# 🔄 YENİ BUILD YÜKLEME

## ✅ Durum:
- ✅ Developer profili güvenilmiş
- ✅ Eski uygulama yüklü (5 gün önce)
- ⚠️ Yeni build'i yüklemen gerekiyor

---

## 🚀 ADIM 1: Eski Uygulamayı Sil (Opsiyonel)

**Telefonda:**
- Uzun bas → "Guvenlik App" → Sil
- Veya Ayarlar → Genel → iPhone Depolama → Guvenlik App → Uygulamayı Sil

**Neden?** Yeni build'i yüklerken çakışma olmaması için.

---

## 🚀 ADIM 2: Xcode'da Yeni Build Yükle

1. **Xcode'u aç** (zaten açık olmalı)
2. **iPhone'u USB ile bağla**
3. Xcode'un üst kısmında **"Poyraz iPhone"** seçili olmalı
4. **Product → Clean Build Folder** (Shift+Cmd+K) - Eski build'i temizle
5. **Product → Run** (Cmd+R) - Yeni build'i yükle

**İlk kez yapıyorsan:**
- Xcode birkaç şey indirebilir (birkaç dakika)
- iPhone'da **Ayarlar → Genel → VPN ve Cihaz Yönetimi** → Geliştirici uygulamasına **"Güven"** de (zaten yapmışsın)

---

## ✅ SONRA:

1. USB'yi çıkar
2. Uygulamayı aç
3. **Çalışmalı!** ✅

---

## 🔍 EĞER HALA ÇALIŞMIYORSA:

### Hata: "Uygulama açılmıyor"
**Çözüm:**
- iPhone'u yeniden başlat
- Uygulamayı tekrar aç

### Hata: "Güvenilmeyen geliştirici"
**Çözüm:**
- Ayarlar → Genel → VPN ve Cihaz Yönetimi
- Developer profiline tekrar "Güven" de

### Hata: "Uygulama süresi doldu"
**Çözüm:**
- 7 gün geçmiş olabilir
- USB ile bağla → Xcode'da Product → Run
- Yeniden imzalanır, 7 gün daha çalışır

---

## 🎯 ŞİMDİ YAP:

1. Xcode'da Product → Clean Build Folder
2. Product → Run
3. USB'yi çıkar → Test et

Sonucu paylaş!
