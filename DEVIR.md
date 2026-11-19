# DEVIR — B11 Slayt 2.0 dilim 2 (dal faz-oto-B11-slayt2)

- main birleştirildi (f655eede üstüne, çakışmasız).
- m.6 notlar + prova: not yazma (outline.dart _NotesEditor) ve sunucu görünümünde büyük not
  (slideshow/presenter.dart) ZATEN vardı. Eksik olan: anlatımsız prova. Eklendi:
  `SlideshowScreen(rehearse: true)` (advTm ilerletmez, slayt başı süre toplanır, çıkışta
  Map<deckIndex,ms>), sunucu panelinde "Bu slayt: mm:ss", menü "Prova (süreleri kaydet)" →
  `PptxMediaOps.setTimings` (advTm). Testler: slideshow_test (prova), slides_pro_test (B11 m.6).
- m.8 (commit sonrası): slide_canvas.dart _canvas — seçili çerçevenin altı/üstü iki
  RepaintBoundary katmanı. Kanıt: slides_perf_test debugOnProfilePaint ile sürüklemede boyanan
  'Madde' metni = 0; tavan 250→130 (CI 107); slideshow_test geçiş karesi SlideCanvas 0.
- Sıradaki: CI sonucu; sığarsa m.5 AI tasarımcı.
- Dokunulmayan: m.2 (B10 m.1 bekliyor), m.3 (fable planı).
