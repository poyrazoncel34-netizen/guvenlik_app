#!/usr/bin/env python3
"""Shared plumbing for the audit evidence verifiers.

Why this exists
---------------
The convergence queue's dominant cluster was 135 requirement rows whose evidence
was one section-level sentence pasted verbatim. Replacing that with 135 NEW
sentences would reproduce the defect in different words. So each of those rows
instead cites a *property* of a machine-readable artifact produced by a verifier
in this package, and the verifier is required to be able to fail.

Contract every verifier in this package obeys
---------------------------------------------
1.  Output is JSON under ``docs/audit/evidence/``.
2.  Every artifact carries ``verifier``, ``verifierVersion``, ``codeRevision``,
    ``command``, ``surfaces``, ``measurements``, ``violations``, ``exclusions``.
3.  ``codeRevision`` is the git revision of the tree that was measured, plus a
    dirty flag. Evidence that cannot name the tree it proves is not evidence.
4.  Wall-clock time is recorded at DAY resolution only (``measuredOn``), which
    matches the ``docs/audit/device-verification-YYYY-MM-DD-*.md`` convention
    already in this repository. A second-resolution stamp would make every
    regeneration a diff, which is exactly the volatile-generated-content problem
    the repo avoids elsewhere.
5.  Every verifier exposes ``--negative-control``. That mode runs the SAME
    measurement code over a deliberately broken copy of the input and asserts it
    reports violations. A verifier that cannot be shown to fail is worse than no
    verifier, because it launders an unproven claim into a green artifact.
"""

from __future__ import annotations

import json
import re
import subprocess
import sys
from datetime import date
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
EVIDENCE_DIR = REPO / "docs" / "audit" / "evidence"


# ---------------------------------------------------------------------------
# provenance
# ---------------------------------------------------------------------------
def code_revision() -> dict:
    """The revision of the tree being measured, and whether it is dirty."""
    try:
        head = subprocess.run(
            ["git", "rev-parse", "HEAD"],
            cwd=REPO, capture_output=True, text=True, check=True,
        ).stdout.strip()
        porcelain = subprocess.run(
            ["git", "status", "--porcelain"],
            cwd=REPO, capture_output=True, text=True, check=True,
        ).stdout.strip()
    except (subprocess.CalledProcessError, FileNotFoundError):
        return {"head": "unknown", "dirty": None}
    return {"head": head, "dirty": bool(porcelain)}


def emit(
    name: str,
    verifier: str,
    version: str,
    command: str,
    surfaces: list,
    measurements: dict,
    violations: list,
    exclusions: list | None = None,
    extra: dict | None = None,
    out_dir: Path | None = None,
) -> Path:
    """Writes one evidence artifact and returns its path."""
    payload = {
        "verifier": verifier,
        "verifierVersion": version,
        "codeRevision": code_revision(),
        "measuredOn": date.today().isoformat(),
        "command": command,
        "surfaces": surfaces,
        "measurements": measurements,
        "violations": violations,
        "exclusions": exclusions or [],
    }
    if extra:
        payload.update(extra)
    target = (out_dir or EVIDENCE_DIR) / name
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(
        json.dumps(payload, ensure_ascii=False, indent=2, sort_keys=False) + "\n",
        encoding="utf-8",
    )
    return target


# ---------------------------------------------------------------------------
# dart source access
# ---------------------------------------------------------------------------
_LINE_COMMENT = re.compile(r"//.*$", re.M)
_BLOCK_COMMENT = re.compile(r"/\*.*?\*/", re.S)


def dart_files(root: Path | None = None, subdirs: tuple = ("lib",)) -> list:
    base = root or REPO
    out = []
    for sub in subdirs:
        out.extend(sorted((base / sub).rglob("*.dart")))
    return out


def strip_comments(src: str) -> str:
    """Removes comments so a doc-comment mentioning a value is never counted.

    This matters: `design_tokens.dart` documents the exact literals it replaced
    inside its own doc comments. A naive scan reads those as live code and
    reports the token file as its own worst offender.
    """
    src = _BLOCK_COMMENT.sub("", src)
    return _LINE_COMMENT.sub("", src)


def read_stripped(path: Path) -> str:
    return strip_comments(path.read_text(encoding="utf-8"))


def rel(path: Path, root: Path | None = None) -> str:
    """Repo-relative path.

    ``root`` matters: the negative-control harness measures a COPY of the tree in
    a temp directory, and without it every path there falls through to an
    absolute string. Allow-list keys then match nothing, the control's baseline
    fills with phantom violations, and the mutation signal is buried in noise.
    """
    for base in (root, REPO):
        if base is None:
            continue
        try:
            return str(path.relative_to(base))
        except ValueError:
            continue
    return str(path)


# ---------------------------------------------------------------------------
# colour maths (WCAG 2.1)
# ---------------------------------------------------------------------------
def parse_argb(literal: str) -> tuple:
    """`0xFF2EC5FF` -> (a, r, g, b)."""
    value = int(literal, 16)
    return ((value >> 24) & 0xFF, (value >> 16) & 0xFF, (value >> 8) & 0xFF, value & 0xFF)


def _channel(c: int) -> float:
    s = c / 255.0
    return s / 12.92 if s <= 0.04045 else ((s + 0.055) / 1.055) ** 2.4


def relative_luminance(rgb: tuple) -> float:
    r, g, b = rgb
    return 0.2126 * _channel(r) + 0.7152 * _channel(g) + 0.0722 * _channel(b)


def contrast_ratio(fg: tuple, bg: tuple) -> float:
    l1, l2 = relative_luminance(fg), relative_luminance(bg)
    if l1 < l2:
        l1, l2 = l2, l1
    return (l1 + 0.05) / (l2 + 0.05)


def composite(fg_argb: tuple, bg_rgb: tuple) -> tuple:
    """Alpha-composites a translucent colour over an opaque background.

    Required for this palette: `glass`, `glassBorder` and every `withValues`
    tint are translucent, and comparing their raw RGB against a background is
    a measurement of a colour that never reaches a pixel.
    """
    a, r, g, b = fg_argb
    alpha = a / 255.0
    return (
        round(r * alpha + bg_rgb[0] * (1 - alpha)),
        round(g * alpha + bg_rgb[1] * (1 - alpha)),
        round(b * alpha + bg_rgb[2] * (1 - alpha)),
    )


# ---------------------------------------------------------------------------
# negative-control harness
# ---------------------------------------------------------------------------
def run_negative_control(name: str, mutate, measure) -> int:
    """Applies [mutate] to a scratch copy of the tree, then asserts [measure] fails.

    ``mutate`` receives a temp directory containing a copy of ``lib/`` (and
    whatever else the verifier asked for) and introduces the defect.
    ``measure`` receives the same directory and returns the violation list.
    """
    import shutil
    import tempfile

    with tempfile.TemporaryDirectory() as tmp:
        scratch = Path(tmp)
        shutil.copytree(REPO / "lib", scratch / "lib")
        # Every directory a verifier READS has to be here, not just lib/.
        # Twice now a verifier grew a rule over a file outside lib/ and the
        # control reported a FALSE violation at baseline (docs/ for the
        # forced-colour write-up, store/ for the manual smoke script). A
        # baseline that is already red hides whether the mutation did anything,
        # and a mutation that cannot reach its target proves nothing.
        for extra in ("assets", "test", "docs", "store", "config"):
            src = REPO / extra
            if src.exists():
                shutil.copytree(src, scratch / extra, dirs_exist_ok=True)
        baseline = measure(scratch)
        description = mutate(scratch)
        mutated = measure(scratch)

    if len(mutated) <= len(baseline):
        print(
            "NEGATIVE_CONTROL_FAIL %s: mutation %r produced %d violations, baseline "
            "had %d. The verifier cannot observe the defect it claims to guard."
            % (name, description, len(mutated), len(baseline))
        )
        return 1
    print(
        "NEGATIVE_CONTROL_PASS %s: mutation %r moved violations %d -> %d"
        % (name, description, len(baseline), len(mutated))
    )
    return 0


def main_guard(argv: list) -> bool:
    """True when the caller was asked for its negative control."""
    return "--negative-control" in argv


if __name__ == "__main__":  # pragma: no cover - smoke check
    print(json.dumps(code_revision()))
    sys.exit(0)
