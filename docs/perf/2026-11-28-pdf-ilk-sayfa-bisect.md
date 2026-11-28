# PDF `acilis_ilk_sayfa` bisect — 2026-11-28

Cihaz: Huawei tablet (5VLBB21A27203178), `.r8test` profil derlemesi, `AB_SENARYO=acilis_gecis`,
damga `PDFPRO_PERF faz=acilis_ilk_sayfa` (belge_100). Aralık `4b2bec2..02c2ee5e` (first-parent, 94 adım).
Küme: iyi ~220–420 ms, kötü ~740–1010 ms.

| adım | commit | ms | sonuç |
|---|---|---|---|
| 47 | 2da8b296 | 744 | kötü |
| 24 | 00d1eeca | 1007 | kötü |
| 12 | 9ad352c9 | 776 | kötü |
| 6 | ec7e9332 (ux-home-core) | 261 | iyi |
| 9 | 8ee5484d (perf-media-pdf) | 949, 792 | kötü |
| 8 | 8c3e416b (pdf-excel-fix) | 224, 334 | iyi |

8ee5484d = 8c3e416b + `c51456c1` (tek yan dal) → **sorumlu commit: c51456c1**
"perf(media,pdf,fm): açılış, galeri, video, büyük PDF ve liste performansı" (iki koşuda da kümeler ayrık).

## Kök tahmini (diff okuması, kod değiştirilmedi)

`lib/screens/viewer/body.dart`, `PdfViewer.file` → `PdfViewerParams.behaviorControlParams`:
- `trailingPageLoadingDelay: Duration(microseconds: 500000)` = **500 ms** (pdfrx varsayılanı Android'de 100 ms).
- `partialImageLoadingDelay: Motion.short` = 120 ms (varsayılan 0 ms).
- `onePassRenderingSizeThreshold` 1400/2000 (varsayılan 2000) ve `loadingBannerBuilder` boş — küçük etki.

`third_party/pdfrx/lib/src/widgets/pdf_viewer.dart:604`: arka sayfaların yüklenmesi bu gecikme kadar
beklenir; ölçülen damga `onDocumentLoadFinished` (body.dart:271 `openMark('ilk_sayfa')`) bu bekleme
SONRASI tetiklenir. Fark ≈ +400 ms bekleme + 120 ms kısmi görüntü gecikmesi ≈ gözlenen +500–600 ms.
Yani gerileme büyük ölçüde damganın (belge-yükleme-bitti) kaymasıdır; ilk sayfa bitmap'inin gerçek
ekrana gelişi bundan önce olabilir ama kısmi görüntü gecikmesi (120 ms) gerçek bir gecikmedir.
Önerilen düzeltme: gecikmeleri varsayılana indir (trailing 100 ms, partial 0) ya da damgayı gerçek ilk
sayfa çizimine (ilk sayfa görüntüsü hazır olayı) taşı; sonra A/B.

Not: `acilis_belge`, `acilis_ekran`, `acilis_gecis_pdf` bu aralıkta kötüleşmedi (önceki tablo).
Temizlik: kilit bırakıldı, Gradle daemon durduruldu, `okuyucu_ab_*` ağaçları silindi.
