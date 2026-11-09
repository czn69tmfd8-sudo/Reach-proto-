import SwiftUI

/// Creates a memory in a local preview only. The caller decides whether and
/// when a reviewed draft may be shared through a separately secured service.
struct AdventureMemoryDraftEditor: View {
    let onSave: (String, Date, String) -> Void
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
                Section {
                    Text("Preview only. This memory is not uploaded or saved permanently. Photo attachments and partner synchronization are not enabled.")
                        .font(.footnote)
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
                        onSave(title.trimmingCharacters(in: .whitespacesAndNewlines), occurredAt, story)
                        dismiss()
                    }
                    .disabled(!valid)
                }
            }
        }
    }
}
