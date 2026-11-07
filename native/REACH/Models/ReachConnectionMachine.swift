import Foundation

enum ReachConnectionEvent: Equatable {
    case handOpened(ReachSession)
    case partnerHandObserved(ReachSession)
    case connectionStarted
    case mediaConnected
    case connectionInterrupted
    case connectionRecovered
    case ended
    case failed(String)
}

enum ReachConnectionMachine {
    static func reduce(_ current: ReachSession?, event: ReachConnectionEvent) -> ReachSession? {
        switch event {
        case .handOpened(let session), .partnerHandObserved(let session):
            return session
        case .connectionStarted:
            return current.map { copy($0, phase: .connecting) }
        case .mediaConnected:
            return current.map { copy($0, phase: .live) }
        case .connectionInterrupted:
            return current.map { copy($0, phase: .recovering) }
        case .connectionRecovered:
            return current.map { copy($0, phase: .live) }
        case .ended:
            return nil
        case .failed(let message):
            return current.map { copy($0, phase: .failed(message)) }
        }
    }

    private static func copy(_ session: ReachSession, phase: ReachSessionPhase) -> ReachSession {
        ReachSession(
            id: session.id,
            partnershipID: session.partnershipID,
            openedBy: session.openedBy,
            openedAt: session.openedAt,
            phase: phase
        )
    }
}
