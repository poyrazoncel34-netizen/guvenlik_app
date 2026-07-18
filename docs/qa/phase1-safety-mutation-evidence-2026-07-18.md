# Phase 1 local safety mutation evidence — 2026-07-18

**Karar:** `LOCAL_PASS / CANDIDATE_UNBOUND / EXTERNAL_UNVERIFIED`

Bu kayıt G0–G3 veya production yayın onayı değildir. Koşu dirty hardening
snapshot'ında yapılmıştır; candidate AAB hash'i yoktur. Tagged release workflow
aynı runner'ı yeniden çalıştırıp sonucu release evidence paketine bağlamadan bu
kanıt candidate için kullanılamaz.

## Kaynak kimliği

- HEAD: `7a5418d05159059f0ee6cd93e2c3b7181228667f`
- Porcelain source-status SHA-256:
  `b0236eb70034073e454abde29dd83d3d95ada61d68dc57b2e62623fe68c9b001`
- Mutation runner SHA-256:
  `b166ea9d128c4c1477bbfe7705680275b13dcb30d70fce01b48f6e1759888a43`
- Yerel JSON evidence SHA-256:
  `09a654e38cc8ae33fc10a65cecc2a68310d89ecfd74a06683d52354be6133fe5`
- Runner ayrıca mutate edilen production dosyaları ve onları öldüren test
  dosyalarının ayrı SHA-256 değerlerini JSON evidence içinde kaydetti.

## Baseline

| Paket | Sonuç | Süre |
| --- | --- | ---: |
| Flutter targeted executable baseline | PASS | 8.746 sn |
| Native `EmergencySessionCoordinatorTest` baseline | PASS | 16.995 sn |

Baseline PASS olmadan hiçbir mutant öldürülmüş sayılmaz.

## Zorunlu mutantlar

| ID | Geri enjekte edilen hata | Sonuç | Süre |
| --- | --- | --- | ---: |
| M01 | Unconfirmed cancel sonucunu success gibi devam ettir | KILLED | 2.664 sn |
| M02 | Stale generation token guard'ını kaldır | KILLED | 4.576 sn |
| M03 | PIN read failure'ı `absent` durumuna indir | KILLED | 2.018 sn |
| M04 | Queue/log/haptic/notification'ı kritik dispatch önüne taşı | KILLED | 1.697 sn |
| M05 | Durable fallback commit başarısızlığını yok say | KILLED | 2.252 sn |
| M06 | Widget `dispose()` içine native cancel geri ekle | KILLED | 3.774 sn |

## Davranış kanıtındaki yeni sınırlar

- Secure-storage read hang'i bounded timeout sonunda `PinState.readFailed`
  olur; PIN dialogu açılmaz ve cancel yetkisi oluşmaz.
- Gerçek `ArmResult.Armed` alan countdown widget dispose edildiğinde native
  `cancelEmergencySession` çağrısı gözlenmez.
- Native cancel `Unknown` dönerse doğru PIN girilmiş olsa bile route kapanmaz ve
  kullanıcıya confirmed cancel gösterilmez.
- Kritik dispatch sonucu queue/DB/log/haptic/Flutter notification
  exception'larından önce alınır; her noncritical boundary bağımsız yakalanır.
- Posted notification'ın durable authorization kaydı yazılamazsa native sonuç
  `FallbackOutcome.FAILED` olur; dead notification actionable sayılmaz.
- Alarm schedule/cancel, notification ve Telecom exception'ları typed dispatch
  sonucunu delmez. Durable tombstone/terminal state doğru kalır; cancel cleanup
  hatası nedeniyle API exception ile çıkmaz.

## Açık kalanlar

- Fiziksel cihaz lifecycle, Doze, reboot, permission revoke ve storage-full
  kanıtları yoktur.
- Bağımsız safety reviewer imzası yoktur.
- Bu koşu immutable AAB, Play-delivered certificate veya G7/G9 soak'a bağlı
  değildir.
