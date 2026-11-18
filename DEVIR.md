# DEVIR — faz-oto-B12-hiz2 (B12 Hız 2.0, bulut)

- Dilim: §1.12 madde 2 (açılış çözümlemesi izolatta) + yer kalırsa madde 4 (Image cacheWidth bekçisi).
- Madde 2 yazıldı (commit "B12 m.2"): kanıt+bekçi `test/open_parse_isolate_test.dart`
  (Stopwatch: sentetik 6000 paragraf docx / 3000×10 xlsx / 120 slayt pptx > 16 ms; statik mandal).
- Kök (kod kanıtı): ana izlekte kalan çözümlemeler —
  `file_service.dart` _loadLegacy (XlsLegacy.tryParse + toXlsxBytes, LegacyText.fromDoc/fromPpt),
  4 editörün `_restoreDraft`i (Word/Word mobil/Slayt/Excel), sesli kitap `DocChapters.load` (docx/pptx).
  Hepsi compute/openForView/_parseDeck ile izolata. ODF/EPUB uygulamada açılmıyor (ODT/ODS/ODP → harici).
- Kalan ana izlek: Word `_rerender` (resim ekle/sil sonrası) — madde 3 kapsamı, tavanda.
- Sıradaki: madde 4.
- Doğrulama: CI (yerel test yok).
