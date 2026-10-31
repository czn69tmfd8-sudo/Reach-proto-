import Foundation

struct ReachRoomCoordinator {
    let rooms: any ReachRoomStore

    func openHand(
        partnership: Partnership,
        existingPair: PairRecord,
        now: Date = Date()
    ) async throws -> ReachSession {
        guard partnership.isAuthorized,
              existingPair.isUsable(by: partnership.localMemberID),
              existingPair.partnerUID(for: partnership.localMemberID) == partnership.partnerMemberID else {
            throw ReachRoomCoordinatorError.unauthorized
        }

        switch PairSessionInterpreter.presentation(pair: existingPair, partnership: partnership) {
        case .none:
            return try await rooms.createRoom(
                pairCode: partnership.id,
                openedBy: partnership.localMemberID,
                partnerUID: partnership.partnerMemberID
            )

        case .myHandOpen(let roomID):
            guard let room = try await rooms.room(id: roomID),
                  room.pairCode == partnership.id,
                  room.hostUid == partnership.localMemberID,
                  room.partnerUid == partnership.partnerMemberID,
                  room.isCurrent(at: now) else {
                throw ReachRoomCoordinatorError.staleSession(roomID)
            }

            return ReachSession(
                id: roomID,
                partnershipID: partnership.id,
                openedBy: partnership.localMemberID,
                openedAt: room.createdAt ?? now,
                phase: .open
            )

        case .partnerHandOpen:
            throw ReachRoomCoordinatorError.partnerAlreadyOpen

        case .invalid:
            throw ReachRoomCoordinatorError.invalidPairState
        }
    }

    func sessionToTake(
        partnership: Partnership,
        pair: PairRecord,
        now: Date = Date()
    ) async throws -> ReachSession {
        guard partnership.isAuthorized,
              pair.isUsable(by: partnership.localMemberID),
              pair.partnerUID(for: partnership.localMemberID) == partnership.partnerMemberID else {
            throw ReachRoomCoordinatorError.unauthorized
        }

        guard case .partnerHandOpen(let roomID) =
                PairSessionInterpreter.presentation(pair: pair, partnership: partnership) else {
            throw ReachRoomCoordinatorError.partnerHandUnavailable
        }

        guard let room = try await rooms.room(id: roomID),
              room.pairCode == partnership.id,
              room.hostUid == partnership.partnerMemberID,
              room.partnerUid == partnership.localMemberID,
              room.isCurrent(at: now) else {
            throw ReachRoomCoordinatorError.staleSession(roomID)
        }

        return ReachSession(
            id: roomID,
            partnershipID: partnership.id,
            openedBy: partnership.partnerMemberID,
            openedAt: room.createdAt ?? now,
            phase: .open
        )
    }

    func end(
        session: ReachSession,
        partnership: Partnership
    ) async throws {
        guard let token = ReachCleanupPolicy.token(
            for: session,
            partnership: partnership
        ) else {
            throw ReachRoomCoordinatorError.sessionMismatch
        }

        try await rooms.clearPairSessionIfCurrent(
            pairCode: token.partnershipID,
            roomID: token.sessionID
        )
    }
}

enum ReachRoomCoordinatorError: LocalizedError, Equatable {
    case unauthorized
    case partnerAlreadyOpen
    case partnerHandUnavailable
    case staleSession(String)
    case invalidPairState
    case sessionMismatch

    var errorDescription: String? {
        switch self {
        case .unauthorized:
            return "This device is not authorized for the partnership."
        case .partnerAlreadyOpen:
            return "Your partner already has their hand open."
        case .partnerHandUnavailable:
            return "Your partner does not currently have a valid REACH open."
        case .staleSession:
            return "The registered REACH session is stale and must be cleared before opening another."
        case .invalidPairState:
            return "The partnership has an incomplete REACH session registration."
        case .sessionMismatch:
            return "The REACH session no longer belongs to this partnership."
        }
    }
}
