# DEVIR — B15 Akıllı bütünlük (dal faz-oto-B15-akilli)

- Yapıldı (dilim 1, tek commit): budama (sohbet, özet, slayt AI kipi, alt çubuk "AI ile çalış",
  Benzerlerde Gemini/en iyi kare, AiTagger, hızlı/toplu kontrol, kontrol listesi) + "Akıllı …"
  adlandırma (tr/en/ar, 109 anahtar) + AI girişlerinde `AppIcons.ai` + `common.smart_failed`.
- Silinen ölü anahtar: 193 (HEAD'e göre yeni yetimler; betik mantığı HAFIZA 2026-11-19 B15).
- `quickCheckInput` → `lib/screens/fm/ai_actions.dart` (ikinci ad kullanıyor).
- Kategori araçları "AI ile kategorilere ayır" → toplu Akıllı ikinci ad (`giveAiAliasBatch`).
- Kasma-kontrol: yalnız kaldırma + ad/simge değişimi; yeni sarmalayıcı/animasyon yok (8 madde geçti).
- Doğrulama: CI. Yerelde test/analyze koşturulmadı.
- Sıradaki: CI yeşil → yürütücü birleştirir. Kalan (4) kategorizasyon mükemmelleştirme (ayrı dilim).
- Sabah bakılacak: Ayarlar "AI Kalıcı Hafıza" artık etkisiz; QuickAiSheet ("Akıllı sor") kaldı.
- Cihaz: docs/CIHAZ_TESTI.md "B15", PLAN C2 (ölçülmedi).
