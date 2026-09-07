import XCTest
@testable import PalmCore

final class BrandCompatibilityTests: XCTestCase {
    func testExistingLibrarySurvivesRenameWithoutMovingSnapshots() throws {
        let support = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: support) }
        let legacy = support.appendingPathComponent("Plam")
        let db = try LocalDatabase(directory: legacy)
        var data = AppData()
        data.preferences.name = "Existing learner"
        try db.save(data)
        let resolved = LocalDatabase.defaultDirectory(applicationSupport: support)
        XCTAssertEqual(resolved.path, legacy.path)
        XCTAssertEqual(try LocalDatabase(directory: resolved).load().preferences.name, "Existing learner")
    }
    func testFreshInstallUsesPalmWithoutMistakingAnEmptyOldFolderForALibrary() throws {
        let support = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: support) }
        try FileManager.default.createDirectory(at: support.appendingPathComponent("Plam"), withIntermediateDirectories: true)
        XCTAssertEqual(LocalDatabase.defaultDirectory(applicationSupport: support).lastPathComponent, "Palm")
    }
}
