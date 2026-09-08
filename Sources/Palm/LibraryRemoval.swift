import Foundation
import PalmCore

extension AppStore {
    func deleteCourse(_ id: UUID) {
        guard busy == nil, !tutorBusy else { error = "Finish or cancel the current AI task before deleting this course."; return }
        let vectors = data.memories.filter { $0.courseID == id }.compactMap(\.vectorID)
        let sessions = Set(data.sessions.filter { $0.courseID == id }.map(\.id))
        do {
            let next = LibraryRemoval.course(id, from: data)
            try database.save(next); data = next
            if selectedCourseID == id || activeSessionID.map(sessions.contains) == true { navigate(.courses) }
            navigationHistory = []; navigationIndex = -1
            notice = "Course deleted. Its notes and flashcards are still in Notebook."
            Task { for vector in vectors { _ = try? await runtime.memory(operation: "delete", id: vector, key: "") } }
        } catch { self.error = "Could not delete this course: " + error.localizedDescription }
    }
    func removeRepository(_ id: UUID) {
        guard busy == nil, !tutorBusy else { error = "Finish or cancel the current AI task before removing this repository."; return }
        do {
            let next = LibraryRemoval.repository(id, from: data)
            try database.save(next); data = next
            if newCourseRepositoryID == id { newCourseRepositoryID = nil }
            notice = "Repository removed from Palm. The original folder and existing courses are kept."
        } catch { self.error = "Could not remove this repository: " + error.localizedDescription }
    }
}
