import Foundation

/// A hard-coded sample quote shown in the learning app.
struct MarketAsset: Identifiable, Equatable {
    let symbol: String
    let companyName: String
    let exchange: String
    let price: Double
    let change: Double
    let changePercent: Double
    let history: [Double]
    let category: String

    var id: String { symbol }
    var isPositive: Bool { changePercent >= 0 }
}

/// One illustrative index entry displayed on the Discover screen.
struct MarketIndex: Identifiable {
    let name: String
    let value: String
    let change: String
    let isPositive: Bool

    var id: String { name }
}

/// The number of shares held and the average demo purchase price per share.
struct Position: Identifiable, Equatable {
    let symbol: String
    var quantity: Int
    var averageCost: Double

    var id: String { symbol }
}

/// The direction of a local, simulated order.
enum OrderSide: String, Identifiable {
    case buy = "BUY"
    case sell = "SELL"

    var id: String { rawValue }
}

/// A completed simulated order kept only in the app's current memory.
struct SimulatedOrder: Identifiable {
    let id: UUID
    let symbol: String
    let side: OrderSide
    let quantity: Int
    let price: Double
    let createdAt: Date

    var total: Double { price * Double(quantity) }
}

/// The accepted order or user-readable reason an order was rejected.
enum OrderResult {
    case accepted(SimulatedOrder)
    case rejected(String)
}

/// Deterministic sample market data; these are not live financial quotes.
enum MarketData {
    static let assets = [
        MarketAsset(
            symbol: "RELIANCE", companyName: "Reliance Industries", exchange: "NSE",
            price: 1_284.50, change: 12.35, changePercent: 0.97,
            history: [34, 41, 38, 52, 47, 63, 58, 69, 64, 82, 77, 94],
            category: "Energy & Retail"
        ),
        MarketAsset(
            symbol: "TCS", companyName: "Tata Consultancy Services", exchange: "NSE",
            price: 3_482.75, change: 24.50, changePercent: 0.71,
            history: [30, 36, 34, 48, 45, 61, 55, 68, 64, 78, 74, 92],
            category: "Information Technology"
        ),
        MarketAsset(
            symbol: "HDFCBANK", companyName: "HDFC Bank", exchange: "NSE",
            price: 1_768.40, change: -8.20, changePercent: -0.46,
            history: [88, 80, 84, 70, 75, 61, 66, 51, 57, 43, 48, 35],
            category: "Banking"
        ),
        MarketAsset(
            symbol: "INFY", companyName: "Infosys", exchange: "NSE",
            price: 1_482.60, change: 5.35, changePercent: 0.36,
            history: [31, 39, 35, 49, 46, 58, 55, 67, 63, 76, 73, 90],
            category: "Information Technology"
        ),
        MarketAsset(
            symbol: "ICICIBANK", companyName: "ICICI Bank", exchange: "NSE",
            price: 1_298.25, change: 7.25, changePercent: 0.56,
            history: [27, 33, 30, 45, 41, 54, 51, 66, 60, 75, 72, 89],
            category: "Banking"
        ),
        MarketAsset(
            symbol: "ITC", companyName: "ITC Limited", exchange: "NSE",
            price: 438.90, change: -2.10, changePercent: -0.48,
            history: [82, 77, 80, 68, 71, 61, 65, 53, 58, 47, 50, 39],
            category: "Consumer Goods"
        ),
        MarketAsset(
            symbol: "TATAMOTORS", companyName: "Tata Motors", exchange: "NSE",
            price: 728.15, change: 10.80, changePercent: 1.51,
            history: [24, 31, 29, 44, 41, 57, 53, 66, 62, 78, 73, 93],
            category: "Automotive"
        )
    ]

    static let indexes = [
        MarketIndex(name: "NIFTY 50", value: "24,854.05", change: "+0.62%", isPositive: true),
        MarketIndex(name: "SENSEX", value: "81,330.56", change: "+0.48%", isPositive: true),
        MarketIndex(name: "BANK NIFTY", value: "56,214.30", change: "-0.21%", isPositive: false)
    ]

    /// Finds an asset without requiring callers to normalize ticker case.
    static func asset(for symbol: String) -> MarketAsset? {
        assets.first { $0.symbol == symbol.uppercased() }
    }
}
