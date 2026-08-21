# Cihaz doğrulama — TalkBack ekran okuyucu geçişi (2026-08-21)

**Satır:** `MP-46-030` (Manual accessibility) — denetimin son kalan `FAIL` satırı.
İlgili satırlar: `MP-47-018`, `MP-59-024`, `MP-69-011`, `MP-74-006`, `MP-77-005`.

## Ne ölçüldü, hangi build üzerinde

| Alan | Değer |
|---|---|
| AVD | `KoruBeni_API36_16k_ctrl` |
| Sistem imajı | `system-images/android-36.1/google_apis_playstore_ps16k/arm64-v8a` |
| Cihaz | `sdk_gphone16k_arm64`, Android 16 (API 36) |
| Build fingerprint | `google/sdk_gphone16k_arm64/emu64a16k:16/BE4B.251210.005/14574095:user/dev-keys` |
| Ekran | 1080x2400, **yoğunluk 420 dpi** (1 dp = 2.625 px, 48 dp = 126 px) |
| Sayfa boyutu | 16384 (16 KB — yayın hedefiyle aynı) |
| TalkBack | `com.google.android.marvin.talkback` **16.0.0.777931756** |
| Ölçülen commit | **`b87b74a`** |
| APK | `app-play-debug.apk`, sha256 `af5047a5377bf5d91925aea4a27b71b197debd486074ab34744daad533a1af81` |
| Kurulum doğrulaması | `dumpsys package com.poyrazoncel.korubeni` → `lastUpdateTime=2026-08-21 10:09:02` |
| Build türü | **debug**, `play` flavor (release değil — sınır aşağıda) |

CERT2-05 kuralı gereği build parmak izi kayıtlıdır: yüklü paketin `lastUpdateTime`
değeri ölçümden önceki derlemeye aittir, yani ölçülen davranış bu commit'in
davranışıdır.

TalkBack'in gerçekten bağlı ve **konuşuyor** olduğu iki bağımsız kayıtla doğrulandı:

    dumpsys accessibility -> Bound services:{Service[label=TalkBack,
      feedbackType[FEEDBACK_SPOKEN, FEEDBACK_HAPTIC, FEEDBACK_AUDIBLE], ...]}
    logcat -> MediaFocusControl: requestAudioFocus()
      AA=USAGE_ASSISTANCE_ACCESSIBILITY/CONTENT_TYPE_SPEECH

## Bulgu 1 — Emülatörde TalkBack ÇALIŞIYOR

Satırın kapsam gerekçesi "Manual screen-reader verification needs TalkBack on
real hardware" diyordu. Bu, işin **semantik yarısı için fazla güçlü bir
iddiaydı**: Play Store sistem imajı Android Accessibility Suite'i taşıyor,
TalkBack kuruluyor, bağlanıyor ve konuşuyor. Semantik ağaç, etiketler, odak
durakları ve dokunma hedefleri emülatörde ölçülebilir — ve ölçüldü.

Donanıma gerçekten bağlı olan kısım daha dar: gerçek dokunmatik jest tanıma ve
üretici TalkBack varyantları. Bu ayrım CERT2-01'in dersidir (bir satırı "dış"
saymak, deponun yapabileceği işi gizleyebilir).

## Bulgu 2 — Dokunma hedefleri (48 dp barı)

Yedi ekranda **56 tıklanabilir düğüm** ölçüldü. Ölçüm GLOBAL koordinatlarda,
`uiautomator` sınırlarından; MP-80 tanımının istediği budur.

| Ekran | Tıklanabilir | >=48 dp | <48 dp | 0x0 |
|---|---|---|---|---|
| PIN kilit | 15 | 14 | 0 | 1 |
| Onay / KVKK | 4 | 3 | 1 | 0 |
| Onay (kaydırılmış) | 5 | 3 | 2 | 0 |
| Onboarding 5/5 | 2 | 2 | 0 | 0 |
| PIN kurulum | 2 | 2 | 0 | 0 |
| Ana ekran (üst) | 15 | 14 | 0 | 1 |
| Ana ekran (alt) | 13 | 12 | 0 | 1 |
| **Toplam** | **56** | **50** | **3** | **3** |

**48 dp altındaki 3 ölçüm gerçek değil, ScrollView kırpmasıdır.** Yanlış pozitif
bildirmemek için tek tek doğrulandı: KVKK "Detayı Gör" düğmesi kırpılmış hâlde
`304x4 px` görünüyordu; ebeveyni `ScrollView bounds=(0,128,1080,2096)` ve düğme
tam o alt kenarda başlıyor. Kaydırıldıktan sonra aynı düğme `304x126 px =
116x48 dp` ölçüyor, bu kez üstteki kardeşi kırpılıyor. Yani **48 dp altında
doğrulanmış tek bir hedef yoktur.**

**3 adet 0x0 düğüm tek ve aynı düğümdür** — Bulgu 5.

## Bulgu 3 — Semantik kalite

- Her ekran bir ekran düzeyi etiket taşıyor: "Uygulama kilidi. PIN ile açın.",
  "PIN kurulum ekranı, 4 haneli güvenlik PIN'i belirleyin", "Acil kişiler
  listesi...", "Onboarding sayfası N / 5".
- Hata durumları etiketli düğüm olarak yayınlanıyor: "Yanlış PIN. Tekrar
  deneyin.", "PIN'ler uyuşmuyor. Tekrar deneyin.", "Devam etmek için aranabilir
  bir acil kişi gerekir."
- Devre dışı düğmeler `clickable=false` olarak doğru bildiriliyor ("Devam Et ve
  Kurulumu Tamamla" onaylar işaretlenene kadar; "Ekle" rıza kutusu işaretlenene
  kadar).
- **Hiçbir ekranda biyometrik istem yok** — CLAUDE.md kural 2 ile tutarlı,
  cihazda doğrulandı.

## Bulgu 4 — inputBorder düzeltmesi CİHAZDA yakalandı

D-10, `AppColors.inputBorder`'ı ayırıp `InputDecorationTheme`'i ona bağlamıştı ve
`color.json` 3.60:1 diyordu. **Ekran görüntüsünden kenar pikseli örneklendiğinde
`#1D3B54` çıktı** — yani eski renk. Sebep: üç ekran temayı atlayıp kendi
`enabledBorder`'ını veriyordu.

Bu, kanıtın **token'ı** ölçüp **çizileni** ölçmemesinin doğrudan sonucudur ve
yalnızca cihazda görülebilirdi. `b87b74a` ile giderildi; aynı örneklem artık
`#3A76A8` veriyor (PIN kurtarma girişi, y=1305).

Kayda geçen ve DEĞİŞTİRİLMEYEN iki durum:
- `disabledBorder` bilerek eski token'da kaldı — SC 1.4.11 devre dışı bileşenleri
  açıkça muaf tutar.
- `fake_call_screen` `Colors.white12` kullanıyor → arka plana karşı **1.41:1**.
  Sistem arayüzünü taklit eden tuzak ekran olduğu için ayrı bir ürün kararıdır.

## Bulgu 5 — AÇIK SORU: çevrimdışı bandı görünmezken odaklanabilir

`lib/widgets/connectivity_banner.dart` `build()` her zaman `SlideTransition`
döndürüyor; çevrimiçiyken erken çıkış ya da `ExcludeSemantics` yok. Sonuç:
cihaz çevrimiçiyken düğüm semantik ağaçta **`clickable=true focusable=true`,
`bounds=[0,0][0,0]`** olarak duruyor. Üç ayrı ekranda göründü.

**Hata olarak DOĞRULANMADI.** TalkBack boş sınırlı düğümleri genellikle eler ve
bu geçişte TalkBack'in ona odaklandığı gözlenemedi — konuşma metni yakalanamadı
(aşağıdaki sınır). Bunu kapatmak bir insanın gerçek bir geçişte kulakla
dinlemesini gerektirir. Not edilmesinin sebebi: bu widget'ın dosyasında zaten
kayıtlı bir erişilebilirlik kusuru geçmişi var (etkinleştirilemeyen, durum
çubuğunun altında kalan `[0,0][1080,63]` hedefi).

## Bulgu 6 — Panik akışı bu geçişte GEZİLEMEDİ

Ana ekran açıkça şunu yazıyor: **"Panik akışı KoruBeni Pro ile açılır."** SOS
kontrolü lisanslıya kapalı olduğundan geri sayım ve sevk akışı TalkBack ile
gezilemedi. Bu tam olarak `MP-41-017`'nin kaydettiği engelin aynısıdır ve Play
internal-test lisanslı test kullanıcısı gerektirir.

Yani bu geçiş **birincil acil akışı kapsamıyor**. Kapsadığı: onboarding, yasal
onay/KVKK, PIN kurulum, PIN kilit, ana ekran, kişiler, ayarlar, PIN kurtarma.

## Bu geçişin sınırları — açıkça

1. **Emülatör, gerçek donanım değil.** Gerçek dokunmatik jest tanıma ve OEM
   TalkBack varyantları doğrulanmadı.
2. **Debug build**, release değil. R8 semantics'i şeritlemez, ama bu geçiş
   release APK'sında tekrarlanmadı.
3. **Konuşma METNİ yakalanamadı.** TalkBack varsayılan ayrıntı düzeyinde
   söylediklerini logcat'e yazmıyor. Konuştuğu ses odağı olaylarıyla kanıtlandı;
   ne söylediği semantik ağaç etiketlerinden çıkarıldı — TalkBack'in okuduğu
   kaynak budur, ama duyulan çıktı birebir kaydedilmedi.
4. **Kurulum adımları TalkBack KAPALI yapıldı.** TalkBack'in çift-dokunma
   zamanlaması `adb input tap` ile PIN girişini güvenilir biçimde bozdu (iki
   denemede "PIN'ler uyuşmuyor"). Ölçümler TalkBack açıkken alındı; yalnızca
   PIN belirleme/girme adımları kapalıyken yapıldı.
5. **Panik akışı kapsam dışı** (Bulgu 6).

## Sonuç

`MP-46-030` **FAIL → PARTIAL**. "Hiç ekran okuyucu geçişi yapılmadı" iddiası
artık doğru değil: TalkBack gerçekten koştu, 56 dokunma hedefi ölçüldü, 48 dp
altında doğrulanmış hedef çıkmadı, semantik etiketler ve hata duyuruları
yerinde, ve geçiş cihazda gerçek bir kusur bulup giderdi (Bulgu 4).

Kalan artık dürüst biçimde dardır ve bu depodan kapatılamaz: gerçek donanımda
jest tanıma, OEM TalkBack varyantları, ve lisanslı test kullanıcısı gerektiren
panik akışı.
