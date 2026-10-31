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
    @Published var message: String?
    @Published private(set) var username = ""
    let apiOrigin: String?
    let configurationError: String?
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

    init(storage: (any AccountStorage)? = nil, origin: String? = nil) {
        let directory = URL.applicationSupportDirectory.appendingPathComponent("Northstar", isDirectory: true)
        let resolvedStorage: any AccountStorage
        #if DEBUG
        if storage == nil && ProcessInfo.processInfo.arguments.contains("--ui-testing") {
            let testDirectory = URL.temporaryDirectory.appendingPathComponent("NorthstarUITests", isDirectory: true)
            if ProcessInfo.processInfo.arguments.contains("--reset-ui-data") { try? FileManager.default.removeItem(at: testDirectory) }
            resolvedStorage = FileAccountStorage(directory: testDirectory)
        } else { resolvedStorage = storage ?? FileAccountStorage(directory: directory) }
        #else
        resolvedStorage = storage ?? FileAccountStorage(directory: directory)
        #endif
        let storage = resolvedStorage
        demo = DemoAccount(storage: storage)
        let configured = origin ?? Bundle.main.object(forInfoDictionaryKey: "NORTHSTAR_API_ORIGIN") as? String
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
                configurationError = "The API origin is invalid. Use HTTPS, or a Debug-only localhost origin."
            }
        } else { remote = nil; configurationError = nil }
    }

    func asset(_ symbol: String) -> MarketAsset? { assets.first { $0.symbol == symbol } }
    func preview(asset: MarketAsset, side: OrderSide, quantity: Int) -> OrderPreview {
        OrderPreview(asset: asset, side: side, quantity: quantity, ledger: ledger)
    }
    func enterOffline() async {
        guard !isBusy else { return }
        isBusy = true; defer { isBusy = false }
        do {
            let loaded = try await demo.load()
            ledger = loaded; assets = MarketData.assets; indexes = MarketData.indexes
            mode = .offline; pending = nil; message = nil
        } catch { message = "The saved demo account could not be read. Your saved file has been preserved." }
    }
    func authenticate(username: String, password: String, register: Bool) async {
        guard !isBusy, let remote else { return }
        isBusy = true; defer { isBusy = false }
        do {
            try await remote.authenticate(username: username, password: password, register: register)
            let data = try await remote.load()
            self.username = username.lowercased()
            apply(data); mode = .remote; message = nil
        } catch { await report(error) }
    }
    func refresh() async {
        guard mode == .remote, !isBusy, let remote else { return }
        isBusy = true; defer { isBusy = false }
        do { apply(try await remote.load()); message = nil }
        catch { await report(error) }
    }
    /// No optimistic ledger changes: a save/server snapshot must succeed first.
    func placeOrder(asset: MarketAsset, side: OrderSide, quantity: Int) async -> Bool {
        guard !isBusy, mode != .signedOut, pending == nil else { return false }
        isBusy = true; defer { isBusy = false }
        do {
            if mode == .remote, let remote {
                ledger = try await remote.submit(OrderRequest(symbol: asset.symbol, side: side, quantity: quantity))
                pending = await remote.pending
            } else {
                let updated = try TradingRules.placeOrder(ledger: ledger, asset: asset, side: side, quantity: quantity)
                try await demo.save(updated)
                ledger = updated
            }
            message = "Paper order completed. No real money moved."
            return true
        } catch { await report(error); return false }
    }
    func retryOrder() async {
        guard !isBusy, mode == .remote, let remote else { return }
        isBusy = true; defer { isBusy = false }
        do {
            ledger = try await remote.retry(); pending = await remote.pending
            message = "The original paper order was confirmed."
        } catch { await report(error) }
    }
    func toggleWatch(_ asset: MarketAsset) async {
        guard !isBusy, mode != .signedOut else { return }
        isBusy = true; defer { isBusy = false }
        let enabled = !ledger.watchlist.contains(asset.symbol)
        do {
            if mode == .remote, let remote { ledger = try await remote.watch(asset.symbol, enabled: enabled) }
            else {
                var updated = ledger
                updated.watchlist.removeAll { $0 == asset.symbol }
                if enabled { updated.watchlist.append(asset.symbol) }
                try await demo.save(updated)
                ledger = updated
            }
            message = nil
        } catch { await report(error) }
    }
    func signOut() async {
        guard !isBusy else { return }
        isBusy = true; defer { isBusy = false }
        var warning: String?
        if mode == .remote, let remote {
            do { try await remote.signOut() }
            catch { warning = "Signed out on this device. Server revocation could not be confirmed; the session will expire automatically." }
        }
        clear(); message = warning
    }
    func deleteAccount() async {
        guard !isBusy, mode == .remote, let remote else { return }
        isBusy = true; defer { isBusy = false }
        do { try await remote.deleteAccount(); clear(); message = "Your API paper account was deleted." }
        catch { await report(error) }
    }
    private func clear() {
        mode = .signedOut; ledger = TradingLedger(cash: 0); assets = []; indexes = []
        username = ""; pending = nil; message = nil
    }
    private func apply(_ data: AccountData) {
        ledger = data.ledger; assets = data.assets; indexes = data.indexes; pending = data.pending
    }
    private func report(_ error: Error) async {
        if let remote { pending = await remote.pending }
        if error as? TradingFailure == .http(401) || error as? TradingFailure == .missingSession {
            clear()
        }
        if let failure = error as? TradingFailure { message = failure.localizedDescription }
        else if error is CancellationError { message = "The request was interrupted. Check for an unconfirmed order before trying again." }
        else { message = "The operation could not be confirmed. Check your connection and retry. Unconfirmed orders retain their original ID." }
    }
}
