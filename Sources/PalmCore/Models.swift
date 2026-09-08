import Foundation

public enum PalmError: LocalizedError {
    case message(String)
    public var errorDescription: String? { if case .message(let text) = self { return text }; return nil }
}

public struct Preferences: Codable, Equatable {
    public var name = ""
    public var dailyMinutes = 15
    public var model = "thinkingmachines/inkling:free"
    public var endpoint = "https://openrouter.ai/api/v1"
    public var appearance = "system"
    public var onboardingComplete = false
    public var providerConnections: [ProviderConnection]?
    public var selectedProviderID: UUID?
    public var teachingPrompts: [String: String]?
    public var featuredBadgeIDs: [String]?
    public var showStreak: Bool?
    public var readingSize: Double?
    public var reminderEnabled: Bool?
    public var reminderHour: Int?
    public var reminderMinute: Int?
    public var context7Key = "" // Reserved; credentials are read from Keychain, never persisted here.
    public init() {}
}

public struct DiagnosticQuestion: Codable, Identifiable, Equatable {
    public var id: String
    public var prompt: String
    public var options: [String]
}

public struct DiagnosticCheck: Codable {
    public var questions: [DiagnosticQuestion]
    public func validate() throws {
        guard (3...5).contains(questions.count), Set(questions.map(\.id)).count == questions.count,
              questions.allSatisfy({ !$0.id.isEmpty && !$0.prompt.isEmpty && (3...4).contains($0.options.count) && Set($0.options).count == $0.options.count && $0.options.allSatisfy { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty } }) else {
            throw PalmError.message("The starting-point check needs three to five unique questions with three or four distinct choices each.")
        }
    }
}

public struct CourseOutline: Codable, Equatable {
    public var title: String
    public var summary: String
    public var outcomes: [String]
    public var modules: [CourseModule]
}

public struct CourseModule: Codable, Identifiable, Equatable {
    public var id: String
    public var title: String
    public var lessons: [LessonOutline]
}

public struct LessonOutline: Codable, Identifiable, Equatable {
    public var id: String
    public var title: String
    public var objective: String
    public var minutes: Int
    public var prerequisites: [String]
    public var isCheckpoint: Bool?
}

public struct Course: Codable, Identifiable, Equatable {
    public var id = UUID()
    public var createdAt = Date()
    public var topic: String
    public var level: String
    public var repositoryID: UUID?
    public var outline: CourseOutline
    public var completedLessonIDs: [String] = []
    public var archived = false
    public var diagnostic: String = ""
    public var lessons: [LessonOutline] { outline.modules.flatMap(\.lessons) }
    public var progress: Double { lessons.isEmpty ? 0 : Double(completedLessonIDs.count) / Double(lessons.count) }
    public var isComplete: Bool { !lessons.isEmpty && lessons.allSatisfy { completedLessonIDs.contains($0.id) } }
    public init(topic: String, level: String, repositoryID: UUID?, outline: CourseOutline, diagnostic: String = "") {
        self.topic = topic; self.level = level; self.repositoryID = repositoryID; self.outline = outline; self.diagnostic = diagnostic
    }
}

public enum QuestionKind: String, Codable, CaseIterable {
    case choice, trueFalse, cloze, trace, explain, diagnose, order, transfer, diagramChoice
    public var label: String {
        switch self { case .diagramChoice: "Choose the flow"; case .choice: "Choose & reason"; case .trueFalse: "True or false"; case .cloze: "Fill the gap"; case .trace: "Trace the code"; case .explain: "Explain it"; case .diagnose: "Find the cause"; case .order: "Put it in order"; case .transfer: "Apply the idea" }
    }
    public var needsModelGrading: Bool { self != .choice && self != .trueFalse && self != .order && self != .diagramChoice }
    public var isLongAnswer: Bool { self == .explain || self == .diagnose || self == .transfer }
    public var usesOptions: Bool { self == .choice || self == .trueFalse || self == .diagramChoice }
}

public struct Question: Codable, Identifiable, Equatable {
    public var id: String
    public var kind: QuestionKind
    public var skill: String
    public var prompt: String
    public var code: String
    public var options: [String]
    public var answer: String
    public var acceptedAnswers: [String]
    public var explanation: String
    public var hints: [String]
    public var sourceIDs: [String]
    public var language: String? = nil
    public var diagrams: [DiagramChoice]? = nil
}

// Models commonly omit empty auxiliary arrays. Their absence has an unambiguous
// meaning; required assessment fields still fail decoding and schema validation.
extension Question {
    private enum CodingKeys: String, CodingKey { case id, kind, skill, prompt, code, options, answer, acceptedAnswers, explanation, hints, sourceIDs, language, diagrams }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        kind = try c.decode(QuestionKind.self, forKey: .kind)
        skill = try c.decode(String.self, forKey: .skill)
        prompt = try c.decode(String.self, forKey: .prompt)
        answer = try c.decode(String.self, forKey: .answer)
        explanation = try c.decode(String.self, forKey: .explanation)
        code = try c.decodeIfPresent(String.self, forKey: .code) ?? ""
        language = try c.decodeIfPresent(String.self, forKey: .language)
        diagrams = try c.decodeIfPresent([DiagramChoice].self, forKey: .diagrams)
        options = try c.decodeIfPresent([String].self, forKey: .options) ?? []
        acceptedAnswers = try c.decodeIfPresent([String].self, forKey: .acceptedAnswers) ?? []
        hints = try c.decodeIfPresent([String].self, forKey: .hints) ?? []
        sourceIDs = try c.decodeIfPresent([String].self, forKey: .sourceIDs) ?? []
        // A provider may explicitly label options and return that label as its key.
        // Resolve only a unique, explicit prefix; never guess an option by similarity.
        if kind == .choice, !options.contains(answer), answer.range(of: "^[A-Z0-9]$", options: .regularExpression) != nil {
            let candidates = options.filter { option in option.hasPrefix(answer + ". ") || option.hasPrefix(answer + ") ") || option.hasPrefix("(" + answer + ") ") }
            if candidates.count == 1 { answer = candidates[0] }
        }
    }
}

public struct LessonContent: Codable, Equatable {
    public var title: String
    public var introduction: String
    public var material: String
    public var workedExample: String
    public var takeaways: [String]
    public var questions: [Question]
    public var sources: [LearningSource]
    public var prediction: Prediction? = nil
}

public struct Prediction: Codable, Equatable {
    public var code: String? = nil
    public var language: String? = nil
    public var prompt: String
    public var options: [String]
    public var explanation: String
    public func validate() throws {
        if let code, code.contains("\\n    ") && !code.contains("\n") { throw PalmError.message("The prediction code contains double-escaped newlines. Encode newlines once so the decoded code spans real lines.") }
        guard !prompt.isEmpty, (2...4).contains(options.count), Set(options).count == options.count, options.allSatisfy({ !$0.isEmpty }), !explanation.isEmpty else { throw PalmError.message("The ungraded prediction needs a prompt, two to four unique choices, and an explanation.") }
    }
}

public struct LearningSource: Codable, Identifiable, Equatable {
    public var id: String
    public var title: String
    public var location: String
    public var excerpt: String
}

public struct Grade: Codable, Equatable {
    public var correct: Bool
    public var feedback: String
    public var misconception: String
    public var uncertain: Bool
    public init(correct: Bool, feedback: String, misconception: String = "", uncertain: Bool = false) {
        self.correct = correct; self.feedback = feedback; self.misconception = misconception; self.uncertain = uncertain
    }
}

public struct Attempt: Codable, Identifiable, Equatable {
    public var id = UUID()
    public var questionID: String
    public var answer: String
    public var grade: Grade
    public var hintsUsed: Int
    public var revealed: Bool
    public var disputed = false
    public var createdAt = Date()
    public var independent: Bool { hintsUsed == 0 && !revealed && !disputed && !grade.uncertain }
    public init(questionID: String, answer: String, grade: Grade, hintsUsed: Int, revealed: Bool) {
        self.questionID = questionID; self.answer = answer; self.grade = grade; self.hintsUsed = hintsUsed; self.revealed = revealed
    }
}

public enum LessonStage: String, Codable { case reading, practice, recap, complete }

public struct StudySession: Codable, Identifiable, Equatable {
    public var id = UUID()
    public var courseID: UUID
    public var lessonID: String
    public var createdAt = Date()
    public var completedAt: Date?
    public var content: LessonContent
    public var stage: LessonStage = .reading
    public var questionIndex = 0
    public var drafts: [String: String] = [:]
    public var hints: [String: Int] = [:]
    public var revealedIDs: [String] = []
    public var attempts: [Attempt] = []
    public var retryAttempts: [Attempt]?
    public var messages: [ChatMessage] = []
    public var recall = ""
    public var predictionAnswer: String?
    public var predictionRevealed: Bool?
    public var recallRevealed: Bool?
    public var tutorDraft: String?
    public var snapshotID: UUID?
    public var snapshotPath: String?
    public var activityByDay: [String: Int]?
    public var isReview = false
    public var isCheckpoint: Bool?
    public var reviewItemID: UUID?
    public var activeSeconds: Int = 0
    public var currentQuestion: Question? { content.questions.indices.contains(questionIndex) ? content.questions[questionIndex] : nil }
    public var independentCorrect: Int { attempts.filter { $0.grade.correct && $0.independent }.count }
    public init(courseID: UUID, lessonID: String, content: LessonContent, snapshotID: UUID? = nil) {
        self.courseID = courseID; self.lessonID = lessonID; self.content = content; self.snapshotID = snapshotID
    }
}

public struct ChatMessage: Codable, Identifiable, Equatable {
    public var isPartial: Bool?
    public var proposedNoteID: UUID?
    public var originalNoteBody: String?
    public var id = UUID()
    public var role: String
    public var content: String
    public var createdAt = Date()
    public var selection: String = ""
    public init(role: String, content: String, selection: String = "") { self.role = role; self.content = content; self.selection = selection }
}

public struct StudyNote: Codable, Identifiable, Equatable {
    public var blocksJSON: String?
    public var documentRevision: UUID?
    public var id = UUID()
    public var title = "Untitled note"
    public var body = ""
    public var tags: [String] = []
    public var courseID: UUID?
    public var sessionID: UUID?
    public var updatedAt = Date()
    public var createdAt = Date()
    public var pinned = false
    public init(title: String = "Untitled note", body: String = "", courseID: UUID? = nil, sessionID: UUID? = nil) {
        self.title = title; self.body = body; self.courseID = courseID; self.sessionID = sessionID
    }
}

public struct NoteRevision: Codable, Identifiable {
    public var blocksJSON: String?
    public var id = UUID()
    public var noteID: UUID
    public var body: String
    public var title: String
    public var createdAt = Date()
    public init(note: StudyNote) { noteID = note.id; body = note.body; title = note.title; blocksJSON = note.blocksJSON }
}

public struct LearnerMemory: Codable, Identifiable, Equatable {
    public var id = UUID()
    public var text: String
    public var courseID: UUID?
    public var sourceIDs: [UUID]
    public var createdAt = Date()
    public var forgotten = false
    public var userEdited = false
    public var vectorID: String?
    public init(text: String, courseID: UUID?, sourceIDs: [UUID]) { self.text = text; self.courseID = courseID; self.sourceIDs = sourceIDs }
}

public struct ReviewItem: Codable, Identifiable, Equatable {
    public var id = UUID()
    public var courseID: UUID
    public var lessonID: String
    public var title: String
    public var due = Date()
    public var lastReview: Date?
    public var repetitions = 0
    public var cardJSON: Data?
    public var paused = false
    public init(courseID: UUID, lessonID: String, title: String) { self.courseID = courseID; self.lessonID = lessonID; self.title = title }
}

public struct Repository: Codable, Identifiable, Equatable {
    public var id = UUID()
    public var name: String
    public var originalPath: String
    public var snapshotID = UUID()
    public var snapshotPath: String
    public var fingerprint: String
    public var fileCount: Int
    public var languages: [String]
    public var overview: String
    public var importedAt = Date()
    public var checkedAt = Date()
    public var stale = false
    public var analysisStatus = "Source snapshot ready"
    public init(name: String, originalPath: String, snapshotPath: String, fingerprint: String, fileCount: Int, languages: [String], overview: String) {
        self.name = name; self.originalPath = originalPath; self.snapshotPath = snapshotPath; self.fingerprint = fingerprint
        self.fileCount = fileCount; self.languages = languages; self.overview = overview
    }
}

public struct GenerationJob: Codable, Identifiable, Equatable {
    public var id = UUID()
    public var kind: String
    public var title: String
    public var status = "running"
    public var error: String?
    public var createdAt = Date()
    public var completedAt: Date?
    public init(kind: String, title: String) { self.kind = kind; self.title = title }
}

public struct RepositoryInsight: Codable, Identifiable {
    public var id = UUID()
    public var repositoryID: UUID
    public var snapshotID: UUID
    public var topic: String
    public var summary: String
    public var createdAt = Date()
    public init(repositoryID: UUID, snapshotID: UUID, topic: String, summary: String) { self.repositoryID = repositoryID; self.snapshotID = snapshotID; self.topic = topic; self.summary = summary }
}

public struct AppData: Codable {
    public var schemaVersion = 1
    public var preferences = Preferences()
    public var courses: [Course] = []
    public var sessions: [StudySession] = []
    public var notes: [StudyNote] = []
    public var flashcards: [Flashcard]?
    public var flashcardDrafts: [Flashcard]?
    public var memories: [LearnerMemory] = []
    public var reviews: [ReviewItem] = []
    public var repositories: [Repository] = []
    public var repositoryInsights: [RepositoryInsight]?
    public var conversations: [TutorConversation]?
    public var modelProfiles: [ModelProfile]?
    public var mcpServers: [MCPServerProfile]?
    public var agentSkills: [AgentSkillProfile]?
    public var jobs: [GenerationJob] = []
    public init() {}
}

public enum LearningEngine {
    /// Produce one atomic completion change. Saving is the caller's responsibility.
    public static func completing(_ data: AppData, sessionID: UUID, now: Date = Date()) throws -> AppData {
        guard let index = data.sessions.firstIndex(where: { $0.id == sessionID }) else { throw PalmError.message("This learning session could not be found.") }
        let session = data.sessions[index]
        guard session.completedAt == nil else { return data }
        guard Set(session.attempts.map(\.questionID)) == Set(session.content.questions.map(\.id)), session.attempts.count == session.content.questions.count else { throw PalmError.message("Finish the remaining questions before completing this topic.") }
        var next = data
        next.sessions[index].completedAt = now; next.sessions[index].stage = .complete
        if !session.isReview, let i = next.courses.firstIndex(where: { $0.id == session.courseID }), !next.courses[i].completedLessonIDs.contains(session.lessonID) { next.courses[i].completedLessonIDs.append(session.lessonID) }
        next.notes.insert(StudyNote(title: session.content.title, body: recap(session), courseID: session.courseID, sessionID: session.id), at: 0)
        let current = next.reviews.first { $0.courseID == session.courseID && $0.lessonID == session.lessonID } ?? ReviewItem(courseID: session.courseID, lessonID: session.lessonID, title: session.content.title)
        let review = try ReviewScheduler.schedule(current, attempts: session.attempts, now: now)
        if let i = next.reviews.firstIndex(where: { $0.id == review.id }) { next.reviews[i] = review } else { next.reviews.append(review) }
        for attempt in session.attempts where !attempt.disputed && !attempt.grade.uncertain && !attempt.grade.misconception.isEmpty {
            next.memories.append(LearnerMemory(text: attempt.grade.misconception, courseID: session.courseID, sourceIDs: [attempt.id]))
        }
        return next
    }

    public static func validateLibrary(_ data: AppData) throws {
        func require(_ condition: Bool, _ reason: String) throws {
            guard condition else { throw PalmError.message("The library cannot be restored: " + reason) }
        }
        func unique<T: Hashable>(_ ids: [T]) -> Bool { Set(ids).count == ids.count }
        try require(data.schemaVersion == 1, "unsupported library version.")
        try require(unique(data.courses.map(\.id)) && unique(data.sessions.map(\.id)) && unique(data.notes.map(\.id)) && unique(data.repositories.map(\.id)) && unique(data.reviews.map(\.id)) && unique(data.memories.map(\.id)) && unique(data.jobs.map(\.id)), "duplicate record identifiers.")
        let courses = Dictionary(uniqueKeysWithValues: data.courses.map { ($0.id, $0) })
        let sessions = Set(data.sessions.map(\.id)); let repositories = Set(data.repositories.map(\.id))
        let attempts = data.sessions.flatMap(\.attempts)
        try require(unique(attempts.map(\.id)), "duplicate attempt identifiers.")
        for course in data.courses {
            try validate(course.outline)
            try require(course.repositoryID.map(repositories.contains) ?? true, "a course references a missing repository.")
            let lessons = Set(course.lessons.map(\.id))
            try require(unique(course.completedLessonIDs) && course.completedLessonIDs.allSatisfy(lessons.contains), "course progress references unknown topics.")
        }
        for session in data.sessions {
            try validate(session.content)
            try require(courses[session.courseID]?.lessons.contains { $0.id == session.lessonID } == true, "a session references a missing course or topic.")
            let questions = Set(session.content.questions.map(\.id))
            try require(session.content.questions.indices.contains(session.questionIndex), "a saved question position is out of range.")
            try require(unique(session.attempts.map(\.questionID)) && session.attempts.allSatisfy { questions.contains($0.questionID) && $0.hintsUsed >= 0 }, "invalid saved attempts.")
            try require(session.drafts.keys.allSatisfy(questions.contains) && session.hints.keys.allSatisfy(questions.contains) && session.revealedIDs.allSatisfy(questions.contains), "saved assistance or drafts reference missing questions.")
            if session.stage == .recap || session.stage == .complete {
                try require(Set(session.attempts.map(\.questionID)) == questions, "a completed session has unanswered questions.")
            }
            try require((session.stage == .complete) == (session.completedAt != nil), "inconsistent session completion state.")
        }
        for note in data.notes {
            try require(note.courseID.map { courses[$0] != nil } ?? true, "a note references a missing course.")
            try require(note.sessionID.map(sessions.contains) ?? true, "a note references a missing session.")
        }
        let cards = (data.flashcards ?? []) + (data.flashcardDrafts ?? [])
        try require(unique(cards.map(\.id)), "duplicate flashcard identifiers.")
        for card in cards {
            try require(data.notes.contains { $0.id == card.noteID }, "a flashcard references a missing note.")
            try FlashcardEngine.validate(front: card.front, back: card.back)
            try require(unique(card.reviews.map(\.id)), "duplicate flashcard reviews.")
        }
        for review in data.reviews {
            try require(courses[review.courseID]?.lessons.contains { $0.id == review.lessonID } == true, "a review references a missing topic.")
        }
    }

    public static func removingRepeatedCode(from prompt: String, code: String) -> String {
        guard !code.isEmpty, let regex = try? NSRegularExpression(pattern: "(?s)```[^\\n]*\\n(.*?)\\n```") else { return prompt }
        let source = prompt as NSString
        var result = prompt
        for match in regex.matches(in: prompt, range: NSRange(location: 0, length: source.length)).reversed() {
            guard source.substring(with: match.range(at: 1)).trimmingCharacters(in: .whitespacesAndNewlines) == code.trimmingCharacters(in: .whitespacesAndNewlines), let range = Range(match.range, in: result) else { continue }
            result.removeSubrange(range)
        }
        let cleaned = result.trimmingCharacters(in: .whitespacesAndNewlines)
        return cleaned.isEmpty ? prompt : cleaned
    }
    public static func normalize(_ answer: String) -> String {
        answer.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
    }
    public static func grade(_ answer: String, for question: Question) -> Grade? {
        guard !question.kind.needsModelGrading else { return nil }
        // Choice and ordering controls submit the exact stored option text.
        // Preserve case and punctuation that can distinguish code identifiers.
        return Grade(correct: answer == question.answer, feedback: question.explanation)
    }
    public static func validate(_ outline: CourseOutline) throws {
        let lessons = outline.modules.flatMap(\.lessons)
        guard !outline.title.isEmpty, !lessons.isEmpty, lessons.count <= 80,
              Set(lessons.map(\.id)).count == lessons.count,
              Set(outline.modules.map(\.id)).count == outline.modules.count else {
            throw PalmError.message("The course plan was incomplete. Please generate it again.")
        }
        let ids = Set(lessons.map(\.id))
        for lesson in lessons {
            guard !lesson.title.isEmpty, !lesson.id.isEmpty, lesson.prerequisites.allSatisfy({ ids.contains($0) && $0 != lesson.id }) else {
                throw PalmError.message("The generated prerequisites were invalid. Please try again.")
            }
        }
        var visited = Set<String>(); var visiting = Set<String>()
        func visit(_ id: String) throws {
            guard !visiting.contains(id) else { throw PalmError.message("The curriculum contains a prerequisite cycle. Please try again.") }
            guard !visited.contains(id), let lesson = lessons.first(where: { $0.id == id }) else { return }
            visiting.insert(id)
            for prerequisite in lesson.prerequisites { try visit(prerequisite) }
            visiting.remove(id); visited.insert(id)
        }
        for lesson in lessons { try visit(lesson.id) }
    }
    public static func validateQuestionMix(_ lesson: LessonContent) throws {
        guard lesson.questions.count >= 4 else { return }
        let choices = lesson.questions.filter { $0.kind.usesOptions }.count
        let written = lesson.questions.filter { $0.kind.needsModelGrading }.count
        guard choices >= 1, written >= 1 else {
            throw PalmError.message("Include a choice question and an independent written explanation or application; choose the remaining formats to suit the objective.")
        }
    }

    public static func validate(_ lesson: LessonContent) throws {
        guard !lesson.material.isEmpty, !lesson.questions.isEmpty, lesson.questions.count <= 25,
              Set(lesson.questions.map(\.id)).count == lesson.questions.count else {
            throw PalmError.message("The lesson did not contain a complete, unique question set. Please retry.")
        }
        try lesson.prediction?.validate()
        let sources = Set(lesson.sources.map(\.id))
        guard sources.count == lesson.sources.count else { throw PalmError.message("Source IDs must be unique.") }
        for q in lesson.questions {
            guard !q.prompt.isEmpty, !q.answer.isEmpty, !q.explanation.isEmpty,
                  q.sourceIDs.allSatisfy(sources.contains) else { throw PalmError.message("A generated question has missing answers or sources. Please retry.") }
            guard ["recall", "trace", "explain", "diagnose", "transfer"].contains(q.skill) else { throw PalmError.message("Question \(q.id) has an invalid skill. Use recall, trace, explain, diagnose, or transfer.") }
            if q.kind == .cloze {
                let pattern = try NSRegularExpression(pattern: "_{3,}|\\[blank\\]")
                let blanks = pattern.numberOfMatches(in: q.prompt, range: NSRange(q.prompt.startIndex..., in: q.prompt))
                guard blanks == 1 else { throw PalmError.message("Question \(q.id) must contain exactly one blank for one answer.") }
            }
            if q.kind == .order {
                let ordered = q.answer.components(separatedBy: " → ")
                guard q.options.count >= 2, Set(q.options).count == q.options.count, Set(ordered) == Set(q.options), ordered.count == q.options.count else { throw PalmError.message("Question \(q.id) must order every option exactly once.") }
            }
            if q.code.contains("\\n    ") && !q.code.contains("\n") { throw PalmError.message("Question \(q.id) contains double-escaped code lines. Use real newlines in the decoded code string.") }
            if q.kind == .trace, q.answer.count > 120 && q.acceptedAnswers.isEmpty { throw PalmError.message("Question \(q.id) needs a concise literal output answer, with reasoning in explanation.") }
            if q.kind == .diagramChoice {
                let diagrams = q.diagrams ?? []
                guard (2...4).contains(diagrams.count), Set(diagrams.map(\.id)) == Set(q.options), diagrams.allSatisfy({ !$0.mermaid.isEmpty && !$0.description.isEmpty }) else { throw PalmError.message("A flow question needs two to four uniquely labeled diagrams and matching option IDs.") }
            }
            if q.kind.usesOptions {
                guard q.options.count >= 2, Set(q.options).count == q.options.count, q.options.contains(q.answer) else {
                    throw PalmError.message("Question \(q.id) has an inconsistent answer key \(q.answer). Its answer must exactly match one of: \(q.options.joined(separator: " | ")).")
                }
            }
        }
    }
    public static func recap(_ session: StudySession) -> String {
        var text = "# \(session.content.title)\n\n## Key ideas\n\n" + session.content.takeaways.map { "- \($0)" }.joined(separator: "\n")
        if !session.content.workedExample.isEmpty { text += "\n\n## Worked example\n\n" + session.content.workedExample }
        if !session.recall.isEmpty { text += "\n\n## My understanding\n\n\(session.recall)" }
        let mistakes = session.attempts.filter { !$0.grade.correct && !$0.disputed && !$0.grade.uncertain }
        if !mistakes.isEmpty { text += "\n\n## Things to revisit\n\n" + mistakes.map { attempt in
            let question = session.content.questions.first { $0.id == attempt.questionID }
            return "### " + (question?.prompt ?? "Practice question") + "\n\n**Your answer:** " + attempt.answer + "\n\n" + attempt.grade.feedback
        }.joined(separator: "\n\n") }
        let replies = session.messages.filter { $0.role == "assistant" }
        if !replies.isEmpty { text += "\n\n## From our conversation\n\n" + replies.map(\.content).joined(separator: "\n\n---\n\n") }
        if !session.content.sources.isEmpty { text += "\n\n## Sources\n\n" + session.content.sources.map { "- \($0.title): \($0.location)" }.joined(separator: "\n") }
        return text
    }
}

public enum NoteFormatting {
    public static func readingBody(_ note: StudyNote) -> String {
        let trimmed = note.body.trimmingCharacters(in: .whitespacesAndNewlines)
        let lines = trimmed.components(separatedBy: "\n")
        if let first = lines.first, first.hasPrefix("# "), (LearningEngine.normalize(String(first.dropFirst(2))) == LearningEngine.normalize(note.title) || LearningEngine.normalize(String(first.dropFirst(2))).hasPrefix(LearningEngine.normalize(note.title) + ":")) {
            return lines.dropFirst().joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return note.body
    }
    public static func preview(_ note: StudyNote) -> String {
        readingBody(note).replacingOccurrences(of: "(?s)```.*?```", with: " ", options: .regularExpression)
            .replacingOccurrences(of: "==", with: "")
            .replacingOccurrences(of: "[#`*]", with: "", options: .regularExpression)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
    }
    public static func readingMinutes(_ note: StudyNote) -> Int { max(1, Int(ceil(Double(note.body.split(whereSeparator: { $0.isWhitespace }).count) / 200))) }
}
