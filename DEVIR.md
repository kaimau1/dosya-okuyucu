# DEVIR — B13 Deneyim hissi (dal faz-oto-B13-his)

## Yapılanlar (dilim 1)
- m.3 dokunuş haritası (713177dd): AppHaptics.longPress/drop/warning; bekçi app_haptics_test.
- m.5 geri al (b6f18163): trashWithUndo ortak uç; Önemli kategori silme çöp + Geri al (eskiden kalıcı); kategori adlandırma Geri al. Bekçi test/undo_paths_guard_test.dart.
- m.8 klavye (e35534cc): DocxEditorView didChangeMetrics → imleç görünür; test word_mobile_format_test "klavye açılınca alttaki imleç satırı görünür kalır".
- Analiz düzeltmesi (46ec0b51).
- m.2 (H6.6), m.6 (Faz 20 ED2), m.9 (Faz 16 a11y_guidelines_test) önceden yapılmış — iş yok.

## Kalan (dilim 2)
- m.1 Office/PDF açılış geçişi (H1.4 cihaz ölçümüne bağlı; PDF kabuğu başka dalda ölçülüyor).
- m.4 Excel/Slayt aşamalı açılış (Word B9 m.8'de yapıldı).
- m.7 Word/Excel/Slayt çimdik + çift dokunuş eşitliği.

## Doğrulama
CI verify (yerel test yok). Cihaz maddeleri docs/CIHAZ_TESTI.md "B13 his turu" + PLAN C3.
