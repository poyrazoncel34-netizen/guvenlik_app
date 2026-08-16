# Degisiklik Gunlugu

Bu dosya her yayin icin **Play "Yenilikler" metninin kaynagidir** — iki ayri
yerde iki farkli surum notu tutmak, ikisinin de yanlis olmasinin en hizli yolu.

Bicim: [Keep a Changelog](https://keepachangelog.com/tr/1.1.0/) tarzi.
Surumleme: `pubspec.yaml` 1.0.0+1'de SABITTIR; gercek `versionCode`
`.github/workflows/release.yml` icinde git tag'inden turer.

## Yayinlanmadi

### Duzeltildi
- Platformun "animasyonlari kaldir" tercihi yedi ekranda yok sayiliyordu.
  Sonsuz nabizlar `AnimationController(...)..repeat()` insa kaskadiyla, yani
  MediaQuery okunabilir hale gelmeden basliyordu. Bastirilan nabizlar artik
  gorunur bir ara degerde park ediliyor.
- Guvenlik Gecmisi'nde bir kaydi kalici olarak silmek onay istemiyordu; tek bir
  yanlis dokunus geri alinamaz bir silme yapiyordu. Artik silinecek kaydi adiyla
  soyleyen bir onay var.
- Erisim ayarlari altindaki tasma kusuru kapatildi.
- Dokunma hedefleri 48 dp'ye cikarildi; erisilemez cevrimdisi banneri onarildi.
- Cevrimdisi banneri sayfa basligini ortuyordu; artik kapladigi yeri ayiriyor.
- Buyuk yazi tipi olceginde (1.5x ve uzeri) cevrimdisi banneri kendi
  etiketini alttan kirpiyordu; banner artik metin olcegiyle birlikte buyuyor.
- Arka plan kilidi hic tetiklenmiyordu (`AppLifecycleState.inactive` donus
  yolunda da tetikleniyor ve sayaci sifirliyordu).

### Eklendi
- `docs/audit/evidence/` altinda makine-okunur kanit artefaktlari ve her biri
  icin negatif kontrollu dogrulayicilar.
- `docs/release/incident_runbook.md`, `SECURITY.md`, bu dosya.
- Boyut x metin-olcegi matrisi (`test/screens/layout_size_matrix_test.dart`).

## 1.0.0 — ilk yayin adayi

Ilk Play Store yayin adayi. Panik butonu, geri sayim, acil kisiler, guvenli
yuruyus, prova, yerel PIN kilidi, KVKK riza akisi, cevrimdisi harita katmani.
