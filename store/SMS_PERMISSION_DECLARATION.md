# 📋 Google Play SMS Permission Declaration Rehberi

KoruBeni uygulaması `SEND_SMS` iznini kullandığı için Google Play Console'da **Permissions Declaration Form** doldurulması **zorunludur**. Bu rehber, formu nasıl dolduracağınızı ve reddedilme riskini nasıl en aza indireceğinizi açıklar.

---

## ⚠️ KRİTİK BİLGİ

Google Play, `SEND_SMS` iznini **çok sıkı** denetler. Sadece **varsayılan SMS uygulaması** olan veya **core safety** işlevi kanıtlanmış uygulamalara izin verir. KoruBeni bir **acil durum güvenlik uygulaması** olduğundan, exception (istisna) talep edilebilir.

**Reddedilme riski:** Google formu reddederse uygulama Store'dan kaldırılır. Bu yüzden aşağıdaki iki stratejiyi birlikte uygulayın.

---

## 📝 Strateji 1: Permission Declaration Form Doldurma

### Google Play Console'da Nereye Gidilir?

```
Play Console > Uygulamanız > Policy and programs > App content > Permissions declarations
```

### Form Yanıtları (Kopyala-Yapıştır)

**1. Which restricted permission does your app use?**
> `SEND_SMS`

**2. Why does your app require this permission?**
> KoruBeni is a personal safety and emergency alert application. The SEND_SMS permission is required for the app's core emergency functionality: when a user triggers the panic button, the app automatically sends an emergency SMS with the user's real-time GPS location to their pre-configured emergency contacts. This is critical because:
>
> 1. **No Internet Required**: SMS works without internet connectivity, which is essential during emergencies where cellular data may be unavailable.
> 2. **Background Sending**: The SMS must be sent automatically without user interaction, as the user may be in physical danger and unable to manually compose a message.
> 3. **Time-Critical**: Emergency situations require immediate notification — opening the SMS composer app would introduce dangerous delays.
>
> Without this permission, the app cannot fulfill its primary safety function of alerting emergency contacts during life-threatening situations.

**3. Describe the core feature that requires this permission:**
> Emergency SOS Alert System — When the panic button is activated (via long-press, phone shake, or timer expiration), KoruBeni automatically:
> 1. Obtains the user's GPS coordinates
> 2. Sends an SMS containing the emergency message and Google Maps location link to all registered emergency contacts
> 3. Initiates a phone call to the primary emergency contact
>
> This is the app's primary and core function. The SMS is only sent during genuine emergency activations, never for marketing, spam, or any other purpose.

**4. Is this the app's core functionality?**
> **Yes.** The entire purpose of KoruBeni is to provide emergency alerting. Removing SMS capability would make the app's core function ineffective, especially in areas with poor internet connectivity.

**5. Provide a video demonstrating the feature:**
> Bir ekran kaydı videosu hazırlayın:
> 1. Uygulamayı açın
> 2. Panik butonuna basılı tutun
> 3. Geri sayım ekranını gösterin
> 4. SMS'in gönderildiğini gösterin
> 5. Video linki buraya yapıştırın

---

## 🛡️ Strateji 2: Alternatif Plan (Reddedilme Durumu)

Google `SEND_SMS` iznini reddederse, uygulama hâlâ çalışabilir durumda olmalıdır. Bunun için **intent-based SMS fallback** zaten kodda mevcuttur:

### Mevcut Fallback Mekanizması
`SmsService._sendViaLauncher()` metodu, SMS uygulamasını `uri_launcher` ile açarak kullanıcının onayıyla SMS gönderir. Bu yöntem `SEND_SMS` izni gerektirmez.

**Eğer Google izni reddederse:**
1. `AndroidManifest.xml`'den `SEND_SMS` satırını kaldırın
2. `SmsPlugin.kt` dosyasını devre dışı bırakın
3. Uygulama otomatik olarak `_sendViaLauncher` fallback'ini kullanacaktır

> **Not:** Bu durumda SMS gönderimi kullanıcı onayı gerektirecektir ve birden fazla kişiye mesaj gönderirken her biri için ayrı SMS uygulaması açılacaktır.

---

## 📊 Data Safety Form Güncellemesi

Google Play Console'da **Data Safety** bölümünde aşağıdaki bilgileri güncelleyin:

### App content > Data Safety

| Veri Türü | Toplanıyor mu? | Paylaşılıyor mu? | Amaç |
|-----------|---------------|-----------------|------|
| **Phone number** | Evet | Hayır | App functionality (Authentication) |
| **Approximate location** | Evet | Evet (acil kişilerle) | App functionality (Emergency alerts) |
| **Precise location** | Evet | Evet (acil kişilerle) | App functionality (Emergency alerts) |
| **SMS or MMS** | Gönderiliyor | Hayır | App functionality (Emergency SMS) |
| **Name** | Evet | Hayır | Account management |
| **Contacts** | Evet (kullanıcı girer) | Hayır | App functionality |
| **Crash logs** | Evet | Evet (Firebase) | Analytics |

### Dikkat Edilecek Sorular

**"Does your app send SMS messages?"**
> Yes — The app sends emergency SMS messages containing the user's location to their pre-configured emergency contacts when the panic button is activated.

**"Is the data encrypted in transit?"**
> Yes (Firebase uses SSL/TLS, SMS uses carrier encryption)

**"Can users request data deletion?"**
> Yes — Users can delete their account and all associated data.

---

## 📱 In-App SMS İzni Gerekçesi (Zaten Mevcut)

Google Play, `SEND_SMS` iznini istemeden önce kullanıcıya **neden gerektiğini açıklayan bir ekran göstermenizi** önerir. `SmsPlugin.kt` zaten izin kontrolü yapıyor ve izin yoksa `url_launcher` fallback'ine geçiyor.

**Ek olarak yapılması gereken:** İlk kez SMS izni istenirken bir açıklama dialog'u göstermek.

---

## 📹 Demo Video Hazırlama Rehberi

Google, form için **demonstrasyon videosu** isteyebilir. Aşağıdaki adımları takip edin:

### Video İçeriği (30-60 saniye)
1. **0-5 sn:** Uygulamayı açın, ana sayfayı gösterin
2. **5-10 sn:** Acil kişi seçildiğini gösterin
3. **10-20 sn:** Panik butonuna basılı tutun, geri sayımı gösterin
4. **20-30 sn:** SMS'in gönderildiğini gösterin (bildirim veya mesaj uygulaması)
5. **30-40 sn:** Güvenli yürüyüş özelliğini gösterin
6. **40-50 sn:** Kontrol noktası özelliğini gösterin

### Video Yükleme
- YouTube'a **unlisted** olarak yükleyin
- Linki forma yapıştırın

---

## ✅ Kontrol Listesi

- [ ] Google Play Console > App content > Permissions declarations formu dolduruldu
- [ ] Data Safety formu güncellendi
- [ ] Demo video hazırlandı ve YouTube'a yüklendi
- [ ] Reddedilme durumu için fallback plan hazır (mevcut kodda zaten var)
- [ ] Store listing'de kategori "Safety" olarak belirtildi
- [ ] Store açıklamasında SMS kullanımının acil durum amaçlı olduğu belirtildi
