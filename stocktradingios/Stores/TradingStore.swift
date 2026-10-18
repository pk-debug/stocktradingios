import Combine
import Foundation

/// Owns the app-wide demo ledger and applies all accepted simulated orders.
///
/// This store is the single source of truth for cash, holdings, and order history.
/// Its state is intentionally in memory and resets when the app is restarted.
@MainActor
final class TradingStore: ObservableObject {
    @Published private(set) var cash: Double
    @Published private(set) var positions: [Position]
    @Published private(set) var orders: [SimulatedOrder] = []

    /// Creates the Indian-market demo account with its sample cash and holdings.
    init(
        cash: Double = 1_000_000,
        positions: [Position] = [
            Position(symbol: "RELIANCE", quantity: 8, averageCost: 1_210.25),
            Position(symbol: "TCS", quantity: 3, averageCost: 3_220.00),
            Position(symbol: "HDFCBANK", quantity: 12, averageCost: 1_690.75)
        ]
    ) {
        self.cash = cash
        self.positions = positions
    }

    /// Validates and applies a whole-share order to the local demo account.
    ///
    /// Rejected orders return a clear reason and never change the ledger.
    /// Accepted orders update cash, holdings, and newest-first order history.
    @discardableResult
    func placeOrder(symbol: String, side: OrderSide, quantity: Int) -> OrderResult {
        guard let asset = MarketData.asset(for: symbol) else {
            return .rejected("That asset is not available in the sample market.")
        }
        guard quantity >= 1 else {
            return .rejected("Enter a whole-share quantity of at least 1.")
        }

        let positionIndex = positions.firstIndex { $0.symbol == asset.symbol }
        let orderValue = Self.roundToCents(asset.price * Double(quantity))
        if side == .buy && orderValue > cash {
            return .rejected("There is not enough demo cash for this order.")
        }
        if side == .sell {
            guard let positionIndex, quantity <= positions[positionIndex].quantity else {
                return .rejected("You do not own enough shares for this demo sale.")
            }
        }

        let order = SimulatedOrder(
            id: UUID(),
            symbol: asset.symbol,
            side: side,
            quantity: quantity,
            price: asset.price,
            createdAt: Date()
        )

        if side == .buy {
            if let positionIndex {
                let previous = positions[positionIndex]
                let updatedQuantity = previous.quantity + quantity
                positions[positionIndex].quantity = updatedQuantity
                positions[positionIndex].averageCost =
                    (previous.averageCost * Double(previous.quantity) + orderValue) / Double(updatedQuantity)
            } else {
                positions.append(Position(symbol: asset.symbol, quantity: quantity, averageCost: asset.price))
            }
            cash = Self.roundToCents(cash - orderValue)
        } else if let positionIndex {
            let remainingQuantity = positions[positionIndex].quantity - quantity
            if remainingQuantity == 0 {
                positions.remove(at: positionIndex)
            } else {
                positions[positionIndex].quantity = remainingQuantity
            }
            cash = Self.roundToCents(cash + orderValue)
        }

        orders.insert(order, at: 0)
        return .accepted(order)
    }

    /// Rounds ledger values to the nearest cent after each accepted order.
    private static func roundToCents(_ amount: Double) -> Double {
        (amount * 100).rounded() / 100
    }
}
