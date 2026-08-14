# Device verification — forced colours / high contrast (MP-12-029)

**Date:** 2026-08-15
**Device:** emulator `Medium_Phone_API_36.1`, Android API 36, 1080×2400
**Build under test:** `build/app/outputs/flutter-apk/app-play-debug.apk`, installed as
`com.poyrazoncel.korubeni`
**Flutter:** 3.38.9 stable · engine `5eb06b7ad5bb8cbc22c5230264c7a00ceac7674b` · Dart 3.10.8
(recorded by `scripts/audit_evidence/a11y_platform.py`, not typed by hand)

## Why the obvious test would have been vacuous

The natural way to answer "is high-contrast behaviour tested" is
`MediaQuery.highContrastOf(context)`. In **this** SDK that flag's own documentation, in
`bin/cache/pkg/sky_engine/lib/ui/window.dart`, reads:

> The platform is requesting that UI be rendered with darker colors.
> Only supported on iOS.

So on Android it is a constant `false`. A test written against it would be green forever
and would measure nothing — the same shape as the `oldVersion < 1` migration branch and the
`_sites(root, "partial")` measurement this audit has already caught. The verifier therefore
**parses the installed SDK** and reports support per flag rather than asserting it:

| flag | SDK doc limitation | delivered on Android |
|---|---|---|
| `accessibleNavigation` | — | yes |
| `invertColors` | — | yes |
| `disableAnimations` | — | yes |
| `boldText` | iOS and Android API 31+ | yes |
| `reduceMotion` | iOS | **no** |
| `highContrast` | iOS | **no** |
| `onOffSwitchLabels` | iOS | **no** |

## Measurement 1 — Android's high-contrast text does not reach Flutter content

Procedure, all four captures on the consent screen (dense text, several colour roles):

```
adb exec-out screencap -p > 00_baseline.png
adb shell settings put secure high_text_contrast_enabled 1
adb exec-out screencap -p > 01_high_contrast_text.png
```

Pixel diff of the decoded PNGs, counted per row:

```
image 1080x2400
changed pixels in status bar (y<100):        3361
changed pixels in APP CONTENT (y>=100):         0
changed rows: 9,10,11,12,13,14 ... 49,50,51
```

**The 3361 changed pixels are the built-in positive control.** They are the SystemUI clock,
an Android *View*, which Android repainted with the high-contrast background box. The
setting was unambiguously active. Zero pixels of Flutter-drawn content changed.

Conclusion, and it is a platform fact rather than an app defect: Android's high-contrast
text is a **View-layer render override**. Flutter draws into its own Surface, so the setting
neither repaints Flutter text nor is reported to the app. There is no flag for it in this
SDK to consume.

## Measurement 2 — a screenshot is the WRONG instrument for colour inversion

```
adb shell settings put secure accessibility_display_inversion_enabled 1   # verified: reads 1
adb shell am force-stop … && am start …                                   # fresh process
adb exec-out screencap -p > 04_invert_after_relaunch.png
```

The app's pixels came back **identical** to baseline; the only byte difference in the file
was the status-bar clock advancing 10:11 → 10:12. Inversion is applied by the display
pipeline *below* the point `screencap` captures, so a screenshot comparison here is a false
negative machine.

This is recorded rather than smoothed, because the tempting write-up — "inversion had no
effect" — would have been wrong, and it is the same class of error as the `dumpsys gfxinfo`
finding already in this repository: right number, wrong instrument.

## What this means for the requirement, and what is enforced instead

Neither an OEM forced palette, nor colour inversion, nor a colour-correction filter can be
observed from inside the app on this platform. What they all share is that they **rewrite
every colour and preserve everything else**. So the durable, checkable property is not "does
the app react to a high-contrast flag" — it cannot — but:

> no critical surface may carry its meaning by colour alone.

A surface that also has an icon, a border, a weight difference, text, or a semantics label
still says what it means after any palette transform. That is measured per surface by
`measurements.colourIndependence` in `docs/audit/evidence/a11y_platform.json`, enforced by
`test/screens/forced_colors_test.dart` (which renders the critical surfaces with **every
colour collapsed to one value** and asserts the states remain distinguishable), and it is
the only claim here that is actually provable.

## Honest limits

- Physical-device behaviour under an **OEM** forced palette (Samsung/Xiaomi skins ship their
  own) is not covered; the emulator has no such mode. That is the same class of gap as the
  OEM battery-saver row and belongs with the physical-device matrix, not here.
- `boldText` is delivered on Android API 31+ but is not consumed by this app. It is reported
  in the artifact rather than silently ignored; text already scales via `textScaleFactor`,
  which the layout suite covers at 2.0.
