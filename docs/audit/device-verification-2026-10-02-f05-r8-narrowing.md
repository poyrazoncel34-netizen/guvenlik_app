# Cihaz doğrulaması — F-05 R8 keep kuralı daraltma

**Tarih:** 2026-10-02 · **Bulgu:** F-05 (`docs/audit/security-audit-2026-10-01.md`)

`proguard-rules.pro` içindeki `-keep class com.poyrazoncel.korubeni.** { *; }` kuralı
kaldırıldı. O kural yüzünden `isMinifyEnabled = true` kütüphaneleri küçültüyor ama
uygulamanın kendi kodunu tamamen okunabilir bırakıyordu.

Obfuscation bir güvenlik sınırı **değildir** ve bu değişiklik hiçbir açığı kapatmaz.
Yaptığı şey, tasarım gereği istemci tarafında olan entitlement kapısının tam şeklini ilan
etmeyi bırakmak — bypass maliyeti yalnızca kodun ne kadar kolay okunduğuyla belirlenen tek
şey o.

## Neden bu değişiklik riskliydi

Bir `PendingIntent`, hedef sınıfın adını **zamanlama anında** gömer. R8'in yeniden
adlandırması build'ler arasında kararlı değildir. Yani bir build'in kurduğu alarm, uygulama
güncellendikten sonra ateşlendiğinde daha önce kaydedilmiş adı çözmeye çalışır. O ad
obfuscate edilmişse **hiçbir şey patlamaz**: build başarılı olur, test kızarmaz, log'a
hiçbir şey düşmez — alarm sadece hiç gelmez. Bu uygulamada bunun anlamı, dialing yapmayan
bir Check-In veya Güvenli Yürüyüş süresidir.

## Daraltmadan önce doğrulananlar

| Kontrol | Sonuç |
|---|---|
| `Class.forName` / `javaClass.name` ile sınıf yükleme | **yok** |
| Sınıf adını string olarak saklayan kod | **yok** — `"com.poyrazoncel..."` string'lerinin hepsi intent action'ı veya kanal adı |
| Runtime'da kurulan `ComponentName`'ler | yalnız OEM sistem uygulamaları (Xiaomi `com.miui.securitycenter`, Huawei `com.huawei.systemmanager`), bizim sınıflarımız değil |
| AGP'nin manifest'ten ürettiği keep kuralları | 11 bileşenin **hepsi** için var — `build/app/intermediates/aapt_proguard_file/<variant>/.../aapt_rules.txt` ile doğrulandı, varsayılmadı |

## Ölçüm zemini

| | |
|---|---|
| AVD | `KoruBeni_A017_API35_Play`, API 35, 1080x2400 @420 |
| Build | `--flavor smoke --release` (minified, `isMinifyEnabled=true`) |
| dart-define | `ENV=ci_smoke`, `REVENUECAT_ANDROID_API_KEY=NON_RELEASE_SMOKE_REVENUECAT_KEY` |
| Kurulan paket | `com.poyrazoncel.korubeni.smoke` |
| APK | `build/app/outputs/flutter-apk/app-smoke-release.apk`, 80.5 MB |

## Kanıtlar

### 1. Değişiklik gerçekten bir şey yaptı — R8 mapping

`build/app/outputs/mapping/smokeRelease/mapping.txt`:

```
uygulama sinifi toplam : 88
YENIDEN ADLANDIRILAN   : 74
adi korunan            : 14
```

Adı korunan 14'ün tamamı kasıtlı: manifest'teki 11 bileşen + Flutter kanal arayüzünü
uygulayan 3 sınıf (`EmergencyPlatformHandler`, `EmergencyEventStreamHandler`,
`VolumeButtonDetector`). Daraltmadan önce bu sayı 88/0 idi.

### 2. Kritik adlar minified dex'te duruyor

`dexdump` ile `classes.dex`, `classes2.dex`, `classes3.dex` tarandı. Manifest'teki 11
bileşenin **hepsi** orijinal adıyla mevcut:

```
VAR  MainActivity
VAR  emergency.BootCompletedReceiver        VAR  emergency.CheckInAlarmReceiver
VAR  emergency.ClockChangeReceiver          VAR  emergency.CountdownAlarmReceiver
VAR  emergency.EmergencyFallbackCleanupReceiver
VAR  emergency.EmergencyFallbackDialActivity
VAR  emergency.ExactAlarmPermissionReceiver
VAR  quickaccess.PanicTileService           VAR  quickaccess.PanicWidgetProvider
VAR  quickaccess.QuickPanicTrampolineActivity
```

### 3. Minified build cihazda çalışıyor

Kuruldu ve başlatıldı; `topResumedActivity` KoruBeni. `ClassNotFoundException`,
`NoSuchMethodError` veya `FATAL` yok.

### 4. Tam yayın zinciri

`scripts/verify_release.sh` → exit 0, 5/5 kapı: analyze temiz, tüm testler yeşil,
`CRITICAL_COVERAGE_PASS`, imzalı smoke AAB + `ANDROID_RELEASE_SURFACE_PASS`, Android lint +
Kotlin unit + instrumentation **derlemesi**, 16KB hizalaması, SBOM lisans/notices paritesi.

## Doğrulanmayan — açıkça

- **Güncelleme-sonrası alarm senaryosu cihazda koşulmadı.** Yani "N sürümünde kurulan alarm,
  N+1 sürümüne güncellendikten sonra ateşleniyor" durumu ölçülmedi. Bu senaryo iki ayrı
  build, bir güncelleme ve zamanlanmış bir alarmın beklenmesini gerektirir. Bunun yerine
  **yapısal olarak** kapatıldı: adların korunduğu dex'ten doğrulandı ve
  `test/release_r8_keep_rules_test.dart` keep listesini manifest'ten türeterek sabitliyor.
- **Instrumentation testleri minified build'e karşı koşulmadı.** `testBuildType` debug'dır;
  release'e karşı koşmak build yapılandırması değişikliği gerektirir. Zincir yalnız
  instrumentation'ın **derlendiğini** kanıtlıyor.
- **Acil arama akışı minified build'de uçtan uca denenmedi.** Telefon araması emülatörde
  anlamlı bir sonuç vermez ve smoke build Pro entitlement'ı olmayan bir ortamda koşuyor.

## Tekrarı önleyen kapı

`test/release_r8_keep_rules_test.dart`, keep listesini **manifest'ten türetir**:

- manifest'teki her bileşenin açık bir `-keep class` kuralı olmalı → yeni bir bileşen
  eklenip kuralı unutulursa test kızarır
- geniş wildcard geri gelirse test kızarır (F-05 regresyonunun kendisi)
- Flutter kanal handler'larının arayüz üzerinden korunduğu sabitlenir
- parser'ın kendisi için negatif kontrol: manifest'ten en az 10 bileşen çıkmazsa test kızarır
  (yoksa kapı boş bir kümeyi kontrol ederek sessizce geçerdi)

Mutasyonla sınandı: wildcard geri eklendiğinde ve `CountdownAlarmReceiver` keep'i
silindiğinde test kırılıyor.

Bir not: testin ilk koşumu yanlış kırmızı verdi, çünkü `proguard-rules.pro` artık taşımadığı
kuralı **yorumda anlatıyor** ve düz substring araması onu buldu. Test şimdi yorumları
ayıklıyor; bu, kaynak-metni testlerinin neden dikkatle yazılması gerektiğinin örneğidir.
