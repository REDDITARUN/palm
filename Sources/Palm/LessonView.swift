import SwiftUI
import PalmCore
import CodeEditSourceEditor
import CodeEditLanguages
import SwiftTreeSitter
import AppKit

struct LessonView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.scenePhase) private var phase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var sessionID: UUID
    @State private var showInspector = false
    @AppStorage("lessonInspectorWidth") private var inspectorWidth = 360.0
    @State private var inspectorTab = "Tutor"
    private let timer = Timer.publish(every: 15, on: .main, in: .common).autoconnect()
    var session: StudySession? { store.data.sessions.first { $0.id == sessionID } }
    private var pageID: String { guard let session else { return "" }; return session.stage.rawValue + (session.predictionRevealed == true ? "revealed" : "") + (session.stage == .practice ? (session.currentQuestion?.id ?? "") : "") }
    var body: some View {
        if let session {
            VStack(spacing: 0) {
                HStack(spacing: 18) {
                    Button { store.activeSessionID = nil; store.openCourse(session.courseID) } label: { Image(systemName: "arrow.left") }.buttonStyle(IconButton()).help("Save and return to course").accessibilityLabel("Return to course")
                    VStack(alignment: .leading, spacing: 4) { Text(session.content.title).font(.system(size: 13, weight: .semibold)); Text(session.isCheckpoint == true ? "Application checkpoint · feedback at the end" : (session.isReview ? "Spaced review" : "Lesson")).font(.system(size: 10)).foregroundStyle(.secondary) }
                    Spacer()
                    HStack(spacing: 7) { stageChip("Read", active: session.stage == .reading); Image(systemName: "chevron.right"); stageChip("Practice", active: session.stage == .practice); Image(systemName: "chevron.right"); stageChip("Reflect", active: session.stage == .recap || session.stage == .complete) }.font(.system(size: 9)).foregroundStyle(.tertiary)
                    Button { withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.2)) { showInspector.toggle() } } label: { Image(systemName: "sidebar.right") }.buttonStyle(IconButton()).accessibilityLabel("Toggle tutor and sources").help(showInspector ? "Focus on the lesson" : "Show tutor and sources")
                }.padding(.horizontal, 28).padding(.vertical, 16)
                Divider()
                GeometryReader { geometry in
                HStack(spacing: 0) {
                    ScrollViewReader { proxy in
                    ScrollView {
                        VStack(alignment: .leading, spacing: 26) {
                            switch session.stage {
                            case .reading: reading(session)
                            case .practice: if let q = session.currentQuestion { QuestionView(session: session, question: q).id(q.id) }
                            case .recap: recap(session)
                            case .complete: completion(session)
                            }
                        }.frame(maxWidth: 740).padding(32).frame(maxWidth: .infinity)
                    }.onChange(of: session.attempts.count) {
                        guard session.stage == .practice else { return }
                        withAnimation(reduceMotion ? nil : .easeOut(duration: 0.22)) { proxy.scrollTo("answer-feedback", anchor: .top) }
                    }
                    }.id(pageID).transition(.opacity).animation(reduceMotion ? nil : .easeOut(duration: 0.18), value: pageID)
                    if showInspector && geometry.size.width >= 900 { InspectorDivider(width: $inspectorWidth); inspector(session, width: min(inspectorWidth, max(300, geometry.size.width - 440))) }
                }
                .overlay(alignment: .trailing) {
                    if showInspector && geometry.size.width < 900 { inspector(session, width: min(inspectorWidth, geometry.size.width - 30)).shadow(color: .black.opacity(0.12), radius: 16, x: -4).transition(.move(edge: .trailing).combined(with: .opacity)) }
                }
                }
            }
            .onChange(of: pageID) { store.selectedExcerpt = "" }
            .onChange(of: session.stage) { if session.stage == .recap || session.stage == .complete { showInspector = false } }
            .onReceive(timer) { _ in if phase == .active && session.stage != .complete { store.logActivity(sessionID, seconds: 15) } }
        }
    }
    private func inspector(_ session: StudySession, width: Double) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                WorkspaceTabs(title: "Inspector", selection: $inspectorTab, options: [.init("Tutor", "Tutor"), .init("Sources", "Sources")])
                Spacer(minLength: 0)
                Button { showInspector = false } label: { Image(systemName: "xmark") }.buttonStyle(IconButton()).accessibilityLabel("Close inspector")
            }.padding(12)
            if inspectorTab == "Tutor" { TutorView(sessionID: session.id) } else { SourcesView(session: session) }
        }.frame(width: width).frame(maxHeight: .infinity).background(Palette.surface)
    }
    private func stageChip(_ title: String, active: Bool) -> some View { Text(title).font(.system(size: 11, weight: active ? .semibold : .regular)).foregroundStyle(active ? Palette.accent : .secondary).padding(.horizontal, 8).padding(.vertical, 5).background(active ? Palette.soft : .clear, in: .capsule) }
    @ViewBuilder private func reading(_ session: StudySession) -> some View {
        if let prediction = session.content.prediction, session.predictionRevealed != true {
            PageHeading(eyebrow: "Before we explore", title: "What do you think?", subtitle: "Make a prediction. This is ungraded—being unsure is part of learning.")
            MarkdownReading(text: prediction.prompt, fontSize: 17)
            if let code = prediction.code, !code.isEmpty { CodeReadingView(code: code, language: prediction.language) { store.selectedExcerpt = $0 }.frame(height: min(CGFloat(code.components(separatedBy: "\n").count * 22 + 60), 310)) }
            ChoiceGrid(options: prediction.options) { ForEach(prediction.options, id: \.self) { option in
                ChoiceOption(title: option, selected: session.predictionAnswer == option, badge: String(UnicodeScalar(65 + (prediction.options.firstIndex(of: option) ?? 0))!)) { store.updateSession(session.id) { $0.predictionAnswer = option } }
            }
            }
            HStack {
                Button("Not sure yet") { store.updateSession(session.id) { $0.predictionAnswer = "Not sure yet"; $0.predictionRevealed = true } }.buttonStyle(QuietButton())
                Spacer()
                Button("Explore the answer") { store.updateSession(session.id) { $0.predictionRevealed = true } }.buttonStyle(PrimaryButton()).disabled(session.predictionAnswer == nil)
            }
        } else {
            PageHeading(eyebrow: "", title: session.content.title, subtitle: session.content.introduction)
            if let prediction = session.content.prediction {
                Panel { VStack(alignment: .leading, spacing: 12) {
                    Text("What happens—and why").font(.system(size: 14, weight: .semibold))
                    if let answer = session.predictionAnswer { Text("Your prediction: " + answer).font(.system(size: 12)).foregroundStyle(.secondary) }
                    MarkdownReading(text: prediction.explanation)
                } }
            }
            MarkdownReading(text: session.content.material)
            if !session.content.workedExample.isEmpty { Panel { VStack(alignment: .leading, spacing: 16) { Eyebrow(title: "Walk through an example"); MarkdownReading(text: session.content.workedExample) } } }
            HStack { Text("Now try it with less help.").font(.system(size: 12)).foregroundStyle(.secondary); Spacer(); Button { store.updateSession(session.id) { $0.stage = .practice } } label: { Label("Start practice", systemImage: "arrow.right") }.buttonStyle(PrimaryButton()).accessibilityIdentifier("start-practice") }
        }
    }
    private func recap(_ session: StudySession) -> some View {
        Group {
            Button("Back to questions") { store.updateSession(session.id) { $0.stage = .practice } }.buttonStyle(TextActionStyle())
            PageHeading(eyebrow: "", title: "Recall the main idea", subtitle: "What clicked? Put the central idea in your own words. It's fine to leave a question open.")
            TextEditor(text: Binding(get: { self.session?.recall ?? "" }, set: { value in store.updateSession(session.id) { $0.recall = value } })).proseNavigation().font(.system(size: 15)).scrollContentBackground(.hidden).padding(16).frame(height: 150).background(Palette.surface, in: .rect(cornerRadius: 12)).overlay(RoundedRectangle(cornerRadius: 12).stroke(Palette.border)).accessibilityLabel("Your reflection")
            if session.recallRevealed != true { Button("Reveal takeaways") { store.updateSession(session.id) { $0.recallRevealed = true } }.buttonStyle(QuietButton()) }
            if session.recallRevealed == true { Panel { VStack(alignment: .leading, spacing: 14) { Eyebrow(title: "Ideas to take with you"); ForEach(session.content.takeaways, id: \.self) { MarkdownReading(text: $0, fontSize: 14) } } } }
            if session.recallRevealed == true { ForEach(session.attempts.filter { session.isCheckpoint == true || (!$0.grade.correct && !$0.disputed) }) { attempt in
                VStack(alignment: .leading, spacing: 8) { Text(session.isCheckpoint == true ? (session.content.questions.first { $0.id == attempt.questionID }?.prompt ?? "Your reasoning") : (attempt.grade.uncertain || attempt.disputed ? "Needs review" : "Worth another look")).font(.system(size: 12, weight: .semibold)).foregroundStyle(Palette.feedback(attempt)); Text(attempt.grade.feedback).font(.system(size: 13)).foregroundStyle(.secondary).lineSpacing(4); if session.isCheckpoint == true { Button(attempt.disputed ? "Undo dispute" : "This question seems wrong") { store.dispute(sessionID: session.id, questionID: attempt.questionID) }.buttonStyle(TextActionStyle()).font(.system(size: 10)) } }.padding(18).background(Palette.feedback(attempt).opacity(0.08), in: .rect(cornerRadius: 12))
            }
            }
            HStack { Text("Your recap will be saved to Notebook. Your answers and conversation stay with this session.").font(.system(size: 11)).foregroundStyle(.secondary); Spacer(); Button("Finish topic") { store.complete(session.id) }.buttonStyle(PrimaryButton()).accessibilityIdentifier("finish-topic") }
        }
    }
    private func completion(_ session: StudySession) -> some View {
        let course = store.data.courses.first { $0.id == session.courseID }
        return VStack(spacing: 26) {
            Image(systemName: course?.isComplete == true ? "checkmark.seal.fill" : "leaf.fill").font(.system(size: 32, weight: .regular)).foregroundStyle(Palette.accent).padding(.top, 16)
            Eyebrow(title: course?.isComplete == true ? "Course complete" : (session.isReview ? "Review complete" : "Topic complete"))
            Text(session.content.title).font(.system(size: 26, weight: .semibold)).multilineTextAlignment(.center)
            Text("Your notes and progress are saved.").font(.system(size: 14)).foregroundStyle(.secondary).multilineTextAlignment(.center).lineSpacing(7)
            HStack(spacing: 36) { completionMetric("\(session.attempts.count)", "questions explored"); completionMetric("\(session.independentCorrect)", "independent answers"); completionMetric("\(session.attempts.filter { $0.hintsUsed > 0 || $0.revealed }.count)", "with support") }.padding(24).background(Palette.surface, in: .rect(cornerRadius: 16))

            HStack(spacing: 12) {
                Button("Open notes") { store.selectedNoteID = store.data.notes.first { $0.sessionID == session.id }?.id; store.navigate(.notebook) }.buttonStyle(QuietButton())
                if let course, let next = course.lessons.first(where: { !course.completedLessonIDs.contains($0.id) }) { Button("Next topic") { store.startLesson(course: course, lesson: next) }.buttonStyle(PrimaryButton()).disabled(store.busy != nil) }
                else { Button("Back to course") { store.openCourse(session.courseID) }.buttonStyle(PrimaryButton()) }
            }
        }.frame(maxWidth: .infinity)
    }
    private func completionMetric(_ value: String, _ label: String) -> some View { VStack(spacing: 6) { Text(value).font(.system(size: 26, weight: .semibold)); Text(label).font(.system(size: 10)).foregroundStyle(.secondary) } }
}

struct QuestionView: View {
    @Environment(AppStore.self) private var store
    var session: StudySession
    var question: Question
    @State private var order: [String] = []
    @State private var retry = false
    @FocusState private var answerFocused: Bool
    @FocusState private var questionFocused: Bool
    var attempt: Attempt? { session.attempts.first { $0.questionID == question.id } }
    private var feedbackColor: Color {
        guard let attempt else { return Palette.accent }
        return Palette.feedback(attempt)
    }
    private var feedbackIcon: String {
        guard let attempt else { return "lightbulb" }
        return attempt.disputed || attempt.grade.uncertain ? "questionmark.circle" : (attempt.grade.correct ? "checkmark.circle" : "xmark.circle")
    }
    var draft: Binding<String> { Binding(get: { store.data.sessions.first { $0.id == session.id }?.drafts[question.id] ?? "" }, set: { value in store.updateSession(session.id) { $0.drafts[question.id] = value } }) }
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack { Eyebrow(title: "Question \(session.questionIndex + 1) of \(session.content.questions.count)"); Spacer(); Button { store.previousQuestion(session.id) } label: { Image(systemName: "chevron.left") }.buttonStyle(IconButton()).accessibilityLabel("Previous question").disabled(session.questionIndex == 0 || store.isEvaluating) }
            ProgressView(value: Double(session.questionIndex), total: Double(session.content.questions.count)).tint(Palette.accent)
            MarkdownReading(text: LearningEngine.removingRepeatedCode(from: question.prompt, code: question.code), fontSize: 17)
            if !question.code.isEmpty { CodeReadingView(code: question.code, language: question.language) { store.selectedExcerpt = $0 }.frame(height: min(CGFloat(question.code.components(separatedBy: "\n").count * 22 + 60), 310)) }
            if question.kind == .diagramChoice {
                ForEach(question.diagrams ?? []) { diagram in
                    VStack(alignment: .leading, spacing: 8) {
                        ChoiceOption(title: "Flow " + diagram.id, selected: draft.wrappedValue == diagram.id, showsCorrectAnswer: attempt != nil && session.isCheckpoint != true && attempt?.disputed != true && diagram.id == question.answer, showsWrongAnswer: attempt != nil && session.isCheckpoint != true && attempt?.disputed != true && draft.wrappedValue == diagram.id && diagram.id != question.answer, isLocked: attempt != nil) { draft.wrappedValue = diagram.id }
                        MermaidDiagram(source: diagram.mermaid, showsControls: false).allowsHitTesting(false).overlay { Button { if attempt == nil { draft.wrappedValue = diagram.id } } label: { Color.clear.contentShape(.rect) }.buttonStyle(.plain).accessibilityLabel("Select flow " + diagram.id + ": " + diagram.description).disabled(attempt != nil || store.busy != nil) }
                        Text(diagram.description).font(.system(size: 12)).foregroundStyle(.secondary)
                    }.padding(12).background(draft.wrappedValue == diagram.id ? Palette.soft : .clear, in: .rect(cornerRadius: 12))
                }
            } else if question.kind.usesOptions {
                ChoiceGrid(options: question.options) {
                    ForEach(question.options, id: \.self) { option in
                        ChoiceOption(title: option, selected: draft.wrappedValue == option, badge: String(UnicodeScalar(65 + (question.options.firstIndex(of: option) ?? 0))!), showsCorrectAnswer: attempt != nil && session.isCheckpoint != true && attempt?.disputed != true && attempt?.grade.uncertain != true && option == question.answer, showsWrongAnswer: attempt != nil && session.isCheckpoint != true && draft.wrappedValue == option && option != question.answer && attempt?.disputed != true && attempt?.grade.uncertain != true, isLocked: attempt != nil) { draft.wrappedValue = option }
                            .disabled(store.busy != nil && attempt == nil).accessibilityIdentifier("option-" + option)
                    }
                }
            } else if question.kind == .order {
                VStack(spacing: 10) { ForEach(order, id: \.self) { item in HStack { MarkdownReading(text: item, fontSize: 14, selectable: false); Spacer(); Button { move(item, by: -1) } label: { Image(systemName: "arrow.up") }.buttonStyle(IconButton()).accessibilityLabel("Move " + item + " up").disabled(order.first == item); Button { move(item, by: 1) } label: { Image(systemName: "arrow.down") }.buttonStyle(IconButton()).accessibilityLabel("Move " + item + " down").disabled(order.last == item) }.padding(14).background(Palette.surface, in: .rect(cornerRadius: 9)).disabled(attempt != nil || store.busy != nil) } }
            } else {
                VStack(alignment: .leading, spacing: 9) {
                    Text(question.kind.isLongAnswer ? "Your reasoning" : "Your answer").font(.system(size: 12, weight: .medium))
                    if let attempt {
                        Text(attempt.answer).font(.system(size: 14)).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading).padding(12).background(Palette.surface, in: .rect(cornerRadius: 8))
                    } else {
                        TextEditor(text: draft).proseNavigation().scrollContentBackground(.hidden).font(.system(size: 14)).frame(height: question.kind.isLongAnswer ? 96 : 48).accessibilityLabel(question.kind.isLongAnswer ? "Your reasoning" : "Your answer").fieldStyle().focused($answerFocused).disabled(store.busy != nil).accessibilityIdentifier("question-answer")
                        Text("Equivalent wording is accepted").font(.system(size: 12)).foregroundStyle(.secondary)
                    }
                }
            }
            if session.hints[question.id, default: 0] > 0 {
                ForEach(Array(question.hints.prefix(session.hints[question.id, default: 0])), id: \.self) { hint in HStack(alignment: .top) { Image(systemName: "lightbulb").foregroundStyle(Palette.accent); MarkdownReading(text: hint, fontSize: 14) }.padding(15).frame(maxWidth: .infinity, alignment: .leading).background(Palette.soft, in: .rect(cornerRadius: 10)) }
            }
            if session.revealedIDs.contains(question.id) && attempt == nil { Panel { VStack(alignment: .leading, spacing: 10) { Eyebrow(title: "Worked answer · assisted"); MarkdownReading(text: question.answer + "\n\n" + question.explanation) } } }
            if let attempt {
                if session.isCheckpoint == true { Text("Response saved. Review your reasoning after the last question.").font(.system(size: 12)).foregroundStyle(.secondary).id("answer-feedback") } else {
                VStack(alignment: .leading, spacing: 13) {
                    Label(attempt.disputed ? "Set aside for review" : (attempt.grade.uncertain ? "This needs a closer look" : (attempt.grade.correct ? "That follows." : "Let's untangle this.")), systemImage: feedbackIcon).font(.system(size: 16, weight: .semibold)).foregroundStyle(feedbackColor)
                    MarkdownReading(text: attempt.grade.feedback)
                    HStack { Button("Try again") { retry = true }.buttonStyle(TextActionStyle()).font(.system(size: 11)); Button(attempt.disputed ? "Undo dispute" : "This question seems wrong") { store.dispute(sessionID: session.id, questionID: question.id) }.buttonStyle(TextActionStyle()).font(.system(size: 10)).foregroundStyle(.secondary); Spacer(); if !attempt.independent { Chip(title: attempt.disputed ? "Excluded from progress" : (attempt.grade.uncertain ? "Needs review" : "Practice with support")) } }
                }.padding(22).background(feedbackColor.opacity(0.08), in: .rect(cornerRadius: 14)).overlay(RoundedRectangle(cornerRadius: 14).stroke(feedbackColor.opacity(0.25))).id("answer-feedback")
                }
                HStack { Button("Previous question") { store.previousQuestion(session.id) }.buttonStyle(QuietButton()).disabled(session.questionIndex == 0); Spacer(); Button(session.questionIndex + 1 == session.content.questions.count ? "Reflect on this topic" : "Next question") { store.nextQuestion(session.id) }.buttonStyle(PrimaryButton()).accessibilityIdentifier("next-question") }
            } else {
                HStack {
                    if store.isEvaluating {
                        Button("Cancel check") { store.cancelWork() }.buttonStyle(TextActionStyle()).font(.system(size: 12)).foregroundStyle(.secondary)
                    } else {
                    ActionPopover(title: "Help", icon: "questionmark.circle", textLabel: true, actions: [
                        WorkspaceAction(title: "Give me a hint", icon: "lightbulb", disabled: session.hints[question.id, default: 0] >= question.hints.count) { store.updateSession(session.id) { $0.hints[question.id, default: 0] = min($0.hints[question.id, default: 0] + 1, question.hints.count) } },
                        WorkspaceAction(title: "Show the explanation", icon: "text.alignleft") { store.updateSession(session.id) { if !$0.revealedIDs.contains(question.id) { $0.revealedIDs.append(question.id) } } }
                    ])
                    }
                    Spacer()
                    if session.revealedIDs.contains(question.id) { Button("Continue with support") { store.record(Grade(correct: false, feedback: question.explanation), answer: "Answer revealed", question: question, sessionID: session.id) }.buttonStyle(QuietButton()) }
                    Button(store.busy != nil ? "Checking…" : (session.isCheckpoint == true ? "Save answer" : "Check answer")) { store.submit(session) }.buttonStyle(PrimaryButton()).disabled(draft.wrappedValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || store.busy != nil).keyboardShortcut(answerFocused || questionFocused ? KeyboardShortcut(.return, modifiers: .command) : nil).accessibilityIdentifier("check-answer")
                }
            }
        }.sheet(isPresented: $retry) { QuestionRetryView(sessionID: session.id, question: question) }
        .focusable().focused($questionFocused).defaultFocus($questionFocused, question.kind.usesOptions).focusEffectDisabled()
        .task(id: attempt?.id) {
            guard attempt != nil else { return }
            await Task.yield()
            // The answer editor has left the hierarchy. Restore continuation
            // focus unless the learner is currently writing in the tutor.
            if !KeyboardContext.isEditing { questionFocused = true }
        }
        .task(id: question.id) { await Task.yield(); if question.kind.usesOptions || question.kind == .order { questionFocused = true } else { answerFocused = true } }
        .onKeyPress(characters: CharacterSet(charactersIn: "123456789"), phases: .down) { press in
            guard !KeyboardContext.isEditing, attempt == nil, store.busy == nil, question.kind.usesOptions,
                  let number = Int(press.characters), question.options.indices.contains(number - 1) else { return .ignored }
            draft.wrappedValue = question.options[number - 1]; return .handled
        }
        .onKeyPress(.return, phases: .down) { _ in
            guard !KeyboardContext.isEditing, attempt != nil else { return .ignored }
            store.nextQuestion(session.id); return .handled
        }
        .onAppear { if question.kind == .order { order = draft.wrappedValue.isEmpty ? question.options.shuffled() : draft.wrappedValue.components(separatedBy: " → "); draft.wrappedValue = order.joined(separator: " → ") } }
    }
    private func move(_ item: String, by offset: Int) { guard let i = order.firstIndex(of: item), order.indices.contains(i + offset) else { return }; order.swapAt(i, i + offset); draft.wrappedValue = order.joined(separator: " → ") }
}

struct CodeReadingView: View {
    @Environment(\.colorScheme) private var colorScheme
    var code: String
    var language: String? = nil
    var onSelection: (String) -> Void
    @State private var state = SourceEditorState()
    @State private var syntaxChoices: [SyntaxChoice] = []
    @State private var hovered = false
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Text("Select code to ask").font(.system(size: 11)).foregroundStyle(Palette.studyMuted).opacity(hovered ? 1 : 0)
                Spacer()
                if !syntaxChoices.isEmpty { ActionPopover(title: "Code structure", icon: "scope", textLabel: true, actions: syntaxChoices.map { item in WorkspaceAction(title: item.title, icon: "curlybraces") { onSelection(item.text) } }) }
                Text(language ?? "Code").font(.system(size: 11, design: .monospaced)).foregroundStyle(Palette.studyMuted)
                CopyCodeButton { NSPasteboard.general.clearContents(); NSPasteboard.general.setString(code, forType: .string) }
            }.padding(.horizontal, 16).padding(.top, 4)
            SourceEditor(.constant(code), language: CodeLanguage.allLanguages.first { $0.id.rawValue.lowercased() == language?.lowercased() } ?? .default, configuration: .init(appearance: .init(theme: Self.theme(dark: colorScheme == .dark), font: .monospacedSystemFont(ofSize: 14, weight: .regular), wrapLines: false), behavior: .init(isEditable: false), peripherals: .init(showGutter: false, showMinimap: false)), state: $state)
                .onChange(of: state.cursorPositions) {
                    if let range = state.cursorPositions?.first?.range, NSMaxRange(range) <= (code as NSString).length {
                        if range.length > 0 { onSelection((code as NSString).substring(with: range)) }
                        syntaxChoices = SyntaxSelection.ancestors(code: code, language: language, range: range)
                    }
                }
                .padding(.horizontal, 22).padding(.bottom, 18)
        }.background(Palette.studyFill).clipShape(.rect(cornerRadius: 14)).onHover { hovered = $0 }
    }
    static func theme(dark: Bool) -> EditorTheme {
        // CodeEdit's minimap reads brightnessComponent, which dynamic/catalog NSColors do not expose.
        func rgb(_ color: NSColor) -> NSColor { color.usingColorSpace(.deviceRGB) ?? NSColor(deviceRed: 0.5, green: 0.5, blue: 0.5, alpha: 1) }
        let text = dark ? NSColor(deviceRed: 0.86, green: 0.91, blue: 0.83, alpha: 1) : NSColor(deviceRed: 0.25, green: 0.34, blue: 0.22, alpha: 1)
        let background = dark ? NSColor(deviceRed: 0.16, green: 0.20, blue: 0.17, alpha: 1) : NSColor(deviceRed: 0.941, green: 0.953, blue: 0.910, alpha: 1)
        let blue = dark ? NSColor(deviceRed: 0.61, green: 0.72, blue: 0.95, alpha: 1) : NSColor(deviceRed: 0.29, green: 0.39, blue: 0.67, alpha: 1)
        let orange = dark ? NSColor(deviceRed: 0.94, green: 0.68, blue: 0.43, alpha: 1) : NSColor(deviceRed: 0.70, green: 0.34, blue: 0.15, alpha: 1)
        let comment = dark ? NSColor(deviceRed: 0.61, green: 0.71, blue: 0.58, alpha: 1) : NSColor(deviceRed: 0.43, green: 0.50, blue: 0.38, alpha: 1)
        return .init(text: .init(color: text), insertionPoint: rgb(.controlAccentColor), invisibles: .init(color: rgb(.tertiaryLabelColor)), background: background, lineHighlight: rgb(.clear), selection: rgb(.selectedTextBackgroundColor), keywords: .init(color: blue), commands: .init(color: blue), types: .init(color: blue), attributes: .init(color: blue), variables: .init(color: text), values: .init(color: blue), numbers: .init(color: orange), strings: .init(color: text), characters: .init(color: text), comments: .init(color: comment))
    }
}

struct TutorView: View {
    @Environment(AppStore.self) private var store
    var sessionID: UUID
    var body: some View { WorkspaceTutor(scope: "session:" + sessionID.uuidString, selection: Binding(get: { store.selectedExcerpt }, set: { store.selectedExcerpt = $0 })) }
}

struct SourcesView: View {
    @Environment(AppStore.self) private var store
    var session: StudySession
    @State private var selected: LearningSource?
    var body: some View {
        ScrollView { VStack(alignment: .leading, spacing: 18) {
            Text("The evidence behind this lesson.").font(.system(size: 12)).foregroundStyle(.secondary)
            if session.content.sources.isEmpty { Text("No external sources were supplied. Treat this lesson as model-generated material and check uncertain claims.").font(.system(size: 12)).foregroundStyle(.secondary) }
            ForEach(session.content.sources) { source in
                Button { selected = source } label: { VStack(alignment: .leading, spacing: 8) { Label(source.title, systemImage: source.location.hasPrefix("https:") ? "link" : "doc.text").font(.system(size: 12, weight: .medium)); Text(source.location).font(.system(size: 10, design: .monospaced)).foregroundStyle(.secondary).lineLimit(3); Text(source.excerpt).font(.system(size: 11)).foregroundStyle(.secondary).lineLimit(5) }.padding(14).frame(maxWidth: .infinity, alignment: .leading).background(Palette.surface, in: .rect(cornerRadius: 10)) }.buttonStyle(TextActionStyle())
            }
        }.padding(18) }
        .sheet(item: $selected) { source in SourceDetailView(source: source, session: session).environment(store) }
    }
}

struct SourceDetailView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    var source: LearningSource
    var session: StudySession
    @State private var code = ""
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack { Text(source.title).font(.title2); Spacer(); Button("Done") { dismiss() } }
            Text(source.location).font(.system(size: 12, design: .monospaced)).foregroundStyle(.secondary)
            if source.location.hasPrefix("https://"), let url = URL(string: source.location) { MarkdownReading(text: source.excerpt); Link("Open documentation ↗", destination: url) }
            else { CodeReadingView(code: code.isEmpty ? source.excerpt : code) { store.selectedExcerpt = $0 }.frame(minHeight: 330) }
            Button("Ask about selection") { if store.selectedExcerpt.isEmpty { store.selectedExcerpt = source.excerpt }; dismiss() }.buttonStyle(PrimaryButton())
        }.padding(26).frame(width: 740, height: 530)
        .task {
            guard let course = store.data.courses.first(where: { $0.id == session.courseID }), let repo = store.data.repositories.first(where: { $0.id == course.repositoryID }) else { return }
            // Read immutable snapshot only; disallow traversal outside it.
            guard let snapshotPath = session.snapshotPath ?? (session.snapshotID == repo.snapshotID ? repo.snapshotPath : nil) else { return }
            let root = URL(fileURLWithPath: snapshotPath).resolvingSymlinksInPath().standardizedFileURL
            let url = root.appendingPathComponent(source.location).standardizedFileURL
            guard url.path.hasPrefix(root.path + "/") else { return }
            code = (try? String(contentsOf: url, encoding: .utf8)) ?? source.excerpt
        }
    }
}
