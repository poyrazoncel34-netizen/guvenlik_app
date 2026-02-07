# 🎯 İLK 3 ADIM - ŞİMDİ YAPALIM

## ADIM 1: Terminal'i Aç ve Git Repo Kur

Terminal'i aç (Cmd+Space, "Terminal" yaz) ve şu komutları sırayla çalıştır:

```bash
cd /Users/poyrazoncel/Desktop/guvenlik_app
git init
git add .
git commit -m "Initial commit: KoruBeni security app"
```

**Kontrol:** `git status` yazarsan "nothing to commit" görmeli.

---

## ADIM 2: Encryption Key Üret

Aynı terminal'de şunu çalıştır:

```bash
openssl rand -base64 32
```

**Çıkan key'i kopyala ve bir yere kaydet!** Örnek: `K9TFyDd47LRrwnh/AxTaXD74vlqGRj3Rjqm9cekKJf8=`

Bu key'i build alırken kullanacağız.

---

## ADIM 3: Android Keystore Oluştur

Terminal'de şunu çalıştır:

```bash
cd /Users/poyrazoncel/Desktop/guvenlik_app/android
keytool -genkey -v -keystore korubeni-release-key.jks -keyalg RSA -keysize 2048 -validity 10000 -alias korubeni
```

**Sorular:**
- **Keystore password:** Güçlü bir şifre belirle (not al!)
- **Key password:** Aynı şifreyi tekrar gir
- **Name:** Poyraz Öncel
- **Organizational Unit:** (Enter'a bas, boş bırak)
- **Organization:** (Enter'a bas, boş bırak)
- **City:** (Şehrin)
- **State:** (Enter'a bas)
- **Country:** TR
- **Onay:** yes

**Şimdi `key.properties` dosyasını oluştur:**

Terminal'de:
```bash
cd /Users/poyrazoncel/Desktop/guvenlik_app/android
nano key.properties
```

Açılan editörde şunu yaz (şifrelerini kendi şifrelerinle değiştir):

```
storePassword=BURAYA_KEYSTORE_SIFRENI_YAZ
keyPassword=BURAYA_KEY_SIFRENI_YAZ
keyAlias=korubeni
storeFile=korubeni-release-key.jks
```

**Kaydet:** Ctrl+O, Enter, Ctrl+X

---

## ✅ İLK 3 ADIM TAMAM!

Bu adımları tamamladıktan sonra bana "tamam" yaz, bir sonraki adımlara geçelim:
- Build alma
- Screenshot'lar
- Store'a yükleme
