import SwiftUI
import AppKit
import Textual
import PlamCore

enum Palette {
    static let accent = Color(nsColor: NSColor(name: nil) { $0.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? NSColor(red: 0.47, green: 0.77, blue: 0.71, alpha: 1) : NSColor(red: 0.14, green: 0.46, blue: 0.42, alpha: 1) })
    static let background = Color(nsColor: NSColor(name: nil) { $0.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? NSColor(red: 0.105, green: 0.11, blue: 0.115, alpha: 1) : NSColor(red: 0.975, green: 0.975, blue: 0.973, alpha: 1) })
    static let canvas = semantic(light: (1, 1, 1), dark: (0.12, 0.125, 0.13))
    static let inputFill = Color.primary.opacity(0.035)
    static let surface = Color(nsColor: .textBackgroundColor)
    static let accentFill = Color(red: 0.14, green: 0.46, blue: 0.42)
    static let onAccent = Color.white
    static let soft = accent.opacity(0.085)
    static let success = semantic(light: (0.13, 0.43, 0.25), dark: (0.48, 0.80, 0.60))
    static let incorrect = semantic(light: (0.69, 0.20, 0.24), dark: (1.0, 0.61, 0.62))
    static let caution = semantic(light: (0.55, 0.34, 0.05), dark: (0.93, 0.74, 0.40))
    private static func semantic(light: (Double, Double, Double), dark: (Double, Double, Double)) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            let value = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? dark : light
            return NSColor(red: value.0, green: value.1, blue: value.2, alpha: 1)
        })
    }
    static func feedback(_ attempt: Attempt) -> Color {
        attempt.disputed || attempt.grade.uncertain ? caution : (attempt.grade.correct ? success : incorrect)
    }
    static let border = Color.primary.opacity(0.12)
    static let hover = Color.primary.opacity(0.075)
    static let pressed = Color.primary.opacity(0.12)
    static let selection = Color.primary.opacity(0.085)
}

struct PrimaryButton: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.isEnabled) private var enabled
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(.system(size: 13, weight: .semibold)).padding(.horizontal, 16).frame(minHeight: 40).contentShape(.rect(cornerRadius: 8))
            .foregroundStyle(Palette.onAccent).background(Palette.accentFill, in: .rect(cornerRadius: 8))
            .opacity(enabled ? 1 : 0.45).scaleEffect(configuration.isPressed && !reduceMotion ? 0.97 : 1)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.14), value: configuration.isPressed)
            .modifier(InteractiveSurface())
    }
}
struct QuietButton: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.isEnabled) private var enabled
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(.system(size: 13, weight: .medium)).padding(.horizontal, 12).frame(minHeight: 36).contentShape(.rect(cornerRadius: 8))
            .background(Palette.inputFill, in: .rect(cornerRadius: 9))
            .opacity(enabled ? 1 : 0.45).scaleEffect(configuration.isPressed && !reduceMotion ? 0.98 : 1)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.14), value: configuration.isPressed)
            .modifier(InteractiveSurface())
    }
}
struct Panel<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View { content.padding(20).frame(maxWidth: .infinity, alignment: .leading).background(Palette.surface, in: .rect(cornerRadius: 12)) }
}
struct Eyebrow: View {
    var title: String
    var body: some View { Text(title).font(.system(size: 12, weight: .medium)).foregroundStyle(.secondary) }
}
struct PageHeading: View {
    var eyebrow: String
    var title: String
    var subtitle: String
    var body: some View { VStack(alignment: .leading, spacing: 8) { if !eyebrow.isEmpty { Eyebrow(title: eyebrow) }; Text(title).font(.system(size: 24, weight: .semibold)); if !subtitle.isEmpty { Text(subtitle).font(.system(size: 14)).foregroundStyle(.secondary).lineSpacing(4) } }.frame(maxWidth: .infinity, alignment: .leading) }
}
struct Chip: View {
    var title: String
    var icon: String? = nil
    var body: some View { HStack(spacing: 5) { if let icon { Image(systemName: icon) }; Text(title) }.font(.system(size: 12)).foregroundStyle(.secondary) }
}
struct EmptyState: View {
    var icon: String
    var title: String
    var subtitle: String
    var actionTitle: String?
    var action: (() -> Void)?
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: icon).font(.system(size: 24, weight: .regular)).foregroundStyle(Palette.accent).frame(width: 40, height: 40)
            Text(title).font(.system(size: 22, weight: .semibold))
            Text(subtitle).foregroundStyle(.secondary).multilineTextAlignment(.center).lineSpacing(5).frame(maxWidth: 380)
            if let actionTitle, let action { Button(actionTitle, action: action).buttonStyle(PrimaryButton()).padding(.top, 6) }
        }.frame(maxWidth: .infinity).padding(.vertical, 64)
    }
}
extension EnvironmentValues { @Entry var studyReadingScale: CGFloat = 1 }

struct MarkdownReading: View {
    @Environment(\.studyReadingScale) private var readingScale
    var text: String
    var fontSize: CGFloat = 15
    var selectable = true
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            ForEach(MarkdownBlocks.parse(text)) { block in
                if block.isDiagram && selectable { MermaidDiagram(source: block.content) }
                else {
                    Group {
                        if selectable { StructuredText(block.content, parser: StudyMarkdownParser()).textual.textSelection(.enabled) }
                        else { StructuredText(block.content, parser: StudyMarkdownParser()).textual.textSelection(.disabled) }
                    }.textual.inlineStyle(.gitHub).textual.headingStyle(ReadingHeadingStyle()).textual.codeBlockStyle(ReadingCodeStyle(interactive: selectable)).font(.system(size: fontSize * readingScale)).frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
}
struct ProgressRing: View {
    var progress: Double
    var size: CGFloat = 48
    var body: some View {
        ZStack {
            Circle().stroke(Palette.accent.opacity(0.12), lineWidth: 4)
            Circle().trim(from: 0, to: min(max(progress, 0), 1)).stroke(Palette.accent, style: StrokeStyle(lineWidth: 4, lineCap: .round)).rotationEffect(.degrees(-90))
            Text("\(Int(progress * 100))").font(.system(size: size / 4, weight: .semibold)).monospacedDigit()
        }.frame(width: size, height: size).accessibilityLabel("\(Int(progress * 100)) percent complete")
    }
}

extension View {
    func fieldStyle() -> some View { self.textFieldStyle(.plain).padding(12).modifier(FieldSurface()) }
}

struct IconButton: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.isEnabled) private var enabled
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.opacity(enabled ? 1 : 0.35).frame(width: 36, height: 36).contentShape(.rect(cornerRadius: 8))
            .background(configuration.isPressed ? Palette.soft : .clear, in: .rect(cornerRadius: 8))
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.95 : 1)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.14), value: configuration.isPressed)
            .modifier(InteractiveSurface())
    }
}

struct ChoiceOption: View {
    var title: String
    var selected: Bool
    var showsCorrectAnswer = false
    var showsWrongAnswer = false
    var isLocked = false
    private var stateColor: Color { showsWrongAnswer ? Palette.incorrect : (showsCorrectAnswer ? Palette.success : Palette.accent) }
    private var stateLabel: String { showsWrongAnswer ? "Your answer, incorrect" : (showsCorrectAnswer ? "Correct answer" : (selected ? "Selected" : "Not selected")) }
    var action: () -> Void
    var body: some View {
        Group {
            if isLocked { optionLabel.accessibilityElement(children: .ignore).accessibilityLabel(title + ". " + stateLabel) }
            else { Button(action: action) { optionLabel }.buttonStyle(OptionButtonStyle()).accessibilityLabel(title).accessibilityValue(stateLabel) }
        }
    }
    private var optionLabel: some View {
        HStack(spacing: 12) {
            Image(systemName: showsWrongAnswer ? "xmark.circle.fill" : (selected || showsCorrectAnswer ? "checkmark.circle.fill" : "circle")).font(.system(size: 18)).foregroundStyle(selected || showsCorrectAnswer ? stateColor : .secondary)
            MarkdownReading(text: title, fontSize: 14, selectable: false)
            Spacer(minLength: 4)
            if showsCorrectAnswer || showsWrongAnswer { Text(showsWrongAnswer ? "Your answer" : "Correct").font(.system(size: 11, weight: .medium)).foregroundStyle(stateColor) }
        }.padding(15).frame(maxWidth: .infinity, minHeight: 48, alignment: .leading)
            .background(selected || showsCorrectAnswer ? stateColor.opacity(0.08) : Palette.surface, in: .rect(cornerRadius: 11))
            .overlay(RoundedRectangle(cornerRadius: 11).stroke(selected || showsCorrectAnswer ? stateColor.opacity(0.6) : Palette.border))
            .contentShape(.rect(cornerRadius: 11))
    }
}

struct InteractiveSurface: ViewModifier {
    @State private var hovered = false
    @Environment(\.isEnabled) private var enabled
    func body(content: Content) -> some View {
        content.contentShape(.rect(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).fill(hovered && enabled ? Palette.hover : .clear).allowsHitTesting(false))
            .onHover { hovered = $0 }
    }
}
struct FieldSurface: ViewModifier {
    @FocusState private var focused: Bool
    func body(content: Content) -> some View {
        content.focused($focused).background(Palette.inputFill, in: .rect(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(focused ? Palette.accent.opacity(0.45) : .clear, lineWidth: 1).allowsHitTesting(false))
    }
}
struct OptionButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var enabled
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.contentShape(.rect(cornerRadius: 8))
            .background(configuration.isPressed ? Palette.pressed : .clear, in: .rect(cornerRadius: 8))
            .opacity(enabled ? 1 : 0.45).modifier(InteractiveSurface())
    }
}
struct TextActionStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.padding(.horizontal, 6).frame(minHeight: 32)
            .contentShape(.rect(cornerRadius: 8))
            .background(configuration.isPressed ? Palette.pressed : .clear, in: .rect(cornerRadius: 8))
            .modifier(InteractiveSurface())
    }
}

struct TutorComposer: View {
    @Binding var text: String
    var placeholder: String
    var busy: Bool
    var context: String = ""
    var clearContext: (() -> Void)? = nil
    var cancel: (() -> Void)? = nil
    var send: () -> Void
    @FocusState private var focused: Bool
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if !context.isEmpty {
                HStack(spacing: 8) {
                    Image(systemName: "text.quote").foregroundStyle(Palette.accent)
                    Text(context).font(.system(size: 11)).lineLimit(2).help(context)
                    Spacer(minLength: 0)
                    if let clearContext { Button(action: clearContext) { Image(systemName: "xmark") }.buttonStyle(IconButton()).accessibilityLabel("Remove attached context") }
                }.padding(.horizontal, 10).padding(.vertical, 4).background(Palette.soft, in: .rect(cornerRadius: 8))
            }
            TextEditor(text: $text).proseNavigation().scrollContentBackground(.hidden).font(.system(size: 14)).focused($focused).accessibilityLabel(placeholder)
                .frame(height: min(120, max(64, CGFloat(text.components(separatedBy: "\n").count) * 20)))
                .overlay(alignment: .topLeading) { if text.isEmpty { Text(placeholder).font(.system(size: 14)).foregroundStyle(.tertiary).padding(.leading, 5).padding(.top, 1).allowsHitTesting(false) } }
            HStack {
                Text(!busy && focused ? "⌘ Return" : "").font(.system(size: 11)).foregroundStyle(.secondary)
                Spacer()
                if busy, let cancel { Button(action: cancel) { Image(systemName: "stop.fill") }.buttonStyle(IconButton()).accessibilityLabel("Stop response") }
                else { Button(action: send) { Image(systemName: "arrow.up").fontWeight(.semibold) }.buttonStyle(IconButton()).background(Palette.soft, in: .rect(cornerRadius: 8)).disabled(busy || text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty).keyboardShortcut(focused ? KeyboardShortcut(.return, modifiers: .command) : nil).accessibilityLabel("Send message") }
            }
        }.padding(14).background(Palette.inputFill, in: .rect(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(focused ? Color.primary.opacity(0.12) : .clear).allowsHitTesting(false))
    }
}

struct ReadingHeadingStyle: StructuredText.HeadingStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.textual.fontScale(configuration.headingLevel == 1 ? 1.5 : (configuration.headingLevel == 2 ? 1.3 : 1.1))
            .fontWeight(.semibold).textual.blockSpacing(.fontScaled(top: 1.3, bottom: 0.6))
    }
}
struct ReadingCodeStyle: StructuredText.CodeBlockStyle {
    var interactive = true
    func makeBody(configuration: Configuration) -> some View {
        VStack(spacing: 0) {
            HStack { Text(configuration.languageHint ?? "Code").font(.system(size: 11)).foregroundStyle(.secondary); Spacer(); if interactive { CopyCodeButton { configuration.codeBlock.copyToPasteboard() } } }.padding(.horizontal, 10)
            Divider()
            Overflow { configuration.label.textual.fontScale(0.9).monospaced().textual.lineSpacing(.fontScaled(0.3)).padding(14) }
        }.background(Palette.surface).clipShape(.rect(cornerRadius: 9))
            .overlay(RoundedRectangle(cornerRadius: 9).stroke(Palette.border)).textual.blockSpacing(.fontScaled(top: 0.7, bottom: 0.4))
    }
}
