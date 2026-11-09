# flutter_secure_storage 10.0.0 -> 10.3.4 ve migrateWithBackup

Tarih: 2026-11-09 · Dal: `codex/evidence-remediation-20260911` · Commit: `5b73db9`
Sahip onayi: 2026-11-09 ("Evet, ayri commit"). Onaylanan plan 10.3.1 diyordu; 10.x
hattinin son yamasi 10.3.4 secildi, cunku 10.3.2-10.3.4 dogrudan veri kaybi
duzeltmeleri iceriyor (asagida).

## Neden

- 10.3.2: yeni kurulumda calisan ve bazi cihazlarin KeyStore'unda patlayabilen
  gereksiz tasima; v9 verisinin yukseltmede atilmasi; `migrateWithBackup`'in
  yanlis dosyayi yedeklemesi; motor ayrildiktan sonra NPE.
- 10.3.4: ayni yerel depoyu acan iki ornek arasinda tasima yarisi.
- 10.1.0: `migrateWithBackup`, "baslatmada yapilandirmanin ezilmesi", MethodRunner NPE.

## Uyumluluk (kaynak karsilastirmasi, 10.0.0 <-> 10.3.4)

| Oge | 10.0.0 | 10.3.4 |
|---|---|---|
| Veri dosyasi | `FlutterSecureStorage` | ayni (namespace yok) |
| Yapilandirma dosyasi | `FlutterSecureStorageConfiguration` | ayni (`LEGACY_GLOBAL_CONFIG_NAME`) |
| Sarilmis anahtar dosyasi | `FlutterSecureKeyStorage` | ayni (namespace yok) |
| RSA alias | `<paket>.FlutterSecureStoragePluginKeyOAEP` | ayni (sonek bos) |
| Algoritma isaretcisi | `.name()` yazilir | `.name()` okunur/yazilir |
| `resetOnError` varsayilani | `true` | `true` — bizde acikca `false` |
| Tasima hatasi + `resetOnError=false` | hata Dart'a firlar | ayni; silme yok |
| Eklenti manifest'i | bos | bos (yeni izin yok) |
| Gecisli bagimlilik | tink-android 1.19.0 | tink-android 1.21.0 |

Sonuc: 10.0.0'in yazdigi kayit 10.3.4'te ayni dosya/anahtar/isaretciyle okunur;
yukseltme tek basina tasima tetiklemez.

## migrateWithBackup: true

- Bir sifre tasimasi gerekirse kayitlar once `_BACKUP`'a kopyalanir. Yedeksiz yol
  eski RSA anahtarini silip veriyi yalnizca bellekte tutarken yeniden sifreler;
  arada cokme PIN ve kisileri kaybettirir.
- Yan etki: 10.x'te secenek acikken eski EncryptedSharedPreferences (ESP)
  bloğu atlanir. ESP tasimasi yalnizca yedekli tasimanin 7. adiminda kosar.
  Bu uygulamada guvenli: kilit dosyasi ilk commit'ten (`69214d0`, 2026-02-07)
  beri 10.0.0; 10.0.0 `migrateOnAlgorithmChange=true` iken ESP'ye hic yazmaz.
  Ayrica her soguk acilista ESP MasterKey'in Keystore'da yeniden baslatilmasi
  da atlanir.
- Ayni yerel depoyu acan onay (consent) eski okuyucusu artik ayni
  `SecureStorage.androidOptions` sabitini kullanir; test bunu sabitler.

## Lisans kaniti

Ilk kosuda (`ae82c1e`, sonra `5b73db9`'e katildi) `release_sbom_contract_test` ve
`license_review_queue_test` kirmiziydi: 4 pub paketinin eski surum kaydi bayatti.
`scripts/harvest_license_evidence.py` ile toplanan lisans baytlari onceki
incelenmis BSD-3-Clause metinleriyle birebir ayni (SHA-256 esit):

| purl | sha256 (ilk 16) | SPDX |
|---|---|---|
| `pkg:pub/flutter_secure_storage@10.3.4` | `55dafb084270616f` | BSD-3-Clause |
| `pkg:pub/flutter_secure_storage_darwin@0.3.2` | `3754c516086c6230` | BSD-3-Clause |
| `pkg:pub/flutter_secure_storage_linux@3.0.3` | `55dafb084270616f` | BSD-3-Clause |
| `pkg:pub/flutter_secure_storage_web@2.1.1` | `55dafb084270616f` | BSD-3-Clause |

Hesap verebilir inceleme: sahip 2026-11-09'da onayladi; kayit
`korubenidestek@gmail.com` / `2026-11-09`. Arac `reviewedBy`/`reviewedAt` uretmedi;
alanlar sahip onayi uzerine yazildi. `THIRD_PARTY_NOTICES.txt`
`scripts/generate_third_party_notices.py` ile yeniden uretildi
(`LICENSE_POLICY_PASS: 398`, `THIRD_PARTY_NOTICES_PASS`).

## Maven tarafi (duzeltme: ilk iddia yanlisti, iki kez)

Ilk taslakta "Maven tarafi degismedi" yazdim; bu yanlisti. Uygulamanin cozulen
calisma zamani surumu degismedi: Gradle kilidi `tink-android:{strictly 1.19.0}`
tutuyor (`android/app/gradle.lockfile` diff'i bos) ve eklentinin `crypto/`
kaynagi 10.0.0 ile birebir ayni. Ama `verification-metadata.xml` cozulmeyen
ama meta verisi indirilen surumleri de dogruluyor:

1. `60a7b01` temiz worktree kosusu 3/6'da (AAB) dustu: Gradle catisma cozumu
   icin eklentinin istedigi tink 1.21.0 ve gecisli gson 2.13.2 /
   error_prone_annotations 2.41.0 meta verisini indiriyor.
2. Bu 4 bileseni ekleyip uretilen diger 18 bileseni "ilgisiz" diye disarida
   biraktim (`4fdd413`). Bu da yanlisti: kosu 4/6'da (Android lint) dustu.
   10.3.4 eklentinin kendi Android modulune `apply plugin: 'jacoco'` ve
   `testImplementation 'org.robolectric:robolectric:4.16.1'` ekledi (10.0.0'da
   yok); lint `:flutter_secure_storage:releaseUnitTestCompileClasspath`'i da
   cozup dogruluyor.

(`60a7b01` ve `4fdd413` itilmemis yerel ara commit'lerdi; ikisi de `5b73db9`'e
commit --amend ile katildi, dalda yoklar.)

Son durum: 22 bilesen, hepsi Gradle'in `--write-verification-metadata sha256`
ciktisi (elle yazilmadi), verify zincirinin kostugu gorevlerle uretildi
(`:app:assemblePlayDebug`, `app:lintSmokeRelease`, `app:testPlayDebugUnitTest`,
`app:assemblePlayDebugAndroidTest`). Silinen satir yok.

| Bilesen | Neden | Artefakt | Onbellek SHA-256 = metadata | SHA-1 = Maven Central `.sha1` |
|---|---|---|---|---|
| `tink-android:1.21.0`, `gson:2.13.2`, `gson-parent:2.13.2`, `error_prone_annotations:2.41.0` | eklentinin `implementation` istegi (catisma cozumu) | 7 | EVET | EVET |
| `org.jacoco.*:0.8.12` (agent, ant, build, core, report) | eklentide `apply plugin: 'jacoco'` | 9 | EVET | EVET |
| `org.ow2.asm:asm-bom:9.7` | jacoco gecisli | 1 | EVET | EVET |
| `org.robolectric:*:4.16.1` (12 modul) | eklentide `testImplementation` | 24 | EVET | EVET |

Robolectric ve jacoco yalnizca eklentinin test/lint siniflandirmasinda; AAB'ye
girmez, uygulama calisma zamanini etkilemez.

## Bilinen eski belge

`docs/SECURITY_AT_REST_DESIGN.md` hala `10.0.0` ve "varsayilan `AndroidOptions()`"
diyor; ikincisi `resetOnError` duzeltmesinden beri de gecersiz. Tarihli bir
tasarim analizi oldugu icin bu iste yalnizca surum numarasi degistirilmedi
(belgeyi tutarsiz birakirdi); ayri bir belge guncellemesi gerekir.

## Kanit

- `evidence/secure-storage-10-3-4-2026-11-09/red_run.txt` — 10.0.0'da yeni secenek
  testi kirmizi (`migrateWithBackup` kanala hic gitmiyor).
- `.../green_run.txt` — 10.3.4 + secenek: 4/4 yesil.
- `.../maven_checksum_crosscheck.txt` — 22 bilesen / 41 artefakt: onbellek SHA-256 =
  metadata ve SHA-1 = Maven Central `.sha1`; 41/41 EVET, silinen satir 0.
- `.../verify_release_clean_worktree.txt` — `5b73db9` uzerinde temiz worktree'de
  `scripts/verify_release.sh` (R8, imzali smoke AAB, Kotlin unit, 16KB, SBOM/lisans); 6/6 yesil,
  2834 test, `exit=0`. Ek olarak soguk onbellekte (`--refresh-dependencies`)
  `:app:assemblePlayDebug`, `app:lintSmokeRelease`, `app:testPlayDebugUnitTest` +
  `app:assemblePlayDebugAndroidTest`: uc kosu da BUILD SUCCESSFUL, dogrulama hatasi 0.

## Cihazda dogrulanmasi gerekenler (YAPILMADI)

Her sonuc AVD/cihaz, yogunluk, olculen commit ve
`adb shell dumpsys package <id> | grep lastUpdateTime` ile kaydedilmeli.

1. **Yukseltme (zorunlu):** `5b73db9~1` (10.0.0) debug build'i kur; PIN, 2 kisi,
   Kontrol Noktasi ayari gir. Uygulamayi kapat. `5b73db9` debug build'ini
   `adb install -r` ile UZERINE kur. Beklenen: acilis PIN kilidi (PIN kurulumu
   DEGIL), dogru PIN kabul, kisiler ayni, `logcat -s FlutterSecureStorage` icinde
   "migration" satiri YOK.
2. Ayni adimi release imzali smoke build'le tekrarla (R8 etkin).
3. Yukseltmeden sonra soguk acilis suresi: `adb shell am start -W` ile 5 kez,
   10.0.0 build'iyle karsilastir (ESP MasterKey atlandigi icin esit ya da daha
   kisa beklenir; olc, varsayma).
4. Yeni kurulum: temiz kurulumda PIN kur, uygulamayi oldur, yeniden ac; kilit gelmeli.
