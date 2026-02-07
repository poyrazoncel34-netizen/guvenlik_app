# ☕ Java Kurulumu - macOS

Java Runtime bulunamadı. Keystore oluşturmak için Java gerekiyor.

## 🎯 EN KOLAY YOL: Homebrew ile OpenJDK

### Adım 1: Homebrew Kontrolü
```bash
which brew
```

Eğer "brew not found" derse, Homebrew'i kur:
```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

### Adım 2: OpenJDK Kur
```bash
brew install openjdk@17
```

### Adım 3: Java'yı Aktif Et
```bash
sudo ln -sfn /opt/homebrew/opt/openjdk@17/libexec/openjdk.jdk /Library/Java/JavaVirtualMachines/openjdk-17.jdk
```

### Adım 4: PATH'e Ekle
```bash
echo 'export PATH="/opt/homebrew/opt/openjdk@17/bin:$PATH"' >> ~/.zshrc
source ~/.zshrc
```

### Adım 5: Kontrol Et
```bash
java -version
```

Şunu görmeli: `openjdk version "17.x.x"`

---

## 🔄 ALTERNATIF: Oracle JDK (Manuel)

1. https://www.oracle.com/java/technologies/downloads/#java17-mac
2. macOS Installer (.dmg) indir
3. Kurulum sihirbazını takip et
4. Terminal'i yeniden aç

---

## ✅ Java Kurulduktan Sonra

Keystore oluşturma komutunu tekrar çalıştır:

```bash
cd /Users/poyrazoncel/Desktop/guvenlik_app/android
keytool -genkey -v -keystore korubeni-release-key.jks -keyalg RSA -keysize 2048 -validity 10000 -alias korubeni
```

---

## 🚀 HIZLI KURULUM (Tek Komut)

Eğer Homebrew zaten kuruluysa, şu komutları sırayla çalıştır:

```bash
# OpenJDK kur
brew install openjdk@17

# Java'yı aktif et
sudo ln -sfn /opt/homebrew/opt/openjdk@17/libexec/openjdk.jdk /Library/Java/JavaVirtualMachines/openjdk-17.jdk

# PATH'e ekle
echo 'export PATH="/opt/homebrew/opt/openjdk@17/bin:$PATH"' >> ~/.zshrc
source ~/.zshrc

# Kontrol et
java -version
```

**Not:** Eğer Apple Silicon (M1/M2) Mac kullanıyorsan `/opt/homebrew`, Intel Mac kullanıyorsan `/usr/local` kullan.

Intel Mac için:
```bash
sudo ln -sfn /usr/local/opt/openjdk@17/libexec/openjdk.jdk /Library/Java/JavaVirtualMachines/openjdk-17.jdk
echo 'export PATH="/usr/local/opt/openjdk@17/bin:$PATH"' >> ~/.zshrc
```
