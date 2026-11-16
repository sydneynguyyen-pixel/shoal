import SwiftUI

@main
struct ShoalApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @Environment(\.scenePhase) private var phase
    var body: some Scene {
        WindowGroup {
            RootView().environment(delegate.store).tint(.shoalBlue)
                .onOpenURL { open($0) }
                .task { delegate.store.syncWidgets(); delegate.store.startSeededActivity() }
                .onChange(of: phase) { if phase == .background { delegate.store.syncWidgets() } }
                .onChange(of: delegate.store.tasks) { delegate.store.syncWidgets() }
        }
    }

    // Widgets and the Live Activity link here: shoal://care, shoal://myjar, shoal://task/<id>
    private func open(_ url: URL) {
        let s = delegate.store
        s.onboarded = true
        switch url.host() {
        case "care": s.tab = 0; s.paths[0] = [.care(nurse: false)]
        case "myjar": s.tab = 1; s.paths[1] = []
        case "task": s.tab = 1; s.paths[1] = [.task(url.lastPathComponent)]
        default: s.tab = 0
        }
    }
}

struct RootView: View {
    @Environment(Store.self) private var store

    var body: some View {
        if store.onboarded { tabs.transition(.opacity) } else { FirstOpenView().transition(.opacity) }
    }

    private var tabs: some View {
        @Bindable var store = store
        return TabView(selection: $store.tab) {
            Tab("Home", image: "tab-home", value: 0) { stack(0) { HomeView() } }
            Tab("My jar", image: "tab-jar", value: 1) { stack(1) { MyJarView() } }
            Tab("People", image: "tab-people", value: 2) { stack(2) { PeopleView() } }
            if store.pebbleOn {
                Tab("Pebble", image: "tab-pebble", value: 3) { stack(3) { PebbleView() } }
            }
            Tab("Settings", image: "tab-settings", value: 4) { stack(4) { SettingsView() } }
        }
        .overlay(alignment: .top) {
            if let t = store.toast { ToastView(text: t).padding(.top, 4) }
        }
        .fullScreenCover(isPresented: $store.kitSetup) { KitSetupView() }
    }

    private func stack<V: View>(_ i: Int, @ViewBuilder _ root: () -> V) -> some View {
        @Bindable var store = store
        return NavigationStack(path: $store.paths[i]) {
            root().navigationDestination(for: Route.self) { r in
                switch r {
                case .task(let id): TaskView(id: id)
                case .handoff(let id, let step): HandoffView(id: id, step: step)
                case .person(let id): PersonView(id: id)
                case .newTask: NewTaskView()
                case .care(let nurse): CareView(nurse: nurse)
                case .kit: KitView()
                case .stones: StonesView()
                case .stone(let id): StoneDetailView(id: id)
                case .month: MonthView()
                case .setup(let id): SetupStepView(id: id)
                }
            }
        }
    }
}

// A scrolling page on the app's soft background.
struct Page<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) { content }
                .padding(.horizontal, 20).padding(.top, 4).padding(.bottom, 40)
        }
        .scrollIndicators(.hidden)
        .background(AppBackground())
    }
}

// One task in a list: its stone, name and who/when.
// The thin line between rows, as on the web.
struct RowSep: View {
    var body: some View { Rectangle().fill(Color(hex: 0xe3e1dc, 0.8)).frame(height: 1) }
}

struct TaskLine: View {
    @Environment(Store.self) private var store
    var t: CareTask
    var showWho = true
    var meta: String? = nil
    var action: (() -> Void)? = nil   // replaces opening the task, e.g. to pair it

    var body: some View {
        Button { if let action { action() } else { store.go(.task(t.id)) } } label: {
            HStack(spacing: 12) {
                t.stone(base: 28).frame(width: 40)
                VStack(alignment: .leading, spacing: 2) {
                    Text(t.n).font(.app(15, .semibold)).foregroundStyle(t.done ? Color.muted : Color.ink)
                        .strikethrough(t.done, color: .muted).multilineTextAlignment(.leading)
                    HStack(spacing: 5) {
                        if showWho, let p = store.person(t.who) { Avatar(p: p, size: 16) }
                        Text(meta ?? line).font(.meta).foregroundStyle(t.urgent ? Color.amber : Color.muted)
                    }
                }
                Spacer(minLength: 4)
                if t.handoff?.pending == true {
                    Text("Asked").font(.app(12, .semibold)).foregroundStyle(Color.shoalBlue)
                        .padding(.horizontal, 8).padding(.vertical, 3).background(Color.blueTint, in: .capsule)
                }
            }
            .padding(.vertical, 11).frame(minHeight: 60).contentShape(.rect)
        }
        .buttonStyle(Pressable())
        .accessibilityElement(children: .combine)
    }

    private var line: String {
        var s = showWho ? (t.who == nil ? "Unassigned · " : "\(store.name(t.who)) · ") : ""
        s += t.done ? (t.doneAt ?? "Done") : t.dueLabel
        if t.remote { s += " · remote" }
        return s
    }
}
