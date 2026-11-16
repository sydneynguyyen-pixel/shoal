import SwiftUI
import ActivityKit
import WidgetKit

// MARK: - Dad's care page: meds, doses and what the family should know

struct Med: Identifiable, Hashable {
    var id: String
    var name: String
    var amt: String
    var how: String
    var why: String
    var prn: Bool          // as needed
    var every: Int = 0     // hours apart, for as-needed meds
    var time: String = ""  // when, for daily meds
}

struct Dose: Identifiable, Hashable {
    let id = UUID()
    var med: String
    var by: String
    var at: Date
}

struct CareNote: Identifiable, Hashable {
    let id = UUID()
    var t: String
    var body: String
    var short: String = ""
    var by: String = "mom"
    var on: String = "Sep 30"
    var alert = false
}

enum CareSection: String { case key, needs, prefs }

func demoMeds() -> [Med] {[
    Med(id: "morphine", name: "Morphine", amt: "5 mg", how: "0.25 mL under the tongue", why: "For pain or hard breathing", prn: true, every: 4),
    Med(id: "lorazepam", name: "Lorazepam", amt: "0.5 mg", how: "1 tablet, dissolved under the tongue", why: "For anxiety or restlessness", prn: true, every: 6),
    Med(id: "metoprolol", name: "Metoprolol", amt: "25 mg", how: "1 tablet with breakfast", why: "For his heart", prn: false, time: "8 AM"),
    Med(id: "senna", name: "Senna", amt: "2 tablets", how: "With water at bedtime", why: "Morphine can cause constipation", prn: false, time: "9 PM"),
]}

func demoDoses() -> [Dose] {
    let now = Date()
    let eight = Calendar.current.date(bySettingHour: 8, minute: 10, second: 0, of: now)!
    return [
        Dose(med: "morphine", by: "bill", at: now.addingTimeInterval(-7.2 * 3600)),
        Dose(med: "lorazepam", by: "mom", at: now.addingTimeInterval(-6.5 * 3600)),
        Dose(med: "metoprolol", by: "mom", at: min(eight, now.addingTimeInterval(-60))),
        Dose(med: "morphine", by: "mom", at: now.addingTimeInterval(-2.4 * 3600)),
    ]
}

func demoKey() -> [CareNote] {[
    CareNote(t: "Allergies", body: "Penicillin (hives). Codeine makes him sick to his stomach.", short: "Penicillin, codeine", alert: true),
    CareNote(t: "Wishes", body: "Comfort care only. Dad doesn't want CPR (DNR). The signed form is on the fridge.", short: "DNR · comfort care only"),
    CareNote(t: "Pharmacy", body: "CVS on Saratoga Ave · (408) 555-0110. Hospice delivers the comfort kit.", by: "you", on: "Oct 2"),
]}

func demoNeeds() -> [CareNote] {[
    CareNote(t: "Moving", body: "Needs two people to get out of bed. The gait belt is in the hall closet.", short: "Two people to get up"),
    CareNote(t: "Eating and drinking", body: "Soft foods, small bites. Thickened water only, small sips.", short: "Soft food, thick water"),
    CareNote(t: "Skin", body: "Turn him every 2 to 3 hours. Lotion on his heels and elbows.", by: "bill"),
    CareNote(t: "Bathroom", body: "Wears briefs. Supplies are under the bathroom sink."),
]}

func demoPrefs() -> [CareNote] {[
    CareNote(t: "Likes", body: "Jazz on the radio, the window open a crack, cold ginger ale.", by: "sam"),
    CareNote(t: "Doesn't like", body: "Loud TV. Being rushed in the morning."),
    CareNote(t: "Comfort", body: "A cool cloth on his forehead. Someone holding his hand."),
    CareNote(t: "Visits", body: "Sam's video call at 7 PM. Pastor Jim on Sundays after church.", by: "you", on: "Oct 2"),
]}

func clock(_ d: Date) -> String { d.formatted(date: .omitted, time: .shortened) }

func ago(_ d: Date) -> String {
    let m = Int(Date().timeIntervalSince(d) / 60)
    if m < 1 { return "just now" }
    if m < 60 { return "\(m) min ago" }
    let h = m / 60, r = m % 60
    if h >= 24 { return "\(h / 24) day\(h >= 48 ? "s" : "") ago" }
    return r >= 10 && h < 6 ? "\(h) hr \(r) min ago" : "\(h) hr ago"
}

extension Store {
    var careUnlocked: Bool {
        guard let u = careUnlockedAt else { return false }
        return Date().timeIntervalSince(u) < 300
    }

    func unlockCare(face: Bool) {
        let at = Date()
        careUnlockedAt = at
        say(face ? "Unlocked with Face ID" : "Unlocked for 5 minutes")
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(300))
            if careUnlockedAt == at { careUnlockedAt = nil }
        }
    }

    func lockCare() { careUnlockedAt = nil; say("Locked") }

    var allergies: String { careKey.first { $0.alert }?.short ?? "" }
    func med(_ id: String) -> Med? { meds.first { $0.id == id } }
    func lastDose(_ id: String) -> Dose? { doses.filter { $0.med == id }.max { $0.at < $1.at } }

    // When the next as-needed dose is okay. nil means okay now.
    func okAt(_ m: Med) -> Date? {
        guard m.prn, let d = lastDose(m.id) else { return nil }
        let t = d.at.addingTimeInterval(Double(m.every) * 3600)
        return t > Date() ? t : nil
    }

    func givenToday(_ m: Med) -> Dose? {
        doses.filter { $0.med == m.id && Calendar.current.isDateInToday($0.at) }.max { $0.at < $1.at }
    }

    func logDose(_ m: Med) {
        let now = Date()
        doses.append(Dose(med: m.id, by: "you", at: now))
        say("Logged \(m.amt) \(m.name.lowercased()) at \(clock(now)). Mom, Bill and Sam were told.")
        if m.prn { startDoseActivity(m, who: "You", at: now) }
        syncWidgets()
    }

    func removeDose(_ d: Dose) {
        doses.removeAll { $0.id == d.id }
        say("Removed")
        syncWidgets()
    }

    func saveNote(_ n: CareNote, in s: CareSection) {
        func put(_ list: inout [CareNote]) {
            if let i = list.firstIndex(where: { $0.id == n.id }) { list[i] = n } else { list.append(n) }
        }
        switch s {
        case .key: put(&careKey)
        case .needs: put(&needs)
        case .prefs: put(&prefs)
        }
        say("Saved. Everyone sees the change.")
    }

    // MARK: widgets and Live Activity

    func syncWidgets() {
        // Most recent dose first, so the widget matches the Live Activity.
        let ms: [MedSnap] = meds.filter(\.prn).compactMap { m -> MedSnap? in
            guard let d = lastDose(m.id) else { return nil }
            return MedSnap(name: m.name, amt: m.amt, who: d.by == "you" ? "You" : name(d.by), givenAt: d.at,
                           okAt: d.at.addingTimeInterval(Double(m.every) * 3600))
        }.sorted { $0.givenAt > $1.givenAt }
        let mineAll = mine("you")
        let left = mineAll.filter { !$0.done }.sorted { a, b in
            a.urgent != b.urgent ? a.urgent : a.date < b.date
        }
        let next = left.first.map { TaskSnap(id: $0.id, n: $0.n, due: $0.dueLabel) }
        ShoalSnapshot(meds: ms, next: next, left: left.count, total: mineAll.count).save()
        WidgetCenter.shared.reloadAllTimelines()
    }

    func startDoseActivity(_ m: Med, who: String, at: Date) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        let next = at.addingTimeInterval(Double(m.every) * 3600)
        let state = DoseActivityAttributes.ContentState(who: who, givenAt: at, nextAt: next)
        Task {
            for a in Activity<DoseActivityAttributes>.activities { await a.end(nil, dismissalPolicy: .immediate) }
            _ = try? Activity.request(attributes: DoseActivityAttributes(medName: m.name, amt: m.amt),
                                      content: .init(state: state, staleDate: next))
        }
    }

    // On launch, show the last comfort dose on the lock screen.
    func startSeededActivity() {
        guard Activity<DoseActivityAttributes>.activities.isEmpty,
              let m = med("morphine"), let d = lastDose(m.id), okAt(m) != nil else { return }
        startDoseActivity(m, who: name(d.by), at: d.at)
    }
}
