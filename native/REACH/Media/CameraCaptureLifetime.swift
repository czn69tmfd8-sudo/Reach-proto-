import Foundation

/// SDK callbacks may run anywhere; ownership and every start/stop request stay on MainActor.
@MainActor
protocol CameraCaptureDriver: AnyObject, Sendable {
    func start(completion: @escaping @Sendable (Error?) -> Void)
    func stop(completion: @escaping @Sendable () -> Void)
}

/// One-shot camera ownership. Closing never waits for a pending start callback.
/// A late start completion queues another stop, so it cannot revive closed capture.
@MainActor
final class CameraCaptureLifetime {
    private let driver: any CameraCaptureDriver
    private let startupTimeout: TimeInterval
    private var pendingStart: CallbackDeadline<Void>?
    private var starting = false
    private var closed = false
    private var startCompletionHandled = false

    init(driver: any CameraCaptureDriver, startupTimeout: TimeInterval = 15) {
        self.driver = driver
        self.startupTimeout = startupTimeout
    }

    func start() async throws {
        guard !closed, !starting else { throw CancellationError() }
        try Task.checkCancellation()
        starting = true
        do {
            try await withTaskCancellationHandler {
                try Task.checkCancellation()
                try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                    pendingStart = CallbackDeadline(continuation, operation: "camera capture", seconds: startupTimeout)
                    driver.start { [self] error in
                        // Retain this lifetime until SDK completion, including after End.
                        Task { @MainActor in self.startCompleted(error) }
                    }
                }
                try Task.checkCancellation()
                guard !closed else { throw CancellationError() }
            } onCancel: {
                Task { @MainActor in self.close() }
            }
        } catch {
            close()
            throw error
        }
    }

    func close() {
        guard !closed else { return }
        closed = true
        pendingStart?.resolve(.failure(CancellationError()))
        pendingStart = nil
        if starting { requestStop() }
    }

    private func startCompleted(_ error: Error?) {
        guard !startCompletionHandled else { return }
        startCompletionHandled = true
        if closed {
            // The initial stop could have completed before this late startup.
            requestStop()
        } else if let error {
            pendingStart?.resolve(.failure(error))
        } else {
            pendingStart?.resolve(.success(()))
        }
        pendingStart = nil
    }

    private func requestStop() {
        // Keep the SDK capturer alive through asynchronous hardware shutdown,
        // even after the peer releases this lifetime. No actor state is touched here.
        let retainedDriver = driver
        driver.stop { [retainedDriver] in _ = retainedDriver }
    }
}
