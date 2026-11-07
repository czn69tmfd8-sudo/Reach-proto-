#!/usr/bin/env bash
set -euo pipefail
: "${DEVICE_ID:?Select an iPhone simulator before running tests}"
mkdir -p build-logs
collect_results() {
  result=$?
  trap - EXIT
  if [[ -d TestResults.xcresult ]]; then
    xcrun xcresulttool get test-results summary --path TestResults.xcresult \
      > build-logs/test-summary.json 2> build-logs/test-summary-error.log || true
    xcrun xcresulttool export diagnostics --path TestResults.xcresult \
      --output-path build-logs/test-diagnostics \
      > build-logs/diagnostics-export.log 2>&1 || true
  fi
  exit "$result"
}
trap collect_results EXIT
xcodebuild -project REACH.xcodeproj -scheme REACH -configuration Debug \
  -destination "platform=iOS Simulator,id=$DEVICE_ID" \
  -derivedDataPath DerivedData -resultBundlePath TestResults.xcresult \
  -parallel-testing-enabled NO -test-timeouts-enabled YES \
  -default-test-execution-time-allowance 60 -maximum-test-execution-time-allowance 120 \
  CODE_SIGNING_ALLOWED=YES CODE_SIGN_IDENTITY="-" test 2>&1 | tee build-logs/tests.log
