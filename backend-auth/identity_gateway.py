"""Verify real identity-service JWTs before allowing access to the paper ledger.

The iPhone cannot grant itself money or accounts by decoding a token. This server
checks the signature using the issuer's public keys, then maps its trusted subject
(the user's stable ID) to one isolated ledger. No social-provider secret enters iOS.
Run with the pinned reference backend on PYTHONPATH; see this folder's README.
"""
from __future__ import annotations

import asyncio
from contextlib import asynccontextmanager, suppress
import time
import hashlib
import json
import os
import urllib.error
import urllib.parse
import urllib.request
from dataclasses import dataclass
from uuid import NAMESPACE_URL, uuid5

import jwt
from fastapi import APIRouter, Depends, FastAPI, Header, HTTPException, Request
from fastapi.routing import APIRoute
from fastapi.exceptions import RequestValidationError


class NoRedirect(urllib.request.HTTPRedirectHandler):
    """Never forward management credentials or key fetches through a redirect."""
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        return None


def https_json(url: str, *, method="GET", body=None, token=None):
    """Make a bounded, TLS-verified request; keep response bodies out of errors."""
    request = urllib.request.Request(url, method=method)
    request.add_header("Accept", "application/json")
    if token:
        request.add_header("Authorization", "Bearer " + token)
    if body is not None:
        request.add_header("Content-Type", "application/json")
        request.data = json.dumps(body).encode()
    with urllib.request.build_opener(NoRedirect()).open(request, timeout=10) as response:
        data = response.read(1_048_577)
        if len(data) > 1_048_576:
            raise ValueError("Identity response too large")
        return json.loads(data) if data else {}


@dataclass(frozen=True)
class Settings:
    """Only the server gets the optional management client secret."""
    issuer: str
    audience: str
    management_id: str = ""
    management_secret: str = ""

    def __post_init__(self):
        parsed = urllib.parse.urlsplit(self.issuer)
        if (parsed.scheme != "https" or not parsed.hostname or parsed.username or parsed.password
                or parsed.path not in ("", "/") or parsed.query or parsed.fragment or not self.audience):
            raise ValueError("Configure an HTTPS identity origin and API audience")
        object.__setattr__(self, "issuer", self.issuer.rstrip("/") + "/")

    @classmethod
    def from_environment(cls):
        return cls(os.environ["NORTHSTAR_IDENTITY_ISSUER"], os.environ["NORTHSTAR_IDENTITY_AUDIENCE"],
                   os.environ.get("NORTHSTAR_MANAGEMENT_CLIENT_ID", ""),
                   os.environ.get("NORTHSTAR_MANAGEMENT_CLIENT_SECRET", ""))


class TrustedJWKClient(jwt.PyJWKClient):
    """Use PyJWT's rotation cache, but keep TLS and no-redirect rules explicit."""
    def fetch_data(self):
        data = https_json(self.uri)
        if not isinstance(data, dict) or not isinstance(data.get("keys"), list):
            raise ValueError("Invalid issuer key set")
        if self.jwk_set_cache is not None:
            self.jwk_set_cache.put(data)
        return data


class JWTVerifier:
    """Accept only signed RS256 API tokens from our issuer for our API audience."""
    def __init__(self, settings: Settings, keys=None):
        self.settings = settings
        self.keys = keys or TrustedJWKClient(settings.issuer + ".well-known/jwks.json", lifespan=300)

    def subject(self, token: str) -> str:
        key = self.keys.get_signing_key_from_jwt(token).key
        claims = jwt.decode(token, key, algorithms=["RS256"], audience=self.settings.audience,
                            issuer=self.settings.issuer, leeway=30,
                            options={"require": ["exp", "iat", "sub", "iss", "aud"]})
        subject = claims["sub"]
        if not isinstance(subject, str) or not 1 <= len(subject) <= 256:
            raise ValueError("Invalid subject")
        return subject


class Auth0IdentityDeletion:
    """Remove the hosted account too, not just its holdings. Configure a separate
    machine-to-machine credential with delete:users in the provider dashboard.
    """
    def __init__(self, settings):
        self.settings = settings

    def delete(self, subject):
        s = self.settings
        if not s.management_id or not s.management_secret:
            raise RuntimeError("Identity deletion is not configured")
        session = https_json(s.issuer + "oauth/token", method="POST", body={
            "grant_type": "client_credentials", "client_id": s.management_id,
            "client_secret": s.management_secret, "audience": s.issuer + "api/v2/"})
        try:
            https_json(s.issuer + "api/v2/users/" + urllib.parse.quote(subject, safe=""),
                       method="DELETE", token=session["access_token"])
        except urllib.error.HTTPError as error:
            if error.code != 404:  # Already removed is a successful idempotent outcome.
                raise


def create_app(settings=None, verifier=None, deletion=None):
    """Reuse the verified trading routes while replacing their identity boundary.

    Legacy password/token routes are deliberately absent here. Run the original
    server separately for free localhost username/password practice.
    """
    from app import main as ledger
    settings = settings or Settings.from_environment()
    verifier = verifier or JWTVerifier(settings)
    deletion = deletion or Auth0IdentityDeletion(settings)
    @asynccontextmanager
    async def lifespan(api):
        async def reconcile():
            while True:
                try:
                    await asyncio.to_thread(process_deletions)
                except Exception:
                    pass  # A temporary database outage must not permanently stop recovery.
                await asyncio.sleep(60)
        worker = asyncio.create_task(reconcile())
        try:
            yield
        finally:
            worker.cancel()
            with suppress(asyncio.CancelledError):
                await worker

    api = FastAPI(title="Northstar identity-secured paper API", version="3.0.0", lifespan=lifespan)
    api.middleware("http")(ledger.security_headers)
    api.add_exception_handler(HTTPException, ledger.business_error)
    api.add_exception_handler(RequestValidationError, ledger.invalid_request)
    with ledger.transaction() as db:
        db.execute("CREATE TABLE IF NOT EXISTS oidc_deleted (subject_hash TEXT PRIMARY KEY)")
        db.execute("""CREATE TABLE IF NOT EXISTS oidc_deletion_jobs (
            subject_hash TEXT PRIMARY KEY, user_id TEXT NOT NULL, subject TEXT NOT NULL,
            attempts INTEGER NOT NULL DEFAULT 0, next_attempt INTEGER NOT NULL DEFAULT 0)""")

    def subject_hash(subject):
        return hashlib.sha256((settings.issuer + subject).encode()).hexdigest()

    def authenticated(request: Request, authorization: str = Header(default="")):
        """Never fall back to an unverified token or a shared demo account."""
        scheme, _, token = authorization.partition(" ")
        if scheme != "Bearer" or not token or len(token) > 16_384:
            raise HTTPException(401, "Sign in again.")
        try:
            subject = verifier.subject(token)
        except (jwt.InvalidTokenError, jwt.PyJWKClientError, ValueError, KeyError):
            raise HTTPException(401, "Sign in again.")
        except Exception:
            # Issuer/network failures must not become anonymous access.
            raise HTTPException(503, "The identity service is unavailable.")
        digest = subject_hash(subject)
        user_id = str(uuid5(NAMESPACE_URL, settings.issuer + subject))
        with ledger.transaction() as db:
            if db.execute("SELECT 1 FROM oidc_deleted WHERE subject_hash=?", (digest,)).fetchone():
                raise HTTPException(401, "This account was deleted.")
            if db.execute("SELECT 1 FROM oidc_deletion_jobs WHERE subject_hash=?", (digest,)).fetchone():
                if request.method == "DELETE" and request.url.path == "/api/v2/account":
                    return user_id, subject
                raise HTTPException(409, "Account deletion is pending. Account access is suspended.")
            db.execute("INSERT OR IGNORE INTO users VALUES (?,?,?,?,?)",
                       (user_id, "oidc_" + digest, "external-identity-only", "00", 100_000_000))
        return user_id, subject

    api.dependency_overrides[ledger.current_user] = authenticated
    router = APIRouter()
    for route in ledger.app.routes:
        if isinstance(route, APIRoute) and not route.path.startswith("/api/v2/auth/") and route.path != "/api/v2/account":
            router.routes.append(route)
    # Rebuild route dependency bindings for this app rather than the legacy app.
    api.include_router(router)

    def attempt_deletion(digest):
        """One durable, idempotent step; retries survive API-process restarts."""
        with ledger.transaction() as db:
            job = db.execute("SELECT * FROM oidc_deletion_jobs WHERE subject_hash=?", (digest,)).fetchone()
            if job is None:
                return
            delay = min(3600, 60 * 2 ** min(job["attempts"], 6))
            db.execute("UPDATE oidc_deletion_jobs SET attempts=attempts+1,next_attempt=? WHERE subject_hash=?",
                       (int(time.time()) + delay, digest))
        deletion.delete(job["subject"])
        with ledger.transaction() as db:
            db.execute("INSERT OR IGNORE INTO oidc_deleted VALUES (?)", (digest,))
            db.execute("DELETE FROM users WHERE id=?", (job["user_id"],))
            db.execute("DELETE FROM oidc_deletion_jobs WHERE subject_hash=?", (digest,))

    def process_deletions():
        """Retry a bounded batch without placing orders or logging user identities."""
        with ledger.transaction() as db:
            jobs = db.execute("SELECT subject_hash FROM oidc_deletion_jobs WHERE next_attempt<=? LIMIT 10",
                              (int(time.time()),)).fetchall()
        for job in jobs:
            try:
                attempt_deletion(job["subject_hash"])
            except Exception:
                # Durable retry time is already recorded; operational monitoring
                # should count pending jobs without collecting identity payloads.
                continue

    api.state.process_deletions = process_deletions

    @api.delete("/api/v2/account", status_code=204)
    def delete_account(user=Depends(authenticated)):
        """Record intent before touching the identity provider. Until completion,
        suspend trading; a lost response or process restart cannot lose the job.
        """
        digest = subject_hash(user[1])
        with ledger.transaction() as db:
            db.execute("INSERT OR IGNORE INTO oidc_deletion_jobs (subject_hash,user_id,subject) VALUES (?,?,?)",
                       (digest, user[0], user[1]))
        try:
            attempt_deletion(digest)
        except Exception:
            raise HTTPException(503, "Deletion is pending. It will be retried securely; account access is suspended.")

    return api
