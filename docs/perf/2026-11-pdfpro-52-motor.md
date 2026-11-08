# PDF Pro Faz 52 — motor karar kapısı: PK1 (PDFium) mi, PK1-B mi? (2026-11-08)

**KARAR: PK1 — PDFium nesne düzeyi düzenleme**, iki koşulla (aşağıda §Koşullar). Prototip
bayrak arkasında kalır (`pdf_pro_engine`); varsayılan yol olması Faz 54'te §Koşullar 1–2'nin
sayıyla kapanmasına bağlı.

**Yöntem:** `test/pdf_pro/bench_test.dart` iki motoru aynı külliyatta (68 PDF / 8 üretici, 74
sayfa) aynı cetvelle ölçer — metin ve pikseller PDFium'dan (144 dpi), motordan bağımsız
(`tool/pdf_pro_bench.dart`). Düzenleme türleri: `ayni` (aynı harflerle ilk↔son sözcük) ve `turkce`
(ilk sözcük → "Işığı"). Başarı = motor reddetmedi **ve** yeni metin PDFium'un sayfa metninde.
Yerel Windows (Flutter 3.47.9, debug JIT); CI (Linux) aynı sayıları + `qpdf --check` /
`mutool draw` verir (alttaki CI satırı).

| Motor | Ne |
|---|---|
| **A — dart-paragraf** | Şimdiki Dart paragraf motoru (`PdfPageEdit`, kendi içerik akışı ayrıştırıcısı + artımlı yazıcı) |
| **B — pdfium-nesne** | `PdfEditBridge`: görüntüleyicinin açık PDFium belgesinde, pdfrx işçisinde (`computeOnIdleDocument` yaması), metin nesnesi okuma → blok kurma → aynı font/matrisle yeniden yazma → `GenerateContent` → **geri okuma doğrulaması** (tutmazsa eski nesneler yerine) → `encodePdf(incremental)` |

## Tablo

| Ölçüm | A dart-paragraf | **B pdfium-nesne** | Kazanan |
|---|---|---|---|
| Kapsama (PDFium karakterlerinin düzenlenebilir blokta olanı) | %63,6 | **%100** | B |
| Bulunan blok / beklenen paragraf (516) | 181 | **520** | B |
| Hiç blok bulunamayan doğal metinli dosya | 21 (Word'ün hepsi) | **0** | B |
| Sayfa hatası | 2 (AES-256 kilit açma) | **0** (PDFium R6'yı kendisi açar) | B |
| Başarı — `ayni` | %54,2 (84/155) | **%81,8** (251/307) | B |
| Başarı — `turkce` | %34,2 (54/158) | **%44,9** (149/332) | B |
| Eksik glif reddi — `turkce` | 44 (%28) | 169 (%51) — dürüst ret, glif yedeği Faz 56 | — |
| Değişmeyen bölge piksel farkı > 0 (düzenleme) | 23 / 136 (%16,9) | 54 / 400 (%13,5) | ≈ |
| — ReportLab ailesi dışında | 21 / 128 (%16,4) | **1 / 284 (%0,4)** | B |
| — ReportLab ailesi (`Tw` kullanan) | 2 / 8 | 53 / 116 | A |
| İşaretli içerik (BDC/MCID) kaybı, blok dışı | ölçülemez | **0** | B |
| Gecikme p50 / p95 (ms) `ayni` | 26,9 / 116,4 | **8,4 / 53,0** | B |
| Gecikme p50 / p95 (ms) `turkce` | 27,5 / 106,4 | **7,5 / 62,5** | B |
| Bellek tepe artışı (koşu boyunca RSS) | 103,8 MB | **37,6 MB** | B |
| Çıktı büyümesi p50 / p95 (bayt / düzenleme) | **1 824 / 4 381** | 36 563 / 174 211 | A |
| `qpdf --check` / `mutool draw` hatası (CI) | 0 / 0 | 0 / 0 | = |
| `.notdef` | ölçülemez | ölçülemez (geri okuma eşlenemeyeni reddeder; glif varlığı Faz 56) | = |

PK1 kapısının dört ölçütü (plan §3): **başarı oranı** B ✅ · **gecikme** B ✅ (3×) · **değişmeyen
bölge farkı** — strict 0 iki motorda da yok; B'nin oranı daha düşük, ReportLab dışında
neredeyse sıfır, kalan farkın kökü bulundu (Koşul 1) · **çıktı büyümesi** A önde (Koşul 2).
Planın "Bitti" ölçütü ("seçilen yol şimdiki motorun en az başarı oranında ✅ ve değişmeyen bölge
farkı 0 ⚠️") yarım: bu yüzden prototip bayrakta kalır, varsayılan olması Koşul 1'e bağlandı.

## Kök nedenler (ölçerek bulundu)

1. **`GenerateContent` metin durumunu (`Tw` sözcük aralığı, `Tc`) yazmıyor.** PDFium düzenlenen
   bloğu taşıyan içerik akışının TAMAMINI nesne modelinden yeniden üretiyor; ReportLab satırları
   `-0.0917 Tw` ile yazdığı için aynı akıştaki DOKUNULMAMIŞ satırlar her boşlukta 0,09 pt kayıyor
   (`rl_cok_sayfa`: "Işıklı tabelalar…" satırında karakter kökenleri +0,092 pt; görsel olarak
   aynı ama piksel farkı 6–21 bin). Chrome/Word/Syncfusion/fpdf2/PyMuPDF'te fark yok (1 RTL vaka
   hariç: `wd_arapca` 110 px).
2. **Büyüme:** artımlı kayıt, sayfanın font kaynak sözlüğünü (`/FXF1`, `/FXF2` takma adlarıyla)
   ve gömülü font akışlarını (FontFile2, ~15 KB'lik) yeniden yazıyor → düzenleme başına +36 KB
   (p50). İçerik akışının kendisi küçük.
3. **Glif:** PDFium bloğu Dart motorundan 3× fazla bulduğu için alt küme fontlarda eksik Türkçe
   harf daha çok görünüyor (Word fontları); köprü bunu sessizce yazmıyor — geri okuma tutmazsa
   eski nesneleri yerine koyup reddediyor (`pdf_edit_bridge_test`).
4. **Boşluk glifi yok** (Dart `pdf` paketi, bazı Chrome alt kümeleri): yeni metin bitişik çıkıyordu;
   geri okuma boşlukları da şart koşacak şekilde sıkılaştırıldı (ret).

## Koşullar (PK1'in varsayılan yol olması için — Faz 54 bitti ölçütü)

1. **Değişmeyen bölge farkı 0 — ReportLab ailesi dahil.** Yol: düzenlenen akışta `Tw`/`Tc`
   kullanan dokunulmamış nesne varsa ya (a) yeni nesneler ayrı içerik akışına yazılıp eski
   bloğun baytları akışta yerinde çıkarılır (PDFium karakter→nesne eşlemesi + Dart artımlı
   yazıcı = hibrit), ya da (b) üst akışın yalnız düzenlenen aralığı yeniden yazılır. Ölçüt:
   tezgâhta `pixelDirty` (ReportLab dahil) 0.
2. **Büyüme ≤ şimdiki motorun 2 katı** (p50 ≤ 4 KB): font sözlüğü/akışı yeniden yazılmamalı
   (aynı kaynak adını yeniden kullan; değişmeyen nesneyi kayda koyma).

Glif eksikliği (169 ret) Faz 56'nın işi (glif bazlı yedek, PK5); OCR/taranmış Faz 62.

## CI (Linux, qpdf + mutool)

_Birleşmeden önce doldurulur._
