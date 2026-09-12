import SwiftUI
import Sparkle
import Combine

@MainActor @Observable final class UpdateController {
    static let shared = UpdateController()
    private let feedDelegate = UpdateFeedDelegate()
    private let controller: SPUStandardUpdaterController
    private var observation: AnyCancellable?
    private var automaticObservation: AnyCancellable?
    var automaticChecks = false {
        didSet { if controller.updater.automaticallyChecksForUpdates != automaticChecks { controller.updater.automaticallyChecksForUpdates = automaticChecks } }
    }
    private(set) var canCheck = false
    private(set) var enabled = false
    private init() {
        controller = SPUStandardUpdaterController(startingUpdater: false, updaterDelegate: feedDelegate, userDriverDelegate: nil)
        enabled = Bundle.main.bundleIdentifier == "app.plam.learning" && !ProcessInfo.processInfo.arguments.contains("--ui-testing")
        if feedDelegate.testFeed != nil { enabled = true }
        if enabled { controller.startUpdater() }
        automaticChecks = controller.updater.automaticallyChecksForUpdates
        automaticObservation = controller.updater.publisher(for: \.automaticallyChecksForUpdates).receive(on: DispatchQueue.main).sink { [weak self] in self?.automaticChecks = $0 }
        observation = controller.updater.publisher(for: \.canCheckForUpdates).receive(on: DispatchQueue.main).sink { [weak self] in self?.canCheck = $0 }
    }
    func check() { guard enabled, canCheck else { return }; controller.checkForUpdates(nil) }

}

struct CheckForUpdatesButton: View {
    @State private var updater = UpdateController.shared
    var body: some View { Button("Check for Updates…") { updater.check() }.disabled(!updater.enabled || !updater.canCheck) }
}

struct UpdateSettings: View {
    @State private var updater = UpdateController.shared
    var body: some View {
        @Bindable var updater = updater
        VStack(alignment: .leading, spacing: 12) {
            HStack { Text("Palm " + (Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "Development")).font(.headline); Spacer(); CheckForUpdatesButton().buttonStyle(QuietButton()) }
            Toggle("Check for updates automatically", isOn: $updater.automaticChecks).disabled(!updater.enabled)
            Text("Updates come from Palm’s GitHub releases and are verified before installation. Your courses, notes, progress, and model connections stay on this Mac.").font(.system(size: 12)).foregroundStyle(.secondary)
            if !updater.enabled { Text("Update installation is disabled in development and test builds.").font(.caption).foregroundStyle(.secondary) }
            Link("View releases ↗", destination: URL(string: "https://github.com/REDDITARUN/palm/releases")!).font(.system(size: 12))
        }
    }
}

private final class UpdateFeedDelegate: NSObject, SPUUpdaterDelegate {
    var testFeed: String? {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--ui-testing"),
           Bundle.main.bundleIdentifier == "app.plam.learning.test",
           let value = ProcessInfo.processInfo.environment["PALM_UPDATE_TEST_FEED"],
           let url = URL(string: value), url.scheme == "http", url.host == "127.0.0.1" { return value }
        #endif
        return nil
    }
    func feedURLString(for updater: SPUUpdater) -> String? { testFeed }
}
