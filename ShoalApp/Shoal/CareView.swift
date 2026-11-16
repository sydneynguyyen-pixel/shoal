import SwiftUI
import LocalAuthentication

// Dad's care page. Primary caregivers unlock it with Face ID or a PIN.
// Ana, the hospice nurse, gets a view-only page with meds, allergies and wishes.
struct CareView: View {
    @Environment(Store.self) private var store
    var nurse = false

    var body: some View {
        Group {
            if nurse || store.careUnlocked { CarePage(nurse: nurse) } else { CareLockView() }
        }
        .navigationTitle("").navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Lock

struct CareLockView: View {
    @Environment(Store.self) private var store
    @State private var entry = ""
    @State private var wrong = false
    @State private var shake: CGFloat = 0
    @State private var looking = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 10)
            Image(systemName: "lock.fill").font(.app(26, .semibold)).foregroundStyle(Color.navy)
                .frame(width: 60, height: 60).background(.white.opacity(0.8), in: .circle)
                .overlay(Circle().strokeBorder(.white))
            Text("\(LOVED)'s care page").font(.title(28)).foregroundStyle(Color.navy).padding(.top, 14)
            Text(looking ? "Looking for your face…" : wrong ? "That's not it. Try again." : "Enter your PIN")
                .font(.app(15)).foregroundStyle(wrong ? Color.alert : Color.muted).padding(.top, 6)
                .contentTransition(.opacity)
            HStack(spacing: 18) {
                ForEach(0..<4, id: \.self) { i in
                    Circle().fill(i < entry.count ? Color.navy : .clear)
                        .overlay(Circle().strokeBorder(Color.navy.opacity(0.5), lineWidth: 1.4))
                        .frame(width: 14, height: 14)
                }
            }
            .padding(.top, 22)
            .offset(x: shake)
            .accessibilityElement().accessibilityLabel("\(entry.count) of 4 digits entered")

            Spacer(minLength: 20)
            let keys = ["1", "2", "3", "4", "5", "6", "7", "8", "9", "face", "0", "del"]
            LazyVGrid(columns: Array(repeating: GridItem(.fixed(78), spacing: 26), count: 3), spacing: 16) {
                ForEach(keys, id: \.self) { k in key(k) }
            }
            Text("Primary caregivers only · relocks after 5 minutes").font(.meta).foregroundStyle(Color.muted).padding(.top, 22)
            Spacer(minLength: 24)
        }
        .frame(maxWidth: .infinity)
        .background(AppBackground())
    }

    @ViewBuilder private func key(_ k: String) -> some View {
        switch k {
        case "face":
            Button { faceID() } label: {
                Image(systemName: "faceid").font(.system(size: 28)).foregroundStyle(Color.shoalBlue).frame(width: 78, height: 78)
            }
            .buttonStyle(Pressable()).accessibilityLabel("Unlock with Face ID")
        case "del":
            Button { if !entry.isEmpty { entry.removeLast() } } label: {
                Image(systemName: "delete.left").font(.system(size: 22)).foregroundStyle(Color.ink).frame(width: 78, height: 78)
            }
            .buttonStyle(Pressable()).accessibilityLabel("Delete")
        default:
            Button { press(k) } label: {
                Text(k).font(.app(30, .regular)).foregroundStyle(Color.navy)
                    .frame(width: 78, height: 78).background(.white.opacity(0.75), in: .circle)
                    .overlay(Circle().strokeBorder(.white))
                    .shadow(color: Color(hex: 0x21262e, 0.05), radius: 8, y: 4)
            }
            .buttonStyle(Pressable())
        }
    }

    private func press(_ k: String) {
        guard entry.count < 4 else { return }
        withAnimation(.snappy) { wrong = false; entry += k }
        guard entry.count == 4 else { return }
        if entry == store.pin {
            withAnimation(.snappy) { store.unlockCare(face: false) }
        } else {
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(150))
                withAnimation(.snappy) { wrong = true; entry = "" }
                for x in [12.0, -10, 7, -4, 0] {
                    withAnimation(.linear(duration: 0.06)) { shake = x }
                    try? await Task.sleep(for: .milliseconds(60))
                }
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
                    withAnimation(.snappy) { store.unlockCare(face: true) }
                }
            }
        } else {
            withAnimation(.snappy) { looking = true; wrong = false }
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(1.1))
                withAnimation(.snappy) { looking = false; store.unlockCare(face: true) }
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

    var body: some View {
        TimelineView(.periodic(from: .now, by: 30)) { _ in
            Page {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("\(LOVED)'s care page").font(.title()).foregroundStyle(Color.navy)
                        Text(nurse ? "Ana · hospice nurse · view only" : "Primary caregivers").font(.meta).foregroundStyle(Color.muted)
                    }
                    Spacer()
                    if !nurse {
                        Button { withAnimation(.snappy) { store.lockCare() } } label: {
                            Label("Lock", systemImage: "lock").font(.app(14, .semibold))
                                .padding(.horizontal, 12).frame(height: 34).background(.white.opacity(0.8), in: .capsule)
                                .overlay(Capsule().strokeBorder(.white))
                        }
                        .buttonStyle(Pressable()).foregroundStyle(Color.ink)
                    }
                }

                if let a = store.careKey.first(where: \.alert) {
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(Color.alert).font(.system(size: 16))
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Allergic: \(a.short)").font(.app(15.5, .semibold)).foregroundStyle(Color.alert)
                            Text(a.body).font(.meta).foregroundStyle(Color.ink)
                        }
                    }
                    .padding(14).frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(hex: 0xc4442f, 0.09), in: .rect(cornerRadius: 18))
                    .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(Color(hex: 0xc4442f, 0.25)))
                    .accessibilityElement(children: .combine)
                }

                HStack(alignment: .firstTextBaseline) {
                    SectionH(text: "Medications")
                    Button("Log") { showLog = true }.font(.app(14, .semibold)).padding(.top, 22)
                }
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible())], spacing: 12) {
                    ForEach(store.meds.filter(\.prn)) { m in
                        Button { if !nurse { dose = m } } label: { MedTile(m: m) }.buttonStyle(Pressable()).disabled(nurse)
                    }
                }
                VStack(alignment: .leading, spacing: 0) {
                    Eyebrow(text: "Every day").padding(.bottom, 6)
                    ForEach(store.meds.filter { !$0.prn }) { m in
                        Button { if !nurse { dose = m } } label: { DailyRow(m: m) }.buttonStyle(Pressable()).disabled(nurse)
                        if m.id != store.meds.filter({ !$0.prn }).last?.id { Divider() }
                    }
                }
                .glassCard()
                if !nurse {
                    Button { addMed = true } label: {
                        Label("Add a med", systemImage: "plus").font(.app(14.5, .semibold))
                    }
                    .padding(.leading, 4).padding(.top, 2)
                }

                notes("Most important", store.careKey.filter { !nurse || $0.t != "Pharmacy" }, .key)
                if !nurse {
                    notes("Needs", store.needs, .needs)
                    notes("Preferences", store.prefs, .prefs)
                }
            }
        }
        .sheet(item: $dose) { m in DoseSheet(m: m) }
        .sheet(isPresented: $showLog) { DoseLogSheet(nurse: nurse).presentationDetents([.medium, .large]) }
        .sheet(item: $edit) { e in NoteSheet(note: e.note, s: e.s, new: e.new) }
        .sheet(isPresented: $addMed) { AddMedSheet() }
    }

    @ViewBuilder private func notes(_ title: String, _ list: [CareNote], _ s: CareSection) -> some View {
        HStack(alignment: .firstTextBaseline) {
            SectionH(text: title)
            if !nurse {
                Button { edit = NoteEdit(note: CareNote(t: "", body: "", by: "you", on: "Today"), s: s, new: true) } label: {
                    Image(systemName: "plus").font(.app(15, .semibold))
                }
                .padding(.top, 22).accessibilityLabel("Add to \(title)")
            }
        }
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible())], alignment: .leading, spacing: 12) {
            ForEach(list) { n in
                Button { if !nurse { edit = NoteEdit(note: n, s: s, new: false) } } label: { NoteTile(n: n) }
                    .buttonStyle(Pressable()).disabled(nurse)
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

struct MedRing: View {
    var progress: Double
    var ready: Bool
    var size: CGFloat = 40
    var body: some View {
        ZStack {
            Circle().stroke(Color(hex: 0x6e737c, 0.13), lineWidth: 5)
            Circle().trim(from: 0, to: ready ? 1 : max(0.02, progress))
                .stroke(ready ? Color(hex: 0x418ef3) : Color(hex: 0xf6d27c), style: .init(lineWidth: 5, lineCap: .round))
                .rotationEffect(.degrees(-90))
            if ready { Image(systemName: "checkmark").font(.system(size: size * 0.32, weight: .bold)).foregroundStyle(Color(hex: 0x418ef3)) }
        }
        .frame(width: size, height: size)
    }
}

struct MedTile: View {
    @Environment(Store.self) private var store
    var m: Med
    var body: some View {
        let last = store.lastDose(m.id)
        let ok = store.okAt(m)
        let progress = last.map { min(1, Date().timeIntervalSince($0.at) / (Double(m.every) * 3600)) } ?? 1
        VStack(alignment: .leading, spacing: 8) {
            MedRing(progress: progress, ready: ok == nil)
            VStack(alignment: .leading, spacing: 2) {
                Text("\(m.name) \(m.amt)").font(.app(15, .semibold)).foregroundStyle(Color.ink)
                Text(ok.map { "Okay after \(clock($0))" } ?? "Okay now").font(.app(13.5, .semibold))
                    .foregroundStyle(ok == nil ? Color.shoalBlue : Color(hex: 0x8a5d0c))
                Text(last.map { "\(store.name($0.by)) · \(ago($0.at))" } ?? "Not given yet").font(.meta).foregroundStyle(Color.muted)
                Text("As needed · \(m.every) h apart").font(.app(12)).foregroundStyle(Color.muted)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(radius: 20, padding: 14)
        .accessibilityElement(children: .combine)
    }
}

struct DailyRow: View {
    @Environment(Store.self) private var store
    var m: Med
    var body: some View {
        let given = store.givenToday(m)
        HStack(spacing: 12) {
            Image(systemName: given != nil ? "checkmark.circle.fill" : "circle")
                .font(.app(22)).foregroundStyle(given != nil ? Color.shoalBlue : Color(hex: 0xb7bcc4))
            VStack(alignment: .leading, spacing: 2) {
                Text("\(m.name) \(m.amt)").font(.app(15, .semibold)).foregroundStyle(Color.ink)
                Text(given.map { "\(store.name($0.by)) gave it at \(clock($0.at))" } ?? "\(m.time) · \(m.how.lowercased())")
                    .font(.meta).foregroundStyle(Color.muted).multilineTextAlignment(.leading)
            }
            Spacer()
            Text(m.time).font(.meta).foregroundStyle(Color.muted)
        }
        .padding(.vertical, 10)
        .accessibilityElement(children: .combine)
    }
}

struct NoteTile: View {
    @Environment(Store.self) private var store
    var n: CareNote
    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(n.t).font(.app(12, .semibold)).foregroundStyle(n.alert ? Color.alert : Color.muted)
            Text(n.short.isEmpty ? n.body : n.short).font(.app(14.5, .medium)).foregroundStyle(Color.ink)
                .lineLimit(4).multilineTextAlignment(.leading)
            Spacer(minLength: 0)
            Text("\(n.by == "you" ? "You" : store.name(n.by)) · \(n.on)").font(.app(11.5)).foregroundStyle(Color.muted)
        }
        .frame(maxWidth: .infinity, minHeight: 104, alignment: .topLeading)
        .glassCard(radius: 18, padding: 13)
    }
}

// MARK: - Logging a dose

struct DoseSheet: View {
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss
    var m: Med

    var body: some View {
        let last = store.lastDose(m.id)
        let early = m.prn ? store.okAt(m) : nil
        let already = m.prn ? nil : store.givenToday(m)
        VStack(alignment: .leading, spacing: 10) {
            if let early, let last {
                Image(systemName: "exclamationmark.circle.fill").font(.system(size: 26)).foregroundStyle(Color.amber)
                Text("Check before giving").font(.title(26)).foregroundStyle(Color.navy)
                Text("\(m.name) was given \(ago(last.at)) by \(store.name(last.by)). The next dose is okay after \(clock(early)).")
                    .font(.body15).foregroundStyle(Color.ink)
                Spacer(minLength: 8)
                Button("Don't log it") { dismiss() }.buttonStyle(PrimaryButton())
                Button("Call hospice") {
                    if let u = URL(string: "tel:4085550199") { UIApplication.shared.open(u) }
                    dismiss()
                }
                .buttonStyle(GhostButton())
                Button("Hospice said okay, log it anyway") { store.logDose(m); dismiss() }
                    .font(.app(14.5, .semibold)).frame(maxWidth: .infinity).padding(.top, 4)
            } else if let already {
                Text("Already given").font(.title(26)).foregroundStyle(Color.navy)
                Text("\(store.name(already.by)) gave \(m.name.lowercased()) at \(clock(already.at)) today.").font(.body15).foregroundStyle(Color.ink)
                Spacer(minLength: 8)
                Button("Okay") { dismiss() }.buttonStyle(PrimaryButton())
                Button("Log another dose anyway") { store.logDose(m); dismiss() }
                    .font(.app(14.5, .semibold)).frame(maxWidth: .infinity).padding(.top, 4)
            } else {
                Text("Log a dose").font(.title(26)).foregroundStyle(Color.navy)
                Text("\(m.amt) of \(m.name.lowercased())").font(.app(17, .semibold)).foregroundStyle(Color.ink)
                Text("\(m.how). \(m.why).").font(.body15).foregroundStyle(Color.muted)
                Spacer(minLength: 8)
                HStack(spacing: 10) {
                    Button("Cancel") { dismiss() }.buttonStyle(GhostButton())
                    Button("I gave it") { store.logDose(m); dismiss() }.buttonStyle(PrimaryButton())
                }
            }
        }
        .padding(24)
        .presentationDetents([.height(early != nil ? 400 : 300)])
    }
}

struct DoseLogSheet: View {
    @Environment(Store.self) private var store
    var nurse: Bool
    var body: some View {
        NavigationStack {
            List {
                ForEach(store.doses.sorted { $0.at > $1.at }) { d in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            if let m = store.med(d.med) {
                                Text("\(m.name) \(m.amt)").font(.app(15, .semibold)).foregroundStyle(Color.ink)
                            }
                            Text("\(d.by == "you" ? "You" : store.name(d.by)) · \(clock(d.at)), \(ago(d.at))").font(.meta).foregroundStyle(Color.muted)
                        }
                        Spacer()
                        if d.by == "you" && !nurse {
                            Button("Remove", role: .destructive) { withAnimation { store.removeDose(d) } }
                                .font(.app(14, .semibold)).buttonStyle(.borderless)
                        }
                    }
                }
            }
            .navigationTitle("Dose log").navigationBarTitleDisplayMode(.inline)
        }
    }
}

// MARK: - Editing notes and meds

struct NoteSheet: View {
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State var note: CareNote
    var s: CareSection
    var new: Bool

    init(note: CareNote, s: CareSection, new: Bool) {
        _note = State(initialValue: note); self.s = s; self.new = new
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Title") { TextField("Like “Sleep” or “Hearing”", text: $note.t) }
                Section("What everyone should know") {
                    TextField("Write it the way you'd tell family", text: $note.body, axis: .vertical).lineLimit(4...8)
                }
            }
            .scrollContentBackground(.hidden).background(AppBackground())
            .navigationTitle(new ? "Add" : note.t).navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        var n = note
                        n.by = "you"; n.on = "Today"
                        if !new && n.body != note.body { n.short = "" }
                        store.saveNote(n, in: s); dismiss()
                    }
                    .disabled(note.t.trimmingCharacters(in: .whitespaces).isEmpty || note.body.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

struct AddMedSheet: View {
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var amt = ""
    @State private var how = ""
    @State private var prn = true
    @State private var every = 4
    @State private var time = "8 AM"

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Name", text: $name)
                    TextField("Dose, like 5 mg", text: $amt)
                    TextField("How to give it", text: $how)
                }
                Section {
                    Picker("When", selection: $prn) {
                        Text("As needed").tag(true)
                        Text("Every day").tag(false)
                    }
                    .pickerStyle(.segmented)
                    if prn {
                        Stepper("\(every) hours apart", value: $every, in: 1...24)
                    } else {
                        Picker("Time", selection: $time) {
                            ForEach(["8 AM", "Noon", "6 PM", "9 PM"], id: \.self) { Text($0) }
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden).background(AppBackground())
            .navigationTitle("Add a med").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        store.meds.append(Med(id: UUID().uuidString, name: name, amt: amt, how: how.isEmpty ? "As the label says" : how,
                                              why: "Added by you", prn: prn, every: every, time: time))
                        store.say("Added. Everyone sees the change.")
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || amt.isEmpty)
                }
            }
        }
        .presentationDetents([.large])
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
                            Text(m.name).font(.app(14, .bold)).foregroundStyle(Color.navy)
                            Spacer()
                            Text(ok.map { "Okay after \(clock($0))" } ?? "Okay now if needed").font(.app(13, ok == nil ? .regular : .semibold))
                                .foregroundStyle(ok == nil ? Color.muted : Color(hex: 0x8a5a07))
                        }
                        .padding(.vertical, 7)
                    }
                    Text("Allergic: \(store.allergies)").font(.app(13, .semibold)).foregroundStyle(Color.alert).padding(.top, 8)
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
    @State private var newPin = ""
    @State private var changing = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Care page lock").font(.title(26)).foregroundStyle(Color.navy)
            Text("Meds, allergies and wishes open with Face ID or your PIN. Only primary caregivers can open it. It locks again after 5 minutes.")
                .font(.meta).foregroundStyle(Color.muted)
            if changing {
                SecureField("New 4-digit PIN", text: $newPin).keyboardType(.numberPad)
                    .padding(14).background(.white, in: .rect(cornerRadius: 14))
                    .onChange(of: newPin) { newPin = String(newPin.filter(\.isNumber).prefix(4)) }
                Button("Save PIN") { store.pin = newPin; store.say("PIN changed"); dismiss() }
                    .buttonStyle(PrimaryButton(enabled: newPin.count == 4)).disabled(newPin.count != 4)
            } else {
                Button("Change PIN") { withAnimation(.snappy) { changing = true } }.buttonStyle(GhostButton())
                Button("Lock now") { store.careUnlockedAt = nil; store.say("Locked"); dismiss() }.buttonStyle(GhostButton())
                Button("See Ana's view") { dismiss(); store.go(.care(nurse: true)) }
                    .font(.app(14.5, .semibold)).frame(maxWidth: .infinity).padding(.top, 4)
            }
        }
        .padding(24)
        .background(AppBackground())
        .presentationDetents([.height(changing ? 330 : 390)])
    }
}
