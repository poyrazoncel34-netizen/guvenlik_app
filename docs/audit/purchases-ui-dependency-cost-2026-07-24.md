# purchases_ui_flutter bağımlılık maliyeti — statik ölçüm (2026-07-24)

**Bu bir statik bağımlılık analizidir, cihaz kanıtı değildir.** Hiçbir kapıyı PASS
yapmaz. Amacı, ertelenmiş `purchases_ui_flutter` düşürme diliminin faydasını
karar verilebilir bir sayıya bağlamaktır.

## Yöntem (tekrar üretilebilir)

```bash
cd android && ./gradlew :app:dependencies \
  --configuration playReleaseRuntimeClasspath --console=plain
```

Ağaç ayrıştırılırken `(c)` ile biten satırlar atlandı (bunlar sürüm kısıtı
bildirimidir, gerçek bağımlılık kenarı değil). Bir bileşen "yalnız X üzerinden
geliyor" sayıldı ancak ve ancak X'in alt ağacında görünüyor ve başka hiçbir
üst düzey bağımlılığın alt ağacında görünmüyorsa.

## Bulgular

| Ölçüm | Değer |
| --- | --- |
| `playReleaseRuntimeClasspath` benzersiz bileşen | 203 |
| `purchases_ui_flutter` alt ağacı | 121 |
| **Yalnız `purchases_ui_flutter` üzerinden gelen** | **75 (%37)** |
| Bunların `androidx.compose` olanı | 38 |
| CycloneDX SBOM toplam bileşen | 400 |

Uygulamanın kendi Android modülünde (`android/app/build.gradle.kts`) Compose
kullanımı yoktur; bu bir Flutter uygulamasıdır. Compose ağacının 39 bileşeninin
tamamı `purchases_ui_flutter`'dan gelir. `audioplayers_android` yalnız 2
bileşen çeker (`compose.runtime:runtime-annotation{,-android}`) ve o ikisi
düşürmeden etkilenmez.

Dart tarafındaki tek kullanım:
`lib/screens/subscription/subscription_management_screen.dart:59` →
`RevenueCatUI.presentCustomerCenter()`. Paywall zaten custom'dır ve bu
`test/core/services/revenuecat_subscription_contract_test.dart:112` ile
pinlenmiştir (`paywall does not use RevenueCat PaywallView`).

## Compose dışı, dikkat çeken bileşenler

Düşürmeyle birlikte kaybolacak 75 bileşenin arasında yalnız UI çatısı yok:

- `com.squareup.okhttp3:okhttp` (+ `okio`) — **ikinci bir HTTP istemcisi**
- `io.coil-kt:coil{,-base,-compose,-compose-base,-svg}` — görsel yükleyici
- `com.caverock:androidsvg-aar` — SVG ayrıştırıcı
- `org.commonmark:commonmark{,-ext-gfm-strikethrough}` — Markdown ayrıştırıcı

Ölçülen giriş yolu: `purchases-ui → coil-compose → coil-base → okhttp`
(`deps.txt:1006`). `purchases_flutter` (çekirdek SDK) okhttp çekmez; ağaçtaki
tek gerçek okhttp kenarı bu Coil zinciridir.

**[ÇIKARIM]** Ağdan indirilen içeriği ayrıştıran üç bileşen (SVG, Markdown,
görsel kod çözme) ve ayrı bir HTTP yığını, ürüne yalnız Customer Center ekranı
için giriyor. Bunlar üçüncü parti SDK yasağının ("Veri cihazdan çıkmaz"
beyanının koddan kanıtlanabilir kalması) gerekçesiyle doğrudan aynı kategoride:
saldırı yüzeyi ve denetlenmesi gereken kod. Bu, düşürme kararının gerekçesini
lisans iş yükünden bağımsız olarak güçlendirir.

**[BELİRSİZ]** Bu bileşenlerin çalışma zamanında gerçekten ağ isteği yapıp
yapmadığı ölçülmedi; Customer Center açılmadığı sürece kod yolunun ölü olması
beklenir. R8 sonrası AAB'de ne kadarının kaldığı da ölçülmedi.

## Karara etkisi

- Lisans incelemesi (400 bileşen, 84 benzersiz metin) düşürmeden **sonra**
  yapılırsa 75 bileşenlik iş boşuna yapılmamış olur. Onaylanmış sıralama
  (cihaz testi → düşürme → lisans) bu ölçümle tutarlıdır.
- `verification-metadata.xml`'deki compose sürüm çakışması —
  `compose-bom:2024.09.00` üzerinden gelen 1.5.4/1.7.0 kaybeden adayları,
  2026-07-24 CI kırmızısının kaynağı — düşürmeyle birlikte tamamen ortadan
  kalkar.

## Bu ölçümün söylemedikleri

- Customer Center'ın Play'in abonelik yönetimi şartını karşılamak için gerekli
  olup olmadığı **incelenmedi**; düşürme kararı bu sorunun cevabını gerektirir.
- Düşürmenin UI etkisi ölçülmedi (UI değişikliği ayrı onay konusudur).
- Cihazda hiçbir şey çalıştırılmadı.
