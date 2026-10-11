### OD-1 wall-clock attack on the real app — RC 5aa3fe9 (OD-1 + OD-1c + arm() skew fix) API 36

9/9 PASS

| Step | Result | Observed |
|---|---|---|
| setup: onboarding -> home | **PASS** |  |
| check-in started (native ARMED) | **PASS** | tapStarted=True native=armed final=1791649655519 elapsedDeadline=13097163 |
| attack +1h (TIME_SET in foreground) | **PASS** | native=armed call=notAttempted elapsedDeadline 13097163->13097163 wallDeadline 1791649655519->1791653254927 uiRemaining=7185s nativeLeft=7244s agree=True telecom 1->1 |
| attack -2h (TIME_SET in foreground) | **PASS** | native=armed call=notAttempted elapsedDeadline 13097163->13097163 wallDeadline 1791653254927->1791646053933 uiRemaining=7178s nativeLeft=7237s agree=True telecom 1->1 |
| attack +1d (TIME_SET missed, app force-stopped) | **PASS** | native=armed call=notAttempted elapsedDeadline 13097163->13097163 wallDeadline 1791646053933->1791732453895 uiRemaining=7134s nativeLeft=7192s agree=True telecom 1->1 |
| attack -1d (TIME_SET missed, app force-stopped) | **PASS** | native=armed call=notAttempted elapsedDeadline 13097163->13097163 wallDeadline 1791732453895->1791646053426 uiRemaining=7089s nativeLeft=7148s agree=True telecom 1->1 |
| attack timezone -> Pacific/Kiritimati | **PASS** | native=armed call=notAttempted elapsedDeadline 13097163->13097163 wallDeadline 1791646053426->1791646053426 uiRemaining=Nones nativeLeft=7141s agree=True telecom 1->1 |
| attack timezone -> Europe/Istanbul | **PASS** | native=armed call=notAttempted elapsedDeadline 13097163->13097163 wallDeadline 1791646053426->1791646053426 uiRemaining=Nones nativeLeft=7135s agree=True telecom 1->1 |
| session survived every clock attack still armed | **PASS** | native=armed elapsedDeadline=13097163 |
