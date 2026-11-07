import XCTest
@testable import REACH

@MainActor
private final class ControlledCameraDriver: CameraCaptureDriver {
    var startCount = 0
    var stopCount = 0
    var startCompletion: (@Sendable (Error?) -> Void)?
    var stopCompletions: [@Sendable () -> Void] = []
    func start(completion: @escaping @Sendable (Error?) -> Void) {
        startCount += 1; startCompletion = completion
    }
    func stop(completion: @escaping @Sendable () -> Void) {
        stopCount += 1; stopCompletions.append(completion)
    }
    func finishStart(_ error: Error? = nil) {
        let callback = startCompletion; startCompletion = nil
        callback?(error)
    }
    func finishStops() {
        let callbacks = stopCompletions; stopCompletions.removeAll()
        callbacks.forEach { $0() }
    }
}

final class CameraCaptureLifetimeTests: XCTestCase {
    @MainActor
    private func waitForStart(_ driver: ControlledCameraDriver) async throws {
        for _ in 0..<1000 {
            if driver.startCount > 0 { return }
            try await Task.sleep(for: .milliseconds(1))
        }
        XCTFail("Camera startup was never requested")
    }

    @MainActor
    func testSuccessfulStartAndRepeatedCloseStopsOnce() async throws {
        let driver = ControlledCameraDriver()
        let capture = CameraCaptureLifetime(driver: driver)
        let start = Task { try await capture.start() }
        try await waitForStart(driver); driver.finishStart()
        try await start.value
        capture.close(); capture.close()
        XCTAssertEqual(driver.startCount, 1); XCTAssertEqual(driver.stopCount, 1)
        driver.finishStops()
    }

    @MainActor
    func testCloseWhileStartPendingCancelsWithoutWaitingForSDK() async throws {
        let driver = ControlledCameraDriver(), capture: CameraCaptureLifetime
        capture = CameraCaptureLifetime(driver: driver)
        let start = Task { try await capture.start() }
        try await waitForStart(driver); capture.close()
        do { try await start.value; XCTFail("Closed startup must throw") }
        catch { XCTAssertTrue(error is CancellationError) }
        XCTAssertEqual(driver.stopCount, 1)
        driver.finishStart(); driver.finishStops()
    }

    @MainActor
    func testCancelledStartRequestsShutdownAndThrowsCancellation() async throws {
        let driver = ControlledCameraDriver(), capture: CameraCaptureLifetime
        capture = CameraCaptureLifetime(driver: driver)
        let start = Task { try await capture.start() }
        try await waitForStart(driver); start.cancel()
        do { try await start.value; XCTFail("Cancelled startup must throw") }
        catch { XCTAssertTrue(error is CancellationError) }
        XCTAssertEqual(driver.stopCount, 1)
        driver.finishStart(); driver.finishStops()
    }

    @MainActor
    func testLateStartupAfterCompletedStopQueuesAnotherShutdown() async throws {
        let driver = ControlledCameraDriver(), capture: CameraCaptureLifetime
        capture = CameraCaptureLifetime(driver: driver)
        let start = Task { try await capture.start() }
        try await waitForStart(driver); capture.close(); driver.finishStops()
        _ = try? await start.value
        // A worker thread may report startup only after the first stop finished.
        let completion = try XCTUnwrap(driver.startCompletion)
        driver.startCompletion = nil
        await Task.detached { completion(nil) }.value
        for _ in 0..<1000 {
            if driver.stopCount == 2 { break }
            try await Task.sleep(for: .milliseconds(1))
        }
        XCTAssertEqual(driver.stopCount, 2)
        driver.finishStops()
    }

    @MainActor
    func testStartFailureStopsCaptureAndPreservesError() async throws {
        let driver = ControlledCameraDriver(), capture: CameraCaptureLifetime
        capture = CameraCaptureLifetime(driver: driver)
        let start = Task { try await capture.start() }
        try await waitForStart(driver)
        driver.finishStart(CallbackDeadlineError(operation: "injected camera failure"))
        do { try await start.value; XCTFail("Expected camera error") }
        catch { XCTAssertEqual(error as? CallbackDeadlineError, CallbackDeadlineError(operation: "injected camera failure")) }
        XCTAssertEqual(driver.stopCount, 1); driver.finishStops()
    }

    @MainActor
    func testLostStartCallbackTimesOutAndLateCallbackStillStops() async throws {
        let driver = ControlledCameraDriver(), capture: CameraCaptureLifetime
        capture = CameraCaptureLifetime(driver: driver, startupTimeout: 0.01)
        do { try await capture.start(); XCTFail("Expected bounded startup failure") }
        catch { XCTAssertEqual(error as? CallbackDeadlineError, CallbackDeadlineError(operation: "camera capture")) }
        XCTAssertEqual(driver.stopCount, 1)
        driver.finishStart()
        for _ in 0..<1000 {
            if driver.stopCount == 2 { break }
            try await Task.sleep(for: .milliseconds(1))
        }
        XCTAssertEqual(driver.stopCount, 2); driver.finishStops()
    }

    @MainActor
    func testDuplicateStartupCallbackCannotDoubleStopOrReviveClosedCapture() async throws {
        let driver = ControlledCameraDriver(), capture: CameraCaptureLifetime
        capture = CameraCaptureLifetime(driver: driver)
        let start = Task { try await capture.start() }
        try await waitForStart(driver)
        let callback = try XCTUnwrap(driver.startCompletion)
        driver.finishStart(); try await start.value
        capture.close(); callback(nil); callback(nil)
        // Drain callbacks deterministically by awaiting another actor task.
        await Task { @MainActor in }.value
        XCTAssertEqual(driver.stopCount, 1); driver.finishStops()
        do { try await capture.start(); XCTFail("Closed capture must remain closed") }
        catch { XCTAssertTrue(error is CancellationError) }
        XCTAssertEqual(driver.startCount, 1)
    }

    @MainActor
    func testCloseBeforeStartNeverStartsHardware() async throws {
        let driver = ControlledCameraDriver(), capture: CameraCaptureLifetime
        capture = CameraCaptureLifetime(driver: driver); capture.close()
        do { try await capture.start(); XCTFail("Closed capture must reject start") }
        catch { XCTAssertTrue(error is CancellationError) }
        XCTAssertEqual(driver.startCount, 0); XCTAssertEqual(driver.stopCount, 0)
    }

    @MainActor
    func testConcurrentStartCannotReplaceAnInFlightCapture() async throws {
        let driver = ControlledCameraDriver(), capture: CameraCaptureLifetime
        capture = CameraCaptureLifetime(driver: driver)
        let start = Task { try await capture.start() }
        try await waitForStart(driver)
        do { try await capture.start(); XCTFail("Second startup must not replace the first") }
        catch { XCTAssertTrue(error is CancellationError) }
        XCTAssertEqual(driver.startCount, 1); XCTAssertEqual(driver.stopCount, 0)
        driver.finishStart(); try await start.value
        capture.close(); XCTAssertEqual(driver.stopCount, 1); driver.finishStops()
    }

    @MainActor
    func testAlreadyCancelledTaskDoesNotRequestCameraStartup() async {
        let driver = ControlledCameraDriver(), capture: CameraCaptureLifetime
        capture = CameraCaptureLifetime(driver: driver)
        let start = Task { @MainActor in
            // This task cannot enter start until the test yields the actor.
            try await capture.start()
        }
        start.cancel()
        do { try await start.value; XCTFail("Cancelled task must not start hardware") }
        catch { XCTAssertTrue(error is CancellationError) }
        XCTAssertEqual(driver.startCount, 0); XCTAssertEqual(driver.stopCount, 0)
        capture.close()
    }

    @MainActor
    func testDriverIsRetainedUntilAsynchronousStopCallbackIsReleased() async throws {
        weak var releasedDriver: ControlledCameraDriver?
        var finishStop: (@Sendable () -> Void)?
        do {
            let driver = ControlledCameraDriver()
            releasedDriver = driver
            let capture = CameraCaptureLifetime(driver: driver)
            let start = Task { try await capture.start() }
            try await waitForStart(driver); driver.finishStart(); try await start.value
            capture.close()
            finishStop = driver.stopCompletions.removeFirst()
        }
        XCTAssertNotNil(releasedDriver, "Pending hardware shutdown must retain its SDK owner")
        finishStop?(); finishStop = nil
        XCTAssertNil(releasedDriver, "Shutdown completion must release ownership")
    }
}
