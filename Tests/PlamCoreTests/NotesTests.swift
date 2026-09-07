import XCTest
@testable import PlamCore

final class NotesTests: XCTestCase {
    func testOldPreferencesLoadWithTeachingDefaultsAndCustomPromptsRoundTrip() throws {
        let old = #"{"name":"Test","dailyMinutes":15,"model":"example","endpoint":"https://example.com","appearance":"system","onboardingComplete":true,"context7Key":""}"#
        var preferences = try JSONDecoder().decode(Preferences.self, from: Data(old.utf8))
        XCTAssertEqual(TeachingPrompts.resolved(.beforeLesson, preferences: preferences), TeachingPromptKind.beforeLesson.defaultText)
        preferences.teachingPrompts = ["beforeLesson": "Use small Python examples", "afterLesson": "  "]
        let restored = try JSONDecoder().decode(Preferences.self, from: JSONEncoder().encode(preferences))
        XCTAssertEqual(TeachingPrompts.resolved(.beforeLesson, preferences: restored), "Use small Python examples")
        XCTAssertEqual(TeachingPrompts.resolved(.afterLesson, preferences: restored), TeachingPromptKind.afterLesson.defaultText)
    }
    func testDiagramFencesDoNotInterpretExamplesInsideCode() {
        let source = "Intro\n\n````markdown\n```mermaid\nA-->B\n```\n````\n\n```mermaid\nflowchart LR\nA-->B\n```\nAfter"
        let blocks = MarkdownBlocks.parse(source)
        XCTAssertEqual(blocks.count, 3)
        XCTAssertTrue(blocks[0].content.contains("````markdown"))
        XCTAssertFalse(blocks[0].isDiagram)
        XCTAssertEqual(blocks[1].content, "flowchart LR\nA-->B")
        XCTAssertTrue(blocks[1].isDiagram)
        XCTAssertEqual(blocks[2].content, "After")
    }
    func testUnclosedAndIndentedFencesStayReadableAndTildeDiagramsWork() {
        XCTAssertFalse(MarkdownBlocks.parse("```mermaid\nflowchart LR\nA-->B").contains(where: \.isDiagram))
        XCTAssertFalse(MarkdownBlocks.parse("    ```mermaid\n    A-->B\n    ```").contains(where: \.isDiagram))
        XCTAssertTrue(MarkdownBlocks.parse("~~~mermaid\nflowchart TD\nA-->B\n~~~")[0].isDiagram)
    }
    func testMathPreservesLatexAndLeavesCodeLiteral() {
        let source = #"""
        A formula:
        $$
        \frac{x_1}{2} + \begin{matrix}a \\ b\end{matrix}
        $$
        `$price$`
        ```text
        $$not math$$
        ```
        """#
        let prepared = MathMarkdown.prepare(source)
        XCTAssertEqual(prepared.formulas.count, 1)
        XCTAssertTrue(prepared.text.contains("`$price$`"))
        XCTAssertTrue(prepared.text.contains("$$not math$$"))
        XCTAssertFalse(prepared.formulas[0].markdown.contains("\n"))
        XCTAssertTrue(prepared.formulas[0].markdown.contains(#"\\frac"#))
        XCTAssertTrue(prepared.formulas[0].markdown.contains(#"x\_1"#))
    }
    func testFallbackRecapDoesNotLabelUncertainAnswersAsMistakes() {
        let question = Question(id: "q", kind: .explain, skill: "explain", prompt: "Why?", code: "", options: [], answer: "Reasoning", acceptedAnswers: [], explanation: "", hints: [], sourceIDs: [])
        let content = LessonContent(title: "Scope", introduction: "", material: "", workedExample: "Example", takeaways: [], questions: [question], sources: [])
        var session = StudySession(courseID: UUID(), lessonID: "scope", content: content, snapshotID: nil)
        session.attempts = [Attempt(questionID: "q", answer: "It depends", grade: Grade(correct: false, feedback: "Missing context", uncertain: true), hintsUsed: 0, revealed: false)]
        XCTAssertFalse(LearningEngine.recap(session).contains("Things to revisit"))
    }
    func testDiagramAssetsAreBundledOffline() throws {
        let page = try XCTUnwrap(MarkdownBlocks.diagramPageURL)
        let html = try String(contentsOf: page, encoding: .utf8)
        XCTAssertTrue(html.contains("connect-src 'none'"))
        XCTAssertTrue(html.contains("securityLevel:'strict'"))
        XCTAssertTrue(FileManager.default.fileExists(atPath: page.deletingLastPathComponent().appendingPathComponent("mermaid.min.js").path))
    }
}
