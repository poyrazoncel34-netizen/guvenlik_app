// ============================================================================
// YASAL METİNLER SABİTLERİ
// Tüm uzun yasal metinler versiyonlanmış olarak burada tutulur.
// Versiyon değiştiğinde LegalVersionChecker kullanıcıyı tekrar onay akışına yönlendirir.
// ============================================================================

class LegalTexts {
  // ── Sürüm Numaraları ──────────────────────────────────────────────────────
  static const String termsVersion = '3.1.0';
  static const String kvkkVersion = '3.3.0';
  static const String lastUpdated = '21 Mayıs 2026';
  static const String lastUpdatedEn = 'May 21, 2026';
  // KVKK/Gizlilik/Aydınlatma belgeleri kendi revizyon tarihini taşır;
  // Kullanım Şartları (termsVersion) içerik değişmediği için lastUpdated'ı korur.
  static const String lastUpdatedKvkk = '18 Temmuz 2026';
  static const String lastUpdatedKvkkEn = 'July 18, 2026';

  // ── Kullanım Sözleşmesi — Türkçe ─────────────────────────────────────────
  static const String termsOfServiceTr =
      '''
KULLANIM SÖZLEŞMESİ (SON KULLANICI LİSANS SÖZLEŞMESİ — EULA)
Sürüm $termsVersion | Son Güncelleme: $lastUpdated

Bu Kullanım Sözleşmesi ("Sözleşme"), KoruBeni ("Geliştirici") ile uygulamayı indiren ve kullanan kişi ("Kullanıcı") arasında akdedilmektedir. Uygulamayı kullanarak bu Sözleşme'nin tüm koşullarını okuduğunuzu, anladığınızı ve kabul ettiğinizi beyan etmiş olursunuz.

──────────────────────────────────────
1. UYGULAMANIN AMACI VE KAPSAMI
──────────────────────────────────────
KoruBeni, kişisel güvenlik farkındalığını desteklemek amacıyla geliştirilmiş bir Android yardımcı uygulamadır. Uygulama temel ücretsiz kullanım sunabilir. Panik/SOS, güvenli yürüyüş/check-in, ses tuşu tetikleyici, test modu ve güvenlik geçmişi gibi ek araçlar isteğe bağlı KoruBeni Pro aboneliğiyle açılabilir. Acil kişi yönetimi ve siren bu sürümde ücretsiz araçlardır.

6502 Sayılı Tüketicinin Korunması Hakkında Kanun kapsamında bilgilendirme: KoruBeni temel ücretsiz kullanım ve Google Play üzerinden yönetilen isteğe bağlı Pro abonelik sunabilir. Profesyonel güvenlik hizmeti, acil müdahale servisi veya herhangi bir mesleki güvenlik çözümü DEĞİLDİR. Herhangi bir hizmet seviyesi taahhüdü verilmemektedir.

──────────────────────────────────────
2. YAŞ SINIRI
──────────────────────────────────────
Bu uygulamayı kullanmak için 18 yaşından büyük olmanız gerekmektedir. Bu sürümde 18 yaş altı kullanım desteklenmez. Kullanıcı, yaş beyanının doğruluğundan münhasıran kendisi sorumludur.

──────────────────────────────────────
3. SORUMLULUK REDDİ (DİSCLAIMER)
──────────────────────────────────────
• Bu uygulama profesyonel güvenlik hizmeti, acil servis veya polis hizmetinin yerini ALMAZ ve ALMAYACAKTIR.
• Acil durumlarda 112'yi aramak KULLANICININ SORUMLULUĞUNDADIR. Uygulama yalnızca yardımcı bir araçtır.
• Uygulama; arama bağlantısını, konum doğruluğunu veya bildirim teslimatını garanti ETMEZ.
• Ağ sorunları, cihaz ayarları, operatör kaynaklı aksaklıklar veya pil tükenmesi nedeniyle yaşanan gecikmeler ve iletim hatalarından GELİŞTİRİCİ SORUMLU TUTULAMAZ.
• GPS donanımının doğruluk payından kaynaklanan konum hatalarından geliştirici sorumlu değildir.

──────────────────────────────────────
4. KULLANICI SORUMLULUKLARI
──────────────────────────────────────
Kullanıcı aşağıdakileri kabul eder:
• Uygulamayı yalnızca yasal amaçlarla ve iyi niyetle kullanacağını,
• Uygulamayı kötüye kullanmayacağını, sahte acil durum bildirimi yapmayacağını,
• Üçüncü kişilerin haklarını ihlal etmeyeceğini,
• Uygulama aracılığıyla gerçekleştirilen tüm eylemlerden münhasıran kendisinin sorumlu olduğunu,
• Türk Ceza Kanunu başta olmak üzere yürürlükteki tüm mevzuata uyacağını.

──────────────────────────────────────
5. SAHTE ÇAĞRI ÖZELLİĞİ
──────────────────────────────────────
Sahte çağrı özelliği YALNIZCA kişisel güvenlik amaçlı tasarlanmıştır (örn. tacizden kaçmak için ortamdan uzaklaşma). Bu özelliğin dolandırıcılık, taciz, başkasını yanıltma veya herhangi bir suç eyleminde kullanılması YASALARA AYKIRIDIR. Söz konusu kötüye kullanımlardan doğan TÜM HUKUKİ VE CEZAİ SORUMLULUK KULLANICIYA AİTTİR.

──────────────────────────────────────
6. KONUM OTURUMU
──────────────────────────────────────
• Konum verisi yalnızca kullanıcının açıkça tetiklemesiyle harita/konum oturumu için kullanılır.
• Gösterilen konumun doğruluğu GPS donanımına bağlıdır; geliştirici tarafından garanti edilmez.
• Konum alınamazsa uygulama sahte koordinat göstermez. Çevrimiçi harita karoları OpenStreetMap bağlantısı gerektirir.

──────────────────────────────────────
7. ACİL DURUM KİŞİLERİ VE ÜÇÜNCÜ KİŞİ HAKLARI
──────────────────────────────────────
• Kullanıcı, acil durum kişisi olarak eklediği kişilerin ad ve telefon numarası bilgilerini kaydetme ve bu kişileri acil durumda arama yetkisine sahip olduğunu beyan eder.
• Bu kişilerin KVKK kapsamındaki haklarından kullanıcı sorumludur. Kişilerin rızasının alınması kullanıcının yükümlülüğündedir.
• Acil durum kişisi olarak eklenen üçüncü kişiler, KVKK Madde 11 kapsamındaki haklarını korubeni.destek@gmail.com adresine başvurarak kullanabilir. Geliştirici, başvuru üzerine ilgili veriyi kullanıcıya bildirerek silinmesini talep edecektir.

──────────────────────────────────────
8. GARANTİ REDDİ
──────────────────────────────────────
Uygulama "OLDUĞU GİBİ" (AS IS) sunulmaktadır. Kesintisiz, hatasız veya belirli bir amaca uygun çalışacağına dair HİÇBİR GARANTİ verilmemektedir. Uygulama herhangi bir zamanda önceden bildirim yapılmaksızın değiştirilebilir, güncellenebilir veya hizmet durdurulabilir.

──────────────────────────────────────
9. SORUMLULUK SINIRLANDIRMASI
──────────────────────────────────────
Geliştirici; uygulamanın kullanımından veya kullanılamamasından kaynaklanan doğrudan, dolaylı, arızi, özel veya sonuç olarak ortaya çıkan HİÇBİR ZARARDAN (can kaybı, maddi kayıp, veri kaybı dahil) sorumlu tutulamaz. Bu sınırlama, TBK m.115 uyarınca ağır kusur ve kasıt hallerini kapsamamaktadır.

Geliştiricinin toplam sorumluluğu, kullanıcının talep tarihinden önceki son 12 (on iki) ay içinde Google Play üzerinden KoruBeni Pro için ödediği toplam bedeli aşamaz. Ücretli aboneliği olmayan kullanıcılar için bu tutar 0 TL'dir.

──────────────────────────────────────
10. TAZMİN (INDEMNIFICATION)
──────────────────────────────────────
Kullanıcı, uygulamanın kullanımından kaynaklanan üçüncü kişi talep, dava veya zararlarından geliştiricinin zarar görmemesini sağlamayı ve doğacak makul avukatlık ücretleri dahil tüm zararları tazmin etmeyi kabul eder.

──────────────────────────────────────
11. MÜCBİR SEBEP
──────────────────────────────────────
Doğal afet, savaş, salgın hastalık, internet/telekomünikasyon altyapısı kesintisi, enerji kesintisi, devlet kısıtlamaları veya kontrol dışı benzeri olaylar ("mücbir sebep") nedeniyle uygulamanın çalışmaması veya gecikmesinden geliştirici sorumlu tutulamaz.

──────────────────────────────────────
12. FİKRİ MÜLKİYET
──────────────────────────────────────
Uygulama ve içerdiği tüm fikri mülkiyet hakları KoruBeni'ye aittir. Kullanıcıya yalnızca kişisel, devredilemez, münhasır olmayan bir kullanım lisansı verilmektedir.

──────────────────────────────────────
13. UYGULANACAK HUKUK VE YETKİLİ MAHKEME
──────────────────────────────────────
Bu Sözleşme Türkiye Cumhuriyeti hukukuna tabidir. Bu Sözleşme'den doğan uyuşmazlıklarda İzmir Mahkemeleri ve İcra Daireleri yetkilidir.

──────────────────────────────────────
14. BÖLÜNEBİLİRLİK
──────────────────────────────────────
Bu Sözleşme'nin herhangi bir hükmünün yetkili mahkeme tarafından geçersiz veya uygulanamaz ilan edilmesi halinde, Sözleşme'nin geri kalan hükümleri tam olarak yürürlükte kalmaya devam eder.

──────────────────────────────────────
15. SÖZLEŞME DEĞİŞİKLİKLERİ
──────────────────────────────────────
Geliştirici bu Sözleşme'yi dilediği zaman güncelleme hakkını saklı tutar. Güncellemeler uygulamada yayımlandığında devam eden kullanım yeni koşulların kabulü anlamına gelir. Önemli değişikliklerde uygulama yeniden onay isteyecektir.

İletişim: korubeni.destek@gmail.com
''';

  // ── Kullanım Sözleşmesi — İngilizce ──────────────────────────────────────
  static const String termsOfServiceEn =
      '''
TERMS OF SERVICE (END USER LICENSE AGREEMENT — EULA)
Version $termsVersion | Last Updated: $lastUpdatedEn

This Terms of Service Agreement ("Agreement") is entered into between KoruBeni ("Developer") and the individual downloading and using the application ("User"). By using the application, you declare that you have read, understood, and accepted all terms of this Agreement.

──────────────────────────────────────
1. PURPOSE AND SCOPE
──────────────────────────────────────
KoruBeni is an Android utility application developed to support personal safety awareness. The app may offer basic free functionality. Additional tools such as Panic/SOS, safe walk/check-in, volume trigger, test mode, and safety history may unlock with the optional KoruBeni Pro subscription. Emergency contact management and siren are free tools in this release.

Notice under Consumer Protection Law No. 6502: KoruBeni may offer basic free functionality and an optional Pro subscription managed through Google Play. It is NOT a professional security service, emergency response service, or any professional security solution. No service level commitment is provided.

──────────────────────────────────────
2. AGE RESTRICTION
──────────────────────────────────────
You must be at least 18 years old to use this application. Under-18 use is not supported in this release. The User is solely responsible for the accuracy of their age declaration.

──────────────────────────────────────
3. DISCLAIMER
──────────────────────────────────────
• This application does NOT and WILL NOT replace professional security services, emergency services, or police services.
• Calling 112 in emergency situations IS THE USER'S RESPONSIBILITY. The app is only an auxiliary tool.
• The application does NOT guarantee call connection, location accuracy, or notification delivery.
• The Developer CANNOT BE HELD RESPONSIBLE for delays and delivery failures due to network issues, device settings, carrier outages, or battery depletion.
• The Developer is not responsible for location errors arising from GPS hardware inaccuracy.

──────────────────────────────────────
4. USER RESPONSIBILITIES
──────────────────────────────────────
The User agrees to:
• Use the application only for lawful purposes and in good faith,
• Not misuse the application or make false emergency notifications,
• Not violate the rights of third parties,
• Be solely responsible for all actions performed through the application,
• Comply with all applicable laws including the Turkish Penal Code.

──────────────────────────────────────
5. FAKE CALL FEATURE
──────────────────────────────────────
The fake call feature is designed ONLY for personal safety purposes (e.g., leaving a situation to escape harassment). Using this feature for fraud, harassment, deception of others, or any criminal act IS ILLEGAL. ALL LEGAL AND CRIMINAL RESPONSIBILITY for such misuse BELONGS TO THE USER.

──────────────────────────────────────
6. LOCATION SESSION
──────────────────────────────────────
• Location data is used for map/location sessions only when explicitly triggered by the user.
• The accuracy of the displayed location depends on GPS hardware and is not guaranteed by the Developer.
• If location cannot be obtained, the app does not show fake coordinates. Online map tiles require OpenStreetMap connectivity.

──────────────────────────────────────
7. EMERGENCY CONTACTS AND THIRD-PARTY RIGHTS
──────────────────────────────────────
• The User declares that they have the authority to save and call the persons added as emergency contacts in an emergency.
• The User is responsible for the rights of these persons under applicable privacy laws.
• Third parties added as emergency contacts may exercise their rights under KVKK Article 11 by contacting korubeni.destek@gmail.com. The Developer will notify the relevant user and request deletion of the data.

──────────────────────────────────────
8. DISCLAIMER OF WARRANTIES
──────────────────────────────────────
The application is provided "AS IS". NO WARRANTY of any kind is given that it will operate without interruption, error-free, or fit for a particular purpose. The application may be changed, updated, or service discontinued at any time without prior notice.

──────────────────────────────────────
9. LIMITATION OF LIABILITY
──────────────────────────────────────
The Developer shall not be liable for any direct, indirect, incidental, special, or consequential DAMAGES (including loss of life, financial loss, or data loss) arising from use or inability to use the application. This limitation does NOT cover cases of gross negligence or intentional misconduct in accordance with TBK Article 115.

The Developer's total liability shall not exceed the total amount paid by the User through Google Play for KoruBeni Pro in the 12 (twelve) months preceding the claim. For users without a paid subscription, this amount is 0 TL.

──────────────────────────────────────
10. INDEMNIFICATION
──────────────────────────────────────
The User agrees to indemnify and hold the Developer harmless from any third-party claims, lawsuits, or damages arising from the use of the application, including reasonable attorney fees.

──────────────────────────────────────
11. FORCE MAJEURE
──────────────────────────────────────
The Developer shall not be liable for any failure or delay in the operation of the application caused by natural disasters, war, pandemics, internet/telecommunications infrastructure outages, power outages, government restrictions, or similar events beyond the Developer's control ("force majeure").

──────────────────────────────────────
12. INTELLECTUAL PROPERTY
──────────────────────────────────────
The application and all intellectual property rights contained therein belong to KoruBeni. The User is granted only a personal, non-transferable, non-exclusive license to use the application.

──────────────────────────────────────
13. GOVERNING LAW AND JURISDICTION
──────────────────────────────────────
This Agreement is governed by the laws of the Republic of Turkey. The courts and enforcement offices of İzmir shall have jurisdiction over disputes arising from this Agreement.

──────────────────────────────────────
14. SEVERABILITY
──────────────────────────────────────
If any provision of this Agreement is found to be invalid or unenforceable by a competent court, the remaining provisions shall continue in full force and effect.

──────────────────────────────────────
15. AMENDMENTS
──────────────────────────────────────
The Developer reserves the right to update this Agreement at any time. Continued use after updates are published in the application constitutes acceptance of the new terms. For material changes, the application will request re-consent.

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
