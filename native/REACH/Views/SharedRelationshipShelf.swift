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
            Label("Shared · visible to both authorized partners", systemImage: "person.2")
                .font(.caption.weight(.semibold))
                .multilineTextAlignment(.center)
            if scene == .active, let scope = store.scope, store.canRead(at: Date()) {
                if store.status == .offline {
                    Text("Offline · showing recently verified entries. Reconnect and refresh before sharing or removing an entry.")
                        .font(.footnote).multilineTextAlignment(.center)
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
                LazyVStack(spacing: 14) {
                    ForEach(visible) { record in
                        sharedCard(record, scope: scope)
                    }
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
                        }.buttonStyle(.bordered).disabled(store.isRefreshing || store.isWriting)
                    }
                }
            } else if store.status == .loading || store.isRefreshing {
                ProgressView("Checking shared access…")
            } else {
                Text(store.status == .connectionUnavailable
                     ? "Couldn’t connect to the shared space. Go online and try again."
                     : "Shared access is unavailable. Check that you’re paired and that sharing is enabled for this staging pair.")
                    .font(.callout).multilineTextAlignment(.center)
            }
            if privateCopy != nil {
                Button("Cancel sharing a copy") { privateCopy = nil }
                    .buttonStyle(.bordered).frame(minHeight: 44)
                Text("Your original stays in Private.").font(.caption)
            }
            if let error { Text(error).font(.footnote) }
            if store.isWriting {
                ProgressView("Saving shared change…")
            } else if store.isRefreshing, store.scope != nil {
                ProgressView("Refreshing shared space…")
            }
            Button("Refresh shared space") { Task { await store.refresh() } }
                .buttonStyle(.bordered).frame(minHeight: 44)
                .disabled(scene != .active || store.isRefreshing || store.isWriting)
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
                if let bytes = entry.photo {
                    SharedPhotoPreview(bytes: bytes, height: 320, label: "Shared memory photograph")
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
                            .disabled(!store.canWrite)
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
                    if store.status == .offline {
                        Text("You can keep editing this draft here. Reconnect and refresh before sharing.")
                            .font(.footnote)
                    }
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
                .disabled(store.isWriting)
                if draft.kind == .memory {
                    Section("Optional shared photograph") {
                        if let bytes = draft.photo {
                            SharedPhotoPreview(bytes: bytes, height: 200, label: "Photograph selected for sharing")
                            Button("Remove photo", role: .destructive) { draft.photo = nil }.disabled(loadingPhoto)
                        }
                        PhotosPicker(selection: $selection, matching: .images) { Label("Choose photograph", systemImage: "photo") }
                            .disabled(loadingPhoto)
                        if loadingPhoto { ProgressView("Preparing photo…") }
                    }
                    .disabled(store.isWriting)
                }
                if store.isWriting { ProgressView("Saving shared change…") }
                else if store.isRefreshing { ProgressView("Refreshing shared access…") }
                if let error { Text(error).font(.footnote) }
            }
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
                    }.disabled(loadingPhoto || !store.canWrite || store.scope != scope)
                }
            }
            .interactiveDismissDisabled(store.isWriting)
            .toolbar {
                if store.status == .offline {
                    ToolbarItem(placement: .bottomBar) {
                        Button("Refresh connection") { Task { await store.refresh() } }
                            .disabled(store.isRefreshing || store.isWriting)
                    }
                }
            }
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

private struct SharedPhotoPreview: View {
    let bytes: Data
    let height: CGFloat
    let label: String
    @State private var decoded: (source: Data, image: UIImage?)?

    var body: some View {
        Group {
            if let decoded, decoded.source == bytes {
                if let image = decoded.image {
                    Image(uiImage: image).resizable().scaledToFit()
                        .frame(maxWidth: .infinity, maxHeight: height)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .accessibilityLabel(label)
                } else {
                    Label("Photo preview unavailable", systemImage: "photo").font(.caption)
                }
            } else {
                ProgressView("Loading photo preview…").frame(maxWidth: .infinity, minHeight: 48)
            }
        }
        .task(id: bytes) {
            guard !Task.isCancelled, decoded?.source != bytes else { return }
            decoded = (bytes, SharedMemoryPhoto.thumbnail(bytes, maxDimension: 640))
        }
        .onDisappear { decoded = nil }
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

    static func thumbnail(_ data: Data, maxDimension: Int = 960) -> UIImage? {
        guard data.count <= 12_000_000, let source = CGImageSourceCreateWithData(data as CFData, nil),
              let thumbnail = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: maxDimension
              ] as CFDictionary) else { return nil }
        return UIImage(cgImage: thumbnail)
    }
}
