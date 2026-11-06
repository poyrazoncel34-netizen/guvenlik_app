# Cift SIM arama hesabi + guncelleyen kuruluma SIM izni — emulator kaniti (2026-11-06)

## Ne olculdu

`1923a6e` (arama hesabi secimi, READ_PHONE_STATE) ve `f80633b` (onceden
CALL_PHONE vermis kuruluma READ_PHONE_STATE'in bir kez sorulmasi).

Guncelleme yolu: READ_PHONE_STATE bildirmeyen eski derleme (`d7ba077`) kurulur,
onboarding tamamlanir, CALL_PHONE verilir; ardindan yeni derleme
`adb install -r` ile ustune kurulur.

## Cihaz ve derleme parmak izi

- AVD: `KoruBeni_Remedy_API35` (`emulator-5560`, `-no-audio`), fingerprint
  `Android/sdk_phone64_arm64/emu64a:15/AE3A.240806.019/12368160:userdebug/test-keys`,
  Physical density 420, 1080x2400.
- Eski APK: `d7ba077`, `flutter build apk --debug --flavor play`,
  sha256 `51eed47f601df36729d6d015dff069039ab24fceb5bb7caaaa61a012de39b4e9`,
  `aapt dump permissions` → READ_PHONE_STATE 0 kez.
- Yeni APK: `f80633b`, ayni komut,
  sha256 `efcbfe8afea0c764fcab096ccb5770e93d5ec9d7f22df7293a5e754411d75b91`,
  READ_PHONE_STATE 1 kez.
- Kurulu derlemenin dogrulanmasi: `dumpsys package com.poyrazoncel.korubeni`
  `lastUpdateTime` eski kurulumda `16:32:39`, guncellemeden sonra `16:34:48`
  ([upgrade-probe-f80633b.md](evidence/sim-selection-2026-11-06/upgrade-probe-f80633b.md)).
- Pro: cevrimdisi Pro capasi root ile yazildi (yalniz test; ticaret kaniti degil).

## Sonuc (13/13 PASS)

| Adim | Sonuc |
|---|---|
| Eski derleme: CALL_PHONE verildi, READ_PHONE_STATE bildirilmemis | PASS |
| Guncelleme sonrasi: CALL_PHONE korunmus, READ_PHONE_STATE `granted=false` | PASS |
| Guncellemeden sonraki ilk acilista "SIM Secimi Izni" aciklamasi | PASS ([ekran](evidence/sim-selection-2026-11-06/01_disclosure_f80633b.png)) |
| "Kabul Et" sonrasi READ_PHONE_STATE `granted=true` | PASS — Android ayrica izin penceresi ACMADI (ayni grupta CALL_PHONE zaten verili) |
| Ikinci acilista yeniden sorulmuyor; `pref_sim_selection_offered` yazili | PASS |

Duzeltme oncesi derleme `7e36d91` de ayni probta 13/13 gecti
([upgrade-probe-7e36d91-prefix.md](evidence/sim-selection-2026-11-06/upgrade-probe-7e36d91-prefix.md)).
Bu oturumdaki ilk iki FAIL, prob kurulumundan kaynaklandi: `adb root` acik
olmadigi icin Pro capasi yazilamamisti ve Pro olmayan kuruluma tasarim geregi
hicbir sey sorulmuyor. `f80633b`'deki kilit bekleme degisikligi cihazda yeniden
uretilmis bir hatayi duzeltmiyor; PanicReadinessSetup ile ayni sozlesme olarak
birim testle sabitlendi.

## Kanitlanamayanlar

- Emulator cift SIM ve "her seferinde sor" ayarini gercekci taklit etmiyor. SIM
  secme penceresinin kilitli ekranda artik acilmadigi yalnizca AOSP kaynagi
  (CallsManager `needsAccountSelection`) ve Robolectric testleriyle
  (`AndroidEmergencyCallRequesterTest`) gosterildi. Gercek cift SIM cihazda
  dogrulanmasi GEREKIR.
- Release imzali derleme ile guncelleme olculmedi; debug -> debug (ayni imza).
