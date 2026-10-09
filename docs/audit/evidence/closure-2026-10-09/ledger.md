# Closure audit 2026-10-09 — çalışma defteri (gerçek uygulama kanıtı)

Başlangıç HEAD `706de9b` (temiz, push edilmedi). Owner kararları (2026-10-09): Y-02, Y-11, A-03, yeniden başlatma + PIN kilidi, Y-09.
Emülatörler: API 36 `KoruBeni_API36` (emulator-5554), API 35 `KoruBeni_A017_API35` (emulator-5556), API 29 `KoruBeni_API29`; hepsi userdebug, root.
Kurulu derleme her satırda: APK sha1 (ilk 12) + `dumpsys package … lastUpdateTime`.

## Y-11 — exact alarm hazırlığı (API 36)
| Derleme | Adım | Gözlem | Sonuç |
|---|---|---|---|
| `943bea9` debug (10:05:23) | ön: `appops … SCHEDULE_EXACT_ALARM default`, "Arka Plan Hazırlığı" çipine dokun | pil sihirbazı açıldı ("Pil Optimizasyonu — Opsiyonel Güvenilirlik Ayarı"), exact alarm yolu yok (`y11_pre_chip_opens_battery_wizard.png`) | FAIL (yeniden üretildi) |
| aynı | ön: Check-In → "Alarm ayarlarını aç" | `REQUEST_SCHEDULE_EXACT_ALARM` package URI'siz → `AlarmsAndRemindersActivity` GENEL liste (Clock / KoruBeni / KoruBeni Smoke, "Not allowed") (`y11_pre_settings_page.png`) | FAIL (yeniden üretildi) |
| `3e701bc990c0` (12:41:17, Y-11 WT) | exact alarm yok → panik | geri sayım YOK; diyalog: "Hiçbir işlem tamamlanmadı" / "Arka plan koruması kapalı. Bu izin olmadan uygulama kapanırsa geri sayım arama yapamaz; bu yüzden panik başlatılmadı. Arka plan korumasını açın ya da acil kişinizi şimdi arayın." / 05551234567 / "Şimdi Ara" / "Arka plan korumasını aç" / "Kapat" (`y11_post_panic_blocked.png`); 12 sn bekleme: DIAL/CALL/Telecom 0 | PASS |
| aynı | "Arka plan korumasını aç" | `dat=package:` → `AlarmsAndRemindersAppActivity` KoruBeni sayfası "Allow setting alarms and reminders" (`y11_post_settings_own_toggle.png`) | PASS |
| aynı | anahtarı ekranda aç → geri → Kapat → panik | kart "Tek eksik: Konum"; native `armed`; geri sayım "5 saniye kaldı" (PIN uiautomator gecikmesiyle geç → arama gitti; araç sınırı) | PASS (korumalı akış) |
| aynı | Ayarlar'dan izni KAPAT → dön | Android süreci öldürdü (pid yok); açılışta kart "Kuruluma 2 adım kaldı"; panik → engelleme diyaloğu; DIAL/CALL 0 | PASS |

## Y-14 (yeni) — silahlı oturumda exact alarm geri alınması (API 36)
| Derleme | Adım | Gözlem | Sonuç |
|---|---|---|---|
| `3e701bc990c0` | Check-In 15 dk (tam + yedek alarm) → Ayarlar'dan izni kapat | logcat `lost permission to set exact alarms!` + `Killing … schedule_exact_alarm revoked`; `dumpsys alarm`: tam alarmlar silindi, yalnız yedekler (GRACE +14 dk 27 sn pencere +11 dk; DISPATCH +15 dk 27 sn pencere +12 dk); native kayıt hâlâ `armed / exactAndInexact` | yeniden üretildi |
| aynı | uygulamayı aç → Kontrol Noktası | "13:44 Kalan süre", hiçbir uyarı yok — tam korumalı görünüyor (`y14_pre_checkin_after_revoke.png`) | FAIL (HIGH) |
| `c2b80f028e3e` (12:56:52, Y-14 WT) | aynı oturum, aç | "Arka plan koruması kapalı veya doğrulanamıyor. Süre dolduğunda uyarı ve arama birkaç dakika gecikebilir. Açmak için dokunun." + 07:56 (`y14_post_degraded_banner.png`) | PASS |
| aynı | uyarıya dokun → KoruBeni anahtarı → aç → geri | uyarı kalktı; `dumpsys alarm`: GRACE ve DISPATCH için tam alarmlar (`window=0 flags=0x5`) yeniden kuruldu + yedekler; PIN ile iptal → `cancelled` | PASS |

## Y-02 — arama sonucu anlatımı (API 36)
| Derleme | Yol | Gerçek ekran metni | Sonuç |
|---|---|---|---|
| `3e701bc990c0` (düzeltme öncesi metin) | panik → Telecom kabul | ~5 sn sonra "Yardım çağrısı henüz gitmedi / Arama bağlanmadı. Aşağıdaki numarayı şimdi manuel arayın." (`y02_pre_failsafe_after_submitted.png`) | FAIL (yeniden üretildi) |
| `f49c9746f120` (13:06:49) | A: panik → native `requestSubmittedUnconfirmed`, Telecom 1, çağrı DIALING | başlık "Arama isteği gönderildi" / "Arama isteği gönderildi. KoruBeni aramanın bağlanıp bağlanmadığını veya karşı tarafın cevap verip vermediğini doğrulayamaz." / kart "Arama isteği Android'e gönderildi — Android arama isteğini kabul etti. KoruBeni bağlantıyı doğrulayamaz; aramanın durumunu telefonunuzun arama ekranında görebilirsiniz."; ~9 sn: diyalog yok, "Şimdi Ara" yok (`y02_post_result_requested.png`) | PASS |
| aynı | B: `pm revoke CALL_PHONE` → panik → 10 sn → ACTION_DIAL | diyalog "Aramayı sizin başlatmanız gerekiyor — Otomatik arama yapılamadı; arama ekranı açıldı. Yeşil arama tuşuna basmadıysanız aşağıdaki numarayı şimdi arayın." + numara + "Şimdi Ara" + "Kapat"; alt ekran "Onayınız gerekiyor — Otomatik arama yapılamadı. Arama ekranı açıldıysa aramayı başlatmak için yeşil arama tuşuna basın." (`y02_post_result_dialer*.png`) | PASS |
| — | C: telefon yeteneği yok | emülatörde SIM/telefon yeteneği kaldırılamıyor; native arm `telephonyUnavailable` → engelleme (birim testleriyle) | NOT PROVEN — EMULATOR LIMITATION |
| — | D: gönderim belirsiz (zaman aşımı) | kaynak: belirsiz → `ACTION_DIAL` (otomatik ikinci arama yok) + çevirici metni; çalışma zamanında zorlanamadı | SOURCE PROVEN / NOT RUNTIME PROVEN |

## Yeniden başlatma + PIN kilidi (API 36, `773876905b05`, 13:15:45) — `lockout-matrix-api36.txt`
15/15 PASS: kill, force-stop, +1 sa, +1 gün, −1 gün, saat dilimi (Istanbul→New York), otomatik saat AÇIK, yeniden başlatma, yeniden başlatma+1 sa, +1 gün, −1 gün, saat dilimi (Tokyo), yeniden başlatma+kill, art arda iki yeniden başlatma: her birinde "Kilitli: Ns" ve doğru PIN reddedildi; yeniden başlatma sonrası bant tam süreye (≈236–237 s / 240 s) döndü. Karşı kontrol: süresi ekranda dolan kilit yeniden başlatmada geri gelmedi, doğru PIN açtı.

## A-03 — son uyarı başarısızlığı (API 36, `3458d6659437`, 13:36:36)
| Adım | Gözlem | Sonuç |
|---|---|---|
| Check-In ekranı | "Süre dolduğunda 60 saniyelik ek süre başlar ve bir uyarı bildirimi gösterilmeye çalışılır. Uyarı gösterilemese bile (ör. bildirimler kapalıysa) ek süre sonunda acil arama akışı başlatılır; arka planda davranış cihaz izinlerine bağlıdır." (`a03_checkin_preexplanation.png`) | PASS (önceden açıklama) |
| bildirim izniyle Check-In 15 dk (ana 13:53:14.823, son 13:54:14.823) → HOME → `pm revoke POST_NOTIFICATIONS` (süreç öldü) → dokunma | native: `graceWarningOutcome=failed`, `fallbackOutcome=failed`, `requestSubmittedUnconfirmed`, `completedAt` …255.316; Telecom `TC@1` 13:54:15.307 (tek); son tarih kaymadı | PASS |
| `korubeni://open/timeline` → PIN | 13:54 satırı: "Arama isteği gönderildi; bağlantı veya yanıt doğrulanmadı. Arama bildirimine erişim doğrulanamadı; gerekirse kişini telefon uygulamasından ara. Son uyarı bildirimi gösterilemedi (bildirimler kapalı olabilir); son tarih değişmedi." (`a03_timeline_reason.png`) | PASS |

## İnceleme turu 2 (2026-10-09 akşam) — yeni düzeltmelerin gerçek uygulama kanıtı (API 36, `KoruBeni_API36`, emulator-5558, 420 dpi, 1080x2400)
Emülatörler 20:05'ten itibaren `-no-audio` ile çalışıyor (kullanıcı isteği). Kurulu derleme her satırda.
| Derleme | Adım | Gözlem | Sonuç |
|---|---|---|---|
| `9c6db0b` debug sha1 `2b4ad096891b` (19:42:26) | Güvenli Yürüyüş ekranı | "Bir zamanlayıcı başlatın. Süre dolduğunda 'Güvendeyim' butonuna basmazsanız 60 saniyelik ek süre başlar ve bir uyarı gösterilmeye çalışılır; ek süre sonunda acil arama akışı başlatılır." (`sw_desc_post_9c6db0b.png`) | PASS |
| aynı | `pm revoke CALL_PHONE` (süreç öldü), exact alarm `allow` → panik | geri sayım başlığı "Sınırlı koruma — uygulama kapanırsa arama yapılmaz", "5 saniye kaldı"; native panik `none` (oturum yok) (`y11_limited_title_post_9c6db0b.png`); PIN → ana sayfa, arayıcı açılmadı | PASS |
| aynı | CALL_PHONE reddedili + exact alarm `default` (uid+paket) → panik | geri sayım YOK; "Hiçbir işlem tamamlanmadı / Arka plan koruması kapalı. … panik başlatılmadı. …" + 05551234567 + "Şimdi Ara" + "Arka plan korumasını aç" + "Kapat"; 12 sn sonra hâlâ diyalog; ACTION_DIAL 0, Telecom 0 (`y11_precedence_both_denied_post_9c6db0b.png`) — öncelik değişikliği öncesi (61d7baa) bu durum `callPermissionDenied` → arayıcı-only geri sayım veriyordu (Kotlin testi + PA-4 mutantı) | PASS |
| aynı | aynı diyalogda "Şimdi Ara" | odak `com.android.dialer/…MainActivity`, tuş takımında 05551234567; Telecom çağrısı 0 (`y11_manual_call_opens_dialer_9c6db0b.png`) | PASS |
| aynı | izinler geri → panik → son tarih | native `armed` → `requestSubmittedUnconfirmed`, Telecom `TC@1` (tek), emülatör çağrıyı ACTIVE yaptı; sonuç ekranında "Telefon uygulamasını aç" kaydırma alanının sonunda, yazısının ortasından KESİK | FAIL (yeni kusur, yerleşim) |
| `ebe5acd` debug sha1 `cf4dccc2a4ba` (19:57:01), emülatör `-no-audio` yeniden başlatma sonrası | panik → son tarih | native `requestSubmittedUnconfirmed`, `TC@1` tek; "Arama isteği gönderildi … doğrulayamaz." bandı + kart tam; bağlantı sabit alt bölümde, kesilmeden (`y02_link_post_ebe5acd.png`) | PASS |
| aynı | "Telefon uygulamasını aç" (573,1835) | odak `com.android.dialer/…MainActivity`, numara 05551234567 dolu; Telecom çağrıları yalnız `TC@1` — ikinci arama yok (`y02_link_tap_opens_dialer_ebe5acd.png`) | PASS |

### Yeniden başlatma + PIN kilidi — inceleme düzeltmeleri sonrası yeniden koşum (`lockout-matrix-api36-ebe5acd.txt`)
`ebe5acd` debug sha1 `cf4dccc2a4ba` (19:57:01), API 36 emulator-5558, `-no-audio`; artık betikli (`tools/lockout_matrix.sh`, RC'de aynen tekrar edilir). 15/15 PASS: kill −9, force-stop, +1 sa, +1 gün, −1 gün, saat dilimi New York, otomatik saat AÇIK → bant azalarak sürdü (231→178 s), doğru PIN reddedildi; 7 yeniden başlatma varyantında (yalın, +1 sa, +1 gün, −1 gün, Tokyo, aç+kill, art arda iki) bant tam süreye döndü (229–237 s / 240 s), doğru PIN reddedildi; 15: aynı açılışta biten kilit yeniden başlatmada geri gelmedi, doğru PIN açtı. Not: monoton okumanın BAŞARISIZ olduğu yollar (tutma penceresi, bekleyen kilit, takılı depo) emülatörde tetiklenemiyor → yalnız birim + 21 mutant (`mutants/lockout-review.log`); çalışma zamanında yalnız regresyon yok kanıtı.
