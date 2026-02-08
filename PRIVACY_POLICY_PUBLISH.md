# Gizlilik Politikası Yayınlama

Store başvurusu için gizlilik politikasının **public bir URL**'de yayında olması gerekir.

## Hızlı Yöntem: GitHub Pages

1. **Hazırlık** (tek seferlik):
   ```bash
   ./scripts/publish_privacy_policy.sh
   ```

2. **Yayınla**:
   ```bash
   npx gh-pages -d .gh-pages-publish
   ```

3. **URL'ler** (repo adı `guvenlik_app` ise):
   - Ana sayfa: `https://<username>.github.io/guvenlik_app/`
   - İngilizce: `https://<username>.github.io/guvenlik_app/privacy_policy_en.html`

4. **GitHub Ayarları**: Repo > Settings > Pages > Source: **gh-pages** branch, / (root)

## Alternatif: Netlify Drop

- [app.netlify.com/drop](https://app.netlify.com/drop) adresine git
- `.gh-pages-publish` klasörünü sürükle-bırak
- Verilen URL'yi store listing'de kullan

## Store Listing'de Kullanım

- **Play Store**: Store listing > Privacy policy > URL girin
- **App Store**: App Information > Privacy Policy URL
