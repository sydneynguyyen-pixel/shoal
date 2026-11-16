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
        Page {
            Text("Settings").font(.title()).foregroundStyle(Color.navy)
            HStack(spacing: 12) {
                Avatar(p: store.person("you"), size: 36)
                VStack(alignment: .leading, spacing: 2) {
                    Text(store.person("you")?.name ?? "You").font(.app(15.5, .semibold)).foregroundStyle(Color.ink)
                    Text(store.phone.isEmpty ? "Signed in with your phone" : "Signed in as +1 \(fmtPhone(store.phone))").font(.meta).foregroundStyle(Color.muted)
                }
                Spacer()
            }
            .glassCard(padding: 14)

            SectionH(text: "Family")
            VStack(spacing: 0) {
                row("Care page lock", "PIN or Face ID · primary caregivers only") { careLock = true }
                RowSep()
                row("Family setup", "Redo with Pebble or by hand") { redo = true }
            }
            .glassCard(padding: 14)

            SectionH(text: "Notifications")
            VStack(spacing: 0) {
                row("Someone needs help", "A sample in 5 seconds. Lock the phone to see it.") { sample("ask") }
                RowSep()
                row("A task got done", "A sample in 5 seconds, with Say thanks") { sample("done") }
            }
            .glassCard(padding: 14)

            SectionH(text: "My jar")
            toggleRow("Progress ring", store.ringOn ? "Shows how many of your tasks are done" : "Off · My jar asks how your week feels instead", $store.ringOn)
                .glassCard(padding: 14)

            SectionH(text: "Stones")
            VStack(spacing: 0) {
                row("Stone colors", store.colors.summary) { colors = true }
                RowSep()
                row("Home kit", store.kit == true ? "Jars, stones, glow and battery" : "Not using one · add real jars and glowing stones") {
                    if store.kit == true { store.go(.kit) } else { store.kit = true; store.kitSetup = true }
                }
            }
            .glassCard(padding: 14)

            SectionH(text: "Pebble")
            VStack(spacing: 0) {
                toggleRow("Pebble suggestions", store.pebbleOn ? "Suggests tasks and a fair split, notices what's slipping, drafts asks" : "Off · you set things up by hand", $store.pebbleOn)
                    .padding(.bottom, 10)
                RowSep()
                row("What Pebble can see", "Answers, goals and what you tell it. No medical advice.") { sees = true }
                if store.pebbleOn {
                    RowSep()
                    row("What Pebble did", store.pebbleLog.isEmpty ? "Nothing yet · every change shows here" : "\(plural(store.pebbleLog.count, "change")) · undo anything") { log = true }
                }
            }
            .glassCard(padding: 14)

            SectionH(text: "Account")
            row("Sign out", "Back to the sign-in screen") { signOut = true }
                .glassCard(padding: 14)

            SectionH(text: "Prototype")
            VStack(alignment: .leading, spacing: 8) {
                Picker("Account", selection: Binding(get: { store.sample }, set: { store.useAccount(sample: $0) })) {
                    Text("New account").tag(false)
                    Text("Full family").tag(true)
                }
                .pickerStyle(.segmented)
                Text(store.sample ? "Months of tasks, five people and paired stones" : "Just finished onboarding, nothing added yet")
                    .font(.meta).foregroundStyle(Color.muted)
            }
            .glassCard(padding: 14)

            Button("Restart prototype") { restart = true }
                .font(.app(15, .semibold)).frame(maxWidth: .infinity).padding(.top, 18)
        }
        .toolbar(.hidden, for: .navigationBar)
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
                Text(t).font(.app(15.5, .semibold)).foregroundStyle(Color.ink)
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
                    Text(t).font(.app(15.5, .semibold)).foregroundStyle(Color.ink)
                    Text(d).font(.meta).foregroundStyle(Color.muted).multilineTextAlignment(.leading)
                }
                Spacer()
                Chevron()
            }
            .padding(.vertical, 10)
        }
        .buttonStyle(Pressable())
    }
}
