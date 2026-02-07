# 📱 Xcode'da iPhone'a Yükleme - Adım Adım

## ✅ ŞU AN: General Sekmesindesin

Gördüğüm kadarıyla:
- ✅ Bundle Identifier: `com.poyrazoncel.korubeni` (Doğru!)
- ⚠️ Display Name: "Display Name" (Bunu "KoruBeni" yap)
- ⚠️ Version: Placeholder (Bunu "1.0.0" yap)

---

## 🚀 ADIM 1: Display Name ve Version Düzelt

**General sekmesinde:**

1. **Display Name:** "Display Name" → **"KoruBeni"** yaz
2. **Version:** Placeholder → **"1.0.0"** yaz
3. **Build:** 1 (Bu iyi, değiştirme)

---

## 🚀 ADIM 2: Signing & Capabilities Sekmesine Geç

1. Üstteki tab'lardan **"Signing & Capabilities"** sekmesine tıkla
2. Şunları yap:

### Signing Ayarları:

1. ✅ **"Automatically manage signing"** işaretle
2. **Team:** Dropdown'dan Apple ID'n ile giriş yap
   - İlk kez yapıyorsan: **"Add Account..."** → Apple ID'n ile giriş yap
   - Apple ID yoksa: Ücretsiz oluşturabilirsin (appleid.apple.com)
3. **Bundle Identifier:** `com.poyrazoncel.korubeni` (zaten doğru)

**Önemli:** Eğer "No accounts available" görürsen:
- **"Add Account..."** butonuna tıkla
- Apple ID'n ile giriş yap
- Xcode otomatik olarak signing'i ayarlar

---

## 🚀 ADIM 3: iPhone'u Bağla

1. **iPhone'u USB kablosu ile Mac'e bağla**
2. iPhone'da **"Bu bilgisayara güven"** mesajına **"Güven"** de
3. Xcode'un üst kısmında (toolbar'da) **cihaz seçici**nde iPhone'unu seç
   - Şu anda muhtemelen "Any iOS Device" yazıyor
   - iPhone'unu bağladığında orada görünecek

---

## 🚀 ADIM 4: Yükle!

1. **Product → Run** (veya **Cmd+R** tuşlarına bas)
2. İlk kez yapıyorsan:
   - Xcode birkaç şey indirebilir (birkaç dakika sürebilir)
   - iPhone'da **Ayarlar → Genel → VPN ve Cihaz Yönetimi** → Geliştirici uygulamasına **"Güven"** de
3. Uygulama telefona yüklenir! 🎉

---

## ✅ SONRA NE OLUR?

- ✅ Uygulama telefonda **bağımsız çalışır**
- ✅ USB'ye bağlı kalmana **gerek yok**
- ✅ Normal bir uygulama gibi kullanabilirsin
- ⚠️ **7 günde bir** yeniden imzalaman gerekecek (Xcode'dan tekrar Run yap)

---

## 🔄 GÜNCELLEME İÇİN

Yeni bir sürüm çıkardığında:
1. Build numarasını artır (General → Build: 2, 3, 4...)
2. Product → Run
3. Güncelleme yüklenir

---

## 📱 AİLE ÜYELERİNE GÖNDERMEK İÇİN

Her aile üyesinin telefonuna USB ile bağlayıp yüklemen gerekiyor. Alternatif:
- **TestFlight** kullan (99$/yıl ama çok daha kolay - bilgisayara bağlamadan yüklenir)

---

## 🎯 ŞİMDİ YAP:

1. Display Name'i "KoruBeni" yap
2. Version'ı "1.0.0" yap
3. **Signing & Capabilities** sekmesine geç
4. "Automatically manage signing" işaretle
5. Apple ID'n ile giriş yap
6. iPhone'u bağla
7. Product → Run

Hangi adımda takıldın? Sorun olursa yaz!
