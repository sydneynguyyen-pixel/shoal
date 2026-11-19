import SwiftUI

struct Badge: View {
    var text: String
    var amber = false
    var body: some View {
        HStack(spacing: 5) {
            if amber { Stone(state: .urgent, w: .small, base: 16) }
            Text(text).font(.app(12.5, .semibold))
        }
        .foregroundStyle(amber ? Color(hex: 0x8a5d0c) : Color.sectionInk)
        .padding(.horizontal, 10).frame(height: 26)
        .background(amber ? Color(hex: 0xf6d27c, 0.32) : .white.opacity(0.75), in: .capsule)
        .overlay(Capsule().strokeBorder(.white))
    }
}

struct TaskView: View {
    @Environment(Store.self) private var store
    var id: String
    @State private var sizeSheet = false
    @State private var costs = false
    @State private var term: String?
    @State private var dateSheet = false

    @State var blink = false
    @State private var adding = false
    @State private var newStep = ""
    @State private var editingNote = false
    @State private var noteDraft = ""

    var body: some View {
        if let t = store.task(id) {
            let p = store.person(t.who)
            let stepsDone = t.steps.filter(\.done).count
            Page {
                // Title first, then one line: who, when, and whether it's urgent.
                HStack(alignment: .top, spacing: 12) {
                    Text(t.n).font(.title()).foregroundStyle(Color.navy)
                    Spacer(minLength: 8)
                    t.stone(base: 30).padding(.top, 6)
                        .opacity(blink ? 0.25 : 1).scaleEffect(blink ? 1.15 : 1)
                }
                HStack(spacing: 6) {
                    if let p { Avatar(p: p, size: 22) }
                    (Text("\(p?.name ?? "Unassigned") · \(t.done ? "Done" : t.kind == .once ? "Due \(fmtDate(t.date))" : repeatLabel(t.days))\(t.time.isEmpty ? "" : " · \(fmtTime(t.time))")")
                        .foregroundStyle(Color.muted)
                     + (t.urgent && !t.done ? Text(" · Urgent").foregroundStyle(Color.amber) : Text("")))
                        .font(.app(15))
                }
                .padding(.bottom, 8)

                if let h = t.handoff { handoffCard(t, h) }

                // Every task shows Steps and Notes, even when they're empty.
                Group {
                    VStack(alignment: .leading, spacing: 0) {
                        HStack { Text("Steps").font(.app(17, .semibold)).foregroundStyle(Color.ink); Spacer(); if !t.steps.isEmpty { Text("\(stepsDone) of \(t.steps.count) done").font(.app(15)).foregroundStyle(Color.muted) } }
                        if !t.steps.isEmpty {
                            Capsule().fill(Color(hex: 0x418ef3, 0.16)).frame(height: 6)
                                .overlay(alignment: .leading) { GeometryReader { g in Capsule().fill(Color.shoalBlue).frame(width: g.size.width * CGFloat(stepsDone) / CGFloat(t.steps.count)) } }
                                .padding(.top, 10).padding(.bottom, 4)
                        }
                        ForEach(Array(t.steps.enumerated()), id: \.element.id) { i, x in
                            if i > 0 { RowSep() }
                            HStack(spacing: 12) {
                                Button { withAnimation(.snappy) { store.toggleStep(id, i) } } label: { CheckBox(on: x.done).frame(width: 44, height: 44).contentShape(.rect) }
                                    .buttonStyle(.plain).padding(.horizontal, -10)
                                    .accessibilityLabel(x.done ? "Mark \(x.n) not done" : "Mark \(x.n) done")
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(x.n).font(.app(15.5, .semibold)).foregroundStyle(Color.ink)
                                    let line = stepLine(x, owner: t.who)
                                    if !line.isEmpty { Text(line).font(.app(15)).foregroundStyle(Color.muted) }
                                }
                                Spacer()
                                if let w = x.who, w != "you", w != t.who { Avatar(p: store.person(w), size: 22) }
                                else if x.who == nil && x.ask == nil {
                                    Menu {
                                        Button("I'll take it") { store.takeStep(id, i) }
                                        Button("Ask someone") { store.go(.handoff(id, step: i)) }
                                    } label: { Text("Take step").font(.app(13, .semibold)).foregroundStyle(Color.shoalBlue) }
                                }
                            }
                            .padding(.vertical, 8)
                        }
                        if !t.steps.isEmpty { RowSep() }
                        Button { newStep = ""; adding = true } label: {
                            Label("Add a step", systemImage: "plus").font(.app(15, .semibold)).foregroundStyle(Color.shoalBlue)
                                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading).contentShape(.rect)
                        }
                        .buttonStyle(.plain).padding(.top, 2)
                    }
                    .glassCard()
                }

                if t.cat == "meds" && t.n == "Comfort meds" { MedTaskCard(ids: ["morphine", "lorazepam"]) }
                if t.cat == "meds" && t.n == "Morning meds" { MedTaskCard(ids: ["metoprolol"]) }

                if t.notes.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Eyebrow(text: "Notes")
                        Button { noteDraft = ""; editingNote = true } label: {
                            Label("Add a note", systemImage: "plus").font(.app(15, .semibold)).foregroundStyle(Color.shoalBlue)
                                .frame(maxWidth: .infinity, minHeight: 36, alignment: .leading).contentShape(.rect)
                        }
                        .buttonStyle(.plain)
                    }
                    .glassCard()
                } else {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Eyebrow(text: "Notes")
                            Spacer()
                            Button("Edit") { noteDraft = t.notes; editingNote = true }.font(.app(14, .semibold)).foregroundStyle(Color.shoalBlue)
                        }
                        Text(glossed(t.notes)).font(.app(16)).foregroundStyle(Color.ink).lineSpacing(4).tint(Color.ink)
                            .environment(\.openURL, OpenURLAction { u in
                                if let k = u.host(), TERMS[k] != nil { term = k }
                                return .handled
                            })
                        Text("Added by you\(store.pebbleOn && hasTerm(t.notes) ? " · tap an underlined word to explain it" : "")").font(.app(13)).foregroundStyle(Color.muted)
                    }
                    .glassCard()
                }

                if store.pebbleOn && !t.done && (t.cat == "paper" || t.n.localizedCaseInsensitiveContains("pay")) {
                    HStack(spacing: 10) {
                        Image("pebble_research_glasses_focused").resizable().scaledToFit().frame(width: 44, height: 44)
                        PearlChip(label: "Find help paying") { costs = true }
                        Spacer()
                    }
                    .padding(.top, 4)
                }
            }
            .navigationTitle("").navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden()
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { store.back() } label: {
                        Image(systemName: "arrow.left").font(.system(size: 16, weight: .medium)).foregroundStyle(Color.ink)
                    }
                    .accessibilityLabel("Back")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button(t.kind == .once ? "Change due date" : "Change days", systemImage: "calendar") { dateSheet = true }
                        if store.kit == true {
                            if let s = store.stoneOf(id) {
                                Button("Find its stone", systemImage: "dot.radiowaves.left.and.right") { findStone(s.label) }
                            } else {
                                Button("Link a real stone", systemImage: "link") { store.go(.kit) }
                            }
                        }
                        Button("Change size · \(t.w.label)", systemImage: "circle.circle") { sizeSheet = true }
                        Button("Hand off", systemImage: "arrow.left.arrow.right") { store.go(.handoff(id, step: nil)) }
                    } label: {
                        Text("•••").font(.app(15, .semibold)).foregroundStyle(Color.muted).frame(width: 36, height: 36)
                    }
                    .accessibilityLabel("More")
                }
            }
            .sheet(item: Binding(get: { term.map { TermID(id: $0) } }, set: { term = $0?.id })) { k in TermSheet(key: k.id) }
            .sheet(isPresented: $dateSheet) { DateSheet(id: id) }
            .alert("Add a step", isPresented: $adding) {
                TextField("What needs doing", text: $newStep)
                Button("Cancel", role: .cancel) {}
                Button("Add") { withAnimation(.snappy) { store.addStep(id, newStep) } }
            }
            .alert(t.notes.isEmpty ? "Add a note" : "Edit note", isPresented: $editingNote) {
                TextField("Anything the family should know", text: $noteDraft, axis: .vertical)
                Button("Cancel", role: .cancel) {}
                Button("Save") { store.setNotes(id, noteDraft) }
            }
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 4) {
                    if t.done {
                        Button("Mark not done") { store.toggleDone(id) }.buttonStyle(PrimaryButton())
                    } else {
                        Button("Mark done") { withAnimation(.snappy) { store.toggleDone(id) } }.buttonStyle(PrimaryButton())
                        Button("Hand off") { store.go(.handoff(id, step: nil)) }
                            .font(.app(15.5, .semibold)).foregroundStyle(Color.shoalBlue).frame(maxWidth: .infinity).frame(height: 44)
                    }
                }
                .padding(.horizontal, 20).padding(.top, 10).padding(.bottom, 6)
                .background(LinearGradient(colors: [Color(hex: 0xf0f7ff, 0), Color(hex: 0xf0f7ff, 0.95)], startPoint: .top, endPoint: .center))
            }
            .sheet(isPresented: $sizeSheet) { SizeSheet(w: Binding(get: { t.w }, set: { v in if let i = store.idx(id) { store.tasks[i].w = v } })) }
            .sheet(isPresented: $costs) { CostsView().presentationDetents([.large]) }
        }
    }

    private func stoneLine(_ t: CareTask) -> String {
        switch t.state {
        case .urgent: "Stone glows yellow"
        case .progress: "Stone glows ice blue"
        case .open: "Stone glows white"
        case .done: "Done · stone resting"
        }
    }

    // Who it went to, and how it went. Everyone can see it.
    private func handoffCard(_ t: CareTask, _ h: Handoff) -> some View {
        let many = h.to.count > 1
        let to = store.person(h.who)
        let name = to?.name ?? "Someone"
        let title: String, sub: String
        switch h.status {
        case .pending:
            title = many ? (h.all ? "Asked everyone who can" : "Asked \(store.names(h.to))") : "Waiting on \(name)"
            sub = many ? "The first to say yes takes it. Everyone can see it's being handed off." : "Everyone can see it's being handed off."
        case .accepted:
            title = "\(name) said yes"
            sub = "\(h.when) · it's in \(name)'s jar now\(many ? ". The others were told it's covered." : "")"
        case .declined:
            title = "\(name) can't take it"
            sub = "“\(h.why)”"
        }
        return HStack(spacing: 12) {
            if h.pending && many {
                HStack(spacing: -10) { ForEach(h.to.prefix(3), id: \.self) { Avatar(p: store.person($0), size: 24) } }
            } else {
                Avatar(p: to, size: 36)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.app(15, .semibold)).foregroundStyle(Color.ink)
                Text(sub).font(.meta).foregroundStyle(Color.muted)
            }
            Spacer(minLength: 4)
            switch h.status {
            case .pending: Button("Cancel") { store.cancelHandoff(t.id) }.font(.app(14, .semibold)).foregroundStyle(Color.shoalBlue)
            case .declined: Button("Ask someone else") { store.go(.handoff(t.id, step: nil)) }
                .font(.app(13.5, .semibold)).foregroundStyle(Color.ink)
                .lineLimit(1).fixedSize()
                .padding(.horizontal, 12).frame(height: 32)
                .background(.white.opacity(0.85), in: .capsule).overlay(Capsule().strokeBorder(.white))
                .buttonStyle(Pressable())
            case .accepted: EmptyView()
            }
        }
        .glassCard(radius: 18, padding: 14)
    }

    // Steps that belong to the task's own person need no "is on it" line.
    private func stepLine(_ x: Step, owner: String?) -> String {
        if let ask = x.ask { return "Asked \(store.names(ask))" }
        guard let w = x.who else { return owner == nil ? "" : "Open" }
        if w == owner { return x.done ? (x.when ?? "") : "" }
        return x.done ? "\(store.name(w)) · \(x.when ?? "Today")" : "\(store.name(w)) is on it"
    }
}

struct SizeSheet: View {
    @Environment(Store.self) private var store
    @Binding var w: Weight
    var pick: Weight? = nil      // Pebble's guess, tagged so people can see it
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("How big is this task?").font(.title(26)).foregroundStyle(Color.navy)
            Text("Bigger tasks get bigger stones, so everyone can see who's carrying what.").font(.meta).foregroundStyle(Color.muted)
            VStack(spacing: 8) {
                ForEach(Weight.allCases) { x in
                    Button { w = x; dismiss() } label: {
                        HStack(spacing: 14) {
                            Stone(state: .open, w: x, base: 30).frame(width: 44)
                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 8) {
                                    Text(x.label).font(.app(15.5, .semibold)).foregroundStyle(Color.ink)
                                    if store.pebbleOn && pick == x {
                                        Text("Pebble's pick").font(.app(11.5, .semibold)).foregroundStyle(Color.shoalBlue)
                                            .padding(.horizontal, 7).padding(.vertical, 2).background(Color.blueTint, in: .rect(cornerRadius: 8))
                                    }
                                }
                                Text(x.hint).font(.meta).foregroundStyle(Color.muted)
                            }
                            Spacer()
                            if w == x { CheckDot() }
                        }
                        .padding(.horizontal, 14).frame(minHeight: 64)
                        .background(.white, in: .rect(cornerRadius: 16))
                        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(w == x ? Color.navy : Color(hex: 0x6e737c, 0.16), lineWidth: 1.5))
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(w == x ? .isSelected : [])
                }
            }
            .padding(.top, 2)
            if store.kit == true {
                Text("Your home kit has small, medium and large stones to match.").font(.meta).foregroundStyle(Color.muted).frame(maxWidth: .infinity)
            }
        }
        .padding(24)
        .presentationDetents([.height(store.kit == true ? 420 : 390)])
    }
}

// A filled blue circle with a tick, for the one picked option.
struct CheckDot: View {
    var body: some View {
        Circle().fill(Color.shoalBlue).frame(width: 24, height: 24)
            .overlay(Image(systemName: "checkmark").font(.system(size: 11, weight: .bold)).foregroundStyle(.white))
    }
}

// A square tick box, filled blue when done.
struct CheckBox: View {
    var on: Bool
    var body: some View {
        RoundedRectangle(cornerRadius: 6)
            .fill(on ? Color.shoalBlue : .white.opacity(0.8))
            .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(on ? .clear : Color(hex: 0xb7bcc4), lineWidth: 1.5))
            .overlay { if on { Image(systemName: "checkmark").font(.system(size: 12, weight: .bold)).foregroundStyle(.white) } }
            .frame(width: 24, height: 24)
    }
}

// Words Pebble can explain in plain language, with where the explanation comes from.
// Pebble explains words. It never says when or how much.
let TERMS: [String: (term: String, def: String, src: String, med: Bool)] = [
    "prn": ("PRN", "It means “as needed.” A PRN medicine isn't on a schedule. It's there if it's needed, for example if pain or breathing gets harder at night.", "MedlinePlus, U.S. National Library of Medicine", true),
    "hospice": ("Hospice", "Care that focuses on comfort and quality of life when a cure is no longer the goal. A team of nurses, aides, social workers and chaplains supports the person and the family, usually at home.", "MedlinePlus, U.S. National Library of Medicine", false),
    "palliative": ("Palliative care", "Care that eases symptoms and stress during a serious illness. It can happen alongside treatment, at any stage.", "MedlinePlus, U.S. National Library of Medicine", false),
    "respite": ("Respite care", "Short-term care that gives a family caregiver a break, for a few hours or a few days.", "National Institute on Aging", false),
    "polst": ("POLST", "A medical order, signed by a doctor and the patient, that says what treatments the person wants in an emergency. It travels with them.", "National POLST", false),
    "dnr": ("DNR", "Do-not-resuscitate order. It tells medical staff not to do CPR if breathing or the heart stops.", "MedlinePlus, U.S. National Library of Medicine", false),
    "ihss": ("IHSS", "In-Home Supportive Services, a California program that pays for help at home for people on Medi-Cal.", "California Department of Social Services", false),
]
private let TERM_RX = try! NSRegularExpression(pattern: "\\b(PRN|hospice|palliative care|palliative|respite care|respite|POLST|DNR|IHSS)\\b", options: .caseInsensitive)
struct TermID: Identifiable { let id: String }

func hasTerm(_ s: String) -> Bool { TERM_RX.firstMatch(in: s, range: NSRange(s.startIndex..., in: s)) != nil }

extension TaskView {
    // Known words become underlined links; matching is local, nothing reads the note.
    func glossed(_ s: String) -> AttributedString {
        var out = AttributedString(s)
        guard store.pebbleOn else { return out }
        for m in TERM_RX.matches(in: s, range: NSRange(s.startIndex..., in: s)).reversed() {
            guard let r = Range(m.range, in: s), let ar = Range(r, in: out) else { continue }
            let key = s[r].lowercased().split(separator: " ")[0]
            out[ar].link = URL(string: "term://\(key)")
            out[ar].underlineStyle = .single
            out[ar].underlineColor = UIColor(Color.shoalBlue)
        }
        return out
    }
}

struct TermSheet: View {
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss
    var key: String
    var body: some View {
        if let x = TERMS[key] {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    Image("pebble_think_01").resizable().scaledToFit().frame(width: 44, height: 44)
                    VStack(alignment: .leading, spacing: 2) {
                        Eyebrow(text: "In plain words")
                        Text(x.term).font(.title(24)).foregroundStyle(Color.navy)
                    }
                }
                Text(x.def).font(.app(16)).foregroundStyle(Color.ink).lineSpacing(3)
                Text("Source: \(x.src)").font(.app(13)).foregroundStyle(Color.muted)
                if x.med {
                    (Text("I can explain words. ") + Text("When and how much").font(.app(13, .semibold)) + Text(" is a question for \(LOVED)'s hospice nurse."))
                        .font(.app(13)).foregroundStyle(Color.muted).glassCard(radius: 16, padding: 12)
                }
                HStack(spacing: 10) {
                    if x.med {
                        Button("Ask the nurse") { dismiss(); store.say("Saved a question about \(x.term) for the nurse's next visit") }.buttonStyle(GhostButton())
                    }
                    Button("Got it") { dismiss() }.buttonStyle(GhostButton())
                }
                .padding(.top, 4)
            }
            .padding(24)
            .presentationDetents([.medium])
        }
    }
}

// Change a one-time task's due date, or an ongoing task's days.
struct DateSheet: View {
    @Environment(Store.self) private var store
    var id: String
    var body: some View {
        if let i = store.idx(id) {
            @Bindable var store = store
            WhenSheet(title: store.tasks[i].n, kind: $store.tasks[i].kind, days: $store.tasks[i].days,
                      date: $store.tasks[i].date, time: $store.tasks[i].time)
        }
    }
}

// When a task happens: repeats on some days, once by a date, or as needed. Same sheet as the web.
struct WhenSheet: View {
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss
    var title: String
    @Binding var kind: Kind
    @Binding var days: [String]
    @Binding var date: Date
    @Binding var time: String

    private enum How: String, CaseIterable { case repeating = "Repeats", once = "One time", needed = "As needed" }
    private var how: How { kind == .once ? .once : days.isEmpty ? .needed : .repeating }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text(title.isEmpty ? "New task" : title).font(.title(24)).foregroundStyle(Color.navy).padding(.bottom, 14)
                Picker("How", selection: Binding(get: { how }, set: { h in
                    if h == .once { kind = .once } else { kind = .repeating; days = h == .needed ? [] : days.isEmpty ? ["Sat"] : days }
                })) { ForEach(How.allCases, id: \.self) { Text($0.rawValue).tag($0) } }
                .pickerStyle(.segmented)

                switch how {
                case .once:
                    label("Due by")
                    HStack(spacing: 8) {
                        ForEach([("Today", addDays(0)), ("Tomorrow", addDays(1)), ("This week", byFriday())], id: \.0) { l, d in
                            chip(l, on: Calendar.current.isDate(date, inSameDayAs: d)) { date = d }
                        }
                    }
                    DatePicker("Due", selection: $date, in: TODAY..., displayedComponents: .date)
                        .datePickerStyle(.graphical).labelsHidden().tint(.shoalBlue)
                case .repeating:
                    HStack {
                        label("Which days?")
                        Button(days.count == 7 ? "Just one day" : "Every day") { days = days.count == 7 ? ["Mon"] : DAYS }
                            .font(.app(13, .semibold)).foregroundStyle(Color.shoalBlue).padding(.top, 16)
                    }
                    HStack(spacing: 6) {
                        ForEach(DAYS, id: \.self) { d in
                            let on = days.contains(d)
                            Button {
                                if !on { days.append(d) } else if days.count > 1 { days.removeAll { $0 == d } } else { store.say("Pick at least one day") }
                            } label: {
                                VStack(spacing: 1) {
                                    Text(String(d.prefix(1))).font(.app(15, .semibold))
                                    Text(d).font(.app(10, .medium)).foregroundStyle(on ? .white.opacity(0.8) : Color.muted)
                                }
                                .foregroundStyle(on ? .white : Color.ink)
                                .frame(maxWidth: .infinity).frame(height: 52)
                                .background(on ? Color.shoalBlue : .white.opacity(0.6), in: .rect(cornerRadius: 14))
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(DAY_FULL[d]!).accessibilityAddTraits(on ? .isSelected : [])
                        }
                    }
                    .padding(.top, 8)
                case .needed:
                    Text("It won't go on the calendar. Whoever has it does it when it comes up, like a doctor calling to book a visit.")
                        .font(.meta).foregroundStyle(Color.muted).padding(.top, 14)
                }

                if how != .needed {
                    (Text("Time ") + Text("Optional").font(.app(12)).foregroundStyle(Color.muted)).modifier(LabelStyle())
                    HStack(spacing: 8) {
                        chip("Any time", on: time.isEmpty) { time = "" }
                        DatePicker("Time", selection: Binding(get: { timeDate(time) }, set: { time = timeString($0) }), displayedComponents: .hourAndMinute)
                            .labelsHidden().tint(.shoalBlue)
                            .opacity(time.isEmpty ? 0.6 : 1)
                    }
                    .padding(.top, 8)
                }

                Button("Done") { dismiss() }.buttonStyle(PrimaryButton()).padding(.top, 20)
            }
            .padding(24)
        }
        .scrollBounceBehavior(.basedOnSize)
        .presentationDetents(how == .once ? [.large] : [.height(how == .needed ? 270 : 390)])
    }

    private func label(_ s: String) -> some View { Text(s).modifier(LabelStyle()) }
    private struct LabelStyle: ViewModifier {
        func body(content: Content) -> some View { content.font(.app(14, .semibold)).foregroundStyle(Color.sectionInk).padding(.top, 16) }
    }
    private func chip(_ l: String, on: Bool, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(l).font(.app(13.5, .semibold)).padding(.horizontal, 14).frame(height: 36)
                .foregroundStyle(on ? Color.shoalBlue : Color.ink)
                .background(on ? Color.blueTint : .white.opacity(0.9), in: .capsule)
                .overlay(Capsule().strokeBorder(on ? Color.shoalBlue.opacity(0.5) : Color(hex: 0xdde1e6)))
        }
        .buttonStyle(.plain).accessibilityAddTraits(on ? .isSelected : [])
    }
}

extension TaskView {
    // The stone on this page blinks while the real one does, as on the web.
    func findStone(_ label: String) {
        store.say("\(label) is blinking")
        Task {
            for _ in 0..<6 { withAnimation(.easeInOut(duration: 0.3)) { blink.toggle() }; try? await Task.sleep(for: .seconds(0.45)) }
            blink = false
        }
    }
}
