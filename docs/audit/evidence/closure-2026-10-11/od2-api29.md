### OD-2 fresh-install runtime proof — API 29 (KoruBeni_API29, emulator-5556, 420 dpi, -no-audio) — no-regression check

6/6 PASS

| Step | Result | Observed |
|---|---|---|
| 1-3. clean install, exact-alarm access at Android default (API 29) | **PASS** | appops=(empty) |
| 4. API 29: no such access exists, step reports it as ON (no regression) | **PASS** | onStep=True cta=False lines=['/Arka plan koruması açık.'] |
| 5-7. API 29 has no exact-alarm special access to request | **PASS** | skipped by OS |
| 8a. the background step did not block onboarding completion | **PASS** | reachedHome=True |
| 8b-13. API 29: nothing to grant | **PASS** | skipped by OS |
| 14-16. a real Check-In arms natively and its exact alarms exist | **PASS** | opened=True native=armed pending=4 exact(window=0)=2 |
