import SwiftUI
import PhotosUI

struct ReachUsView: View {
    private enum Space: String, CaseIterable, Identifiable {
        case scrapbook = "Our Scrapbook", story = "Our Story", goals = "Our Goals", questions = "Our Questions", plans = "Our Plans", profile = "Our Profile"
        var id: Self { self }
    }
    @State private var space: Space = .scrapbook
    @State private var privateStory = false
    @State private var editingQuestion: RelationshipEntry?
    @EnvironmentObject private var journal: RelationshipJournalStore

    var body: some View {
        ReachPage {
            Text("Us").font(.largeTitle.bold())
            Text("A little space to grow together.").font(.subheadline)
            Picker("Relationship space", selection: $space) {
                ForEach(Space.allCases) { Text($0.rawValue).tag($0) }
            }.pickerStyle(.menu).font(.headline)
            switch space {
            case .scrapbook:
                NavigationLink {
                    ReachScrapbookView()
                } label: {
                    Label("Open Our Scrapbook", systemImage: "book.closed.fill")
                        .frame(maxWidth: .infinity, minHeight: 52)
                }
                .buttonStyle(.borderedProminent)
                Text("Your private entries and shared memories stay where they are stored. Only their place in the app has changed.")
                    .font(.footnote)
                    .multilineTextAlignment(.center)
            case .story:
                Picker("Story visibility", selection: $privateStory) {
                    Text("Shared timeline").tag(false)
                    Text("Private dates").tag(true)
                }.pickerStyle(.segmented)
                if privateStory { RelationshipMilestonesView() }
                else { SharedRelationshipShelf(kind: .milestone, privateCopy: .constant(nil)) }
            case .goals:
                SharedRelationshipShelf(kind: .goal, privateCopy: .constant(nil))
            case .questions:
                let prompt = RelationshipPrompts.daily(RelationshipPrompts.questions, on: Date())
                ReachGlassPanel {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Today’s question").font(.headline)
                        Text(prompt).font(.title3)
                        Button("Answer privately") {
                            editingQuestion = journal.entries(.question).first {
                                $0.title == prompt && Calendar.current.isDateInToday($0.date)
                            } ?? RelationshipEntry(kind: .question, title: prompt)
                        }.buttonStyle(.bordered).disabled(journal.loadError != nil)
                    }
                }
                JournalStorageNotice()
                SharedRelationshipShelf(kind: .response, privateCopy: .constant(nil), suggestedTitle: prompt)
            case .plans:
                SharedRelationshipShelf(kind: .plan, privateCopy: .constant(nil), ideas: RelationshipPrompts.dateIdeas)
            case .profile:
                ReachProfilePanel()
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .sheet(item: $editingQuestion) { RelationshipEntryEditor(entry: $0) }
    }
}

private struct ReachProfilePanel: View {
    @EnvironmentObject private var appearance: ReachAppearanceStore
    @State private var selection: PhotosPickerItem?
    @State private var slot: ReachAppearanceStore.Photo = .own
    @State private var imageError: String?
    @State private var loading = false

    var body: some View {
        VStack(spacing: 16) {
            ReachGlassPanel {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Make this space yours").font(.title2.weight(.semibold))
                    Text("Appearance settings stay on this iPhone. Names and photos don’t grant pairing access or change your partner’s profile.")
                        .font(.footnote).foregroundStyle(.white.opacity(0.85))
                    TextField("Your display name", text: $appearance.preferences.ownName)
                        .accessibilityLabel("Your local display name")
                        .onChange(of: appearance.preferences.ownName) { _, text in
                            if text.count > 40 { appearance.preferences.ownName = String(text.prefix(40)) }
                        }
                    TextField("Partner’s display name", text: $appearance.preferences.partnerName)
                        .accessibilityLabel("Partner’s local display name")
                        .onChange(of: appearance.preferences.partnerName) { _, text in
                            if text.count > 40 { appearance.preferences.partnerName = String(text.prefix(40)) }
                        }
                    Toggle("Show a personal message in Our Scrapbook", isOn: $appearance.preferences.showMessage)
                    TextField("Your optional words", text: $appearance.preferences.personalMessage, axis: .vertical)
                        .lineLimit(3...6).accessibilityLabel("Optional personal message")
                        .onChange(of: appearance.preferences.personalMessage) { _, text in
                            if text.count > 600 { appearance.preferences.personalMessage = String(text.prefix(600)) }
                        }
                }
                .textFieldStyle(.roundedBorder)
                .submitLabel(.done).onSubmit { ReachKeyboard.dismiss() }
            }
            ReachGlassPanel {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Your photographs").font(.headline)
                    Picker("Photo to change", selection: $slot) {
                        ForEach(ReachAppearanceStore.Photo.allCases) { value in Text(value.label).tag(value) }
                    }.pickerStyle(.menu).disabled(loading)
                    PhotosPicker(selection: $selection, matching: .images) {
                        Label("Choose photograph", systemImage: "photo")
                            .frame(minHeight: 44)
                    }.disabled(loading)
                    if appearance.image(for: slot) != nil {
                        Button(slot == .background ? "Restore original sunset" : "Remove this local photo", role: .destructive) {
                            do { try appearance.setPhoto(nil, for: slot) } catch { imageError = error.localizedDescription }
                        }.frame(minHeight: 44).disabled(loading)
                    }
                    Text("Only a photo you select is imported. Photos are stored privately on this device and aren’t uploaded or shared.")
                        .font(.footnote).foregroundStyle(.white.opacity(0.85))
                    if let imageError { Text(imageError).font(.footnote) }
                }
            }
        }
        .onChange(of: slot) { _, _ in selection = nil; imageError = nil }
        .task(id: selection) {
            guard let selection else { return }
            let selectedSlot = slot
            loading = true; imageError = nil
            defer { loading = false; self.selection = nil }
            do {
                guard let data = try await selection.loadTransferable(type: Data.self) else {
                    throw ReachAppearanceStore.AppearanceError.image
                }
                try Task.checkCancellation()
                try appearance.setPhoto(data, for: selectedSlot)
            } catch is CancellationError { return }
            catch { imageError = error.localizedDescription }
        }
    }
}
