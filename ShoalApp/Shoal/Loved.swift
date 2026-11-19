import SwiftUI

// Dad's profile: who he is, what he likes, and who cares for him. He has no jar.
// His meds, allergies and needs stay on the locked care page.

struct Likes: Identifiable, Hashable {
    let id = UUID()
    var cat: String
    var icon: String
    var hue: UInt32
    var big: String? = nil     // one value worth seeing at a glance, like the room temperature
    var loves: [String]
    var nots: [String] = []
    var tint: Color { Color(hex: hue) }
}

func demoLikes() -> [Likes] {[
    Likes(cat: "Music", icon: "music.note", hue: 0x7a5af5,
          loves: ["Jazz on the radio", "Ella Fitzgerald", "Hymns on Sunday"], nots: ["Loud TV"]),
    Likes(cat: "Food and drink", icon: "fork.knife", hue: 0xe0793a,
          loves: ["Cold ginger ale", "Vanilla pudding", "Canned peaches"], nots: ["Anything spicy"]),
    Likes(cat: "Temperature", icon: "thermometer.medium", hue: 0x2f9bd6, big: "68°",
          loves: ["Window open a crack", "Light cotton blanket"], nots: ["Heavy covers"]),
    Likes(cat: "Things to do", icon: "leaf", hue: 0x3f9b8c,
          loves: ["Watching the bird feeder", "Old photo albums", "Crossword read aloud"]),
    Likes(cat: "Things to talk about", icon: "bubble.left.and.bubble.right", hue: 0xd4708a,
          loves: ["The Giants", "Fishing at Lake Tahoe", "The grandkids"], nots: ["Money"]),
    Likes(cat: "Comfort", icon: "moon", hue: 0x5b6fd6,
          loves: ["Cool cloth on his forehead", "Someone holding his hand", "Lights low after 8"], nots: ["Being rushed in the morning"]),
    Likes(cat: "Visits", icon: "calendar", hue: 0xc98a1b,
          loves: ["Sam's video call, 7 PM", "Pastor Jim, Sundays"], nots: ["More than 2 people at once"]),
]}

extension Store {
    func addLike(_ id: UUID, _ text: String, not: Bool) {
        guard let i = likes.firstIndex(where: { $0.id == id }) else { return }
        if not { likes[i].nots.append(text) } else { likes[i].loves.append(text) }
        say("Added. Everyone sees it.")
    }
    func removeLike(_ id: UUID, _ text: String) {
        guard let i = likes.firstIndex(where: { $0.id == id }) else { return }
        likes[i].loves.removeAll { $0 == text }
        likes[i].nots.removeAll { $0 == text }
    }
}

// Dad's face. The sample family has his photo; a new account shows a warm initial.
struct LovedAvatar: View {
    @Environment(Store.self) private var store
    var size: CGFloat = 52
    var body: some View {
        Group {
            if store.sample {
                Image("avatar-dad").resizable().scaledToFill()
            } else {
                ZStack {
                    Circle().fill(LinearGradient(colors: [Color(hex: 0xf6d9b8), Color(hex: 0xe9b98c)], startPoint: .topLeading, endPoint: .bottomTrailing))
                    Text(String(LOVED.prefix(1))).font(.title(size * 0.44)).foregroundStyle(Color(hex: 0x7a4a1e))
                }
            }
        }
        .frame(width: size, height: size).clipShape(.circle)
        .overlay(Circle().strokeBorder(.white, lineWidth: 2))
    }
}

// The card at the top of People.
struct LovedCard: View {
    @Environment(Store.self) private var store
    var body: some View {
        Button { store.go(.loved) } label: {
            HStack(spacing: 14) {
                LovedAvatar(size: 54)
                VStack(alignment: .leading, spacing: 4) {
                    Text(LOVED).font(.app(17, .semibold)).foregroundStyle(Color.ink)
                    Text("Hospice care at home").font(.meta).foregroundStyle(Color.muted)
                    HStack(spacing: 5) {
                        ForEach(store.likes.prefix(5)) { l in
                            Image(systemName: l.icon).font(.system(size: 10.5, weight: .semibold)).foregroundStyle(l.tint)
                                .frame(width: 22, height: 22).background(l.tint.opacity(0.13), in: .circle)
                        }
                    }
                    .padding(.top, 2)
                }
                Spacer(minLength: 4)
                Chevron()
            }
            .contentShape(.rect)
        }
        .buttonStyle(Pressable())
        .glassCard(padding: 16)
    }
}

struct LovedView: View {
    @Environment(Store.self) private var store
    @State private var editing: Likes?

    var body: some View {
        Page {
            VStack(spacing: 8) {
                LovedAvatar(size: 88)
                Text(LOVED).font(.title(30)).foregroundStyle(Color.navy)
                Text("82 · Hospice care at home since September").font(.meta).foregroundStyle(Color.muted)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity).padding(.top, 4).padding(.bottom, 6)

            Button { store.go(.care(nurse: false)) } label: {
                HStack(spacing: 12) {
                    Image(systemName: "cross.case").font(.system(size: 16, weight: .medium)).foregroundStyle(Color.shoalBlue)
                        .frame(width: 38, height: 38).background(Color.blueTint, in: .circle)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Care info").font(.app(15.5, .semibold)).foregroundStyle(Color.ink)
                        Text("Meds, allergies and needs").font(.meta).foregroundStyle(Color.muted)
                    }
                    Spacer(minLength: 4)
                    if !store.careUnlocked {
                        Image(systemName: "lock.fill").font(.system(size: 12)).foregroundStyle(Color.muted)
                    }
                    Chevron()
                }
                .contentShape(.rect)
            }
            .buttonStyle(Pressable())
            .glassCard(padding: 14)

            SectionH(text: "What he likes")
            if store.likes.isEmpty {
                Text("Nothing yet.").font(.meta).foregroundStyle(Color.muted)
            }
            ForEach(store.likes) { l in
                Button { editing = l } label: { LikesCard(l: l) }.buttonStyle(Pressable())
            }

            SectionH(text: "Care team")
            VStack(spacing: 0) {
                teamRow(letter: "A", title: "Ana", sub: "Hospice nurse") { store.go(.care(nurse: true)) }
                RowSep()
                teamRow(icon: "phone", title: "Hospice office", sub: "(408) 555-0199 · day or night") {
                    store.say("Calling hospice, (408) 555-0199")
                    if let u = URL(string: "tel:4085550199") { UIApplication.shared.open(u) }
                }
            }
            .glassCard(padding: 12)
        }
        .navigationTitle("").navigationBarTitleDisplayMode(.inline)
        .sheet(item: $editing) { l in LikesSheet(id: l.id) }
    }

    private func teamRow(icon: String? = nil, letter: String? = nil, title: String, sub: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                ZStack {
                    Circle().fill(Color.blueTint)
                    if let icon { Image(systemName: icon).font(.system(size: 15, weight: .medium)).foregroundStyle(Color.shoalBlue) }
                    if let letter { Text(letter).font(.app(16, .semibold)).foregroundStyle(Color.shoalBlue) }
                }
                .frame(width: 38, height: 38)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.app(15.5, .semibold)).foregroundStyle(Color.ink)
                    Text(sub).font(.meta).foregroundStyle(Color.muted).lineLimit(1)
                }
                Spacer(minLength: 4)
                Chevron()
            }
            .padding(.vertical, 10).contentShape(.rect)
        }
        .buttonStyle(Pressable())
    }
}

// One kind of thing he likes: a colored header, then what he likes and what he doesn't as chips.
struct LikesCard: View {
    var l: Likes
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: l.icon).font(.system(size: 15, weight: .semibold)).foregroundStyle(l.tint)
                    .frame(width: 34, height: 34).background(l.tint.opacity(0.14), in: .rect(cornerRadius: 11))
                Text(l.cat).font(.app(16, .semibold)).foregroundStyle(Color.ink)
                Spacer(minLength: 4)
                if let big = l.big {
                    Text(big).font(.title(26)).foregroundStyle(l.tint)
                }
            }
            FlowRow(spacing: 6) {
                ForEach(l.loves, id: \.self) { s in
                    Text(s).font(.app(13.5, .medium)).foregroundStyle(Color.ink)
                        .padding(.horizontal, 11).frame(height: 30)
                        .background(l.tint.opacity(0.12), in: .capsule)
                }
                ForEach(l.nots, id: \.self) { s in
                    HStack(spacing: 5) {
                        Image(systemName: "nosign").font(.system(size: 10.5, weight: .semibold))
                        Text(s).font(.app(13.5, .medium))
                    }
                    .foregroundStyle(Color.muted)
                    .padding(.horizontal, 11).frame(height: 30)
                    .overlay(Capsule().strokeBorder(Color(hex: 0xdde1e6)))
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .multilineTextAlignment(.leading)
        .homeTile()
    }
}

// Edit one kind: remove a chip, or add a like or a don't.
struct LikesSheet: View {
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss
    var id: UUID
    @State private var text = ""
    @State private var not = false

    var body: some View {
        let l = store.likes.first { $0.id == id }
        VStack(alignment: .leading, spacing: 18) {
            if let l {
                HStack(spacing: 10) {
                    Image(systemName: l.icon).font(.system(size: 15, weight: .semibold)).foregroundStyle(l.tint)
                        .frame(width: 34, height: 34).background(l.tint.opacity(0.14), in: .rect(cornerRadius: 11))
                    Text(l.cat).font(.title(24)).foregroundStyle(Color.navy)
                }
                group("Likes", l.loves, l)
                group("Doesn't like", l.nots, l)

                VStack(alignment: .leading, spacing: 10) {
                    Picker("", selection: $not) {
                        Text("Likes").tag(false)
                        Text("Doesn't like").tag(true)
                    }
                    .pickerStyle(.segmented)
                    HStack(spacing: 8) {
                        TextField("Add something", text: $text)
                            .font(.app(15)).padding(.horizontal, 14).frame(height: 44)
                            .background(.white, in: .rect(cornerRadius: 14))
                            .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Color(hex: 0xdde1e6)))
                            .submitLabel(.done).onSubmit(add)
                        Button("Add", action: add).font(.app(15, .semibold)).foregroundStyle(.white)
                            .padding(.horizontal, 18).frame(height: 44).background(Color.shoalBlue, in: .capsule)
                            .buttonStyle(Pressable())
                    }
                }
            }
            Spacer(minLength: 0)
            Button("Done") { dismiss() }.buttonStyle(GhostButton())
        }
        .padding(24)
        .presentationDetents([.height(520), .large])
        .presentationBackground { AppBackground() }
        .modifier(SheetToast())
    }

    @ViewBuilder private func group(_ title: String, _ list: [String], _ l: Likes) -> some View {
        if !list.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text(title).font(.app(13, .semibold)).foregroundStyle(Color.muted)
                FlowRow(spacing: 6) {
                    ForEach(list, id: \.self) { s in
                        Button { withAnimation(.snappy) { store.removeLike(id, s) } } label: {
                            HStack(spacing: 6) {
                                Text(s).font(.app(13.5, .medium)).foregroundStyle(Color.ink)
                                Image(systemName: "xmark").font(.system(size: 9.5, weight: .bold)).foregroundStyle(Color.muted)
                            }
                            .padding(.horizontal, 11).frame(height: 30)
                            .background(title == "Likes" ? l.tint.opacity(0.12) : .white.opacity(0.8), in: .capsule)
                        }
                        .buttonStyle(Pressable()).accessibilityLabel("Remove \(s)")
                    }
                }
            }
        }
    }

    private func add() {
        let v = text.trimmingCharacters(in: .whitespaces)
        if v.isEmpty { store.say("Write something first"); return }
        withAnimation(.snappy) { store.addLike(id, v.prefix(1).uppercased() + v.dropFirst(), not: not) }
        text = ""
    }
}
