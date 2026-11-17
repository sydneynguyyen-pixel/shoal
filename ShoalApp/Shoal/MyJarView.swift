import SwiftUI

struct MyJarView: View {
    @Environment(Store.self) private var store
    @State private var tab: Kind? = nil
    @State private var showDone = false
    @State private var reviewing: Request?

    var body: some View {
        let all = store.mine("you")
        let live = all.filter { !$0.done }
        let done = all.filter(\.done)
        let urgent = live.filter(\.urgent)
        let today = live.filter { $0.occurs(on: TODAY) || $0.urgent }.count
        let shown = live.filter { tab == nil || $0.kind == tab }
            .sorted { (order($0), $0.date) < (order($1), $1.date) }
        let onBreak = store.checkIn == .onBreak && !store.heldOpen

        Page {
            HStack {
                Text("Your jar").font(.title()).foregroundStyle(Color.navy)
                Spacer()
                Button { store.go(.newTask) } label: {
                    Image(systemName: "plus").font(.system(size: 15, weight: .regular)).foregroundStyle(Color.ink).frame(width: 44, height: 44)
                        .background(.white.opacity(0.85), in: .circle).overlay(Circle().strokeBorder(.white))
                        .shadow(color: Color(hex: 0x13315d, 0.08), radius: 10, y: 4)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Add a task")
            }
            VStack(spacing: 6) {
                Jar(who: "you", width: 120)
                Text(live.isEmpty ? (store.mine("you").isEmpty ? "No tasks yet" : "All done") : "\(live.count) to do").font(.app(14)).foregroundStyle(Color.muted)
            }
            .frame(maxWidth: .infinity).padding(.top, 4)
            HStack(spacing: 0) {
                stat("\(today)", "today", .ink)
                Rectangle().fill(Color(hex: 0xe3e1dc, 0.8)).frame(width: 1, height: 36)
                stat("\(urgent.count)", "urgent", .amber)
                Rectangle().fill(Color(hex: 0xe3e1dc, 0.8)).frame(width: 1, height: 36)
                stat("\(live.count)", "left", .ink)
            }
            .padding(.bottom, 8)

            if store.ringOn {
                HStack { Spacer(); Ring(done: done.count, urgent: urgent.count, total: all.count); Spacer() }
                    .glassCard()
            }

            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 22) {
                    utab("All", live.count, nil)
                    utab("One-time", live.filter { $0.kind == .once }.count, .once)
                    utab("Ongoing", live.filter { $0.kind == .repeating }.count, .repeating)
                    Spacer()
                }
                .overlay(alignment: .bottom) { Rectangle().fill(Color(hex: 0xe3e1dc, 0.8)).frame(height: 1) }
                .padding(.bottom, 2)

                if tab != .repeating {
                    if onBreak && !store.requests.isEmpty {
                        requestRow(eyebrow: "On hold till Sunday", title: "\(plural(store.requests.count, "ask")) waiting", cta: "See") { store.heldOpen = true }
                    } else {
                        ForEach(store.requests) { r in
                            requestRow(eyebrow: "Request from \(store.name(r.from))", title: r.n, cta: "Review") { reviewing = r }
                        }
                    }
                }
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
                if shown.isEmpty { Text("Nothing here. Tap + to add a task.").font(.meta).foregroundStyle(Color.muted).padding(.vertical, 14) }
            }
            .glassCard()

            if !done.isEmpty {
                Button { withAnimation(.snappy) { showDone.toggle() } } label: {
                    HStack { Text("Done · \(done.count)").font(.app(14, .semibold)).foregroundStyle(Color.sectionInk)
                        Image(systemName: "chevron.right").font(.system(size: 12, weight: .semibold)).rotationEffect(.degrees(showDone ? 90 : 0)).foregroundStyle(Color.muted) }
                    .padding(.horizontal, 4).padding(.top, 6)
                }
                .buttonStyle(.plain)
                if showDone {
                    VStack(spacing: 0) { ForEach(done) { t in if t.id != done.first?.id { RowSep() }; TaskLine(t: t, showWho: false, meta: "Done") } }.glassCard()
                }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
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

    private func stat(_ n: String, _ l: String, _ c: Color) -> some View {
        VStack(spacing: 1) {
            Text(n).font(.app(22, .semibold)).foregroundStyle(c).monospacedDigit()
            Text(l).font(.app(14)).foregroundStyle(Color.muted)
        }
        .frame(maxWidth: .infinity)
    }

    // Underlined tabs: the picked one in ink with a 2pt rule under it.
    private func utab(_ l: String, _ n: Int, _ k: Kind?) -> some View {
        let on = tab == k
        return Button { withAnimation(.snappy) { tab = k } } label: {
            HStack(alignment: .firstTextBaseline, spacing: 5) {
                Text(l).font(.app(16, on ? .semibold : .medium)).foregroundStyle(on ? Color.ink : Color.muted)
                Text("\(n)").font(.app(12, .semibold)).foregroundStyle(Color.muted.opacity(0.8)).monospacedDigit()
            }
            .frame(height: 46)
            .overlay(alignment: .bottom) { if on { Capsule().fill(Color.ink).frame(height: 2) } }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(on ? [.isSelected] : [])
    }

    private func requestRow(eyebrow: String, title: String, cta: String, action: @escaping () -> Void) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Eyebrow(text: eyebrow, color: .shoalBlue)
                Text(title).font(.app(16, .semibold)).foregroundStyle(Color.ink)
            }
            Spacer()
            Button(cta, action: action).font(.app(13, .semibold)).foregroundStyle(Color.shoalBlue)
        }
        .padding(.vertical, 14)
        .overlay(alignment: .bottom) { RowSep() }
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
