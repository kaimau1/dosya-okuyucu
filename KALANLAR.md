# KALANLAR — canlı kalan-iş listesi (biten madde silinir)

## Yarım kalan
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
- [ ] Excel: dondurulmuş bölme (frozen pane) desteği — kullanıcının SAHU dosyasında var,
      şu an yok sayılıyor (tek parça kaydırma)
- [ ] Yol haritası #2: Firebase config + gerçek senkron (kullanıcı `flutterfire configure`)

## Bilinen eksik-risk
- [ ] Word canlı düzenleme: paragraf eşlemesi indeks tabanlı (DOM `article p` ↔ `w:p`);
      sayı uyuşmazsa sigorta düzenlemeyi kapatıp metin düzenleyiciye yönlendirir.
      Metin kutusu/köprü içeren belgelerde cihazda doğrulanmalı (2026-07-22)
- [ ] Excel pinch: kaydırma sürerken başlayan pinch ilk denemede tutmayabilir
      (ilk parmağın sahipliği scrollable'da kalır); cihazda rahatsız ederse iyileştirilecek
- [ ] Word'de zoom % rozeti yok (native WebView zoom ölçeği Flutter'a bildirmiyor);
      istenirse visualViewport JS köprüsü
- [ ] Koyu temada Word WebView kanvası açık kalıyor (sayfa zaten beyaz; bilinçli erteleme)

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

## PDF turu sonrası kalanlar (2026-07-26)
- [ ] **Cihaz doğrulaması bekliyor:** vurgulama (artık görünmeli), uzun basışla
      metin seçimi, 2/4 sütun düzeni, kaydırma çubuğu, taramada köşe ayarı.
      Bunların hiçbiri birim testle doğrulanamaz (pdfium render + dokunma).
- [ ] **AI düzenleme sayfa düzenini korumuyor** (bilinçli — bkz. HAFIZA
      2026-07-26 §8). "Yerinde metin düzenleme" istenirse gömülü font alt
      kümesi + satır kırımı yeniden kurma işi; ayrı ve büyük bir faz.
- [ ] **Vurgu koordinatı sayfa /Rotate=0 varsayıyor** (`PdfAnnotator`).
      Döndürülmüş sayfada vurgu kayabilir; `stampTransform` benzeri bir köprü
      gerekir.
- [ ] **Sıkıştırma hâlâ yalnız akış sıkıştırması** — taranmış PDF'te kazanç
      küçük. Agresif mod (sayfaları bitmap'e render + JPEG) ayrı seçenek olarak
      sunulmalı, sessizce yapılmamalı (metin katmanı kaybolur).
- [ ] **Arka plana alınan iş için kalıcı gösterge yok** — "Arka plana al"
      dendikten sonra işin sürdüğü yalnız bitince anlaşılıyor; kalıcı bir
      alt bilgi çubuğu/bildirim iyi olurdu.
- [ ] **Taramada döndürme yok** — köşe ayarı var ama 90° çevirme yok
      (ML Kit çoğu zaman doğru yönlendiriyor).
- [ ] **graphify güncellemesi:** bu turun yeni düğümleri (`pdf_reload`,
      `pdf_save`, `perspective`, `scan_edit/review`, `pdf_ai_edit`) grafta yok.
