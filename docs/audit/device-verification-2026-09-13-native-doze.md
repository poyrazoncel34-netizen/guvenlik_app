# Cihaz doğrulaması — 2026-09-13 — Native çekirdek, zorla derin Doze

**AVD:** `KoruBeni_API37_16k` · Android 17 (API 37) · `sdk_gphone16k_arm64` · 16 KB sayfa
**Ekran yoğunluğu:** 420
**Ölçülen commit:** `6c1467c`, çalışma ağacı temiz (script temiz ağaç olmadan çalışmıyor)
**Kurulum kanıtı:** `dumpsys package com.poyrazoncel.korubeni` →
`lastUpdateTime=2026-09-13 23:09:28`. Build aynı koşuda bu commit'ten derlendi.
APK SHA-256 `5238550b…a3b3`, test APK `6fd8f79a…41f8`
**Araç:** `scripts/native_doze_dispatch_probe.sh` + `NativeDozeDispatchProbeTest`

## Sonuç: GEÇTİ

```
RESULT state=requestSubmittedUnconfirmed call=submittedUnconfirmed fallback=posted latenessMs=78
```

- Oturum üretimdeki `EmergencySessionCoordinator.arm` ile kuruldu, süre 90 sn.
  Flutter, faturalama ve abonelik devrede değildi.
- Ekran kapatıldı (`mWakefulness=Asleep`), şarj çıkarıldı, `cmd deviceidle force-idle`
  ile derin Doze zorlandı (`deep=IDLE`).
- Alarm süreden **78 ms** sonra geldi. Çekirdek önce yedek bildirimi gönderdi
  (`posted`), sonra `TelecomManager.placeCall` çağrıldı (`submittedUnconfirmed`).
- Derin Doze örnekleri (5 sn aralık): **18/18 `IDLE`**. Son örnek 20:10:58Z,
  sevkiyat 20:11:00Z. Yani cihaz sevkiyattan en fazla ~2 sn öncesine kadar Doze'da.
- Uygulama pil muafiyetinde **değildi** (`battery_optimization_whitelisted=0`).
- Hedef, sıfırlardan oluşan ve gerçek bir kişiye ait olamayan parser hedefiydi.

## Kanıtlamadıkları

- **Süreç ölümü:** Instrumentation, test boyunca uygulama sürecini canlı tutar. Sistem
  ya da üretici süreci öldürdükten sonra alarmın teslim edilip edilmediği ölçülmedi.
  "Kur, çık, sonra bak" tasarımı kullanılamaz: AndroidJUnitRunner bitince hedef paketi
  force-stop eder ve alarmlar silinir. Uygulama açılışında da alarmı yeniden kuran bir
  `reconcile` yok; yalnızca boot, saat ve exact-alarm izin receiver'ları çağırıyor.
- **Üretici pil yöneticileri** (Xiaomi, Samsung vb.): emülatörde yok.
- **Zorla Doze ≠ doğal Doze:** `force-idle` bakım pencerelerini ve hareket algılamayı atlar.
- **Arama bağlandı mı:** Android bunu raporlamaz, sonuç bilerek "unconfirmed" kalır.
- **API 36:** ilk deneme `KoruBeni_API36_16k_ctrl` üzerinde kuruluma bile ulaşmadı:
  `/data` 5.8 GB'ın 329 MB'ı boştu ("Requested internal only, but not enough space").
  Orada kurulu başka bir proje (`com.poyrazoncel.veloxa`) ve eski KoruBeni build'leri
  vardı, hiçbiri silinmedi. Script o koşuda yanlış bir "imza uyuşmazlığı?" ipucu verdi,
  `6c1467c` ile düzeltildi.

## Koşum ayrıntıları

Başlangıç 20:09:22Z, kurulum 20:09:30Z, bitiş 20:11:03Z. Kanıt dosyaları yerelde
`build/qa/native-doze/20260913T200922Z/` altında (izlenmeyen build çıktısı). Numara
hiçbir dosyaya yazılmaz.
