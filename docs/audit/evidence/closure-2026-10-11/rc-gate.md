# RC kapisi — RELEASE_CANDIDATE_HEAD `5aa3fe9` (2026-10-11)

Onceki RC `1b76466` (uygulama kodu `cdc4024` ile ayni). Bu kapanista uygulama
kodu DEGISTI, bu yuzden eski RC'nin hicbir kaniti tasinmadi; her sey bu HEAD'de
yeniden uretildi.

## Commit'ler

| Commit | Ne |
|---|---|
| `e4c8668` | OD-1 — 5 dk vade politikasi tek karar fonksiyonunda, monotonik saat yetkisi, OD-1c |
| `ed2885a` | OD-2 — gorunur "Arka Plan Koruması" adimi, tek readiness hukmu |
| `13972b0` | LR-1 — konum metinleri kaynakla eslesti, yasal surum bump'i |
| `5aa3fe9` | Inceleme bulgulari — arm() saat sapmasi (HIGH), kanitsiz duvar ezmesi, adim durum metni |

## Yerel kapilar

| Kapi | Sonuc |
|---|---|
| `scripts/verify_release.sh` | **LOCAL_CANDIDATE_PASS** — 6/6 kapi |
| temiz yerel build zemini | PASS |
| `flutter analyze --no-fatal-infos` | PASS, 0 sorun |
| `flutter test` + kritik safety coverage | PASS — **2612** test |
| imzali smoke AAB + birlesik Android release yuzeyi | PASS |
| Android lint + Kotlin unit + instrumentation derlemesi | PASS — Kotlin unit **216/216** |
| 16 KB sayfa hizalamasi | PASS — 8/8 native kutuphane |
| etiketli-yayin lisans/notices paritesi | PASS |
| Karsi-olgusal mutantlar (OD-1, OD-2, LR-1, inceleme) | **0 survivor**, agac hash ile geri yuklendi |

Dis kapilar: `EXTERNAL_RELEASE_GATES_UNVERIFIED`.
Etiketli yayin: `TAGGED_RELEASE_GATES_LOCAL_PASS`.

## Artefakt ozetleri

Bkz. `artifact-hashes.txt`. Smoke AAB `.smoke` paket kimligiyle derlendi ve
**Play'e yuklenemez**; yalnizca kod/build/lint/16KB kapilarinin kanitidir.

## Cihaz kanitlari (hepsi bu HEAD'in derlemesiyle)

Her kosum once APK'nin degisikligi TASIDIGI dogrulanarak yapildi. Bu kapanista
bir kosum eski bir APK'ya karsi yapilip iki anlamsiz FAIL uretti; `lr1_copy_runtime.py`
artik degisikligi tasimayan bir derlemede kosmayi REDDEDIYOR.

| Proba | Sonuc |
|---|---|
| OD-1 cihaz probasi, API 36, 10 mod | **10/10 OK, 0 FAILURES** |
| OD-2 taze kurulum probasi, API 36, 12 adim | **12/12 PASS** |
| OD-1 cihaz probasi, API 35, 10 mod | **10/10 OK, 0 FAILURES** |
| OD-2 taze kurulum probasi, API 35, 12 adim | **12/12 PASS** (ilk kosum 6/12 idi; sebebi proba, bkz. `od2-ledger.md`) |
| OD-2 regresyon kontrolu, API 29 | **6/6 PASS** — adim "acik" diyor, CTA cikmiyor |
| OD-1 duvar saati saldirisi, gercek 2 sa Check-In, API 36 | **9/9 PASS** — elapsed vade (13097163) alti saldiri boyunca hic oynamadi |
| LR-1 veri akisi envanteri, API 36 | tcpdump + izin-geri-alma; Harita acilmadan OSM 0, ham koordinat yok |
| LR-1 duzeltilmis metin, API 36 | 6/7 — tek kirmizi PROBA kusuru, uygulamanin degil (bkz. `lr1-copy-runtime-api36.md`) |

### LR-1 adim 3 hakkinda

Proba "konum disindaki her kutuyu isaretle" yaklasimini kaydirmali bir ekranda
guvenilir sekilde yapamadi ve ZORUNLU Kullanim Sozlesmesi kutusunu isaretsiz
birakti; CTA dogru sekilde devre disi kaldi ve hicbir sey olmadi. Kaynak
tamamlamanin yalnizca `_canProceed = yas && EULA && KVKK` ile kapiliandigini
gosteriyor (`unified_consent_screen.dart:63-64`) — konum orada yok.

Ozellik artik cihaz probasina degil, cururmeyecegi yere sabitlendi:
`test/screens/unified_consent_behavior_test.dart`, "LR-1: declining the optional
location consent still completes setup" — gercek `UnifiedConsentScreen`'i surer,
CTA'nin yalniz uc zorunlu madde ile etkinlestigini ve reddin `false` olarak
KAYDEDILDIGINI dogrular. Bu, LR-1'in surum bump'i yuzunden onemli: bump mevcut
tum kullanicilari bu ekrana, istege bagli onaylar isaretsiz halde geri
gonderiyor.
