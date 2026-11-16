import SwiftUI

struct HandoffView: View {
    @Environment(Store.self) private var store
    var id: String
    var step: Int?
    @State private var picked: Set<String> = []
    @State private var unassigned = false
    @State private var note = ""
    @State private var byPebble = false
    @State private var started = false

    var body: some View {
        if let t = store.task(id) {
            let s = step.flatMap { t.steps.indices.contains($0) ? t.steps[$0] : nil }
            let options = store.people.filter { $0.id != t.who }
            let able = options.filter { store.canTake($0, t) }
            let all = able.count > 1 && able.allSatisfy { picked.contains($0.id) }
            let target = picked.count == 1 ? store.person(picked.first) : nil
            let label = unassigned ? "Leave it unassigned" : picked.isEmpty ? "Pick someone"
                : target.map { "Send request to \($0.name)" } ?? (all ? "Ask everyone" : "Ask \(picked.count) people")
            let pick = store.pebblePick(t)

            Page {
                Text(s != nil ? "Ask for help with a step" : t.who != nil ? "Hand it off" : "Find someone")
                    .font(.title()).foregroundStyle(Color.navy)
                Text(s.map { "Just “\($0.n)”. The rest of the task stays with \(t.who == "you" ? "you" : store.name(t.who))." }
                     ?? "Ask one person, a few, or everyone. The first to say yes takes it, and the task moves to their jar.")
                    .font(.body15).foregroundStyle(Color.muted)

                HStack(spacing: 14) {
                    t.stone(base: 28).frame(width: 40)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(t.n).font(.system(size: 15.5, weight: .semibold)).foregroundStyle(Color.ink)
                        Text("\(t.who == nil ? "Unassigned" : store.name(t.who)) · \(t.dueLabel)").font(.meta).foregroundStyle(Color.muted)
                    }
                    Spacer()
                }
                .glassCard(radius: 18, padding: 12)

                if let pick {
                    HStack(spacing: 10) {
                        Image("pebble_offer_open_hands").resizable().scaledToFit().frame(width: 30, height: 30)
                        (Text(pick.p.name).bold() + Text(" has \(pick.why).")).font(.system(size: 14)).foregroundStyle(Color.ink)
                        Spacer()
                        if !picked.contains(pick.p.id) {
                            Button("Ask \(pick.p.name)") { picked = [pick.p.id]; unassigned = false }.font(.system(size: 14, weight: .semibold))
                        }
                    }
                    .pearl(radius: 16, padding: 12)
                }

                VStack(spacing: 0) {
                    if able.count > 1 {
                        row(selected: all, enabled: true, action: {
                            picked = all ? [] : Set(able.map(\.id)); unassigned = false
                        }) {
                            HStack(spacing: -10) { ForEach(able.prefix(3)) { Avatar(p: $0, size: 24) } }.frame(width: 52, alignment: .leading)
                            label2("Everyone who can", "\(able.count) people · first yes takes it")
                        }
                        Divider()
                    }
                    ForEach(options) { p in
                        let ok = able.contains(p)
                        let n = store.mine(p.id).filter { !$0.done }.count
                        row(selected: picked.contains(p.id), enabled: ok, action: {
                            if picked.contains(p.id) { picked.remove(p.id) } else { picked.insert(p.id) }
                            unassigned = false
                        }) {
                            Avatar(p: p, size: 38).frame(width: 52, alignment: .leading)
                            label2(p.name, ok ? "\(plural(n, "task"))\(p.remote ? " · remote" : "")\(p.tier == .trusted ? " · gets a text" : "")"
                                   : p.remote ? "Needs someone close by" : "Light tasks only")
                        }
                        if p.id != options.last?.id { Divider() }
                    }
                    if t.who != nil && s == nil {
                        Divider()
                        row(selected: unassigned, enabled: true, action: { unassigned.toggle(); if unassigned { picked = [] } }) {
                            Stone(state: .open, w: .medium, base: 26).frame(width: 52, alignment: .leading)
                            label2("Unassigned", "Glows white for whoever is free")
                        }
                    }
                }
                .glassCard(padding: 8)

                HStack {
                    (Text("Note ").font(.system(size: 14, weight: .semibold)).foregroundStyle(Color.sectionInk) + Text("optional").font(.meta).foregroundStyle(Color.muted))
                    Spacer()
                    if store.pebbleOn && !byPebble {
                        PearlChip(label: "Write it for me") { note = store.pebbleNote(t, step: s?.n); byPebble = true }
                    }
                }
                .padding(.top, 10).padding(.horizontal, 4)
                TextField("Anything they should know?", text: $note, axis: .vertical)
                    .lineLimit(3...6).font(.body15)
                    .padding(14)
                    .background(.white.opacity(0.85), in: .rect(cornerRadius: 16))
                    .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Color(hex: 0xdde1e6)))
                if byPebble { Text("Pebble wrote this. It names the task and the date, never health details.").font(.system(size: 12)).foregroundStyle(Color.pearlInk) }

                if let target {
                    Text(target.tier == .main && !target.remote ? "\(target.name) gets it in the app." : "We'll text \(target.name).").font(.meta).foregroundStyle(Color.muted)
                        .frame(maxWidth: .infinity)
                } else if picked.count > 1 {
                    Text("They each get the request. Once someone says yes, the rest are told it's covered.").font(.meta).foregroundStyle(Color.muted)
                        .multilineTextAlignment(.center).frame(maxWidth: .infinity)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .safeAreaInset(edge: .bottom) {
                Button(label) { send(t) }
                    .buttonStyle(PrimaryButton(enabled: unassigned || !picked.isEmpty))
                    .disabled(!unassigned && picked.isEmpty)
                    .padding(.horizontal, 20).padding(.top, 10).padding(.bottom, 6)
                    .background(LinearGradient(colors: [Color(hex: 0xf0f7ff, 0), Color(hex: 0xf0f7ff, 0.95)], startPoint: .top, endPoint: .center))
            }
            .onAppear {
                // Coming from one of Pebble's suggestions, its pick is already made.
                guard !started else { return }
                started = true
                if let p = store.handPick { picked = [p]; store.handPick = nil }
            }
        }
    }

    private func send(_ t: CareTask) {
        if unassigned {
            if let i = store.idx(id) { store.tasks[i].who = nil }
            store.say("Left open. It glows white for whoever is free.")
        } else {
            let order = store.people.map(\.id).filter { picked.contains($0) }
            store.sendHandoff(id, to: order, note: note, step: step, byPebble: byPebble)
        }
        store.back()
    }

    private func label2(_ a: String, _ b: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(a).font(.system(size: 15.5, weight: .semibold)).foregroundStyle(Color.ink)
            Text(b).font(.meta).foregroundStyle(Color.muted)
        }
    }

    private func row<C: View>(selected: Bool, enabled: Bool, action: @escaping () -> Void, @ViewBuilder _ c: () -> C) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                c()
                Spacer()
                Image(systemName: selected ? "checkmark.circle.fill" : "circle").font(.system(size: 22))
                    .foregroundStyle(selected ? Color.shoalBlue : Color(hex: 0xc4c8ce))
            }
            .padding(.horizontal, 8).padding(.vertical, 10)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .disabled(!enabled).opacity(enabled ? 1 : 0.4)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}
