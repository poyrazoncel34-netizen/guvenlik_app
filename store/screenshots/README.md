# Store Screenshots

Bu klasore Google Play icin Android ekran goruntulerini ekleyin.

## Klasör Yapısı

```
store/screenshots/
├── android/          ← Android screenshot'lari
└── README.md         ← Bu dosya
```

---

## Play Store (Android)

**Dizin:** `store/screenshots/android/`

- **Minimum 2, maksimum 8** screenshot gerekli
- Onerilen boyutlar: **1080×1920** veya **1080×2340**
- Format: PNG veya JPEG
- Dosya adi ornegi: `01_home.png`, `02_contacts.png`, `03_map.png`

---

## Yakalanacak Ekranlar

| # | Ekran | Açıklama |
|---|-------|----------|
| 1 | Ana sayfa | Panik butonu görünür olmalı |
| 2 | Acil kişiler | Kişi listesi dolu halde |
| 3 | Harita / Konum oturumu | Konum durumu ekranı |
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
Veya emulatorde dogrudan ekran goruntusu tusunu kullanin.

### Otomatik (opsiyonel)
- Android: Fastlane `screengrab`
