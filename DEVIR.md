# DEVIR — faz-oto-P01-olcum (OTOMASYON P01)

Yapılanlar:
- H0.3 açılış damgaları `PDFPRO_PERF faz=acilis_{ekran,belge,ilk_sayfa,kucuk_resim}` (20c61b52).
  İlk sayfa bitmap'i = pdfrx `onDocumentLoadFinished` (ilk sayfa görüntüsü önbelleğe girince
  çağrılır — third_party/pdfrx/lib/src/widgets/pdf_viewer.dart:745-760), yama gerekmedi.
- H0.2 senaryo `pdf_buyuk_acilis` + `pdf_buyuk_50_sayfa` (BUYUK_PDF dart-define).
- `tool/ab_olcum.sh` + `tool/ab_karar.py` (karar kuralı, MIUI düğme bulucu, `--deneme` öz denetim).

Şu an: CI + cihazda kuru deneme (`AB_KURU=1 bash tool/ab_olcum.sh HEAD`).
Sıradaki: bitiş belgeleri (OTOMASYON satırı, FERRARI [x], ab-olcum "Araç farkı", HAFIZA).
Test: `python -I tool/ab_karar.py --deneme` · CI verify.
