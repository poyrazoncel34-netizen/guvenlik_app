# Cihaz doğrulaması — 2026-08-27 — Sözleşme v4 ve 16 KB çalışma zamanı

**AVD:** `KoruBeni_API36_16k_ctrl`
**Sistem:** Android API 36 · `sdk_gphone16k_arm64` · abi `arm64-v8a`
**Sayfa boyutu:** `getconf PAGE_SIZE` = **16384** (gerçek 16 KB çekirdek)
**Ekran:** 1080x2400 · yoğunluk 420
**Ölçülen commit:** `84984f3` (2026-08-27 10:00:52), çalışma ağacı temiz
**Kurulum kanıtı:** `dumpsys package com.poyrazoncel.korubeni` →
`lastUpdateTime=2026-08-27 11:08:18` — ölçümden dakikalar önce, commit sonrası

---

## Önce yapılan hata ve düzeltmesi

İlk denemede cihazda kurulu olan `com.poyrazoncel.korubeni.smoke` paketi
başlatıldı ve ekran görüntüsü alındı. Parmak izi kontrolünde çıktı:

```
lastUpdateTime = 2026-08-12 02:06:52   (15 gün önce)
ölçülen commit = 2026-08-27 10:00:52
```

O yapı bu oturumun **hiçbir işini içermiyordu**. Ölçüm geçersiz sayıldı ve
atıldı. `CERT2-05` kaydındaki hatanın aynısıydı; orada fark dört saatti, burada
on beş gün. Aşağıdaki bulguların tamamı, güncel ağaçtan yeniden derlenip
kurulan APK üzerinde alınmıştır.

---

## Ölçülenler

| # | Ne | Sonuç | Kanıt |
|---|---|---|---|
| 1 | Native kütüphaneler 16 KB çekirdekte yükleniyor | **PASS** | `FlutterJNI: flutter (null) was loaded normally!` · `dlopen failed` / `UnsatisfiedLink` / `p_align` YOK |
| 2 | Uygulama açılıyor ve ayakta kalıyor | **PASS** | `pidof` = 8033, 18 sn sonra hâlâ canlı; `FATAL EXCEPTION` yok |
| 3 | Sözleşme v4.0.0 uygulamada canlı | **PASS** | Onay ekranı `Sürüm 4.0.0 — 25 Ağustos 2026` gösteriyor |
| 4 | Yaş kapısı ilerlemeyi bloke ediyor | **PASS** | Seçim yapılmadan "Devam Et ve Kurulumu Tamamla" **devre dışı** |
| 5 | Yaş beyanı sorumluluğu kullanıcıya bağlıyor | **PASS** | "Beyanınızın doğruluğundan münhasıran siz sorumlusunuz" ekranda |
| 6 | KVKK sürümü değişmemiş | **PASS** | `3.4.0 — 19 Temmuz 2026` (bu turda bump edilmedi, doğru) |
| 7 | Türkçe diakritikler doğru çiziliyor | **PASS** | Ekran görüntüsü |
| 8 | Native güvenlik çekirdeği instrumentation | **PASS** | `:app:connectedPlayDebugAndroidTest` exit 0 · `Finished 8 tests on KoruBeni_API36_16k_ctrl(AVD)` · başarısızlık yok |

16 KB bulgusu (1), daha önce yapılan **statik** ELF hizalama kontrolünün üstüne
gelir: orada `PT_LOAD` hizalaması okunmuştu, burada kütüphaneler gerçekten
16 KB sayfalı bir çekirdekte **yüklendi**. Hizalama yanlış olsaydı `dlopen`
burada başarısız olurdu.

---

## Ölçülemeyenler — ve neden

| Ne | Engel |
|---|---|
| **Silahlanmış oturumun Doze altında davranışı** | Doze bu emülatörde zorlanabiliyor (`deep idle: IDLE`), ancak panik kurmak Pro yetkisi ister. Yapı `LOCAL_VERIFY_PLACEHOLDER` anahtarıyla derlendi, entitlement fail-closed oluyor ve buton kurulmuyor. **Engel yalnızca donanım değil, billing bağımlılığı** — E1 bu yüzden E2'yi kilitliyor. |
| **Gerçek arama** | Emülatörde SIM ve telefon şebekesi yok. `TelecomManager.placeCall` sonucu gözlemlenemez. |
| **OEM pil yöneticileri** | Xiaomi MIUI / Samsung One UI / Huawei EMUI emülatörde yok. Proje kuralı bunu zaten yazılı olarak kabul ediyor. |
| **Panik → arama süresi** | (2) ve (3) olmadan ölçülemez. |
| **Doze yarışı** | Proje kuralı: cihaz dışında kanıtlanamaz. Bu belge onu iddia etmiyor. |

---

## Sonuç

Bu koşu, **sözleşme v4 ve yaş kapısının gerçek bir Android 16 / 16 KB cihazda
çalıştığını** ve native güvenlik çekirdeğinin bozulmadığını gösterir.

**Acil arama yolunun kendisi hâlâ doğrulanmamıştır** ve bu belge onu doğrulanmış
saymaz. `docs/release/safety_case.md` karar durumu `NO_GO` olarak kalır.
