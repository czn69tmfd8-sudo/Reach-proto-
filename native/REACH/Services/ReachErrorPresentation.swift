import Foundation

enum ReachErrorPresentation {
    static func message(_ error: Error) -> String {
        if error is CancellationError { return "This action was cancelled. Start a new action when you’re ready." }
        // These types provide controlled application strings, never remote payloads.
        if let error = error as? StagingCallPreflightError { return error.localizedDescription }
        if let error = error as? ReachRoomCoordinatorError { return error.localizedDescription }
        if let error = error as? FirestoreRoomStoreError { return error.localizedDescription }
        if let error = error as? PeerError { return error.localizedDescription }
        if let error = error as? SignalingError { return error.localizedDescription }
        if let error = error as? ReachEnvironmentError { return error.localizedDescription }
        let error = error as NSError
        return ReachFailureCopy.backend(domain: error.domain, code: error.code)
    }
}
