# DEVIR — B2 Akıllı düzen 2.0 kullanım, dilim 4 (dal faz-oto-B2-duzen-kullanim)

Dilim 1–3 main'de (main bu dala birleştirildi, 2026-11-19). Dilim 4 = Decisions'ın kalanları:
- [x] m.4a tarama sonrası AI kalite: `ScanAiQuality` (`services/scan_quality.dart`, 3 noul soru →
  `ai_glare/ai_cut/ai_illegible`), ⋮ "AI ile kalite kontrolü" (`scan_result/actions.dart`
  `_aiQualityCheck`), şerit `_qualityHint` AI önerisini önce gösterir. Test `scan_ai_quality_test`.
  Metinler `strings/45_decision_uses.dart` (`_t45`).
- [ ] m.4b akıllı temizlik: greeting/blurry kovası "AI ile doğrula" (yanlış eşleşmeyi listeden çıkar)
- [ ] m.4c sohbet yönlendirici: basit soru (Decisions noul) → Gemma (kısa iş zinciri) önce
- [ ] m.4d galeri kategori süzgeci: Fotoğraflar'da `FmQuickFilters` AI kategori hapı ZATEN VAR
  (fm_quick_filters.dart smartcat-pill); eksik = hassas kategori (kimlik/sağlık/banka/vergi) PIN kilidi.

## Doğrulama
CI `verify` (yerel test yok). Cihaz: `docs/CIHAZ_TESTI.md` B2 dilim 4.
