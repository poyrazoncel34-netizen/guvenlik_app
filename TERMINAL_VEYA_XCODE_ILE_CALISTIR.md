# iPhone'da Uygulamayı Çalıştırma – Baştan Sona Rehber

Hiç bilmeyen biri için, eksiksiz adımlar. Dün Terminal’den çalıştırdıysan aynı yöntem burada da anlatılıyor.

---

## Ne lazım?

- Mac bilgisayar
- iPhone (açık ve şifreli değilse kilidi açık)
- iPhone’un şarj kablosu (USB tarafı Mac’e takılacak; bazı Mac’lerde USB-C adaptör gerekebilir)
- Bu proje bilgisayarda: `guvenlik_app` klasörü (örn. Masaüstü’nde)

---

# YÖNTEM: TERMINAL İLE (Yazı yazarak)

Bu yöntemde sadece Terminal’i açıp iki komut yazacaksın. Uygulama derlenip doğrudan iPhone’da açılacak.

---

## Adım 1: iPhone’u bilgisayara bağla

1. iPhone’un **şarj kablosunu** al.
2. **USB ucunu** Mac’in bir USB (veya USB-C) girişine tak.
3. Kablonun **diğer ucunu** iPhone’a tak.
4. iPhone’da bir pencere çıkacak: **“Bu bilgisayara güven?”** (veya “Trust This Computer?”)
   - **Güven** / **Trust** butonuna bas.
   - İstersen “Bu bilgisayara güven” kutusunda şifre de isteyebilir; iPhone kilidini açmak için kullandığın şifreyi yaz.
5. iPhone’u **kilitsiz** bırak (ekran kapalı olabilir ama kilit açık olsun). Bazı adımlarda Mac, telefona erişmek isteyebilir.

**Bu adımı atlama.** Kablo takılı ve “Güven” dedikten sonra devam et.

---

## Adım 2: Terminal’i aç

1. Mac’te **Spotlight**’ı aç:
   - Klavyeden **Cmd (⌘) + Space** tuşlarına birlikte bas
   - Veya ekranın sağ üst köşesindeki büyütece tıkla
2. Açılan arama kutusuna **Terminal** yaz.
3. Listede **“Terminal”** (siyah ekranlı uygulama) görünecek; üstüne tıkla veya Enter’a bas.
4. Siyah (veya beyaz) bir pencere açılacak; içinde bir satır yazı ve yanıp sönen imleç var. Burası **Terminal**.

Bu pencerede hiçbir programı açmıyorsun; sadece **komut** (yazı) yazacaksın.

---

## Adım 3: Proje klasörüne geç

Terminal’de şu anda “nerede” olduğun önemli. Uygulama kodları `guvenlik_app` klasöründe; önce oraya gideceğiz.

1. Terminal penceresine tıkla (içeriği seçili olmasın, sadece odak orada olsun).
2. Aşağıdaki satırı **aynen** yaz (kopyala-yapıştır da olur):
   ```bash
   cd /Users/poyrazoncel/Desktop/guvenlik_app
   ```
3. **Enter**’a bas.

- **cd** = “şu klasöre gir” demek.
- **/Users/poyrazoncel/Desktop/guvenlik_app** = projenin tam yolu (senin kullanıcı adın `poyrazoncel`, proje Masaüstü’nde `guvenlik_app` klasöründe).

Eğer proje Masaüstü’nde değilse (başka bir yerdeyse), o klasörün yolunu yazman gerekir. Masaüstü’ndeyse bu satır yeterli.

- Hata almazsan bir sonraki adıma geç.  
- “No such file or directory” derse: `guvenlik_app` klasörünün gerçekten nerede olduğunu kontrol et; yolun sonundaki `guvenlik_app` doğru mu bak.

---

## Adım 4: Uygulamayı iPhone’da çalıştır

Aynı Terminal penceresinde, bir satır daha yazacaksın:

1. Şunu **aynen** yaz (veya kopyala-yapıştır):
   ```bash
   flutter run
   ```
2. **Enter**’a bas.

Ne olacak?

- **“Waiting for another flutter command…”** veya **“More than one device”** gibi bir şey çıkarsa: Flutter birden fazla cihaz (örneğin iPhone + simulator) görüyordur. O zaman ekranda **cihaz listesi** ve yanlarında numaralar (1, 2, 3…) çıkar. **iPhone’un olduğu satırdaki numarayı** yazıp Enter’a bas. Örneğin iPhone “2” numaralıysa: `2` yaz, Enter.
- **“Launching lib/main.dart on …”** gibi bir satır görürsen: Derleme başlamış demektir. Bekle; ilk seferde 1–3 dakika sürebilir.
- Derleme bitince Terminal’de **“Flutter run key commands”** veya benzeri bir blok görürsün; aynı anda **iPhone’da uygulama açılır**.

Yani: **cd** ile klasöre girdin, **flutter run** ile uygulamayı telefonda başlattın. Dün de büyük ihtimalle bunu yaptın.

---

## Adım 5: İlk seferde iPhone’da “Güven” (Developer uygulaması)

İlk kez bu Mac’ten bu iPhone’a uygulama yüklüyorsan, iPhone’da şöyle bir uyarı çıkabilir:

- **“Untrusted Developer”** / **“Güvenilir olmayan geliştirici”** veya  
- **“Developer Mode”** ile ilgili bir mesaj  

Yapman gereken:

1. iPhone’da **Ayarlar**’ı aç.
2. **Genel**’e gir.
3. **VPN ve Cihaz Yönetimi** (veya **Profiller / Device Management**) bölümüne gir.
4. **“Geliştirici Uygulaması”** veya **Apple ID’n (veya “Developer App”)** altında bir satır göreceksin. Ona tıkla.
5. **“Güven”** / **“Trust”** de.
6. Tekrar onaylarsan, o andan sonra bu geliştiriciye güvenilmiş olur.

Bundan sonra tekrar Mac’e dön; Terminal’de tekrar **flutter run** yazıp Enter’a bas. Bu sefer uygulama iPhone’da açılmalı.

---

## Özet: Her seferinde yapacağın şey

1. iPhone’u **kablo ile** Mac’e bağla, “Güven” de, kilidi aç.
2. **Terminal**’i aç (Cmd+Space → “Terminal”).
3. Şu iki komutu sırayla yaz, her birinden sonra Enter:
   ```bash
   cd /Users/poyrazoncel/Desktop/guvenlik_app
   flutter run
   ```
4. Birden fazla cihaz çıkarsa, **iPhone’un numarasını** yazıp Enter’a bas.
5. Derleme bitene kadar bekle; uygulama iPhone’da açılacak.

Bu kadar. Dün çalıştıysa, aynı işlem: kablo + bu iki komut.

---

## Sık karşılaşılan sorunlar

**“No devices found” / Cihaz bulunamadı**  
- iPhone kablo ile takılı mı?  
- “Bu bilgisayara güven” dedin mi?  
- Kabloyu çıkarıp tekrar tak; iPhone’da tekrar “Güven” de.  
- Bazen başka bir USB girişi denemek işe yarar.

**“flutter: command not found”**  
- Flutter kurulu değil veya Terminal’in PATH’inde yok.  
- Flutter’ı daha önce kurduysan, aynı Terminal oturumunda `flutter doctor` yazıp çalışıp çalışmadığına bak. Çalışmıyorsa Flutter’ı tekrar kurup PATH’e eklemen gerekir.

**Proje başka yerde**  
- `guvenlik_app` Masaüstü’nde değilse, `cd` komutundaki yolu değiştir.  
- Örnek: Proje İndirilenler’deyse:  
  `cd /Users/poyrazoncel/Downloads/guvenlik_app`

**Uygulama 7 günde bir açılmıyor**  
- Apple’ın kuralı: Bu şekilde yüklenen uygulama 7 gün sonra imzası düşer.  
- Çözüm: iPhone’u tekrar Mac’e bağla, aynı şekilde **flutter run** çalıştır. Uygulama yeniden yüklenir, 7 gün daha çalışır.

---

## Xcode ile çalıştırmak istersen

Terminal yerine Xcode kullanmak istersen:

1. iPhone’u yine **USB ile bağla**, “Güven” de.
2. Terminal’de şunu yaz (proje klasöründe olmana gerek yok):
   ```bash
   open /Users/poyrazoncel/Desktop/guvenlik_app/ios/Runner.xcworkspace
   ```
   Enter’a bas → Xcode açılır.
3. Xcode’da üstteki cihaz menüsünden **kendi iPhone’unu** seç (simulator değil).
4. Menüden **Product → Run** (veya **Cmd+R**) yap.
5. İlk seferde yine iPhone’da Ayarlar → Genel → VPN ve Cihaz Yönetimi → Geliştirici uygulamasına **Güven** de.

Özet: **Telefonda uygulama açmak için en basit yol, Terminal’de `cd` + `flutter run`.** Dün çalıştıysan, aynı adımlar.
