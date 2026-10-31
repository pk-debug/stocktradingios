# Validation evidence

Validated in the Linux cloud workspace on 31 October 2026. This evidence covers native Swift domain/data code and the reference backend. It does not establish a compiled or running SwiftUI app.

| Check | Result |
| --- | --- |
| Swift 6 core debug and optimized Release compilation | Passed, official `swift:6.1.3-bookworm` container |
| XCTest package suite with actual backend | **16 tests passed, 0 failures, 0 skipped** |
| Real HTTP account contract | Passed: signup, catalog/index decoding, watchlist, buy/sell, server rejection, logout/login, persisted history, isolation, deletion and refusal to follow redirects |
| Domain and storage coverage | Buy/sell arithmetic, affordability boundaries, bad quantities, nonfinite cash, search/sector/sort, disk restart persistence, preserved corrupt data |
| Failure-path coverage | Lost POST response, failed post-order snapshot, same UUID after restart, account/origin scoping, rejection versus unauthorized retention, disk failure before POST, expired session, concurrent-operation guard, live-execution rejection |
| Reference backend's Python tests | **11 passed**, one upstream TestClient deprecation warning |
| Xcode project/resources | OpenStep parser accepted project and package-product references; asset JSON, privacy/debug plists and shared scheme parsed |
| iOS Swift syntax | Swift frontend parse passed for app, presentation tests and UI tests; parsing does not type-check SwiftUI |
| Xcode simulator build, presentation tests, UI tests, device Release/archive | **Not run: macOS/Xcode unavailable** |
| GitHub CI, TestFlight, device accessibility/performance, production HTTPS | **Not run** |

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
