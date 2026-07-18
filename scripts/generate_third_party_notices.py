#!/usr/bin/env python3
"""Generate candidate-bound third-party notices from human-reviewed bytes.

The script is deliberately offline and fail closed. It never guesses a licence,
downloads mutable content, or substitutes registry metadata for reviewed text.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import sys
from collections import defaultdict
from pathlib import Path


SHA256_RE = re.compile(r"^[0-9a-f]{64}$")
SPDX_RE = re.compile(r"^[A-Za-z0-9][A-Za-z0-9.+-]{0,127}$")
DATE_RE = re.compile(r"^\d{4}-\d{2}-\d{2}$")


def sha256_bytes(value: bytes) -> str:
    return hashlib.sha256(value).hexdigest()


def fail(message: str) -> int:
    print("THIRD_PARTY_NOTICES_FAIL", file=sys.stderr)
    print(f"- {message}", file=sys.stderr)
    return 1


def load_object(path: Path, label: str) -> dict[str, object]:
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, UnicodeDecodeError, json.JSONDecodeError) as exc:
        raise ValueError(f"{label} cannot be read: {exc}") from exc
    if not isinstance(value, dict):
        raise ValueError(f"{label} root must be an object")
    return value


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--sbom", required=True, type=Path)
    parser.add_argument("--evidence", required=True, type=Path)
    parser.add_argument("--license-text-dir", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    args = parser.parse_args()

    try:
        sbom = load_object(args.sbom, "SBOM")
        evidence = load_object(args.evidence, "licence evidence")
    except ValueError as exc:
        return fail(str(exc))
    if sbom.get("bomFormat") != "CycloneDX":
        return fail("SBOM is not CycloneDX")
    if evidence.get("schemaVersion") != 1:
        return fail("unsupported licence evidence schema")
    components = sbom.get("components")
    entries = evidence.get("entries")
    if not isinstance(components, list) or not components:
        return fail("SBOM components are missing")
    if not isinstance(entries, dict):
        return fail("licence evidence entries must be an object")

    component_purls: set[str] = set()
    component_labels: dict[str, str] = {}
    for component in components:
        if not isinstance(component, dict):
            return fail("malformed SBOM component")
        purl = component.get("purl")
        if not isinstance(purl, str) or not purl.startswith("pkg:") or purl in component_purls:
            return fail(f"missing or duplicate component purl: {purl}")
        component_purls.add(purl)
        name = str(component.get("name") or "unknown")
        version = str(component.get("version") or "unknown")
        component_labels[purl] = f"{name} {version} ({purl})"

    evidence_purls = set(entries)
    missing = sorted(component_purls - evidence_purls)
    stale = sorted(evidence_purls - component_purls)
    if missing:
        return fail(f"{len(missing)} SBOM components lack human-reviewed evidence; first={missing[0]}")
    if stale:
        return fail(f"stale evidence purls; first={stale[0]}")

    groups: dict[tuple[str, str, str], list[str]] = defaultdict(list)
    texts: dict[str, str] = {}
    for purl in sorted(component_purls):
        raw = entries.get(purl)
        if not isinstance(raw, dict):
            return fail(f"malformed evidence entry: {purl}")
        spdx_id = raw.get("spdxId")
        source_url = raw.get("sourceUrl")
        reviewed_hash = str(raw.get("sha256") or "").lower()
        reviewed_by = raw.get("reviewedBy")
        reviewed_at = raw.get("reviewedAt")
        if not isinstance(spdx_id, str) or not SPDX_RE.fullmatch(spdx_id):
            return fail(f"invalid SPDX decision: {purl}")
        if not isinstance(source_url, str) or not source_url.startswith("https://"):
            return fail(f"invalid primary-source URL: {purl}")
        if not SHA256_RE.fullmatch(reviewed_hash):
            return fail(f"invalid reviewed-bytes SHA-256: {purl}")
        if not isinstance(reviewed_by, str) or not reviewed_by.strip():
            return fail(f"missing accountable reviewer: {purl}")
        if not isinstance(reviewed_at, str) or not DATE_RE.fullmatch(reviewed_at):
            return fail(f"invalid review date: {purl}")

        text_path = args.license_text_dir / f"{reviewed_hash}.txt"
        try:
            text_bytes = text_path.read_bytes()
            text = text_bytes.decode("utf-8")
        except (OSError, UnicodeDecodeError) as exc:
            return fail(f"reviewed licence text cannot be read for {purl}: {exc}")
        if not text.strip():
            return fail(f"reviewed licence text is empty: {purl}")
        if sha256_bytes(text_bytes) != reviewed_hash:
            return fail(f"reviewed licence text hash mismatch: {purl}")
        texts[reviewed_hash] = text.rstrip("\n")
        groups[(reviewed_hash, spdx_id, source_url)].append(component_labels[purl])

    try:
        sbom_hash = sha256_bytes(args.sbom.read_bytes())
    except OSError as exc:
        return fail(f"SBOM cannot be hashed: {exc}")
    lines = [
        "KoruBeni THIRD-PARTY SOFTWARE NOTICES",
        "",
        "This file is generated only from accountable human-reviewed licence bytes.",
        f"Candidate SBOM SHA-256: {sbom_hash}",
        f"Components: {len(component_purls)}",
        "",
    ]
    for index, key in enumerate(sorted(groups), start=1):
        reviewed_hash, spdx_id, source_url = key
        lines.extend(
            [
                "=" * 78,
                f"NOTICE {index}",
                f"SPDX decision: {spdx_id}",
                f"Reviewed source: {source_url}",
                f"Reviewed bytes SHA-256: {reviewed_hash}",
                "Components:",
            ]
        )
        lines.extend(f"- {label}" for label in sorted(groups[key]))
        lines.extend(["", texts[reviewed_hash], ""])

    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text("\n".join(lines).rstrip() + "\n", encoding="utf-8")
    print("THIRD_PARTY_NOTICES_PASS")
    print(f"components={len(component_purls)} uniqueTexts={len(groups)} output={args.output}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
