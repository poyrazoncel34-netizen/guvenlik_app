# F14 — unresolved operations decision

OPERATOR_DECISION_PENDING. No owner approval for one of the conflicting numeric
policies was found in the inspected source or supplied request. This decision is
open and belongs to the repository owner; neither silence nor an instruction to
“continue” selects a threshold, and no agent may pick one on the owner's behalf.

The single proposed canonical procedure is
[PRODUCTION_ROLLOUT_RUNBOOK.md](../../store/PRODUCTION_ROLLOUT_RUNBOOK.md).
Legacy documents redirect there. These historical numbers are **not executable
operator instructions**:

| Previous source | Conflicting historical policy |
|---|---|
| incident_runbook | Crash-free <99%, ANR >0.47%; daily first 72h, then weekly; 1/10/50/100 rollout |
| observability_and_slo | Crash-free <98%, ANR >0.47%; 24h,72h,7d and before progression |
| current proposed rollout runbook | User-perceived crash >=0.50%, ANR >=0.20%, device >=2%; update stages 5/20/50/100 with 24h/48h holds, severity-based stop |

Required decision: approve the proposed canonical thresholds, metric definitions,
observation checkpoints, staffed owner/backup and initial/update distinction, or
supply a replacement approved decision. Rates cannot be converted between
crash-free sessions and user-perceived daily-user rates without evidence.
A confirmed safety defect blocks launch independent of statistical sample size.
No operator rehearsal, recovery duration or live Console action has been done.
