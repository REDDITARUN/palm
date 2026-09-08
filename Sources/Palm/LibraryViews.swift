import SwiftUI
import PalmCore
import MarkdownEngine
import AppKit

struct NotebookView: View {
    @Environment(AppStore.self) private var store
    @State private var showingMap = false
    @AppStorage("notebookCourseFilter") private var courseFilter = "all"
    @AppStorage("notebookTagFilter") private var tagFilter = ""
    @AppStorage("notebookPinnedOnly") private var pinnedOnly = false
    @AppStorage("notebookSort") private var sortOrder = "Recent"
    private var filtered: Bool { courseFilter != "all" || !tagFilter.isEmpty || pinnedOnly || !search.isEmpty }
    private func clearFilters() { courseFilter = "all"; tagFilter = ""; pinnedOnly = false; store.notebookSearch = "" }
    private var courseOptions: [SelectOption<String>] { [.init("all", "All courses"), .init("personal", "Personal notes")] + store.data.courses.map { .init($0.id.uuidString, $0.outline.title) } }

    @AppStorage("noteTutorVisible") private var noteTutorVisible = false
    @FocusState private var searchFocused: Bool
    private var search: String { store.notebookSearch }
    var notes: [StudyNote] { NotebookFilter.notes(store.data.notes, query: search, course: courseFilter, tag: tagFilter, pinned: pinnedOnly, sort: sortOrder) }
    var body: some View {
        GeometryReader { geometry in
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 16) {
                HStack { Text("Notebook").font(.system(size: 18, weight: .semibold)); Spacer(); Button { clearFilters(); store.newNote() } label: { Image(systemName: "square.and.pencil") }.buttonStyle(IconButton()).accessibilityLabel("New note").help("New note") }
                TextField("Search notes", text: Binding(get: { store.notebookSearch }, set: { store.notebookSearch = $0 })).focused($searchFocused).fieldStyle().font(.system(size: 12)).accessibilityLabel("Search notes")
                WorkspaceSelect(title: "Filter notes by course", selection: $courseFilter, options: courseOptions, searchable: true)
                HStack(spacing: 4) {
                    WorkspaceSelect(title: "Filter notes by tag", selection: $tagFilter, options: [.init("", "All tags")] + Set(store.data.notes.flatMap(\.tags)).sorted().map { .init($0, $0) })
                    Button { pinnedOnly.toggle() } label: { Image(systemName: pinnedOnly ? "pin.fill" : "pin") }.buttonStyle(IconButton()).background(pinnedOnly ? Palette.soft : .clear, in: .rect(cornerRadius: 8)).accessibilityLabel("Pinned notes only").accessibilityValue(pinnedOnly ? "On" : "Off")
                }
                HStack { Text("\(notes.count) notes").font(.system(size: 11)).foregroundStyle(.secondary); Spacer(); if filtered { Button("Clear") { clearFilters() }.buttonStyle(TextActionStyle()).font(.system(size: 11)) }; ActionPopover(title: "Sort notes", actions: [WorkspaceAction(title: "Recently edited", icon: "clock") { sortOrder = "Recent" }, WorkspaceAction(title: "Title", icon: "textformat.abc") { sortOrder = "Title" }]); Button { showingMap = true } label: { Image(systemName: "point.3.connected.trianglepath.dotted") }.buttonStyle(IconButton()).accessibilityLabel("Open knowledge map").help("Knowledge map") }
                ScrollView {
                    LazyVStack(spacing: 8) {
                        if notes.isEmpty && filtered { VStack(spacing: 12) { Text("No matching notes").font(.system(size: 13, weight: .medium)); Button("Clear filters") { clearFilters() }.buttonStyle(QuietButton()) }.padding(.vertical, 24) }
                        ForEach(notes) { note in
                            Button { store.selectedNoteID = note.id } label: {
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack(alignment: .top) { if note.pinned { Image(systemName: "pin.fill").font(.system(size: 11)).foregroundStyle(Palette.accent) }; Text(note.title).font(.system(size: 13, weight: .medium)).lineLimit(3).help(note.title); Spacer(minLength: 0) }
                                    NoteCourseLabel(course: store.data.courses.first { $0.id == note.courseID })
                                    Text(NoteFormatting.preview(note)).font(.system(size: 12)).foregroundStyle(.secondary).lineLimit(2)
                                    HStack { Text(note.sessionID == nil ? "Personal note" : "Lesson recap"); Spacer(); Text(note.updatedAt.formatted(.dateTime.month(.abbreviated).day())) }.font(.system(size: 10)).foregroundStyle(.secondary)
                                }.padding(14).frame(maxWidth: .infinity, alignment: .leading)
                                    .background(store.selectedNoteID == note.id ? Palette.selection : .clear, in: .rect(cornerRadius: 12))
                                    .contentShape(.rect(cornerRadius: 8))
                            }.buttonStyle(OptionButtonStyle()).accessibilityAddTraits(store.selectedNoteID == note.id ? .isSelected : [])
                        }
                    }
                }
            }.padding(20).frame(width: 245)
            if let id = store.selectedNoteID, let note = store.data.notes.first(where: { $0.id == id }) { NoteEditorView(noteID: note.id) }
            else { EmptyState(icon: "book.closed", title: "Your understanding, in words.", subtitle: "Lesson recaps and your own ideas live here. Open a note or start a fresh page.", actionTitle: "New note", action: { store.newNote() }) }
        }
        }.sheet(isPresented: $showingMap) { KnowledgeMapView() }
        .background { Button("Find notes") { noteTutorVisible = false; searchFocused = true }.keyboardShortcut("f").hidden() }.onAppear { if courseFilter != "all" && courseFilter != "personal" && !store.data.courses.contains(where: { $0.id.uuidString == courseFilter }) { courseFilter = "all" }; if !notes.contains(where: { $0.id == store.selectedNoteID }) { store.selectedNoteID = notes.first?.id } }
        .onChange(of: store.selectedNoteID) { if let id = store.selectedNoteID, store.data.notes.contains(where: { $0.id == id }), !notes.contains(where: { $0.id == id }) { clearFilters() } }
        .onChange(of: notes.map(\.id)) { if !notes.contains(where: { $0.id == store.selectedNoteID }) { store.selectedNoteID = notes.first?.id } }
    }
}

struct NoteEditorView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.openURL) private var openURL
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var noteID: UUID
    @AppStorage("noteInspectorWidth") private var inspectorWidth = 360.0
    @State private var showingCards = false
    @State private var showHistory = false
    @State private var revisions: [NoteRevision] = []
    @State private var selection = ""
    @State private var showDelete = false
    @AppStorage("noteTutorVisible") private var showTutor = false
    @State private var tagsDraft = ""
    @State private var showFormatting = false
    @State private var rewriteConfirmation = false
    @State private var selectedCard: Flashcard?
    var note: StudyNote? { store.data.notes.first { $0.id == noteID } }
    var body: some View {
        if let note {
            GeometryReader { geometry in
            HStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 0) {
                    HStack(spacing: 12) {
                        WorkspaceTabs(title: "Notebook section", selection: $showingCards, options: [.init(false, "Note"), .init(true, "Flashcards")])
                        Spacer()
                        Button { store.updateNote(noteID) { $0.pinned.toggle() } } label: { Image(systemName: note.pinned ? "pin.fill" : "pin") }.buttonStyle(IconButton()).accessibilityLabel(note.pinned ? "Unpin note" : "Pin note")
                        ActionPopover(title: "Note actions", actions: noteActions(note))
                        Button { showTutor.toggle() } label: { Image(systemName: "sidebar.right") }.buttonStyle(IconButton()).help("Show note tutor").accessibilityLabel("Toggle note tutor")
                    }.padding(.horizontal, 22).padding(.vertical, 12)
                    if showingCards { NoteFlashcardsView(noteID: noteID) }
                    else {
                        VStack(alignment: .leading, spacing: 8) {
                            NoteCourseLabel(course: store.data.courses.first { $0.id == note.courseID })
                            TextField("Note title", text: Binding(get: { self.note?.title ?? "" }, set: { value in store.updateNote(noteID) { $0.title = value } }), axis: .vertical).lineLimit(1...4).textFieldStyle(.plain).font(.system(size: 25, weight: .semibold)).accessibilityLabel("Note title")
                            TextField("Add tags, separated by commas", text: $tagsDraft).textFieldStyle(.plain).font(.system(size: 11)).foregroundStyle(.secondary).accessibilityLabel("Note tags").onChange(of: tagsDraft) { let tags = tagsDraft.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }; if tags != self.note?.tags { store.updateNote(noteID) { $0.tags = tags } } }
                        }.padding(.horizontal, 50).padding(.top, 26).padding(.bottom, 12)
                        BlockNoteEditor(note: note, links: Dictionary(store.data.notes.map { ($0.title, $0.id.uuidString) }, uniquingKeysWith: { first, _ in first }), openNote: { target in if let linked = store.data.notes.first(where: { $0.id.uuidString == target || $0.title == target }) { store.selectedNoteID = linked.id } }, changed: { id, revision, markdown, blocks in guard let current = store.data.notes.first(where: { $0.id == id }), (current.documentRevision?.uuidString ?? current.id.uuidString) == revision, current.body != markdown || current.blocksJSON != blocks else { return }; store.updateNote(id) { $0.body = markdown; $0.blocksJSON = blocks } }, selected: { selection = $0 }, askSelection: { selection = $0; showTutor = true }, failed: { store.error = $0 })
                    }
                    if !backlinks(note).isEmpty { ScrollView(.horizontal) { HStack { Text("Linked from").font(.system(size: 11)).foregroundStyle(.secondary); ForEach(backlinks(note)) { linked in Button(linked.title) { store.selectedNoteID = linked.id }.buttonStyle(TextActionStyle()).font(.system(size: 12)) } }.padding(12) } }
                }.frame(minWidth: 320)
                if showTutor && geometry.size.width >= 660 {
                    InspectorDivider(width: $inspectorWidth)
                    tutorPanel.frame(width: min(inspectorWidth, max(300, geometry.size.width - 328))).background(Palette.background)
                }
            }
            .overlay(alignment: .trailing) {
                if showTutor && geometry.size.width < 660 { tutorPanel.frame(width: min(inspectorWidth, geometry.size.width - 24)).background(Palette.background).shadow(color: .black.opacity(0.06), radius: 18, x: -6).padding(.leading, 24) }
            }
            }.background(Palette.canvas).onChange(of: noteID, initial: true) { tagsDraft = note.tags.joined(separator: ", "); selection = ""; showingCards = false }
            .sheet(isPresented: $showFormatting) { MarkdownGuide() }
            .sheet(item: $selectedCard) { card in FlashcardEditor(card: card) }
            .confirmationDialog("Rewrite this recap? The current note will be saved in revision history.", isPresented: $rewriteConfirmation) { Button("Rewrite recap") { store.writeRecap(note) } }
            .sheet(isPresented: $showHistory) { VStack(alignment: .leading, spacing: 18) { HStack { Text("Revision history").font(.title2); Spacer(); Button("Done") { showHistory = false } }; if revisions.isEmpty { Text("Revisions appear as you edit this note.").foregroundStyle(.secondary) }; List(revisions) { revision in HStack { VStack(alignment: .leading) { Text(revision.createdAt.formatted()); Text(revision.body.prefix(100)).font(.caption).foregroundStyle(.secondary) }; Spacer(); Button("Restore revision") { store.updateNote(noteID, forceRevision: true) { $0.body = revision.body; $0.title = revision.title; $0.blocksJSON = revision.blocksJSON; $0.documentRevision = UUID() }; showHistory = false } } } }.padding(24).frame(width: 650, height: 440).task(id: noteID) { do { revisions = try store.database.revisions(for: noteID) } catch { store.error = "Could not load note history: " + error.localizedDescription } } }

            .confirmationDialog("Delete this note?", isPresented: $showDelete) { Button("Delete note", role: .destructive) { store.deleteNote(noteID) } }
        }
    }
    private var tutorPanel: some View {
        VStack(spacing: 0) {
            HStack { Text("Note tutor").font(.system(size: 12, weight: .medium)); Spacer(); Button { showTutor = false } label: { Image(systemName: "xmark") }.buttonStyle(IconButton()).accessibilityLabel("Close note tutor") }.padding(14)
            WorkspaceTutor(scope: "note:" + noteID.uuidString, selection: $selection)
        }
    }
    private func noteActions(_ note: StudyNote) -> [WorkspaceAction] {
        var actions = [WorkspaceAction(title: "Revision history", icon: "clock.arrow.circlepath") { showHistory = true }]
        if let courseID = note.courseID { actions.append(WorkspaceAction(title: "Open course", icon: "square.stack") { store.openCourse(courseID) }) }
        if note.sessionID != nil { actions.append(WorkspaceAction(title: "Rewrite recap…", icon: "arrow.clockwise", disabled: store.busy != nil) { rewriteConfirmation = true }) }
        actions += [
            WorkspaceAction(title: "Create a flashcard", icon: "rectangle.on.rectangle") { selectedCard = Flashcard(noteID: noteID, front: "", back: selection) },
            WorkspaceAction(title: "Markdown guide", icon: "textformat") { showFormatting = true },
            WorkspaceAction(title: "Export Markdown…", icon: "square.and.arrow.up") { export(note) },
            WorkspaceAction(title: "Create a course", icon: "plus") { store.newCourseTopic = note.title; store.showingNewCourse = true },
            WorkspaceAction(title: "Delete note", icon: "trash", destructive: true) { showDelete = true }
        ]
        return actions
    }
    private func backlinks(_ note: StudyNote) -> [StudyNote] { store.data.notes.filter { $0.id != note.id && $0.body.contains("[[\(note.title)]]") } }
    private func export(_ note: StudyNote) { let panel = NSSavePanel(); panel.nameFieldStringValue = note.title.replacingOccurrences(of: "/", with: "-") + ".md"; if panel.runModal() == .OK, let url = panel.url { do { try note.body.write(to: url, atomically: true, encoding: .utf8) } catch { store.error = error.localizedDescription } } }
}

struct RepositoriesView: View {
    @State private var removing: Repository?
    @State private var removeConfirmation = false
    @Environment(AppStore.self) private var store
    @State private var remote = ""
    var body: some View {
        ScrollView { VStack(alignment: .leading, spacing: 28) {
            HStack { PageHeading(eyebrow: "", title: "Repositories", subtitle: "Code sources for your courses."); Button(action: chooseFolder) { Label("Open folder", systemImage: "folder.badge.plus") }.buttonStyle(PrimaryButton()).disabled(store.busy != nil) }
            Panel { HStack(spacing: 14) { Image(systemName: "link").foregroundStyle(Palette.accent); TextField("https://github.com/owner/repository", text: $remote).textFieldStyle(.plain); Button("Import from GitHub") { store.importRemote(remote) }.buttonStyle(QuietButton()).disabled(remote.isEmpty || store.busy != nil) } }
            DisclosureGroup("How to connect GitHub") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Public repository: paste its HTTPS GitHub URL above and choose Import from GitHub.")
                    Text("Private repository: create a fine-grained token for that repo with Contents: read-only. Save it in Settings → Local tools, then import its URL.")
                    Text("GitHub import needs Apple's command-line tools. You can also download a repository ZIP, extract it, and choose Open folder.")
                    Link("Create a GitHub token ↗", destination: URL(string: "https://github.com/settings/personal-access-tokens/new")!)
                }.font(.system(size: 12)).foregroundStyle(.secondary).padding(.top, 10)
            }.font(.system(size: 12))
            if !store.toolsReady { HStack { Image(systemName: "puzzlepiece.extension").foregroundStyle(Palette.accent); Text("Prepare local tools to add Serena's symbol and reference exploration.").font(.system(size: 12)).foregroundStyle(.secondary); Spacer(); Button("Prepare tools") { store.prepareTools() }.buttonStyle(QuietButton()).disabled(store.busy != nil) } }
            if store.data.repositories.isEmpty { EmptyState(icon: "curlybraces", title: "A codebase can be a classroom.", subtitle: "Open a local project or import from GitHub. Palm saves a source snapshot and builds lessons around your questions.", actionTitle: "Choose a repository", action: chooseFolder) }
            ForEach(store.data.repositories) { repo in Panel {
                VStack(alignment: .leading, spacing: 20) {
                    HStack { Image(systemName: "folder").font(.system(size: 26, weight: .light)).foregroundStyle(Palette.accent); VStack(alignment: .leading, spacing: 5) { Text(repo.name).font(.system(size: 19, weight: .semibold)); Text(repo.originalPath).font(.system(size: 10, design: .monospaced)).foregroundStyle(.secondary).lineLimit(1) }; Spacer(); Chip(title: repo.stale ? "Source changed" : "Snapshot ready", icon: repo.stale ? "arrow.clockwise" : "checkmark") }
                    HStack { Text("\(repo.fileCount) source files").font(.system(size: 12)).foregroundStyle(.secondary); ForEach(repo.languages, id: \.self) { Chip(title: $0) }; Spacer() }
                    if let insights = store.data.repositoryInsights?.filter({ $0.repositoryID == repo.id && $0.snapshotID == repo.snapshotID }), !insights.isEmpty {
                        DisclosureGroup("Saved understanding · \(insights.count) explorations") { VStack(alignment: .leading, spacing: 16) { ForEach(insights) { insight in VStack(alignment: .leading, spacing: 8) { Text(insight.topic).font(.system(size: 13, weight: .semibold)); MarkdownReading(text: insight.summary) } } }.padding(.top, 12) }.font(.system(size: 12))
                    }
                    if repo.stale { Text("The original files have changed. Refresh to use the latest code; past lessons retain their saved evidence.").font(.system(size: 12)).foregroundStyle(.orange) }
                    HStack { Button("Build a course") { store.newCourseRepositoryID = repo.id; store.showingNewCourse = true }.buttonStyle(PrimaryButton()); Button("Refresh snapshot") { store.refresh(repo) }.buttonStyle(QuietButton()); Button("Remove…") { removing = repo; removeConfirmation = true }.buttonStyle(TextActionStyle()); Spacer(); Text("Imported \(repo.importedAt.formatted(.dateTime.month(.abbreviated).day()))").font(.system(size: 10)).foregroundStyle(.tertiary) }.disabled(store.busy != nil)
                }
            } }
        }.padding(34) }
        .alert("Remove “\(removing?.name ?? "repository")” from Palm?", isPresented: $removeConfirmation) {
            Button("Cancel", role: .cancel) { removing = nil }
            Button("Remove repository", role: .destructive) { if let removing { store.removeRepository(removing.id) }; removing = nil }
        } message: { Text("Your original repository folder is untouched. Existing courses, notes, and source snapshots used by saved lessons are kept.") }
    }
    private func chooseFolder() { let panel = NSOpenPanel(); panel.canChooseDirectories = true; panel.canChooseFiles = false; panel.prompt = "Open repository"; if panel.runModal() == .OK, let url = panel.url { store.importRepository(url) } }
}

struct ReviewView: View {
    @Environment(AppStore.self) private var store
    @State private var cardReview: CardReviewRequest?
    var body: some View {
        ScrollView { VStack(alignment: .leading, spacing: 28) {
            PageHeading(eyebrow: "", title: "Review", subtitle: "Revisit topics and practice your flashcards.")
            if !store.flashcards.isEmpty {
                Panel { HStack {
                    VStack(alignment: .leading, spacing: 6) { Text("Flashcards").font(.system(size: 16, weight: .semibold)); Text("\(store.dueFlashcards.count) ready across your notes").font(.system(size: 12)).foregroundStyle(.secondary) }
                    Spacer(); Button("Review cards") { cardReview = CardReviewRequest(ids: store.dueFlashcards.map(\.id)) }.buttonStyle(PrimaryButton()).disabled(store.dueFlashcards.isEmpty)
                } }
            }
            if store.dueReviews.isEmpty { Panel { EmptyState(icon: "checkmark.circle", title: "No topic reviews due", subtitle: store.data.reviews.isEmpty ? "Finish a topic to begin your review schedule." : "Your next review will appear here when it's due. You can also revisit a topic anytime.", actionTitle: "Explore my courses", action: { store.navigate(.courses) }) } }
            else {
                HStack { Text("Ready today").font(.system(size: 18, weight: .semibold)); Spacer(); Chip(title: "\(store.dueReviews.count) topics") }
                ForEach(store.dueReviews) { item in reviewRow(item) }
            }
            let upcoming = store.data.reviews.filter { !$0.paused && $0.due > Date() }.sorted { $0.due < $1.due }
            if !upcoming.isEmpty { Text("Coming up").font(.system(size: 18, weight: .semibold)); ForEach(upcoming) { item in reviewRow(item) } }
            if !store.data.reviews.filter(\.paused).isEmpty { Text("Paused").font(.system(size: 18, weight: .semibold)); ForEach(store.data.reviews.filter(\.paused)) { item in reviewRow(item) } }
        }.padding(34) }.sheet(item: $cardReview) { request in FlashcardReviewView(ids: request.ids) }
    }
    private func reviewRow(_ item: ReviewItem) -> some View {
        Panel { HStack(spacing: 18) { Image(systemName: "arrow.trianglehead.clockwise").font(.system(size: 22)).foregroundStyle(Palette.accent); VStack(alignment: .leading, spacing: 6) { Text(item.title).font(.system(size: 15, weight: .medium)); Text(item.paused ? "Paused" : "Due \(item.due.formatted(.relative(presentation: .named))) · \(item.repetitions) learning encounters").font(.system(size: 11)).foregroundStyle(.secondary) }; Spacer(); Button(item.paused ? "Resume" : "Pause") { if let i = store.data.reviews.firstIndex(where: { $0.id == item.id }) { store.data.reviews[i].paused.toggle(); store.save() } }.buttonStyle(TextActionStyle()).font(.system(size: 11)).foregroundStyle(.secondary); Button("Saved practice") { store.reviewSaved(item) }.buttonStyle(QuietButton()).disabled(store.busy != nil); Button("Fresh review") { if let course = store.data.courses.first(where: { $0.id == item.courseID }), let lesson = course.lessons.first(where: { $0.id == item.lessonID }) { store.startLesson(course: course, lesson: lesson, review: item) } }.buttonStyle(QuietButton()).disabled(store.busy != nil) } }
    }
}
