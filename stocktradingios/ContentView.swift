import SwiftUI

struct ContentView: View {
    @StateObject private var trading = TradingStore()
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        Group {
            if trading.mode == .signedOut {
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
                ZStack { Color(.systemBackground).ignoresSafeArea(); Label("Northstar", systemImage: "sparkles").font(.title) }
                    .accessibilityHidden(true)
            }
        }
        .tint(TradingStyle.green)
        .environmentObject(trading)
    }
}

#Preview { ContentView() }
