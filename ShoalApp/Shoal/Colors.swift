import SwiftUI

// Stone colors each family picks for themselves. Done always means the light is off;
// urgent, in progress and unassigned can each be any color, as long as no two match.

struct Hue {
    let name: String
    let hi, mid, lo, glow: UInt32
    let ga: Double
    let dark: (UInt32, UInt32, UInt32)   // the ongoing-task colorway: deeper rim, same core
}

let HUE_KEYS = ["yellow", "orange", "red", "pink", "purple", "ice", "green", "white"]
let HUES: [String: Hue] = [
    "yellow": Hue(name: "yellow", hi: 0xfff5d6, mid: 0xf6d27c, lo: 0xd9a23a, glow: 0xf6c45c, ga: 0.6, dark: (0xffe9a8, 0xd9a23a, 0x7a5a1c)),
    "orange": Hue(name: "orange", hi: 0xffe9d6, mid: 0xf9ad6b, lo: 0xe07a2c, glow: 0xf79646, ga: 0.55, dark: (0xffd0a6, 0xe07a2c, 0x7d3f12)),
    "red": Hue(name: "red", hi: 0xffe1dc, mid: 0xf28a7b, lo: 0xcf4a37, glow: 0xec6454, ga: 0.5, dark: (0xffc2b8, 0xcf4a37, 0x74251b)),
    "pink": Hue(name: "pink", hi: 0xffe6f1, mid: 0xf4a6c8, lo: 0xd9669a, glow: 0xf08cbe, ga: 0.5, dark: (0xffd0e4, 0xd9669a, 0x7a2f52)),
    "purple": Hue(name: "purple", hi: 0xefe8ff, mid: 0xbba5f2, lo: 0x8a6ad8, glow: 0xaa8cf0, ga: 0.5, dark: (0xddd0ff, 0x8a6ad8, 0x46317e)),
    "ice": Hue(name: "ice blue", hi: 0xffffff, mid: 0xd3e9fc, lo: 0x98c4ec, glow: 0x8cc4f6, ga: 0.55, dark: (0xe6f2ff, 0x6fa3d6, 0x33597f)),
    "green": Hue(name: "green", hi: 0xe9fbe6, mid: 0xa6dd9a, lo: 0x5fae55, glow: 0x78d26e, ga: 0.5, dark: (0xd6f5cf, 0x5fae55, 0x2f5e2a)),
    "white": Hue(name: "white", hi: 0xffffff, mid: 0xeef1f5, lo: 0xcfd5dd, glow: 0xffffff, ga: 0.95, dark: (0xffffff, 0xa9bdd6, 0x41546e)),
]

let COLOR_STATES: [StoneState] = [.urgent, .progress, .open]

struct StoneColors: Equatable {
    var urgent = "yellow", progress = "ice", open = "white"
    static let shoal = StoneColors()

    subscript(_ s: StoneState) -> String {
        get { s == .urgent ? urgent : s == .progress ? progress : open }
        set { if s == .urgent { urgent = newValue } else if s == .progress { progress = newValue } else { open = newValue } }
    }
    func hue(_ s: StoneState) -> Hue { HUES[self[s]] ?? HUES["white"]! }
    func name(_ s: StoneState) -> String { s == .done ? "light off" : hue(s).name }
    var summary: String { COLOR_STATES.map { hue($0).name.capitalized }.joined(separator: " · ") }

    // Two states can't share a color, so the one already using it takes the old color instead.
    mutating func pick(_ key: String, for s: StoneState) {
        if let other = COLOR_STATES.first(where: { $0 != s && self[$0] == key }) { self[other] = self[s] }
        self[s] = key
    }

    // Pairs that can look alike. "all" means even with typical color vision.
    var lookAlike: [(String, String, String)] {
        let c = COLOR_STATES.map { self[$0] }
        return LOOK_ALIKE.filter { c.contains($0.0) && c.contains($0.1) }
    }
}

let LOOK_ALIKE = [("ice", "white", "all"), ("yellow", "orange", "red-green"), ("red", "green", "red-green"),
                  ("orange", "green", "red-green"), ("orange", "pink", "blue-yellow"), ("ice", "green", "blue-yellow")]

struct Preset: Identifiable { let id: String; let t: String; let d: String; var rec = false; let c: StoneColors }
// Distances were checked by simulating each type of color blindness on these exact colors.
let PRESETS = [
    Preset(id: "shoal", t: "Shoal", d: "The original colors", c: StoneColors()),
    Preset(id: "clear", t: "Easy to tell apart", d: "Works for any color vision", rec: true, c: StoneColors(urgent: "yellow", progress: "purple", open: "white")),
    Preset(id: "rg", t: "Red-green safe", d: "Protanopia and deuteranopia", c: StoneColors(urgent: "orange", progress: "purple", open: "white")),
    Preset(id: "by", t: "Blue-yellow safe", d: "Tritanopia", c: StoneColors(urgent: "red", progress: "yellow", open: "white")),
]

extension StoneState {
    var meaning: String { [StoneState.urgent: "Due soon", .progress: "Someone is on it", .open: "No one has it yet", .done: "Light is off"][self]! }
    var short: String { self == .open ? "Unassigned" : label }
}

// MARK: - Picker

// The family's jar sits at the top and changes as soon as a color does; presets or your own colors below.
struct StoneColorPicker: View {
    @Environment(Store.self) private var store
    @State private var custom = false

    var body: some View {
        let on = PRESETS.first { $0.c == store.colors }
        VStack(alignment: .leading, spacing: 12) {
            VStack(spacing: 8) {
                SampleJar(states: ["done", "done", "progress", "urgent", "open", "progress", "open", "urgent", "progress"], width: 96)
                Text(on.map { "\($0.t) colors" } ?? "Your own colors").font(.system(size: 13, weight: .semibold)).foregroundStyle(Color.muted)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .glassCard()

            if custom { customRows } else { presets(on) }
        }
        .animation(.snappy, value: custom)
    }

    private func presets(_ on: Preset?) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Eyebrow(text: "Presets")
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                ForEach(PRESETS) { p in
                    Button { withAnimation(.snappy) { store.colors = p.c } } label: {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(spacing: 4) {
                                ForEach(COLOR_STATES, id: \.self) { s in Stone(state: s, w: .small, base: 26, palette: p.c) }
                                Spacer()
                                if on?.id == p.id { Image(systemName: "checkmark.circle.fill").foregroundStyle(Color.shoalBlue) }
                            }
                            .frame(height: 26)
                            Text(p.t).font(.system(size: 14.5, weight: .semibold)).foregroundStyle(Color.ink)
                            if p.rec { Text("Recommended").font(.system(size: 11, weight: .semibold)).foregroundStyle(Color.shoalBlue) }
                            Text(p.d).font(.system(size: 12)).foregroundStyle(Color.muted).multilineTextAlignment(.leading)
                            Spacer(minLength: 0)
                        }
                        .frame(maxWidth: .infinity, minHeight: 112, alignment: .topLeading)
                        .glassCard(radius: 18, padding: 12)
                        .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(on?.id == p.id ? Color.shoalBlue : .clear, lineWidth: 2))
                    }
                    .buttonStyle(Pressable())
                    .accessibilityAddTraits(on?.id == p.id ? .isSelected : [])
                }
            }
            Button { custom = true } label: {
                HStack(spacing: 12) {
                    if on == nil {
                        HStack(spacing: 4) { ForEach(COLOR_STATES, id: \.self) { s in Stone(state: s, w: .small, base: 22) } }
                    } else {
                        Image(systemName: "plus").font(.system(size: 16, weight: .semibold)).foregroundStyle(Color.shoalBlue)
                            .frame(width: 34, height: 34).background(Color.blueTint, in: .circle)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(on == nil ? "Your own colors" : "Make your own").font(.system(size: 15, weight: .semibold)).foregroundStyle(Color.ink)
                        Text(on == nil ? "Tap to change them" : "Pick a color for each stone").font(.meta).foregroundStyle(Color.muted)
                    }
                    Spacer()
                    Chevron()
                }
                .glassCard(radius: 18, padding: 12)
            }
            .buttonStyle(Pressable())
        }
    }

    private var customRows: some View {
        @Bindable var store = store
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Button { custom = false } label: { Label("Presets", systemImage: "chevron.left").font(.system(size: 14, weight: .semibold)) }
                Spacer()
                Text("Make your own").font(.system(size: 14, weight: .semibold)).foregroundStyle(Color.ink)
            }
            VStack(alignment: .leading, spacing: 14) {
                ForEach(COLOR_STATES, id: \.self) { s in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 10) {
                            Stone(state: s, w: .small, base: 24)
                            VStack(alignment: .leading, spacing: 1) {
                                Text("\(s.short) · \(store.colors.hue(s).name.capitalized)").font(.system(size: 14.5, weight: .semibold)).foregroundStyle(Color.ink)
                                Text(s.meaning).font(.system(size: 12)).foregroundStyle(Color.muted)
                            }
                        }
                        HStack(spacing: 6) {
                            ForEach(HUE_KEYS, id: \.self) { k in
                                let h = HUES[k]!, sel = store.colors[s] == k
                                Button { withAnimation(.snappy) { store.colors.pick(k, for: s) } } label: {
                                    Circle().fill(RadialGradient(colors: [Color(hex: h.hi), Color(hex: h.mid), Color(hex: h.lo)], center: UnitPoint(x: 0.38, y: 0.3), startRadius: 0, endRadius: 18))
                                        .frame(width: 30, height: 30)
                                        .overlay(Circle().strokeBorder(Color(hex: 0x13315d, 0.12)))
                                        .padding(3)
                                        .overlay(Circle().strokeBorder(sel ? Color.shoalBlue : .clear, lineWidth: 2))
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel(h.name).accessibilityAddTraits(sel ? .isSelected : [])
                            }
                        }
                    }
                    Divider()
                }
                HStack(spacing: 10) {
                    Stone(state: .done, w: .small, base: 24)
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Done · Off").font(.system(size: 14.5, weight: .semibold)).foregroundStyle(Color.ink)
                        Text("Always off, so it's clear the task is finished").font(.system(size: 12)).foregroundStyle(Color.muted)
                    }
                }
            }
            .glassCard()
            ForEach(Array(store.colors.lookAlike.enumerated()), id: \.offset) { _, w in
                Text("\(HUES[w.0]!.name.capitalized) and \(HUES[w.1]!.name) can look alike\(w.2 == "all" ? ", even with typical color vision" : " with \(w.2) color blindness"). Try Easy to tell apart.")
                    .font(.system(size: 13)).foregroundStyle(Color(hex: 0x8a5d0c))
                    .padding(12).frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(hex: 0xf6d27c, 0.22), in: .rect(cornerRadius: 14))
            }
            Text("Urgent stones also show a !, so color is never the only sign that something needs doing.").font(.system(size: 12.5)).foregroundStyle(Color.muted)
        }
    }
}

// Stone colors from Settings or the kit.
struct ColorsSheet: View {
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Stone colors").font(.title(28)).foregroundStyle(Color.navy)
                    StoneColorPicker()
                    if store.colors != .shoal {
                        Button("Reset colors") { withAnimation(.snappy) { store.colors = .shoal } }.buttonStyle(GhostButton()).padding(.top, 6)
                    }
                }
                .padding(20)
            }
            .background(AppBackground())
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
    }
}
