/// TradingDomain.swift contains pure rules: filter stocks, preview paise amounts and update a local practice ledger. No screen or HTTP dependency is allowed here.
import Foundation

public struct TradingLedger: Codable, Equatable, Sendable {
  public var cash: Double
  public var positions: [Position]
  public var orders: [SimulatedOrder]
  public var watchlist: [String]

  public init(
    cash: Double, positions: [Position] = [], orders: [SimulatedOrder] = [],
    watchlist: [String] = []
  ) {
    self.cash = cash
    self.positions = positions
    self.orders = orders
    self.watchlist = watchlist
  }

  public static let demo = TradingLedger(
    cash: 1_000_000,
    positions: [
      Position(symbol: "RELIANCE", quantity: 8, averageCost: 1_210.25),
      Position(symbol: "TCS", quantity: 3, averageCost: 3_220),
      Position(symbol: "HDFCBANK", quantity: 12, averageCost: 1_690.75),
    ])
}

public enum AssetSort: String, CaseIterable, Sendable {
  case alphabetical = "A–Z"
  case gainers = "Gainers"
  case losers = "Losers"
}

public enum Discovery {
  public static func assets(
    _ assets: [MarketAsset], query: String, category: String, sort: AssetSort
  ) -> [MarketAsset] {
    let query = query.trimmingCharacters(in: .whitespacesAndNewlines)
    return assets.filter {
      (category.isEmpty || $0.category == category)
        && (query.isEmpty || $0.symbol.localizedCaseInsensitiveContains(query)
          || $0.companyName.localizedCaseInsensitiveContains(query))
    }.sorted {
      if sort != .alphabetical && $0.changePercent != $1.changePercent {
        return sort == .gainers
          ? $0.changePercent > $1.changePercent : $0.changePercent < $1.changePercent
      }
      return $0.symbol < $1.symbol
    }
  }
}

public struct OrderPreview: Sendable {
  public let estimatedValue: Double
  public let cashAfter: Double
  public let maxBuyQuantity: Int
  public let ownedQuantity: Int
  public let error: String?
  public var canSubmit: Bool { error == nil }

  /// Work in integer paise so preview and ledger agree at affordability boundaries.
  public init(asset: MarketAsset, side: OrderSide, quantity: Int, ledger: TradingLedger) {
    let owned = ledger.positions.first { $0.symbol == asset.symbol }?.quantity ?? 0
    ownedQuantity = owned
    guard asset.price.isFinite, asset.price > 0, asset.price <= 1_000_000_000,
      ledger.cash.isFinite, ledger.cash >= 0, ledger.cash <= 1_000_000_000_000
    else {
      estimatedValue = 0
      cashAfter = 0
      maxBuyQuantity = 0
      error = "Account or quote data is unavailable. Refresh before trading."
      return
    }
    let price = Int64((asset.price * 100).rounded())
    let balance = Int64((ledger.cash * 100).rounded())
    maxBuyQuantity = price > 0 ? Int(min(balance / price, 1_000_000)) : 0
    guard price > 0, (1...1_000_000).contains(quantity) else {
      estimatedValue = 0
      cashAfter = ledger.cash
      error = "Enter 1–1,000,000 whole shares at a quote of at least one paisa."
      return
    }
    let total = price * Int64(quantity)
    estimatedValue = Double(total) / 100
    cashAfter = Double(side == .buy ? balance - total : balance + total) / 100
    if side == .buy && total > balance {
      error = "Not enough practice cash. You can buy up to \(maxBuyQuantity) shares."
    } else if side == .sell && quantity > owned {
      error = "Not enough shares. You own \(owned) shares."
    } else {
      error = nil
    }
  }
}

public enum TradingRules {
  public static func placeOrder(
    ledger: TradingLedger, asset: MarketAsset, side: OrderSide, quantity: Int,
    execution: ExecutionMode = .paper
  ) throws -> TradingLedger {
    try ExecutionPolicy.validate(execution)
    let preview = OrderPreview(asset: asset, side: side, quantity: quantity, ledger: ledger)
    if let error = preview.error { throw TradingFailure.validation(error) }
    var result = ledger
    let index = result.positions.firstIndex { $0.symbol == asset.symbol }
    if side == .buy {
      if let index {
        let previous = result.positions[index]
        let (updated, overflow) = previous.quantity.addingReportingOverflow(quantity)
        guard !overflow else { throw TradingFailure.validation("The holding is too large.") }
        result.positions[index].quantity = updated
        result.positions[index].averageCost =
          (previous.averageCost * Double(previous.quantity) + preview.estimatedValue)
          / Double(updated)
      } else {
        result.positions.append(
          Position(symbol: asset.symbol, quantity: quantity, averageCost: asset.price))
      }
    } else if let index {
      result.positions[index].quantity -= quantity
      if result.positions[index].quantity == 0 { result.positions.remove(at: index) }
    }
    result.cash = preview.cashAfter
    result.orders.insert(
      SimulatedOrder(symbol: asset.symbol, side: side, quantity: quantity, price: asset.price),
      at: 0)
    return result
  }
}

public enum ExecutionMode: Sendable { case paper, live }

/// A future broker adapter must be a separate, reviewed integration. No live route exists.
public enum ExecutionPolicy {
  public static func validate(_ mode: ExecutionMode) throws {
    guard mode == .paper else {
      throw TradingFailure.validation("Live execution is not supported. Use paper trading only.")
    }
  }
}

public enum TradingFailure: Error, LocalizedError, Equatable, Sendable {
  case validation(String)
  case http(Int)
  case invalidResponse, busy, missingSession, unresolvedOrder

  public var errorDescription: String? {
    switch self {
    case .validation(let message): return message
    case .http(401), .missingSession:
      return "Your session expired or your credentials were not accepted. Sign in again."
    case .http(409):
      return "The request conflicts with your account. Check cash, holdings or username."
    case .http(429): return "Too many requests. Wait before trying again."
    case .http(let status) where (400..<500).contains(status):
      return "Check your input and try again."
    case .http:
      return "The service is unavailable. An order may have completed; retry the same order."
    case .invalidResponse:
      return "The service returned unexpected account data. Refresh before trading."
    case .busy: return "Wait for the current request to finish."
    case .unresolvedOrder: return "Resolve the unconfirmed order before placing another."
    }
  }
}

public struct LearningLesson: Identifiable, Sendable {
  public let id: String
  public let title: String
  public let explanation: String
  public static let all: [LearningLesson] = [
    .init(
      id: "orders", title: "What does a market order do?",
      explanation:
        "A market order asks to trade at the available price. In a real market, the execution price can change. This app fills paper market orders using synthetic prices. Limit and stop orders are not supported yet."
    ),
    .init(
      id: "risk", title: "Why does diversification matter?",
      explanation:
        "Holding several companies and sectors can reduce concentration in one business. It cannot remove market risk or guarantee a profit. Your paper portfolio is practice, not personalized investment advice."
    ),
    .init(
      id: "costs", title: "Why is the order value only an estimate?",
      explanation:
        "Real trades can include brokerage, taxes and exchange charges. These depend on the broker, instrument and date. Northstar does not deduct these charges or estimate a real broker’s fee. Check the provider’s official schedule before real trading."
    ),
  ]
}
