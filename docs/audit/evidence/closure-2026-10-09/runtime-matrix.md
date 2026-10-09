# Runtime matrix (closure audit 2026-10-09) — real app, real UI, per API

## API 29 debug 61d7baa (APK sha1 27743ced505a)
| Step | Result | Observed |
|---|---|---|
| clean install | PASS | API 29; lastUpdateTime 2026-10-09 18:39:57; flags [ DEBUGGABLE HAS_CODE ALLOW_CLEAR_USER_DATA ] |
| onboarding: consent + carousel | PASS |  |
| onboarding: emergency contact + contact consent | PASS |  |
| onboarding: PIN + notification + battery step -> home | PASS |  |
| permissions granted + Pro test anchor -> home | PASS | /Acil kişi hazır Annem • 05551234567 / /Kurulum tamam / /Arka Plan Hazırlığı / /3 adımda hazır olun |
| panic -> countdown -> PIN cancel | PASS | countdown seen=True; native panic=cancelled; 10.7s |
| Check-In 15 min -> PIN cancel | PASS | armed=True; native long=cancelled |
| Safe Walk -> PIN cancel | FAIL | armed=False; native long=cancelled |
| widget quick panic -> countdown -> PIN cancel | PASS | countdown seen=True; native panic=cancelled; 12.2s |
| tile quick panic -> countdown -> PIN cancel | PASS | countdown seen=True; native panic=cancelled; 11.4s |
| deep link korubeni://open/settings | PASS |  |
| map tab opens | PASS | /Harita. Konumunuzu gösterir. Harita Konumunuz 37.42200, -122.08400, Konumunuzu haritada görüntüleyin / /Harita |
| timeline via deep link | PASS |  |
| process kill -> reopen -> lock -> PIN -> app | PASS |  |
| logcat review (app processes) | PASS | 0 lines |
