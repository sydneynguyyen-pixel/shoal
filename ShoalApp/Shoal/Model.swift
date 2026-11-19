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
// Friday of this week, or 3 days out if that's already gone.
func byFriday() -> Date {
    let wd = (Calendar.current.component(.weekday, from: TODAY) + 5) % 7   // Mon = 0
    return wd <= 4 ? addDays(4 - wd) : addDays(3)
}
// Times are kept as "HH:mm", like the web, and shown as "9 AM" or "2:30 PM".
func fmtTime(_ t: String) -> String {
    let p = t.split(separator: ":").compactMap { Int($0) }
    guard p.count == 2 else { return "" }
    return "\(p[0] % 12 == 0 ? 12 : p[0] % 12)\(p[1] == 0 ? "" : String(format: ":%02d", p[1])) \(p[0] < 12 ? "AM" : "PM")"
}
func timeDate(_ t: String) -> Date {
    let p = t.split(separator: ":").compactMap { Int($0) }
    return Calendar.current.date(bySettingHour: p.first ?? 9, minute: p.count > 1 ? p[1] : 0, second: 0, of: TODAY)!
}
func timeString(_ d: Date) -> String {
    let c = Calendar.current.dateComponents([.hour, .minute], from: d)
    return String(format: "%02d:%02d", c.hour ?? 9, c.minute ?? 0)
}
// "Bill", "Bill and Sam", "Bill, Sam and Nora"
func andList(_ names: [String]) -> String {
    names.count < 2 ? names.joined() : names.dropLast().joined(separator: ", ") + " and " + names.last!
}

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
    var via = "text"        // how the invite went out: text, email or link
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
    var ask: [String]?      // asked these people, waiting on an answer
}

struct Request: Identifiable, Hashable {
    let id: String
    var from: String
    var n: String
    var note: String
}

struct Handoff: Hashable {
    enum Status: Hashable { case pending, accepted, declined }
    var to: [String]
    var note: String
    var status = Status.pending
    var all = false          // asked everyone who can take it
    var taker: String?       // who answered
    var when = ""
    var why = ""
    var pending: Bool { status == .pending }
    var who: String? { taker ?? to.first }
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
    // Sam was invited by text and hasn't joined yet, so Sam shows as Pending.
    Person(id: "sam", name: "Sam", img: "avatar-sam", tier: .main, cap: 3, about: "Helps from Portland", remote: true,
           best: "Weekends", reach: "Text", contact: "(503) 555-0188",
           know: ["Great with insurance and forms", "Visiting Thanksgiving week", "Can make calls on work breaks"], invited: true),
    Person(id: "nora", name: "Nora", img: "avatar-nora", tier: .trusted, cap: 2, about: "Neighbor",
           best: "Weekdays", reach: "Text", contact: "(408) 555-0115",
           know: ["Has a spare key", "Can check in if no one answers"]),
    Person(id: "leo", name: "Leo", img: nil, tier: .kid, cap: 2, about: "Dad's grandson, 14"),
]

func demoTasks() -> [CareTask] {
    var n = 0
    func mk(_ name: String, _ who: String?, _ w: Int, _ cat: String, days: [String]? = nil, due: Int = 0,
            done: Bool = false, doneAt: String? = nil, remote: Bool = false, why: String = "", kid: Bool = false, notes: String = "", steps: [Step] = []) -> CareTask {
        defer { n += 1 }
        return CareTask(id: "d\(n)", n: name, who: who, w: Weight(rawValue: w)!, cat: cat,
                        kind: days == nil ? .once : .repeating, days: days ?? [], date: days == nil ? addDays(due) : addDays(3),
                        done: done, doneAt: doneAt, steps: steps, notes: notes, remote: remote, why: why,
                        open: kid ? [.main, .trusted, .kid] : nil)
    }
    let l = LOVED
    // Every task gets a short note and a few steps, so each task page reads the same way.
    // The first `done` steps are checked; steps belong to the task's person unless said.
    func st(_ who: String?, _ done: Int, _ names: String...) -> [Step] {
        names.enumerated().map { i, x in Step(n: x, who: who, done: i < done) }
    }
    return [
        // You: 3 of 8 done, 1 urgent.
        mk("Refill \(l)'s prescription", "you", 1, "meds", due: 1,
           notes: "Ask for the 90-day supply. The old bottle is in the kitchen drawer. The hospice nurse said to fill the PRN dose too.",
           steps: [Step(n: "Call the pharmacy", who: "you", done: true, when: "Mon"),
                   Step(n: "Check insurance covers it", who: "bill"),
                   Step(n: "Pick up or get it delivered", who: nil)]),
        mk("Ask hospice about a bed", "you", 1, "phone", due: 4,
           notes: "A hospital bed would let \(l) sit up to eat. Ask if hospice covers it and how fast it can come.",
           steps: st("you", 0, "Call the hospice line", "Measure the bedroom door", "Pick a delivery day")),
        mk("Figure out help paying for care", "you", 2, "paper", due: 6,
           notes: "Start with what Medicare covers for hospice, then see what's left over.",
           steps: st("you", 1, "Gather the last 3 bills", "Check what Medicare covers", "Ask about state help")),
        mk("Sort \(l)'s mail", "you", 1, "paper", days: ["Mon"],
           notes: "Bills go in the blue folder. Anything from the hospital, take a photo for the family.",
           steps: st("you", 0, "Open and sort", "File the bills", "Toss the junk")),
        mk("Fill the weekly pill box", "you", 1, "meds", days: ["Sun"],
           notes: "Use the list on the fridge. Morning slots are on top.",
           steps: st("you", 0, "Check the list on the fridge", "Fill morning and night", "Note anything running low")),
        mk("Book the eye exam", "you", 1, "phone", due: -2, done: true, doneAt: "Mon",
           notes: "Dr. Patel's office. Afternoons are easier for \(l).",
           steps: st("you", 2, "Call the office", "Add it to the calendar")),
        mk("Call about the hospital bill", "you", 2, "phone", due: -4, done: true, doneAt: "Last Fri",
           notes: "They agreed to a payment plan. The letter should come this week.",
           steps: st("you", 3, "Find the account number", "Call billing", "Ask for a payment plan")),
        mk("Return the walker", "you", 1, "drive", due: -5, done: true, doneAt: "Last Thu",
           notes: "The supply store on Main takes returns till 5.",
           steps: st("you", 2, "Fold it into the car", "Drop it at the store")),

        // Mom: 4 of 8 done, nothing urgent.
        mk("Cook dinners", "mom", 2, "cook", days: ["Mon", "Wed", "Fri"],
           notes: "Soft foods. \(l) likes soup and mashed potatoes.",
           steps: st("mom", 0, "Plan the meals", "Cook", "Put leftovers in the fridge")),
        mk("Morning meds", "mom", 1, "meds", days: DAYS,
           notes: "With breakfast. Check the box off on the fridge list.",
           steps: st("mom", 0, "Give the morning pills", "Check it off")),
        mk("Comfort meds", "mom", 1, "meds", days: DAYS,
           notes: "From the hospice comfort kit in the fridge. Call hospice before giving more than the plan says.",
           steps: st("mom", 0, "Check the plan", "Give the dose", "Write down the time")),
        mk("Keep \(l) company", "mom", 2, "there", days: DAYS,
           notes: "He likes the radio on and the old photo albums.",
           steps: st("mom", 0, "Sit with him after lunch", "Help with a short walk")),
        mk("Laundry and sheets", "mom", 2, "there", due: -1, done: true, doneAt: "Yesterday",
           notes: "Fresh sheets twice a week. The spare set is in the hall closet.",
           steps: st("mom", 2, "Wash and dry", "Make the bed")),
        mk("Pick up the hospice supplies", "mom", 1, "drive", due: -2, done: true, doneAt: "Mon",
           notes: "Gloves, pads and wipes. Ask for the large gloves.",
           steps: st("mom", 2, "Call ahead", "Pick up at the front desk")),
        mk("Call the church about visits", "mom", 1, "phone", due: -3, done: true, doneAt: "Sun",
           notes: "Pastor Kim can come Tuesdays.",
           steps: st("mom", 2, "Call the office", "Pick a day")),
        mk("Clean out the fridge", "mom", 1, "there", due: -4, done: true, doneAt: "Last Sat",
           notes: "Check dates on the milk and yogurt.",
           steps: st("mom", 2, "Toss old food", "Wipe the shelves")),

        // Bill: 1 of 6 done, 2 urgent.
        mk("Drive \(l) to Thursday's visit", "bill", 2, "drive", due: 2, why: "10 minutes away",
           notes: "Appointment at 10. Bring the med list and his glasses.",
           steps: st("bill", 0, "Pick him up at 9:30", "Bring the med list", "Drive him home")),
        mk("Fix the stair rail", "bill", 2, "there", due: 1, why: "Said he's handy",
           notes: "The top bracket is loose. \(l) uses it every day.",
           steps: st("bill", 1, "Buy longer screws", "Tighten the top bracket", "Test it")),
        mk("Pick up groceries", "bill", 2, "drive", days: ["Sat"], why: "Free evenings",
           notes: "The list is on the fridge. Get the soft bread.",
           steps: st("bill", 0, "Grab the list", "Shop", "Put it away")),
        mk("Weekend visits", "bill", 2, "there", days: ["Sun"], why: "Wants to be there",
           notes: "Afternoons are best. He likes to watch the game.",
           steps: st("bill", 0, "Visit after lunch", "Tell the family how he's doing")),
        mk("Take out recycling", "bill", 1, "there", days: ["Tue"], why: "Lives closest",
           notes: "Bins go out Monday night.",
           steps: st("bill", 0, "Roll the bins out", "Bring them back in")),
        mk("Drive \(l) to his checkup", "bill", 2, "drive", due: 0, done: true, doneAt: "Today, 2:00 PM",
           notes: "Doctor said things look steady.",
           steps: st("bill", 2, "Drive him there", "Drive him home")),

        // Sam: 1 of 3 done, from far away.
        mk("Order groceries online", "sam", 1, "phone", days: ["Fri"], remote: true, why: "Can do it from anywhere",
           notes: "Delivery to the house between 2 and 4.",
           steps: st("sam", 0, "Check the fridge list", "Place the order")),
        mk("Video call with \(l)", "sam", 1, "there", days: ["Wed", "Sun"], remote: true, why: "Wants to be there",
           notes: "Call Mom's phone. Keep it to 20 minutes.",
           steps: st("sam", 0, "Text Mom first", "Call")),
        mk("Pay the utility bills", "sam", 1, "paper", due: -3, done: true, doneAt: "Sat", remote: true,
           notes: "Paid online. Receipts are in the shared folder.",
           steps: st("sam", 2, "Pay power and water", "Save the receipts")),

        mk("Bring in the mail", "nora", 1, "there", days: ["Mon", "Thu"],
           notes: "Leave it on the kitchen table.",
           steps: st("nora", 0, "Grab it from the box", "Leave it inside")),

        // Unassigned.
        mk("Be there for the nurse visit", nil, 2, "there", due: 2,
           notes: "Ana comes at 11. Someone needs to let her in and hear the update.",
           steps: st(nil, 0, "Be at the house by 10:45", "Let Ana in", "Share her update")),
        mk("Mow the lawn", nil, 2, "there", days: ["Sat"],
           notes: "The mower is in the garage. Gas can is full.",
           steps: st(nil, 0, "Mow front", "Mow back")),
        // Small jobs for the trusted circle and kid tasks for Leo.
        mk("Drop off a library book", nil, 1, "drive", due: 3,
           notes: "It's on the hall table. Due Friday.",
           steps: st(nil, 0, "Grab the book", "Drop it in the return slot")),
        mk("Walk the dog after lunch", nil, 1, "there", days: ["Wed"], kid: true,
           notes: "Leash is by the door. Around the block is plenty.",
           steps: st(nil, 0, "Leash up", "Walk the block")),
        mk("Read the paper to \(l)", "leo", 1, "there", days: ["Tue", "Sat"], kid: true,
           notes: "Sports page first. He likes the crossword too.",
           steps: st("leo", 0, "Read the sports page", "Do the crossword together")),
        mk("Water the plants", "leo", 1, "there", days: ["Wed"], kid: true,
           notes: "Just the ones in the front window.",
           steps: st("leo", 0, "Fill the can", "Water the window plants")),
        mk("Make a card for \(l)", nil, 1, "there", due: 4, kid: true,
           notes: "Anything bright. He keeps them on the dresser.",
           steps: st(nil, 0, "Draw it", "Give it to him")),
    ]
}
