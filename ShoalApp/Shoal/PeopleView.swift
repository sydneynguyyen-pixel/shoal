import SwiftUI

struct PeopleView: View {
    @Environment(Store.self) private var store
    @State private var invite = false
    @State private var pending: Person?

    var body: some View {
        let done = store.tasks.filter(\.done).count
        let open = store.active.filter { $0.who == nil }.count
        let circle = store.people.filter { $0.tier != .main }
        Page {
            HStack {
                Text("People").font(.title()).foregroundStyle(Color.navy)
                Spacer()
                Button { invite = true } label: {
                    Text("+ Invite").font(.app(14, .semibold)).foregroundStyle(Color.ink)
                        .padding(.horizontal, 14).frame(height: 36).background(.white.opacity(0.85), in: .capsule).overlay(Capsule().strokeBorder(.white))
                }
            }
            Text("October · \(done) of \(store.tasks.count) tasks done together").font(.body15).foregroundStyle(Color.muted)

            MonthEntry().padding(.top, 2)

            HStack {
                Eyebrow(text: "Family jars")
                Spacer()
                if open > 0 { Text("\(open) unassigned").font(.meta).foregroundStyle(Color.muted) }
            }
            .padding(.top, 10)
            HStack(spacing: 6) {
                ForEach(store.mainPeople) { p in
                    let n = store.mine(p.id).filter { !$0.done }.count
                    Button { store.go(.person(p.id)) } label: {
                        VStack(spacing: 2) {
                            Jar(who: p.id, width: store.mainPeople.count > 4 ? 330 / CGFloat(store.mainPeople.count) : 76)
                            Text(p.name).font(.app(13, .semibold)).foregroundStyle(Color.ink)
                            Text(p.invited ? "Invited" : n > 0 ? "\(n) to do" : store.mine(p.id).isEmpty ? "No tasks yet" : "All done").font(.app(12)).foregroundStyle(Color.muted)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(Pressable())
                }
            }

            VStack(spacing: 0) {
                ForEach(store.mainPeople) { p in
                    let ts = store.mine(p.id), d = ts.filter(\.done).count
                    if p.id != store.mainPeople.first?.id { RowSep() }
                    Button { if p.invited { pending = p } else { store.go(.person(p.id)) } } label: {
                        HStack(spacing: 12) {
                            Avatar(p: p, size: 38)
                                .opacity(p.invited ? 0.6 : 1)
                                .overlay(Circle().strokeBorder(Color(hex: 0x13315d, 0.28), style: .init(lineWidth: 1.5, dash: [3, 3])).padding(-4).opacity(p.invited ? 1 : 0))
                            VStack(alignment: .leading, spacing: 2) {
                                Text(p.name).font(.app(15.5, .semibold)).foregroundStyle(Color.ink)
                                Text(p.invited ? "\(viaShort(p)) · \(plural(ts.count, "task")) waiting" : "\(p.remote ? "Remote · " : "")\(d) of \(ts.count) done").font(.meta).foregroundStyle(Color.muted)
                            }
                            Spacer()
                            if p.invited {
                                Text("Pending").font(.app(13, .medium)).foregroundStyle(Color.ink)
                                    .padding(.horizontal, 12).frame(height: 30).background(.white.opacity(0.85), in: .capsule)
                                    .overlay(Capsule().strokeBorder(Color(hex: 0xdde1e6)))
                            } else {
                                MiniBar(f: Double(d) / Double(max(ts.count, 1)))
                            }
                            Chevron()
                        }
                        .padding(.vertical, 10)
                    }
                    .buttonStyle(Pressable())
                }
            }
            .glassCard(padding: 12)

            SectionH(text: "Extended circle")
            VStack(spacing: 0) {
                let tasks = circle.reduce(0) { $0 + store.mine($1.id).count }
                circleRow(icon: "person.2", title: "Trusted circle",
                          sub: circle.isEmpty ? "No one yet · \(plural(tasks, "task"))" : "\(circle[0].name)\(circle.count > 1 ? " + \(circle.count - 1) other\(circle.count > 2 ? "s" : "")" : "") · \(plural(tasks, "task"))",
                          badge: "On", stack: Array(circle.prefix(4))) { store.say("Trusted circle gets light tasks and a text when one opens up") }
                RowSep()
                circleRow(letter: "A", title: "Ana", sub: "Hospice nurse · see what she sees") { store.go(.care(nurse: true)) }
            }
            .glassCard(padding: 12)

            // What the family knows about the person they care for, apart from the people helping.
            SectionH(text: "About \(LOVED)")
            circleRow(icon: "heart", title: "\(LOVED)'s care", sub: "Meds, allergies, needs and preferences") { store.go(.care(nurse: false)) }
                .glassCard(padding: 12)
        }
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $invite) { InviteSheet(tier: .main) }
        .sheet(item: $pending) { p in PendingInviteSheet(p: p) }
    }
}

extension PeopleView {
    func circleRow(icon: String? = nil, letter: String? = nil, title: String, sub: String, badge: String? = nil, stack: [Person] = [], action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                ZStack {
                    Circle().fill(Color.blueTint)
                    if let icon { Image(systemName: icon).font(.system(size: 15, weight: .medium)).foregroundStyle(Color.shoalBlue) }
                    if let letter { Text(letter).font(.app(16, .semibold)).foregroundStyle(Color.shoalBlue) }
                }
                .frame(width: 38, height: 38)
                VStack(alignment: .leading, spacing: 3) {
                    Text(title).font(.app(15.5, .semibold)).foregroundStyle(Color.ink)
                    HStack(spacing: 6) {
                        if !stack.isEmpty {
                            HStack(spacing: -6) { ForEach(stack) { Avatar(p: $0, size: 20) } }
                        }
                        Text(sub).font(.meta).foregroundStyle(Color.muted).lineLimit(1)
                    }
                }
                Spacer(minLength: 4)
                if let badge { Badge(text: badge) }
                Chevron()
            }
            .padding(.vertical, 10)
            .contentShape(.rect)
        }
        .buttonStyle(Pressable())
    }
}

// Small done bar on a person row.
struct MiniBar: View {
    var f: Double
    var body: some View {
        Capsule().fill(Color(hex: 0x418ef3, 0.18)).frame(width: 62, height: 5)
            .overlay(alignment: .leading) { Capsule().fill(Color.shoalBlue).frame(width: max(5, 62 * f), height: 5) }
    }
}

struct PersonView: View {
    @Environment(Store.self) private var store
    var id: String
    @State private var moving = false
    @State private var moveTask: CareTask?

    var body: some View {
        if let p = store.person(id) {
            let ts = store.mine(id).filter { !$0.done }
            let load = store.load(id)
            Page {
                HStack(spacing: 14) {
                    Avatar(p: p, size: 64)
                    Text(p.id == "you" ? "You" : p.name).font(.title()).foregroundStyle(Color.navy)
                }
                Text(p.about).font(.body15).foregroundStyle(Color.muted)

                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 8) {
                        Eyebrow(text: "This week")
                        HStack(spacing: 10) {
                            ZStack {
                                Circle().stroke(Color(hex: 0x6e737c, 0.13), lineWidth: 5)
                                Circle().trim(from: 0, to: min(1, CGFloat(load) / CGFloat(max(p.cap, 1))))
                                    .stroke(load > p.cap ? Color(hex: 0xd9a23a) : Color.shoalBlue, style: .init(lineWidth: 5, lineCap: .round)).rotationEffect(.degrees(-90))
                            }
                            .frame(width: 38, height: 38)
                            (Text("\(load)").font(.app(24, .semibold)).foregroundStyle(Color.navy)
                             + Text(" of \(p.cap) hrs").font(.meta).foregroundStyle(Color.muted))
                        }
                        Text(load > p.cap ? "More than they said they have" : "\(plural(p.cap - load, "hr")) of room left").font(.app(12)).foregroundStyle(Color.muted)
                    }
                    .glassCard(radius: 22, padding: 14)
                    if !p.best.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Eyebrow(text: "Best time to ask")
                            Text(p.best).font(.app(22, .semibold)).foregroundStyle(Color.navy).lineLimit(1).minimumScaleFactor(0.7)
                            Text("Prefers \(p.reach.lowercased())").font(.app(12)).foregroundStyle(Color.muted)
                        }
                        .frame(maxHeight: .infinity, alignment: .top)
                        .glassCard(radius: 22, padding: 14)
                    }
                }
                .fixedSize(horizontal: false, vertical: true)

                if p.id != "you" {
                    HStack(spacing: 12) {
                        Avatar(p: p, size: 36)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(p.contact.isEmpty ? "In Shoal" : p.contact).font(.app(15.5, .semibold)).foregroundStyle(Color.ink)
                            Text(p.reach.isEmpty ? "Gets asks in the app" : "\(p.reach) works best").font(.meta).foregroundStyle(Color.muted)
                        }
                        Spacer()
                        if !p.contact.isEmpty {
                            pill("Text") { openContact("sms", p.contact, store) }
                            pill("Call") { openContact("tel", p.contact, store) }
                        }
                    }
                    .glassCard(padding: 14)
                }

                if !p.know.isEmpty {
                    SectionH(text: "Good to know")
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(p.know, id: \.self) { k in
                            HStack(alignment: .top, spacing: 10) {
                                Circle().fill(Color(hex: 0x98c4ec)).frame(width: 6, height: 6).padding(.top, 7)
                                Text(k).font(.body15).foregroundStyle(Color.ink)
                            }
                        }
                    }
                    .glassCard()
                }

                SectionH(text: "Their tasks, and why")
                VStack(spacing: 0) {
                    if ts.isEmpty {
                        Text("Nothing on \(p.name)'s plate right now.").font(.meta).foregroundStyle(Color.muted).padding(.vertical, 14)
                    }
                    ForEach(ts) { t in
                        if t.id != ts.first?.id { RowSep() }
                        TaskLine(t: t, showWho: false, meta: "\(t.dueLabel) · Why: \(why(t, p))")
                    }
                }
                .glassCard(padding: 12)

                HStack(spacing: 10) {
                    Image(systemName: "lock").foregroundStyle(Color.muted)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("What Pebble used").font(.app(13, .semibold)).foregroundStyle(Color.sectionInk)
                        Text("Everyone's answers and \(LOVED)'s goals. Not notes or medical records.").font(.meta).foregroundStyle(Color.muted)
                    }
                }
                .padding(.horizontal, 4).padding(.top, 6)

                if !ts.isEmpty {
                    Button(p.id == "you" ? "Hand one of yours off" : "Move one of \(p.name)'s tasks") { moving = true }
                        .buttonStyle(GhostButton()).padding(.top, 10)
                    Text(p.id == "you" ? "Ask someone else to take it." : "Ask someone else to take it, so \(p.name) has less to carry.")
                        .font(.meta).foregroundStyle(Color.muted).frame(maxWidth: .infinity)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .confirmationDialog("Which one should move?", isPresented: $moving, titleVisibility: .visible) {
                ForEach(ts) { t in
                    Button(t.n) { store.go(.handoff(t.id, step: nil)) }
                }
                Button("Cancel", role: .cancel) {}
            }
        }
    }

    private func why(_ t: CareTask, _ p: Person) -> String {
        if !t.why.isEmpty { return t.why }
        if p.remote || t.remote { return "Can do it from anywhere" }
        return ["meds": "Knows the routine", "drive": "Has a car", "cook": "Likes to cook", "there": "Lives close", "phone": "Free during the day", "paper": "Good with forms"][t.cat] ?? "Had free time then"
    }

    private func pill(_ l: String, _ a: @escaping () -> Void) -> some View {
        Button(l, action: a).font(.app(14, .semibold))
            .padding(.horizontal, 14).frame(height: 34).background(Color.blueTint, in: .capsule)
    }
}

// Text and Call open Messages and Phone. The simulator has neither, so it says so instead.
@MainActor func openContact(_ scheme: String, _ number: String, _ store: Store) {
    guard let u = URL(string: "\(scheme):\(number.filter(\.isNumber))") else { return }
    UIApplication.shared.open(u) { ok in
        if !ok { store.say(scheme == "sms" ? "Messages isn't available on this device" : "Calling isn't available on this device") }
    }
}
