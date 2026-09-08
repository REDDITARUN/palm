import SwiftUI
import AppKit
import PalmCore

extension AppStore {
    var providerConnections: [ProviderConnection] { data.preferences.providerConnections ?? [] }
    var hasModelAccess: Bool { modelAvailable(configuration) }
    func modelAvailable(_ config: ModelConfiguration) -> Bool { !config.model.isEmpty && (config.authentication == .chatGPT ? chatGPTConnected : (!config.key.isEmpty || config.allowsEmptyKey)) }
    func hasModelAccess(for role: String) -> Bool { modelAvailable(modelConfiguration(for: role)) }
    func connectionKey(_ connection: ProviderConnection) -> String {
        guard connection.authentication == .apiKey else { return "" }
        if isUITesting && !isLiveTesting { return testProviderKeys[connection.credentialAccount] ?? "" }
        return Keychain.read(connection.credentialAccount) ?? ""
    }
    func loadActiveConnection() {
        data.preferences.migrateProviders()
        guard let active = data.preferences.activeProvider else { return }
        apiKey = connectionKey(active); modelIDs = active.modelIDs
    }
    func saveConnection(_ draft: ProviderConnection, replacementKey: String, activate: Bool) throws {
        var connection = try draft.validated()
        if let old = providerConnections.first(where: { $0.id == draft.id }), old.endpoint.trimmingCharacters(in: .whitespacesAndNewlines) != connection.endpoint {
            connection.legacyCredentialAccount = nil
        }
        let key = replacementKey.trimmingCharacters(in: .whitespacesAndNewlines)

        if !key.isEmpty && connection.authentication == .apiKey {
            if isUITesting && !isLiveTesting { testProviderKeys[connection.credentialAccount] = key }
            else { try Keychain.save(key, account: connection.credentialAccount) }
        }
        var next = data; next.preferences.saveProvider(connection, activate: activate)
        try database.save(next); data = next; loadActiveConnection()
    }
    func forgetConnectionKey(_ connection: ProviderConnection) throws {
        if isUITesting && !isLiveTesting { testProviderKeys[connection.credentialAccount] = nil }
        else { try Keychain.save("", account: connection.credentialAccount) }
        if data.preferences.selectedProviderID == connection.id { apiKey = "" }
    }
    func activateConnection(_ id: UUID) throws {
        var next = data; next.preferences.activateProvider(id)
        try database.save(next); data = next; loadActiveConnection()
    }
    func refreshChatGPTStatus() async {
        guard await runtime.isReady() else { chatGPTConnected = false; return }
        do { let status = try await chatGPTAuth.status(); chatGPTConnected = status.connected; chatGPTModels = status.models }
        catch { chatGPTConnected = false }
    }
}

struct ProviderSettingsView: View {
    @Environment(AppStore.self) private var store
    @State private var selectedID: UUID?
    @State private var draft = ProviderConnection.preset("OpenRouter")
    @State private var key = ""
    @State private var status = ""
    @State private var failure = ""
    @State private var working = false
    @State private var signInTask: Task<Void, Never>?
    @State private var newKind = "OpenRouter"
    @State private var pendingSwitch: UUID?
    @State private var discard = false
    @State private var baseline = ProviderConnection.preset("OpenRouter")
    private var dirty: Bool { draft != baseline || !key.isEmpty }
    private var saved: Bool { store.providerConnections.contains { $0.id == draft.id } }
    private var isActive: Bool { store.data.preferences.selectedProviderID == draft.id }
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Your connections").font(.system(size: 17, weight: .semibold))
            Text("Save several providers. Choose which connection Palm uses by default; task-specific models live in Agents.").font(.system(size: 12)).foregroundStyle(.secondary)
            ForEach(store.providerConnections) { connection in
                Button {
                    if dirty && connection.id != draft.id { pendingSwitch = connection.id; discard = true }
                    else { load(connection) }
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: connection.authentication == .chatGPT ? "person.crop.circle" : "cpu").foregroundStyle(Palette.accent)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(connection.name).font(.system(size: 13, weight: .medium))
                            Text(connection.model.isEmpty ? "Choose a model" : connection.model).font(.system(size: 11)).foregroundStyle(.secondary).lineLimit(1)
                        }
                        Spacer()
                        if connection.id == store.data.preferences.selectedProviderID { Text("In use").font(.system(size: 11)).foregroundStyle(Palette.accent) }
                        if connection.id == selectedID { Image(systemName: "checkmark").font(.system(size: 11)) }
                    }.padding(12).background(connection.id == selectedID ? Palette.selection : .clear, in: .rect(cornerRadius: 9)).contentShape(.rect)
                }.buttonStyle(OptionButtonStyle()).disabled(working)
            }
            HStack {
                WorkspaceSelect(title: "Connection type", selection: $newKind, options: ["OpenRouter", "OpenAI", "ChatGPT", "Custom"].map { .init($0, $0) })
                Button("Add connection") { load(.preset(newKind)) }.buttonStyle(QuietButton()).disabled(dirty || working)
            }
            Divider().padding(.vertical, 4)
            field("Connection name") { TextField("Connection name", text: $draft.name).fieldStyle() }
            if draft.authentication == .chatGPT { chatGPT }
            else {
                field("API base URL") { TextField("https://provider.example/v1", text: $draft.endpoint).fieldStyle() }
                field("API key") { SecureField(saved ? "Leave blank to keep this connection’s key" : "Paste a key · optional for localhost", text: $key).fieldStyle() }
                HStack {
                    Text("Keys stay in macOS Keychain.").font(.system(size: 11)).foregroundStyle(.secondary)
                    Spacer()
                    if saved { Button("Forget API key") { perform { if let original = store.providerConnections.first(where: { $0.id == draft.id }) { try store.forgetConnectionKey(original) }; key = ""; status = "Key removed. This connection cannot use it again until you add one." } }.buttonStyle(TextActionStyle()).font(.system(size: 11)).disabled(working) }
                }
            }
            field("Model ID") { TextField("Paste any exact model ID", text: $draft.model).fieldStyle() }
            if !(draft.authentication == .chatGPT ? store.chatGPTModels : draft.modelIDs).isEmpty {
                WorkspaceSelect(title: "Browse models", selection: $draft.model, options: catalogue.map { .init($0, $0) }, searchable: true)
            }
            if draft.configuration().isOpenRouter { Toggle("Show free models only in the list", isOn: $draft.freeOnly).font(.system(size: 12)) }
            Text("Custom model IDs are saved exactly as entered. Palm never switches to a paid model automatically.").font(.system(size: 11)).foregroundStyle(.secondary)
            HStack(spacing: 10) {
                Button("Save") { save(activate: false) }.buttonStyle(QuietButton()).disabled(working || draft.model.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                Button(isActive ? "Save & keep using" : "Save & use") { save(activate: true) }.buttonStyle(PrimaryButton()).disabled(working || draft.model.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                Spacer()
                Button("Refresh models") { refresh() }.buttonStyle(TextActionStyle()).font(.system(size: 12)).disabled(working)
            }
            if dirty { Button("Discard changes") { if let original = store.providerConnections.first(where: { $0.id == selectedID }) { load(original) } else if let active = store.data.preferences.activeProvider { load(active) } }.buttonStyle(TextActionStyle()).font(.system(size: 12)) }
            if working { HStack { ProgressView().controlSize(.small); Text("Connecting…").font(.system(size: 12)) } }
            if !status.isEmpty { Text(status).font(.system(size: 12)).foregroundStyle(Palette.accent) }
            if !failure.isEmpty { Text(failure).font(.system(size: 12)).foregroundStyle(.red).textSelection(.enabled) }
        }
        .onAppear { if let active = store.data.preferences.activeProvider { load(active) } }
        .task { if store.providerConnections.contains(where: { $0.authentication == .chatGPT }) { await store.refreshChatGPTStatus() } }
        .onDisappear { signInTask?.cancel(); Task { await store.chatGPTAuth.stop() } }
        .alert("Discard unsaved connection changes?", isPresented: $discard) {
            Button("Keep editing", role: .cancel) { pendingSwitch = nil }
            Button("Discard", role: .destructive) { if let connection = store.providerConnections.first(where: { $0.id == pendingSwitch }) { load(connection) }; pendingSwitch = nil }
        }
    }
    private var catalogue: [String] {
        let ids = draft.authentication == .chatGPT ? store.chatGPTModels : draft.modelIDs
        return Array(Set(ids + (draft.model.isEmpty ? [] : [draft.model]))).filter { $0 == draft.model || !draft.configuration().isOpenRouter || !draft.freeOnly || $0.hasSuffix(":free") || $0 == "openrouter/free" }.sorted()
    }
    private var chatGPT: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(store.chatGPTConnected ? "ChatGPT connected through OpenCode" : "Use your ChatGPT account’s Codex access").font(.system(size: 13, weight: .medium))
            Text("Available models and limits depend on your subscription. This connection does not use an OpenAI API key or fall back to API billing.").font(.system(size: 12)).foregroundStyle(.secondary)
            HStack {
                Button(store.chatGPTConnected ? "Sign in again" : "Sign in with ChatGPT") { signIn() }.buttonStyle(QuietButton()).disabled(working || store.busy != nil)
                if signInTask != nil { Button("Cancel sign-in") { signInTask?.cancel(); status = "Cancelling sign-in…"; Task { await store.chatGPTAuth.stop() } }.buttonStyle(TextActionStyle()) }
                if store.chatGPTConnected { Button("Sign out") { working = true; Task { defer { working = false }; do { try await store.chatGPTAuth.disconnect(); store.chatGPTConnected = false; store.chatGPTModels = []; status = "Signed out of Palm’s ChatGPT connection." } catch { failure = error.localizedDescription } } }.buttonStyle(TextActionStyle()).disabled(working || store.busy != nil || store.tutorBusy) }
            }
        }
    }
    private func load(_ value: ProviderConnection) { draft = value; baseline = value; selectedID = value.id; key = ""; status = ""; failure = "" }
    private func perform(_ action: () throws -> Void) { failure = ""; do { try action() } catch { failure = error.localizedDescription } }
    private func save(activate: Bool) {
        perform {
            try store.saveConnection(draft, replacementKey: key, activate: activate)
            if let saved = store.providerConnections.first(where: { $0.id == draft.id }) { load(saved) }
            status = activate || isActive ? "Saved. Palm is using this connection." : "Connection saved. Your active provider is unchanged."
        }
    }
    private func refresh() {
        working = true; failure = ""; status = ""
        let snapshot = draft; let credential = key.isEmpty ? store.connectionKey(draft) : key
        Task {
            defer { working = false }
            do {
                if snapshot.authentication == .chatGPT {
                    let account = try await store.chatGPTAuth.status(); store.chatGPTConnected = account.connected; store.chatGPTModels = account.models
                    guard account.connected else { throw PalmError.message("Sign in with ChatGPT to see the models available through OpenCode.") }
                } else {
                    let models = try await store.ai.validateKey(snapshot.configuration(key: credential))
                    guard draft.id == snapshot.id && draft.endpoint == snapshot.endpoint else { throw PalmError.message("The endpoint changed while refreshing. Refresh again for the new endpoint.") }
                    draft.modelIDs = models
                }
                status = "Model list refreshed. Your custom model is still selected. Save to keep changes."
            } catch { failure = "Could not refresh models. You can still save a custom model ID. " + error.localizedDescription }
        }
    }
    private func signIn() {
        working = true; failure = ""; status = "Preparing ChatGPT sign-in…"
        signInTask = Task {
            defer { working = false; signInTask = nil }
            do {
                if !(await store.runtime.isReady()) { try await store.runtime.prepare(); store.toolsReady = await store.runtime.isReady() }
                let auth = try await store.chatGPTAuth.begin()
                try Task.checkCancellation()
                guard NSWorkspace.shared.open(auth.url) else { throw PalmError.message("Could not open your browser for sign-in.") }
                status = "Finish signing in in your browser. " + auth.instructions
                let result = try await store.chatGPTAuth.complete(); try Task.checkCancellation()
                store.chatGPTConnected = result.connected; store.chatGPTModels = result.models
                status = "Connected. Choose a model, then Save & use."
            } catch { if !Task.isCancelled { failure = error.localizedDescription }; await store.chatGPTAuth.stop() }
        }
    }
    private func field<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 7) { Text(title).font(.system(size: 12, weight: .medium)); content() }
    }
}
