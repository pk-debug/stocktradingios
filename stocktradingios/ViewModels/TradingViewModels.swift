import Combine
import Foundation

/// Holds Discover screen input and performs ticker/company-name filtering.
@MainActor
final class DiscoverViewModel: ObservableObject {
    @Published var searchText = ""

    /// Returns sample assets whose ticker or company name matches the search.
    var filteredAssets: [MarketAsset] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return MarketData.assets }
        return MarketData.assets.filter {
            $0.symbol.localizedCaseInsensitiveContains(query)
                || $0.companyName.localizedCaseInsensitiveContains(query)
        }
    }

    /// Calculates the current value of the positions in the supplied ledger.
    func positionsValue(for positions: [Position]) -> Double {
        positions.reduce(0) { total, position in
            total + (MarketData.asset(for: position.symbol)?.price ?? 0) * Double(position.quantity)
        }
    }
}

/// Performs portfolio display calculations without changing the trading ledger.
struct PortfolioViewModel {
    /// Calculates the current sample-quote value of all positions.
    func marketValue(for positions: [Position]) -> Double {
        positions.reduce(0) { total, position in
            total + (MarketData.asset(for: position.symbol)?.price ?? 0) * Double(position.quantity)
        }
    }

    /// Calculates the total original cost basis of all remaining positions.
    func investedValue(for positions: [Position]) -> Double {
        positions.reduce(0) { $0 + $1.averageCost * Double($1.quantity) }
    }

    /// Calculates one holding's current sample-quote value.
    func marketValue(for position: Position, asset: MarketAsset) -> Double {
        asset.price * Double(position.quantity)
    }

    /// Calculates one holding's unrealized gain or loss.
    func gainLoss(for position: Position, asset: MarketAsset) -> Double {
        (asset.price - position.averageCost) * Double(position.quantity)
    }
}
