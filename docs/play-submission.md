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

## 1. Foreground Service `specialUse` gerekçesi (EN KRİTİK Console maddesi)

**Manifest gerçeği:** `android/app/src/main/AndroidManifest.xml`
- `FOREGROUND_SERVICE_SPECIAL_USE` izni beyan edilmiş.
- `id.flutter.flutter_background_service.BackgroundService` →
  `android:foregroundServiceType="specialUse"`.
- `PROPERTY_SPECIAL_USE_FGS_SUBTYPE` = **`emergency_checkin_keepalive`**.
- Geolocator'ın konum FGS'i (`GeolocatorLocationService`) manifest'ten
  `tools:node="remove"` ile **çıkarılmıştır** — serviste konum akışı yoktur.

### Console "App content → Special Use foreground service" beyan metni (yapıştır)

```text
KoruBeni uses a foreground service ONLY for active, user-started personal-safety
sessions: Safe Walk, Check-In, and the emergency countdown/keepalive timer. The
session shows a visible, persistent notification and is tied to the user's active
safety flow; the user can stop or cancel it at any time.

The service performs timer accounting, exact-alarm scheduling, and persistent
notification upkeep only. It does NOT stream location, record audio, run ads,
collect analytics, perform hidden tracking, or execute indefinitely in the
background. Geolocator's bundled foreground location service is removed from the
merged manifest (tools:node="remove"); location is read on demand only, in the
foreground Activity context.

specialUse is used because the work (a user-perceptible safety-session keepalive
that keeps alarm + notification paths firing reliably under Doze) does not fit any
named Android 14/15 type: 'location' would imply continuous location streaming
(not done); 'dataSync' is capped at a 6-hour quota on Android 15+; 'shortService'
is capped at ~3 minutes (sessions can run tens of minutes). Subtype declared in
the manifest as emergency_checkin_keepalive.
```

> Tam tip-seçim gerekçesi (neden `location`/`dataSync`/`shortService` değil) için
> [docs/play_console_declarations.md](play_console_declarations.md) §"Foreground
> Service specialUse".

### Demo video senaryosu (Console için ben çekeceğim)

FGS'i tetikleyen adımları, persistent notification'ı ve kullanıcı kontrolünü
gösterir:

1. Uygulamayı aç, PIN ile gir (biyometrik YOK — duress koruması).
2. **Check-In** (veya Safe Walk) ekranını aç; bir süre seç (ör. 5 dk) ve
   oturumu **kullanıcı olarak başlat** → bu noktada foreground service başlar.
3. Status bar'da **kalıcı bildirimi göster** (oturum aktif olduğunun kanıtı).
4. Telefonu kilitle / uygulamayı arka plana al → bildirim kalır, oturum sayacı
   sürer (Doze altında keepalive amacı budur).
5. Geri dön; süre/grace dolmadan **"Güvendeyim" onayı** ver → service durur,
   bildirim kaybolur (kullanıcı kontrolü kanıtı).
6. İkinci çekim: onay verilmezse süre + 60 sn grace dolar → **yalnız birincil
   acil kişi** aranır (112 yok). Otomatik aramayı bu noktada göster (bkz. §2).

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
