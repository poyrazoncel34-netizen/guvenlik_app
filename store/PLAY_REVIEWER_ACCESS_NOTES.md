# Play Console — App access / incelemeci notu

Bu dosya **Play Console → App content → App access** alanına ve gerektiginde
inceleme notlarina yapistirmak icin hazirlandi. Amaci tek bir somut riski
kapatmak: incelemeci uygulamayi acip **calistiramadigi veya goremedigi** icin
"temel islevsellik dogrulanamadi" gerekcesiyle red yazmasi.

Bu risk KoruBeni'de uc bagimsiz nedenin ust uste binmesinden dogar:

1. **Panik/SOS Pro'nun arkasinda.** Incelemeci uygulamanin mansetteki
   ozelligine satin alma yapmadan ulasamaz.
2. **Release build'de `FLAG_SECURE` acik** (MainActivity, duress modeli geregi).
   Ekran cihazda tamamen gorunur ama ekran goruntusu / ekran kaydi siyah cikar;
   Pre-launch report gorselleri de siyah gelir.
3. **Uygulama yalniz Turkce.** `localeFilters = ["tr"]`, `supportedLocales`
   yalniz `tr_TR`. Ingilizce cihazdaki incelemeci arayuzu okuyamaz.

Ucu tek tek zararsiz, birlikte incelemeciyi kor birakir.

---

## Yapilacaklar (operator)

- [ ] **App access** = "All or some functionality is restricted" secilip
      asagidaki metin yapistirilir.
- [ ] Play Console → Monetize → Subscriptions → **promo kod** uretilip
      metindeki `<PROMO_CODE>` yerine yazilir (yoksa satir silinir ve
      License testing tercih edilir).
- [ ] Play Console → Setup → **License testing**: inceleme/tester hesaplari
      eklenir; boylece satin alma ucretsiz test satin almasi olur.
- [ ] Store listing **varsayilan dili Turkce** olarak ayarlanir (uygulama
      Turkce-only; varsayilan dil Ingilizce kalirsa metadata uyusmazligi olur).

---

## YAPISTIRILACAK METIN (TR + EN)

```
No account, login, or developer backend is required. The app is offline-first.
Hesap, giris veya gelistirici sunucusu gerekmez. Uygulama offline-first calisir.

--- FIRST RUN / ILK CALISTIRMA (~90 sn) ---
1. Consent screen: tick the required boxes and select the 18+ declaration.
   Onay ekrani: zorunlu kutulari isaretleyin, 18+ beyanini secin.
2. Onboarding: 4 info pages, then a required emergency-contact step.
   Grant the contact-data consent card first, then type ANY name and ANY
   valid phone number (7-15 digits, e.g. +90 555 000 00 00). This step
   cannot be skipped by design: with no reachable contact the app has
   nothing to call.
   Onboarding: 4 bilgi sayfasi, sonra zorunlu acil kisi adimi. Once riza
   kartini onaylayin, sonra herhangi bir isim ve gecerli bir telefon
   numarasi (7-15 hane) girin.
3. The app then requires a 4-digit PIN. Choose any PIN and remember it:
   it is the only unlock method (biometrics are deliberately not supported,
   see the duress note below).
   Ardindan 4 haneli PIN istenir. Herhangi bir PIN secin ve unutmayin.
4. A notification permission prompt follows. Allow it.
   Sonrasinda bildirim izni sorulur; izin verin.

--- FREE FEATURES (no purchase needed) / UCRETSIZ OZELLIKLER ---
- Map / location session   (tab: Harita)
- Fake incoming call       (home: Sahte Arama)
- Siren                    (home: Siren)
- Emergency contacts       (tab: Kisiler)

--- PAID FEATURES / UCRETLI OZELLIKLER ---
Panic/SOS, Safe Walk, Check-in, Safety history, Volume trigger and Test mode
require the optional "KoruBeni Pro" subscription. To evaluate them without a
real charge, redeem this promo code on the paywall screen:
    <PROMO_CODE>
Alternatively the review account can be added to Play Console license testing.
Test mode ("Test Modu", free) runs the full panic flow WITHOUT placing a call.

--- IMPORTANT NOTES / ONEMLI NOTLAR ---
* Screenshots and screen recording are blocked (FLAG_SECURE) in release
  builds. This is a safety requirement, not obfuscation: the protected
  screens are the PIN pad, the emergency contact list and the safety
  timeline, and screen-capturing stalkerware is the exact threat model.
  The screen is fully visible on the device; only capture is blocked.
* The app NEVER dials 112 or any emergency service, and never claims to be
  one. It only calls the phone number the user configured themselves.
  The store listing states this explicitly.
* Biometric unlock is deliberately NOT implemented. An attacker can force a
  finger or face onto a device; a PIN can be withheld. This is intentional.
* The UI ships in Turkish only (tr-TR); the store listing language matches.
* No data is sent to a developer backend. The only outbound traffic is
  optional OpenStreetMap map tiles and Google Play Billing / RevenueCat for
  the optional subscription. No ads, no analytics, no crash-reporting SDK.
```

---

## Neden bu metin

| Satir | Kapattigi red gerekcesi |
|---|---|
| Ilk calistirma adimlari | "Could not get past the setup screens" (Turkce arayuz + zorunlu kisi adimi) |
| Promo kod / license testing | "Core functionality is behind a paywall and could not be verified" |
| FLAG_SECURE aciklamasi | "App blocks screenshots" supheleri + siyah Pre-launch gorselleri |
| 112 aramaz notu | Misleading Claims / acil servis iddiasi supheleri |
| Biyometrik yok notu | "Neden modern kimlik dogrulama yok" sorusu |
| Veri akisi notu | Data safety formu ile arayuz davranisinin celismedigi teyidi |

## Kapsam disi

Bu dosya bir Play Console formunu doldurmaz ve gonderim yapmaz. Promo kod
uretimi, license testing hesaplari ve varsayilan listeleme dili yalniz
operator tarafindan Console'da yapilir.
