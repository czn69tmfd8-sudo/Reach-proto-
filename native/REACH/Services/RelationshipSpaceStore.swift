import Combine
import FirebaseAuth
import Foundation

@MainActor
final class RelationshipSpaceStore: ObservableObject {
    enum Status: Equatable {
        case loading, ready, offline, unavailable
    }

    @Published private(set) var scope: RelationshipScope?
    @Published private(set) var records: [SharedRelationshipRecord] = []
    @Published private(set) var status: Status = .loading
    @Published private(set) var pageNumber = 1
    @Published private(set) var hasOlderEntries = false
    @Published private(set) var isWriting = false
    private let transport = RelationshipSpaceTransport()
    private var session = UUID()
    private var verified: RelationshipOfflineWindow?
    private var refreshing = false
    private var expiry: Task<Void, Never>?
    private var pageStarts: [RelationshipSpaceTransport.Cursor] = []
    private var nextPage: RelationshipSpaceTransport.Cursor?

    func watch() async {
        let session = self.session
        guard let auth = try? transport.authenticate() else { status = .unavailable; return }
        let listener = auth.addStateDidChangeListener { [weak self] _, user in
            let uid = user?.uid
            Task { @MainActor [weak self] in
                guard let self, self.session == session, let scope = self.scope, scope.uid != uid else { return }
                self.clear(status: .unavailable)
            }
        }
        defer { auth.removeStateDidChangeListener(listener) }
        while !Task.isCancelled && self.session == session {
            await refresh()
            do { try await Task.sleep(for: .seconds(15)) }
            catch { return }
        }
    }

    func reset() {
        session = UUID()
        refreshing = false
        isWriting = false
        clear(status: .loading)
    }

    func refresh() async { await load(pageStarts) }

    func olderPage() async {
        guard let nextPage else { return }
        await load(pageStarts + [nextPage])
    }

    func newerPage() async {
        guard !pageStarts.isEmpty else { return }
        await load(Array(pageStarts.dropLast()))
    }

    private func load(_ requestedPages: [RelationshipSpaceTransport.Cursor]) async {
        guard !refreshing, !isWriting else { return }
        let session = self.session
        refreshing = true
        defer { if self.session == session { refreshing = false } }
        guard let auth = try? transport.authenticate(), let uid = auth.currentUser?.uid else {
            clear(status: .unavailable)
            return
        }
        if let scope, scope.uid != uid { clear(status: .loading) }
        let pages = scope == nil ? [] : requestedPages
        do {
            let (scope, records, next) = try await transport.load(uid: uid, previousScope: scope, after: pages.last)
            guard self.session == session, !Task.isCancelled, auth.currentUser?.uid == uid else { return }
            self.scope = scope
            self.records = records
            pageStarts = pages
            pageNumber = pages.count + 1
            nextPage = next
            hasOlderEntries = next != nil
            verified = RelationshipOfflineWindow(verifiedAt: Date())
            expiry?.cancel()
            expiry = Task { [weak self] in
                do { try await Task.sleep(for: .seconds(RelationshipOfflineWindow.duration)) }
                catch { return }
                self?.clear(status: .unavailable)
            }
            status = .ready
        } catch {
            guard self.session == session, !Task.isCancelled else { return }
            if (error as? RelationshipSpaceError) == .unauthorized || auth.currentUser?.uid != uid {
                clear(status: .unavailable)
            } else if (error is URLError || (error as? RelationshipSpaceError) == .unavailable), canRead(at: Date()) {
                status = .offline
            } else {
                clear(status: .unavailable)
            }
        }
    }

    func canRead(at date: Date) -> Bool { verified?.permitsReading(at: date) == true }

    func save(_ consent: SharedRelationshipConsent) async throws {
        try await write(in: consent.scope) { try await transport.save(consent, in: consent.scope) }
    }

    func delete(_ record: SharedRelationshipRecord, in scope: RelationshipScope) async throws {
        try await write(in: scope) { try await transport.delete(record, in: scope) }
    }

    private func write(in expectedScope: RelationshipScope, operation: () async throws -> Void) async throws {
        guard scope == expectedScope, canRead(at: Date()) else { throw RelationshipSpaceError.unauthorized }
        guard !isWriting, !refreshing else { throw RelationshipSpaceError.unavailable }
        let session = self.session
        isWriting = true
        do {
            try await operation()
        } catch {
            guard self.session == session else { throw RelationshipSpaceError.unauthorized }
            isWriting = false
            if (error as? RelationshipSpaceError) == .unauthorized { clear(status: .unavailable) }
            if let failure = error as? RelationshipSpaceError { throw failure }
            throw RelationshipSpaceError.unavailable
        }
        guard self.session == session else { throw RelationshipSpaceError.unauthorized }
        isWriting = false
        guard scope == expectedScope, (try? transport.authenticate().currentUser?.uid) == expectedScope.uid else {
            clear(status: .unavailable)
            throw RelationshipSpaceError.unauthorized
        }
        await refresh()
    }

    private func clear(status: Status) {
        expiry?.cancel()
        expiry = nil
        scope = nil
        records = []
        verified = nil
        pageStarts = []
        pageNumber = 1
        nextPage = nil
        hasOlderEntries = false
        self.status = status
    }
}
