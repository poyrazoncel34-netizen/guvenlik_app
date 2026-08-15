# C5/C6/C7 — gelen cagri on ucusu (emulator), 2026-08-15

Bu bir ON UCUS kaydidir. `store/REAL_DEVICE_QA_MATRIX.md` C5, C6 ve C7 satirlari
bu kayitla **gecmez**; hepsi `NEEDS_REAL_DEVICE_TEST` olarak kalir.

Kosum: `ANDROID_SERIAL=emulator-5554 ./scripts/phase3_incoming_call_preflight.sh`

## Ortam

| Alan | Deger |
|---|---|
| Cihaz | `sdk_gphone16k_arm64` (Android emulator, AVD `KoruBeni_API36_16k_ctrl`) |
| API | 36 |
| Paket | `com.poyrazoncel.korubeni` (play flavor, **debug** build) |
| versionName / versionCode | `1.0.0` / `1` |
| Build revizyonu | `a5d2eaa` |
| Tarih | 2026-08-15 |

## On kosul sonuclari

| # | On kosul | Sonuc | Nasil olculdu |
|---|---|---|---|
| 0 | Emulator kimligi | PASS | `ro.product.model`, `ro.kernel.qemu` |
| 1 | Amaclanan APK kurulu | PASS | `pm list packages` + `dumpsys package` versionName/versionCode |
| 2 | Uygulama sureci calisiyor | PASS | `pidof` = 5162 |
| 3 | **Geri sayim gercekten armli** | **FAIL** | cihaz-korumali `korubeni_emergency_session_v1.xml` **hic yok** |
| 4 | **Simule cagri Android cagri durumuna ulasiyor** | **PASS** | `dumpsys telephony.registry` `mCallState` 0 -> **1 (RINGING)** -> 0 |

## 3 numarali on kosul neden saglanmadi -- ve bu neden bir kusur degil

Onboarding makineyle bastan sona surulda (onam -> tanitim -> acil kisi
`QA / 5559876543` -> PIN -> bildirim izni -> pil adimi), `CALL_PHONE` adb ile
verildi ve ana ekrana ulasildi. SOS butonu orada **kilitli**:

```
Kilitli SOS butonu / SOS / Kilitli · Provasini ucretsiz calistir / PRO
```

Butona dokunmak geri sayimi baslatmiyor ve cihaz-korumali oturum deposu
OLUSMUYOR bile:

```
$ adb shell run-as com.poyrazoncel.korubeni ls /data/user_de/0/.../shared_prefs/
ls: ... No such file or directory
```

Yani panik akisi entitlement kapisinda fail-closed davraniyor. Bu, dogru
davranistir ve `MP-41-017`'nin adlandirdigi dis bagimliligin ta kendisidir:
gercek bir armli dispatch'e ulasmak icin **Play internal-test lisansli test
hesabi** gerekir. On ucus bu bagimliligi artik iddia etmiyor, **olcuyor**.

**Test Modu kullanilmadi.** Ana ekranda "Test Modu (gercek arama yapilmaz)"
dugmesi var ve geri sayim ekranini acardi -- ama `countdown_screen.dart`
icinde `widget.isTestMode` dali native oturumu ARMLAMADAN dogrudan Dart
sayacini baslatir. Test Modu ile alinacak bir ekran goruntusu "geri sayim
gercekten armli" on kosulunu **karsilamaz**; onu PASS saymak tam olarak bu
denetimin kaldirmaya calistigi turden sahte kanit olurdu.

## Ne kanitlandi

1. Emulator telefon simulasyonu **gercekten** Android cagri durumuna ulasiyor
   (`mCallState=1`), yani C5/C6/C7'nin enstrumantasyonu calisir durumda ve
   operatorun kesintiyi tetiklemek icin ucuncu bir telefona ihtiyaci olup
   olmadigi artik olculebilir bir soru.
2. Hat kosum sonunda bosa donuyor (`mCallState=0`), yani ardisik kosumlar
   birbirini kirletmiyor.
3. Armli dispatch'e ulasmanin onundeki tek engel entitlement kapisi -- kod
   kusuru, izin eksigi ya da eksik kisi degil.

## Ne kanitlanmadi

- Fiziksel cihaz davranisi, OEM pil politikalari, gercek Telecom yigini.
- Armli geri sayim sirasinda gelen cagrinin gercek etkisi (3 numarali on kosul
  saglanmadigi icin senaryonun kendisi **hic kosulmadi**).
- `adb emu gsm call` gercek bir sebeke cagrisi degildir.

C5, C6 ve C7 bu nedenle lisansli test hesabi + fiziksel cihaz ile kosulana
kadar `NEEDS_REAL_DEVICE_TEST`.
