import SwiftUI
import PalmCore

extension AppStore {
    func conversation(_ scope: String) -> TutorConversation {
        if let conversation = data.conversations?.first(where: { $0.id == scope }) { return conversation }
        var conversation = TutorConversation(id: scope)
        if scope.hasPrefix("session:"), let id = UUID(uuidString: String(scope.dropFirst(8))), let session = data.sessions.first(where: { $0.id == id }) { conversation.messages = session.messages; conversation.draft = session.tutorDraft ?? "" }
        return conversation
    }
    func updateConversation(_ scope: String, _ change: (inout TutorConversation) -> Void) {
        var conversation = conversation(scope); change(&conversation); conversation.updatedAt = Date()
        if data.conversations == nil { data.conversations = [] }
        if let i = data.conversations?.firstIndex(where: { $0.id == scope }) { data.conversations?[i] = conversation } else { data.conversations?.append(conversation) }
        do { try database.saveConversation(conversation) } catch { self.error = "Could not save the conversation: " + error.localizedDescription }
        // Keep lesson evidence and old recap consumers in sync.
        if scope.hasPrefix("session:"), let id = UUID(uuidString: String(scope.dropFirst(8))), let i = data.sessions.firstIndex(where: { $0.id == id }) { data.sessions[i].messages = conversation.messages; data.sessions[i].tutorDraft = conversation.draft }
    }
    func branchTutor(_ scope: String, at messageID: UUID) {
        guard !tutorBusy else { return }
        let original = conversation(scope)
        guard let index = original.messages.firstIndex(where: { $0.id == messageID }) else { return }
        var archived = original; archived.id = scope + ":branch:" + UUID().uuidString
        if data.conversations == nil { data.conversations = [] }; data.conversations?.append(archived)
        updateConversation(scope) { $0.draft = original.messages[index].content; $0.messages = Array(original.messages.prefix(index)) }; save()
    }
    func sendTutor(_ text: String, scope: String, selection: String, questionHelp: Bool = true, editNote: Bool = false) {
        guard !tutorBusy, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        let sessionID = scope.hasPrefix("session:") ? UUID(uuidString: String(scope.dropFirst(8))) : nil
        let session = data.sessions.first { $0.id == sessionID }
        let noteID = scope.hasPrefix("note:") ? UUID(uuidString: String(scope.dropFirst(5))) : nil
        let note = data.notes.first { $0.id == noteID }
        let previous = conversation(scope).messages.suffix(12).map { "\($0.role): \($0.content)" }.joined(separator: "\n")
        updateConversation(scope) { if $0.messages.last?.role != "user" || $0.messages.last?.content != text || $0.messages.last?.selection != selection { $0.messages.append(ChatMessage(role: "user", content: text, selection: selection)) }; $0.draft = "" }; save()
        tutorBusy = true; tutorScope = scope; tutorStreamingText = ""; tutorStatus = "Preparing context"; tutorFailure = nil
        // Record assistance immediately, including interrupted streams that may reveal hints.
        if questionHelp, let session, session.stage == .practice, let question = session.currentQuestion, !session.attempts.contains(where: { $0.questionID == question.id }) { updateSession(session.id) { $0.hints[question.id, default: 0] += 1 } }
        let config = modelConfiguration(for: "tutor")
        tutorTask = Task {
            var reply = ChatMessage(role: "assistant", content: "")
            reply.isPartial = true; tutorMessageID = reply.id
            updateConversation(scope) { $0.messages.append(reply) }
            if editNote, let note { reply.proposedNoteID = note.id; reply.originalNoteBody = note.body }
            defer { tutorBusy = false; tutorTask = nil; tutorStatus = ""; tutorStreamingText = ""; tutorMessageID = nil }
            do {
                var context = ""
                if let session { context = "Lesson: \(session.content.title)\nMaterial: \(session.content.material)\nQuestion: \(session.currentQuestion?.prompt ?? "")\nCode:\n\(session.currentQuestion?.code ?? "")\n" + (await relevantMemories(query: text, courseID: session.courseID)) }
                if let note { context += "\nCurrent note: \(note.title)\n<note>\(note.body)</note>" }
                context += "\nRelated saved knowledge:\n" + KnowledgeIndex.context(data, query: text + " " + selection, excluding: noteID)
                let skills = (data.agentSkills ?? []).filter(\.enabled).map(\.instructions).joined(separator: "\n")
                let prompt = TeachingPrompts.resolved(.noteTutor, preferences: data.preferences) + "\n" + skills + "\n" + context + "\nPrevious conversation:\n" + previous + "\nSelected passage: <selection>\(selection)</selection>\nLearner: \(text)\n" + (editNote ? "Propose a revised version of the complete current note. Return ONLY the proposed Markdown document, preserving useful existing content and making only requested changes. Do not add commentary or an outer Markdown fence." : "Answer directly. If asked for a hint, do not reveal the full answer. Cite relevant saved notes as [[exact note title]].")
                try await ai.streamTutor(prompt, config: config) { [self] event in
                    await receiveTutorEvent(event, scope: scope)
                }
                try Task.checkCancellation()
                reply.content = tutorStreamingText; reply.isPartial = false
                updateConversation(scope) { conversation in if let i = conversation.messages.firstIndex(where: { $0.id == reply.id }) { conversation.messages[i] = reply } }; save()
            } catch {
                reply.content = tutorStreamingText; reply.proposedNoteID = nil
                updateConversation(scope) { conversation in
                    if let i = conversation.messages.firstIndex(where: { $0.id == reply.id }) { if reply.content.isEmpty { conversation.messages.remove(at: i) } else { conversation.messages[i] = reply } }
                }
                tutorFailure = Task.isCancelled ? "Response stopped. You can send another message." : error.localizedDescription
                save()
            }
        }
    }
    func receiveTutorEvent(_ event: TutorEvent, scope: String) {
        switch event {
        case .status(let status): tutorStatus = status
        case .text(let delta):
            tutorStreamingText += delta
            if Date().timeIntervalSince(tutorCheckpoint) >= 1 {
                tutorCheckpoint = Date()
                let content = tutorStreamingText; let id = tutorMessageID
                updateConversation(scope) { conversation in if let index = conversation.messages.firstIndex(where: { $0.id == id }) { conversation.messages[index].content = content } }
            }
        case .finished: break
        }
    }
    func applyNoteProposal(_ message: ChatMessage) {
        guard message.isPartial != true, let id = message.proposedNoteID, let original = message.originalNoteBody, let note = data.notes.first(where: { $0.id == id }) else { return }
        guard note.body == original else { error = "This note has changed since the suggestion was generated. Ask for an updated edit so your changes are preserved."; return }
        let revision = NoteRevision(note: note)
        if let index = data.notes.firstIndex(where: { $0.id == id }) { data.notes[index].body = message.content; data.notes[index].blocksJSON = nil; data.notes[index].documentRevision = UUID(); data.notes[index].updatedAt = Date(); save(revision: revision); notice = "Note updated. The previous version is in revision history." }
    }
    func modelConfiguration(for role: String) -> ModelConfiguration {
        guard let profile = data.modelProfiles?.first(where: { $0.roles.contains(role) }) else { return configuration }
        if let id = profile.providerID {
            guard let connection = providerConnections.first(where: { $0.id == id }) else { return .init(key: "", endpoint: profile.endpoint, model: profile.model) }
            var config = connection.configuration(key: connectionKey(connection)); config.model = profile.model; return config
        }
        let config = ModelConfiguration(key: "", endpoint: profile.endpoint, model: profile.model)
        return ModelConfiguration(key: Keychain.read(config.credentialAccount) ?? (profile.endpoint == configuration.endpoint ? apiKey : ""), endpoint: profile.endpoint, model: profile.model)
    }
}

struct WorkspaceTutor: View {
    @Environment(AppStore.self) private var store
    var scope: String
    @Binding var selection: String
    @State private var editNote = false
    @State private var questionHelp = true
    @State private var showHistory = false
    private var conversation: TutorConversation { store.conversation(scope) }
    private var running: Bool { store.tutorBusy && store.tutorScope == scope }
    private var draft: Binding<String> { Binding(get: { conversation.draft }, set: { value in store.updateConversation(scope) { $0.draft = value } }) }
    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 22) {
                        if conversation.messages.isEmpty {
                            VStack(alignment: .leading, spacing: 8) { Text("Make the idea clearer").font(.system(size: 16, weight: .semibold)); Text(scope.hasPrefix("note:") ? "Ask a question, select a passage, or describe a change to this note." : "Ask about this step or click a code element.").font(.system(size: 13)).foregroundStyle(.secondary).lineSpacing(4) }.padding(.vertical, 22)
                        }
                        ForEach(conversation.messages.filter { !running || $0.id != store.tutorMessageID }) { message in
                            VStack(alignment: .leading, spacing: 10) {
                                HStack { Text(message.role == "user" ? "You" : (message.proposedNoteID != nil ? "Proposed edit" : "Palm")).font(.system(size: 11, weight: .medium)).foregroundStyle(.secondary); Spacer(); if message.role == "user" { Button { store.branchTutor(scope, at: message.id) } label: { Image(systemName: "pencil") }.buttonStyle(IconButton()).help("Edit and resend · keeps the previous branch").accessibilityLabel("Edit message").disabled(store.tutorBusy) } }
                                if !message.selection.isEmpty { Text(message.selection).font(.system(size: 11, design: .monospaced)).lineLimit(4).padding(10).frame(maxWidth: .infinity, alignment: .leading).background(Palette.soft, in: .rect(cornerRadius: 8)) }
                                MarkdownReading(text: message.content, fontSize: 14)
                                if message.isPartial == true { Text("Interrupted response").font(.system(size: 11)).foregroundStyle(.secondary) }
                                if let noteID = message.proposedNoteID, message.isPartial != true {
                                    let applied = store.data.notes.first(where: { $0.id == noteID })?.body == message.content
                                    Button(applied ? "Applied to note" : "Apply to note") { store.applyNoteProposal(message) }.buttonStyle(QuietButton()).disabled(applied)
                                }
                            }.id(message.id)
                        }
                        if running {
                            HStack(spacing: 8) { ThinkingIndicator(); Text(store.tutorStatus).font(.system(size: 11)).foregroundStyle(.secondary) }
                            if !store.tutorStreamingText.isEmpty { MarkdownReading(text: store.tutorStreamingText, fontSize: 14) }
                        }
                        if store.tutorScope == scope, let failure = store.tutorFailure, !running {
                            Text(failure).font(.system(size: 12)).foregroundStyle(.secondary)
                            if let last = conversation.messages.last(where: { $0.role == "user" }) { Button("Retry response") { store.sendTutor(last.content, scope: scope, selection: last.selection, questionHelp: questionHelp, editNote: editNote) }.buttonStyle(QuietButton()) }
                        }
                        Color.clear.frame(height: 1).id("chat-end")
                    }.padding(20)
                }.onChange(of: conversation.messages.count) { proxy.scrollTo("chat-end", anchor: .bottom) }.onChange(of: running) { if !running { proxy.scrollTo("chat-end", anchor: .bottom) } }
            }
            VStack(alignment: .leading, spacing: 10) {
                HStack { if scope.hasPrefix("note:") { WorkspaceTabs(title: "Tutor mode", selection: $editNote, options: [.init(false, "Ask"), .init(true, "Edit note")]) }
                else { Toggle("Help with this question", isOn: $questionHelp).font(.system(size: 11)).toggleStyle(.checkbox) }
                    Spacer(); Button { showHistory = true } label: { Image(systemName: "clock.arrow.circlepath") }.buttonStyle(IconButton()).accessibilityLabel("Conversation branches").help("Previous conversation branches")
                }
                TutorComposer(text: draft, placeholder: editNote ? "Describe the change…" : "Ask a question…", busy: running, context: selection, clearContext: { selection = "" }, cancel: { store.tutorTask?.cancel() }) { store.sendTutor(draft.wrappedValue, scope: scope, selection: selection, questionHelp: questionHelp, editNote: editNote) }.id(scope)
                if store.tutorBusy && !running { Text("Another conversation is responding.").font(.system(size: 11)).foregroundStyle(.secondary) }
            }.padding(14)
        }.sheet(isPresented: $showHistory) {
            VStack(alignment: .leading, spacing: 18) {
                HStack { Text("Conversation branches").font(.system(size: 20, weight: .semibold)); Spacer(); Button("Done") { showHistory = false }.buttonStyle(QuietButton()) }
                let branches = (store.data.conversations ?? []).filter { $0.id.hasPrefix(scope + ":branch:") }.sorted { $0.updatedAt > $1.updatedAt }
                if branches.isEmpty { Text("Editing a previous message keeps the original conversation here.").font(.system(size: 13)).foregroundStyle(.secondary) }
                ScrollView { VStack(alignment: .leading, spacing: 18) { ForEach(branches) { branch in DisclosureGroup(branch.updatedAt.formatted()) { VStack(alignment: .leading, spacing: 14) { ForEach(branch.messages) { message in VStack(alignment: .leading, spacing: 6) { Text(message.role.capitalized).font(.caption).foregroundStyle(.secondary); MarkdownReading(text: message.content, fontSize: 13) } } }.padding(.top, 12) } } } }
            }.padding(26).frame(width: 650, height: 530)
        }.onDisappear { store.save() }
    }
}

struct InspectorDivider: View {
    @Binding var width: Double
    @State private var origin: Double?
    @State private var hovering = false
    var body: some View {
        Color.clear.frame(width: 8).contentShape(.rect)
            .overlay { Capsule().fill(hovering ? Color.primary.opacity(0.25) : .clear).frame(width: 3, height: 32).allowsHitTesting(false) }
            .onHover { hovering = $0; if $0 { NSCursor.resizeLeftRight.push() } else { NSCursor.pop() } }
            .gesture(DragGesture().onChanged { value in if origin == nil { origin = width }; width = min(640, max(300, (origin ?? width) - value.translation.width)) }.onEnded { _ in origin = nil })
            .accessibilityLabel("Tutor panel width").accessibilityValue("\(Int(width)) points")
            .accessibilityAdjustableAction { direction in width = min(640, max(300, width + (direction == .increment ? 40 : -40))) }
    }
}
struct ThinkingIndicator: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 24, paused: reduceMotion)) { timeline in
            let phase = reduceMotion ? 0 : timeline.date.timeIntervalSinceReferenceDate
            ZStack { ForEach(0..<3) { index in Circle().stroke(Palette.accent.opacity(0.35 + Double(index) * 0.15), lineWidth: 1.1).frame(width: 13, height: 17).rotationEffect(.degrees(phase * 38 + Double(index) * 60)) } }.frame(width: 20, height: 20)
        }.accessibilityHidden(true)
    }
}
