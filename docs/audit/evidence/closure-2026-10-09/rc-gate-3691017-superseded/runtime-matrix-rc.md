
## API 36 KoruBeni_API36 emulator-5558 RC 3691017 debug sha256 192fc9ae18426f3d
| Step | Result | Observed |
|---|---|---|
| clean install | PASS | API 36; lastUpdateTime 2026-10-10 09:45:37; flags [ DEBUGGABLE HAS_CODE ALLOW_CLEAR_USER_DATA ] |
| onboarding: consent + carousel | PASS |  |
| onboarding: emergency contact + contact consent | PASS |  |
| onboarding: PIN + notification + battery step -> home | PASS |  |
| permissions granted + Pro test anchor -> home | PASS | /Acil kişi hazır Annem • 05551234567 / /Kurulum tamam / /Arka Plan Hazırlığı / /3 adımda hazır olun |
| panic -> countdown -> PIN cancel | PASS | countdown seen=True; native panic=cancelled; 11.0s |
| Check-In 15 min -> PIN cancel | PASS | armed=True; native long=cancelled |
| Safe Walk -> PIN cancel | PASS | armed=True; native long=cancelled |
| widget quick panic -> countdown -> PIN cancel | PASS | countdown seen=True; native panic=cancelled; 10.3s |
| tile quick panic -> countdown -> PIN cancel | PASS | countdown seen=True; native panic=cancelled; 10.3s |
| deep link korubeni://open/settings | PASS |  |
| map tab opens | PASS | /Harita. Konumunuzu gösterir. Harita Konumunuz 41.00824, 28.97837, Konumunuzu haritada görüntüleyin / /Harita |
| timeline via deep link | PASS |  |
| process kill -> reopen -> lock -> PIN -> app | PASS |  |
| logcat review (app processes) | PASS | 0 lines |
