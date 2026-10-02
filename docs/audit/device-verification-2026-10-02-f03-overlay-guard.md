# Cihaz doğrulaması — F-03 örtüşme (tapjacking) dokunuş politikası

**Tarih:** 2026-10-02 · **Bulgu:** F-03 (`docs/audit/security-audit-2026-10-01.md`)

Bu belge, `warn` / `block` politika ayrımının gerçek bir cihazda çalıştığını kaydeder.
Birim testleri politika haritasını, kiralama aritmetiğini ve kanal çağrısını kanıtlıyordu;
`FLAG_WINDOW_IS_OBSCURED`'in gerçekten set edildiği ve davranışın beklendiği gibi
ayrıştığı **yalnız burada** kanıtlanıyor.

## Ölçüm zemini

| | |
|---|---|
| AVD | `KoruBeni_A017_API35_Play` (Google Play sistem imajı) |
| API | 35 |
| Ekran | 1080x2400, yoğunluk 420 |
| Ölçülen commit | `6bb7361` |
| Kurulan paket | `com.poyrazoncel.korubeni`, versionName 1.0.0 |
| Kurulum parmak izi | `lastUpdateTime=2026-10-02 11:30:04` (`adb shell dumpsys package`) |
| APK SHA-256 | `3f90d494ca88de9664cbd92da9554bb37a698abf8d724f090c2c6e19d98ed40f` |
| Build türü | `--flavor play --debug` |

**Neden debug:** release build'de pencere geneli `FLAG_SECURE` var ve `adb exec-out screencap`
boş kare üretir, yani görsel kanıt alınamaz. Örtüşme kapısı `BuildConfig.DEBUG` ile
koşullanmıyor; `MainActivity.dispatchTouchEvent`, `OverlayTouchGuard` ve Dart tarafı iki
build türünde de aynı. `FLAG_SECURE` farkı bu kapının davranışını değiştirmez.

**Ölçüm teşhis build'iyle yapılmadı.** Teşhis sırasında geçici bir logcat satırı eklendi
(`flags`, `policy`, `obscured` okumak için); aşağıdaki dört vaka o satır KALDIRILDIKTAN ve
APK yeniden derlenip kurulduktan SONRA yeniden koşuldu. CERT2-05 tam olarak bunu şart
koşuyor: ölçülen build, kanıtın bağlandığı build olmalı.

## Örtüşme kaynağı

`com.example.overlayprobe` — depo DIŞINDA tutulan tek aktiviteli bir test APK'si
(`/tmp` altında, commit edilmedi). Pencere:

- `TYPE_APPLICATION_OVERLAY` (type 2038), `appop=SYSTEM_ALERT_WINDOW`, `mOwnerUid=10208`
- `FLAG_NOT_FOCUSABLE | FLAG_NOT_TOUCHABLE`
- tam ekran, alfa 0.08 (düşük opaklık)

**Neden ayrı bir uygulama:** Android `FLAG_WINDOW_IS_OBSCURED`'i aynı UID'den gelen
pencereler için set etmez. KoruBeni'nin kendi süreci içinden açılan bir overlay bu kapıyı
asla tetikleyemezdi, yani bir instrumentation testi bunu doğrulayamaz.

**Neden `FLAG_NOT_TOUCHABLE`:** bu bayrak olmadan overlay penceresi dokunuşu KENDİSİ
yutuyor ve kurban uygulama hiçbir olay görmüyor. Bu probe'un ilk koşumunda tam olarak bu
oldu ve "uyarı çıkmadı" sonucunu üretti; sebep kapı değil, probe'un kendisiydi. Gerçek bir
tapjacking örtüşmesi de dokunuşu alttaki uygulamaya geçirir.

## Ham okuma (teşhis turu)

Geçici log, `MainActivity.dispatchTouchEvent` içinde ACTION_DOWN'da:

```
overlay YOK : flags=0x0 policy=warn  obscured=false
overlay VAR : flags=0x1 policy=warn  obscured=true      <- FLAG_WINDOW_IS_OBSCURED
ayarlar     : flags=0x1 policy=off   obscured=true      <- korumasız yüzey, politika yok
diyalog     : flags=0x1 policy=block obscured=true
```

İki şeyi birden gösteriyor: bayrak gerçekten set ediliyor, ve Dart tarafı her yüzeyin
politikasını doğru gönderiyor (`warn` kilit ekranında, `off` ayarlar listesinde, `block`
sıfırlama diyaloğunda).

## Dört vaka (temiz build)

| # | Yüzey | Politika | Örtüşme | Beklenen | Gözlenen | Kanıt |
|---|---|---|---|---|---|---|
| 1 | Kilit PIN ekranı | `warn` | yok | dokunuş geçer, uyarı yok | PIN noktası doldu, uyarı yok | — |
| 2 | Kilit PIN ekranı | `warn` | var | dokunuş geçer **ve** uyarı çıkar | iki nokta dolu + kırmızı uyarı | `evidence/f03-overlay-2026-10-02/warn-touch-lands-and-warns.png` |
| 3 | Sıfırlama diyaloğu | `block` | var | dokunuş **atılır**, uyarı çıkar | diyalog kapanmadı, uyarı bandı diyalog arkasında görünür | `.../block-touch-discarded.png` |
| 4 | Sıfırlama diyaloğu | `block` | yok | dokunuş geçer | diyalog kapandı | `.../block-negative-control-no-overlay.png` |

Vaka 4 negatif kontroldür ve zorunludur: onsuz vaka 3'teki "diyalog açık kaldı" sonucu,
butonun basitçe bozuk olmasıyla ayırt edilemezdi.

## Doğrulanan

- Geçiş kapısı (`warn`) örtüşme altında **kullanılabilir kalıyor**. Kullanıcı uygulamadan
  kilitlenmiyor; bu, politikanın iki değerli olmasının tek sebebiydi.
- Örtüşme kullanıcıya **söyleniyor** — duress modelinde eyleme geçirilebilir bilgi.
- Geçiş kapısı olmayan yüzeyde (`block`) dokunuş gerçekten **atılıyor**.
- `block` altında dokunuş atılsa bile uyarı çıkıyor, yani ölü düğme hissi yok.

## Doğrulanmayan — açıkça

- **Yalnız bir OEM/imaj.** Google Play emülatör imajı, API 35. Hangi örtüşmelerin gerçek bir
  Samsung/Xiaomi build'inde bayrağı tetiklediği ölçülmedi. Bu asimetri F-03'ün tasarımının
  gerekçesidir: ölçülmeyen durum bir uyarıya düşer, kilitlenmiş kullanıcıya değil.
- **Mavi ışık filtresi / ekran karartma uygulamaları denenmedi.** Probe sentetik bir
  örtüşmedir. Gerçek bir karartma uygulamasının farklı pencere bayrakları olabilir.
- **Android'in kendi güvenilmeyen-dokunuş engellemesi ölçülmedi.** İlk turda yüksek
  opaklıkla denendi ama o sırada probe `FLAG_NOT_TOUCHABLE` taşımıyordu, yani sonuç
  karışıktı ve burada hiçbir iddiaya dayanak yapılmıyor.
- **Rıza akışı ve veri export yüzeyleri cihazda ölçülmedi.** İkisi de aynı mixin ve aynı
  kanal üzerinden aynı iki politikayı kullanıyor; kapsanan iki vaka mekanizmanın her iki
  dalını da kanıtlıyor, ama bu dört yüzeyin dördünün de ölçüldüğü anlamına gelmez.

## Tekrarlanabilirlik

Probe APK'si depoda değildir. Tekrar üretmek için: tek `Activity`, `SYSTEM_ALERT_WINDOW`
izni, `TYPE_APPLICATION_OVERLAY` + `FLAG_NOT_FOCUSABLE | FLAG_NOT_TOUCHABLE`, tam ekran,
düşük alfa; `adb shell appops set <pkg> SYSTEM_ALERT_WINDOW allow` ile izin verilir.
