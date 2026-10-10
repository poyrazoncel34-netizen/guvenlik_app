### OD-1 wall-clock attack on the real app — POST-FIX (OD-1 + OD-1c) API 36

9/9 PASS

| Step | Result | Observed |
|---|---|---|
| setup: onboarding -> home | **PASS** |  |
| check-in started (native ARMED) | **PASS** | tapStarted=True native=armed final=1791670456174 elapsedDeadline=12628895 |
| attack +1h (TIME_SET in foreground) | **PASS** | native=armed call=notAttempted elapsedDeadline 12628895->12628895 wallDeadline 1791670456174->1791674055913 uiRemaining=7185s nativeLeft=7243s agree=True telecom 29->29 |
| attack -2h (TIME_SET in foreground) | **PASS** | native=armed call=notAttempted elapsedDeadline 12628895->12628895 wallDeadline 1791674055913->1791666855159 uiRemaining=7179s nativeLeft=7236s agree=True telecom 29->29 |
| attack +1d (TIME_SET missed, app force-stopped) | **PASS** | native=armed call=notAttempted elapsedDeadline 12628895->12628895 wallDeadline 1791666855159->1791753254847 uiRemaining=7130s nativeLeft=7188s agree=True telecom 29->29 |
| attack -1d (TIME_SET missed, app force-stopped) | **PASS** | native=armed call=notAttempted elapsedDeadline 12628895->12628895 wallDeadline 1791753254847->1791666854249 uiRemaining=7084s nativeLeft=7141s agree=True telecom 29->29 |
| attack timezone -> Pacific/Kiritimati | **PASS** | native=armed call=notAttempted elapsedDeadline 12628895->12628895 wallDeadline 1791666854249->1791666854249 uiRemaining=7073s nativeLeft=7130s agree=True telecom 29->29 |
| attack timezone -> Europe/Istanbul | **PASS** | native=armed call=notAttempted elapsedDeadline 12628895->12628895 wallDeadline 1791666854249->1791666854249 uiRemaining=7064s nativeLeft=7122s agree=True telecom 29->29 |
| session survived every clock attack still armed | **PASS** | native=armed elapsedDeadline=12628895 |
