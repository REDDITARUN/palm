import XCTest
@testable import PalmCore

final class SourceAndWorkTests: XCTestCase {
    func testSourceLineReferencesAndLinks() throws {
        for location in ["src/main.py:12-18", "src/main.py#L12-L18"] {
            let ref = try SourceReference(location)
            XCTAssertEqual(ref.path, "src/main.py"); XCTAssertEqual(ref.line, 12); XCTAssertEqual(ref.endLine, 18)
            XCTAssertEqual(try SourceReference(link: ref.link), ref)
        }
        XCTAssertEqual(try SourceReference("folder with space/code.swift:3").line, 3)
        for bad in ["../secret", "/etc/passwd", "src/../../secret", "file:///etc/passwd", "a.py:0", "a.py:4-2", "a\\b"] { XCTAssertThrowsError(try SourceReference(bad)) }
    }
    func testSnapshotOnlyFilesAndSymlinkContainment() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: dir) }
        let root = dir.appendingPathComponent("snapshot")
        try FileManager.default.createDirectory(at: root.appendingPathComponent("src"), withIntermediateDirectories: true)
        try Data("print(42)\n".utf8).write(to: root.appendingPathComponent("src/main.py"))
        try Data("private".utf8).write(to: dir.appendingPathComponent("secret"))
        try FileManager.default.createSymbolicLink(at: root.appendingPathComponent("escape.py"), withDestinationURL: dir.appendingPathComponent("secret"))
        XCTAssertEqual(try SnapshotSource.files(root: root), ["src/main.py"])
        XCTAssertEqual(try SnapshotSource.read(root: root, reference: SourceReference("src/main.py:1")), "print(42)\n")
        XCTAssertThrowsError(try SnapshotSource.read(root: root, reference: SourceReference("escape.py")))
        XCTAssertThrowsError(try SnapshotSource.read(root: root, reference: SourceReference("missing.py")))
    }
    func testLongWorkKeepsOutputAndSupportsCancellation() async throws {
        let data = try await ProcessRunner.run("/bin/sh", ["-c", "printf first; sleep 0.3; printf second"], timeout: nil)
        XCTAssertEqual(String(decoding: data, as: UTF8.self), "firstsecond")
        let task = Task { try await ProcessRunner.run("/bin/sleep", ["30"], timeout: nil) }
        try await Task.sleep(for: .milliseconds(100))
        let start = Date(); task.cancel()
        do { _ = try await task.value; XCTFail("Cancelled process succeeded") } catch { }
        XCTAssertLessThan(Date().timeIntervalSince(start), 3)
    }
    func testUpgradeBacksUpAndKeepsExistingLibrary() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let old = try LocalDatabase(directory: root, appVersion: "1.0.2")
        var data = AppData(); data.preferences.name = "Existing learner"
        data.notes = [StudyNote(title: "Keep this", body: "My original reasoning")]
        data.flashcards = [.init(noteID: data.notes[0].id, front: "A", back: "B")]
        try old.save(data)
        let upgraded = try LocalDatabase(directory: root, appVersion: "1.0.3")
        let loaded = try upgraded.load()
        XCTAssertEqual(loaded.preferences.name, data.preferences.name)
        XCTAssertEqual(loaded.notes[0].body, data.notes[0].body)
        XCTAssertEqual(loaded.flashcards?.first?.id, data.flashcards?.first?.id)
        let backupFolder = root.appendingPathComponent("UpgradeBackups")
        let backups = try FileManager.default.contentsOfDirectory(at: backupFolder, includingPropertiesForKeys: nil)
        XCTAssertEqual(backups.count, 1)
        _ = try LocalDatabase(directory: root, appVersion: "1.0.3")
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: backupFolder.path).count, 1)
        // A copy made with SQLite's backup API can be opened independently.
        let restore = root.appendingPathComponent("restore")
        try FileManager.default.createDirectory(at: restore, withIntermediateDirectories: true)
        try FileManager.default.copyItem(at: backups[0], to: restore.appendingPathComponent("plam.sqlite"))
        XCTAssertEqual(try LocalDatabase(directory: restore).load().notes[0].body, "My original reasoning")
    }
    func testOptInLocalParakeetTranscription() async throws {
        guard let path = ProcessInfo.processInfo.environment["PALM_VOICE_TEST_AUDIO"] else { throw XCTSkip("Set PALM_VOICE_TEST_AUDIO to a disposable spoken fixture to download and test Parakeet.") }
        let transcript = try await VoiceTranscriber.shared.transcribe(URL(fileURLWithPath: path))
        XCTAssertTrue(transcript.lowercased().contains("list"), "Expected list in the spoken fixture")
        XCTAssertTrue(transcript.lowercased().contains("copy"), "Expected copy in the spoken fixture")
    }
}
