
## v1.0.2 debug sha256 7f68e08d4a5fa4ef -> RC ff945ee debug sha256 f2e3078eef3f68cf — KoruBeni_API29 emulator-5556, 420 dpi, -no-audio — API 29
| Step | Result | Observed |
|---|---|---|
| v1.0.2: install + consent + PIN + primary contact | PASS | lastUpdateTime 2026-10-10 12:13:16; "Acil kişi hazır — Annem • 05551234567"=True |
| v1.0.2: wrong PINs escalate the lockout | PASS | Kilitli: 25s -> Kilitli: 56s -> Kilitli: 116s -> Kilitli: 231s at 12:20:02 |
| upgrade during the 240 s lockout -> re-consent -> lock still active, correct PIN refused | PASS | install at 12:20:02 lastUpdateTime 2026-10-10 12:20:03; re-consent=True terms=4.0.0; band after consent=Kilitli: 197s; correct PIN opened=False |
| force-stop after upgrade keeps the lockout | PASS | band=Kilitli: 160s |
| lockout runs out -> correct PIN opens; v1.0.2 data intact | PASS | "Acil kişi hazır — Annem • 05551234567"=True at 12:24:03 |
| upgraded app: Check-In 15 min armed | PASS | native=armed pending alarms=4 |
| kill -9 | PASS | native=armed alarms=4 |
| force-stop -> reopen | PASS | native=armed alarms=4 |
| reboot (app not opened): alarms rescheduled by the boot receiver | PASS | native=armed alarms=4 boot-receiver pid=1695 |
| reopen -> remaining shown -> PIN cancel | FAIL | remaining=? native=armed alarms=4 |

Note (12:31–12:33): the last row's FAIL was the probe acting before the first post-reboot cold start finished
(it found no Check-In screen, so no cancel was attempted; native stayed `armed` with 4 pending alarms --
which itself shows the session survived). Re-checked by hand on the same upgraded install, same build:
| Step | Result | Observed |
|---|---|---|
| Check-In 15 min armed -> reboot (app not opened) | PASS | armed, pending 4 -> after reboot armed, pending 4 (boot receiver) |
| reopen (waited for the lock screen) -> PIN -> Kontrol Noktası -> İptal Et -> PIN | PASS | native `cancelled`, pending 0 |
