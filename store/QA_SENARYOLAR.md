# KoruBeni — QA Senaryoları ve Ekran Kontrol Listesi

Bu dosya, uygulama çıkışı öncesi kritik akışların manuel test senaryolarını ve dikkat edilecek noktaları listeler.

---

## 1. İlk Açılış Akışı

| Adım | Ekran | Kontrol Edilecek |
|------|-------|------------------|
| 1 | SplashScreen | Logo ve "KoruBeni yükleniyor" görünüyor mu? ~1.8s sonra otomatik geçiş |
| 2 | OnboardingScreen | 3 sayfa: "Tek dokunuşla acil yardım", "Acil kişilerinizi seçin", "Konum paylaşımı" |
| 3 | Onboarding | Atla / İleri / Başla butonları çalışıyor mu? |
| 4 | MainNavigation | Başla ile ana menüye geçiş yapılıyor mu? |

**Olası sorunlar:**
- `SharedPreferences` erişim hatası (izin/izolasyon)
- Uzun süren splash (ağ/Firebase gecikmesi)

---

## 2. Ana Sayfa ve Panik Butonu

| Adım | Ekran | Kontrol Edilecek |
|------|-------|------------------|
| 1 | HomePage | Panik butonu görünür mü? "BASILI TUT" metni okunuyor mu? |
| 2 | PanicButton | Basılı tutma (3s) → PIN doğrulama ekranına geçiş |
| 3 | PinVerificationScreen | Geri sayım, PIN girme, İptal / Acil arama butonları |
| 4 | CountdownScreen | 10 saniye geri sayım, PIN ile iptal |

**Olası sorunlar:**
- Panik butonu uzun basma süresi (3s) UX beklentisi ile uyuşuyor mu?
- PIN ekranında biyometrik varsa "Face ID / Parmak izi ile iptal" çalışıyor mu?

---

## 3. Hızlı Aksiyonlar (Quick Help)

| Adım | Ekran | Kontrol Edilecek |
|------|-------|------------------|
| 1 | HomePage | "Hızlı Yardım" FAB tıklanıyor mu? |
| 2 | BottomSheet | Polis 155, İtfaiye 110, Acil 112, Sahte Çağrı, Siren vb. seçenekler |
| 3 | Sahte Çağrı | Gerçekçi arama ekranı açılıyor mu? |
| 4 | Siren | Siren sesi çalıyor mu? (izin varsa) |

---

## 4. Kişiler Sekmesi

| Adım | Ekran | Kontrol Edilecek |
|------|-------|------------------|
| 1 | ContactsPage | Acil kişi listesi boş/ dolu görünümü |
| 2 | Rehber izni | İzin verilmediyse rationale gösteriliyor mu? |
| 3 | Kişi ekleme | Rehberden kişi seçimi (max 5) çalışıyor mu? |
| 4 | Kişi silme | Silme işlemi doğrulanıyor mu? |

---

## 5. Harita ve Konum

| Adım | Ekran | Kontrol Edilecek |
|------|-------|------------------|
| 1 | MapPage | Harita yükleniyor mu? Mevcut konum gösteriliyor mu? |
| 2 | Konum izni | İzin reddedilirse uyarı mesajı |
| 3 | Konum paylaşımı | "Konum Paylaş" başlatıp bitirme akışı |

---

## 6. Ayarlar

| Adım | Ekran | Kontrol Edilecek |
|------|-------|------------------|
| 1 | SettingsPage | Profil, bildirimler, konum, ses, titreşim ayarları |
| 2 | Profil düzenleme | Ad/email güncelleme ve kaydetme |
| 3 | Hakkında / Gizlilik | İç sayfalar açılıyor mu? |
| 4 | Dil değişimi | TR/EN geçişi çalışıyor mu? |

---

## 7. Arka Plan ve Özel Durumlar

| Senaryo | Kontrol Edilecek |
|---------|------------------|
| Uçak modu | Offline uyarısı, acil durum akışı (SMS/arama olmadan) |
| İzin reddi | Konum / rehber reddedildiğinde uygulama çökmeden çalışıyor mu? |
| Pil optimizasyonu | Uygulama arka planda kapatılırsa bildirim/foreground service |
| Sallama tetiklemesi | Telefon sallanınca CountdownScreen’e geçiş |
| Ses tuşu tetiklemesi | (destekleniyorsa) Volume tuşu ile panik tetikleme |

---

## Öncelik Sırası

1. **Kritik:** Panik butonu → PIN → geri sayım → acil arama/SMS
2. **Yüksek:** Splash → Onboarding → Ana sayfa, Kişiler ekleme
3. **Orta:** Harita, Ayarlar, Sahte çağrı, Siren
4. **Düşük:** Arka plan, sallama/ses tetikleme, dil değişimi

Bu senaryoları gerçek Android ve iOS cihazlarda test edin; emülatörde izinler ve arama/SMS davranışı farklı olabilir.
