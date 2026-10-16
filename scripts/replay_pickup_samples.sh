#!/bin/bash
set -euo pipefail
# Offline parsing replay only. Does not run Vision, an app, Simulator or device UI.
repo_root="$(cd "$(dirname "$0")/.." && pwd)"
replay_root="$(mktemp -d /tmp/shouxia-pickup-replay.XXXXXX)"
trap 'rm -rf "$replay_root"' EXIT
python3 - "$repo_root" "$replay_root" <<'PY'
from pathlib import Path
import sys, shutil
root, target = map(Path, sys.argv[1:])
for f in ['Shouxia/Services/PickupParser.swift','Shouxia/Models/PickupRecord.swift','Shared/PickupRecognitionCore.swift','Shared/PickupSharedTextParser.swift','Shared/PickupImageShareQueue.swift']:
    shutil.copyfile(root/f, target/Path(f).name)
s=(root/'Shouxia/Services/ImagePickupRecognizer.swift').read_text()
s='import Foundation\n'+s[s.index('struct RecognizedTextLine'):s.index('struct ImageTextRecognizer')]+s[s.index('struct ImagePickupExtractor'):s.index('private extension CGImagePropertyOrientation')]
(target/'ImagePure.swift').write_text(s)
PY
cat > "$replay_root/main.swift" <<'SWIFT'
import Foundation
func item(_ p: ParsedPickup) -> [String: Any] {
    ["code": p.code, "location": p.location as Any? ?? NSNull(), "platform": p.platform as Any? ?? NSNull(),
     "unresolvedNotificationCount": p.unresolvedNotificationCount,
     "locationRequiresConfirmation": p.locationRequiresConfirmation]
}
func item(_ p: ImagePickupCandidate) -> [String: Any] {
    ["code": p.code, "location": p.location as Any? ?? NSNull(), "platform": p.platform as Any? ?? NSNull(),
     "unresolvedNotificationCount": p.unresolvedNotificationCount,
     "isLabelled": p.isLabelled, "isHighConfidence": p.isHighConfidence,
     "shouldSelectByDefault": p.shouldSelectByDefault,
     "reviewIssue": p.reviewIssue?.rawValue as Any? ?? NSNull(),
     "hasAlternativeGroup": p.alternativeGroup != nil,
     "locationRequiresConfirmation": p.locationRequiresConfirmation]
}
func run(_ action: () throws -> [[String: Any]]) -> [String: Any] {
    do { return ["outcome": "returned", "items": try action()] }
    catch { return ["outcome": "error", "error": String(describing: error), "items": []] }
}
let input = try String(contentsOfFile: CommandLine.arguments[1], encoding: .utf8)
for line in input.split(separator: "\n") {
    let sample = try JSONSerialization.jsonObject(with: Data(line.utf8)) as! [String: Any]
    guard let text = sample["text"] as? String else { continue }
    var result: [String: Any] = ["id": sample["id"]!, "inputRepresentation": sample["representation"]!]
    result["manual"] = run { try PickupParser().parseAll(text).map(item) }
    if sample["representation"] as? String != "format_only" {
        result["automatic"] = run { try PickupParser().parseAll(text, requiresLabel: true).map(item) }
        result["shared_text"] = run { try PickupSharedTextParser().candidates(from: text).map(item) }
        let strings = (sample["ocr_lines"] as? [String]) ?? text.components(separatedBy: .newlines)
        let layout = sample["layout"] as? [String: Any]
        let boxes = layout?["boxes"] as? [[Double]]
        let screenHeight = (layout?["screen_height"] as? Double) ?? 2400
        let lines = strings.enumerated().map { i, text in
            // X is normalized consistently within the fixture; no inferred real image width.
            RecognizedTextLine(text: text, confidence: 0.92,
                minX: boxes == nil ? 0 : boxes![i][0] / 1000,
                midY: boxes == nil ? Double(strings.count - i) * 0.04 : 1 - (boxes![i][1] + boxes![i][3] / 2) / screenHeight,
                width: boxes == nil ? 0 : boxes![i][2] / 1000,
                height: boxes == nil ? 0 : boxes![i][3] / screenHeight)
        }
        result["image_lines"] = run { try ImagePickupExtractor().candidates(from: lines).map(item) }
    }
    let data = try JSONSerialization.data(withJSONObject: result, options: [.sortedKeys, .withoutEscapingSlashes])
    print(String(decoding: data, as: UTF8.self))
}
SWIFT
xcrun swiftc "$replay_root"/*.swift -o "$replay_root/replay"
"$replay_root/replay" "${1:-$repo_root/docs/research/2026-10-15-pickup-parsing/samples.jsonl}"
