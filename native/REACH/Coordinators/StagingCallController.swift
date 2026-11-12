import Combine
import Foundation

/// One explicit foreground call at a time. No automatic joining or background media.
@MainActor
final class StagingCallController: ObservableObject {
    @Published private(set) var peer: NativeWebRTCPeer?
    @Published private(set) var phase = ReachCallPhase.idle
    @Published private(set) var busy = false
    @Published private(set) var diagnostics = ReachPrivateDiagnostics()
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

    func start(joining expectedRoomID: String? = nil) async {
        guard !busy, !phase.hasStarted else { return }
        let join = expectedRoomID != nil
        busy = true
        phase = .preparing
        diagnostics.record(.checkingPartnership)
        watchdog = ReachTransportWatchdog()
        let token = UUID(); generation = token
        do {
            let dependencies = try FirebaseDependencyFactory.staging()
            guard let uid = await dependencies.auth.currentUID(),
                  let lock = try await dependencies.pairs.memberLock(uid: uid),
                  let pair = try await dependencies.pairs.pair(code: lock.pairCode),
                  case .authorized(let partnership) = PairingAuthorization.resolve(uid: uid, memberLock: lock, pairCode: lock.pairCode, pair: pair) else {
                // Distinguish a failed local pairing preflight from a denied room transaction.
                // No UIDs, pairing codes, or room identifiers are included in user-facing copy.
                throw StagingCallPreflightError.notAuthorized
            }
            guard generation == token else { throw CancellationError() }
            diagnostics.record(.partnershipVerified)
            // Rooms are one-shot: never attach a new peer to an old offer or its ICE.
            if !join, pair.activeRoom != nil { throw ReachRoomCoordinatorError.partnerAlreadyOpen }
            if let expectedRoomID {
                guard pair.activeRoom == expectedRoomID,
                      ReachHandControls.verifiedAvailability(
                        partnership: partnership, pair: pair,
                        room: try await dependencies.rooms.room(id: expectedRoomID), now: Date()
                      ).canTake(at: Date()) else {
                    throw ReachRoomCoordinatorError.partnerHandUnavailable
                }
            }
            guard generation == token else { return }
            diagnostics.record(.preparing)
            let media = NativeWebRTCPeer()
            peer = media
            try await media.prepare()
            guard generation == token else { media.close(); throw CancellationError() }
            let coordinator = ReachRoomCoordinator(rooms: dependencies.rooms)
            let session: ReachSession
            if let expectedRoomID {
                // Permission prompts can outlast an invitation. Recheck before subscribing to signaling.
                guard let currentPair = try await dependencies.pairs.pair(code: partnership.id),
                      currentPair.activeRoom == expectedRoomID,
                      ReachHandControls.verifiedAvailability(
                        partnership: partnership, pair: currentPair,
                        room: try await dependencies.rooms.room(id: expectedRoomID), now: Date()
                      ).canTake(at: Date()) else {
                    throw ReachRoomCoordinatorError.partnerHandUnavailable
                }
                session = try await coordinator.sessionToTake(partnership: partnership, pair: currentPair)
            } else {
                diagnostics.record(.registeringRoom)
                session = try await coordinator.openHand(partnership: partnership, existingPair: pair)
            }
            guard generation == token else {
                media.close()
                // Opening may have committed while End was pressed.
                if !join { try? await coordinator.end(session: session, partnership: partnership) }
                throw CancellationError()
            }
            diagnostics.record(join ? .joining : .opening)
            self.session = session; self.partnership = partnership; rooms = dependencies.rooms
            diagnostics.record(.checkingRoom)
            guard let room = try await dependencies.rooms.room(id: session.id),
                  room.isCurrent(), room.pairCode == partnership.id,
                  room.hostUid == session.openedBy,
                  room.partnerUid == (join ? partnership.localMemberID : partnership.partnerMemberID) else {
                throw SignalingError.ended
            }
            guard generation == token else { return }
            inbox = SignalingInbox()
            let role: ReachMediaRole = join ? .joiner : .opener
            let signaling = try FirestoreSignalingTransport()
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
                    } catch { await self?.fail(error, token: token, checkpoint: .signalingFailed) }
                })
            }
            // Once Take Hand has accepted a verified offer, also bound the
            // wait for the signaling listener's first snapshot.
            if join { handleTransport(.negotiationStarted, token: token) }
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
                } catch { await self?.fail(error, token: token, checkpoint: .signalingFailed) }
            })
            tasks.append(Task { [weak self] in
                do {
                    for try await candidate in signaling.observeRemoteCandidates(roomID: session.id, role: role) {
                        guard let self, self.generation == token else { return }
                        try self.inbox.accept(candidate)
                        try await self.drainRemoteCandidates(media: media, token: token)
                    }
                } catch { await self?.fail(error, token: token, checkpoint: .signalingFailed) }
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
                } catch { await self?.fail(error, token: token, checkpoint: .pairObservationFailed) }
            })
            tasks.append(Task { [weak self] in
                do {
                    for try await room in dependencies.rooms.observeRoom(id: session.id) {
                        guard let self, self.generation == token else { return }
                        guard let room, room.isCurrent(), room.pairCode == partnership.id else { throw SignalingError.ended }
                    }
                } catch { await self?.fail(error, token: token, checkpoint: .roomObservationFailed) }
            })
            tasks.append(Task { [weak self] in
                do { try await Task.sleep(for: .seconds(max(0, room.expiresAt.timeIntervalSinceNow))) }
                catch { return }
                await self?.fail(SignalingError.ended, token: token)
            })
            if !join {
                diagnostics.record(.publishingOffer)
                let offer = try await media.makeDescription(.offer)
                guard generation == token else { throw CancellationError() }
                try await signaling.publishDescription(offer, roomID: session.id, role: role)
            }
            guard generation == token else { return }
            if phase == .preparing { phase = .outgoing }
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

    func end() async {
        guard phase.hasStarted else { return }
        await stop(message: nil)
    }

    private func handleTransport(_ event: ReachTransportWatchdog.Event, token: UUID) {
        guard generation == token, !watchdog.finished else { return }
        switch event {
        case .connected:
            phase = phase.receiving(event)
            diagnostics.record(.connected)
        case .disconnected:
            phase = phase.receiving(event)
            diagnostics.record(.interrupted)
        case .negotiationStarted:
            phase = phase.receiving(event)
        case .failed, .closed:
            break // Terminal events go directly to teardown.
        }
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

    private func fail(_ error: Error, token: UUID, checkpoint: ReachDiagnosticSample.Event? = nil) async {
        guard generation == token else { return }
        if let checkpoint { diagnostics.record(checkpoint) }
        diagnostics.record(.failed)
        await stop(message: ReachErrorPresentation.message(error))
    }

    private func stop(message: String?) async {
        generation = UUID()
        let stopToken = generation
        watchdogTask?.cancel(); watchdogTask = nil
        tasks.forEach { $0.cancel() }; tasks.removeAll()
        peer?.close(); peer = nil
        diagnostics.record(.ended)
        let oldSession = session, oldPartnership = partnership, oldRooms = rooms
        session = nil; partnership = nil; rooms = nil; inbox = SignalingInbox()
        outbox = LocalCandidateOutbox(); drainingCandidates = false
        phase = .ending
        busy = true
        var feedback = message
        if let oldSession, let oldPartnership, let oldRooms {
            do {
                try await SessionCleanupDeadline.run {
                    try await ReachRoomCoordinator(rooms: oldRooms).end(session: oldSession, partnership: oldPartnership)
                }
            }
            catch {
                if generation == stopToken {
                    diagnostics.record(.cleanupUnconfirmed)
                    feedback = "Media stopped. Check pairing management to finish closing the hand."
                }
            }
        }
        guard generation == stopToken else { return }
        busy = false
        phase = feedback.map(ReachCallPhase.failed) ?? .idle
    }
}

enum StagingCallPreflightError: LocalizedError {
    case notAuthorized

    var errorDescription: String? {
        "Call setup could not verify this device’s staging partnership before opening a room."
    }
}
