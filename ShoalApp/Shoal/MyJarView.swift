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
                    Image(systemName: "plus").font(.system(size: 17, weight: .semibold)).frame(width: 40, height: 40)
                        .background(.white.opacity(0.7), in: .circle).overlay(Circle().strokeBorder(.white))
                }
                .accessibilityLabel("Add a task")
            }
            HStack { Spacer(); Jar(who: "you", width: 120); Spacer() }
            HStack(spacing: 22) {
                stat("\(today)", "today", .ink)
                stat("\(urgent.count)", "urgent", .amber)
                stat("\(live.count)", "left", .ink)
            }
            .frame(maxWidth: .infinity)

            if store.ringOn {
                HStack { Spacer(); Ring(done: done.count, urgent: urgent.count, total: all.count); Spacer() }
                    .glassCard()
            } else {
                CheckInCard()
            }

            VStack(alignment: .leading, spacing: 0) {
                Picker("Show", selection: $tab) {
                    Text("All \(live.count)").tag(Kind?.none)
                    Text("One-time \(live.filter { $0.kind == .once }.count)").tag(Kind?.some(.once))
                    Text("Ongoing \(live.filter { $0.kind == .repeating }.count)").tag(Kind?.some(.repeating))
                }
                .pickerStyle(.segmented).padding(.bottom, 8)

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
                    HStack { Text("Done · \(done.count)").font(.system(size: 14, weight: .semibold)).foregroundStyle(Color.sectionInk)
                        Image(systemName: "chevron.right").font(.system(size: 12, weight: .semibold)).rotationEffect(.degrees(showDone ? 90 : 0)).foregroundStyle(Color.muted) }
                    .padding(.horizontal, 4).padding(.top, 6)
                }
                .buttonStyle(.plain)
                if showDone {
                    VStack(spacing: 0) { ForEach(done) { t in TaskLine(t: t, showWho: false, meta: "Done") } }.glassCard()
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
                Button("Decide later") { reviewing = nil }.font(.system(size: 15, weight: .semibold)).frame(maxWidth: .infinity).padding(.top, 4)
            }
            .padding(24)
            .presentationDetents([.height(320)])
        }
    }

    private func order(_ t: CareTask) -> Int { t.urgent ? 0 : t.kind == .once ? 1 : 2 }

    private func stat(_ n: String, _ l: String, _ c: Color) -> some View {
        HStack(spacing: 4) { Text(n).font(.system(size: 15, weight: .bold)).foregroundStyle(c); Text(l).font(.meta).foregroundStyle(Color.muted) }
    }

    private func requestRow(eyebrow: String, title: String, cta: String, action: @escaping () -> Void) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Eyebrow(text: eyebrow, color: .shoalBlue)
                Text(title).font(.system(size: 15.5, weight: .semibold)).foregroundStyle(Color.ink)
            }
            Spacer()
            Button(cta, action: action).font(.system(size: 14, weight: .semibold))
        }
        .padding(12)
        .background(Color.blueTint, in: .rect(cornerRadius: 14))
        .padding(.bottom, 6)
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
                (Text("\(done)").font(.system(size: 34, weight: .semibold)) + Text("/\(total)").font(.system(size: 16)).foregroundStyle(Color.muted))
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
                Text("How's your load feeling?").font(.title(22)).foregroundStyle(Color.navy)
                Text("Only you see this. Shoal asks less of you when it's a lot.").font(.meta).foregroundStyle(Color.muted)
                HStack(spacing: 8) {
                    chip("Doing okay", .fine); chip("Stretched thin", .stretched); chip("I need a break", .onBreak)
                }
                .padding(.top, 4)
            case .fine?:
                reply("Glad to hear it.", "Nothing changes. We'll ask again Sunday.")
            case .stretched?:
                reply("That's a lot to carry.", "Pebble looked for someone with room.")
                if let s = store.stretchedSuggestion {
                    HStack(spacing: 10) {
                        Image("pebble_offer_open_hands").resizable().scaledToFit().frame(width: 32, height: 32)
                        Text("\(s.p.name) could take “\(s.task.n)”.").font(.system(size: 14)).foregroundStyle(Color.ink)
                        Spacer()
                        Button("Ask") { store.pebbleHandoff(s.task.id) }.font(.system(size: 14, weight: .semibold))
                    }
                    .pearl(radius: 16, padding: 10)
                }
            case .onBreak?:
                reply("You're allowed to rest.", "New asks are held until Sunday. The family only knows if you tell them.")
                if store.toldFamily {
                    Text("The family knows you could use a hand.").font(.meta).foregroundStyle(Color.thanks)
                } else {
                    Button("Tell the family") { store.toldFamily = true; store.say("Told the family you could use a hand") }
                        .font(.system(size: 14, weight: .semibold))
                }
            }
            if store.checkIn != nil {
                Button("Change answer") { store.checkIn = nil; store.heldOpen = false }.font(.system(size: 13, weight: .medium)).padding(.top, 2)
            }
        }
        .glassCard()
    }

    private func reply(_ a: String, _ b: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(a).font(.title(22)).foregroundStyle(Color.navy)
            Text(b).font(.meta).foregroundStyle(Color.muted)
        }
    }

    private func chip(_ l: String, _ c: CheckIn) -> some View {
        Button { withAnimation(.snappy) { store.checkIn = c } } label: {
            Text(l).font(.system(size: 13, weight: .semibold)).foregroundStyle(Color.ink).lineLimit(1).minimumScaleFactor(0.85)
                .padding(.horizontal, 10).frame(height: 34).background(.white.opacity(0.9), in: .capsule).overlay(Capsule().strokeBorder(Color(hex: 0xdde1e6)))
        }
        .buttonStyle(.plain)
    }
}
