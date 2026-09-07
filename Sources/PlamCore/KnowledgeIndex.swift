import Foundation

public struct KnowledgeNode: Identifiable, Equatable {
    public var id: String
    public var title: String
    public var kind: String
    public var recordID: UUID
}
public struct KnowledgeLink: Identifiable, Equatable {
    public var source: String
    public var target: String
    public var relation: String
    public var id: String { source + ":" + relation + ":" + target }
}
public struct KnowledgeIndex {
    public var nodes: [KnowledgeNode]
    public var links: [KnowledgeLink]
    public init(_ data: AppData) {
        nodes = data.notes.map { .init(id: "note:" + $0.id.uuidString, title: $0.title, kind: "Note", recordID: $0.id) }
        nodes += data.courses.map { .init(id: "course:" + $0.id.uuidString, title: $0.outline.title, kind: "Course", recordID: $0.id) }
        nodes += data.memories.filter { !$0.forgotten }.map { .init(id: "memory:" + $0.id.uuidString, title: String($0.text.prefix(90)), kind: "Memory", recordID: $0.id) }
        var edges: [KnowledgeLink] = []
        for note in data.notes {
            let source = "note:" + note.id.uuidString
            if let course = note.courseID, data.courses.contains(where: { $0.id == course }) { edges.append(.init(source: source, target: "course:" + course.uuidString, relation: "explains")) }
            let targets = Self.linkTargets(note)
            for other in data.notes where other.id != note.id && (targets.contains(other.id) || note.body.contains("[[" + other.title + "]]") || note.body.contains("[[" + other.id.uuidString + "]]")) { edges.append(.init(source: source, target: "note:" + other.id.uuidString, relation: "links to")) }
        }
        for memory in data.memories where !memory.forgotten {
            if let course = memory.courseID, data.courses.contains(where: { $0.id == course }) { edges.append(.init(source: "memory:" + memory.id.uuidString, target: "course:" + course.uuidString, relation: "learning evidence")) }
        }
        links = edges
    }
    public static func linkTargets(_ note: StudyNote) -> Set<UUID> {
        guard let json = note.blocksJSON, let value = try? JSONSerialization.jsonObject(with: Data(json.utf8)) else { return [] }
        var result = Set<UUID>()
        func visit(_ value: Any) {
            if let array = value as? [Any] { array.forEach(visit) }
            if let object = value as? [String: Any] {
                if object["type"] as? String == "noteLink", let props = object["props"] as? [String: Any], let target = props["target"] as? String, let id = UUID(uuidString: target) { result.insert(id) }
                object.values.forEach(visit)
            }
        }
        visit(value); return result
    }
    public static func context(_ data: AppData, query: String, excluding noteID: UUID? = nil) -> String {
        let tokens = Set(query.lowercased().split(whereSeparator: { !$0.isLetter && !$0.isNumber }).filter { $0.count > 2 }.map(String.init))
        var ranked: [(StudyNote, Int)] = []
        for note in data.notes where note.id != noteID {
            let searchable = (note.title + " " + note.body + " " + note.tags.joined(separator: " ")).lowercased()
            var score = data.notes.first(where: { $0.id == noteID }).map { Self.linkTargets($0).contains(note.id) ? 2 : 0 } ?? 0
            for token in tokens where searchable.contains(token) { score += 1 }
            if score > 0 { ranked.append((note, score)) }
        }
        ranked.sort { left, right in left.1 == right.1 ? left.0.updatedAt > right.0.updatedAt : left.1 > right.1 }
        let notes = ranked.prefix(5).map { "[[\($0.0.title)]] (saved note \($0.0.id))\n\($0.0.body.prefix(3500))" }.joined(separator: "\n\n")
        let memories = data.memories.filter { memory in !memory.forgotten && tokens.contains(where: { memory.text.localizedCaseInsensitiveContains($0) }) }.prefix(4).map { "Saved learning memory (\($0.id), evidence \($0.sourceIDs.map(\.uuidString).joined(separator: ", "))): \($0.text)" }.joined(separator: "\n")
        return notes + (memories.isEmpty ? "" : "\n\n" + memories)
    }
}
