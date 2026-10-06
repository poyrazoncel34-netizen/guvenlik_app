# Cihaz dogrulamasi — launch-critical fonksiyonel denetim (2026-10-06)

Etiketler: `[KESIN]` dogrudan gozlendi · `[GUCLU CIKARIM]` kanittan cikarildi · `[BILINMEYEN]` dogrulanamadi.

## Ortam

| Alan | Deger |
|---|---|
| AVD | `KoruBeni_A017_API35` (API 35, emulator; fiziksel cihaz DEGIL) |
| Yogunluk / cozunurluk | 420 dpi, 1080x2400 |
| Olculen commit'ler | HATA once: `f596c01` · DUZELTME sonrasi: `895ab27` |
| Build | `flutter build apk --debug --flavor play` (play debug) ve `--release --flavor smoke` |
| Kurulum kaniti | `adb shell dumpsys package com.poyrazoncel.korubeni \| grep lastUpdateTime` → once `2026-10-06 11:29:05` (f596c01), sonra `2026-10-06 13:02:10` (895ab27); smoke release `2026-10-06 11:56:22` |

## 1. Zaman cizelgesinde ham ceviri anahtari (B3)

Yontem: native journal'a (`korubeni_emergency_session_v1.xml`, `run-as` ile)
terminal bir PANIC sonucu eklendi (`requestSubmittedUnconfirmed` / `posted`;
gercek arama yok), uygulama `force-stop` sonrasi soguk baslatildi, ardindan
`korubeni://open/timeline` acildi.

- `f596c01`: kayit "countdown_emergency_title — native_history_request_submitted
  native_history_fallback_posted" olarak kalici yazildi. `[KESIN]`
- `895ab27`: ayni senaryoda journal soguk acilista tuketildi ve kayit
  "Acil Durum Tetiklendi — Arama istegi gonderildi; baglanti veya yanit
  dogrulanmadi..." olarak yazildi. `[KESIN]`

## 2. Push'lanmis route'tan veri silme sonrasi surec olumu (ERTELENDI)

Yontem: Ayarlar → Kullanici (ProfilePage) → Cihaz Verilerini Temizle → PIN →
HOME → uygulama sureci sinyalle olduruldu → gorevden geri donus.

- debug (`f596c01`): `'_history.isNotEmpty'` assertion ve "Bir sorun olustu"
  ekrani. `[KESIN]`
- smoke release: yerel hata gunlugune `flutter_framework_unhandled` yazildi;
  arayuz etkilesimli kaldi (onay kutusu isaretlenebildi; FLAG_SECURE nedeniyle
  ekran goruntusu siyah). `[KESIN]` Yayini engellemedigi icin ertelendi.

## 3. Deep link ↔ arka plan PIN kilidi

Yontem: HOME → 125 sn bekleme → `korubeni://open/timeline`.
Sonuc: kilit ekrani ustte, zaman cizelgesi altinda acildi (1 deneme). Ters
siralama yarisi bu denemede gozlenmedi. `[BILINMEYEN]` (tek deneme).

## 4. Instrumentation

`am instrument` (play debug, `895ab27`): 18 test, 16 gecti. Dusen 2 test
`DeviceIntegrityEmulatorProbeTest` — RootBeer'i yansima ile cagiriyor; RootBeer
`6bb7361` (F-06, safe_device kaldirildi) ile APK'dan cikti. Degisikliklerden
bagimsiz, onceden kalan prob borcu. `[KESIN]`

## Kapsam disi

Gercek telefon hatti, SIM, kilitli ekranda Telecom, OEM pil yoneticisi, fiziksel
Doze, Play billing bu notta DOGRULANMADI.
