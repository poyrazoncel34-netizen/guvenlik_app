# Google Play Console – Yayın Öncesi Kontrol Listesi

Bu liste, KoruBeni uygulamasını Play Store’a göndermeden önce **Play Console**’da tamamlaman gereken adımları özetler.

---

## 1. Privacy Policy URL

- **Nerede:** Play Console → Uygulama → **Store ayarları** (veya Store presence) → **Store listing** → **Privacy policy**
- **Ne yap:** Gizlilik politikasının yayında olduğu **canlı URL**’yi gir.
- **KoruBeni için:**
  - Gizlilik metni: `store/privacy_policy.html` (TR), `store/privacy_policy_en.html` (EN)
  - GitHub Pages URL: `https://poyrazoncel34-netizen.github.io/guvenlik_app/privacy_policy.html`
  - Bu URL’yi Play Console’daki **Privacy policy** alanına yapıştır.
- **Detay:** [store/privacy_policy_template.md](privacy_policy_template.md)

---

## 2. Data Safety (Veri Güvenliği) Formu

- **Nerede:** Play Console → Uygulama → **Policy** → **App content** → **Data safety**
- **Ne yap:** Toplanan / paylaşılan veri türlerini ve amaçlarını beyan et.

KoruBeni için güvenli ve güncel beyan yaklaşımı:

| Veri türü | Toplama / paylaşma | Amaç (kısa) |
|------------|--------------------|-------------|
| **Konum** (approximate / precise) | Acil durumda veya kullanıcı konum oturumunu başlatınca işlenir; uygulama otomatik mesajla paylaşmaz | Acil durumda konum durumu |
| **Kişiler** (rehber) | Cihazda erişilir, seçilen kişi cihazda saklanır | Acil kişi seçimi |
| **Ses kaydı** (mikrofon) | Opsiyonel, cihazda kalır | Kanıt / delil kaydı |
| **Profil bilgisi** (ad/fotoğraf) | Opsiyonel, cihazda kalır | Uygulama içi kişiselleştirme |
| **Uygulama etkileşimi** | Toplanmıyor | Analitik / crash reporting yok |

- Konum ve kişi erişimi kullandığı için Data Safety formunu boş bırakma.
- Firebase, auth, crash analytics veya push bildirim beyanı verme; mevcut mimari offline-first.
- Gizlilik politikasındaki açıklamalarla **tutarlı** ol.

---

## 3. İçerik Derecelendirmesi (Content Rating)

- **Nerede:** Play Console → **Policy** → **App content** → **Content rating**
- **Ne yap:** “Start questionnaire” / “Anketi başlat” de; soruları yanıtla.
- **KoruBeni için genel rehber:**
  - Şiddet: Yok veya çok düşük (güvenlik uygulaması).
  - Cinsellik / korku: Yok.
  - Tehlikeli faaliyet: Acil arama / panik özelliği var; “acil durum / güvenlik” bağlamında işaretle.
  - Sonuç genelde **PEGI 3 / Everyone** benzeri çıkar; anketi bitirip sertifikayı al.

---

## 4. Hedef Kitle ve Reklam

- **Nerede:** **Policy** → **App content** → **Target audience and content** (veya **Ads**)
- **Ne yap:**
  - **Hedef kitle:** Yetişkin (örn. 18+ veya “not for children”) veya “all ages” – uygulama amacına göre seç.
  - **Reklam:** KoruBeni reklam içermiyorsa “No, my app does not contain ads” işaretle.

---

## 5. AAB Yükleme (Internal / Closed / Production)

- **Nerede:** Play Console → **Release** → **Testing** (Internal / Closed) veya **Production**
- **Ne yap:**
  1. Yerelde: `ENCRYPTION_KEY='...' REVENUECAT_ANDROID_API_KEY='goog_...' ./scripts/build_production.sh` veya
     `flutter build appbundle --release --flavor play --dart-define=ENV=production --dart-define=REVENUECAT_ANDROID_API_KEY=goog_... --dart-define=ENCRYPTION_KEY=...`
  2. Oluşan dosya: `build/app/outputs/bundle/playRelease/app-play-release.aab`
  3. Play Console’da ilgili track’i seç → **Create new release** → AAB dosyasını yükle.
  4. Release notları yaz (opsiyonel ama önerilir).
  5. İncelemeye gönder.

---

## 6. Özet Sıra

1. Privacy Policy’i yayınla; URL’yi Store listing’e ekle.
2. Data Safety formunu doldur (konum, kişi erişimi, ses kaydı, opsiyonel profil verisi).
3. Content rating anketini tamamla.
4. Hedef kitle ve reklam bilgisini gir.
5. AAB’yi build alıp ilgili track’e yükle.

Bu adımlar [release_checklist.md](release_checklist.md) ile uyumludur; oradaki “Privacy Policy URL canlı”, “Data Safety form”, “Internal Testing track’e yükle” vb. maddeler bu dokümandaki işlemlerle tamamlanır.
