# Cihaz ve masaüstü doğrulama listesi

> Kodla ya da birim testle kapatılamayan, **telefonda bakılması gereken** maddeler.
> Faz 0 bu dosyayı KALANLAR'daki eski "cihaz doğrulaması" maddeleriyle dolduracak;
> şimdilik Faz 8 ve Faz 9 bölümleri var. Her madde: ne yapılır → ne görülmeli.
> Örnek dosyalar `test/fixtures/pdf/` ve `test/fixtures/office/` altında
> (`flutter test tool/write_fixtures_test.dart` yeniden üretir).

## Faz 8 — PDF tek çatı (2026-10-21)

- [ ] **Düzenle kapısı:** herhangi bir PDF → alt çubukta artık *Düzenle · Araçlar · Çevir ·
      Paylaş · Yazdır* var (Kalem/Düzenleyici ayrı düğme değil). "Düzenle" → altı kip
      (Metin, Kalem, İmza, Form, Sayfalar, AI ile) çıkıyor mu, her biri kendi ekranını
      açıyor mu, kaydederken hep aynı "Orijinali değiştir / Kopyasını kaydet" penceresi mi.
- [ ] **Seçimden düzenleme:** yazıya uzun bas → seçim çubuğunda "Düzenle" → PDF
      düzenleyicisi SEÇİMİN SAYFASINDA açılıyor mu (eski satır içi kutu artık yok).
- [ ] **Yazı ekle (K12 yedeği):** `taranmis.pdf` → Düzenle → Metin → sağ altta
      "Yazı ekle" → sayfaya dokun → metin + punto → yazı dokunulan yerde mi;
      `dondurulmus_90.pdf` ve `cropbox.pdf`te de dokunulan yerde ve DÜZ okunuyor mu.
- [ ] **"Daha fazla" sayfası:** "Düzenle ve imzala" grubu kalktı; Metni tanı (OCR)
      "Dönüştür" grubunda.
- [ ] **Aa levhası (PDF):** üst çubukta "Aa" → okuma görünümü düğmesi, 1/2/4 sütun,
      gece modu ve "kaldığım yerden aç" anahtarı tek yerde; değişiklik arkada canlı.
- [ ] **Örnek set:** `test/fixtures/pdf/*` uygulamada açılıyor mu (parola: `1234`);
      `uzun_320_sayfa.pdf` açılış süresi Faz 4 ölçümünden kötü değil mi
      (`docs/perf/2026-10-21.md`).

**Bulutta ölçülen (2026-10-21):** örnek PDF'lerin hepsi Poppler'da açılıyor;
düzenlenmiş hâllerinde yeni metin var, eskisi yok (`pdftotext`). Paragraf motoru
`/Rotate 90/180/270`, CropBox'lı, parolası kaldırılmış, Type0/Identity-H ve
`/Differences`+AGL (ToUnicode'suz) belgelerde düzenliyor (`pdf_fixture_smoke_test`).

## Faz 9 — Office ve metin (2026-10-21)

### Word
- [ ] **Canlı yazma gidiyor mu (KÖK NEDEN düzeltmesi):** `tablo.docx` → Düzenle → bir
      paragrafa yaz → Kaydet → dosyayı kapat-aç: yazılan duruyor mu. (Chromium'da
      ölçüldü: `input` olayının hedefi `<article>` olduğu için yazılanlar eskiden
      Flutter'a hiç gitmiyordu — bkz. HAFIZA 2026-10-21 (4).)
- [ ] **Tablo hücresi:** aynı belgede "Ayşe" hücresine yaz → kaydet → yeniden aç.
- [ ] **Seçime punto/yazı tipi:** bir kelimeyi seç → punto 20 → yalnız o kelime
      büyüyor mu; kaydet-aç sonrası da öyle mi.
- [ ] **Resim ekle/sil:** imleç bir paragrafta → şeritte "Resim ekle" → galeriden
      resim → paragrafın altına geldi mi, düzenleme kaldığı yerden sürüyor mu;
      resmin yanına dokun → "Resmi sil".
- [ ] **Masaüstü Word:** `tablo_duzenlendi.docx` Word'de onarım istemeden açılıyor mu
      (resim, madde işareti, "Mart" 16 pt kalın, "Ayşe Kaya").

### Excel
- [ ] **Grafik ekle:** `satis.xlsx` → A1:C4 seç → Daha fazla → Ekle → Grafik ekle →
      Sütun/Çubuk/Çizgi/Pasta önizlemesi değişiyor mu → Ekle → Kaydet.
- [ ] **Masaüstü Excel / Google E-Tablolar:** `satis_duzenlendi.xlsx` onarım istemeden
      açılıyor mu, grafik E-M sütunlarında görünüyor mu, sayfa sırası *Notlar, Özet*.
- [ ] **Köşegen doldurma:** 1, 2 / 10, 20 bloğunu seç → tutamağı sağ-aşağı çapraz çek →
      önizleme dikdörtgen mi, sonuç satır serisinin devamı mı (C1=19 …).
- [ ] **Sayfa taşı:** sekmeye uzun bas → Sola/Sağa taşı → kaydet → Excel'de sıra aynı mı.
- [ ] **Seçimi çevir:** birkaç hücre seç → Çevir → yalnız seçim çevriliyor mu.
- [ ] 10 bin satırlık dosyada kaydırma/açılış Faz 4 ölçümünden kötü değil mi
      (`tool/make_test_tree.py` ve Ek D protokolü).

### Slayt
- [ ] Metin kutusunu düzenle → bir kelime seç → şeritte "Çevir" → yalnız seçim.
- [ ] `sunum_duzenlendi.pptx` PowerPoint'te açılıyor mu ("Gelir %12 arttı").

### Metin ve eski biçimler
- [ ] **Büyük metin:** 50 MB'lık bir kayıt dosyası aç → "Büyük dosya — salt okunur"
      şeridi + satır sayısı + kodlama; hızlı kaydırma (kaydırma çubuğunu sürükle)
      takılmıyor mu, bellek uyarısı/çökme yok mu.
- [ ] **Kodlamalar:** `metin_utf8.txt`, `metin_cp1254.txt`, `metin_utf16le.txt` aynı
      Türkçe metni gösteriyor mu; `noktali_virgul.csv` üç sütun.
- [ ] **Eski .doc/.ppt:** gerçek bir `.doc` aç → "SALT OKUNUR" rozeti → "DOCX yap ve
      düzenle" → yanına `ad.docx` (varsa `ad (2).docx`) çıktı mı ve Word ekranı açıldı mı;
      `.ppt` için aynısı (`.pptx`).

**Bulutta ölçülen (2026-10-21):** `test/fixtures/office/*.{docx,xlsx,pptx}` (özgün +
düzenlenmiş, 7 dosya) LibreOffice 7'de PDF'e çevrildi; hepsi açıldı, düzenlenen metinler
yerinde. Grafik dört türde de LibreOffice'te çiziliyor (`spPr` rengi eklendikten sonra —
önce çubuklar görünmüyordu). openpyxl grafikleri `BarChart/LineChart/PieChart` olarak
okuyor. Word köprüsü: `node tool/check_word_bridge.js` (Playwright + Chromium).
**Gerçek Microsoft Office'te açılış bulutta denenemedi** — yukarıdaki masaüstü maddeleri
bunun için.
