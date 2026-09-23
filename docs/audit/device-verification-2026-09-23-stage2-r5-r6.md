# Cihaz doğrulaması — 2026-09-23 — Aşama 2: R3 (bayat CLAIMED), R5 (gecikmeli sahte çağrı), R6 (ses tuşu tetikleyici)

## Ölçülen yapı (kimlik)

| Alan | Değer |
|---|---|
| Cihaz | Emülatör AVD `KoruBeni_A017_API35` |
| API / ABI | 35 / `arm64-v8a` |
| Ekran / yoğunluk | 1080x2400 / 420 dpi |
| Ölçülen kod | `HEAD=223c7c1` **+ commit edilmemiş çalışma ağacı** |
| Çalışma ağacı parmak izi | `TREE_DIFF_SHA=07e92fa169c96ea3` (`{ git diff; git status --short; } \| shasum -a 256 \| cut -c1-16`) |
| Kurulu yapı doğrulaması | `adb shell dumpsys package com.poyrazoncel.korubeni \| grep lastUpdateTime` → `2026-09-23 19:37:31` |
| Yapı komutu | `flutter build apk --debug --flavor play --target-platform android-arm64` |

**Neden parmak izi var:** CERT2-05'te bir sertifikasyon turu, düzeltmeden dört saat
önceki bir yapıyı koşup düzeltme öncesi kusuru yeniden üretmişti. Bu kayıt ölçülen
ağacı commit hash'iyle veremiyor (ağaç commit edilmemiş), bu yüzden diff'in içerik
hash'i veriliyor; aynı hash yeniden üretilmeden bu kayıt başka bir ağaca atfedilemez.

İlk kurulum `android-x64` ile yapılmıştı ve uygulama
`MissingLibraryException: Could not find 'libflutter.so' ... only found: [x86_64]`
ile açılmadan düştü. Ölçümlerin hiçbiri o yapıdan değil; hepsi yukarıdaki
`arm64-v8a` yapısından.

---

## R5 — Gecikmeli sahte çağrı teslim ediliyor (KAPANDI)

**Kusur (envanter R5 / BLD-01, FKC-03):** `zonedSchedule` kullanılıyordu ama
`com.dexterous.flutterlocalnotifications.ScheduledNotificationReceiver`
birleştirilmiş manifest'te yoktu → alarm teslim edilecek bileşeni bulamaz;
kullanıcıya "zamanlandı" denir, hiçbir şey gelmez.

### 1. Birleştirilmiş manifest (emülatörsüz)

`:app:processPlayDebugMainManifest` çıktısında her iki alıcı da var,
`exported=false`, boot yeniden zamanlayıcı `BOOT_COMPLETED` /
`MY_PACKAGE_REPLACED` / `QUICKBOOT_POWERON` filtreleriyle bağlı.

### 2. Kurulu paket (cihaz)

```
$ adb shell cmd package query-receivers --brief -a android.intent.action.BOOT_COMPLETED
    com.poyrazoncel.korubeni/com.dexterous.flutterlocalnotifications.ScheduledNotificationBootReceiver
    com.poyrazoncel.korubeni/.emergency.BootCompletedReceiver
```

### 3. Gerçek kullanıcı akışı (cihaz)

Temiz kurulum → rıza → onboarding → acil kişi (`Test / 5551234567`) → PIN `2468`
→ bildirim izni verildi. Ana Sayfa → Hızlı İşlemler → Sahte Çağrı → **"1 Dakika Sonra"**.

İlk denemede uygulama doğru şekilde **"Kesin alarm izni gerekli"** diyaloğunu
gösterdi (sessizce sahte başarı YOK). İzin verildikten sonra
(`cmd appops set ... SCHEDULE_EXACT_ALARM allow`) yeniden denendi:

```
SCHEDULE_T0 = Wed Sep 23 19:44:31 +03 2026

$ adb shell dumpsys alarm
  tag=*walarm*:com.poyrazoncel.korubeni/com.dexterous.flutterlocalnotifications.ScheduledNotificationReceiver
  type=RTC_WAKEUP origWhen=2026-09-23 19:45:31.000 window=0 exactAllowReason=permission
  operation=PendingIntent{... com.poyrazoncel.korubeni broadcastIntent}
```

Bekleme sonrası (19:45:55):

```
NotificationRecord(pkg=com.poyrazoncel.korubeni id=31001 importance=4
  channel=emergency_alerts category=call)
    android.title = "Sahte çağrı hazır"
    android.text  = "Sahte çağrı ekranını açmak için dokunun."
```

**Sonuç: gecikmeli sahte çağrı gerçekten teslim ediliyor.**

### 4. Negatif kontrol (mutasyon) — bu kaydın en önemli parçası

Manifest'teki 17 satırlık alıcı bloğu geçici olarak kaldırıldı, APK yeniden
derlenip kuruldu ve aynı instrumentation testi koşuldu:

```
ScheduledNotificationManifestInstrumentationTest > installedPackageDeclaresScheduledDeliveryReceiver FAILED
  android.content.pm.PackageManager$NameNotFoundException:
    ComponentInfo{com.poyrazoncel.korubeni/com.dexterous.flutterlocalnotifications.ScheduledNotificationReceiver}
ScheduledNotificationManifestInstrumentationTest > installedPackageRoutesBootToPluginRescheduler FAILED
  java.lang.AssertionError: BOOT_COMPLETED must reach the plugin's scheduled-notification rescheduler
```

`NameNotFoundException` R5'in kök nedeninin tam olarak yeniden üretilmesidir.
Manifest geri alındı (`git diff --stat` yeniden `+17`), yeniden kuruldu, test
tekrar yeşil. Yani test gerçekten bu düzeltmeyi ölçüyor.

### 5. Instrumentation (emülatör, tam koşu)

`:app:connectedPlayDebugAndroidTest` → **14 test, 0 hata, 6 atlandı**
(atlananlar bayrakla açılan opt-in probları: Doze, overdue, reboot).
Yeni `ScheduledNotificationManifestInstrumentationTest`'in iki testi de PASS.

> **Not:** `connectedAndroidTest` koşusu bitince uygulamayı KALDIRIR. Ardından
> elle ölçüm yapacaksan yeniden kur — aksi halde `pm list packages` boş döner ve
> bu "uygulama çöktü" gibi görünür.

---

## R6 — Ses tuşu tetikleyici (REPO TARAFI KAPANDI; CİHAZ UCU AŞAMA 6'YA DEVREDİLDİ)

**Kusur (envanter R6 / SES-01..05):** Ayarlar'dan açıldığında Dart geri çağrısı
bir sonraki resume'a kadar `null` kalıyordu; native taraf tuşları yutarken
uygulama tarafında hiçbir şey olmuyordu.

### Repo kanıtı (taze koşuldu)

- `test/core/services/volume_trigger_service_behavior_test.dart` — gerçek servis,
  2 test. **Mutasyon:** `bindCallback` düzeltme öncesi haline döndürüldüğünde
  test düşüyor: `Expected: <1> Actual: <0>` (panik sayacı) — yani "desen hiçbir
  şey yapmaz" kusurunun tam kendisi. Mutasyon geri alındı, test yeşil.
- `android/.../VolumeButtonDetectorTest.kt` — 4 Robolectric testi: kapalıyken
  tuş yutulmuyor, canlı dinleyici şart, 3 basış tam 1 olay + 5 sn soğuma,
  yanlış tuş geçiyor ve kapatma kısmi deseni siliyor. Kotlin JVM paketi
  `--rerun-tasks` ile **125 test, 0 hata** (119 → 125).

### Cihaz ucu — DÜRÜST SINIR

Ayarlar → Ses & Titreşim → "Ses Tuşu ile Acil Durum" anahtarına dokunuldu.
Anahtar **`checked=false` olarak kaldı** ve log şunu yazdı:

```
[WARN][runtime] revenuecat_api_key_missing
```

Bu **doğru davranış**: `emergency_trigger_host.dart:119-147` native dinleyiciyi
yalnız `SubscriptionGate.isAuthorized(access, PremiumFeature.volumeTrigger)`
olduğunda başlatır; doğrulama yapısında RevenueCat anahtarı yer tutucudur, bu
yüzden yetki hiç kurulamaz ve tetikleyici hiç açılmaz.

**Sonuç:** `adb shell input keyevent 25` ×3 ile uçtan uca doğrulama bu cihazda
YAPILAMADI ve YAPILMIŞ GİBİ KAYDEDİLMİYOR. R6'nın cihaz ucu, gerçek Pro
yetkisine — yani **R1'e (Play lisans testçisi + RevenueCat panosu)** — bağlıdır
ve bu nedenle **EXTERNAL REMAINDER olarak Aşama 6'ya**, R1'in arkasına
devredilmiştir (bkz. `docs/release/final_completion_matrix.md`, "Aşama 2
kapanisi ve devir").

Yardımcı bir kontrol denendi ve **sonuçsuz** kaldı: tetikleyici kapalıyken
`keyevent 25` ×3 sonrası `dumpsys audio` ilk `streamVolume` değeri değişmedi
(3 → 3). Emülatörde `input keyevent`'in hangi akışı sürdüğü doğrulanamadığı için
bu ölçüm delil sayılmadı; "tuş yutulmuyor" iddiası yalnız JVM testine dayanıyor.

---

## R3 — Bayat CLAIMED kaydı artık sormadan aranmıyor (CİHAZDA KAPANDI)

**Kusur (envanter R3 / NTV-10):** `EmergencySessionCoordinator.kt:598`'de
`LifecycleState.CLAIMED` dalı **yaş sınırı olmadan** `claimAndDispatch` çağırıyordu.
Force-stop veya güç kesintisiyle CLAIMED'de kalmış bir kayıt, uygulama günler
sonra açıldığında istenmeyen bir acil arama başlatabiliyordu.

2026-09-20 kaydı ARMED yarısını ölçmüş ve **"`CLAIMED` dalı değişmedi ve
ölçülmedi. Bayat bir CLAIMED kaydı hâlâ açılışta aranır."** diye açıkça
not düşmüştü. Bu bölüm o boşluğu kapatır; o kaydı geçersiz kılmaz, sürdürür.

### Düzeltme

CLAIMED dalı artık ARMED ile aynı tazelik politikasına uyuyor: vadesi
`MAX_OVERDUE_DISPATCH_MS`'i aşmışsa `offerOverdueInsteadOfDialling`, aşmamışsa
`claimAndDispatch`.

### JVM kanıtı (taze)

`EmergencySessionCoordinatorTest` içinde iki test — biri bayat, biri taze
(negatif kontrol). Kotlin paketi `--rerun-tasks` ile **125 test, 0 hata**.

### Cihaz kanıtı — YENİ

`OverdueSessionProbeTest`'e CLAIMED için bir prob çifti eklendi. Bu prob
SAHTE kullanmaz: gerçek Direct Boot deposunu, gerçek üretim koordinatör
kablosunu (`AndroidEmergencySessionRuntime`) ve gerçek Telecom isteyicisini
sürer. Her ikisi de `-e overdueProbe` olmadan atlanır, yani normal bir
`connectedAndroidTest` koşusu asla oturum kaydı yazmaz.

```
$ ./gradlew :app:connectedPlayDebugAndroidTest \
    -Pandroid.testInstrumentationRunnerArguments.class=...OverdueSessionProbeTest \
    -Pandroid.testInstrumentationRunnerArguments.overdueProbe=claimed \
    -Pandroid.testInstrumentationRunnerArguments.overdueProbeTarget=+905001234567 \
    -Pandroid.testInstrumentationRunnerArguments.overdueProbeAllowReplace=1
  [PASS] staleClaimedSessionIsOfferedNotDialled     (diğer 3 SKIPPED)

$ ... -Pandroid.testInstrumentationRunnerArguments.overdueProbe=claimed-control
  [PASS] recentlyClaimedSessionIsStillDialled       (diğer 3 SKIPPED)
```

Probun kendi logu (sınır iki yönde de gösterildi):

```
I OverdueProbe: SEEDED state=claimed overdueByMs=3600000
I OverdueProbe: CLAIMED_STALE   state=manualActionRequired call=notAttempted fallback=posted
I OverdueProbe: SEEDED state=claimed overdueByMs=30000
I OverdueProbe: CLAIMED_CONTROL state=requestFailed        call=failed
```

**Okuma notu — negatif kontrol neden bu kadar önemli:** "arama olmadı" tek
başına hiçbir şey kanıtlamaz; prob hiç koşmasaydı da aynı görünürdü. Kontrol
kolunda `call=failed` (yani `notAttempted` DEĞİL) olması, 30 sn geciken bir
CLAIMED kaydının hâlâ sevk girişimine ulaştığını gösteriyor. `failed` sonucu
emülatörde beklenen durumdur (telefon donanımı/arama izni yok); burada anlamlı
olan `notAttempted` ile `failed` arasındaki fark, aramanın başarısı değil.

Prob, oturum kaydını PANIC yuvasına yazar; `connectedAndroidTest` koşu sonunda
uygulamayı kaldırdığı için tohumlanan kayıt uygulama verisiyle birlikte silinir
(koşu sonrası `pm list packages | grep -c korubeni` → `0`).

### Hâlâ açık olan (R3'ün diğer yarısı)

Force-stop'un alarmları silmesi ve aramanın sessizce kaçması (HATA-14, NTV-09)
bu turda ölçülmedi: protokol Test C ve fiziksel cihaz gerektirir. Bu yarı
**EXTERNAL REMAINDER olarak Aşama 5'e** devredilmiştir.

---

## Aşama 2 kod incelemesi — bulgular ve kapanış

Değişiklik kümesi `security-reviewer` ve `flutter-reviewer` ile incelendi.
Bulgular bağımsız olarak doğrulandıktan sonra kapatıldı (hiçbiri "ajan öyle
dedi" diye kabul edilmedi).

### CRITICAL-1 — Aktif panik oturumu, PIN'siz sıfırlamayla susturulabiliyordu

`SafetySessionActivityProbe` yalnız `check_in_state_v2` / `safe_walk_state_v2`
anahtarlarına bakıyordu. Panik oturumu bu anahtarlara HİÇ yazmaz — doğrudan
native koordinatörün kalıcı deposuna kurulur. `EmergencySessionCoordinator.wipe()`
ise yalnız `CLAIMED` kaydı reddeder; `PREPARING`/`ARMED` kaydı **iptal eder**.

Sonuç: geri sayım çalışırken, PIN bilmeyen biri "PIN'imi unuttum" (mevcut) veya
yeni `BootstrapRecoveryScreen` (K2 ile eklendi) üzerinden oturumu iptal
ettirebiliyordu. Zorlama modelinin tam olarak engellemeyi amaçladığı senaryo.

Envanterin kendisi bunu KLT-08 satırında not etmişti ("Probe panik geri
sayımını kapsamaz"), ama R1–R7/K1–K3 listesinde yer almıyordu. K2 bu yola
ikinci ve daha kolay ulaşılan bir giriş eklediği için Aşama 2 kapsamında
kapatıldı.

**Düzeltme:** probe artık native PANIC yuvasını da sorguluyor
(`discoverEmergencySession` — token gerektirmeyen, zaten var olan yol).
`present` + terminal-olmayan → aktif; `corrupted`/`unknown`/exception →
fail-closed; native köprü yoksa (`isSupported == false`) aktif panik oturumu
olamayacağı için `absent`.

**Kanıt:** `safety_session_activity_probe_test.dart` 7 → **14 test**. Mutasyon:
panik kontrolü `hasActiveSession()`'dan çıkarıldığında ARMED vakası düşüyor
(`Expected: true, Actual: <false>`), yani test gerçekten bu düzeltmeyi ölçüyor.
Negatif kontrol de var: bitmiş (cancelled/requestFailed/… ) bir panik kaydı
sıfırlamayı ENGELLEMİYOR — aksi halde "her zaman true" dönen bir probe tüm
pozitif vakaları geçerken kullanıcının kendi kurtarma yolunu kalıcı olarak
kapatırdı.

### HIGH-1 — PIN kilit sayacı okunamadığında kilit sessizce devre dışı kalıyordu

`_syncLockoutState()` içindeki çıplak `catch (_)`, okunamayan sayacı
"0 hata, kilit yok" sayıyordu. `PinVerificationService.verify()` kilit
servisine HİÇ bakmadığı için bu ekranın `_lockoutEndTime` alanı kilidin TEK
uygulama noktası — yani fail-open, üstelik hiçbir kayıt düşmeden (release'de
`debugPrint` zaten derlenmiyor).

**Düzeltme:** tipli `on Exception` / `on StateError` (çıplak catch kaldırıldı —
`dart/coding-style.md`), `LocalWarningCode.pinLockoutStateUnreadable` ile yerel
kayıt, ve okunamayan sayaç **kilitli** kabul ediliyor (bir temel geri çekilme
adımı). Kullanıcı kilitlenmiyor: "PIN'imi unuttum" `_isLockedOut`'a bağlı
değil, erişilebilir kalıyor — ve artık panik-farkında probe ile korunuyor.
Ayrıca sayaç okunamıyorken geri sayım akışı başlatılmıyor; `countdownStream`
saniyede bir `getState()` çağırdığı için bu yalnız aynı hatayı zamanlayıcıya
bağlardı.

**Kanıt:** yeni `test/screens/unlock_lockout_fail_closed_test.dart` (gerçek
`AppUnlockScreen` pump'ı). Mutasyon: `lockedUntil: null`'a döndürüldüğünde
kilit bandı kayboluyor ve test düşüyor. Negatif kontrol: sayaçlar okunabilir
ve temizken ekran kilitlenmiyor.

### HIGH-2 — `HomeProvider`'da eksik dispose koruması

Kardeş provider'lar (`ContactsProvider`, `SettingsProvider`) `_disposed` +
`notifyListeners()` override'ı taşırken `HomeProvider` bu turda `dispose()`
kazandı ama korumayı almadı; uçuştaki üç eşzamanlı yükleme dispose sonrası
`notifyListeners()` çağırabilirdi. Aynı desen eklendi.

### HIGH-3 — `app_unlock_screen.dart` biçimlendirme gürültüsü

Diff 277+/231− idi; `git diff -w` ile yalnız ~54 satır gerçekti. Yani ~230
satır saf yeniden girintileme — `coding-style.md`'nin adıyla yasakladığı şey
("format ONLY files you create"), üstelik zorlama modelinin merkezindeki bir
ekranda `git blame`'i bozarak.

Dosya `HEAD` sürümünden yeniden kuruldu ve yalnız işlevsel parçalar uygulandı.
Diff şimdi **42+/2−** ve `git diff -w` ile birebir aynı — yani kozmetik
gürültü sıfır.

### MEDIUM — kapatılan

`AppResetStateRegistry.resetAll()` başarısızlık yolunun testi yoktu. Eklendi:
bir provider sıfırlamayı reddettiğinde sonuç `WipeResult.unknown`'a düşüyor
(depo temizlense bile), çünkü "veriler silindi" demek süreçte yaşayan bayat
durum varken doğru değil.

### MEDIUM — kapatılmadı (bilinçli)

- `bootstrap_recovery_screen.dart` metinleri gömülü Türkçe; uygulama şu an
  yalnız TR çalışıyor (`supportedLocales: [tr_TR]`) ve
  `translations_key_parity_test` bunları görmez. EN yayınına kadar borç.
- `contacts_provider_add_validation_test.dart` kendi provider'larını dispose
  etmiyor, dolayısıyla statik registry'de birikiyorlar. Bugün bir hataya yol
  açmıyor (o dosya `resetAll()` çağırmıyor) ama tuzak.

---

## Bu kaydın kapsamadıkları

- Fiziksel cihaz yok; yalnız emülatör (R2 açık kalır).
- Gerçek satın alma / RevenueCat işlemi yok (R1, K1 açık kalır).
- Force-stop ve OEM öldürme senaryoları bu turda koşulmadı (R3'ün cihaz yarısı).
- Doze altında gecikmeli sahte çağrı ölçülmedi; ölçüm ekran açık ve cihaz uyanıkken yapıldı.
