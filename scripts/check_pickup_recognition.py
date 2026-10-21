#!/usr/bin/env python3
"""Offline, assertion-based acceptance of the actual Swift entry points.

This is a development/regression gate, not an estimate of user accuracy.
No network, device, Simulator, or UI is used.
"""
import argparse
import hashlib
import json
import subprocess
import sys
import tempfile
from collections import Counter
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ENTRIES = ("manual", "automatic", "shared_text", "image_lines")
REVIEWS = ("shared_text", "image_lines")


def read_jsonl(path):
    return [json.loads(line) for line in path.read_text().splitlines() if line.strip()]


def contracts():
    cases = []
    for sample in read_jsonl(ROOT / "docs/research/2026-10-15-pickup-parsing/samples.jsonl"):
        groups = sample["expected_groups"]
        if sample["representation"] == "structure_only" or any(g["code"]["state"] == "ambiguous" for g in groups):
            continue  # No code truth; never turn an unknown annotation into a negative.
        known = [g for g in groups if g["code"]["state"] == "known"]
        checks = {}
        for entry in (("manual",) if sample["representation"] == "format_only" else ENTRIES):
            check = {"codes": [g["code"]["value"] for g in known]}
            if not known:
                check["outcome"] = "error"
            elif all(g["location"]["state"] in ("known", "not_stated") for g in known):
                # C22's detailed address only has image-layout evidence.
                check["locations"] = [None if sample["id"] == "C22" and entry != "image_lines"
                                      else g["location"]["value"] for g in known]
            if known:
                # Existing platform display contract: literal courier, else pickup
                # service; normalize only aliases in PickupDirectory's canonical names.
                names = [g["carrier"]["value"] or g["pickup_service"]["value"] for g in known]
                check["platforms"] = [{"兔喜生活": "兔喜", "快宝驿站": "快宝"}.get(name, name) for name in names]
            checks[entry] = check
        cases.append({**sample, "id": "research/" + sample["id"], "expect": checks})
    for sample in read_jsonl(ROOT / "docs/recognition/1.2.8/cases.jsonl"):
        checks = {}
        for entry in ENTRIES:
            check = {"accepted": sample["expected"]} if entry in REVIEWS else {"codes": sample["expected"]}
            if not sample["expected"]:
                check["review_only"] = True if entry in REVIEWS else False
                if entry not in REVIEWS:
                    check["outcome"] = "error"
            checks[entry] = check
        cases.append({**sample, "id": "hotfix/" + sample["id"], "expect": checks})
    for sample in read_jsonl(ROOT / "docs/recognition/1.2.7/review-fixes/review-cases.jsonl"):
        old = sample["expected_behavior"]
        checks = {entry: {} for entry in ENTRIES}
        for entry, check in checks.items():
            for key in ("codes", "locations", "unresolved"):
                if key in old:
                    check[key] = old[key]
            if entry == "automatic" and "automatic" in old:
                check["error"] = old["automatic"]
            if entry in REVIEWS:
                if "review_codes" in old:
                    check["codes"] = old["review_codes"]
                if "default_selected" in old:
                    check["accepted"] = old["default_selected"]
            if entry == "shared_text" and "review" in old:
                check["error"] = old["review"]
            if entry == "image_lines" and "image_lines" in old:
                check["error"] = old["image_lines"]
        cases.append({**sample, "id": "review/" + sample["id"], "expect": checks})
    cases += read_jsonl(ROOT / "docs/recognition/1.2.9/contracts.jsonl")
    # Meaning-preserving transformations must retain the complete code, across entries.
    for code in ("001234", "A-12-08", "11-4-7319"):
        for label in ("取件码", "提货码", "取件密码"):
            for opening, closing in (("", ""), ("【", "】"), ("[", "]"), ("（", "）"), ("「", "」")):
                text = f"包裹已到北门驿站，{label}{opening}{code}{closing}，请及时取件"
                for prefix in ("", "收件人：张三，", "收件地址：海棠路8号，"):
                    cases.append({"id": f"variation/{len(cases)}", "representation": "synthetic_variation",
                                  "template_family": "labelled-arrival", "text": prefix + text,
                                  "expect": {e: {"codes": [code], "unresolved": 0} for e in ENTRIES}})
    return cases


def verify(cases, results):
    failures = []
    assertions = 0
    for sample in cases:
        result = results.get(sample["id"])
        if result is None:
            failures.append({"id": sample["id"], "check": "missing replay result"})
            continue
        for entry, expected in sample["expect"].items():
            value = result.get(entry)
            if value is None:
                failures.append({"id": sample["id"], "entry": entry, "check": "missing entry result"})
                continue
            items = value["items"]
            actual = {"codes": [x["code"] for x in items], "locations": [x["location"] for x in items],
                      "platforms": [x["platform"] for x in items],
                      "accepted": [x["code"] for x in items if x.get("shouldSelectByDefault", True)],
                      "unresolved": max((x["unresolvedNotificationCount"] for x in items), default=0),
                      "outcome": value["outcome"], "error": value.get("error"),
                      "issues": [x.get("reviewIssue") for x in items],
                      "review_only": all(x.get("reviewIssue") and not x["shouldSelectByDefault"] for x in items)}
            for key, want in expected.items():
                if key == "review_only" and want is False:
                    continue
                assertions += 1
                if actual.get(key) != want:
                    failures.append({"id": sample["id"], "entry": entry, "check": key,
                                     "expected": want, "actual": actual.get(key)})
    return assertions, failures


def field_summary(cases, failures):
    counts = Counter(key for sample in cases for expected in sample["expect"].values()
                     for key, value in expected.items() if not (key == "review_only" and value is False))
    failed = Counter(x["check"] for x in failures)
    return {key: {"checked": count, "failed": failed[key]} for key, count in sorted(counts.items())}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, help="Save summary and raw replay outside historical evidence")
    parser.add_argument("--source-root", type=Path, default=ROOT, help="Optional isolated source snapshot for a version comparison")
    args = parser.parse_args()
    cases = contracts()
    with tempfile.TemporaryDirectory(prefix="shouxia-recognition-gate-") as directory:
        source = Path(directory) / "cases.jsonl"
        source.write_text("".join(json.dumps(x, ensure_ascii=False) + "\n" for x in cases))
        proc = subprocess.run(["bash", str(args.source_root / "scripts/replay_pickup_samples.sh"), str(source)],
                              cwd=args.source_root, capture_output=True, text=True)
        if proc.returncode:
            sys.stderr.write(proc.stderr)
            return proc.returncode
        rows = [json.loads(x) for x in proc.stdout.splitlines()]
    if len({x["id"] for x in rows}) != len(rows) or len(rows) != len(cases):
        raise ValueError("Replay lost or duplicated cases")
    assertions, failures = verify(cases, {x["id"]: x for x in rows})
    summary = {"cases": len(cases), "entry_calls": sum(len(x["expect"]) for x in cases),
               "assertions": assertions, "failures": failures,
               "source_sets": {name: sum(x["id"].startswith(name + "/") for x in cases)
                               for name in ("research", "hotfix", "review", "stability", "variation")},
               "checks_by_field": field_summary(cases, failures),
               "source_sha256": {str(p.relative_to(args.source_root)): hashlib.sha256(p.read_bytes()).hexdigest()
                                 for p in (args.source_root / "Shared/PickupRecognitionCore.swift",
                                           args.source_root / "Shouxia/Services/PickupParser.swift",
                                           args.source_root / "Shouxia/Services/ImagePickupRecognizer.swift",
                                           args.source_root / "Shared/PickupSharedTextParser.swift",
                                           args.source_root / "Shared/PickupImageShareQueue.swift",
                                           args.source_root / "Shouxia/Models/PickupRecord.swift")},
               "scope": "Historical labelled development inputs plus constructed variations; not independent accuracy or real OCR."}
    if args.output:
        args.output.mkdir(parents=True, exist_ok=True)
        (args.output / "summary.json").write_text(json.dumps(summary, ensure_ascii=False, indent=2) + "\n")
        (args.output / "replay.jsonl").write_text(proc.stdout)
    print(f"{len(cases)} cases / {summary['entry_calls']} entry calls / {assertions} assertions / {len(failures)} failures")
    for failure in failures[:25]:
        print(json.dumps(failure, ensure_ascii=False))
    if len(failures) > 25:
        print(f"... {len(failures) - 25} more; use --output to inspect all failures")
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
