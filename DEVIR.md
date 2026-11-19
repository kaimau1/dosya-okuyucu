# DEVIR — B2 Akıllı düzen 2.0 kullanım, dilim 3 (dal faz-oto-B2-duzen-kullanim)

Dilim 1+2 main'de. Dilim 3 (yerel, 2026-11-19):
- Kontrol listeleri (b7101e66): `services/fm/checklists.dart` (hazır 5 liste + `ckl_lists`
  kayıt, `questions/evaluate/report` saf), `screens/fm/ai_checklist.dart` levhası; giriş:
  girdi menüsü (dosya + klasör, klasörde doğrudan içi) ve seçim çubuğu `ai_checklist`.
  Dosya başına tek Decisions isteği (bütün maddeler), madde = en yüksek P(evet).
  PDF rapor: `ConversionService.textToPdf` (Carlito) → `shareEntries`. Test `checklists_test`.
- WhatsApp iletilen kopyaları (47f2dca8): `SmartSort.waCopiesOf` (WhatsApp klasörü +
  aynı bayt boyutu, en eskisi kalır), `reasonOf` → Ayıkla nedeni `wa_copy`. Test `smart_wa_copies_test`.
- Ayıkla AI puanı (21c4f7dc): `SimilarScreen._aiScore` score sorusu (netlik/gözler/kadraj),
  `SimilarFinder.orderByAi` (saf, test `similar_best_frame_test`).
- Boş imza alanı sorusu (915aab0f): `quickCheckPresets` `sign_empty` (toplu kontrolde süzgeç).
- Metinler: `strings/44_checklist.dart` (`_t44`).

## Kalan (sığmadı)
Decisions: tarayıcı sonrası sayfa kalitesi, akıllı temizlik bulanık/selamlaşma doğrulama,
sohbet yönlendirici (ucuz model), galeri kategori süzgeci.

## Doğrulama
CI `verify` (yerel test yok). Cihaz: `docs/CIHAZ_TESTI.md` B2 dilim 3.
