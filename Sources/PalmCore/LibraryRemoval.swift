import Foundation

public enum LibraryRemoval {
    /// Keep authored notes, note revisions, and their flashcards as independent study material.
    public static func course(_ id: UUID, from data: AppData) -> AppData {
        var next = data
        let sessions = Set(data.sessions.filter { $0.courseID == id }.map(\.id))
        next.courses.removeAll { $0.id == id }
        next.sessions.removeAll { $0.courseID == id }
        next.reviews.removeAll { $0.courseID == id }
        next.memories.removeAll { $0.courseID == id }
        for i in next.notes.indices {
            if next.notes[i].courseID == id { next.notes[i].courseID = nil }
            if next.notes[i].sessionID.map(sessions.contains) == true { next.notes[i].sessionID = nil }
        }
        next.conversations?.removeAll { conversation in sessions.contains { conversation.id == "session:" + $0.uuidString || conversation.id.hasPrefix("session:" + $0.uuidString + ":branch:") } }
        return next
    }
    /// Forget the connection, retaining source snapshots cited by saved lessons. No filesystem writes.
    public static func repository(_ id: UUID, from data: AppData) -> AppData {
        var next = data
        next.repositories.removeAll { $0.id == id }
        next.repositoryInsights?.removeAll { $0.repositoryID == id }
        for i in next.courses.indices where next.courses[i].repositoryID == id { next.courses[i].repositoryID = nil }
        return next
    }
}
