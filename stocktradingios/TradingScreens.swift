//
//  TradingScreens.swift
//  stocktradingios
//
//  Created by Pawan Kumar on 16/10/26.
//

import SwiftUI

// Screen-level views and reusable screen components.

/// Shows the account summary, sample indexes, and searchable sample assets.
struct DiscoverView: View {
    @EnvironmentObject private var trading: TradingStore
    @StateObject private var viewModel = DiscoverViewModel()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("NORTHSTAR")
                            .font(.system(size: 17, weight: .heavy, design: .rounded))
                            .tracking(2.2)
                            .foregroundStyle(TradingStyle.ink)
                        Text("INDIA, IN FOCUS")
                            .font(.system(size: 9, weight: .medium))
                            .tracking(1.8)
                            .foregroundStyle(TradingStyle.muted)
                    }
                    Spacer()
                    Text("DEMO")
                        .font(.system(size: 10, weight: .heavy))
                        .tracking(1)
                        .foregroundStyle(TradingStyle.green)
                        .padding(.horizontal, 11)
                        .padding(.vertical, 7)
                        .background(Color(red: 227 / 255, green: 238 / 255, blue: 232 / 255), in: Capsule())
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("INDIAN MARKETS, IN FOCUS")
                        .font(.system(size: 10, weight: .heavy))
                        .tracking(1.5)
                        .foregroundStyle(TradingStyle.green)
                    Text("Good evening.")
                        .font(.system(size: 30, weight: .bold))
                        .tracking(-0.8)
                        .foregroundStyle(TradingStyle.ink)
                    Text("Explore Indian stocks at your own pace.")
                        .font(.system(size: 14))
                        .foregroundStyle(Color(red: 114 / 255, green: 123 / 255, blue: 117 / 255))
                }
                .padding(.top, 34)
                .padding(.bottom, 21)

                accountCard
                sectionHeading("Market snapshot", subtitle: "Illustrative Indian index values", trailing: "DEMO")
                    .padding(.top, 29)
                    .padding(.bottom, 12)
                indexCard

                sectionHeading("Popular stocks", subtitle: "NSE sample companies · tap to explore", trailing: "\(viewModel.filteredAssets.count) STOCKS")
                    .padding(.top, 29)
                    .padding(.bottom, 12)

                HStack(spacing: 11) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(TradingStyle.secondary)
                    TextField("Search name or ticker", text: $viewModel.searchText)
                        .font(.system(size: 13))
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                        .accessibilityLabel("Search Indian stocks")
                }
                .padding(.horizontal, 13)
                .frame(height: 46)
                .background(.white, in: RoundedRectangle(cornerRadius: 12))
                .padding(.bottom, 9)

                VStack(spacing: 0) {
                    if viewModel.filteredAssets.isEmpty {
                        Text("No sample assets match that search.")
                            .font(.system(size: 13))
                            .foregroundStyle(TradingStyle.secondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 24)
                    } else {
                        ForEach(viewModel.filteredAssets) { asset in
                            NavigationLink {
                                AssetDetailView(asset: asset)
                            } label: {
                                AssetRow(asset: asset)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(.horizontal, 14)
                .background(.white, in: RoundedRectangle(cornerRadius: 15))

                Text("Learning demo only. These India-market examples are not live prices, investment advice, or real orders.")
                    .font(.system(size: 10))
                    .foregroundStyle(TradingStyle.muted)
                    .lineSpacing(3)
                    .padding(.top, 18)
                    .padding(.bottom, 12)
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
        }
        .background(TradingStyle.background.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
    }

    private var accountCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("DEMO ACCOUNT VALUE")
                    .font(.system(size: 10, weight: .bold))
                    .tracking(1.1)
                    .foregroundStyle(Color(red: 184 / 255, green: 208 / 255, blue: 195 / 255))
                Spacer()
                Text("INDIA SAMPLE PORTFOLIO")
                    .font(.system(size: 9))
                    .tracking(0.8)
                    .foregroundStyle(Color(red: 184 / 255, green: 208 / 255, blue: 195 / 255))
            }
            Text(DemoMoney.format(trading.cash + viewModel.positionsValue(for: trading.positions)))
                .font(.system(size: 30, weight: .bold))
                .tracking(-0.6)
                .foregroundStyle(.white)
                .padding(.top, 12)
            HStack {
                Text("\(DemoMoney.format(trading.cash)) available to simulate")
                    .font(.system(size: 11))
                    .foregroundStyle(Color(red: 208 / 255, green: 224 / 255, blue: 215 / 255))
                Spacer()
                NavigationLink {
                    PortfolioView()
                } label: {
                    Text("Portfolio  >")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.white)
                }
            }
            .padding(.top, 14)
        }
        .padding(20)
        .background(TradingStyle.darkGreen, in: RoundedRectangle(cornerRadius: 18))
    }

    private var indexCard: some View {
        HStack(spacing: 0) {
            ForEach(Array(MarketData.indexes.enumerated()), id: \.element.id) { index, marketIndex in
                VStack(alignment: .leading, spacing: 5) {
                    Text(marketIndex.name)
                        .font(.system(size: 10))
                        .foregroundStyle(TradingStyle.secondary)
                    Text(marketIndex.value)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Color(red: 29 / 255, green: 41 / 255, blue: 35 / 255))
                    Text(marketIndex.change)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(marketIndex.isPositive ? TradingStyle.green : TradingStyle.red)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, index == 0 ? 0 : 12)
                .padding(.trailing, 6)
                .overlay(alignment: .leading) {
                    if index > 0 {
                        Rectangle()
                            .fill(Color(red: 227 / 255, green: 231 / 255, blue: 225 / 255))
                            .frame(width: 1)
                            .padding(.vertical, 1)
                            .offset(x: -1)
                    }
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 15)
        .background(.white, in: RoundedRectangle(cornerRadius: 15))
    }

    private func sectionHeading(_ title: String, subtitle: String, trailing: String) -> some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(Color(red: 29 / 255, green: 41 / 255, blue: 35 / 255))
                Text(subtitle)
                    .font(.system(size: 11))
                    .foregroundStyle(TradingStyle.muted)
            }
            Spacer()
            Text(trailing)
                .font(.system(size: 9, weight: .bold))
                .tracking(0.8)
                .foregroundStyle(title == "Market snapshot" ? Color(red: 139 / 255, green: 113 / 255, blue: 69 / 255) : TradingStyle.muted)
                .padding(.bottom, 3)
        }
    }
}

/// Presents one asset's identity, sample chart, and latest example quote.
private struct AssetRow: View {
    let asset: MarketAsset

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(asset.symbol)
                    .font(.system(size: 15, weight: .bold))
                    .tracking(0.3)
                    .foregroundStyle(TradingStyle.ink)
                Text(asset.companyName)
                    .font(.system(size: 12))
                    .foregroundStyle(TradingStyle.secondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            SparklineView(values: asset.history, color: asset.trendColor, height: 36)
                .frame(width: 70)
                .accessibilityLabel("Sample price trend chart")

            VStack(alignment: .trailing, spacing: 4) {
                Text(DemoMoney.format(asset.price))
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(TradingStyle.ink)
                Text("\(asset.isPositive ? "+" : "")\(asset.changePercent, specifier: "%.2f")%")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(asset.trendColor)
            }
            .frame(minWidth: 86, alignment: .trailing)
        }
        .padding(.vertical, 12)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color(red: 229 / 255, green: 232 / 255, blue: 226 / 255))
                .frame(height: 0.5)
        }
        .accessibilityElement(children: .combine)
        .accessibilityHint("Open asset details")
    }
}

/// Draws a small bar chart from the sample history values.
private struct SparklineView: View {
    let values: [Double]
    let color: Color
    let height: CGFloat

    private var maximum: Double { max(values.max() ?? 1, 1) }

    var body: some View {
        HStack(alignment: .bottom, spacing: 3) {
            ForEach(Array(values.enumerated()), id: \.offset) { index, value in
                RoundedRectangle(cornerRadius: 3)
                    .fill(color.opacity(0.38 + (Double(index) / Double(max(values.count - 1, 1))) * 0.62))
                    .frame(maxWidth: .infinity)
                    .frame(height: max(3, height * max(0.12, value / maximum)))
            }
        }
        .frame(height: height, alignment: .bottom)
    }
}

/// Shows one asset's sample quote, descriptive information, and order actions.
private struct AssetDetailView: View {
    @EnvironmentObject private var trading: TradingStore
    let asset: MarketAsset
    @State private var orderSide: OrderSide?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(asset.symbol)
                            .font(.system(size: 26, weight: .heavy))
                            .tracking(0.4)
                            .foregroundStyle(TradingStyle.ink)
                        Text(asset.companyName)
                            .font(.system(size: 13))
                            .foregroundStyle(TradingStyle.secondary)
                    }
                    Spacer()
                    Text(asset.exchange)
                        .font(.system(size: 9, weight: .bold))
                        .tracking(0.4)
                        .foregroundStyle(TradingStyle.secondary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(.white, in: Capsule())
                }
                .padding(.top, 18)

                Text(DemoMoney.format(asset.price))
                    .font(.system(size: 34, weight: .bold))
                    .tracking(-0.7)
                    .foregroundStyle(TradingStyle.ink)
                    .padding(.top, 22)
                Text("\(asset.change >= 0 ? "+" : "-")\(DemoMoney.format(abs(asset.change))) (\(asset.changePercent >= 0 ? "+" : "")\(asset.changePercent, specifier: "%.2f")%) today")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(asset.trendColor)
                    .padding(.top, 4)

                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Text("SAMPLE PRICE MOVEMENT")
                            .font(.system(size: 10, weight: .bold))
                            .tracking(1)
                            .foregroundStyle(TradingStyle.secondary)
                        Spacer()
                        Text("Illustrative only")
                            .font(.system(size: 9))
                            .foregroundStyle(TradingStyle.muted)
                    }
                    SparklineView(values: asset.history, color: asset.trendColor, height: 160)
                        .accessibilityLabel("Sample price movement chart")
                    HStack {
                        Text("9:30 AM")
                        Spacer()
                        Text("12:00 PM")
                        Spacer()
                        Text("4:00 PM")
                    }
                    .font(.system(size: 9))
                    .foregroundStyle(TradingStyle.muted)
                }
                .padding(16)
                .background(.white, in: RoundedRectangle(cornerRadius: 15))
                .padding(.top, 22)

                VStack(alignment: .leading, spacing: 0) {
                    Text("About this sample")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Color(red: 29 / 255, green: 41 / 255, blue: 35 / 255))
                        .padding(.bottom, 10)
                    infoRow("Category", value: asset.category)
                    infoRow("Exchange", value: asset.exchange)
                    infoRow("Quote source", value: "Built-in demo data", isLast: true)
                }
                .padding(16)
                .background(.white, in: RoundedRectangle(cornerRadius: 15))
                .padding(.top, 12)

                Text("Educational demo, not investment advice. Orders are simulated locally and never reach a broker.")
                    .font(.system(size: 10))
                    .foregroundStyle(TradingStyle.muted)
                    .lineSpacing(3)
                    .padding(.top, 16)

                HStack(spacing: 10) {
                    Button {
                        orderSide = .buy
                    } label: {
                        Text("Simulate buy")
                            .font(.system(size: 13, weight: .bold))
                            .frame(maxWidth: .infinity)
                            .frame(height: 48)
                            .foregroundStyle(.white)
                            .background(TradingStyle.green, in: RoundedRectangle(cornerRadius: 11))
                    }
                    Button {
                        orderSide = .sell
                    } label: {
                        Text("Simulate sell")
                            .font(.system(size: 13, weight: .bold))
                            .frame(maxWidth: .infinity)
                            .frame(height: 48)
                            .foregroundStyle(TradingStyle.red)
                            .background(Color(red: 249 / 255, green: 233 / 255, blue: 232 / 255), in: RoundedRectangle(cornerRadius: 11))
                    }
                }
                .padding(.top, 18)
                .padding(.bottom, 24)
            }
            .padding(.horizontal, 20)
        }
        .background(TradingStyle.background.ignoresSafeArea())
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $orderSide) { side in
            OrderTicketView(asset: asset, side: side)
                .environmentObject(trading)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
    }

    private func infoRow(_ label: String, value: String, isLast: Bool = false) -> some View {
        HStack {
            Text(label)
                .foregroundStyle(TradingStyle.secondary)
            Spacer()
            Text(value)
                .fontWeight(.medium)
                .foregroundStyle(TradingStyle.ink)
        }
        .font(.system(size: 11))
        .padding(.vertical, 10)
        .overlay(alignment: .bottom) {
            if !isLast {
                Rectangle()
                    .fill(TradingStyle.background)
                    .frame(height: 1)
            }
        }
    }
}

/// Collects a whole-share quantity and asks the store to simulate that order.
private struct OrderTicketView: View {
    @EnvironmentObject private var trading: TradingStore
    @Environment(\.dismiss) private var dismiss
    let asset: MarketAsset
    let side: OrderSide
    @State private var quantityText = "1"
    @State private var message: String?
    @State private var succeeded = false
    @FocusState private var quantityFocused: Bool

    private var quantity: Int { Int(quantityText) ?? 0 }
    private var estimatedTotal: Double { Double(quantity) * asset.price }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Capsule()
                .fill(Color.gray.opacity(0.25))
                .frame(width: 38, height: 5)
                .frame(maxWidth: .infinity)
                .padding(.top, 10)
                .padding(.bottom, 19)

            HStack {
                VStack(alignment: .leading, spacing: 5) {
                    Text("SIMULATED ORDER")
                        .font(.system(size: 10, weight: .bold))
                        .tracking(1.2)
                        .foregroundStyle(TradingStyle.green)
                    Text("\(side.rawValue) \(asset.symbol)")
                        .font(.system(size: 21, weight: .bold))
                        .foregroundStyle(TradingStyle.ink)
                }
                Spacer()
                Button("CLOSE") { dismiss() }
                    .font(.system(size: 10, weight: .bold))
                    .tracking(0.6)
                    .foregroundStyle(TradingStyle.green)
            }

            Text("Whole shares")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(TradingStyle.secondary)
                .padding(.top, 20)
            TextField("Number of whole shares", text: $quantityText)
                .keyboardType(.numberPad)
                .focused($quantityFocused)
                .font(.system(size: 18, weight: .semibold))
                .padding(12)
                .background(TradingStyle.background, in: RoundedRectangle(cornerRadius: 10))
                .accessibilityLabel("Number of whole shares")
                .onChange(of: quantityText) { _, newValue in
                    quantityText = String(newValue.filter(\.isNumber))
                    message = nil
                }
                .padding(.top, 7)

            HStack {
                Text("Estimated total")
                    .font(.system(size: 12))
                    .foregroundStyle(TradingStyle.secondary)
                Spacer()
                Text(DemoMoney.format(estimatedTotal))
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(TradingStyle.ink)
            }
            .padding(.top, 14)
            Text("\(quantity) share(s) x sample quote \(DemoMoney.format(asset.price)). No fees in this demo.")
                .font(.system(size: 10))
                .foregroundStyle(TradingStyle.muted)
                .padding(.top, 5)

            if let message {
                Text(message)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(succeeded ? TradingStyle.green : TradingStyle.red)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 12)
            }

            Button {
                submitOrder()
            } label: {
                Text(succeeded ? "Done" : "Confirm simulated order")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 46)
                    .background(TradingStyle.green, in: RoundedRectangle(cornerRadius: 10))
            }
            .padding(.top, 17)

            Text("This does not place a real trade or move real money.")
                .font(.system(size: 9))
                .foregroundStyle(TradingStyle.muted)
                .frame(maxWidth: .infinity)
                .padding(.top, 10)
        }
        .padding(.horizontal, 22)
        .background(.white)
        .onChange(of: succeeded) { _, newValue in
            if newValue {
                quantityFocused = false
            }
        }
    }

    private func submitOrder() {
        guard !succeeded else {
            dismiss()
            return
        }
        quantityFocused = false
        switch trading.placeOrder(symbol: asset.symbol, side: side, quantity: quantity) {
        case .accepted:
            succeeded = true
            message = "\(side.rawValue) simulated. View the updated portfolio in Activity or Portfolio."
        case .rejected(let reason):
            message = reason
        }
    }
}

/// Shows the demo account totals, estimated gains, and each current holding.
struct PortfolioView: View {
    @EnvironmentObject private var trading: TradingStore
    @Environment(\.dismiss) private var dismiss
    private let viewModel = PortfolioViewModel()
    let onExplore: (() -> Void)?

    init(onExplore: (() -> Void)? = nil) {
        self.onExplore = onExplore
    }

    private var marketValue: Double { viewModel.marketValue(for: trading.positions) }
    private var investedValue: Double { viewModel.investedValue(for: trading.positions) }
    private var unrealizedGain: Double { marketValue - investedValue }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                pageHeading(
                    eyebrow: "YOUR MONEY, EXPLAINED",
                    title: "Portfolio",
                    subtitle: "A local, simulated account for learning."
                )
                totalCard
                gainCard
                HStack(alignment: .bottom) {
                    Text("Your positions")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(Color(red: 29 / 255, green: 41 / 255, blue: 35 / 255))
                    Spacer()
                    Text("\(trading.positions.count) HOLDINGS")
                        .font(.system(size: 9, weight: .bold))
                        .tracking(1)
                        .foregroundStyle(TradingStyle.muted)
                }
                .padding(.top, 30)
                .padding(.bottom, 12)

                if trading.positions.isEmpty {
                    emptyPortfolio
                } else {
                    VStack(spacing: 10) {
                        ForEach(trading.positions) { position in
                            if let asset = MarketData.asset(for: position.symbol) {
                                NavigationLink {
                                    AssetDetailView(asset: asset)
                                } label: {
                                    positionCard(position, asset: asset)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                Text("This portfolio exists only in app memory and resets when the app restarts.")
                    .font(.system(size: 10))
                    .foregroundStyle(TradingStyle.muted)
                    .lineSpacing(3)
                    .padding(.top, 14)
                    .padding(.bottom, 20)
            }
            .padding(.horizontal, 20)
            .padding(.top, 22)
        }
        .background(TradingStyle.background.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
    }

    private var totalCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("TOTAL DEMO ACCOUNT VALUE")
                .font(.system(size: 10, weight: .bold))
                .tracking(1)
                .foregroundStyle(Color(red: 184 / 255, green: 208 / 255, blue: 195 / 255))
            Text(DemoMoney.format(trading.cash + marketValue))
                .font(.system(size: 29, weight: .bold))
                .tracking(-0.5)
                .foregroundStyle(.white)
                .padding(.top, 10)
            Rectangle()
                .fill(Color(red: 65 / 255, green: 100 / 255, blue: 83 / 255))
                .frame(height: 1)
                .padding(.vertical, 17)
            HStack {
                summaryValue("Invested value", value: marketValue)
                Spacer()
                summaryValue("Available cash", value: trading.cash, alignment: .trailing)
            }
        }
        .padding(20)
        .background(TradingStyle.darkGreen, in: RoundedRectangle(cornerRadius: 18))
    }

    private var gainCard: some View {
        HStack {
            VStack(alignment: .leading, spacing: 5) {
                Text("Unrealized gain / loss")
                    .font(.system(size: 11))
                    .foregroundStyle(TradingStyle.secondary)
                Text(signedCurrency(unrealizedGain))
                    .font(.system(size: 19, weight: .bold))
                    .foregroundStyle(unrealizedGain >= 0 ? TradingStyle.green : TradingStyle.red)
            }
            Spacer()
            Text("Based on sample\nquote values")
                .font(.system(size: 9))
                .foregroundStyle(TradingStyle.muted)
                .multilineTextAlignment(.trailing)
        }
        .padding(16)
        .background(.white, in: RoundedRectangle(cornerRadius: 14))
        .padding(.top, 12)
    }

    private var emptyPortfolio: some View {
        VStack(spacing: 8) {
            Text("Your demo portfolio is empty")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(Color(red: 29 / 255, green: 41 / 255, blue: 35 / 255))
            Text("Explore an asset and simulate a buy to see how positions work.")
                .font(.system(size: 12))
                .foregroundStyle(TradingStyle.secondary)
                .multilineTextAlignment(.center)
            Button {
                if let onExplore {
                    onExplore()
                } else {
                    dismiss()
                }
            } label: {
                Text("Explore sample assets")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 15)
                    .padding(.vertical, 11)
                    .background(TradingStyle.green, in: RoundedRectangle(cornerRadius: 10))
            }
            .padding(.top, 7)
        }
        .frame(maxWidth: .infinity)
        .padding(20)
        .background(.white, in: RoundedRectangle(cornerRadius: 15))
    }

    private func summaryValue(_ title: String, value: Double, alignment: HorizontalAlignment = .leading) -> some View {
        VStack(alignment: alignment, spacing: 5) {
            Text(title)
                .font(.system(size: 11))
                .foregroundStyle(Color(red: 184 / 255, green: 208 / 255, blue: 195 / 255))
            Text(DemoMoney.format(value))
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(.white)
        }
    }

    private func positionCard(_ position: Position, asset: MarketAsset) -> some View {
        let value = viewModel.marketValue(for: position, asset: asset)
        let gain = viewModel.gainLoss(for: position, asset: asset)

        return VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(position.symbol)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(TradingStyle.ink)
                    Text("\(position.quantity) shares at \(DemoMoney.format(position.averageCost)) avg.")
                        .font(.system(size: 11))
                        .foregroundStyle(TradingStyle.secondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text(DemoMoney.format(value))
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(TradingStyle.ink)
                    Text(signedCurrency(gain))
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(gain >= 0 ? TradingStyle.green : TradingStyle.red)
                }
            }
            SparklineView(values: asset.history, color: gain >= 0 ? TradingStyle.green : TradingStyle.red, height: 24)
                .accessibilityLabel("Sample price trend chart")
        }
        .padding(.horizontal, 16)
        .padding(.top, 15)
        .padding(.bottom, 11)
        .background(.white, in: RoundedRectangle(cornerRadius: 14))
    }
}

/// Lists simulated orders and explains that no real trades are placed.
struct ActivityView: View {
    @EnvironmentObject private var trading: TradingStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                pageHeading(
                    eyebrow: "A CLEAR RECORD",
                    title: "Activity",
                    subtitle: "Every order in this screen is simulated."
                )

                if trading.orders.isEmpty {
                    emptyActivity
                } else {
                    VStack(spacing: 0) {
                        ForEach(trading.orders) { order in
                            orderRow(order)
                            if order.id != trading.orders.last?.id {
                                Rectangle()
                                    .fill(Color(red: 229 / 255, green: 232 / 255, blue: 226 / 255))
                                    .frame(height: 0.5)
                            }
                        }
                    }
                    .padding(.horizontal, 14)
                    .background(.white, in: RoundedRectangle(cornerRadius: 15))
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("What does SIMULATED mean?")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Color(red: 49 / 255, green: 69 / 255, blue: 58 / 255))
                    Text("These records change only this app's local demo portfolio. They are not sent to an exchange or broker and have no monetary value.")
                        .font(.system(size: 11))
                        .foregroundStyle(Color(red: 117 / 255, green: 128 / 255, blue: 120 / 255))
                        .lineSpacing(4)
                }
                .padding(15)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(red: 240 / 255, green: 243 / 255, blue: 239 / 255), in: RoundedRectangle(cornerRadius: 13))
                .padding(.top, 19)
                .padding(.bottom, 20)
            }
            .padding(.horizontal, 20)
            .padding(.top, 22)
        }
        .background(TradingStyle.background.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
    }

    private var emptyActivity: some View {
        VStack(spacing: 0) {
            Text("--")
                .font(.system(size: 17, weight: .heavy))
                .foregroundStyle(TradingStyle.green)
                .frame(width: 52, height: 52)
                .background(Color(red: 234 / 255, green: 241 / 255, blue: 236 / 255), in: Circle())
            Text("No activity yet")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(Color(red: 29 / 255, green: 41 / 255, blue: 35 / 255))
                .padding(.top, 16)
            Text("When you simulate a buy or sell, its status, quantity, and sample price will appear here.")
                .font(.system(size: 12))
                .foregroundStyle(TradingStyle.secondary)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .padding(.top, 8)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 22)
        .padding(.vertical, 34)
        .background(.white, in: RoundedRectangle(cornerRadius: 16))
    }

    private func orderRow(_ order: SimulatedOrder) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 11) {
                Text(order.side.rawValue)
                    .font(.system(size: 10, weight: .heavy))
                    .foregroundStyle(order.side == .buy ? TradingStyle.green : TradingStyle.red)
                    .frame(width: 44, height: 30)
                    .background(
                        order.side == .buy
                            ? Color(red: 231 / 255, green: 242 / 255, blue: 235 / 255)
                            : Color(red: 249 / 255, green: 233 / 255, blue: 232 / 255),
                        in: RoundedRectangle(cornerRadius: 8)
                    )
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(order.quantity) \(order.symbol)")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Color(red: 29 / 255, green: 41 / 255, blue: 35 / 255))
                    Text("\(MarketData.asset(for: order.symbol)?.companyName ?? "Sample asset") · \(DemoMoney.format(order.price)) per share")
                        .font(.system(size: 10))
                        .foregroundStyle(TradingStyle.secondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 4)
                VStack(alignment: .trailing, spacing: 4) {
                    Text(DemoMoney.format(order.total))
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Color(red: 29 / 255, green: 41 / 255, blue: 35 / 255))
                    Text("SIMULATED")
                        .font(.system(size: 9, weight: .heavy))
                        .tracking(0.3)
                        .foregroundStyle(Color(red: 164 / 255, green: 123 / 255, blue: 55 / 255))
                }
                .fixedSize()
            }
            Text(order.createdAt.formatted(date: .abbreviated, time: .shortened))
                .font(.system(size: 9))
                .foregroundStyle(TradingStyle.muted)
                .padding(.leading, 55)
        }
        .padding(.vertical, 14)
    }
}

private func pageHeading(eyebrow: String, title: String, subtitle: String) -> some View {
    VStack(alignment: .leading, spacing: 0) {
        Text(eyebrow)
            .font(.system(size: 10, weight: .heavy))
            .tracking(1.5)
            .foregroundStyle(TradingStyle.green)
        Text(title)
            .font(.system(size: 30, weight: .bold))
            .tracking(-0.8)
            .foregroundStyle(TradingStyle.ink)
            .padding(.top, 9)
        Text(subtitle)
            .font(.system(size: 13))
            .foregroundStyle(Color(red: 114 / 255, green: 123 / 255, blue: 117 / 255))
            .padding(.top, 6)
            .padding(.bottom, 22)
    }
}

/// Formats a currency amount with a leading sign for gains and losses.
private func signedCurrency(_ amount: Double) -> String {
    "\(amount >= 0 ? "+" : "-")\(DemoMoney.format(abs(amount)))"
}
