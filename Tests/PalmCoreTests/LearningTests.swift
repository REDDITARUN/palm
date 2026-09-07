import XCTest
@testable import PalmCore

final class LearningTests: XCTestCase {
    func question(kind: QuestionKind = .choice) -> Question {
        Question(id: "q1", kind: kind, skill: "recall", prompt: "Which value?", code: "", options: ["one", "two"], answer: "one", acceptedAnswers: ["1"], explanation: "One follows from the example.", hints: ["Count the first item."], sourceIDs: [])
    }
    func content() -> LessonContent {
        LessonContent(title: "A topic", introduction: "Start here", material: "A clear explanation.", workedExample: "A worked example.", takeaways: ["Remember the principle."], questions: [question()], sources: [])
    }
    func testGradingPreservesOptionIdentityAndDefersWrittenAnswers() {
        XCTAssertTrue(LearningEngine.grade("one", for: question())!.correct)
        XCTAssertFalse(LearningEngine.grade("ONE", for: question())!.correct)
        XCTAssertFalse(LearningEngine.grade("1", for: question())!.correct)
        XCTAssertFalse(LearningEngine.grade("two", for: question())!.correct)
        XCTAssertNil(LearningEngine.grade("an explanation", for: question(kind: .explain)))
        XCTAssertNil(LearningEngine.grade("an application", for: question(kind: .transfer)))
    }
    func testQuestionDecodingDefaultsOnlyAuxiliaryFields() throws {
        var object = try JSONSerialization.jsonObject(with: JSONEncoder().encode(question())) as! [String: Any]
        for key in ["acceptedAnswers", "sourceIDs", "hints", "code"] { object.removeValue(forKey: key) }
        let decoded = try JSONDecoder().decode(Question.self, from: JSONSerialization.data(withJSONObject: object))
        XCTAssertTrue(decoded.acceptedAnswers.isEmpty); XCTAssertTrue(decoded.sourceIDs.isEmpty)
        XCTAssertTrue(decoded.hints.isEmpty); XCTAssertEqual(decoded.code, "")
        XCTAssertEqual(decoded.answer, "one")
        object.removeValue(forKey: "answer")
        XCTAssertThrowsError(try JSONDecoder().decode(Question.self, from: JSONSerialization.data(withJSONObject: object)))
    }

    func testRepositoryEvidenceUsesExactSnapshotLocations() {
        let evidence = "SOURCE src/main.py [sha256:" + String(repeating: "a", count: 64) + "]\nprint(1)\nEND SOURCE\nAgent metadata: /tmp/agent/.serena/project.yml and https://example.com"
        XCTAssertEqual(AIService.evidenceLocations(in: evidence), ["src/main.py"])
        XCTAssertEqual(AIService.evidenceLocations(in: "Official docs: [Python](https://docs.python.org/3/reference/)"), ["https://docs.python.org/3/reference/"])
        XCTAssertTrue(AIService.evidenceLocations(in: "No sources supplied.").isEmpty)
    }

    func testEveryWrittenAnswerUsesSemanticGrading() {
        for kind in [QuestionKind.cloze, .trace, .explain, .diagnose, .transfer] {
            XCTAssertTrue(kind.needsModelGrading)
            XCTAssertNil(LearningEngine.grade("one", for: question(kind: kind)))
        }
        for kind in [QuestionKind.choice, .trueFalse, .order] { XCTAssertFalse(kind.needsModelGrading) }
    }
    func testStartingCheckRequiresUsefulDistinctChoices() throws {
        let questions = (1...3).map { DiagnosticQuestion(id: "d\($0)", prompt: "Choose a result", options: ["One", "Two", "Three"]) }
        XCTAssertNoThrow(try DiagnosticCheck(questions: questions).validate())
        var invalid = questions; invalid[0].options = ["One", "One", "Two"]
        XCTAssertThrowsError(try DiagnosticCheck(questions: invalid).validate())
    }
    func testLessonMixIncludesChoicesAndWrittenThinking() throws {
        var lesson = content(); lesson.questions = (1...6).map { index in var q = question(kind: .explain); q.id = "q\(index)"; return q }
        XCTAssertThrowsError(try LearningEngine.validateQuestionMix(lesson))
        lesson.questions[0].kind = .choice; lesson.questions[2].kind = .trueFalse
        XCTAssertNoThrow(try LearningEngine.validateQuestionMix(lesson))
    }
    func testReadingNoteOmitsDuplicateHeadingWithoutChangingStoredMarkdown() {
        let note = StudyNote(title: "Closures", body: "# Closures\n\n## Key ideas\n\nIndependent state.")
        XCTAssertEqual(NoteFormatting.readingBody(note), "## Key ideas\n\nIndependent state.")
        XCTAssertTrue(note.body.hasPrefix("# Closures"))
        var personal = note; personal.title = "My thoughts"
        XCTAssertEqual(NoteFormatting.readingBody(personal), note.body)
    }

    func testInvalidAnswerKeyIsRejected() {
        var lesson = content(); lesson.questions[0].answer = "not an option"
        XCTAssertThrowsError(try LearningEngine.validate(lesson))
        lesson = content(); lesson.questions.append(lesson.questions[0])
        XCTAssertThrowsError(try LearningEngine.validate(lesson))
        lesson = content(); lesson.questions[0].sourceIDs = ["invented"]
        XCTAssertThrowsError(try LearningEngine.validate(lesson))
    }
    func testPrerequisiteCycleIsRejected() {
        let a = LessonOutline(id: "a", title: "A", objective: "Explain", minutes: 10, prerequisites: ["b"])
        let b = LessonOutline(id: "b", title: "B", objective: "Apply", minutes: 10, prerequisites: ["a"])
        let outline = CourseOutline(title: "Test", summary: "", outcomes: [], modules: [CourseModule(id: "m1", title: "Module", lessons: [a, b])])
        XCTAssertThrowsError(try LearningEngine.validate(outline))
    }
    func testAssistanceAndDisputesDoNotCountAsIndependent() {
        var attempt = Attempt(questionID: "q1", answer: "one", grade: Grade(correct: true, feedback: "Yes"), hintsUsed: 0, revealed: false)
        XCTAssertTrue(attempt.independent)
        attempt.hintsUsed = 1; XCTAssertFalse(attempt.independent)
        attempt.hintsUsed = 0; attempt.disputed = true; XCTAssertFalse(attempt.independent)
        attempt.disputed = false; attempt.grade.uncertain = true; XCTAssertFalse(attempt.independent)
    }
    func testSchedulePreservesIdentityAndIgnoresDisputedEvidence() throws {
        let item = ReviewItem(courseID: UUID(), lessonID: "lesson", title: "Title")
        var attempt = Attempt(questionID: "q1", answer: "one", grade: Grade(correct: true, feedback: "Yes"), hintsUsed: 0, revealed: false)
        let time = Date(timeIntervalSince1970: 1_780_000_000)
        let scheduled = try ReviewScheduler.schedule(item, attempts: [attempt], now: time)
        XCTAssertEqual(item.id, scheduled.id); XCTAssertEqual(scheduled.repetitions, 1)
        XCTAssertGreaterThan(scheduled.due, time); XCTAssertNotNil(scheduled.cardJSON)
        attempt.disputed = true
        XCTAssertEqual(try ReviewScheduler.schedule(scheduled, attempts: [attempt], now: time), scheduled)
    }
    func testPersistenceRecoverySearchRevisionsAndExport() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let db = try LocalDatabase(directory: root)
        var data = AppData()
        let course = backupCourse()
        data.courses = [course]
        var session = StudySession(courseID: course.id, lessonID: "lesson", content: content())
        session.drafts["q1"] = "half written answer"; session.hints["q1"] = 1
        session.messages = [ChatMessage(role: "user", content: "Why?")]
        data.sessions = [session]
        let note = StudyNote(title: "Closures", body: "Independent lexical environments.")
        data.notes = [note]
        try db.save(data, revision: NoteRevision(note: note))
        let reopened = try LocalDatabase(directory: root).load()
        XCTAssertEqual(reopened.sessions.first?.drafts["q1"], "half written answer")
        XCTAssertEqual(reopened.sessions.first?.messages.count, 1)
        XCTAssertEqual(try db.searchNotes("lexical"), [note.id])
        XCTAssertEqual(try db.revisions(for: note.id).count, 1)
        let export = root.appendingPathComponent("export.json")
        try db.export(data, to: export)
        XCTAssertEqual(try db.importData(from: export).sessions, data.sessions)
        let backup = root.appendingPathComponent("backup.sqlite")
        try db.backup(to: backup); XCTAssertTrue(FileManager.default.fileExists(atPath: backup.path))
    }
    private func backupCourse() -> Course {
        Course(topic: "Topic", level: "Fundamentals", repositoryID: nil, outline: CourseOutline(title: "Topic", summary: "", outcomes: [], modules: [CourseModule(id: "module", title: "Module", lessons: [LessonOutline(id: "lesson", title: "Lesson", objective: "Explain", minutes: 10, prerequisites: [])])]))
    }

    func testPortableBackupRestoresSnapshotsRevisionsAndDrafts() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let source = try LocalDatabase(directory: root.appendingPathComponent("source"))
        let snapshot = root.appendingPathComponent("original-snapshot")
        try FileManager.default.createDirectory(at: snapshot, withIntermediateDirectories: true)
        try "let original = 42".write(to: snapshot.appendingPathComponent("main.swift"), atomically: true, encoding: .utf8)
        var data = AppData(); let course = backupCourse(); data.courses = [course]
        var session = StudySession(courseID: course.id, lessonID: "lesson", content: content())
        session.snapshotPath = snapshot.path; session.snapshotID = UUID(); session.drafts["q1"] = "unfinished"
        data.sessions = [session]
        var note = StudyNote(title: "Before", body: "Original explanation", courseID: course.id, sessionID: session.id)
        let revision = NoteRevision(note: note); note.title = "After"; data.notes = [note]
        var memory = LearnerMemory(text: "A user correction", courseID: course.id, sourceIDs: [])
        memory.vectorID = "old-local-index"; data.memories = [memory]
        data.jobs = [GenerationJob(kind: "lesson", title: "In progress")]
        try source.save(data, revision: revision)
        let archive = root.appendingPathComponent("portable.palmbackup")
        try source.exportBackup(data, to: archive)
        try FileManager.default.removeItem(at: snapshot)
        let destination = try LocalDatabase(directory: root.appendingPathComponent("destination"))
        let restored = try destination.restoreBackup(from: archive)
        XCTAssertEqual(restored.sessions[0].drafts["q1"], "unfinished")
        XCTAssertEqual(try destination.revisions(for: note.id).first?.title, "Before")
        XCTAssertEqual(restored.notes[0].title, "After")
        XCTAssertEqual(restored.jobs[0].status, "interrupted")
        XCTAssertNil(restored.memories[0].vectorID)
        XCTAssertEqual(try String(contentsOfFile: restored.sessions[0].snapshotPath! + "/main.swift", encoding: .utf8), "let original = 42")
        XCTAssertEqual(try destination.searchNotes("explanation"), [note.id])
        XCTAssertEqual(try LocalDatabase(directory: destination.directory).load().sessions[0].drafts["q1"], "unfinished")
    }

    func testInvalidRestoreLeavesExistingLibraryUntouched() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let db = try LocalDatabase(directory: root)
        var existing = AppData(); existing.notes = [StudyNote(title: "Keep me", body: "My notes")]
        try db.save(existing)
        var invalid = AppData(); invalid.courses = [backupCourse()]
        invalid.sessions = [StudySession(courseID: UUID(), lessonID: "lesson", content: content())]
        let file = root.appendingPathComponent("invalid.json"); try db.export(invalid, to: file)
        XCTAssertThrowsError(try db.restoreJSON(from: file))
        XCTAssertEqual(try db.load().notes[0].title, "Keep me")
        invalid.sessions = []; invalid.courses.append(invalid.courses[0]); try db.export(invalid, to: file)
        XCTAssertThrowsError(try db.restoreJSON(from: file))
        XCTAssertEqual(try db.load().notes[0].title, "Keep me")
    }

    func testBackupRejectsSnapshotSymlinks() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let db = try LocalDatabase(directory: root)
        let snapshot = root.appendingPathComponent("snapshot")
        try FileManager.default.createDirectory(at: snapshot, withIntermediateDirectories: true)
        try FileManager.default.createSymbolicLink(at: snapshot.appendingPathComponent("outside"), withDestinationURL: root.appendingPathComponent("plam.sqlite"))
        var data = AppData(); let course = backupCourse(); data.courses = [course]
        var session = StudySession(courseID: course.id, lessonID: "lesson", content: content()); session.snapshotPath = snapshot.path; data.sessions = [session]
        XCTAssertThrowsError(try db.exportBackup(data, to: root.appendingPathComponent("unsafe.palmbackup")))
    }

    func testUnreadableLibraryIsNotSilentlyReplaced() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try Data("not a database".utf8).write(to: root.appendingPathComponent("plam.sqlite"))
        XCTAssertThrowsError(try LocalDatabase(directory: root))
    }
    func testRepositorySnapshotExcludesSecretsAndDetectsChanges() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let source = root.appendingPathComponent("repo")
        try FileManager.default.createDirectory(at: source, withIntermediateDirectories: true)
        try "let value = 1".write(to: source.appendingPathComponent("main.swift"), atomically: true, encoding: .utf8)
        try "PRIVATE".write(to: source.appendingPathComponent(".env"), atomically: true, encoding: .utf8)
        try "PRIVATE".write(to: source.appendingPathComponent("credentials.json"), atomically: true, encoding: .utf8)
        let service = RepositoryService(directory: root.appendingPathComponent("data"))
        let repo = try await service.importFolder(source)
        XCTAssertEqual(repo.fileCount, 1)
        let original = try await service.fingerprint(source); XCTAssertEqual(original, repo.fingerprint)
        try "let value = 2".write(to: source.appendingPathComponent("main.swift"), atomically: true, encoding: .utf8)
        let updated = try await service.fingerprint(source); XCTAssertNotEqual(updated, repo.fingerprint)
        let snapshot = try String(contentsOfFile: repo.snapshotPath + "/main.swift", encoding: .utf8)
        XCTAssertEqual(snapshot, "let value = 1")
    }
    func testCompletionIsAtomicIdempotentAndCreatesLinkedRecords() throws {
        var data = AppData()
        let lesson = LessonOutline(id: "lesson", title: "Lesson", objective: "Explain", minutes: 10, prerequisites: [])
        let course = Course(topic: "Topic", level: "Fundamentals", repositoryID: nil, outline: CourseOutline(title: "Topic", summary: "", outcomes: [], modules: [CourseModule(id: "m", title: "Module", lessons: [lesson])]))
        data.courses = [course]
        var session = StudySession(courseID: course.id, lessonID: lesson.id, content: content())
        data.sessions = [session]
        XCTAssertThrowsError(try LearningEngine.completing(data, sessionID: session.id))
        XCTAssertEqual(data.notes.count, 0)
        session.attempts = [Attempt(questionID: "q1", answer: "one", grade: Grade(correct: true, feedback: "Correct"), hintsUsed: 0, revealed: false)]
        session.recall = "My explanation"; data.sessions = [session]
        let completed = try LearningEngine.completing(data, sessionID: session.id)
        XCTAssertTrue(completed.courses[0].isComplete)
        XCTAssertEqual(completed.sessions[0].stage, .complete)
        XCTAssertEqual(completed.notes[0].sessionID, session.id)
        XCTAssertTrue(completed.notes[0].body.contains("My explanation"))
        XCTAssertEqual(completed.reviews.count, 1)
        let repeated = try LearningEngine.completing(completed, sessionID: session.id)
        XCTAssertEqual(repeated.notes.count, 1)
        XCTAssertEqual(repeated.reviews[0].repetitions, 1)
        XCTAssertEqual(repeated.sessions[0].completedAt, completed.sessions[0].completedAt)
    }

    func testCancellingWorkTerminatesItsChildProcess() async throws {
        let started = Date()
        let task = Task { try await ProcessRunner.run("/bin/sleep", ["20"]) }
        try await Task.sleep(for: .milliseconds(80)); task.cancel()
        do { _ = try await task.value; XCTFail("Cancelled process should not complete normally") } catch { }
        XCTAssertLessThan(Date().timeIntervalSince(started), 2)
    }

    func testUnambiguousClozeAndOrderingArtifacts() throws {
        var lesson = content()
        var cloze = question(); cloze.kind = .cloze; cloze.prompt = "Fill ___ and ___."
        lesson.questions = [cloze]; XCTAssertThrowsError(try LearningEngine.validate(lesson))
        cloze.prompt = "Fill ___."; lesson.questions = [cloze]; XCTAssertNoThrow(try LearningEngine.validate(lesson))
        var order = question(); order.kind = .order; order.options = ["Read", "Explain", "Apply"]; order.answer = "Read → Explain → Apply"
        lesson.questions = [order]; XCTAssertNoThrow(try LearningEngine.validate(lesson))
        order.answer = "Read → Read → Apply"; lesson.questions = [order]; XCTAssertThrowsError(try LearningEngine.validate(lesson))
    }
    func testCheckpointFlagAndOldSnapshotPathSurvivePersistence() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let database = try LocalDatabase(directory: root)
        var data = AppData(); var session = StudySession(courseID: UUID(), lessonID: "checkpoint", content: content())
        session.isCheckpoint = true; session.snapshotPath = "/immutable/original-snapshot"; session.activityByDay = ["2026-9-5": 60]
        data.sessions = [session]; try database.save(data)
        let restored = try database.load().sessions[0]
        XCTAssertEqual(restored.isCheckpoint, true); XCTAssertEqual(restored.snapshotPath, session.snapshotPath); XCTAssertEqual(restored.activityByDay, session.activityByDay)
    }

}
