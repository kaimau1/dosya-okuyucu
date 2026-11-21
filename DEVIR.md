# DEVIR — faz-oto-B10-acilis (B10 m.8 + m.5 artık)

Yapılanlar:
- 8af2d070 m.8: `xlsx_stream.dart` blok blok açma (`_bytes`/`_raw` + dart:io ZLibCodec raw), tavanda durur; sharedStrings tembel (`_Shared`).
- bd787c10 m.5 artık: `FileFilter` (auto_filter.dart) dosyadaki filterColumn okur → `XlsxSheet._loadFileFilters`; renk süzgeci `colorFilter` + dxf (`_colorFilterDxf`, save_patch). Test: excel_finish_ops_test "B10 m.5 artık".
- m.8 düzeltme: shared dizeler olay yığını başına liste (tam okuma gerilemesi), hazır indeks await'siz.
- analyze düzeltmesi (use_null_aware_elements).

Ölçüm (CI, large_file_test PERF):
- Önce (44895645942): head_100k=445 ms, full_100k=1669, stream_300k=1640.
- 1. sürüm (44897565553, yeşil): head=61, full=10331 (!), 300k=10154 → GERİLEME. Kök hipotez: dize başına duraklat/sürdür zinciri.
- 2. sürüm (44898131873): analyze kırmızı, PERF yok. 3. koşu 44898521629 sonucu BAKILMADI.

Sıradaki:
1. `gh run view 44898521629 --log | grep -o "PERF xlsx[^\"]*"` → full/300k ≤ önceki (1669/1640) mi? Değilse kök: zlib çıktı yığınları ya da sayfa olay akışı; gerekirse tam okumada (maxCells büyük) eski `_unpack` yolu.
2. Geçerse `large_file_test` `lessThan(3000)` → ölçüme göre daralt (ör. 1000).
3. PLAN.md B10 satırı + §1.10 m.8/m.5, HAFIZA tarihli kayıt (önce/sonra), DEVIR.md sil.
