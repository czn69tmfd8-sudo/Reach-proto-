import Foundation

struct ReachDiagnosticSample: Identifiable, Equatable, Sendable {
    enum Event: String, Sendable {
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
