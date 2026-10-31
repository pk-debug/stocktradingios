# JWT gateway for the Northstar paper API

The old local server accepts opaque password-session tokens. It cannot verify an Auth0 access token. This gateway reuses its tested trading routes and replaces the identity boundary with **RS256 signature + issuer + audience + expiry** verification. It is an optional companion service; the existing free localhost username flow still runs without it.

## Run locally

From the mobile checkout, prepare the exact backend revision in an ignored directory. If `.backend` already contains work, preserve it rather than resetting it blindly.

```sh
git clone https://github.com/pk-debug/northstar-backend-lab.git .backend
git -C .backend checkout 7bac27ca60fe799a40ec9a11bec7b04d8ff78317
python3.12 -m venv .venv
. .venv/bin/activate
pip install -r backend-auth/requirements.lock
```

Provide the variables named in `.env.example` through your shell's secure configuration or hosting settings. A `.env` file is ignored by Git, but uvicorn does not load it automatically unless you use a compatible environment loader. Do not paste provider secrets into Swift, xcconfig, README or chat.

```sh
PYTHONPATH=.backend/paper-trading-api:backend-auth \
  uvicorn identity_gateway:create_app --factory --host 127.0.0.1 --port 8000 --no-access-log
```

For Docker, copy `.env.example` to `backend-auth/.env`, supply real values privately, and run `docker compose -f backend-auth/compose.yml up --build`. The compose service binds loopback only, keeps SQLite in a named volume, runs without root privileges, and uses a read-only root filesystem. A public host needs HTTPS termination, persistent storage, backups, gateway rate limits and monitoring. Do not expose this lab by changing a port mapping and assuming it is production-ready.

## Settings

| Variable | Location | Meaning |
| --- | --- | --- |
| `NORTHSTAR_IDENTITY_ISSUER` | App + server | HTTPS tenant origin; issuer claims include its trailing slash |
| `NORTHSTAR_IDENTITY_AUDIENCE` | App + server | Your registered RS256 API identifier |
| `NORTHSTAR_MANAGEMENT_CLIENT_ID` | Server only | Separate machine-to-machine client authorized to delete accounts |
| `NORTHSTAR_MANAGEMENT_CLIENT_SECRET` | Server only | Its secret, supplied securely outside Git |
| `NORTHSTAR_DB` | Server only | Persistent SQLite path; use `/data/northstar.sqlite3` in the supplied container |

The native iOS client is a **public** OAuth client with no client secret. The management client is a different server-side application. Never reuse its credentials in the mobile build.

## Account lifecycle

A verified `(issuer, subject)` gets its own ledger and ₹10 lakh in virtual cash. Phone, Google, Facebook and Apple identities are not automatically merged; linking identities is an explicit provider-side account-linking decision, not something a phone-number match should silently do.

Legacy password endpoints are absent from this gateway. An unverified/expired/wrong-audience token cannot fall back to a shared demo account. Public catalog and health endpoints remain public; balances and mutations require a verified JWT.

Deletion first calls the identity provider's management API and accepts an already-deleted 404. Only a confirmed provider deletion removes the local ledger and records a minimal hashed subject tombstone. The tombstone prevents an old unexpired JWT from recreating the deleted account. Management failures return 503 rather than pretending to delete. A deletion intent is persisted before contacting the provider. While pending, trading is suspended; only deletion retry can use the account. A bounded background worker retries jobs with backoff after failures and process restarts. Monitor the queue, test recovery, and define support/retention policies for prolonged identity-service outages. For Apple, verify provider-specific authorization/token revocation as well as deleting the hosted profile; a management-profile deletion alone is not evidence of Apple grant revocation.

The gateway validates signatures with PyJWT/cryptography; it does not implement its own cryptography. JWKS refreshes use a bounded cache, HTTPS and no redirects. Unknown identity-service failures deny account access. Deployment must restrict outbound traffic to its configured issuer, and must rate-limit and observe requests without logging bearer tokens.

## Tests

```sh
PYTHONPATH=backend-auth:.backend/paper-trading-api pytest -q backend-auth/tests
```

The tests generate temporary RSA keys and cover isolation, forged signatures, wrong issuers/audiences, expiry, absent legacy login and account deletion. They do not authenticate real social accounts or send paid SMS messages. CI pins the external backend revision and installs the complete tested `requirements.lock`; `requirements.txt` describes the extra JWT dependency for maintainers.
