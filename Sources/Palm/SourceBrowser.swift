import SwiftUI
import PalmCore

extension EnvironmentValues {
    @Entry var sourceSnapshot: String? = nil
}

struct SourceBrowser: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    var root: String
    var initial: SourceReference? = nil
    @State private var files: [String] = []
    @State private var search = ""
    @State private var selected: String?
    @State private var code = ""
    @State private var failure: String?
    var body: some View {
        VStack(spacing: 16) {
            HStack { Label("Saved source", systemImage: "chevron.left.forwardslash.chevron.right").font(.headline); Spacer(); Text("Read-only snapshot").font(.caption).foregroundStyle(.secondary); Button("Done") { dismiss() }.buttonStyle(QuietButton()).keyboardShortcut(.cancelAction) }
            HSplitView {
                VStack(alignment: .leading, spacing: 10) {
                    TextField("Find a file…", text: $search).fieldStyle().accessibilityLabel("Find source file")
                    List(selection: $selected) {
                        ForEach(files.filter { search.isEmpty || $0.localizedCaseInsensitiveContains(search) }, id: \.self) { path in
                            Text(path).font(.system(size: 11, design: .monospaced)).lineLimit(2).help(path).tag(path)
                        }
                    }.listStyle(.sidebar).scrollContentBackground(.hidden)
                }.frame(minWidth: 210, idealWidth: 260, maxWidth: 300)
                VStack(alignment: .leading, spacing: 12) {
                    Text(selected ?? "Choose a file").font(.system(size: 12, design: .monospaced)).textSelection(.enabled)
                    if let failure { ContentUnavailableView("Source unavailable", systemImage: "doc.questionmark", description: Text(failure)) }
                    else if selected != nil {
                        CodeReadingView(code: code, language: SnapshotSource.language(selected ?? ""), onAsk: { store.askAboutCode((selected ?? "") + "\n" + $0); dismiss() }, showsLineNumbers: true, focusLine: selected == initial?.path ? initial?.line : nil) { _ in }.id((selected ?? "") + String(code.hashValue))
                    } else { ContentUnavailableView("Explore the repository", systemImage: "doc.text.magnifyingglass", description: Text("Choose a file. Click any code element to ask your tutor about it.")) }
                }.padding(.leading, 16).frame(minWidth: 450, maxWidth: .infinity, maxHeight: .infinity)
            }
        }.padding(22).frame(minWidth: 940, idealWidth: 1080, minHeight: 630, idealHeight: 740)
            .task {
                do {
                    files = try await Task.detached { try SnapshotSource.files(root: URL(fileURLWithPath: root)) }.value
                    if let initial, !files.contains(initial.path) {
                        let prefix = initial.path.trimmingCharacters(in: CharacterSet(charactersIn: "/")) + "/"
                        if let child = files.first(where: { $0.hasPrefix(prefix) }) { search = prefix; selected = child }
                        else { selected = initial.path }
                    } else { selected = initial?.path ?? files.first }
                }
                catch { failure = error.localizedDescription }
            }
            .task(id: selected) {
                guard let selected else { return }; code = ""; failure = nil
                do {
                    let text = try await Task.detached { try SnapshotSource.read(root: URL(fileURLWithPath: root), reference: SourceReference(selected)) }.value
                    try Task.checkCancellation(); code = text
                } catch { if !Task.isCancelled { failure = error.localizedDescription } }
            }
    }
}

struct BrowseSourceButton: View {
    var root: String
    @State private var showing = false
    var body: some View {
        Button { showing = true } label: { Label("Browse code", systemImage: "doc.text.magnifyingglass") }.buttonStyle(QuietButton())
            .sheet(isPresented: $showing) { SourceBrowser(root: root) }
    }
}

extension AppStore {
    func snapshotPath(for session: StudySession) -> String? {
        if let path = session.snapshotPath { return path }
        guard let course = data.courses.first(where: { $0.id == session.courseID }), let repo = data.repositories.first(where: { $0.id == course.repositoryID }), repo.snapshotID == session.snapshotID else { return nil }
        return repo.snapshotPath
    }
}
