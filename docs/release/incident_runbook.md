# KoruBeni — Olay Mudahale ve Yayin Durdurma Kilavuzu

> Bu belge, denetimde **on dorde yakin satirin ortak eksigi** olarak ortaya cikti:
> 67, 75, 77, 78 ve 79. bolumler hep ayni sey yuzunden PARTIAL kaliyordu — yazili
> bir olay proseduru yoktu. Beklenmesi gereken sayfa budur.
>
> **Bu urun icin dogru olan iki gercek, en basta:**
>
> 1. **Telemetri yoktur.** Gelistirici backend'i, analitik ve crash SDK toplama
>    yoktur. Yani bir olay, ancak bir kullanici bildirdiginde ya da Play Console
>    bir crash/ANR gosterdiginde gorunur. "Monitoring neden yakalamadi?" sorusunun
>    kalici cevabi burada bir kez veriliyor, her olayda tekrar degil.
> 2. **Geri alma (rollback) Play'de YOKTUR.** Google Play bir surumu geri
>    alamaz; yalnizca yayilimi DURDURUR ve ileri dogru yeni bir surum
>    yayinlarsiniz. Bu belgede "rollback" her yerde **ileri sarma** demektir.

---

## 1. Siddet modeli

| Siddet | Tanim | Hedef ilk yanit |
|---|---|---|
| **S1 — Guvenlik** | Panik cagrisi baslamiyor, geri sayim silahlanmiyor, acil kisi kaybolmus, PIN kilidi acilmiyor | Ayni gun; yayilim derhal durdurulur |
| **S2 — Veri** | Kullanici verisi kayboluyor veya yanlis yaziliyor (activity_events, riza kaydi, acil kisi) | 24 saat icinde |
| **S3 — Islev** | Guvenlik disi bir ozellik bozuk (harita, prova, tema) | Sonraki surum |
| **S4 — Kozmetik** | Gorsel/metin kusuru | Biriktir |

Bu urunde **cagrilma yolunu geciktiren veya engelleyen her sey S1'dir.**

## 2. Yayilimi durdurma esikleri

The single procedure and proposed numeric thresholds are in
[PRODUCTION_ROLLOUT_RUNBOOK.md](../../store/PRODUCTION_ROLLOUT_RUNBOOK.md), sections 4–6.
**OPERATOR_DECISION_PENDING:** historical thresholds/cadences conflict; see
[operations_decision_pending.md](operations_decision_pending.md). Do not use this
old runbook as an independent release or stop-threshold authorization.

## 3. Yayilimi durdurma proseduru

Use the canonical runbook's first-release/update distinction and forward hotfix
procedure. First releases cannot rely on a previous release or staged rollback.
A confirmed safety defect prevents launch; for an existing release the actual
operator follows the available Console controls. No four-hour recovery time or
operator availability has been measured. Prova status remains PROVA EDILMEDI.

## 4. Odemeyi devre disi birakma (MP-67-009)

Odeme akisi RevenueCat + Play Billing uzerindedir; uygulamada uzaktan
kapatilabilen bir bayrak yoktur (kasitli: uzaktan bayrak, backend demektir).
Devre disi birakma yollari, en hizlidan en yavasa:

1. **RevenueCat dashboard -> Offerings -> mevcut offering'i "current" olmaktan
   cikar.** Paywall o anda satilacak paket bulamaz; `SubscriptionGate` zaten
   paket yoklugunu ele alir ve acil ozellikleri KAPATMAZ.
2. **Play Console -> Monetize -> Subscriptions -> urunu deactivate et.** Yeni
   satin almalar durur; mevcut abonelikler devam eder (Play kurali).
3. Yeni surum: paywall girisini gizle. En yavas yol, cunku inceleme gerektirir.

**Kritik degismez:** odeme kapatilmasi acil cagriyi ETKILEMEZ.
`canUseEmergencyFeature` ticari yetkilendirmeden ayridir ve bu
`test/.../subscription_readiness_state_test.dart` ile pinlidir.

## 5. Guvenlik ve kotuye kullanim bildirim kanali (MP-32-049, MP-65-015/016)

- **Guvenlik acigi bildirimi:** `SECURITY.md` (depo kokunde), genel destekten
  AYRI bir adres.
- **Kotuye kullanim:** bu uygulamada kullanici uretimi icerik, hesap, paylasim
  veya sunucu yoktur. Baska bir kullaniciyi hedefleyebilecek bir yuzey yoktur;
  "kotuye kullanim" burada yalnizca kullanicinin KENDI cihazinda birinin
  uygulamayi zorlamasi anlamina gelir ve buna karsi tasarim yaniti PIN'dir
  (biyometri KESIN OLARAK yasak, CLAUDE.md kural 2).
- **Guvenlik olaylarinin operatore ulasmamasi (MP-78-014/015):** kabul edilmis
  bir sonuctur, kusur degil. Telemetri yok demek, guvenlik olayinin da
  gorunmemesi demektir. Kabul edilen risk burada yazilidir; ceviren sey bir
  kullanici raporudur.

## 6. Destek sureci (MP-77-021)

| Kanal | Ne | Yanit beklentisi |
|---|---|---|
| Play Console yorumlari | ilk temas | 3 is gunu |
| Destek e-postasi (store listeleme) | teshis | 3 is gunu |

First diagnosis requests only app version, Android/device model, approximate incident time, reproduction steps and an allowlisted local error code if available. Do not ask for a full user-data export, raw database, screenshots containing contacts, or free-form diagnostic payloads. Do not collect names, phone numbers, email, PINs or coordinates. User data export remains a separate voluntary personal-data-copy feature, not a support prerequisite. If the user cannot safely obtain a code, proceed with the non-personal reproduction description. No new telemetry is introduced.

## 7. Postmortem sablonu (MP-79-001..005)

Her S1/S2 olayindan sonra bu bes soru yanitlanir ve `docs/audit/` altina
`postmortem-YYYY-MM-DD-<konu>.md` olarak yazilir.

1. **Neden oldu?** Kok neden, semptom degil.
2. **Neden test yakalamadi?** Hangi testin var olmasi gerekirdi. Duzeltmeyle
   AYNI commit'te yazilir (depo kurali).
3. **Neden monitoring yakalamadi?** *Bu sorunun bu uruende kalici cevabi vardir:
   monitoring yoktur.* Her postmortem'de tekrar yazilmaz; buraya bir kez
   yazilmistir. Yanit yalnizca "Play vitals bunu gosterir miydi?" sorusudur.
4. **Neden kullanici yakaladi?** Hangi kullanim yolu testlerin disindaydi.
5. **Ayni bug sinifi baska nerede olabilir?** Ayni sinifi arayan bir tarama
   ya da testin adi. Mutasyon kanidi tercih edilir.

## 8. Prova durumu — DURUSTCE

| Prova | Durum |
|---|---|
| Yayilimi durdurma + ileri sarma | **PROVA EDILMEDI** (MP-77-022, MP-80-017) |
| Odemeyi devre disi birakma | **PROVA EDILMEDI** — RevenueCat hesabi gerekir |
| Anahtar kurtarma | `docs/release/dr_and_key_custody.md` |

Prova edilmemis bir prosedur, prova edilmis gibi sunulmuyor.

---

## 9. Calisma zamani kontrolu: kademeli yayilim (MP-50-012, MP-75-016, MP-27-023)

**Bu projede calisma zamani ozellik bayragi (feature flag) YOKTUR** ve olmayacak: uzaktan
bayrak bir backend demektir (CLAUDE.md kural 1), derleme zamanindaki bir bayrak ise bir
olay sirasinda hicbir ise yaramaz. Bu bir eksiklik degil, kayitli bir urun kararidir
(`PRODUCT_DECISIONS_REQUIRED.md` D-7).

Onun yerine elde ne oldugu burada yaziyor, cunku "bayrak yok" cumlesi tek basina bir olay
sirasinda kimseye yardim etmez.

**Mevcut calisma zamani kontrolu: Play kademeli yayilim yuzdesi.** Kullanilabilir tek
gercek mekanizma budur ve olay proseduru onu bir bayrak gibi kullanir.

| Soru | Cevap |
|---|---|
| Ne yapar | Yeni surumun **kac kullaniciya dagitildigini** belirler: Kanonik runbook §4; owner approval pending |
| Nasil kapatilir | Play Console → Production → **Halt rollout** (§3 adim 1) |
| Ne kadar hizli | Dakikalar; inceleme gerektirmez |
| **Neyi yapamaz** | **Zaten guncellemis bir cihazda hicbir seyi geri almaz veya kapatmaz.** Yalnizca YENI dagitimi durdurur |
| Kimi korur | Henuz guncellememis kullanicilari |

**Bu yuzden esik tablosu (§2) bayragin yerini tutan seydir.** Gercek bir bayrakla "kotu
ozelligi kapat" denirdi; burada "yayilimi durdur ve ileri sar" denir. Ikisi ayni sey degil
ve bu belge bunlari ayni seymis gibi yazmiyor.

**Odeme icin ayri ve daha guclu bir kontrol vardir** — §4. RevenueCat offering'ini "current"
olmaktan cikarmanin istemciye ulasma zamani SDK cache/ag davranisina baglidir; aninda teslim garantisi yoktur. Yani odeme, kademeli
yayilimin aksine, gercekten uzaktan kapatilabilir.

**Degismez:** ne kademeli yayilim ne de odeme kapatma acil cagri yolunu etkiler.
`canUseEmergencyFeature` ticari yetkilendirmeden ayridir (§4).
