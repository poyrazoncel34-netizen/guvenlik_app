# Denetim Uygulama Oturumu — 2026-07-06

Bu not, 2026-07-06 tarihli KVKK/yayına-hazırlık denetiminin **uygulama** aşamasını
belgeler. Bulgular için: `codebase-audit-2026-06.md`, `release_readiness_research_2026-06-27.md`.

## Yapılanlar (commit kanıtlarıyla)

| İş | Commit | Doğrulama |
|---|---|---|
| RevenueCat 8.x → 10.x migrasyonu commit'lendi | `04aee33` | analyze + 478 test yeşil |
| Kullanılmayan EmergencyCoreService kaldırıldı | `545400d` | " |
| Harita konum izni prominent-disclosure'a bağlandı | `377b95d` | regresyon testi dahil |
| API 27/29 stil öznitelikleri temel kaynaklardan çıkarıldı | `cc08a4b` | lintPlayRelease uyumu |
| Ölü EncryptionService + hayalet ENCRYPTION_KEY söküldü | `189f20e` | negatif regresyon testleri eklendi |
| targetSdk 35 → 36 (31 Ağustos 2026 Play şartı) | `9379180` | placeholder release build |
| KVKK aydınlatma 3.2.0: gerçek veri sorumlusu kimliği + m.9 aktarım şeffaflığı + TR/EN parite | `931a92a` | test pinleri + HTML aynaları güncel |
| `_isKvkkAccepted` → `_isKvkkAcknowledged` | `dcc2936` | davranış değişikliği yok |

## Keystore kanıtı (K-1 çözümü)

`keytool` ile iki keystore da key.properties kimlik bilgileriyle test edildi (2026-07-06):

- ❌ eski `korubeni_keystore.jks` (dosya tarihi 20 Haziran): **şifre uymuyor** →
  `korubeni_keystore_SIFRESI_BILINMIYOR_KULLANMA.jks` olarak yeniden adlandırıldı.
- ✅ eski `korubeni_keystore_ESKI_YEDEK.jks` (11 Mart): açılıyor, alias mevcut →
  **`korubeni_keystore_release.jks`** olarak yeniden adlandırıldı; key.properties güncellendi.
- Resmî imzalama anahtarı parmak izi (SHA-256):
  `AF:68:8F:50:BB:20:0C:6A:A2:1D:69:E2:8A:F1:41:45:F3:F2:76:11:E2:C1:4E:1A:D3:FE:2F:DF:FD:D2:95:94`

Operatör: ilk Play yüklemesinden önce **Play App Signing**'e kaydol; keystore + şifreleri
şifre kasası + ayrı fiziksel yedek olarak sakla. Uygulama henüz yayınlanmadığı için
anahtar seçimi serbesttir; ilk yüklemeden sonra kalıcılaşır.

## EncryptionService kaldırma gerekçesi (Z-1)

- Kod tabanında tek bir çağıran yoktu (yalnızca DI kaydı); release pipeline yine de
  ENCRYPTION_KEY dart-define'ı zorunlu kılıyordu.
- Derleme zamanı dart-define anahtarı hatalı desendir: AOT snapshot'a gömülür,
  binary'den çıkarılabilir, tüm kurulumlarda aynıdır. Gerçek koruma
  flutter_secure_storage (Android Keystore, kurulum başına anahtar) ile PIN/kişilerde
  zaten mevcut; ona dokunulmadı.
- Geri sızma koruması: gradle/fastlane/release-workflow için
  `isNot(contains('ENCRYPTION_KEY'))` testleri eklendi.
- CI notu: `CI_ENCRYPTION_KEY` GitHub secret'ı artık kullanılmıyor; secret'ın
  GitHub'dan silinmesi operatör adımıdır (zararsız, ama temizlik).

## KVKK 3.2.0 kararlarının dayanağı (K-5, K-6)

- **Kimlik:** KVKK m.10 veri sorumlusunun kimliğini ister; "KoruBeni" tüzel kişilik
  değildir. Uygulama içi metin, yayındaki gizlilik politikasıyla (Poyraz Öncel, İzmir)
  eşitlendi.
- **m.9 şeffaflığı:** 1 Eylül 2024'ten beri arızi olmayan yurt dışı aktarımda açık
  rıza tek başına geçerli değil. RevenueCat akışı sürekli → arızi değil. Eklenen
  cümle aktarımı **meşrulaştırmaz**, m.10 şeffaflığını sağlar ve metin-kod makasını
  kapatır. Yapısal karar operatörde (aşağıda).
- **2026/347 sayılı İlke Kararı (RG 24.03.2026):** aydınlatma için onay/rıza
  istenemez; yalnızca "okudum" geri bildirimi alınabilir. Mevcut checkbox metni
  ("okudum ve anladım") uyumlu; granüler rızalar ayrı beyanlar halinde ve opsiyonel.
  Değişken adı bu karara uygun şekilde `_isKvkkAcknowledged` yapıldı.
- Sürüm bump'ı LegalVersionChecker üzerinden yeniden onay akışını tetikler —
  tasarlanmış davranış; yayınlanmamış uygulamada kullanıcı maliyeti sıfır.

## Operatöre kalan kararlar / adımlar

1. **RevenueCat m.9 kararı (tek açık hukuki risk):**
   (a) belgelenmiş risk kabulü (veri minimize: `collectDeviceIdentifiers()` çağrılmıyor,
   anonim ID; küçük geliştiriciye yaptırım emsali bulunamadı — garanti değildir), veya
   (b) RevenueCat'i çıkarıp saf Google Play Billing (aktaran sıfatı yapısal olarak
   ortadan kalkar; ~1-2 hafta iş). Yayın öncesi (a) + yol haritasına (b) makul bir çizgidir.
2. **gh-pages yeniden publish:** `.gh-pages-publish/aydinlatma.html` güncellendi;
   canlı GitHub Pages kopyasının push'lanması gerekir.
3. **Sahte çağrı + kilitli ekran:** `USE_FULL_SCREEN_INTENT` beyan edilmedi; Android
   14+ kilitli ekranda zamanlanmış sahte çağrı heads-up bildirime düşer. Karar: izni
   beyan et (ayarlardan kullanıcı onayı akışı gerekir) YA DA ses tuşu örneğindeki
   gibi sınırı UI metnine yaz. Belirsiz bırakma.
4. **Cihaz doğrulaması:** targetSdk 36 + RevenueCat v10 gerçek cihazda (en az bir
   Xiaomi dahil) uçtan uca test — satın alma/restore/iptal + Doze altında acil akış.
5. **Play Console:** Data Safety (RevenueCat satırı dahil), içerik derecelendirme,
   FGS specialUse / exact alarm / battery-optimization beyanları, 12 tester × 14 gün.
6. `CI_ENCRYPTION_KEY` ve `ENCRYPTION_KEY` GitHub secrets temizliği.

## Doğrulama durumu

- `flutter analyze`: temiz (her commit sonrası).
- `flutter test`: 478 test yeşil (her commit sonrası; EncryptionService testlerinin
  kaldırılmasıyla 483'ten düştü).
- Placeholder release AAB + 16KB hizalama: bu oturumda yeniden koşuldu (sonuç için
  oturum kaydı). ENCRYPTION_KEY **verilmeden** derlendi — söküm kanıtı.
- Bu artefact Play'e yüklenmez; yalnızca pipeline kanıtıdır.
