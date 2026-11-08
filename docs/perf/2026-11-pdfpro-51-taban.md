# PDF Pro Faz 51 — şimdiki motorun TABAN ölçümü (2026-11-08)

**Ne:** `test/pdf_pro/bench_test.dart` + `tool/pdf_pro_bench.dart`, külliyat
`test/fixtures/pdf_corpus/` (68 PDF, 8 üretici — `CORPUS.md`). Motor: şimdiki Dart paragraf
motoru (`PdfPageEdit.outline` / `replaceParagraph`, editörün yaptığının aynısı: sahip parolalı
belgede önce kilit açılır). Ölçüm motordan **bağımsız**: metin ve pikseller PDFium'dan
(pdfrx), yani Faz 52'deki ikinci motor aynı cetvelle ölçülür. Taban bekçisi:
`test/pdf_pro/baseline.json` (kötüleşme CI kırmızı).

**Ortam:** yerel Windows (Flutter 3.47.9, debug JIT) — süreler göreli; CI (Linux) aynı
sayıları verir, ek olarak `qpdf --check` + `mutool draw` (bkz. alttaki CI satırı). Her sayfada en
çok 6 blok, belge başına en çok 2 sayfa; iki düzenleme türü:
`ayni` (ilk ↔ son sözcük — aynı harfler, yalnız yeniden dizme sınanır) ve `turkce`
(ilk sözcük → "Işığı" — glif kapsaması sınanır). Başarı = motor reddetmedi **ve** yeni metin
PDFium'un sayfa metninde (aranabilir).

## Özet

| Ölçüm | Değer | Hedef (plan §7) |
|---|---|---|
| Dosya / sayfa | 68 / 74 | — |
| Kapsama (PDFium karakterlerinin düzenlenebilir blokta olanı) | **%63,6** | ≥ %97 |
| Bulunan blok / beklenen paragraf | 181 / 516 | — |
| Hiç blok bulunamayan doğal metinli dosya | **21** (Word'ün 18'inin hepsi, Type3, standart 14 font) | 0 |
| Düzenleme başarısı — `ayni` | **%54,2** (84/155) | ≥ %98 |
| Düzenleme başarısı — `turkce` | **%34,2** (54/158) | ≥ %98 |
| `turkce`'de eksik glif reddi | 44 / 158 (%27,8) | 0 (glif bazlı yedek) |
| Değişmeyen bölge piksel farkı > 0 olan düzenleme | `ayni` 10/83 · `turkce` 13/53 (en çok 29 115 px) | 0 |
| `.notdef` | **ölçülemedi** (motor glif varlığını bilmiyor — Faz 52 PDFium yolunda) | 0 |
| Büyüme p50 / p95 (bayt) | `ayni` 1 824 / 4 381 · `turkce` 1 620 / 4 548 | — |
| Gecikme p50 / p95 (ms, yerel JIT) | `ayni` 25,6 / 114,2 · `turkce` 27,9 / 109,1 | — |
| Sayfa hatası | 2 (`wd_sifreli.pdf`: kilit açıldıktan sonra "Sayfa bulunamadı") | 0 |
| `qpdf --check` / `mutool draw` hatası (CI) | **0 / 0** (138 başarılı düzenlemenin hepsi) | 0 |

## Reddin nedenleri (başarısız 175 düzenleme)

| Neden | Adet |
|---|---|
| Paragrafın içinde metin dışı çizim (`q`/`Q`/`cm`/`BDC`/`EMC`/`w`/`re`) — yeniden dizme reddi | 106 |
| Eksik glif (alt küme fontta yeni harf yok) | 49 |
| Metin sığmıyor (altta yer yok) | 15 |
| Motor yazdı ama yeni metin PDFium'da çıkmıyor | 5 |

## Üretici başına

| Üretici | Kapsama | Düzenleme | Başarı | Piksel kirli |
|---|---|---|---|---|
| Microsoft Word (18 dosya) | **%0** | 5 | %0 | 0 |
| Chrome/Skia | %98,5 | 104 | %40,4 | 17 |
| ReportLab | %98,5 | 64 | %15,6 | 2 |
| fpdf2 | %96,6 | 42 | %52,4 | 0 |
| PyMuPDF | %100 | 30 | %90,0 | 0 |
| Syncfusion | %100 | 38 | %78,9 | 0 |
| pdf (Dart) | %100 | 16 | %0 | 0 |
| matplotlib (Type3/Type42) | %45,6 | 2 | %0 | 0 |

## Bulgular (kök nedenler)

1. **Word belgelerinde motor HİÇ paragraf bulamıyor** (PS2'nin asıl kökü): Word her satırı ayrı
   `q … re W* n … BT … ET Q` kırpma bloğuna ve `/Span <</MCID n>> BDC … EMC` işaretli içeriğe
   sarıyor; paragraf motoru kırpmalı blokları birleştirmiyor (`uniformGraphics`) → 0 blok →
   editör sayfayı "taranmış" sayıp OCR'a düşüyordu. Faz 51.8 sessiz OCR düşüşünü kapattı
   (kullanıcı bilerek "OCR ile düzenle" seçebilir); gerçek çözüm Faz 52 motor kararı.
2. **Sahip parolalı belgede kilit açma şifreyi kaldırmıyordu** (Syncfusion izin bayrakları) —
   tezgâh yakaladı, düzeltildi (`PdfTools.removePassword`, test). AES-256 (R6) Word kopyası
   kilit açıldıktan sonra sayfasız çıkıyor → KALANLAR (Faz 52 PDFium yolu R6'yı kendisi açar).
3. **Değişmeyen bölgede piksel farkı** en çok Chrome çıktısında: aynı `BT` bloğunu paylaşan
   komşu satırların yeniden konumlanması; iki büyük vaka (`rl_iki_sutun` 29 115 px,
   `rl_karma_logo` 13 554 px) iki sütunlu/yaslı düzende satır sayısı değişince komşu sütunun
   metin matrisi kayması. PK1 kapısının ana ölçütü.
4. **Eksik glif** `turkce` düzenlemelerinin %28'i: şimdiki motor glif bazlı yedek yapmıyor,
   reddediyor (editörde Carlito'yla üstüne yazmaya düşüyordu — PS2b).

## CI (Linux, `qpdf` + `mutool`)

CI koşusu 42468059813 (ubuntu, qpdf 12.3.2 + mupdf-tools): sayılar yerelle **birebir aynı**
(deterministik) — kapsama %63,6, başarı %54,2 / %34,2, piksel kirli 10 / 13; `qpdf --check` ve
`mutool draw` hatası **0** (yazılan her artımlı dosya iki bağımsız okuyucudan geçti). Gecikme
p50/p95 CI: `ayni` 30,4 / 105,4 ms · `turkce` 29,0 / 123,4 ms. Tezgâh süresi 21 sn.
