# F14 — operations threshold decision (RESOLVED)

**Resolved 2026-09-12 by the repository owner.** The canonical procedure and its
numeric halt thresholds are
[PRODUCTION_ROLLOUT_RUNBOOK.md](../../store/PRODUCTION_ROLLOUT_RUNBOOK.md),
sections 4–6:

- user-perceived crash rate >= 0.50%, ANR >= 0.20%, affected devices >= 2%
- staged rollout 5 / 20 / 50 / 100 with 24h and 48h holds
- severity-based stop, with the first-release vs update distinction preserved

These were chosen because they are stated in the metric definitions Google Play
actually reports against, and because this is the only one of the three sources
that separates a first release from an update.

The two historical sources below are superseded. They are **not** executable
operator instructions and must not be cited as an independent authorization:

| Superseded source | Historical policy |
|---|---|
| incident_runbook | Crash-free <99%, ANR >0.47%; daily first 72h then weekly; 1/10/50/100 |
| observability_and_slo | Crash-free <98%, ANR >0.47%; 24h, 72h, 7d and before each progression |

Rates cannot be converted between crash-free sessions and user-perceived
daily-user rates without evidence, so the superseded numbers were not
recalculated into the new scheme — they were replaced.

## Still open (NOT resolved by this decision)

A confirmed safety defect blocks launch independently of any statistical sample
size. The following remain open and are tracked in
[external_acceptance_20260911.md](external_acceptance_20260911.md):

- named staffed owner and backup for the rollout window
- an actual two-operator tabletop rehearsal reaching the same stop decision
- measured recovery duration (no four-hour target has been demonstrated)
- any live Console action

Approving thresholds is not the same as having rehearsed them.
