# KALANLAR — canlı kalan-iş listesi (biten madde silinir)

## Yarım kalan
- [ ] **2026-08-01 turu cihaz doğrulaması (kullanıcı)** — (a) slaytta her kartın
      üstünde ve sağ alt rozette **"Slayt 3 / 12"** yazıyor mu, rozete
      dokununca "Slayta git" açılıp o slayda ATLIYOR mu (yakınlaştırılmış
      hâlde de doğru yere), (b) üstteki 🔍 ile aranan kelime bulunuyor,
      ‹ › eşleşmeler arasında geziyor, altındaki bağlam satırı hangi slaytta
      olduğunu söylüyor mu, (c) alt çubuktaki **AI özet** → "Kısa"/"Detaylı"
      seçenekleri geliyor ve özet slayt numaralarına atıf yapıyor mu,
      (d) slaytta bir metin kutusuna dokunup düzenlemeye geçince **geri tuşu**
      ekrandan çıkmak yerine düzenlemeyi kapatıyor mu (Word'de de aynı),
      (e) Word'de **yakınlaştırınca yazı keskin mi** (pinch artık JS/CSS zoom;
      bulanıklık gitmeli), ölçek rozeti (%) çıkıyor mu, (f) Word biçim
      çubuğundaki **yazı tipi/punto** seçimi paragrafa uygulanıp KAYDEDİLİYOR
      mu (kaydet → Word'de aç → font ve punto korunmuş olmalı), (g) Word'de
      sol alt **"Sayfa 3 / 12"** rozeti doğru sayıyor ve dokununca o sayfaya
      gidiyor mu, (h) Excel durum çubuğunun sağında **"Sayfa 1 / 3"** var mı,
      (i) **dondurulmuş bölmesi olan** bir Excel dosyasında tek hücre değiştirip
      kaydet → masaüstü Excel'de aç → bölme, ızgara ayarı ve süzgeç okları
      DURUYOR mu.
- [ ] **Google Drive cihaz doğrulaması (kullanıcı)** — 2026-07-30: Pano →
      Araçlar → **Google Drive** → (a) "Google ile bağlan" hesap seçtiriyor ve
      Drive izni soruyor mu, (b) bir dosyaya uzun bas → **Drive'a yükle** →
      dosya gerçekten Drive'a çıkıyor mu, (c) Drive ekranında o dosya
      listeleniyor mu, dokununca inip AÇILIYOR mu, (d) kapsam şeridi
      ("yalnız bu uygulamayla yüklediğiniz…") okunuyor mu, (e) silme çalışıyor
      mu, (f) **google-services.json yoksa** giriş penceresi hiç açılmıyor
      olmalı — çökme DEĞİL. NOT: Drive, Firebase ile aynı OAuth istemcisini
      kullanıyor; Firebase kurulmamışsa Drive da çalışmaz (FIREBASE_SETUP.md).
- [ ] **NAS cihaz doğrulaması (kullanıcı)** — 2026-07-30: Pano → Araçlar →
      **Ağ depolama** → (a) **Ağda ara** telefonun Wi-Fi'sindeki NAS'ı buluyor
      mu (mDNS + port taraması), (b) elle eklenen SFTP/FTP/FTPS/WebDAV
      bağlantısı **Bağlantıyı sına** ile yeşil veriyor mu, (c) klasörler
      geziliyor, dosya dokununca inip AÇILIYOR mu, (d) **Buraya yükle** /
      yeni klasör / yeniden adlandır / sil çalışıyor mu, (e) parola kaydetme
      KAPALIYKEN her bağlanışta soruluyor mu, (f) yanlış adres/parola
      ANLAŞILIR hata veriyor mu (ham SocketException değil).
- [ ] **SMB: yalnız SMB3 zorunlu kılan sunucular sınanmadı.** SMB'nin kendisi
      2026-07-30'da **gerçek Samba 4.19 (SMB2) üzerinde doğrulandı** — okuma ve
      yazma çalışıyor (HAFIZA 2026-07-30 IV; `test/remote_live_test.dart`), o
      yüzden "protokolü listeden çıkar" kararı KAPANDI. Kalan tek belirsizlik:
      `smb_connect` en fazla SMB210 konuşuyor; SMB3'ü zorunlu kılan (eski
      sürümleri kapatmış) bir NAS'ta bağlanmayabilir. Ekrandaki uyarı bunu
      yazıyor ve kullanıcıyı SFTP/FTP'ye yönlendiriyor.
- [ ] **SMB'de port değiştirilemez (paket sınırı).** `smb_connect` bağlanırken
      445'i sabit kullanıyor, verilen portu yok sayıyor; form alanı bu yüzden
      SMB'de kapalı. Farklı portta SMB gerekirse paket çatallanmalı.
- [ ] **PC'den FTP cihaz doğrulaması (kullanıcı)** — Ağ depolama → sağ üst
      bilgisayar simgesi → **Başlat** → PC'nin dosya gezginine/tarayıcısına
      yazılan `ftp://<ip>:2121` adresi açılıyor mu, kullanıcı adı/parola
      soruluyor mu, dosyalar listelenip indiriliyor mu, **Yazmaya izin ver**
      kapalıyken PC'den silme reddediliyor mu.
- [ ] **FTP sunucusu arka planda çalışmıyor (bilinçli).** Ekrandan çıkınca
      duruyor: kullanıcı telefonunu ağa açtığını unutmasın. İstenirse ön plan
      servisi + kalıcı bildirim gerekir (manifest'e servis eklenmesi lazım).
- [ ] **Dil desteği cihaz doğrulaması (kullanıcı)** — 2026-07-30: Ayarlar →
      **Dil** → English / العربية seç → (a) ana ekran, alt sekmeler, Ayarlar,
      Excel ve Word ekranları o dilde mi, (b) **Arapça'da arayüz sağdan sola**
      mı akıyor (geri oku, sekme sırası, kaydırıcılar), (c) Arapça'da yazı
      tipi okunur mu (cihazın Arapça fontu), (d) dil seçimi uygulamayı
      kapatıp açınca korunuyor mu, (e) "Sistem" seçiliyken telefon dili
      İngilizce/Arapça ise uygulama o dilde mi açılıyor.
- [ ] **Kalan ekranlar hâlâ Türkçe** — 2026-07-30'da çevrilenler: ana ekran,
      Ayarlar, Excel, Word. Dosya yöneticisi ekranları (pano, kategoriler,
      fotoğraflar, arama, işlemler, indirme…), PDF ekranları, slayt editörü,
      AI sohbeti ve `services/` içindeki kullanıcıya görünen metinler
      çevrilmedi. Altyapı hazır: `context.t('anahtar')` + `lib/core/l10n/
      app_strings.dart` tablosuna üç dilli satır eklemek yetiyor; `l10n_test`
      eksik anahtarı zaten yakalıyor.
- [ ] **Sağdan sola Excel/Word cihaz doğrulaması (kullanıcı)** — 2026-07-30:
      (a) Arapça bir .xlsx aç → A sütunu SAĞDA mı, kaydırma sağ kenardan mı
      başlıyor, hücre metni sağa mı yaslı, sayılar sola mı, (b) ⋮ > **Sayfa
      sağdan sola** ile yön değişiyor mu, kaydedip Excel'de açınca korunuyor
      mu, (c) gizlediğin sütunu kaydedip Excel'de aç → gizli KALMALI,
      (d) Arapça bir .docx aç → sayfa görünümünde metin sağdan mı akıyor,
      Arapça harfler kutu (tofu) çıkmıyor mu, (e) ⋮ > Metin düzenleyicide
      paragraflar sağa yaslı mı.
- [ ] **2026-07-28 turu cihaz doğrulaması (kullanıcı)** — (a) resmi PDF'te
      *Düzenleyici → Metin* → paragrafa dokun → artık ne "metin dışı çizim var
      (ET)" ne de "(Q)" uyarısı ÇIKMAMALI; (b) **ortalı** bir başlığı (DAĞITIM
      gibi) kısalt/uzat → sayfada ORTALI kalmalı; (c) *Görsel* modunda armayı
      taşı → KESİLMEMELİ; (d) Word'de alt çubuktaki **Mobil** düğmesi → yazı
      okunur boyuta gelmeli, **Sayfa** ile geri dönmeli, düzenleme hâlâ
      çalışmalı; (e) Word/Excel/slayt/görüntüleyicide üstteki ⋮ ve simgelerde
      artık alttakilerin ikizi OLMAMALI, ama Word/Slaytta düzenlemeye geçince
      üstte **Kaydet** görünmeli.
- [ ] **PDF editörü cihaz doğrulaması (kullanıcı)** — 2026-07-27: PDF aç → alt
      çubuk **Düzenleyici** → (a) *Metin* modunda paragraf kutuları çıkıyor mu,
      dokununca pencere açılıp özgün metni üstte gösteriyor mu, "Uygula" sonrası
      sonuç sayfada HEMEN görünüyor mu, yazı tipi/punto/hizalama korunuyor mu,
      (b) kelimeyi uzatınca satır düzgün sarıyor mu, kısaltınca boşluk düzgün mü,
      (c) *Görsel* modunda logo/QR seçilip sürükleniyor/boyutlanıyor/siliniyor mu,
      (d) *Filigran* modunda "KOPYADIR" benzeri damga listeleniyor ve
      kaldırılıyor mu, gerçek içerik listede ÇIKMAMALI, (e) *Sayfa* modunda
      90° sağa/sola dönüyor mu, (f) **Geri al** işe yarıyor mu, (g) **Kaydet** →
      "Üzerine yaz / Kopyasını kaydet / Klasör seç" ve "AÇ" düğmesi çalışıyor mu,
      (h) kaydetmeden çıkınca özgün dosya DEĞİŞMEMİŞ olmalı.
- [ ] **Eski (kelime bazlı) yerinde düzenleme yolunu SİL** — 2026-07-27: paragraf
      editörü cihazda doğrulanınca `viewer_screen`'deki seçim-tabanlı düzenleme
      zinciri (`_startInlineEdit`/`_applyInlineEdit`/`_InlineEdit`/`_editBar`),
      `services/pdf_edit_flow.dart`, `services/pdf_content_editor.dart`,
      `services/pdf/pdf_text_replace.dart`, `widgets/pdf_inline_editor.dart` ve
      testleri (`pdf_content_editor*`, `pdf_inplace_edit`, `pdf_reflow`,
      `pdf_replace_text`, `pdf_encrypted_edit`) kaldırılacak. **Şimdi
      silinmemesinin nedeni:** paragraf motoru bazı belgeleri REDDEDİYOR
      (genişlik tablosu olmayan font, aralıkta gerçek çizim `q`/`cm`/`Do`,
      sığmama — *satır başına ayrı `BT`/`ET` reddi 2026-07-28'de kalktı*);
      eski yol o belgelerde hâlâ çalışan tek yedek. Doğrulanmadan silmek
      yetenek kaybı olurdu. (usta 4b'nin istisnası, gerekçesi burada.)
- [ ] **Okuma deneyimi cihaz doğrulaması (kullanıcı)** — 2026-07-25 Faz 4: PDF aç →
      (a) ay simgesi gece modunu açıyor mu, sayfa ters renkte okunaklı mı,
      (b) içindekiler (☰ simgesi) olan bir PDF'te başlığa dokununca o sayfaya
      gidiyor mu, olmayan belgede "içindekiler yok" diyor mu, (c) içinde köprü
      olan PDF'te bağlantıya dokununca ONAY penceresi tam adresi gösteriyor mu,
      "Aç" tarayıcıyı açıyor mu, iç bağlantı sayfaya atlıyor mu, (d) ⋮ "Sesli oku"
      → Türkçe okuyor mu, duraklat/devam/durdur çalışıyor mu, ekrandan çıkınca
      susuyor mu (dispose), (e) taranmış PDF'te "önce OCR" uyarısı geliyor mu.
- [ ] **İmza cihaz doğrulaması (kullanıcı)** — 2026-07-25 Faz 2: PDF aç → ⋮
      "İmzala" → (a) imza penceresi çiziyor mu, "Tamam" sonrası imza HATIRLANIYOR
      mu (ikinci kez sormamalı), (b) imza kutusu parmakla sürüklenip kaydırıcıyla
      büyüyor mu, (c) "Bas" sonrası imza sayfada TAM gördüğünüz yerde mi,
      (d) yakınlaştırınca keskin mi (vektör), (e) **döndürülmüş sayfada** (araçlardan
      90° döndürüp imzalayın) imza yan yatık ya da başka köşede mi çıkıyor —
      koordinat çevirisi birim testli ama cihazda görsel teyit edilmedi.
- [ ] **Belge tarayıcı cihaz doğrulaması (kullanıcı)** — 2026-07-25 Faz 3: ana
      ekranda "Belge Tara" → (a) Google tarayıcı arayüzü açılıyor mu, kamera izni
      soruluyor mu, (b) kenar tespiti + kırpma + filtre "tarayıcıdan çıkmış gibi"
      mi, (c) çok sayfa çekip tek PDF oluyor mu, (d) "Yazıları da tanı" seçilince
      PDF içinde arama çalışıyor mu, (e) belge Son belgeler'de görünüyor mu,
      (f) PDF Araçları ⋮ "Sayfa tara ve ekle" mevcut belgeye ekliyor mu.
      **Play Services olmayan cihazda** paketin yedek tarayıcısına düşmeli.
- [ ] **PDF Araçları cihaz doğrulaması (kullanıcı)** — 2026-07-25 Faz 1: ana ekran
      PDF simgesi / görüntüleyici ⋮ "PDF araçları" → (a) sayfa küçük resimleri
      geliyor mu, (b) seç → döndür/sil/öne-arkaya taşı doğru sayfaya mı uyguluyor,
      (c) "Çıkar" seçili sayfaları ayrı PDF olarak paylaşıyor mu, (d) "Başka PDF
      ekle" birleştiriyor mu, (e) parola koy → uygulamayı kapat-aç → parola soruyor
      mu, parolayı kaldır çalışıyor mu, (f) sıkıştır boyutu düşürüyor mu (taranmış
      PDF'te kazanç KÜÇÜK olabilir, beklenen), (g) Kaydet sonrası görüntüleyici
      belgeyi tazeliyor mu.
- [ ] **Çeviri/resim-PDF/premium cihaz doğrulaması (kullanıcı)** — 2026-07-24,
      build 89'da: (a) PDF'te metin seç → "Çevir" → dil modeli iniyor mu, çeviri
      geliyor mu; (b) Word/Excel/Slayt menüsünde "Belgeyi çevir"; (c) bir resim
      açıp "PDF'e dönüştür" → "Yazıları da tanı" → çıkan PDF'te resim TAM ve
      içindeki yazı aranabilir mi; (d) .apk dosyasına "birlikte aç" deyince
      uygulamamız artık listede ÇIKMIYOR mu (asıl şikayet); (e) WhatsApp'tan
      gelen dosya hâlâ açılıyor mu (octet-stream riski — HAFIZA'da yazılı);
      (f) premium görünüm: kart/liste/boş durum, koyu tema kontrastı.
- [ ] **Seçili metin çevirisi Word/Excel/Slayt'ta yok** — şu an yalnız PDF'te
      (seçim altyapısı orada). Word WebView tabanlı, seçim Flutter'a gelmiyor;
      istenirse JS köprüsüyle seçili metin okunabilir.
- [ ] **`withOpacity` → `withValues` temizliği** — analyze'da ~8 uyarı
      (markdown_text, pdf_select_layer, office_shell, viewer_screen, editörler).
      Yeni kod `withValues` kullanıyor, eskiler kaldı.
- [ ] **PDF Faz 2 vurgu cihaz doğrulaması (kullanıcı)** — yerel build telefona
      KURULDU (2026-07-23, adb install başarılı, debug-imzalı). "Metin seç" →
      renk seç (sarı/yeşil/pembe/mavi) → Vurgula → (a) vurgu SEÇİLEN metnin tam
      üstüne oturuyor mu (koordinat Y-flip), (b) kaydettikten sonra aynı sayfada
      yeniden yükleniyor mu (ValueKey), (c) kapatıp açınca vurgu kalıcı mı.
      **Not:** kaldır+kur ile kuruldu → Gemini API anahtarı ve son dosyalar listesi
      sıfırlandı, Ayarlar'dan anahtarı tekrar gir. Push yapılmadı, main/CI eski.
- [ ] **Cihaz doğrulaması (kullanıcı)** — 2026-07-23 14:30'da yerel derleme telefona
      kuruldu, içindekiler test edilmedi: Excel hücre içi yazma (seçili hücreye
      ikinci dokunuş), slaytta yerinde metin düzenleme, PDF seçim tutamaçları,
      Gemini model listesinin Ayarlar'da otomatik dolması. Ayrıca eski liste:
      WhatsApp "birlikte aç", odak-noktalı pinch, Word tam sayfa sığdırma,
      eski .doc/.xls/.ppt açma, arama, yeni belge, slayt çoğalt/sil/taşı.
- [ ] **PDF arama cihaz doğrulaması (kullanıcı)** — Faz 1 (belge içi arama + sayfaya
      atlama + sarı vurgu) main'de/build'de: gerçek PDF'te arama sonuçları doğru
      vurgulanıp sonraki/önceki ile o sayfaya kayıyor mu? (pdfrx PdfTextSearcher).
- [ ] **Slayt sadakati cihaz doğrulaması (kullanıcı)** — Faz 1-3 yerelde test
      yeşil (204) ama GÖRSEL cihazda bakılmadı (2026-07-23): gömülü fontlarla
      metin görünümü + **değişken-Arimo kalın** (Arial kalın doğru mu?),
      bağlayıcı okları/kesik çizgi, dış gölge, grafiklerin (sütun/çubuk/pasta/
      halka/çizgi) gerçek .pptx'te doğru veri+renk+oranla çizilmesi.

- [ ] **Word sadakati cihaz doğrulaması (kullanıcı)** — 2026-07-24 WebView'a MS font
      ikamesi (Calibri→Carlito, Times→Tinos, Arial→Arimo `@font-face`) + Word sayfa
      kırma konumları (`ignoreLastRenderedPageBreak:false`) + tam A4 yükseklik
      (`ignoreHeight:false`) eklendi. Gerçek Calibri/Times/Arial'lı .docx'te: (a)
      satır/sayfa kırılımı Word ile aynı yerde mi, (b) yazı yerel/doğru görünüyor mu,
      (c) `../fonts/` file:// erişimi cihazda fontları gerçekten yüklüyor mu (script'ler
      yükleniyor → beklenen evet). Yerelde flutter yok, CI test+APK yeşil olmalı.

- [ ] **PPTX sadakati cihaz doğrulaması (kullanıcı)** — 2026-07-24: p:style tema
      dolgu/çizgi referansı, görsel flipH/flipV, spcPts/spcAft satır aralığı, tablo
      kenar-başına kenarlık eklendi (birim testli, CI yeşil olmalı). Gerçek .pptx'te:
      (a) tema temelli renkli şekiller artık dolu mu (eskiden boştu), (b) aynalanmış
      görseller doğru yönde mi, (c) tablo yalnız tanımlı kenarları mı çiziyor.

## PDF sadakat/deneyim — araştırıldı, cihaz doğrulaması gerekli (kör push yok)
- [ ] **Türkçe-duyarlı PDF arama** — PDF yolu `startTextSearch(caseInsensitive)` locale-
      duyarsız; İ/ı/ş kaçıyor. `findAll`(turkishFold) + `selectionPdfRects` + kendi
      paint callback'iyle değiştir (`viewer_screen` PDF arama dalı). Altyapı hazır.
- [ ] **Döndürülmüş sayfa (/Rotate≠0) vurgu düzeltmesi** — `pdf_annotator.addHighlight`
      sayfa rotasyonunu okuyup rect'leri görünür koordinata döndürsün; `pdf_annotator_test`e
      90/180/270. Syncfusion rotasyon konvansiyonu cihazda teyit edilmeli.
- [ ] **PDF vurgu remount zoom kaybı** — `_pdfReloadKey++` remount'ta zoom/kaydırma sıfırlanır;
      `onViewerReady`'de son matris geri uygula.

## Play Store atağı — PDF (2026-07-25 kararı, 4 faz)
- [x] ~~Faz 1: PDF Araçları (birleştir/çıkar/sil/sırala/döndür/parola/sıkıştır)~~ → YAPILDI 2026-07-25
- [x] ~~Faz 2: İmza (parmakla çiz → sayfaya vektör olarak bas)~~ → YAPILDI 2026-07-25
- [x] ~~Faz 3: Belge tarayıcı (ML Kit) → tek PDF + OCR~~ → YAPILDI 2026-07-25
      ("çoklu resim → tek PDF" maddesini de kapattı)
- [x] ~~Faz 4: gece modu + link tıklama + içindekiler + sesli okuma~~ → YAPILDI 2026-07-25
      **4 fazın tamamı bitti.**

## Sonra yapılacak
- [ ] **PDF form doldurma (en son)** — Syncfusion `PdfLoadedForm` alanları oku (`doc.form.fields`),
      ekranda düzenlenebilir overlay, doldur → save. En belirsiz UX; en son.
- [ ] Yol haritası #2: Firebase config + gerçek senkron (kullanıcı `flutterfire configure`)

## Bilinen eksik-risk
- [ ] Word canlı düzenleme: paragraf eşlemesi indeks tabanlı (DOM `article p` ↔ `w:p`);
      sayı uyuşmazsa sigorta düzenlemeyi kapatıp metin düzenleyiciye yönlendirir.
      Metin kutusu/köprü içeren belgelerde cihazda doğrulanmalı (2026-07-22)
- [ ] Excel pinch: kaydırma sürerken başlayan pinch ilk denemede tutmayabilir
      (ilk parmağın sahipliği scrollable'da kalır); cihazda rahatsız ederse iyileştirilecek
- [ ] Koyu temada Word WebView kanvası açık kalıyor (sayfa zaten beyaz; bilinçli erteleme)
- [ ] **Word'de yazı tipi/punto PARAGRAF düzeyinde** (2026-08-01): seçimin
      ortasındaki üç kelimeye ayrı punto verilemiyor. Bilinçli sınır — seçimi
      `<span>`la sarmak `<p>` sayısını değiştirip canlı düzenlemenin paragraf
      eşlemesini bozabiliyor (sigorta düzenlemeyi tamamen kapatır). Gerekirse
      yol: seçimi paragraf sınırında BÖLÜP her parçayı ayrı sarmak ve eşlemeyi
      `data-p-index` gibi bir kimlikle indeksten bağımsız hale getirmek.

## Dosya yöneticisi (2026-07-25) — cihaz doğrulaması gereken/ertelenen işler
- [ ] **İzin akışı (kullanıcı, cihaz):** ilk açılışta "Tüm dosyalara erişim" kartı →
      Android ayar sayfası → geri dönünce tarama otomatik başlıyor mu. Reddedilirse
      medya izinleriyle en azından Görüntüler/Video/Ses görünüyor mu.
- [ ] **Depolama doluluğu (`df`) gerçek cihazda:** halka/çubuk doğru dolu mu; bazı
      ROM'larda `df` kısıtlıysa çubuk gizlenmeli (kod öyle davranıyor, doğrulanmadı).
- [ ] **Büyük depolama taraması:** 100 bin+ dosyalı telefonda pano taraması ne kadar
      sürüyor, bellek sorun çıkarıyor mu (`_TopN` sınırı yeterli mi).
- [ ] **SD kart / OTG:** `/storage/XXXX-XXXX` bulunuyor mu; birimler arası taşımada
      kopyala+sil yedek yolu çalışıyor mu; SD karta yazma (SAF gerekebilir!) —
      Android bazı cihazlarda SD karta doğrudan yazmayı engeller, o durumda hata
      mesajı anlamlı mı.
- [x] ~~Video/ses oynatıcı ertelendi~~ → **YAPILDI 2026-07-25:** video_player 2.10.1 +
      video_player_android 2.8.15 (Flutter 3.29 uyumlu son sürüm) ile uygulama içi
      oynatıcı: çalma listesi, kaydırma, hız, tam ekran. Cihazda doğrulanacak:
      büyük mkv/HEVC oynatma, tam ekran yatay geçişi, ses dosyasında arka planda
      çalma (arka plan servisi YOK — ekran kapanınca durur, istenirse audio_service).
- [ ] **Ses: bildirim/kilit ekranı kontrolleri yok** — audioplayers ekran kapalıyken
      çalmayı sürdürür ama ön plan servisi olmadığı için sistem bellek baskısında
      süreci öldürebilir ve bildirimden kontrol edilemez. Çözüm `just_audio_background`
      (manifest'te activity sınıfı değişir → APK'da sınıf doğrulayan CI adımı şart).
- [ ] **Ses: ID3 kapak resmi / albüm-sanatçı bilgisi okunmuyor** (dosya adı gösteriliyor).
- [ ] **Ekranı açık tutma (wakelock) yok:** uzun videoda ekran sönebilir; istenirse
      `wakelock_plus` eklenir (küçük eklenti, Flutter 3.29 uyumlu sürüm seçilmeli).
- [ ] **Video küçük resmi (thumbnail) yok** — listelerde video ikonuyla gösteriliyor.
- [ ] **Küçük resim (thumbnail) yalnız görsellerde** — video/PDF küçük resmi yok
      (video için platform kanalı, PDF için pdfium render gerekir).
- [x] ~~RAR/7z çıkarma yok~~ → **YAPILDI 2026-07-25:** koni_archive (saf Dart, MIT)
      ile RAR4/RAR5 + 7z listeleme/çıkarma/önizleme/parola/çok parçalı. Kalan:
      cihazda büyük ve solid RAR'da hız (saf Dart LZMA/PPMd yavaştır — 100 MB+
      arşivde çıkarma dakikalar sürebilir, ilerleme çubuğu var ama İPTAL YOK),
      ve RAR YAZMA kalıcı olarak yok (biçim özel mülk; .zip üretiliyor).
- [ ] **Yapıştırmada çakışma politikası soruluyor değil**, varsayılan "yeniden adlandır"
      (veri ezilmez). İstenirse yapıştırma öncesi Üzerine yaz/Atla/Yeniden adlandır sorusu.
- [ ] **graphify güncellemesi:** yeni `lib/services/fm/*` ve `lib/screens/fm/*` düğümleri
      graf raporunda yok (bu oturumda ağ/API yok) — `graphify update .` çalıştırılmalı.

## Dosya yöneticisi — araştırma karşılaştırmasından KALAN maddeler (2026-07-25)
Referanslar: Fossify File Manager, Material Files, AnExplorer, ekran görüntüsündeki
File Manager+. Bizde artık olanlar: pano/kategoriler, gezgin+çoklu seçim, çöp
kutusu, bellek analizi, **yinelenen dosya bulucu**, arşiv (RAR5/RAR4/7z okuma +
parolalı üretme), medya oynatıcı, galeri, favoriler, arama. Kalanlar:
- [ ] **Ağ/bulut (FTP, SMB, WebDAV, Drive)** — Material Files/AnExplorer'da var.
      Büyük iş: her protokol için sanal dosya sistemi katmanı gerekir; mevcut
      `FsEntry`/`FileOps` doğrudan `dart:io` üzerine kurulu → önce soyutlama.
- [ ] **Çift bölme (dual pane)** — tablet/yatay ekranda iki klasör yan yana,
      sürükle-bırak taşıma. Gezgin push-tabanlı olduğu için orta ölçekli iş.
- [ ] **Toplu yeniden adlandırma** (desen: "Tatil_###.jpg", bul/değiştir).
- [ ] **Varsayılan başlangıç klasörü** ayarı (Material Files'ta var) — küçük iş,
      AppState'e tek tercih.
- [ ] **Dosya seçici olarak davranma** (başka uygulama dosya isteyince
      GET_CONTENT/OPEN_DOCUMENT intent'i karşılamak).
- [ ] **SD karta yazma (SAF)** — Android bazı cihazlarda ikincil birime doğrudan
      yazmayı engeller; gerekirse `SAF` tree izni akışı eklenmeli.
- [ ] **Klasör boyutlarını liste içinde göstermek** (şu an yalnız Özellikler'de,
      istek üzerine hesaplanıyor — her satırda hesaplamak pahalı).

## PDF turu sonrası kalanlar (2026-07-26, 2. tur sonrası güncel)
- [ ] **Cihaz doğrulaması bekliyor:** vurgulama, uzun basışla metin seçimi,
      2/4 sütun düzeni, kaydırma çubuğu, taramada köşe ayarı + döndürme,
      yerinde metin düzenleme. Hiçbiri birim testle doğrulanamaz
      (pdfium render + dokunma + kamera).
- [x] ~~Vurgu koordinatı /Rotate=0 varsayıyor~~ → **YANLIŞ ALARM, ölçüldü
      2026-07-26:** dört açıda da yazılan `/Rect` birebir aynı. İki taraf da ham
      sayfa uzayında konuşuyor. Uyarı silindi, davranış testle sabitlendi.
- [x] ~~AI düzenleme sayfa düzenini korumuyor~~ → **YAPILDI (3. tur):**
      `PdfContentEditor` ile GERÇEK yerinde düzenleme — belgenin kendi metni
      değişiyor, yazı tipi/punto/konum korunuyor, eski metin siliniyor,
      değişiklik dosyanın sonuna ekleniyor (özgün baytlara dokunulmuyor).
      Üstünü kapatan eski yol yalnız yedek (reddedilirse, onay alarak).
- [x] ~~Yerinde düzenleme özel kodlamalı fontlarda çalışmaz~~ → **ÇÖZÜLDÜ
      (4. tur):** fontun `/ToUnicode` tablosu okunup ters çevriliyor; alt küme
      gömülü ve Type0/Identity-H fontlar artık çalışıyor, yeni metin belgenin
      ÖZGÜN yazı tipiyle yazılıyor. Kalan sınır: alt küme fontta HİÇ geçmemiş
      bir harf yazılamaz (glif yok) — reddediliyor.
- [ ] **`/ToUnicode` taşımayan belgeler** (eski üreticiler, bazı taranmış+OCR
      çıktıları) hâlâ tek baytlık tahmine kalıyor; tutmazsa yedek yola düşer.
      Çözüm: `/Encoding /Differences` + glif adı→Unicode tablosu (AGL).
- [x] ~~Yeni metin uzunsa satırın kalanı sağa kayar (PDF metni yeniden
      akıtmaz)~~ → **YAPILDI (5. tur):** belgenin kendi glif genişlikleriyle
      ölçülüp satırın kalanı kaydırılıyor (`pdf_font_metrics` + `scanContent`).
      Taşarsa kaydetmeden önce uyarı veriliyor.
- [ ] **İki yana yaslı satır yeniden YASLANMIYOR.** Satırın kalanı doğru kadar
      kayıyor ama sağ kenar artık düz değil (Word paragrafı yeniden dağıtır,
      biz tek satıra dokunuyoruz). Çözüm için paragraf sınırlarını ve `Tw`
      dağıtımını yeniden hesaplamak gerekir — ayrı ve büyük iş.
- [ ] **Yerinde düzenleme cihaz doğrulaması (kullanıcı)** — 5. tur: PDF aç →
      yazıya uzun bas → "Düzenle" → (a) kutu metnin TAM ÜSTÜNDE mi açılıyor,
      punto/konum oturuyor mu, (b) klavye kendiliğinden geliyor ve metin baştan
      seçili mi, (c) kelimeyi uzatıp uygula → satırın kalanı KAYIYOR mu,
      kısaltınca boşluk kalmıyor mu, (d) yakınlaştırılmış sayfada kutu doğru
      yerde mi, (e) "AI ile düzelt" kutuyu kaybetmeden metni değiştiriyor mu,
      (f) taşma uyarısı çıkan belgede sonuç gerçekten taşıyor mu.
- [x] ~~Arka plana alınan iş için kalıcı gösterge yok~~ → **YAPILDI:** kalıcı
      alt şerit (iş adı + sayaç + Durdur), sayfa değişse de kalıyor.
- [x] ~~Taramada döndürme yok~~ → **YAPILDI:** önizlemede 90° çevirme.
- [ ] **Agresif sıkıştırma (resme çevirerek) YAPILMADI — yol kapalı.**
      Cihazda JPEG kodlayıcı yok (`dart:ui` yalnız PNG üretir) ve PNG taranmış
      sayfada özgün JPEG'den büyük çıkar → "sıkıştır" dosyayı şişirirdi.
      Gerekirse `image` paketi (yeni bağımlılık, yavaş) veya platform kanalı.
      Yapılırsa metin katmanı kaybolacağı için AYRI ve açıkça uyaran bir
      seçenek olmalı, sessizce değil.
- [ ] **Kırpılmış (CropBox'ı MediaBox'tan kaydırılmış) PDF'te vurgu/yerinde
      düzenleme koordinatı doğrulanmadı.** Syncfusion kutu ölçüsünü alırken
      köşe konumunu (c0/c1) atıyor; böyle bir dosya elimizde yok, ölçülemedi.
- [ ] **graphify güncellemesi:** araç bu ortamda kurulu değil; yeni düğümler
      (`pdf_reload`, `pdf_save`, `perspective`, `scan_edit/review`,
      `pdf_ai_edit`, `pdf_dict`, `pdf_font_metrics`, `pdf_edit_flow`,
      `pdf_inline_editor`, `ai_rewrite_sheet`) grafta eksik; silinen
      `pdf_text_replace_screen` hâlâ duruyor.
- [ ] **APK ~199 MB (build 123).** Bu iş ÖNCESİNDE de böyleydi (build 120:
      196 MB → build 123: 199 MB, artış yalnız yeni kod), yani bu turun
      getirdiği bir şişme değil. Ama "sade/hızlı" konumlandırma ve Play Store
      için fazla büyük. Muhtemel kaynaklar: tek APK'da tüm ABI'ler (pdfium +
      ML Kit + video/ses yerel kütüphaneleri), gömülü fontlar, WebView Word
      motoru. Yol: `--split-per-abi` ya da App Bundle (AAB) — indirilen boyut
      3-4 kat düşer. Release akışının değişmesi gerekir, ayrı iş.

- [ ] **Windows'ta kırık 4 test (yerel doğrulamayı köreltiyor).** CI Linux'ta
      geçiyorlar, ama yerelde `flutter test` hep kırmızı döndüğü için gerçek
      regresyonu gürültüden ayırmak zorlaşıyor (2026-07-28 turunda kök nedeni
      bulmadan önce baseline'ı stash'leyip ölçmek gerekti):
      `fm_archive_rar_test: volumePath` — test POSIX yol bekliyor, `p.join`
      Windows'ta `\` üretiyor (ya test platform-duyarlı olmalı ya `volumePath`
      POSIX ayracı sabitlemeli) · `şifreli arşiv … parolasız çıkarma` —
      tearDown temp klasörünü silemiyor, Windows dosya kilidi (koni bir kolu
      geç kapatıyor olabilir) · `fm_trash` iki testi Android birim mantığına
      dayanıyor.

- [ ] **Gizli satır/sütun kaydetmede kayboluyor (Excel sadakati).**
      `excel 4.0.6` yazma API'sinde `hidden` karşılığı yok: `<cols>` ve
      `sheetData` her kayıtta paketin kendi haritasından baştan üretiliyor
      (`save_file.dart` `_setColumns` / `_setRows`), `<col hidden="1">` ve
      `<row hidden="1">` hiç yazılmıyor. Genişlik/yükseklik kaybı
      `XlsxEditor._seedSizes` ile kapatıldı ama gizlilik kapatılamadı.
      Yol: `save()` sonrası zip'i açıp `xl/worksheets/*.xml` içindeki
      `<col>`/`<row>` düğümlerine `hidden` özniteliğini geri yazmak
      (bizim `layout.hiddenCols/hiddenRows` doğru veriyi tutuyor).
      Aynı yama satır özel biçimini (`s`+`customFormat`) da kurtarır.
- [ ] **Tamamen BOŞ satırın yüksekliği kaydedilmiyor.** Paket `<row>`u yalnız
      hücresi olan satır için yazıyor. Ekranda doğru, dosyada kayıp.
      Ucuz çözüm: yükseklik verilen boş satıra bir boş hücre yazmak.
