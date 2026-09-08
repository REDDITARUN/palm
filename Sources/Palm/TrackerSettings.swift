import SwiftUI
import PalmCore

struct SettingsView: View {
    @Environment(AppStore.self) private var store
    @State private var tab = "General"
    @State private var promptKind = TeachingPromptKind.beforeLesson
    @State private var contextKey = ""
    @State private var githubKey = ""
    @State private var reminders = false
    @State private var shortcuts = false
    @State private var status = ""
    @State private var newMemory = ""
    @State private var restoreConfirmation = false
    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Settings").font(.system(size: 18, weight: .semibold)).padding(.bottom, 20).padding(.horizontal, 10)
                ForEach(["General", "Model", "Agents", "Teaching", "Local tools", "Memory", "Data"], id: \.self) { item in
                    Button { tab = item } label: { Text(item).font(.system(size: 13)).frame(maxWidth: .infinity, alignment: .leading).padding(10).background(tab == item ? Palette.selection : .clear, in: .rect(cornerRadius: 8)).contentShape(.rect(cornerRadius: 8)) }.buttonStyle(OptionButtonStyle()).accessibilityAddTraits(tab == item ? .isSelected : [])
                }
                Spacer()
                Button("Keyboard shortcuts") { shortcuts = true }.buttonStyle(TextActionStyle()).font(.system(size: 12))
            }.padding(16).frame(width: 170)
            Divider()
            VStack(alignment: .leading, spacing: 18) {
            Text(tab).font(.system(size: 22, weight: .semibold))
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    switch tab {
                    case "General": general
                    case "Model": model
                    case "Agents": AgentSettingsView()
                    case "Teaching": teaching
                    case "Local tools": tools
                    case "Memory": memories
                    default: storage
                    }
                }.padding(.vertical, 8)
            }
            if !status.isEmpty { Text(status).font(.system(size: 12)).foregroundStyle(Palette.accent) }
            if let busy = store.busy { HStack { ProgressView().controlSize(.small); Text(busy).font(.system(size: 11)) } }
            }.padding(28)
        }.background(Palette.background).sheet(isPresented: $reminders) { DailyReminderSheet() }.sheet(isPresented: $shortcuts) { ShortcutGuide() }
        .onAppear { if !store.isUITesting { contextKey = Keychain.read("context7") ?? ""; githubKey = Keychain.read("github") ?? "" } }
        .confirmationDialog("Restore a saved library? Your current library will be backed up before replacement.", isPresented: $restoreConfirmation) { Button("Choose library backup…") { store.restoreLibrary() } }
        .alert("Settings need attention", isPresented: Binding(get: { store.error != nil }, set: { if !$0 { store.error = nil } })) { Button("OK") { store.error = nil } } message: { Text(store.error ?? "") }
    }
    private var general: some View {
        Group {
            field("Your name") { TextField("Name", text: Binding(get: { store.data.preferences.name }, set: { value in store.updatePreferences { $0.name = value } })).fieldStyle() }
            field("Daily intention") { WorkspaceSelect(title: "Daily intention", selection: Binding(get: { store.data.preferences.dailyMinutes }, set: { value in store.updatePreferences { $0.dailyMinutes = value } }), options: [10, 15, 25, 40, 60].map { .init($0, "\($0) minutes") }) }
            field("Daily reminder") { Button("Choose reminder time…") { reminders = true }.buttonStyle(QuietButton()) }
            field("Appearance") { WorkspaceTabs(title: "Appearance", selection: Binding(get: { store.data.preferences.appearance }, set: { value in store.updatePreferences { $0.appearance = value } }), options: [.init("system", "System"), .init("light", "Light"), .init("dark", "Dark")]) }
            field("Reading size") { WorkspaceSelect(title: "Reading size", selection: Binding(get: { store.data.preferences.readingSize ?? 15 }, set: { value in store.updatePreferences { $0.readingSize = value } }), options: [.init(14.0, "Compact"), .init(15.0, "Default"), .init(17.0, "Large"), .init(19.0, "Larger")]) }
            Toggle("Show practice streak", isOn: Binding(get: { store.data.preferences.showStreak != false }, set: { value in store.updatePreferences { $0.showStreak = value } }))
            Text("Practice questions and flashcard reviews count. Taking a break never removes your learning progress.").font(.system(size: 12)).foregroundStyle(.secondary)

        }
    }
    private var model: some View { ProviderSettingsView() }
    private var teaching: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Explanations that work for you").font(.system(size: 18, weight: .semibold))
            Text("Choose how Palm teaches before practice, writes your recap, and answers note questions. Changes apply to new explanations; saved lessons stay as they are.").font(.system(size: 12)).foregroundStyle(.secondary).lineSpacing(4)
            WorkspaceSelect(title: "Teaching prompt", selection: $promptKind, options: TeachingPromptKind.allCases.map { .init($0, $0.title) })
            TextEditor(text: Binding(get: { store.data.preferences.teachingPrompts?[promptKind.rawValue] ?? promptKind.defaultText }, set: { value in
                store.updatePreferences { preferences in
                    if preferences.teachingPrompts == nil { preferences.teachingPrompts = [:] }
                    preferences.teachingPrompts?[promptKind.rawValue] = value
                }
            })).font(.system(size: 13)).scrollContentBackground(.hidden).padding(12).frame(minHeight: 210).background(Palette.surface, in: .rect(cornerRadius: 10)).overlay(RoundedRectangle(cornerRadius: 10).stroke(Palette.border)).accessibilityLabel(promptKind.title + " prompt")
            HStack { Label("Saved automatically on your Mac", systemImage: "internaldrive").font(.system(size: 11)).foregroundStyle(.secondary); Spacer(); Button("Restore default") { store.updatePreferences { $0.teachingPrompts?.removeValue(forKey: promptKind.rawValue) } }.buttonStyle(QuietButton()) }
            Text("Try: ‘Use Python examples’, ‘Explain every symbol’, or ‘Show a small flow before the code’. Palm keeps the Markdown format, source rules, and answer grading separate from these teaching preferences.").font(.system(size: 12)).foregroundStyle(.secondary).lineSpacing(4)
        }
    }
    private var tools: some View {
        Group {
            Label(store.toolsReady ? "Local tools are ready" : "Local tools need preparation", systemImage: store.toolsReady ? "checkmark.circle" : "puzzlepiece.extension").font(.system(size: 16, weight: .medium)).foregroundStyle(Palette.accent)
            Text("Palm manages OpenCode, Serena, and Mem0 locally. Preparing downloads the required runtime once. Language servers may need your project's language toolchain.").font(.system(size: 12)).foregroundStyle(.secondary).lineSpacing(5)
            Button(store.toolsReady ? "Repair local tools" : "Prepare local tools") { store.prepareTools() }.buttonStyle(PrimaryButton()).disabled(store.busy != nil)
            Divider()
            field("Context7 key (optional documentation retrieval)") { SecureField("Context7 API key", text: $contextKey).fieldStyle() }
            field("GitHub token (optional private repositories)") { SecureField("Read-only repository token", text: $githubKey).fieldStyle() }
            Button("Save tool credentials") { do { try Keychain.save(contextKey, account: "context7"); try Keychain.save(githubKey, account: "github"); status = "Tool credentials saved in Keychain." } catch { store.error = error.localizedDescription } }.buttonStyle(QuietButton())
        }
    }
    private var memories: some View {
        Group {
            Text("What your tutor remembers").font(.system(size: 17, weight: .semibold))
            Text("These are editable preferences and tentative learning observations. Your original answers remain a separate record.").font(.system(size: 12)).foregroundStyle(.secondary).lineSpacing(4)
            HStack { TextField("e.g. Short examples help me understand", text: $newMemory).fieldStyle(); Button("Remember") { var memory = LearnerMemory(text: newMemory, courseID: nil, sourceIDs: []); memory.userEdited = true; store.data.memories.append(memory); store.save(); newMemory = ""; Task { await store.indexMemories() } }.disabled(newMemory.isEmpty) }
            ForEach(store.data.memories.filter { !$0.forgotten }) { memory in
                VStack(alignment: .leading, spacing: 10) {
                    TextField("Memory", text: Binding(get: { store.data.memories.first { $0.id == memory.id }?.text ?? "" }, set: { value in store.editMemory(memory.id, text: value) }), axis: .vertical).textFieldStyle(.plain).font(.system(size: 13))
                    HStack { Text(memory.userEdited ? "Your words" : "Tentative · \(memory.sourceIDs.count) supporting attempt(s)").font(.system(size: 10)).foregroundStyle(.secondary); Spacer(); Button("Forget") { store.forget(memory) }.buttonStyle(TextActionStyle()).font(.system(size: 11)).foregroundStyle(.secondary) }
                }.padding(16).background(Palette.surface, in: .rect(cornerRadius: 10))
            }
            if store.data.memories.filter({ !$0.forgotten }).isEmpty { Text("No memories yet. Useful observations appear as you learn.").font(.system(size: 12)).foregroundStyle(.secondary) }
        }
    }
    private var storage: some View {
        Group {
            Text("Your library belongs to you.").font(.system(size: 18, weight: .semibold))
            Text(store.database.directory.path).font(.system(size: 11, design: .monospaced)).textSelection(.enabled).foregroundStyle(.secondary)
            Text("Back up courses, notes, revision history, attempts, reviews, and code snapshots together. Credentials stay in Keychain. JSON and Markdown exports are also available.").font(.system(size: 12)).foregroundStyle(.secondary).lineSpacing(5)
            HStack { Button("Back up library…") { store.backupLibrary() }.buttonStyle(PrimaryButton()); Button("Restore library…") { restoreConfirmation = true }.buttonStyle(QuietButton()); Button("Export JSON…") { store.exportLibrary() }.buttonStyle(QuietButton()) }
            Button("Show local library in Finder") { NSWorkspace.shared.open(store.database.directory) }.buttonStyle(QuietButton())
            Text("Keep the entire .palmbackup folder together. Restoring an older backup can restore previously forgotten records. JSON exports contain records only; use a full backup to preserve code snapshots and note history.").font(.system(size: 12)).foregroundStyle(.secondary).lineSpacing(5)
        }
    }
    private func field<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View { VStack(alignment: .leading, spacing: 8) { Text(title).font(.system(size: 12, weight: .medium)); content() } }
}
