# KoruBeni — Çıkış Öncesi Durum ve Yapılan Düzeltmeler

## Yapılan düzeltmeler (bu oturumda)

### 1. Android CI workflow eklendi
- **Dosya:** `.github/workflows/android.yml`
- **Ne yapar:** `main` branch'e push veya manuel tetiklemede:
  - Flutter analyze
  - Flutter test
  - Gerekli secret'lar varsa: release AAB build, artifact olarak yükleme
- **GitHub Secrets (gerekli):**
  - `KEYSTORE_BASE64` — `base64 -i android/korubeni-release-key.jks` çıktısı
  - `KEY_ALIAS`, `KEY_PASSWORD`, `STORE_PASSWORD` — key.properties değerleri
  - `ENCRYPTION_KEY` — production build için (örn. `openssl rand -base64 32`)
- **Opsiyonel:** `ANDROID_GOOGLE_SERVICES_JSON_BASE64` — Firebase için (base64 -i android/app/google-services.json)

### 2. Gizlilik politikası deploy düzeltildi
- **Dosya:** `.github/workflows/pages.yml`
- **Değişiklik:** Artık **`.gh-pages-publish`** klasörü deploy ediliyor (önceden `docs`).
- **Sonuç URL'leri:**
  - Ana: `https://poyrazoncel34-netizen.github.io/guvenlik_app/`
  - TR: `.../guvenlik_app/privacy_policy.html`
  - EN: `.../guvenlik_app/privacy_policy_en.html`
- Tetikleyici: `.gh-pages-publish/**` değişince veya **Actions → Deploy Privacy Policy → Run workflow**.

### 3. ENCRYPTION_KEY log güvenliği
- **Dosya:** `scripts/build_production.sh`
- **Değişiklik:** Production build sırasında encryption key’in ilk 20 karakteri artık loglanmıyor; sadece “Encryption key set” mesajı yazılıyor (CI log güvenliği).

---

## Mevcut durum (kod tarafı)

| Kontrol              | Durum |
|----------------------|--------|
| `flutter analyze`     | ✅ Sorun yok |
| `flutter test`       | ✅ 34 test geçiyor |
| Release checklist    | ⚠️ Store/QA maddeleri senin yapacağın işler (aşağıda) |

**Test uyarısı (kritik değil):** Easy Localization `panic_button_semantics_label` / `panic_button_semantics_hint` test ortamında bulamıyor; çeviri dosyalarında anahtarlar mevcut, uygulama normal çalışır.

---

## Uygulamayı çıkarmak için senin yapman gerekenler

### 1. GitHub Secrets (CI için)
- Repo → **Settings → Secrets and variables → Actions**
- Ekleyeceklerin: `KEYSTORE_BASE64`, `KEY_ALIAS`, `KEY_PASSWORD`, `STORE_PASSWORD`, `ENCRYPTION_KEY`
- İstersen: `ANDROID_GOOGLE_SERVICES_JSON_BASE64` (Firebase)

### 2. Gizlilik politikasını yayına al
- **Settings → Pages → Source:** GitHub Actions
- `.gh-pages-publish` içeriği güncelse **Actions → Deploy Privacy Policy → Run workflow** çalıştır
- Çıkan URL’yi (örn. `.../guvenlik_app/privacy_policy.html`) Play Store / App Store’da Privacy Policy alanına yaz

### 3. Play Store
- [store/PLAY_CONSOLE_CHECKLIST.md](store/PLAY_CONSOLE_CHECKLIST.md): Privacy Policy URL, Data Safety, Content rating, hedef kitle
- AAB: CI’dan indir (Actions → son run → Artifacts) veya yerelde:  
  `ENCRYPTION_KEY='...' ./scripts/build_production.sh`  
  → `build/app/outputs/bundle/release/app-release.aab`’yi Play Console’a yükle

### 4. iOS (App Store)
- Yerelde: `flutter build ios --release --dart-define=ENV=production --dart-define=ENCRYPTION_KEY=...`
- Xcode’da Archive → App Store Connect’e yükle, TestFlight / yayın

### 5. QA (release_checklist.md’deki gibi)
- Gerçek cihazda (Android + iPhone) test
- PIN kurulumu, SMS/arama, izin reddi, çevrimdışı senaryolar

---

## Hızlı komutlar

```bash
# Yerel production AAB
ENCRYPTION_KEY='...' ./scripts/build_production.sh

# Sürüm artır
./scripts/bump_version.sh

# Test
flutter test
flutter analyze
```

Bu adımlarla uygulama store’a çıkmaya hazır; eksik kalan kısım sadece senin konsol ayarları ve QA.
