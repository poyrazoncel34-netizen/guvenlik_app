# Play Console Copy-Paste Pack — KoruBeni

Source scope: `store/DATA_SAFETY_FORM.md`, `docs/play_console_declarations.md`, `store/permissions_declaration_notes.md`, `store/CONTENT_RATING_ANSWERS.md`, `store/play_store_listing_tr.md`, `store/STORE_LISTING_COPY_PASTE.md`, `lib/core/constants/app_constants.dart`.

Use this pack as Play Console entry text. Keep final URLs, product IDs, RevenueCat offering IDs, screenshots, and signed build status verified before submission.

Status rule: this pack is CODE_DONE copy preparation only. Play Console forms are `PLAY_CONSOLE`; RevenueCat setup is `REVENUECAT`; signed AAB work is `SIGNING`; live URL/store operations are `NEEDS_OPERATOR_ACTION`; real-device QA is `NEEDS_REAL_DEVICE_TEST`; uncertain legal/policy claims are `NEEDS_OWNER_REVIEW` or `UNKNOWN` until resolved.

Data Safety track nuance: internal testing may be exempt from the Data Safety section depending on Play Console state. Closed testing, open testing, and production require Data Safety where Play presents it. Legal/privacy docs must still be consistent before internal testing.

External gates to record in the release tracker:

```text
PLAY_CONSOLE: Data Safety, Content Rating, Target Audience, FGS declaration, exact alarm declaration if requested, CALL_PHONE/sensitive permission declaration, pre-launch report.
REVENUECAT: dashboard app, entitlement, current offering, monthly/annual packages, purchase/restore/cancel/expired/no-offering/network evidence.
SIGNING: real signing config, pinned upload-certificate fingerprint, signed AAB build, signed AAB upload. RevenueCat Android public SDK key is a client identifier; never substitute an `sk_` server secret.
NEEDS_REAL_DEVICE_TEST: API29/API36/16 KB, Pixel/Samsung/Xiaomi, dual-SIM and low-memory evidence; notification/exact denial, Direct Boot, no SIM and billing sandbox.
NEEDS_OPERATOR_ACTION: live privacy/terms/aydinlatma/data deletion URL verification, screenshot PII review, CI log secret review.
NEEDS_OWNER_REVIEW: legal wording or policy claims not verified by repo evidence.
UNKNOWN: any item where Play Console account state or external dashboard state is unavailable.
```

---

## 1. App Identity

**Package name**

```text
com.poyrazoncel.korubeni
```

**App name**

```text
KoruBeni
```

**Category recommendation**

```text
Tools / Safety
```

If Play Console requires a single category, use `Tools`. Keep safety positioning in the listing copy and declarations.

**Default language recommendation**

```text
Turkish (Turkey) / tr-TR
```

First Google Play release is Turkish-only. Do not create an English localization entry until the English runtime path is re-enabled and tested.

**Store assets**

```text
Store icon: 512x512 PNG.
Feature graphic: prepare or verify 1024x500 in Play Console.
Screenshots: upload from store/screenshots/android/final/ only after manual PII review.
```

---

## 2. Store Listing TR

**Title**

```text
KoruBeni - Kişisel Güvenlik
```

**Short description**

```text
Panik/SOS Pro; konum, sahte çağrı ve siren ücretsiz.
```

**Full description**

```text
KoruBeni, konum durumunuzu görmenize, cihaz içi sahte çağrı simülasyonu çalıştırmanıza ve Pro abonelikle ek kişisel güvenlik araçlarını kullanmanıza yardımcı olan bir Android uygulamasıdır.

KoruBeni ücretsiz temel güvenlik araçları sunar. Panik/SOS, güvenli yürüyüş, check-in ve gelişmiş güvenlik otomasyonları KoruBeni Pro ile kullanılabilir.

⚠️ ÖNEMLİ: KoruBeni resmi bir acil servis değildir ve 112'nin yerine geçmez. Gerçek bir acil durumda lütfen önce 112'yi arayın. KoruBeni yalnızca tamamlayıcı bir araçtır ve fiziksel koruma sağlamaz.

★ ÜCRETSİZ ÖZELLİKLER ★

◉ Konum Oturumu
Konum alınabilirse uygulama içinde gösterin; alınamazsa açık hata durumu görün.

◉ Sahte Arama
Rahatsız edici durumlardan uzaklaşmak için cihaz içinde çalışan kişisel güvenlik amaçlı sahte gelen arama simülasyonu oluşturun. Bu özellik gerçek telefon araması başlatmaz ve üçüncü kişilere iletişim göndermez.

◉ Siren
Yüksek sesli alarm ile çevrenizdeki insanların dikkatini çekin.

◉ Acil Kişiler
Rehberinizden güvenilir kişileri yerel olarak kaydedin ve yönetin.

★ KORUBENİ PRO İLE AÇILAN ÖZELLİKLER ★

◉ Panik/SOS Butonu
KoruBeni Pro ile uzun basarak panik akışını başlatın. 10 saniyelik geri sayım ile yanlışlıkla tetiklemeyi önleyin. Bu özellik ücretsiz planda çalışmaz.

◉ Güvenli Yürüyüş
Gece veya güvensiz ortamlarda yardımcı check-in oturumu başlatın. Arka plan davranışı Android ayarlarına bağlıdır.

◉ Check-in
Belirlediğiniz süre sonunda kontrol akışı başlatan yardımcı check-in oturumları kullanın.

◉ Güvenlik Geçmişi
Uygulama içi güvenlik olaylarınızı cihazda yerel olarak görün.

◉ Ses Tuşu Tetikleyici ve Test Modu
Pro kullanıcılar için gelişmiş güvenlik otomasyonlarını ve gerçek arama yapmadan test akışını kullanın.

KoruBeni Pro isteğe bağlı bir aboneliktir. Satın alma, yenileme, iptal ve geri yükleme işlemleri Google Play üzerinden yönetilir.

★ GÜVENLİK ★

• 4 haneli PIN ile uygulama koruması
• PIN bilgisi için güvenli cihaz içi depolama
• Acil kişi kayıtları için cihaz içi yerel veritabanı
• Geliştirici sunucusu olmayan offline-first mimari

★ GİZLİLİK ★

• KoruBeni'nin bulut hesabı yoktur. Tüm verileriniz cihazınızda kalır.
• Arka planda konum izlemiyoruz. Konum yalnızca siz bir oturum başlattığınızda kullanılır.
• Verilerinizi hiçbir reklam ağıyla veya veri komisyoncusuyla paylaşmıyoruz; satmıyoruz.
• Pro abonelik için Google Play Billing aracılığıyla yalnızca satın alma geçmişi tutulur.
• Harita ve Play Billing sağlayıcılarının kendi teknik ağ davranışları olabilir.

KoruBeni — Ücretsiz konum oturumu ve sahte çağrı; Pro ile ek güvenlik araçları.
```

---

## 3. Additional Store Listing Localizations

```text
Do not add an English Play listing for the first Google Play release.
The app currently launches publicly in Turkish. English listing/reference files (see store/play_store_listing_en.md) may remain in the repository only as internal preparation material and must not be pasted into Play Console until full English runtime support is re-enabled and tested.
```

### Internal English reference — DO NOT paste into Play Console for the first release

Kept here only so the English copy stays in sync with TR when the English Play listing is eventually enabled. Includes the same 112 disclaimer placement as the live Turkish listing.

```text
KoruBeni - Personal Safety

Short description:
Panic/SOS requires Pro; location, fake call, and siren are free.

Full description:
KoruBeni is an Android personal safety app that helps you view location status, run an on-device fake call simulation, and use additional safety tools with an optional Pro subscription.

KoruBeni offers free basic safety tools. Panic/SOS, Safe Walk, check-in, and advanced safety automations are available with KoruBeni Pro.

⚠️ IMPORTANT: KoruBeni is not an official emergency service and does not replace 112 (or your local emergency number). In a real emergency, please call your local emergency number first. KoruBeni is only a complementary tool and does not provide physical protection.

★ FREE FEATURES ★

◉ Location Session
Show your current location when available; show a clear unavailable state when it cannot be acquired.

◉ Fake Call
Create an on-device fake incoming call simulation for personal safety in uncomfortable situations. This feature does not place a real phone call and does not contact third parties.

◉ Siren
Draw attention with a loud alarm.

◉ Emergency Contacts
Save and manage trusted contacts locally on your device.

★ UNLOCKED WITH KORUBENI PRO ★

◉ Panic/SOS Button
With KoruBeni Pro, hold to start the panic flow. A 10-second countdown helps prevent accidental activation. This feature does not work on the free plan.

◉ Safe Walk
Start a helper check-in session during night or unsafe situations. Background behavior depends on Android settings.

◉ Check-in
Use timed check-in sessions that start a follow-up flow when the timer expires.

◉ Safety History
View local in-app safety events on your device.

◉ Volume Trigger and Test Mode
Use advanced safety automations and test the flow without placing a real call.

KoruBeni Pro is optional. Purchases, renewals, cancellations, and restore operations are managed through Google Play.

★ SECURITY ★

• 4-digit PIN app protection
• Secure on-device storage for PIN
• Local on-device database for emergency contact records
• Offline-first architecture without a developer backend

★ PRIVACY ★

• Location is processed only during emergency or location sessions
• We don’t sell your data to third parties
• The primary copy of app data stays on device; map and Play Billing providers may have their own technical network behavior

KoruBeni — Free location session and fake call; optional Pro safety tools.
```

---

## 4. Legal URLs

**Privacy policy**

```text
https://poyrazoncel34-netizen.github.io/guvenlik_app/privacy_policy.html
```

**Internal English privacy policy reference**

```text
https://poyrazoncel34-netizen.github.io/guvenlik_app/privacy_policy_en.html
```

Do not use the English URL as evidence of English runtime support for the first Play release.

**Terms**

```text
https://poyrazoncel34-netizen.github.io/guvenlik_app/kullanim_sartlari.html
```

**KVKK / Aydınlatma**

```text
https://poyrazoncel34-netizen.github.io/guvenlik_app/aydinlatma.html
```

**Data deletion**

```text
https://poyrazoncel34-netizen.github.io/guvenlik_app/data_deletion.html
```

Notes:

- `AppConstants.aydinlatmaMetniUrl` currently points to `aydinlatma.html`.
- The English privacy URL follows the existing public legal URL pattern; verify the live hosted page before submitting.

---

## 5. Data Safety Answers

**General answer**

```text
Does your app collect or share any of the required user data types?
Yes, because optional Pro subscription processing uses Google Play Billing / RevenueCat, and online map screens may contact the configured map tile provider. Do not mark local-only data as developer-collected/shared merely because it is stored on device.
```

**Data collected / processed**

```text
Location:
- Conservative disclosure needed for map/location sessions.
- Used only when the user opens map/location features or triggers safety flows.
- No developer backend receives location.
- Online map tile requests may reveal map viewport/network metadata to the configured tile provider.

Personal info:
- Optional profile name: local-only, for profile personalization.
- Optional photos/images: local-only, user-selected fake-call avatar if image picker is used.
- Email address: not collected.
- Phone number: not collected by developer. Emergency contact numbers are chosen from the device and stored locally unless the user invokes Android telephony.
- User IDs: not collected by developer; no auth backend.

Contacts:
- Accessed so the user can choose emergency contacts.
- Stored local-only.
- Do not claim developer collection/sharing if no off-device transfer is introduced.
- Purpose: app functionality — emergency contact selection.

Financial info / purchases:
- Purchase history / subscription status: processed by Google Play Billing and RevenueCat for optional Pro purchases.
- Entitlement status: processed by RevenueCat to verify and restore Pro access.
- Anonymous user/device/app info: processed by RevenueCat / Google Play Billing for subscription verification and fraud prevention.
- Payment card credentials: not collected or stored by the developer.

Map tile provider / OpenStreetMap:
- Online map display may request map tiles from the configured provider.
- Provider: OpenStreetMap tile infrastructure / configured map tile provider.
- Purpose: app functionality — online map display.
```

**Data shared**

```text
Not automatically shared by the app or sent to a developer backend. Emergency contacts are used for call flow only. Online map tiles, Google Play Billing, and RevenueCat have their own technical network behavior.
```

**Security practices**

```text
The app does not operate a developer backend. Most safety data is stored on device: emergency contacts, display name, optional user-selected fake-call avatar images, PIN, local activity history, fake call settings, and consent records.

Encryption in transit: do not mark blanket "Yes" for all data. The app has no developer backend; map, Google Play Billing, and RevenueCat traffic are handled by their providers.

Data sold: No.
Developer backend: No developer-operated backend in this release.
```

**Deletion answer**

```text
Users can request data deletion: Yes. Deleting the app or clearing app storage removes on-device data.

Local data deletion does not cancel an active Google Play subscription. Subscription purchase, renewal, cancellation, and restore operations are managed through Google Play.
```

**No ads**

```text
No ads. Ads data is not collected.
```

**No UGC**

```text
No user-generated content feature.
```

**No account**

```text
KoruBeni does not create developer-operated user accounts and has no auth backend in this release. Data deletion refers to deleting local on-device app data. Google Play subscription cancellation and purchase history are managed separately through Google Play.
```

**RevenueCat / Google Play Billing disclosure**

```text
Google Play handles payment processing. RevenueCat helps verify subscription and entitlement status. The developer does not store card or payment credentials and does not operate a billing backend.

Subscription status, anonymous user ID, purchase events, app/device information, and entitlement data may be handled by Google Play Billing and RevenueCat. Payment credentials are handled by Google Play and are not stored by the developer.
```

**OpenStreetMap disclosure**

```text
Map screens may contact the configured map tile service, currently OpenStreetMap tile infrastructure, for online map display. No developer backend receives map data.
```

**Photos/images disclosure**

```text
Optional display-name data and user-selected fake-call avatar images stay on the device. Images may be picked by the user for fake-call personalization; there is no cloud upload and no developer backend.
```

**Not used**

```text
Firebase auth, cloud database, analytics, crash reporting, ads, UGC, developer backend, microphone/audio recording.
```

---

## 6. Permission Declarations

### REQUEST_IGNORE_BATTERY_OPTIMIZATIONS

**Core functionality**

```text
KoruBeni requests battery optimization exemption only as an optional reliability improvement for active user-started safety sessions such as Safe Walk and check-in. Android and OEM battery settings may still affect behavior. The user can decline, and the app explains that timer/background reliability may be degraded.
```

**Reviewer explanation**

```text
This permission is an optional reliability enhancement for user-started safety timers such as Safe Walk/check-in. The app continues to function if the user denies the request, but warns that timer and background reliability may be reduced. The prompt is suppressible and does not auto-show forever.
```

### SCHEDULE_EXACT_ALARM

**Core functionality**

```text
KoruBeni uses exact alarms for user-visible safety deadlines and timers, including Panic/SOS countdown backup, check-in expiry, grace periods, and Safe Walk timers. Delay can affect the expected safety behavior of these user-started flows. The app is not using exact alarms for ads, analytics, marketing, hidden tracking, or arbitrary background work.
```

**Why required**

```text
Android Doze, app standby, and OEM battery restrictions can delay Dart timers or inexact alarm behavior. Safety timers need the best available timing path when user-visible deadlines expire. SCHEDULE_EXACT_ALARM is used for those user-started safety timer/reminder flows.
```

**Not used for**

```text
Advertising, marketing, analytics, hidden location tracking, user monitoring, indefinite arbitrary background work, or starting new safety sessions in the background without user initiation.
```

**Fallback / degraded behavior**

```text
If exact alarm access is denied or unavailable, Check-In, Safe Walk, and scheduled fake-call sessions are not armed. Panic may continue only as a visible foreground countdown ending in a manual `ACTION_DIAL` path, with no background guarantee. An independently keyed inexact alarm is created only after exact scheduling succeeds, as a residual backup if the permission is later revoked.
```

### FOREGROUND SERVICE — NOT APPLICABLE

Do not paste an FGS declaration for this build. It does not request an FGS
permission or start a custom foreground service. Remove any stale `specialUse`
Console draft and confirm the uploaded AAB manifest contains no transitive FGS
entry. Safety-session notifications are ordinary status UI; native alarms own
deadline reliability.

### CALL_PHONE, if prompted

**Declaration category**

```text
Safety / Emergency
```

**Core functionality**

```text
Used only for Panic/SOS, Check-In, and Safe Walk sessions that the user explicitly arms. When the relevant deadline expires, Android may submit an unconfirmed call request to the system Telecom service for the immutable pre-selected contact. The app never synthesizes 112/911 or another official short code and never claims ringing or connection. If automatic submission cannot be used, an actionable notification exposes a user-tapped ACTION_DIAL path.
```

**Reviewer explanation**

```text
CALL_PHONE is limited to user-armed Panic/SOS, Check-In, and Safe Walk expiry. A successful API return means only that a request was submitted to Android Telecom; connection remains unknown. When automatic submission is unavailable, the user can tap the fallback notification to open ACTION_DIAL. KoruBeni has no official 112/police integration and never generates official short codes.
```

### FLAG_SECURE reviewer note

```text
KoruBeni does not set Android FLAG_SECURE globally. Ordinary screenshots remain possible. An in-app privacy mask obscures the recent-apps preview while the app is backgrounded; it is not an OS screenshot block.
```

### POST_NOTIFICATIONS reviewer note

```text
Notifications are used for user-visible safety timer/session reliability and related reminders in user-started flows. They are not used for ads, marketing, analytics, hidden tracking, or indefinite background execution. The app has local notification preference/prompt state and the user can deny notification permission.
```

---

## 7. Content Rating Answers

```text
Content rating questionnaire: KoruBeni is a personal safety app.

Violence:
- Cartoon or fantasy violence: None
- Realistic violence: None
- Prolonged graphic or sadistic violence: None

Sexual content:
- Nudity or sexual content: None
- Sexual themes: None

Language:
- Profanity or crude humor: None
- Mature/suggestive themes: None

Controlled substances:
- Alcohol, tobacco, drugs: None

Fear / Horror:
- Horror themes: None
- Fear themes: None. This is a safety app, not horror content.

Dangerous activities:
- Simulated gambling: None
- Unrestricted web access: No. The app does not open an external browser.
- User-generated content: No.
- Shares location: No automatic sharing. Location is processed for emergency/location session when user triggers it.

Other:
- Social interaction: Yes — emergency contacts / call flow.
- Personal information shared: No automatic app-to-contact sharing. Emergency calls may expose the caller's phone number through the phone network; location is processed for the emergency/map session when user triggers it.

Expected result:
Usually PEGI 3 / Everyone or Everyone 10+ equivalent. Complete the questionnaire, obtain the certificate, and save it in Play Console.

Target audience:
Intended for adults / 18+. Do not enter Designed for Families unless the product decision changes and the app/legal/store copy is reworked.
```

---

## 8. Reviewer Notes

**No login required**

```text
No login or test account is required for basic app access. The app has no account system or developer authentication backend.
```

**Panic/SOS is Pro-only**

```text
Panic/SOS is a KoruBeni Pro feature.
```

**Free plan access**

```text
The free plan includes basic app access, immediate fake call, siren, emergency contact management, basic display name, map/location view where permission is granted, and legal/settings access.
```

**Test path for Pro via license tester**

```text
Use a Google Play license tester account or internal test track account.
Install the Play/internal testing build.
Open the paywall from the locked panic/SOS button or Settings -> KoruBeni Pro.
Complete a sandbox/test purchase for the configured monthly or annual plan.
The test purchase is sandboxed via license testing and produces no real charge.
Return to Home and verify the panic/SOS button shows active Pro copy before long press.
```

Operator note (NEEDS_OPERATOR_ACTION): the reviewer's Google account must be added
in advance under Play Console -> Setup -> License testing, otherwise the sandbox
purchase path above will produce a real charge prompt instead of a test purchase.

**Panic/SOS reviewer path**

```text
Home -> locked Pro panic/SOS button -> Paywall/test purchase -> Pro entitlement active -> Home -> panic/SOS button -> long press -> emergency countdown.
```

**Fake call is simulated, not real telephony**

```text
Fake Call creates an on-device fake incoming call simulation for personal safety in uncomfortable situations. This feature does not place a real phone call and does not contact third parties.
```

**Local data deletion does not cancel Play subscription**

```text
Deleting the app or clearing app storage removes on-device data. It does not cancel an active Google Play subscription. KoruBeni Pro purchase, renewal, cancellation, and restore operations are managed through Google Play.
```

---

## 9. Manual Checklist Still Not Complete

```text
[ ] Screenshots from store/screenshots/android/final/ manually reviewed for PII
[ ] Play icon 512x512 PNG uploaded/verified
[ ] Feature graphic 1024x500 prepared/verified
[ ] Data Safety submitted for closed/open/production, or Play Console internal-testing exemption evidence saved
[ ] Content Rating submitted
[ ] Target Audience submitted
[ ] FGS / exact alarm / battery optimization declarations submitted if required
[ ] RevenueCat products/offering configured
[ ] License tester monthly/annual purchase, restore, cancel/manage tested
[ ] Signed AAB produced and uploaded
[ ] Real-device QA matrix passed on API29/API36/16 KB, Pixel/Samsung/Xiaomi, dual-SIM and low-memory physical devices
[ ] Play Console production access screen checked; if the personal-account policy applies, 12 opted-in testers / 14 continuous days completed
```
