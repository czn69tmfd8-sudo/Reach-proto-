#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "$0")/../.." && pwd)"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

fetch() {
    local name="$1" image="$2" checksum="$3"
    curl --fail --silent --show-error --location --retry 2 --max-time 25 \
        "https://images.unsplash.com/${image}?w=1800" --output "$work/$name.jpg"
    printf '%s  %s\n' "$checksum" "$work/$name.jpg" | shasum -a 256 -c
}

fetch mountains photo-1519681393784-d120267933ba 3454e153455e1fa5bdfa172b5d411d8d8d188b04c12fce9ea3072dfa31b8840a
fetch night photo-1519608487953-e999c86e7455 2ce7e7724b11d3f3c838f4c47533aa32c523cbcf0ae4b95d438f1e79ab815535
fetch paris photo-1502602898657-3e91760cbb34 c603df5ecae27b41567f5ba3b108355fc5b0a15901a3a5b19c75972d3baebfe6
fetch woodland photo-1472396961693-142e6e269027 9786d35bc59904727b0a9800cca8c90eda39c9de2f16b8c8d04f7c9f20c0e735

cp "$root/native/scripts/adventure-photo-benchmark.swift" "$work/main.swift"
xcrun swiftc "$root/native/REACH/Firebase/AdventurePhotoPreviewEncoder.swift" "$work/main.swift" -o "$work/preview-benchmark"
"$work/preview-benchmark" "$work"/{mountains,night,paris,woodland}.jpg
