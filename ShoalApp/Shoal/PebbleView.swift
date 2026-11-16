import SwiftUI

struct PebbleView: View {
    @Environment(Store.self) private var store
    @State private var talk = false
    @State private var costs = false
    @State private var log = false
    @State private var sees = false

    var body: some View {
        let open = store.active.first { $0.who == nil }
        Page {
            VStack(spacing: 10) {
                ZStack {
                    Circle().fill(RadialGradient(colors: [Color(hex: 0x8cc4f6, 0.35), .clear], center: .center, startRadius: 0, endRadius: 130))
                        .frame(width: 260, height: 260)
                    Image("pebble_base_front").resizable().scaledToFit().frame(width: 150, height: 150)
                }
                .frame(height: 200)
                Text("Hi, I'm Pebble").font(.title()).foregroundStyle(Color.navy)
                Text("Tell me what's going on. I'll sort it into tasks.").font(.body15).foregroundStyle(Color.muted).multilineTextAlignment(.center)
                Button("Talk it through") { talk = true }.buttonStyle(PrimaryButton()).padding(.top, 6)
            }
            .frame(maxWidth: .infinity)

            PebbleHomeCard().padding(.top, 6)

            LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                tile("pebble_offer_open_hands", "Find someone", open?.n ?? "Nothing open") {
                    if let open { store.pebbleHandoff(open.id) } else { store.say("Every task has someone. Nothing to ask for.") }
                }
                tile("pebble_research_glasses_focused", "Help with costs", "\(PROGRAMS.count) programs") { costs = true }
                tile("pebble_carry_03", "What I did", store.pebbleLog.isEmpty ? "Nothing yet" : "\(plural(store.pebbleLog.count, "change")) · undo any") { log = true }
                tile("pebble_peer_down", "What I can see", "Answers and goals, never the care page") { sees = true }
            }
            .padding(.top, 6)
        }
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $talk) { TalkView() }
        .sheet(isPresented: $costs) { CostsView() }
        .sheet(isPresented: $log) { LogView().presentationDetents([.medium]) }
        .sheet(isPresented: $sees) { SeesView().presentationDetents([.medium]) }
    }

    private func tile(_ img: String, _ lab: String, _ note: String, _ a: @escaping () -> Void) -> some View {
        Button(action: a) {
            VStack(alignment: .leading, spacing: 6) {
                Image(img).resizable().scaledToFit().frame(width: 44, height: 44)
                Text(lab).font(.system(size: 15, weight: .semibold)).foregroundStyle(Color.ink)
                Text(note).font(.system(size: 12)).foregroundStyle(Color.muted).lineLimit(2).multilineTextAlignment(.leading)
                Spacer(minLength: 0)
            }
            .frame(height: 120, alignment: .topLeading)
            .glassCard(radius: 26, padding: 14)
        }
        .buttonStyle(Pressable())
    }
}

// MARK: - Costs

struct Program: Identifiable { let id: String; let n: String; let d: String; let src: String }
let PROGRAMS = [
    Program(id: "ihss", n: "In-Home Supportive Services (IHSS)", d: "Pays for help at home for people on Medi-Cal. A family member can sometimes be the paid helper.", src: "cdss.ca.gov"),
    Program(id: "pfl", n: "California Paid Family Leave", d: "Partial pay for up to 8 weeks while you care for a seriously ill family member.", src: "edd.ca.gov"),
    Program(id: "fcsp", n: "Family Caregiver Support Program", d: "Respite care, counseling and training through your local Area Agency on Aging.", src: "aging.ca.gov"),
]

struct CostsView: View {
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var saved: Set<String> = []
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Image("pebble_research_glasses_focused").resizable().scaledToFit().frame(width: 64, height: 64)
                    Text("Help with costs").font(.title(28)).foregroundStyle(Color.navy)
                    Text("Programs a family caring at home in California may qualify for. Check each one at its source.").font(.body15).foregroundStyle(Color.muted)
                    ForEach(PROGRAMS) { p in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(p.n).font(.system(size: 15.5, weight: .semibold)).foregroundStyle(Color.ink)
                            Text(p.d).font(.system(size: 14)).foregroundStyle(Color.muted)
                            HStack {
                                Text(p.src).font(.system(size: 12, weight: .medium)).foregroundStyle(Color.pearlInk)
                                Spacer()
                                Button(saved.contains(p.id) ? "Added to your jar" : "Look into it") {
                                    guard !saved.contains(p.id) else { return }
                                    saved.insert(p.id)
                                    let id = "c\(UUID().uuidString.prefix(6))"
                                    store.tasks.append(CareTask(id: id, n: "Look into \(p.n)", who: "you", w: .small, cat: "paper", kind: .once, date: addDays(7)))
                                    store.pebbleDid("Added “Look into \(p.n)” to your jar", how: "From Help with costs · you said yes", undo: .task(id))
                                }
                                .font(.system(size: 14, weight: .semibold)).disabled(saved.contains(p.id))
                            }
                        }
                        .pearl(radius: 18, padding: 14)
                    }
                    Text("Sample programs. Pebble doesn't give legal or financial advice.").font(.system(size: 12)).foregroundStyle(Color.muted)
                }
                .padding(20)
            }
            .background(AppBackground())
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
    }
}

struct LogView: View {
    @Environment(Store.self) private var store
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text("What Pebble did").font(.title(26)).foregroundStyle(Color.navy)
                if store.pebbleLog.isEmpty {
                    Text("Nothing yet. Every change Pebble makes shows here, and you can undo it.").font(.body15).foregroundStyle(Color.muted)
                }
                ForEach(store.pebbleLog) { e in
                    HStack(spacing: 10) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(e.what).font(.system(size: 14.5, weight: .semibold)).foregroundStyle(Color.ink).strikethrough(e.undone)
                            Text(e.how).font(.meta).foregroundStyle(Color.muted)
                        }
                        Spacer()
                        if e.undone {
                            Text("Undone").font(.system(size: 13, weight: .semibold)).foregroundStyle(Color.muted)
                        } else if e.undo != nil {
                            Button("Undo") { withAnimation(.snappy) { store.undoPebble(e) } }.font(.system(size: 14, weight: .semibold))
                        }
                    }
                    .pearl(radius: 14, padding: 12)
                }
                if !store.pebbleLog.isEmpty {
                    Button("Clear this list") { withAnimation(.snappy) { store.pebbleLog.removeAll() } }
                        .font(.system(size: 14, weight: .semibold)).foregroundStyle(Color.muted).frame(maxWidth: .infinity).padding(.top, 4)
                }
            }
            .padding(24)
        }
    }
}

struct SeesView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Image("pebble_sensitive_01").resizable().scaledToFit().frame(width: 60, height: 60)
            Text("What Pebble can see").font(.title(26)).foregroundStyle(Color.navy)
            ForEach(["Everyone's answers about time and how they like to help", "\(LOVED)'s goals, and the tasks and who has them", "What you tell it in Talk it through"], id: \.self) { l in
                Label(l, systemImage: "checkmark").font(.body15).foregroundStyle(Color.ink)
            }
            Label("Never \(LOVED)'s care page, notes or medical records. No medical advice.", systemImage: "lock").font(.body15).foregroundStyle(Color.muted)
            Spacer()
        }
        .padding(24)
    }
}
