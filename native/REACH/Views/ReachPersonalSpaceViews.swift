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
                navigationCard("Our Adventure Book", icon: "book.closed")
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Open Our Adventure Book")
            NavigationLink {
                ReachMessengerView()
            } label: {
                navigationCard("Our Messages", icon: "bubble.left.and.bubble.right")
            }
            .buttonStyle(.plain)
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

    private func navigationCard(_ title: String, icon: String) -> some View {
        ReachGlassPanel {
            HStack {
                Label(title, systemImage: icon).font(.headline)
                Spacer()
                Image(systemName: "chevron.right").accessibilityHidden(true)
            }
        }
    }
}

struct ReachProfilePanel: View {
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
    let editable: Bool
    private let enabled: Bool
    private let expectedScope: ReachProfilePhotoScope?
    private let portraits: (UIImage?, UIImage?) -> Portraits

    @Environment(\.scenePhase) private var scene
    @State private var photos = ReachProfilePhotoCache<UIImage>()
    @State private var selection: PhotosPickerItem?
    @State private var photoError: String?
    @State private var saving = false
    @State private var authRevision = 0
    @State private var mutationRevision = 0

    init(editable: Bool, enabled: Bool = true, expectedScope: ReachProfilePhotoScope? = nil,
         @ViewBuilder portraits: @escaping (UIImage?, UIImage?) -> Portraits) {
        self.editable = editable
        self.enabled = enabled
        self.expectedScope = expectedScope
        self.portraits = portraits
    }

    var body: some View {
        VStack(spacing: 12) {
            let visible = photos.visible(expectedScope: editable ? photos.scope : expectedScope,
                                         authorized: enabled && scene == .active)
            portraits(visible.0, visible.1)
            if editable {
                PhotosPicker(selection: $selection, matching: .images) {
                    Label("Choose my profile photo", systemImage: "person.crop.circle")
                }.disabled(photos.scope == nil || saving)
                if photos.own != nil {
                    Button("Remove my profile photo", role: .destructive) {
                        Task { await save(nil) }
                    }.disabled(photos.scope == nil || saving)
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
        .task(id: RefreshKey(scene: scene, authRevision: authRevision, enabled: enabled, scope: expectedScope)) {
            if scene != .active || (!editable && photos.scope != expectedScope) { clear() }
            guard enabled, scene == .active, editable || expectedScope != nil else { return }
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

    private struct RefreshKey: Equatable {
        let scene: ScenePhase
        let authRevision: Int
        let enabled: Bool
        let scope: ReachProfilePhotoScope?
    }

    private static func decodedPortrait(_ data: Data) -> UIImage? {
        guard let thumbnail = AdventurePhotoPreviewEncoder.thumbnail(data, maximumEdge: 320) else { return nil }
        return UIImage(cgImage: thumbnail)
    }

    private func clear() {
        photos.setScope(nil)
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
            let scope = ReachProfilePhotoScope(code: lock.pairCode, own: uid, partner: other)
            guard editable || scope == expectedScope else {
                throw AdventurePrivatePhotoClient.Failure.unauthorized
            }
            guard !Task.isCancelled, scene == .active, Auth.auth().currentUser?.uid == uid else { return }
            if photos.scope != scope { clear() }
            photos.setScope(scope)
            if !saving { photoError = nil }
            async let own: Void = refreshPortrait(using: client, scope: scope, ownPhoto: true, revision: revision)
            async let partner: Void = refreshPortrait(using: client, scope: scope, ownPhoto: false, revision: revision)
            _ = await (own, partner)
        } catch {
            guard !Task.isCancelled, scene == .active else { return }
            if !editable, photos.scope == expectedScope, photos.scope?.own == Auth.auth().currentUser?.uid,
               ReachHomeReadOutcome(error: error).isTransient { return }
            clear()
            photoError = "Shared profile photos are unavailable."
        }
    }

    @MainActor
    private func refreshPortrait(using client: AdventurePrivatePhotoClient, scope: ReachProfilePhotoScope,
                                 ownPhoto: Bool, revision: Int) async {
        let result: ReachProfilePhotoCache<UIImage>.Result
        do {
            let bytes = try await client.readProfilePhoto(
                pairCode: scope.code, ownerUID: ownPhoto ? scope.own : scope.partner
            )
            result = .updated(bytes.flatMap { Self.decodedPortrait($0) })
        } catch {
            if (error as? AdventurePrivatePhotoClient.Failure) == .unauthorized ||
                ReachHomeReadOutcome(error: error) == .authorizationDenied {
                result = .denied
            } else if ReachHomeReadOutcome(error: error).isTransient ||
                      (error as? AdventurePrivatePhotoClient.Failure) == .unavailable {
                result = .transientFailure
            } else {
                result = .failed
            }
        }
        guard !Task.isCancelled, scene == .active, photos.scope == scope,
              Auth.auth().currentUser?.uid == scope.own else { return }
        if case .denied = result {
            photos.apply(result, ownPhoto: ownPhoto, for: scope)
            selection = nil
            photoError = "Shared profile photos are unavailable."
            return
        }
        guard !ownPhoto || (revision == mutationRevision && !saving) else { return }
        photos.apply(result, ownPhoto: ownPhoto, for: scope)
        switch result {
        case .failed, .transientFailure:
            if !saving { photoError = "Shared profile photos are unavailable." }
        default: break
        }
    }

    private func save(_ item: PhotosPickerItem?) async {
        guard !saving, let scope = photos.scope, scene == .active else { return }
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
            guard !Task.isCancelled, photos.scope == scope, scene == .active else { return }
            try await AdventurePrivatePhotoClient.profileTransport()
                .saveOwnProfilePhoto(pairCode: scope.code, uid: scope.own, bytes: encoded)
            guard !Task.isCancelled, photos.scope == scope, scene == .active else { return }
            photos.apply(.updated(encoded.flatMap { Self.decodedPortrait($0) }), ownPhoto: true, for: scope)
            photoError = nil
        } catch {
            guard !Task.isCancelled, photos.scope == scope else { return }
            if (error as? AdventurePrivatePhotoClient.Failure) == .unauthorized ||
                ReachHomeReadOutcome(error: error) == .authorizationDenied { clear() }
            photoError = "Couldn’t save your profile photo. Try again."
        }
    }
}
#endif
