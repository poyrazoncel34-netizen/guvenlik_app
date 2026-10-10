
## RC 3691017 debug sha256 192fc9ae18426f3d — KoruBeni_API36 emulator-5558 — part 2 (P7, P8; P1–P6 in rc-fix-probes.part1-p1-p6.out.txt) — API 36, lastUpdateTime 2026-10-10 10:30:43
| Probe | Result | Observed |
|---|---|---|
| P7 Y-14 revoke during Check-In -> notice -> settings -> re-grant restores exact alarms | PASS | armed=armed process_killed=True notice=True settings=True notice_gone=True exact_alarms=2 end=cancelled |
| P8 A-03 final warning fails -> single call at the final deadline + timeline reason | FAIL | armed=cancelled final=cancelled graceWarningOutcome=notAttempted calls+=0 timeline_reason=False |
