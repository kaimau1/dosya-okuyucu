# R3 (b) Word menü — aynı oturum tabanı (A' `4b2bec2` ↔ main `02c2ee5e`, word_300, 3A+3B ABBA, Huawei DBY-W09)

**Soru:** `word_300_menu` build p90/p99 gerilemesi aynı oturumda da var mı?
**Cevap: YOK (build).** Koşu başı menü build p90 / p99 (ms): A' = 3.4/13.1 (1.), 9.3/34.7 (4.), 5.1/19.3 (5.); B = 6.5/17.3 (2.), 3.2/13.2 (3.), 8.0/50.7 (6.). Ortanca p90 5.1→6.5 (+30 %), p99 19.3→17.3 (-10 %); koşular arası yayılım (3–9 / 13–51) farktan büyük = gürültü tabanı. Ağır kare dağılımı çıkarılmadı (build'de gerileme olmadığı için gerekmedi).
**Raster (gözlem):** menü raster p90 13.3→17.4 (+31 %), p99 15.7→19.7 (+25 %), ≈ +3–4 ms, p99 < 24 ms; B'de kare sayısı da biraz düşük (92–138 vs 154–163). Hafif ama yönlü; build'den bağımsız, ayrıca izlenmeli. `word_mobil_kaydirma_pro0/1` raster p90 +71/+65 % (7.7→13.2) — kaydırma p99 ok (+8 %), menü dışı; menü yamasıyla ilgisi doğrulanmadı.

# A/B ölçümü — 2026-11-27 (Mi Note 10 Lite, `tool/ab_olcum.sh`)

## A/B — A `4b2bec2` × 3, B `02c2ee5` × 3

Kare ölçüleri ms (`flutter drive --profile`); `acilis_*#n` = PDFPRO_PERF açılış damgası ms (#1 belge_100, #2 büyük PDF).

| senaryo | ölçü | A ortanca | A en kötü | B ortanca | fark % | durum |
|---|---|---|---|---|---|---|
| soguk_acilis | build p90 | 0.7 | 0.9 | 0.8 | +8 | ok |
| soguk_acilis | build p99 | 1.2 | 1.2 | 1.0 | -12 | ok |
| soguk_acilis | raster p90 | 3.8 | 4.2 | 4.5 | +18 | ok |
| soguk_acilis | raster p99 | 5.0 | 5.1 | 5.1 | +1 | ok |
| word_300_acilis | build p90 | 0.6 | 0.6 | 0.6 | -0 | ok |
| word_300_acilis | build p99 | 28.2 | 28.9 | 2.8 | -90 | ok |
| word_300_acilis | raster p90 | 8.5 | 8.7 | 9.6 | +13 | ok |
| word_300_acilis | raster p99 | 9.4 | 9.6 | 11.0 | +17 | ok |
| word_300_kapanis | build p90 | 1.6 | 3.1 | 1.6 | +1 | ok |
| word_300_kapanis | build p99 | 3.4 | 5.4 | 4.6 | +36 | ok |
| word_300_kapanis | raster p90 | 7.9 | 8.6 | 9.4 | +19 | ok |
| word_300_kapanis | raster p99 | 12.2 | 13.4 | 12.7 | +4 | ok |
| word_300_kaydirma | build p90 | 0.6 | 0.6 | 0.7 | +14 | ok |
| word_300_kaydirma | build p99 | 0.8 | 0.8 | 1.0 | +24 | ok |
| word_300_kaydirma | raster p90 | 7.5 | 7.5 | 8.1 | +9 | ok |
| word_300_kaydirma | raster p99 | 9.1 | 9.8 | 9.5 | +4 | ok |
| word_300_menu | build p90 | 5.1 | 9.3 | 6.5 | +30 | ok |
| word_300_menu | build p99 | 19.3 | 34.7 | 17.3 | -10 | ok |
| word_300_menu | raster p90 | 13.3 | 15.2 | 17.4 | +31 | KÖTÜ |
| word_300_menu | raster p99 | 15.7 | 17.0 | 19.7 | +25 | KÖTÜ |
| word_mobil_acilis_pro0 | build p90 | 3.6 | 4.0 | 3.7 | +2 | ok |
| word_mobil_acilis_pro0 | build p99 | 31.9 | 54.2 | 14.0 | -56 | ok |
| word_mobil_acilis_pro0 | raster p90 | 7.3 | 7.7 | 7.6 | +4 | ok |
| word_mobil_acilis_pro0 | raster p99 | 12.3 | 13.6 | 13.7 | +11 | ok |
| word_mobil_acilis_pro1 | build p90 | 4.0 | 4.7 | 4.6 | +16 | ok |
| word_mobil_acilis_pro1 | build p99 | 45.0 | 53.1 | 23.8 | -47 | ok |
| word_mobil_acilis_pro1 | raster p90 | 7.3 | 7.4 | 7.3 | +1 | ok |
| word_mobil_acilis_pro1 | raster p99 | 12.3 | 12.7 | 10.8 | -13 | ok |
| word_mobil_kaydirma_pro0 | build p90 | 13.1 | 18.0 | 13.1 | -0 | ok |
| word_mobil_kaydirma_pro0 | build p99 | 15.5 | 20.0 | 14.7 | -5 | ok |
| word_mobil_kaydirma_pro0 | raster p90 | 7.7 | 7.8 | 13.2 | +71 | KÖTÜ |
| word_mobil_kaydirma_pro0 | raster p99 | 13.0 | 13.2 | 14.1 | +8 | ok |
| word_mobil_kaydirma_pro1 | build p90 | 11.9 | 18.6 | 13.0 | +9 | ok |
| word_mobil_kaydirma_pro1 | build p99 | 13.4 | 21.5 | 14.3 | +6 | ok |
| word_mobil_kaydirma_pro1 | raster p90 | 7.6 | 8.5 | 12.5 | +65 | KÖTÜ |
| word_mobil_kaydirma_pro1 | raster p99 | 12.6 | 12.7 | 13.5 | +8 | ok |

| koşu | başlangıç °C |
|---|---|
| 1_A | 27.1 |
| 2_B | 28.0 |
| 3_B | 28.4 |
| 4_A | 28.6 |
| 5_A | 28.6 |
| 6_B | 28.4 |

Ortalama başlangıç °C: A 28.1, B 28.3

KARAR: KALDI — word_300_menu raster p90 13.3→17.4 (%+31); word_300_menu raster p99 15.7→19.7 (%+25); word_mobil_kaydirma_pro0 raster p90 7.7→13.2 (%+71); word_mobil_kaydirma_pro1 raster p90 7.6→12.5 (%+65)
