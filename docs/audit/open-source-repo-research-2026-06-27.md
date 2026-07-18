# KoruBeni Open-Source Repo Research

Date: 2026-06-27
Scope: Research only. No app code, UI, Android manifest, build, translation, or store metadata changes.

## Decision Summary

Recommendation: do not "take" any repository wholesale.

Use this split instead:

1. Primary engineering reference: `android/nowinandroid`
   - Use for Android/Kotlin quality, modular boundaries, test strategy, and official Android architecture alignment.
   - Do not migrate KoruBeni to Jetpack Compose; KoruBeni remains Flutter UI with native Android emergency reliability code.
   - Confidence: 0.82.

2. Secondary Flutter product/release reference: `localsend/localsend`
   - Use for Flutter app organization, release discipline, localization/product polish, and local/offline-first user trust patterns.
   - Do not copy local-network/file-transfer code; domain mismatch.
   - Confidence: 0.70.

3. Security/privacy product references only: `guardianproject/haven`, `signalapp/Signal-Android`, `ente-io/ente`
   - Use for threat-model thinking, privacy wording, onboarding clarity, local-data caution, and safety UX.
   - Do not copy code from these repositories due GPL/AGPL license risk and domain mismatch.
   - Confidence: 0.78.

4. Deprioritize as main references: `immich-app/immich`, `rustdesk/rustdesk`, `AppFlowy-IO/AppFlowy`
   - Large, high-quality projects, but their core domains are photo backup, remote desktop, and workspace/productivity. They are too indirect for KoruBeni's emergency reliability core.
   - Confidence: 0.76.

## KoruBeni Need Model

Evidence from local project sources:

- `CLAUDE.md`: offline-first core, local PIN only, Doze/OEM battery reliability, graceful denied-permission behavior, Google Play target, UI unchanged, plan approval before code changes.
- `docs/HANDOVER.md`: Android-targeted Flutter app; critical paths include native `AlarmManager`, foreground service `specialUse`, `CALL_PHONE` with dialer fallback, exact alarm degraded mode, boot restore, no 112 fallback, check-in/safe-walk state machine, Play declarations.
- `pubspec.yaml`: Flutter/Dart app using Provider, get_it, secure storage, sqflite, local notifications, geolocator, background service, permission handler, RevenueCat, safe_device.

Derived selection criteria:

| Criterion | Weight | Why it matters |
|---|---:|---|
| Android reliability relevance | High | KoruBeni's risk is Doze, alarms, FGS, boot restore, permissions. |
| License safety | High | Directly copying GPL/AGPL code can create obligations incompatible with a closed/commercial Play app unless intentionally accepted. |
| Flutter app relevance | Medium | UI is Flutter, but UI/theme is explicitly not to be changed. |
| Security/privacy domain relevance | Medium | Safety app trust and disclosures matter, but code reuse is risky. |
| Star count | Low-Medium | Popularity signals maturity, not fit. |

## Hypothesis Tree

```text
Goal: improve KoruBeni safely using open-source references, without app changes until approved.

H1: Use android/nowinandroid as the primary reference.
  Evidence for:
    - Official Android sample repo; README says it follows official architecture guidance.
    - Apache-2.0 license in GitHub API and LICENSE file.
    - KoruBeni's highest-risk code is native Android reliability, not Flutter UI.
  Evidence against:
    - It is Kotlin/Compose, while KoruBeni UI is Flutter and UI is not to change.
  Decision:
    - Accept as architecture/test/native-quality reference, not as codebase to import.
  Confidence: 0.82.

H2: Use localsend/localsend as the primary reference.
  Evidence for:
    - Flutter/Dart, cross-platform, Apache-2.0, strong release/product footprint.
    - README emphasizes local communication without internet or third-party servers.
  Evidence against:
    - Its core domain is local file/message transfer, not emergency timers, CALL_PHONE, exact alarm, or Play sensitive safety claims.
  Decision:
    - Use as secondary Flutter/release/reference only.
  Confidence: 0.70.

H3: Use Haven/Signal/ente as safety/privacy foundation.
  Evidence for:
    - Haven is directly security/safety oriented and local-device/sensor focused.
    - Signal and ente are strong privacy/security UX references.
  Evidence against:
    - Haven is GPL-3.0; Signal and ente are AGPL-3.0.
    - Domains differ: Haven is sensor monitoring, Signal is messenger, ente is encrypted cloud/auth/photos.
  Decision:
    - Use for product/security thinking only; do not copy code.
  Confidence: 0.78.

H4: Take no repo; rely only on official Android/Play docs.
  Evidence for:
    - KoruBeni already has a mature native emergency layer and local docs.
    - Official Android/Play policy docs are the source of truth for exact alarms, FGS, runtime permissions, and declarations.
  Evidence against:
    - Mature repos can still improve engineering habits, tests, release structure, and UX review.
  Decision:
    - Keep official docs as primary constraints; use selected repos as examples.
  Confidence: 0.74.
```

## Candidate Data

GitHub API snapshot collected on 2026-06-27.

| Repo | Stars | Language | License | Last push | Fit | Code-copy risk |
|---|---:|---|---|---|---|---|
| `android/nowinandroid` | 21,419 | Kotlin | Apache-2.0 | 2026-06-26 | High for Android architecture/testing | Low if attribution/license preserved; still prefer no copy |
| `localsend/localsend` | 84,204 | Dart | Apache-2.0 | 2026-06-19 | Medium-high for Flutter product/release | Low if attribution/license preserved; domain code mostly irrelevant |
| `guardianproject/haven` | 6,791 | Java | GPL-3.0 | 2022-10-26 | High product-domain inspiration | High for direct code reuse |
| `signalapp/Signal-Android` | 28,974 | Kotlin | AGPL-3.0 | 2026-06-26 | Medium security/privacy inspiration | High for direct code reuse |
| `ente/ente` | 27,335 | Dart | AGPL-3.0 | 2026-06-26 | Medium privacy/encryption inspiration | High for direct code reuse |
| `immich-app/immich` | 104,470 | TypeScript | AGPL-3.0 | 2026-06-27 | Low-medium; background/mobile patterns only | High for direct code reuse |
| `rustdesk/rustdesk` | 117,053 | Rust | AGPL-3.0 | 2026-06-26 | Low-medium; self-host/security messaging only | High for direct code reuse |
| `AppFlowy-IO/AppFlowy` | 72,989 | Dart | AGPL-3.0 | 2026-06-26 | Low; domain mismatch | High for direct code reuse |

## Key Claims And Verification

| Claim | Source A | Source B | Assessment |
|---|---|---|---|
| KoruBeni's core improvement area is Android reliability, not visual UI. | Local `CLAUDE.md` requires Doze/OEM reliability, graceful denied permissions, UI unchanged. | Local `docs/HANDOVER.md` details AlarmManager, FGS, boot restore, CALL_PHONE/ACTION_DIAL, exact alarm degraded mode. | Strong. This makes Android reliability references more valuable than full Flutter UI rewrites. |
| Exact alarm handling must include denied/default-denied paths and graceful degradation. | Local `docs/HANDOVER.md` says exact permission denial falls back to inexact alarm + degraded messaging. | Android official "Schedule exact alarms are denied by default" documents default-denied behavior and migration/graceful-degrade guidance. | Strong. External repos should not override KoruBeni's explicit degraded-mode behavior. |
| Foreground service type and Play declarations are a policy risk independent of repo choice. | Local `docs/play_console_declarations.md` and `docs/HANDOVER.md` document `specialUse` rationale and Play declaration needs. | Android official foreground service type docs describe `specialUse`, Play Console app content declaration, and FGS type enforcement. | Strong. Repo selection cannot bypass Play policy obligations. |
| Runtime permission UX must explain need, request in context, and degrade after denial. | Local `lib/core/utils/permission_helper.dart` and Play docs describe prominent disclosure and denied-session handling. | Android official runtime permission guide says ask in context, explain sensitive permissions, and gracefully degrade on denial. | Strong. This supports reference patterns from Android docs/nowinandroid over copying safety app code. |
| Apache-2.0 repos are lower legal risk than GPL/AGPL repos for limited reuse. | Repo LICENSE files for `android/nowinandroid` and `localsend/localsend` are Apache-2.0. | Official Apache-2.0 text permits reproduction/distribution/modification subject to license/notice conditions. | Strong, but not legal advice; attribution/NOTICE review is still required before any copy. |
| GPL/AGPL repos are high risk for direct code reuse in KoruBeni. | Repo LICENSE/API data: Haven GPL-3.0; Signal/ente/Immich/RustDesk/AppFlowy AGPL-3.0. | Official GNU GPL/AGPL texts are copyleft licenses designed to preserve users' rights to source and modified versions; AGPL adds network-service source availability concerns. | Strong enough to avoid direct code copy unless the product license strategy is intentionally changed with legal review. |
| Haven is the closest product-domain reference, but not a code source. | Haven README describes Android on-device sensors, monitoring physical areas, privacy, local event logs, Signal/Tor notifications. | Haven repo license is GPL-3.0 and GitHub API shows last push in 2022, making direct reuse and freshness less attractive. | Strong. Use for threat model and UX only. |
| LocalSend is useful but not an emergency-safety foundation. | LocalSend README: Flutter, local network, no internet/third-party servers, cross-platform. | KoruBeni local docs: emergency calls, timers, AlarmManager, CALL_PHONE, Play sensitive permissions. | Strong. Use for Flutter app/release discipline, not safety core. |
| Very high-star repos can be poor matches. | RustDesk README: remote desktop/self-hosting; Immich README: photo/video management/backups; AppFlowy README/API: workspace/productivity. | KoruBeni local docs: personal safety app with native emergency reliability and Play sensitive permissions. | Strong. Stars do not overcome domain mismatch. |

## Conflicts And Source Reliability

- GitHub API vs README/license:
  - GitHub API is reliable for current metadata such as stars, language, license field, and pushed date.
  - Repo LICENSE/README files are more reliable for license text and project intent than search snippets or blog posts.
  - If API license and LICENSE file conflict, prefer the actual LICENSE file, then verify with SPDX/official license text.

- Repo examples vs Android/Play docs:
  - Official Android/Play docs take precedence for platform and store policy behavior.
  - Repos show implementation patterns but can be outdated, domain-specific, or non-compliant for KoruBeni's exact Play target.

- High stars vs product fit:
  - Stars are weak evidence. They support maturity but do not prove a pattern is appropriate for a safety/emergency app.

## Practical Decision

Do not import a repository.

Adopt a research-backed reference stack:

1. `android/nowinandroid`: primary reference for native Android structure, tests, Gradle hygiene, architecture language, and maintainable boundaries.
2. `localsend/localsend`: secondary reference for Flutter release/product quality and offline/local-first trust language.
3. `guardianproject/haven`: threat model and safety onboarding reference only.
4. `signalapp/Signal-Android` and `ente-io/ente`: privacy/security UX and disclosure reference only.
5. Official Android/Play docs: binding rules for exact alarms, foreground services, runtime permissions, sensitive permissions, and Play declarations.

## Next Research Steps Before Any Code Plan

1. Compare KoruBeni native emergency Kotlin package against `nowinandroid` test/module conventions.
2. Compare KoruBeni release/checklist docs against `localsend` release and platform-support conventions.
3. Extract non-code UX principles from Haven/Signal/ente: permission wording, privacy boundaries, local data explanations, safety disclaimers.
4. Produce a change proposal with zero copied GPL/AGPL code and no UI/theme changes.
5. Ask for explicit approval before touching app code.

## Source Index

Repository/API primary sources:

- `https://api.github.com/repos/android/nowinandroid`
- `https://raw.githubusercontent.com/android/nowinandroid/main/README.md`
- `https://raw.githubusercontent.com/android/nowinandroid/main/LICENSE`
- `https://api.github.com/repos/localsend/localsend`
- `https://raw.githubusercontent.com/localsend/localsend/main/README.md`
- `https://raw.githubusercontent.com/localsend/localsend/main/LICENSE`
- `https://api.github.com/repos/guardianproject/haven`
- `https://raw.githubusercontent.com/guardianproject/haven/master/README.md`
- `https://raw.githubusercontent.com/guardianproject/haven/master/LICENSE`
- `https://api.github.com/repos/signalapp/Signal-Android`
- `https://raw.githubusercontent.com/signalapp/Signal-Android/main/README.md`
- `https://raw.githubusercontent.com/signalapp/Signal-Android/main/LICENSE`
- `https://api.github.com/repos/ente-io/ente`
- `https://raw.githubusercontent.com/ente-io/ente/main/README.md`
- `https://raw.githubusercontent.com/ente-io/ente/main/LICENSE`
- `https://api.github.com/repos/immich-app/immich`
- `https://raw.githubusercontent.com/immich-app/immich/main/README.md`
- `https://api.github.com/repos/rustdesk/rustdesk`
- `https://raw.githubusercontent.com/rustdesk/rustdesk/master/README.md`
- `https://api.github.com/repos/AppFlowy-IO/AppFlowy`

Official platform/license sources:

- `https://developer.android.com/about/versions/14/changes/schedule-exact-alarms`
- `https://developer.android.com/develop/background-work/services/fgs/service-types`
- `https://developer.android.com/training/permissions/requesting`
- `https://support.google.com/googleplay/android-developer/answer/13392821`
- `https://support.google.com/googleplay/android-developer/answer/16558241`
- `https://www.apache.org/licenses/LICENSE-2.0.txt`
- `https://www.gnu.org/licenses/gpl-3.0.txt`
- `https://www.gnu.org/licenses/agpl-3.0.txt`
