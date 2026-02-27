# App Store Connect — App Privacy Details

App Store Connect → Uygulama → App Privacy bölümünde aşağıdaki etiketleri ekleyin.

---

## 1. Konum (Location)

| Etiket | Açıklama |
|--------|----------|
| **Coarse Location** | ✅ Collected |
| **Precise Location** | ✅ Collected |

**Usage:** App functionality — Emergency location sharing, Safe Walk  
**Linked to user:** Yes  
**Used for tracking:** No

---

## 2. Kişisel Bilgiler (Personal Information)

| Veri | Toplanıyor? | Kullanım |
|------|-------------|----------|
| **Name** | ✅ Optional | App functionality (profile) |
| **Email Address** | ✅ Optional | Account, notifications |
| **Phone Number** | ✅ Yes | Authentication, emergency calls |
| **User ID** | ✅ Yes | Account management (Firebase Auth) |

**Linked to user:** Yes  
**Used for tracking:** No

---

## 3. Kişiler (Contacts)

| Veri | Toplanıyor? | Kullanım |
|------|-------------|----------|
| **Contacts** | ✅ Yes | Emergency contact selection |

**Linked to user:** Yes  
**Used for tracking:** No  
**Note:** Stored on device; used only when user selects emergency contacts or triggers emergency.

---

## 4. Ses (Audio)

| Veri | Toplanıyor? | Kullanım |
|------|-------------|----------|
| **Voice Recordings** | ✅ Optional | Evidence recording (user-initiated) |

**Linked to user:** Yes  
**Used for tracking:** No

---

## 5. Tanılama (Diagnostics)

| Veri | Toplanıyor? | Kullanım |
|------|-------------|----------|
| **Crash Data** | ✅ Yes | Firebase Crashlytics |
| **Performance Data** | ✅ Yes | Firebase Analytics |

**Linked to user:** No (anonymous)  
**Used for tracking:** No

---

## Özet Tablo (App Store format)

| Data Type | Collected | Purpose |
|-----------|-----------|---------|
| Location | Yes | App functionality |
| Name | Optional | App functionality |
| Email | Optional | App functionality |
| Phone Number | Yes | App functionality |
| User ID | Yes | App functionality |
| Contacts | Yes | App functionality |
| Voice Recordings | Optional | App functionality |
| Crash Data | Yes | Analytics |
| Performance Data | Yes | Analytics |

**Data used to track you:** No  
**Data linked to you:** Yes (for most types above)  
**Data collected but not linked:** Crash/Performance data
