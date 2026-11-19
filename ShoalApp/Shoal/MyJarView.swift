import SwiftUI

struct MyJarView: View {
    @Environment(Store.self) private var store
    enum Filter: String, CaseIterable { case all = "All", urgent = "Urgent", once = "One-time", ongoing = "Ongoing" }
    @State private var tab: Filter = .all
    @State private var showDone = false
    @State private var reviewing: Request?

    var body: some View {
        let all = store.mine("you")
        let live = all.filter { !$0.done }
        let done = all.filter(\.done)
        let urgent = live.filter(\.urgent)
        let shown = live.filter { t in
            switch tab { case .all: true; case .urgent: t.urgent; case .once: t.kind == .once; case .ongoing: t.kind == .repeating }
        }
            .sorted { (order($0), $0.date) < (order($1), $1.date) }
        let onBreak = store.checkIn == .onBreak && !store.heldOpen

        Page {
            VStack(spacing: 6) {
                Jar(who: "you", width: 120)
                Text(live.isEmpty ? (store.mine("you").isEmpty ? "No tasks yet" : "All done") : "\(live.count) to do").font(.app(14)).foregroundStyle(Color.muted)
            }
            .frame(maxWidth: .infinity).padding(.top, 4).padding(.bottom, 8)
            // Shrinks and fades as it scrolls away, like a large title.
            .visualEffect { v, g in
                let y = g.frame(in: .scrollView).minY, h = max(g.size.height, 1)
                let p = min(max(-y / h, 0), 1)
                return v.scaleEffect(1 - 0.4 * p, anchor: .bottom).opacity(1 - p)
            }

            if store.ringOn {
                HStack { Spacer(); Ring(done: done.count, urgent: urgent.count, total: all.count); Spacer() }
                    .glassCard()
            }

            if onBreak && !store.requests.isEmpty {
                requestCard(eyebrow: "On hold till Sunday", title: "\(plural(store.requests.count, "ask")) waiting", cta: "See") { store.heldOpen = true }
            } else {
                ForEach(store.requests) { r in
                    requestCard(eyebrow: "Request from \(store.name(r.from))", title: r.n, cta: "Review") { reviewing = r }
                }
            }

            Picker("Show", selection: $tab.animation(.snappy)) {
                ForEach(Filter.allCases, id: \.self) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .padding(.vertical, 2)

            VStack(alignment: .leading, spacing: 0) {
                ForEach(shown) { t in
                    if t.id != shown.first?.id { RowSep() }
                    HStack(spacing: 0) {
                        TaskLine(t: t, showWho: false, meta: t.urgent ? t.dueLabel.prefix(1).uppercased() + t.dueLabel.dropFirst() : t.kind == .once ? fmtDate(t.date) : repeatLabel(t.days))
                        Button { withAnimation(.snappy) { store.toggleDone(t.id) } } label: {
                            Image(systemName: "circle").font(.system(size: 22)).foregroundStyle(Color(hex: 0xb7bcc4)).frame(width: 44, height: 44)
                        }
                        .accessibilityLabel("Mark \(t.n) done")
                    }
                }
                if shown.isEmpty { Text(tab == .urgent ? "Nothing urgent." : "Nothing here. Tap + to add a task.").font(.meta).foregroundStyle(Color.muted).padding(.vertical, 14) }
            }
            .glassCard()

            if !done.isEmpty {
                Button { withAnimation(.snappy) { showDone.toggle() } } label: {
                    HStack { Text("Done · \(done.count)").font(.app(15, .semibold)).foregroundStyle(Color.sectionInk)
                        Spacer()
                        Image(systemName: "chevron.right").font(.system(size: 12, weight: .semibold)).rotationEffect(.degrees(showDone ? 90 : 0)).foregroundStyle(Color.muted) }
                    .padding(.horizontal, 4).padding(.top, 14).frame(minHeight: 44).contentShape(.rect)
                }
                .buttonStyle(.plain)
                if showDone {
                    VStack(spacing: 0) { ForEach(done) { t in if t.id != done.first?.id { RowSep() }; TaskLine(t: t, showWho: false, meta: "Done") } }.glassCard()
                }
            }
        }
        .contentMargins(.bottom, 90, for: .scrollContent)   // keeps Done clear of the tab bar
        .navigationTitle("Your jar")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Add a task", systemImage: "plus") { store.go(.newTask) }
            }
        }
        .sheet(item: $reviewing) { r in
            VStack(alignment: .leading, spacing: 12) {
                Eyebrow(text: "Request from \(store.name(r.from))", color: .shoalBlue)
                Text(r.n).font(.title(26)).foregroundStyle(Color.navy)
                Text("“\(r.note)”").font(.body15).foregroundStyle(Color.muted)
                HStack(spacing: 10) {
                    Button("Not this time") { store.answer(r, yes: false); reviewing = nil }.buttonStyle(GhostButton())
                    Button("I'll take it") { store.answer(r, yes: true); reviewing = nil }.buttonStyle(PrimaryButton())
                }
                .padding(.top, 8)
                Button("Decide later") { reviewing = nil }.font(.app(15, .semibold)).frame(maxWidth: .infinity).padding(.top, 4)
            }
            .padding(24)
            .presentationDetents([.height(320)])
        }
    }

    private func order(_ t: CareTask) -> Int { t.urgent ? 0 : t.kind == .once ? 1 : 2 }

    // A request isn't a task yet, so it gets its own tinted card with a clear button.
    private func requestCard(eyebrow: String, title: String, cta: String, action: @escaping () -> Void) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Eyebrow(text: eyebrow, color: .navy)
                Text(title).font(.app(16, .semibold)).foregroundStyle(Color.ink)
            }
            Spacer()
            Button(cta, action: action)
                .font(.app(14, .semibold)).foregroundStyle(.white)
                .padding(.horizontal, 16).padding(.vertical, 9)
                .background(Color.shoalBlue, in: .capsule)
        }
        .padding(.vertical, 14).padding(.horizontal, 16)
        .background(RoundedRectangle(cornerRadius: 22).fill(Color.shoalBlue.opacity(0.09)).background(.white.opacity(0.8), in: .rect(cornerRadius: 22)))
        .overlay(RoundedRectangle(cornerRadius: 22).strokeBorder(.white.opacity(0.9)))
    }
}

// Done in blue, urgent in yellow, the rest left open.
struct Ring: View {
    var done: Int, urgent: Int, total: Int
    var body: some View {
        let t = CGFloat(max(total, 1))
        let gap: CGFloat = (done > 0 && urgent > 0) ? 0.02 : 0
        ZStack {
            Circle().stroke(Color(hex: 0x6e737c, 0.13), lineWidth: 10)
            Circle().trim(from: 0, to: max(0, CGFloat(done) / t - gap))
                .stroke(Color(hex: 0x418ef3), style: .init(lineWidth: 10, lineCap: .round)).rotationEffect(.degrees(-90))
            Circle().trim(from: CGFloat(done) / t, to: max(CGFloat(done) / t, CGFloat(done + urgent) / t - gap))
                .stroke(Color(hex: 0xf6d27c), style: .init(lineWidth: 10, lineCap: .round)).rotationEffect(.degrees(-90))
            VStack(spacing: 0) {
                (Text("\(done)").font(.app(34, .semibold)) + Text("/\(total)").font(.app(16)).foregroundStyle(Color.muted))
                    .foregroundStyle(Color.navy)
                Text("done").font(.meta).foregroundStyle(Color.muted)
            }
        }
        .frame(width: 150, height: 150)
        .animation(.snappy, value: done)
        .accessibilityElement().accessibilityLabel("\(done) of \(total) done, \(urgent) urgent")
    }
}

struct CheckInCard: View {
    @Environment(Store.self) private var store
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Eyebrow(text: "This week")
            switch store.checkIn {
            case nil:
                Text("How's your load feeling?").font(.app(17, .semibold)).foregroundStyle(Color.ink)
                Text("Only you see this. Shoal asks less of you when it's a lot.").font(.app(13)).foregroundStyle(Color.muted)
                VStack(spacing: 8) {
                    HStack(spacing: 8) { chip("Doing okay", .fine); chip("Stretched thin", .stretched) }
                    chip("I need a break", .onBreak)
                }
                .padding(.top, 6)
            case .fine?:
                reply("Glad to hear it.", "Nothing changes. We'll ask again Sunday.")
            case .stretched?:
                reply("That's a lot to carry.", "Pebble looked for someone with room.")
                if let s = store.stretchedSuggestion {
                    HStack(spacing: 10) {
                        Image("pebble_offer_open_hands").resizable().scaledToFit().frame(width: 32, height: 32)
                        Text("\(s.p.name) could take “\(s.task.n)”.").font(.app(14)).foregroundStyle(Color.ink)
                        Spacer()
                        Button("Ask") { store.pebbleHandoff(s.task.id) }.font(.app(14, .semibold))
                    }
                    .pearl(radius: 16, padding: 10)
                }
            case .onBreak?:
                reply("You're allowed to rest.", "New asks are held until Sunday. The family only knows if you tell them.")
                if store.toldFamily {
                    Text("The family knows you could use a hand.").font(.meta).foregroundStyle(Color.thanks)
                } else {
                    Button("Tell the family") { store.toldFamily = true; store.say("Told the family you could use a hand") }
                        .font(.app(14, .semibold))
                }
            }
            if store.checkIn != nil {
                Button("Change answer") { store.checkIn = nil; store.heldOpen = false }.font(.app(13, .medium)).padding(.top, 2)
            }
        }
        .glassCard()
    }

    private func reply(_ a: String, _ b: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(a).font(.app(17, .semibold)).foregroundStyle(Color.ink)
            Text(b).font(.app(13)).foregroundStyle(Color.muted)
        }
    }

    private func chip(_ l: String, _ c: CheckIn) -> some View {
        Button { withAnimation(.snappy) { store.checkIn = c } } label: {
            Text(l).font(.app(14, .medium)).foregroundStyle(Color.ink).lineLimit(1)
                .padding(.horizontal, 14).frame(maxWidth: .infinity).frame(height: 38)
                .background(.white.opacity(0.55), in: .capsule).overlay(Capsule().strokeBorder(.white))
                .shadow(color: Color(hex: 0x13315d, 0.06), radius: 6, y: 2)
                .contentShape(.capsule)
        }
        .buttonStyle(.plain)
    }
}
