# CERT-01…CERT-09 — remediation record

> Response to [`FINAL_REPOSITORY_CERTIFICATION.md`](FINAL_REPOSITORY_CERTIFICATION.md),
> which returned **FAILED** on nine findings. That report is left exactly as issued: a
> certification is a record of what was true when it was taken, and editing it to match a
> later tree is the defect the whole audit exists to remove. This is the separate record of
> what was done about it, in the same shape as `FINAL_REMEDIATION_REGISTER.md` for the FIR
> series.

| Fact | Value |
|---|---|
| Certification that triggered this | `FINAL_REPOSITORY_CERTIFICATION.md`, verdict FAILED, 9 findings |
| Verified implementation revision after remediation | `c855a4b` |
| Evidence artifacts | 12, measured at `b171e93`, `dirty:false` |
| Convergence guard | **18/18 PASS** (was 16 gates; CERT-09 added two) |
| Date | 2026-08-16 |

---

## What was actually wrong, and what was done

| # | Finding | Disposition |
|---|---|---|
| CERT-01 | `MP-67-001..004` counted as EXTERNAL while their whole remediation was already committed | **Fixed.** All four re-graded PASS against `incident_runbook.md` §2 and `observability_and_slo.md`, each with its own evidence answering its own question rather than four copies of one sentence |
| CERT-02 | `MP-23-012` asked for a Play-subscriptions link-out that exists twice in `lib/` | **Fixed.** PASS, citing `subscription_management_screen.dart:82-90` and `subscription_deletion_notice.dart:35` |
| CERT-03 | `MP-50-014/015/016` asked for documentation the runbook already carried | **Fixed.** Stale clause replaced with a citation; the rehearsal remains external, which is the row's real scope |
| CERT-04 | `MP-53-006` carried an in-repo documentation deliverable, scoped external | **Fixed.** `dr_and_key_custody.md` §1.1 now records the retention decision AND that no off-platform mirror exists, with the residual risk stated. Row PASS |
| CERT-05 | `WORK_PHRASES` was 8 verbs, matched case-sensitively while the check beside it used `re.I` | **Fixed.** 18 verbs, case-insensitive, and 19 newly surfaced rows registered with honest reasons. `MP-50-012` closed its in-repo half (`incident_runbook.md` §9). The rule's real BOUND — it cannot see a remediation that names no file, which is why CERT-01/02 escaped it — is now written in the docstring instead of left to be rediscovered |
| CERT-06 | 13 polish rows + `MP-08-008` parked behind golden tests, a remedy this repo forbids, on a recorded reason of "was not performed" | **Fixed by doing the pass.** Clean install on an API 36 emulator, full onboarding, 8 surfaces captured and inspected: **8 of 13 items closed PASS**, 5 kept open with the panel argument `MP-69-012/013` already uses. `MP-08-008` PASS with a new render + inventory test |
| CERT-07 | Baseline table headed `ef40178` while provenance claimed a later revision; two rows did not reproduce | **Fixed.** Every row re-executed at `c855a4b` and the heading corrected. Measured drift confirmed the finding: 1643 → **1656** tests, 846 → **858** scanned files |
| CERT-08 | The alert verifier's docstring promised tear-offs were reported; they were silently missed | **Fixed.** New `alertOutcomeTearOff` rule; the negative control now asserts it fires |
| CERT-09 | No gate checked evidence CONTENT — a committed hand-edit would satisfy all 16 gates | **Fixed.** New `verify_evidence_reproducibility.py`, wired into the guard with its own negative control |

## The defect the polish pass found

`CERT-06` was the finding that mattered most, not because it was the most severe but because
doing the work honestly turned up something no review had:

**With the offline banner visible, the top ~42 dp of every tab was occluded.** On Home that
hid more than half of the "Hoş Geldiniz" heading. The banner is a `Positioned(top: 0)`
overlay, so it occupied no layout space and the pages beneath reserved nothing for it. Every
earlier walkthrough had run **online**, where the banner never appears — which is exactly why
eight rows had been sitting at UNVERIFIED behind a forbidden remedy instead of being looked at.

It was fixed in its own commit with its own device pass, per the standard
`PRODUCT_DECISIONS_REQUIRED.md` D-2 sets for shell-wide visual change, and verified offline on
a clean install. `MP-72-031` had been **PASS**; it was downgraded on the evidence and only
returned to PASS after the fix was verified on the device.

## Accounting movement

| Metric | At certification | Now |
|---|---|---|
| PASS | 799 | **814** |
| PARTIAL | 69 | 62 |
| UNVERIFIED | 51 | 43 |
| FAIL / BLOCKED / N/A | 2 / 38 / 779 | 2 / 38 / 779 |
| Unresolved | 160 | **145** |
| P0 / P1 | 0 / 29 | 0 / 29 |
| IN_REPO_RESOLVABLE | **7** (certified) | **0** |
| RUNTIME_VERIFIABLE_NOW | **13** (certified) | **0** |
| EXTERNAL / PRODUCT | 105 / 35 | 110 / 35 |
| Checklist / audit / missing / duplicated / unaccounted | 1738 / 1738 / 0 / 0 / 0 | unchanged |

Re-verified with a parser written independently of the repository tooling: 80 sections,
1714 checkbox + 24 launch-matrix, 0 text mismatches, 0 placement mismatches.

## Two things deliberately NOT done

1. **`FINAL_REPOSITORY_CERTIFICATION.md` was not edited.** Its verdict was correct when taken.
2. **Nothing was re-scoped to make a number move.** The five remaining section-72 items were
   kept open rather than passed on an emulator capture, and each names why a physical panel is
   the remainder. The 145 unresolved rows are still 110 external and 35 owner decisions.

## What this does not claim

Repository convergence is not launch readiness. Physical-device execution, the Play
internal-test track, the RevenueCat sandbox, real TalkBack testing, MFA and branch-protection
confirmation, Play policy approval and the rollout rehearsal all remain outstanding, and are
recorded in `EXTERNAL_LAUNCH_BLOCKERS.md` and `PRODUCT_DECISIONS_REQUIRED.md`. None of them is
closable from this repository, and none of them was touched here.
