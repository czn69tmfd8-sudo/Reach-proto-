import FirebaseAuth
import Foundation

/// Uses the existing Firebase identity and server rules, without writing shared documents
/// into the default Firestore client's persistent cache.
@MainActor
final class RelationshipSpaceTransport {
    private struct Value: Codable, Equatable {
        var stringValue: String?
        var integerValue: String?
        var timestampValue: String?
        var bytesValue: Data?
        var booleanValue: Bool?
    }
    private struct Document: Codable {
        var name: String?
        var fields: [String: Value]
        var updateTime: String?
    }
    struct Cursor: Equatable {
        let eventAt: String
        let documentName: String
    }

    private static let pageSize = 12

    private struct QueryResult: Decodable {
        var document: Document?
    }

    private let base = URL(string: "https://firestore.googleapis.com/v1/projects/reach-staging-a4745/databases/(default)/documents/")!
    private let network: URLSession = {
        let config = URLSessionConfiguration.ephemeral
        config.urlCache = nil
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        config.timeoutIntervalForRequest = 8
        config.timeoutIntervalForResource = 12
        return URLSession(configuration: config)
    }()

    func authenticate() throws -> Auth {
        try FirebaseBootstrap.configureStaging()
        return Auth.auth()
    }

    func load(uid: String, previousScope: RelationshipScope?, after cursor: Cursor?,
              knownPage: [SharedRelationshipRecord]?)
        async throws -> (RelationshipScope, [SharedRelationshipRecord], Cursor?) {
        guard SharedContentPolicy.documentID(uid) else { throw RelationshipSpaceError.unauthorized }
        let token = try await credential(for: uid)
        let lock: Document = try await read("nativeStaging/v1/memberLocks/\(segment(uid))", token: token)
        guard let code = lock.fields["pairCode"]?.stringValue, SharedContentPolicy.pairCode(code) else {
            throw RelationshipSpaceError.unauthorized
        }
        if let previousScope, previousScope.pairCode != code { throw RelationshipSpaceError.unauthorized }
        let pair: Document = try await read("nativeStaging/v1/pairInvites/\(code)", token: token)
        guard let host = pair.fields["hostUid"]?.stringValue,
              let partner = pair.fields["partnerUid"]?.stringValue,
              pair.fields["revoked"] == nil || pair.fields["revoked"]?.booleanValue == false,
              let scope = RelationshipScope.resolve(uid: uid, code: code,
                pair: PairRecord(hostUid: host, partnerUid: partner, revoked: false, activeRoom: nil, openedBy: nil)) else {
            throw RelationshipSpaceError.unauthorized
        }
        var query: [String: Any] = [
            "from": [["collectionId": "entries"]],
            "orderBy": [
                ["field": ["fieldPath": "eventAt"], "direction": "DESCENDING"],
                ["field": ["fieldPath": "__name__"], "direction": "DESCENDING"]
            ],
            "limit": Self.pageSize
        ]
        if let cursor {
            query["startAt"] = ["before": false, "values": [
                ["timestampValue": cursor.eventAt], ["referenceValue": cursor.documentName]
            ]]
        }
        let documents: [Document]
        let records: [SharedRelationshipRecord]
        if let knownPage, scope == previousScope {
            var metadata = query
            metadata["select"] = ["fields": [["fieldPath": "eventAt"]]]
            let projected = try await runQuery(metadata, scope: scope, token: token)
            if projected.count == knownPage.count && zip(projected, knownPage).allSatisfy({ item in
                let (document, record) = item
                return document.name == resourceName(scope, id: record.id) && document.updateTime == record.version
            }) {
                documents = projected
                records = knownPage
            } else {
                documents = try await runQuery(query, scope: scope, token: token)
                records = try documents.map { try decode($0, scope: scope) }
            }
        } else {
            documents = try await runQuery(query, scope: scope, token: token)
            records = try documents.map { try decode($0, scope: scope) }
        }
        let next: Cursor?
        if documents.count == Self.pageSize, let last = documents.last, let name = last.name,
           let eventAt = last.fields["eventAt"]?.timestampValue {
            next = Cursor(eventAt: eventAt, documentName: name)
        } else {
            next = nil
        }
        return (scope, records, next)
    }

    private func runQuery(_ query: [String: Any], scope: RelationshipScope, token: String) async throws -> [Document] {
        let body = try JSONSerialization.data(withJSONObject: ["structuredQuery": query])
        let result = try await request(parent(scope) + ":runQuery", token: token, method: "POST", body: body)
        return try JSONDecoder().decode([QueryResult].self, from: result).compactMap(\.document)
    }

    func save(_ consent: SharedRelationshipConsent, in scope: RelationshipScope) async throws {
        try consent.validate(for: scope)
        let entry = try consent.entry.validated()
        let token = try await credential(for: scope.uid)
        let resource = path(scope) + "/" + entry.id.uuidString.lowercased()
        let format = ISO8601DateFormatter()
        let fields: [String: Value] = [
            "kind": Value(stringValue: entry.kind.rawValue), "authorUid": Value(stringValue: scope.uid),
            "title": Value(stringValue: entry.title), "caption": Value(stringValue: entry.caption),
            "eventAt": Value(timestampValue: format.string(from: entry.date)),
            "progress": Value(integerValue: String(entry.progress))
        ]
        var document = Document(fields: fields)
        if let photo = entry.photo { document.fields["photo"] = Value(bytesValue: photo) }
        let payload = try JSONEncoder().encode(document)
        do {
            _ = try await request(resource, token: token, method: "PATCH", query: [consent.precondition], body: payload)
        } catch RelationshipSpaceError.conflict {
            // A timed-out write may already have landed. A retry never overwrites a newer version.
            let existing: Document = try await read(resource, token: token, missing: .conflict)
            guard existing.fields["authorUid"]?.stringValue == scope.uid,
                  existing.fields == document.fields
            else { throw RelationshipSpaceError.conflict }
        }
    }

    func delete(_ record: SharedRelationshipRecord, in scope: RelationshipScope) async throws {
        guard record.isOwned(by: scope) else { throw RelationshipSpaceError.unauthorized }
        let token = try await credential(for: scope.uid)
        let resource = path(scope) + "/" + record.id.uuidString.lowercased()
        do {
            _ = try await request(resource, token: token, method: "DELETE",
                query: [URLQueryItem(name: "currentDocument.updateTime", value: record.version)], missing: .conflict)
        } catch let error as RelationshipSpaceError where error == .conflict || error == .unauthorized {
            do {
                _ = try await request(resource, token: token, missing: .missing)
            } catch RelationshipSpaceError.missing {
                return // A prior delete already landed, and reads are still authorized.
            }
            throw error
        }
    }

    private func credential(for uid: String) async throws -> String {
        let auth = try authenticate()
        guard let user = auth.currentUser, user.uid == uid else { throw RelationshipSpaceError.unauthorized }
        let token: String
        do { token = try await user.getIDToken() }
        catch {
            if (error as NSError).code == AuthErrorCode.networkError.rawValue { throw RelationshipSpaceError.unavailable }
            throw RelationshipSpaceError.unauthorized
        }
        guard auth.currentUser?.uid == uid else { throw RelationshipSpaceError.unauthorized }
        return token
    }

    private func parent(_ scope: RelationshipScope) -> String {
        "nativeStaging/v1/relationshipSpace/\(scope.pairCode)"
    }

    private func path(_ scope: RelationshipScope) -> String {
        parent(scope) + "/entries"
    }

    private func resourceName(_ scope: RelationshipScope, id: UUID) -> String {
        "projects/reach-staging-a4745/databases/(default)/documents/" + path(scope) + "/" + id.uuidString.lowercased()
    }

    private func segment(_ value: String) -> String {
        let allowed = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~")
        return value.addingPercentEncoding(withAllowedCharacters: allowed) ?? ""
    }

    private func read<T: Decodable>(_ resource: String, token: String,
                                   query: [URLQueryItem] = [], missing: RelationshipSpaceError = .unauthorized) async throws -> T {
        let data = try await request(resource, token: token, query: query, missing: missing)
        guard let value = try? JSONDecoder().decode(T.self, from: data) else { throw RelationshipSpaceError.malformed }
        return value
    }

    private func request(_ resource: String, token: String, method: String = "GET",
                         query: [URLQueryItem] = [], body: Data? = nil,
                         missing: RelationshipSpaceError = .unauthorized) async throws -> Data {
        guard var components = URLComponents(string: base.absoluteString + resource) else { throw RelationshipSpaceError.invalid }
        if !query.isEmpty { components.queryItems = query }
        guard let url = components.url else { throw RelationshipSpaceError.invalid }
        try Task.checkCancellation()
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("Bearer " + token, forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = body
        let isMutation = method == "PATCH" || method == "DELETE"
        let (data, response): (Data, URLResponse)
        do { (data, response) = try await network.data(for: request) }
        catch {
            if isMutation { throw RelationshipSpaceError.unconfirmed }
            throw error
        }
        guard let status = (response as? HTTPURLResponse)?.statusCode else {
            throw isMutation ? RelationshipSpaceError.unconfirmed : RelationshipSpaceError.unavailable
        }
        switch status {
        case 200...299: return data
        case 401, 403: throw RelationshipSpaceError.unauthorized
        case 404: throw missing
        case 409, 412: throw RelationshipSpaceError.conflict
        case 400:
            struct Failure: Decodable {
                struct Detail: Decodable { let status: String }
                let error: Detail
            }
            if (try? JSONDecoder().decode(Failure.self, from: data).error.status) == "FAILED_PRECONDITION" {
                throw RelationshipSpaceError.conflict
            }
            throw RelationshipSpaceError.invalid
        default: throw isMutation ? RelationshipSpaceError.unconfirmed : RelationshipSpaceError.unavailable
        }
    }

    private func decode(_ document: Document, scope: RelationshipScope) throws -> SharedRelationshipRecord {
        let fields = document.fields
        let format = ISO8601DateFormatter()
        guard let name = document.name, name.hasPrefix("projects/reach-staging-a4745/databases/(default)/documents/" + path(scope) + "/"),
              let rawID = name.split(separator: "/").last,
              let id = UUID(uuidString: String(rawID)), let version = document.updateTime,
              let author = fields["authorUid"]?.stringValue, SharedContentPolicy.documentID(author),
              let rawKind = fields["kind"]?.stringValue, let kind = SharedRelationshipKind(rawValue: rawKind),
              let title = fields["title"]?.stringValue, let caption = fields["caption"]?.stringValue,
              let rawDate = fields["eventAt"]?.timestampValue, let date = date(from: rawDate, formatter: format),
              let rawProgress = fields["progress"]?.integerValue, let progress = Int(rawProgress) else {
            throw RelationshipSpaceError.malformed
        }
        let entry = try SharedRelationshipEntry(id: id, kind: kind, title: title, caption: caption,
            date: date, progress: progress, photo: fields["photo"]?.bytesValue).validated()
        return SharedRelationshipRecord(entry: entry, scope: scope, authorUID: author, version: version)
    }

    private func date(from value: String, formatter: ISO8601DateFormatter) -> Date? {
        if let date = formatter.date(from: value) { return date }
        formatter.formatOptions.insert(.withFractionalSeconds)
        return formatter.date(from: value)
    }
}
