#!/bin/bash
set -euo pipefail
# Host-only tests: no simulator, device, signing or UI interaction.
repo_root="$(cd "$(dirname "$0")/.." && pwd)"
test_root="$(mktemp -d /tmp/shouxia-surface-tests.XXXXXX)"
trap 'rm -rf "$test_root"' EXIT
mkdir -p "$test_root/Sources/Shouxia" "$test_root/Tests/ShouxiaTests"
cat > "$test_root/Package.swift" <<'SWIFT'
// swift-tools-version: 6.0
import PackageDescription
let package = Package(name: "ShouxiaSurfaceCore", platforms: [.macOS(.v14)], targets: [
    .target(name: "Shouxia"),
    .testTarget(name: "ShouxiaTests", dependencies: ["Shouxia"])
])
SWIFT
for file in Shouxia/Models/PickupRecord.swift Shouxia/Models/PickupHandoffPackage.swift Shouxia/Services/PickupParser.swift Shouxia/Services/PickupRepository.swift Shouxia/Services/PickupLiveActivityController.swift Shared/PickupSurfaceSnapshot.swift Shared/PickupActivitySession.swift; do
    cp "$repo_root/$file" "$test_root/Sources/Shouxia/"
done
for file in PickupSurfaceTests PickupActivityTests; do
    cp "$repo_root/ShouxiaTests/$file.swift" "$test_root/Tests/ShouxiaTests/"
done
swift test --package-path "$test_root"
