import Foundation
import Security

struct CommunityAccount: Codable, Equatable {
    let id: String
    var nickname: String
    var pointsBalance: Int
    var pointsEarnedTotal: Int
    var leaderboardVisible: Bool
}

struct CommunityAppleCredential: Encodable {
    let identityToken: String
    let authorizationCode: String
    let nonce: String
    let installationId: String
    let platform: String
}

struct CommunityLeaderboardEntry: Codable, Identifiable, Equatable {
    let rank: Int
    let publicId: String
    let nickname: String
    let pointsBalance: Int
    let isCurrentUser: Bool

    var id: String { publicId }
}

struct CommunityMessage: Codable, Identifiable, Equatable {
    let id: String
    let roomId: String
    let nickname: String?
    let text: String
    let createdAt: Date
    let expiresAt: Date
    let authorKey: String

    var displayName: String {
        let trimmed = (nickname ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "匿名用户 / Anonymous" : trimmed
    }
}

enum CommunityReportReason: String, CaseIterable, Identifiable {
    case spam
    case harassment
    case personalInformation = "personal_information"
    case scam
    case other

    var id: String { rawValue }

    var label: String {
        switch self {
        case .spam: return "垃圾信息 / Spam"
        case .harassment: return "骚扰或仇恨 / Harassment"
        case .personalInformation: return "个人信息 / Personal information"
        case .scam: return "诈骗或引流 / Scam or solicitation"
        case .other: return "其他 / Other"
        }
    }
}

enum CommunityServiceError: LocalizedError {
    case server(statusCode: Int, code: String)
    case invalidResponse
    case keychain(OSStatus)
    case invalidToken
    case requestTimedOut
    case transport(String)
    case decoding(String)

    var errorDescription: String? {
        switch self {
        case let .server(_, code): return code
        case .invalidResponse: return "The community service returned an invalid response."
        case let .keychain(status):
            return SecCopyErrorMessageString(status, nil) as String? ?? "Keychain error \(status)"
        case .invalidToken: return "The stored community session is invalid."
        case .requestTimedOut: return "The community service did not respond in time."
        case let .transport(message), let .decoding(message): return message
        }
    }

    var isAuthenticationFailure: Bool {
        guard case let .server(statusCode, code) = self else { return false }
        return statusCode == 401 || statusCode == 403 || ["login_required", "session_expired", "session_revoked"].contains(code)
    }
}

final class CommunityAPI {
    private struct AccountEnvelope: Decodable {
        let account: CommunityAccount
    }

    private struct SessionEnvelope: Decodable {
        let sessionToken: String
        let account: CommunityAccount
    }

    private struct HeartbeatEnvelope: Decodable {
        let pointsBalance: Int
        let activeSeconds: Int
        let leaseVersion: Int
    }

    private struct LeaderboardEnvelope: Decodable {
        let entries: [CommunityLeaderboardEntry]
        let me: CommunityLeaderboardEntry?
    }

    private struct MessagesEnvelope: Decodable {
        let messages: [CommunityMessage]
    }

    private struct MessageMutationEnvelope: Decodable {
        let message: CommunityMessage?
        let pointsBalance: Int?
        let remainingCooldown: Int?
        let error: String?
    }

    private struct ServerErrorEnvelope: Decodable {
        let error: String
    }

    private struct LeasePayload: Encodable {
        let leaseVersion: Int
    }

    private struct ProfilePayload: Encodable {
        let nickname: String
        let leaderboardVisible: Bool
    }

    private let baseURL = URL(string: "https://lynncat.com/markets")!
    private let session: URLSession
    private let encoder = JSONEncoder()
    private let decoder: JSONDecoder

    init(session: URLSession = CommunityAPI.makeSession()) {
        self.session = session
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .millisecondsSince1970
        self.decoder = decoder
    }

    func signIn(_ credential: CommunityAppleCredential) async throws -> (token: String, account: CommunityAccount) {
        let envelope: SessionEnvelope = try await request(path: "auth/apple", method: "POST", body: credential)
        return (envelope.sessionToken, envelope.account)
    }

    func account(token: String) async throws -> CommunityAccount {
        let envelope: AccountEnvelope = try await request(path: "account", method: "GET", token: token)
        return envelope.account
    }

    func heartbeat(token: String, leaseVersion: Int) async throws -> (points: Int, activeSeconds: Int, leaseVersion: Int) {
        let envelope: HeartbeatEnvelope = try await request(
            path: "points/heartbeat",
            method: "POST",
            token: token,
            idempotencyKey: "codexpilot-heartbeat-\(UUID().uuidString.lowercased())",
            body: LeasePayload(leaseVersion: leaseVersion)
        )
        return (envelope.pointsBalance, envelope.activeSeconds, envelope.leaseVersion)
    }

    func stopHeartbeat(token: String, leaseVersion: Int) async {
        let _: HeartbeatEnvelope? = try? await request(
            path: "points/heartbeat/stop",
            method: "POST",
            token: token,
            body: LeasePayload(leaseVersion: leaseVersion)
        )
    }

    func updateProfile(token: String, nickname: String, leaderboardVisible: Bool) async throws -> CommunityAccount {
        let envelope: AccountEnvelope = try await request(
            path: "account/profile",
            method: "PUT",
            token: token,
            body: ProfilePayload(nickname: nickname, leaderboardVisible: leaderboardVisible)
        )
        return envelope.account
    }

    func leaderboard(token: String?) async throws -> (entries: [CommunityLeaderboardEntry], me: CommunityLeaderboardEntry?) {
        let envelope: LeaderboardEnvelope = try await request(path: "leaderboard", method: "GET", token: token)
        return (envelope.entries, envelope.me)
    }

    func messages(roomId: String) async throws -> [CommunityMessage] {
        var components = URLComponents(url: baseURL.appendingPathComponent("messages"), resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "room", value: roomId)]
        let envelope: MessagesEnvelope = try await perform(url: components.url!, method: "GET")
        return envelope.messages.filter { $0.roomId == roomId }
    }

    func postMessage(token: String, roomId: String, text: String) async throws -> (message: CommunityMessage, pointsBalance: Int?) {
        struct Payload: Encodable {
            let roomId: String
            let text: String
        }
        let envelope: MessageMutationEnvelope = try await request(
            path: "messages",
            method: "POST",
            token: token,
            idempotencyKey: UUID().uuidString.lowercased(),
            body: Payload(roomId: roomId, text: text)
        )
        guard let message = envelope.message else {
            throw CommunityServiceError.server(statusCode: 500, code: envelope.error ?? "send_failed")
        }
        return (message, envelope.pointsBalance)
    }

    func report(message: CommunityMessage, reason: CommunityReportReason, reporterId: String) async throws {
        struct Payload: Encodable {
            let reporterId: String
            let reason: String
        }
        let _: MessageMutationEnvelope = try await request(
            url: baseURL
                .appendingPathComponent("messages")
                .appendingPathComponent(message.id)
                .appendingPathComponent("reports"),
            method: "POST",
            body: Payload(reporterId: reporterId, reason: reason.rawValue)
        )
    }

    func logout(token: String) async {
        let _: EmptyResponse? = try? await request(path: "auth/logout", method: "POST", token: token)
    }

    private struct EmptyResponse: Decodable {}

    private func request<Response: Decodable>(
        path: String,
        method: String,
        token: String? = nil,
        idempotencyKey: String? = nil
    ) async throws -> Response {
        try await perform(
            url: baseURL.appendingPathComponent(path),
            method: method,
            token: token,
            idempotencyKey: idempotencyKey
        )
    }

    private func request<Body: Encodable, Response: Decodable>(
        path: String,
        method: String,
        token: String? = nil,
        idempotencyKey: String? = nil,
        body: Body
    ) async throws -> Response {
        try await perform(
            url: baseURL.appendingPathComponent(path),
            method: method,
            token: token,
            idempotencyKey: idempotencyKey,
            body: try encoder.encode(body)
        )
    }

    private func request<Body: Encodable, Response: Decodable>(
        url: URL,
        method: String,
        token: String? = nil,
        idempotencyKey: String? = nil,
        body: Body
    ) async throws -> Response {
        try await perform(
            url: url,
            method: method,
            token: token,
            idempotencyKey: idempotencyKey,
            body: try encoder.encode(body)
        )
    }

    private func perform<Response: Decodable>(
        url: URL,
        method: String,
        token: String? = nil,
        idempotencyKey: String? = nil,
        body: Data? = nil
    ) async throws -> Response {
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 8)
        request.httpMethod = method
        request.httpBody = body
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("no-store", forHTTPHeaderField: "Cache-Control")
        request.setValue("no-cache", forHTTPHeaderField: "Pragma")
        if body != nil {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        if let token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        if let idempotencyKey {
            request.setValue(idempotencyKey, forHTTPHeaderField: "Idempotency-Key")
        }

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch let error as URLError where error.code == .timedOut {
            throw CommunityServiceError.requestTimedOut
        } catch {
            throw CommunityServiceError.transport(error.localizedDescription)
        }
        guard let http = response as? HTTPURLResponse else {
            throw CommunityServiceError.invalidResponse
        }
        guard (200..<300).contains(http.statusCode) else {
            let code = (try? decoder.decode(ServerErrorEnvelope.self, from: data).error) ?? "http_\(http.statusCode)"
            throw CommunityServiceError.server(statusCode: http.statusCode, code: code)
        }
        do {
            return try decoder.decode(Response.self, from: data)
        } catch {
            throw CommunityServiceError.decoding(error.localizedDescription)
        }
    }

    private static func makeSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.timeoutIntervalForRequest = 8
        configuration.timeoutIntervalForResource = 8
        configuration.urlCache = nil
        return URLSession(configuration: configuration)
    }
}

@MainActor
final class CommunityAccountStore: ObservableObject {
    static let shared = CommunityAccountStore()

    @Published private(set) var account: CommunityAccount?
    @Published private(set) var leaderboard: [CommunityLeaderboardEntry] = []
    @Published private(set) var currentRank: CommunityLeaderboardEntry?
    @Published private(set) var isRestoring = false
    @Published private(set) var isSigningIn = false
    @Published private(set) var isAccruing = false
    @Published private(set) var activeSeconds = 0
    @Published private(set) var errorText: String?

    var isAuthenticated: Bool { account != nil && token != nil }
    var authorizationToken: String? { token }

    private let api = CommunityAPI()
    private let tokenStore = CommunityTokenStore()
    private var token: String?
    private var leaseVersion = 0
    private var heartbeatTask: Task<Void, Never>?
    private var isForeground = false
    private var sessionRevision: UInt64 = 0
    private var restoreOperationID: UUID?
    private var signInOperationID: UUID?

    private init() {
        token = try? tokenStore.read()
    }

    func restoreSession() async {
        invalidatePendingWork(sendStop: false)
        let revision = sessionRevision
        let operationID = UUID()
        restoreOperationID = operationID
        account = nil
        activeSeconds = 0
        leaseVersion = 0
        errorText = nil
        isRestoring = true
        defer {
            if restoreOperationID == operationID {
                isRestoring = false
                restoreOperationID = nil
            }
        }

        guard let stored = try? tokenStore.read(), !stored.isEmpty else {
            token = nil
            return
        }
        token = stored

        do {
            let restoredAccount = try await api.account(token: stored)
            guard isCurrentSession(revision: revision, token: stored) else { return }
            token = stored
            account = restoredAccount
            errorText = nil
            startHeartbeatIfNeeded()
        } catch let error as CommunityServiceError where error.isAuthenticationFailure {
            guard isCurrentSession(revision: revision, token: stored) else { return }
            clearSession()
        } catch {
            guard isCurrentSession(revision: revision, token: stored) else { return }
            errorText = "账户服务暂时不可用 / Account service unavailable"
        }
    }

    func signIn(_ credential: CommunityAppleCredential) async throws {
        guard !isSigningIn else { return }
        invalidatePendingWork(sendStop: true)
        let revision = sessionRevision
        let operationID = UUID()
        signInOperationID = operationID
        restoreOperationID = nil
        isRestoring = false
        isSigningIn = true
        errorText = nil
        defer {
            if signInOperationID == operationID {
                isSigningIn = false
                signInOperationID = nil
            }
        }

        do {
            let result = try await api.signIn(credential)
            guard revision == sessionRevision else { throw CancellationError() }

            do {
                try tokenStore.save(result.token)
            } catch {
                await api.logout(token: result.token)
                throw error
            }

            guard revision == sessionRevision else { throw CancellationError() }
            token = result.token
            account = result.account
            leaseVersion = 0
            activeSeconds = 0
            errorText = nil
            startHeartbeatIfNeeded()
        } catch {
            guard revision == sessionRevision else { throw error }
            errorText = "登录失败，请稍后重试 / Could not sign in"
            throw error
        }
    }

    func setForeground(_ foreground: Bool) {
        guard foreground != isForeground else {
            if foreground { startHeartbeatIfNeeded() }
            return
        }
        isForeground = foreground
        if foreground {
            startHeartbeatIfNeeded()
        } else {
            invalidatePendingWork(sendStop: true)
        }
    }

    func refreshLeaderboard() async {
        do {
            let result = try await api.leaderboard(token: token)
            leaderboard = result.entries
            currentRank = result.me
        } catch {
            errorText = "排行榜暂时不可用 / Leaderboard unavailable"
        }
    }

    func updateProfile(nickname: String, leaderboardVisible: Bool) async {
        guard let token else { return }
        do {
            account = try await api.updateProfile(token: token, nickname: nickname, leaderboardVisible: leaderboardVisible)
            errorText = nil
            await refreshLeaderboard()
        } catch let error as CommunityServiceError where error.isAuthenticationFailure {
            clearSession()
        } catch {
            errorText = "资料保存失败 / Profile could not be saved"
        }
    }

    func applyServerBalance(_ points: Int?) {
        guard let points else { return }
        account?.pointsBalance = points
    }

    func logout() {
        let currentToken = token
        clearSession()
        if let currentToken {
            Task { await api.logout(token: currentToken) }
        }
    }

    private func startHeartbeatIfNeeded() {
        guard isForeground, isAuthenticated, heartbeatTask == nil else { return }
        isAccruing = true
        heartbeatTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                await self.heartbeat()
                guard !Task.isCancelled else { return }
                do {
                    try await Task.sleep(nanoseconds: 20_000_000_000)
                } catch {
                    return
                }
            }
        }
    }

    private func heartbeat() async {
        guard let token else { return }
        let revision = sessionRevision
        let requestLeaseVersion = leaseVersion
        do {
            let result = try await api.heartbeat(token: token, leaseVersion: requestLeaseVersion)
            guard isCurrentSession(revision: revision, token: token) else { return }
            account?.pointsBalance = result.points
            activeSeconds = result.activeSeconds
            leaseVersion = result.leaseVersion
        } catch let error as CommunityServiceError where error.isAuthenticationFailure {
            guard isCurrentSession(revision: revision, token: token) else { return }
            clearSession()
        } catch {
            guard isCurrentSession(revision: revision, token: token) else { return }
            isAccruing = false
        }
    }

    private func invalidatePendingWork(sendStop: Bool) {
        sessionRevision &+= 1
        heartbeatTask?.cancel()
        heartbeatTask = nil
        isAccruing = false

        guard sendStop, let token else { return }
        let version = leaseVersion
        leaseVersion = 0
        let api = api
        Task {
            await api.stopHeartbeat(token: token, leaseVersion: version)
        }
    }

    private func isCurrentSession(revision: UInt64, token: String) -> Bool {
        revision == sessionRevision && self.token == token
    }

    private func clearSession() {
        invalidatePendingWork(sendStop: false)
        account = nil
        token = nil
        activeSeconds = 0
        leaseVersion = 0
        isRestoring = false
        isSigningIn = false
        restoreOperationID = nil
        signInOperationID = nil
        try? tokenStore.delete()
    }
}

@MainActor
final class CommunityMessageStore: ObservableObject {
    static let roomID = "codexpilot"

    @Published private(set) var messages: [CommunityMessage] = []
    @Published private(set) var isLoading = false
    @Published private(set) var isPosting = false
    @Published private(set) var feedback: String?
    @Published private(set) var blockedAuthors: Set<String>

    private let account = CommunityAccountStore.shared
    private let api = CommunityAPI()
    private let defaults = UserDefaults.standard
    private let clientIdentifier: String
    private let blockedAuthorsKey = "codexpilot_community_blocked_authors"
    private let clientIdentifierKey = "codexpilot_community_client_identifier"

    init() {
        blockedAuthors = Set(defaults.stringArray(forKey: blockedAuthorsKey) ?? [])
        if let stored = defaults.string(forKey: clientIdentifierKey), !stored.isEmpty {
            clientIdentifier = stored
        } else {
            let created = UUID().uuidString.lowercased()
            defaults.set(created, forKey: clientIdentifierKey)
            clientIdentifier = created
        }
    }

    var visibleMessages: [CommunityMessage] {
        messages
            .filter { $0.expiresAt > Date() && !blockedAuthors.contains($0.authorKey) }
            .sorted { $0.createdAt > $1.createdAt }
    }

    func refresh() async {
        isLoading = true
        defer { isLoading = false }
        do {
            messages = try await api.messages(roomId: Self.roomID)
            feedback = nil
        } catch {
            feedback = "交流内容同步失败 / Could not refresh discussion"
        }
    }

    func send(_ text: String) async -> Bool {
        let trimmed = String(text.trimmingCharacters(in: .whitespacesAndNewlines).prefix(200))
        guard !trimmed.isEmpty else { return false }
        guard let token = account.authorizationToken, account.isAuthenticated else {
            feedback = "请先登录后再发言 / Sign in to post"
            return false
        }
        guard (account.account?.pointsBalance ?? 0) >= 3 else {
            feedback = "发言需要 3 积分 / Posting costs 3 points"
            return false
        }

        isPosting = true
        defer { isPosting = false }
        do {
            let result = try await api.postMessage(token: token, roomId: Self.roomID, text: trimmed)
            account.applyServerBalance(result.pointsBalance)
            messages.removeAll { $0.id == result.message.id }
            messages.insert(result.message, at: 0)
            feedback = nil
            await refresh()
            return true
        } catch let error as CommunityServiceError {
            switch error {
            case let .server(_, code) where code == "insufficient_points":
                feedback = "积分不足，请保持应用运行以获取积分 / Not enough points"
            case let .server(_, code) where code == "cooldown":
                feedback = "请稍后再发言 / Please wait before posting again"
            case let .server(_, code) where code == "objectionable_content":
                feedback = "内容不符合社区规则 / This post violates community rules"
            default:
                feedback = "发送失败，请稍后重试 / Could not send post"
            }
            return false
        } catch {
            feedback = "发送失败，请稍后重试 / Could not send post"
            return false
        }
    }

    func report(_ message: CommunityMessage, reason: CommunityReportReason) async {
        do {
            try await api.report(message: message, reason: reason, reporterId: clientIdentifier)
            feedback = "已提交举报 / Report submitted"
        } catch {
            feedback = "举报发送失败 / Could not submit report"
        }
    }

    func block(_ authorKey: String) {
        guard !authorKey.isEmpty else { return }
        blockedAuthors.insert(authorKey)
        defaults.set(blockedAuthors.sorted(), forKey: blockedAuthorsKey)
    }
}

private final class CommunityTokenStore {
    private let service = "com.lynncat.codexpilot.community"
    private let account = "primary-session"

    func read() throws -> String? {
        var query = baseQuery
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess else { throw CommunityServiceError.keychain(status) }
        guard let data = result as? Data, let token = String(data: data, encoding: .utf8), !token.isEmpty else {
            throw CommunityServiceError.invalidToken
        }
        return token
    }

    func save(_ token: String) throws {
        guard let data = token.data(using: .utf8), !data.isEmpty else { throw CommunityServiceError.invalidToken }
        let attributes = [kSecValueData as String: data]
        let update = SecItemUpdate(baseQuery as CFDictionary, attributes as CFDictionary)
        if update == errSecSuccess { return }
        guard update == errSecItemNotFound else { throw CommunityServiceError.keychain(update) }
        var item = baseQuery
        item[kSecValueData as String] = data
        item[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        let add = SecItemAdd(item as CFDictionary, nil)
        guard add == errSecSuccess else { throw CommunityServiceError.keychain(add) }
    }

    func delete() throws {
        let status = SecItemDelete(baseQuery as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else { throw CommunityServiceError.keychain(status) }
    }

    private var baseQuery: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
    }
}

enum CommunityInstallationID {
    static let key = "codexpilot_community_installation_identifier"

    static var current: String {
        if let identifier = UserDefaults.standard.string(forKey: key), !identifier.isEmpty {
            return identifier
        }
        let identifier = UUID().uuidString.lowercased()
        UserDefaults.standard.set(identifier, forKey: key)
        return identifier
    }
}
