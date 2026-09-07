import Foundation
import CryptoKit

public actor RepositoryService {
    public let directory: URL
    private let excluded: Set<String> = [".git", ".env", ".ssh", ".aws", "node_modules", ".build", "build", "dist", "vendor", ".venv", "venv", "__pycache__", ".next", "Pods", "DerivedData", ".serena", ".opencode"]
    private let extensions: Set<String> = ["swift", "ts", "tsx", "js", "jsx", "mjs", "py", "rs", "go", "java", "kt", "c", "h", "cpp", "cs", "rb", "php", "sql", "md", "json", "yaml", "yml", "toml", "html", "css", "vue", "svelte", "sh", "txt", "xml", "graphql", "proto"]
    public init(directory: URL) { self.directory = directory }
    public func importFolder(_ root: URL) throws -> Repository {
        let root = root.resolvingSymlinksInPath().standardizedFileURL
        let files = try enumerate(root)
        guard !files.isEmpty else { throw PalmError.message("No readable source files were found in this folder.") }
        let destination = directory.appendingPathComponent("Snapshots/\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
        var hashInput = ""; var languages: [String: Int] = [:]; var paths: [String] = []
        for file in files {
            let relative = String(file.path.dropFirst(root.path.count + 1))
            let data = try Data(contentsOf: file)
            let target = destination.appendingPathComponent(relative)
            try FileManager.default.createDirectory(at: target.deletingLastPathComponent(), withIntermediateDirectories: true)
            try data.write(to: target, options: .atomic)
            hashInput += relative + ":" + Self.hash(data) + "\n"
            languages[file.pathExtension, default: 0] += 1; paths.append(relative)
        }
        return Repository(name: root.lastPathComponent, originalPath: root.path, snapshotPath: destination.path,
                          fingerprint: Self.hash(Data(hashInput.utf8)), fileCount: files.count,
                          languages: languages.sorted { $0.value > $1.value }.prefix(5).map(\.key),
                          overview: paths.sorted().joined(separator: "\n"))
    }
    public func fingerprint(_ root: URL) throws -> String {
        let root = root.resolvingSymlinksInPath().standardizedFileURL
        let files = try enumerate(root)
        var text = ""
        for file in files { text += String(file.path.dropFirst(root.path.count + 1)) + ":" + Self.hash(try Data(contentsOf: file)) + "\n" }
        return Self.hash(Data(text.utf8))
    }
    private func enumerate(_ root: URL) throws -> [URL] {
        guard let enumerator = FileManager.default.enumerator(at: root, includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey, .fileSizeKey], options: [.skipsHiddenFiles]) else { throw PalmError.message("The repository folder could not be opened.") }
        var files: [URL] = []
        for case let url as URL in enumerator {
            if excluded.contains(url.lastPathComponent) { enumerator.skipDescendants(); continue }
            let values = try url.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey, .fileSizeKey])
            if values.isSymbolicLink == true { enumerator.skipDescendants(); continue }
            guard values.isDirectory != true, (values.fileSize ?? 0) < 250_000,
                  extensions.contains(url.pathExtension) || ["Dockerfile", "Makefile"].contains(url.lastPathComponent),
                  !url.lastPathComponent.lowercased().contains("secret"), !url.lastPathComponent.lowercased().contains("credentials"),
                  !url.lastPathComponent.hasSuffix("lock.json"), !url.lastPathComponent.hasSuffix(".lock") else { continue }
            files.append(url.resolvingSymlinksInPath().standardizedFileURL)
            guard files.count <= 10_000 else { throw PalmError.message("This folder has more than 10,000 source files. Select a package or subfolder to keep analysis focused.") }
        }
        return files.sorted { $0.path < $1.path }
    }
    public func context(for repository: Repository, topic: String) throws -> String {
        let root = URL(fileURLWithPath: repository.snapshotPath).resolvingSymlinksInPath().standardizedFileURL
        let files = try enumerate(root)
        let terms = Set(topic.lowercased().split(whereSeparator: { !$0.isLetter }).filter { $0.count > 3 }.map(String.init))
        var ranked: [(URL, String, Int)] = []
        for file in files {
            guard let contents = try? String(contentsOf: file, encoding: .utf8) else { continue }
            let path = String(file.path.dropFirst(root.path.count + 1))
            let lower = contents.lowercased()
            let score = terms.reduce(0) { $0 + (path.lowercased().contains($1) ? 12 : 0) + (lower.contains($1) ? 3 : 0) } + (path.lowercased().contains("readme") ? 8 : 0) + (path.contains("test") ? 2 : 0)
            ranked.append((file, contents, score))
        }
        ranked.sort { $0.2 == $1.2 ? $0.0.path < $1.0.path : $0.2 > $1.2 }
        var context = "Repository: \(repository.name)\nSnapshot: \(repository.snapshotID)\nFile map (may be abbreviated):\n\(repository.overview.prefix(10000))\n"
        for (file, content, _) in ranked.prefix(18) {
            let path = String(file.path.dropFirst(root.path.count + 1))
            context += "\nSOURCE \(path) [sha256:\(Self.hash(Data(content.utf8)))]\n\(content.prefix(7000))\nEND SOURCE\n"
            if context.count > 65_000 { break }
        }
        return context
    }
    public func clone(url: String, token: String?) async throws -> URL {
        guard let remote = URL(string: url), remote.scheme == "https", remote.host == "github.com", remote.user == nil, remote.password == nil else { throw PalmError.message("Enter an HTTPS github.com repository URL.") }
        let target = directory.appendingPathComponent("Repositories/\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: target.deletingLastPathComponent(), withIntermediateDirectories: true)
        var env = ProcessInfo.processInfo.environment
        env["GIT_TERMINAL_PROMPT"] = "0"
        if let token, !token.isEmpty {
            env["GIT_CONFIG_COUNT"] = "1"; env["GIT_CONFIG_KEY_0"] = "http.https://github.com/.extraheader"
            env["GIT_CONFIG_VALUE_0"] = "Authorization: Basic \(Data("x-access-token:\(token)".utf8).base64EncodedString())"
        }
        _ = try await ProcessRunner.run("/usr/bin/git", ["clone", "--depth", "1", "--", url, target.path], environment: env, timeout: 120)
        return target
    }
    public static func hash(_ data: Data) -> String { SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined() }
}

private final class ProcessCancellation: @unchecked Sendable {
    private let lock = NSLock()
    private var process: Process?
    private var cancelled = false
    func launch(_ value: Process) throws {
        lock.lock(); defer { lock.unlock() }
        guard !cancelled else { throw CancellationError() }
        process = value; try value.run()
    }
    func cancel() {
        lock.lock(); defer { lock.unlock() }
        cancelled = true
        if process?.isRunning == true { process?.terminate() }
    }
}

public enum ProcessRunner {
    public static func output(_ executable: String, _ arguments: [String], input: Data? = nil, environment: [String: String]? = nil, timeout: TimeInterval = 120) -> AsyncThrowingStream<Data, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do { _ = try await run(executable, arguments, input: input, environment: environment, timeout: timeout, onOutput: { continuation.yield($0) }); continuation.finish() }
                catch { continuation.finish(throwing: error) }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
    public static func run(_ executable: String, _ arguments: [String], input: Data? = nil, environment: [String: String]? = nil, timeout: TimeInterval = 120, onOutput: (@Sendable (Data) -> Void)? = nil) async throws -> Data {
        let cancellation = ProcessCancellation()
        return try await withTaskCancellationHandler {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let process = Process(); process.executableURL = URL(fileURLWithPath: executable); process.arguments = arguments
                if let environment { process.environment = environment }
                let output = Pipe(); let error = Pipe(); let stdin = Pipe()
                process.standardOutput = output; process.standardError = error; process.standardInput = stdin
                do { try cancellation.launch(process) } catch { continuation.resume(throwing: error); return }
                let timer = DispatchSource.makeTimerSource()
                timer.schedule(deadline: .now() + timeout)
                timer.setEventHandler { if process.isRunning { process.terminate() } }; timer.resume()
                let errorRead = DispatchGroup(); errorRead.enter()
                DispatchQueue.global().async { _ = error.fileHandleForReading.readDataToEndOfFile(); errorRead.leave() }
                if let input { try? stdin.fileHandleForWriting.write(contentsOf: input) }
                try? stdin.fileHandleForWriting.close()
                var result = Data()
                while true {
                    let chunk = output.fileHandleForReading.availableData
                    if chunk.isEmpty { break }
                    result.append(chunk); onOutput?(chunk)
                }
                process.waitUntilExit(); timer.cancel(); errorRead.wait()
                if process.terminationStatus == 0 { continuation.resume(returning: result) }
                else { continuation.resume(throwing: PalmError.message("\(URL(fileURLWithPath: executable).lastPathComponent) stopped before finishing (exit \(process.terminationStatus)). Check its installation or try again.")) }
            }
        }
        } onCancel: { cancellation.cancel() }
    }
}
