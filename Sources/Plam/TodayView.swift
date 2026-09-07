import SwiftUI
import PlamCore

struct TodayView: View {
    @Environment(AppStore.self) private var store
    @State private var reminders = false
    @State private var cards: CardReviewRequest?
    private var plan: DailyPlan { DailyPlan(store.data, now: store.clock) }
    var body: some View {
        let day = plan
        ScrollView {
            VStack(alignment: .leading, spacing: 30) {
                HStack {
                    PageHeading(eyebrow: "", title: "Today", subtitle: store.clock.formatted(.dateTime.weekday(.wide).month(.wide).day()))
                    Button { reminders = true } label: { Label(store.data.preferences.reminderEnabled == true ? "Reminder on" : "Set a reminder", systemImage: "bell") }.buttonStyle(QuietButton())
                }
                HStack(alignment: .center, spacing: 32) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(day.minutes >= store.data.preferences.dailyMinutes ? "You made time to learn." : "A little progress, every day.").font(.system(size: 25, weight: .semibold)).tracking(-0.5)
                        Text(day.minutes >= store.data.preferences.dailyMinutes ? "Your daily intention is complete. Continue if you feel like it." : "Choose one next step. You don’t need to work on every course today.").font(.system(size: 13)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                        weekStrip
                    }.frame(maxWidth: .infinity, alignment: .leading)
                    VStack(alignment: .trailing, spacing: 8) {
                        HStack(alignment: .firstTextBaseline, spacing: 4) { Text("\(day.minutes)").font(.system(size: 35, weight: .medium)); Text("/ \(store.data.preferences.dailyMinutes) min").font(.system(size: 12)).foregroundStyle(.secondary) }
                        ProgressView(value: Double(min(day.minutes, store.data.preferences.dailyMinutes)), total: Double(max(1, store.data.preferences.dailyMinutes))).tint(Palette.accent).frame(width: 150)
                        Text("Focused lesson time").font(.system(size: 10)).foregroundStyle(.secondary)
                    }
                }.padding(24).background(Palette.canvas, in: .rect(cornerRadius: 18))
                if day.answers > 0 || day.topics > 0 {
                    HStack(spacing: 24) { Label("\(day.answers) practice \(day.answers == 1 ? "answer" : "answers") today", systemImage: "checkmark.circle"); if day.topics > 0 { Label("\(day.topics) \(day.topics == 1 ? "topic" : "topics") completed", systemImage: "checkmark.seal") } }.font(.system(size: 12)).foregroundStyle(.secondary)
                }
                if let next = day.courses.first, next.priority < 3 {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("SUGGESTED NEXT").font(.system(size: 10, weight: .semibold)).tracking(1.3).foregroundStyle(.secondary)
                        HStack(alignment: .center, spacing: 24) {
                            VStack(alignment: .leading, spacing: 7) {
                                Text(title(next)).font(.system(size: 21, weight: .semibold)).fixedSize(horizontal: false, vertical: true)
                                Text(next.course.outline.title + " · " + reason(next)).font(.system(size: 12)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                            }.frame(maxWidth: .infinity, alignment: .leading)
                            Button(actionLabel(next)) { act(next) }.buttonStyle(PrimaryButton()).disabled(store.busy != nil)
                        }
                    }.padding(.vertical, 4)
                }
                VStack(alignment: .leading, spacing: 12) {
                    HStack { Text("Your courses").font(.system(size: 17, weight: .semibold)); Text("\(day.courses.count)").font(.system(size: 12)).foregroundStyle(.tertiary); Spacer(); Button { store.showingNewCourse = true } label: { Label("New course", systemImage: "plus") }.buttonStyle(QuietButton()) }
                    if day.courses.isEmpty { EmptyState(icon: "square.stack", title: "What would you like to understand?", subtitle: "Start a course from a concept, a question, or your code.", actionTitle: "Create a course", action: { store.showingNewCourse = true }) }
                    ForEach(day.courses) { item in courseRow(item) }
                }
                if !day.personalCards.isEmpty {
                    Button { cards = .init(ids: day.personalCards.map(\.id)) } label: { HStack { Label("\(day.personalCards.count) personal flashcards ready", systemImage: "rectangle.on.rectangle"); Spacer(); Text("Practice"); Image(systemName: "arrow.right") }.font(.system(size: 13)).padding(16).contentShape(.rect) }.buttonStyle(OptionButtonStyle())
                }
            }.frame(maxWidth: 1000, alignment: .leading).padding(32).frame(maxWidth: .infinity, alignment: .top)
        }.sheet(isPresented: $reminders) { DailyReminderSheet() }.sheet(item: $cards) { FlashcardReviewView(ids: $0.ids) }
    }
    private var weekStrip: some View {
        let calendar = Calendar.current
        let practiced = Set(LearningProgress.practiceDays(store.data, now: store.clock).map(\.date))
        return HStack(spacing: 8) {
            ForEach(-6...0, id: \.self) { offset in
                let date = calendar.date(byAdding: .day, value: offset, to: calendar.startOfDay(for: store.clock))!
                let done = practiced.contains(date)
                VStack(spacing: 5) {
                    ZStack { Circle().fill(done ? Palette.accent : Palette.selection); if done { Image(systemName: "checkmark").font(.system(size: 9, weight: .semibold)).foregroundStyle(.white) } else if offset == 0 { Circle().stroke(Palette.accent.opacity(0.7), lineWidth: 1) } }.frame(width: 22, height: 22)
                    Text(date.formatted(.dateTime.weekday(.narrow))).font(.system(size: 9)).foregroundStyle(.secondary)
                }.accessibilityElement(children: .ignore).accessibilityLabel(date.formatted(.dateTime.weekday(.wide)) + (done ? ", practiced" : ", no practice recorded"))
            }
            if store.data.preferences.showStreak != false { Text("\(LearningProgress.streak(store.data, now: store.clock)) day streak").font(.system(size: 11)).foregroundStyle(.secondary).padding(.leading, 6) }
        }.padding(.top, 6)
    }
    private func courseRow(_ item: CourseDayPlan) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Button { store.openCourse(item.id) } label: {
                HStack(spacing: 13) {
                    RoundedRectangle(cornerRadius: 2).fill(CourseIdentity.color(item.id)).frame(width: 4, height: 34)
                    VStack(alignment: .leading, spacing: 5) { Text(item.course.outline.title).font(.system(size: 14, weight: .medium)); Text(title(item)).font(.system(size: 12)).foregroundStyle(.secondary).lineLimit(2) }
                    Spacer(); Text("\(Set(item.course.completedLessonIDs).count) / \(item.course.lessons.count)").font(.system(size: 11)).monospacedDigit().foregroundStyle(.secondary); Image(systemName: "chevron.right").font(.system(size: 10)).foregroundStyle(.tertiary)
                }.padding(12).frame(maxWidth: .infinity, alignment: .leading).contentShape(.rect(cornerRadius: 8))
            }.buttonStyle(OptionButtonStyle())
            HStack(spacing: 12) {
                Text(item.lastPractice.map { "Practiced " + $0.formatted(.relative(presentation: .named)) } ?? (item.resume != nil ? "Lesson in progress" : "Ready when you are")).font(.system(size: 11)).foregroundStyle(.secondary)
                Spacer()
                if !item.cards.isEmpty { Button("\(item.cards.count) \(item.cards.count == 1 ? "card" : "cards") due") { cards = .init(ids: item.cards.map(\.id)) }.buttonStyle(TextActionStyle()) }
                if !item.reviews.isEmpty { Button("\(item.reviews.count) \(item.reviews.count == 1 ? "topic" : "topics") due") { review(item) }.buttonStyle(TextActionStyle()) }
                Button(actionLabel(item)) { act(item) }.buttonStyle(QuietButton()).disabled(store.busy != nil)
            }.font(.system(size: 11)).padding(.leading, 29).padding(.trailing, 12).padding(.bottom, 12)
        }
    }
    private func title(_ item: CourseDayPlan) -> String { item.resume?.content.title ?? item.reviews.first?.title ?? (!item.cards.isEmpty ? "Refresh what you’ve learned" : item.next?.title ?? (item.course.isComplete ? "Course complete · revisit any topic" : "Explore your learning path")) }
    private func reason(_ item: CourseDayPlan) -> String { item.resume != nil ? "Pick up where you left off" : !item.reviews.isEmpty || !item.cards.isEmpty ? "Ready for a memory refresh" : "\(item.next?.minutes ?? 15) min · build on what you know" }
    private func actionLabel(_ item: CourseDayPlan) -> String { item.resume != nil ? "Resume lesson" : !item.reviews.isEmpty ? "Review topic" : !item.cards.isEmpty ? "Practice cards" : item.next != nil ? "Start lesson" : "Open course" }
    private func review(_ item: CourseDayPlan) { if let review = item.reviews.first { store.selectedCourseID = item.id; store.destination = .courses; store.reviewSaved(review) } }
    private func act(_ item: CourseDayPlan) {
        if let session = item.resume { store.destination = .courses; store.selectedCourseID = item.id; store.activeSessionID = session.id }
        else if !item.reviews.isEmpty { review(item) }
        else if !item.cards.isEmpty { cards = .init(ids: item.cards.map(\.id)) }
        else if let lesson = item.next { store.startLesson(course: item.course, lesson: lesson) }
        else { store.openCourse(item.id) }
    }
}
