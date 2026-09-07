import Foundation

public struct CourseDayPlan: Identifiable {
    public var course: Course
    public var resume: StudySession?
    public var reviews: [ReviewItem]
    public var cards: [Flashcard]
    public var next: LessonOutline?
    public var lastPractice: Date?
    public var id: UUID { course.id }
    public var priority: Int { resume != nil ? 0 : !reviews.isEmpty || !cards.isEmpty ? 1 : next != nil ? 2 : 3 }
}

public struct DailyPlan {
    public var courses: [CourseDayPlan]
    public var minutes: Int
    public var answers: Int
    public var topics: Int
    public var personalCards: [Flashcard]
    public init(_ data: AppData, now: Date = Date(), calendar: Calendar = .current) {
        let today = calendar.startOfDay(for: now)
        let parts = calendar.dateComponents([.year, .month, .day], from: now)
        let key = "\(parts.year!)-\(parts.month!)-\(parts.day!)"
        minutes = data.sessions.reduce(0) { total, session in
            total + max(0, session.activityByDay?[key] ?? (session.activityByDay == nil && calendar.isDate(session.createdAt, inSameDayAs: now) ? session.activeSeconds : 0))
        } / 60
        answers = LearningProgress.practiceDays(data, now: now, calendar: calendar).first { $0.date == today }?.count ?? 0
        topics = Set(data.sessions.filter { !$0.isReview && $0.completedAt.map { $0 >= today && $0 <= now } == true }.map { $0.courseID.uuidString + ":" + $0.lessonID }).count
        let dueCards = (data.flashcards ?? []).filter { !$0.paused && $0.due <= now }
        let personalIDs = Set(data.notes.filter { $0.courseID == nil }.map(\.id))
        personalCards = dueCards.filter { personalIDs.contains($0.noteID) }.sorted { $0.due < $1.due }
        courses = data.courses.filter { !$0.archived }.map { course in
            let sessions = data.sessions.filter { $0.courseID == course.id && $0.createdAt <= now }
            let noteIDs = Set(data.notes.filter { $0.courseID == course.id }.map(\.id))
            let cards = (data.flashcards ?? []).filter { noteIDs.contains($0.noteID) }
            let dates = sessions.flatMap { $0.attempts.map(\.createdAt) } + cards.flatMap { $0.reviews.map(\.date) }
            let resume = sessions.filter { $0.stage != .complete && $0.completedAt == nil }.max { a, b in
                (a.attempts.last?.createdAt ?? a.createdAt) < (b.attempts.last?.createdAt ?? b.createdAt)
            }
            return CourseDayPlan(course: course, resume: resume,
                reviews: data.reviews.filter { review in review.courseID == course.id && course.lessons.contains(where: { $0.id == review.lessonID }) && !review.paused && review.due <= now }.sorted { $0.due < $1.due },
                cards: dueCards.filter { noteIDs.contains($0.noteID) }.sorted { $0.due < $1.due },
                next: course.lessons.first { !course.completedLessonIDs.contains($0.id) && $0.prerequisites.allSatisfy(course.completedLessonIDs.contains) },
                lastPractice: dates.filter { $0 <= now }.max())
        }.sorted { a, b in
            if a.priority != b.priority { return a.priority < b.priority }
            // Spread new learning across courses that have had less recent attention.
            let left = a.lastPractice ?? .distantPast, right = b.lastPractice ?? .distantPast
            if left != right { return a.priority == 0 ? left > right : left < right }
            if a.course.createdAt != b.course.createdAt { return a.course.createdAt < b.course.createdAt }
            return a.id.uuidString < b.id.uuidString
        }
    }
}
