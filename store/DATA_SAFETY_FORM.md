# Play Console — Data Safety Form Yanıtları

Bu dosya, mevcut offline-first mimariye göre hazırlanmış daha güvenli cevapları içerir.

---

## Genel Sorular

**Does your app collect or share any of the required user data types?**  
→ Yes

Not: KoruBeni geliştirici sunucularına veri göndermez. Konum, kişi ve profil verileri cihazda işlenir. Harita karoları, Play Billing ve üretimde açıkça yapılandırılmış crash reporting gibi üçüncü taraf bileşenler ayrı değerlendirilmelidir.

---

## Veri Türleri ve Yanıtlar

### 1. Konum (Location)

| Soru | Yanıt |
|------|-------|
| Approximate location | ✅ Processed when emergency or location session is triggered |
| Precise location | ✅ Processed when emergency or location session is triggered |
| Paylaşım | ❌ Not automatically shared by the app |
| Amaç | App functionality — Emergency assistance, location session |
| Zorunlu / Opsiyonel | Optional — User action required |

**Short explanation:**  
Location is used only when the user triggers an emergency flow or starts a location session. The app does not automatically send location messages to emergency contacts.

---

### 2. Kişisel Bilgiler (Personal info)

| Veri | Yanıt | Not |
|------|-------|-----|
| Name | ✅ Optional, device-only | Profile personalization |
| Photo | ✅ Optional, device-only | Profile personalization |
| Email address | ❌ Not collected | No account system |
| Phone number | ❌ Not collected by developer | Emergency contact numbers are chosen from the device and stored locally |
| User IDs | ❌ Not collected | No auth backend |

**Short explanation:**  
Optional profile data stays on the device. The app has no sign-in flow and no backend user account.

---

### 3. Kişiler (Contacts)

| Soru | Yanıt |
|------|-------|
| Contacts | ✅ Accessed so the user can choose emergency contacts |
| Storage | Device-only |
| Paylaşım | ❌ Not shared with developer or cloud services |
| Amaç | App functionality — Emergency contact selection |

**Short explanation:**  
Contacts are accessed only so the user can pick trusted contacts. Selected contact data is stored locally on the device.

---

### 4. Ses / Mikrofon (Audio)

| Soru | Yanıt |
|------|-------|
| Voice or sound recordings | ✅ Optional |
| Storage | Device-only |
| Paylaşım | ❌ Not shared |
| Amaç | App functionality — Evidence recording |

**Short explanation:**  
Voice recording is optional and stays on the device unless the user manually exports it outside the app.

---

### 5. Uygulama Etkileşimi (App activity)

| Veri | Yanıt |
|------|-------|
| Crash logs | ❌ Not collected |
| Diagnostics | ❌ Not collected |
| Analytics | ❌ Not collected |

**Short explanation:**  
The app does not use Firebase Analytics, Crashlytics, or another telemetry backend.

---

## Veri Güvenliği

- **Encryption in transit:** Do not mark blanket `Yes` for all data. The app has no developer backend, but map, billing, and configured crash reporting traffic are handled by their providers.
- **Users can request data deletion:** Yes — deleting the app or clearing app storage removes on-device data.
- **Data sold:** No

---

## Özet (Copy-Paste için)

**Data used by the app:**
- Location, only during emergency/location session flows
- Contacts, only for choosing emergency contacts
- Optional profile name/photo, device-only
- Optional audio recordings, device-only

**Shared with:** Not automatically shared by the app. Emergency contacts are used for call flow only.

**Not used:** Firebase auth, cloud database, analytics, crash reporting
