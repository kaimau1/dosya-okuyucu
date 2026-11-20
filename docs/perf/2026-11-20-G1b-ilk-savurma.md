# G1b — Fotoğraflar: açıldıktan sonraki ilk savurmada tek uzun kare (2026-11-20)

Cihaz: Huawei MatePad (DBY-W09, Android 12), USB. Profil derlemesi `.r8test` (arm64).
A = main `a68bb77f` · B = dal `faz-oto-G1b-galeri` (süzgeç şeridi "var mı" sorar).
Senaryo (her koşu `pm clear`): uygulama → Fotoğraflar → 8 sn bekle → tek savurma (yukarı) → 2 sn.
Ölçü: `KARE` (FrameTiming, ≥ 25 ms kareler, logcat); `tl` koşularında VM zaman çizelgesi
(`ext.flutter.profileWidgetBuilds` açık — widget düzeyi BUILD olayları).

| koşu | °C | ilk savurma karesi (ms, build) | ≥ 25 ms kare sayısı | not |
|---|---|---|---|---|
| A0 | 26,0 | 164 (159) | 1 | zaman çizelgesi (widget'sız) |
| A1 | 26,4 | 182 (176) | 1 | zaman çizelgesi (widget'lı) |
| A2 | 26,1 | 181 (165) | 2 | ikinci 30 ms |
| A3 | 26,3 | 170 (154) | 2 | ilki 27 ms raster |
| A4 | 26,4 | 154 (148) | 1 | |
| B1 | 26,6 | ≤ 24 (en uzun kare 6,5 ms) | 0 | zaman çizelgesi (widget'lı) |
| B2 | 26,7 | ≤ 24 | 1 | 28 ms (build 5, raster 20) |
| B3 | 26,8 | ≤ 24 | 0 | |
| B4 | 26,9 | ≤ 24 | 0 | |

Kök neden (A1 zaman çizelgesi): uzun karenin LAYOUT'u içindeki tek BUILD = galerinin yüzen
üst çubuğunun (SliverAppBar, kayarken yerleşimde yeniden kurulur) yeniden kurulması; 168 ms'nin
167,5 ms'si `FmQuickFilters.build` ÖZ süresi (altındaki `FmFilterBar` 1,2 ms). Şerit her
dosyada ~10 süzgeç denemesiyle TAM sayım yapıyordu (`_computeCounts`); önbellek anahtarı
(liste kimliği + geçmiş/etiket/Akıllı düzen sürümleri) ekran açıldıktan sonra değişmiş, şerit
ilk savurmaya dek yeniden kurulmamıştı → hesap o kareye biniyordu. Şeridin kendisi yalnız
"hap görünsün mü" sorusuna bakıyordu; sayılar levhada (levha kendisi sayar).

Düzeltme: şerit `_presence` ile yalnız VAR/YOK sorar, ilk eşleşmede durur; AI kategori
sayıları yalnız levha açılırken (`_smartCounts`, eşlem bakışı). Bekçi:
`test/perf/filter_perf_test.dart` "her çizimde yeni liste ≤ 60 ms".

KARAR: GEÇTİ — ilk savurma karesi 154–182 ms → ≤ 24 ms (4/4 koşu), başka ≥ 25 ms kare artmadı.
