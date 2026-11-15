import CryptoKit
import XCTest
@testable import REACH

final class AdventurePrivatePhotoClientTests: XCTestCase {
    private let pairCode = "ABCDEFGHJKLM"
    private let bytes = Data([0xff, 0xd8, 0xff, 0xe0, 1, 2])
    private let path = "projects/demo-reach-adventure/databases/(default)/documents/adventureBooks/ABCDEFGHJKLM/memories/trip/privatePhotoPreviews/preview"

    @MainActor
    func testInterruptedCommitReadsOriginalRecordWithoutRewriting() async throws {
        let document = try responseDocument()
        var methods: [String] = []
        let client = fixture { request in
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer synthetic-token")
            XCTAssertEqual(request.cachePolicy, .reloadIgnoringLocalCacheData)
            XCTAssertEqual(request.value(forHTTPHeaderField: "Cache-Control"), "no-store")
            methods.append(request.httpMethod ?? "")
            if request.httpMethod == "POST" {
                let body = try XCTUnwrap(request.httpBody)
                let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
                let writes = try XCTUnwrap(json["writes"] as? [[String: Any]])
                XCTAssertEqual(writes.count, 1)
                XCTAssertEqual((writes.first?["currentDocument"] as? [String: Bool])?["exists"], false)
                XCTAssertEqual((writes.first?["update"] as? [String: Any])?["name"] as? String, self.path)
                XCTAssertEqual((writes.first?["updateTransforms"] as? [[String: String]])?.first?["setToServerValue"],
                               "REQUEST_TIME")
                throw URLError(.timedOut)
            }
            return (document, 200)
        }
        try await client.publish(pairCode: pairCode, memoryID: "trip", bytes: bytes)
        XCTAssertEqual(methods, ["POST", "GET"])
    }

    @MainActor
    func testDifferentOwnerAndRevokedAccessCannotBeRecovered() async throws {
        let other = try responseDocument(owner: "partner")
        let conflict = fixture { request in request.httpMethod == "POST" ? (Data(), 409) : (other, 200) }
        do {
            try await conflict.publish(pairCode: pairCode, memoryID: "trip", bytes: bytes)
            XCTFail("Conflicting record was adopted")
        } catch {
            XCTAssertEqual(error as? AdventurePrivatePhotoClient.Failure, .conflict)
        }
        let revoked = fixture { _ in (Data(), 403) }
        do {
            _ = try await revoked.read(pairCode: pairCode, memoryID: "trip")
            XCTFail("Revoked request returned an image")
        } catch {
            XCTAssertEqual(error as? AdventurePrivatePhotoClient.Failure, .unauthorized)
        }
    }

    @MainActor
    func testSignOutDuringReadRejectsTheInFlightResponse() async throws {
        var uid: String? = "owner"
        let document = try responseDocument()
        let client = fixture(currentUID: { uid }) { _ in
            uid = nil
            return (document, 200)
        }
        do {
            _ = try await client.read(pairCode: pairCode, memoryID: "trip")
            XCTFail("A stale response escaped sign-out")
        } catch {
            XCTAssertEqual(error as? AdventurePrivatePhotoClient.Failure, .unauthorized)
        }
    }

    @MainActor
    func testCachedReconnectAndRevocationInvalidateServerBackedObservation() {
        let state = AdventurePreviewAccessState()
        XCTAssertTrue(state.accept(isCached: true, hasPendingWrites: false, matches: true))
        XCTAssertTrue(state.accept(isCached: false, hasPendingWrites: false, matches: true))
        XCTAssertFalse(state.accept(isCached: true, hasPendingWrites: false, matches: true))
        XCTAssertFalse(state.accept(isCached: false, hasPendingWrites: false, matches: false))
        XCTAssertFalse(state.accept(isCached: false, hasPendingWrites: true, matches: false))
        XCTAssertFalse(AdventurePrivatePhotoGate.enabled)
    }

    @MainActor
    func testProfilePhotoUsesPairScopedOwnerWritesAndAuthenticatedPartnerReads() async throws {
        let root = "projects/demo-reach-adventure/databases/(default)/documents/reachProfilePhotos/ABCDEFGHJKLM/members/"
        var requests: [URLRequest] = []
        let client = fixture { request in
            requests.append(request)
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer synthetic-token")
            XCTAssertEqual(request.cachePolicy, .reloadIgnoringLocalCacheData)
            if request.httpMethod == "GET" {
                XCTAssertTrue(request.url?.absoluteString.hasSuffix(root + "partner") == true)
                return (try JSONSerialization.data(withJSONObject: ["name": root + "partner", "fields": [
                    "ownerUid": ["stringValue": "partner"],
                    "bytes": ["bytesValue": self.bytes.base64EncodedString()]
                ]]), 200)
            }
            return (Data(), 200)
        }

        for payload in [bytes, nil] {
            do {
                try await client.saveOwnProfilePhoto(pairCode: pairCode, uid: "partner", bytes: payload)
                XCTFail("Partner write reached the transport")
            } catch {
                XCTAssertEqual(error as? AdventurePrivatePhotoClient.Failure, .unauthorized)
            }
        }
        XCTAssertTrue(requests.isEmpty)
        let partner = try await client.readProfilePhoto(pairCode: pairCode, ownerUID: "partner")
        XCTAssertEqual(partner, bytes)
        try await client.saveOwnProfilePhoto(pairCode: pairCode, uid: "owner", bytes: bytes)
        try await client.saveOwnProfilePhoto(pairCode: pairCode, uid: "owner", bytes: nil)
        XCTAssertEqual(requests.count, 3)
        let update = try XCTUnwrap(requests[1].httpBody)
        let updateBody = try XCTUnwrap(JSONSerialization.jsonObject(with: update) as? [String: [[String: Any]]])
        XCTAssertEqual((updateBody["writes"]?.first?["update"] as? [String: Any])?["name"] as? String, root + "owner")
        XCTAssertEqual((updateBody["writes"]?.first?["updateTransforms"] as? [[String: String]])?.first,
                       ["fieldPath": "updatedAt", "setToServerValue": "REQUEST_TIME"])
        let deletion = try XCTUnwrap(requests[2].httpBody)
        let deleteBody = try XCTUnwrap(JSONSerialization.jsonObject(with: deletion) as? [String: [[String: String]]])
        XCTAssertEqual(deleteBody["writes"], [["delete": root + "owner"]])
    }

    @MainActor
    private func fixture(
        currentUID: @escaping @MainActor () -> String? = { "owner" },
        send: @escaping @MainActor (URLRequest) async throws -> (Data, Int)
    ) -> AdventurePrivatePhotoClient {
        AdventurePrivatePhotoClient(projectID: "demo-reach-adventure", credentials: {
            .init(uid: "owner", token: "synthetic-token")
        }, currentUID: currentUID, send: send)
    }

    private func responseDocument(owner: String = "owner") throws -> Data {
        let digest = SHA256.hash(data: bytes).map { String(format: "%02x", $0) }.joined()
        return try JSONSerialization.data(withJSONObject: ["name": path, "fields": [
            "ownerUid": ["stringValue": owner], "operationID": ["stringValue": digest],
            "createdAt": ["timestampValue": "2026-01-01T00:00:00Z"],
            "bytes": ["bytesValue": bytes.base64EncodedString()]
        ]])
    }
}
