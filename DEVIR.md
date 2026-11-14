# DEVIR — faz-oto-P01-olcum (OTOMASYON P01) — BİTTİ, birleştirme bekliyor

Yapılanlar:
- H0.3 açılış damgaları `PDFPRO_PERF faz=acilis_{ekran,belge,ilk_sayfa,kucuk_resim}` (20c61b52).
  İlk sayfa bitmap'i = pdfrx `onDocumentLoadFinished` (ilk sayfa görüntüsünü bekler), yama yok.
- H0.2 senaryo `pdf_buyuk_acilis` + `pdf_buyuk_50_sayfa` (409ecd5d; BUYUK_PDF dart-define).
- `tool/ab_olcum.sh` + `tool/ab_karar.py` (d5f65eb0 + Windows düzeltmeleri); `ci/prepare_android.sh`
  pub yolu `url2pathname` (Windows'ta StopIteration veriyordu).
Kuru deneme (AB_KURU=1, A=8696755): 11 senaryo özeti geldi, büyük PDF 24 fırlatma sayfa 1→51,
pil 19,6→23 °C. Ham: build/ab/20261114-141521 (git dışı). Tam A,B×2 koşusu YAPILMADI (P02 işi).
Test: `python -I tool/ab_karar.py --deneme` · CI verify.
