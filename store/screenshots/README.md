# Store Screenshots

Bu klasöre platform bazında ekran görüntülerini ekleyin.

## Klasör Yapısı

```
store/screenshots/
├── android/          ← Android screenshot'ları
├── ios/              ← iOS screenshot'ları
└── README.md         ← Bu dosya
```

---

## Play Store (Android)

**Dizin:** `store/screenshots/android/`

- **Minimum 2, maksimum 8** screenshot gerekli
- Önerilen boyutlar: **1080×1920** veya **1080×2340**
- Format: PNG veya JPEG
- Dosya adı örneği: `01_home.png`, `02_contacts.png`, `03_map.png`

---

## App Store (iOS)

**Dizin:** `store/screenshots/ios/`

| Cihaz | Boyut |
|-------|-------|
| iPhone 6.7" (iPhone 15 Pro Max) | 1290×2796 |
| iPhone 6.5" (iPhone 14 Plus) | 1284×2778 |
| iPhone 5.5" (iPhone 8 Plus) | 1242×2208 |

- Aynı ekranlar farklı boyutlarda çekilebilir
- Format: PNG
- Dosya adı örneği: `01_home_6.7.png`, `02_contacts_6.7.png`

---

## Yakalanacak Ekranlar

| # | Ekran | Açıklama |
|---|-------|----------|
| 1 | Ana sayfa | Panik butonu görünür olmalı |
| 2 | Acil kişiler | Kişi listesi dolu halde |
| 3 | Harita / Konum paylaşımı | Canlı konum paylaşım ekranı |
| 4 | Güvenli yürüyüş | Zamanlayıcı aktif |
| 5 | Sahte arama | Gelen sahte arama ekranı |
| 6 | Ayarlar | Genel ayarlar sayfası |

---

## Nasıl Alınır

### Android
```bash
# Emülatörde uygulama çalışırken
adb shell screencap -p /sdcard/screenshot.png
adb pull /sdcard/screenshot.png store/screenshots/android/01_home.png
```
Veya emülatörde doğrudan ekran görüntüsü tuşunu kullanın.

### iOS
- **Simulator:** `Cmd+S` ile kaydet
- **Gerçek cihaz:** Yan tuş + Güç tuşu

### Otomatik (opsiyonel)
- Android: Fastlane `screengrab`
- iOS: Fastlane `snapshot`
