# KoruBeni — Final Gerçek-İnsan Kapanışı + Çalışma Zamanı Kanıtı (2026-10-09 / 10)

Başlangıç HEAD `706de9b`. **RELEASE_CANDIDATE_HEAD = `3691017`** (dal `codex/evidence-remediation-20260911`,
**push edilmedi**). Uygulama kodu (`lib/`, `android/`, `assets/`, `pubspec.*`) `45ebf8b`'den beri değişmedi;
`45ebf8b..3691017` yalnız test taşıma + kanıt. Ham kanıt: [`evidence/closure-2026-10-09/`](evidence/closure-2026-10-09/)
(`ledger.md` cihaz satırları, `mutants/` karşı-olgusal mutantlar, `rc-gate/` RC kapısı).

Owner kararları (Y-02, Y-11, A-03, yeniden başlatma + PIN kilidi, Y-09) ONAYLI kabul edildi, yeniden sorulmadı.
Kural: kanıtlanamayan hiçbir şeye PASS yazılmadı; fiziksel cihaz → **PHYSICAL DEVICE REQUIRED**, mağaza/abonelik →
**EXTERNAL SYSTEM REQUIRED**.

## 0. RC kapısı — RELEASE_CANDIDATE_HEAD `ff945ee` (tüm kanıt bu HEAD'de yeniden üretildi)

Uygulama kodu `cdc4024` ile aynı (`git diff cdc4024 ff945ee -- lib android assets pubspec.*` boş). Önceki aday
`3691017`'nin koşusu force-stop kusurunu (FS-01) buldu → geçersiz, arşivde (`rc-gate-3691017-superseded/`).
Ham çıktılar: [`evidence/closure-2026-10-09/rc-gate/`](evidence/closure-2026-10-09/rc-gate/).

| Kapı | Sonuç | Kanıt |
|---|---|---|
| Temiz checkout (`git worktree`), `flutter clean`, `verify_release.sh` | **PASS** `LOCAL_CANDIDATE_PASS` — analyze 0 sorun; `flutter test` 2580/2580 + kritik coverage; imzalı smoke AAB + release yüzeyi; lint + Kotlin unit + instrumentation derlemesi; 16 KB; lisans/notices | `verify_release.txt` |
| Kotlin unit | **187/187** | `artifact-hashes.txt` |
| AAB sha256 | `3755c57081d9cc95c1caee7ebf18b3b421a25715b1709665534f0032d79cee2d` (smoke, Play'e yüklenemez) | `artifact-hashes.txt` |
| Birleşik manifest sha256 | `edab5243eed17a59a1aa357b8954272e65457f34e1cb8ccad4df27e81fa680a9`; 8/8 yasak izin yok (USE_EXACT_ALARM, FOREGROUND_SERVICE, AD_ID, arka plan konum, rehber, tam ekran niyet, SMS, telefon durumu); izin farkı (706de9b'ye göre) yok | `merged-manifest-inspection.txt` |
| Test APK sha256 | `021e0456a0601c2788ddd219ba2621416a2bda0f62d5989b0431fc94ad65b1b3` | `artifact-hashes.txt` |
| RC APK'ları | debug `f2e3078eef3f68cfa0d099b0f43a354e1fd6e5a91943611daccb7cfb0d5a951f`; smoke release `43a0166c8fac0ad326a9eb050da72642ec7f9551e756adab6d5588d9b2457f03` | cihaz satırları |
| Gizli anahtar taraması | **PASS** 0 bulgu | `secrets-scan.json` |
| OSV bağımlılık denetimi | **PASS** bilinen bulgu yok (pub 195 + maven 203 sorgu; yalnız tarama anı) | `osv.json`, `osv-audit.txt` |
| FUZZ_SCALE=13 | **PASS** 4043 vaka | `fuzz-scale13.txt` |
| `run_safety_mutations.py` | **PASS** 7/7 öldürüldü | `safety-mutations.json` |
| Karşı-olgusal mutantlar (bu denetimin tümü) | **PASS** 58/58 öldürüldü, sonra ağaç temiz | `counterfactual-all-at-rc.txt` |
| Kritik testler ×10 (36 dosya, 186 test) | **PASS** 10/10 | `critical-tests-x10.txt` |
| Çalışma zamanı matrisi API 36 (debug) | **PASS** 15/15, logcat 0 satır | `runtime-matrix-rc.md` |
| Çalışma zamanı matrisi API 29 (debug) | **PASS** 15/15, logcat 0 satır | `runtime-matrix-rc-api29.md` |
| Release smoke (R8 + AOT, DEBUGGABLE yok) API 29 | **PASS** 15/15, logcat 0 satır | `runtime-matrix-rc-smoke-release.md` |
| Kilit matrisi API 36 (yeniden başlatma + saat + dilim) | **PASS** 15/15 | `lockout-matrix-api36-rc.txt` |
| v1.0.2 → RC yükseltme (API 29, debug→debug) | **PASS** 240 s kilit yükseltmeyi aştı (yeniden rıza sonrası 207 s, force-stop sonrası 160 s), veri korundu; silahlı Check-In kill −9 / **force-stop → aç (4 alarm)** / yeniden başlatma; son adım prob zamanlaması → elle yeniden kontrol PASS | `upgrade-v102-to-rc.md` |
| P9 force-stop → aç alarmları geri kurar (API 29, etkilenen OS) | **PASS** 4 → 0 → 4 | `rc-fix-probes.md` |
| Instrumentation API 29 | **PASS** OK (19 test) | `instrumentation-api29.txt` |
| Düzeltme probları API 36 (`rc_fix_probes.py`) | P1 Güvenli Yürüyüş tanıtımı **PASS**; P2 Yardım SSS (Y-09) **PASS**; P3 "Sınırlı koruma" başlığı, native `none`, arama 0 **PASS**; P4 ikisi reddi → kesin alarm reddi, 12 sn geri sayım yok, "Şimdi Ara" yalnız arayıcı, Telecom 0 **PASS**; P5 kesin alarm reddi → "Arka plan korumasını aç" uygulamanın kendi anahtarı **PASS** (ilk koşu: yeniden başlatmada emülatör modeminin yeniden eklediği "bilinmeyen çağrı" — `TSI.aNUC`, çağıran paket yok — üstteydi; modem temizlenip yeniden koşuldu); P6 kabul edilen istek: tek Telecom çağrısı, sessiz bağlantı arayıcıyı açar, ikinci çağrı yok **PASS**; P7 Check-In sırasında izin geri alındı → uyarı → ayarlar → yeniden izin → tam alarmlar geri **PASS** | `rc-fix-probes.md`, `rc-fix-probes-api36*.out.txt` |
| Instrumentation API 36 | **PASS** OK (19 test) | `instrumentation-api36.txt` |
<!-- RC-ROWS -->


## 1. Ortam ve kanıt standardı

| Ortam | Ayrıntı |
|---|---|
| API 36 | AVD `KoruBeni_API36`, emulator-5558, userdebug, root, 420 dpi, 1080x2400 |
| API 35 | AVD `KoruBeni_A017_API35`, emulator-5554, userdebug, root, GMS yok, 420 dpi, 1080x2400 |
| API 29 | AVD `KoruBeni_API29`, emulator-5556, userdebug, root, 420 dpi |
| Ses | 2026-10-09 20:05'ten itibaren tüm emülatörler `-no-audio` + ses akışları 0 (kullanıcı isteği) |
| Kurulu derleme | her cihaz satırında APK özeti + `dumpsys package … lastUpdateTime` |
| Pro | yalnız TEST amaçlı çevrimdışı çapa (root ile); **ticaret kanıtı değil** |
| Arama | yalnız emülatör-kontrollü numara `05551234567` (emülatör modemi); gerçek üçüncü kişi aranmadı |

Her düzeltme: yeniden üretim → kök neden → regresyon testi (önce KIRMIZI) → düzeltme → **karşı-olgusal mutant**
(`tools/counterfactual.py`: kaynak sha256 önce/mutant/geri; mutant testleri kırmızı yapmalı) → gerçek uygulamada
çalışma → tekrar bozmayı deneme (chaos / matris) → inceleme (security-reviewer, flutter-reviewer; bulguları ayrıca
düzeltildi).

## 2. Kusur defteri

Sütunlar: ID · Önem · Durum · Yeniden üretim · Kök neden · Düzeltme · Regresyon testi · Karşı-olgusal kanıt ·
Çalışma zamanı kanıtı · Kalan risk · Commit.

| ID | Önem | Durum | Yeniden üretim | Kök neden | Düzeltme | Regresyon testi | Karşı-olgusal | Çalışma zamanı | Kalan risk | Commit |
|---|---|---|---|---|---|---|---|---|---|---|
| Y-11 | HIGH | FIXED | API 36 temiz kurulum: exact alarm varsayılan reddi → panik → korumalı görünen arayıcı-only geri sayım; süreç ölümünde kimse aranmıyordu; ayar butonu genel listeyi, ana sayfa çipi pil sihirbazını açıyordu (`ledger.md` Y-11 FAIL satırları) | `exactAlarmDenied` foreground-dial izin listesindeydi; ayar intent'i `package:` URI'siz; çip yönlendirmesi tek hedefli | panik reddedilir: "Arka plan korumasını aç" (kendi anahtarı, reddinde uygulama sayfası) + "Şimdi Ara"; çip eksik izne gider | `panic_arm_policy_test` Y-11, `countdown_exact_alarm_required_test`, `background_protection_fix_test`, `ExactAlarmSettingsIntentTest` | `earlier-fixes.log` Y11-1..5 KILLED | API 36 `3e701bc990c0`: diyalog birebir, kendi anahtarı, 12 sn DIAL/CALL 0, izin → `armed`; geri alma → süreç öldü, "Kuruluma 2 adım kaldı" | OD-2 (ilk panikte izin isteği onboarding'de yok) | `b63a685`, `61d7baa` |
| Y-11b | MEDIUM | FIXED | CALL_PHONE + exact alarm ikisi reddiyken native `callPermissionDenied` döndü → arayıcı-only geri sayım (inceleme) | native red önceliği CALL_PHONE'u önce kontrol ediyordu | `exactAlarmDenied` önce | Kotlin `missing exact alarm outranks a refused call permission` | `y11-limited-protection.log` PA-4 KILLED (test adıyla) | API 36 `9c6db0b`: ikisi reddi → Y-11 diyaloğu, ACTION_DIAL 0, Telecom 0 (`y11_precedence_both_denied_post_9c6db0b.png`) | — | `53f7981` |
| Y-11c | MEDIUM | FIXED | yalnız CALL_PHONE reddi → native oturumsuz geri sayım korumalıyla aynı başlıkta (inceleme) | başlık sabitti | `foregroundDialCountdown` → "Sınırlı koruma — uygulama kapanırsa arama yapılmaz"; başlık geri sayım başlarken yenilenir | `panic_arm_policy_test` (3 neden), `countdown_exact_alarm_required_test` kontrol | PA-1..3 KILLED | API 36 `9c6db0b`: başlık birebir, native `none`, PIN → ana sayfa (`y11_limited_title_post_9c6db0b.png`) | `uncertainNativeCountdown` (ArmUnknown) uyarısız: native kurulmuş olabilir, "arama yapılmaz" yanlış olurdu | `53f7981` |
| Y-14 | HIGH | FIXED | API 36: silahlı Check-In, Ayarlar'dan exact alarm kapat → tam alarmlar silindi, yalnız 10–12 dk pencereli yedekler; ekran tam korumalı | native okuma izin durumunu taşımıyordu | `SessionReadWire` canlı `exactAlarmPermitted`; Dart degrade uyarısı + dokununca izin sayfası; sorgu hatası = izin yok | `check_in_service_behavior_matrix_test`, `emergency_snapshot_parser_test`, `background_protection_tap_test`, `SessionReadWireTest` | Y14-1..5 KILLED | API 36 `c2b80f028e3e`: uyarı birebir; yeniden izin → `window=0 flags=0x5` tam alarmlar geri | geri alma anından açılışa kadar kullanıcı uyarıyı görmez (süreç ölür) | `0636678`, `61d7baa` |
| Y-02 | HIGH | FIXED | Telecom kabulünden 5 sn sonra "Yardım çağrısı henüz gitmedi / Arama bağlanmadı … manuel arayın" (çağrı aynı telefonda çalarken) | kabul edilmiş istek başarısızlık sayılıyordu | REQUEST_SUBMITTED_UNCONFIRMED anlatımı; gerçek başarısızlık ayrı + manuel arama | `emergency_call_screen_behavior_test` Y-02 | Y02-1, Y02-2 KILLED | API 36 `f49c9746f120` A ve B birebir; C NOT PROVEN (emülatör); D SOURCE ONLY | "cevaplandı" asla söylenmiyor | `3a8ea49` |
| Y-02b | MEDIUM | FIXED | Telecom kabul + çağrı sonra başarısız (sinyal yok) → ekranda arayıcıya hiçbir yol yok (inceleme MEDIUM-7) | manuel arama kaldırılınca alternatif kalmadı | sessiz "Telefon uygulamasını aç" (ACTION_DIAL, numara dolu, kendisi aramaz) | aynı dosya: bağlantı, ≥48 dp, semantik, yalnız istek gönderildi durumunda | DL-1..3 KILLED | API 36 `ebe5acd`: dokun → `com.android.dialer` 05551234567; Telecom yalnız `TC@1` (ikinci arama yok) | `openDialer` Android kanalında `MissingPluginException` yakalanmıyor (LOW, önceden var olan desen) | `40429e7` |
| UI-01 | LOW | FIXED | API 36 411x914 dp: bağlantı kaydırma alanının sonunda, yazısı ortadan kesik (gerçek cihazda bulundu) | içerik görünüm alanını aştı | bağlantı sabit alt bölüme (22 dp boşluğun yerine) | 411x914 dp yüzeyde bağlantı + bant durgun halde tam görünür | DL-4 (eski yerleşim) KILLED | `y02_link_post_ebe5acd.png` kesiksiz, kart tam | test fontu Roboto'dan geniş: uzun kart metni yalnız cihazda doğrulandı | `ebe5acd` |
| LK-01 | HIGH | FIXED | yeniden başlatma + saat ileri aktif kilidi bitiriyordu | yeni açılışta duvar deadline'ı karar veriyordu | yeni açılışta kilit tam süreyle yeniden başlar, o açılışa bağlanır | `pin_lockout_monotonic_test` | LK-B1 KILLED | API 36 matris 15/15 (`lockout-matrix-api36-ebe5acd.txt`, betikli) | — | `576d33e` |
| LK-02 | MEDIUM | FIXED | (inceleme) monoton okuma başarısız + saat ileri → kilit biter VE kalıcı silinir | doğrulanmamış bitiş de anahtarları siliyordu | yalnız monoton kanıtlı bitiş unutturur; başarısız okumada kilit sürer | aynı dosya | LK-R1..R3 KILLED | emülatörde tetiklenemez → yalnız regresyon matrisi | sürekli okuma hatası: 30 sn tutma sonra duvar (anahtarlar kalır) | `d60e766` |
| LK-03 | LOW | FIXED | deneme sayacı yazımı kesilirse ilk kilit yeniden başlatmada 0 sn | süre son yazılan sayaçtan türetiliyordu | `pin_lockout_duration_ms` deadline ile | aynı | LK-R4, LK-R6 KILLED | — | — | `d60e766` |
| LK-04 | LOW | FIXED | "bitti" diyen eşzamanlı okuma yeni kilidin anahtarlarını silebiliyordu | serileştirme yoktu | readState/registerFailure/reset sıraya alındı | 30 kademeli okuyucu testi | LK-R5, LK-R7 KILLED | — | — | `d60e766` |
| LK-05 | MEDIUM | FIXED | monoton okumasız kaydedilen kilit kalıcı duvar-only (inceleme MEDIUM-2) | işaret yoktu | bekleyen kilit ilk başarılı okumada tam süreyle bağlanır | aynı | LK-M2a..c KILLED | — | OD-3: bekleyen kilit ≤2 kat uzayabilir | `0bef751` |
| LK-06 | HIGH | FIXED | (inceleme 2) 1 sn tutma tam saniyeye 0 → kilit ekranı tuş takımını açıyordu | `remainingSeconds` kesirli saniyeyi atar | en az 2 sn görünür; süreç saatiyle en çok 30 sn | aynı | LK-H1..H4, LK-E1 KILLED | — | — | `43e6238` |
| LK-07 | MEDIUM | FIXED | (inceleme 2) hiç dönmeyen keystore çağrısı sonraki tüm PIN kontrollerini (geri sayım PIN'i dahil) durduruyordu | sınırsız kilit | 5 sn sonra kilitsiz; takılı tutucu dönene kadar bekleme yok | aynı | LK-W1..W3 KILLED | — | — | `43e6238` |
| LK-08 | LOW | FIXED | bekleyen kilit yazımı wall'dan önce kesilirse kilit sayılmıyordu; kesilen sıfırlama doğru PIN sonrası yeniden kilitleyebilirdi | yalnız elapsed anahtarı kontrol; silme sırası | yalnız uzunluk = kesik kilit; silmelerde uzunluk önce | aynı | LK-C1, LK-D1, LK-D2 KILLED | — | — | `43e6238` |
| A-03 | MEDIUM | FIXED | API 36: bildirimler kapalıyken son uyarı gösterilemedi, zaman çizelgesinde iz yok | sonuç taşınmıyordu | `graceWarningOutcome` → zaman çizelgesi nedeni; son tarih/hedef değişmedi | `native_history_warning_reason_test` + Kotlin karakterizasyon | A03-1..3 KILLED | API 36 `3458d6659437`: neden birebir, tek Telecom, son tarih kaymadı | — | `4b6bc3d` |
| A-03b | LOW | FIXED | Güvenli Yürüyüş tanıtımı akışı "uygulama açıkken"e bağlıyordu | eski metin | 60 sn ek süre + en-iyi-çaba uyarı + akış | `safe_walk_desc_copy_test` (koddaki sabite bağlı) | SW-1, SW-2 KILLED | API 36 `9c6db0b` birebir (`sw_desc_post_9c6db0b.png`) | — | `1231480` |
| Y-09 | MEDIUM | FIXED (uygulama içi) / LEGAL REVIEW REQUIRED (rıza metni) | metinler olmayan "konum oturumu"nu anlatıyordu; Yardım SSS'i ilk düzeltmeden kaçmıştı | eski özellik metinleri | izin/gizlilik/SSS metinleri kaynağa göre; karo önbelleği açıklandı | `test/screens/y09_location_session_copy_test.dart` (gösterilen her anahtar) | Y09-1..3 KILLED | ağ yakalama: tek uygulama hostu `tile.openstreetmap.org` (`y09-network-capture.md`) | rıza ekranı `legal_consent_location(_sub)` hâlâ "acil durum veya konum oturumu" diyor → **LEGAL REVIEW REQUIRED** | `0353522`, `14a31e2`, `45ebf8b` |
| T-01 | LOW | FIXED | sarmalayıcı kaynak testi 1200 karakter uzaklık; "Şimdi Ara" dokunulmuyordu (testleri test et) | zayıf test | parantez aralığı; dokunup `tel:` | — | M5-a KILLED; aynı mutant ESKİ testte SURVIVED (zayıflığın kanıtı); M5-b KILLED | — | `_closeOf` sınırları belgeli | `8800ec1` |
| FS-01 | CRITICAL (politika: aramayı engelleyebilir) | FIXED | RC 3691017 cihaz koşusu, API 29: silahlı Check-In → `am force-stop` → bekleyen alarm 4 → 0; uygulamayı yeniden aç → 0 kaldı, native `armed`; uygulama tekrar kapanırsa süre dolunca hiçbir şey tetiklenmeyecekti (`rc-gate-3691017-superseded/`) | force-stop paketin alarmlarını siler; Android 15+ yeniden başlamada BOOT_COMPLETED'i tekrar teslim eder (API 36'da 4→0→4 gözlendi), API 29–34 etmez; uygulama başlangıcında uzlaştırma yoktu | `MainActivity.onCreate` süreç başına bir kez `reconcileCurrentBoot()` (alıcı koruması ardında; başarısızsa sonraki başlangıçta yeniden) | `ProcessStartReconcileTest`, `EmergencySessionCoordinatorTest` (düşen alarmlar yeniden; çift uzlaştırma tek arama), `test/android/main_activity_process_start_reconcile_contract_test.dart` | PS-1..6 KILLED (`mutants/force-stop-reconcile.log`) | API 29 düzeltilmiş derleme: 4 → force-stop 0 → aç 4; RC'de P9 (API 29 + 36) | uygulama force-stop sonrası HİÇ açılmazsa Android 10–14 hiçbir şey çalıştıramaz (platform); aynı-açılış uzlaştırması "vadesi geldi"yi duvar saatiyle verir (security LOW, OD-1 ile birlikte) | `39ccb2f`, `cdc4024` |
| Y-09b | MEDIUM | FIXED | Ayarlar > Yardım SSS'i "Konum oturumu pil tüketiyor mu? / Konum yalnızca siz oturumu başlattığınızda kullanılır" diyordu (ilk Y-09 düzeltmesinden kaçmış) | eski metin | SSS maddesi kaynağa göre (TR/EN) | `y09_location_session_copy_test.dart` | Y09-1..3 KILLED | RC'de P2 | — | `45ebf8b` |
| ENV-01 | — (ortam) | NOT A CODE DEFECT | RC kaos 1. deneme (API 35): "KoruBeni isn't responding"; eski sürücü görmeden 60+ dizi diyalog üstünde koştu | `/data/anr`: ana iş parçacığı `NmeaClient.stop → removeNmeaListener → unregisterGnssNmeaCallback`; system_server NMEA kilidini tutarken emülatör GNSS HAL `stopNmea` içinde bloke, HAL'ın `reportNmea` geri çağrısı aynı kilidi bekliyor → system_server/HAL kilitlenmesi | uygulamada değişiklik yok: GMS'li (Play) cihazda geolocator Fused sağlayıcıyı kullanır, NMEA dinleyicisi kaydedilmez; acil akış konum kullanmaz. Sürücü ANR'yi algılayıp sınıflandırıyor (`env-gnss-hal-deadlock`/`app`) | — | — | `rc-gate-3691017-superseded/attempt1-anr-gnss-deadlock-evidence.txt` | GMS'siz cihaz + kilitlenen GNSS HAL: haritadan çıkış UI'yi dondurabilir (LOW, platform) | — |
| T-02 | INFO (araç) | FIXED | release smoke widget adımı FAIL: betik `<smoke paketi>.extra.PANIC_SOURCE` gönderiyordu; trampolin sabit anahtarı bekler ve doğru biçimde reddetti (fail-closed) | test betiği | sabit anahtar | — | — | doğru anahtarla release widget paniği PASS | — | araç |
| EV-01 | INFO | FIXED | önceki commit'lerin atıf yaptığı `mutants/*.log` depoya girmemişti | `.gitignore` `*.log` | `git add -f` | — | — | — | — | `45ebf8b` |

## 3. OWNER DECISION REQUIRED / LEGAL REVIEW REQUIRED (kod değiştirilmedi)

| ID | Konu | Neden kodla çözülmedi | Kanıt |
|---|---|---|---|
| OD-1 | **5 dk vade politikası iki yolda tutarsız** (kotlin-reviewer MEDIUM): exact alarm yeniden verildiğinde `reconcileArmedFromWall` vadesi 5 dk'yı aşmış oturumu MANUAL_ACTION_REQUIRED'a alıyor; alarm alıcısı → `claimAndDispatch` yolunda vade kapısı yok, geç de olsa otomatik arıyor | A-03 owner kararı "5 dakikalık overdue politikasını değiştirme" diyor; hangi yolun doğru olduğu bir güvenlik-semantiği kararı | `EmergencySessionCoordinator.kt` (reconcile vs claimAndDispatch); inceleme raporu |
| OD-2 | **API 34+ temiz kurulumda ilk panik exact alarm izni verilene kadar reddediliyor**; onboarding bu izni istemiyor (security MEDIUM-6) | Y-11 kararı paniği izinsiz başlatmayı yasaklıyor; onboarding'e adım eklemek ürün/UI kararı (CLAUDE.md kural 4) | ana kart "Kuruluma 2 adım kaldı"; red diyaloğu "Şimdi Ara" ile anında manuel arama sunuyor |
| OD-1b | Aynı-açılış uzlaştırması (yeniden başlatma, paket değişimi, kilit açma ve artık uygulama başlangıcı) vadesi geldi kararını duvar saatiyle veriyor; uygulama durdurulmuşken saat değiştiyse (TIME_SET kaçırıldı) erken arama veya teklif olabilir (security-reviewer LOW) | 5 dk vade politikası A-03 owner kararıyla korumalı; monoton karar politikanın bir parçası | `EmergencySessionCoordinator.kt` `reconcileArmedFromWall` |
| OD-3 | Monoton okuma olmadan kaydedilen (bekleyen) kilit ilk başarılı okumada TAM süreyle bağlanıyor → en kötü ≈2× (15 dk → 30 dk) | fail-closed (onaylı yeniden başlatma kuralıyla tutarlı); kısaltmak saat ileri ile kilidi kısaltmayı açar | `pin_lockout_service.dart` `_remaining`; LK-M2c |
| LR-1 | **Rıza ekranındaki konum maddesi** (`legal_consent_location`, `legal_consent_location_sub`): "acil durum ve konum oturumlarında işlenir … aktif oturum süresince" diyor; kaynakta konum oturumu yok ve acil akışlar konum kullanmıyor | hukuki rıza metni: değişiklik hukuki inceleme + `scripts/bump_legal.sh` + yeniden rıza ister | `test/screens/y09_location_session_copy_test.dart` açık LEGAL REVIEW REQUIRED listesi |
| LR-2 | `legal_texts.dart` ve `store/*.html` KVKK/gizlilik metinleri bu denetimde değiştirilmedi | aynı | — |

## 4. Kalan riskler (bilinen, düzeltilmedi veya kanıtlanamadı)

| Risk | Önem | Durum |
|---|---|---|
| Monoton okuma sürekli başarısızsa (köprü var) kilit 30 sn tutulur, sonra duvar karar verir (anahtarlar kalır) | LOW | bilinçli sınır: sonsuz kilit tüm uygulamayı (panik dahil) kapatırdı |
| v1.0.2'den kalan TEK aktif kilit yalnız duvar anahtarlı → yükseltmeden hemen sonra yeniden başlatma + saat ileri onu bitirebilir | LOW | tek seferlik; yeni kilitler monoton |
| `AndroidIntentService.openDialer` Android kanalında `MissingPluginException` yakalamıyor | LOW | önceden var olan desen; köprü yokken yalnız |
| `uncertainNativeCountdown` (ArmUnknown) "Sınırlı koruma" başlığı taşımıyor | LOW | native oturum kurulmuş olabilir; uyarı yanlış olabilirdi |
| "3 adımda hazır olun" kartı acil kişi varken de 1. adımı gösteriyor (kapatılabilir statik kart) | INFO | UI kapsamı dışında |
| Y-02 C (telefon yeteneği yok) | — | NOT PROVEN — EMULATOR LIMITATION (birim testleri var) |
| Y-02 D (gönderim belirsiz/zaman aşımı) | — | SOURCE PROVEN / NOT RUNTIME PROVEN |
| Yayın imzalı v1.0.2 → RC yükseltmesi | — | EXTERNAL SYSTEM REQUIRED (Play release kapısı gerçek `goog_` RevenueCat anahtarı istiyor; debug→debug yükseltme kanıtlandı) |
| Doze/OEM pil yöneticisi altında gerçek cihaz davranışı, gerçek SIM ile arama bağlantısı | — | PHYSICAL DEVICE REQUIRED |
| Abonelik satın alma / yenileme / iade | — | EXTERNAL SYSTEM REQUIRED |

<!-- AFTER-SECTION-4 -->

