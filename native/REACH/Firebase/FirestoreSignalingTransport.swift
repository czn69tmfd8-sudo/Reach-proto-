import FirebaseFirestore
import Foundation

private struct SignalingListenerBox: @unchecked Sendable {
    let registration: any ListenerRegistration
}

/// Server rules are the authority; local validation catches malformed payloads early.
@MainActor
final class FirestoreSignalingTransport: ReachSignalingTransport {
    private let db: Firestore

    init(db: Firestore = Firestore.firestore()) throws {
        try ReachEnvironmentGuard.validate(environment: .staging, configuredProjectID: db.app.options.projectID)
        self.db = db
    }

    func publishDescription(_ description: ReachSessionDescription, roomID: String, role: ReachMediaRole) async throws {
        try ReachSignalingValidation.validate(description)
        guard description.kind == (role == .opener ? .offer : .answer) else {
            throw SignalingError.wrongRole
        }
        try await db.collection(ReachCollections.rooms).document(roomID).updateData([
            role == .opener ? "offer" : "answer": ["type": description.kind.rawValue, "sdp": description.sdp]
        ])
    }

    func observeRemoteDescription(roomID: String, role: ReachMediaRole) -> AsyncThrowingStream<ReachSessionDescription, Error> {
        let field = role == .opener ? "answer" : "offer"
        let kind: ReachSessionDescription.Kind = role == .opener ? .answer : .offer
        return AsyncThrowingStream { continuation in
            let registration = db.collection(ReachCollections.rooms).document(roomID).addSnapshotListener { snapshot, error in
                if let error { continuation.finish(throwing: error); return }
                guard let data = snapshot?.data(), data["active"] as? Bool == true,
                      let expiry = data["expiresAt"] as? NSNumber,
                      expiry.doubleValue > Date().timeIntervalSince1970 * 1000 else {
                    continuation.finish(throwing: SignalingError.ended)
                    return
                }
                guard let raw = data[field] as? [String: Any] else { return }
                guard raw["type"] as? String == kind.rawValue, let sdp = raw["sdp"] as? String else {
                    continuation.finish(throwing: SignalingError.malformed); return
                }
                let description = ReachSessionDescription(kind: kind, sdp: sdp)
                do { try ReachSignalingValidation.validate(description); continuation.yield(description) }
                catch { continuation.finish(throwing: error) }
            }
            let box = SignalingListenerBox(registration: registration)
            continuation.onTermination = { _ in box.registration.remove() }
        }
    }

    func publishCandidate(_ candidate: ReachIceCandidate, roomID: String, role: ReachMediaRole) async throws {
        try ReachSignalingValidation.validate(candidate)
        let side = role == .opener ? ReachCollections.hostCandidates : ReachCollections.partnerCandidates
        // Use the synchronous SDK entry point with its server-acknowledgement
        // callback. Swift 6.1 rejects sending the heterogeneous dictionary into
        // addDocument's nonisolated async overload. No payload or Firestore object
        // is transferred to a task, and a queued local write is not reported as success.
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            // An offline SDK can keep this callback pending indefinitely. Bound
            // our wait; a later server result cannot revive a stopped call.
            let deadline = CallbackDeadline(continuation, operation: "staging ICE acknowledgement")
            _ = db.collection(ReachCollections.rooms).document(roomID).collection(side).addDocument(data: [
                "candidate": candidate.sdp, "sdpMid": candidate.sdpMid as Any? ?? NSNull(),
                "sdpMLineIndex": Int(candidate.sdpMLineIndex)
            ], completion: { error in
                if let error { deadline.resolve(.failure(error)) }
                else { deadline.resolve(.success(())) }
            })
        }
    }

    func observeRemoteCandidates(roomID: String, role: ReachMediaRole) -> AsyncThrowingStream<ReachIceCandidate, Error> {
        let side = role == .opener ? ReachCollections.partnerCandidates : ReachCollections.hostCandidates
        return AsyncThrowingStream { continuation in
            let registration = db.collection(ReachCollections.rooms).document(roomID).collection(side).addSnapshotListener { snapshot, error in
                if let error { continuation.finish(throwing: error); return }
                for change in snapshot?.documentChanges ?? [] where change.type == .added {
                    let data = change.document.data()
                    guard let sdp = data["candidate"] as? String,
                          let index = data["sdpMLineIndex"] as? Int, let line = Int32(exactly: index) else {
                        continuation.finish(throwing: SignalingError.malformed); return
                    }
                    let candidate = ReachIceCandidate(sdp: sdp, sdpMid: data["sdpMid"] as? String, sdpMLineIndex: line)
                    do { try ReachSignalingValidation.validate(candidate); continuation.yield(candidate) }
                    catch { continuation.finish(throwing: error); return }
                }
            }
            let box = SignalingListenerBox(registration: registration)
            continuation.onTermination = { _ in box.registration.remove() }
        }
    }
}

enum SignalingError: LocalizedError {
    case wrongRole, malformed, ended, transportFailed
    var errorDescription: String? {
        switch self {
        case .transportFailed: return "Media transport ended or timed out. Explicitly open a fresh hand to retry."
        case .wrongRole: return "Only the opener may offer and only the joining partner may answer."
        case .malformed: return "Invalid signaling message."
        case .ended: return "The staging session ended or expired."
        }
    }
}
