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
for file in Shouxia/Models/PickupRecord.swift Shouxia/Models/PickupHandoffPackage.swift Shouxia/Services/PickupParser.swift Shouxia/Services/PickupRepository.swift Shouxia/Services/PickupLiveActivityController.swift Shared/PickupSurfaceSnapshot.swift Shared/PickupActivitySession.swift Shared/SystemCapabilities.swift Shared/PickupImageShareQueue.swift Shouxia/Models/PickupShareText.swift Shouxia/Features/PickupStore.swift; do
    cp "$repo_root/$file" "$test_root/Sources/Shouxia/"
done
for file in PickupSurfaceTests PickupActivityTests PickupRepositoryTests PickupShareTextTests PickupStoreTests PickupImageShareTests; do
    cp "$repo_root/ShouxiaTests/$file.swift" "$test_root/Tests/ShouxiaTests/"
done
# Extract portable image parsing unchanged; UIKit decoding and live OCR are iOS-only.
python3 - "$repo_root" "$test_root" <<'PYTEST'
from pathlib import Path
import sys, re
root, target = map(Path, sys.argv[1:])
s = (root / "Shouxia/Services/ImagePickupRecognizer.swift").read_text()
a, b = s.index("struct ImageTextRecognizer:"), s.index("struct ImagePickupExtractor:")
s = s[:a] + s[b:]
s = s[:s.index("private extension CGImagePropertyOrientation")]
s = s.replace("import UIKit\n", "").replace("import Vision\n", "")
(target / "Sources/Shouxia/ImagePickupRecognizer.swift").write_text(s)
s = (root / "ShouxiaTests/PickupParserTests.swift").read_text()
s = re.sub(r"    func testReal(?:ImageOCRFixtureWhenProvided|OverlappingImageBatchWhenProvided)\(\).*?^    }\n", "", s, flags=re.S | re.M)
(target / "Tests/ShouxiaTests/PickupParserTests.swift").write_text(s)
share = (root / "Shouxia/Features/Handoff/HandoffActivityView.swift").read_text()
share = "import Foundation\n" + share[share.index("struct HandoffShareContent"):share.index("struct HandoffActivityView")]
(target / "Sources/Shouxia/HandoffShareContent.swift").write_text(share)
print("Host tests exclude UIKit theme and 2 real OCR fixture tests; iOS build-for-testing checks those sources.")
PYTEST
swift test --package-path "$test_root"
