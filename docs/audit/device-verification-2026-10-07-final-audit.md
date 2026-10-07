# Cihaz doğrulaması — kapsamlı son denetim (2026-10-06/07)

Etiketler: `[KESİN]` doğrudan gözlendi · `[GÜÇLÜ ÇIKARIM]` kanıttan çıkarıldı · `KANITLANMADI`.

## Ortam

| Alan | Değer |
|---|---|
| AVD | `KoruBeni_A017_API35` — API 35, `userdebug`, `test-keys`, **Google Play hizmetleri yok**; emülatör, fiziksel cihaz DEĞİL |
| Yoğunluk / çözünürlük | 420 dpi, 1080x2400 |
| Kurulum kanıtı yöntemi | `adb shell dumpsys package com.poyrazoncel.korubeni \| grep lastUpdateTime` her kurulumdan hemen sonra |

## Ölçümler

| # | Senaryo | Build (commit / lastUpdateTime) | Sonuç |
|---|---|---|---|
| 1 | Profil → Cihaz Verilerini Temizle → PIN → HOME → `kill -9` → görev | `eda8304` play debug / 2026-10-06 13:32:18 | `'_history.isNotEmpty'` assertion + "Bir sorun oluştu" `[KESİN]` (hata) |
| 2 | Aynı + Verilerimi Sil yolu | çalışma ağacı (sonra `3e39841`) / 13:59:05 | 0 framework hatası, onay ekranı `[KESİN]` |
| 3 | Aynı, **release** | smoke release, aynı ağaç / 14:47:11 | yerel hata günlüğünde `flutter_framework_unhandled` yok, onay ekranı `[KESİN]` |
| 4 | >120 sn arka plan → kilit → HOME → `korubeni://open/timeline` | `eda8304` / 13:32:18 | zaman çizelgesi kilidin ÜSTÜNDE `[KESİN]` (hata) |
| 5 | Aynı + dönüşle eşzamanlı bağlantı | çalışma ağacı (sonra `6edbc8a`) / 14:17:58 | 2/2 kilit üstte, PIN sonrası hedef `[KESİN]` |
| 6 | Enstrümantasyon | 14:43:20 ve `09b9004` kodu / 2026-10-07 18:43:59 | 18/18 (önce 16/18) `[KESİN]` |
| 7 | Son commit tam betik (E1 karo, E2 prova PIN, E3 siren sesi, E4 kilit+bağlantı, E5 reset+süreç ölümü+depolama) | `cc2fdd6` / 2026-10-07 17:56:35 (koşu 1) ve 18:20:35 (koşu 2) | Koşu 2: hepsi geçti. Koşu 1: E4 hariç geçti (aşağıda) `[KESİN]` |
| 8 | E4 döngüsü (gerçek 128 sn arka plan, 4 tekrar) + 4 ayrı deney | `cc2fdd6` / 18:20:35 | 8/8 kilit gösterildi ve bağlantıdan sonra üstte kaldı `[KESİN]` |
| 9 | Güvenli depoda `user_pin` şifreli metninde 1 bayt bozma, soğuk açılış | `cc2fdd6` / 18:20:35 | eklenti PIN'i sildi, uygulama "PIN belirleyin" açtı `[KESİN]` (hata) |
| 10 | Aynı | `09b9004` kodu / 18:43:59 | "Güvenli başlatma tamamlanamadı", depo kaydı silinmedi; geçerli veriyle normal kilit açma `[KESİN]` |
| 11 | Harita sekmesi açılmadan karo | `cc2fdd6` | ana ekranda 0, Harita'da 60 karo `[KESİN]` |
| 12 | Prova (Test Modu) 2.0x yazı tipi | `eda8304`+ ağaç | tuş takımı yok, "PIN doğrulanıyor…" `[KESİN]` (hata); düzeltmeyle tuş takımı var, PIN ile iptal `[KESİN]` |
| 13 | Siren sesi | `cc2fdd6` | durdurunca 7→2 geri `[KESİN]`; hızlı durdurma yarışı 20 zamanlı denemede yakalanamadı `KANITLANMADI` |
| 14 | Harita sekmesi, GMS'siz emülatör | ara build | ANR; system_server GNSS HAL kilitlenmesi, ana iş parçacığı geolocator `NmeaClient.stop` binder çağrısında `[KESİN]` |
| 15 | "Etkinlikleri tutma" açık, arka plan → dönüş | `cc2fdd6` öncesi ağaç | sekme korundu, 0 hata `[KESİN]` |

### Koşu 1 E4 anomalisi

128 sn sonrası dönüşte kilit görünmedi; bağlantıdan sonra zaman çizelgesi görünürdü ve tuş takımı yoktu. Aynı süreç (pid) E5'teki `kill -9`'a kadar yaşadı (`dumpsys activity exit-info`), sistem saatinde değişiklik yok (`dumpsys alarm`: 0 time change; `time_detector` yalnız açılıştaki NITZ). Gözlem, ilk HOME tuş olayının işlenmemesiyle (uygulama 128 sn boyunca önde kaldı; bağlantı öncesi arka plan yalnız 2 sn) birebir tutarlı `[GÜÇLÜ ÇIKARIM]`. Sonraki 11 gözlemde yeniden üretilemedi. Mantık ayrıca deterministik testlerle (`deep_link_resume_lock_test`) korunuyor.

## Kapsam dışı

Gerçek SIM/Telecom, kilitli ekranda çağrı, OEM pil yöneticileri, fiziksel Doze, Play Billing, API 29/36 imajları bu notta doğrulanmadı.
