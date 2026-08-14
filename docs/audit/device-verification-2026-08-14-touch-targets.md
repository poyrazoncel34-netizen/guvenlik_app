# Cihaz dogrulamasi — dokunma hedefi geometrisi (Android 48 dp)

**Tarih:** 2026-08-14
**Cihaz:** `Medium_Phone_API_36.1`, arm64, API 36, yogunluk 420 (dpr 2.625)
**Olcum araci:** `adb shell uiautomator dump` -> gercek semantik dugum sinirlari.
Ikon boyutundan CIKARIM YOK; onceki passin kucuk hedefleri kacirmasinin sebebi
tam olarak buydu.

---

## 1. Olcum metodolojisi — ve once duzeltilmesi gereken hata

uiautomator **KIRPILMIS** dikdortgeni bildirir. Kaydirma penceresinin kenarina
denk gelen bir kontrol oldugundan kisa okunur. Bu, uydurma kusur uretir:

| Kontrol | Pencere kenarinda | Tam gorunurken |
|---|---|---|
| "Detayi Gor" (riza ekrani) | 115.8 x **26.3** dp | 115.8 x **48.0** dp |
| "Yasal Bilgiler & KVKK" satiri | 371.4 x **23.2** dp | 371.4 x **74.3** dp |

Ikisi de ayni kosumda, ayni yapida, sadece 300 px kaydirma farkiyla olculdu.

**Bu, onceki passin "yaklasik 23.2 dp'lik iki hedef" bulgusunun yarisini
gecersiz kilar.** `test/screens/touch_target_geometry_test.dart` icindeki
`Target('Yasal Bilgiler & KVKK satiri', 371.4, 23.2, ...)` satiri yanlisti ve
duzeltildi. Diger yari (22.1 dp'lik onam kutusu) gercekti.

Olcum betigi (`sweep.py`) artik her dugumun en yakin kaydirilabilir atasini
bulur ve o pencerenin kenarina degen dugumleri **CLIPPED / yeniden olc** diye
isaretler — ne gecmis ne kalmis sayar.

## 2. Bulunan ve duzeltilen gercek kusurlar

| Kontrol | Once | Sonra | Nasil |
|---|---|---|---|
| Cevrimdisi Mod banneri | 411.4 x **24.0** dp, **ERISILEMEZ** | 411.4 x **67.0** dp, dokunulabilir | icerik + vurus alani durum cubugunun ALTINA alindi (`viewPadding.top`) |
| Kisi onam modali onay kutusu | 22.1 x 22.1 dp | 283.4 x 77.0 dp (tek dugum) | `MergeSemantics` |
| Riza onay kutusu (5 ornek) | ic ice 24.0 x 24.0 dp | 371.4 x 82.3 dp (tek dugum) | `MergeSemantics` |
| Hazirlik cipi x5 | 90.7 x **30.9** dp | 90.7 x **48.0** dp | `MinimumTapTarget` |
| Prova satiri | 329.1 x **38.1** dp | >= 48 dp | `ConstrainedBox(minHeight: 48)` |
| Ayarlar switch | 51.0 x **40.8** dp | 60.2 x **48.0** dp | `MinimumTapTarget` |
| Riza yonetimi switch | 51.0 x **28.2** dp | 60.2 x **48.0** dp | `MinimumTapTarget` |

**Hicbir gorsel oge buyutulmedi.** Cip hala 30.9 dp yuksekliginde ciziliyor,
onay kutusu hala 24 dp, switch hala 0.85 olcekli. Buyuyen sey yalnizca
etkilesim ve semantik alan.

### 2.1 Banner: kucuk degil, hic dokunulamiyordu

Bu, boyut olcumunun yan urunu olarak bulundu. Banner `[0,0][1080,63]` sinirlari
ile bildiriliyordu, yani tamamen sistem durum cubugunun altinda. Dogrulama:
`adb shell input tap 540 <y>` ile y = **10, 31, 55, 62** — dordu de diyalogu
acmadi. Etiketi de sistem saatinin yaninda duruyordu.

Sebep: banner `SafeArea(bottom: false)` icindeydi ama bir ata `padding`'i zaten
tuketmisti, dolayisiyla SafeArea sifir inset olcup hicbir sey yapmiyordu.
Duzeltme `viewPadding.top` okur — o tuketilmez. Sonrasinda y = 140'a dokunmak
diyalogu aciyor (ekran goruntusu kayitli).

### 2.2 Switch: `Transform.scale` vurus alanini da kuculttu

`Transform.scale(scale: 0.85)` pikselleri ile birlikte HIT-TEST bolgesini de
olcekler, yani Material'in hazir 48 dp hedefi 40.8 dp'ye iniyordu. Bu, cerceve
testinde de yakalandi — ama ancak olcum GLOBAL koordinata cevrildikten sonra:
`SemanticsNode.rect` dugumun KENDI uzayindadir ve donusumden once 48 dp
bildirir. Harness once o yerel degeri okuyup kusurlu switch'i "uyumlu" ilan
etti; cihaz 40.8 dedi ve cihaz hakliydi. `interactiveSize` artik
`tester.getRect` (global) kullanir.

## 3. Kapanis olcumleri (ekran ekran)

```
[consent-top]           pass=3  under=0
[consent-mid]           pass=5  under=0
[onboarding-p1]         pass=2  under=0
[onboarding-contact]    pass=4  under=0
[contact-consent-dialog] pass=2 under=0
[pin-setup]             pass=12 under=0
[battery-wizard]        pass=5  under=0
[home]                  pass=15 under=0     (once: pass=8 under=6)
[map]                   pass=2  under=0
[contacts]              pass=2  under=0
[settings]              pass=11 under=0
[legal-settings]        pass=8  under=0
[consent-management]    pass=5  under=0
```

## 4. Regresyon bari

`test/screens/touch_target_minimum_size_test.dart` ayni seyi cihazsiz olcer
(global `tester.getRect`), boylece gerileme CI'da yakalanir:

- `MinimumTapTarget` gorseli BUYUTMEDEN 48 dp'ye cikarir (artwork 20x20
  kalmali diye ayrica assert edilir);
- buyutulmus kenar bosluguna dokunmak geri cagriyi tetikler — yalnizca
  `Semantics` ile yapilan bir "duzeltme" boyut assert'ini gecer ama bu vakayi
  gecemez;
- NEGATIF KONTROL: sarilmamis 0.85 olcekli switch 48 dp'nin ALTINDA olmali;
- NEGATIF KONTROL: sarilmamis 20 dp'lik kontrol 48 dp'nin ALTINDA olmali;
- riza satiri platforma TEK dokunulabilir dugum vermeli
  (`isMergedIntoParent` ile olculur).
