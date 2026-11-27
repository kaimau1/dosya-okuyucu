# DEVIR — B18 Yer aç birleştirme + yeni görünüm (dal faz-oto-B18-yer-ac)

Yapılanlar (tek WIP commit, CI'a gönderilmedi, [skip ci]):
- similar_screen.dart: `picks` (Yer aç ile paylaşılan seçim), `startScan` (statik), `levelOf`, `without` (saf budama).
- chat_cleanup_screen.dart: `ChatJunkLive.start` (tarama ekrandan ayrıldı), `picks` → ChatJunkBucketScreen(picks) (paylaşılan seçimde clear yerine removeAll).
- cleanup_tools.dart: DeepScanCard yalnız içerik taraması; `startDeepScans` (benzer=Normal, Gevşek sonucu yenilenir; sohbet medyası), `openSimilarMedia(picks:)`.
- cleanup_advisor.dart: saf `deepCleanupSuggestions` (en iyi kare asla önerilmez, originals=en iyi kare, hızlı taramayla çift sayım yok) + `cleanupSeedSelection` (yalnız yeni/değişen öneri seçimi kurulur, küme kimliği korunur).
- cleanup_screen.dart: yeni görünüm — disk halkası + "Güvenle açılabilir" ana sayı + "İncelemeye değer" ikincil, ondalıklı "boş alan before → after (+delta)", tek satır güven notu, süzgeç ve "Güvenlileri temizle" kalktı, kompakt satırlar (ayrıntı dokununca), ListView.builder, kuyruk anahtarı ile dar yeniden çizim, _suggestions önbellekli, derin satırlar (similar/chat_media) + "taranıyor" satırları, _analyze sonunda startDeepScans.
- Çeviri: strings/55_yer_ac.dart (+app_strings part/_t55), id/ms ekleri.
- Testler güncellendi: cleanup_perfected (süzgeç/quick-safe kalktı, video satırı açılıyor), cleanup_birlesik (dup satırı açılıyor, clean-card-similar), cleanup_ux ('Güvenle açılabilir').

Kalan:
1. `PYTHONUTF8=1 python tool/on_denetim.py` → kırmızıysa düzelt.
2. Yeni saf test yaz: test/cleanup_deep_merge_test.dart (deepCleanupSuggestions: en iyi kare yok, originals, dedupe, cleanupTotal; cleanupSeedSelection: derin sonuç gelince seçim silinmez, İncele varsayılan seçilmez, küme kimliği aynı).
3. Kodu gözden geçir (derlenmedi!): cleanup_screen.dart build/_card/_details/_summaryBanner, prefer_const uyarıları, kullanılmayan import (AppColors? edition?).
4. Commit gövdesi Yeni:/İyileştirme:/Düzeltme: + Co-Authored-By; [skip ci] olmadan push, `gh run watch`, kırmızıysa 2 tur.
5. PLAN.md B18 satırı, HAFIZA.md tarihli karar, docs/CIHAZ_TESTI.md (Yer aç görünümü, derin satırlar, seçim geri yansıma, Normal kademe yanlış eşleşme, kuyruk sırası: derin tarama başka işleri bekletebilir).
