# Cihaz doğrulaması — 2026-09-22 — A-017 kök (root) tespit probu

**A-017 final statüsü: KISMİ / KAPATILAMADI.**

**Neden:** Android uygulama sandbox'ı nedeniyle bazı gerekli kontroller için
güvenilir yokluk (absence) kanıtı üretilemiyor. `/cache` altındaki su/magisk
yolları EACCES veriyor; `ro.debuggable` ve `ro.secure` uygulamaya kapalı bir
property alanında. Katı kural (yalnızca gözlenmiş yokluk `clean` sonucuna
katkı verir) korunduğu için production-benzeri stok imajda sonuç her açılışta
`unknown`.

**Sağlanan:** Hata ≠ temiz garantisi testlerle ve mutasyonlarla kanıtlandı.
Exception, EACCES, zaman aşımı, null, bozuk cevap, eksik anahtar ve kanal
hatası hiçbir koşulda `clean` üretmiyor.

**Sahibin kararı (2026-09-22, seçenek c):** Katı semantik değiştirilmeyecek.
EACCES için "nötr" istisna eklenmeyecek. `Settings.Global.ADB_ENABLED`,
`ro.debuggable`/`ro.secure` yerine kullanılmayacak (semantik olarak eşdeğer değil).
`unknown` production'da olağan sonuç olarak kabul ediliyor. Uyarı dialog'u
yalnızca `compromised` durumunda açılıyor, `unknown` yerel olarak kaydediliyor.

## Ölçülen yapı

- **Commit:** `a099b4a` + commit edilmemiş çalışma ağacı. Ağaç parmak izi
  (`git diff` + 11 takip edilmeyen dosya, sha256 ilk 16): `11ca6c2ea935fa8b`.
- **Uygulama (kanal ölçümü):** `flutter build apk --debug --flavor play`, derleme
  15:43:32. APK sha256 `308ffc21919d37ae…`. Kurulum kanıtı: `dumpsys package
  com.poyrazoncel.korubeni` → `lastUpdateTime=2026-09-22 15:43:36`. dex içinde
  reviewer düzeltmesinin iş parçacığı adı `device-integrity-probe` doğrulandı.
  Aynı imajda daha önce yapılan bir ölçüm (APK `6ca3f144…`) bu düzeltmelerden
  ÖNCEKİ yapıyla yapıldığı için sonuç olarak kullanılmadı (CERT2-05 tuzağı).
- **Instrumentation:** `:app:connectedPlayDebugAndroidTest`,
  `DeviceIntegrityEmulatorProbeTest`, 2/2 geçti. Uygulama sürecinde ve
  uygulamanın UID'siyle çalışır.

## İmaj 1 — production-benzeri (belirleyici ölçüm)

**AVD:** `KoruBeni_A017_API35_Play` · `system-images;android-35;google_apis_playstore;arm64-v8a` r9
**Parmak izi:** `google/sdk_gphone64_arm64/emu64a:15/AE3A.240806.036/12592187:user/release-keys`
**Yoğunluk:** 420 · `ro.debuggable=0` (adb shell)

Gerçek MethodChannel ölçümü (splash → `DeviceSecurityService` → Kotlin → Dart), 3 soğuk açılış:

| Açılış | Prob süresi | Sonuç | Çökme |
|---|---|---|---|
| 1 | 258 ms | unknown | yok (pid 6887) |
| 2 | 161 ms | unknown | yok (pid 6973) |
| 3 | 243 ms | unknown | yok (pid 7073) |

```
result={suBinary=error, magiskBinary=error, superuserArtifacts=absent, pathSuBinary=absent,
  rwSystemMounts=absent, testKeys=absent, dangerousProps=error, developmentEnvironment=error}
failedPaths=[/cache/su, /cache/magisk]
PROPS snapshotSize=604 ro.debuggable=<missing>(areaReadable=false)
  ro.secure=<missing>(areaReadable=false) service.adb.root=<missing>(areaReadable=true)
```

Yerel kayıtta `device_integrity_unknown` uyarısı var. Dart'ın 3 sn'lik zaman
aşımına hiç ulaşılmadı.

**Neden sürekli `unknown`:**
1. `/cache` dizini `0770 system:cache`; uygulama `lstat` çağrısında EACCES alıyor.
   Katı kural gereği bu `error` sayılıyor.
2. `ro.debuggable` ve `ro.secure` `u:object_r:userdebug_or_eng_prop:s0`
   bağlamında. Uygulama bu property alanını **okuyamıyor**: snapshot'ta bu
   anahtarlar yok ve alan erişilemez. Zorunlu property okunamadığı için
   `dangerousProps=error` ve `developmentEnvironment=error`.
3. `service.adb.root` alanı (`shell_prop`) okunabiliyor, yani oradaki yokluk
   gerçek bir yokluk.

Aynı cihazda eski yol: `safe_device` `isRooted=false`, `ro.debuggable=` ve
`ro.secure=` **boş** döndü. Eski kod aynı property'leri hiç okuyamıyordu ama
bunu "tehlikeli değil" diye yorumluyordu (fail-open).

## İmaj 2 — userdebug (production kanıtı DEĞİL)

**AVD:** `KoruBeni_A017_API35` · `system-images;android-35;default;arm64-v8a`
**Parmak izi:** `Android/sdk_phone64_arm64/emu64a:15/AE3A.240806.019/12368160:userdebug/test-keys` · 420 dpi

Gerçek kanal: 244 ms, `unknown`, çökme yok. Burada ayrıca `/system/xbin`
`0750 root:shell` izinli ve **içinde gerçek bir `su` var** (shell `stat` ile
görüyor). Uygulama EACCES alıyor. Eski `safe_device` bu dosyayı "yok" saydı
(`isRooted=false`).

## D1 — paket kontrolleri gerçekten etkisiz (iki imajda)

`com.topjohnwu.magisk` adlı, kod içermeyen bir dummy APK kuruldu
(`pm list packages` ile görünüyor). Uygulamanın süreci içinden:
`getPackageInfo(com.topjohnwu.magisk)` → `visible=false`. APK'daki RootBeer
0.1.1 için `detectRootManagementApps=false` ve `detectPotentiallyDangerousApps=false`.
Pozitif kontrol olarak uygulamanın kendi paketi için `getPackageInfo` başarılı.
Sonuç: targetSdk 36 ve `<queries>` olmadan bu kontrol hiçbir zaman tetiklenemezdi.

## D2 — native kütüphanenin yol kapsamı

RootBeer `Const.suPaths`'teki 14 dizinin hepsi (hem JNI `checkForRoot` hem
Java `checkForBinary`), PATH'ten türeyen girişler ve safe_device'ın 16 yolu
`DeviceIntegrityProbeTest` içinde tek tek "tespit edilir" diye sabitlendi.
Bir yolu silen mutasyon (K5) testte yakalanıyor. Kaybolan tek şey JNI
katmanının Java hook'larına karşı direnci; sonucu zaten hook'lanabilir Java
metotları üzerinden döndüğü için bu gerçek bir koruma değildi.

## Kalan teknik engel

A-017'nin kapanması için stok, root'suz bir `user/release-keys` cihazda şu üç
sinyal için **gözlenmiş yokluk** gerekiyor. Uygulama sandbox'ından üçü de
gözlenemiyor:

| Kontrol | Gözlem | Neden |
|---|---|---|
| `suBinary` / `magiskBinary` | `/cache/su`, `/cache/magisk` → EACCES | `/cache` `0770 system:cache` |
| `dangerousProps` | `ro.debuggable`, `ro.secure` snapshot'ta yok, alan okunamıyor | `userdebug_or_eng_prop` bağlamı uygulamalara kapalı |
| `developmentEnvironment` | aynı zorunlu property okunamıyor | aynı |

Bu engel kodla değil, platformun izin modeliyle ilgili. Kapatmak için ya
ayrıcalıklı bir doğrulama kaynağı ya da sahibin kural değişikliği gerekiyor.

## Tut / geri al değerlendirmesi (2026-09-22)

Soru şuydu: production'da kalıcı `unknown` üreten yeni Kotlin probu tutulmalı
mı, yoksa HEAD'deki minimal çözüme mi dönülmeli? Minimal çözüm, safe_device
kanalını doğrudan okuyup yalnızca Dart'ta üç değerli sarmalama yapıyordu.

Üç inceleme de **TUT** dedi (kotlin-reviewer, security-reviewer,
flutter-reviewer). CRITICAL/HIGH bulgu yok.

- Minimal çözüm A-017'yi çözmez. EACCES → "yok" dönüşümü safe_device/RootBeer
  Java katmanında, kanal cevabı oluşmadan önce yapılıyor. Dart tarafındaki üç
  değerli sarmalama bu `false` değerini ayırt edemez. userdebug imajdaki
  `/system/xbin/su` kaçırması bunun cihazda yeniden üretilmiş örneği. Geri
  dönmek belgelenmiş bir fail-open'ı yeniden açar.
- Yeni prob hiçbir durumda eski yolun `compromised` dediği yerde `clean`
  demiyor. Kontrol kümesi eskisinin üst kümesi; bırakılan paket kontrolünün
  zaten ölü olduğu D1 ile kanıtlandı.
- Kullanıcıya etkisi ihmal edilebilir. `unknown` dialog açmıyor; prob 161–258 ms
  sürüyor; yerel log satır sınırıyla döndürülüyor.
- Kalan LOW notlar: `lstat` ve mounts okumasının kendi iç zaman aşımı yok
  (Dart'ın 3 sn sınırı ve çağrı başına ayrı iş parçacığı bunu sınırlıyor).
  Kullanılmayan `safe_device` bağımlılığı `pubspec`'te duruyor.
