# MASTER PRODUCTION READINESS CHECKLIST

> This checklist is the canonical production-readiness standard for this repository.
> Every individual checkbox is an independent requirement.
> The approximately 80 top-level sections are categories, not 80 individual requirements.
> Do not mark requirements complete inside this file.
> Project-specific PASS/FAIL/PARTIAL/BLOCKED/N/A/UNVERIFIED results must be recorded separately in `PRODUCTION_AUDIT.md`.
> A requirement may only receive PASS when supported by objective evidence.

## 1. Ürün mantığı ve kullanıcı akışları
Her önemli özellik için:
- [ ] Başlangıç noktası belli.
- [ ] Kullanıcı ne yapmak istediğini anlayabiliyor.
- [ ] Primary CTA açık.
- [ ] Secondary CTA primary CTA ile yarışmıyor.
- [ ] Bir sonraki adım tahmin edilebilir.
- [ ] Kullanıcı çıkış yolunu biliyor.
- [ ] Kullanıcı geri dönebiliyor.
- [ ] Yanlış işlem geri alınabiliyor.
- [ ] Geri alınamayan işlem açıkça belirtiliyor.
- [ ] Destructive action confirmation var.
- [ ] Çok kritik işlemlerde ekstra doğrulama var.
- [ ] Kullanıcı yarıda bırakırsa state korunuyor.
- [ ] Refresh sonrası mantıklı state korunuyor.
- [ ] Browser Back doğru çalışıyor.
- [ ] Browser Forward doğru çalışıyor.
- [ ] Deep link doğru ekrana götürüyor.
- [ ] Unauthorized deep link doğru şekilde login'e yönlendiriyor.
- [ ] Login sonrası kullanıcı orijinal deep link'e dönebiliyor.
- [ ] Aynı sayfanın birden fazla tab'da açılması bozulmaya yol açmıyor.
- [ ] Back/forward cache durumları düşünülmüş.
- [ ] Session expire olursa kullanıcının yaptığı iş mümkün olduğunca kaybolmuyor.
- [ ] Kullanıcı bir işlemi iki kere tetiklerse duplicate işlem oluşmuyor.
- [ ] Tüm flow'ların success state'i var.
- [ ] Failure state'i var.
- [ ] Empty state'i var.
- [ ] Loading state'i var.
- [ ] Partial success state'i varsa tasarlanmış.
- [ ] Offline/poor connection state'i düşünülmüş.
- [ ] Timeout state'i düşünülmüş.
- [ ] Permission denied state'i düşünülmüş.
- [ ] Account restricted state'i düşünülmüş.
Apple özellikle kullanıcıların hata yaptıktan sonra kolayca toparlanabilmesi, context'in korunması, tanıdık davranışların kullanılması ve kullanıcıya net feedback verilmesini temel tasarım prensipleri arasında sayıyor. 

## 2. Information Architecture
- [ ] Navigation hiyerarşisi açık.
- [ ] Ana bölümler birbirinden net ayrılmış.
- [ ] Aynı şey farklı yerlerde farklı isimlerle geçmiyor.
- [ ] Breadcrumb gereken yerde var.
- [ ] Kullanıcı nerede olduğunu anlayabiliyor.
- [ ] Kullanıcı ana sayfaya ulaşabiliyor.
- [ ] Logo davranışı tutarlı.
- [ ] Menü sırası mantıklı.
- [ ] Kullanım sıklığı yüksek özellikler daha kolay erişiliyor.
- [ ] Nadir özellikler UI'ı kalabalıklaştırmıyor.
- [ ] Settings kategorileri mantıklı.
- [ ] Çok derin menüler yok.
- [ ] Search gereken ürünlerde search var.
- [ ] Filtreleme gereken ürünlerde filtre var.
- [ ] Sorting gereken ürünlerde sorting var.
- [ ] Kullanıcının mental modeliyle bilgi mimarisi uyuşuyor.

## 3. Genel UI kalite kontrolü
Şimdi senin söylediğin bölüme geliyoruz.
Her ekran
- [ ] Pixel-level alignment düzgün.
- [ ] Horizontal alignment düzgün.
- [ ] Vertical alignment düzgün.
- [ ] Grid sistemi tutarlı.
- [ ] Spacing sistemi tutarlı.
- [ ] Rastgele 13px/17px/21px gibi değerler yok; token sistemi kullanılıyor.
- [ ] Component radius'ları tutarlı.
- [ ] Border kalınlıkları tutarlı.
- [ ] Shadow sistemi tutarlı.
- [ ] Elevation mantığı tutarlı.
- [ ] Layer hierarchy anlaşılır.
- [ ] UI gereksiz kalabalık değil.
- [ ] Kullanıcı nereye bakması gerektiğini anlıyor.
- [ ] Visual hierarchy güçlü.
- [ ] Primary action görsel olarak primary.
- [ ] Dangerous action uygun şekilde ayrıştırılmış.
- [ ] Disabled state gerçekten disabled gibi görünüyor.
- [ ] Interactive element interactive gibi görünüyor.
- [ ] Decorative element interactive gibi görünmüyor.
- [ ] Empty whitespace bilinçli kullanılmış.
- [ ] Alignment ekranlar arasında değişmiyor.
- [ ] Aynı component farklı ekranlarda farklı davranmıyor.
- [ ] İçerik yoğunluğu kullanım senaryosuna uygun.
- [ ] Gereksiz modal kullanılmıyor.
- [ ] Gereksiz tooltip kullanılmıyor.
- [ ] UI jargon kullanmıyor.
- [ ] Placeholder üretim içeriği kalmamış.
- [ ] Lorem ipsum yok.
- [ ] Demo görseller yok.
- [ ] Broken image yok.
- [ ] Missing icon yok.
Apple'ın 2026 tasarım prensipleri bunu doğrudan “Craft — care about every detail”, sadelik, tutarlılık, feedback ve familiarity kavramlarıyla ele alıyor. 

## 4. Design System
Ürün büyüyecekse bu bölüm zorunlu gibi düşün.
- [ ] Design token sistemi var.
- [ ] Color token'ları var.
- [ ] Semantic color token'ları var.
- [ ] Typography token'ları var.
- [ ] Spacing scale var.
- [ ] Radius scale var.
- [ ] Shadow/elevation scale var.
- [ ] Z-index scale var.
- [ ] Motion duration token'ları var.
- [ ] Easing/spring token'ları var.
- [ ] Breakpoint sistemi var.
- [ ] Icon size scale var.
- [ ] Component density sistemi var.
- [ ] Light theme tanımlı.
- [ ] Dark theme tanımlıysa tam.
- [ ] Component API'ları standardize.
- [ ] Button component tek kaynaktan geliyor.
- [ ] Input component tek kaynaktan geliyor.
- [ ] Modal/dialog standardı var.
- [ ] Toast standardı var.
- [ ] Tooltip standardı var.
- [ ] Dropdown standardı var.
- [ ] Table standardı var.
- [ ] Skeleton standardı var.
- [ ] Empty state standardı var.
- [ ] Error state standardı var.
- [ ] Component variation'ları belgelenmiş.
- [ ] Tasarım ve kod component'ları isim olarak eşleşiyor.
- [ ] Kullanılmayan eski component'lar temizleniyor.

## 5. Typography
- [ ] Font ailesi bilinçli seçilmiş.
- [ ] Font lisansı uygun.
- [ ] Webfont performansı kontrol edilmiş.
- [ ] Fallback font var.
- [ ] Font loading sırasında layout aşırı kaymıyor.
- [ ] Heading hierarchy semantik.
- [ ] H1/H2/H3 görsel olarak ayırt ediliyor.
- [ ] Heading kullanımı yalnızca font büyütme amacıyla yapılmıyor.
- [ ] Body text rahat okunuyor.
- [ ] Line-height yeterli.
- [ ] Letter-spacing mantıklı.
- [ ] Çok uzun satırlar yok.
- [ ] Çok kısa satırlar yok.
- [ ] Bold gereksiz kullanılmıyor.
- [ ] Uppercase aşırı kullanılmıyor.
- [ ] Link'ler text'ten ayırt edilebiliyor.
- [ ] Text zoom edildiğinde tasarım bozulmuyor.
- [ ] Dynamic Type/font scaling düşünülmüş.
- [ ] Uzun kullanıcı isimleri UI'ı bozmuyor.
- [ ] Uzun email adresleri UI'ı bozmuyor.
- [ ] Uzun lokalizasyon metinleri UI'ı bozmuyor.
- [ ] Emoji UI'ı bozmuyor.
- [ ] Combining character'lar düşünülmüş.
- [ ] RTL metinler düşünülmüş.
- [ ] Turkish İ/i/ı/I case dönüşümleri test edilmiş.
Android'in güncel kalite testleri de text block'larında okunabilirlik, wrap, clipping ve farklı form factor'larda kompozisyonun ayrıca doğrulanmasını istiyor. 

## 6. Renk sistemi
- [ ] Brand renkleri tanımlı.
- [ ] Semantic success rengi var.
- [ ] Warning rengi var.
- [ ] Error rengi var.
- [ ] Info rengi var.
- [ ] Background renkleri tanımlı.
- [ ] Surface seviyeleri tanımlı.
- [ ] Border renkleri tanımlı.
- [ ] Disabled renkleri tanımlı.
- [ ] Hover renkleri tanımlı.
- [ ] Pressed renkleri tanımlı.
- [ ] Selected renkleri tanımlı.
- [ ] Focus indicator rengi tanımlı.
- [ ] Contrast yeterli.
- [ ] Renk tek bilgi taşıma yöntemi değil.
- [ ] Color blindness durumları kontrol edilmiş.
- [ ] Dark Mode contrast'ı kontrol edilmiş.
- [ ] OLED'de aşırı blooming/contrast problemi yok.
- [ ] Screenshot/export çıktıları okunabilir.

## 7. Responsive / Adaptive layout
Her desteklenen genişlikte:
- [ ] 320px gibi dar ekranlar.
- [ ] Normal telefon.
- [ ] Büyük telefon.
- [ ] Tablet portrait.
- [ ] Tablet landscape.
- [ ] Laptop.
- [ ] Desktop.
- [ ] Ultra-wide.
- [ ] Çok yüksek viewport.
- [ ] Çok kısa viewport.
- [ ] Split-screen.
- [ ] Browser zoom %200.
- [ ] Browser zoom %400 gerektiğinde.
- [ ] Foldable cihaz.
- [ ] Orientation change.
- [ ] Dynamic browser chrome.
- [ ] Mobile keyboard açılmış durum.
- [ ] Safe area/notch.
- [ ] iPhone home indicator.
- [ ] Android navigation bar.
- [ ] Scrollbar görünürken layout.
- [ ] Desktop window resize.
- [ ] Text overflow.
- [ ] Card wrapping.
- [ ] Tables responsive.
- [ ] Charts responsive.
- [ ] Modal responsive.
- [ ] Drawer responsive.
- [ ] Bottom sheet responsive.
Android 2026 kalite standardı özellikle telefon, tablet, foldable, desktop ve resizable/windowed durumlarını kalite kriterinin bir parçası olarak ele alıyor. 

## 8. Bütün component state'leri
Her interactive component için şu matrix tamamlanmalı:
- [ ] Default.
- [ ] Hover.
- [ ] Focus.
- [ ] Focus-visible.
- [ ] Active/pressed.
- [ ] Selected.
- [ ] Disabled.
- [ ] Loading.
- [ ] Success.
- [ ] Warning.
- [ ] Error.
- [ ] Read-only.
- [ ] Empty.
- [ ] Partially selected.
- [ ] Keyboard controlled.
- [ ] Touch controlled.
Özellikle:
Button
- [ ] Primary.
- [ ] Secondary.
- [ ] Tertiary.
- [ ] Ghost.
- [ ] Destructive.
- [ ] Icon-only.
- [ ] Loading button.
- [ ] Disabled button.
- [ ] Long-label button.
Input
- [ ] Empty.
- [ ] Filled.
- [ ] Focus.
- [ ] Invalid.
- [ ] Valid.
- [ ] Disabled.
- [ ] Read-only.
- [ ] Prefix.
- [ ] Suffix.
- [ ] Character limit.
- [ ] Multiline.
- [ ] Autofill.
Aynı mantık checkbox, radio, switch, dropdown, tabs, slider, date picker, file upload vb. için uygulanmalı.

## 9. Motion / animasyon
Sen özellikle bunu söyledin; gerçekten premium hissin büyük kısmı burada oluşuyor.
- [ ] Animasyonun amacı var.
- [ ] Yalnızca gösteriş için animasyon yok.
- [ ] Animasyon kullanıcıya state değişimini anlatıyor.
- [ ] Spatial continuity korunuyor.
- [ ] Bir element kaybolup rastgele başka yerde oluşmuyor.
- [ ] Enter animation mantıklı yönden geliyor.
- [ ] Exit animation aynı spatial mantığı takip ediyor.
- [ ] Gesture ile animation yönü tutarlı.
- [ ] UI tepkisi input'tan hemen sonra başlıyor.
- [ ] Animasyon kullanıcıyı bekletmiyor.
- [ ] Animasyon interrupt edilebiliyor.
- [ ] Rapid interaction sırasında animasyonlar yığılmıyor.
- [ ] Repeated animation rahatsız etmiyor.
- [ ] Duration component boyutuna ve mesafeye uygun.
- [ ] Easing tutarlı.
- [ ] Spring değerleri sistematik.
- [ ] Opacity transition temiz.
- [ ] Scale transition temiz.
- [ ] Blur animation gereksiz kullanılmıyor.
- [ ] Layout animation jank oluşturmuyor.
- [ ] Scroll-triggered animation takılmıyor.
- [ ] Route transitions hızlı.
- [ ] Loading animation gereğinden dramatik değil.
- [ ] Skeleton animation CPU/GPU tüketmiyor.
- [ ] Animasyon düşük güçlü cihazda da düzgün.
- [ ] Reduced Motion destekleniyor.
- [ ] Motion kapalıyken bilgi kaybolmuyor.
- [ ] Animasyon accessibility açısından flashing üretmiyor.
Apple özellikle motion'ın amaçlı olması, kısa ve hassas feedback sağlaması, gereksiz motion'dan kaçınılması, kullanıcı tarafından kesilebilmesi ve Reduce Motion tercihinin desteklenmesini öneriyor. 

## 10. UI fiziği
Burada insanların çoğu hiçbir kontrol yapmıyor.
Drag
- [ ] Element parmağı/mouse'u gecikmeden takip ediyor.
- [ ] Drag başlangıcında jump oluşmuyor.
- [ ] Cursor ile object offset korunuyor.
- [ ] Drag threshold yanlışlıkla tetiklenmeyecek kadar iyi.
- [ ] Drag sınırları belli.
- [ ] Drop zone feedback veriyor.
- [ ] Invalid drop anlaşılır.
- [ ] Cancel edilebiliyor.
- [ ] Touch ve mouse davranışları uygun.
Spring
- [ ] Fazla bounce yok.
- [ ] Underdamped spring kullanıcıyı yormuyor.
- [ ] Overshoot amaca uygun.
- [ ] Element ağırsa hareketi ağır hissettiriyor.
- [ ] Element küçükse çok hantallaşmıyor.
- [ ] Spring sürekli değişmiyor.
- [ ] Velocity continuity korunuyor.
Scroll
- [ ] Scroll doğal.
- [ ] Nested scroll kavgası yok.
- [ ] Scroll lock doğru.
- [ ] Modal açıldığında background scroll etmiyor.
- [ ] Modal kapanınca scroll position korunuyor.
- [ ] Infinite scroll pagination düzgün.
- [ ] Scroll restoration düzgün.
- [ ] Overscroll beklenen davranışta.
Gesture
- [ ] Swipe threshold mantıklı.
- [ ] Swipe velocity hesaba katılıyor.
- [ ] Gesture cancel mümkün.
- [ ] Gesture ile button alternatifi var.
- [ ] Gesture platform convention'larıyla çakışmıyor.
Apple da custom gesture yerine mümkün olduğunca kullanıcıların bildiği platform davranışlarını tercih etmeyi ve complex gesture'lar için alternatif sağlamayı öneriyor. 

## 11. Microinteractions
- [ ] Button press feedback.
- [ ] Toggle feedback.
- [ ] Checkbox feedback.
- [ ] Save feedback.
- [ ] Copy feedback.
- [ ] Upload feedback.
- [ ] Download feedback.
- [ ] Delete feedback.
- [ ] Drag/drop feedback.
- [ ] Validation feedback.
- [ ] Success feedback.
- [ ] Error feedback.
- [ ] Network reconnect feedback.
- [ ] Notification feedback.
- [ ] Like/favorite feedback.
- [ ] Undo feedback.
- [ ] Keyboard shortcut feedback.
- [ ] Haptic varsa animation ile senkron.
- [ ] Sound feedback varsa isteğe bağlı.
- [ ] Feedback gecikmeli gelmiyor.

## 12. Accessibility
Bunu “sonra bakarız” kategorisine koyma.
Hedef olarak web için en azından WCAG 2.2 AA almak mantıklı bir production standardıdır. W3C, WCAG 2.2'nin geniş engel kategorilerini kapsadığını ve otomatik test yanında insan değerlendirmesi de gerektirdiğini açıkça belirtiyor. 
Keyboard
- [ ] Bütün app mouse'suz kullanılabiliyor.
- [ ] Tab order mantıklı.
- [ ] Focus görünür.
- [ ] Focus modal'ın arkasına kaçmıyor.
- [ ] Focus trap gereken yerde var.
- [ ] Modal kapanınca focus tetikleyene dönüyor.
- [ ] Escape uygun yerlerde çalışıyor.
- [ ] Enter/Space doğru component'ı aktive ediyor.
- [ ] Keyboard shortcut'lar conflict yaratmıyor.
Screen reader
- [ ] Semantic HTML/native component kullanılmış.
- [ ] Button gerçekten button.
- [ ] Link gerçekten link.
- [ ] Form label'ları var.
- [ ] Icon-only button'ların accessible name'i var.
- [ ] Decorative images gizlenmiş.
- [ ] Informational images alt text taşıyor.
- [ ] Heading yapısı doğru.
- [ ] Landmarks doğru.
- [ ] Live region gereken yerde var.
- [ ] Error screen reader'a duyuruluyor.
- [ ] Loading state duyuruluyor.
- [ ] Dialog doğru role sahip.
Vision
- [ ] Text contrast.
- [ ] UI contrast.
- [ ] Focus contrast.
- [ ] Zoom.
- [ ] Text scaling.
- [ ] Color-independent information.
- [ ] High Contrast/forced colors mümkünse test edilmiş.
Motor
- [ ] Touch target yeterince büyük.
- [ ] Interactive element'lar birbirine aşırı yakın değil.
- [ ] Drag gerektiren işlem için alternatif var.
- [ ] Multi-touch zorunlu değil.
- [ ] Hover-only özellik yok.
Cognitive
- [ ] Dil sade.
- [ ] Error mesajı açıklayıcı.
- [ ] Aynı işlemler aynı yerde.
- [ ] Auto-dismiss çok hızlı değil.
- [ ] Kullanıcıya yeterli süre tanınıyor.
- [ ] Kritik işlem açık.
WCAG 2.2 özellikle focus'un gizlenmemesi, target size, dragging alternatives, tutarlı yardım ve accessible authentication gibi yeni kriterler ekledi. 

## 13. Copywriting ve microcopy
- [ ] CTA ne olacağını anlatıyor.
- [ ] “Submit” yerine bağlama uygun ifade var.
- [ ] Error mesajı kullanıcı dilinde.
- [ ] Internal error code kullanıcıya tek başına gösterilmiyor.
- [ ] Blame edici dil yok.
- [ ] Success message anlamlı.
- [ ] Tooltip kısa.
- [ ] Empty state kullanıcıya ne yapacağını söylüyor.
- [ ] Confirmation dialog net.
- [ ] Delete confirmation hangi şeyi sileceğini söylüyor.
- [ ] Pricing wording açık.
- [ ] Subscription wording açık.
- [ ] Trial şartları açık.
- [ ] Auto-renewal saklanmıyor.
- [ ] Privacy wording anlaşılır.
- [ ] Permission istemeden önce nedeni anlatılıyor.
- [ ] AI output AI olduğu gereken yerde belirtiliyor.
- [ ] Kullanıcı jargon bilmek zorunda değil.

## 14. Localization / Internationalization
- [ ] String'ler hardcoded değil.
- [ ] Date locale-aware.
- [ ] Time locale-aware.
- [ ] Timezone doğru.
- [ ] Currency locale-aware.
- [ ] Decimal separators doğru.
- [ ] Thousand separators doğru.
- [ ] Number formats doğru.
- [ ] Pluralization doğru.
- [ ] Gender-dependent grammar gerekiyorsa destekli.
- [ ] RTL destekleniyor.
- [ ] Layout RTL mirror ediliyor.
- [ ] Icon'ların RTL davranışı doğru.
- [ ] Long translation test edilmiş.
- [ ] CJK font/test yapılmışsa destek iddiası doğrulanmış.
- [ ] Mixed RTL/LTR strings test edilmiş.
- [ ] Unicode düzgün.
- [ ] Emoji düzgün.
- [ ] Date boundary test edilmiş.
- [ ] DST test edilmiş.
- [ ] Leap year test edilmiş.
- [ ] User locale ve data timezone birbirine karıştırılmıyor.
Apple da localization'ın yalnızca metin çevirmek değil; tarih, para, RTL, icon ve kültürel renk anlamlarını da içerdiğini vurguluyor. 

## 15. Onboarding
- [ ] İlk ekran value proposition'ı gösteriyor.
- [ ] Zorunlu olmayan onboarding zorunlu yapılmıyor.
- [ ] Skip mümkün.
- [ ] Kullanıcı uzun tutorial okumak zorunda değil.
- [ ] Feature gerektiği anda öğretiliyor.
- [ ] Empty state onboarding için kullanılıyor.
- [ ] Permission ilk açılışta topluca istenmiyor.
- [ ] Permission ihtiyaç anında isteniyor.
- [ ] Sample data işe yarıyorsa kullanılıyor.
- [ ] Kullanıcı ilk değer anına hızlı ulaşıyor.
- [ ] Onboarding progress gerekiyorsa gösteriliyor.
- [ ] Onboarding yarıda kesilirse devam edebiliyor.
- [ ] Returning user gereksiz onboarding görmüyor.
Apple'ın kendi onboarding rehberi onboarding gerekiyorsa hızlı, opsiyonel ve mümkün olduğunca interaktif olmasını öneriyor. 

## 16. Formlar
Her form için:
- [ ] Doğru input type.
- [ ] Label var.
- [ ] Placeholder label yerine kullanılmıyor.
- [ ] Required açık.
- [ ] Optional açık.
- [ ] Validation anlaşılır.
- [ ] Validation çok erken rahatsız etmiyor.
- [ ] Submit sonrası validation düzgün.
- [ ] Invalid field'e focus alınabiliyor.
- [ ] Error summary gerekiyorsa var.
- [ ] Autofill çalışıyor.
- [ ] Password manager çalışıyor.
- [ ] Paste engellenmiyor.
- [ ] Copy gerektiği yerde çalışıyor.
- [ ] Mobile keyboard doğru.
- [ ] Enter key mantıklı davranıyor.
- [ ] Numeric input numeric keyboard açıyor.
- [ ] Credit card input uygunsa formatlı.
- [ ] Phone input locale'a uygun.
- [ ] Date input mantıklı.
- [ ] Whitespace normalize ediliyor.
- [ ] Max length server tarafında da uygulanıyor.
- [ ] Client validation server validation yerine geçmiyor.
- [ ] Double-submit engelleniyor.
- [ ] Form submit sırasında durum belli.
- [ ] Server error form verisini silmiyor.
- [ ] Unsaved changes gerekiyorsa korunuyor.

## 17. Loading
- [ ] İlk açılış loading state'i.
- [ ] Route loading.
- [ ] Component loading.
- [ ] Button loading.
- [ ] Background refresh.
- [ ] Pagination loading.
- [ ] Upload progress.
- [ ] Download progress.
- [ ] AI generation progress.
- [ ] Long task progress.
- [ ] Skeleton layout gerçek content ile aynı ölçüde.
- [ ] Spinner sonsuza kadar sebepsiz dönmüyor.
- [ ] Timeout sonrası kullanıcı bilgi alıyor.
- [ ] Cancel mümkün olan operasyon iptal edilebiliyor.
- [ ] Loading sırasında duplicate action yapılamıyor.

## 18. Empty states
Her collection için:
- [ ] İlk defa empty.
- [ ] Search no results.
- [ ] Filter no results.
- [ ] User deleted everything.
- [ ] Permission nedeniyle empty.
- [ ] Network nedeniyle empty değilmiş gibi gösterilmiyor.
- [ ] Empty state neden boş olduğunu açıklıyor.
- [ ] Yapılacak sonraki eylem belli.
- [ ] Gereksiz illustration asıl mesajın önüne geçmiyor.

## 19. Error states
Her external dependency ve network call için:
- [ ] 400.
- [ ] 401.
- [ ] 403.
- [ ] 404.
- [ ] 409.
- [ ] 422.
- [ ] 429.
- [ ] 500.
- [ ] 502.
- [ ] 503.
- [ ] 504.
- [ ] DNS error.
- [ ] Offline.
- [ ] Timeout.
- [ ] Abort.
- [ ] Partial response.
- [ ] Corrupted response.
- [ ] Invalid JSON.
- [ ] API schema mismatch.
- [ ] Dependency outage.
- [ ] Maintenance.
- [ ] User-friendly messaging.
- [ ] Retry güvenliyse retry.
- [ ] Retry güvenli değilse otomatik yapılmıyor.
- [ ] Retry exponential backoff kullanıyor.
- [ ] Retry storm yaratmıyor.

## 20. Offline / kötü bağlantı
Uygulamana uygunsa:
- [ ] Network kaybolunca app çökmez.
- [ ] Kullanıcı connection durumunu anlar.
- [ ] Pending operation belli.
- [ ] Retry var.
- [ ] Duplicate oluşmuyor.
- [ ] Offline cache tutarlı.
- [ ] Reconnection sync düzgün.
- [ ] Conflict resolution tasarlanmış.
- [ ] Optimistic UI geri alınabiliyor.
- [ ] Local state/server state çatışması ele alınıyor.
- [ ] Stale data işaretleniyor gerekiyorsa.

## 21. Authentication
- [ ] Register.
- [ ] Login.
- [ ] Logout.
- [ ] Logout all devices gerekiyorsa.
- [ ] Email verification.
- [ ] Password reset.
- [ ] Password change.
- [ ] Email change.
- [ ] Phone change.
- [ ] MFA.
- [ ] Passkey uygunsa.
- [ ] OAuth.
- [ ] OAuth account linking.
- [ ] OAuth error.
- [ ] OAuth cancel.
- [ ] Expired reset link.
- [ ] Used reset link.
- [ ] Brute force protection.
- [ ] Credential stuffing mitigation.
- [ ] Session rotation.
- [ ] Secure cookies.
- [ ] Session expiry.
- [ ] Remember me davranışı.
- [ ] Revoked user erişemiyor.
- [ ] Disabled account erişemiyor.
- [ ] Deleted account erişemiyor.

## 22. Authorization
Authentication ile karıştırma.
“Kimsin?” ayrı, “ne yapabilirsin?” ayrı.
- [ ] Server-side authorization.
- [ ] Client UI'a güvenilmiyor.
- [ ] Object-level authorization.
- [ ] Route authorization.
- [ ] API authorization.
- [ ] Admin route'ları korunuyor.
- [ ] Role escalation engelleniyor.
- [ ] Tenant isolation test edilmiş.
- [ ] User A, User B'nin ID'sini değiştirerek verisine erişemiyor.
- [ ] Organization membership doğrulanıyor.
- [ ] Removed team member erişemiyor.
- [ ] Permission change anında/uygun sürede uygulanıyor.
- [ ] API token scope'ları minimum.
- [ ] Service account'lar minimum privilege.
Bu alan OWASP ASVS'nin temel doğrulama alanlarından biri ve uygulama güvenliğinin yalnızca login ekranından ibaret olmadığını gösteriyor. 

## 23. Account management
- [ ] Profile edit.
- [ ] Avatar update.
- [ ] Account delete.
- [ ] Account export gerekiyorsa.
- [ ] Password change.
- [ ] Email change verification.
- [ ] Active sessions list.
- [ ] Revoke session.
- [ ] Security settings.
- [ ] Notification preferences.
- [ ] Privacy preferences.
- [ ] Billing settings.
- [ ] Data retention davranışı açık.
- [ ] Deletion backend'de gerçekten uygulanıyor.
- [ ] Subscription olan kullanıcı account silerken uygun flow görüyor.

## 24. Search
- [ ] Search debounce.
- [ ] Empty query.
- [ ] No results.
- [ ] Typo.
- [ ] Case handling.
- [ ] Diacritics.
- [ ] Turkish letters.
- [ ] Unicode.
- [ ] Emoji.
- [ ] Very long query.
- [ ] Malicious input.
- [ ] Search loading.
- [ ] Search pagination.
- [ ] Search ranking.
- [ ] Search result highlighting.
- [ ] Keyboard navigation.
- [ ] Screen reader.
- [ ] Search URL state gerektiğinde korunuyor.

## 25. Filtering / sorting / pagination
- [ ] Filters combine correctly.
- [ ] Clear all.
- [ ] One filter clear.
- [ ] Selected state visible.
- [ ] URL persistence gerekiyorsa var.
- [ ] Refresh persistence.
- [ ] Back button.
- [ ] Pagination stable.
- [ ] Duplicate records yok.
- [ ] Missing records yok.
- [ ] Sort deterministic.
- [ ] Cursor pagination gerekiyorsa kullanılıyor.
- [ ] Large offsets performans sorunu yaratmıyor.
- [ ] Infinite scroll accessibility düşünülmüş.

## 26. Notifications
- [ ] Permission zamanı doğru.
- [ ] Permission rationale.
- [ ] Push opt-out.
- [ ] Email opt-out.
- [ ] Transactional ve marketing ayrılmış.
- [ ] Notification preferences.
- [ ] Duplicate notification yok.
- [ ] Deep link doğru.
- [ ] Expired notification doğru fallback'e gider.
- [ ] Badge count doğru.
- [ ] Timezone doğru.
- [ ] Quiet hours gerekiyorsa.
- [ ] User notification spam olmuyor.
- [ ] Sensitive data lock screen'de gösterilmiyor.
- [ ] Push token rotation yönetiliyor.

## 27. Frontend engineering
- [ ] Type safety.
- [ ] Lint.
- [ ] Formatter.
- [ ] Build reproducible.
- [ ] Dependency versions kontrollü.
- [ ] Dead code temiz.
- [ ] Console error yok.
- [ ] Console warning önemli yerlerde yok.
- [ ] Unhandled promise rejection yok.
- [ ] Memory leak yok.
- [ ] Event listener leak yok.
- [ ] Zombie timer yok.
- [ ] AbortController/cancellation gerektiği yerde.
- [ ] Race condition kontrolü.
- [ ] Component unmount sonrası state update yok.
- [ ] State management anlaşılır.
- [ ] Server state/client state ayrımı doğru.
- [ ] Cache invalidation mantıklı.
- [ ] Sensitive data frontend state'te gereksiz tutulmuyor.
- [ ] Secret client bundle'a konmuyor.
- [ ] Source maps production stratejisi düşünülmüş.
- [ ] Error boundaries var.
- [ ] Feature flags güvenli.
- [ ] Browser compatibility test edilmiş.

## 28. Backend/API
Her endpoint:
- [ ] Authentication.
- [ ] Authorization.
- [ ] Input schema validation.
- [ ] Output schema.
- [ ] Rate limiting.
- [ ] Size limit.
- [ ] Timeout.
- [ ] Request cancellation.
- [ ] Structured error.
- [ ] Correct HTTP status.
- [ ] Logging.
- [ ] Tracing.
- [ ] Correlation/request ID.
- [ ] Pagination.
- [ ] Idempotency gereken yerde.
- [ ] Retry semantics.
- [ ] Concurrency behavior.
- [ ] Transactions.
- [ ] Abuse protection.
- [ ] Versioning strategy.
- [ ] Backward compatibility.
- [ ] Deprecation strategy.
- [ ] API documentation.
- [ ] Schema/contract tests.

## 29. Database
- [ ] Schema tasarımı.
- [ ] Primary keys.
- [ ] Foreign keys.
- [ ] Unique constraints.
- [ ] NOT NULL constraints.
- [ ] Check constraints.
- [ ] Index'ler.
- [ ] Query plan'lar.
- [ ] N+1 query yok.
- [ ] Slow queries ölçülüyor.
- [ ] Transaction boundaries doğru.
- [ ] Isolation level düşünülmüş.
- [ ] Race conditions test edilmiş.
- [ ] Lost update kontrolü.
- [ ] Duplicate insert kontrolü.
- [ ] Optimistic/pessimistic locking gerekiyorsa.
- [ ] Data integrity DB seviyesinde mümkün olduğunca korunuyor.
- [ ] Timestamp standardı.
- [ ] UTC storage stratejisi.
- [ ] Soft delete gerekiyorsa doğru.
- [ ] Hard delete gerekiyorsa doğru.
- [ ] Retention jobs var.
- [ ] Orphan data temizleniyor.
- [ ] Migration sistemi var.
- [ ] Migrations version controlled.
- [ ] Large migration production'da kilit oluşturmuyor.
- [ ] Migration rollback/roll-forward stratejisi var.
- [ ] Backup var.
- [ ] Restore test edildi.
- [ ] Replica lag etkisi düşünülmüş.
- [ ] Failover davranışı biliniyor.

## 30. Cache
- [ ] Cache key doğru.
- [ ] User-specific data başka kullanıcıya sızmıyor.
- [ ] Tenant cache isolation.
- [ ] TTL doğru.
- [ ] Invalidation stratejisi.
- [ ] Stale data kabul kriteri.
- [ ] Cache stampede önleniyor.
- [ ] Cache poisoning düşünülmüş.
- [ ] Cache unavailable olduğunda sistem tamamen çökmüyor.
- [ ] Sensitive responses public cache'e girmiyor.

## 31. File uploads
- [ ] File type allowlist.
- [ ] MIME verification.
- [ ] Extension'a kör güven yok.
- [ ] File size limit.
- [ ] Number of files limit.
- [ ] Filename sanitization.
- [ ] Path traversal engellenmiş.
- [ ] Malware scanning riskine göre.
- [ ] Image decompression bomb düşünülmüş.
- [ ] Metadata/EXIF privacy düşünülmüş.
- [ ] Storage ACL doğru.
- [ ] Signed URL expiration.
- [ ] Unauthorized download engelleniyor.
- [ ] User content separation.
- [ ] Delete file gerçekten siliniyor.
- [ ] Failed upload cleanup.
- [ ] Interrupted upload.
- [ ] Resume gerekiyorsa.
- [ ] Thumbnail generation failure.
- [ ] Unsupported media UI.

## 32. Klasik application security
OWASP ASVS 5.0.0 ve NIST SSDF'yi minimum referanslardan biri olarak alırdım. NIST'in amacı security'yi development lifecycle'ın içine yerleştirmek; sonradan pentest ekleyerek güvenli ürün oluşturmak değil. 
Kontroller:
- [ ] Threat model oluşturuldu.
- [ ] Attack surface çıkarıldı.
- [ ] Trust boundaries çıkarıldı.
- [ ] Least privilege.
- [ ] Defense in depth.
- [ ] Authentication controls.
- [ ] Authorization controls.
- [ ] Tenant isolation.
- [ ] SQL injection.
- [ ] Command injection.
- [ ] XSS.
- [ ] CSRF.
- [ ] SSRF.
- [ ] XXE uygunsa.
- [ ] Path traversal.
- [ ] Open redirect.
- [ ] Host header attacks.
- [ ] CORS.
- [ ] CSP.
- [ ] Clickjacking.
- [ ] Secure headers.
- [ ] TLS.
- [ ] HSTS uygunsa.
- [ ] Cookie flags.
- [ ] Session fixation.
- [ ] Brute force.
- [ ] Rate limiting.
- [ ] Enumeration.
- [ ] Account takeover.
- [ ] Password reset abuse.
- [ ] File upload abuse.
- [ ] Deserialization risk.
- [ ] Prototype pollution uygunsa.
- [ ] ReDoS.
- [ ] Mass assignment.
- [ ] Business logic abuse.
- [ ] Race-condition abuse.
- [ ] Secrets scanning.
- [ ] Dependency vulnerability scanning.
- [ ] SAST.
- [ ] DAST uygun projelerde.
- [ ] SBOM stratejisi.
- [ ] Container scan.
- [ ] Infrastructure misconfiguration scan.
- [ ] Secret rotation.
- [ ] Security logging.
- [ ] Audit logging.
- [ ] Incident response.
- [ ] Responsible vulnerability disclosure kanalı.

## 33. Secrets
- [ ] API key repository'de yok.
- [ ] .env commit edilmemiş.
- [ ] Production secrets dev'den farklı.
- [ ] Secrets secret manager'da.
- [ ] Rotation mümkün.
- [ ] Expiration olan secret'lar takip ediliyor.
- [ ] Minimum permissions.
- [ ] Secret logs'a düşmüyor.
- [ ] Secret analytics'e gitmiyor.
- [ ] Secret frontend'e gitmiyor.
- [ ] Old secret revoke ediliyor.
- [ ] Employee offboarding ile credentials revoke ediliyor.

## 34. Privacy
AB kullanıcıları söz konusuysa privacy yalnızca privacy policy sayfası değildir. GDPR rehberlerinde purpose limitation, data minimisation, storage limitation ve privacy-by-design/default açık gereklilikler olarak yer alıyor. 
- [ ] Hangi veriyi topladığın belli.
- [ ] Neden topladığın belli.
- [ ] Her veri alanı gerçekten gerekli.
- [ ] Gereksiz veri toplanmıyor.
- [ ] Data inventory var.
- [ ] Data classification var.
- [ ] PII tanımlı.
- [ ] Sensitive data tanımlı.
- [ ] Encryption in transit.
- [ ] Encryption at rest riskine göre.
- [ ] Retention policy.
- [ ] Deletion policy.
- [ ] Access policy.
- [ ] Employee access minimum.
- [ ] Audit trail.
- [ ] Privacy policy gerçek davranışla eşleşiyor.
- [ ] Third-party processors kayıtlı.
- [ ] Analytics SDK'ları kontrol edilmiş.
- [ ] AI provider'a hangi verilerin gittiği biliniyor.
- [ ] Logs'ta hassas veri maskeleniyor.
- [ ] Error reports'ta hassas veri maskeleniyor.
- [ ] Data export uygulanabiliyorsa düzgün.
- [ ] Account deletion uygulanabiliyorsa düzgün.
- [ ] Consent gerekiyorsa gerçekten meaningful.
- [ ] Consent withdrawal mümkün.
- [ ] Cookie/SDK consent bölgesel gerekliliklere uygun.
- [ ] Default settings privacy-friendly.
- [ ] Children's data varsa ayrı değerlendirme.
AB rehberleri ayrıca kullanıcıya verinin neden işlendiği, ne kadar saklanacağı, kimlere verileceği ve çeşitli haklarının açıkça anlatılmasını istiyor. 

## 35. AI özelliği varsa — AI Product Behavior
Buradan itibaren normal SaaS checklist'i yetmez.
- [ ] AI'nın işi tek cümlede tanımlı.
- [ ] Yapmaması gerekenler tanımlı.
- [ ] Başarılı output tanımlı.
- [ ] Kabul edilemez output tanımlı.
- [ ] Golden dataset var.
- [ ] Real-world examples var.
- [ ] Edge cases var.
- [ ] Rare-but-catastrophic cases var.
- [ ] Expected outputs/rubric var.
- [ ] Model değişince eval çalışıyor.
- [ ] Prompt değişince eval çalışıyor.
- [ ] Tool değişince eval çalışıyor.
- [ ] Retrieval değişince eval çalışıyor.
- [ ] Regression threshold var.
- [ ] Launch threshold var.
- [ ] Human review sampling var.
- [ ] Production logs'dan yeni eval case üretiliyor.
- [ ] Kullanıcı feedback'i eval sistemine besleniyor.
- [ ] Model hallucination davranışı ölçülüyor.
- [ ] Abstention davranışı ölçülüyor.
- [ ] Uncertainty doğru ifade ediliyor.
- [ ] Citation doğruluğu ölçülüyor.
- [ ] Structured output validity ölçülüyor.
- [ ] Tool selection accuracy ölçülüyor.
- [ ] Tool argument accuracy ölçülüyor.
- [ ] Multi-turn consistency test ediliyor.
- [ ] Language behavior test ediliyor.
- [ ] Safety behavior test ediliyor.
- [ ] Latency ölçülüyor.
- [ ] Token kullanımı ölçülüyor.
- [ ] Cost/request ölçülüyor.
- [ ] Model/provider failure fallback'i var.
OpenAI'nin güncel eval yaklaşımı bunu Specify → Measure → Improve şeklinde tanımlıyor: önce “iyi”nin ne olduğunu somutlaştır, gerçek koşullarda ölç, hataları kategorize edip eval setini sürekli büyüt. Ayrıca launch sonrasında da gerçek production çıktılarının ölçülmesini öneriyor. 

## 36. AI UX
- [ ] AI yaptığı şey konusunda yanlış kesinlik vermiyor.
- [ ] Processing durumu belli.
- [ ] Long generation cancel edilebiliyor.
- [ ] Retry/regenerate anlamlı.
- [ ] Edit prompt kolay.
- [ ] Input geçmişi gerekiyorsa kullanılabilir.
- [ ] User AI'nın hangi veriyi kullandığını anlayabiliyor.
- [ ] Source/citation gerekiyorsa gösteriliyor.
- [ ] Citation gerçekten kaynakla eşleşiyor.
- [ ] AI yanlışsa kullanıcı düzeltebiliyor.
- [ ] AI'nın değişiklik yapacağı şey önizleniyor.
- [ ] Destructive AI action confirmation gerektiriyor.
- [ ] AI'nın yaptığı işlemler audit edilebiliyor.
- [ ] Uzun işlem progress veriyor.
- [ ] Partial streaming düzgün.
- [ ] Stream yarıda kesilirse UI bozulmuyor.
- [ ] Model error kullanıcıya internal teknik detay göstermiyor.
- [ ] Conversation deletion düzgün.
- [ ] Attachment handling güvenli.
- [ ] Context window taşması yönetiliyor.
- [ ] Kullanıcı eski context'in kullanıldığını yanlış varsaymıyor.

## 37. AI security
2026 itibarıyla AI sistemleri için OWASP AISVS 1.0 artık doğrulanabilir gereksinimler sunuyor; OWASP LLM Top 10 da prompt injection, sensitive information disclosure, supply chain, poisoning, improper output handling, excessive agency, system prompt leakage, vector/embedding weakness, misinformation ve unbounded consumption gibi riskleri ayrı sınıflar olarak ele alıyor. 
Kontrol et:
- [ ] Direct prompt injection.
- [ ] Indirect prompt injection.
- [ ] Jailbreak.
- [ ] System prompt leakage.
- [ ] Sensitive information disclosure.
- [ ] Cross-user context leak.
- [ ] Cross-tenant RAG leak.
- [ ] Training/RAG poisoning.
- [ ] Malicious documents.
- [ ] Malicious web pages.
- [ ] Malicious email content.
- [ ] Tool output injection.
- [ ] Agent-to-agent injection.
- [ ] Improper output handling.
- [ ] AI output HTML olarak güvenilmeden render edilmiyor.
- [ ] AI output SQL olarak direkt çalıştırılmıyor.
- [ ] AI output shell command olarak direkt çalıştırılmıyor.
- [ ] AI output file path olarak sanitization olmadan kullanılmıyor.
- [ ] Model authorization kararı vermiyor.
- [ ] Server authorization ayrıca uygulanıyor.
- [ ] Tool permissions minimum.
- [ ] Tool list minimum.
- [ ] Open-ended shell/browser tool gerekmiyorsa verilmemiş.
- [ ] Read-only ihtiyaca write permission verilmemiş.
- [ ] User context downstream sistemlerde korunuyor.
- [ ] High-impact actions human approval gerektiriyor.
- [ ] Delete/send/pay/publish gibi işlemler açık confirmation gerektiriyor.
- [ ] Rate limits.
- [ ] Token limits.
- [ ] Cost limits.
- [ ] Loop limits.
- [ ] Max tool calls.
- [ ] Max execution time.
- [ ] Sandboxing.
- [ ] External URL restrictions.
- [ ] Network egress restrictions uygunsa.
- [ ] Tool activity logging.
- [ ] Suspicious behavior detection.
- [ ] AI incident kill switch.
OWASP özellikle excessive agency için minimum tool functionality + minimum permissions + minimum autonomy + high-impact işlemde human approval yaklaşımını öneriyor. 

## 38. RAG kullanıyorsan
- [ ] Document ownership.
- [ ] Tenant isolation.
- [ ] Retrieval authorization.
- [ ] Query-time ACL enforcement.
- [ ] Deleted docs index'ten çıkıyor.
- [ ] Updated docs re-index ediliyor.
- [ ] Embedding metadata doğru.
- [ ] Chunking test edilmiş.
- [ ] Retrieval recall eval'i.
- [ ] Retrieval precision eval'i.
- [ ] Groundedness eval'i.
- [ ] Citation mapping.
- [ ] Citation source user tarafından erişilebilir mi?
- [ ] Stale data handling.
- [ ] Poisoned document handling.
- [ ] Malicious instructions document'ta data olarak muamele görüyor.
- [ ] Private documents global retrieval'e düşmüyor.
- [ ] Vector DB backup/restore.
- [ ] Embedding model migration stratejisi.

## 39. AI agent kullanıyorsan
Her agent için:
- [ ] Amaç.
- [ ] Allowed actions.
- [ ] Forbidden actions.
- [ ] Tool allowlist.
- [ ] Tool argument schema.
- [ ] Permission scope.
- [ ] Max steps.
- [ ] Max runtime.
- [ ] Max cost.
- [ ] Exit condition.
- [ ] Loop detection.
- [ ] Tool timeout.
- [ ] Tool retry policy.
- [ ] Tool failure recovery.
- [ ] State isolation.
- [ ] User isolation.
- [ ] Audit trail.
- [ ] Approval boundary.
- [ ] Destructive action confirmation.
- [ ] External content treated as untrusted.
- [ ] Sandbox.
- [ ] Kill switch.
NIST'in Generative AI risk profili de risk yönetimini yalnızca model seviyesinde değil, AI ürününün tüm yaşam döngüsüne yayılması gereken bir süreç olarak ele alıyor. 

## 40. Web performance
Web uygulamasında production hedefleri:
- [ ] LCP ölçülüyor.
- [ ] INP ölçülüyor.
- [ ] CLS ölçülüyor.
- [ ] Real User Monitoring var.
Google'ın güncel “good” Core Web Vitals eşikleri:
LCP ≤ 2.5s INP ≤ 200ms CLS ≤ 0.1
ve değerlendirme kullanıcıların 75. yüzdelik dilimi üzerinden yapılmalı. 
Ayrıca:
- [ ] TTFB izleniyor.
- [ ] JS bundle size kontrollü.
- [ ] Code splitting.
- [ ] Lazy loading.
- [ ] Images optimized.
- [ ] Correct image dimensions.
- [ ] Responsive images.
- [ ] Modern image formats.
- [ ] Fonts optimized.
- [ ] CDN.
- [ ] Compression.
- [ ] HTTP caching.
- [ ] API caching.
- [ ] Critical rendering path.
- [ ] Third-party scripts denetlenmiş.
- [ ] Analytics UI thread'i öldürmüyor.
- [ ] Huge hydration cost yok.
- [ ] Long tasks azaltılmış.
- [ ] Memory consumption ölçülüyor.
- [ ] Slow device test.
- [ ] Slow CPU test.
- [ ] Slow 3G/4G test.
- [ ] Cold cache test.
- [ ] Warm cache test.

## 41. Native/mobile performance
- [ ] Cold startup.
- [ ] Warm startup.
- [ ] Resume.
- [ ] Memory.
- [ ] Battery.
- [ ] CPU.
- [ ] GPU.
- [ ] Network.
- [ ] Frame drops.
- [ ] Scroll jank.
- [ ] Image memory.
- [ ] Background activity.
- [ ] App switcher.
- [ ] Rotation.
- [ ] Background → foreground.
- [ ] Low-memory recovery.
- [ ] Phone call interruption.
- [ ] Notification interruption.
- [ ] Permission changes while backgrounded.
- [ ] Network change Wi-Fi → cellular.
- [ ] Battery saver.
- [ ] Device thermal throttling.
Android'ın güncel quality guide'ı startup'ın hızlı olması veya 2 saniyeyi aşacaksa feedback verilmesini ve akıcı rendering için 60 FPS seviyesinde yaklaşık 16 ms frame budget'ını açık kalite kriterleri arasında sayıyor. 

## 42. Scalability
- [ ] Normal load test.
- [ ] Peak load test.
- [ ] Spike test.
- [ ] Stress test.
- [ ] Soak test.
- [ ] Concurrent users.
- [ ] Concurrent writes.
- [ ] Hot key.
- [ ] Large tenant.
- [ ] Large account.
- [ ] Huge file.
- [ ] Huge collection.
- [ ] High notification volume.
- [ ] Queue backlog.
- [ ] DB saturation.
- [ ] Connection pool exhaustion.
- [ ] CPU saturation.
- [ ] Memory saturation.
- [ ] Disk saturation.
- [ ] Rate-limit behavior.
- [ ] Autoscaling.
- [ ] Autoscaling delay.
- [ ] Scale-down behavior.
- [ ] Dependency quotas.
- [ ] Cloud quotas.
- [ ] Launch traffic spike.
Google'ın launch rehberi ürün lansmanlarında normal trafik tahmininin çok üzerine çıkılabileceğini ve capacity planning'in launch checklist'in temel bölümü olması gerektiğini özellikle anlatıyor. 

## 43. Reliability
Her dependency için sor:
“Bu tamamen giderse ne olur?”
- [ ] App server dies.
- [ ] Container dies.
- [ ] VM dies.
- [ ] Availability zone dies.
- [ ] Region dies gerekiyorsa.
- [ ] Database unavailable.
- [ ] Read replica unavailable.
- [ ] Cache unavailable.
- [ ] Queue unavailable.
- [ ] Object storage unavailable.
- [ ] DNS problem.
- [ ] CDN problem.
- [ ] Authentication provider down.
- [ ] Payment provider down.
- [ ] Email provider down.
- [ ] SMS provider down.
- [ ] AI provider down.
- [ ] Search provider down.
- [ ] Third-party API timeout.
- [ ] Third-party API returns malformed data.
- [ ] Dependency becomes slow.
- [ ] Partial dependency failure.
- [ ] Circuit breaker gerekiyorsa.
- [ ] Deadline/timeout.
- [ ] Retry.
- [ ] Exponential backoff.
- [ ] Jitter.
- [ ] Load shedding.
- [ ] Graceful degradation.
- [ ] Fallback.
- [ ] Single points of failure çıkarılmış.
Google launch checklist'i aynı şekilde machine, rack/cluster, network ve backend failure gibi senaryoların launch öncesi açıkça cevaplanmasını istiyor. AWS Well-Architected Reliability Pillar da proven failure recovery, resilient architecture ve consistent change management'i temel reliability alanları sayıyor. 

## 44. Observability
Production sistem gözlemlenemiyorsa production ready değildir.
Logs
- [ ] Structured.
- [ ] Timestamp.
- [ ] Request ID.
- [ ] Trace ID.
- [ ] User ID uygun şekilde/pseudonymous.
- [ ] Tenant ID.
- [ ] Service.
- [ ] Version.
- [ ] Environment.
- [ ] Error type.
- [ ] Stack trace.
- [ ] Sensitive fields redacted.
- [ ] Log levels doğru.
- [ ] Searchable.
- [ ] Retention belirlenmiş.
Metrics
- [ ] Request rate.
- [ ] Error rate.
- [ ] Latency.
- [ ] CPU.
- [ ] Memory.
- [ ] Disk.
- [ ] Network.
- [ ] DB connections.
- [ ] Queue depth.
- [ ] Cache hit rate.
- [ ] External dependency latency.
- [ ] External dependency errors.
- [ ] Auth failures.
- [ ] Payment failures.
- [ ] AI latency.
- [ ] AI errors.
- [ ] AI tokens.
- [ ] AI cost.
- [ ] Business KPI.
Traces
- [ ] Distributed tracing.
- [ ] Frontend → API trace.
- [ ] API → DB.
- [ ] API → third party.
- [ ] AI tool chains.
AWS Operational Excellence bunu application telemetry, UX telemetry, dependency telemetry ve distributed tracing olarak açıkça ayırıyor. 

## 45. SLO / alerting
Her kritik journey için:
- [ ] SLI tanımlı.
- [ ] SLO tanımlı.
- [ ] Availability objective.
- [ ] Latency objective.
- [ ] Correctness objective gerekiyorsa.
- [ ] Error budget.
- [ ] Alert threshold.
- [ ] Alert owner.
- [ ] Alert runbook.
- [ ] Alert gerçekten actionable.
- [ ] Warning ile critical ayrılmış.
- [ ] Pager yalnızca gerçekten acil olaylarda.
- [ ] Synthetic monitors.
- [ ] External uptime monitor.
- [ ] Status page gerekiyorsa.
Google SRE temelleri SLO, monitoring ve alerting'i production reliability'nin temel yapı taşları olarak ele alıyor. 

## 46. Automated testing
Unit
- [ ] Critical business logic.
- [ ] Utility functions.
- [ ] Validation.
- [ ] Permission logic.
- [ ] Data transforms.
- [ ] Edge cases.
Integration
- [ ] DB.
- [ ] Cache.
- [ ] Queue.
- [ ] External services mock/test environment.
- [ ] Authentication.
- [ ] Storage.
- [ ] Payment.
Contract
- [ ] API schema.
- [ ] Frontend/backend compatibility.
- [ ] Service-to-service compatibility.
E2E
- [ ] Signup.
- [ ] Login.
- [ ] Password reset.
- [ ] Core product journey.
- [ ] Create.
- [ ] Edit.
- [ ] Delete.
- [ ] Search.
- [ ] Payment.
- [ ] Logout.
- [ ] Account delete.
Diğer
- [ ] Visual regression.
- [ ] Accessibility automation.
- [ ] Manual accessibility.
- [ ] Performance regression.
- [ ] Security tests.
- [ ] Load tests.
- [ ] Failure injection.
- [ ] Migration tests.
- [ ] Backup restore tests.
- [ ] AI eval regression tests.

## 47. Manual QA
Robotların yakalamadığı şeyleri yakalar.
Her release:
- [ ] Fresh user.
- [ ] Existing user.
- [ ] Power user.
- [ ] Admin.
- [ ] Free user.
- [ ] Paid user.
- [ ] Expired subscriber.
- [ ] Suspended user.
- [ ] Deleted user.
- [ ] Empty account.
- [ ] Account with thousands of objects.
- [ ] Mobile.
- [ ] Tablet.
- [ ] Desktop.
- [ ] Light.
- [ ] Dark.
- [ ] Keyboard.
- [ ] Screen reader.
- [ ] Slow network.
- [ ] Offline.
- [ ] Permission denied.
- [ ] Browser refresh.
- [ ] Multiple tabs.
- [ ] Session expiry.
- [ ] App background/foreground.
- [ ] Weird/long text.
- [ ] Emoji.
- [ ] RTL.
- [ ] Localization.

## 48. CI pipeline
Her pull request'te mümkün olduğunca:
format → lint → typecheck → unit → integration → security → build → E2E → artifact
Kontroller:
- [ ] Build fail → merge yok.
- [ ] Tests fail → merge yok.
- [ ] Type error → merge yok.
- [ ] Security critical → merge yok.
- [ ] AI eval regression → ilgili projede merge/deploy yok.
- [ ] Branch protection.
- [ ] Required review.
- [ ] CODEOWNERS gerekiyorsa.
- [ ] Dependency updates otomatik/takipli.
- [ ] Build artifact immutable.
- [ ] Build provenance/attestation ihtiyaca göre.
- [ ] CI secrets güvenli.
NIST SSDF tam olarak güvenli geliştirme uygulamalarını SDLC'nin içine yerleştirmeyi amaçlıyor. 

## 49. Environment sistemi
- [ ] Local.
- [ ] Development.
- [ ] Preview.
- [ ] Staging.
- [ ] Production.
Ve:
- [ ] Production data development'a körlemesine kopyalanmıyor.
- [ ] Environment secrets ayrı.
- [ ] Environment APIs ayrı.
- [ ] Payment test/live ayrı.
- [ ] AI prod/dev credentials ayrı.
- [ ] Production flag açıkça belli.
- [ ] Staging production'a mümkün olduğunca benziyor.
- [ ] Environment config version controlled.
- [ ] Configuration drift kontrol ediliyor.
AWS Operational Excellence de multiple environments, configuration management, version control ve test/validation'ı preparation best practice'leri arasında sayıyor. 

## 50. Deployment
- [ ] Automated.
- [ ] Reproducible.
- [ ] Auditable.
- [ ] Versioned.
- [ ] Deployment sahibi belli.
- [ ] Release notes.
- [ ] Database migration ordering.
- [ ] Backward-compatible migration.
- [ ] Health checks.
- [ ] Readiness check.
- [ ] Smoke test.
- [ ] Feature flag.
- [ ] Kill switch.
- [ ] Rollback.
- [ ] Rollback gerçekten test edilmiş.
- [ ] Previous known-good artifact saklanıyor.
- [ ] Canary.
- [ ] Gradual rollout.
- [ ] Metrics otomatik izleniyor.
- [ ] Error threshold aşılırsa rollout duruyor.
Google'ın canary modeli değişikliği production trafiğinin küçük bir kısmında sınayıp, sonuçlara göre rollout'a devam etmeyi öngörüyor; bunun amacı test ortamında ortaya çıkmayan sorunların blast radius'unu küçültmek. 

## 51. Database deployment
- [ ] Schema değişikliği eski app version ile uyumlu.
- [ ] Expand/contract pattern gerektiğinde.
- [ ] Column rename doğrudan destructive yapılmıyor.
- [ ] Data migration ölçülmüş.
- [ ] Long-running lock kontrol edilmiş.
- [ ] Migration disk kullanımını patlatmıyor.
- [ ] Index creation davranışı biliniyor.
- [ ] Rollback veri kaybı yaratmıyor.
- [ ] Roll-forward planı var.
- [ ] Migration telemetry var.

## 52. Backup
- [ ] Database backup.
- [ ] Object storage backup gerekiyorsa.
- [ ] Configuration backup.
- [ ] Encryption.
- [ ] Retention.
- [ ] Geographic strategy risk seviyesine göre.
- [ ] Backup erişim kontrolü.
- [ ] Backup monitoring.
- [ ] Backup failure alert.
- [ ] Restore procedure yazılı.
- [ ] Restore otomasyonu.
- [ ] Restore test edildi.
- [ ] Restored application gerçekten açıldı.
- [ ] RPO tanımlı.
- [ ] RTO tanımlı.
Backup'ın var olduğunu görmek yeterli değildir; restore testi asıl kontrol olmalıdır. AWS reliability çerçevesi de proven failure recovery üzerine kuruludur. 

## 53. Disaster Recovery
- [ ] DB completely lost scenario.
- [ ] Region failure.
- [ ] Cloud credentials compromised.
- [ ] Data corruption.
- [ ] Accidental mass deletion.
- [ ] Ransomware/hostile deletion riskine göre.
- [ ] DNS failure.
- [ ] Third-party outage.
- [ ] Restore runbook.
- [ ] Failover runbook.
- [ ] Communication plan.
- [ ] Status page.
- [ ] Incident roles.
- [ ] DR drill/game day yapılıyor.

## 54. Payments varsa
- [ ] Pricing doğru.
- [ ] Currency doğru.
- [ ] Tax doğru sistemi kullanıyor.
- [ ] Checkout success.
- [ ] Checkout cancel.
- [ ] Payment failed.
- [ ] Payment requires authentication.
- [ ] Duplicate submit.
- [ ] Idempotency.
- [ ] Webhook verification.
- [ ] Duplicate webhook.
- [ ] Out-of-order webhook.
- [ ] Delayed webhook.
- [ ] Missing webhook reconciliation.
- [ ] Refund.
- [ ] Partial refund.
- [ ] Chargeback.
- [ ] Subscription create.
- [ ] Upgrade.
- [ ] Downgrade.
- [ ] Cancel.
- [ ] Pause uygunsa.
- [ ] Trial.
- [ ] Trial expire.
- [ ] Payment retry.
- [ ] Card expiry.
- [ ] Billing portal.
- [ ] Invoice.
- [ ] Entitlement server-side.
- [ ] “Paid” state yalnızca frontend redirect'e güvenmiyor.
- [ ] Payment provider down.
- [ ] Financial events audit log.

## 55. Subscription UX
- [ ] Free özellikleri belli.
- [ ] Paid özellikleri belli.
- [ ] Fiyat açık.
- [ ] Billing period açık.
- [ ] Auto-renewal açık.
- [ ] Trial ending açık.
- [ ] Cancel yolu bulunabilir.
- [ ] Cancel sonrası ne olacağı açık.
- [ ] Upgrade farkı açık.
- [ ] Downgrade timing açık.
- [ ] Restore purchase mobile'da gerektiğinde.
- [ ] Subscription state cihazlar arasında tutarlı.

## 56. Analytics
Ölçmediğin şeyi düzeltemezsin.
- [ ] Activation.
- [ ] Conversion.
- [ ] Retention.
- [ ] Churn.
- [ ] Core action completion.
- [ ] Funnel.
- [ ] Search success.
- [ ] Payment success.
- [ ] Error rate.
- [ ] Feature usage.
- [ ] Time-to-value.
- [ ] AI acceptance/regeneration varsa.
- [ ] Analytics event naming standard.
- [ ] Event schema.
- [ ] Duplicate events yok.
- [ ] Sensitive data analytics'e gitmiyor.
- [ ] Bot/internal traffic ayrıştırılıyor.
- [ ] Analytics production'da doğrulanmış.
- [ ] Dashboard var.
- [ ] KPI owner var.

## 57. Experiment / A/B testing
- [ ] Hypothesis.
- [ ] Primary metric.
- [ ] Guardrail metric.
- [ ] Sample allocation.
- [ ] Stable assignment.
- [ ] Exposure logging.
- [ ] Experiment contamination kontrolü.
- [ ] Feature flag cleanup.
- [ ] Negative side effect kontrolü.
- [ ] AI eval ile A/B test birbirine karıştırılmıyor.
OpenAI de AI eval'lerinin kullanıcı üzerindeki gerçek ürün deneyimini ölçen A/B testlerin yerine geçmediğini; bunların birbirini tamamladığını vurguluyor. 

## 58. SEO — public web ürünüyse
- [ ] Unique title.
- [ ] Meta description.
- [ ] Canonical.
- [ ] Robots.
- [ ] Sitemap.
- [ ] Correct status codes.
- [ ] SSR/SSG gerekiyorsa.
- [ ] Crawlable links.
- [ ] Structured data uygunsa.
- [ ] OpenGraph.
- [ ] Social image.
- [ ] Mobile friendly.
- [ ] Core Web Vitals.
- [ ] Duplicate pages.
- [ ] 404.
- [ ] Redirects.
- [ ] International hreflang gerekiyorsa.
- [ ] Auth/private pages indexlenmiyor.

## 59. Mobile platform-specific
iOS
- [ ] Safe area.
- [ ] Dynamic Type.
- [ ] VoiceOver.
- [ ] Reduce Motion.
- [ ] Dark Mode.
- [ ] App background/foreground.
- [ ] Permission strings.
- [ ] Deep links.
- [ ] Universal Links gerekiyorsa.
- [ ] App icon.
- [ ] Launch screen.
- [ ] Push.
- [ ] App Store metadata.
- [ ] Privacy disclosures.
- [ ] In-app purchase compliance.
- [ ] TestFlight.
- [ ] Crash-free real-device testing.
Apple'ın 8 Haziran 2026 güncellenen App Review Guidelines'ı submission'da crash/bug testi, doğru metadata, çalışan backend, review account/demo mode, tamamlanmış IAP ve final içerik bekliyor. 
Android
- [ ] Multiple screen sizes.
- [ ] Back behavior.
- [ ] Predictive Back uygunsa.
- [ ] Rotation/config changes.
- [ ] Foldables.
- [ ] Large screens.
- [ ] Accessibility.
- [ ] Notification permission.
- [ ] Deep/App Links.
- [ ] Battery usage.
- [ ] Background work rules.
- [ ] Play policy.
- [ ] Real device test.
Android'ın 2026 core quality checklist'i ekranlar, app switcher, interruptions, network/battery/GPS değişiklikleri ve IAP dahil tüm önemli user flow'ların test edilmesini istiyor. 

## 60. UGC / sosyal özellik varsa
- [ ] Report.
- [ ] Block.
- [ ] Mute.
- [ ] Content moderation.
- [ ] Spam prevention.
- [ ] Abuse detection.
- [ ] Rate limiting.
- [ ] Impersonation process.
- [ ] Harassment handling.
- [ ] Appeal/report workflow.
- [ ] Copyright/takedown process riskine göre.
- [ ] Deleted content handling.
- [ ] Deleted user content policy.
- [ ] Privacy settings.
- [ ] Public/private visibility.
- [ ] Search visibility.
- [ ] Admin moderation tools.
- [ ] Moderator audit logs.
Apple'ın App Store kuralları UGC uygulamalarında objectionable material filtering, report mekanizması, abusive user blocking ve ulaşılabilir contact information istiyor. 

## 61. Email
- [ ] Verification emails.
- [ ] Password reset.
- [ ] Security alerts.
- [ ] Billing.
- [ ] Subscription.
- [ ] Notification.
- [ ] Correct sender.
- [ ] Reply-to.
- [ ] Plain-text fallback.
- [ ] Mobile rendering.
- [ ] Dark Mode email.
- [ ] Broken links.
- [ ] Expired links.
- [ ] Unsubscribe gerekiyorsa.
- [ ] Duplicate send.
- [ ] Bounce handling.
- [ ] Delivery monitoring.
- [ ] No sensitive data unnecessarily.

## 62. Legal / compliance
Bu bölüm ülkeye ve ürüne göre hukuk danışmanıyla doğrulanmalı.
- [ ] Terms of Service.
- [ ] Privacy Policy.
- [ ] Cookie/consent requirements.
- [ ] Data processors.
- [ ] Data retention.
- [ ] Data deletion.
- [ ] Intellectual property.
- [ ] Third-party content licenses.
- [ ] Font licenses.
- [ ] Image licenses.
- [ ] Open-source licenses.
- [ ] AI model/provider terms.
- [ ] User generated content terms.
- [ ] Refund terms.
- [ ] Subscription terms.
- [ ] Age restrictions.
- [ ] Children's privacy gerekiyorsa.
- [ ] Regional compliance.
- [ ] App Store rules.
- [ ] Google Play rules.
- [ ] Marketing claims gerçeği yansıtıyor.
- [ ] “AI” iddiaları yanıltıcı değil.

## 63. Infrastructure / cloud
AWS'nin Well-Architected Framework'ü bunu altı eksende değerlendiriyor: Operational Excellence, Security, Reliability, Performance Efficiency, Cost Optimization ve Sustainability.
Kontroller:
- [ ] Infrastructure as Code.
- [ ] Version controlled.
- [ ] Network segmentation.
- [ ] IAM least privilege.
- [ ] Production access minimum.
- [ ] MFA admin.
- [ ] Audit logs.
- [ ] Encryption.
- [ ] Secret management.
- [ ] Autoscaling.
- [ ] Health checks.
- [ ] Load balancing.
- [ ] DNS.
- [ ] CDN.
- [ ] WAF riskine göre.
- [ ] DDoS protection.
- [ ] Quotas monitored.
- [ ] Capacity headroom.
- [ ] Resource tagging.
- [ ] Cost allocation.
- [ ] Environment isolation.
- [ ] Backup.
- [ ] DR.
- [ ] Patch process.
- [ ] Vulnerability management.

## 64. Cost / FinOps
AI projelerinde özellikle unutuluyor.
- [ ] Cost per active user.
- [ ] Cost per request.
- [ ] DB cost.
- [ ] Storage cost.
- [ ] Egress cost.
- [ ] CDN cost.
- [ ] Logging cost.
- [ ] Monitoring cost.
- [ ] Email/SMS cost.
- [ ] AI token cost.
- [ ] AI tool cost.
- [ ] Embedding cost.
- [ ] Vector DB cost.
- [ ] Image/video generation cost.
- [ ] Abuse cost exposure.
- [ ] Per-user quota.
- [ ] Per-org quota.
- [ ] Budget alert.
- [ ] Anomaly detection.
- [ ] Runaway agent protection.
- [ ] Unlimited endpoints kontrol edilmiş.
- [ ] Unused resource cleanup.
AWS de cost optimization'ı sistemin tüm yaşam döngüsü boyunca sürekli refinement gerektiren ayrı bir architecture pillar olarak ele alıyor. 

## 65. Support
- [ ] Contact mechanism.
- [ ] Help center.
- [ ] FAQ gerekiyorsa.
- [ ] Support ticket.
- [ ] Ticket ownership.
- [ ] Severity levels.
- [ ] Response expectations.
- [ ] Admin tooling.
- [ ] User lookup.
- [ ] Account diagnostics.
- [ ] Audit trail.
- [ ] Impersonation/support access kontrollü.
- [ ] Sensitive data maskeli.
- [ ] Refund tooling gerekiyorsa.
- [ ] Abuse escalation.
- [ ] Security escalation.
- [ ] Data deletion request handling.

## 66. Internal admin panel
Bazen uygulamanın kendisinden daha tehlikelidir.
- [ ] Admin auth.
- [ ] MFA.
- [ ] Role separation.
- [ ] Least privilege.
- [ ] Audit log.
- [ ] Sensitive fields masked.
- [ ] Dangerous action confirmation.
- [ ] Bulk operation confirmation.
- [ ] User impersonation audited.
- [ ] Impersonation banner.
- [ ] Cannot impersonate higher privilege.
- [ ] Export permissions.
- [ ] Search rate limits.
- [ ] Admin API private/protected.
- [ ] Production admin action traceable.
- [ ] Emergency access/break-glass documented.

## 67. Incident response
Bir gece sistem çökerse:
- [ ] Kim alarm alıyor?
- [ ] Kim Incident Commander?
- [ ] Kim teknik müdahaleyi yapıyor?
- [ ] Kim kullanıcı iletişimini yapıyor?
- [ ] Severity nasıl belirleniyor?
- [ ] Rollback nasıl?
- [ ] Feature nasıl disable edilir?
- [ ] AI nasıl disable edilir?
- [ ] Payment nasıl disable edilir?
- [ ] Status page nasıl güncellenir?
- [ ] Database restore nasıl?
- [ ] Credentials nasıl rotate edilir?
- [ ] Security breach procedure ne?
- [ ] Evidence nasıl korunur?
- [ ] Postmortem nasıl yazılır?
- [ ] Action item owner nasıl atanır?
Google SRE postmortem yaklaşımı incident impact, root cause analysis ve somut action item'ların formal biçimde ele alınmasını öneriyor. 

## 68. Documentation
Developer
- [ ] README.
- [ ] Setup.
- [ ] Architecture.
- [ ] Environment.
- [ ] Secrets.
- [ ] Database.
- [ ] Migrations.
- [ ] APIs.
- [ ] Testing.
- [ ] Deployment.
- [ ] Rollback.
- [ ] Monitoring.
- [ ] Runbooks.
Product
- [ ] Feature behavior.
- [ ] Permissions.
- [ ] Roles.
- [ ] Edge cases.
- [ ] Billing.
- [ ] AI behavior.
- [ ] Known limitations.
Bir kritik süreci yalnızca bir kişinin kafasında biliyor olması single point of failure demektir. Google'ın launch rehberi de manual operational process'lerin launch öncesi belgelenmesini özellikle ister. 

## 69. Browser/device matrix
Web'de en az:
- [ ] Latest Chrome.
- [ ] Latest Safari.
- [ ] Latest Firefox.
- [ ] Latest Edge.
- [ ] iOS Safari.
- [ ] Android Chrome.
Destek politikasına göre eski sürümler.
Ayrıca:
- [ ] Mouse.
- [ ] Trackpad.
- [ ] Touch.
- [ ] Keyboard.
- [ ] Screen reader.
- [ ] High DPI.
- [ ] Low DPI.
- [ ] 60Hz.
- [ ] High-refresh screen gerekiyorsa.
- [ ] Slow CPU.
- [ ] Low memory.

## 70. “Kötü kullanıcı” testi
Normal kullanıcının dışında:
- [ ] Her butona çok hızlı bas.
- [ ] Double click.
- [ ] 20 kez submit.
- [ ] Tab'ı kapat.
- [ ] Refresh.
- [ ] Back.
- [ ] Connection'ı kes.
- [ ] Connection'ı işlem ortasında kes.
- [ ] Token'ı expire et.
- [ ] Permission değiştir.
- [ ] Başka tab'da aynı objeyi değiştir.
- [ ] Aynı kullanıcıyla iki cihaz kullan.
- [ ] Devasa text yapıştır.
- [ ] HTML yapıştır.
- [ ] Script yapıştır.
- [ ] SQL-like string yapıştır.
- [ ] Unicode garbage.
- [ ] Emoji flood.
- [ ] 0-byte file.
- [ ] Huge file.
- [ ] Wrong file extension.
- [ ] API'yi UI olmadan çağır.
- [ ] IDs değiştir.
- [ ] Rate limit'i zorla.
- [ ] Her dependency'yi ayrı ayrı öldür.

## 71. “Gerçek insan” kalite testi
Bu tamamen metrik değildir ama ürün kalitesinin çok önemli kısmıdır.
Beş gerçek kullanıcıya hiçbir yardım etmeden uygulamayı ver:
- [ ] Ne işe yaradığını anlayabiliyor mu?
- [ ] Nereden başlayacağını biliyor mu?
- [ ] Ana işi tamamlayabiliyor mu?
- [ ] Hata yaptığında düzeltebiliyor mu?
- [ ] Bir şey olduğunda neden olduğunu anlıyor mu?
- [ ] Yardım istemeden ana özelliği keşfedebiliyor mu?
- [ ] Kullanıcı beklenmedik yerlerde duruyor mu?
- [ ] Yanlış CTA'ya basıyor mu?
- [ ] Terminolojiyi anlıyor mu?
- [ ] “Bu ne yapacak?” diye tereddüt ediyor mu?
- [ ] App hızlı hissediyor mu?
- [ ] App güvenilir hissediyor mu?

## 72. Görsel “premium polish” turu
Son tur olarak ekran ekran:
- [ ] Pixel misalignment.
- [ ] 1px border inconsistencies.
- [ ] Uneven padding.
- [ ] Uneven card height.
- [ ] Inconsistent corner radius.
- [ ] Text baseline mismatch.
- [ ] Icon optical alignment.
- [ ] Icon stroke mismatch.
- [ ] Incorrect icon weight.
- [ ] Button label centering.
- [ ] Avatar cropping.
- [ ] Image aspect ratio.
- [ ] Blurry assets.
- [ ] Wrong resolution.
- [ ] Shadow clipping.
- [ ] Gradient banding.
- [ ] Scrollbar.
- [ ] Focus ring.
- [ ] Selection highlight.
- [ ] Text caret.
- [ ] Cursor type.
- [ ] Hover transition.
- [ ] Tooltip positioning.
- [ ] Popover collision.
- [ ] Dropdown viewport overflow.
- [ ] Modal vertical centering.
- [ ] Sticky header.
- [ ] Sticky footer.
- [ ] Safe area.
- [ ] Keyboard overlay.
- [ ] Z-index issues.
- [ ] Body scroll leak.
- [ ] Transition flash.
- [ ] Dark mode flash.
- [ ] Font loading flash.
- [ ] Skeleton-to-content jump.
Burada “milyar dolarlık uygulama hissi” oluşmaya başlıyor.

## 73. Release öncesi security gate
NO-GO:
- [ ] Bilinen critical vulnerability varsa.
- [ ] Auth bypass varsa.
- [ ] Tenant isolation hatası varsa.
- [ ] Remote code execution ihtimali varsa.
- [ ] Sensitive data leak varsa.
- [ ] Hardcoded production secret varsa.
- [ ] Backup yoksa kritik sistemlerde.
- [ ] Restore doğrulanmadıysa kritik sistemlerde.
- [ ] Admin panel korunmuyorsa.
- [ ] Payment integrity hatası varsa.
- [ ] AI agent destructive işlemi approval'sız yapabiliyorsa.
- [ ] Prompt injection sonucu yetki aşımı mümkünse.

## 74. Release öncesi UX gate
NO-GO:
- [ ] Ana kullanıcı flow'u tamamlanamıyorsa.
- [ ] Kullanıcının verisi kayboluyorsa.
- [ ] Destructive işlem yanlışlıkla kolay tetikleniyorsa.
- [ ] Kritik error görünmüyorsa.
- [ ] App önemli cihazlarda kullanılamıyorsa.
- [ ] Kritik accessibility blocker varsa.
- [ ] Payment sonucu belirsizse.
- [ ] Login/reset çalışmıyorsa.
- [ ] AI kritik görevde kabul edilemez oranda yanlış davranıyorsa.

## 75. Release öncesi engineering gate
- [ ] CI green.
- [ ] Unit green.
- [ ] Integration green.
- [ ] Critical E2E green.
- [ ] AI evals green.
- [ ] Security gate green.
- [ ] Performance gate green.
- [ ] Migration tested.
- [ ] Smoke test green.
- [ ] Backup green.
- [ ] Restore test güncel.
- [ ] Monitoring active.
- [ ] Alerts active.
- [ ] Dashboard active.
- [ ] Rollback tested.
- [ ] Feature flags ready.
- [ ] On-call hazır.
- [ ] Runbook hazır.

## 76. Canary release gate
Canary kullanıcılarında:
- [ ] Error rate normal.
- [ ] Latency normal.
- [ ] CPU normal.
- [ ] Memory normal.
- [ ] DB normal.
- [ ] External APIs normal.
- [ ] Crash rate normal.
- [ ] AI quality normal.
- [ ] AI cost normal.
- [ ] Payment conversion normal.
- [ ] Business KPI normal.
- [ ] Support tickets anormal artmıyor.
Değilse:
STOP → ROLLBACK → INVESTIGATE.
Google SRE'nin yaklaşımı da değişikliklerin gerçek trafik altında küçük bir grupta değerlendirildikten sonra genişletilmesidir. 

## 77. Full launch gate
Bütün kritik alanların özeti:
Alan	Launch için
Product	Kritik flow'lar tamam
UI	Kritik görsel kusur yok
UX	Kritik usability blocker yok
Motion	Jank/motion accessibility blocker yok
Accessibility	Belirlenen standardı karşılıyor
Frontend	Kritik hata yok
Backend	Kritik endpoint'ler doğrulandı
Database	Integrity + migration doğrulandı
Security	Critical açık yok
Privacy	Veri akışı anlaşılmış
AI	Eval threshold geçildi
AI Security	Critical agent/LLM riski açık değil
Performance	Hedefler içinde
Reliability	Failure planları var
Monitoring	Aktif
Alerting	Aktif
Backup	Aktif
Restore	Test edilmiş
CI/CD	Green
Rollback	Hazır
Support	Hazır
Incident response	Hazır
Legal/store	Uygun
Canary	Sağlıklı
## 78. Launch sonrası ilk dönem
Launch yaptın diye checklist bitmez.
- [ ] Crash monitoring.
- [ ] Error rate.
- [ ] Latency.
- [ ] SLO.
- [ ] User support.
- [ ] Funnel.
- [ ] Activation.
- [ ] Retention.
- [ ] Churn.
- [ ] Payment.
- [ ] AI errors.
- [ ] AI cost.
- [ ] Hallucinations.
- [ ] Security events.
- [ ] Abuse.
- [ ] DB growth.
- [ ] Storage growth.
- [ ] Infrastructure cost.
- [ ] Queue backlog.
- [ ] User feedback.
- [ ] App Store/Play reviews.
- [ ] Top support issues.
- [ ] Unexpected workflows.
- [ ] New eval cases.
- [ ] New regression tests.

## 79. Her production bug'dan sonra
Bu nokta çok önemli.
Bug çıktı:
Fix etmek yetmez.
Şunları sor:
- [ ] Neden oldu?
- [ ] Neden test yakalamadı?
- [ ] Neden monitoring yakalamadı?
- [ ] Neden kullanıcı yakaladı?
- [ ] Aynı bug sınıfı başka nerede olabilir?
- [ ] Unit test eklenebilir mi?
- [ ] Integration test eklenebilir mi?
- [ ] E2E test eklenebilir mi?
- [ ] AI ise eval case eklenebilir mi?
- [ ] Static check eklenebilir mi?
- [ ] CI gate eklenebilir mi?
- [ ] Monitoring eklenebilir mi?
- [ ] Alert eklenebilir mi?
- [ ] Architecture değişikliği gerekiyor mu?
- [ ] Checklist'e yeni madde eklenmeli mi?
İşte büyük şirketlerin checklist'lerinin sürekli büyüme sebebi budur. Google açıkça launch checklist maddelerinin çoğunun geçmişte yaşanan gerçek launch problemlerinden türediğini anlatıyor. 

## 80. Bir özelliğin “DONE” tanımı
Ben AI ile uygulama geliştirirken feature done kavramını şöyle tanımlardım:
Bir feature ancak:
**Design
- [ ] all states
- [ ] responsive
- [ ] accessibility
- [ ] motion
- [ ] frontend
- [ ] backend
- [ ] auth/authz
- [ ] database
- [ ] error handling
- [ ] analytics
- [ ] monitoring
- [ ] tests
- [ ] security
- [ ] AI evals gerekiyorsa
- [ ] documentation
- [ ] rollout
- [ ] rollback**
