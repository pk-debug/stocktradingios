/// IdentityTests.swift treats the browser callback like an untrusted message and
/// tests token renewal with fake tickets. Server tests verify actual signatures.

import Foundation
import XCTest

@testable import NorthstarCore

#if canImport(FoundationNetworking)
  import FoundationNetworking
#endif

private func testJWT(
  subject: String = "google|learner", issuer: String = "https://identity.example/",
  audience: String = "paper-api", lifetime: Double = 3600
) throws -> String {
  let claims: [String: Any] = [
    "iss": issuer, "aud": audience, "sub": subject, "exp": Date().timeIntervalSince1970 + lifetime,
  ]
  let payload = try JSONSerialization.data(withJSONObject: claims).base64EncodedString()
    .replacingOccurrences(of: "+", with: "-").replacingOccurrences(of: "/", with: "_")
    .replacingOccurrences(of: "=", with: "")
  return "test-header." + payload + ".not-a-real-signature"
}

private actor TokenService: HTTPTransport {
  var replies: [HTTPResult]
  private(set) var requests: [URLRequest] = []
  init(_ replies: [HTTPResult]) { self.replies = replies }
  func send(_ request: URLRequest) throws -> HTTPResult {
    requests.append(request)
    guard !replies.isEmpty else { throw TradingFailure.invalidResponse }
    return replies.removeFirst()
  }
}

/// Hold an HTTP response so a test can erase the session while login is suspended.
private actor HeldTokenService: HTTPTransport {
  let response: HTTPResult
  private var responseWaiter: CheckedContinuation<HTTPResult, Never>?
  private var startWaiter: CheckedContinuation<Void, Never>?
  init(_ response: HTTPResult) { self.response = response }
  func send(_ request: URLRequest) async -> HTTPResult {
    await withCheckedContinuation { continuation in
      responseWaiter = continuation
      startWaiter?.resume()
      startWaiter = nil
    }
  }
  func waitUntilStarted() async {
    if responseWaiter != nil { return }
    await withCheckedContinuation { startWaiter = $0 }
  }
  func release() {
    responseWaiter?.resume(returning: response)
    responseWaiter = nil
  }
}

final class IdentityTests: XCTestCase, @unchecked Sendable {
  private func configuration() throws -> IdentityConfiguration {
    try .init(
      issuer: "https://identity.example/", clientID: "native-public-id", audience: "paper-api",
      redirectURI: "com.example.app://auth/callback")
  }
  private func response(_ token: String, refresh: String?) throws -> HTTPResult {
    var fields: [String: Any] = ["access_token": token, "token_type": "Bearer", "expires_in": 3600]
    if let refresh { fields["refresh_token"] = refresh }
    return .init(data: try JSONSerialization.data(withJSONObject: fields), status: 200)
  }
  func testPKCERequestAndStrictCallbackState() throws {
    let attempt = AuthorizationAttempt(
      configuration: try configuration(), verifier: String(repeating: "a", count: 43),
      state: "random-state")
    let url = try attempt.authorizationURL(
      challenge: "S256-challenge", connection: "sms", signup: true)
    let query = URLComponents(url: url, resolvingAgainstBaseURL: false)!.queryItems!
    XCTAssertEqual(query.first { $0.name == "code_challenge_method" }?.value, "S256")
    XCTAssertEqual(query.first { $0.name == "connection" }?.value, "sms")
    XCTAssertEqual(query.first { $0.name == "screen_hint" }?.value, "signup")
    XCTAssertFalse(query.contains { $0.name == "client_secret" })
    XCTAssertEqual(
      try attempt.code(
        from: URL(string: "com.example.app://auth/callback?code=one-time-code&state=random-state")!),
      "one-time-code")
    for callback in [
      "com.example.app://auth/callback?code=x&state=wrong",
      "com.example.app://evil/callback?code=x&state=random-state",
      "com.example.app://auth/callback?code=x&state=random-state&state=random-state",
      "com.example.app://auth/callback?code=x&state=random-state#error",
      "com.example.app://auth/callback?error=denied&state=random-state",
    ] {
      XCTAssertThrowsError(try attempt.code(from: URL(string: callback)!))
    }
  }
  func testConfigurationAndClaimMismatchAreRejected() throws {
    XCTAssertThrowsError(
      try IdentityConfiguration(
        issuer: "http://identity.example", clientID: "id", audience: "api",
        redirectURI: "app://auth/callback"))
    for token in [
      try testJWT(issuer: "https://other.example/"), try testJWT(audience: "other-api"),
      try testJWT(lifetime: -1), "not-a-jwt",
    ] {
      XCTAssertThrowsError(try AccessTokenClaims(token: token, configuration: configuration()))
    }
  }
  func testRefreshRotationPersistsBeforeReturningAndRestoresSubject() async throws {
    let storage = MemoryAccountStorage()
    let fresh = try testJWT()
    let transport = TokenService([
      try response(testJWT(lifetime: 15), refresh: "first-receipt"),
      try response(fresh, refresh: "rotated-receipt"),
    ])
    let session = IdentitySession(
      configuration: try configuration(), secureStorage: storage, transport: transport)
    let subject = try await session.exchange(
      code: "one-use-code", verifier: String(repeating: "a", count: 43))
    XCTAssertEqual(subject, "google|learner")
    let access = try await session.validAccessToken()
    XCTAssertEqual(access, fresh)
    let stored = await storage.read(try configuration().sessionKey)
    let persisted = try XCTUnwrap(stored)
    XCTAssertTrue(String(decoding: persisted, as: UTF8.self).contains("rotated-receipt"))
    let restarted = IdentitySession(
      configuration: try configuration(), secureStorage: storage, transport: transport)
    let restored = try await restarted.restore()
    XCTAssertEqual(restored, subject)
    let requests = await transport.requests
    XCTAssertEqual(requests.count, 2)
    XCTAssertTrue(
      String(decoding: requests[1].httpBody!, as: UTF8.self).contains("grant_type=refresh_token"))
  }
  func testRevokedRefreshClearsLocalCredentials() async throws {
    let storage = MemoryAccountStorage()
    let config = try configuration()
    let transport = TokenService([
      try response(testJWT(lifetime: 15), refresh: "receipt"), .init(status: 400),
    ])
    let session = IdentitySession(
      configuration: config, secureStorage: storage, transport: transport)
    _ = try await session.exchange(code: "code", verifier: "verifier")
    do {
      _ = try await session.validAccessToken()
      XCTFail("Expected sign-in requirement")
    } catch { XCTAssertEqual(error as? TradingFailure, .missingSession) }
    let stored = await storage.read(config.sessionKey)
    XCTAssertNil(stored)
  }
  func testSignOutErasesLocalTokensEvenIfRemoteRevocationFails() async throws {
    let storage = MemoryAccountStorage()
    let config = try configuration()
    let transport = TokenService([try response(testJWT(), refresh: "receipt"), .init(status: 503)])
    let session = IdentitySession(
      configuration: config, secureStorage: storage, transport: transport)
    _ = try await session.exchange(code: "code", verifier: "verifier")
    do {
      try await session.signOut()
      XCTFail("Expected remote failure")
    } catch {}
    let stored = await storage.read(config.sessionKey)
    XCTAssertNil(stored)
    do {
      _ = try await session.validAccessToken()
      XCTFail("Must be signed out")
    } catch { XCTAssertEqual(error as? TradingFailure, .missingSession) }
  }
  func testFormEncodingDoesNotTurnPlusIntoSpace() async throws {
    let transport = TokenService([try response(testJWT(), refresh: "receipt")])
    let session = IdentitySession(
      configuration: try configuration(), secureStorage: MemoryAccountStorage(),
      transport: transport)
    _ = try await session.exchange(code: "code+with&symbols", verifier: "verifier")
    let requests = await transport.requests
    XCTAssertTrue(
      String(decoding: requests[0].httpBody!, as: UTF8.self).contains("code=code%2Bwith%26symbols"))
  }
  func testClearingSessionDuringExchangePreventsResurrection() async throws {
    let storage = MemoryAccountStorage()
    let config = try configuration()
    let transport = HeldTokenService(try response(testJWT(), refresh: "receipt"))
    let session = IdentitySession(
      configuration: config, secureStorage: storage, transport: transport)
    let exchange = Task { try await session.exchange(code: "code", verifier: "verifier") }
    await transport.waitUntilStarted()
    try await session.clearLocal()
    await transport.release()
    do {
      _ = try await exchange.value
      XCTFail("Cleared login must not reappear")
    } catch { XCTAssertEqual(error as? TradingFailure, .missingSession) }
    let stored = await storage.read(config.sessionKey)
    XCTAssertNil(stored)
  }
  func testRefreshCannotSwitchAccountSubject() async throws {
    let storage = MemoryAccountStorage()
    let config = try configuration()
    let transport = TokenService([
      try response(testJWT(lifetime: 15), refresh: "receipt"),
      try response(testJWT(subject: "different-user"), refresh: "new-receipt"),
    ])
    let session = IdentitySession(
      configuration: config, secureStorage: storage, transport: transport)
    _ = try await session.exchange(code: "code", verifier: "verifier")
    do {
      _ = try await session.validAccessToken()
      XCTFail("Refresh must preserve identity")
    } catch { XCTAssertEqual(error as? TradingFailure, .missingSession) }
    let stored = await storage.read(config.sessionKey)
    XCTAssertNil(stored)
  }
  func testMissingRefreshReceiptIsNotASavedSession() async throws {
    let storage = MemoryAccountStorage()
    let config = try configuration()
    let transport = TokenService([try response(testJWT(), refresh: nil)])
    let session = IdentitySession(
      configuration: config, secureStorage: storage, transport: transport)
    do {
      _ = try await session.exchange(code: "code", verifier: "verifier")
      XCTFail("Expected provider setup error")
    } catch {}
    let stored = await storage.read(config.sessionKey)
    XCTAssertNil(stored)
  }
}
