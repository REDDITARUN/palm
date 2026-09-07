import XCTest
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
}
