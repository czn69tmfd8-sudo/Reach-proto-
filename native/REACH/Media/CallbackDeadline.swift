import Foundation

/// A callback must complete exactly once, even when an SDK loses it or calls back
/// after its deadline. The lock protects the continuation, not the SDK operation.
final class CallbackDeadline<Value: Sendable>: @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<Value, Error>?
    private var timeout: DispatchWorkItem?

    init(_ continuation: CheckedContinuation<Value, Error>, operation: String, seconds: TimeInterval = 15) {
        self.continuation = continuation
        let deadline = DispatchWorkItem { [self] in
            resolve(.failure(CallbackDeadlineError(operation: operation)))
        }
        timeout = deadline
        DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + seconds, execute: deadline)
    }

    func resolve(_ result: Result<Value, Error>) {
        lock.lock()
        let pending = continuation
        continuation = nil
        let deadline = timeout
        timeout = nil
        lock.unlock()
        deadline?.cancel()
        pending?.resume(with: result)
    }
}

struct CallbackDeadlineError: LocalizedError, Equatable {
    let operation: String
    var errorDescription: String? { "WebRTC timed out during \(operation). End the call and retry." }
}
