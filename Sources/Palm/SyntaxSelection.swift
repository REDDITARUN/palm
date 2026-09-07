import Foundation
import CodeEditLanguages
import SwiftTreeSitter

struct SyntaxChoice { var title: String; var text: String }
enum SyntaxSelection {
    static func ancestors(code: String, language: String?, range: NSRange) -> [SyntaxChoice] {
        guard code.utf16.count < 100_000, let language = CodeLanguage.allLanguages.first(where: { $0.id.rawValue.lowercased() == language?.lowercased() })?.language else { return [] }
        let parser = Parser()
        do { try parser.setLanguage(language) } catch { return [] }
        // This binding parses UTF-16LE, and its NSRange helpers divide byte offsets by two.
        guard let tree = parser.parse(code), let root = tree.rootNode else { return [] }
        var node = root.descendant(in: range.byteRange)
        var result: [SyntaxChoice] = []
        var previous = NSRange(location: NSNotFound, length: 0)
        while let current = node, result.count < 8 {
            let span = current.range
            if current.isNamed, span.length > 0, span != previous, NSMaxRange(span) <= (code as NSString).length {
                result.append(.init(title: (current.nodeType ?? "expression").replacingOccurrences(of: "_", with: " "), text: (code as NSString).substring(with: span)))
                previous = span
            }
            node = current.parent
        }
        return result
    }
}
