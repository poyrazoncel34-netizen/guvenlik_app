# KoruBeni — Production / Google Play Launch Readiness (2026-10-05)

> Etiketler: `[KESİN]` birincil kanıtla doğrulandı · `[GÜÇLÜ ÇIKARIM]` kanıttan kuvvetle çıkarılıyor, doğrudan doğrulanmadı · `[BİLİNMEYEN]` mevcut kanıtla belirlenemiyor.
> Bu belge hukuki tavsiye değildir. KVKK maddeleri teknik/hukuki boşluk analizidir; karar hukukçuya aittir.

**Ölçülen commit:** `b2acaa59598e7a23f138e5fef53a075fc0726fe1` (dal `codex/evidence-remediation-20260911`, çalışma ağacı temiz).
**Araç zinciri:** Flutter 3.38.9 / Dart 3.10.8 · AGP 8.9.1 · Kotlin 2.1.0 · Gradle 8.14.
**Bu oturumda kod değişikliği yapılmadı.** (CLAUDE.md kural 5: plan + onay.)

---

## 1. Executive Launch Status

**Production için: NO-GO (bugün). Kapalı test kanalı için: depo tarafı hazır; engel operasyonel.**

Kod kapısı güçlü. Bu commit'te yerel release zinciri 6/6 yeşil, 2079 Dart testi ve 138 Kotlin testi geçiyor. Target API 36 ve Billing 8.3.0 Play şartlarını karşılıyor. Manifest dar tutulmuş, mağaza metninde yasaklı güvenlik iddiası yok. Buna rağmen production için zorunlu kapıların çoğu doğrulanmadı:

- **Production AAB yok.** Bu kod hiç push edilmedi: yerel `main`, `origin/main`'in 160 commit önünde ve bu dal ayrıca 38 commit önde. Production AAB'yi yalnızca GitHub'daki tag tabanlı `release.yml` üretiyor.
- **Fiziksel cihaz kabul testi yapılmadı.** Bütün cihaz kanıtları emülatörde alınmış.
- **Gerçek Play sandbox satın alma akışı hiç denenmedi.**
- **Kişisel hesap için 12 tester × 14 gün şartının durumu bilinmiyor.**
- **KVKK onay mimarisi** 2026/347 ilke kararıyla çelişme riski taşıyor; hukukçu görüşü gerekli.

Bu kapılar kapanmadan GO verilemez.

---

## 2. Verified Architecture Snapshot (yalnız doğrulanmış)

| Konu | Gerçek | Kanıt |
|---|---|---|
| Paket / SDK | `com.poyrazoncel.korubeni`, minSdk 29, target/compile 36 | `[KESİN]` merged release manifest `minSdkVersion="29" targetSdkVersion="36"`; `android/app/build.gradle.kts` |
| Flavor'lar | `play` (prod, arm64-only) ve `smoke` (`.smoke`, billing kapalı, yüklenemez) | `[KESİN]` build.gradle.kts; Play release `ENV=production` + `goog_` anahtarı yoksa Gradle reddeder |
| Billing | `com.android.billingclient:billing:8.3.0`; RevenueCat `purchases` 10.14.0 / hybrid 18.22.1; `purchases_flutter` 10.4.2 | `[KESİN]` `android/app/gradle.lockfile` (`dependencyLocking { lockAllConfigurations() }`), `pubspec.lock` |
| Backend/analytics/crash/FCM/SMS/AI | Yok | `[KESİN]` manifest + bağımlılık listesi; OSV taraması 195 pub + 203 Maven bileşeni gördü |
| Native otorite | `EmergencySessionCoordinator` tek süreç kilidiyle (`PROCESS_LOCK`) tüm geçişleri yönetiyor; Dart projeksiyon | `[KESİN]` `EmergencySessionCoordinator.kt` |
| Durum makinesi | PREPARING→ARMED→(CANCELLED \| CLAIMED→REQUEST_SUBMITTED_UNCONFIRMED \| MANUAL_ACTION_REQUIRED \| REQUEST_FAILED), CORRUPTED | `[KESİN]` `EmergencySessionModels.kt` |
| Claim yarışı | Dart ve AlarmManager aynı token ile `claimAndDispatch`; dayanıklı ARMED→CLAIMED yazımı tek kazanan belirler; kaybeden dayanıklı sonucu okur; süreç içi `submittedInProcess` ikinci Telecom isteğini engeller; çöküş sonrası en-az-bir-kez penceresi açıkça belgelenmiş | `[KESİN]` coordinator satır 248–407 |
| Arama | `TelecomManager.placeCall` → yalnız `SUBMITTED_UNCONFIRMED`; `ConnectionState` enum'unda tek değer `UNKNOWN` | `[KESİN]` `AndroidEmergencySessionRuntime.kt` |
| Arm ön koşulları (fail-closed) | entitlement AUTHORIZED, PIN, aranabilir hedef, telefon/Telecom/dialer, CALL_PHONE, exact alarm, bildirim açık, alert kanalı ≥ HIGH | `[KESİN]` `CapabilitySnapshot.rejectionReason()` |
| Alarm | `setExactAndAllowWhileIdle` + bağımsız `setAndAllowWhileIdle` (ELAPSED_REALTIME_WAKEUP); exact kabul edilmezse arm reddedilir | `[KESİN]` `AndroidEmergencySessionAlarmScheduler` |
| Reboot / saat | LOCKED_BOOT/BOOT → `reconcileAfterBoot` (elapsed yeniden bazlanır); TIME_SET/TIMEZONE → elapsed'e göre yeniden hesap; 5 dk'dan eski geçmiş oturum aranmaz, bildirimle önerilir | `[KESİN]` coordinator `reconcile*`, `MAX_OVERDUE_DISPATCH_MS` |
| BOOT receiver ↔ FGS | Boot receiver hiçbir foreground service başlatmıyor; manifestte `FOREGROUND_SERVICE*` yok | `[KESİN]` `BootCompletedReceiver.kt`, merged manifest |
| Hedef numara saklama | Device-protected SharedPreferences'ta düz metin; yalnız PREPARING/ARMED/CLAIMED ve ≤ 24 sa fallback penceresinde | `[KESİN]` `DeviceProtectedEmergencySessionStore.kt`, `FALLBACK_TARGET_RETENTION_MS` |
| Hedef değişmezliği | Arm anındaki normalize hedef oturum boyunca sabit; kişi düzenleme oturumu yönlendiremez | `[KESİN]` `immutableTargetMismatch`, `_armedTargetNumber` |
| Dart dispatch timeout | 5 sn; timeout → `readEmergencySession`; hâlâ belirsizse `ACTION_DIAL` | `[KESİN]` `emergency_platform_service.dart:313-346`, `countdown_screen.dart:367-376` |
| Test modu | Native arm yok, arama yok | `[KESİN]` `countdown_screen.dart` `_startCountdown` |
| Ses tuşu | `MainActivity.onKeyDown` → yapısal olarak yalnız ön planda | `[KESİN]` `MainActivity.kt:473` |
| Safe Walk konum | `safe_walk_screen.dart` / `check_in_service.dart` geolocator kullanmıyor | `[KESİN]` |
| Kişi seçici | READ_CONTACTS `tools:node="remove"`; ACTION_PICK | `[KESİN]` manifest |
| PIN | PBKDF2-HMAC-SHA256, 100 000 iter, 16 B salt, 32 B anahtar, sabit-zamanlı karşılaştırma, düz-metin legacy kayıt ilk başarılı girişte yükseltilir; senkron (UI isolate) | `[KESİN]` `pin_hasher.dart`, `pin_verification_service.dart` |
| PIN kilidi | `DateTime.now()` (duvar saati) | `[KESİN]` `pin_lockout_service.dart:17,118,151` |
| RevenueCat | Entitlement `"KoruBeni Pro"`; anahtar `--dart-define`; anonim kullanıcı (logIn yok); `informational` doğrulama + kod tarafında yalnız `verified`/`verifiedOnDevice` güvenilir; `automaticDeviceIdentifierCollectionEnabled=false`; `diagnosticsEnabled=false`; abonelik yönetimi Play linki | `[KESİN]` `revenue_cat_service.dart`, `app_constants.dart:90`, `subscription_management_screen.dart:85` |
| Harita | Varsayılan `https://tile.openstreetmap.org/{z}/{x}/{y}.png`; UA `flutter_map (com.poyrazoncel.korubeni; +korubeni.destek@gmail.com)`; atıf görünür; HTTP cache'e saygılı sınırlı önbellek; açılışta kullanıcı konumuna merkezlenir (zoom 15–16) | `[KESİN]` `app_environment.dart`, `map_utils.dart`, `map_page.dart:151,512,395` |
| Tile sağlayıcı değişimi | `MAP_TILE_URL_TEMPLATE` derleme zamanı `--dart-define` → **değişiklik yeni sürüm gerektirir** | `[KESİN]` `String.fromEnvironment` |
| Uzak kill-switch / remote config | Yok | `[KESİN]` |

**Başlangıç modeliyle çelişki:** Bulunmadı. Ek bulgu: `docs/audit/*` altındaki bütün cihaz kanıtları emülatörde (AVD `KoruBeni_API37_16k`, `KoruBeni_A017_API35*`) alınmış; fiziksel cihaz kaydı yok `[KESİN]`.

---

## 3. Policy Evidence Register (erişim: 2026-10-05)

| # | Gereksinim | Resmi kaynak | Uygulanır mı | Durum |
|---|---|---|---|---|
| R1 | 31 Ağu 2026'dan itibaren yeni uygulama/güncelleme API 36 hedeflemeli; uzatma 1 Kas 2026 | [Android Dev — Target API](https://developer.android.com/google/play/requirements/target-sdk) | Evet | `[KESİN]` target 36 ✓ |
| R2 | PBL 7 için yeni uygulama/güncelleme son tarihi 31 Ağu 2026 (uzatma 1 Kas 2026); PBL 8 için 31 Ağu 2027 | [Billing deprecation FAQ](https://developer.android.com/google/play/billing/deprecation-faq) | Evet | `[KESİN]` 8.3.0 ✓ (2027-08-31'e kadar) |
| R3 | 30 Eyl 2026'dan itibaren tüm Play paketleri kayıtlı olmalı; kayıtsızlar Play'den kaldırılır | [Play Console Help 16984799](https://support.google.com/googleplay/android-developer/answer/16984799) · [Policy deadlines](https://support.google.com/googleplay/android-developer/answer/12253906) | Evet | `[BİLİNMEYEN]` Console Ana sayfası kontrolü — sahip |
| R4 | 13 Kas 2023 sonrası açılan kişisel hesaplarda ≥12 tester, kesintisiz ≥14 gün kapalı test, sonra production erişim başvurusu | [Play Console Help 14151465](https://support.google.com/googleplay/android-developer/answer/14151465) | `[GÜÇLÜ ÇIKARIM]` Evet (2026-07-23 notu: hesap kişisel) | `[BİLİNMEYEN]` başlangıç durumu |
| R5 | Yeni kişisel hesaplarda Play Console mobil uygulamasıyla fiziksel Android cihaz (≥ Android 10, root'suz) doğrulaması | [Play Console Help 14316361](https://support.google.com/googleplay/android-developer/answer/14316361) | Muhtemelen | `[BİLİNMEYEN]` |
| R6 | `USE_EXACT_ALARM` yalnız alarm/timer/takvim çekirdek işlevleri için; diğerleri kullanıcı onaylı `SCHEDULE_EXACT_ALARM` kullanmalı | [Permissions & sensitive APIs](https://support.google.com/googleplay/android-developer/answer/16558241) | `SCHEDULE_EXACT_ALARM` var, `USE_EXACT_ALARM` yok | `[KESİN]` uyumlu |
| R7 | Doze muafiyeti yalnız çekirdek işlev bozuluyorsa; tabloda **"Safety app — Acceptable"** | [Doze & App Standby](https://developer.android.com/training/monitoring-device-state/doze-standby) | Evet | `[KESİN]` politika uyumlu; inceleme sorusu olası |
| R8 | 27 Oca 2027: kesin konum için "location button" önerilen minimum kapsam; geniş erişim gerekmeyen uygulamalar Contact Picker kullanmalı | Policy deadlines + R6 sayfası | Evet (2027) | Kişi: ✓ ACTION_PICK. Konum: P2 |
| R9 | Aboneliği yönetme/iptal için kolay çevrimiçi yöntem (ör. Play Abonelik Merkezi linki) | [Play Help 9900533 — Subscriptions](https://support.google.com/googleplay/android-developer/answer/9900533) | Evet | `[KESİN]` link mevcut |
| R10 | App content: hedef kitle + içerik derecelendirmesi tüm uygulamalar için; Health apps beyanı (özelliği olmayanlar dahil) tüm uygulamalar için | [Play Help 9859455](https://support.google.com/googleplay/android-developer/answer/9859455) · [Health apps 14738291](https://support.google.com/googleplay/android-developer/answer/14738291) | Evet | Sahip — Console |
| R11 | RevenueCat kullanan uygulama Data Safety'de **Purchase history**: Collected, App functionality + Analytics, zorunlu, ephemeral değil; cihaz kimliği yalnız reklam-ID entegrasyonunda | [RevenueCat — Play Data Safety](https://www.revenuecat.com/docs/platform-resources/google-platform-resources/google-plays-data-safety) | Evet | Taslak §12 |
| R12 | OSMF: görünür atıf, benzersiz UA, cache (≥7 gün ya da header), toplu indirme/offline yasak, **SLA yok**, uyarısız engelleme | [OSMF Tile Usage Policy](https://operations.osmfoundation.org/policies/tiles/) | Evet | `[KESİN]` kod uyumlu; operasyonel risk P2 |
| R13 | OSMF IP, cihaz/tarayıcı türü vb. topluyor; CDN konum kaydı üretebilir; tile dışı veriler UK/NL | [OSMF Privacy Policy](https://osmfoundation.org/wiki/Privacy_Policy) | Evet | KVKK m.9 ve Data Safety girdisi |
| R14 | KVKK Kurulu 18.02.2026, 2026/347: aydınlatma ve açık rıza ayrı başlık, ayrı metin, ayrı beyan; aydınlatma için onay/rıza istenmez (yalnız "okudum" geri bildirimi); başka işleme şartı varsa açık rıza metni sunulmaz. RG 24.03.2026 / 33203 | [KVKK kamuoyu duyurusu](https://www.kvkk.gov.tr/Icerik/8710/) · [Karar PDF](https://www.kvkk.gov.tr/SharedFolderServer/CMSFiles/MTY5Y2UzNzI5ZDQzODc.pdf) | Evet | Boşluk §13 |
| R15 | KVKK m.9 (2024 sonrası): uygun güvence olarak standart sözleşme; imzadan sonra 5 iş günü içinde Kuruma bildirim | [KVKK Yurt Dışına Aktarım](https://www.kvkk.gov.tr/Icerik/2053/Yurtdisina-Aktarim) · [Standart sözleşme duyurusu](https://www.kvkk.gov.tr/Icerik/8170/) | `[BİLİNMEYEN — hukukçu]` | §13 |

---

## 4. P0 Launch Blockers

| ID | Bulgu | Etiket | Sahip | Kapanış kanıtı |
|---|---|---|---|---|
| **P0-1** | Release adayı kod yalnız bu dizüstünde duruyor. Yerel `main`, `origin/main`'in 160 commit önünde (`origin/main` = 3 Ağu `d0693eb`); bu dalın upstream'i yok ve 38 commit önde. CI bu kodda hiç koşmadı. Production AAB'yi yalnız tag tabanlı `release.yml` üretiyor (imza ve RC anahtarı GitHub secret'larında). Uzaktaki son tag `v1.0.2` eski koda işaret ediyor. Ek risk: kaynak kodun tek kopyası bu dizüstünde. **Ek (2026-10-06):** sertleştirilmiş `release.yml`'in istediği `EXPECTED_UPLOAD_CERT_SHA256` ve `EXPECTED_PLAY_APP_SIGNING_CERT_SHA256` secret'ları GitHub'da yok. `RELEASE_TAG_SSH_ALLOWED_SIGNERS` (ya da `RELEASE_TAG_GPG_PUBLIC_KEYS`) değişkeni de tanımlı değil. Tag imzalı ve annotated olmalı, ama bu makinede imza anahtarı yok. Bunlar tamamlanmadan `v1.0.3` koşusu ilk adımlarda kırmızı olur. | `[KESİN]` (`gh secret list`, `gh variable list`, `scripts/verify_release_tag.sh`) | Developer (push onayı sahipte) | push → `ci.yml` yeşil → `v1.0.3` tag → `release.yml` artefaktı + provenance |
| **P0-2** | Fiziksel cihaz kabul testi sıfır (Doze, OEM, reboot, kilitli ekran, gerçek telefon hattı, çift SIM) | `[KESİN]` | Fiziksel cihaz testçisi | §10 matrisi dolu + `docs/audit/` kaydı (cihaz, OS, commit, `lastUpdateTime`) |
| **P0-3** | Gerçek Play sandbox satın alma / restore / iptal / süre dolumu akışı hiç denenmedi; RevenueCat dashboard eşlemesi bilinmiyor | `[KESİN]` kanıt yok · `[BİLİNMEYEN]` yapılandırma | RevenueCat sahibi + Play Console sahibi | `store/BILLING_RELEASE_CHECKLIST.md` uçtan uca + RC event log |
| **P0-4** | Production erişimi için 12×14 kapalı test. Hesap kişisel (2026-07-23 notu); testin başlayıp başlamadığı bilinmiyor | `[GÜÇLÜ ÇIKARIM]` | Play Console sahibi | Dashboard "Apply for production" uygun |
| **P0-5** | Paket kaydı (30 Eyl 2026 son tarihli). 2026-07-23 notunda geliştirici doğrulaması tamam görünüyor; **paket kaydı** ayrıca doğrulanmalı | `[BİLİNMEYEN]` | Play Console sahibi | Console Ana sayfa / "Android developer verification" ekranı |

---

## 5. P1 Pre-launch Issues

| ID | Bulgu | Etiket | Önerilen işlem |
|---|---|---|---|
| **P1-1** | **KVKK 2026/347 onay mimarisi.** Tek ekranda: Şartlar kabulü, aydınlatma kutusu ("okudum … anladım") ve 4 isteğe bağlı açık rıza. Somut sorunlar: (a) Acil kişi ekleme `typeEmergencyContacts` açık rızasına bağlı (`contacts_page.dart:66`, `onboarding_contact_gate_service.dart:95,160`), Panik de birincil kişi gerektiriyor; yani ücretli çekirdek hizmet açık rızaya bağlanmış. Karar, başka işleme şartı (ör. m.5/2-c sözleşmenin ifası) varsa açık rıza **sunulmamasını** istiyor. (b) Aydınlatma onayı tüketim kaydına `grantConsent(ConsentRecord.typeKvkk)` olarak, yani "rıza verildi" diye yazılıyor; aslında bir bilgi edinme beyanı. (c) Yaş metni "kişisel veri işleme **rızanızın** geçerliliği için" diyor. (d) Kişi rızası metni "yerel veritabanında saklanır" diyor; gerçekte saklama yeri secure storage. | Kod gerçekleri `[KESİN]` · uyumsuzluk `[GÜÇLÜ ÇIKARIM]` | Hukukçu görüşü → onaylı tasarım. Akış/metin değişikliği CLAUDE.md kural 4 gereği **sahip onayı** ister. Gerekirse `scripts/bump_legal.sh` ile `kvkkVersion` artırılır (herkes yeniden onaylar). |
| **P1-2** | **KVKK m.9 yurt dışı aktarım.** RevenueCat (ABD) ve OSMF (UK/NL + CDN) akışları gerçek. Aydınlatma metni bu durumu kendisi açık madde olarak yazıyor: "KVKK Madde 9 mekanizması ve sözleşme kanıtı yayın kapısında ayrıca doğrulanır". Aktarımın abonelik süresince sürekli olması istisna yolunu zayıflatıyor `[GÜÇLÜ ÇIKARIM]`. | `[BİLİNMEYEN — hukukçu]` | Hukukçu: mekanizma seçimi (standart sözleşme + 5 iş günü bildirimi vb.) ve OSMF tile isteklerinin kapsama girip girmediği |
| **P1-3** | **Canlı Kullanım Şartları eski.** `kullanim_sartlari.html` yayında v3.1.0 (21 May), uygulama 4.0.0 (25 Ağu) kabul ettiriyor. Kök neden P0-1: `.gh-pages-publish` güncellemesi push edilmedi; son Pages deploy'u 2026-07-23. Privacy, aydınlatma ve data_deletion sayfaları güncel. | `[KESİN]` `scripts/verify_live_legal_urls.sh` → `FAIL terms_html` | Push sonrası `pages.yml` otomatik tetiklenir; script yeniden koşulup PASS alınır |
| **P1-4** | **Data Safety alan bazında hazır değil.** Mevcut taslak anlatı biçiminde. RevenueCat'in Purchase history şartı var. Harita tile'larından konum çıkarımı 2026-10-06'da karara bağlandı. | `[KESİN]` kaynak | §12 alan bazlı yanıtlar; Console'a giriş sahipte |
| **P1-5** | **Gizlilik politikası §15** ("Uluslararası Veri Aktarımı") alıcı/ülke/veri türü vermiyor; OSMF'ye giden IP + tile koordinatı yalnız aydınlatmada yazıyor | `[KESİN]` metin | P1-2 hukukçu çıktısıyla birlikte; değişirse `bump_legal.sh` |
| **P1-6** | **Mağaza varlıkları.** Ekran görüntüleri 2026-04-27 tarihli, güncel UI'ı yansıttığı bilinmiyor. Console'daki ad (not: "KoruBeni - Kişisel Güvenlik") ile kopya paketteki ad ("KoruBeni: Panik Butonu, Siren") farklı. Kopya paketteki kategori "Tools veya Safety"; Play'de "Safety" kategorisi yok. | `[BİLİNMEYEN]` / `[GÜÇLÜ ÇIKARIM]` | Debug build'den yeni ekran görüntüsü (release'te FLAG_SECURE var); ad ve kategori sahip kararı |
| **P1-7** | **Çift SIM.** `placeCall` `PhoneAccountHandle` olmadan çağrılıyor. Varsayılan SIM "her seferinde sor" ise sistem SIM seçiciyi gösterir ve kilitli/arka planda arama ilerlemeyebilir. Uygulama bağlantı iddia etmiyor, bu doğru. | `[GÜÇLÜ ÇIKARIM]` | Fiziksel test (senaryo 19); bulgu doğrulanırsa kurulumda yönlendirme. **SAFETY SEMANTIC** — sahip kararı |
| **P1-8** | **Bilinen yarış:** Dart 5 sn timeout → durum okuma belirsiz → `ACTION_DIAL`, native çağrı da gitmiş olabilir | `[KESİN]` kod | **Kod değişikliği önerilmiyor**; §8'deki tradeoff sahip tarafından açıkça kabul edilmeli |
| **P1-9** | **Fail-closed arm.** Exact alarm, bildirim, HIGH kanal veya CALL_PHONE eksikse Panik arm olmuyor. Android 14+ temiz kurulumda `SCHEDULE_EXACT_ALARM` varsayılan olarak reddedili; her yeni Pro kullanıcısı "Alarmlar ve hatırlatıcılar" iznini vermeli. Mağaza metni bu bağımlılığı yalnız Safe Walk için söylüyor. | `[KESİN]` kod | Davranış korunur; mağaza metnine sınır cümlesi (§15); fiziksel UX testi |

---

## 6. P2 Post-launch Technical Debt

| ID | Bulgu | Etiket |
|---|---|---|
| P2-1 | PIN kilidi duvar saatine bağlı: saat ileri alınırsa kilit kalkar. Saldırgan cihaz kilidini zaten açmış olmalı; 4 haneli PIN + 100k PBKDF2 ile yine de risk. Monoton + duvar saati karışımı önerilir (security review gerekir). | `[KESİN]` |
| P2-2 | PBKDF2 100k, iptal yolunda senkron ve UI isolate üzerinde. Düşük seviye cihazda gecikme ölçülmedi. Plan: arm'lı geri sayımda PIN iptali, 30 deneme, medyan + p95 (`Stopwatch` + `adb logcat`), ≤2 GB RAM sınıfı cihaz. Kabul ölçütü örneği: p95 < 1 sn (sahip onaylar). | `[KESİN]` senkron · `[BİLİNMEYEN]` gecikme |
| P2-3 | Mağaza metni "Acil kişi kayıtları için cihaz içi yerel veritabanı" diyor; gerçekte secure storage. Güvenliği olduğundan düşük gösteriyor. | `[KESİN]` |
| P2-4 | 27 Oca 2027 konum düğmesi politikası; şu an `ACCESS_FINE_LOCATION` runtime izni | `[KESİN]` |
| P2-5 | OSMF SLA yok + derleme zamanı URL. Harita kesilirse düzeltme yeni sürüm ister. Harita acil yolda değil (`map_consent_gate_test`: "the emergency path is not gated on consent"). Sözleşmeli tile sağlayıcı değerlendirilmeli; Data Safety ve KVKK etkisi yeniden yapılır. | `[KESİN]` |
| P2-6 | Android 16 `PROPERTY_COMPAT_ALLOW_RESTRICTED_RESIZABILITY` geçici opt-out; API 37 hedeflenince kalkar | `[KESİN]` |
| P2-7 | Bu oturumda koşulmayanlar: mutation testleri (`scripts/run_safety_mutations.py`), instrumentation testlerinin cihazda çalıştırılması (yalnız derlendi), strict bağımlılık doğrulaması | `[KESİN]` |
| P2-8 | IARC'de "Social interaction: Yes" muhafazakâr bir yanıt; uygulama içi kullanıcı-kullanıcı etkileşimi yok. Gözden geçir. | `[GÜÇLÜ ÇIKARIM]` |

P3 (ölü veya miras kod: `health_check_service`, `OfflineQueueService`, boş `contacts` tablosu, `call_service` adlandırması) yayını etkilemiyor; yayından önce dokunulmamalı.

---

## 7. Code Changes Made

**Yok.** Bu oturum yalnız okuma, doğrulama ve araştırma yaptı. Önerilen değişiklikler §17 ve sohbetteki planda; sahip onayı bekliyor.

---

## 8. Unresolved Safety Risks

1. **Otomatik çağrı + manuel dialer yarışı (P1-8).** Üç risk arasında bir tercih var:
   - *Yanlış negatif:* native çağrı gitti ama Dart "belirsiz" diyor.
   - *Mükerrer kullanıcı eylemi:* dialer açılıyor, kullanıcı ikinci kez arayabilir.
   - *Hiç çağrı yok:* dialer açılmasaydı, native gerçekten başarısız olduğunda tek yol kaybolurdu.

   Mevcut kod mükerrer eylemi göze alıp "hiç çağrı yok" riskini en aza indiriyor. Önerim davranışı **korumak**. Semantik değişikliği sahip onayı olmadan yapılmaz.
2. **Çift SIM seçici (P1-7)** — doğrulanmadı.
3. **Force-stop:** Android alarmları siliyor; kullanıcı uygulamayı açana kadar hiçbir şey olmuyor. Açılışta 5 dk'dan eski oturum aranmıyor, bildirimle öneriliyor. Bu, normal süreç ölümü ve reboot'tan farklı bir durum. Emülatörde doğrulandı (`device-verification-2026-09-13-force-stop.md`); OEM'in kendiliğinden force-stop yapıp yapmadığı `[BİLİNMEYEN]`.
4. **Telecom kabulü ≠ bağlantı.** Uygulama bunu bilmiyor ve doğru biçimde iddia etmiyor.
5. **Device-protected düz metin hedef:** Direct Boot'ta (kilit açılmadan) reboot kurtarması için gerekli. Saklama süresi oturum + ≤24 sa fallback; terminal durumda siliniyor. Şifreleme Direct Boot kurtarmasını bozar. Önerim değiştirmemek; risk belgelenmiş durumda (aydınlatma metni ve Data Safety taslağı).
6. **Çöküş penceresi:** Telecom kabul edip terminal durum yazılmadan süreç ölürse yeniden deneme mükerrer istek üretebilir. Kod bunu açıkça belgelemiş, giderilemez.

---

## 9. Test Evidence Report (commit `b2acaa5`, 2026-10-05)

| Kapı | Sonuç | Kanıt |
|---|---|---|
| `scripts/verify_release.sh` (6 adım) | **EXIT=0** | flutter clean + pub get → analyze "No issues found" → `flutter test --coverage` **+2079 All tests passed** + `CRITICAL_COVERAGE_PASS` → imzalı smoke AAB + `ANDROID_RELEASE_SURFACE_PASS` + jarsigner → `lintSmokeRelease` + `testPlayDebugUnitTest` + `assemblePlayDebugAndroidTest` → 16 KB hizalama → lisans/notices kapısı |
| Kotlin unit | **138 test, 0 hata, 0 atlama** | `build/app/test-results/testPlayDebugUnitTest/*.xml` |
| Secret taraması | **PASS**, 1160 metin dosyası, 0 bulgu | `scripts/scan_release_secrets.py --require-clean` |
| OSV | **PASS**, pub 195 + Maven 203 sorgu, bilinen bulgu yok | `scripts/audit_dependencies_osv.sh` |
| Canlı yasal URL'ler | **FAIL** (`terms_html`) | `scripts/verify_live_legal_urls.sh`; privacy ✓, aydınlatma ✓, data_deletion ✓ (elle sha256) |
| Merged release manifest | target 36 / min 29; izinler §9-tablo | `build/app/intermediates/merged_manifest/smokeRelease/...` |

**Sınır:** Smoke flavor'ı `.smoke` uygulama kimliği ve kapalı billing ile derleniyor. Play AAB'si değil, provenance kanıtı da değil. `play` flavor'ında farklı olan yalnızca boş flavor manifesti; bağımlılık kilidi `playReleaseRuntimeClasspath` için `[KESİN]`. Gerçek Play AAB'si `release.yml`'den alınmalı.

**İzin tablosu (merged release manifest):**

| İzin | Neden / özellik | Tür | Play riski | Kaldırılabilir mi |
|---|---|---|---|---|
| CALL_PHONE | Panik/Check-In/Safe Walk otomatik arama isteği | runtime | Düşük; kısıtlı Call Log grubunda değil | Hayır (çekirdek) |
| POST_NOTIFICATIONS | Fallback/uyarı bildirimi; arm ön koşulu | runtime (13+) | Yok | Hayır |
| SCHEDULE_EXACT_ALARM | Native son tarih; arm ön koşulu | özel erişim, kullanıcı verir | Uyumlu (R6) | Hayır |
| REQUEST_IGNORE_BATTERY_OPTIMIZATIONS | Aktif oturum güvenilirliği, isteğe bağlı | özel | "Safety app — Acceptable" (R7); inceleme sorusu olası | Hayır (önerilmez) |
| ACCESS_FINE / COARSE_LOCATION | Harita/konum oturumu (ön plan) | runtime | 2027 konum düğmesi (R8) | Fine → 2027 öncesi değerlendir |
| RECEIVE_BOOT_COMPLETED | Reboot reconcile | normal | Yok (FGS başlatmıyor) | Hayır |
| WAKE_LOCK | Oturum süresince wakelock | normal | Yok | Hayır |
| VIBRATE | Geri sayım haptiği | normal | Yok | — |
| INTERNET / ACCESS_NETWORK_STATE | Tile, billing, bağlantı kontrolü | normal | Yok | Hayır |
| com.android.vending.BILLING | Play Billing | normal | Yok | Hayır |
| `…DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION` | AndroidX otomatik | imza | Yok | — |
| Yok: USE_EXACT_ALARM, FOREGROUND_SERVICE*, USE_FULL_SCREEN_INTENT, READ_CONTACTS, AD_ID, ACCESS_BACKGROUND_LOCATION | | | | `[KESİN]` |

---

## 10. Physical Device Acceptance Matrix (doldurulacak — şu an 0/23)

**Cihazlar (minimum):**
- D1 Pixel/AOSP'e yakın, Android 15 veya 16
- D2 Samsung One UI, Android 14 veya 15
- D3 Xiaomi HyperOS
- D4 (varsa) Android 10 / API 29

Hepsinde gerçek SIM ve aramayı karşılayacak ikinci bir telefon olmalı.

**Her satıra yazılacaklar:** cihaz · OS · pil modu · uygulama durumu · exact alarm · bildirim · kilit · beklenen · gözlenen · zaman · log · P/F · commit · `dumpsys package … | grep lastUpdateTime`.

| # | Senaryo | Beklenen (kaynak) |
|---|---|---|
| 1 | Panik ön planda | 10 sn sonra arama isteği; ekranda bağlantı iddiası yok |
| 2 | Panik, ekran kilitli | Native alarm ile arama isteği |
| 3 | Panik, uygulama arka planda | Aynı |
| 4 | Panik, Flutter süreci öldürülmüş (`am kill`) | Receiver → `claimAndDispatch` |
| 5 | Panik + Doze (`dumpsys deviceidle force-idle`) | `setExactAndAllowWhileIdle` teslimi |
| 6 | Exact alarm izni kaldırılmış | Arm reddi (`exactAlarmDenied`) + yönlendirme |
| 7 | Bildirimler kapalı | Arm reddi (`notificationsDisabled`) |
| 8 | CALL_PHONE reddedilmiş | Arm reddi; manuel arama yolu |
| 9 | Geri sayım sırasında reboot | ≤5 dk ise LOCKED_BOOT'ta arama; >5 dk ise öneri bildirimi |
| 10 | Check-In normal süre dolumu | Grace uyarısı |
| 11 | Check-In grace dolumu | Arama isteği |
| 12 | Check-In PIN ile revizyon | Generation +1; eski alarm etkisiz |
| 13 | Safe Walk dolumu | Ön uyarı → grace → arama |
| 14 | Safe Walk PIN iptali | CANCELLED; arama yok |
| 15 | Quick Settings panik | 3 dk tazelik penceresi; entitlement kapısı |
| 16 | Widget panik | Aynı |
| 17 | Ses tuşu (ön plan) | Yalnız ön planda tetiklenir |
| 18 | Saat / saat dilimi değişikliği | Kalan süre elapsed'e göre korunur |
| 19 | Çift SIM ("her seferinde sor") | **Bilinmiyor**: SIM seçici davranışını kaydet |
| 20 | SIM yok / uçak modu / şebeke yok | Bağlantı iddiası yok; fallback bildirimi |
| 21 | Manuel dialer fallback | Bildirime dokununca tek seferlik hedef tüketimi |
| 22 | Otomatik çağrı / dialer timeout yarışı | Kaydet (P1-8) |
| 23 | Force-stop | Alarm silinir; açılışta >5 dk ise öneri, arama yok |

Script'ler hazır: `scripts/phase3_physical_device_preflight.sh`, `scripts/native_doze_dispatch_probe.sh`, `docs/audit/telefon-testi-protokolu-2026-09-14.md`.

---

## 11. Google Play Console Preparation Sheet

| Alan | Beklenen yanıt | Kanıt | Sahip işlemi | Bilinmeyen |
|---|---|---|---|---|
| Privacy policy | `https://poyrazoncel34-netizen.github.io/guvenlik_app/privacy_policy.html` | Canlı = repo (sha256 PASS) | URL'yi gir | — |
| Data Safety | §12 | Kod + R11 + Play Help 10787469 | Formu doldur | — |
| Ads | Reklam yok | Ads SDK yok | "No" | — |
| App access | "Some functionality restricted" + `store/PLAY_REVIEWER_ACCESS_NOTES.md` | Dosya hazır | Promo kod veya license tester | Promo kod |
| Target audience | 18+ (Families'e girme) | Onay ekranı 18+ | Seç | — |
| Content rating | `store/CONTENT_RATING_ANSWERS.md` | Dosya | Anketi gönder | P2-8 |
| Sensitive permissions | SCHEDULE_EXACT_ALARM için form beklenmez; Console form gösterirse doldur. FGS beyanı **olmamalı** (eski specialUse taslağı varsa sil) | Manifest | Kontrol et | Console'un neyi soracağı `[BİLİNMEYEN]` |
| Account deletion | Hesap oluşturma yok → "No" | Login yok `[KESİN]` | Seç | — |
| Health apps | Sağlık özelliği yok | Tıbbi profil kaldırıldı (`user_data_export_medical_removed_test`) | "No health features" | — |
| Financial features | Yok | — | "None" | — |
| News / Government / COVID | Hayır | — | — | — |
| Advertising ID | Kullanılmıyor | AD_ID izni yok, RC device-id toplama kapalı | "No" | — |
| Location | Ön plan; arka plan yok | Manifest | — | — |
| Subscription | Ürün/base plan/fiyat/trial | — | Console + RC | `[BİLİNMEYEN]` |
| Countries / pricing | TR (yalnız Türkçe listing) | localeFilters `tr` | Seç | Diğer ülkeler |
| Testing tracks | Internal → Closed (≥12, 14 gün) | R4 | Kur | Başlangıç tarihi |
| Production access | 14 gün sonrası başvuru | R4 | Başvur | İnceleme süresi |
| Developer verification / package registration | Tamam olmalı | R3 | Doğrula | `[BİLİNMEYEN]` |
| Play App Signing | Kayıtlı olmalı; `release.yml` `EXPECTED_PLAY_APP_SIGNING_CERT_SHA256` bekliyor | Workflow | App integrity ekranı | `[BİLİNMEYEN]` |
| Pre-launch report | Çalıştır; FLAG_SECURE yüzünden görseller siyah, PIN ve onay ekranı crawler'ı durdurur. **Telefon güvenilirliğini kanıtlamaz.** | MainActivity | Sonuçları oku | — |

---

## 12. Data Safety Draft

Toplama (collection) = cihaz dışına aktarım, SDK'lar dahil. Yalnız cihazda kalan veri beyan edilmez.

| Veri türü | Collected | Shared | Ephemeral | Zorunlu | Amaç | Kaynak | Kanıt / not |
|---|---|---|---|---|---|---|---|
| Financial info → **Purchase history** | **Evet** | Hayır (RC hizmet sağlayıcı) | Hayır | Zorunlu (Pro satın alanlar için) | App functionality, Analytics | RevenueCat / Play Billing | R11 `[KESİN]` |
| Device or other IDs | Önerim: **beyan etme** | — | — | — | — | RC anonim ID | RC: yalnız reklam-ID entegrasyonunda; device-id toplama kapalı `[KESİN]`. Muhafazakâr seçenek sahip kararı. |
| Location → Approximate location | **Evet** | **Evet** (OpenStreetMap karo sağlayıcısı) | Hayır | İsteğe bağlı (harita) | App functionality | OSM tile istekleri | Karar 2026-10-06, tablo altındaki not |
| Location → Precise location | **Evet** | **Evet** (aynı) | Hayır | İsteğe bağlı (harita) | App functionality | OSM tile istekleri | lat/lng cihazı terk etmiyor `[KESİN]`. Ancak harita GPS konumuna `initialZoom: 15.0` ve `zoom = 16.0` ile merkezleniyor (`map_page.dart:149,513`). z15 karosunun kenarı Türkiye enleminde ≈ 0,9 km. İstenen karo kümesi konumu ≈ 1 km²'ye daraltıyor; Google'ın precise eşiği < 3 km² |
| Contacts / Phone number | Hayır | — | — | — | — | — | Yerel; arama Android Telecom'a gidiyor, geliştiriciye değil |
| Personal info (ad, profil) | Hayır | — | — | — | — | — | Yerel |
| Photos | Hayır | — | — | — | — | — | Avatar yerel |
| Crash logs / Diagnostics / App activity | Hayır | — | — | — | — | — | Uzak raporlama yok; RC `diagnosticsEnabled=false` |
| Security practices | Aktarımda şifreleme: RC/Play/OSM HTTPS (`usesCleartextTraffic=false`); silme talebi: yerel silme + `data_deletion.html` | | | | | | |

**Harita kararı (2026-10-06).** Birincil kaynak: [Play Console Help 10787469](https://support.google.com/googleplay/android-developer/answer/10787469).
- Google'a göre "collect", verinin cihaz dışına aktarılmasıdır. Alıcının geliştirici ya da üçüncü taraf sunucu olması fark etmez. Approximate ≥ 3 km², precise < 3 km².
- Sharing istisnaları: hizmet sağlayıcı, hukuki zorunluluk, kullanıcı eylemi ya da belirgin uygulama içi açıklama + rıza, anonim veri.
- OSMF sözleşmeli bir hizmet sağlayıcı değil; kendi gizlilik politikası olan bağımsız bir taraf.
- Rıza istisnası teoride mümkün: konum açık rızası (`LocationConsentGate`) ve aydınlatmadaki "Harita ağı" satırı var. Ama KVKK onay ekranı hukukçu incelemesinde (P1-1), bu yüzden istisnaya dayanılmadı. **Shared = Evet.** Fazla beyan politika ihlali sayılmaz; eksik beyan sayılır.
- Ephemeral = Hayır, çünkü OSMF istekleri logluyor (R13).
- IP ayrı tür olarak beyan edilmez: geliştirici IP'den konum çıkarmıyor (aynı sayfa, IP maddesi).
- `store/DATA_SAFETY_FORM.md`'deki "Conservative disclosure needed" satırı bu yanıtlarla karşılanıyor.
- Hukukçu onay tasarımını kabul ederse "Shared" istisnası production sonrası yeniden değerlendirilebilir.

---

## 13. Privacy / KVKK Gap Report

| Konu | Gerçek | Boşluk | Durum |
|---|---|---|---|
| Aydınlatma / açık rıza ayrımı (2026/347) | Ayrı başlık ve ayrı kutular var, ama hepsi tek ekranda ve tek "Devam" ile kaydediliyor | Yapısal olarak kısmen uyumlu `[GÜÇLÜ ÇIKARIM]` | Hukukçu |
| Aydınlatma için onay istenmesi | Kutu metni "okudum … anladım" (geri bildirim, izinli); kayıtta `grantConsent(typeKvkk)` | Kayıt semantiği yanlış ("rıza" olarak yazılıyor) | P1-1 |
| Başka şart varken açık rıza | Acil kişi saklama (hizmetin ifası) açık rızaya bağlı ve çekirdek akışı kapılıyor | Kararın 3. ilkesiyle çelişme riski `[GÜÇLÜ ÇIKARIM]` | P1-1 |
| Yaş beyanı | "rızanızın geçerliliği için" | Yaşı rızaya bağlıyor | P1-1 |
| Yurt dışı aktarım | RevenueCat ABD, OSMF UK/NL + CDN | Mekanizma belgesi yok | P1-2 `[BİLİNMEYEN — hukukçu]` |
| Gizlilik politikası ↔ davranış | Kişiler, PIN, timeline, avatar, abonelik, harita, device-protected hedef, yerel silme anlatılmış | §15 belirsiz; OSMF IP + tile koordinatı yalnız aydınlatmada | P1-5 |
| Canlı URL | Privacy ✓, aydınlatma ✓, silme ✓; **Şartlar ✗** | — | P1-3 |
| Hesap silme | Hesap yok → Play hesap silme şartı uygulanmaz `[KESİN]`. Yerel "tüm verileri sil" var: `app_reset_service.dart` + native `wipe()` (CLAIMED iken `TOO_LATE`). | — | ✓ |
| Üçüncü kişi verisi | Acil kişinin adı/numarası (kullanıcı başkasının verisini giriyor) | Hukuki dayanak ve aydınlatma | Hukukçu |
| Cihaz-içi işleme ve veri sorumluluğu | Veri çoğunlukla cihazda kalıyor | Geliştiricinin bu veri için veri sorumlusu sayılıp sayılmadığı `[BİLİNMEYEN — hukukçu]` | Hukukçu |

---

## 14. RevenueCat / Subscription Launch Checklist (sahip tarafı)

- [ ] Production Android API key (`goog_…`) GitHub secret'ında (Gradle ve Dart `test_`/`sk_`/placeholder anahtarı reddediyor `[KESİN]`)
- [ ] Play'de abonelik ürünü + base plan(lar) aktif; fiyat, trial ve teklif `[BİLİNMEYEN]`
- [ ] RC entitlement kimliği **tam olarak** `KoruBeni Pro` (boşluk ve büyük harf dahil) `[KESİN]` kod beklentisi
- [ ] RC offering ↔ package ↔ ürün eşlemesi
- [ ] RC'de Play service credentials (purchase doğrulama) ve RTDN (iptal/geri ödeme olayları için önerilir)
- [ ] License tester hesabıyla closed/internal track'ten (sideload değil) gerçek sandbox satın alma → Panik açılıyor
- [ ] Süre dolumu / iptal / iade → Pro kapanıyor (UI ve `SubscriptionGate` aynı durumu gösteriyor)
- [ ] Restore (ikinci cihaz, yeniden kurulum; anonim ID olduğu için Play hesabı üzerinden)
- [ ] Çevrimdışı açılışta doğrulanmış-Pro davranışı (mevcut anchor politikası) cihazda gözlendi
- [ ] Uygulamada "Aboneliği Google Play'de yönet" linki çalışıyor `[KESİN]` link var

---

## 15. Store Listing Claims Guardrail

**Mevcut kanonik metin** (`store/PLAY_CONSOLE_COPY_PASTE_PACK.md` §2) taranınca yasaklı iddia bulunmadı `[KESİN]`. "112 otomatik", "acil servisle bağlantı", "tüm kişiler", "konum paylaşır", "arama bağlandı", "her koşulda", "telefon kapalıyken", "garanti" ifadelerinin hiçbiri yok. "112'nin yerine geçmez" uyarısı mevcut.

**Eklenmesi önerilen sınır cümleleri** (eksik):
1. "Panik yalnızca seçtiğiniz **birincil** acil kişiye arama isteği gönderir; 112'yi veya diğer kişileri aramaz."
2. "Uygulama, aramanın karşı tarafça cevaplanıp cevaplanmadığını bilemez."
3. "Otomatik özellikler Android izinlerine bağlıdır: Telefon, Bildirimler ve Alarmlar ve hatırlatıcılar. İzin yoksa Panik başlatılmaz."
4. "Güvenli Yürüyüş konum paylaşmaz."

**Düzeltilecek:** "Acil kişi kayıtları için cihaz içi yerel veritabanı" → "cihaz içi güvenli depolama".

---

## 16. Release / Rollback Limitations

- Play bir sürümü geri alamaz. Yapılabilecek şey staged rollout'u durdurmak ve daha yüksek `versionCode` ile ileri sürmek. `versionCode` tag'den türüyor (`MAJOR*10000+MINOR*100+PATCH`); sıradaki `v1.0.3` → 10003.
- Uzak kill-switch yok `[KESİN]`. Rollout'u durdurmak, cihazda kurulu sürümü devre dışı bırakmaz. Kill-switch eklemek acil yola ağ bağımlılığı getirir; önermiyorum.
- Tile sağlayıcı değişimi yeni sürüm ister.
- Durdurma eşikleri ve kademeler: `docs/release/incident_runbook.md` §2, `store/PRODUCTION_ROLLOUT_RUNBOOK.md`.

---

## 17. Earliest Safe Launch Critical Path

Süreler tahmin aralığıdır, garanti değildir.

| Sıra | Adım | Sahip | Bağımlılık | Effort | Tamamlanma kanıtı |
|---|---|---|---|---|---|
| 1 | Push onayı → `main` + dal push; CI yeşil; Pages yeniden deploy | Developer (onay: sahip) | — | 0,5–1 gün | `ci.yml` yeşil; `verify_live_legal_urls.sh` PASS |
| 2 | Paket kaydı + geliştirici doğrulaması + Play App Signing kontrolü | Play Console sahibi | — | 0,5 gün | Console ekranları |
| 3 | KVKK hukukçu görüşü (P1-1, P1-2, P1-5) | Hukukçu | — (paralel) | 3–10 gün `[BİLİNMEYEN]` | Yazılı görüş |
| 4 | Doc düzeltmeleri (Data Safety tablosu, mağaza sınır cümleleri) | Developer | Onay | 0,5 gün | Policy testleri yeşil |
| 5 | `v1.0.3` tag → `release.yml` AAB → internal → closed track | Developer + Console sahibi | 1, 2, 4 | 1 gün | Artefakt + provenance + track |
| 6 | App content formları (§11, §12) | Console sahibi | 4 | 0,5–1 gün | Console "complete" |
| 7 | 12 tester opt-in → 14 gün sayacı | Console sahibi | 5, 6 | **14 gün (sabit)** | Opt-in tarihi |
| 8 | Fiziksel cihaz matrisi (§10), closed-track build ile | Cihaz testçisi | 5 | 3–7 gün (7 içinde paralel) | `docs/audit/` kaydı |
| 9 | Billing sandbox (§14) | RC + Console sahibi | 5 | 1–2 gün (7 içinde) | RC event log |
| 10 | Hukukçu değişiklik isterse: kod + `bump_legal.sh` + yeni tag | Developer | 3 | 1–3 gün | Yeni AAB; tester'lar yeniden opt-in gerekmez |
| 11 | Production erişim başvurusu | Console sahibi | 7 | inceleme `[BİLİNMEYEN]` | Erişim verildi |
| 12 | Production staged rollout 1%→… | Console sahibi | 8, 9, 11, hukukçu | — | Vitals |

- **Senaryo A** (12×14 geçerli, 2026-07-23 notuna göre muhtemel): 1–6 adımları ~7 Eki'ye kadar biterse 14 günlük sayaç en erken ~21 Eki'de dolar. Üstüne production erişim incelemesi eklenir: **en erken production ≈ 2026-10-22…10-31.** Fiziksel test veya hukukçu bir bulgu çıkarırsa yeni sürüm 14 günlük pencerenin içinde yapılabilir; sayaç sıfırlanmaz.
- **Senaryo B** (şart uygulanmıyor): adım 8, 9 ve 3 bitince, **en erken ≈ 1–2 hafta.**

---

## 18. Final Hard-Gate Checklist

| Kapı | Durum |
|---|---|
| Release build başarılı (smoke, yerel) | ✅ `[KESİN]` |
| Production Play AAB (`release.yml`) | ❌ yok (P0-1) |
| Target API 36 | ✅ |
| Billing ≥ PBL 8 | ✅ 8.3.0 |
| Production RevenueCat yapılandırması | ❓ |
| Gerçek sandbox satın alma | ❌ |
| Restore / iptal / süre dolumu | ❌ |
| Emergency unit/native testleri | ✅ 2079 Dart + 138 Kotlin |
| Panik fiziksel cihaz kabulü | ❌ |
| Reboot / kilit / Doze kabulü (fiziksel) | ❌ (yalnız emülatör) |
| Manifest izinleri gerekçeli | ✅ §9 |
| Exact alarm politika uyumu | ✅ SCHEDULE_EXACT_ALARM |
| Data Safety ↔ SDK davranışı | ⚠️ alan bazlı yanıtlar hazır, harita kararı verildi (§12); Console'a giriş bekliyor |
| Privacy policy ↔ veri akışı | ⚠️ §15 belirsiz |
| KVKK kritik uyumsuzluk yok veya hukukçu kabulü | ❌ hukukçu bekleniyor |
| Store listing gerçek dışı iddia yok | ✅ (sınır cümleleri önerilir) |
| Developer verification / paket kaydı | ❓ |
| Closed test / production erişimi | ❓ |
| App Content alanları | ❓ |

---

## 19. Things Still Needed From Owner

1. Push izni (`main` ve bu dal): kodun tek kopyası bu dizüstünde.
2. Play hesabı hâlâ kişisel mi? Kapalı test başladı mı, kaç tester, hangi tarihte?
3. Paket kaydı ve geliştirici doğrulaması Console'da "tamam" mı? Play App Signing kayıtlı mı?
4. RevenueCat: entitlement ve offering eşlemesi, production `goog_` anahtarı secret'ta mı, service credentials ve RTDN durumu.
5. Play abonelik ürünleri, base plan, fiyat, trial.
6. Fiziksel test cihazları (Pixel / Samsung / Xiaomi), SIM'ler ve ikinci telefon mevcut mu?
7. KVKK hukukçusu var mı? Yurt dışı aktarım mekanizması için görüş alındı mı?
8. ~~Harita tile verisinin Data Safety beyanı~~ — 2026-10-06'da karar verildi (§12): Approximate + Precise location, Collected + Shared. Yalnız Console'a girilmesi kalıyor.
9. Bilinen dialer yarışı (P1-8) ve fail-closed arm (P1-9) semantiğinin açıkça kabulü.
10. Console'daki uygulama adı ve kategorisi; yeni ekran görüntüleri.
