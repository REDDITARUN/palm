import XCTest
@testable import PalmCore

final class LibraryRemovalTests: XCTestCase {
    func testRemovalRetainsNotesCardsAndOtherCoursesAcrossDatabaseReopen() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let db = try LocalDatabase(directory: root)
        let outline = CourseOutline(title: "Scope", summary: "Names", outcomes: [], modules: [.init(id: "m", title: "Basics", lessons: [.init(id: "l", title: "Scope", objective: "Trace", minutes: 5, prerequisites: [])])])
        var data = AppData()
        let course = Course(topic: "Scope", level: "New", repositoryID: nil, outline: outline)
        let other = Course(topic: "Other", level: "New", repositoryID: nil, outline: outline)
        data.courses = [course, other]
        let question = Question(id: "q", kind: .choice, skill: "trace", prompt: "Which?", code: "", options: ["A", "B"], answer: "A", acceptedAnswers: [], explanation: "A", hints: [], sourceIDs: [])
        let session = StudySession(courseID: course.id, lessonID: "l", content: .init(title: "Scope", introduction: "", material: "Names", workedExample: "", takeaways: [], questions: [question], sources: []))
        data.sessions = [session]
        let note = StudyNote(title: "Keep me", body: "My explanation", courseID: course.id, sessionID: session.id)
        data.notes = [note]
        data.flashcards = [.init(noteID: note.id, front: "What is scope?", back: "Where a name can be used.")]
        data.memories = [.init(text: "Course memory", courseID: course.id, sourceIDs: []), .init(text: "Global memory", courseID: nil, sourceIDs: [])]
        data.reviews = [.init(courseID: course.id, lessonID: "l", title: "Scope")]
        data.conversations = [.init(id: "session:" + session.id.uuidString), .init(id: "note:" + note.id.uuidString)]
        try db.save(data, revision: NoteRevision(note: note))
        let next = LibraryRemoval.course(course.id, from: data)
        try db.save(next)
        let loaded = try LocalDatabase(directory: root).load()
        XCTAssertEqual(loaded.courses.map(\.id), [other.id]); XCTAssertTrue(loaded.sessions.isEmpty); XCTAssertTrue(loaded.reviews.isEmpty)
        XCTAssertEqual(loaded.flashcards, data.flashcards)
        XCTAssertEqual(loaded.notes.first?.body, note.body); XCTAssertNil(loaded.notes.first?.courseID); XCTAssertNil(loaded.notes.first?.sessionID)
        XCTAssertEqual(loaded.memories.map(\.text), ["Global memory"])
        XCTAssertEqual(loaded.conversations?.map(\.id), ["note:" + note.id.uuidString])
        XCTAssertEqual(try db.revisions(for: note.id).count, 1)
    }
    func testRepositoryRemovalKeepsOriginalFilesAndUnlinksCourses() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let file = root.appendingPathComponent("main.py"); try Data("print(1)".utf8).write(to: file)
        let repo = Repository(name: "Fixture", originalPath: root.path, snapshotPath: root.path, fingerprint: "test", fileCount: 1, languages: ["Python"], overview: "Fixture")
        var data = AppData(); data.repositories = [repo]
        data.courses = [.init(topic: "Test", level: "New", repositoryID: repo.id, outline: .init(title: "Test", summary: "", outcomes: [], modules: []))]
        data.repositoryInsights = [.init(repositoryID: repo.id, snapshotID: repo.snapshotID, topic: "Test", summary: "Evidence")]
        let next = LibraryRemoval.repository(repo.id, from: data)
        XCTAssertTrue(next.repositories.isEmpty); XCTAssertTrue(next.repositoryInsights!.isEmpty); XCTAssertNil(next.courses.first?.repositoryID)
        XCTAssertEqual(try String(contentsOf: file, encoding: .utf8), "print(1)")
    }
}
