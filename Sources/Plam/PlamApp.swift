import SwiftUI

@main struct PlamApp: App {
    @State private var store = AppStore()
    @NSApplicationDelegateAdaptor(PlamLifecycle.self) private var lifecycle
    var body: some Scene {
        Window("Plam", id: "main") {
            RootView().environment(store).tint(Palette.accent).onAppear { lifecycle.store = store; DailyReminder.shared.configure(store) }
                .preferredColorScheme(store.data.preferences.appearance == "system" ? nil : (store.data.preferences.appearance == "dark" ? .dark : .light))
                .frame(minWidth: 960, minHeight: 680)
        }
        .defaultSize(width: 1260, height: 840)
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandGroup(after: .newItem) {
                Button("New course") { store.showingNewCourse = true }.keyboardShortcut("n", modifiers: [.command, .shift])
                Button("New note") { store.newNote() }.keyboardShortcut("n")
            }
            CommandMenu("Learn") {
                Button("Search and commands…") { store.showingCommands = true }.keyboardShortcut("k")
                Button("Keyboard shortcuts…") { store.showingShortcuts = true }
                if store.isUITesting { Button("Control gallery…") { store.showingGallery = true } }
                Divider()
                Button("Today") { store.navigate(.today) }.keyboardShortcut("1")
                Button("Courses") { store.navigate(.courses) }.keyboardShortcut("2")
                Button("Review") { store.navigate(.review) }.keyboardShortcut("3")
                Button("Notebook") { store.navigate(.notebook) }.keyboardShortcut("4")
                Button("Repositories") { store.navigate(.repositories) }.keyboardShortcut("5")
                Button("Progress") { store.navigate(.progress) }.keyboardShortcut("6")
                Divider()
                Button("Back") { store.moveInHistory(-1) }.keyboardShortcut("[", modifiers: [.command, .option]).disabled(store.navigationIndex <= 0)
                Button("Forward") { store.moveInHistory(1) }.keyboardShortcut("]", modifiers: [.command, .option]).disabled(store.navigationIndex + 1 >= store.navigationHistory.count)
                Button("Toggle sidebar") { store.sidebarVisible.toggle() }.keyboardShortcut("s", modifiers: [.command, .control])
            }
        }
        Settings { SettingsView().environment(store).tint(Palette.accent).preferredColorScheme(store.appearance).frame(width: 820, height: 650) }
    }
}

struct RootView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.scenePhase) private var phase
    var body: some View {
        @Bindable var store = store
        Group {
            if store.data.preferences.onboardingComplete { WorkspaceView() } else { WelcomeView() }
        }
        .environment(\.studyReadingScale, CGFloat((store.data.preferences.readingSize ?? 15) / 15))
        .background(Palette.background)
        .alert("Something needs attention", isPresented: Binding(get: { store.error != nil && !store.showingNewCourse }, set: { if !$0 { store.error = nil } })) {
            Button("OK") { store.error = nil }
        } message: { Text(store.error ?? "") }
        .sheet(isPresented: $store.showingGallery) { ControlGallery() }
        .sheet(isPresented: $store.showingCommands) { CommandSearch().environment(store) }
        .sheet(isPresented: $store.showingShortcuts) { ShortcutGuide() }
        .sheet(isPresented: $store.showingNewCourse) { NewCourseView().environment(store) }
        .onReceive(Timer.publish(every: 30, on: .main, in: .common).autoconnect()) { store.clock = $0 }
        .onChange(of: phase) { if phase == .active { Task { await store.checkRepositories() } } }
        .task { while !Task.isCancelled { if phase == .active { await store.checkRepositories() }; try? await Task.sleep(for: .seconds(60)) } }
    }
}

struct WorkspaceView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private var routeID: String { store.activeSessionID?.uuidString ?? store.selectedCourseID?.uuidString ?? store.destination.rawValue }
    var body: some View {
        HStack(spacing: 0) {
            if store.sidebarVisible { SidebarView().frame(width: 190) }
            VStack(spacing: 0) {
                HStack(spacing: 4) {
                    Button { store.sidebarVisible.toggle() } label: { Image(systemName: "sidebar.left") }.buttonStyle(IconButton()).help("Toggle sidebar").accessibilityLabel("Toggle sidebar")
                    Button { store.moveInHistory(-1) } label: { Image(systemName: "chevron.left") }.buttonStyle(IconButton()).disabled(store.navigationIndex <= 0).help("Back").accessibilityLabel("Back")
                    Button { store.moveInHistory(1) } label: { Image(systemName: "chevron.right") }.buttonStyle(IconButton()).disabled(store.navigationIndex + 1 >= store.navigationHistory.count).help("Forward").accessibilityLabel("Forward")
                    Spacer()
                    Button { store.showingCommands = true } label: { Image(systemName: "magnifyingglass") }.buttonStyle(IconButton()).help("Search and commands · ⌘K").accessibilityLabel("Search and commands")
                }.padding(.horizontal, 20).frame(height: 48)
                ZStack(alignment: .top) {
                Group {
                if let session = store.activeSession { LessonView(sessionID: session.id).id(session.id) }
                else {
                    switch store.destination {
                    case .today: TodayView()
                    case .courses: if let course = store.selectedCourse { CourseDetailView(courseID: course.id) } else { CoursesView() }
                    case .repositories: RepositoriesView()
                    case .notebook: NotebookView()
                    case .review: ReviewView()
                    case .progress: TrackerView()
                    }
                }
                }
                }.frame(maxWidth: .infinity, maxHeight: .infinity)
                if let busy = store.busy, !store.isEvaluating {
                    HStack(spacing: 12) { ProgressView().controlSize(.small); Text(busy).font(.system(size: 12)); Spacer(); Button("Cancel") { store.cancelWork() }.buttonStyle(TextActionStyle()).foregroundStyle(.secondary) }
                        .padding(14).background(Palette.soft)
                } else if let notice = store.notice {
                    HStack { Image(systemName: "checkmark.circle"); Text(notice).font(.system(size: 12)); Spacer(); Button { store.notice = nil } label: { Image(systemName: "xmark") }.buttonStyle(TextActionStyle()) }.padding(14).foregroundStyle(Palette.accent).background(Palette.soft).task(id: notice) { do { try await Task.sleep(for: .seconds(8)); if store.notice == notice { store.notice = nil } } catch {} }
                }
            }
        }.onChange(of: store.location, initial: true) { store.recordLocation() }
    }
}

struct SidebarView: View {
    @Environment(AppStore.self) private var store
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) { Image(systemName: "leaf.fill").foregroundStyle(Palette.accent); Text("Plam").font(.system(size: 17, weight: .semibold)) }.padding(.top, 40).padding(.bottom, 24).padding(.horizontal, 22)
            ForEach(Destination.allCases) { route in
                Button { store.navigate(route) } label: {
                    HStack(spacing: 12) {
                        Image(systemName: route.icon).font(.system(size: 15)).frame(width: 20)
                        Text(route.rawValue).font(.system(size: 13, weight: store.destination == route ? .semibold : .regular))
                        Spacer()

                    }.foregroundStyle(store.destination == route ? .primary : .secondary).padding(.horizontal, 14).frame(maxWidth: .infinity, minHeight: 40).contentShape(.rect(cornerRadius: 8))
                        .background(store.destination == route ? Palette.selection : .clear, in: .rect(cornerRadius: 9))
                }.buttonStyle(OptionButtonStyle()).padding(.horizontal, 12).padding(.vertical, 2)
            }
            Spacer()
            SettingsLink { Label("Settings", systemImage: "gearshape").font(.system(size: 13)).frame(maxWidth: .infinity, alignment: .leading).padding(12).contentShape(.rect(cornerRadius: 8)) }.buttonStyle(OptionButtonStyle()).padding(12).help("Settings · ⌘,")
        }.background(Palette.background)
    }
}

@MainActor final class PlamLifecycle: NSObject, NSApplicationDelegate {
    weak var store: AppStore?
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard let store else { return .terminateNow }
        store.cancelWork(); store.tutorTask?.cancel(); store.save()
        Task { await store.runtime.stop(); sender.reply(toApplicationShouldTerminate: true) }
        return .terminateLater
    }
}
