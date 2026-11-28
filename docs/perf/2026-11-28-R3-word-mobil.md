# R3 kalan iki iş — Word mobil kaydırma + slayt geçiş build p99 (2026-11-28, Huawei DBY-W09)

A = `4b2bec2` (eski taban) · B = main `11fb9de6` · `AB_SENARYO=word_300,acilis_gecis`, 4A+4B ABBA,
`.r8test` profil, `tool/ab_olcum.sh`, pil 24–25,5 °C. Ham tablo: `2026-11-28-ab-4b2bec2-11fb9de.md`.

## Sonuç: iki gerileme de GERÇEK DEĞİL (ölçü gürültüsü) — kod değişmedi

### (1) `word_mobil_kaydirma_pro0/1` raster p90 (+%65–71 denmişti)

| ölçü | A ortanca | B ortanca | fark |
|---|---|---|---|
| pro0 raster p90 | 12.2 | 12.0 | −2 % |
| pro1 raster p90 | 12.7 | 10.9 | −14 % |
| pro0 / pro1 raster ORTALAMA | 7.51 / 7.83 | 7.77 / 8.15 | +3 / +4 % |
| koşu başı "yüksek kip" (p90 ≥ 11 ms) | 3/4, 3/4 | 2/4, 2/4 | — |

**Kök (ölçü):** senaryo yalnız ≈55 kare; kare başı raster iki kipli (≈7–8 ms / ≈13–14 ms), p90 = en kötü
6. kare → koşu ya alt ya üst kipe düşüyor. Aynı commit oturumdan oturuma kip değiştiriyor:
`4b2bec2` p90 = 7.7 (27-11 taban, 3/3 alt) · 11.2 · 12.0 · 13.0 (26-11 turları) · 12.2 (bugün, 3/4 üst);
`02c2ee5` 27-11 taban oturumunda 2/3 üst, aynı gün P22b oturumunda 3/3 alt (7.1/4.7/7.9).
"+%71" = taban oturumunda A'nın üç koşusunun da şans eseri alt kipe düşmesi. Bisect gereksiz (aynı
oturumda A ≈ B, ortalama raster farkı < %5, kod farkında raster yükü yok: düz docx'te tablo/resim/
opak paragraf yolu kullanılmıyor).

### (2) `gecis_pptx_acilis` build p99 (27→37–43 denmişti)

A 26/29/20/42 (ortanca 27.9) · B 56/31/25/20 (ortanca 28.1) → **+%1**. ≈60–74 karede p99 = en kötü
1–2 kare; aynı derlemede 16–58 ms (27-11 koşularında 121 ms bile) oynuyor. Önceki "KALDI"lar tek kare
şansı.

## Yeni bulgu (kapsam dışı → PLAN R3 yeni satırı)

**`acilis_ilk_sayfa#1` (belge_100 PDF ilk sayfa bitmap'i) A 331/375/419* → B 815/974/1001/1038 ms**
(+%163, tam ayrık — gürültü değil). 27-11'deki tüm koşularda (02c2ee5 ve sonrası) zaten 700–830 ms; yani
gerileme `4b2bec2..02c2ee5e` arasında, o raporlarda taban hep 02c2ee5 sonrası olduğu için görünmedi.
Şüpheli aralık `lib/screens/viewer/body.dart`'a dokunan commit'ler: c51456c1, ac47b338, 2bef416a,
e92152c2, f5ae323f, 2da8b296, fb47a12a (doğrulanmadı — bisect gerekir). Ayrıca `gecis_xlsx_acilis`
build p99 35→123 (B'de 2 koşu 198/320, öteki ikisi 19/48 — tek kare kuyruğu, izle).
(*1_A koşusunda açılış damgası logcat'e düşmedi; A = 3 koşu.)

KARAR: R3 (1) ve (2) GEÇTİ (gerileme yok) — düzeltme yapılmadı. Yeni: PDF ilk sayfa +600 ms → bisect.
