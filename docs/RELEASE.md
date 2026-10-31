# Release gates before App Store submission

This implementation prepares a native paper-trading product for review. It does not establish App Store approval or production readiness. The default app is free, offline paper practice; no payments or in-app purchase are implemented. Choose and disclose a future business model before adding monetization.

## Required product and backend decisions

- Provide the production HTTPS origin if shipping API accounts. Deploy the matching authenticated v2 service with persistent storage, controlled schema migrations, backups, rate limits, monitoring and an incident plan. Never ship the unsecured v1 lab ledger.
- Choose a unique production bundle identifier and your own signing team, configure distribution signing/provisioning, and verify the export-compliance answer. Current project signing settings and example bundle identifiers are development placeholders.
- Publish a real privacy-policy URL and support URL in App Store Connect. Describe optional API usernames, credentials, watchlists and simulated transactions, hosting/retention/deletion, and local storage. Reconcile the included privacy manifest and App Privacy answers with the exact shipped backend and SDKs. No tracking SDK is included.
- API accounts have in-app permanent deletion with a confirmation. Test revocation, server cascade deletion and offline/error behavior on the production deployment. Hosted password recovery requires provider configuration; the original service has none. Passkeys are not implemented here. Test the device-owner app lock and rotating JWT lifecycle.
- Describe synthetic data, virtual money and absence of brokerage prominently in metadata, onboarding and review notes. Supply App Review a working review path (offline mode and, if needed, test API credentials securely through App Store Connect). Do not claim financial returns, exchange connectivity or investment advice.

## macOS and device verification still required

- Run the shared Xcode scheme's build, presentation tests and XCUITests on a supported simulator; build Release for a generic device and archive with your team. The macOS CI definition has not run from this workspace.
- Verify iPhone small/large displays, iPad split view, portrait/landscape, dark/light appearance, increased contrast, Reduce Motion and the largest accessibility text sizes. Native controls and semantic colors are a baseline, not proof of accessibility.
- Use Accessibility Inspector and VoiceOver for labels, reading/focus order, order review, retry errors and destructive deletion. Test keyboard input, password autofill and hardware-keyboard navigation.
- Use an RTL pseudolanguage and a long-string pseudolanguage. An English source string catalog is included and Xcode extraction can populate remaining literals. Complete catalog coverage and reviewed translations are future localization work. INR formatting intentionally follows the Indian market locale; dates use system formatting.
- Exercise real network loss before POST, after commit and during snapshot, then force quit/relaunch and confirm retry ID preservation. Check expired sessions, rate limits and server errors. Confirm no credentials enter logs, files, analytics or app-switcher screenshots.
- Profile startup, scrolling, memory and navigation with Instruments (Time Profiler, Allocations, Leaks) on devices. No performance numbers are claimed here. The app has no polling loop, streaming connection or background queue.
- Verify icon appearance on devices, archive resources/privacy report, signing, version/build numbers and export-compliance settings. The original Northstar icon from the reference app is included.
- Distribute through TestFlight, gather accessibility/usability feedback, and check crash reports before submission. Only publish after the above gates pass.

## CI and contribution workflow

The workflow runs package tests against a pinned real backend on Linux, and package/Xcode/simulator/Release checks on macOS. External repository checkout assumes CI can read `pk-debug/northstar-backend-lab`; private cross-repository access needs an appropriately scoped CI credential. Do not embed one in this app. Configure required branch checks and review changes through a feature branch/PR. Source changes and any Git push are separate from deployment, signing and App Store submission; no store submission is automated here.


## Identity and biometric release configuration

Use [AUTHENTICATION.md](AUTHENTICATION.md) as the provider setup checklist. Register the final bundle-ID callback, RS256 audience, native/public client, enabled social/SMS connections and rotating refresh policy. Supply account-deletion management credentials on the server only. For Apple, verify grant/token revocation in addition to hosted-profile deletion. Do not release a selected provider using development dashboard keys or untested callbacks. Check live provider/SMS pricing and abuse/spend limits before enabling phone login publicly.

Both Info.plists include `NSFaceIDUsageDescription` and a callback scheme derived from `PRODUCT_BUNDLE_IDENTIFIER`. Debug alone has `NSAllowsLocalNetworking`; Release uses `Configuration/ReleaseInfo.plist`. The private app Keychain does not require sharing entitlements. The current Apple flow is broker-hosted web authentication, not a native Apple authorization flow; configure its developer identifiers/Services ID and broker callback accordingly rather than adding an unused entitlement.

Test Face ID on a supported iPhone, Touch ID on supported hardware, device-passcode fallback, no enrollment, biometric lockout, changed enrollment, cancellation, backgrounding during prompts and reinstall behavior. Verify a background/in-flight browser or refresh result never bypasses the local lock or revives a cleared session. Verify signing-out erases Keychain receipts even after network failure. Test the hosted deletion recovery worker across process restarts/provider outages and verify queued accounts cannot keep trading.

## Archive and export

The checked-in bundle identifier remains an example and the signing team must be yours. Set both in Xcode before exporting. Then on macOS run:

```sh
bash scripts/archive_release.sh
# For an intentionally offline-only build:
bash scripts/archive_release.sh --offline-only
```

The script reads resolved Release settings, runs `scripts/validate_release.py`, creates `output/Northstar.xcarchive` and exports using `Configuration/ExportOptions.plist`. It never uploads or publishes. Local signing certificates/profiles, Apple Developer membership, App Store Connect app record, privacy/support URLs, screenshots, age/category/export compliance, review credentials and TestFlight are still your deployment prerequisites. The validator catches common missing files, example IDs, HTTP allowances and missing hosted settings/Apple connection; it cannot prove provider connectivity, entitlement approval or review compliance.
