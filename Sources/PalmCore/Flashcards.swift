import Foundation
import FSRS

public struct Flashcard: Codable, Identifiable, Equatable {
    public var id = UUID()
    public var noteID: UUID
    public var front: String
    public var back: String
    public var createdAt = Date()
    public var updatedAt = Date()
    public var due = Date()
    public var paused = false
    public var cardJSON: Data?
    public var reviews: [FlashcardReview] = []
    public init(noteID: UUID, front: String, back: String) { self.noteID = noteID; self.front = front; self.back = back }
}
public struct FlashcardReview: Codable, Identifiable, Equatable {
    public var id: UUID
    public var date: Date
    public var rating: RecallRating
}
public enum RecallRating: String, Codable, CaseIterable, Identifiable {
    case again, hard, good, easy
    public var id: String { rawValue }
    public var label: String { switch self { case .again: "Again"; case .hard: "Hard"; case .good: "Good"; case .easy: "Easy" } }
    public var detail: String { switch self { case .again: "Couldn't recall"; case .hard: "Recalled with effort"; case .good: "Recalled correctly"; case .easy: "Immediate recall" } }
    var fsrs: Rating { switch self { case .again: .again; case .hard: .hard; case .good: .good; case .easy: .easy } }
}
public struct FlashcardDraft: Codable, Equatable, Identifiable {
    public var front: String
    public var back: String
    public var id: String { front }
    public init(front: String, back: String) { self.front = front; self.back = back }
}
public struct FlashcardDeck: Codable {
    public var cards: [FlashcardDraft]
    public func validate() throws {
        guard (1...12).contains(cards.count), Set(cards.map { LearningEngine.normalize($0.front) }).count == cards.count else { throw PalmError.message("Generate one to twelve distinct flashcards.") }
        for card in cards { try FlashcardEngine.validate(front: card.front, back: card.back) }
    }
}
public enum FlashcardEngine {
    public static func validate(front: String, back: String) throws {
        guard !front.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !back.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              front.count <= 4000, back.count <= 12000 else { throw PalmError.message("Each card needs a focused question and answer (up to 4,000 and 12,000 characters).") }
    }
    public static func reviewed(_ card: Flashcard, rating: RecallRating, encounterID: UUID, now: Date = Date()) throws -> Flashcard {
        guard !card.reviews.contains(where: { $0.id == encounterID }) else { return card }
        let scheduler = FSRS(parameters: .init(w: FSRSDefaults.defaultWv6))
        let previous = try card.cardJSON.map { try JSONDecoder().decode(Card.self, from: $0) } ?? Card(due: now)
        let next = try scheduler.next(card: previous, now: now, grade: rating.fsrs)
        var result = card
        result.cardJSON = try JSONEncoder().encode(next.card); result.due = next.card.due
        result.reviews.append(FlashcardReview(id: encounterID, date: now, rating: rating))
        return result
    }
}

public struct PracticeDay: Identifiable {
    public var date: Date
    public var count: Int
    public var id: Date { date }
}
public struct LearningBadge: Identifiable {
    public var id: String
    public var title: String
    public var detail: String
    public var icon: String
    public var earned: Bool
    public var progress: Int = 0
    public var target: Int = 1
    public var earnedAt: Date? = nil
}
public enum LearningProgress {
    public static func dates(_ data: AppData) -> [Date] {
        data.sessions.flatMap { $0.attempts.map(\.createdAt) } + (data.flashcards ?? []).flatMap { $0.reviews.map(\.date) }
    }
    public static func practiceDays(_ data: AppData, now: Date = Date(), calendar: Calendar = .current) -> [PracticeDay] {
        Dictionary(grouping: dates(data).filter { $0 <= now }, by: { calendar.startOfDay(for: $0) }).map { PracticeDay(date: $0.key, count: $0.value.count) }.sorted { $0.date < $1.date }
    }
    public static func streak(_ data: AppData, now: Date = Date(), calendar: Calendar = .current) -> Int {
        let days = Set(dates(data).map { calendar.startOfDay(for: $0) })
        var day = calendar.startOfDay(for: now)
        if !days.contains(day) { day = calendar.date(byAdding: .day, value: -1, to: day)! }
        var count = 0
        while days.contains(day) { count += 1; day = calendar.date(byAdding: .day, value: -1, to: day)! }
        return count
    }
    public static func longestStreak(_ data: AppData, now: Date = Date(), calendar: Calendar = .current) -> Int {
        var longest = 0, run = 0
        var previous: Date?
        for day in Set(dates(data).filter { $0 <= now }.map { calendar.startOfDay(for: $0) }).sorted() {
            run = previous.flatMap { calendar.dateComponents([.day], from: $0, to: day).day } == 1 ? run + 1 : 1
            longest = max(longest, run); previous = day
        }
        return longest
    }
    public static func badges(_ data: AppData, now: Date = Date(), calendar: Calendar = .current) -> [LearningBadge] {
        let solved = data.sessions.flatMap { session in session.attempts.filter { $0.independent && $0.grade.correct && $0.createdAt <= now }.compactMap { attempt in session.content.questions.first { $0.id == attempt.questionID }.map { ($0, attempt.createdAt) } } }.sorted { $0.1 < $1.1 }
        var topics: [String: Date] = [:]
        for session in data.sessions { if let date = session.completedAt, date <= now { let key = session.courseID.uuidString + ":" + session.lessonID; topics[key] = min(topics[key] ?? date, date) } }
        let completed = topics.values.sorted()
        let transfers = solved.filter { $0.0.skill == "transfer" }.map(\.1)
        let delayed = data.sessions.filter { session in session.isReview && data.sessions.contains { earlier in earlier.courseID == session.courseID && earlier.lessonID == session.lessonID && (earlier.completedAt.map { session.createdAt.timeIntervalSince($0) >= 86400 } ?? false) } }.flatMap { $0.attempts.filter { $0.independent && $0.grade.correct && $0.createdAt <= now }.map(\.createdAt) }.sorted()
        let cardDays = Set((data.flashcards ?? []).flatMap { $0.reviews.filter { $0.date <= now }.map { calendar.startOfDay(for: $0.date) } }).sorted()
        var courseDates: [Date] = []
        for course in data.courses where !course.lessons.isEmpty && course.lessons.allSatisfy({ course.completedLessonIDs.contains($0.id) }) {
            let dates = course.lessons.compactMap { topics[course.id.uuidString + ":" + $0.id] }; if dates.count == course.lessons.count, let date = dates.max() { courseDates.append(date) }
        }
        var streakDate: Date?, run = 0, previous: Date?
        for day in Set(dates(data).filter { $0 <= now }.map { calendar.startOfDay(for: $0) }).sorted() { run = previous.flatMap { calendar.dateComponents([.day], from: $0, to: day).day } == 1 ? run + 1 : 1; if run >= 7 && streakDate == nil { streakDate = day }; previous = day }
        func badge(_ id: String, _ title: String, _ detail: String, _ icon: String, _ count: Int, _ target: Int, _ date: Date?) -> LearningBadge { .init(id: id, title: title, detail: detail, icon: icon, earned: count >= target, progress: min(count, target), target: target, earnedAt: count >= target ? date : nil) }
        return [
            badge("first", "First steps", "Complete your first topic.", "leaf.fill", completed.count, 1, completed.first),
            badge("apply", "Put it to work", "Solve a transfer question without hints or a revealed answer.", "arrow.triangle.branch", transfers.count, 1, transfers.first),
            badge("recall", "It stayed with you", "Answer correctly on your own in a review at least a day after completing the topic.", "sparkles", delayed.count, 1, delayed.first),
            badge("cards", "Recall habit", "Review flashcards on three different days.", "rectangle.on.rectangle", cardDays.count, 3, cardDays.count >= 3 ? cardDays[2] : nil),
            badge("five", "Five topics", "Complete five different topics. Repeat sessions count once.", "square.stack.3d.up.fill", completed.count, 5, completed.count >= 5 ? completed[4] : nil),
            badge("week", "A week of practice", "Practice on seven consecutive days. Once earned, this stays yours.", "flame.fill", longestStreak(data, now: now, calendar: calendar), 7, streakDate),
            badge("independent", "On your own", "Answer 25 questions correctly without hints or revealed answers.", "bolt.fill", solved.count, 25, solved.count >= 25 ? solved[24].1 : nil),
            badge("course", "Course complete", "Complete every topic in a course.", "graduationcap.fill", courseDates.count, 1, courseDates.min())
        ]
    }
}
