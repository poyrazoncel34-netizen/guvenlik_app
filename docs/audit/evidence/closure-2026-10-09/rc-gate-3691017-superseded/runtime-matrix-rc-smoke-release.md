
## API 29 emulator-5556 RC 3691017 SMOKE RELEASE (R8+AOT) sha256 17b12f9a01106054 (run 2, fixed widget extra key)
| Step | Result | Observed |
|---|---|---|
| clean install | PASS | API 29; lastUpdateTime 2026-10-10 10:05:09; flags [ HAS_CODE ALLOW_CLEAR_USER_DATA ] |
| onboarding: consent + carousel | PASS |  |
| onboarding: emergency contact + contact consent | PASS |  |
| onboarding: PIN + notification + battery step -> home | PASS |  |
| permissions granted + Pro test anchor -> home | PASS | /Acil kişi hazır Annem • 05551234567 / /Kurulum tamam / /Arka Plan Hazırlığı / /3 adımda hazır olun |
| panic -> countdown -> PIN cancel | PASS | countdown seen=True; native panic=cancelled; 9.6s |
| Check-In 15 min -> PIN cancel | PASS | armed=True; native long=cancelled |
| Safe Walk -> PIN cancel | PASS | armed=True; native long=cancelled |
| widget quick panic -> countdown -> PIN cancel | PASS | countdown seen=True; native panic=cancelled; 9.5s |
| tile quick panic -> countdown -> PIN cancel | PASS | countdown seen=True; native panic=cancelled; 11.5s |
| deep link korubeni://open/settings | PASS |  |
| map tab opens | PASS | /Harita. Konumunuzu gösterir. Harita Konumunuz 37.42200, -122.08400, Konumunuzu haritada görüntüleyin / /Harita |
| timeline via deep link | PASS |  |
| process kill -> reopen -> lock -> PIN -> app | PASS |  |
| logcat review (app processes) | PASS | 0 lines |
