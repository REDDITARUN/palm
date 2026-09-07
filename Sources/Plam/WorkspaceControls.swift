import SwiftUI
import AppKit
import PlamCore

enum KeyboardContext {
    static var isEditing: Bool { NSApp.keyWindow?.firstResponder is NSTextView || NSApp.keyWindow?.firstResponder is NSTextField }
}

extension View {
    func proseNavigation() -> some View {
        onKeyPress(.tab, phases: .down) { press in
            if press.modifiers.contains(.shift) { NSApp.keyWindow?.selectPreviousKeyView(nil) }
            else { NSApp.keyWindow?.selectNextKeyView(nil) }
            return .handled
        }
    }
}

struct KeyboardRows<Item: Identifiable, Content: View>: View where Item.ID: Hashable {
    var items: [Item]
    @ViewBuilder var content: (Item) -> Content
    @FocusState private var focused: Item.ID?
    var body: some View {
        LazyVStack(spacing: 4) {
            ForEach(items) { item in content(item).focused($focused, equals: item.id).id(item.id) }
        }.onKeyPress(.downArrow) { move(1) }.onKeyPress(.upArrow) { move(-1) }
    }
    private func move(_ delta: Int) -> KeyPress.Result {
        guard let current = items.firstIndex(where: { $0.id == focused }) else { return .ignored }
        focused = items[min(max(current + delta, 0), items.count - 1)].id
        return .handled
    }
}

struct CopyCodeButton: View {
    var copy: () -> Void
    @State private var copied = false
    var body: some View {
        Button { copy(); copied = true } label: { Image(systemName: copied ? "checkmark" : "doc.on.doc") }
            .buttonStyle(IconButton()).help(copied ? "Copied" : "Copy code").accessibilityLabel(copied ? "Code copied" : "Copy code")
            .task(id: copied) { if copied { try? await Task.sleep(for: .seconds(1.5)); if !Task.isCancelled { copied = false } } }
    }
}

struct WorkspaceAction: Identifiable {
    var id: String { identity ?? title }
    var title: String
    var icon: String = ""
    var detail: String = ""
    var shortcut: String = ""
    var selected = false
    var disabled = false
    var destructive = false
    var identity: String? = nil
    var action: () -> Void
}

struct ActionList: View {
    var actions: [WorkspaceAction]
    var searchable = false
    var placeholder = "Search…"
    var choose: (WorkspaceAction) -> Void
    @State private var query = ""
    @State private var highlighted: String?
    @State private var committed = false
    @FocusState private var searchFocused: Bool
    @FocusState private var listFocused: Bool
    private var filtered: [WorkspaceAction] { actions.filter { query.isEmpty || ($0.title + " " + $0.detail).localizedCaseInsensitiveContains(query) } }
    var body: some View {
        VStack(spacing: 4) {
            if searchable {
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                    TextField(placeholder, text: $query).textFieldStyle(.plain).focused($searchFocused)
                        .onSubmit { activate() }.accessibilityLabel(placeholder)
                }.padding(12)
                Divider()
            }
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 2) {
                        ForEach(filtered) { item in
                            if item.destructive { Divider().padding(.vertical, 4) }
                            Button { commit(item) } label: {
                                HStack(spacing: 10) {
                                    if !item.icon.isEmpty { Image(systemName: item.icon).frame(width: 18) }
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(item.title).lineLimit(2).fixedSize(horizontal: false, vertical: true)
                                        if !item.detail.isEmpty { Text(item.detail).font(.system(size: 11)).foregroundStyle(.secondary).lineLimit(1) }
                                    }
                                    Spacer(minLength: 12)
                                    if item.selected { Image(systemName: "checkmark").foregroundStyle(Palette.accent) }
                                    if !item.shortcut.isEmpty { Text(item.shortcut).font(.system(size: 11)).foregroundStyle(.secondary) }
                                }.font(.system(size: 13)).foregroundStyle(item.destructive ? Palette.incorrect : .primary)
                                    .padding(.horizontal, 10).padding(.vertical, 8).frame(maxWidth: .infinity, minHeight: 36, alignment: .leading)
                                    .background(highlighted == item.id ? Palette.selection : .clear, in: .rect(cornerRadius: 8))
                                    .contentShape(.rect(cornerRadius: 8))
                            }.buttonStyle(OptionButtonStyle()).disabled(item.disabled).id(item.id)
                                .accessibilityAddTraits(item.selected ? .isSelected : [])
                        }
                        if filtered.isEmpty { Text("No matching results").font(.system(size: 13)).foregroundStyle(.secondary).padding(20) }
                    }.padding(6)
                }.frame(height: min(CGFloat(max(filtered.count, 1)) * rowHeight, 360))
                    .onChange(of: highlighted) { if let highlighted { proxy.scrollTo(highlighted) } }
            }
        }.background(Palette.surface).focusable(!searchable).focused($listFocused).focusEffectDisabled()
            .task { await Task.yield(); if searchable { searchFocused = true } else { listFocused = true } }
            .onKeyPress(.downArrow) { move(1); return .handled }
            .onKeyPress(.upArrow) { move(-1); return .handled }
            .onKeyPress(.return) { activate(); return .handled }
            .onChange(of: query) { highlighted = filtered.first(where: { !$0.disabled })?.id }
            .onAppear { highlighted = actions.first(where: { $0.selected && !$0.disabled })?.id ?? actions.first(where: { !$0.disabled })?.id }
    }
    private var rowHeight: CGFloat { actions.contains(where: { !$0.detail.isEmpty }) ? 56 : 42 }
    private func move(_ delta: Int) {
        let available = filtered.filter { !$0.disabled }
        guard !available.isEmpty else { return }
        let current = available.firstIndex(where: { $0.id == highlighted }) ?? (delta > 0 ? -1 : 0)
        highlighted = available[(current + delta + available.count) % available.count].id
    }
    private func activate() { if let item = filtered.first(where: { $0.id == highlighted && !$0.disabled }) { commit(item) } }
    private func commit(_ item: WorkspaceAction) { guard !committed, !item.disabled else { return }; committed = true; choose(item) }
}

struct ActionPopover: View {
    var title: String
    var icon = "ellipsis"
    var textLabel = false
    var searchable = false
    var actions: [WorkspaceAction]
    @State private var showing = false
    @FocusState private var triggerFocused: Bool
    var body: some View {
        Button { showing.toggle() } label: {
            HStack(spacing: 6) { if textLabel { Text(title).font(.system(size: 13)).lineLimit(1).truncationMode(.middle) }; Image(systemName: icon) }
                .padding(.horizontal, textLabel ? 10 : 0).frame(minWidth: 36, minHeight: 36).contentShape(.rect(cornerRadius: 8))
        }.buttonStyle(OptionButtonStyle()).focused($triggerFocused).help(title).accessibilityLabel(title)
            .popover(isPresented: $showing, arrowEdge: .bottom) {
                ActionList(actions: actions, searchable: searchable) { item in
                    showing = false
                    DispatchQueue.main.async { item.action() }
                }.frame(width: searchable ? 360 : 280).onExitCommand { showing = false }
            }
            .onChange(of: showing) { if !showing { triggerFocused = true } }
    }
}

struct SelectOption<Value: Hashable>: Identifiable {
    var value: Value
    var title: String
    var id: Value { value }
    init(_ value: Value, _ title: String) { self.value = value; self.title = title }
}

struct WorkspaceSelect<Value: Hashable>: View {
    var title: String
    @Binding var selection: Value
    var options: [SelectOption<Value>]
    var searchable = false
    var body: some View {
        ActionPopover(title: options.first(where: { $0.value == selection })?.title ?? title, icon: "chevron.down", textLabel: true, searchable: searchable, actions: options.map { option in
            WorkspaceAction(title: option.title, selected: selection == option.value, identity: String(reflecting: option.value)) { selection = option.value }
        }).accessibilityLabel(title).accessibilityValue(options.first(where: { $0.value == selection })?.title ?? "")
            .background(Palette.inputFill, in: .rect(cornerRadius: 8))
    }
}

struct WorkspaceTabs<Value: Hashable>: View {
    @Namespace private var indicator
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var title: String
    @Binding var selection: Value
    var options: [SelectOption<Value>]
    var body: some View {
        HStack(spacing: 4) {
            ForEach(options) { option in
                Button { selection = option.value } label: {
                    Text(option.title).font(.system(size: 13, weight: selection == option.value ? .semibold : .regular))
                        .foregroundStyle(selection == option.value ? .primary : .secondary)
                        .padding(.horizontal, 12).frame(minHeight: 36)
                        .background { if selection == option.value { RoundedRectangle(cornerRadius: 8).fill(Palette.selection).matchedGeometryEffect(id: "selected-tab", in: indicator) } }
                        .contentShape(.rect(cornerRadius: 8))
                }.buttonStyle(OptionButtonStyle()).accessibilityAddTraits(selection == option.value ? .isSelected : [])
            }
        }.animation(reduceMotion ? nil : .easeOut(duration: 0.18), value: selection).accessibilityElement(children: .contain).accessibilityLabel(title)
            .onKeyPress(.rightArrow) { move(1); return .handled }
            .onKeyPress(.leftArrow) { move(-1); return .handled }
    }
    private func move(_ delta: Int) {
        guard !options.isEmpty, let current = options.firstIndex(where: { $0.value == selection }) else { return }
        selection = options[(current + delta + options.count) % options.count].value
    }
}

struct CommandSearch: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    private var actions: [WorkspaceAction] {
        var items = Destination.allCases.map { route in WorkspaceAction(title: route.rawValue, icon: route.icon, detail: "Navigate") { store.navigate(route) } }
        items += [WorkspaceAction(title: "New note", icon: "square.and.pencil", shortcut: "⌘N") { store.newNote() }, WorkspaceAction(title: "New course", icon: "plus", shortcut: "⇧⌘N") { store.showingNewCourse = true }]
        items += store.activeCourses.map { course in WorkspaceAction(title: course.outline.title, icon: "square.stack", detail: "Course", identity: "course-" + course.id.uuidString) { store.openCourse(course.id) } }
        items += store.data.notes.map { note in WorkspaceAction(title: note.title, icon: "doc.text", detail: "Note", identity: "note-" + note.id.uuidString) { store.navigate(.notebook); store.selectedNoteID = note.id } }
        return items
    }
    var body: some View {
        VStack(spacing: 0) {
            ActionList(actions: actions, searchable: true, placeholder: "Search courses, notes, and actions…") { item in dismiss(); DispatchQueue.main.async { item.action() } }
            Divider()
            HStack { Text("↑ ↓ Navigate   ↵ Open"); Spacer(); Button("Close") { dismiss() }.buttonStyle(TextActionStyle()).keyboardShortcut(.cancelAction) }.font(.system(size: 11)).foregroundStyle(.secondary).padding(.horizontal, 14)
        }.frame(width: 560).background(Palette.surface)
    }
}

struct WorkspaceLocation: Equatable {
    var destination: Destination
    var courseID: UUID?
    var sessionID: UUID?
    var noteID: UUID?
}

extension AppStore {
    var appearance: ColorScheme? { data.preferences.appearance == "system" ? nil : (data.preferences.appearance == "dark" ? .dark : .light) }
    var location: WorkspaceLocation { .init(destination: destination, courseID: selectedCourseID, sessionID: activeSessionID, noteID: destination == .notebook ? selectedNoteID : nil) }
    func recordLocation() {
        if navigationHistory.indices.contains(navigationIndex), navigationHistory[navigationIndex] == location { return }
        navigationHistory = Array(navigationHistory.prefix(navigationIndex + 1))
        navigationHistory.append(location)
        if navigationHistory.count > 100 { navigationHistory.removeFirst() }
        navigationIndex = navigationHistory.count - 1
    }
    func moveInHistory(_ delta: Int) {
        let next = navigationIndex + delta
        guard navigationHistory.indices.contains(next) else { return }
        navigationIndex = next
        let target = navigationHistory[next]
        destination = target.destination; selectedCourseID = target.courseID; activeSessionID = target.sessionID; selectedNoteID = target.noteID
    }
}

struct ShortcutGuide: View {
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack { Text("Keyboard shortcuts").font(.title2); Spacer(); Button("Done") { dismiss() }.buttonStyle(QuietButton()).keyboardShortcut(.cancelAction) }
            ForEach(["⌘K|Search and commands", "⌘1–4|Today, Courses, Review, Notebook", "⌘N / ⇧⌘N|New note / New course", "⌘,|Settings", "⌘Return|Check answer or send from focused input", "Space|Reveal a flashcard", "↑ ↓ / Return|Navigate and choose in popovers", "Escape|Close the current popover or dialog"], id: \.self) { row in
                let parts = row.components(separatedBy: "|")
                HStack { Text(parts[1]); Spacer(); Text(parts[0]).monospaced().foregroundStyle(.secondary) }.font(.system(size: 13))
            }
            Text("Enable Keyboard Navigation in macOS System Settings to reach buttons with Tab and activate them with Space. Multiline editors keep Return for a new line.").font(.system(size: 12)).foregroundStyle(.secondary)
        }.padding(28).frame(width: 540)
    }
}
