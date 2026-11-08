import Foundation

struct ReachDiagnosticSample: Identifiable, Equatable, Sendable {
    enum Event: String, Sendable {
        case checkingPartnership = "Checking staging partnership"
        case partnershipVerified = "Staging partnership verified"
        case registeringRoom = "Requesting staging room registration"
        case checkingRoom = "Checking staging room on the server"
        case publishingOffer = "Publishing the call offer"
        case pairObservationFailed = "Partnership observation failed"
        case roomObservationFailed = "Room observation failed"
        case signalingFailed = "Call signaling failed"
        case preparing = "Preparing media"
        case opening = "Opening a hand"
        case joining = "Taking a hand"
        case connected = "Media transport connected"
        case interrupted = "Media transport interrupted"
        case ended = "Media stopped"
        case failed = "Connection could not continue"
        case cleanupUnconfirmed = "Media stopped; server cleanup unconfirmed"
    }
    let id = UUID()
    let date: Date
    let event: Event
}

struct ReachPrivateDiagnostics: Sendable {
    private(set) var events: [ReachDiagnosticSample] = []
    mutating func record(_ event: ReachDiagnosticSample.Event, at date: Date = Date()) {
        events.append(ReachDiagnosticSample(date: date, event: event))
        if events.count > 20 { events.removeFirst(events.count - 20) }
    }
}

/// Future relay inputs only: not connected to RTCConfiguration or persisted.
/// A trusted staging broker must issue short-lived credentials AFTER authorization.
struct ReachRelayGrant: Sendable {
    let urls: [String]
    let username: String
    let credential: String
    let expiresAt: Date
    func isUsable(at now: Date) -> Bool {
        guard !urls.isEmpty, urls.count <= 4, !username.isEmpty, username.utf8.count <= 512,
              !credential.isEmpty, credential.utf8.count <= 2048,
              expiresAt > now, expiresAt.timeIntervalSince(now) <= 600 else { return false }
        return urls.allSatisfy {
            $0.range(of: #"^turns?:[A-Za-z0-9][A-Za-z0-9.-]*:[0-9]{1,5}\?transport=(udp|tcp)$"#, options: .regularExpression) != nil
                && !$0.contains("@")
                && Self.validPort($0)
        }
    }
    private static func validPort(_ url: String) -> Bool {
        guard let port = url.split(separator: ":").last?.split(separator: "?").first.flatMap({ Int($0) }) else { return false }
        return (1...65535).contains(port)
    }
}

/// Safe fixed messages: never display raw SDK payloads, UIDs, SDP or credentials.
enum ReachFailureCopy {
    static func backend(domain: String, code: Int) -> String {
        if domain == "FIRFirestoreErrorDomain" {
            switch code {
            case 7, 16: return "Pairing authorization could not be verified. Check pairing management before trying again."
            case 4, 14: return "The staging service could not be reached. Check your connection and explicitly try again."
            default: break
            }
        }
        if domain == NSURLErrorDomain { return "The network is unavailable. Check your connection and explicitly try again." }
        if domain == "FIRAuthErrorDomain" { return "Staging sign-in could not be verified. Check your connection and try again." }
        return "REACH could not complete this action. Check pairing and connection information before trying again."
    }
}

/// Authoritative call document listeners wait for the server rather than act on
/// a local snapshot from before the room transaction or on an uncommitted write.
enum ReachCallDocumentPolicy {
    static func isAuthoritative(isFromCache: Bool, hasPendingWrites: Bool) -> Bool {
        !isFromCache && !hasPendingWrites
    }
}

/// The Firestore rule caps expiry relative to server time. Leave headroom for
/// an opener whose clock is slightly ahead instead of requesting the exact cap.
enum ReachRoomExpiry {
    static func epochMilliseconds(from now: Date) -> Int64 {
        Int64(now.addingTimeInterval(8 * 60 * 60 - 60).timeIntervalSince1970 * 1000)
    }
}
