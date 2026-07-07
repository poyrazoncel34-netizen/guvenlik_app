# KoruBeni — Döngü Tabanlı İş Akışı Playbook'u

Bu doküman, "loop" (agent'ın bir durma koşuluna kadar iş tekrarlaması) fikrini
KoruBeni'nin gerçek iş akışına uygular. Amaç: senin en çok tekrarladığın manuel
adımları otomatiğe bağlamak. Her madde bir darboğaza karşılık gelir.

> Not: Bu kurulumda `/loop`, `/schedule`, `/code-review` ve `skill-creator`
> mevcuttur. Makalede geçen `/goal` ve "dynamic workflows / auto mode" bu
> kurulumda skill olarak GÖRÜNMÜYOR — kullanmadan önce teyit et.

---

## 1. Turn-based: "bitti" = doğrulama skill'inin yeşili

En büyük darboğaz: yayına giden her değişikliği elle denetlemek. Artık kodlu.

```bash
./scripts/verify_release.sh      # analyze + test + AAB + lint + Kotlin + 16KB
```

- Yerel skill `verify-release-change` bunu değişiklik sonrası çağırır ve
  kısmi/yanlış-yeşil raporu yasaklar.
- 5/5 yeşil = kod kapısı geçildi. Kırmızıysa hangi adımın düştüğünü yazar.
- **KANITLAMAZ** (gerçek cihaz/panel gerekir): Doze, OEM-killer, gerçek satın
  alma, görsel UI, Play Console, 12 tester × 14 gün.

## 2. Script > akıl yürütme (deterministik iş)

Legal sürüm bump'ı artık elle heredoc değil:

```bash
./scripts/bump_legal.sh --kvkk 3.3.0 --date "10 Temmuz 2026" --date-en "July 10, 2026" --dry-run
# önce dry-run ile önizle, sonra --dry-run'ı çıkar
```

Eski değerleri kendisi keşfeder, gh-pages aynasını üretir (elle değil),
parity testiyle biter. Diğer deterministik script'ler: `verify_16kb_alignment.sh`,
`sync_privacy_policy.sh`, `bump_version.sh` (build no).

## 3. Goal-based: net çıkış koşulu olan işler

Deterministik exit'i olan işlerde (parity testi, 16KB, lint) döngünün durma
koşulunu teste bağla. `bump_legal.sh` bunu zaten yapıyor (parity testi = kapı).
Kurulumda `/goal` görünürse: `/goal bump_legal 3.3.0 çalıştır, parity testi
yeşil olana kadar dur` gibi kullanılır — yoksa skill + test aynı işi görür.

## 4. Fresh-context review — yazan ajan değil

"Acımasızca denetle" işe yarıyor ama author-reviewer aynı ajansa taraflıdır
(bu oturumda kendi işimi rasyonalize edip yanlış-yeşile yaklaştım). Ruthless
audit istediğinde:

- `/code-review` (mevcut skill) — taze bağlam, current diff.
- veya ayrı reviewer alt-ajanı: `flutter-reviewer`, `kotlin-reviewer`,
  `security-reviewer` (mevcut agent tipleri).

**Konvansiyon:** üretim + denetim aynı turda AYNI ajana yaptırılmaz; denetimi
taze bağlama devret.

## 5. Time-based: dış-bağımlı Play işleri

Kalan yayın blokörleri kodla kapanmaz; dış sistem beklemesidir. Elle kontrol
yerine izlet (aralık = değişim hızı):

```bash
# CI / PR durumu — değiştikçe kontrol
/loop 10m PR'imi kontrol et, review yorumlarını adresle, CI kırmızıysa düzelt

# Tekrarlayan/zamanlanmış — kapalı test sayacı GÜNLÜK (saatlik değil)
/schedule her sabah 09:00: kapalı testteki tester sayısını ve 14 gün
  koşulunu kontrol et; 12'ye ulaşınca ve süre dolunca bana haber ver
```

İzlenecek dış kapılar (bkz. `docs/audit/session-2026-07-06-uygulama.md`):
- 12 tester × kesintisiz 14 gün (production başvurusunun kritik yolu).
- CI'dan gerçek secret'larla v1.0.0 tag üretim AAB'si.
- 31 Ağustos 2026: API 36 + Billing v8 deadline'ı (kod tarafı hazır).
- Play Console formları: Data Safety, içerik derecelendirme, izin beyanları.

---

## Kod kalitesini korumak (makale ilkeleri, KoruBeni'de)

- **Codebase temiz kalsın:** ajan mevcut desenleri izler → `verify_release.sh`
  ve testler tek "iyi" tanımı.
- **Kendi işini doğrulayabilsin:** skill + `verify_release.sh` = ölçülebilir kapı.
- **Bir sonuç standardı tutmazsa:** tek sonucu düzeltip geçme — kontrolü
  `verify_release.sh`'e/teste ekle ki tüm gelecek iterasyonlar için kapansın.
- **Token yönetimi:** deterministik işi script'e ver (akıl yürütme değil);
  büyük iş öncesi küçük dilimde pilotla; routine'leri gereğinden sık koşturma.
