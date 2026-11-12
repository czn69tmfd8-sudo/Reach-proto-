import CryptoKit
import FirebaseAuth
import FirebaseFirestore
import PhotosUI
import SwiftUI
import UIKit

/// Staging-only live Adventure Book surface. The existing preview remains
/// available and no data is copied from the user's private scrapbook.
struct ReachAdventureBookLive: View {
    @State private var book: AdventureBook?
    @State private var pairCode: String?
    @State private var error: String?
    @State private var busy = false
    @State private var showingNewMemory = false
    @State private var pendingMemory: (memory: AdventureMemory, initialStory: String)?
    @State private var selectedMemory: AdventureMemory?
    @State private var selectedStoryVersion: Timestamp?
    @State private var commentDraft = ""
    @State private var pendingComment: (memoryID: String, text: String, id: String)?
    @State private var photoSelection: PhotosPickerItem?
    @State private var uploadingPhotoFor: AdventureMemory?
    @State private var photoProgress = ""
    @State private var pendingPhoto: AdventurePhotoUpload?
    @State private var pendingPhotoBytes: Data?
    @State private var pendingPhotoPosition = 0
    @State private var recoveryRecord: AdventurePhotoRecoveryRecord?

    private var recoveryJournal: AdventurePhotoRecoveryJournal? {
        guard let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else { return nil }
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return AdventurePhotoRecoveryJournal(fileURL: directory.appendingPathComponent("adventure-photo-recovery.json"))
    }
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicType
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject private var appearance: ReachAppearanceStore
    @State private var page = 0
    @State private var openedMemoryID: String?
    @State private var repository = FirestoreAdventureBookRepository()
    @State private var connectionEpoch = 0
    @State private var connecting = false
    @State private var loadedContentScope = AdventureBookContentScope()

    private var contentScope: AdventureBookContentScope {
        AdventureBookContentScope(orderedIDs: book?.orderedMemories.map(\.id) ?? [],
                                  page: page, openedMemoryID: openedMemoryID)
    }

    var body: some View {
        VStack(spacing: 0) {
            AdventureBookHeader(title: "Our Adventure Book") {
                if let selectedID = openedMemoryID {
                    if let restoredPage = AdventureGalleryPagination.page(
                        forSelectedMemoryID: selectedID,
                        orderedIDs: book?.orderedMemories.map(\.id) ?? []
                    ) {
                        page = restoredPage
                    }
                    openedMemoryID = nil
                } else if page == 0 {
                    dismiss()
                } else {
                    page = 0
                }
            }
            if let error {
                Text(error).font(.footnote).foregroundStyle(.white)
                    .padding(10).background(.black.opacity(0.45), in: RoundedRectangle(cornerRadius: 8))
                if book == nil {
                    Button("Try again") { Task { await connect() } }
                        .disabled(connecting)
                        .buttonStyle(.bordered).tint(.white)
                }
            }
            if pendingMemory != nil && !busy {
                HStack {
                    Button("Retry memory save") { Task { await submitPendingMemory() } }
                    Button("Discard pending save", role: .destructive) {
                        pendingMemory = nil
                        error = nil
                    }
                }
                .buttonStyle(.bordered).tint(.white)
                Text("If the memory was already created, you can edit its story from the memory page.")
                    .font(.caption).foregroundStyle(.white)
            }
            if let book {
                let ordered = book.orderedMemories
                let spreadCount = AdventureGalleryPagination.spreadCount(memoryCount: ordered.count)
                if let selectedID = AdventureGalleryPagination.selectedMemoryID(openedMemoryID, availableIDs: ordered.map(\.id)),
                   let memory = ordered.first(where: { $0.id == selectedID }) {
                    if loadedContentScope.detailID == selectedID {
                        memoryPage(memory)
                    } else {
                        ProgressView("Loading memory…").tint(.white).foregroundStyle(.white)
                    }
                    Button {
                        if let restoredPage = AdventureGalleryPagination.page(
                            forSelectedMemoryID: memory.id, orderedIDs: ordered.map(\.id)
                        ) {
                            page = restoredPage
                        }
                        self.openedMemoryID = nil
                    } label: {
                        Label("Back to memories", systemImage: "chevron.left")
                            .frame(maxWidth: .infinity, minHeight: 44)
                    }
                    .foregroundStyle(.white)
                } else {
                    TabView(selection: $page) {
                        ScrollView {
                            AdventureLeatherCover {
                                withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.4)) { page = 1 }
                            }
                            Text("Decorative cover prints · your memories are inside")
                                .font(.caption2).foregroundStyle(.white)
                        }.tag(0)
                        ForEach(0..<spreadCount, id: \.self) { spread in
                            galleryPage(Array(ordered[AdventureGalleryPagination.memoryRange(spread: spread, memoryCount: ordered.count)]),
                                        spread: spread, totalSpreads: spreadCount)
                                .tag(spread + 1)
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                    .animation(reduceMotion ? nil : .easeInOut(duration: 0.32), value: page)
                    HStack {
                        Button("Previous") { page = AdventureGalleryPagination.clampedPage(page - 1, memoryCount: ordered.count) }.disabled(page == 0)
                        Spacer()
                        Text(page == 0 ? "Cover" : "Memories · \(page) of \(spreadCount)").font(.caption)
                        Spacer()
                        Button("Next") { page = AdventureGalleryPagination.clampedPage(page + 1, memoryCount: ordered.count) }
                            .disabled(page == spreadCount)
                    }
                    .font(.caption).foregroundStyle(.white).padding(.horizontal, 18)
                    .frame(minHeight: 44)
                    .accessibilityElement(children: .contain)
                }
            } else if error == nil {
                ProgressView("Checking private pairing and loading our book…").tint(.white).foregroundStyle(.white)
            }
            if book == nil { Spacer() }
        }
        .onChange(of: book?.orderedMemories.map(\.id) ?? []) { _, ids in
            page = AdventureGalleryPagination.clampedPage(page, memoryCount: ids.count)
            if let selected = openedMemoryID, !ids.contains(selected) {
                openedMemoryID = nil
                commentDraft = ""
            }
        }
        .onChange(of: contentScope, initial: true) { _, scope in
            loadedContentScope = AdventureBookContentScope()
            repository.updateContentScope(scope)
        }
        .background { ReachHomeBackground() }
        .toolbar(.hidden, for: .navigationBar)
        .reachKeyboardToolbar()
        .task(id: scenePhase == .background) {
            if scenePhase != .background { await connect() }
        }
        .task(id: photoSelection) { await uploadSelectedPhoto() }
        .onDisappear { clearPrivateContext() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .background { clearPrivateContext() }
        }
        .sheet(isPresented: $showingNewMemory) {
            AdventureMemoryDraftEditor { title, date, story in
                Task { await create(title: title, date: date, story: story) }
            }
        }
        .sheet(item: $selectedMemory) { memory in
            AdventureStoryEditor(initialText: memory.stories.first(where: {
                $0.authorUID == Auth.auth().currentUser?.uid
            })?.text ?? "") { text in
                let version = selectedStoryVersion
                let epoch = connectionEpoch
                Task { await saveStory(memoryID: memory.id, text: text, version: version, epoch: epoch) }
            }
        }
    }

    private func galleryPage(_ memories: [AdventureMemory], spread: Int, totalSpreads: Int) -> some View {
        AdventureParchmentPage {
            VStack(alignment: .leading, spacing: 18) {
                AdventureGalleryHeading()
                Text("Page \(spread + 1) of \(totalSpreads)")
                    .font(AdventureBookPalette.serif(14, relativeTo: .caption))
                    .frame(maxWidth: .infinity)
                if (book?.memories.count ?? 0) >= 500 {
                    Text("This book has reached the current 500-memory safety limit.")
                        .font(.caption)
                        .accessibilityAddTraits(.isStaticText)
                }
                if memories.isEmpty {
                    Text("Our story begins with the first memory we add.")
                        .font(AdventureBookPalette.handwriting(21))
                        .padding(.vertical, 28)
                }
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: dynamicType.isAccessibilitySize ? 1 : 2), spacing: 18) {
                    ForEach(Array(memories.enumerated()), id: \.element.id) { index, memory in
                        Button {
                            // A draft belongs to one memory only. Never carry it
                            // into a different memory's conversation.
                            if openedMemoryID != memory.id { commentDraft = "" }
                            openedMemoryID = memory.id
                        } label: {
                            VStack(alignment: .leading, spacing: 6) {
                                AdventureMountedFrame(title: memory.title) {
                                    if let coverPhoto = memory.photos.first {
                                        AdventureAuthenticatedPhoto(pairCode: memory.pairCode,
                                            memoryID: memory.id, photo: coverPhoto, compact: true)
                                    } else if page == spread + 1 && !loadedContentScope.photoIDs.contains(memory.id) {
                                        ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
                                    } else {
                                        VStack(spacing: 8) {
                                            Image(systemName: "photo.on.rectangle.angled").font(.title)
                                            Text("No photograph").font(.caption)
                                        }
                                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                                        .background(AdventureBookPalette.paper.opacity(0.45))
                                    }
                                }.frame(height: dynamicType.isAccessibilitySize ? 250 : 160)
                                HStack {
                                    Text(memory.occurredAt, style: .date)
                                        .font(AdventureBookPalette.serif(13, relativeTo: .caption))
                                    Spacer(minLength: 0)
                                    Image(systemName: "heart").foregroundStyle(AdventureBookPalette.burgundy)
                                }.padding(.horizontal, 4)
                            }
                            .foregroundStyle(AdventureBookPalette.ink)
                            .rotationEffect(.degrees(index.isMultiple(of: 2) ? -2 : 2))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Open memory: \(memory.title)")
                        .accessibilityHint("Opens this memory’s stories, photographs and conversation")
                    }
                }
                if AdventureGalleryPagination.canAppendMemory(
                    loadedCount: book?.memories.count ?? 500, queryLimit: 500
                ) {
                    Button { showingNewMemory = true } label: {
                        Label("Add a New Memory", systemImage: "plus")
                            .frame(maxWidth: .infinity, minHeight: 44)
                    }
                    .font(AdventureBookPalette.serif(18)).foregroundStyle(.white)
                    .background(AdventureBookPalette.burgundy, in: Capsule())
                    .disabled(busy || pendingMemory != nil).padding(.horizontal, 14)
                } else {
                    Text("Adding more memories is paused at the current 500-memory safety limit.")
                        .font(.caption)
                        .foregroundStyle(AdventureBookPalette.ink)
                        .accessibilityAddTraits(.isStaticText)
                }
            }
        }
    }

    private func memoryPage(_ memory: AdventureMemory) -> some View {
        AdventureParchmentPage {
            VStack(alignment: .leading, spacing: 14) {
                Text(memory.title).font(AdventureBookPalette.handwriting(28, relativeTo: .title2))
                    .frame(maxWidth: .infinity).multilineTextAlignment(.center)
                Image(systemName: "leaf").foregroundStyle(AdventureBookPalette.gold)
                Text(memory.occurredAt, style: .date).font(.caption)
                ForEach(memory.photos) { photo in
                    VStack(spacing: 8) {
                        AdventureAuthenticatedPhoto(pairCode: memory.pairCode,
                                                    memoryID: memory.id, photo: photo)
                        if !photo.caption.isEmpty {
                            Text(photo.caption)
                                .font(.system(.subheadline, design: .serif)).italic()
                        }
                    }
                    .padding(9)
                    .background(AdventureBookPalette.parchmentLight)
                    .overlay(alignment: .topLeading) { AdventureTape().rotationEffect(.degrees(-38)) }
                    .overlay(alignment: .bottomTrailing) { AdventureTape().rotationEffect(.degrees(-38)) }
                    .rotationEffect(.degrees(memory.photos.first?.id == photo.id ? -1.2 : 1.2))
                    .shadow(color: .black.opacity(0.15), radius: 5, x: 2, y: 4)
                }
                if AdventurePhotoFeatureGate.liveUploadsEnabled {
                    PhotosPicker(selection: $photoSelection, matching: .images) {
                        Label("Choose photo", systemImage: "photo.badge.plus")
                    }
                    .onChange(of: photoSelection) { _, selection in
                        if selection != nil { uploadingPhotoFor = memory }
                    }
                } else {
                    Label("Photos will be available after secure Storage activation. Memories, stories and comments still work.", systemImage: "photo.on.rectangle.angled")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if !photoProgress.isEmpty {
                    Text(photoProgress).font(.caption)
                }
                if AdventurePhotoFeatureGate.liveUploadsEnabled && pendingPhoto != nil && pendingPhotoBytes != nil {
                    Button("Retry incomplete photo") {
                        Task { await retryPendingPhoto() }
                    }.buttonStyle(.bordered)
                }
                if recoveryRecord != nil && pendingPhotoBytes == nil {
                    Text("An earlier upload needs recovery. Reselect the same photograph; no replacement upload will occur without verification.")
                        .font(.caption)
                }
                let ownUID = Auth.auth().currentUser?.uid
                let ownStory = memory.stories.first(where: { $0.authorUID == ownUID })?.text ?? ""
                let partnerStory = memory.stories.first(where: { $0.authorUID != ownUID })?.text ?? ""
                let columns = dynamicType.isAccessibilitySize
                    ? AnyLayout(VStackLayout(alignment: .leading, spacing: 12))
                    : AnyLayout(HStackLayout(alignment: .top, spacing: 10))
                columns {
                    AdventureStoryCard(heading: "\(appearance.preferences.partnerLabel)’s Story", text: partnerStory)
                    AdventureStoryCard(heading: "My Story", text: ownStory, tint: .blue)
                }
                Button("Write or edit my story") { Task { await openStoryEditor(memory) } }
                    .buttonStyle(.bordered)
                Divider()
                Label("Our Conversation", systemImage: "bubble.left.and.bubble.right")
                    .font(AdventureBookPalette.script(24, relativeTo: .headline))
                ForEach(memory.comments) { comment in
                    Text(comment.text)
                        .font(.system(.subheadline, design: .serif))
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.white.opacity(0.3), in: RoundedRectangle(cornerRadius: 8))
                }
                TextField("Leave a comment", text: $commentDraft)
                    .textFieldStyle(.roundedBorder)
                Button("Post comment") {
                    let text = commentDraft
                    Task { await postComment(memoryID: memory.id, text: text) }
                }
                .disabled(busy || commentDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
    }

    private var addPage: some View {
        AdventureParchmentPage {
            VStack(spacing: 22) {
                Spacer(minLength: 55)
                Image(systemName: "heart.text.square")
                    .font(.system(size: 52))
                    .foregroundStyle(AdventureBookPalette.gold)
                Text("Our Next Adventure")
                    .font(.system(.title, design: .serif).bold())
                Text("Every memory deserves its own chapter.")
                    .font(.system(.body, design: .serif)).italic()
                    .multilineTextAlignment(.center)
                Button("Add a Memory") { showingNewMemory = true }
                    .buttonStyle(.borderedProminent).disabled(busy)
                Spacer(minLength: 55)
            }
            .frame(maxWidth: .infinity)
        }
    }

    private func clearPrivateContext() {
        connectionEpoch += 1
        repository.stopObserving()
        connecting = false
        book = nil
        pairCode = nil
        error = nil
        busy = false
        showingNewMemory = false
        pendingMemory = nil
        selectedMemory = nil
        selectedStoryVersion = nil
        openedMemoryID = nil
        loadedContentScope = AdventureBookContentScope()
        commentDraft = ""
        pendingComment = nil
        photoSelection = nil
        uploadingPhotoFor = nil
        photoProgress = ""
        pendingPhoto = nil
        pendingPhotoBytes = nil
        pendingPhotoPosition = 0
        recoveryRecord = nil
    }

    private func connect() async {
        guard !connecting, scenePhase != .background, !Task.isCancelled else { return }
        clearPrivateContext()
        connecting = true
        let epoch = connectionEpoch
        defer { if connectionEpoch == epoch { connecting = false } }
        do {
            try FirebaseBootstrap.configureStaging()
            guard let uid = Auth.auth().currentUser?.uid else {
                throw AdventureBookRepositoryError.unauthorized
            }
            let lock = try await Firestore.firestore()
                .document("nativeStaging/v1/memberLocks/\(uid)").getDocument(source: .server)
            guard let code = lock.data()?["pairCode"] as? String else {
                throw AdventureBookRepositoryError.notPaired
            }
            guard connectionEpoch == epoch, !Task.isCancelled else { return }
            pairCode = code
            if let saved = try recoveryJournal?.load(), saved.upload.ownerUID == uid,
               saved.upload.pairCode == code {
                var recovered = saved.upload
                guard recovered.prepareForRecovery(as: uid) else {
                    throw AdventureBookRepositoryError.conflict
                }
                let restored = AdventurePhotoRecoveryRecord(upload: recovered,
                    sha256: saved.sha256, byteCount: saved.byteCount,
                    caption: saved.caption, position: saved.position)
                try recoveryJournal?.save(restored)
                recoveryRecord = restored
                pendingPhoto = recovered
                pendingPhotoPosition = restored.position
            }
            try await repository.observe(pairCode: code) { result in
                guard connectionEpoch == epoch else { return }
                switch result {
                case .success(let updated):
                    loadedContentScope = repository.loadedScope
                    book = updated
                case .failure(let failure):
                    clearPrivateContext()
                    error = failure.localizedDescription
                }
            }
        } catch {
            guard connectionEpoch == epoch else { return }
            clearPrivateContext()
            if !(error is CancellationError) { self.error = error.localizedDescription }
        }
    }

    private func create(title: String, date: Date, story: String) async {
        guard !busy, pendingMemory == nil, let code = pairCode,
              let uid = Auth.auth().currentUser?.uid else { return }
        guard let currentBook = book,
              AdventureGalleryPagination.canAppendMemory(loadedCount: currentBook.memories.count, queryLimit: 500),
              let nextOrder = AdventureGalleryPagination.nextPageOrder(
                  existing: currentBook.memories.map(\.pageOrder)
              ) else {
            error = AdventureBookRepositoryError.conflict.localizedDescription
            return
        }
        let memory = AdventureMemory(id: UUID().uuidString.lowercased(), pairCode: code, creatorUID: uid,
                                     title: title, occurredAt: date, stories: [], photos: [],
                                     comments: [], pageOrder: nextOrder)
        pendingMemory = (memory, story)
        await submitPendingMemory()
    }

    private func submitPendingMemory() async {
        guard !busy, let pendingMemory, pendingMemory.memory.pairCode == pairCode,
              pendingMemory.memory.creatorUID == Auth.auth().currentUser?.uid else { return }
        let epoch = connectionEpoch
        busy = true
        defer { if connectionEpoch == epoch { busy = false } }
        do {
            try await repository.createMemory(pendingMemory.memory, initialStory: pendingMemory.initialStory)
            guard connectionEpoch == epoch else { return }
            self.pendingMemory = nil
            error = nil
        } catch {
            if connectionEpoch == epoch { self.error = error.localizedDescription }
        }
    }

    private func openStoryEditor(_ memory: AdventureMemory) async {
        guard let code = pairCode, let uid = Auth.auth().currentUser?.uid else { return }
        let epoch = connectionEpoch
        do {
            let current = try await FirestoreAdventureStoryTransport()
                .loadOwnStory(pairCode: code, memoryID: memory.id, uid: uid)
            guard connectionEpoch == epoch, openedMemoryID == memory.id else { return }
            selectedStoryVersion = current?.version
            var editorMemory = memory
            editorMemory.stories.removeAll { $0.authorUID == uid }
            if let current {
                editorMemory.stories.append(.init(authorUID: uid, text: current.text,
                                                  updatedAt: Date()))
            }
            selectedMemory = editorMemory
        } catch {
            if connectionEpoch == epoch { self.error = error.localizedDescription }
        }
    }

    private func saveStory(memoryID: String, text: String, version: Timestamp?, epoch: Int) async {
        guard connectionEpoch == epoch, let code = pairCode, Auth.auth().currentUser != nil else { return }
        do {
            // Use the exact version captured when the editor opened.
            // Transaction retries reject a stale version if the partner or
            // another session changed the story in the meantime.
            try await repository.saveOwnStory(pairCode: code, memoryID: memoryID,
                                              text: text, expectedVersion: version)
        } catch {
            if connectionEpoch == epoch { self.error = error.localizedDescription }
        }
    }

    private func postComment(memoryID: String, text: String) async {
        guard let code = pairCode, !busy else { return }
        let epoch = connectionEpoch
        let commentID: String
        if let pendingComment, pendingComment.memoryID == memoryID, pendingComment.text == text {
            commentID = pendingComment.id
        } else {
            commentID = UUID().uuidString.lowercased()
            pendingComment = (memoryID, text, commentID)
        }
        busy = true
        defer { if connectionEpoch == epoch { busy = false } }
        do {
            try await repository.postComment(pairCode: code, memoryID: memoryID, text: text, commentID: commentID)
            guard connectionEpoch == epoch else { return }
            pendingComment = nil
            error = nil
            // Only clear the draft after the server accepts it, and never
            // erase a draft that the user has since edited or moved away from.
            if openedMemoryID == memoryID, commentDraft == text {
                commentDraft = ""
            }
        } catch {
            if connectionEpoch == epoch { self.error = error.localizedDescription }
        }
    }
    private func uploadSelectedPhoto() async {
        guard AdventurePhotoFeatureGate.liveUploadsEnabled,
              let selection = photoSelection, let memory = uploadingPhotoFor,
              let uid = Auth.auth().currentUser?.uid else { return }
        let epoch = connectionEpoch
        defer {
            if connectionEpoch == epoch {
                photoSelection = nil
                uploadingPhotoFor = nil
            }
        }
        do {
            photoProgress = "Preparing private photo…"
            guard let original = try await selection.loadTransferable(type: Data.self) else {
                throw AdventureBookRepositoryError.invalidMemory
            }
            guard connectionEpoch == epoch, !Task.isCancelled else { return }
            // Normalize Photos assets (including HEIC) to actual JPEG bytes.
            // Reject oversized files before contacting Storage.
            guard let decoded = UIImage(data: original),
                  let jpeg = decoded.jpegData(compressionQuality: 0.78),
                  !jpeg.isEmpty, jpeg.count <= 15_728_640 else {
                throw AdventureBookRepositoryError.invalidMemory
            }
            let hash = SHA256.hash(data: jpeg).map { String(format: "%02x", $0) }.joined()
            if let saved = recoveryRecord {
                guard saved.upload.memoryID == memory.id,
                      saved.canResume(as: uid, withHash: hash, byteCount: jpeg.count) else {
                    throw AdventureBookRepositoryError.conflict
                }
                pendingPhoto = saved.upload
                pendingPhotoPosition = saved.position
            } else {
                let operation = AdventurePhotoUpload(pairCode: memory.pairCode,
                                                     memoryID: memory.id,
                                                     photoID: UUID().uuidString.lowercased(),
                                                     ownerUID: uid)
                let record = AdventurePhotoRecoveryRecord(upload: operation,
                    sha256: hash, byteCount: jpeg.count, caption: "", position: memory.photos.count)
                try recoveryJournal?.save(record)
                recoveryRecord = record
                pendingPhoto = operation
                pendingPhotoPosition = memory.photos.count
            }
            pendingPhotoBytes = jpeg
            await retryPendingPhoto()
        } catch {
            guard connectionEpoch == epoch else { return }
            photoProgress = "Photo upload incomplete"
            self.error = error.localizedDescription
        }
    }

    private func retryPendingPhoto() async {
        guard AdventurePhotoFeatureGate.liveUploadsEnabled,
              var operation = pendingPhoto, let bytes = pendingPhotoBytes else { return }
        let epoch = connectionEpoch
        let transport = FirestoreAdventurePhotoTransport()
        do {
            if operation.phase == .prepared || operation.phase == .retryRequired {
                photoProgress = "Uploading private photo…"
                try await transport.uploadJPEG(bytes, upload: &operation)
                guard connectionEpoch == epoch else { return }
                pendingPhoto = operation
                if let previous = recoveryRecord {
                    let updated = AdventurePhotoRecoveryRecord(upload: operation,
                        sha256: previous.sha256, byteCount: previous.byteCount,
                        caption: previous.caption, position: previous.position)
                    try recoveryJournal?.save(updated)
                    recoveryRecord = updated
                }
            }
            guard operation.phase == .uploadedAwaitingMetadata else {
                throw AdventureBookRepositoryError.conflict
            }
            photoProgress = "Publishing private photo…"
            try await transport.publish(&operation, caption: "", position: pendingPhotoPosition)
            guard connectionEpoch == epoch else { return }
            try recoveryJournal?.clear()
            recoveryRecord = nil
            pendingPhoto = nil
            pendingPhotoBytes = nil
            photoProgress = "Photo saved"
        } catch {
            guard connectionEpoch == epoch else { return }
            pendingPhoto = operation
            if let previous = recoveryRecord {
                let updated = AdventurePhotoRecoveryRecord(upload: operation,
                    sha256: previous.sha256, byteCount: previous.byteCount,
                    caption: previous.caption, position: previous.position)
                try? recoveryJournal?.save(updated)
                recoveryRecord = updated
            }
            photoProgress = "Photo incomplete — retry without replacing existing data"
            self.error = error.localizedDescription
        }
    }

}

private struct AdventureAuthenticatedPhoto: View {
    let pairCode: String
    let memoryID: String
    let photo: AdventureMemory.Photo
    var compact = false
    @State private var image: UIImage?
    @State private var error: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: compact ? .fill : .fit)
                    .frame(maxWidth: .infinity)
                    .frame(height: compact ? 112 : 230)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: compact ? 3 : 10))
            } else if let error {
                Label(error, systemImage: "lock.fill").font(.caption)
            } else {
                ProgressView("Loading private photo…")
            }
            if !compact && !photo.caption.isEmpty {
                Text(photo.caption).font(.caption)
            }
        }
        .task(id: photo.id) {
            do {
                let bytes = try await FirestoreAdventurePhotoTransport()
                    .readPhoto(pairCode: pairCode, memoryID: memoryID, photoID: photo.id)
                guard let decoded = UIImage(data: bytes) else {
                    throw AdventureBookRepositoryError.unavailable
                }
                guard !Task.isCancelled else { return }
                image = decoded
            } catch {
                guard !Task.isCancelled else { return }
                image = nil
                self.error = "Photo unavailable"
            }
        }
        .onDisappear { image = nil }
    }
}
