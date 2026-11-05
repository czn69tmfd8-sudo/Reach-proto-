import XCTest
@testable import REACH

final class CallbackDeadlineTests: XCTestCase {
    func testFirstCompletionWinsAndLateCompletionIsIgnored() async throws {
        let result: Int = try await withCheckedThrowingContinuation { continuation in
            let callback = CallbackDeadline(continuation, operation: "test", seconds: 0.05)
            callback.resolve(.success(42))
            callback.resolve(.failure(CallbackDeadlineError(operation: "late duplicate")))
        }
        XCTAssertEqual(result, 42)
    }

    func testMissingSDKCallbackFailsWithNamedDeadline() async {
        do {
            let _: Int = try await withCheckedThrowingContinuation { continuation in
                _ = CallbackDeadline(continuation, operation: "remote SDP", seconds: 0.01)
            }
            XCTFail("A lost callback must fail the operation")
        } catch {
            XCTAssertEqual(error as? CallbackDeadlineError, CallbackDeadlineError(operation: "remote SDP"))
        }
    }

    func testCallbackAfterTimeoutCannotResumeContinuationTwice() async {
        do {
            let _: Int = try await withCheckedThrowingContinuation { continuation in
                let callback = CallbackDeadline(continuation, operation: "ICE", seconds: 0.01)
                DispatchQueue.global().asyncAfter(deadline: .now() + 0.05) { callback.resolve(.success(1)) }
            }
            XCTFail("Expected deadline failure")
        } catch {
            XCTAssertEqual(error as? CallbackDeadlineError, CallbackDeadlineError(operation: "ICE"))
        }
        try? await Task.sleep(for: .milliseconds(100))
    }
}
