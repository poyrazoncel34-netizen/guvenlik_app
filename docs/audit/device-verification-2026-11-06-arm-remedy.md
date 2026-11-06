# Cihaz doğrulaması — ret penceresi çözümleri ve sıralı panik kurulumu (2026-11-06)

Etiketler: `[KESİN]` doğrudan gözlendi · `[GÜÇLÜ ÇIKARIM]` kanıttan çıkarıldı · `KANITLANMADI`.

Doğrulanan değişiklik: `bc02350` (ret penceresinde her nedene tek dokunuşla çözüm) ve
`249eeb2` (Pro etkinleşince eksik izinlerin sırayla istenmesi). Native ret kuralı
(`CapabilitySnapshot.rejectionReason()`) değişmedi; bu not kullanıcının o rete ulaşmadan
önce çözüme yönlendirildiğini cihazda ölçer.

## Ortam

| Alan | Değer |
|---|---|
| AVD | `KoruBeni_Remedy_API35` — API 35 (Android 15), `sdk_phone64_arm64`, `userdebug`/`test-keys`, **Google Play hizmetleri yok**; emülatör, fiziksel cihaz DEĞİL |
| Sistem parmak izi | `Android/sdk_phone64_arm64/emu64a:15/AE3A.240806.019/12368160:userdebug/test-keys` |
| Yoğunluk / çözünürlük | 420 dpi, 1080x2400 |
| Ölçülen commit | `249eeb2` (çalışma ağacı temiz; yalnız izlenmeyen `marketing/`) |
| Derleme | `flutter build apk --debug --flavor play --target-platform android-arm64` → `app-play-debug.apk`, SHA-256 `99aa192504e047e6d8e1c77d2899a09a8f45f1bf33995e99e0f6932dd2804519` |
| Derlemenin değişikliği taşıdığı | `unzip -p … assets/flutter_assets/assets/translations/tr-TR.json` içinde `panic_setup_exact_alarm_body`, `panic_fix_alert_channel`, `perm_alert_channel_title` var |
| Kurulum kanıtı | temiz kurulum, hemen ardından `adb shell dumpsys package com.poyrazoncel.korubeni \| grep lastUpdateTime` → `2026-11-06 13:18:07`; oturum boyunca yeniden kurulmadı |
| Pro | Play Billing yok. Çevrimdışı Pro çapası `docs/audit/evidence/chaos-2026-10-08/tools/inject_pro.sh` ile (run-as) yazıldı. Yalnız test; ticaret kanıtı DEĞİL |
| Ses | `-no-audio`, ses akışları 0 |
| Acil kişi | kurgusal `05550000000` |

Kanıtlar: `docs/audit/evidence/arm-remedy-2026-11-06/` (`shots/` 1000 px'e küçültülmüş ekran
görüntüleri; zamanlı koşuların betikleri ve çıktıları `.sh`/`.txt`).

## Ölçümler

| # | Senaryo | Sonuç | Görüntü |
|---|---|---|---|
| 1 | Temiz kurulumda kesin alarm | `appops get … SCHEDULE_EXACT_ALARM` → `No operations. Default mode: default`; bu araç yalnız modu verir, izin durumunu tek başına kanıtlamaz. Uygulama onboarding'de "Alarm ve hatırlatıcı erişimi kapalı." gösterdi ve #8'deki panik `exactAlarmDenied` ile reddedildi `[KESİN]` | 01 |
| 2 | Onboarding'in kesin alarm adımı atlandı (hatanın senaryosu); Pro yokken açılış | kurulum sorulmadı `[KESİN]` | 02 |
| 3 | Pro çapası yazıldı, `pref_panic_readiness_setup_offered` yok, soğuk açılış | PIN'den sonra ilk soru kesin alarm, yeni gövde metniyle; "Alarm ayarlarını aç" doğrudan uygulamanın "Alarms & reminders" sayfasını açtı (`com.android.settings/.spa.SpaActivity`) `[KESİN]` | 03, 04 |
| 4 | Kurulum sürerken Ayarlar'da 143 sn (13:23:21 → 13:25:44, BACK ile dönüş) | önce PIN kilidi, üstünde soru yok; PIN'den sonra sıradaki soru "Telefon Arama İzni Gerekli" `[KESİN]` | 05, 06 |
| 5 | Arama izni reddedildi | kurulum bitti; bildirim ve kanal zaten tamam olduğu için başka soru yok; `flutter.pref_panic_readiness_setup_offered=true` yazıldı `[KESİN]` | — |
| 6 | İkinci soğuk açılış | kilit açıldıktan 8 sn sonra soru yok, ana ekran `[KESİN]` | 07 |
| 7 | Kesin alarm ve arama izni eksik, ana ekrandan panik | "Hiçbir işlem tamamlanmadı": "Şimdi Ara", "Arka plan korumasını aç", "Kapat" `[KESİN]` | 08 |
| 8 | "Arka plan korumasını aç" → Ayarlar'da izni aç → BACK | Ayarlar'ın kesin alarm sayfası açıldı, `appops` → `SCHEDULE_EXACT_ALARM: allow`; dönüşte pencere açık kaldı ve düğme sıradaki eksiğe geçti: "Arama iznini ver"; uygulama süreci yaşıyordu `[KESİN]` | 09, 10 |
| 9 | "Arama iznini ver" → açıklama "Kabul Et" → sistem izni "ALLOW" | `CALL_PHONE: granted=true`; çözüm düğmesi kayboldu, "Şimdi Ara" ve "Kapat" kaldı `[KESİN]` | 11 |
| 10 | Dört yetenek tamam, panik yeniden | native oturum bırakıştan 1 sn sonra `armed`, "Acil uyarı devreye giriyor"; PIN ile `cancelled`; logcat'te CALL/DIAL yok, telecom'da çağrı 0 `[KESİN]` | 12 |
| 11 | "Acil Bildirimler" kanalı "Silent" (`mImportance` 4 → 2), ana ekranda "Arka Plan Hazırlığı" | 13:31:22 `START u0 {act=android.settings.CHANNEL_NOTIFICATION_SETTINGS … ChannelPanelActivity}`; açılan sayfa kanalın kendisi ("Acil Bildirimler", Default/Silent) `[KESİN]` | 13, 14 |
| 12 | Bildirim izni kaldırıldı (`pm revoke`), kanal sessiz, ayar silindi, soğuk açılış | kurulum yeniden sunuldu, ilk soru "Bildirim izni kapalı" `[KESİN]` | 15 |
| 13 | "Ayarlara Git" → Ayarlar'dayken Hızlı Ayarlar panelinde "KoruBeni panik" kutucuğu | geri sayım en üstte, "Sınırlı koruma — uygulama kapanırsa arama yapılmaz"; üstünde soru yok; PIN ile iptal edildi, CALL/DIAL yok, çağrı 0 `[KESİN]`. İptalden sonra kanal sorusu görünür (Bulgu 1) | 16, 17 |
| 14 | Kanal sorusu reddedildi | kurulum bitti, ayar yazıldı `[KESİN]` | — |
| 15 | İstenmeden tetiklenen sınırlı geri sayım (Bulgu 2) | soğuk açılış, sınırlı geri sayım 10 sn sonra çeviriciyi numarayla açtı (13:34:03 `act=android.intent.action.DIAL`), arama yapılmadı, telecom'da çağrı 0 `[KESİN]` | 16x |

## Bulgular

1. **Kurulum sorusu, Hızlı Ayarlar paniğinin altına açılabiliyor — DÜŞÜK (kullanıcı deneyimi).**
   #13'te kurulum Ayarlar'dan dönüşü bekliyordu; dönüşü kutucuğun açtığı geri sayım
   tetikledi. İptalden sonra kanal sorusu ekrandaydı ve ayar yazılmamıştı. Yani kurulum
   panikle bitmedi, devam etti. `EmergencyTriggerHost` geri sayım kilidini
   (`PanicCountdownGuard`) yetki kontrolünden sonra, push anında alıyor. Bu bilinçli; kilit
   bekleme boyunca tutulsa panik butonu basışı düşer. Kurulumun dönüşteki hazırlık okuması
   bundan önce bittiği için kurulum geri sayımı görmedi, soruyu açtı ve geri sayım sorunun
   üstüne itildi `[GÜÇLÜ ÇIKARIM]`. Sıra, kod okumasından ve 16/17 görüntülerinden
   çıkarıldı. Korunan özellik: geri sayım hiçbir anda örtülmedi ve PIN iptali çalıştı
   `[KESİN]`. Birim testteki "Ayarlar sırasında açılan geri sayım kurulumu bitirir" yolu bu
   koşuda tetiklenmedi.
2. **`cmd statusbar click-tile`, bağlanmamış kutucukta tıklamayı bekletiyor — ARAÇ.** İlk
   denemede (`step7a_click_tile_unbound.txt`) uygulama açılmadı ve servis çağrılmadı. Tıklama,
   panel bir sonraki açılışta servis bağlanınca teslim edildi ve istenmeyen bir panik başlattı
   (#15). Sonraki koşu paneli açıp kutucuğa dokunarak yapıldı (`step7b_…`). Uygulama kusuru
   değil, ölçüm aracı tuzağı.

## Kapsam dışı / doğrulanmadı

- Gerçek satın alma veya geri yükleme sonrası paywall kurulumu ve kurulum sırasında açılan
  geri sayımı paywall'ın kapatmaması: Play Billing ve lisans test hesabı gerekir, bu imajda
  Google Play hizmetleri yok. KANITLANMADI; yalnız widget testleri
  (`test/screens/paywall_pro_activation_setup_test.dart`).
- Release (R8) derlemesi bu notta kurulmadı; derleme kapıları `scripts/verify_release.sh` ile
  `249eeb2` üzerinde ayrıca geçti.
- Fiziksel cihaz, OEM'lerin farklı Ayarlar ekranları, API 34 ve API 36 imajları.
- Çözüm düğmesi değiştiğinde ekran okuyucu duyurusu (bilinen açık LOW).
