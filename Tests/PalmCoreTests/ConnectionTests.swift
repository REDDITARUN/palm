import XCTest
@testable import PalmCore

final class ConnectionTests: XCTestCase {
    func testLegacyMigrationAndIndependentModelsSurviveReopen() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let db = try LocalDatabase(directory: root)
        var data = AppData(); data.preferences.model = "my/private-model:free"
        let legacyJSON = try JSONEncoder().encode(data)
        data = try JSONDecoder().decode(AppData.self, from: legacyJSON)
        data.preferences.migrateProviders()
        let original = try XCTUnwrap(data.preferences.activeProvider)
        XCTAssertEqual(original.credentialAccount, "model-openrouter")
        var custom = ProviderConnection.preset("Custom"); custom.model = "local/unknown-model"; custom.endpoint = "https://models.example/v1"
        data.preferences.saveProvider(try custom.validated(), activate: true)
        data.preferences.activateProvider(original.id)
        XCTAssertEqual(data.preferences.model, "my/private-model:free")
        data.preferences.activateProvider(custom.id)
        try db.save(data)
        let restored = try LocalDatabase(directory: root).load()
        XCTAssertEqual(restored.preferences.activeProvider?.model, "local/unknown-model")
        XCTAssertEqual(restored.preferences.providerConnections?.count, 2)
        XCTAssertNotEqual(original.credentialAccount, custom.credentialAccount)
        var legacyCustom = Preferences(); legacyCustom.endpoint = "https://custom.invalid/v1/"; legacyCustom.model = "custom"
        let expectedAccount = ModelConfiguration(key: "", endpoint: legacyCustom.endpoint, model: "custom").credentialAccount
        legacyCustom.migrateProviders()
        XCTAssertEqual(try legacyCustom.activeProvider?.validated().credentialAccount, expectedAccount)
    }
    func testDraftEditsCannotMutateSavedConnectionOrCarryKeysAcrossEndpoints() throws {
        var preferences = Preferences(); preferences.migrateProviders()
        let old = try XCTUnwrap(preferences.activeProvider)
        var draft = old; draft.endpoint = "https://another.example/v1"; draft.legacyCredentialAccount = nil
        draft.model = "a custom model"
        XCTAssertEqual(preferences.activeProvider, old)
        XCTAssertNotEqual(draft.credentialAccount, old.credentialAccount)
        XCTAssertEqual(try draft.validated().model, "a custom model")
    }
    func testImportedConnectionCannotReadUnrelatedKeychainAccounts() {
        var connection = ProviderConnection(name: "Imported", endpoint: "https://provider.invalid/v1", model: "custom")
        connection.legacyCredentialAccount = "github"
        XCTAssertNotEqual(connection.credentialAccount, "github")
        connection.legacyCredentialAccount = "model-openrouter"
        XCTAssertNotEqual(connection.credentialAccount, "model-openrouter")
    }
    func testConnectionRejectsEmbeddedCredentialsAndNonlocalHTTP() {
        for endpoint in ["https://user:password@provider.example/v1", "https://provider.example/v1?key=secret", "http://provider.example/v1"] {
            XCTAssertThrowsError(try ProviderConnection(name: "Test", endpoint: endpoint, model: "custom").validated())
        }
        XCTAssertNoThrow(try ProviderConnection(name: "Local", endpoint: "http://localhost:1234/v1", model: "custom").validated())
    }
    func testChatGPTCannotInheritAPIKeysOrAgentOverrides() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let connection = ProviderConnection(name: "ChatGPT", endpoint: "https://api.openai.com/v1", model: "codex", authentication: .chatGPT)
        let config = connection.configuration(key: "test-only-should-be-ignored")
        XCTAssertEqual(config.key, ""); XCTAssertTrue(config.requiresHarness)
        XCTAssertEqual(OpenCodeEnvironment.providerConfig(config)["small_model"] as? String, "openai/codex")
        let free = ModelConfiguration(key: "test", endpoint: "https://openrouter.ai/api/v1", model: "chosen:free")
        XCTAssertEqual(OpenCodeEnvironment.providerConfig(free)["small_model"] as? String, "openrouter/chosen:free")
        let env = try OpenCodeEnvironment.make(directory: root, configuration: config, inherited: ["HOME": root.path, "OPENAI_API_KEY": "wrong", "OPENROUTER_API_KEY": "wrong", "OPENCODE_CONFIG_CONTENT": "wrong", "OTHER_TOKEN": "wrong"])
        XCTAssertNil(env["OPENAI_API_KEY"]); XCTAssertNil(env["OPENROUTER_API_KEY"]); XCTAssertNil(env["OTHER_TOKEN"]); XCTAssertNil(env["OPENCODE_CONFIG_CONTENT"])
        XCTAssertTrue(env["XDG_DATA_HOME"]!.hasSuffix("ChatGPTAgentData"))
        let api = try OpenCodeEnvironment.make(directory: root, configuration: .init(key: "test-only", endpoint: "https://api.openai.com/v1", model: "api-model"))
        XCTAssertNotEqual(api["XDG_DATA_HOME"], env["XDG_DATA_HOME"])
        XCTAssertEqual(api["OPENAI_API_KEY"], "test-only"); XCTAssertNil(api["OPENROUTER_API_KEY"])
    }
    func testAuthOnlyOffersConnectedProviderModelsAndValidatesBrowserDestination() throws {
        let connected = Data(#"{"connected":["openai"],"all":[{"id":"openai","models":{"eligible-model":{}}},{"id":"other","models":{"wrong":{}}}]}"#.utf8)
        XCTAssertEqual(try OpenCodeAuthentication.parseStatus(connected), .init(connected: true, models: ["eligible-model"]))
        let disconnected = Data(#"{"connected":[],"all":[{"id":"openai","models":{"api-only-model":{}}}]}"#.utf8)
        XCTAssertEqual(try OpenCodeAuthentication.parseStatus(disconnected), .init(connected: false, models: []))
        XCTAssertTrue(OpenCodeAuthorization.trusted(URL(string: "https://auth.openai.com/oauth/authorize")!))
        for url in ["http://auth.openai.com", "https://auth.openai.com.attacker.example", "https://evil.example", "https://user:password@auth.openai.com"] { XCTAssertFalse(OpenCodeAuthorization.trusted(URL(string: url)!)) }
    }
    func testCustomModelThroughPinnedHarnessWithLocalProvider() async throws {
        guard let executable = ProcessInfo.processInfo.environment["PALM_AUTH_RUNTIME"] else { throw XCTSkip("Opt-in local OpenCode generation check") }
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root.appendingPathComponent("Runtime/venv/bin"), withIntermediateDirectories: true)
        try FileManager.default.createSymbolicLink(at: root.appendingPathComponent("Runtime/opencode"), withDestinationURL: URL(fileURLWithPath: executable))
        try FileManager.default.createSymbolicLink(at: root.appendingPathComponent("Runtime/venv/bin/python"), withDestinationURL: URL(fileURLWithPath: "/usr/bin/python3"))
        let server = Process(); server.executableURL = URL(fileURLWithPath: "/usr/bin/python3")
        server.arguments = ["-u", "-c", #"""
import json
from http.server import BaseHTTPRequestHandler, HTTPServer
class H(BaseHTTPRequestHandler):
 def log_message(self,*args): pass
 def do_POST(self):
  body=json.loads(self.rfile.read(int(self.headers['Content-Length'])))
  if body.get('model')!='private-test-model' or self.headers.get('Authorization')!='Bearer local-test-key':
   self.send_response(400);self.end_headers();return
  self.send_response(200);self.send_header('Content-Type','text/event-stream');self.end_headers()
  for delta,finish in [({'role':'assistant','content':'Each name points to the same list.'},None),({},'stop')]:
   event={'id':'fixture','object':'chat.completion.chunk','created':1,'model':'private-test-model','choices':[{'index':0,'delta':delta,'finish_reason':finish}]}
   self.wfile.write(('data: '+json.dumps(event)+'\n\n').encode());self.wfile.flush()
  self.wfile.write(b'data: [DONE]\n\n');self.wfile.flush()
s=HTTPServer(('127.0.0.1',0),H);print(s.server_port,flush=True);s.serve_forever()
"""#]
        let pipe = Pipe(); server.standardOutput = pipe; server.standardError = FileHandle.nullDevice
        try server.run(); defer { server.terminate() }
        let port = try XCTUnwrap(Int(String(decoding: pipe.fileHandleForReading.availableData, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)))
        let runtime = RuntimeService(directory: root)
        let result = try await runtime.generate("Explain the alias briefly.", configuration: .init(key: "local-test-key", endpoint: "http://127.0.0.1:\(port)/v1", model: "private-test-model"))
        XCTAssertEqual(result, "Each name points to the same list.")
    }
    func testPinnedRuntimeAuthProtocolWithoutAnAccount() async throws {
        guard let executable = ProcessInfo.processInfo.environment["PALM_AUTH_RUNTIME"] else { throw XCTSkip("Opt-in read-only OpenCode protocol check") }
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root.appendingPathComponent("Runtime"), withIntermediateDirectories: true)
        try FileManager.default.createSymbolicLink(at: root.appendingPathComponent("Runtime/opencode"), withDestinationURL: URL(fileURLWithPath: executable))
        let auth = OpenCodeAuthentication(directory: root)
        do {
            let before = try await auth.status(); XCTAssertFalse(before.connected); XCTAssertTrue(before.models.isEmpty)
            let authorization = try await auth.begin(); XCTAssertEqual(authorization.method, "auto"); XCTAssertTrue(OpenCodeAuthorization.trusted(authorization.url))
            await auth.stop() // No browser is opened and no user account is accessed.
            try await auth.disconnect()
            let after = try await auth.status(); XCTAssertFalse(after.connected)
            await auth.stop()
        } catch { await auth.stop(); throw error }
    }
}
