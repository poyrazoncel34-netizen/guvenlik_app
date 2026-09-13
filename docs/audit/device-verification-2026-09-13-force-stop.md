# Cihaz doğrulaması — 2026-09-13 — Geri sayım sırasında force-stop (G6A)

**AVD:** `KoruBeni_API37_16k` · Android 17 (API 37) · `sdk_gphone16k_arm64` · 16 KB sayfa · yoğunluk 420
**Build:** APK SHA-256 `5238550b…a3b3`, `6c1467c` commit'inden derlendi. Ölçüm `128505e`'de yapıldı;
aradaki commit'ler yalnızca `docs/` (`git diff --name-only 6c1467c 128505e -- lib android scripts` boş).
**Kurulum kanıtı:** `lastUpdateTime=2026-09-13 23:09:28`, varyant B'de `install -r` 23:35:54.
**Yöntem:** Oturum `NativeDozeDispatchProbeTest` ile üretim koordinatöründen kuruldu (hedef sıfırlardan
oluşan parser hedefi, süre 60 sn), ardından `adb shell am force-stop`. Tek seferlik deney script'i repoda
yok; zaman çizelgesi ve tam logcat yerelde `build/qa/force-stop/20260913T203219Z-v2/` altında.

## Sonuçlar

| Adım | Gözlem |
|---|---|
| Kurulum | `lifecycleState=armed`, uygulamanın bekleyen alarmı 3 |
| `am force-stop` | `stopped=true`, bekleyen alarm **0**, kayıt hâlâ `armed` |
| Süreden 20 sn sonrasına kadar | arama yok (`mCallState=0`), kayıt `armed`, kullanıcıya hiçbir şey gösterilmedi |
| **A — kullanıcı uygulamayı açar** | Sistem `PACKAGE_UNSTOPPED` yayınladı ve pakete `LOCKED_BOOT_COMPLETED` gönderdi. `BootCompletedReceiver` Flutter yüklenmeden çalıştı (23:33:42.792), Telecom arama kaydı 82 ms sonra oluştu. Kayıt `requestSubmittedUnconfirmed`. **Açılışta sormadan, yaş sınırı olmadan otomatik arama.** |
| **B — uygulama açılmadan güncelleme** (`install -r`) | Paket `stopped=true` kaldı, receiver çalışmadı, 45 sn'de arama yok, kayıt `armed` kaldı |

İlk deneme (20:27Z) aynı A sonucunu verdi. Onun güncelleme adımı geçersizdi: oturum zaten sonuçlanmıştı
ve log temizlendiği için tetikleyici kaydı kayboldu. Bu nedenle v2'de A ve B ayrı koşuldu.

## Ne anlama geliyor (N-08)

- **Force-stop sürerken arama gitmez ve kullanıcı bilgilendirilmez.** Platformun gereği; G6A da bunu
  bekliyor. Üreticinin normal kullanımda force-stop yapıp yapmadığı telefonda ölçülmeli (protokol Test C).
- **Uygulama ne zaman açılırsa açılsın süresi geçmiş panik oturumu hemen aranır**: 1 dakika sonra da,
  günler sonra da. `reconcile` içinde yaş sınırı yok (`EmergencySessionCoordinator.kt:522-524`).
  G6A'nın beklentisi "gecikmiş durumu dürüstçe göster"di; gözlenen davranış göstermek değil, sormadan aramak.
- Geç aramanın bilinçli bir tercih olduğu belgelerde var ("kaçırılan arama, erken aramadan daha kötü",
  `docs/PLAN_F2_F3.md`). O karar kısa pencereler için verilmişti; "günler sonra açılışta arama" hiç
  tartışılmamış. **Yaş sınırı ve kullanıcıya gösterim bir ürün/güvenlik kararıdır, uygulanmadı.**
- **B, önceki bir iddiamı çürüttü:** durdurulmuş uygulama güncellemede `MY_PACKAGE_REPLACED` almadı. "Play
  güncellemesi günler sonra arama yaptırır" bu emülatörde doğrulanmadı.

## Kanıtlamadıkları

- Yalnızca Android 17 emülatörü. `LOCKED_BOOT_COMPLETED`'ın unstop'ta yeniden gönderilmesi eski sürümlerde
  farklı olabilir; orada açılışta arama hiç olmayabilir (sessiz kayıp sürer). Ölçülmedi.
- Üretici force-stop'u, gerçek reboot ve doğal Doze bu deneyin dışında.

## Yan gözlemler

- **Probe temizliği vadesi geçmiş oturumu iptal edemez.** Temizlikteki `cancel` instrumentation'ı da paketi
  uyandırdı; receiver, iptal kodu okumadan önce oturumu aradı (sıfır hedef, zararsız). Script ve test
  yorumu düzeltildi; protokolde fiziksel cihaz uyarısı var.
- Debug APK, 16 KB emülatörde `PageSizeMismatchDialog` gösterdi. Release AAB'nin 16 KB hizalaması ayrıca
  doğrulanıyor (`scripts/verify_16kb_alignment.sh`); debug build için araştırılmadı.
