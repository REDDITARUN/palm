import XCTest
import AppKit
import CodeEditSourceEditor
@testable import Palm

final class SyntaxSelectionTests: XCTestCase {
    func testSyntaxSelectionPreservesUnicodeOffsetsAndOffersParents() {
        let code = "const emoji = '🙂';\nconst café = 3;\nconsole.log(café);"
        let range = (code as NSString).range(of: "café")
        let choices = SyntaxSelection.ancestors(code: code, language: "javascript", range: range)
        XCTAssertEqual(choices.first?.text, "café")
        XCTAssertTrue(choices.contains { $0.text == "const café = 3;" })
        XCTAssertTrue(choices.contains { $0.text == code })
    }
    func testUnknownLanguageKeepsOrdinarySelectionAvailable() {
        XCTAssertTrue(SyntaxSelection.ancestors(code: "abc", language: "unknown", range: NSRange(location: 1, length: 1)).isEmpty)
    }
    func testPythonSelectionOffersCallAndEnclosingFlow() {
        let code = "for n in nums:\n    if n % 2 == 0:\n        filtered.append(n)"
        let choices = SyntaxSelection.ancestors(code: code, language: "py", range: (code as NSString).range(of: "append"))
        XCTAssertEqual(choices.first?.text, "append")
        XCTAssertTrue(choices.contains { $0.title == "Call" && $0.text == "filtered.append(n)" })
        XCTAssertTrue(choices.contains { $0.title == "If Statement" })
        XCTAssertTrue(choices.contains { $0.text == code })
    }
    func testAliasesAndInvalidRanges() {
        XCTAssertEqual(SyntaxSelection.language(for: " Python3 ")?.id, SyntaxSelection.language(for: "python")?.id)
        XCTAssertEqual(SyntaxSelection.language(for: ".js")?.id, SyntaxSelection.language(for: "javascript")?.id)
        XCTAssertNotNil(SyntaxSelection.language(for: "c#"))
        for range in [NSRange(location: NSNotFound, length: 0), NSRange(location: -1, length: 0), NSRange(location: 0, length: Int.max), NSRange(location: 4, length: 0)] {
            XCTAssertTrue(SyntaxSelection.ancestors(code: "abc", language: "python", range: range).isEmpty)
        }
        XCTAssertFalse(SyntaxSelection.ancestors(code: "value", language: "python", range: NSRange(location: 5, length: 0)).isEmpty)
    }
    @MainActor func testSyntaxActionChangesNativeSelectionAndRejectsStaleCode() {
        _ = NSApplication.shared
        let code = "filtered.append(n)"
        let bridge = SyntaxSelectionController()
        let controller = TextViewController(string: code, language: SyntaxSelection.language(for: "python")!, configuration: .init(appearance: .init(theme: CodeReadingView.theme(dark: false), font: .monospacedSystemFont(ofSize: 14, weight: .regular), wrapLines: false)), cursorPositions: [.init(range: NSRange(location: 0, length: 0))], coordinators: [bridge])
        _ = controller.view
        let choice = SyntaxChoice(title: "Call", text: code, range: NSRange(location: 0, length: code.utf16.count))
        XCTAssertTrue(bridge.select(choice, in: code))
        XCTAssertEqual(controller.textView.selectionManager.textSelections.map(\.range), [choice.range])
        XCTAssertFalse(bridge.select(choice, in: "different question"))
        bridge.destroy()
        XCTAssertFalse(bridge.select(choice, in: code))
    }

}
