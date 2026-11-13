# DEVİR — PDF Pro dekont/tablo satırı düzenleme (2026-11-13, yarım)

Dal: `faz-pdf-satir` (main'e GİRMEDİ — bench blok sayısı 523 → 534, nedeni bakılmadı).

## Yapılan (yerelde yeşil: `test/pdf_pro/pdf_pro_dekont_test.dart` ilk 2 test)
- Fikstür: `test/fixtures/pdf/dx_dekont.pdf` (uydurma; üretici `tool/pdf_corpus/make_dekont.py`, DevExpress taklidi).
- Boşluk ölçümü: `pdf_typeset.dart` `_probe` — boşluk artık "a␠a" yazılıp geri okunarak ölçülür.
- Blok algılama: `pdf_text_blocks.dart` `_lines` sonu (sekme durağı bölmesi) + `_paragraphs.tableRows`.

## Kök nedenler
1. **Boşluklar 1 em:** DevExpress alt kümesinde U+0020 yok (yalnız U+00A0); `FPDFFont_GetGlyphWidth`
   eşlenemeyen kodda CID 0 genişliğini (DW=1000) döndürüyor, glif boş → "boşluk" kabul (`pdf_typeset.dart:70-82`, eski hâl).
   Satır 1 em boşlukla taşıp sarılıyor → alt satırın üstüne biniyor.
2. **Satırlar tek blok:** `_continues` (`pdf_text_blocks.dart:~975`) uzun satır + altındaki kısa etiketi 2 satırlı
   paragraf sayıyor; `_lines` 1,6 em altı boşlukta etiket + ":" + değeri tek satır yapıyor.
3. "Bitti ≠ canlı" DOĞRULANMADI: ekran görüntülerinde canlı yazımda da boşluklar açık; ikisi aynı yol.
4. PDFium, nesneyi içeren tek dörtgen kırpmayı ayrıştırırken atar (`CheckClip`) → hücre bilgisi API'den okunamaz
   (`FPDFClipPath_CountPaths` = -1); kırpma tabanlı hücre algılama bu yüzden bırakıldı.

## Kalan
- Bench: hangi külliyat dosyalarında blok arttı (`build/pdf_pro_bench/pdfium-nesne.json` eski/yeni `pages` karşılaştır);
  sekme durağı / `tableRows` düzyazıyı bölüyorsa eşiği sıkılaştır; `baseline_pdfium.json` bekçisi CI'da.
- 3. test (kayıt + yeniden açma) yerelde koşmaz (path_provider) → CI'da bak. `pdf_edit_save_test` 3 testi temiz ağaçta da yerelde kırmızı.
- Yapılmadı: Kaydet varsayılanı "kopya" (öneri 3), HAFIZA/PDF_PRO_PLANI/CIHAZ_TESTI kayıtları, cihaz doğrulaması.
- Yerel test: `PATH=/c/Users/sena/vsshim:$PATH` + `C:\src\flutter-3479\bin\flutter.bat test test/pdf_pro/...`.
