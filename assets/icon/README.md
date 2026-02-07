# Uygulama İkonu

Store gönderimi için profesyonel bir ikon gereklidir.

## Adımlar

1. **Görsel oluştur**  
   - Boyut: **1024x1024 px**, PNG, şeffaf arka plan önerilmez (iOS).  
   - Önerilen prompt (AI): *"Mobile app icon, shield with location pin, safety theme, modern gradient, purple blue, rounded square"*

2. **Dosyayı koy**  
   - Bu klasöre `app_icon.png` adıyla kaydet.

3. **Flutter Launcher Icons**  
   - `pubspec.yaml` içinde `flutter_launcher_icons` bölümünün yorumunu kaldır.  
   - Çalıştır: `dart run flutter_launcher_icons`  
   - Android ve iOS ikonları otomatik üretilir.

4. **Android adaptive icon (opsiyonel)**  
   - Ön plan: `app_icon_foreground.png` (ön plan görseli, 1024x1024).  
   - Arka plan: `adaptive_icon_background` rengi veya ayrı görsel.
