import CryptoKit
import FirebaseAuth
import FirebaseCore
import Foundation

enum AdventurePrivatePhotoGate {
    static let enabled = false
}

/// Uses Firebase ID tokens, so Firestore evaluates the caller's rules.
/// Bytes never enter the Firestore SDK's persistent document cache.
@MainActor
struct AdventurePrivatePhotoClient {
    struct Credentials: Sendable {
        let uid: String
        let token: String
    }

    struct Preview: Equatable, Sendable {
        let ownerUID: String
        let operationID: String
        let bytes: Data
    }

    enum Failure: LocalizedError, Equatable {
        case unauthorized, unavailable, conflict, malformed

        var errorDescription: String? {
            switch self {
            case .unauthorized: "Access to this private photograph ended."
            case .unavailable: "The private photograph could not be reached."
            case .conflict: "This memory already has a different photograph."
            case .malformed: "The private photograph could not be verified."
            }
        }
    }

    private static let session: URLSession = {
        let config = URLSessionConfiguration.ephemeral
        config.urlCache = nil
        config.urlCredentialStorage = nil
        config.httpCookieStorage = nil
        config.httpShouldSetCookies = false
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        config.timeoutIntervalForRequest = 15
        config.timeoutIntervalForResource = 25
        return URLSession(configuration: config, delegate: NoPhotoRedirects(), delegateQueue: nil)
    }()

    let projectID: String
    let credentials: @MainActor () async throws -> Credentials
    let currentUID: @MainActor () -> String?
    let send: @MainActor (URLRequest) async throws -> (Data, Int)

    static func live() throws -> Self {
        guard AdventurePrivatePhotoGate.enabled else { throw Failure.unavailable }
        try FirebaseBootstrap.configureStaging()
        let projectID = FirebaseApp.app()?.options.projectID
        try ReachEnvironmentGuard.validate(environment: .staging, configuredProjectID: projectID)
        guard let projectID else { throw Failure.unavailable }
        return Self(projectID: projectID, credentials: {
            guard let user = Auth.auth().currentUser else { throw Failure.unauthorized }
            return try await Credentials(uid: user.uid, token: user.getIDToken())
        }, currentUID: {
            Auth.auth().currentUser?.uid
        }, send: { request in
            let (data, response) = try await session.data(for: request)
            guard let status = (response as? HTTPURLResponse)?.statusCode else { throw Failure.unavailable }
            return (data, status)
        })
    }

    func read(pairCode: String, memoryID: String) async throws -> Preview? {
        let auth = try await credentials()
        let path = try documentPath(pairCode: pairCode, memoryID: memoryID)
        return try await read(path: path, auth: auth)
    }

    func publish(pairCode: String, memoryID: String, bytes: Data) async throws {
        guard Self.isJPEG(bytes) else { throw Failure.malformed }
        let auth = try await credentials()
        let path = try documentPath(pairCode: pairCode, memoryID: memoryID)
        // The same encoded bytes produce the same ID after a process restart.
        let operationID = Self.operationID(bytes)
        let expected = Preview(ownerUID: auth.uid, operationID: operationID, bytes: bytes)
        let body: [String: Any] = ["writes": [[
            "update": ["name": path, "fields": [
                "ownerUid": ["stringValue": auth.uid],
                "operationID": ["stringValue": operationID],
                "bytes": ["bytesValue": bytes.base64EncodedString()]
            ]],
            "updateTransforms": [["fieldPath": "createdAt", "setToServerValue": "REQUEST_TIME"]],
            "currentDocument": ["exists": false]
        ]]]

        do {
            let (_, status) = try await request(
                path: "projects/\(projectID)/databases/(default)/documents:commit",
                auth: auth, body: try JSONSerialization.data(withJSONObject: body)
            )
            if (200..<300).contains(status) { return }
            if status == 401 { throw Failure.unauthorized }
            throw Failure.unavailable
        } catch {
            try Task.checkCancellation()
            guard currentUID() == auth.uid else { throw Failure.unauthorized }
            if let existing = try await read(path: path, auth: auth) {
                guard existing == expected else { throw Failure.conflict }
                return
            }
            throw error
        }
    }

    private func read(path: String, auth: Credentials) async throws -> Preview? {
        let (data, status) = try await request(path: path, auth: auth)
        if status == 404 { return nil }
        if status == 401 || status == 403 { throw Failure.unauthorized }
        guard status == 200 else { throw Failure.unavailable }
        guard data.count <= 400_000,
              let document = try? JSONDecoder().decode(WireDocument.self, from: data),
              document.name == path,
              let owner = document.fields["ownerUid"]?.stringValue,
              SharedContentPolicy.documentID(owner),
              let operationID = document.fields["operationID"]?.stringValue,
              document.fields["createdAt"]?.timestampValue?.isEmpty == false,
              let bytes = document.fields["bytes"]?.bytesValue,
              Self.isJPEG(bytes), operationID == Self.operationID(bytes) else { throw Failure.malformed }
        return Preview(ownerUID: owner, operationID: operationID, bytes: bytes)
    }

    private func documentPath(pairCode: String, memoryID: String) throws -> String {
        let allowed = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789_-")
        guard SharedContentPolicy.pairCode(pairCode), (1...128).contains(memoryID.utf8.count),
              memoryID.unicodeScalars.allSatisfy(allowed.contains) else { throw Failure.malformed }
        return "projects/\(projectID)/databases/(default)/documents/adventureBooks/\(pairCode)/memories/\(memoryID)/privatePhotoPreviews/preview"
    }

    private func request(path: String, auth: Credentials, body: Data? = nil) async throws -> (Data, Int) {
        try Task.checkCancellation()
        guard currentUID() == auth.uid else { throw Failure.unauthorized }
        guard let url = URL(string: "https://firestore.googleapis.com/v1/\(path)") else { throw Failure.malformed }
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData)
        request.setValue("Bearer \(auth.token)", forHTTPHeaderField: "Authorization")
        request.setValue("no-store", forHTTPHeaderField: "Cache-Control")
        if let body {
            request.httpMethod = "POST"
            request.httpBody = body
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        let response = try await send(request)
        try Task.checkCancellation()
        guard currentUID() == auth.uid else { throw Failure.unauthorized }
        return response
    }

    private static func operationID(_ bytes: Data) -> String {
        SHA256.hash(data: bytes).map { String(format: "%02x", $0) }.joined()
    }

    private static func isJPEG(_ bytes: Data) -> Bool {
        bytes.count <= AdventurePhotoPreviewEncoder.maximumBytes && bytes.starts(with: [0xff, 0xd8, 0xff])
    }

    private struct WireDocument: Decodable {
        let name: String
        let fields: [String: WireField]
    }

    private struct WireField: Decodable {
        let stringValue: String?
        let bytesValue: Data?
        let timestampValue: String?
    }
}

private final class NoPhotoRedirects: NSObject, URLSessionTaskDelegate {
    func urlSession(_ session: URLSession, task: URLSessionTask,
                    willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest,
                    completionHandler: @escaping @Sendable (URLRequest?) -> Void) {
        completionHandler(nil)
    }
}
