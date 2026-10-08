# Cihaz günlüğü — gerçek kullanıcı / saldırgan denetimi (2026-10-07/08)

Ortam: AVD `KoruBeni_A017_API35` (API 35, `userdebug`, Google Play hizmetleri YOK, 420 dpi, 1080x2400), emülatör — fiziksel cihaz DEĞİL.
Kurulum kanıtı: her kurulumdan sonra `adb shell dumpsys package com.poyrazoncel.korubeni | grep lastUpdateTime`.

| Build | Tanım |
|---|---|
| `2026-10-07 18:43:59` | `09b9004` kodu (başlangıç, önceki denetimin son build'i) |
| `2026-10-07 23:06:46` | çalışma ağacı: HEAD `8684cf7` + düzeltmeler (diff sha `08e88ee27559`, 7 izlenmeyen dosya); APK sha1 `85bb5063856fd375…`; bu build sonraki tek-uçuş, zaman çizelgesi okuma ve `whenReleased(timeout)` değişikliklerini İÇERMEZ |

## Başlangıç build'inde yeniden üretilen kusurlar (`18:43:59`)

| # | Senaryo | Gözlem |
|---|---|---|
| D-1 (N-03) | Ana sayfa → Test Modu provası → ~T+3 sn `am start -a android.intent.action.VIEW -d korubeni://open/timeline com.poyrazoncel.korubeni` → bekle | Zaman çizelgesi provanın ÜSTÜNDE açıldı. T+10'da provanın "tamamlandı" `pop`'u zaman çizelgesini kapattı; prova "0 saniye"de kaldı. GERİ: etkisiz. Doğru PIN (2468): etkisiz. Çıkış yalnız süreç öldürerek (`run-as … kill -9`). Logcat'te FATAL/ANR yok — UI düzgün görünüp kilitli kalıyor. |
| D-2 (A-12) | Alarm akışı `cmd media_session volume --stream 4 --set 3` → Siren → `run-as … kill -9` → soğuk açılış | 3 → siren sırasında 7 → öldürme sonrası 7 → yeniden açılışta 7 (hiç geri yüklenmedi). |

## Düzeltilmiş build'de (`23:06:46`)

| # | Senaryo | Gözlem |
|---|---|---|
| D-3 (N-03) | D-1'in aynısı | T+3'te zaman çizelgesi üstte; T+10 sonrası hâlâ zaman çizelgesi üstte (prova kendini altta kapattı); GERİ → Ana Sayfa. Kapan yok. |
| D-4 (A-12) | D-2'nin aynısı | 3 → 7 → öldürme 7 → soğuk açılışta **3**. |
| D-5 (A-12, kullanıcı tercihi) | Siren → öldürme → kullanıcı alarm sesini 5 yapar → soğuk açılış | **5** kaldı (kullanıcı seçimi ezilmedi). Logcat'te `SIREN_VOLUME_RESTORE_FAILED`/FATAL yok. |
| D-6 (A-04) | `pm revoke … CALL_PHONE` (kişi kayıtlı, 2 eksik) → aç | "Kuruluma 2 adım kaldı" / "Eksik adımlara aşağıdan dokunarak tamamlayabilirsin." (önce: "Önce acil kişini ekleyelim"). İzin geri verildi. |
| D-7 (K-01 regresyonu, yeni kilit kodu) | PIN → HOME 23:09:30 → 128 sn → `korubeni://open/timeline` 23:11:38 → PIN → GERİ | Bağlantıdan sonra kilit üstte; PIN sonrası zaman çizelgesi; GERİ → Ana Sayfa; logcat'te FATAL/ANR/`E/flutter` yok. |

## A-02 dayanağı

| # | Senaryo | Gözlem |
|---|---|---|
| D-8 | `adb shell settings get global boot_count` önce; `emulator -no-snapshot-load` ile gerçek soğuk açılış; tekrar oku | 16 → **17**. Bu açılışın yayın geçmişinde (`dumpsys activity broadcasts history`) LOCKED_BOOT_COMPLETED ve BOOT_COMPLETED var, TIME_SET yok (emülatör saati ana makineden). Gerçek cihazda TIME_SET'in LOCKED_BOOT_COMPLETED'a göre sırası ve BOOT_COUNT'un direct-boot'ta okunabilirliği **DEVICE VALIDATION REQUIRED**. |

## GMS'li ortam (A-01 ayrımı, §30) ve U-01

AVD `KoruBeni_A017_API35_Play` — API 35, **`user`** build, Google Play hizmetleri 26.34.36; emülatör. Kurulu build: düzeltilmiş `app-play-debug.apk` (`lastUpdateTime=2026-10-08 08:03:22`, aynı APK sha1 `85bb5063856fd375…`).

| # | Senaryo | Gözlem |
|---|---|---|
| D-9 (U-01) | Konum izni `pm grant` ile verili, uygulama içi konum RIZASI verilmemiş → Harita → konum düğmesi | Yalnız "Bu özellik için ilgili onay gereklidir." SnackBar'ı; hangi onay/nerede yok. Kart kalıcı "Konum alınamadı". Sistem konum sağlayıcılarına hiç istek gitmedi (`ProviderRequest[OFF]`). Düzeltme `5081f10`: metin yolu söylüyor; yol cihazda doğrulandı: Ayarlar → "Yasal Bilgiler & KVKK" → "Rıza Yönetimi". |
| D-10 (A-01) | Rıza açık, `adb emu geo fix`, Harita → konum; 5× (Ana Sayfa ↔ Harita + konum isteği) | Konum Fused sağlayıcıdan alındı (`41.00400, 28.97400`, ekran `a01-gms-map-located.png`). `am_anr` 0, logcat "ANR in"/FATAL 0, `notResponding=true` 0. Rıza kapalıyken ayrıca 5 döngü: 0 ANR. GMS'siz cihazdaki `NmeaClient.stop` ANR'ı (önceki denetim, GMS'siz emülatör) bu ortamda oluşmuyor; gerçek GMS'siz cihaz **DEVICE VALIDATION REQUIRED**. |
| D-11 (U-01 sonrası) | Build `dcc1622` (sonra yalnız bir testin güncellendiği `5081f10` olarak amend edildi; uygulama kodu aynı) (`lastUpdateTime=2026-10-08 08:24:09`, APK sha1 `c0191e8c8d72cc6d…`), aynı Play AVD: Rıza Yönetimi'nden konum rızasını geri çek → Harita → konum düğmesi | SnackBar: "Bu özellik için ilgili onay gerekli. Ayarlar > Yasal Bilgiler & KVKK > Rıza Yönetimi bölümünden verebilirsin." (`u01-consent-message-fixed.png`). Logcat'te FATAL/ANR/`E/flutter` 0. |

## Release (smoke) build — Play AVD (`user`, API 35)

Kurulum: `flutter build apk --release --flavor smoke --target-platform android-arm64 --dart-define=ENV=ci_smoke --dart-define=REVENUECAT_ANDROID_API_KEY=NON_RELEASE_SMOKE_REVENUECAT_KEY`, HEAD `5081f10`; paket `com.poyrazoncel.korubeni.smoke`, debuggable DEĞİL, `lastUpdateTime=2026-10-08 09:13:32`.

| # | Senaryo | Gözlem |
|---|---|---|
| R-1 (§26) | Temiz kurulum: Kurulum ve Onay (yaş + tüm onaylar) → karusel "Atla" → kişi "Annem / 05551234567" + kişi rızası → PIN 2468 ×2 → bildirim izni **Reddet** → pil "Şimdilik Atla" | Ana sayfa; "Kuruluma 3 adım kaldı / Eksik adımlara aşağıdan dokunarak tamamlayabilirsin." (A-04 release'de). Çökme yok. |
| R-2 (N-03) | Test Modu + `korubeni://open/timeline` (paket `.smoke`) | T+10 sonrası zaman çizelgesi üstte; GERİ → Ana Sayfa; logcat FATAL/`E/flutter` 0. |
| R-3 (kilit + bağlantı + FLAG_SECURE) | HOME 09:17:41 → 129 sn → bağlantı 09:19:50 → PIN → GERİ | Kilit üstte; `screencap` ortalama parlaklık **0,53** (siyah, FLAG_SECURE); PIN sonrası zaman çizelgesi; GERİ → Ana Sayfa; FATAL/ANR/`E/flutter` 0. Ayrıntı: `release-lock-link.txt`. |
| I-1 | Enstrümantasyon, `5081f10` play debug + androidTest APK (`lastUpdateTime 09:11:37`) | `OK (18 tests)` |
