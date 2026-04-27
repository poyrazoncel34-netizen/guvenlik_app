# Play Console — Data Safety Form Answers

Canonical policy/declaration source: `docs/play_console_declarations.md`.
This file is the Play Console answer source and mirrors that policy wording for form entry.

---

## Genel Sorular

**Does your app collect or share any of the required user data types?**  
→ Yes

Not: KoruBeni geliştirici sunucularına veya geliştirici tarafından işletilen bir backend'e veri göndermez. Konum, acil kişi, profil, fake call, isteğe bağlı avatar/fotoğraf ve yerel olay verileri cihazda işlenir. Google Play Billing ve RevenueCat isteğe bağlı Pro abonelik/satın alma doğrulaması için kendi sağlayıcı altyapılarında veri işleyebilir. Çevrimiçi harita ekranları OpenStreetMap karo altyapısına teknik ağ istekleri yapabilir.

---

## Veri Türleri ve Yanıtlar

### 1. Konum (Location)

| Soru | Yanıt |
|------|-------|
| Approximate location | ✅ Processed when emergency or location session is triggered |
| Precise location | ✅ Processed when emergency or location session is triggered |
| Sharing | ❌ Not sent to developer backend and not automatically shared by the app |
| Purpose | App functionality — user-controlled safety features, map display, emergency context, check-in/safe-walk timers |
| Required / optional | Optional — permission and user action required for related features |

**Short explanation:**  
Location is user-controlled and safety-feature related. It is used when the user opens map/location features or triggers safety flows. The app does not automatically send location messages to emergency contacts or a developer backend.

---

### 2. Kişisel Bilgiler (Personal info)

| Veri | Yanıt | Not |
|------|-------|-----|
| Name | ✅ Optional, device-only | Profile personalization |
| Photos/images | ✅ Optional, device-only | User-selected profile/fake-call avatar if `image_picker` is used |
| Email address | ❌ Not collected | No account system |
| Phone number | ❌ Not collected by developer | Emergency contact numbers are chosen from the device and stored locally |
| User IDs | ❌ Not collected | No auth backend |

**Short explanation:**  
Optional profile data and user-selected images stay on the device. Images may be picked by the user for profile/fake-call avatar personalization; there is no cloud upload and no developer backend.

---

### 3. Kişiler (Contacts)

| Soru | Yanıt |
|------|-------|
| Contacts | ✅ Accessed so the user can choose emergency contacts |
| Storage | Device-only |
| Sharing | ❌ Not shared with developer or cloud services |
| Amaç | App functionality — Emergency contact selection |

**Short explanation:**  
Contacts are accessed only so the user can pick trusted emergency contacts. Selected contact data is stored locally on the device unless the user starts a call flow through Android.

### 4. Financial info / Purchases

| Data | Answer |
|------|--------|
| Purchase history / subscription status | ✅ Processed by Google Play Billing and RevenueCat for optional Pro purchases |
| Entitlement status | ✅ Processed by RevenueCat to verify and restore Pro access |
| Anonymous user/device/app info | ✅ Processed by RevenueCat / Google Play Billing for subscription verification and fraud prevention |
| Payment card credentials | ❌ Not collected or stored by the developer |
| Purpose | App functionality — optional Pro purchase, subscription verification, entitlement restore |

**Short explanation:**  
Google Play handles payment processing. RevenueCat helps verify subscription and entitlement status. The developer does not store card or payment credentials and does not operate a billing backend.

---

### 5. Ses / Mikrofon (Audio)

| Soru | Yanıt |
|------|-------|
| Voice or sound recordings | ❌ Not collected |
| Microphone permission | ❌ Not requested |
| Paylaşım | ❌ Not shared |
| Amaç | Not used in this Android Play release |

**Short explanation:**  
This Android Play release does not record audio and does not request microphone permission.

---

### 6. App activity

| Veri | Yanıt |
|------|-------|
| Crash logs | ❌ Not collected |
| Diagnostics | ❌ Not collected |
| Analytics | ❌ Not collected |
| User-generated content | ❌ Not supported |
| Ads data | ❌ Not collected |

**Short explanation:**  
The app does not use Firebase Analytics, Crashlytics, ads, UGC features, or another telemetry backend.

### 7. Map tile provider / OpenStreetMap

| Data | Answer |
|------|--------|
| Map tile requests | ✅ Technical network requests when online map screens are opened |
| Provider | OpenStreetMap tile infrastructure / configured map tile provider |
| Developer backend | ❌ No developer backend receives map data |
| Purpose | App functionality — online map display |

**Short explanation:**  
Online map display may request map tiles from the configured provider. These requests are governed by the provider's own technical network behavior and policies.

---

## Veri Güvenliği

- **Encryption in transit:** Do not mark blanket `Yes` for all data. The app has no developer backend; map, Google Play Billing, and RevenueCat traffic are handled by their providers.
- **Users can request data deletion:** Yes — deleting the app or clearing app storage removes on-device data.
- **Data sold:** No
- **Ads:** No ads.
- **UGC:** No user-generated content feature.
- **Developer backend:** No developer-operated backend in this release.

---

## Özet (Copy-Paste için)

**Data used by the app:**
- Location, only during emergency/location session flows
- Contacts, only for choosing emergency contacts
- Optional profile name, device-only
- Optional photos/images selected by the user for profile/fake-call avatar, device-only
- Fake call settings and local event data, device-only
- Purchase/subscription events, entitlement status, anonymous user/device/app info through Google Play Billing and RevenueCat for optional Pro access

**Shared with:** Not automatically shared by the app or sent to a developer backend. Emergency contacts are used for call flow only. Online map tiles, Google Play Billing, and RevenueCat have provider-side technical network behavior.

**Not used:** Firebase auth, cloud database, analytics, crash reporting, ads, UGC, developer backend, microphone/audio recording
