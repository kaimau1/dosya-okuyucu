# GELİŞTİRME PLANI — Faz 34–42 (2026-11-04)

Kaynak: kullanıcı isteği *"görünüm ve işlev olarak geliştir; Excel, Word, Slayt, PDF; belge
taramada profesyonel yöntem; eksiksiz düşün"* + 2026-11-04 kod taraması (`lib/services`,
`lib/screens/editors`, `pdf_*`, `scan_*`). Yürütme sırası **KALANLAR.md → "Faz C"**.
Doğrulama = CI (CLAUDE.md §4); cihazda bakılacaklar `docs/CIHAZ_TESTI.md`'ye.

## PERFORMANS KORUMA ANAYASASI (her fazın ön koşulu — 2026-11-04, kullanıcı: "performans düzeltmelerini bozma")
Mevcut kazanımlar (docs/perf/2026-10-21.md, HAFIZA Faz 4): soğuk açılış ~430–630 ms, boşta 0 kare,
5.000 öğe kaydırma p99 8 ms, görsel önbelleği 56/100/160 MB (`PerfBudget`), GPU belleği tavanı
64 MB/300, `FsScan.sort` ad anahtarı bir kez, açılış kuyruğu (`StartupQueue`, 2 sn sonra tek sıra),
gizli sekme `TickerMode`, PDF metni açılışta çıkarılmaz (P4), uygulama boyutu önbelleği (P5),
bellek yoklaması 15 sn (P6), hafif profilde 120 Hz/otomatik tarama/nabız kapalı (P12).
**Kurallar (hiçbiri pazarlıksız):**
1. **Yeni ağır iş ana iş parçacığında koşmaz:** ayrıştırma/OCR/görüntü işleme/PDF üretimi
   `compute`/izolat ya da Kotlin `Dispatchers.Default`; `perf_offload_test` desenine bağla.
2. **Tembel yükle:** yeni özellik açılışta (`main`, pano `initState`) hiçbir şey çalıştırmaz;
   ilk kullanımda kurulur. Gerekli ise `StartupQueue`'ya girer, asla ilk 2 sn'de değil.
3. **Bütçe `PerfBudget`ten gelir:** yeni önbellek/eşzamanlılık/çözme genişliği sayısı elle
   yazılmaz; `low/mid/high` profiline bağlanır. Hafif profilde yeni animasyon, nabız,
   önizleme otomatiği KAPALI başlar. Açık tercih korunur.
4. **Görsel bütçesi:** yeni resim gösteren her yüzey `cacheWidth = boyut×dpr` (kademeli kova)
   kullanır; tam çözünürlük yalnız yakınlaştırmada. Tarama/PDF önizleme ≤ ekran×dpr×2 (≤2480).
5. **Yeniden çizim disiplini:** büyük listede/ızgarada `const` + `RepaintBoundary` + sabit
   `itemExtent`/`mainAxisExtent`; yeni bildirimci `ValueListenableBuilder` ile dar kapsam —
   kökte `watch` YOK (`root_rebuild_test`). `saveLayer`/`Opacity`/`BackdropFilter`/geniş
   `ShaderMask` liste hücresinde YASAK (squircle simgeler tek `CustomPainter`, bu desen korunur).
6. **Boşta 0 kare:** yeni `AnimationController`/`Timer.periodic` görünmezken durur
   (`TickerMode`, yaşam döngüsü); yeni dosya izleyici dizin izleme olayına bağlanır, yoklama yapmaz.
7. **APK/bellek bütçesi:** yeni bağımlılık/yerel kütüphane CI boyut + 16 KB denetiminden geçer;
   +1,5 MB üstü her ekleme için gerekçe + alternatif (`HAFIZA`). Model dosyaları (OCR/çeviri)
   isteğe bağlı iner, APK'ya gömülmez.
8. **Her faz perf kapısı:** (a) ilgili `test/perf/*_perf_test.dart` (excel/word/slides) genişler
   ve yeşil; (b) tasarım tokenı/hareket bekçileri (`design_tokens_test`, `motion_tokens_test`) yeşil;
   (c) `docs/perf/` altında faz sonu A/B tablosu: **önce/sonra** soğuk açılış, pano boşta kare,
   büyük klasör kaydırma, ilgili editörde büyük dosya açılış/kaydırma/kayıt süresi
   (ölçüm Xiaomi 13T + bir düşük RAM cihaz; `FrameTiming` ile — SF aralığı kanıt DEĞİL);
   (d) gerileme > %10 ya da p99 > 24 ms ise faz birleşmez, özellik bayrakla kapalı gelir.
9. **Özellik bayrağı:** büyük yeni yetenek (pivot, imza, pro tarayıcı) `perf_mode=hafif`te
   ya da bayrak kapalıyken eski yolu aynen çalıştırır; geri alma tek satır.
10. **Büyük dosya tavanı:** 100 MB xlsx/pdf, 10 bin slayt nesnesi, 500 sayfalık docx için
    akış okuma + sayfalama; yeni özellik bu tavanı düşürmez (test verisi `tool/make_test_tree.py`).

## Mevcut durum (tarama özeti)
- **Excel:** xlsx okuma/yazma/yama, formül motoru, grafik, veri doğrulama, otomatik süzgeç,
  dondurma, adlandırılmış aralık, bul/değiştir. **Eksik:** özet tablo (pivot), mini grafik
  (sparkline), koşullu biçim *yazma* (A7.5), tablo nesnesi (structured ref), formül
  otomatik tamamlama/yardım balonu zayıf, yazdırma düzeni, parola.
- **Word:** docx düzenleme, değişiklik izleme, yorum, dipnot, içindekiler, üst/alt bilgi,
  sayfa no. **Eksik:** denklem (OMML yalnız okunur), stil galerisi/stil düzenleme, şablonlar,
  mail-merge, sayfa düzeni (kenar boşluğu/sütun) ekranı, karşılaştırma, PDF dışa aktarım
  kalitesi (sayfa kırılımı), belge parolası.
- **Slayt:** pptx okuma/düzenleme, geçiş, animasyon, konuşmacı notu, sunum kipi. **Eksik:**
  ana slayt/yerleşim (master) düzenleme (yalnız okunur), SmartArt (görüntü olarak), slayt
  içi grafik düzenleme, ses/video ekleme, şablon galerisi, sunucu görünümü (zamanlayıcı+not).
- **PDF:** görüntüle/işaretle/kalem/form/imza (görsel)/sayfa işlemleri/birleştir-böl/OCR/çeviri.
  **Eksik:** kalıcı karartma (redaction) doğrulaması, **dijital imza (PKCS#7)**, PDF/A,
  sayfa karşılaştırma, tablo çıkarma (→ Excel), parola/izin düzenleme, sıkıştırma agresif
  kip (A7.4), yer imi düzenleme, damga/filigran şablonları.
- **Tarama:** `cunning_document_scanner` (ML Kit belge tarayıcı sarmalayıcı) → JPEG →
  `scan_enhance/dewarp/prepare/page_ops` → OCR'lı PDF. **Eksik:** canlı kenar kılavuzu ve
  otomatik çekim bizde değil (paket penceresi), yalnız JPEG döner (PDF/OCR bizde),
  belge türü kipleri yok, kimlik/kitap/kartvizit akışı yok, toplu inceleme ızgarası zayıf.

---

## Faz 34 — Pano cilası — BİTTİ 2026-11-04 (cihaz doğrulaması CIHAZ_TESTI.md'de)
- [x] Simgeler sadeleşti: parlama kalktı, gölge/gradyan yumuşak (`fm_tile_art.dart`).
- [x] Alt gezinme çubuğu kalktı; alt panel simetrik (Çöp · Drive · **Aktar** · Tara · Yer aç),
      güvenli alan (SafeArea) eklendi; ek düğme varsayılanı "Yer aç" (`home_quick_row.dart`).
- [x] Araçlar çizgisi yukarı çekildi; kutu ızgarası 0,86→0,94 oran; araç çerçevesi ince.
- [ ] Cihazda doğrula: 360×800 dp ve 2× yazı ölçeğinde tüm araç satırı alt panel üstünde.
- [x] Başka sekmelere erişim panodaki kutulardan; ölü alt çubuk ayarı (ayarlar satırı +
      "Ana ekranı düzenle" girişi) kaldırıldı (`NavTabs` altyapısı sekme durumu için duruyor).
**Bitti ölçütü:** ekran görüntüsünde 4 sıra kutu + araç satırı + alt panel kayma yok.

## Faz 35 — Pro belge tarayıcı — BİTTİ 2026-11-05 (kod; cihaz doğrulaması CIHAZ_TESTI.md'de, perf A/B bekliyor)
**KARAR (kullanıcı onayladı, 2026-11-04): ML Kit geçişi Faz 35'in ilk adımıdır; kullanıcı başlatacak.**
Karar: **ML Kit `GmsDocumentScanner`'ı doğrudan kullan** (Kotlin köprüsü,
`ci/` yaması) — `cunning_document_scanner`'ı bırak. Gerekçe: sonuç olarak **PDF + JPEG**
birlikte döner, **canlı kenar + otomatik çekim + parmak/gölge/leke silme + otomatik
döndürme** Google'da hazır; sayfa sınırı, galeri içe aktarma, kip (BASE / BASE_WITH_FILTER /
FULL) seçilebilir. Bizim katman: OCR, sıkıştırma, adlandırma, saklama.
0. [x] **ML Kit geçişi (ilk adım, ayrı commit; 2026-11-05 yapıldı — `ci/DocScan.kt`, kanal `dosya/docscan`, bayrak `scan_engine_v2` varsayılan açık, yedek = galeriden içe aktar; cihazda doğrulama CIHAZ_TESTI):** `ci/` altında Kotlin köprüsü (`GmsDocumentScanner`,
   `play-services-mlkit-document-scanner`; MethodChannel `scan.start` → PDF + JPEG yolları),
   `ci/prepare_android.sh` yaması + `tool/check_kotlin.sh` uyumu; Dart'ta `DocumentScanner.scanPages`
   yeni köprüye bağlanır, `cunning_document_scanner` pubspec'ten çıkar (bu ayrıca `permission_handler`
   ^13 engelini kaldırır — A3.4b). Play Services yoksa/ hata olursa **eski yedek akış** (galeriden
   içe aktar + elle kırpma, `scan_edit_screen`) devreye girer. Bayrak: `scan_engine_v2` (kapalıyken
   eski yol). R8 kuralı + `.r8test` A/B; APK boyutu bütçesi; 16 KB denetimi. Perf: tarayıcı
   ilk kullanımda kurulur, açılışta yok; sonuç JPEG'leri `cacheWidth` ile gösterilir.
   **Bitti:** cihazda tara → PDF; Play Services'siz cihazda yedek akış; CI yeşil.
1. [x] **Belge türü kipleri** (`scan_kind.dart`, stüdyoda hap seçici) (tara ekranında hap seçici): Belge · Kimlik/Ehliyet (ön+arka tek A4)
   · Kitap (çift sayfa → 2 sayfaya böl) · Makbuz/Fiş (uzun, ince) · Beyaz tahta · Kartvizit
   (OCR → kişi) · Fotoğraf. Her kip filtre/kırpma varsayılanını belirler.
2. [x] **Toplu inceleme ızgarası:** (stüdyo ızgara görünümü; yeni filtreler `vivid`/`shadowless`) sürükle-sırala, tek sayfa döndür/yeniden kırp/filtre
   (Orijinal · Otomatik · Gri · S/B · Renkli-canlı · Gölge-sil), sayfa sil, "sayfa ekle".
3. [x] **Akıllı çıktı:** (`scan_export.dart`, stüdyo → Dışa aktar) aranabilir PDF (mevcut OCR katmanı), Word'e (düzenlenebilir), Excel'e
   (tablo algılama → hücreler), TXT; PDF boyutu önizlemesi + kalite (Küçük/Orta/Yüksek).
4. [x] **Otomatik ad + klasör:** (`Taramalar` alt klasörü; kimlik → kasa önerisi; bulut seçeneği mevcut paylaş/taşı akışıyla) `scan_title` (var) ile tarih + ilk başlık; "Taramalar"
   klasörü; bulut/kasa seçeneği (kimlik taramaları kasaya önerilir).
5. [x] **İyileştirme:** (`scan_quality.dart`: Laplace keskinlik, parlaklık, izdüşüm eğikliği) `scan_enhance`/`scan_dewarp` kalite metrikleri (keskinlik, eğiklik) ile
   "yeniden çek" önerisi; düşük ışıkta fener önerisi.
6. [x] Test: sayfa işlem birim testleri (`scan_kind/export/quality/actions_test`, `test/perf/scan_perf_test`; cihaz turu CIHAZ_TESTI) (sıralama, böl, birleştir), PDF üretimi bayt testleri;
   cihaz: 10 gerçek belge (kağıt, fiş, kimlik, kitap, tahta) — `CIHAZ_TESTI.md`.
**Bitti ölçütü:** tek dokunuşla Belge→PDF; kimlik iki yüz tek sayfa; kitap iki sayfa böler;
OCR'lı PDF aranabilir; 20 sayfa < 15 sn işlenir (orta cihaz).

**Ek (2026-11-04):** 6. [x] Taramada tek tıkla "belge → önerilen eylem" (fatura → Faturalar/AI, kimlik → Kasa,
makbuz → Excel gider satırı). 7. [x] **Perf:** sayfa işleme tek izolatta, sırayla (eşzamanlılık
`PerfBudget`); önizleme `cacheWidth`; 30 sayfa PDF üretimi akışla (tüm JPEG'ler belleğe
alınmaz); OCR isteğe bağlı + arka planda, bitince bildirim. Ham JPEG'ler iş bitince silinir.
8. [x] Yeniden tara/ekle sırasında taslak kaydı (uygulama kapansa kaybolmasın). 9. [x] Dışa aktarma kuyruğu `JobQueue`'da
(ilerleme, iptal, sonuç sayfası — A5 deseni).
**Faz 35 notları (2026-11-05):** ek 6 = öneri şeridi (kimlik → Kasa, fiş/fatura → `Giderler.csv`;
fatura → AI özet ayrı iş). Ek 7: işler izolatta sırayla, önizlemeler `cacheWidth`'li, ham/ara JPEG'ler
ev temizliğinde (`docscan`, `_kalite_`, `_kimlik_`, `_kitap_`); **açık kalan:** `pdf` paketi sayfaları
kayda dek bellekte tutuyor — 30 sayfa "akışla" üretim yapılmadı (ölçüm sonrası gerekirse ayrı iş).
Ek 8: stüdyo her değişikliği PDF'e kendiliğinden yazıyor + arka plana geçerken bekleyen yazılıyor (taslak = PDF).
Ek 9: dışa aktarma `TrackedTask` → `JobQueue` (ilerleme, iptal, bitince bildirim).

## Faz 36 — Excel — BİTTİ 2026-11-05 (kod; cihaz doğrulaması CIHAZ_TESTI.md'de, perf A/B bekliyor)
- [x] 1. Özet tablo (pivot) oluştur/yenile (satır/sütun/değer/süzgeç, topla-say-ort) — xlsx
   `pivotCache` yazımı veya salt "değer anlık görüntüsü" ilk sürüm.
   (`services/xlsx/pivot.dart` değer anlık görüntüsü + "Özeti yenile"; Veri sekmesi.)
- [x] 2. Koşullu biçim yazma: renk ölçeği, veri çubuğu, simge kümesi, formül kuralı (A7.5).
   (`XlsxCondRuleWrite` görsel gövdeler + `expression`; ızgarada simge/formül boyama; `xlsx_cond_write_test`.)
- [x] 3. Mini grafik (sparkline) çiz + yaz (`x14:sparklineGroups`).
   (okuma + yazma + hücre içi çizim — çizgi/sütun/kazanç-kayıp; Ekle sekmesi.)
- [x] 4. Formül: yardım balonu + otomatik tamamlama + hata açıklaması ("#DEĞER! neden"),
   dinamik diziler (FILTER/SORT/UNIQUE), XLOOKUP, LET, SEQUENCE.
   (Balon/tamamlama/XLOOKUP vardı; `FormulaArray` + taşma (`CalcState._spills`), dizi bağlamı,
   LET, `formula_errors.dart` + formül çubuğunda "?" düğmesi.)
- [x] 5. Tablo nesnesi (ListObject) + biçimli tablo stilleri, yapısal başvuru.
   (ListObject yazımı vardı; tablo adı + vurguya göre yerleşik stil, dosya tablolarını okuma
   `xlsx/table_reader.dart`, `Tablo1[Sütun]`/`[@Sütun]`/`[#Veri]`/`[[#Başlıklar],[X]]` çözümü.)
- [x] 6. Yazdırma düzeni + PDF'e aktar (sayfa sığdır, başlık satırı yinele), parola ile aç/koru.
   (`xlsx/sheet_pdf.dart`; ECMA-376 Agile AES-256 `office_crypto.dart` + CFB yazıcı `ole_cfb_writer.dart`.)
- [x] 7. Görünüm: şerit sadeleştirme, hücre düzenleme çubuğu, parmakla seçim tutamakları,
   kaydırmada sabit başlık gölgesi, yoğunluk (kompakt/rahat) ayarı.
   (Düzenleme çubuğu + tutamaklar vardı; sade şerit, başlık gölgesi, yoğunluk — tercihler kalıcı.)
**Ölçüt:** 5 örnek gerçek dosyada yaz→aç döngüsü kayıpsız (B4 uyumluluk turu).

**Ek:**
- [x] 8. Veri: CSV/ods içe aktar sihirbazı (ayraç/kodlama/tür önizleme), yinelenenleri kaldır,
metni sütunlara böl, ara toplam, gruplama/anahat, hücre notları/yorum dizisi, köprü + sayfa bağı.
   (Yinelenen/böl/not vardı; `xlsx/data_tools.dart` içe aktar + ODS + ara toplam (SUBTOTAL iç içe
   saymaz) + anahat (`outlineLevel` okuma/yazma) + not yanıtı; köprü `XlsxLinkWriter`.)
- [x] 9. Biçim boyacısı, koşullu biçim yöneticisi, hücre stilleri galerisi, tema renkleri.
   (Stil galerisi vardı; boyacı tek dokunuşluk, yönetici dosya kurallarını da siler (`condRemovals`),
   renk seçicide `xlsx/theme_palette.dart` tema ızgarası.)
- [x] 10. Formül denetimi (öncül/ardıl oklar), döngüsel başvuru uyarısı, "Ne-olursa" (hedef ara).
   (`formula_audit.dart`: öncül/ardıl + kiriş/ikiye bölme çözücü; oklar ızgara üstü salt çizim;
   döngü yazınca uyarı.)
- [x] 11. Grafik: kombinasyon, ikincil eksen, eğilim çizgisi, grafik stilleri; grafiği görüntü/PDF paylaş.
   (`XlsxChartSpec.combo/secondaryAxis/trendline/style` → c:lineChart + 2. eksen çifti, c:trendline;
   önizleme `ChartPainter` aynı bayraklarla; PNG/PDF paylaş `pro_chart.dart`.)
- [x] 12. Çok kişilik: sayfa/aralık koruma; yazdırma alanı. **Perf:** hesaplama **bağımlılık grafiği +
kirli hücre** (tam yeniden hesap YOK), pivot/büyük yapıştır izolatta, görünür pencere dışı hücre
çizilmez (mevcut sanal ızgara korunur), `excel_perf_test` 100 bin satır eşiği eklenir; grafik/sparkline
yalnız görünürken boyanır.
   (Koruma: 16 bit özet yazılır, dosyadaki SHA-512 doğrulanır; `protectedRanges` = düzenlenebilir aralık;
   `_xlnm.Print_Area` → `xlsx/print_area_writer.dart`. Perf: kirli hücre `CalcState` zaten vardı — 100 bin
   satır testi; pivot ve büyük yapıştırma izolatta; grafik pencere dışında boyanmaz, mini grafik sanal
   ızgara hücresinde.)

## Faz 37 — Word
- [x] 1. Stil galerisi (Başlık 1–3, Alıntı, Liste) + "stili güncelle"; belge teması/yazı tipleri.
   (`docx/pro/docx_style_ops.dart`: stile taşı + 5 tema; Giriş > Stiller; `word_pro_style_test`.)
2. Sayfa düzeni ekranı (kenar boşluğu, yön, boyut, sütun, sayfa kesmesi), yazdır önizleme.
3. Denklem düzenleyici (OMML yaz/oku, temel LaTeX girişi), tablo: hücre birleştir/böl,
   kenarlık/gölge, otomatik sığdır, sıralama.
4. Şablonlar (CV, mektup, rapor, fatura, tutanak) — "Yeni belge" sayfasına galeri.
5. Karşılaştır/birleştir iki belge; yorum+değişiklik gezinme çubuğu; belge parolası.
6. Sesle yazma (cihaz STT) ve AI ile yeniden yaz/özetle/çevir (Gemini var) — satır içi.
7. PDF/Docx dışa aktarım kalitesi: sayfa kırılımı, yazı tipi gömme.
**Ölçüt:** 5 gerçek docx düzen kaybı olmadan açılıp kaydedilir.

**Ek:** 8. Gezinti bölmesi (başlık ağacı), sayfa küçük resimleri, kelime sayacı, okuma süresi.
9. Madde/numara çok düzeyli, sütun, kenarlık, metin kutusu, şekil, görsel sarma (satır içi/üstte/arkada),
başlık/kapak sayfası, bölüm sonu, farklı ilk sayfa, alan kodları (tarih, sayfa), çapraz başvuru, kaynakça.
10. Yazım/dilbilgisi (var olan yazım denetimi + AI düzeltme önerisi satır içi, kullanıcı onaylı).
11. Okuma kipi (yeniden akış) + gece kipi; PDF/ODT/RTF/MD dışa aktarma kalitesi. **Perf:** sayfa
düzeni **artımlı** (yalnız değişen paragraf ve sonrası), görünür sayfa ±1 çizilir, `word_perf_test`
500 sayfa eşiği; yazım denetimi izolatta ve boşta; görsel `cacheWidth`; AI çağrıları iptal edilebilir.

## Faz 38 — Slayt
1. Ana slayt/yerleşim (master/layout) düzenleme: yer tutucu, tema renk/yazı tipi.
2. Şablon galerisi (8 sade tema) + "metinden slayt" (`text_to_slides`, var) için tasarım önerisi.
3. Slayt içi grafik ekle/düzenle (tablo verisinden), SmartArt → düzenlenebilir şekil grubu.
4. Ses/video ekleme + oynatma, sunum kipinde lazer işaretçi, kalem, zamanlayıcı.
5. Sunucu görünümü (not + sonraki slayt + süre), PDF/PNG/video dışa aktarım.
6. Yardımcı çizgi/hizalama/dağıt, katman paneli, animasyon sırası paneli.
**Ölçüt:** 5 gerçek pptx görsel fark < eşik (B4); sunum kipi 60 fps.

**Ek:** 7. Slayt sıralayıcıda sürükle-bırak, bölüm (section) grupları, gizli slayt, özel gösteri.
8. Şekil kitaplığı, bağlayıcı çizgiler, gradyan/gölge/yansıma, görsel kırpma/şekle kırp, arka plan
kaldırma (ML Kit, isteğe bağlı), tablo biçimleri, bağlantı/eylem düğmeleri, canlı sayaç.
9. Sunum: uzaktan kumanda (ses tuşları/yerel ağ), kayıtlı anlatım, HDMI/Cast ikinci ekran notları.
**Perf:** küçük resimler tek kez üretilir ve önbellekte (`slide_image_budget_test` korunur),
yalnız görünür slayt tam çizilir, sunum kipinde sonraki slayt önceden rasterize, geçiş animasyonları
`RepaintBoundary` içinde; hafif profilde karmaşık geçişler sadeleşir; `slides_perf_test` 300 slayt eşiği.

## Faz 39 — PDF — BİTTİ 2026-11-05 (kod; cihaz doğrulaması CIHAZ_TESTI.md'de, perf A/B bekliyor)
- [x] 1. **Dijital imza (PKCS#7)** — kullanıcı sertifikası/self-signed, görünür imza alanı.
   (`services/pdf_digital_sign.dart` + `pdf/der.dart`; Pro araçlar levhası.)
- [x] 2. Kalıcı karartma (redaction) — metin+görüntüyü gerçekten siler, doğrulama testi.
   (`pdf_redact.dart` + `pdf_raster.dart` + `pdf_region_screen.dart`; `test/pdf_redact_test.dart`.)
- [x] 3. Tablo çıkarma → Excel; sayfa metnini Word'e (düzen korunarak); PDF/A dışa aktarım.
   (`pdf_export_pro.dart`; PDF/A-2b `PdfRedact.apply(conformance:)` görüntü + görünmez metin kipi.)
- [x] 4. İki PDF karşılaştırma (görsel fark + metin farkı).
   (`pdf_compare.dart` + `pdf_compare_screen.dart`.)
- [x] 5. Parola/izin düzenleme, yer imi düzenleme, damga/filigran şablonları, numaralandırma.
   (`pdf_doc_pro.dart`: izinler AES-256, yer imi ağacı, 7 damga şablonu + filigran, Bates/Romen/n-N.)
- [x] 6. Okuma: gece kipi (A9.2), kaydırma kilidi, çift sayfa/kitap görünümü, sesli okuma
   (var), metin işaretleme kitapçığı (tüm vurgular tek listede dışa aktar).
   (Gece kipi vardı + kâğıt/sepya tonu; `viewer/pdf_reading_pro.dart`, `pdf_notes.dart`.)
- [x] 7. Agresif sıkıştırma (A7.4).
   (DPI 96/120/150 + kalite + gri + görünmez metin; 40 sayfalık parçalarla, bellek tavanlı.)
**Ölçüt:** imzalı PDF Adobe/Chrome'da geçerli görünür (cihaz dışı doğrulama 💻).

**Ek:**
- [x] 8. Sayfa küçük resim ızgarasında çoklu seç → döndür/sil/çıkar/yeniden sırala (var olanı
genişlet), boş sayfa algıla ve sil, sayfaları kırp/boyutlandır, A4'e sığdır.
   (`pdf_page_pro.dart`, `pdf_reorder_screen.dart`; kırpma bölge ekranının `crop` kipi.)
- [x] 9. Formlar: alan vurgusu, otomatik doldurma profili (ad/adres), düzleştir, form oluştur (metin/onay/imza).
   (Vurgu `PdfFormOverlay` + düzleştirme vardı; `pdf_form_pro.dart` profil/eşleme/alan ekleme.)
- [x] 10. Notlar: metin vurgusu/çizgi/not özeti dışa aktar; metinde ara + sonuç listesi + OCR'lı taranmış PDF'te ara.
   (`pdf_notes.dart` Markdown kitapçık — görüntüleyici + Pro araçlar; arama çubuğunda sonuç listesi; OCR arama vardı.)
- [x] 11. Görüntüden PDF / PDF'ten görüntü toplu, web sayfasından PDF, PDF'e Word/Excel/PPT aktarım.
   (`office_html.dart` + `Printing.convertHtml`; toplu JPEG klasörü 40'lık parçalarla.)
- [x] 12. İmza yönetimi: kayıtlı imza/paraf/tarih/damga, toplu "her sayfaya paraf".
   (`PdfDocPro.initialPages` tek geçiş; Pro araçlar → İmza ve paraf yönetimi.)
**Perf:** sayfalar
tembel render (görünür ±1, kova cacheWidth), metin çıkarma **istek üzerine** (P4 korunur),
karartma/sıkıştırma/OCR/karşılaştırma `JobQueue` + izolat, 500 sayfa PDF'te bellek tavanı
testi, küçük resim şeridi yalnız açıkken üretilir.

## Faz 40 — Ortak görünüm ve deneyim
1. **Tasarım dili:** tüm editör üst çubukları tek yapı (başlık · kaydet · geri/ileri · ⋮),
   alt araç şeridi kaydırılabilir + bağlama duyarlı (seçime göre).
2. Animasyon/hareket: sayfa geçişleri `Motion` tokenlarıyla; boş durum çizimleri.
3. Erişilebilirlik: 2× yazı, TalkBack etiketleri, kontrast denetimi (token bekçisi).
4. Onboarding: ilk açılış 3 ekran (okuyucu · düzenleyici · tara) + örnek belgeler.
5. Ayarlar sadeleşmesi: arama kutusu, gruplar, "önerilenler".
**Ölçüt:** token bekçisi yeşil; 2× yazıda taşma yok (widget testleri).

**Ek:** 6. Ortak geri al/yinele ve taslak kurtarma altyapısı (SaveIsolate/EditorChrome üzerine) tüm
editörlerde aynı davranış; kapanışta otomatik kaydet güvencesi. 7. Tek "Paylaş/Dışa aktar" sayfası
(PDF, docx/xlsx/pptx, görüntü, bağlantı). 8. Tema: açık/koyu/AMOLED/kâğıt, vurgu rengi,
yazı ölçeği ön ayarları. 9. Dil: TR/EN/AR (RTL bekçisi korunur) eksik çeviri taraması.
10. Boş/hata/yükleme durumları için iskelet (nabız hafifte kapalı) ve tek tip hata sayfası.
**Perf:** hiçbir ortak bileşen `saveLayer`/geniş blur eklemez; token bekçisi ve hareket bekçisi
yeşil; ortak bileşen değişince pano boşta-kare ve kaydırma ölçümü yenilenir.

## Faz 41 — Dosya yöneticisi ve bulut
1. Çift bölme (A7.1), SD kart SAF yazma (A7.2), toplu yeniden adlandırma şablonları.
2. Drive: çevrimdışı kopya, çakışma çözümü, OneDrive/Dropbox (hesap kararı 👤).
3. Arama: içerik içi arama (OCR dahil) dizini, kayıtlı aramalar, akıllı klasörler.
4. Paylaşım: kısa ömürlü bağlantı (yerel ağ), QR ile aktar (var) → toplu.
**Ölçüt:** 50 bin dosyada arama < 1 sn (dizinli).

**Ek:** 5. Çöp kutusu/kasa/yinelenenler/büyük dosya temizleyici akıllı öneriler (var olan
Yer aç sekmesi); 6. Etiket + renk + favori klasör; 7. Arşiv: 7z/rar okuma, parola, bölünmüş zip;
8. Yerel ağ: SMB/FTP/WebDAV istemci. **Perf:** dizin (indeks) **artımlı** ve olay güdümlü,
arka planda düşük öncelik, pil tasarrufunda duraklar; `fs_sort_perf_test` ve gezgin liste önbelleği
(P8/G13) korunur; küçük resim üretimi eşzamanlılığı `PerfBudget`te.

## Faz 42 — Kalite, performans, yayın
1. Başlangıç süresi/APK boyutu bütçeleri (CI var) — yeni bağımlılık eklenince bütçe kontrolü.
2. Büyük dosya: 100 MB xlsx/pdf akış okuma, bellek tavanı testleri.
3. Çökme günlüğü → "bildir" akışı; A8 ölçüm altyapısı.
4. Sürüm adayı turu (B6) ve mağaza varlıkları.

**Ek:** 5. Otomatik perf gerileme kapısı: CI'da `flutter test --tags perf` eşikleri + APK boyutu
tabanı (artış %2'yi aşarsa kırmızı). 6. `integration_test` cihaz senaryoları (P13): soğuk açılış,
5.000 öğe kaydırma, 100 sayfa PDF, 100 bin satır xlsx — `tool/make_test_tree.py` verisiyle.
7. Çökme/ANR ve yavaş kare (`KARE` günlüğü) için kullanıcı onaylı anonim özet (A8).
8. R8/obfuscate kuralları: ML Kit ve yeni yerel köprüler için kural ekle, `.r8test` yan yana A/B.

## Sıra önerisi
**34 → 35 (tarayıcı) → 39 (PDF imza/karartma) → 36 (Excel) → 37 (Word) → 38 (Slayt) → 40 → 41 → 42.**
Gerekçe: tarama ve PDF en sık kullanılan, kullanıcıya en görünür; Excel/Word/Slayt gerçek
dosya uyumluluğu (B4) cihaz/Windows turuna bağlı. Her faz ayrı commit dizisi, CI yeşil,
HAFIZA kaydı, `KALANLAR.md`'den madde silme.
