# KoruBeni - Gerçek Eksikler Listesi (2024)

**Oluşturulma Tarihi**: 27 Şubat 2024  
**Durum**: Flutter analyze'de 1 HATA + 8 UYARI + Chaos test altyapısı eksik

---

## 🔴 KRİTİK HATALAR (Uygulamayı Engelleyen)

### 1. DozeMode Servisi - Değişken Hatası
**Dosya**: `lib/core/services/doze_mode_service.dart:72`  
**Hata**: `Local variable 'isWhitelisted' can't be referenced before it is declared`

```dart
// ❌ YANLIŞ (satır 72)
final isWhitelisted = await isWhitelisted();

// ✅ DOĞRU olmalı
final isWhitelisted = await _isWhitelisted();
// veya
final whitelisted = await isWhitelisted();
```

**Çözüm**: Fonksiyon ismi değişken ismiyle çakışıyor. Değişken adını değiştir.

---

## 🟡 UYARILAR (Düzeltilmeli)

### 2. Kullanılmayan Import
**Dosya**: `lib/core/services/emergency_core_service.dart:23`  
```dart
// ❌ Kullanılmıyor
import 'location_service.dart';
```
**Çözüm**: Bu satırı sil veya kullan.

### 3. Gereksiz Null Karşılaştırmaları
**Dosyalar**:
- `lib/core/services/emergency_core_service.dart:635`
- `lib/core/services/health_check_service.dart:161`

```dart
// ❌ YANLIŞ
if (FirebaseService.instance != null) { ... }

// ✅ DOĞRU (Dart 3'te null olamaz)
// Direkt kullan veya nullable yap
```

### 4. Gereksiz Cast'ler
**Dosya**: `lib/core/services/health_check_service.dart:92-97`

```dart
// ❌ YANLIŞ
final value = data['key'] as String;  // Zaten String

// ✅ DOĞRU
final value = data['key'];
```

### 5. Deprecated API Kullanımı
**Dosya**: `lib/core/services/emergency_core_service.dart:194`

```dart
// ❌ DEPRECATED
final position = await Geolocator.getCurrentPosition(
  desiredAccuracy: LocationAccuracy.high,
);

// ✅ YENİ API
final position = await Geolocator.getCurrentPosition(
  locationSettings: LocationSettings(
    accuracy: LocationAccuracy.high,
    distanceFilter: 10,
  ),
);
```

---

## 🔵 CHAOS TEST ALTYAPISI EKSİKLERİ

### 6. Mockito Paketi Eksik
**Durum**: Chaos testler için mockito gerekli ama `pubspec.yaml`'da yok

**Çözüm**:
```yaml
# pubspec.yaml dev_dependencies bölümüne ekle
dev_dependencies:
  mockito: ^5.4.4
  build_runner: ^2.4.9
```

### 7. Chaos Test Import Hataları
**Dosya**: `test/chaos/chaos_test_helpers.dart`

**Sorunlar**:
- Mockito import edilemiyor (paket yok)
- Relative imports kullanılıyor (lib'den)
- Mock sınıflar oluşturulamıyor

**Çözüm**: Mockito ekle + mock'ları generate et:
```bash
flutter pub add mockito --dev
flutter pub add build_runner --dev
flutter pub run build_runner build
```

---

## 📊 ÖZET

| Kategori | Sayı | Öncelik |
|----------|------|---------|
| **Kritik Hatalar** | 1 | 🔴 Acil |
| **Uyarılar** | 8 | 🟡 Önemli |
| **Chaos Test Eksikleri** | 2 | 🔵 Orta |
| **TOPLAM** | 11 | - |

---

## ✅ HIZLI DÜZELTME PLANI

### Adım 1: Kritik Hatayı Düzelt (5 dakika)
```bash
# DozeMode servisindeki değişken adını değiştir
# Satır 72: final isWhitelisted = await isWhitelisted();
# Değiştir: final whitelisted = await isWhitelisted();
```

### Adım 2: Uyarıları Temizle (15 dakika)
1. Kullanılmayan import'u sil
2. Null karşılaştırmalarını düzelt
3. Gereksiz cast'leri kaldır
4. Deprecated API'yi güncelle

### Adım 3: Chaos Test Altyapısını Düzelt (10 dakika)
```bash
flutter pub add mockito --dev
flutter pub add build_runner --dev
flutter pub run build_runner build --delete-conflicting-outputs
```

### Adım 4: Doğrula (5 dakika)
```bash
flutter analyze
flutter test
```

**Toplam Süre**: ~35 dakika

---

## 🎯 SONUÇ

**Mevcut Durum**:
- ❌ Flutter analyze: 1 HATA + 8 UYARI
- ❌ Chaos testler: Çalışmıyor (mockito eksik)
- ✅ Normal testler: 34 test geçiyor
- ✅ Ana uygulama: Çalışıyor (kritik hata runtime'da görünmüyor)

**Hedef Durum**:
- ✅ Flutter analyze: 0 HATA + 0 UYARI
- ✅ Chaos testler: Çalışıyor
- ✅ Tüm testler: Geçiyor

---

## 📝 NOTLAR

1. **DozeMode hatası**: Runtime'da görünmüyor çünkü o kod path'i henüz çalışmamış olabilir. Ama release'den önce mutlaka düzeltilmeli.

2. **Chaos testler**: Yeni eklendi, mockito dependency'si eklenmemiş. Bu testler opsiyonel ama zero-fault garantisi için önemli.

3. **Uyarılar**: Kod çalışıyor ama best practice'lere uymuyor. Store'a çıkmadan önce temizlenmeli.

4. **Store eksikleri**: Ayrı bir konu. Bu liste sadece **kod kalitesi** eksiklerini içeriyor.

---

**Sonraki Adım**: Kritik hatayı düzelt, sonra uyarıları temizle, sonra chaos test altyapısını kur.
