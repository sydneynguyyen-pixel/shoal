import SwiftUI

struct HomeView: View {
    @Environment(Store.self) private var store
    @State private var notesOpen = false
    @State private var stackOpen = false

    var body: some View {
        let urgent = store.active.filter(\.urgent).sorted { $0.date < $1.date }
        let finished = store.tasks.first { $0.done && $0.doneAt != nil && $0.who != "you" && !store.thanked.contains($0.id) && !store.dismissed.contains($0.id) }
        Page {
            HStack {
                ShoalMark(s: 30)
                Spacer()
                Button { notesOpen = true } label: {
                    Image("icon-bell").resizable().frame(width: 22, height: 22).foregroundStyle(Color.navy)
                        .frame(width: 44, height: 44)
                        .overlay(alignment: .topTrailing) {
                            if !urgent.isEmpty || finished != nil {
                                Circle().fill(Color(hex: 0xf2b84b)).frame(width: 10, height: 10)
                                    .overlay(Circle().strokeBorder(.white, lineWidth: 2)).offset(x: -10, y: 10)
                            }
                        }
                }
                .accessibilityLabel("Notifications")
            }
            .padding(.bottom, 2)

            NoteStack(urgent: urgent, finished: finished, open: $stackOpen)

            Text(TODAY.formatted(.dateTime.weekday(.wide).month(.wide).day()).uppercased())
                .font(.app(11, .semibold)).tracking(0.88).foregroundStyle(Color.muted)
            Text("Good morning").font(.title()).foregroundStyle(Color.navy).padding(.bottom, 4)

            SetupCard()

            // A new account sees just the next step; the jars and widgets come in once there are tasks.
            if !store.tasks.isEmpty {
            let jarW: CGFloat = store.mainPeople.count > 4 ? 330 / CGFloat(store.mainPeople.count) : 76
            HStack(alignment: .top, spacing: 0) {
                ForEach(store.mainPeople) { p in
                    Button { store.go(.person(p.id)) } label: {
                        VStack(spacing: 3) {
                            Jar(who: p.id, width: jarW, lit: store.kit == true ? store.glow.lit : 1)
                            Text(p.name).font(.app(13.5, .semibold)).foregroundStyle(Color.ink).padding(.top, 2)
                            let n = store.mine(p.id).filter { !$0.done }.count
                            Text(p.invited ? "Invited" : n > 0 ? "\(n) to do" : store.mine(p.id).isEmpty ? "No tasks yet" : "All done").font(.app(12)).foregroundStyle(Color.muted)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(Pressable())
                }
            }
            .padding(.vertical, 10)

            HStack(spacing: 12) {
                JarTile()
                if store.kit == true { KitTile() } else { PeopleTile() }
            }

            CareHomeCard()

            WeekCard()
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $notesOpen) { NotesSheet(urgent: urgent, finished: finished) }
    }
}

// The round chevron in a widget's top corner.
struct GoDot: View {
    var dark = false
    var body: some View {
        Image(systemName: "chevron.right").font(.system(size: 11, weight: .bold))
            .foregroundStyle(dark ? .white.opacity(0.7) : Color(hex: 0xa3a9b3))
            .frame(width: 30, height: 30).background(dark ? Color.white.opacity(0.12) : Color(hex: 0xf1f0ec), in: .circle)
    }
}

// A Home widget: frosted white, or night blue for the kit.
struct HomeTile: ViewModifier {
    var dark = false
    func body(content: Content) -> some View {
        content
            .padding(16).frame(maxWidth: .infinity, alignment: .leading)
            .background {
                if dark {
                    ZStack {
                        LinearGradient(colors: [Color(hex: 0x142a4c), Color(hex: 0x0b1730)], startPoint: .top, endPoint: .bottom)
                        RadialGradient(colors: [Color(hex: 0x2b5288), Color(hex: 0x2b5288, 0)], center: .topLeading, startRadius: 0, endRadius: 190)
                    }
                    .clipShape(.rect(cornerRadius: 26))
                } else {
                    RoundedRectangle(cornerRadius: 26).fill(.white.opacity(0.72))
                }
            }
            .overlay(RoundedRectangle(cornerRadius: 26).strokeBorder(.white.opacity(dark ? 0.08 : 0.9)))
            .shadow(color: Color(hex: 0x13315d, 0.12), radius: 13, y: 10)
    }
}
extension View { func homeTile(dark: Bool = false) -> some View { modifier(HomeTile(dark: dark)) } }

struct TileTop: View {
    var label: String
    var dark = false
    var body: some View {
        HStack {
            Text(label).font(.app(14, .semibold)).foregroundStyle(dark ? Color(hex: 0xf1f5fb) : Color.ink)
            Spacer()
            GoDot(dark: dark)
        }
        .frame(minHeight: 34)
    }
}

struct JarTile: View {
    @Environment(Store.self) private var store
    var body: some View {
        let all = store.mine("you"), left = all.filter { !$0.done }, urg = left.filter(\.urgent).count
        Button { store.tab = 1 } label: {
            VStack(alignment: .leading, spacing: 0) {
                TileTop(label: "Your jar")
                Spacer(minLength: 14)
                HStack(spacing: 10) {
                    KitRing(f: all.isEmpty ? 0 : Double(all.count - left.count) / Double(all.count), size: 46, line: 4, tint: Color.shoalBlue)
                    Text("\(left.count)").font(.app(34, .semibold)).tracking(-0.7).monospacedDigit().foregroundStyle(Color.ink)
                }
                (Text(left.count == 1 ? "task to do" : "tasks to do").foregroundStyle(Color.muted)
                 + (urg > 0 ? Text(" · ") .foregroundStyle(Color.muted) + Text("\(urg) urgent").foregroundStyle(Color.amber) : Text("")))
                    .font(.app(12.5)).padding(.top, 4)
            }
            .frame(minHeight: 118, alignment: .top)
            .homeTile()
        }
        .buttonStyle(Pressable())
    }
}

struct KitTile: View {
    @Environment(Store.self) private var store
    var body: some View {
        let out = store.stones.filter(\.out).count, on = store.stones.count - out
        Button { store.go(.kit) } label: {
            VStack(alignment: .leading, spacing: 0) {
                TileTop(label: "Home kit", dark: true)
                Spacer(minLength: 14)
                HStack(spacing: 10) {
                    KitRing(f: Double(on) / Double(max(1, store.stones.count)), size: 46, line: 4, tint: Color(hex: 0x7fb1ff))
                    (Text("\(on)").font(.app(34, .semibold)).foregroundStyle(Color(hex: 0xf1f5fb))
                     + Text("/\(store.stones.count)").font(.app(17, .medium)).foregroundStyle(Color(hex: 0xd6e2f3, 0.66)))
                        .tracking(-0.7).monospacedDigit()
                }
                Text(out > 0 ? "\(plural(out, "stone")) off power" : "Glow \(store.glow == .on ? "on" : store.glow == .dim ? "dim" : "off") · charging")
                    .font(.app(12.5, out > 0 ? .semibold : .regular))
                    .foregroundStyle(out > 0 ? Color(hex: 0xf5c47e) : Color(hex: 0xd6e2f3, 0.66)).padding(.top, 4)
            }
            .frame(minHeight: 118, alignment: .top)
            .homeTile(dark: true)
        }
        .buttonStyle(Pressable())
    }
}

struct PeopleTile: View {
    @Environment(Store.self) private var store
    var body: some View {
        let helpers = store.people.filter { $0.id != "you" }, invited = helpers.filter(\.invited).count
        Button { store.tab = 2 } label: {
            VStack(alignment: .leading, spacing: 0) {
                TileTop(label: "People")
                Spacer(minLength: 14)
                HStack(spacing: -8) {
                    ForEach(helpers.prefix(4)) { p in Avatar(p: p, size: 36).overlay(Circle().strokeBorder(.white, lineWidth: 2)) }
                }
                Text("\(helpers.count - invited) helping\(invited > 0 ? " · \(invited) invited" : "")")
                    .font(.app(12.5)).foregroundStyle(Color.muted).padding(.top, 4)
            }
            .frame(minHeight: 118, alignment: .top)
            .homeTile()
        }
        .buttonStyle(Pressable())
    }
}

// The urgent task and a finished one, as iOS-style banners. Two stack up; tap to fan them out.
struct NoteStack: View {
    @Environment(Store.self) private var store
    var urgent: [CareTask]
    var finished: CareTask?
    @Binding var open: Bool

    private struct Note: Identifiable { let id: String; let kind: Int }

    var body: some View {
        let notes: [Note] = (urgent.first.map { store.dismissed.contains("u" + $0.id) ? [] : [Note(id: "u" + $0.id, kind: 0)] } ?? [])
            + (finished.map { [Note(id: $0.id, kind: 1)] } ?? [])
        if !notes.isEmpty {
            let stacked = notes.count > 1 && !open
            VStack(alignment: .trailing, spacing: 8) {
                ZStack(alignment: .top) {
                    if stacked {
                        RoundedRectangle(cornerRadius: 22).fill(.white.opacity(0.42))
                            .overlay(RoundedRectangle(cornerRadius: 22).strokeBorder(.white.opacity(0.8)))
                            .scaleEffect(x: 0.95).offset(y: 9)
                    }
                    if stacked {
                        banner(notes[0]).allowsHitTesting(false)
                            .overlay(Color.clear.contentShape(.rect).onTapGesture { withAnimation(.spring(duration: 0.45, bounce: 0.2)) { open = true } })
                            .accessibilityAddTraits(.isButton).accessibilityHint("Shows \(notes.count) notifications")
                    }
                }
                if !stacked {
                    ForEach(notes) { n in banner(n).transition(.move(edge: .top).combined(with: .opacity)) }
                    if notes.count > 1 {
                        Button("Show less") { withAnimation(.spring(duration: 0.45, bounce: 0.2)) { open = false } }
                            .font(.app(12.5, .semibold)).foregroundStyle(Color.navy)
                            .padding(.horizontal, 12).padding(.vertical, 5).background(.white.opacity(0.6), in: .capsule)
                    }
                }
            }
            .padding(.bottom, stacked ? 18 : 10)
        }
    }

    @ViewBuilder private func banner(_ n: Note) -> some View {
        let warm = Color(hex: 0xf6d27c)
        if n.kind == 0, let u = urgent.first {
            row(tint: warm, title: u.n, body: "\(u.dueLabel.prefix(1).uppercased() + u.dueLabel.dropFirst()) · \(store.name(u.who))\(urgent.count > 1 ? " · +\(urgent.count - 1) urgent" : "")",
                cta: "View", thumb: AnyView(u.stone(base: 24)), action: { store.go(.task(u.id)) }, clear: { store.dismissed.insert(n.id) })
        } else if let f = finished, let p = store.person(f.who) {
            row(tint: nil, title: "\(p.name) finished \(f.n)", body: f.doneAt ?? "Today", cta: "Thank",
                thumb: AnyView(Avatar(p: p, size: 28)),
                action: { store.thanked.insert(f.id); store.say("Sent \(p.name) a thank-you") }, clear: { store.dismissed.insert(f.id) })
        }
    }

    private func row(tint: Color?, title: String, body: String, cta: String, thumb: AnyView, action: @escaping () -> Void, clear: @escaping () -> Void) -> some View {
        HStack(spacing: 12) {
            thumb.frame(width: 40, height: 40)
                .background((tint?.opacity(0.22) ?? .white.opacity(0.55)), in: .circle)
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(.app(14.5, .semibold)).foregroundStyle(Color.ink).lineLimit(1)
                Text(body).font(.app(12.5)).foregroundStyle(tint == nil ? Color(hex: 0x22262e, 0.6) : Color(hex: 0x8a5a07)).lineLimit(1)
            }
            Spacer(minLength: 4)
            Button(cta, action: action)
                .font(.app(12.5, .semibold)).foregroundStyle(Color.navy)
                .padding(.horizontal, 12).padding(.vertical, 6)
                .background(.white.opacity(0.75), in: .rect(cornerRadius: 14))
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 22).fill(tint.map { $0.opacity(0.16) } ?? .white.opacity(0.5)).background(.ultraThinMaterial, in: .rect(cornerRadius: 22)))
        .overlay(RoundedRectangle(cornerRadius: 22).strokeBorder(.white.opacity(0.85)))
        .shadow(color: Color(hex: 0x13315d, 0.12), radius: 12, y: 8)
        .contentShape(.rect)
        .onTapGesture(perform: action)
        .contextMenu { Button("Clear", systemImage: "xmark", action: clear) }
    }
}

// The bell: everything waiting on you, in one list.
struct NotesSheet: View {
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss
    var urgent: [CareTask]
    var finished: CareTask?
    var body: some View {
        let asks = store.tasks.filter { $0.handoff?.pending == true && !$0.done }
        NavigationStack {
            List {
                if !urgent.isEmpty {
                    Section("Urgent") {
                        ForEach(urgent) { t in
                            Button { dismiss(); store.go(.task(t.id)) } label: {
                                HStack(spacing: 12) {
                                    t.stone(base: 26).frame(width: 36)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(t.n).font(.app(15, .semibold)).foregroundStyle(Color.ink)
                                        Text("\(t.dueLabel) · \(store.name(t.who))").font(.meta).foregroundStyle(Color.muted)
                                    }
                                }
                            }
                        }
                    }
                }
                if let f = finished, let p = store.person(f.who) {
                    Section("Finished") {
                        HStack(spacing: 12) {
                            Avatar(p: p, size: 32)
                            Text("\(p.name) finished \(f.n)").font(.app(15)).foregroundStyle(Color.ink)
                            Spacer()
                            Button("Thank") { store.thanked.insert(f.id); store.say("Sent \(p.name) a thank-you") }
                                .font(.app(14, .semibold)).foregroundStyle(Color.thanks).buttonStyle(.borderless)
                        }
                    }
                }
                if !asks.isEmpty {
                    Section("Waiting on an answer") {
                        ForEach(asks) { t in
                            Button { dismiss(); store.go(.task(t.id)) } label: {
                                Text(t.n).font(.app(15)).foregroundStyle(Color.ink)
                            }
                        }
                    }
                }
                if urgent.isEmpty && finished == nil && asks.isEmpty {
                    Text("You're all caught up.").font(.body15).foregroundStyle(Color.muted)
                }
            }
            .navigationTitle("Notifications").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
        .presentationDetents([.medium, .large])
    }
}

struct WeekCard: View {
    @Environment(Store.self) private var store
    @State private var all = false
    var body: some View {
        let week = (0..<7).map { addDays($0, to: monday) }
        let counts = week.map { d in store.active.filter { $0.occurs(on: d) }.count }
        let mx = max(1, counts.max() ?? 1)
        let heavyN = counts.max() ?? 0
        let heavy = week[counts.firstIndex(of: heavyN) ?? 0]
        let today = store.active.filter { $0.occurs(on: store.day) }
        VStack(alignment: .leading, spacing: 0) {
            Text("This week").font(.app(14, .semibold)).foregroundStyle(Color.ink).frame(minHeight: 34)
            HStack(alignment: .bottom, spacing: 0) {
                ForEach(Array(week.enumerated()), id: \.offset) { i, d in
                    let on = Calendar.current.isDate(d, inSameDayAs: store.day)
                    let isToday = Calendar.current.isDate(d, inSameDayAs: TODAY)
                    let hasUrgent = store.active.contains { $0.urgent && $0.occurs(on: d) }
                    Button { withAnimation(.snappy) { store.day = d; all = false } } label: {
                        VStack(spacing: 4) {
                            VStack(spacing: 6) {
                                if hasUrgent { Stone(state: .urgent, w: .small, base: 18) }
                                RoundedRectangle(cornerRadius: 9)
                                    .fill(on ? Color(hex: 0x418ef3) : counts[i] == heavyN && heavyN > 0 ? Color(hex: 0x418ef3, 0.3) : Color(hex: 0x6e737c, 0.18))
                                    .frame(width: 30, height: max(8, CGFloat(counts[i]) / CGFloat(mx) * 84))
                                    .shadow(color: on ? Color(hex: 0x418ef3, 0.5) : .clear, radius: 7, y: 6)
                            }
                            .frame(height: 104, alignment: .bottom)
                            Text(String(dayKey(d).prefix(1)).uppercased()).font(.app(12, on ? .bold : .semibold))
                                .foregroundStyle(on ? Color.ink : isToday ? Color.shoalBlue : Color.muted).padding(.top, 4)
                            Text("\(Calendar.current.component(.day, from: d))").font(.app(15, on ? .bold : .semibold)).monospacedDigit()
                                .foregroundStyle(on ? Color.ink : isToday ? Color.shoalBlue : Color.ink)
                        }
                        .padding(.bottom, 6)
                        .frame(maxWidth: .infinity)
                        .contentShape(.rect)
                    }
                    .buttonStyle(Pressable())
                    .accessibilityLabel("\(DAY_FULL[dayKey(d)]!) \(Calendar.current.component(.day, from: d)), \(plural(counts[i], "task"))\(hasUrgent ? ", one is urgent" : "")")
                    .accessibilityAddTraits(on ? .isSelected : [])
                }
            }
            .padding(.top, 6)
            Text(heavyN > 0 ? "\(DAY_FULL[dayKey(heavy)]!) is the heavy day · \(plural(heavyN, "task"))" : store.tasks.isEmpty ? "Nothing planned yet" : "A light week")
                .font(.app(13.5)).foregroundStyle(Color.muted).padding(.horizontal, 4).padding(.top, 6).padding(.bottom, 8)
            if today.isEmpty {
                Text("Nothing on \(DAY_FULL[dayKey(store.day)]!).").font(.meta).foregroundStyle(Color.muted).padding(.vertical, 12)
            } else {
                let shown = all ? today : Array(today.prefix(3))
                ForEach(shown) { t in
                    if t.id != shown.first?.id { RowSep() }
                    TaskLine(t: t)
                }
                if today.count > 3 {
                    Button(all ? "Show less" : "\(today.count - 3) more") { withAnimation(.snappy) { all.toggle() } }
                        .font(.app(13.5, .semibold)).foregroundStyle(Color.shoalBlue).padding(.top, 10)
                }
            }
        }
        .homeTile()
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
                        Text("“\(t.n)” still needs someone.").font(.app(15, .semibold)).foregroundStyle(Color.ink)
                        if let pick { Text("\(pick.p.name) has \(pick.why).").font(.meta).foregroundStyle(Color.muted) }
                    }
                }
                HStack(spacing: 8) {
                    PearlChip(label: "Find someone") { store.pebbleHandoff(t.id) }
                    Button("Take it") { store.take(t.id) }.font(.app(14, .semibold)).padding(.horizontal, 10)
                }
            }
            .pearl()
        }
    }
}
