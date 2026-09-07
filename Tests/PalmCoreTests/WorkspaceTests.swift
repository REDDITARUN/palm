import XCTest
@testable import PalmCore

final class WorkspaceTests: XCTestCase {
    func testLegacyNoteDecodesWithoutBlocks() throws {
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(StudyNote(body: "==idea== $x$"))) as? [String: Any])
        object.removeValue(forKey: "blocksJSON"); object.removeValue(forKey: "documentRevision")
        let note = try JSONDecoder().decode(StudyNote.self, from: JSONSerialization.data(withJSONObject: object))
        XCTAssertNil(note.blocksJSON); XCTAssertEqual(note.body, "==idea== $x$")
    }
    func testDocumentWritesAndRevisionsSurviveReopenAndBackup() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let db = try LocalDatabase(directory: root)
        var data = AppData(); var note = StudyNote(title: "Math", body: "Original")
        note.blocksJSON = "[{\"id\":\"stable-block\",\"type\":\"paragraph\",\"content\":\"Original\"}]"
        data.notes = [note]; try db.save(data)
        let revision = NoteRevision(note: note)
        note.body = "Changed"; note.blocksJSON = "[{\"id\":\"stable-block\",\"type\":\"paragraph\",\"content\":\"Changed\"}]"
        try db.saveNote(note, revision: revision)
        var conversation = TutorConversation(id: "note:" + note.id.uuidString); conversation.messages = [ChatMessage(role: "user", content: "Explain")]
        try db.saveConversation(conversation)
        let reopened = try LocalDatabase(directory: root)
        let loaded = try reopened.load()
        XCTAssertEqual(loaded.notes, [note]); XCTAssertEqual(loaded.conversations, [conversation])
        XCTAssertEqual(try reopened.revisions(for: note.id).first?.blocksJSON, revision.blocksJSON)
        XCTAssertEqual(try reopened.searchNotes("Changed"), [note.id]); XCTAssertTrue(try reopened.searchNotes("Original").isEmpty)
        let backup = root.appendingPathComponent("export")
        try reopened.exportBackup(loaded, to: backup)
        let restored = try reopened.restoreBackup(from: backup)
        XCTAssertEqual(restored.notes, [note]); XCTAssertEqual(restored.conversations, [conversation])
        var deleted = restored; deleted.notes = []; deleted.conversations = []
        try reopened.save(deleted)
        XCTAssertTrue(try reopened.load().notes.isEmpty)
    }
    func testGraphExcludesForgottenMemoryAndRetrievalUsesSavedNotes() {
        var data = AppData(); let first = StudyNote(title: "Closures", body: "A closure captures an environment. [[Scope]]")
        let second = StudyNote(title: "Scope", body: "Lexical scope controls name resolution.")
        data.notes = [first, second]
        var memory = LearnerMemory(text: "Secret forgotten idea", courseID: nil, sourceIDs: []); memory.forgotten = true; data.memories = [memory]
        let index = KnowledgeIndex(data)
        XCTAssertEqual(index.nodes.count, 2); XCTAssertEqual(index.links.count, 1)
        let context = KnowledgeIndex.context(data, query: "lexical scope", excluding: first.id)
        XCTAssertTrue(context.contains("[[Scope]]")); XCTAssertFalse(context.contains("Secret forgotten"))
    }
    func testDiagramAnswersAreValidatedByStableOptionID() throws {
        var q = Question(id: "flow", kind: .diagramChoice, skill: "trace", prompt: "Which flow?", code: "", options: ["A", "B"], answer: "B", acceptedAnswers: [], explanation: "B preserves the return path.", hints: [], sourceIDs: [])
        q.diagrams = [.init(id: "A", mermaid: "flowchart LR\nA-->B", description: "A goes to B"), .init(id: "B", mermaid: "flowchart LR\nA-->C", description: "A goes to C")]
        var content = LessonContent(title: "Flow", introduction: "", material: "Trace the path.", workedExample: "", takeaways: [], questions: [q], sources: [])
        try LearningEngine.validate(content)
        XCTAssertEqual(LearningEngine.grade("B", for: q)?.correct, true)
        content.questions[0].diagrams?.removeLast()
        XCTAssertThrowsError(try LearningEngine.validate(content))
    }
    func testSSEFramingAndProcessOutputPreserveUnicode() async throws {
        var parser = ServerSentEvents()
        XCTAssertNil(parser.consume(": keepalive")); XCTAssertNil(parser.consume("data: first")); XCTAssertNil(parser.consume("data: second")); XCTAssertEqual(parser.consume(""), "first\nsecond")
        var output = Data()
        for try await chunk in ProcessRunner.output("/usr/bin/printf", ["%s", "λ🙂"]) { output.append(chunk) }
        XCTAssertEqual(String(decoding: output, as: UTF8.self), "λ🙂")
    }
    func testExplicitChoiceLabelsResolveWithoutFuzzyMatching() throws {
        let source = #"{"id":"q","kind":"choice","skill":"recall","prompt":"Which scope?","options":["A. Global","B. Enclosing","C. Local"],"answer":"B","explanation":"Enclosing scope."}"#
        let question = try JSONDecoder().decode(Question.self, from: Data(source.utf8))
        XCTAssertEqual(question.answer, "B. Enclosing")
        XCTAssertEqual(LearningEngine.grade("B. Enclosing", for: question)?.correct, true)
        let invalid = source.replacingOccurrences(of: "\"answer\":\"B\"", with: "\"answer\":\"enclose\"")
        XCTAssertEqual(try JSONDecoder().decode(Question.self, from: Data(invalid.utf8)).answer, "enclose")
    }
    func testEditorIsBundledWithNoNetworkPermission() throws {
        let url = try XCTUnwrap(WorkspaceResources.editorURL)
        let html = try String(contentsOf: url, encoding: .utf8)
        XCTAssertTrue(html.contains("connect-src 'none'"))
        XCTAssertTrue(html.contains("Note editor"))
    }
}
