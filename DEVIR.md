# DEVIR — P08 (faz-oto-P08-bellek)
- Kök neden: `PdfEditSession.commitLive` (lib/services/pdf/pro/pdf_edit_session.dart) koşulsuz `_restored = true`
  → `needsReplay` her yerinde yazmadan sonra açık → `PdfEditSaver.encode` (pdf_edit_save.dart:97) her 30 sn
  geçici kayıtta ve Kaydet'te açılış baytlarından ikinci tam PDFium belgesi açıp komutları yeniden oynatıyordu.
  commitLive sayfayı anlık görüntüden GERİ KOYMAZ (sayfa nesnesi aynı); gizlenen özgünleri bitiş yazımı
  kaldırır, ara yazımların erişilemez artıklarını kırpma atar → canlı belgeden kayıt doğru.
- Düzeltme: commitLive'da `_restored = true` kaldırıldı (undo/redo/cancelLive'da kalır — orada sayfa değişiyor).
- Test: pdf_pro_live_edit_test "yerinde yazma…" → `needsReplay` false + kayıt metni == canlı metin.
- Doğrulama: CI. Cihaz A/B yürütücüde (ab-olcum): 50 sayfa rl_paragraflar×50, 3 yerinde yazma + Bitti,
  31 sn bekle (geçici kayıt), Kaydet; `dumpsys meminfo <pkt>.r8test` TOTAL PSS düzenleme sonu ve Kaydet sonrası,
  taban (önceki [apk] profil) vs aday, 2 tur ABBA. Bütçe +40 MB (oturuma girmeden önceki PSS'ten fark).
- Hâlâ aşarsa sıradaki aday: tuş başı prova (geçici sayfa kopyası) — HAFIZA 2026-11-13.
