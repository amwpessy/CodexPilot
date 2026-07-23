import Foundation
import XCTest
@testable import MacStatusCodexMonitor

final class CommunityServiceTests: XCTestCase {
    override func tearDown() {
        CommunityStubURLProtocol.reset()
        super.tearDown()
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
}

private final class CommunityStubURLProtocol: URLProtocol {
    private static let lock = NSLock()
    private static var storedRequests: [URLRequest] = []
    static var responseData = Data()

    static var requests: [URLRequest] {
        lock.withLock { storedRequests }
    }

    static func reset() {
        lock.withLock {
            storedRequests = []
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
        let data = Self.lock.withLock { () -> Data in
            Self.storedRequests.append(request)
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
}
