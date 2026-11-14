# DEVIR — P12 Excel hızı (dal faz-oto-P12-excel)

Kök neden (B3.3a, kodla): dosya yöneticisinden xlsx açılışı kitabı İKİ KEZ ayrıştırıyordu —
`EntryOpener.open` → `FileService.load` → `_loadSpreadsheet` → izolatta `XlsxReader.read` + 200 bin
hücrelik tablo + düz metin (lib/services/file_service.dart `_decodeSpreadsheet`), sonra ekran
`_load` → `compute(_readAndParse)` aynı dosyayı yeniden okuyup ayrıştırıyor (spreadsheet/edit_ops.dart).
Editör o metni yalnız AI/çeviri düğmesinde kullanıyor.

Yapılanlar:
1. `FileService.load(spreadsheetText: false)` + EntryOpener bunu kullanır; editör metni istenince
   modelden kurar (`_docText`). Kanıt: test/perf/excel_perf_test.dart `PERF excel_reader_10k_x20_ms …
   open_old_ms … open_new_ms` (CI debug, aynı koşuda eski/yeni yol).
2. A/B senaryosu `xlsx_10k_x20_acilis` / `xlsx_10k_x20_kaydirma` (integration_test/perf_senaryolari_test.dart,
   gerçek `EntryOpener.open`, dokunuş→ilk SheetCell), logcat `OFIS_PERF faz=acilis_xlsx_10k_x20 ms=`;
   ab_karar.py regex + ab_olcum.sh grep/veri; make_test_tree.py `tablo_10k_x20.xlsx`.
3. B3.4: test/pinch_zoom_area_test.dart (kaydırma sürerken pinch).

Telefon: başka ajan ab_olcum koşturuyordu → kullanılmadı. Cihaz sayısı YOK.
CI sayıları: (bekliyor)
Sıradaki: CI sonucu → sayıları yaz; okuyucu (XlsxReader) baskınsa ayrı madde.
