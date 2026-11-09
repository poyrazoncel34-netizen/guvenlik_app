# OSM Tile Usage Policy uyumu ve harita kesinti durumu — 2026-11-09

Kaynak: <https://operations.osmfoundation.org/policies/tiles/> (sayfada tarih yok;
2026-11-09'da okundu) ve OSMF Attribution Guidelines (son düzenleme 2026-09-10).
Dal: `codex/evidence-remediation-20260911`, taban commit `bcef086`.

## Uyum tablosu

| Madde | Politika | Önce | Sonra |
|---|---|---|---|
| User-Agent | Uygulamayı adıyla tanıtan, sabit UA; kütüphane varsayılanı engellenir; iletişim önerilir | `flutter_map (com.poyrazoncel.korubeni; +korubeni.destek@gmail.com)` — kütüphane adıyla başlıyor | `KoruBeni (com.poyrazoncel.korubeni; +korubeni.destek@gmail.com)`, `NetworkTileProvider(headers:)` ile açık |
| Attribution | "OpenStreetMap" adı, etkileşimsiz görünür, UI altında gizlenmez, `/copyright` linki | Var ve linkli; ama yükleme katmanının altında kalıyordu ve büyük yazı boyutunda alt kontrol kartı üstünü örtüyordu | Uyarılar + atıf + kontroller tek bir yukarı büyüyen yığında (`MapBottomStack`); 1.0 ölçekte konumlar piksel piksel aynı, 1.3/2.0'da çakışma yok; yükleme katmanının üstünde |
| Cache | Cache-Control/Expires/ETag; başlık yoksa ≥7 gün; koşullu istek; `no-cache` gönderme | Uyuyor (128 MiB sınırlı kalıcı cache) | Değişmedi; ret süresince süresi dolmuş kopya ağ yerine gösteriliyor |
| Toplu indirme / offline | Ön yükleme, "bölgeyi kaydet", arşiv yasak | Uyuyor | Değişmedi |
| İstek hızı | Sayısal sınır yok; ağır kullanım engellenebilir | Yalnız 503'te jitter'lı yeniden deneme; 403/429'da geri çekilme yok; zaman aşımı yok | 401/403/429 → TÜM upstream trafik `Retry-After`'a göre (30 sn–1 sa, varsayılan 429: 5 dk, 401/403: 30 dk) durur; her istek 15 sn ile sınırlı |
| HTTP/2 | Öneri | Yok | Yok (yeni bağımlılık gerektirir; kapsam dışı) |
| URL | Tam `https://tile.openstreetmap.org/{z}/{x}/{y}.png`; sabit kodlanmaması önerilir | Doğru; `MAP_TILE_URL_TEMPLATE` derleme zamanı | Değişmedi. Uzaktan değiştirme backend ister (CLAUDE.md kural 1) |
| Ticari kullanım | Erişim "her an", haber verilmeden kesilebilir | Kesintide sessiz boş harita | "Harita şu an yüklenemiyor" bandı (`blocked` / `network`) |

## Kesinti durumu nasıl çalışıyor

- `lib/core/network/map_tile_availability.dart`: `MapTileAvailability`
  (`null` / `blocked` / `network`).
- `lib/core/network/tile_upstream_guard.dart`: `TileUpstreamGuard` (her upstream
  isteğin tek yolu: zaman aşımı, ret, raporlama) ve `TileUpstreamBackoff`.
- Raporlama: 401/403/429 → `blocked` + devre kesici (cevabın GELDİĞİ ana göre;
  zaman aşımından sonra gelen geç ret de sayılır); 5xx, zaman aşımı, soket/TLS
  veya gövde ortasında kopma → ağ hatası (3 ardışık = `network`); başarı yalnız
  gövde tamamen geldikten sonra ve ret süresi dolmuşsa sayılır. Devre kesici
  OSM dışı (ücretli sağlayıcı) URL'lere de uygulanır.
- Zaman aşımı gövdede akış üzerinde (`Stream.timeout`) uygulanır: abonelik
  iptal edilir, bağlantı serbest kalır.
- Süresi dolmuş bir karonun yeniden doğrulaması ret/5xx/zaman aşımıyla
  biterse eldeki eski kopya gösterilir.
- `NetworkTileProvider(silenceExceptions: true)`: başarısız karo saydam görünür.
  Önceden, pan/zoom ile budanmış bir karonun hatası dinleyicisiz kalıp
  `FlutterError.onError`'a ulaşıyor, her karo için bir
  `flutterFrameworkUnhandled` yerel kaza kaydı yazıyordu (100 satırlık
  `crash_logs` tavanını harita gürültüsüyle doldurabilirdi). Bu yüzden
  `errorTileCallback` kaldırıldı.
- Çevrimdışıyken (bağlantı yok) mevcut çevrimdışı yüzey gösterilir; bant ve
  karo katmanı yoktur.

## Sağlayıcı değiştirme (MapTiler / Stadia)

Derleme tanımları:

```
--dart-define=MAP_TILE_URL_TEMPLATE=https://api.maptiler.com/maps/streets-v2/256/{z}/{x}/{y}.png?key=<ANAHTAR>
--dart-define=MAP_TILE_ATTRIBUTION=© MapTiler © OpenStreetMap contributors
--dart-define=MAP_TILE_ATTRIBUTION_URL=https://www.maptiler.com/copyright/
```

`validateReleaseConfiguration` OSM dışı bir şablonda atıf hâlâ yalın OSM
satırıysa, atıf "OpenStreetMap" içermiyorsa ya da link HTTPS değilse release
derlemesini durdurur.

**Yapılandırmayla çözülmeyen kısımlar:**

1. **Hukuki:** `lib/constants/legal_texts.dart` (KVKK tablosu ve aydınlatma
   paragrafı, TR+EN) ile `store/aydinlatma_metni.html` karo alıcısını açıkça
   "OpenStreetMap" diye adlandırıyor. Sağlayıcı değişirse bu metinler
   `scripts/bump_legal.sh` ile güncellenmeli; `kvkkVersion` artışı tüm
   kullanıcılardan yeniden onay ister. Data Safety formu da gözden geçirilmeli.
2. **Cache:** kalıcı cache yalnız `tile.openstreetmap.org` içindir. Ücretli
   sağlayıcıda yalnız bellek içi görüntü cache'i kalır; sağlayıcının cache
   şartları okunmadan genişletilmemeli.
3. **Anahtar:** istemci anahtarı APK'ya gömülür; sağlayıcı panelinde paket
   adına/kotaya kısıtlanmalı.

## Kanıt

- Kırmızı→yeşil: `docs/audit/evidence/osm-tile-2026-11-09/D1..D7-*.txt`. Yeni
  testler HEAD'e derlenemediği için (yeni test kancaları gerekir) her kusur,
  yalnız o düzeltme HEAD davranışına geri alınarak yeniden üretildi (KIRMIZI,
  exit 1), sonra düzeltme geri konup aynı test koşuldu (YEŞİL, exit 0).
  Çağıran listesi: `CALLERS.txt`.
- `test/core/network/tile_outage_handling_test.dart` — 403/429 (yüzeye çıkar,
  cache'lenmez, `blocked`, sonraki istek ağa çıkmaz, süre bitince düzelir),
  `Retry-After` saniye/HTTP-date/sınırlar, ret sırasında bayat cache, zaman aşımı
  (başlık ve gövde), 3 ardışık hata → `network`, soket hatası, ücretli sağlayıcı
  yolu, dispose sonrası rapor.
- `test/screens/map_tile_outage_widget_test.dart` — gerçek zincir (flutter_map →
  NetworkTileProvider → OsmTileCacheClient → mock upstream): normal, 403, 429,
  zaman aşımı ve yükleme katmanı durumlarında atfın ekranda ve en üstte olduğu
  (isabet testi), bandın göründüğü, istisna olmadığı, ret sonrası kaydırmada
  ağa istek gitmediği ve isteklerin `KoruBeni (...)` UA'sıyla çıktığı.
- `test/core/services/app_environment_test.dart` — atıf doğrulama kuralı.
- Mutasyon sınaması (hepsi geri alındı): atfı yükleme katmanının altına
  taşımak, UA başlığını kaldırmak, devre kesiciyi atlamak, istek zaman aşımını
  kaldırmak, alt yığının yuva yüksekliğini sıfırlamak, gövde zaman aşımını
  Future'a geri almak ve ret sırasında başarıyı saymak — yedisi de en az bir
  testi kırdı. Bant semantiğini eski `container: true` biçimine döndürmek
  testi kırmadı; çünkü o biçim de etiketi taşıyor (M6 yanlış alarm).

## Bağımsız inceleme (flutter-reviewer) ve sonuçları

| Bulgu | Sonuç |
|---|---|
| H1 gövde zaman aşımı bağlantıyı bırakmıyordu | Düzeltildi; test `onCancel` ile bırakılmayı kanıtlıyor |
| M1 gövde ortası `ClientException` sayılmıyordu | Düzeltildi; başarı da gövde sonuna ertelendi (yoksa sayaç her 200'de sıfırlanıyordu) |
| M2 uçuştaki başarı aktif reddi siliyordu | Düzeltildi + test |
| M3 atıf alt kontrollerle çakışıyordu | `MapBottomStack` ile düzeltildi + 1.0/1.3/2.0 çakışma testi |
| M4 Retry-After istek başına göre; geç ret kayboluyordu; taşma; saat geri alma | Dördü de düzeltildi + test |
| M5 yeniden doğrulama hatasında eski kopya kullanılmıyordu | Düzeltildi + 429/503/zaman aşımı testleri |
| M6 bant canlı bölgesi etiketsiz | Yanlış alarm (eski hali de etiketi birleştiriyordu; mutasyonla görüldü); `MergeSemantics` + etiket testi eklendi |
| L2 geçersiz `MAP_TILE_ATTRIBUTION` başlangıçta `StateError` | Bilerek bırakıldı: mevcut `MAP_TILE_URL_TEMPLATE` ve RevenueCat kontrolleriyle aynı fail-closed kalıbı. Bu tanımlar bugün hiçbir release komutunda verilmiyor; sağlayıcı değişiminde dahili test kanalında açılış denenmeli |

## Doğrulanmayanlar

- Cihaz/emülatörde canlı OSM'e karşı ağ yakalaması yapılmadı; gerçek AAB'nin
  gönderdiği başlık bu notla kanıtlanmış değildir
  (`NETWORK_CAPTURE_AND_COUNSEL_UNVERIFIED` sürüyor).
- Ret süresi uygulama yeniden başlayınca sıfırlanır (bellek içi). Yeniden
  başlatmada en fazla bir görünüm alanı kadar istek tekrar gider.
- Atıf rozetinin dokunma alanı 48 dp'nin altında (mevcut tasarım; görsel
  değişiklik kapsam dışı bırakıldı).
