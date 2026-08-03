import Foundation
import Security
import XCTest
@testable import MacStatusCodexMonitor

final class CommunityServiceTests: XCTestCase {
    override func tearDown() {
        CommunityStubURLProtocol.reset()
        super.tearDown()
    }

    func testCommunityCredentialRulesAcceptEightCharacterAlphanumericPassword() {
        XCTAssertTrue(
            CommunityCredentialRules.areValid(username: "pilot-user", password: "market88")
        )
    }

    func testCommunityCredentialRulesRejectWeakPasswords() {
        XCTAssertFalse(
            CommunityCredentialRules.areValid(username: "pilot-user", password: "abc1234")
        )
        XCTAssertFalse(
            CommunityCredentialRules.areValid(username: "pilot-user", password: "abcdefgh")
        )
        XCTAssertFalse(
            CommunityCredentialRules.areValid(username: "pilot-user", password: "12345678")
        )
    }

    func testCommunityTokenStoreUsesExpectedKeychainBackend() {
        let query = CommunityTokenStore.query(account: "test-session")

        XCTAssertEqual(query[kSecClass as String] as? String, kSecClassGenericPassword as String)
        XCTAssertEqual(query[kSecAttrService as String] as? String, CommunityTokenStore.service)
        XCTAssertEqual(query[kSecAttrAccount as String] as? String, "test-session")
#if DIRECT_DISTRIBUTION
        XCTAssertEqual(CommunityTokenStore.service, "com.lynncat.codexpilot.community.direct")
        XCTAssertNil(query[kSecUseDataProtectionKeychain as String])
#else
        XCTAssertEqual(query[kSecUseDataProtectionKeychain as String] as? Bool, true)
#endif
    }

    func testCommunityTokenStoreRoundTripsSessionInConfiguredKeychain() throws {
        let service = "\(CommunityTokenStore.service).tests.\(UUID().uuidString)"
        let store = CommunityTokenStore(service: service, account: "round-trip-session")
        defer { try? store.delete() }

        try store.save("first-session-token")
        XCTAssertEqual(try store.read(), "first-session-token")

        try store.save("updated-session-token")
        XCTAssertEqual(try store.read(), "updated-session-token")

        try store.delete()
        XCTAssertNil(try store.read())
    }

    func testAppleSignInSendsOneRequestAndDecodesSession() async throws {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [CommunityStubURLProtocol.self]
        let session = URLSession(configuration: configuration)
        defer { session.invalidateAndCancel() }

        CommunityStubURLProtocol.responseData = Data(
            """
            {
              "sessionToken": "session-token",
              "account": {
                "id": "account-id",
                "nickname": "Kream",
                "pointsBalance": 265,
                "pointsEarnedTotal": 300,
                "leaderboardVisible": true
              }
            }
            """.utf8
        )

        let api = CommunityAPI(session: session)
        let result = try await api.signIn(CommunityAppleCredential(
            identityToken: "identity-token",
            authorizationCode: "authorization-code",
            nonce: "raw-nonce",
            installationId: "installation-id",
            platform: "macos"
        ))

        XCTAssertEqual(result.token, "session-token")
        XCTAssertEqual(result.account.nickname, "Kream")
        XCTAssertEqual(result.account.pointsBalance, 265)

        let requests = CommunityStubURLProtocol.requests
        XCTAssertEqual(requests.count, 1)
        let request = try XCTUnwrap(requests.first)
        XCTAssertEqual(request.url?.absoluteString, "https://lynncat.com/markets/auth/apple")
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/json")
    }

    func testPasswordLoginUsesSharedSessionEnvelope() async throws {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [CommunityStubURLProtocol.self]
        let session = URLSession(configuration: configuration)
        defer { session.invalidateAndCancel() }

        CommunityStubURLProtocol.responseData = sessionEnvelopeData
        let api = CommunityAPI(session: session)
        let result = try await api.signIn(
            CommunityPasswordCredential(
                username: "pilot-user",
                password: "correct-horse-42",
                installationId: "installation-id",
                platform: "macos"
            ),
            registering: false
        )

        XCTAssertEqual(result.token, "session-token")
        XCTAssertEqual(result.account.pointsBalance, 265)
        let request = try XCTUnwrap(CommunityStubURLProtocol.requests.first)
        XCTAssertEqual(
            request.url?.absoluteString,
            "https://lynncat.com/markets/auth/password/login"
        )
        XCTAssertEqual(request.httpMethod, "POST")
        let payload = try XCTUnwrap(
            CommunityStubURLProtocol.requestBodies.compactMap { $0 }.first
        )
        let json = try XCTUnwrap(
            JSONSerialization.jsonObject(with: payload) as? [String: String]
        )
        XCTAssertEqual(json["username"], "pilot-user")
        XCTAssertEqual(json["installationId"], "installation-id")
    }

    func testPasswordRegistrationAndLinkUseDedicatedEndpoints() async throws {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [CommunityStubURLProtocol.self]
        let session = URLSession(configuration: configuration)
        defer { session.invalidateAndCancel() }
        let api = CommunityAPI(session: session)
        let credential = CommunityPasswordCredential(
            username: "pilot-user",
            password: "correct-horse-42",
            installationId: "installation-id",
            platform: "macos"
        )

        CommunityStubURLProtocol.responseData = sessionEnvelopeData
        _ = try await api.signIn(credential, registering: true)
        CommunityStubURLProtocol.responseData = Data(#"{"linked":true}"#.utf8)
        try await api.linkPasswordLogin(
            token: "session-token",
            username: "pilot-user",
            password: "correct-horse-42"
        )

        XCTAssertEqual(CommunityStubURLProtocol.requests.count, 2)
        XCTAssertEqual(
            CommunityStubURLProtocol.requests[0].url?.absoluteString,
            "https://lynncat.com/markets/auth/password/register"
        )
        XCTAssertEqual(
            CommunityStubURLProtocol.requests[1].url?.absoluteString,
            "https://lynncat.com/markets/auth/password/link"
        )
        XCTAssertEqual(
            CommunityStubURLProtocol.requests[1].value(forHTTPHeaderField: "Authorization"),
            "Bearer session-token"
        )
    }

    func testPokerStatusDecodesDailyLimitWindow() async throws {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [CommunityStubURLProtocol.self]
        let session = URLSession(configuration: configuration)
        defer { session.invalidateAndCancel() }

        CommunityStubURLProtocol.responseData = Data(
            """
            {
              "poker": {
                "pointsBalance": 1900,
                "dailyWon": 450,
                "dailyLimit": 7500,
                "dailyRemaining": 7050,
                "dayKey": "2026-07-23",
                "resetsAt": 1784822400000
              }
            }
            """.utf8
        )

        let status = try await CommunityAPI(session: session).pokerStatus(token: "session-token")

        XCTAssertEqual(status.pointsBalance, 1_900)
        XCTAssertEqual(status.dailyWon, 450)
        XCTAssertEqual(status.dailyLimit, 7_500)
        XCTAssertEqual(status.dailyRemaining, 7_050)
        let request = try XCTUnwrap(CommunityStubURLProtocol.requests.first)
        XCTAssertEqual(request.url?.absoluteString, "https://lynncat.com/markets/points/poker")
        XCTAssertEqual(request.httpMethod, "GET")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer session-token")
    }

    func testPokerSettlementUsesStableHandIdempotencyKey() async throws {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [CommunityStubURLProtocol.self]
        let session = URLSession(configuration: configuration)
        defer { session.invalidateAndCancel() }

        CommunityStubURLProtocol.responseData = Data(
            """
            {
              "settlement": {
                "handId": "hand-12345678",
                "requestedDelta": 600,
                "appliedDelta": 600,
                "pointsBalance": 2500,
                "dailyWon": 600,
                "dailyLimit": 7500,
                "dailyRemaining": 6900,
                "dayKey": "2026-07-23",
                "resetsAt": 1784822400000
              }
            }
            """.utf8
        )

        let receipt = try await CommunityAPI(session: session).settlePokerHand(
            token: "session-token",
            handId: "hand-12345678",
            delta: 600
        )

        XCTAssertEqual(receipt.appliedDelta, 600)
        XCTAssertEqual(receipt.pointsBalance, 2_500)
        let request = try XCTUnwrap(CommunityStubURLProtocol.requests.first)
        XCTAssertEqual(request.url?.absoluteString, "https://lynncat.com/markets/points/poker/settle")
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(
            request.value(forHTTPHeaderField: "Idempotency-Key"),
            "codexpilot-poker-hand-12345678"
        )
    }

    func testShuihuStatusDecodesCollectionAndDailyDraws() async throws {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [CommunityStubURLProtocol.self]
        let session = URLSession(configuration: configuration)
        defer { session.invalidateAndCancel() }

        CommunityStubURLProtocol.responseData = Data(
            """
            {
              "cards": {
                "pointsBalance": 5200,
                "drawsUsed": 3,
                "dailyLimit": 10,
                "drawsRemaining": 7,
                "dayKey": "2026-07-24",
                "resetsAt": 1784908800000,
                "uniqueCount": 2,
                "totalCopies": 3,
                "rewardClaimed": false,
                "collection": [
                  { "cardId": 1, "copies": 1 },
                  { "cardId": 14, "copies": 2 }
                ]
              }
            }
            """.utf8
        )

        let status = try await CommunityAPI(session: session).shuihuStatus(token: "session-token")

        XCTAssertEqual(status.pointsBalance, 5_200)
        XCTAssertEqual(status.drawsRemaining, 7)
        XCTAssertEqual(status.copies(of: 14), 2)
        let request = try XCTUnwrap(CommunityStubURLProtocol.requests.first)
        XCTAssertEqual(request.url?.absoluteString, "https://lynncat.com/markets/points/shuihu")
        XCTAssertEqual(request.httpMethod, "GET")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer session-token")
    }

    func testShuihuDrawUsesStableIdempotencyKeyAndDecodesReward() async throws {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [CommunityStubURLProtocol.self]
        let session = URLSession(configuration: configuration)
        defer { session.invalidateAndCancel() }

        CommunityStubURLProtocol.responseData = Data(
            """
            {
              "draw": {
                "cardId": 108,
                "isNew": true,
                "copies": 1,
                "cost": 1000,
                "pointsBalance": 1002000,
                "drawsUsed": 1,
                "dailyLimit": 10,
                "drawsRemaining": 9,
                "dayKey": "2026-07-24",
                "resetsAt": 1784908800000,
                "uniqueCount": 108,
                "totalCopies": 139,
                "rewardGranted": true,
                "rewardAmount": 1000000,
                "rewardClaimed": true,
                "collection": [{ "cardId": 108, "copies": 1 }]
              }
            }
            """.utf8
        )

        let receipt = try await CommunityAPI(session: session).drawShuihuCard(
            token: "session-token",
            requestID: "request-123"
        )

        XCTAssertEqual(receipt.cardId, 108)
        XCTAssertTrue(receipt.rewardGranted)
        XCTAssertEqual(receipt.rewardAmount, 1_000_000)
        let request = try XCTUnwrap(CommunityStubURLProtocol.requests.first)
        XCTAssertEqual(request.url?.absoluteString, "https://lynncat.com/markets/points/shuihu/draw")
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(
            request.value(forHTTPHeaderField: "Idempotency-Key"),
            "devpilot-shuihu-request-123"
        )
    }

    private var sessionEnvelopeData: Data {
        Data(
            """
            {
              "sessionToken": "session-token",
              "account": {
                "id": "account-id",
                "nickname": "Kream",
                "pointsBalance": 265,
                "pointsEarnedTotal": 300,
                "leaderboardVisible": true
              }
            }
            """.utf8
        )
    }
}

private final class CommunityStubURLProtocol: URLProtocol {
    private static let lock = NSLock()
    private static var storedRequests: [URLRequest] = []
    private static var storedRequestBodies: [Data?] = []
    static var responseData = Data()

    static var requests: [URLRequest] {
        lock.withLock { storedRequests }
    }

    static var requestBodies: [Data?] {
        lock.withLock { storedRequestBodies }
    }

    static func reset() {
        lock.withLock {
            storedRequests = []
            storedRequestBodies = []
            responseData = Data()
        }
    }

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        let requestBody = Self.bodyData(from: request)
        let data = Self.lock.withLock { () -> Data in
            Self.storedRequests.append(request)
            Self.storedRequestBodies.append(requestBody)
            return Self.responseData
        }
        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: ["Content-Type": "application/json"]
        )!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}

    private static func bodyData(from request: URLRequest) -> Data? {
        if let body = request.httpBody {
            return body
        }
        guard let stream = request.httpBodyStream else {
            return nil
        }

        stream.open()
        defer { stream.close() }

        var result = Data()
        var buffer = [UInt8](repeating: 0, count: 4_096)
        while stream.hasBytesAvailable {
            let count = stream.read(&buffer, maxLength: buffer.count)
            if count < 0 {
                return nil
            }
            if count == 0 {
                break
            }
            result.append(buffer, count: count)
        }
        return result
    }
}
