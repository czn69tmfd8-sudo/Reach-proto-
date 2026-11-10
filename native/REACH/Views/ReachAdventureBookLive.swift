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
    @State private var selectedMemory: AdventureMemory?
    @State private var selectedStoryVersion: Timestamp?
    @State private var commentDraft = ""
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
    @State private var page = 0
    @State private var repository = FirestoreAdventureBookRepository()

    var body: some View {
        ReachPage {
            Text("Our Adventure Book")
                .font(.system(.largeTitle, design: .serif).bold())
            Text("Two hearts. Two stories. One adventure.")
                .font(.subheadline).italic()
            if let error {
                Text(error).font(.footnote).foregroundStyle(.red)
                Button("Try again") { Task { await connect() } }
                    .buttonStyle(.bordered)
            }
            if let book {
                let ordered = book.orderedMemories
                TabView(selection: $page) {
                    AdventureLeatherCover { withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.4)) { page = 1 } }.tag(0)
                    galleryPage(ordered).tag(1)
                    ForEach(Array(ordered.enumerated()), id: \.element.id) { index, memory in
                        memoryPage(memory).tag(index + 2)
                    }
                    addPage.tag(ordered.count + 2)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .frame(height: min(max(UIScreen.main.bounds.height * 0.65, 440), 710))
                .animation(reduceMotion ? nil : .easeInOut(duration: 0.38), value: page)
                HStack {
                    Button("Previous") { page = max(0, page - 1) }.disabled(page == 0)
                    Spacer()
                    Text("Page \(page + 1) of \(ordered.count + 3)").font(.caption)
                    Spacer()
                    Button("Next") { page = min(ordered.count + 2, page + 1) }
                        .disabled(page == ordered.count + 2)
                }.buttonStyle(.bordered)
            } else if error == nil {
                ProgressView("Checking private pairing and loading our book…")
            }
        }
        .task { await connect() }
        .task(id: photoSelection) { await uploadSelectedPhoto() }
        .onDisappear { repository.stopObserving() }
        .sheet(isPresented: $showingNewMemory) {
            AdventureMemoryDraftEditor { title, date, story in
                Task { await create(title: title, date: date, story: story) }
            }
        }
        .sheet(item: $selectedMemory) { memory in
            AdventureStoryEditor(initialText: memory.stories.first(where: {
                $0.authorUID == Auth.auth().currentUser?.uid
            })?.text ?? "") { text in
                Task { await saveStory(memoryID: memory.id, text: text) }
            }
        }
    }

    private func galleryPage(_ memories: [AdventureMemory]) -> some View {
        AdventureParchmentPage {
            VStack(alignment: .leading, spacing: 16) {
                Text("Our Shared Memories")
                    .font(.system(.title, design: .serif).bold())
                Text("Every chapter is ours to revisit")
                    .font(.system(.subheadline, design: .serif)).italic()
                Image(systemName: "leaf")
                    .foregroundStyle(AdventureBookPalette.gold)
                if memories.isEmpty {
                    Text("Our story begins with the first memory we add.")
                        .font(.system(.body, design: .serif))
                }
                ForEach(Array(memories.enumerated()), id: \.element.id) { index, memory in
                    Button {
                        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.38)) {
                            page = index + 2
                        }
                    } label: {
                        HStack(spacing: 14) {
                            Image(systemName: "photo.on.rectangle.angled")
                                .font(.title2)
                                .frame(width: 54, height: 54)
                                .background(.white.opacity(0.55),
                                            in: RoundedRectangle(cornerRadius: 7))
                            VStack(alignment: .leading, spacing: 5) {
                                Text(memory.title)
                                    .font(.system(.headline, design: .serif))
                                Text(memory.occurredAt, style: .date)
                                    .font(.caption)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                        }
                        .foregroundStyle(AdventureBookPalette.ink)
                        .padding(11)
                        .background(.white.opacity(0.32),
                                    in: RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint("Open memory page")
                }
            }
        }
    }

    private func memoryPage(_ memory: AdventureMemory) -> some View {
        AdventureParchmentPage {
            VStack(alignment: .leading, spacing: 14) {
                Text(memory.title).font(.system(.title, design: .serif).bold())
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
                    .background(.white.opacity(0.65), in: RoundedRectangle(cornerRadius: 4))
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
                AdventureStoryCard(heading: "Partner’s Story", text: partnerStory)
                AdventureStoryCard(heading: "My Story", text: ownStory)
                Button("Write or edit my story") { Task { await openStoryEditor(memory) } }
                    .buttonStyle(.bordered)
                Divider()
                Label("Our Conversation", systemImage: "bubble.left.and.bubble.right")
                    .font(.system(.headline, design: .serif))
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
                    commentDraft = ""
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

    private func connect() async {
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
            let loaded = try await repository.load(pairCode: code)
            book = loaded
            error = nil
            try await repository.observe(pairCode: code) { result in
                switch result {
                case .success(let updated): book = updated
                case .failure(let failure):
                    book = nil
                    error = failure.localizedDescription
                }
            }
        } catch {
            book = nil
            self.error = error.localizedDescription
        }
    }

    private func create(title: String, date: Date, story: String) async {
        guard let code = pairCode, let uid = Auth.auth().currentUser?.uid else { return }
        busy = true
        defer { busy = false }
        do {
            let id = UUID().uuidString.lowercased()
            let memory = AdventureMemory(id: id, pairCode: code, creatorUID: uid,
                                         title: title, occurredAt: date, stories: [],
                                         photos: [], comments: [], pageOrder: book?.memories.count ?? 0)
            try await repository.createMemory(memory)
            if !story.isEmpty {
                try await repository.saveOwnStory(pairCode: code, memoryID: id,
                                                  text: story, expectedVersion: nil)
            }
            book = try await repository.load(pairCode: code)
        } catch { self.error = error.localizedDescription }
    }

    private func openStoryEditor(_ memory: AdventureMemory) async {
        guard let code = pairCode, let uid = Auth.auth().currentUser?.uid else { return }
        do {
            let current = try await FirestoreAdventureStoryTransport()
                .loadOwnStory(pairCode: code, memoryID: memory.id, uid: uid)
            selectedStoryVersion = current?.version
            var editorMemory = memory
            editorMemory.stories.removeAll { $0.authorUID == uid }
            if let current {
                editorMemory.stories.append(.init(authorUID: uid, text: current.text,
                                                  updatedAt: Date()))
            }
            selectedMemory = editorMemory
        } catch { self.error = error.localizedDescription }
    }

    private func saveStory(memoryID: String, text: String) async {
        guard let code = pairCode, Auth.auth().currentUser != nil else { return }
        do {
            // Use the exact version captured when the editor opened.
            // Transaction retries reject a stale version if the partner or
            // another session changed the story in the meantime.
            try await repository.saveOwnStory(pairCode: code, memoryID: memoryID,
                                              text: text, expectedVersion: selectedStoryVersion)
        } catch { self.error = error.localizedDescription }
    }

    private func postComment(memoryID: String, text: String) async {
        guard let code = pairCode else { return }
        do { try await repository.postComment(pairCode: code, memoryID: memoryID, text: text) }
        catch { self.error = error.localizedDescription }
    }
    private func uploadSelectedPhoto() async {
        guard AdventurePhotoFeatureGate.liveUploadsEnabled,
              let selection = photoSelection, let memory = uploadingPhotoFor,
              let uid = Auth.auth().currentUser?.uid else { return }
        defer { photoSelection = nil; uploadingPhotoFor = nil }
        do {
            photoProgress = "Preparing private photo…"
            guard let original = try await selection.loadTransferable(type: Data.self) else {
                throw AdventureBookRepositoryError.invalidMemory
            }
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
            photoProgress = "Upload incomplete. Nothing was overwritten."
            self.error = error.localizedDescription
        }
    }

    private func retryPendingPhoto() async {
        guard AdventurePhotoFeatureGate.liveUploadsEnabled,
              var operation = pendingPhoto, let bytes = pendingPhotoBytes else { return }
        let transport = FirestoreAdventurePhotoTransport()
        do {
            if operation.phase == .prepared || operation.phase == .retryRequired {
                photoProgress = "Uploading private photo…"
                try await transport.uploadJPEG(bytes, upload: &operation)
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
            try recoveryJournal?.clear()
            recoveryRecord = nil
            pendingPhoto = nil
            pendingPhotoBytes = nil
            photoProgress = "Photo saved"
        } catch {
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
    @State private var image: UIImage?
    @State private var error: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let image {
                Image(uiImage: image)
                    .resizable().scaledToFit()
                    .frame(maxHeight: 230)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            } else if let error {
                Label(error, systemImage: "lock.fill").font(.caption)
            } else {
                ProgressView("Loading private photo…")
            }
            if !photo.caption.isEmpty {
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
                image = decoded
            } catch {
                image = nil
                self.error = "Photo unavailable"
            }
        }
        .onDisappear { image = nil }
    }
}
