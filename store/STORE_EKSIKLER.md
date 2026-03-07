# KoruBeni — Store Çıkışı Öncesi Eksikler

Bu dosya, [release_checklist.md](release_checklist.md) ve [PLAY_CONSOLE_CHECKLIST.md](PLAY_CONSOLE_CHECKLIST.md) içindeki tamamlanmamış maddelerin özeti ve adım adım talimatlarıdır.

---

## Yapılacaklar Özeti

| # | Madde | Platform | Tahmini süre |
|---|-------|----------|--------------|
| 1 | Privacy Policy URL canlı | Her ikisi | ~30 dk |
| 2 | Support email belirle | Her ikisi | ~5 dk |
| 3 | Store listings (kısa/uzun açıklama) | Her ikisi | ~1 saat |
| 4 | Screenshots | Her ikisi | ~2 saat |
| 5 | App icon 1024x1024 onay | Her ikisi | ~15 dk |
| 6 | Data Safety form | Android | ~30 dk |
| 7 | Content rating anketi | Android | ~15 dk |
| 8 | Internal Testing track'e AAB yükle | Android | ~20 dk |
| 9 | App Store Privacy Details | iOS | ~30 dk |
| 10 | TestFlight'a yükle | iOS | ~20 dk |
| 11 | QA (gerçek cihaz, akışlar) | Her ikisi | ~2–3 saat |

---

## 1. Privacy Policy URL

**Gerekli:** Gizlilik politikasının yayında olduğu bir URL.

**Adımlar:**
1. `store/privacy_policy.html` ve `store/privacy_policy_en.html` dosyalarını GitHub Pages veya kendi sitenize yükleyin.
2. Örnek GitHub Pages URL: `https://poyrazoncel34-netizen.github.io/guvenlik_app/privacy_policy.html`
3. Bu URL'yi Play Console ve App Store Connect’te ilgili alana girin.

---

## 2. Support Email

**Gerekli:** Destek için e-posta adresi.

**Adımlar:**
1. ✅ `privacy_policy_template.md` içinde destek e-postası dolduruldu: `korubeni.destek@gmail.com`
2. ✅ `store/privacy_policy.html` ve `privacy_policy_en.html` içinde aynı e-posta kullanılıyor.
3. Play Console ve App Store Connect'te Support email alanına `korubeni.destek@gmail.com` yazın.

---

## 3. Store Listings

**Gerekli:** Kısa açıklama (80 karakter), uzun açıklama, anahtar kelimeler (iOS).

**Mevcut dosyalar:**
- `store/play_store_listing_tr.md`, `store/play_store_listing_en.md`
- `store/app_store_listing_tr.md`, `store/app_store_listing_en.md`

**Adımlar:**
1. Bu dosyalardaki metinleri son hâline getirin.
2. Play Console → Store listing → Short description / Full description
3. App Store Connect → App Information → Description / Keywords

---

## 4. Screenshots

**Gerekli:** Cihaz boyutlarına uygun ekran görüntüleri.

**Boyutlar (örnek):**
- Android: 1080×1920 veya 1080×2340 (telefon)
- iOS: 6.7", 6.5", 5.5" (iPhone)

**Adımlar:**
1. Emülatör veya gerçek cihazda uygulamayı açın.
2. Ana sayfa, Kişiler, Harita, Ayarlar vb. ekranları görüntüleyin.
3. Cihazın ekran görüntüsü özelliğini kullanın veya Fastlane screengrab / snapshot ile otomatik alın.

---

## 5. App Icon 1024x1024

**Gerekli:** Store için 1024×1024 PNG (şeffaf olmayan, köşeleri yuvarlatılmamış).

**Adımlar:**
1. `assets/icon/app_icon.png` dosyasının 1024×1024 olduğundan emin olun.
2. `dart run flutter_launcher_icons` çalıştırın.
3. App Store Connect’te 1024×1024 ikonu yükleyin (gerekirse manuel).

---

## 6. Data Safety (Play Console)

**Gerekli:** Toplanan / paylaşılan veri türlerini beyan etme.

**Adımlar:**
1. Play Console → Policy → App content → Data safety
2. “Start” / “Manage”
3. **Copy-paste hazır yanıtlar:** [DATA_SAFETY_FORM.md](DATA_SAFETY_FORM.md)
4. Detay için [PLAY_CONSOLE_CHECKLIST.md](PLAY_CONSOLE_CHECKLIST.md) bölüm 2.

---

## 7. Content Rating (Play Console)

**Gerekli:** İçerik derecelendirme anketi.

**Adımlar:**
1. Play Console → Policy → App content → Content rating
2. “Start questionnaire” tıklayın.
3. **Yanıt rehberi:** [CONTENT_RATING_ANSWERS.md](CONTENT_RATING_ANSWERS.md)
4. Sonuç genelde PEGI 3 / Everyone benzeri olur.

---

## 8. AAB Yükleme (Play Console)

**Gerekli:** Release AAB dosyası.

**Adımlar:**
1. Yerelde build: `ENCRYPTION_KEY='...' ./scripts/build_production.sh`
2. Dosya: `build/app/outputs/bundle/release/app-release.aab`
3. Play Console → Release → Internal testing → Create new release → AAB yükle
4. Release notları yazın (opsiyonel).

---

## 9. App Store Privacy Details (iOS)

**Gerekli:** App Store Connect’te gizlilik etiketleri.

**Adımlar:**
1. App Store Connect → Uygulama → App Privacy
2. **Copy-paste hazır etiketler:** [APP_STORE_PRIVACY_DETAILS.md](APP_STORE_PRIVACY_DETAILS.md)
3. Amaçları seçin (ör. “App functionality”, “Analytics”).

---

## 10. TestFlight (iOS)

**Gerekli:** iOS build’in TestFlight’a yüklenmesi.

**Adımlar:**
1. `flutter build ios --release --dart-define=ENV=production --dart-define=ENCRYPTION_KEY=...`
2. Xcode → Product → Archive
3. Organizer → Distribute App → App Store Connect
4. Yükleme tamamlandığında TestFlight’tan test edicilere davet gönderin.

---

## 11. QA (Manuel Test)

**Gerekli:** Kritik akışların gerçek cihazda test edilmesi.

**Detaylı senaryolar:** [QA_SENARYOLAR.md](QA_SENARYOLAR.md)

**Özet:**
- Gerçek Android ve iPhone cihazlarda test
- Panik butonu → PIN → geri sayım → acil arama/SMS
- Kişi ekleme, konum paylaşımı, sahte çağrı, siren
- İzin reddi ve offline senaryolar

---

## Hızlı Başlangıç Sırası

1. Privacy Policy URL + Support email (store’a giriş için zorunlu)
2. AAB build + Internal Testing yükle (Android için hızlı geri bildirim)
3. Data Safety + Content rating (Play Console tamamlama)
4. Screenshots + Store listings (store görünürlüğü)
5. iOS: Privacy Details + TestFlight
6. QA (her platformda kritik akışlar)
