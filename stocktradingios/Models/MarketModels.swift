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
            symbol: "AAPL", companyName: "Apple Inc.", exchange: "NASDAQ",
            price: 228.87, change: 2.41, changePercent: 1.06,
            history: [24, 36, 29, 48, 42, 60, 54, 71, 64, 84, 76, 96],
            category: "Technology"
        ),
        MarketAsset(
            symbol: "MSFT", companyName: "Microsoft Corporation", exchange: "NASDAQ",
            price: 429.17, change: 3.28, changePercent: 0.77,
            history: [32, 27, 39, 35, 55, 49, 63, 58, 70, 66, 83, 91],
            category: "Technology"
        ),
        MarketAsset(
            symbol: "NVDA", companyName: "NVIDIA Corporation", exchange: "NASDAQ",
            price: 138.85, change: -1.22, changePercent: -0.87,
            history: [89, 78, 86, 68, 73, 58, 66, 49, 55, 38, 44, 28],
            category: "Semiconductors"
        ),
        MarketAsset(
            symbol: "AMZN", companyName: "Amazon.com, Inc.", exchange: "NASDAQ",
            price: 187.83, change: 0.96, changePercent: 0.51,
            history: [25, 32, 28, 44, 39, 52, 48, 63, 61, 75, 69, 88],
            category: "Consumer"
        ),
        MarketAsset(
            symbol: "GOOGL", companyName: "Alphabet Inc.", exchange: "NASDAQ",
            price: 165.27, change: -0.54, changePercent: -0.33,
            history: [85, 75, 80, 62, 69, 58, 64, 48, 56, 43, 49, 37],
            category: "Communication"
        ),
        MarketAsset(
            symbol: "VOO", companyName: "Vanguard S&P 500 ETF", exchange: "NYSE ARCA",
            price: 526.42, change: 1.87, changePercent: 0.36,
            history: [27, 36, 34, 44, 48, 45, 57, 62, 59, 76, 81, 93],
            category: "ETF"
        ),
        MarketAsset(
            symbol: "TSLA", companyName: "Tesla, Inc.", exchange: "NASDAQ",
            price: 249.98, change: -4.76, changePercent: -1.87,
            history: [91, 78, 85, 64, 72, 51, 63, 40, 48, 32, 38, 20],
            category: "Automotive"
        )
    ]

    static let indexes = [
        MarketIndex(name: "S&P 500", value: "5,842.47", change: "+0.42%", isPositive: true),
        MarketIndex(name: "NASDAQ", value: "18,421.36", change: "+0.68%", isPositive: true),
        MarketIndex(name: "DOW", value: "43,275.91", change: "-0.13%", isPositive: false)
    ]

    /// Finds an asset without requiring callers to normalize ticker case.
    static func asset(for symbol: String) -> MarketAsset? {
        assets.first { $0.symbol == symbol.uppercased() }
    }
}
