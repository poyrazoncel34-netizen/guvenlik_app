# Flutter "Startup Lock" Hatası – Çözüm

Terminalde **"Waiting for another flutter command to release the startup lock..."** görüyorsan:

## Hızlı çözüm (Terminalde sırayla çalıştır)

```bash
# 1. Flutter'ı tutan işlemleri sonlandır
kill -9 $(ps aux | grep -E 'flutter_tools\.snapshot (run|daemon)' | grep -v grep | awk '{print $2}') 2>/dev/null

# 2. Lock dosyasını sil (Homebrew Flutter için)
rm -f /opt/homebrew/share/flutter/bin/cache/lockfile

# 3. Cihazları listele
cd /Users/poyrazoncel/Desktop/guvenlik_app
flutter devices

# 4. Uygulamayı telefona yükle (cihaz bağlıysa)
flutter run
```

## Tek komut

```bash
killall -9 dart 2>/dev/null; rm -f /opt/homebrew/share/flutter/bin/cache/lockfile; cd /Users/poyrazoncel/Desktop/guvenlik_app && flutter run
```

**Not:** `killall -9 dart` Cursor’daki Dart eklentisini kısa süre etkisiz bırakabilir; gerekirse Cursor’u yeniden başlatın.

## Telefon bağlı değilse

1. **Android:** USB hata ayıklamayı aç, kabloyu tak, “USB hata ayıklamaya izin ver?” → İzin ver.
2. **iPhone:** Kabloyu tak, “Bu bilgisayara güven” de.
3. Sonra tekrar: `flutter devices` → `flutter run`.
