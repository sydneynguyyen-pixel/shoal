import SwiftUI

// What onboarding used to ask all at once, now done from Home in any order, one short sitting each.
struct SetupCard: View {
    @Environment(Store.self) private var store
    @State private var kitAsk = false

    var body: some View {
        if let setup = store.setup, !store.setupHidden {
            let n = store.setupCount, total = store.countedSteps.count
            if n == total && store.kit != nil {
                HStack(spacing: 12) {
                    Image(systemName: "checkmark.circle.fill").font(.system(size: 26)).foregroundStyle(Color.shoalBlue)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("You're all set up").font(.app(15.5, .semibold)).foregroundStyle(Color.ink)
                        Text("Change anything from My jar, People, or Settings.").font(.meta).foregroundStyle(Color.muted)
                    }
                    Spacer()
                    Button("Hide") { withAnimation(.snappy) { store.setupHidden = true } }.font(.app(14, .semibold))
                }
                .glassCard()
            } else {
                let next = store.shownSteps.first { !setup.contains($0.id) && ($0.needs == nil || setup.contains($0.needs!)) }
                VStack(alignment: .leading, spacing: 10) {
                    SectionH(text: "Finish setting up", trailing: "\(n) of \(total)")
                    VStack(alignment: .leading, spacing: 4) {
                        GeometryReader { g in
                            ZStack(alignment: .leading) {
                                Capsule().fill(Color(hex: 0xdfe8f3))
                                Capsule().fill(Color.shoalBlue).frame(width: max(8, g.size.width * CGFloat(n) / CGFloat(max(total, 1))))
                            }
                        }
                        .frame(height: 6).padding(.bottom, 6)
                        ForEach(store.shownSteps) { x in
                            let done = setup.contains(x.id), locked = x.needs != nil && !setup.contains(x.needs!)
                            Button { open(x, locked: locked) } label: {
                                HStack(spacing: 12) {
                                    ZStack {
                                        Circle().strokeBorder(done ? Color.shoalBlue : Color(hex: 0xc3cad4), lineWidth: 1.5)
                                        if done { Circle().fill(Color.shoalBlue); Image(systemName: "checkmark").font(.system(size: 11, weight: .bold)).foregroundStyle(.white) }
                                    }
                                    .frame(width: 24, height: 24)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(x.t).font(.app(15, .semibold)).foregroundStyle(locked ? Color.muted : Color.ink)
                                        Text(locked ? "Add tasks first" : done ? "Done · tap to change" : x.m).font(.app(12.5)).foregroundStyle(Color.muted)
                                            .multilineTextAlignment(.leading)
                                    }
                                    Spacer()
                                    if x.id == next?.id { Text("Next").font(.app(12, .semibold)).foregroundStyle(Color.shoalBlue) }
                                    Chevron()
                                }
                                .padding(.vertical, 7)
                                .opacity(locked ? 0.6 : 1)
                            }
                            .buttonStyle(Pressable())
                        }
                    }
                    .glassCard()
                }
                .sheet(isPresented: $kitAsk) { KitAskSheet().presentationDetents([.medium, .large]) }
            }
        }
    }

    private func open(_ x: SetupStep, locked: Bool) {
        if locked { store.say("Add what needs doing first"); return }
        if x.id == "stones" {
            if store.kit == true { store.kitSetup = true } else { kitAsk = true }
            return
        }
        store.go(.setup(x.id))
    }
}

// The kit is an add-on. Everything works in the app; the kit puts the jars on a shelf at home.
struct KitAskSheet: View {
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Do you have a Shoal kit?").font(.title(26)).foregroundStyle(Color.navy)
            Text("Shoal works fully in the app. The kit adds real jars and stones that glow at home, so the family can see the plan without picking up a phone.")
                .font(.body15).foregroundStyle(Color.muted)
            FamilyShelf(width: 70)
            Spacer(minLength: 0)
            Button("Yes, set it up") {
                store.kit = true
                dismiss()
                Task { try? await Task.sleep(for: .seconds(0.45)); store.kitSetup = true }
            }
            .buttonStyle(PrimaryButton())
            Button("Not now, just the app") {
                store.kit = false
                dismiss()
                store.say("Just the app. You can add a kit from Settings.")
            }
            .buttonStyle(GhostButton())
        }
        .padding(24)
        .background(AppBackground())
    }
}

// The main caregivers' jars on a shelf.
struct FamilyShelf: View {
    @Environment(Store.self) private var store
    var width: CGFloat = 70
    var lit: Double = 1
    var blink: String? = nil
    var only: String? = nil
    var names = true
    var dark = false
    var body: some View {
        let ppl = store.mainPeople.filter { only == nil || $0.id == only }
        let w = ppl.count > 4 ? width * 4 / CGFloat(ppl.count) : width
        VStack(spacing: 0) {
            HStack(alignment: .bottom, spacing: 8) {
                ForEach(ppl) { p in
                    VStack(spacing: 4) {
                        Jar(who: p.id, width: w, lit: lit, blink: blink)
                        if names { Text(p.name).font(.app(12.5, .semibold)).foregroundStyle(dark ? .white.opacity(0.85) : Color.ink) }
                    }
                }
            }
            RoundedRectangle(cornerRadius: 3).fill(dark ? Color.white.opacity(0.14) : Color(hex: 0xc9b79c, 0.45)).frame(height: 6)
                .padding(.horizontal, 4).padding(.top, names ? -22 : 0).offset(y: names ? 0 : -4)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Steps

struct SetupStepView: View {
    var id: String
    var body: some View {
        switch id {
        case "tasks": SetupTasksView()
        case "calendar": SetupCalendarView()
        case "schedule": SetupScheduleView()
        default: SetupSplitView()
        }
    }
}

// A screen with a footer button pinned at the bottom.
struct StepPage<Content: View>: View {
    var cta: String
    var enabled = true
    var action: () -> Void
    @ViewBuilder var content: Content
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) { content }
                .padding(.horizontal, 20).padding(.bottom, 24)
        }
        .background(AppBackground())
        .safeAreaInset(edge: .bottom) {
            Button(cta, action: action).buttonStyle(PrimaryButton(enabled: enabled)).disabled(!enabled)
                .padding(.horizontal, 20).padding(.vertical, 10)
                .background(.ultraThinMaterial.opacity(0.6))
        }
        .navigationBarTitleDisplayMode(.inline)
    }
}

// Starter tasks for each stage, picked with hospice nurses and doulas. A fixed list, so it works with Pebble off.
let STARTER: [String: [(String, Int, String)]] = [
    "start": [("Doctor appointments", 2, "drive"), ("Keep a list of meds and doses", 1, "paper"), ("Keep the care binder up to date", 1, "paper"),
              ("Insurance calls", 2, "phone"), ("Set up a meal train", 1, "phone"), ("Keep family updated", 1, "phone"), ("Safety check: rails, rugs, lights", 2, "there")],
    "daily": [("Refill prescriptions", 1, "meds"), ("Weekly grocery run", 2, "drive"), ("Rides to appointments", 2, "drive"),
              ("Visit and keep them company", 2, "there"), ("Give the main caregiver a night off", 3, "there"), ("Keep family updated", 1, "phone")],
    "final": [("Be there for hospice nurse visits", 2, "there"), ("Repositioning for comfort", 1, "there"), ("Record stories and memories", 2, "there"),
              ("Give the main caregiver a night off", 3, "there"), ("Overnight stays", 3, "there"), ("Keep family updated", 1, "phone"), ("Set up a meal train", 1, "phone")],
]

struct SetupTasksView: View {
    @Environment(Store.self) private var store
    @State private var picked: Set<String> = []
    @State private var own = ""

    var body: some View {
        let list = STARTER[store.careStage] ?? []
        let stage = CARE_STAGES.first { $0.id == store.careStage }!
        let added = Set(store.setupTasks.compactMap { store.task($0)?.n })
        StepPage(cta: picked.isEmpty ? "Done" : "Add \(plural(picked.count, "task"))", action: save) {
            Eyebrow(text: "Add what needs doing")
            Text("Tasks families often need").font(.title(28)).foregroundStyle(Color.navy)
            Text("For \(stage.s). Tap to leave any out. They start in the shared jar, and you choose who does what next.").font(.body15).foregroundStyle(Color.muted)
            VStack(spacing: 0) {
                ForEach(list, id: \.0) { t in
                    let on = picked.contains(t.0)
                    Button { if on { picked.remove(t.0) } else { picked.insert(t.0) } } label: {
                        HStack(spacing: 12) {
                            Stone(state: on ? .open : .done, w: Weight(rawValue: t.1)!, base: 26).frame(width: 36)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(t.0).font(.app(15, .semibold)).foregroundStyle(Color.ink).multilineTextAlignment(.leading)
                                Text(added.contains(t.0) ? "In the shared jar" : Weight(rawValue: t.1)!.label).font(.meta).foregroundStyle(Color.muted)
                            }
                            Spacer()
                            Image(systemName: on ? "checkmark.circle.fill" : "circle").font(.system(size: 22)).foregroundStyle(on ? Color.shoalBlue : Color(hex: 0xc3cad4))
                        }
                        .padding(.vertical, 9)
                    }
                    .buttonStyle(Pressable())
                    .accessibilityAddTraits(on ? .isSelected : [])
                    Divider()
                }
                HStack {
                    TextField("Add your own", text: $own).font(.body15).submitLabel(.done).onSubmit(addOwn)
                    Button("Add", action: addOwn).font(.app(14, .semibold)).disabled(own.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                .padding(.top, 10)
            }
            .glassCard()
        }
        .onAppear {
            picked = added.isEmpty ? Set(list.map(\.0)) : added
        }
    }

    private func addOwn() {
        let v = own.trimmingCharacters(in: .whitespaces)
        guard !v.isEmpty else { return }
        let t = CareTask(id: "s\(store.tasks.count)\(Int.random(in: 0..<999))", n: v, who: nil, w: .medium, cat: "there", kind: .once, date: addDays(5))
        store.tasks.append(t)
        store.setupTasks.append(t.id)
        picked.insert(v)
        own = ""
        store.say("Added “\(v)”")
    }

    private func save() {
        let list = STARTER[store.careStage] ?? []
        // Drop the ones left out, add the new ones.
        for id in store.setupTasks { if let t = store.task(id), !picked.contains(t.n) { store.tasks.removeAll { $0.id == id } } }
        store.setupTasks.removeAll { store.task($0) == nil }
        let have = Set(store.setupTasks.compactMap { store.task($0)?.n })
        for (i, t) in list.enumerated() where picked.contains(t.0) && !have.contains(t.0) {
            let task = CareTask(id: "s\(store.tasks.count)\(i)", n: t.0, who: nil, w: Weight(rawValue: t.1)!, cat: t.2, kind: .once, date: addDays(3 + i % 5))
            store.tasks.append(task)
            store.setupTasks.append(task.id)
        }
        if store.setupTasks.isEmpty { store.say("Pick at least one task"); return }
        store.setupDone("tasks")
    }
}

struct SetupCalendarView: View {
    @Environment(Store.self) private var store
    @State private var connecting: String?
    private let cals = [("Google Calendar", "Your Google account", "calendar"), ("Apple Calendar", "iCloud calendars on this phone", "applelogo"), ("Outlook", "Work or personal Microsoft account", "envelope")]

    var body: some View {
        StepPage(cta: "Done", enabled: !store.calendars.isEmpty, action: { store.setupDone("calendar") }) {
            Eyebrow(text: "Your calendar")
            Text("Bring in your calendar").font(.title(28)).foregroundStyle(Color.navy)
            Text("So tasks land on free time. Pick any you use.").font(.body15).foregroundStyle(Color.muted)
            VStack(spacing: 0) {
                ForEach(cals, id: \.0) { c in
                    let on = store.calendars.contains(c.0)
                    HStack(spacing: 12) {
                        Image(systemName: c.2).font(.system(size: 18)).foregroundStyle(Color.shoalBlue).frame(width: 40, height: 40).background(Color.blueTint, in: .rect(cornerRadius: 10))
                        VStack(alignment: .leading, spacing: 2) {
                            Text(c.0).font(.app(15, .semibold)).foregroundStyle(Color.ink)
                            Text(on ? "Connected · only busy times" : c.1).font(.meta).foregroundStyle(on ? Color.shoalBlue : Color.muted)
                        }
                        Spacer()
                        if connecting == c.0 { ProgressView().controlSize(.small) }
                        else if on { Image(systemName: "checkmark.circle.fill").font(.system(size: 22)).foregroundStyle(Color.shoalBlue) }
                        else {
                            Button("Connect") { connect(c.0) }.font(.app(14, .semibold))
                                .padding(.horizontal, 14).frame(height: 34).background(Color.blueTint, in: .capsule)
                        }
                    }
                    .padding(.vertical, 10)
                    if c.0 != cals.last?.0 { Divider() }
                }
            }
            .glassCard()
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "lock").foregroundStyle(Color.muted)
                Text("Shoal only sees when you're busy, never what your events are.").font(.app(13)).foregroundStyle(Color.muted)
            }
            .padding(.horizontal, 4)
        }
    }

    private func connect(_ n: String) {
        connecting = n
        Task {
            try? await Task.sleep(for: .seconds(1))
            store.calendars.insert(n)
            connecting = nil
            store.say("\(n) connected")
        }
    }
}

extension Store {
    // The tasks the checklist works on: the ones added in setup, or anything still open.
    var setupList: [String] {
        let ids = setupTasks.filter { task($0)?.done == false }
        return ids.isEmpty ? active.filter { $0.who == nil }.map(\.id) : ids
    }
}

struct SetupScheduleView: View {
    @Environment(Store.self) private var store

    var body: some View {
        StepPage(cta: "Done", action: { store.setupDone("schedule") }) {
            Eyebrow(text: "Schedule")
            Text("Put tasks on the calendar").font(.title(28)).foregroundStyle(Color.navy)
            Text("Pick a day for each, or make it weekly.\(store.calendars.isEmpty ? "" : " Busy times from your calendar are left alone.")").font(.body15).foregroundStyle(Color.muted)
            if store.pebbleOn {
                PearlChip(label: "Place them on free days") { spread() }
            }
            VStack(spacing: 0) {
                ForEach(store.setupList, id: \.self) { id in
                    if let t = store.task(id) { row(t); Divider() }
                }
            }
            .glassCard()
        }
    }

    private func row(_ t: CareTask) -> some View {
        HStack(spacing: 12) {
            t.stone(base: 26).frame(width: 36)
            VStack(alignment: .leading, spacing: 2) {
                Text(t.n).font(.app(15, .semibold)).foregroundStyle(Color.ink)
                Text(t.kind == .repeating ? repeatLabel(t.days) : fmtDate(t.date)).font(.meta).foregroundStyle(Color.muted)
            }
            Spacer()
            Menu {
                Section("One time") {
                    ForEach(1..<15, id: \.self) { d in
                        Button(fmtDate(addDays(d))) { set(t.id) { $0.kind = .once; $0.date = addDays(d) } }
                    }
                }
                Section("Every week") {
                    ForEach(DAYS, id: \.self) { d in
                        Button("Every \(DAY_FULL[d]!)") { set(t.id) { $0.kind = .repeating; $0.days = [d] } }
                    }
                }
            } label: {
                Text("Change").font(.app(14, .semibold)).padding(.horizontal, 12).frame(height: 32).background(Color.blueTint, in: .capsule)
            }
        }
        .padding(.vertical, 9)
    }

    private func set(_ id: String, _ f: (inout CareTask) -> Void) {
        guard let i = store.idx(id) else { return }
        withAnimation(.snappy) { f(&store.tasks[i]) }
    }

    // Lightest days first, so nobody's week piles up on one day.
    private func spread() {
        var count = (1...10).map { d in store.active.filter { $0.occurs(on: addDays(d)) }.count }
        for id in store.setupList {
            guard let i = store.idx(id), store.tasks[i].kind == .once else { continue }
            let d = count.indices.min { count[$0] < count[$1] }!
            store.tasks[i].date = addDays(d + 1)
            count[d] += 1
        }
        store.pebbleDid("Placed \(plural(store.setupList.count, "task")) on the lightest days")
        store.say("Pebble put them on the lightest days")
    }
}

struct SetupSplitView: View {
    @Environment(Store.self) private var store

    var body: some View {
        let ids = store.setupList
        StepPage(cta: "Send the plan", action: send) {
            Eyebrow(text: "Who does what")
            Text("Choose who does what").font(.title(28)).foregroundStyle(Color.navy)
            Text("Rings show how much room each person said they have. Anyone can trade later.").font(.body15).foregroundStyle(Color.muted)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(store.mainPeople) { p in
                        HStack(spacing: 6) {
                            Avatar(p: p, size: 22)
                            Text("\(p.name) \(store.load(p.id))/\(p.cap)h").font(.app(13, .semibold))
                                .foregroundStyle(store.room(p) < 0 ? Color.amber : Color.ink)
                        }
                        .padding(.horizontal, 10).frame(height: 32).background(.white.opacity(0.85), in: .capsule)
                    }
                }
            }
            if store.pebbleOn { PearlChip(label: "Suggest a fair split") { suggest() } }
            VStack(spacing: 0) {
                ForEach(ids, id: \.self) { id in
                    if let t = store.task(id) { row(t); Divider() }
                }
            }
            .glassCard()
        }
    }

    private func row(_ t: CareTask) -> some View {
        let ok = store.people.filter { store.canTake($0, t) }
        return HStack(spacing: 12) {
            t.stone(base: 26).frame(width: 36)
            VStack(alignment: .leading, spacing: 2) {
                Text(t.n).font(.app(15, .semibold)).foregroundStyle(Color.ink)
                Text("\(t.w.label) · about \(plural(t.w.hours, "hour"))").font(.meta).foregroundStyle(Color.muted)
            }
            Spacer()
            Menu {
                ForEach(ok) { p in Button(p.id == "you" ? "You" : p.name) { assign(t.id, p.id) } }
                Button("Leave it open") { assign(t.id, nil) }
            } label: {
                HStack(spacing: 6) {
                    if let p = store.person(t.who) { Avatar(p: p, size: 22) }
                    Text(t.who == nil ? "Open" : store.name(t.who)).font(.app(14, .semibold))
                    Image(systemName: "chevron.up.chevron.down").font(.system(size: 10, weight: .semibold))
                }
                .padding(.horizontal, 10).frame(height: 32).background(Color.blueTint, in: .capsule)
            }
        }
        .padding(.vertical, 9)
    }

    private func assign(_ id: String, _ who: String?) {
        guard let i = store.idx(id) else { return }
        withAnimation(.snappy) { store.tasks[i].who = who }
    }

    // Biggest tasks first, each to whoever has the most room left and can take it.
    private func suggest() {
        let ids = store.setupList.sorted { (store.task($0)?.w.rawValue ?? 0) > (store.task($1)?.w.rawValue ?? 0) }
        for id in ids { if let i = store.idx(id) { store.tasks[i].who = nil } }
        for id in ids {
            guard let i = store.idx(id) else { continue }
            let t = store.tasks[i]
            if let p = store.mainPeople.filter({ store.canTake($0, t) }).max(by: { store.room($0) < store.room($1) }) {
                withAnimation(.snappy) { store.tasks[i].who = p.id }
            }
        }
        store.pebbleDid("Suggested who does what for \(plural(ids.count, "task"))", how: "Balanced by size and free time")
        store.say("Pebble balanced it by size and free time")
    }

    private func send() {
        let open = store.setupList.filter { store.task($0)?.who == nil }.count
        store.setupDone("split")
        store.say(open > 0 ? "Plan sent. \(plural(open, "task")) left open for anyone." : "Plan sent. Everyone gets a link.")
    }
}
