import Foundation

/// Talks to your own server (app/server, contract in app/api/openapi.yaml).
struct API {
    let base: URL
    let token: String?

    init(base: URL, token: String?) {
        self.base = base
        self.token = token
    }

    /// "api.rubenonmission.nl" or "http://localhost:8787/" -> a clean base URL, or nil if it isn't one.
    static func baseURL(_ server: String) -> URL? {
        var text = server.trimmingCharacters(in: .whitespacesAndNewlines)
        while text.hasSuffix("/") { text.removeLast() }
        if !text.isEmpty && !text.contains("://") { text = "https://" + text }
        guard let url = URL(string: text), let scheme = url.scheme, ["http", "https"].contains(scheme), url.host != nil else { return nil }
        return url
    }

    // MARK: Wire types

    /// One stored record, as the server sends it (and as the seed and backups hold it).
    struct Record: Codable {
        var id: String
        var collection: String
        var createdAt: String?
        var updatedAt: String
        var deletedAt: String?
        var seq: Int?
        var data: JSONObject

        init(id: String, collection: String, createdAt: String?, updatedAt: String, deletedAt: String?, data: JSONObject) {
            self.id = id
            self.collection = collection
            self.createdAt = createdAt
            self.updatedAt = updatedAt
            self.deletedAt = deletedAt
            self.seq = nil
            self.data = data
        }

        enum CodingKeys: String, CodingKey { case id, collection, createdAt, updatedAt, deletedAt, seq, data }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            id = try c.decode(String.self, forKey: .id)
            collection = try c.decode(String.self, forKey: .collection)
            createdAt = try c.decodeIfPresent(String.self, forKey: .createdAt)
            updatedAt = try c.decode(String.self, forKey: .updatedAt)
            deletedAt = try c.decodeIfPresent(String.self, forKey: .deletedAt)
            seq = try c.decodeIfPresent(Int.self, forKey: .seq)
            data = try c.decodeIfPresent(JSONObject.self, forKey: .data) ?? [:]
        }

        func encode(to encoder: Encoder) throws {
            var c = encoder.container(keyedBy: CodingKeys.self)
            try c.encode(id, forKey: .id)
            try c.encode(collection, forKey: .collection)
            try c.encodeIfPresent(createdAt, forKey: .createdAt)
            try c.encode(updatedAt, forKey: .updatedAt)
            try c.encode(deletedAt, forKey: .deletedAt)   // null when live, as in the contract
            try c.encodeIfPresent(seq, forKey: .seq)
            try c.encode(data, forKey: .data)
        }
    }

    /// One local change for POST /v1/sync.
    struct Change: Encodable {
        var id: String
        var collection: String
        var updatedAt: String
        var deletedAt: String?
        var data: JSONObject

        enum CodingKeys: String, CodingKey { case id, collection, updatedAt, deletedAt, data }

        func encode(to encoder: Encoder) throws {
            var c = encoder.container(keyedBy: CodingKeys.self)
            try c.encode(id, forKey: .id)
            try c.encode(collection, forKey: .collection)
            try c.encode(updatedAt, forKey: .updatedAt)
            try c.encode(deletedAt, forKey: .deletedAt)
            try c.encode(data, forKey: .data)
        }
    }

    struct SyncRequest: Encodable {
        var cursor: String?
        var changes: [Change]
        var limit: Int

        enum CodingKeys: String, CodingKey { case cursor, changes, limit }

        func encode(to encoder: Encoder) throws {
            var c = encoder.container(keyedBy: CodingKeys.self)
            try c.encode(cursor, forKey: .cursor)   // null for a full download
            try c.encode(changes, forKey: .changes)
            try c.encode(limit, forKey: .limit)
        }
    }

    struct SyncResponse: Decodable {
        var cursor: String
        var hasMore: Bool
        var resetRequired: Bool
        var serverTime: String?
        var changes: [Record]
        var accepted: [Accepted]
        var rejected: [Rejected]
    }

    struct Accepted: Decodable {
        var id: String
        var seq: Int
    }

    struct Rejected: Decodable {
        var id: String
        var reason: String          // stale, invalid, forbidden
        var message: String?
        var current: Record?
    }

    struct DeviceInfo: Encodable {
        var name: String
        var platform: String
        var appVersion: String
    }

    struct User: Decodable {
        var id: String
        var email: String
        var name: String
    }

    struct Device: Decodable, Identifiable {
        var id: String
        var name: String
        var platform: String
        var appVersion: String?
        var createdAt: Date?
        var lastSeenAt: Date?
        var current: Bool

        enum CodingKeys: String, CodingKey { case id, name, platform, appVersion, createdAt, lastSeenAt, current }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            id = try c.decode(String.self, forKey: .id)
            name = try c.decodeIfPresent(String.self, forKey: .name) ?? "Device"
            platform = try c.decodeIfPresent(String.self, forKey: .platform) ?? "other"
            appVersion = try c.decodeIfPresent(String.self, forKey: .appVersion)
            createdAt = try c.decodeIfPresent(String.self, forKey: .createdAt).flatMap(TimeFormat.date)
            lastSeenAt = try c.decodeIfPresent(String.self, forKey: .lastSeenAt).flatMap(TimeFormat.date)
            current = try c.decodeIfPresent(Bool.self, forKey: .current) ?? false
        }
    }

    struct Session: Decodable {
        var token: String
        var user: User
        var device: Device
    }

    struct Me: Decodable {
        var user: User
        var device: Device
    }

    enum Failure: LocalizedError {
        case badAddress
        case unauthorized(String)
        case http(Int, code: String, message: String)
        case checksum

        var errorDescription: String? {
            switch self {
            case .badAddress: "That server address doesn't look right."
            case .unauthorized(let message): message.isEmpty ? "This device is logged out. Log in again." : message
            case .http(_, _, let message): message
            case .checksum: "A downloaded file didn't match its checksum. It will be fetched again."
            }
        }

        static func isUnauthorized(_ error: Error) -> Bool {
            if case .unauthorized? = error as? Failure { return true }
            return false
        }
    }

    // MARK: Requests

    private func url(_ path: String) -> URL { base.appendingPathComponent(path) }

    private func request(_ path: String, method: String = "GET", timeout: TimeInterval = 60) -> URLRequest {
        var r = URLRequest(url: url(path))
        r.httpMethod = method
        r.timeoutInterval = timeout
        if let token { r.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        return r
    }

    private func jsonRequest<B: Encodable>(_ path: String, method: String = "POST", body: B) throws -> URLRequest {
        var r = request(path, method: method)
        r.setValue("application/json", forHTTPHeaderField: "Content-Type")
        r.httpBody = try JSONEncoder().encode(body)
        return r
    }

    /// Throws a readable error for anything but 2xx (and the allowed codes).
    @discardableResult
    private func check(_ data: Data, _ response: URLResponse, allow: Set<Int> = []) throws -> Int {
        let code = (response as? HTTPURLResponse)?.statusCode ?? 0
        if (200..<300).contains(code) || allow.contains(code) { return code }
        struct ErrorBody: Decodable { struct Inner: Decodable { var code: String; var message: String }; var error: Inner }
        let body = try? JSONDecoder().decode(ErrorBody.self, from: data)
        let message = body?.error.message ?? "The server answered \(code)."
        if code == 401 { throw Failure.unauthorized(body?.error.message ?? "") }
        throw Failure.http(code, code: body?.error.code ?? "http_\(code)", message: message)
    }

    @discardableResult
    private func send(_ r: URLRequest, allow: Set<Int> = []) async throws -> (data: Data, status: Int) {
        let (data, response) = try await URLSession.shared.data(for: r)
        let status = try check(data, response, allow: allow)
        return (data: data, status: status)
    }

    func health() async throws {
        var r = URLRequest(url: url("v1/health"))
        r.timeoutInterval = 15
        try await send(r)
    }

    func login(email: String, password: String, device: DeviceInfo) async throws -> Session {
        struct Body: Encodable { var email: String; var password: String; var device: DeviceInfo }
        let r = try jsonRequest("v1/auth/login", body: Body(email: email, password: password, device: device))
        return try JSONDecoder().decode(Session.self, from: try await send(r).data)
    }

    func logout() async throws {
        try await send(request("v1/auth/logout", method: "POST"))
    }

    func me() async throws -> Me {
        try JSONDecoder().decode(Me.self, from: try await send(request("v1/me")).data)
    }

    func devices() async throws -> [Device] {
        struct List: Decodable { var devices: [Device] }
        return try JSONDecoder().decode(List.self, from: try await send(request("v1/devices")).data).devices
    }

    func revokeDevice(_ id: String) async throws {
        let safe = id.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? id
        try await send(request("v1/devices/\(safe)", method: "DELETE"))
    }

    func sync(cursor: String?, changes: [Change], limit: Int = 500) async throws -> SyncResponse {
        var r = try jsonRequest("v1/sync", body: SyncRequest(cursor: cursor, changes: changes, limit: limit))
        r.timeoutInterval = 120
        return try JSONDecoder().decode(SyncResponse.self, from: try await send(r).data)
    }

    // MARK: Files

    /// HEAD: does the server have this file already?
    func fileExists(_ fileID: String) async throws -> Bool {
        try await send(request("v1/files/\(fileID)", method: "HEAD"), allow: [404]).status != 404
    }

    func upload(_ fileID: String, from file: URL, mimeType: String, fileName: String, sha256: String) async throws {
        var r = request("v1/files/\(fileID)", method: "PUT", timeout: 300)
        r.setValue(mimeType.isEmpty ? "application/octet-stream" : mimeType, forHTTPHeaderField: "Content-Type")
        if !fileName.isEmpty { r.setValue(Self.percentEncoded(fileName), forHTTPHeaderField: "X-File-Name") }
        if !sha256.isEmpty { r.setValue(sha256, forHTTPHeaderField: "X-Sha256") }
        let (data, response) = try await URLSession.shared.upload(for: r, fromFile: file)
        try check(data, response)
    }

    /// The file's bytes, or nil if the server doesn't have it (yet).
    func download(_ fileID: String) async throws -> Data? {
        let result = try await send(request("v1/files/\(fileID)", timeout: 300), allow: [404])
        return result.status == 404 ? nil : result.data
    }

    func deleteFile(_ fileID: String) async throws {
        try await send(request("v1/files/\(fileID)", method: "DELETE"), allow: [404])
    }

    /// Header values must be ASCII: everything but unreserved characters is %-encoded (the server decodes it).
    static func percentEncoded(_ s: String) -> String {
        let allowed = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~")
        return s.addingPercentEncoding(withAllowedCharacters: allowed) ?? "file"
    }
}
