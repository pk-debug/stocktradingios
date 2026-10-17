import SwiftUI

/// Creates the app's shared demo ledger and connects the three primary tabs.
struct ContentView: View {
    @StateObject private var trading = TradingStore()
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                DiscoverView()
            }
            .tabItem {
                Label("Discover", systemImage: "magnifyingglass")
            }
            .tag(0)

            NavigationStack {
                PortfolioView(onExplore: { selectedTab = 0 })
            }
            .tabItem {
                Label("Portfolio", systemImage: "chart.pie")
            }
            .tag(1)

            NavigationStack {
                ActivityView()
            }
            .tabItem {
                Label("Activity", systemImage: "clock.arrow.circlepath")
            }
            .tag(2)
        }
        .tint(TradingStyle.green)
        .environmentObject(trading)
    }
}

#Preview {
    ContentView()
}
