import SwiftUI
import NorthstarCore

enum TradingStyle {
    static let green = Color.accentColor
}

extension MarketAsset {
    var trendColor: Color { isPositive ? .primary : .red }
}
