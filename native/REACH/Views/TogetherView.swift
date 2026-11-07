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
    @State private var shared = false
    @State private var copyToShare: RelationshipEntry?

    private var visibleEntries: [RelationshipEntry] {
        store.entries(selected).filter { entry in
            (!onlyPlanned || selected != .dateIdea || entry.status == .planned)
                && (search.isEmpty || (entry.title + " " + entry.body + " " + entry.category).localizedCaseInsensitiveContains(search))
        }
    }

    var body: some View {
        ReachPage {
            Text("Together").font(.largeTitle.bold())
            Picker("Scrapbook visibility", selection: $shared) {
                Text("Private").tag(false)
                Text("Shared").tag(true)
            }.pickerStyle(.segmented)
            Text(shared ? "Shared scrapbook · visible to both authorized partners" : "Private on this iPhone")
                .font(.caption.weight(.semibold)).multilineTextAlignment(.center)
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass").accessibilityHidden(true)
                TextField(shared ? "Search shared memories" : "Search private entries", text: $search)
                    .submitLabel(.done).onSubmit { ReachKeyboard.dismiss() }
                if !search.isEmpty {
                    Button { search = "" } label: { Image(systemName: "xmark.circle.fill") }
                        .accessibilityLabel("Clear search")
                }
            }
            .padding(.horizontal, 16).frame(minHeight: 48)
            .background(.black.opacity(0.45), in: Capsule())
            .overlay { Capsule().strokeBorder(.white.opacity(0.2)).allowsHitTesting(false) }

            if shared {
                SharedRelationshipShelf(kind: .memory, search: search, privateCopy: $copyToShare)
            } else {
                privateScrapbook
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .onChange(of: shared) { _, value in
            search = ""
            if !value { copyToShare = nil }
        }
        .sheet(item: $editing) { RelationshipEntryEditor(entry: $0) }
        .alert("Delete this local entry?", isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } }), presenting: deleting) { entry in
            Button("Delete", role: .destructive) { perform { try store.delete(entry) } }
            Button("Cancel", role: .cancel) {}
        } message: { _ in Text("This removes it from this iPhone. It does not remove a separately shared copy.") }
    }

    @ViewBuilder private var privateScrapbook: some View {
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
            RelationshipEntryCard(entry: entry, edit: { editing = entry }, delete: { deleting = entry }) {
                if entry.kind == .memory {
                    Button("Share a copy…") {
                        copyToShare = entry
                        shared = true
                    }.frame(minHeight: 44)
                }
            }
        }
        NavigationLink {
            ReachHomeView()
        } label: {
            Label("Development demo · simulated connections", systemImage: "hammer")
                .font(.footnote).padding(16).background(.black.opacity(0.65), in: RoundedRectangle(cornerRadius: 16))
        }
        .padding(.bottom, 8)
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

struct RelationshipEntryCard<Actions: View>: View {
    let entry: RelationshipEntry
    let edit: () -> Void
    let delete: () -> Void
    @ViewBuilder var extraActions: Actions
    var body: some View {
        ReachGlassPanel {
            VStack(alignment: .leading, spacing: 12) {
                if let data = entry.photo, let image = UIImage(data: data) {
                    Image(uiImage: image).resizable().scaledToFit()
                        .frame(maxWidth: .infinity, maxHeight: 300)
                        .clipShape(RoundedRectangle(cornerRadius: 16)).accessibilityLabel("Your selected memory photograph")
                }
                Text(entry.title).font(.title3.weight(.semibold))
                Text(entry.date, style: .date).font(.caption)
                if !entry.category.isEmpty { Text(entry.category).font(.caption).bold() }
                if !entry.body.isEmpty { Text(entry.body).textSelection(.enabled) }
                if entry.kind == .dateIdea || entry.kind == .reminder {
                    Text(entry.status.rawValue.capitalized).font(.caption.weight(.medium))
                }
                HStack {
                    Button("Edit", action: edit).frame(minHeight: 44)
                    Spacer()
                    Button("Delete", role: .destructive, action: delete).frame(minHeight: 44)
                }.buttonStyle(.bordered)
                extraActions.buttonStyle(.bordered)
            }
        }
    }
}

extension RelationshipEntryCard where Actions == EmptyView {
    init(entry: RelationshipEntry, edit: @escaping () -> Void, delete: @escaping () -> Void) {
        self.init(entry: entry, edit: edit, delete: delete) { EmptyView() }
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
