# Chaos audit 2026-10-08 — çalışma defteri (ham gözlemler)

Başlangıç: HEAD `3a1f992`, temiz ağaç. Baseline: `flutter analyze --no-fatal-infos` temiz, `flutter test --no-pub` 2182/2182 (10:0x).

## Oturum 1 — 10:04–10:27
AVD `KoruBeni_A017_API35` (API 35, userdebug, GMS yok, 420 dpi, 1080x2400). Build: `flutter build apk --debug --flavor play`
HEAD `3a1f992`, APK sha1 `475ee4e82fd986393fb8f2c08df98f104d75320e`, `lastUpdateTime=2026-10-08 10:04:48`
(`install -r` — 2026-10-07 verisi korunarak, "eski kullanıcı"). Pro: `tools/inject_pro.sh` (yalnız debug, test amaçlı
yerel çapa; RevenueCat anahtarı yok → `revenuecat_api_key_missing`). PIN 2468, kişi "Annem / 05551234567".
Ekran görüntüleri oturum kesintisinde (scratchpad silindi) kayboldu; anahtar gözlemler oturum 2'de yeniden çekilecek.

| # | Senaryo | Gözlem | Sonuç |
|---|---|---|---|
| U1 | Yerinde güncelleme → aç → yanlış PIN 1111 → doğru PIN | "Yanlış PIN. Tekrar deneyin." → ana sayfa | PASS |
| Y-03 | Pro çapası var, ilk basıştan önce ana sayfa | SOS "Kilitli · Provasını ücretsiz çalıştır · PRO"; basılı tutunca yetki verildi (ilk kullanım uyarısı), sonra "Pro Panik Butonu" | FAIL (UI ↔ yetki tutarsız) |
| P0 | Gerçek panik, iptal yok | 10:09:30 başlangıç → 10:09:40.465 Telecom `CallIntentProcessor` | PASS (emülatör) |
| Y-02 | P0 sonrası sonuç ekranı | Arama aktifken (00:06) sonuç ekranı "Onayınız gerekiyor — … yeşil arama tuşuna basmanız gerekir" + 5 sn sonra "Yardım çağrısı henüz gitmedi / Arama bağlanmadı. … manuel arayın." | FAIL (yanlış olumsuz iddia) |
| P1 | Panik → T+2 HOME → T+5 dön → PIN | kalan 5 sn görünüyor; native `cancelled` | PASS |
| P2 | Panik → T+1 ekran kilidi → 13 sn | 10:16:13 arama; sonuç ekranı; ana sayfaya dönünce durum bildirimi (7777) kalktı | PASS (emülatör) |
| P3 | Panik → T+1 `korubeni://open/timeline` → PIN | bağlantı ertelendi, iptalden sonra zaman çizelgesi açıldı (2 tetik + 2 iptal satırı) | PASS |
| A-11 | Panik → T+2 `run-as kill -9` → T+3 aç | 3 sn splash → açılış kilidi; iptal yüzeyi YOK; native 10:17:48 son tarihte aradı; zaman çizelgesine düştü | FAIL (yeniden üretildi) |
| C1 | Check-In 15 dk → `kill -9` → aç → kilit → Kontrol Noktası | 13:46 kaldı (doğru) | PASS |
| Y-01a | Check-In aktif, ekran önde, `date` +3600 sn | native son tarihler +3599,8 sn kaydı (doğru); Dart ekranı hemen "⚠️ Süre doldu! Yanıt verin! 00:00 EK SÜRE — 60 saniye içinde … arama başlatılacak!" ve 75+ sn öyle kaldı; arama yok; HOME+dönüşte 10:10'a düzeldi | FAIL |
| Y-01b | Aynı oturum, `date` −7200 sn | Dart "129:56 kaldı"; native ana son tarih = şimdi+593 sn | FAIL (kullanıcı 2 sa sanıyor, ~10 dk sonra uyarı+arama) |

Kök neden (Y-01): `ClockChangeReceiver` yalnız `reconcileAfterClockChange()` çağırıyor, Dart'a olay göndermiyor;
`EmergencyTriggerHost`'taki `safetyClockChanged` dinleyicisini native HİÇ tetiklemiyor (ölü dal). `CheckInService`
sayaçları `_endAt`/`_graceEndAt` duvar saatine göre hesaplıyor ve yalnız devamda yeniden okuyor.

## Oturum 2 — 14:16– (kesinti sonrası soğuk açılış, BOOT_COUNT 19; aynı kurulu build `lastUpdateTime=2026-10-08 10:04:48`)
Ekran görüntüleri: `shots/` (tam çözünürlük). Saat değişimi `adb root` + `date @N` (auto_time=0).

| # | Senaryo | Gözlem | Sonuç |
|---|---|---|---|
| N1 | Kesinti: oturum 1'in Check-In'i 3 saat değişikliğiyle silahlı kaldı | native: grace uyarısı `posted`, `completedAt` 10:36:01 `requestSubmittedUnconfirmed` (orijinal son tarih 10:36:02, fark = `date @N` saniye kırpması) | PASS (native süre tabanlı) |
| Y-03 | Soğuk açılış, ana sayfa | `y03_sos_locked_before_press.png` "Kilitli SOS butonu"; 0,4 sn dokunuş sonrası `y03_sos_after_short_press.png` "Pro Panik Butonu" | FAIL |
| Y-01a | Check-In 15 dk (14:18), `date` +3600 | `y01a_clock_forward_false_grace.png`: "Süre doldu! 00:00 EK SÜRE"; native ana son tarih = şimdi+879 sn | FAIL |
| Y-01b | Devam (14:27 kaldı), `date` −7200 | `y01b_clock_back_overstated_remaining.png`: "134:19"; native = şimdi+857 sn | FAIL |
| Y-04 | Panik, T+1'de `date` +3600 | 15:20:43.129 `ACTION_DIAL tel:…` (çevirici, PIN tuş takımı gitti); 15:20:51.546 native otomatik arama (gerçek son tarih). İki arama yolu, iptal penceresi 8 sn erken kapandı | FAIL |
| Y-02 | Y-04 sonrası | `y02_failsafe_after_submitted_request.png` "Yardım çağrısı henüz gitmedi / Arama bağlanmadı"; `y02_result_attention_card.png` "yeşil arama tuşuna basmanız gerekir" (ACTION_CALL'da yeşil tuş yok) | FAIL |
| Y-06 | Test Modu provası: 5 yanlış PIN (≥1 sn arayla) + doğru PIN (14:23:45–52) | prova 10 sn dolmadan iptal edildi (doğru PIN kabul) | — |
| Y-06b | Prova: yalnız 5 yanlış, sonra `kill -9` + aç | açılış kilidi "Kilitli: 17s", tuş takımı devre dışı (`y06_lockout_active_after_rehearsal_misses.png`) → kilit gerçekten devredeydi; prova tuş takımı kilidi YOK SAYIYOR | FAIL (güvenlik) |

Kaynak bulguları (oturum 2): `PinLockoutService` duvar saati (`lockedUntil = DateTime.now()+…`): saat ileri → kilit biter, geri → sahip saatlerce kilitli (Y-05, cihazda henüz koşulmadı).
| Y-05 | Açılış kilidinde 5 yanlış PIN → "Kilitli: 86s" → `date` +3600 | bant anında kalktı, tuş takımı etkin (`y05_lockout_after_clock_forward.png`) | FAIL (güvenlik) |
| Y-05b | 1 yanlış PIN → "Kilitli: 236s" → `date` −7200 → düzelt | "Kilitli: 7431s" (`y05_lockout_after_clock_back.png`) → 225s | FAIL (sahip saatlerce kilitli) |
| S1 | Alarm sesi 3, "Siren" kutucuğuna tek komutta çift dokunuş | tek diyalog; sırasında 7, durdurunca 3 | PASS |
| S2 (A-12) | Siren → `kill -9` → aç | 3 → 7 → 7 → açılışta 3 | PASS (düzeltme doğrulandı) |
| M1 | Uçak modu, konum izni yok → Harita → rıza "Reddet" | "İnternet bağlantısı yok", "Konum alınamadı", çökme/ANR yok | PASS (metin: "konum oturumu" — bkz. Y-09) |
| P5 | Uçak modu + gerçek panik | 14:35:08 Telecom kabul etti, 14:35:08.48 `DisconnectCause Radio off`; native `requestSubmittedUnconfirmed`; uygulama "henüz gitmedi" (bu durumda DOĞRU) | Y-02'nin karşı kanıtı: metin iki durumu ayırt edemiyor |
| K1 | "+90 555 123 45 67" ile mevcut 05551234567'yi tekrar ekle | alan "+905551234567"e normalleşti; rıza onayından SONRA "Bu kişi zaten listede" | PASS (rıza kaydı kopya için de soruluyor — INFO) |
| SW1 | Safe Walk 5 dk → T+10 sn `kill -9` → aç → kilit → Güvenli Yürüyüş | 04:28 kaldı, yeniden bağlandı; başlangıçta "🚶 Check-in Zamanlayıcı — Bilgilendirme" başlığı (Safe Walk için Check-In metni — INFO) | PASS |
| F1 | Fuzz `FUZZ_SCALE=13` (156×10, 130×40, 52×120 eylem) HEAD `3a1f992` | 338/338 geçti (`fuzz-scale13-baseline.txt`) — saat değişimi eylemi YOK, Y-01/Y-04'ü göremez | PASS (kapsam sınırlı) |
| Y-07 | Deterministik widget testi `test/screens/countdown_pin_before_arm_test.dart` (birincil kişi okuması bekletilir, PIN yüklü, doğru PIN) | native arm HİÇ çağrılmadı ama 10 sn sonra `AlertDialog` (başarısız arama) gösterildi | FAIL `[KESİN]` |
| Y-06c | Deterministik widget testi `test/screens/countdown_rehearsal_lockout_test.dart` (5 dk kilit, doğru PIN) | prova kapandı (kilit yok sayıldı) | FAIL `[KESİN]` |
| SW2 | Safe Walk 5 dk ön uyarı | native `preWarningOutcome=posted` 14:42:40; PIN iptali → `cancelled` | PASS |
| R1 | Ayarlar → Cihaz Verilerini Temizle, çift dokunuş | ilk dokunuş diyaloğu açtı, ikinci dokunuş bariyere düşüp kapattı | PASS (zararsız) |
| R2 | Onay → PIN → Doğrula + HOME aynı komutta → 0,4 sn sonra `kill -9` | silme öldürmeden önce bitti: güvenli depo `<map />`, prefs yalnız sonradan yazılan `pref_volume_trigger=false`, native oturum `<map />`, siren günlüğü boş, files/app_flutter/cache boş; yalnız şifreleme anahtar sarmalayıcısı (`FlutterSecureKeyStorage`) kaldı | PASS |
| R3 | Sıfırlamadan sonra aç | Kurulum ve Onay; FATAL/`E/flutter`/`_history.isNotEmpty` 0 | PASS |
| J1 | Sıfırdan yolculuk: onay → tanıtım GERİ (başlatıcıya çıktı) → dönüş (aynı sayfa) → Atla → "123" ("Bu numara aranabilir bir acil kişi numarası değil.") → 05551234567 + rıza → uyuşmayan PIN ("PIN'ler uyuşmuyor") → 2468×2 → pil "Atla" → ana sayfa | hatasız; metinde "degraded modda" (İngilizce sözcük — INFO) | PASS |
| PR1 | `pm revoke CALL_PHONE` → aç → panik | kart "İzin verilmedi — acil durumda dialer açılacak"; geri sayım çalıştı, native oturum yok, son tarihte `ACTION_DIAL` (14:49:06.8) | PASS (tasarım: izinsiz → çevirici) |

## Düzeltme sonrası cihaz doğrulaması (API 35, GMS yok, 420 dpi; debug play build'leri)
| Build (HEAD / APK sha1 / lastUpdateTime) | # | Senaryo | Gözlem | Sonuç |
|---|---|---|---|---|
| `30d85e2` / `f5128722a05b…` / 17:35:32 | V-Y03 | soğuk açılış, ana sayfa | "Pro Panik Butonu" basmadan (`v_y03_sos_cold_start.png`) | PASS |
| aynı | V-Y04 | panik, T+1 `date` +3600 | geri sayım "5 saniye kaldı" + PIN tuşları; ACTION_DIAL yok; tek Telecom isteği 18:36:36.391, native son tarih …36.290 | PASS |
| aynı | V-Y01 | Check-In 15 dk, +1 sa / −2 sa | ekran 14:42 ↔ native 880 sn; ekran 14:35 ↔ native 872 sn | PASS |
| aynı | V-A11a | panik, T+1,5 `kill -9`, aç | yeniden açılıştan 0,8 sn sonra oturum bulundu ama kök Navigator yoktu → yeniden gösterme düştü; native 17:44:11.96'da aradı (`DBG-A11 … nav=false`) | FAIL → `c631736` |
| `c631736` / `70104c46…` / 17:46:42 | V-A11b | aynı | ~3,6 sn sonra geri sayım 6 sn kala, "Acil kişi: A***" (`v_a11_fixed_1..4.png`); PIN → native `cancelled`, 0 arama | PASS |
| aynı | V-QP | durdurulmuş uygulamaya widget trambolini (3×) | 3/3 maskeli geri sayım; PIN iptali, 0 arama | PASS |
| aynı | V-Y06 | prova: 5 yanlış (kilit) + doğru PIN | doğru PIN provayı bitirmedi, prova süresini doldurdu (`v_y06_rehearsal_refuses_locked.png`) | PASS (INFO: yanlış PIN SnackBar kuyruğu kilit mesajını geciktiriyor) |
| aynı | V-Y05a | kilit 56 sn, `date` −7200 | "Kilitli: 50s" (önce 7431 sn) | PASS |
| aynı | V-Y05b | kilit 37 sn, `date` +3600 | bant kalktı, tuş takımı açıldı — servis doğru, EKRAN kendi duvar saati bitişiyle kapıyordu | FAIL → `25fe9d9` |
| `25fe9d9` / `a1cf6a7a…` / 17:55:35 | V-Y05c | kilit 88 sn, `date` +3600 | "Kilitli: 82s", tuş takımı devre dışı (`v_y05_screen_survives_clock_forward.png`) | PASS |
| `25fe9d9` / `a1cf6a7a…` / 17:55:35 | V-Y08 | `pm revoke CALL_PHONE` → panik | 17:58:57.995 ACTION_DIAL; activity_events'te 17:58:58.05 "Acil Durum Tetiklendi" (önce yoktu) | PASS |
| aynı | V-A08 | `korubeni://open/timeline` açıkken `…/open/settings` | ikinci bağlantı hemen yönlendirildi; GERİ → Ayarlar | PASS |
| aynı | I-35 | `am instrument` (19 test, `BootIdentityInstrumentationTest` dahil) | OK (19) — boot_id uygulama sürecinden okunuyor (`instrumentation-api35.txt`) | PASS |

## API 29 (AVD `KoruBeni_API29`, `system-images;android-29;default;arm64-v8a` r08, userdebug, 420 dpi, 1080x2400)
| Build | # | Senaryo | Gözlem | Sonuç |
|---|---|---|---|---|
| `25fe9d9` / 18:00:44 | I-29a | `am instrument` | 17/19: `ScheduledNotificationManifestInstrumentationTest` API 33 API'si (`*Flags.of`) → NoSuchMethodError (test kusuru) | FAIL → `c40d749` |
| aynı + `c40d749` androidTest | I-29b | `am instrument` | OK (19), BootIdentity dahil | PASS |
| aynı | J29 | sıfırdan: onay → tanıtım → kişi+rıza → PIN → pil atla | ana sayfa, FATAL/E-flutter 0 | PASS |
| aynı | P29 | ilk kullanım uyarısı → panik → PIN | native `cancelled` | PASS |
| aynı | A11-29 | panik → root `kill -9` → aç | yeniden bağlanan geri sayım "2 saniye kaldı", "Acil kişi: A***"; (yavaş döküm → PIN son tarihten sonra, arama gitti) | PASS (görünürlük); iptal penceresi API 35'te doğrulandı |
| aynı | Y04-29 | panik + T+1 `date` +3600 | "5 saniye kaldı" + PIN; ACTION_DIAL yok; tek Telecom isteği | PASS |
| aynı | Y-10 | uygulama açıkken HOME → 135 sn → `date` −3600 → aç | aynı süreç (pid 5206) PIN istemeden ana sayfa (`y10_resume_after_clock_back.png`) | FAIL → `cb857b8` |
| `cb857b8` / `7a6a30392077…` / 18:14:13 | Y-10b | aynı senaryo (HOME → 135 sn → `date` −3600 → aç), süreç yaşı 02:52 (HOME'dan önce başlamış, aynı süreç) | devam kilidi gösterildi, PIN istendi | PASS |

## API 36 (AVD `KoruBeni_API36`, `sdk_phone64_arm64`, userdebug, 420 dpi, 1080x2400) — build `cb857b8` / APK sha1 `7a6a30392077…` / lastUpdateTime 2026-10-08 18:17:42
| # | Senaryo | Gözlem | Sonuç |
|---|---|---|---|
| I-36 | `am instrument` | OK (19), BootIdentity dahil (`instrumentation-api36.txt`) | PASS |
| J36 | sıfırdan yolculuk, bildirim izni REDDEDİLDİ, pil/arka plan adımı atlandı | ana sayfa, FATAL/E-flutter 0 | PASS |
| Y08-36 | native oturumsuz panik (exact alarm varsayılan reddi → `exactAlarmDenied`) | 18:20:48.533 ACTION_DIAL → activity_events 18:20:48.56 "Acil Durum Tetiklendi" | PASS |
| Y-11 (yeni gözlem) | temiz kurulum API 36: `appops SCHEDULE_EXACT_ALARM` = default (reddedilmiş), CALL_PHONE verili; panik → T+1,5 `kill -9` → aç | native yuva `<map />` (arm `exactAlarmDenied` ile reddedildi → ön plan çevirici geri sayımı); geri sayım ekranı korunan oturumla AYNI görünüyor ("Acil uyarı devreye giriyor", `a11_36_after_panic.png`); süreç ölünce ne arama ne çevirici; süreç yaşarsa son tarihte ACTION_DIAL (`a11_36_after_deadline.png`) | tasarım gereği (launch-readiness 2026-10-05 satır 6) → SAFETY/PRODUCT DECISION REQUIRED (bkz. defter) |
| A11-36a | `appops set SCHEDULE_EXACT_ALARM allow` → panik → T+1,5 native `armed` → root `kill -9` → aç → ekranı okurken bekledim | yeniden bağlanan geri sayım "6 saniye", "Acil kişi: A***" (`a11_36_reattach.png`); PIN son tarihten SONRA → native aradı (`requestSubmittedUnconfirmed`) | PASS (görünürlük) |
| A11-36b | aynı, açılıştan 3,2 sn sonra otomatik PIN | native `cancelled`, CALL/DIAL 0; altta açılış kilidi (`a11_36_reattach_cancelled.png`) | PASS |
| Y04-36 | panik + T+1 `date` +3600 | sıçramadan sonra "8 saniye" + PIN tuşları (`y04_36_after_jump.png`); native son tarih +3600 yeniden tabanlandı; ACTION_DIAL 0; tek Telecom isteği 19:36:16.024 (gerçek son tarih ~18:36:16 + 1 sa) | PASS |

## İnceleme ajanı bulguları sonrası (2026-10-08 19:00+)
| # | Senaryo | Gözlem | Sonuç |
|---|---|---|---|
| Y-12 emülatör | ekran kapalı 40 sn | `/proc/timer_list` MONOTONIC ve `/proc/uptime` BOOTTIME aynı ilerledi (emülatör uyumadı) | temsili değil |
| Y-12 zorla s2idle | `echo freeze > /sys/power/state` (root), ~5 dk | adbd çevrimdışı; 18:57:40'ta uyandı; MONOTONIC = BOOTTIME (2414,04), ikisi de ~88 sn kaybetti, duvar saati devam etti | emülatör uyku anlamını taklit etmiyor → PHYSICAL DEVICE REQUIRED |
| Y-12 prob API 36 | `tools/y12_probe.dart.txt` debug girişi, `-t` ile | `abi=android_arm64 reader=true bootUs=2940146879 systemMonotonicUs=2940147883`; 3 sn sonra `/proc/uptime` 2943,47 → `SafetyClock.system` BOOTTIME'a bağlı | PASS (bağlama) |

## İnceleme ajanları (flutter / kotlin / security, salt-okur, 2026-10-08 18:40–18:55) — bulgu → karar
| Kaynak | Bulgu | Doğrulama | Karar / commit |
|---|---|---|---|
| flutter M1 | `SafetyClock.system` = `Stopwatch` (CLOCK_MONOTONIC, uykuda durur) | Dart VM Android monotonik = CLOCK_MONOTONIC; native elapsedRealtime = CLOCK_BOOTTIME; emülatör uykuyu taklit etmiyor | **Y-12** düzeltildi `e5e786b` (FFI CLOCK_BOOTTIME); prob API 36 PASS; uyku davranışı PHYSICAL DEVICE REQUIRED |
| kotlin M1 | iki BOOT_COUNT biliniyorsa boot_id hiç sorulmuyor | yeni test: geç artan sayaç + aynı açılış +1 sa → `MANUAL_ACTION_REQUIRED` (kırmızı) | düzeltildi `9eeb73d` |
| kotlin L3 / L4 | uzlaştırma istisnasında olay yayılmıyor; olay testi küresel veri yoluna açık | test kırmızı (0 olay) | düzeltildi `9eeb73d` |
| security M2 / kotlin M2 | kilit anlık görüntüsünde boot_id yok → BOOT_COUNT okunamazsa duvar saati | test kırmızı | düzeltildi `0c3a94a` |
| security L1 / flutter L1 | duvar anahtarı elapsed'den önce yazılıyor → yarım yazımda eski son tarih karar verir | test kırmızı (kilit açık) | düzeltildi `0c3a94a` |
| security M3 (kısmen) | devam kilidinde okuma hatası → yalnız duvar saati | test kırmızı | düzeltildi `2d39f39` (native saat kuruluyken fail-closed). PIN kilidinde okuma hatası → duvar (sınırlı) kalan risk, LOW |
| flutter M3 / L3 | yeniden gösterme ile hızlı tetikleyici yarışı; bekleme duvar saatine bağlı | iki test kırmızı | düzeltildi `b24ee18` |
| flutter test kalitesi | `countdown_pin_before_arm_test` sabit gerçek-zaman dilimleri; `ArmUnknown` vakası yok | — | `943bea9` (koşul beklemesi + `ArmUnknown`; mutasyon: belirsiz belirteç yok sayılınca kırmızı) |
| security M1 / flutter L7 | yeniden başlatma + saat ileri → bir kilit atlanır | belgelenmiş kalan risk | **SECURITY DECISION REQUIRED** |
| flutter M2 | yanlış PIN kaydı ek I/O | registerFailure monotonik okumayı yalnız kilit yazarken yapar | LOW, değişiklik yok |
| flutter L2 | Check-In `safetyClockChanged` süren geri yüklemede düşebilir | dar yarış; native yetkili | LOW, belgelendi |
| flutter L4 | her devamda `_lockActive` ≤1 sn | paywall yeniden değerlendirme doğru | INFO |
| flutter L5 | yeniden bağlanmada maskeli ad güncel birincil kişiden | 10 sn içinde kişi değişimi pratikte imkânsız | LOW, belgelendi |
| flutter L6 | `ArmUnknown` + Y-08 çift satır olabilir | eksik satırdan iyi (tasarım) | LOW, belgelendi |
| security L2 | bozuk monotonik anahtar → duvar | bozuk duvar gibi kapatmak sahibi kalıcı kilitleyebilir | LOW, belgelendi |
| security L3 | prova tuşu saniyede bir kayıp | — | LOW |
| security L4 | `debugPrint` taşındı | release'de `main.dart:38` susturuyor | INFO |
| kotlin L1 / L2 | A-02↔A-02r arası kayıt bir açılış id'siz; eski kaydın duvar yeniden tabanlaması TIME_SET ile yarışabilir | yayımlanmamış ara derleme | LOW, belgelendi |
| (yeni, kendi bulgum) | `cb857b8` `elapsed`→`wallElapsed` yeniden adlandırması `safety_session_callsite_contract_test`'i kırdı, commit öncesi tam paket koşulmamıştı | tam paket | değişken adı geri alındı, `cb857b8`'e katlandı → yeni kimlik `e1192a3` (geçmiş yeniden yazıldı; dal hiç push edilmedi) |

### Geçmiş yeniden yazımı (2026-10-09 09:44, dal hiç push edilmedi)
Yedek: `backup/chaos-pre-fixup-20261009` (= eski `8211c14`). Eski → yeni: `cb857b8`→`e1192a3` (yalnız `wallElapsed`→`elapsed`),
`6546b10`→`e5e786b`, `4e7812b`→`9eeb73d`, `a935006`→`0c3a94a`, `86b68a0`→`2d39f39`, `6b5f8c4`→`b24ee18`, `8211c14`→`943bea9`.
Son ağaç yedekten yalnız bu 2 satırla farklı (`git diff backup… HEAD --stat`: 1 dosya, 2+/2-). Yeniden yazım öncesi tam paket
(HEAD + yeniden adlandırma): 2534/2534 (`full-suite-pre-fixup.txt`).
(`cb857b8` derlemeleriyle yapılan cihaz koşuları `e1192a3` ile davranışça aynıdır: fark yalnız yerel değişken adı.)

## Cihaz: inceleme sonrası (API 36, `KoruBeni_API36`, 420 dpi; makine commit-başı doğrulamayla yüklü, yük ~5)
| Build | # | Senaryo | Gözlem | Sonuç |
|---|---|---|---|---|
| `943bea9` / APK sha1 `61c71259ab55…` / lastUpdateTime 2026-10-09 09:45:52 | W1 | panik → native `armed` → root `kill -9` → widget trambolini ile soğuk açılış (`tools/race_a11.sh`, tuş takımı pikselden tespit) | tuş takımı açılıştan 4,7 sn sonra; geri sayım native son tarihiyle "5 saniye", "Acil kişi: A***", diyalog yok (`a11r_race_after_pin.png`); PIN → native `cancelled`, CALL/DIAL 0 | PASS |
| aynı | W2 | aynı, uiautomator ile tespit | uiautomator animasyonlu ekranda "idle" alamadı, tespit 10 sn gecikti → PIN son tarihten sonra, arama gitti | araç sınırı (kusur değil) |
| aynı | W3 | aynı, sabit 3 sn sonra PIN | o anda açılış ekranı vardı (`a11r_before_pin.png`), dokunuşlar boşa | zamanlama (kusur değil); INFO: yüklü makinede debug soğuk açılış 10 sn'nin ~4,7'sini yiyor |
| **`2d39f39` (düzeltme öncesi)** / APK sha1 `a4e7737e803a…` / 10:03:49 | W4 | W1 ile aynı betik | taze geri sayım "10" üstünde **"Hiçbir işlem tamamlanmadı — Güvenlik oturumu kurulmadı…"** diyaloğu, PIN tuşları erişilemez (`a11r_race_prefix_after_pin.png`); native 10:04:53.4'te aradı | **Y-13 yeniden üretildi (HIGH)** → `b24ee18` |
| `943bea9` | Y05r | soğuk açılış kilidi, 5 yanlış PIN → "Kilitli: 27s" → `date` +3600 | "Kilitli: 15s" sürdü; PIN ancak kilit doğal bitince kabul edildi | PASS |
| `943bea9` | A02r-dev | Check-In 15 dk → `adb reboot` → yeni açılışta `date` +3600 → Check-In ekranı | önce: boot_id `6480e850…`, BOOT_COUNT 2, elapsed son tarih 2273381; açılıştan sonra: son tarih aynı (1791530556529), kayıt `f729edc7…` + BOOT_COUNT 3 ile yeniden damgalandı, elapsed 938119 (kalan ~923 sn, duvar farkıyla tutarlı); +1 sa sonra duvar son tarihi +3599,2 sn kaydı, elapsed son tarih ve alarm (+14 dk 44 sn) aynı; ekran "13:19" = native kalana eşit; PIN ile iptal → `cancelled` | PASS |
| `943bea9` | Y10r | HOME 10 sn → aç; HOME 130 sn → `date` −3600 → aç | kısa: kilit yok; uzun + saat geri: kilit var | PASS |
| `943bea9` | Y12r | panik, dokunma (Y-12 sonrası normal yol) | native son tarih …26.868 → tamamlanma …26.924; tek Telecom isteği; erken Dart gönderimi yok | PASS |
| prob (`y12_probe.dart.txt`) API 29 (`KoruBeni_API29`, arm64) | Y12-29 | prob girişi | `reader=true bootUs=41616569 systemMonotonicUs=41617762`; 4,5 sn sonra `/proc/uptime` 46,07 → Android 10 bağlayıcısında da `libc.so` FFI çalışıyor | PASS (bağlama) |
| `943bea9` / sha1 `61c71259ab55…` API 29 | P29r | panik → "8 saniye kaldı" → PIN | native `cancelled`, CALL/DIAL 0, E/flutter 0 | PASS |

## Release (smoke, debuggable değil, R8 + AOT) — API 29 (`KoruBeni_API29`, userdebug, arm64, 1080x2274)
Build `943bea9` / APK sha1 `6873e282cdf9…` / `com.poyrazoncel.korubeni.smoke` lastUpdateTime 2026-10-09 10:24:28 / pkgFlags `HAS_CODE ALLOW_CLEAR_USER_DATA` (DEBUGGABLE yok).
| # | Senaryo | Gözlem | Sonuç |
|---|---|---|---|
| R1 | temiz kurulum: onay kutuları → Devam → tanıtım Atla → kişi + rıza → PIN 2468×2 → pil "Şimdilik Atla" | ana sayfa; E/flutter yalnız Impeller "EGL Error: Success" emülatör gürültüsü | PASS |
| R2 | `tools/inject_pro_root.sh` (root ile çevrimdışı Pro çapası — test amaçlı, ticaret kanıtı değil) + CALL_PHONE → panik | ilk kullanım uyarısı → onay → panik → native `armed` → "8 saniye kaldı" → PIN → `cancelled` | PASS |
| R3 | panik → native `armed` görülür görülmez root `kill -9` → başlatıcı | açılıştan 3,6 sn sonra "5 saniye kaldı", "Acil kişi: A***"; uiautomator iki dökümü PIN'i son tarihin ardına itti → arama gitti, zaman çizelgesine "Acil Durum Tetiklendi" 10:29:32.189 | PASS (görünürlük) |
| R4 | R3, tek dökümde tespit+PIN (`tools/live_pin.py`) | açılıştan ~3 sn sonra geri sayım, PIN → `cancelled`, CALL/DIAL 0 | PASS |
| R5 | yerel hata günlüğü + logcat | `app_flutter/korubeni.db` `crash_logs` 0 satır; logcat FATAL/ANR/PlatformException/MissingPluginException/flutter_framework_unhandled 0 | PASS |
| R6 (Y-12 AOT) | prob girişi `--release --flavor smoke` (AOT, R8), API 29 | `reader=true bootUs=1404634752 systemMonotonicUs=1404634825`; ~4 sn sonra `/proc/uptime` 1408,49 → üretim yapılandırmasında da `SafetyClock.system` BOOTTIME | PASS (bağlama) |

## Release (smoke) — API 36, 2026-10-08 18:47 (build `cb857b8` ≡ `e1192a3` davranışı / sha1 `81984253a02c…` / lastUpdateTime 2026-10-08 18:47:32)
| # | Senaryo | Gözlem | Sonuç |
|---|---|---|---|
| RO1 | onay ekranında hiçbir kutu seçmeden "Devam Et" | ekranda kaldı (inert) | PASS |
| RO2 | tanıtımda döndürme (`user_rotation 1`) | dikey kilitli; ekran görüntüsü siyah (FLAG_SECURE) | PASS |
| RO3 | tanıtım 1/5'te `kill -9` → aç | tanıtım 1/5'ten devam; onaylar korunmuş | PASS |
| RO4 | kişi "Annem Rel" + "+90 555 123 45 67"; rıza işaretlemeden "Ekle"; sonra rıza + "Ekle" üçlü dokunuş | "Ekle" devre dışı; tek kayıt "Annem Rel birincil acil kişiniz olarak kaydedildi" | PASS |
