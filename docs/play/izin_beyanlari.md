# Play Console — hassas izin beyanları (Faz 11a, 2026-10-22)

Play Console > Uygulama içeriği'ndeki formlara yapıştırılacak metinler. Her
izin için: **neden**, **reddedilirse ne olur**, **kısa video senaryosu**
(Play, `MANAGE_EXTERNAL_STORAGE` ve ön plan servisleri için video istiyor).

## MANAGE_EXTERNAL_STORAGE (Tüm dosyalara erişim)

- **Kategori:** Dosya yöneticisi (izin verilen kullanım: "File managers").
- **Neden:** Uygulamanın asıl işlevi telefondaki tüm dosyaları gezmek,
  açmak, taşımak, kopyalamak, silmek ve yer açmaktır (indirilenler,
  WhatsApp medyası, SD kart, USB bellek). Medya izinleri belge/arşiv/APK
  dosyalarını kapsamaz; Storage Access Framework klasör bazında izin verdiği
  için tüm depolamayı yöneten bir dosya yöneticisi için yetersizdir.
- **Reddedilirse:** Uygulama açılır; belge görüntüleyici/düzenleyici
  "Birlikte aç" ve paylaşım yoluyla gelen dosyalarla çalışır. Gezgin, pano
  analizi ve temizlik "izin gerekli" kartı gösterir.
- **Video senaryosu (30 sn):** ilk açılış → İzinler sayfası → "Tüm
  dosyalara erişim"e dokun → sistem ayarı → geri dön → pano dolu bellek
  halkası → İndirilenler'de bir PDF'i aç → çöp kutusuna taşı → geri al.

## FOREGROUND_SERVICE_DATA_SYNC

- **Neden:** Kullanıcının başlattığı uzun dosya işleri (kopyalama/taşıma,
  ZIP, video küçültme, ağ paylaşımı) ekran kapansa da sürsün; bildirimde
  ilerleme ve "Durdur" düğmesi.
- **Video:** büyük klasörü SD karta kopyala → ana ekrana çık → bildirimdeki
  ilerleme çubuğu → "Durdur".

## FOREGROUND_SERVICE_MEDIA_PLAYBACK

- **Neden:** Ses/video oynatıcı ve sesli kitaplar arka planda çalar;
  kilit ekranı ve bildirim denetimleri.

## PACKAGE_USAGE_STATS (isteğe bağlı)

- **Neden:** "Uygulamalar" ekranında son kullanım tarihini göstermek
  (uzun süredir kullanılmayan uygulamaları kaldırma önerisi). Kullanıcı
  kendisi verir; vermezse yalnız kurulum tarihi görünür.

## REQUEST_INSTALL_PACKAGES

- **Neden:** Dosya yöneticisinde kullanıcının dokunduğu APK dosyasını
  sistemin kurulum ekranına vermek. Uygulama kendiliğinden hiçbir şey kurmaz.

## CAMERA

- **Neden:** Belge tarama (kenar algılama, PDF). Yalnız tarama açıkken.

## POST_NOTIFICATIONS

- **Neden:** Uzun işlerin ilerlemesi/sonucu, fatura hatırlatması. Reddedilirse
  işler yine çalışır, yalnız bildirim görünmez.

## INTERNET

- Kullanıcının başlattığı işler: Gemini AI (kendi anahtarı), Google Drive,
  ağ depolama, indirme yöneticisi, ML Kit dil modeli ve yapay zekâ sesi
  indirmeleri. Analitik/reklam YOK.
