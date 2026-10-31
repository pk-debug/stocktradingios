# Same Northstar v2 API, native Swift client

There is no live market-data provider or deployed origin supplied by the source app. Its APIs belong to [northstar-backend-lab/paper-trading-api](https://github.com/pk-debug/northstar-backend-lab/tree/7bac27ca60fe799a40ec9a11bec7b04d8ff78317/paper-trading-api). The older unauthenticated USD `/api/v1` demos are not used.

| Method | Path | Purpose |
| --- | --- | --- |
| POST | `/api/v2/auth/register` | `{username,password}` → `{token,expiresAt}` |
| POST | `/api/v2/auth/login` | Same credential/session shape |
| POST | `/api/v2/auth/logout` | Revoke bearer session |
| GET | `/api/v2/assets` | Seven synthetic INR assets |
| GET | `/api/v2/indexes` | Three illustrative indexes |
| GET | `/api/v2/snapshot` | Atomic cash, positions, completed orders, watchlist, currency |
| POST | `/api/v2/orders` | `{symbol,side,quantity}`, `Idempotency-Key: UUID` |
| PUT / DELETE | `/api/v2/watchlist/{symbol}` | Add/remove selected stock |
| DELETE | `/api/v2/account` | Permanently delete account and related data |

Bearer auth selects the account. `expiresAt` is Unix seconds. Sides are `BUY`/`SELL`; order dates are ISO 8601 including fractional seconds. Snapshot currency must be INR. The server validates quantities, balances and ownership and persists the committed ledger. Passwords have 12–128 characters; usernames have 3–40 ASCII letters, numbers, dots, underscores or hyphens. Names normalize to lowercase.

## Local contract server

Clone the backend beside the app (or use another disposable checkout), then select the verified revision. Do not point tests at a production account store.

```sh
git clone https://github.com/pk-debug/northstar-backend-lab.git
cd northstar-backend-lab
git checkout 7bac27ca60fe799a40ec9a11bec7b04d8ff78317
python3.12 -m venv .venv
. .venv/bin/activate
pip install -r paper-trading-api/requirements.lock
NORTHSTAR_DB=/tmp/northstar-contract.sqlite3 uvicorn app.main:app \
  --app-dir paper-trading-api --host 127.0.0.1 --port 8000 --no-access-log
```

From the iOS app checkout, run `NORTHSTAR_TEST_API=http://127.0.0.1:8000 swift test`. The contract registers unique disposable accounts, verifies catalog/watchlist/buy/sell/rejection, signs out/in, verifies isolation, and deletes accounts. It also verifies HTTP redirects are refused. Authentication is rate-limited by IP; repeated local contract runs may require a fresh disposable database or waiting for the rate-limit window.

For iOS Simulator, the Debug configuration already sets `NORTHSTAR_API_ORIGIN=http://localhost:8000`. Run the backend on your Mac and choose Sign in/Create an account in the simulator. Only Debug allows loopback HTTP; `Configuration/DebugInfo.plist` contains the local-network ATS allowance. There is no broad `NSAllowsArbitraryLoads` exception. Physical devices do not share your Mac’s localhost; use a reachable HTTPS development host for those.

For Release, deploy this backend behind HTTPS and set the Xcode user-defined build setting `NORTHSTAR_API_ORIGIN` for Release. The Release target uses no Debug plist and rejects HTTP origins. No hardcoded credentials or broker keys are included. Verify deployment migrations/backups, availability, TLS and privacy commitments before launch.

## Failure and retry semantics

The client uses an ephemeral URLSession, bounded deadlines, no shared response cache/cookies and no redirect following. It sends no credential-bearing request to a redirected origin. Raw server bodies are never shown to users or logged.

Before POST, persist `{key,request}` in an origin + normalized username scoped journal. If persistence fails, do not POST. On timeout, 5xx, rate limit, expiry, decode failure or a failed post-order snapshot, retain the journal. Explicit retry reuses the same UUID and payload; the server deduplicates it. An authoritative POST rejection (400/404/409/422) clears it. A successful POST followed by a successful INR snapshot clears it only after that state can be displayed. Merely refreshing a snapshot does not discard an unresolved order. Signing out clears memory but preserves retry intent on disk for the same account after sign-in. There is no automatic money-changing retry or background queue.

The store serializes UI actions; the API actor also guards against overlapping operations across suspension points. API state is never replaced with local fixture balances during a network failure.


## Hosted JWT mode

The route shapes above remain the paper-account contract. The optional [JWT gateway](../backend-auth/README.md) replaces authentication for ledger routes: it verifies the issuer's RS256 JWT and maps `(issuer, subject)` to an isolated ledger. It deliberately omits `/api/v2/auth/*`; email/social/SMS signup/login, refresh and revocation happen at the configured identity service. Do not send an Auth0 JWT to the old opaque-token server and expect it to work. Configure the gateway and mobile audience/issuer together.

Hosted account deletion persists a job before calling the identity service. While unresolved, account access is suspended. A background worker retries with backoff; confirmed completion removes the ledger and records a hashed tombstone to prevent resurrection through an old JWT. Operations must monitor pending jobs and verify provider-specific revocation requirements. Ordinary order retry remains explicit and never uses this deletion worker.
