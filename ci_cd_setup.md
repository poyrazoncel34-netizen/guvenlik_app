# GitHub Actions CI/CD — Kurulum Rehberi

## Gerekli GitHub Secrets

Repo'nuzda **Settings > Secrets and variables > Actions** bölümüne şu secret'ları ekleyin:

### 1. Android Signing Key

```bash
# Keystore dosyasını base64'e çevirin:
base64 -i android/korubeni-release-key.jks | pbcopy
```

| Secret Adı | Değer |
|---|---|
| `KEYSTORE_BASE64` | Yukarıdaki base64 çıktısı |
| `KEY_ALIAS` | key.properties dosyasındaki `keyAlias` değeri |
| `KEY_PASSWORD` | key.properties dosyasındaki `keyPassword` değeri |
| `STORE_PASSWORD` | key.properties dosyasındaki `storePassword` değeri |

### 2. Google Play Deploy (İsteğe Bağlı)

Google Play Console'dan bir **Service Account** oluşturup JSON key'ini ekleyin:

| Secret Adı | Değer |
|---|---|
| `GOOGLE_PLAY_SERVICE_ACCOUNT_JSON` | Service account JSON içeriği |

## Pipeline Akışı

```
Push to main → Analyze → Test → Build AAB → Deploy to Internal Track
Push to develop → Analyze → Test (build yok)
Pull Request → Analyze → Test (build yok)
```

## İlk Kullanım

1. GitHub'da repo oluşturun
2. Secret'ları ekleyin
3. Kodu push edin
4. Actions sekmesinden pipeline'ı izleyin
