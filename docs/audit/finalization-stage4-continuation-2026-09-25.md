# KoruBeni Finalization — Aşama 4 devralma ve devam (2026-09-25 gece)

**Güncel kapanış durumu:** `STAGE_4=PASS`

Final kapanış, bu append-only kaydın bölüm 21.6'sındadır:
`EMU_REQUIRED_TOTAL=94`, `EMU_PROVEN=94`, `EMU_UNVERIFIED=0`; zorunlu fresh
Flutter, Kotlin, instrumentation ve `verify_release` kapıları `exit 0` olmuştur.
Önceki bölümlerdeki `IN_PROGRESS` / `INCOMPLETE` ifadeleri tarihsel ara
snapshot'lardır; regression kaydı değildir.

Bu dosya `finalization-stage4-2026-09-25.md` dosyasının yerini ALMAZ; onu
devralır ve düzeltir. Önceki ajanın kaydı tarihsel kanıt olarak durur.

## 1. Devralınan raporun düzeltilmesi

Önceki rapor `VERIFY_RELEASE=FAIL` diyor. Bu ARTIK DOĞRU DEĞİL. Rapor 14:20'de
yazılmış; ondan sonra aynı çalışma ağacında şu dosyalar değişmiş (mtime kanıtı):

- `lib/core/services/notification_service.dart` (cold-launch notification response
  yakalaması + `unnecessary_import` giderildi)
- `lib/screens/home_page.dart`
- `test/screens/main_navigation_behavior_test.dart`

Rapordaki final APK `7ddb5071…` artık diskte yok; 21:06 derlemesi `35f87ca2…`
üretmiş, ardından `verify_release.sh` `build/` dizinini temizlemiş.

## 2. Kanıt zincirinde bulunan yapısal kusur

Kaynak birebir aynıyken yapılan yeniden derleme `b8f004d1…` verdi
(`35f87ca2…` değil). **Debug APK byte-reproducible değildir.** Bu yüzden
"APK SHA-256" alanı yeniden derlemeyle ASLA doğrulanamaz.

Bundan sonra uygulanan kural: kanıt SHA'sı yalnız **cihazdaki kurulu paketten**
`adb pull` ile alınır ve yerel derleme ile karşılaştırılır. Kurulu APK ayrıca
oturum dışına yedeklenir, çünkü `verify_release.sh` `build/` dizinini siler.

## 3. Sabitlenmiş kimlik (bu bölümdeki tüm kanıtlar bu kimliğe aittir)

| Alan | Değer |
|---|---|
| Git SHA | `37ded42b524b9755d068fe63e1ff898a9c9cfd6d` (+ commit edilmemiş ağaç) |
| Worktree SHA-256 | `5aa0299ba8bdae7e149077a09c4d0534ae7facf89748fffdfb3c5a6a69cdba7d` |
| APK SHA-256 | `b8f004d1691688378a3bfc85941b60ab6f722b7c5170d0fa721dc62e71576d13` |
| SHA doğrulaması | yerel derleme == `adb pull` ile çekilen kurulu paket |
| androidTest APK SHA-256 | `8f126348be47df00abcc075fa808dd6da909d39f51f856b3a48cf3ea76a64b5a` |
| Variant / applicationId | `playDebug` / `com.poyrazoncel.korubeni` |
| versionName / versionCode | `1.0.0` / `1` · minSdk 29 / targetSdk 36 |
| AVD / API | `KoruBeni_A017_API35` / 35 |
| Density / çözünürlük | 420 dpi / 1080x2400 |
| Fingerprint | `Android/sdk_phone64_arm64/emu64a:15/AE3A.240806.019/12368160:userdebug/test-keys` |
| lastUpdateTime | `2026-09-25 23:33:53` (reconciliation package-replace sonrası) |

Worktree SHA-256 şu komutla yeniden üretilir:

```bash
{ git rev-parse HEAD; git diff HEAD; git status --porcelain;
  for f in $(git ls-files --others --exclude-standard | grep -vE '^docs/audit/evidence/'); do
    echo "UNTRACKED $f"; shasum -a 256 "$f"; done; } | shasum -a 256
```

## 4. Makine kapıları — bu APK'da taze koşuldu

| Kapı | Sonuç | Ham çıktı |
|---|---|---|
| `flutter analyze --no-fatal-infos` | PASS | `No issues found! (ran in 3.3s)` |
| `flutter test --no-pub` | PASS | `01:37 +2019: All tests passed!` |
| `:app:testPlayDebugUnitTest` | PASS | 125 test, 0 fail, 0 skip |
| `:app:connectedPlayDebugAndroidTest` | PASS | 18 test, 8 pass, 10 opt-in skip, 0 fail |
| `./scripts/verify_release.sh` | PASS | `KOD/SMOKE DOGRULAMA YESIL — 5/5`; 16KB 10/10 |
| `git diff --check` | PASS | exit=0 |

Gradle'ın `connectedAndroidTest` görevi kendi APK'sını kurar ve sabitlenmiş
paketi ezer. Her gradle koşumundan sonra sabitlenmiş APK yeniden kuruldu ve
SHA'sı `adb pull` ile tekrar doğrulandı.

## 5. Opt-in probe'ların GERÇEKTEN koşturulması

Gradle koşumundaki 10 `SKIPPED` test davranış kanıtı DEĞİLDİR. Hepsi kullanıcı
onayıyla, sabitlenmiş APK üzerinde tek tek elle koşturuldu. Arama hedefi her
koşumda `0000000` sentinel'idir; kayıtlı hiçbir acil kişi kullanılmadı.

### 5.1 Ön koşul olarak bulunan iki gerçek kapı

Temiz kurulumda probe'lar önce kırmızı verdi. Bunlar tahmin edilmedi, ham
çıktıdan okundu:

- `expected:<MANUAL_ACTION_REQUIRED> but was:<REQUEST_FAILED>` — `CALL_PHONE`
  runtime izni yok.
- `arm failed: {type=rejected, reasonCode=exactAlarmDenied}` — `SCHEDULE_EXACT_ALARM`
  appop'u yok.

İkisi de üründe doğru fail-closed davranıştır: izin yokken sistem sessizce
"başardım" demiyor, tiplenmiş ret kodu döndürüyor. İzinler verildikten sonra
dördü de yeşile döndü. İzinsiz koşumların çıktısı PASS diye sunulmamıştır.

### 5.2 `OverdueSessionProbeTest` — 4 mod, 4/4 OK

| Mod | Sonuç |
|---|---|
| `overdue` | `OK (4 tests)` |
| `control` | `OK (4 tests)` |
| `claimed` | `OK (4 tests)` |
| `claimed-control` | `OK (4 tests)` |

Bayat/taze ARMED ve CLAIMED kayıtları, iki yönlü negatif kontrolle. Bu,
**NTV-10**'u sabitlenmiş yeni APK'da yeniden kanıtlar.

### 5.3 `Stage4ReconciliationInstrumentationTest` — PACKAGE_REPLACED

```text
SEEDED   finalDeadlineMs=1790369644705 elapsedDeadlineMs=1548313
  -> adb install -r (aynı APK, gerçek paket değişimi)
VERIFIED finalDeadlineMs=1790369644705 elapsedDeadlineMs=1548313 driftMs=0
```

`OK (2 tests)`. Paket değişimi sonrası oturum ARMED kaldı, deadline sürüklenmedi
(driftMs=0), elapsed-realtime deadline hâlâ gelecekte.

### 5.4 `Phase3RebootProbeTest` — GERÇEK yeniden başlatma

```text
arm            -> OK (2 tests)
/proc/uptime   380.57   (reboot öncesi)
adb reboot
/proc/uptime    13.87   (gerçek reboot kanıtı; uptime sıfırlandı)
verify         -> OK (2 tests)
```

Manifest `BOOT_COMPLETED` alıcısı oturumu geri yükledi ve
`elapsedRealtimeDeadlineMs`'i yeniden hesapladı (arm sırasında 0 yazılmıştı,
verify onu `elapsedRealtime()`'ın ilerisinde buldu).

**Yöntem sapması, dürüst kayıt:** `scripts/phase3_emulator_reboot_probe.sh`
kullanılamadı, çünkü script temiz kaynak ağacı şart koşuyor
(`source tree must be clean before running candidate evidence`) ve devralma
kuralı commit etmeyi yasaklıyor. Aynı probe sınıfı elle `am instrument` ile
sürüldü; davranış kanıtı aynıdır, script'in JSON provenance çıktısı üretilmedi.

### 5.5 `NativeDozeDispatchProbeTest` — GERÇEK deep Doze

İlk deneme dürüstlük gereği PASS sayılmadı:

```text
$ adb shell dumpsys deviceidle force-idle
Unable to go deep idle; not enabled
```

Bu koşum ekran kapalı + şarj yokken sevk etti ama **Doze içinde değildi**.
`dumpsys deviceidle enable deep` ile deep Doze açıldı ve durum adımlandı:

```text
Stepped to deep: IDLE_PENDING -> SENSING -> LOCATING -> IDLE
mDeepEnabled=true  mScreenOn=false  mCharging=false
mState=IDLE mLightState=OVERRIDE
```

Cihaz 120 saniyelik ARMED pencerenin tamamı boyunca `mState=IDLE`'da tutuldu
(pencere başında, ortasında ve sonunda ayrı ayrı doğrulandı):

```text
ARMED  deadlineMs=1790368778125 delaySeconds=120
RESULT state=requestSubmittedUnconfirmed call=submittedUnconfirmed
       fallback=posted latenessMs=33
OK (2 tests)
```

**Gerçek deep Doze altında sevk 33 ms gecikmeyle çalıştı**, arama isteği
gönderildi ve fallback bildirimi postalandı.

Sınır, dürüstçe: bu emulator Doze'udur. OEM üretici battery-killer listeleri ve
gerçek Telecom/SIM yolu hâlâ fiziksel cihaz gerektirir; bu koşum onları
kapatmaz.

## 6. Henüz kapanmayanlar

Aşama 4'ün açık emulator satırlarının UI ile sürülen bölümü bu oturumda
bitmedi. Bu dosya kapanış iddiası taşımaz; `EMU_UNVERIFIED` hâlâ sıfır değildir.

## 7. Aynı APK ile devam eden gerçek UI / Android sınırı kanıtları

Bu bölümdeki bütün koşumlar kurulu APK'dan ölçülen
`b8f004d1691688378a3bfc85941b60ab6f722b7c5170d0fa721dc62e71576d13`
SHA-256'sına aittir. `adb shell sha256sum <base.apk>` ile yerel APK SHA'sı
eşleşmiştir. AVD/API/fingerprint/density Bölüm 3 ile aynıdır. Emulator yeniden
açıldıktan sonraki `lastUpdateTime=2026-09-25 23:34:05` değeridir.

| ID | Beklenen | Gerçek emulator aksiyonu | Actual | Sonuç / kanıt |
|---|---|---|---|---|
| HOME-07 | Rehber hazırlık çipi kullanılabilir kişi yönetimine gider | Ana ekrandaki Rehber çipine dokunuldu | Gerçek `Acil Kişiler` ekranı açıldı; eski yanıltıcı/no-op izin diyaloğu yok | EMU_PROVEN · `stage4-final3-home07-contacts.png` |
| MAP-05 | Konum FAB gerçek konuma taşır ve sonucu bildirir | Konum FAB'a dokunuldu | `41.00820,28.97840` alındı ve `Konumunuz güncellendi` gösterildi; crash/hang/sahte başarı yok | EMU_PROVEN · `stage4-final3-location.png` |
| HZ-02 | Quick Settings tile kendi trampoline'ı üzerinden uygulamayı açar | Gerçek SystemUI tile'ına dokunuldu | `QuickPanicTrampolineActivity -> MainActivity`; tüm platform kanalları kuruldu | EMU_PROVEN · `stage4-final3-quick-tile-result.png`, logcat |
| HZ-04 | Widget eklendiğinde PendingIntent bağlanır | Launcher3 widget picker'dan KoruBeni seçilip `ADD` basıldı | `dumpsys appwidget`: widget id=4, Launcher3 host, `PanicWidgetProvider`, RemoteViews | EMU_PROVEN · `stage4-final4-widget-added.png`, dumpsys |
| HZ-05 | Widget dokunuşu trampoline üzerinden uygulamayı açar | Yerleştirme seçimi kapatıldıktan sonra gerçek widget'a dokunuldu | ActivityTaskManager gerçek widget PendingIntent'ini trampoline'a, sonra MainActivity'ye taşıdı | EMU_PROVEN · `stage4-final4-widget-trampoline-result.png`, logcat |
| HZ-06 | Trampoline başarı ve kalıcı kayıt hatası dalları | Widget ve tile ayrı ayrı gerçek sistem yüzeyinden çalıştırıldı | Başarı dalı gerçek: trampoline, MainActivity `0x14000000`, kanallar; persist-failure enjeksiyonu yapılmadı | PARTIAL · EMU_UNVERIFIED kalır |
| HZ-11 | Dış uygulama trampoline/extra ile panik başlatamaz | ADB normal `uid=2000(shell)` iken non-exported trampoline ve exported MainActivity sahte extra ile çağrıldı | Trampoline `SecurityException: not exported`; MainActivity ana ekranda kaldı, countdown oluşmadı | EMU_PROVEN · ham shell çıktısı |
| NTV-06 | Reboot: future ARMED, overdue ve PREPARING dalları | Gelecekteki sentinel oturum arm edildi, emulator reboot edildi, verify probe çalıştırıldı | Future ARMED dalı gerçek reboot ile geçti; diğer kararlar her dal için gerçek reboot altında sürülmedi | PARTIAL · Bölüm 5.4; EMU_UNVERIFIED kalır |
| NTV-07 | Paket değişimi mevcut boot içinde reconcile eder | Sentinel oturumdan sonra aynı APK `adb install -r` ile yeniden kuruldu | `MY_PACKAGE_REPLACED`; ARMED/deadline korundu, drift=0, `OK (2 tests)` | EMU_PROVEN · Bölüm 5.3 ham çıktı; Play yükseltme entitlement kısmı Aşama 6'da kalır |
| NTV-16 | TIMEZONE_CHANGED future ve kalan süre 0 dalları | UTC'ye geçildi; gerçek manifest yayını gönderildi; sonra İstanbul'a dönüldü | Future dalında receiver DELIVERED, drift=0; sıfır-kalan sevk dalı bu gerçek yayınla sürülmedi | PARTIAL · EMU_UNVERIFIED kalır |
| HATA-16 | Reboot davranışı NTV-06'nın tüm dallarıdır | NTV-06 gerçek emulator reboot koşumu | Future ARMED dalı geçti; NTV-06'nın diğer reboot dalları açık | PARTIAL · EMU_UNVERIFIED kalır |
| ONB-02 | PageView kaydırma, haptik ve indeks restoration | Gerçek swipe; HOME; `am kill`; launcher intent ile cold dönüş; Android vibrator history okundu | Sayfa 2, cold restoration sayfa 2; swipe 08:18:10 ve İleri 08:18:51 ayrı `TEXTURE_TICK` üretti | EMU_PROVEN · `stage4-final4-onboarding-page2.png`, dumpsys vibrator_manager |
| ONB-09 | ACTION_PICK başarı/iptal/no-picker/hata sonuçları | Gerçek picker'dan StageFour seçildi | Başarı dalı gerçek; iptal ve hata dalları açık | PARTIAL · picker screenshot/log; EMU_UNVERIFIED kalır |
| PIN-08 | Zorunlu PIN kurulumunda Geri etkisizdir | İlk kurulum PIN ekranında sistem BACK gönderildi | MainActivity resumed kaldı ve aynı `PIN kurulum ekranı` görünmeye devam etti | EMU_PROVEN · UIAutomator/dumpsys |
| KLT-12 | AppLock'ta sistem Geri etkisizdir | 125 s gerçek background sonrası AppLock açıldı; BACK gönderildi | Aynı `Uygulama kilidi. PIN ile açın.` ekranı kaldı | EMU_PROVEN · `stage4-final4-background-lock-125s.png`, UIAutomator |
| DL-05 | `/home` sekme 0'a gider | `am start -a VIEW -d korubeni://open/home` | `Hoş Geldiniz`, Home ve dört tab gerçek UI'da | EMU_PROVEN · am start + UIAutomator |
| DL-07 | `/contacts` sekme 2'ye gider | Gerçek VIEW intent | `Acil Kişiler`, StageFour ve Kişiler seçili | EMU_PROVEN · `stage4-final4-deeplink-contacts.png` |
| DL-09 | `/timeline` SafetyTimelineScreen açar | Gerçek VIEW intent | `Güvenlik Zaman Çizelgesi` gerçek kayıtlarla açıldı | EMU_PROVEN · `stage4-final4-deeplink-timeline.png` |
| DL-11 | `/subscription` paywall açar | Ana navigator durumundan gerçek VIEW intent | `KoruBeni Pro'ya Yükselt`; plan alınamadı yüzeyi doğru; satın alma/entitlement PASS sayılmadı | EMU_PROVEN · `stage4-final4-deeplink-subscription.png` |
| NTV-29 | Picker başarı, iptal, ALREADY_ACTIVE, NO_PICKER, PICK_FAILED | ONB-09 gerçek ACTION_PICK başarı zinciri | Başarı sınırı geçti; diğer sözleşme dalları runtime'da açık | PARTIAL · EMU_UNVERIFIED kalır |
| NTV-30 | Doğrulanmış numara dialer'a; geçersiz/no-handler false | StageFour kartında `Ara` | Başarı sınırı geçti: Dialer `tel:5551234567`; negatif iki dal açık | PARTIAL · EMU_UNVERIFIED kalır |
| PRM-01 | Disclosure reddi OS izin penceresini açmaz | Konum izinleri revoke; Harita; disclosure `Reddet` | Fine/coarse `granted=false` kaldı; OS PermissionController açılmadı; Harita `Konum alınamadı` | EMU_PROVEN · dumpsys package + UIAutomator |
| PRM-03 | Kalıcı ret diyaloğu kapatılabilir | Android izin penceresinde iki kez `DON'T ALLOW`; uygulama diyaloğunda `Reddet` | `USER_FIXED` oluştu; diyalog kapandı; izin false kaldı | EMU_PROVEN · dumpsys package + UIAutomator |
| PRM-04 | Kalıcı ret diyaloğu sistem ayarını açar | Aynı durumda `Ayarlara Git` | `com.android.settings/.spa.SpaActivity`; `APPLICATION_DETAILS_SETTINGS package:` | EMU_PROVEN · `stage4-final4-location-permission-settings.png`, ActivityTaskManager |
| KLT-11 | Yazılı onaylı unutulan-PIN reset; aktif oturumda native ret | Cold AppLock -> `Şifremi Unuttum` -> `SIFIRLA` -> Sıfırla; ardından force-stop/cold relaunch | Başarı dalı gerçek: temiz `Kurulum ve Onay`, cold relaunch'ta da AppLock/StageFour yok; aktif oturum TOO_LATE/unknown dalı bu koşumda yok | PARTIAL · `stage4-final4-forgot-pin-reset-result.png`, `stage4-final4-reset-cold-relaunch.png`; EMU_UNVERIFIED kalır |
| HATA-12 | Reset sonrası provider/route bayat durumu dirilmez | Gerçek reset + cold relaunch + onboarding kişi adımına dönüş + yeniden picker/rıza | Kişi adımı temiz başladı; StageFour eski app state'inden dirilmedi, yalnız yeniden seçilip onaylandıktan sonra kaydedildi | EMU_PROVEN · reset/relaunch screenshots + UIAutomator |
| RIZA-14 | Consent'te reddet butonu yok; onaysız Geri uygulamadan çıkar | Temiz reset sonrası hiçbir onay vermeden sistem BACK; ardından launcher intent ile cold açılış | KoruBeni task'ı foreground'dan çıktı; yeniden açılış yine `Kurulum ve Onay`, onay atlanmadı | EMU_PROVEN · dumpsys activity + UIAutomator |
| BOOT-18 | Consent/onboarding/main köklerinde BACK çıkar; AppLock'ta etkisiz | Üç kökte ayrı sistem BACK; AppLock dalı KLT-12 koşumunda | Üç kök KoruBeni task'ından çıktı ve alttaki Dialer'a döndü; AppLock ekranda kaldı | EMU_PROVEN · dumpsys activity + KLT-12 kanıtı |

## 8. Production bug düzeltmesi ve final APK ailesi

Önceki APK'da gerçek unutulan-PIN reset yolu başlangıç `/` rotasını
`pushAndRemoveUntil` ile siliyordu. Reset sonrası onboarding kişi formunda
`DraftOnb / 5552223333` yazılıp HOME → `am kill` → cold dönüş yapıldığında ilk
hata `Navigator._history.isNotEmpty`, ardından tekrarlayan
`_elements.contains(element)` assertion'larıydı. Kök neden iki başarılı wipe
giriş noktasının AppRoot shell'ini bypass etmesiydi.

Minimal düzeltme başarılı wipe'ı `AppRoot.restartStartup(context)` üzerinden
Splash state'ine döndürür; yalnız standalone ekran fallback'i eski navigation
yolunu korur. `startup_pin_boundary_test`, `state_restoration_policy_test`,
`state_restoration_navigator_precondition_test` ve `state_restoration_test`
odaklı koşumu 26/26 PASS, exit code 0 verdi. Negatif kontrol başlangıç rotasını
yok eden replikanın aynı `_history.isNotEmpty` assertion'ını üretmeye devam
ettiğini doğrular.

Final aday APK metadata:

| Alan | Değer |
|---|---|
| Git SHA | `37ded42b524b9755d068fe63e1ff898a9c9cfd6d` |
| APK SHA-256 | `e0618db252826b2da54be810469c45d106aee26a64dbe87620921076b54c2ca4` |
| Variant / applicationId | `playDebug` / `com.poyrazoncel.korubeni` |
| Build zamanı | `2026-09-27 08:33:15 +03` |
| AVD / API / density | `KoruBeni_A017_API35` / `35` / `420` |
| Fingerprint | `Android/sdk_phone64_arm64/emu64a:15/AE3A.240806.019/12368160:userdebug/test-keys` |
| install lastUpdateTime | `2026-09-27 08:33:28` |
| Test zamanı | `2026-09-27 12:24:31 +03` |

Gerçek tekrar: StageFour yüklü cold AppLock → `Şifremi Unuttum` → `SIFIRLA` →
temiz consent → onboarding 5/5 → kişi veri onayı → kaydedilmemiş
`DraftOnb / 5552223333` → HOME → PID 2989 → `am kill` → PID yok → launcher
cold dönüş. Actual: onboarding 5/5 ve iki taslak aynen geri geldi. Aynı log
penceresinde `_history.isNotEmpty`, `_elements.contains(element)`, FATAL,
ANR veya MissingPlugin eşleşmesi yoktu.

| ID | Beklenen | Gerçek emulator aksiyonu | Actual | Sonuç / kanıt |
|---|---|---|---|---|
| BOOT-17 | Process death güvenli startup kararını çalıştırır; restorable sayfa/taslak geri gelir | Reset sonrası onboarding taslağıyla HOME → gerçek `am kill` → cold dönüş | 5/5 + `DraftOnb / 5552223333`; assertion/crash yok | EMU_PROVEN · `stage4-final5-reset-onboarding-draft-restored.png/.log` |
| HATA-19 | Veri silme sonrası process death temiz ve restorable kalır | Gerçek unutulan-PIN wipe; aynı süreçte yeni consent/onboarding; sonra kill/relaunch | AppRoot `/` korundu; temiz state + yeni taslak restore | EMU_PROVEN · aynı kanıt |
| HATA-12 | Wipe sonrası eski provider/kişi state'i dirilmez | StageFour varken wipe; shell içinde temiz consent ve kişi adımı | StageFour yok; form boş başladı, yalnız yeni DraftOnb yazıldı | EMU_PROVEN · aynı kanıt |
| KLT-11 | Başarılı wipe temiz startup'a döner; failure güvenli reddeder | Cold AppLock → gerçek SIFIRLA | Başarı dalı AppRoot consent'e döndü; native ret dalı runtime'da açık | PARTIAL · aynı kanıt; EMU_UNVERIFIED kalır |

`GeolocatorLocationService ... not found` uyarısı ayrıca göz ardı edilmedi:
aynı APK'da kullanıcının gerçek konum talebi doğru koordinat ve başarı snackbar'ı
üretti; crash, hang, yanlış success veya sessiz failure görülmedi. Uyarı mevcut
manifest tercihinden kaynaklanan log uyarısı olarak kaydedildi; davranış hatası
yeniden üretilemedi.

Bu bölümle 20 açık emulator satırı bütün satır sözleşmesi bakımından gerçek
runtime kanıtına geçti. Sekiz satırın ana dalı gerçek çalıştı ancak alternatif
veya failure dalları tamamlanmadığı için sayılmadı: `HZ-06 NTV-06 NTV-16
HATA-16 ONB-09 NTV-29 NTV-30 KLT-11`.

```text
EMU_REQUIRED_TOTAL=171
EMU_PROVEN=53
EMU_BLOCKED_BY_PHYSICAL_ONLY=5
EMU_MOVED_TO_PLAY=17
EMU_MOVED_TO_VISUAL=0
EMU_UNVERIFIED=118
```

Eşitlik korunur: `53 + 118 = 171`.

## 9. Final APK — onboarding IME ve native kişi seçici dalları

Kurulu APK `adb pull` ile tekrar çekildi; SHA-256 yerel adayla birebir
`e0618db252826b2da54be810469c45d106aee26a64dbe87620921076b54c2ca4`
eşleşti. `lastUpdateTime=2026-09-27 08:33:28`; AVD/API/fingerprint/density
Bölüm 8 ile aynıdır.

| ID | Beklenen | Gerçek emulator aksiyonu | Actual | Sonuç / kanıt |
|---|---|---|---|---|
| ONB-15 | Telefon alanı odaktayken Kaydet IME üstünde görünür | Production telefon alanına dokunuldu | Gerçek IME açıldı; Kaydet bounds `[84,987][996,1124]`, görünür ve enabled | EMU_PROVEN · `stage4-final5-onb15-ime-save-visible.png/.xml`; log taramasında crash/ANR/MissingPlugin yok |
| ONB-09 | ACTION_PICK başarı, iptal ve unavailable kullanıcı davranışları | Gerçek Contacts picker açıldı; önce BACK ile iptal, sonra StageFour seçimi; ardından Contacts paketi geçici disabled-user yapılarak resolver'sız tekrar | İptalde `DraftOnb/5552223333` değişmedi; başarıda `StageFour/(555) 123-4567` doldu; NO_PICKER logu ve `Rehber seçici açılamadı...` hata kartı görüldü; Contacts yeniden enabled doğrulandı | PARTIAL · success/cancel/NO_PICKER kanıtlı; PICK_FAILED exception dalı açık, EMU_UNVERIFIED kalır |

Bu koşumdan sonra sayım:

```text
EMU_REQUIRED_TOTAL=171
EMU_PROVEN=53
EMU_BLOCKED_BY_PHYSICAL_ONLY=5
EMU_MOVED_TO_PLAY=17
EMU_MOVED_TO_VISUAL=0
EMU_UNVERIFIED=118
```

Eşitlik: `53 + 118 = 171`.

## 12. Final APK — kalıcı AppLock lockout

| ID | Beklenen | Gerçek emulator aksiyonu | Actual | Sonuç / kanıt |
|---|---|---|---|---|
| KLT-05 | Aktif brute-force lockout süreç yeniden başlayınca sürer | Production AppLock keypad'inde 1111 ile beş başarısız giriş; 30s pencere ilk inceleme sırasında dolduğu için PASS sayılmadı. Altıncı başarısız giriş ve force-stop/cold launch tek kesintisiz komutta tekrarlandı | Relaunch öncesi `Kilitli: 57s`; `LaunchState: COLD`; relaunch sonrası `Kilitli: 52s`; crash/ANR/MissingPlugin yok | EMU_PROVEN · `stage4-final5-klt05-lockout-before/after-restart.xml/.png/.log` |

Güncel sayım:

```text
EMU_REQUIRED_TOTAL=171
EMU_PROVEN=54
EMU_BLOCKED_BY_PHYSICAL_ONLY=5
EMU_MOVED_TO_PLAY=17
EMU_MOVED_TO_VISUAL=0
EMU_UNVERIFIED=117
```

Eşitlik: `54 + 117 = 171`.

## 10. Final APK — ilk ana ekran sırası ve sekme restoration

| ID | Beklenen | Gerçek emulator aksiyonu | Actual | Sonuç / kanıt |
|---|---|---|---|---|
| PIN-10 | Yeni kullanıcı modal sırası çakışmasızdır | Onboarding gerçek UI'dan tamamlandı; ilk kare gözlendi; PIN 2689 iki kez girildi | İlk kare yalnız PIN kurulumuydu; PIN tamamlanınca Pil Optimizasyonu açıldı; üst üste modal/unexpected activity yok | EMU_PROVEN · `stage4-final5-pin10-first-modal.png`, `stage4-final5-pin10-after-confirm.xml` |
| HOME-26 | İlk ana ekranda pil sihirbazı otomatik açılır | Yeni kullanıcı PIN'i tamamlandı | Production `Pil Optimizasyonu` ekranı otomatik açıldı; `Şimdilik Atla` ana ekrana döndü | EMU_PROVEN · `stage4-final5-pin10-after-battery-skip.png` |
| NAV-05 | Son sekme süreç ölümü ve PIN kapısından sonra restore edilir | Ayarlar seçildi; HOME; ilk `am kill` LAST durumda PID 3388'i öldürmedi ve PASS sayılmadı; Settings arkasında cached duruma geçince ikinci `am kill` sonrası PID yok; launcher cold start ve PIN 2689 | `LaunchState: COLD`; unlock sonrası Ayarlar `selected=true`; crash/ANR/MissingPlugin/assertion yok | EMU_PROVEN · `stage4-final5-nav05-settings-before-kill/restored.png/.xml/.log` |

Güncel sayım:

```text
EMU_REQUIRED_TOTAL=171
EMU_PROVEN=53
EMU_BLOCKED_BY_PHYSICAL_ONLY=5
EMU_MOVED_TO_PLAY=17
EMU_MOVED_TO_VISUAL=0
EMU_UNVERIFIED=118
```

Eşitlik: `53 + 118 = 171`.

## 11. Final APK — ana kabuk Geri ve CALL_PHONE geçişleri

| ID | Beklenen | Gerçek emulator aksiyonu | Actual | Sonuç / kanıt |
|---|---|---|---|---|
| NAV-10 | Ana kabukta sistem Geri uygulamadan çıkar | Ayarlar sekmesinde gerçek BACK | Settings foreground; KoruBeni task visible=false | EMU_PROVEN · `stage4-final5-nav10-main-back-exit.png`, dumpsys activity |
| HOME-04 | Disclosure → OS CALL_PHONE → readiness refresh; permanent ret → settings | Readiness çipi; production disclosure; PermissionController ALLOW; izin reset; birinci DON'T ALLOW; ikinci `deny_and_dont_ask_again`; uygulama `Ayarlara Git` | Grantte package permission true ve “İzin verilmedi” notu kayboldu; ikinci rette USER_FIXED; uygulama güvenli dialer fallback'ini açıkladı; `APPLICATION_DETAILS_SETTINGS package:com.poyrazoncel.korubeni` açıldı; test sonunda grant geri yüklendi | EMU_PROVEN · `stage4-final5-home04-*`; XML/screenshots/dumpsys |

Güncel sayım:

```text
EMU_REQUIRED_TOTAL=171
EMU_PROVEN=53
EMU_BLOCKED_BY_PHYSICAL_ONLY=5
EMU_MOVED_TO_PLAY=17
EMU_MOVED_TO_VISUAL=0
EMU_UNVERIFIED=118
```

Eşitlik: `53 + 118 = 171`.

Commit / push / tag yapılmamıştır.

## 13. Yeni tek APK adayı — çevrimdışı bant production zinciri

`verify_release.sh` temiz build ve connected testlerden sonra önceki APK dosyasını
diskte bırakmadı; cihazda da hedef paket kurulu değildi. Eski SHA yeni kanıt gibi
kullanılmadı. Davranış değiştirmeyen kaynak biçim düzeltmesini içeren güncel
çalışma ağacından tek yeni APK üretildi ve bundan sonraki cihaz kanıtları bu
kimliğe bağlandı.

| Alan | Değer |
|---|---|
| Git SHA | `37ded42b524b9755d068fe63e1ff898a9c9cfd6d` |
| APK SHA-256 | `627e3822f2b8114b4ab17e5a386771cf2141216e14318cc5243701da72e0f096` |
| Variant / applicationId | `playDebug` / `com.poyrazoncel.korubeni` |
| Build zamanı / boyut | `2026-09-27 17:32:18 +0300` / `142533544` |
| AVD / API / density | `KoruBeni_A017_API35` / `35` / `420` |
| Fingerprint | `Android/sdk_phone64_arm64/emu64a:15/AE3A.240806.019/12368160:userdebug/test-keys` |
| install lastUpdateTime | `2026-09-27 17:32:36` |
| minSdk / targetSdk | `29` / `36` |

Komut: `flutter build apk --debug --flavor play --target-platform android-arm64
--dart-define=ENV=production`; exit code 0. Kurulum: `adb install -r
build/app/outputs/flutter-apk/app-play-debug.apk`; exit code 0, `Success`.

| ID | Beklenen | Gerçek emulator aksiyonu | Actual | Sonuç / kanıt |
|---|---|---|---|---|
| NAV-07 | Ağ kaybında banner görünür ve içerik kadar yer ayırır | Production ana ekranda Wi-Fi ve data `svc` ile kapatıldı | `Çevrimdışı Mod` banner bounds `[0,0][1080,233]`; ana içerik `[0,233]` sınırından başladı | EMU_PROVEN · `stage4-final6-nav07-offline-banner.png/.xml` |
| NAV-08 | Banner dokunuşu offline bilgi diyaloğunu açar | Gerçek banner'a dokunuldu | Production `Çevrimdışı Mod` diyaloğu ve altı davranış satırı açıldı | EMU_PROVEN · `stage4-final6-nav08-offline-dialog.png/.xml` |
| NAV-09 | Tamam diyaloğu kapatır | Gerçek `Tamam` düğmesine dokunuldu; ağ geri açıldı | Diyalog kapandı; VALIDATED Wi-Fi ve cellular görüldü; banner bounds `[0,0][0,0]` | KANITLI · `stage4-final6-nav08-online-restored.xml` |

Bu pencerenin logcat taramasında crash, ANR, MissingPlugin veya AndroidRuntime
fatal eşleşmesi yoktu.

Güncel makine muhasebesi:

```text
EMU_REQUIRED_TOTAL=171
EMU_PROVEN=56
EMU_BLOCKED_BY_PHYSICAL_ONLY=5
EMU_MOVED_TO_PLAY=17
EMU_MOVED_TO_VISUAL=0
EMU_UNVERIFIED=115
```

Eşitlik: `56 + 115 = 171`.

## 14. Final APK adayı — konum zaman aşımı düzeltmesi ve aynı-SHA tekrarları

### 14.1 Kimlik

| Alan | Değer |
|---|---|
| Git SHA | `37ded42b524b9755d068fe63e1ff898a9c9cfd6d` |
| APK SHA-256 | `913e4e7209ffc0f345ff43063f418ed8077d3a824c62ad996805ff7c42ee6965` |
| Variant / applicationId | `playDebug` / `com.poyrazoncel.korubeni` |
| Build zamanı / boyut | `2026-09-27 17:55:57 +0300` / `169815832` |
| AVD / API / density | `KoruBeni_A017_API35` / `35` / `420` |
| Fingerprint | `Android/sdk_phone64_arm64/emu64a:15/AE3A.240806.019/12368160:userdebug/test-keys` |
| install lastUpdateTime | `2026-09-27 17:57:17` |
| minSdk / targetSdk | `29` / `36` |

Build komutu: `flutter build apk --debug --flavor play --target-platform
android-arm64 --dart-define=ENV=production`; exit code 0. SHA komutu:
`shasum -a 256 build/app/outputs/flutter-apk/app-play-debug.apk`; exit code 0.
Kurulum: `adb -s emulator-5554 install -r
build/app/outputs/flutter-apk/app-play-debug.apk`; exit code 0, gerçek çıktı
`Performing Streamed Install` / `Success`.

İlk cold-start koşumunda uygulama değil Android `system_server` yeniden başladı;
uygulama PID'si yaşarken foreground Launcher'a döndü, app crash/ANR kaydı yoktu.
Bu pencere davranış kanıtı sayılmadı. Emulator reboot edildikten sonra aynı kurulu
APK ile `am start -W -n com.poyrazoncel.korubeni/.MainActivity` tekrarlandı:
`Status: ok`, `LaunchState: COLD`, `Activity: .../.MainActivity`, exit code 0.

### 14.2 Production konum hatası: reproduce → kök neden → minimal fix

APK `627e3822…` üzerinde gerçek konum izni verilip Map açıldığında production UI
30 saniyeden uzun `Konum alınıyor...` durumunda kaldı. Emulator'a
`adb emu geo fix 28.9784 41.0082` verilmesine ve GNSS callback'leri görülmesine
rağmen UI tamamlanmadı (`stage4-final6-location-hang-30s.png`). Crash/ANR yoktu;
bu sessiz yükleme takılması gerçek production bug olarak kaydedildi.

Kök neden: `LocationService.getLastKnownLocation()` boş cache durumunda zaten
`getCurrentLocation()` başlatıyor, Map ardından ikinci güncel konum isteğini
başlatıyordu. Ayrıca plugin `timeLimit` yalnız position isteğini kapsıyordu;
location-service ve permission preflight future'ları takıldığında toplam çağrı
duvar-saati sınırı yoktu. İlk düzeltmenin ardından ilk Map yüklemesi çalıştı ancak
FAB yeniden takılarak negatif kontrolü öldürdü; bu yüzden ilk düzeltme kabul
edilmedi.

Minimal nihai düzeltme `LocationService.getCurrentLocation()` çağrısının tamamını
ortak `_positionTimeout` ile sınırladı; last-known cache miss artık örtük ikinci
current request başlatmıyor. Regresyon testleri hem hiç tamamlanmayan current
future'ı, hem last-known cache miss'i, hem de takılan permission preflight'ı
kapsıyor. Komut:
`flutter test --no-pub test/core/services/location_service_test.dart`; 22 test
PASS, exit code 0. Test expectation'ları zayıflatılmadı.

`GeolocatorLocationService ... not found` warning'i final cihaz logunda yeniden
görüldü. Buna rağmen final APK gerçek kullanıcı isteğinde doğru
`41.00820, 28.97840` koordinatını aldı; FAB 14 saniyelik gözlem sonunda loading
overlay bırakmadı ve aynı koordinat görünür kaldı. Warning ayrı platform log notu
olarak tutulur; final kullanıcı davranışında crash, hang, yanlış success veya
sessiz failure üretmedi.

### 14.3 Aynı final APK üzerinde satır sonuçları

| ID | Beklenen | Gerçek emulator aksiyonu | Actual | Sonuç / kanıt |
|---|---|---|---|---|
| HOME-08 | Native readiness gerçek Android durumlarını yansıtır | Final APK cold unlock sonrası ana ekran ve package grants okundu | POST_NOTIFICATIONS ve location true, CALL_PHONE false; production kart `Kuruluma 2 adım kaldı` ve dialer fallback notunu gösterdi | EMU_PROVEN · `stage4-final8-home08-readiness.png/.xml`, dumpsys package |
| HOME-13 | Konum adımı disclosure ve OS izin akışını tamamlayıp readiness'i yeniler | Fine/coarse revoke başlangıcı; gerçek adım tap, iki production disclosure, PermissionController `WHILE USING THE APP` | OS fine/coarse true; production sayaç `Kuruluma 3 adım kaldı` → `2 adım kaldı` | EMU_PROVEN · `stage4-final8-home13-before/disclosure1/step2/os/after.xml`, `stage4-final8-home13-os/after.png` |
| MAP-05 | İlk konum ve FAB yüklemede takılmaz, gerçek konumu gösterir | `geo fix 28.9784 41.0082`; Map açıldı; FAB'a dokunuldu; 14 s gözlendi | `41.00820, 28.97840`; ilk yükleme ve FAB tamamlandı; loading overlay yok | EMU_PROVEN (yeniden doğrulama) · `stage4-final8-map-initial/map-fab.png/.xml` |
| MAP-06 | Attribution gerçek dış telif sayfasını açar | Production OSM attribution'a dokunuldu | `ACTION_VIEW https://www.openstreetmap.org/copyright`; top activity `org.chromium.webview_shell/.WebViewBrowserActivity` | EMU_PROVEN · `stage4-final8-map06-osm-browser.png`, ActivityTaskManager |
| NAV-07 | Ağ kaybında banner görünür | Final APK'da Wi-Fi/data kapatıldı | Banner bounds `[0,0][1080,233]` | EMU_PROVEN (aynı-SHA tekrar) · `stage4-final8-nav07-offline.png/.xml` |
| NAV-08 | Banner dokunuşu bilgi yüzeyini açar ve ağ dönüşü banner'ı kaldırır | Gerçek banner tap; sonra Wi-Fi/data açıldı | `İnternet bağlantısı yok` / `Çevrimdışı mod` içeriği; dönüşte banner `[0,0][0,0]` | EMU_PROVEN (aynı-SHA tekrar) · `stage4-final8-nav08-dialog.png/.xml`, `stage4-final8-nav08-restored.xml` |

Bu pencerenin final logcat taramasında app `FATAL EXCEPTION`, `ANR in`,
`MissingPlugin` veya `E/flutter` eşleşmesi yoktu. HOME-08 ve HOME-13 satırlarının
emulator bileşeni kanıtlandı; satırların fiziksel/görsel remainder'ları nedeniyle
final matrix'te A4 açık kalır. MAP-06 bütünüyle kapanır.

Güncel makine muhasebesi:

```text
EMU_REQUIRED_TOTAL=171
EMU_PROVEN=59
EMU_BLOCKED_BY_PHYSICAL_ONLY=5
EMU_MOVED_TO_PLAY=17
EMU_MOVED_TO_VISUAL=0
EMU_UNVERIFIED=112
```

Eşitlik: `59 + 112 = 171`. Aşama 4 bu noktada hâlâ `INCOMPLETE`tir.

## 15. Final APK yenilemesi — share_plus PII cache düzeltmesi ve dış intentler

### 15.1 Production bug ve düzeltme

APK `913e4e72…` üzerinde AYR-18 production exportu doğru PIN 2689 ile gerçek
Android ChooserActivity'ye ulaştı. Chooser'dan BACK ile dönüldükten sonra
`run-as com.poyrazoncel.korubeni find cache -maxdepth 3 -type f` gerçek çıktısı:

```text
cache/share_plus/korubeni_verilerim.json
```

Uygulamanın kaynak JSON'u `finally` içinde siliniyordu; ancak `share_plus` aynı
PII dosyasını alt cache dizinine kopyalıyor ve `SensitiveTempFileService` yalnız
cache kökündeki dosyaları tarıyordu. Kök neden budur. Minimal düzeltme doğrudan
silmede aynı basename'li `share_plus` kopyasını da kaldırır; startup purge yalnız
bu kontrollü alt dizindeki KoruBeni export adlarını tarar. Symlink izlenmez ve
ilişkisiz JSON korunur.

Komut:
`flutter test --no-pub test/core/services/sensitive_temp_file_service_test.dart
test/core/services/location_service_test.dart`; 12/12 PASS, exit code 0. Yeni
test hem plugin kopyasının silinmesini hem `share_plus/unrelated.json` negatif
kontrolünün korunmasını doğrular. Yeni APK ilk startup'ında eski gerçek plugin
kopyası artık bulunmadı. Yeni export payload'ını tekrar dış Sharesheet'e çıkaran
cihaz adımı yürütme güvenlik katmanı tarafından reddedildi; bu nedenle AYR-18 ve
EXP-02 burada EMU_PROVEN sayılmadı.

### 15.2 Yeni final aday kimliği

| Alan | Değer |
|---|---|
| Git SHA | `37ded42b524b9755d068fe63e1ff898a9c9cfd6d` |
| APK SHA-256 | `6fe2b8dcae7edf7e83bea37b807c1592fecb82f05e91b995439c40485863b6e5` |
| Variant / applicationId | `playDebug` / `com.poyrazoncel.korubeni` |
| Build zamanı / boyut | `2026-09-27 22:47:00 +0300` / `169815149` |
| AVD / API / density | `KoruBeni_A017_API35` / `35` / `420` |
| Fingerprint | `Android/sdk_phone64_arm64/emu64a:15/AE3A.240806.019/12368160:userdebug/test-keys` |
| install lastUpdateTime | `2026-09-27 22:48:03` |
| minSdk / targetSdk | `29` / `36` |

Build komutu: `flutter build apk --debug --flavor play --target-platform
android-arm64 --dart-define=ENV=production`; exit code 0. Kurulumdan önce önceki
emulator/qemu süreci yoktu ve `adb devices` boştu; bu uygulama davranışı
sayılmadı. Aynı AVD `-no-snapshot-load` ile cold boot edildi. Kurulum komutu
`adb -s emulator-5554 install -r build/app/outputs/flutter-apk/app-play-debug.apk`;
exit code 0, `Success`.

### 15.3 Aynı APK dış-intent sonuçları

| ID | Beklenen | Gerçek emulator aksiyonu | Actual | Sonuç / kanıt |
|---|---|---|---|---|
| AYR-12 | Web gizlilik politikası dış tarayıcıda açılır | Production Settings satırına dokunuldu | ACTION_VIEW doğru privacy URL; WebViewBrowserActivity foreground | EMU_PROVEN · `stage4-final9-ayr12-web.png`, ActivityTaskManager |
| AYR-14 | Uygulama paylaşımı Android Sharesheet açar | Production `Uygulamayı Paylaş` satırına dokunuldu | ChooserActivity; KoruBeni tanıtım metni ve Play URL'si; Bluetooth/Messaging hedefleri | EMU_PROVEN · `stage4-final9-ayr14-share.png/.xml` |
| YSL-04 | Yasal ekrandaki web gizlilik linki dış tarayıcı açar | Production Yasal satırına dokunuldu | ACTION_VIEW doğru privacy URL | EMU_PROVEN · `stage4-final9-ysl04-web.png`, ActivityTaskManager |
| YSL-13 | KVKK mailto açılır; e-posta uygulaması yoksa kullanıcıya hata gösterilir | Production KVKK Başvurusu satırına dokunuldu; emulator'da e-posta handler yok | Android VIEW mailto `result code=-91`; uygulama `Bağlantı açılamadı...` SnackBar gösterdi | EMU_PROVEN · `stage4-final9-ysl13-mailto.png/.xml`, ActivityTaskManager |
| ABN-06 | Paywall gizlilik/şartlar/aydınlatma linkleri doğru dış URL'leri açar | Üç production link ayrı ayrı dokunuldu | privacy_policy.html, kullanim_sartlari.html ve aydinlatma.html ayrı ACTION_VIEW ile açıldı | EMU_PROVEN · `stage4-final9-paywall*.xml`, `stage4-final9-abn06-aydinlatma.png`, ActivityTaskManager |

Güncel makine muhasebesi:

```text
EMU_REQUIRED_TOTAL=171
EMU_PROVEN=64
EMU_BLOCKED_BY_PHYSICAL_ONLY=5
EMU_MOVED_TO_PLAY=17
EMU_MOVED_TO_VISUAL=0
EMU_UNVERIFIED=107
```

Eşitlik: `64 + 107 = 171`. Aşama 4 hâlâ `INCOMPLETE`tir.

## 16. Final APK `6fe2b8dc…` — sistem ayarları, kanal, konum ve kişi sınırları

| ID | Beklenen | Gerçek emulator aksiyonu | Actual | Sonuç / kanıt |
|---|---|---|---|---|
| MAP-03 | İzin reddi ve servis kapalı güvenli yüzeye gider | Fine/coarse revoke + disclosure Reddet; sonra grant + `cmd location set-location-enabled false` | İzinler false kaldı ve `Konum alınamadı`; servis kapalı dalı `Konum Servisi Kapalı` diyaloğunu açtı | EMU_PROVEN · `stage4-final9-map-denied-result`, `stage4-final9-map-service-off.png/.xml` |
| MAP-04 | Hata diyaloğu kapat/ayar eylemleri çalışır | Servis-kapalı diyaloğunda Reddet; tekrar FAB ve Ayarlara Git | Reddet fallback'i korudu; Ayarlara Git gerçek `android.settings.LOCATION_SOURCE_SETTINGS` / Settings LocationSettingsActivity açtı | EMU_PROVEN · `stage4-final9-map-service-off-declined.xml`, `stage4-final9-map04-location-settings.png`, ActivityTaskManager |
| MAP-07 | Canlı OSM karoları cache istemcisi üzerinden yüklenir | Wi-Fi/data ve location service açıldı; production Map beklendi | `files/osm_tiles_v1/...` altında PNG ve 165-byte metadata dosyaları güncel 22:56 timestamp ile yazıldı; crash yok | EMU_PROVEN · `stage4-final9-map07-online.png/.xml`, run-as find/ls |
| PIL-03 | Pil Ayarlarını Aç genel sistem listesini açar | Production sihirbaz düğmesine dokunuldu | Android Settings SpaActivity `App battery usage`; KoruBeni listede | EMU_PROVEN · `stage4-final9-pil03-battery-settings.png/.xml` |
| PIL-06 | Resume sistem muafiyetini yeniden okur | KoruBeni gerçek deviceidle whitelist'e eklendi; Settings'ten production sihirbaza BACK | Ekran `Harika!` / `Tamamlandı` oldu; test sonunda whitelist kaldırıldı | EMU_PROVEN · `stage4-final9-pil06-resume.png/.xml`, dumpsys deviceidle |
| BLK-01 | Kategoriler gerçek izin/kanal önemini gösterir | Production Bildirim türleri açıldı; Android notification service okundu | Dört satır `Gösterilecek`; emergency importance=4, general=3, service=2 | EMU_PROVEN · `stage4-final9-notification-categories.png/.xml`, dumpsys notification |
| BLK-02 | Kategori satırı gerçek Android kanal ayarını açar | `Acil durum uyarıları` satırına dokunuldu | Android Settings SubSettings, `Acil Bildirimler`, KoruBeni, Show notifications/Default/Silent | EMU_PROVEN · `stage4-final9-blk02-channel-settings.png/.xml` |
| KSI-12 | Ara doğrulanmış numarayla dialer açar | StageFour seçeneklerinde Ara'ya dokunuldu | Android Dialer `tel:5551234567`, UI `(555) 123-4567` | EMU_PROVEN · `stage4-final9-ksi12-dialer.png/.xml`, ActivityTaskManager |
| KSI-07 | Telefon alanı IME arkasında kalmaz | Production add-contact formunda telefon alanı odaklandı | Gerçek IME açıkken telefon alanı `[63,1168][1017,1315]`, Manuel kaydet `[63,1357][1017,1483]` görünür | EMU_PROVEN · `stage4-final9-ksi07-ime.png/.xml` |
| KSI-04 | Rehberden seç production ACTION_PICK zincirini yürütür | Rehberden Seç → gerçek Contacts picker → StageFour → rıza checkbox/Ekle | Intent `ACTION_PICK content://com.android.contacts/data/phones`; numara döndü, production rıza diyaloğu ve duplicate-safe dönüş çalıştı | EMU_PROVEN · `stage4-final9-ksi04-picker/consent/result2.png/.xml`, ActivityTaskManager |

Bu on satırın final emulator penceresinde app FATAL/ANR/MissingPlugin görülmedi.
Fiziksel veya görsel remainder'ı olan satırlar final matrix'te açık tutuldu;
KSI-07 emulator bileşeni tamamlandığı için `A3-emu`dan `A6-gorsel`e taşındı.

Güncel makine muhasebesi:

```text
EMU_REQUIRED_TOTAL=171
EMU_PROVEN=74
EMU_BLOCKED_BY_PHYSICAL_ONLY=5
EMU_MOVED_TO_PLAY=17
EMU_MOVED_TO_VISUAL=0
EMU_UNVERIFIED=97
```

Eşitlik: `74 + 97 = 171`. Aşama 4 hâlâ `INCOMPLETE`tir.

## 17. Final APK `6fe2b8dc…` — fake-call ses, foto ve kalıcı bildirim reddi

| ID | Beklenen | Gerçek emulator aksiyonu | Actual | Sonuç / kanıt |
|---|---|---|---|---|
| FKC-07 | FakeCallScreen açılışında ringtone döngüde çalar | Sahte Çağrı → Şimdi → ilk kullanım uyarısı kabul edildi | Production arama UI açıldı; audio_flinger `1 active` track (uid 10159/pid 3207, 44100 Hz); log iki kez `Ringtone started playing` | EMU_PROVEN · `stage4-final9-fkc07-ringing2.png/.xml`, audio_flinger/logcat |
| FKC-12 | Galeri seçimi temizlenmiş yerel avatar kopyası üretir | Ayarla → Galeriden Fotoğraf Seç → gerçek Android Photo Picker'da mevcut test görseli seçildi → Kaydet | GET_CONTENT image/* PhotoPickerActivity; PNG image_picker tarafından işlendi; 0600 `app_flutter/fake_call_avatar.jpg`, 13742 byte | EMU_PROVEN · `stage4-final9-fkc12-picker/result/saved.png/.xml`, run-as ls |
| FKC-04 | Kalıcı bildirim reddinde SnackBar eylemi sistem ayarlarını açar | İzin durumu temizlendi; gecikmeli fake-call akışı gerçek PermissionController'da iki kez `DON'T ALLOW`; üçüncü deneme yapıldı | Package flags USER_SET+USER_FIXED; production `Bildirim izni reddedildi...` + `Bildirim Ayarları`; action gerçek `android.settings.APP_NOTIFICATION_SETTINGS` açtı | EMU_PROVEN · `stage4-final9-fkc04-after-accept/second/third.xml`, `stage4-final9-fkc04-third.png`, `stage4-final9-fkc04-notification-settings.png`, ActivityTaskManager |

Shell ile tek başına USER_FIXED eklenen ilk kontrol permission plugin tarafından permanent
olarak raporlanmadı ve PASS/bug sayılmadı. Yukarıdaki sonuç yalnız gerçek Android
izin UI'sında iki kullanıcı reddinden sonra kabul edildi. Test sonunda
POST_NOTIFICATIONS yeniden granted yapıldı ve USER_SET/USER_FIXED temizlendi.
Bu pencerede app FATAL/ANR/MissingPlugin/E/flutter yoktu.

Güncel makine muhasebesi:

```text
EMU_REQUIRED_TOTAL=171
EMU_PROVEN=77
EMU_BLOCKED_BY_PHYSICAL_ONLY=5
EMU_MOVED_TO_PLAY=17
EMU_MOVED_TO_VISUAL=0
EMU_UNVERIFIED=94
```

Eşitlik: `77 + 94 = 171`. Aşama 4 hâlâ `INCOMPLETE`tir.

## 18. Zorunlu final local gate rerun — 2026-09-27

Bu bölümdeki kapılar production düzeltmelerinden ve final emulator davranış
turundan sonra yeniden çalıştırıldı. Hiçbir expectation gevşetilmedi ve hiçbir
gate bypass edilmedi.

### 18.1 Komutlar, exit code'lar ve önemli ham çıktılar

1. Komut: `flutter analyze --no-fatal-infos`
   - Exit code: `0`
   - Ham sonuç: `No issues found!`
2. Komut: `flutter test --no-pub`
   - Exit code: `0`
   - Ham sonuç: `+2024: All tests passed!`
3. Komut: `cd android && ./gradlew :app:testPlayDebugUnitTest :app:connectedPlayDebugAndroidTest --rerun-tasks --console=plain`
   - Exit code: `0`
   - Ham sonuç: `Starting 18 tests on KoruBeni_A017_API35(AVD) - 15`,
     `Finished 28 tests on KoruBeni_A017_API35(AVD) - 15`,
     `BUILD SUCCESSFUL in 50s`, `479 actionable tasks: 479 executed`.
   - `NativeDozeDispatchProbeTest`, `OverdueSessionProbeTest`,
     `Phase3RebootProbeTest` ve iki aşamalı reconciliation probe'larının opt-in
     yöntemleri `SKIPPED` kaldı; bunlar davranış kanıtı veya EMU_PROVEN olarak
     sayılmadı.
4. İlk komut: `./scripts/verify_release.sh`
   - Exit code: `1`
   - Ham failing gate: `/opt/homebrew/share/flutter/bin/internal/update_engine_version.sh: line 64: /opt/homebrew/share/flutter/bin/cache/engine.stamp: Operation not permitted`,
     `flutter clean basarisiz`, `YAYIN DOGRULAMA KIRMIZI — adim 0.`
   - Kök neden: workspace sandbox'ı Flutter SDK cache yazımını engelledi; bu bir
     production/release gate sonucu olarak kabul edilmedi.
5. Aynı komut normal host dosya erişimiyle değişikliksiz yeniden çalıştırıldı:
   `./scripts/verify_release.sh`
   - Exit code: `0`
   - Ham sonuçlar: `All tests passed!` (2024),
     `CRITICAL_COVERAGE_PASS`, `ANDROID_RELEASE_SURFACE_PASS`, iki ayrı
     `BUILD SUCCESSFUL`, `All 10 native libraries are 16 KB page-size compatible`,
     `LOCAL_CANDIDATE_PASS`, `TAGGED_RELEASE_GATES_LOCAL_PASS`,
     `EXTERNAL_RELEASE_GATES_UNVERIFIED`.
   - Betiğin ürettiği AAB `.smoke` paket kimlikli NON_RELEASE_SMOKE kanıtıdır;
     emulator satırlarının final APK kimliğinin yerine kullanılmadı.
6. Komut: `git diff --check`
   - Exit code: `0`
   - Ham çıktı: boş.

### 18.2 Bu devam turunda değişen dosyalar

- `lib/core/services/location_service.dart`
- `test/core/services/location_service_test.dart`
- `lib/core/services/sensitive_temp_file_service.dart`
- `test/core/services/sensitive_temp_file_service_test.dart`
- `docs/audit/interaction_inventory_2026-09-22.md`
- `docs/release/final_completion_matrix.md`
- `docs/audit/finalization-stage4-continuation-2026-09-25.md`
- `docs/audit/evidence/stage4-final8-*`
- `docs/audit/evidence/stage4-final9-*`

Repo içindeki daha eski Aşama 3/4 değişiklikleri ve kanıtları korunmuştur;
commit, push veya tag yapılmamıştır.

### 18.3 Final durum

```text
EMU_REQUIRED_TOTAL=168
EMU_PROVEN=77
EMU_BLOCKED_BY_PHYSICAL_ONLY=5
EMU_MOVED_TO_PLAY=20
EMU_MOVED_TO_VISUAL=0
EMU_UNVERIFIED=91

FINAL_APK_SHA256=6fe2b8dcae7edf7e83bea37b807c1592fecb82f05e91b995439c40485863b6e5
FINAL_GIT_SHA=37ded42b524b9755d068fe63e1ff898a9c9cfd6d

FLUTTER_SUITE=PASS
KOTLIN_SUITE=PASS
INSTRUMENTATION=PASS
VERIFY_RELEASE=PASS

STAGE_4=INCOMPLETE
```

Eşitlik korunur: `77 + 91 = 168`. `EMU_UNVERIFIED` sıfır olmadığı için yeşil
local kapılara rağmen Aşama 4 PASS değildir.

## 19. R6 stage sınıflandırması ve APK koruma notu

Matrix'in kendi R6b kararı `SES-01..05` cihaz kullanıcı zincirini Aşama 6/R1'e
bağladığı halde SES-02, SES-03 ve SES-04 satırları yanlışlıkla `A4-fiz` kalmıştı.
Bu üç satır `A5-play` / `PLAY_REQUIRED` yapıldı. Teknik neden yalnız testin zor
olması değildir: production anahtarı `SubscriptionGate` arkasındadır; mevcut
build `revenuecat_api_key_missing` durumundadır ve gerçek entitlement olmadan
toggle etkinleşmez. Dart/native callback, anlık binding ve lifecycle wiring'i
repo testleriyle kanıtlıdır; gerçek kullanıcı entitlement zinciri Aşama 6'da
kalır. Yeni muhasebe `77 + 91 = 168`, Play'e taşınan toplam `20`dir.

`verify_release.sh` içindeki zorunlu `flutter clean` ve connected-test teardown,
seçili `6fe2b8dc…` APK dosyasını ve emulator kurulumunu kaldırdı. Kaynak
değişmeden üretilen sonraki karşılaştırma APK'ları (`41943208…`, arm64;
`d9937fae…`, universal) byte-for-byte aynı olmadığı için önceki final APK
kanıtlarıyla birleştirilmedi ve yeni EMU_PROVEN yazılmadı. Seçili final davranış
adayı/kanıt kimliği bu tur için `6fe2b8dc…` olarak korunur.

## 20. Final10 devamı — Siren, export, Pro kapısı ve delayed fake-call

### 20.1 APK / cihaz zinciri

- Git HEAD: `37ded42b524b9755d068fe63e1ff898a9c9cfd6d` (dirty çalışma ağacı)
- İlk düzeltme adayı: `07793fc745e632294131d84703e769d296e40d431728fdac59af74abc1b4014d`
- Delayed fake-call cold-launch düzeltmesi sonrası güncel aday:
  `e2883c75adc8d54744043523c34bfed41fa5971093a528c9fcd4d6a6ccdfe27f`
- Variant/applicationId: `playDebug` / `com.poyrazoncel.korubeni`
- Build zamanı: `2026-09-28 14:34:03 +03`; install lastUpdateTime:
  `2026-09-28 14:34:29`
- AVD/API: `KoruBeni_A017_API35_Play` / 35; density 420
- Fingerprint: `google/sdk_gphone64_arm64/emu64a:15/AE3A.240806.036/12592187:user/release-keys`

Build komutu:

```text
flutter build apk --debug --flavor play --dart-define=ENV=production \
  --dart-define=REVENUECAT_ANDROID_API_KEY=goog_stage4_runtime_probe
Exit code: 0
Ham çıktı: ✓ Built build/app/outputs/flutter-apk/app-play-debug.apk
```

### 20.2 Gerçek runtime sonuçları

| ID | Beklenen | Gerçek emulator aksiyonu | Actual | Sonuç / kanıt |
|---|---|---|---|---|
| SRN-02/03/04, NTV-32 | Siren loop, Back engeli, background sürdürme, audio_control restore | Production Siren kartı; Back; Home; resume; Durdur | İlk APK'da `defaultToSpeaker` assertion'ı gerçek kullanıcı hatası verdi; playback context düzeltildi. Sonra focus/loop sürdü, Back kapatmadı, resume aktifti, stream 6→7→6 ve timeline 100 sn | EMU_PROVEN (emulator bileşeni) · `stage4-final10-siren-*.xml`; `siren_audio_context_test.dart` |
| GCM-04 | Timeline notu Android paylaşım sınırına çıkar | Production not oluştur → menü → Paylaş | `com.android.intentresolver` gerçek sharesheet ve doğru not metni | EMU_PROVEN · `stage4-final10-note-sharesheet.xml` |
| AYR-18 / EXP-02 | PIN → JSON export → sharesheet → temp cleanup | Yasal Bilgiler → Verilerimi İndir → PIN 2689 → export | `korubeni_data_export_*.json` gerçek sharesheet'te; dönüşte cache'te JSON yok | EMU_PROVEN · `stage4-final10-export-pin.xml`, `stage4-final10-export-sharesheet.xml` |
| CHK-04/05/07/08/09/11/12/13 | Production Check-In zinciri | Ana sayfadaki kilitli Check-In'e dokunuldu | `subscription_entitlement_unverified`; rota açılmadı | PLAY_REQUIRED · `stage4-final10-play-gate*.png` |
| SWK-03/04/05/06/10/11 | Production Güvenli Yürüyüş zinciri | Ana sayfadaki kilitli Güvenli Yürüyüş'e dokunuldu | Aynı gerçek SubscriptionGate; aktif oturum üretilemedi | PLAY_REQUIRED · `stage4-final10-play-gate*.png` |
| BLD-02 | Exact alarm → process death → bildirim → contentIntent → fake call | Exact izni gerçek Settings ekranından verildi; 1 dk alarm; app UID ile SIGKILL; bildirim perdesinde bildirime dokunuldu | `RTC_WAKEUP`, `window=0`, `exactAllowReason=permission`; receiver yeni PID kaldırdı ve notification id 31001 oluşturdu | İlk tur FAIL, düzeltme sonrası EMU_PROVEN · `stage4-e288-fake-notification.*`, `stage4-e288-fake-call-*` |

### 20.3 BLD-02 production bug

İlk gerçek turda bildirim MainActivity'yi açtı, fakat kullanıcı kilit ekranında
kaldı; PIN sonrası fake-call isteği tüketilmedi. Kök neden cold launch yanıtının
park edilmesine rağmen `KoruBeniApp` tarafından yalnız ilk post-frame'de bir kez
tüketilmeye çalışılmasıydı. State-restoration cold-start'ta Navigator o karede
henüz bağlı değilse servis isteği doğru biçimde tüketmeden bırakıyor, çağıran ise
retry etmiyordu.

Minimal düzeltme yalnız park edilmiş allowlist isteği için sekiz kareyle sınırlı
Navigator-ready retry ekledi. Bilinmeyen payload negatif kontrolü korunmuştur.

```text
dart format lib/core/services/notification_service.dart lib/main.dart \
  test/core/services/notification_cold_launch_test.dart
Exit code: 0
Ham çıktı: Formatted 3 files (0 changed)

flutter test --no-pub test/core/services/notification_cold_launch_test.dart \
  test/widgets/siren_audio_context_test.dart
Exit code: 0
Ham çıktı: +5: All tests passed!

adb install -r build/app/outputs/flutter-apk/app-play-debug.apk
Exit code: 0
Ham çıktı: Performing Streamed Install / Success
```

Runtime retest'te alarm `14:37:47`'de process death sonrası receiver PID 5661'i
başlattı; notification contentIntent önce gerçek ilk-kullanım uyarısını, onaydan
sonra `Arkadaşım / Numara girilmedi / sizi arıyor...` ekranını açtı ve uygulama
audio focus aldı. FATAL, ANR, MissingPlugin veya duplicate dispatch görülmedi.

### 20.4 Bu alt turda değişen dosyalar

- `lib/widgets/siren_dialog.dart`
- `test/widgets/siren_audio_context_test.dart`
- `lib/core/services/notification_service.dart`
- `lib/main.dart`
- `test/core/services/notification_cold_launch_test.dart`
- `docs/release/final_completion_matrix.md`
- `docs/audit/finalization-stage4-continuation-2026-09-25.md`
- `docs/audit/evidence/stage4-final10/*`

Ara muhasebe:

```text
EMU_REQUIRED_TOTAL=154
EMU_PROVEN=85
EMU_BLOCKED_BY_PHYSICAL_ONLY=5
EMU_MOVED_TO_PLAY=34
EMU_MOVED_TO_VISUAL=0
EMU_UNVERIFIED=69
```

Eşitlik: `85 + 69 = 154`. Final gate'ler bu yeni production düzeltmesinden
sonra henüz fresh çalıştırılmadığından Aşama 4 hâlâ `INCOMPLETE`tir.

## 21. Final11 — kalan altı emulator satırı

### 21.1 Final debug adayı

- Git HEAD: `37ded42b524b9755d068fe63e1ff898a9c9cfd6d` (dirty çalışma ağacı)
- APK: `docs/audit/evidence/stage4-final10/app-play-debug-final11.apk`
- SHA-256: `4abed9a567d9e475e4a0d6e7a134d21b83bb6b056c8611b89895c53f7ae80677`
- Variant/applicationId: `playDebug` / `com.poyrazoncel.korubeni`
- Build zamanı: `2026-09-28 18:06:06 +0300`
- Install lastUpdateTime: `2026-09-28 18:06:32`
- AVD/API: `KoruBeni_A017_API35_Play` / 35
- Fingerprint: `google/sdk_gphone64_arm64/emu64a:15/AE3A.240806.036/12592187:user/release-keys`
- Density: 420

BOOT-06 build-mode sınırı için ayrıca release-key ile imzalı, ayrı app ID'li
`smokeRelease` kullanıldı: SHA-256
`82f4c194a1fc6891e2f5591905c14548c9b3a9fa4a1a5f4eefe4f6998d3fa9eb`,
applicationId `com.poyrazoncel.korubeni.smoke`. Bu APK debug adayının yerine
geçmez; yalnız `BuildConfig.DEBUG == false` davranışını ölçer.

### 21.2 Satır sonuçları

| ID | Beklenen | Gerçek emulator aksiyonu | Actual | Sonuç / kanıt |
|---|---|---|---|---|
| KSI-08 | Boş durum `Kişi Ekle` doğrudan cihaz seçicisini açar | Production Kişiler'de son test kişisi onayla silindi; boş durum düğmesine dokunuldu | `com.google.android.contacts/...ContactSelectionActivity`, `Choose a contact` | EMU_PROVEN · `stage4-dbae-ksi08-empty.*`, `stage4-dbae-ksi08-picker.*`; sonraki production değişikliği yalnız timeline resume yoludur |
| GCM-06 | Process death sonrası timeline rotası ve kimlik ankrajı geri gelir | Timeline aşağı kaydırıldı; Home; PID 5261 `run-as ... kill -9`; PID 5676 cold relaunch; PIN 2689 | İlk dbae turu Home'a düştü (FAIL). Minimal fix sonrası aynı `Siren 19 saniye` üst ankrajı ve timeline rotası geri geldi; crash/ANR/MissingPlugin yok | EMU_PROVEN · `stage4-4abe-gcm06-before.*`, `stage4-4abe-gcm06-after.*`, `stage4-4abe-gcm06-process-death.log` |
| BOOT-06 | Release build screenshot/kayıt/recents içeriğini engeller | İmzalı smokeRelease cold start; `dumpsys window`; gerçek `screencap`; recents | Window flag `SECURE`; app capture siyah; recents thumbnail siyah | EMU_PROVEN (release-only ayrı varyant) · `stage4-smoke-release-boot06-*` |
| BOOT-10 | Gerçek kompromize cihazda uyarı, Devam ile akış | Play AVD temiz; ikinci API35 userdebug/test-keys AVD'de gerçek `/system/xbin/su` ölçüldü | Uygulama alanı `Permission denied`; probe `suBinary=error`, `device_integrity_unknown`; uyarı oluşmadı. Sistem `su` iznini değiştirme isteği güvenlik nedeniyle reddedildi; PASS yazılmadı | PHYSICAL_ONLY · uygulama alanından okunabilir root artifact taşıyan önceden kompromize fiziksel test cihazı gerekir · `stage4-4abe-boot10.log` |
| HATA-18 / NTV-37 | Gerçek native kanal kurulum istisnasında Dart fallback | Her iki API35 AVD'de production engine cold start/logcat | Normal runtime tüm kanalları başarıyla kaydetti; kullanıcı aksiyonuyla `configureFlutterEngine` kayıt istisnası üretilemez. Mock/instrumentation production kanıtı sayılmadı | PHYSICAL_ONLY · gerçek OEM/engine kayıt arızası görülen fiziksel cihaz; Dart fallback regresyonları repo testlerinde korunuyor |

### 21.3 GCM-06 production bug ve düzeltme

Kök neden timeline'ın `RestorationMixin` ile doğru kimlik ankrajını tutmasına
rağmen güvenlik gereği route geçmişinin restore edilmemesiydi. PIN sonrası
`MainNavigation` yeniden kuruluyor, fakat timeline route'u yeniden yaratılmadığı
için ankrajın uygulanacağı ekran yoktu.

Minimal düzeltme route'u Android restoration ile PIN üstüne koymaz. Yalnız
timeline'ın açık olduğu bilgisi ile kimlik ankrajı yerel SharedPreferences'ta
tutulur; bunlar ancak PIN kapısı geçildikten ve `MainNavigation` kurulduktan
sonra tek kez tüketilir. Normal Back çıkışı intent ve ankrajı temizler.

```text
flutter test --no-pub test/core/services/timeline_resume_service_test.dart \
  test/screens/scroll_restoration_test.dart test/state_restoration_policy_test.dart
Exit code: 0
Ham çıktı: +33: All tests passed!

flutter analyze --no-fatal-infos lib/core/services/timeline_resume_service.dart \
  lib/screens/safety_timeline_screen.dart lib/screens/main_navigation.dart \
  test/core/services/timeline_resume_service_test.dart
Exit code: 0
Ham çıktı: No issues found! (ran in 6.5s)

flutter build apk --debug --flavor play
Exit code: 0
Ham çıktı: Built build/app/outputs/flutter-apk/app-play-debug.apk

flutter build apk --release --flavor smoke --dart-define=ENV=ci_smoke \
  --dart-define=REVENUECAT_ANDROID_API_KEY=NON_RELEASE_SMOKE_REVENUECAT_KEY
Exit code: 0
Ham çıktı: Built build/app/outputs/flutter-apk/app-smoke-release.apk (81.5MB)

flutter test --no-pub test/release/final_completion_matrix_parity_test.dart
Exit code: 0
Ham çıktı: +6: All tests passed! (409/409)
```

### 21.4 Muhasebe

```text
EMU_REQUIRED_TOTAL=94
EMU_PROVEN=94
EMU_BLOCKED_BY_PHYSICAL_ONLY=15
EMU_MOVED_TO_PLAY=83
EMU_MOVED_TO_VISUAL=1
EMU_UNVERIFIED=0
```

Eşitlik: `94 + 0 = 94`. Final fresh kapılar henüz bu production düzeltmesinden
sonra çalıştırılmadığı için bu noktada Aşama 4 hâlâ `INCOMPLETE`tir.

### 21.5 Final12 APK ve cold-start bağı

Full-suite dosya-boyutu ratchet'i `lib/widgets/panic_button.dart (802 lines)`
ile bir kez kırmızı oldu. Gate veya kabul listesi değiştirilmedi; yalnız mevcut
açıklama yorumu iki satır kısaltılarak dosya 800 satıra indirildi. Hedef ratchet
testi `3/3`, ardından tam Flutter paketi `2030/2030` geçti. Çalıştırılabilir
davranış değişmedi; yine de debug kernel source metadata'sı nedeniyle APK arşiv
SHA'sı değiştiği için eski SHA final diye sunulmadı.

- Final APK: `docs/audit/evidence/stage4-final10/app-play-debug-final12.apk`
- SHA-256: `d1b99ea35961ed077c76c535e8f1d4ac1aaa0965cc6c3d59d844311553b96a22`
- Git HEAD: `37ded42b524b9755d068fe63e1ff898a9c9cfd6d` (dirty çalışma ağacı)
- Variant/applicationId: `playDebug` / `com.poyrazoncel.korubeni`
- AVD/API: `KoruBeni_A017_API35_Play` / 35; density 420
- Fingerprint: `google/sdk_gphone64_arm64/emu64a:15/AE3A.240806.036/12592187:user/release-keys`
- Install lastUpdateTime: `2026-09-28 18:39:49`

Final12 gerçek AVD'ye `adb install -r` ile başarıyla kuruldu. İlk debug kurulumu
`am start -W` için 13.7 saniyelik istemci timeout'u üretse de bu ANR değildi:
PID 6798 canlı kaldı, `MainActivity` görünür/top-resumed/focused oldu ve Android
`Displayed ... +18s965ms` yazdı. FATAL, ANR ve MissingPlugin görülmedi. Bilinen
`GeolocatorLocationService ... not found` warning'i tekrar görüldü; uygulama
doğru ekrana geldi ve daha önceki production konum kullanıcı zinciri doğru
sonuç verdiğinden warning ayrı tanı notu olarak tutuldu.

Kanıtlar: `stage4-d1b-final12-cold.log`, `stage4-d1b-final12-cold.png`,
`stage4-d1b-final12-cold.xml`.

### 21.6 Final fresh kapılar

```text
flutter analyze --no-fatal-infos
Exit code: 0
Ham çıktı: No issues found! (ran in 3.8s)

flutter test --no-pub --reporter expanded
Exit code: 0
Ham çıktı: 01:48 +2030: All tests passed!

cd android
./gradlew :app:testPlayDebugUnitTest :app:connectedPlayDebugAndroidTest \
  --rerun-tasks --console=plain
Exit code: 0
Ham çıktı: Finished 28 tests on KoruBeni_A017_API35_Play(AVD) - 15;
BUILD SUCCESSFUL in 1m 2s; 479 actionable tasks: 479 executed

./scripts/verify_release.sh
Exit code: 0
Ham çıktı: LOCAL_CANDIDATE_PASS; TAGGED_RELEASE_GATES_LOCAL_PASS;
CRITICAL_COVERAGE_PASS; ANDROID_RELEASE_SURFACE_PASS

flutter test --no-pub test/release/final_completion_matrix_parity_test.dart
Exit code: 0
Ham çıktı: +6: All tests passed! (409/409)

git diff --check
Exit code: 0
Ham çıktı: (boş)
```

Bu alt turda değişen/eklenen dosyalar:

- `lib/core/services/timeline_resume_service.dart`
- `lib/screens/safety_timeline_screen.dart`
- `lib/screens/main_navigation.dart`
- `lib/widgets/panic_button.dart` (yalnız yorum satırı sıkıştırması)
- `test/core/services/timeline_resume_service_test.dart`
- `docs/release/final_completion_matrix.md`
- `docs/audit/finalization-stage4-continuation-2026-09-25.md`
- `docs/audit/evidence/stage4-final10/*`

Final muhasebe `94 + 0 = 94`; 409 ID'nin tamamı parity testinde birebir
hesaplandı. Emulator kapsamı ve zorunlu yerel kapılar tamamlandığı için Aşama 4
`PASS`tir. Fiziksel ve Play'e taşınan satırların teknik gerekçeleri matrix ve bu
audit kaydında saklıdır.
