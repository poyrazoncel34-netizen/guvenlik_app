# KoruBeni — DEVİR RAPORU (HANDOVER)

> **Tarih:** 11 Haziran 2026 · **main HEAD:** `be37d2a` + bu commit · **Doğrulama:** Bu rapordaki her
> iddia bu oturumda kod açılarak ve test koşularak doğrulanmıştır (dosya:satır referanslı).
> **Bu raporu okuyan yeni oturum:** Önce §2'deki BAĞLAYICI KURALLARI oku. Bunlar eksik/bug
> değil, bilinçli ürün kararlarıdır — "tamamlamaya" kalkma.

## Bu oturumda koşulan gerçek sonuçlar

| Komut | Sonuç |
|---|---|
| `flutter analyze` | **No issues found** (3.1s) |
| `flutter test` | **405 test, tümü geçti** (`All tests passed!`) |
| `./gradlew :app:testPlayDebugUnitTest` | **BUILD SUCCESSFUL — 32 test, 0 hata** (CheckInExpiryEscalation 6, CheckInScheduler 2, EmergencyExecutor 8, EmergencyPrefsClear 1, FullScreenIntentNotification 2, NativeDispatchFailure 9, NativeNotificationText 4) |
| `grep -rniE "112\|911\|999" lib/ android/app/src/main/` | **Temiz** — yalnız yasal bilgilendirme stringleri ("112'yi SİZ arayın") ve "112 yok" yorumları (bkz. §2.1) |

> ⚠️ Native test her zaman `:app:` scope ile koşulmalı: kök `testDebugUnitTest`,
> üçüncü-parti `flutter_direct_caller_plugin`'in test-variant'ı yüzünden patlar (bilinen borç).
> Test çıktıları repo-kökü `build/` altına düşer (`build/app/test-results/...`).

> ℹ️ `~/.claude/settings.json` şu an `{"hooks":{}}` — Stop hook **bilerek kapalı**;
> yedek `~/.claude/settings.json.korubeni-bak` dosyasında duruyor. Değiştirilmedi.

---

## 1. UYGULAMA NEDİR

**KoruBeni** (`com.poyrazoncel.korubeni`) — Android-hedefli, offline-first kişisel güvenlik
uygulaması (Flutter). TR birincil / EN ikincil dil. Google Play Store hedefi.

**Ne DEĞİLDİR (yasal sınırlar):**
- Profesyonel güvenlik hizmeti DEĞİLDİR; 112 ve resmi acil servislerin YERİNİ TUTMAZ
  ([legal_disclaimer_screen.dart:146](../lib/screens/legal_disclaimer_screen.dart)). Kullanıcı
  onboarding'de "Gerçek acil durumda önce 112'yi arayacağımı kabul ediyorum" kutusunu işaretler
  ([legal_disclaimer_screen.dart:261](../lib/screens/legal_disclaimer_screen.dart)).
- **18+** üründür: yaş beyanı ekranı zorunlu
  ([age_verification_screen.dart](../lib/screens/legal/age_verification_screen.dart)), Play
  content rating hedef kitlesi adults/18+ ([CONTENT_RATING_ANSWERS.md](../store/CONTENT_RATING_ANSWERS.md)).

**Ücretsiz / Pro ayrımı** — tek kaynak [feature_access_matrix.dart](../lib/core/constants/feature_access_matrix.dart):

| Katman | Özellikler |
|---|---|
| FREE | harita/konum görünümü, sahte çağrı, siren, acil kişi yönetimi (ekleme + birincil seçme) |
| PRO | **panik/SOS butonu**, Safe Walk, Check-In, etkinlik zaman çizelgesi, ses-tuşu tetikleyici, test modu, gelişmiş otomasyon |

- RevenueCat entitlement kimliği: **`'KoruBeni Pro'`**
  ([revenue_cat_service.dart:22](../lib/core/services/revenue_cat_service.dart)).
- Offline Pro: RevenueCat SDK `CustomerInfo`'yu lokal cache'ler; `isPro()` cache üstünden
  çevrimdışı da çalışır ([revenue_cat_service.dart:65-68](../lib/core/services/revenue_cat_service.dart)).
- Kapı: [subscription_gate.dart](../lib/core/services/subscription_gate.dart) +
  `SubscriptionProvider` ([lib/presentation/providers/subscription_provider.dart](../lib/presentation/providers/subscription_provider.dart)).

---

## 2. BAĞLAYICI KURALLAR + GEREKÇELERİ (hepsi kodla doğrulandı)

### 2.1 — 112 HİÇBİR AKIŞTA ARANMAZ (en kritik kural)

Ürün kararıyla (commit `6beb774` "remove 112/official short-code fallback from all flows" +
`684ba5d` panik guard'ı) 112/911/999 ve tüm resmi kısa-kod fallback'leri **panik, countdown,
check-in, safe-walk VE native yedeklerden** söküldü. **Bu bir eksik değil, kuraldır — GERİ GETİRME.**

Doğrulanmış uygulama noktaları:
- **Callable hedef tanımı = yalnız 7–15 haneli kullanıcı numarası:**
  [emergency_number_validator.dart:6-20](../lib/core/utils/emergency_number_validator.dart).
- Dart arama yolu: boş/geçersiz hedef → `failed`, asla 112 sentezlenmez
  ([call_service.dart:73-77](../lib/core/services/call_service.dart)).
- Native yürütücü: boş hedef → `status=failed`; ACTION_CALL **ve** ACTION_DIAL ikisi de
  başarısızsa yine `failed`, 112'ye düşmez
  ([EmergencyExecutor.kt:55-60, 83-85](../android/app/src/main/kotlin/com/poyrazoncel/korubeni/emergency/EmergencyExecutor.kt)).
- Countdown native yedeği: persist edilmiş numara yoksa **arama yapılmaz**
  ([CountdownAlarmReceiver.kt:48-59](../android/app/src/main/kotlin/com/poyrazoncel/korubeni/emergency/CountdownAlarmReceiver.kt)).
- Check-in/safe-walk native yedeği: birincil yoksa session iptal, arama yok
  ([CheckInAlarmReceiver.kt:51-58](../android/app/src/main/kotlin/com/poyrazoncel/korubeni/emergency/CheckInAlarmReceiver.kt);
  boot-restore aynı: [CheckInScheduler.kt:209-215](../android/app/src/main/kotlin/com/poyrazoncel/korubeni/emergency/CheckInScheduler.kt)).
- `status=failed` → **tam-ekran, kapatılamaz "elle ara" fail-safe diyaloğu**
  ([countdown_screen.dart:305-315, 348-357](../lib/screens/countdown_screen.dart) `_showBlockingFailure`).
- **Kurulum guard'ları** (callable kişi yoksa akış HİÇ kurulamaz):
  panik [panic_button.dart:138-145](../lib/widgets/panic_button.dart), check-in
  [check_in_screen.dart:61-68, 99-105](../lib/screens/check_in_screen.dart), safe-walk
  [safe_walk_screen.dart:148](../lib/screens/safe_walk_screen.dart).
- **Dokunulmaz 112 stringleri** (yasal bilgilendirme, kural ihlali DEĞİL):
  [legal_texts.dart:38, 141](../lib/constants/legal_texts.dart),
  [legal_disclaimer_screen.dart:146, 261](../lib/screens/legal_disclaimer_screen.dart),
  [legal_disclaimer_banner.dart:29-37](../lib/widgets/legal_disclaimer_banner.dart). Bunlar
  "112'yi SİZ arayın" der; uygulamanın 112'yi aramasıyla ilgisi yoktur.

### 2.2 — İki acil yol KASITLI farklı (birleştirme/"tamamlama" yapma)

| | Panik / Countdown | Check-In / Safe-Walk |
|---|---|---|
| Anlam | Kullanıcının **bilerek** tetiklediği gerçek acil durum | "Yaşam belirtisi alınamadı" sinyali |
| Sayım | 10sn + 2sn native pay ([countdown_screen.dart:150-151](../lib/screens/countdown_screen.dart)) | seçilen süre + **60sn grace** ([check_in_service.dart:50](../lib/core/services/check_in_service.dart)) |
| İptal | **PIN gerekir** (PIN tanımlı değilse tek-dokunuş iptal: [countdown_screen.dart:927-930](../lib/screens/countdown_screen.dart)) | **PIN'siz tek-dokunuş "Güvendeyim"** ([check_in_screen.dart:157-159, 507](../lib/screens/check_in_screen.dart)) |
| Hedef | Birincil + **TÜM** yapılandırılmış numaralar üzerinde failover ([countdown_screen.dart:283-303](../lib/screens/countdown_screen.dart)) | **YALNIZ birincil kişi, failover YOK** ([check_in_service.dart:408-416, 445-461](../lib/core/services/check_in_service.dart)) |

Gerekçe (SPEC §0.1): kaçırılan check-in yanlış-pozitife açıktır (uyuyakalma vb.); tüm rehberi
taramak orantısızdır. "Kişi açmazsa X yap" dalı teknik olarak da kurulamaz (Android karşı-taraf
çağrı durumu vermez). Fark Android kısıtı değil, bilinçli ürün kararıdır.

### 2.3 — SADECE-PIN kimlik
Biyometrik (yüz/parmak) **KESİNLİKLE yasak** — duress/zorlama altında kilit açtırma riskine karşı
(CLAUDE.md kural 2). Kodda hiçbir biyometrik akış yok (`3520f99` ile son iskeleler de söküldü).
**Önerme bile yapma.** PIN: secure storage'da (`user_pin`), countdown iptali ve uygulama kilidi
için kullanılır; üstel lockout için bkz. §5.

### 2.4 — OFFLINE-FIRST çekirdek
Acil/check-in arama yolu geliştirici backend'ine bağlanmaz; yalnız platform/telefon servisleri.
Ağ kullanan opsiyoneller: harita karoları, RevenueCat/Play Billing, bağlantı kontrolü.
**"%100 offline ürün" iddiası da yasaktır** (CLAUDE.md kural 1). Cleartext trafik kapalı
([network_security_config.xml](../android/app/src/main/res/xml/network_security_config.xml)).

### 2.5 — Full-screen-intent BİLİNÇLİ EKLENMEDİ (SPEC Karar 7a ertelendi)
`USE_FULL_SCREEN_INTENT` **manifest'te YOK** ([AndroidManifest.xml](../android/app/src/main/AndroidManifest.xml) — doğrulandı).
Kod tarafı hazır ama zarif-düşüşlü: `showAlert(fullScreen=true)` çağrısı
`canUseFullScreenIntent()` (Android 14+ runtime kontrolü) geçerse FSI ekler, geçmezse düz
yüksek-öncelikli heads-up bildirimine düşer, **çökmez**
([EmergencyNotificationHelper.kt:116-143](../android/app/src/main/kotlin/com/poyrazoncel/korubeni/emergency/EmergencyNotificationHelper.kt)).
Manifest izni olmadığından grace uyarısı bugün fiilen **heads-up bildirimdir**. Manifest izni +
Play Console çekirdek-işlev beyanı ayrı, ertelenmiş bir adımdır — **eklemeyi önerme.**

### 2.6 — "Uygulama açıksa" metin güçlendirmesi ertelendi (SPEC Karar 8)
Native-yedek arama kodu kanıtlandığı halde stringler bilinçli temkinli ("uygulama açıksa…").
Metin güncellemesi **gerçek-cihaz kanıtı** bekliyor
([check_in_service.dart:338-340](../lib/core/services/check_in_service.dart) NOT'u). String değiştirme.

### 2.7 — UI/tema/görsel tasarım DEĞİŞMEZ + plan-onay zorunluluğu
CLAUDE.md kural 4-5: hiçbir UI/tema değişikliği yapılmaz; **her kod değişikliğinden önce plan
yazılıp kullanıcı onayı alınır.** Bu bağlayıcıdır.

### 2.8 — Yasal sürümler tek-kaynak
[legal_texts.dart:9-12](../lib/constants/legal_texts.dart): `termsVersion='3.1.0'`,
`kvkkVersion='3.1.1'`, `lastUpdated='21 Mayıs 2026'`. Public sayfalar (gh-pages:
`https://poyrazoncel34-netizen.github.io/guvenlik_app/…`, index.html dahil) buna eşitlendi
(commit'ler `816cbbf`, `1977661`). Sürüm değişirse `LegalVersionChecker` kullanıcıyı yeniden
onay akışına sokar ([splash_screen.dart:178+](../lib/screens/splash_screen.dart)).

---

## 3. TEKNİK MİMARİ

**Stack:** Flutter 3.38.9 stable, Dart SDK `^3.10.8` ([pubspec.yaml:22](../pubspec.yaml)).
State: **Provider** (`MultiProvider`, [main.dart:225](../lib/main.dart)) + DI: **get_it**
([service_locator.dart](../lib/core/di/service_locator.dart)). Sürüm: `1.0.0+1` (CI tag'i ezer, §8).

**Android SDK:** minSdk **24** (Flutter 3.38 varsayılanı; merged manifest'ten doğrulandı),
targetSdk **35**, compileSdk **36**, Java 17, yalnız 64-bit ABI (`arm64-v8a`,`x86_64` — 16KB
uyumu için bilinçli, [build.gradle.kts:90-95](../android/app/build.gradle.kts)), kaynak dilleri
yalnız `en`,`tr`. Tek flavor: **`play`** (build komutlarında `--flavor play` zorunlu).

**Klasör yapısı (özet):**
- `lib/core/services/` — 35+ servis (arama, check-in, platform köprüsü, bildirim, lockout…)
- `lib/core/security/` — `encryption_service.dart`, `secure_storage*.dart`
- `lib/core/constants/` — `app_constants`, `feature_access_matrix`
- `lib/screens/`, `lib/widgets/` — UI (DOKUNULMAZ); `lib/screens/legal/` — KVKK/onay ekranları
- `lib/services/` — `consent_manager`, `device_security_service`, `legal_version_checker`
- `lib/constants/legal_texts.dart` — yasal metinler tek-kaynak
- `android/.../korubeni/emergency/` — 13 Kotlin dosyası (native acil katman)

**MethodChannel köprüsü:**
- Ana kanal `com.poyrazoncel.korubeni/emergency_platform` + event kanalı `…/events`
  ([emergency_platform_service.dart:15-18](../lib/core/services/emergency_platform_service.dart)).
  Handler metodları ([EmergencyPlatformHandler.kt:28-94](../android/app/src/main/kotlin/com/poyrazoncel/korubeni/emergency/EmergencyPlatformHandler.kt)):
  `scheduleCheckIn`, `didCheckInAlarmFire`, `cancelCheckIn`, `consumePendingTrigger`,
  `canScheduleExactAlarms`, `requestExactAlarmPermission`, `executeEmergencyNative`,
  `getDeviceState`, `openManufacturerSettings`, `openBatterySettings`,
  `scheduleCountdownAlarm`, `cancelCountdownAlarm`, `didCountdownAlarmFire`, `clearEmergencyPrefs`.
- Yan kanallar ([MainActivity.kt:24-26](../android/app/src/main/kotlin/com/poyrazoncel/korubeni/MainActivity.kt)):
  `…/android_intents`, `…/settings`, `…/audio_control`, ses-tuşu Event+MethodChannel.
- Dart tarafı tüm native çağrılarda timeout'lu ve **fail-closed** (test edilmiş:
  `emergency_platform_service_test.dart`).
- Native→Dart olay köprüsü: `EmergencyEventBus.emitOrPersist` — Dart ölüyse olay native prefs'e
  yazılır, açılışta `consumePendingTrigger` ile tüketilir
  ([emergency_trigger_host.dart:113-145](../lib/core/widgets/emergency_trigger_host.dart)).

**Depolama haritası (NE nerede):**

| Depo | İçerik |
|---|---|
| flutter_secure_storage ([secure_storage_keys.dart](../lib/core/security/secure_storage_keys.dart)) | `user_pin`, sahte-çağrı profili, `medical_profile`, kişi listeleri, acil kişi adı/numarası, `kvkk_consent_log`, PIN lockout sayaçları (`pin_lockout_*`, [pin_lockout_service.dart:33-34](../lib/core/services/pin_lockout_service.dart)) |
| SharedPreferences | `check_in_state_v2` / `safe_walk_state_v2` ([check_in_service.dart:53-54](../lib/core/services/check_in_service.dart)), yasal kabul bayrak/sürümleri, özellik-uyarı bayrakları, onboarding |
| sqflite ([local_database_service.dart:37-64](../lib/core/services/local_database_service.dart)) | `contacts`, `activity_events`, `crash_logs`, `app_settings` tabloları |
| **Native** SharedPreferences dosyası **`korubeni_emergency`** ([EmergencyPrefs.kt](../android/app/src/main/kotlin/com/poyrazoncel/korubeni/emergency/EmergencyPrefs.kt)) | countdown: `countdown_active/deadline_ms/alarm_fired/primary_number/dispatch_id`; check-in (safe-walk için `_safe_walk` sonekli): `check_in_active/phase/deadline/grace_ms/primary_number/alarm_fired`; `pending_trigger` |
| Dosya | `legal_logs.json` — KVKK audit log, bozulursa kendini onaran ([legal_log_service.dart](../lib/core/services/legal_log_service.dart)) |

**EncryptionService** ([encryption_service.dart](../lib/core/security/encryption_service.dart)):
AES-CBC, her şifrelemede `Random.secure()` ile rastgele IV, IV çıktının başına eklenir; eski
statik-IV verisini de çözebilir. Anahtar `--dart-define=ENCRYPTION_KEY` (base64) —
[app_constants.dart:8-11](../lib/core/constants/app_constants.dart); release'te boşsa build
reddedilir (§8).

**Offline güvenilirlik mekanizması:**
- AlarmManager `setExactAndAllowWhileIdle` (Doze-geçirgen); exact izni yoksa/iptal edilirse
  inexact `setAndAllowWhileIdle` fallback + Dart'a `nativeScheduleDegraded` bayrağı
  ([CheckInScheduler.kt:234-282](../android/app/src/main/kotlin/com/poyrazoncel/korubeni/emergency/CheckInScheduler.kt),
  kullanıcıya snackbar: [check_in_screen.dart:89-97](../lib/screens/check_in_screen.dart)).
- Boot-restore: `BootCompletedReceiver` → `restoreAfterBoot` — süre dolmamışsa alarmı yeniden
  kurar; main bitmiş + grace varsa grace'i başlatır; **grace de geçmişse native olarak birincil
  kişiyi arar** ([CheckInScheduler.kt:158-232](../android/app/src/main/kotlin/com/poyrazoncel/korubeni/emergency/CheckInScheduler.kt)).
- FGS: `flutter_background_service`, tip **`specialUse`**, subtype property
  `emergency_checkin_keepalive` ([AndroidManifest.xml:86-97](../android/app/src/main/AndroidManifest.xml)).
  Geolocator'ın konum FGS'i manifest'ten `tools:node="remove"` ile çıkarıldı (satır 99-101).
- Doze/pil sihirbazı: [battery_optimization_wizard.dart](../lib/screens/battery_optimization_wizard.dart),
  `doze_mode_service`, `battery_optimization_service` — izin reddi degraded modda devam eder.

---

## 4. ACİL AKIŞLAR (kalp)

### 4.1 Panik / Countdown (tam eskalasyon, 112'siz)

1. **Tetik:** 3sn basılı tutma; TalkBack/VoiceOver'da tek dokunuş + onay diyaloğu
   ([panic_button.dart:205-273](../lib/widgets/panic_button.dart)). Pro-gate + ilk-kullanım uyarısı önce.
2. **Guard:** callable kişi yoksa countdown HİÇ açılmaz, "kişi ekle" snackbar'ı
   ([panic_button.dart:138-145, 177-203](../lib/widgets/panic_button.dart)).
3. **Arming:** `CountdownScreen` açılır; **Dart timer'dan ÖNCE** native yedek alarm +12sn'e
   kurulur (`dispatchId` ile) ([countdown_screen.dart:126-166](../lib/screens/countdown_screen.dart)) — Doze
   geçişi pencerede yakalanmasın diye.
4. **10sn sayım** → `_makeEmergencyCall`:
   a. `didCountdownAlarmFire(dispatchId)` → native zaten aradıysa Dart **atlar** (satır 185-197);
   b. native alarm **iptal edilir** (cleanup başarısız olsa bile dispatch durmaz, satır 198-208);
   c. `_executeEmergency`: birincil numara → başarısızsa **tüm** callable numaralar sırayla
   denenir (failover, satır 283-303); hepsi `failed` → tam-ekran fail-safe (satır 305-315).
5. **İptal:** PIN girişi (üstel lockout'a tabi); PIN tanımlı değilse tek-dokunuş iptal
   ([countdown_screen.dart:927-930](../lib/screens/countdown_screen.dart)).
6. **Native yedek ateşlerse** ([CountdownAlarmReceiver.kt](../android/app/src/main/kotlin/com/poyrazoncel/korubeni/emergency/CountdownAlarmReceiver.kt)):
   `KEY_COUNTDOWN_ACTIVE` değilse (PIN'le iptal edilmiş) **reddeder**; `dispatchId` eşleşmezse
   bayat alarmı **reddeder**; `ACTIVE=false` yazar ve **tek** persist edilmiş numarayı
   `EmergencyExecutor` ile arar (failover native'de yok — o Dart'ın işi). **F1 düzeltmesi
   (FRESH_AUDIT):** `ALARM_FIRED=true` yalnız dispatch BAŞARILIYSA yazılır; `failed` dönerse
   bayrak false kalır ve **7304** id'li "elle ara" bildirimi çıkar (dokunuş dialer'ı numara
   ön-dolu açar — uygulama/PIN kapısına uğramaz).

### 4.2 Check-In / Safe-Walk (yalnız-birincil dead-man's-switch)

İkisi **aynı** kontrolörü kullanır: `CheckInService.instance` / `CheckInService.safeWalk`
([check_in_service.dart:36-43](../lib/core/services/check_in_service.dart);
safe-walk bağlaması [safe_walk_screen.dart:34](../lib/screens/safe_walk_screen.dart)). Faz makinesi:
`ACTIVE(main) → GRACE(60sn) → ESCALATE`.

1. **Guard:** callable kişi yoksa kurulamaz ([check_in_screen.dart:99-105](../lib/screens/check_in_screen.dart),
   [safe_walk_screen.dart:148](../lib/screens/safe_walk_screen.dart)).
2. **start(minutes):** koordinatör arm + native main deadline **birincil numarayla** kurulur +
   FGS + Dart ticker ([check_in_service.dart:91-120](../lib/core/services/check_in_service.dart)).
   Native kurulamadıysa `nativeScheduleDegraded` kullanıcıya gösterilir.
3. **Main dolar:** native `checkInGraceStarted` olayı + HIGH bildirim (FSI izni varsa FSI,
   yoksa heads-up) + grace alarmı kurulur
   ([CheckInAlarmReceiver.kt:24-46](../android/app/src/main/kotlin/com/poyrazoncel/korubeni/emergency/CheckInAlarmReceiver.kt));
   Dart canlıysa aynı anda grace ticker + ekran-içi uyarı
   ([check_in_service.dart:315-334](../lib/core/services/check_in_service.dart)).
4. **Grace içinde "Güvendeyim":** PIN'siz tek dokunuş → `confirmSafe()` süreyi sıfırlar; native
   alarm anında iptal edilir.
5. **Grace dolar — ESCALATE (iki yürütücü, tek arama):**
   - **Native yol** (Dart ölü olsa da çalışır): `isActive` değilse reddet →
     `deactivateForEscalation` (alarm iptal + `ACTIVE=false`) →
     `EmergencyExecutor.executeEmergency(primary)` — **yalnız birincil, 112 yok**; dispatch
     BAŞARILIYSA `markAlarmFired` (`ALARM_FIRED=true`), `failed` ise bayrak false kalır ve
     bildirim "elle ara" kopyasına döner (F1)
     ([CheckInAlarmReceiver.kt:48-90](../android/app/src/main/kotlin/com/poyrazoncel/korubeni/emergency/CheckInAlarmReceiver.kt)).
   - **Dart yol** (`_triggerEmergency`, [check_in_service.dart:351-440](../lib/core/services/check_in_service.dart)):
     `tryClaim` → `didCheckInAlarmFire` (native aradıysa atla) → **önce native alarmı iptal et**
     (dedup penceresini tek round-trip'e indirir, commit `8d6633c`) → yalnız
     `resolvePrimaryNumber` hedefini ara → `EmergencyCallScreen`. Boş hedef → arama YOK,
     `failed` sonucuyla ekran.
6. **Boot-restore:** §3'teki gibi; expired ise native birincil-arama (yalnız-bildirim DEĞİL).

### 4.3 Çift-tetikleme dedup'ının TÜM katmanları

1. **`dispatchId`** (countdown): intent'teki id ≠ persist edilen id → bayat alarm reddi
   ([CountdownAlarmReceiver.kt:31-37](../android/app/src/main/kotlin/com/poyrazoncel/korubeni/emergency/CountdownAlarmReceiver.kt)).
2. **`KEY_*_ALARM_FIRED` bayrağı — anlamı (F1 sonrası): "native dispatch BAŞARILI oldu".**
   Yalnız başarılı dispatch'ten SONRA yazılır; `failed`'de false kalır → Dart resume kendi
   aramasını (failover + bloklayıcı fail-safe) çalıştırır, başarısızlık asla sessiz yutulmaz.
   Bayrak set ise Dart resume'da arama atlar
   (countdown: [countdown_screen.dart:185-197](../lib/screens/countdown_screen.dart); check-in:
   [check_in_service.dart:365-373](../lib/core/services/check_in_service.dart)).
3. **`tryClaim`** (isolate-içi tek-arama kilidi, session-bazlı):
   [check_in_expiry_coordinator.dart](../lib/core/services/check_in_expiry_coordinator.dart).
4. **`KEY_*_ACTIVE` reddi:** iptal sonrası ateşlenen alarm native'de sessizce reddedilir
   (countdown receiver satır 26-29; check-in receiver satır 16-18).
5. **`deactivateForEscalation` + `markAlarmFired`** (eski `markAlarmFiredAndDeactivate`'in F1
   bölünmesi): arama ÖNCESİ alarm iptal + `ACTIVE=false` (bayat-alarm reddi); `ALARM_FIRED`
   yalnız BAŞARILI dispatch sonrası yazılır
   ([CheckInScheduler.kt:96-116](../android/app/src/main/kotlin/com/poyrazoncel/korubeni/emergency/CheckInScheduler.kt)).
   Bildirim ID ayrımı: **check-in 7303 / safe-walk 7305 / countdown failure 7304**
   (`notificationIdFor`) — eşzamanlı oturumların bildirimleri birbirini ezmez.
6. **Cancel-before-escalation:** Dart, aramadan ÖNCE native yedeği iptal eder; iptal hatası
   dispatch'i asla bloklamaz (countdown satır 198-208; check-in satır 375-390).

---

## 5. GÜVENLİK & KVKK

- **PIN + üstel lockout:** 5 hatalı denemeden sonra kilit; süre `30 × 2^(deneme-5)` saniye
  ([pin_lockout_service.dart:62-65](../lib/core/services/pin_lockout_service.dart)). Sayaçlar
  secure storage'da. PIN secure storage'da, legacy SharedPreferences'tan tek-seferlik migrasyon
  var ([countdown_screen.dart:102-117](../lib/screens/countdown_screen.dart)).
- **Rıza audit log (KVKK):** her onay/geri-çekme `kvkk_consent_log`'a yazılır
  ([consent_manager.dart](../lib/services/consent_manager.dart)); bozuk kayıt tüm logu silmez,
  atlanır (commit `b53cfdd`); `legal_logs.json` bozulursa kendini onarır (`5132b7c`).
- **Veri dışa aktarma (Md.11):** [user_data_export_service.dart](../lib/core/services/user_data_export_service.dart)
  — profil, sahte-çağrı, rıza logu dahil JSON üretir.
- **TAM silme (Md.7):** `AppResetService.clearLocalData`
  ([app_reset_service.dart:14-26](../lib/core/services/app_reset_service.dart)) →
  SharedPreferences.clear + secure storage deleteAll + sqflite DB dosyası silme + lokal dosyalar
  + **native `korubeni_emergency` prefs wipe'ı** (`clearEmergencyPrefs` →
  [EmergencyPrefs.kt:35-37](../android/app/src/main/kotlin/com/poyrazoncel/korubeni/emergency/EmergencyPrefs.kt),
  commit `e84c6ca`). Native wipe olmadan birincil numara silmeden sağ çıkardı — bu yüzden kritik.
- **Root tespiti (BLOKLAMAZ):** `safe_device` ile; tespit edilirse yalnız uyarı diyaloğu,
  kullanıcı devam edebilir ([splash_screen.dart:156-172](../lib/screens/splash_screen.dart)).
- **Ağ sertleştirme:** cleartext kapalı (network_security_config + `usesCleartextTraffic=false`),
  `allowBackup=false`, exported bileşen yalnız MainActivity + BOOT receiver (izin filtreli).
- **Sır yönetimi:** `ENCRYPTION_KEY` ve `REVENUECAT_ANDROID_API_KEY` yalnız `--dart-define`;
  release'te boşsa hem Gradle ([build.gradle.kts:53-66](../android/app/build.gradle.kts)) hem
  Dart ([app_environment.dart:26-38](../lib/config/app_environment.dart)) build/açılışı reddeder.
  Repo'da hardcoded sır yok (doğrulandı).

---

## 6. ERİŞİLEBİLİRLİK

- **Panik butonu AT yolu:** TalkBack aktifken 3sn-basılı-tutma yerine tek dokunuş + açık onay
  diyaloğu ([panic_button.dart:205-273](../lib/widgets/panic_button.dart), commit `cdfa78d`).
- **Countdown canlı bölge:** ekran okuyucuya saniye ilanı `liveRegion` ile (commit `98cabfd`).
- Alt gezinme sekmeleri seçilebilir buton semantiği (`5251b7c`), "Eve Dön" etiketi (`e4fe932`),
  iptal butonu kontrast artışı white38→white70 (`d673e83`).
- Grace bildirimi: HIGH importance + DnD bypass + titreşim
  ([EmergencyNotificationHelper.kt:30-37](../android/app/src/main/kotlin/com/poyrazoncel/korubeni/emergency/EmergencyNotificationHelper.kt)).
- Çalışma ağacındaki commit'lenmemiş değişiklikler rıza checkbox'larına `semanticLabel` ekliyor (§10).

---

## 7. TEST & KALİTE

**Bu oturum sonuçları:** sayfa başındaki tabloya bakın (391 Dart + 20 native, hepsi yeşil;
analyze temiz).

**Test deseni:** Acil akışlar **source-contract testleri** (kaynak kodda kritik kalıpların
varlığını assert eden) + MethodChannel mock'larıyla test edilir; gerçek Doze yarışı yalnız
cihazda kanıtlanır. Kritik dosyalar: `test/core/services/emergency_platform_service_test.dart`
(fail-closed timeout'lar), `revenuecat_subscription_contract_test.dart`, native
`CheckInExpiryEscalationTest.kt` (112/failover-yok regresyon koruması dahil).

**Bilinen borçlar:**
- Kök `./gradlew testDebugUnitTest` PATLAR → daima `:app:testPlayDebugUnitTest`
  (üçüncü-parti `flutter_direct_caller_plugin` test-variant sorunu).
- 800+ satır dosyalar (CLAUDE.md 800-maks kuralını aşıyor; bölme = UI dokunma riski, ertelendi):
  [home_page.dart](../lib/screens/home_page.dart) 1271, [countdown_screen.dart](../lib/screens/countdown_screen.dart) 1189,
  [contacts_page.dart](../lib/screens/contacts_page.dart) 1108, [map_page.dart](../lib/screens/map_page.dart) 1017.
- `dart format .` repoda format-drift üretir; yalnız yeni oluşturulan dosyaları formatla.
- 95 paketin major güncellemesi mevcut (kısıtlar içinde güncel; bilinçli sabitlemeler:
  `flutter_local_notifications ^19.1.0` v19.0.x release-bug'ı nedeniyle, [pubspec.yaml:43-47](../pubspec.yaml)).

---

## 8. PLAY STORE DURUMU

**İzinler + gerekçeler** ([AndroidManifest.xml](../android/app/src/main/AndroidManifest.xml)):

| İzin | Gerekçe / Console işi |
|---|---|
| `CALL_PHONE` | Acil doğrudan arama; reddedilirse dialer'a düşer. **Console'da yüksek-riskli izin beyanı + çekirdek-işlev gerekçesi gerekir** (oto-arama yalnız kullanıcının kurduğu güvenlik oturumlarında). |
| `FOREGROUND_SERVICE_SPECIAL_USE` + subtype property | **EN KRİTİK Console maddesi:** specialUse beyan metni hazır ([play-submission.md §1](play-submission.md)) + **demo video operatör işi**. |
| `SCHEDULE_EXACT_ALARM` | Check-in/countdown deadline'ları; reddi degraded-inexact'e düşer. Console beyanı gerekir. |
| `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS` | Opsiyonel sunulur, reddi degraded modda devam (manifest yorumu satır 36-41). |
| Konum (FINE/COARSE) | Yalnız ön planda, harita/güvenlik oturumu; arka plan konumu YOK. |
| `READ_CONTACTS` | **`tools:node="remove"` ile ÇIKARILDI** — kişi seçimi ACTION_PICK ile. |
| RECORD_AUDIO / mikrofon FGS | **YOK** (kayıt özelliği söküldü). |

**Hazır dokümanlar:** [DATA_SAFETY_FORM.md](../store/DATA_SAFETY_FORM.md) (geliştirici toplama
yok; RevenueCat/Billing + harita karoları beyanı), [CONTENT_RATING_ANSWERS.md](../store/CONTENT_RATING_ANSWERS.md)
(18+), operatör akış sırası [play-console-checklist.md](play-console-checklist.md),
yapıştırma paketi [PLAY_CONSOLE_COPY_PASTE_PACK.md](../store/PLAY_CONSOLE_COPY_PASTE_PACK.md).

**Yapıldı / Yapılmadı (git log + dosyadan tespit):**

| Madde | Durum |
|---|---|
| R8 minify + shrinkResources | ✅ YAPILDI ([build.gradle.kts:128-136](../android/app/build.gradle.kts)); keep-kuralları receiver/MethodChannel/korubeni.** için tam ([proguard-rules.pro:51-88](../android/app/proguard-rules.pro)) |
| Dart obfuscation + split-debug-info | ✅ YAPILDI — release.yml `--obfuscate --split-debug-info` + sembol artefaktı (commit `f4f9f00`) |
| Release'te debugPrint susturma | ✅ YAPILDI ([main.dart:41-44](../lib/main.dart)); FlutterError.onError pre-launch raporu için korunur (commit `2ac1fcb`) |
| Feature graphic 1024×500 | ✅ VAR — [store/assets/feature_graphic_1024x500.png](../store/assets/feature_graphic_1024x500.png) + üretici script (commit `90e08c4`) |
| 16KB page-size | ⚠️ KISMEN: 64-bit-only ABI + Flutter 3.38 + plugin matrisi analizi ([release_risks.md §16KB](release_risks.md)); **nihai kanıt Play Console "memory page size" göstergesi — operatör doğrulayacak** |
| Ekran görüntüleri | ⚠️ `store/screenshots/android/` mevcut; Console'a yükleme operatör işi |
| Console beyanları (FGS video, Data Safety, IARC) | ❌ OPERATÖR İŞİ (§12) |

**Release akışı (tag→versionCode):** workflow'lar Flutter **3.38.9**'a pinlidir
(`FLUTTER_VERSION` env, ci.yml + release.yml). `v*.*.*` tag push → [release.yml](../.github/workflows/release.yml):
`versionCode = MAJOR×10000 + MINOR×100 + PATCH` (v1.0.0 → **10000**), analyze + test + imzalı
`app-play-release.aab` + debug-symbols artefaktı. **İlk Play yüklemesi MUTLAKA v* tag push ile
yapılmalı** — lokal AAB yüklenmez (versionCode tutarlılığı + provenance).
Mevcut tag'ler: `v1.0.0-rc1`, `v1.0.0-rc2` (final `v1.0.0` HENÜZ YOK).

**Gerekli GitHub secrets:** `KEYSTORE_BASE64`, `STORE_PASSWORD`, `KEY_PASSWORD`, `KEY_ALIAS`,
`ENCRYPTION_KEY`, `REVENUECAT_ANDROID_API_KEY` (CI smoke için opsiyonel `CI_ENCRYPTION_KEY`).
Lokal release build `android/key.properties` ister; yoksa Gradle release'i REDDEDER
([build.gradle.kts:25-27](../android/app/build.gradle.kts)) — debug imzaya sessiz düşüş yok.
CI (PR/main) kendi tek-kullanımlık NON_RELEASE_SMOKE anahtarını üretir ([ci.yml:35-56](../.github/workflows/ci.yml)).

---

## 9. AÇIK / ERTELENMİŞ KONULAR

1. **Full-screen-intent (SPEC 7a):** manifest izni + Console beyanı ertelendi; kod zarif-düşüşlü
   hazır (§2.5). Karar operatörün.
2. **"Uygulama açıksa" metin güçlendirmesi (SPEC 8):** gerçek-cihaz kanıtı sonrası ayrı adım (§2.6).
3. **targetSdk 36 (Android 16):** ilk gönderim 35'te kalacak; bump sonraki release
   ([release_risks.md](release_risks.md) önerisi).
4. **Themed icon:** monochrome ikon app_icon'dan türetiliyor; özel beyaz-silüet asset üretimi
   opsiyonel iyileştirme ([pubspec.yaml:102-107](../pubspec.yaml)).
5. **workmanager** uyumluluk sorunu nedeniyle devre dışı ([pubspec.yaml:42](../pubspec.yaml)) —
   AlarmManager+FGS deseni yerine geçti, geri eklenmesi planlanmıyor.
6. **800+ satır dosyaların bölünmesi** — UI dokunmadan yapılamayacağı için bilinçli ertelendi (§7).
7. **Flutter ≥3.44 yükseltmesi:** `app_theme.dart` yeni API'ye uyarlanmalı
   (`CupertinoPageTransitionsBuilder` 3.44'te kalktı; UI dosyası — plan-onay zorunlu);
   targetSdk 36 bump'ı ve workflow pin güncellemesiyle AYNI pakette, lansman sonrası.
8. **Direct Boot sınırı (FRESH_AUDIT F4):** Boot-restore zinciri `BOOT_COMPLETED` +
   credential-encrypted prefs'e bağlıdır; cihaz reboot olur ve **ilk kilit açılışına dek**
   restore/eskalasyon çalışmaz. Bilinçli BİLİNEN SINIR olarak kabul edildi; `directBootAware`
   + device-protected storage mühendisliği backlog'dadır
   ([FRESH_AUDIT_2026-06-10.md](FRESH_AUDIT_2026-06-10.md) F4).

---

## 10. GIT DURUMU

- **main HEAD:** `231e7a7` (F1: failed native dispatch asla sessiz yutulmaz) + devam serisi
  (i18n diakritik · a11y etiketleri · billing guard · hijyen · F8 · F5 · F2/F3 plan kaydı ·
  doküman senkronları). Yayın dalı yok; release tag'le CI'dan.
- Yerel↔origin senkron durumunun tek doğru kaynağı git'tir (`git fetch && git status`);
  bu doküman senkron iddiası taşımaz.
- **Çalışma ağacı TEMİZ** (11 Haziran 2026): önceki raporda duran 21 commit'lenmemiş dosya
  bu seride mantıksal parçalara bölünerek commit'lendi — `fix(i18n)` tr-TR diakritik ·
  `feat(a11y)` lokalize rıza-checkbox `semanticLabel`'ları (legal_disclaimer'ın 5 hardcoded
  etiketi `.tr()` anahtarına çevrildi, TR metinler karakteri karakterine korundu) ·
  `fix(billing)` RevenueCat `_isConfigured`/`_canUsePurchases` guard'ı + kontrat testi ·
  `chore` const/stil hijyeni + smoke-script'teki bayat "112'ye düşer" beklentisinin
  düzeltilmesi. Tüm kapılar (analyze + flutter test + `:app:` native) seri boyunca yeşil.
- **Son commit'lerin anlamı (yeniden eskiye):**
  *(bu seri)* docs(audit) triyaj+git tazeleme · chore hijyen+smoke · fix(billing) RC guard ·
  feat(a11y) etiketler · fix(i18n) diakritik · `231e7a7` **F1 düzeltmesi** (FRESH_AUDIT) ·
  `f4f9f00` release AAB obfuscation+semboller · `2ac1fcb` release debugPrint susturma ·
  `9c99c06` Console checklist + CALL_PHONE notundan bayat 112 temizliği · `90e08c4` feature
  graphic · `1977661`+`816cbbf` yasal sürüm/sayfa eşitleme · `684ba5d` **panik callable-contact
  guard'ı** · `6beb774` **112'nin TÜM akışlardan sökülmesi** · `e84c6ca` KVKK Md.7 native prefs
  wipe · `8d6633c` check-in cancel-before-escalation dedup · `f6e09eb` M2 merge (grace'li
  dead-man's-switch + native yedek).
- **Dal hijyeni:** ~90 bayat `claude/*` dalı + `feat/m2-*`, `fix/*`, `release/play-ready-20260521`,
  `wip/*`, `temp-rebase-*` dalları duruyor — temizlik opsiyonel, operatör kararı.
- `gh-pages` dalı yasal sayfaları yayınlar (privacy_policy.html, data_deletion.html…).

---

## 11. YALNIZ GERÇEK CİHAZDA KANITLANIR

Kod/birim testle KANITLANAMAYAN, cihaz turu bekleyenler
([MANUAL_SMOKE_TEST_SCRIPT.md](../store/MANUAL_SMOKE_TEST_SCRIPT.md) +
[REAL_DEVICE_QA_MATRIX.md](../store/REAL_DEVICE_QA_MATRIX.md)):

1. Doze/app-kill altında **native yedek aramanın fiilen çıkması** (countdown + check-in/safe-walk).
2. **Boot-restore** sonrası expired-session native araması.
3. **Dedup yarışı** (Dart resume ↔ native fire çakışması) — kodda 6 katman var (§4.3) ama yarış
   ancak cihazda gözlenir.
4. **OEM-kill** (Xiaomi/Samsung agresif pil yönetimi) altında FGS + alarm hayatta kalımı.
5. **Exact-alarm reddi** → degraded inexact davranışı ve kullanıcı uyarısı.
6. **"Verilerimi Sil" sonrası** native `korubeni_emergency` dosyasının gerçekten boşaldığı.
7. Boş-hedef fail-safe'inin cihazda görünür/bloklayıcı olduğu (smoke script satır 11).
8. **Dispatch-failure fail-safe turu (F1):** Oturum aktifken CALL_PHONE iznini geri al,
   uygulamayı öldür, süreyi doldur (Android 13/14/15): elle-ara bildirimi çıkıyor mu, numara
   doğru mu, dokununca dialer ön-dolu açılıyor mu, kilit ekranında içerik görünüyor mu?
   - Bildirim dokunuş yolları: **7304** dokunuşu dialer'ı numara ön-dolu açıyor mu; **7303**
     dokunuşunda uygulama kilidi (PIN) aktifken otomatik retry'ın PIN'e takılıp takılmadığını
     gözle.
   - Receiver bağlamından ACTION_CALL/ACTION_DIAL'ın gerçek cihazda
     Background-Activity-Launch kısıtına takılmadığını doğrula — `startActivity`'nin
     istisnasız dönmesi UI'nin göründüğünü KANITLAMAZ; "dialerOpened" durumu cihazda gözle
     teyit edilmeli.

> ⚠️ Cihaz QA'sı **İMZALI RELEASE AAB** üstünde yapılmalı: debug build R8/obfuscation
> çalıştırmaz; keep-kuralı regresyonları (receiver adı, MethodChannel) yalnız release'te görünür.

---

## 12. OPERATÖRÜN MANUEL İŞLERİ (kod dışı)

1. **Play Console beyanları:** FGS specialUse beyanı + **demo video** (senaryo:
   [play-submission.md §1](play-submission.md)); CALL_PHONE izin beyanı; exact-alarm; Data
   Safety formu; IARC content rating (18+); App access "Pro test talimatı". Sıra:
   [play-console-checklist.md](play-console-checklist.md).
2. **Keystore yedeği:** `KEYSTORE_BASE64`/parolalar güvenli kasada; kaybolursa Play imza kimliği
   geri alınamaz (üretim adımları: [KEYSETUP.md](../KEYSETUP.md)).
3. **RevenueCat:** dashboard'da `KoruBeni Pro` entitlement + Play abonelik ürünü Active;
   secrets'ta gerçek `REVENUECAT_ANDROID_API_KEY`.
4. **Gerçek-cihaz QA turu** (§11) — production'dan ÖNCE, release AAB ile.
5. **`v1.0.0` tag push** → CI AAB'sini Play **internal testing**'e yükle (ilk yükleme asla lokal
   AAB ile değil).
6. Yasal URL'lerin canlı ve tarih damgalarının (21 Mayıs 2026) doğru olduğunun kontrolü.
7. Play Console "memory page size" (16KB) göstergesinin yeşil olduğunun teyidi.

---

## EK: ESKİMİŞ BİLGİ LİSTESİ (eski doküman ↔ güncel kod çelişkileri)

Yeni oturum bu dokümanlara bakarsa şu kısımlara **güvenmesin**:

1. **[SPEC.md](../SPEC.md) §0.1 ve §1.3 — "countdown/panikte 112 fallback VAR" der.**
   GEÇERSİZ: SPEC, M2 yazıldığı andaki durumu anlatır; sonraki `6beb774` commit'i 112'yi
   countdown/panik dahil HER yerden söktü. Bugün `EmergencyExecutor`'da 112/çoklu-numara dalı
   yoktur (failover Dart'ta, 112 hiçbir yerde). SPEC'in "M2'de countdown'un 112 davranışına
   dokunulmaz" notları artık konusuz.
2. **[SPEC.md](../SPEC.md) §1.2 — "native arama YAPMAZ / yalnız bildirim" tarifi** pre-M2
   durumdur; M2 uygulandı, native yedek artık birincil kişiyi arar (§4.2).
3. **[docs/release_risks.md](release_risks.md) plugin tablosu:** `flutter_jailbreak_detection
   ^1.10.0` ve `flutter_local_notifications ^17.2.1` listeler — güncel pubspec'te root tespiti
   **`safe_device ^1.3.10`**, FLN **`^19.1.0`**. 16KB plugin matrisi bu satırlar için bayat.
4. **[build.gradle.kts:85](../android/app/build.gradle.kts) yorumu** "Android 6.0: USE_BIOMETRIC
   minimum" der — bayat: fiili minSdk **24**'tür (Flutter 3.38 varsayılanı) ve biyometrik bu
   projede zaten yasaktır.
5. **[KEYSETUP.md](../KEYSETUP.md)** lokal keystore adı `korubeni-release-key.jks` örneği verir;
   CI gerçeği `android/app/korubeni_keystore.jks` (secret'tan decode, release.yml:53). Lokal
   kılavuz olarak okunmalı, CI yolu esas alınmalı.
6. **Kök `README.md` / `BUILD_*.md` dosyaları** erken dönem build notlarıdır; release süreci
   için tek doğru kaynak [release.yml](../.github/workflows/release.yml) +
   [play-console-checklist.md](play-console-checklist.md)'dir.
7. **Eski "`ALARM_FIRED` = native ateşledi" semantiği BAYATTIR.** F1 düzeltmesi
   ([FRESH_AUDIT_2026-06-10.md](FRESH_AUDIT_2026-06-10.md)) sonrası doğru okuma:
   "`ALARM_FIRED` = native dispatch BAŞARILI oldu". [SPEC.md](../SPEC.md) §3.2/§5'teki
   "arama sonrası bayrak yaz" tarifleri ve `markAlarmFiredAndDeactivate` adı geçen tüm eski
   açıklamalar bu yüzden güncel değildir — başarısızlıkta bayrak false kalır, elle-ara
   bildirimi devreye girer.
