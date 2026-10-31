"""Check that the release guard rejects common deployment mistakes."""
import importlib.util
from pathlib import Path
import unittest

spec = importlib.util.spec_from_file_location("release_guard", Path(__file__).parents[1] / "validate_release.py")
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


class ReleaseGuardTests(unittest.TestCase):
    def settings(self):
        return dict(PRODUCT_BUNDLE_IDENTIFIER="org.test.northstar", DEVELOPMENT_TEAM="TEST123456",
                    CONFIGURATION="Release", INFOPLIST_FILE="Configuration/ReleaseInfo.plist",
                    NORTHSTAR_API_ORIGIN="https://api.test.example", NORTHSTAR_IDENTITY_ISSUER="https://identity.test.example",
                    NORTHSTAR_IDENTITY_CLIENT_ID="public-client", NORTHSTAR_IDENTITY_AUDIENCE="paper-api")

    def test_valid_structural_settings(self):
        self.assertEqual(module.validate(self.settings()), [])

    def test_debug_http_and_placeholder_identity_are_rejected(self):
        settings = self.settings()
        settings.update(CONFIGURATION="Debug", NORTHSTAR_API_ORIGIN="http://localhost:8000",
                        PRODUCT_BUNDLE_IDENTIFIER="com.example.app", INFOPLIST_FILE="Configuration/DebugInfo.plist")
        self.assertGreaterEqual(len(module.validate(settings)), 4)

    def test_social_login_requires_apple_connection(self):
        settings = self.settings()
        settings["NORTHSTAR_CONNECTION_GOOGLE"] = "google-oauth2"
        self.assertTrue(any("Apple" in error for error in module.validate(settings)))
        settings["NORTHSTAR_CONNECTION_APPLE"] = "apple"
        self.assertEqual(module.validate(settings), [])

    def test_offline_archive_does_not_require_identity_service(self):
        settings = self.settings()
        for key in list(settings):
            if key.startswith("NORTHSTAR_"): del settings[key]
        self.assertEqual(module.validate(settings, offline_only=True), [])
