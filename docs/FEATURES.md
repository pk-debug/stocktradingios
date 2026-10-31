# Reference scope and Swift implementation

Reference inspected: `pk-debug/kmpNativeUiTrading` at `eab65359c530f02a387c327e8b2921d47f41d10c`, especially `docs/FEATURES.md`, the native iOS screens, domain use cases, `RemoteAccount` and its pending-order journal. Backend contract: `pk-debug/northstar-backend-lab` at `7bac27ca60fe799a40ec9a11bec7b04d8ff78317`.

| Reference capability | Native Swift location |
| --- | --- |
| Discovery, query, category, deterministic sorting | `Discovery` in `Sources/NorthstarCore/TradingDomain.swift`; `DiscoverView` |
| Quote/details and illustrative trend | `AssetDetailView`, `Sparkline`; Codable market catalog |
| Persistent watchlist, offline and API | `TradingStore.toggleWatch`, `DemoAccount`, `RemoteAccount.watch` |
| Whole-share preview, max buy, owned shares, paise amounts | `OrderPreview`, `TradingRules`, `OrderTicketView` |
| Review before submission | Ticket → Review → Confirm, with explicit edit action |
| Persistent offline ledger | `DemoAccount`, `FileAccountStorage` actor |
| Isolated API accounts and auth | `RemoteAccount`, `LoginView`, configurable HTTPS origin |
| Durable original-ID retry, restart recovery, no silent queue | `PendingOrder`, `RemoteAccount.submit/retry`, `StatusSection` |
| Portfolio/account value/P&L | `TradingStore` calculations, `PortfolioView` |
| Completed activity, latest 500 API orders | `ActivityView`, server snapshot |
| Shared lessons in native controls | `LearningLesson`, `AccountView` disclosure groups |
| Sign out, expiry, permanent deletion | `RemoteAccount`, `TradingStore`, `AccountView` |
| Explicit live execution rejection | `ExecutionPolicy`; tested before any network submission |
| iOS icon, privacy and build/test automation | Assets, `PrivacyInfo.xcprivacy`, shared scheme, `.github/workflows/quality.yml` |

Android artifacts, Compose screens and Kotlin interoperability are not needed by this iOS-only app. The domain is deliberately native Swift so it can be studied and tested independently of a Kotlin runtime.

As in the reference, there is no live feed, historical chart provider, derivatives/options, margin, IPOs, SIPs, deposits, KYC, broker routing, limit/stop orders, open-order cancellation, alerts, push notifications, biometric unlock, password recovery, taxes or real fee calculation. No UI advertises those unsupported capabilities. Real execution requires a separately designed backend/broker contract, permissions, audit trail and release review.
