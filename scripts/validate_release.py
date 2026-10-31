#!/usr/bin/env python3
"""Check resolved Release settings before spending time on a signed archive.

A successful check means the known configuration fields look consistent. It does
not replace App Review, provider setup, testing on a device, or a security audit.
"""
import argparse
import json
import plistlib
from pathlib import Path
from urllib.parse import urlsplit

ROOT = Path(__file__).resolve().parents[1]


def validate(settings, offline_only=False):
    """Return actionable problems, never credential values or the whole settings."""
    errors = []
    bundle = settings.get("PRODUCT_BUNDLE_IDENTIFIER", "")
    team = settings.get("DEVELOPMENT_TEAM", "")
    if not bundle or bundle.startswith("com.example.") or "$" in bundle:
        errors.append("Set a unique production PRODUCT_BUNDLE_IDENTIFIER.")
    if len(team) != 10 or not team.isalnum():
        errors.append("Select your 10-character Apple development team.")
    if settings.get("CONFIGURATION") != "Release":
        errors.append("Export resolved Release build settings, not Debug settings.")
    info_path = settings.get("INFOPLIST_FILE", "")
    path = ROOT / info_path
    if not path.is_file():
        errors.append("Release Info.plist is missing.")
    else:
        info = plistlib.loads(path.read_bytes())
        ats = info.get("NSAppTransportSecurity", {})
        if ats.get("NSAllowsArbitraryLoads") or ats.get("NSAllowsLocalNetworking") or ats.get("NSExceptionDomains"):
            errors.append("Release must not include local or arbitrary HTTP allowances.")
        if not info.get("NSFaceIDUsageDescription"):
            errors.append("Add the Face ID purpose description.")
        schemes = [s for item in info.get("CFBundleURLTypes", []) for s in item.get("CFBundleURLSchemes", [])]
        if "$(PRODUCT_BUNDLE_IDENTIFIER)" not in schemes and bundle not in schemes:
            errors.append("Register the identity callback URL scheme matching the bundle ID.")
    if not offline_only:
        origin = urlsplit(settings.get("NORTHSTAR_API_ORIGIN", ""))
        issuer = urlsplit(settings.get("NORTHSTAR_IDENTITY_ISSUER", ""))
        for name, value in [("NORTHSTAR_API_ORIGIN", origin), ("NORTHSTAR_IDENTITY_ISSUER", issuer)]:
            if value.scheme != "https" or not value.hostname or value.username or value.password or value.path not in ("", "/") or value.query or value.fragment:
                errors.append("Configure a real HTTPS origin for " + name + ".")
        for field in ["NORTHSTAR_IDENTITY_CLIENT_ID", "NORTHSTAR_IDENTITY_AUDIENCE"]:
            if not settings.get(field): errors.append("Configure " + field + ".")
        social = settings.get("NORTHSTAR_CONNECTION_GOOGLE") or settings.get("NORTHSTAR_CONNECTION_FACEBOOK")
        if social and not settings.get("NORTHSTAR_CONNECTION_APPLE"):
            errors.append("Configure the Apple sign-in connection alongside social login; review App Store guideline 4.8.")
    for file in ["stocktradingios/PrivacyInfo.xcprivacy", "stocktradingios/Assets.xcassets/AppIcon.appiconset/AppIcon.png", "Configuration/ExportOptions.plist"]:
        if not (ROOT / file).is_file(): errors.append("Missing release resource: " + file)
    return errors


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--settings-json", type=Path, required=True)
    parser.add_argument("--offline-only", action="store_true", help="Explicitly archive without hosted account providers.")
    args = parser.parse_args()
    payload = json.loads(args.settings_json.read_text())
    target = next((item["buildSettings"] for item in payload if item.get("target") == "stocktradingios"), None)
    if target is None:
        parser.error("No stocktradingios target found in the resolved build settings.")
    errors = validate(target, args.offline_only)
    if errors:
        print("Release configuration needs attention:\n" + "\n".join("- " + error for error in errors))
        return 1
    print("Release configuration checks passed. Device, identity-provider and App Store checks remain required.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
