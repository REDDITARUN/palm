import Foundation

/// Protect LaTeX from Markdown's emphasis, escapes, and soft-break parsing.
public enum MathMarkdown {
    public struct Formula { public var token: String; public var markdown: String }
    public static func prepare(_ source: String) -> (text: String, formulas: [Formula]) {
        // Code fences and inline code are matched first and passed through untouched.
        let pattern = #"(?ms)^[ ]{0,3}(`{3,}|~{3,})[^\n]*\n.*?(?:^[ ]{0,3}\1[ \t]*$|\z)|(`+).*?\2|(?<!\\)\$\$(.+?)\$\$|(?<![\\$])\$(?!\$)([^\n$]+)\$"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return (source, []) }
        var text = source, formulas: [Formula] = []
        let prefix = "PLAMMATH" + UUID().uuidString.replacingOccurrences(of: "-", with: "")
        for match in regex.matches(in: source, range: NSRange(source.startIndex..., in: source)).reversed() {
            let display = match.range(at: 3).location != NSNotFound
            guard let body = Range(match.range(at: display ? 3 : 4), in: source), let full = Range(match.range, in: source) else { continue }
            let token = prefix + String(formulas.count) + "END"
            let latex = source[body].replacingOccurrences(of: "\n", with: " ")
            // Foundation removes Markdown escapes before Textual creates its math attachment.
            let escaped = latex.reduce(into: "") { value, character in
                if "\\`*_[]<>".contains(character) { value.append("\\") }
                value.append(character)
            }
            let delimiter = display ? "$$" : "$"
            formulas.append(Formula(token: token, markdown: delimiter + escaped + delimiter))
            text.replaceSubrange(full, with: token)
        }
        return (text, formulas)
    }
}
