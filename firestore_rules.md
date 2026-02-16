# Firestore Security Rules — KoruBeni

Bu kuralları Firebase Console > Firestore Database > Rules sekmesine yapıştırın.

```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {

    // ========================================
    // USERS koleksiyonu
    // ========================================
    match /users/{userId} {
      // Kullanıcı sadece kendi profilini okuyabilir ve yazabilir
      allow read, write: if request.auth != null && request.auth.uid == userId;

      // Aktivite alt koleksiyonu
      match /activities/{activityId} {
        allow read, write: if request.auth != null && request.auth.uid == userId;
      }
    }

    // ========================================
    // EMERGENCIES koleksiyonu
    // ========================================
    match /emergencies/{emergencyId} {
      // Sadece giriş yapmış kullanıcılar oluşturabilir
      allow create: if request.auth != null
                    && request.resource.data.userId == request.auth.uid;

      // Kullanıcı sadece kendi acil durumlarını okuyabilir
      allow read: if request.auth != null
                  && resource.data.userId == request.auth.uid;

      // Güncelleme ve silme yok (kanıt korunması)
      allow update, delete: if false;
    }

    // ========================================
    // LOCATIONS koleksiyonu
    // ========================================
    match /locations/{userId} {
      // Kullanıcı sadece kendi konum verisini okuyabilir/yazabilir
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }

    // ========================================
    // Diğer tüm koleksiyonlar — varsayılan olarak kapalı
    // ========================================
    match /{document=**} {
      allow read, write: if false;
    }
  }
}
```

## Kuralların Açıklaması

| Koleksiyon | Okuma | Yazma | Silme |
|---|---|---|---|
| `users/{uid}` | ✅ Sadece kendi | ✅ Sadece kendi | ✅ Sadece kendi |
| `users/{uid}/activities` | ✅ Sadece kendi | ✅ Sadece kendi | ✅ Sadece kendi |
| `emergencies` | ✅ Sadece kendi | ✅ Oluşturma (kendi uid ile) | ❌ Silinemez |
| `locations/{uid}` | ✅ Sadece kendi | ✅ Sadece kendi | ✅ Sadece kendi |
| Diğer her şey | ❌ | ❌ | ❌ |

## Nasıl Uygulanır

1. [Firebase Console](https://console.firebase.google.com/) → projenizi seçin
2. Sol menüden **Firestore Database** → **Rules** sekmesi
3. Yukarıdaki kuralları yapıştırın
4. **Publish** butonuna basın
