# At-Rest PII Koruması — Tasarım Notu (KRİTİK-1)

> **Durum: YÖN SEÇİLDİ → H1 + bellek-ısıtma.** Bu belge salt-okunur araştırma +
> seçilen yönün kesin analizini içerir. Bu turda da **hiçbir kod değiştirilmedi**
> (yalnız bu doküman güncellendi). Uygulama, onaylanmış kesin planla **ayrı bir
> turda** yapılacaktır. Seçilen yönün ayrıntısı ve 3 kritik riskin çözümü için
> **§8**'e bakın — §1-7 ilk araştırma turunun kaydıdır.
>
> Tarih: 2026-06-24 · Kapsam: yalnız `docs/SECURITY_AT_REST_DESIGN.md`
> (ilk tur: eklendi; bu tur: §8 eklendi + bu banner güncellendi).

---

## 1. Sorun Tanımı + Denetim Referansı

**KRİTİK-1 (at-rest PII koruması).** Acil kişilerin `name` ve `phone` alanları
sqflite veritabanında (`korubeni.db`, `contacts` tablosu) **düz metin** olarak
saklanıyor. Bir kişisel-güvenlik uygulamasında acil kişi bilgisi en hassas
veridir (KVKK kişisel veri; tehdit modelinde "cihaz ele geçirildi / yedekten
çıkarıldı" senaryosu doğrudan ilgili). Veritabanı dosyası şifrelenmemiş; root'lu
cihazda, ADB yedeğinde veya dosya sistemine erişimde okunabilir.

**İlgili güvenlik kuralı:** `.claude/rules/dart/security.md` →
> "Never write sensitive data to SharedPreferences or local files in plaintext."
> "Store tokens, PII, and credentials only in `flutter_secure_storage`."

Mevcut durum bu kurala aykırı: PII düz metin SQLite'ta.

---

## 2. Veri Akışı Haritası (kanıt: dosya:satır)

### 2.1 Tek gerçek kaynak: sqflite `contacts` tablosu (DÜZ METİN)

Şema — `lib/core/services/local_database_service.dart:36-44`:
```
CREATE TABLE contacts(
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL,
  phone TEXT NOT NULL UNIQUE,
  is_primary INTEGER NOT NULL DEFAULT 0,
  created_at TEXT NOT NULL
)
```
`name` ve `phone` şifrelenmeden yazılıyor. DB sürümü 2
(`local_database_service.dart:10`).

### 2.2 YAZMA yolları (hepsi DB'ye düz metin)

| Yer | Ne yapıyor |
|-----|-----------|
| `contact_service.dart:51-88` `saveContactRecords` | `txn.insert('contacts', {name, phone, ...})` — düz metin |
| `contact_service.dart:25-49` `saveContacts` | normalize edip `saveContactRecords`'a devrediyor |
| `contact_service.dart:125-165` `savePrimaryEmergencyContact` | `txn.insert/update` düz metin, `is_primary=1` |
| `contact_service.dart:197-200` `clearPrimaryEmergencyContact` | `is_primary=0` |

**Acil kişi yazımının secure storage'a HİÇ gitmediğini** doğruladım — tüm aktif
yazma yolları yalnız DB'ye yazıyor.

### 2.3 OKUMA yolları (panik/SOS — hepsi DB)

| Yer | Çağrı | Bağlam |
|-----|-------|--------|
| `widgets/panic_button.dart:179` | `getAllEmergencyNumbers()` | `_hasCallableContact()` ön-kontrol |
| `screens/countdown_screen.dart:120` | `getPrimaryEmergencyContact()` | geri sayım ekranı kişiyi yükler |
| `screens/countdown_screen.dart:131` | `getAllEmergencyNumbers()` | **native AlarmManager yedeği** için numara seçer |
| `screens/countdown_screen.dart:249` | `getAllEmergencyNumbers()` | arama tetikleme |
| `core/services/check_in_service.dart:406,466` | `getAllEmergencyNumbers()` | check-in akışı |
| `screens/safe_walk_screen.dart:147` | `getAllEmergencyNumbers()` | safe walk |
| `screens/check_in_screen.dart:63` | `getAllEmergencyNumbers()` | check-in ekranı |
| `core/services/user_data_export_service.dart:24` | `getContactRecords()` | KVKK veri dışa aktarımı |

Tüm okumalar zinciri: çağrı → `ContactsRepository` →
`ContactsLocalDataSource` (`lib/data/datasources/local/contacts_local_datasource.dart`)
→ `ContactService` (static) → `LocalDatabaseService.database` → `db.query('contacts', ...)`.

**Acil yolda okuma noktası sayısı: 4 ayrı yüzey** (panik ön-kontrol, geri sayım
yükleme, native yedek zamanlama, arama tetikleme) — artı check-in ve safe-walk.
Hepsi şu an **senkron, anahtar gerektirmeyen düz-metin** DB okuması. Acil yolun
fail-safe'liği açısından kritik nokta budur: okuma yoluna anahtar/şifre çözme
bağımlılığı eklemek, anahtar kullanılamadığında acil kişinin **okunamamasına**
yol açabilir.

### 2.4 "Çift depolama" neden var? (tarihsel)

Şu an **aktif çift depolama YOK.** Secure storage'daki acil-kişi anahtarları
(`emergencyContactPhone`, `emergencyContactName`, `contactsData`, `contactsList`,
`emergencyContactsList` — `secure_storage_keys.dart`) **yalnızca eski (legacy)
depolardır** ve tek yönlü migrasyon için tutuluyor:

- `contact_service.dart:219-251` `_migrateLegacyContacts()` — DB boşsa, secure
  storage'dan (ve daha da eski düz `SharedPreferences` `saved_contacts`
  anahtarından) okur, **DB'ye yazar**, sonra
- `contact_service.dart:282-290` `_clearLegacyContactStorage()` — eski secure
  storage + prefs anahtarlarını **siler**.

Yani evrim: `SharedPreferences (düz)` → `flutter_secure_storage` → **`sqflite DB
(düz metin)`**. İronik sonuç: veri, cihaz-bağlı anahtarla korunan secure
storage'dan **düz-metin SQLite'a taşınmış** durumda — koruma seviyesi düşmüş.
KRİTİK-1'in kökü tam olarak bu migrasyon.

### 2.5 EncryptionService durumu — ÖLÜ KOD

- Tanım: `lib/core/security/encryption_service.dart` — AES (CBC), her `encrypt`
  çağrısında rastgele IV üretip ciphertext'e öne ekliyor; legacy statik-IV ve
  legacy base64 çözme yardımcıları var.
- DI: `service_locator.dart:45-49` `registerLazySingleton<EncryptionService>`.
- **Canlı çağıran YOK.** `grep '\.encrypt(\|\.decrypt(\|EncryptionService'` →
  yalnız kendi dosyası, DI kaydı ve testler. Üretim akışında hiç çağrılmıyor.
  → **Etkin biçimde ölü kod.**
- Anahtar kaynağı: `AppConstants.encryptionKeyBase64` =
  `String.fromEnvironment('ENCRYPTION_KEY')` (`app_constants.dart:10-11`) —
  **derleme-zamanı dart-define.** Bu, **her APK'da gömülü, tüm kullanıcılar için
  aynı, cihaz-bağlı OLMAYAN** bir anahtardır. APK'dan çıkarılabilir.
- Zorunluluk: `app_environment.dart:36-38` `validateReleaseConfiguration` yalnız
  release'de **boş olmadığını** kontrol eder (`main.dart:46`). Yani güvenlik
  garantisi değil, sadece "tanımlı mı" kontrolü.

> **Sonuç:** Mevcut `EncryptionService` + dart-define anahtarı, at-rest PII için
> **uygun bir temel değil** — statik, paylaşılan, ikili dosyada gömülü anahtar
> ciddi bir koruma sağlamaz. Cihaz-bağlı (Keystore) anahtara ihtiyaç var.

### 2.6 Android Keystore — projede zaten var mı?

Evet, dolaylı olarak. `lib/core/security/secure_storage.dart` →
`FlutterSecureStorage(aOptions: AndroidOptions())`. `flutter_secure_storage`
(pubspec.lock: **10.0.0**) Android'de **Android Keystore**'da tutulan, cihaz-bağlı,
(donanım destekli olabilen) bir ana anahtarla şifreli depolama kullanır. Bu
mekanizma PIN (`user_pin`), fake-call verisi ve consent için **zaten kullanımda**.
Yani cihaz-bağlı anahtar altyapısı projede **mevcut ve kanıtlanmış** — yalnız acil
kişiler için kullanılmıyor.

> ⚠️ **Doğrulanmalı:** flutter_secure_storage **v10**'un Android backend'inin tam
> iç yapısı (v9 `EncryptedSharedPreferences` kullanıyordu; v10 implementasyonu
> değişti). "Keystore-destekli, cihaz-bağlı anahtar" iddiası **orta güven** —
> seçilen yönde plugin v10 dökümantasyonuna/Keystore davranışına karşı teyit
> edilmeli. (`secure_storage.dart:4` `encryptedPrefsEnabled = true` yalnızca bir
> sabit bayrak; gerçek backend davranışını garanti etmez.)

İlgili bağımlılıklar (pubspec.lock): `flutter_secure_storage 10.0.0`,
`encrypt 5.0.3`, `sqflite 2.4.2`. SQLCipher **kullanılmıyor**.

---

## 3. Rakip Çözüm Hipotezleri

Her hipotez için: (a) panik fail-safe riski, (b) migrasyon riski, (c) karmaşıklık,
(d) mimari uyum, (e) güven seviyesi.

| # | Yaklaşım | (a) Panik fail-safe riski | (b) Migrasyon riski | (c) Karmaşıklık | (d) Mimari uyum | (e) Güven |
|---|----------|---------------------------|---------------------|-----------------|------------------|-----------|
| **H1** | **Tek kaynak = secure storage.** DB'den PII'yi tamamen kaldır; acil kişiyi yalnız `flutter_secure_storage`'dan oku/yaz. | **Orta.** Tüm okuma artık tek async secure-storage erişimine bağlı; Keystore kilitliyken (örn. cihaz yeniden başlatıldı, henüz unlock edilmedi) okuma gecikebilir/başarısız olabilir. iOS `first_unlock_this_device` zaten ayarlı; Android için unlock-bağımlılığı netleştirilmeli. 4 okuma noktasının hepsi düz-metin DB'den secure-storage JSON'a taşınmalı. | **Orta.** Veri zaten DB'de; geri yazım (DB→secure) gerekir. Migrasyon yarıda kalırsa kişi kaybı riski → idempotent + doğrulama şart. `is_primary`, sıralama, dedupe JSON modeline taşınmalı. | **Orta-Yüksek.** `contacts` tablosu tamamen emekli; `ContactService` baştan yazılır; sorgu/sıralama (`is_primary DESC, created_at ASC`) elde yapılır. | **İyi.** Secure storage zaten PIN için bu app'te kullanılıyor; "PII yalnız secure storage" kuralına birebir uyar. | **Orta** |
| **H2** | **DB alanlarını şifrele.** `contacts.name/phone`'u **cihaz-bağlı Android Keystore anahtarıyla** şifrele (dart-define ENCRYPTION_KEY DEĞİL). `EncryptionService`'i Keystore anahtarına bağla/yenile. | **Yüksek.** Her acil-yol okuması artık şifre-çözmeye, dolayısıyla Keystore anahtarının erişilebilirliğine bağımlı. Anahtar erişilemezse/çözme hatası olursa kişi **okunamaz** → acil anda boş/yanlış. 4 okuma noktasında çözme hatası fail-safe'i bozar. En riskli seçenek. | **Orta-Yüksek.** Mevcut düz-metin satırlar tek seferde şifrelenmeli (DB v3 + onUpgrade). `phone TEXT UNIQUE` kısıtı şifreli değerle bozulur (aynı düz metin farklı IV → farklı ciphertext → UNIQUE çalışmaz, dedupe kırılır). Şema yeniden tasarımı gerekir. | **Yüksek.** Keystore'dan anahtar türetme + sqflite katmanına şeffaf şifrele/çöz + UNIQUE/sorgu sorunları + IV yönetimi. `EncryptionService` baştan yazılır (mevcut dart-define modeli atılır). | **Orta.** Mevcut `EncryptionService`'i yeniden kullanır ama anahtar modelini tamamen değiştirir; sqflite katmanına şifreleme serpiştirmek temiz mimariye aykırı. | **Düşük-Orta** |
| **H3** | **Hibrit / minimal.** Acil yolun okuduğu kaynağı tek bir yere sabitle (tercihen secure storage); DB'yi PII içermeyecek/şifreli role daralt. | **Düşük-Orta.** Tek okuma kaynağı + (örn. başlangıçta belleğe ısıtılmış kopya) ile fail-safe korunabilir; acil yol secure-storage'dan tek sefer okur, kalanı bellekten servis eder. | **Düşük-Orta.** Kapsam dar tutulursa kademeli yapılabilir; yine idempotent migrasyon + doğrulama. | **Orta.** H1 ile H2 arası; "rol ayrımı" netleştirilmeli (DB neyi tutar?). | **İyi.** Acil yol tek, sade, anahtarsız-bellek okumasına indirgenebilir. | **Orta** |

### 3.1 SQLCipher (ek seçenek, not)

Tam-DB şifreleme için `sqflite_sqlcipher` + Keystore'dan türetilmiş parola da
mümkün. Avantaj: tüm tablolar (contacts + crash_logs + activity_events) korunur,
UNIQUE/sorgu sorunu yok (DB içeride düz, dosya şifreli). Dezavantaj: yeni native
bağımlılık, açılışta DB parolası Keystore'a bağlı → açılış fail-safe'i ek
inceleme ister, APK boyutu/16KB sayfa uyumu doğrulanmalı. **Bu turda derinlemesine
değerlendirilmedi; H1 reddedilirse ikinci tur adayı.**

---

## 4. Önerilen Yön + Gerekçe

**Öneri (karar kullanıcıya ait): H1 — "Tek kaynak = secure storage"** (gerekirse
H3'ün fail-safe bellek-ısıtma desenleriyle güçlendirilmiş).

Gerekçe:
1. **Mimari uyum + en az yeni yüzey:** Cihaz-bağlı anahtar altyapısı
   (`flutter_secure_storage`) projede **zaten var ve PIN için kanıtlanmış.** Yeni
   kripto kodu, IV yönetimi, şema değişikliği gerektirmez.
2. **H2'nin fail-safe maliyeti çok yüksek:** Acil yola 4 noktada şifre-çözme
   bağımlılığı eklemek, KRİTİK kısıtın ("acil anda asla okunamama olmamalı")
   doğrudan ihlal riskidir. Ayrıca `phone UNIQUE` + dedupe, IV'li şifrelemeyle
   doğal olarak çakışır.
3. **Ölü kodu sahiplenmemek:** `EncryptionService` + dart-define statik anahtar
   model olarak zayıf; H2 bu modeli yenilemek yerine **emekliye ayırmak** daha
   temiz (ayrı temizlik turu).
4. **H1'in fail-safe riski yönetilebilir:** Tek async okuma riskine karşı —
   uygulama açılışında bir kez okuyup belleğe ısıtma (H3 deseni) + iOS'taki
   `first_unlock_this_device` muadili Android davranışının doğrulanması.

> Not: H1 seçilse bile **kararı kullanıcı verecek.** H2 tercih edilirse, §2.6'daki
> Keystore deseni ve `phone UNIQUE` sorunu önce çözülmeli.

---

## 5. Açık Riskler

- **R1 — Keystore unlock zamanlaması (H1/H2):** Android'de secure storage'ın
  cihaz açıldıktan ama kullanıcı ilk unlock'tan önce okunabilirliği netleştirilmeli.
  Acil yol "boot sonrası kilitli" durumda da çalışmalı.
- **R2 — `phone UNIQUE` + şifreleme çakışması (H2):** Rastgele IV, deterministik
  olmayan ciphertext üretir; UNIQUE kısıtı ve telefon-eşleştirme/dedupe bozulur.
- **R3 — Native AlarmManager yedeği:** `countdown_screen.dart:131` numarayı Dart
  tarafında okuyup native'e iletiyor. Okuma kaynağı değişince bu zincirin hâlâ
  doğru numarayı ilettiği device-testle doğrulanmalı.
- **R4 — KVKK veri dışa aktarımı:** `user_data_export_service.dart:24` aynı veriyi
  okuyor; yeni kaynağa uyarlanmalı.
- **R5 — Yarım migrasyon → veri kaybı:** Mevcut kullanıcıların kayıtlı kişisi
  taşıma sırasında kaybolmamalı (mutlak kısıt). Migrasyon idempotent olmalı ve
  **eski kaynağı yalnızca yeni kaynağa yazım doğrulandıktan sonra** silmeli.
- **R6 — flutter_secure_storage v10 backend belirsizliği:** §2.6, orta güven —
  uygulama öncesi teyit.

---

## 6. Migrasyon Stratejisi Taslağı (uygulama turu için)

> Mutlak kısıt: **mevcut kayıtlı acil kişi migrasyonda KAYBOLMAMALI.**

1. **Geri-uyumlu okuma:** Yeni kaynak boşsa, eski DB `contacts` tablosundan oku
   (mevcut `_migrateLegacyContacts` deseninin tersi yönü).
2. **Yaz + DOĞRULA:** Yeni kaynağa yaz, sonra geri okuyup kişi sayısı/içerik
   eşleşmesini doğrula.
3. **Yalnız doğrulama sonrası temizle:** Eski düz-metin satırları ancak
   doğrulama geçince sil (idempotent — yarıda kesilirse tekrar çalışınca kayıp
   olmaz).
4. **Fail-safe ısıtma:** Açılışta acil kişiyi bir kez okuyup bellekte tut; acil
   yol önce bellekten servis etsin, depo erişimi gecikse bile kişi okunabilsin.
5. **Device-test:** Doze + reboot-öncesi-unlock + denied-permission senaryolarında
   panik akışının kişiyi doğru okuduğunu cihazda doğrula (bu repo'da emniyet
   yarışları yalnız cihazda test edilir konvansiyonu).
6. **Ölü kod:** `EncryptionService` ve dart-define `ENCRYPTION_KEY` zinciri H1'de
   kullanılmıyorsa **ayrı temizlik turunda** kaldır/emekliye ayır (bu görevin
   kapsamı dışında).

---

## 7. Karar Bekleniyor

Bu belge salt-okunur araştırmadır. Uygulama öncesi seçim gereken nokta:

- **Hangi hipotez?** (öneri: **H1**; alternatifler H3, H2, ya da §3.1 SQLCipher)
- H2 seçilirse: §2.6 Keystore deseni + R2 (`UNIQUE`) önce çözülmeli.
- Onay sonrası ayrı bir **plan-onay turunda** TDD ile uygulanacak; bu turda
  **kod değişikliği yok.**

---

## 8. Seçilen Yön: H1 + Bellek-Isıtma — 3 Kritik Riskin Çözümü

> **Karar:** **H1 (tek kaynak = `flutter_secure_storage`)**, H3'ün **bellek-ısıtma**
> (read-through cache) deseniyle güçlendirilmiş. DB'deki düz-metin acil-kişi PII'si
> kaldırılır; okuma/yazma secure storage'a taşınır. Aşağıda uygulama öncesi
> çözülmesi gereken 3 kritik riskin **kanıtlı** analizi ve her biri için kesin
> karar + güven seviyesi var. **Bu bölüm uygulama turunun planıdır.**

### 8.0 Okuma/yazma zinciri (kanıt)

Tüm acil-kişi erişimi tek, ince bir geçiş zincirinden geçiyor — bu, H1'i tek
noktadan uygulanabilir kılar:

```
Repository (contacts_repository_impl.dart:31,49)
  → LocalDataSource (contacts_local_datasource.dart:20,35)
    → ContactService (static, contact_service.dart)
      → [BUGÜN] LocalDatabaseService → sqflite contacts tablosu
      → [H1 SONRASI] SecureStorage (JSON) + bellek cache
```

`ContactService` tek değişim noktasıdır; repo/datasource imzaları (`Future`
döndürüyor) **değişmeden** kalır.

---

### 8.1 RİSK 1 — Native AlarmManager yedeği → **H1'i BOZMUYOR** ✅ (güven: YÜKSEK)

**Bulgu (kesin):** Native taraf acil kişiyi **SQLite DB'den OKUMUYOR.** Numara,
Dart tarafında okunup **method-channel argümanı** olarak native'e geçiriliyor ve
native kendi **SharedPreferences** dosyasına yazıyor. Tam zincir:

1. `countdown_screen.dart:131` — Dart `getAllEmergencyNumbers()` + `:120`
   `getPrimaryEmergencyContact()` ile numarayı **Dart tarafında** seçer
   (`_scheduleNativeBackupAlarm`, :129-156).
2. `emergency_platform_service.dart:225-229` — `scheduleCountdownAlarm` method
   channel çağrısı, `primaryNumber`'ı **string argüman** olarak gönderir.
3. `EmergencyPlatformHandler.kt:72-80` — `call.argument<String>("primaryNumber")`
   okur, `CountdownAlarmScheduler.schedule(...)`'a verir.
4. `CountdownAlarmScheduler.kt:33-40` — numarayı `korubeni_emergency`
   SharedPreferences dosyasına (`KEY_COUNTDOWN_PRIMARY_NUMBER`) `.commit()` ile yazar.
5. `CountdownAlarmReceiver.kt:52-53` — alarm tetiklenince numarayı **bu prefs'ten**
   geri okur; `EmergencyExecutor.executeEmergency` ile arar.

**Sonuç:** Native yedek, Dart okumasının **aşağı-akışındadır**; kendi DB bağımlılığı
**hiç yoktu.** H1, DB→secure storage geçişini yalnız **Dart-tarafı okuma kaynağında**
yapar; native'e veri ulaştırma yolu (method-channel arg → native prefs)
**hiç değişmez.** Force-stop/Doze senaryosunda native yedek aynen çalışmaya devam
eder — çünkü numara, countdown kurulurken zaten native prefs'e yazılmıştır ve
alarm Flutter motoru donmuşken bile o prefs'ten okunur.

**Tek gereksinim:** `_scheduleNativeBackupAlarm` içindeki Dart okuması (`:131`)
countdown başlarken numarayı çözebilmeli. Bu çağrı **bugün de `await`'li (async)**;
secure storage okumasına geçmek bu noktada kırıcı değil. Numara çözülemezse bugünkü
davranış korunur: native yedek atlanır, Dart yolu manuel-arama fail-safe'i gösterir
(`countdown_screen.dart:144-148`).

> **İkincil bulgu (dürüstlük notu) — native prefs'te düz-metin PII kalıntısı:**
> Native yedek, tasarımı gereği numarayı `korubeni_emergency` SharedPreferences'a
> **düz metin** yazar (`CountdownAlarmScheduler.kt:38`; check-in için muadili
> `CheckInScheduler.kt:40`). Bu **kaçınılmazdır:** Flutter motoru donmuşken çalışan
> native kod `flutter_secure_storage`'ı (Dart-tarafı plugin) **okuyamaz**; numara,
> motora ihtiyaç duymadan erişilebilir bir yere bırakılmalıdır. Dolayısıyla H1,
> "at-rest sıfır düz-metin PII" hedefine **tam ulaşmaz**: bir countdown/check-in
> **etkinken** (veya yarıda kesilmişken) native prefs'te geçici bir düz-metin kopya
> bulunur. Değerlendirme:
> - Bu dosya app-private (`MODE_PRIVATE`) — eski SQLite DB ile **aynı** koruma
>   seviyesi; yani H1 durumu **kötüleştirmez**, kalıcı DB kopyasını geçici
>   arm-süresi kopyasına indirir.
> - `cancel()` anahtarları siler (`CountdownAlarmScheduler.kt:87-93`), ama
>   `CountdownAlarmReceiver` **fire sonrası `KEY_COUNTDOWN_PRIMARY_NUMBER`'ı
>   temizlemiyor** (yalnız `ACTIVE=false`, `ALARM_FIRED=true` yazıyor, :46-48,
>   :87-89). Doze-fire senaryosunda numara bir sonraki `cancel`/`schedule`'a kadar
>   prefs'te kalır.
> - **Karar:** Native yedeği **olduğu gibi bırak** (H1 native'e dokunmaz). Native
>   prefs düz-metin kalıntısı (a) önceden var, (b) frozen-engine yedeği için
>   yapısal zorunluluk, (c) app-private. İsteğe bağlı **küçük sertleştirme** (ayrı,
>   düşük öncelikli): receiver fire/handoff sonrası `KEY_COUNTDOWN_PRIMARY_NUMBER`'ı
>   sil. Bu, H1 için **gerekli değil**, kapsam dışı bir iyileştirmedir.

**Karar:** H1 uygulanabilir; native AlarmManager yedeği **değiştirilmez.**
Güven: **YÜKSEK** (zincir uçtan uca kanıtlı).

---

### 8.2 RİSK 2 — Senkron→asenkron geçişi → **GERÇEKTE GEÇİŞ YOK** ✅ (güven: YÜKSEK)

**Bulgu (önemli düzeltme):** 4 acil-okuma noktasının **hiçbiri senkron değil** —
hepsi bugün zaten `Future` döndürüp `await`'leniyor (çünkü sqflite zaten async):

| Nokta | Çağrı | Bugünkü hâli |
|-------|-------|--------------|
| `panic_button.dart:179` | `await ContactService.getAllEmergencyNumbers()` | **async** (ön-kontrol) |
| `countdown_screen.dart:120` | `await _contactsRepository.getPrimaryEmergencyContact()` | **async** (initState'te fire-and-forget) |
| `countdown_screen.dart:131` | `await _contactsRepository.getAllEmergencyNumbers()` | **async** (native yedek kurma) |
| `countdown_screen.dart:249` | `await _contactsRepository.getAllEmergencyNumbers()` | **async** (arama tetikleme) |

§2.3'teki "senkron düz-metin DB okuması" ifadesi **yanlıştı** — düzeltiliyor.
sqflite→secure storage geçişi çağrı-noktası **sözleşmesini değiştirmez**; sync→async
refactor **gerekmez.** Bu, Risk 2'yi büyük ölçüde söndürür.

**Gerçek risk (latency/erişilebilirlik):** secure storage okuması Android'de
Keystore-decrypt nedeniyle **daha yavaş** olabilir ve Keystore kilitliyken
(boot-sonrası-unlock-öncesi) **başarısız** olabilir. Bellek-ısıtma deseni
sync-köprü değil, **erişilebilirlik hedge'idir.**

**Bellek-ısıtma deseni (read-through cache) — tasarım:**

- **Katman:** `ContactService` içinde process-ömürlü statik bellek kopyası
  (`static List<EmergencyContact>? _warmCache`). Tüm okumalar tek bu sınıftan
  geçtiği için (8.0 zinciri) tek doğru yerdir.
- **Isıtma tetikleyicileri:**
  1. **Açılışta** — `main()`/bootstrap'te DI sonrası bir kez `await` ile ısıt
     (panik mümkün olmadan önce bellek dolu olsun).
  2. **Her yazımda (write-through)** — `saveContacts`/`savePrimaryEmergencyContact`
     vb. cache'i atomik günceller → **bayatlama yok** (kullanıcı numarayı
     değiştirdiyse acil yol eski numarayı **aramaz**).
  3. **Acil moda girişte** — countdown açılırken bir kez tazele.
- **Okuma:** Acil yol önce `_warmCache`'i kullanır; cache doluysa secure-storage
  gecikmesi/kilidi acil yolu etkilemez. Cache boşsa (cold-start + anında panik)
  bugünkü gibi async secure okumasına düşer.
- **Fail-safe garantisi (mutlak kısıt):** "veri henüz yüklenmedi → kimse aranamadı"
  senaryosu **hiçbir akışta** olmamalı. Garanti zinciri:
  1. Açılış ısıtması, panikten önce cache'i doldurur (birincil savunma).
  2. Cache boş + secure okuma başarısız/boş → bugünkü davranış aynen korunur:
     `_hasCallableContact` false döner / `_executeEmergency` boş listede
     **bloklayan manuel-arama** fail-safe'ini gösterir (`countdown_screen.dart:305-315`).
     Yani H1 **yeni** bir "sessiz başarısızlık" yolu eklemez.
  3. **Asla** son bilinen geçerli kişiyi, geçici Keystore hatası yüzünden
     "yok" sayma: cache son başarılı okumayı tutar; Keystore anlık erişilemezse
     bellekteki kopya hâlâ servis edilir.
- **Cache invalidation:** Yalnız "Verilerimi Sil" (KVKK) ve contact silme cache'i
  temizler; aksi hâlde cache her zaman son geçerli kişiyi taşır.

**Karar:** H1 + açılışta-ısıtılan write-through bellek cache. sync→async refactor
yok. Güven: **YÜKSEK** (zaten-async kanıtlı); ısıtma deseni güven: **YÜKSEK-ORTA**
(cihaz-testiyle Keystore-kilit senaryosu doğrulanacak — §8.4).

---

### 8.3 RİSK 3 — Migrasyon güvenliği → idempotent, doğrula-önce-sil ✅ (güven: YÜKSEK)

**Tablo kullanımı (kanıt):** `contacts` tablosu **yalnız acil kişiler** için
kullanılıyor. Diğer tablolar (`activity_events`, `crash_logs`, `app_settings` —
`local_database_service.dart:36-68`) ayrı; bunlara dokunulmuyor. Yani acil-kişi
verisini tablodan tümüyle çıkarmak **başka hiçbir özelliği etkilemez.**

**`phone UNIQUE` notu:** Bu yalnız bir **DB kısıtıydı**; H1'de JSON modeline
geçince dedupe zaten Dart'ta yapılıyor (`contact_service.dart:64-65`,
`matchesPhone`). H2'nin `UNIQUE`+IV çakışması (§R2) H1'de **yok.**

**Migrasyon stratejisi (DB → secure storage; idempotent, best-effort,
doğrula-önce-sil):**

1. **Secure-öncelikli okuma + DB-fallback:** `ContactService` okuması önce secure
   storage'a bakar. Secure boş **ve** DB `contacts` doluysa → migrasyonu tetikle
   (bugünkü `if (rows.isEmpty) _migrateLegacyContacts()` deseninin **tersi yönü**,
   `contact_service.dart:102-108,176-184`).
2. **Yaz + DOĞRULA:** DB satırlarını JSON olarak secure'a yaz; sonra **geri oku**,
   kişi sayısı + içerik (normalized phone, is_primary, sıra) eşleşmesini doğrula.
3. **Yalnız doğrulama sonrası DB'yi temizle:** Doğrulama geçerse DB satırlarını sil
   (`txn.delete('contacts')`). Doğrulama geçmezse **DB'yi SİLME** — okuma DB'den
   fallback ile çalışmaya devam eder (kişi asla kaybolmaz).
4. **Idempotent (kill-safe):**
   - 2 ve 3 arasında kill (yazıldı, silinmedi): sonraki açılış → secure dolu →
     okuma secure'dan; DB'de artık (kullanılmayan) düz-metin satır kalır → tekrar
     çalışan migrasyon doğrulayıp siler. **Kayıp yok**, sadece geç temizlik.
   - 1 ve 2 arasında kill (secure hâlâ boş): sonraki açılış → secure boş + DB dolu
     → migrasyon baştan çalışır. **Kayıp yok.**
   - Hiçbir durumda veri "ne DB'de ne secure'da" yarım kalmaz: silme **her zaman**
     başarılı+doğrulanmış secure yazımının arkasında.
5. **Tabloyu bırakma kararı:** `contacts` tablosunu **silME**; şemayı koru, yalnız
   satırları migrasyon sonrası boşalt. Gerekçe: (a) düşük risk/geri-alınabilir
   rollout — migrasyon hatası olsa bile şema kaybı yok; (b) DB sürüm bump'ı +
   `onUpgrade` ile şema düşürmek riskli ve gereksiz. Boş tablonun bırakılması
   zararsız. **Tabloyu tamamen kaldırma ayrı bir temizlik turuna** ertelenir
   (ölü `EncryptionService`+dart-define temizliğiyle birlikte, §6.6).
6. **Veri modeli:** Mevcut `EmergencyContact` yalnız `name`+`phone` tutuyor
   (`contact_service.dart:371-395`). Secure JSON modeli `isPrimary` + sıralama
   bilgisini de taşımalı (bugün SQL'de `is_primary DESC, created_at ASC`,
   `:99`). Uygulama turunda `EmergencyContact.toJson/fromJson` genişletilecek
   veya liste düzeyinde bir zarf (ordered list + primary index) kullanılacak.

**Karar:** Idempotent, doğrula-önce-sil migrasyonu; tablo şeması korunur, satırlar
boşaltılır. Güven: **YÜKSEK.**

---

### 8.4 Uygulama turu — kalan doğrulamalar ve açık riskler

- **R6 (flutter_secure_storage v10 backend):** §2.6 — **orta güven.** Uygulama
  öncesi v10 Android backend'inin Keystore-destekli ve cihaz-bağlı olduğunu
  plugin dökümantasyonuna karşı **teyit et** (Context7/pub). H1'in koruma iddiası
  buna dayanır.
- **R1 (Keystore unlock zamanlaması) → cihaz-testi:** Boot-sonrası-unlock-öncesi,
  Doze, ve denied-permission senaryolarında panik akışının doğru kişiyi
  okuduğunu **cihazda** doğrula (repo konvansiyonu: emniyet yarışları yalnız
  cihazda test edilir — `[[emergency-flow-test-convention]]`). Açılış-ısıtması bu
  riski büyük ölçüde kapatmalı; cihaz-testi teyit eder.
- **R4 (KVKK dışa aktarım):** `user_data_export_service.dart:24`
  `getContactRecords()` çağırıyor — H1 sonrası secure kaynaktan okuyacak (zincir
  aynı `ContactService`'ten geçtiği için otomatik uyumlu; teyit edilecek).
- **Native prefs sertleştirme (opsiyonel, kapsam dışı):** §8.1 — receiver
  fire/handoff sonrası `KEY_COUNTDOWN_PRIMARY_NUMBER` temizliği. H1 için gerekli
  değil.
- **Test stratejisi:** Migrasyon (idempotent/kill-safe), write-through cache
  tazeleme, cache-boş-fallback için kaynak-sözleşmeli birim testleri; Keystore-kilit
  ve Doze için cihaz-testi (`[[emergency-flow-test-convention]]`). Yeni dosyaları
  formatla, mevcut satırları formatlama (`[[dart-format-drift]]`).

### 8.5 Özet — yön onaya hazır

| Risk | Karar | H1'i bozuyor mu? | Güven |
|------|-------|-------------------|-------|
| 1 · Native AlarmManager | Native'e dokunma; numara zaten method-channel arg → native prefs | **HAYIR** | YÜKSEK |
| 2 · Sync→async | Geçiş yok (zaten async); write-through bellek-ısıtma ekle | **HAYIR** | YÜKSEK |
| 3 · Migrasyon | Idempotent + doğrula-önce-sil; tablo şeması kalır, satır boşalır | **HAYIR** | YÜKSEK |

**R6 (secure storage v10 backend) artık TEYİT EDİLDİ → §9.** Kalan tek koşullu
kalem, donanım-destek (StrongBox) zorlanmaması ve decrypt-hata davranışıdır
(§9'da açık riskler). Diğer her şey yüksek güven. **Yön (H1 + bellek-ısıtma)
uygulama planı olarak onaya hazır; kod ayrı turda yazılacak.**

---

## 9. R6 Teyidi — flutter_secure_storage v10 Android Backend (kaynak-doğrulamalı)

> **Amaç:** H1'in temel varsayımını — "acil-kişi PII'si secure storage'a taşınınca
> şifreleme anahtarı **cihazdan çıkamaz**" — birincil kaynaklarla doğrulamak.
> Sürüm `pubspec.lock`'ta **10.0.0** (pin: `^10.0.0`, `pubspec.yaml:38`). Android
> implementasyonu çekirdek pakette (ayrı `_android` federe paketi yok); uygulamamız
> varsayılan `AndroidOptions()` kullanıyor (`secure_storage.dart:8`).

### 9.1 İddia bazında bulgular

| # | İddia | Bulgu | Kaynak | Güven |
|---|-------|-------|--------|-------|
| 1 | **Mekanizma** | Hibrit: AndroidKeyStore'da üretilen **RSA-OAEP** anahtar çifti, bir **AES-GCM** veri anahtarını sarmalıyor (wrap/unwrap); asıl veri AES/GCM ile şifrelenip SharedPreferences'a yazılıyor. v10, **deprecate edilmiş** Jetpack `EncryptedSharedPreferences`'tan **ayrıldı**, özel cipher'lara geçti. | Plugin kaynağı `KeyCipherImplementationRSA18.java` + `…RSAOAEP.java` (v10.0.0 tag) · `StorageCipherImplementationGCM.java` · resmi README "Important notice for Android" | **YÜKSEK** (kaynak-okumalı) |
| 2 | **Cihaza-bağlı / dışa-aktarılamaz** | **EVET.** RSA çifti doğrudan `KeyPairGenerator.getInstance("RSA", "AndroidKeyStore")` ile üretiliyor; özel anahtar yalnız `keyAlias` altında keystore'da, `wrap/unwrap` işlemleri sistem sürecine devrediliyor. Android Keystore anahtar materyali **dışa aktarılamaz, uygulama sürecine hiç girmez** ("key material remaining non-exportable… never enters the application process"). Sarmalanmış AES anahtarı + ciphertext düz-okunur prefs'te dursa da, **bu cihazın keystore'u olmadan çözülemez.** | Kaynak: `KeyCipherImplementationRSA18.java` (`KEYSTORE_PROVIDER_ANDROID = "AndroidKeyStore"`, `createKeys()`) · `developer.android.com/privacy-and-security/keystore` | **YÜKSEK** (iki bağımsız kaynak: plugin kaynağı + Android resmi doc) |
| 3 | **Donanım-destekli (StrongBox/TEE)** | **ZORLANMIYOR.** Varsayılan yolda `setIsStrongBoxBacked(...)` **çağrılmıyor**, `setUserAuthenticationRequired` da yok. Anahtarın TEE-destekli mi yoksa salt-yazılım mı olduğu **cihaza/OS'a bağlı** (modern cihazlarda OS varsayılan olarak TEE'ye koyar, ama plugin garanti etmez). İkisi de "dışa-aktarılamaz" sayılır; salt-yazılım keystore, OS'u ele geçirilmiş cihazda daha zayıftır. StrongBox'ı zorlamak, desteklemeyen cihazlarda `StrongBoxUnavailableException` ile **anahtar üretimini kırardı** — bu yüzden zorlanmaması makul. | Kaynak: `KeyCipherImplementationRSA18.makeAlgorithmParameterSpec()` (StrongBox çağrısı yok) · Android doc (StrongBox opsiyonel, API 28+) | **YÜKSEK** ("zorlanmıyor" kesin); cihaz-bazlı TEE backing: **ORTA** (cihaza göre değişir, tek tek garanti edilemez) |
| 4a | **Caveat — EncryptedSharedPreferences deprecation** | v10 zaten bu deprecate API'den **ayrıldı**; deprecate yola **bağımlı değiliz.** | Resmi README · pub.dev changelog | **YÜKSEK** |
| 4b | **Caveat — yedekleme `InvalidKeyException`** | Plugin uyarısı: Android auto-backup (Google Drive) şifreli prefs'i yedekler ama cihaz-bağlı keystore anahtarı yedeklenmez → yeni cihazda geri-yüklemede veri **çözülemez** olur. **Bizde zaten azaltılmış:** `AndroidManifest.xml:57-58` `allowBackup="false"` + `fullBackupContent="false"`. Restore-to-new-device senaryosu **yok.** | Resmi README · `android/app/src/main/AndroidManifest.xml:57-58` (bizim manifest) | **YÜKSEK** (bizim manifestte doğrulandı) |
| 4c | **Caveat — root'lu / ele geçirilmiş OS** | Keystore, anahtarın **çıkarılmasını** engeller ama OS ele geçirilmişse uygulama kimliğiyle çalışan saldırgan anahtarı **yerinde kullanıp** çözebilir. Tüm keystore çözümleri için **yapısal**; H1'in tehdit modeli ("cihaz ele geçirildi / yedekten çıkarıldı, **at-rest** çevrimdışı saldırgan") yine de karşılanır. | `developer.android.com/privacy-and-security/keystore` ("can't extract them from the device") | **YÜKSEK** |
| 4d | **Caveat — decrypt-hatasında veri silme** | Plugin'in hata-kurtarma seçenekleri decrypt hatasında veriyi **sıfırlayabilir**; acil-kişi için **sessiz silme ASLA** olmamalı (mutlak kısıt). Uygulama turunda: bu davranışın bizde aktif olmadığını teyit et, hatayı **elle** ele al (fallback + yeniden-ekle istemi), asla otomatik wipe etme. | Bu turda kaynak-doğrulanmadı | **DOĞRULANAMADI** → uygulama turunda teyit |

### 9.2 Net karar

**EVET — flutter_secure_storage v10 Android backend'i H1 için yeterince
cihaz-bağlı/güvenli.** Şifreleme anahtarı (RSA, AndroidKeyStore) **dışa
aktarılamaz** ve **cihazdan çıkamaz** — bu, H1'in tüm kazancının dayandığı
varsayımdır ve hem **plugin kaynağıyla** hem **Android resmi dökümantasyonuyla**
doğrulandı. Düz-metin SQLite'tan buraya taşımak, çevrimdışı/at-rest tehdit modeline
karşı **gerçek** bir koruma artışıdır.

### 9.3 Açık riskler (uygulama turunda ele alınacak)

- **AR-1 (StrongBox zorlanmıyor):** Varsayılan yapı donanım güvenli-elemanını
  zorlamaz; modern cihazlarda TEE varsayılandır ama garanti değildir. **Kabul
  edilebilir** — StrongBox'ı zorlamak desteklemeyen cihazlarda anahtar üretimini
  kırar ("acil kişi her zaman okunabilir" kısıtını ihlal eder). Statü: **kabul.**
- **AR-2 (decrypt-hata davranışı — §9.1 4d):** Secure storage decrypt hatasında
  veriyi **sessizce silmemeli**; hatayı elle yakala, son geçerli bellek-cache'i
  (§8.2) servis et, kullanıcıya yeniden-ekleme yolu sun. **DOĞRULANMADI** —
  uygulama turunda davranışı test et.
- **AR-3 (anahtar kaybı = veri kaybı):** Cihaz-bağlı anahtar; keystore temizlenir
  veya bozulursa (örn. ekran kilidi sıfırlama bazı cihazlarda keystore'u
  etkileyebilir) şifreli kişi okunamaz hâle gelir. Mutlak kısıt gereği: böyle bir
  durumda akış **çökmemeli**; boş-kişi fail-safe'i (§8.2) devreye girmeli ve
  kullanıcı uyarılmalı. Bellek-cache geçici köprü sağlar ama kalıcı çözüm değildir.
  Statü: fail-safe ile **yönetilebilir**, cihaz-testiyle doğrula.

> Sonuç: R6 **YÜKSEK güvenle teyit edildi.** Kalan üç açık risk H1'i bozmaz;
> ikisi (AR-1, AR-3) fail-safe/kabul ile yönetilir, biri (AR-2) uygulama turunda
> davranış-testi gerektirir. **H1 + bellek-ısıtma yönü teknik temelden sağlamdır.**

---

## 10. Uygulama Planı — H1 + write-through bellek cache (TDD, dosya-dosya)

> **Durum: PLAN — KOD YOK.** Bu bölüm onaylanınca **ayrı bir turda** uygulanır.
> Bu turda yalnız bu doküman güncellendi. Plan, §0 değişmez kısıtlarına (acil kişi
> her senaryoda okunabilir; 112 otomatik aranmaz / tek birincil; biyometri yok;
> UI/tema dokunulmaz; offline-first; native acil-arama yedeği değişmez) uyar.
> Kanıtlar §2 ve §8'deki dosya:satır referanslarıyla tutarlıdır.

### 10.1 HEDEF MİMARİ

**Tek kaynak = `flutter_secure_storage`.** `ContactService` (statik, tek geçiş
noktası — `contact_service.dart`) acil kişiyi tek bir kanonik secure-storage
anahtarında JSON zarfı olarak okur/yazar. Açılışta-ısıtılan **write-through**
bellek cache eklenir.

- **Kanonik anahtar (yeni):** `SecureStorageKeys.emergencyContactsV1 =
  'emergency_contacts_v1'`. Eski anahtarlar (`contactsData`,
  `emergencyContactPhone/Name`, `contactsList`, `emergencyContactsList`) **migrasyon
  okuması için korunur**, ayrı temizlik turunda silinir.
- **JSON zarfı (immutable):**
  ```json
  { "version": 1,
    "contacts": [ {"name":"…","phone":"…","isPrimary":true}, … ] }
  ```
  Liste **sırası korunur** (bugünkü `is_primary DESC, created_at ASC` yerine:
  zarf yazılırken primary öne alınır + `isPrimary` bayrağı taşınır). Dedupe
  zaten Dart'ta (`matchesPhone`) — `phone UNIQUE` DB kısıtına gerek yok (§8.3).
- **`EmergencyContact` modeli (`contact_service.dart:371`):** `final bool
  isPrimary` (default `false`) + `copyWith` eklenir. **`toJson()` (name+phone)
  AYNEN korunur** → KVKK export (`user_data_export_service.dart:41`) byte-stable
  kalır. Zarf için ayrı `Map toSecureJson()` (name+phone+isPrimary) eklenir;
  `fromJson` `isPrimary`'yi opsiyonel okur.
- **Bellek cache:** `static List<EmergencyContact>? _cache;` (process-ömürlü).
  Okuma cache doluysa cache'ten; boşsa secure'dan yükle + ısıt. Her yazım cache'i
  yeni listeyle değiştirir (write-through → bayatlama yok).
- **Tek-uçuş (single-flight):** `static Future<List<EmergencyContact>>? _inflight;`
  — eşzamanlı `warmUp()` + okuma çift-migrasyon yapmasın diye aynı future paylaşılır.
- **DB `contacts` tablosu:** şema **KORUNUR**; migrasyon sonrası satırlar boşaltılır,
  artık yazılmaz/okunmaz (kaynak değil). **Tablo kaldırma + DB version bump =
  gelecek temizlik turu** (bu turda DB sürümü 2'de kalır, `onUpgrade`
  değişmez — `local_database_service.dart:10,71`).
- **Korunan public imzalar (repo/datasource DEĞİŞMEZ):** `getContacts`,
  `getContactRecords`, `saveContacts`, `saveContactRecords`, `getEmergencyContact`,
  `savePrimaryEmergencyContact`, `clearPrimaryEmergencyContact`,
  `getAllEmergencyNumbers`, `saveEmergencyContact`, `getEmergencyNumber` — hepsi
  aynı `Future` imzasıyla kalır; gövdeleri secure+cache'e taşınır.
- **Testedilebilirlik düzeltmesi:** `static final _secureStorage` /
  `_databaseService` (`contact_service.dart:21-22`) **getter**'a çevrilir
  (`static SecureStorage get _secureStorage => serviceLocator<SecureStorage>();`)
  — böylece locator reset eden testler taze fake alır. `@visibleForTesting static
  void resetCache()` eklenir.

### 10.2 FAIL-SAFE TASARIMI (en kritik)

Ortak özel yardımcı `_ensureCanonical()`: (gerekirse migrasyon) + listeyi döndürür;
hem `warmUp()` hem cache-boş okuma bunu çağırır. Kurallar:

**(a) Cold-start + bellek ısınmadan panik.** `panic_button.dart:179`,
`countdown_screen.dart:131,249` **bugün de `await`'li** (§8.2). Cache `null` ise
`getAllEmergencyNumbers()` → `_ensureCanonical()`'i await eder → secure read (gerekirse
DB fallback) → liste döner. **Bugünkü bloklayan davranış birebir korunur.** Liste
boşsa `_hasCallableContact` false → mevcut "kişi gerekli" UI'ı; boş listede
`_executeEmergency` 112 sentezlemez, **bloklayan manuel-arama** fail-safe'i gösterir
(`countdown_screen.dart:305-315`). Yeni "sessiz başarısızlık" yolu eklenmez.

**(b) Decrypt hatası / okuma başarısız (AR-2) — SESSİZ SİLME ASLA.** Kanonik
okuma `try/catch` içinde:
1. **read EXCEPTION** (Keystore decrypt/erişim hatası): **hiçbir şey silme/yazma.**
   Sırayla: (i) `_cache` doluysa son-geçerli cache'i döndür; (ii) değilse DB
   `contacts` satırlarını **salt-oku** (migrate/clear YOK) ve döndür; (iii) o da
   boşsa `[]` döndür → mevcut "kişi yok" fail-safe'ine düşer. **Asla throw etme,
   asla kanonik anahtarı silme.**
2. **read SUCCESS + değer var** → decode + cache + döndür.
3. **read SUCCESS + null/boş** → migrasyon kapısı (10.3). Bir read EXCEPTION'ı
   **"secure boş" sayılMAZ** — yoksa migrasyon yanlış tetiklenir. Bu ayrım AR-2'nin
   çekirdeği.
4. **decode FAILURE** (anahtar var ama bozuk) + DB satırları hâlâ varsa → onarım:
   DB'den yeniden kur (10.3). DB boşsa son-geçerli cache veya `[]` (silme yok).

**(c) Bellek cache bayatlaması — write-through garantisi.** Tüm yazım yolları
(`saveContactRecords`, `saveContacts`, `savePrimaryEmergencyContact`,
`clearPrimaryEmergencyContact`) önce kanonik secure'a yazar, sonra `_cache`'i yeni
listeyle **atomik değiştirir**. Kullanıcı numarayı değiştirdiyse acil yol eski
numarayı **asla aramaz**. Cache invalidation yalnız: KVKK "Verilerimi Sil" (10.6).

### 10.3 MİGRASYON (kayıp-imkânsız, idempotent, kill-safe)

Tek rutin `_migrateToCanonicalIfNeeded()` — eski `_migrateLegacyContacts`
(secure→DB, `contact_service.dart:219-251`) + yeni DB→secure'u **tek yöne** birleştirir
(ping-pong yok: tek hedef = kanonik secure, tek yön).

**Değişmez invariant:** _DB `contacts` satırları varsa migrasyon henüz
doğrulanmış-tamam değildir._ Bu yüzden **DB'de satır olduğu sürece her açılışta
rutin çalışır** (ucuz); satır kalmayınca kanonik tek kaynaktır.

**Adımlar (kanonik anahtar yokken / DB satırı varken):**
1. **Kaynak seç (öncelik):** DB `contacts` doluysa → DB'den oku (en güncel format,
   `is_primary` + sıra korunur). DB boş ama legacy secure/prefs doluysa
   (`contactsData` / `saved_contacts` / `emergencyContactPhone+Name`) → legacy'den
   oku (eski mantık port edilir).
2. **YAZ:** Listeyi `emergency_contacts_v1` zarfı olarak secure'a yaz.
3. **DOĞRULA:** Geri oku + decode; **count + normalized-phone kümesi + primary
   eşleşmesi** kontrol et.
4. **ANCAK doğrulama geçerse TEMİZLE:** `txn.delete('contacts')` (atomik) + legacy
   anahtar/prefs'leri sil (`_clearLegacyContactStorage` mantığı).
   **Doğrulama geçmezse:** DB'ye/legacy'ye **DOKUNMA**; az önce yazılan kanonik
   anahtarı **sil** (sonraki açılış temiz tekrar etsin); kaynak DB/legacy olarak
   kalır → kişi okunmaya devam eder.
5. **Bayrak:** Başarılı pas sonrası `AppConstants.prefContactsSecureMigratedV1 =
   'pref_contacts_secure_migrated_v1'` set edilir — yalnız **legacy-prefs yeniden
   taramasını** atlamak için (kullanıcı sıfır kişiyle de "migrated" sayılsın). DB
   satır varlığı yine de otoritedir (invariant).

**Kill-safe yürüyüş (kayıp asla):**
- Yaz↔doğrula arası kill: DB satırları **durur** → sonraki açılış idempotent
  yeniden yazar/doğrular/siler. Kayıp yok.
- Doğrula↔sil arası kill: kanonik dolu ama DB satır var → sonraki açılış (invariant
  gereği) çalışır, kanonik üzerine-yazar, doğrular, DB'yi siler. Kayıp yok.
- Sil sırasında kill: `txn.delete` **atomik** → ya hep ya hiç; yarım kalmaz.
- Hiçbir anda veri "ne DB'de ne secure'da" değildir: silme **her zaman** başarılı+
  doğrulanmış kanonik yazımın arkasında.

**Eski migrasyonla çakışma:** Rewrite sonrası `getContactRecords`/`getEmergencyContact`
artık DB-hedefli `_migrateLegacyContacts`'i **çağırmaz**; tek `_ensureCanonical` →
`_migrateToCanonicalIfNeeded` zinciri kalır. Tek hedef + tek yön → sonsuz döngü/çift
taşıma imkânsız.

### 10.4 ENCRYPTIONSERVICE + ENCRYPTION_KEY TEMİZLİĞİ → **ÖNERİ: AYRI TUR**

**Analiz.** `EncryptionService` ölü (prod çağıran yok — yalnız kendi dosyası,
DI `service_locator.dart:45-47`, `app_constants.dart:9` yorumu, ve
`test/core/security/encryption_service_test.dart`). Kaldırma zinciri:
`encryption_service.dart` sil → DI kaydı + importu sil → testi sil →
`AppConstants.encryptionKeyBase64` (`app_constants.dart:7-11`) artık kullanılmıyor,
sil → buna bakan `validateReleaseConfiguration` bloğu (`app_environment.dart:36-38`)
sil → CI'daki `--dart-define=ENCRYPTION_KEY` (`ci.yml:75`, `release.yml:124`) artık
**no-op** (Flutter bilinmeyen define'ı yok sayar → build KIRILMAZ).

**Kritik sıra (gelecek tur için):** (1) kod referansı (`encryptionKeyBase64`) +
`validate` bloğu **birlikte** kaldırılmalı (biri kalırsa derleme hatası). (2) CI
secret/define **en son, opsiyonel** kaldırılır — bırakılırsa zararsız. Yani CI,
kod kaldırmasından **kırılmaz**; tek kırılma yolu "validate hâlâ ister ama secret
yok" ki bu bizim değişikliğimiz değil.

**ÖNERİ: bu tura ALMA — ayrı, küçük temizlik turu.** Gerekçe: (a) H1, Encryption
service kaldırmaya **bağımlı değil**; (b) bu kaldırma DI + constants + env + CI'a
dokunur → güvenlik-hassas acil-kişi diff'ini gereksiz büyütür ve inceleme yüzeyini
genişletir; (c) §6.6/§8.4 zaten "ayrı temizlik turu" diyor. Bu tur **yalnız
acil-kişi depolamasına** odaklanır. Yukarıdaki kesin sıra gelecek tur için hazır.

### 10.5 TDD — TESTLER (RED→GREEN)

Harness: `TestWidgetsFlutterBinding.ensureInitialized()`; in-memory DB için fake
`LocalDatabaseService` (sqflite ffi `inMemoryDatabasePath`, `contacts` şeması);
`_FakeSecureStorage extends SecureStorage` (in-memory map + okuma/silme sayaçları,
fırlatma enjekte edilebilir — `app_reset_native_prefs_test.dart` deseni);
`SharedPreferences.setMockInitialValues`. Yalnız yeni dosyalar formatlanır
([[dart-format-drift]]).

- **`contact_service_secure_store_test.dart`** (write-through/okuma/ısıtma):
  yaz→oku aynı; yazımdan sonra fake-secure zarfı içerir; cache boşken oku→secure'dan
  ısıt (cache dolar); `getEmergencyContact` primary döner; `getAllEmergencyNumbers`
  primary-önce sıralı; `savePrimary` write-through eski primary'yi düşürür;
  A yaz sonra B yaz → oku B (bayatlama yok).
- **`contact_service_migration_test.dart`** (DB→secure):
  DB satırları + secure boş → ilk okuma migrasyon yapar (secure dolu, DB boşalır,
  primary korunur); idempotent (ikinci çağrı no-op, kopya yok); **kill-safe**
  (DB.delete fırlatsın → DB satır durur + kanonik dolu → tekrar çalışınca yakınsar,
  kişi sayısı **hiç sıfır olmaz**); **doğrula-önce-sil** (read-back uyumsuzluğu →
  DB SİLİNMEZ + kanonik geri-alınır, veri DB fallback'ten okunur); legacy secure/prefs
  yolu (DB boş, `contactsData`/`emergencyContactPhone` dolu → kanonik + legacy temizlenir);
  ping-pong yok (tekrarlı okumada DB boş kalır, legacy yeniden taranmaz).
- **`contact_service_failsafe_test.dart`** (AR-2):
  secure read fırlatır + cache dolu → son-geçerli cache (silme/throw yok);
  read fırlatır + cache boş + DB dolu → DB satırları (migrate/sil YOK);
  read fırlatır + her şey boş → `[]` (mevcut "kişi yok" yoluna düşer, throw yok);
  **assert: read hatasında fake-secure'a 0 yazma/0 silme** (sessiz silme asla).
- **`contact_service_emergency_read_contract_test.dart`** (kaynak-sözleşmeli,
  [[emergency-flow-test-convention]]): `panic_button.dart` hâlâ
  `ContactService.getAllEmergencyNumbers()` çağırır; `countdown_screen.dart` native
  yedek + execute noktalarında repo `getAllEmergencyNumbers`/`getPrimaryEmergencyContact`
  okur; `scheduleCountdownAlarm(primaryNumber:)` argümanı Dart-çözümlü numarayı alır;
  safe_walk + check_in hâlâ `getAllEmergencyNumbers` okur; **assert: `contact_service.dart`
  artık `txn.insert('contacts'` içermez** (tek-kaynak kanıtı); biyometri/112-sentez yok.
- **`app_reset_contacts_cache_test.dart`** (KVKK): cache dolu → `clearLocalData` →
  sonraki okuma `[]` (cache invalidate edildi).
- **Kapı:** `flutter analyze` temiz + `flutter test` yeşil +
  `./gradlew :app:testPlayDebugUnitTest` yeşil (native dokunulmadı; regresyon yok
  doğrulanır).
- **Cihaz-only (otomasyon değil):** Keystore-kilitli (boot-öncesi-unlock), Doze,
  denied-permission — R1/AR-3, [[emergency-flow-test-convention]] gereği cihazda.

### 10.6 DEĞİŞECEK DOSYALAR (dosya:satır) + DOKUNULMAYACAKLAR

**Değişecek (bu tur):**
| Dosya | Değişiklik |
|-------|-----------|
| `lib/core/services/contact_service.dart` | Ana rewrite: kanonik secure JSON zarfı + write-through cache + `warmUp()`/`_ensureCanonical()`/`resetCache()` + birleşik `_migrateToCanonicalIfNeeded()`; DB yazımları kaldırılır; statik-final → getter; `EmergencyContact`'a `isPrimary`+`copyWith`+`toSecureJson` (`:371`, `toJson` korunur) |
| `lib/core/security/secure_storage_keys.dart` | `emergencyContactsV1` kanonik anahtarı eklenir; legacy anahtarlar korunur (gelecekte sil) |
| `lib/core/constants/app_constants.dart` | `prefContactsSecureMigratedV1` migrasyon bayrağı eklenir (ENCRYPTION_KEY'e DOKUNMA) |
| `lib/main.dart:~114` | `setupServiceLocator()` sonrası `ContactService.warmUp()` (try/catch, boot'u bloklamaz; lazy yol zaten kendini onarır) |
| `lib/core/services/app_reset_service.dart:14-26` | `deleteAll()`+`deleteDatabaseFile()` sonrası `ContactService.resetCache()` (KVKK cache invalidation) |
| `test/core/services/*` | 10.5'teki 5 yeni test dosyası |

**DOKUNULMAYACAKLAR:**
- **Native acil-arama yedeği:** `EmergencyPlatformHandler.kt`,
  `CountdownAlarmScheduler.kt`, `CountdownAlarmReceiver.kt`, `CheckInScheduler.kt`,
  `emergency_platform_service.dart` (method-channel argümanları aynen — §8.1).
- **UI/ekranlar/state:** `countdown_screen.dart`, `panic_button.dart`,
  `safe_walk_screen.dart`, `check_in_service.dart`, `contacts_provider.dart`,
  contacts sayfaları (imzalar korunduğu için sıfır değişiklik).
- **Repo/datasource:** `contacts_repository_impl.dart`,
  `contacts_local_datasource.dart` (delege ettikleri imzalar değişmez).
- **DB:** `local_database_service.dart` şema/sürüm (tablo kalır, satır boşalır).
- **112 / biyometri / tema:** hiçbiri.
- **EncryptionService / ENCRYPTION_KEY / CI / `app_environment.dart`:** ayrı tur (10.4).

### 10.7 RİSKLER + AÇIK SORULAR

- **AR-1 (StrongBox zorlanmıyor):** değişmez, **kabul** (§9.3).
- **AR-2 (decrypt-hata davranışı):** plan ile çözülür — read-hatasında son-geçerli
  cache / DB fallback / `[]`; **asla silme/throw** (10.2b). `contact_service_failsafe_test`
  assert eder. Kalan: cihazda gerçek plugin exception tipi (muhtemelen
  `PlatformException`) doğrulanmalı; her throw tek-tip ele alınır.
- **AR-3 (anahtar kaybı = veri kaybı):** İlk doğrulanmış migrasyondan **sonra**
  secure tek at-rest kopyadır (DB shadow tutmak KRİTİK-1'i bozardı). Kanonik
  okunamaz + DB boşaltılmış + cache soğuk = kurtarılamaz → boş-liste fail-safe'i
  (çökme yok, kullanıcı yeniden ekler). H1'in **kabul edilen** dengesi (güçlü
  at-rest ↔ anahtar-kaybı kurtarılamazlığı). Cihaz-testiyle doğrula.
- **Export şekli (yeni OQ):** `toJson()` name+phone korunarak export **byte-stable**
  bırakılır; `isPrimary` yalnız `toSecureJson()` zarfında. **Öneri: böyle yap.**
- **warmUp yerleşimi (yeni OQ):** `setupServiceLocator()` sonrası **await** (tek ucuz
  okuma), try/catch ile; lazy `_ensureCanonical` yol korumayı garanti eder.
- **Eşzamanlılık (yeni OQ):** `warmUp` + okuma çift-migrasyonu single-flight
  (`_inflight`) ile engellenir (10.1).
- **R6:** §9'da YÜKSEK güvenle teyitli — açık değil.
