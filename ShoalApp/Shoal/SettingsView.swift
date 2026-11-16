import SwiftUI

struct SettingsView: View {
    @Environment(Store.self) private var store
    @State private var sees = false
    @State private var log = false
    @State private var restart = false
    @State private var careLock = false
    @State private var colors = false

    var body: some View {
        @Bindable var store = store
        Page {
            Text("Settings").font(.title()).foregroundStyle(Color.navy)
            HStack(spacing: 12) {
                Avatar(p: store.person("you"), size: 40)
                VStack(alignment: .leading, spacing: 2) {
                    Text("You").font(.system(size: 15.5, weight: .semibold)).foregroundStyle(Color.ink)
                    Text("Primary caregiver for \(LOVED)").font(.meta).foregroundStyle(Color.muted)
                }
            }
            .glassCard(padding: 14)

            SectionH(text: "My jar")
            toggleRow("Progress ring", store.ringOn ? "Shows how many of your tasks are done" : "Off · My jar asks how your week feels instead", $store.ringOn)
                .glassCard(padding: 14)

            SectionH(text: "\(LOVED)'s care")
            row("Care page lock", "PIN or Face ID · primary caregivers only") { careLock = true }
                .glassCard(padding: 14)

            SectionH(text: "Home kit")
            VStack(spacing: 0) {
                row("Home kit", store.kit == true ? "Jars, glow and night hours" : "Not set up · real jars and glowing stones") {
                    if store.kit == true { store.go(.kit) } else { store.kit = true; store.kitSetup = true }
                }
                Divider()
                row("Stone colors", store.colors.summary) { colors = true }
            }
            .glassCard(padding: 14)

            SectionH(text: "Outside the app")
            VStack(spacing: 0) {
                row("Someone needs help", "A sample in 5 seconds. Lock the phone to see it.") { sample("ask") }
                Divider()
                row("A task got done", "A sample in 5 seconds, with Say thanks") { sample("done") }
            }
            .glassCard(padding: 14)

            SectionH(text: "Pebble")
            VStack(spacing: 0) {
                toggleRow("Pebble suggestions", store.pebbleOn ? "Suggests a fair split, notices what's slipping, writes asks" : "Off · you set things up by hand", $store.pebbleOn)
                    .padding(.bottom, 10)
                Divider()
                row("What Pebble can see", "Answers, goals and what you tell it. No medical advice.") { sees = true }
                if store.pebbleOn {
                    Divider()
                    row("What Pebble did", store.pebbleLog.isEmpty ? "Nothing yet · every change shows here" : "\(plural(store.pebbleLog.count, "change")) · undo anything") { log = true }
                }
            }
            .glassCard(padding: 14)

            Button("Restart prototype") { restart = true }
                .font(.system(size: 15, weight: .semibold)).frame(maxWidth: .infinity).padding(.top, 18)
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
                Text(t).font(.system(size: 15.5, weight: .semibold)).foregroundStyle(Color.ink)
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
                    Text(t).font(.system(size: 15.5, weight: .semibold)).foregroundStyle(Color.ink)
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
