# KORUBENİ — PRODUCTION SECURITY AUDIT

**Tarih:** 2026-10-01 · **Denetim modu:** salt-okunur

Denetim sırasında hiçbir production dosyası değiştirilmedi. Düzeltmeler denetimden SONRA,
madde madde onay alınarak uygulandı ve aşağıdaki tabloda commit'leriyle kayıtlıdır.

## Bulgu durumları

| ID | Severity | Durum | Kayıt |
|---|---|---|---|
| F-01 | MEDIUM | **KAPANDI** | `af24a4d` — fix(security): kilit ekrani sayac yazma hatasinda fail-closed |
| F-02 | MEDIUM | **KABUL EDİLEN RİSK** | §3 F-02 → "Kabul kararı" |
| F-03 | MEDIUM | **UYGULANDI — CİHAZDA DOĞRULANMADI** | feat(security): ortusme (tapjacking) dokunus politikasi — uyar/engelle ayrımı; §3 F-03 → "Uygulama" |
| F-04 | LOW | **KAPANDI** | `26d09dc` — fix(reliability): quick-access panik istegine tazelik penceresi (3 dk, monotonik saat) |
| F-05 | LOW | AÇIK | — |
| F-06 | INFO | AÇIK (Aşama 4'e taşındı) | `safe_device` kaldırma yedi lisans/SBOM kapısını yeniden üretmeyi gerektiriyor; `verify_release.sh` adımıyla birlikte yapılacak |
| F-07 | INFO | **SABITLENDI** | `9fb7138` — yüzey silinmedi; hiçbir çağırıcının geçmediği bir tel tuzak testiyle pinlendi |
| F-08 | INFO | **KAPANDI** | Kanıtlar commit edildi; `verify_release.sh` 5/5 yeşil, imzalı secret-scan ve OSV artefaktları üretildi (§7) |
| F-09 | INFO | **KAPANDI** | Denetim değil, düzeltme sırasında bulundu. §3 F-09 |

Bu belge `config/absence_claims.json`'a kayıtlı **değildir**. O kayıt defteri `MP-xxx` audit
satır kimlikleriyle anahtarlanmıştır ve `PRODUCTION_AUDIT.md` satırlarına bağlıdır; bu rapor
bir audit satırı olmadığı için oraya kayıt açmak uydurma bir satır kimliği üretmek olurdu.
Buradaki yokluk iddialarının her biri §2'de kendi doğrulama komutuyla verilmiştir.

## 0. Denetim tabanı

| | |
|---|---|
| Branch | `codex/evidence-remediation-20260911` |
| Denetlenen HEAD | `69c2ecdbb51b2ab4dec9efec6959a7ee021ea8fe` |
| İzlenen dosyalarda değişiklik | yok |
| İzlenmeyen | 118 dosya, tamamı `docs/audit/evidence/` altında kanıt |
| `git diff --check` | temiz (exit 0) |
| `flutter analyze --no-fatal-infos` | No issues found |
| `flutter test --no-pub` | All tests passed (2040 test; F-01 düzeltmesinden sonra 2043) |

Kod hacmi: 173 Dart dosyası, ~35 odaklı servis, 41 Kotlin production dosyası.

## 1. Mimari envanter — uygulanabilirlik bayrakları

```
BACKEND_PRESENT=NO            geliştirici backend'i yok
REMOTE_API_PRESENT=PARTIAL    kendi API'si yok. Üçüncü taraf: tile.openstreetmap.org,
                              RevenueCat/Play Billing. Acil yolda ağ yok.
WEBVIEW_PRESENT=NO            webview_flutter / InAppWebView / WebView yok
COOKIE_SESSION_PRESENT=NO     cookie/oturum yok; url_launcher harici tarayıcıya devrediyor
LOCAL_DATABASE_PRESENT=YES    sqflite, databaseVersion=3, 4 tablo
FILE_UPLOAD_PRESENT=NO        sunucuya upload yok
FILE_EXPORT_PRESENT=YES       KVKK veri taşınabilirliği: JSON export + share_plus
```

Kanal sınırları: 10 MethodChannel + 2 EventChannel, tamamı aynı süreç içi Flutter embedder
sınırı (IPC değil). Gerçek dış sınırlar: exported `MainActivity` (launcher + `korubeni://`
VIEW filtresi), exported `PanicTileService` (`BIND_QUICK_SETTINGS_TILE` ile korunmuş) ve 7
app-private receiver.

## 2. Checklist sonuçları

```
AUTHENTICATION=PASS                 AUTHORIZATION=PARTIAL
INPUT_VALIDATION=PASS               SQL_INJECTION=PASS
XSS=NOT_APPLICABLE                  CSRF=NOT_APPLICABLE
CORS=NOT_APPLICABLE                 HTTPS=PASS
SECURE_COOKIES=NOT_APPLICABLE       RATE_LIMITING=PARTIAL
IDOR=NOT_APPLICABLE                 SECRET_MANAGEMENT=PASS
FILE_UPLOAD_VALIDATION=NOT_APPLICABLE
GLOBAL_EXCEPTION_HANDLING=PASS      SECURITY_HEADERS=NOT_APPLICABLE
LOGGING_AUDIT=PASS                  DEPENDENCY_SCANNING=PASS
DATABASE_SECURITY=PARTIAL           BACKUP_SECURITY=PASS
CICD_SECURITY=PASS                  MOBILE_ANDROID_SECURITY=PARTIAL
```

### AUTHENTICATION = PASS

Yerel PIN; biyometri yok. `local_auth` ne `pubspec.lock`'ta ne kodda — duress modeli
korunuyor (CLAUDE.md kural 2).

PIN at-rest plaintext değil: `lib/core/security/pin_hasher.dart` PBKDF2-HMAC-SHA256, 100k
iterasyon, `Random.secure()` 16-byte salt, 32-byte key, uzunluk-bağımsız sabit-zaman
karşılaştırma. Bozuk kayıt exception değil `false` döndürüyor — kilit ekranında
yakalanmamış hata olmuyor. Legacy plaintext tek yönlü migrate ediliyor ve
SharedPreferences kopyası siliniyor.

Okunamayan secure storage absent'a düşürülmüyor: `PinState.readFailed` ayrı bir durum ve
mutasyon `M03_PIN_READ_FAILURE_AS_ABSENT` bunu kalıcı olarak sınıyor.

Bypass yüzeyleri kapalı:
- Deep link modeli arm/dial/unlock **ifade edemiyor** — `AppDestination` enum'unda böyle bir
  hedef yok. Park edilen hedef yalnız `MainNavigation` tarafından, yani consent → onboarding
  → PIN kapısından sonra tüketiliyor.
- Quick-access artık exported `MainActivity` intent'inden okunmuyor;
  `QuickPanicTrampolineActivity` `exported="false"`. Kaynak yorumu cihaz doğrulamasını da
  kaydediyor: `Activity.launchedFromUid` bu noktada -1 döndüğü için UID kontrolü kullanılabilir
  bir savunma değil.

### AUTHORIZATION = PARTIAL — güvenlik sınırı değil, bilinçli ürün kararı

Tek kural `SubscriptionGate.isAuthorized`. panic / safeWalk / checkIn / volumeTrigger
"emergency-capable" olarak sınırsız offline entitlement, diğer ücretli özellikler sınırlı
grace alıyor. Merkezileştirme gerçek: UI kilit badge'leri, panik butonu ve quick-access host
aynı fonksiyonu çağırıyor.

Backend olmadığı için entitlement client-side'dır ve rooted bir cihazda kaçınılmaz olarak
bypass edilebilir. Bu bir **gelir bütünlüğü** riski, kullanıcı verisi riski değil: bypass
eden kişi yalnız kendi cihazındaki kendi özelliğini açar, başka kullanıcının verisine yol
yoktur (çok kullanıcılı nesne modeli hiç yok). Bypass'ın maliyetini F-05 düşürüyor.

Saat manipülasyonu düşünülmüş: ileri tarihli anchor "rolled-back clock veya tampered store"
sayılıp süresi dolmuş kabul ediliyor; asimetri bilinçli — yanlış saat doğrulanmış bir aboneden
SOS'u almamalı.

### INPUT_VALIDATION = PASS

En kritik sink telefon numarası ve **çift taraflı** doğrulanıyor:
`AndroidIntentService.normalizedCallableOrNull` (Dart) ile `EmergencyTargetValidator` (Kotlin)
aynı kuralı bağımsız uyguluyor — yalnız ASCII rakam + tek baştaki `+`, 7-15 hane, `' - ( ) .`
biçimlendirme. URI, MMI/USSD komutu, `,`/`;` pause-wait dizisi, dahili numara ve Unicode
rakam reddediliyor. Bu gerçek bir dial-string/USSD injection savunmasıdır.

Deep link: 512 bayt sınırı iki tarafta (Kotlin `DEEP_LINK_MAX_LENGTH`, Dart
`DeepLinkChannel.maxLength`), sabit scheme+host, tek path segmenti, destination allowlist,
parametre başına regex kuralı (`^[A-Za-z0-9_-]{1,64}$`), bilinmeyen parametre = red.

Platform kanalı dönüşleri strict parse ediliyor: `DeviceSecurityService.parse` bilinmeyen
değerde `null`, `QuickPanicRequestService._sourceFrom` tanınmayan etiketi atıyor.

### SQL_INJECTION = PASS

`where:` içinde string interpolasyonu yok (`grep -rn "where:" lib | grep '\$'` → 0 eşleşme).
4 dinamik SQL noktasının tamamında interpolasyon yalnız derleme-zamanı sabiti:

| Yer | Dinamik kısım | Kaynağı |
|---|---|---|
| `activity_service.dart:65` | retention limiti | `?` ile bağlı |
| `local_database_service.dart:146,153` | tablo/kolon adı | kod içi `Map` sabiti |
| `database_integrity_service.dart:147` | pragma adı | enum (`quick_check`/`integrity_check`) |

Kullanıcı kontrollü hiçbir değer SQL metnine girmiyor.

### XSS / CSRF / CORS / SECURE_COOKIES = NOT_APPLICABLE_WITH_REASON

HTML render eden hiçbir yüzey yok: WebView paketi yok, Markdown→HTML yok, yasal metinler
`url_launcher` ile **harici** tarayıcıya açılıyor. Native Flutter `Text` widget'ı XSS yüzeyi
değildir; yanlış pozitif üretmiyorum.

Cookie/oturum yok, state-changing authenticated endpoint yok → klasik CSRF'in öznesi yok.
Uygulamanın kontrol ettiği bir origin olmadığı için CORS politikası da yok; native Flutter
client için CORS'un tarayıcı güvenlik sınırı olmadığı ayrıca geçerli.

### HTTPS = PASS

`usesCleartextTraffic="false"` + `network_security_config.xml` içinde
`<base-config cleartextTrafficPermitted="false"/>`. `lib/` içinde tek bir `http://` literali
yok. TLS bypass yok: `badCertificateCallback`, custom `TrustManager`, `HostnameVerifier` —
hiçbiri mevcut değil.

Tile client host'u sabitliyor (`osm_tile_cache_client.dart:461`:
`scheme != 'https' || host != 'tile.openstreetmap.org'` → red) ve yanıt boyutunu sınırlıyor
(`OSM_TILE_RESPONSE_TOO_LARGE`). `MAP_TILE_URL_TEMPLATE` bir `--dart-define`; release
başlangıcında `isSafeMapTileUrlTemplate` ile HTTPS olarak doğrulanıyor.

### RATE_LIMITING = PARTIAL

PIN brute-force: 5. hatada 30s, sonra ikiye katlanarak 15 dakikada tavan. Tavan bilinçli —
sınırsız katlama 20 hatada ~11 güne çıkıyor ve ~44 hatada taşıp kilidi tamamen devre dışı
bırakıyordu. 15 dk tavanda 4 haneli uzay pratikte korunuyor.

`SafetySessionPinGate` denemeyi **karşılaştırmadan önce** düşüyor ve düşemezse eylemi
tamamen reddediyor — doğru fail-closed. `AppUnlockScreen`'deki asimetri F-01 ile kapatıldı.

Açık kalan: emergency trigger spam'i için debounce/cooldown yok (F-04 ile aynı dosya ailesi).

### IDOR = NOT_APPLICABLE_WITH_REASON

Remote çok kullanıcılı kaynak modeli yok; erişilebilecek "başka kullanıcının nesnesi" mevcut
değil. Mobil muadili ayrıca incelendi: exported yüzey yalnız `MainActivity` ve
`PanicTileService`. Diğer 7 receiver + `EmergencyFallbackDialActivity` +
`QuickPanicTrampolineActivity` `exported="false"`. `ContentProvider`/`FileProvider`
uygulama tarafından hiç tanımlanmamış.

### SECRET_MANAGEMENT = PASS

Hiçbir `.jks`, `.keystore`, `key.properties`, `.env`, `local.properties`, `.p12`, `.p8`
dosyası **tüm geçmişte bir kez bile** commit edilmemiş:
`git log --all --diff-filter=A --name-only` taraması boş.

5.269 blob'luk tam geçmiş taramasında secret-şekilli tek eşleşme sınıfı `storePassword=` ve
tamamı placeholder veya env referansı:

```
storePassword=$CI_STORE_PASSWORD
storePassword=$STORE_PASSWORD
storePassword=${{ secrets.STORE_PASSWORD }}
storePassword=BURAYA_KEYSTORE_SIFRENI_YAZ
storePassword=XXXX
storePassword=YOUR_KEYSTORE_PASSWORD
storePassword=ci_store_password
```

`ci_store_password` (6d00076, f159215) CI'ın `keytool -validity 1` ile o koşumda ürettiği
atılabilir anahtarın şifresidir; yayınlanan hiçbir artefaktı imzalamıyor → INFO.

`goog_*` eşleşmeleri yalnız iki test fixture'ı. Gradle, Play release'de `goog_` public SDK
key zorunlu kılıyor ve `sk_`, `test_`, `placeholder`, `dummy`, `non_release_smoke`
değerlerini reddediyor (`android/app/build.gradle.kts`) — public mobil SDK key ile gerçek
secret doğru ayrılmış.

### FILE_UPLOAD_VALIDATION = NOT_APPLICABLE_WITH_REASON

Sunucuya upload yok. Muadil import/export yüzeyi ayrıca incelendi ve temiz:

- `ImageSanitizerService` kullanıcı fotoğrafını ham piksele decode edip **yeni** bir görüntü
  olarak encode ediyor; EXIF/XMP/PNG-text yapısal olarak devralınamıyor. Blocklist değil,
  yapısal garanti. Kaynak EXIF yönü ham baytlardan okunup piksellere uygulanıyor.
- `SensitiveTempFileService` kendi export dosyasını **ve** share_plus'ın cache kopyasını
  siliyor, ayrıca startup'ta eskimişleri süpürüyor.
- Export `SensitiveActionPinGate` arkasında; PIN varsa doğrulama isteniyor, okunamıyorsa
  "kilitli" sayılıyor (absent'a düşmüyor).

### GLOBAL_EXCEPTION_HANDLING = PASS

`FlutterError.onError` + `PlatformDispatcher.instance.onError` `installUnhandledErrorHandlers`
içinde kurulu. Release'de ham exception/stack sunulmuyor (`return isRelease` ile engine'in
yazdırması engelleniyor), yalnız allowlist'lenmiş kod kaydediliyor. `ErrorWidget.builder`
`runApp`'ten önce set ediliyor ve release'de exception metnini göstermiyor.

Güvenlik-duyarlı fail-open araması: `PinState.readFailed` hiçbir yerde absent'a düşmüyor;
`DeviceIntegrity` probe hatası `clean` değil `unknown` oluyor. Bulunan tek fail-open F-01
idi ve kapatıldı.

### SECURITY_HEADERS = NOT_APPLICABLE (platform-controlled)

Uygulamanın kontrol ettiği bir web yüzeyi yok. `store/*.html` ve gizlilik politikası GitHub
Pages static sayfaları: HSTS, `X-Content-Type-Options`, TLS GitHub tarafından yönetiliyor;
CSP/`frame-ancestors` meta-tag dışında repo'dan ayarlanamaz. Native Flutter UI için security
header uydurmuyorum.

### LOGGING_AUDIT = PASS

Release'de `debugPrint` `main.dart`'ta no-op'a çevriliyor; davranış
`test/main_release_logging_contract_test.dart` ile sözleşmeye bağlı. `lib/` içinde `print(`
yok.

Kalıcı diagnostics **yalnız allowlist'lenmiş enum kodu** kabul ediyor (`LocalErrorCode` /
`LocalWarningCode`); serbest metin API'si `info()` sadece `assert` içinde çalışıyor. Ek
savunma olarak `redactSensitive` telefon, koordinat, e-posta ve dosya yolu desenlerini
maskeliyor. `crash_logs` tablosuna da yalnız `code.wireCode` yazılıyor, `stack` sabit `null`.

Bildirim metinlerinde PII yok ve `VISIBILITY_PRIVATE` kullanılıyor — kilit ekranında hedef
numara görünmüyor. Timeline olayları çeviri anahtarlarından üretiliyor; tek kullanıcı
kontrollü alan plan notu (F-02).

### DEPENDENCY_SCANNING = PASS (kanıtlı)

Her iki katman tam-sürüm eşleşmesiyle OSV'ye sorguldu, 2026-10-01:

| Katman | Kaynak | Koordinat | Bulgu |
|---|---|---|---|
| Pub | `pubspec.lock` (hosted) | 96 | **0** |
| Maven | `android/app/gradle.lockfile` (playReleaseRuntimeClasspath) | 203 | **0** |

Lockfile otoritatif: `android/build.gradle.kts` içinde
`dependencyLocking { lockAllConfigurations() }` — kilit dışına çıkan bir çözüm build'i kırar.
"Outdated" durumu vulnerability sayılmadı.

2026-10-02'de aynı kontrol deponun kendi zinciriyle tekrarlandı ve imzalı artefakt
üretildi: `OSV_EVIDENCE_PASS`, **196 Pub + 203 Maven** sorgu, findingCount=0 (§4b).
Pub sayısı yukarıdaki 96'dan farklıdır çünkü iki sayma farklı: benim elle koşumum
`pubspec.lock`'taki yalnız `hosted` paketleri sorguldu, deponun script'i çözümlenmiş
ağacın tamamını sorguluyor. İkisi de 0 bulgu verdi; otoritatif olan imzalı artefakttır.

Terk edilmiş/ölü bağımlılık: `safe_device` 1.3.10 pubspec'te duruyor ama runtime'da hiçbir
şey çağırmıyor (F-06).

**Kısıt:** repo'nun kendi `scripts/audit_dependencies_osv.sh` zinciri çalıştırılamadı.
`scripts/generate_osv_evidence.py` `--untracked-files=all` ile kirli ağaçta fail-closed
davranıyor ve ağaçta 118 izlenmeyen kanıt dosyası vardı. Doğru davranış; ama bu koşumda
imzalı kanıt artefaktı üretilmedi (F-08).

### DATABASE_SECURITY = PARTIAL

Mimari doğru ayrılmış:

| Veri | Yer | Not |
|---|---|---|
| PIN (hash) | `flutter_secure_storage` | Keystore destekli |
| Acil kişiler | `flutter_secure_storage` `emergency_contacts_v1` | Tek kaynak; legacy `contacts` tablosu BOŞ tutuluyor |
| KVKK rıza logu | plain `SharedPreferences` | Bilinçli: rıza kanıtı keystore sıfırlamasında hayatta kalmalı |
| `activity_events` | sqflite | Gerçek kullanıcı verisi |
| `crash_logs` | sqflite | 100 satır tavanlı, PII yok |

Migration'lar yalnız ekleyici (`ALTER TABLE ADD COLUMN` / `CREATE TABLE`); `activity_events`
gerçek kullanıcı verisi olduğu için drop-recreate yok. Idempotent `_addMissingColumns`
yarı uygulanmış upgrade'i kurtarıyor. `PRAGMA foreign_keys = ON` her bağlantıda.

Eksik: plan notu serbest metni şifresiz (F-02).

### BACKUP_SECURITY = PASS

`android:allowBackup="false"` + `android:fullBackupContent="false"` +
`dataExtractionRules`'ta **cloud-backup ve device-transfer'in ikisinde de** dokuz domain'in
hepsi (`root, file, database, sharedpref, external, device_root, device_file,
device_database, device_sharedpref`) `exclude path="."`.

Yani PIN hash'i, keystore verisi, acil kişiler, rıza logu, entitlement anchor'ı ve timeline
hiçbir yedek veya transfer kanalına girmiyor. Restore sonrası auth bypass, bayat oturum,
eski rıza veya silinmiş verinin dirilmesi mümkün değil.
`scripts/audit_android_release_surface.py` bu dokuz domain'i merged manifest üzerinde
fail-closed doğruluyor.

### CICD_SECURITY = PASS (repo'dan doğrulanabilen kısım)

5 workflow'un tamamında **her action tam SHA'ya pinlenmiş**. `pull_request_target` hiç
kullanılmıyor — untrusted PR + secrets kombinasyonu yok. Varsayılan
`permissions: contents: read`; yazma izni yalnız ihtiyaç duyulan job'da (`release.yml`:
`id-token: write`, `attestations: write`; `pages.yml`: `pages: write`).

Release `environment: production` arkasında ve yalnız `v*.*.*` tag'inde tetikleniyor.
`actions/attest-build-provenance` ile artefakt provenance'ı üretiliyor.

CodeQL kurulu ve kapsamı dürüstçe belgelenmiş: Dart analizörü **yok**, yani kapı satır
bazında ~%13'ü (Kotlin acil çekirdeği) görüyor; `build-mode: manual` olmadan bu fiilen 0
idi. Workflow'un kendi yorumu bunu PASS değil "kapsamı adıyla anılan bir satır" olarak
not ediyor — doğru tutum.

**UNVERIFIED_EXTERNAL:** branch protection kuralları, required reviewers, environment
approver'ları ve secret scanning / push protection ayarları repo kodundan doğrulanamaz;
GitHub dashboard gerektirir.

### MOBILE_ANDROID_SECURITY = PARTIAL

Doğrulanmış güçlü taraflar:

- **Exported yüzey minimal.** Tek eklenen exported bileşen `PanicTileService` ve
  `android:permission="android.permission.BIND_QUICK_SETTINGS_TILE"` ile korunmuş
  (signature-level; binder'ı sisteme kısıtlar). `PanicWidgetProvider` `exported="false"` —
  API 31+'ta `AppWidgetService` explicit component'e teslim ettiği için doğru.
- **PendingIntent'lerin tamamı `FLAG_IMMUTABLE`.** 6 üretim noktası; `FLAG_MUTABLE` hiç yok.
- **Intent spoofing kapatılmış.** Panic isteği exported launcher'ın intent extra'sından değil,
  exported olmayan trampoline'dan geliyor; üçüncü taraf uygulama geri sayım uyduramaz.
- **Bildirim aksiyonu yetkilendirilmiş.** `EmergencyFallbackDialActivity` token + TTL'i
  fail-closed doğruluyor, tek-tüketimli (`consumeFallbackTarget`), sonra `ACTION_DIAL`
  (ACTION_CALL değil) açıyor ve `catch (_: RuntimeException)` içinde **112 sentezlemiyor**.
- **Ekran sızıntısı kapalı.** Release'de pencere genelinde `FLAG_SECURE` + API 33+'ta
  `setRecentsScreenshotEnabled(false)`. Pencere geneli uygulanması bilinçli: per-screen liste
  bir unutulan route ile PIN pad'i sızdırır.
- **Root/integrity fail-open düzeltilmiş (A-017 kapandı).** `DeviceIntegrityProbe` her
  kontrolü found/absent/error olarak ayrı raporluyor; EACCES, başarısız `exec`, okunamayan
  mount tablosu artık "root yok" demiyor. Dart tarafı `error`'u asla `clean`'e çevirmiyor.
  `unknown`'da suçlayıcı dialog göstermemek duress modelinde bilinçli karar.
- **Clipboard sızıntısı yok** — F-07, yol fiilen ölü kod.
- **Boot/time/package receiver'ları** direct-boot aware, app-private, exception sınırları
  `EmergencyReceiverGuard` ve testleriyle kaplı.

Açık kalanlar: F-03 (tapjacking), F-04 (bayat quick-panic), F-05 (obfuscation kapalı).

**Doğrulanmamış:** `scripts/audit_android_release_surface.py` **merged** manifest üzerinde
çalışır ve bir release build gerektirir; bu denetimde kaynak manifest okundu, merged manifest
kapısı koşturulmadı. Dependency manifest'leri kaynak manifest incelendikten sonra izin ve
bileşen ekleyebilir, o yüzden bu gerçek bir boşluktur — `verify_release.sh` kapatır.

## 3. Bulgular

### F-01 — `AppUnlockScreen`'de sayaç yazma hatası kilidi sessizce devre dışı bırakıyordu — KAPANDI

```
Kategori   Authentication / brute-force koruması
Severity   MEDIUM
CWE        CWE-307, CWE-636
OWASP      MASVS-AUTH-2 / M4
Durum      KAPANDI — af24a4d
```

**Precondition:** secure storage okuması başarılı ama yazması başarısız. Cihaz depolamasının
doldurulması (ulaşılabilir) veya keystore commit hatasıyla oluşur.

**Attack path:** `app_unlock_screen.dart` yanlış PIN'de `registerFailure()`'ı `unawaited`
zincirinde çağırıyor ve hatayı yalnız `debugPrint` ile yutuyordu; release'de `debugPrint`
no-op. Yazma başarısız olursa `failedAttempts` artmaz, `_lockoutEndTime` null kalır,
`_onPinKey`'in `if (_isLockedOut) return;` kapısı hiç tetiklenmez. 10.000 kombinasyon
kilitlenmeden ve iz bırakmadan denenebilirdi. `PinVerificationService.verify()` lockout
servisine hiç danışmadığı için bu ekrandaki `_lockoutEndTime` tek uygulama noktasıdır.

**Kanıt (karşıtlık):** `lib/core/widgets/safety_session_pin_gate.dart` aynı problemi doğru
çözüyordu — denemeyi karşılaştırmadan önce düşüyor, düşemezse eylemi tamamen reddediyor.
Aynı repo, aynı sayaç, iki farklı politika; asıl brute-force yüzeyi gevşek olandı.
Mevcut `test/screens/unlock_lockout_fail_closed_test.dart` yalnız OKUMA hatasını kapsıyordu.

**Uygulanan düzeltme:** `registerFailure()` artık `await` ediliyor. Düşülemeyen deneme bir
temel backoff adımı (30s) kilit üretiyor ve yeni `pinLockoutRegisterFailed` koduyla
kaydediliyor. Sayaç akışı başlatılmıyor (hatayı zamanlayıcıya bağlamak anlamsız) ve ek
SnackBar gösterilmiyor — kilit bandı kalan süreyi zaten yazıyor, en yakın mevcut metin
(`pin_state_read_failed`) ise "PIN ile iptal kullanılamıyor" diyor ki burada yanlış olurdu.

**Reddedilen alternatif:** `SafetySessionPinGate` gibi karşılaştırmadan önce debit etmek.
O gate bir export veya sıfırlamayı koruyor, dolayısıyla eylemi reddetmek güvenli bir cevap.
Kilit ekranında karşılaştırmayı reddetmek, keystore'u yazamayan bir sahibi kendi güvenlik
uygulamasından **kalıcı olarak** kilitler; duress modelinde bu kendi başına bir zarardır.
Seçilen yol kurtarılabilir: doğru PIN hâlâ açıyor (doğrulama okur, yazmaz) ve
"PIN'imi unuttum" `_isLockedOut`'a bağlı değil.

**Regresyon kanıtı:** `test/screens/unlock_lockout_write_failure_test.dart` — iki catch
dalını da kapsıyor (`PlatformException`, gerçek flutter_secure_storage hatası; ve
`StateError`, `PinLockoutService.getState()`'in bozuk sayaç sinyali) + eşik altında
kilitlenmediğini doğrulayan negatif kontrol. `M07_LOCKOUT_WRITE_FAILURE_IGNORED` mutasyon
katalogda ve `test/safety_mutation_runner_contract_test.dart` tarafından pinlenmiş.
Mutant elle uygulandığında test kırıldı (`+2 -1`), geri yüklendiğinde 3/3 yeşil.

**Bilinen kural gerilimi:** `.claude/rules/dart/coding-style.md` "Never catch `Error`
subtypes" diyor; düzeltme `on StateError` yakalıyor. Aynı dosyadaki mevcut
`_syncLockoutState` zaten aynı şeyi yapıyor, çünkü `PinLockoutService.getState()` bozuk
sayaçta `StateError` **atmayı seçmiş** — bu bir programlama hatası sinyali değil, servisin
dokümante ettiği durum sinyali. Kalıcı doğru çözüm `getState()`'in kendi `Exception` tipini
atmasıdır; o değişiklik bu commit'in kapsamı dışında bırakıldı ve açık bir takip işidir.

### F-02 — Güvenlik planı serbest metni şifresiz yerelde — KABUL EDİLEN RİSK

```
Kategori   Data at rest / Database security
Severity   MEDIUM
CWE        CWE-312
OWASP      MASVS-STORAGE-1
Durum      KABUL EDİLEN RİSK (2026-10-01)
```

**Precondition:** root veya adli erişim. Release build `debuggable` değil ve
`allowBackup=false`, yani `adb backup` / `run-as` yolu kapalı.

**Attack path:** `safety_timeline_screen.dart` kullanıcının yazdığı `destination` ve plan
metnini `SharedPreferences`'ta `safety_timeline_notes` anahtarına JSON olarak, ayrıca
`activity_events.description` içine düz metin olarak yazıyor. Duress modelinde saldırganın
tam olarak aradığı bilgi: kullanıcının nereye gittiği veya gitmeyi planladığı. PIN ve acil
kişiler Keystore destekli secure storage'dayken bu alan düz dosyada.

**Kanıt:** `createSchema` → `activity_events.description TEXT NOT NULL`, şifreleme yok;
sqflite düz SQLite. `SecureStorageKeys` listesinde plan notu için anahtar yok. Timeline'ın
diğer tüm metinleri çeviri anahtarı; yalnız bu alan kullanıcı metni.

**Mevcut hafifletmeler:** Android sandbox; `allowBackup=false` + dataExtractionRules tam
dışlama; release'de pencere geneli `FLAG_SECURE`; `activity_events` retention sınırı;
timeline'a erişim PIN kapısının arkasında.

#### Kabul kararı

Bu yayın için **kabul edilen risk** olarak kaydedildi. Gerekçe:

1. Sömürü yolu uzaktan erişilebilir değil; root veya fiziksel adli çıkarma gerekiyor.
2. Yedek/transfer kanalları tamamen kapalı olduğu için sandbox dışına standart bir sızma
   yolu yok.
3. Düzeltme `activity_events` okuyan yüzeyleri etkiler ve mevcut notlar için bir migration
   gerektirir; `activity_events` gerçek kullanıcı verisi olduğundan bu değişikliğin kendi
   veri kaybı riski, kapattığı root-only riskten büyüktür.

**Bu bir "sandbox var, sorun yok" kararı değildir.** Verinin hassasiyeti kabul ediliyor ve
risk adıyla kayda geçiyor. İleride secure storage zarfına taşınması (acil kişilerin
`emergency_contacts_v1` deseni) doğru hedef olarak kalıyor; o iş yapıldığında
`activity_events.description` yalnız çeviri anahtarı taşımalı ve ham SQLite satırının
kullanıcı metnini içermediğini doğrulayan bir test eşlik etmeli.

**Gizlilik politikası sonucu:** Yerel kayıtların cihaz sandbox'ı ile korunduğu, root'lu bir
cihazda bu korumanın geçerli olmadığı dürüstçe ifade edilmeli; "uçtan uca şifreli" veya
"tüm veriler şifreli" türü bir iddia bu alan için doğru olmaz.

### F-03 — Tapjacking / overlay savunması yok — AÇIK

```
Kategori   Mobile / UI redressing
Severity   MEDIUM
CWE        CWE-1021
OWASP      MASVS-PLATFORM-3 / M1
Durum      AÇIK — kapsam kararı verildi, kod uygulanmadı
```

**Precondition:** cihaza overlay izni (`SYSTEM_ALERT_WINDOW`) olan bir uygulama kurulmuş
olmalı — duress modelinde tam olarak beklenen senaryo (partner tarafından kurulmuş
stalkerware).

**Attack path:** `setFilterTouchesWhenObscured` / `FLAG_WINDOW_IS_OBSCURED` kontrolü hiçbir
yerde yok (`grep -rn "filterTouchesWhenObscured\|FLAG_WINDOW_IS_OBSCURED\|obscured"` →
`lib/` ve `android/` içinde 0). Overlay, PIN pad'in üzerine sahte bir tuş takımı koyabilir
(PIN hasat) veya rıza / export / sıfırlama onayını gizleyerek kullanıcıyı farkında olmadığı
bir eyleme tıklatabilir. `FLAG_SECURE` ekran **yakalamayı** engelliyor, overlay'i
engellemiyor — farklı tehdit sınıfı.

**Kanıt:** `docs/` ve kök `*.md` içinde tapjacking hakkında alınmış hiçbir karar yok; yani
bu bilinçli bir takas değil, atlanmış bir yüzey.

#### Uygulama (2026-10-02)

Kapsam kararı korundu ama **davranış değişti**, ve bu değişiklik uygulamadan önce
bulunan bir yan etkiden doğdu.

`View.setFilterTouchesWhenObscured(true)` örtüşen dokunuşları **opaklık eşiği
olmadan** atar. Android 12+ güvenilmeyen dokunuşları kendisi de engelliyor ama
eşikli; yani bu bayrağı açmak platformdan **kesinlikle daha katı** ve bugün geçen
örtüşmeleri yarın engeller. Ulaştığı örtüşmeler ekran karartma ve mavi ışık
filtresi uygulamaları — yaygın olanlar. minSdk 29, yani API 29-30'da platform hiç
bir şey yapmıyor.

Sorun: kapsamdaki **PIN ekranı ve rıza akışı birer geçiş kapısı.** Orada dokunuş
atılırsa kullanıcı uygulamayı hiç açamaz — panik butonuna ulaşmak için bile — ve
"PIN'imi unuttum" da bir dokunuş olduğu için kaçış yolu yok.

Bu yüzden tek bir anahtar yerine iki politika uygulandı:

| Yüzey | Politika | Neden |
|---|---|---|
| Uygulama kilidi PIN ekranı | `warn` | Geçiş kapısı; kilitlenme kabul edilemez |
| Rıza akışı | `warn` | Geçiş kapısı; tamamlanmadan panik butonuna ulaşılamıyor |
| Veri export | `block` | Geçiş kapısı değil; reddetmek güvenli cevap |
| Yerel veri sıfırlama | `block` | Geçiş kapısı değil; örtüşme neyi onayladığını saklayabilir |

`warn` altında dokunuş geçer ve kullanıcıya "başka bir uygulama bu ekranın üstüne
çiziyor" denir — duress modelinde eyleme geçirilebilir bilgi. **İki politika da
rapor üretir**, yani `block` altında atılan dokunuş ölü bir düğme gibi görünmez;
sessiz reddetme bu projede kendi başına bir defekt.

**Acil yol hiç dokunulmadı:** `countdown_screen`, `panic_button`,
`safety_session_pin_gate` (silahlı oturum iptali) ve `emergency_trigger_host`
hiçbir politika taşımıyor; `test/screens/overlay_touch_policy_contract_test.dart`
bunu sabitliyor. İyi niyetli bir örtüşme (sohbet balonu, ses paneli) bir panik
basışını asla yutmamalı.

**Uygulama notları:**
- Kiralama modeli `ForegroundServiceOwnership` desenini izliyor: en güçlü canlı
  kiralama kazanır, bir diyalog kapanınca altındaki ekranın koruması düşmez.
- Sarmalayıcı widget yerine `State` mixin'i kullanıldı: `build` gövdelerini bir
  seviye içe almak ekran başına ~200 önceki satırı yeniden girintilerdi, ki bu depo
  o churn'ü açıkça reddediyor.
- Kanal hatası yutuluyor: koruma derinlik savunması, bir kullanıcının rıza ekranına
  veya PIN pad'ine ulaşamama nedeni olamaz.

**DOĞRULANMADI — ve bu bir eksik, kapatılmış bir madde değil.** Birim testleri
politika haritasını, kiralama aritmetiğini, strict parse'ı ve kanal çağrısını
kanıtlıyor (Kotlin 7 test, Dart 14 test, üç mutant öldürüldü). Korumanın
**gerçekten çalıştığı** — hangi örtüşmelerin `FLAG_WINDOW_IS_OBSCURED` tetiklediği —
cihazda ölçülmedi. Politika ayrımı tam olarak bu belirsizliğin zarar vermesini
engellemek için var: ölçülmeyen durum bir uyarıya düşer, kilitlenmiş bir
kullanıcıya değil. Cihaz doğrulaması yapıldığında AVD/cihaz, yoğunluk, commit ve
`lastUpdateTime` parmak iziyle `docs/audit/`'a kaydedilmeli.

#### Kapsam kararı

Filtre **yalnız** şu yüzeylere uygulanacak: PIN pad, rıza ekranları, veri export, uygulama
sıfırlama.

**Panik butonu ve geri sayım iptali kapsam DIŞI.** İyi niyetli bir overlay (sohbet balonu,
ses paneli, navigasyon kartı) acil basışı engellerse bu projenin CRITICAL saydığı gecikme
üretilir. Güvenlik kazancı yalnız gizli yüzeylerde, maliyet acil yolda; bu ayrımın korunması
zorunludur.

Regresyon testi önerisi: hassas route'ların obscured-touch politikasını sorduğunu doğrulayan
widget testi **ve** panik butonunun sormadığını doğrulayan negatif test.

### F-04 — Quick-panic hand-off'unda tazelik sınırı yok — AÇIK

```
Kategori   Stale emergency state / Rate limiting
Severity   LOW
CWE        CWE-613
```

`PanicRequestStore.submit` isteği device-protected prefs'e `commit()` ile yazıyor; ne
timestamp ne TTL var. Flutter o anda başlayamazsa (süreç kill, OEM kill, yeniden başlatma)
kayıt kalıcı olur ve kullanıcı günler sonra uygulamayı normal açtığında doğrudan gerçek bir
geri sayıma düşer. `QuickPanicRequestService.consume()` yalnız etiketi doğruluyor, tazeliği
değil. Aynı yolda tekrarlı basışlar için debounce/cooldown da yok.

Saldırgan kontrolü yok (exported olmayan trampoline), çoğunlukla kaza senaryosu; veri açığa
çıkması yok ve geri sayım hâlâ PIN ile iptal edilebilir.

**Öneri:** istekle birlikte **monotonik** (`elapsedRealtime`) timestamp yaz; tüketirken dar
bir pencere (2-5 dk) dışındakini sessizce at ve nedeni allowlist'li bir kodla kaydet.
`System.currentTimeMillis` saat değişimiyle oynanabilir, kullanılmamalı.

### F-05 — Uygulama kodu tamamen obfuscation dışı — AÇIK

```
Kategori   Hardening · Severity LOW · OWASP MASVS-RESILIENCE-3
```

`android/app/proguard-rules.pro`: `-keep class com.poyrazoncel.korubeni.** { *; }` +
`-keepclassmembers ... public <methods>; public <fields>;` — tüm uygulama sınıf, metot ve
alan adları açıkta. `isMinifyEnabled = true` olsa da app kodu fiilen obfuscate edilmiyor.

Anlamı tek başına değil, AUTHORIZATION'ın client-side olmasıyla birleştiğinde: entitlement
bypass'ının maliyetini düşürüyor. Obfuscation bir güvenlik sınırı **değildir**; bu yüzden
CRITICAL/HIGH değil.

**Öneri:** keep kuralını OS'un adıyla ürettiği yüzeye daralt — manifest bileşenleri,
platform-channel giriş noktaları, Flutter'ın yansımayla kullandığı sınıflar. **En riskli
adım:** yanlış daraltma bir receiver'ı kaybettirirse bu CRITICAL bir güvenilirlik
regresyonudur. R8 sonrası `verify_release.sh` **ve** cihazda acil akış koşumu olmadan
birleştirilmemeli; sonuç `docs/audit/`'a AVD/yoğunluk/commit + `lastUpdateTime` parmak
iziyle kaydedilmeli (CERT2-05).

### F-06 — Kullanılmayan `safe_device` bağımlılığı duruyor — AÇIK

```
Kategori Supply chain · Severity INFO
```

`safe_device: ^1.3.10` pubspec.yaml'da; A-017 düzeltmesinden sonra runtime'da hiçbir şey
çağırmıyor — `device_security_service.dart`'ın kendi yorumu bunu açıkça söylüyor. Gereksiz
transitive yüzey ve yanlış bir "root tespiti şu paketle yapılıyor" izlenimi.

Kaldırmadan önce `audit_absence_claims_gate` ve SBOM/lisans kanıt kapıları koşulmalı;
`pubspec.lock`, SBOM ve OSV kanıtı yenilenmeli.

### F-07 — `emergencyMessage` clipboard yolu ölü kod — AÇIK

```
Kategori Dead code / potansiyel gelecek sızıntı · Severity INFO
```

`emergency_failure_dialog.dart` ve `emergency_call_screen.dart` kullanıcı panosuna
`emergencyMessage` yazıyor; ancak 5 çağrı noktasının hiçbiri bu parametreyi geçmiyor, yani
yol asla çalışmıyor. **Bugün sızıntı yok.** İleride buraya kişi adı, numara veya konum içeren
bir metin bağlanırsa pano IME ve Android 13 pano önizlemesi üzerinden sızar. Ya yol silinmeli
ya da parametreye "PII içermez" sözleşmesi bir testle bağlanmalı.

### F-08 — Resmî OSV kanıt artefaktı bu koşumda üretilemedi — KISMEN

```
Kategori Evidence / süreç · Severity INFO
```

`scripts/audit_dependencies_osv.sh` → `scripts/generate_osv_evidence.py` kirli ağaçta
fail-closed (`--untracked-files=all`, 118 izlenmeyen kanıt dosyası). Doğru davranış; ama
imzalı artefakt yok. Sorgular doğrudan koşuldu (0 bulgu, bkz. DEPENDENCY_SCANNING).

Kalan iş: kanıt dosyaları commit edilip `scripts/verify_release.sh` temiz ağaçta koşulmalı.
Bu aynı koşum merged-manifest exported-surface kapısını ve 16KB hizalamayı da kapatır.

### F-09 — `PRODUCTION_AUDIT.md` var olmayan bir hafifletme beyan ediyordu — KAPANDI

```
Kategori   Release governance / denetim doğruluğu
Severity   INFO (kodda açık yok; yanlış olan şey beyanın kendisi)
Durum      KAPANDI — bu raporla aynı commit
```

Denetim sırasında değil, F-06 için `safe_device` atıfları taranırken bulundu.
`PRODUCTION_AUDIT.md` iki yerde `safe_device`'ı çalışan bir güvenlik kontrolü olarak
gösteriyordu:

- Bölüm 22, "Gap.": *"the app mitigates with safe_device root detection"*
- Bölüm 32, "Section assessment.": *"safe_device provides root/jailbreak detection"*

İki cümle **iki ayrı nedenle** yanlıştı:

1. `safe_device` A-017 ile runtime yolundan çıkarılmıştı; gerçek mekanizma native
   `DeviceIntegrityProbe`.
2. Daha önemlisi: **hiçbir kök tespiti entitlement kurcalamasını hafifletmiyor.**
   `DeviceIntegrity.compromised` verdict'inin tek tüketicisi
   `splash_screen.dart:170-183` ve orada yaptığı tek şey "Devam" düğmesi olan,
   kapatılabilir bir uyarı göstermek. Hiçbir özelliği kısıtlamıyor, hiçbir
   yetkilendirme kararını beslemiyor. Yani bileşen adı düzeltilse bile "hafifletme"
   kelimesi fazlasını iddia ediyordu.

**Kullanıcıya ve Play'e bakan metinler temiz** (kontrol edildi): `store/`,
`.gh-pages-publish/`, yasal metinler ve KVKK/Play belgelerinde kök tespiti iddiası yok.
Tek kullanıcıya görünen değinme uyarı diyaloğunun kendi metni ve o metin dürüst
("risk altında olabilir", onay istiyor). Yani mağaza veya yasal bir aşırı iddia sorunu
yoktu; sorun yalnız iç denetim belgesindeydi.

**Düzeltme:** iki cümle gerçeğe çekildi; ikisi de artık verdict'in neyi
beslemediğini açıkça söylüyor ve `safe_device`'a yalnız tarihsel düzeltme notu
olarak atıf yapıyor.

**Bu bulgunun asıl anlamı tek bir cümle değil.** Denetim belgelerinin kodla
tutarlılığı bu çalışmada **sistematik olarak kontrol edilmedi** — kod okundu,
belgeler kodla karşılaştırılmadı. Bulunan iki örnek (F-09 ve aşağıdaki
`specialUse` gözlemi) tesadüfen çıktı. Belgelerdeki her `SRC` / `CMD` / `TEST`
atıfının gerçek kodla karşılaştırılması ayrı bir iş olarak planlandı ve bu raporun
kapsamı dışındadır.

### Gözlem — `specialUse` foreground service iddiası geçersiz

Güvenlik bulgusu değil, **belge sürüklenmesi**. `.claude/rules/common/performance.md` ve
`.claude/rules/dart/patterns.md` "`specialUse` FGS"den bahsediyor; ancak:

- `AndroidManifest.xml`'de hiçbir foreground `<service>` beyanı yok,
- `FOREGROUND_SERVICE*` izni istenmiyor,
- `KoruBeniForegroundService` yalnızca sürekli bir bildirim yönetiyor.

Güvenilirlik fiilen exact alarm + direct-boot receiver'lara dayanıyor. `dart/security.md`
ayrıca bu FGS için "Play Console declaration + demo video obligation" olduğunu söylüyor ki
beyan edilmemiş bir bileşen için bu yükümlülük de yok. Belgeler gerçeğe çekilmeli — var
sandığımız bir mekanizma bu projenin en pahalı hata sınıfıdır.

## 4. Negatif kontrol değerlendirmesi

Denetim aşamasında production kodu mutasyona sokulmadı. Repo'da zaten gerçek bir mutasyon
koşucusu var (`scripts/run_safety_mutations.py`; her mutant hedeflenen testi kırmak zorunda):

| Mutant | Ölçtüğü koruma |
|---|---|
| M01_CANCEL_RESULT_SWALLOWED | onaylanmamış native iptalin kabul edilmesi |
| M02_STALE_GENERATION_ACCEPTED | bayat token'ın coordinator guard'ını geçmesi |
| M03_PIN_READ_FAILURE_AS_ABSENT | secure storage okuma hatasının "PIN yok"a düşmesi |
| M04_LOG_BEFORE_DISPATCH | yan etkilerin dispatch sonucunun önüne geçmesi |
| M05_NOTIFICATION_RESULT_IGNORED | ölü fallback bildiriminin başarılı sayılması |
| M06_DISPOSE_NATIVE_CANCEL | dispose'dan native cancel gönderilmesi |
| **M07_LOCKOUT_WRITE_FAILURE_IGNORED** | **düşülemeyen PIN denemesinin kilitsiz geçmesi (bu denetimle eklendi)** |

`test/release_secret_scan_test.dart` de gerçek bir negatif kontrol: tarayıcıyı fixture'a
karşı koşuyor ve tespit ettiğini assert ediyor — yalnız grep değil.

**Negatif kontrolü hâlâ olmayan PASS'lar (kalite notu düşürülmüş):** entitlement
authorization bypass, unsafe SQL interpolasyonu, `http://` endpoint policy'si, korumasız
exported bileşen. Bunlar için mutant eklenmesi önerilir.


## 4b. Yayın zinciri koşumu — 2026-10-02

Denetim sırasında çalıştırılamayan kapılar, kanıt dosyaları commit edildikten sonra
temiz ağaçta koşuldu.

### `scripts/verify_release.sh` — exit 0, 5/5 kod+smoke kapısı

| Adım | Sonuç |
|---|---|
| temiz build zemini (`flutter clean` + `pub get`) | PASS |
| `flutter analyze` | PASS, sıfır sorun |
| `flutter test` + kritik safety coverage | PASS, 2066 test; `CRITICAL_COVERAGE_PASS` |
| imzalı NON_RELEASE_SMOKE AAB + imza + **birleşik Android release yüzeyi** | PASS, `ANDROID_RELEASE_SURFACE_PASS` |
| Android lint + Kotlin unit + instrumentation derlemesi | PASS |
| 16KB sayfa boyutu hizalaması | PASS, tüm native kütüphaneler uyumlu |
| etiketli-yayın blocker (SBOM lisans kanıtı + notices paritesi) | PASS |

Sonuç satırları: `LOCAL_CANDIDATE_PASS`, `TAGGED_RELEASE_GATES_LOCAL_PASS`,
`EXTERNAL_RELEASE_GATES_UNVERIFIED`.

**Bu, §2'deki en önemli "doğrulanmadı" maddesini kapatır.** `ANDROID_RELEASE_SURFACE_PASS`
kaynak manifest değil **birleşik** manifest üzerinde çalışır; yani bağımlılık
manifest'lerinin inceleme sonrası izin veya bileşen ekleyip eklemediği artık
doğrulanmıştır. Denetim anında bu kapı koşulamamıştı (release build gerektiriyor).

Not: üretilen AAB `.smoke` paket kimliğiyle derlenir ve Play'e yüklenemez; gerçek
üretim AAB'si yalnız etiketli production zincirinden alınır.

### İmzalı kanıt artefaktları

| Kapı | Sonuç |
|---|---|
| `scan_release_secrets.py --require-clean` | `RELEASE_SECRET_SCAN_PASS` — mode=tracked-candidate, 1379 yol (1156 metin + 223 ikili), **findings=0**, içerik ve yol SHA-256'larıyla bağlı |
| `audit_dependencies_osv.sh` | `OSV_EVIDENCE_PASS` — pub 196 + Maven 203 sorgu, **findingCount=0**, ekosistem başına sorgu/yanıt SHA-256'larıyla |

F-08'in nedeni buydu: ikisi de `--untracked-files=all` ile kirli ağaçta fail-closed
davranıyor ve 362 izlenmeyen kanıt dosyası onları bloke ediyordu. Dosyalar commit
edildi, kapılar koştu.

`interpretation: noKnownFindingsAtScanTime` — aracın kendi ifadesi ve doğru olanı bu:
PASS "bu tam sürümlerde koşum anında bilinen OSV bulgusu yok" demektir, "açık yok"
demez.

### Hala doğrulanmayan

`EXTERNAL_RELEASE_GATES_UNVERIFIED` — script'in kendisi bunu yazıyor. Repo kodundan
doğrulanamayan şeyler: GitHub branch protection, required reviewers, environment
approver'ları, secret scanning / push protection ve Play Console beyanları.

F-03'ün cihaz doğrulaması da yapılmadı (§3 F-03).

## 5. Özet

Denetim anındaki (69c2ecd) sayım:

```
CRITICAL=0   HIGH=0   MEDIUM=3   LOW=2   INFO=3
APPLICABLE_CONTROLS=16   PASS=11   PARTIAL=4   FAIL=0
NOT_APPLICABLE=5 (+ SECURITY_HEADERS, IDOR gerekçeli N/A)
UNVERIFIED_EXTERNAL=2
RELEASE_BLOCKING_SECURITY_FINDINGS=0
SECURITY_RELEASE_READY=NO
```

Düzeltmeler sonrası güncel durum:

```
KAPANDI=4 (F-01, F-04, F-08, F-09)
SABITLENDI=1 (F-07 — silinmedi, tel tuzak testiyle pinlendi)
KABUL EDİLEN RİSK=1 (F-02)
UYGULANDI / CİHAZDA DOĞRULANMADI=1 (F-03)
AÇIK=2 (F-05 obfuscation, F-06 ölü safe_device bağımlılığı)

CRITICAL=0   HIGH=0   açık MEDIUM=0
RELEASE_BLOCKING_SECURITY_FINDINGS=0
SECURITY_RELEASE_READY=NO
```

`SECURITY_READY=YES` eşiğinin karşılanmayan maddeleri:

| Kriter | Durum |
|---|---|
| CRITICAL=0, HIGH=0 | ✅ |
| secret scan temiz (tam geçmiş dahil) | ✅ |
| authentication/authorization bypass yok | ✅ (entitlement client-side, ayrı sınıf) |
| sensitive data leakage bulunmuyor | ⚠️ F-02 kabul edilen risk olarak kayıtlı |
| release logging güvenli | ✅ |
| bilinen kritik/yüksek dependency vulnerability yok | ✅ `OSV_EVIDENCE_PASS`: 196 Pub + 203 Maven sorgu, findingCount=0 (§4b) |
| Android exported/native yüzeyleri doğrulanmış | ✅ `ANDROID_RELEASE_SURFACE_PASS` birleşik manifest üzerinde (§4b) |
| uygulanabilir kritik kontrollerde doğrulanmamış güvenlik sınırı yok | ⚠️ F-03 uygulandı ama cihazda ölçülmedi |
| gerekli dış güvenlik ayarları doğrulanmış | ❌ `EXTERNAL_RELEASE_GATES_UNVERIFIED` — GitHub/Play paneli gerekir |

**Bu bir "yayınlamayın" kararı değildir.** Hiçbir bulgu release-blocker değil ve açık
MEDIUM kalmadı. 2026-10-02 itibarıyla `NO` iki maddeye indi:

1. **F-03 cihazda ölçülmedi.** Kod uygulandı ve birim testleriyle çevrelendi, ama
   korumanın gerçekten çalıştığı yalnız cihazda kanıtlanabilir.
2. **Dış ayarlar doğrulanmadı.** GitHub branch protection, required reviewers,
   environment approver'ları, secret scanning ve Play Console beyanları repo
   kodundan görülemez.

İkisi de kapatılırsa eşik karşılanır. F-05 ve F-06 açık ama ikisi de eşiğin
maddesi değil: biri hardening (güvenlik sınırı değil), diğeri ölü bir bağımlılık.

## 6. Kalan iş

| # | İş | Not |
|---|---|---|
| 1 | F-03 kodu (kararlaştırılan kapsamda) | Panik yolu kapsam dışı kalmalı |
| 2 | F-04 monotonik tazelik penceresi | Kotlin + Dart testleriyle |
| 3 | F-06 / F-07 ölü bağımlılık ve ölü kod | Önce absence-claims ve SBOM kapıları |
| 4 | F-05 keep kuralı daraltma | Cihaz doğrulaması olmadan birleştirilmemeli |
| 5 | F-08 `verify_release.sh` temiz ağaçta | Merged manifest + OSV artefaktı + 16KB |
| 6 | GitHub dashboard doğrulaması | Branch protection, environment approver, secret scanning |
| 7 | `PinLockoutService` `StateError` → kendi `Exception` tipi | F-01'in bıraktığı kural gerilimini kaldırır |
| 8 | `specialUse` FGS iddiasının belgelerden düzeltilmesi | Güvenlik bulgusu değil, doğruluk işi |
