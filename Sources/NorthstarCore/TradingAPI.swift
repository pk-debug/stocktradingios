/// TradingAPI.swift speaks the paper-account HTTP contract. A durable order ID works like a receipt number, preventing an uncertain retry from buying twice.
import Foundation

#if canImport(FoundationNetworking)
  import FoundationNetworking
#endif

public struct HTTPResult: Sendable {
  public let data: Data
  public let status: Int
  public init(data: Data = Data(), status: Int) {
    self.data = data
    self.status = status
  }
}

public protocol HTTPTransport: Sendable {
  func send(_ request: URLRequest) async throws -> HTTPResult
}

/// Reject all redirects so a bearer token can never follow a redirect to another host.
private final class NoRedirects: NSObject, URLSessionTaskDelegate, Sendable {
  func urlSession(
    _ session: URLSession, task: URLSessionTask,
    willPerformHTTPRedirection response: HTTPURLResponse,
    newRequest request: URLRequest, completionHandler: @escaping @Sendable (URLRequest?) -> Void
  ) {
    completionHandler(nil)
  }
}

public final class URLSessionTransport: HTTPTransport, Sendable {
  private let session: URLSession
  public init() {
    let configuration = URLSessionConfiguration.ephemeral
    configuration.timeoutIntervalForRequest = 15
    configuration.timeoutIntervalForResource = 20
    configuration.urlCache = nil
    configuration.httpCookieStorage = nil
    configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
    session = URLSession(configuration: configuration, delegate: NoRedirects(), delegateQueue: nil)
  }
  public func send(_ request: URLRequest) async throws -> HTTPResult {
    let (data, response) = try await session.data(for: request)
    guard let response = response as? HTTPURLResponse else { throw TradingFailure.invalidResponse }
    return HTTPResult(data: data, status: response.statusCode)
  }
}

public struct OrderRequest: Codable, Equatable, Sendable {
  public let symbol: String
  public let side: OrderSide
  public let quantity: Int
  public init(symbol: String, side: OrderSide, quantity: Int) {
    self.symbol = symbol
    self.side = side
    self.quantity = quantity
  }
}
public struct PendingOrder: Codable, Equatable, Sendable {
  public let key: UUID
  public let request: OrderRequest
  public init(key: UUID = UUID(), request: OrderRequest) {
    self.key = key
    self.request = request
  }
}
public struct AccountData: Sendable {
  public let ledger: TradingLedger
  public let assets: [MarketAsset]
  public let indexes: [MarketIndex]
  public let pending: PendingOrder?
}

/// A single account session; serializes operations across suspension points explicitly.
/// Authentication stays in memory. Retry intents survive restart, scoped to origin + username.
public actor RemoteAccount {
  public let origin: URL
  private let transport: any HTTPTransport
  private let storage: any AccountStorage
  private var identityProvider: (any AccessTokenProviding)?
  private var token: String?
  private var expiresAt: Date?
  private var owner: String?
  public private(set) var pending: PendingOrder?
  private var busy = false
  private var pendingKey: String {
    "pending:\(origin.absoluteString):\(owner ?? "")"
  }

  public init(
    origin: String, transport: any HTTPTransport = URLSessionTransport(),
    storage: any AccountStorage,
    allowLocalHTTP: Bool = false
  ) throws {
    guard let components = URLComponents(string: origin), let host = components.host, !host.isEmpty,
      components.user == nil, components.password == nil, components.query == nil,
      components.fragment == nil,
      components.path.isEmpty || components.path == "/",
      components.scheme == "https"
        || (allowLocalHTTP && components.scheme == "http"
          && ["localhost", "127.0.0.1"].contains(host)),
      let url = components.url
    else {
      throw TradingFailure.validation(
        "Use an HTTPS API origin without credentials, path, query or fragment.")
    }
    self.origin =
      url.absoluteString.hasSuffix("/") ? URL(string: String(url.absoluteString.dropLast()))! : url
    self.transport = transport
    self.storage = storage
  }

  private func begin() throws {
    guard !busy else { throw TradingFailure.busy }
    busy = true
  }
  private struct Credentials: Encodable {
    let username: String
    let password: String
  }
  private struct Session: Decodable {
    let token: String
    let expiresAt: Double
  }
  private struct Snapshot: Decodable {
    let cash: Double
    let positions: [Position]
    let orders: [SimulatedOrder]
    let watchlist: [String]
    let currency: String
    func ledger() throws -> TradingLedger {
      guard currency == "INR", cash.isFinite, cash >= 0,
        positions.allSatisfy({ $0.quantity > 0 && $0.averageCost.isFinite && $0.averageCost >= 0 })
      else {
        throw TradingFailure.invalidResponse
      }
      return TradingLedger(cash: cash, positions: positions, orders: orders, watchlist: watchlist)
    }
  }
  public static func validateCredentials(username: String, password: String) throws {
    guard username.range(of: "^[a-zA-Z0-9_.-]{3,40}$", options: .regularExpression) != nil,
      (12...128).contains(password.count)
    else {
      throw TradingFailure.validation(
        "Use a 3–40 character username (letters, numbers, _, . or -) and a 12–128 character password."
      )
    }
  }

  public func authenticate(username: String, password: String, register: Bool) async throws {
    try begin()
    defer { busy = false }
    try Self.validateCredentials(username: username, password: password)
    identityProvider = nil
    token = nil
    owner = nil
    pending = nil
    expiresAt = nil
    let session: Session = try await decoded(
      "/api/v2/auth/\(register ? "register" : "login")", method: "POST",
      body: JSONEncoder().encode(Credentials(username: username, password: password)),
      authenticated: false)
    let identity = username.lowercased()
    let key = "pending:\(origin.absoluteString):\(identity)"
    let data = try await storage.read(key)
    let restored = try data.map { try JSONDecoder().decode(PendingOrder.self, from: $0) }
    owner = identity
    pending = restored
    token = session.token
    expiresAt = Date(timeIntervalSince1970: session.expiresAt)
  }

  /// Attach a hosted identity only after its code exchange has completed. The
  /// subsequent API snapshot, not local JWT decoding, establishes account access.
  public func useIdentity(_ provider: any AccessTokenProviding, subject: String) async throws {
    try begin()
    defer { busy = false }
    let data = try await storage.read("pending:\(origin.absoluteString):\(subject)")
    let restored = try data.map { try JSONDecoder().decode(PendingOrder.self, from: $0) }
    identityProvider = provider
    token = nil
    expiresAt = nil
    owner = subject
    pending = restored
  }
  /// Local teardown does not erase a durable unconfirmed order.
  public func forgetIdentity() throws {
    try begin()
    defer { busy = false }
    identityProvider = nil
    token = nil
    expiresAt = nil
    owner = nil
    pending = nil
  }

  public func load() async throws -> AccountData {
    try begin()
    defer { busy = false }
    let assets: [MarketAsset] = try await decoded("/api/v2/assets")
    let indexes: [MarketIndex] = try await decoded("/api/v2/indexes")
    let snapshot: Snapshot = try await decoded("/api/v2/snapshot")
    guard !assets.isEmpty, Set(assets.map(\.symbol)).count == assets.count,
      assets.allSatisfy({
        $0.price.isFinite && $0.price > 0 && $0.price <= 1_000_000_000 && $0.change.isFinite
          && $0.changePercent.isFinite && $0.history.allSatisfy(\.isFinite)
      })
    else {
      throw TradingFailure.invalidResponse
    }
    return AccountData(
      ledger: try snapshot.ledger(), assets: assets, indexes: indexes, pending: pending)
  }

  public func submit(_ request: OrderRequest, execution: ExecutionMode = .paper) async throws
    -> TradingLedger
  {
    try begin()
    defer { busy = false }
    try ExecutionPolicy.validate(execution)
    guard pending == nil else { throw TradingFailure.unresolvedOrder }
    try checkSession()
    guard (1...1_000_000).contains(request.quantity) else {
      throw TradingFailure.validation("Enter 1–1,000,000 whole shares.")
    }
    let order = PendingOrder(request: request)
    // A failed journal write must prevent the POST, otherwise a restart could buy twice.
    try await save(order)
    return try await sendPending(order)
  }
  public func retry() async throws -> TradingLedger {
    try begin()
    defer { busy = false }
    guard let pending else { throw TradingFailure.validation("There is no unconfirmed order.") }
    return try await sendPending(pending)
  }
  private func sendPending(_ order: PendingOrder) async throws -> TradingLedger {
    do {
      _ = try await request(
        "/api/v2/orders", method: "POST", body: JSONEncoder().encode(order.request), key: order.key)
    } catch let failure as TradingFailure {
      if case .http(let status) = failure, [400, 404, 409, 422].contains(status) {
        try await save(nil)
      }
      throw failure
    }
    // Only a definitive POST rejection can discard intent. A failed snapshot never can.
    let snapshot: Snapshot = try await decoded("/api/v2/snapshot")
    let ledger = try snapshot.ledger()
    try await save(nil)
    return ledger
  }
  private func save(_ value: PendingOrder?) async throws {
    guard owner != nil else { throw TradingFailure.missingSession }
    try await storage.write(try value.map { try JSONEncoder().encode($0) }, key: pendingKey)
    pending = value
  }
  public func watch(_ symbol: String, enabled: Bool) async throws -> TradingLedger {
    try begin()
    defer { busy = false }
    guard symbol.range(of: "^[A-Z0-9.-]{1,16}$", options: .regularExpression) != nil else {
      throw TradingFailure.invalidResponse
    }
    _ = try await request("/api/v2/watchlist/\(symbol)", method: enabled ? "PUT" : "DELETE")
    let snapshot: Snapshot = try await decoded("/api/v2/snapshot")
    return try snapshot.ledger()
  }
  public func signOut() async throws {
    try begin()
    defer {
      busy = false
      identityProvider = nil
      token = nil
      expiresAt = nil
      owner = nil
      pending = nil
    }
    _ = try await request("/api/v2/auth/logout", method: "POST")
  }
  public func deleteAccount() async throws {
    try begin()
    defer { busy = false }
    _ = try await request("/api/v2/account", method: "DELETE")
    try await save(nil)
    identityProvider = nil
    token = nil
    owner = nil
    expiresAt = nil
    pending = nil
  }
  private func checkSession() throws {
    if identityProvider != nil { return }
    guard token != nil, let expiresAt, expiresAt > Date() else {
      throw TradingFailure.missingSession
    }
  }
  private func request(
    _ path: String, method: String = "GET", body: Data? = nil, key: UUID? = nil,
    authenticated: Bool = true
  ) async throws -> Data {
    if authenticated {
      try checkSession()
      if let identityProvider { token = try await identityProvider.validAccessToken() }
    }
    var request = URLRequest(url: origin.appendingPathComponent(String(path.dropFirst())))
    request.httpMethod = method
    request.httpBody = body
    request.timeoutInterval = 15
    request.setValue("application/json", forHTTPHeaderField: "Accept")
    if body != nil { request.setValue("application/json", forHTTPHeaderField: "Content-Type") }
    if authenticated, let token {
      request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    }
    if let key {
      request.setValue(key.uuidString.lowercased(), forHTTPHeaderField: "Idempotency-Key")
    }
    let result = try await transport.send(request)
    guard (200..<300).contains(result.status) else { throw TradingFailure.http(result.status) }
    return result.data
  }
  private func decoded<T: Decodable>(
    _ path: String, method: String = "GET", body: Data? = nil,
    authenticated: Bool = true
  ) async throws -> T {
    let data = try await request(path, method: method, body: body, authenticated: authenticated)
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .custom { decoder in
      let value = try decoder.singleValueContainer().decode(String.self)
      let formatter = ISO8601DateFormatter()
      formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
      if let date = formatter.date(from: value) { return date }
      formatter.formatOptions = [.withInternetDateTime]
      if let date = formatter.date(from: value) { return date }
      throw TradingFailure.invalidResponse
    }
    do { return try decoder.decode(T.self, from: data) } catch {
      throw TradingFailure.invalidResponse
    }
  }
}
