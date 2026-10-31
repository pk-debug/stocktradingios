import Testing
import NorthstarCore
@testable import stocktradingios

struct stocktradingiosTests {
    @Test @MainActor
    func offlineEntryPersistsOrdersAndWatchlistAcrossStoreInstances() async throws {
        let storage = MemoryAccountStorage()
        let store = TradingStore(storage: storage)
        await store.enterOffline()
        let asset = try #require(store.asset("RELIANCE"))
        await store.toggleWatch(asset)
        #expect(await store.placeOrder(asset: asset, side: .buy, quantity: 1))
        #expect(store.cash == 998_715.50)
        let second = TradingStore(storage: storage)
        await second.enterOffline()
        #expect(second.ledger == store.ledger)
        #expect(second.ledger.watchlist == ["RELIANCE"])
        await second.signOut()
        #expect(second.mode == .signedOut)
        #expect(second.cash == 0)
        #expect(second.assets.isEmpty)
    }

    @Test @MainActor
    func rejectedOrderDoesNotPublishLedgerChanges() async throws {
        let store = TradingStore(storage: MemoryAccountStorage())
        await store.enterOffline()
        let original = store.ledger
        let asset = try #require(store.asset("TCS"))
        #expect(!(await store.placeOrder(asset: asset, side: .buy, quantity: 300)))
        #expect(store.ledger == original)
        #expect(store.message != nil)
    }

    @Test @MainActor
    func portfolioAndMoneyPresentation() async {
        let store = TradingStore(storage: MemoryAccountStorage())
        await store.enterOffline()
        #expect(abs(store.marketValue - 41_945.05) < 0.001)
        #expect(abs(store.investedValue - 39_631) < 0.001)
        #expect(DemoMoney.format(1_000_000).contains("₹"))
    }

    @Test @MainActor
    func insecureAPIConfigurationShowsError() {
        let store = TradingStore(storage: MemoryAccountStorage(), origin: "http://example.com")
        #expect(store.configurationError != nil)
        #expect(store.mode == .signedOut)
    }
}
