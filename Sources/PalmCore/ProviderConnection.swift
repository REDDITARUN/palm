import Foundation

public enum ModelAuthentication: String, Codable, CaseIterable { case apiKey, chatGPT }

/// A saved connection contains preferences only. Credentials never enter library exports.
public struct ProviderConnection: Codable, Identifiable, Equatable {
    public var id = UUID()
    public var name: String
    public var endpoint: String
    public var model: String
    public var authentication: ModelAuthentication = .apiKey
    public var freeOnly = true
    public var modelIDs: [String] = []
    public var legacyCredentialAccount: String?
    public var credentialAccount: String {
        let legacy = ModelConfiguration(key: "", endpoint: endpoint, model: model).credentialAccount
        if legacyCredentialAccount == legacy { return legacy }
        return "provider-" + id.uuidString + "-" + RepositoryService.hash(Data(endpoint.utf8)).prefix(20)
    }
    public init(name: String, endpoint: String, model: String, authentication: ModelAuthentication = .apiKey) {
        self.name = name; self.endpoint = endpoint; self.model = model; self.authentication = authentication
    }
    public static func preset(_ name: String) -> Self {
        switch name {
        case "OpenAI": return .init(name: name, endpoint: "https://api.openai.com/v1", model: "gpt-4.1")
        case "ChatGPT": return .init(name: name, endpoint: "https://api.openai.com/v1", model: "", authentication: .chatGPT)
        case "OpenRouter": return .init(name: name, endpoint: "https://openrouter.ai/api/v1", model: "thinkingmachines/inkling:free")
        default: return .init(name: "Custom", endpoint: "http://localhost:1234/v1", model: "")
        }
    }
    public func configuration(key: String = "") -> ModelConfiguration {
        .init(key: authentication == .chatGPT ? "" : key, endpoint: endpoint, model: model, authentication: authentication, credentialAccount: credentialAccount)
    }
    public func validated() throws -> Self {
        var value = self
        value.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        value.model = model.trimmingCharacters(in: .whitespacesAndNewlines)
        value.endpoint = endpoint.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.name.isEmpty, !value.model.isEmpty else { throw PalmError.message("Enter a connection name and model ID.") }
        try value.configuration().validateEndpoint()
        if authentication == .chatGPT && value.endpoint != "https://api.openai.com/v1" { throw PalmError.message("ChatGPT sign-in uses OpenCode's OpenAI provider.") }
        return value
    }
}

extension Preferences {
    public var activeProvider: ProviderConnection? { providerConnections?.first { $0.id == selectedProviderID } }
    public mutating func migrateProviders() {
        guard providerConnections == nil || providerConnections!.isEmpty else {
            if activeProvider == nil, let first = providerConnections?.first { activateProvider(first.id) }
            return
        }
        let config = ModelConfiguration(key: "", endpoint: endpoint, model: model)
        var initial = ProviderConnection(name: config.isOpenRouter ? "OpenRouter" : (config.agentProvider == "openai" ? "OpenAI" : "Custom"), endpoint: endpoint, model: model)
        initial.legacyCredentialAccount = config.credentialAccount
        providerConnections = [initial]; selectedProviderID = initial.id
    }
    public mutating func activateProvider(_ id: UUID) {
        guard let provider = providerConnections?.first(where: { $0.id == id }) else { return }
        selectedProviderID = id; endpoint = provider.endpoint; model = provider.model
    }
    public mutating func saveProvider(_ provider: ProviderConnection, activate: Bool) {
        if providerConnections == nil { providerConnections = [] }
        if let i = providerConnections?.firstIndex(where: { $0.id == provider.id }) { providerConnections?[i] = provider }
        else { providerConnections?.append(provider) }
        if activate || selectedProviderID == provider.id { activateProvider(provider.id) }
    }
}
