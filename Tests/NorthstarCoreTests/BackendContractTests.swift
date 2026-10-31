import XCTest
import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
@testable import NorthstarCore

final class BackendContractTests: XCTestCase, @unchecked Sendable {
    /// Uses a disposable real backend, never a developer's existing account.
    func testRealHTTPAccountJourney() async throws {
        guard let origin = ProcessInfo.processInfo.environment["NORTHSTAR_TEST_API"] else {
            throw XCTSkip("Set NORTHSTAR_TEST_API to a disposable v2 backend to run the real HTTP contract.")
        }
        let redirect = try await URLSessionTransport().send(URLRequest(url: URL(string: origin + "/api/v2/assets/")!))
        XCTAssertEqual(redirect.status, 307, "Transport must refuse redirects")
        let storage = MemoryAccountStorage()
        let account = try RemoteAccount(origin: origin, storage: storage, allowLocalHTTP: true)
        let name = "ios_" + UUID().uuidString.replacingOccurrences(of: "-", with: "").prefix(24)
        let password = UUID().uuidString
        try await account.authenticate(username: name, password: password, register: true)
        let initial = try await account.load()
        XCTAssertEqual(initial.ledger.cash, 1_000_000)
        XCTAssertTrue(initial.ledger.positions.isEmpty)
        XCTAssertEqual(initial.assets.count, 7)
        XCTAssertEqual(initial.indexes.count, 3)
        let watched = try await account.watch("RELIANCE", enabled: true)
        XCTAssertEqual(watched.watchlist, ["RELIANCE"])
        let bought = try await account.submit(.init(symbol: "RELIANCE", side: .buy, quantity: 2))
        XCTAssertEqual(bought.cash, 997_431)
        XCTAssertEqual(bought.positions.first?.quantity, 2)
        XCTAssertEqual(bought.orders.count, 1)
        let sold = try await account.submit(.init(symbol: "RELIANCE", side: .sell, quantity: 2))
        XCTAssertTrue(sold.positions.isEmpty)
        XCTAssertEqual(sold.cash, 1_000_000)
        XCTAssertEqual(sold.orders.count, 2)
        do {
            _ = try await account.submit(.init(symbol: "RELIANCE", side: .sell, quantity: 1))
            XCTFail("Server must reject selling unowned shares")
        } catch { XCTAssertEqual(error as? TradingFailure, .http(409)) }
        let pending = await account.pending
        XCTAssertNil(pending)
        try await account.signOut()
        try await account.authenticate(username: name, password: password, register: false)
        let restored = try await account.load()
        XCTAssertEqual(restored.ledger.orders.count, 2)
        XCTAssertEqual(restored.ledger.watchlist, ["RELIANCE"])

        let other = try RemoteAccount(origin: origin, storage: MemoryAccountStorage(), allowLocalHTTP: true)
        let otherName = "ios_" + UUID().uuidString.replacingOccurrences(of: "-", with: "").prefix(24)
        try await other.authenticate(username: otherName, password: password, register: true)
        let isolated = try await other.load()
        XCTAssertEqual(isolated.ledger.cash, 1_000_000)
        XCTAssertTrue(isolated.ledger.orders.isEmpty)
        XCTAssertTrue(isolated.ledger.watchlist.isEmpty)
        try await other.deleteAccount()
        try await account.deleteAccount()
        do {
            try await account.authenticate(username: name, password: password, register: false)
            XCTFail("Deleted account must not authenticate")
        } catch { XCTAssertEqual(error as? TradingFailure, .http(401)) }
    }
}
