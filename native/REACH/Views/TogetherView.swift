import SwiftUI
import UIKit

struct TogetherView: View {
    @EnvironmentObject private var store: RelationshipJournalStore
    @EnvironmentObject private var appearance: ReachAppearanceStore
    @State private var selected: RelationshipEntry.Kind = .memory
    @State private var editing: RelationshipEntry?
    @State private var deleting: RelationshipEntry?
    @State private var error: String?
    @State private var search = ""
    @State private var onlyPlanned = false

    private var visibleEntries: [RelationshipEntry] {
        store.entries(selected).filter { entry in
            (!onlyPlanned || selected != .dateIdea || entry.status == .planned)
                && (search.isEmpty || (entry.title + " " + entry.body + " " + entry.category).localizedCaseInsensitiveContains(search))
        }
    }

    var body: some View {
        ReachPage {
            Text("Together").font(.largeTitle.bold())
            Text("PRIVATE ON THIS IPHONE · Not shared or synchronized")
                .font(.caption.weight(.semibold)).multilineTextAlignment(.center)
            if appearance.preferences.showMessage && !appearance.preferences.personalMessage.isEmpty {
                Text(appearance.preferences.personalMessage).italic().multilineTextAlignment(.center)
            }
            JournalStorageNotice()
            Picker("Together section", selection: $selected) {
                Text("Memories").tag(RelationshipEntry.Kind.memory)
                Text("Questions").tag(RelationshipEntry.Kind.question)
                Text("Date ideas").tag(RelationshipEntry.Kind.dateIdea)
                Text("Reminders").tag(RelationshipEntry.Kind.reminder)
            }.pickerStyle(.menu).font(.headline)
            TextField("Search your local entries", text: $search)
                .textFieldStyle(.roundedBorder).submitLabel(.done).onSubmit { ReachKeyboard.dismiss() }
                .accessibilityLabel("Search private Together entries")
            if selected == .dateIdea { Toggle("Planned dates only", isOn: $onlyPlanned) }
            suggestions
            Button { editing = RelationshipEntry(kind: selected) } label: {
                Label("Add \(selected.label.lowercased())", systemImage: "plus")
                    .frame(minHeight: 44)
            }.buttonStyle(.borderedProminent).disabled(store.loadError != nil)
            if let error { Text(error).font(.footnote).accessibilityLabel("Save error: " + error) }
            if visibleEntries.isEmpty {
                ReachGlassPanel {
                    VStack(spacing: 12) {
                        Image(systemName: "heart.text.square").font(.largeTitle)
                        Text("A little space for the two of you").font(.headline)
                        Text(store.entries(selected).isEmpty ? "Add your first \(selected.label.lowercased()). Only you can see it on this iPhone." : "No entries match these filters. Try another search.")
                            .multilineTextAlignment(.center)
                    }.frame(maxWidth: .infinity)
                }
            }
            ForEach(visibleEntries) { entry in
                RelationshipEntryCard(entry: entry, edit: { editing = entry }, delete: { deleting = entry })
            }
            NavigationLink {
                ReachHomeView()
            } label: {
                Label("Development demo · simulated connections", systemImage: "hammer")
                    .font(.footnote).padding(16).background(.black.opacity(0.65), in: RoundedRectangle(cornerRadius: 16))
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .sheet(item: $editing) { RelationshipEntryEditor(entry: $0) }
        .alert("Delete this local entry?", isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } }), presenting: deleting) { entry in
            Button("Delete", role: .destructive) { perform { try store.delete(entry) } }
            Button("Cancel", role: .cancel) {}
        } message: { _ in Text("This removes it from this iPhone. There is no shared copy or undo.") }
    }

    @ViewBuilder private var suggestions: some View {
        switch selected {
        case .question:
            let question = RelationshipPrompts.daily(RelationshipPrompts.questions, on: Date())
            ReachGlassPanel {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Today’s question").font(.headline)
                    Text(question).font(.title3)
                    Text("Your response is private. Your partner cannot see it.").font(.footnote)
                    Button("Write or edit my response") {
                        editing = todayEntry(title: question) ?? RelationshipEntry(kind: .question, title: question)
                    }.buttonStyle(.bordered).disabled(store.loadError != nil)
                }
            }
        case .dateIdea:
            ReachGlassPanel {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Ideas to make your own").font(.headline)
                    ForEach(RelationshipPrompts.dateIdeas, id: \.self) { title in
                        Button { editing = RelationshipEntry(kind: .dateIdea, title: title, category: "At a distance") } label: {
                            Label(title, systemImage: "plus.circle").frame(minHeight: 44, alignment: .leading)
                        }.disabled(store.loadError != nil)
                    }
                    Text("Suggestions only. Saving an idea does not invite your partner or book anything.").font(.footnote)
                }
            }
        case .reminder:
            let title = RelationshipPrompts.daily(RelationshipPrompts.reminders, on: Date())
            ReachGlassPanel {
                VStack(alignment: .leading, spacing: 12) {
                    Text("A gentle daily reminder").font(.headline)
                    Text(title)
                    if let entry = todayEntry(title: title) {
                        Text(entry.status == .dismissed ? "Dismissed for today" : "Saved for today").font(.caption)
                    } else {
                        HStack {
                            Button("Save") { saveReminder(title, status: .saved) }
                            Button("Dismiss") { saveReminder(title, status: .dismissed) }
                        }.buttonStyle(.bordered).disabled(store.loadError != nil)
                    }
                    Text("In-app only. No notification or message is sent.").font(.footnote)
                }
            }
        default: EmptyView()
        }
    }
    private func todayEntry(title: String) -> RelationshipEntry? {
        store.entries(selected).first { $0.title == title && Calendar.current.isDateInToday($0.date) }
    }
    private func saveReminder(_ title: String, status: RelationshipEntry.Status) {
        perform { try store.save(RelationshipEntry(kind: .reminder, title: title, status: status)) }
    }
    private func perform(_ action: () throws -> Void) {
        do { try action(); error = nil } catch { self.error = error.localizedDescription }
    }
}

struct JournalStorageNotice: View {
    @EnvironmentObject private var store: RelationshipJournalStore
    var body: some View {
        if let error = store.loadError {
            ReachGlassPanel {
                VStack(alignment: .leading, spacing: 12) {
                    Text(error).font(.footnote)
                    Button("Try opening local journal again") { store.reload() }
                }
            }
        }
    }
}

struct RelationshipEntryCard: View {
    let entry: RelationshipEntry
    let edit: () -> Void
    let delete: () -> Void
    var body: some View {
        ReachGlassPanel {
            VStack(alignment: .leading, spacing: 12) {
                Text(entry.title).font(.title3.weight(.semibold))
                Text(entry.date, style: .date).font(.caption)
                if !entry.category.isEmpty { Text(entry.category).font(.caption).bold() }
                if !entry.body.isEmpty { Text(entry.body).textSelection(.enabled) }
                if let data = entry.photo, let image = UIImage(data: data) {
                    Image(uiImage: image).resizable().scaledToFit().frame(maxHeight: 280)
                        .clipShape(RoundedRectangle(cornerRadius: 16)).accessibilityLabel("Your selected memory photograph")
                }
                if entry.kind == .dateIdea || entry.kind == .reminder {
                    Text(entry.status.rawValue.capitalized).font(.caption.weight(.medium))
                }
                HStack {
                    Button("Edit", action: edit).frame(minHeight: 44)
                    Spacer()
                    Button("Delete", role: .destructive, action: delete).frame(minHeight: 44)
                }.buttonStyle(.bordered)
            }
        }
    }
}

struct RelationshipMilestonesView: View {
    @EnvironmentObject private var store: RelationshipJournalStore
    @State private var editing: RelationshipEntry?
    @State private var deleting: RelationshipEntry?
    @State private var error: String?
    var body: some View {
        VStack(spacing: 16) {
            JournalStorageNotice()
            ReachGlassPanel {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Your relationship dates").font(.title2.bold())
                    Text("Milestones and important dates are private to this iPhone. They do not change pairing or your partner’s information.").font(.footnote)
                    if store.entries(.milestone).isEmpty { Text("Add an anniversary, a first meeting or a moment you want to remember.") }
                    Button("Add a milestone") { editing = RelationshipEntry(kind: .milestone) }
                        .buttonStyle(.bordered).frame(minHeight: 44).disabled(store.loadError != nil)
                    if let error { Text(error).font(.footnote) }
                }
            }
            ForEach(store.entries(.milestone)) { entry in
                RelationshipEntryCard(entry: entry, edit: { editing = entry }, delete: { deleting = entry })
            }
        }
        .sheet(item: $editing) { RelationshipEntryEditor(entry: $0) }
        .alert("Delete this local milestone?", isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } }), presenting: deleting) { entry in
            Button("Delete", role: .destructive) {
                do { try store.delete(entry) } catch { self.error = error.localizedDescription }
            }
            Button("Cancel", role: .cancel) {}
        } message: { _ in Text("It will be removed from this iPhone.") }
    }
}
