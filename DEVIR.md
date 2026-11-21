# DEVIR — faz-oto-B10-excel4 (B10 Excel 2.0 kalanları)

Yapılanlar (her madde ayrı commit):
- m.2 Türkçe LAMBDA adları — b78fda16 (CI 44894231680 yeşil)
- m.5 süzgeç 2 — 13cef9f1 + 8c553e71 (analyze düzeltmesi)
- m.7 "Yalnız formülleri yapıştır" — 073fed38 (gerisi zaten vardı)
- m.1 chartex okuma + çizim — 7f42ac12
- m.8 ilk pencere ölçümü (perf kapısı) — ec26d2b2

Şu anki adım: m.8 düzeltmesi ölçüme bağlı.
Kök/kanıt: lib/services/xlsx/xlsx_stream.dart `read` → `_unpack(ss…)` ve
`_unpack(f…)` sayfa XML'ini tavan 800 iken de tümüyle açıyor.
Ölçüm: CI "Perf gerileme kapısı" özetinde `PERF xlsx_head_100k_ms=…
xlsx_stream_full_100k_ms=…` (test/large_file_test.dart "ilk pencere").
CI 44895645942 ham: xlsx_head_100k_ms=445 xlsx_stream_full_100k_ms=1669 file_kb=1741
(baş = tamın %27'si; 800 hücre için büyük → erken durma değer).
Sıradaki: baş/tam oranı yüksekse `_unpack` yerine `Inflate.lazy` +
`inflateBlock` ile blok blok aç, `_readSheet` tavanı dolunca dur → aynı
test; tavan `lessThan(3000)` ölçümle daraltılır (yalnız düşer).
Kalan (m.5): dosyadaki filterColumn ölçütlerini okuma; renk süzgeci dxf.
İşe yaramayan: —
Test: CI (dala push). Yerel test yok.
