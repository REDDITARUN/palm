import SwiftUI
import PlamCore

struct QuestionRetryView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    var sessionID: UUID
    var question: Question
    @State private var answer = ""
    @State private var order: [String] = []
    @State private var grade: Grade?
    @State private var checking = false
    @State private var task: Task<Void, Never>?
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack { Text("Practice again").font(.system(size: 20, weight: .semibold)); Spacer(); Button("Done") { dismiss() }.buttonStyle(QuietButton()) }
            Text("Your first attempt stays in your learning evidence. This retry is saved as practice with support.").font(.system(size: 12)).foregroundStyle(.secondary)
            ScrollView { VStack(alignment: .leading, spacing: 16) {
                MarkdownReading(text: question.prompt)
                if !question.code.isEmpty { CodeReadingView(code: question.code, language: question.language) { store.selectedExcerpt = $0 }.frame(height: 240) }
                if question.kind == .diagramChoice { ForEach(question.diagrams ?? []) { diagram in VStack { ChoiceOption(title: "Flow " + diagram.id, selected: answer == diagram.id, isLocked: grade != nil) { answer = diagram.id }; MermaidDiagram(source: diagram.mermaid, showsControls: false).allowsHitTesting(false).overlay { Button { answer = diagram.id } label: { Color.clear.contentShape(.rect) }.buttonStyle(.plain).accessibilityLabel("Select flow " + diagram.id).disabled(grade != nil || checking) }; Text(diagram.description).font(.caption) } } }
                else if question.kind.usesOptions { ForEach(question.options, id: \.self) { option in ChoiceOption(title: option, selected: answer == option, isLocked: grade != nil) { answer = option } } }
                else if question.kind == .order {
                    ForEach(order, id: \.self) { item in
                        HStack { MarkdownReading(text: item, fontSize: 14, selectable: false); Spacer()
                            Button { move(item, by: -1) } label: { Image(systemName: "arrow.up") }.buttonStyle(IconButton()).accessibilityLabel("Move " + item + " up").disabled(order.first == item)
                            Button { move(item, by: 1) } label: { Image(systemName: "arrow.down") }.buttonStyle(IconButton()).accessibilityLabel("Move " + item + " down").disabled(order.last == item)
                        }.padding(12).disabled(checking || grade != nil)
                    }
                }
                else { TextEditor(text: $answer).font(.system(size: 14)).frame(minHeight: 130).proseNavigation().accessibilityLabel("Retry answer") }
                if let grade { MarkdownReading(text: grade.feedback) }
            } }
            HStack { Spacer(); Button(checking ? "Checking…" : "Check retry") { check() }.buttonStyle(PrimaryButton()).disabled(checking || answer.isEmpty || grade != nil) }
        }.padding(26).frame(width: 670, height: 610).onAppear { if question.kind == .order { order = question.options.shuffled(); answer = order.joined(separator: " → ") } }.onDisappear { task?.cancel() }
    }
    private func move(_ item: String, by offset: Int) { guard let index = order.firstIndex(of: item), order.indices.contains(index + offset) else { return }; order.swapAt(index, index + offset); answer = order.joined(separator: " → ") }
    private func check() {
        checking = true
        task = Task {
            defer { checking = false }
            do {
                let result: Grade
                if question.kind.needsModelGrading { result = try await store.ai.evaluate(answer: answer, question: question, config: store.modelConfiguration(for: "grading"), feedbackPrompt: TeachingPrompts.resolved(.answerFeedback, preferences: store.data.preferences)) }
                else { result = LearningEngine.grade(answer, for: question) ?? Grade(correct: false, feedback: "This answer needs model evaluation.") }
                try Task.checkCancellation(); grade = result
                store.updateSession(sessionID) { if $0.retryAttempts == nil { $0.retryAttempts = [] }; $0.retryAttempts?.append(Attempt(questionID: question.id, answer: answer, grade: result, hintsUsed: 0, revealed: true)) }
            } catch { if !Task.isCancelled { store.error = error.localizedDescription } }
        }
    }
}
