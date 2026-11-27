# DEVIR — faz-oto-B4-p22b (P22b düzeltme)
- Yapılan: P22b (tutamaç önizlemesi + "N. sayfaya dön" hapı) — 29de589e; ilk A/B KALDI (docs/perf/2026-11-27-P22b-ab.md, `acilis_belge` +50–60 ms).
- Şimdi: düzeltme — hap ilk atlamaya dek ağaçta yok (`_pdfBackArmed`, body.dart ~473, pdf_navigation.dart `_markPdfBack`); önizleme Stack'i yalnız sürüklerken (pdf_inset_scroll_thumb.dart).
- Kök neden kanıtı: damga öncesi P22b kod yolu YOK (hap `_pageCount>0` = onViewerReady sonrası; thumb `!isReady` → SizedBox). Fark büyük olasılıkla damga gürültüsü (HAFIZA R3 (a)). Ayrıntı HAFIZA 2026-11-27 "P22b düzeltme".
- Sıradaki: cihazda yeniden A/B (ab-olcum, 4+4 ABBA; karar `acilis_ilk_sayfa` + kareler). Geçerse yürütücü birleştirir.
- Ölçüm: `tool/ab_olcum.sh` (A = main, B = bu dal ucu).
