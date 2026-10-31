# Northstar — learn native iOS by building a paper-trading app

Northstar is a SwiftUI investing **practice** app. You explore sample Indian stocks, keep a watchlist, buy/sell with virtual rupees, and learn how an account changes after a trade. Prices are invented. There is no real money, live exchange feed, deposit, broker connection or investment advice.

The project also demonstrates how a native iOS application separates screens, business rules, storage, networking and identity. Product behavior comes from [the original KMP app](https://github.com/pk-debug/kmpNativeUiTrading/tree/eab65359c530f02a387c327e8b2921d47f41d10c); the implementation here is Swift, with no Kotlin runtime.

## Start without paying for an identity provider

Open `stocktradingios.xcodeproj` in Xcode 16+ with Swift 6 and an iOS 18+ simulator. Choose the shared `stocktradingios` scheme and run.

- **Enter offline demo:** start with ₹10 lakh and example holdings. Orders and watchlists stay on this device and survive restart.
- **Local-server signup/login:** start the original backend using [API.md](docs/API.md). Debug points to `http://localhost:8000`; the iOS Simulator shares your Mac's localhost. Create a username/password account with its own virtual ledger. This path needs no third-party identity provider.
- **Device app lock:** on an enrolled device, enable Face ID or Touch ID in Account → Device security. The device passcode is the recovery option. Biometrics unlock local access; they do not create a server account.

A physical phone does not share your Mac's localhost. Use a reachable HTTPS development host for device API tests. Debug permits HTTP only for localhost/127.0.0.1; Release does not use the local-network allowance.

## Login, signup and JWT sessions

The app includes a hosted sign-in path for email, Google, Facebook, mobile/SMS and Apple. A configurable **Auth0-compatible identity service** handles password entry, provider consent, phone-number entry and SMS verification in Apple's system browser. The app uses Authorization Code + PKCE, exact callback/state checks, device-only, passcode-protected Keychain storage and rotating refresh tokens. The companion gateway verifies JWT signatures and isolates each account.

**Provider configuration is still required.** Social/SMS authentication is not something an app can securely enable by inventing a key or accepting a phone number. Edit the public settings in [Identity.xcconfig](Configuration/Identity.xcconfig), register the provider/callbacks, and deploy the [JWT gateway](backend-auth/README.md). Secrets remain in the provider dashboard/server, never in the mobile app. Empty connections are hidden in Release; Debug explains unconfigured options.

[Authentication setup](docs/AUTHENTICATION.md) explains the exact settings, provider registrations, Apple requirements, pricing tradeoffs and limitations. Start with local login; enable social accounts when needed and SMS last, with spend/rate limits. No paid provider is needed just to learn or run the current local app. No live pricing or free-tier guarantee is claimed.

## What the app does

| Area | Behavior |
| --- | --- |
| Discover | Company/ticker search, sector filters, alphabetical/gainer/loser sorting and illustrative indexes |
| Details/watchlist | Synthetic quote, illustrative trend, owned shares and persistent add/remove |
| Orders | Whole-share paper buy/sell, integer-paise preview, explicit review/confirmation and server authorization |
| Reliability | Durable same-UUID retry after an uncertain result or restart; no silent order queue |
| Portfolio/activity | Cash, cost basis, market value, unrealized P/L and completed paper orders |
| Identity/security | Separate login/signup, optional hosted providers, JWT renewal, Keychain, device-owner lock and privacy cover |
| Account deletion | In-app request; hosted gateway persists deletion jobs, suspends access and retries provider failures |
| Learning | Native expandable lessons about orders, diversification and costs |

See [feature mapping](docs/FEATURES.md) for the reference implementation and unsupported product features.

## Understand the code, even if you are new to iOS

Start at [the beginner code tour](docs/CODE_TOUR.md). It explains every source/configuration file and walks through one buy, one login and one unlock. Source files have introductory documentation and comments at trust boundaries. Comments explain **why** a step exists; normal Swift syntax is explained once rather than repeating an inaccurate translation above every line.

A useful reading order is:

1. `stocktradingiosApp.swift`: create one shared account and lock.
2. `ContentView.swift`: choose locked, signed-out or account screens.
3. `TradingScreens.swift`: collect user input and render state.
4. `TradingStore.swift`: coordinate the requested action.
5. `NorthstarCore`: calculate rules, save data and call the API.
6. `Security`: use Apple's browser, Keychain and local authentication.

[Architecture and interview notes](docs/ARCHITECTURE.md) connect these ideas to Android/Flutter, explain actor reentrancy and identify the security decisions you should be able to defend.

## Test and inspect evidence

```sh
swift test
python3 -m unittest discover -s scripts/tests
```

The Swift core has no third-party package dependency. The real HTTP contract test explicitly skips unless `NORTHSTAR_TEST_API` points to a disposable original backend. To run it, start the server from [API.md](docs/API.md), then use `NORTHSTAR_TEST_API=http://127.0.0.1:8000 swift test`.

JWT gateway tests use the pinned backend plus `backend-auth/requirements.lock`; see its README. They generate temporary RSA keys and test forgery, issuer/audience/expiry failures, account isolation and durable deletion recovery. They do not send paid SMS or pretend to log into real Google/Facebook accounts.

On macOS, choose an installed simulator and run:

```sh
xcodebuild test -project stocktradingios.xcodeproj -scheme stocktradingios \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro'
```

[Validation evidence](docs/VALIDATION.md) separates executed tests from unrun Xcode, Keychain, biometric, provider and device checks. Linux cannot prove SwiftUI compilation or App Store readiness. GitHub CI includes Linux core/gateway tests and macOS simulator/Release gates; adding the workflow is not evidence it has passed.

## Prepare an App Store build

Set your unique production bundle ID and development team. Configure Release HTTPS origins and callbacks, privacy/support URLs, enabled identity providers, account deletion/revocation and App Store metadata. Review [the release guide](docs/RELEASE.md) before submitting.

The repository includes Debug/Release Info.plists, Face ID purpose text, callback URL registration, icon, privacy manifest, source string catalog, shared scheme, export options and a release-settings validator. On a configured Mac, `bash scripts/archive_release.sh` validates settings, archives and exports an IPA. It **does not upload or publish**. `--offline-only` explicitly selects an offline-only archive without hosted identity settings.

These files remove common configuration omissions; they cannot supply your signing identity, provider approvals, SMS budget or App Review approval. Complete device testing and TestFlight before describing this as a production release.
