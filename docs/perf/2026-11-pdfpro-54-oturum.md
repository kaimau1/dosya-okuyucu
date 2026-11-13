# PDF Pro Faz 54 — oturum ölçümü (2026-11-11)

**Yöntem:** `test/pdf_pro/session_bench_test.dart`, CI (Linux, Flutter 3.47.9, **debug JIT** — cihaz DEĞİL),
koşu 43008088491. Külliyattan 8 belge (ReportLab, Word, Chrome, fpdf, Syncfusion, Dart `pdf`), belge başına
en çok 4 "aynı harflerle ilk↔son sözcük" düzenlemesi; süre = komut + o sayfanın 144 dpi çizimi.
Cihaz sayıları `docs/CIHAZ_TESTI.md` "PDF Pro Faz 54" / 11 ile ölçülecek.

| Ölçüm | Bütçe (§6, MatePad / hafif) | CI (debug JIT) | Cihaz |
|---|---|---|---|
| Uygula → güncel sayfa | p95 ≤ 250 / 400 ms | p50 14,0 · p95 58,8 ms (n=28) | **p50 30 · p95 46 ms** ✔ (n=34, komut; çizim hariç) ³ |
| Geri al → güncel sayfa | p95 ≤ 150 ms | p50 6,8 · p95 10,7 ms (n=28) | **p50 17 · p95 26 ms** ✔ (geri al, n=85) · yinele p50 6 · p95 24 ✔ ³ |
| Artımlı kayıt, 50 sayfa | ≤ 500 ms | **bekliyor** — tezgâhın 51 sayfalık belgesi (`rl_cok_sayfa` ×17, Syncfusion birleştirme) üzerinde hiçbir düzenleme uygulanamadı (köprü reddetti); kayıt süresi ölçülemedi | **p50 179 · p95 212 ms** ✔ (n=6, 50 sayfa, tek üreticili `rl_paragraflar` ×50) ³ |
| Oturum ek belleği | ≤ +40 MB | koşu boyunca RSS tepe +52,4 MB — 8 belge art arda, çizim önbelleği ve Dart yığını dahil; tek oturumun payı ayrıştırılmadı → bütçe için **bekliyor** | **+56 / +65 MB** ✘ (3 paragraf düzenlemesi, 2 koşu; kipe girişte +9 / +10 MB)² |
| Düzenleme kipine geçiş | ≤ 150 / 250 ms | ölçülmedi (görüntüleyici widget tezgâhı yok) | **p50 45 · p95 47 ms** ✔ (n=6) ³ |
| Boşta (düzenleme kipinde) | 0 kare | ölçülmedi | **0 kare** ✔ (10 sn × 3, `dumpsys gfxinfo`) |

**Cihaz (2026-11-13, Mi Note 10 Lite, yerel profil `.r8test` derlemesi, pil 36–38 °C, `rl_paragraflar.pdf`):**
¹ uygulamada düzenleme zaman damgası yok; ekran kaydı/adb ile güvenilir ms çıkmıyor → `PDFPRO_PERF` logu eklenince
ölçülecek (KALANLAR). ² `dumpsys meminfo` TOTAL PSS, okuma kipi → 3 düzenleme sonrası; ilk koşu atıldı, bir koşu
kurtarma penceresi yüzünden geçersiz. Yedek yazı tipi + sayfa anlık görüntüleri dahil; bütçe aşımı KALANLAR'da.

**Doğrulanan (test, sayı değil):** geri alınan sayfa özgünle piksel piksel aynı; artımlı kayıtta özgün baytlar
başta aynen; ikinci kayıt birincinin üstüne ek biriktirmiyor; geri alma içeren oturumun kaydı yeniden
oynatmayla doğru.

**Açık:** (1) 50 sayfa kaydı — birleştirilmiş belgede köprünün neden reddettiği incelenmedi; gerçek 50
sayfalık külliyat belgesi (tek üreticiden) eklenip yeniden ölçülmeli. (2) Bellek tek oturum için ayrı ölçülmeli
(cihazda `dumpsys meminfo`). (3) Geri alma sonrası kayıt (yeniden oynatma) süresi ayrıca ölçülmedi.

**Cihaz, `PDFPRO_PERF` (2026-11-13, Mi Note 10 Lite, `.r8test` profil, pil 30–37 °C):** ³ 50 sayfalık belge
(`rl_paragraflar` ×50, PyMuPDF ile birleştirildi), koşu başına 3 tur (yerinde yaz + Bitti, 2× geri al/yinele, Sil+geri al,
Çoğalt+geri al) + Kaydet; ilk koşu atıldı, 2 koşu normal + 2 koşu geçici kayıt kapalı toplandı (n birleşik).
`tus` p50 31 · p95 67 ms (n=46). Hepsi §6 bütçesi içinde (MatePad/hafif sınırları). Oturum belleği A/B
(`dumpsys meminfo` TOTAL PSS, 50 sayfa, düzenleme sonu, Kaydet'ten önce; mutlak, taban çıkarılmadı):
normal (30 sn kayıt) 400 / 337 MB · geçici kayıt kapalı (`SNAP=100000`) 368 / 363 MB → fark gürültü içinde;
geçici kaydın bellek payı belirgin değil.
