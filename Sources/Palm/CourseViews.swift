import SwiftUI
import PalmCore

struct CourseCard: View {
    @Environment(AppStore.self) private var store
    var course: Course
    var body: some View {
        Button { store.openCourse(course.id) } label: {
            HStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(course.outline.title).font(.system(size: 15, weight: .medium)).fixedSize(horizontal: false, vertical: true)
                    Text(course.lessons.first(where: { !course.completedLessonIDs.contains($0.id) })?.title ?? "Completed · ready to revisit").font(.system(size: 12)).foregroundStyle(.secondary).lineLimit(2)
                }
                Spacer(minLength: 16)
                Text("\(course.completedLessonIDs.count) / \(course.lessons.count)").font(.system(size: 12)).monospacedDigit().foregroundStyle(.secondary)
                Image(systemName: "chevron.right").font(.system(size: 11)).foregroundStyle(.tertiary)
            }.padding(16).frame(maxWidth: .infinity, minHeight: 76, alignment: .leading).contentShape(.rect(cornerRadius: 8))
        }.buttonStyle(OptionButtonStyle()).accessibilityElement(children: .ignore).accessibilityLabel(course.outline.title).accessibilityValue("\(course.completedLessonIDs.count) of \(course.lessons.count) topics completed").accessibilityAddTraits(.isButton)
    }
}

struct CoursesView: View {
    @Environment(AppStore.self) private var store
    @FocusState private var searchFocused: Bool
    var filtered: [Course] { store.data.courses.filter { $0.archived == store.showingArchivedCourses && (store.courseSearch.isEmpty || $0.outline.title.localizedCaseInsensitiveContains(store.courseSearch)) } }
    var body: some View {
        @Bindable var store = store
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                HStack { PageHeading(eyebrow: "", title: "Courses", subtitle: ""); Button { store.showingNewCourse = true } label: { Label("New course", systemImage: "plus") }.buttonStyle(PrimaryButton()) }
                HStack {
                    TextField("Search courses", text: $store.courseSearch).fieldStyle().focused($searchFocused).frame(maxWidth: 350)
                    Spacer()
                    WorkspaceSelect(title: "Course filter", selection: $store.showingArchivedCourses, options: [.init(false, "Active"), .init(true, "Archived")])
                }
                if filtered.isEmpty { EmptyState(icon: "square.stack", title: store.courseSearch.isEmpty ? "No courses here yet" : "No matching courses", subtitle: "Choose a topic to start learning, or change the filter.") }
                else { KeyboardRows(items: filtered) { CourseCard(course: $0) } }
            }.frame(maxWidth: 980, alignment: .leading).padding(32).frame(maxWidth: .infinity, alignment: .top)
        }.background { Button("Find courses") { searchFocused = true }.keyboardShortcut("f").hidden() }
    }
}

struct CourseDetailView: View {
    @Environment(AppStore.self) private var store
    @State private var showOutcomes = false
    @State private var deleteConfirmation = false
    var courseID: UUID
    var body: some View {
        if let course = store.data.courses.first(where: { $0.id == courseID }) {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    HStack {
                        Button { store.navigate(.courses) } label: { Label("Courses", systemImage: "arrow.left") }.buttonStyle(TextActionStyle()).foregroundStyle(.secondary)
                        Spacer()
                        ActionPopover(title: "Course actions", actions: [
                            WorkspaceAction(title: course.archived ? "Unarchive course" : "Archive course", icon: "archivebox") { if let i = store.data.courses.firstIndex(where: { $0.id == courseID }) { store.data.courses[i].archived.toggle(); store.save() } },
                            WorkspaceAction(title: "Create a related course", icon: "plus") { store.newCourseTopic = course.outline.title; store.showingNewCourse = true },
                            WorkspaceAction(title: "Delete course…", icon: "trash") { deleteConfirmation = true }
                        ])
                    }
                    PageHeading(eyebrow: "", title: course.outline.title, subtitle: course.outline.summary)
                    HStack {
                        Text("\(course.completedLessonIDs.count) of \(course.lessons.count) topics completed").font(.system(size: 13)).foregroundStyle(.secondary)
                        Spacer()
                        if course.isComplete { Button("Review course") { store.navigate(.review) }.buttonStyle(QuietButton()) }
                        else if let next = course.lessons.first(where: { !course.completedLessonIDs.contains($0.id) }) { Button("Continue learning") { store.startLesson(course: course, lesson: next) }.buttonStyle(PrimaryButton()).disabled(store.busy != nil) }
                    }
                    DisclosureGroup("Learning outcomes", isExpanded: $showOutcomes) {
                        VStack(alignment: .leading, spacing: 10) { ForEach(course.outline.outcomes, id: \.self) { Text($0).font(.system(size: 14)) } }.padding(.vertical, 12)
                    }.font(.system(size: 13)).foregroundStyle(.secondary)
                    Divider()
                    ForEach(course.outline.modules) { module in
                        VStack(alignment: .leading, spacing: 12) {
                            Text(module.title).font(.system(size: 16, weight: .semibold))
                            KeyboardRows(items: module.lessons) { LessonRow(course: course, lesson: $0) }
                        }
                    }
                }.frame(maxWidth: 980, alignment: .leading).padding(32).frame(maxWidth: .infinity, alignment: .top)
            }
            .alert("Delete “\(course.outline.title)”?", isPresented: $deleteConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Delete course", role: .destructive) { store.deleteCourse(courseID) }
            } message: { Text("This removes its lessons, attempts, topic reviews, and course memories. Your notes and flashcards are kept. This cannot be undone.") }
        }
    }
}

private struct LessonRow: View {
    @Environment(AppStore.self) private var store
    var course: Course
    var lesson: LessonOutline
    var complete: Bool { course.completedLessonIDs.contains(lesson.id) }
    var ready: Bool { lesson.prerequisites.allSatisfy(course.completedLessonIDs.contains) }
    var body: some View {
        Button { store.startLesson(course: course, lesson: lesson) } label: {
            HStack(spacing: 14) {
                Image(systemName: complete ? "checkmark.circle" : "circle").foregroundStyle(complete ? Palette.accent : .secondary).frame(width: 20)
                VStack(alignment: .leading, spacing: 6) {
                    Text(lesson.title).font(.system(size: 14, weight: .medium))
                    Text(lesson.objective).font(.system(size: 12)).foregroundStyle(.secondary).lineLimit(2)
                    if !ready && !complete { Text("Suggested first: " + lesson.prerequisites.compactMap { id in course.lessons.first { $0.id == id }?.title }.joined(separator: ", ")).font(.system(size: 12)).foregroundStyle(.secondary) }
                }
                Spacer()
                Text("\(lesson.minutes) min").font(.system(size: 12)).foregroundStyle(.secondary)
                Text(complete ? "Revisit" : (ready ? "Start" : "Explore")).font(.system(size: 13, weight: .medium))
            }.padding(16).frame(maxWidth: .infinity, minHeight: 72, alignment: .leading).contentShape(.rect(cornerRadius: 8))
        }.buttonStyle(OptionButtonStyle()).disabled(store.busy != nil)
    }
}

struct NewCourseView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var topic = ""
    @State private var level = "Some familiarity"
    @State private var repositoryID: UUID?
    @State private var diagnostic = ""
    @State private var diagnosticQuestions: [DiagnosticQuestion] = []
    @State private var diagnosticIndex = 0
    @State private var diagnosticTask: Task<Void, Never>?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var diagnosticAnswers: [String: String] = [:]
    @State private var diagnosing = false
    private var takingDiagnostic: Bool { !diagnosticQuestions.isEmpty && diagnosticIndex < diagnosticQuestions.count }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                HStack { Eyebrow(title: takingDiagnostic ? "Starting check" : "New course"); Spacer(); Button { dismiss() } label: { Image(systemName: "xmark") }.buttonStyle(TextActionStyle()).help(store.busy == nil ? "Close" : "Keep working in the background") }
                if takingDiagnostic {
                    Text(topic).font(.system(size: 15, weight: .medium)).foregroundStyle(.secondary).lineLimit(2).help(topic)
                } else {
                PageHeading(eyebrow: "", title: "What do you want to understand?", subtitle: "Choose a concept, question, or part of a repository.")
                TextField("e.g. How async code works, from promises to race conditions", text: $topic, axis: .vertical).lineLimit(2...4).fieldStyle().accessibilityIdentifier("course-topic")
                HStack(alignment: .top, spacing: 18) {
                    VStack(alignment: .leading, spacing: 9) { Text("Starting point").font(.system(size: 12, weight: .medium)); WorkspaceSelect(title: "Starting point", selection: $level, options: ["New to this", "Some familiarity", "Experienced"].map { .init($0, $0) }) }
                    VStack(alignment: .leading, spacing: 9) { Text("Repository context").font(.system(size: 12, weight: .medium)); WorkspaceSelect(title: "Repository", selection: $repositoryID, options: [.init(nil, "Just the topic")] + store.data.repositories.map { .init(Optional($0.id), $0.name) }, searchable: true) }
                }
                VStack(alignment: .leading, spacing: 9) { Text("What do you already know? (optional)").font(.system(size: 12, weight: .medium)); TextField("Tell us what clicks, what doesn't, and what you want to be able to do.", text: $diagnostic, axis: .vertical).lineLimit(2...4).fieldStyle() }
                }
                if diagnosticQuestions.isEmpty {
                    Button(action: startDiagnostic) {
                        HStack(spacing: 10) {
                            if diagnosing { ProgressView().controlSize(.small) }
                            Label(diagnosing ? "Preparing your starting check…" : "Try a quick starting check", systemImage: "sparkle.magnifyingglass")
                        }
                    }.buttonStyle(QuietButton()).disabled(topic.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !store.hasModelAccess(for: "planning") || diagnosing)
                    Text("Three quick questions with choices. Skip anything you're unsure about.").font(.system(size: 12)).foregroundStyle(.secondary)
                } else {
                    diagnosticCard
                }
                if takingDiagnostic {
                    Button("Skip the remaining questions") { advanceDiagnostic(diagnosticQuestions.count - diagnosticIndex) }.buttonStyle(TextActionStyle()).font(.system(size: 12)).foregroundStyle(.secondary)
                } else {
                Divider()
                if !store.hasModelAccess(for: "planning") { Label("Connect a model in Settings before creating a course.", systemImage: "key").font(.system(size: 12)).foregroundStyle(.secondary); SettingsLink { Text("Open Settings") } }
                HStack { Text("You can adjust the course as you learn.").font(.system(size: 11)).foregroundStyle(.secondary); Spacer(); Button { store.createCourse(topic: topic, level: level, repositoryID: repositoryID, diagnostic: diagnostic + "\n" + diagnosticQuestions.map { "Q: \($0.prompt) A: \(diagnosticAnswers[$0.id, default: "Not answered"])" }.joined(separator: "\n")) } label: { Label("Create course", systemImage: "arrow.right") }.buttonStyle(PrimaryButton()).disabled(topic.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !store.hasModelAccess(for: "planning") || store.busy != nil || diagnosing).accessibilityIdentifier("build-course")
                }
                }
                if let error = store.error { Text(error).font(.system(size: 12)).foregroundStyle(.red).textSelection(.enabled).padding(12).frame(maxWidth: .infinity, alignment: .leading).background(Color.red.opacity(0.07), in: .rect(cornerRadius: 10)) }
                if store.busy != nil { WorkStatusView() }
            }.padding(32)
        }.frame(width: 700, height: 620)
        .onAppear { repositoryID = store.newCourseRepositoryID; store.newCourseRepositoryID = nil; topic = store.newCourseTopic; store.newCourseTopic = "" }
        .onChange(of: topic) { resetDiagnostic() }
        .onChange(of: level) { resetDiagnostic() }
        .onDisappear { diagnosticTask?.cancel() }
    }
    private var diagnosticCard: some View {
        Panel {
            VStack(alignment: .leading, spacing: 18) {
                if diagnosticIndex < diagnosticQuestions.count {
                    let question = diagnosticQuestions[diagnosticIndex]
                    HStack {
                        Eyebrow(title: "Your starting point")
                        Spacer()
                        Text("\(diagnosticIndex + 1) of \(diagnosticQuestions.count)").font(.system(size: 12)).monospacedDigit().foregroundStyle(.secondary)
                    }
                    ProgressView(value: Double(diagnosticIndex), total: Double(diagnosticQuestions.count)).tint(Palette.accent)
                    VStack(alignment: .leading, spacing: 12) {
                        MarkdownReading(text: question.prompt, fontSize: 17)
                        ForEach(question.options + ["Not sure yet"], id: \.self) { option in
                            ChoiceOption(title: option, selected: diagnosticAnswers[question.id] == option) { diagnosticAnswers[question.id] = option }
                        }
                    }.id(question.id).transition(.opacity)
                    HStack {
                        if diagnosticIndex > 0 { Button("Back") { advanceDiagnostic(-1) }.buttonStyle(QuietButton()) }
                        Spacer()
                        Button(diagnosticIndex + 1 == diagnosticQuestions.count ? "Finish starting check" : "Next question") { advanceDiagnostic(1) }.buttonStyle(PrimaryButton()).disabled(diagnosticAnswers[question.id] == nil)
                    }
                } else {
                    Label("Your starting point is ready", systemImage: "checkmark.circle.fill").font(.system(size: 16, weight: .semibold)).foregroundStyle(Palette.accent)
                    Text("Your choices will shape the course. Uncertain answers simply tell us where to begin.").font(.system(size: 13)).foregroundStyle(.secondary)
                    Button("Review my choices") { withAnimation(reduceMotion ? nil : .easeOut(duration: 0.18)) { diagnosticIndex = 0 } }.buttonStyle(QuietButton())
                }
            }
        }
    }
    private func advanceDiagnostic(_ delta: Int) {
        withAnimation(reduceMotion ? nil : .easeOut(duration: 0.18)) { diagnosticIndex += delta }
    }
    private func resetDiagnostic() {
        diagnosticTask?.cancel(); diagnosticQuestions = []; diagnosticAnswers = [:]; diagnosticIndex = 0; diagnosing = false
    }
    private func startDiagnostic() {
        diagnosing = true; store.error = nil
        diagnosticTask = Task {
            defer { if !Task.isCancelled { diagnosing = false } }
            do {
                try await store.ensureLearningAgent()
                let check = try await store.ai.diagnostic(topic: topic, level: level, config: store.modelConfiguration(for: "planning"))
                try Task.checkCancellation()
                withAnimation(reduceMotion ? nil : .easeOut(duration: 0.18)) { diagnosticQuestions = check.questions; diagnosticIndex = 0 }
            } catch { if !Task.isCancelled { store.error = error.localizedDescription } }
        }
    }
}
