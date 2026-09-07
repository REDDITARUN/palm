import SwiftUI
import PalmCore
import AppKit
import UniformTypeIdentifiers

enum AchievementStyle {
    static func color(_ id: String) -> Color { switch id { case "first", "five": Palette.accent; case "week": .orange; case "apply", "independent": .indigo; case "course": .purple; case "recall": .teal; default: .blue } }
}
struct AchievementMedallion: View {
    var badge: LearningBadge
    var size: CGFloat = 68
    var body: some View {
        let color = badge.earned ? AchievementStyle.color(badge.id) : Color.secondary
        ZStack {
            Circle().fill(LinearGradient(colors: [color.opacity(badge.earned ? 0.20 : 0.05), color.opacity(0.035)], startPoint: .topLeading, endPoint: .bottomTrailing))
            Circle().inset(by: 5).stroke(color.opacity(badge.earned ? 0.26 : 0.12), lineWidth: 1)
            Image(systemName: badge.icon).font(.system(size: size * 0.32, weight: .medium)).foregroundStyle(color.opacity(badge.earned ? 1 : 0.45))
            if badge.earned { Image(systemName: "checkmark").font(.system(size: size * 0.13, weight: .bold)).foregroundStyle(color).padding(5).background(Palette.canvas, in: .circle).offset(x: size * 0.34, y: size * 0.34) }
        }.frame(width: size, height: size).accessibilityHidden(true)
    }
}
struct AchievementProgress: View {
    var badge: LearningBadge
    var body: some View {
        GeometryReader { geometry in
            Capsule().fill(Palette.inputFill).overlay(alignment: .leading) {
                Capsule().fill(AchievementStyle.color(badge.id).opacity(0.7)).frame(width: geometry.size.width * min(1, max(0, Double(badge.progress) / Double(max(1, badge.target)))))
            }
        }.frame(height: 3).accessibilityHidden(true)
    }
}
struct AchievementDetail: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    var badge: LearningBadge
    @State private var sharing = false
    private var featured: Bool { store.data.preferences.featuredBadgeIDs?.contains(badge.id) == true }
    var body: some View {
        VStack(spacing: 22) {
            HStack { Spacer(); Button("Done") { dismiss() }.buttonStyle(QuietButton()).keyboardShortcut(.cancelAction) }
            AchievementMedallion(badge: badge, size: 120)
            VStack(spacing: 8) { Text(badge.title).font(.system(size: 25, weight: .semibold)); Text(badge.earned ? "Earned " + (badge.earnedAt?.formatted(.dateTime.month(.wide).day().year()) ?? "") : "\(badge.progress) of \(badge.target)").font(.system(size: 12)).foregroundStyle(.secondary) }
            Text(badge.detail).font(.system(size: 14)).multilineTextAlignment(.center).lineSpacing(4).frame(maxWidth: 350)
            if !badge.earned { AchievementProgress(badge: badge).frame(width: 240) }
            if badge.earned {
                HStack { Button(featured ? "Remove from showcase" : "Feature on Progress") { store.updatePreferences { preferences in var ids = preferences.featuredBadgeIDs ?? []; let wasFeatured = ids.contains(badge.id); ids.removeAll { $0 == badge.id }; if !wasFeatured { ids.append(badge.id) }; preferences.featuredBadgeIDs = Array(ids.suffix(3)) } }.buttonStyle(QuietButton()); Button("Share achievement") { sharing = true }.buttonStyle(PrimaryButton()) }
            }
        }.padding(28).frame(width: 520).background(Palette.canvas).sheet(isPresented: $sharing) { ProgressShareSheet(badge: badge) }
    }
}
struct ProgressShareSheet: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    var badge: LearningBadge? = nil
    @State private var status = ""
    private var name: String { store.data.preferences.name.isEmpty ? "My learning" : store.data.preferences.name }
    private var days: [PracticeDay] { LearningProgress.practiceDays(store.data) }
    private var card: some View {
        VStack(spacing: 22) {
            HStack { Label("Palm", systemImage: "leaf.fill").font(.system(size: 18, weight: .semibold)); Spacer(); Text(Date().formatted(.dateTime.month(.abbreviated).year())).font(.system(size: 12)).foregroundStyle(.secondary) }
            Spacer(minLength: 0)
            if let badge { AchievementMedallion(badge: badge, size: 144); Text(badge.title).font(.system(size: 32, weight: .semibold)); Text(badge.detail).font(.system(size: 16)).multilineTextAlignment(.center).frame(maxWidth: 360) }
            else { PracticeTree(days: days); Text("\(days.count) days of learning").font(.system(size: 32, weight: .semibold)); Text("\(store.data.courses.reduce(0) { $0 + $1.completedLessonIDs.count }) topics completed · \(LearningProgress.badges(store.data).filter(\.earned).count) achievements").font(.system(size: 15)).foregroundStyle(.secondary) }
            Spacer(minLength: 0)
            Text(name).font(.system(size: 17, weight: .medium))
        }.padding(38).frame(width: 520, height: 590).foregroundStyle(Color(red: 0.15, green: 0.17, blue: 0.16)).background(Color(red: 0.97, green: 0.98, blue: 0.965)).environment(\.colorScheme, .light)
    }
    var body: some View {
        VStack(spacing: 18) {
            HStack { Text("Share your progress").font(.system(size: 18, weight: .semibold)); Spacer(); Button("Done") { dismiss() }.buttonStyle(QuietButton()) }
            card.scaleEffect(0.74, anchor: .top).frame(width: 385, height: 437, alignment: .top).clipped()
            HStack { Text(status).font(.system(size: 11)).foregroundStyle(.secondary); Spacer(); Button("Copy image") { export(copy: true) }.buttonStyle(QuietButton()); Button("Save image…") { export(copy: false) }.buttonStyle(PrimaryButton()) }
        }.padding(24).frame(width: 600)
    }
    @MainActor private func export(copy: Bool) {
        let renderer = ImageRenderer(content: card); renderer.scale = 2
        guard let image = renderer.nsImage, let tiff = image.tiffRepresentation, let bitmap = NSBitmapImageRep(data: tiff), let png = bitmap.representation(using: .png, properties: [:]) else { status = "Could not create image."; return }
        if copy { NSPasteboard.general.clearContents(); NSPasteboard.general.setData(png, forType: .png); status = "Image copied" }
        else {
            let panel = NSSavePanel(); panel.allowedContentTypes = [.png]
            panel.nameFieldStringValue = "Palm-" + (badge?.id ?? "progress") + ".png"
            let completion: (NSApplication.ModalResponse) -> Void = { response in
                if response == .OK, let url = panel.url { do { try png.write(to: url, options: .atomic); status = "Image saved" } catch { status = error.localizedDescription } }
            }
            var host = NSApp.keyWindow ?? NSApp.mainWindow
            while let attached = host?.attachedSheet { host = attached }
            if let host { panel.beginSheetModal(for: host, completionHandler: completion) }
            else { panel.begin(completionHandler: completion) }
        }
    }
}
