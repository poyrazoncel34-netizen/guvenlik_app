# 🛡️ KoruBeni — Kişisel Güvenlik Uygulaması

<p align="center">
  <strong>Android'de acil arama akışını başlat. Konumunu gör. Güvenlik oturumlarını dürüstçe takip et.</strong>
</p>

---

## 📱 Özellikler

| Özellik | Açıklama |
|---|---|
| 🚨 **Panik Butonu** | Basılı tut → bırak → geri sayım → PIN girilmezse acil arama akışı |
| 📍 **Konum Oturumu** | Konum alınırsa haritada gösterilir; alınamazsa açık hata durumu gösterilir |
| 🚶 **Güvenli Yürüyüş** | Uygulama canlıyken yardımcı check-in; Android arka plan kısıtlarında garanti değildir |
| 📞 **Sahte Çağrı** | Özelleştirilebilir isim/fotoğraf ile sahte arama |
| 🔊 **Siren** | Dikkat çekmek için yüksek sesli siren |
| 📳 **Shake Algılama** | Bu Android Play sürümünde varsayılan olarak devre dışıdır |
| 🔐 **PIN Koruması** | 4 haneli PIN güvenliği |
| 🌍 **Çok Dilli** | Türkçe + İngilizce |
| 📡 **Offline-First** | Geliştirici sunucusu yoktur; harita/billing gibi üçüncü taraf servisler ağ kullanabilir |

## 🏗️ Teknoloji

- **Flutter** 3.29+ (Dart)
- **State Management** — Provider + GetIt
- **Yerel Depolama** — SQLite + Flutter Secure Storage
- **Güvenlik** — AES şifreleme, Flutter Secure Storage

## 🚀 Kurulum

### Gereksinimler
- Flutter 3.29+ (Dart ≥ 3.10)
- Android SDK 21+
- `flutter_jailbreak_detection` için Android: `minSdkVersion 21`

### Adımlar

```bash
# 1. Depoyu klonla
git clone https://github.com/poyrazoncel34-netizen/guvenlik_app.git
cd guvenlik_app

# 2. Bağımlılıkları yükle
flutter pub get

# 3. Uygulamayı çalıştır (debug)
flutter run

# 4. Testleri çalıştır
flutter test
```

**Opsiyonel — Sentry crash reporting** (yalnızca production):
```bash
flutter run --dart-define=SENTRY_DSN=https://your-dsn@sentry.io/123 \
            --dart-define=ENV=production
```
> DSN tanımlanmazsa Sentry no-op olarak çalışır; hiçbir veri gönderilmez.

---

## 📸 Ekran Görüntüleri

> Gerçek cihaz ekran görüntüleri `assets/screenshots/` klasörüne eklenecektir.

| Ana Ekran | Acil Durum | Sahte Arama |
|---|---|---|
| *(yakında)* | *(yakında)* | *(yakında)* |

---

## 🤝 Katkıda Bulunma

Katkılar memnuniyetle karşılanır! Lütfen aşağıdaki adımları izleyin:

1. **Fork** edin ve bir **feature branch** oluşturun:
   ```bash
   git checkout -b feat/özellik-adı
   ```
2. Değişikliklerinizi yapın ve testleri geçtiğinden emin olun:
   ```bash
   flutter test
   flutter analyze
   ```
3. Commit mesajınızı **Conventional Commits** formatında yazın:
   ```
   feat(scope): açıklama
   fix(scope): açıklama
   ```
4. **Pull Request** açın — `main` branch'e karşı.

### Kural ve Kısıtlamalar
- Geliştirici sunucusu veya cloud DB eklemeyin; harita, Play Billing ve crash reporting gibi üçüncü taraf entegrasyonlarının gerçek ağ davranışını metinlerde açık yazın.
- Biyometrik kimlik doğrulama **yasaktır** (baskı saldırısı riski).
- Tüm yeni özellikler için test yazılması zorunludur.

---

## 📄 Gizlilik Politikası

🇹🇷 [Türkçe](https://poyrazoncel34-netizen.github.io/guvenlik_app/)
🇬🇧 [English](https://poyrazoncel34-netizen.github.io/guvenlik_app/#english)

## 📋 Lisans

Bu proje özel lisanslıdır. Tüm hakları saklıdır.
