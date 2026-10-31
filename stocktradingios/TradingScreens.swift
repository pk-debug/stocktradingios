/// TradingScreens.swift contains native forms and lists. Each screen reads shared state and sends user actions to the store.

import NorthstarCore
import SwiftUI

/// Choose login or signup. Hosted providers handle secrets; localhost credentials use the legacy practice API.
struct LoginView: View {
  @EnvironmentObject private var trading: TradingStore
  @State private var username = ""
  @State private var password = ""
  @State private var register = false
  @State private var confirmation = ""

  var body: some View {
    Form {
      Section {
        Label("NORTHSTAR", systemImage: "sparkles").font(.title.bold())
        Text("Practice investing, one decision at a time.").font(.title2)
        Text(
          "Synthetic Indian stock prices and virtual rupees. No live quotes, brokerage or real-money orders."
        )
        .foregroundStyle(.secondary)
      }
      Section(register ? "Create your account" : "Welcome back") {
        Picker("Account action", selection: $register) {
          Text("Log in").tag(false)
          Text("Sign up").tag(true)
        }.pickerStyle(.segmented)
        if trading.hostedLoginAvailable {
          Button(register ? "Create account with email" : "Log in with email") {
            Task { await trading.hostedSignIn(connection: nil, signup: register) }
          }.accessibilityIdentifier("hostedEmail")
          providerButton("Apple", connection: "apple", image: "apple.logo")
          providerButton("Google", connection: "google", image: "person.crop.circle")
          providerButton("Facebook", connection: "facebook", image: "person.2")
          providerButton("mobile number", connection: "phone", image: "phone")
          Text(
            "A secure browser window handles your password or SMS code. Never share a verification code. SMS delivery and verification are provided by the identity service."
          )
          .font(.footnote).foregroundStyle(.secondary)
        } else {
          #if DEBUG
            Text(
              "Google, Facebook, Apple and mobile sign-in need an identity-service configuration. Local username login below works without a paid service."
            )
            .font(.footnote).foregroundStyle(.secondary)
            ForEach(["Apple", "Google", "Facebook", "mobile number"], id: \.self) { provider in
              Button("Continue with \(provider)") {}.disabled(true)
            }
          #endif
        }
      }
      Section("Practice on this device") {
        Button("Enter offline demo") { Task { await trading.enterOffline() } }
          .accessibilityIdentifier("enterOffline")
        Text("No account needed. Your demo holdings, orders and watchlist stay on this device.")
          .font(.footnote).foregroundStyle(.secondary)
      }
      if trading.apiOrigin != nil && !trading.identityConfigured {
        Section(register ? "Create local-server paper account" : "Local-server paper account") {
          if let error = trading.configurationError {
            Text(error).foregroundStyle(.red)
          } else {
            TextField("Username", text: $username)
              .textContentType(.username).textInputAutocapitalization(.never)
              .autocorrectionDisabled().keyboardType(.asciiCapable)
              .accessibilityIdentifier("username")
            SecureField("Password", text: $password)
              .textContentType(register ? .newPassword : .password)
              .accessibilityIdentifier("password")
            if register {
              SecureField("Confirm password", text: $confirmation).textContentType(.newPassword)
              if !confirmation.isEmpty && confirmation != password {
                Text("Passwords must match.").foregroundStyle(.red)
              }
            }
            Text("Username: 3–40 letters, numbers, _, . or -. Password: 12–128 characters.")
              .font(.footnote).foregroundStyle(.secondary)
            Button(register ? "Create paper account" : "Sign in") {
              // Clear the password immediately. This local-server flow never saves it or its opaque token.
              let suppliedPassword = password
              password = ""
              confirmation = ""
              Task {
                await trading.authenticate(
                  username: username, password: suppliedPassword, register: register)
              }
            }
            .disabled(register && (confirmation != password || password.isEmpty))
            Button(register ? "Already registered? Sign in" : "Create an account") {
              register.toggle()
              password = ""
              confirmation = ""
              trading.message = nil
            }
            Text(
              "Each API account starts empty with ₹10 lakh in virtual cash. Signing in again is required after restarting."
            )
            .font(.footnote).foregroundStyle(.secondary)
          }
        }
      }
      StatusSection()
      Section { NavigationLink("Privacy and demo limits") { PrivacyView() } }
    }
    .navigationTitle("Welcome")
    .disabled(trading.isBusy)
  }
  /// Each provider is enabled by a public connection name; no provider secret
  /// belongs in the app. Unconfigured providers are absent in Release builds.
  @ViewBuilder private func providerButton(_ title: String, connection: String, image: String)
    -> some View
  {
    if let name = trading.connection(connection) {
      Button("Continue with \(title)", systemImage: image) {
        Task { await trading.hostedSignIn(connection: name, signup: register) }
      }.accessibilityIdentifier("login-" + connection)
    }
  }

}

/// Show progress, safe messages and an explicit retry of the original unconfirmed order.
struct StatusSection: View {
  @EnvironmentObject private var trading: TradingStore
  var body: some View {
    if trading.isBusy {
      Section { ProgressView("Working…").accessibilityIdentifier("working") }
    }
    if let message = trading.message {
      Section {
        Text(message).accessibilityIdentifier("statusMessage")
        Button("Dismiss message") { trading.message = nil }
      }
    }
    if let pending = trading.pending {
      Section("Unconfirmed paper order") {
        Text(
          "\(pending.request.side.rawValue) \(pending.request.quantity) × \(pending.request.symbol)"
        )
        Text(
          "The server may already have completed this order. Retry sends the original ID and cannot intentionally create a second order. New orders are blocked until this is resolved."
        )
        .font(.footnote)
        Button("Retry original order") { Task { await trading.retryOrder() } }
          .disabled(trading.isBusy).accessibilityIdentifier("retryOrder")
      }
    }
  }
}

/// Filter the in-memory catalog and navigate to details without performing work inside rendering.
struct DiscoverView: View {
  @EnvironmentObject private var trading: TradingStore
  @State private var query = ""
  @State private var category = ""
  @State private var sort: AssetSort = .alphabetical
  private var results: [MarketAsset] {
    Discovery.assets(trading.assets, query: query, category: category, sort: sort)
  }
  var body: some View {
    List {
      Section(trading.accountLabel) {
        LabeledContent("Account value", value: DemoMoney.format(trading.cash + trading.marketValue))
        LabeledContent("Available virtual cash", value: DemoMoney.format(trading.cash))
        Text("Paper trading only · prices are synthetic").font(.footnote).foregroundStyle(
          .secondary)
      }
      StatusSection()
      Section("Illustrative market snapshot") {
        ForEach(trading.indexes) { index in
          LabeledContent(index.name) {
            VStack(alignment: .trailing) {
              Text(index.value)
              Label(
                index.change, systemImage: index.isPositive ? "arrow.up.right" : "arrow.down.right"
              )
              .font(.footnote)
            }
          }
          .accessibilityElement(children: .combine)
        }
      }
      Section("Explore companies") {
        Picker("Sector", selection: $category) {
          Text("All sectors").tag("")
          ForEach(Array(Set(trading.assets.map(\.category))).sorted(), id: \.self) {
            Text($0).tag($0)
          }
        }
        Picker("Sort", selection: $sort) {
          ForEach(AssetSort.allCases, id: \.self) { Text($0.rawValue).tag($0) }
        }
        if results.isEmpty {
          ContentUnavailableView.search(text: query)
        }
        ForEach(results) { asset in
          NavigationLink {
            AssetDetailView(asset: asset)
          } label: {
            AssetRow(asset: asset)
          }
          .accessibilityIdentifier("asset-\(asset.symbol)")
        }
      }
    }
    .navigationTitle("Discover")
    .searchable(text: $query, prompt: "Company or ticker")
    .refreshable { await trading.refresh() }
    .toolbar {
      if trading.mode == .remote {
        Button("Refresh", systemImage: "arrow.clockwise") { Task { await trading.refresh() } }
          .disabled(trading.isBusy)
      }
    }
  }
}

/// One accessible company summary; the layout can stack when text grows.
struct AssetRow: View {
  let asset: MarketAsset
  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      ViewThatFits(in: .horizontal) {
        HStack(alignment: .firstTextBaseline) {
          Text(asset.symbol).font(.headline)
          Spacer()
          Text(DemoMoney.format(asset.price)).monospacedDigit()
        }
        VStack(alignment: .leading) {
          Text(asset.symbol).font(.headline)
          Text(DemoMoney.format(asset.price)).monospacedDigit()
        }
      }
      Text(asset.companyName).font(.subheadline).foregroundStyle(.secondary)
      Label(
        "\(asset.changePercent.formatted(.number.precision(.fractionLength(2))))%",
        systemImage: asset.isPositive ? "arrow.up.right" : "arrow.down.right"
      )
      .font(.footnote).foregroundStyle(asset.trendColor)
    }
    .padding(.vertical, 4)
    .accessibilityElement(children: .combine)
  }
}

/// Show the selected synthetic quote, illustrative trend and entry points for watchlists and reviewed orders.
struct AssetDetailView: View {
  @EnvironmentObject private var trading: TradingStore
  let asset: MarketAsset
  @State private var showOrder = false
  private var current: MarketAsset { trading.asset(asset.symbol) ?? asset }
  var body: some View {
    List {
      Section { AssetRow(asset: current) }
      Section("Illustrative trend") {
        Sparkline(values: current.history)
          .stroke(
            current.trendColor, style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round)
          )
          .frame(height: 130)
          .padding(.vertical)
          .accessibilityLabel(
            "Synthetic trend for \(current.symbol). Illustrative values, not historical market prices."
          )
        Text("Sample shape only; no historical intervals or live feed.").font(.footnote)
          .foregroundStyle(.secondary)
      }
      Section("Company") {
        LabeledContent("Sector", value: current.category)
        LabeledContent("Exchange", value: current.exchange)
        LabeledContent(
          "Shares owned",
          value: "\(trading.positions.first { $0.symbol == current.symbol }?.quantity ?? 0)")
      }
      Section {
        Button(
          trading.ledger.watchlist.contains(current.symbol)
            ? "Remove from watchlist" : "Add to watchlist",
          systemImage: trading.ledger.watchlist.contains(current.symbol) ? "star.fill" : "star"
        ) {
          Task { await trading.toggleWatch(current) }
        }
        .disabled(trading.isBusy).accessibilityIdentifier("toggleWatch")
        Button("Review paper order", systemImage: "arrow.left.arrow.right") { showOrder = true }
          .disabled(trading.isBusy || trading.pending != nil)
          .accessibilityIdentifier("reviewOrder")
      }
      StatusSection()
    }
    .navigationTitle(current.symbol)
    .sheet(isPresented: $showOrder) { NavigationStack { OrderTicketView(asset: current) } }
  }
}

/// Draw an illustrative shape from fixture values; this is not a historical-price chart.
struct Sparkline: Shape {
  let values: [Double]
  func path(in rect: CGRect) -> Path {
    guard values.count > 1, values.allSatisfy(\.isFinite), let low = values.min(),
      let high = values.max()
    else { return Path() }
    let span = max(high - low, 1)
    return Path { path in
      for (index, value) in values.enumerated() {
        let point = CGPoint(
          x: rect.width * CGFloat(index) / CGFloat(values.count - 1),
          y: rect.height * CGFloat(1 - (value - low) / span))
        if index == 0 { path.move(to: point) } else { path.addLine(to: point) }
      }
    }
  }
}

/// Separate editing from review so submitting an order is an explicit final decision.
struct OrderTicketView: View {
  @EnvironmentObject private var trading: TradingStore
  @Environment(\.dismiss) private var dismiss
  let asset: MarketAsset
  @State private var side: OrderSide = .buy
  @State private var quantity = "1"
  @State private var reviewing = false
  private var count: Int { Int(quantity) ?? 0 }
  private var preview: OrderPreview { trading.preview(asset: asset, side: side, quantity: count) }
  var body: some View {
    Form {
      Section(reviewing ? "Review paper market order" : "Paper market order") {
        LabeledContent("Stock", value: asset.symbol)
        if reviewing {
          LabeledContent("Side", value: side.rawValue)
          LabeledContent("Whole shares", value: quantity)
        } else {
          Picker("Side", selection: $side) {
            Text("Buy").tag(OrderSide.buy)
            Text("Sell").tag(OrderSide.sell)
          }.pickerStyle(.segmented)
          TextField("Whole shares", text: $quantity).keyboardType(.numberPad)
            .accessibilityIdentifier("orderQuantity")
        }
        LabeledContent("Sample price", value: DemoMoney.format(asset.price))
        LabeledContent("Estimated order value", value: DemoMoney.format(preview.estimatedValue))
        LabeledContent("Virtual cash after order", value: DemoMoney.format(preview.cashAfter))
        LabeledContent("Maximum affordable buy", value: "\(preview.maxBuyQuantity)")
        LabeledContent("Shares owned", value: "\(preview.ownedQuantity)")
      }
      Section {
        Text(
          "Synthetic market order. No real money moves. No brokerage, taxes or exchange fees are deducted. The API server validates and prices API orders."
        )
        if let error = preview.error { Text(error).foregroundStyle(.red) }
        if reviewing {
          Button("Confirm paper \(side == .buy ? "buy" : "sale")") {
            Task {
              if await trading.placeOrder(asset: asset, side: side, quantity: count) {
                dismiss()
              } else {
                reviewing = false
              }
            }
          }
          .accessibilityIdentifier("confirmOrder")
          Button("Edit order") { reviewing = false }
        } else {
          Button("Review order") { reviewing = true }
            .accessibilityIdentifier("continueReview")
        }
      }
      .disabled(!preview.canSubmit || trading.isBusy || trading.pending != nil)
      StatusSection()
    }
    .navigationTitle(reviewing ? "Review" : "Order ticket")
    .toolbar {
      ToolbarItem(placement: .cancellationAction) {
        Button("Cancel") { dismiss() }.disabled(trading.isBusy)
      }
    }
    .interactiveDismissDisabled(trading.isBusy)
  }
}

/// Display the account’s saved symbols and let the store perform add/remove operations.
struct WatchlistView: View {
  @EnvironmentObject private var trading: TradingStore
  private var watched: [MarketAsset] {
    trading.assets.filter { trading.ledger.watchlist.contains($0.symbol) }
  }
  var body: some View {
    List {
      StatusSection()
      if watched.isEmpty {
        ContentUnavailableView(
          "Your watchlist is empty", systemImage: "star",
          description: Text("Explore a company in Discover and add it to your watchlist."))
      }
      ForEach(watched) { asset in
        NavigationLink {
          AssetDetailView(asset: asset)
        } label: {
          AssetRow(asset: asset)
        }
        .swipeActions {
          Button("Remove", role: .destructive) { Task { await trading.toggleWatch(asset) } }
            .disabled(trading.isBusy)
        }
      }
    }
    .navigationTitle("Watchlist")
    .refreshable { await trading.refresh() }
  }
}

/// Explain virtual cash, holdings value and unrealized profit/loss using the current snapshot.
struct PortfolioView: View {
  @EnvironmentObject private var trading: TradingStore
  var body: some View {
    List {
      Section("Virtual account") {
        LabeledContent("Cash", value: DemoMoney.format(trading.cash))
        LabeledContent("Holdings value", value: DemoMoney.format(trading.marketValue))
        LabeledContent("Invested value", value: DemoMoney.format(trading.investedValue))
        LabeledContent(
          "Unrealized gain/loss",
          value: DemoMoney.format(trading.marketValue - trading.investedValue))
        Text("Estimates from synthetic quotes. Fees and taxes are excluded.").font(.footnote)
          .foregroundStyle(.secondary)
      }
      StatusSection()
      Section("Holdings") {
        if trading.positions.isEmpty {
          ContentUnavailableView(
            "No holdings yet", systemImage: "chart.pie",
            description: Text("Explore Discover to review your first paper order."))
        }
        ForEach(trading.positions) { position in
          if let asset = trading.asset(position.symbol) {
            NavigationLink {
              AssetDetailView(asset: asset)
            } label: {
              VStack(alignment: .leading, spacing: 6) {
                AssetRow(asset: asset)
                Text(
                  "\(position.quantity) shares · average \(DemoMoney.format(position.averageCost))")
                Text("Value \(DemoMoney.format(asset.price * Double(position.quantity)))")
                Text(
                  "Unrealized P/L \(DemoMoney.format((asset.price - position.averageCost) * Double(position.quantity)))"
                )
              }
              .font(.subheadline).accessibilityElement(children: .combine)
            }
          } else {
            Text("\(position.symbol): quote unavailable. Refresh your account.")
          }
        }
      }
    }
    .navigationTitle("Portfolio")
    .refreshable { await trading.refresh() }
  }
}

/// Read completed paper-order receipts; an unresolved order is not shown as a confirmed fill.
struct ActivityView: View {
  @EnvironmentObject private var trading: TradingStore
  var body: some View {
    List {
      StatusSection()
      if trading.orders.isEmpty {
        ContentUnavailableView(
          "No paper orders yet", systemImage: "clock",
          description: Text("Completed paper orders will appear here."))
      }
      ForEach(trading.orders) { order in
        VStack(alignment: .leading, spacing: 6) {
          Label(
            "\(order.side.rawValue) \(order.symbol)",
            systemImage: order.side == .buy ? "arrow.down.left" : "arrow.up.right"
          )
          .font(.headline)
          Text("\(order.quantity) shares × \(DemoMoney.format(order.price))")
          Text(DemoMoney.format(order.total)).monospacedDigit()
          Text(order.createdAt, format: .dateTime.day().month().year().hour().minute())
            .font(.footnote).foregroundStyle(.secondary)
          Text("Completed · paper order").font(.footnote)
        }
        .accessibilityElement(children: .combine)
      }
      if trading.mode == .remote {
        Text("The API returns the latest 500 completed orders.").font(.footnote).foregroundStyle(
          .secondary)
      }
    }
    .navigationTitle("Activity")
    .refreshable { await trading.refresh() }
  }
}

/// Manage device security, learn investing basics, sign out or request permanent account deletion.
struct AccountView: View {
  @EnvironmentObject private var trading: TradingStore
  @EnvironmentObject private var access: AppAccess
  @State private var deleting = false
  var body: some View {
    List {
      Section("Account") {
        Text(trading.accountLabel).font(.headline)
        if trading.mode == .remote { LabeledContent("Username", value: trading.username) }
        Text(
          trading.mode == .remote
            ? "The server owns this virtual ledger. Hosted identity sessions are kept in this device’s Keychain. Local-server sessions end on restart."
            : "Your demo ledger is saved locally and survives restart. Signing out does not erase it."
        )
        .foregroundStyle(.secondary)
      }
      StatusSection()
      Section("Device security") {
        Text(
          "Face ID and Touch ID depend on your device. Your device passcode provides recovery. Biometric data never leaves iOS."
        )
        .font(.footnote).foregroundStyle(.secondary)
        if access.enabled {
          Button("Lock app now", systemImage: "lock") { access.lock() }
          Button("Turn off app lock") { Task { await access.disable() } }.disabled(
            access.authenticating)
        } else {
          Button("Enable \(access.biometricName) app lock", systemImage: "lock.shield") {
            Task { await access.enable() }
          }
          .disabled(!access.biometricAvailable || access.authenticating)
        }
        if let error = access.error { Text(error).foregroundStyle(.red) }
      }
      Section("Learn the basics") {
        ForEach(LearningLesson.all) { lesson in
          DisclosureGroup(lesson.title) { Text(lesson.explanation).padding(.vertical, 8) }
        }
      }
      Section {
        NavigationLink("Privacy and demo limits") { PrivacyView() }
        Button("Sign out", role: .destructive) { Task { await trading.signOut() } }.disabled(
          trading.isBusy)
        if trading.mode == .remote {
          Button("Delete API account permanently", role: .destructive) { deleting = true }
            .disabled(trading.isBusy).accessibilityIdentifier("deleteAccount")
        }
      }
    }
    .navigationTitle("Account & learning")
    .confirmationDialog(
      "Delete your API paper account permanently?", isPresented: $deleting,
      titleVisibility: .visible
    ) {
      Button("Delete account and all server data", role: .destructive) {
        Task { await trading.deleteAccount() }
      }
    } message: {
      Text(
        "This deletes your server account, holdings, watchlist, sessions and orders. This cannot be undone."
      )
    }
  }
}

/// Explain data handling and product limits in plain language before the user creates an account.
struct PrivacyView: View {
  var body: some View {
    List {
      Section("On this device") {
        Text(
          "Offline holdings, watchlists and paper orders are stored in the app’s private storage. API retry instructions contain an order ID and payload scoped to the account and server. Passwords are never saved. Hosted identity access and rotating refresh tokens use this device’s Keychain; local-server tokens remain in memory. No advertising or analytics SDK is included."
        )
      }
      Section("API paper accounts") {
        Text(
          "In API mode, your username, password and account actions are sent over HTTPS to the configured Northstar server. That server stores your account and transactions. Sessions expire. Hosted sessions renew through the identity provider when possible; revoked sessions require sign-in. Optional social and phone providers process the data needed to authenticate you. You can permanently delete your API account from Account."
        )
      }
      Section("Learning demo") {
        Text(
          "All prices and indexes are synthetic. There are no deposits, withdrawals, real trades or live quotes. This is not investment advice. Real execution, limit/stop orders, taxes, notifications and password recovery are not supported."
        )
      }
    }
    .navigationTitle("Privacy & limits")
  }
}
