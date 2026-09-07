import XCTest
@testable import PlamCore

private final class ProviderStub: URLProtocol {
    static var responseBody: Data = Data()
    static var status = 200
    static var lastRequest: URLRequest?
    static var requestCount = 0
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        Self.lastRequest = request; Self.requestCount += 1
        client?.urlProtocol(self, didReceive: HTTPURLResponse(url: request.url!, statusCode: Self.status, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Self.responseBody)
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}

final class ProviderTests: XCTestCase {
    let config = ModelConfiguration(key: "test-only", endpoint: "https://provider.invalid/v1", model: "fixture")
    func service(body: String, status: Int = 200) -> AIService {
        ProviderStub.responseBody = Data(body.utf8); ProviderStub.status = status; ProviderStub.requestCount = 0
        let configuration = URLSessionConfiguration.ephemeral; configuration.protocolClasses = [ProviderStub.self]
        return AIService(session: URLSession(configuration: configuration))
    }
    func completion(_ content: String) throws -> String {
        String(data: try JSONSerialization.data(withJSONObject: ["choices": [["message": ["content": content], "finish_reason": "stop"]]]), encoding: .utf8)!
    }
    func testProviderUsesConfiguredRouteAndBearerCredential() async throws {
        let ai = service(body: "{\"data\":[{\"id\":\"fixture\"}]}")
        let models = try await ai.validateKey(config)
        XCTAssertEqual(models, ["fixture"])
        XCTAssertEqual(ProviderStub.lastRequest?.url?.path, "/v1/models")
        XCTAssertEqual(ProviderStub.lastRequest?.value(forHTTPHeaderField: "Authorization"), "Bearer test-only")
        XCTAssertNil(ProviderStub.lastRequest?.url?.query)
    }
    func testProviderErrorsAreActionableAndDoNotExposeServerBody() async throws {
        let ai = service(body: "SECRET SERVER BODY", status: 429)
        do { _ = try await ai.text("test", config: config); XCTFail("Expected rate limit error") }
        catch { XCTAssertTrue(error.localizedDescription.contains("rate or billing")); XCTAssertFalse(error.localizedDescription.contains("SECRET")) }
    }
    func testMalformedCourseCannotBecomeAnArtifact() async throws {
        let ai = service(body: try completion("{\"title\":\"Incomplete\"}"))
        do { _ = try await ai.outline(topic: "Test", level: "New", diagnostic: "", context: "", config: config); XCTFail("Expected malformed outline rejection") }
        catch { XCTAssertTrue(error.localizedDescription.contains("malformed learning artifact")) }
        XCTAssertEqual(ProviderStub.requestCount, 3, "One generation and at most two repairs")
    }
    func testTruncatedModelOutputIsRejected() async throws {
        let ai = service(body: "{\"choices\":[{\"message\":{\"content\":\"partial\"},\"finish_reason\":\"length\"}]}")
        do { _ = try await ai.text("test", config: config); XCTFail("Expected truncated output rejection") }
        catch { XCTAssertTrue(error.localizedDescription.contains("cut short")) }
    }
    func testRecapKeepsOriginalSourcesAndRejectsAnEmptyGeneration() async throws {
        let content = LessonContent(title: "Functions", introduction: "", material: "Return sends a value to the caller.", workedExample: "", takeaways: [], questions: [], sources: [LearningSource(id: "s1", title: "Functions source", location: "src/functions.py", excerpt: "return value")])
        let session = StudySession(courseID: UUID(), lessonID: "functions", content: content, snapshotID: nil)
        let ai = service(body: try completion("## A worked example\n\nA useful explanation."))
        let result = try await ai.recap(session: session, preferences: Preferences(), config: config)
        XCTAssertTrue(result.hasSuffix("## Sources\n\n- Functions source: src/functions.py"))
        ProviderStub.responseBody = Data(try completion("   ").utf8)
        do { _ = try await ai.recap(session: session, preferences: Preferences(), config: config); XCTFail("An empty recap should not replace saved notes") }
        catch { XCTAssertTrue(error.localizedDescription.contains("empty recap")) }
    }
    func testTutorAndRubricDecodeThroughCompatibleProvider() async throws {
        let ai = service(body: try completion("A useful explanation."))
        let reply = try await ai.tutor("Why?", config: config); XCTAssertEqual(reply, "A useful explanation.")
        ProviderStub.responseBody = Data(try completion("{\"correct\":false,\"feedback\":\"Ambiguous example\",\"misconception\":\"\",\"uncertain\":true}").utf8)
        let question = Question(id: "q", kind: .explain, skill: "explain", prompt: "Why?", code: "", options: [], answer: "Rubric", acceptedAnswers: [], explanation: "Explain", hints: [], sourceIDs: [])
        let grade = try await ai.evaluate(answer: "Reasoning", question: question, config: config)
        XCTAssertTrue(grade.uncertain); XCTAssertTrue(grade.misconception.isEmpty)
    }
}
