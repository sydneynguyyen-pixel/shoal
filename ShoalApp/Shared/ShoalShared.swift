import Foundation
import ActivityKit

// Shared by the app and its widgets: what the home and lock screen show.
let APP_GROUP = "group.com.shoal.prototype"

struct MedSnap: Codable, Hashable {
    var name: String
    var amt: String
    var who: String
    var givenAt: Date
    var okAt: Date
}

struct TaskSnap: Codable, Hashable {
    var id: String
    var n: String
    var due: String
}

struct ShoalSnapshot: Codable, Hashable {
    var meds: [MedSnap]
    var next: TaskSnap?
    var left: Int
    var total: Int

    static let key = "snapshot"

    static func load() -> ShoalSnapshot {
        if let d = UserDefaults(suiteName: APP_GROUP)?.data(forKey: key),
           let s = try? JSONDecoder().decode(ShoalSnapshot.self, from: d) { return s }
        return .sample
    }

    func save() {
        if let d = try? JSONEncoder().encode(self) { UserDefaults(suiteName: APP_GROUP)?.set(d, forKey: Self.key) }
    }

    // Used before the app has written anything, and in the widget gallery.
    static var sample: ShoalSnapshot {
        let given = Date().addingTimeInterval(-2.4 * 3600)
        return ShoalSnapshot(
            meds: [MedSnap(name: "Morphine", amt: "5 mg", who: "Mom", givenAt: given, okAt: given.addingTimeInterval(4 * 3600))],
            next: TaskSnap(id: "d0", n: "Refill Dad's prescription", due: "Due tomorrow"),
            left: 5, total: 8)
    }
}

// The Live Activity for a comfort med: who gave it, and when the next dose is okay.
struct DoseActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var who: String
        var givenAt: Date
        var nextAt: Date
    }
    var medName: String
    var amt: String
}
