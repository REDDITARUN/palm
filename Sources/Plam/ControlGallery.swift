import SwiftUI

/// Available only from the isolated test app's Learn menu.
struct ControlGallery: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selected = false
    @State private var value = "Default"
    @State private var input = ""
    @State private var count = 0
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                HStack { Text("Control gallery").font(.title2); Spacer(); Button("Done") { dismiss() }.buttonStyle(QuietButton()).keyboardShortcut(.cancelAction) }
                Text("Use Tab, Space, and the pointer to check each control. Activations: \(count)").font(.system(size: 13)).foregroundStyle(.secondary)
                HStack {
                    Button("Primary") { count += 1 }.buttonStyle(PrimaryButton())
                    Button("Secondary") { count += 1 }.buttonStyle(QuietButton())
                    Button("Text action") { count += 1 }.buttonStyle(TextActionStyle())
                    Button { count += 1 } label: { Image(systemName: "plus") }.buttonStyle(IconButton()).accessibilityLabel("Add")
                }
                HStack {
                    Button("Disabled primary") {}.buttonStyle(PrimaryButton()).disabled(true)
                    Button("Disabled secondary") {}.buttonStyle(QuietButton()).disabled(true)
                    Button {} label: { Image(systemName: "plus") }.buttonStyle(IconButton()).disabled(true).accessibilityLabel("Disabled add")
                }
                Button { selected.toggle() } label: { HStack { Text("Full-width selectable row"); Spacer(); if selected { Image(systemName: "checkmark") } }.padding(14).frame(maxWidth: .infinity).background(selected ? Palette.selection : .clear, in: .rect(cornerRadius: 8)).contentShape(.rect(cornerRadius: 8)) }.buttonStyle(OptionButtonStyle())
                WorkspaceSelect(title: "Selector", selection: $value, options: ["Default", "Large", "Larger"].map { .init($0, $0) }, searchable: true)
                WorkspaceTabs(title: "Tabs", selection: $selected, options: [.init(false, "Note"), .init(true, "Flashcards")])
                TextField("Focus this field", text: $input).fieldStyle()
                ChoiceOption(title: "A choice with `inline code`", selected: selected) { selected.toggle() }
                ChoiceOption(title: "Incorrect answer", selected: true, showsWrongAnswer: true, isLocked: true) {}
                ChoiceOption(title: "Correct answer", selected: false, showsCorrectAnswer: true, isLocked: true) {}
                ActionPopover(title: "Actions", textLabel: true, actions: [WorkspaceAction(title: "Available") { count += 1 }, WorkspaceAction(title: "Unavailable", disabled: true) {}, WorkspaceAction(title: "Destructive example", destructive: true) { count += 1 }])
                TutorComposer(text: $input, placeholder: "Write a question…", busy: false) { count += 1 }
            }.padding(28)
        }.frame(width: 720, height: 650)
    }
}
