import PhotosUI
import SwiftUI

/// Collects a local memory draft. The caller decides whether and
/// when a reviewed draft may be saved through a separately secured service.
struct AdventureMemoryDraftEditor: View {
    var allowPhoto = false
    let onSave: (String, Date, String, PhotosPickerItem?) -> Void
    @State private var photo: PhotosPickerItem?
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var occurredAt = Date()
    @State private var story = ""

    private var valid: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        title.utf8.count <= 120 &&
        story.utf8.count <= 6000
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("The adventure") {
                    TextField("Give this memory a title", text: $title)
                        .textInputAutocapitalization(.words)
                    DatePicker("When did it happen?", selection: $occurredAt, displayedComponents: .date)
                }
                Section("Your memory") {
                    TextEditor(text: $story)
                        .frame(minHeight: 150)
                        .accessibilityLabel("Your story about this memory")
                    Text("\(story.utf8.count) / 6000 bytes")
                        .font(.caption)
                }
                if allowPhoto {
                    Section("Photograph") {
                        let label = photo == nil ? "Choose photo" : "Change selected photo"
                        PhotosPicker(selection: $photo, matching: .images) {
                            Label(label, systemImage: "photo.badge.plus")
                        }
                    }
                }
            }
            .navigationTitle("New Adventure")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add Page") {
                        guard valid else { return }
                        onSave(title.trimmingCharacters(in: .whitespacesAndNewlines), occurredAt, story, photo)
                        dismiss()
                    }
                    .disabled(!valid)
                }
            }
        }
    }
}
