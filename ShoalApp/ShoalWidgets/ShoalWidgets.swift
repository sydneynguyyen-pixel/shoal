import WidgetKit
import SwiftUI
import ActivityKit

private extension Color {
    init(hex: UInt32, _ a: Double = 1) {
        self.init(.sRGB, red: Double((hex >> 16) & 0xff) / 255, green: Double((hex >> 8) & 0xff) / 255, blue: Double(hex & 0xff) / 255, opacity: a)
    }
    static let navy = Color(hex: 0x13315d)
    static let muted = Color(hex: 0x6e737c)
    static let shoalBlue = Color(hex: 0x2070d9)
    static let ringBlue = Color(hex: 0x418ef3)
    static let yellow = Color(hex: 0xf6d27c)
    static let yellowInk = Color(hex: 0x8a5d0c)
}

private let widgetBackground = LinearGradient(colors: [Color(hex: 0xecf4ff), Color(hex: 0xfbf7f0), .white], startPoint: .top, endPoint: .bottom)

private func clock(_ d: Date) -> String { d.formatted(date: .omitted, time: .shortened) }

@main
struct ShoalWidgetBundle: WidgetBundle {
    var body: some Widget {
        NextDoseWidget()
        UpNextWidget()
        DoseLiveActivity()
    }
}

// MARK: - Timeline

struct ShoalEntry: TimelineEntry {
    var date: Date
    var snap: ShoalSnapshot
}

struct ShoalProvider: TimelineProvider {
    func placeholder(in context: Context) -> ShoalEntry { ShoalEntry(date: .now, snap: .sample) }
    func getSnapshot(in context: Context, completion: @escaping (ShoalEntry) -> Void) {
        completion(ShoalEntry(date: .now, snap: context.isPreview ? .sample : .load()))
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<ShoalEntry>) -> Void) {
        let s = ShoalSnapshot.load()
        // A new entry when each dose turns okay, so "Okay after" flips to "Okay now" on time.
        var dates = [Date.now]
        dates += s.meds.map(\.okAt).filter { $0 > .now }.sorted()
        completion(Timeline(entries: dates.map { ShoalEntry(date: $0, snap: s) }, policy: .after(.now.addingTimeInterval(3600))))
    }
}

// MARK: - Next comfort dose (home screen small, lock screen rectangle)

struct NextDoseWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "NextDose", provider: ShoalProvider()) { e in
            NextDoseView(e: e).containerBackground(for: .widget) { widgetBackground }
                .widgetURL(URL(string: "shoal://care"))
        }
        .configurationDisplayName("Next dose")
        .description("When Dad's next comfort dose is okay.")
        .supportedFamilies([.systemSmall, .accessoryRectangular])
    }
}

struct DoseRing: View {
    var m: MedSnap
    var line: CGFloat = 6
    var body: some View {
        ProgressView(timerInterval: m.givenAt...m.okAt, countsDown: false) { EmptyView() } currentValueLabel: { EmptyView() }
            .progressViewStyle(.circular)
            .tint(Color.yellow)
    }
}

struct NextDoseView: View {
    @Environment(\.widgetFamily) private var family
    var e: ShoalEntry

    var body: some View {
        if let m = e.snap.meds.first {
            let ready = m.okAt <= e.date
            if family == .accessoryRectangular {
                HStack(spacing: 8) {
                    if ready {
                        Image(systemName: "checkmark.circle").font(.system(size: 28))
                    } else {
                        DoseRing(m: m).frame(width: 30, height: 30)
                    }
                    VStack(alignment: .leading, spacing: 0) {
                        Text(m.name).font(.headline).widgetAccentable()
                        Text(ready ? "Okay now" : "Okay after \(clock(m.okAt))").font(.caption)
                        Text("\(m.who) gave it \(clock(m.givenAt))").font(.caption2).foregroundStyle(.secondary)
                    }
                }
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        if ready {
                            Image(systemName: "checkmark.circle.fill").font(.system(size: 34)).foregroundStyle(Color.ringBlue)
                        } else {
                            DoseRing(m: m).frame(width: 36, height: 36)
                        }
                        Spacer()
                    }
                    Spacer(minLength: 0)
                    Text("\(m.name) \(m.amt)").font(.system(size: 15, weight: .semibold)).foregroundStyle(Color.navy)
                    Text(ready ? "Okay now" : "Okay after").font(.system(size: 12.5)).foregroundStyle(Color.muted)
                    if !ready {
                        Text(clock(m.okAt)).font(.system(size: 24, weight: .semibold, design: .serif)).foregroundStyle(Color.yellowInk)
                    }
                    Text("\(m.who) · \(clock(m.givenAt))").font(.system(size: 11.5)).foregroundStyle(Color.muted)
                }
            }
        } else {
            VStack(alignment: .leading) {
                Text("Comfort meds").font(.headline)
                Text("Nothing given yet").font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Up next for you (home screen medium, lock screen circle)

struct UpNextWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "UpNext", provider: ShoalProvider()) { e in
            UpNextView(e: e).containerBackground(for: .widget) { widgetBackground }
                .widgetURL(URL(string: e.snap.next.map { "shoal://task/\($0.id)" } ?? "shoal://myjar"))
        }
        .configurationDisplayName("Up next for you")
        .description("Your next task and how many are left.")
        .supportedFamilies([.systemMedium, .accessoryCircular])
    }
}

struct UpNextView: View {
    @Environment(\.widgetFamily) private var family
    var e: ShoalEntry

    var body: some View {
        let s = e.snap
        if family == .accessoryCircular {
            Gauge(value: Double(s.total - s.left), in: 0...Double(max(s.total, 1))) {
                Text("to do")
            } currentValueLabel: {
                VStack(spacing: -2) {
                    Text("\(s.left)").font(.system(size: 20, weight: .semibold))
                    Text("to do").font(.system(size: 9))
                }
            }
            .gaugeStyle(.accessoryCircularCapacity)
            .widgetURL(URL(string: "shoal://myjar"))
        } else {
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("UP NEXT FOR YOU").font(.system(size: 10.5, weight: .semibold)).tracking(0.8).foregroundStyle(Color.muted)
                    if let t = s.next {
                        Text(t.n).font(.system(size: 18, weight: .regular, design: .serif)).foregroundStyle(Color.navy).lineLimit(2)
                        Text(t.due).font(.system(size: 12.5, weight: .semibold)).foregroundStyle(Color.yellowInk)
                    } else {
                        Text("All done").font(.system(size: 18, design: .serif)).foregroundStyle(Color.navy)
                    }
                    Spacer(minLength: 0)
                    Text("Shoal").font(.system(size: 11, weight: .semibold)).foregroundStyle(Color.shoalBlue)
                }
                Spacer(minLength: 0)
                ZStack {
                    Circle().stroke(Color(hex: 0x6e737c, 0.13), lineWidth: 8)
                    Circle().trim(from: 0, to: CGFloat(s.total - s.left) / CGFloat(max(s.total, 1)))
                        .stroke(Color.ringBlue, style: .init(lineWidth: 8, lineCap: .round)).rotationEffect(.degrees(-90))
                    VStack(spacing: 0) {
                        Text("\(s.left)").font(.system(size: 24, weight: .semibold)).foregroundStyle(Color.navy)
                        Text("left").font(.system(size: 11)).foregroundStyle(Color.muted)
                    }
                }
                .frame(width: 84, height: 84)
            }
        }
    }
}

// MARK: - Live Activity: the last comfort dose

struct DoseLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: DoseActivityAttributes.self) { ctx in
            DoseActivityView(a: ctx.attributes, s: ctx.state)
                .padding(16)
                .activityBackgroundTint(Color.white.opacity(0.85))
                .widgetURL(URL(string: "shoal://care"))
        } dynamicIsland: { ctx in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Text("\(ctx.attributes.medName) \(ctx.attributes.amt)").font(.headline)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(timerInterval: Date.now...max(Date.now, ctx.state.nextAt), countsDown: true)
                        .font(.headline.monospacedDigit()).multilineTextAlignment(.trailing).foregroundStyle(Color.yellow)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(alignment: .leading, spacing: 6) {
                        ProgressView(timerInterval: ctx.state.givenAt...ctx.state.nextAt, countsDown: false) { EmptyView() } currentValueLabel: { EmptyView() }
                            .tint(Color.yellow)
                        Text("\(ctx.state.who) gave it \(clock(ctx.state.givenAt)) · next dose okay \(clock(ctx.state.nextAt))")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
            } compactLeading: {
                Image(systemName: "pills.fill").foregroundStyle(Color.yellow)
            } compactTrailing: {
                Text(timerInterval: Date.now...max(Date.now, ctx.state.nextAt), countsDown: true)
                    .monospacedDigit().frame(maxWidth: 52).foregroundStyle(Color.yellow)
            } minimal: {
                Image(systemName: "pills.fill").foregroundStyle(Color.yellow)
            }
            .widgetURL(URL(string: "shoal://care"))
        }
    }
}

struct DoseActivityView: View {
    var a: DoseActivityAttributes
    var s: DoseActivityAttributes.ContentState
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text("\(a.medName) \(a.amt)").font(.system(size: 17, weight: .semibold)).foregroundStyle(Color.navy)
                Spacer()
                Text("Shoal").font(.system(size: 12, weight: .semibold)).foregroundStyle(Color.shoalBlue)
            }
            Text("\(s.who) gave it \(clock(s.givenAt))").font(.system(size: 13.5)).foregroundStyle(Color.muted)
            ProgressView(timerInterval: s.givenAt...s.nextAt, countsDown: false) { EmptyView() } currentValueLabel: { EmptyView() }
                .tint(Color.yellow)
            Text("Next dose okay \(clock(s.nextAt))").font(.system(size: 14, weight: .semibold)).foregroundStyle(Color.yellowInk)
        }
    }
}
