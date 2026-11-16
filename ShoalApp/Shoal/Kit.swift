import SwiftUI

// MARK: - Setup guide: jars, the first stone, then the rest

struct KitSetupView: View {
    @Environment(Store.self) private var store
    @State private var step = 0
    @State private var heard = false
    @State private var blink: String?
    @State private var colors = false
    @State private var more = false

    // Your urgent task first, else your first one.
    private var first: CareTask? {
        let yours = store.active.filter { $0.who == "you" }
        return yours.first(where: \.urgent) ?? yours.first ?? store.active.first
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Button { if step == 0 { store.kitSetup = false } else { withAnimation(.snappy) { step -= 1 } } } label: {
                    Image(systemName: "chevron.left").font(.system(size: 18, weight: .semibold)).frame(width: 40, height: 40)
                }
                .accessibilityLabel("Back")
                HStack(spacing: 4) {
                    ForEach(1...8, id: \.self) { k in Capsule().fill(k <= step ? Color.shoalBlue : Color(hex: 0xd9e2ee)).frame(height: 5) }
                }
                Button("Skip") { store.kitSetup = false }.font(.app(15, .semibold))
            }
            .padding(.horizontal, 14)
            ScrollView {
                VStack(alignment: .leading, spacing: 12) { page }
                    .padding(.horizontal, 22).padding(.top, 8).padding(.bottom, 20)
                    .id(step)
                    .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .opacity))
            }
            footer.padding(.horizontal, 22).padding(.bottom, 10)
        }
        .background(AppBackground())
        .sheet(isPresented: $colors) { ColorsSheet() }
        .overlay(alignment: .top) { if let t = store.toast { ToastView(text: t).padding(.top, 4) } }
    }

    private func next() { withAnimation(.snappy) { step += 1 } }

    private func head(_ eyebrow: String, _ title: String, _ sub: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Eyebrow(text: eyebrow)
            Text(title).font(.title(28)).foregroundStyle(Color.navy).fixedSize(horizontal: false, vertical: true)
            Text(sub).font(.body15).foregroundStyle(Color.muted).fixedSize(horizontal: false, vertical: true)
        }
    }

    private func stage<V: View>(tall: Bool = false, @ViewBuilder _ c: () -> V) -> some View {
        VStack(spacing: 14) { c() }
            .padding(.vertical, 20)
            .frame(maxWidth: .infinity).frame(minHeight: tall ? 250 : 190)
            .background(RadialGradient(colors: [Color(hex: 0x1d3a66), Color(hex: 0x0e1f3a)], center: .center, startRadius: 10, endRadius: 260), in: .rect(cornerRadius: 26))
    }

    private func pill(_ s: String) -> some View {
        Text(s).font(.app(13, .semibold)).foregroundStyle(.white)
            .padding(.horizontal, 12).padding(.vertical, 6).background(.white.opacity(0.14), in: .capsule)
    }

    @ViewBuilder private var page: some View {
        let main = store.mainPeople
        switch step {
        case 0:
            head("Setup · about 5 minutes", "Your plan is ready", "\(plural(store.active.count, "task")), shared by \(main.count) of you. Next, set up the jars and pair your first stone.")
            FamilyShelf(width: 66).padding(.vertical, 10).glassCard()
            steps([("Set up the jars", "One per person, about a minute"), ("Pair your first stone", "Tap it to one of your tasks"), ("Try it out", "Find a stone and see the glow")])
        case 1:
            let others = store.people.filter { $0.tier != .main }.map(\.name)
            head("Step 1 of 8", "Set up the jars", "One jar for each person who takes on tasks.\(others.isEmpty ? "" : " \(others.joined(separator: ", ")) can follow along without one.")")
            let jw: CGFloat = main.count > 4 ? 248 / CGFloat(main.count) : 62
            HStack(spacing: 8) { ForEach(main) { p in VStack(spacing: 4) { JarBody(stones: [], width: jw); Text(p.name).font(.app(12.5, .semibold)).lineLimit(1).minimumScaleFactor(0.8) } } }
                .frame(maxWidth: .infinity).padding(.vertical, 10).glassCard()
            steps([("Plug in the base", "It powers the jars and charges spare stones"), ("Snap on one jar per person", "Use only as many as you need"),
                   ("Write a name on each lid", main.map(\.name).joined(separator: ", "))])
        case 2:
            let w = first?.w ?? .medium
            head("Step 2 of 8 · First stone", "Pick up a \(w.label.lowercased()) stone",
                 "\(first.map { "“\($0.n)” is a \(w.label.lowercased()) task, so it gets a \(w.label.lowercased()) stone. " } ?? "")Lift one from the round end of the base. It glows \(store.colors.name(.open)) when it's ready to pair.")
            stage(tall: true) {
                Stone(state: .open, w: w, base: 110).phaseAnimator([1, 1.06]) { v, s in v.scaleEffect(s) } animation: { _ in .easeInOut(duration: 1.5) }
                Text("\(w.label) stone · \(store.colors.name(.open)) glow · ready to pair").font(.app(13)).foregroundStyle(.white.opacity(0.8))
            }
            HStack {
                ForEach(Weight.allCases) { k in
                    VStack(spacing: 6) {
                        Stone(state: .open, w: k, base: 26).frame(height: 30)
                        Text(k.label).font(.app(13, .semibold)).foregroundStyle(Color.ink)
                        Text("\(store.stones.filter { $0.size == k }.count) in the kit").font(.app(11.5)).foregroundStyle(Color.muted)
                    }
                    .frame(maxWidth: .infinity).padding(.vertical, 10)
                    .background(k == w ? Color.blueTint : .clear, in: .rect(cornerRadius: 14))
                }
            }
            .glassCard(padding: 8)
        case 3:
            head("Step 3 of 8 · First stone", "Hold it to your phone", "Touch the stone to the back of your phone. This is the only screen that listens for stones, so nothing pairs by accident.")
            stage {
                if heard, let t = first {
                    t.stone(base: 90)
                    pill("✓ \(store.stoneOf(t.id)?.label ?? store.freeStone(t.w)?.label ?? "Stone") found · \((store.stoneOf(t.id) ?? store.freeStone(t.w))?.size.label ?? "")")
                } else {
                    Stone(state: .open, w: first?.w ?? .medium, base: 90).phaseAnimator([0.94, 1.04]) { v, s in v.scaleEffect(s) } animation: { _ in .easeInOut(duration: 0.9) }
                    HStack(spacing: 6) { ProgressView().tint(.white).controlSize(.small); Text("Listening for a stone…") }
                        .font(.app(13, .semibold)).foregroundStyle(.white)
                }
            }
            .task { if !heard { try? await Task.sleep(for: .seconds(1.8)); withAnimation(.spring) { heard = true } } }
            if let t = first { pairTo(t) }
        case 4:
            if let t = first {
                let st = t.state
                head("Step 4 of 8 · First stone", "Paired. Now drop it in your jar.",
                     "Your stone now glows \(store.colors.name(st)) because \(st == .urgent ? "the task is urgent. Once it's underway, it turns \(store.colors.name(.progress))." : st == .progress ? "someone is on it. It turns \(store.colors.name(.urgent)) when it's due soon." : "no one has it yet.")")
                stage(tall: true) {
                    Image(systemName: "checkmark.circle.fill").font(.system(size: 24)).foregroundStyle(Color(hex: 0x6fd08c))
                    t.stone(base: 110)
                    pill("\(st.short) · \(store.colors.name(st))")
                    Text("\(t.n) · \(store.name(t.who))").font(.app(13)).foregroundStyle(.white.opacity(0.8))
                }
            }
        case 5:
            if let t = first {
                head("Step 5 of 8 · Try it", "Find a stone", "Tap Find stone on any task. Its stone blinks so you can spot it in the jar.")
                stage {
                    FamilyShelf(width: 92, blink: blink, only: "you", names: false, dark: true)
                    pill("Blinking").opacity(blink != nil ? 1 : 0) // keeps the jar from jumping
                }
                TaskLine(t: t, action: {}).allowsHitTesting(false).glassCard(padding: 12)
                if blink != nil { SectionH(text: "Did it blink?") }
            }
        case 6:
            head("Step 6 of 8 · Try it", "What the glow means", "Every stone tells you where its task stands, right from the jar.")
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                ForEach([StoneState.urgent, .progress, .open, .done], id: \.self) { s in
                    VStack(alignment: .leading, spacing: 6) {
                        Stone(state: s, base: 34).frame(height: 34)
                        Text(s.short).font(.app(15, .semibold)).foregroundStyle(Color.ink)
                        Text(s.meaning).font(.app(12)).foregroundStyle(Color.muted)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading).glassCard(radius: 18, padding: 12)
                }
            }
            VStack(alignment: .leading, spacing: 10) {
                kind(Stone(state: .open, w: .small, base: 26), "Light stone", "One-time task")
                kind(Stone(state: .open, w: .small, dark: true, base: 26), "Dark stone", "Ongoing task")
                Text("Both kinds glow the same colors. At home, urgent stones pulse.").font(.app(12.5)).foregroundStyle(Color.muted)
            }
            .glassCard()
            VStack(alignment: .leading, spacing: 10) {
                ForEach(Weight.allCases) { w in kind(Stone(state: .open, w: w, base: 26), "\(w.label) stone", w.hint) }
                Text("A full jar of big stones means someone's carrying a lot.").font(.app(12.5)).foregroundStyle(Color.muted)
            }
            .glassCard()
            Button("Choose your own colors") { colors = true }.buttonStyle(GhostButton())
        case 7:
            head("Step 7 of 8 · Try it", "Stones charge in the jar", "The jars sit on the base, so every stone charges while it's in a jar. Spare stones charge on the round end. You never have to move a stone just to charge it.")
            stage {
                HStack(spacing: 20) {
                    VStack(spacing: 6) { Stone(state: .done, base: 40).opacity(0.5); Text("Left out, it fades").font(.app(12)) }
                    Image(systemName: "arrow.right").font(.system(size: 16, weight: .semibold))
                    VStack(spacing: 6) { Stone(state: .open, base: 40); Text("Back in a jar").font(.app(12)) }
                }
                .foregroundStyle(.white.opacity(0.85))
                HStack(spacing: 8) {
                    ForEach(0..<3, id: \.self) { _ in RoundedRectangle(cornerRadius: 6).fill(.white.opacity(0.18)).frame(width: 52, height: 20) }
                    Capsule().fill(.white.opacity(0.18)).frame(width: 60, height: 20).overlay(Stone(state: .open, w: .small, base: 18))
                }
                HStack { Text("Jars charge here"); Spacer(); Text("Spares charge here") }.font(.app(11.5, .semibold)).foregroundStyle(Color(hex: 0x8cc4f6)).padding(.horizontal, 30)
            }
            Text("If a stone stays out, like on a table, we'll let you know before it runs low.").font(.app(13)).foregroundStyle(Color.muted).multilineTextAlignment(.center).frame(maxWidth: .infinity)
        default:
            let paired = store.stones.filter { $0.task != nil }.count
            let list = store.active.filter { $0.who != nil }.sorted { ($0.who == "you" ? 0 : 1) < ($1.who == "you" ? 0 : 1) }
            head("Step 8 of 8 · Almost done", "Pair the rest", "Each task takes a stone its size: S, M or L. Pair them now, or anyone can pair their own later.")
            VStack(alignment: .leading, spacing: 8) {
                HStack { Text("\(paired) of \(store.stones.count) paired").font(.app(15, .semibold)); Spacer(); Text("\(store.stones.count - paired) to go").font(.meta).foregroundStyle(Color.muted) }
                ProgressView(value: Double(paired), total: Double(store.stones.count)).tint(.shoalBlue)
            }
            .glassCard()
            VStack(spacing: 0) {
                ForEach(more ? list : Array(list.prefix(5))) { t in
                    HStack {
                        TaskLine(t: t, action: {}).allowsHitTesting(false)
                        if store.stoneOf(t.id) != nil {
                            Text("✓ Paired").font(.app(13, .semibold)).foregroundStyle(Color.shoalBlue)
                        } else {
                            Button("Pair \(t.w.label.prefix(1))") {
                                if let s = store.pair(t.id) { store.say("\(s.label) paired · \(s.size.label.lowercased())") } else { store.say("All \(store.stones.count) stones are in use") }
                            }
                            .font(.app(13.5, .semibold)).padding(.horizontal, 12).frame(height: 30).background(Color.blueTint, in: .capsule)
                            .accessibilityLabel("Pair a \(t.w.label.lowercased()) stone")
                        }
                    }
                }
                if list.count > 5 {
                    Button(more ? "Show fewer" : "+ \(list.count - 5) more tasks") { withAnimation(.snappy) { more.toggle() } }
                        .font(.app(14, .semibold)).padding(.top, 8)
                }
            }
            .glassCard(padding: 12)
        }
    }

    @ViewBuilder private var footer: some View {
        switch step {
        case 0: VStack(spacing: 6) { Button("Start setup", action: next).buttonStyle(PrimaryButton()); Button("Do it later") { store.kitSetup = false }.font(.app(15, .semibold)).frame(height: 36) }
        case 1: Button("The jars are on", action: next).buttonStyle(PrimaryButton())
        case 2: Button("I've got one", action: next).buttonStyle(PrimaryButton())
        case 3:
            VStack(spacing: 6) {
                Button("It's paired") {
                    if let t = first, let s = store.pair(t.id) { store.say("\(s.label) paired · \(s.size.label.lowercased())") }
                    next()
                }
                .buttonStyle(PrimaryButton(enabled: heard)).disabled(!heard)
                Button("Stone not lighting up?") { store.say("Set it in a jar or on the base for 10 minutes, then try again") }
                    .font(.app(15, .semibold)).frame(height: 36)
            }
        case 4: Button("It's in my jar", action: next).buttonStyle(PrimaryButton())
        case 5:
            if blink == nil {
                Button("Find stone") { blink = first?.id }.buttonStyle(PrimaryButton())
            } else {
                HStack(spacing: 10) {
                    Button("Not yet") { store.say("Lift the lid and look again. It blinks for 30 seconds."); blink = nil; Task { try? await Task.sleep(for: .seconds(0.1)); blink = first?.id } }
                        .buttonStyle(GhostButton())
                    Button("Yes, I see it") { blink = nil; next() }.buttonStyle(PrimaryButton())
                }
            }
        case 6: Button("Next", action: next).buttonStyle(PrimaryButton())
        case 7: Button("Got it", action: next).buttonStyle(PrimaryButton())
        default:
            VStack(spacing: 6) {
                Button("Go to Home") {
                    store.setup?.insert("stones")
                    store.kitSetup = false
                    store.tab = 0
                    store.say("Your kit is set up")
                }
                .buttonStyle(PrimaryButton())
                Button("Do this later") { store.kitSetup = false }.font(.app(15, .semibold)).frame(height: 36)
            }
        }
    }

    private func steps(_ rows: [(String, String)]) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            ForEach(Array(rows.enumerated()), id: \.offset) { k, r in StepRow(n: k + 1, t: r.0, d: r.1) }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard()
    }

    private func kind(_ s: Stone, _ t: String, _ d: String) -> some View {
        HStack(spacing: 12) {
            s.frame(width: 40)
            VStack(alignment: .leading, spacing: 1) {
                Text(t).font(.app(14.5, .semibold)).foregroundStyle(Color.ink)
                Text(d).font(.app(12.5)).foregroundStyle(Color.muted)
            }
        }
    }

    private func pairTo(_ t: CareTask) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Eyebrow(text: "Pairing it to")
            TaskLine(t: t, action: {}).allowsHitTesting(false)
        }
        .glassCard(padding: 12)
    }
}

// MARK: - Home kit

// Readings sit flat on the background (nothing to tap). Tiles are things you change. Rarely used things are rows at the bottom.
// The kit is a device screen, so it is dark night blue, like the room the jars sit in.
struct KitView: View {
    @Environment(Store.self) private var store
    @State private var colors = false
    @State private var pairing = false
    @State private var nightSheet = false
    @State private var stop = false

    private let bg = Color(hex: 0x0c1a30)
    private let card = Color.white.opacity(0.07)

    var body: some View {
        @Bindable var store = store
        let out = store.stones.filter(\.out)
        let total = store.stones.count
        let charging = total - out.count
        let avg = store.stones.reduce(0) { $0 + $1.battery } / max(total, 1)
        let paired = store.stones.filter { $0.task != nil }.count
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("Home kit").font(.title(32)).foregroundStyle(.white)
                HStack(spacing: 6) { Circle().fill(Color(hex: 0x6fd08c)).frame(width: 8, height: 8); Text("Base connected") }
                    .font(.app(13.5, .medium)).foregroundStyle(.white.opacity(0.75))

                ForEach(out) { s in
                    Button { store.go(.stone(s.id)) } label: {
                        HStack(spacing: 12) {
                            ZStack {
                                KitRing(f: Double(s.battery) / 100, size: 34, line: 3, tint: Color(hex: 0xf6d27c))
                                Text("!").font(.app(14, .bold)).foregroundStyle(Color(hex: 0xf6d27c))
                            }
                            VStack(alignment: .leading, spacing: 2) {
                                Text("\(s.label) is \(s.task == nil ? "off the base" : "out of its jar")").font(.app(15, .semibold)).foregroundStyle(.white)
                                Text("\(s.battery)% · not charging").font(.meta).foregroundStyle(.white.opacity(0.65))
                            }
                            Spacer()
                            Text("Find").font(.app(13.5, .semibold)).foregroundStyle(bg)
                                .padding(.horizontal, 14).frame(height: 30).background(.white, in: .capsule)
                        }
                        .padding(14).background(card, in: .rect(cornerRadius: 20))
                    }
                    .buttonStyle(Pressable())
                }

                VStack(spacing: 16) {
                    HStack {
                        Text("Glow").font(.app(13, .semibold)).foregroundStyle(.white.opacity(0.7))
                        Spacer()
                        Picker("Glow", selection: Binding(get: { store.glow }, set: { g in
                            withAnimation(.easeInOut(duration: 0.5)) { store.glow = g }
                            store.say(g == .on ? "Stones glow" : g == .dim ? "Stones dimmed" : "Glow off. Colors still show in the app.")
                        })) {
                            Text("On").tag(Glow.on); Text("Dim").tag(Glow.dim); Text("Off").tag(Glow.off)
                        }
                        .pickerStyle(.segmented).frame(width: 180)
                    }
                    FamilyShelf(width: 70, lit: store.glow.lit, dark: true)
                }
                .padding(16)
                .background(RadialGradient(colors: [Color(hex: 0x1d3a66), Color(hex: 0x10223f)], center: .bottom, startRadius: 10, endRadius: 300), in: .rect(cornerRadius: 26))
                .overlay(RoundedRectangle(cornerRadius: 26).strokeBorder(.white.opacity(0.08)))

                HStack {
                    reading(Double(charging) / Double(total), "\(charging)", "/\(total)", "charging")
                    reading(Double(avg) / 100, "\(avg)", "%", "avg battery", low: avg < 30)
                    reading(Double(store.spares.count) / Double(total), "\(store.spares.count)", "", "spares ready")
                }
                .padding(.vertical, 6)
                .accessibilityElement(children: .combine)

                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("Night hours").font(.app(13, .semibold)).foregroundStyle(.white.opacity(0.7))
                            Spacer()
                            Toggle("Night hours", isOn: $store.night.animation(.snappy)).labelsHidden().scaleEffect(0.8).frame(width: 44)
                        }
                        if store.night {
                            HStack(alignment: .firstTextBaseline, spacing: 3) {
                                Text(hourText(store.nightFrom).0).font(.app(28, .semibold)).foregroundStyle(.white)
                                Text(hourText(store.nightFrom).1).font(.app(13, .semibold)).foregroundStyle(.white.opacity(0.7))
                            }
                            Text("until \(hourText(store.nightTo).0) \(hourText(store.nightTo).1)").font(.meta).foregroundStyle(.white.opacity(0.65))
                            Button { nightSheet = true } label: { HStack(spacing: 4) { Text("Change"); Image(systemName: "chevron.right") } }
                                .font(.app(13, .semibold)).foregroundStyle(Color(hex: 0x8cc4f6))
                        } else {
                            Text("Off").font(.app(28, .semibold)).foregroundStyle(.white)
                            Text("Stones glow all night").font(.meta).foregroundStyle(.white.opacity(0.65))
                        }
                    }
                    .frame(maxWidth: .infinity, minHeight: 130, alignment: .topLeading)
                    .padding(14).background(card, in: .rect(cornerRadius: 22))

                    Button { colors = true } label: {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack { Text("Stone colors").font(.system(size: 13, weight: .semibold)).foregroundStyle(.white.opacity(0.7)); Spacer(); Image(systemName: "chevron.right").font(.system(size: 12, weight: .semibold)).foregroundStyle(.white.opacity(0.5)) }
                            HStack(spacing: 6) { ForEach(COLOR_STATES, id: \.self) { s in Stone(state: s, w: .small, base: 28) } }.frame(height: 30)
                            Text(store.colors.summary).font(.app(12.5)).foregroundStyle(.white.opacity(0.65)).multilineTextAlignment(.leading)
                        }
                        .frame(maxWidth: .infinity, minHeight: 130, alignment: .topLeading)
                        .padding(14).background(card, in: .rect(cornerRadius: 22))
                    }
                    .buttonStyle(Pressable())
                }

                VStack(spacing: 0) {
                    row("All stones", "\(paired) paired · \(total - paired) spare") { store.go(.stones) }
                    Divider().overlay(.white.opacity(0.1))
                    row("Pair a stone", nil) { pairing = true }
                    Divider().overlay(.white.opacity(0.1))
                    row("Setup guide", nil) { store.kitSetup = true }
                }
                .padding(.horizontal, 14).background(card, in: .rect(cornerRadius: 22))

                Button("Stop using the kit") { stop = true }
                    .font(.app(15, .semibold)).foregroundStyle(.white.opacity(0.7)).frame(maxWidth: .infinity).padding(.top, 6)
                .confirmationDialog("Stop using the kit?", isPresented: $stop, titleVisibility: .visible) {
                    Button("Stop using the kit", role: .destructive) {
                        store.kit = false
                        for i in store.stones.indices { store.stones[i].task = nil }
                        store.back()
                        store.say("Kit off. Everything still works in the app.")
                    }
                    Button("Cancel", role: .cancel) {}
                } message: { Text("Stones are unpaired. Your tasks and jars in the app stay the same.") }
            }
            .padding(.horizontal, 20).padding(.bottom, 30)
        }
        .background(bg.ignoresSafeArea())
        .toolbarBackground(bg, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $colors) { ColorsSheet() }
        .sheet(isPresented: $pairing) { PairSheet().presentationDetents([.medium, .large]) }
        .sheet(isPresented: $nightSheet) { NightSheet().presentationDetents([.height(340)]) }
    }

    private func reading(_ f: Double, _ val: String, _ unit: String, _ lab: String, low: Bool = false) -> some View {
        VStack(spacing: 6) {
            ZStack {
                KitRing(f: f, size: 72, line: 5, tint: low ? Color(hex: 0xf6d27c) : Color(hex: 0x8cc4f6))
                HStack(alignment: .firstTextBaseline, spacing: 1) {
                    Text(val).font(.app(20, .semibold))
                    Text(unit).font(.app(11, .semibold)).foregroundStyle(.white.opacity(0.6))
                }
                .foregroundStyle(.white)
            }
            Text(lab).font(.app(12)).foregroundStyle(.white.opacity(0.65))
        }
        .frame(maxWidth: .infinity)
    }

    private func row(_ t: String, _ m: String?, _ a: @escaping () -> Void) -> some View {
        Button(action: a) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(t).font(.app(15.5, .semibold)).foregroundStyle(.white)
                    if let m { Text(m).font(.meta).foregroundStyle(.white.opacity(0.6)) }
                }
                Spacer()
                Image(systemName: "chevron.right").font(.system(size: 13, weight: .semibold)).foregroundStyle(.white.opacity(0.4))
            }
            .padding(.vertical, 14)
        }
        .buttonStyle(Pressable())
    }
}

func hourText(_ h: Int) -> (String, String) {
    let hh = h % 12 == 0 ? 12 : h % 12
    return ("\(hh):00", h < 12 ? "AM" : "PM")
}

// A thin progress ring. It fills in from empty when it first draws.
struct KitRing: View {
    var f: Double
    var size: CGFloat
    var line: CGFloat
    var tint: Color
    @State private var shown = false
    var body: some View {
        ZStack {
            Circle().stroke(tint.opacity(0.18), lineWidth: line)
            Circle().trim(from: 0, to: shown ? max(0, min(1, f)) : 0)
                .stroke(tint, style: .init(lineWidth: line, lineCap: .round)).rotationEffect(.degrees(-90))
        }
        .frame(width: size, height: size)
        .onAppear { withAnimation(.easeOut(duration: 0.9)) { shown = true } }
    }
}

struct NightSheet: View {
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        @Bindable var store = store
        VStack(alignment: .leading, spacing: 14) {
            Text("Night hours").font(.title(26)).foregroundStyle(Color.navy)
            Text("Stones stay dark so they don't light up the room at night. Urgent stones still glow softly.").font(.body15).foregroundStyle(Color.muted)
            HStack {
                Picker("From", selection: $store.nightFrom) { ForEach(17..<24, id: \.self) { h in Text("\(hourText(h).0) \(hourText(h).1)").tag(h) } }
                    .fixedSize()
                Spacer()
                Text("until").foregroundStyle(Color.muted)
                Spacer()
                Picker("To", selection: $store.nightTo) { ForEach(5..<11, id: \.self) { h in Text("\(hourText(h).0) \(hourText(h).1)").tag(h) } }
                    .fixedSize()
            }
            .glassCard()
            Button("Done") { dismiss(); store.say("Night hours saved") }.buttonStyle(PrimaryButton())
        }
        .padding(24)
    }
}

// Pairs a spare stone to any task that doesn't have one.
struct PairSheet: View {
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss
    var only: Int? = nil   // a specific stone, from its page
    var body: some View {
        let list = store.active.filter { store.stoneOf($0.id) == nil }
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Pair a stone").font(.title(26)).foregroundStyle(Color.navy)
                    Text("Pick a task. \(only == nil ? "It gets a spare stone its size." : "This stone glows as soon as it's paired.")").font(.body15).foregroundStyle(Color.muted)
                    if list.isEmpty { Text("Every task has a stone.").font(.body15).foregroundStyle(Color.muted).padding(.top, 10) }
                    VStack(spacing: 0) {
                        ForEach(list) { t in
                            if t.id != list.first?.id { RowSep() }
                            TaskLine(t: t, action: { pair(t) })
                        }
                    }
                    .glassCard(padding: 12)
                }
                .padding(20)
            }
            .background(AppBackground())
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
        }
    }

    private func pair(_ t: CareTask) {
        if let id = only, let j = store.stones.firstIndex(where: { $0.id == id }) {
            store.stones[j].task = t.id
            store.say("\(store.stones[j].label) paired to “\(t.n)”")
        } else if let s = store.pair(t.id) {
            store.say("\(s.label) paired · \(s.size.label.lowercased())")
        } else {
            store.say("All \(store.stones.count) stones are in use")
        }
        dismiss()
    }
}

// MARK: - All stones

struct StonesView: View {
    @Environment(Store.self) private var store
    @State private var filter = "all"
    @State private var pairing = false

    var body: some View {
        let paired = store.stones.filter { $0.task != nil }.count
        let keep: (KitStone) -> Bool = { s in filter == "unpaired" ? s.task == nil : filter == "out" ? s.out : true }
        var groups: [(String, [KitStone])] = []
        let out = store.stones.filter { $0.out && keep($0) }
        if !out.isEmpty { groups.append(("Not charging", out)) }
        for p in store.mainPeople {
            let l = store.stones.filter { !$0.out && store.inJar($0) && store.task($0.task!)?.who == p.id && keep($0) }
            if !l.isEmpty { groups.append((p.id == "you" ? "In your jar" : "In \(p.name)'s jar", l)) }
        }
        let base = store.stones.filter { !$0.out && !store.inJar($0) && keep($0) }
        if !base.isEmpty { groups.append(("On the base", base)) }

        return Page {
            Text("Stones").font(.title()).foregroundStyle(Color.navy)
            Text("\(store.stones.count) stones (S, M and L) · \(paired) paired. Stones charge in the jars and on the base.").font(.body15).foregroundStyle(Color.muted)
            HStack(spacing: 8) {
                chip("All", "all")
                chip("Unpaired \(store.stones.count - paired)", "unpaired")
                chip("Not charging \(store.stones.filter(\.out).count)", "out")
            }
            if groups.isEmpty { Text("No stones here.").font(.body15).foregroundStyle(Color.muted).padding(.top, 10) }
            ForEach(groups, id: \.0) { g in
                SectionH(text: g.0)
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 3), spacing: 10) {
                    ForEach(g.1) { s in card(s) }
                }
            }
        }
        .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Pair a stone") { pairing = true } } }
        .sheet(isPresented: $pairing) { PairSheet().presentationDetents([.medium, .large]) }
    }

    private func chip(_ l: String, _ id: String) -> some View {
        Button { withAnimation(.snappy) { filter = id } } label: {
            Text(l).font(.app(13.5, .semibold)).foregroundStyle(filter == id ? .white : Color.ink)
                .padding(.horizontal, 12).frame(height: 32).background(filter == id ? Color.shoalBlue : .white.opacity(0.85), in: .capsule)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(filter == id ? .isSelected : [])
    }

    private func card(_ s: KitStone) -> some View {
        let t = s.task.flatMap(store.task)
        return Button { store.go(.stone(s.id)) } label: {
            VStack(spacing: 5) {
                Group {
                    if let t { Stone(state: t.state, w: s.size, dark: t.kind == .repeating, base: 30) } else { Stone(state: .open, w: s.size, base: 30).opacity(0.45) }
                }
                .frame(height: 34)
                HStack(spacing: 3) {
                    Text(String(format: "%02d", s.id)).font(.app(14, .semibold)).foregroundStyle(Color.ink)
                    Text(s.size.label.prefix(1)).font(.app(10.5, .bold)).foregroundStyle(Color.muted)
                        .padding(.horizontal, 4).background(Color(hex: 0xeef1f5), in: .rect(cornerRadius: 4))
                }
                Text(t?.n ?? "Not paired").font(.app(11)).foregroundStyle(Color.muted).lineLimit(1)
                Text(s.out ? "\(s.battery)%" : "⚡ \(s.battery)%").font(.app(11, .semibold)).foregroundStyle(s.out ? Color.alert : Color.shoalBlue)
            }
            .frame(maxWidth: .infinity).glassCard(radius: 18, padding: 10)
        }
        .buttonStyle(Pressable())
        .accessibilityLabel("\(s.label), \(t?.n ?? "not paired"), \(s.battery) percent")
    }
}

// MARK: - One stone

struct StoneDetailView: View {
    @Environment(Store.self) private var store
    var id: Int
    @State private var blink = false
    @State private var pairing = false

    var body: some View {
        if let s = store.stones.first(where: { $0.id == id }) {
            let t = s.task.flatMap(store.task)
            let st = t?.state ?? .open
            Page {
                VStack(spacing: 12) {
                    Group {
                        if let t { Stone(state: st, w: s.size, dark: t.kind == .repeating, base: 110) } else { Stone(state: .open, w: s.size, base: 110).opacity(0.45) }
                    }
                    .opacity(blink ? 0.2 : 1)
                    .frame(height: 200).frame(maxWidth: .infinity)
                    .background(RadialGradient(colors: [Color(hex: 0x1d3a66), Color(hex: 0x0e1f3a)], center: .center, startRadius: 10, endRadius: 220), in: .rect(cornerRadius: 26))
                    Text(s.label).font(.title()).foregroundStyle(Color.navy)
                    Text("\(store.place(s)) · last seen 2 min ago").font(.meta).foregroundStyle(Color.muted)
                    HStack(spacing: 8) {
                        badge(t == nil ? "Spare" : st == .done ? "Resting" : "Glowing · \(st.short.lowercased())", amber: st == .urgent && t != nil)
                        badge(s.out ? "▮ \(s.battery)% · about \(plural(max(1, s.battery / 25), "day")) left" : "⚡ \(s.battery)% · charging", amber: s.out)
                    }
                }
                .frame(maxWidth: .infinity)
                if s.out {
                    HStack(spacing: 10) {
                        Stone(state: .done, w: .small, base: 18)
                        Text("Put it back in a jar or on the base and it charges on its own.").font(.app(13.5)).foregroundStyle(Color.ink)
                    }
                    .glassCard(padding: 12)
                }
                Button("Make it blink to find it") { blinkIt(s) }.buttonStyle(GhostButton())
                SectionH(text: "Paired to")
                if let t {
                    TaskLine(t: t).glassCard(padding: 12)
                } else {
                    Button { pairing = true } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "plus").font(.system(size: 15, weight: .bold)).foregroundStyle(Color.shoalBlue).frame(width: 36, height: 36).background(Color.blueTint, in: .rect(cornerRadius: 10))
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Pair it to a task").font(.app(15, .semibold)).foregroundStyle(Color.ink)
                                Text("It glows as soon as it's paired").font(.meta).foregroundStyle(Color.muted)
                            }
                            Spacer(); Chevron()
                        }
                        .glassCard(padding: 12)
                    }
                    .buttonStyle(Pressable())
                }
                SectionH(text: "About")
                VStack(spacing: 10) {
                    about("Model", "Shoal Stone")
                    about("Size", "\(s.size.label) · for \(s.size.label.lowercased()) tasks")
                    about("Generation", "Gen 1 · 2026")
                    about("Colorway", (t.map { $0.kind == .once } ?? (s.id % 3 != 0)) ? "Light · for one-time tasks" : "Dark · for ongoing tasks")
                }
                .glassCard()
                if t != nil {
                    Button("Unpair this stone", role: .destructive) {
                        if let j = store.stones.firstIndex(where: { $0.id == id }) { store.stones[j].task = nil; store.say("\(s.label) is a spare again") }
                    }
                    .font(.app(15, .semibold)).frame(maxWidth: .infinity).padding(.top, 6)
                }
            }
            .sheet(isPresented: $pairing) { PairSheet(only: id).presentationDetents([.medium, .large]) }
        }
    }

    private func badge(_ s: String, amber: Bool) -> some View {
        Text(s).font(.app(12.5, .semibold)).foregroundStyle(amber ? Color(hex: 0x8a5d0c) : Color.ink)
            .padding(.horizontal, 10).padding(.vertical, 5).background(amber ? Color(hex: 0xf6d27c, 0.3) : .white.opacity(0.85), in: .capsule)
    }

    private func about(_ k: String, _ v: String) -> some View {
        HStack { Text(k).foregroundStyle(Color.muted); Spacer(); Text(v).fontWeight(.semibold).foregroundStyle(Color.ink) }.font(.app(14))
    }

    private func blinkIt(_ s: KitStone) {
        store.say("\(s.label) is blinking for 30 seconds")
        Task {
            for _ in 0..<8 {
                withAnimation(.easeInOut(duration: 0.3)) { blink.toggle() }
                try? await Task.sleep(for: .seconds(0.45))
            }
            blink = false
        }
    }
}
