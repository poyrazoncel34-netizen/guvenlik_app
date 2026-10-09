# KoruBeni — İnsan Benzeri Kaos Denetimi, Düzeltme ve Yeniden Test (2026-10-08 / 09)

Girdi: `docs/audit/real-user-adversarial-audit-2026-10-08.md` ve kanıtları — **geçmiş kanıt ve bilinen kusur listesi olarak
okundu, sonuçları doğru kabul edilmedi**; depo kaynak olarak yeniden doğrulandı. Başlangıç HEAD `3a1f992`
(analyze temiz, `flutter test` 2182/2182). Son HEAD `3625d2a` (dal `codex/evidence-remediation-20260911`, **push edilmedi**).
Ham gözlemler, ekran görüntüleri, araçlar ve koşum çıktıları: [`evidence/chaos-2026-10-08/`](evidence/chaos-2026-10-08/)
(`ledger-working.md` tüm satırların kaynağıdır). Plan ve sahip onayı: [`fix-plan.md`](evidence/chaos-2026-10-08/fix-plan.md)
(A+B+C+D + API 29/36 imajları onaylandı; E bölümü inceleme ajanı bulgularıdır).

## 1. Ortam ve kanıt standardı

| Ortam | Ayrıntı |
|---|---|
| API 35 | AVD `KoruBeni_A017_API35`, userdebug, GMS yok, 420 dpi, 1080x2400 |
| API 29 | AVD `KoruBeni_API29` (`system-images;android-29;default;arm64-v8a`), userdebug, 1080x2274 |
| API 36 | AVD `KoruBeni_API36` (`sdk_phone64_arm64`), userdebug, 1080x2400 |
| Debug build'ler | her koşu satırında HEAD / APK sha1 / `lastUpdateTime` (`dumpsys package`) — defterde |
| Release | `flutter build apk --release --flavor smoke` (R8 + AOT, DEBUGGABLE yok), HEAD `943bea9`, sha1 `6873e282cdf9…` |
| Pro | `tools/inject_pro.sh` (debug) / `tools/inject_pro_root.sh` (release, root) — **yalnız test; ticaret kanıtı değil** |
| Fiziksel cihaz / Play Billing | yok → **PHYSICAL DEVICE REQUIRED** / **COMMERCE REQUIRED** |

Her düzeltme: yeniden üretim → kanıt → regresyon testi (önce kırmızı) → düzeltme → **mutasyon** (düzeltmeyi bozunca test
kırmızı, kaynak hash'i geri doğrulandı) → cihazda yeniden çalışma → tam paket. İnceleme: flutter-reviewer, kotlin-reviewer,
security-reviewer (salt-okur) — CRITICAL 0, HIGH 0; bulguları §4'te.

## 2. Önceki rapor maddelerinin yeniden doğrulaması

| Madde | Önceki durum | Bu denetimdeki doğrulama | Sonuç |
|---|---|---|---|
| N-03 / A-06 (bağlantı geri sayımı kapatıyordu) | düzeltildi | cihaz P3: panik + `korubeni://open/timeline` → bağlantı ertelendi, iptalden sonra açıldı | PASS |
| A-12 (siren sesi süreç ölümünde) | düzeltildi | cihaz S2: 3 → 7 → ölüm → açılışta 3 | PASS |
| A-04 (kuruluma yanlış alt başlık) | düzeltildi | cihaz J1/J29/J36 | PASS |
| A-10 (silme çift dokunuş) | INFO | cihaz R1/R2: bariyer çift eylemi yutuyor; silme öldürmeden önce tamam | PASS |
| N-01, N-02, N-04, N-05, A-05, A-09, T-01, T-02 | düzeltildi | regresyon testleri her commit'te yeşil (§7); cihazda ayrıca koşulmadı | PASS (test) |
| **A-02 / A-02r** (yeni açılışta TIME_SET) | kalan risk LOW | **açık bulundu** → `3ce7e72` + inceleme `9eeb73d`; cihaz: yeniden başlatma + saat +1 sa (§5) | DÜZELTİLDİ |
| **A-07** (paywall kilidin üstünde) | kalan risk LOW | yeniden üretildi → `120f99d` | DÜZELTİLDİ |
| **A-08** (park edilen bağlantı) | kalan risk LOW | yeniden üretildi + görünür varyant (yönlendirici itilen ekranı bekliyordu) → `7cc6587`; cihaz V-A08 | DÜZELTİLDİ |
| **A-11** (süreç ölümünde geri sayım kayıp) | açık | cihazda yeniden üretildi → `fd9b5fb` + soğuk açılış `c631736` + yarış `b24ee18` | DÜZELTİLDİ |
| A-03 | sahip kararı | değişmedi | **SAFETY SEMANTIC DECISION REQUIRED** |

## 3. Kusur defteri (bu denetimde bulunanlar + yeniden açılanlar)

Sütunlar: Kullanıcı görür mü · yeniden üretim · kök neden · düzeltme commit'i · regresyon testi (mutasyonla kırmızı) ·
çalışma-zamanı doğrulaması · kalan risk. Tüm satırların ham kanıtı defterdedir.

| ID | Önem | Görür | Yeniden üretim (kanıt) | Kök neden | Düzeltme | Regresyon | Çalışma-zamanı | Kalan risk |
|---|---|---|---|---|---|---|---|---|
| **Y-04** | HIGH | Evet | panik + T+1 `date` +3600 → anında ACTION_DIAL, PIN tuşları gitti, 8 sn sonra native otomatik arama (API 35) | Dart geri sayımı duvar saatine bölünüyordu | `8980a5d` (MonotonicDeadline) | `countdown_wall_clock_jump_test`, `monotonic_deadline_test` | API 35/29/36: sıçrama sonrası "5/8 saniye", tek Telecom isteği gerçek son tarihte | geri alınan saat + TIME_SET son tarihten de geç gelirse çevirici yolu (LOW) |
| **Y-01** | HIGH | Evet | Check-In +1 sa → sahte "Süre doldu! EK SÜRE"; −2 sa → "134:19" (native 593 sn) | Dart sayaçları duvar saati; `safetyClockChanged` dinleyicisi ölüydü | `274e4b3` | `check_in_wall_clock_change_test`, `ClockChangeEventTest`, 285 tohumlu saat fuzz'ı (mutantta 84/285 ihlal) | API 35: ekran = native kalan | yeniden yükleme sırasında düşen olay (LOW, §4) |
| **Y-12** | HIGH (dal gerilemesi, yayımlanmadı) | Evet (fiziksel cihazda) | inceleme: `Stopwatch` = CLOCK_MONOTONIC, uykuda durur; native CLOCK_BOOTTIME. Emülatör uykuyu taklit etmiyor (zorla s2idle'da ikisi birlikte 88 sn kaybetti) | Y-04/Y-01 düzeltmesinde yanlış monotonik saat | `e5e786b` (libc `clock_gettime(CLOCK_BOOTTIME)`, dart:ffi) | `sleep_counting_monotonic_test` (4 mutant), `boot_clock_test` | prob: API 36 JIT, API 29 JIT, **API 29 AOT release** → `SafetyClock.system` = BOOTTIME | uyku davranışı **PHYSICAL DEVICE REQUIRED** |
| **Y-13** | HIGH | Evet | silahlı panik → süreç ölümü → widget/kutucuk/ses tuşu ile soğuk açılış: "Hiçbir işlem tamamlanmadı — Güvenlik oturumu kurulmadı", PIN tuşları erişilemez, native yine aradı (düzeltme öncesi derleme `2d39f39`, API 36, `a11r_race_prefix_after_pin.png`) | taze geri sayımın arm'ı `activeSessionExists` ile reddedilince hata diyaloğu; yeniden gösterme yuvayı geç alıyordu | `b24ee18` (reddedilen geri sayım yetim oturumu benimser; bekleme monotonik) | `countdown_reattach_test` (+1), `emergency_trigger_reattach_test` (+1) | API 36 W1: aynı betikte "5 saniye", "A***", PIN → `cancelled` | — |
| **A-11** | HIGH | Evet | panik → `kill -9` → aç: iptal yüzeyi yok, son tarihte arama (API 35) | yeniden gösterme yoktu; soğuk açılışta kök Navigator yokken düşüyordu | `fd9b5fb`, `c631736` | `panic_reattachment_test`, `countdown_reattach_test`, `emergency_trigger_reattach_test` | API 35/29/36 + **release (API 29)**: maskeli yeniden bağlanan geri sayım, PIN → `cancelled` | debug soğuk açılış yüklü makinede 10 sn'nin ~4,7'sini yiyor (INFO) |
| **Y-05** | MEDIUM (güvenlik) | Evet | kilit 86 sn → +1 sa → kilit kalktı; −2 sa → 7431 sn | kilit duvar saatiyle | `005de75`, ekran `25fe9d9`, boot_id + yazma sırası `0c3a94a` | `pin_lockout_monotonic_test` (+3), `unlock_lockout_wall_clock_test`, `read_monotonic_clock_test` (`3625d2a`) | API 35 V-Y05a/c, API 36 Y05r: +1 sa sonra "Kilitli: 15s" | **yeniden başlatma + saat ileri bir kilidi atlar → SECURITY DECISION REQUIRED**; PIN okuma hatasında duvar (sınırlı) LOW |
| **Y-10** | MEDIUM (güvenlik) | Evet | HOME → 135 sn → saat −1 sa → aç: PIN istenmedi (API 29, aynı süreç) | arka plan süresi yalnız duvar saati | `e1192a3`, okuma hatasında fail-closed `2d39f39` | `app_lifecycle_lock_test` (Y-10 grubu 6) | API 29 Y-10b, API 36 Y10r | — |
| **Y-06** | MEDIUM (güvenlik) | Evet | 5 yanlış prova PIN'i → kilit; prova doğru PIN'i yine kabul etti (oracle) | prova tuş takımı kilidi sormuyordu | `1147941` | `countdown_rehearsal_lockout_test` | API 35 V-Y06 | prova saniyede bir kayıp sayar (LOW) |
| **Y-08** | MEDIUM | Evet | izinsiz/çevirici panik zaman çizelgesine yazılmıyor | yalnız native günlük uzlaştırması | `ec29702` | `emergency_bookkeeping_timeline_test`, `countdown_no_native_journal_test` | API 35/36: ACTION_DIAL → satır <0,1 sn | `ArmUnknown`'da çift satır olabilir (eksikten iyi, LOW) |
| **Y-03** | MEDIUM | Evet | Pro çevrimdışı çapası varken soğuk açılışta SOS "Kilitli" | çapa ağ başlatmasından sonra yükleniyordu | `2b175a7` | `subscription_startup_anchor_test` | API 35 V-Y03 | — |
| **Y-07** | LOW-MED | Evet | arm bitmeden doğru PIN → 10 sn sonra "arama başarısız"; ya da iptal edilmiş oturumu arm etme | arm/iptal sıralaması | `53309f8` + test `943bea9` | `countdown_pin_before_arm_test` (4 vaka, `ArmUnknown` dahil) | birim (deterministik) | — |
| **A-02r** | MEDIUM | Hayır (geç/erken arama) | JVM: BOOT_COUNT okunamazsa/geç artarsa yeni açılış ayırt edilemiyor; geç artan sayaçta aynı açılışta +1 sa → `MANUAL_ACTION_REQUIRED` | tek kimlik BOOT_COUNT | `3ce7e72`, `9eeb73d` | coordinator testleri + 400 vakalık özellik testi (tutarsız kimlikler dahil), `BootIdentityTest`, enstrümantasyon | boot_id API 29/35/36 uygulama sürecinden okunuyor; API 36 yeniden başlatma + saat +1 sa: kalan korundu, ekran 13:19 = native | A-02↔A-02r arası yayımlanmamış derleme kaydı bir açılış id'siz (LOW) |
| **A-08** | LOW | Evet | ikinci bağlantı sonraki devama kadar parkta / yönlendirici itilen ekranı bekliyordu | `await push` | `7cc6587` | `deep_link_resume_lock_test` (+2) | API 35 V-A08 | — |
| **A-07** | LOW | Evet | paywall devam kilidinin üstünde | kapı kilidi beklemiyordu | `120f99d` | `deep_link_resume_lock_test` (+2) | birim | — |
| T-03 | test | Hayır | `ScheduledNotificationManifestInstrumentationTest` API 29'da `NoSuchMethodError` | API 33 sınıfı | `c40d749` | enstrümantasyon | API 29/35/36: 19/19 | — |
| T-04 | süreç | Hayır | `cb857b8` değişken adı değişikliği `safety_session_callsite_contract_test`'i kırdı; commit öncesi tam paket koşulmamıştı | — | geçmişte `e1192a3`'e katlandı (dal push edilmemişti; yedek `backup/chaos-pre-fixup-20261009`) | aynı test | commit-başı doğrulama | — |

## 4. Sahip / güvenlik / ürün kararı gerekenler (kod değiştirilmedi)

| ID | Konu | Kanıt | Neden karar |
|---|---|---|---|
| **Y-02** | Telecom isteği kabul ettikten 5 sn sonra her seferinde "Yardım çağrısı henüz gitmedi / Arama bağlanmadı … manuel arayın" + "yeşil arama tuşuna basmanız gerekir" | arama aktifken yanlış (API 35), uçak modunda doğru (P5) | uygulama bağlantıyı bilemiyor; "kabul edilmiş istek sonrası elle tekrar arama istemek" = mükerrer-arama ↔ arama-yok dengesi → **SAFETY SEMANTIC DECISION REQUIRED** |
| **Y-11** | Android 14+ temiz kurulumda SCHEDULE_EXACT_ALARM varsayılan reddedilmiş; "Arka Plan Hazırlığı" atlanırsa her panik yalnız ön plan çevirici geri sayımı; ekran korunan oturumla aynı görünüyor, süreç ölürse ne arama ne çevirici | API 36: native yuva boş, `exactAlarmDenied`, son tarihte ACTION_DIAL (`a11_36_after_panic.png`, `a11_36_after_deadline.png`) | belgelenmiş tasarım (launch-readiness 2026-10-05 satır 6); farkı göstermek metin/UI, alarm olmadan native oturum açmak güvenlik anlamı → **SAFETY/PRODUCT DECISION REQUIRED** |
| A-03 | önceki rapordaki gibi | değişmedi | **SAFETY SEMANTIC DECISION REQUIRED** |
| Kilit ↔ sonuç ekranı sırası; gerçek panik tuş takımının kilit sırasında doğrulaması | önceki rapordaki gibi (öneri: koru) | — | sahip |
| Yeniden başlatma + saat ileri | bir PIN kilidi atlanır (saldırgan maliyeti ~1–2 dk yeniden başlatma / kilit) | security-reviewer M1 | kapatmak, kilitliyken telefonu yeniden başlatan sahibi de yeniden kilitler → **SECURITY DECISION REQUIRED** |
| **Y-09** | izin açıklaması/gizlilik detayında var olmayan "konum oturumu" özelliği | M1, rıza metni | Play belirgin açıklama doğruluğu → sahip/hukuk (`scripts/bump_legal.sh`) |

LOW / INFO (belgelendi, kod yok): Check-In `safetyClockChanged` süren bir geri yüklemede düşebilir (native yetkili, sonraki
devamda düzelir) · bozuk monotonik kilit anahtarı duvara düşer · yeniden bağlanan geri sayım birincil kişi arada değiştiyse
maskeli adı yanlış gösterebilir · yanlış PIN kaydı kilit yazarken ek native okuma · `debugPrint` taşındı (release'de
`main.dart:38` susturuyor) · Safe Walk başlangıcında "Check-in Zamanlayıcı" başlığı · "degraded modda" İngilizce sözcük ·
eski "Arama akışı başlatılıyor" bildirimleri · yanlış PIN SnackBar kuyruğu kilit mesajını geciktiriyor · kopya kişi için önce
rıza soruluyor · rıza metni "yerel veritabanı" diyor, kişiler güvenli depoda · zaman çizelgesi zaman damgaları duvar saati ·
emülatör Impeller "EGL Error: Success" günlük gürültüsü · `CountdownClock` üretimde kullanılmıyor.

## 5. Cihaz / API matrisi (özet; satırlar defterde)

| Senaryo | API 35 | API 29 | API 36 | Release (API 29) |
|---|---|---|---|---|
| Temiz kurulum yolculuğu (kaos: erken Devam, döndürme, süreç ölümü) | PASS | PASS | PASS (bildirim reddi) | PASS |
| Panik → PIN iptali | PASS | PASS | PASS | PASS |
| Y-04 saat sıçraması | PASS | PASS | PASS | — |
| A-11 süreç ölümü → yeniden bağlanma → iptal | PASS | PASS (görünürlük) | PASS | PASS |
| Y-13 yarış (widget soğuk açılış) | — | — | PASS (öncesinde FAIL yeniden üretildi) | — |
| Y-05 kilit + saat | PASS | — | PASS | — |
| Y-10 devam kilidi + saat geri | — | PASS | PASS | — |
| Y-08 zaman çizelgesi | PASS | — | PASS | PASS (satırlar) |
| A-02r yeniden başlatma + saat | — | — | PASS | — |
| Y-12 FFI bağlaması (prob) | — | PASS (JIT + AOT) | PASS | PASS (AOT) |
| `am instrument` (19 test, boot_id dahil) | 19/19 | 19/19 | 19/19 | — |
| Logcat / yerel hata günlüğü (FATAL/ANR/PlatformException/MissingPluginException/flutter_framework_unhandled) | 0 | 0 | 0 | 0 (`crash_logs` 0 satır) |
| Fiziksel: Telecom/SIM, Doze, OEM öldürme, gerçek uyku (Y-12), çift SIM, GMS'siz cihaz | **PHYSICAL DEVICE REQUIRED** |||||
| Play Billing satın alma/geri yükleme/iptal | **COMMERCE REQUIRED** |||||

## 6. Fuzz ve mutasyon

| Koşu | Sonuç |
|---|---|
| Gezinme fuzz'ı `FUZZ_SCALE=13` (156×10, 130×40, 52×120 eylem), başlangıç `3a1f992` | 338/338 (`fuzz-scale13-baseline.txt`) |
| Tohumlu durumlu saat fuzz'ı (285 dizi: kısa/orta/uzun; saat ±, geç TIME_SET, süreç ölümü) | düzeltmeyle 285/285; mutantta 84/285 ihlal (`clock-fuzz-*.txt`) |
| Son HEAD fuzz'ları | §7 |
| Mutasyon | her düzeltme için en az bir mutant; hepsi kırmızı, kaynak hash'i geri doğrulandı (defter) |

## 7. Doğrulama zinciri

| Kapı | Sonuç | Kanıt |
|---|---|---|
| Commit-başı (temiz detached worktree, her commit'te `rm -rf build/test_cache` → analyze → tam paket → Android değiştiyse Kotlin unit) | **23/23 yeşil** (`3a1f992..943bea9`; 2182 → 2534 test) | [`per-commit-validation.txt`](evidence/chaos-2026-10-08/per-commit-validation.txt) |
| Son test commit'i `3625d2a` (`readMonotonicClock` ayrıştırma testi) | aşağıdaki zincirin tam paketinde | — |
| `scripts/verify_release.sh` @ `3625d2a` (`flutter clean` dahil) | **EXIT=0** — analyze temiz; **2538/2538**; kritik kapsam PASS (emergency_platform_service %97,18, check_in_service %95,22, …); imzalı smoke AAB + birleşik release yüzeyi; lint + Kotlin unit + enstrümantasyon derlemesi; 16 KB; lisans/notices | [`verify-release-summary.txt`](evidence/chaos-2026-10-08/verify-release-summary.txt) |
| Kotlin unit (ayrıca) | 171/171 | — |
| Gezinme fuzz'ı `FUZZ_SCALE=13` @ `3625d2a` | 338/338 | [`fuzz-scale13-final.txt`](evidence/chaos-2026-10-08/fuzz-scale13-final.txt) |
| Saat fuzz'ı (285 tohumlu dizi) | tam paketin parçası, yeşil | `test/core/services/safety_clock_chaos_fuzz_test.dart` |
| `am instrument` (19 test) | API 29 / 35 / 36: 19/19 | `instrumentation-api*.txt` |
| İnceleme ajanları | CRITICAL 0, HIGH 0; MEDIUM/LOW bulguları §3–§4'te işlendi | defter "İnceleme ajanları" |

Geçmiş notu: `cb857b8` bir sözleşme testini kırıyordu (T-04); dal hiç push edilmediği için düzeltme o commit'e katlandı
(`e1192a3`), sonraki 7 commit yeniden uygulandı; son ağaç yedekten yalnız 2 satırla farklı (yedek dal
`backup/chaos-pre-fixup-20261009`).

## 8. Hükümler

| Alan | Hüküm | Gerekçe |
|---|---|---|
| CODE | **PASS** | bu denetimde bulunan tüm kod kusurları testli + mutasyonla düzeltildi; commit-başı yeşil (§7). Açık kalanlar kod kusuru değil, §4'teki karar maddeleri |
| DEVICE | **UNKNOWN** | emülatör matrisi PASS; Telecom/SIM, Doze, OEM, gerçek uyku (Y-12) fiziksel cihaz gerektiriyor |
| COMMERCE | **UNKNOWN** | Play Billing hiç denenmedi; Pro yalnız test çapasıyla |
| RELEASE | **FAIL** | commit'ler push edilmedi, CI'da koşmadı; `release.yml` önkoşulları (2 secret + 1 değişken + imzalı tag) eksik; Play Console adımları yapılmadı; §4 kararları bekliyor |
| **PRODUCT** | **NO-GO** | gerçek cihaz + Play Billing doğrulaması olmadan GO verilemez; Y-02 ve Y-11 kullanıcıyı yanıltabilir |

**Gerçek bir insan bu uygulamayı kullanırken karşılaşabileceği, bugün bildiğimiz herhangi bir kod problemi kaldı mı?**
**EVET.** Güvenlik anlamını değiştirmeden düzeltebileceğim bilinen kod kusuru kalmadı; ancak kullanıcının karşılaşacağı,
sahip kararı bekleyen bilinen sorunlar var: Y-02 (arama aktifken "henüz gitmedi" diyor), Y-11 (exact alarm izni yoksa
panik yalnız çeviriciye düşüyor ve bunu göstermiyor), A-03, Y-09 ve yeniden başlatma ile kilit atlatma; ayrıca §4'teki LOW
kalan riskler.

**Bugün gerçek kullanıcılara gönderiyor muyuz?** **NO-GO.**
