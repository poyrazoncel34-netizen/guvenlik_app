### OD-2 fresh-install runtime proof — RC 5aa3fe9 — API 36 (KoruBeni_API36, emulator-5558, 420 dpi, -no-audio)

12/12 PASS

| Step | Result | Observed |
|---|---|---|
| 1-3. clean install, exact-alarm access at Android default (API 36) | **PASS** | appops=No operations. Default mode: default |
| 4. Skip lands on a visible "Arka Plan Koruması" step that says it is OFF | **PASS** | onStep=True saysOff=True cta=True |
| 5-6. CTA opens the system alarms-and-reminders screen FOR THIS APP | **PASS** | focus com.poyrazoncel.korubeni/com.poyrazoncel.korubeni.MainActivity -> com.android.settings/com.android.settings.spa.SpaActivity :: KoruBeni / 1.0.0 / Allow setting alarms and reminders / Allow this app to set alarms and schedule time-sensitive actions. This lets the app run in the background, whic |
| 7. returning without granting leaves the access off | **PASS** | appops=No operations. Default mode: default backOnStep=True |
| 8a. the background step did not block onboarding completion | **PASS** | reachedHome=True |
| 8b. with the access still off, home does not claim readiness | **PASS** | appops=No operations. Default mode: default headline=/Kurulumun büyük bölümü tamam backgroundNoteShown=True |
| 9-11. access granted (via appops: the same bit the system toggle writes) | **PASS** | appops=SCHEDULE_EXACT_ALARM: allow |
| 12-13. after returning, readiness reads FULLY READY | **PASS** | headline=/Kurulum tamam backgroundNoteShown=False |
| 14-16. a real Check-In arms natively and its exact alarms exist | **PASS** | opened=True native=armed pending=4 exact(window=0)=2 |
| 17-19. revoking the access removes the exact alarms | **PASS** | exact 2 -> 0 (session alarms 4 -> 2) native=armed androidLoggedReason=True |
| 20-21. reopening after a revoke shows no stale READY | **PASS** | headline=/Kurulumun büyük bölümü tamam |
| 22. the live session shows a degraded warning, not full protection | **PASS** | opened=True screen=/KoruBeni güvenlik uygulaması, Acil durumlarda yardım çağırın ve konumunuzu görün / /Geri / /Kontrol Noktası / /Arka plan koruması kapalı veya doğrulanamıyor. Süre dolduğunda uyarı ve arama birkaç dakika gecikebilir. Açmak için dokunun. / / |
