# Play Console — Data Safety Form Yanıtları

Bu dosya, Play Console → Policy → App content → Data safety formunu doldururken kopyalanacak yanıtları içerir.

---

## Genel Sorular

**Does your app collect or share any of the required user data types?**  
→ Yes

---

## Veri Türleri ve Yanıtlar

### 1. Konum (Location)

| Soru | Yanıt |
|------|-------|
| Approximate location | ✅ Collected, shared with emergency contacts when emergency triggered |
| Precise location | ✅ Collected, shared with emergency contacts when emergency or location sharing is active |
| Amaç | App functionality — Emergency location sharing, Safe Walk |
| Zorunlu / Opsiyonel | Optional — User chooses when to share |

**Kısa açıklama (İngilizce):**  
Location is collected only when the user actively shares it or triggers an emergency. Shared with emergency contacts and Firebase for delivery.

---

### 2. Kişisel Bilgiler (Personal info)

| Veri | Toplanıyor? | Paylaşılıyor? | Amaç |
|------|-------------|---------------|------|
| Name | ✅ Optional (profile) | ❌ No | App functionality |
| Email address | ✅ Optional (profile) | ✅ With Firebase | Account, notifications |
| Phone number | ✅ Yes | ✅ With Firebase | Authentication, emergency calls |
| User IDs | ✅ Yes (Firebase Auth) | ✅ With Firebase | Account management |

**Kısa açıklama:**  
Phone number for authentication. Optional name/email for profile. Data processed by Firebase under DPA.

---

### 3. Kişiler (Contacts)

| Soru | Yanıt |
|------|-------|
| Contacts | ✅ Collected | Stored on device only (for emergency contact selection) |
| Amaç | App functionality — Emergency contact selection |
| Paylaşım | Not shared with third parties; used in-app only |

**Kısa açıklama:**  
Contacts are used only to let users select emergency contacts. Stored locally, not shared with servers except when SMS/call is triggered by user action.

---

### 4. Ses / Mikrofon (Audio)

| Soru | Yanıt |
|------|-------|
| Voice or sound recordings | ✅ Collected (optional) | ❌ Not shared |
| Amaç | App functionality — Evidence recording (user-initiated) |
| Opsiyonel | Yes — User chooses when to record |

**Kısa açıklama:**  
Microphone used only for optional voice recording feature when user enables it. Not shared.

---

### 5. Uygulama Etkileşimi (App activity)

| Veri | Toplanıyor? | Amaç |
|------|-------------|------|
| Crash logs | ✅ Yes | Firebase Crashlytics — App stability |
| Diagnostics | ✅ Yes | Firebase Crashlytics — Bug fixing |
| Analytics | ✅ Yes | Firebase Analytics — Anonymous usage stats |

**Kısa açıklama:**  
Crash reports and anonymous analytics via Firebase for stability and improvement.

---

## Veri Güvenliği

- **Encryption in transit:** Yes (HTTPS/TLS)
- **Users can request data deletion:** Yes
- **Data processing agreement (DPA):** Firebase/Google DPA applies

---

## Özet (Copy-Paste için)

**Collected data types:**
- Location (approximate, precise) — for emergency sharing
- Personal info (name, email, phone, user ID) — for account and notifications
- Contacts — for emergency contact selection (device-stored)
- Audio — optional voice recording
- App activity — crash logs, analytics

**Shared with:** Emergency contacts (when user triggers emergency), Firebase (infrastructure)

**Not sold:** We do not sell user data.
