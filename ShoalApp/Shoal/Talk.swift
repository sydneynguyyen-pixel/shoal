import SwiftUI
import Speech
import AVFoundation

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

// MARK: - Pebble tab: a chat you can type or talk into

// One thing you said and how Pebble answered it.
struct Exchange: Identifiable {
    enum Stage { case review, done, sensitive }
    let id = UUID()
    var said: String
    var stage: Stage
    var props: [Proposal] = []
    var skipped: [String] = []
    var done: [(st: StoneState, n: String, m: String)] = []
    var newId: String?
}

struct PebbleView: View {
    @Environment(Store.self) private var store
    @State private var chat: [Exchange] = []
    @State private var text = ""
    @State private var mic = Listener()
    @State private var costs = false
    @State private var log = false
    @State private var sees = false
    @State private var pairing = false
    @FocusState private var typing: Bool

    private var samples: [(String, String)] { [
        ("A busy week", "The hospice nurse said \(LOVED) might need a hospital bed soon. And his refill runs out Friday. I can't do Thursday's visit, I have a work thing."),
        ("Things around the house", "Mom said the stair rail is loose again. We need to call about the hospital bill. I'm honestly wiped out this week."),
        ("A hard moment", "\(LOVED) is breathing strangely and I can't wake him."),
    ] }
    private var blank: Bool { text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    var body: some View {
        VStack(spacing: 0) {
            header
            if chat.isEmpty {
                Spacer()
                welcome
                Spacer()
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(alignment: .leading, spacing: 18) {
                            ForEach($chat) { $x in exchange($x, live: x.id == chat.last?.id) }
                            Color.clear.frame(height: 1).id("end")
                        }
                        .padding(.horizontal, 20).padding(.vertical, 12)
                    }
                    .scrollIndicators(.hidden)
                    .scrollDismissesKeyboard(.interactively)
                    .onChange(of: chat.count) { withAnimation(.snappy) { proxy.scrollTo("end", anchor: .bottom) } }
                    .onChange(of: chat.last?.stage) { withAnimation(.snappy) { proxy.scrollTo("end", anchor: .bottom) } }
                }
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) { composer }
        .background(alignment: .bottom) {
            ZStack {
                AppBackground()
                // The pearl glow behind the samples, only before the first message.
                if chat.isEmpty {
                    EllipticalGradient(colors: [Color(hex: 0xd9c8f3, 0.75), Color(hex: 0xf6dccb, 0.55), Color(hex: 0xcfe6f0, 0.35), .clear],
                                       center: .bottom, startRadiusFraction: 0, endRadiusFraction: 0.75)
                        .frame(height: 460).frame(maxHeight: .infinity, alignment: .bottom)
                        .transition(.opacity)
                }
            }
            .ignoresSafeArea()
        }
        .toolbar(.hidden, for: .navigationBar)
        .onChange(of: mic.heard) { if mic.on { text = mic.heard } }
        .sheet(isPresented: $costs) { CostsView() }
        .sheet(isPresented: $log) { LogView().presentationDetents([.medium]) }
        .sheet(isPresented: $sees) { SeesView().presentationDetents([.medium]) }
        .sheet(isPresented: $pairing) { PairSheet().presentationDetents([.medium, .large]) }
    }

    private var header: some View {
        HStack(spacing: 10) {
            Image("pebble_base_front").resizable().scaledToFit().frame(width: 32, height: 32)
            Text("Pebble").font(.title(24)).foregroundStyle(Color.navy)
            Spacer()
            Menu {
                if !chat.isEmpty {
                    item("New chat", "Clear this chat and start over", "square.and.pencil") { mic.stop(); withAnimation(.snappy) { chat = []; text = "" } }
                }
                item("Help with costs", "Programs that may pay for care", "dollarsign.circle") { costs = true }
                item("What Pebble did", "Everything it added, with Undo", "clock.arrow.circlepath") { log = true }
                item("What Pebble can see", "Only what you tell it here", "eye") { sees = true }
                // Quick lookups pop up as sheets; the check-in is a full page, so it sits apart with a ›.
                Section {
                    item("Monthly check-in  ›", "How the work was shared this month", "calendar") { store.go(.month) }
                }
            } label: {
                Image(systemName: "ellipsis").font(.system(size: 17, weight: .semibold)).foregroundStyle(Color.ink)
                    .frame(width: 44, height: 44).glassEffect(.regular.interactive(), in: .circle)
            }
            .accessibilityLabel("More")
        }
        .padding(.horizontal, 20).padding(.top, 6).padding(.bottom, 4)
    }

    private func item(_ title: String, _ sub: String, _ icon: String, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title); Text(sub); Image(systemName: icon)
        }
    }

    private var welcome: some View {
        VStack(spacing: 10) {
            Image("pebble_base_front").resizable().scaledToFit().frame(width: 120, height: 120)
                .shadow(color: Color(red: 90/255, green: 60/255, blue: 40/255, opacity: 0.18), radius: 8, y: 12)
            Text("What's going on?").font(.title(30)).foregroundStyle(Color.navy)
            Text("Tell me what's on your plate. I'll turn it into tasks and find who can help.").multilineTextAlignment(.center).font(.body15).foregroundStyle(Color.muted)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 20)
        .onTapGesture { typing = false }
    }

    // MARK: Messages

    @ViewBuilder private func exchange(_ x: Binding<Exchange>, live: Bool) -> some View {
        let e = x.wrappedValue
        Text(e.said).font(.body15).foregroundStyle(Color.ink)
            .padding(.horizontal, 14).padding(.vertical, 10)
            .background(Color(hex: 0xebe8e3, 0.9), in: .rect(cornerRadius: 20))
            .frame(maxWidth: 300, alignment: .trailing)
            .frame(maxWidth: .infinity, alignment: .trailing)

        VStack(alignment: .leading, spacing: 10) {
            Image(e.stage == .sensitive ? "pebble_sensitive_01" : e.stage == .done ? "pebble_carry_03" : "pebble_offer_open_hands")
                .resizable().scaledToFit().frame(width: 34, height: 34)
            switch e.stage {
            case .sensitive:
                reply("That sounds really hard. I can't help with symptoms or medicine. \(LOVED)'s hospice team can, any time of day or night.")
                Label("I didn't save what you said, and I never contact hospice on my own.", systemImage: "lock")
                    .font(.meta).foregroundStyle(Color.muted)
                Button("Call hospice") { store.say("In the real app this calls the hospice number the family saved.") }
                    .buttonStyle(PrimaryButton()).frame(width: 180)
            case .review:
                reply(e.props.isEmpty ? "I didn't find anything to add. Try saying what needs doing." : "Here's what I'd add. Tap one to leave it out.")
                ForEach(x.props) { $p in proposal($p, live: live) }
                if let first = e.skipped.first {
                    (Text("I left \(e.skipped.count == 1 ? "one thing" : "\(e.skipped.count) things") out. ").bold()
                     + Text(e.skipped.contains { hits(PEB_MEDS, $0) } ? "Anything about medicine or symptoms is a question for \(LOVED)'s hospice nurse. " : "")
                     + Text("“\(first)”"))
                        .font(.app(13.5)).foregroundStyle(Color.sectionInk)
                }
                if live {
                    let on = e.props.filter { $0.on && $0.kind != .dup }.count
                    if on > 0 {
                        Button(on == 1 ? "Yes, add this" : "Yes, add these \(on)") { yes(x) }
                            .buttonStyle(PrimaryButton()).padding(.top, 2)
                    }
                }
            case .done:
                reply("Done. Here's where they went.")
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(Array(e.done.enumerated()), id: \.offset) { _, d in
                        HStack(spacing: 12) {
                            Stone(state: d.st, w: .small, base: 22).frame(width: 28)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(d.n).font(.app(15, .semibold)).foregroundStyle(Color.ink)
                                Text(d.m).font(.meta).foregroundStyle(Color.muted)
                            }
                            Spacer(minLength: 0)
                        }
                    }
                }
                .glassCard(radius: 18, padding: 14)
                HStack(spacing: 16) {
                    if live, e.newId != nil, store.kit == true {
                        Button("Pair a stone") { pairing = true }.font(.app(14, .semibold))
                    }
                    Button("Undo in What Pebble did") { log = true }.font(.app(14, .semibold)).foregroundStyle(Color.muted)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func reply(_ s: String) -> some View {
        Text(s).font(.app(16)).foregroundStyle(Color.ink).fixedSize(horizontal: false, vertical: true)
    }

    private func proposal(_ p: Binding<Proposal>, live: Bool) -> some View {
        let v = p.wrappedValue
        return Button { if v.kind != .dup { withAnimation(.snappy) { p.wrappedValue.on.toggle() } } } label: {
            HStack(alignment: .top, spacing: 12) {
                if v.kind == .dup { Stone(state: .done, w: .small, base: 22).frame(width: 26) }
                else { Image(systemName: v.on ? "checkmark.circle.fill" : "circle").font(.system(size: 22)).foregroundStyle(v.on ? Color.shoalBlue : Color.muted) }
                VStack(alignment: .leading, spacing: 3) {
                    Text(v.n).font(.app(15, .semibold)).foregroundStyle(Color.ink)
                    Text(v.m).font(.meta).foregroundStyle(v.kind == .step || v.kind == .dup ? Color(hex: 0x8a5d0c) : Color.muted)
                    if let s = v.step { Text("Step: \(s)").font(.meta).foregroundStyle(Color.muted) }
                }
                .multilineTextAlignment(.leading)
                Spacer(minLength: 0)
            }
            .opacity(v.on || v.kind == .dup ? 1 : 0.5)
            .pearl(radius: 16, padding: 12)
        }
        .buttonStyle(Pressable())
        .disabled(v.kind == .dup || !live)
        .accessibilityAddTraits(v.on ? .isSelected : [])
    }

    // MARK: Composer

    private var composer: some View {
        VStack(alignment: .leading, spacing: 12) {
            if chat.isEmpty && blank && !mic.on {
                FlowRow(spacing: 8) {
                    ForEach(samples, id: \.0) { s in
                        Button { text = s.1 } label: {
                            Text(s.0).font(.app(14, .medium)).foregroundStyle(Color.ink)
                                .padding(.horizontal, 14).frame(height: 38)
                                .background(.white.opacity(0.75), in: .capsule)
                                .overlay(Capsule().strokeBorder(.white))
                        }
                        .buttonStyle(Pressable())
                    }
                }
                .transition(.opacity)
            }
            HStack(alignment: .bottom, spacing: 10) {
                TextField(mic.on ? "Listening…" : "Tell Pebble what's going on", text: $text, axis: .vertical)
                    .focused($typing)
                    .lineLimit(1...6).font(.app(16))
                    .padding(.vertical, 13)
                    .accessibilityLabel("Tell Pebble what's going on")
                if mic.on || blank {
                    Button { listen() } label: {
                        Image(systemName: mic.on ? "stop.fill" : "mic.fill").font(.system(size: mic.on ? 12 : 15, weight: .semibold))
                            .foregroundStyle(.white).frame(width: 34, height: 34)
                            .background(mic.on ? Color.alert : Color.shoalBlue, in: .circle)
                            .symbolEffect(.pulse, isActive: mic.on)
                    }
                    .accessibilityLabel(mic.on ? "Stop listening" : "Talk to Pebble")
                    .padding(.bottom, 7)
                }
                if !blank {
                    Button { send() } label: {
                        Image(systemName: "arrow.up").font(.system(size: 15, weight: .bold))
                            .foregroundStyle(.white).frame(width: 34, height: 34)
                            .background(Color.navy, in: .circle)
                    }
                    .accessibilityLabel("Send")
                    .padding(.bottom, 7)
                }
            }
            .padding(.leading, 18).padding(.trailing, 7)
            .background(.white, in: .rect(cornerRadius: 26))
            .overlay(RoundedRectangle(cornerRadius: 26).strokeBorder(Color(hex: 0xe6e3de)))
            .shadow(color: Color(hex: 0x21262e, 0.08), radius: 14, y: 6)
        }
        .padding(.horizontal, 16).padding(.top, 8).padding(.bottom, 8)
        .animation(.snappy, value: blank)
        .animation(.snappy, value: mic.on)
    }

    // MARK: Actions

    private func listen() {
        if mic.on { mic.stop(); return }
        typing = false
        mic.start(after: text) { store.say("Couldn't hear you. You can type instead.") }
    }

    private func send() {
        mic.stop(); typing = false
        let said = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !said.isEmpty else { return }
        text = ""
        let e: Exchange
        if let r = store.hear(said) { e = Exchange(said: said, stage: .review, props: r.props, skipped: r.skipped) }
        else { e = Exchange(said: said, stage: .sensitive) }
        withAnimation(.snappy) { chat.append(e) }
    }

    private func yes(_ x: Binding<Exchange>) {
        let before = Set(store.tasks.map(\.id))
        let done = store.commit(x.wrappedValue.props)
        let newId = store.tasks.first { !before.contains($0.id) && $0.who == "you" }?.id
        withAnimation(.snappy) {
            x.wrappedValue.done = done
            x.wrappedValue.newId = newId
            x.wrappedValue.stage = .done
        }
    }
}

// MARK: - Listening with the microphone

@MainActor @Observable final class Listener {
    var on = false
    var heard = ""
    @ObservationIgnored private let engine = AVAudioEngine()
    @ObservationIgnored private var req: SFSpeechAudioBufferRecognitionRequest?
    @ObservationIgnored private var job: SFSpeechRecognitionTask?

    // Adds what it hears after `base`. Calls `failed` if it can't listen.
    func start(after base: String, failed: @escaping @MainActor () -> Void) {
        Task {
            guard await Self.speechAllowed(), await AVAudioApplication.requestRecordPermission(),
                  let rec = SFSpeechRecognizer(locale: Locale(identifier: "en-US")), rec.isAvailable else { failed(); return }
            let input = engine.inputNode
            let format = input.outputFormat(forBus: 0)
            guard format.sampleRate > 0, format.channelCount > 0 else { failed(); return }
            do {
                let session = AVAudioSession.sharedInstance()
                try session.setCategory(.record, mode: .measurement, options: .duckOthers)
                try session.setActive(true, options: .notifyOthersOnDeactivation)
                let req = SFSpeechAudioBufferRecognitionRequest()
                req.shouldReportPartialResults = true
                input.installTap(onBus: 0, bufferSize: 1024, format: format, block: Self.feed(req))
                engine.prepare()
                try engine.start()
                self.req = req
                let b = base.trimmingCharacters(in: .whitespacesAndNewlines)
                let lead = b.isEmpty ? "" : b + " "
                heard = b
                on = true
                job = rec.recognitionTask(with: req, resultHandler: Self.results { [weak self] s, end in
                    Task { @MainActor in
                        guard let self, self.on else { return }
                        if let s { self.heard = lead + s }
                        if end { self.stop() }
                    }
                })
            } catch { stop(); failed() }
        }
    }

    func stop() {
        guard on || engine.isRunning else { return }
        on = false
        if engine.isRunning { engine.stop() }
        engine.inputNode.removeTap(onBus: 0)
        req?.endAudio(); job?.cancel()
        req = nil; job = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    // These are built outside the main actor because the audio and speech callbacks run on their own threads.
    nonisolated private static func speechAllowed() async -> Bool {
        await withCheckedContinuation { c in SFSpeechRecognizer.requestAuthorization { c.resume(returning: $0 == .authorized) } }
    }
    nonisolated private static func feed(_ req: SFSpeechAudioBufferRecognitionRequest) -> AVAudioNodeTapBlock {
        { buffer, _ in req.append(buffer) }
    }
    nonisolated private static func results(_ f: @escaping @Sendable (String?, Bool) -> Void) -> (SFSpeechRecognitionResult?, (any Error)?) -> Void {
        { r, e in f(r?.bestTranscription.formattedString, e != nil || r?.isFinal == true) }
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
