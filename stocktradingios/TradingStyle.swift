/// TradingStyle.swift uses system-aware colors so the same screens work in light and dark appearance without fixed white backgrounds.

import NorthstarCore
import SwiftUI

enum TradingStyle {
  static let green = Color.accentColor
}

extension MarketAsset {
  var trendColor: Color { isPositive ? .primary : .red }
}
