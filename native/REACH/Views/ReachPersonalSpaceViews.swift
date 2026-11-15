import SwiftUI
import PhotosUI
import FirebaseAuth
import UIKit

struct ReachUsView: View {
    var body: some View {
        ReachPage {
            Text("Us").font(.largeTitle.bold())
            NavigationLink {
                ReachAdventureBookLive()
            } label: {
                AdventureLeatherArtwork(showSamplePrints: false)
                    .aspectRatio(0.91, contentMode: .fit)
                    .frame(maxWidth: 390)
                    .padding(.vertical, 8)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Open Our Adventure Book")
            NavigationLink {
                ReachPage {
                    Text("Our Profile").font(.largeTitle.bold())
                    ReachProfilePanel()
                }
            } label: {
                Label("Our Profile", systemImage: "person.crop.circle")
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(.bordered)
        }
        .toolbar(.hidden, for: .navigationBar)
    }
}

private struct ReachProfilePanel: View {
    @EnvironmentObject private var appearance: ReachAppearanceStore
    #if REACH_SHARED_PROFILE_PHOTOS
    private let slot: ReachAppearanceStore.Photo = .background
    #else
    @State private var slot: ReachAppearanceStore.Photo = .background
    #endif
    @State private var selection: PhotosPickerItem?
    @State private var imageError: String?
    @State private var loading = false

    var body: some View {
        let pickerTitle = slot == .background ? "Choose a background for this iPhone" : "Choose local photograph"
        VStack(spacing: 16) {
            ReachGlassPanel {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Make this space yours").font(.title2.weight(.semibold))
                    Text("Appearance settings stay on this iPhone. Display names and backgrounds are local to this iPhone.")
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

                }
                .textFieldStyle(.roundedBorder)
                .submitLabel(.done).onSubmit { ReachKeyboard.dismiss() }
            }
            ReachGlassPanel {
                VStack(alignment: .leading, spacing: 16) {
                    #if REACH_SHARED_PROFILE_PHOTOS
                    SharedProfilePhotographs(editable: true) { own, partner in
                        HStack(spacing: 24) {
                            profilePortrait(own, name: appearance.preferences.ownLabel)
                            profilePortrait(partner, name: appearance.preferences.partnerLabel)
                        }
                    }
                    Divider()
                    #else
                    Picker("Local photo to change", selection: $slot) {
                        ForEach(ReachAppearanceStore.Photo.allCases) { value in Text(value.label).tag(value) }
                    }.pickerStyle(.menu).disabled(loading)
                    #endif
                    PhotosPicker(selection: $selection, matching: .images) {
                        Label(pickerTitle, systemImage: "photo")
                            .frame(minHeight: 44)
                    }.disabled(loading)
                    if appearance.image(for: slot) != nil {
                        Button(slot == .background ? "Restore original sunset" : "Remove local photo", role: .destructive) {
                            do { try appearance.setPhoto(nil, for: slot) } catch { imageError = error.localizedDescription }
                        }.frame(minHeight: 44).disabled(loading)
                    }
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

    private func profilePortrait(_ image: UIImage?, name: String) -> some View {
        VStack {
            ZStack {
                Circle().fill(.ultraThinMaterial)
                if let image { Image(uiImage: image).resizable().scaledToFill() }
                else { Image(systemName: "person.crop.circle").font(.largeTitle) }
            }
            .frame(width: 74, height: 74)
            .clipShape(Circle())
            Text(name).font(.caption)
        }
    }
}

#if REACH_SHARED_PROFILE_PHOTOS
struct SharedProfilePhotographs<Portraits: View>: View {
    struct Pair: Equatable {
        let code: String
        let own: String
        let partner: String
    }

    let editable: Bool
    private let portraits: (UIImage?, UIImage?) -> Portraits

    @Environment(\.scenePhase) private var scene
    @State private var pair: Pair?
    @State private var own: UIImage?
    @State private var partner: UIImage?
    @State private var selection: PhotosPickerItem?
    @State private var photoError: String?
    @State private var saving = false
    @State private var authRevision = 0
    @State private var mutationRevision = 0

    init(editable: Bool, @ViewBuilder portraits: @escaping (UIImage?, UIImage?) -> Portraits) {
        self.editable = editable
        self.portraits = portraits
    }

    var body: some View {
        VStack(spacing: 12) {
            portraits(own, partner)
            if editable {
                PhotosPicker(selection: $selection, matching: .images) {
                    Label("Choose my profile photo", systemImage: "person.crop.circle")
                }.disabled(pair == nil || saving)
                if own != nil {
                    Button("Remove my profile photo", role: .destructive) {
                        Task { await save(nil) }
                    }.disabled(pair == nil || saving)
                }
                if let photoError { Text(photoError).font(.footnote) }
            }
        }
        .task {
            guard (try? AdventurePrivatePhotoClient.profileTransport()) != nil else { return }
            let auth = Auth.auth()
            let (events, continuation) = AsyncStream<Void>.makeStream()
            let handle = auth.addStateDidChangeListener { _, _ in _ = continuation.yield(()) }
            defer { auth.removeStateDidChangeListener(handle) }
            for await _ in events {
                clear()
                authRevision += 1
            }
        }
        .task(id: "\(scene)-\(authRevision)") {
            guard scene == .active else { clear(); return }
            while !Task.isCancelled {
                await refresh()
                do { try await Task.sleep(for: .seconds(5)) }
                catch { return }
            }
        }
        .task(id: selection) {
            guard let selection else { return }
            await save(selection)
            if self.selection == selection { self.selection = nil }
        }
        .onDisappear { clear() }
    }

    private static func decodedPortrait(_ data: Data) -> UIImage? {
        guard let thumbnail = AdventurePhotoPreviewEncoder.thumbnail(data, maximumEdge: 320) else { return nil }
        return UIImage(cgImage: thumbnail)
    }

    private func clear() {
        pair = nil
        own = nil
        partner = nil
        selection = nil
    }

    private func refresh() async {
        let revision = mutationRevision
        do {
            let client = try AdventurePrivatePhotoClient.profileTransport()
            guard let uid = Auth.auth().currentUser?.uid else {
                throw AdventurePrivatePhotoClient.Failure.unauthorized
            }
            let store = FirestorePairStore()
            guard let lock = try await store.memberLock(uid: uid),
                  let record = try await store.pair(code: lock.pairCode),
                  record.isUsable(by: uid),
                  let other = record.partnerUID(for: uid), other != uid else {
                throw AdventurePrivatePhotoClient.Failure.unauthorized
            }
            let scope = Pair(code: lock.pairCode, own: uid, partner: other)
            guard !Task.isCancelled, scene == .active, Auth.auth().currentUser?.uid == uid else { return }
            if pair != scope { clear() }
            async let ownBytes = client.readProfilePhoto(pairCode: scope.code, ownerUID: uid)
            async let partnerBytes = client.readProfilePhoto(pairCode: scope.code, ownerUID: other)
            let images = try await (ownBytes, partnerBytes)
            guard !Task.isCancelled, scene == .active, Auth.auth().currentUser?.uid == uid else { return }
            pair = scope
            if revision == mutationRevision && !saving {
                own = images.0.flatMap { Self.decodedPortrait($0) }
            }
            partner = images.1.flatMap { Self.decodedPortrait($0) }
            if !saving { photoError = nil }
        } catch {
            guard !Task.isCancelled, scene == .active else { return }
            clear()
            photoError = "Shared profile photos are unavailable."
        }
    }

    private func save(_ item: PhotosPickerItem?) async {
        guard !saving, let scope = pair, scene == .active else { return }
        saving = true
        mutationRevision += 1
        defer {
            mutationRevision += 1
            saving = false
        }
        do {
            var encoded: Data?
            if let item {
                guard let bytes = try await item.loadTransferable(type: Data.self),
                      let jpeg = AdventurePhotoPreviewEncoder.encode(bytes) else {
                    throw AdventurePrivatePhotoClient.Failure.malformed
                }
                encoded = jpeg
            }
            guard !Task.isCancelled, pair == scope, scene == .active else { return }
            try await AdventurePrivatePhotoClient.profileTransport()
                .saveOwnProfilePhoto(pairCode: scope.code, uid: scope.own, bytes: encoded)
            guard !Task.isCancelled, pair == scope, scene == .active else { return }
            own = encoded.flatMap { Self.decodedPortrait($0) }
            photoError = nil
        } catch {
            guard !Task.isCancelled, pair == scope else { return }
            photoError = "Couldn’t save your profile photo. Try again."
        }
    }
}
#endif
