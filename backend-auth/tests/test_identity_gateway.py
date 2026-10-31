"""Generate temporary test keys to prove that forged tokens never open a ledger.
These keys are only test fixtures, never production credentials.
"""
import time
from types import SimpleNamespace

import jwt
import pytest
from cryptography.hazmat.primitives.asymmetric import rsa
from fastapi.testclient import TestClient
from identity_gateway import Settings, JWTVerifier, create_app


@pytest.fixture
def system(tmp_path, monkeypatch):
    monkeypatch.setenv("NORTHSTAR_DB", str(tmp_path / "account.sqlite3"))
    from app import main as ledger
    ledger.DB_PATH = str(tmp_path / "account.sqlite3")
    ledger.initialize()
    private = rsa.generate_private_key(public_exponent=65537, key_size=2048)
    settings = Settings("https://identity.example/", "northstar-api")
    class Keys:
        def get_signing_key_from_jwt(self, token):
            return SimpleNamespace(key=private.public_key())
    class Deletion:
        deleted = []
        fail = False
        def delete(self, subject):
            if self.fail:
                raise RuntimeError("Unavailable")
            self.deleted.append(subject)
    deletion = Deletion()
    client = TestClient(create_app(settings, JWTVerifier(settings, Keys()), deletion))
    def token(subject="google|learner", **changes):
        claims = dict(iss=settings.issuer, aud=settings.audience, sub=subject,
                      iat=int(time.time()), exp=int(time.time()) + 300)
        claims.update(changes)
        return jwt.encode(claims, private, algorithm="RS256", headers={"kid": "temporary-test-key"})
    return client, token, deletion


def auth(token):
    return {"Authorization": "Bearer " + token}


def test_verified_accounts_are_isolated_and_legacy_login_absent(system):
    client, token, _ = system
    first, second = auth(token("google|first")), auth(token("sms|second"))
    assert client.get("/api/v2/snapshot", headers=first).json()["cash"] == 1_000_000
    assert client.post("/api/v2/orders", headers={**first, "Idempotency-Key": "first-buy"},
                       json={"symbol": "RELIANCE", "side": "BUY", "quantity": 1}).status_code == 201
    assert client.get("/api/v2/snapshot", headers=second).json()["orders"] == []
    assert client.post("/api/v2/auth/login", json={}).status_code == 404


@pytest.mark.parametrize("changes", [dict(aud="wrong-api"), dict(iss="https://imposter.example/"),
                                     dict(exp=1), dict(sub=""), dict(iat=int(time.time()) + 3600)])
def test_bad_claims_are_rejected(system, changes):
    client, token, _ = system
    assert client.get("/api/v2/snapshot", headers=auth(token(**changes))).status_code == 401


def test_unsigned_and_forged_tokens_are_rejected(system):
    client, token, _ = system
    valid = token()
    pieces = valid.split(".")
    forged = pieces[0] + "." + pieces[1] + ".ZmFrZS1zaWduYXR1cmU"
    assert client.get("/api/v2/snapshot", headers=auth(forged)).status_code == 401
    assert client.get("/api/v2/snapshot", headers=auth("opaque-local-token")).status_code == 401
    assert client.get("/api/v2/snapshot").status_code == 401


def test_deletion_prevents_old_token_recreating_account(system):
    client, token, deletion = system
    headers = auth(token())
    assert client.get("/api/v2/snapshot", headers=headers).status_code == 200
    assert client.delete("/api/v2/account", headers=headers).status_code == 204
    assert deletion.deleted == ["google|learner"]
    assert client.get("/api/v2/snapshot", headers=headers).status_code == 401


def test_failed_provider_deletion_does_not_report_success(system):
    client, token, deletion = system
    headers = auth(token())
    deletion.fail = True
    assert client.delete("/api/v2/account", headers=headers).status_code == 503
    assert client.get("/api/v2/snapshot", headers=headers).status_code == 409
    deletion.fail = False
    assert client.delete("/api/v2/account", headers=headers).status_code == 204


def test_insecure_issuer_is_rejected():
    with pytest.raises(ValueError):
        Settings("http://identity.example", "api")


def test_persisted_deletion_job_is_reconciled_without_user_retry(system):
    client, token, deletion = system
    headers = auth(token())
    deletion.fail = True
    assert client.delete("/api/v2/account", headers=headers).status_code == 503
    from app import main as ledger
    with ledger.transaction() as db:
        assert db.execute("SELECT count(*) FROM oidc_deletion_jobs").fetchone()[0] == 1
        db.execute("UPDATE oidc_deletion_jobs SET next_attempt=0")
    deletion.fail = False
    client.app.state.process_deletions()
    assert client.get("/api/v2/snapshot", headers=headers).status_code == 401
    with ledger.transaction() as db:
        assert db.execute("SELECT count(*) FROM oidc_deletion_jobs").fetchone()[0] == 0


def test_wrong_signature_algorithm_is_rejected(system):
    client, token, _ = system
    claims = jwt.decode(token(), options={"verify_signature": False})
    forged = jwt.encode(claims, b"only-a-generated-test-secret-000000", algorithm="HS256")
    assert client.get("/api/v2/snapshot", headers=auth(forged)).status_code == 401
