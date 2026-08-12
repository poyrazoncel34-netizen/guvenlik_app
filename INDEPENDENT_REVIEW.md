# INDEPENDENT REVIEW — KoruBeni (com.poyrazoncel.korubeni)

Adversarial production-readiness review, conducted **2026-08-12** against working tree at
git HEAD `fe83771` (branch `feat/tutundurma-ucretsiz-prova`), **including uncommitted changes**.

Reviewer position: independent evaluator. I did not implement this application. The goal was to
disprove the claim that it is production-ready, not to confirm it.

## What I actually did

| Activity | Detail |
|---|---|
| Read | `docs/MASTER_PRODUCTION_CHECKLIST.md`, `PRODUCTION_AUDIT.md`, `REMEDIATION_PLAN.md`, `PROGRESS.md` |
| Re-ran the suite | `flutter test --no-pub` → **1042 passed / 0 failed** (confirms the claim) |
| Parsed all audit rows | 1,714 rows, 1,714 unique IDs — machine-counted, not trusted from prose |
| Built and ran the app | `flutter build apk --debug --flavor play --target-platform android-arm64`, installed on a booted **API 36** emulator, drove the full first-run flow |
| Adversarial UI probes | Consent bypass attempt, weak PIN, denied notification permission, skipped battery wizard, keyboard-open layout, 200% font scale, locked-SOS press and 3.5 s hold |
| Code probes | Wrote throwaway tests against `SubscriptionAccessState`; **disabled a production fix and re-ran its own regression test** to measure whether the test can fail |
| Verified gates | `verify_release_change_classification.py` run directly |

Screenshots and dumps live in the session scratchpad; every finding below cites a reproduction
you can run yourself.

---

## Verdict summary

Four findings materially contradict claims in the audit set. One is a **falsified PASS on a flow
that gates the emergency contact** — and with no emergency contact there is no panic call at all.
Two are assertions that are structurally incapable of failing, which means the remediation
over-reports its own coverage. One is a methodological gap in the "no P0" conclusion.

Counted honestly, the engineering underneath is well above average for a solo Android project
(see "What held up" — it is a long list, and it is not padding). The problem is not the codebase.
The problem is that **the audit's status column is more confident than its evidence**.

---

# FINDINGS

## IR-01 — `MP-72-030` PASS is false: the keyboard still hides the only control that completes onboarding

- **Requirement IDs:** `MP-72-030` (Keyboard overlay), `MP-07-023` (Text overflow), `MP-72-003` (Uneven padding)
- **Current status in audit:** `MP-72-030` **PASS**, `MP-07-023` **PASS**, `MP-72-003` PARTIAL
- **Recommended status:** `MP-72-030` → **FAIL**, `MP-07-023` → **FAIL**
- **Severity:** **HIGH** (this project's own rule: anything that can prevent the emergency call is CRITICAL by definition; this blocks the setup step that registers the emergency contact)

### Evidence

`PROGRESS.md` lists this as fixed defect #3: *"Fixed with a `FocusNode` + `Scrollable.ensureVisible`."*
The audit records `MP-72-030` as PASS with evidence *"Fixed in lib/screens/onboarding…"*.

I reproduced the original defect on the same platform the audit used (API 36 emulator), against a
build made from this exact working tree.

With the phone field focused and the soft keyboard open (`mInputShown=true`), the uiautomator
accessibility tree contains:

```
y=  613 :: Acil kişi ekleme adımı
y= 1012 :: 7-15 haneli bir numara girin. Numara yalnızca cihazınızda …
y= 1257 :: Başla
y= 1440 :: Devam etmek için aranabilir bir acil kişi gerekir.

SAVE BUTTON PRESENT: False
PICK-CONTACT PRESENT: False
```

Both **"Kişiyi kaydet"** (save contact) and **"Rehberden seç"** (pick from contacts) are absent —
not merely off-screen, absent from the accessibility tree, which is precisely the symptom the
audit itself used to characterise the original bug. A manual swipe restores them:

```
y=  811 :: Rehberden seç
y=  968 :: Kişiyi kaydet
AFTER SCROLL -- SAVE PRESENT: True
```

The helper text is also still clipped mid-sentence with the keyboard open ("…yalnızca cihazınızda"
with "saklanır." below the fold), which is `MP-07-023` / `MP-72-003`.

### Reproduction

```bash
flutter build apk --debug --flavor play --target-platform android-arm64
adb install -r build/app/outputs/flutter-apk/app-play-debug.apk
adb shell am start -n com.poyrazoncel.korubeni/.MainActivity
# complete consent → advance carousel to step 5/5 → tap the phone field
adb shell uiautomator dump /sdcard/ui.xml && adb shell cat /sdcard/ui.xml | grep -c "Kişiyi kaydet"
# → 0 while the keyboard is open
```

### Root cause

`lib/screens/onboarding/onboarding_contact_step.dart:62` registers the reveal on focus and defers
it by exactly one frame:

```dart
WidgetsBinding.instance.addPostFrameCallback((_) {
  ...
  Scrollable.ensureVisible(target, ..., alignment: 1.0);
});
```

One post-frame callback fires ~16 ms after focus. The Android IME animates in over ~200–300 ms, so
at the moment `ensureVisible` runs the viewport has **not yet shrunk** and the save button is still
visible — the call is a no-op. The keyboard then covers it, and nothing re-scrolls. The code comment
anticipates exactly this hazard ("Wait for the IME inset to be applied before measuring") but a
single frame is not enough to satisfy it.

### Recommended correction

Drive the reveal from the **inset**, not from the focus event. Either:

- watch `MediaQuery.viewInsetsOf(context).bottom` in `didChangeDependencies` and call
  `ensureVisible` when it becomes non-zero (it changes across several frames — re-issue on change,
  not once); or
- wrap the action row in the scroll view's bottom padding so it is inset-aware and cannot be
  occluded at all.

Then re-verify **on device**, since this defect is invisible to the widget-test harness (see IR-02).

---

## IR-02 — The regression test that "proves" IR-01's fix cannot fail

- **Requirement IDs:** `MP-72-030`, and the Batch 5 completion criteria in `REMEDIATION_PLAN.md`
- **Severity:** **HIGH** (a test that cannot fail is worse than no test — it converts an open defect into a closed one on paper)

### Evidence

`test/screens/onboarding_contact_step_keyboard_test.dart` has two structural defects:

1. Its helper takes a `bottomInset` parameter, but the keyboard test calls
   `pumpStep(tester, bottomInset: 0)` (line 84) — **the keyboard is never simulated** in the test
   named *"focusing the phone field scrolls the save action into view."*
2. Line 99 is `await tester.ensureVisible(saveButton);` — **the test performs the scroll itself**,
   then asserts `expect(saveButton, findsOneWidget)`. Flutter finders match the widget tree, not the
   visible viewport, so that assertion is true whether or not the button is on screen.

### Reproduction — I disabled the production fix and the test still passed

```dart
void _revealSaveActionOnFocus() {
  if (true) return;              // fix disabled
  if (!_phoneFocusNode.hasFocus) return;
```

```
run 1: All tests passed!
run 2: All tests passed!
run 3: All tests passed!
run 4: All tests passed!
```

Four consecutive green runs with the fix removed. (The file was restored; `git diff --stat` returns
to the original 31 insertions.)

### Recommended correction

Assert the property that actually matters — geometry under a real inset:

```dart
await pumpStep(tester, bottomInset: 400);   // simulate the IME
final box = tester.getRect(find.byKey(saveButtonKey));
expect(box.bottom, lessThanOrEqualTo(800 - 400),
    reason: 'save action must sit above the keyboard inset');
```

Do **not** call `tester.ensureVisible` before the assertion. Confirm the new test fails with the
production fix disabled before trusting it.

---

## IR-03 — The accessibility "labelled target" assertion is vacuous, and Batch 4 covers 1 of the 4 promised screens

- **Requirement IDs:** `MP-12-030`, `MP-12-031` (PARTIAL, resting on this test), `MP-12-017`, `MP-12-001`, `MP-12-023`…`025`
- **Severity:** **HIGH** for the vacuity; **MEDIUM** for the coverage overstatement
- **Recommended status:** keep `MP-12-030`/`031` PARTIAL but strike `labeledTapTargetGuideline` from their evidence

### Evidence

`test/screens/accessibility_guidelines_test.dart` pumps `OnboardingContactStep` with only
`DefaultMaterialLocalizations` / `DefaultWidgetsLocalizations` — **`easy_localization` is not
initialised**. `easy_localization` resolves an unloaded key to the key string itself, so every
label is a non-empty ASCII identifier. I probed what actually renders:

```
RENDERED_TEXTS: [onboarding_contact_title, onboarding_contact_body,
 onboarding_contact_consent_title, ..., onboarding_contact_pick_btn,
 onboarding_contact_save_btn]
```

`meetsGuideline(labeledTapTargetGuideline)` only checks that a tappable node has a **non-empty**
accessible name. Since the fallback name is always the key string, **the assertion cannot fail** —
not for a missing translation, not for an empty label, not for a meaningless one.

The same harness gap is visible across the whole suite: the run emits **61 distinct
`Localization key [...] not found` warnings**, covering the countdown, panic button and onboarding
contact screens. So every widget test in this suite asserts against key names, not user-facing copy.

The tap-target half of the test (`androidTapTargetGuideline`) **is** meaningful — sizes are real
geometry — and I am not disputing it.

Separately: `REMEDIATION_PLAN.md` Batch 4 step 1 promises matchers on "the consent gate, contact
form, panic button and countdown." Only the contact form exists. `PROGRESS.md` marks Batch 4
**✅ Done** while its own "Next remediation batch" section simultaneously lists three Batch 4 items
as still open (`Semantics(header: true)`, `textContrastGuideline`, the `shrinkWrap` review).

### Reproduction

```bash
grep -n "localizationsDelegates" -A3 test/screens/accessibility_guidelines_test.dart   # no EasyLocalization
flutter test --no-pub 2>&1 | grep -c "Localization key .* not found"                   # 61 distinct keys
```

### Recommended correction

1. Initialise `EasyLocalization` in the a11y harness (copy the setup from a neighbouring test, per
   `.claude/rules/dart/testing.md`) so labels are real Turkish copy. Confirm the test then fails if
   a key is removed.
2. Either extend the matchers to the other three promised screens or reclassify Batch 4 as
   **PARTIAL** in `PROGRESS.md`.
3. Note that the production build is **not** affected — the real app's accessibility tree is rich
   (verified live: the SOS node exposes `"Kilitli SOS butonu / SOS / Kilitli · Provasını ücretsiz
   çalıştır"`). This is a test-fidelity defect, not a shipped a11y defect.

---

## IR-04 — "There are no P0 findings" is not supportable as written

- **Requirement IDs:** `MP-22-001` (P1 PARTIAL), `MP-54-029` (P1 PARTIAL); and the P0 claim in `PRODUCTION_AUDIT.md`, `REMEDIATION_PLAN.md` and `PROGRESS.md`
- **Severity:** **HIGH** (classification defect — it shapes what gets fixed before launch)

### Evidence

All three documents assert the absence of P0 is *structural*:

> "with no server, no accounts, no telemetry and no AI, the entire catastrophic-risk surface this
> checklist targets (auth bypass, tenant leakage, mass data loss, prompt injection, financial-ledger
> corruption) does not exist in this architecture."

Every hazard in that list is a **server/web** hazard. The enumeration is correct and I independently
confirmed the premise (no server code, no accounts, no analytics, no AI; `lib/` has no HTTP client
outside the OSM tile cache). But the argument silently assumes the product's catastrophic class is
on that list. It is not. For KoruBeni the catastrophic event is **the panic button failing to
dial**, and that event is reachable.

`PremiumFeature.panic` is **Pro-gated** (`lib/core/constants/feature_access_matrix.dart:97-102`),
and `SubscriptionGate.ensureAccess` **fails closed** when entitlement cannot be resolved
(`subscription_gate.dart:90-96`). I exercised the state machine directly:

```
OFFLINE_8_DAYS        canUsePaidSafetyFeature=false  decision=unknown  grace=false
OFFLINE_3_DAYS        canUsePaidSafetyFeature=true
FRESH_INSTALL_OFFLINE canUsePaidSafetyFeature=false  decision=unknown
FUTURE_ANCHOR         canUsePaidSafetyFeature=false
```

So a **paying subscriber** whose store has been unreachable for more than
`offlineGracePeriod = Duration(days: 7)` gets a panic button that refuses to arm. Same for a fresh
install offline, and same if the device clock is ahead of the anchor. Live confirmation on the
emulator: the SOS control renders greyed with a **PRO** badge and the label
**"Kilitli · Provasını ücretsiz çalıştır"**.

I want to be fair about the design, because it is genuinely thoughtful: the 7-day grace, the
1800 ms/400 ms budgets, the single-source `entitlementDecision` getter, and the explicit rejection
message are all correct responses to a hard trade-off, and the reasoning in
`subscription_access_state.dart:30-36` is better than most production code I read. The rejection is
also **visible**, not silent — I verified the snackbar appears on both a tap and a 3.5 s hold:
*"Abonelik durumu doğrulanamadı… aboneliğiniz varsa 'Satın Alımları Geri Yükle' seçeneğini
kullanın."* My objection is not that the trade is wrong. It is that a decision this consequential
is recorded as **P1 PARTIAL** under a heading that says catastrophic risk is structurally absent.

One concrete gap sits underneath it: **nothing warns the user before the grace expires.**
`offlineGracePeriod` is referenced only inside its own file:

```
lib/core/services/subscription_access_state.dart:36   static const Duration offlineGracePeriod
lib/core/services/subscription_access_state.dart:82   return moment.difference(verifiedAt) <= offlineGracePeriod;
```

No screen, service or notification reads it. A Pro user therefore discovers that their panic button
is disabled at the moment they press it — which is the worst possible moment.

### Reproduction

```bash
grep -rn "offlineGracePeriod" lib/          # 2 hits, both in the defining file
grep -n "PremiumFeature.panic" -A3 lib/core/constants/feature_access_matrix.dart   # access: pro
```

State machine: construct `SubscriptionAccessState(status: unavailable, lastVerifiedPro: true,
lastVerifiedProAt: now - 8 days)` and read `canUsePaidSafetyFeature` → `false`.

### Recommended correction

1. **Reframe the P0 claim.** Replace "no P0 exists, structurally" with an explicit statement that
   the product's catastrophic class is *failure to dial*, then classify against **that**. Either
   elevate `MP-22-001`/`MP-54-029` to P0-accepted-with-rationale with a named owner and a review
   date, or state in one line why a 7-day-offline Pro user losing SOS is not P0. Do not leave it
   implied.
2. **Warn before the cliff.** Surface remaining grace once it drops below ~48 h (home readiness card
   is the natural place — it already reports degraded states well). This is the single highest-value
   change available and it costs very little.
3. Do **not** narrow the grace window, and do **not** make the panic path network-dependent — the
   existing rationale is right on both counts.

---

## IR-05 — `PRODUCTION_AUDIT.md` ships five contradictory summary tables

- **Requirement ID:** document integrity (affects every consumer of the audit)
- **Severity:** MEDIUM

### Evidence

Lines 36–124 contain **five** "Result summary" tables and **five** severity tables, stacked, with
different numbers and no indication which is current:

| Table | PASS | FAIL | PARTIAL | BLOCKED | N/A | UNVERIFIED |
|---|---|---|---|---|---|---|
| 1st | 630 | 21 | 140 | 28 | 773 | 122 |
| 2nd | 623 | 22 | 146 | 28 | 773 | 122 |
| 3rd | 610 | 22 | 147 | 28 | 773 | 134 |
| 4th | 609 | 23 | 144 | 28 | 773 | 137 |
| 5th | 561 | 44 | 164 | 27 | 775 | 143 |

I parsed all 1,714 rows. The **first** table is correct
(`{'PASS': 630, 'PARTIAL': 140, 'N/A': 773, 'UNVERIFIED': 122, 'FAIL': 21, 'BLOCKED': 28}`,
1,714 unique IDs, severities P1=27 / P2=229 / P3=55). The other four are stale revisions that were
appended rather than replaced. The last one is the *baseline*, which `PROGRESS.md` presents as the
"before" column — so a reader who scrolls to the bottom-most table reads pre-remediation numbers as
current.

### Reproduction

```bash
grep -c "TOTAL INDIVIDUAL REQUIREMENTS" PRODUCTION_AUDIT.md    # 5
```

### Recommended correction

Delete tables 2–5. Keep one summary, and have it generated from the rows rather than hand-written,
so it cannot drift again.

---

## IR-06 — 44% of PASS rows carry copy-pasted section boilerplate as their evidence

- **Requirement IDs:** widespread; `MP-01-022` is the clearest example
- **Severity:** MEDIUM (evidence quality — most verdicts are probably right, but the audit does not demonstrate them)

### Evidence

Of 630 PASS rows there are only **420 distinct evidence strings**; **280 PASS rows (44.4%)** share
their evidence with at least one other row. The most reused string appears **28 times**. The reuse
is section-level: the section assessment is pasted into each row regardless of what the row asks.

The sharpest case is `MP-01-022` — *"Kullanıcı bir işlemi iki kere tetiklerse duplicate işlem
oluşmuyor"* (double-triggering must not produce a duplicate operation), marked **PASS** with:

> "RUN 2026-08-12: first-run walkthrough on an API 36 emulator (…). Entry point, primary CTA, next
> step and exit path were unambiguous on every screen walked."

That sentence is about navigation clarity. It says nothing about double-triggering. The same text
backs `MP-01-013` (state after refresh), `MP-01-029` (timeout state) and 17 others.

In fairness, the underlying claim for `MP-01-022` does appear to hold — `panic_button.dart:108`
guards with `if (_pointerDown || _isArmed || _countdownOpening) return;` plus a `_pressEpoch`
generation counter, and the contact form guards with `_saving`. The verdict is likely correct. The
*evidence* does not establish it, and an auditor cannot tell the checked rows from the assumed ones.

### Reproduction

```bash
python3 - <<'PY'
import collections
rows=[l.split('|') for l in open('PRODUCTION_AUDIT.md',encoding='utf-8') if l.startswith('| `MP-')]
p=[r for r in rows if 'PASS' in r[4]]
c=collections.Counter(r[6].strip() for r in p)
print(len(p),'PASS;',len(c),'distinct evidence;',sum(n for n in c.values() if n>1),'shared')
PY
```

### Recommended correction

For any row whose evidence is the section assessment verbatim, either write row-specific evidence
or downgrade the row to **UNVERIFIED**. Prioritise the behavioural claims (duplicate submission,
state retention, timeout, partial success) — those are the ones a boilerplate sentence cannot cover.

---

## IR-07 — `PROGRESS.md` batch states and test counts contradict their own document

- **Requirement ID:** remediation reporting integrity
- **Severity:** MEDIUM

### Evidence

1. **Batch 5 marked ✅ Done** with two defects in scope. One is fixed (and IR-01 shows it does not
   actually work), the helper-text clip is **not** fixed, and the golden-test deliverable was
   dropped. The audit is honest about this internally — `MP-46-028` is still **FAIL**
   ("no golden-file or screenshot-comparison test exists anywhere under test/") and `MP-72-003` is
   still PARTIAL — so the batch table contradicts the rows it summarises.
2. **Batch 4 marked ✅ Done** while three of its items are listed as open later in the same file.
3. **Three different suite counts:** the header says "green at **1042** passed"; the commands table
   says "after remediation **1025** passed / 0 failed"; Batch 0's completion criterion says
   "**1010/1010** green." I measured **1042 passed / 0 failed**, so the headline is right and the
   other two are stale.
4. `REMEDIATION_PLAN.md` Batch 10 step 2 says to document "the deliberate **recreate-on-upgrade**
   behaviour," which is the opposite of what was implemented and of the rule in `patterns.md`
   ("Migrations are additive-only"). Following that instruction literally would document a data-loss
   design that the code correctly does not have.

### Recommended correction

Change Batch 4 and Batch 5 to 🟡 **Partial**, reconcile the three suite counts to one, and fix the
Batch 10 wording to "additive-only migration."

---

## IR-08 — The entire remediation is uncommitted, and two security gates cannot run against it

- **Requirement IDs:** `MP-75-001`, `MP-75-002`; the OSV and secret-scan evidence gates
- **Severity:** MEDIUM

### Evidence

```
$ git status --porcelain | wc -l
26
$ git ls-files | grep -c "PRODUCTION_AUDIT\|REMEDIATION_PLAN\|PROGRESS.md\|MASTER_PRODUCTION"
0
$ git log --oneline main..HEAD
(6 commits, none containing any remediation work)
```

Every artefact this review was asked to evaluate — all four audit documents, the migration fix, the
crash-log stamping, the panic-button seam, the layout fix, and all six new test files — exists only
as uncommitted working-tree state.

This matters beyond hygiene, and `PROGRESS.md` says so itself: *"Both fail closed on a dirty working
tree (`candidate source is dirty`)."* The OSV audit and the release secret scanner were therefore
run against a **detached clean worktree at HEAD** — i.e. against the tree *without* any of this
work. Their `OSV_EVIDENCE_PASS` / `RELEASE_SECRET_SCAN_PASS` results are quoted as current evidence
but do not cover the changes under review. `scripts/verify_release.sh` was not run at all.

To be fair: I ran `verify_release_change_classification.py` against the live tree and it **passes**
with all 26 paths classified, so Batch 0 genuinely works and the new files are correctly covered.

### Recommended correction

Commit the remediation in the logical groups the classification config already defines, then re-run
the OSV and secret gates against the committed tree so their PASS results describe the shipping
state. Until then, no release-gate evidence in the audit set applies to the code being reviewed.

---

## IR-09 — PIN error banner displaces the keypad mid-entry

- **Requirement IDs:** `MP-08-023`, `MP-16-*` (form feedback)
- **Severity:** LOW

### Evidence

Entering a blocked PIN (`1234`) inserts a "Daha güvenli bir PIN seçin." banner **above** the keypad,
shifting all ten keys down by ~120 px. I hit this myself during the walkthrough: my next four taps
landed on the wrong digits because the layout moved under them. On a security control where the
user is typing a secret and cannot see what they entered, a silent 120 px shift invites mis-entry.

The weak-PIN rejection itself is a **good** control and works correctly (`Validators.isWeakPin`,
`lib/screens/pin_setup_screen.dart:64`).

### Reproduction

Enter `1234` at PIN setup, screenshot, compare keypad bounds before/after.

### Recommended correction

Reserve the banner's vertical space (fixed-height slot, or overlay it) so the keypad never moves.

---

## IR-10 — Three audit rows are malformed and lose their columns

- **Requirement ID:** document integrity
- **Severity:** LOW

### Evidence

Parsing the Verif column yields three values that are not method codes:
`"Portrait lock is defensible for a panic-button product; revisit alongside the adaptive-layout work."`,
`"uiMode\\"`, `"screenSize\\"` — unescaped `|` characters inside evidence text shift those rows'
columns.

### Recommended correction

Escape `|` as `\|` in table cells; re-verify the parse yields only `RUN|TEST|CMD|SRC|DOC|NONE`.

---

# What held up under challenge

I tried to break these and could not. They are stated here because a review that only lists defects
misrepresents the codebase.

| Claim | Independent result |
|---|---|
| Suite green | **Confirmed** — 1042 passed / 0 failed |
| `flutter analyze` clean | **Confirmed** — no issues |
| Dead migration hook fixed | **Confirmed and well done.** `upgradeSchema` is additive-only, idempotent (`PRAGMA table_info` before `ADD COLUMN`), with a missing-table safety net. The reasoning comment is accurate. |
| `MP-44-015` crash-log bound (corrected PARTIAL→PASS) | **Confirmed** — unconditional `DELETE … WHERE id NOT IN (… ORDER BY created_at DESC LIMIT 100)` on every insert. The upgrade to PASS was justified. |
| `PanicButton.holdClockOverride` is production-inert | **Confirmed** — `widget.holdClockOverride?.call() ?? Stopwatch()`; never supplied outside tests. A legitimate seam, correctly justified. |
| Platform-channel await added to `CrashLogService` | **Not a dispatch-path regression** — `record()` is only called from the two global error handlers in `main.dart`. |
| Hostile-input coverage (Batch 6) | **Genuinely substantive** — 8 hostile strings incl. RTL override and zero-width, a 10 000-char ReDoS-shaped timing bound, and both digit-count edges. |
| Auth / authz / tenancy / IDOR marked N/A | **Structurally correct** — verified no server, no accounts, no shared datastore, single-user-per-device. No IDOR or tenant-isolation surface exists. |
| PIN brute-force protection (`MP-21-018`) | **Confirmed** — PBKDF2-HMAC-SHA256 100k, 16-byte salt, constant-time compare, capped exponential backoff. |
| Weak PIN rejection | **Confirmed live** — `1234` rejected with a clear message |
| No biometrics (CLAUDE.md rule 2) | **Confirmed** — no `local_auth`; onboarding explains the duress rationale to the user |
| Third-party consent gate | **Confirmed non-bypassable** — "Ekle" is inert until the consent box is ticked; I tried it first |
| Graceful degradation on denied permissions | **Excellent.** Denied notifications + skipped battery wizard → home still loads, readiness chips show what is missing, and the app states *"İzin verilmedi — acil durumda dialer açılacak"* |
| Entitlement rejection is visible, not silent | **Confirmed on both tap and 3.5 s hold** (I initially suspected the hold path was a silent no-op; capturing mid-hold disproved it) |
| Production accessibility labels | **Rich** — e.g. `"Kilitli SOS butonu / SOS / Kilitli · Provasını ücretsiz çalıştır"` |
| 200% font scale | **Holds up** — unlock screen stays scrollable and "Şifremi Unuttum" remains on-screen and clickable |
| TODO/FIXME/stub/placeholder sweep | **Zero** across `lib/` and `android/…/kotlin/` |
| CI/CD | **Above typical** — analyze, 90% critical-coverage gate, OSV audit, secret scan, Kotlin unit, safety mutation testing, instrumentation compile, AAB smoke build, API 29–36 nightly emulator matrix |
| `docs/release/observability_and_slo.md` (Batch 7) | **Honest and useful** — names the blindness, forbids resolving it with an SDK, and picks two objectives that are actually measurable without one |
| Batch 0 release-classification rule | **Works** — verifier passes, 26/26 paths classified |
| `test/translation_key_usage_test.dart` | **Closes a real gap** the parity test cannot see (a key absent from *both* bundles) |
| Prompt-injection / tool-abuse / AI risk | **Genuinely N/A** — no LLM, agent, RAG or model dependency anywhere in the tree |

---

# Status downgrades

| ID | Audit status | Independent status | Basis |
|---|---|---|---|
| `MP-72-030` | PASS | **FAIL** | IR-01 — reproduced live on API 36 |
| `MP-07-023` | PASS | **FAIL** | IR-01 — helper text still clipped with keyboard open |
| `MP-12-030` | PARTIAL | PARTIAL *(evidence reduced)* | IR-03 — `labeledTapTargetGuideline` half is vacuous |
| `MP-12-031` | PARTIAL | PARTIAL *(evidence reduced)* | IR-03 — same |
| `MP-22-001` | P1 PARTIAL | **P0-class, accepted-with-rationale** | IR-04 — reaches the product's catastrophic class |
| `MP-54-029` | P1 PARTIAL | **P0-class, accepted-with-rationale** | IR-04 — same |
| `MP-01-022` | PASS | **UNVERIFIED** | IR-06 — evidence does not address the requirement |

The 27 P1 items remain P1 and remain externally blocked; I found no reason to dispute that
classification. The 773 N/A verdicts are, on the sample I checked, correctly justified rather than
evasive.

---

# Required before release

**Blocking**

1. Fix IR-01 (inset-driven reveal) and re-verify on device — this gates the emergency contact.
2. Fix IR-02 so the regression test fails when the fix is absent. Prove it by disabling the fix.
3. Fix IR-03's harness so the a11y assertion can fail; or drop the claim.
4. Resolve IR-04's classification and ship the pre-expiry grace warning.

**Before sign-off**

5. Reconcile IR-05, IR-06, IR-07 — one summary table, row-specific evidence on behavioural PASSes,
   honest batch states.
6. Commit the work (IR-08) and re-run the OSV + secret gates against the committed tree so their
   PASS results describe what ships.

**Unchanged from the existing plan** — Batches 1 (billing), 2 (physical device) and 3 (key custody)
remain correctly identified as the release-blocking P1 set. Nothing here displaces them.

---

# VERDICT

The engineering is strong and the audit is unusually thorough — 1,714 individually evaluated
requirements with per-item justification is real work, the release tooling is better than most
commercial Android projects, and several of the "fixes" I attacked held up cleanly under direct
probing.

But the claim under review is production-readiness, and I was able to disprove a PASS on the flow
that registers the emergency contact by building and running this exact tree, then show that its
regression test passes with the fix deleted, and that a second remediation assertion cannot fail
either. A checklist whose PASS column can be falsified in one walkthrough is not yet evidence of
readiness — and on a product where the failure mode is a call that never gets placed, that gap is
the one that matters most.

## **REVIEW FAILED — REMEDIATION REQUIRED**

Four HIGH findings (IR-01 through IR-04) must be closed and independently re-verified — on hardware,
not in the widget harness — before this is a defensible production-readiness claim.
