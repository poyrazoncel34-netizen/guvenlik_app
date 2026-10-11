# LR-1 Phase A — gercek veri akisi envanteri (2026-10-11)

Hicbir hukuki metne dokunulmadan ONCE cikarildi. Her satir ya KAYNAKTAN ya da
CIHAZDAN olculdu; "kaynak diyor ki" ile "cihazda gorundu" ayri tutuldu.

## Tablo

| Veri | Kaynak | Yerel saklama | Ag hedefi | Ne zaman | Amac | Kullanici baslatir mi | Istege bagli mi | Saklama | Ucuncu taraf |
|---|---|---|---|---|---|---|---|---|---|
| Hassas GPS (lat/lng) | `geolocator` | **Yok** (yalniz bellek) | **Yok** | yalniz Harita ekrani acikken | kendi konumunu haritada gostermek | Evet (Harita sekmesi) | Evet | ekrandan cikinca biter | Yok |
| Kaba GPS | ayni | Yok | Yok | ayni | ayni | Evet | Evet | ayni | Yok |
| Harita goruntuleme alani (karo z/x/y) | harita gezinmesi | karo onbellegi (uygulamaya ozel) | **`tile.openstreetmap.org`** | yalniz Harita acikken | karo indirmek | Evet | Evet | HTTP cache direktifi, yoksa 7 gun; 128 MiB tavan | **OSMF** |
| IP + User-Agent | ag yigini | Yok | `tile.openstreetmap.org` | karo istegi sirasinda | baglanti | Evet (Harita acarak) | Evet | OSMF politikasi | **OSMF** |
| Acil kisi (ad, numara) | kullanici / sistem secici | `flutter_secure_storage` `emergency_contacts_v1` | **Yok** | kullanici ekleyince | arama akisi | Evet | Hayir (panik icin gerekli) | kullanici silene kadar | Yok |
| Aktif oturum hedefi | acil kisi | device-protected prefs (token/son tarih/normalize numara) | **Yok** | oturum silahliyken | reboot/Doze kurtarma | Evet | — | terminal duruma kadar; iptalde hemen | Yok |
| PIN | kullanici | hash'li, secure storage | **Yok** | kurulumda | uygulama kilidi | Evet | Hayir | degistirene kadar | Yok |
| Zaman cizelgesi | uygulama | sqflite `activity_events` | **Yok** | olay aninda | kullanici gecmisi | — | — | cihaz verisi silinene kadar | Yok |
| RevenueCat yetki + satin alma | Play Billing | — | RevenueCat / Google Play | yalniz Pro/paywall/restore yolunda VE guncel yasal onaydan sonra | abonelik dogrulama | Evet | Evet | saglayici politikasi | **RevenueCat, Google** |
| Rıza kaydi | kullanici | `SharedPreferences` `kvkk_consent_log_v2` | **Yok** | onay aninda | KVKK ispati | Evet | Hayir | cihaz verisi silinene kadar | Yok |

## Konum: on soruya kaynak + calisma zamani yaniti

1. **GPS lat/lng bir KoruBeni backend'ine gidiyor mu?** Hayir — oyle bir backend yok.
   `lib/` icindeki TEK HTTPS hostu `tile.openstreetmap.org` (`app_environment.dart`).
2. **Backend gercekten yok mu?** Kaynakta yok; calisma zamani yakalamasinda uygulamadan
   cikan baska host gorulmedi.
3. **GPS lat/lng OSM'ye query/body/header olarak gidiyor mu?** Hayir. Tam pcap icinde
   enjekte edilen koordinat (`41.00824` / `28.97837`) **hic gecmiyor**. Karo URL'si
   `{z}/{x}/{y}.png`.
4. **OSM yalniz karo istegi mi goruyor?** Evet — artı IP ve User-Agent.
5. **Karo zoom seviyeleri?** Cihazda olculdu: onbellek `osm_tiles_v1/15/...` ve
   `osm_tiles_v1/16/...` — yani **z=15 ve z=16**.
6. **Harita acilmadan karo istegi oluyor mu?** Hayir.
7. **Harita hic acilmazsa OSM istegi 0 mi?** **Evet, 0** (calisma zamani).
8. **Acil akislar konum API'si cagiriyor mu?** Hayir.
   Kaynak: `check_in_service`, `call_service`, `countdown_screen`,
   `emergency_platform_service`, `safe_walk_screen` icinde **sifir** konum referansi;
   `getCurrentLocation()`'in tek cagrani `map_page.dart`; konum alabilen tek kapi
   `LocationConsentGate` ve o da yalniz `map_page.dart:215`'ten cagriliyor — basliginda
   "NEVER call this on the panic / SOS / check-in path" yaziyor.
   Calisma zamani: konum izni **GERI ALINMISKEN** Check-In normal sekilde silahlaniyor.
9. **Guvenli Yuruyus konum paylasiyor mu?** Hayir. Ayni `CheckInService` sinifini
   (`CheckInService.safeWalk`) kullaniyor ve o sinifta konum referansi yok.
10. **Koordinatlar SQLite/secure storage/prefs'e yaziliyor mu?** Hayir —
    `/data/data` ve `/data/user_de/0` altinda enjekte edilen koordinati iceren dosya yok
    (yalniz `kernel_blob.bin` = Dart kodu ve karo onbellegi haric tutuldu).

## Google Play Data Safety — konum siniflandirmasi

Play'in tanimi: **Yaklasik >= 3 km²**, **Hassas < 3 km²**.

Uygulama ham koordinat GONDERMIYOR. Ancak gonderilen karo z/x/y, kullanicinin
**baktigi alani** belirler ve harita kullanicinin uzerine ortalandiginda bu alan
kullanicinin konumudur. Olculen zoom'larda bir karonun yer kapladigi alan (41°N):

| zoom | karo kenari | alan | Play bandi |
|---|---|---|---|
| 15 | 922.9 m | **0.85 km²** | **Hassas (<3 km²)** |
| 16 | 461.4 m | **0.21 km²** | **Hassas (<3 km²)** |

Yani: ham GPS aktarilmiyor, ama karo koordinatlarindan tureyen alan Play'in HASSAS
bandinda. Data Safety paketi bunu boyle yazmali — "GPS gonderilmiyor" tek basina
eksik bir beyan olurdu. (`store/DATA_SAFETY_FORM.md` bu turden guncellendi.)

OSMF bir "service provider" varsayilMADI: kendi kullanim politikasi ve kendi veri
isleme sorumlulugu olan bagimsiz bir ucuncu taraf olarak degerlendirildi.

## RevenueCat

`revenue_cat_service.dart` olculdu: `automaticDeviceIdentifierCollectionEnabled = false`,
`diagnosticsEnabled = false`, `setLogLevel(error)`, `entitlementVerificationMode =
informational`. `setAttributes` / `logIn` / ozel musteri nitelikleri / analytics
entegrasyonu **yok** — yani anonim uygulama kullanici kimligi disinda kimlik verilmiyor.
Yapilandirma tembel: yalniz guncel yasal onay varken ve kullanici Pro/paywall/restore
yoluna girdiginde. Play'in ve RevenueCat'in kendi rehberi **purchase history** beyani
istiyor; `store/DATA_SAFETY_FORM.md` bunu zaten iceriyor.

## Araclar ve ham kanit

- `tools/lr1_dataflow_probe.py` — tcpdump + izin-geri-alma deneyi
- `lr1-dataflow-api36.md` — koşu ciktisi
