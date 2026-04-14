# Google Play Data Safety Section — Form Yanıtları

## Veri Toplama
- Uygulama kullanıcıdan veri topluyor mu? **EVET** (cihazda kalır, sunucuya gönderilmez)

---

## Toplanan Veri Türleri

### Konum
- Yaklaşık konum: **EVET**
- Kesin konum: **EVET**
- Toplama amacı: Uygulama işlevselliği (acil durum konum durumu / konum oturumu)
- Zorunlu mu: **EVET**
- Paylaşılıyor mu: **HAYIR** (uygulama konumu otomatik mesajla paylaşmaz)
- İşleme: Cihazda geçici (acil durum sırasında)

### Kişisel Bilgiler
- Ad: **EVET**
  - Toplama amacı: Uygulama işlevselliği (profil / acil arama akışı)
  - Zorunlu mu: **HAYIR**
  - Paylaşılıyor mu: **HAYIR**
  - İşleme: Cihazda (SQLite)

- Telefon numarası: **EVET** (acil durum kişileri)
  - Toplama amacı: Uygulama işlevselliği (acil durum arama akışı)
  - Zorunlu mu: **EVET**
  - Paylaşılıyor mu: **HAYIR**
  - İşleme: Cihazda (SQLite)

### Fotoğraf ve Video
- Fotoğraf: **EVET** (profil fotoğrafı — opsiyonel)
  - Toplama amacı: Uygulama işlevselliği (profil)
  - Zorunlu mu: **HAYIR**
  - Paylaşılıyor mu: **HAYIR**
  - İşleme: Cihazda

---

## Güvenlik Uygulamaları

| Konu | Durum |
|------|-------|
| Veri aktarım sırasında şifreleniyor mu? | Geliştirici backend'i yok. Harita ve Google Play Billing trafiği kendi sağlayıcı altyapısına tabidir. |
| Veri silinebilir mi? | **EVET** — uygulama içinden tam silme mevcut |
| Veri sunucuya gönderilmiyor | **DOĞRU** — geliştirici backend'i yok; harita ve Google Play Billing sağlayıcıları ayrıca değerlendirilir |
| Veri üçüncü tarafla paylaşılmıyor | **DOĞRU** — analytics, crashlytics, reklam servisi yok |

---

## Üçüncü Taraf Kütüphaneler

| Kütüphane | Amaç | Veri Topluyor mu? |
|-----------|-------|-------------------|
| OpenStreetMap (flutter_map) | Harita görüntüleme (tile download) | Hayır (kullanıcı verisi iletilmez) |
| Google Play Billing / RevenueCat | İsteğe bağlı Pro abonelik doğrulama | Satın alma/abonelik durumu sağlayıcı altyapısında işlenir |

Firebase / Google Analytics / Crashlytics: **KULLANILMIYOR**

---

## Play Console Veri Güvenliği Formu — Özet Cevaplar

- **Kullanıcı verileri paylaşılıyor mu?** HAYIR
- **Kullanıcı verileri toplanıyor mu?** EVET (cihazda)
- **Veriler şifreli aktarılıyor mu?** UYGULANAMAZ / sağlayıcıya göre (geliştirici backend'i yok; harita ve Google Play Billing kendi altyapısını kullanır)
- **Kullanıcı veri silme talebinde bulunabilir mi?** EVET
- **Uygulama güvenlik ihlallerini nasıl ele alıyor?** Geliştirici sunucusu yoktur. PIN ve ilk müdahale bilgileri secure storage kullanır; acil kişiler ve yerel olay verileri cihaz içi SQLite veritabanında tutulur.
