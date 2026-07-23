# KALANLAR — canlı kalan-iş listesi (biten madde silinir)

## Yarım kalan
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

## Sonra yapılacak
- [ ] **PDF Faz 2 — Annotation (Syncfusion yazma)** — seçili metni vurgula. Notlar:
      `PdfSelectLayer` seçimi `_selStart/_selEnd` (fullText char indeksi) tutuyor;
      `_SelectionPainter` her fragment için `f.getBoundsForRange(start,end)` → **PdfRect
      (PDF puntosu)** üretiyor. Yeni: layer bu PdfRect listesini + sayfa no'yu yukarı
      raporlasın (onSelected'ı genişlet). Syncfusion helper (`services/pdf_annotator.dart`):
      `PdfDocument(inputBytes)` → `page.annotations.add(PdfTextMarkupAnnotation/
      PdfRectangleAnnotation)` → `save()`. **KOORDİNAT TUZAĞI:** pdfium PdfRect Y-up
      (bottom-left origin), Syncfusion annotation Y-down (top-left) → `top=ph - pdfRect.top`.
      Syncfusion annotation API'sini önce kontrol et (pub cache). Cihazda doğrula.
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
