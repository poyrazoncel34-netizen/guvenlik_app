#!/usr/bin/env python3
"""Split an exact human licence-review queue across four accountable reviewers.

The output is work allocation only. It deliberately carries no SPDX decision,
primary-source URL, reviewed bytes hash, or completed-review status.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import sys
from pathlib import Path


REVIEWER_RE = re.compile(r"^[A-Za-z0-9][A-Za-z0-9._@+-]{2,127}$")
SAFE_ITEM_FIELDS = (
    "purl",
    "name",
    "group",
    "version",
    "ecosystem",
    "lockedArtifactSha256",
    "registryReference",
    "status",
)


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for block in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def fail(message: str) -> int:
    print("LICENSE_REVIEW_ASSIGNMENTS_FAIL", file=sys.stderr)
    print(f"- {message}", file=sys.stderr)
    return 1


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--queue", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--reviewer", required=True, action="append")
    args = parser.parse_args()

    if len(args.reviewer) != 4:
        return fail("exactly four accountable reviewers are required")
    if len(set(args.reviewer)) != len(args.reviewer):
        return fail("reviewers must be unique")
    if any(not REVIEWER_RE.fullmatch(reviewer) for reviewer in args.reviewer):
        return fail("reviewer identifiers must be stable non-placeholder IDs")
    if not args.queue.is_file() or args.queue.stat().st_size == 0:
        return fail(f"queue is missing or empty: {args.queue}")

    try:
        payload = json.loads(args.queue.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        return fail(f"queue cannot be read: {exc}")
    if not isinstance(payload, dict) or payload.get("schemaVersion") != 1:
        return fail("unsupported review queue schema")
    entries = payload.get("entries")
    if not isinstance(entries, list) or not entries:
        return fail("review queue entries are missing")

    seen: set[str] = set()
    reviewed_count = 0
    unreviewed: list[dict[str, object]] = []
    for raw in entries:
        if not isinstance(raw, dict):
            return fail("malformed review queue entry")
        purl = raw.get("purl")
        status = raw.get("status")
        if not isinstance(purl, str) or not purl.startswith("pkg:") or purl in seen:
            return fail(f"missing or duplicate purl: {purl}")
        seen.add(purl)
        if status == "REVIEWED":
            reviewed_count += 1
            continue
        if status != "HUMAN_REVIEW_REQUIRED":
            return fail(f"unsupported review status for {purl}: {status}")
        unreviewed.append({field: raw.get(field) for field in SAFE_ITEM_FIELDS})

    component_count = len(entries)
    if payload.get("componentCount") != component_count:
        return fail("componentCount does not match queue entries")
    if payload.get("reviewedCount") != reviewed_count:
        return fail("reviewedCount does not match queue entries")
    if payload.get("unreviewedCount") != len(unreviewed):
        return fail("unreviewedCount does not match queue entries")

    unreviewed.sort(key=lambda item: str(item["purl"]))
    buckets: list[list[dict[str, object]]] = [[] for _ in args.reviewer]
    for index, item in enumerate(unreviewed):
        buckets[index % len(buckets)].append(item)

    assignments = [
        {
            "reviewer": reviewer,
            "assignmentCount": len(items),
            "items": items,
        }
        for reviewer, items in zip(args.reviewer, buckets, strict=True)
    ]
    counts = [len(items) for items in buckets]
    if counts and max(counts) - min(counts) > 1:
        return fail("review allocation is not balanced")

    output_payload = {
        "schemaVersion": 1,
        "sourceQueueSha256": sha256(args.queue),
        "componentCount": component_count,
        "reviewedCount": reviewed_count,
        "assignedCount": len(unreviewed),
        "reviewerCount": len(args.reviewer),
        "status": "HUMAN_REVIEW_REQUIRED" if unreviewed else "COMPLETE",
        "assignments": assignments,
    }
    args.output.parent.mkdir(parents=True, exist_ok=True)
    temporary = args.output.with_suffix(args.output.suffix + ".tmp")
    temporary.write_text(
        json.dumps(output_payload, indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
    )
    temporary.replace(args.output)
    print("LICENSE_REVIEW_ASSIGNMENTS_READY")
    print(
        f"components={component_count} reviewed={reviewed_count} "
        f"assigned={len(unreviewed)} reviewers={len(args.reviewer)}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
