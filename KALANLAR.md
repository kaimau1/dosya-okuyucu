# KALANLAR — canlı kalan-iş listesi (biten madde silinir)

## Yarım kalan
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
- [ ] **PDF gece modu (invert)** — `PdfViewer`'ı `ColorFiltered` invert matrisiyle sar,
      AppBar'da toggle (mevcut `_pdfSelectMode` düğmesi kalıbı). Salt görsel, düşük risk.
- [ ] **PDF link/köprü tıklama** — `PdfViewerParams.linkWidgetBuilder`; dış URL→url_launcher
      (pubspec'e ekle), iç hedef→`_pdfController.goToPage`.
- [ ] **PDF belge ana hattı (outline)** — `document.loadOutline()` + yan çekmece navigasyon.
- [ ] **PDF vurgu remount zoom kaybı** — `_pdfReloadKey++` remount'ta zoom/kaydırma sıfırlanır;
      `onViewerReady`'de son matris geri uygula.

## Sonra yapılacak
- [ ] **PDF Faz 3 — Sayfa düzenleme** — döndür/sil/sırala. Syncfusion `doc.pages[i].rotation`,
      `doc.pages.remove/reorder` → save → pdfrx'te reload. Küçük resim şeridi UI gerekebilir.
- [ ] **PDF Faz 4 — Form doldurma** — Syncfusion `PdfLoadedForm` alanları oku (`doc.form.fields`),
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
