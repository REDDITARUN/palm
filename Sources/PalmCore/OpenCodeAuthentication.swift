import Foundation

public struct OpenCodeAccountStatus: Equatable, Sendable {
    public var connected: Bool
    public var models: [String]
    public init(connected: Bool, models: [String]) { self.connected = connected; self.models = models }
}
public struct OpenCodeAuthorization: Decodable, Sendable {
    public let url: URL
    public let method: String
    public let instructions: String
    public static func trusted(_ url: URL) -> Bool { url.scheme == "https" && url.host == "auth.openai.com" && url.user == nil && url.password == nil }
}

/// OpenCode owns OAuth, refresh, and account eligibility. Palm never reads its tokens.
/// This service uses its own protected directory, not another CLI's saved account.
public actor OpenCodeAuthentication {
    private let directory: URL
    private var process: Process?
    private var port = 0
    private let password = UUID().uuidString
    private var methodIndex: Int?
    public init(directory: URL) { self.directory = directory }
    deinit { if process?.isRunning == true { process?.terminate() } }

    private func start() async throws {
        if process?.isRunning == true { return }
        let executable = directory.appendingPathComponent("Runtime/opencode")
        guard FileManager.default.isExecutableFile(atPath: executable.path) else { throw PalmError.message("Prepare local tools before signing in with ChatGPT.") }
        let workspace = directory.appendingPathComponent("ChatGPTConnection")
        try FileManager.default.createDirectory(at: workspace, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        let configURL = workspace.appendingPathComponent("opencode.json")
        let config: [String: Any] = ["$schema": "https://opencode.ai/config.json", "enabled_providers": ["openai"], "permission": ["*": "deny"], "share": "disabled", "autoupdate": false]
        try JSONSerialization.data(withJSONObject: config).write(to: configURL, options: .atomic)
        var env = try OpenCodeEnvironment.make(directory: directory, configuration: .init(key: "", endpoint: "https://api.openai.com/v1", model: "", authentication: .chatGPT))
        env["OPENCODE_CONFIG"] = configURL.path; env["OPENCODE_SERVER_PASSWORD"] = password
        port = Int.random(in: 42000...49000)
        let child = Process(); child.executableURL = executable
        child.arguments = ["serve", "--hostname", "127.0.0.1", "--port", String(port)]
        child.currentDirectoryURL = workspace; child.environment = env
        child.standardOutput = FileHandle.nullDevice; child.standardError = FileHandle.nullDevice
        try child.run(); process = child
        do {
            for _ in 0..<100 {
                try Task.checkCancellation()
                if (try? await request("global/health", timeout: 1)) != nil { return }
                if !child.isRunning { break }
                try await Task.sleep(for: .milliseconds(200))
            }
            throw PalmError.message("OpenCode could not start the sign-in service. Try Repair local tools in Settings.")
        } catch { stop(); throw error }
    }
    private func request(_ path: String, method: String = "GET", body: [String: Any]? = nil, timeout: TimeInterval = 30) async throws -> Data {
        var request = URLRequest(url: URL(string: "http://127.0.0.1:\(port)/\(path)")!)
        request.httpMethod = method; request.timeoutInterval = timeout
        request.setValue("Basic " + Data("opencode:\(password)".utf8).base64EncodedString(), forHTTPHeaderField: "Authorization")
        if let body { request.httpBody = try JSONSerialization.data(withJSONObject: body); request.setValue("application/json", forHTTPHeaderField: "Content-Type") }
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let response = response as? HTTPURLResponse, (200..<300).contains(response.statusCode) else { throw PalmError.message("OpenCode could not complete ChatGPT sign-in. Retry, or check your account's Codex access.") }
        return data
    }
    public func status() async throws -> OpenCodeAccountStatus {
        try await start()
        let data = try await request("provider")
        return try Self.parseStatus(data)
    }
    public static func parseStatus(_ data: Data) throws -> OpenCodeAccountStatus {
        let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
        let connected = (object["connected"] as? [String] ?? []).contains("openai")
        let provider = (object["all"] as? [[String: Any]] ?? []).first { $0["id"] as? String == "openai" }
        let models = connected ? Array((provider?["models"] as? [String: Any] ?? [:]).keys).sorted() : []
        return .init(connected: connected, models: models)
    }
    public func begin() async throws -> OpenCodeAuthorization {
        stop(); try await start()
        let data = try await request("provider/auth")
        let methods = (try JSONSerialization.jsonObject(with: data) as? [String: [[String: Any]]])?["openai"] ?? []
        guard let index = methods.firstIndex(where: { $0["type"] as? String == "oauth" && ($0["label"] as? String ?? "").lowercased().contains("browser") }) else { throw PalmError.message("This OpenCode version has no ChatGPT browser sign-in. Repair local tools and retry.") }
        let result = try await request("provider/openai/oauth/authorize", method: "POST", body: ["method": index])
        let auth = try JSONDecoder().decode(OpenCodeAuthorization.self, from: result)
        guard OpenCodeAuthorization.trusted(auth.url), auth.method == "auto" else { stop(); throw PalmError.message("OpenCode returned an unsupported sign-in flow. No browser was opened.") }
        methodIndex = index; return auth
    }
    public func complete() async throws -> OpenCodeAccountStatus {
        guard let methodIndex else { throw PalmError.message("Start ChatGPT sign-in first.") }
        _ = try await request("provider/openai/oauth/callback", method: "POST", body: ["method": methodIndex], timeout: 300)
        // Reload provider metadata after credentials change; don't reuse the unauthenticated model catalogue.
        stop()
        return try await status()
    }
    public func disconnect() async throws {
        try await start()
        _ = try await request("auth/openai", method: "DELETE")
        stop()
    }
    public func stop() { if process?.isRunning == true { process?.terminate() }; process = nil; methodIndex = nil }
}

public enum OpenCodeEnvironment {
    public static func make(directory: URL, configuration: ModelConfiguration, inherited: [String: String] = ProcessInfo.processInfo.environment) throws -> [String: String] {
        // Deliberate allowlist: shell credentials and global OpenCode overrides must not choose a different account.
        var env = inherited.filter { ["HOME", "USER", "LOGNAME", "TMPDIR", "LANG", "LC_ALL", "SHELL", "SSL_CERT_FILE", "SSL_CERT_DIR"].contains($0.key) }
        env["PATH"] = directory.appendingPathComponent("Runtime/venv/bin").path + ":/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin"
        let auth = configuration.authentication == .chatGPT
        let data = directory.appendingPathComponent(auth ? "ChatGPTAgentData" : "APIKeyAgentData")
        let config = directory.appendingPathComponent(auth ? "ChatGPTAgentConfig" : "APIKeyAgentConfig")
        for folder in [data, config] {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
            try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: folder.path)
        }
        env["XDG_DATA_HOME"] = data.path; env["XDG_CONFIG_HOME"] = config.path
        env["XDG_CACHE_HOME"] = directory.appendingPathComponent("AgentCache").path
        env["OPENCODE_DISABLE_PROJECT_CONFIG"] = "true"
        if !auth {
            env["PALM_MODEL_API_KEY"] = configuration.key
            if configuration.isOpenRouter { env["OPENROUTER_API_KEY"] = configuration.key }
            else if configuration.agentProvider == "openai" { env["OPENAI_API_KEY"] = configuration.key }
        }
        return env
    }
    public static func providerConfig(_ configuration: ModelConfiguration) -> [String: Any] {
        let provider = configuration.agentProvider ?? "palmcustom"
        let selected = provider + "/" + configuration.model
        // OpenCode also uses a small model for background work. Keep that work on the user's exact choice.
        if configuration.authentication == .chatGPT { return ["enabled_providers": ["openai"], "model": selected, "small_model": selected, "provider": ["openai": ["options": ["timeout": false, "headerTimeout": 1_800_000, "chunkTimeout": 1_800_000]]]] }
        var entry: [String: Any] = ["options": ["apiKey": "{env:PALM_MODEL_API_KEY}", "baseURL": configuration.endpoint, "timeout": false, "headerTimeout": 1_800_000, "chunkTimeout": 1_800_000]]
        if provider == "palmcustom" { entry["npm"] = "@ai-sdk/openai-compatible"; entry["name"] = "Palm custom provider" }
        entry["models"] = [configuration.model: ["name": configuration.model]]
        return ["enabled_providers": [provider], "model": selected, "small_model": selected, "provider": [provider: entry]]
    }
}
