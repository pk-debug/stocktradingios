/// stocktradingiosApp.swift is the front door. It creates exactly one account and
/// lock for the running app, so two iPad windows cannot rotate one token twice.
import SwiftUI

@main
struct stocktradingiosApp: App {
  @StateObject private var access: AppAccess
  @StateObject private var trading: TradingStore

  init() {
    let access = AppAccess()
    _access = StateObject(wrappedValue: access)
    _trading = StateObject(wrappedValue: TradingStore(access: access))
  }

  var body: some Scene {
    WindowGroup {
      ContentView()
        .environmentObject(access)
        .environmentObject(trading)
    }
  }
}
