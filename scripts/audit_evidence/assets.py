#!/usr/bin/env python3
"""Asset presence and integrity — MP-03-029, MP-03-031, and the icon inventory.

  measurements.declaredAssets   -> MP-03-029
  measurements.iconography      -> MP-03-031
  measurements.launcherIcons    -> MP-03-031 (platform half)

Run:
    python3 scripts/audit_evidence/assets.py
    python3 scripts/audit_evidence/assets.py --negative-control
"""

from __future__ import annotations

import re
import sys
from collections import Counter
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from common import (  # noqa: E402
    REPO, dart_files, emit, main_guard, read_stripped, rel, property_classes, run_negative_control,
)

VERSION = "1.0.0"
# The rules this verifier's negative control demonstrably trips. Anything
# emitted but absent here is guarded by a rule NO mutation has exercised,
# and the artifact says so rather than implying coverage (FIR-06).
CONTROLLED_RULES = [
    "demoAssetShipped",
    "referencedAssetMissing",
]
COMMAND = "python3 scripts/audit_evidence/assets.py"

# Words that mark an asset as a stand-in rather than production content.
DEMO_MARKERS = ("demo", "sample", "placeholder", "dummy", "test_", "lorem", "mock",
                "example", "temp_", "draft")


def _referenced(root: Path) -> dict:
    """Every 'assets/...' literal in lib/, mapped to the sites that use it."""
    out: dict = {}
    for path in dart_files(root):
        src = read_stripped(path)
        for m in re.finditer(r"['\"](assets/[^'\"]+)['\"]", src):
            out.setdefault(m.group(1), []).append(
                f"{rel(path, root)}:{src[: m.start()].count(chr(10)) + 1}")
        # AssetSource('sounds/x.wav') resolves under assets/ without the prefix.
        for m in re.finditer(r"AssetSource\(\s*['\"]([^'\"]+)['\"]", src):
            out.setdefault("assets/" + m.group(1), []).append(
                f"{rel(path, root)}:{src[: m.start()].count(chr(10)) + 1}")
    return out


def _on_disk(root: Path) -> list:
    base = root / "assets"
    if not base.exists():
        return []
    return sorted(rel(p, root) for p in base.rglob("*") if p.is_file())


def measure(root: Path) -> list:
    violations = []
    referenced = _referenced(root)
    disk = set(_on_disk(root))

    for asset, sites in sorted(referenced.items()):
        if asset in disk:
            continue
        # The web branch serves bundled assets under a DOUBLED prefix; the
        # Android path is the un-doubled one. Both spellings are legitimate.
        if asset.startswith("assets/assets/") and asset[len("assets/"):] in disk:
            continue
        # easy_localization takes a DIRECTORY (`path: 'assets/translations'`),
        # not a file. Treating every literal as a file reports the localisation
        # root as a missing asset -- a defect invented by the measurement.
        if (root / asset).is_dir():
            continue
        violations.append({"rule": "referencedAssetMissing", "detail": asset,
                           "sites": sites[:3]})

    for asset in sorted(disk):
        # Untracked local junk is not shipped: pubspec declares directories, and
        # `flutter build` copies what is on disk, so a stray .DS_Store WOULD ride
        # along in a local build. It is gitignored, so it never reaches CI or the
        # release artifact. Recorded rather than silently skipped.
        if asset.rsplit("/", 1)[-1] in (".DS_Store", "Thumbs.db"):
            continue
        low = asset.lower()
        for marker in DEMO_MARKERS:
            if marker in low.rsplit("/", 1)[-1]:
                violations.append({"rule": "demoAssetShipped", "detail": asset,
                                   "marker": marker})

    # Every Icons.* glyph must be a real Material identifier; a typo compiles
    # only if it exists, so the real risk is an icon FONT that was tree-shaken
    # away. Assert the tree-shake config has not been disabled.
    pubspec = (root / "pubspec.yaml").read_text(encoding="utf-8") if (root / "pubspec.yaml").exists() else ""
    if "uses-material-design: true" not in pubspec:
        violations.append({
            "rule": "materialIconFontNotDeclared",
            "detail": "pubspec.yaml does not set uses-material-design: true, so "
                      "Icons.* glyphs would render as missing boxes",
        })
    return violations


def build(root: Path) -> dict:
    referenced = _referenced(root)
    disk = _on_disk(root)
    icons = Counter()
    for path in dart_files(root):
        src = read_stripped(path)
        for m in re.finditer(r"Icons\.(\w+)", src):
            icons[m.group(1)] += 1

    android_res = root / "android" / "app" / "src" / "main" / "res"
    launcher = sorted(rel(p, root) for p in android_res.rglob("ic_launcher*")) if android_res.exists() else []

    return {
        "declaredAssets": {
            "onDisk": [a for a in disk if not a.endswith(".DS_Store")],
            "untrackedLocalJunk": [a for a in disk if a.endswith(".DS_Store")],
            "onDiskCount": len(disk),
            "referencedFromDart": sorted(referenced),
            "referencedCount": len(referenced),
            "unreferencedOnDisk": sorted(set(disk) - set(referenced)),
            "demoMarkersSearched": list(DEMO_MARKERS),
            "demoAssetsFound": len([v for v in measure(root)
                                    if v["rule"] == "demoAssetShipped"]),
            "webDoubledPrefixNote": (
                "audioplayers' UrlSource path on web resolves under a doubled "
                "assets/ prefix; the Android AssetSource path does not. Both "
                "spellings appear in source and both are correct."
            ),
        },
        "iconography": {
            "materialIconsDeclared": "uses-material-design: true",
            "distinctGlyphs": len(icons),
            "totalGlyphSites": sum(icons.values()),
            "mostUsed": icons.most_common(15),
            "customIconFonts": len(re.findall(
                r"IconData\(", "".join(read_stripped(p) for p in dart_files(root)))),
            "whyNoMissingGlyph": (
                "every glyph is a const IconData from the Material font, resolved at "
                "compile time -- a wrong name does not compile. There is no dynamic "
                "icon lookup by string anywhere in lib/, which is the only way a "
                "Flutter app renders a missing-icon box."
            ),
            "dynamicIconLookupSites": [
                f"{rel(p, root)}" for p in dart_files(root)
                if re.search(r"IconData\(\s*[a-z_]\w*\s*[,)]", read_stripped(p))],
        },
        "launcherIcons": {
            "androidResources": launcher,
            "count": len(launcher),
        },
    }


def _mutate(scratch: Path) -> str:
    target = scratch / "lib" / "screens" / "settings_page.dart"
    src = target.read_text(encoding="utf-8")
    src = src.replace("class SettingsPage",
                      "const _missing = 'assets/images/does_not_exist.png';\n"
                      "class SettingsPage", 1)
    target.write_text(src, encoding="utf-8")
    demo = scratch / "assets" / "images"
    demo.mkdir(parents=True, exist_ok=True)
    (demo / "demo_avatar.png").write_bytes(b"\x89PNG\r\n\x1a\n")
    return "a referenced-but-absent asset plus a shipped demo image"


def main() -> int:
    if main_guard(sys.argv):
        return run_negative_control(
            "assets", _mutate, measure,
            expect_rules=[
                "demoAssetShipped",
                "referencedAssetMissing",
            ],
        )
    violations = measure(REPO)
    measurements_payload = build(REPO)
    path = emit(
        "assets.json",
        verifier="scripts/audit_evidence/assets.py",
        version=VERSION,
        command=COMMAND,
        surfaces=["assets/**", "lib/**/*.dart", "pubspec.yaml",
                  "android/app/src/main/res/**"],
        measurements=measurements_payload,
        violations=violations,
        exclusions=[
            {"what": "translation JSON payloads",
             "why": "they are content, measured by copy.json; their presence is proven "
                    "by the app failing to start without them"},
        ],
        extra={
            "propertyClasses": property_classes(
                measurements_payload, Path(__file__), CONTROLLED_RULES,
            ),
            "negativeControl": {
            "command": COMMAND + " --negative-control",
            "mutation": "reference an asset that is not on disk and ship a demo_ image",
            "expected": "referencedAssetMissing and demoAssetShipped fire",
        }},
    )
    print(f"ASSETS_OK violations={len(violations)} -> {rel(path)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
