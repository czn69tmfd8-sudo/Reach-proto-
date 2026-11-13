#!/usr/bin/env bash
# Capture the production call UI with synthetic video panes on a Debug simulator.
set -euo pipefail
: "${DEVICE_ID:?Select an available iPhone simulator}"
APP=DerivedData/Build/Products/Debug-iphonesimulator/REACH.app
OUTPUT=build-logs/call-visual
mkdir -p "$OUTPUT"
xcrun simctl bootstatus "$DEVICE_ID" -b
xcrun simctl install "$DEVICE_ID" "$APP"
xcrun simctl status_bar "$DEVICE_ID" override --time '9:41' --batteryState charged --batteryLevel 100
restore_ui() {
  xcrun simctl terminate "$DEVICE_ID" com.reachprototype.app || true
  xcrun simctl status_bar "$DEVICE_ID" clear || true
}
trap restore_ui EXIT
for VIEW in controls hidden; do
  xcrun simctl terminate "$DEVICE_ID" com.reachprototype.app || true
  xcrun simctl launch "$DEVICE_ID" com.reachprototype.app --call-simulator-preview="$VIEW"
  # Give the Debug application and SwiftUI time to render after a cold launch.
  sleep 8
  xcrun simctl io "$DEVICE_ID" screenshot "$OUTPUT/reach-fullscreen-$VIEW.png"
done
git rev-parse HEAD > "$OUTPUT/source-commit.txt"
xcrun simctl list devices available -j > "$OUTPUT/simulator-devices.json"
