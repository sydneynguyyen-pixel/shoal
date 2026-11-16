import SwiftUI

struct PeopleView: View {
    @Environment(Store.self) private var store
    @State private var invite = false

    var body: some View {
        let done = store.tasks.filter(\.done).count
        let open = store.active.filter { $0.who == nil }.count
        let circle = store.people.filter { $0.tier != .main }
        Page {
            HStack {
                Text("People").font(.title()).foregroundStyle(Color.navy)
                Spacer()
                Button { invite = true } label: {
                    Text("+ Invite").font(.system(size: 14, weight: .semibold)).foregroundStyle(Color.ink)
                        .padding(.horizontal, 14).frame(height: 36).background(.white.opacity(0.85), in: .capsule).overlay(Capsule().strokeBorder(.white))
                }
            }
            Text("October · \(done) of \(store.tasks.count) tasks done together").font(.body15).foregroundStyle(Color.muted)

            HStack {
                Eyebrow(text: "Family jars")
                Spacer()
                if open > 0 { Text("\(open) unassigned").font(.meta).foregroundStyle(Color.muted) }
            }
            .padding(.top, 10)
            HStack(spacing: 6) {
                ForEach(store.mainPeople) { p in
                    Button { store.go(.person(p.id)) } label: {
                        VStack(spacing: 2) {
                            Jar(who: p.id, width: store.mainPeople.count > 4 ? 330 / CGFloat(store.mainPeople.count) : 76)
                            Text(p.name).font(.system(size: 13, weight: .semibold)).foregroundStyle(Color.ink)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(Pressable())
                }
            }
            MonthEntry().padding(.top, 6)

            VStack(spacing: 0) {
                ForEach(store.mainPeople) { p in
                    let ts = store.mine(p.id), d = ts.filter(\.done).count
                    Button { store.go(.person(p.id)) } label: {
                        HStack(spacing: 12) {
                            Avatar(p: p, size: 38)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(p.name).font(.system(size: 15.5, weight: .semibold)).foregroundStyle(Color.ink)
                                Text("\(p.remote ? "Remote · " : "")\(d) of \(ts.count) done").font(.meta).foregroundStyle(Color.muted)
                            }
                            Spacer()
                            ProgressView(value: Double(d), total: Double(max(ts.count, 1))).tint(.shoalBlue).frame(width: 54)
                            Chevron()
                        }
                        .padding(.vertical, 10)
                    }
                    .buttonStyle(Pressable())
                    if p.id != store.mainPeople.last?.id { Divider() }
                }
            }
            .glassCard(padding: 12)

            SectionH(text: "Extended circle")
            VStack(spacing: 0) {
                ForEach(circle) { p in
                    Button { store.go(.person(p.id)) } label: {
                        HStack(spacing: 12) {
                            Avatar(p: p, size: 38)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(p.name).font(.system(size: 15.5, weight: .semibold)).foregroundStyle(Color.ink)
                                Text("\(p.tier.label) · \(plural(store.mine(p.id).filter { !$0.done }.count, "task"))").font(.meta).foregroundStyle(Color.muted)
                            }
                            Spacer()
                            Badge(text: "Light tasks")
                            Chevron()
                        }
                        .padding(.vertical, 10)
                    }
                    .buttonStyle(Pressable())
                }
            }
            .glassCard(padding: 12)
            Text("The trusted circle gets small tasks, and a text when one opens up.").font(.meta).foregroundStyle(Color.muted).padding(.horizontal, 4)
        }
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $invite) {
            VStack(alignment: .leading, spacing: 14) {
                Text("Invite someone").font(.title(26)).foregroundStyle(Color.navy)
                Text("They get a link by text. Family gets a jar; the trusted circle gets light tasks only.").font(.body15).foregroundStyle(Color.muted)
                ShareLink(item: URL(string: "https://shoal.example/join/K7Q2")!, message: Text("Join our family on Shoal")) {
                    Text("Share invite link")
                }
                .buttonStyle(PrimaryButton())
            }
            .padding(24)
            .presentationDetents([.height(260)])
        }
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
                            (Text("\(load)").font(.system(size: 24, weight: .semibold)).foregroundStyle(Color.navy)
                             + Text(" of \(p.cap) hrs").font(.meta).foregroundStyle(Color.muted))
                        }
                        Text(load > p.cap ? "More than they said they have" : "\(plural(p.cap - load, "hr")) of room left").font(.system(size: 12)).foregroundStyle(Color.muted)
                    }
                    .glassCard(radius: 22, padding: 14)
                    if !p.best.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Eyebrow(text: "Best time to ask")
                            Text(p.best).font(.system(size: 22, weight: .semibold)).foregroundStyle(Color.navy).lineLimit(1).minimumScaleFactor(0.7)
                            Text("Prefers \(p.reach.lowercased())").font(.system(size: 12)).foregroundStyle(Color.muted)
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
                            Text(p.contact.isEmpty ? "In Shoal" : p.contact).font(.system(size: 15.5, weight: .semibold)).foregroundStyle(Color.ink)
                            Text(p.reach.isEmpty ? "Gets asks in the app" : "\(p.reach) works best").font(.meta).foregroundStyle(Color.muted)
                        }
                        Spacer()
                        if !p.contact.isEmpty {
                            pill("Text") { store.say("Opening Messages for \(p.name)") }
                            pill("Call") { store.say("Calling \(p.name)…") }
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
                        TaskLine(t: t, showWho: false, meta: "\(t.dueLabel) · Why: \(why(t, p))")
                        if t.id != ts.last?.id { Divider() }
                    }
                }
                .glassCard(padding: 12)

                HStack(spacing: 10) {
                    Image(systemName: "lock").foregroundStyle(Color.muted)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("What Pebble used").font(.system(size: 13, weight: .semibold)).foregroundStyle(Color.sectionInk)
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
        Button(l, action: a).font(.system(size: 14, weight: .semibold))
            .padding(.horizontal, 14).frame(height: 34).background(Color.blueTint, in: .capsule)
    }
}
