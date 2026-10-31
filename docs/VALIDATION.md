# Validation evidence

Validated in the Linux cloud workspace on 31 October 2026. This evidence covers native Swift domain/data code and the reference backend. It does not establish a compiled or running SwiftUI app.

| Check | Result |
| --- | --- |
| Swift 6 core debug and optimized Release compilation | Passed, official `swift:6.1.3-bookworm` container |
| XCTest package suite with actual backend | **25 tests passed, 0 failures, 0 skipped** |
| Real HTTP account contract | Passed: signup, catalog/index decoding, watchlist, buy/sell, server rejection, logout/login, persisted history, isolation, deletion and refusal to follow redirects |
| Domain and storage coverage | Buy/sell arithmetic, affordability boundaries, bad quantities, nonfinite cash, search/sector/sort, disk restart persistence, preserved corrupt data |
| Failure-path coverage | Lost POST response, failed post-order snapshot, same UUID after restart, account/origin scoping, rejection versus unauthorized retention, disk failure before POST, expired session, concurrent-operation guard, live-execution rejection |
| JWT gateway security tests | **12 passed**, one upstream TestClient deprecation warning |
| Release configuration guard tests | **4 passed** |
| Gateway container | Built locked dependencies with TLS enabled; after fixing copied-file permissions, non-root/read-only startup passed, health returned `ok` and seven assets decoded |
| Reference backend's Python tests (previous milestone) | **11 passed**; original backend remains pinned |
| Xcode project/resources | OpenStep parser accepted project and identity xcconfig bindings; Face ID text, callback schemes, Debug-only HTTP allowance, privacy/export plists, asset JSON and shared scheme passed structural checks |
| iOS Swift syntax | Swift frontend parse passed for Debug/Release app/security sources and presentation/UI tests; parsing does not type-check SwiftUI, Security or LocalAuthentication |
| Xcode simulator build, presentation tests, UI tests, device Release/archive | **Not run: macOS/Xcode unavailable** |
| OAuth protocol regression tests | **9 of the 25 Swift tests** cover callback/state, claims, refresh rotation, revoked refresh, sign-out, form encoding, cleared-session race, subject preservation and missing refresh receipt |
| Real Google/Facebook/Apple/SMS, live issuer JWKS/management APIs, Keychain and biometrics | **Not run: provider accounts/configuration and Apple runtime unavailable** |
| GitHub CI, TestFlight, device accessibility/performance, production HTTPS | **Not run from this workspace** |

Reference mobile commit: `eab65359c530f02a387c327e8b2921d47f41d10c`.
Backend used for real HTTP testing: `7bac27ca60fe799a40ec9a11bec7b04d8ff78317` from `pk-debug/northstar-backend-lab` with its locked Python dependencies in Python 3.12. Its first test invocation lacked the documented `PYTHONPATH`; rerunning with `/backend` and a separate disposable bootstrap database passed all 11 tests.

The final package run supplied `NORTHSTAR_TEST_API=http://127.0.0.1:8000`, so the HTTP contract actually executed. Without that variable it reports an explicit skip; this is not equivalent evidence. Swift's runner also prints a separate zero-test Swift Testing footer because this package uses XCTest. The XCTest summary above is the executed suite. App-target presentation tests use Swift Testing and require Xcode.

## Reproduce

Run the disposable backend as described in [API.md](API.md), then from the mobile checkout run:

```sh
NORTHSTAR_TEST_API=http://127.0.0.1:8000 swift test
```

In this Linux workspace, Swift was run in the official Swift container and shared the disposable Python backend container's network namespace for loopback HTTP. No host networking, disabled TLS verification or production credentials were used. The official Swift image resolved to `sha256:fc875c5f6fda1703bb1086e3f93a7dee27e89471d51b089003eab7b4bfbd2c42`. Backend state was disposable.

On macOS, run the shared Xcode scheme as documented in README and complete [RELEASE.md](RELEASE.md). Until those gates pass, do not call the native app App Store ready.


## Authentication extension evidence

The JWT gateway tests use **real temporary RSA signatures**, not a client-supplied decoded JSON object. They reject forged signatures, HS256 algorithm substitution, expired/wrong-issuer/wrong-audience tokens and missing authentication. They verify isolated accounts, absent legacy auth endpoints, deletion tombstones, failure reporting, suspension while deletion is pending and durable recovery jobs. The Swift OAuth tests use fake HTTP responses to test the client protocol; these are not proof of live provider configuration.

The full Swift run used the real pinned original backend, so its HTTP test did not skip. The first run of the new gateway tests exposed copied FastAPI routes still binding legacy dependencies; rebuilding them through a router fixed the boundary, and the final 12 tests passed. A direct sandboxed TestClient invocation could not use its event-loop sockets; tests completed with permitted local event-loop access. The first non-root Docker startup also exposed restrictive copied-file permissions; the Dockerfile now normalizes readable source permissions, and functional startup passed afterward. These corrections are reflected in the checked-in code.

No actual provider credentials, SMS delivery charges, Apple certificates or production host were used. No signed IPA, App Store upload or App Review approval was produced. Read [AUTHENTICATION.md](AUTHENTICATION.md) and [RELEASE.md](RELEASE.md) before enabling hosted accounts publicly.
