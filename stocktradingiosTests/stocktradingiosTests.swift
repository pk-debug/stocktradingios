//
//  stocktradingiosTests.swift
//  stocktradingiosTests
//
//  Created by Pawan Kumar on 16/10/26.
//

import Testing
@testable import stocktradingios

struct stocktradingiosTests {

    @Test @MainActor
    func buyingSharesUpdatesCashPositionAverageCostAndActivity() {
        let store = TradingStore()

        let result = store.placeOrder(symbol: "AAPL", side: .buy, quantity: 1)

        #expect(store.cash == 12_221.13)
        #expect(store.positions.first(where: { $0.symbol == "AAPL" })?.quantity == 5)
        #expect(abs((store.positions.first(where: { $0.symbol == "AAPL" })?.averageCost ?? 0) - 191.734) < 0.001)
        #expect(store.orders.count == 1)
        if case .accepted(let order) = result {
            #expect(order.symbol == "AAPL")
            #expect(order.quantity == 1)
            #expect(order.side == .buy)
            #expect(order.total == 228.87)
        } else {
            Issue.record("A valid buy order should be accepted.")
        }
    }

    @Test @MainActor
    func sellingSharesCreditsCashAndRemovesEmptyPosition() {
        let store = TradingStore()

        let result = store.placeOrder(symbol: "VOO", side: .sell, quantity: 3)

        #expect(store.cash == 14_029.26)
        #expect(store.positions.first(where: { $0.symbol == "VOO" }) == nil)
        #expect(store.orders.count == 1)
        if case .accepted = result {
        } else {
            Issue.record("A valid sale should be accepted.")
        }
    }

    @Test @MainActor
    func rejectedOrdersLeaveTheLedgerUnchanged() {
        let store = TradingStore()
        let originalCash = store.cash
        let originalPositions = store.positions

        let insufficientCash = store.placeOrder(symbol: "VOO", side: .buy, quantity: 100)
        let insufficientShares = store.placeOrder(symbol: "TSLA", side: .sell, quantity: 1)
        let zeroQuantity = store.placeOrder(symbol: "AAPL", side: .buy, quantity: 0)
        let unavailableAsset = store.placeOrder(symbol: "UNKNOWN", side: .buy, quantity: 1)

        #expect(store.cash == originalCash)
        #expect(store.positions == originalPositions)
        #expect(store.orders.isEmpty)
        if case .rejected(let message) = insufficientCash {
            #expect(message == "There is not enough demo cash for this order.")
        } else {
            Issue.record("An order over the available demo cash should be rejected.")
        }
        if case .rejected(let message) = insufficientShares {
            #expect(message == "You do not own enough shares for this demo sale.")
        } else {
            Issue.record("A sale without owned shares should be rejected.")
        }
        if case .rejected(let message) = zeroQuantity {
            #expect(message == "Enter a whole-share quantity of at least 1.")
        } else {
            Issue.record("A zero-share order should be rejected.")
        }
        if case .rejected(let message) = unavailableAsset {
            #expect(message == "That asset is not available in the sample market.")
        } else {
            Issue.record("An unavailable asset should be rejected.")
        }
    }

    @Test @MainActor
    func discoverSearchMatchesTickerAndCompanyName() {
        let viewModel = DiscoverViewModel()

        #expect(viewModel.filteredAssets.count == 7)

        viewModel.searchText = "apple"
        #expect(viewModel.filteredAssets.map(\.symbol) == ["AAPL"])

        viewModel.searchText = "nv"
        #expect(viewModel.filteredAssets.map(\.symbol) == ["NVDA"])

        viewModel.searchText = "no matching asset"
        #expect(viewModel.filteredAssets.isEmpty)
    }

    @Test @MainActor
    func portfolioViewModelCalculatesDemoValues() {
        let store = TradingStore()
        let viewModel = PortfolioViewModel()
        let marketValue = viewModel.marketValue(for: store.positions)
        let investedValue = viewModel.investedValue(for: store.positions)

        #expect(abs(marketValue - 3_353.08) < 0.001)
        #expect(abs(investedValue - 3_016.5) < 0.001)
        #expect(abs(marketValue - investedValue - 336.58) < 0.001)
    }
}
