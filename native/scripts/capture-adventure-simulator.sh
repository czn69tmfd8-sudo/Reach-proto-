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

if [[ "${REACH_CAPTURE_LIVE_GALLERY:-0}" == 1 ]]; then
  fixture_dir="$OUTPUT/gallery-pagination"
  mkdir -p "$fixture_dir"
  restore_ui
  # Use the smallest and largest available standard iPhones on the runner.
  fixture_devices=$(python3 - "$OUTPUT/simulator-devices.json" <<'PY'
import json
import sys

with open(sys.argv[1]) as report:
    devices = json.load(report)["devices"]
phones = {
    phone["name"]: phone["udid"]
    for runtime, entries in devices.items()
    if ".iOS-" in runtime
    for phone in entries
    if phone.get("isAvailable") and phone["name"].startswith("iPhone")
}
choices = [
    ("small", ("SE", " mini", "16e", "17e", " iPhone 16", " iPhone 17", "Pro")),
    ("large", ("Pro Max", "Plus", "Air")),
]
used = set()
for size, preferences in choices:
    match = next((name for needle in preferences for name in phones if needle.strip() in name and name not in used), None)
    if match is None:
        match = next((name for name in phones if name not in used), None)
    if match is None:
        raise SystemExit("Two distinct iPhone simulator sizes are required")
    used.add(match)
    print(size, phones[match], match, sep="|")
PY
)
  while IFS='|' read -r SIZE DEVICE_ID NAME; do
    mkdir -p "$fixture_dir/$SIZE"
    printf '%s\n' "$NAME" > "$fixture_dir/$SIZE/device.txt"
    xcrun simctl bootstatus "$DEVICE_ID" -b
    xcrun simctl install "$DEVICE_ID" "$APP"
    xcrun simctl ui "$DEVICE_ID" content_size large
    xcrun simctl status_bar "$DEVICE_ID" override --time '9:41' --batteryState charged --batteryLevel 100
    for PAGE in 0 1 2 3; do
      xcrun simctl terminate "$DEVICE_ID" com.reachprototype.app || true
      xcrun simctl launch "$DEVICE_ID" com.reachprototype.app --adventure-gallery-page="$PAGE"
      sleep 7
      xcrun simctl io "$DEVICE_ID" screenshot "$fixture_dir/$SIZE/page-$PAGE.png"
    done
    restore_ui
  done <<< "$fixture_devices"
fi
