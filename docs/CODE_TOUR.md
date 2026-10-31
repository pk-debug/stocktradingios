# Read this app like a small story

You do not need a finance degree or years of Swift experience. Imagine a school shop with pretend money. A screen is the counter, a store coordinates requests, rules check what is allowed, storage is a notebook, and the API is a separate cashier who owns online balances.

## Six Swift ideas you will see everywhere

- `struct` describes a value, like a stock quote. `class` describes an object with a shared lifetime. `actor` describes an object whose state is protected from simultaneous access.
- `let` means the value cannot be reassigned. `var` means it can change. `String?` means a string may be missing; `guard let` safely unwraps it before continuing.
- `@State` belongs to one screen, such as typed search text. `@Published` tells observing screens that shared state changed. `@StateObject` owns an observable object's lifetime; `@EnvironmentObject` reads the shared object.
- `@MainActor` keeps screen-state changes on the UI actor. It does not mean the network blocks the screen. `await` suspends while another task does work; `throws`, `do` and `catch` describe failures.
- `guard` is an early checkpoint. `defer` schedules cleanup when a function exits, including on failure. For example, a busy flag is reset even if a request throws.
- `Codable` turns agreed data shapes into/from JSON. `Sendable` declares data safe to move across concurrency boundaries. A `protocol` is a contract that real and fake implementations can both satisfy.

Comments in the source explain important decisions near the code. Start with a file's introduction, then read the named function you are following. Do not assume that every helper executes in file order; callers choose which functions run.

## App and screen files

| File | Job and what to notice |
| --- | --- |
| `stocktradingios/stocktradingiosApp.swift` | Entry point, marked `@main`. It creates one `AppAccess` and `TradingStore`, then supplies them to every window. Sharing avoids two windows renewing the same refresh token independently. |
| `stocktradingios/ContentView.swift` | Chooses the lock screen, uncertain-deletion screen, login or tabs. A privacy cover hides inactive scenes. Background transitions lock access. Session restoration waits until the device lock opens. |
| `stocktradingios/TradingScreens.swift` | Native forms/lists. `LoginView` separates login/signup and provider choices. `StatusSection` shows progress/errors/retry. `DiscoverView`, `AssetDetailView` and `WatchlistView` browse assets. `OrderTicketView` separates input from confirmation. `PortfolioView` and `ActivityView` render snapshots. `AccountView` manages learning/security/deletion; `PrivacyView` explains limits. `Sparkline` draws a sample shape. |
| `stocktradingios/Stores/TradingStore.swift` | Main-actor coordinator. It checks the shared lock/busy/deletion state, calls the right account service, and publishes confirmed results. `report` maps failures to safe messages rather than exposing raw server bodies. |
| `stocktradingios/TradingStyle.swift` | Semantic accent/trend colors; system appearance and text remain usable in dark mode. |
| `stocktradingios/ViewModels/TradingViewModels.swift` | A display-only rupee formatter. Changing number presentation never changes money in the ledger. |

## Identity and device security files

| File | Job and what to notice |
| --- | --- |
| `stocktradingios/Security/AppAccess.swift` | Uses LocalAuthentication to ask iOS to verify the device owner. Face/fingerprint data never enters the app. A user-presence Keychain item remembers that app lock is enabled. A generation number prevents a late unlock response overriding a newer background lock. |
| `stocktradingios/Security/BrowserSignIn.swift` | Generates random state/verifier, hashes the verifier with Apple's SHA-256 implementation, opens `ASWebAuthenticationSession`, checks the callback and exchanges its one-use code. The browser is retained until completion. |
| `stocktradingios/Security/KeychainVault.swift` | Stores OAuth tokens in Keychain, device-only, requiring a device passcode and an unlocked device. Updating an existing item avoids deleting a receipt before its replacement can be saved. Passwords are never stored. |
| `Sources/NorthstarCore/IdentitySession.swift` | Public configuration, authorization URL/callback rules, local claim inspection and token renewal. `exchange` trades a code for tokens; `restore` reads the secure receipt; `validAccessToken` renews near expiry; `signOut` erases and revokes. Generation checks prevent an in-flight login reviving a cleared session. JWT decoding here is not signature verification. |

## The reusable Swift package

| File | Job and what to notice |
| --- | --- |
| `Package.swift` | Declares the `NorthstarCore` library and package tests. No third-party Swift package is required. The app links this local package through Xcode. |
| `Sources/NorthstarCore/MarketModels.swift` | Shared shapes for stocks, indexes, positions and paper-order receipts. `MarketData` is an invented catalog for offline practice. `Codable` also permits real API JSON to be decoded into the same shapes. |
| `Sources/NorthstarCore/TradingDomain.swift` | Pure discovery/sorting, ledger shapes, paise-based previews and local order validation. `TradingRules` changes a copy of the ledger after checks succeed. `ExecutionPolicy` rejects live execution. `LearningLesson` contains plain educational text. |
| `Sources/NorthstarCore/AccountStorage.swift` | Ordinary account storage contract, file/in-memory implementations and the offline repository. Disk work belongs to actors; writes are atomic and excluded from backup. OAuth tokens must not be put here. |
| `Sources/NorthstarCore/TradingAPI.swift` | `HTTPTransport` separates networking from tests. `URLSessionTransport` uses deadlines and refuses redirects. `RemoteAccount` owns the API session and journal. An explicit busy flag spans suspension points because actors can admit other calls while awaiting. |

## Server-side JWT companion

| File | Job and what to notice |
| --- | --- |
| `backend-auth/identity_gateway.py` | Adds a verified identity boundary to the pinned paper backend. `Settings` validates the issuer. `JWTVerifier` verifies RS256 with trusted public keys. The app factory binds trading routes to that verifier. Account subjects map to isolated ledgers. Deletion jobs are durable and retried; tombstones prevent old JWTs recreating deleted accounts. |
| `backend-auth/requirements.txt` | Describes the added JWT/cryptography dependency range for maintainers. |
| `backend-auth/requirements.lock` | Exact tested Python dependencies for reproducible gateway builds, including the original backend's dependencies. These are package versions, not secrets. |
| `backend-auth/.env.example` | Variable names and safe examples. Real management secrets go in ignored local/hosting configuration, not this file or iOS. |
| `backend-auth/Dockerfile` | Installs locked dependencies, copies the pinned application/gateway and runs as a non-root user. Optional proxy CA mounts preserve TLS in managed builds. |
| `backend-auth/compose.yml` | Runs the service locally with persistent database storage, loopback binding and a read-only root filesystem. It does not provide public HTTPS. |
| `backend-auth/README.md` | Exact checkout/start/test steps and operational/deletion limitations. |

## Tests are executable explanations

| File | What it proves |
| --- | --- |
| `Tests/NorthstarCoreTests/TradingTests.swift` | Accepted/rejected orders, integer-paise boundaries, discovery, persistence and uncertain-order retry. Fake HTTP/storage let failure paths be reproduced on purpose. |
| `Tests/NorthstarCoreTests/IdentityTests.swift` | Exact callback/state rules, local claim checks, refresh rotation/revocation and form encoding. Fake JWTs here are deliberately not cryptographic proof; the server tests cover signatures. |
| `Tests/NorthstarCoreTests/BackendContractTests.swift` | Real HTTP compatibility with a disposable original backend. A missing server produces an explicit skip. |
| `stocktradingiosTests/stocktradingiosTests.swift` | Main-actor presentation behavior without reading the user's saved account or real Keychain. Requires an Xcode test host. |
| `stocktradingiosUITests/stocktradingiosUITests.swift` | Simulator/device taps for reviewed orders, restart persistence and large-text navigation. Test-only fixture storage is separate from real account files. |
| `backend-auth/tests/test_identity_gateway.py` | Temporary real RSA keys verify that forged, expired or wrong-purpose JWTs fail. Also exercises isolation, deleted-account tombstones and recovery jobs. |
| `scripts/tests/test_release.py` | Confirms that common Debug/HTTP/placeholder-signing mistakes are rejected by the release guard. |

## Build, deployment and resource files

| File or group | Why it exists |
| --- | --- |
| `Configuration/Identity.xcconfig` | One place for public issuer/client/audience and enabled provider connection names. No secret belongs in it. |
| `Configuration/DebugInfo.plist` | Face ID reason and callback scheme plus Debug-only local networking permission. |
| `Configuration/ReleaseInfo.plist` | Face ID reason and callback scheme without the local HTTP allowance. |
| `Configuration/ExportOptions.plist` | Tells Xcode to export an App Store Connect IPA using automatic signing; your archive still needs your real signing team. |
| `scripts/validate_release.py` | Reads resolved Xcode settings and rejects known configuration omissions. It does not contact identity providers or certify security/compliance. |
| `scripts/archive_release.sh` | Runs the guard, archives and exports. It never uploads or publishes. |
| `.github/workflows/quality.yml` | Runs package/API/gateway checks on Linux and Xcode/simulator/Release checks on macOS when GitHub executes it. |
| `stocktradingios.xcodeproj/project.pbxproj` | Xcode's target, build-setting, resource and local-package wiring. Avoid editing object IDs casually. |
| `stocktradingios.xcodeproj/xcshareddata/xcschemes/stocktradingios.xcscheme` | The shared run/test/archive plan used by developers and CI. |
| `stocktradingios.xcodeproj/project.xcworkspace/contents.xcworkspacedata` | Xcode workspace structure. Existing `xcuserdata` breakpoint/scheme files are personal editor metadata, not application logic or deployment credentials. |
| `stocktradingios/Assets.xcassets/**/Contents.json` | Xcode asset descriptions. JSON does not permit docstrings; its keys describe author/version, appearance, filename and image size. |
| `stocktradingios/Assets.xcassets/AppIcon.appiconset/AppIcon.png` | The original Northstar icon from the reference application. |
| `stocktradingios/Localizable.xcstrings` | English source string catalog. More coverage/translations and RTL testing remain work before claiming multilingual support. |
| `stocktradingios/PrivacyInfo.xcprivacy` | Machine-readable privacy declarations. They must match the providers, backend and SDKs actually shipped. |
| `.gitignore` | Keeps build output, databases, environments and secret `.env` files out of version control. |
| `.dockerignore` | Keeps unrelated mobile files and local state out of the gateway build context. |

JSON, plist/XML and lockfiles cannot contain Swift docstrings. Their meanings are documented here rather than inserting invalid syntax. Repository Markdown files explain product scope, setup and evidence: `README` is the entry point; `API`, `AUTHENTICATION`, `ARCHITECTURE`, `FEATURES`, `RELEASE`, `VALIDATION` and this tour cover different questions.

## Follow three actions end to end

**Buy one share:** the ticket parses a whole number → `OrderPreview` checks price/cash in paise → the user reviews and confirms → the store checks the lock/busy state → offline rules save a new ledger, or the API saves an order UUID before POST → a confirmed snapshot updates the screens. A timeout retains the UUID; it is not proof of a failed trade.

**Log in with a provider:** the button selects a configured connection → the browser collects credentials/consent/OTP → the exact callback and random state are checked → PKCE proves the app started the flow → tokens enter Keychain → the API verifies the JWT signature → only then is an account shown. The app never grants itself access just because it can decode a JWT.

**Unlock the app:** backgrounding closes the local door → the user taps Unlock → iOS verifies a supported biometric or device passcode → the app reads a user-presence-protected Keychain item → a generation check confirms no newer background event happened → screens and account actions become available again.
