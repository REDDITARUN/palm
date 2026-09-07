import SwiftUI
import PlamCore

struct AgentSettingsView: View {
    @Environment(AppStore.self) private var store
    @State private var model: ModelProfile?
    @State private var server: MCPServerProfile?
    @State private var skill: AgentSkillProfile?
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            section("Model routes", detail: "Save models and assign them to planning, lessons, grading, notes, or the tutor. Unassigned tasks use your default model.") { model = ModelProfile() }
            ForEach(store.data.modelProfiles ?? []) { profile in
                row(profile.name.isEmpty ? profile.model : profile.name, detail: profile.roles.isEmpty ? "Saved · uses no task routes" : profile.roles.joined(separator: ", "), icon: "cpu") { model = profile }
            }
            section("MCP connections", detail: "Tools available to the repository researcher. Enable only the tool names you want it to call. Serena remains available through Local tools.") { server = MCPServerProfile() }
            ForEach(store.data.mcpServers ?? []) { profile in row(profile.name, detail: profile.enabled ? "Enabled · \(profile.allowedTools.count) tool rules" : "Disabled", icon: "puzzlepiece.extension") { server = profile } }
            section("Teaching skills", detail: "Reusable instructions included in learning generation and tutor conversations. Skills do not grant tool permissions.") { skill = AgentSkillProfile() }
            ForEach(store.data.agentSkills ?? []) { profile in row(profile.name, detail: profile.enabled ? "Enabled" : "Disabled", icon: "text.document") { skill = profile } }
        }
        .sheet(item: $model) { ModelProfileEditor(profile: $0) }
        .sheet(item: $server) { MCPProfileEditor(profile: $0) }
        .sheet(item: $skill) { SkillProfileEditor(profile: $0) }
    }
    private func section(_ title: String, detail: String, add: @escaping () -> Void) -> some View { VStack(alignment: .leading, spacing: 8) { HStack { Text(title).font(.system(size: 16, weight: .semibold)); Spacer(); Button(action: add) { Image(systemName: "plus") }.buttonStyle(IconButton()).accessibilityLabel("Add " + title) }; Text(detail).font(.system(size: 12)).foregroundStyle(.secondary) } }
    private func row(_ title: String, detail: String, icon: String, action: @escaping () -> Void) -> some View { Button(action: action) { HStack(spacing: 12) { Image(systemName: icon).foregroundStyle(Palette.accent); VStack(alignment: .leading, spacing: 5) { Text(title).font(.system(size: 13, weight: .medium)); Text(detail).font(.system(size: 11)).foregroundStyle(.secondary) }; Spacer(); Image(systemName: "chevron.right").font(.system(size: 10)) }.padding(14).frame(maxWidth: .infinity).contentShape(.rect) }.buttonStyle(OptionButtonStyle()) }
}

struct ModelProfileEditor: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State var profile: ModelProfile
    @State private var key = ""
    @State private var validating = false
    @State private var error = ""
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Model profile").font(.system(size: 20, weight: .semibold))
            TextField("Name", text: $profile.name).fieldStyle()
            TextField("API base URL", text: $profile.endpoint).fieldStyle()
            TextField("Model ID", text: $profile.model).fieldStyle()
            SecureField("API key · leave empty to reuse the provider key", text: $key).fieldStyle()
            Text("Use for").font(.system(size: 12, weight: .medium))
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 150))], alignment: .leading) { ForEach(["planning", "lessons", "grading", "notes", "tutor", "research"], id: \.self) { role in Toggle(role.capitalized, isOn: Binding(get: { profile.roles.contains(role) }, set: { enabled in profile.roles.removeAll { $0 == role }; if enabled { profile.roles.append(role) } })).toggleStyle(.checkbox).font(.system(size: 11)) } }
            if !error.isEmpty { Text(error).font(.system(size: 12)).foregroundStyle(.red) }
            HStack { Button("Cancel") { dismiss() }.buttonStyle(QuietButton()); Button("Delete") { store.data.modelProfiles?.removeAll { $0.id == profile.id }; store.save(); dismiss() }.buttonStyle(TextActionStyle()); Spacer(); Button(validating ? "Validating…" : "Validate and save") { save() }.buttonStyle(PrimaryButton()).disabled(validating || profile.model.isEmpty) }
        }.padding(28).frame(width: 620)
    }
    private func save() {
        validating = true
        Task {
            defer { validating = false }
            do {
                let config = ModelConfiguration(key: "", endpoint: profile.endpoint, model: profile.model)
                let credential = key.isEmpty ? (Keychain.read(config.credentialAccount) ?? (profile.endpoint == store.configuration.endpoint ? store.apiKey : "")) : key
                let models = try await store.ai.validateKey(.init(key: credential, endpoint: profile.endpoint, model: profile.model))
                guard models.contains(profile.model) else { error = "This provider did not list that model. Check the exact model ID."; return }
                if !key.isEmpty { try Keychain.save(key, account: config.credentialAccount); if profile.endpoint == store.configuration.endpoint { store.apiKey = key } }
                if store.data.modelProfiles == nil { store.data.modelProfiles = [] }
                for i in store.data.modelProfiles!.indices { store.data.modelProfiles?[i].roles.removeAll { profile.roles.contains($0) } }
                store.data.modelProfiles?.removeAll { $0.id == profile.id }; store.data.modelProfiles?.append(profile); store.save(); dismiss()
            } catch { self.error = error.localizedDescription }
        }
    }
}
struct MCPProfileEditor: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State var profile: MCPServerProfile
    @State private var arguments = ""
    @State private var tools = ""
    @State private var token = ""
    @State private var error = ""
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("MCP connection").font(.system(size: 20, weight: .semibold))
            TextField("Name · letters, numbers, underscore", text: $profile.name).fieldStyle()
            WorkspaceTabs(title: "Transport", selection: $profile.transport, options: [.init("remote", "Remote HTTPS"), .init("local", "Local command")])
            if profile.transport == "remote" { TextField("MCP endpoint", text: $profile.url).fieldStyle(); SecureField("Optional bearer token · stored in Keychain", text: $token).fieldStyle() }
            else { TextField("Absolute executable path", text: $profile.command).fieldStyle(); TextField("Arguments · one per line", text: $arguments, axis: .vertical).lineLimit(3...6).fieldStyle(); Text("The enabled local server runs on your Mac when repository research starts.").font(.system(size: 11)).foregroundStyle(.secondary) }
            TextField("Allowed tool names, separated by commas", text: $tools).fieldStyle()
            Text("Use names from the server's documentation. * allows all tools on this connection.").font(.system(size: 11)).foregroundStyle(.secondary)
            Toggle("Enabled for repository research", isOn: $profile.enabled).toggleStyle(.switch)
            if !error.isEmpty { Text(error).font(.system(size: 12)).foregroundStyle(.red) }
            HStack { Button("Cancel") { dismiss() }.buttonStyle(QuietButton()); Button("Delete") { store.data.mcpServers?.removeAll { $0.id == profile.id }; store.save(); dismiss() }.buttonStyle(TextActionStyle()); Spacer(); Button("Save connection") { save() }.buttonStyle(PrimaryButton()) }
        }.padding(28).frame(width: 600).onAppear { arguments = profile.arguments.joined(separator: "\n"); tools = profile.allowedTools.joined(separator: ", ") }
    }
    private func save() {
        guard !profile.name.isEmpty, profile.name.range(of: "^[A-Za-z][A-Za-z0-9_]*$", options: .regularExpression) != nil, !["serena", "context7"].contains(profile.name), !(store.data.mcpServers ?? []).contains(where: { $0.id != profile.id && $0.name == profile.name }) else { error = "Choose a unique connection name using letters, numbers, and underscores."; return }
        if profile.transport == "remote" { guard let url = URL(string: profile.url), url.scheme == "https", url.host != nil else { error = "Use a valid HTTPS MCP endpoint."; return } }
        else { guard profile.command.hasPrefix("/"), FileManager.default.isExecutableFile(atPath: profile.command) else { error = "Choose an existing executable using its full path."; return } }
        profile.arguments = arguments.components(separatedBy: .newlines).filter { !$0.isEmpty }; profile.allowedTools = tools.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        if profile.enabled && profile.allowedTools.isEmpty { error = "Specify at least one allowed tool before enabling this connection."; return }
        do { if !token.isEmpty { try Keychain.save(token, account: profile.credentialAccount) } } catch { self.error = error.localizedDescription; return }
        if store.data.mcpServers == nil { store.data.mcpServers = [] }; store.data.mcpServers?.removeAll { $0.id == profile.id }; store.data.mcpServers?.append(profile); store.save(); dismiss()
    }
}
struct SkillProfileEditor: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State var profile: AgentSkillProfile
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Teaching skill").font(.system(size: 20, weight: .semibold))
            TextField("Skill name", text: $profile.name).fieldStyle()
            TextEditor(text: $profile.instructions).font(.system(size: 14)).proseNavigation().frame(height: 250).accessibilityLabel("Skill instructions")
            Toggle("Enabled", isOn: $profile.enabled).toggleStyle(.switch)
            HStack { Button("Cancel") { dismiss() }.buttonStyle(QuietButton()); Button("Delete") { store.data.agentSkills?.removeAll { $0.id == profile.id }; store.save(); dismiss() }.buttonStyle(TextActionStyle()); Spacer(); Button("Save skill") { if store.data.agentSkills == nil { store.data.agentSkills = [] }; store.data.agentSkills?.removeAll { $0.id == profile.id }; store.data.agentSkills?.append(profile); store.save(); dismiss() }.buttonStyle(PrimaryButton()).disabled(profile.name.isEmpty || profile.instructions.isEmpty) }
        }.padding(28).frame(width: 620)
    }
}
