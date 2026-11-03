import XCTest
@testable import REACH

final class MockReachBackendTests: XCTestCase {
    private func pair() -> Partnership {
        Partnership(
            id: "test-pair",
            localMemberID: "one",
            partnerMemberID: "two",
            partnerDisplayName: "Partner",
            isAuthorized: true
        )
    }

    func testOldSessionCleanupCannotRemoveNewSession() async throws {
        let backend = MockReachBackend()
        let first = try await backend.open(partnership: pair())
        let clearedFirst = await backend.clearIfCurrent(id: first.id)
        XCTAssertTrue(clearedFirst)
        let second = try await backend.open(partnership: pair())

        let removed = await backend.clearIfCurrent(id: first.id)
        XCTAssertFalse(removed)
        let current = await backend.currentSession()
        XCTAssertEqual(current?.id, second.id)
    }

    func testDelayedUpdateCannotResurrectEndedSession() async throws {
        let backend = MockReachBackend()
        let first = try await backend.open(partnership: pair())
        _ = await backend.clearIfCurrent(id: first.id)
        var delayed = first
        delayed.phase = .live

        let applied = await backend.updateIfCurrent(delayed, expectedID: first.id)
        XCTAssertFalse(applied)
        let current = await backend.currentSession()
        XCTAssertNil(current)
    }

    func testDuplicateOpenIsRejected() async throws {
        let backend = MockReachBackend()
        _ = try await backend.open(partnership: pair())
        do {
            _ = try await backend.open(partnership: pair())
            XCTFail("Expected duplicate session rejection")
        } catch MockReachBackendError.sessionAlreadyExists {
            // Expected
        }
    }
}
