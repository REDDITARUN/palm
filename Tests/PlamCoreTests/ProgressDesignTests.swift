import XCTest
@testable import PlamCore

final class ProgressDesignTests: XCTestCase {
    func testEarnedWeekAndTreeSurviveBreakWithoutCountingFutureDays() {
        var calendar = Calendar(identifier: .gregorian); calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let now = Date(timeIntervalSince1970: 1_780_000_000)
        var card = Flashcard(noteID: UUID(), front: "Q", back: "A")
        for offset in Array(-16 ... -10) + [-10, 1] {
            card.reviews.append(.init(id: UUID(), date: calendar.date(byAdding: .day, value: offset, to: now)!, rating: .good))
        }
        var data = AppData(); data.flashcards = [card]
        let days = LearningProgress.practiceDays(data, now: now, calendar: calendar)
        XCTAssertEqual(days.count, 7)
        XCTAssertEqual(days.last?.count, 2)
        XCTAssertEqual(LearningProgress.streak(data, now: now, calendar: calendar), 0)
        XCTAssertEqual(LearningProgress.longestStreak(data, now: now, calendar: calendar), 7)
        let badge = LearningProgress.badges(data, now: now, calendar: calendar).first { $0.id == "week" }!
        XCTAssertTrue(badge.earned); XCTAssertEqual(badge.progress, 7)
        XCTAssertEqual(badge.earnedAt, days.last?.date)
    }
    func testRepeatedTopicCompletionDoesNotInflateMilestones() {
        var data = AppData()
        let now = Date(), course = UUID()
        for offset in 1...8 {
            var session = StudySession(courseID: course, lessonID: "same-topic", content: LearningTests().content())
            session.completedAt = now.addingTimeInterval(Double(-offset) * 86400)
            data.sessions.append(session)
        }
        let badges = LearningProgress.badges(data, now: now)
        XCTAssertTrue(badges.first { $0.id == "first" }!.earned)
        XCTAssertEqual(badges.first { $0.id == "five" }!.progress, 1)
        XCTAssertFalse(badges.first { $0.id == "five" }!.earned)
        XCTAssertEqual(badges.first { $0.id == "first" }!.earnedAt, data.sessions.last?.completedAt)
    }
    func testNotebookFiltersComposeAndRespectCourseIdentity() {
        let first = UUID(), second = UUID()
        var a = StudyNote(title: "Scope", body: "A lexical environment"); a.courseID = first; a.tags = ["Python"]; a.pinned = true
        var b = a; b.id = UUID(); b.courseID = second
        var c = StudyNote(title: "Personal", body: "Scope notes"); c.tags = ["Python"]
        let notes = [b, c, a]
        XCTAssertEqual(NotebookFilter.notes(notes, query: "LEXICAL", course: first.uuidString, tag: "Python", pinned: true).map(\.id), [a.id])
        XCTAssertEqual(NotebookFilter.notes(notes, course: "personal").map(\.id), [c.id])
        XCTAssertTrue(NotebookFilter.notes(notes, course: first.uuidString, tag: "Swift").isEmpty)
        XCTAssertEqual(Set(NotebookFilter.notes(notes).map(\.id)), Set(notes.map(\.id)))
    }
    func testGraphNeighborhoodIsBoundedAndHandlesCycles() {
        let links = [KnowledgeLink(source: "a", target: "b", relation: "link"), .init(source: "b", target: "c", relation: "link"), .init(source: "c", target: "d", relation: "link"), .init(source: "c", target: "b", relation: "link")]
        XCTAssertEqual(KnowledgeLayout.neighborhood("a", depth: 0, links: links), ["a"])
        XCTAssertEqual(KnowledgeLayout.neighborhood("a", depth: 1, links: links), ["a", "b"])
        XCTAssertEqual(KnowledgeLayout.neighborhood("a", depth: 2, links: links), ["a", "b", "c"])
        XCTAssertEqual(KnowledgeLayout.neighborhood("alone", depth: 4, links: links), ["alone"])
    }
    func testGraphLayoutIsFiniteDeterministicAndIgnoresMissingEndpoints() {
        let nodes = (0..<30).map { KnowledgeNode(id: "node\($0)", title: "Node \($0)", kind: "Note", recordID: UUID()) }
        let links = (1..<30).map { KnowledgeLink(source: "node0", target: "node\($0)", relation: "link") } + [.init(source: "missing", target: "node1", relation: "link")]
        let points = KnowledgeLayout.positions(nodes: nodes, links: links)
        XCTAssertEqual(points.count, 30)
        XCTAssertTrue(points.values.allSatisfy { $0.x.isFinite && $0.y.isFinite })
        XCTAssertEqual(points, KnowledgeLayout.positions(nodes: nodes.reversed(), links: links))
        XCTAssertTrue(KnowledgeLayout.positions(nodes: [], links: links).isEmpty)
        XCTAssertEqual(KnowledgeLayout.positions(nodes: [nodes[0]], links: links).count, 1)
    }
    func testDisconnectedCoursesOccupySeparateRegions() {
        let nodes = ["a", "b", "c", "d"].map { KnowledgeNode(id: $0, title: $0, kind: "Note", recordID: UUID()) }
        let points = KnowledgeLayout.positions(nodes: nodes, links: [.init(source: "a", target: "b", relation: "link"), .init(source: "c", target: "d", relation: "link")])
        let firstRight = max(points["a"]!.x, points["b"]!.x)
        let secondLeft = min(points["c"]!.x, points["d"]!.x)
        XCTAssertGreaterThan(secondLeft - firstRight, 100)
    }

}
