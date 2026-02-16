# KoruBeni — Dağıtım Kontrol Listesi

Bu rehber 3 ana adımı kapsar:

1. GitHub Secrets ekleme  
2. Google Play Console'a AAB yükleme  
3. Gizlilik politikasını web'de yayınlama  

---

## 1. GitHub Secrets Ekleme

**Repo:** https://github.com/poyrazoncel34-netizen/guvenlik_app

**Settings → Secrets and variables → Actions → New repository secret**

### Android imzalama (CI/CD için zorunlu)

| Secret Adı | Nasıl alınır |
|------------|--------------|
| `KEYSTORE_BASE64` | `base64 -i android/korubeni-release-key.jks \| pbcopy` (veya çıktıyı kopyala) |
| `KEY_ALIAS` | `android/key.properties` → `keyAlias` değeri |
| `KEY_PASSWORD` | `android/key.properties` → `keyPassword` değeri |
| `STORE_PASSWORD` | `android/key.properties` → `storePassword` değeri |

**Not:** CI/CD workflow `korubeni-release-key.jks` kullanıyor. `key.properties` içindeki alias ve parolaları GitHub Secrets olarak ekleyin.

### Google Play (opsiyonel — otomatik deploy)

| Secret Adı | Değer |
|------------|-------|
| `GOOGLE_PLAY_SERVICE_ACCOUNT_JSON` | Google Play Console → Setup → API access → Service Account oluştur → JSON key indir → **tüm JSON içeriğini** buraya yapıştır |

**Service Account kurulumu:**
1. [Google Play Console](https://play.google.com/console) → Uygulama seç
2. **Setup** → **API access** → **Link** (veya Create new service account)
3. Google Cloud Console'da Service Account oluştur → JSON key indir
4. Play Console'da bu hesabı **Admin** veya **Release manager** yetkisiyle ekle
5. JSON içeriğini `GOOGLE_PLAY_SERVICE_ACCOUNT_JSON` secret'ına ekle

---

## 2. Google Play Console'a AAB Yükleme

### A) Otomatik (CI/CD ile)

Secret'lar eklendikten sonra `main` branch'e push yapın. GitHub Actions:

1. AAB build eder  
2. `GOOGLE_PLAY_SERVICE_ACCOUNT_JSON` varsa **Internal** track'e yükler  

**Actions** sekmesinden pipeline'ı takip edin.

### B) Manuel yükleme

1. AAB dosyasını oluşturun:
   ```bash
   # android/key.properties ve ENCRYPTION_KEY hazır olmalı
   ENCRYPTION_KEY='<base64_key>' flutter build appbundle --release \
     --dart-define=ENV=production --dart-define=ENCRYPTION_KEY=<base64_key>
   ```
2. Dosya: `build/app/outputs/bundle/release/app-release.aab`
3. [Google Play Console](https://play.google.com/console) → Uygulama → **Production** / **Internal testing** → **Create new release**
4. AAB dosyasını sürükleyip bırakın
5. Release notes ekleyip yayınlayın

---

## 3. Gizlilik Politikasını Web'e Koyma

Store başvurusu için gizlilik politikası **public URL** gerektirir.

### Yöntem A: GitHub Pages (önerilen)

1. Repo **Settings** → **Pages** → **Build and deployment** → **Source: GitHub Actions**
2. `main` branch'e push yapın (`.gh-pages-publish` veya `store/privacy_policy*.html` değişirse `Deploy Privacy Policy` workflow tetiklenir)
3. Manuel tetikleme: **Actions** → **Deploy Privacy Policy** → **Run workflow**

**URL'ler** (repo `guvenlik_app`, username `poyrazoncel34-netizen`):
- Ana sayfa: https://poyrazoncel34-netizen.github.io/guvenlik_app/
- Türkçe: https://poyrazoncel34-netizen.github.io/guvenlik_app/privacy_policy.html
- İngilizce (Play Store için): https://poyrazoncel34-netizen.github.io/guvenlik_app/privacy_policy_en.html

### Yöntem B: gh-pages CLI

```bash
npx gh-pages -d .gh-pages-publish
```

Sonrasında Settings → Pages → Source: **Deploy from a branch** → **gh-pages** branch

### Yöntem C: Netlify Drop

1. [app.netlify.com/drop](https://app.netlify.com/drop) adresine gidin
2. `.gh-pages-publish` klasörünü sürükleyip bırakın
3. Verilen URL'yi (örn. `https://random-name.netlify.app`) store listing'de kullanın

### Store'da kullanım

- **Play Store:** Store listing → Privacy policy → URL girin  
- **App Store:** App Information → Privacy Policy URL  

---

## Hızlı başlangıç sırası

1. [ ] GitHub Secrets ekle (`KEYSTORE_BASE64`, `KEY_ALIAS`, `KEY_PASSWORD`, `STORE_PASSWORD`)
2. [ ] İsteğe bağlı: `GOOGLE_PLAY_SERVICE_ACCOUNT_JSON` ekle (otomatik Play deploy için)
3. [ ] Gizlilik politikasını yayınla (GitHub Pages veya Netlify)
4. [ ] `main` branch'e push yap (CI/CD tetiklenir)
5. [ ] Play Console'da privacy policy URL'sini store listing'e ekle
