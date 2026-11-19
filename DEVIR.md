# DEVIR — P28 PDF kabuğu (faz-oto-P28-pdf-kabuk)
- 23c22f20 H3.6: durum çubuğu anahtarı PDF Aa levhasına (kök: metin levhasındaydı, shell_menus.dart `_showReadingSettings`) + bekçi testi
- 739c3a9c H3.7: `ReadingFloat.endShown`, rozet çubuklar görünürken end 44→80 (AI düğmesi sağdan 16+56) + test/reading_float_end_test.dart
- ff0d1367 H3.5: `PdfPagedTurn.gap` + body.dart `_pagedPdfLayout` (kipteyken sayfa aralığı) + test
- Şu an: belgeler + push + CI. Sıradaki: yürütücü cihaz A/B (docs/CIHAZ_TESTI.md "P28").
- Doğrulama: CI verify (yerel test yok).
- C1 (2026-11-19): main birleştirildi (cd1dea27), CI yeşil. Eski yarım tablo `docs/perf/2026-11-14-ab-c07320a-c387058.md` (YETERSİZ).
- A/B YAPILAMADI — cihaz bekliyor: USB'deki cihaz Huawei DBY-W09 (tablet), kurulum "bilinmeyen kaynak" güvenlik uyarısında takıldı (P08 koşusunda görüldü). Sür: Mi Note bağlıyken bu dalda `timeout 14400 bash tool/ab_olcum.sh "" HEAD`; gözle bakılacaklar CIHAZ_TESTI "P28".
