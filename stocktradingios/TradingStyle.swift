import SwiftUI

/// Shared colors used by the SwiftUI screens to keep the demo visually consistent.
enum TradingStyle {
    static let green = Color(red: 20 / 255, green: 107 / 255, blue: 80 / 255)
    static let darkGreen = Color(red: 23 / 255, green: 60 / 255, blue: 46 / 255)
    static let ink = Color(red: 23 / 255, green: 34 / 255, blue: 29 / 255)
    static let secondary = Color(red: 121 / 255, green: 130 / 255, blue: 125 / 255)
    static let muted = Color(red: 146 / 255, green: 154 / 255, blue: 149 / 255)
    static let red = Color(red: 211 / 255, green: 86 / 255, blue: 82 / 255)
    static let background = Color(red: 246 / 255, green: 247 / 255, blue: 244 / 255)
}

extension MarketAsset {
    /// Returns the visual trend color used by charts and quote labels.
    var trendColor: Color {
        isPositive ? TradingStyle.green : TradingStyle.red
    }
}
