import Foundation

/// Separate complete, top-level Mermaid fences; other code fences stay literal.
public enum MarkdownBlocks {
    public struct Block: Identifiable, Equatable {
        public var id: Int
        public var content: String
        public var isDiagram: Bool
    }
    public static func parse(_ source: String) -> [Block] {
        let lines = source.components(separatedBy: "\n")
        var blocks: [Block] = [], prose: [String] = []
        var index = 0
        func appendProse() {
            if !prose.isEmpty { blocks.append(Block(id: blocks.count, content: prose.joined(separator: "\n"), isDiagram: false)); prose = [] }
        }
        while index < lines.count {
            let line = lines[index]
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            let indent = line.prefix(while: { $0 == " " }).count
            guard indent <= 3, let marker = trimmed.first, marker == "`" || marker == "~" else { prose.append(line); index += 1; continue }
            let count = trimmed.prefix(while: { $0 == marker }).count
            guard count >= 3 else { prose.append(line); index += 1; continue }
            let language = trimmed.dropFirst(count).trimmingCharacters(in: .whitespaces).lowercased()
            var end = index + 1
            while end < lines.count {
                let candidate = lines[end].trimmingCharacters(in: .whitespaces)
                if lines[end].prefix(while: { $0 == " " }).count <= 3 && candidate.count >= count && candidate.allSatisfy({ $0 == marker }) { break }
                end += 1
            }
            guard end < lines.count else { prose.append(contentsOf: lines[index...]); break }
            if language == "mermaid" {
                appendProse()
                blocks.append(Block(id: blocks.count, content: lines[(index + 1)..<end].joined(separator: "\n"), isDiagram: true))
            } else { prose.append(contentsOf: lines[index...end]) }
            index = end + 1
        }
        appendProse()
        return blocks
    }
    public static var diagramPageURL: URL? { Bundle.module.url(forResource: "diagram", withExtension: "html", subdirectory: "Resources/Diagrams") }
}
