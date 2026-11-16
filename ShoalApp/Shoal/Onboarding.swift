import SwiftUI

// First open: logo splash → sign in (phone, Google, Facebook) → text code → intro to Shoal →
// welcome → about them → who's helping → stone colors. Then Home, with a checklist for the rest.
struct FirstOpenView: View {
    @Environment(Store.self) private var store

    var body: some View {
        ZStack {
            AppBackground()
            Group {
                switch store.first {
                case .splash: SplashView()
                case .signin: SignInView()
                case .verify: VerifyView()
                case .intro: IntroView()
                case .welcome: WelcomeView()
                case .about: AboutView()
                case .people: InvitePeopleView()
                case .colors: ColorsStepView()
                }
            }
            .id(store.first)
            .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .opacity))
        }
        .overlay(alignment: .top) {
            if let t = store.toast { ToastView(text: t).padding(.top, 4) }
        }
    }
}

extension Store {
    func step(_ s: FirstStage) { withAnimation(.smooth(duration: 0.4)) { first = s } }
    func signedIn(_ msg: String) { step(.intro); say(msg) }
    // Done with onboarding: the app, with the setup checklist on Home.
    func finishOnboarding(_ msg: String) {
        if lovedName.trimmingCharacters(in: .whitespaces) != LOVED {
            LOVED = lovedName.trimmingCharacters(in: .whitespaces)
            tasks = demoTasks()
        }
        setup = []
        tab = 0
        withAnimation(.smooth(duration: 0.45)) { onboarded = true }
        say(msg)
    }
    func skipToApp() {
        tab = 0
        if kit == nil { kit = true }   // the sample family shows the physical kit too, as on the web
        withAnimation(.smooth(duration: 0.45)) { onboarded = true }
        say("Skipped onboarding")
    }
}

// MARK: - Splash

struct SplashView: View {
    @Environment(Store.self) private var store
    @State private var word = false
    var body: some View {
        VStack(spacing: 14) {
            ShoalMark(s: 104, assemble: true)
            Text("shoal").font(.title(40)).tracking(-0.02 * 40).foregroundStyle(Color(hex: 0x0F4C93))
                .opacity(word ? 1 : 0).offset(y: word ? 0 : 8)
            Text("Share caregiving with your family").font(.body15).foregroundStyle(Color.muted)
                .opacity(word ? 1 : 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(.rect)
        .onTapGesture { store.step(.signin) }
        .task {
            try? await Task.sleep(for: .seconds(0.9))
            withAnimation(.easeOut(duration: 0.6)) { word = true }
            try? await Task.sleep(for: .seconds(2.5))
            if store.first == .splash { store.step(.signin) }
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
    }
}

// MARK: - Sign in

func fmtPhone(_ d: String) -> String {
    let c = Array(d)
    if c.count < 4 { return d }
    if c.count < 7 { return "(\(String(c[0..<3]))) \(String(c[3...]))" }
    return "(\(String(c[0..<3]))) \(String(c[3..<6]))-\(String(c[6...]))"
}

/// A phone field that formats as you type, "(408) 555-1234". It edits the text itself on every keystroke,
/// so fast typing never loses digits the way reformatting a SwiftUI TextField after the fact can.
struct PhoneField: UIViewRepresentable {
    @Binding var digits: String
    @Binding var focused: Bool

    func makeUIView(context: Context) -> UITextField {
        let t = UITextField()
        t.placeholder = "(555) 123-4567"
        t.keyboardType = .numberPad
        t.textContentType = .telephoneNumber
        t.font = .systemFont(ofSize: 17)
        t.textColor = UIColor(Color.ink)
        t.delegate = context.coordinator
        t.setContentHuggingPriority(.defaultLow, for: .horizontal)
        t.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        t.text = fmtPhone(digits)
        return t
    }

    func updateUIView(_ t: UITextField, context: Context) {
        context.coordinator.parent = self
        if t.text != fmtPhone(digits) { t.text = fmtPhone(digits) }
        if !focused, t.isFirstResponder { DispatchQueue.main.async { t.resignFirstResponder() } }
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, UITextFieldDelegate {
        var parent: PhoneField
        init(_ p: PhoneField) { parent = p }

        func textField(_ t: UITextField, shouldChangeCharactersIn range: NSRange, replacementString s: String) -> Bool {
            let old = t.text ?? ""
            guard let r = Range(range, in: old) else { return false }
            var head = old[..<r.lowerBound].filter(\.isNumber)
            let tail = old[r.upperBound...].filter(\.isNumber)
            // Backspacing over "(", ")", " " or "-" removes the digit before it.
            if s.isEmpty, range.length > 0, old[r].allSatisfy({ !$0.isNumber }), !head.isEmpty { head.removeLast() }
            var d = head + s.filter(\.isNumber) + tail
            if d.count == 11, d.hasPrefix("1") { d.removeFirst() }
            d = String(d.prefix(10))
            let caretDigits = min(d.count, head.count + s.filter(\.isNumber).count)
            let f = fmtPhone(d)
            t.text = f
            // Put the caret after the same number of digits it was after.
            var seen = 0, off = 0
            for ch in f { if seen == caretDigits { break }; if ch.isNumber { seen += 1 }; off += 1 }
            if let pos = t.position(from: t.beginningOfDocument, offset: off) { t.selectedTextRange = t.textRange(from: pos, to: pos) }
            parent.digits = d
            return false
        }
        func textFieldDidBeginEditing(_ t: UITextField) { parent.focused = true }
        func textFieldDidEndEditing(_ t: UITextField) { parent.focused = false }
    }
}

struct SignInView: View {
    @Environment(Store.self) private var store
    @State private var via: String?
    @State private var focus = false

    var body: some View {
        let ready = store.phone.count == 10
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Lockup(size: 40).frame(maxWidth: .infinity).padding(.top, 36).padding(.bottom, 18)
                Text("Sign in to get started").font(.title(30)).foregroundStyle(Color.navy)
                Text("Enter your phone number and we'll text you a code. You don't need a password.").font(.body15).foregroundStyle(Color.muted)
                HStack(spacing: 10) {
                    Text("🇺🇸 +1").font(.app(16, .medium)).foregroundStyle(Color.ink)
                    Divider().frame(height: 22)
                    PhoneField(digits: Bindable(store).phone, focused: $focus)
                        .frame(height: 54).accessibilityLabel("Phone number")
                }
                .padding(.horizontal, 16).frame(height: 54)
                .background(.white, in: .rect(cornerRadius: 16))
                .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(focus ? Color.shoalBlue : Color(hex: 0xdde1e6), lineWidth: focus ? 1.5 : 1))
                Button("Text me a code") { focus = false; store.step(.verify) }
                    .buttonStyle(PrimaryButton(enabled: ready)).disabled(!ready)
                HStack { line; Text("or").font(.meta).foregroundStyle(Color.muted); line }.padding(.vertical, 4)
                social("Google") {
                    Text("G").font(.app(17, .bold)).foregroundStyle(LinearGradient(colors: [Color(hex: 0xEA4335), Color(hex: 0xFBBC05), Color(hex: 0x34A853), Color(hex: 0x4285F4)], startPoint: .topLeading, endPoint: .bottomTrailing))
                }
                social("Facebook") {
                    Text("f").font(.app(15, .bold)).foregroundStyle(.white).frame(width: 20, height: 20).background(Color(hex: 0x1877F2), in: .circle)
                }
                Text("By continuing, you agree to Shoal's Terms and Privacy Policy. Your carrier may charge for texts.")
                    .font(.app(12)).foregroundStyle(Color.muted).padding(.top, 6)
                Button("Skip sign-in (testing) →") { store.signedIn("Skipped sign-in") }
                    .font(.app(13, .semibold)).foregroundStyle(Color.muted).frame(maxWidth: .infinity).padding(.top, 4)
            }
            .padding(.horizontal, 24).padding(.bottom, 30)
        }
        .scrollDismissesKeyboard(.interactively)
    }

    private var line: some View { Rectangle().fill(Color(hex: 0xdde1e6)).frame(height: 1) }

    private func social<I: View>(_ name: String, @ViewBuilder icon: () -> I) -> some View {
        Button {
            via = name
            Task {
                try? await Task.sleep(for: .seconds(1.2))
                if store.first == .signin { store.signedIn("Signed in with \(name)") }
            }
        } label: {
            HStack(spacing: 10) {
                if via == name { ProgressView().controlSize(.small); Text("Connecting…") } else { icon(); Text("Continue with \(name)") }
            }
            .font(.app(15.5, .semibold)).foregroundStyle(Color.ink)
            .frame(maxWidth: .infinity).frame(height: 52)
            .background(.white, in: .capsule).overlay(Capsule().strokeBorder(Color(hex: 0xdde1e6)))
        }
        .buttonStyle(Pressable())
        .disabled(via != nil)
    }
}

// MARK: - Text code

struct VerifyView: View {
    @Environment(Store.self) private var store
    @State private var code = ""
    @State private var sentAt = Date.now
    @State private var sms = false
    @State private var checking = false
    @FocusState private var focus: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Button { store.step(.signin) } label: { Label("Back", systemImage: "chevron.left").font(.app(16, .medium)) }
                .padding(.top, 8)
            Eyebrow(text: "Verify your number").padding(.top, 14)
            Text("Enter the 6-digit code").font(.title(30)).foregroundStyle(Color.navy)
            HStack(spacing: 4) {
                Text("Sent to +1 \(fmtPhone(store.phone)).").foregroundStyle(Color.muted)
                Button("Change number") { store.step(.signin) }.fontWeight(.semibold)
            }
            .font(.body15)
            ZStack {
                TextField("", text: $code)
                    .keyboardType(.numberPad).textContentType(.oneTimeCode).focused($focus)
                    .foregroundStyle(.clear).tint(.clear).accessibilityLabel("6-digit code")
                    .onChange(of: code) {
                        code = String(code.filter(\.isNumber).prefix(6))
                        if code.count == 6 { entered() }
                    }
                    .disabled(checking)
                HStack(spacing: 8) {
                    ForEach(0..<6, id: \.self) { i in
                        let ch = Array(code)
                        Text(i < ch.count ? String(ch[i]) : "")
                            .font(.title(24)).tracking(-0.02 * 24).foregroundStyle(Color.navy)
                            .frame(maxWidth: .infinity).frame(height: 56)
                            .background(.white, in: .rect(cornerRadius: 14))
                            .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(checking ? Color(hex: 0x3a9a5b) : i == ch.count && focus ? Color.shoalBlue : Color(hex: 0xdde1e6), lineWidth: i == ch.count || checking ? 1.5 : 1))
                    }
                }
                .allowsHitTesting(false)
            }
            .contentShape(.rect)
            .onTapGesture { focus = true }
            .padding(.top, 6)
            Group {
                if checking {
                    HStack(spacing: 8) { ProgressView().controlSize(.small); Text("Checking the code…") }
                } else {
                    TimelineView(.periodic(from: .now, by: 1)) { ctx in
                        let left = max(0, 30 - Int(ctx.date.timeIntervalSince(sentAt)))
                        if left > 0 {
                            Text("No text yet? You can resend in 0:\(String(format: "%02d", left))")
                        } else {
                            HStack(spacing: 4) {
                                Text("No text yet?")
                                Button("Resend code") { resend() }.fontWeight(.semibold)
                            }
                        }
                    }
                }
            }
            .font(.meta).foregroundStyle(Color.muted)
            Text("Prototype: any 6 digits work, or tap the text that comes in.").font(.app(12)).foregroundStyle(Color.muted)
                .frame(maxWidth: .infinity).padding(.top, 10)
            Spacer()
        }
        .padding(.horizontal, 24)
        .overlay(alignment: .top) {
            if sms {
                Button { code = "482913" } label: {
                    HStack(alignment: .top, spacing: 10) {
                        ShoalMark(s: 22).padding(6).background(.white, in: .rect(cornerRadius: 8))
                        VStack(alignment: .leading, spacing: 2) {
                            HStack { Text("Messages").font(.app(13, .semibold)); Spacer(); Text("now").font(.app(12)).foregroundStyle(.secondary) }
                            Text("Your Shoal code is 482913. Don't share it with anyone.").font(.app(14)).multilineTextAlignment(.leading)
                        }
                    }
                    .foregroundStyle(Color.ink)
                    .padding(12)
                    .background(.regularMaterial, in: .rect(cornerRadius: 22))
                    .shadow(color: .black.opacity(0.15), radius: 14, y: 8)
                    .padding(.horizontal, 10)
                }
                .buttonStyle(Pressable())
                .transition(.move(edge: .top).combined(with: .opacity))
                .accessibilityLabel("Text message with your code")
            }
        }
        .onAppear { focus = true }
        .task(id: sentAt) { await textArrives() }
    }

    private func textArrives() async {
        try? await Task.sleep(for: .seconds(1.4))
        guard !checking else { return }
        withAnimation(.spring(duration: 0.5)) { sms = true }
        try? await Task.sleep(for: .seconds(7))
        withAnimation(.easeIn(duration: 0.3)) { sms = false }
    }

    private func resend() {
        withAnimation { sms = false }
        sentAt = .now
        store.say("New code sent")
    }

    private func entered() {
        guard !checking else { return }
        focus = false
        withAnimation { sms = false; checking = true }
        Task {
            try? await Task.sleep(for: .seconds(1.1))
            if store.first == .verify { store.signedIn("Number verified") }
        }
    }
}

// MARK: - Intro

struct IntroView: View {
    @Environment(Store.self) private var store
    @State private var i = 0
    private let n = 5

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Lockup(size: 24)
                Spacer()
                if i < n - 1 { Button("Skip") { store.step(.welcome) }.font(.app(15, .semibold)) }
            }
            .frame(height: 44).padding(.horizontal, 24)
            TabView(selection: $i) {
                slide(0, "Welcome to Shoal", "Share caregiving with your family",
                      "Shoal is a shared to-do list for taking care of someone. Everyone can see what needs to be done and who is doing it.") { circle }
                slide(1, "Tasks", "Each task is a stone",
                      "Every task, like a ride or a refill, gets a stone. Its color tells you if it's urgent, someone is doing it, it's open, or it's done.") { stones }
                slide(2, "Your family", "Each person has a jar",
                      "Your jar holds the tasks you've taken on. You can see who has a lot and who has room for more.") { jars }
                slide(3, "At home", "Real stones light up at home",
                      "You can link a real stone to a task and keep it in a jar at home. It lights up in the same colors, so anyone can check without a phone.") { hold }
                slide(4, "Privacy and security", "Your family's info stays private",
                      "We only use what you share to run your family's plan. We never sell it.") { privacy }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            VStack(spacing: 18) {
                HStack(spacing: 8) {
                    ForEach(0..<n, id: \.self) { k in
                        Button { withAnimation { i = k } } label: {
                            Capsule().fill(k == i ? Color.shoalBlue : Color(hex: 0xc8d3e0)).frame(width: k == i ? 22 : 8, height: 8)
                        }
                        .buttonStyle(.plain).accessibilityLabel("Slide \(k + 1)")
                    }
                }
                Button(i == n - 1 ? "Set up your family's plan" : "Next") {
                    if i < n - 1 { withAnimation { i += 1 } } else { store.step(.welcome) }
                }
                .buttonStyle(PrimaryButton())
            }
            .padding(.horizontal, 24).padding(.bottom, 16)
        }
    }

    private func slide<V: View>(_ k: Int, _ eyebrow: String, _ title: String, _ sub: String, @ViewBuilder visual: () -> V) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            visual().frame(maxWidth: .infinity).frame(height: 330)
            Eyebrow(text: eyebrow)
            Text(title).font(.title(30)).foregroundStyle(Color.navy).fixedSize(horizontal: false, vertical: true)
            Text(sub).font(.body15).foregroundStyle(Color.muted).fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 24)
        .tag(k)
    }

    private var circle: some View {
        ZStack {
            Circle().fill(.white.opacity(0.55)).overlay(Circle().strokeBorder(.white)).frame(width: 250, height: 250)
            Circle().strokeBorder(Color(hex: 0x418ef3, 0.14), lineWidth: 1).frame(width: 180, height: 180)
            ShoalMark(s: 72).phaseAnimator([0, -6]) { v, y in v.offset(y: y) } animation: { _ in .easeInOut(duration: 1.8) }
            ForEach(Array([("avatar-you", "You"), ("avatar-nora", "Nora"), ("avatar-bill", "Bill"), ("avatar-sam", "Sam")].enumerated()), id: \.offset) { k, a in
                let ang = Double(k) * .pi / 2 - .pi / 4
                VStack(spacing: 3) {
                    Image(a.0).resizable().scaledToFill().frame(width: 46, height: 46).clipShape(.circle).overlay(Circle().strokeBorder(.white, lineWidth: 2))
                    Text(a.1).font(.app(12, .semibold)).foregroundStyle(Color.ink)
                }
                .offset(x: cos(ang) * 112, y: sin(ang) * 112)
            }
        }
    }

    private var stones: some View {
        let c = store.colors
        let rows: [(StoneState, String)] = [
            (.urgent, "Refill prescription · urgent"), (.progress, "Drive to PT · Bill is doing it"),
            (.open, "Weekly groceries · open"), (.done, "Call hospice · done"),
        ]
        return VStack(alignment: .leading, spacing: 18) {
            ForEach(Array(rows.enumerated()), id: \.offset) { k, r in
                HStack(spacing: 14) {
                    Stone(state: r.0, w: .large, base: 44).frame(width: 64)
                    Text(r.1).font(.app(14, .medium)).foregroundStyle(Color.ink)
                        .padding(.horizontal, 12).padding(.vertical, 7).background(.white.opacity(0.85), in: .capsule)
                }
                .offset(x: k % 2 == 0 ? 0 : 36)
            }
            Text("\(c.hue(.urgent).name.capitalized) urgent · \(c.hue(.progress).name) someone's on it · \(c.hue(.open).name) open · off when done")
                .font(.app(12)).foregroundStyle(Color.muted)
        }
    }

    private var jars: some View {
        VStack(spacing: 0) {
            HStack(alignment: .bottom, spacing: 18) {
                ForEach(Array([("You", ["done", "done*", "progress", "open*", "urgent"]),
                               ("Nora", ["done", "done", "done*", "progress*", "progress", "open"]),
                               ("Bill", ["done*", "progress", "open"])].enumerated()), id: \.offset) { _, j in
                    VStack(spacing: 6) {
                        SampleJar(states: j.1, width: 82)
                        Text(j.0).font(.app(13, .semibold)).foregroundStyle(Color.ink)
                    }
                }
            }
            RoundedRectangle(cornerRadius: 3).fill(Color(hex: 0xc9b79c, 0.5)).frame(height: 6).padding(.horizontal, 10).offset(y: -24)
        }
    }

    private var hold: some View {
        VStack(spacing: 26) {
            Stone(state: .progress, w: .large, base: 120)
                .phaseAnimator([1, 1.06]) { v, s in v.scaleEffect(s) } animation: { _ in .easeInOut(duration: 1.6) }
            Text("\(store.colors.hue(.progress).name.capitalized) · someone is doing it").font(.app(14, .semibold)).foregroundStyle(Color.ink)
                .padding(.horizontal, 14).padding(.vertical, 8).background(.white.opacity(0.85), in: .capsule)
        }
    }

    private var privacy: some View {
        VStack(spacing: 14) {
            Image(systemName: "lock.fill").font(.system(size: 24)).foregroundStyle(Color.shoalBlue)
                .frame(width: 58, height: 58).background(.white, in: .circle).shadow(color: Color.shoalBlue.opacity(0.15), radius: 10, y: 4)
            VStack(alignment: .leading, spacing: 12) {
                ForEach([("Only people you invite can see your plan", "Not other users, and not advertisers."),
                         ("Calendars only show when you're busy", "Shoal never sees what your events are."),
                         ("Sign-in uses a code sent to your phone", "No password to guess or steal."),
                         ("You can delete your data anytime", "Your account and plan are removed for good.")], id: \.0) { r in
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "checkmark").font(.app(11, .bold)).foregroundStyle(Color.shoalBlue)
                            .frame(width: 22, height: 22).background(Color.blueTint, in: .circle)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(r.0).font(.app(14, .semibold)).foregroundStyle(Color.ink)
                            Text(r.1).font(.app(12.5)).foregroundStyle(Color.muted)
                        }
                    }
                }
            }
            .glassCard()
        }
    }
}

// MARK: - Welcome

struct WelcomeView: View {
    @Environment(Store.self) private var store
    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Let's get you set up").font(.title(34)).foregroundStyle(Color.navy).padding(.top, 30)
                    Text("Three quick things, about 2 minutes. Tasks and the stones can wait until you're ready.").font(.body15).foregroundStyle(Color.muted)
                    HStack(alignment: .bottom, spacing: 10) {
                        ForEach(Array([["done", "done", "done", "open", "progress", "urgent", "progress"],
                                       ["done", "done", "open", "open", "progress", "progress", "urgent", "open"],
                                       ["done", "done", "open", "progress", "open"],
                                       ["done", "done", "open"]].enumerated()), id: \.offset) { _, s in
                            SampleJar(states: s, width: 66)
                        }
                    }
                    .frame(maxWidth: .infinity).padding(.vertical, 18)
                    .glassCard()
                    .accessibilityLabel("Four jars with glowing stones")
                    VStack(alignment: .leading, spacing: 14) {
                        ForEach(Array([("Who you're caring for", "Their name and what they're facing"),
                                       ("Who's helping", "Invite family now, or later"),
                                       ("Your stone colors", "What each glow means to you")].enumerated()), id: \.offset) { k, r in
                            StepRow(n: k + 1, t: r.0, d: r.1)
                        }
                    }
                    .glassCard()
                    Button("Skip onboarding (testing) →") { store.skipToApp() }
                        .font(.app(13, .semibold)).foregroundStyle(Color.muted).frame(maxWidth: .infinity).padding(.top, 6)
                }
                .padding(.horizontal, 24).padding(.bottom, 20)
            }
            Button("Start") { store.step(.about) }.buttonStyle(PrimaryButton()).padding(.horizontal, 24).padding(.bottom, 16)
        }
    }
}

struct StepRow: View {
    var n: Int; var t: String; var d: String
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(n)").font(.app(13, .bold)).foregroundStyle(Color.shoalBlue)
                .frame(width: 26, height: 26).background(Color.blueTint, in: .circle)
            VStack(alignment: .leading, spacing: 2) {
                Text(t).font(.app(15, .semibold)).foregroundStyle(Color.ink)
                Text(d).font(.meta).foregroundStyle(Color.muted)
            }
        }
    }
}

// MARK: - Onboarding steps

// Back, three progress bars, and the step's own content with a footer button.
struct OnboardStep<Content: View>: View {
    @Environment(Store.self) private var store
    var n: Int
    var back: FirstStage
    var cta = "Next"
    var enabled = true
    var next: () -> Void
    @ViewBuilder var content: Content

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 14) {
                Button { store.step(back) } label: { Image(systemName: "chevron.left").font(.app(18, .semibold)).frame(width: 40, height: 40) }
                    .accessibilityLabel("Back")
                HStack(spacing: 6) {
                    ForEach(1...3, id: \.self) { k in Capsule().fill(k <= n ? Color.shoalBlue : Color(hex: 0xd9e2ee)).frame(height: 5) }
                }
                Color.clear.frame(width: 40, height: 40)
            }
            .padding(.horizontal, 14)
            ScrollView {
                VStack(alignment: .leading, spacing: 12) { content }
                    .padding(.horizontal, 24).padding(.top, 10).padding(.bottom, 20)
            }
            .scrollDismissesKeyboard(.interactively)
            Button(cta, action: next).buttonStyle(PrimaryButton(enabled: enabled)).disabled(!enabled)
                .padding(.horizontal, 24).padding(.bottom, 16)
        }
    }
}

struct Choice: View {
    var t: String
    var d: String? = nil
    var on: Bool
    var multi = false
    var action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(t).font(.app(15.5, .semibold)).foregroundStyle(Color.ink)
                    if let d { Text(d).font(.meta).foregroundStyle(Color.muted).multilineTextAlignment(.leading) }
                }
                Spacer()
                Image(systemName: on ? (multi ? "checkmark.square.fill" : "checkmark.circle.fill") : (multi ? "square" : "circle"))
                    .font(.app(22)).foregroundStyle(on ? Color.shoalBlue : Color(hex: 0xc3cad4))
            }
            .glassCard(radius: 18, padding: 14)
            .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(on ? Color.shoalBlue.opacity(0.6) : .clear, lineWidth: 1.5))
        }
        .buttonStyle(Pressable())
        .accessibilityAddTraits(on ? .isSelected : [])
    }
}

struct CareStage: Identifiable { let id: String; let t: String; let d: String; let s: String }
let CARE_STAGES = [
    CareStage(id: "start", t: "Just starting", d: "A new diagnosis, or help is new", s: "families just starting out"),
    CareStage(id: "daily", t: "Day to day", d: "Ongoing care, settling into a routine", s: "day-to-day care"),
    CareStage(id: "final", t: "In hospice or final months", d: "Comfort care, at home or in a facility", s: "hospice and the final months"),
]
let CONDITIONS = [("dementia", "Dementia or memory loss"), ("cancer", "Cancer"), ("aging", "Getting older and frail"), ("other", "Something else")]

struct AboutView: View {
    @Environment(Store.self) private var store
    var body: some View {
        @Bindable var store = store
        let ok = !store.lovedName.trimmingCharacters(in: .whitespaces).isEmpty
        OnboardStep(n: 1, back: .welcome, enabled: ok, next: { store.step(.people) }) {
            Eyebrow(text: "About them")
            Text("Who are you caring for?").font(.title(30)).foregroundStyle(Color.navy)
            Text("This picks the starter tasks. You can change any of them.").font(.body15).foregroundStyle(Color.muted)
            HStack {
                Text("Name").font(.app(14, .semibold)).foregroundStyle(Color.muted)
                TextField("Their name", text: $store.lovedName).font(.app(17)).multilineTextAlignment(.trailing)
                    .onChange(of: store.lovedName) { if store.lovedName.count > 20 { store.lovedName = String(store.lovedName.prefix(20)) } }
            }
            .glassCard(radius: 18, padding: 16)
            SectionH(text: "Where are things right now?")
            ForEach(CARE_STAGES) { g in
                Choice(t: g.t, d: g.d, on: store.careStage == g.id) { withAnimation(.snappy) { store.careStage = g.id } }
            }
            HStack(alignment: .firstTextBaseline) {
                SectionH(text: "What are they living with?")
                Text("Optional · pick any").font(.app(12)).foregroundStyle(Color.muted)
            }
            ForEach(CONDITIONS, id: \.0) { c in
                Choice(t: c.1, on: store.conditions.contains(c.0), multi: true) {
                    withAnimation(.snappy) { if store.conditions.contains(c.0) { store.conditions.remove(c.0) } else { store.conditions.insert(c.0) } }
                }
            }
        }
    }
}

struct InvitePeopleView: View {
    @Environment(Store.self) private var store
    @State private var adding: Tier?
    @State private var name = ""
    @FocusState private var focus: Bool

    private let groups: [(Tier, String, String, String)] = [
        (.main, "Main caregivers", "Get the app, a jar, and stones", "Add a caregiver"),
        (.trusted, "Trusted circle", "Friends and neighbors · light tasks", "Add a friend or neighbor"),
        (.kid, "Kids & teens", "Their own small tasks, never urgent", "Add a kid or teen"),
    ]

    var body: some View {
        OnboardStep(n: 2, back: .about, next: { store.step(.colors) }) {
            Eyebrow(text: "People")
            Text("Who's helping?").font(.title(30)).foregroundStyle(Color.navy)
            Text("We'll text each person a link. You can add more later.").font(.body15).foregroundStyle(Color.muted)
            ForEach(groups, id: \.0) { g in
                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(g.1).font(.app(15, .semibold)).foregroundStyle(Color.ink)
                        Spacer()
                        Text(g.2).font(.app(12)).foregroundStyle(Color.muted)
                    }
                    .padding(.top, 8)
                    VStack(spacing: 0) {
                        ForEach(store.people.filter { $0.tier == g.0 }) { p in
                            HStack(spacing: 12) {
                                Avatar(p: p, size: 36)
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(p.name).font(.app(15, .semibold)).foregroundStyle(Color.ink)
                                    if p.id == "you" { Text("That's you").font(.meta).foregroundStyle(Color.muted) }
                                }
                                Spacer()
                                if p.invited {
                                    Text("Invited").font(.app(12, .semibold)).foregroundStyle(Color.shoalBlue)
                                        .padding(.horizontal, 9).padding(.vertical, 4).background(Color.blueTint, in: .capsule)
                                }
                            }
                            .padding(.vertical, 8)
                            Divider()
                        }
                        if adding == g.0 {
                            HStack(spacing: 8) {
                                TextField("Name or phone number", text: $name).focused($focus).submitLabel(.send).onSubmit { invite(g.0) }
                                    .font(.body15)
                                Button("Invite") { invite(g.0) }.font(.app(14, .semibold)).disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                                Button { adding = nil; name = "" } label: { Image(systemName: "xmark").font(.app(13, .bold)).foregroundStyle(Color.muted) }
                                    .accessibilityLabel("Cancel")
                            }
                            .padding(.vertical, 10)
                        } else {
                            Button { adding = g.0; name = ""; focus = true } label: {
                                HStack(spacing: 10) {
                                    Image(systemName: "plus").font(.app(14, .bold)).foregroundStyle(Color.shoalBlue)
                                        .frame(width: 36, height: 36).background(Color.blueTint, in: .circle)
                                    Text(g.3).font(.app(15, .semibold)).foregroundStyle(Color.shoalBlue)
                                    Spacer()
                                }
                                .padding(.vertical, 8)
                            }
                            .buttonStyle(Pressable())
                        }
                    }
                    .glassCard(radius: 18, padding: 14)
                }
            }
        }
    }

    private func invite(_ tier: Tier) {
        let v = name.trimmingCharacters(in: .whitespaces)
        guard !v.isEmpty else { return }
        let digits = v.filter(\.isNumber)
        let shown = digits.count >= 10 ? fmtPhone(String(digits.suffix(10))) : v
        store.people.append(Person(id: "inv\(store.people.count)", name: shown, img: nil, tier: tier, cap: tier == .main ? 4 : 2, about: "Invited", invited: true))
        store.say("Sent \(shown) a link")
        name = ""
        adding = nil
    }
}

struct ColorsStepView: View {
    @Environment(Store.self) private var store
    var body: some View {
        OnboardStep(n: 3, back: .people, cta: "Confirm colors", next: {
            let p = PRESETS.first { $0.c == store.colors }
            store.finishOnboarding("Stone colors saved\(p.map { ": \($0.t)" } ?? "")")
        }) {
            Eyebrow(text: "Stones")
            Text("Pick your stone colors").font(.title(30)).foregroundStyle(Color.navy)
            StoneColorPicker()
            Text("Each stone glows to show where a task stands. You can change these anytime in Settings.").font(.app(12.5)).foregroundStyle(Color.muted)
        }
    }
}
