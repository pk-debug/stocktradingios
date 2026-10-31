/// TradingStore.swift is the screen coordinator. MainActor protects UI state; package actors handle account rules, disk and networking.
import Combine
import Foundation
import NorthstarCore

/// SwiftUI's presentation owner. The Swift package owns trading rules, disk I/O and HTTP.
@MainActor
final class TradingStore: ObservableObject {
  enum Mode { case signedOut, offline, remote }
  @Published private(set) var mode: Mode = .signedOut
  @Published private(set) var ledger = TradingLedger(cash: 0)
  @Published private(set) var assets: [MarketAsset] = []
  @Published private(set) var indexes: [MarketIndex] = []
  @Published private(set) var pending: PendingOrder?
  @Published private(set) var isBusy = false
  @Published private(set) var deletionPending = false
  @Published var message: String?
  @Published private(set) var username = ""
  let apiOrigin: String?
  let configurationError: String?
  let access: AppAccess
  private let browser = BrowserSignIn()
  private let identityConfiguration: IdentityConfiguration?
  private let identitySession: IdentitySession?
  private var usingIdentity = false
  private var attemptedRestore = false
  var hostedLoginAvailable: Bool { identityConfiguration != nil && remote != nil }
  var identityConfigured: Bool {
    !(Bundle.main.object(forInfoDictionaryKey: "NORTHSTAR_IDENTITY_ISSUER") as? String ?? "")
      .isEmpty
  }
  func connection(_ name: String) -> String? {
    let key = "NORTHSTAR_CONNECTION_" + name.uppercased()
    guard let value = Bundle.main.object(forInfoDictionaryKey: key) as? String, !value.isEmpty
    else { return nil }
    return value
  }
  private let demo: DemoAccount
  private let remote: RemoteAccount?
  var cash: Double { ledger.cash }
  var positions: [Position] { ledger.positions }
  var orders: [SimulatedOrder] { ledger.orders }
  var accountLabel: String { mode == .remote ? "API paper account" : "Offline demo" }
  var marketValue: Double {
    positions.reduce(0) { $0 + Double($1.quantity) * (asset($1.symbol)?.price ?? 0) }
  }
  var investedValue: Double { positions.reduce(0) { $0 + Double($1.quantity) * $1.averageCost } }

  init(storage: (any AccountStorage)? = nil, origin: String? = nil, access: AppAccess? = nil) {
    self.access = access ?? AppAccess()
    let bundle = Bundle.main
    let issuer = bundle.object(forInfoDictionaryKey: "NORTHSTAR_IDENTITY_ISSUER") as? String ?? ""
    if !issuer.isEmpty {
      let configuration = try? IdentityConfiguration(
        issuer: issuer,
        clientID: bundle.object(forInfoDictionaryKey: "NORTHSTAR_IDENTITY_CLIENT_ID") as? String
          ?? "",
        audience: bundle.object(forInfoDictionaryKey: "NORTHSTAR_IDENTITY_AUDIENCE") as? String
          ?? "",
        redirectURI: (bundle.bundleIdentifier ?? "") + "://auth/callback")
      identityConfiguration = configuration
      identitySession = configuration.map {
        IdentitySession(configuration: $0, secureStorage: KeychainVault())
      }
    } else {
      identityConfiguration = nil
      identitySession = nil
    }
    let directory = URL.applicationSupportDirectory.appendingPathComponent(
      "Northstar", isDirectory: true)
    let resolvedStorage: any AccountStorage
    #if DEBUG
      if storage == nil && ProcessInfo.processInfo.arguments.contains("--ui-testing") {
        let testDirectory = URL.temporaryDirectory.appendingPathComponent(
          "NorthstarUITests", isDirectory: true)
        if ProcessInfo.processInfo.arguments.contains("--reset-ui-data") {
          try? FileManager.default.removeItem(at: testDirectory)
        }
        resolvedStorage = FileAccountStorage(directory: testDirectory)
      } else {
        resolvedStorage = storage ?? FileAccountStorage(directory: directory)
      }
    #else
      resolvedStorage = storage ?? FileAccountStorage(directory: directory)
    #endif
    let storage = resolvedStorage
    demo = DemoAccount(storage: storage)
    let configured =
      origin ?? Bundle.main.object(forInfoDictionaryKey: "NORTHSTAR_API_ORIGIN") as? String
    let value = configured?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    apiOrigin = value.isEmpty ? nil : value
    if !value.isEmpty {
      do {
        #if DEBUG
          remote = try RemoteAccount(origin: value, storage: storage, allowLocalHTTP: true)
        #else
          remote = try RemoteAccount(origin: value, storage: storage)
        #endif
        configurationError = nil
      } catch {
        remote = nil
        configurationError =
          "The API origin is invalid. Use HTTPS, or a Debug-only localhost origin."
      }
    } else {
      remote = nil
      configurationError = nil
    }
  }

  func asset(_ symbol: String) -> MarketAsset? { assets.first { $0.symbol == symbol } }
  func preview(asset: MarketAsset, side: OrderSide, quantity: Int) -> OrderPreview {
    OrderPreview(asset: asset, side: side, quantity: quantity, ledger: ledger)
  }
  /// Load the device-local practice account without requiring any paid identity provider.
  func enterOffline() async {
    guard !deletionPending, !access.locked, !isBusy else { return }
    isBusy = true
    defer { isBusy = false }
    do {
      let loaded = try await demo.load()
      ledger = loaded
      assets = MarketData.assets
      indexes = MarketData.indexes
      mode = .offline
      pending = nil
      message = nil
    } catch {
      message = "The saved demo account could not be read. Your saved file has been preserved."
    }
  }
  /// Use the original localhost username API; it has no OAuth refresh token.
  func authenticate(username: String, password: String, register: Bool) async {
    guard !deletionPending, !access.locked, !isBusy, let remote else { return }
    isBusy = true
    defer { isBusy = false }
    do {
      try await remote.authenticate(username: username, password: password, register: register)
      let data = try await remote.load()
      usingIdentity = false
      self.username = username.lowercased()
      apply(data)
      mode = .remote
      message = nil
    } catch { await report(error) }
  }
  /// Restore only after the device lock opens. A failed network request keeps the
  /// Keychain receipt so the user can retry when connectivity returns.
  func restoreIdentity() async {
    guard !deletionPending, !access.locked, !attemptedRestore, mode == .signedOut,
      let identitySession, let remote
    else { return }
    attemptedRestore = true
    guard !isBusy else { return }
    isBusy = true
    defer { isBusy = false }
    do {
      guard let subject = try await identitySession.restore() else { return }
      try await remote.useIdentity(identitySession, subject: subject)
      let data = try await remote.load()
      apply(data)
      username = "Connected account"
      usingIdentity = true
      mode = .remote
    } catch { await report(error) }
  }
  func hostedSignIn(connection: String?, signup: Bool) async {
    guard !deletionPending, !access.locked, !isBusy, let configuration = identityConfiguration,
      let identitySession, let remote
    else { return }
    isBusy = true
    defer { isBusy = false }
    do {
      let subject = try await browser.signIn(
        configuration: configuration, connection: connection, signup: signup,
        session: identitySession)
      try await remote.useIdentity(identitySession, subject: subject)
      let data = try await remote.load()
      apply(data)
      username = "Connected account"
      usingIdentity = true
      mode = .remote
      message = nil
    } catch is CancellationError {
      message = "Sign-in was cancelled. You can try again when ready."
    } catch { await report(error) }
  }
  /// Replace visible account state only after a fresh authenticated server snapshot succeeds.
  func refresh() async {
    guard !deletionPending, !access.locked, mode == .remote, !isBusy, let remote else { return }
    isBusy = true
    defer { isBusy = false }
    do {
      apply(try await remote.load())
      message = nil
    } catch { await report(error) }
  }
  /// No optimistic ledger changes: a save/server snapshot must succeed first.
  func placeOrder(asset: MarketAsset, side: OrderSide, quantity: Int) async -> Bool {
    guard !deletionPending, !access.locked, !isBusy, mode != .signedOut, pending == nil else {
      return false
    }
    isBusy = true
    defer { isBusy = false }
    do {
      if mode == .remote, let remote {
        ledger = try await remote.submit(
          OrderRequest(symbol: asset.symbol, side: side, quantity: quantity))
        pending = await remote.pending
      } else {
        let updated = try TradingRules.placeOrder(
          ledger: ledger, asset: asset, side: side, quantity: quantity)
        try await demo.save(updated)
        ledger = updated
      }
      message = "Paper order completed. No real money moved."
      return true
    } catch {
      await report(error)
      return false
    }
  }
  /// Resolve an uncertain order with its original UUID rather than creating a new order.
  func retryOrder() async {
    guard !deletionPending, !access.locked, !isBusy, mode == .remote, let remote else { return }
    isBusy = true
    defer { isBusy = false }
    do {
      ledger = try await remote.retry()
      pending = await remote.pending
      message = "The original paper order was confirmed."
    } catch { await report(error) }
  }
  /// Save a watchlist change before publishing it, so the UI never promises an unsaved change.
  func toggleWatch(_ asset: MarketAsset) async {
    guard !deletionPending, !access.locked, !isBusy, mode != .signedOut else { return }
    isBusy = true
    defer { isBusy = false }
    let enabled = !ledger.watchlist.contains(asset.symbol)
    do {
      if mode == .remote, let remote {
        ledger = try await remote.watch(asset.symbol, enabled: enabled)
      } else {
        var updated = ledger
        updated.watchlist.removeAll { $0 == asset.symbol }
        if enabled { updated.watchlist.append(asset.symbol) }
        try await demo.save(updated)
        ledger = updated
      }
      message = nil
    } catch { await report(error) }
  }
  /// Erase device credentials and attempt remote revocation; an app lock stays enabled until explicitly disabled.
  func signOut() async {
    guard !access.locked, !isBusy else { return }
    isBusy = true
    defer { isBusy = false }
    var warning: String?
    do {
      // Erase hosted receipts even when the user entered offline mode after
      // a failed hosted login. Explicit sign-out must not restore them later.
      if let identitySession { try await identitySession.signOut() }
    } catch is VaultError {
      message = "Secure sign-out could not finish. Unlock your device and try again."
      return
    } catch {
      warning =
        "Signed out on this device. Remote revocation could not be confirmed; the session will expire automatically."
    }
    if mode == .remote, let remote {
      do {
        if usingIdentity { try await remote.forgetIdentity() } else { try await remote.signOut() }
      } catch {
        warning =
          "Signed out on this device. Remote revocation could not be confirmed; the session will expire automatically."
      }
    }
    clear()
    message = warning
  }
  /// Ask the server to remove the account before clearing local presentation state.
  func deleteAccount() async {
    guard !access.locked, !isBusy, mode == .remote, let remote else { return }
    isBusy = true
    defer { isBusy = false }
    deletionPending = true
    do {
      try await remote.deleteAccount()
      if usingIdentity, let identitySession { try await identitySession.clearLocal() }
      clear()
      message = "Your API paper account was deleted."
    } catch { await report(error) }
  }
  /// Remove private account information from memory when returning to the welcome screen.
  private func clear() {
    mode = .signedOut
    ledger = TradingLedger(cash: 0)
    assets = []
    indexes = []
    username = ""
    pending = nil
    message = nil
    usingIdentity = false
    deletionPending = false
  }
  /// Publish one coherent server snapshot rather than mixing balances from different requests.
  private func apply(_ data: AccountData) {
    ledger = data.ledger
    assets = data.assets
    indexes = data.indexes
    pending = data.pending
  }
  /// Translate failures into safe messages and require sign-in again when authorization is lost.
  private func report(_ error: Error) async {
    if let remote { pending = await remote.pending }
    if error as? TradingFailure == .http(401) || error as? TradingFailure == .missingSession {
      if let identitySession { try? await identitySession.clearLocal() }
      clear()
    }
    if let failure = error as? TradingFailure {
      message = failure.localizedDescription
    } else if error is CancellationError {
      message = "The request was interrupted. Check for an unconfirmed order before trying again."
    } else {
      message =
        "The operation could not be confirmed. Check your connection and retry. Unconfirmed orders retain their original ID."
    }
  }
}
