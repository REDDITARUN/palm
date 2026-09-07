import SwiftUI
import PlamCore

struct TrackerView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var tab = "Overview"
    @State private var selectedBadge: LearningBadge?
    @State private var sharing = false
    @State private var selectedDay: Date?
    @State private var expandedCourse: UUID?
    private var badges: [LearningBadge] { LearningProgress.badges(store.data, now: store.clock) }
    private var days: [PracticeDay] { LearningProgress.practiceDays(store.data, now: store.clock) }
    private var showcase: [LearningBadge] {
        let featured = (store.data.preferences.featuredBadgeIDs ?? []).compactMap { id in badges.first { $0.id == id && $0.earned } }
        return Array((featured + badges.filter { $0.earned && !featured.map(\.id).contains($0.id) } + badges.filter { !$0.earned }).prefix(3))
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 5) { Text("Progress").font(.system(size: 26, weight: .semibold)); Text("The practice you’ve put in. The things you’ve learned.").font(.system(size: 13)).foregroundStyle(.secondary) }
                Spacer(); Button { sharing = true } label: { Label("Share progress", systemImage: "square.and.arrow.up") }.buttonStyle(QuietButton())
            }.padding(.horizontal, 32).padding(.top, 24).padding(.bottom, 20).frame(maxWidth: 1120).frame(maxWidth: .infinity)
            WorkspaceTabs(title: "Progress view", selection: $tab, options: [.init("Overview", "Overview"), .init("Achievements", "Achievements")]).padding(.horizontal, 32).padding(.bottom, 20).frame(maxWidth: 1120, alignment: .leading).frame(maxWidth: .infinity)
            ScrollView {
                VStack(alignment: .leading, spacing: 26) {
                    if tab == "Overview" { overview }
                    else { achievements }
                }.padding(.horizontal, 32).padding(.bottom, 32).frame(maxWidth: 1120).frame(maxWidth: .infinity)
            }
        }.sheet(item: $selectedBadge) { AchievementDetail(badge: $0) }.sheet(isPresented: $sharing) { ProgressShareSheet() }
    }
    private var overview: some View {
        VStack(alignment: .leading, spacing: 26) {
            HStack(alignment: .center, spacing: 22) {
                VStack(spacing: 2) {
                    PracticeTree(days: days, selected: selectedDay) { selectedDay = $0 }
                    Text(selectedDay.map { date in date.formatted(.dateTime.month(.abbreviated).day()) + " · \(days.first { $0.date == date }?.count ?? 0) practice answers" } ?? (days.isEmpty ? "Your first practice starts its growth." : "\(days.count < 3 ? "Sprout" : days.count < 7 ? "Seedling" : days.count < 14 ? "Sapling" : days.count < 28 ? "Young tree" : "Growing tree") · each bright leaf is a practice day")).font(.system(size: 11)).foregroundStyle(.secondary)
                }.frame(width: 320)
                VStack(alignment: .leading, spacing: 18) {
                    HStack { Label("Your learning tree", systemImage: "leaf").font(.system(size: 12, weight: .medium)).foregroundStyle(Palette.accent); Spacer(); if store.data.preferences.showStreak != false { Label("\(LearningProgress.streak(store.data, now: store.clock)) day streak", systemImage: "flame.fill").font(.system(size: 12, weight: .medium)).foregroundStyle(.orange) } }
                    Text(days.isEmpty ? "A little practice.\nRoom to grow." : "\(days.count) days of showing up.").font(.system(size: 27, weight: .semibold)).tracking(-0.5)
                    Text("Your tree keeps its growth after a break. Select a bright leaf to revisit a practice day." + (days.count > 56 ? " The canopy shows your latest 56 days." : "")).font(.system(size: 12)).foregroundStyle(.secondary).lineSpacing(4).fixedSize(horizontal: false, vertical: true)
                    HStack { Text("Milestones").font(.system(size: 13, weight: .semibold)); Spacer(); Button("View all \(badges.count)") { tab = "Achievements" }.buttonStyle(TextActionStyle()).font(.system(size: 11)).foregroundStyle(.secondary) }
                    HStack(alignment: .top, spacing: 10) { ForEach(showcase) { badge in Button { selectedBadge = badge } label: { VStack(spacing: 10) { AchievementMedallion(badge: badge, size: 58); Text(badge.title).font(.system(size: 11, weight: .medium)).lineLimit(2).multilineTextAlignment(.center); Text(badge.earned ? "Earned" : "\(badge.progress)/\(badge.target)").font(.system(size: 10)).foregroundStyle(.secondary) }.frame(maxWidth: .infinity).padding(.vertical, 6).contentShape(.rect) }.buttonStyle(OptionButtonStyle()).accessibilityLabel(badge.title + (badge.earned ? ", earned" : ", \(badge.progress) of \(badge.target)")) } }
                }.frame(maxWidth: .infinity, alignment: .leading)
            }.padding(24).background(Palette.canvas, in: .rect(cornerRadius: 20))
            HStack(spacing: 24) {
                statistic("Topics completed", value: store.activeCourses.reduce(0) { $0 + $1.completedLessonIDs.count }, detail: "Across \(store.activeCourses.count) " + (store.activeCourses.count == 1 ? "course" : "courses"), icon: "square.stack")
                statistic("Solved independently", value: store.totalAttempts.filter { $0.independent && $0.grade.correct }.count, detail: "Without hints or revealed answers", icon: "sparkles")
                statistic("Achievements earned", value: badges.filter(\.earned).count, detail: "\(badges.count - badges.filter(\.earned).count) more to discover", icon: "medal")
            }
            HStack(alignment: .top, spacing: 24) {
                ActivityCalendar(days: days, now: store.clock, selected: $selectedDay).frame(width: 340)
                VStack(alignment: .leading, spacing: 14) {
                    Text("Your courses").font(.system(size: 18, weight: .semibold))
                    ForEach(store.activeCourses) { course in courseRow(course) }
                    if store.activeCourses.isEmpty { Text("Your courses will appear here as you start learning.").font(.system(size: 13)).foregroundStyle(.secondary) }
                }.frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
    private var achievements: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack { Text("\(badges.filter(\.earned).count) earned · \(badges.count) to collect").font(.system(size: 18, weight: .semibold)); Spacer(); Text("Select any achievement to see its story.").font(.system(size: 12)).foregroundStyle(.secondary) }
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 210), spacing: 18)], spacing: 18) {
                ForEach(badges) { badge in Button { selectedBadge = badge } label: {
                    VStack(alignment: .leading, spacing: 16) { HStack { AchievementMedallion(badge: badge, size: 74); Spacer(); if store.data.preferences.featuredBadgeIDs?.contains(badge.id) == true { Image(systemName: "star.fill").font(.system(size: 11)).foregroundStyle(.orange) } }; Text(badge.title).font(.system(size: 16, weight: .semibold)); Text(badge.detail).font(.system(size: 12)).foregroundStyle(.secondary).lineLimit(3).frame(minHeight: 45, alignment: .top); HStack { Text(badge.earned ? "Earned" : "\(badge.progress) of \(badge.target)").font(.system(size: 11, weight: .medium)); Spacer(); if badge.earned { Text(badge.earnedAt?.formatted(.dateTime.month(.abbreviated).day()) ?? "").font(.system(size: 11)).foregroundStyle(.secondary) } }; AchievementProgress(badge: badge).opacity(badge.earned ? 0 : 1) }.padding(22).frame(maxWidth: .infinity, alignment: .leading).background(Palette.canvas, in: .rect(cornerRadius: 16)).contentShape(.rect(cornerRadius: 16))
                }.buttonStyle(OptionButtonStyle()).accessibilityElement(children: .ignore).accessibilityLabel(badge.title + ". " + badge.detail).accessibilityValue(badge.earned ? "Earned" : "\(badge.progress) of \(badge.target)").accessibilityAddTraits(.isButton) }
            }
        }
    }
    private func statistic(_ title: String, value: Int, detail: String, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 9) { Label(title, systemImage: icon).font(.system(size: 12)).foregroundStyle(.secondary); Text("\(value)").font(.system(size: 30, weight: .medium)).monospacedDigit(); Text(detail).font(.system(size: 11)).foregroundStyle(.secondary) }.frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 8)
    }
    private func courseRow(_ course: Course) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Button { withAnimation(reduceMotion ? nil : .easeOut(duration: 0.18)) { expandedCourse = expandedCourse == course.id ? nil : course.id } } label: {
                HStack(spacing: 12) { Circle().fill(CourseIdentity.color(course.id)).frame(width: 9, height: 9); Text(course.outline.title).font(.system(size: 14, weight: .medium)).lineLimit(2).multilineTextAlignment(.leading); Spacer(); Text("\(course.completedLessonIDs.count) / \(course.lessons.count)").font(.system(size: 12)).foregroundStyle(.secondary); Image(systemName: expandedCourse == course.id ? "chevron.up" : "chevron.down").font(.system(size: 10)).foregroundStyle(.secondary) }.padding(.vertical, 10).frame(maxWidth: .infinity).contentShape(.rect)
            }.buttonStyle(OptionButtonStyle()).accessibilityLabel(course.outline.title + ", show learning details")
            ProgressView(value: Double(course.completedLessonIDs.count), total: Double(max(1, course.lessons.count))).tint(CourseIdentity.color(course.id))
            if expandedCourse == course.id {
                let sessions = store.data.sessions.filter { $0.courseID == course.id }
                ForEach(["recall", "trace", "explain", "diagnose", "transfer"], id: \.self) { skill in
                    let attempts = sessions.flatMap { session in session.attempts.filter { attempt in attempt.independent && session.content.questions.first(where: { $0.id == attempt.questionID })?.skill == skill } }
                    HStack { Text(skill.capitalized).font(.system(size: 12)); Spacer(); Text(attempts.isEmpty ? "Not yet practiced" : "\(attempts.filter { $0.grade.correct }.count) correct of \(attempts.count) independent answers").font(.system(size: 11)).foregroundStyle(.secondary) }
                }
                Button("Open course") { store.openCourse(course.id) }.buttonStyle(QuietButton())
            }
        }.padding(20).background(Palette.canvas, in: .rect(cornerRadius: 14))
    }
}
struct ActivityCalendar: View {
    var days: [PracticeDay]
    var now: Date
    @Binding var selected: Date?
    private var calendar: Calendar { Calendar.current }
    private var end: Date { calendar.startOfDay(for: now) }
    private var start: Date { let weekday = (calendar.component(.weekday, from: end) + 5) % 7; return calendar.date(byAdding: .day, value: -77 - weekday, to: end)! }
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack { Text("Practice days").font(.system(size: 16, weight: .semibold)); Spacer(); Text(selected.map { date in date.formatted(.dateTime.month(.abbreviated).day()) + " · \(days.first { $0.date == date }?.count ?? 0) answers" } ?? "Last 12 weeks").font(.system(size: 11)).foregroundStyle(.secondary) }
            HStack(alignment: .top, spacing: 6) {
                VStack(spacing: 6) { ForEach(["M", "T", "W", "T", "F", "S", "S"].indices, id: \.self) { index in Text(["M", "T", "W", "T", "F", "S", "S"][index]).font(.system(size: 9)).foregroundStyle(.tertiary).frame(width: 15, height: 16) } }
                ForEach(0..<12, id: \.self) { week in VStack(spacing: 6) { ForEach(0..<7, id: \.self) { day in
                    let date = calendar.date(byAdding: .day, value: week * 7 + day, to: start)!
                    let count = days.first { $0.date == date }?.count ?? 0
                    Button { selected = date } label: { RoundedRectangle(cornerRadius: 3).fill(date > end ? .clear : count == 0 ? Palette.inputFill : Palette.accent.opacity(min(1, 0.25 + Double(count) / 20))).frame(width: 16, height: 16).overlay { if selected == date { RoundedRectangle(cornerRadius: 3).stroke(Palette.accent, lineWidth: 1.5) } }.contentShape(.rect) }.buttonStyle(.plain).disabled(date > end).help(date.formatted(.dateTime.month(.abbreviated).day()) + " · \(count) answers").accessibilityLabel(date.formatted(.dateTime.month(.abbreviated).day()) + ", \(count) practice answers")
                } } }
            }
            HStack { Text(start.formatted(.dateTime.month(.abbreviated).day())); Spacer(); Text(end.formatted(.dateTime.month(.abbreviated).day())) }.font(.system(size: 10)).foregroundStyle(.secondary)
        }.padding(22).background(Palette.canvas, in: .rect(cornerRadius: 16))
    }
}
