# PIN guvenli depo okuma hatasi: gecici/kalici ayrimi ve cikissiz ekran kapatma

Tarih: 2026-11-09 · Dal: `codex/evidence-remediation-20260911` · Taban: `08173c0` · Kod commit'i: `de31e31`

## Sorun

- `PinVerificationService.loadState()` tek bir okuma hatasini veya 2 sn'lik zaman
  asimini dogrudan `readFailed` yapiyordu; kritik baslatma tekrar denemeden
  `BootstrapRecoveryScreen`'e dusuyordu. Guncellemeden sonraki ilk erisimde
  flutter_secure_storage 10, eski `encryptedSharedPreferences` verisini yeni
  sifreye tasir (`migrateOnAlgorithmChange` varsayilani `true`); yavas TEE'li
  cihazda bu 2 sn'yi asabilir.
- `contactFailed` / `contactTimeout` kurtarma ekranina degil, cikissiz
  `ErrorWidget`'a gidiyordu.

## Karar (sahip onayi, 2026-11-09)

Kalici bozulmada "PIN'imi unuttum" politikasi AYNEN uygulanir: aktif oturum
kontrolu + `SIFIRLA` yazili onay + tam yerel silme (kisiler dahil). Kisileri
koruyan PIN yeniden belirleme yolu YOK: PIN'i bilmeyen birine uygulamayi ve kisi
listesini acardi. Ayrica en olasi kalici hata (Keystore anahtar kaybi) kisileri
de cozulemez kilar; korunacak veri zaten kalmaz.

## Yapilan

- `PinStorageReadPolicy`: 3 deneme, 300 ms / 900 ms geri cekilme. Herhangi bir
  deneme zaman asimiysa `transientFailure` -> `pinTimeout`; her deneme depolama
  hatasiysa `persistentFailure` -> `pinFailed`. Politika yalnizca okur; PIN
  kaydina yazmaz/silmez, hatayi asla `absent`a cevirmez.
- PIN adimina 10 sn'lik adim butcesi (en kotu durum ~7,2 sn).
- `contact*` hatalari da kurtarma ekranina yonlenir.
- Ekran metni nedene gore: `pinFailed` veri kaybini sifirlamadan once acikca
  anlatir; `pinTimeout` eski metni korur; `contact*` kisileri adlandirir.
- Ekrandaki 13 sabit metin ceviri anahtarina tasindi (TR metinler ayni).

## Kanit

- `docs/audit/evidence/pin-storage-recovery-2026-11-09/red_run.txt` — duzeltme
  oncesi: 9 test kirmizi (beklenen nedenlerle), 11 koruma testi yesil.
- `.../green_run.txt` — duzeltme sonrasi ayni dosyalar: 28/28 yesil.
- `.../analyze.txt`, `.../analyze_strict.txt` — `flutter analyze --no-fatal-infos`
  ve `flutter analyze`: ikisi de "No issues found".
- `.../full_test_main_checkout.txt` — ana kopyada tam paket (reviewer
  duzeltmelerinden once): 2830 gecti, 2 kirmizi. Ikisi de
  `release_change_classification_test`; tek neden izlenmeyen `marketing/`
  (926 `UNCLASSIFIED_PATH`, hepsi `marketing/` altinda). Kod kusuru degil,
  `marketing/`'e dokunulmadi.
- `.../verify_release_clean_worktree.txt` — kod commit'i `de31e31` uzerinde,
  `marketing/` olmayan temiz worktree'de `scripts/verify_release.sh`
  (analyze, tam test + kritik coverage, imzali smoke AAB, Android lint +
  Kotlin unit + instrumentation derleme, 16KB, lisans/notices).

## Bilinen sinir

- Kritik baslatma sirasinda `LocalLoggerService` henuz baslatilmamis oldugu icin
  (baslatma `startup_best_effort_services` icinde, bootstrap'tan sonra) deneme
  sayisi ve hata turu kalici loga yazilmiyor. Baslatma sirasini degistirmek
  `main_startup_init_order_test` sozlesmesini degistirmeyi gerektirir; bu iste
  yapilmadi.
- Calisma zamanindaki PIN okumalarina (geri sayim, kilit ekrani) tekrar deneme
  eklenmedi: oraya bekleme eklemek aramayi geciktirebilir.

## Cihazda dogrulanmasi gerekenler (YAPILMADI)

Bu notu yazan oturum hicbir cihazda/emulatorde calistirmadi. Kosulacak adimlar
(her sonuc AVD/cihaz, yogunluk, olculen commit ve
`adb shell dumpsys package <id> | grep lastUpdateTime` ile build kimligiyle
kaydedilmeli):

1. Guncelleme yolu: `encryptedSharedPreferences: true` kullanan eski bir build
   (or. `ca2af0d`..`6d00076` arasi) kur, PIN + kisi ekle, bu build'i ustune kur;
   ilk acilista ana ekrana PIN kilidiyle gelindigini ve kisilerin durdugunu dogrula.
2. Kalici hata: `run-as` ile `FlutterSecureStorage` tercih dosyasindaki PIN
   degerini boz (yalnizca debug build); uygulamanin ~1,2 sn + okuma suresi kadar
   bekleyip kurtarma ekranini `pinFailed` metniyle actigini, "Yeniden Dene"nin
   ekranda tuttugunu, `SIFIRLA` ile sifirlamanin PIN kurulumuna dondugunu dogrula.
3. Anahtar kaybi: cihazda ekran kilidini kaldirip yeniden kur (bazi Samsung
   modellerinde Keystore anahtarlarini gecersiz kilar); ayni akisi gozle.
4. Kisi deposu hatasi: yalnizca `emergency_contacts_v1` degerini boz; ErrorWidget
   yerine kurtarma ekraninin acildigini dogrula.
5. Aktif oturum: Kontrol Noktasi kuruluyken 2. adimi tekrarla; sifirlamanin
   "Aktif bir guvenlik oturumu varken sifirlama yapilamaz." ile reddedildigini dogrula.
