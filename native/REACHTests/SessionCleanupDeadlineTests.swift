import XCTest
@testable import REACH

private actor CleanupCounter {
    private(set) var value = 0
    func record() { value += 1 }
}
private enum CleanupFailure: Error { case denied }

final class SessionCleanupDeadlineTests: XCTestCase {
    func testSuccessfulCleanupCompletesOnce() async throws {
        let counter = CleanupCounter()
        try await SessionCleanupDeadline.run { await counter.record() }
        let count = await counter.value
        XCTAssertEqual(count, 1)
    }
    func testServerRejectionIsPreserved() async {
        do {
            try await SessionCleanupDeadline.run { throw CleanupFailure.denied }
            XCTFail("Server rejection must not become a successful cleanup")
        } catch { XCTAssertTrue(error is CleanupFailure) }
    }
    func testSlowCleanupTimesOutButLateCompletionIsSafe() async throws {
        let counter = CleanupCounter()
        do {
            try await SessionCleanupDeadline.run(seconds: 0.01) {
                try await Task.sleep(for: .milliseconds(80))
                await counter.record()
            }
            XCTFail("A slow server must not leave the UI waiting indefinitely")
        } catch { XCTAssertTrue(error is SessionCleanupTimeout) }
        // The original transaction can still complete. Its continuation must not
        // resume twice or turn the timeout into a claim of server confirmation.
        try await Task.sleep(for: .milliseconds(150))
        let count = await counter.value
        XCTAssertEqual(count, 1)
    }
    func testCleanupStillRunsWhenCallingTaskWasCancelled() async throws {
        let counter = CleanupCounter()
        let task = Task {
            withUnsafeCurrentTask { $0?.cancel() }
            try await SessionCleanupDeadline.run { await counter.record() }
        }
        try await task.value
        let count = await counter.value
        XCTAssertEqual(count, 1)
    }
}
