// ============================================================================
// YASAL METİNLER SABİTLERİ
// Tüm uzun yasal metinler versiyonlanmış olarak burada tutulur.
// Versiyon değiştiğinde splash_screen.dart ve ConsentManager kullanıcıyı
// tekrar onay akışına yönlendirir (prefTermsVersion / kvkkVersion karşılaştırması).
// ============================================================================

class LegalTexts {
  // ── Sürüm Numaraları ──────────────────────────────────────────────────────
  static const String termsVersion = '4.0.0';
  static const String kvkkVersion = '3.4.0';
  static const String lastUpdated = '25 Ağustos 2026';
  static const String lastUpdatedEn = 'August 25, 2026';
  // Her belge kendi revizyon tarihini taşır: lastUpdated Kullanım Şartları'na,
  // lastUpdatedKvkk ise KVKK/Aydınlatma belgelerine aittir. v4.0.0'da Kullanım
  // Şartları'nın gövdesi yeniden yazıldığı için lastUpdated de birlikte taşındı.
  static const String lastUpdatedKvkk = '19 Temmuz 2026';
  static const String lastUpdatedKvkkEn = 'July 19, 2026';

  // ── Kullanım Sözleşmesi — Türkçe ─────────────────────────────────────────
  static const String termsOfServiceTr =
      '''
KULLANIM SÖZLEŞMESİ (SON KULLANICI LİSANS SÖZLEŞMESİ — EULA)
Sürüm $termsVersion | Son Güncelleme: $lastUpdated

──────────────────────────────────────
1. TARAFLAR, KONU VE KABUL
──────────────────────────────────────
Bu Kullanım Sözleşmesi ("Sözleşme"), KoruBeni uygulamasını ("Uygulama") geliştiren taraf ("Geliştirici") ile Uygulamayı cihazına kuran ve kullanan gerçek kişi ("Kullanıcı") arasında akdedilir.

Kullanıcı, Uygulamayı kurarak ve kullanarak bu Sözleşme'yi okuduğunu, anladığını ve tüm hükümleriyle kabul ettiğini beyan eder. Kullanıcı, herhangi bir hükmü kabul etmiyorsa Uygulamayı kullanmamalı ve cihazından kaldırmalıdır.

6502 Sayılı Tüketicinin Korunması Hakkında Kanun kapsamında bilgilendirme: KoruBeni temel ücretsiz kullanım ve Google Play üzerinden yönetilen isteğe bağlı KoruBeni Pro aboneliği sunabilir. Panik/SOS, güvenli yürüyüş/check-in, ses tuşu tetikleyici ve güvenlik geçmişi gibi araçlar Pro ile açılabilir. Acil kişi yönetimi, siren ve test modu bu sürümde ücretsizdir. KoruBeni profesyonel bir güvenlik hizmeti, acil müdahale servisi veya mesleki güvenlik çözümü DEĞİLDİR. Herhangi bir hizmet seviyesi taahhüdü verilmemektedir.

──────────────────────────────────────
2. TANIMLAR
──────────────────────────────────────
• Arama girişimi: Uygulamanın, cihazın işletim sistemine bir telefon araması başlatma talebi iletmesidir. Talebin işletim sistemi tarafından yerine getirilip getirilmeyeceği, aramanın kurulup kurulmayacağı ve karşı tarafın yanıt verip vermeyeceği bu tanımın DIŞINDADIR.
• Yardımcı araç: Kullanıcının kendi güvenlik planını uygulamasına destek olan, ancak bu planın yerine geçmeyen cihaz içi yazılımdır.
• Prova (Test Modu): Kullanıcının, gerçek arama yapılmaksızın akışın kendi cihazında çalışıp çalışmadığını doğrulamasını sağlayan işlevdir.
• Cihaz koşulları: İşletim sistemi sürümü ve ayarları, üretici pil yönetimi, uyku (Doze) modu, izin durumları, şebeke ve operatör durumu, şarj seviyesi, ses profili, depolama ve benzeri, Geliştiricinin kontrolü dışındaki tüm etkenlerdir.

──────────────────────────────────────
3. EDİMİN KAPSAMI VE NİTELİĞİ
──────────────────────────────────────
3.1. Geliştiricinin bu Sözleşme kapsamındaki edimi, Uygulamanın Kullanıcının cihazına kurulabilir halde sunulmasından ve belgelenen işlevleri ÖZENLE yerine getirmeye çalışmasından ibarettir.

3.2. Bu Sözleşme bir SONUÇ BORCU doğurmaz. Geliştirici; Kullanıcının güvenliğinin sağlanacağını, bir zararın önleneceğini, bir aramanın kurulacağını, bir bildirimin teslim edileceğini, bir konumun doğru olacağını veya herhangi bir işlevin belirli bir sürede tamamlanacağını TAAHHÜT ETMEMEKTEDİR.

3.3. Uygulama bir YARDIMCI ARAÇTIR. Sözleşmenin konusu bir güvenlik sonucu değil, bir araçtır. Taahhüt edilmemiş bir sonucun gerçekleşmemesi, sözleşmeye aykırılık teşkil etmez.

3.4. Kullanıcı; acil durumlarda birincil ve asli yolun 112 Acil Çağrı Merkezi'ni aramak olduğunu, Uygulamanın bu yolun yerine geçmediğini ve geçmeyeceğini kabul eder.

──────────────────────────────────────
4. UYGULAMANIN YAPMADIĞI ŞEYLER
──────────────────────────────────────
Kullanıcı, Uygulamanın aşağıdakileri YAPMADIĞINI bilerek kullandığını kabul eder:
• Resmî bir acil servis, kolluk kuvveti veya 112 hizmeti DEĞİLDİR; bunlara bağlı değildir.
• Bir alarm izleme merkezi, çağrı merkezi veya insanlı müdahale hizmeti İÇERMEZ.
• Kullanıcı adına kimseyi olay yerine YÖNLENDİRMEZ ve müdahale organize ETMEZ.
• Fiziksel koruma, caydırıcılık veya güvenlik garantisi SAĞLAMAZ.
• Kullanıcıyı arka planda TAKİP ETMEZ; konum yalnızca Kullanıcının başlattığı oturumda kullanılır.
• Geliştiriciye ait herhangi bir sunucuya acil durum verisi GÖNDERMEZ; Geliştirici hiçbir acil durumdan HABERDAR OLMAZ ve olamaz.
• Kurulumdan sonra Geliştirici tarafından İZLENMEZ, DENETLENMEZ veya bakımı ÜSTLENİLMEZ.

──────────────────────────────────────
5. BELGELENMİŞ ÇALIŞMA SINIRLARI
──────────────────────────────────────
5.1. Uygulama, cihaz koşullarına bağlı bir yazılımdır. Aşağıdaki durumlar Uygulamanın bilinen, belgelenmiş ve kabul edilmiş çalışma sınırlarıdır; bunlar ayıp, kusur veya eksik ifa SAYILMAZ:

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
l) Üçüncü taraf hizmetlerinin (harita sağlayıcı, uygulama mağazası, ödeme altyapısı) kesintisi veya sonlanması;
m) İşletim sisteminin yeni bir sürümünün mevcut davranışı değiştirmesi;
n) Bildirim tesliminin işletim sistemi tarafından geciktirilmesi veya engellenmesi;
o) Sahte çağrı işlevinin cihaz içi bir simülasyon olması ve gerçek arama başlatmaması;
p) Uygulamanın mağazadan kaldırılması veya hizmetin sonlandırılması.

5.2. Kullanıcı, bu sınırların kendisine sözleşme öncesinde açıkça bildirildiğini ve Uygulamadan beklentisini bu sınırlar dahilinde oluşturduğunu kabul eder.

──────────────────────────────────────
6. KULLANICININ DOĞRULAMA YÜKÜMLÜLÜĞÜ
──────────────────────────────────────
6.1. Uygulama, Kullanıcının akışın KENDİ CİHAZINDA çalışıp çalışmadığını gerçek arama yapılmaksızın doğrulamasını sağlayan ücretsiz bir Prova (Test Modu) işlevi sunar.

6.2. Kullanıcı; kurulumdan sonra, her önemli cihaz veya işletim sistemi değişikliğinden sonra ve düzenli aralıklarla Provayı çalıştırmayı KENDİ YÜKÜMLÜLÜĞÜ olarak kabul eder.

6.3. Kullanıcı, Uygulamanın hazırlık durumu uyarılarını (eksik izinler, pil optimizasyonu, eksik acil kişi ve benzeri) dikkate almayı kabul eder.

6.4. Provayı çalıştırmamış veya hazırlık uyarılarını dikkate almamış olan Kullanıcı, kendi cihazında doğrulanmamış bir kuruluma güvenmiş sayılır.

──────────────────────────────────────
7. KULLANICININ BEYAN VE TAAHHÜTLERİ
──────────────────────────────────────
Kullanıcı, Uygulamayı kullanarak aşağıdakileri açıkça beyan ve taahhüt eder:
7.1. 18 yaşını doldurduğunu ve tam fiil ehliyetine sahip olduğunu;
7.2. Acil durumlarda ÖNCELİKLE 112'yi arayacağını, Uygulamayı 112'nin alternatifi olarak kullanmayacağını;
7.3. Madde 5'te sayılan çalışma sınırlarını okuduğunu ve anladığını;
7.4. Provayı kendi cihazında çalıştırarak kurulumunu doğrulama yükümlülüğünün kendisinde olduğunu;
7.5. Kendi güvenlik planından, bulunduğu ortamı ve riskleri değerlendirmekten ve alacağı önlemlerden MÜNHASIRAN kendisinin sorumlu olduğunu;
7.6. Uygulamanın varlığına güvenerek, aksi halde girmeyeceği bir riske girmeyeceğini;
7.7. Acil durum kişisi olarak eklediği kişilerin açık rızasını ÖNCEDEN aldığını;
7.8. Cihazının fiziksel güvenliğinden, PIN'inin gizliliğinden ve işletim sistemi güncellemelerinden kendisinin sorumlu olduğunu;
7.9. Uygulamayı yalnızca hukuka uygun amaçlarla kullanacağını.

──────────────────────────────────────
8. KULLANICININ MÜNHASIR SORUMLULUĞU
──────────────────────────────────────
Aşağıdaki hususlar MÜNHASIRAN Kullanıcının sorumluluğundadır:
a) Acil durumda 112'yi aramak veya aramamak yönündeki kararı ve bu kararın sonuçları;
b) Kendi güvenlik planı, risk değerlendirmesi ve bulunduğu ortama ilişkin tercihleri;
c) Uygulamanın kendi cihazında çalıştığını doğrulaması;
d) Cihaz izinlerinin verilmesi ve korunması;
e) Cihazın şarjlı, açık ve çalışır durumda tutulması;
f) Acil durum kişilerinin doğru, güncel ve ulaşılabilir olması;
g) Acil durum kişilerinin rızasının alınmış olması;
h) Uygulama aracılığıyla gerçekleştirdiği tüm arama, siren, sahte çağrı ve paylaşım eylemleri;
i) Uygulamanın kötüye kullanılmasından doğan her türlü hukuki ve cezai sonuç;
j) Uygulamanın PIN ile korunması ve PIN'in üçüncü kişilerle paylaşılmaması.

──────────────────────────────────────
9. ACİL DURUM KİŞİLERİ VE ÜÇÜNCÜ KİŞİLER
──────────────────────────────────────
9.1. Kullanıcı, acil durum kişisi olarak eklediği kişilerin kişisel verilerini Uygulamaya girmeden önce bu kişilerin açık rızasını aldığını taahhüt eder.

9.2. Bu taahhüdün ihlali nedeniyle Geliştiriciye yöneltilecek her türlü talep, şikâyet, idari yaptırım ve yargılama gideri bakımından Kullanıcı, Geliştiriciye rücu sorumluluğunu kabul eder.

9.3. Acil durum kişisi olarak eklenen üçüncü kişiler, KVKK Madde 11 kapsamındaki haklarını korubeni.destek@gmail.com adresine başvurarak kullanabilir.

──────────────────────────────────────
10. YAŞ SINIRI
──────────────────────────────────────
10.1. Uygulama yalnızca 18 yaşını doldurmuş kişilerin kullanımı içindir.

10.2. 18 yaşından küçük bir kişinin Uygulamayı kullanması halinde, bu kullanımdan ve sonuçlarından o kişinin veli veya vasisi sorumludur.

10.3. Geliştirici, 18 yaşından küçük olduğunu tespit ettiği kullanıcıların erişimini sonlandırma hakkını saklı tutar.

──────────────────────────────────────
11. KÖTÜYE KULLANIM YASAĞI
──────────────────────────────────────
11.1. Sahte çağrı işlevi YALNIZCA kişisel güvenlik amaçlıdır (örneğin tacizden uzaklaşmak için ortamdan ayrılma). Dolandırıcılık, taciz, başkasını yanıltma veya herhangi bir suç eyleminde kullanılması YASAKTIR.

11.2. Uygulamanın 112 veya kolluk kuvvetlerine asılsız ihbar amacıyla kullanılması YASAKTIR ve idari ya da cezai yaptırıma tabidir.

11.3. Uygulamanın bir başkasını rızası dışında izlemek veya takip etmek amacıyla kullanılması YASAKTIR.

11.4. Bu yasakların ihlalinden doğan TÜM HUKUKİ VE CEZAİ SORUMLULUK KULLANICIYA AİTTİR.

──────────────────────────────────────
12. KONUM OTURUMU
──────────────────────────────────────
• Konum verisi yalnızca Kullanıcının açıkça tetiklemesiyle harita/konum oturumu için kullanılır.
• Gösterilen konumun doğruluğu GPS donanımına bağlıdır ve Geliştirici tarafından garanti edilmez.
• Konum alınamazsa Uygulama sahte koordinat göstermez. Çevrimiçi harita karoları OpenStreetMap bağlantısı gerektirir.

──────────────────────────────────────
13. GARANTİ REDDİ
──────────────────────────────────────
13.1. Uygulama "OLDUĞU GİBİ" (AS IS) ve "MEVCUT HALİYLE" (AS AVAILABLE) sunulmaktadır.

13.2. Geliştirici, Uygulamanın kesintisiz, hatasız veya belirli bir amaca uygun çalışacağına dair zımni dahil hiçbir garanti vermez.

13.3. Uygulama önceden bildirim yapılmaksızın değiştirilebilir, güncellenebilir veya sonlandırılabilir.

13.4. Bu madde, tüketici mevzuatından doğan ve sözleşmeyle bertaraf edilemeyen haklarınızı etkilemez.

──────────────────────────────────────
14. SORUMLULUK
──────────────────────────────────────
14.1. Geliştiricinin sorumluluğu, ancak kendi kusurunun bulunduğu hallerde ve Madde 3'te tanımlanan edim kapsamı çerçevesinde doğar.

14.2. Madde 5'te sayılan belgelenmiş çalışma sınırlarından kaynaklanan durumlar Geliştiricinin kusuru sayılmaz.

14.3. Kullanıcının Madde 6'daki doğrulama yükümlülüğünü yerine getirmemesi, doğan zararda kendi kusuru olarak değerlendirilir.

14.4. Geliştiricinin sorumlu tutulduğu hallerde toplam sorumluluğu, Kullanıcının talep tarihinden önceki son on iki (12) ay içinde Google Play üzerinden KoruBeni Pro için ödediği toplam bedeli aşamaz. Ücretli aboneliği bulunmayan Kullanıcı bakımından bu tutar sıfırdır.

14.5. Bu maddedeki sınırlamalar; Geliştiricinin kastı, ağır ihmali ve tüketici mevzuatından doğan emredici sorumluluğu bakımından UYGULANMAZ.

──────────────────────────────────────
15. TAZMİN VE RÜCU
──────────────────────────────────────
15.1. Kullanıcı; kendi hukuka aykırı fiilinden, bu Sözleşme'yi ihlalinden veya Madde 9 kapsamındaki rıza taahhüdüne aykırılığından doğan ve Geliştiriciye yöneltilen üçüncü kişi taleplerinden Geliştiriciyi tazmin etmeyi kabul eder.

15.2. Bu yükümlülük, Geliştiricinin kendi kusurundan doğan talepleri KAPSAMAZ.

──────────────────────────────────────
16. MÜCBİR SEBEP VE ÜÇÜNCÜ TARAF BAĞIMLILIKLARI
──────────────────────────────────────
16.1. Doğal afet, savaş, salgın hastalık, telekomünikasyon veya enerji altyapısı kesintisi, siber saldırı, devlet kısıtlamaları ve benzeri kontrol dışı olaylardan Geliştirici sorumlu tutulamaz.

16.2. Uygulama; işletim sistemi, uygulama mağazası, ödeme altyapısı ve harita sağlayıcısı gibi üçüncü taraf hizmetlere bağımlıdır. Bu hizmetlerin politika değişikliği, kesintisi veya sonlanması Geliştiricinin kontrolünde değildir.

──────────────────────────────────────
17. FİKRİ MÜLKİYET
──────────────────────────────────────
Uygulama ve içerdiği tüm fikri mülkiyet hakları Geliştiriciye aittir. Kullanıcıya yalnızca kişisel, devredilemez ve münhasır olmayan bir kullanım lisansı verilmektedir.

──────────────────────────────────────
18. UYGULANACAK HUKUK VE UYUŞMAZLIK ÇÖZÜMÜ
──────────────────────────────────────
18.1. Bu Sözleşme Türkiye Cumhuriyeti hukukuna tabidir.

18.2. Tüketici sıfatını haiz Kullanıcı, 6502 Sayılı Kanun uyarınca parasal sınırlara göre KENDİ YERLEŞİM YERİNDEKİ Tüketici Hakem Heyeti'ne veya Tüketici Mahkemesi'ne başvurabilir. Bu hak sözleşmeyle sınırlandırılamaz.

──────────────────────────────────────
19. BÖLÜNEBİLİRLİK VE DEĞİŞİKLİKLER
──────────────────────────────────────
19.1. Herhangi bir hükmün geçersiz sayılması halinde, Sözleşme'nin diğer hükümleri yürürlükte kalır. Geçersiz hüküm, tarafların amacına en yakın geçerli hükümle ikame edilmiş sayılır.

19.2. Geliştirici bu Sözleşme'yi güncelleyebilir. Esaslı değişikliklerde Uygulama yeniden onay ister. Onay verilmemesi halinde Kullanıcı Uygulamayı kullanmaya devam edemez.

İletişim: korubeni.destek@gmail.com
''';

  // ── Kullanım Sözleşmesi — İngilizce ──────────────────────────────────────
  static const String termsOfServiceEn =
      '''
TERMS OF SERVICE (END USER LICENSE AGREEMENT — EULA)
Version $termsVersion | Last Updated: $lastUpdatedEn

──────────────────────────────────────
1. PARTIES, SUBJECT AND ACCEPTANCE
──────────────────────────────────────
This Terms of Service Agreement ("Agreement") is entered into between the party developing the KoruBeni application (the "Application") ("Developer") and the natural person installing and using the Application ("User").

By installing and using the Application, the User declares that they have read, understood and accepted this Agreement in full. A User who does not accept any provision must not use the Application and must remove it from their device.

Notice under Consumer Protection Law No. 6502: KoruBeni may offer basic free functionality and an optional KoruBeni Pro subscription managed through Google Play. Tools such as Panic/SOS, safe walk/check-in, volume trigger and safety history may unlock with Pro. Emergency contact management, siren and test mode are free in this release. KoruBeni is NOT a professional security service, an emergency response service, or a professional security solution. No service level commitment is provided.

──────────────────────────────────────
2. DEFINITIONS
──────────────────────────────────────
• Call attempt: the Application submitting a request to the device operating system to place a telephone call. Whether the operating system fulfils that request, whether the call is established, and whether the other party answers are OUTSIDE this definition.
• Auxiliary tool: on-device software that supports the User in carrying out their own safety plan but does not replace that plan.
• Rehearsal (Test Mode): the function allowing the User to verify, without placing a real call, whether the flow works on their own device.
• Device conditions: operating system version and settings, manufacturer battery management, sleep (Doze) mode, permission states, network and carrier status, charge level, sound profile, storage and all similar factors outside the Developer's control.

──────────────────────────────────────
3. SCOPE AND NATURE OF THE OBLIGATION
──────────────────────────────────────
3.1. The Developer's obligation under this Agreement consists of making the Application available for installation on the User's device and endeavouring, WITH DUE CARE, to perform the documented functions.

3.2. This Agreement creates NO OBLIGATION OF RESULT. The Developer does NOT UNDERTAKE that the User's safety will be secured, that any harm will be prevented, that a call will be established, that a notification will be delivered, that a location will be accurate, or that any function will complete within a given time.

3.3. The Application is an AUXILIARY TOOL. The subject of this Agreement is a tool, not a safety outcome. The non-occurrence of a result that was never undertaken does not constitute a breach of this Agreement.

3.4. The User accepts that the primary and principal course of action in an emergency is to call the 112 Emergency Call Centre, and that the Application neither replaces nor will replace that course of action.

──────────────────────────────────────
4. WHAT THE APPLICATION DOES NOT DO
──────────────────────────────────────
The User accepts that they use the Application knowing that it does NOT do the following:
• It is NOT an official emergency service, law enforcement body or 112 service, and is not connected to any of them.
• It does NOT include an alarm monitoring centre, call centre or human response service.
• It does NOT direct anyone to a scene on the User's behalf and does NOT organise any response.
• It does NOT provide physical protection, deterrence or any safety guarantee.
• It does NOT track the User in the background; location is used only within a session the User starts.
• It does NOT send emergency data to any server belonging to the Developer; the Developer is NOT and cannot be AWARE of any emergency.
• After installation it is NOT monitored, supervised or maintained by the Developer.

──────────────────────────────────────
5. DOCUMENTED OPERATING LIMITS
──────────────────────────────────────
5.1. The Application is software dependent on device conditions. The following are known, documented and accepted operating limits of the Application; they do NOT constitute a defect, fault or deficient performance:

a) The operating system delaying or stopping background work in sleep (Doze) mode;
b) The device manufacturer's battery management software terminating or restricting the Application;
c) A call failing or being delayed due to the network, carrier or base station;
d) The called person not answering, being busy or being unreachable;
e) The device running out of charge, powering off, or hardware failure;
f) The User not granting, or revoking, the required permissions (phone, location, notification, alarm);
g) An operating system update changing permissions, alarms or background behaviour;
h) Restrictions applied by the operating system while the device is locked;
i) The siren not being heard due to the device sound profile, silent mode or volume level;
j) Location deviations arising from the accuracy margin of GPS hardware;
k) Map tiles failing to load because there is no internet connection;
l) Interruption or discontinuation of third-party services (map provider, application store, payment infrastructure);
m) A new operating system version changing existing behaviour;
n) Notification delivery being delayed or blocked by the operating system;
o) The fake call function being an on-device simulation that does not place a real call;
p) The Application being removed from the store or the service being discontinued.

5.2. The User accepts that these limits were expressly disclosed to them before contracting and that their expectations of the Application are formed within these limits.

──────────────────────────────────────
6. THE USER'S VERIFICATION DUTY
──────────────────────────────────────
6.1. The Application provides a free Rehearsal (Test Mode) function allowing the User to verify, without placing a real call, whether the flow works ON THEIR OWN DEVICE.

6.2. The User accepts as THEIR OWN DUTY to run the Rehearsal after installation, after every significant device or operating system change, and at regular intervals.

6.3. The User accepts to take account of the Application's readiness warnings (missing permissions, battery optimisation, missing emergency contact and the like).

6.4. A User who has not run the Rehearsal or has disregarded the readiness warnings is deemed to have relied on an installation that was not verified on their own device.

──────────────────────────────────────
7. THE USER'S DECLARATIONS AND UNDERTAKINGS
──────────────────────────────────────
By using the Application, the User expressly declares and undertakes:
7.1. That they are at least 18 years old and have full legal capacity;
7.2. That they will call 112 FIRST in an emergency and will not use the Application as an alternative to 112;
7.3. That they have read and understood the operating limits listed in Article 5;
7.4. That the duty to verify their installation by running the Rehearsal on their own device rests with them;
7.5. That they are SOLELY responsible for their own safety plan, for assessing their environment and risks, and for the precautions they take;
7.6. That they will not, in reliance on the existence of the Application, take a risk they would not otherwise take;
7.7. That they obtained the express consent of the persons they add as emergency contacts IN ADVANCE;
7.8. That they are responsible for the physical security of their device, the confidentiality of their PIN, and operating system updates;
7.9. That they will use the Application only for lawful purposes.

──────────────────────────────────────
8. THE USER'S EXCLUSIVE RESPONSIBILITY
──────────────────────────────────────
The following are the EXCLUSIVE responsibility of the User:
a) The decision whether or not to call 112 in an emergency, and the consequences of that decision;
b) Their own safety plan, risk assessment and choices regarding the environment they are in;
c) Verifying that the Application works on their own device;
d) Granting and preserving device permissions;
e) Keeping the device charged, powered on and operational;
f) The emergency contacts being correct, current and reachable;
g) The consent of the emergency contacts having been obtained;
h) All call, siren, fake call and sharing actions performed through the Application;
i) Any and all civil and criminal consequences arising from misuse of the Application;
j) Protecting the Application with a PIN and not sharing that PIN with third parties.

──────────────────────────────────────
9. EMERGENCY CONTACTS AND THIRD PARTIES
──────────────────────────────────────
9.1. The User undertakes that they obtained the express consent of the persons added as emergency contacts before entering their personal data into the Application.

9.2. The User accepts recourse liability towards the Developer for any claim, complaint, administrative sanction and litigation cost directed at the Developer as a result of a breach of this undertaking.

9.3. Third parties added as emergency contacts may exercise their rights under KVKK Article 11 by contacting korubeni.destek@gmail.com.

──────────────────────────────────────
10. AGE RESTRICTION
──────────────────────────────────────
10.1. The Application is intended solely for use by persons who are at least 18 years old.

10.2. Where a person under 18 uses the Application, the parent or legal guardian of that person is responsible for that use and its consequences.

10.3. The Developer reserves the right to terminate access for users it determines to be under 18.

──────────────────────────────────────
11. PROHIBITION OF MISUSE
──────────────────────────────────────
11.1. The fake call function is ONLY for personal safety purposes (for example, leaving a situation to escape harassment). Using it for fraud, harassment, deception of others or any criminal act is PROHIBITED.

11.2. Using the Application to make a false report to 112 or to law enforcement is PROHIBITED and is subject to administrative or criminal sanction.

11.3. Using the Application to monitor or track another person without their consent is PROHIBITED.

11.4. ALL CIVIL AND CRIMINAL LIABILITY arising from a breach of these prohibitions BELONGS TO THE USER.

──────────────────────────────────────
12. LOCATION SESSION
──────────────────────────────────────
• Location data is used for a map/location session only when expressly triggered by the User.
• The accuracy of the displayed location depends on GPS hardware and is not guaranteed by the Developer.
• If location cannot be obtained, the Application does not display fabricated coordinates. Online map tiles require an OpenStreetMap connection.

──────────────────────────────────────
13. DISCLAIMER OF WARRANTIES
──────────────────────────────────────
13.1. The Application is provided "AS IS" and "AS AVAILABLE".

13.2. The Developer gives no warranty, including any implied warranty, that the Application will operate uninterrupted, error-free or fit for a particular purpose.

13.3. The Application may be changed, updated or discontinued without prior notice.

13.4. This Article does not affect your rights arising from consumer legislation that cannot be excluded by contract.

──────────────────────────────────────
14. LIABILITY
──────────────────────────────────────
14.1. The Developer's liability arises only where the Developer is at fault and within the scope of the obligation defined in Article 3.

14.2. Situations arising from the documented operating limits listed in Article 5 do not constitute fault of the Developer.

14.3. The User's failure to perform the verification duty in Article 6 is assessed as the User's own contributory fault in any resulting damage.

14.4. Where the Developer is held liable, total liability shall not exceed the total amount paid by the User through Google Play for KoruBeni Pro in the twelve (12) months preceding the claim. For a User without a paid subscription this amount is zero.

14.5. The limitations in this Article do NOT APPLY to the Developer's intent, gross negligence, or mandatory liability arising from consumer legislation.

──────────────────────────────────────
15. INDEMNIFICATION AND RECOURSE
──────────────────────────────────────
15.1. The User agrees to indemnify the Developer against third-party claims directed at the Developer arising from the User's own unlawful act, breach of this Agreement, or breach of the consent undertaking in Article 9.

15.2. This obligation does NOT COVER claims arising from the Developer's own fault.

──────────────────────────────────────
16. FORCE MAJEURE AND THIRD-PARTY DEPENDENCIES
──────────────────────────────────────
16.1. The Developer cannot be held liable for natural disasters, war, epidemics, telecommunications or energy infrastructure outages, cyber attacks, governmental restrictions and similar events beyond its control.

16.2. The Application depends on third-party services such as the operating system, the application store, the payment infrastructure and the map provider. Policy changes, interruption or discontinuation of these services are outside the Developer's control.

──────────────────────────────────────
17. INTELLECTUAL PROPERTY
──────────────────────────────────────
The Application and all intellectual property rights contained therein belong to the Developer. The User is granted only a personal, non-transferable, non-exclusive licence to use it.

──────────────────────────────────────
18. GOVERNING LAW AND DISPUTE RESOLUTION
──────────────────────────────────────
18.1. This Agreement is governed by the laws of the Republic of Turkey.

18.2. A User who qualifies as a consumer may, according to the monetary thresholds under Law No. 6502, apply to the Consumer Arbitration Committee or the Consumer Court AT THEIR OWN PLACE OF RESIDENCE. This right cannot be restricted by contract.

──────────────────────────────────────
19. SEVERABILITY AND AMENDMENTS
──────────────────────────────────────
19.1. If any provision is held invalid, the remaining provisions of this Agreement remain in force. The invalid provision is deemed replaced by the valid provision closest to the parties' intent.

19.2. The Developer may update this Agreement. For material changes the Application will request re-consent. If consent is not given, the User may not continue to use the Application.

Contact: korubeni.destek@gmail.com
''';

  // ── KVKK Aydınlatma Metni — Türkçe ───────────────────────────────────────
  static const String kvkkDisclosureTr =
      '''
KİŞİSEL VERİLERİN KORUNMASI KANUNU (KVKK)
AYDINLATMA METNİ
Sürüm $kvkkVersion | Son Güncelleme: $lastUpdatedKvkk

6698 Sayılı Kişisel Verilerin Korunması Kanunu ("KVKK") Madde 10 kapsamında aydınlatma metnidir.

──────────────────────────────────────
1. VERİ SORUMLUSUNUN KİMLİĞİ
──────────────────────────────────────
Veri Sorumlusu : Poyraz Öncel ("KoruBeni" uygulamasının geliştiricisi)
Adres          : İzmir, Türkiye
İletişim       : korubeni.destek@gmail.com

──────────────────────────────────────
2. İŞLENEN KİŞİSEL VERİLER
──────────────────────────────────────
Kategori          | Veri                              | Amaç                                  | Hukuki Sebep
────────────────────────────────────────────────────────────────────────────────────────────────────────
Kimlik            | Ad                                | Uygulama profili                      | Açık rıza
Görsel            | İsteğe bağlı sahte çağrı avatarı  | Sahte çağrı kişiselleştirme           | Açık rıza
İletişim          | Acil kişi adı, telefon numarası   | Acil durumda arama akışı              | Açık rıza
Konum             | GPS koordinatları                 | Harita ve konum oturumu               | Açık rıza
Güvenlik          | PIN kodu (şifreli)                | Uygulama erişim kontrolü              | Meşru menfaat
Cihaz             | Cihaz tipi, OS versiyonu          | Teknik uyumluluk & rıza logu          | Meşru menfaat
Yasal Rıza Logu   | Rıza türü, tarih, versiyon        | KVKK uyum kaydı                       | Hukuki yükümlülük
Abonelik (Pro)    | IP, cihaz bilgisi, abone kimliği  | Pro abonelik doğrulama (RevenueCat)   | Sözleşmenin ifası
Harita ağı        | IP, User-Agent, karo koordinatı   | OpenStreetMap karolarını göstermek    | Açık rıza
Aktif oturum      | Numara, token, tür ve son tarihler| Alarmı reboot/Doze sırasında sürdürmek| Sözleşmenin ifası

──────────────────────────────────────
3. VERİLERİN İŞLENME AMACI
──────────────────────────────────────
• Acil arama, harita ve konum oturumu işlevlerinin sağlanması
• Uygulama güvenliğinin ve erişim kontrolünün sağlanması
• KVKK kapsamında rıza kayıtlarının tutulması
• Kullanıcı deneyiminin kişiselleştirilmesi

──────────────────────────────────────
4. VERİ AKTARIMI
──────────────────────────────────────
Kişisel verileriniz geliştiriciye ait bir backend sunucusuna aktarılmaz. Uygulama verilerinin ana kopyası cihazınızda saklanır. Çevrimiçi harita açıldığında OpenStreetMap karo sağlayıcısına IP adresi, uygulamanın User-Agent bilgisi ve istenen karo koordinatları gider; bu koordinatlardan görüntülenen yaklaşık harita alanı çıkarılabilir. İsteğe bağlı Pro abonelik Google Play Billing üzerinden yönetilir; RevenueCat abonelik/yetki durumunu doğrulamaya yardımcı olabilir. Acil akış otomatik mesaj göndermez.

RevenueCat yalnız güncel Kullanım Şartları ve KVKK akışı tamamlandıktan sonra; kullanıcı Pro/paywall/restore ekranına girdiğinde veya cihazda daha önce doğrulanmış Pro kullanımına ilişkin yalnız başlatma amacı taşıyan yerel ipucu varsa yapılandırılır. Bu ipucu Pro hakkı kanıtı değildir. Yapılandırıldığında abonelik doğrulaması için sınırlı teknik veri (IP adresi, cihaz/işletim sistemi bilgisi, anonim abone kimliği ve satın alma olayları) RevenueCat'e; ödeme olayları Google Play'e aktarılabilir. RevenueCat, Google ve OpenStreetMap sağlayıcılarının yurt dışında veri işlemesi KVKK Madde 9 kapsamındadır ve yayımdan önce uygulanabilir aktarım mekanizması ile hizmet sağlayıcı kayıtları veri sorumlusu tarafından tamamlanır. Uygulama reklam/atıf kimliği toplamaz.

Uygulama tüm rehber listesini okumaz. Yalnızca kullanıcının sistem seçicisinde seçtiği veya elle girdiği acil kişiler uygulamaya özel güvenli cihaz depolamasında saklanır.

──────────────────────────────────────
5. VERİ SAKLAMA SÜRELERİ
──────────────────────────────────────
• Profil bilgileri     : Uygulama kullanıldığı sürece; siz silene kadar
• Sahte çağrı avatarı  : Siz silene veya uygulama verisini temizleyene kadar
• Acil durum kişileri  : Yalnızca seçtiğiniz veya girdiğiniz kişiler; siz silene kadar
• Konum bilgisi        : Yalnızca aktif konum oturumu sırasında cihaz belleğinde geçici olarak tutulur; oturum bittiğinde silinir ve kalıcı olarak saklanmaz
• Harita karoları      : Uygulamaya özel yerel cache'te sağlayıcının HTTP cache talimatları süresince; talimat yoksa yedi gün. Cache 128 MiB ile sınırlıdır; süresi dolan/bozuk karolar açılışta, tüm karolar cihaz verisi silindiğinde temizlenir
• Rıza logları         : Uygulama kullanıldığı sürece; cihaz verisini silene kadar
• Abonelik verisi      : Doğrulama amacıyla RevenueCat/Google Play tarafından kendi saklama politikaları süresince işlenir; geliştirici ayrıca saklamaz
• PIN (şifreli)        : Siz değiştirene veya silene kadar
• Aktif oturum zarfı   : Oturum terminal duruma gelene, doğrulanmış iptal veya cihaz verisi silme tamamlanana kadar; iptalde hedef numara hemen silinir
• Manuel arama fallback: Bildirim eylemi kullanıldığında, bildirim kapatıldığında veya en geç 24 saat sonunda silinir

──────────────────────────────────────
6. VERİ GÜVENLİĞİ
──────────────────────────────────────
• PIN bilgisi FlutterSecureStorage üzerinde saklanmaktadır.
• Acil kişi verisi uygulamaya özel güvenli cihaz depolamasında saklanır; Android yedekleme kapalıdır ve eski gereksiz kopyalar temizlenir.
• Reboot öncesi kurulmuş güvenlik oturumunu sürdürebilmek için cihaz kilidi açılmadan erişilebilen uygulamaya özel alanda yalnız protokol/sürüm, rastgele token, generation, oturum türü, normalize hedef, son tarihler ve zamanlama modu tutulur. PIN, kişi adı, konum, geçmiş, RevenueCat kimliği ve serbest metin log bu alana yazılmaz.
• Uygulama geliştirici backend'ine kişisel veri göndermez; OpenStreetMap, Google Play Billing ve RevenueCat ağ aktarımları yukarıda ayrıca açıklanmıştır.

──────────────────────────────────────
7. ÜÇÜNCÜ KİŞİ VERİ SAHİPLERİNİN HAKLARI
──────────────────────────────────────
Kullanıcı tarafından acil durum kişisi olarak eklenen üçüncü kişiler de veri sahibi sıfatıyla KVKK Madde 11 kapsamındaki tüm haklardan yararlanır. Bu kişiler, verilerinin silinmesini veya düzeltilmesini talep etmek için korubeni.destek@gmail.com adresine başvurabilir.

──────────────────────────────────────
8. HAKLARINIZ (KVKK Madde 11)
──────────────────────────────────────
KVKK kapsamında aşağıdaki haklara sahipsiniz:
a) Kişisel veri işlenip işlenmediğini öğrenme
b) İşlenmişse buna ilişkin bilgi talep etme
c) İşlenme amacını ve amacına uygun kullanılıp kullanılmadığını öğrenme
d) Yurt içinde veya yurt dışında aktarıldığı üçüncü kişileri bilme
e) Eksik veya yanlış işlenmiş olması halinde düzeltilmesini isteme
f) KVKK'nın 7. maddesi çerçevesinde silinmesini veya yok edilmesini isteme
g) Düzeltme/silme işlemlerinin aktarılan üçüncü kişilere bildirilmesini isteme
ğ) İşlenen verilerin münhasıran otomatik sistemler ile analiz edilmesi suretiyle kişinin kendisi aleyhine bir sonucun ortaya çıkmasına itiraz etme
h) Kanuna aykırı olarak işlenmesi sebebiyle zarara uğraması halinde zararın giderilmesini talep etme

──────────────────────────────────────
9. BAŞVURU YÖNTEMİ
──────────────────────────────────────
Haklarınızı kullanmak için aşağıdaki e-posta adresine yazılı başvuruda bulunabilirsiniz:

E-posta: korubeni.destek@gmail.com
Yanıt Süresi: En geç 30 (otuz) gün
Konu Satırı: "KVKK Başvurusu"

Başvurunuzda; adınızı, soyadınızı, başvuruya konu talebinizi ve iletişim bilgilerinizi belirtmeniz gerekmektedir.

──────────────────────────────────────
10. AYDINLATMA METNİ DEĞİŞİKLİKLERİ
──────────────────────────────────────
Bu metin, KVKK ve ilgili mevzuattaki değişiklikler doğrultusunda güncellenebilir. Önemli değişikliklerde uygulama yeniden onay isteyecektir.
''';

  // ── KVKK Aydınlatma Metni — İngilizce ────────────────────────────────────
  static const String kvkkDisclosureEn =
      '''
PERSONAL DATA PROTECTION LAW (KVKK)
DISCLOSURE NOTICE
Version $kvkkVersion | Last Updated: $lastUpdatedKvkkEn

This disclosure notice is provided pursuant to Article 10 of Law No. 6698 on the Protection of Personal Data ("KVKK").

──────────────────────────────────────
1. DATA CONTROLLER IDENTITY
──────────────────────────────────────
Data Controller : Poyraz Öncel (developer of the "KoruBeni" application)
Address         : İzmir, Türkiye
Contact         : korubeni.destek@gmail.com

──────────────────────────────────────
2. PERSONAL DATA PROCESSED
──────────────────────────────────────
Category          | Data                              | Purpose                               | Legal Basis
─────────────────────────────────────────────────────────────────────────────────────────────────────────
Identity          | Name                              | Application profile                   | Explicit consent
Visual            | Optional fake-call avatar         | Fake call personalization             | Explicit consent
Contact           | Emergency contact name, phone     | Emergency call flow                   | Explicit consent
Location          | GPS coordinates                   | Map and location session              | Explicit consent
Security          | PIN code (encrypted)              | App access control                    | Legitimate interest
Device            | Device type, OS version           | Technical compatibility & consent log | Legitimate interest
Legal Consent Log | Consent type, date, version       | KVKK compliance record                | Legal obligation
Subscription (Pro)| IP, device info, subscriber ID    | Pro subscription verification         | Contract performance
Map network       | IP, User-Agent, tile coordinates  | Display OpenStreetMap tiles            | Explicit consent
Active session    | Number, token, kind and deadlines | Survive reboot/Doze alarm delivery      | Contract performance

──────────────────────────────────────
3. PURPOSES OF PROCESSING
──────────────────────────────────────
• Providing emergency call, map and location-session features
• Ensuring application security and access control
• Maintaining consent records under KVKK
• Personalizing the user experience

──────────────────────────────────────
4. DATA TRANSFER
──────────────────────────────────────
Your personal data is not transferred to a developer-operated backend. The primary copy of app data is stored on your device. When the online map is opened, the OpenStreetMap tile provider receives the IP address, the app User-Agent, and requested tile coordinates; those coordinates can reveal the approximate map viewport. Optional Pro subscriptions are managed through Google Play Billing, and RevenueCat may help verify subscription/entitlement status. The emergency flow does not send automatic messages.

RevenueCat is configured only after the current Terms and KVKK flow is completed and the user enters a Pro/paywall/restore flow, or when a local prior-Pro initialization hint exists. That hint is not proof of entitlement. Once configured, limited technical data (IP address, device/OS information, an anonymous subscriber ID, and purchase events) may be transferred to RevenueCat; payment events may be transferred to Google Play. Processing abroad by RevenueCat, Google, and OpenStreetMap falls under Article 9 of KVKK; the applicable transfer mechanism and provider records must be completed by the data controller before publication. The app does not collect advertising/attribution identifiers.

The app does not read the full contacts list. It stores only emergency contacts selected through the system picker or entered by the user in app-private secure on-device storage.

──────────────────────────────────────
5. DATA RETENTION PERIODS
──────────────────────────────────────
• Profile information      : While the app is in use; until you delete it
• Fake call avatar         : Until you delete it or clear app data
• Emergency contacts       : Only contacts you select or enter; until you delete them
• Location data            : Held only in device memory while a location session is active; cleared when the session ends and never persisted
• Map tiles                : In an app-private local cache for the provider's HTTP cache lifetime, or seven days when no usable directive is supplied. The cache is limited to 128 MiB; expired/corrupt tiles are purged at startup and all tiles are removed when app data is cleared
• Consent logs             : While the app is in use; until device data deletion
• Subscription data        : Processed by RevenueCat/Google Play under their own retention policies for verification; not additionally stored by the developer
• PIN (encrypted)          : Until you change or delete it
• Active-session envelope  : Until terminal state, acknowledged cancellation, or completed device-data deletion; the target is removed immediately on cancellation
• Manual-call fallback     : Removed on action, dismissal, or no later than 24 hours

──────────────────────────────────────
6. DATA SECURITY
──────────────────────────────────────
• PIN information is stored in FlutterSecureStorage.
• Emergency contact data is stored in app-private secure on-device storage; Android backup is disabled and unnecessary legacy copies are cleaned up.
• To preserve a previously armed safety session across reboot, the app-private device-protected area contains only protocol/schema version, random token, generation, session kind, normalized target, deadlines, and scheduling mode. PIN, contact name, location, history, RevenueCat ID, and free-text logs are not stored there.
• The application does not send personal data to a developer backend; OpenStreetMap, Google Play Billing, and RevenueCat network transfers are separately disclosed above.

──────────────────────────────────────
7. THIRD-PARTY DATA SUBJECT RIGHTS
──────────────────────────────────────
Third parties added as emergency contacts by the User also hold data subject status and benefit from all rights under KVKK Article 11. These persons may contact korubeni.destek@gmail.com to request deletion or correction of their data.

──────────────────────────────────────
8. YOUR RIGHTS (KVKK Article 11)
──────────────────────────────────────
Under KVKK, you have the following rights:
a) To learn whether personal data is processed
b) To request information about processing if it is
c) To learn the purpose of processing and whether it is used in accordance with its purpose
d) To know the third parties to whom data is transferred domestically or abroad
e) To request correction if data is incomplete or incorrectly processed
f) To request deletion or destruction under Article 7 of KVKK
g) To request notification of correction/deletion to third parties to whom data was transferred
ğ) To object to a result arising against oneself through the analysis of processed data exclusively by automated systems
h) To demand compensation for damages in case of unlawful processing

──────────────────────────────────────
9. APPLICATION METHOD
──────────────────────────────────────
To exercise your rights, you may apply in writing to the following email address:

E-mail       : korubeni.destek@gmail.com
Response Time: At most 30 (thirty) days
Subject Line : "KVKK Application"

In your application, please include your name, surname, the subject of your request, and contact information.

──────────────────────────────────────
10. CHANGES TO DISCLOSURE NOTICE
──────────────────────────────────────
This notice may be updated in line with changes to KVKK and related legislation. For significant changes, the application will request re-consent.
''';
}
