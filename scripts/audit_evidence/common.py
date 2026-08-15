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
3.  ``codeRevision.verifiedCodeRevision`` is the CLEAN commit whose measured
    surface produced the artifact, with ``dirty: false`` and the tree hash.
    Evidence that cannot name the tree it proves is not evidence, and a stamp
    reading ``dirty: true`` names no tree at all -- so a verifier REFUSES to
    emit from a dirty worktree rather than writing an unreconstructable claim.
    The commit that CONTAINS the artifact is necessarily later; that
    documentation head is recorded in PRODUCTION_AUDIT.md, not guessed at here.
4.  Wall-clock time is recorded at DAY resolution only (``measuredOn``), which
    matches the ``docs/audit/device-verification-YYYY-MM-DD-*.md`` convention
    already in this repository. A second-resolution stamp would make every
    regeneration a diff, which is exactly the volatile-generated-content problem
    the repo avoids elsewhere.
5.  Every verifier exposes ``--negative-control``. That mode runs the SAME
    measurement code over a deliberately broken copy of the input and asserts it
    reports violations. A verifier that cannot be shown to fail is worse than no
    verifier, because it launders an unproven claim into a green artifact.
6.  A negative control names the RULES it trips (``expect_rules``), and each of
    them must strictly increase. A control is therefore evidence about those
    rules and nothing else. Measurements with no violation rule behind them are
    CENSUS values: their credibility comes from being computed from the tree and
    reproducible at a named revision, not from a mutation. Each verifier
    declares which of its cited properties are ENFORCED and which are CENSUS in
    its ``propertyClasses`` block, and no artifact may claim a control proves a
    property no rule guards.
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
# Paths a verifier WRITES. A tree that is dirty only here is still a faithful
# copy of the revision being measured: running verifier #2 after verifier #1 has
# written its artifact must not make #2 refuse to run.
_EVIDENCE_OUTPUT_PREFIX = "docs/audit/evidence/"


def _git(*args) -> str:
    return subprocess.run(
        ["git", *args], cwd=REPO, capture_output=True, text=True, check=True,
    ).stdout.strip()


def code_revision() -> dict:
    """The revision of the tree being measured, and whether it is dirty.

    The provenance model, stated once
    ---------------------------------
    An evidence artifact names the **verified implementation revision**: the
    clean commit whose lib/, test/, assets/ and verifier sources were measured.
    That is NOT always the final HEAD, and pretending otherwise would be a
    self-referential impossibility -- committing an artifact changes the tree,
    so no artifact can ever name the commit that contains it. A later
    documentation/evidence commit may therefore sit on top; the difference is
    explicit in PRODUCTION_AUDIT.md and PROGRESS.md rather than hidden.

    What is NOT tolerated is `dirty: true`. A dirty tree corresponds to no
    commit at all, so an artifact stamped with one cannot be reconstructed by
    anybody -- which is the whole job of the stamp. The previous artifacts all
    carried a stale, dirty revision four commits behind HEAD (FIR-04). Changes
    confined to the evidence directory are exempt, because those are this
    package's own output, not the surface it measures.
    """
    try:
        head = _git("rev-parse", "HEAD")
        porcelain = _git("status", "--porcelain")
        tree = _git("rev-parse", "HEAD^{tree}")
    except (subprocess.CalledProcessError, FileNotFoundError):
        return {"verifiedCodeRevision": "unknown", "dirty": None, "treeHash": None,
                "dirtyPaths": []}

    # `line[2:]` then strip: porcelain v1 puts a two-character status first for
    # every case (" M", "??", "M ", "A "), so slicing at 2 and stripping is the
    # form that cannot eat the first character of the path.
    changed = [line[2:].strip() for line in porcelain.splitlines() if line.strip()]
    dirty_paths = sorted(
        path for path in changed if not path.startswith(_EVIDENCE_OUTPUT_PREFIX)
    )
    return {
        "verifiedCodeRevision": head,
        "dirty": bool(dirty_paths),
        "treeHash": tree,
        "dirtyPaths": dirty_paths[:20],
        "note": (
            "verifiedCodeRevision is the commit whose measured surface produced "
            "this artifact. A later commit may CONTAIN this file; that is the "
            "documentation head, and the two are distinguished in "
            "PRODUCTION_AUDIT.md. Changes under docs/audit/evidence/ are this "
            "package's own output and do not make the measured tree dirty."
        ),
    }


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
    baseline_semantics: str | None = None,
) -> Path:
    """Writes one evidence artifact and returns its path.

    ``baseline_semantics`` is REQUIRED reading whenever ``violations`` is
    non-empty: a verifier that reports violations and is filed as evidence must
    say whether they are a real open finding, an intentionally non-zero census,
    or a rule defect. Silence there is how a red baseline gets read as clean
    (FIR-06).
    """
    revision = code_revision()
    if revision.get("dirty"):
        raise SystemExit(
            f"REFUSING_TO_EMIT {name}: the working tree is dirty outside "
            f"docs/audit/evidence/, so this measurement corresponds to no "
            f"commit and nobody could reproduce it. Commit or stash first.\n"
            f"  dirty: {', '.join(revision['dirtyPaths'][:10])}"
        )
    if violations and not baseline_semantics:
        raise ValueError(
            f"{name}: {len(violations)} baseline violations with no "
            f"baseline_semantics. Say what they mean."
        )
    payload = {
        "verifier": verifier,
        "verifierVersion": version,
        "codeRevision": revision,
        "measuredOn": date.today().isoformat(),
        "command": command,
        "surfaces": surfaces,
        "measurements": measurements,
        "violations": violations,
        "baseline": {
            "violationCount": len(violations),
            "semantics": baseline_semantics or (
                "0 violations: every rule this verifier emits is currently "
                "satisfied by the measured tree."
            ),
        },
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
# property classification (ENFORCED vs CENSUS)
# ---------------------------------------------------------------------------
_RULE_LITERAL = re.compile(r"""["']rule["']\s*:\s*["']([A-Za-z0-9_]+)["']""")
_MEASURE_DEF = re.compile(r"^def measure\(", re.M)
_NEXT_DEF = re.compile(r"^def ", re.M)


def _measure_body(source: str) -> str:
    """The text of ``measure()``, the only function that emits violations."""
    start = _MEASURE_DEF.search(source)
    if not start:
        return ""
    rest = source[start.end():]
    end = _NEXT_DEF.search(rest)
    return rest[: end.start()] if end else rest


def _walk(measurements, prefix=""):
    for key, value in measurements.items():
        path = f"{prefix}{key}"
        yield path, key
        if isinstance(value, dict):
            yield from _walk(value, prefix=f"{path}.")


def property_classes(measurements: dict, verifier: Path, controlled_rules) -> dict:
    """Splits the cited measurement surface into ENFORCED and CENSUS.

    Why this exists
    ---------------
    The audit repeated one sentence under ~198 rows: "the cited property is the
    measurement, and the negative control shows the verifier can report the
    opposite." That is false for most of them. ``run_negative_control`` used to
    compare TOTAL violation counts for a whole verifier, so a control that broke
    the gutter-symmetry rule was cited as proof for eighteen other ``layout.py``
    properties it never touched (FIR-06).

    The classification criterion is mechanical and stated so a reader can check
    it: a property is ENFORCED when its own name is read by ``measure()`` -- the
    function that produces violations -- and CENSUS otherwise. A CENSUS value is
    a computed fact about the tree. Its credibility comes from being derived
    rather than typed, and from reproducing at a named revision; it does NOT come
    from a mutation, and no artifact may claim otherwise.
    """
    body = _measure_body(verifier.read_text(encoding="utf-8"))
    emitted = sorted(set(_RULE_LITERAL.findall(verifier.read_text(encoding="utf-8"))))
    enforced, census = [], []
    for path, leaf in _walk(measurements):
        target = enforced if (f'"{leaf}"' in body or f"'{leaf}'" in body) else census
        target.append(path)
    return {
        "criterion": (
            "ENFORCED = the property's name is read by measure(), the function "
            "that emits violations. CENSUS = a computed fact with no violation "
            "rule behind it; it is credible because it is derived and "
            "reproducible at a named revision, NOT because a mutation moved it."
        ),
        "rulesEmitted": emitted,
        "rulesUnderNegativeControl": sorted(controlled_rules or []),
        "rulesEmittedWithoutControl": sorted(
            set(emitted) - set(controlled_rules or [])
        ),
        "enforcedProperties": enforced,
        "censusProperties": census,
    }


# ---------------------------------------------------------------------------
# negative-control harness
# ---------------------------------------------------------------------------
def run_negative_control(name: str, mutate, measure, expect_rules=None) -> int:
    """Applies [mutate] to a scratch copy of the tree, then asserts [measure] fails.

    ``mutate`` receives a temp directory containing a copy of ``lib/`` (and
    whatever else the verifier asked for) and introduces the defect.
    ``measure`` receives the same directory and returns the violation list.

    ``expect_rules`` names the RULES the mutation is supposed to trip. Without
    it this harness only compared TOTAL violation counts, which is why the
    audit's boilerplate "the negative control shows the verifier can report the
    opposite" was overstated: a verifier exposing nineteen cited properties and
    guarding one of them with a rule would satisfy a total-count check while
    proving nothing about the other eighteen (FIR-06). With it, each named rule
    must strictly increase, so the control demonstrates THAT rule firing rather
    than some rule firing.
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
        # Manifest FILES, not just directories. Without pubspec.yaml, assets.py
        # cannot see `uses-material-design: true` and reported
        # materialIconFontNotDeclared at BASELINE -- a phantom violation in the
        # control only, which is exactly the red baseline the comment above
        # warns about (FIR-06).
        for manifest in ("pubspec.yaml", "pubspec.lock", "analysis_options.yaml"):
            src = REPO / manifest
            if src.exists():
                shutil.copy2(src, scratch / manifest)
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

    def _by_rule(violations):
        counts = {}
        for violation in violations:
            rule = violation.get("rule", "<unnamed>")
            counts[rule] = counts.get(rule, 0) + 1
        return counts

    before, after = _by_rule(baseline), _by_rule(mutated)
    if expect_rules:
        missed = [
            rule for rule in expect_rules
            if after.get(rule, 0) <= before.get(rule, 0)
        ]
        if missed:
            print(
                "NEGATIVE_CONTROL_FAIL %s: mutation %r did not trip %s. Totals "
                "moved %d -> %d, but a total that moves proves only that SOME "
                "rule fired." % (name, description, missed, len(baseline), len(mutated))
            )
            return 1
    fired = sorted(
        "%s %d->%d" % (rule, before.get(rule, 0), after[rule])
        for rule in after
        if after[rule] > before.get(rule, 0)
    )
    if before:
        print(
            "NEGATIVE_CONTROL_BASELINE %s: %d pre-existing violation(s): %s"
            % (name, len(baseline), sorted(before.items()))
        )
    print(
        "NEGATIVE_CONTROL_PASS %s: mutation %r moved violations %d -> %d; rules "
        "fired: %s" % (name, description, len(baseline), len(mutated), fired)
    )
    return 0


def main_guard(argv: list) -> bool:
    """True when the caller was asked for its negative control."""
    return "--negative-control" in argv


if __name__ == "__main__":  # pragma: no cover - smoke check
    print(json.dumps(code_revision()))
    sys.exit(0)
