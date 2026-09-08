import Foundation
import AppKit
import CodeEditLanguages
import CodeEditSourceEditor
import SwiftTreeSitter

struct SyntaxChoice: Identifiable {
    var title: String
    var text: String
    var range: NSRange
    var id: String { "\(range.location):\(range.length)" }
    var detail: String {
        let lines = text.components(separatedBy: "\n").count
        return lines == 1 ? String(text.prefix(65)) : "\(lines) lines · " + String(text.split(separator: "\n").first ?? "").trimmingCharacters(in: .whitespaces)
    }
}
enum SyntaxSelection {
    static func language(for hint: String?) -> CodeLanguage? {
        guard let raw = hint?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(), !raw.isEmpty else { return nil }
        let aliases = ["py": "python", "python3": "python", "js": "javascript", "ts": "typescript", "c++": "cpp", "c#": "csharp", "c_sharp": "csharp", "sh": "bash"]
        let name = aliases[raw] ?? raw
        return CodeLanguage.allLanguages.first { $0.id.rawValue.lowercased() == name || $0.extensions.contains(raw.trimmingCharacters(in: CharacterSet(charactersIn: "."))) }
    }
    static func valid(_ range: NSRange, in code: String) -> Bool {
        let count = code.utf16.count
        return range.location != NSNotFound && range.location >= 0 && range.length >= 0 && range.location <= count && range.length <= count - range.location
    }
    static func ancestors(code: String, language hint: String?, range: NSRange) -> [SyntaxChoice] {
        guard code.utf16.count < 100_000, !code.isEmpty, valid(range, in: code), let language = language(for: hint)?.language else { return [] }
        let parser = Parser()
        do { try parser.setLanguage(language) } catch { return [] }
        // SwiftTreeSitter parses UTF-16LE; its NSRange bridge converts to byte offsets.
        guard let tree = parser.parse(code), let root = tree.rootNode else { return [] }
        // An insertion point at EOF should still offer the last expression and its parents.
        let query = range.length == 0 && range.location == code.utf16.count ? NSRange(location: range.location - 1, length: 0) : range
        var node = root.descendant(in: query.byteRange)
        var result: [SyntaxChoice] = []
        var previous = NSRange(location: NSNotFound, length: 0)
        while let current = node, result.count < 12 {
            let span = current.range
            if current.isNamed, span.length > 0, span != previous, valid(span, in: code) {
                let title = (current.nodeType ?? "expression").replacingOccurrences(of: "_", with: " ").capitalized
                result.append(.init(title: title, text: (code as NSString).substring(with: span), range: span))
                previous = span
            }
            node = current.parent
        }
        return result
    }
}

/// Uses the editor's public coordinator API because the pinned SourceEditor state
/// bridge compares cursorPositions with itself and never applies requested ranges.
final class SyntaxSelectionController: NSObject, TextViewCoordinator {
    weak var controller: TextViewController?
    private var clickRecognizer: NSClickGestureRecognizer?
    func prepareCoordinator(controller: TextViewController) {
        destroy()
        self.controller = controller
        // CodeEditTextView skips single-click positioning when isEditable is false.
        // A non-delaying click recognizer restores it without enabling code editing
        // or intercepting dragging, scrolling, and the editor's word selection.
        let click = NSClickGestureRecognizer(target: self, action: #selector(positionCursor(_:)))
        click.delaysPrimaryMouseButtonEvents = false
        controller.textView.addGestureRecognizer(click)
        clickRecognizer = click
    }
    func destroy() {
        if let clickRecognizer { controller?.textView.removeGestureRecognizer(clickRecognizer) }
        clickRecognizer = nil
        controller = nil
    }
    @objc private func positionCursor(_ gesture: NSClickGestureRecognizer) {
        guard let controller, !controller.textView.isEditable,
              (NSApp.currentEvent?.clickCount ?? 1) == 1,
              let offset = controller.textView.layoutManager.textOffsetAtPoint(gesture.location(in: controller.textView)) else { return }
        controller.setCursorPositions([CursorPosition(range: NSRange(location: offset, length: 0))], scrollToVisible: false)
        controller.textView.window?.makeFirstResponder(controller.textView)
    }
    @MainActor @discardableResult
    func select(_ choice: SyntaxChoice, in code: String) -> Bool {
        guard let controller, controller.textView.string == code,
              SyntaxSelection.valid(choice.range, in: code),
              (code as NSString).substring(with: choice.range) == choice.text else { return false }
        controller.setCursorPositions([CursorPosition(range: choice.range)], scrollToVisible: true)
        controller.textView.window?.makeFirstResponder(controller.textView)
        return true
    }
}
