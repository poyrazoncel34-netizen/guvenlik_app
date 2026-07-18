#!/usr/bin/env python3
"""Prepare a deterministic human licence-review queue from an exact SBOM.

This tool never infers a licence or marks a component reviewed. It only carries
forward entries already present in the accountable human evidence file.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import sys
from pathlib import Path


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for block in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def fail(message: str) -> int:
    print("LICENSE_REVIEW_QUEUE_FAIL", file=sys.stderr)
    print(f"- {message}", file=sys.stderr)
    return 1


def property_value(component: dict[str, object], name: str) -> str | None:
    properties = component.get("properties")
    if not isinstance(properties, list):
        return None
    matches = [
        item.get("value")
        for item in properties
        if isinstance(item, dict) and item.get("name") == name
    ]
    if len(matches) != 1 or not isinstance(matches[0], str):
        return None
    return matches[0]


def locked_hash(component: dict[str, object]) -> str | None:
    hashes = component.get("hashes")
    if not isinstance(hashes, list):
        return None
    matches = [
        item.get("content")
        for item in hashes
        if isinstance(item, dict) and item.get("alg") == "SHA-256"
    ]
    if len(matches) != 1 or not isinstance(matches[0], str):
        return None
    return matches[0].lower()


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--sbom", required=True, type=Path)
    parser.add_argument("--evidence", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    args = parser.parse_args()

    try:
        sbom = json.loads(args.sbom.read_text(encoding="utf-8"))
        evidence = json.loads(args.evidence.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        return fail(f"input cannot be read: {exc}")
    if not isinstance(sbom, dict) or sbom.get("bomFormat") != "CycloneDX":
        return fail("invalid CycloneDX SBOM")
    if not isinstance(evidence, dict) or evidence.get("schemaVersion") != 1:
        return fail("invalid licence evidence schema")
    evidence_entries = evidence.get("entries")
    if not isinstance(evidence_entries, dict):
        return fail("licence evidence entries must be an object")
    components = sbom.get("components")
    if not isinstance(components, list) or not components:
        return fail("SBOM components are missing")

    queue: list[dict[str, object]] = []
    seen: set[str] = set()
    for raw_component in components:
        if not isinstance(raw_component, dict):
            return fail("malformed SBOM component")
        purl = raw_component.get("purl")
        if not isinstance(purl, str) or not purl.startswith("pkg:") or purl in seen:
            return fail(f"missing or duplicate purl: {purl}")
        seen.add(purl)
        reviewed = evidence_entries.get(purl)
        if reviewed is not None and not isinstance(reviewed, dict):
            return fail(f"malformed reviewed evidence: {purl}")
        ecosystem = property_value(raw_component, "korubeni:ecosystem")
        registry_reference = (
            f"https://pub.dev/packages/{raw_component.get('name')}/versions/{raw_component.get('version')}"
            if ecosystem == "Pub"
            else purl
        )
        queue.append(
            {
                "purl": purl,
                "name": raw_component.get("name"),
                "group": raw_component.get("group"),
                "version": raw_component.get("version"),
                "ecosystem": ecosystem,
                "lockedArtifactSha256": locked_hash(raw_component),
                "registryReference": registry_reference,
                "status": "REVIEWED" if reviewed is not None else "HUMAN_REVIEW_REQUIRED",
                "spdxId": reviewed.get("spdxId") if isinstance(reviewed, dict) else None,
                "primarySourceUrl": reviewed.get("sourceUrl") if isinstance(reviewed, dict) else None,
                "reviewedBytesSha256": reviewed.get("sha256") if isinstance(reviewed, dict) else None,
                "reviewedBy": reviewed.get("reviewedBy") if isinstance(reviewed, dict) else None,
                "reviewedAt": reviewed.get("reviewedAt") if isinstance(reviewed, dict) else None,
            }
        )

    stale = sorted(set(evidence_entries) - seen)
    if stale:
        return fail(f"stale evidence purls: {stale[:10]}")
    queue.sort(key=lambda item: str(item["purl"]))
    reviewed_count = sum(item["status"] == "REVIEWED" for item in queue)
    payload = {
        "schemaVersion": 1,
        "sbomSha256": sha256(args.sbom),
        "evidenceFileSha256": sha256(args.evidence),
        "componentCount": len(queue),
        "reviewedCount": reviewed_count,
        "unreviewedCount": len(queue) - reviewed_count,
        "status": "COMPLETE" if reviewed_count == len(queue) else "HUMAN_REVIEW_REQUIRED",
        "entries": queue,
    }
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(
        json.dumps(payload, indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
    )
    print("LICENSE_REVIEW_QUEUE_READY")
    print(f"components={len(queue)} reviewed={reviewed_count} unreviewed={len(queue) - reviewed_count}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
