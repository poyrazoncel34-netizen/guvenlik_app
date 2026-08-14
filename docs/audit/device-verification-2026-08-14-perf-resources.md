# Cihaz dogrulamasi — 2026-08-14, kaynak kullanimi (bellek / CPU / ag / termal)

**Cihaz:** emulator `Medium_Phone_API_36.1`, arm64, API 36, 1080x2400 @ 420 dpi (dpr 2.625)
**Yapi:** `flutter build apk --profile --flavor play --target-platform android-arm64`
**Amac:** 41. bolumun kaynak satirlarini "hic olculmedi"den gercek sayilara tasimak.

---

## 0. Bu kosumun DURUSTCE olcemedigi seyler

Bunlari once yaziyorum, cunku bir olcum belgesinin en kolay yalani atlanan
oleumu hic anmamaktir.

| Ne | Neden olculemedi |
|---|---|
| **Gercek pil tuketimi** | Emulator batarya modeli sanal: `Computed drain: 0, actual drain: 0`. Emulatorde olculen bir mAh sayisi gercek donanim hakkinda hicbir sey soylemez. |
| **Termal kisitlama** | `Thermal Status: 0`, sabit; deri 30.1 C, batarya 30.2 C. Emulatorde termal kisitlama TETIKLENEMEZ. |
| **GPU is yuku** | `Graphics: 0 kB` — emulator host GPU'sunu kullaniyor, bu yuzden uygulamaya atfedilen GPU bellegi sifir okunuyor. Bu bir olcum degil, olcumun yoklugu. |
| **Bu kosumda kare sureleri** | `dumpsys SurfaceFlinger --latency` yalnizca tazeleme periyodunu (16.666 ms) dondurdu, kare satiri dondurmedi; katman kimligi (`#1386`) her surec baslangicinda degisiyor. Kare kanidi 2026-08-14 a11y/perf kosumundadir (744 aralik) ve o kosumun agacina bagli olarak alintilanir. |

---

## 1. Soguk baslatma

```
adb shell am start-activity -W -n com.poyrazoncel.korubeni/.MainActivity
LaunchState: COLD
TotalTime: 4755 ms   WaitTime: 4825 ms
```

Bu bir PROFILE yapinin TEMIZ KURULUM sonrasi ILK acilisi: JIT onbellegi yok,
`.dex` optimizasyonu yapilmamis, riza/onboarding kapisi calisiyor. Kararli hal
soguk baslatma sayisi degildir ve oyle sunulmuyor.

## 2. Bellek — sizinti imzasi aranarak

| Olcum | t0 (acilistan 8 sn sonra) | t1 (28 kaydirma sonrasi) | Delta |
|---|---|---|---|
| TOTAL PSS | 169 803 kB | 175 138 kB | **+5 335 kB** |
| TOTAL RSS | 280 320 kB | 286 536 kB | +6 216 kB |
| Native Heap | 28 824 kB | 30 204 kB | +1 380 kB |
| Dalvik Heap | 5 432 kB | 2 664 kB | −2 768 kB (GC calisti) |
| **Views** | **7** | **7** | **0** |
| **Activities** | **1** | **1** | **0** |
| **AppContexts** | **5** | **5** | **0** |
| WebViews | 0 | 0 | 0 |

**Okunmasi gereken sey delta degil, sayimlar.** Bir Flutter uygulamasinda
sizinti View sayisinda degil Dart nesnelerinde birikir; ama `Activities` ve
`AppContexts` sabit kalmasi, en agir Android sizinti sinifinin (tutulan
Activity baglami) OLMADIGINI gosterir. PSS'deki +5 MB, GC'nin Dalvik yiginini
5 432 -> 2 664 kB'ye dusurdugu ayni pencerede olustu: bu, buyuyen bir sizinti
degil, native raster onbelleginin isinmasi.

Bu, dinlenmedeki mutlak ayak izi hakkinda gercek donanim yerine gecmez; ama
"kaydirma bellek sizdiriyor mu" sorusuna **hayir** cevabini verir, ve o soru
emulatorde yanitlanabilir.

## 3. CPU

```
top:      0.0% CPU, 280M VIRT / 184M RES   (etkilesim sonrasi bosta)
cpuinfo:  0.2% (0.1% user + 0% kernel)
```

Bosta duran panik ekrani olcumun yapildigi anda islemciyi mesgul etmiyor.
Bu, bugun duzeltilen kusurla dogrudan ilgili: yedi ekran platformun
"animasyonlari kaldir" tercihini yok sayarak sonsuz dongu calistiriyordu;
o donguler artik tercih sorulduktan sonra basliyor.

## 4. Ag — urunun temel iddiasi

`dumpsys netstats detail`, uygulama uid'i icin **acil yol boyunca kayit
uretmedi**. Kayitli tum trafik varsayilan agda sistem uid'lerine ait.

Bu satirin asil kaniti calisma zamani degil kaynak: acil yol
(`panic_button` -> `countdown_screen` -> `emergency_platform_service`) hicbir
HTTP istemcisi cagirmaz. Ag yalnizca istege bagli katmanlarda: harita dosemeleri
ve RevenueCat. Bu, `docs/audit/evidence/storage.json` ve
`docs/audit/evidence/flows.json` icinde ayrica kayitli.

## 5. Termal ve pil — olculemedi, tahmin edilmedi

```
Thermal Status: 0 (NONE), sabit
Temperature{mValue=30.2, battery}  Temperature{mValue=30.1, skin}
Estimated battery capacity: 3000 mAh, Computed drain: 0, actual drain: 0
```

Ikisi de gercek donanim gerektirir. Bu satirlar EXTERNAL_BLOCKER'a tasindi;
emulatorden bir sayi uydurup "olculdu" demek, olcmemekten daha kotudur cunku
bir sonraki okuyucuyu yanlis bir guvenle birakir.

## 6. Bildirim kesintisi

`POST_NOTIFICATIONS` bu kosumda `adb shell pm grant` ile verildi (onceki
kosumda reddedilmisti, bu yuzden kesinti hic denenmemisti). Silahlanmis bir
oturum sirasinda bildirim kesintisinin TAM dogrulanmasi gercek bir cagri
gerektirir (lisansli test hesabi + fiziksel cihaz), bu yuzden bu satirin
kalintisi disaridadir; izin durumunun artik verilebilir oldugu kayitlidir.

## 7. Yeniden uretme

```bash
bash scripts/measure_device_resources.sh
```
