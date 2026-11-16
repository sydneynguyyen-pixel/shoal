import SwiftUI

struct HomeView: View {
    @Environment(Store.self) private var store

    var body: some View {
        let urgent = store.active.filter(\.urgent).sorted { $0.date < $1.date }
        let finished = store.tasks.first { $0.done && $0.doneAt != nil && $0.who != "you" && !store.thanked.contains($0.id) && !store.dismissed.contains($0.id) }
        Page {
            HStack {
                Text(TODAY.formatted(.dateTime.weekday(.wide).month(.wide).day()).uppercased())
                    .font(.system(size: 11, weight: .semibold)).tracking(0.88).foregroundStyle(Color.muted)
                Spacer()
                Button { store.go(.newTask) } label: {
                    Image(systemName: "plus").font(.system(size: 17, weight: .semibold)).frame(width: 40, height: 40)
                        .background(.white.opacity(0.7), in: .circle).overlay(Circle().strokeBorder(.white))
                }
                .accessibilityLabel("New task")
            }
            Text("Good morning").font(.title()).foregroundStyle(Color.navy).padding(.bottom, 4)

            SetupCard()

            if let u = urgent.first {
                Button { store.go(.task(u.id)) } label: {
                    HStack(spacing: 14) {
                        u.stone(base: 50)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(u.n).font(.system(size: 16, weight: .semibold)).foregroundStyle(Color.ink).multilineTextAlignment(.leading)
                            (Text("Urgent").bold().foregroundStyle(Color.amber) + Text(" · \(u.dueLabel) · \(store.name(u.who))").foregroundStyle(Color.muted)).font(.meta)
                        }
                        Spacer()
                        if urgent.count > 1 {
                            Text("+\(urgent.count - 1)").font(.system(size: 13, weight: .semibold)).foregroundStyle(Color.amber)
                                .padding(.horizontal, 9).padding(.vertical, 4).background(Color(hex: 0xf6d27c, 0.3), in: .capsule)
                        } else { Chevron() }
                    }
                    .glassCard()
                }
                .buttonStyle(Pressable())
            }

            if let f = finished, let p = store.person(f.who) {
                HStack(spacing: 10) {
                    Avatar(p: p, size: 24)
                    (Text(p.name).bold() + Text(" finished “\(f.n)”")).font(.system(size: 14)).foregroundStyle(Color.ink).lineLimit(2)
                    Spacer()
                    Button("Thank") { store.thanked.insert(f.id); store.say("Sent \(p.name) a thank-you") }
                        .font(.system(size: 14, weight: .semibold)).foregroundStyle(Color.thanks)
                    Button { store.dismissed.insert(f.id) } label: { Image(systemName: "xmark").font(.system(size: 12, weight: .bold)).foregroundStyle(Color.muted) }
                        .accessibilityLabel("Dismiss")
                }
                .glassCard(radius: 18, padding: 12)
            }

            PebbleHomeCard()

            SectionH(text: "Family jars")
            let jarW: CGFloat = store.mainPeople.count > 4 ? 330 / CGFloat(store.mainPeople.count) : 76
            HStack(alignment: .top, spacing: 0) {
                ForEach(store.mainPeople) { p in
                    Button { store.go(.person(p.id)) } label: {
                        VStack(spacing: 3) {
                            Jar(who: p.id, width: jarW, lit: store.kit == true ? store.glow.lit : 1)
                            Text(p.name).font(.system(size: 13.5, weight: .semibold)).foregroundStyle(Color.ink).padding(.top, 2)
                            let n = store.mine(p.id).filter { !$0.done }.count
                            Text(n > 0 ? "\(n) to do" : "All done").font(.system(size: 12)).foregroundStyle(Color.muted)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(Pressable())
                }
            }

            if store.kit == true {
                let out = store.stones.filter(\.out).count
                Button { store.go(.kit) } label: {
                    HStack(spacing: 12) {
                        KitRing(f: Double(store.stones.count - out) / Double(store.stones.count), size: 40, line: 4, tint: Color.shoalBlue)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Home kit").font(.system(size: 15.5, weight: .semibold)).foregroundStyle(Color.ink)
                            Text(out > 0 ? "\(plural(out, "stone")) off power" : "Glow \(store.glow == .on ? "on" : store.glow == .dim ? "dim" : "off") · charging")
                                .font(.meta).foregroundStyle(out > 0 ? Color.amber : Color.muted)
                        }
                        Spacer(); Chevron()
                    }
                    .glassCard(padding: 14)
                }
                .buttonStyle(Pressable())
            }

            SectionH(text: "\(LOVED)'s care")
            CareHomeCard()

            SectionH(text: "This week")
            WeekCard()
        }
        .toolbar(.hidden, for: .navigationBar)
    }
}

struct WeekCard: View {
    @Environment(Store.self) private var store
    var body: some View {
        let week = (0..<7).map { addDays($0, to: monday) }
        let counts = week.map { d in store.active.filter { $0.occurs(on: d) }.count }
        let mx = max(1, counts.max() ?? 1)
        let heavyN = counts.max() ?? 0
        let heavy = week[counts.firstIndex(of: heavyN) ?? 0]
        let today = store.active.filter { $0.occurs(on: store.day) }
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .bottom, spacing: 0) {
                ForEach(Array(week.enumerated()), id: \.offset) { i, d in
                    let on = Calendar.current.isDate(d, inSameDayAs: store.day)
                    let isToday = Calendar.current.isDate(d, inSameDayAs: TODAY)
                    let hasUrgent = store.active.contains { $0.urgent && $0.occurs(on: d) }
                    Button { withAnimation(.snappy) { store.day = d } } label: {
                        VStack(spacing: 5) {
                            if hasUrgent { Stone(state: .urgent, w: .small, base: 18) } else { Color.clear.frame(height: 10) }
                            RoundedRectangle(cornerRadius: 5)
                                .fill(counts[i] == heavyN && heavyN > 0 ? Color(hex: 0x98c4ec) : Color(hex: 0xd3e9fc))
                                .frame(width: 22, height: max(8, CGFloat(counts[i]) / CGFloat(mx) * 70))
                            Text(String(dayKey(d).prefix(1))).font(.system(size: 11)).foregroundStyle(Color.muted)
                            Text("\(Calendar.current.component(.day, from: d))").font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(on ? .white : isToday ? Color.shoalBlue : Color.ink)
                                .frame(width: 30, height: 30).background(on ? Color.shoalBlue : .clear, in: .circle)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(DAY_FULL[dayKey(d)]!) \(Calendar.current.component(.day, from: d)), \(plural(counts[i], "task"))")
                }
            }
            Text(heavyN > 0 ? "\(DAY_FULL[dayKey(heavy)]!) is the heavy day · \(plural(heavyN, "task"))" : "A light week")
                .font(.meta).foregroundStyle(Color.muted).padding(.leading, 4)
            Divider().padding(.vertical, 4)
            if today.isEmpty {
                Text("Nothing on \(DAY_FULL[dayKey(store.day)]!).").font(.meta).foregroundStyle(Color.muted).padding(.vertical, 12)
            } else {
                ForEach(today) { t in TaskLine(t: t) }
            }
        }
        .glassCard()
    }

    private var monday: Date { addDays(-((Calendar.current.component(.weekday, from: TODAY) + 5) % 7)) }
}

// Pebble's one suggestion on Home, on pearl.
struct PebbleHomeCard: View {
    @Environment(Store.self) private var store
    var body: some View {
        if store.pebbleOn, let t = store.active.first(where: { $0.who == nil }) {
            let pick = store.pebblePick(t)
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top, spacing: 12) {
                    Image("pebble_think_01").resizable().scaledToFit().frame(width: 44, height: 44)
                    VStack(alignment: .leading, spacing: 3) {
                        Eyebrow(text: "Pebble noticed", color: .pearlInk)
                        Text("“\(t.n)” still needs someone.").font(.system(size: 15, weight: .semibold)).foregroundStyle(Color.ink)
                        if let pick { Text("\(pick.p.name) has \(pick.why).").font(.meta).foregroundStyle(Color.muted) }
                    }
                }
                HStack(spacing: 8) {
                    PearlChip(label: "Find someone") { store.pebbleHandoff(t.id) }
                    Button("Take it") { store.take(t.id) }.font(.system(size: 14, weight: .semibold)).padding(.horizontal, 10)
                }
            }
            .pearl()
        }
    }
}
