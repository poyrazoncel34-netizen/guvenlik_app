# Release hardening local evidence — 2026-07-18

Decision: **LOCAL PARTIAL / PRODUCTION NO-GO**

This ledger records executable repo-local evidence only. It is not bound to a
production AAB, Play app-signing certificate, physical-device run, independent
review, billing matrix, counsel decision, or closed-test soak. Therefore it
cannot close G0–G10 or produce `MASTER_GO_NO_GO_PASS`.

## Source baseline

- Branch: `codex/release-hardening-100`
- Baseline HEAD: `7a5418d05159059f0ee6cd93e2c3b7181228667f`
- Recoverable pre-hardening snapshot:
  `/private/tmp/korubeni-release-hardening.6qiDwT`
- Snapshot contains tracked/staged patch, porcelain-v2 status, untracked path
  list/archive and `SHA256SUMS`; checksum verification passed.
- Current dirty paths: 280, all classified.
- Porcelain-v2 source-status SHA-256:
  `e85d45f159f23e0d4f1f946d94c63d3add1342f8f138220e2c8a3aa9c5713e4f`.
- Product commit exclusions: `.agents`, `.codex`, `AGENTS.md`, JKS/keystore,
  `key.properties` and platform service credential files.

## Executable local results

| Evidence | Result |
| --- | --- |
| `flutter analyze --no-fatal-infos` | PASS, no issues |
| Full Dart suite after all local changes | PASS, zero failures |
| Secret-scan/provenance/external-gate targeted tests | PASS, 7/7 |
| Native Play debug host tests | PASS, 50/50 |
| Play debug instrumentation APK | COMPILED, not device-executed |
| Mandatory safety mutations | PASS, 6/6 killed |
| `git diff --check` | PASS |
| Workflow YAML parse | PASS for CI, nightly Android and release |

The four initially failing Dart tests were source-text contracts made stale by
safe multiline formatting and the new best-effort alarm-cancel helper. Their
assertions were updated to preserve the same typed-token/corrupted-state
contract; runtime behavior was not weakened.

## Critical line coverage

| Module | LH/LF | Coverage | Gate |
| --- | ---: | ---: | --- |
| `emergency_session_contract.dart` | 121/122 | 99.18% | PASS |
| `emergency_platform_service.dart` | 291/307 | 94.79% | PASS |
| `pin_verification_service.dart` | 56/60 | 93.33% | PASS |
| `check_in_service.dart` | 317/350 | 90.57% | PASS |

Global line coverage is 1963/4882 = 40.21% and remains informational. The
critical threshold does not turn the remaining global coverage gap into PASS.

## Deliberate fail-closed results

- Exact SBOM: 400 components.
- Human licence review: 0 reviewed / 400 unreviewed.
- Licence policy: `UNVERIFIED`, FAIL.
- Candidate notices: FAIL; 400 components lack reviewed primary-source bytes.
- Connected Android devices: none.
- Immutable production AAB/tag/provenance: absent.
- External gates: 0/11 closed.

## Evidence binding

Final classification: PASS, 280/280 paths classified, 0 forbidden paths staged.
The local scanner evaluated 256 UTF-8 text files, skipped five binary files and
reported zero high-confidence credential signatures. Its JSON binds the
complete scanned content set by SHA-256; this remains a local first engine, not
independent repository-host secret scanning. Mutation evidence remains
dirty-source-bound and candidate-unbound; its detailed hash record is in
`phase1-safety-mutation-evidence-2026-07-18.md`.
