import SwiftUI

struct Badge: View {
    var text: String
    var amber = false
    var body: some View {
        HStack(spacing: 5) {
            if amber { Stone(state: .urgent, w: .small, base: 16) }
            Text(text).font(.system(size: 12.5, weight: .semibold))
        }
        .foregroundStyle(amber ? Color(hex: 0x8a5d0c) : Color.sectionInk)
        .padding(.horizontal, 10).frame(height: 26)
        .background(amber ? Color(hex: 0xf6d27c, 0.32) : .white.opacity(0.75), in: .capsule)
        .overlay(Capsule().strokeBorder(.white))
    }
}

struct TaskView: View {
    @Environment(Store.self) private var store
    var id: String
    @State private var sizeSheet = false
    @State private var costs = false

    var body: some View {
        if let t = store.task(id) {
            let p = store.person(t.who)
            let stepsDone = t.steps.filter(\.done).count
            Page {
                HStack(spacing: 6) {
                    Badge(text: t.kind == .once ? "One-time" : "Ongoing")
                    Button { sizeSheet = true } label: { Badge(text: t.w.label) }.accessibilityLabel("Size: \(t.w.label). Change size")
                    Badge(text: t.kind == .once ? "Due \(fmtDate(t.date))" : repeatLabel(t.days), amber: t.urgent)
                    if t.remote { Badge(text: "Remote OK") }
                }
                Text(t.n).font(.title()).foregroundStyle(Color.navy).padding(.bottom, 2)

                HStack(spacing: 12) {
                    if let p { Avatar(p: p, size: 40) } else {
                        Circle().strokeBorder(Color(hex: 0xb7bcc4), style: .init(lineWidth: 1.4, dash: [4, 3])).frame(width: 40, height: 40)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(p?.name ?? "Unassigned").font(.system(size: 15.5, weight: .semibold)).foregroundStyle(Color.ink)
                        Text(t.done ? "Done · stone resting" : stoneLine(t)).font(.meta).foregroundStyle(Color.muted)
                    }
                    Spacer()
                    t.stone(base: 30)
                }
                .glassCard()

                if let h = t.handoff {
                    HStack(spacing: 12) {
                        Avatar(p: store.person(h.to.first), size: 32)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(h.pending ? "Waiting on \(h.to.map { store.name($0) }.joined(separator: ", "))" : "\(store.name(t.who)) said yes")
                                .font(.system(size: 15, weight: .semibold)).foregroundStyle(Color.ink)
                            if !h.note.isEmpty { Text("“\(h.note)”").font(.meta).foregroundStyle(Color.muted).lineLimit(2) }
                        }
                        Spacer()
                        if h.pending { ProgressView().controlSize(.small) } else { Image(systemName: "checkmark.circle.fill").foregroundStyle(Color.shoalBlue) }
                    }
                    .glassCard(radius: 18, padding: 14)
                }

                if !t.steps.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack { Text("Steps").font(.system(size: 15, weight: .semibold)); Spacer(); Text("\(stepsDone) of \(t.steps.count)").font(.meta).foregroundStyle(Color.muted) }
                        ProgressView(value: Double(stepsDone), total: Double(t.steps.count)).tint(.shoalBlue)
                        ForEach(Array(t.steps.enumerated()), id: \.element.id) { i, x in
                            HStack(spacing: 12) {
                                Button { withAnimation(.snappy) { store.toggleStep(id, i) } } label: {
                                    Image(systemName: x.done ? "checkmark.circle.fill" : "circle").font(.system(size: 22))
                                        .foregroundStyle(x.done ? Color.shoalBlue : Color(hex: 0xb7bcc4))
                                }
                                .accessibilityLabel(x.done ? "Mark \(x.n) not done" : "Mark \(x.n) done")
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(x.n).font(.system(size: 15, weight: .medium)).foregroundStyle(Color.ink).strikethrough(x.done, color: .muted)
                                    Text(stepLine(x)).font(.meta).foregroundStyle(x.ask != nil ? Color.shoalBlue : Color.muted)
                                }
                                Spacer()
                                if let w = x.who, w != "you" { Avatar(p: store.person(w), size: 22) }
                                else if x.who == nil && x.ask == nil {
                                    Menu {
                                        Button("I'll take it") { store.takeStep(id, i) }
                                        Button("Ask someone") { store.go(.handoff(id, step: i)) }
                                    } label: { Text("Take step").font(.system(size: 14, weight: .semibold)) }
                                }
                            }
                        }
                    }
                    .glassCard()
                }

                if t.cat == "meds" && t.n == "Comfort meds" { MedTaskCard(ids: ["morphine", "lorazepam"]) }
                if t.cat == "meds" && t.n == "Morning meds" { MedTaskCard(ids: ["metoprolol"]) }

                if !t.notes.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Eyebrow(text: "Notes")
                        Text(t.notes).font(.body15).foregroundStyle(Color.ink).lineSpacing(3)
                        Text("Added by you").font(.meta).foregroundStyle(Color.muted)
                    }
                    .glassCard()
                }

                if store.pebbleOn && !t.done && (t.cat == "paper" || t.n.localizedCaseInsensitiveContains("pay")) {
                    HStack(spacing: 10) {
                        Image("pebble_research_glasses_focused").resizable().scaledToFit().frame(width: 44, height: 44)
                        PearlChip(label: "Find help paying") { costs = true }
                        Spacer()
                    }
                    .padding(.top, 4)
                }
            }
            .navigationTitle("").navigationBarTitleDisplayMode(.inline)
            .safeAreaInset(edge: .bottom) {
                HStack(spacing: 10) {
                    if t.done {
                        Button("Mark not done") { store.toggleDone(id) }.buttonStyle(PrimaryButton())
                    } else {
                        Button("Hand off") { store.go(.handoff(id, step: nil)) }.buttonStyle(GhostButton())
                        Button("Mark done") { withAnimation(.snappy) { store.toggleDone(id) } }.buttonStyle(PrimaryButton())
                    }
                }
                .padding(.horizontal, 20).padding(.top, 10).padding(.bottom, 6)
                .background(LinearGradient(colors: [Color(hex: 0xf0f7ff, 0), Color(hex: 0xf0f7ff, 0.95)], startPoint: .top, endPoint: .center))
            }
            .sheet(isPresented: $sizeSheet) { SizeSheet(w: Binding(get: { t.w }, set: { v in if let i = store.idx(id) { store.tasks[i].w = v } })) }
            .sheet(isPresented: $costs) { CostsView().presentationDetents([.large]) }
        }
    }

    private func stoneLine(_ t: CareTask) -> String {
        switch t.state {
        case .urgent: "Stone glows yellow · due soon"
        case .progress: "Stone glows ice blue"
        case .open: "Stone glows white for whoever is free"
        case .done: "Done · stone resting"
        }
    }

    private func stepLine(_ x: Step) -> String {
        if let ask = x.ask { return "Asked \(store.name(ask))" }
        guard let w = x.who else { return "Open" }
        return x.done ? "\(store.name(w)) · \(x.when ?? "Today")" : "\(store.name(w)) is on it"
    }
}

struct SizeSheet: View {
    @Binding var w: Weight
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Stone size").font(.title(26)).foregroundStyle(Color.navy)
            Text("Bigger stone, bigger job.").font(.meta).foregroundStyle(Color.muted)
            ForEach(Weight.allCases) { x in
                Button { w = x; dismiss() } label: {
                    HStack(spacing: 14) {
                        Stone(state: .open, w: x, base: 30).frame(width: 44)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(x.label).font(.system(size: 15.5, weight: .semibold)).foregroundStyle(Color.ink)
                            Text(x.hint).font(.meta).foregroundStyle(Color.muted)
                        }
                        Spacer()
                        if w == x { Image(systemName: "checkmark").foregroundStyle(Color.shoalBlue).fontWeight(.semibold) }
                    }
                    .padding(12).background(w == x ? Color.blueTint : .clear, in: .rect(cornerRadius: 14))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(24)
        .presentationDetents([.height(360)])
    }
}
