import SwiftUI

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
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 12) {
                        Image("pebble_research_glasses_focused").resizable().scaledToFit().frame(width: 56, height: 56)
                        VStack(alignment: .leading, spacing: 2) {
                            Eyebrow(text: "Help with costs", color: Color.pearlInk)
                            Text("\(PROGRAMS.count) programs that may fit").font(.title(24)).foregroundStyle(Color.navy)
                        }
                    }
                    Text("Based on: California · care at home · sample answers").font(.meta).foregroundStyle(Color.muted)
                        .padding(.bottom, 2)
                    ForEach(PROGRAMS) { p in
                        let added = store.costTasks[p.id].map { id in store.tasks.contains { $0.id == id } } ?? false
                        VStack(alignment: .leading, spacing: 4) {
                            Text(p.n).font(.app(15, .semibold)).foregroundStyle(Color(hex: 0x6a5a8c))
                            Text(p.d).font(.meta).foregroundStyle(Color.muted)
                            HStack {
                                Text("Source · \(p.src)").font(.meta).foregroundStyle(Color.muted)
                                Spacer()
                                if added {
                                    Badge(text: "Task added")
                                } else {
                                    Button("Make a task") { add(p) }
                                        .font(.app(13, .semibold)).foregroundStyle(Color.shoalBlue)
                                        .padding(.horizontal, 12).frame(height: 30)
                                        .background(Color.blueTint, in: .capsule)
                                        .buttonStyle(Pressable())
                                }
                            }
                            .padding(.top, 8)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .pearl(radius: 18, padding: 14)
                    }
                    Text("Pebble finds and explains. Only the program can say if you qualify.")
                        .font(.meta).foregroundStyle(Color.muted).multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity).padding(.top, 4)
                }
                .padding(20)
            }
            .background(AppBackground())
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
    }

    private func add(_ p: Program) {
        let name = "Look into " + p.n.replacingOccurrences(of: #"\s*\(.*\)"#, with: "", options: .regularExpression)
        let id = "c\(UUID().uuidString.prefix(6))"
        store.tasks.append(CareTask(id: id, n: name, who: "you", w: .small, cat: "paper", kind: .once, date: addDays(7),
                                    notes: "Source: \(p.src). Only the program can say if \(LOVED) qualifies."))
        store.costTasks[p.id] = id
        store.pebbleDid("Added “\(name)” to your jar", how: "From Help with costs · source \(p.src)", undo: .task(id))
        store.say("Added to your jar")
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
                            Text(e.what).font(.app(14.5, .semibold)).foregroundStyle(Color.ink).strikethrough(e.undone)
                            Text(e.how).font(.meta).foregroundStyle(Color.muted)
                        }
                        Spacer()
                        if e.undone {
                            Text("Undone").font(.app(13, .semibold)).foregroundStyle(Color.muted)
                        } else if e.undo != nil {
                            Button("Undo") { withAnimation(.snappy) { store.undoPebble(e) } }.font(.app(14, .semibold))
                        }
                    }
                    .pearl(radius: 14, padding: 12)
                }
                if !store.pebbleLog.isEmpty {
                    Button("Clear this list") { withAnimation(.snappy) { store.pebbleLog.removeAll() } }
                        .font(.app(14, .semibold)).foregroundStyle(Color.muted).frame(maxWidth: .infinity).padding(.top, 4)
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
            ForEach(["Everyone's answers about time and how they like to help", "\(LOVED)'s goals, and the tasks and who has them", "What you tell it in this chat"], id: \.self) { l in
                Label(l, systemImage: "checkmark").font(.body15).foregroundStyle(Color.ink)
            }
            Label("Never \(LOVED)'s care page, notes or medical records. No medical advice.", systemImage: "lock").font(.body15).foregroundStyle(Color.muted)
            Spacer()
        }
        .padding(24)
    }
}
