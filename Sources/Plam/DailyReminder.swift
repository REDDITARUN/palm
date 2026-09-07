import SwiftUI
import UserNotifications
import PlamCore

@MainActor final class DailyReminder: NSObject, UNUserNotificationCenterDelegate {
    static let shared = DailyReminder()
    static let identifier = "plam.daily-practice"
    weak var store: AppStore?
    func configure(_ store: AppStore) {
        self.store = store
        guard !store.isUITesting else { return }
        UNUserNotificationCenter.current().delegate = self
        Task { try? await schedule(store.data.preferences) }
    }
    func schedule(_ preferences: Preferences) async throws {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [Self.identifier])
        guard preferences.reminderEnabled == true else { return }
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional else { return }
        let content = UNMutableNotificationContent()
        content.title = "A little time to learn"
        content.body = "Your next lesson and memory refreshers are ready in Today."
        var time = DateComponents(); time.hour = min(23, max(0, preferences.reminderHour ?? 19)); time.minute = min(59, max(0, preferences.reminderMinute ?? 0))
        try await center.add(UNNotificationRequest(identifier: Self.identifier, content: content, trigger: UNCalendarNotificationTrigger(dateMatching: time, repeats: true)))
    }
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
        guard response.notification.request.identifier == Self.identifier else { return }
        await MainActor.run { self.store?.navigate(.today); NSApp.activate(ignoringOtherApps: true) }
    }
}

struct DailyReminderSheet: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var enabled = false
    @State private var time = Date()
    @State private var message: String?
    @State private var saving = false
    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack { Text("Make room for learning").font(.system(size: 22, weight: .semibold)); Spacer(); Button { dismiss() } label: { Image(systemName: "xmark") }.buttonStyle(IconButton()).accessibilityLabel("Close reminder settings") }
            Text("A quiet daily reminder on your Mac. Open it to see your next step across all your courses.").font(.system(size: 13)).foregroundStyle(.secondary).lineSpacing(4)
            Toggle("Remind me each day", isOn: $enabled).toggleStyle(.switch)
            DatePicker("At", selection: $time, displayedComponents: .hourAndMinute).disabled(!enabled)
            Text("Uses your Mac’s local time. Scheduled reminders can arrive while Plam is closed; Focus and notification settings may silence them.").font(.system(size: 11)).foregroundStyle(.secondary)
            if let message { Text(message).font(.system(size: 12)).foregroundStyle(.secondary) }
            HStack { Spacer(); Button("Cancel") { dismiss() }.buttonStyle(QuietButton()); Button(saving ? "Saving…" : "Save reminder") { Task { await save() } }.buttonStyle(PrimaryButton()).disabled(saving) }
        }.padding(28).frame(width: 470).onAppear {
            enabled = store.data.preferences.reminderEnabled == true
            time = Calendar.current.date(bySettingHour: store.data.preferences.reminderHour ?? 19, minute: store.data.preferences.reminderMinute ?? 0, second: 0, of: Date()) ?? Date()
        }
    }
    private func save() async {
        saving = true; defer { saving = false }
        do {
            if enabled && !store.isUITesting {
                guard try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert]) else { message = "Notifications are off for Plam. Enable them in System Settings → Notifications, then save again."; return }
            }
            let hour = Calendar.current.component(.hour, from: time), minute = Calendar.current.component(.minute, from: time)
            var preferences = store.data.preferences; preferences.reminderEnabled = enabled; preferences.reminderHour = hour; preferences.reminderMinute = minute
            if !store.isUITesting { try await DailyReminder.shared.schedule(preferences) }
            store.updatePreferences { $0.reminderEnabled = enabled; $0.reminderHour = hour; $0.reminderMinute = minute }
            store.notice = store.isUITesting ? "Reminder preferences saved in the test profile. No notification was scheduled." : enabled ? "Daily reminder saved." : "Daily reminder turned off."
            dismiss()
        } catch { message = error.localizedDescription }
    }
}
