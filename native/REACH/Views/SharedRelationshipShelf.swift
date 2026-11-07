import PhotosUI
import SwiftUI
import UIKit
import ImageIO

struct SharedRelationshipShelf: View {
    let kind: SharedRelationshipKind
    var search = ""
    @Binding var privateCopy: RelationshipEntry?
    var suggestedTitle = ""
    var ideas: [String] = []
    @StateObject private var store = RelationshipSpaceStore()
    @Environment(\.scenePhase) private var scene
    @State private var editor: Editor?
    @State private var deleting: SharedRelationshipRecord?
    @State private var error: String?

    private struct Editor: Identifiable {
        let scope: RelationshipScope
        let draft: SharedRelationshipEntry
        var previous: SharedRelationshipRecord?
        var id: UUID { draft.id }
    }

    var body: some View {
        VStack(spacing: 14) {
            if scene == .active, let scope = store.scope, store.canRead(at: Date()) {
                if store.status == .offline {
                    Text("Offline · showing recently verified entries").font(.footnote)
                }
                if let privateCopy {
                    Button("Review a copy to share") {
                        do {
                            let photo = try privateCopy.photo.map { try SharedMemoryPhoto.prepare($0) }
                            editor = Editor(scope: scope, draft: .memoryCopy(of: privateCopy, photo: photo))
                            self.privateCopy = nil
                        } catch { self.error = error.localizedDescription }
                    }
                    .buttonStyle(.bordered)
                }
                Button {
                    editor = Editor(scope: scope, draft: SharedRelationshipEntry(kind: kind, title: suggestedTitle))
                } label: {
                    Label("Add shared \(kind.title.lowercased())", systemImage: "plus").frame(minHeight: 44)
                }.buttonStyle(.borderedProminent)
                if !ideas.isEmpty {
                    Menu("Browse date ideas") {
                        ForEach(ideas, id: \.self) { idea in
                            Button(idea) {
                                editor = Editor(scope: scope, draft: SharedRelationshipEntry(kind: kind, title: idea))
                            }
                        }
                    }.buttonStyle(.bordered)
                }
                let visible = store.records.filter {
                    $0.entry.kind == kind && (search.isEmpty ||
                        "\($0.entry.title) \($0.entry.caption)".localizedCaseInsensitiveContains(search))
                }
                if visible.isEmpty {
                    Text(search.isEmpty ? "No shared \(kind.title.lowercased()) entries on this page." : "No shared entries match this search.")
                        .font(.callout).multilineTextAlignment(.center)
                }
                ForEach(visible) { record in
                    sharedCard(record, scope: scope)
                }
                if store.hasOlderEntries || store.pageNumber > 1 {
                    VStack(spacing: 8) {
                        Text("Shared space · page \(store.pageNumber)").font(.caption)
                        if !search.isEmpty { Text("Search applies to this page.").font(.caption) }
                        HStack {
                            if store.pageNumber > 1 {
                                Button("Newer entries") { Task { await store.newerPage() } }
                            }
                            if store.hasOlderEntries {
                                Button("Older entries") { Task { await store.olderPage() } }
                            }
                        }.buttonStyle(.bordered)
                    }
                }
            } else if store.status == .loading {
                ProgressView("Checking shared access…")
            } else {
                Text("Shared access is unavailable. Check that you’re paired, online, and using a staging build with sharing enabled.")
                    .font(.callout).multilineTextAlignment(.center)
            }
            if let error { Text(error).font(.footnote) }
            Button("Refresh shared space") { Task { await store.refresh() } }
                .buttonStyle(.bordered).frame(minHeight: 44).disabled(scene != .active)
                .padding(.bottom, 8)
        }
        .task(id: scene) {
            guard scene == .active else { return }
            await store.watch()
        }
        .onChange(of: scene) { _, value in
            if value != .active { closeAndReset() }
        }
        .onChange(of: store.scope) { previous, current in
            if previous != nil && previous != current {
                editor = nil
                deleting = nil
                privateCopy = nil
            }
        }
        .onDisappear { closeAndReset() }
        .sheet(item: $editor) { item in
            SharedRelationshipEditor(scope: item.scope, entry: item.draft, previous: item.previous, store: store)
        }
        .alert("Remove this shared entry?", isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } }), presenting: deleting) { record in
            Button("Remove from shared space", role: .destructive) {
                guard let scope = store.scope else { return }
                Task {
                    do { try await store.delete(record, in: scope); error = nil }
                    catch { self.error = error.localizedDescription }
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: { _ in Text("This removes the shared entry for both partners. Any private original stays on this iPhone.") }
    }

    private func closeAndReset() {
        store.reset()
        editor = nil
        deleting = nil
        privateCopy = nil
        error = nil
    }

    private func sharedCard(_ record: SharedRelationshipRecord, scope: RelationshipScope) -> some View {
        let entry = record.entry
        let own = record.isOwned(by: scope)
        return ReachGlassPanel {
            VStack(alignment: .leading, spacing: 10) {
                if let bytes = entry.photo, let image = SharedMemoryPhoto.thumbnail(bytes) {
                    Image(uiImage: image).resizable().scaledToFit()
                        .frame(maxWidth: .infinity, maxHeight: 320)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .accessibilityLabel("Shared memory photograph")
                }
                Text(entry.title).font(.title3.weight(.semibold))
                Text(own ? "Shared by you" : "Shared by your partner").font(.caption.weight(.semibold))
                Text(entry.date, style: .date).font(.caption)
                if !entry.caption.isEmpty { Text(entry.caption) }
                if entry.kind == .goal {
                    ProgressView(value: Double(entry.progress), total: 100) {
                        Text("\(entry.progress)% complete").font(.subheadline)
                    }.tint(.pink)
                }
                if own {
                    HStack {
                        Button("Edit") { editor = Editor(scope: scope, draft: entry, previous: record) }
                        Spacer()
                        Button("Remove", role: .destructive) { deleting = record }
                    }.buttonStyle(.bordered).disabled(store.isWriting)
                }
            }
        }
    }
}

private struct SharedRelationshipEditor: View {
    let scope: RelationshipScope
    let previous: SharedRelationshipRecord?
    @ObservedObject var store: RelationshipSpaceStore
    @Environment(\.dismiss) private var dismiss
    @State private var draft: SharedRelationshipEntry
    @State private var selection: PhotosPickerItem?
    @State private var loadingPhoto = false
    @State private var confirmed: SharedRelationshipConsent?
    @State private var error: String?

    init(scope: RelationshipScope, entry: SharedRelationshipEntry, previous: SharedRelationshipRecord?, store: RelationshipSpaceStore) {
        self.scope = scope
        self.previous = previous
        self.store = store
        _draft = State(initialValue: entry)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("Both authorized partners can see the title, date, text, and any selected photo when you confirm sharing.")
                        .font(.footnote)
                }
                Section {
                    TextField("Title", text: $draft.title, axis: .vertical)
                    DatePicker("Date", selection: $draft.date, displayedComponents: .date)
                    TextField(draft.kind == .response ? "Your voluntary response" : "Caption or details", text: $draft.caption, axis: .vertical)
                        .lineLimit(3...8)
                    if draft.kind == .goal {
                        Stepper("Progress · \(draft.progress)%", value: $draft.progress, in: 0...100, step: 5)
                    }
                }
                if draft.kind == .memory {
                    Section("Optional shared photograph") {
                        if let bytes = draft.photo, let image = UIImage(data: bytes) {
                            Image(uiImage: image).resizable().scaledToFit().frame(maxHeight: 200)
                                .accessibilityLabel("Photograph selected for sharing")
                            Button("Remove photo", role: .destructive) { draft.photo = nil }.disabled(loadingPhoto)
                        }
                        PhotosPicker(selection: $selection, matching: .images) { Label("Choose photograph", systemImage: "photo") }
                            .disabled(loadingPhoto)
                    }
                }
                if let error { Text(error).font(.footnote) }
            }
            .disabled(store.isWriting)
            .scrollDismissesKeyboard(.interactively)
            .reachKeyboardToolbar()
            .navigationTitle(draft.kind.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() }.disabled(store.isWriting) }
                ToolbarItem(placement: .confirmationAction) {
                    Button(previous == nil ? "Share" : "Save changes") {
                        do {
                            confirmed = SharedRelationshipConsent(scope: scope, entry: try draft.validated(), previous: previous)
                        } catch { self.error = error.localizedDescription }
                    }.disabled(loadingPhoto || store.isWriting || store.scope != scope)
                }
            }
            .interactiveDismissDisabled(store.isWriting)
            .confirmationDialog("Share with your partner?", isPresented: Binding(
                get: { confirmed != nil }, set: { if !$0 { confirmed = nil } }
            ), presenting: confirmed) { consent in
                Button(previous == nil ? "Share entry" : "Share changes") {
                    Task {
                        do { try await store.save(consent); dismiss() }
                        catch { self.error = error.localizedDescription }
                    }
                }
                Button("Cancel", role: .cancel) {}
            }
            .task(id: selection) {
                guard let selection else { return }
                loadingPhoto = true
                defer { loadingPhoto = false }
                do {
                    guard let data = try await selection.loadTransferable(type: Data.self) else { throw JournalError.invalidPhoto }
                    try Task.checkCancellation()
                    draft.photo = try SharedMemoryPhoto.prepare(data)
                    error = nil
                } catch is CancellationError {
                    return
                } catch { self.error = error.localizedDescription }
            }
        }
    }
}

@MainActor
private enum SharedMemoryPhoto {
    static func prepare(_ data: Data) throws -> Data {
        guard let image = thumbnail(data) else { throw JournalError.invalidPhoto }
        for quality in [0.72, 0.55, 0.4, 0.25] {
            if let jpeg = image.jpegData(compressionQuality: quality), jpeg.count <= SharedRelationshipEntry.maximumPhotoBytes {
                return jpeg
            }
        }
        throw RelationshipSpaceError.invalid
    }

    static func thumbnail(_ data: Data) -> UIImage? {
        guard data.count <= 12_000_000, let source = CGImageSourceCreateWithData(data as CFData, nil),
              let thumbnail = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: 960
              ] as CFDictionary) else { return nil }
        return UIImage(cgImage: thumbnail)
    }
}
