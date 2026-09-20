# Cihaz doğrulaması — 2026-09-20 — Vadesi geçmiş oturum artık sormadan aranmıyor (A-001)

**AVD:** `KoruBeni_API37_16k` · Android 17 (API 37) · `sdk_gphone16k_arm64` · arm64-v8a · 16 KB sayfa ·
yoğunluk 420 · 1080x2400
**Ölçülen commit:** `a1a132e` (`fix(safety): vadesi 5 dakikayi asan oturum sormadan aranmiyor`).
Ölçüm sırasında ağaç temizdi: `git status --porcelain -- lib android scripts config test` → `0` satır.
**Build:** `build/app/outputs/flutter-apk/app-play-debug.apk`,
SHA-256 `488d394dfdf9399ae79826ef8aba2a2c10a0f4351d5f1e7aea1b379775a69c0b`
**Kurulum kanıtı:** `adb shell dumpsys package com.poyrazoncel.korubeni | grep lastUpdateTime` →
`lastUpdateTime=2026-09-20 11:47:22`, `firstInstallTime=2026-09-20 11:47:22` (önce `adb uninstall`
yapıldı, yani kurulu byte'lar bu commit'in build'i).
**Yöntem:** `OverdueSessionProbeTest` (androidTest). Oturum kaydı doğrudan üretim
`DeviceProtectedEmergencySessionStore`'una yazılıyor ve ardından ÜRETİM koordinatörünün
`reconcileAfterBoot()`'u çağrılıyor. Kayıt `arm()` üzerinden kurulamaz: `arm()` geçmişteki bir
deadline'ı haklı olarak reddeder, oysa sınanan durum tam olarak "deadline'ı saatler önce geçmiş bir
kayıt" — force-stop veya kapanma sonrası kaydın göründüğü hâl.
Hedef `+900000000000` (parser'ı geçen, kimseye ait olmayan numara); gerçek bir kişi aranmadı.
Sonda `-e overdueProbe` olmadan atlanır, yani normal connected-test koşusu asla oturum yazmaz.

## Sonuçlar

| Varyant | Kayıt | Telecom | Kullanıcıya görünen |
|---|---|---|---|
| **A — 1 saat gecikmiş** (`overdueByMs=3600000`) | `state=manualActionRequired call=notAttempted fallback=posted` | logcat'te **0** `Telecom.*Call:` satırı | Bildirim gönderildi: `id=7304`, `channel=emergency_alerts`, `importance=4`, `category=alarm` |
| **B — negatif kontrol, 30 sn gecikmiş** (`overdueByMs=30000`) | `state=requestSubmittedUnconfirmed call=submittedUnconfirmed` | logcat'te **233** `Telecom` satırı, gerçek bir arama oluşup düştü | — |

Bildirim metni cihazdan, `dumpsys notification --noredact` ile okundu:

```
android.title=String (Geri sayımınız tamamlanamadı)
android.text=String (Kesintiye uğradı ve otomatik aranamayacak kadar eskidi.
                     Yine de aramak isterseniz korumalı eyleme dokunun.)
```

Bu metnin ayrı olması şart: standart manual-fallback kopyası "Otomatik istek denenecek" diyor,
bu vakada otomatik istek denenmiyor.

## Ne anlama geliyor

- **2026-09-13 kaydındaki davranış kapandı.** O kayıt, uygulama açılışında `BootCompletedReceiver`'ın
  Flutter yüklenmeden çalıştığını ve 82 ms sonra Telecom arama kaydı oluştuğunu ölçmüştü
  (`docs/audit/device-verification-2026-09-13-force-stop.md`, varyant A). Aynı AVD'de, aynı yoldan,
  bir saatlik oturum artık hiç Telecom'a gitmiyor.
- **Negatif kontrol olmadan bu kanıt değersizdi.** "Arama yok" tek başına, sondanın hiç çalışmamasıyla
  aynı görünür. B varyantı aynı build'de aynı yoldan gerçek bir arama üretiyor, yani sınırın iki yanı da
  ölçüldü.
- Kullanıcı aramayı kaybetmiyor: hedef kayıtta korunuyor ve bildirime dokunmak
  `consumeFallbackTarget` üzerinden aramayı yetkilendiriyor.

## Kanıtlamadıkları — bunlar açık kalıyor

- **Yalnızca emülatör, yalnızca Android 17.** Fiziksel telefonda ve eski API seviyelerinde ölçülmedi.
  Telefon protokolü `docs/audit/telefon-testi-protokolu-2026-09-14.md`.
- **Gerçek bir force-stop → açılış döngüsü sınanmadı.** Sonda `reconcileAfterBoot()`'u doğrudan
  çağırıyor; sistemin `PACKAGE_UNSTOPPED` / `LOCKED_BOOT_COMPLETED` yayınıyla tetiklediği yol
  2026-09-13'te ölçülmüştü, bu turda tekrarlanmadı. Tetikleyiciden sonraki KARAR ölçüldü, tetikleyicinin
  kendisi değil.
- **Bildirime dokunup aramanın gerçekten başladığı sınanmadı.** `fallback=posted` ve PendingIntent'in
  varlığı ölçüldü; dokunma → `consumeFallbackTarget` → Telecom zinciri ölçülmedi.
- **`CLAIMED` dalı değişmedi ve ölçülmedi.** Bayat bir CLAIMED kaydı hâlâ açılışta aranır.
- **Cihaz açıkken OEM'in exact alarm'ı saatlerce geciktirdiği dar senaryo** (CountdownAlarmReceiver
  yolu) sınır dışında; orada yaş sınırı yok.
- 5 dakikalık sınır bir ürün kararıdır; bu kayıt sınırın UYGULANDIĞINI gösterir, DOĞRU olduğunu değil.
