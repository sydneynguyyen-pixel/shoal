import SwiftUI
import LocalAuthentication

// Dad's care page. Primary caregivers unlock it with Face ID or a PIN.
// Ana, the hospice nurse, gets a view-only page with meds, allergies and wishes.
struct CareView: View {
    @Environment(Store.self) private var store
    var nurse = false

    var body: some View {
        Group {
            if nurse || (store.careUnlocked && !store.pinSetting) { CarePage(nurse: nurse) } else { CareLockView() }
        }
        .navigationTitle("").navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if nurse {
                    Text("View only").font(.app(12.5, .semibold)).foregroundStyle(Color.navy)
                        .padding(.horizontal, 10).frame(height: 26).background(Color.navy.opacity(0.07), in: .capsule)
                } else if store.careUnlocked && !store.pinSetting {
                    Button { withAnimation(.snappy) { store.lockCare() } } label: {
                        HStack(spacing: 5) {
                            Image(systemName: "lock").font(.system(size: 12, weight: .semibold))
                            Text("Lock").font(.app(13, .semibold))
                        }
                        .foregroundStyle(Color.shoalBlue).padding(.horizontal, 12).frame(height: 30)
                        .background(Color.blueTint, in: .capsule).fixedSize()
                    }
                    .buttonStyle(Pressable())
                }
            }
            .sharedBackgroundVisibility(.hidden)
        }
    }
}

// Sheets cover the app's toast, so sheets that toast show it themselves.
struct SheetToast: ViewModifier {
    @Environment(Store.self) private var store
    func body(content: Content) -> some View {
        content.overlay(alignment: .top) { if let t = store.toast { ToastView(text: t).padding(.top, 8) } }
            .onAppear { store.sheetToasts += 1 }
            .onDisappear { store.sheetToasts -= 1 }
    }
}

// MARK: - Lock

struct CareLockView: View {
    @Environment(Store.self) private var store
    @State private var entry = ""
    @State private var msg: String?
    @State private var shake: CGFloat = 0

    var body: some View {
        let setting = store.pinSetting
        VStack(spacing: 0) {
            Image(systemName: "lock").font(.system(size: 24, weight: .semibold)).foregroundStyle(Color.shoalBlue)
                .frame(width: 56, height: 56).background(Color.blueTint, in: .circle)
            Text(setting ? "New PIN" : "\(LOVED)'s care").font(.title()).foregroundStyle(Color.navy).padding(.top, 14)
            Text("Primary caregivers only").font(.body15).foregroundStyle(Color.muted).padding(.top, 4)

            VStack(spacing: 0) {
                Text(msg ?? (setting ? "Choose a 4-digit PIN" : "Enter your PIN"))
                    .font(.app(14, .semibold)).foregroundStyle(Color.navy).contentTransition(.opacity)
                HStack(spacing: 16) {
                    ForEach(0..<4, id: \.self) { i in
                        Circle().fill(i < entry.count ? Color.navy : .clear)
                            .overlay(Circle().strokeBorder(Color.navy, lineWidth: 1.5))
                            .frame(width: 13, height: 13)
                    }
                }
                .padding(.top, 14).padding(.bottom, 22)
                .accessibilityElement().accessibilityLabel("\(entry.count) of 4 digits entered")
                let keys = ["1", "2", "3", "4", "5", "6", "7", "8", "9", "face", "0", "del"]
                LazyVGrid(columns: Array(repeating: GridItem(.fixed(72), spacing: 24), count: 3), spacing: 14) {
                    ForEach(keys, id: \.self) { k in key(k) }
                }
            }
            .padding(.top, 26)
            .offset(x: shake)
            Spacer()
        }
        .padding(.top, 24)
        .frame(maxWidth: .infinity)
        .background(AppBackground())
    }

    @ViewBuilder private func key(_ k: String) -> some View {
        switch k {
        case "face":
            Button { faceID() } label: {
                Image(systemName: "faceid").font(.system(size: 28)).foregroundStyle(Color.shoalBlue).frame(width: 72, height: 72)
            }
            .buttonStyle(Pressable()).accessibilityLabel("Unlock with Face ID")
        case "del":
            Button { if !entry.isEmpty { entry.removeLast() } } label: {
                Image(systemName: "delete.left").font(.system(size: 22)).foregroundStyle(Color.navy).frame(width: 72, height: 72)
            }
            .buttonStyle(Pressable()).accessibilityLabel("Delete")
        default:
            Button { press(k) } label: {
                Text(k).font(.app(28, .regular)).foregroundStyle(Color.navy)
                    .frame(width: 72, height: 72).background(.white.opacity(0.7), in: .circle)
                    .overlay(Circle().strokeBorder(.white))
                    .shadow(color: Color(hex: 0x13315d, 0.08), radius: 8, y: 4)
            }
            .buttonStyle(Pressable())
        }
    }

    private func press(_ k: String) {
        guard entry.count < 4 else { return }
        entry += k
        guard entry.count == 4 else { return }
        let v = entry
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(200))
            if store.pinSetting {
                store.pin = v; store.pinSetting = false
                withAnimation(.snappy) { store.unlockCare(face: false) }
                store.say("PIN saved. Share it only with the primary caregivers.")
            } else if v == store.pin {
                withAnimation(.snappy) { store.unlockCare(face: false) }
            } else {
                withAnimation(.snappy) { msg = "That's not it. Try again." }
                for x in [-8.0, 8, -8, 8, 0] {
                    withAnimation(.linear(duration: 0.07)) { shake = x }
                    try? await Task.sleep(for: .milliseconds(70))
                }
                entry = ""
            }
        }
    }

    // Real Face ID when the phone has it set up. The simulator usually doesn't, so it acts it out.
    private func faceID() {
        let ctx = LAContext()
        var err: NSError?
        if ctx.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &err) {
            Task { @MainActor in
                if (try? await ctx.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: "Open \(LOVED)'s care page")) == true {
                    store.pinSetting = false
                    withAnimation(.snappy) { store.unlockCare(face: true) }
                }
            }
        } else {
            withAnimation(.snappy) { msg = "Looking for your face…" }
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(0.7))
                store.pinSetting = false
                withAnimation(.snappy) { msg = nil; store.unlockCare(face: true) }
            }
        }
    }
}

// MARK: - Unlocked page

struct CarePage: View {
    @Environment(Store.self) private var store
    var nurse: Bool
    @State private var dose: Med?
    @State private var showLog = false
    @State private var edit: NoteEdit?
    @State private var addMed = false

    private let grid = [GridItem(.flexible(), spacing: 12), GridItem(.flexible())]

    var body: some View {
        TimelineView(.periodic(from: .now, by: 30)) { _ in
            Page {
                Text("\(LOVED)'s care").font(.title()).foregroundStyle(Color.navy)

                ForEach(store.careKey.filter(\.alert)) { a in
                    if nurse { alertStrip(a) } else {
                        Button { edit = NoteEdit(note: a, s: .key, new: false) } label: { alertStrip(a) }.buttonStyle(Pressable())
                    }
                }

                head("Medications", log: !store.doses.isEmpty, plus: "Add a medication") { addMed = true }
                let prn = store.meds.filter(\.prn), daily = store.meds.filter { !$0.prn }
                if !prn.isEmpty {
                    LazyVGrid(columns: grid, spacing: 12) {
                        ForEach(prn) { m in
                            if nurse { MedTile(m: m) } else {
                                Button { dose = m } label: { MedTile(m: m) }.buttonStyle(Pressable())
                            }
                        }
                    }
                }
                if !daily.isEmpty {
                    VStack(alignment: .leading, spacing: 0) {
                        Text("Every day").font(.app(14, .semibold)).foregroundStyle(Color.ink).frame(minHeight: 34)
                        ForEach(daily) { m in
                            if m.id != daily.first?.id { Divider() }
                            if nurse { DailyRow(m: m) } else {
                                Button { dose = m } label: { DailyRow(m: m) }.buttonStyle(Pressable())
                            }
                        }
                    }
                    .homeTile()
                }
                if store.meds.isEmpty { empty("No medications yet.") }

                let keys = store.careKey.filter { !$0.alert }
                if !keys.isEmpty || !nurse { notes("Most important", keys, .key) }
                if !nurse {
                    notes("Needs", store.needs, .needs)
                    notes("Preferences", store.prefs, .prefs)
                }
            }
        }
        .sheet(item: $dose) { m in DoseSheet(m: m) }
        .sheet(isPresented: $showLog) { DoseLogSheet(nurse: nurse) }
        .sheet(item: $edit) { e in NoteSheet(note: e.note, s: e.s, new: e.new) }
        .sheet(isPresented: $addMed) { AddMedSheet() }
    }

    private func alertStrip(_ a: CareNote) -> some View {
        HStack(spacing: 10) {
            Text("!").font(.app(13, .heavy)).foregroundStyle(.white)
                .frame(width: 20, height: 20).background(Color(hex: 0xd4553a), in: .circle)
            (Text(a.t).bold() + Text("  ") + Text(nurse ? a.body : a.summary))
                .font(.app(14.5)).foregroundStyle(Color(hex: 0x8f2f19)).multilineTextAlignment(.leading)
            Spacer(minLength: 0)
            if !nurse { Chevron() }
        }
        .padding(.horizontal, 14).padding(.vertical, 12)
        .background(Color(hex: 0xd4553a, 0.1), in: .rect(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(Color(hex: 0xd4553a, 0.18)))
        .padding(.top, 2)
        .accessibilityElement(children: .combine)
    }

    // Section title with Log and + on the right.
    private func head(_ title: String, log: Bool = false, plus: String, add: @escaping () -> Void) -> some View {
        HStack(spacing: 12) {
            Text(title).font(.app(14, .semibold)).foregroundStyle(Color.sectionInk)
            Spacer()
            if log { Button("Log") { showLog = true }.font(.app(14, .semibold)).foregroundStyle(Color.shoalBlue) }
            if !nurse {
                Button(action: add) {
                    Image(systemName: "plus").font(.system(size: 14, weight: .semibold)).foregroundStyle(Color.shoalBlue)
                        .frame(width: 28, height: 28).background(Color.blueTint, in: .circle)
                }
                .buttonStyle(Pressable()).accessibilityLabel(plus)
            }
        }
        .frame(minHeight: 28)
        .padding(.horizontal, 4).padding(.top, 18).padding(.bottom, 2)
    }

    private func empty(_ s: String) -> some View {
        Text(s).font(.meta).foregroundStyle(Color.muted).padding(.horizontal, 4)
    }

    @ViewBuilder private func notes(_ title: String, _ list: [CareNote], _ s: CareSection) -> some View {
        head(title, plus: title == "Most important" ? "Add something important" : "Add to \(title.lowercased())") {
            edit = NoteEdit(note: CareNote(t: "", body: "", by: "you", on: "Just now"), s: s, new: true)
        }
        if list.isEmpty { empty("Nothing yet.") } else {
            LazyVGrid(columns: grid, alignment: .leading, spacing: 12) {
                ForEach(list) { n in
                    if nurse { NoteTile(n: n, full: true) } else {
                        Button { edit = NoteEdit(note: n, s: s, new: false) } label: { NoteTile(n: n) }.buttonStyle(Pressable())
                    }
                }
            }
        }
    }
}

struct NoteEdit: Identifiable {
    var note: CareNote
    var s: CareSection
    var new: Bool
    var id: UUID { note.id }
}

private let okTeal = Color(hex: 0x3f9b8c), okInk = Color(hex: 0x24665b), waitAmber = Color(hex: 0xe0a03a)

// As-needed meds: the ring fills until the next dose is okay.
struct MedTile: View {
    @Environment(Store.self) private var store
    var m: Med
    var body: some View {
        let last = store.lastDose(m.id)
        let ok = store.okAt(m)
        let f = last.map { min(1, Date().timeIntervalSince($0.at) / (Double(m.every) * 3600)) } ?? 1
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Text(m.name).font(.app(14, .semibold)).foregroundStyle(Color.ink).lineLimit(1)
                Spacer(minLength: 4)
                Text(m.amt).font(.app(13, .semibold)).foregroundStyle(Color.muted).lineLimit(1)
            }
            Spacer(minLength: 12)
            HStack(spacing: 10) {
                KitRing(f: f, size: 46, line: 4, tint: ok == nil ? okTeal : waitAmber)
                VStack(alignment: .leading, spacing: 3) {
                    Text(ok == nil ? "Okay" : "Okay after").font(.app(12, .semibold)).foregroundStyle(Color.muted)
                    if let ok {
                        let parts = clock(ok).split(whereSeparator: \.isWhitespace)
                        HStack(alignment: .firstTextBaseline, spacing: 3) {
                            Text(parts.first.map(String.init) ?? "").font(.app(28, .semibold)).tracking(-0.5).monospacedDigit().foregroundStyle(Color.ink)
                            Text(parts.dropFirst().joined(separator: " ")).font(.app(14, .semibold)).foregroundStyle(Color.muted)
                        }
                    } else {
                        Text("Now").font(.app(28, .semibold)).tracking(-0.5).foregroundStyle(okInk)
                    }
                }
                .lineLimit(1).minimumScaleFactor(0.7)
            }
            Spacer(minLength: 10)
            Text(last.map { "\($0.by == "you" ? "You" : store.name($0.by)) · \(ago($0.at))" } ?? "Not given yet")
                .font(.app(12.5)).foregroundStyle(Color.muted).lineLimit(1).minimumScaleFactor(0.8)
        }
        .frame(minHeight: 118)
        .homeTile()
        .accessibilityElement(children: .combine)
    }
}

// Daily meds: a check when given today.
struct DailyRow: View {
    @Environment(Store.self) private var store
    var m: Med
    var body: some View {
        let given = store.givenToday(m)
        HStack(spacing: 12) {
            ZStack {
                if given != nil {
                    Circle().fill(okTeal)
                    Image(systemName: "checkmark").font(.system(size: 11, weight: .heavy)).foregroundStyle(.white)
                } else {
                    Circle().strokeBorder(Color.navy.opacity(0.25), lineWidth: 1.6)
                }
            }
            .frame(width: 24, height: 24)
            (Text(m.name).font(.app(15, .semibold)).foregroundStyle(Color.ink)
             + Text("  \(m.amt)").font(.app(13, .medium)).foregroundStyle(Color.muted))
                .multilineTextAlignment(.leading)
            Spacer()
            Text(given.map { clock($0.at) } ?? m.time).font(.app(13.5, .semibold)).monospacedDigit()
                .foregroundStyle(given != nil ? okInk : Color.muted)
        }
        .frame(minHeight: 48)
        .contentShape(.rect)
        .accessibilityElement(children: .combine)
    }
}

// Needs and preferences: an icon, the title and a short summary. Ana's view shows the whole note.
struct NoteTile: View {
    var n: CareNote
    var full = false
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Image(systemName: n.icon).font(.system(size: 15, weight: .medium)).foregroundStyle(Color.shoalBlue)
                .frame(width: 32, height: 32).background(Color.blueTint, in: .rect(cornerRadius: 11))
            Spacer(minLength: 14)
            Text(n.t).font(.app(13, .semibold)).foregroundStyle(Color.muted)
            Text(full ? n.body : n.summary).font(.app(full ? 14 : 15, full ? .medium : .semibold)).foregroundStyle(Color.ink)
                .lineLimit(full ? 6 : 2).multilineTextAlignment(.leading).padding(.top, 2)
        }
        .frame(minHeight: 86, alignment: .topLeading)
        .homeTile()
    }
}

// MARK: - Logging a dose

private struct SheetHead: View {
    var eyebrow: String?
    var title: String
    var sub: String?
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let eyebrow { Eyebrow(text: eyebrow) }
            Text(title).font(.title(24)).foregroundStyle(Color.navy).fixedSize(horizontal: false, vertical: true)
            if let sub { Text(sub).font(.meta).foregroundStyle(Color.muted).fixedSize(horizontal: false, vertical: true) }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct LinkButton: View {
    var label: String
    var action: () -> Void
    var body: some View {
        Button(label, action: action).font(.app(14.5, .semibold)).foregroundStyle(Color.shoalBlue)
            .frame(maxWidth: .infinity).frame(height: 36)
    }
}

// Logging checks the last dose first, so two people don't both give it.
struct DoseSheet: View {
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss
    var m: Med

    var body: some View {
        let last = store.lastDose(m.id)
        let early = m.prn ? store.okAt(m) : nil
        let already = m.prn ? nil : store.givenToday(m)
        let who = { (d: Dose) in d.by == "you" ? "You" : store.name(d.by) }
        VStack(alignment: .leading, spacing: 18) {
            if let early, let last {
                SheetHead(eyebrow: "Check before giving", title: "\(m.name) was given \(ago(last.at))",
                          sub: "\(who(last)) gave it at \(clock(last.at)). Next dose okay after \(clock(early)). Call hospice before giving more.")
                VStack(spacing: 10) {
                    Button("Don't log it") { dismiss() }.buttonStyle(GhostButton())
                    Button("Call hospice") {
                        dismiss()
                        store.say("Calling hospice, (408) 555-0199")
                        if let u = URL(string: "tel:4085550199") { UIApplication.shared.open(u) }
                    }
                    .buttonStyle(GhostButton())
                    LinkButton(label: "Hospice said okay, log it anyway") { store.logDose(m); dismiss() }
                }
            } else if let already {
                SheetHead(eyebrow: "Already given", title: "\(m.name) was given today",
                          sub: "\(who(already)) gave it at \(clock(already.at)). Once a day.")
                VStack(spacing: 10) {
                    Button("Okay") { dismiss() }.buttonStyle(GhostButton())
                    LinkButton(label: "Log another dose anyway") { store.logDose(m); dismiss() }
                }
            } else {
                SheetHead(eyebrow: "Log a dose", title: "\(m.amt) of \(m.name.lowercased())", sub: "\(m.how) · \(m.why)")
                HStack(spacing: 10) {
                    Button("Cancel") { dismiss() }.buttonStyle(GhostButton())
                    Button("I gave it") { store.logDose(m); dismiss() }.buttonStyle(GhostButton())
                }
            }
        }
        .padding(24)
        .presentationDetents([.height(early != nil ? 370 : already != nil ? 290 : 250)])
        .presentationBackground { AppBackground() }
    }
}

struct DoseLogSheet: View {
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss
    var nurse: Bool
    var body: some View {
        let list = store.doses.sorted { $0.at > $1.at }
        VStack(alignment: .leading, spacing: 14) {
            SheetHead(title: "Dose log")
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(list) { d in
                        HStack(spacing: 10) {
                            Avatar(p: store.person(d.by), size: 28)
                            VStack(alignment: .leading, spacing: 2) {
                                if let m = store.med(d.med) {
                                    Text("\(m.amt) \(m.name.lowercased())").font(.app(15, .semibold)).foregroundStyle(Color.ink)
                                }
                                Text("\(d.by == "you" ? "You" : store.name(d.by)) · \(clock(d.at)) · \(ago(d.at))").font(.meta).foregroundStyle(Color.muted)
                            }
                            Spacer()
                            if d.by == "you" && !nurse {
                                Button("Remove") { withAnimation { store.removeDose(d) } }
                                    .font(.app(14, .semibold)).foregroundStyle(Color.shoalBlue)
                            }
                        }
                        .padding(.vertical, 10)
                        if d.id != list.last?.id { Divider() }
                    }
                    if list.isEmpty {
                        Text("No doses logged yet.").font(.meta).foregroundStyle(Color.muted).frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
            .scrollIndicators(.hidden)
            Button("Done") { dismiss() }.buttonStyle(GhostButton())
        }
        .padding(24)
        .presentationDetents([.medium, .large])
        .presentationBackground { AppBackground() }
        .modifier(SheetToast())
    }
}

// MARK: - Editing notes and meds

private func field<F: View>(_ label: String, @ViewBuilder _ f: () -> F) -> some View {
    VStack(alignment: .leading, spacing: 6) {
        Text(label).font(.app(13, .semibold)).foregroundStyle(Color.sectionInk)
        f().font(.body15)
            .padding(.horizontal, 14).padding(.vertical, 12)
            .background(.white.opacity(0.85), in: .rect(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Color(hex: 0xdde1e6)))
    }
}

struct NoteSheet: View {
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss
    var note: CareNote
    var s: CareSection
    var new: Bool
    @State private var title = ""
    @State private var text: String

    init(note: CareNote, s: CareSection, new: Bool) {
        self.note = note; self.s = s; self.new = new
        _text = State(initialValue: note.body)
    }

    private var sectionName: String { ["key": "most important", "needs": "needs", "prefs": "preferences"][s.rawValue]! }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SheetHead(title: new ? "Add to \(sectionName)" : note.t,
                      sub: new ? nil : "\(note.by == "you" ? "You" : store.name(note.by)) · \(note.on)")
            if new {
                field("Title") { TextField(s == .prefs ? "Music" : s == .needs ? "Sleep" : "Doctor", text: $title) }
            }
            field(new ? "What should everyone know?" : "Details") {
                TextField("", text: $text, axis: .vertical).lineLimit(4...8)
            }
            Spacer(minLength: 0)
            HStack(spacing: 10) {
                if !new && !note.alert {
                    Button("Remove") { store.removeNote(note, in: s); dismiss() }.buttonStyle(GhostButton())
                } else {
                    Button("Cancel") { dismiss() }.buttonStyle(GhostButton())
                }
                Button("Save") { save() }.buttonStyle(GhostButton())
            }
        }
        .padding(24)
        .presentationDetents([.height(new ? 470 : 400), .large])
        .presentationBackground { AppBackground() }
        .modifier(SheetToast())
    }

    private func save() {
        let v = text.trimmingCharacters(in: .whitespacesAndNewlines), k = title.trimmingCharacters(in: .whitespaces)
        if v.isEmpty || (new && k.isEmpty) { store.say(new && k.isEmpty ? "Add a title first" : "Write something first"); return }
        if !new && v == note.body { dismiss(); return }   // nothing changed
        var n = note
        if new { n.t = k }
        n.body = v; n.by = "you"; n.on = "Just now"; n.short = ""
        store.saveNote(n, in: s)
        dismiss()
    }
}

struct AddMedSheet: View {
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var amt = ""
    @State private var how = ""
    @State private var prn = true
    @State private var every = "4"
    @State private var time = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            SheetHead(title: "Add a medication")
            field("Name") { TextField("Morphine", text: $name) }
            field("Dose") { TextField("5 mg", text: $amt) }
            field("How to give it") { TextField("0.25 mL under the tongue", text: $how) }
            HStack(spacing: 8) {
                chip("As needed", on: prn) { prn = true }
                chip("Every day", on: !prn) { prn = false }
            }
            if prn {
                field("Hours apart, at least") { TextField("4", text: $every).keyboardType(.numberPad) }
            } else {
                field("Time of day") { TextField("8 AM", text: $time) }
            }
            Spacer(minLength: 0)
            HStack(spacing: 10) {
                Button("Cancel") { dismiss() }.buttonStyle(GhostButton())
                Button("Add") {
                    let n = name.trimmingCharacters(in: .whitespaces), a = amt.trimmingCharacters(in: .whitespaces)
                    if n.isEmpty || a.isEmpty { store.say("Add the name and dose"); return }
                    store.addMed(name: n, amt: a, how: how.trimmingCharacters(in: .whitespaces), prn: prn,
                                 every: Int(every) ?? 4, time: time.trimmingCharacters(in: .whitespaces))
                    dismiss()
                }
                .buttonStyle(GhostButton())
            }
        }
        .padding(24)
        .presentationDetents([.large])
        .presentationBackground { AppBackground() }
        .modifier(SheetToast())
    }

    private func chip(_ label: String, on: Bool, _ action: @escaping () -> Void) -> some View {
        Button { withAnimation(.snappy) { action() } } label: {
            Text(label).font(.app(14, .semibold)).foregroundStyle(on ? .white : Color.ink)
                .padding(.horizontal, 14).frame(height: 36)
                .background(on ? Color.navy : .white.opacity(0.85), in: .capsule)
        }
        .buttonStyle(Pressable())
        .accessibilityAddTraits(on ? .isSelected : [])
    }
}

// MARK: - Care on other screens

// Home: the next comfort doses at a glance, or Locked.
struct CareHomeCard: View {
    @Environment(Store.self) private var store
    var body: some View {
        Button { store.go(.care(nurse: false)) } label: {
            VStack(alignment: .leading, spacing: 0) {
                TileTop(label: "\(LOVED)'s care")
                if store.careUnlocked {
                    ForEach(store.meds.filter(\.prn)) { m in
                        let ok = store.okAt(m)
                        if m.id != store.meds.first(where: \.prn)?.id { RowSep() }
                        HStack(alignment: .firstTextBaseline) {
                            Text("\(m.name) \(m.amt)").font(.app(14, .bold)).foregroundStyle(Color.navy)
                            Spacer()
                            Text(ok.map { "Okay after \(clock($0))" } ?? "Okay now if needed").font(.app(13, ok == nil ? .regular : .semibold))
                                .foregroundStyle(ok == nil ? Color.muted : Color(hex: 0x8a5a07))
                        }
                        .padding(.vertical, 7)
                    }
                    HStack(spacing: 6) {
                        Text("!").font(.app(11, .heavy)).foregroundStyle(.white)
                            .frame(width: 16, height: 16).background(Color(hex: 0xd4553a), in: .circle)
                        Text("Allergic: \(store.allergies)").font(.app(13, .semibold)).foregroundStyle(Color.alert)
                    }
                    .padding(.top, 8)
                } else {
                    HStack(spacing: 10) {
                        Image(systemName: "lock").font(.system(size: 14, weight: .semibold)).foregroundStyle(Color.shoalBlue)
                            .frame(width: 36, height: 36).background(Color.blueTint, in: .circle)
                        Text("Locked").font(.app(13.5)).foregroundStyle(Color.muted)
                    }
                    .padding(.top, 4)
                }
            }
            .homeTile()
        }
        .buttonStyle(Pressable())
        .accessibilityLabel(store.careUnlocked ? "\(LOVED)'s care page" : "\(LOVED)'s care page, locked")
    }

    private func progressOf(_ m: Med) -> Double {
        guard let d = store.lastDose(m.id) else { return 1 }
        return min(1, Date().timeIntervalSince(d.at) / (Double(m.every) * 3600))
    }
}

// On a med task: today's doses, or a way to unlock.
struct MedTaskCard: View {
    @Environment(Store.self) private var store
    var ids: [String]
    @State private var dose: Med?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Eyebrow(text: "Doses")
            if store.careUnlocked {
                ForEach(ids.compactMap { store.med($0) }) { m in
                    Button { dose = m } label: {
                        if m.prn {
                            let ok = store.okAt(m)
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("\(m.name) \(m.amt)").font(.app(15, .semibold)).foregroundStyle(Color.ink)
                                    Text(store.lastDose(m.id).map { "\(store.name($0.by)) · \(ago($0.at))" } ?? "Not given yet").font(.meta).foregroundStyle(Color.muted)
                                }
                                Spacer()
                                Text(ok.map { "Okay after \(clock($0))" } ?? "Okay now").font(.app(13.5, .semibold))
                                    .foregroundStyle(ok == nil ? Color.shoalBlue : Color(hex: 0x8a5d0c))
                            }
                            .padding(.vertical, 6)
                        } else {
                            DailyRow(m: m)
                        }
                    }
                    .buttonStyle(Pressable())
                }
                Button("Full log") { store.go(.care(nurse: false)) }.font(.app(14, .semibold))
            } else {
                HStack {
                    Image(systemName: "lock.fill").foregroundStyle(Color.navy)
                    Text("Doses are locked").font(.app(15, .semibold)).foregroundStyle(Color.ink)
                    Spacer()
                    Button("Unlock") { store.go(.care(nurse: false)) }.font(.app(14.5, .semibold))
                }
            }
        }
        .glassCard()
        .sheet(item: $dose) { m in DoseSheet(m: m) }
    }
}

// Settings: how the care page is locked.
struct CareLockSheet: View {
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        let others = store.people.filter { $0.tier == .main && $0.id != "you" }.map(\.name) + ["you"]
        VStack(alignment: .leading, spacing: 18) {
            SheetHead(title: "Care page lock",
                      sub: "Only \(andList(others)) can open it. Locks after 5 minutes. Ana, the hospice nurse, can see meds and allergies.")
            VStack(spacing: 10) {
                Button(store.pin.isEmpty ? "Set a PIN" : "Change PIN") {
                    dismiss()
                    store.pinSetting = true
                    store.go(.care(nurse: false))
                }
                .buttonStyle(GhostButton())
                Button("Lock now") { store.careUnlockedAt = nil; store.say("Locked"); dismiss() }.buttonStyle(GhostButton())
            }
        }
        .padding(24)
        .presentationDetents([.height(290)])
        .presentationBackground { AppBackground() }
    }
}
