# Phase 5 — Store Asset Review Evidence (2026-07-18)

Scope: canonical Google Play files under `store/assets/` and
`store/screenshots/android/final/`. No UI, theme, or visual asset was modified
during this review.

## Mechanical checks

| File | Format / dimensions | SHA-256 | Result |
| --- | --- | --- | --- |
| `play_icon_512.png` | PNG, 512×512, RGBA | `562e390b4188630a372d0fc17a022f5bd0e61b206ac1e87dcc354cc702e0ff7b` | PASS_FORMAT |
| `feature_graphic_1024x500.png` | PNG, 1024×500, RGB/no alpha | `7f32324f9cb4483584e4369a593554484c4cd6f8335b586a8c891e0d2e449128` | PASS_FORMAT |
| `01_home_locked_panic.png` | PNG, 992×1846, RGB | `8ff1f3c74d1d595563f508877e7c34a7165a9ac4e0dd8f3814fa92f8f02fd3c3` | PASS_FORMAT |
| `02_contacts.png` | PNG, 992×1846, RGB | `e35ab069f5c82789dd818e9dfcc85b2e3ec07587283fa968e678e35d92de0719` | PASS_FORMAT |
| `03_settings_legal.png` | PNG, 992×1846, RGB | `9082d8fd5c388d9363783a3d52f44b8f8eda3eecfaaeb5d5aec3dac0a3064760` | PASS_FORMAT |
| `04_map.png` | PNG, 848×1696, RGB (2:1) | `d9e4471bf8a414149ff9b56fafd3cec5e0355e4ea0d05b423a3ef7bf5bfe985e` | PASS_FORMAT |

## Visual PII review

- No real personal name, phone number, email, account identifier, or contact is
  visible. `Kullanıcı` is generic placeholder copy.
- The map shows the standard Android emulator test coordinate
  `37.42200, -122.08400` at the public Google campus, not a tester's private
  home/work location. OpenStreetMap attribution is visible.
- No PIN or signing/billing secret is visible.

Result: `PASS_REPO_VISUAL_PII`. The store operator must still record the final
Play upload filenames/screenshots; this review cannot prove what is ultimately
uploaded in Play Console.

## Release-candidate mismatch — still open

`03_settings_legal.png` visibly says `Sürüm 1.0.0 (Build 1)`. The tag workflow
maps `v1.0.0` to Android `versionCode=10000`. Therefore the current final set is
not evidence from the exact signed production candidate. Before upload, recapture
the canonical set from the signed internal-track candidate (or document an owner
exception for the non-functional build-label difference) and repeat this PII/hash
review. This is `NEEDS_OPERATOR_ACTION`, not a UI code change.

The Play icon/feature graphic also need the owner's final masked-icon and visual
approval in Play Console; format validity is not subjective brand approval.
