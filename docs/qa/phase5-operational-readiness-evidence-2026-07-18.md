# Release Hardening Evidence Ledger — 2026-07-18

Status: **NO-GO / EXTERNAL_RELEASE_GATES_UNVERIFIED**

This ledger replaces the earlier weighted `70%` assessment. That assessment
double-counted repository checks and understated safety/device uncertainty.
KoruBeni now uses non-compensating gates: a green style, legal-copy, or unit
test domain cannot offset an open safety or physical-device gate.

## Current local evidence

| Evidence | Result | Boundary |
| --- | --- | --- |
| `flutter analyze` | PASS, zero issues | Static analysis only |
| `flutter test --no-pub` | PASS, 620 tests after battery/provenance hardening | Many tests are source-contract checks; count is not a safety score; the last coverage-producing verifier run contained 617 tests |
| Critical Dart coverage gate | PASS_LOCAL | Contract 99.18%, platform 96.68%, PIN 92.16%, Check-In 90.57%; each file must independently remain ≥90% |
| `app:testPlayDebugUnitTest` | PASS, 43 native tests | Includes typed coordinator/store/validator tests; not OEM proof |
| Concurrency eval | PASS_LOCAL | 1,000 controlled interleavings for each of five race families |
| Reference model | PASS_LOCAL | 20 seeds × 10,000 traces × 50 operations = 10,000,000 model operations; not Android execution |
| Play release lint + manifest processing | PASS_LOCAL | Warnings remain and are dispositioned; Play policy acceptance is external |
| Clean local release verifier | LOCAL_CANDIDATE_PASS | `verify_release.sh` passed 5/5 after clean/pub-get: analyze, 617 tests+coverage, signed `.smoke` AAB, Android lint/tests and 16 KB alignment |
| Non-release smoke AAB | PASS_LOCAL | Signed `.smoke` artifact, 104.3 MB; deliberately not uploadable as production provenance |
| R8/native symbols | PASS_LOCAL | R8 mapping generated; AGP embeds `.dbg` files under AAB `BUNDLE-METADATA/com.android.tools.build.debugsymbols` |
| CycloneDX SBOM | PASS_INVENTORY | 401 Pub/Maven components; licence evidence deliberately remains `UNVERIFIED` |
| Gradle dependency verification | PASS_LOCAL | Strict SHA-256 metadata parses and covers 1,950 components / 3,586 artifacts; a normal host-test build passed with it enabled |
| Data extraction rules | PASS_LOCAL | Backup and device-transfer exclusions compile; device/OEM validation remains external |

## Material implementation completed

- Native `EmergencySessionCoordinator` is the only compiled scheduler/dispatch
  authority. Legacy `EmergencyExecutor`, `CheckInScheduler`, and
  `CountdownAlarmScheduler` were removed.
- Typed token/generation arm, cancel, read, dispatch, wipe, capability and PIN
  contracts fail closed on timeout/unknown state.
- Durable Direct Boot state, cancellation tombstones, stale-generation
  suppression, fallback-first dispatch and `TelecomManager.placeCall` are in
  place. Connection is always `unknown`.
- Target normalization is side-effect free and limited to 7–15 ASCII digits;
  no 112/911/KADES target is synthesized.
- Release workflow is SHA-pinned and expects signed-tag/main ancestry, upload
  certificate identity, arm64-only AAB, 16 KB checks, SBOM, merged manifest,
  lint report, R8 mapping, embedded native-symbol index, lockfiles and hashed
  Gradle dependency-verification metadata.
- Tagged source provenance runs before dependency resolution and rejects any
  tracked, staged, or untracked drift. It binds annotated tag, commit, Git tree
  and exact AAB SHA-256; the current 259-path development worktree correctly
  returns non-zero and therefore cannot be called a candidate.
- Battery exemption now has one native authority and no plugin bypass. A red
  policy contract first observed three direct native owners; after the change,
  Kotlin compile/lint passed, total lint warnings fell from 56 to 46 and the
  generalized `BatteryLife` findings fell from four to the one intentional
  safety-app request that still requires Play/operator disposition.
- The tagged workflow now fails closed unless every exact SBOM purl has
  reviewed licence evidence accepted by the SPDX policy. The current 401-entry
  inventory deliberately remains blocked because the evidence file is empty;
  `docs/release/dependency_license_review.md` defines the human review process.
- Legal/store copy now distinguishes local wipe, subscription cancellation,
  RevenueCat deletion, bounded fallback retention, OSM transfers, and
  unconfirmed call requests.

## Gate status

| Gate | Status | Why it is not closed |
| --- | --- | --- |
| G0 Safety case | PARTIAL | Independent reviewer sign-off absent |
| G1 Native kernel | LOCAL_PASS / REVIEW_UNVERIFIED | Unit/model/race evidence passes; independent review, mutation and candidate device evidence remain |
| G2 Flutter/PIN/session | LOCAL_PASS / REVIEW_UNVERIFIED | Critical modules independently exceed 90%; executable timeout, PIN, restore, lifecycle and race tests pass; independent review and device lifecycle evidence remain |
| G3 Android platform | LOCAL_PARTIAL | Build/manifest/Direct Boot code exists; API29–36 physical permission/Doze/reboot evidence absent |
| G4 Security/privacy | PARTIAL | Gradle checksums and a fail-closed SPDX policy exist; all 401 exact-purl licence reviews, MASVS report and counsel decision remain absent |
| G5 Quality | LOCAL_PARTIAL | 620-test full regression and the last critical coverage gate pass; accessibility, performance, migration and physical feature matrix remain incomplete |
| G6 Artifact chain | TOOLING_PASS / CANDIDATE_UNVERIFIED | Strict Gradle checksum metadata, source-drift fail-close and smoke proof pass; current worktree is intentionally rejected; exact tagged production AAB/attestation/Play-delivered cert absent |
| G7 Physical devices | UNVERIFIED | API29/API36, Pixel/Samsung/Xiaomi, dual-SIM and low-memory matrix not run |
| G8 Billing/Play | UNVERIFIED | Console, RevenueCat dashboard, licence tester and Bundle Explorer evidence absent |
| G9 Closed soak | UNVERIFIED | Same production AAB has not completed 12 testers × 14 days |
| G10 Go/no-go | FAIL | Required approvals and hotfix drill absent; multiple gates remain unverified |

## Honest readiness statement

**[CERTAIN] Production decision: NO-GO.** Zero of eleven gates is fully closed
for one immutable production AAB.

**[STRONG ESTIMATE] Implementation progress is about 65% ±5.** This is work
completion, not launch-success probability. The proof-based readiness ceiling
is 65 until native/PIN/dispatch controls receive independent review and the
API29–36/Direct Boot/device gate advances. Editing weights cannot raise it.

The following cannot be manufactured from the repository: Play and RevenueCat
dashboard state, product pricing, real SIM/Telecom/OEM behavior, Turkish privacy
counsel's Article 9 mechanism, Play-processed artifact evidence, closed-track
soak, and accountable approvals. `scripts/verify_external_release_gates.py`
must continue returning fail until candidate-bound evidence closes G0–G10.
