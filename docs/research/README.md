# KoruBeni Competitive & Compliance Research (2026-06)

Evidence-first competitive, monetization, and KVKK/Google Play compliance research for the KoruBeni personal-safety app. Public sources only; no source code modified.

## Deliverables
| File | What it is |
|---|---|
| [`01-competitive-analysis-2026-06.md`](01-competitive-analysis-2026-06.md) | **Main report** — exec summary, profiles, feature/permission & pricing tables, revenue methodology, recommendations, store-readiness checklist, KVKK gap matrix, abuse-risk checklist, Mermaid hypothesis tree |
| [`competitor-profiles.csv`](competitor-profiles.csv) | 11 apps: origin, scale, features, pricing, positioning |
| [`feature-permissions-matrix.csv`](feature-permissions-matrix.csv) | 28 feature/permission rows × 8 apps incl. KoruBeni |
| [`monetization-pricing.csv`](monetization-pricing.csv) | Free vs paid tiers, prices, trials, billing |
| [`revenue-estimates.csv`](revenue-estimates.csv) | Per-app monthly revenue with formulas + confidence |
| [`evidence-log.csv`](evidence-log.csv) | 30 claims, each ≥2 sources (or flagged low-confidence) + access date |
| [`hypotheses.csv`](hypotheses.csv) | 14 hypotheses with confidence + supported/inference status |
| [`research-notes.json`](research-notes.json) | Machine-readable notes + nested hypothesis tree |

## Headline findings
- **Life360** anchors the market: USD 489.5M FY2025 revenue, 2.8M paying circles, ~95.8M MAU (reported, high confidence).
- **KADES** (free TR government app, ~9.7M downloads) is the incumbent KoruBeni must differentiate from and *not* impersonate.
- **#1 product gap:** user-initiated location-to-contacts share (KoruBeni is offline-first and doesn't auto-send).
- **#1 asset:** privacy-minimal / offline / duress-aware architecture (no backend, mic, biometric, background location).
- **Launch blockers:** `specialUse` FGS demo-video declaration; broad `READ_CONTACTS` vs the April-2026 Contact-Picker policy; KVKK March-2026 separate-consent rule; "not an emergency service" disclaimers.

## Confidence
Life360 financials = **high** (public filings). All other revenue figures = **estimates/low confidence**. See per-claim flags in `evidence-log.csv`.

> Follow-up (separate task): combine these outputs with the codebase audit in `../audit/` into a file-by-file launch-readiness plan.
