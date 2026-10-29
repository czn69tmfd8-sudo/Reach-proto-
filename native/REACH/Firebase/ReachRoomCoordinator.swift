import Foundation

struct ReachRoomCoordinator {
    let rooms: any ReachRoomStore

    func openHand(
        partnership: Partnership,
        existingPair: PairRecord,
        now: Date = Date()
    ) async throws -> ReachSession {
        guard partnership.isAuthorized else {
            throw ReachRoomCoordinatorError.unauthorized
        }

        if let activeRoom = existingPair.activeRoom,
           let openedBy = existingPair.openedBy {
            if openedBy == partnership.localMemberID {
                return ReachSession(
                    id: activeRoom,
                    partnershipID: partnership.id,
                    openedBy: openedBy,
                    openedAt: now,
                    phase: .open
                )
            }

            throw ReachRoomCoordinatorError.partnerAlreadyOpen
        }

        return try await rooms.createRoom(
            pairCode: partnership.id,
            openedBy: partnership.localMemberID,
            partnerUID: partnership.partnerMemberID
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
    case sessionMismatch

    var errorDescription: String? {
        switch self {
        case .unauthorized:
            return "This device is not authorized for the partnership."
        case .partnerAlreadyOpen:
            return "Your partner already has their hand open."
        case .sessionMismatch:
            return "The REACH session no longer belongs to this partnership."
        }
    }
}
