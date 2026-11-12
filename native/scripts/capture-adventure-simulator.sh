#!/usr/bin/env bash
# Run from native/ after building the Debug simulator application.
set -euo pipefail
: "${DEVICE_ID:?Select an available iPhone simulator}"
APP=DerivedData/Build/Products/Debug-iphonesimulator/REACH.app
OUTPUT=build-logs/adventure-visual
mkdir -p "$OUTPUT"
xcrun simctl bootstatus "$DEVICE_ID" -b
xcrun simctl install "$DEVICE_ID" "$APP"
xcrun simctl status_bar "$DEVICE_ID" override --time '9:41' --batteryState charged --batteryLevel 100
restore_ui() {
  xcrun simctl ui "$DEVICE_ID" content_size large || true
  xcrun simctl status_bar "$DEVICE_ID" clear || true
}
trap restore_ui EXIT
xcrun simctl ui "$DEVICE_ID" content_size large
for PAGE in 0 1 2; do
  xcrun simctl terminate "$DEVICE_ID" com.reachprototype.app || true
  xcrun simctl launch "$DEVICE_ID" com.reachprototype.app --adventure-sample-page="$PAGE"
  # The app can briefly show its white launch surface after simctl launch.
  # Wait for SwiftUI's sample fixture to finish its first render before capture.
  sleep 7
  xcrun simctl io "$DEVICE_ID" screenshot "$OUTPUT/page-$PAGE.png"
done
xcrun simctl ui "$DEVICE_ID" content_size accessibility-extra-extra-extra-large
xcrun simctl terminate "$DEVICE_ID" com.reachprototype.app || true
xcrun simctl launch "$DEVICE_ID" com.reachprototype.app --adventure-sample-page=2
sleep 2
xcrun simctl io "$DEVICE_ID" screenshot "$OUTPUT/memory-accessibility.png"
git rev-parse HEAD > "$OUTPUT/source-commit.txt"
xcrun simctl list devices available -j > "$OUTPUT/simulator-devices.json"
xcodebuild -version > "$OUTPUT/xcode-version.txt"
