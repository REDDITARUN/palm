import SwiftUI
import PalmCore
import AppKit

enum Destination: String, CaseIterable, Identifiable {
    case today = "Today", courses = "Courses", repositories = "Repositories", notebook = "Notebook", review = "Review", progress = "Progress"
    var id: String { rawValue }
    var icon: String { switch self { case .today: "sun.max"; case .courses: "square.stack"; case .repositories: "chevron.left.forwardslash.chevron.right"; case .notebook: "book.closed"; case .review: "arrow.trianglehead.clockwise"; case .progress: "chart.xyaxis.line" } }
}

@MainActor @Observable final class AppStore {
    var data: AppData
    var clock = Date()
    var showingGallery = false
    var showingCommands = false
    var showingShortcuts = false
    var sidebarVisible = true
    var courseSearch = ""
    var notebookSearch = ""
    var showingArchivedCourses = false
    var navigationHistory: [WorkspaceLocation] = []
    var navigationIndex = -1
    var destination: Destination = .today
    var selectedCourseID: UUID?
    var activeSessionID: UUID?
    var selectedNoteID: UUID?
    var showingNewCourse = false
    var newCourseRepositoryID: UUID?
    var newCourseTopic = ""
    var error: String?
    var notice: String?
    var busy: String?
    var task: Task<Void, Never>?
    var tutorBusy = false
    var tutorScope: String?
    var tutorStatus = ""
    var tutorStreamingText = ""
    var tutorMessageID: UUID?
    var tutorCheckpoint = Date.distantPast
    var tutorFailure: String?
    var tutorTask: Task<Void, Never>?
    var toolsReady = false
    var modelIDs: [String] = []
    var selectedExcerpt = ""
    var lessonTutorRequest = UUID()
    func askAboutCode(_ text: String) { selectedExcerpt = text; lessonTutorRequest = UUID() }
    let database: LocalDatabase
    let ai: AIService
    let repos: RepositoryService
    let runtime: RuntimeService
    var apiKey = ""
    var isUITesting: Bool
    var isLiveTesting: Bool
    private var lastRevision: [UUID: Date] = [:]

    init() {
        let testing = Bundle.main.bundleIdentifier == "app.plam.learning.test" || ProcessInfo.processInfo.arguments.contains("--ui-testing")
        isUITesting = testing
        isLiveTesting = ProcessInfo.processInfo.arguments.contains("--live-provider")
        let testDir = ProcessInfo.processInfo.environment["PALM_TEST_DATA"].map { URL(fileURLWithPath: $0) } ?? FileManager.default.temporaryDirectory.appendingPathComponent("Palm-UITests")
        do {
            database = try LocalDatabase(directory: testing ? testDir : nil)
            data = try database.load()
        } catch {
            let alert = NSAlert(); alert.messageText = "Palm couldn't open your library"
            alert.informativeText = "Your saved files have not been replaced. " + error.localizedDescription
            alert.addButton(withTitle: "Quit"); alert.addButton(withTitle: "Show library folder")
            if alert.runModal() == .alertSecondButtonReturn {
                let folder = testing ? testDir : LocalDatabase.defaultDirectory()
                NSWorkspace.shared.open(folder)
            }
            exit(1)
        }
        repos = RepositoryService(directory: database.directory)
        runtime = RuntimeService(directory: database.directory)
        ai = AIService(runtime: runtime)
        apiKey = testing && !isLiveTesting ? "ui-test-key" : Keychain.read(ModelConfiguration(key: "", endpoint: data.preferences.endpoint, model: data.preferences.model).credentialAccount) ?? ""
        if isUITesting && !isLiveTesting { data.preferences.endpoint = ProcessInfo.processInfo.environment["PALM_TEST_ENDPOINT"] ?? "http://127.0.0.1:49160/v1"; data.preferences.model = "test-model" }
        for index in data.jobs.indices where data.jobs[index].status == "running" { data.jobs[index].status = "interrupted"; data.jobs[index].error = "The app closed. Retry the activity to resume." }
        try? database.save(data)
        Task { toolsReady = await runtime.isReady() }
    }
    var enabledSkillInstructions: String { (data.agentSkills ?? []).filter(\.enabled).map(\.instructions).joined(separator: "\n") }
    var configuration: ModelConfiguration { .init(key: apiKey, endpoint: data.preferences.endpoint, model: data.preferences.model) }
    var activeSession: StudySession? { data.sessions.first { $0.id == activeSessionID } }
    var selectedCourse: Course? { data.courses.first { $0.id == selectedCourseID } }
    var dueReviews: [ReviewItem] { data.reviews.filter { !$0.paused && $0.due <= clock }.sorted { $0.due < $1.due } }
    var activeCourses: [Course] { data.courses.filter { !$0.archived } }
    var todayMinutes: Int {
        let day = Self.dayKey(Date())
        return data.sessions.reduce(0) { $0 + ($1.activityByDay?[day] ?? (Calendar.current.isDateInToday($1.createdAt) ? $1.activeSeconds : 0)) } / 60
    }
    static func dayKey(_ date: Date) -> String { let c = Calendar.current.dateComponents([.year, .month, .day], from: date); return "\(c.year!)-\(c.month!)-\(c.day!)" }
    func logActivity(_ id: UUID, seconds: Int) { updateSession(id) { session in
        if session.activityByDay == nil { session.activityByDay = [Self.dayKey(session.createdAt): session.activeSeconds] }
        session.activeSeconds += seconds; session.activityByDay?[Self.dayKey(Date()), default: 0] += seconds
    } }
    var isEvaluating: Bool { busy != nil && data.jobs.last(where: { $0.status == "running" })?.kind == "evaluation" }
    var totalAttempts: [Attempt] { data.sessions.flatMap(\.attempts) }
    func save(revision: NoteRevision? = nil) {
        do { try database.save(data, revision: revision) } catch { self.error = "Could not save your changes: \(error.localizedDescription)" }
    }
    func updatePreferences(_ change: (inout Preferences) -> Void) { change(&data.preferences); save() }
    func openCourse(_ id: UUID) { selectedCourseID = id; activeSessionID = nil; destination = .courses }
    func navigate(_ route: Destination) { destination = route; activeSessionID = nil; selectedCourseID = nil }
    func updateSession(_ id: UUID, _ change: (inout StudySession) -> Void) {
        guard let i = data.sessions.firstIndex(where: { $0.id == id }) else { return }; change(&data.sessions[i]); save()
    }
    func updateNote(_ id: UUID, forceRevision: Bool = false, _ change: (inout StudyNote) -> Void) {
        guard let i = data.notes.firstIndex(where: { $0.id == id }) else { return }
        let revision = forceRevision || Date().timeIntervalSince(lastRevision[id] ?? .distantPast) > 30 ? NoteRevision(note: data.notes[i]) : nil
        if revision != nil { lastRevision[id] = Date() }
        let old = data.notes[i]
        change(&data.notes[i])
        if old.body != data.notes[i].body && old.blocksJSON == data.notes[i].blocksJSON { data.notes[i].blocksJSON = nil; data.notes[i].documentRevision = UUID() }
        data.notes[i].updatedAt = Date()
        do { try database.saveNote(data.notes[i], revision: revision) } catch { self.error = "Could not save this note: " + error.localizedDescription }
    }
    func newNote() { let note = StudyNote(); data.notes.insert(note, at: 0); selectedNoteID = note.id; destination = .notebook; save() }
    func run(_ title: String, kind: String, action: @escaping () async throws -> Void) {
        guard task == nil else { return }
        busy = title; error = nil
        let job = GenerationJob(kind: kind, title: title); data.jobs.append(job); save()
        task = Task {
            do {
                try await action(); try Task.checkCancellation()
                if let i = data.jobs.firstIndex(where: { $0.id == job.id }) { data.jobs[i].status = "complete"; data.jobs[i].completedAt = Date() }
            } catch {
                let cancelled = Task.isCancelled || error is CancellationError || (error as? URLError)?.code == .cancelled
                if let i = data.jobs.firstIndex(where: { $0.id == job.id }) { data.jobs[i].status = cancelled ? "cancelled" : "failed"; data.jobs[i].error = cancelled ? nil : error.localizedDescription }
                if !cancelled { self.error = error.localizedDescription }
            }
            save(); busy = nil; task = nil
        }
    }
    func cancelWork() { task?.cancel(); Task { await runtime.stop() } }
    var providerName: String { configuration.isOpenRouter ? "OpenRouter" : (data.preferences.endpoint == "https://api.openai.com/v1" ? "OpenAI" : "Custom") }
    func selectProvider(_ name: String) {
        if name == "OpenRouter" { data.preferences.endpoint = "https://openrouter.ai/api/v1"; data.preferences.model = "thinkingmachines/inkling:free" }
        else if name == "OpenAI" { data.preferences.endpoint = "https://api.openai.com/v1"; data.preferences.model = "gpt-4.1" }
        else { data.preferences.endpoint = "http://localhost:1234/v1"; data.preferences.model = "" }
        apiKey = Keychain.read(configuration.credentialAccount) ?? ""; modelIDs = []; save()
    }
    func setEndpoint(_ endpoint: String) { data.preferences.endpoint = endpoint; apiKey = Keychain.read(configuration.credentialAccount) ?? ""; modelIDs = []; save() }
    func validateKey(_ key: String) async throws {
        var config = configuration; config.key = key
        let models = try await ai.validateKey(config)
        if !isUITesting || isLiveTesting { try Keychain.save(key, account: config.credentialAccount) }
        apiKey = key; modelIDs = models
    }
    func createCourse(topic: String, level: String, repositoryID: UUID?, diagnostic: String) {
        run("Building your learning path…", kind: "course") { [self] in
            try await ensureLearningAgent()
            var context = ""
            if let repo = data.repositories.first(where: { $0.id == repositoryID }) {
                context = try await repositoryContext(repo, topic: topic)
            } else {
                busy = "Finding reliable learning sources…"
                context = try await ai.documentation(topic: topic, config: configuration)
            }
            busy = "Organizing fundamentals and checkpoints…"
            let outline = try await ai.outline(topic: topic, level: level, diagnostic: diagnostic, context: context + "\nTeaching preferences:\n" + TeachingPrompts.resolved(.curriculum, preferences: data.preferences) + "\n" + enabledSkillInstructions, config: modelConfiguration(for: "planning"))
            try Task.checkCancellation()
            let course = Course(topic: topic, level: level, repositoryID: repositoryID, outline: outline, diagnostic: diagnostic)
            data.courses.insert(course, at: 0); showingNewCourse = false; openCourse(course.id)
        }
    }
    func startLesson(course: Course, lesson: LessonOutline, review: ReviewItem? = nil) {
        if review == nil, let session = data.sessions.last(where: { $0.courseID == course.id && $0.lessonID == lesson.id && !$0.isReview && $0.stage != .complete }) {
            activeSessionID = session.id; return
        }
        run(review == nil ? "Preparing your lesson…" : "Preparing a fresh review…", kind: "lesson") { [self] in
            try await ensureLearningAgent()
            let repo = data.repositories.first { $0.id == course.repositoryID }
            var context: String
            if let repo {
                context = try await repositoryContext(repo, topic: lesson.title + " " + lesson.objective)
            } else { context = try await ai.documentation(topic: course.topic + ": " + lesson.objective, config: configuration) }
            busy = "Writing examples and checking questions…"
            let memories = await relevantMemories(query: lesson.objective, courseID: course.id) + "\n" + learningEvidence(course.id)
            let content = try await ai.lesson(course: course, lesson: lesson, context: context, memory: memories, review: review != nil, config: modelConfiguration(for: "lessons"), teachingPrompt: TeachingPrompts.resolved(.beforeLesson, preferences: data.preferences) + "\nQuestion design:\n" + TeachingPrompts.resolved(.questionDesign, preferences: data.preferences) + "\n" + enabledSkillInstructions)
            try Task.checkCancellation()
            var session = StudySession(courseID: course.id, lessonID: lesson.id, content: content, snapshotID: repo?.snapshotID)
            session.snapshotPath = repo?.snapshotPath
            session.isCheckpoint = lesson.isCheckpoint ?? lesson.title.lowercased().contains("checkpoint")
            if session.isCheckpoint == true { session.stage = .practice }
            if let review { session.isReview = true; session.reviewItemID = review.id; session.stage = .practice }
            data.sessions.append(session); selectedCourseID = course.id; destination = .courses; activeSessionID = session.id
        }
    }
    func reviewSaved(_ item: ReviewItem) {
        if let unfinished = data.sessions.last(where: { $0.reviewItemID == item.id && $0.completedAt == nil }) { activeSessionID = unfinished.id; return }
        guard let previous = data.sessions.last(where: { $0.courseID == item.courseID && $0.lessonID == item.lessonID && $0.completedAt != nil }) else { error = "Open this topic once to save its questions for offline practice."; return }
        var session = StudySession(courseID: item.courseID, lessonID: item.lessonID, content: previous.content, snapshotID: previous.snapshotID)
        session.snapshotPath = previous.snapshotPath; session.isReview = true; session.reviewItemID = item.id; session.stage = .practice
        data.sessions.append(session); activeSessionID = session.id; save()
        notice = "Practicing saved questions. Written answers are checked by your model; choosing options works offline."
    }
    func submit(_ snapshot: StudySession) {
        guard busy == nil, let session = data.sessions.first(where: { $0.id == snapshot.id }),
              session.currentQuestion?.id == snapshot.currentQuestion?.id else { return }
        guard let q = session.currentQuestion, !session.attempts.contains(where: { $0.questionID == q.id }) else { return }
        let draft = session.drafts[q.id, default: ""]
        guard !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        let answer = q.kind.needsModelGrading ? draft.trimmingCharacters(in: .whitespacesAndNewlines) : draft
        if let grade = LearningEngine.grade(answer, for: q) { record(grade, answer: answer, question: q, sessionID: session.id) }
        else {
            run("Checking your reasoning…", kind: "evaluation") { [self] in
                let grade = try await ai.evaluate(answer: answer, question: q, config: modelConfiguration(for: "grading"), feedbackPrompt: TeachingPrompts.resolved(.answerFeedback, preferences: data.preferences))
                try Task.checkCancellation(); record(grade, answer: answer, question: q, sessionID: session.id)
            }
        }
    }
    func record(_ grade: Grade, answer: String, question: Question, sessionID: UUID) {
        updateSession(sessionID) { session in
            guard !session.attempts.contains(where: { $0.questionID == question.id }) else { return }
            session.attempts.append(Attempt(questionID: question.id, answer: answer, grade: grade, hintsUsed: session.hints[question.id, default: 0], revealed: session.revealedIDs.contains(question.id)))
        }
    }
    func previousQuestion(_ id: UUID) { updateSession(id) { $0.questionIndex = max(0, $0.questionIndex - 1) } }
    func nextQuestion(_ id: UUID) {
        updateSession(id) { session in
            guard let q = session.currentQuestion, session.attempts.contains(where: { $0.questionID == q.id }) else { return }
            if session.questionIndex + 1 < session.content.questions.count { session.questionIndex += 1 } else { session.stage = .recap }
        }
    }
    func complete(_ id: UUID) {
        guard data.sessions.first(where: { $0.id == id })?.completedAt == nil else { return }
        do {
            let next = try LearningEngine.completing(data, sessionID: id)
            try database.save(next); data = next
            Task { await indexMemories() }
            if let note = data.notes.first(where: { $0.sessionID == id }) { writeRecap(note) }
        } catch { self.error = "Could not complete the topic: \(error.localizedDescription)" }
    }
    func writeRecap(_ note: StudyNote) {
        guard let session = data.sessions.first(where: { $0.id == note.sessionID }) else { return }
        let preferences = data.preferences
        run("Writing your example-led recap…", kind: "notes") { [self] in
            try await ensureLearningAgent()
            let body = try await ai.recap(session: session, preferences: preferences, config: modelConfiguration(for: "notes"))
            try Task.checkCancellation()
            guard let current = data.notes.first(where: { $0.id == note.id }), current.body == note.body else {
                notice = "Your note changed while the recap was being written. Your edits were kept; you can request a new recap from the note menu."
                return
            }
            guard let index = data.notes.firstIndex(where: { $0.id == note.id }) else { return }
            var next = data
            next.notes[index].body = body; next.notes[index].blocksJSON = nil; next.notes[index].documentRevision = UUID(); next.notes[index].updatedAt = Date()
            try database.save(next, revision: NoteRevision(note: current)); data = next
            notice = "Your recap is ready in Notebook."
        }
    }
    func dispute(sessionID: UUID, questionID: String) {
        updateSession(sessionID) { session in if let i = session.attempts.firstIndex(where: { $0.questionID == questionID }) { session.attempts[i].disputed.toggle() } }
    }
    func ask(_ text: String, sessionID: UUID, selection: String, questionHelp: Bool = true) {
        sendTutor(text, scope: "session:" + sessionID.uuidString, selection: selection, questionHelp: questionHelp)
    }

    func learningEvidence(_ courseID: UUID) -> String {
        data.sessions.filter { $0.courseID == courseID }.suffix(5).flatMap { session in
            session.attempts.filter { !$0.disputed && !$0.grade.uncertain }.suffix(6).compactMap { attempt -> String? in
                guard let question = session.content.questions.first(where: { $0.id == attempt.questionID }) else { return nil }
                return "Skill: \(question.skill). Question: \(question.prompt). Correct: \(attempt.grade.correct). Independent: \(attempt.independent). Feedback: \(attempt.grade.feedback)"
            }
        }.joined(separator: "\n")
    }
    func repositoryContext(_ repo: Repository, topic: String) async throws -> String {
        var context = try await repos.context(for: repo, topic: topic)
        if let cached = data.repositoryInsights?.last(where: { $0.repositoryID == repo.id && $0.snapshotID == repo.snapshotID && $0.topic == topic }) { return context + "\n" + cached.summary }
        if toolsReady, modelConfiguration(for: "research").agentProvider != nil {
            busy = "Following symbols, references, and tests…"
            let summary = try await runtime.explore(repository: repo, topic: topic, configuration: modelConfiguration(for: "research"))
            try Task.checkCancellation()
            if data.repositoryInsights == nil { data.repositoryInsights = [] }
            data.repositoryInsights?.append(RepositoryInsight(repositoryID: repo.id, snapshotID: repo.snapshotID, topic: topic, summary: summary)); save()
            context += "\n" + summary
        }
        return context
    }
    func importRepository(_ url: URL) {
        run("Reading your repository…", kind: "repository") { [self] in
            let repo = try await repos.importFolder(url); try Task.checkCancellation(); data.repositories.append(repo); destination = .repositories
        }
    }
    func importRemote(_ url: String) {
        run("Downloading the repository…", kind: "repository") { [self] in
            let local = try await repos.clone(url: url, token: Keychain.read("github")); let repo = try await repos.importFolder(local)
            try Task.checkCancellation(); data.repositories.append(repo); destination = .repositories
        }
    }
    func refresh(_ repo: Repository) {
        run("Refreshing the source snapshot…", kind: "repository") { [self] in
            var updated = try await repos.importFolder(URL(fileURLWithPath: repo.originalPath)); updated.id = repo.id
            if let i = data.repositories.firstIndex(where: { $0.id == repo.id }) { data.repositories[i] = updated }
        }
    }
    func checkRepositories() async {
        for repo in data.repositories {
            if let fingerprint = try? await repos.fingerprint(URL(fileURLWithPath: repo.originalPath)), let i = data.repositories.firstIndex(where: { $0.id == repo.id }) {
                data.repositories[i].stale = fingerprint != repo.fingerprint; data.repositories[i].checkedAt = Date()
            }
        }
        save()
    }
    func ensureLearningAgent() async throws {
        try await runtime.configure(servers: data.mcpServers ?? [], skills: data.agentSkills ?? [])
        if (configuration.requiresHarness || (data.modelProfiles ?? []).contains(where: { ModelConfiguration(key: "", endpoint: $0.endpoint, model: $0.model).requiresHarness })) && !toolsReady { if task != nil { busy = "Preparing your local learning agent for the first time…" }; try await runtime.prepare(); toolsReady = await runtime.isReady() }
    }
    func prepareTools() {
        run("Preparing Serena and memory tools. This can take several minutes…", kind: "tools") { [self] in try await runtime.prepare(); toolsReady = await runtime.isReady(); notice = "Local exploration and memory tools are ready." }
    }
    func relevantMemories(query: String, courseID: UUID) async -> String {
        let eligible = data.memories.filter { !$0.forgotten && ($0.courseID == nil || $0.courseID == courseID) }
        guard !eligible.isEmpty else { return "" }
        var matched = [UUID]()
        if toolsReady,
           let result = try? await runtime.memory(operation: "search", text: query, key: apiKey),
           let hits = result["results"] as? [[String: Any]] {
            matched = hits.compactMap { hit in
                guard let meta = hit["metadata"] as? [String: Any], let id = meta["canonical_id"] as? String else { return nil }
                return UUID(uuidString: id)
            }
        }
        let terms = Set(query.lowercased().split(whereSeparator: { !$0.isLetter }).map(String.init))
        let ranked = eligible.sorted { a, b in
            let sa = (matched.contains(a.id) ? 100 : 0) + terms.filter { a.text.lowercased().contains($0) }.count
            let sb = (matched.contains(b.id) ? 100 : 0) + terms.filter { b.text.lowercased().contains($0) }.count
            return sa == sb ? a.createdAt > b.createdAt : sa > sb
        }
        // Always use current canonical text; vectors may be stale or have been forgotten during the search.
        return ranked.prefix(8).compactMap { candidate in data.memories.first { $0.id == candidate.id && !$0.forgotten }?.text }.joined(separator: "\n")
    }
    func editMemory(_ id: UUID, text: String) {
        guard let i = data.memories.firstIndex(where: { $0.id == id }) else { return }
        let vectorID = data.memories[i].vectorID
        data.memories[i].text = text; data.memories[i].userEdited = true; data.memories[i].vectorID = nil; save()
        if let vectorID { Task { _ = try? await runtime.memory(operation: "delete", id: vectorID, key: apiKey) } }
    }
    private var indexingMemories = false
    func indexMemories() async {
        guard !indexingMemories else { return }
        indexingMemories = true; defer { indexingMemories = false }
        guard toolsReady else { return }
        for memory in data.memories where !memory.forgotten && memory.vectorID == nil {
            if let result = try? await runtime.memory(operation: "add", text: memory.text, id: memory.id.uuidString, key: apiKey),
               let results = result["results"] as? [[String: Any]], let vectorID = results.first?["id"] as? String,
               let i = data.memories.firstIndex(where: { $0.id == memory.id && !$0.forgotten && $0.text == memory.text }) { data.memories[i].vectorID = vectorID; save() }
        }
    }
    func forget(_ memory: LearnerMemory) {
        guard let i = data.memories.firstIndex(where: { $0.id == memory.id }) else { return }
        data.memories[i].forgotten = true; save()
        if let id = memory.vectorID { Task { _ = try? await runtime.memory(operation: "delete", id: id, key: apiKey) } }
    }
    func exportLibrary() {
        let panel = NSSavePanel(); panel.nameFieldStringValue = "Palm-library.json"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do { try database.export(data, to: url); notice = "Library exported. Repository snapshots remain in Application Support." } catch { self.error = error.localizedDescription }
    }
    func backupLibrary() {
        let panel = NSSavePanel(); panel.nameFieldStringValue = "Palm-" + Self.dayKey(Date()) + ".palmbackup"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do { try database.exportBackup(data, to: url); notice = "Backup saved with code snapshots and note history." }
        catch { self.error = error.localizedDescription }
    }
    func restoreLibrary() {
        guard busy == nil, !tutorBusy, !indexingMemories else { error = "Let the current activity finish before restoring a library."; return }
        let panel = NSOpenPanel(); panel.canChooseDirectories = true; panel.canChooseFiles = true
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let isFolder = (try url.resourceValues(forKeys: [.isDirectoryKey])).isDirectory == true
            data = try isFolder ? database.restoreBackup(from: url) : database.restoreJSON(from: url)
            activeSessionID = nil; selectedCourseID = nil; selectedNoteID = nil; selectedExcerpt = ""; destination = .today
            apiKey = isUITesting && !isLiveTesting ? "ui-test-key" : Keychain.read(configuration.credentialAccount) ?? ""
            modelIDs = []; lastRevision = [:]
            notice = "Library restored. A backup of the previous library was saved."
            Task { await indexMemories() }
        } catch { self.error = error.localizedDescription }
    }
}
