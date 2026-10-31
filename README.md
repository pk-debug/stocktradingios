# Northstar — native SwiftUI paper trading

A native iOS learning and interview project, porting the implemented product scope of [kmpNativeUiTrading](https://github.com/pk-debug/kmpNativeUiTrading/tree/eab65359c530f02a387c327e8b2921d47f41d10c) into Swift. SwiftUI renders the screens; a Swift 6 package owns domain rules, persistence and the same authenticated Northstar **v2** API contract.

**All prices are synthetic and all money is virtual. No live quotes, real brokerage, deposits or real-money orders.** This is a paper-trading app, not an App Store-ready financial service.

## Run on iPhone or iPad

Open `stocktradingios.xcodeproj` using Xcode 16+ with Swift 6 and an iOS 18+ SDK/simulator. Choose the shared `stocktradingios` scheme and run. The previous iOS 26.5 deployment target is now **iOS 18.0** to support more devices. Choose your own development team for a physical device.

Choose **Enter offline demo** for ₹10 lakh and three example holdings. Accepted orders, holdings and the watchlist survive restart in the app sandbox. No signup or password is required. Signing out hides the account without deleting the device-local ledger.

For **API paper accounts**, configure the app target's user-defined build setting `NORTHSTAR_API_ORIGIN` with your deployed HTTPS origin, for example `https://api.your-domain.com`. It is copied into the generated Info.plist. In an xcconfig, write `https:/$()/api.your-domain.com` because `//` starts a comment. There is no deployed API URL in the reference repository and none is invented here. An unset origin leaves offline mode available; a configured origin adds signup/sign-in. Each API account starts with ₹10 lakh and **no holdings**. Tokens and passwords are never saved; restarting requires signing in again.

Debug builds default to `http://localhost:8000` for iOS Simulator testing against the local server. Start the backend using [API.md](docs/API.md); the simulator uses your Mac’s loopback. Debug permits HTTP only for `localhost` and `127.0.0.1`, with `NSAllowsLocalNetworking` in a Debug-only plist. Release does not use that plist, has no HTTP exception and requires HTTPS for API accounts. Leave the Release origin unset for offline-only mode until hosting is ready.

## Implemented features

- Discover: company/ticker search, sector filtering, alphabetical/gainer/loser sorting, seven sample stocks and three indexes.
- Asset details: synthetic quote, sector/exchange, illustrative accessible chart, owned quantity and watchlist control.
- Watchlist: persistent offline or isolated server-backed add/remove.
- Orders: whole-share paper buys/sells, integer-paise affordability and cash preview, edit/review/confirm flow, server-authoritative API pricing and rejection.
- Reliability: durable account-and-origin-scoped UUID journal, explicit retry after an uncertain result or restart, new-order blocking while unresolved. No silent background order queue.
- Portfolio: cash, holdings, average cost, invested/market value and unrealized P/L. Activity shows completed orders (API: latest 500).
- Account: offline entry, API registration/login, expiring sessions, sign out and destructive confirmation for permanent API account deletion.
- Learning: expandable lessons on market orders, diversification and costs. Privacy and demo limitations are available before signup.
- Native foundation: semantic colors, Dynamic Type, native navigation/forms, SF Symbols, adaptable rows, VoiceOver descriptions, sandbox file protection, app-switcher privacy cover, icon, privacy manifest and CI definitions.

See the [feature parity map](docs/FEATURES.md), [API setup](docs/API.md), [Swift architecture and Android/Flutter learning guide](docs/ARCHITECTURE.md), [validation evidence](docs/VALIDATION.md), and [release gates](docs/RELEASE.md).

## Test

The core has no third-party dependencies and runs on Linux or macOS:

```sh
swift test
```

Without `NORTHSTAR_TEST_API`, the real HTTP contract test is explicitly **skipped**; the other tests still run. To exercise the actual server contract, start the disposable backend described in [API.md](docs/API.md), then run:

```sh
NORTHSTAR_TEST_API=http://127.0.0.1:8000 swift test
```

On macOS, choose an installed compatible simulator (`xcrun simctl list devices available`) and run:

```sh
xcodebuild test -project stocktradingios.xcodeproj -scheme stocktradingios \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro'
```

The repository includes presentation tests and UI journeys for review/confirmation, persistence, watchlist empty states and accessibility-sized navigation. Linux cannot compile SwiftUI or run the simulator; those checks remain a required macOS gate. CI is added but has not been executed in GitHub from this workspace.
