# Northstar iOS

Northstar is a small sample investing app built with native SwiftUI. It is a learning project: the prices are examples, and buying or selling only changes a temporary demo account inside the app.

## If you just want to try the app

1. Open `stocktradingios.xcodeproj` in Xcode.
2. Pick the `stocktradingios` scheme and an iPhone simulator.
3. Press **Run** (the triangle button).
4. Try the **Discover**, **Portfolio**, and **Activity** tabs.

You can search for a company or ticker, open an asset to see its sample chart, and simulate a whole-share buy or sale. Accepted orders update the demo cash and holdings and appear in Activity. The app starts with **$12,450** of sample cash and three example holdings.

> **Demo only:** Nothing is sent to a broker or stock exchange, no real money moves, and these examples are not investment advice. The account and order history live in app memory and reset when the app is restarted.

## What the screens do

- **Discover** shows the sample account value, illustrative market indexes, and a searchable list of example stocks and an ETF.
- **Asset details** shows a hard-coded quote, a simple sample trend chart, company category, and the simulated order ticket.
- **Portfolio** shows cash, sample market value, estimated unrealized gain or loss, and the positions in the demo account.
- **Activity** lists the simulated orders or explains what will appear there after the first order.

## How the project is organized

The app uses a lightweight **MVVM + shared store** approach. SwiftUI views describe what appears on screen; view models handle screen-specific presentation calculations; and one observable store owns the account state and order rules. Keeping the order rules in the store means each screen displays the same account.

In everyday terms:

- A **model** describes information, such as a stock quote or a holding.
- A **view** draws the screen and connects buttons and text fields to app state.
- A **view model** prepares information a screen needs, such as matching search results or portfolio totals.
- The **store** is the shared demo account ledger. It checks an order before it updates cash, holdings, and activity.

The order path is: tap **Simulate buy/sell** → enter a whole number of shares → the store checks the sample asset, available cash or shares, and quantity → the screen shows a clear result. Rejected orders leave the account unchanged.

```text
stocktradingios/
  ContentView.swift                   App entry screen and shared tab/store setup
  Models/MarketModels.swift           Asset, index, position, and order data
  Stores/TradingStore.swift           Demo cash, holdings, validation, and order updates
  ViewModels/TradingViewModels.swift  Search and portfolio display calculations
  TradingScreens.swift                Discover, details, portfolio, and activity UI
  TradingStyle.swift                  Shared colors for the SwiftUI screens
stocktradingiosTests/
  stocktradingiosTests.swift          Tests for simulated-order behavior
```

### A simple way to follow the code

1. Start at `stocktradingios/ContentView.swift` to see how the tabs share one `TradingStore`.
2. Read `stocktradingios/Models/MarketModels.swift` for the data shapes and sample stock list.
3. Read `stocktradingios/TradingScreens.swift` to see what each screen displays and which user actions it offers.
4. Follow a buy or sell button to `stocktradingios/Stores/TradingStore.swift`. The store validates the order before changing cash, positions, or activity.
5. Look at `stocktradingios/ViewModels/TradingViewModels.swift` for search and portfolio calculations.
6. Read `stocktradingiosTests/stocktradingiosTests.swift` for examples of accepted and rejected orders.

## Build and test

Open the project in Xcode and run the `stocktradingios` scheme on an iOS simulator or device. From Terminal, you can build and run the tests on an installed iOS simulator with:

```sh
xcodebuild test \
  -project stocktradingios.xcodeproj \
  -scheme stocktradingios \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

The project currently targets **iOS 26.5 or later**, matching the simulator configuration used for development.

## Project limits and next steps

This is a local learning demo, not a financial product. Quotes and index values are fixed examples. Orders are not persisted and do not execute outside the app. A production app would need a trusted backend for market data and account records, strong authentication, real order validation and auditing, and appropriate legal and compliance review.
