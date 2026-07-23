#!/usr/bin/env python3
"""Harvest exact licence bytes for every SBOM component from resolved artifacts.

This tool removes the mechanical half of the dependency licence review: locating
the exact resolved artifact, reading its licence bytes, and hashing them. It
deliberately does NOT perform the accountable half.

It never:
  * infers, guesses, or emits an SPDX identifier;
  * writes a reviewer identity or review date;
  * writes to `config/dependency_license_evidence.json`;
  * downloads anything (offline by construction, like the notice generator).

The output is a proposal whose root key is `candidates`, not `entries`, so it
can never be renamed into place as accountable human evidence: every consumer of
the real evidence file requires `entries` plus `spdxId`/`reviewedBy`/`reviewedAt`
and will reject this document.

A reviewer still has to open each harvested text, confirm the SPDX identifier
against the complete wording (exceptions, dual licensing, bundled fonts and
native binaries included), and record their own name and UTC date.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import sys
import zipfile
from pathlib import Path
from xml.etree import ElementTree

# Ordered by preference. The artifact's own licence file is primary evidence.
LICENSE_FILE_NAMES = (
    "LICENSE",
    "LICENSE.txt",
    "LICENSE.md",
    "LICENCE",
    "LICENCE.txt",
    "LICENCE.md",
    "COPYING",
    "COPYING.txt",
    "NOTICE",
    "NOTICE.txt",
)

# Defensive cap against a malicious/typosquatted cached artifact shipping a
# LICENSE entry (or POM) that decompresses/expands to gigabytes. This tool is
# offline and only ever runs against the local caches, so the effect would be a
# local memory-exhaustion DoS, never code execution -- but the guard is cheap.
# Overridable for tests via KORUBENI_MAX_LICENSE_BYTES.
def _max_license_bytes() -> int:
    raw = os.environ.get("KORUBENI_MAX_LICENSE_BYTES", "")
    if raw.isdigit() and int(raw) > 0:
        return int(raw)
    return 8 * 1024 * 1024  # 8 MiB; real licence texts are a few KiB.


MAX_LICENSE_BYTES = _max_license_bytes()

PUB_PURL_RE = re.compile(r"^pkg:pub/([^@/]+)@(.+)$")
MAVEN_PURL_RE = re.compile(r"^pkg:maven/([^/]+)/([^@/]+)@(.+)$")
MAVEN_POM_NS = "{http://maven.apache.org/POM/4.0.0}"

PROTECTED_OUTPUTS = (
    Path("config/dependency_license_evidence.json"),
    Path("config/dependency_license_policy.json"),
)


def fail(message: str) -> int:
    print("LICENSE_HARVEST_FAIL", file=sys.stderr)
    print(f"- {message}", file=sys.stderr)
    return 1


def sha256_bytes(value: bytes) -> str:
    return hashlib.sha256(value).hexdigest()


def load_object(path: Path, label: str) -> dict[str, object]:
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, UnicodeDecodeError, json.JSONDecodeError) as exc:
        raise ValueError(f"{label} cannot be read: {exc}") from exc
    if not isinstance(value, dict):
        raise ValueError(f"{label} root must be an object")
    return value


def decode_utf8(raw: bytes) -> str | None:
    """Return text only when the bytes are valid UTF-8.

    The evidence schema stores reviewed bytes as UTF-8 text. Anything else is
    reported as unresolved rather than silently transcoded, because a lossy
    conversion would break the byte-for-byte hash contract.
    """
    try:
        return raw.decode("utf-8")
    except UnicodeDecodeError:
        return None


def read_pub_license(pub_cache: Path, name: str, version: str) -> tuple[str, str] | None:
    """Return (source label, text) from the resolved pub artifact."""
    hosted = pub_cache / "hosted"
    if not hosted.is_dir():
        return None
    for host_dir in sorted(p for p in hosted.glob("*") if p.is_dir()):
        package_dir = host_dir / f"{name}-{version}"
        if not package_dir.is_dir():
            continue
        for candidate in LICENSE_FILE_NAMES:
            license_path = package_dir / candidate
            if not license_path.is_file():
                continue
            try:
                if license_path.stat().st_size > MAX_LICENSE_BYTES:
                    continue
                raw = license_path.read_bytes()
            except OSError:
                continue
            text = decode_utf8(raw)
            if text is None:
                continue
            label = f"pub-cache:{host_dir.name}/{package_dir.name}/{candidate}"
            return label, text
    return None


def read_flutter_sdk_license(flutter_root: Path, name: str) -> tuple[str, str] | None:
    """Resolve licence bytes for SDK-vendored packages (flutter, sky_engine, ...).

    These resolve to version `0.0.0` and never appear in the pub cache. The
    per-package file is preferred; the SDK-wide LICENSE is recorded explicitly
    as such so a reviewer can see the text is not package-specific.
    """
    if not flutter_root.is_dir():
        return None
    searched = (
        (f"packages/{name}/LICENSE", "package"),
        (f"bin/cache/pkg/{name}/LICENSE", "package"),
        ("LICENSE", "sdk-wide"),
    )
    for relative, scope in searched:
        license_path = flutter_root / relative
        if not license_path.is_file():
            continue
        try:
            if license_path.stat().st_size > MAX_LICENSE_BYTES:
                continue
            raw = license_path.read_bytes()
        except OSError:
            continue
        text = decode_utf8(raw)
        if text is None:
            continue
        return f"flutter-sdk[{scope}]:{relative}", text
    return None


def maven_version_dir(gradle_cache: Path, group: str, artifact: str, version: str) -> Path | None:
    base = gradle_cache / "modules-2" / "files-2.1" / group / artifact / version
    return base if base.is_dir() else None


def read_maven_bundled_license(version_dir: Path) -> tuple[str, str] | None:
    """Read a licence file bundled inside the resolved jar/aar."""
    archives = sorted(
        path
        for path in version_dir.rglob("*")
        if path.is_file() and path.suffix in (".jar", ".aar")
    )
    for archive in archives:
        try:
            with zipfile.ZipFile(archive) as bundle:
                members = {
                    info.filename: info
                    for info in bundle.infolist()
                    if not info.is_dir()
                }
                for candidate in LICENSE_FILE_NAMES:
                    for prefix in ("", "META-INF/"):
                        member = f"{prefix}{candidate}"
                        info = members.get(member)
                        if info is None:
                            continue
                        # Trust the declared uncompressed size as a cheap bound;
                        # skip anything implausibly large before reading it in.
                        if info.file_size > MAX_LICENSE_BYTES:
                            continue
                        raw = bundle.read(member)
                        text = decode_utf8(raw)
                        if text is None:
                            continue
                        return f"gradle-cache:{archive.name}!/{member}", text
        except (OSError, zipfile.BadZipFile, KeyError):
            continue
    return None


def read_maven_pom_declaration(version_dir: Path) -> dict[str, str] | None:
    """Return the POM's declared licence name/url.

    This is registry metadata -- a fact about the published POM, not a licence
    decision. It is recorded so the reviewer knows where upstream points, and is
    never promoted to an SPDX identifier by this tool.
    """
    poms = sorted(path for path in version_dir.rglob("*.pom") if path.is_file())
    for pom in poms:
        try:
            if pom.stat().st_size > MAX_LICENSE_BYTES:
                continue
            root = ElementTree.parse(pom).getroot()
        except (OSError, ElementTree.ParseError):
            continue
        licenses = root.find(f"{MAVEN_POM_NS}licenses")
        if licenses is None:
            licenses = root.find("licenses")
        if licenses is None:
            continue
        for node in list(licenses):
            name_node = node.find(f"{MAVEN_POM_NS}name")
            if name_node is None:
                name_node = node.find("name")
            url_node = node.find(f"{MAVEN_POM_NS}url")
            if url_node is None:
                url_node = node.find("url")
            name = (name_node.text or "").strip() if name_node is not None else ""
            url = (url_node.text or "").strip() if url_node is not None else ""
            if not name and not url:
                continue
            return {"declaredName": name, "declaredUrl": url, "pomFile": pom.name}
    return None


def build_candidate(
    purl: str,
    pub_cache: Path,
    gradle_cache: Path,
    flutter_root: Path,
) -> dict[str, object]:
    pub_match = PUB_PURL_RE.match(purl)
    if pub_match:
        name, version = pub_match.group(1), pub_match.group(2)
        registry = f"https://pub.dev/packages/{name}/versions/{version}"
        found = read_pub_license(pub_cache, name, version)
        harvest_kind = "pub-artifact-license-file"
        if found is None:
            # SDK-vendored packages resolve to 0.0.0 and ship inside the SDK.
            found = read_flutter_sdk_license(flutter_root, name)
            harvest_kind = "flutter-sdk-license-file"
        if found is None:
            return {
                "status": "UNRESOLVED",
                "reason": "no UTF-8 licence file in the resolved pub cache or Flutter SDK",
                "registryReference": registry,
            }
        label, text = found
        return {
            "status": "HUMAN_REVIEW_REQUIRED",
            "sha256": sha256_bytes(text.encode("utf-8")),
            "harvestKind": harvest_kind,
            "harvestedFrom": label,
            "registryReference": registry,
            "_text": text,
        }

    maven_match = MAVEN_PURL_RE.match(purl)
    if maven_match:
        group, artifact, version = maven_match.groups()
        registry = (
            "https://repo1.maven.org/maven2/"
            f"{group.replace('.', '/')}/{artifact}/{version}/"
        )
        version_dir = maven_version_dir(gradle_cache, group, artifact, version)
        if version_dir is None:
            return {
                "status": "UNRESOLVED",
                "reason": "module version is not present in the local Gradle cache",
                "registryReference": registry,
            }
        record: dict[str, object] = {"registryReference": registry}
        declaration = read_maven_pom_declaration(version_dir)
        if declaration is not None:
            # Recorded as an upstream fact, never as an SPDX decision.
            record["pomDeclaration"] = declaration
        bundled = read_maven_bundled_license(version_dir)
        if bundled is None:
            record["status"] = "UNRESOLVED"
            record["reason"] = (
                "no UTF-8 licence file bundled in the resolved jar/aar; "
                "reviewer must fetch the primary upstream text"
            )
            return record
        label, text = bundled
        record["status"] = "HUMAN_REVIEW_REQUIRED"
        record["sha256"] = sha256_bytes(text.encode("utf-8"))
        record["harvestKind"] = "maven-artifact-license-file"
        record["harvestedFrom"] = label
        record["_text"] = text
        return record

    return {"status": "UNRESOLVED", "reason": "unsupported purl type for offline harvesting"}


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Harvest exact licence bytes for SBOM components (no SPDX inference)."
    )
    parser.add_argument("--sbom", required=True, type=Path)
    parser.add_argument(
        "--evidence",
        required=True,
        type=Path,
        help="Accountable human evidence file; read only, never written.",
    )
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--text-output-dir", required=True, type=Path)
    parser.add_argument("--pub-cache", type=Path, default=Path.home() / ".pub-cache")
    parser.add_argument("--gradle-cache", type=Path, default=Path.home() / ".gradle" / "caches")
    parser.add_argument(
        "--flutter-root",
        type=Path,
        default=Path(os.environ.get("FLUTTER_ROOT", "")),
        help="Flutter SDK root for SDK-vendored packages; defaults to $FLUTTER_ROOT.",
    )
    parser.add_argument(
        "--require-complete",
        action="store_true",
        help="Exit non-zero unless every component has harvested bytes or reviewed evidence.",
    )
    args = parser.parse_args()

    for protected in PROTECTED_OUTPUTS:
        try:
            same = args.output.resolve() == protected.resolve()
        except OSError:
            same = False
        if same:
            return fail(
                f"refusing to write {protected}; harvested bytes are not accountable evidence"
            )

    try:
        sbom = load_object(args.sbom, "SBOM")
        evidence = load_object(args.evidence, "licence evidence")
    except ValueError as exc:
        return fail(str(exc))

    if sbom.get("bomFormat") != "CycloneDX":
        return fail("SBOM is not CycloneDX")
    components = sbom.get("components")
    if not isinstance(components, list) or not components:
        return fail("SBOM components are missing")
    reviewed = evidence.get("entries")
    if not isinstance(reviewed, dict):
        return fail("licence evidence entries must be an object")

    purls: list[str] = []
    for component in components:
        if not isinstance(component, dict):
            return fail("malformed SBOM component")
        purl = component.get("purl")
        if not isinstance(purl, str) or not purl.startswith("pkg:"):
            return fail(f"missing component purl: {purl}")
        purls.append(purl)
    if len(set(purls)) != len(purls):
        return fail("duplicate component purl in SBOM")

    try:
        args.text_output_dir.mkdir(parents=True, exist_ok=True)
    except OSError as exc:
        return fail(f"cannot create text output directory: {exc}")

    candidates: dict[str, object] = {}
    harvested = 0
    unresolved = 0
    already_reviewed = 0

    for purl in sorted(purls):
        if purl in reviewed:
            already_reviewed += 1
            candidates[purl] = {"status": "ALREADY_REVIEWED"}
            continue
        record = build_candidate(purl, args.pub_cache, args.gradle_cache, args.flutter_root)
        text = record.pop("_text", None)
        if isinstance(text, str):
            digest = record["sha256"]
            if not isinstance(digest, str):
                return fail(f"internal error: missing digest for {purl}")
            target = args.text_output_dir / f"{digest}.txt"
            # Byte-exact I/O only. Text mode would apply universal-newline
            # translation and silently break the hash-for-bytes contract that
            # the whole evidence chain depends on.
            payload = text.encode("utf-8")
            try:
                if not target.exists():
                    target.write_bytes(payload)
                elif target.read_bytes() != payload:
                    return fail(f"hash collision writing reviewed bytes for {purl}")
            except OSError as exc:
                return fail(f"cannot write reviewed bytes for {purl}: {exc}")
            record["licenseTextFile"] = f"{digest}.txt"
            harvested += 1
        else:
            unresolved += 1
        candidates[purl] = record

    proposal = {
        "schemaVersion": 1,
        "documentKind": "unreviewed-license-harvest",
        "notEvidence": (
            "Harvested bytes only. No SPDX decision, reviewer identity, or review "
            "date is present or implied. No release gate accepts this file."
        ),
        "componentCount": len(purls),
        "summary": {
            "alreadyReviewed": already_reviewed,
            "harvestedAwaitingReview": harvested,
            "unresolved": unresolved,
        },
        "candidates": candidates,
    }

    try:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(
            json.dumps(proposal, indent=2, sort_keys=True, ensure_ascii=False) + "\n",
            encoding="utf-8",
        )
    except OSError as exc:
        return fail(f"cannot write proposal: {exc}")

    print(
        f"LICENSE_HARVEST_OK components={len(purls)} reviewed={already_reviewed} "
        f"harvested={harvested} unresolved={unresolved}"
    )
    print(f"- proposal: {args.output}")
    print(f"- reviewed bytes: {args.text_output_dir}")
    print("- SPDX identifier, reviewer and date remain HUMAN_REVIEW_REQUIRED.")

    if args.require_complete and unresolved:
        return fail(f"{unresolved} components still lack harvested licence bytes")
    return 0


if __name__ == "__main__":
    sys.exit(main())
