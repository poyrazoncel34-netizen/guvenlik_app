# Cihaz dogrulamasi — Android durum geri yukleme (state restoration)

**Tarih:** 2026-08-14
**Cihaz:** `Medium_Phone_API_36.1` emulatoru, arm64, API 36, yogunluk 420 (dpr 2.625)
**Yapi:** `flutter build apk --debug --flavor play --target-platform android-arm64`
**Paket:** `com.poyrazoncel.korubeni`

---

## 1. Neden bu pass yapildi

2026-08-14 a11y/performans passi sunu **kabul edilmis bir sinirlama** olarak kaydetmisti:

> "unsubmitted input does NOT survive true process death (no `RestorationMixin`)"

Bu bir sinirlama degil, **kusurdu**. Flutter'in bu is icin birinci sinif bir mekanizmasi var
(`RestorationMixin` + `Restorable*` + kok `restorationScopeId`); uygulama sadece onu hic
benimsememisti. Kaybedilen sey de kozmetik degil: `OnboardingContactStep` onboarding'i
tamamlayabilen **tek** kapidir, dolayisiyla yarim yazilmis acil kisiyi kaybeden kullanici
panik akisi olmayan bir kurulumla kalabilir.

## 2. Kullanilan yordam — ve neden "normal kapatma" ile ayni sey degil

| Adim | Komut | Amac |
|---|---|---|
| 1 | uygulamada kaydedilmemis veri gir | olcum oncesi durum |
| 2 | `adb shell input keyevent KEYCODE_HOME` | uygulamayi arka plana al; Android burada `onSaveInstanceState` calistirir |
| 3 | `adb shell am kill <paket>` | **sistem kaynakli** oldurme. Task kaydi ve saved instance state korunur |
| 4 | `adb shell pidof <paket>` -> bos | surecin gercekten oldugunu KANITLA |
| 5 | launcher intent ile geri don | ayni task'i devam ettir; aktivite savedInstanceState ile yeniden yaratilir |
| 6 | `adb shell pidof <paket>` -> YENI pid | yeni surec oldugunu kanitla |

`am force-stop` **kullanilmadi**: o, kullanici kaynakli sonlandirmadir ve saved instance
state'i siler; onunla test etmek "geri yukleme calismiyor" sonucunu her zaman uretir ve
hicbir sey kanitlamaz.

## 3. Sonuclar

### 3.1 Kaydedilmemis acil kisi formu — GECTI

| | Ad | Telefon | Onboarding sayfasi |
|---|---|---|---|
| oldurme oncesi | `Ayse Yilmaz` | `05551112233` | 5/5 (kisi adimi) |
| pid | 11431 | | |
| `am kill` sonrasi | pid yok | | |
| geri donuste | pid **11843** | | |
| geri yukleme sonrasi | `Ayse Yilmaz` | `05551112233` | 5/5 (kisi adimi) |

Cerceve hatasi: **0**.

### 3.2 NEGATIF KONTROL — ayni yordam, degisiklik ONCESI yapi

Ayni emulator, ayni ekran, ayni komut dizisi; tek fark `git stash` ile geri alinmis
kaynak agaci:

| | Ad | Telefon | Onboarding sayfasi |
|---|---|---|---|
| oldurme oncesi | `Ayse Yilmaz` | `05551112233` | 5/5 |
| geri donuste | **bos** | **bos** | **1/5** |

Cerceve hatasi: 0. Yani eski davranis "sessizce her seyi kaybet" idi. Bu, testin
gecmesinin yordamdan degil **degisiklikten** geldigini kanitlar.

### 3.3 PIN tamponu geri YUKLENMEMELI — GECTI

PIN kurulum ekraninda 4 haneden 2'si girildi (2 nokta dolu), sonra ayni `am kill`
yordami:

- geri donuste PIN ekrani **hic yok**; uygulama kismi PIN'i tasimadi.
- `_pin` bilerek duz bir `String` alanidir; `test/state_restoration_policy_test.dart`
  PIN tasiyan bes dosyada `Restorable` gecmesini yasaklar.

Gerekce: geri yukleme verisi Android'e **saved instance state** olarak verilir. Duress
modelinin tek sirri olan PIN'i oraya yazmak, onu hic bulunmadigi bir depoya tasirdi.

### 3.4 PIN kapisi geri yuklemeden SONRA da uygulanir — GECTI

PIN tanimliyken Ayarlar sekmesindeyken `am kill`:

- geri donuste ekran: **"Uygulama kilidi. PIN ile acin."**
- PIN girildikten sonra: **Ayarlar sekmesi** (geri yuklenmis sekme indeksi)

Yani gezinme durumu korunuyor ama **yalnizca kilidin arkasinda** aciliyor.

### 3.5 Itilen rotalar geri yuklenmiyor — TASARIM GEREGI

`PinSetupScreen` (MainNavigation'in `Navigator.push`'u) oldurme aninda ekrandaydi;
geri donuste yoktu. Kabuk kararini yeniden calistirdi. Bu istenen davranis.

---

## 4. Bu pass sirasinda BULUNAN VE DUZELTILEN kusur

Ilk uygulama denemesi kok `MaterialApp`'e `restorationScopeId: 'korubeni'` koydu.
Geri yukleme calisti — **ve uygulama coktu**. Olculen: `am kill` sonrasi 10 saniye
icinde **28 cerceve hatasi** ve tam ekran hata sayfasi ("Bir sorun olustu").

Zincirin basi tahmin degil, olculdu:

```
navigator.dart:3859  assert(_history.isNotEmpty,
  'All routes returned by onGenerateInitialRoutes are not restorable...')
```
ardindan her karede `framework.dart:2168 '_elements.contains(element)'`.

**Kok neden.** `WidgetsApp` kendi Navigator'una `restorationScopeId: 'nav'` degerini
**kosulsuz** verir; yani durum geri yuklemeyi acmak ROTA gecmisi geri yuklemeyi de acar.
Bu uygulamanin acilisi ise kendi baslangic rotasini yok ediyordu: `SplashScreen` nereye
gidilecegine karar verip `pushReplacement` yapiyordu (ve ayni sey `UnifiedConsentScreen`,
`OnboardingScreen`, kilit ekrani icin de gecerliydi — dort ayri yerde). Geri yuklemede
rotalar dusuruluyor, dusulecek baslangic rotasi da olmadigi icin gecmis **bos** donuyor.

**Reddedilen iki kestirme, ikisi de olculdu:**

1. *Rotalari `restorablePush` ile itmek.* Guvenlik gerekcesiyle reddedildi: kilit ekrani
   `pushReplacement` ile ACILIYORDU, yani yiginin DIBINDE duruyordu; geri yuklenen bir
   rota onun USTUNE eklenir ve PIN kapisi, yaziyi korumak icin eklenen ozellik tarafindan
   atlanirdi.
2. *Kovayi Navigator'un ALTINA almak* (`RootRestorationScope` ekran icinde). Cokusu
   durdurdu — **geri yuklemeyi de durdurdu**: cihazda taslaklar `am kill` sonrasi yine
   yoktu. Cokmemeyi hicbir sey yapmayarak saglayan bir yapilandirma cozum degildir.

**Uygulanan duzeltme:** on kosulun ihlali kaldirildi. `home:` artik `AppRoot` kabugudur;
ust duzey hedefi **durum** olarak degistirir ve rota yiginina hic dokunmaz. `/` hep
yasar ve geri yuklenebilir. Dort `pushReplacement`/`pushAndRemoveUntil` cagrisi da
kabuga geri cagri haline geldi; her biri tek basina mount edildiginde eski davranisini
korur.

Bu, guvenlik acisindan da daha iyi bir sekil: `AppRoot._destination` bilerek geri
yuklenmez, bu yuzden surec olumunden sonra karar (PIN kapisi dahil) bastan calisir.

## 5. Kanitin tekrarlanabilirligi

- `test/screens/state_restoration_test.dart` — davranis + iki negatif kontrol
  (ayni agactaki duz `TextEditingController` geri gelmemeli; kok id olmadan uygulama
  geri yuklenemez olmali). MUTASYON: `restorationId`'yi null yapmak 3 vakanin 2'sini
  kirmistir.
- `test/screens/state_restoration_navigator_precondition_test.dart` — yukaridaki cokusun
  calistirilabilir kaydi. Kok id + kendini degistiren `home:` -> ilk hata
  `_history.isNotEmpty` olmali; kabuk yapilandirmasi -> sifir hata VE taslak geri gelmis
  olmali.
- `test/state_restoration_policy_test.dart` — kok id, `home: const AppRoot()`, PIN
  tasiyan bes dosyada `Restorable` yasagi, `lib/` icinde `restorable*` rota API yasagi.
