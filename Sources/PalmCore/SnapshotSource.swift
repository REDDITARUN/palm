import Foundation

public struct SourceReference: Hashable, Identifiable, Sendable {
    public var path: String
    public var line: Int?
    public var endLine: Int?
    public var id: String { path + ":" + String(line ?? 0) }
    public init(_ location: String) throws {
        let pattern = #"^(.+?)(?:(?::|#L)([0-9]+)(?:[-:](?:L)?([0-9]+))?)?$"#
        let trimmed = location.trimmingCharacters(in: .whitespacesAndNewlines)
        let regex = try NSRegularExpression(pattern: pattern)
        guard let match = regex.firstMatch(in: trimmed, range: NSRange(trimmed.startIndex..., in: trimmed)), let range = Range(match.range(at: 1), in: trimmed) else { throw PalmError.message("Invalid source path.") }
        path = String(trimmed[range]); if path.hasPrefix("./") { path.removeFirst(2) }
        line = Range(match.range(at: 2), in: trimmed).flatMap { Int(trimmed[$0]) }
        endLine = Range(match.range(at: 3), in: trimmed).flatMap { Int(trimmed[$0]) }
        guard !path.isEmpty, !path.hasPrefix("/"), !path.contains(":"), !path.contains("\\"), !path.contains("\0"), !path.split(separator: "/").contains(".."), (line ?? 1) > 0, (endLine ?? line ?? 1) >= (line ?? 1) else { throw PalmError.message("This path is outside the saved repository.") }
    }
    public var link: URL {
        var url = URLComponents(); url.scheme = "palm-source"; url.host = "open"
        url.queryItems = [URLQueryItem(name: "path", value: path)] + (line.map { [URLQueryItem(name: "line", value: String($0))] } ?? []) + (endLine.map { [URLQueryItem(name: "end", value: String($0))] } ?? [])
        return url.url!
    }
    public init(link: URL) throws {
        guard link.scheme == "palm-source", link.host == "open", let parts = URLComponents(url: link, resolvingAgainstBaseURL: false), let path = parts.queryItems?.first(where: { $0.name == "path" })?.value else { throw PalmError.message("Invalid source link.") }
        let line = parts.queryItems?.first { $0.name == "line" }?.value
        let end = parts.queryItems?.first { $0.name == "end" }?.value
        try self.init(path + (line.map { ":" + $0 } ?? "") + (end.map { "-" + $0 } ?? ""))
    }
}

public enum SnapshotSource {
    public static func url(root: URL, reference: SourceReference) throws -> URL {
        let base = root.resolvingSymlinksInPath().standardizedFileURL
        let child = base.appendingPathComponent(reference.path).resolvingSymlinksInPath().standardizedFileURL
        guard child.path.hasPrefix(base.path + "/") else { throw PalmError.message("This path is outside the saved repository.") }
        return child
    }
    public static func read(root: URL, reference: SourceReference) throws -> String {
        let file = try url(root: root, reference: reference)
        let values = try file.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey])
        guard values.isRegularFile == true, (values.fileSize ?? Int.max) <= 2_000_000 else { throw PalmError.message("Choose a source file smaller than 2 MB.") }
        let text = try String(contentsOf: file, encoding: .utf8)
        guard !text.contains("\0") else { throw PalmError.message("This is a binary file.") }
        return text
    }
    public static func files(root: URL) throws -> [String] {
        let base = root.resolvingSymlinksInPath().standardizedFileURL
        guard FileManager.default.fileExists(atPath: base.path), let items = FileManager.default.enumerator(at: base, includingPropertiesForKeys: [.isRegularFileKey, .isSymbolicLinkKey], options: [.skipsHiddenFiles]) else { throw PalmError.message("This source snapshot is no longer available. Your lesson and saved excerpts are still kept.") }
        var paths: [String] = []
        for case let file as URL in items {
            let values = try file.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey])
            if values.isSymbolicLink == true { continue }
            if values.isRegularFile == true {
                let canonical = file.resolvingSymlinksInPath().standardizedFileURL.path
                guard canonical.hasPrefix(base.path + "/") else { continue }
                paths.append(String(canonical.dropFirst(base.path.count + 1)))
            }
            if paths.count >= 20_000 { break }
        }
        return paths.sorted()
    }
    public static func language(_ path: String) -> String {
        let ext = URL(fileURLWithPath: path).pathExtension.lowercased()
        return ["py": "python", "js": "javascript", "jsx": "javascript", "ts": "typescript", "tsx": "typescript", "rs": "rust", "h": "c", "sh": "bash", "md": "markdown" ][ext] ?? ext
    }
}
