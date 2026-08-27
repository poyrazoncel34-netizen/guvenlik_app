# KoruBeni — Sorumluluk Devri Analizi

**Tarih:** 2026-08-25 · **Kapsam:** Türkiye · **Tüzel kişilik:** yok (gerçek kişi geliştirici)
**Amaç:** Uygulamanın kullanımından doğabilecek her zarar senaryosunda sorumluluğun
kullanıcıya devredilebileceği azami sınırı, Türk mevzuatına dayandırarak tespit etmek.

> Bu belge hukuki mütalaa değildir. Mevzuat ve kamuya açık kaynaklar okunarak
> hazırlanmış bir mühendislik/uyum analizidir. Yayından önce bir tüketici hukuku
> avukatına okutulmalıdır.

---

## 0. Önce dürüst cevap: tavan nerede?

**%100 devir hukuken mümkün değil.** İki emredici hüküm bunu kesin olarak kesiyor,
bir üçüncüsü ise koşullu:

| Engel | Kaynak | Etkisi | Kesinlik |
|---|---|---|---|
| Kast ve ağır ihmal | TBK m.115 | Önceden yapılan sorumsuzluk anlaşması **kesin hükümsüz**. Sözleşmeyle aşılamaz. | **Kesin** |
| Ölüm/yaralanma sorumluluğunu kaldıran şartlar | Haksız Şartlar Yönetmeliği EK-1 (a) | Tüketici sözleşmesinde **kesin hükümsüz**, hâkim resen atar. | **Kesin** |
| Ayıplı ürünün yol açtığı ölüm/yaralanma | **7223 s. Ürün Güvenliği ve Teknik Düzenlemeler Kanunu m.6** | Üretici kusuru aranmaksızın tazminle yükümlü. | **Koşullu — muhtemelen kapsam dışı** |

Bu üçü sözleşmeyle kapatılamaz. Ama **hiçbiri kendiliğinden tetiklenmez.** Üçünün de
bir tetikleyicisi var ve tetikleyiciyi kapatmak mümkün:

- TBK m.115 → tetikleyici **ağır ihmal**. Mühendislik disipliniyle kapatılır.
- Haksız Şartlar → tetikleyici **sorumluluğu kaldıran şart yazmış olmak**. Yazmayarak kapatılır.
- Kusursuz sorumluluk → tetikleyici **AYIP**. Belgelenmiş davranışla kapatılır.

### Üçüncü satırın düzeltilmesi (2026-08-26)

Bu belgenin ilk hali kusursuz sorumluluğun dayanağı olarak **2003 tarihli "Ayıplı Malın
Neden Olduğu Zararlardan Sorumluluk Hakkında Yönetmelik"i** gösteriyordu. Yanlıştı ve
web doğrulamasında yakalandı:

1. O yönetmelik **mülga 4077** sayılı Kanun'un 4. ve 31. maddelerine dayanıyor. 6502
   **Geçici m.1** onu yalnızca *"bu Kanunda öngörülen yönetmelikler yürürlüğe girinceye
   kadar ve bu Kanuna aykırı olmayan hükümleri"* ile ayakta tutuyor — kalıcı bir zemin değil.
2. Kusursuz sorumluluğun güncel dayanağı **7223 sayılı Kanun (12.03.2020) m.6**: imalatçı
   ve ithalatçı "zararı gidermekle yükümlü"; doktrin bunu kusursuz sorumluluk sayıyor.
3. Ancak 7223 m.3(1)(s) **"ürün"ü "her türlü madde, müstahzar veya eşya"** olarak
   tanımlıyor — fiziksel. Fiziksel taşıyıcıya (CD, flash bellek) kayıtlı yazılım ürün
   sayılıyor; **yalnızca dijital dağıtılan mobil uygulamalar ve hizmetler kapsam dışı
   kalıyor.** Play üzerinden dağıtılan KoruBeni bu ikinci gruba giriyor.

**Sonuç:** bugün itibarıyla kusursuz ürün sorumluluğunun KoruBeni'ye uzanması
**muhtemel değil.** Bu bir yorum meselesidir ve avukat teyidi gerektirir — belgenin ilk
hali bu satırda fazla karamsardı.

**İleriye dönük risk.** AB **Ürün Sorumluluğu Direktifi 2024/2853** (yürürlük 09.12.2024)
yazılımı açıkça "ürün" tanımına aldı ve **09.12.2026'dan sonra** piyasaya sürülenlere
uygulanıyor. Türkiye 7223'ü AB uyumu kapsamında çıkarmıştı; yönün buraya doğru olması
bekleniyor. Yani **bugün kapsam dışı, orta vadede muhtemelen içeride.**

**Sözleşme bu düzeltmeden etkilenmiyor.** Madde 5 ayıbın *kendisini* hedeflediği için
her iki rejimde de doğru savunmadır; ayıp hem TKHK m.8 hem 7223 bakımından tetikleyicidir.

### Fiilen işleyen rejim

Düzeltme sonrası gerçek tablo şu: uygulama TKHK m.3 bakımından **"mal"dır** (tanım
yazılımı açıkça sayıyor), dolayısıyla **ayıp** rejimi işler — ama ayıbın yaptırımı
sözleşmeseldir (iade, onarım, bedel indirimi), yani **para seviyesindedir** ve Madde
14.4'teki tavanla sınırlıdır. Bedensel zarar tazminatı ise genel hükümlere (TBK m.49 /
m.112) gider ve **kusur arar** — Madde 3, 5, 6 ve 14 tam olarak orada çalışır.

**Bu analizin tezi:** korumanın kaynağı sözleşme metni değil, **ayıp yokluğunun
ispatlanabilirliğidir.** Sözleşme dördüncü sırada gelir.

---

## 1. Uygulamanın tabi olduğu hukuki rejim

| Soru | Cevap | Dayanak |
|---|---|---|
| Uygulama "mal" mı "hizmet" mi? | **Mal.** Dijital içerik ve hizmetler normatif olarak mal kategorisinde. | TKHK m.3/h |
| Hangi ayıp rejimi? | Ayıplı **mal** hükümleri (m.8-12) | TKHK m.3/h atfı |
| "Ayıp" nedir? | Reklamlarda/mağaza sayfasında yer alan özellikleri taşımayan, **ya da tüketicinin makul olarak beklediği faydaları azaltan** eksiklik | TKHK m.8 |
| Mağaza açıklaması sözleşmenin parçası mı? | **Evet.** Reklamda vaat edilen unsurlar sözleşmenin parçası sayılır. | TKHK m.61 |
| İlk 6 ayda ispat yükü kimde? | **Satıcıda.** Teslimden itibaren 6 ay içinde çıkan ayıbın teslimde var olduğu kabul edilir; aksini satıcı ispatlar. | TKHK m.10 |
| Sözleşme dışı kişiler? | Sorumsuzluk kaydı **üçüncü kişiyi bağlamaz**; haksız fiil sorumluluğu sözleşmeden bağımsızdır. | Sözleşmenin nispiliği · TBK m.49 |
| 18 yaş altı kullanıcı? | Sınırlı ehliyetsiz küçük yasal temsilci rızası olmadan **borç altına giremez** → EULA onu bağlamaz | TMK m.11, m.16 |
| Tüketici nerede dava açar? | **Kendi yerleşim yerinde.** Emredici, sözleşmeyle değiştirilemez. | TKHK m.73/5 |
| Google koruma sağlıyor mu? | **Hayır.** DDA tek yönlü: geliştirici Google'ı tazmin eder, tersi yok. | Google Play DDA |

**Sonuç:** İzmir yetki şartı bugün fonksiyonsuz. Mağaza metni bir hukuki belgedir.
Ve ilk 6 ay boyunca "uygulamam ayıplı değildi"yi **sen ispat edeceksin.**

---

## 2. En yakın emsal — ve kötü haber

**Yargıtay 3. Hukuk Dairesi, Manavgat alarm kararı (2025).** Bir vatandaş evine alarm
sistemi kurdurdu. Sistem 4 gün sonra bozuldu, şirkete defalarca bildirildi, giderilmedi.
17 Nisan 2020'de eve hırsız girdi. İlk derece mahkemesi davayı reddetti; **Yargıtay bozdu:**

> "Sistemin olay anında devreye girip uyarı vermesi gerekirken çalışmadığı, haksız fiil
> teşkil eden olay ile güvenlik sisteminin çalışmaması arasında **illiyet bağı bulunduğu**,
> çalışmayan güvenlik sisteminden dolayı hırsızlığın önlenememesinde güvenlik firmasının
> sorumlu olduğu anlaşılmıştır."

**Bunun anlamı çok net ve rahatsız edici:** Türk hukukunda, suçu üçüncü kişi işlemiş olsa
bile, çalışmayan güvenlik sistemi ile zarar arasında illiyet bağı **kurulur**. Saldırganın
fiili nedensellik zincirini kesmez.

Bunu Yargıtay HGK içtihadı da destekliyor: *"İlliyet bağının kesilmesi olasılığı dar
yorumlanmalıdır. İlliyet bağının kesildiği iddiası, sorumlu kişiler tarafından açıkça
ispatlanmadıkça kabul edilmemelidir."* — yani **ispat yükü sende**, ve mahkeme zaten
kesilmeye isteksiz.

### Ama karar üç noktada ayrıştırılabilir

| Manavgat davası | KoruBeni (doğru kurgulanırsa) |
|---|---|
| Sistem **arızalıydı** — yani ayıp mevcuttu | Belgelenmiş davranış sınırı ≠ arıza |
| Müşteri arızayı **defalarca bildirdi**, şirket **gidermedi** → ağır ihmal | Geliştiriciye bildirilecek/giderilecek bir bakım borcu yok |
| Şirket **izleme hizmeti** üstlenmişti — sürekli edim | Kurulumdan sonra geliştirici tarafında devam eden edim yok |

Üçünün de KoruBeni'de doğmaması **tasarım kararıdır**, kendiliğinden olmaz. Bu analizin
geri kalanı bunu nasıl garanti altına alacağımızı tanımlıyor.

---

## 3. Sorumluluk devir mekanizmaları

Sekiz mekanizma. Her senaryo bunlardan bir veya birkaçına dayanır.

| Kod | Mekanizma | Ne yapar | Dayanak |
|---|---|---|---|
| **M1** | **Edim daraltma** | Borcu *sonuç borcu* değil *özen borcu* olarak tanımlar. Vekil, sonucun gerçekleşmemesinden **aksi kararlaştırılmış olsa bile** sorumlu tutulamaz. | TBK vekâlet hükümleri; özen borcu doktrini |
| **M2** | **Ayıp tanımını önceden kapatma** | Bir davranış önceden ve açıkça belgelenmişse, "makul beklenti"nin dışında kalmaz → ayıp değildir → TKHK ayıp rejimi tetiklenmez (7223 kusursuz sorumluluğu da, kapsama girdiği varsayılsa dahi, aynı sebeple tetiklenmez) | TKHK m.8 ("makul olarak beklediği fayda") |
| **M3** | **Kullanıcı doğrulama yükü** | Test Modu ile kullanıcı, ifanın kendi cihazında çalıştığını **kendi kontrol eder**. Kontrol imkânı verilmiş ve kullanılmamışsa zarar görenin kusuru doğar | TBK m.52 (zarar görenin kusuru → tazminat indirilir veya **tamamen kaldırılır**) |
| **M4** | **Bilgilendirilmiş kabul + ispat kaydı** | Kullanıcının sınırlamayı bildiğini ispatlar. İspat yükü sende olduğu için (TKHK m.10, HGK içtihadı) bu mekanizma olmadan diğerlerinin hiçbiri mahkemede kullanılamaz | TKHK m.10; HGK illiyet içtihadı |
| **M5** | **Yaş kapısı** | 18 altı kullanıcıya karşı EULA'nın hiçbir hükmü işlemez. Yaş kapısı sözleşmenin ayakta kalma şartıdır | TMK m.11, m.16 |
| **M6** | **Üçüncü kişi rızası garantisi + daraltılmış tazmin** | Acil kişiler EULA'yı imzalamadı; onlara karşı sözleşme koruma sağlamaz. Tek yol: kullanıcının rızayı aldığını taahhüt etmesi ve rücu hakkı | Sözleşmenin nispiliği; KVKK m.5 |
| **M7** | **Vaat tutarlılığı** | Mağaza metni + sözleşme + ekran metinleri tek ve aynı vaadi söyler. Çelişki tüketici lehine yorumlanır | TKHK m.61; TBK m.23 |
| **M8** | **Ağır ihmalden kaçınma (kod disiplini)** | TBK m.115 sözleşmeyle aşılamaz. Tek savunma ağır ihmalin **hiç doğmaması**. Bu bir metin işi değil, mühendislik işidir | TBK m.115 |

**M8 en önemlisi ve tek başına sözleşmeyle yapılamayan mekanizma.** Manavgat kararında
şirketi yakan şey sözleşme metni değil, bildirilen arızayı gidermemesiydi.

---

## 4. Senaryo matrisi

Sütunlar: **Varsayılan** = hiçbir mekanizma yoksa sorumlu kim · **Mekanizma** = devri
sağlayan araç · **Kalan** = mekanizmalar uygulandıktan sonra sende kalan risk.

### A — Uygulama çalışmadı

| # | Senaryo | Varsayılan | Mekanizma | Kanıt gereksinimi | Kalan |
|---|---|---|---|---|---|
| A1 | Doze/uyku modunda arama hiç başlamadı | Geliştirici (ayıp) | M2+M3+M4 | Doze davranışının belgelenmiş olması; cihaz doğrulama kaydı; kullanıcının Test Modu erişimi | **Orta** |
| A2 | OEM pil yöneticisi uygulamayı öldürdü | Geliştirici | M2+M3 | OEM kill davranışının mağaza+sözleşme+ekranda yazılı olması; pil optimizasyonu uyarısının gösterildiği kaydı | **Orta** |
| A3 | Şebeke yoktu, arama gitmedi | Kullanıcı/operatör | M1+M2 | "Şebekeye bağımlıdır" ifadesinin üç yüzeyde bulunması | Düşük |
| A4 | Arama gitti, karşı taraf açmadı | Kullanıcı | M1 | Edim tanımı: "arama girişiminde bulunur", teslim/cevap taahhüdü yok | Çok düşük |
| A5 | Şarj bitti, cihaz kapandı | Kullanıcı | M2 | Cihaz koşuluna bağımlılık beyanı | Çok düşük |
| A6 | Kullanıcı izinleri reddetti, akış çalışmadı | Kullanıcı | M2+M4 | İzin reddi ekranında açık uyarı + reddin yerel kaydı | Düşük |
| A7 | Android güncellemesi izinleri sıfırladı | Belirsiz | M2+M3 | "Hazırlık durumu" kontrolünün varlığı ve kullanıcıya bildirimi | **Orta** |
| A8 | Uygulama çöktü (crash) | Geliştirici (ayıp) | M8 + crash log | Yerel crash kaydı; sürüm bazlı çökme oranı; hızlı yama geçmişi | **Yüksek** |
| A9 | Geri sayım çalıştı, kullanıcı iptal edemedi | Geliştirici | M8 | İptal yolunun test kanıtı; PIN kilitlenmesi senaryoları | **Yüksek** |
| A10 | Cihaz kilitliyken akış çalışmadı | Geliştirici | M2+M3 | Kilit ekranı davranışının belgelenmesi | Orta |
| A11 | Siren çalmadı / ses kısıktı | Geliştirici | M2+M3 | Ses profili bağımlılığının yazılı olması | Düşük |
| A12 | Konum hatalı/sapmalı geldi | GPS/donanım | M1+M2 | GPS doğruluk payının yazılı olması (mevcut madde 3'te var) | Çok düşük |
| A13 | Harita yüklenmedi (internet yok) | Kullanıcı | M2 | Haritanın isteğe bağlı ağ katmanı olduğunun beyanı | Çok düşük |
| A14 | Sahte çağrı çalışmadı | Geliştirici | M2 | Özelliğin cihaz içi simülasyon olduğu beyanı | Düşük |
| A15 | Check-in bildirimi gelmedi | Geliştirici | M2+M3 | Arka plan davranışının OS'e bağımlılığı (mağaza metninde mevcut) | Orta |
| A16 | Güncelleme sonrası davranış değişti | Geliştirici | M4+M8 | CHANGELOG; sürüm bazlı davranış sözleşme testleri | Orta |

### B — Uygulama çalıştı ama zarar oluştu

| # | Senaryo | Varsayılan | Mekanizma | Kanıt gereksinimi | Kalan |
|---|---|---|---|---|---|
| B1 | Arama gitti, kişi yardıma gelmedi | Kullanıcı | M1 | Edim tanımı: üçüncü kişinin davranışı taahhüt kapsamı dışı | Çok düşük |
| B2 | **Kullanıcı uygulamaya güvenip 112'yi aramadı** | Geliştirici (!) | M2+M4+M7 | Bu senaryonun en yüksek riskli olanı. 112 uyarısının **her yüzeyde** ve **kullanım anında** görünmesi | **Yüksek** |
| B3 | Uygulamaya güvenip riskli yere gitti | Kullanıcı | M2+M4 | "Fiziksel koruma sağlamaz" beyanı (mağaza metninde mevcut) | Orta |
| B4 | Siren saldırganı tahrik etti | Kullanıcı | M1+M4 | Sirenin sonucunun öngörülemez olduğu beyanı | Düşük |
| B5 | Yardıma gelen acil kişi zarar gördü | **Üçüncü kişi — EULA bağlamaz** | M6 | Kullanıcının rıza taahhüdü; tazmin/rücu hükmü | **Yüksek** |

### C — Kullanıcı kötüye kullandı

| # | Senaryo | Varsayılan | Mekanizma | Kanıt gereksinimi | Kalan |
|---|---|---|---|---|---|
| C1 | Sahte çağrıyla dolandırıcılık | Kullanıcı | M4 | Mevcut madde 5 bunu karşılıyor | Çok düşük |
| C2 | 112'ye asılsız ihbar | Kullanıcı | M4 | Kabahatler Kanunu kapsamında idari para cezası kullanıcıya | Çok düşük |
| C3 | Takip/stalkerware amaçlı kullanım | Kullanıcı + Play politikası | M4+M7 | Arka plan konum takibi olmaması mimari savunma | Düşük |
| C4 | Rızası olmayan kişiyi acil kişi ekledi | **Paylaşılan — KVKK** | M6 | Kullanıcının rıza taahhüdü; mevcut madde 7 temel var ama daraltılmalı | **Yüksek** |
| C5 | Sirenle çevreye rahatsızlık | Kullanıcı | M4 | Kabahatler Kanunu — gürültü | Çok düşük |

### D — Üçüncü kişi zararı (sözleşme koruma sağlamaz)

| # | Senaryo | Varsayılan | Mekanizma | Kanıt gereksinimi | Kalan |
|---|---|---|---|---|---|
| D1 | Acil kişi verisi rızasız işlendi → KVKK şikayeti | **Veri sorumlusu = SEN** | M6 | Rıza taahhüdü + rücu; ama KVKK idari para cezası **doğrudan sana** kesilir | **Yüksek** |
| D2 | Acil kişi gereksiz/yanlış arandı | Kullanıcı | M6 | Aramayı kullanıcı tetikler; otomatik gönderim yok | Düşük |
| D3 | Cihaz çalındı, acil kişi verisi okundu | Paylaşılan | M2+M8 | Güvenli depolama; yedeklemenin kapalı olması | Orta |
| D4 | 18 yaş altı kullandı, zarar gördü | **Geliştirici — EULA geçersiz** | M5 | Gerçek yaş kapısı + Play hedef kitle beyanı | **Yüksek** |

### E — Ödeme ve abonelik

| # | Senaryo | Varsayılan | Mekanizma | Kanıt gereksinimi | Kalan |
|---|---|---|---|---|---|
| E1 | Ödedi, Pro açılmadı, panik butonu çalışmadı | Geliştirici (ayıp) | M8 | **En tehlikeli ticari senaryo.** Entitlement zincirinin uçtan uca kanıtı | **Yüksek** |
| E2 | İptal/iade talebi | Google Play | M2 | Mağaza akışına atıf | Çok düşük |
| E3 | Deneme bitti, haberi olmadı | Geliştirici | M4+M7 | Deneme koşullarının paywall'da yazılı olması | Düşük |
| E4 | Fiyat değişti | Google Play | M2 | Play bildirimi | Çok düşük |

### F — Öngörülemeyen (kullanıcının aklına gelmeyenler)

| # | Senaryo | Varsayılan | Mekanizma | Kanıt gereksinimi | Kalan |
|---|---|---|---|---|---|
| F1 | Google API/politika değişikliği özelliği kırdı | Paylaşılan | M2+M8 | Mücbir sebep + üçüncü taraf bağımlılığı beyanı | Orta |
| F2 | RevenueCat/OSM servisi kapandı | Paylaşılan | M2 | Üçüncü taraf bağımlılık listesi sözleşmede | Düşük |
| F3 | Yeni Android sürümü davranışı bozdu | Geliştirici | M2+M8 | Sürüm uyumluluk beyanı + hızlı yama | Orta |
| F4 | Play uygulamayı kaldırdı, kullanıcı erişemedi | Google | M2 | Hizmetin durdurulabileceği beyanı (mevcut madde 8) | Düşük |
| F5 | KVKK veri ihlali | **Veri sorumlusu = SEN** | M8 | 72 saat bildirim yükümlülüğü; ihlal müdahale planı | **Yüksek** |
| F6 | Reklam Kurulu şikayeti (yanıltıcı reklam) | Geliştirici | M7 | Mağaza metni ↔ gerçek davranış parity kanıtı | Orta |
| F7 | Geliştirici devam edemedi (hastalık/vefat) | — | M2 | Hizmetin bildirimsiz durdurulabileceği beyanı (mevcut) | Düşük |
| F8 | Uygulama silinmeden veri kaldı / kalmadı | Kullanıcı | M2 | Saklama sürelerinin yazılı olması (KVKK metninde mevcut) | Çok düşük |

---

## 5. Kalan yüksek riskler ve neden sözleşmeyle kapanmadıkları

Yukarıdaki matriste **9 senaryo "Yüksek"** kaldı. Hiçbiri metin yazarak kapanmıyor:

| Senaryo | Neden metin yetmiyor | Ne kapatır |
|---|---|---|
| A8 crash, A9 iptal edilemedi | Ağır ihmal iddiası doğurur → TBK m.115 | Kod kalitesi + test + hızlı yama (M8) |
| B2 kullanıcı 112'yi aramadı | Uygulamanın varlığı beklenti yaratır | Kullanım anında uyarı (M4) + vaat tutarlılığı (M7) |
| B5 acil kişi zarar gördü | Sözleşmenin nispiliği | Sadece rücu (M6) — tam koruma yok |
| C4/D1 üçüncü kişi verisi | KVKK cezası veri sorumlusuna doğrudan kesilir | Rıza taahhüdü + mimari (rehber okumama) |
| D4 18 yaş altı | Küçük sözleşmeyle bağlanamaz | Gerçek yaş kapısı (M5) |
| E1 ödedi ama çalışmadı | Ayıp + ticari güven | Billing zincirinin uçtan uca doğrulanması |
| F5 KVKK ihlali | İdari yaptırım, sözleşme dışı | İhlal müdahale planı |

**Ortak payda:** kalan riskin tamamı **mühendislik ve kanıt** işidir, metin işi değil.
Bu, tezin doğrulanmasıdır: zırh sözleşme değil, ayıpsızlığın ispatıdır.

---

## 6. Yapılacaklar

### Faz 1 — Sözleşme (metin, UI'a dokunmaz)
1. Yeni madde: **EDİMİN KAPSAMI** — özen borcu tanımı, sonuç taahhüdü reddi (M1)
2. Yeni madde: **BELGELENMİŞ DAVRANIŞ SINIRLARI** — A1..A16 senaryolarının açık listesi (M2)
3. Yeni madde: **KULLANICI DOĞRULAMA YÜKÜ** — Test Modu ile ifa kontrolü (M3)
4. Madde 9 yeniden yazımı — ölüm/yaralanma ibaresi çıkar, kusur şartı + TBK m.115 sınırı kalır
5. Madde 13 düzeltme — TKHK m.73/5 gerçeğine uydur
6. Madde 10 daraltma — yalnızca kullanıcının kusurlu fiilinden doğan talepler (M6)
7. Yeni madde: **KULLANICI BEYANI** — 112 birincil yol, cihaz bağımlılığı, prova yapıldı (M4)
8. Yaş kapısı hükmünün sertleştirilmesi (M5)

### Faz 2 — Vaat tutarlılığı (metin)
9. Mağaza metni denetimi: "acil yardım" anahtar kelimesi, "Güvenli Yürüyüş" adlandırması
10. Politika testi genişletme: mağaza ↔ sözleşme ↔ ekran metni parity

### Faz 3 — İspat zinciri (küçük UI)
11. Onay akışında sınırlama bloğu + metin sürümü/hash kaydı
12. Panik ilk kurulumda tek seferlik "bu ne değildir" onayı
13. Yaş kapısının gerçek bir kapı olması + Play hedef kitle beyanının kapatılması

### Faz 4 — Yayın
14. EXTERNAL_LAUNCH_BLOCKERS E1..E9

---

## 6.5 AÇIK SORU — mesafeli sözleşme yükümlülükleri (2026-08-27'de bulundu)

Bu analiz boyunca **hiç incelenmemiş** bir alan: Pro aboneliği bir **mesafeli
sözleşme** kuruyor ve Mesafeli Sözleşmeler Yönetmeliği kendi yükümlülüklerini
getiriyor. Depoda bu konuda hiçbir şey yok — `cayma`, `mesafeli` veya
`ön bilgilendirme` ifadeleri sözleşmede, mağaza metninde ve çevirilerde geçmiyor.

**Neden hemen hüküm yazılmadı:** yükümlülüğün kimde olduğu belirsiz.

- Google'ın Türkçe yardım sayfası: *"Satın alma işlemleri uygulamanın
  geliştiricisinden yapılır"* ve vergiden çoğu yerde geliştirici sorumlu.
  Google yalnızca **AB/BK KDV'si** bakımından merchant of record.
- Bu okumaya göre Türk tüketicisine karşı **sağlayıcı sensin** ve ön
  bilgilendirme yükümlülüğü sende.
- Ancak fiyat, yenileme koşulu, iptal ve iade akışını **Google'ın kendi satın
  alma ekranı** gösteriyor ve iadeyi Google yürütüyor. Ön bilgilendirmenin bir
  kısmı fiilen platform tarafından veriliyor.

Yanlış tarafa yazmak iki yönde de zarar verir: olmayan bir yükümlülüğü
üstlenmek, ya da olanı eksik yerine getirmek.

**Avukata sorulacak (4. soru):**

1. Play üzerinden satılan abonelikte, Türk tüketicisine karşı **sağlayıcı
   geliştirici mi, Google mı?**
2. Sağlayıcı geliştiriciyse, uygulamanın kendisi hangi **ön bilgilendirmeyi**
   vermek zorunda?
3. Cayma hakkı: Yönetmelik *"elektronik ortamda anında ifa edilen hizmetler
   veya anında teslim edilen gayrimaddi mallar"* için cayma hakkı öngörmüyor —
   ama ön bilgilendirmede **bunun açıkça belirtilmesi** gerekiyor. Bu beyan
   nerede yapılmalı: sözleşmede mi, paywall'da mı, mağaza metninde mi?

**Bulunma biçimi kayda değer:** bu boşluk bir teste veya denetime takılmadı.
"Hukuksal tarafta her şeyden emin miyiz?" sorusu üzerine, daha önce hiç
bakılmamış bir mevzuata bakılarak bulundu. Aynı yöntemle bulunabilecek başka
alanlar olabilir; e-ticaret mevzuatı (ETBİS) ve ticari elektronik ileti (İYS)
bu turda incelenmedi.

---

## 7. Kaynaklar

- TBK m.115-116 sorumsuzluk anlaşmaları — Erdem&Erdem, Aktaş Hukuk
- Tüketici Sözleşmelerindeki Haksız Şartlar Hakkında Yönetmelik — mevzuat.gov.tr
- 7223 s. Ürün Güvenliği ve Teknik Düzenlemeler Kanunu (12.03.2020) — m.3(1)(s), m.6
- AB Ürün Sorumluluğu Direktifi 2024/2853 — yazılımı ürün sayar, 09.12.2026'dan sonra
- ~~Ayıplı Malın Neden Olduğu Zararlardan Sorumluluk Hakkında Yönetmelik~~ — dayanağı
  mülga 4077; 6502 Geçici m.1 ile sınırlı ayakta. Bkz. §0 düzeltme notu.
- TKHK m.3/h, m.8, m.10, m.61, m.73/5 — 6502 sayılı Kanun
- Yargıtay 3. HD Manavgat alarm kararı (2025) — AA, 2025
- Yargıtay HGK illiyet bağı içtihadı — eyavuz.av.tr derlemesi
- TMK m.11, m.16 ehliyet
- Google Play Developer Distribution Agreement
- Life360 Terms of Service 2025.2 — karşılaştırmalı model

---

## 8. Ceza ve idari yaptırım ekseni (ek — 2026-08-25)

Sözleşme bu eksende **sıfır iş görür.** Anayasa m.38/7 ve TCK m.20: *"Ceza sorumluluğu
şahsidir. Kimse başkasının fiilinden dolayı sorumlu tutulamaz."* Bu iki yöne birden işler.

**Tüzel kişilik bu eksende fark yaratmazdı:** "Tüzel kişiler hakkında ceza yaptırımı
uygulanamaz." Şirket kurulsaydı da hapis riski gerçek kişiye yönelirdi. Ceza ekseninde
şirketsiz olmanın maliyeti sıfırdır.

| Kaynak | Maruziyet | Kapanma | Mekanizma |
|---|---|---|---|
| Kullanıcının işlediği suç | — | **Tam** | TCK m.20 + iştirakte kast şartı (taksirle iştirak olmaz). İstisna: belirli bir suçu bilerek kolaylaştırmak |
| Vergi (VUK m.359) | Hapis | **Tam, koşullu** | GVK mük. 20/B — aşağıdaki şartlar sürekli korunmak kaydıyla |
| TCK 135 / 136 / 138 | 1–3 / 2–4 / 1–2 yıl | Büyük ölçüde | "Hukuka aykırı olarak" unsuru; rıza ve hukuki sebep varsa suç oluşmaz |
| KVKK idari ceza | 256.357 – 17.092.242 TL | Küçülür | Uyum + ihlal müdahale planı (72 saat) |
| Reklam Kurulu | İdari para cezası | **Kısmi** | Genel izlenim ölçütü; **marka adının kendisi yanıltıcı bulunabilir** |
| TCK 85 / 89 taksirli suç | 2–6 yıl | Düşük, sıfır değil | Objektif isnat edilebilirlik zayıf; tetikleyici ağır ihmal |

### GVK mükerrer 20/B — şartlar (hepsi zorunlu)

1. İkametgâhın bağlı olduğu vergi dairesinden **istisna belgesi** al (Dijital Vergi Dairesi).
2. Türkiye'de bir bankada hesap aç; **tüm hasılat münhasıran** bu hesaptan tahsil edilsin.
3. Hesap bilgilerini **1 ay içinde** vergi dairesine bildir.
4. Karşı taraf Google Ireland Ltd.; banka aktarımda **%15 stopaj** yapar, eşik altında nihai vergidir.
5. Kapsam: mobil uygulama, mağaza üzerinden satış. **Bilgisayar programı kapsam dışı.**
6. Eşik aşılırsa istisna **o yıl tamamen** kaybedilir; kazancın **tamamı** beyan edilir.
7. Şart ihlali → **geçmişe dönük** vergi ziyaı cezası + gecikme faizi + KDV.

**Çözülmemiş:** Bağ-Kur 4/b zorunluluğu. Kaynaklar çelişkili; mali müşavire sorulacak.

### Reklam Kurulu — neden tam kapanmıyor

Kurul yanıltıcılığı "genel izlenim" ölçütüyle, tüketici gözünden değerlendirir. Emsal:
"Asmalı Bahçe Pansiyon" işletmesinin "Butik Otel" olarak tanıtılması, belge bulunmadığı
için **ismin işletme türünü yanlış tanıtması** gerekçesiyle yaptırıma bağlanmıştır.

Uygulama adı "KoruBeni" bir koruma vaadi taşır; uygulama ise koruma sağlamadığını beyan
eder. Uyarı ibaresi genel izlenimi iyileştirir, ortadan kaldırmaz. **İsim durduğu sürece
artık bir risk kalır** ve bu, sahibinin bilinçli kabulüyle taşınmalıdır.
