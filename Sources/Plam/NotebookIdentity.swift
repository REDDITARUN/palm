import SwiftUI
import PlamCore

enum CourseIdentity {
    static func color(_ id: UUID?) -> Color {
        guard let id else { return .secondary }
        let colors: [Color] = [Palette.accent, .indigo, .orange, .purple, .blue, .pink]
        let hash = id.uuidString.utf8.reduce(UInt64(0)) { ($0 &* 31) &+ UInt64($1) }
        return colors[Int(hash % UInt64(colors.count))]
    }
}
struct NoteCourseLabel: View {
    var course: Course?
    var body: some View { HStack(spacing: 5) { Circle().fill(CourseIdentity.color(course?.id)).frame(width: 6, height: 6); Text(course?.outline.title ?? "Personal note").lineLimit(1) }.font(.system(size: 10, weight: .medium)).foregroundStyle(.secondary).help(course?.outline.title ?? "Personal note").accessibilityLabel("Course: " + (course?.outline.title ?? "Personal note")) }
}
