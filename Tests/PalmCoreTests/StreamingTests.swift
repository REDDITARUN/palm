import XCTest
@testable import PalmCore

private final class StreamStub: URLProtocol {
    static var payload = ""
    static var lastRequest: URLRequest?
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        Self.lastRequest = request
        client?.urlProtocol(self, didReceive: HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: ["Content-Type": "text/event-stream"])!, cacheStoragePolicy: .notAllowed)
        // Deliver in tiny chunks, including inside UTF-8 sequences.
        for byte in Self.payload.utf8 { client?.urlProtocol(self, didLoad: Data([byte])) }
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}
private actor EventCapture {
    var values: [TutorEvent] = []
    func append(_ event: TutorEvent) { values.append(event) }
}
final class StreamingTests: XCTestCase {
    func testDirectStreamingPreservesContentAndReportsActualReasoningState() async throws {
        StreamStub.payload = ": ping\n\ndata: {\"choices\":[{\"delta\":{\"reasoning\":\"internal provider reasoning\"}}]}\n\ndata: {\"choices\":[{\"delta\":{\"content\":\"λ \"}}]}\n\ndata: {\"choices\":[{\"delta\":{\"content\":\"🙂\"},\"finish_reason\":\"stop\"}]}\n\ndata: [DONE]\n\n"
        let config = URLSessionConfiguration.ephemeral; config.protocolClasses = [StreamStub.self]
        let ai = AIService(session: URLSession(configuration: config)); let events = EventCapture()
        try await ai.streamTutor("Explain", config: .init(key: "test-key", endpoint: "https://fixture.invalid/v1", model: "fixture")) { await events.append($0) }
        let captured = await events.values
        XCTAssertTrue(captured.contains(.status("Reasoning")))
        XCTAssertEqual(captured.compactMap { if case .text(let text) = $0 { return text }; return nil }.joined(), "λ 🙂")
        XCTAssertEqual(captured.last, .finished)
    }
    func testTruncatedStreamDoesNotBecomeACompletedReply() async throws {
        StreamStub.payload = "data: {\"choices\":[{\"delta\":{\"content\":\"Partial\"}}]}\n\ndata: {\"choices\":[{\"delta\":{},\"finish_reason\":\"length\"}]}\n\n"
        let config = URLSessionConfiguration.ephemeral; config.protocolClasses = [StreamStub.self]
        let ai = AIService(session: URLSession(configuration: config)); let events = EventCapture()
        do { try await ai.streamTutor("Explain", config: .init(key: "test-key", endpoint: "https://fixture.invalid/v1", model: "fixture")) { await events.append($0) }; XCTFail("Expected truncation failure") }
        catch { XCTAssertTrue(error.localizedDescription.contains("output limit")) }
        let values = await events.values
        XCTAssertFalse(values.contains(.finished))
    }
}
