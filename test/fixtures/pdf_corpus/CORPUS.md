# PDF Pro külliyatı (Faz 51)

Üretici: `tool/pdf_corpus/make_corpus.py` + `tool/pdf_corpus/dart_corpus_test.dart`.
Metinler UYDURMA (`tool/pdf_corpus/metin.py`) — kişisel/hasta verisi yok (KVKK).
Her dosya ≤ 300 KB. *Beklenen paragraf* = başlık + gövde paragrafı + liste maddesi + tablo hücresi.
Ölçüm: `test/pdf_pro/bench_test.dart` (rapor: `docs/perf/2026-11-pdfpro-51-taban.md`).

| Dosya | Üretici | Özellikler | Sayfa | Beklenen paragraf | Boyut |
|---|---|---|---|---|---|
| `ch_arapca.pdf` | Chrome/Skia | arapca, rtl, karma-yon | 1 | 7 | 46 KB |
| `ch_basliklar.pdf` | Chrome/Skia | baslik-hiyerarsisi, karma-bicim | 1 | 8 | 22 KB |
| `ch_cok_sayfa.pdf` | Chrome/Skia | cok-sayfa | 2 | 13 | 29 KB |
| `ch_dondurulmus.pdf` | Chrome/Skia | dondurulmus-metin, dikey-metin | 1 | 4 | 14 KB |
| `ch_iki_sutun.pdf` | Chrome/Skia | iki-sutun | 1 | 9 | 22 KB |
| `ch_iki_yana.pdf` | Chrome/Skia | iki-yana | 1 | 6 | 22 KB |
| `ch_karma_logo.pdf` | Chrome/Skia | logo+metin, PS2-benzeri | 1 | 5 | 23 KB |
| `ch_liste.pdf` | Chrome/Skia | madde-listesi, numarali-liste | 1 | 10 | 22 KB |
| `ch_objstm.pdf` | Chrome/Skia + qpdf | nesne-akisi-ObjStm, xref-akisi | 1 | 7 | 17 KB |
| `ch_paragraflar.pdf` | Chrome/Skia | web-font, carlito | 1 | 7 | 20 KB |
| `ch_sistem_serif.pdf` | Chrome/Skia | sistem-fontu, times | 1 | 5 | 49 KB |
| `ch_tablo.pdf` | Chrome/Skia | tablo | 1 | 25 | 24 KB |
| `dp_iki_yana.pdf` | pdf (Dart) | iki-yana | 1 | 5 | 9 KB |
| `dp_liste.pdf` | pdf (Dart) | madde-listesi | 1 | 6 | 8 KB |
| `dp_paragraflar.pdf` | pdf (Dart) | ttf-alt-kume, carlito | 1 | 6 | 9 KB |
| `dp_tablo.pdf` | pdf (Dart) | tablo | 1 | 13 | 8 KB |
| `fp_core_font.pdf` | fpdf2 | standart-14-font, latin1 | 1 | 4 | 1 KB |
| `fp_iki_yana.pdf` | fpdf2 | iki-yana | 1 | 6 | 19 KB |
| `fp_karma_logo.pdf` | fpdf2 | logo+metin, PS2-benzeri | 1 | 5 | 22 KB |
| `fp_liste.pdf` | fpdf2 | madde-listesi | 1 | 7 | 18 KB |
| `fp_paragraflar.pdf` | fpdf2 | ttf-alt-kume, arimo | 1 | 6 | 20 KB |
| `fp_tablo.pdf` | fpdf2 | tablo | 1 | 29 | 20 KB |
| `mpl_grafik.pdf` | matplotlib | type3, grafik-etiketleri | 1 | 3 | 13 KB |
| `mpl_type3.pdf` | matplotlib | type3, dejavu | 1 | 7 | 17 KB |
| `mpl_type42.pdf` | matplotlib | type42, dejavu | 1 | 7 | 15 KB |
| `mu_dondurulmus.pdf` | PyMuPDF | dondurulmus-metin-90-180 | 1 | 3 | 18 KB |
| `mu_form.pdf` | PyMuPDF | acroform | 1 | 4 | 30 KB |
| `mu_taranmis.pdf` | PyMuPDF | taranmis, metin-katmani-yok | 1 | 0 | 71 KB |
| `mu_taranmis_ocr.pdf` | PyMuPDF | taranmis, gorunmez-ocr-katmani | 1 | 8 | 90 KB |
| `mu_textbox.pdf` | PyMuPDF | insert_textbox | 1 | 4 | 22 KB |
| `rl_artimli.pdf` | ReportLab + qpdf | yeniden-yazilmis | 1 | 7 | 35 KB |
| `rl_base14.pdf` | ReportLab | standart-14-font, gomulu-degil | 1 | 3 | 1 KB |
| `rl_cok_sayfa.pdf` | ReportLab | cok-sayfa | 3 | 15 | 38 KB |
| `rl_dondurulmus_metin.pdf` | ReportLab | dondurulmus-metin-30, dikey-metin | 1 | 5 | 18 KB |
| `rl_dondurulmus_sayfa.pdf` | ReportLab | sayfa-rotate-90 | 1 | 4 | 18 KB |
| `rl_iki_sutun.pdf` | ReportLab | iki-sutun, iki-yana | 1 | 9 | 35 KB |
| `rl_iki_yana.pdf` | ReportLab | iki-yana, tinos | 1 | 6 | 34 KB |
| `rl_karma_logo.pdf` | ReportLab | logo+metin, PS2-benzeri | 1 | 5 | 38 KB |
| `rl_kucuk_punto.pdf` | ReportLab | 8pt | 1 | 5 | 19 KB |
| `rl_liste.pdf` | ReportLab | madde-listesi | 1 | 6 | 34 KB |
| `rl_numarali.pdf` | ReportLab | numarali-liste | 1 | 6 | 34 KB |
| `rl_paragraflar.pdf` | ReportLab | ttf-alt-kume, carlito | 1 | 7 | 35 KB |
| `rl_sifreli.pdf` | ReportLab | sifreli-sahip-parolasi | 1 | 5 | 36 KB |
| `rl_tablo.pdf` | ReportLab | tablo | 1 | 26 | 35 KB |
| `rl_yatay.pdf` | ReportLab | yatay-sayfa | 1 | 5 | 35 KB |
| `sf_form.pdf` | Syncfusion | acroform | 1 | 3 | 13 KB |
| `sf_iki_yana.pdf` | Syncfusion | iki-yana, tinos | 1 | 5 | 22 KB |
| `sf_paragraflar.pdf` | Syncfusion | ttf, carlito | 1 | 6 | 23 KB |
| `sf_sifreli.pdf` | Syncfusion | sifreli-sahip-parolasi | 1 | 4 | 23 KB |
| `sf_tablo.pdf` | Syncfusion | tablo | 1 | 12 | 12 KB |
| `wd_arapca.pdf` | Microsoft Word | arapca, rtl, karma-yon | 1 | 7 | 242 KB |
| `wd_arial.pdf` | Microsoft Word | arial | 1 | 6 | 61 KB |
| `wd_basliklar.pdf` | Microsoft Word | baslik-stilleri, renkli-baslik | 1 | 9 | 112 KB |
| `wd_cok_sayfa.pdf` | Microsoft Word | cok-sayfa | 4 | 13 | 168 KB |
| `wd_dipnot.pdf` | Microsoft Word | dipnot, ust-simge | 1 | 7 | 163 KB |
| `wd_iki_sutun.pdf` | Microsoft Word | iki-sutun | 2 | 9 | 163 KB |
| `wd_iki_yana.pdf` | Microsoft Word | iki-yana | 1 | 6 | 164 KB |
| `wd_karisik_bicim.pdf` | Microsoft Word | kalin-italik-renk-karisik | 1 | 5 | 250 KB |
| `wd_madde.pdf` | Microsoft Word | madde-listesi | 1 | 6 | 175 KB |
| `wd_mektup_logo.pdf` | Microsoft Word | logo+metin, PS2-birebir, calibri, iki-yana | 1 | 6 | 165 KB |
| `wd_numarali.pdf` | Microsoft Word | numarali-liste | 1 | 6 | 172 KB |
| `wd_ortali.pdf` | Microsoft Word | ortali | 1 | 5 | 156 KB |
| `wd_paragraflar.pdf` | Microsoft Word | calibri, alt-kume | 2 | 7 | 163 KB |
| `wd_sifreli.pdf` | Microsoft Word + qpdf (AES-256) | sifreli-sahip-parolasi, aes256 | 2 | 7 | 161 KB |
| `wd_tablo.pdf` | Microsoft Word | tablo | 1 | 26 | 174 KB |
| `wd_times.pdf` | Microsoft Word | times-new-roman | 1 | 6 | 65 KB |
| `wd_ust_alt_bilgi.pdf` | Microsoft Word | ust-bilgi, alt-bilgi, sayfa-no | 1 | 7 | 162 KB |
| `wd_yatay.pdf` | Microsoft Word | yatay-sayfa | 1 | 5 | 162 KB |

**Toplam:** 68 PDF · 8 üretici: Chrome/Skia, Microsoft Word, PyMuPDF, ReportLab, Syncfusion, fpdf2, matplotlib, pdf (Dart).

**Eksik üreticiler (bu makinede yok):** LibreOffice, Google Docs, LaTeX (pdfTeX/XeTeX), Quartz (macOS). Bkz. `KALANLAR.md` 👤.
