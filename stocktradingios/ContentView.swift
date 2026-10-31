/// ContentView.swift reads the app-owned account and device lock, then chooses the visible screen.

import NorthstarCore
import SwiftUI

struct ContentView: View {
  @EnvironmentObject private var trading: TradingStore
  @EnvironmentObject private var access: AppAccess
  @Environment(\.scenePhase) private var scenePhase

  var body: some View {
    Group {
      if access.locked {
        AppLockedView()
      } else if trading.deletionPending {
        PendingDeletionView()
      } else if trading.mode == .signedOut {
        NavigationStack { LoginView() }
      } else {
        TabView {
          NavigationStack { DiscoverView() }
            .tabItem { Label("Discover", systemImage: "magnifyingglass") }
          NavigationStack { WatchlistView() }
            .tabItem { Label("Watchlist", systemImage: "star") }
          NavigationStack { PortfolioView() }
            .tabItem { Label("Portfolio", systemImage: "chart.pie") }
          NavigationStack { ActivityView() }
            .tabItem { Label("Activity", systemImage: "clock.arrow.circlepath") }
          NavigationStack { AccountView() }
            .tabItem { Label("Account", systemImage: "person.crop.circle") }
        }
      }
    }
    .overlay {
      if scenePhase != .active {
        ZStack {
          Color(.systemBackground).ignoresSafeArea()
          Label("Northstar", systemImage: "sparkles").font(.title)
        }
        .accessibilityHidden(true)
      }
    }
    .tint(TradingStyle.green)
    .task(id: access.locked) { if !access.locked { await trading.restoreIdentity() } }
    .onChange(of: scenePhase) { _, phase in if phase == .background { access.lock() } }
  }
}

#Preview {
  let access = AppAccess(ignoresKeychainForTests: true)
  ContentView().environmentObject(access)
    .environmentObject(TradingStore(storage: MemoryAccountStorage(), access: access))
}

/// No navigation or sign-out shortcut bypasses the device lock. iOS offers the
/// device passcode if Face ID/Touch ID is unavailable, changed or locked out.
private struct AppLockedView: View {
  @EnvironmentObject private var access: AppAccess
  var body: some View {
    VStack(spacing: 24) {
      Image(systemName: "lock.shield").font(.largeTitle).accessibilityHidden(true)
      Text("Northstar is locked").font(.title.bold())
      Text("Use \(access.biometricName) or your device passcode to access your account.")
        .multilineTextAlignment(.center)
      if let error = access.error { Text(error).foregroundStyle(.red) }
      Button(access.authenticating ? "Unlocking…" : "Unlock Northstar") {
        Task { await access.unlock() }
      }
      .buttonStyle(.borderedProminent).disabled(access.authenticating)
      .accessibilityIdentifier("unlockApp")
    }.padding()
  }
}

/// An uncertain deletion suspends account interaction rather than letting the
/// user keep trading while a server-side deletion job may already be running.
private struct PendingDeletionView: View {
  @EnvironmentObject private var trading: TradingStore
  var body: some View {
    VStack(spacing: 20) {
      Text("Account deletion requested").font(.title.bold())
      Text(
        "Completion has not been confirmed. Your account may already be suspended. Retry confirmation or sign out; the hosted server keeps a durable deletion request."
      )
      if let message = trading.message { Text(message).font(.footnote) }
      Button("Retry deletion confirmation") { Task { await trading.deleteAccount() } }
      Button("Sign out") { Task { await trading.signOut() } }
    }.padding().disabled(trading.isBusy)
  }
}
