
## v1.0.2 debug sha256 7f68e08d4a5fa4ef -> RC 3691017 debug sha256 192fc9ae18426f3d — KoruBeni_API29 emulator-5556, 420 dpi, -no-audio — API 29
| Step | Result | Observed |
|---|---|---|
| v1.0.2: install + consent + PIN + primary contact | PASS | lastUpdateTime 2026-10-10 10:42:39; "Acil kişi hazır — Annem • 05551234567"=True |
| v1.0.2: wrong PINs escalate the lockout | PASS | Kilitli: 25s -> Kilitli: 56s -> Kilitli: 114s -> Kilitli: 236s at 10:49:09 |
| upgrade during the 240 s lockout -> re-consent -> lock still active, correct PIN refused | PASS | install at 10:49:09 lastUpdateTime 2026-10-10 10:49:09; re-consent=True terms=4.0.0; band after consent=Kilitli: 207s; correct PIN opened=False |
| force-stop after upgrade keeps the lockout | PASS | band=Kilitli: 169s |
| lockout runs out -> correct PIN opens; v1.0.2 data intact | PASS | "Acil kişi hazır — Annem • 05551234567"=True at 10:53:16 |
| upgraded app: Check-In 15 min armed | PASS | native=armed pending alarms=4 |
| kill -9 | PASS | native=armed alarms=4 |
| force-stop -> reopen | FAIL | native=armed alarms=0 |
| reboot (app not opened): alarms rescheduled by the boot receiver | FAIL | native=armed alarms=0 boot-receiver pid=1572 |
| reopen -> remaining shown -> PIN cancel | PASS | remaining=? native=cancelled alarms=0 |
