# Telefon Bağlı Değilken Uygulamayı Çalıştırma

Bilgisayara telefon bağlamadan uygulamayı çalıştırmak için aşağıdaki yöntemlerden birini kullanabilirsiniz.

---

## 1. iOS Simulator (Mac + Xcode)

iPhone simülatöründe çalıştırmak için:

1. **Simulator'ü aç:**
   ```bash
   open -a Simulator
   ```
   veya Xcode → Open Developer Tool → Simulator

2. **Uygulamayı çalıştır:**
   ```bash
   cd /Users/poyrazoncel/Desktop/guvenlik_app
   flutter run
   ```
   Birden fazla cihaz varsa:
   ```bash
   flutter run -d "iPhone 16"
   ```

3. **Mevcut cihazları görmek için:**
   ```bash
   flutter devices
   ```

---

## 2. Chrome (Web)

Tarayıcıda çalıştırmak için:

```bash
cd /Users/poyrazoncel/Desktop/guvenlik_app
flutter run -d chrome
```

Not: Bazı özellikler (biyometri, titreşim, gerçek konum) web’de sınırlı veya simüle olabilir.

---

## 3. macOS Masaüstü

Proje macOS hedefini desteklediği için doğrudan Mac’te pencere uygulaması olarak çalıştırabilirsiniz:

```bash
cd /Users/poyrazoncel/Desktop/guvenlik_app
flutter run -d macos
```

---

## 4. Android Emulator

Android Studio kuruluysa:

1. **Android Studio** → Tools → Device Manager → bir sanal cihaz oluşturup başlatın.
2. Emulator açıkken:
   ```bash
   cd /Users/poyrazoncel/Desktop/guvenlik_app
   flutter run
   ```
   veya cihazı seçerek:
   ```bash
   flutter run -d emulator-5554
   ```

---

## Hangi cihazlar var?

Hangi cihazların kullanılabilir olduğunu görmek için:

```bash
flutter devices
```

Çıktıda `chrome`, `macos`, `iPhone`, `android` gibi satırlar görürsünüz. İstediğiniz cihazın ID’sini kullanarak:

```bash
flutter run -d <cihaz_id>
```

şeklinde çalıştırabilirsiniz.

---

## Özet

| Yöntem        | Komut                    | Gereksinim              |
|---------------|--------------------------|--------------------------|
| iOS Simulator | `flutter run`            | Xcode (Mac)              |
| Chrome        | `flutter run -d chrome`  | Flutter                  |
| macOS         | `flutter run -d macos`  | Flutter + Mac            |
| Android       | `flutter run`            | Android Studio + Emulator|

En hızlı deneme için: **Chrome** (`flutter run -d chrome`) veya **macOS** (`flutter run -d macos`) kullanın.
