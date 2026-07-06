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

---

# ÖZ-DENETİM TURU 2 (aynı gün) — İlk uygulamanın eksikleri ve kapatılması

İlk uygulama turu "her adım kanıtlı" iddiasındaydı; ikinci acımasız denetim şunları buldu:

## Bulunan ve kapatılan eksikler

1. **KVKK §2/§5 yapısal eksik:** Aktarım CÜMLESİ eklenmiş ama m.10'un istediği yapıya
   — veri kategorileri tablosu ve saklama süreleri — abonelik verisi satırı eklenmemişti.
   Kapatıldı: TR/EN tablolarına "Abonelik (Pro) | IP, cihaz bilgisi, abone kimliği |
   ... | Sözleşmenin ifası (m.5/2-c)" satırı + saklama bölümlerine abonelik satırı +
   HTML tablolarına aynı satır. Hukuki sebep bilinçli olarak açık rıza DEĞİL
   sözleşmenin ifası seçildi (rıza enflasyonundan kaçınma: rıza geri çekilirse Pro
   sözleşmesi ifa edilemez hale gelirdi).
2. **Mevcut metinde madde atıf hatası (ilk turda gözden kaçtı):** HTML tablolar açık
   rızayı "Md. 5/2-a" diye gösteriyordu; açık rıza m.5/1'dir, 5/2-a "kanunlarda
   açıkça öngörülme"dir. 4 satır × 2 ayna düzeltildi.
3. **targetSdk 36 etki analizi yüzeyseldi:** Android 16, sw>=600dp ekranlarda
   orientation/resizability kısıtlarını YOK SAYAR (kaynak: developer.android.com
   behavior-changes-16). main.dart:209 portre kilidi tablet/katlanabilirde devre
   dışı kalacaktı. Google'ın belgelediği GEÇİCİ opt-out
   (PROPERTY_COMPAT_ALLOW_RESTRICTED_RESIZABILITY) manifeste eklendi.
   **TEKNİK BORÇ:** API 37'de opt-out kalkıyor — adaptif layout çalışması planlanmalı.
4. **Billing Library kanıtı (ilk raporda kurulmayan bağlantı):** Play, 31 Ağustos
   2026'dan itibaren yeni sürümlerde Billing Library v8 istiyor (developer.android.com
   deprecation-faq). purchases_flutter 10.3.0'ın 'billingclient bc8' kullandığı pub
   cache gradle'ında doğrulandı → RevenueCat v10 migrasyonu tercihe bağlı bir
   iyileştirme değil, targetSdk 36 ile AYNI deadline'ın zorunluluğuydu. 8.x'te
   kalınsaydı Ağustos sonrası güncelleme yüklenemezdi.
5. **CI'da bayat keystore rehberliği:** release.yml, KEYSTORE_BASE64 secret'ını
   şifresi bilinmeyen eski dosya adına referansla anlatıyordu. Dosya adları
   korubeni_keystore_release.jks olarak güncellendi. **OPERATÖR:** KEYSTORE_BASE64
   secret'ının, çalışan keystore'un base64'ü olduğunu doğrula:
   `base64 -i android/app/korubeni_keystore_release.jks | tr -d '\n'`
6. **Data Safety formu ile yeni legal metin arası tutarlılık:** IP adresi formda
   yoktu, kimlik satırına eklendi.
7. **"Operatör push'lasın" kaçamağı:** gh-pages branch'i lokalde mevcuttu; güncel
   aydinlatma.html worktree ile commit'lendi (gh-pages @ 2135fe7). Kalan tek adım
   `git push origin gh-pages` (yayına alma kararı operatörde).
8. **Android lint/Kotlin testleri ilk turda atlanmıştı** (Haziran süreci koşuyordu):
   bu turda lintPlayRelease + testPlayDebugUnitTest koşuldu (sonuç oturum kaydında).

---

# %100 HAZIRLIK TURU (aynı gün, tur 3)

## Kapatılanlar

- **main + gh-pages push edildi** (7a24133..20c86e3, 93e225e..2135fe7). Canlı
  aydınlatma 3.2.0'a döndü (yayın sonrası URL doğrulaması oturum kaydında).
- **FSI kararı kapatıldı (madde 8b):** USE_FULL_SCREEN_INTENT manifeste beyan
  edildi. Gerekçe: sahte çağrı kilitli ekranda gerçek çağrı gibi çalmalı
  (çekirdek senaryo) + acil geri sayım uyarıları kilitli ekranda görünmeli.
  Kod zaten canUseFullScreenIntent() ile düşüyor; beyan yalnızca yetenek
  kazandırır, çökme yüzeyi eklemez. Console formu gerekirse gerekçe:
  docs/play_console_declarations.md. Tutarlılık testi eklendi (manifest ↔ docs).
  Operatör farklı tercih ederse beyanı kaldırmak tek satır + testi güncellemek.

## RevenueCat m.9 KARAR KAYDI (madde 8a) — OPERATÖR ONAYI BEKLİYOR

Öneri (mühendis değerlendirmesi, hukuki görüş değildir):
- **Yayın için (a) belgelenmiş risk kabulü.** Dayanak: akış minimize
  (collectDeviceIdentifiers çağrılmıyor, anonim abone kimliği, reklam/atıf
  kimliği yok), aydınlatma 3.2.0 aktarımı m.9 kapsamında açıkça bildiriyor,
  Data Safety formu tutarlı, küçük geliştiriciye bu zeminde yaptırım emsali
  bulunamadı (garanti değildir). Kalan hukuki boşluk: Türk standart
  sözleşmesinin RevenueCat ile imzalanmamış olması — bugün pratikte
  kapatılamıyor.
- **Yol haritası için (b):** ilk kararlı sürümden sonra saf Play Billing'e
  geçiş değerlendirmesi (~1-2 hafta iş; aktaran sıfatını yapısal olarak
  kaldırır). v1.1 aday maddesi.
- Onay şekli: bu bölüme "ONAYLANDI — <tarih, isim>" satırı eklemek yeterli.

## Bu turda da KAPANAMAYANLAR (yapısal olarak repo dışı)

1. Gerçek REVENUECAT_ANDROID_API_KEY ile üretim AAB (anahtar yalnızca
   RevenueCat panelinde).
2. Play Console formları + kapalı test + 12 tester × 14 gün.
3. Gerçek cihaz turu: Doze/OEM-killer/satın alma (emülatör smoke denemesi
   oturum kaydında; Doze yarışı ve billing yalnızca gerçek cihazda).

## Emülatör smoke testi (Android 16 / API 36) — 2026-07-06

Gerçek cihaz DEĞİL ama gerçek OS: AVD "Medium Phone API 36.1" (Android 16, SDK 36).
İmzalı release APK (app-play-release.apk, 76.5MB) temiz kuruldu ve başlatıldı.

**KANITLANAN (CONFIRMED):**
- Android 16'da çökmeden açılıyor: `Displayed ... MainActivity +1s782ms`, PID canlı,
  logcat'te FATAL/AndroidRuntime yok.
- Tam servis init (önceki koşu logu): "Integrity check: all data consistent",
  LocalLogger, ForegroundService, HapticService configured.
- targetSdk 36 + FSI beyanı + orientation opt-out property'siyle kurulum/başlatma
  sorunsuz.

**KANITLANAMAYAN (gerçek cihaz gerektirir):**
- Görsel UI doğrulaması: Flutter **Impeller (OpenGLES) backend** emülatörde
  `screencap`'e siyah kare veriyor + pencere SurfaceFlinger'da (Secure) — ikisi de
  bilinen yakalama artefaktı, uygulama bug'ı DEĞİL (loglar render + çalışmayı
  kanıtlıyor). Yine de göz-ile UI doğrulaması gerçek cihazda yapılmalı.
- Doze yarışı, OEM arka-plan katili, gerçek satın alma/restore: emülatör kapsamaz.
- RevenueCat: placeholder anahtarla init beklenen şekilde devre dışı; gerçek panel
  + lisans tester gerçek cihaz işi.
