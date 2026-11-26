# DEVIR — B16 internetsiz Arapça OCR (dal faz-oto-B16-ocr)
- Yapılan (dilim 1): `lib/services/arabic_ocr.dart` (indirme + det/rec + CTC + yön), `voice/neural_engine.dart` `infer`/`decodeTensor`,
  `voice/neural_voices.dart` (`fetchFiles`, `provide`/`GET in/`, JS `engine.infer`, ORT'yi OCR için tut), `ocr_service.dart`
  (`_forcedArabic`/`_autoArabic`, `hasArabicText`), ayar satırı indir/sil + ilerleme, lisans, çeviri `54_arabic_ocr.dart`.
- Kanıt: Python + onnxruntime prototipi (aynı modeller, aynı ön/son işlem) 3 satırlık Arapça görselde birebir doğru.
- Test: `test/arabic_ocr_test.dart` (sözlük, CTC, yön, kutu, tensör, sunucu girdisi).
- Doğrulanmadı: WebView'da ORT ana iş parçacığında çok iş parçacıklı çalışıyor mu (hipotez: evet, COOP/COEP var), hız/bellek.
- Sıradaki: cihaz turu (docs/CIHAZ_TESTI.md B16) → kalite kapısı m.4; yerel sonuç zayıfsa Gemini'ye sorarak geçiş; eğik kutu.
