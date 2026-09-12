import XCTest
@testable import Palm
import PalmCore

@MainActor final class SourceLinkTests: XCTestCase {
    func testFileLineAndDirectoryLinksStayInsideSourceContext() throws {
        let markdown = "Read `src/main.py:12` and `src/util/`.\n\n```python\npath = 'src/main.py'\n```"
        let linked = try StudyMarkdownParser(linkSources: true).attributedString(for: markdown)
        let references = linked.runs.compactMap { $0.link }.filter { $0.scheme == "palm-source" }.compactMap { try? SourceReference(link: $0) }
        XCTAssertTrue(references.contains { $0.path == "src/main.py" && $0.line == 12 })
        XCTAssertTrue(references.contains { $0.path == "src/util/" })
        XCTAssertEqual(references.count, 2, "Do not turn literal source code inside fences into links")
        let plain = try StudyMarkdownParser().attributedString(for: markdown)
        XCTAssertFalse(plain.runs.contains { $0.link?.scheme == "palm-source" })
    }
}
