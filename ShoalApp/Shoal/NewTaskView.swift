import SwiftUI

struct NewTaskView: View {
    @Environment(Store.self) private var store
    @State private var name = ""
    @State private var kind: Kind = .once
    @State private var date = addDays(4)
    @State private var time = ""
    @State private var days: Set<String> = ["Sat"]
    @State private var w: Weight = .medium
    @State private var sizeSet = false
    @State private var open: Set<Tier> = [.main]
    @State private var openSet = false
    @State private var remote = false
    @State private var who: String? = "you"
    @State private var notes = ""
    @State private var sizeSheet = false
    @State private var whenSheet = false
    @State private var pick: Weight?
    @FocusState private var nameFocus: Bool

    private var draft: CareTask {
        CareTask(id: "n\(store.tasks.count)", n: name.trimmingCharacters(in: .whitespaces), who: who, w: w, cat: remote ? "phone" : "there",
                 kind: kind, days: kind == .repeating ? DAYS.filter { days.contains($0) } : [], date: date, time: time, notes: notes, remote: remote,
                 open: openSet ? Tier.allCases.filter { open.contains($0) } : nil)
    }

    var body: some View {
        let t = draft
        let tiers = store.openTo(t)
        Page {
            Text("New task").font(.title()).foregroundStyle(Color.navy)

            label("What needs doing?")
            TextField("e.g. Pick up shower chair", text: $name)
                .font(.app(17)).focused($nameFocus).submitLabel(.done)
                .padding(.horizontal, 16).frame(height: 56)
                .background(.white, in: .rect(cornerRadius: 16))
                .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(nameFocus ? Color.shoalBlue : Color(hex: 0xdde1e6), lineWidth: nameFocus ? 2 : 1))
                .onChange(of: name) { guessSize() }

            Picker("Kind", selection: $kind) {
                Text("One-time").tag(Kind.once)
                Text("Ongoing").tag(Kind.repeating)
            }
            .pickerStyle(.segmented).padding(.top, 6)

            Button { whenSheet = true } label: {
                HStack(spacing: 10) {
                    (Text(kind == .once ? "Due date" : "Repeats").font(.app(15, .medium)).foregroundStyle(Color.ink)
                     + Text("  Required").font(.app(12.5, .medium)).foregroundStyle(Color(hex: 0xa26b0c)))
                    Spacer()
                    Text((kind == .once ? fmtDate(date) : repeatLabel(Array(days))) + (time.isEmpty ? "" : " · \(fmtTime(time))"))
                        .font(.app(15, .semibold)).foregroundStyle(Color.shoalBlue)
                    Chevron()
                }
                .glassCard(padding: 16)
            }
            .buttonStyle(Pressable())

            Button { sizeSheet = true } label: {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text("Stone size").font(.app(15.5, .semibold)).foregroundStyle(Color.ink)
                            if !sizeSet && store.pebbleOn && !name.trimmingCharacters(in: .whitespaces).isEmpty { Text("Pebble's guess").font(.app(12.5, .medium)).foregroundStyle(Color(hex: 0xa26b0c)) }
                        }
                        Text("Bigger stone, bigger job").font(.meta).foregroundStyle(Color.muted)
                    }
                    Spacer()
                    Stone(state: .open, w: w, base: 18)
                    Text(w.label).font(.app(15, .semibold)).foregroundStyle(Color.shoalBlue)
                    Chevron()
                }
                .glassCard(padding: 14)
            }
            .buttonStyle(Pressable())

            SectionH(text: "Who can help")
            VStack(alignment: .leading, spacing: 12) {
                FlowRow(spacing: 8) {
                    ForEach(Tier.allCases) { k in
                        let on = tiers.contains(k)
                        Button {
                            var s = Set(tiers); if on { s.remove(k) } else { s.insert(k) }
                            guard !s.isEmpty else { store.say("At least one group needs to be able to help"); return }
                            open = s; openSet = true
                            if let p = store.person(who), !store.canTake(p, draft) { who = nil }
                        } label: {
                            Text(k == .main ? "Main caregivers" : k == .trusted ? "Trusted circle" : "Kids & teens")
                                .font(.app(13.5, .semibold))
                                .padding(.horizontal, 14).frame(height: 36)
                                .foregroundStyle(on ? Color.navy : Color.ink)
                                .background(on ? Color.blueTint : .white.opacity(0.9), in: .capsule)
                                .overlay(Capsule().strokeBorder(on ? Color.navy : Color(hex: 0xdde1e6), lineWidth: on ? 1.5 : 1))
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(on ? .isSelected : [])
                    }
                }
                Divider()
                Toggle(isOn: $remote) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Can be done from anywhere").font(.app(15.5, .semibold))
                        Text(remoteNote(t)).font(.meta).foregroundStyle(Color.muted)
                    }
                }
                .onChange(of: remote) { if let p = store.person(who), !store.canTake(p, draft) { who = nil } }
            }
            .glassCard(padding: 14)

            SectionH(text: "Who takes it")
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 5), spacing: 10) {
                ForEach(store.people) { p in
                    pickButton(on: who == p.id, label: p.name, enabled: store.canTake(p, t)) { who = p.id } face: { Avatar(p: p, size: 36) }
                }
                pickButton(on: who == nil, label: "Open", enabled: true) { who = nil } face: {
                    Circle().strokeBorder(Color(hex: 0xb7bcc4), style: .init(lineWidth: 1.4, dash: [4, 3])).frame(width: 36, height: 36)
                }
            }
            .glassCard(padding: 12)

            SectionH(text: "Notes")
            TextField("Add a note (optional)", text: $notes, axis: .vertical)
                .lineLimit(3...6).font(.body15).padding(14)
                .background(.white.opacity(0.85), in: .rect(cornerRadius: 16))
                .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Color(hex: 0xdde1e6)))
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden()
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button { store.back() } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.left").font(.system(size: 15, weight: .medium))
                        Text("Cancel").font(.app(15, .medium))
                    }
                    .foregroundStyle(Color.ink).padding(.horizontal, 6).fixedSize()
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            let ok = !name.trimmingCharacters(in: .whitespaces).isEmpty
            Button("Save task") { store.addTask(draft) }
                .buttonStyle(PrimaryButton(enabled: ok)).disabled(!ok)
                .padding(.horizontal, 20).padding(.top, 10).padding(.bottom, 6)
                .background(LinearGradient(colors: [Color(hex: 0xf0f7ff, 0), Color(hex: 0xf0f7ff, 0.95)], startPoint: .top, endPoint: .center))
        }
        .sheet(isPresented: $sizeSheet) { SizeSheet(w: Binding(get: { w }, set: { w = $0; sizeSet = true }), pick: pick) }
        .sheet(isPresented: $whenSheet) {
            WhenSheet(title: name, kind: $kind, days: Binding(get: { DAYS.filter { days.contains($0) } }, set: { days = Set($0) }), date: $date, time: $time)
        }
        .onAppear { nameFocus = true }
    }

    private func label(_ s: String) -> some View {
        Text(s).font(.app(14, .semibold)).foregroundStyle(Color.sectionInk).padding(.horizontal, 4).padding(.top, 6)
    }

    // Pebble guesses the size from the words, until you pick one yourself.
    private func guessSize() {
        guard !sizeSet, store.pebbleOn else { return }
        let n = name.lowercased()
        guard !n.trimmingCharacters(in: .whitespaces).isEmpty else { w = .medium; pick = nil; return }
        let big = ["overnight", "night off", "stay", "move", "moving", "install", "set up", "hospital", "renovat", "whole day", "weekend", "trip"]
        let mid = ["appointment", "doctor", "ride", "drive", "cook", "meal", "clean", "bath", "shop", "grocer", "walk", "outing", "yard", "therapy", "visit", "repair", "errand"]
        w = big.contains { n.contains($0) } ? .large : mid.contains { n.contains($0) } ? .medium : .small
        pick = w
    }

    private func remoteNote(_ t: CareTask) -> String {
        let far = store.people.filter { $0.remote && store.openTo(t).contains($0.tier) }.map(\.name)
        if far.isEmpty { return "Phone calls, forms, ordering online" }
        return t.remote ? "\(andList(far)) can take it too" : "Lets \(andList(far)) take it from afar"
    }

    private func pickButton<F: View>(on: Bool, label: String, enabled: Bool, action: @escaping () -> Void, @ViewBuilder face: () -> F) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                face().padding(3).overlay(Circle().strokeBorder(on ? Color.shoalBlue : .clear, lineWidth: 2.5))
                Text(label).font(.app(13, on ? .semibold : .medium)).foregroundStyle(on ? Color.shoalBlue : Color.muted).lineLimit(1)
            }
        }
        .buttonStyle(.plain)
        .disabled(!enabled).opacity(enabled ? 1 : 0.35)
        .accessibilityAddTraits(on ? .isSelected : [])
    }
}
