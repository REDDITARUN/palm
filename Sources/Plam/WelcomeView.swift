import SwiftUI

struct WelcomeView: View {
    @Environment(AppStore.self) private var store
    @State private var step = 0
    @State private var key = ""
    @State private var checking = false
    @State private var keyError: String?
    @State private var name = ""
    @State private var minutes = 15
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                HStack(spacing: 8) { ForEach(0..<3, id: \.self) { i in Capsule().fill(i <= step ? Palette.accent : Palette.border).frame(width: 28, height: 4) }; Spacer(); Text("\(step + 1) / 3").font(.system(size: 11, design: .monospaced)).foregroundStyle(.tertiary) }.padding(.bottom, 26)
                if step == 0 {
                    PageHeading(eyebrow: "Welcome to Plam", title: "Learn something deeply.", subtitle: "Build courses from your questions and code. Practice, take notes, and revisit what matters.")
                    feature("point.topleft.down.to.point.bottomright.curvepath", "A path made for you", "From first principles to real-world understanding.")
                    feature("curlybraces", "Learn from actual code", "Explore your repositories with source-linked lessons.")
                    feature("arrow.trianglehead.clockwise", "Remember what matters", "Practice, reflect, and return at the right time.")
                    Button { step = 1 } label: { HStack { Text("Continue"); Spacer(); Image(systemName: "arrow.right") }.frame(maxWidth: .infinity) }.buttonStyle(PrimaryButton()).padding(.top, 12).accessibilityIdentifier("welcome-start")
                } else if step == 1 {
                    PageHeading(eyebrow: "", title: "Connect your model", subtitle: "Your model creates the lessons and answers your questions. Selected learning context is sent to that provider.")
                    WorkspaceTabs(title: "Provider", selection: Binding(get: { store.providerName }, set: { value in store.selectProvider(value); key = store.apiKey }), options: [.init("OpenRouter", "OpenRouter"), .init("OpenAI", "OpenAI")])
                    VStack(alignment: .leading, spacing: 7) {
                        Link("1. Create your \(store.providerName) API key ↗", destination: URL(string: store.configuration.isOpenRouter ? "https://openrouter.ai/settings/keys" : "https://platform.openai.com/api-keys")!)
                        Text("2. Paste your key below. Connect, then choose a topic.").foregroundStyle(.secondary)
                    }.font(.system(size: 12))
                    VStack(alignment: .leading, spacing: 9) { Text("\(store.providerName) API key").font(.system(size: 12, weight: .semibold)); SecureField("sk-…", text: $key).fieldStyle().accessibilityIdentifier("api-key") }
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Model").font(.system(size: 12, weight: .semibold))
                        TextField("Model ID", text: Binding(get: { store.data.preferences.model }, set: { value in store.updatePreferences { $0.model = value } })).fieldStyle().accessibilityLabel("Onboarding model")
                        Text(store.configuration.isOpenRouter ? "Start with Inkling free, or enter another free or paid model ID. Change models anytime in Settings." : "OpenAI API usage is billed separately from a ChatGPT subscription.").font(.system(size: 11)).foregroundStyle(.secondary)
                        if store.configuration.requiresHarness {
                            Text("Inkling free needs a one-time tools download. Its provider logs prompts and outputs for model improvement; use non-confidential learning material.").font(.system(size: 11)).foregroundStyle(.secondary)
                            Link("Free model details and terms ↗", destination: URL(string: "https://openrouter.ai/thinkingmachines/inkling:free")!).font(.system(size: 11))
                        }
                    }
                    Text("Your key stays in macOS Keychain. Plam is free; provider pricing and limits apply.").font(.system(size: 11)).foregroundStyle(.secondary).lineSpacing(4)
                    if let keyError { Text(keyError).font(.system(size: 12)).foregroundStyle(.red) }
                    Button {
                        checking = true; keyError = nil
                        Task { do { try await store.validateKey(key.trimmingCharacters(in: .whitespacesAndNewlines)); step = 2 } catch { keyError = error.localizedDescription }; checking = false }
                    } label: { HStack { if checking { ProgressView().controlSize(.small) }; Text(checking ? "Checking connection…" : "Connect & continue"); Spacer(); Image(systemName: "arrow.right") } }.buttonStyle(PrimaryButton()).disabled(key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || store.data.preferences.model.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || checking)
                    Button("I'll add a key in Settings") { step = 2 }.buttonStyle(TextActionStyle()).font(.system(size: 12)).foregroundStyle(.secondary)
                } else {
                    PageHeading(eyebrow: "", title: "Make it yours", subtitle: "You can change these preferences anytime.")
                    VStack(alignment: .leading, spacing: 9) { Text("What should we call you?").font(.system(size: 12, weight: .semibold)); TextField("Your name (optional)", text: $name).fieldStyle().accessibilityIdentifier("learner-name") }
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Daily learning intention").font(.system(size: 12, weight: .semibold))
                        WorkspaceTabs(title: "Daily learning intention", selection: $minutes, options: [10, 15, 25, 40].map { .init($0, "\($0) min") })
                    }
                    VStack(alignment: .leading, spacing: 7) {
                        Label("Your code is optional", systemImage: "curlybraces").font(.system(size: 13, weight: .medium))
                        Text("Start with any topic. For code-based lessons, open Repositories and add a local folder or GitHub URL. Private repos use a read-only token in Settings → Local tools.").font(.system(size: 12)).foregroundStyle(.secondary).lineSpacing(3)
                    }.padding(.vertical, 8)
                    Button { store.updatePreferences { $0.name = name; $0.dailyMinutes = minutes; $0.onboardingComplete = true } } label: { HStack { Text("Start learning"); Spacer(); Image(systemName: "arrow.right") } }.buttonStyle(PrimaryButton()).padding(.top, 10).accessibilityIdentifier("finish-onboarding")
                }
                Spacer(minLength: 0)
                if step > 0 { Button { step -= 1 } label: { Label("Back", systemImage: "arrow.left") }.buttonStyle(TextActionStyle()).font(.system(size: 12)).foregroundStyle(.secondary) }
            }.padding(40).frame(maxWidth: 550, alignment: .leading)
        }.frame(maxWidth: .infinity, maxHeight: .infinity).padding(.top, 20).onAppear { key = store.apiKey; name = store.data.preferences.name; minutes = store.data.preferences.dailyMinutes }
    }
    private func feature(_ icon: String, _ title: String, _ description: String) -> some View {
        HStack(alignment: .top, spacing: 14) { Image(systemName: icon).font(.system(size: 17)).foregroundStyle(Palette.accent).frame(width: 38, height: 38).background(Palette.soft, in: .rect(cornerRadius: 11)); VStack(alignment: .leading, spacing: 5) { Text(title).font(.system(size: 14, weight: .semibold)); Text(description).font(.system(size: 12)).foregroundStyle(.secondary).lineSpacing(3) } }
    }
}
