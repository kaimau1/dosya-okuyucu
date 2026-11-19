# G1 — Fotoğraflar: eski görsele hızlı inip açınca donma (2026-11-20)

Cihaz: Huawei MatePad (DBY-W09, Android 12, 2560×1600), USB. Profil derlemesi `.r8test`
(arm64). A = main `95715af3`, B = dal `faz-oto-G1-galeri-kasma` (film şeridi sabit öğe boyu).
Veri: tabletteki 3.821 görsel + 1.500 yapay 12 MP JPEG (her 3 günde bir, 2014'e dek) = 5.321.
Pil 25,5–25,8 °C (ısınma yok).

Senaryo (her koşu `pm clear` → küçük resim önbelleği boş): Fotoğraflar → bir savurma →
hızlı kaydırma tutamacıyla 1,2 sn'de en alta (2014) → 0,3 sn sonra bir görsele dokun → 3 sn.
Ölçü: `KARE` (FrameTiming, ≥ 25 ms kareler, logcat) + VM zaman çizelgesi.

| koşu | ilk savurma karesi (ms) | açılış karesi (ms, build) | ≥ 700 ms kare |
|---|---|---|---|
| A1 | 113 | 695 (678) | 0 |
| A2 | 121 | 712 (702) | 1 |
| A3 | 135 | 679 (647) | 0 |
| B1 | 127 | ≤ 33 | 0 |
| B2 | 114 | ≤ 26 | 0 |
| B3 | 127 | ≤ 32 | 0 |

Kök neden (zaman çizelgesi A2): açılış karesinde 343 ms içinde ~16 bin `BUILD` (tembel liste
öğe kurma). Galerinin alt küçük resim şeridi `ListView.separated` idi; boyu bilinmeyen öğeler
yüzünden açılışta seçili fotoğrafa `jumpTo` yaparken liste 0'dan o indekse kadar (en eski
fotoğrafta ~5.300 öğe + 5.300 ayraç) her öğeyi kurup ölçtü. Yeni fotoğrafta indeks küçük →
sorun yok; bu yüzden "eski fotoğraflarda" görülüyordu. Düzeltme: `itemExtent` (O(1) atlama).

Kalan (bu işin dışı, A ve B'de aynı): Fotoğraflar açıldıktan sonraki İLK savurmada tek
110–135 ms kare (LAYOUT içinde tek BUILD; eski/yeni fotoğraftan bağımsız). Kök bulunmadı → PLAN.

KARAR: GEÇTİ — açılış donması 679–712 ms → ≤ 33 ms; başka senaryo kötüleşmedi (ilk savurma
karesi A 113–135, B 114–127).
