import SwiftUI
import AVFoundation
import PalmCore

@MainActor @Observable final class VoiceInput: NSObject, AVAudioRecorderDelegate {
    enum Phase { case idle, preparing, recording, transcribing }
    private(set) var phase: Phase = .idle
    private(set) var status = ""
    var error: String?
    private(set) var startedAt: Date?
    private var recorder: AVAudioRecorder?
    private var file: URL?
    private var work: Task<Void, Never>?
    private var generation = UUID()
    // A single recorder across all composers. Changing destinations cancels the previous one.
    private static weak var owner: VoiceInput?

    func start() {
        Self.owner?.cancel(); Self.owner = self
        error = nil; phase = .preparing; status = "Preparing Parakeet…"
        let token = UUID(); generation = token
        work = Task {
            do {
                try await VoiceTranscriber.shared.prepare { [weak self] fraction in
                    Task { @MainActor in guard self?.generation == token else { return }; self?.status = fraction >= 1 ? "Loading voice model…" : "Preparing voice model · \(Int(max(0, min(1, fraction)) * 100))%" }
                }
                try Task.checkCancellation()
                guard await AVCaptureDevice.requestAccess(for: .audio) else { throw PalmError.message("Allow microphone access for Palm in System Settings → Privacy & Security → Microphone.") }
                try Task.checkCancellation(); guard generation == token else { return }
                let url = FileManager.default.temporaryDirectory.appendingPathComponent("palm-voice-" + UUID().uuidString + ".wav")
                file = url
                let recording = try AVAudioRecorder(url: url, settings: [AVFormatIDKey: kAudioFormatLinearPCM, AVSampleRateKey: 16000, AVNumberOfChannelsKey: 1, AVLinearPCMBitDepthKey: 16, AVLinearPCMIsFloatKey: false, AVLinearPCMIsBigEndianKey: false])
                recording.delegate = self
                guard recording.record() else { throw PalmError.message("The microphone could not start. Check your input device and try again.") }
                recorder = recording; startedAt = Date(); phase = .recording; status = "Listening on this Mac"
            } catch { if !Task.isCancelled, generation == token { self.error = error.localizedDescription; cancel() } }
        }
    }
    func finish(insert: @escaping (String) -> Void) {
        guard phase == .recording, let file else { return }
        recorder?.delegate = nil; recorder?.stop(); recorder = nil; phase = .transcribing; status = "Transcribing on this Mac…"
        let token = generation
        work = Task {
            defer { try? FileManager.default.removeItem(at: file) }
            do {
                let transcript = try await VoiceTranscriber.shared.transcribe(file)
                try Task.checkCancellation(); guard generation == token else { return }
                if transcript.isEmpty { error = "No speech was detected. Try again a little closer to the microphone." }
                else { insert(transcript) }
                cancel()
            } catch { if !Task.isCancelled, generation == token { self.error = error.localizedDescription; cancel() } }
        }
    }
    func cancel() {
        generation = UUID(); work?.cancel(); work = nil
        recorder?.delegate = nil; recorder?.stop(); recorder = nil
        if let file { try? FileManager.default.removeItem(at: file) }; file = nil
        phase = .idle; status = ""; startedAt = nil
        if Self.owner === self { Self.owner = nil }
    }
    nonisolated func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
        Task { @MainActor in self.error = "Audio recording stopped. Please check your microphone and try again."; self.cancel() }
    }
}

struct VoiceInputButton: View {
    @Environment(\.isEnabled) private var isEnabled
    @Binding var text: String
    var shortcutEnabled = false
    @State private var voice = VoiceInput()
    @State private var explainDownload = false
    var body: some View {
        HStack(spacing: 6) {
            if voice.phase != .idle {
                if let start = voice.startedAt, voice.phase == .recording { Text(start, style: .timer).monospacedDigit().font(.caption).fixedSize() }
                Text(voice.status).font(.system(size: 11)).foregroundStyle(.secondary).lineLimit(1)
                if voice.phase != .recording { ProgressView().controlSize(.mini) }
                Button { voice.cancel() } label: { Image(systemName: "xmark") }.buttonStyle(IconButton()).accessibilityLabel("Cancel dictation")
            }
            Button(action: toggle) { Image(systemName: voice.phase == .recording ? "stop.circle.fill" : "mic").foregroundStyle(voice.phase == .recording ? Palette.accent : Color.secondary) }
                .buttonStyle(IconButton()).disabled(voice.phase == .preparing || voice.phase == .transcribing)
                .accessibilityLabel(voice.phase == .recording ? "Finish dictation" : "Dictate answer")
                .help("Dictate · ⌘⇧D. Review the transcript before sending.")
                .keyboardShortcut(shortcutEnabled ? KeyboardShortcut("d", modifiers: [.command, .shift]) : nil)
        }
        .onDisappear { voice.cancel() }
        .onChange(of: isEnabled) { if !isEnabled { voice.cancel() } }
        .alert("Set up local voice input?", isPresented: $explainDownload) {
            Button("Download and continue") { voice.start() }
            Button("Cancel", role: .cancel) {}
        } message: { Text("Palm downloads the Parakeet v3 speech model once (several hundred MB). After setup, dictation runs on your Mac. Your audio is deleted after transcription. ⌘⇧D starts and stops recording in the focused answer or chat.") }
        .alert("Voice input", isPresented: Binding(get: { voice.error != nil }, set: { if !$0 { voice.error = nil } })) { Button("OK") { voice.error = nil } } message: { Text(voice.error ?? "") }
    }
    private func toggle() {
        if voice.phase == .recording {
            voice.finish { transcript in text += (text.isEmpty || text.last?.isWhitespace == true ? "" : " ") + transcript }
        } else if VoiceTranscriber.downloaded { voice.start() }
        else { explainDownload = true }
    }
}
