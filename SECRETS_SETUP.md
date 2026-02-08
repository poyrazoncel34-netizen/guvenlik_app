# Gizli Anahtarlar Kurulumu

Bu dosya production build için gerekli gizli değerlerin nasıl ayarlanacağını açıklar. **Bu değerleri ASLA Git'e commit etmeyin.**

## 1. Android Release Signing (key.properties)

```bash
cp key.properties.example key.properties
# key.properties dosyasını düzenleyin - gerçek değerleri girin
```

- `key.properties` zaten `.gitignore`'da
- Keystore oluşturmak: `keytool -genkey -v -keystore upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload`

## 2. Şifreleme Anahtarı (ENCRYPTION_KEY)

Uygulama hassas verileri (PIN, kişiler) şifrelemek için AES kullanır. Production build'de mutlaka ayarlayın:

```bash
# Base64 formatında 32 byte (256 bit) anahtar oluşturun:
# openssl rand -base64 32

# Build sırasında geçirin:
flutter build apk --dart-define=ENV=production --dart-define=ENCRYPTION_KEY=<base64_key>
flutter build appbundle --dart-define=ENV=production --dart-define=ENCRYPTION_KEY=<base64_key>
flutter build ios --dart-define=ENV=production --dart-define=ENCRYPTION_KEY=<base64_key>
```

**CI/CD'de**: Environment variable olarak `ENCRYPTION_KEY` tanımlayın, build script'te `--dart-define=ENCRYPTION_KEY=$ENCRYPTION_KEY` kullanın.

## 3. Firebase (google-services.json / GoogleService-Info.plist)

- `android/app/google-services.json` - Android için
- `ios/Runner/GoogleService-Info.plist` - iOS için

Bu dosyalar Firebase Console'dan indirilir ve `.gitignore`'da listelenmiştir.
