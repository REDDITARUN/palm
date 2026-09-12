import Foundation
import FluidAudio

/// Model weights are cached outside the study library; audio never goes to a server.
public actor VoiceTranscriber {
    public static let shared = VoiceTranscriber()
    private var manager: AsrManager?
    public static var cacheDirectory: URL {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0].appendingPathComponent("app.plam.learning/Parakeet", isDirectory: true)
    }
    public static var downloaded: Bool { AsrModels.modelsExist(at: cacheDirectory, version: .v3) }
    public func prepare(progress: (@Sendable (Double) -> Void)? = nil) async throws {
        guard manager == nil else { return }
        let models = try await AsrModels.downloadAndLoad(to: Self.cacheDirectory, version: .v3, progressHandler: { progress?($0.fractionCompleted) })
        try Task.checkCancellation()
        manager = AsrManager(models: models)
    }
    public func transcribe(_ file: URL) async throws -> String {
        try await prepare()
        guard let manager else { throw PalmError.message("Prepare voice input and try again.") }
        var decoder = try TdtDecoderState()
        let result = try await manager.transcribe(file, decoderState: &decoder)
        try Task.checkCancellation()
        return result.text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
