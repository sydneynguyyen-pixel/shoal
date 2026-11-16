import SwiftUI

struct NewTaskView: View {
    @Environment(Store.self) private var store
    @State private var name = ""
    @State private var kind: Kind = .once
    @State private var date = addDays(1)
    @State private var days: Set<String> = ["Sat"]
    @State private var w: Weight = .medium
    @State private var sizeSet = false
    @State private var open: Set<Tier> = [.main]
    @State private var openSet = false
    @State private var remote = false
    @State private var who: String? = "you"
    @State private var notes = ""
    @State private var sizeSheet = false
    @FocusState private var nameFocus: Bool

    private var draft: CareTask {
        CareTask(id: "n\(store.tasks.count)", n: name.trimmingCharacters(in: .whitespaces), who: who, w: w, cat: remote ? "phone" : "there",
                 kind: kind, days: kind == .repeating ? DAYS.filter { days.contains($0) } : [], date: date, notes: notes, remote: remote,
                 open: openSet ? Tier.allCases.filter { open.contains($0) } : nil)
    }

    var body: some View {
        let t = draft
        let tiers = store.openTo(t)
        Page {
            Text("New task").font(.title()).foregroundStyle(Color.navy)

            label("What needs doing?")
            TextField("e.g. Pick up shower chair", text: $name)
                .font(.system(size: 17)).focused($nameFocus).submitLabel(.done)
                .padding(.horizontal, 16).frame(height: 56)
                .background(.white, in: .rect(cornerRadius: 16))
                .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(nameFocus ? Color.shoalBlue : Color(hex: 0xdde1e6), lineWidth: nameFocus ? 2 : 1))
                .onChange(of: name) { guessSize() }

            Picker("Kind", selection: $kind) {
                Text("One-time").tag(Kind.once)
                Text("Ongoing").tag(Kind.repeating)
            }
            .pickerStyle(.segmented).padding(.top, 6)

            VStack(spacing: 0) {
                if kind == .once {
                    DatePicker(selection: $date, in: TODAY..., displayedComponents: .date) {
                        Text("Due date").font(.system(size: 15.5, weight: .semibold))
                    }
                    .padding(.vertical, 6)
                } else {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack { Text("Repeats").font(.system(size: 15.5, weight: .semibold)); Spacer(); Text(repeatLabel(Array(days))).font(.meta).foregroundStyle(Color.muted) }
                        HStack(spacing: 6) {
                            ForEach(DAYS, id: \.self) { d in
                                let on = days.contains(d)
                                Button { if on { days.remove(d) } else { days.insert(d) } } label: {
                                    Text(String(d.prefix(1))).font(.system(size: 14, weight: .semibold))
                                        .frame(width: 36, height: 36)
                                        .foregroundStyle(on ? .white : Color.ink)
                                        .background(on ? Color.shoalBlue : .white, in: .circle)
                                        .overlay(Circle().strokeBorder(on ? .clear : Color(hex: 0xdde1e6)))
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel(DAY_FULL[d]!).accessibilityAddTraits(on ? .isSelected : [])
                            }
                        }
                    }
                    .padding(.vertical, 6)
                }
            }
            .glassCard(padding: 14)

            Button { sizeSheet = true } label: {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text("Stone size").font(.system(size: 15.5, weight: .semibold)).foregroundStyle(Color.ink)
                            if !sizeSet && store.pebbleOn && !name.isEmpty { Text("Pebble's guess").font(.system(size: 12, weight: .semibold)).foregroundStyle(Color.pearlInk) }
                        }
                        Text("Bigger stone, bigger job").font(.meta).foregroundStyle(Color.muted)
                    }
                    Spacer()
                    Stone(state: .open, w: w, base: 26)
                    Text(w.label).font(.system(size: 15, weight: .semibold)).foregroundStyle(Color.ink)
                    Chevron()
                }
                .glassCard(padding: 14)
            }
            .buttonStyle(Pressable())

            SectionH(text: "Who can help")
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    ForEach(Tier.allCases) { k in
                        let on = tiers.contains(k)
                        Button {
                            var s = Set(tiers); if on { s.remove(k) } else { s.insert(k) }
                            s.insert(.main); open = s; openSet = true
                            if let p = store.person(who), !store.canTake(p, draft) { who = nil }
                        } label: {
                            Text(k == .main ? "Main caregivers" : k == .trusted ? "Trusted circle" : "Kids & teens")
                                .font(.system(size: 13, weight: .semibold)).lineLimit(1).minimumScaleFactor(0.8)
                                .padding(.horizontal, 10).frame(height: 34)
                                .foregroundStyle(on ? Color.shoalBlue : Color.ink)
                                .background(on ? Color.blueTint : .white.opacity(0.9), in: .capsule)
                                .overlay(Capsule().strokeBorder(on ? Color.shoalBlue.opacity(0.5) : Color(hex: 0xdde1e6)))
                        }
                        .buttonStyle(.plain)
                        .disabled(k == .main)
                        .accessibilityAddTraits(on ? .isSelected : [])
                    }
                }
                Divider()
                Toggle(isOn: $remote) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Can be done from anywhere").font(.system(size: 15.5, weight: .semibold))
                        Text(remoteNote(t)).font(.meta).foregroundStyle(Color.muted)
                    }
                }
                .onChange(of: remote) { if let p = store.person(who), !store.canTake(p, draft) { who = nil } }
            }
            .glassCard(padding: 14)

            SectionH(text: "Who takes it")
            ScrollView(.horizontal) {
                HStack(spacing: 14) {
                    ForEach(store.people) { p in
                        let ok = store.canTake(p, t)
                        pickButton(on: who == p.id, label: p.name, enabled: ok) { who = p.id } face: { Avatar(p: p, size: 46) }
                    }
                    pickButton(on: who == nil, label: "Open", enabled: true) { who = nil } face: {
                        Circle().strokeBorder(Color(hex: 0xb7bcc4), style: .init(lineWidth: 1.4, dash: [4, 3])).frame(width: 46, height: 46)
                    }
                }
                .padding(.horizontal, 6).padding(.vertical, 4)
            }
            .scrollIndicators(.hidden)
            .glassCard(padding: 8)

            SectionH(text: "Notes")
            TextField("Add a note (optional)", text: $notes, axis: .vertical)
                .lineLimit(3...6).font(.body15).padding(14)
                .background(.white.opacity(0.85), in: .rect(cornerRadius: 16))
                .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Color(hex: 0xdde1e6)))
        }
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            let ok = !name.trimmingCharacters(in: .whitespaces).isEmpty && (kind == .once || !days.isEmpty)
            Button("Save task") { store.addTask(draft); store.back() }
                .buttonStyle(PrimaryButton(enabled: ok)).disabled(!ok)
                .padding(.horizontal, 20).padding(.top, 10).padding(.bottom, 6)
                .background(LinearGradient(colors: [Color(hex: 0xf0f7ff, 0), Color(hex: 0xf0f7ff, 0.95)], startPoint: .top, endPoint: .center))
        }
        .sheet(isPresented: $sizeSheet) { SizeSheet(w: Binding(get: { w }, set: { w = $0; sizeSet = true })) }
        .onAppear { nameFocus = true }
    }

    private func label(_ s: String) -> some View {
        Text(s).font(.system(size: 14, weight: .semibold)).foregroundStyle(Color.sectionInk).padding(.horizontal, 4).padding(.top, 6)
    }

    // Pebble guesses the size from the words, until you pick one yourself.
    private func guessSize() {
        guard !sizeSet, store.pebbleOn else { return }
        let n = name.lowercased()
        let big = ["overnight", "move", "install", "set up", "hospital", "whole day", "weekend", "trip"]
        let mid = ["appointment", "doctor", "ride", "drive", "cook", "meal", "clean", "bath", "shop", "grocer", "walk", "yard", "visit", "repair", "errand"]
        w = big.contains { n.contains($0) } ? .large : mid.contains { n.contains($0) } ? .medium : .small
    }

    private func remoteNote(_ t: CareTask) -> String {
        let far = store.people.filter { $0.remote && store.openTo(t).contains($0.tier) }.map(\.name)
        if far.isEmpty { return "Phone calls, forms, ordering online" }
        return t.remote ? "\(far.joined(separator: " and ")) can take it too" : "Lets \(far.joined(separator: " and ")) take it from afar"
    }

    private func pickButton<F: View>(on: Bool, label: String, enabled: Bool, action: @escaping () -> Void, @ViewBuilder face: () -> F) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                face().padding(3).overlay(Circle().strokeBorder(on ? Color.shoalBlue : .clear, lineWidth: 2.5))
                Text(label).font(.system(size: 13, weight: on ? .semibold : .regular)).foregroundStyle(on ? Color.shoalBlue : Color.ink)
            }
        }
        .buttonStyle(.plain)
        .disabled(!enabled).opacity(enabled ? 1 : 0.35)
        .accessibilityAddTraits(on ? .isSelected : [])
    }
}
