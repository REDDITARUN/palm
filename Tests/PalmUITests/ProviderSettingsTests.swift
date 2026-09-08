import XCTest
import PalmCore
@testable import Palm

@MainActor final class ProviderSettingsTests: XCTestCase {
    func testSaveSwitchForgetAndRoutedModels() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = AppStore(testDirectory: directory)
        var openRouter = ProviderConnection.preset("OpenRouter"); openRouter.model = "custom-model:free"
        try store.saveConnection(openRouter, replacementKey: "fixture-router-key", activate: true)
        var custom = ProviderConnection(name: "Second provider", endpoint: "https://provider.invalid/v1", model: "my-unlisted-model")
        try store.saveConnection(custom, replacementKey: "fixture-custom-key", activate: true)
        store.updatePreferences { $0.name = "Updated name"; $0.dailyMinutes = 25 }
        XCTAssertEqual(store.data.preferences.name, "Updated name")
        XCTAssertEqual(store.configuration.key, "fixture-custom-key")
        XCTAssertEqual(store.configuration.model, "my-unlisted-model")
        try store.activateConnection(openRouter.id)
        XCTAssertEqual(store.configuration.key, "fixture-router-key"); XCTAssertEqual(store.configuration.model, "custom-model:free")
        try store.forgetConnectionKey(openRouter)
        try store.activateConnection(custom.id); try store.activateConnection(openRouter.id)
        XCTAssertEqual(store.configuration.key, ""); XCTAssertFalse(store.hasModelAccess)
        var route = ModelProfile(); route.providerID = custom.id; route.model = "private/override"; route.roles = ["grading"]
        store.data.modelProfiles = [route]
        XCTAssertEqual(store.modelConfiguration(for: "grading").key, "fixture-custom-key")
        XCTAssertEqual(store.modelConfiguration(for: "grading").model, "private/override")
        custom.endpoint = "https://changed.invalid/v1"
        try store.saveConnection(custom, replacementKey: "", activate: true)
        XCTAssertEqual(store.configuration.key, "", "An edited endpoint must not inherit the previous server's key")
        XCTAssertEqual(store.modelConfiguration(for: "grading").key, "")
        let reopened = try LocalDatabase(directory: directory).load()
        XCTAssertEqual(reopened.preferences.activeProvider?.model, custom.model)
        XCTAssertEqual(reopened.preferences.activeProvider?.endpoint, custom.endpoint)
        let export = String(decoding: try JSONEncoder().encode(reopened), as: UTF8.self)
        XCTAssertFalse(export.contains("fixture-router-key")); XCTAssertFalse(export.contains("fixture-custom-key"))
    }
    func testChatGPTRouteNeverUsesAnAPIKeyAndRequiresConnection() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = AppStore(testDirectory: directory)
        var connection = ProviderConnection.preset("ChatGPT"); connection.model = "eligible-codex-model"
        try store.saveConnection(connection, replacementKey: "fixture-not-an-oauth-token", activate: true)
        XCTAssertTrue(store.configuration.requiresHarness); XCTAssertEqual(store.apiKey, ""); XCTAssertFalse(store.hasModelAccess)
        store.chatGPTConnected = true; XCTAssertTrue(store.hasModelAccess)
        var route = ModelProfile(); route.providerID = connection.id; route.model = connection.model; route.roles = ["tutor"]
        store.data.modelProfiles = [route]
        XCTAssertEqual(store.modelConfiguration(for: "tutor").authentication, .chatGPT)
        XCTAssertEqual(store.modelConfiguration(for: "tutor").key, "")
    }
}
