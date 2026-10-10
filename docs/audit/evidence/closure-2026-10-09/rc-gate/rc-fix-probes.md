
## RC ff945ee debug sha256 f2e3078eef3f68cf — KoruBeni_API29 emulator-5556 (P9 on the affected OS) — API 29, lastUpdateTime 2026-10-10 12:20:03
| Probe | Result | Observed |
|---|---|---|
| P9 force-stop during an armed Check-In -> reopen restores its alarms | PASS | armed=armed pending=4 -> force-stop 0 -> reopen 4; native after reopen=armed; end=cancelled |

## RC ff945ee debug sha256 f2e3078eef3f68cf — KoruBeni_API36 emulator-5558, 420 dpi, -no-audio — API 36, lastUpdateTime 2026-10-10 12:23:10
| Probe | Result | Observed |
|---|---|---|
| P1 Safe Walk intro | PASS | Bir zamanlayıcı başlatın. Süre dolduğunda 'Güvendeyim' butonuna basmazsanız 60 saniyelik ek süre başlar ve bir uyarı gösterilmeye çalışılır; ek süre sonunda acil arama akışı başlatılır.  |
| P2 Help FAQ (Y-09) | PASS | S: Konum pil tüketiyor mu? C: Konum yalnız harita ekranı açıkken okunur; uygulama konumu arka planda izlemez ve kaydetmez. Harita görüntüleri indirilip cihazda önbelleğe alınır.  S: Sahte çağrı gerçek mi görünüyor? C: Uygulama cihaz içinde sahte gelen arama ekranı simüle eder. Gerçek telefon araması |
| P3 Y-11c CALL_PHONE refused -> limited heading | PASS | heading=True native=none pin=True calls+=0 focus=com.poyrazoncel.korubeni/com.poyrazoncel.korubeni.MainActivity |
| P4 Y-11b both refused -> exact-alarm refusal; manual call opens dialer only | PASS | refusal=True no_countdown_12s=True dialer=True calls+=0 |
| P5 Y-11 exact alarm refused -> refusal; button opens this app's own toggle | FAIL | refusal=False focus=com.android.dialer/com.android.incallui.InCallActivity page=05551234567 / 13:01/13 minutes, 1 second / /Unmuted / Mute / /Keypad / Keypad / /Speaker, is on / Speaker / /Add call /  |
| P6 Y-02 accepted request: one call; quiet link opens dialer, places none | PASS | arm=armed native=requestSubmittedUnconfirmed calls_after_dispatch=+1 calls_after_link=+0 focus=com.android.dialer/com.android.dialer.main.impl.MainActivity (shot p6_accepted_request.png) |
| P7 Y-14 revoke during Check-In -> notice -> settings -> re-grant restores exact alarms | PASS | armed=armed process_killed=True notice=True settings=True notice_gone=True exact_alarms=2 end=cancelled |
| P8 A-03 final warning fails -> single call at the final deadline + timeline reason | FAIL | armed=cancelled final=cancelled graceWarningOutcome=notAttempted calls+=0 timeline_reason=False |
| P9 force-stop during an armed Check-In -> reopen restores its alarms | FAIL | armed=cancelled pending=0 -> force-stop 0 -> reopen 0; native after reopen=cancelled; end=cancelled |

## RC ff945ee debug sha256 f2e3078eef3f68cf — KoruBeni_API36 emulator-5558 — re-run of P5 after clearing an emulator-modem 'unknown call' (TSI.aNUC 12:22:40, callingPackage null) left on top by a reboot — API 36, lastUpdateTime 2026-10-10 12:58:07
| Probe | Result | Observed |
|---|---|---|
| P5 Y-11 exact alarm refused -> refusal; button opens this app's own toggle | PASS | refusal=True focus=com.android.settings/com.android.settings.spa.SpaActivity page=KoruBeni / 1.0.0 / Allow setting alarms and reminders / Allow this app to set alarms and schedule time-sensitive actions |

## RC ff945ee debug sha256 f2e3078eef3f68cf — KoruBeni_API36 emulator-5558 — re-run of P8, P9 after clearing the emulator-modem 'unknown call' — API 36, lastUpdateTime 2026-10-10 12:58:07
| Probe | Result | Observed |
|---|---|---|
| P8 A-03 final warning fails -> single call at the final deadline + timeline reason | FAIL | armed=none final=none graceWarningOutcome=None calls+=0 timeline_reason=False |
| P9 force-stop during an armed Check-In -> reopen restores its alarms | FAIL | armed=none pending=0 -> force-stop 0 -> reopen 0; native after reopen=none; end=none |

## RC ff945ee debug sha256 f2e3078eef3f68cf (rebuilt 2026-10-10 15:4x, byte-identical) — KoruBeni_API36 emulator-5558 — P8, P9 re-run 3 after machine restart (fresh install 15:50:29) — API 36, lastUpdateTime 2026-10-10 15:50:29
| Probe | Result | Observed |
|---|---|---|
| P8 A-03 final warning fails -> single call at the final deadline + timeline reason | FAIL | armed=none final=none graceWarningOutcome=None calls+=0 timeline_reason=False |
| P9 force-stop during an armed Check-In -> reopen restores its alarms | PASS | armed=armed pending=4 -> force-stop 0 -> reopen 4; native after reopen=armed; end=cancelled |

## RC ff945ee debug sha256 f2e3078eef3f68cf — KoruBeni_API36 emulator-5558 — P8 with a 15-minute Check-In (the probe's earlier '5 dk' chip does not exist) — API 36, lastUpdateTime 2026-10-10 15:50:29
| Probe | Result | Observed |
|---|---|---|
| P8 A-03 final warning fails -> single call at the final deadline + timeline reason | PASS | armed=armed final=requestSubmittedUnconfirmed graceWarningOutcome=failed calls+=1 timeline_reason=True |
