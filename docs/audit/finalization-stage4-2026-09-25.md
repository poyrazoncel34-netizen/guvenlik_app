# KoruBeni Finalization — Aşama 4 Android runtime kanıtı

**Tarihsel snapshot sonucu:** `INCOMPLETE`

> **SUPERSEDED / TARİHSEL:** Bu dosya Aşama 4'ün ilk ara snapshot'ıdır ve
> silinmeden korunur. Güncel kapanış sonucu
> [`finalization-stage4-continuation-2026-09-25.md`](finalization-stage4-continuation-2026-09-25.md)
> bölüm 21.6'da kayıtlıdır: `STAGE_4=PASS`, `EMU_PROVEN=94/94`,
> `EMU_UNVERIFIED=0`, final APK SHA-256
> `d1b99ea35961ed077c76c535e8f1d4ac1aaa0965cc6c3d59d844311553b96a22`.
> Bu başlıktaki `INCOMPLETE` daha sonraki bir regression sonucu değildir.

**Zaman:** 2026-09-24–25, Europe/Istanbul

**Baseline Git SHA:** `37ded42b524b9755d068fe63e1ff898a9c9cfd6d`

**Commit/push/tag:** yapılmadı

## Final build kimliği

| Alan | Değer |
|---|---|
| APK | `build/app/outputs/flutter-apk/app-play-debug.apk` |
| SHA-256 | `7ddb50717ab192fe337b910a108c2dece199d09c68a731d37bae5ab1b654ed79` |
| Variant / applicationId | `playDebug` / `com.poyrazoncel.korubeni` |
| Build zamanı / boyut | `2026-09-25 13:49:23 +0300` / `207759537` |
| minSdk / targetSdk / compileSdk | 29 / 36 / 36 |
| AVD | `KoruBeni_A017_API35` |
| API / ABI / density | 35 / arm64-v8a / 420 dpi |
| Fingerprint | `Android/sdk_phone64_arm64/emu64a:15/AE3A.240806.019/12368160:userdebug/test-keys` |
| Final kurulum lastUpdateTime | `2026-09-25 14:08:55` |
| androidTest APK SHA-256 | `8f126348be47df00abcc075fa808dd6da909d39f51f856b3a48cf3ea76a64b5a` |

`KoruBeni_A017_API35_Play` mevcut olsa da `PlayStore.enabled=no`; production-like
user/release-keys imaj diye sunulmadı. Bunun yokluğu tek başına blocker sayılmadı.

## Emu=E yeniden sınıflandırması

Makine çıkarımı eski 193 satırı şu şekilde ayırdı:

- emulator ile gerçekten doğrulanabilir: 171
- `PHYSICAL_ONLY`: 5 — `GS-16 SRN-01 OEM-01 OEM-02 HATA-11`
- `EXTERNAL_PLAY`: 17 — `HZ-07 HZ-10 SES-01 DL-10 CHK-02 SWK-02 AYR-08 AYR-15 DEL-04 ABN-03 ABN-04 ABN-05 ABN-07 ABN-09 ABN-12 HATA-08 HATA-09`
- yalnız görsel/manual: 0 (görsel gerektiren satırlar emulator veya fiziksel gereksinimle birlikteydi)

Teknik gerekçe: fiziksel grupta gerçek SIM/Telecom, hoparlör ve OEM üretici
davranışı gerekir. Play grubunda gerçek entitlement, satın alma, restore,
Customer Center veya Play lisans testçisi gerekir. R6'nın native wiring'i dış
entitlement'ın yerine geçirilmedi.

## Final SHA üzerinde satır kanıtları

| ID | Expected | Gerçek emulator aksiyonu | Actual | Sonuç / kanıt |
|---|---|---|---|---|
| BOOT-01 | gerçek `main()` cold bootstrap | final APK cold açıldı ve temiz kurulum yürütüldü | bootstrap crash/timeout olmadan consent'e ulaştı | PASS, E4-COLD-02 |
| BOOT-07 | recents'ta hassas içerik yok | hassas fake-call ekranında Recents açıldı | görev kartı siyah/beyaz, içerik görünmedi | PASS, `stage4-final-recents-privacy.png` |
| BOOT-09 | native integrity probe | final APK instrumentation probe'u | found/absent/error sözleşmesi döndü, crash yok | PASS, E4-INTEGRITY-02 |
| PIN-01 | PIN yoksa zorunlu setup | onboarding sonrası gerçek PIN kuruldu | requiredSetup tam ekranı açıldı, 2468 kaydedildi | PASS, E4-COLD-02 |
| YDK-01 | ≥120 sn arka planda kilit | uygulama 120 sn üzeri arka planda bırakılıp açıldı | AppUnlockScreen geldi, doğru PIN ile kapandı | PASS, E4-LIFECYCLE-02 |
| NAV-06 | disclosure → OS bildirim izni | ilk prompt reddedildi; sonra Android ayarından açıldı | tekrar otomatik prompt yok, gerçek izin durumu güncellendi | PASS, E4-PERMISSION-02 |
| HOME-05 | Arka plan çipi wizard açar | gerçek Home çipine dokunuldu | BatteryOptimizationWizard açıldı | PASS, E4-READINESS-02 |
| HOME-06 | rıza → gerekçe → location izni | gerçek Konum çipi, disclosure ve OS dialogu | harita gerçek emulator koordinatına geçti | PASS, E4-LOCATION-02 |
| HZ-01 | tile INACTIVE görünür | final APK tile'i SystemUI'da açıldı | `KoruBeni panik` görünür; dokunulmadı | PASS yalnız görünürlük, `stage4-final-quick-settings.png` |
| NTV-01 | exact/inexact scheduler | final APK instrumentation ve 1 dk üretim alarmı | exact window=0; inexact backup sözleşmesi PASS | PASS, E4-ALARM-02 |
| NTV-10 | stale CLAIMED otomatik aranmaz | stale/fresh ARMED ve CLAIMED dört opt-in prob | stale manuel aksiyon, fresh dispatch; kontroller PASS | PASS, E4-STALE-02 |
| NTV-31 | settings MethodChannel gerçek ekran açar | kategori ve uygulama bildirim ayarları açıldı | doğru Android ekranları ve user grant görüldü | PASS, E4-SETTINGS-02 |
| NTV-33 | integrity channel sözleşmesi | kurulu final APK test edildi | gerçek Kotlin channel probe PASS | PASS, E4-INTEGRITY-02 |
| DL-01 | cold VIEW park edilir | `korubeni://open/map` cold başlatıldı | PIN kapısından sonra map tüketildi | PASS, E4-DEEPLINK-02 |
| DL-02 | warm singleTop tüketir | açık uygulamaya `/settings` gönderildi | Settings sekmesine geçti | PASS, E4-DEEPLINK-02 |
| DL-04 | kapılar öncesi link kaybolmaz | cold map linki kilitliyken gönderildi | unlock sonrası tek kez tüketildi | PASS, E4-DEEPLINK-02 |
| DL-06 | `/map` sekme 1 | cold `/map` gönderildi | gerçek map açıldı | PASS, E4-DEEPLINK-02 |
| DL-08 | `/settings` sekme 3 | warm `/settings` gönderildi | gerçek Settings açıldı | PASS, E4-DEEPLINK-02 |
| BLD-01 | 1 dk exact sahte çağrı bildirimi | UI'da 1 dk seçildi, süreç `am kill` ile öldürüldü | id 31001/category call bildirimi yeni süreçte geldi | PASS, E4-FAKECALL-02 |
| BLD-03 | cold notification tap fake call açar | süreç ölüyken gerçek bildirime dokunuldu | first-use sonrası gerçek FakeCallScreen açıldı, duplicate yok | PASS, iki final screenshot |
| FKC-03 | gecikme seçimi BLD-01'i çalıştırır | `1 Dakika Sonra` seçildi | alarm, delivery ve cold action tamamlandı | PASS, E4-FAKECALL-02 |
| MAP-01 | rıza/izin/gerçek konum/kamera | OS location grant + emulator geo 41.0082,28.9784 | ekranda `41.00820, 28.97840` görüldü | PASS, E4-LOCATION-02 |
| PIL-01 | disclosure → sistem muafiyet ekranı | Optimizasyonu kapat seçildi, Android dialogu reddedildi | resume'da durum doğru kaldı; crash/hang yok | PASS, E4-READINESS-02 |
| PRM-02 | Kabul OS izin UI açar | location ve notification disclosure kabul edildi | gerçek Android izin/ayar UI açıldı | PASS, E4-PERMISSION-02 |
| SIF-02 | PIN kapılı native+local reset | iki onay, PIN 2468, silme, force-stop/relaunch | temiz consent; eski PIN/kişi/bildirim durumu dönmedi | PASS, `stage4-final-after-in-app-reset.png` |

Geolocator startup logu hâlâ şu uyarıyı üretir:

```text
Unable to start service Intent {
  cmp=com.poyrazoncel.korubeni/com.baseflow.geolocator.GeolocatorLocationService
}: not found
```

Merged manifest uygulamanın bilinçli `tools:node=remove` kaydını doğruladı.
Plugin foreground service'e bind etmeyi deniyor; buna rağmen gerçek kullanıcı
zincirinde OS izni, current position ve harita kamerası doğru çalıştı. Crash,
hang, yanlış success veya sessiz failure görülmedi. Bu nedenle ürün davranış
FAIL'i değil, ayrı plugin warning olarak bırakıldı.

## Açık emulator satırları

Final SHA'da doğrulanmayan 146 satır şunlardır. İlk 136 ID yeni makine
çıkarımındaki emulator grubundan; son 10 ID eski APK kanıtı final SHA'ya
taşınmadığı için yeniden açılmıştır.

```text
BOOT-02 BOOT-05 BOOT-06 BOOT-08 BOOT-10 BOOT-17 BOOT-18 RIZA-14
ONB-02 ONB-09 ONB-15 PIN-08 PIN-10 KLT-05 KLT-11 KLT-12 YDK-03 YDK-04
NAV-05 NAV-07 NAV-08 NAV-10 HOME-04 HOME-07 HOME-08 HOME-13 HOME-26
PNK-10 PNK-11 PNK-12 GS-02 GS-03 GS-05 GS-06 GS-14 GS-17 GS-23 GS-24
GS-26 SNC-02 SNC-03 SNC-09 SNC-10 HZ-03 HZ-11 SES-02 SES-03 SES-04
NTV-03 NTV-04 NTV-05 NTV-08 NTV-09 NTV-11 NTV-12 NTV-13 NTV-14 NTV-15
NTV-17 NTV-18 NTV-20 NTV-21 NTV-23 NTV-24 NTV-26 NTV-27 NTV-28 NTV-29
NTV-32 NTV-37 NTV-38 DL-05 DL-07 DL-09 DL-11 BLD-02 BLD-05 BLD-06
CHK-04 CHK-05 CHK-07 CHK-08 CHK-09 CHK-11 CHK-12 CHK-13 SWK-03 SWK-04
SWK-05 SWK-06 SWK-10 SWK-11 FKC-04 FKC-07 FKC-12 SRN-02 SRN-03 SRN-04
KSI-04 KSI-07 KSI-08 KSI-12 KSI-17 MAP-03 MAP-04 MAP-05 MAP-06 MAP-07
GCM-04 GCM-06 PIL-03 PIL-06 BLK-01 BLK-02 AYR-12 AYR-14 AYR-18 YSL-04
YSL-13 EXP-02 ABN-06 PRM-01 PRM-03 PRM-04 HATA-01 HATA-02 HATA-03
HATA-04 HATA-06 HATA-10 HATA-12 HATA-14 HATA-15 HATA-17 HATA-18 HATA-19
HZ-02 HZ-04 HZ-05 HZ-06 NTV-06 NTV-07 NTV-16 NTV-30 HATA-13 HATA-16
```

Quick Settings dokunması, widget dokunması ve CALL_PHONE verilmiş gerçek
reconciliation seed'i acil tetik/arama riski taşıdığı için açık kullanıcı onayı
olmadan koşturulmadı. Final APK'da tile görünür; widget provider kayıtlı, fakat
`dumpsys appwidget` final paket için bağlı widget örneği göstermedi. Dolayısıyla
HZ-02/HZ-04/HZ-05/HZ-06 PASS değildir. PACKAGE_REPLACED seed denemesi izin
reddiyle durdu; bu başarısız deneme PASS diye sunulmadı.

## Fresh komutlar ve ham sonuçlar

```text
$ flutter analyze --no-fatal-infos
1 info: unnecessary_import
exit=0

$ flutter test --no-pub
01:39 +2018: All tests passed!
exit=0

$ cd android
$ ./gradlew :app:testPlayDebugUnitTest \
    :app:connectedPlayDebugAndroidTest --rerun-tasks --console=plain
Starting 18 tests on KoruBeni_A017_API35(AVD) - 15
Finished 28 tests on KoruBeni_A017_API35(AVD) - 15
BUILD SUCCESSFUL in 28s
479 actionable tasks: 479 executed
exit=0
```

Gradle hedef APK SHA'sı `43799c39…` olduğu için final Flutter APK yeniden
kuruldu ve aynı androidTest APK ile doğrudan tekrar çalıştırıldı:

```text
$ adb install -r build/app/outputs/flutter-apk/app-play-debug.apk
Success
$ adb install -r -t build/app/outputs/apk/androidTest/play/debug/app-play-debug-androidTest.apk
Success
$ adb shell am instrument -w -r \
    com.poyrazoncel.korubeni.test/androidx.test.runner.AndroidJUnitRunner
Time: 0.822
OK (18 tests)
exit=0
```

18 testin 8'i normal PASS, 10'u opt-in bayrağı olmadığı için assumption skip.
Skip'ler davranış PASS'i sayılmadı. Stale/fresh dört opt-in prob final SHA'da
ayrıca PASS oldu; ilk izinsiz denemelerin `REQUEST_FAILED` çıktısı saklandı ve
başarı diye sunulmadı.

Son kapılar:

```text
$ ./scripts/verify_release.sh
[1/6] flutter analyze (sifir sorun sarti)
info • unnecessary_import • lib/core/services/notification_service.dart:2:8
YAYIN DOGRULAMA KIRMIZI — adim 1.
exit=1

$ git diff --check
exit=0
```

`verify_release.sh` build dizinini temizledi. Kurulu final APK `adb pull` ile
aynı yola geri alındı; boyut `207759537`, SHA-256 yeniden `7ddb5071…` çıktı.
Uyarıyı kaldırmak kaynak durumunu ve yeniden üretilecek APK SHA'yı değiştireceği
için eski runtime kanıtı yeni SHA'ya aktarılmadı. Bu kapı FAIL'dir.

## Muhasebe

```text
EMU_REQUIRED_TOTAL=171
EMU_PROVEN=25
EMU_BLOCKED_BY_PHYSICAL_ONLY=5
EMU_MOVED_TO_PLAY=17
EMU_UNVERIFIED=146
```

## Değişen dosyalar

- `android/app/src/main/kotlin/com/poyrazoncel/korubeni/MainActivity.kt`
- `lib/core/widgets/app_privacy_shield.dart`
- `lib/core/services/notification_service.dart`
- `lib/main.dart`
- `test/widgets/app_privacy_shield_test.dart`
- `test/core/services/notification_cold_launch_test.dart`
- `android/app/src/androidTest/kotlin/com/poyrazoncel/korubeni/emergency/Stage4ReconciliationInstrumentationTest.kt`
- `docs/audit/interaction_inventory_2026-09-22.md`
- `docs/release/final_completion_matrix.md`
- `docs/audit/finalization-stage4-2026-09-25.md`
- `docs/audit/evidence/stage4-2026-09-25/stage4-final-*.png`

Mevcut diğer commit edilmemiş çalışma korunmuştur.

## Karar

`EMU_UNVERIFIED=146`; final SHA üzerinde boot/package/time reconciliation,
Quick Settings/widget trampoline, dialer ve diğer açık emulator satırları
tamamlanmadı. Bu nedenle Aşama 4 `PASS` değildir.
