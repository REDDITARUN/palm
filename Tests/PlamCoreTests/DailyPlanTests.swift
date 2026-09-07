import XCTest
@testable import PlamCore

final class DailyPlanTests: XCTestCase {
    private func course(_ name: String) -> Course {
        Course(topic: name, level: "New", repositoryID: nil, outline: .init(title: name, summary: "", outcomes: [], modules: [.init(id: "m", title: "Basics", lessons: [
            .init(id: "advanced", title: "Advanced", objective: "", minutes: 20, prerequisites: ["intro"]),
            .init(id: "intro", title: "Introduction", objective: "", minutes: 10, prerequisites: [])
        ])]))
    }
    func testPlanIncludesEveryActiveCourseAndRespectsPrerequisites() {
        var data = AppData(); data.courses = (0..<7).map { course("Course \($0)") }; data.courses[2].archived = true
        let plan = DailyPlan(data)
        XCTAssertEqual(plan.courses.count, 6)
        XCTAssertTrue(plan.courses.allSatisfy { $0.next?.id == "intro" })
        data.courses[0].completedLessonIDs = ["intro"]
        XCTAssertEqual(DailyPlan(data).courses.first { $0.id == data.courses[0].id }?.next?.id, "advanced")
    }
    func testResumeAndDueWorkArePrioritizedWithoutArchivedOrOrphanWork() {
        let now = Date(); var data = AppData(); data.courses = [course("Fresh"), course("Due"), course("Resume"), course("Archived")]; data.courses[3].archived = true
        var session = StudySession(courseID: data.courses[2].id, lessonID: "intro", content: LearningTests().content()); session.createdAt = now.addingTimeInterval(-100)
        data.sessions = [session]
        var archived = session; archived.id = UUID(); archived.courseID = data.courses[3].id; data.sessions.append(archived)
        var review = ReviewItem(courseID: data.courses[1].id, lessonID: "intro", title: "Introduction"); review.due = now.addingTimeInterval(-1); data.reviews = [review]
        var orphan = review; orphan.id = UUID(); orphan.lessonID = "deleted"; data.reviews.append(orphan)
        let plan = DailyPlan(data, now: now)
        XCTAssertEqual(plan.courses.map(\.id), [data.courses[2].id, data.courses[1].id, data.courses[0].id])
        XCTAssertEqual(plan.courses[1].reviews.count, 1)
        data.sessions[0].completedAt = now
        XCTAssertNil(DailyPlan(data, now: now).courses.first { $0.id == session.courseID }?.resume)
    }
    func testTodayUsesRecordedDayBucketsAndDoesNotDuplicateCompletedTopics() {
        var calendar = Calendar(identifier: .gregorian); calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let now = calendar.date(from: DateComponents(year: 2026, month: 9, day: 7, hour: 12))!
        var data = AppData(); data.courses = [course("Python")]
        var session = StudySession(courseID: data.courses[0].id, lessonID: "intro", content: LearningTests().content())
        session.createdAt = now.addingTimeInterval(-86400); session.activeSeconds = 1500; session.activityByDay = ["2026-9-7": 240, "2026-9-6": 1260]; session.completedAt = now
        var second = session; second.id = UUID(); second.activityByDay = ["2026-9-7": 120]
        data.sessions = [session, second]
        let plan = DailyPlan(data, now: now, calendar: calendar)
        XCTAssertEqual(plan.minutes, 6); XCTAssertEqual(plan.topics, 1)
    }
    func testCardsStayWithTheirCourseAndPersonalCardsRemainAvailable() {
        var data = AppData(); data.courses = [course("Active"), course("Archived")]; data.courses[1].archived = true
        var a = StudyNote(title: "A", body: ""); a.courseID = data.courses[0].id
        var b = StudyNote(title: "B", body: ""); b.courseID = data.courses[1].id
        let personal = StudyNote(title: "Personal", body: "")
        data.notes = [a, b, personal]
        data.flashcards = [a,b,personal].map { Flashcard(noteID: $0.id, front: "Q", back: "A") }
        let plan = DailyPlan(data, now: Date().addingTimeInterval(10))
        XCTAssertEqual(plan.courses[0].cards.map(\.noteID), [a.id]); XCTAssertEqual(plan.personalCards.map(\.noteID), [personal.id])
    }
    func testCursorAnchoredGraphZoomAndLimits() {
        var camera = GraphViewport(); camera.pan = .init(x: 41, y: -60)
        let center = CGPoint(x: 400, y: 250), cursor = CGPoint(x: 210, y: 380)
        let world = camera.unproject(cursor, center: center)
        for factor in [1.2, 0.5, 100, 0.0001, 2] {
            camera.zoom(factor, at: cursor, center: center)
            let result = camera.project(world, center: center)
            XCTAssertEqual(result.x, cursor.x, accuracy: 0.00001); XCTAssertEqual(result.y, cursor.y, accuracy: 0.00001)
            XCTAssertTrue((0.25...3).contains(camera.scale))
        }
        camera.zoom(.nan, at: cursor, center: center); XCTAssertTrue(camera.scale.isFinite)
    }
    func testExistingPreferencesDecodeWithoutReminderFields() throws {
        var object = try JSONSerialization.jsonObject(with: JSONEncoder().encode(Preferences())) as! [String: Any]
        object.removeValue(forKey: "reminderEnabled"); object.removeValue(forKey: "reminderHour"); object.removeValue(forKey: "reminderMinute")
        let preferences = try JSONDecoder().decode(Preferences.self, from: JSONSerialization.data(withJSONObject: object))
        XCTAssertNil(preferences.reminderEnabled)
    }
}
