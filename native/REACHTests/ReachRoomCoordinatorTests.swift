import XCTest
@testable import REACH

final class ReachRoomCoordinatorTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 10_000)
    private let partnership = Partnership(
        id: "PAIR01",
        localMemberID: "byron",
        partnerMemberID: "aaron",
        partnerDisplayName: "Aaron",
        isAuthorized: true
    )

    func testReusesOnlyVerifiedCurrentOwnRoom() async throws {
        let room = RoomRecord(
            hostUid: "byron",
            partnerUid: "aaron",
            pairCode: "PAIR01",
            createdAt: now.addingTimeInterval(-60),
            expiresAt: now.addingTimeInterval(60),
            active: true,
            offer: nil,
            answer: nil
        )
        let store = StubRoomStore(room: room)
        let coordinator = ReachRoomCoordinator(rooms: store)
        let session = try await coordinator.openHand(
            partnership: partnership,
            existingPair: pair(activeRoom: "room-1", openedBy: "byron"),
            now: now
        )

        XCTAssertEqual(session.id, "room-1")
        XCTAssertEqual(session.openedAt, room.createdAt)
        XCTAssertEqual(await store.createCount, 0)
    }

    func testExpiredRegisteredRoomIsRejectedInsteadOfReused() async {
        let room = RoomRecord(
            hostUid: "byron",
            partnerUid: "aaron",
            pairCode: "PAIR01",
            createdAt: now.addingTimeInterval(-9 * 60 * 60),
            expiresAt: now.addingTimeInterval(-1),
            active: true,
            offer: nil,
            answer: nil
        )
        let coordinator = ReachRoomCoordinator(rooms: StubRoomStore(room: room))

        do {
            _ = try await coordinator.openHand(
                partnership: partnership,
                existingPair: pair(activeRoom: "room-1", openedBy: "byron"),
                now: now
            )
            XCTFail("Expected stale session rejection")
        } catch {
            XCTAssertEqual(error as? ReachRoomCoordinatorError, .staleSession("room-1"))
        }
    }

    func testHalfWrittenPairPointerIsRejected() async {
        let coordinator = ReachRoomCoordinator(rooms: StubRoomStore(room: nil))
        do {
            _ = try await coordinator.openHand(
                partnership: partnership,
                existingPair: pair(activeRoom: "room-1", openedBy: nil),
                now: now
            )
            XCTFail("Expected invalid pair state")
        } catch {
            XCTAssertEqual(error as? ReachRoomCoordinatorError, .invalidPairState)
        }
    }


    func testTakeHandRequiresVerifiedPartnerOwnedCurrentRoom() async throws {
        let room = RoomRecord(
            hostUid: "aaron",
            partnerUid: "byron",
            pairCode: "PAIR01",
            createdAt: now.addingTimeInterval(-60),
            expiresAt: now.addingTimeInterval(60),
            active: true,
            offer: nil,
            answer: nil
        )
        let coordinator = ReachRoomCoordinator(rooms: StubRoomStore(room: room))
        let session = try await coordinator.sessionToTake(
            partnership: partnership,
            pair: pair(activeRoom: "room-1", openedBy: "aaron"),
            now: now
        )
        XCTAssertEqual(session.id, "room-1")
        XCTAssertEqual(session.openedBy, "aaron")
    }

    func testTakeHandRejectsRoomOwnedByWrongDevice() async {
        let room = RoomRecord(
            hostUid: "intruder",
            partnerUid: "byron",
            pairCode: "PAIR01",
            createdAt: now.addingTimeInterval(-60),
            expiresAt: now.addingTimeInterval(60),
            active: true,
            offer: nil,
            answer: nil
        )
        let coordinator = ReachRoomCoordinator(rooms: StubRoomStore(room: room))
        do {
            _ = try await coordinator.sessionToTake(
                partnership: partnership,
                pair: pair(activeRoom: "room-1", openedBy: "aaron"),
                now: now
            )
            XCTFail("Expected stale/invalid room rejection")
        } catch {
            XCTAssertEqual(error as? ReachRoomCoordinatorError, .staleSession("room-1"))
        }
    }

    private func pair(activeRoom: String?, openedBy: String?) -> PairRecord {
        PairRecord(
            hostUid: "byron",
            partnerUid: "aaron",
            revoked: false,
            activeRoom: activeRoom,
            openedBy: openedBy
        )
    }
}

private actor StubRoomStore: ReachRoomStore {
    let storedRoom: RoomRecord?
    private(set) var createCount = 0

    init(room: RoomRecord?) {
        self.storedRoom = room
    }

    func createRoom(pairCode: String, openedBy uid: String, partnerUID: String) async throws -> ReachSession {
        createCount += 1
        return ReachSession(
            id: "new-room",
            partnershipID: pairCode,
            openedBy: uid,
            openedAt: Date(),
            phase: .open
        )
    }

    func room(id: String) async throws -> RoomRecord? { storedRoom }

    nonisolated func observeRoom(id: String) -> AsyncThrowingStream<RoomRecord?, Error> {
        AsyncThrowingStream { $0.finish() }
    }

    func clearPairSessionIfCurrent(pairCode: String, roomID: String) async throws {}
}
