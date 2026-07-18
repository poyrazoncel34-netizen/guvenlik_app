# KoruBeni Release Audit Note

Date: 2026-05-04

Scope: static/code/doc/test audit only. Emulator, adb, Android device install/run, Play Console dashboard work, RevenueCat dashboard work, live billing flows, and production upload were not executed.

## Baseline Before Changes

Commands run:

| Command | Result | Notes |
| --- | --- | --- |
| `git status` | PASS | Clean `main`, up to date with `origin/main`. |
| `git branch --show-current` | PASS | `main`. |
| `git log --oneline -5` | PASS | Latest commits: `4f91e04`, `6b77ba4`, `5801eef`, `a7642b4`, `5a92bf5`. |
| `git diff --check` | PASS | No whitespace errors. |
| `dart --version` | PASS | First sandboxed run could not update Flutter cache outside workspace; rerun with approval returned Dart SDK 3.10.8. |
| `flutter --version` | PASS | Flutter 3.38.9 stable, Dart 3.10.8. |
| `flutter analyze --no-fatal-infos` | PASS | Exit 0. Existing info-only lints; no errors or warnings. |
| `flutter test --reporter=compact` | PASS | 288 tests passed. |
| `rg -n "[...Turkish/string scan...]" lib android/app/src/main/kotlin` | PASS_WITH_FINDINGS | Found expected Turkish legal/localized content plus release-visible hardcoded strings in contacts/native notification areas. |
| `rg -n "emergency_alerts|service_status|general_notifications|korubeni_alerts_high|korubeni_service_low|korubeni_general_default" lib android/app/src/main/kotlin` | FIXED_BY_2d7e48a | Active source now uses canonical IDs only: `emergency_alerts`, `service_status`, and `general_notifications`. Old `korubeni_*` IDs are historical findings only. |
| `rg -n "TODO|FIXME|HACK" lib/core/services lib/screens android/app/src/main/kotlin store scripts .github/workflows` | PASS | No matches in scanned release-critical paths. |
| `rg -n "API_KEY|SECRET|TOKEN|PASSWORD|KEYSTORE|PRIVATE_KEY|REVENUECAT|GOOGLE_SERVICE" .` | PASS_WITH_REVIEW | Matches were placeholders, env var names, release script checks, tests, and `key.properties.example`; no committed production secret identified in baseline scan. |

Files and areas inspected:

- `lib/`
- `android/app/src/main/kotlin/`
- `lib/core/services`
- `lib/screens`
- `store/`
- `scripts/`
- `.github/workflows`
- `android/app/build.gradle.kts`
- `android/key.properties.example`
- `test/`

Baseline issues found:

- CODE_DONE: Native Kotlin notification strings and channel metadata were routed through locale-aware text with safe fallback in commit `2d7e48a647a22b41e025089836ae1d76a5876654`.
- CODE_DONE: Kotlin notification channels now use only `emergency_alerts`, `service_status`, and `general_notifications`; old `korubeni_*` channel IDs are fixed historical findings.
- CODE_DONE: `lib/screens/contacts_page.dart` contains hardcoded Turkish KVKK dialog text.
- CODE_DONE: Static regression coverage should prevent old channel IDs and known hardcoded Turkish notification/contact strings from returning.
- CODE_DONE: Store docs need icon-size, short-description, overclaim, screenshot source-of-truth, Play declaration, billing checklist, QA matrix, and final gate hardening.
- PLAY_CONSOLE / SIGNING / NEEDS_OPERATOR_ACTION: Play Console forms, app content declarations, target audience, content rating, data safety, privacy/data deletion URLs, signed AAB upload, tester setup, and closed testing evidence remain external.
- REVENUECAT / PLAY_CONSOLE: RevenueCat/Google Play subscription dashboard setup and license tester billing validation remain external.
- NEEDS_REAL_DEVICE_TEST: API29/API36/16 KB, Pixel/Samsung/Xiaomi, dual-SIM and low-memory physical-device safety, permissions, Direct Boot, process-death, notification, call, map, and billing QA remain not run.
- NOT_TESTED_RUNTIME: Android runtime behavior, device install, emulator behavior, Play Billing purchase/restore flows, and Play Console dashboard state were not tested because runtime/device/dashboard execution is forbidden.

Runtime/device command confirmation:

- No `adb`, emulator, Android device, `flutter run`, `flutter drive`, `patrol`, install, Play Billing runtime, Play Console dashboard, RevenueCat dashboard, keystore creation, or upload command was run.
