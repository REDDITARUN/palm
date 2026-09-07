import Foundation

public enum NotebookFilter {
    public static func notes(_ notes: [StudyNote], query: String = "", course: String = "all", tag: String = "", pinned: Bool = false, sort: String = "Recent") -> [StudyNote] {
        notes.filter { note in
            (course == "all" || (course == "personal" ? note.courseID == nil : note.courseID?.uuidString == course)) &&
            (tag.isEmpty || note.tags.contains(tag)) && (!pinned || note.pinned) &&
            (query.isEmpty || note.title.localizedCaseInsensitiveContains(query) || note.body.localizedCaseInsensitiveContains(query) || note.tags.contains { $0.localizedCaseInsensitiveContains(query) })
        }.sorted { a, b in
            if a.pinned != b.pinned { return a.pinned }
            if sort == "Title" { let order = a.title.localizedStandardCompare(b.title); return order == .orderedSame ? a.id.uuidString < b.id.uuidString : order == .orderedAscending }
            return a.updatedAt == b.updatedAt ? a.id.uuidString < b.id.uuidString : a.updatedAt > b.updatedAt
        }
    }
}
