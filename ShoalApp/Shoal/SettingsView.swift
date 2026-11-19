import SwiftUI

struct SettingsView: View {
    @Environment(Store.self) private var store
    @State private var sees = false
    @State private var log = false
    @State private var restart = false
    @State private var careLock = false
    @State private var colors = false
    @State private var redo = false
    @State private var signOut = false

    var body: some View {
        @Bindable var store = store
        List {
            Section {
                HStack(spacing: 12) {
                    Avatar(p: store.person("you"), size: 36)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(store.person("you")?.name ?? "You").font(.app(16, .semibold)).foregroundStyle(Color.ink)
                        Text(store.phone.isEmpty ? "Signed in with your phone" : "+1 \(fmtPhone(store.phone))").font(.meta).foregroundStyle(Color.muted)
                    }
                }
            }
            Section("Family") {
                row("Care page lock", "PIN or Face ID") { careLock = true }
                row("Family setup", "Redo with Pebble or by hand") { redo = true }
            }
            Section("Notifications") {
                row("Someone needs help", "Sample in 5 seconds") { sample("ask") }
                row("A task got done", "Sample in 5 seconds") { sample("done") }
            }
            Section("My jar") {
                toggleRow("Progress ring", store.ringOn ? "Shows how many tasks are done" : "Asks how your week feels instead", $store.ringOn)
            }
            Section("Stones") {
                row("Stone colors", store.colors.summary) { colors = true }
                row("Home kit", store.kit == true ? "Jars, stones, glow and battery" : "Not set up") {
                    if store.kit == true { store.go(.kit) } else { store.kit = true; store.kitSetup = true }
                }
            }
            Section("Pebble") {
                toggleRow("Pebble suggestions", store.pebbleOn ? "On" : "Off · you set things up by hand", $store.pebbleOn)
                row("What Pebble can see", "No medical advice") { sees = true }
                if store.pebbleOn {
                    row("What Pebble did", store.pebbleLog.isEmpty ? "Nothing yet" : plural(store.pebbleLog.count, "change")) { log = true }
                }
            }
            Section("Account") {
                Button("Sign out", role: .destructive) { signOut = true }.font(.app(16))
            }
            Section {
                Picker("Account", selection: Binding(get: { store.sample }, set: { store.useAccount(sample: $0) })) {
                    Text("New account").tag(false)
                    Text("Full family").tag(true)
                }
                .pickerStyle(.segmented)
                .listRowBackground(Color.clear).listRowInsets(.init())
                Button("Restart prototype") { restart = true }.font(.app(16))
            } header: { Text("Testing") } footer: {
                Text(store.sample ? "Months of tasks, five people and paired stones" : "Just finished onboarding, nothing added yet")
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(AppBackground())
        .navigationTitle("Settings")
        .onChange(of: store.pebbleOn) { if !store.pebbleOn && store.tab == 3 { store.tab = 4 } }
        .sheet(isPresented: $sees) { SeesView().presentationDetents([.medium]) }
        .sheet(isPresented: $careLock) { CareLockSheet() }
        .sheet(isPresented: $colors) { ColorsSheet() }
        .sheet(isPresented: $log) { LogView().presentationDetents([.medium]) }
        .confirmationDialog("Start the demo over?", isPresented: $restart, titleVisibility: .visible) {
            Button("Restart", role: .destructive) { store.reset(); store.say("Back to the start") }
            Button("Cancel", role: .cancel) {}
        } message: { Text("The family and tasks go back to how they began.") }
        .confirmationDialog("Redo family setup?", isPresented: $redo, titleVisibility: .visible) {
            Button("Start over", role: .destructive) { store.reset() }
            Button("Keep it", role: .cancel) {}
        } message: { Text("You'll go back through onboarding. This prototype starts fresh.") }
        .confirmationDialog("Sign out?", isPresented: $signOut, titleVisibility: .visible) {
            Button("Sign out", role: .destructive) { store.reset(); store.first = .signin }
            Button("Stay signed in", role: .cancel) {}
        } message: { Text("You'll go back to the sign-in screen. In this prototype, signing out also clears what you set up.") }
    }

    private func sample(_ kind: String) {
        Task {
            if await Notify.send(kind, store: store) { store.say("Coming in 5 seconds") }
            else { store.say("Turn on notifications for Shoal in Settings") }
        }
    }

    private func toggleRow(_ t: String, _ d: String, _ b: Binding<Bool>) -> some View {
        Toggle(isOn: b.animation(.snappy)) {
            VStack(alignment: .leading, spacing: 2) {
                Text(t).font(.app(16)).foregroundStyle(Color.ink)
                Text(d).font(.meta).foregroundStyle(Color.muted)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(.rect)
            .onTapGesture { withAnimation(.snappy) { b.wrappedValue.toggle() } }
        }
    }

    private func row(_ t: String, _ d: String, _ a: @escaping () -> Void) -> some View {
        Button(action: a) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(t).font(.app(16)).foregroundStyle(Color.ink)
                    Text(d).font(.meta).foregroundStyle(Color.muted).multilineTextAlignment(.leading)
                }
                Spacer()
                Chevron()
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }
}
