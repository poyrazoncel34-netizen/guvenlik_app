# TASLAK — Kullanım Sözleşmesi v4.0.0

> **DURUM: TASLAK.** Henüz `lib/constants/legal_texts.dart` dosyasına uygulanmadı.
> Amaç: sorumluluğun kullanıcıda kalmasını, Türk hukukunda **ayakta kalacak** şekilde sağlamak.
> Her maddenin altında `» Teknik:` satırı, o maddenin hangi hukuki mekanizmayı kullandığını
> ve neden geçersiz sayılamayacağını açıklar. Bu satırlar yayına girmez, sadece incelemek içindir.

---

## Yazım tekniğinin özeti

Üç şeyi ASLA yazmıyoruz, çünkü yazıldıkları anda kesin hükümsüz oluyorlar:

1. ~~"Hiçbir zarardan sorumlu değildir"~~ → Haksız Şartlar Yönetmeliği, yasak listesi 1. sıra
2. ~~"Ölüm ve yaralanmadan sorumlu tutulamaz"~~ → aynı yönetmelik, kesin hükümsüz
3. ~~"Tüm sorumluluk kullanıcıya aittir"~~ → genel sorumsuzluk kaydı; TBK m.115 + haksız şart

Bunların yerine üç şey yapıyoruz. Sonuç aynı, ama bu sefer ayakta kalıyor:

1. **Borcu daraltıyoruz.** Sorumluluktan kaçmıyoruz — sorumluluk doğuracak borcu hiç üstlenmiyoruz.
2. **Beklentiyi önceden tanımlıyoruz.** "Ayıp", kullanıcının *makul beklentisinin* karşılanmamasıdır. Beklentiyi biz yazarsak, karşılanmama diye bir şey olmaz.
3. **Doğrulama yükünü kullanıcıya veriyoruz.** Kullanıcı kendi cihazında test edebiliyorsa, etmemesi kendi kusurudur.

---

## 1. TARAFLAR, KONU VE KABUL

Bu Kullanım Sözleşmesi ("Sözleşme"), KoruBeni uygulamasını ("Uygulama") geliştiren
Poyraz Öncel ("Geliştirici") ile Uygulamayı cihazına kuran ve kullanan gerçek kişi
("Kullanıcı") arasında akdedilir.

Kullanıcı, Uygulamayı kurarak ve kullanarak bu Sözleşme'yi okuduğunu, anladığını ve
tüm hükümleriyle kabul ettiğini beyan eder. Kullanıcı bu Sözleşme'nin herhangi bir
hükmünü kabul etmiyorsa Uygulamayı kullanmamalı ve cihazından kaldırmalıdır.

---

## 2. TANIMLAR

| Terim | Tanım |
|---|---|
| **Arama girişimi** | Uygulamanın, cihazın işletim sistemine bir telefon araması başlatma talebi iletmesi. Talebin işletim sistemi tarafından yerine getirilip getirilmeyeceği, aramanın kurulup kurulmayacağı ve karşı tarafın yanıt verip vermeyeceği bu tanımın **dışındadır.** |
| **Yardımcı araç** | Kullanıcının kendi güvenlik planını uygulamasına destek olan, ancak bu planın yerine geçmeyen cihaz içi yazılım. |
| **Prova (Test Modu)** | Kullanıcının, gerçek arama yapılmaksızın akışın kendi cihazında çalışıp çalışmadığını doğrulamasını sağlayan işlev. |
| **Cihaz koşulları** | İşletim sistemi sürümü ve ayarları, üretici pil yönetimi, uyku/Doze modu, izin durumları, şebeke ve operatör durumu, şarj seviyesi, ses profili, depolama ve benzeri, Geliştiricinin kontrolü dışındaki tüm etkenler. |

> » **Teknik:** "Arama girişimi" tanımı sözleşmenin en kritik cümlesidir. Edimi *sonuçtan*
> ayırıp *girişime* indirger. Sonrasında gelen her madde bu tanıma dayanır.

---

## 3. EDİMİN KAPSAMI VE NİTELİĞİ

3.1. Geliştiricinin bu Sözleşme kapsamındaki edimi, Uygulamanın Kullanıcının cihazına
kurulabilir halde sunulmasından ve belgelenen işlevleri **özenle** yerine getirmeye
çalışmasından ibarettir.

3.2. **Bu Sözleşme bir sonuç borcu doğurmaz.** Geliştirici; Kullanıcının güvenliğinin
sağlanacağını, bir zararın önleneceğini, bir aramanın kurulacağını, bir bildirimin
teslim edileceğini, bir konumun doğru olacağını veya herhangi bir işlevin belirli bir
sürede tamamlanacağını **taahhüt etmemektedir.**

3.3. Uygulama bir **yardımcı araçtır.** Sözleşmenin konusu bir güvenlik sonucu değil,
bir araçtır. Taahhüt edilmemiş bir sonucun gerçekleşmemesi, sözleşmeye aykırılık
teşkil etmez.

3.4. Kullanıcı; acil durumlarda birincil ve asli yolun **112 Acil Çağrı Merkezi'ni
aramak** olduğunu, Uygulamanın bu yolun yerine geçmediğini ve geçmeyeceğini kabul eder.

> » **Teknik:** Özen borcu / sonuç borcu ayrımı. Türk hukukunda vekil, sonucun
> gerçekleşmemesinden — aksi kararlaştırılmış olsa bile — sorumlu tutulamaz. Sorumluluğu
> *sınırlamıyoruz* (bu yasak), borcun konusunu *tanımlıyoruz* (bu serbest).

---

## 4. UYGULAMANIN YAPMADIĞI ŞEYLER

Kullanıcı, Uygulamanın aşağıdakileri **yapmadığını** bilerek kullandığını kabul eder:

- Resmî bir acil servis, kolluk kuvveti veya 112 hizmeti **değildir**; bunlara bağlı değildir.
- Bir alarm izleme merkezi, çağrı merkezi veya insanlı müdahale hizmeti **içermez**.
- Kullanıcı adına kimseyi olay yerine **yönlendirmez** ve müdahale organize **etmez**.
- Fiziksel koruma, caydırıcılık veya güvenlik garantisi **sağlamaz**.
- Kullanıcıyı arka planda **takip etmez**; konum yalnızca Kullanıcının başlattığı oturumda kullanılır.
- Geliştiriciye ait herhangi bir sunucuya acil durum verisi **göndermez**; Geliştirici hiçbir
  acil durumdan **haberdar olmaz** ve olamaz.
- Kurulumdan sonra Geliştirici tarafından **izlenmez, denetlenmez veya bakımı üstlenilmez.**

> » **Teknik:** Bu maddenin son iki bendi, Yargıtay 3. HD'nin alarm şirketi kararından
> (Manavgat, 2025) korunmak içindir. O davada şirketin sorumlu tutulmasının sebebi
> **izleme hizmeti üstlenmiş olması** ve bildirilen arızayı **gidermemesiydi.** Burada
> üstlenilen bir izleme ve giderme borcu yoktur; dolayısıyla ihlal edilebilecek bir
> borç da yoktur.

---

## 5. BELGELENMİŞ ÇALIŞMA SINIRLARI

5.1. Uygulama, cihaz koşullarına bağlı bir yazılımdır. Aşağıdaki durumlar Uygulamanın
**bilinen, belgelenmiş ve kabul edilmiş çalışma sınırlarıdır**; bunlar ayıp, kusur veya
eksik ifa sayılmaz:

a) İşletim sisteminin uyku (Doze) modunda arka plan işlerini geciktirmesi veya durdurması;
b) Cihaz üreticisinin pil yönetimi yazılımının Uygulamayı sonlandırması veya kısıtlaması;
c) Şebeke, operatör veya baz istasyonu kaynaklı arama kurulamaması ya da gecikmesi;
d) Aranan kişinin yanıt vermemesi, meşgul olması veya ulaşılamaz olması;
e) Cihazın şarjının bitmesi, kapanması veya donanım arızası;
f) Kullanıcının gerekli izinleri (telefon, konum, bildirim, alarm) vermemesi veya geri alması;
g) İşletim sistemi güncellemesinin izinleri, alarmları veya arka plan davranışını değiştirmesi;
h) Cihaz kilitliyken işletim sisteminin uyguladığı kısıtlamalar;
i) Cihaz ses profili, sessiz mod veya ses seviyesi nedeniyle sirenin duyulmaması;
j) GPS donanımının doğruluk payından kaynaklanan konum sapmaları;
k) İnternet bağlantısı bulunmaması nedeniyle harita karolarının yüklenememesi;
l) Üçüncü taraf hizmetlerinin (harita sağlayıcı, mağaza, ödeme altyapısı) kesintisi veya sonlanması;
m) İşletim sisteminin yeni bir sürümünün mevcut davranışı değiştirmesi;
n) Bildirim tesliminin işletim sistemi tarafından geciktirilmesi veya engellenmesi;
o) Sahte çağrı işlevinin cihaz içi bir simülasyon olması ve gerçek arama başlatmaması;
p) Uygulamanın mağazadan kaldırılması veya hizmetin sonlandırılması.

5.2. Kullanıcı, bu sınırların kendisine sözleşme öncesinde açıkça bildirildiğini ve
Uygulamadan beklentisini bu sınırlar dahilinde oluşturduğunu kabul eder.

> » **Teknik:** Bu madde sözleşmenin **ikinci taşıyıcı kolonudur.** 6502 sayılı Kanun'da
> "ayıp", tüketicinin **makul olarak beklediği** faydaların karşılanmamasıdır. Beklenti
> sözleşme öncesinde ve açıkça tanımlandığında, listedeki bir durumun gerçekleşmesi
> "beklentinin karşılanmaması" olmaz — dolayısıyla ayıp doğmaz. Ayıp doğmayınca
> **Ayıplı Malın Neden Olduğu Zararlardan Sorumluluk Hakkında Yönetmelik'teki kusursuz
> sorumluluk da tetiklenmez.** Sözleşmeyle aşılamayan tek gerçek tehdit budur ve bu
> madde onu tetikleyicisinden kapatır.

---

## 6. KULLANICININ DOĞRULAMA YÜKÜMLÜLÜĞÜ

6.1. Uygulama, Kullanıcının akışın **kendi cihazında** çalışıp çalışmadığını gerçek
arama yapılmaksızın doğrulamasını sağlayan ücretsiz bir Prova (Test Modu) işlevi sunar.

6.2. Kullanıcı; kurulumdan sonra, her önemli cihaz veya işletim sistemi değişikliğinden
sonra ve düzenli aralıklarla Provayı çalıştırmayı **kendi yükümlülüğü olarak** kabul eder.

6.3. Kullanıcı, Uygulamanın hazırlık durumu uyarılarını (izin eksikleri, pil optimizasyonu,
eksik acil kişi vb.) dikkate almayı kabul eder.

6.4. Provayı çalıştırmamış veya hazırlık uyarılarını dikkate almamış olan Kullanıcı,
kendi cihazında doğrulanmamış bir kuruluma güvenmiş sayılır.

> » **Teknik:** TBK m.52 — zarar görenin kendi kusuru, hâkimin tazminatı indirmesine
> **veya tamamen kaldırmasına** imkân verir. Doğrulama imkânı ücretsiz olarak verilmiş
> ve kullanılmamışsa, bu doğrudan zarar görenin kusurudur. Manavgat kararında müşteri
> arızayı bildirmiş ve şirket gidermemişti; burada doğrulama aracı kullanıcının elindedir
> ve giderilecek bir bildirim Geliştiriciye ulaşmaz.

---

## 7. KULLANICININ BEYAN VE TAAHHÜTLERİ

Kullanıcı, Uygulamayı kullanarak aşağıdakileri **açıkça beyan ve taahhüt eder:**

7.1. 18 yaşını doldurduğunu ve tam fiil ehliyetine sahip olduğunu;

7.2. Acil durumlarda **öncelikle 112'yi arayacağını**, Uygulamayı 112'nin alternatifi
olarak kullanmayacağını;

7.3. Uygulamanın Madde 5'te sayılan çalışma sınırlarını okuduğunu ve anladığını;

7.4. Provayı kendi cihazında çalıştırarak kurulumunu doğrulama yükümlülüğünün
kendisinde olduğunu;

7.5. Kendi güvenlik planından, bulunduğu ortamı ve riskleri değerlendirmekten ve
alacağı önlemlerden **münhasıran kendisinin sorumlu** olduğunu;

7.6. Uygulamanın varlığına güvenerek, aksi halde girmeyeceği bir riske girmeyeceğini;

7.7. Acil durum kişisi olarak eklediği kişilerin **açık rızasını önceden aldığını**;

7.8. Cihazının fiziksel güvenliğinden, PIN'inin gizliliğinden ve işletim sistemi
güncellemelerinden kendisinin sorumlu olduğunu;

7.9. Uygulamayı yalnızca hukuka uygun amaçlarla kullanacağını.

> » **Teknik:** Bu madde, bir "sorumsuzluk kaydı" değil bir **beyan ve taahhüt** listesidir.
> Sorumsuzluk kayıtları haksız şart denetimine tabidir; kullanıcının kendi fiilleri
> hakkındaki beyanları değildir. Yasak listenin dışında kalır.

---

## 8. KULLANICININ MÜNHASIR SORUMLULUĞU

Aşağıdaki hususlar **münhasıran Kullanıcının sorumluluğundadır:**

a) Acil durumda 112'yi aramak veya aramamak yönündeki kararı ve bu kararın sonuçları;
b) Kendi güvenlik planı, risk değerlendirmesi ve bulunduğu ortama ilişkin tercihleri;
c) Uygulamanın kendi cihazında çalıştığını doğrulaması;
d) Cihaz izinlerinin verilmesi ve korunması;
e) Cihazın şarjlı, açık ve çalışır durumda tutulması;
f) Acil durum kişilerinin doğru, güncel ve ulaşılabilir olması;
g) Acil durum kişilerinin rızasının alınmış olması;
h) Uygulama aracılığıyla gerçekleştirdiği tüm arama, siren, sahte çağrı ve paylaşım eylemleri;
i) Uygulamanın kötüye kullanılmasından doğan her türlü hukuki ve cezai sonuç;
j) Uygulamanın PIN'i ile korunması ve PIN'in üçüncü kişilerle paylaşılmaması.

> » **Teknik:** Bu maddedeki her bent, Geliştiricinin kontrolünde **olmayan** ve
> Kullanıcının kontrolünde **olan** bir alanı işaret eder. Sorumluluğu zorla devretmiyor;
> zaten kullanıcıda olan sorumluluğu **isimlendiriyor.** Bu ayrım haksız şart
> denetiminde belirleyicidir.

---

## 9. ÜÇÜNCÜ KİŞİLER

9.1. Kullanıcı, acil durum kişisi olarak eklediği kişilerin kişisel verilerini
Uygulamaya girmeden önce bu kişilerin **açık rızasını aldığını** taahhüt eder.

9.2. Bu taahhüdün ihlali nedeniyle Geliştiriciye yöneltilecek her türlü talep, şikâyet,
idari yaptırım ve yargılama gideri bakımından Kullanıcı, Geliştiriciye **rücu
sorumluluğunu** kabul eder.

9.3. Acil durum kişileri, verilerinin silinmesi veya düzeltilmesi için doğrudan
Geliştiriciye başvurabilir.

> » **Teknik dürüstlük notu:** Bu madde üçüncü kişiye karşı Geliştiriciyi **korumaz.**
> Sözleşmenin nispiliği gereği, sözleşmeyi imzalamayan kişi onunla bağlı değildir; ayrıca
> KVKK idari para cezası doğrudan veri sorumlusuna kesilir. Bu maddenin sağladığı tek şey,
> Kullanıcıya **rücu** hakkıdır. Bu, matristeki B5/C4/D1 senaryolarında kalan yüksek riskin
> sebebidir ve sözleşmeyle kapatılamaz.

---

## 10. YAŞ SINIRI

10.1. Uygulama yalnızca **18 yaşını doldurmuş** kişilerin kullanımı içindir.

10.2. 18 yaşından küçük bir kişinin Uygulamayı kullanması halinde, bu kullanımdan ve
sonuçlarından o kişinin veli veya vasisi sorumludur.

10.3. Geliştirici, 18 yaşından küçük olduğunu tespit ettiği kullanıcıların erişimini
sonlandırma hakkını saklı tutar.

> » **Teknik:** Bu madde metinde olmakla yetinilemez. 18 yaşından küçük kişi, yasal
> temsilcisinin rızası olmadan borç altına giremez; bu Sözleşme'nin **hiçbir hükmü** ona
> karşı işlemez. Bu nedenle uygulamada **gerçek bir yaş kapısı** ve Play Console'da
> **18+ hedef kitle beyanı** zorunludur. Metin tek başına yeterli değildir.

---

## 11. KÖTÜYE KULLANIM YASAĞI

11.1. Sahte çağrı işlevi yalnızca kişisel güvenlik amaçlıdır. Dolandırıcılık, taciz,
başkasını yanıltma veya herhangi bir suç eyleminde kullanılması yasaktır.

11.2. Uygulamanın 112 veya kolluk kuvvetlerine asılsız ihbar amacıyla kullanılması
yasaktır ve idari/cezai yaptırıma tabidir.

11.3. Uygulamanın bir başkasını rızası dışında izlemek veya takip etmek amacıyla
kullanılması yasaktır.

11.4. Bu yasakların ihlalinden doğan **tüm hukuki ve cezai sorumluluk Kullanıcıya aittir.**

---

## 12. GARANTİ REDDİ

12.1. Uygulama "OLDUĞU GİBİ" (AS IS) ve "MEVCUT HALİYLE" (AS AVAILABLE) sunulmaktadır.

12.2. Geliştirici, Uygulamanın kesintisiz, hatasız veya belirli bir amaca uygun
çalışacağına dair zımni dahil hiçbir garanti vermez.

12.3. Uygulama önceden bildirim yapılmaksızın değiştirilebilir, güncellenebilir veya
sonlandırılabilir.

12.4. Bu madde, tüketici mevzuatından doğan ve sözleşmeyle bertaraf edilemeyen
haklarınızı etkilemez.

> » **Teknik:** 12.4 bilinçli olarak eklenmiştir. Sınırsız bir garanti reddi haksız şart
> sayılıp **tamamen** düşer. Emredici hakları saklı tutan bir garanti reddi ise ayakta kalır.
> Daha az istemek, daha çok almaktır.

---

## 13. SORUMLULUK

13.1. Geliştiricinin sorumluluğu, ancak kendi kusurunun bulunduğu hallerde ve bu
Sözleşme'nin Madde 3'te tanımlanan edim kapsamı çerçevesinde doğar.

13.2. Madde 5'te sayılan belgelenmiş çalışma sınırlarından kaynaklanan durumlar
Geliştiricinin kusuru sayılmaz.

13.3. Kullanıcının Madde 6'daki doğrulama yükümlülüğünü yerine getirmemesi, doğan
zararda kendi kusuru olarak değerlendirilir.

13.4. Geliştiricinin sorumlu tutulduğu hallerde toplam sorumluluğu, Kullanıcının talep
tarihinden önceki son on iki (12) ay içinde KoruBeni Pro için ödediği toplam bedeli
aşamaz. Ücretli aboneliği bulunmayan Kullanıcı bakımından bu tutar sıfırdır.

13.5. Bu maddedeki sınırlamalar; Geliştiricinin kastı, ağır ihmali ve tüketici
mevzuatından doğan emredici sorumluluğu bakımından **uygulanmaz.**

> » **Teknik:** 13.5, sözleşmenin ayakta kalmasını sağlayan maddedir. TBK m.115 gereği
> kast ve ağır ihmali kapsayan sorumsuzluk anlaşması **kesin hükümsüzdür** — ve maddeyi
> bu istisnayı yazmadan kurarsanız, madde bütünüyle düşer. İstisnayı açıkça yazmak,
> geri kalan sınırlamanın geçerli kalmasını sağlar. Mevcut sözleşmede "hiçbir zarardan
> sorumlu tutulamaz (can kaybı dahil)" ifadesi bulunuyordu; bu ifade Haksız Şartlar
> Yönetmeliği'nin yasak listesinde **birinci sırada** yer alır ve resen atılır.

---

## 14. TAZMİN VE RÜCU

14.1. Kullanıcı; kendi hukuka aykırı fiilinden, bu Sözleşme'yi ihlalinden veya Madde 9
kapsamındaki rıza taahhüdüne aykırılığından doğan ve Geliştiriciye yöneltilen üçüncü
kişi taleplerinden Geliştiriciyi tazmin etmeyi kabul eder.

14.2. Bu yükümlülük, Geliştiricinin kendi kusurundan doğan talepleri kapsamaz.

> » **Teknik:** 14.2 kasten eklenmiştir. Sınırsız tazmin taahhüdü tüketici aleyhine
> orantısız sayılır ve haksız şart olarak düşer. Kullanıcının **kendi fiiliyle**
> sınırlanmış tazmin ise ayakta kalır.

---

## 15. MÜCBİR SEBEP VE ÜÇÜNCÜ TARAF BAĞIMLILIKLARI

15.1. Doğal afet, savaş, salgın, telekomünikasyon veya enerji altyapısı kesintisi,
siber saldırı, devlet kısıtlamaları ve benzeri kontrol dışı olaylardan Geliştirici
sorumlu tutulamaz.

15.2. Uygulama; işletim sistemi, uygulama mağazası, ödeme altyapısı ve harita sağlayıcısı
gibi üçüncü taraf hizmetlere bağımlıdır. Bu hizmetlerin politika değişikliği, kesintisi
veya sonlanması Geliştiricinin kontrolünde değildir.

---

## 16. FİKRİ MÜLKİYET

Uygulama ve içerdiği tüm fikri mülkiyet hakları Geliştiriciye aittir. Kullanıcıya
kişisel, devredilemez ve münhasır olmayan bir kullanım lisansı verilmektedir.

---

## 17. UYGULANACAK HUKUK VE UYUŞMAZLIK ÇÖZÜMÜ

17.1. Bu Sözleşme Türkiye Cumhuriyeti hukukuna tabidir.

17.2. Tüketici sıfatını haiz Kullanıcı, 6502 sayılı Kanun uyarınca parasal sınırlara göre
**kendi yerleşim yerindeki** Tüketici Hakem Heyeti'ne veya Tüketici Mahkemesi'ne
başvurabilir.

> » **Teknik:** Mevcut sözleşmedeki "İzmir Mahkemeleri yetkilidir" hükmü tüketiciye karşı
> **hükümsüzdür**; tüketicinin kendi yerleşim yerinde başvurma hakkı emredicidir. Geçersiz
> bir yetki şartını sözleşmede tutmak hiçbir koruma sağlamaz, buna karşılık sözleşmenin
> genelinin iyi niyet denetiminde aleyhe değerlendirilmesine yol açabilir.

---

## 18. BÖLÜNEBİLİRLİK

Herhangi bir hükmün geçersiz sayılması halinde, Sözleşme'nin diğer hükümleri yürürlükte
kalır. Geçersiz hüküm, tarafların amacına en yakın geçerli hükümle ikame edilmiş sayılır.

---

## 19. DEĞİŞİKLİKLER

Geliştirici bu Sözleşme'yi güncelleyebilir. Esaslı değişikliklerde Uygulama yeniden
onay ister. Onay verilmemesi halinde Kullanıcı Uygulamayı kullanmaya devam edemez.

**İletişim:** korubeni.destek@gmail.com

---

# Bu taslak neyi başarıyor, neyi başaramıyor

## Başardığı

| Senaryo grubu | Sonuç |
|---|---|
| A1–A16 (uygulama çalışmadı) | Madde 5 ile **ayıp sayılmaz** → tüketici ayıp rejimi ve kusursuz sorumluluk tetiklenmez |
| A3, A4, A5, A12, A13 | Madde 3 + 5 ile sorumluluk **tamamen kullanıcı/donanım tarafında** |
| B1, B3, B4 | Madde 3.2 + 7.5 + 7.6 ile **kullanıcının kendi risk kararı** |
| C1–C5 (kötüye kullanım) | Madde 11 ile **tamamen kullanıcıda** |
| Doğrulama yapılmamışsa | Madde 6 + 13.3 ile TBK m.52 uyarınca tazminat **indirilir veya kaldırılır** |
| Tüm senaryolarda tavan | Madde 13.4 ile ödenen abonelik bedeli; ücretsiz kullanıcıda **sıfır** |

## Başaramadığı — ve sebebi

| Senaryo | Neden |
|---|---|
| A8 çökme, A9 iptal edilememesi | Ağır ihmal iddiası doğarsa TBK m.115 devreye girer. **Hiçbir sözleşme bunu kapatamaz.** Tek çare kodun sağlam olması. |
| B5 acil kişi zarar gördü | Acil kişi sözleşmenin tarafı değil. Madde 9 yalnızca rücu sağlar. |
| C4 / D1 KVKK | İdari para cezası doğrudan veri sorumlusuna kesilir; sözleşme idari yaptırımı engellemez. |
| D4 18 yaş altı | Küçük sözleşmeyle bağlanamaz. Metin değil, **gerçek yaş kapısı** gerekir. |
| E1 ödedi ama çalışmadı | Ayıp iddiası. Billing zincirinin uçtan uca doğrulanmasıyla kapanır. |
| F5 veri ihlali | İdari yaptırım, sözleşme dışıdır. |

**Özet:** Bu sözleşme, kullanıcıya devredilebilecek olan her şeyi devrediyor. Devredilemeyen
altı senaryo kalıyor ve bunların hepsi mühendislik işi — metin işi değil.
