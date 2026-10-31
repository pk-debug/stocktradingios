/// TradingTests.swift checks the ledger and uncertain-network rules using isolated test accounts and fake HTTP responses.

import Foundation
import XCTest

@testable import NorthstarCore

#if canImport(FoundationNetworking)
  import FoundationNetworking
#endif

final class TradingTests: XCTestCase, @unchecked Sendable {
  func testBuySellAndRejectedOrderPreserveLedger() throws {
    let reliance = try XCTUnwrap(MarketData.asset(for: "RELIANCE"))
    let bought = try TradingRules.placeOrder(
      ledger: .demo, asset: reliance, side: .buy, quantity: 1)
    XCTAssertEqual(bought.cash, 998_715.50)
    XCTAssertEqual(bought.positions.first?.quantity, 9)
    XCTAssertEqual(try XCTUnwrap(bought.positions.first?.averageCost), 1_218.50, accuracy: 0.001)
    XCTAssertEqual(bought.orders.count, 1)
    let hdfc = try XCTUnwrap(MarketData.asset(for: "HDFCBANK"))
    let sold = try TradingRules.placeOrder(ledger: bought, asset: hdfc, side: .sell, quantity: 12)
    XCTAssertNil(sold.positions.first { $0.symbol == "HDFCBANK" })
    XCTAssertEqual(sold.cash, 1_019_936.30)
    XCTAssertThrowsError(
      try TradingRules.placeOrder(ledger: sold, asset: hdfc, side: .sell, quantity: 1))
    XCTAssertEqual(sold.orders.count, 2)
    XCTAssertThrowsError(
      try TradingRules.placeOrder(ledger: .demo, asset: reliance, side: .buy, quantity: Int.max))
    XCTAssertThrowsError(
      try TradingRules.placeOrder(ledger: .demo, asset: reliance, side: .buy, quantity: 0))
  }

  func testPreviewUsesPaiseAtAffordabilityBoundary() throws {
    let asset = try XCTUnwrap(MarketData.asset(for: "RELIANCE"))
    let preview = OrderPreview(asset: asset, side: .buy, quantity: 2, ledger: .init(cash: 2_569))
    XCTAssertTrue(preview.canSubmit)
    XCTAssertEqual(preview.estimatedValue, 2_569)
    XCTAssertEqual(preview.cashAfter, 0)
    XCTAssertEqual(preview.maxBuyQuantity, 2)
    XCTAssertFalse(
      OrderPreview(asset: asset, side: .buy, quantity: 2, ledger: .init(cash: 2_568.99)).canSubmit)
    XCTAssertFalse(
      OrderPreview(asset: asset, side: .buy, quantity: 1, ledger: .init(cash: .nan)).canSubmit)
  }

  func testDiscoveryCombinesQuerySectorAndStableSort() {
    XCTAssertEqual(
      Discovery.assets(MarketData.assets, query: " hDfC ", category: "Banking", sort: .gainers).map(
        \.symbol), ["HDFCBANK"])
    XCTAssertEqual(
      Discovery.assets(MarketData.assets, query: "hdfc", category: "Automotive", sort: .gainers)
        .count, 0)
    XCTAssertEqual(
      Discovery.assets(MarketData.assets, query: "", category: "", sort: .gainers).first?.symbol,
      "TATAMOTORS")
    XCTAssertEqual(
      Discovery.assets(MarketData.assets, query: "", category: "", sort: .losers).first?.symbol,
      "ITC")
    let alphabetical = Discovery.assets(
      MarketData.assets, query: "", category: "", sort: .alphabetical
    ).map(\.symbol)
    XCTAssertEqual(alphabetical, alphabetical.sorted())
  }

  func testOfflineLedgerAndWatchlistSurviveNewRepository() async throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let storage = FileAccountStorage(directory: directory)
    let first = DemoAccount(storage: storage)
    var ledger = try await first.load()
    ledger.watchlist = ["RELIANCE"]
    ledger = try TradingRules.placeOrder(
      ledger: ledger, asset: XCTUnwrap(MarketData.asset(for: "RELIANCE")), side: .buy, quantity: 1)
    try await first.save(ledger)
    let restored = try await DemoAccount(storage: storage).load()
    XCTAssertEqual(restored, ledger)
    let data = try await storage.read("offline-ledger-v1")
    XCTAssertNotNil(data)
  }

  func testCorruptOfflineDataIsPreservedAndNotReset() async throws {
    let storage = MemoryAccountStorage()
    let data = Data("broken ledger".utf8)
    await storage.write(data, key: "offline-ledger-v1")
    do {
      _ = try await DemoAccount(storage: storage).load()
      XCTFail("Expected decoding error")
    } catch {}
    let retained = await storage.read("offline-ledger-v1")
    XCTAssertEqual(retained, data)
  }

  func testOriginsAndCredentialsAreValidated() throws {
    for origin in [
      "http://example.com", "https://user:secret@example.com", "https://example.com/api",
      "https://example.com?q=x", "https://example.com#token", "file:///tmp/api",
    ] {
      XCTAssertThrowsError(try RemoteAccount(origin: origin, storage: MemoryAccountStorage()))
    }
    XCTAssertNoThrow(
      try RemoteAccount(origin: "https://example.com/", storage: MemoryAccountStorage()))
    XCTAssertNoThrow(
      try RemoteAccount(
        origin: "http://127.0.0.1:8000", storage: MemoryAccountStorage(), allowLocalHTTP: true))
    XCTAssertThrowsError(
      try RemoteAccount(
        origin: "http://192.168.1.2:8000", storage: MemoryAccountStorage(), allowLocalHTTP: true))
    XCTAssertThrowsError(try RemoteAccount.validateCredentials(username: "a", password: "short"))
    XCTAssertNoThrow(
      try RemoteAccount.validateCredentials(
        username: "learner.ios", password: "a-unique-test-password"))
  }
}

actor StubAPI: HTTPTransport {
  enum Failure {
    case none, lostResponse, snapshotUnavailable, conflict, unauthorized, expiredSession,
      slowCatalog
  }
  private let failure: Failure
  private var didFail = false
  private var submitted = false
  private var catalogWaiter: CheckedContinuation<Void, Never>?
  private var committedKeys: Set<String> = []
  private(set) var orderRequests: [URLRequest] = []
  private(set) var paths: [String] = []
  init(_ failure: Failure = .none) { self.failure = failure }

  func send(_ request: URLRequest) async throws -> HTTPResult {
    let path = request.url!.path
    paths.append(path)
    if path.hasSuffix("/register") || path.hasSuffix("/login") {
      let expiry = failure == .expiredSession ? 0 : 4_102_444_800
      return .init(
        data: Data("{\"token\":\"test-token\",\"expiresAt\":\(expiry)}".utf8), status: 200)
    }
    XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer test-token")
    if path.hasSuffix("/orders") {
      orderRequests.append(request)
      if failure == .conflict { return .init(status: 409) }
      if failure == .unauthorized { return .init(status: 401) }
      committedKeys.insert(request.value(forHTTPHeaderField: "Idempotency-Key")!)
      submitted = true
      if failure == .lostResponse && !didFail {
        didFail = true
        throw URLError(.timedOut)
      }
      return .init(data: Data("{}".utf8), status: 201)
    }
    if path.hasSuffix("/assets") {
      catalogWaiter?.resume()
      catalogWaiter = nil
      if failure == .slowCatalog { try await Task.sleep(for: .milliseconds(100)) }
      return .init(data: try JSONEncoder().encode(MarketData.assets), status: 200)
    }
    if path.hasSuffix("/indexes") {
      return .init(data: try JSONEncoder().encode(MarketData.indexes), status: 200)
    }
    if path.hasSuffix("/snapshot") {
      if failure == .snapshotUnavailable && submitted && !didFail {
        didFail = true
        return .init(status: 503)
      }
      return .init(
        data: Data(
          "{\"cash\":998715.5,\"positions\":[],\"orders\":[],\"watchlist\":[],\"currency\":\"INR\"}"
            .utf8), status: 200)
    }
    return .init(status: 204)
  }
  func waitForCatalog() async {
    if paths.contains("/api/v2/assets") { return }
    await withCheckedContinuation { catalogWaiter = $0 }
  }
  var committedCount: Int { committedKeys.count }
}

actor RejectingStorage: AccountStorage {
  func read(_ key: String) -> Data? { nil }
  func write(_ data: Data?, key: String) throws { throw CocoaError(.fileWriteNoPermission) }
}

final class TradingAPITests: XCTestCase, @unchecked Sendable {
  private let order = OrderRequest(symbol: "RELIANCE", side: .buy, quantity: 1)
  private func account(_ api: StubAPI, storage: any AccountStorage = MemoryAccountStorage()) throws
    -> RemoteAccount
  {
    try RemoteAccount(origin: "https://paper.example", transport: api, storage: storage)
  }
  private func signIn(_ account: RemoteAccount, name: String = "learner") async throws {
    try await account.authenticate(username: name, password: "test-password-12345", register: false)
  }
  func testLostOrderResponseRestoresOriginalUUIDAfterRestart() async throws {
    let api = StubAPI(.lostResponse)
    let storage = MemoryAccountStorage()
    let first = try account(api, storage: storage)
    try await signIn(first)
    do {
      _ = try await first.submit(order)
      XCTFail("Expected timeout")
    } catch {}
    let firstPending = await first.pending
    let original = try XCTUnwrap(firstPending)
    let restarted = try account(api, storage: storage)
    try await signIn(restarted)
    let restored = await restarted.pending
    XCTAssertEqual(restored, original)
    do {
      _ = try await restarted.submit(order)
      XCTFail("Must block new orders")
    } catch { XCTAssertEqual(error as? TradingFailure, .unresolvedOrder) }
    let ledger = try await restarted.retry()
    XCTAssertEqual(ledger.cash, 998_715.5)
    let requests = await api.orderRequests
    XCTAssertEqual(requests.count, 2)
    XCTAssertEqual(
      requests[0].value(forHTTPHeaderField: "Idempotency-Key"),
      requests[1].value(forHTTPHeaderField: "Idempotency-Key"))
    XCTAssertEqual(
      try JSONDecoder().decode(OrderRequest.self, from: XCTUnwrap(requests[0].httpBody)),
      try JSONDecoder().decode(OrderRequest.self, from: XCTUnwrap(requests[1].httpBody)))
    let count = await api.committedCount
    XCTAssertEqual(count, 1)
    let cleared = await restarted.pending
    XCTAssertNil(cleared)
  }
  func testRetrySurvivesSnapshotFailureAfterSuccessfulPOST() async throws {
    let api = StubAPI(.snapshotUnavailable)
    let account = try account(api)
    try await signIn(account)
    do {
      _ = try await account.submit(order)
      XCTFail("Expected snapshot failure")
    } catch { XCTAssertEqual(error as? TradingFailure, .http(503)) }
    let pending = await account.pending
    XCTAssertNotNil(pending)
    _ = try await account.retry()
    let count = await api.committedCount
    XCTAssertEqual(count, 1)
  }
  func testDefinitiveRejectionClearsPendingButUnauthorizedRetainsIt() async throws {
    for failure in [StubAPI.Failure.conflict, .unauthorized] {
      let account = try account(StubAPI(failure))
      try await signIn(account)
      do {
        _ = try await account.submit(order)
        XCTFail("Expected failure")
      } catch {}
      let pending = await account.pending
      XCTAssertEqual(pending == nil, failure == .conflict)
    }
  }
  func testFailedJournalWritePreventsSubmission() async throws {
    let api = StubAPI()
    let account = try account(api, storage: RejectingStorage())
    try await signIn(account)
    do {
      _ = try await account.submit(order)
      XCTFail("Expected storage failure")
    } catch {}
    let requests = await api.orderRequests
    XCTAssertTrue(requests.isEmpty)
  }
  func testPendingRecordsAreScopedByAccountAndOrigin() async throws {
    let api = StubAPI(.lostResponse)
    let storage = MemoryAccountStorage()
    let first = try account(api, storage: storage)
    try await signIn(first)
    do { _ = try await first.submit(order) } catch {}
    try await first.signOut()
    let other = try account(api, storage: storage)
    try await signIn(other, name: "someoneelse")
    let otherPending = await other.pending
    XCTAssertNil(otherPending)
    let differentServer = try RemoteAccount(
      origin: "https://another.example", transport: api, storage: storage)
    try await signIn(differentServer)
    let differentPending = await differentServer.pending
    XCTAssertNil(differentPending)
    try await signIn(first, name: "LEARNER")
    let originalPending = await first.pending
    XCTAssertNotNil(originalPending)
  }
  func testExpiredSessionNeverSendsAnOrder() async throws {
    let api = StubAPI(.expiredSession)
    let account = try account(api)
    try await signIn(account)
    do {
      _ = try await account.submit(order)
      XCTFail("Expected expired session")
    } catch { XCTAssertEqual(error as? TradingFailure, .missingSession) }
    let requests = await api.orderRequests
    XCTAssertTrue(requests.isEmpty)
  }
  func testConcurrentOperationsAreRejectedAcrossSuspension() async throws {
    let api = StubAPI(.slowCatalog)
    let account = try account(api)
    try await signIn(account)
    let loading = Task { try await account.load() }
    await api.waitForCatalog()
    do {
      _ = try await account.watch("RELIANCE", enabled: true)
      XCTFail("Expected busy guard")
    } catch { XCTAssertEqual(error as? TradingFailure, .busy) }
    _ = try await loading.value
  }
  func testLiveExecutionIsRejectedBeforeNetworking() async throws {
    XCTAssertThrowsError(try ExecutionPolicy.validate(.live))
    let api = StubAPI()
    let account = try account(api)
    try await signIn(account)
    do {
      _ = try await account.submit(order, execution: .live)
      XCTFail("Live must be rejected")
    } catch {}
    let requests = await api.orderRequests
    XCTAssertTrue(requests.isEmpty)
  }
  func testCatalogWatchlistAndDeletionUseV2Routes() async throws {
    let api = StubAPI()
    let account = try account(api)
    try await signIn(account)
    let data = try await account.load()
    XCTAssertEqual(data.assets.count, 7)
    XCTAssertEqual(data.indexes.count, 3)
    _ = try await account.watch("RELIANCE", enabled: true)
    _ = try await account.watch("RELIANCE", enabled: false)
    try await account.deleteAccount()
    let paths = await api.paths
    XCTAssertTrue(paths.contains("/api/v2/account"))
    do {
      _ = try await account.load()
      XCTFail("Deleted session must not authorize")
    } catch { XCTAssertEqual(error as? TradingFailure, .missingSession) }
  }
}
