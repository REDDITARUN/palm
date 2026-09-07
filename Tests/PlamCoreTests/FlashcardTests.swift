import XCTest
@testable import PlamCore

final class FlashcardTests: XCTestCase {
    func testLibraryWithoutNewFieldsStillDecodes() throws {
        var object = try JSONSerialization.jsonObject(with: JSONEncoder().encode(AppData())) as! [String: Any]
        object.removeValue(forKey: "flashcards")
        let decoded = try JSONDecoder().decode(AppData.self, from: JSONSerialization.data(withJSONObject: object))
        XCTAssertNil(decoded.flashcards)
    }
    func testCardReviewSchedulesAndIsIdempotent() throws {
        let now = Date(timeIntervalSince1970: 1_780_000_000)
        let card = Flashcard(noteID: UUID(), front: "What does `f()` return?", back: "A closure.")
        let encounter = UUID()
        let reviewed = try FlashcardEngine.reviewed(card, rating: .good, encounterID: encounter, now: now)
        XCTAssertEqual(reviewed.reviews.count, 1)
        XCTAssertNotNil(reviewed.cardJSON)
        XCTAssertGreaterThan(reviewed.due, now)
        XCTAssertEqual(try FlashcardEngine.reviewed(reviewed, rating: .again, encounterID: encounter, now: now), reviewed)
        let again = try FlashcardEngine.reviewed(card, rating: .again, encounterID: UUID(), now: now)
        XCTAssertLessThan(again.due, reviewed.due)
    }
    func testPersistenceAndPortableBackupKeepDeckAndHistory() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let db = try LocalDatabase(directory: root.appendingPathComponent("original"))
        var data = AppData(); let note = StudyNote(title: "Scope", body: "A closure retains an environment.")
        data.notes = [note]
        data.flashcards = [try FlashcardEngine.reviewed(Flashcard(noteID: note.id, front: "What is retained?", back: "The lexical environment."), rating: .hard, encounterID: UUID())]
        data.flashcardDrafts = [Flashcard(noteID: note.id, front: "A draft question?", back: "A draft answer.")]
        try db.save(data)
        XCTAssertEqual(try db.load().flashcards, data.flashcards)
        let backup = root.appendingPathComponent("backup")
        try db.exportBackup(data, to: backup)
        let restored = try LocalDatabase(directory: root.appendingPathComponent("restored")).restoreBackup(from: backup)
        XCTAssertEqual(restored.flashcards, data.flashcards)
        XCTAssertEqual(restored.flashcardDrafts, data.flashcardDrafts)
    }
    func testOrphanAndDuplicateReviewsRejectedOnRestore() throws {
        var data = AppData(); let note = StudyNote(); data.notes = [note]
        var card = Flashcard(noteID: UUID(), front: "Question", back: "Answer"); data.flashcards = [card]
        XCTAssertThrowsError(try LearningEngine.validateLibrary(data))
        card.noteID = note.id
        card = try FlashcardEngine.reviewed(card, rating: .good, encounterID: UUID())
        card.reviews.append(card.reviews[0]); data.flashcards = [card]
        XCTAssertThrowsError(try LearningEngine.validateLibrary(data))
    }
    func testDraftValidationAndDuplicateFronts() throws {
        XCTAssertThrowsError(try FlashcardEngine.validate(front: "  ", back: "Answer"))
        let deck = FlashcardDeck(cards: [.init(front: "One?", back: "Yes"), .init(front: " one? ", back: "Yes")])
        XCTAssertThrowsError(try deck.validate())
    }
    func testStreakUsesActualReviewDaysAndAllowsTodayPending() throws {
        var calendar = Calendar(identifier: .gregorian); calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let now = Date(timeIntervalSince1970: 1_780_000_000)
        var data = AppData(); var card = Flashcard(noteID: UUID(), front: "Q", back: "A")
        for offset in [1, 2, 4] { card.reviews.append(.init(id: UUID(), date: calendar.date(byAdding: .day, value: -offset, to: now)!, rating: .again)) }
        data.flashcards = [card]
        XCTAssertEqual(LearningProgress.streak(data, now: now, calendar: calendar), 2)
        XCTAssertEqual(LearningProgress.streak(data, now: calendar.date(byAdding: .day, value: 1, to: now)!, calendar: calendar), 0)
    }
    func testDescriptiveDuplicateTitleRemovedOnlyAtStart() {
        let note = StudyNote(title: "Sequences", body: "# Sequences: Taking the last items\n\nKeep this explanation.\n\n## More examples")
        XCTAssertTrue(NoteFormatting.readingBody(note).hasPrefix("Keep this explanation."))
        let different = StudyNote(title: "Sequences", body: "# Different idea\n\nKeep this title.")
        XCTAssertEqual(NoteFormatting.readingBody(different), different.body)
    }
    func testDuplicateCodeRemovalPreservesDifferentExamples() {
        let prompt = "What happens?\n```python\nprint(1)\n```\nCompare:\n```python\nprint(2)\n```"
        let cleaned = LearningEngine.removingRepeatedCode(from: prompt, code: "print(1)")
        XCTAssertFalse(cleaned.contains("print(1)"))
        XCTAssertTrue(cleaned.contains("print(2)"))
        XCTAssertTrue(cleaned.contains("What happens?"))
        XCTAssertEqual(LearningEngine.removingRepeatedCode(from: prompt, code: "print(3)"), prompt)
    }
    func testPredictionStoredSeparatelyFromAssessment() throws {
        var content = LearningTests().content()
        content.prediction = Prediction(prompt: "What happens?", options: ["A", "B"], explanation: "B follows.")
        var session = StudySession(courseID: UUID(), lessonID: "lesson", content: content)
        session.predictionAnswer = "A"; session.predictionRevealed = true
        let decoded = try JSONDecoder().decode(StudySession.self, from: JSONEncoder().encode(session))
        XCTAssertEqual(decoded.predictionAnswer, "A")
        XCTAssertTrue(decoded.attempts.isEmpty)
        XCTAssertEqual(decoded.independentCorrect, 0)
    }
}
