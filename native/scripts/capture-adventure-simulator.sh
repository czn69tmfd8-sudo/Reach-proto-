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
  # Reuse the already-booted test device. Boot one alternate size on
  # the same runtime to keep the captures comparable and limit runner load.
  fixture_devices=$(python3 - "$OUTPUT/simulator-devices.json" "$DEVICE_ID" <<'PYTHON'
import json
import sys

with open(sys.argv[1]) as report:
    devices = json.load(report)["devices"]
primary_id = sys.argv[2]
phones = next(
    [phone for phone in entries if phone.get("isAvailable") and phone["name"].startswith("iPhone")]
    for runtime, entries in devices.items()
    if ".iOS-" in runtime and any(phone["udid"] == primary_id for phone in entries)
)
primary = next(phone for phone in phones if phone["udid"] == primary_id)
alternate_choices = [
    phone for phone in phones
    if phone["udid"] != primary_id and phone["name"] != primary["name"]
]
if not alternate_choices:
    raise SystemExit("Two distinct iPhone simulator sizes are required")
compact_tokens = ("SE", "mini", "16e", "17e")
primary_is_compact = any(token in primary["name"] for token in compact_tokens)
preferences = ("Pro Max", "Plus", "Air") if primary_is_compact else compact_tokens
alternate = next(
    (phone for token in preferences for phone in alternate_choices if token in phone["name"]),
    alternate_choices[0],
)
for label, phone in [
    ("compact" if primary_is_compact else "standard", primary),
    ("large" if primary_is_compact else "compact", alternate),
]:
    print(label, phone["udid"], phone["name"], sep="|")
PYTHON
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
    xcrun simctl shutdown "$DEVICE_ID"
  done <<< "$fixture_devices"
fi
