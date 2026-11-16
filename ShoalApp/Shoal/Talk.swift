import SwiftUI

// MARK: - Listening: turning what someone says into draft changes

// Signs of an emergency. Pebble doesn't triage. It stops and points to the hospice team.
private let PEB_URGENT = #"\b(can'?t wake|won'?t wake|not waking|breathing (strange|different|hard)|stopp?ed breathing|not breathing|unresponsive|seizure|bleeding|chest pain|fell|a fall|passed away|is dying)"#
// Medicine and symptoms. Pebble leaves these out and says so.
private let PEB_MEDS = #"\b(dose|doses|mg|ml|morphine|lorazepam|pill|pills|medication|medicine|symptom|pain level)\b"#
private let PEB_TIRED = #"\b(tired|wiped|exhausted|overwhelmed|burn(ed|t) out|need a break|running on empty)\b"#
private let STOP = Set("the a an and or but so to of for in on at with about his her their dad's mom's is was be it this that i i'm we he she they said might need needs soon can't cant do have has had runs out again my our your just really call ask get take make help need want going go said says told tell".split(separator: " ").map(String.init))

// Capture groups of the first match (group 0 is the whole match), or nil.
private func rx(_ pattern: String, _ s: String) -> [String]? {
    guard let re = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]),
          let m = re.firstMatch(in: s, range: NSRange(s.startIndex..., in: s)) else { return nil }
    return (0..<m.numberOfRanges).map { k in Range(m.range(at: k), in: s).map { String(s[$0]) } ?? "" }
}
private func hits(_ pattern: String, _ s: String) -> Bool { rx(pattern, s) != nil }

private func words(_ s: String) -> [String] {
    s.lowercased().map { $0.isLetter || $0 == "'" ? $0 : " " }.split(separator: " ").map { w in
        var w = String(w); if w.hasSuffix("'s") { w.removeLast(2) }; return w
    }
    .filter { $0.count > 2 && !STOP.contains($0) }
}
private func overlap(_ a: String, _ b: String) -> Int {
    let B = Set(words(b).map { String($0.prefix(6)) })
    return words(a).map { String($0.prefix(6)) }.filter { B.contains($0) }.count
}
// The task whose name shares the most words with what was said.
private func matchTask(_ s: String, _ list: [CareTask]) -> (t: CareTask, score: Int)? {
    var best: CareTask?, score = 0
    for t in list { let o = overlap(s, t.n); if o > score { best = t; score = o } }
    return best.map { ($0, score) }
}
private func dateIn(_ s: String) -> Date? {
    guard let m = rx(#"\b(monday|tuesday|wednesday|thursday|friday|saturday|sunday)"#, s) else { return nil }
    let want = ["sunday", "monday", "tuesday", "wednesday", "thursday", "friday", "saturday"].firstIndex(of: m[1].lowercased())! + 1
    for i in 1...7 where Calendar.current.component(.weekday, from: addDays(i)) == want { return addDays(i) }
    return nil
}
private func cap1(_ s: String) -> String { s.prefix(1).uppercased() + s.dropFirst() }
private func tidy(_ s: String) -> String {
    var s = s.trimmingCharacters(in: .whitespaces)
    if let m = rx(#"^(and|so|but|also|oh|plus)\s+"#, s) { s.removeFirst(m[0].count) }
    if let m = rx(#"\b(his|her)\b"#, s), let r = s.range(of: m[0]) { s.replaceSubrange(r, with: "\(LOVED)'s") }
    while let l = s.last, ",;.!?".contains(l) { s.removeLast() }
    return cap1(s)
}
func sizeFor(_ n: String) -> Weight {
    let n = n.lowercased()
    if ["overnight", "move", "install", "set up", "hospital", "whole day", "weekend", "trip"].contains(where: n.contains) { return .large }
    if ["appointment", "doctor", "ride", "drive", "cook", "meal", "clean", "bath", "shop", "grocer", "walk", "yard", "visit", "repair", "errand", "fix"].contains(where: n.contains) { return .medium }
    return .small
}

struct Proposal: Identifiable {
    enum K { case new, step, release, open, dup, checkin }
    let id = UUID()
    var kind: K
    var on = true
    var task: String?
    var n: String
    var m: String
    var step: String?
    var date: Date?
}

extension Store {
    // Returns nil when what was said sounds like an emergency.
    func hear(_ text: String) -> (props: [Proposal], skipped: [String])? {
        let sentences = text.components(separatedBy: CharacterSet(charactersIn: ".!?\n"))
            .map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        if sentences.contains(where: { hits(PEB_URGENT, $0) }) { return nil }
        let mineNow = active.filter { $0.who == "you" }
        var props: [Proposal] = [], skipped: [String] = []
        func owner(_ t: CareTask) -> String { t.who == "you" ? "your jar" : t.who != nil ? "\(name(t.who))'s jar" : "the shared jar" }
        for s in sentences {
            if hits(PEB_MEDS, s) { skipped.append(s); continue }
            if hits(PEB_TIRED, s) { props.append(.init(kind: .checkin, n: "Tell My jar you're stretched thin", m: "Only you see this · it helps Pebble suggest a hand-off")); continue }
            // "I can't do Thursday's visit" frees something up, or asks the circle to cover it.
            if let c = rx(#"\b(?:can'?t|cannot|won'?t be able to)\s+(?:do|make|cover|go to|get to)\s+(.+?)(?:,|$)"#, s) {
                if let mt = matchTask(s, mineNow) {
                    props.append(.init(kind: .release, task: mt.t.id, n: mt.t.n, m: "Leaves your jar · ask the circle, first yes takes it"))
                } else {
                    var what = c[1]; if what.lowercased().hasPrefix("the ") { what.removeFirst(4) }
                    props.append(.init(kind: .open, n: "Cover \(what)\(hits(#"with|for"#, what) ? "" : " with \(LOVED)")", m: "Ask the circle · first yes takes it", date: dateIn(s)))
                }
                continue
            }
            if let mt = matchTask(s, active), mt.score >= 2 {
                props.append(.init(kind: .dup, on: false, task: mt.t.id, n: mt.t.n, m: "Already in \(owner(mt.t)) · nothing new to add")); continue
            }
            if let mt = matchTask(s, active), mt.score == 1 {
                props.append(.init(kind: .step, task: mt.t.id, n: mt.t.n, m: "Already in \(owner(mt.t)) · I'll add a step, not a new stone", step: tidy(s))); continue
            }
            if let need = rx(#"\bneeds?\s+(?:to\s+)?(?:(a|an|the|some)\s+)?(.+?)(?:\s+soon|\s+this week|\s+by\s+\w+)?$"#, s) {
                let art = need[1].isEmpty ? "" : need[1].lowercased() + " "
                let item = need[2]
                let verb = need[0].lowercased().contains("need to") || need[0].lowercased().contains("needs to") || hits(#"^(call|book|ask|get|pick|find|order|schedule|fix|pay)\b"#, item)
                let n = verb ? cap1(item) : hits(#"hospice|nurse|doctor"#, s) ? "Ask hospice about \(art)\(item)" : "Get \(art)\(item)"
                props.append(.init(kind: .new, n: n, m: "New task · your jar · this week", date: dateIn(s))); continue
            }
            if let todo = rx(#"\b(?:have to|got to|should|remember to|don't forget to|we need to)\s+(.+?)$"#, s) {
                props.append(.init(kind: .new, n: cap1(todo[1]), m: "New task · your jar · this week", date: dateIn(s))); continue
            }
            skipped.append(s)
        }
        return (props, skipped)
    }

    // Applies what you said yes to. Every change goes in What Pebble did, with an undo.
    func commit(_ props: [Proposal]) -> [(st: StoneState, n: String, m: String)] {
        var done: [(StoneState, String, String)] = []
        func make(_ n: String, _ who: String?, _ date: Date?) -> CareTask {
            let t = CareTask(id: "pb\(UUID().uuidString.prefix(6))", n: n, who: who, w: sizeFor(n), cat: "", kind: .once, date: date ?? addDays(7))
            tasks.append(t); return t
        }
        for p in props where p.on {
            switch p.kind {
            case .new:
                let t = make(p.n, "you", p.date)
                pebbleDid("Added “\(t.n)” to your jar", how: "From what you told Pebble · you said yes", undo: .task(t.id))
                done.append((.progress, t.n, "New stone for your jar"))
            case .step:
                guard let id = p.task, let i = idx(id), let s = p.step else { continue }
                tasks[i].steps.append(Step(n: s))
                pebbleDid("Added a step to “\(tasks[i].n)”", how: "“\(s)” · you said yes", undo: .step(id, s))
                done.append((tasks[i].state, tasks[i].n, "Added as a step · same stone"))
            case .release:
                guard let id = p.task, let i = idx(id) else { continue }
                tasks[i].who = nil
                pebbleDid("Moved “\(tasks[i].n)” to the shared jar", how: "Asked the circle · you said yes", undo: .who(id, "you"))
                done.append((.open, tasks[i].n, "Asked the circle · waiting for a yes"))
            case .open:
                let t = make(p.n, nil, p.date)
                pebbleDid("Asked the circle to cover “\(t.n)”", how: "From what you told Pebble · you said yes", undo: .task(t.id))
                done.append((.open, t.n, "Asked the circle · waiting for a yes"))
            case .checkin:
                checkIn = .stretched
                pebbleDid("Noted that you're stretched thin", how: "Private to you · you said yes")
                done.append((.done, "You're stretched thin", "Saved privately in My jar"))
            case .dup: break
            }
        }
        return done
    }
}

// MARK: - Talk it through

struct TalkView: View {
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss
    enum Phase { case listen, review, done, sensitive }
    @State private var phase = Phase.listen
    @State private var text = ""
    @State private var props: [Proposal] = []
    @State private var skipped: [String] = []
    @State private var done: [(st: StoneState, n: String, m: String)] = []
    @State private var newId: String?
    @State private var pairing = false
    @FocusState private var typing: Bool

    private var samples: [(String, String)] { [
        ("A busy week", "The hospice nurse said \(LOVED) might need a hospital bed soon. And his refill runs out Friday. I can't do Thursday's visit, I have a work thing."),
        ("Around the house", "Mom said the stair rail is loose again. We need to call about the hospital bill. I'm honestly wiped out this week."),
        ("A hard moment", "\(LOVED) is breathing strangely and I can't wake him."),
    ] }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) { content }
                        .padding(20)
                        .id(phase)
                        .transition(.opacity.combined(with: .move(edge: .trailing)))
                }
                .scrollDismissesKeyboard(.interactively)
                footer.padding(.horizontal, 20).padding(.bottom, 10)
            }
            .background(AppBackground())
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } } }
            .sheet(isPresented: $pairing) { PairSheet().presentationDetents([.medium, .large]) }
        }
    }

    private func figure(_ img: String, _ size: CGFloat = 130) -> some View {
        Image(img).resizable().scaledToFit().frame(width: size, height: size).frame(maxWidth: .infinity)
    }

    @ViewBuilder private var content: some View {
        switch phase {
        case .sensitive:
            figure("pebble_sensitive_01")
            Text("That sounds really hard.").font(.title(28)).foregroundStyle(Color.navy).frame(maxWidth: .infinity)
            Text("I can't help with symptoms or medicine. \(LOVED)'s hospice team can, any time of day or night.")
                .font(.body15).foregroundStyle(Color.muted).multilineTextAlignment(.center).frame(maxWidth: .infinity)
            Label("Pebble didn't save anything you said. It never contacts hospice on its own. You decide.", systemImage: "lock")
                .font(.app(13.5)).foregroundStyle(Color.ink).glassCard(padding: 14)
        case .review:
            HStack(spacing: 12) {
                Image("pebble_think_01").resizable().scaledToFit().frame(width: 56, height: 56)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Waiting for your yes").font(.app(12, .semibold)).foregroundStyle(Color(hex: 0x8a5d0c))
                        .padding(.horizontal, 8).padding(.vertical, 3).background(Color(hex: 0xf6d27c, 0.35), in: .capsule)
                    Text(props.isEmpty ? "I didn't find anything to add." : "Here's what I'd add. Change anything.").font(.title(22)).foregroundStyle(Color.navy)
                }
            }
            ForEach($props) { $p in
                Button { if p.kind != .dup { withAnimation(.snappy) { p.on.toggle() } } } label: {
                    HStack(alignment: .top, spacing: 12) {
                        if p.kind == .dup { Stone(state: .done, w: .small, base: 22).frame(width: 26) }
                        else { Image(systemName: p.on ? "checkmark.circle.fill" : "circle").font(.system(size: 22)).foregroundStyle(p.on ? Color.shoalBlue : Color.muted) }
                        VStack(alignment: .leading, spacing: 3) {
                            Text(p.n).font(.app(15, .semibold)).foregroundStyle(Color.ink)
                            Text(p.m).font(.meta).foregroundStyle(p.kind == .step || p.kind == .dup ? Color(hex: 0x8a5d0c) : Color.muted)
                            if let s = p.step { Text("Step: \(s)").font(.meta).foregroundStyle(Color.muted) }
                        }
                        .multilineTextAlignment(.leading)
                        Spacer(minLength: 0)
                    }
                    .opacity(p.on || p.kind == .dup ? 1 : 0.5)
                    .pearl(radius: 16, padding: 12)
                }
                .buttonStyle(Pressable())
                .disabled(p.kind == .dup)
                .accessibilityAddTraits(p.on ? .isSelected : [])
            }
            if let first = skipped.first {
                HStack(alignment: .top, spacing: 10) {
                    Image("pebble_peer_down").resizable().scaledToFit().frame(width: 36, height: 36)
                    (Text("I left \(skipped.count == 1 ? "one thing" : "\(skipped.count) things") out. ").bold()
                     + Text(skipped.contains { hits(PEB_MEDS, $0) } ? "Anything about medicine or symptoms is a question for \(LOVED)'s hospice nurse. " : "")
                     + Text("“\(first)”"))
                        .font(.app(13.5)).foregroundStyle(Color.ink)
                }
                .glassCard(padding: 12)
            }
            if !props.isEmpty { Text("Tap a card to leave it out.").font(.meta).foregroundStyle(Color.muted) }
        case .done:
            figure("pebble_carry_03")
            Text("Done. Here's where they went.").font(.title(26)).foregroundStyle(Color.navy).frame(maxWidth: .infinity)
            VStack(alignment: .leading, spacing: 12) {
                ForEach(Array(done.enumerated()), id: \.offset) { _, x in
                    HStack(spacing: 12) {
                        Stone(state: x.st, w: .small, base: 22).frame(width: 28)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(x.n).font(.app(15, .semibold)).foregroundStyle(Color.ink)
                            Text(x.m).font(.meta).foregroundStyle(Color.muted)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading).glassCard()
            Text("Undo anything from What Pebble did.").font(.meta).foregroundStyle(Color.muted).frame(maxWidth: .infinity)
        case .listen:
            figure("pebble_base_front", 110)
            Text("Talk or type").font(.app(12.5, .semibold)).foregroundStyle(Color.muted)
                .padding(.horizontal, 10).padding(.vertical, 4).background(.white.opacity(0.8), in: .capsule).frame(maxWidth: .infinity)
            TextField("What's going on? Say it however it comes out.", text: $text, axis: .vertical)
                .focused($typing)
                .lineLimit(5...10).font(.body15).padding(14)
                .background(.white, in: .rect(cornerRadius: 16))
                .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Color(hex: 0xdde1e6)))
                .accessibilityLabel("Tell Pebble what's going on")
            Eyebrow(text: "Try a sample", color: .muted)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) { ForEach(samples, id: \.0) { s in PearlChip(label: s.0) { text = s.1 } } }
            }
            // Scroll edge to edge so chips slide off the screen, not off a hard line inside the margin.
            .contentMargins(.horizontal, 20, for: .scrollContent).padding(.horizontal, -20)
        }
    }

    @ViewBuilder private var footer: some View {
        switch phase {
        case .sensitive:
            VStack(spacing: 6) {
                Button("Call hospice") { store.say("In the real app this calls the hospice number the family saved.") }.buttonStyle(PrimaryButton())
                Button("Go back") { withAnimation(.snappy) { phase = .listen } }.font(.app(15, .semibold)).frame(height: 36)
            }
        case .review:
            let on = props.filter { $0.on && $0.kind != .dup }.count
            HStack(spacing: 10) {
                Button("Say a change") { withAnimation(.snappy) { phase = .listen } }.buttonStyle(GhostButton())
                Button(on == 0 ? "Nothing to add" : on == 1 ? "Yes, add this" : "Yes, add these \(on)") {
                    if on == 0 { dismiss(); return }
                    let before = Set(store.tasks.map(\.id))
                    done = store.commit(props)
                    newId = store.tasks.first { !before.contains($0.id) && $0.who == "you" }?.id
                    withAnimation(.snappy) { phase = .done }
                }
                .buttonStyle(PrimaryButton())
            }
        case .done:
            if newId != nil && store.kit == true {
                HStack(spacing: 10) {
                    Button("Later") { dismiss() }.buttonStyle(GhostButton())
                    Button("Pair a stone now") { pairing = true }.buttonStyle(PrimaryButton())
                }
            } else {
                Button("Done") { dismiss() }.buttonStyle(PrimaryButton())
            }
        case .listen:
            VStack(spacing: 6) {
                Button("That's everything") {
                    typing = false
                    if let r = store.hear(text) { props = r.props; skipped = r.skipped; withAnimation(.snappy) { phase = .review } }
                    else { withAnimation(.snappy) { phase = .sensitive } }
                }
                .buttonStyle(PrimaryButton(enabled: !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty))
                .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                Text("Nothing is added until you say yes.").font(.meta).foregroundStyle(Color.muted)
            }
        }
    }
}

// MARK: - Monthly check-in

struct MonthView: View {
    @Environment(Store.self) private var store
    @State private var move = false
    @State private var nothing = false

    var body: some View {
        Page {
            HStack(spacing: 12) {
                Image("pebble_think_01").resizable().scaledToFit().frame(width: 56, height: 56)
                VStack(alignment: .leading, spacing: 4) {
                    Eyebrow(text: "\(TODAY.formatted(.dateTime.month(.wide))) check-in")
                    Text("A few things I noticed this month").font(.title(24)).foregroundStyle(Color.navy)
                }
            }
            VStack(alignment: .leading, spacing: 14) {
                ForEach(Array(store.monthNotes.enumerated()), id: \.offset) { _, x in
                    HStack(spacing: 12) {
                        Stone(state: x.st, w: .small, base: 22).frame(width: 28)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(x.n).font(.app(15, .semibold)).foregroundStyle(Color.ink)
                            Text(x.m).font(.meta).foregroundStyle(Color.muted)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading).glassCard()
            HStack(alignment: .top, spacing: 10) {
                Stone(state: .progress, w: .small, base: 16)
                Text("Pebble only raises this at the check-in, with everyone. Never as a nudge to one person. Rings show how much room someone has, never why.")
                    .font(.app(13)).foregroundStyle(Color.ink)
            }
            .glassCard(padding: 12)
        }
        .safeAreaInset(edge: .bottom) {
            HStack(spacing: 10) {
                Button("Not this month") {
                    store.monthSkipped = true
                    store.back()
                    store.say("Okay. Pebble will check in next month.")
                }
                .buttonStyle(GhostButton()).frame(width: 140)
                Button("Move stones together") { if store.monthMove == nil { nothing = true } else { move = true } }.buttonStyle(PrimaryButton())
            }
            .padding(.horizontal, 20).padding(.vertical, 10).background(.ultraThinMaterial)
        }
        .sheet(isPresented: $move) { MoveSheet().presentationDetents([.height(360)]) }
        .alert("Nothing to move", isPresented: $nothing) { Button("Got it") {} } message: {
            Text("Everyone is within the room they set. Move stones by hand from People if you like.")
        }
    }
}

private struct MoveSheet: View {
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let m = store.monthMove {
                Text("One move that evens things out").font(.title(24)).foregroundStyle(Color.navy)
                Text("Decide together. Everyone sees the same jars after.").font(.body15).foregroundStyle(Color.muted)
                HStack(spacing: 12) {
                    m.t.stone(base: 26).frame(width: 34)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(m.t.n).font(.app(15, .semibold)).foregroundStyle(Color.ink)
                        Text("\(m.from.name) → \(m.to.name) · \(m.t.w.label.lowercased())").font(.meta).foregroundStyle(Color.muted)
                    }
                    Spacer()
                }
                .glassCard(padding: 12)
                Spacer(minLength: 0)
                HStack(spacing: 10) {
                    Button("Not this one") { dismiss() }.buttonStyle(GhostButton())
                    Button("Move it") {
                        if let i = store.idx(m.t.id) {
                            store.tasks[i].who = m.to.id
                            store.pebbleDid("Moved “\(m.t.n)” from \(m.from.name) to \(m.to.name)", how: "At the monthly check-in · the family said yes", undo: .who(m.t.id, m.from.id))
                        }
                        dismiss()
                        store.say("Moved to \(m.to.id == "you" ? "your" : m.to.name + "'s") jar")
                    }
                    .buttonStyle(PrimaryButton())
                }
            } else {
                Text("Everything is even now.").font(.title(24)).foregroundStyle(Color.navy)
                Button("Done") { dismiss() }.buttonStyle(PrimaryButton())
            }
        }
        .padding(24)
    }
}

// The entry card on People. Hidden when Pebble is off or the family skipped this month.
struct MonthEntry: View {
    @Environment(Store.self) private var store
    var body: some View {
        if store.pebbleOn && !store.monthSkipped {
            Button { store.go(.month) } label: {
                HStack(spacing: 12) {
                    Image("pebble_think_01").resizable().scaledToFit().frame(width: 44, height: 44)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Monthly check-in").font(.app(15.5, .semibold)).foregroundStyle(Color.ink)
                        Text("Pebble has a few things for when you're all together").font(.meta).foregroundStyle(Color.muted).multilineTextAlignment(.leading)
                    }
                    Spacer(minLength: 0)
                    Chevron()
                }
                .pearl(radius: 20, padding: 14)
            }
            .buttonStyle(Pressable())
        }
    }
}
