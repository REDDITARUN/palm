import XCTest
@testable import PalmCore

/// Opt-in only. Credentials arrive in the process environment from a Keychain-reading launcher.
final class LiveProviderTests: XCTestCase {
    func testRealFlashcards() async throws {
        let env = ProcessInfo.processInfo.environment
        guard let key = env["PALM_LIVE_KEY"], let model = env["PALM_LIVE_MODEL"], model.hasSuffix(":free") else { throw XCTSkip("Live flashcard generation requires free-model opt-in.") }
        let config = ModelConfiguration(key: key, endpoint: "https://openrouter.ai/api/v1", model: model)
        let runtime = env["PALM_LIVE_RUNTIME"].map { RuntimeService(directory: URL(fileURLWithPath: $0)) }
        let ai = AIService(runtime: runtime)
        let note = StudyNote(title: "Python lists", body: "Python assignment b = a binds another name to the same list. Mutating b changes the shared list. b = a.copy() creates a shallow copy: the outer lists differ but nested objects remain shared. Example: a = [1, 2]; b = a; b.append(3); a is now [1, 2, 3]. A deep copy recursively copies nested objects. Do not claim that shallow copies isolate every nested object.")
        let deck = try await ai.flashcards(note: note, config: config)
        try deck.validate()
        XCTAssertGreaterThanOrEqual(deck.cards.count, 4)
        if let path = env["PALM_LIVE_OUTPUT"] { let url = URL(fileURLWithPath: path); try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true); try JSONEncoder().encode(deck).write(to: url.appendingPathComponent("flashcards.json")) }
        print("LIVE: valid flashcard deck received (\(deck.cards.count) cards).")
    }

    func testRealFreeModelLearningPipeline() async throws {
        let env = ProcessInfo.processInfo.environment
        guard let key = env["PALM_LIVE_KEY"], let model = env["PALM_LIVE_MODEL"] else { throw XCTSkip("Live provider tests require explicit opt-in.") }
        guard model.hasSuffix(":free") else { throw XCTSkip("This test is restricted to free model IDs.") }
        let config = ModelConfiguration(key: key, endpoint: "https://openrouter.ai/api/v1", model: model)
        let runtime = env["PALM_LIVE_RUNTIME"].map { RuntimeService(directory: URL(fileURLWithPath: $0)) }
        let ai = AIService(runtime: runtime, observeArtifact: { text in
            if let path = env["PALM_LIVE_OUTPUT"] { let dir = URL(fileURLWithPath: path); try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true); try? text.write(to: dir.appendingPathComponent("response-" + UUID().uuidString + ".txt"), atomically: true, encoding: .utf8) }
        })
        let started = Date()
        let models = try await ai.validateKey(config); XCTAssertTrue(models.contains(model))
        let topic = "Python closures: lexical scope, nonlocal, and separate counter instances. Exactly two focused lessons and a final application checkpoint."
        let outline = try await ai.outline(topic: topic, level: "Some familiarity", diagnostic: "Knows Python functions and variables; unsure how captured state survives.", context: "No retrieved sources. Teach stable Python fundamentals and do not invent citations.", config: config)
        print("LIVE: valid course outline received."); fflush(stdout)
        let course = Course(topic: topic, level: "Some familiarity", repositoryID: nil, outline: outline)
        guard let lesson = course.lessons.first else { return XCTFail("No generated lessons") }
        let content = try await ai.lesson(course: course, lesson: lesson, context: "No retrieved sources. Do not invent citations.", memory: "Prefers concise code examples and explanations of why.", review: false, config: config)
        print("LIVE: valid lesson received."); fflush(stdout)
        XCTAssertNotNil(content.prediction)
        XCTAssertGreaterThanOrEqual(content.questions.count, 8)
        XCTAssertGreaterThanOrEqual(Set(content.questions.map(\.kind)).count, 3)
        let question = Question(id: "live-rubric", kind: .explain, skill: "explain", prompt: "Why can a returned Python inner function still access a local variable from the outer function after the outer function returns?", code: "", options: [], answer: "The inner function retains references to the bindings in its enclosing lexical environment. A closure keeps those bindings accessible after the outer invocation ends.", acceptedAnswers: [], explanation: "A closure retains access to enclosing bindings; it does not make locals global.", hints: [], sourceIDs: [])
        let correct = try await ai.evaluate(answer: "The inner function closes over the outer binding and keeps a reference to it. That environment remains accessible through the closure after return.", question: question, config: config)
        let wrong = try await ai.evaluate(answer: "Python automatically turns every local variable into a global variable when a function returns.", question: question, config: config)
        XCTAssertTrue(correct.correct); XCTAssertFalse(correct.uncertain)
        XCTAssertFalse(wrong.correct); XCTAssertFalse(wrong.uncertain)
        let tutor = try await ai.tutor("Briefly explain why two separate calls to a Python counter factory can retain independent state. No external sources are supplied; do not invent any.", config: config)
        XCTAssertFalse(tutor.isEmpty)
        if let path = env["PALM_LIVE_OUTPUT"] {
            let directory = URL(fileURLWithPath: path); try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            try encoder.encode(course).write(to: directory.appendingPathComponent("course.json"))
            try encoder.encode(content).write(to: directory.appendingPathComponent("lesson.json"))
            try encoder.encode([correct, wrong]).write(to: directory.appendingPathComponent("grading.json"))
            try tutor.write(to: directory.appendingPathComponent("tutor.md"), atomically: true, encoding: .utf8)
        }
        print("LIVE PASS: \(model), \(course.lessons.count) lessons, \(content.questions.count) questions, correct/incorrect rubric grading, tutor. \(Int(Date().timeIntervalSince(started))) seconds.")
    }
    func testRealRepositoryExploration() async throws {
        let env = ProcessInfo.processInfo.environment
        guard let key = env["PALM_LIVE_KEY"], let model = env["PALM_LIVE_MODEL"], let root = env["PALM_LIVE_RUNTIME"], let repository = env["PALM_LIVE_REPO"] else { throw XCTSkip("Live repository test requires explicit opt-in.") }
        guard model.hasSuffix(":free") else { throw XCTSkip("Free model IDs only.") }
        let directory = URL(fileURLWithPath: root)
        let snapshot = try await RepositoryService(directory: directory).importFolder(URL(fileURLWithPath: repository))
        let runtime = RuntimeService(directory: directory)
        let evidence = try await runtime.explore(repository: snapshot, topic: "Explain make_counter and the captured value, using the real symbols and code.", configuration: ModelConfiguration(key: key, endpoint: "https://openrouter.ai/api/v1", model: model))
        XCTAssertTrue(evidence.contains("make_counter")); XCTAssertTrue(evidence.contains("main.py"))
        try evidence.write(to: directory.appendingPathComponent("repository-evidence.md"), atomically: true, encoding: .utf8)
        print("LIVE PASS: read-only OpenCode + Serena repository exploration with \(model).")
    }

    func testRealRepositoryCourseLifecycle() async throws {
        let env = ProcessInfo.processInfo.environment
        guard env["PALM_LIVE_LIFECYCLE"] == "1", let key = env["PALM_LIVE_KEY"],
              let model = env["PALM_LIVE_MODEL"], model.hasSuffix(":free"),
              let runtimePath = env["PALM_LIVE_RUNTIME"], let repoPath = env["PALM_LIVE_REPO"] else {
            throw XCTSkip("Full live lifecycle requires explicit free-model opt-in.")
        }
        let root = URL(fileURLWithPath: runtimePath).appendingPathComponent("lifecycle-" + UUID().uuidString)
        let db = try LocalDatabase(directory: root)
        let repositoryService = RepositoryService(directory: root)
        let repository = try await repositoryService.importFolder(URL(fileURLWithPath: repoPath))
        let runtime = RuntimeService(directory: URL(fileURLWithPath: runtimePath))
        let config = ModelConfiguration(key: key, endpoint: "https://openrouter.ai/api/v1", model: model)
        let ai = AIService(runtime: runtime, observeArtifact: { text in
            try? text.write(to: root.appendingPathComponent("response-" + UUID().uuidString + ".txt"), atomically: true, encoding: .utf8)
        })
        let topic = "Understand this small Python counter repository: captured state and independent instances. Exactly two lessons plus one final application checkpoint; no additional lessons."
        let native = try await repositoryService.context(for: repository, topic: topic)
        let evidence = try await runtime.explore(repository: repository, topic: topic, configuration: config)
        let context = native + "\n" + evidence
        print("LIFECYCLE: repository explored."); fflush(stdout)
        let outline = try await ai.outline(topic: topic, level: "Some familiarity", diagnostic: "Knows functions; wants to understand how this repository preserves state.", context: context, config: config)
        let course = Course(topic: topic, level: "Some familiarity", repositoryID: repository.id, outline: outline)
        guard course.lessons.count == 3, course.lessons.last?.isCheckpoint == true else { return XCTFail("The requested three-lesson plan and final checkpoint were not generated.") }
        var data = AppData(); data.courses = [course]; data.repositories = [repository]
        try db.save(data)
        var questionCount = 0
        for lesson in course.lessons {
            let content = try await ai.lesson(course: data.courses[0], lesson: lesson, context: context, memory: "Use concise examples. Earlier completed topics: " + data.courses[0].completedLessonIDs.joined(separator: ", "), review: false, config: config)
            XCTAssertFalse(content.sources.isEmpty, "Repository learning must retain source evidence.")
            var session = StudySession(courseID: course.id, lessonID: lesson.id, content: content, snapshotID: repository.snapshotID)
            session.snapshotPath = repository.snapshotPath; session.isCheckpoint = lesson.isCheckpoint; session.stage = .practice
            for (index, question) in content.questions.enumerated() {
                session.questionIndex = index
                session.drafts[question.id] = question.answer
                // Scripted canonical answers exercise transport, grading, and persistence; they do not measure learning.
                let grade: Grade
                if let objective = LearningEngine.grade(question.answer, for: question) { grade = objective }
                else { grade = try await ai.evaluate(answer: question.answer, question: question, config: config) }
                XCTAssertTrue(grade.correct || grade.uncertain, "The generated answer must satisfy its own rubric or be flagged ambiguous.")
                session.attempts.append(Attempt(questionID: question.id, answer: question.answer, grade: grade, hintsUsed: 0, revealed: false))
                if let i = data.sessions.firstIndex(where: { $0.id == session.id }) { data.sessions[i] = session } else { data.sessions.append(session) }
                try db.save(data)
                data = try db.load()
                XCTAssertEqual(data.sessions.last?.attempts.count, index + 1)
            }
            questionCount += content.questions.count
            data = try LearningEngine.completing(data, sessionID: session.id)
            try db.save(data)
            XCTAssertEqual(data.notes.last?.sessionID, data.sessions.first?.id)
            print("LIFECYCLE: completed \(lesson.title), \(content.questions.count) questions."); fflush(stdout)
        }
        XCTAssertTrue(data.courses[0].isComplete)
        XCTAssertEqual(data.notes.count, 3); XCTAssertEqual(data.reviews.count, 3)
        let review = try XCTUnwrap(data.reviews.first)
        let lesson = try XCTUnwrap(course.lessons.first { $0.id == review.lessonID })
        let fresh = try await ai.lesson(course: course, lesson: lesson, context: context, memory: "Delayed review; use different examples from the original.", review: true, config: config)
        var session = StudySession(courseID: course.id, lessonID: lesson.id, content: fresh, snapshotID: repository.snapshotID)
        session.snapshotPath = repository.snapshotPath; session.isReview = true; session.reviewItemID = review.id; session.stage = .practice
        for question in fresh.questions {
            let grade: Grade
            if let objective = LearningEngine.grade(question.answer, for: question) { grade = objective }
            else { grade = try await ai.evaluate(answer: question.answer, question: question, config: config) }
            session.attempts.append(Attempt(questionID: question.id, answer: question.answer, grade: grade, hintsUsed: 0, revealed: false))
        }
        session.questionIndex = fresh.questions.count - 1; data.sessions.append(session)
        data = try LearningEngine.completing(data, sessionID: session.id)
        try db.save(data)
        XCTAssertEqual(data.reviews.count, 3)
        XCTAssertEqual(data.reviews.first { $0.id == review.id }?.repetitions, review.repetitions + 1)
        try LearningEngine.validateLibrary(data)
        let backup = root.appendingPathComponent("completed.palmbackup")
        try db.exportBackup(data, to: backup)
        let reopened = try LocalDatabase(directory: root.appendingPathComponent("restored"))
        let restored = try reopened.restoreBackup(from: backup)
        XCTAssertTrue(restored.courses[0].isComplete); XCTAssertEqual(restored.notes.count, 4)
        XCTAssertEqual(restored.sessions.flatMap(\.attempts).count, questionCount + fresh.questions.count)
        print("LIFECYCLE PASS: three repository lessons, \(questionCount) questions, fresh review, saved notes, scheduling, reopen, and portable restore. Artifacts: \(root.path)")
    }

    func testRealRefinedRecap() async throws {
        let env = ProcessInfo.processInfo.environment
        guard env["PALM_LIVE_NOTES"] == "1", let key = env["PALM_LIVE_KEY"], let model = env["PALM_LIVE_MODEL"], model.hasSuffix(":free"), let path = env["PALM_LIVE_RUNTIME"] else { throw XCTSkip("Live notes test requires explicit opt-in.") }
        let root = URL(fileURLWithPath: path)
        let content = try JSONDecoder().decode(LessonContent.self, from: Data(contentsOf: root.appendingPathComponent("ux-lesson.json")))
        var session = StudySession(courseID: UUID(), lessonID: "functions", content: content, snapshotID: nil)
        session.recall = "Arguments go into the function; return sends a value back. I confused returning and printing."
        var preferences = Preferences()
        preferences.teachingPrompts = ["afterLesson": TeachingPromptKind.afterLesson.defaultText + " Include a small Mermaid flow to help me remember the difference between return and print."]
        let ai = AIService(runtime: RuntimeService(directory: root))
        let recap = try await ai.recap(session: session, preferences: preferences, config: ModelConfiguration(key: key, endpoint: "https://openrouter.ai/api/v1", model: model))
        XCTAssertTrue(recap.contains("```mermaid"))
        XCTAssertGreaterThan(recap.count, 300)
        try recap.write(to: root.appendingPathComponent("refined-recap.md"), atomically: true, encoding: .utf8)
    }

    func testRealChoiceDiagnosticAndSemanticShortAnswers() async throws {
        let env = ProcessInfo.processInfo.environment
        guard env["PALM_LIVE_UX"] == "1", let key = env["PALM_LIVE_KEY"], let model = env["PALM_LIVE_MODEL"], model.hasSuffix(":free"), let path = env["PALM_LIVE_RUNTIME"] else { throw XCTSkip("Live UX grading check requires explicit opt-in.") }
        let ai = AIService(runtime: RuntimeService(directory: URL(fileURLWithPath: path)))
        let config = ModelConfiguration(key: key, endpoint: "https://openrouter.ai/api/v1", model: model)
        let check = try await ai.diagnostic(topic: "Python closures and independent state", level: "Some familiarity", config: config)
        XCTAssertEqual(check.questions.count, 3); try check.validate()
        let question = Question(id: "output", kind: .trace, skill: "trace", prompt: "What values does this print, in order?", code: "print(1)\nprint(2)\nprint(1)", options: [], answer: "1, 2, 1", acceptedAnswers: [], explanation: "The three print calls output 1, then 2, then 1.", hints: [], sourceIDs: [])
        XCTAssertNil(LearningEngine.grade("It prints 1 then 2 then 1.", for: question))
        let equivalent = try await ai.evaluate(answer: "It prints 1 then 2 then 1, each on its own line.", question: question, config: config)
        let wrong = try await ai.evaluate(answer: "1, 2, 3", question: question, config: config)
        XCTAssertTrue(equivalent.correct); XCTAssertFalse(equivalent.uncertain)
        XCTAssertFalse(wrong.correct); XCTAssertFalse(wrong.uncertain)
        let lesson = LessonOutline(id: "functions", title: "Functions, arguments, and returns", objective: "Trace positional arguments and explain how a Python function returns a value.", minutes: 12, prerequisites: [])
        let course = Course(topic: "Python fundamentals", level: "Some familiarity", repositoryID: nil, outline: CourseOutline(title: "Python foundations", summary: "", outcomes: [], modules: [CourseModule(id: "basics", title: "Basics", lessons: [lesson])]))
        let content = try await ai.lesson(course: course, lesson: lesson, context: "No external sources supplied. Teach stable Python fundamentals.", memory: "Prefers a mix of choice questions and short written thinking.", review: false, config: config)
        try LearningEngine.validateQuestionMix(content)
        XCTAssertEqual(content.title, lesson.title)
        try JSONEncoder().encode(content).write(to: URL(fileURLWithPath: path).appendingPathComponent("ux-lesson.json"))
        var recapSession = StudySession(courseID: course.id, lessonID: lesson.id, content: content, snapshotID: nil)
        recapSession.recall = "I think arguments go into the function and return sends the result back to the caller."
        if let q = content.questions.first {
            recapSession.attempts = [Attempt(questionID: q.id, answer: "The function prints its return value automatically", grade: Grade(correct: false, feedback: "Returning a value passes it to the caller; printing displays it. Those are different actions.", misconception: "Confuses return with print"), hintsUsed: 0, revealed: false)]
        }
        var preferences = Preferences()
        preferences.teachingPrompts = ["afterLesson": TeachingPromptKind.afterLesson.defaultText + " Include a small Mermaid flow that distinguishes returning a value from printing it."]
        let recap = try await ai.recap(session: recapSession, preferences: preferences, config: config)
        XCTAssertTrue(recap.contains("```mermaid"))
        XCTAssertGreaterThan(recap.count, 300)
        try recap.write(to: URL(fileURLWithPath: path).appendingPathComponent("ux-recap.md"), atomically: true, encoding: .utf8)
        let output = URL(fileURLWithPath: path).appendingPathComponent("ux-grading.json")
        try JSONEncoder().encode([equivalent, wrong]).write(to: output)
        print("UX LIVE PASS: three choice diagnostic questions; equivalent prose accepted for code output; wrong output rejected; generated lesson has \(content.questions.filter { $0.kind.usesOptions }.count) choice questions out of \(content.questions.count).")
    }

}
