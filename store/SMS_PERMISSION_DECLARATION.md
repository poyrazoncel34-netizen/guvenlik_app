# Google Play SMS Declaration Notu

KoruBeni artık `SEND_SMS` iznini manifestte beyan etmiyor.

Bu nedenle Play Console tarafında restricted `SMS Permission Declaration` formunu doldurma ihtiyacı kaldırıldı. Uygulama acil durum mesajı için kullanıcının varsayılan SMS uygulamasını önceden doldurulmuş alıcı ve metinle açar.

Sonuç:

- `Permissions declarations` altında `SEND_SMS` için istisna isteme zorunluluğu yok
- Data Safety formunda konum ve kişi erişimi yine doğru şekilde beyan edilmeli
- Demo videoda SMS composer akışını göstermek yine faydalı olabilir, fakat restricted SMS permission başvurusu için zorunlu değildir
