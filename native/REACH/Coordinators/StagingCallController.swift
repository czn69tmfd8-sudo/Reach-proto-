import Combine
import Foundation

/// One explicit foreground call at a time. No automatic joining or background media.
@MainActor
final class StagingCallController: ObservableObject {
    @Published private(set) var peer: NativeWebRTCPeer?
    @Published private(set) var status = "No live staging call."
    @Published private(set) var busy = false
    private var generation = UUID()
    private var tasks: [Task<Void, Never>] = []
    private var session: ReachSession?
    private var partnership: Partnership?
    private var rooms: (any ReachRoomStore)?
    private var inbox = SignalingInbox()
    private var outbox = LocalCandidateOutbox()
    private var drainingCandidates = false
    private var watchdog = ReachTransportWatchdog()
    private var watchdogTask: Task<Void, Never>?

    func start(join: Bool) async {
        guard !busy, peer == nil else { return }
        busy = true
        watchdog = ReachTransportWatchdog()
        let token = UUID(); generation = token
        do {
            let dependencies = try FirebaseDependencyFactory.staging()
            guard let uid = await dependencies.auth.currentUID(),
                  let lock = try await dependencies.pairs.memberLock(uid: uid),
                  let pair = try await dependencies.pairs.pair(code: lock.pairCode),
                  case .authorized(let partnership) = PairingAuthorization.resolve(uid: uid, memberLock: lock, pairCode: lock.pairCode, pair: pair) else {
                throw ReachRoomCoordinatorError.unauthorized
            }
            guard generation == token else { throw CancellationError() }
            // Rooms are one-shot: never attach a new peer to an old offer or its ICE.
            if !join, pair.activeRoom != nil { throw ReachRoomCoordinatorError.partnerAlreadyOpen }
            let media = NativeWebRTCPeer()
            peer = media
            status = "Preparing camera and microphone…"
            try await media.prepare()
            guard generation == token else { media.close(); throw CancellationError() }
            let coordinator = ReachRoomCoordinator(rooms: dependencies.rooms)
            let session = try await (join ? coordinator.sessionToTake(partnership: partnership, pair: pair) : coordinator.openHand(partnership: partnership, existingPair: pair))
            guard generation == token else {
                media.close()
                // Opening may have committed while End was pressed.
                if !join { try? await coordinator.end(session: session, partnership: partnership) }
                throw CancellationError()
            }
            self.session = session; self.partnership = partnership; rooms = dependencies.rooms
            inbox = SignalingInbox()
            let role: ReachMediaRole = join ? .joiner : .opener
            let signaling = try FirestoreSignalingTransport()
            media.onState = { [weak self] value in
                guard let self, self.generation == token else { return }
                self.status = value
            }
            media.onTransportEvent = { [weak self] event in
                guard let self, self.generation == token else { return }
                self.handleTransport(event, token: token)
            }
            media.onCandidate = { [weak self] candidate in
                guard let self, self.generation == token else { return }
                do { try self.outbox.enqueue(candidate) }
                catch {
                    self.peer?.close()
                    self.tasks.append(Task { [weak self] in await self?.fail(error, token: token) })
                    return
                }
                guard !self.drainingCandidates else { return }
                self.drainingCandidates = true
                self.tasks.append(Task { [weak self] in
                    do {
                        while let self, self.generation == token {
                            guard let candidate = self.outbox.next() else {
                                self.drainingCandidates = false
                                return
                            }
                            try await signaling.publishCandidate(candidate, roomID: session.id, role: role)
                        }
                    } catch { await self?.fail(error, token: token) }
                })
            }
            status = join ? "Negotiating media transport…" : "Hand open. Waiting for your partner to take it."
            // Snapshot listeners emit existing messages, so late joiners receive the offer and all ICE.
            tasks.append(Task { [weak self] in
                do {
                    for try await description in signaling.observeRemoteDescription(roomID: session.id, role: role) {
                        guard let self, self.generation == token else { return }
                        if try self.inbox.accept(description) {
                            self.handleTransport(.negotiationStarted, token: token)
                            try await media.apply(description)
                            guard self.generation == token else { return }
                            try self.inbox.remoteDescriptionApplied()
                            try await self.drainRemoteCandidates(media: media, token: token)
                            if join {
                                let answer = try await media.makeDescription(.answer)
                                guard self.generation == token else { return }
                                try await signaling.publishDescription(answer, roomID: session.id, role: role)
                            }
                        }
                    }
                } catch { await self?.fail(error, token: token) }
            })
            tasks.append(Task { [weak self] in
                do {
                    for try await candidate in signaling.observeRemoteCandidates(roomID: session.id, role: role) {
                        guard let self, self.generation == token else { return }
                        try self.inbox.accept(candidate)
                        try await self.drainRemoteCandidates(media: media, token: token)
                    }
                } catch { await self?.fail(error, token: token) }
            })
            tasks.append(Task { [weak self] in
                do {
                    for try await updated in dependencies.pairs.observePair(code: partnership.id) {
                        guard let self, self.generation == token else { return }
                        guard let updated, updated.isUsable(by: uid), updated.activeRoom == session.id,
                              updated.partnerUID(for: uid) == partnership.partnerMemberID else {
                            throw ReachRoomCoordinatorError.unauthorized
                        }
                    }
                } catch { await self?.fail(error, token: token) }
            })
            tasks.append(Task { [weak self] in
                do {
                    for try await room in dependencies.rooms.observeRoom(id: session.id) {
                        guard let self, self.generation == token else { return }
                        guard let room, room.isCurrent(), room.pairCode == partnership.id else { throw SignalingError.ended }
                    }
                } catch { await self?.fail(error, token: token) }
            })
            guard let room = try await dependencies.rooms.room(id: session.id) else { throw SignalingError.ended }
            tasks.append(Task { [weak self] in
                do { try await Task.sleep(for: .seconds(max(0, room.expiresAt.timeIntervalSinceNow))) }
                catch { return }
                await self?.fail(SignalingError.ended, token: token)
            })
            if !join {
                let offer = try await media.makeDescription(.offer)
                guard generation == token else { throw CancellationError() }
                try await signaling.publishDescription(offer, roomID: session.id, role: role)
            }
            guard generation == token else { return }
            busy = false
        } catch { await fail(error, token: token) }
    }

    private func drainRemoteCandidates(media: NativeWebRTCPeer, token: UUID) async throws {
        guard generation == token, let owner = inbox.beginDrain() else { return }
        defer { if generation == token { inbox.finishDrain(owner: owner) } }
        while generation == token, let candidate = inbox.nextCandidate(owner: owner) {
            try await media.add(candidate)
        }
    }

    func end() async { await stop(message: "Staging call ended.") }

    private func handleTransport(_ event: ReachTransportWatchdog.Event, token: UUID) {
        applyWatchdog(watchdog.receive(event), token: token)
    }

    private func applyWatchdog(_ action: ReachTransportWatchdog.Action, token: UUID) {
        switch action {
        case .none: break
        case .cancelDeadline:
            watchdogTask?.cancel(); watchdogTask = nil
        case .startDeadline(let id, let seconds):
            watchdogTask?.cancel()
            watchdogTask = Task { [weak self] in
                do { try await Task.sleep(for: .seconds(seconds)) } catch { return }
                guard let self, self.generation == token else { return }
                self.applyWatchdog(self.watchdog.deadlineExpired(id), token: token)
            }
        case .stop:
            // Stop capture synchronously, before any Firebase cleanup awaits.
            peer?.close()
            tasks.append(Task { [weak self] in
                await self?.fail(SignalingError.transportFailed, token: token)
            })
        }
    }

    private func fail(_ error: Error, token: UUID) async {
        guard generation == token else { return }
        await stop(message: error.localizedDescription)
    }

    private func stop(message: String) async {
        generation = UUID()
        let stopToken = generation
        watchdogTask?.cancel(); watchdogTask = nil
        tasks.forEach { $0.cancel() }; tasks.removeAll()
        peer?.close(); peer = nil
        let oldSession = session, oldPartnership = partnership, oldRooms = rooms
        session = nil; partnership = nil; rooms = nil; inbox = SignalingInbox()
        outbox = LocalCandidateOutbox(); drainingCandidates = false
        busy = true; status = message
        if let oldSession, let oldPartnership, let oldRooms {
            do {
                try await SessionCleanupDeadline.run {
                    try await ReachRoomCoordinator(rooms: oldRooms).end(session: oldSession, partnership: oldPartnership)
                }
            }
            catch {
                if generation == stopToken { status = "Media stopped. Session cleanup could not be confirmed: \(error.localizedDescription)" }
            }
        }
        guard generation == stopToken else { return }
        busy = false
    }
}
