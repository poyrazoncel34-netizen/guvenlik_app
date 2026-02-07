# 📱 iPhone'a USB ile Yükleme (Ücretsiz)

## ✅ İlk Yükleme (USB Gerekli - Sadece 1 Kez)

İlk yükleme için USB ile bağlaman gerekiyor. Sonra uygulama telefonda **bağımsız çalışır** - USB'ye bağlı kalmana gerek yok!

---

## 🚀 ADIM 1: iOS Build Al

Terminal'de:

```bash
cd /Users/poyrazoncel/Desktop/guvenlik_app
flutter build ios --release --dart-define=ENV=production --dart-define=ENCRYPTION_KEY=$ENCRYPTION_KEY
```

Bu komut iOS build'i hazırlar (5-10 dakika sürebilir).

---

## 🚀 ADIM 2: Xcode'da Aç

1. **Xcode'u aç** (App Store'dan ücretsiz indirebilirsin)
2. **File → Open** → `ios/Runner.xcworkspace` dosyasını seç
3. Xcode açılır

---

## 🚀 ADIM 3: Signing Ayarla (Önemli!)

1. Sol panelde **"Runner"** projesine tıkla
2. **"Signing & Capabilities"** sekmesine git
3. **"Automatically manage signing"** işaretle
4. **Team:** Apple ID'n ile giriş yap (ücretsiz)
5. **Bundle Identifier:** `com.poyrazoncel.korubeni` (zaten var)

**Not:** İlk kez yapıyorsan Apple ID ile giriş yapman istenebilir.

---

## 🚀 ADIM 4: iPhone'u Bağla ve Yükle

1. **iPhone'u USB ile Mac'e bağla**
2. iPhone'da **"Bu bilgisayara güven"** mesajına **"Güven"** de
3. Xcode'un üst kısmında **cihaz seçici**nde iPhone'unu seç
4. **Product → Run** (veya **Cmd+R**)
5. İlk kez yapıyorsan iPhone'da **Ayarlar → Genel → VPN ve Cihaz Yönetimi** → Geliştirici uygulamasına **"Güven"** de
6. Uygulama telefona yüklenir! 🎉

---

## ✅ SONRA NE OLUR?

- ✅ Uygulama telefonda **bağımsız çalışır**
- ✅ USB'ye bağlı kalmana **gerek yok**
- ✅ Normal bir uygulama gibi kullanabilirsin
- ⚠️ **7 günde bir** yeniden imzalaman gerekecek (Xcode'dan tekrar Run yap)

---

## 🔄 GÜNCELLEME İÇİN

Yeni bir sürüm çıkardığında:

1. Yeni build al
2. Xcode'da aç
3. iPhone'u USB ile bağla
4. Product → Run
5. Güncelleme yüklenir

---

## 📱 AİLE ÜYELERİNE GÖNDERMEK İÇİN

Her aile üyesinin telefonuna USB ile bağlayıp yüklemen gerekiyor. Alternatif olarak:

- **TestFlight** kullan (99$/yıl ama çok daha kolay)
- Veya herkesin telefonunu Mac'e bağla ve yükle

---

## 🎯 HAZIR MISIN?

1. iOS build'i al (yukarıdaki komut)
2. Xcode'u aç
3. iPhone'u bağla
4. Run!

Build'i çalıştır ve sonucu paylaş!
