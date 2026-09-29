# Open release blockers

Bu liste ayni eksigi farkli isimlerle saymaz. Inventory ID kumeleri ile
cross-cutting kabul akislari ayri yazilir ve toplanmaz.

## Stage 5 — fiziksel cihaz

54 benzersiz `A4-fiz` ID aciktir:

```text
BOOT-01 BOOT-02 BOOT-05 BOOT-09 BOOT-10 ONB-09 YDK-03 NAV-06 HOME-05
HOME-06 HOME-08 HOME-13 HOME-16 GS-16 HZ-01 HZ-03 NTV-01 NTV-29 NTV-30
NTV-31 NTV-32 NTV-33 NTV-37 BLD-01 BLD-02 BLD-03 BLD-05 FKC-03 FKC-04
FKC-07 FKC-12 SRN-01 SRN-02 SRN-04 KSI-04 KSI-12 MAP-01 MAP-03 MAP-04
MAP-07 PIL-01 PIL-03 PIL-06 OEM-01 OEM-02 BLK-01 BLK-02 PRM-02 HATA-03
HATA-04 HATA-10 HATA-11 HATA-14 HATA-18
```

Emulator/mock evidence bu fiziksel siniri kapatmaz.

## Stage 6 — Play, RevenueCat ve legal

- 99 benzersiz `A5-play` ID icin gercek Play/RevenueCat islem kaniti yok:
  `PLAY_RC_PROVEN=0`, `PLAY_RC_UNVERIFIED=99`.
- Internal/closed track, license tester, dashboard product/base-plan/offer,
  entitlement, satin alma/restore/cancel/pending/expiry zincirleri acik.
- Canli `kullanim_sartlari.html` uygulamadaki Terms 4.0.0 ile uyusmuyor:
  `LEGAL_URLS=FAIL`. `RIZA-13` gorsel olarak tamam, external legal paritesi acik.
- Play Console URL alanlari ve store copy gercek dashboard'da dogrulanmadi.
- RevenueCat/Google Play veri aktarimi icin imzali KVKK counsel sonucu yok:
  `KVKK_COUNSEL=BLOCKED`.

## Stage 7 — fiziksel TalkBack

Gorsel/emulator/production-widget kapsami `116/116`; `VISUAL_UNTESTED=0`.
Fiziksel TalkBack'te 11 ana akis acik: onboarding, PIN, home, panic,
countdown, contacts, Check-In, SafeWalk, paywall, settings, data deletion.
Bu akislar inventory kumelerine cross-cutting oldugu icin 54/99'a eklenerek
benzersiz ID toplami uretilmez.

## Kaynak ve artifact durumu

- COMMIT_1-11 sonrasi tracked kaynak adayi kayitlidir:
  `SOURCE_FROZEN_SHA=c034731ced73cedc071fa76a800ca6a32a9c4789`.
- COMMIT_12 SHA'si belgeye tahmin edilerek yazilmaz; commit sonrasinda dis
  raporda verilir.
- Kaynak adayi SHA'sina bagli production-signed Play AAB yok:
  `PRODUCTION_AAB=BLOCKED`.
- Matrixte 15 `ULAŞILAMAZ / ÖLÜ` satir urun karari bekler. Bunlar dis cihaz
  blocker'i diye yeniden sayilmaz; `OPEN=169` muhasebesine dahildir.
