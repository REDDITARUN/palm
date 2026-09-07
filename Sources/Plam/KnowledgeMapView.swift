import SwiftUI
import PlamCore

struct KnowledgeMapView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var searchQuery = ""
    @State private var selected: String?
    @State private var focusID: String?
    @State private var depth = 1
    @State private var kind = "All"
    @State private var course = "all"
    @State private var positions: [String: CGPoint] = [:]
    @State private var command = "fit"
    @State private var commandID = UUID()
    @State private var layingOut = false
    @State private var index = KnowledgeIndex(AppData())
    private var candidates: [KnowledgeNode] {
        let neighborhood = focusID.map { KnowledgeLayout.neighborhood($0, depth: depth, links: index.links) }
        return index.nodes.filter { node in (kind == "All" || node.kind == kind) && (course == "all" || courseID(node)?.uuidString == course) && (neighborhood == nil || neighborhood!.contains(node.id)) }
    }
    private var visible: [KnowledgeNode] {
        let matches = searchQuery.isEmpty ? candidates : candidates.filter { $0.title.localizedCaseInsensitiveContains(searchQuery) }
        // Matching nodes retain immediate context, so searching doesn't strand a note.
        let ids = Set(matches.flatMap { KnowledgeLayout.neighborhood($0.id, depth: searchQuery.isEmpty ? 0 : 1, links: index.links) })
        return Array(candidates.filter { ids.contains($0.id) }.prefix(300))
    }
    private func courseID(_ node: KnowledgeNode) -> UUID? {
        if node.kind == "Course" { return node.recordID }
        if node.kind == "Note" { return store.data.notes.first { $0.id == node.recordID }?.courseID }
        return store.data.memories.first { $0.id == node.recordID }?.courseID
    }
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 4) { Text("Knowledge map").font(.system(size: 22, weight: .semibold)); Text("Revisit a note, follow its links, and find related ideas.").font(.system(size: 12)).foregroundStyle(.secondary) }
                Spacer(); Button("Done") { dismiss() }.buttonStyle(QuietButton()).keyboardShortcut(.cancelAction)
            }.padding(24)
            HStack(spacing: 12) {
                WorkspaceSelect(title: "Map course", selection: $course, options: [.init("all", "All courses")] + store.data.courses.map { .init($0.id.uuidString, $0.outline.title) }, searchable: true).frame(maxWidth: 230)
                WorkspaceTabs(title: "Map kinds", selection: $kind, options: [.init("All", "All"), .init("Note", "Notes"), .init("Course", "Courses"), .init("Memory", "Memories")])
                Spacer()
                if focusID != nil { WorkspaceSelect(title: "Connection depth", selection: $depth, options: [.init(1, "1 step"), .init(2, "2 steps")]); Button("Whole map") { selected = nil; focusID = nil; kind = "All"; course = "all" }.buttonStyle(QuietButton()) }
            }.padding(.horizontal, 24).padding(.bottom, 16)
            HStack(spacing: 0) {
                ZStack {
                    GraphNavigationSurface(nodes: visible.compactMap { node -> GraphCanvasNode? in guard let point = positions[node.id] else { return nil }; return .init(node: node, point: point, color: node.kind == "Memory" ? .systemOrange : NSColor(CourseIdentity.color(courseID(node)))) }, links: index.links, selected: selected, command: command, commandID: commandID, select: { selected = $0 }, open: open)
                        .background(Palette.canvas)
                    if visible.isEmpty { VStack(spacing: 10) { Image(systemName: "point.3.connected.trianglepath.dotted").font(.system(size: 28)).foregroundStyle(.tertiary); Text("No matching connections").font(.system(size: 16, weight: .medium)); Button("Reset filters") { query = ""; course = "all"; kind = "All"; focusID = nil }.buttonStyle(QuietButton()) } }
                    if layingOut { ProgressView().controlSize(.small).allowsHitTesting(false) }
                }.clipped()
                    .overlay(alignment: .topLeading) {
                        if let focus = index.nodes.first(where: { $0.id == focusID }) { VStack(alignment: .leading, spacing: 4) { Text("Around this " + focus.kind.lowercased()).font(.system(size: 10)).foregroundStyle(.secondary); Text(focus.title).font(.system(size: 13, weight: .medium)).lineLimit(1) }.padding(16).allowsHitTesting(false) }
                    }
                    .overlay(alignment: .bottomLeading) { Text("Drag to arrange · pinch to zoom · double-click to open").font(.system(size: 10)).foregroundStyle(.secondary).padding(16).allowsHitTesting(false) }
                    .overlay(alignment: .bottomTrailing) { HStack(spacing: 4) { Button { navigate("out") } label: { Image(systemName: "minus") }.buttonStyle(IconButton()).accessibilityLabel("Zoom out"); Button { navigate("in") } label: { Image(systemName: "plus") }.buttonStyle(IconButton()).accessibilityLabel("Zoom in"); Button { navigate("fit") } label: { Image(systemName: "arrow.up.left.and.arrow.down.right") }.buttonStyle(IconButton()).accessibilityLabel("Fit graph") }.padding(6).background(Palette.background, in: .rect(cornerRadius: 10)).padding(14) }
                    .task(id: visible.map(\.id).sorted().joined()) { await layout() }
                inspector.frame(width: 280).background(Palette.background)
            }
        }.frame(width: 1100, height: 710).background(Palette.background)
            .task(id: query) { do { try await Task.sleep(for: .milliseconds(200)); searchQuery = query; if !query.isEmpty { focusID = nil } } catch {} }
            .onChange(of: visible.map(\.id)) { if let selected, !visible.contains(where: { $0.id == selected }) { self.selected = nil } }
            .onChange(of: store.data.notes, initial: true) { index = KnowledgeIndex(store.data) }
            .onAppear { if let id = store.selectedNoteID { selected = "note:" + id.uuidString; focusID = selected } }
            .onChange(of: store.data.courses) { index = KnowledgeIndex(store.data) }
            .onChange(of: store.data.memories) { index = KnowledgeIndex(store.data) }
    }
    private var inspector: some View {
        VStack(alignment: .leading, spacing: 16) {
            TextField("Find a note or idea", text: $query).fieldStyle().accessibilityLabel("Search knowledge map")
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    if !query.isEmpty {
                        Text("Search results").font(.system(size: 11, weight: .medium)).foregroundStyle(.secondary)
                        ForEach(candidates.filter { $0.title.localizedCaseInsensitiveContains(query) }) { node in connectionButton(node) }
                    }
                    if let node = index.nodes.first(where: { $0.id == selected }) {
                        HStack { Circle().fill(CourseIdentity.color(courseID(node))).frame(width: 7, height: 7); Text(node.kind).font(.system(size: 11)).foregroundStyle(.secondary); Spacer() }
                        Text(node.title).font(.system(size: 18, weight: .semibold)).fixedSize(horizontal: false, vertical: true)
                        if node.kind == "Note", let note = store.data.notes.first(where: { $0.id == node.recordID }) { Text(NoteFormatting.preview(note)).font(.system(size: 12)).foregroundStyle(.secondary).lineLimit(5) }
                        if node.kind == "Memory", let memory = store.data.memories.first(where: { $0.id == node.recordID }) { Text(memory.text).font(.system(size: 12)).foregroundStyle(.secondary) }
                        HStack { if node.kind != "Memory" { Button("Open " + node.kind.lowercased()) { open(node) }.buttonStyle(PrimaryButton()) }; Button("Focus here") { focusID = node.id; query = ""; kind = "All"; course = "all" }.buttonStyle(QuietButton()) }
                        Text("Saved connections").font(.system(size: 12, weight: .semibold)).padding(.top, 4)
                        let links = index.links.filter { $0.source == node.id || $0.target == node.id }
                        if links.isEmpty { Text("No links yet. Add [[note links]] in this note to connect ideas.").font(.system(size: 12)).foregroundStyle(.secondary) }
                        ForEach(links) { link in if let other = index.nodes.first(where: { $0.id == (link.source == node.id ? link.target : link.source) }) { connectionButton(other, relation: link.relation == "explains" ? (node.kind == "Course" ? "Note in this course" : "Belongs to this course") : link.relation == "links to" ? (link.source == node.id ? "Linked from this note" : "Links to this note") : link.relation) } }
                        if node.kind == "Note", let note = store.data.notes.first(where: { $0.id == node.recordID }) {
                            let related = store.data.notes.filter { other in other.id != note.id && !Set(other.tags.map { $0.lowercased() }).intersection(note.tags.map { $0.lowercased() }).isEmpty && !links.contains { $0.source == "note:" + other.id.uuidString || $0.target == "note:" + other.id.uuidString } }.sorted { $0.updatedAt > $1.updatedAt }
                            if !related.isEmpty {
                                Text("Related by tag").font(.system(size: 12, weight: .semibold)).padding(.top, 6)
                                Text("Shared topics, not saved links.").font(.system(size: 10)).foregroundStyle(.secondary)
                                ForEach(Array(related.prefix(6))) { other in if let target = index.nodes.first(where: { $0.recordID == other.id && $0.kind == "Note" }) { connectionButton(target, relation: other.tags.filter { tag in note.tags.contains { $0.caseInsensitiveCompare(tag) == .orderedSame } }.joined(separator: " · ")) } }
                            }
                        }
                    } else if query.isEmpty {
                        Text("Explore your learning").font(.system(size: 17, weight: .semibold))
                        Text("Hover to follow connections. Select an idea to inspect it, or double-click to open it.").font(.system(size: 13)).foregroundStyle(.secondary).lineSpacing(4)
                        HStack(spacing: 14) { Label("Note", systemImage: "circle.fill"); Label("Course", systemImage: "largecircle.fill.circle") }.font(.system(size: 10)).foregroundStyle(.secondary)
                        Text("Start with a course").font(.system(size: 12, weight: .medium)).padding(.top, 12)
                        ForEach(visible.filter { $0.kind == "Course" }) { node in connectionButton(node) }
                        Text("Or a recent note").font(.system(size: 12, weight: .medium))
                        ForEach(Array(visible.filter { $0.kind == "Note" }.prefix(6))) { node in connectionButton(node) }
                    }
                }.frame(maxWidth: .infinity, alignment: .leading)
            }
        }.padding(20)
    }
    private func connectionButton(_ node: KnowledgeNode, relation: String? = nil) -> some View {
        Button { selected = node.id; if !visible.contains(where: { $0.id == node.id }) { focusID = node.id; course = "all"; kind = "All"; query = ""; searchQuery = "" } } label: { HStack(alignment: .top, spacing: 8) { Circle().fill(CourseIdentity.color(courseID(node))).frame(width: 6, height: 6).padding(.top, 5); VStack(alignment: .leading, spacing: 4) { Text(node.title).font(.system(size: 12)).lineLimit(2); if let relation { Text(relation).font(.system(size: 10)).foregroundStyle(.secondary) } }; Spacer(minLength: 0) }.padding(8).frame(maxWidth: .infinity, alignment: .leading).contentShape(.rect) }.buttonStyle(OptionButtonStyle())
    }
    private func open(_ node: KnowledgeNode) { if node.kind == "Note" { store.selectedNoteID = node.recordID; dismiss() }; if node.kind == "Course" { store.openCourse(node.recordID); dismiss() } }
    private func navigate(_ action: String) { command = action; commandID = UUID() }
    private func layout() async {
        let nodes = visible, links = index.links
        if nodes.allSatisfy({ positions[$0.id] != nil }) { return }
        layingOut = true
        let result = await Task.detached(priority: .userInitiated) { KnowledgeLayout.positions(nodes: nodes, links: links) }.value
        guard !Task.isCancelled else { return }
        positions.merge(result) { existing, _ in existing }; layingOut = false; navigate("fit")
    }
}
