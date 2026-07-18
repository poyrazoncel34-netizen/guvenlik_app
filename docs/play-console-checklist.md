# KoruBeni — Play Console Yayın Kontrol Listesi (Operatör Akışı)

> **Amaç:** Operatörün Play Console'da adım adım izleyeceği TEK dosya. Her adım:
> **(a)** Console'da NEREYE gidileceği, **(b)** tam yapıştırılacak metin (veya
> kaynağa bağlantı), **(c)** bağımlılık. Bu dosya **kod davranışını değiştirmez**
> ve **yeni içerik uydurmaz** — yalnız mevcut dokümanları operatör-akışına dizer.
>
> **Kaynak dokümanlar** (tam metinler buralarda):
> [docs/play-submission.md](play-submission.md) ·
> [docs/play_console_declarations.md](play_console_declarations.md) ·
> [store/permissions_declaration_notes.md](../store/permissions_declaration_notes.md) ·
> [store/DATA_SAFETY_FORM.md](../store/DATA_SAFETY_FORM.md) ·
> [store/CONTENT_RATING_ANSWERS.md](../store/CONTENT_RATING_ANSWERS.md) ·
> [store/PLAY_CONSOLE_COPY_PASTE_PACK.md](../store/PLAY_CONSOLE_COPY_PASTE_PACK.md) ·
> [store/play_store_listing_tr.md](../store/play_store_listing_tr.md) ·
> [store/MANUAL_SMOKE_TEST_SCRIPT.md](../store/MANUAL_SMOKE_TEST_SCRIPT.md) ·
> [store/REAL_DEVICE_QA_MATRIX.md](../store/REAL_DEVICE_QA_MATRIX.md)
>
> ⚠️ **DEĞİŞMEZ KURALLAR:**
> - Uygulama **112 veya resmi acil kısa kodları ASLA otomatik aramaz** — yalnız
>   kullanıcının seçtiği/girdiği gerçek BİRİNCİL kişi numarası aranır. Hiçbir
>   Console/store metnine "112'yi arar" yazma.
> - İlk yükleme **git etiketinden (CI) üretilen imzalı AAB** ile yapılır. Lokalde
>   üretilmiş AAB **yüklenmez** (versionCode etiketten türer: `v1.0.0 → 10000`).

---

## 0. Başlamadan — ön koşullar

| # | Ön koşul | Kim | Kanıt / Not |
|---|---|---|---|
| 0.1 | Keystore yedeği + güçlü parola (`KEYSTORE_BASE64`, `STORE_PASSWORD` secret'ları) | **Operatör** | Kaybolursa Play imza kimliği geri alınamaz. |
| 0.2 | Yasal URL'ler canlı mı? (aşağıdaki §3.1 ve §3.10) | **Operatör** | Tarayıcıda aç, içerik + tarih damgası doğru mu kontrol et. |
| 0.3 | Gerçek-cihaz QA tamamlandı mı? | **Operatör** | [MANUAL_SMOKE_TEST_SCRIPT.md](../store/MANUAL_SMOKE_TEST_SCRIPT.md) → sonuçları [REAL_DEVICE_QA_MATRIX.md](../store/REAL_DEVICE_QA_MATRIX.md). Production'dan ÖNCE. |
| 0.4 | RevenueCat dashboard + Play abonelik ürünü Active mi? | **Operatör** | §4. |
| 0.5 | İmzalı AAB git etiketinden üretildi mi? | **Operatör** | `v1.0.0` push → `.github/workflows/release.yml`. Lokal AAB yükleme. |

---

## Bağımlılık sırası (özet)

```
1. Uygulama oluştur
2. Store listing (metin + grafikler: ikon, feature graphic 1024x500, ekran görüntüleri)
3. App content (Policy) — şu sırayla:
     3.1 Privacy policy URL  ─┐ (çoğu beyandan önce gerekir)
     3.2 App access (Pro test talimatı)
     3.3 Ads = No
     3.4 Content rating (IARC) ──► SERTİFİKA   (production'dan önce zorunlu)
     3.5 Target audience = 18+
     3.6 Data safety           (closed/open/production'dan önce zorunlu)
     3.7 Foreground service manifest check (beyan UYGULANMAZ)
     3.8 Hassas izinler: CALL_PHONE / EXACT_ALARM / BATTERY
     3.9 Government/Financial/Health = N/A
     3.10 Data deletion URL
4. Subscriptions — "KoruBeni Pro" entitlement eşleşmesi (paywall'dan önce Active olmalı)
5. Testing track (internal → closed) → AAB yükle (CI etiketinden)
6. Production release (3.4 + 3.6 + QA tamamsa)
```

---

## 1. Uygulama oluştur

**Nereye:** Play Console → **All apps → Create app**

| Alan | Değer |
|---|---|
| App name | `KoruBeni - Kişisel Güvenlik` |
| Default language | `Türkçe (tr-TR)` |
| App or game | App |
| Free or paid | **Free** (Pro, uygulama-içi abonelik) |
| Declarations | Developer Program Policies + US export laws onayı |

---

## 2. Store listing (Main store listing)

**Nereye:** **Grow → Store presence → Main store listing**

**App name (paste):**
```text
KoruBeni - Kişisel Güvenlik
```

**Short description (80 karakter) (paste):**
```text
Panik/SOS Pro; konum, sahte çağrı ve siren ücretsiz.
```

**Full description:** [store/play_store_listing_tr.md](../store/play_store_listing_tr.md) içindeki
"Full Description (4000 karakter)" bloğunu yapıştır. İlk sürüm
**Turkish-only**: [store/play_store_listing_en.md](../store/play_store_listing_en.md)
yalnız iç referanstır; İngilizce runtime yeniden açılıp gerçek cihazda test
edilmeden Play Console'a yapıştırma veya İngilizce listing oluşturma.

**Grafikler (Graphics):**

| Asset | Dosya | Not |
|---|---|---|
| App icon (512×512) | [store/assets/play_icon_512.png](../store/assets/play_icon_512.png) | 32-bit PNG |
| **Feature graphic (1024×500)** | [store/assets/feature_graphic_1024x500.png](../store/assets/feature_graphic_1024x500.png) | 24-bit PNG, alfa YOK. TASLAK — beğenmezsen `store/assets/make_feature_graphic.py` ile yeniden üret. |
| Phone screenshots | [store/screenshots/](../store/screenshots) | Harita ekranlarında **OpenStreetMap atıfı görünür** olmalı. |

> Tüm görsel/store metin paketinin tek elden hâli:
> [store/PLAY_CONSOLE_COPY_PASTE_PACK.md](../store/PLAY_CONSOLE_COPY_PASTE_PACK.md).

---

## 3. App content (Policy → App content)

**Nereye:** **Policy → App content**. Aşağıdaki sırayı izle.

### 3.1 Privacy policy

**Nereye:** App content → **Privacy policy**
**Bağımlılık:** Diğer birçok beyandan önce gereklidir. Önce URL'nin canlı olduğunu doğrula (§0.2).

**Paste (URL):**
```text
https://poyrazoncel34-netizen.github.io/guvenlik_app/privacy_policy.html
```

### 3.2 App access

**Nereye:** App content → **App access**
Panik/SOS bir **KoruBeni Pro** özelliğidir; reviewer'ın Pro'yu test edebilmesi için
talimat ver. **Bağımlılık:** §4 (abonelik ürünü Active) ile tutarlı olmalı.

**Reviewer path (paste):**
```text
Home -> locked Pro Panic/SOS button -> Paywall/test purchase -> Pro entitlement active -> Home -> Panic/SOS button -> long press -> emergency countdown.
```

**Testing instructions (paste):**
```text
Use a Google Play license tester account or internal/closed test track account.
Install the Play internal/closed testing build.
Open the paywall from the locked Panic/SOS button or Settings -> KoruBeni Pro.
Complete sandbox/test purchase for the configured monthly or annual plan.
Return to Home and verify the Panic/SOS button shows active Pro copy before long press.
```

### 3.3 Ads

**Nereye:** App content → **Ads** → **No, my app does not contain ads.**
(Repo doğrulaması: reklam SDK'sı yok.)

### 3.4 Content rating (IARC questionnaire)

**Nereye:** App content → **Content rating**
**Bağımlılık:** Sertifika **production yayınından önce** alınmalı.
Tam IARC cevapları: [store/CONTENT_RATING_ANSWERS.md](../store/CONTENT_RATING_ANSWERS.md).
Özet: Violence/Sexual/Language/Controlled substances/Horror = **None**;
UGC = No; Simulated gambling = None; Social interaction = Yes (acil kişiler/arama akışı);
Shares location = No automatic sharing.

### 3.5 Target audience and content

**Nereye:** App content → **Target audience and content**

**Paste:**
```text
Target audience: 18+ (adults only). The EULA sets a strict 18+ age requirement; under-18 use is not supported in this release. No ads, no user-generated content, no social features. Answer the IARC questionnaire accordingly (no violence, sexual content, gambling, or controlled substances).
```
> **Designed for Families'e GİRME.** (Kaynak: legal_texts 18+; CONTENT_RATING_ANSWERS.)

### 3.6 Data safety

**Nereye:** App content → **Data safety**
**Bağımlılık:** Closed/open/production için zorunlu (internal testing'de muaf olabilir).
Tam form + veri türü tablosu: [store/DATA_SAFETY_FORM.md](../store/DATA_SAFETY_FORM.md).

**Temel cevaplar:**
- Collect/share required user data types? → **Yes** (yalnız Play Billing/RevenueCat abonelik + online harita karo isteği nedeniyle; cihazda-yerel veriyi "geliştirici topluyor" diye işaretleme).
- Data sold? → **No.** · Users can request data deletion? → **Yes.**
- Blanket "encryption in transit" işaretleme; yerel-veri geliştirici sunucusuna gitmez.

**Console serbest-metin (paste):**
```text
KoruBeni does not operate a developer backend. Emergency contacts, profile data, PIN, fake-call settings, local activity history, and consent records are stored on device. The app does not read the full contacts list; it stores only emergency contacts selected or entered by the user, locally on the device. Optional Pro subscription processing is handled by Google Play Billing and RevenueCat. Online map screens may request map tiles from the configured map tile provider, currently OpenStreetMap tile infrastructure, only for the map viewport the user actively opens. The app does not bulk download, scrape, pre-seed, archive, or package OpenStreetMap public tiles. The app does not use ads, analytics, crash reporting SDKs, auth backend, cloud database, SMS sending, microphone, audio recording, account creation, or user-generated content in this Play release.
```

### 3.7 Foreground service — beyan UYGULANMAZ

Play build'i `FOREGROUND_SERVICE` / `FOREGROUND_SERVICE_SPECIAL_USE` istemez ve
özel bir foreground service başlatmaz. `flutter_background_service`, servis
manifest girdisi ve `specialUse` subtype property kaldırılmıştır.

**Operatör kontrolü:** AAB upload sonrasında bundle izinleri/merged manifestte
FGS izni veya servisi görünmemeli. Eski Console taslağı varsa kaldır; bu build
için FGS beyanı veya demo videosu gönderme. Oturum bildirimi yalnız kullanıcıya
durum gösterir; timing güvenilirliği exact alarm + bağımsız inexact fallback +
boot/izin restorasyonuna dayanır.

### 3.8 Hassas izinler (varsa Console ayrı beyan ister)

**Nereye:** App content → ilgili izin beyanı bölümleri.
Tam metinler: [store/permissions_declaration_notes.md](../store/permissions_declaration_notes.md).

**CALL_PHONE (paste) — 112 YOK:**
```text
CALL_PHONE is limited to Panic/SOS, Check-In, and Safe Walk sessions explicitly armed by the user. At expiry Android may submit an unconfirmed Telecom request for the immutable pre-selected contact; the app never claims ringing or connection and never synthesizes 112/911. If automatic submission cannot be used, an actionable notification exposes a user-tapped ACTION_DIAL path.
```

**SCHEDULE_EXACT_ALARM (paste):**
```text
KoruBeni uses exact alarms for user-visible safety deadlines and timers, including Panic/SOS countdown backup, check-in expiry, grace periods, and Safe Walk timers. Delay can affect the expected safety behavior of these user-started flows. The app is not using exact alarms for ads, analytics, marketing, hidden tracking, or arbitrary background work.
```
Fallback (gerekirse paste):
```text
If exact alarm access is denied or unavailable, Check-In, Safe Walk, and scheduled fake-call sessions are not armed. Panic may continue only as a visible foreground countdown ending in a user-confirmed `ACTION_DIAL` path; no background guarantee is claimed. The independently keyed inexact alarm is armed only after exact scheduling succeeds, as a residual backup if exact access is later revoked.
```

**REQUEST_IGNORE_BATTERY_OPTIMIZATIONS (paste):**
```text
KoruBeni requests battery optimization exemption only as an optional reliability improvement for active user-started safety sessions such as Safe Walk and check-in. Android and OEM battery settings may still affect behavior. The user can decline, and the app explains that timer/background reliability may be degraded.
```

> Not: `READ_CONTACTS` istenmez (sistem seçici/manuel giriş), `READ_PHONE_STATE`
> yok, `ACCESS_BACKGROUND_LOCATION` yok, SMS izni yok.

### 3.9 Diğer App content kalemleri

- **Government apps:** No · **Financial features:** None.
- **Health Apps Declaration:** Form bütün uygulamalar için gönderilir; actual
  build sağlık özelliği sunmadığından “No health features” seçilir.
- **FLAG_SECURE reviewer note:** Global `FLAG_SECURE` yoktur; screenshot
  mümkündür. Yalnız app background olduğunda recents privacy mask gösterilir.

### 3.10 Data deletion

**Nereye:** App content → **Data deletion** (veya Data safety içinde "data deletion request" alanı)

**Paste (URL):**
```text
https://poyrazoncel34-netizen.github.io/guvenlik_app/data_deletion.html
```
> Cihaz içi veri "Verilerimi Sil" / uygulama verisini silme ile kalkar; abonelik
> iptali Google Play üzerinden ayrı yönetilir.

---

## 4. Subscriptions — "KoruBeni Pro" entitlement eşleşmesi

**Nereye:** **Monetize → Products → Subscriptions**
**Bağımlılık:** Paywall'ın çalışması için ürün **Active** olmalı; §3.2 reviewer testi buna bağlı.

**RevenueCat eşleşmesi (paste/checklist):**
```text
RevenueCat entitlement identifier "KoruBeni Pro" MUST map to the Play Console
subscription product's entitlement in the RevenueCat dashboard. Verify:
  - Play Console subscription product (base plan) is created and Active.
  - RevenueCat -> Entitlements -> "KoruBeni Pro" is attached to that product.
  - The entitlement string matches EXACTLY (case-sensitive): "KoruBeni Pro".
Entitlement status is cached locally by RevenueCat, so Pro access works offline once verified.
```

---

## 5. Testing → Release

**Nereye:** **Test and release → Testing → Internal testing** (sonra Closed),
ardından **Production**.

1. **AAB'yi git etiketinden (CI) üret ve yükle** — `v1.0.0` push →
   `.github/workflows/release.yml` imzalı AAB üretir (versionCode etiketten:
   `v1.0.0 → 10000`). **Lokal AAB yükleme.**
2. Internal testing → release oluştur, testçileri ekle
   ([store/INTERNAL_TESTING_GUIDE.md](../store/INTERNAL_TESTING_GUIDE.md)).
3. Closed testing → tester listesi
   ([store/CLOSED_TEST_TESTER_GUIDE.md](../store/CLOSED_TEST_TESTER_GUIDE.md)).
4. Production → yalnız §3.4 (content rating sertifikası) + §3.6 (data safety) +
   §0.3 (gerçek-cihaz QA) tamamsa.

---

## 6. Operatörün manuel işi (Claude Code YAPAMAZ — hatırlatıcı)

- **Gerçek cihaz QA:** telefon arama (test-güvenli numara), Doze/exact-alarm,
  batarya, bildirim, konum, offline/no-SIM — özellikle **Xiaomi/MIUI + Samsung**.
  Emülatör kesin değil. ([MANUAL_SMOKE_TEST_SCRIPT.md](../store/MANUAL_SMOKE_TEST_SCRIPT.md))
- **Play Console'da form gönderme / beyan tıklama / FGS demo videosu çekme** (§3.7).
- **Keystore yedeği + imza sırları + upload sertifika parmak izi**; RevenueCat için istemciye uygun Android public SDK key kullanılır, `sk_` server secret gömülmez.
- **`v1.0.0` etiketini push edip CI'dan imzalı AAB üretmek** (lokal AAB değil).
- Yayında **paket sürümü YÜKSELTME** (özellikle `purchases_flutter`); pinler test edilmiş.

> Hiçbir kalemi "submitted/PASS" olarak işaretleme — operatör harici kanıt
> kaydetmeden. Bu dosya yalnız yapıştırılacak metni ve sırayı verir.
