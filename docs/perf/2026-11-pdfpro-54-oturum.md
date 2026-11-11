# PDF Pro Faz 54 — oturum ölçümü (2026-11-11)

**Yöntem:** `test/pdf_pro/session_bench_test.dart`, CI (Linux, Flutter 3.47.9, **debug JIT** — cihaz DEĞİL),
koşu 43008088491. Külliyattan 8 belge (ReportLab, Word, Chrome, fpdf, Syncfusion, Dart `pdf`), belge başına
en çok 4 "aynı harflerle ilk↔son sözcük" düzenlemesi; süre = komut + o sayfanın 144 dpi çizimi.
Cihaz sayıları `docs/CIHAZ_TESTI.md` "PDF Pro Faz 54" / 11 ile ölçülecek.

| Ölçüm | Bütçe (§6, MatePad / hafif) | CI (debug JIT) | Cihaz |
|---|---|---|---|
| Uygula → güncel sayfa | p95 ≤ 250 / 400 ms | p50 14,0 · p95 58,8 ms (n=28) | bekliyor |
| Geri al → güncel sayfa | p95 ≤ 150 ms | p50 6,8 · p95 10,7 ms (n=28) | bekliyor |
| Artımlı kayıt, 50 sayfa | ≤ 500 ms | **bekliyor** — tezgâhın 51 sayfalık belgesi (`rl_cok_sayfa` ×17, Syncfusion birleştirme) üzerinde hiçbir düzenleme uygulanamadı (köprü reddetti); kayıt süresi ölçülemedi | bekliyor |
| Oturum ek belleği | ≤ +40 MB | koşu boyunca RSS tepe +52,4 MB — 8 belge art arda, çizim önbelleği ve Dart yığını dahil; tek oturumun payı ayrıştırılmadı → bütçe için **bekliyor** | bekliyor |
| Düzenleme kipine geçiş | ≤ 150 / 250 ms | ölçülmedi (görüntüleyici widget tezgâhı yok) | bekliyor |
| Boşta (düzenleme kipinde) | 0 kare | ölçülmedi | bekliyor |

**Doğrulanan (test, sayı değil):** geri alınan sayfa özgünle piksel piksel aynı; artımlı kayıtta özgün baytlar
başta aynen; ikinci kayıt birincinin üstüne ek biriktirmiyor; geri alma içeren oturumun kaydı yeniden
oynatmayla doğru.

**Açık:** (1) 50 sayfa kaydı — birleştirilmiş belgede köprünün neden reddettiği incelenmedi; gerçek 50
sayfalık külliyat belgesi (tek üreticiden) eklenip yeniden ölçülmeli. (2) Bellek tek oturum için ayrı ölçülmeli
(cihazda `dumpsys meminfo`). (3) Geri alma sonrası kayıt (yeniden oynatma) süresi ayrıca ölçülmedi.
