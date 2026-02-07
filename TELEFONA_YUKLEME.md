# 📱 KORUBENI - TELEFONA YÜKLEME REHBERİ

## ✅ APK Build Alındı!

APK dosyası şu konumda:
```
build/app/outputs/flutter-apk/app-release.apk
```

---

## 📲 TELEFONA YÜKLEME YÖNTEMLERİ

### YÖNTEM 1: WhatsApp/Telegram ile Gönder (En Kolay)

1. **APK dosyasını bul:**
   - Finder'da: `/Users/poyrazoncel/Desktop/guvenlik_app/build/app/outputs/flutter-apk/app-release.apk`
   - Dosyayı bul ve sağ tık → "Paylaş" → WhatsApp/Telegram

2. **Telefona gönder:**
   - Kendi WhatsApp'ına gönder veya aile üyelerine gönder

3. **Telefonda yükle:**
   - WhatsApp'tan dosyayı aç
   - "Yükle" butonuna tıkla
   - "Bilinmeyen kaynaklardan yükleme" izni ver (Android ayarlarından)

---

### YÖNTEM 2: Email ile Gönder

1. **APK'yı email'e ekle:**
   - Finder'da APK dosyasını bul
   - Sağ tık → "Paylaş" → Mail
   - Kendi email'ine gönder

2. **Telefonda aç:**
   - Email'i aç
   - APK ekini indir
   - Yükle

---

### YÖNTEM 3: Google Drive / Dropbox ile Paylaş

1. **Cloud'a yükle:**
   - Google Drive'a APK'yı yükle
   - Paylaşım linki oluştur

2. **Link'i paylaş:**
   - WhatsApp/Email ile link'i gönder
   - Telefonda link'i aç → İndir → Yükle

---

### YÖNTEM 4: QR Kod ile İndir (En Profesyonel)

1. **QR kod oluştur:**
   - APK'yı bir web sunucusuna yükle (GitHub Pages, Netlify, vb.)
   - QR kod oluştur: https://qr-code-generator.com/
   - QR kodu ekrana göster

2. **Telefonda tara:**
   - QR kod okuyucu ile tara
   - Link'i aç → İndir → Yükle

---

## ⚙️ ANDROID AYARLARI (İlk Yükleme İçin)

Telefonda şu ayarı açman gerekiyor:

**Android 8.0+:**
1. Ayarlar → Uygulamalar → Özel uygul erişimi
2. "Bilinmeyen kaynaklardan yükleme" veya "Yükleme kaynakları" → Aç

**Eski Android:**
1. Ayarlar → Güvenlik
2. "Bilinmeyen kaynaklar" → Aç

---

## 📋 YÜKLEME ADIMLARI (Telefonda)

1. APK dosyasını aç (WhatsApp/Email/Drive'dan)
2. "Yükle" butonuna tıkla
3. İzinleri onayla (Konum, Rehber, SMS)
4. Uygulama yüklendi! 🎉

---

## 🔄 GÜNCELLEME

Yeni bir sürüm çıkardığında:

1. **Yeni APK build al:**
   ```bash
   cd /Users/poyrazoncel/Desktop/guvenlik_app
   flutter build apk --release --dart-define=ENV=production --dart-define=ENCRYPTION_KEY=$ENCRYPTION_KEY
   ```

2. **Eski APK'yı sil ve yenisini yükle:**
   - Telefonda eski uygulamayı sil
   - Yeni APK'yı yükle

---

## ✅ HAZIR!

APK dosyası hazır. Şimdi telefona yükleyebilirsin!
