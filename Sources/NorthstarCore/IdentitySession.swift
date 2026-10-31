/// IdentitySession.swift connects a hosted identity service to the trading API.
/// Think of an access token as a short-lived entry ticket and a refresh token as a
/// private renewal receipt. Only the operating system Keychain may keep that receipt.
import Foundation

#if canImport(FoundationNetworking)
  import FoundationNetworking
#endif

/// The API client asks this boundary for a current ticket before each request.
public protocol AccessTokenProviding: Sendable {
  func validAccessToken() async throws -> String
}

/// Public application settings, never a client secret. This implementation targets
/// Auth0's standard OAuth endpoints and configurable hosted-login connections.
public struct IdentityConfiguration: Sendable {
  public let issuer: URL
  public let clientID: String
  public let audience: String
  public let redirectURI: String
  public init(issuer: String, clientID: String, audience: String, redirectURI: String) throws {
    guard let url = URL(string: issuer),
      let c = URLComponents(url: url, resolvingAgainstBaseURL: false),
      c.scheme == "https", c.host != nil, c.user == nil, c.password == nil,
      c.query == nil, c.fragment == nil, c.path.isEmpty || c.path == "/",
      !clientID.isEmpty, !audience.isEmpty,
      let callback = URLComponents(string: redirectURI), callback.scheme != nil,
      callback.scheme != "http", callback.scheme != "https", callback.host == "auth",
      callback.path == "/callback",
      callback.query == nil, callback.fragment == nil
    else {
      throw TradingFailure.validation(
        "Configure the HTTPS identity issuer, native client ID, API audience and app callback.")
    }
    self.issuer = url
    self.clientID = clientID
    self.audience = audience
    self.redirectURI = redirectURI
  }
  public var sessionKey: String { "identity:\(issuer.absoluteString):\(clientID):\(audience)" }
}

/// The browser must return this exact state and callback. PKCE binds the code to
/// the app that started login, so stealing a callback code is not enough to log in.
public struct AuthorizationAttempt: Sendable {
  public let verifier: String
  public let state: String
  public let configuration: IdentityConfiguration
  public init(configuration: IdentityConfiguration, verifier: String, state: String) {
    self.configuration = configuration
    self.verifier = verifier
    self.state = state
  }
  public func authorizationURL(challenge: String, connection: String?, signup: Bool) throws -> URL {
    guard (43...128).contains(verifier.count), !state.isEmpty, !challenge.isEmpty else {
      throw TradingFailure.invalidResponse
    }
    var c = URLComponents(
      url: configuration.issuer.appendingPathComponent("authorize"), resolvingAgainstBaseURL: false)!
    var items = [
      URLQueryItem(name: "response_type", value: "code"),
      .init(name: "client_id", value: configuration.clientID),
      .init(name: "redirect_uri", value: configuration.redirectURI),
      .init(name: "scope", value: "openid offline_access"),
      .init(name: "audience", value: configuration.audience), .init(name: "state", value: state),
      .init(name: "code_challenge", value: challenge),
      .init(name: "code_challenge_method", value: "S256"),
      .init(name: "prompt", value: "login"),
    ]
    if let connection { items.append(.init(name: "connection", value: connection)) }
    if signup { items.append(.init(name: "screen_hint", value: "signup")) }
    c.queryItems = items
    return c.url!
  }
  public func code(from callback: URL) throws -> String {
    guard var expected = URLComponents(string: configuration.redirectURI),
      var actual = URLComponents(url: callback, resolvingAgainstBaseURL: false)
    else { throw TradingFailure.invalidResponse }
    let items = actual.queryItems ?? []
    actual.query = nil
    expected.query = nil
    guard actual == expected,
      items.filter({ $0.name == "state" }).count == 1,
      items.first(where: { $0.name == "state" })?.value == state,
      !items.contains(where: { $0.name == "error" }),
      items.filter({ $0.name == "code" }).count == 1,
      let code = items.first(where: { $0.name == "code" })?.value, !code.isEmpty
    else {
      throw TradingFailure.validation(
        "Sign-in was cancelled or its security check failed. Start again.")
    }
    return code
  }
}

/// Claims are inspected for UI lifecycle only. Decoding JSON is NOT signature
/// verification: the backend must verify RS256, issuer, audience and expiry.
public struct AccessTokenClaims: Decodable, Sendable {
  public let sub: String
  public let iss: String
  public let exp: Double
  public init(token: String, configuration: IdentityConfiguration, now: Date = Date()) throws {
    let parts = token.split(separator: ".", omittingEmptySubsequences: false)
    guard parts.count == 3, !parts[2].isEmpty else { throw TradingFailure.invalidResponse }
    var payload = String(parts[1]).replacingOccurrences(of: "-", with: "+").replacingOccurrences(
      of: "_", with: "/")
    payload += String(repeating: "=", count: (4 - payload.count % 4) % 4)
    guard let data = Data(base64Encoded: payload) else { throw TradingFailure.invalidResponse }
    struct Claims: Decodable {
      let sub: String
      let iss: String
      let exp: Double
      let aud: Audience
    }
    enum Audience: Decodable {
      case one(String)
      case many([String])
      init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if let one = try? c.decode(String.self) {
          self = .one(one)
        } else {
          self = .many(try c.decode([String].self))
        }
      }
      func contains(_ value: String) -> Bool {
        switch self {
        case .one(let a): return a == value
        case .many(let a): return a.contains(value)
        }
      }
    }
    let claims = try JSONDecoder().decode(Claims.self, from: data)
    let issuer =
      configuration.issuer.absoluteString.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
      + "/"
    guard claims.iss == issuer, !claims.sub.isEmpty, claims.aud.contains(configuration.audience),
      claims.exp.isFinite,
      claims.exp > now.timeIntervalSince1970
    else { throw TradingFailure.missingSession }
    sub = claims.sub
    iss = claims.iss
    exp = claims.exp
  }
}

/// Owns refresh-token rotation. Its storage MUST be an iOS Keychain implementation
/// in the app; tests use in-memory storage to examine failure paths without secrets.
public actor IdentitySession: AccessTokenProviding {
  private struct Tokens: Codable, Sendable {
    let accessToken: String
    let refreshToken: String
    let subject: String
  }
  private struct Response: Decodable {
    let access_token: String
    let refresh_token: String?
    let token_type: String
    let expires_in: Double
  }
  private let configuration: IdentityConfiguration
  private let secureStorage: any AccountStorage
  private let transport: any HTTPTransport
  private var tokens: Tokens?
  private var busy = false
  private var generation = 0
  public init(
    configuration: IdentityConfiguration, secureStorage: any AccountStorage,
    transport: any HTTPTransport = URLSessionTransport()
  ) {
    self.configuration = configuration
    self.secureStorage = secureStorage
    self.transport = transport
  }
  public func exchange(code: String, verifier: String) async throws -> String {
    guard !busy else { throw TradingFailure.busy }
    busy = true
    defer { busy = false }
    let attempt = generation
    let response = try await tokenRequest([
      "grant_type": "authorization_code", "client_id": configuration.clientID,
      "code": code, "code_verifier": verifier, "redirect_uri": configuration.redirectURI,
    ])
    guard let refresh = response.refresh_token, !refresh.isEmpty else {
      throw TradingFailure.validation(
        "Enable offline access and rotating refresh tokens for the native identity client.")
    }
    let claims = try AccessTokenClaims(token: response.access_token, configuration: configuration)
    try await persist(
      .init(accessToken: response.access_token, refreshToken: refresh, subject: claims.sub),
      generation: attempt)
    return claims.sub
  }
  public func restore() async throws -> String? {
    guard !busy else { throw TradingFailure.busy }
    busy = true
    defer { busy = false }
    let attempt = generation
    guard let data = try await secureStorage.read(configuration.sessionKey) else { return nil }
    guard attempt == generation else { throw TradingFailure.missingSession }
    tokens = try JSONDecoder().decode(Tokens.self, from: data)
    _ = try await accessToken()
    return tokens?.subject
  }
  public func validAccessToken() async throws -> String {
    guard !busy else { throw TradingFailure.busy }
    busy = true
    defer { busy = false }
    return try await accessToken()
  }
  private func accessToken() async throws -> String {
    guard let current = tokens else { throw TradingFailure.missingSession }
    if let claims = try? AccessTokenClaims(
      token: current.accessToken, configuration: configuration),
      claims.exp > Date().timeIntervalSince1970 + 60
    {
      return current.accessToken
    }
    let attempt = generation
    do {
      let response = try await tokenRequest([
        "grant_type": "refresh_token", "client_id": configuration.clientID,
        "refresh_token": current.refreshToken,
      ])
      let claims = try AccessTokenClaims(token: response.access_token, configuration: configuration)
      guard claims.sub == current.subject else {
        try await clearLocal()
        throw TradingFailure.missingSession
      }
      // Persist a rotated receipt before returning the renewed ticket.
      try await persist(
        .init(
          accessToken: response.access_token,
          refreshToken: response.refresh_token ?? current.refreshToken, subject: claims.sub),
        generation: attempt)
      return response.access_token
    } catch {
      if let failure = error as? TradingFailure, failure == .http(400) || failure == .http(401) {
        try await clearLocal()
        throw TradingFailure.missingSession
      }
      throw error
    }
  }
  private func persist(_ value: Tokens, generation attempt: Int) async throws {
    guard attempt == generation else { throw TradingFailure.missingSession }
    do {
      try await secureStorage.write(JSONEncoder().encode(value), key: configuration.sessionKey)
      guard attempt == generation else {
        try await secureStorage.write(nil, key: configuration.sessionKey)
        throw TradingFailure.missingSession
      }
      tokens = value
    } catch {
      tokens = nil
      throw error
    }
  }
  /// Revocation is best effort remotely, but local credentials are always erased.
  public func signOut() async throws {
    guard !busy else { throw TradingFailure.busy }
    busy = true
    defer { busy = false }
    var refresh = tokens?.refreshToken
    if refresh == nil, let data = try await secureStorage.read(configuration.sessionKey) {
      refresh = (try? JSONDecoder().decode(Tokens.self, from: data))?.refreshToken
    }
    try await clearLocal()
    if let refresh {
      _ = try await form(
        "oauth/revoke",
        fields: [
          "client_id": configuration.clientID, "token": refresh, "token_type_hint": "refresh_token",
        ])
    }
  }
  public func clearLocal() async throws {
    generation += 1
    tokens = nil
    try await secureStorage.write(nil, key: configuration.sessionKey)
  }
  private func tokenRequest(_ fields: [String: String]) async throws -> Response {
    let result = try await form("oauth/token", fields: fields)
    let response = try JSONDecoder().decode(Response.self, from: result)
    guard response.token_type.lowercased() == "bearer", response.expires_in > 0 else {
      throw TradingFailure.invalidResponse
    }
    return response
  }
  private func form(_ path: String, fields: [String: String]) async throws -> Data {
    var request = URLRequest(url: configuration.issuer.appendingPathComponent(path))
    request.httpMethod = "POST"
    request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
    // QueryItem encodes URL query strings, but form bodies must encode '+' too.
    let allowed = CharacterSet(
      charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~")
    request.httpBody = Data(
      fields.sorted { $0.key < $1.key }.map {
        "\($0.key.addingPercentEncoding(withAllowedCharacters: allowed)!)=\($0.value.addingPercentEncoding(withAllowedCharacters: allowed)!)"
      }.joined(separator: "&").utf8)
    let result = try await transport.send(request)
    guard (200..<300).contains(result.status) else { throw TradingFailure.http(result.status) }
    return result.data
  }
}
