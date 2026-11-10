import SwiftUI

/// Local-only editing prototype. Nothing here writes to Firebase or changes pairing.
struct AdventureStoryEditor: View {
    let initialText: String
    let onSave: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var draft: String
    @State private var showingDiscardConfirmation = false

    init(initialText: String, onSave: @escaping (String) -> Void) {
        self.initialText = initialText
        self.onSave = onSave
        _draft = State(initialValue: initialText)
    }

    private var valid: Bool {
        !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        draft.utf8.count <= 6000
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Your side of the story") {
                    TextEditor(text: $draft)
                        .frame(minHeight: 220)
                        .accessibilityLabel("Your memory")
                    Text("\(draft.utf8.count) / 6000 bytes")
                        .font(.caption)
                        .foregroundStyle(draft.utf8.count > 6000 ? .red : .secondary)
                }
                Section {
                    Text("Preview only: Save updates this sample page on your iPhone while it is open. It does not upload, sync or permanently store your story.")
                        .font(.footnote)
                }
            }
            .navigationTitle("Write your memory")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        if draft != initialText { showingDiscardConfirmation = true }
                        else { dismiss() }
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        guard valid else { return }
                        onSave(draft)
                        dismiss()
                    }
                    .disabled(!valid || draft == initialText)
                }
            }
            .confirmationDialog("Discard your changes?", isPresented: $showingDiscardConfirmation) {
                Button("Discard changes", role: .destructive) { dismiss() }
                Button("Keep writing", role: .cancel) {}
            }
        }
    }
}
