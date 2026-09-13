# Telefon testi protokolü — 2026-09-14 — hazırlık

## Hazırlık (bilgisayar + telefon)
- Telefonda Geliştirici seçenekleri → USB hata ayıklama açık; bilgisayara bağla, "izin ver"i onayla.
- Xiaomi/MIUI'de ek olarak genelde gerekir: "USB üzerinden yükle" ve
  "USB hata ayıklama (Güvenlik ayarları)". Bunlar kapalıysa `adb install` veya
  `pm grant` reddedilir. (Cihazda doğrula; tahmin olarak yazıldı.)
- Aramayı karşılayacak **ikinci bir telefon/numara** senin kontrolünde olmalı.
- Telefonda Play'den kurulmuş bir KoruBeni varsa imza farklıdır; script
  otomatik kaldırmaz, kurulum hata verir. Önce elle kaldırman gerekir.
- Pil ayarlarına dokunma: üreticinin varsayılanı ölçülecek. Script
  uygulamanın pil muafiyetinde olup olmadığını kanıta yazar.

## Test A — native Doze sondası (abonelik GEREKMEZ)
```
ANDROID_SERIAL=<adb devices'taki seri> \
NATIVE_DOZE_CONFIRM_PHYSICAL=1 \
NATIVE_DOZE_TARGET=<ikinci numara> \
./scripts/native_doze_dispatch_probe.sh
```
- Beklenen: ekran kapanır, ~90 sn sonra ikinci telefon çalar. Emülatörde (API 37) aynı test GEÇTİ, alarm 78 ms geç geldi: `docs/audit/device-verification-2026-09-13-native-doze.md`.
- Kanıt: `build/qa/native-doze/<zaman>/evidence.txt` (numara YAZILMAZ).
- Sınır: test boyunca uygulama süreci canlı tutulur. Üreticinin "arka plan
  uygulamasını öldürme" davranışını bu test ÖLÇMEZ.

## Test B — panik + güç tuşu (abonelik GEREKİR)
Build yolu kararına bağlı (main'e birleştirme + imzalı tag + 2 secret, ya da
yerel build istisnası). Karar verilmeden yapılamaz.
1. Paniğe uzun bas → geri sayım başlar başlamaz güç tuşuna bas.
2. 15 sn bekle; ikinci telefon çalıyor mu?
3. Kayıt: cihaz, model, Android sürümü, yoğunluk, commit, `lastUpdateTime`.

## Her kayıtta zorunlu (projenin CERT2-05 kuralı)
Cihaz/AVD adı, yoğunluk, ölçülen commit, kurulu build'in o commit'i içerdiğinin
kanıtı (`dumpsys package … | grep lastUpdateTime`).
