# KoruBeni — Play Console Gönderim Metinleri

> **Amaç:** Google Play Console'da App content / Data safety / Store listing
> alanlarına yapıştırılacak metinleri tek dosyada toplar. Tüm ifadeler
> `lib/constants/legal_texts.dart` ve gerçek kod davranışıyla (AndroidManifest,
> call_service, check_in_service, revenue_cat_service) **tutarlı** olacak şekilde
> hazırlanmıştır.
>
> **Bu dosya kod davranışını değiştirmez** — yalnız Console'da elle girilecek
> beyan/açıklama metinleridir. Console tıklamaları, demo video çekimi ve
> gerçek-cihaz testleri bu dosyanın kapsamı dışındadır (manuel iş).
>
> İlgili kaynaklar:
> [docs/play_console_declarations.md](play_console_declarations.md) ·
> [store/permissions_declaration_notes.md](../store/permissions_declaration_notes.md) ·
> [docs/google_play_data_safety_notes.md](google_play_data_safety_notes.md)

---

## 1. Foreground service beyanı — UYGULANMAZ

**Manifest gerçeği:** Play build'i `FOREGROUND_SERVICE` veya
`FOREGROUND_SERVICE_SPECIAL_USE` istemez; uygulama özel bir Android foreground
service başlatmaz. Eski `flutter_background_service` bağımlılığı, servis girdisi
ve `specialUse` subtype property kaldırılmıştır.

Aktif oturumdaki görünür bildirim sıradan bir yerel durum bildirimidir; process
keepalive veya zamanlama garantisi değildir. Deadline güvenilirliği native
`AlarmManager` exact alarmı, yalnız başarılı arm sonrası kurulan ayrı inexact yedeği, kalıcı deadline state'i ve
boot/exact-izin restorasyonu ile sağlanır.

**Play Console işlemi:** Bu build için `specialUse` beyanı veya FGS demo videosu
gönderme. Console'da eski taslak varsa kaldır. Upload edilen AAB'nin merged
manifestinde FGS izni/servisi bulunmadığını ayrıca doğrula.

### Gerçek-cihaz alarm + bildirim kanıtı

Bu kayıt Play FGS beyanı için değil, release QA kanıtı içindir. Oturum durum
bildiriminin kullanıcı kontrolünü ve native deadline'ın arka plan/Doze davranışını
gösterir:

1. Uygulamayı aç, PIN ile gir (biyometrik YOK — duress koruması).
2. **Check-In** (veya Safe Walk) ekranını aç; bir süre seç ve oturumu başlat.
3. Status bar'da oturum durum bildirimini göster.
4. Telefonu kilitle / uygulamayı arka plana al ve cihazı Doze'a al.
5. Geri dön; süre/grace dolmadan **"Güvendeyim" onayı** ver → native alarm ve
   yedeği iptal edilir, bildirim kaybolur.
6. İkinci çekim: onay verilmezse süre + 60 sn grace dolar → **yalnız birincil
   acil kişi** aranır (112 yok). Otomatik aramayı bu noktada göster (bkz. §2).

### QA evidence video — shot list (çekime hazır kayıt planı)

> Yukarıdaki senaryonun çekime hazır hâli; Console'a yüklenecek video **bu listeyle**
> çekilir — ikisi ayrışırsa bu shot list esastır. Aynı listeye QA matrisinden de
> işaret edilir ([REAL_DEVICE_QA_MATRIX.md K1](../store/REAL_DEVICE_QA_MATRIX.md)).

**Ön-koşullar:**

- Gerçek cihaz; ideali **imzalı internal-testing build'i**.
- Pro, **license tester** hesabıyla açık (paywall görünmez).
- **İkinci telefon** birincil acil kişi olarak kayıtlı (otomatik aramanın hedefi).
- Bildirimler açık; **durum çubuğu saati görünür** (zaman akışının kanıtı).
- Hedef süre **60–90 sn**; sahne kesmeli kurgu serbest.
- Teslim: erişimi kısıtlı, redacted iç QA arşivi. Bu build FGS beyan etmediği için
  video bir Console FGS formuna yüklenmez.

**Sahneler (altyazılar İngilizce — AYNEN bu metinlerle):**

| # | Sahne | Altyazı (EN, aynen) |
|---|---|---|
| 1 | Ana ekran | "KoruBeni — personal safety app (Turkish UI)." |
| 2 | Check-In ekranı; en kısa süre seçilir; Başlat | "User starts a timed safety check-in session." |
| 3 | Bildirim çekmecesi; oturum durum bildirimi 2–3 sn ekranda | "Visible status notification while the safety session is active." |
| 4 | Uygulama arka plana + ekran kilidi; saat görünür | "Native alarm scheduling protects the user-started deadline in the background." |
| 5 | Kesme ("a few minutes later"); süre dolar, grace heads-up görünür; cihaza DOKUNULMAZ | "Time expired — 60-second grace warning. User does not respond." |
| 6 | Grace dolar → giden arama ekranı; test numarası kayıtta maskelenir | "No response → automatic call to the user-chosen emergency contact." |
| 7 | (Opsiyonel) ikinci telefon çalarken dış çekim | "The pre-selected contact's phone rings. The app never auto-dials 112/911." |
| 8 | Oturum kapanışı | "Session ends — fully user-initiated and time-bounded." |

---

## 2. CALL_PHONE / otomatik arama — mağaza açıklaması paragrafı

**Kod gerçeği:**
- `android/app/src/main/AndroidManifest.xml`: `CALL_PHONE` beyan edilmiş, izin
  reddedilirse **dialer'a düşer** (kullanıcı yeşil tuşa basar).
- `lib/core/services/call_service.dart`: `directCallStarted` başarısızsa
  `dialerOpened`; boş/geçersiz hedef **failure**'dır, asla 112 sentezlenmez
  (`call_service.dart:73`).
- `lib/core/utils/emergency_number_validator.dart`: yalnız 7–15 haneli **gerçek
  kullanıcı kişi numarası** çağrılabilir hedef sayılır; resmi kısa kodlar (112)
  asla otomatik arama hedefi olmaz.
- `lib/core/services/check_in_service.dart`: süre + 60 sn grace dolarsa **yalnız
  birincil acil kişi** aranır (no 112, no failover — SPEC §0 K1/K2).

### Store listing paragrafı (TR — açıklamaya gömülecek)

```text
Otomatik acil arama: Panik/SOS, Check-In ve Güvenli Yürüyüş akıllarında, sizin
belirlediğiniz süre ve ek 60 saniyelik onay (grace) süresi içinde "güvendeyim"
onayı vermezseniz, uygulama önceden tanımladığınız BİRİNCİL acil kişiyi otomatik
olarak arar. Uygulama 112 veya resmi acil çağrı kısa kodlarını aramaz; yalnızca
sizin rehberinizden seçtiğiniz/girdiğiniz gerçek kişi numarasını arar. Arama izni
verilmemişse uygulama çökmez; telefon uygulamasının çevirici ekranını açar ve
aramayı sizin başlatmanız beklenir. Bu davranış, otomatik aramadan ÖNCE uygulama
içinde belirgin bir bilgilendirme (prominent disclosure) ile açıkça anlatılır ve
onayınız alınır.
```

> Uygulama-içi prominent disclosure referansı:
> `lib/constants/legal_texts.dart` (KVKK/EULA metinleri) + arming/countdown akışı
> (`lib/widgets/panic_button.dart`, `lib/screens/countdown_screen.dart`).
> Not: Panik aramayı ARMAK için en az bir **çağrılabilir acil kişi** zorunludur
> (commit `684ba5d`).

---

## 3. REQUEST_IGNORE_BATTERY_OPTIMIZATIONS gerekçesi

**Kod gerçeği:**
- `lib/core/utils/permission_helper.dart:77`: izin istenmeden ÖNCE açık beyan
  gösterilir (`requestBatteryOptimizationExemption`).
- `lib/core/services/emergency_readiness_service.dart`: whitelist durumu
  (`batteryOptimizationWhitelisted`) okunur; **reddedilse de uygulama çalışır**,
  yalnız güvenilirlik düşer.

### Console / permissions beyan metni (yapıştır)

```text
KoruBeni requests battery-optimization exemption ONLY to improve the reliability
of active, user-started safety sessions (Safe Walk, Check-In, emergency countdown)
under Doze mode and manufacturer battery restrictions, so the safety timer and the
automatic primary-contact call can fire on time. The request is shown with an
explicit in-app disclosure before the system dialog.

This permission is NOT required for the app to function: if the user denies it,
the app continues to run in a degraded reliability mode — timers and the emergency
call still operate, but may be delayed or interrupted by aggressive OEM battery
management. No background tracking, ads, or analytics depend on this permission.
```

---

## 4. Data Safety form cevapları

> Kaynak: `lib/constants/legal_texts.dart` (KVKK veri envanteri) +
> [docs/google_play_data_safety_notes.md](google_play_data_safety_notes.md) +
> [store/google_play_data_safety_answers.md](../store/google_play_data_safety_answers.md).
> **Temel ilke:** PII geliştirici sunucusuna gönderilmez; birincil veri kopyası
> cihazda yerel tutulur.

| Veri türü | Toplanıyor? | Paylaşılıyor? | Saklama | Açıklama |
|---|---|---|---|---|
| **Konum (yaklaşık/kesin)** | Evet | Hayır | **Yalnız oturum, kalıcı değil** | On-demand, foreground'da; harita/SOS akışında. Arka plan konum yok, sürekli akış yok. |
| **Kişiler (acil kişiler)** | Evet | Hayır | Cihazda yerel | Uygulama **tüm rehberi okumaz**; `Intent.ACTION_PICK` ile yalnız kullanıcının seçtiği/elle girdiği kişi saklanır (`READ_CONTACTS` runtime'da gerekmez). |
| **PIN (kimlik doğrulama)** | Evet | Hayır | Cihazda **şifreli** | Yerel PIN; paylaşılmaz, sunucuya gitmez. Biyometrik kilit **yoktur** (duress koruması). |
| **Cihaz / OS bilgisi** | Evet | Hayır | Cihazda yerel | Yalnız **rıza logu** (rıza türü, tarih, versiyon) — KVKK uyum kaydı. |

**Console serbest-metin notu (yapıştır):**

```text
No personal data (PII) is transmitted to developer-operated servers. The primary
copy of app data (PIN, emergency contacts, history) is stored locally on the
device; PIN is encrypted. Location is used on demand only and is not persisted
beyond the active session. Contacts are not bulk-read — only the user-selected or
manually-entered emergency contact is stored locally (Intent.ACTION_PICK). The
emergency flow sends no automatic messages.

Optional third-party processors handle only their own scoped functions under their
own privacy policies, not developer PII collection: RevenueCat / Google Play
Billing (subscription/entitlement verification) and OpenStreetMap (on-demand map
tiles). KoruBeni does not bulk-download, pre-cache, scrape, archive, or repackage
OSM tiles.
```

---

## 5. İçerik derecelendirme (Content Rating)

**Kod gerçeği:** `lib/constants/legal_texts.dart:32` — "Bu uygulamayı kullanmak
için 18 yaşından büyük olmanız gerekmektedir. Bu sürümde 18 yaş altı kullanım
desteklenmez."

```text
Target audience: 18+ (adults only). The EULA sets a strict 18+ age requirement;
under-18 use is not supported in this release. No ads, no user-generated content,
no social features. Answer the IARC questionnaire accordingly (no violence,
sexual content, gambling, or controlled substances).
```

> Ayrıntılı IARC anket cevapları için
> [store/CONTENT_RATING_ANSWERS.md](../store/CONTENT_RATING_ANSWERS.md).

---

## 6. Abonelik eşleşmesi (entitlement ↔ Play Console ürünü)

**Kod gerçeği:** `lib/core/services/revenue_cat_service.dart:22` —
`entitlementId = 'KoruBeni Pro'`.

```text
RevenueCat entitlement identifier "KoruBeni Pro" MUST map to the Play Console
subscription product's entitlement in the RevenueCat dashboard. Verify:
  - Play Console subscription product (base plan) is created and Active.
  - RevenueCat → Entitlements → "KoruBeni Pro" is attached to that product.
  - The entitlement string matches EXACTLY (case-sensitive): "KoruBeni Pro".
Entitlement status is cached locally by RevenueCat, so Pro access works offline
once verified.
```

> Pro açtığı özellikler ücretsizden ayrımı için
> `lib/core/constants/feature_access_matrix.dart`. Acil kişi yönetimi ve siren bu
> sürümde **ücretsiz** (legal_texts.dart:25).

---

## Gönderim öncesi hatırlatma

- İlk Play yüklemesi **mutlaka git etiket push'u** ile yapılmalı (versionCode
  etiketten türetilir: `v1.0.0 → 10000`). Lokal AAB ile yapma — bkz.
  [release_risks.md](release_risks.md) / `.github/workflows/release.yml`.
- Keystore yedeği + güçlü parola **geliştiricinin sorumluluğunda**
  (KEYSTORE_BASE64 / STORE_PASSWORD secret'ları); kaybolursa Play imza kimliği
  geri alınamaz.
