# Guvenlik Acigi Bildirimi — KoruBeni

KoruBeni bir kisisel guvenlik uygulamasidir: panik cagrisi, acil kisiler ve
yerel PIN kilidi. Bir aciga rastlarsaniz lutfen once bize bildirin.

## Nereye bildirilir

**korubeni.security@gmail.com** — genel destekten AYRI bir adres, bu yuzden bir
guvenlik raporu ozellik istekleri arasinda kaybolmaz.

Yanit beklentisi: **3 is gunu icinde ilk yanit.** Bu tek gelistiricili bir
projedir; sure bunu yansitiyor, bir SLA taahhudu degil.

## Kapsam

| Kapsamda | Kapsam disi |
|---|---|
| Acil cagri yolunu engelleyen/geciktiren her sey | Sunucu tarafi — sunucu yok |
| PIN kilidi, kilitlenme sayaci, zorlama (duress) modeli | Kullanici hesabi ele gecirme — hesap yok |
| Yerel depolama (acil kisiler, riza kaydi, guvenlik gecmisi) | Analitik/telemetri — hicbiri yok |
| Android manifest, exported bilesenler, platform kanallari | Ucuncu taraf harita dosemesi sunucusu |
| RevenueCat entegrasyonu / yetkilendirme kapilari | |

## Bu urunun kasitli tasarim kararlari — kusur degildir

Bunlari bildirmeden once okuyun; hepsi bilerek boyledir ve gerekcesi yazilidir.

- **Biyometrik kilit acma YOKTUR ve eklenmeyecektir.** Bir saldirgan parmagi ya
  da yuzu zorla kullandirabilir; PIN saklanabilir. Zorlama modelinde biyometri
  bir zaafiyettir, bir ozellik degil.
- **KVKK riza kaydi duz `SharedPreferences`'tedir, keystore'da degil.** Riza
  kaniti keystore sifirlanmalarindan sag cikmalidir. Bu kasitli bir secimdir.
- **Acil kisiler icin tek kaynak `flutter_secure_storage`'dir.** Veritabaninda
  eski bir tablo vardir ve BOS tutulur.
- **Uzaktan kapatma anahtari (kill switch) yoktur.** Bir panik butonunda uzaktan
  kapatma anahtari, kendisi bir guvenlik riskidir.

## Bildirirken

Etkilenen surum, cihaz/Android surumu ve yeniden uretme adimlari yeterlidir.
Kavram kanidi kodu isteriz ama zorunlu degildir. Duzeltme yayinlanana kadar
kamuya acmamanizi rica ederiz.

## Odul

Para odulu yoktur. Isteginiz halinde duzeltme notlarinda ad verilir.
