import SwiftUI
import MessageUI

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
        }
        setup = []
        tab = 0
        withAnimation(.smooth(duration: 0.45)) { onboarded = true }
        say(msg)
    }
    func skipToApp() {
        LOVED = "Dad"; lovedName = "Dad"
        loadDemo()
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
            Text("shoal").font(.title(52)).tracking(-0.02 * 52).foregroundStyle(Color(hex: 0x0F4C93))
                .opacity(word ? 1 : 0).offset(y: word ? 0 : 8)
            Text("Share caregiving with your family").font(.body15).foregroundStyle(Color.navy.opacity(0.7))
                .opacity(word ? 1 : 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background {
            ZStack {
                RadialGradient(colors: [.white, Color(hex: 0xf3f8ff), Color(hex: 0xe6f0ff)], center: .center, startRadius: 0, endRadius: 520)
                BrandRings(layout: .splash).opacity(word ? 0.55 : 0)
            }
            .ignoresSafeArea()
        }
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

// MARK: - Brand rings

// Soft, blurred rings in the brand blues with a cream glow, drifting slowly behind the splash and sign-in.
struct BrandRings: View {
    enum Layout { case splash, signin }
    var layout: Layout
    @State private var drift = false

    var body: some View {
        let big = layout == .splash
        ZStack(alignment: .topLeading) {
            cream(big ? 296 : 240).offset(x: big ? -60 : 70, y: big ? 40 : 120)
            // Web sizes: 292 box, r111, 38 wide; 252, r93, 34; 212, r75, 30. Sign-in uses smaller boxes.
            ring(292, 111, 38, to: big ? 292 : 230, 0x418EF3, 0.9).offset(x: big ? 170 : 210, y: big ? -40 : -30).modifier(Drift(on: drift, d: 7, x: 8, y: -10))
            ring(252, 93, 34, to: big ? 252 : 190, 0x0F4C93, 0.75).offset(x: big ? -90 : -70, y: big ? 470 : 120).modifier(Drift(on: drift, d: 8, x: -8, y: 8))
            ring(212, 75, 30, to: big ? 212 : 150, 0x82DAFF, 0.9).offset(x: big ? 230 : 290, y: big ? 600 : 150).modifier(Drift(on: drift, d: 6, x: 6, y: 10))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onAppear { drift = true }
        .accessibilityHidden(true)
    }

    private func ring(_ box0: CGFloat, _ r: CGFloat, _ w: CGFloat, to box: CGFloat, _ hex: UInt32, _ o: Double) -> some View {
        let k = box / box0
        return Circle().stroke(Color(hex: hex, o), lineWidth: w * k)
            .frame(width: r * 2 * k, height: r * 2 * k)
            .blur(radius: 8)
            .frame(width: box, height: box)
    }

    private func cream(_ box: CGFloat) -> some View {
        Circle()
            .fill(RadialGradient(stops: [.init(color: Color(hex: 0xF1EBCF, 0.9), location: 0), .init(color: Color(hex: 0xF1EBCF, 0), location: 0.68)],
                                 center: .center, startRadius: 0, endRadius: box / 2))
            .frame(width: box, height: box).blur(radius: 9)
    }

    private struct Drift: ViewModifier {
        var on: Bool; var d: Double; var x: CGFloat; var y: CGFloat
        func body(content: Content) -> some View {
            content.offset(x: on ? x : 0, y: on ? y : 0)
                .animation(.easeInOut(duration: d).repeatForever(autoreverses: true), value: on)
        }
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
        // The number pad has no return key, so give it a Done button to put the keyboard away.
        let bar = UIToolbar(frame: CGRect(x: 0, y: 0, width: 320, height: 44))
        bar.items = [UIBarButtonItem(systemItem: .flexibleSpace),
                     UIBarButtonItem(systemItem: .done, primaryAction: UIAction { [weak t] _ in t?.resignFirstResponder() })]
        bar.sizeToFit()
        t.inputAccessoryView = bar
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
                Lockup(size: 40).frame(maxWidth: .infinity).padding(.top, 40).padding(.bottom, 18)
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
        .background(alignment: .top) {
            BrandRings(layout: .signin)
                .frame(height: 262 + 60).opacity(0.5)
                .mask(LinearGradient(stops: [.init(color: .black, location: 0.55), .init(color: .clear, location: 1)], startPoint: .top, endPoint: .bottom))
                .ignoresSafeArea()
                .allowsHitTesting(false)
        }
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
                if i < n - 1 { Button("Skip") { store.step(.welcome) }.font(.app(14, .medium)).foregroundStyle(Color.muted) }
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
                            Capsule().fill(k == i ? Color.shoalBlue : Color(hex: 0xc8d3e0)).frame(width: k == i ? 22 : 7, height: 7)
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
            visual().frame(maxWidth: .infinity).frame(height: 380)
            Eyebrow(text: eyebrow, color: .blueLabel)
            Text(title).font(.title(30)).foregroundStyle(Color.navy).fixedSize(horizontal: false, vertical: true)
            Text(sub).font(.body15).foregroundStyle(Color.muted).fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 24)
        .tag(k)
    }

    // The family around the mark, each avatar floating on its own beat.
    private var circle: some View {
        ZStack {
            ShoalMark(s: 72)
                .shadow(color: Color(hex: 0x0F4C93, 0.18), radius: 8, y: 6)
                .phaseAnimator([false, true]) { v, up in v.offset(y: up ? -8 : 0).rotationEffect(.degrees(up ? 6 : 0)) }
                    animation: { _ in .easeInOut(duration: 2.5) }
            orb("avatar-you", "You", 0).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading).padding(.top, 30)
            orb("avatar-nora", "Nora", 1).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing).padding(.top, 10)
            orb("avatar-bill", "Bill", 2).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing).padding(.trailing, 10)
            orb("avatar-sam", "Sam", 3).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading).padding(.leading, 16).padding(.bottom, 10)
        }
        .frame(width: 280, height: 280)
    }

    private func orb(_ img: String, _ name: String, _ k: Int) -> some View {
        VStack(spacing: 6) {
            Image(img).resizable().scaledToFill().frame(width: 58, height: 58).clipShape(.circle)
                .overlay(Circle().strokeBorder(.white, lineWidth: 3))
                .shadow(color: Color(hex: 0x21262e, 0.1), radius: 10, y: 6)
            Text(name).font(.app(12.5, .semibold)).foregroundStyle(Color.ink)
                .padding(.horizontal, 9).padding(.vertical, 2)
                .background(.white.opacity(0.9), in: .rect(cornerRadius: 10))
                .shadow(color: Color(hex: 0x21262e, 0.06), radius: 4, y: 2)
        }
        .modifier(Floaty(phase: k))
    }

    // Four stones scattered down the slide, each with a small tag under it.
    private var stones: some View {
        GeometryReader { g in
            let rows: [(StoneState, String, CGFloat, CGFloat, Bool)] = [
                (.urgent, "Refill prescription · urgent", 12, 26, false), (.progress, "Drive to PT · Bill is doing it", 4, 92, true),
                (.open, "Weekly groceries · open", 30, 196, false), (.done, "Call hospice · done", 34, 262, true),
            ]
            ZStack(alignment: .topLeading) {
                ForEach(Array(rows.enumerated()), id: \.offset) { k, r in
                    VStack(spacing: 14) {
                        Stone(state: r.0, w: .large, base: 74)
                        HStack(spacing: 6) {
                            dot(r.0)
                            Text(r.1).font(.app(11.5, .semibold)).foregroundStyle(Color.ink).fixedSize()
                        }
                        .padding(.horizontal, 10).padding(.vertical, 5)
                        .background(.white.opacity(0.9), in: .rect(cornerRadius: 12))
                        .shadow(color: Color(hex: 0x21262e, 0.06), radius: 4, y: 2)
                    }
                    .modifier(Floaty(phase: k))
                    .frame(width: g.size.width - r.2, alignment: r.4 ? .trailing : .leading)
                    .offset(x: r.4 ? 0 : r.2, y: r.3)
                }
            }
        }
    }

    private func dot(_ st: StoneState) -> some View {
        let c: Color = st == .done ? Color(hex: 0xd2d2d2) : st == .open ? .white : Color(hex: store.colors.hue(st).mid)
        return Circle().fill(c).frame(width: 7, height: 7)
            .overlay(Circle().strokeBorder(st == .open ? Color(hex: 0xc9ced6) : .clear, lineWidth: 1))
    }

    private var jars: some View {
        VStack(spacing: -4) {
            HStack(alignment: .bottom, spacing: 8) {
                ForEach(Array([("You", ["done", "done*", "progress", "open*", "urgent"]),
                               ("Nora", ["done", "done", "done*", "progress*", "progress", "open"]),
                               ("Bill", ["done*", "progress", "open"])].enumerated()), id: \.offset) { _, j in
                    VStack(spacing: 6) {
                        SampleJar(states: j.1, width: 90)
                        Text(j.0).font(.app(13, .semibold)).foregroundStyle(Color.ink)
                    }
                }
            }
            Ellipse().fill(RadialGradient(colors: [Color(hex: 0x13315d, 0.14), .clear], center: .center, startRadius: 0, endRadius: 165))
                .frame(width: 330, height: 14)
        }
    }

    private var hold: some View {
        VStack(spacing: 30) {
            Stone(state: .progress, w: .large, base: 98)
                .phaseAnimator([1, 1.06]) { v, s in v.scaleEffect(s) } animation: { _ in .easeInOut(duration: 1.6) }
            Text("\(store.colors.hue(.progress).name.prefix(1).uppercased() + store.colors.hue(.progress).name.dropFirst()) · someone is doing it").font(.app(12.5, .semibold)).foregroundStyle(Color.blueLabel)
                .padding(.horizontal, 12).padding(.vertical, 6).background(Color.blueTint, in: .rect(cornerRadius: 14))
        }
    }

    private var privacy: some View {
        let rows = [("Only people you invite can see your plan", "Not other users, and not advertisers."),
                    ("Calendars only show when you're busy", "Shoal never sees what your events are."),
                    ("Sign-in uses a code sent to your phone", "No password to guess or steal."),
                    ("You can delete your data anytime", "Your account and plan are removed for good.")]
        return VStack(spacing: 18) {
            Image(systemName: "lock.fill").font(.system(size: 26)).foregroundStyle(Color.shoalBlue)
                .frame(width: 76, height: 76)
                .background(LinearGradient(colors: [Color(hex: 0xd5eaff), Color(hex: 0xa9d2ff)], startPoint: .topLeading, endPoint: .bottomTrailing), in: .circle)
                .background(Circle().fill(Color(hex: 0xc1dfff, 0.35)).padding(-10))
                .background(Circle().fill(Color(hex: 0xc1dfff, 0.18)).padding(-22))
                .modifier(Floaty(phase: 0, d: 2.5))
                .padding(.top, 22)
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(rows.enumerated()), id: \.offset) { k, r in
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "checkmark").font(.app(11, .bold)).foregroundStyle(.white)
                            .frame(width: 22, height: 22).background(Color.shoalBlue, in: .circle)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(r.0).font(.app(14, .semibold)).foregroundStyle(Color.ink)
                            Text(r.1).font(.app(12.5)).foregroundStyle(Color.muted)
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(.vertical, 12)
                    .overlay(alignment: .top) { if k > 0 { Rectangle().fill(Color(hex: 0xe6e9ee)).frame(height: 1).padding(.leading, 34) } }
                }
            }
            .padding(.horizontal, 16).padding(.vertical, 4)
            .glassCard(padding: 0)
        }
    }
}

// Gentle up-and-down float, offset per item so they don't move in step.
struct Floaty: ViewModifier {
    var phase: Int
    var d: Double = 3
    @State private var up = false
    func body(content: Content) -> some View {
        content.offset(y: up ? -6 : 0)
            .task {
                try? await Task.sleep(for: .seconds(Double(phase) * 0.75))
                withAnimation(.easeInOut(duration: d).repeatForever(autoreverses: true)) { up = true }
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
            Button("Start") { store.loadFresh(); store.step(.about) }.buttonStyle(PrimaryButton()).padding(.horizontal, 24).padding(.bottom, 16)
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

// Back, three short progress bars, and the step's own content with a footer button and Back under it.
struct OnboardStep<Content: View>: View {
    @Environment(Store.self) private var store
    var n: Int
    var back: FirstStage
    var cta = "Next"
    var enabled = true
    var skip: (() -> Void)? = nil
    var next: () -> Void
    @ViewBuilder var content: Content

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Button { store.step(back) } label: {
                    Image(systemName: "arrow.left").font(.system(size: 18, weight: .medium)).foregroundStyle(Color.ink).frame(width: 40, height: 40)
                }
                .accessibilityLabel("Back")
                HStack(spacing: 6) {
                    ForEach(1...3, id: \.self) { k in
                        RoundedRectangle(cornerRadius: 2).fill(k <= n ? Color.shoalBlue : Color.shoalBlue.opacity(0.18)).frame(width: 26, height: 4)
                    }
                }
                .accessibilityElement().accessibilityLabel("Step \(n) of 3")
                Spacer()
                if let skip {
                    Button("Skip", action: skip).font(.app(14, .medium)).foregroundStyle(Color.muted).frame(height: 40).padding(.horizontal, 6)
                }
            }
            .padding(.horizontal, 14)
            ScrollView {
                VStack(alignment: .leading, spacing: 12) { content }
                    .padding(.horizontal, 24).padding(.top, 10).padding(.bottom, 20)
            }
            .scrollDismissesKeyboard(.interactively)
            VStack(spacing: 0) {
                Button(cta, action: next).buttonStyle(PrimaryButton(enabled: enabled)).disabled(!enabled)
                Button("Back") { store.step(back) }.font(.app(14, .medium)).foregroundStyle(Color.muted).frame(height: 44)
            }
            .padding(.horizontal, 24).padding(.bottom, 4)
        }
    }
}

struct StepEyebrow: View {
    var text: String; var n: Int
    var body: some View { Eyebrow(text: "\(text) · Step \(n) of 3", color: .blueLabel) }
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
    @State private var own = ""
    var body: some View {
        @Bindable var store = store
        let ok = !store.lovedName.trimmingCharacters(in: .whitespaces).isEmpty
        // Anything written in sits with the others as a picked option; tap it to remove it.
        let written = store.conditions.filter { c in !CONDITIONS.contains { $0.0 == c } }.sorted()
        OnboardStep(n: 1, back: .welcome, enabled: ok, next: { store.step(.people) }) {
            StepEyebrow(text: "About them", n: 1)
            Text("Who are you caring for?").font(.title(30)).foregroundStyle(Color.navy)
            Text("This picks the starter tasks. You can change any of them.").font(.body15).foregroundStyle(Color.muted)
            VStack(alignment: .leading, spacing: 2) {
                Text("Name").font(.app(13)).foregroundStyle(Color.muted)
                TextField("Their name", text: $store.lovedName).font(.app(16, .semibold)).foregroundStyle(Color.ink)
                    .onChange(of: store.lovedName) { if store.lovedName.count > 20 { store.lovedName = String(store.lovedName.prefix(20)) } }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 2)
            .glassCard(radius: 18, padding: 10)
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
            ForEach(written, id: \.self) { w in
                Choice(t: w, on: true, multi: true) { _ = withAnimation(.snappy) { store.conditions.remove(w) } }
                    .accessibilityHint("Removes it")
            }
            HStack(spacing: 10) {
                Image(systemName: "plus").font(.system(size: 14, weight: .semibold)).foregroundStyle(Color.muted)
                TextField("Write your own", text: $own).font(.body15).submitLabel(.done).onSubmit(addOwn)
                Button("Add", action: addOwn).font(.app(14, .semibold)).foregroundStyle(Color.shoalBlue)
                    .disabled(own.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(.horizontal, 16).frame(height: 52)
            .background(.white.opacity(0.5), in: .rect(cornerRadius: 18))
            .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(Color(hex: 0xb9c3d0), style: StrokeStyle(lineWidth: 1.2, dash: [5, 4])))
        }
    }

    private func addOwn() {
        let v = own.trimmingCharacters(in: .whitespaces)
        guard !v.isEmpty else { return }
        _ = withAnimation(.snappy) { store.conditions.insert(v) }
        own = ""
    }
}

struct InvitePeopleView: View {
    @Environment(Store.self) private var store
    @State private var inviting: Tier?
    @State private var pending: Person?

    private let groups: [(Tier, String, String, String)] = [
        (.main, "Main caregivers", "Get the app, a jar, and stones", "Add a caregiver"),
        (.trusted, "Trusted circle", "Friends and neighbors · light tasks", "Add a friend or neighbor"),
        (.kid, "Kids & teens", "Their own small tasks, never urgent", "Add a kid or teen"),
    ]

    var body: some View {
        OnboardStep(n: 2, back: .about, next: { store.step(.colors) }) {
            StepEyebrow(text: "People", n: 2)
            Text("Who's helping?").font(.title(30)).foregroundStyle(Color.navy)
            Text("Invite the people who'll share the work. Send the link by text, email, or any app.").font(.body15).foregroundStyle(Color.muted)
            ForEach(groups, id: \.0) { g in
                VStack(alignment: .leading, spacing: 8) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(g.1).font(.app(16, .semibold)).foregroundStyle(Color.ink)
                        Text(g.2).font(.app(13)).foregroundStyle(Color.muted)
                    }
                    .padding(.top, 8)
                    VStack(spacing: 0) {
                        ForEach(store.people.filter { $0.tier == g.0 }) { p in
                            row(p)
                            Divider()
                        }
                        Button { inviting = g.0 } label: {
                            HStack(spacing: 12) {
                                Text("+").font(.app(18, .medium)).foregroundStyle(Color.shoalBlue)
                                    .frame(width: 36, height: 36)
                                    .overlay(Circle().strokeBorder(Color.shoalBlue.opacity(0.5), style: StrokeStyle(lineWidth: 1.2, dash: [3, 3])))
                                Text(g.3).font(.app(14.5, .semibold)).foregroundStyle(Color.shoalBlue)
                                Spacer()
                            }
                            .padding(.vertical, 8)
                        }
                        .buttonStyle(Pressable())
                    }
                    .glassCard(radius: 18, padding: 14)
                }
            }
        }
        .sheet(item: $inviting) { t in InviteSheet(tier: t) }
        .sheet(item: $pending) { p in PendingInviteSheet(p: p) }
    }

    @ViewBuilder private func row(_ p: Person) -> some View {
        let waiting = p.id != "you" && p.invited
        let line = HStack(spacing: 12) {
            Avatar(p: p, size: 36).opacity(waiting ? 0.6 : 1)
            VStack(alignment: .leading, spacing: 1) {
                Text(p.name).font(.app(15.5, .semibold)).foregroundStyle(Color.ink)
                Text(p.id == "you" ? "That's you" : waiting ? "\(viaShort(p)) · waiting to join" : p.about)
                    .font(.meta).foregroundStyle(Color.muted)
            }
            Spacer()
            if waiting {
                Text("Pending").font(.app(12, .semibold)).foregroundStyle(Color.ink)
                    .padding(.horizontal, 9).padding(.vertical, 4)
                    .background(.white.opacity(0.85), in: .capsule)
                    .overlay(Capsule().strokeBorder(Color(hex: 0xdde1e6)))
            }
        }
        .padding(.vertical, 8)
        if waiting {
            Button { pending = p } label: { line.contentShape(.rect) }.buttonStyle(Pressable())
        } else {
            line
        }
    }
}

// How an invite went out, from what the share sheet reports. Sam's demo invite is "text".
func viaShort(_ p: Person) -> String {
    switch p.via {
    case "text", "Messages": "Text sent"
    case "email", "Mail": "Email sent"
    case "copy": "Link copied"
    case "": "Invite sent"
    default: "Sent by \(p.via)"
    }
}
func viaHow(_ p: Person) -> String {
    switch p.via {
    case "text", "Messages": p.contact.isEmpty ? "by text" : "by text to \(p.contact)"
    case "email", "Mail": "by email"
    case "copy": "with a link"
    case "": ""
    default: "by \(p.via)"
    }
}
func inviteMessage(_ name: String, _ code: String) -> String {
    "Hi \(name), join \(LOVED)'s plan on Shoal so we can share the care: https://shoal.app/j/\(code)"
}

// The iOS share sheet. `done` gets the app that was picked ("Messages", "Mail", "copy", or "" for any other),
// or nil if it was closed without sharing.
struct ShareSheet: UIViewControllerRepresentable {
    var text: String
    var done: (String?) -> Void
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let vc = UIActivityViewController(activityItems: [text], applicationActivities: nil)
        vc.completionWithItemsHandler = { type, ok, _, _ in
            guard ok else { return done(nil) }
            switch type {
            case .message?: done("Messages")
            case .mail?: done("Mail")
            case .copyToPasteboard?: done("copy")
            default: done("")
            }
        }
        return vc
    }
    func updateUIViewController(_ vc: UIActivityViewController, context: Context) {}
}

// Messages with the invite filled in: their number (if we have it) and the ready-made text.
// It goes from your phone as you, and you can change it before sending. `done` gets "Messages" when sent, nil when canceled.
struct MessageCompose: UIViewControllerRepresentable {
    var to: [String]
    var text: String
    var done: (String?) -> Void
    func makeCoordinator() -> Coordinator { Coordinator(done: done) }
    func makeUIViewController(context: Context) -> MFMessageComposeViewController {
        let vc = MFMessageComposeViewController()
        vc.recipients = to
        vc.body = text
        vc.messageComposeDelegate = context.coordinator
        return vc
    }
    func updateUIViewController(_ vc: MFMessageComposeViewController, context: Context) {}
    final class Coordinator: NSObject, MFMessageComposeViewControllerDelegate {
        let done: (String?) -> Void
        init(done: @escaping (String?) -> Void) { self.done = done }
        func messageComposeViewController(_ c: MFMessageComposeViewController, didFinishWith result: MessageComposeResult) {
            done(result == .sent ? "Messages" : nil)
        }
    }
}

extension View {
    // While `text` is set: Messages, addressed to `to`, or the share sheet where Messages isn't available
    // (the Simulator, an iPad without it). Then clears it.
    func shareSheet(_ text: Binding<String?>, to: [String] = [], done: @escaping (String?) -> Void) -> some View {
        sheet(isPresented: Binding(get: { text.wrappedValue != nil }, set: { if !$0 { text.wrappedValue = nil } })) {
            let finish: (String?) -> Void = { via in
                text.wrappedValue = nil
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { done(via) }
            }
            if MFMessageComposeViewController.canSendText() {
                MessageCompose(to: to, text: text.wrappedValue ?? "", done: finish)
                    .presentationDetents([.large])
                    .ignoresSafeArea()
            } else {
                ShareSheet(text: text.wrappedValue ?? "", done: finish)
                    .presentationDetents([.medium, .large])
                    .ignoresSafeArea()
            }
        }
    }
}

func inviteCode(_ id: String) -> String {
    let chars = Array("ABCDEFGHJKLMNPQRSTUVWXYZ2345679")
    var h: UInt32 = 5381
    for b in id.utf8 { h = (h &* 33) &+ UInt32(b) }
    return String((0..<4).map { k in chars[Int((h >> (k * 5)) % UInt32(chars.count))] })
}

extension Tier { var roleLine: String {
    ["main": "Gets the app, a jar, and the whole plan. Can take and hand off tasks.",
     "trusted": "Gets a text when a light task opens up. No medical details.",
     "kid": "Their own small jobs in plain words. Never urgent."][rawValue]!
} }

// One sheet for every invite: who they are, how they know the person you care for, and what they can do.
// Send invite opens Messages with the text filled in (the share sheet where there is no Messages). Until they accept, they show as pending.
struct InviteSheet: View {
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State var tier: Tier
    @State private var name = ""
    @State private var rel = ""
    @State private var phone = ""
    @State private var phoneFocus = false
    @State private var sharing: String?
    @State private var id = "inv\(Int(Date.now.timeIntervalSince1970))"
    private let rels = ["Son or daughter", "Sibling", "Spouse or partner", "Grandchild", "Friend", "Neighbor", "Other"]

    init(tier: Tier) { _tier = State(initialValue: tier) }

    private var ready: Bool { !name.trimmingCharacters(in: .whitespaces).isEmpty }

    var body: some View {
        let code = inviteCode(id)
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text("Invite someone").font(.title(26)).foregroundStyle(Color.navy)
                Text("Send them a link to join \(LOVED)'s plan.").font(.body15).foregroundStyle(Color.muted)
                field("Name") { TextField("First name", text: $name).textContentType(.givenName) }
                label("How do they know \(LOVED)?", "Optional")
                FlowRow(spacing: 8) {
                    ForEach(rels, id: \.self) { r in chip(r, rel == r) { rel = rel == r ? "" : r } }
                }
                label("What can they do?")
                seg([("main", "Main caregiver"), ("trusted", "Trusted circle"), ("kid", "Kids & teens")], tier.rawValue) { tier = Tier(rawValue: $0)! }
                Text(tier.roleLine).font(.meta).foregroundStyle(Color.muted)
                field("Phone", "Optional") { PhoneField(digits: $phone, focused: $phoneFocus).frame(height: 24) }
                Button("Send invite", action: send)
                    .buttonStyle(PrimaryButton(enabled: ready)).disabled(!ready).padding(.top, 6)
                Text("They show as pending until they accept.").font(.meta).foregroundStyle(Color.muted).frame(maxWidth: .infinity)
            }
            .padding(24)
        }
        .scrollDismissesKeyboard(.interactively)
        .shareSheet($sharing, to: phone.isEmpty ? [] : [phone], done: added)
        .presentationDetents([.large])
        .presentationBackground(Color(hex: 0xf4f8fd))
    }

    private func send() {
        guard ready else { return }
        phoneFocus = false
        sharing = inviteMessage(name.trimmingCharacters(in: .whitespaces), inviteCode(id))
    }

    // After the share sheet closes. Closed without sending: stay on the form.
    private func added(_ via: String?) {
        guard let via else { return }
        let n = name.trimmingCharacters(in: .whitespaces)
        store.people.append(Person(id: id, name: n, img: nil, tier: tier, cap: tier == .main ? 5 : 2, about: rel,
                                   contact: phone.isEmpty ? "" : fmtPhone(phone), invited: true, via: via))
        dismiss()
        store.say(via == "copy" ? "Link copied. \(n) shows as pending." : "Invite sent to \(n)")
    }

    private func field<F: View>(_ t: String, _ hint: String? = nil, @ViewBuilder _ f: () -> F) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Eyebrow(text: t)
                if let hint { Text(hint).font(.app(12)).foregroundStyle(Color.muted) }
            }
            f().font(.app(16)).foregroundStyle(Color.ink)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(radius: 18, padding: 14)
    }

    private func label(_ t: String, _ hint: String? = nil) -> some View {
        (Text(t).font(.app(14, .semibold)).foregroundStyle(Color.sectionInk)
         + Text(hint.map { "  \($0)" } ?? "").font(.app(12)).foregroundStyle(Color.muted))
            .padding(.top, 6)
    }

    private func chip(_ t: String, _ on: Bool, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(t).font(.app(14, .semibold)).foregroundStyle(on ? .white : Color.ink)
                .padding(.horizontal, 14).frame(height: 36)
                .background(on ? Color.navy : .white.opacity(0.85), in: .capsule)
                .overlay(Capsule().strokeBorder(on ? .clear : Color(hex: 0xdde1e6)))
        }
        .buttonStyle(Pressable())
        .accessibilityAddTraits(on ? .isSelected : [])
    }

    private func seg(_ opts: [(String, String)], _ cur: String, _ pick: @escaping (String) -> Void) -> some View {
        HStack(spacing: 4) {
            ForEach(opts, id: \.0) { o in
                Button { withAnimation(.snappy(duration: 0.2)) { pick(o.0) } } label: {
                    Text(o.1).font(.app(13.5, .semibold)).foregroundStyle(cur == o.0 ? Color.navy : Color.muted)
                        .lineLimit(1).minimumScaleFactor(0.85)
                        .frame(maxWidth: .infinity).frame(height: 36)
                        .background(cur == o.0 ? .white : .clear, in: .capsule)
                        .shadow(color: cur == o.0 ? Color(hex: 0x21262e, 0.08) : .clear, radius: 4, y: 2)
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(cur == o.0 ? .isSelected : [])
            }
        }
        .padding(4)
        .background(Color(hex: 0x2070d9, 0.08), in: .capsule)
    }
}

// Tap a pending invite to resend it, copy the link, or cancel it.
struct PendingInviteSheet: View {
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss
    var p: Person
    @State private var sharing: String?

    var body: some View {
        let role = ["main": "main caregiver", "trusted": "trusted circle", "kid": "kids & teens"][p.tier.rawValue]!
        let how = viaHow(p)
        let code = inviteCode(p.id)
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                Avatar(p: p, size: 40).opacity(0.6)
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(p.name) hasn't joined yet").font(.app(17, .semibold)).foregroundStyle(Color.ink)
                    Text("Invited as \(role)\(how.isEmpty ? "" : " \(how)")\(p.about.isEmpty ? "" : " · \(p.about)")").font(.meta).foregroundStyle(Color.muted)
                }
            }
            Text("You can still give \(p.name) tasks. They'll say yes or no to each one when they join.").font(.app(14)).foregroundStyle(Color.muted)
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Invite code").font(.meta).foregroundStyle(Color.muted)
                    Text(code).font(.title(22)).tracking(2).foregroundStyle(Color.navy)
                    Text("shoal.app/j/\(code)").font(.meta).foregroundStyle(Color.muted)
                }
                Spacer()
            }
            .glassCard(radius: 18, padding: 14)
            Button("Resend invite") { sharing = inviteMessage(p.name, code) }
                .buttonStyle(GhostButton())
            Button("Cancel invite", role: .destructive) {
                dismiss()
                for i in store.tasks.indices where store.tasks[i].who == p.id { store.tasks[i].who = nil }
                store.people.removeAll { $0.id == p.id }
                store.say("Invite canceled. \(p.name)'s tasks are open again.")
            }
            .font(.app(15, .semibold)).frame(maxWidth: .infinity)
        }
        .padding(24)
        .shareSheet($sharing, to: p.contact.isEmpty ? [] : [p.contact.filter(\.isNumber)]) { via in
            guard let via else { return }
            if let i = store.people.firstIndex(where: { $0.id == p.id }) { store.people[i].via = via }
            dismiss()
            store.say(via == "copy" ? "Invite link copied" : "Sent \(p.name) the invite again")
        }
        .presentationDetents([.height(400)])
        .presentationBackground(Color(hex: 0xf4f8fd))
    }
}

struct ColorsStepView: View {
    @Environment(Store.self) private var store
    var body: some View {
        let done = {
            let p = PRESETS.first { $0.c == store.colors }
            store.finishOnboarding("Stone colors saved\(p.map { ": \($0.t)" } ?? "")")
        }
        OnboardStep(n: 3, back: .people, cta: "Confirm colors", skip: done, next: done) {
            StepEyebrow(text: "Stones", n: 3)
            Text("Pick your stone colors").font(.title(30)).foregroundStyle(Color.navy)
            StoneColorPicker()
            Text("Each stone glows to show where a task stands. You can change these anytime in Settings.").font(.app(12.5)).foregroundStyle(Color.muted)
        }
    }
}
