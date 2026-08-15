# PRODUCT DECISIONS REQUIRED

> Requirements that engineering cannot close because the answer is a product
> choice, not a technical fact. **Nine decisions**, covering **31 requirement
> IDs**. Both numbers are true and neither contradicts the other: several
> requirements collapse into one underlying question.
>
> These are not a place to park hard work. Every requirement that could be
> resolved or verified in the repository has been, and each decision below
> states explicitly what engineering has already finished and what remains
> genuinely blocked on an answer.

Generated against verified code revision `3789318`+. Regenerate the ID lists
with `python3 scripts/generate_resolution_queue.py` (`PRODUCT_DECISION_REQUIRED`
scope).

---

## D-1 — Is the light theme a supported mode, or should it be deleted?

- **Requirement IDs (1):** `MP-04-015`
- **Current behaviour.** `AppTheme.lightTheme` is fully written and maintained,
  and `main.dart` pins `ThemeMode.dark`, so it can never render. Nobody sees it,
  nothing tests it, and it drifts a little further from the dark theme with
  every palette change.
- **Why engineering cannot decide.** Whether this app should have a light mode
  is a product/brand question. There is also a safety argument on both sides
  (below) that only the owner can weigh.
- **Option A — support it.** Add a theme switch, extend the palette work to the
  light surfaces, and put light mode into the device QA matrix.
  *Consequence:* real ongoing cost — every screen doubles its visual QA.
  *Safety note:* a light theme is easier to read outdoors in daylight.
- **Option B — delete it (recommended default).** Remove `lightTheme`, keep the
  single dark theme the product actually ships.
  *Consequence:* one fewer maintained-but-dead surface; trivially reversible
  from git if the product changes its mind.
  *Safety note:* a dark UI is less likely to light up a room, which matters for
  a duress product used at night.
- **Engineering already done.** The palette and theme are token-driven, so
  either option is a small change. `docs/design/design_system.md` records the
  current state.
- **Blocked?** Yes, on this answer only.

## D-2 — Should typography be routed through `TextTheme`?

- **Requirement IDs (1):** `MP-04-004`
- **Current behaviour.** A measured type scale exists (`TypeScale`) and is
  ratcheted, but the app sets `fontSize` inline at 335 sites and reads
  `Theme.of(context).textTheme` at **zero**.
- **Why engineering cannot decide.** The migration touches 335 render sites.
  `TextTheme` styles carry colour, while the inline styles set colour
  explicitly, so a mechanical migration can silently change text colour. That
  is exactly the visual regression CLAUDE.md rule 4 exists to prevent, on a
  codebase whose review model depends on small diffs. Whether to accept that
  risk is a judgement about how much visual QA the owner will fund.
- **Option A — migrate (recommended if a device QA pass is funded).** Build a
  `TextTheme` from `TypeScale`, migrate screen by screen, each with a
  before/after device screenshot, lowering the pinned off-scale count as it
  goes.
- **Option B — keep the ratchet only.** The scale is already named and new code
  is already forced onto it; the existing 77 off-scale sizes stay as recorded
  debt.
- **Engineering already done.** Scale defined, ratchet enforcing it, debt
  measured at 77 and pinned so it cannot grow.
- **Blocked?** Partially — Option B is already implemented, so nothing is
  broken while this waits.

## D-3 — Is portrait-phone-only still the product's scope?

- **Requirement IDs (12):** `MP-07-004`, `MP-07-005`, `MP-07-006`, `MP-07-007`,
  `MP-07-008`, `MP-07-011`, `MP-07-014`, `MP-47-013`, `MP-47-014`, `MP-59-018`,
  `MP-74-005`, `MP-80-002`
- **Current behaviour.** Layouts are portrait-phone-only by an explicit recorded
  product decision. Tablets, foldables, landscape and desktop are out of scope.
- **Why engineering cannot decide.** This is a market-reach decision, and it has
  a hard external deadline attached (see D-4).
- **Option A — keep the scope.** These twelve requirements stay N/A-by-scope and
  should be recorded as such rather than as gaps.
- **Option B — widen it.** Real work across every screen plus a device matrix.
- **Recommendation.** Keep the scope for launch; revisit with D-4.
- **Blocked?** Yes — but note the requirements are not defects today, they are
  consequences of a decision already taken and simply need re-confirming.

## D-4 — Android 16 / API 37 large-screen compatibility

- **Requirement IDs (2):** `MP-59-022`, `MP-59-023`
- **Current behaviour.** Large-screen/foldable support is deliberately deferred
  behind the Android large-screen compatibility opt-out, which **expires at API
  37**. This is a deadline, not a preference.
- **Why engineering cannot decide.** The response depends on D-3 and on the
  release timeline.
- **Option A.** Do the adaptive-layout work before targeting API 37.
- **Option B.** Ship at the current target and schedule the work explicitly.
- **Recommendation.** Decide this together with D-3, and put a date on it — this
  is the only item here with an externally imposed clock.
- **Blocked?** Yes.

## D-5 — Is an email inbox the support channel, or is a ticket system needed?

> **Revised 2026-08-15 (FIR-03).** This entry previously read *"there is no
> ticket identity, no owner, no severity ladder and no stated response
> expectation"* and marked **Option B** as the open decision. Option B was
> already written — `docs/release/incident_runbook.md` §1, §2 and §6 — one day
> after this entry, and the entry was never revisited. The stale text hid
> completed work behind an owner decision, so `MP-65-005`, `MP-65-006` and
> `MP-65-007` are now graded PASS against the runbook and only the tooling
> question below remains open.

- **Requirement IDs (1):** `MP-65-004`
- **Current behaviour.** Intake is the support e-mail
  (`korubeni.destek@gmail.com`, which also appears in the KVKK texts as the data
  controller contact) plus the Play Console review queue. Both carry a written
  response expectation of 3 business days (`incident_runbook.md` §6), the owner
  is named (§2, sole developer, with the reason a rotation is deliberately not
  written), and severity is an S1–S4 ladder with per-level target first response
  (§1). What does NOT exist is a ticket SYSTEM: no per-report identifier, no
  queue state, no ageing view.
- **Why engineering cannot decide.** A help desk is a recurring cost and a third
  system to administer; whether the report volume justifies it is the owner's
  call, not a repository fact. KVKK also gives the address a legal role — a
  data-subject request arriving there has statutory deadlines.
- **Option A — adopt a help desk.** Ticket IDs, ownership per report, and
  measurable response times, at the cost of another system.
- **Option B — keep e-mail plus the written policy (current state).** Already in
  effect; nothing further to write.
- **Engineering already done.** Option B in full. Nothing here needs code.
- **Blocked?** Only on Option A vs B. The written policy that used to be the
  blocking half is committed.

## D-6 — Does this product accept having no telemetry?

- **Requirement IDs (5):** `MP-75-012`, `MP-75-013`, `MP-75-014`, `MP-77-015`,
  `MP-32-046`+`MP-32-047` (log centralisation)

> **Revised 2026-08-15 (FIR-03).** `MP-79-012` and `MP-79-013` were listed here
> and graded FAIL on a remediation — *"make that substitution explicit in the
> postmortem template"* — that `docs/release/incident_runbook.md` §7 item 3
> already carries. They are now PASS and are no longer part of this decision.
> The standing decision below is unchanged and still real.
- **Current behaviour.** No analytics, no crash SDK, no dashboard, no alerting.
  Logging is entirely local and never leaves the device. This is a deliberate
  privacy choice for a duress product and is stated in the KVKK texts. The
  consequence is that **a regression is discovered by users, not by the team**,
  and Play Console vitals are the only signal.
- **Why engineering cannot decide.** Adding any telemetry contradicts a
  published privacy claim and CLAUDE.md rule 1. Removing the consequence is not
  possible; only accepting it or changing the privacy posture is.
- **Option A — accept, and say so (recommended).** Record an explicit owner
  acceptance that detection is user-reported plus Play vitals, with a named
  person checking vitals on a stated cadence. Costs nothing, changes nothing,
  and turns an unmanaged risk into an owned one.
- **Option B — add privacy-preserving crash reporting.** Opt-in, no PII, KVKK
  text updated, Data Safety re-declared, new consent. Meaningful legal and
  product work.
- **Blocked?** Yes — but Option A is a signature, not a project.

## D-7 — Runtime feature flags: none exist

- **Requirement IDs (2):** `MP-50-012`, `MP-75-016`
- **Current behaviour.** No runtime flags. A bad release can only be fixed by
  shipping another release, and Play forbids rolling back to a lower
  `versionCode`, so the only rollback is a roll-forward.
- **Why engineering cannot decide.** Flags need a delivery mechanism. A remote
  one means a backend, which CLAUDE.md rule 1 forbids; a build-time one is not a
  runtime flag and would not help an incident.
- **Option A — accept (recommended).** Keep the no-backend envelope and rely on
  a rehearsed roll-forward, which is tracked as an external blocker (E9).
- **Option B — local kill-switch.** A signed, bundled config that can disable a
  non-safety feature without a release. Never for the emergency path.
- **Blocked?** Yes, though A is the status quo.

## D-8 — Residual local-tamper risk on entitlement

- **Requirement IDs (2):** `MP-22-001`, `MP-54-029`
- **Current behaviour.** With no backend, entitlement is anchored locally. On a
  **rooted** device, writing both SharedPreferences keys grants unbounded
  emergency access. `allowBackup=false` blocks the non-root route, single-value
  forgery is refused, and the consequence is revenue, not safety.
- **Why engineering cannot decide.** Closing it requires a server check, which
  would make the panic button network-dependent — the exact failure this product
  exists to avoid. That trade is the owner's.
- **Option A — accept (recommended, and currently implemented).** Documented
  in-code and in the audit rows.
- **Option B — server-side entitlement.** Introduces a backend and a network
  dependency on the safety path. **Not recommended:** a subscriber in a basement
  with no signal must still be able to press SOS.
- **Blocked?** Yes, but the safest option is already shipped.

## D-9 — Product-scope N/As that only need re-confirming

- **Requirement IDs (5):** `MP-08-008` (button-level loading beyond the paywall),
  `MP-16-019` (locale-aware phone normalisation, e.g. `+90`),
  `MP-23-012` (in-app billing portal — Play owns subscription management),
  `MP-46-028` (image-level visual regression — golden tests are forbidden by
  `.claude/rules/dart/testing.md`), `MP-49-012` (verification artefact not
  signed with the release key)
- **Why grouped.** Each is a small, independent "is this in scope?" question
  rather than a design problem. None blocks another item.
- **Recommendation.** Confirm each as intentionally out of scope, except
  `MP-16-019`: **phone normalisation is worth a second look**, because a number
  saved without a country code may not dial from a different network, and that
  is the emergency path. Engineering can implement it as soon as the intended
  behaviour (normalise silently vs. prompt the user) is chosen.
- **Blocked?** Only `MP-46-028` is truly blocked (it needs the golden-test rule
  reversed). The rest are confirmations.

---

## What is NOT here

Difficulty, size and "no existing test" are not product decisions. Everything
resolvable in the repository is in `RESOLUTION_QUEUE.md` under
`IN_REPO_RESOLVABLE` or `RUNTIME_VERIFIABLE_NOW`; everything needing an outside
system is in `EXTERNAL_LAUNCH_BLOCKERS.md`.
