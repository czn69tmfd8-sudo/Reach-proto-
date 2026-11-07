import SwiftUI
import PhotosUI
import UIKit

struct RelationshipEntryEditor: View {
    @EnvironmentObject private var store: RelationshipJournalStore
    @Environment(\.dismiss) private var dismiss
    @State private var draft: RelationshipEntry
    @State private var selection: PhotosPickerItem?
    @State private var loadingPhoto = false
    @State private var error: String?
    @FocusState private var field: Field?
    private enum Field: Hashable { case title, body, category }
    init(entry: RelationshipEntry) { _draft = State(initialValue: entry) }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("Private on this iPhone. Saving does not share this entry with your partner.")
                        .font(.footnote)
                }
                Section("Your \(draft.kind.label.lowercased())") {
                    TextField("Title", text: $draft.title, axis: .vertical).focused($field, equals: .title)
                        .accessibilityLabel("Entry title, maximum 120 characters")
                    DatePicker("Date", selection: $draft.date, displayedComponents: .date)
                    TextField("Notes or your response", text: $draft.body, axis: .vertical)
                        .lineLimit(4...12).focused($field, equals: .body)
                        .accessibilityLabel("Private notes or response, maximum 6,000 characters")
                    if draft.kind == .dateIdea {
                        TextField("Category, for example At home", text: $draft.category).focused($field, equals: .category)
                    }
                    if draft.kind == .dateIdea || draft.kind == .reminder {
                        Picker("Status", selection: $draft.status) {
                            ForEach(RelationshipEntry.Status.allCases, id: \.self) { value in
                                Text(value.rawValue.capitalized).tag(value)
                            }
                        }
                    }
                }
                if draft.kind == .memory { photoSection }
                if let error { Section { Text(error).foregroundStyle(.red).accessibilityLabel("Save error: " + error) } }
            }
            .scrollDismissesKeyboard(.interactively)
            .submitLabel(.done).onSubmit { field = nil }
            .reachKeyboardToolbar()
            .background(ReachKeyboardObserver().frame(width: 0, height: 0))
            .navigationTitle(draft.kind.label).navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        do { try store.save(draft); dismiss() }
                        catch { self.error = error.localizedDescription }
                    }.disabled(loadingPhoto || store.loadError != nil)
                }
            }
            .interactiveDismissDisabled(loadingPhoto)
            .task(id: selection) {
                guard let selection else { return }
                loadingPhoto = true; defer { loadingPhoto = false; self.selection = nil }
                do {
                    guard let data = try await selection.loadTransferable(type: Data.self) else { throw JournalError.invalidEntry }
                    try Task.checkCancellation()
                    draft.photo = try RelationshipJournalStore.memoryPhoto(data)
                    error = nil
                } catch is CancellationError { return }
                catch { self.error = error.localizedDescription }
            }
        }
    }
    private var photoSection: some View {
        Section("Optional memory photograph") {
            if let data = draft.photo, let image = UIImage(data: data) {
                Image(uiImage: image).resizable().scaledToFit().frame(maxHeight: 200)
                Button("Remove photo", role: .destructive) { draft.photo = nil; selection = nil }
                    .disabled(loadingPhoto)
            }
            PhotosPicker(selection: $selection, matching: .images) {
                Label("Choose photograph", systemImage: "photo")
            }.disabled(loadingPhoto)
            if loadingPhoto { ProgressView("Preparing local photograph…") }
            Text("Only the selected photo is imported. A resized copy without the original metadata stays in this private journal.")
                .font(.footnote)
        }
    }
}
