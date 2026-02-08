# 📱 Firebase Telefon Doğrulama Kurulumu

Telefon numarası ile giriş çalışmıyorsa veya uygulama kapanıyorsa, Firebase Console ayarlarını kontrol edin.

---

## ⚡ HIZLI ÇÖZÜM: SMS gelmezse devam et

**SMS gelmez veya uygulama kapanırsa** - Giriş ekranında **"SMS gelmezse buradan devam et"** butonuna basın.

Bu butonun çalışması için:
1. Firebase Console → Authentication → Sign-in method
2. **Anonymous** satırını **Enable** yapın
3. Kaydedin
4. Uygulamada "SMS gelmezse buradan devam et" butonuna basın
5. Uygulama içinde tüm özellikleri test edebilirsiniz

---

## ✅ ADIM 1: Android - SHA-1 ve SHA-256 Ekle (ZORUNLU)

SMS'in çalışması için Android'de mutlaka yapılmalı:

1. Terminal'de: `cd android && ./gradlew signingReport`
2. **SHA-1** ve **SHA-256** değerlerini kopyala
3. [Firebase Console](https://console.firebase.google.com) → Proje ayarları → Genel
4. "Uygulamalarınız" bölümünde Android uygulamasına tıkla
5. "Parmak izi ekle" → SHA-1 ve SHA-256 ekle
6. **google-services.json** dosyasını indirip `android/app/` içine kopyala (üzerine yaz)

---

## ✅ ADIM 2: Phone Authentication'ı Etkinleştir

1. [Firebase Console](https://console.firebase.google.com) aç
2. Projenizi seçin
3. Sol menüden **Authentication** → **Sign-in method**
4. **Phone** satırına tıkla
5. **Enable** (Etkinleştir) aç
6. **Kaydet**

---

## ✅ ADIM 3: Test Numarası Ekle (Geliştirme İçin - Opsiyonel)

SMS gitmeden test etmek için:

1. **Authentication** → **Sign-in method** → **Phone**
2. **Phone numbers for testing** bölümüne git
3. **+90 555 123 4567** gibi bir numara ekle
4. Doğrulama kodu: **123456** (sabit test kodu)
5. Bu numara ile giriş yapınca SMS gitmez, direkt 123456 kodu çalışır

---

## ✅ ADIM 4: iOS - API Anahtarı Kısıtlamaları (iOS Çökmesi Varsa)

reCAPTCHA çalışmıyorsa (beyaz ekran, uygulama kapanması):

1. [Google Cloud Console](https://console.cloud.google.com) → API & Services → Credentials
2. Firebase projenize ait **API Key**'i bul
3. **Application restrictions** → **None** yapın (geçici olarak)
4. Veya **iOS apps** kısıtlaması varsa, Bundle ID'nin doğru olduğundan emin ol: `com.poyrazoncel.korubeni`

---

## 📋 Telefon Numarası Formatı

Doğru format: **+90 5XX XXX XX XX**
- Mutlaka **+90** ile başlamalı (Türkiye)
- Boşluklar otomatik temizlenir

---

## 🔧 Hâlâ Çalışmıyorsa

1. **İnternet:** Wi-Fi veya mobil veri açık mı?
2. **Firebase Console:** Phone auth ve Anonymous auth etkin mi?
3. **Android:** SHA-1 ve SHA-256 Firebase'e eklendi mi?
4. **Numara:** +90 ile mi yazıyorsun?
5. **SMS gelmezse:** "SMS gelmezse buradan devam et" butonu ile giriş yapıp uygulamayı kullanabilirsiniz

Hata mesajı ekranda görünüyorsa, o mesajı not alıp kontrol et.
