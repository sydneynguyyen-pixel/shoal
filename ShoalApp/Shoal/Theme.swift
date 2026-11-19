import SwiftUI

extension Color {
    init(hex: UInt32, _ a: Double = 1) {
        self.init(.sRGB, red: Double((hex >> 16) & 0xff) / 255, green: Double((hex >> 8) & 0xff) / 255, blue: Double(hex & 0xff) / 255, opacity: a)
    }
    static let navy = Color(hex: 0x13315d)
    static let ink = Color(hex: 0x22262e)
    static let muted = Color(hex: 0x5b6069)   // darker for contrast on the light background
    static let sectionInk = Color(hex: 0x4f5560)
    static let shoalBlue = Color(hex: 0x2070d9)
    static let blueTint = Color(hex: 0x2070d9, 0.1)
    static let blueLabel = Color(hex: 0x2f6fcb)
    static let amber = Color(hex: 0xc98a1b)
    static let alert = Color(hex: 0xc4442f)
    static let thanks = Color(hex: 0x7357c4)
    static let pearlInk = Color(hex: 0x6a5a8c)
}

// MARK: - Type

// Same fonts as the web: Figtree for text, Fraunces (SOFT 0, WONK 1) for titles.
extension Font {
    static func app(_ size: CGFloat, _ w: Font.Weight = .regular) -> Font {
        let name = switch w {
        case .medium: "Figtree-Medium"
        case .semibold: "Figtree-SemiBold"
        case .bold, .heavy, .black: "Figtree-Bold"
        default: "Figtree-Regular"
        }
        return .custom(name, fixedSize: size)
    }
    static func title(_ size: CGFloat = 32, weight: CGFloat = 400) -> Font { Font(UIFont.fraunces(size, weight: weight) as CTFont) }
    static let body15 = Font.app(15)
    static let meta = Font.app(15)
}

extension UIFont {
    static func fraunces(_ size: CGFloat, weight: CGFloat = 400) -> UIFont {
        // Axis tags: wght, opsz, SOFT, WONK
        let axes: [Int: CGFloat] = [0x77676874: weight, 0x6F70737A: min(144, max(9, size)), 0x534F4654: 0, 0x574F4E4B: 1]
        let d = UIFontDescriptor(fontAttributes: [.name: "Fraunces-Regular", UIFontDescriptor.AttributeName(rawValue: kCTFontVariationAttribute as String): axes])
        return UIFont(descriptor: d, size: size)
    }
}

struct Eyebrow: View {
    var text: String
    var color: Color = .muted
    var body: some View {
        Text(text.uppercased()).font(.app(11, .semibold)).tracking(0.88).foregroundStyle(color)
    }
}

struct SectionH: View {
    var text: String
    var trailing: String? = nil
    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(text).font(.app(14, .semibold)).foregroundStyle(Color.sectionInk)
            Spacer()
            if let trailing { Text(trailing).font(.meta).foregroundStyle(Color.muted) }
        }
        .padding(.horizontal, 4).padding(.top, 22).padding(.bottom, 2)
    }
}

// MARK: - Backgrounds and surfaces

struct AppBackground: View {
    var body: some View {
        LinearGradient(stops: [
            .init(color: Color(hex: 0xecf4ff), location: 0),
            .init(color: Color(hex: 0xfbf7f0), location: 0.19),
            .init(color: .white, location: 0.65),
            .init(color: Color(hex: 0xf0f7ff), location: 1),
        ], startPoint: .top, endPoint: .bottom)
        .ignoresSafeArea()
    }
}

struct GlassCard: ViewModifier {
    var radius: CGFloat = 22
    var padding: CGFloat = 16
    func body(content: Content) -> some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.white.opacity(0.62), in: .rect(cornerRadius: radius))
            .overlay(RoundedRectangle(cornerRadius: radius).strokeBorder(.white, lineWidth: 1))
            .shadow(color: Color(hex: 0x21262e, 0.05), radius: 12, y: 8)
    }
}

// Pebble's suggestions sit on pearl, so they never look like the family's own cards.
struct Pearl: ViewModifier {
    var radius: CGFloat = 20
    var padding: CGFloat = 14
    func body(content: Content) -> some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(LinearGradient(colors: [Color(hex: 0xfbf5f0), Color(hex: 0xf0e9fa), Color(hex: 0xe7f1f5)], startPoint: .topLeading, endPoint: .bottomTrailing), in: .rect(cornerRadius: radius))
            .overlay(RoundedRectangle(cornerRadius: radius).strokeBorder(
                AngularGradient(colors: [Color(hex: 0xc9b4ee), Color(hex: 0xf1c9ae), Color(hex: 0xb3d8e8), Color(hex: 0xd6bdee), Color(hex: 0xc9b4ee)], center: .center), lineWidth: 2))
            .shadow(color: Color(hex: 0x7864a0, 0.22), radius: 14, y: 8)
    }
}

extension View {
    func glassCard(radius: CGFloat = 22, padding: CGFloat = 16) -> some View { modifier(GlassCard(radius: radius, padding: padding)) }
    func pearl(radius: CGFloat = 20, padding: CGFloat = 14) -> some View { modifier(Pearl(radius: radius, padding: padding)) }
}

struct PearlChip: View {
    var label: String
    var action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image("pebble_base_front").resizable().scaledToFit().frame(width: 18, height: 18)
                Text(label).font(.app(14, .semibold)).foregroundStyle(Color.pearlInk)
            }
            .padding(.horizontal, 12).frame(height: 34)
            .background(LinearGradient(colors: [Color(hex: 0xfbf5f0), Color(hex: 0xf0e9fa), Color(hex: 0xe7f1f5)], startPoint: .leading, endPoint: .trailing), in: .capsule)
            .overlay(Capsule().strokeBorder(LinearGradient(colors: [Color(hex: 0xc9b4ee), Color(hex: 0xf1c9ae), Color(hex: 0xb3d8e8)], startPoint: .leading, endPoint: .trailing), lineWidth: 1.5))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Buttons

struct PrimaryButton: ButtonStyle {
    var enabled = true
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.app(15.5, .semibold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity).frame(height: 52)
            .background(enabled ? Color.shoalBlue : Color(hex: 0xaecaee), in: .capsule)
            .shadow(color: Color.shoalBlue.opacity(enabled ? 0.28 : 0), radius: 8, y: 6)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.snappy(duration: 0.15), value: configuration.isPressed)
    }
}

struct GhostButton: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.app(15.5, .semibold)).foregroundStyle(Color.ink)
            .frame(maxWidth: .infinity).frame(height: 52)
            .background(.white.opacity(0.85), in: .capsule)
            .overlay(Capsule().strokeBorder(.white))
            .shadow(color: Color(hex: 0x21262e, 0.06), radius: 10, y: 6)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
    }
}

struct Pressable: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.contentShape(.rect).opacity(configuration.isPressed ? 0.7 : 1)
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .animation(.snappy(duration: 0.15), value: configuration.isPressed)
    }
}

// MARK: - Stones

// The glowing stone. Size follows the task's size; repeating tasks are the darker stones.
// Colors follow the family's choice (Store.colors) unless a palette is passed in.
struct Stone: View {
    @Environment(Store.self) private var store: Store?
    var state: StoneState
    var w: Weight = .medium
    var dark = false
    var base: CGFloat = 30   // width at medium
    var palette: StoneColors? = nil
    var lit: Double = 1      // the kit's Glow: 1 on, 0.45 dim, 0 off

    private var k: CGFloat { w == .small ? 0.74 : w == .large ? 1.3 : 1 }
    private var colors: (hi: Color, mid: Color, lo: Color, glow: Color) {
        let st = lit == 0 ? StoneState.done : state
        if st == .done {
            return dark ? (Color(hex: 0xb3b7bd), Color(hex: 0x8e939a), Color(hex: 0x6a7078), .clear)
                        : (Color(hex: 0xececec), Color(hex: 0xcfcfcf), Color(hex: 0xa9abae), .clear)
        }
        let h = (palette ?? store?.colors ?? .shoal).hue(st)
        return dark ? (Color(hex: h.dark.0), Color(hex: h.dark.1), Color(hex: h.dark.2), Color(hex: h.glow, h.ga))
                    : (Color(hex: h.hi), Color(hex: h.mid), Color(hex: h.lo), Color(hex: h.glow, h.ga))
    }

    var body: some View {
        let wd = base * k, ht = base * k * 0.733
        let c = colors
        Ellipse()
            .fill(RadialGradient(stops: [.init(color: c.hi, location: 0), .init(color: c.mid, location: 0.42), .init(color: c.lo, location: 1)],
                                 center: UnitPoint(x: 0.38, y: 0.28), startRadius: 0, endRadius: wd * 0.75))
            .frame(width: wd, height: ht)
            .shadow(color: c.glow.opacity(lit), radius: wd * 0.22 * max(lit, 0.4))
            .shadow(color: state == .done || lit == 0 ? Color(hex: 0x21262e, 0.12) : .clear, radius: 3, y: 2)
            .saturation(lit == 0 ? 1 : 0.4 + 0.6 * lit)
            .opacity(lit == 0 ? 1 : 0.3 + 0.7 * lit)
            .overlay(alignment: .topTrailing) {
                // Only urgent stones carry a mark, so meaning never rides on color alone.
                if state == .urgent && lit > 0 && wd >= 16 {
                    let d = max(11, min(26, wd * 0.36))
                    Text("!").font(.app(d * 0.72, .heavy)).foregroundStyle(.white)
                        .frame(width: d, height: d).background(Color(hex: 0xa07624), in: .circle)
                        .overlay(Circle().strokeBorder(.white, lineWidth: 1.5))
                        .offset(x: d * 0.3, y: -d * 0.25)
                }
            }
            .accessibilityHidden(true)
    }
}

extension CareTask {
    func stone(base: CGFloat = 30, lit: Double = 1) -> Stone { Stone(state: state, w: w, dark: kind == .repeating, base: base, lit: lit) }
    var jarStone: JarStone { JarStone(id: id, state: state, w: w, dark: kind == .repeating) }
}

// MARK: - People

struct Avatar: View {
    var p: Person?
    var size: CGFloat = 36
    var body: some View {
        Group {
            if let img = p?.img {
                Image(img).resizable().scaledToFill()
            } else {
                ZStack {
                    Circle().fill(Color.blueTint)
                    Text(String(p?.name.prefix(1) ?? "?")).font(.app(size * 0.42, .semibold)).foregroundStyle(Color.shoalBlue)
                }
            }
        }
        .frame(width: size, height: size).clipShape(.circle)
        .overlay(Circle().strokeBorder(.white, lineWidth: size > 30 ? 2 : 1))
        .accessibilityHidden(true)
    }
}

// MARK: - Jars

// One stone in a jar: a task's, or a sample's.
struct JarStone: Identifiable { var id: String; var state: StoneState; var w: Weight; var dark = false }

// A family member's jar: faint tinted glass with a rounded floor, stones settled at the bottom.
struct Jar: View {
    @Environment(Store.self) private var store
    var who: String
    var width: CGFloat = 84
    var lit: Double = 1
    var blink: String? = nil

    var body: some View {
        // Done stones sit at the bottom, glowing ones on top, big under small.
        let all = store.mine(who).sorted { ($0.done ? 0 : 1, -$0.w.rawValue) < ($1.done ? 0 : 1, -$1.w.rawValue) }
        JarBody(stones: all.map(\.jarStone), width: width, lit: lit, blink: blink)
            .accessibilityElement().accessibilityLabel("\(store.name(who))'s jar, \(plural(all.filter { !$0.done }.count, "stone")) glowing")
    }
}

// Sample jars for the intro, welcome and color picker. States read bottom row first; "*" marks a dark stone.
struct SampleJar: View {
    var states: [String]
    var width: CGFloat = 70
    var palette: StoneColors? = nil
    private static let W: [Weight] = [.large, .medium, .small, .medium, .medium, .small, .small, .medium, .small]
    var body: some View {
        let st: [String: StoneState] = ["urgent": .urgent, "progress": .progress, "open": .open, "done": .done]
        let stones = states.enumerated().map { i, s in
            JarStone(id: "\(i)", state: st[s.replacingOccurrences(of: "*", with: "")] ?? .open, w: Self.W[i % Self.W.count], dark: s.hasSuffix("*"))
        }
        JarBody(stones: stones, width: width, palette: palette).accessibilityHidden(true)
    }
}

struct JarBody: View {
    var stones: [JarStone]
    var width: CGFloat
    var lit: Double = 1
    var blink: String? = nil
    var palette: StoneColors? = nil
    @State private var on = true

    var body: some View {
        let h = width * 1.45
        let base = width * 0.3
        let rows = pack(stones, inner: width - 14, base: base, maxRows: Int((h - 20) / (base * 0.62)))
        let shape = UnevenRoundedRectangle(topLeadingRadius: 6, bottomLeadingRadius: width * 0.3, bottomTrailingRadius: width * 0.3, topTrailingRadius: 6)
        ZStack(alignment: .bottom) {
            shape
                .fill(LinearGradient(stops: [.init(color: Color(hex: 0x418ef3, 0.09), location: 0), .init(color: Color(hex: 0x418ef3, 0.025), location: 0.3),
                                             .init(color: Color(hex: 0x418ef3, 0.025), location: 0.7), .init(color: Color(hex: 0x418ef3, 0.1), location: 1)],
                                     startPoint: .leading, endPoint: .trailing))
                .overlay { shape.fill(LinearGradient(stops: [.init(color: .clear, location: 0.9), .init(color: Color(hex: 0x13315d, 0.08), location: 0.93)], startPoint: .top, endPoint: .bottom)) }
                .overlay(shape.strokeBorder(LinearGradient(colors: [Color(hex: 0x13315d, 0.26), Color(hex: 0x13315d, 0.15)], startPoint: .top, endPoint: .bottom), lineWidth: 1.5))
                .padding(.horizontal, 3).padding(.top, 4).padding(.bottom, 3)
            VStack(spacing: -base * 0.18) {
                ForEach(Array(rows.enumerated().reversed()), id: \.offset) { i, row in
                    HStack(spacing: 0) {
                        ForEach(row) { t in
                            Stone(state: t.state, w: t.w, dark: t.dark, base: base, palette: palette, lit: lit)
                                .opacity(blink == t.id && !on ? 0.15 : 1)
                        }
                    }
                    .offset(x: i % 2 == 0 ? 0 : base * 0.15)
                }
            }
            .padding(.bottom, 9)
            Image("jar").resizable().mask { shape.padding(.horizontal, 3).padding(.top, 4).padding(.bottom, 3) }.allowsHitTesting(false)
        }
        .frame(width: width, height: h)
        .animation(.easeInOut(duration: 0.5), value: lit)
        .task(id: blink) {
            on = true
            guard blink != nil else { return }
            for _ in 0..<12 {
                try? await Task.sleep(for: .seconds(0.45))
                withAnimation(.easeInOut(duration: 0.3)) { on.toggle() }
            }
            on = true
        }
    }

    // Lay stones into rows that fit the jar, bottom row first. A full jar lets done stones drop off first.
    private func pack(_ ts: [JarStone], inner: CGFloat, base: CGFloat, maxRows: Int) -> [[JarStone]] {
        var list = ts
        func rowsFor(_ l: [JarStone]) -> [[JarStone]] {
            var rows: [[JarStone]] = [[]], wsum: CGFloat = 0
            // The bottom curves in, so the lowest rows hold a little less.
            func room(_ r: Int) -> CGFloat { inner * (r == 0 ? 0.8 : r == 1 ? 0.93 : 1) }
            for t in l {
                let k: CGFloat = t.w == .small ? 0.74 : t.w == .large ? 1.3 : 1
                if wsum + base * k > room(rows.count - 1), !rows[rows.count - 1].isEmpty { rows.append([]); wsum = 0 }
                rows[rows.count - 1].append(t); wsum += base * k
            }
            return rows
        }
        var r = rowsFor(list)
        while r.count > maxRows, let i = list.firstIndex(where: { $0.state == .done }) { list.remove(at: i); r = rowsFor(list) }
        return Array(r.prefix(maxRows))
    }
}

// MARK: - Logo

// Five stones of the Shoal mark, as in start.js: piece, x%, y%, w%, h%, rotation.
private let MARK: [(String, Double, Double, Double, Double, Double)] = [
    ("top", 50, 18, 29, 18, 0),
    ("right", 79.48, 40.42, 25, 16, 72),
    ("bottom-right", 69.1, 76.3, 30, 19, 144),
    ("bottom-left", 32.07, 74.68, 23, 15, -144),
    ("lit", 20.05, 40.27, 37.53, 27.53, -72),
]

struct ShoalMark: View {
    var s: CGFloat
    var assemble = false
    @State private var shown = false
    var body: some View {
        ZStack(alignment: .topLeading) {
            ForEach(Array(MARK.enumerated()), id: \.offset) { i, m in
                let lit = m.0 == "lit"
                let w = s * m.3 / 100 * (lit ? 25.65 / 35.65 : 1), h = s * m.4 / 100 * (lit ? 16.15 / 26.15 : 1)
                let on = !assemble || shown
                Ellipse().fill(lit ? Color(hex: 0x82DAFF) : Color(hex: 0x0F4C93))
                    .frame(width: w, height: h)
                    .shadow(color: lit && on ? Color(hex: 0x418EF3, 0.9) : .clear, radius: s * 0.05)
                    .shadow(color: lit && on ? Color(hex: 0x418EF3, 0.6) : .clear, radius: s * 0.12)
                    .rotationEffect(.degrees(m.5 + (on ? 0 : -60)))
                    .scaleEffect(on ? 1 : 0.3)
                    .opacity(on ? 1 : 0)
                    .position(x: s * (on ? m.1 : 50) / 100, y: s * (on ? m.2 : 50) / 100)
                    .animation(.spring(duration: 0.7, bounce: 0.25).delay(Double(i) * 0.12), value: shown)
            }
        }
        .frame(width: s, height: s)
        .onAppear { if assemble { shown = true } }
        .accessibilityHidden(true)
    }
}

// The mark with the wordmark next to it.
struct Lockup: View {
    var size: CGFloat = 26
    var body: some View {
        HStack(spacing: size * 0.3) {
            ShoalMark(s: size)
            Text("shoal").font(.title(size * 0.95)).tracking(-0.02 * size).foregroundStyle(Color(hex: 0x0F4C93))
        }
        .accessibilityElement().accessibilityLabel("Shoal")
    }
}

// MARK: - Toast

struct ToastView: View {
    var text: String
    var body: some View {
        Text(text).font(.app(14.5, .medium)).foregroundStyle(.white)
            .padding(.horizontal, 18).padding(.vertical, 12)
            .background(Color.navy.opacity(0.92), in: .capsule)
            .shadow(color: .black.opacity(0.15), radius: 12, y: 6)
            .padding(.horizontal, 24)
            .transition(.move(edge: .top).combined(with: .opacity))
    }
}

struct Chevron: View {
    var body: some View { Image(systemName: "chevron.right").font(.system(size: 13, weight: .semibold)).foregroundStyle(Color(hex: 0xa3a9b3)) }
}

// Lays children out left to right and wraps to a new line when they run out of room, like chips on the web.
struct FlowRow: Layout {
    var spacing: CGFloat = 8
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = arrange(proposal.width ?? .infinity, subviews)
        return CGSize(width: proposal.width ?? rows.map(\.width).max() ?? 0,
                      height: rows.reduce(0) { $0 + $1.height } + spacing * CGFloat(max(0, rows.count - 1)))
    }
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var y = bounds.minY
        for row in arrange(bounds.width, subviews) {
            var x = bounds.minX
            for i in row.items {
                let s = subviews[i].sizeThatFits(.unspecified)
                subviews[i].place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(s))
                x += s.width + spacing
            }
            y += row.height + spacing
        }
    }
    private struct Row { var items: [Int] = []; var width: CGFloat = 0; var height: CGFloat = 0 }
    private func arrange(_ maxW: CGFloat, _ subviews: Subviews) -> [Row] {
        var rows = [Row()]
        for (i, v) in subviews.enumerated() {
            let s = v.sizeThatFits(.unspecified)
            if !rows[rows.count - 1].items.isEmpty && rows[rows.count - 1].width + spacing + s.width > maxW { rows.append(Row()) }
            var r = rows[rows.count - 1]
            r.width += (r.items.isEmpty ? 0 : spacing) + s.width
            r.height = max(r.height, s.height)
            r.items.append(i)
            rows[rows.count - 1] = r
        }
        return rows
    }
}
