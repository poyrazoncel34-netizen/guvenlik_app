# KoruBeni — Özen Dosyası

**Tarih:** 2026-08-27 · **Kapsam:** Türkiye · **Muhatap:** avukat, bilirkişi, hâkim

> **Bu belge uygulamanın güvenli olduğunu iddia etmez.** Ne yapıldığının, nasıl
> ölçüldüğünün ve **neyin ölçülemediğinin** kaydıdır. İddia değil, envanterdir.

---

## 1. Bu dosya hangi soruyu cevaplıyor

Bir zarar davasında sözleşme metni tek başına yetmez. Sorumluluk sınırlamalarının
ayakta kalıp kalmayacağı, tek bir ayrımda düğümlenir:

> **Hafif ihmal mi, ağır ihmal mi?**

Fark hayati:

| | Sonuç |
|---|---|
| **Hafif kusur** | Sorumsuzluk kaydı **geçerlidir** — bkz. §2 |
| **Ağır ihmal / kast** | Önceden yapılan sorumsuzluk anlaşması **kesin hükümsüzdür** (TBK m.115). Sözleşme ne yazarsa yazsın çalışmaz. |

Kullanım Sözleşmesi v4.0.0 Madde 14.5 bu istisnayı zaten açıkça yazıyor; yazmasaydı
madde bütünüyle düşerdi. Yani sözleşmenin bittiği yer burasıdır ve **bu dosyanın
başladığı yer.**

---

## 2. Neden hafif kusur sınırlaması bu üründe geçerli

TBK m.115/2, hafif kusurdan sorumsuzluk anlaşmasını yalnızca **kanun ya da yetkili
makam iznine tabi** olarak yürütülebilen uzmanlık hizmetleri bakımından geçersiz sayar —
doktor, avukat, mali müşavir gibi.

**Yazılım geliştiriciliği izne tabi bir meslek değildir.** Dolayısıyla hafif kusur
bakımından sözleşmesel sınırlama bu üründe kullanılabilir durumdadır.

Bunun pratik anlamı: **savunmanın tamamı, bir kusurun "ağır" tarafa geçmemesine
bağlıdır.** Bu dosya tam olarak onun kaydıdır.

---

## 3. "Ağır ihmal" ne demek — ve bu projede neye benzerdi

Ağır ihmal bir *sonuç* değil, bir *davranış standardıdır*: aynı konumdaki makul bir
geliştiricinin **bariz şekilde** alacağı önlemi almamak.

En yakın emsal bunu somutlaştırıyor. **Yargıtay 3. HD, Manavgat alarm kararı (2025):**
alarm sistemi bozuktu, müşteri **defalarca bildirdi**, şirket **gidermedi**, ev soyuldu —
şirket sorumlu tutuldu. Şirketi yakan şey bir hata değil, **bildirilen bir kusuru
gidermemesiydi.**

Bu projede ağır ihmal şuna benzerdi:

- Bilinen bir dispatch kusurunu sürümler boyunca taşımak
- Kırmızı bir güvenlik testini iddiayı zayıflatarak yeşile çevirmek
- Cihazda doğrulanmamış bir davranışı "doğrulandı" diye kaydetmek
- Kullanıcı bildirimlerini kayıtsız bırakmak

**Aşağıdaki envanterin amacı, bu dördünün olmadığını gösterebilmektir.**

---

## 4. Ölçülen özen aygıtı

Tüm sayılar 2026-08-27'de bu depoda ölçülmüştür; iddia değildir.

| Ne | Ölçüm | Nerede |
|---|---|---|
| Otomatik test | **1701 test**, 299 test dosyası | `flutter test --no-pub` |
| Native test | 18 Kotlin test sınıfı | `android/app/src/test`, `androidTest` |
| Politika/drift yakalayıcı | Kök seviyede **38 test dosyası** | `test/*_test.dart` |
| Negatif kontrol pratiği | **14 test dosyası** açık negatif kontrol taşıyor | `grep "NEGATIVE CONTROL"` |
| Denetim | **1767 gereksinim satırı**, satır başına kanıt | `PRODUCTION_AUDIT.md` |
| Makine okunur kanıt | 12 artifact | `docs/audit/evidence/` |
| Cihaz doğrulama kaydı | 8 tarihli belge | `docs/audit/device-verification-*.md` |
| CI | 5 iş akışı (ci, codeql, nightly-android, pages, release) | `.github/workflows/` |
| Yayın kapısı | analyze → test → imzalı AAB → lint/unit → 16 KB | `scripts/verify_release.sh` |

**2026-08-27'de koşulan yayın zinciri: 5/5 kapı yeşil.** Aynı gün ölçülenler:

- 16 KB sayfa uyumu: **10/10 native kütüphane** (`libapp.so`, `libflutter.so` `0x10000`)
- Play Billing Library: **8.3.0** (31.08.2026 şartı: 8+)
- Target API: **36** (aynı tarihli şart: 36)
- Kritik yol test kapsamı: `emergency_session_contract` %99.18, `emergency_platform_service`
  %95.04, `pin_verification_service` %94.87 — eşik %90

---

## 5. Delil değeri asıl yüksek olan üç pratik

Test sayısı tek başına özen göstermez; herkes test yazar. Bu depoda **olağandışı** olan
ve mahkemede özen olarak okunabilecek olan şunlardır:

### 5.1 Bir kapının kırılabildiği kanıtlanmadan kabul edilmiyor
Kanıt matrisi her doğrulayıcıdan **negatif kontrol** ister: kapıyı kıracak mutasyon
uygulanır, kırmızı görülür, geri alınır. Yeşil bir testin *bir şeyi koruduğu* böyle
gösterilir. Bu oturumda beş ayrı kapı bu şekilde sınandı ve **ikisinin kendi kusuru bu
yolla bulundu** (§6).

### 5.2 Cihaz kanıtı yapı parmak izi taşımak zorunda
`CERT2-05` kaydı: bir sertifikasyon geçişi, düzeltmeden **dört saat önce** derlenmiş bir
yapıyı koşmuş ve düzeltme öncesi kusuru yeniden üretmişti. O günden beri cihaz notları
AVD/cihaz adını, yoğunluğu, ölçülen commit'i ve kurulumun `lastUpdateTime` ile
doğrulandığını **zorunlu olarak** taşıyor.

### 5.3 Düzeltmeler siliniyor değil, kaydediliyor
Yanlış çıkan bir değerlendirme üzeri çizilerek ve gerekçesiyle bırakılıyor (FIR-03,
CERT2-01, ve bu dosyanın §6'sı). Bir kaydın *değiştiğini görebilmek*, kaydın hiç
değişmemiş görünmesinden daha güvenilirdir.

---

## 6. Aygıtın kendi hatalarını yakaladığı kayıtlı örnekler

Bunlar zayıflık değil, işleyen bir sürecin delilidir. Hepsi 2026-08-25/27'de bulundu ve
commit geçmişinde gerekçeleriyle duruyor.

| Bulunan | Neydi |
|---|---|
| `specialUse` FGS | Denetim, **var olmayan** bir foreground service'i PASS kanıtı gösteriyordu; blocker belgesi operatörü olmayan bir beyanı göndermeye yolluyordu. İki test yokluğu zaten koruyordu. |
| Blocker sürüklenmesi | Belge 12 gün geride; başlık 87 diyordu, gövde 76 taşıyordu, 30 gereksinim hiçbir kategoride tarif edilmemişti. Artık parite testiyle pinli. |
| KVKK ihlal prosedürü | "Bildirim gerekip gerekmediğini değerlendir" diyordu — m.12/5'te **risk eşiği yok**. GDPR alışkanlığı, ceza sebebi. |
| VERBİS notu | Dayanak karar numarası yanlış, eşik üç yıl bayat (25M → 100M), muafiyet gerekçesi hukuken hatalı. |
| Kural 1 ihlali | İki hukuki belge "tamamen çevrimdışı" diyordu; CLAUDE.md kural 1 bunu açıkça yasaklıyor ve belgelerin kendi bölümleri RevenueCat'i sayıyordu. |
| Kapının kendi kusuru | Yazılan iki yeni test, negatif kontrolde **kendi ölçüm hatasını** gösterdi ve düzeltildi. |

---

## 7. Doğrulanmamış olanlar — dürüstçe

Bu bölüm dosyanın en önemli kısmıdır. Eksiksiz görünen bir özen dosyası, özen dosyası
değildir.

- **`docs/release/safety_case.md` karar durumu: `NO_GO / INDEPENDENT_REVIEW_UNVERIFIED`.**
  15 hazard'ın çoğu `LOCAL_PASS, device unverified`; H07 ve H08 `UNVERIFIED`.
- **Doze yarışı ve OEM pil yöneticileri cihaz dışında kanıtlanamaz.** Proje kuralı bunu
  yazılı olarak kabul eder ve emülatör sonucunu cihaz sonucu gibi sunmayı yasaklar.
- **Billing yaşam döngüsü hiç gözlemlenmedi.** Satın alma, iptal, deneme başlangıcı ve
  bitişi bu yapıya karşı hiç çalıştırılmadı.
- **109 gereksinim açık**, tamamı dış blocker; 29'u P1.
- **Panik→arama süresi gerçek donanımda ölçülmedi.**

Bu satırların yazılı olması, ağır ihmal iddiasına karşı **lehe** delildir: neyin
bilinmediği biliniyor ve kayıt altında.

---

## 8. Bu dosyanın değerini yok edecek şeyler

- Kırmızı bir testi iddiayı zayıflatarak yeşile çevirmek
- Doğrulanmamış bir şeyi doğrulanmış diye kaydetmek
- §7'yi kısaltmak veya güzelleştirmek
- Bildirilen bir kusuru sürümler boyunca taşımak
- Bu dosyayı güncellemeyi bırakmak

Bunlardan herhangi biri, dosyayı savunma delilinden **aleyhe delile** çevirir.

---

## 9. Güncel tutma

Her yayından sonra §4 sayıları yeniden ölçülür, §7 gözden geçirilir, §6'ya o dönemde
bulunan hatalar eklenir. Sayılar ölçülmeden yazılmaz.

**İlgili belgeler:** `docs/legal/sorumluluk-devri-analizi-2026-08-25.md` ·
`docs/release/safety_case.md` · `PRODUCTION_AUDIT.md` · `EXTERNAL_LAUNCH_BLOCKERS.md` ·
`docs/veri_ihlali_bildirimi_proseduru.md`
