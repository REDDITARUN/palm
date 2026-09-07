import Foundation

public enum WorkspaceResources {
    public static var editorURL: URL? { Bundle.module.url(forResource: "index", withExtension: "html", subdirectory: "Resources/Editor") }
}
public struct TutorConversation: Codable, Identifiable, Equatable {
    public var id: String
    public var messages: [ChatMessage] = []
    public var draft = ""
    public var updatedAt = Date()
    public init(id: String) { self.id = id }
}
public struct ModelProfile: Codable, Identifiable, Equatable {
    public var id = UUID()
    public var name = ""
    public var endpoint = "https://openrouter.ai/api/v1"
    public var model = ""
    public var roles: [String] = []
    public init() {}
}
public struct MCPServerProfile: Codable, Identifiable, Equatable {
    public var id = UUID()
    public var name = ""
    public var transport = "remote"
    public var url = ""
    public var command = ""
    public var arguments: [String] = []
    public var enabled = false
    public var allowedTools: [String] = []
    public var credentialAccount: String { "mcp-" + id.uuidString + "-" + RepositoryService.hash(Data(url.utf8)).prefix(16) }
    public init() {}
}
public struct AgentSkillProfile: Codable, Identifiable, Equatable {
    public var id = UUID()
    public var name = ""
    public var instructions = ""
    public var enabled = true
    public init() {}
}
public enum TutorEvent: Sendable, Equatable { case status(String), text(String), finished }

/// SSE framing is independent of network chunk boundaries; comments and unknown fields are ignored.
public struct ServerSentEvents {
    private var data: [String] = []
    public init() {}
    public mutating func consume(_ line: String) -> String? {
        if line.isEmpty { guard !data.isEmpty else { return nil }; defer { data.removeAll() }; return data.joined(separator: "\n") }
        if line.hasPrefix("data:") { var value = String(line.dropFirst(5)); if value.first == " " { value.removeFirst() }; data.append(value) }
        return nil
    }
}

public struct DiagramChoice: Codable, Identifiable, Equatable {
    public var id: String
    public var mermaid: String
    public var description: String
    public init(id: String, mermaid: String, description: String) { self.id = id; self.mermaid = mermaid; self.description = description }
}
