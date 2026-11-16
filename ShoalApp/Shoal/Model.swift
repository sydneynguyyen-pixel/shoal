import Foundation

// The prototype's "today" is Tue Oct 20, 2026, same as the web app.
let TODAY: Date = Calendar.current.date(from: DateComponents(year: 2026, month: 10, day: 20))!
let DAYS = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
let DAY_FULL = ["Mon": "Monday", "Tue": "Tuesday", "Wed": "Wednesday", "Thu": "Thursday", "Fri": "Friday", "Sat": "Saturday", "Sun": "Sunday"]

func addDays(_ n: Int, to d: Date = TODAY) -> Date { Calendar.current.date(byAdding: .day, value: n, to: d)! }
func dayKey(_ d: Date) -> String { DAYS[(Calendar.current.component(.weekday, from: d) + 5) % 7] }
func daysFromToday(_ d: Date) -> Int {
    Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: TODAY), to: Calendar.current.startOfDay(for: d)).day ?? 0
}
func fmtDate(_ d: Date) -> String { d.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day()) }
func plural(_ n: Int, _ word: String) -> String { "\(n) \(word)\(n == 1 ? "" : "s")" }

enum Tier: String, CaseIterable, Identifiable {
    case main, trusted, kid
    var id: String { rawValue }
    var label: String { ["main": "Family", "trusted": "Trusted circle", "kid": "Kids"][rawValue]! }
}

struct Person: Identifiable, Hashable {
    let id: String
    var name: String
    var img: String?
    var tier: Tier
    var cap: Int            // hours a week they said they can give
    var about: String
    var remote = false
    var best = ""
    var reach = ""
    var contact = ""
    var know: [String] = []
    var invited = false
}

enum Weight: Int, CaseIterable, Identifiable {
    case small = 1, medium = 2, large = 3
    var id: Int { rawValue }
    var label: String { ["Small", "Medium", "Large"][rawValue - 1] }
    var hours: Int { [1, 3, 6][rawValue - 1] }
    var hint: String { ["Quick, about an hour or less", "A few hours, or a trip out", "Half a day or more, or overnight"][rawValue - 1] }
}

enum Kind: String { case once, repeating }

struct Step: Identifiable, Hashable {
    let id = UUID()
    var n: String
    var who: String?
    var done = false
    var when: String?
    var ask: String?        // asked someone, waiting on an answer
}

struct Request: Identifiable, Hashable {
    let id: String
    var from: String
    var n: String
    var note: String
}

struct Handoff: Hashable {
    var to: [String]
    var note: String
    var pending = true
}

struct CareTask: Identifiable, Hashable {
    let id: String
    var n: String
    var who: String?
    var w: Weight
    var cat: String
    var kind: Kind
    var days: [String] = []
    var date: Date
    var time: String = ""
    var done = false
    var doneAt: String?
    var steps: [Step] = []
    var notes = ""
    var remote = false
    var why = ""
    var open: [Tier]?       // who can help; nil means the default for its size
    var handoff: Handoff?

    var urgent: Bool { kind == .once && !done && daysFromToday(date) <= 2 }
    var state: StoneState {
        if done { return .done }
        if who == nil { return .open }
        return urgent ? .urgent : .progress
    }
    func occurs(on d: Date) -> Bool {
        kind == .repeating ? days.contains(dayKey(d)) : Calendar.current.isDate(date, inSameDayAs: d)
    }
    var dueLabel: String {
        if kind == .repeating { return repeatLabel(days) }
        let d = daysFromToday(date)
        if d == 0 { return "due today" }
        if d == 1 { return "due tomorrow" }
        if d < 0 { return fmtDate(date) }
        return "due \(fmtDate(date))"
    }
}

enum StoneState { case urgent, progress, open, done
    var label: String { ["Urgent", "In progress", "Needs someone", "Done"][[StoneState.urgent, .progress, .open, .done].firstIndex(of: self)!] }
}

func repeatLabel(_ days: [String]) -> String {
    let set = DAYS.filter { days.contains($0) }
    if set.isEmpty { return "As needed" }
    if set.count == 7 { return "Every day" }
    if set == ["Mon", "Tue", "Wed", "Thu", "Fri"] { return "Weekdays" }
    if set == ["Sat", "Sun"] { return "Weekends" }
    return set.count == 1 ? "Every \(set[0])" : set.joined(separator: ", ")
}

// MARK: - Demo family

nonisolated(unsafe) var LOVED = "Dad"   // set from onboarding

let DEMO_PEOPLE: [Person] = [
    Person(id: "you", name: "You", img: "avatar-you", tier: .main, cap: 8, about: "Primary caregiver"),
    Person(id: "mom", name: "Mom", img: "avatar-mom", tier: .main, cap: 9, about: "Lives with Dad",
           best: "Mornings", reach: "Call", contact: "(408) 555-0142",
           know: ["Doesn't drive after dark", "Needs a nap around 2, so no calls then", "Knows all the meds by heart"]),
    Person(id: "bill", name: "Bill", img: "avatar-bill", tier: .main, cap: 6, about: "Free evenings · 10 min away",
           best: "After 6 PM", reach: "Text", contact: "(408) 555-0179",
           know: ["Bad back, so no heavy lifting", "Has the truck, good for big pickups", "Works days, can't take calls till lunch"]),
    Person(id: "sam", name: "Sam", img: "avatar-sam", tier: .main, cap: 3, about: "Helps from Portland", remote: true,
           best: "Weekends", reach: "Text", contact: "(503) 555-0188",
           know: ["Great with insurance and forms", "Visiting Thanksgiving week", "Can make calls on work breaks"]),
    Person(id: "nora", name: "Nora", img: "avatar-nora", tier: .trusted, cap: 2, about: "Neighbor",
           best: "Weekdays", reach: "Text", contact: "(408) 555-0115",
           know: ["Has a spare key", "Can check in if no one answers"]),
]

func demoTasks() -> [CareTask] {
    var n = 0
    func mk(_ name: String, _ who: String?, _ w: Int, _ cat: String, days: [String]? = nil, due: Int = 0,
            done: Bool = false, doneAt: String? = nil, notes: String = "", steps: [Step] = [], remote: Bool = false, why: String = "") -> CareTask {
        defer { n += 1 }
        return CareTask(id: "d\(n)", n: name, who: who, w: Weight(rawValue: w)!, cat: cat,
                        kind: days == nil ? .once : .repeating, days: days ?? [], date: days == nil ? addDays(due) : addDays(3),
                        done: done, doneAt: doneAt, steps: steps, notes: notes, remote: remote, why: why)
    }
    let l = LOVED
    return [
        mk("Refill \(l)'s prescription", "you", 1, "meds", due: 1,
           notes: "Ask for the 90-day supply. The old bottle is in the kitchen drawer. The hospice nurse said to fill the PRN dose too.",
           steps: [Step(n: "Call the pharmacy", who: "you", done: true, when: "Mon"),
                   Step(n: "Check insurance covers it", who: "bill"),
                   Step(n: "Pick up or get it delivered", who: nil)]),
        mk("Ask hospice about a bed", "you", 1, "phone", due: 4),
        mk("Figure out help paying for care", "you", 2, "paper", due: 6),
        mk("Sort \(l)'s mail", "you", 1, "paper", days: ["Mon"]),
        mk("Fill the weekly pill box", "you", 1, "meds", days: ["Sun"]),
        mk("Book the eye exam", "you", 1, "phone", due: -2, done: true),
        mk("Call about the hospital bill", "you", 2, "phone", due: -4, done: true),
        mk("Return the walker", "you", 1, "drive", due: -5, done: true),
        mk("Cook dinners", "mom", 2, "cook", days: ["Mon", "Wed", "Fri"]),
        mk("Morning meds", "mom", 1, "meds", days: DAYS),
        mk("Comfort meds", "mom", 1, "meds", days: DAYS,
           notes: "From the hospice comfort kit in the fridge. Call hospice before giving more than the plan says."),
        mk("Keep \(l) company", "mom", 2, "there", days: DAYS),
        mk("Laundry and sheets", "mom", 2, "there", due: -1, done: true),
        mk("Drive \(l) to Thursday's visit", "bill", 2, "drive", due: 2, why: "10 minutes away"),
        mk("Pick up groceries", "bill", 2, "drive", days: ["Sat"], why: "Free evenings"),
        mk("Fix the stair rail", "bill", 2, "there", due: 5, why: "Said he's handy"),
        mk("Weekend visits", "bill", 2, "there", days: ["Sun"], why: "Wants to be there"),
        mk("Take out recycling", "bill", 1, "there", days: ["Tue"], why: "Lives closest"),
        mk("Drive \(l) to his checkup", "bill", 2, "drive", due: 0, done: true, doneAt: "Today, 2:00 PM"),
        mk("Order groceries online", "sam", 1, "phone", days: ["Fri"], remote: true, why: "Can do it from anywhere"),
        mk("Video call with \(l)", "sam", 1, "there", days: ["Wed", "Sun"], remote: true, why: "Wants to be there"),
        mk("Pay the utility bills", "sam", 1, "paper", due: -3, done: true, remote: true),
        mk("Bring in the mail", "nora", 1, "there", days: ["Mon", "Thu"]),
        mk("Be there for the nurse visit", nil, 2, "there", due: 2),
        mk("Mow the lawn", nil, 2, "there", days: ["Sat"]),
    ]
}
