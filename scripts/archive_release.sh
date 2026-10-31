#!/bin/bash
# Archive with your local Xcode signing account. This script exports an IPA;
# it never uploads a build or publishes anything to the App Store.
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p output
xcodebuild -project stocktradingios.xcodeproj -scheme stocktradingios \
  -configuration Release -destination 'generic/platform=iOS' -showBuildSettings -json > output/release-settings.json
python3 scripts/validate_release.py --settings-json output/release-settings.json "$@"
xcodebuild archive -project stocktradingios.xcodeproj -scheme stocktradingios \
  -configuration Release -destination 'generic/platform=iOS' -archivePath output/Northstar.xcarchive
xcodebuild -exportArchive -archivePath output/Northstar.xcarchive \
  -exportPath output/export -exportOptionsPlist Configuration/ExportOptions.plist
