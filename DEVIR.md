# DEVIR — B11 Slayt 2.0 (dal faz-oto-B11-slayt2)

Kaynak: PLAN.md §1.11. Dilim 1 = m.1 (tablo stili) + m.7 (sadakat bekçisi) + m.4 (imleç dokunulan yerde).

## Yapılanlar
- m.1 (kısmi) tablo stilleri: `pptx_render.dart` `_table` + `_tableStyle` — kök neden: çizici
  yalnız açık `a:tcPr` dolgusunu okuyordu (pptx_objects.addTable yorumu). Test:
  `pptx_render_test` "B11 m.1: tablo stili".
- m.7 sadakat bekçisi: `test/slides_roundtrip_test.dart` (SmartArt parçaları, gömülü yazı tipi,
  medya, customXml, p14 uzantısı; dokunmadan / metin düzenle / not + slayt sil).

- m.4 imleç dokunulan yerde: `slide_canvas` onTapUp → `onEditShape(s, at)` → `_beginEdit(.., at)` →
  `SlideBoxEditor.tapAt` → `RenderEditable.getPositionForPoint`. Test `slides_edit_test` "B11 m.4".
  Klavyede kayma: `showOnScreen` iç içe kaydırıcılarda zaten çalışmalı (hipotez, cihazda bak).

## Kalan
- m.1 piksel altın görüntü: yerel test yasak → altın PNG üretilemiyor; yapısal (model) altın
  testleriyle sürüyor. Stil kenarlıkları (`a:tcBdr`) okunmuyor.
- m.2 grafik türleri: B10 m.1 ortak çiziciye bağlı (B10 bulutta sürüyor) → B10 m.1'den sonra.
- m.3 geçiş/animasyon (plan fable), m.5 AI tasarımcı, m.6 notlar+prova,
  m.8 sürükleme bütçesi.

## Doğrulama
CI `verify` (yerel test yok). `gh run list -b faz-oto-B11-slayt2 -L 1`.
