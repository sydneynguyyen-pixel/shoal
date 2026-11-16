import SwiftUI
import Observation

enum Route: Hashable {
    case task(String)
    case handoff(String, step: Int?)
    case person(String)
    case newTask
    case care(nurse: Bool)
    case kit, stones, stone(Int), month
    case setup(String)
}

enum FirstStage: Int { case splash, signin, verify, intro, welcome, about, people, colors }
enum Glow: String, CaseIterable { case on, dim, off
    var lit: Double { self == .on ? 1 : self == .dim ? 0.45 : 0 }
}

// A real stone from the kit. It charges in a jar or on the base; one that's "out" is running down.
struct KitStone: Identifiable, Hashable {
    let id: Int
    var size: Weight
    var battery: Int
    var task: String?
    var out = false
    var label: String { String(format: "Stone %02d", id) }
}

func demoStones() -> [KitStone] {
    let batt = [92, 88, 100, 76, 95, 81, 22, 97, 64, 90, 85, 99, 73, 91, 87, 100, 68, 94, 79, 96, 83, 100, 71, 89, 93, 77, 98, 86, 66, 100, 84, 92, 75, 97, 88, 90]
    return (1...36).map { i in
        KitStone(id: i, size: i <= 12 ? .small : i <= 27 ? .medium : .large, battery: batt[i - 1], out: i == 7)
    }
}

// Everything Pebble changed, with how to undo it.
enum PebbleUndo: Hashable { case task(String), step(String, String), who(String, String?) }
struct PebbleEntry: Identifiable, Hashable {
    let id = UUID()
    var what: String
    var how: String = "You said yes"
    var undo: PebbleUndo?
    var undone = false
}

enum CheckIn: String { case fine, stretched, onBreak }

@MainActor @Observable
final class Store {
    var people: [Person] = DEMO_PEOPLE
    var tasks: [CareTask] = demoTasks()
    var pebbleOn = true
    var ringOn = true
    var checkIn: CheckIn?
    var heldOpen = false
    var thanked: Set<String> = []
    var dismissed: Set<String> = []
    var pebbleLog: [PebbleEntry] = []
    var toast: String?
    var day: Date = TODAY
    var requests: [Request] = [Request(id: "r1", from: "mom", n: "Call the pharmacy", note: "They'll only talk to the main contact.")]
    var toldFamily = false
    var handPick: String?   // Pebble's pick, made before Hand off opens

    // Dad's care page. Locked for primary caregivers, relocks after 5 minutes.
    var meds: [Med] = demoMeds()
    var doses: [Dose] = demoDoses()
    var careKey: [CareNote] = demoKey()
    var needs: [CareNote] = demoNeeds()
    var prefs: [CareNote] = demoPrefs()
    var careUnlockedAt: Date?
    var pin = "1234"

    // First open: splash, sign in, intro, then three onboarding steps.
    var onboarded = false
    var first: FirstStage = .splash
    var phone = ""
    var lovedName = LOVED
    var careStage = "final"
    var conditions: Set<String> = []
    var colors = StoneColors.shoal
    // The Home checklist. nil when onboarding was skipped.
    var setup: Set<String>?
    var setupHidden = false
    var setupTasks: [String] = []
    var calendars: Set<String> = []
    var monthSkipped = false

    // The Shoal kit. nil until the family says whether they have one.
    var kit: Bool?
    var stones: [KitStone] = demoStones()
    var glow: Glow = .on
    var night = true
    var nightFrom = 21
    var nightTo = 7
    var kitSetup = false

    // One navigation path per tab, so each tab keeps its place.
    var tab = 0
    var paths: [[Route]] = [[], [], [], [], []]

    func go(_ r: Route) { paths[tab].append(r) }
    func back() { if !paths[tab].isEmpty { paths[tab].removeLast() } }

    func say(_ s: String) {
        withAnimation(.snappy) { toast = s }
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(2.6))
            if toast == s { withAnimation(.snappy) { toast = nil } }
        }
    }

    func reset() {
        LOVED = "Dad"
        people = DEMO_PEOPLE; tasks = demoTasks(); checkIn = nil; heldOpen = false
        thanked = []; dismissed = []; pebbleLog = []; toldFamily = false
        requests = [Request(id: "r1", from: "mom", n: "Call the pharmacy", note: "They'll only talk to the main contact.")]
        paths = [[], [], [], [], []]; tab = 0; day = TODAY
        meds = demoMeds(); doses = demoDoses(); careKey = demoKey(); needs = demoNeeds(); prefs = demoPrefs()
        careUnlockedAt = nil; pin = "1234"
        onboarded = false; first = .splash; phone = ""; lovedName = "Dad"; careStage = "final"; conditions = []
        colors = .shoal; setup = nil; setupHidden = false; setupTasks = []; calendars = []; monthSkipped = false
        kit = nil; stones = demoStones(); glow = .on; night = true; nightFrom = 21; nightTo = 7; kitSetup = false
        syncWidgets()
    }

    // MARK: lookups

    func person(_ id: String?) -> Person? { people.first { $0.id == id } }
    func name(_ id: String?) -> String { person(id)?.name ?? "Unassigned" }
    func task(_ id: String) -> CareTask? { tasks.first { $0.id == id } }
    func idx(_ id: String) -> Int? { tasks.firstIndex { $0.id == id } }
    func mine(_ id: String) -> [CareTask] { tasks.filter { $0.who == id } }
    var active: [CareTask] { tasks.filter { !$0.done } }
    var mainPeople: [Person] { people.filter { $0.tier == .main } }

    func load(_ id: String) -> Int { mine(id).filter { !$0.done }.reduce(0) { $0 + $1.w.hours } }
    func room(_ p: Person) -> Int { p.cap - load(p.id) }

    // Who a task is open to. Small tasks reach the trusted circle; kids only if marked.
    func openTo(_ t: CareTask) -> [Tier] { t.open ?? (t.w == .small ? [.main, .trusted] : [.main]) }
    func canTake(_ p: Person, _ t: CareTask) -> Bool {
        guard openTo(t).contains(p.tier) else { return false }
        let near = !t.remote && ["drive", "there", "cook"].contains(t.cat)
        return !(near && p.remote)
    }

    // MARK: Pebble

    func pebblePick(_ t: CareTask) -> (p: Person, why: String)? {
        guard pebbleOn else { return nil }
        let near = !t.remote && ["drive", "there", "cook"].contains(t.cat)
        let ok = people.filter { $0.id != "you" && $0.id != t.who && canTake($0, t) && room($0) >= t.w.hours }
        guard let p = ok.max(by: { room($0) < room($1) }) else { return nil }
        return (p, "\(plural(room(p), "hour")) of room this week\(near && !p.remote ? ", and close by" : "")")
    }

    func pebbleNote(_ t: CareTask, step: String? = nil) -> String {
        let due = t.kind == .once ? t.dueLabel : repeatLabel(t.days).lowercased()
        let minutes = ["20 minutes", "an hour or so", "a few hours"][t.w.rawValue - 1]
        if let step { return "Could you take “\(step.lowercased())” for “\(t.n)”? It's \(due). Thank you!" }
        return "Could you take this one? It's \(due) and takes about \(minutes). Thank you!"
    }

    var stretchedSuggestion: (task: CareTask, p: Person)? {
        guard pebbleOn else { return nil }
        for t in mine("you").filter({ !$0.done && !$0.urgent }) {
            if let x = pebblePick(t) { return (t, x.p) }
        }
        return nil
    }

    // Opens Hand off with Pebble's pick already made.
    func pebbleHandoff(_ id: String, step: Int? = nil) {
        if let t = task(id) { handPick = pebblePick(t)?.p.id }
        go(.handoff(id, step: step))
    }

    // MARK: actions

    func toggleDone(_ id: String) {
        guard let i = idx(id) else { return }
        tasks[i].done.toggle()
        tasks[i].doneAt = tasks[i].done ? "Just now" : nil
        say(tasks[i].done ? "Nice. That stone goes dim." : "Back on the list.")
    }

    func take(_ id: String) {
        guard let i = idx(id) else { return }
        tasks[i].who = "you"
        say("It's yours now.")
    }

    func toggleStep(_ id: String, _ s: Int) {
        guard let i = idx(id), tasks[i].steps.indices.contains(s) else { return }
        tasks[i].steps[s].done.toggle()
    }

    func takeStep(_ id: String, _ s: Int) {
        guard let i = idx(id), tasks[i].steps.indices.contains(s) else { return }
        tasks[i].steps[s].who = "you"
    }

    func sendHandoff(_ id: String, to: [String], note: String, step: Int?, byPebble: Bool) {
        guard let i = idx(id) else { return }
        let names = to.map { name($0) }.joined(separator: ", ")
        if byPebble { pebbleDid("Wrote the note to \(names) for “\(tasks[i].n)”", how: "You checked it and sent it") }
        if let s = step, tasks[i].steps.indices.contains(s) {
            tasks[i].steps[s].ask = to.first
            let taker = to.first
            say("Asked \(names)")
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(4))
                if let j = idx(id), tasks[j].steps.indices.contains(s) {
                    tasks[j].steps[s].who = taker
                    tasks[j].steps[s].ask = nil
                    say("\(name(taker)) took “\(tasks[j].steps[s].n.lowercased())”")
                }
            }
        } else {
            tasks[i].handoff = Handoff(to: to, note: note)
            say(to.count > 1 ? "Asked \(to.count) people. First to say yes takes it." : "Asked \(names)")
            let taker = to.first
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(4))
                if let j = idx(id), tasks[j].handoff != nil {
                    tasks[j].who = taker
                    tasks[j].handoff?.pending = false
                    say("\(name(taker)) said yes to “\(tasks[j].n)”")
                }
            }
        }
    }

    func answer(_ r: Request, yes: Bool) {
        requests.removeAll { $0.id == r.id }
        if yes {
            tasks.append(CareTask(id: "r\(tasks.count)", n: r.n, who: "you", w: .small, cat: "phone", kind: .once, date: addDays(1), notes: r.note))
            say("It's in your jar. \(name(r.from)) will see you took it.")
        } else {
            say("\(name(r.from)) will find someone else.")
        }
    }

    func addTask(_ t: CareTask) {
        tasks.append(t)
        say(t.who == nil ? "Added. Anyone it's open to can take it." : "Added to \(t.who == "you" ? "your" : name(t.who) + "'s") jar.")
    }

    func move(_ id: String, to who: String) {
        guard let i = idx(id) else { return }
        let from = tasks[i].who
        tasks[i].who = who
        say("Moved from \(name(from)) to \(name(who))")
    }

    // MARK: Pebble log

    func pebbleDid(_ what: String, how: String = "You said yes", undo: PebbleUndo? = nil) {
        pebbleLog.insert(PebbleEntry(what: what, how: how, undo: undo), at: 0)
    }

    func undoPebble(_ e: PebbleEntry) {
        guard let k = pebbleLog.firstIndex(where: { $0.id == e.id }) else { return }
        switch e.undo {
        case .task(let id): tasks.removeAll { $0.id == id }; for j in stones.indices where stones[j].task == id { stones[j].task = nil }
        case .step(let id, let n): if let i = idx(id) { tasks[i].steps.removeAll { $0.n == n } }
        case .who(let id, let who): if let i = idx(id) { tasks[i].who = who }
        case nil: break
        }
        pebbleLog[k].undone = true
        say("Undone")
    }

    // MARK: Setup checklist

    func setupDone(_ id: String) {
        setup?.insert(id)
        paths[tab] = []
        let n = setupCount, total = countedSteps.count
        say(n == total ? "All set up" : "\(n) of \(total) done")
    }
    var countedSteps: [SetupStep] { SETUP_STEPS.filter { !$0.optional || kit == true } }
    var shownSteps: [SetupStep] { SETUP_STEPS.filter { !$0.optional || kit != false } }
    var setupCount: Int { countedSteps.filter { setup?.contains($0.id) == true }.count }

    // MARK: Kit

    func stoneOf(_ taskId: String) -> KitStone? { stones.first { $0.task == taskId } }
    // A task gets a free stone its own size, or the closest size left.
    func freeStone(_ w: Weight) -> KitStone? {
        stones.filter { $0.task == nil && !$0.out }.min { abs($0.size.rawValue - w.rawValue) < abs($1.size.rawValue - w.rawValue) }
    }
    @discardableResult func pair(_ taskId: String) -> KitStone? {
        guard stoneOf(taskId) == nil, let t = task(taskId), let s = freeStone(t.w), let j = stones.firstIndex(of: s) else { return stoneOf(taskId) }
        stones[j].task = taskId
        return stones[j]
    }
    func inJar(_ s: KitStone) -> Bool { guard let t = s.task.flatMap(task), let w = t.who else { return false }; return person(w)?.tier == .main }
    func place(_ s: KitStone) -> String {
        if s.out { return "\(s.task == nil ? "Off the base" : "Out of its jar") · not charging" }
        if inJar(s), let t = s.task.flatMap(task) { return "In \(t.who == "you" ? "your" : name(t.who) + "'s") jar · charging" }
        return "On the base · charging"
    }
    var spares: [KitStone] { stones.filter { !$0.out && !inJar($0) } }

    // MARK: Monthly check-in

    // Patterns are raised once a month, with everyone, never as a nudge to one person.
    var monthNotes: [(st: StoneState, n: String, m: String)] {
        var out: [(StoneState, String, String)] = []
        for p in mainPeople where room(p) < 0 {
            out.append((.urgent, "\(p.name) is carrying more than the room they set", "About \(load(p.id)) hours a week · their rings say about \(p.cap)"))
        }
        let open = active.filter { $0.who == nil }
        if !open.isEmpty { out.append((.open, "\(plural(open.count, "task")) still \(open.count == 1 ? "has" : "have") no one", "They glow \(colors.name(.open)) in the shared jar")) }
        let late = active.filter { $0.kind == .once && daysFromToday($0.date) < 0 }
        out.append(late.isEmpty ? (.progress, "Nothing slipped past its date", "Everyone kept the plan going")
                                : (.urgent, "\(plural(late.count, "task")) ran past \(late.count == 1 ? "its" : "their") date", "Worth a look together"))
        return out
    }

    // One move that evens things out: from whoever is most over their room to whoever has the most.
    var monthMove: (t: CareTask, from: Person, to: Person)? {
        guard let from = mainPeople.filter({ room($0) < 0 }).min(by: { room($0) < room($1) }) else { return nil }
        let tos = mainPeople.filter { $0.id != from.id && room($0) > 0 }.sorted { room($0) > room($1) }
        for t in mine(from.id).filter({ !$0.done && !$0.urgent }).sorted(by: { $0.w.rawValue < $1.w.rawValue }) {
            for p in tos where room(p) >= t.w.hours && canTake(p, t) && (!p.remote || t.remote) { return (t, from, p) }
        }
        return nil
    }
}

struct SetupStep: Identifiable { let id: String; let t: String; let m: String; var needs: String? = nil; var optional = false }
let SETUP_STEPS = [
    SetupStep(id: "tasks", t: "Add what needs doing", m: "About 5 min"),
    SetupStep(id: "calendar", t: "Bring in your calendar", m: "About 1 min · so tasks land on free time"),
    SetupStep(id: "schedule", t: "Put tasks on the calendar", m: "About 3 min", needs: "tasks"),
    SetupStep(id: "split", t: "Choose who does what", m: "About 3 min · then send the plan", needs: "tasks"),
    SetupStep(id: "stones", t: "Connect a Shoal kit", m: "Optional · real jars and glowing stones at home", needs: "tasks", optional: true),
]
