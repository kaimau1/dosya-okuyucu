# DEVIR — B2 Akıllı düzen 2.0 kullanım, dilim 4 (dal faz-oto-B2-duzen-kullanim)

Dilim 1–3 main'de (main bu dala birleştirildi, 2026-11-19). Dilim 4 = Decisions'ın kalanları:
- [x] m.4a tarama sonrası AI kalite: `ScanAiQuality` (`services/scan_quality.dart`, 3 noul soru →
  `ai_glare/ai_cut/ai_illegible`), ⋮ "AI ile kalite kontrolü" (`scan_result/actions.dart`
  `_aiQualityCheck`), şerit `_qualityHint` AI önerisini önce gösterir. Test `scan_ai_quality_test`.
  Metinler `strings/45_decision_uses.dart` (`_t45`).
- [x] m.4b akıllı temizlik: greeting/blurry kovası satırında AI düğmesi (`smart_cleanup_screen`
  `_aiVerify`, en çok 20 görsel, 512 px önizleme, kapsam kuralı); `SmartAnalysis.verifyQuestion/
  dropRejected` (P<0.3 düşer). Test `smart_analysis_ai_verify_test`.
DURDU: haftalık limit %91 (yürütücü). Kalanlara kod yazılmadı.
- [ ] m.4c sohbet yönlendirici (plan: `AiTaskModels.resolve(preferShort:)` shortOnly satırları öne;
  `PooledGemini.chat` öncesi yalnız katalogda Gemma varsa + elle seçim yoksa Decisions noul "basit
  soru mu", son kullanıcı mesajı ≤400 krk, `.timeout(1500ms)`, hata → normal zincir): basit soru (Decisions noul) → Gemma (kısa iş zinciri) önce
- [ ] m.4d galeri kategori süzgeci: Fotoğraflar'da `FmQuickFilters` AI kategori hapı ZATEN VAR
  (fm_quick_filters.dart smartcat-pill); eksik = hassas kategori (kimlik/sağlık/banka/vergi) PIN kilidi.

## Doğrulama
CI `verify` (yerel test yok). Cihaz: `docs/CIHAZ_TESTI.md` B2 dilim 4.
