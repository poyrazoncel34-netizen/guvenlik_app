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
- ⚠️ Koşu yarıda kalırsa (kablo çıkarsa, Ctrl+C) ve süre dolmuşsa, script'in temizliği oturumu
  iptal edemez: temizlik uygulamayı uyandırır ve süresi geçmiş oturum **ikinci numarana aranır**.
  Süre dolmadan kesilirse iptal çalışır.

## Test C — Üretici uygulamayı force-stop ediyor mu? (abonelik ve arama GEREKMEZ)
Neden (N-08, emülatör deneyi `docs/audit/device-verification-2026-09-13-force-stop.md`):
geri sayım sırasında uygulama force-stop edilirse Android alarmı siler, arama gitmez ve
kullanıcıya bir şey gösterilmez. Uygulama sonra açılınca (Android 17 emülatöründe) süresi
geçmiş oturum sormadan hemen aranır. Bu test üreticinin normal kullanımda force-stop yapıp
yapmadığını ölçer. Arama yapılmaz.
1. Test A'dan sonra uygulama kuruludur. KoruBeni'yi ana ekrandan bir kez aç, ana ekrana dön.
2. `adb shell dumpsys package com.poyrazoncel.korubeni | grep -o "stopped=[a-z]*"` → `stopped=false` beklenir.
3. Son uygulamalar ekranından KoruBeni'yi kaydırarak kapat. 1 dk bekle, 2. adımı tekrarla.
4. "Tümünü temizle" ile tekrarla. 2. adımı tekrarla.
5. Ekranı kapat, pil tasarrufu varsayılanında 10 dk beklet. 2. adımı tekrarla.
- `stopped=true` görülen her adım: bu telefonda o davranış N-08 senaryosunu gerçekleştirir.
- Kayıt: cihaz, model, Android/MIUI/One UI sürümü, hangi adımda `stopped=true`.

## Test B — panik + güç tuşu (abonelik GEREKİR)
Build yolu kararına bağlı (main'e birleştirme + imzalı tag + 2 secret, ya da
yerel build istisnası). Karar verilmeden yapılamaz.
1. Paniğe uzun bas → geri sayım başlar başlamaz güç tuşuna bas.
2. 15 sn bekle; ikinci telefon çalıyor mu?
3. Kayıt: cihaz, model, Android sürümü, yoğunluk, commit, `lastUpdateTime`.

## Build yolu (Test B için karar bekliyor)
(a) CI release (projenin kuralı): 142 commit `main`'e birleştirilmeli; imzalı annotated tag
(`v1.0.3` → versionCode 10003); GitHub secret'ları `EXPECTED_UPLOAD_CERT_SHA256` ve
`EXPECTED_PLAY_APP_SIGNING_CERT_SHA256` eklenmeli. İlkinin değeri repoda kayıtlı
(`store/PLAY_CONSOLE_RUNBOOK.html`: `AF:68:8F:50:BB:20:0C:6A:A2:1D:69:E2:8A:F1:41:45:F3:F2:76:11:E2:C1:4E:1A:D3:FE:2F:DF:FD:D2:95:94`);
ikincisi Play Console → Uygulama bütünlüğü → Uygulama imzalama anahtarı sertifikası SHA-256.
CI Play'e yüklemez; AAB'yi Console'dan elle dahili teste yüklersin.
(b) Yerel build istisnası: proje kuralına aykırı (Fastfile/runbook "yalnızca CI"), 10003'ü harcar.
Her iki yolda: telefondaki Google hesabı Console → Lisans testi listesine eklenmeli ve
dahili test katılımcısı olmalı; satın alma test ödemesiyle yapılır.

## Her kayıtta zorunlu (projenin CERT2-05 kuralı)
Cihaz/AVD adı, yoğunluk, ölçülen commit, kurulu build'in o commit'i içerdiğinin
kanıtı (`dumpsys package … | grep lastUpdateTime`).
