# Closed Test — Tester Onboarding (Operator → Tester)

Bu dosya, operatörün Closed Test sürecine katılacak **gönüllü test kullanıcılarına** göndereceği talimat metnini içerir. İçerik herhangi bir yere kopyalanabilir (WhatsApp, e-posta, Telegram, vs.) ve operatör tarafından kişiselleştirilir.

Operatör-tarafı AAB yükleme/inceleme adımları için: [`INTERNAL_TESTING_GUIDE.md`](INTERNAL_TESTING_GUIDE.md).

Bu doc'taki şablonlar repo audit kapsamında hazırlanmıştır; gerçek tester recruit'i ve mesajlaşma operator action'dır.

---

## Operatör için ön hatırlatmalar

- Closed test yayın izni için Google Play, yeni Personal hesaplarda 12+ test kullanıcısı × 14 gün sürekli engagement talep eder. Bu süre tamamlanmadan production access başvurusu reddedilebilir.
- Tester hesabı: testerlerin Google Play Store'a giriş yapmak için kullandıkları gerçek Google hesabı olmalıdır. Aile/kurumsal hesap zorunlu değildir.
- Aynı tester hesap listesini hem Closed Test track'inde hem License Tester (Play Console → Setup → License Testing) olarak kullanmak Pro abonelik testini ücretsiz yapar.
- Aktif kullanım sayılır (engagement): testerin uygulamayı 14 gün boyunca en az birkaç gün açması beklenir; sadece kurma → silme yetmez.
- Reddedilme veya askıya alınma yaşamamak için, gerçek 112 araması test sırasında **kesinlikle yapılmamalıdır**.

Recruit hedefi: 12 yeşil kalır (engagement gösterir) için 20-30 kişiye davet at; response rate ~%40-50.

---

## Tester'a Gönderilecek Davet Metni — TR (kopyala-yapıştır)

```
Merhaba [İSİM],

KoruBeni adlı kişisel güvenlik uygulamamı Google Play'de yayınlamak üzere
14 gün boyunca telefonunda test edecek 12 kişiye ihtiyacım var.
Sen de aralarında olur musun?

✋ ÖNEMLİ HUKUKİ UYARI ✋
KoruBeni resmi bir acil servis DEĞİLDİR ve 112'NİN YERİNİ TUTMAZ.
Test sırasında GERÇEK 112'yi ASLA arama. Sadece "ekranı görüyor muyum?"
düzeyinde test yap; numara aramaya gitmeden hemen iptal et.

📥 KURULUM (1 dakika)
1. Telefonundan şu linki aç (Play Store'a hangi Google hesabıyla
   giriş yaptıysan onu kullan):
   [OPT-IN URL — operator buraya kendi Play tester link'ini yapıştırır]
2. "Become a tester" / "Test sürümünü kullanmaya başla" düğmesine bas
3. Birkaç dakika bekle; sonra Play Store'dan "KoruBeni"yi yükle

📋 14 GÜNDE NELER DENESEN İYİ
Her bir senaryoyu bir kez yapsan yeterli. Crash olursa lütfen bildir.

Gün 1-2: ısınma
- Uygulamayı aç, onboarding'i geç (kabul kutucuklarını işaretle)
- Acil kişi ekle — gerçek değil! "Test Kişi 1" / +90 555 000 0000
- Ana ekran "Panik/SOS" butonuna bas → onay diyaloğunu gör → İPTAL

Gün 3-7: ana akış
- Safe Walk başlat → 1-2 dakika çalıştır → İptal et
- Check-in başlat → süre dolmasını bekle → "İyiyim" tuşuna bas
- Sahte çağrı tetikle
- Sireni 5 saniye çalıştır → kapat
- Haritayı aç → telefonu hareket ettir → harita güncelleniyor mu
- Bildirim çekmecesinde Safe Walk bildirimi görünüyor mu

Gün 8-14: kenar durumlar
- Pro abonelik paywall'ını aç (sadece görüntüle, satın alma yapma)
- Privacy / Terms / Veri Silme linklerini tıkla — açılıyor mu
- İnterneti kapat → harita "yüklenemedi" mesajı geliyor mu
- Telefonu yeniden başlat → Safe Walk hâlâ aktifken ne oluyor
- Uygulamayı 1-2 günde bir aç (Play "engagement" görsün diye)

📝 GERİBİLDİRİM
Crash, donma, garip davranış gördüğünde:
[FEEDBACK FORM URL — operator Google Forms link'ini yapıştırır]
veya e-posta: korubeni.destek@gmail.com

📅 14 GÜNLÜK TAAHHÜT
14 günden önce uygulamayı silersen ya da "Leave program" yaparsan
Play tarafında engagement düşüyor ve production izin başvurum
ertelenir. Lütfen 14 gün boyunca uygulamayı telefonunda tut.

🔒 GİZLİLİK
KoruBeni cihazında veri tutar; sunucu yok.
Test sırasında yalnızca anonim crash raporu Google'a otomatik gider
(Play'in kendi süreci). Gerçek konumun, gerçek kişilerin veya gerçek
telefonun benimle paylaşılmaz.

🆘 SORUN YAŞARSAN
WhatsApp: [operator numarası — sadece 14 gün sürerken destek için]
E-posta: korubeni.destek@gmail.com

Teşekkürler!
— Poyraz Öncel, KoruBeni Geliştiricisi
```

---

## Invitation Message — EN (copy/paste)

```
Hi [NAME],

I'm releasing a personal-safety Android app called KoruBeni on
Google Play and I need 12 testers to keep it on their phone for
14 days. Are you in?

✋ IMPORTANT LEGAL NOTICE ✋
KoruBeni is NOT an official emergency service and does NOT replace
112 (or your local emergency number). DO NOT dial real 112 during
testing. Only verify that the dialer screen appears; cancel before
the call connects.

📥 INSTALL (1 minute)
1. Open this link on your phone using the same Google account you
   use for the Play Store:
   [OPT-IN URL — operator pastes Play tester link here]
2. Tap "Become a tester"
3. Wait a few minutes; then install "KoruBeni" from the Play Store

📋 WHAT TO TRY OVER 14 DAYS
Do each scenario once. Report any crash you see.

Days 1-2 — warm-up
- Open the app, complete onboarding (tick the acceptance boxes)
- Add an emergency contact — use a fake one! "Test Person 1" /
  +90 555 000 0000
- Tap Panic/SOS on home → see confirmation dialog → CANCEL

Days 3-7 — main flow
- Start Safe Walk → run for 1-2 minutes → cancel
- Start Check-In → let timer expire → tap "I'm okay"
- Trigger a fake call
- Play the siren for 5 seconds → stop it
- Open the map → move your phone → does the map update?
- Is the Safe Walk notification visible in the notification drawer?

Days 8-14 — edge cases
- Open the Pro subscription paywall (just look, don't purchase)
- Tap Privacy / Terms / Data Deletion links — do they open?
- Turn off internet → does the map show "failed to load"?
- Reboot the phone while Safe Walk is active → what happens?
- Open the app every 1-2 days (Play wants to see "engagement")

📝 FEEDBACK
For crashes, freezes, or odd behavior:
[FEEDBACK FORM URL — operator pastes Google Forms link]
or email: korubeni.destek@gmail.com

📅 14-DAY COMMITMENT
If you uninstall or hit "Leave program" before 14 days, my Play
engagement metric drops and production approval gets delayed.
Please keep the app installed for 14 days.

🔒 PRIVACY
KoruBeni stores your data on-device; there is no server.
During testing, only anonymous crash reports may flow to Google
(their own pipeline). I never see your real location, contacts,
or phone number.

🆘 IF YOU GET STUCK
WhatsApp: [operator phone — for 14-day support only]
Email: korubeni.destek@gmail.com

Thanks!
— Poyraz Öncel, KoruBeni Developer
```

---

## Feedback Form — recommended Google Forms structure

Operatör Google Forms ile oluşturup link'i yukarıdaki davet metinlerine yapıştırır.

| # | Soru | Tip | Notlar |
|---|---|---|---|
| 1 | Adın? | Kısa cevap | İsteğe bağlı |
| 2 | Hangi telefonu kullanıyorsun? | Çoktan seçmeli | Samsung / Xiaomi / Pixel / Vestel-Casper / Diğer |
| 3 | Android sürümü? (Ayarlar → Telefon Hakkında) | Kısa cevap | "Android 13", "Android 14" gibi |
| 4 | Uygulama açılırken sorun yaşadın mı? | Çoktan seçmeli | Hayır / Yavaş açıldı / Crash / Açılmadı |
| 5 | Hangi özelliği denedin? | Uzun cevap | Serbest metin |
| 6 | Crash veya donma yaşadın mı? | Çoktan seçmeli | Hiç / Bir kere / Birden fazla |
| 7 | Evet ise, ne yaparken oldu? | Uzun cevap | Adımlar |
| 8 | Genel izlenim / öneri | Uzun cevap | Serbest metin |
| 9 | Pro paywall ekranını gördün mü? | Çoktan seçmeli | Evet / Hayır / Bulamadım |
| 10 | Safe Walk bildirimi çekmecede görünüyor mu? | Çoktan seçmeli | Evet, Stop butonu da var / Bildirim var, Stop yok / Bildirim hiç yoktu / Test etmedim |

---

## Operatör için hatırlatma — tester engagement hijyeni

- 7. günde ve 13. günde testerlere kısa bir hatırlatma at: "Aboneliği bırakma, hâlâ test ediyoruz, teşekkürler!"
- Tester crash bildirimi gönderirse 24 saat içinde "aldım, bakıyorum" cevabı ver — yoksa kullanıcı uygulamayı silebilir.
- Sonraki sürüm release notes'ta "Beta Testers" credit ekle — bu, gelecekteki recruit'i kolaylaştırır.

---

## Recruit kaynak fikirleri (operator action)

| Kaynak | Tahmini cevap oranı | Notlar |
|---|---|---|
| Aile + yakın arkadaşlar | %60-80 | En kolay başlangıç; ilk 5 burada bulunur |
| Üniversite / iş arkadaşları | %30-50 | Android cihaz gereği önemli; iPhone kullananları sorma |
| Reddit r/AndroidQuestions, r/SomebodyMakeThis | %20-30 | Bağlantı verir, gerçek aktif kullanım az olur |
| testerscommunity.com (free swap) | %40-50 | Karşı tarafın uygulamasını da test etmen gerekir |
| Twitter / LinkedIn duyuru | %5-15 | Düşük ama bedava |

Önemli: Tamamen anonim "test farm" hizmetleri Play tarafından "tester engagement" olarak kabul edilmeyebilir. Aktif kullanıcı kalibresi her hâlükârda gerçek olmalı.
