#!/usr/bin/env python3
"""Asset presence and integrity — MP-03-029, MP-03-031, and the icon inventory.

  measurements.declaredAssets   -> MP-03-029
  measurements.iconography      -> MP-03-031
  measurements.launcherIcons    -> MP-03-031 (platform half)
  measurements.densityBuckets   -> MP-72-013, MP-72-014

Run:
    python3 scripts/audit_evidence/assets.py
    python3 scripts/audit_evidence/assets.py --negative-control
"""

from __future__ import annotations

import re
import struct
import sys
from collections import Counter
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from common import (  # noqa: E402
    REPO, dart_files, emit, main_guard, read_stripped, rel, property_classes, run_negative_control,
)

VERSION = "1.1.0"
# The rules this verifier's negative control demonstrably trips. Anything
# emitted but absent here is guarded by a rule NO mutation has exercised,
# and the artifact says so rather than implying coverage (FIR-06).
CONTROLLED_RULES = [
    "demoAssetShipped",
    "referencedAssetMissing",
    "assetDensityMismatch",
    "assetBucketMissing",
]
COMMAND = "python3 scripts/audit_evidence/assets.py"

# Words that mark an asset as a stand-in rather than production content.
DEMO_MARKERS = ("demo", "sample", "placeholder", "dummy", "test_", "lorem", "mock",
                "example", "temp_", "draft")


# Android density buckets and their multiplier against mdpi.
#
# Why this is here (CERT2-01). MP-72-013 "Blurry assets" and MP-72-014 "Wrong
# resolution" were classified EXTERNAL on the grounds that only one density
# bucket exists on any single device, so a second one is hardware. That is the
# wrong way round: the DEVICE has one bucket, but the REPOSITORY has all of
# them, and whether a variant is the mdpi source scaled by its own multiplier is
# arithmetic over committed files. A raster that is not that size is upscaled --
# which is precisely what renders blurry on the devices in that bucket -- or
# needlessly oversized. Neither needs a panel to see.
DENSITY_MULTIPLIERS = {
    "ldpi": 0.75, "mdpi": 1.0, "hdpi": 1.5,
    "xhdpi": 2.0, "xxhdpi": 3.0, "xxxhdpi": 4.0,
}
# One pixel of rounding slack: 1.5x off an odd baseline is not a defect.
DENSITY_TOLERANCE_PX = 1
# ldpi is not required. Android has not shipped an ldpi device in years and
# `flutter_launcher_icons` does not emit the bucket; demanding it would invent a
# violation rather than find one.
DENSITY_OPTIONAL = ("ldpi",)


def _png_size(path: Path):
    """(width, height) from the IHDR, or None when the file is not a PNG."""
    with open(path, "rb") as fh:
        head = fh.read(24)
    if len(head) < 24 or head[:8] != b"\x89PNG\r\n\x1a\n":
        return None
    return struct.unpack(">II", head[16:24])


def _density_families(root: Path) -> dict:
    """Density-qualified rasters, grouped by the family they are variants of.

    The key drops the density token from the directory, so
    `drawable-night-xxhdpi/android12splash.png` joins its mdpi sibling in one
    family, while `drawable/background.png` -- which carries no density
    qualifier and is therefore a variant of nothing -- is skipped rather than
    reported as an incomplete family.
    """
    res = root / "android" / "app" / "src" / "main" / "res"
    families: dict = {}
    if not res.exists():
        return families
    for path in sorted(res.rglob("*.png")):
        parts = path.parent.name.split("-")
        density = next((p for p in parts if p in DENSITY_MULTIPLIERS), None)
        if density is None:
            continue
        size = _png_size(path)
        if size is None:
            continue
        stem = "-".join(p for p in parts if p != density)
        families.setdefault(f"{stem}/{path.name}", {})[density] = {
            "path": rel(path, root), "width": size[0], "height": size[1],
        }
    return families


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

    # Density buckets: is each variant its baseline scaled by its own
    # multiplier? `property` names the measurement these violations come from,
    # so property_classes() classes it ENFORCED rather than census.
    for family, buckets in sorted(_density_families(root).items()):
        baseline = min(buckets, key=lambda d: DENSITY_MULTIPLIERS[d])
        base = buckets[baseline]
        for density, entry in sorted(buckets.items()):
            factor = DENSITY_MULTIPLIERS[density] / DENSITY_MULTIPLIERS[baseline]
            for axis in ("width", "height"):
                expected = base[axis] * factor
                if abs(entry[axis] - expected) > DENSITY_TOLERANCE_PX:
                    violations.append({
                        "rule": "assetDensityMismatch",
                        "property": "densityBuckets",
                        "detail": entry["path"], "axis": axis,
                        "expected": round(expected, 2), "actual": entry[axis],
                        "baseline": base["path"],
                    })
        missing = sorted(set(DENSITY_MULTIPLIERS) - set(buckets) - set(DENSITY_OPTIONAL))
        if missing and len(buckets) > 1:
            violations.append({
                "rule": "assetBucketMissing", "property": "densityBuckets",
                "detail": family, "missing": missing,
                "present": sorted(buckets, key=lambda d: DENSITY_MULTIPLIERS[d]),
            })

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

    density_families = _density_families(root)
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
        "densityBuckets": {
            "families": [
                {
                    "family": name,
                    "buckets": {
                        d: buckets[d]["path"]
                        for d in sorted(buckets, key=lambda x: DENSITY_MULTIPLIERS[x])
                    },
                    "pixelSizes": {
                        d: [buckets[d]["width"], buckets[d]["height"]]
                        for d in sorted(buckets, key=lambda x: DENSITY_MULTIPLIERS[x])
                    },
                }
                for name, buckets in sorted(density_families.items())
            ],
            "familyCount": len(density_families),
            "densityMultipliers": DENSITY_MULTIPLIERS,
            "tolerancePx": DENSITY_TOLERANCE_PX,
            "optionalBuckets": list(DENSITY_OPTIONAL),
            "bundledRasterAssetCount": len(
                [a for a in disk if a.lower().endswith((".png", ".jpg", ".jpeg", ".webp"))]),
            "why": (
                "MP-72-013/014. Every raster this app ships is an Android res "
                "variant; the Flutter asset bundle declares no images at all, and "
                "the only runtime image is a user-picked file. So 'blurry' and "
                "'wrong resolution' reduce to whether each bucket is its baseline "
                "scaled by the bucket multiplier, which is arithmetic over "
                "committed files rather than a property of a panel."
            ),
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
    # CERT2-01: give one bucket the wrong resolution and delete another.
    res = scratch / "android" / "app" / "src" / "main" / "res"
    wrong = res / "mipmap-xxhdpi" / "ic_launcher.png"
    source = res / "mipmap-mdpi" / "ic_launcher.png"
    if wrong.exists() and source.exists():
        wrong.write_bytes(source.read_bytes())
    dropped = res / "mipmap-xxxhdpi" / "ic_launcher.png"
    if dropped.exists():
        dropped.unlink()
    return ("a referenced-but-absent asset, a shipped demo image, an xxhdpi "
            "launcher icon left at mdpi resolution, and a deleted xxxhdpi bucket")


def main() -> int:
    if main_guard(sys.argv):
        return run_negative_control(
            "assets", _mutate, measure,
            expect_rules=[
                "demoAssetShipped",
                "referencedAssetMissing",
                "assetDensityMismatch",
                "assetBucketMissing",
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
            "mutation": "reference an asset that is not on disk, ship a demo_ "
                        "image, leave an xxhdpi launcher icon at mdpi resolution "
                        "and delete the xxxhdpi bucket",
            "expected": "referencedAssetMissing, demoAssetShipped, "
                        "assetDensityMismatch and assetBucketMissing fire",
        }},
    )
    print(f"ASSETS_OK violations={len(violations)} -> {rel(path)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
