# PDF PRO PLANI — Profesyonel PDF düzenleyici (Faz 51–68) · 2026-11-08

Kullanıcı isteği (2026-11-08, 6 ekran görüntüsüyle):
*"İstediğim profesyonel bir PDF düzenleme programı olmak, en iyisi olmak. Basit iş istemiyorum;
zor, karmaşık, uzun sürecek, detaylı bir çalışma istiyorum. Önce detaylı araştırma. Yarım iş,
eksik, 'bunu başka zaman yaparız' istemiyorum. Görsel tasarımda da detay ve temizlik; performansa
dikkat. Piyasadaki en iyi PDF düzenleme aracı olmak için ne gerekiyorsa. İstediğin sayıda faz
belirle; test cihazını da bağlayabiliriz."*

Bu belge: (1) bildirilen 6 sorunun **kodda bulunmuş kök nedenleri**, (2) rakip ve teknik
araştırma, (3) **mimari karar** (neden şimdiki motor tavana dayandı, yerine ne geliyor),
(4) her biri ölçülebilir "bitti" ölçütlü **18 faz**, (5) ortak kurallar ve cihaz kapıları.

> Geçerli kurallar: `GELISTIRME_PLANI.md` → **Performans Koruma Anayasası (1–10)**, tasarım
> tokenı bekçileri (AppHues, `context.type`, Motion, `showAppSheet`, `AppColors`), üç dil
> (TR/EN/AR), KVKK (külliyata kullanıcı belgesi GİRMEZ), CLAUDE.md §4 faz istisnası
> (`faz-NN` dalı → PR → CI yeşil + cihaz kapısı → main).

---

## 1. Bildirilen sorunlar ve kök nedenleri (kod taraması, `main` @ `2797180`)

| # | Kullanıcının gördüğü | Kök neden (kodda) |
|---|---|---|
| **PS1** | Seçip "Düzenle" deyince seçim kayboluyor; tüm sayfa yeniden taranıp çerçeveleniyor, yeniden seçmek gerekiyor | `viewer/pdf_selection.dart:83` `onEdit` yalnız **sayfa numarasını** geçiriyor; seçim dikdörtgeni/metni atılıyor. `PdfEditorScreen` ayrı bir ekran + **ayrı çalışma kopyası** açıyor, sayfayı baştan çözümlüyor (`pdf_editor/actions.dart:49 _loadOutline`) ve bütün blokları çerçeveliyor. Seçim → paragraf eşlemesi hiç yok. |
| **PS2** | Düzenledikten sonra yazı tipi ve boyutu hep değişiyor (ekranda "taşımaktadır." → minik "taşımak") | Üç ayrı neden üst üste: **(a)** Word çıktısı bu belgede paragraf motoru satırların çoğunu tanıyamıyor; `actions.dart:186 _ocrEditable` sayfada **tek bir görsel** (logo) varsa tanınmayan her satıra **OCR "taranmış satır"** kutusu açıyor → doğal metin OCR yoluyla düzenleniyor: beyaz kutuyla örtüp **Carlito** ile yazıyor, punto da OCR kutusunun yüksekliğinden tahmin ediliyor (`layer.dart:516 box.height / 1.2`) → boyut ve yazı tipi bozuluyor. **(b)** Doğal yolda alt küme (subset) fontta yeni harfin glifi yoksa (Türkçe ğ/ş/ı/İ tipik) `pdf_page_edit.dart:226 paragraphFontProgram` null dönüyor → bütün paragraf Carlito/Tinos'a düşüyor. **(c)** Düzenleme alanı belgenin fontuyla değil **her zaman Carlito** ile çiziliyor (`widgets/pdf_object_layer.dart:487, :559`) → yazarken gördüğün, sonuçla aynı değil. |
| **PS3** | Kaydedince alttaki "açmak için Aç'a basın" çalışmıyor; kopya doğrudan açılmalı ve Belgeler'e hemen düşmeli | `widgets/pdf_save_dialog.dart:97 _announce` eylemi **editör ekranının `context`**'iyle `EntryOpener.open` çağırıyor; kayıttan hemen sonra editör kapanıyor (`navigator.pop(true)`) → bildirim küresel katmanda yaşamaya devam ediyor ama `context.mounted == false` → dokunuş sessizce boşa gidiyor. Kopya son dosyalar/Belgeler listesine eklenmiyor (yalnız `ActivityLog`). Görüntüleyici dönüşte **özgün** dosyayı tazeliyor, kopyayı değil. |
| **PS4** | Düzenlerken sayfa uzaklaşıyor (zoom out), yazma/düzenleme akışı kötü | **(a)** `EditorChrome` `resizeToAvoidBottomInset: true` (`core/edit/editor_chrome.dart:291`) → klavye açılınca görüntüleyicinin boyu küçülüyor, pdfrx sayfayı yeni boya "sığdırıyor" (ekran görüntüsü 5: sayfa pul gibi). **(b)** Her uygulamada `_syncDocument` (`actions.dart:140`) bütün belgeyi diske yazıp pdfrx'e **baştan yükletiyor** (`PdfReload.reloadFile` → `forceReload`) — yakınlaştırma/konum/odak kaybı + saniyeler. **(c)** `_zoomToParagraph` yalnız paragraf için; OCR satırında hiç yakınlaşma yok. |
| **PS5** | Uzun seçimde altta neyi seçtiğimiz yarıda kesiliyor, görmek mümkün değil | `pdf_selection.dart:70` önizleme `_shorten(_pdfSelection, 34)` — **34 karakterde** kesiliyor; genişletme yok. Çubuk sayfanın altına sabit, seçimin alt kısmını örtüyor. |
| **PS6** | Düzenleme menüsü güzel değil | 8 sekmeli `OfficeRibbon` + yongalar (Metin · Görsel · İmzala · Form · Çiz · AI · Filigran · Sayfa); çoğu sekmede tek yonga, bağlama göre değişen araç çubuğu yok; Çiz/İmza/Form/Sayfa işleri ayrı ekranlara gidiyor (`pdf_ink_screen`, `pdf_sign_screen`, `pdf_form_screen`, `pdf_tools_screen`, `pdf_reorder_screen`). Her satırın gri çerçeveyle kaplanması sayfayı kalabalıklaştırıyor (ekran görüntüsü 1). |

**Ortak kök:** düzenleyici, görüntüleyiciden kopuk ikinci bir ekran + "her adımda belgeyi baştan yaz
ve baştan yükle" döngüsü + tanıyamadığı metni sessizce OCR'a havale eden, kendi yazdığımız sınırlı
bir içerik akışı ayrıştırıcısı üzerine kurulu. Yamalarla "en iyi" olunamaz → **§3 mimari karar.**

---

## 2. Araştırma özeti

### 2.1 Rakipler (mobil) — ne yapıyorlar
- **Adobe Acrobat (Android):** alt menüden *Edit PDF*; metin bloğuna dokununca yerinde düzenleme;
  yazı tipi/boyut/renk/hizalama, madde işaretli/numaralı liste, görsel taşı/boyutlandır/kırp,
  geri al/yinele (üst çubuk), ✓ ile bitir; mobilde metin düzenleme **ücretli**; taranmış belgede
  düzenleme ve otomatik font eşleştirme ücretli katmanda. [A1][A2][A3]
- **Foxit PDF Editor:** metin + görsel nesne düzenleme, OCR (el yazısı dâhil), gerçek redaksiyon,
  imza; hepsi abonelik ($6,99/ay, $39,99/yıl — ABD). [F1]
- **PDFelement:** **satır kipi / paragraf kipi** tek dokunuşla; paragraf tanıma eklenen metinle
  biçimi korur; font tanıma (yazı tipi + punto) ve eklenen metne uygulama; blokları sürükleyip taşıma;
  **taranmış PDF düzenlemiyor**; ücretsiz çıktı filigranlı. [P1][P2][P3]
- **Xodo:** açıklama/form güçlü, mevcut metin düzenleme sınırlı (kullanıcı yorumları: "sayfayı görüntü
  gibi ele alıyor"). [X1][X2][X3]
- **Nutrient (PSPDFKit) SDK — profesyonel referans:** satırları paragrafa gruplar, paragraf **tek
  varlık** olarak düzenlenir; yerel Android metin girişi (seçim tutamaçları, donanım klavyesi);
  klavye üstü çubukta renk, yazı tipi, punto, kalın/italik; paragraf oluştur/sil, kopyala/yapıştır
  (stil dâhil), **sürükle-bırak taşıma ve boyutlandırma**, sola/orta/sağa/iki yana hizalama; geri
  al/yinele; sınırlar: yalnız LTR, IME bileşik girişi yok. [N1]

**Çıkarım:** piyasada "mevcut metni gerçekten, aslına uygun, ücretsiz" düzenleyen mobil uygulama
yok; hepsi ya ücretli ya sınırlı. Bizim fark yaratabileceğimiz yer: **(1)** yazı tipine sadakat
(Türkçe harf eksikliği dâhil), **(2)** IME/Türkçe klavye ve RTL (Arapça) desteği — Nutrient'ın bile
yapmadığı, **(3)** taranmış belgede arka plan rengini koruyan düzenleme, **(4)** tek yüzey (okurken
düzenle, ekran değişmeden), **(5)** hepsi ücretsiz ve çevrimdışı.

### 2.2 Teknik — kritik bulgu: PDFium düzenleme API'si zaten uygulamada
- pdfrx 2.12 → `pdfium_flutter 0.4.1` → **`pdfium_dart 0.4.1`**: ffigen ile üretilmiş tam PDFium C API'si.
  Doğrulanan işlevler (pub.dev `PDFium` sınıfı) [D1]: `FPDFText_SetText`, `FPDFPageObj_NewTextObj`,
  `FPDFText_LoadFont`, `FPDFTextObj_GetFont`, `FPDFTextObj_GetText`, `FPDFFont_GetBaseFontName`,
  `FPDFFont_GetFamilyName`, **`FPDFFont_GetFontData`** (gömülü font programını okur),
  `FPDFFont_GetGlyphWidth`, `FPDFText_GetTextObject` (karakter → içerik nesnesi), `FPDFPage_InsertObject`,
  `FPDFPage_RemoveObject`, `FPDFPageObj_Transform`, `FPDFPageObj_GetBounds`, **`FPDFPage_GenerateContent`**,
  **`FPDF_SaveAsCopy` / `FPDF_SaveWithVersion`** (`FPDF_INCREMENTAL` bayrağı → özgün baytlar korunur),
  `FPDFAnnot_*` (gerçek PDF açıklamaları).
- PDFium, Foxit'in motorunun açık kaynak kolu; düzenleme API'si tam bu iş için. Kural: kaydetmeden ya
  da sayfayı yeniden yüklemeden önce `FPDFPage_GenerateContent` çağrılmazsa değişiklik kaybolur [D2].
- pdfrx_engine 0.9 zaten sayfa yeniden dizme, belge birleştirme ve `encodePdf` yapıyor → PDFium'u
  **görüntüleyicinin açık belgesi üzerinde** düzenlemek için örnek desen mevcut.
- **Ek APK maliyeti yok** (pdfium .so zaten var; yalnız Dart kodu). Native C derleyici tuzağı (HAFIZA
  Faz 48): PDFium'lu testler Windows'ta derlenmez → CI (Linux) koşar.
- Yazı tipi gösterimi için referans: pdf.js'in font "onarma" yaklaşımı (gömülü alt küme fontlara
  ToUnicode + kodlamadan Unicode `cmap` kurmak, çıplak CFF'yi OpenType'a sarmak) — Dart'ta yeniden
  yazılır (yalnız yöntem; kod kopyalanmaz).
- Şimdiki motorun durumu: ~19.400 satır PDF kodu; içerik akışı ayrıştırıcı + paragraf motoru +
  artımlı yazıcı (`pdf_syntax`, `pdf_paragraph`, `pdf_paragraph_layout`, `pdf_page_context`);
  emek değerli (satır sarma, iki yana yaslama, artımlı xref akışı, ObjStm) ama **okuma tarafı**
  (Type0/CID, çok alt kümeli Word fontları, Type3, döndürülmüş metin, RTL) tavanda.

---

## 3. Mimari kararlar (PK = PDF Pro Kararı)

- **PK1 — Tek motor: PDFium nesne düzeyi düzenleme, görüntüleyicinin açık belgesinde.** Okuma
  (karakter, kutu, font, punto, renk, nesne eşlemesi) ve yazma (metin nesnesi değiştir/ekle/sil,
  `GenerateContent`, artımlı kaydet) PDFium'la. `pdfrx_engine` `third_party/`'ye alınır (pdfrx gibi,
  `YAMA.md` ile) ve düzenleme işleri **pdfrx'in kendi PDFium işçisinde, aynı kilitle** koşar
  (PDFium iş parçacığı güvenli değil; ikinci izolatta paralel çağrı YASAK).
  **Karar kapısı Faz 52:** külliyatta PDFium yolu şimdiki motoru başarı oranı, değişmeyen bölgede
  piksel farkı (=0), çıktı büyümesi ve gecikmede **geçemezse** PK1 iptal; şimdiki motorun okuma
  tarafı PDFium karakter verisiyle güçlendirilir (PK1-B). Sonuç HAFIZA'ya.
- **PK2 — Düzenleme belgeyi yeniden yüklemez.** Değişiklik bellekteki sayfaya uygulanır, yalnız o
  sayfanın görüntü önbelleği geçersiz kılınır → yakınlaştırma, kaydırma, odak, seçim yerinde kalır.
  Hedef: uygula → güncel pikseller p95 ≤ 250 ms (MatePad), ≤ 400 ms (hafif profil).
- **PK3 — Tek yüzey.** Düzenleme, görüntüleyicinin bir **kipi** (Acrobat'taki gibi): ekran değişmez,
  çalışma kopyası dosyası yok; kaydedilmemiş değişiklik bellekte + çökme günlüğünde. `PdfEditorScreen`
  ayrı ekranı Faz 54'te emekliye ayrılır (tek düzenleme yolu — FAZ_PLANI D3 dersi).
- **PK4 — Paragraf birimi korunur (2026-07-27 kullanıcı kararı)**, yanına **satır kipi** gelir
  (PDFelement). Özgün baytlara dokunulmaz kararı da korunur: kayıt **artımlı** (`FPDF_INCREMENTAL`).
- **PK5 — Yazı tipi sadakati sırası:** (1) belgenin kendi gömülü fontu (glif varsa) → (2) **glif
  bazlı yedek**: yalnız eksik harfler, metrik uyumlu aileden, büyük harf yüksekliği eşlenmiş →
  (3) kullanıcı isterse tüm paragraf eşleşen aileyle. Paragrafın tamamını sessizce başka fonta
  geçirmek YASAK. **Beyaz kutuyla örtme doğal metinde YASAK** (yalnız taranmış sayfada, örneklenen
  arka plan rengiyle — Faz 62).
- **PK6 — Gördüğün = yazılan (WYSIWYG).** Düzenleme alanı belgenin gerçek fontuyla (onarılıp Flutter'a
  yüklenmiş) çizilir; satır sonları yazıcıya Flutter'ın dizgisinden aktarılır → ekrandaki ile PDF'teki
  satır kırılımları birebir. Onarılamayan font (Type1/Type3/bozuk) → PDFium canlı bölge çizimi +
  bizim imleç katmanı (Faz 57 prototipiyle seçilir).
- **PK7 — Sessiz geri düşüş yok.** Motor bir bloğu düzenleyemiyorsa kullanıcıya nedeni ve seçenekleri
  gösterilir (eşleşen fontla yaz · satır kipine geç · üstüne yeni metin kutusu); OCR yalnız gerçekten
  taranmış bölgede açılır (logo içeren doğal sayfada ASLA).
- **PK8 — Her şey ölçülür.** Külliyat + ölçüm tezgâhı CI'da koşar; her faz sayılarla biter
  (`docs/perf/2026-11-pdfpro-<faz>.md`). Sayı uydurma yok; ölçülemeyen "bekliyor" yazılır.

---

## 4. Ortak kurallar (bütün fazlar)

1. **Dal/PR:** `faz-NN` dalı, her madde ayrı commit, planda `[x]`; PR → CI yeşil + (varsa) cihaz
   kapısı → main. Uygulamayı değiştiren birleşmede APK otomatik (faz PR'ı).
2. **Ortam etiketi:** ☁️ bulutta yapılır (doğrulama CI) · 💻📱 yerel Windows + USB'li telefon
   (`C:\src\flutter-3479`, yerel test serbest — YUKSELTME §0 düzeni). Etiketsiz madde ☁️.
3. **Performans anayasası** + bu plana özel bütçeler (§6). Yeni ağır iş ana iş parçacığında koşmaz;
   PDFium çağrıları yalnız pdfrx işçisinde.
4. **Tasarım:** her yeni yüzey Faz 53 tasarım diline uyar; açık/koyu/AMOLED, telefon/tablet, RTL;
   golden testler (`test/golden/pdf_pro/`).
5. **Dil:** her yeni metin TR/EN/AR (`lib/core/l10n/strings/2x_pdf_*.dart`).
6. **KVKK:** külliyat yalnız kendi ürettiğimiz/telifsiz belgeler; kullanıcı belgesi depoya girmez
   (yerel külliyat klasörü `.gitignore`'da, yalnız sayılar raporlanır).
7. **Test:** her motor maddesi birim test + külliyat ölçümü; her UX maddesi widget testi + cihaz
   maddesi (`docs/CIHAZ_TESTI.md` "PDF Pro Faz NN").
8. **Bitti:** maddeler `[x]` · CI yeşil · ölçüm raporu · cihaz kapısı (💻📱 fazlarda) · HAFIZA
   (karar/kök neden/tuzak) · KALANLAR güncel · `graphify update .`.

---

## 5. Fazlar

Sıra bağımlılığa göre. ☁️ = bulut, 💻📱 = yerel + cihaz. Tahmini süre oturum sayısıdır.

### Faz 51 — Temel: külliyat, ölçüm tezgâhı ve kanamayı durdurma ☁️ + 📱 (2–3 oturum)
Amaç: bundan sonraki her kararı sayıyla vermek ve bildirilen sorunların hızlı kısmını hemen gidermek.
1. [x] **Külliyat** `test/fixtures/pdf_corpus/` (≥ 60 PDF, her biri ≤ 300 KB, Türkçe karakterli,
       kişisel veri yok): Word (Windows'ta "PDF olarak kaydet" — 💻 kullanıcı üretir, sentetik metin),
       LibreOffice, Google Docs, Chrome/Skia (headless baskı), Syncfusion, `pdf` paketi, ReportLab,
       LaTeX, Quartz benzeri; çok sütunlu, tablolu, listeli, iki yana yaslı, döndürülmüş sayfa, Arapça
       (RTL), Type3 fontlu, şifreli (sahip parolalı), formlu, taranmış + OCR katmanlı, karma (logo +
       metin — PS2'nin birebir benzeri). `CORPUS.md`: üretici, özellik, beklenen paragraf sayısı.
2. [x] **Ölçüm tezgâhı** `tool/pdf_pro_bench.dart` + `test/pdf_pro/bench_test.dart` (CI'da):
       paragraf kapsaması (% karakter düzenlenebilir blokta), düzenleme başarı oranı (her paragrafı
       değiştir → yeniden çıkar → metin doğru mu), **değişmeyen bölge piksel farkı** (PDFium çizimi,
       blok kutusu + 2 pt dışında 0 olmalı), font sadakati (yedek fonta düşen harf oranı, `.notdef`
       sayısı = 0), çıktı büyümesi, gecikme. Bağımsız doğrulama: CI'da `qpdf --check` + `mutool draw`
       (ikinci çizici) — kurulum CI adımına.
3. [x] **Taban raporu** `docs/perf/2026-11-pdfpro-51-taban.md`: şimdiki motorun sayıları (ileride
       karşılaştırma tabanı).
4. [x] **PS3 düzeltmesi:** kayıt bildirimi kök gezgin anahtarıyla açar (ekran kapansa da çalışır);
       bildirimin gövdesine dokunmak da açar; kopya **son dosyalar + Belgeler** listesinin başına
       anında düşer (`AppState.addRecent` + `FsEvents.changed`, genel klasörse MediaStore taraması);
       görüntüleyici kopya kaydedildiyse **kopyayı** açar. Test: bildirim eylemi editör kapandıktan
       sonra dosyayı açıyor.
5. [x] **PS5 düzeltmesi:** seçim çubuğunda önizleme genişletilebilir (dokun → tüm seçim kaydırılabilir
       alanda, karakter/sözcük sayısı); çubuk seçimi örtüyorsa seçimin üstüne yerleşir.
6. [x] **PS1 ara düzeltme:** "Düzenle" seçimin dikdörtgenini ve metnini geçirir; editör o sayfada
       seçimle en çok örtüşen paragrafı **doğrudan düzenleme kipinde** açar, imleç seçimin başına.
7. [x] **PS4 ara düzeltme:** düzenleyicide klavye görüntüleyiciyi küçültmez
       (`resizeToAvoidBottomInset: false` + düzenlenen satırı klavyenin üstüne kaydırma); OCR satırında
       da okunur boya yakınlaşma; uygulamadan sonra yakınlaştırma matrisi geri yüklenir.
8. [x] **PS2 ara düzeltme:** `_ocrEditable` doğal metinli sayfada logo yüzünden OCR açmaz (yalnız
       sayfanın metin katmanı gerçekten yoksa ya da OCR satırı görsel bölgesinin içindeyse); düzenleme
       alanı Carlito yerine belgenin fontuna en yakın gömülü aileyle (Carlito/Tinos/Arimo) çizilir.
**Bitti:** külliyat + tezgâh CI'da yeşil, taban raporu yazıldı; PS1/3/4/5 ara düzeltmeleri cihazda
doğrulandı (📱 kısa tur: 6 ekran görüntüsünün her biri yeniden denenir).
**Sonuç (2026-11-08, PR `faz-51`):** 68 PDF / 8 üretici; taban kapsama %63,6, başarı %54,2 (aynı
harf) / %34,2 (Türkçe harf), Word'de 0 paragraf (kök: satır başına kırpma bloğu) →
`docs/perf/2026-11-pdfpro-51-taban.md`. PS1–PS5 MatePad'de ✅ (`docs/CIHAZ_TESTI.md`). Ek bulgu:
sahip parolalı belgede kilit açma düzeltildi; AES-256 kopyası KALANLAR'da.

### Faz 52 — Motor köprüsü: PDFium düzenleme API'si + karar kapısı ☁️ (2–3 oturum)
1. [x] `third_party/pdfrx_engine` (0.9.x) depoya alınır, `YAMA.md`; pdfrx bağımlılığı yerel yola.
2. [x] `PdfEditBridge` (pdfrx işçisinde, belge kilidiyle): sayfa yükle/tut, metin nesnelerini sırala
       (kutu, matris, font, punto, renk, metin), `FPDFText_GetTextObject` ile karakter → nesne eşlemesi,
       `SetText`/yeni metin nesnesi/sil/dönüştür, `GenerateContent`, `SaveAsCopy(INCREMENTAL)`.
3. [x] pdfrx'e **sayfa değişti** olayı: o sayfanın görüntü/metin önbelleği düşer, görüntüleyici yalnız
       o sayfayı yeniden çizer, matris değişmez (widget testi: düzenleme sonrası `value` aynı).
4. [ ] Prototip düzenleyici yolu (gizli bayrak `pdf_pro_engine`): paragraf değiştir → bellek → çizim.
5. [ ] **Karar kapısı:** külliyatta iki motor yan yana (tezgâh): başarı oranı, piksel farkı, `qpdf
       --check`, çıktı büyümesi, p95 gecikme, bellek. Tablo `docs/perf/2026-11-pdfpro-52-motor.md`.
       PK1 mi PK1-B mi → HAFIZA "karar". (`GenerateContent`'in işaretli içerik/etiketli PDF davranışı
       ayrıca ölçülür; kayıp varsa yalnız kirli akış yeniden üretimi doğrulanır.)
**Bitti:** karar sayıyla verildi; seçilen yol külliyatta şimdiki motorun **en az** başarı oranında ve
değişmeyen bölge farkı 0.

### Faz 53 — Tasarım dili ve etkileşim prototipi 👤 onay kapısı ☁️ (1–2 oturum)
1. [ ] Rakip akış analizi (Acrobat, Foxit, PDFelement, Xodo, Nutrient) → `docs/design/pdf_pro/analiz.md`:
       giriş, blok seçimi, biçim çubuğu, nesne tutamaçları, kaydetme — her birinde "biz nasıl daha iyi".
2. [ ] **Yüksek çözünürlüklü maketler** (telefon dikey/yatay + tablet, açık/koyu): görüntüleyici ↔
       düzenleme kipi geçişi; üst çubuk (geri · başlık + "kaydedilmedi" durumu · geri al · yinele ·
       Kaydet dolgulu düğme · ⋮); **alt araç çubuğu** (Metin · Görsel · İşaretle · İmza · Form ·
       Sayfalar · Daha fazla) + seçili araca göre **bağlamsal ikinci çubuk**; seçili nesnenin yanında
       yüzen eylem çubuğu; klavye üstü biçim çubuğu (yazı tipi · punto · B/I/U/S · renk · hizalama ·
       satır aralığı · liste · ⋯); blok çerçevesi dili (dokunmadan önce hafif, dokununca belirgin —
       her satırı gri kutuya boğmak YOK); boş/yükleniyor/hata durumları; tablet: sol araç rayı + sağ
       özellik paneli; RTL ayna.
3. [ ] Etkileşim belirtimi `docs/design/pdf_pro/etkilesim.md`: dokun/uzun bas/sürükle/iki parmak,
       imleç yerleştirme, seçim tutamaçları, yakınlaştırma kuralları (klavye açılınca küçülme YOK,
       okunur boy hedefi 16–20 sp), haptik, Motion süreleri, geri tuşu davranışı.
4. [ ] Tasarım tokenları: düzenleme yüzeyine özel renk/aralık/yarıçap tokenları `AppHues` içinde.
5. [ ] Kullanıcı onayı (maketler artefakt/ekran görüntüsü olarak sunulur); düzeltmeler işlenir.
**Bitti:** kullanıcı maketleri onayladı; sonraki UX fazları bu maketlere göre yapılır.

### Faz 54 — Düzenleme oturumu çekirdeği + tek yüzey + kaydetme akışı ☁️ + 📱 (3 oturum)
1. [ ] `PdfEditSession`: görüntüleyicinin belgesine bağlı oturum; sayfa bazlı kirli izleme; komut
       yığını (her komut: uygula/geri al — sayfa içerik akışı + kaynak sözlüğü anlık görüntüsü, tüm
       belge kopyası YOK); sınırsız geri al/yinele, adım adları ("Paragraf düzenlendi: 'Ancak…'").
2. [ ] **Tek yüzey:** görüntüleyicide "Düzenle" → düzenleme kipi (aynı ekran, aynı yakınlaştırma);
       çıkışta kaydedilmemiş değişiklik sorusu. `PdfEditorScreen` ve çalışma kopyası emekli
       (işlevleri taşındıkça; sonunda dosya silinir, testler taşınır).
3. [ ] **Artımlı kayıt:** Kaydet = özgüne artımlı yaz (yazılabilirse) + önceki sürüm **sürüm
       geçmişine** (uygulama içi, 14 gün, "önceki sürüme dön"); Farklı kaydet = aynı klasör ya da
       Belgeler; salt okunur konumda otomatik Belgeler'e kopya + açık bildirim. Kopya kaydedilince
       oturum kopyaya geçer, son dosyalar/Belgeler'e düşer (PS3 kalıcı çözümü).
4. [ ] **Çökme kurtarma:** komut günlüğü + 30 sn'de bir artımlı geçici kayıt; süreç ölürse açılışta
       "Kaydedilmemiş düzenlemeleri geri yükle".
5. [ ] Şifreli belge: sahip parolası/izin bayrakları; düzenleme yasaksa açık uyarı + "parolayla aç".
6. [ ] Ölçüm: uygula → piksel p95, geri al p95, 50 sayfa artımlı kayıt süresi, oturum ek belleği.
**Bitti:** §6 bütçeleri tutuyor; düzenleme sonrası yakınlaştırma/kaydırma değişmiyor (test + 📱);
kayıt/kopya/sürüm geçmişi cihazda doğrulandı.

### Faz 55 — Metin anlama (düzen çözümleme) ☁️ (2–3 oturum)
1. [ ] Karakter düzeyi çıkarım (PDFium metin sayfası): Unicode, kutu, taban çizgisi, font, punto,
       renk, işleme kipi, nesne kimliği; görünmez metin (OCR katmanı) ayrı işaretli.
2. [ ] Sözcük → satır → paragraf → sütun: taban çizgisi ve aralık istatistiği, **çok alt kümeli
       fontlar tek koşu** (Word'ün Türkçe harfleri ikinci fonta bölmesi), iki yana yaslama, ortalı,
       girintili ilk satır, asılı girinti, madde/numara algılama, üst/alt bilgi ve sayfa numarası,
       tablo hücreleri (çizgi + hizalama), dipnot, döndürülmüş metin (90/180/270 ve açılı), **RTL**
       (Arapça; görsel → mantıksal sıra), dikey metin "düzenlenemez" diye açıkça işaretli.
3. [ ] **Satır kipi / paragraf kipi** geçişi (PDFelement); blokları bölme/birleştirme jesti.
4. [ ] Seçim → blok eşlemesi (PS1 kalıcı): görüntüleyici seçiminden blok + karakter aralığı.
5. [ ] Hedef (külliyat, doğal belgeler): **≥ %97 karakter doğru blokta**, paragraf sınırı F1 ≥ 0,95,
       PS2'nin benzeri belgede tüm paragraflar doğal blok (OCR'a düşen satır 0).
**Bitti:** hedefler tezgâhta tutuyor; rapor `2026-11-pdfpro-55-duzen.md`.

### Faz 56 — Yazı tipi sadakati ☁️ (3 oturum)
1. [ ] **Font çıkarma ve onarma:** `FPDFFont_GetFontData` → TrueType alt kümeye ToUnicode + kodlamadan
       Unicode `cmap` kurma, çıplak CFF/CIDFontType0C'yi OpenType'a sarma, eksik tabloları
       (OS/2, hhea, post, name) üretme → Flutter `FontLoader` ile oturumluk yükleme (önbellek,
       `PerfBudget`'e bağlı üst sınır). Type1 ve Type3 → "onarılamaz" sınıfı (PK6 yedeği).
2. [ ] **Kapsama:** bir harf yazılabilir mi = glif var ∧ kodlanabilir (basit fontta kodlama tablosu,
       CID'de ToUnicode ters eşleme). Test: Türkçe 12 harf × külliyat fontları.
3. [ ] **Glif bazlı yedek** (PK5): yalnız eksik harfler yedek fontla, büyük harf yüksekliği ve x-yüksekliği
       ölçeklenerek, aynı taban çizgisinde; yazıcı karma koşu üretir.
4. [ ] **Metrik uyumlu aile eşlemesi:** Calibri→Carlito, Cambria→Caladea, Arial/Helvetica→Arimo,
       Times→Tinos, Courier→Cousine, Georgia→Gelasio, Segoe UI→Selawik, Verdana/Tahoma→DejaVu/Noto,
       Arapça→Noto Naskh/Sans Arabic, bilinmeyen→sınıfına göre (serif/sans/mono, kalınlık, italik,
       genişlik — PANOSE/OS2). APK'da yalnız mevcutlar (Carlito, Tinos, Arimo); diğerleri **isteğe
       bağlı font paketi** (ilk ihtiyaçta iner, çevrimdışı kipe uyar, anayasa kural 7).
5. [ ] **Dart TrueType alt kümeleyici** (glyf/loca/hmtx/cmap 4+12/bileşik glif kapanışı): gömülen
       yedek font yalnız kullanılan glifler (+ ToUnicode, metin aranabilir/kopyalanabilir kalır).
6. [ ] **Punto ve biçim ölçümü kesinliği:** Tf × Tm × CTM ölçeği, Tz (yatay ölçek), Tc/Tw (harf/
       sözcük aralığı), Ts (yükselme), işleme kipi (dolgu/kontur), renk uzayı (Gray/RGB/CMYK).
7. [ ] Font seçicide sıra: **belgenin fontları** → eşleşen aileler → cihaz/paket fontları; her satırda
       kendi fontuyla önizleme.
8. [ ] Hedef: düzenlenen paragrafın değişmeyen sözcükleri özgünle piksel benzerliği SSIM ≥ 0,98;
       yedek fonta düşen harf ≤ eksik glif sayısı; `.notdef` = 0; çıktı metni %100 aranabilir.
**Bitti:** hedefler külliyatta; PS2 (font/punto değişimi) PS2 benzeri belgede yeniden üretilemiyor.

### Faz 57 — Yerinde metin düzenleme (WYSIWYG) — kalp 💻📱 (3–4 oturum)
1. [ ] Bloğa dokun → **imleç dokunulan harfte** (tümünü seçme yok), klavye açılır; sayfa okunur boya
       yakınlaşır ve **orada kalır** (klavye görüntüleyiciyi küçültmez; imleç satırı klavye + çubuğun
       üstünde tutulur; bitirince yakınlaştırma korunur).
2. [ ] **WYSIWYG alan** (PK6): özgün glifler gizlenir (sayfa o nesneler hariç çizilir), yerine belgenin
       onarılmış fontuyla `EditableText`; renk, Tc/Tw/Tz, satır aralığı, hizalama birebir. Onarılamayan
       font → PDFium canlı bölge çizimi + imleç katmanı (prototip iki yolu ölçer, seçim HAFIZA'ya).
3. [ ] **Canlı akış:** yazdıkça blok içinde yeniden sarma; kutu aşağı uzar; başka bloğa çarpacaksa
       satır içinde uyarı + seçenekler (punto küçült · alttakileri aşağı it · kutuyu genişlet). "Sığmıyor"
       reddi yerine önizleme.
4. [ ] Satır sonları yazıcıya Flutter dizgisinden (gördüğün = yazılan; test: ekran satır sayısı = PDF
       satır sayısı, 200 paragraf).
5. [ ] **Karakter düzeyi biçim:** seçili aralıkta yazı tipi, punto, kalın, italik, altı çizili, üstü
       çizili, renk, vurgu rengi; paragraf düzeyinde hizalama (sol/orta/sağ/iki yana), satır aralığı,
       girinti. Kalın kesim gömülü değilse aynı ailenin yedek kalın kesimi (PK5) — ret yok.
6. [ ] Yerel seçim tutamaçları, büyüteç, Türkçe klavye + **IME bileşik giriş** (Gboard otomatik
       düzeltme, sesle yazma), donanım klavyesi kısayolları, Arapça RTL giriş.
7. [ ] Dokunarak dışarı çık = uygula; ✕ = vazgeç; geri tuşu önce alanı kapatır.
8. [ ] Blok tutamaçları: uzun bas → taşı (sürükle), yan tutamaçlarla genişlik, sil, çoğalt, stili kopyala.
9. [ ] Görüntüleyiciden seçimle gelince seçim aynen korunmuş açılır (PS1 kalıcı).
10. [ ] Bütçe: dokun → imleç ≤ 120 ms (klavye animasyonu hariç), tuş → piksel ≤ 1 kare (16 ms) yazım
       sırasında, uygula → sayfa ≤ 250 ms p95.
**Bitti:** cihazda 6 ekran görüntüsündeki akışlar sorunsuz; Türkçe/Arapça giriş, donanım klavyesi,
iki cihazda bütçe; widget + golden testler.

### Faz 58 — Metin araçları: yeni metin, liste, bul-değiştir, yazım, kopyala-yapıştır ☁️ + 📱 (2 oturum)
1. [ ] **Yeni metin kutusu:** dokun/sürükle-çiz; varsayılan stil çevredeki gövde metninden (font,
       punto, renk) — "eşleşen stil".
2. [ ] Madde işaretli/numaralı liste oluştur/kaldır (Acrobat'taki gibi), girinti artır/azalt.
3. [ ] **Belge geneli bul-değiştir** (içerik düzeyi, açıklama değil): büyük/küçük harf, tam sözcük,
       Türkçe katlama (İ/ı), tek tek ya da tümü; her değişim geri alınabilir tek adım.
4. [ ] Yazım denetimi (Android yazım denetleyicisi — Türkçe) düzenleme alanında; AI düzeltme Faz 65'te.
5. [ ] Blok kopyala/kes/yapıştır (stil dâhil, oturum içi; dışarıya düz metin), sayfalar arası taşı.
6. [ ] Paragraf sil; boş kalan alanın altındakileri yukarı çekme seçeneği.
7. [ ] Metin için bağlantı ekle/düzenle/kaldır (URI + sayfa içi hedef).
**Bitti:** testler + cihaz turu; bul-değiştir külliyatta doğru sayım.

### Faz 59 — Nesne düzenleme: görsel, vektör, bağlantı, hizalama ☁️ + 📱 (2–3 oturum)
1. [ ] Görsel: seç, taşı, boyutlandır (oran kilidi), döndür (15° adımlı + serbest), **kırp** (tutamaçla),
       değiştir (galeri/kamera/tarama), dışa aktar, sil, saydamlık, öne/arkaya.
2. [ ] Görsel ekle: galeri, kamera, tarama, panodan; büyük görsel cihaz bütçesine göre sıkıştırılır.
3. [ ] Vektör nesneler (çizgi, dikdörtgen, yol): seç, taşı, renk/kalınlık, sil; şekil ekle (çizgi, ok,
       dikdörtgen, elips) — gerçek içerik nesnesi.
4. [ ] **Hizalama kılavuzları ve tutunma** (kenar, orta, sayfa kenar boşluğu, diğer nesneler), ızgara.
5. [ ] Çoklu seçim (kement + uzun bas), grup taşıma, hizala/dağıt.
6. [ ] Katmanlar (OCG) göster/gizle; filigran/arka plan öğeleri ayrı katman olarak seçilebilir.
**Bitti:** cihazda dokunma hassasiyeti (küçük nesne seçimi), 60 fps sürükleme, testler.

### Faz 60 — İşaretleme stüdyosu: gerçek PDF açıklamaları ☁️ + 📱 (2 oturum)
1. [ ] Metin üstü: vurgu, altı çizili, üstü çizili, dalgalı; renk paleti + son kullanılanlar.
2. [ ] Yapışkan not, serbest metin, şekiller, ok, bulut, **kalem** (basınçlı kalem/stylus, avuç içi
       reddi), silgi, damgalar (Onaylandı, Reddedildi, Gizli, tarih/saat, özel görsel damga).
3. [ ] **Yorum paneli:** tüm açıklamalar listesi, yanıt, durum (açık/çözüldü), yazar, filtre; açıklamaya
       git.
4. [ ] Açıklamalar `FPDFAnnot` ile gerçek PDF nesnesi (Acrobat/Chrome'da görünür, düzenlenebilir);
       düzleştirme seçeneği; XFDF içe/dışa aktar.
5. [ ] Şimdiki ayrı Kalem/Vurgu yolları bu stüdyoya taşınır (tek yol); `pdf_ink_screen` emekli.
**Bitti:** açıklamalar ikinci çiziciyle (`mutool`) görünüyor; cihazda kalem gecikmesi ölçüldü.

### Faz 61 — Form ve imza ☁️ + 📱 (2–3 oturum)
1. [ ] Doldurma: tüm AcroForm türleri (metin, çok satır, onay, radyo, liste, açılır, tarih, imza alanı),
       biçim/hesaplama alanları için temel JavaScript karşılıkları (sayı, tarih, toplam), sekmeyle sıradaki.
2. [ ] **Form oluşturma:** alan ekle/taşı/boyutlandır/özellikler (ad, zorunlu, varsayılan, seçenekler).
3. [ ] **Düz PDF'te alan algılama:** çizgi/kutu/onay kutusu sezgisi (+ isteğe AI) → tek dokunuşla
       doldurulabilir forma çevir.
4. [ ] İmza: çiz/yaz/görsel, kayıtlı imzalar ve baş harfler, tarih damgası; imza alanına yerleştirme.
5. [ ] **Dijital imza** (PAdES, mevcut `pdf_digital_sign` üzerine): sertifika içe aktar, görünür imza,
       doğrulama göstergesi (geçerli/değiştirilmiş), imzadan sonra artımlı düzenleme uyarısı.
6. [ ] `pdf_form_screen` ve `pdf_sign_screen` tek yüzeye taşınır, emekli.
**Bitti:** külliyattaki formlar dolduruluyor ve Acrobat/Chrome'da doğru görünüyor (💻 elle kontrol).

### Faz 62 — Taranmış belge düzenleme (OCR Pro) ☁️ + 📱 (2–3 oturum)
1. [ ] Sayfa/belge OCR → **görünmez metin katmanı** (aranabilir PDF), Türkçe/Latin + Arapça; ilerleme,
       Durdur, arka plan işçisi.
2. [ ] Taranmış satır düzenleme: üstüne yazma **örneklenen arka plan rengiyle** (beyaz değil; doku
       varsa yerinde doldurma/inpainting), metin rengi ve kalınlık kontur kalınlığından, punto glif
       yüksekliğinden, eğim düzeltmesinden sonra; yazı tipi sınıfı tahmini (serif/sans).
3. [ ] "Bu sayfayı düzenlenebilir yap": OCR blokları gerçek metin bloğuna dönüşür (Faz 57 araçlarıyla
       düzenlenir), özgün görüntü isteğe göre arkada kalır.
4. [ ] OCR güven puanı düşük sözcükler işaretli; AI ile düzelt (Faz 65 onay kancası).
5. [ ] PK7: doğal metinli sayfada OCR yolu açılmaz (bekçi test).
**Bitti:** taranmış külliyatta düzenlenen satırın çevresiyle renk farkı ΔE ≤ 3; cihazda tur.

### Faz 63 — Sayfa yönetimi stüdyosu ☁️ + 📱 (2 oturum)
1. [ ] Küçük resim ızgarası (canlı, değişen sayfa hemen tazelenir): sürükle-bırak sıralama, çoklu seçim,
       döndür, sil, çoğalt, çıkar (yeni PDF), böl, araya boş/dosyadan/görselden/taramadan sayfa ekle,
       başka PDF'le birleştir; hepsi geri alınabilir komut.
2. [ ] Görsel kırpma (kenar boşluğu tutamaçları, tüm sayfalara uygula), sayfa boyutu değiştir.
3. [ ] Üst/alt bilgi, sayfa numarası, Bates numarası, filigran (metin/görsel; ekle/düzenle/kaldır),
       arka plan rengi/görseli.
4. [ ] Yer imleri (içindekiler) düzenleme: ekle, yeniden adlandır, sürükle, iç içe.
5. [ ] `pdf_tools_screen`/`pdf_reorder_screen` işleri bu stüdyoya taşınır; araçlar ekranı kısayol olarak kalır.
**Bitti:** 300 sayfalık belgede ızgara akıcı (p99 ≤ 16 ms), işlemler geri alınabilir.

### Faz 64 — Güvenlik, gizlilik ve çıktı ☁️ + 📱 (2 oturum)
1. [ ] **Nesne düzeyi gerçek redaksiyon:** bölgedeki glifler metinden silinir, görsellerin yalnız o
       pikselleri karartılır, vektörler kırpılır — **sayfa görüntüye çevrilmez** (şimdiki `pdf_redact`
       sayfayı rasterleştiriyor; o yol yedek olarak kalır). Doğrulama: çıktıda bölgede tek karakter/piksel
       kalmadığı test edilir; meta veri, açıklama, form değeri, gömülü dosya, eski artımlı sürümler temizlenir
       (redaksiyonda belge baştan yazılır).
2. [ ] **KVKK desen arama + redaksiyon:** TC kimlik no (sağlama algoritmalı), IBAN, telefon, e-posta,
       adres kalıpları, özel liste; önizle → onayla.
3. [ ] Parola ve izinler (aç/düzenle/yazdır/kopyala), meta veri düzenle/temizle, belge özellikleri.
4. [ ] Optimize/sıkıştır (görsel yeniden örnekleme, yinelenen font/görsel birleştirme, nesne akışları),
       öncesi/sonrası boyut; **PDF/A-2b** dışa aktarma; düzleştir (açıklama/form).
5. [ ] Yazdır (sistem), paylaş, "e-postayla gönder" kısayolu.
**Bitti:** redaksiyon testleri (sızıntı 0), PDF/A çıktısı doğrulayıcıdan (veraPDF — CI'da isteğe bağlı) geçiyor.

### Faz 65 — AI destekli düzenleme ☁️ + 📱 (1–2 oturum)
1. [ ] Seçili paragrafı **yerinde** AI ile yeniden yaz / kısalt / resmileştir / dilbilgisi düzelt —
       stil korunur, sonuç önce fark görünümünde önerilir, kabul = tek geri alınabilir adım.
2. [ ] Paragrafı yerinde çevir (TR↔EN↔AR …), sığmazsa Faz 57 akış seçenekleri.
3. [ ] Form otomatik doldurma (kullanıcının kayıtlı profilinden, cihazda), akıllı redaksiyon önerisi.
4. [ ] Hepsi `AiPool.consent` + çevrimdışı kip + anahtar kapısı (`ensureAiKey`); belge geneli AI
       yeniden yazım yolu (`pdf_ai_edit_screen`) yeni araçlara yönlendirilir.
**Bitti:** onaysız gönderim 0 (test), çevrimdışıda açık mesaj; cihazda tur.

### Faz 66 — Performans, kararlılık, büyük belgeler 💻📱 (2 oturum)
1. [ ] 500+ sayfa, 200 MB, görsel ağırlıklı belgelerde düzenleme kipi: tembel sayfa çözümleme,
       bellek tavanı, önbellek tahliyesi; işçi kuyruğu önceliği (görünen sayfa önce).
2. [ ] **Bulanık test (fuzz):** bozuk/kötü niyetli PDF'lerle köprü + çözümleyici (çökme 0, zaman aşımı
       korumalı); şifreli, doğrusallaştırılmış, karma xref, onarılmış belgeler.
3. [ ] Uzun oturum: 200 düzenleme + 200 geri al/yinele → bellek sızıntısı yok, gecikme sabit.
4. [ ] Pil/ısı: 10 dk sürekli düzenleme CPU süresi; boşta 0 kare (düzenleme kipinde de).
5. [ ] İki cihazda (MatePad + Xiaomi/Mi Note 10 Lite) tam ölçüm; `docs/perf/2026-11-pdfpro-66.md`.
**Bitti:** §6 bütçelerinin tamamı iki cihazda; fuzz CI'da düzenli koşu.

### Faz 67 — Görsel cila, tablet, erişilebilirlik, ilk kullanım ☁️ + 📱 (2 oturum)
1. [ ] Faz 53 maketlerine piksel uyumu denetimi (golden + cihaz ekran görüntüsü karşılaştırması),
       boşluk/ritim/tipografi temizliği, mikro animasyonlar (Motion), haptik.
2. [ ] Tablet ve yatay düzen (sol ray + sağ panel), katlanabilir/çoklu pencere, fare/kalem imleçleri.
3. [ ] TalkBack etiketleri, odak sırası, büyük yazı (200%), kontrast (WCAG AA), RTL ayna.
4. [ ] İlk kullanım ipuçları (koç işaretleri, bir kez), "Neler yeni" (ANA.ARA anahtarı), yardım sayfası.
5. [ ] Ayarlar: varsayılan kaydetme kipi, sürüm geçmişi süresi, font paketleri, blok çerçevesi görünürlüğü.
**Bitti:** kullanıcı cihazda görsel onay verir; erişilebilirlik denetimi temiz.

### Faz 68 — Sürüm adayı ve "en iyi" kapısı 💻📱👤 (1–2 oturum)
1. [ ] Külliyat tam koşu: tüm hedefler (§6, §7) tablo hâlinde; gerileme 0.
2. [ ] **Rakip karşılaştırma turu:** aynı 10 belge + aynı 15 görev Acrobat, PDFelement, Xodo ve bizde
       (💻👤 kullanıcı cihazında); süre, adım sayısı, sonuç kalitesi tablosu `docs/perf/2026-11-pdfpro-68-rakip.md`.
       Bir görevde gerideysek o madde düzeltilmeden faz bitmez.
3. [ ] Cihaz matrisi (en az 2 cihaz, Android 10–16), Play mağaza ekran görüntüleri ve metni, sürüm
       adı ara hane +1 (`app_version.dart`), "Neler yeni".
4. [ ] Eski yolların temizliği: emekli ekranlar/servisler silindi, ölü kod yok, `graphify update .`.
**Bitti:** kullanıcı onayı → sürüm.

---

## 6. Performans bütçeleri (PDF Pro — anayasaya ek)

| Ölçüm | Hedef (MatePad / hafif profil) |
|---|---|
| Düzenleme kipine geçiş (aynı ekran) | ≤ 150 ms / ≤ 250 ms, belge yeniden yüklenmez |
| Bloğa dokun → imleç | ≤ 120 ms (klavye animasyonu hariç) |
| Yazarken tuş → piksel | ≤ 16 ms (1 kare), kare p99 ≤ 12 ms |
| Uygula → güncel sayfa | p95 ≤ 250 ms / ≤ 400 ms |
| Geri al / yinele | p95 ≤ 150 ms |
| Artımlı kayıt, 50 sayfa | ≤ 500 ms |
| Düzenleme oturumu ek belleği | ≤ +40 MB (500 sayfada ≤ +80 MB) |
| Boşta (düzenleme kipinde) | 0 kare |
| Yakınlaştırma/kaydırma düzenleme sonrası | değişmez (test) |
| APK artışı (bütün plan) | ≤ +1,5 MB (font paketleri isteğe bağlı iner) |

## 7. Kalite hedefleri (külliyat, CI tezgâhı)

| Ölçüm | Hedef |
|---|---|
| Doğal belgede karakterlerin düzenlenebilir blokta olma oranı | ≥ %97 |
| Paragraf düzenleme başarı oranı (ret yok) | ≥ %98 |
| Değişmeyen bölge piksel farkı | 0 |
| `.notdef` (tofu) glif | 0 |
| Düzenleme sonrası metnin aranabilir/kopyalanabilir olması | %100 |
| Değişmeyen sözcüklerin özgünle benzerliği (SSIM) | ≥ 0,98 |
| `qpdf --check` + ikinci çizici (`mutool`) hatasız | %100 |
| Redaksiyon sızıntısı | 0 |

---

## 8. Rakip özellik matrisi → hedef faz

| Özellik | Rakiplerde (kaynaklara göre) | Bizde şimdi | Faz |
|---|---|---|---|
| Mevcut metni yerinde düzenleme | Acrobat (ücretli), Foxit (ücretli), PDFelement, Nutrient; Xodo sınırlı | Kısmi; çok belgede OCR'a düşüyor | 52–57 |
| Satır / paragraf kipi | PDFelement; Nutrient paragraf | Yalnız paragraf | 55 |
| Yazı tipi eşleştirme | Acrobat, PDFelement | Carlito/Tinos yedeği | 56 |
| Karakter düzeyi biçim | Acrobat, Nutrient | Paragraf geneli punto/kalın/renk | 57 |
| Blok taşı / boyutlandır | PDFelement, Nutrient | Yok | 57 |
| Liste (madde/numara) | Acrobat | Yok | 58 |
| Belge geneli bul-değiştir (içerik) | masaüstü sınıfı | `PdfTools.replaceText` (sınırlı) | 58 |
| Görsel ekle/taşı/kırp/değiştir | Acrobat, Foxit, Nutrient | Ekle/taşı/sil/değiştir | 59 |
| Gerçek açıklamalar + yorum paneli | hepsi | Vurgu/kalem/not ayrı ekranlarda | 60 |
| Form doldur / oluştur / algıla | Acrobat, Foxit, PDFelement | Doldur | 61 |
| Dijital imza | Acrobat, Foxit | Var (ayrı ekran) | 61 |
| Taranmışta düzenleme | Acrobat (ücretli), Foxit OCR | Beyaz örtü + Carlito | 62 |
| Sayfa yönetimi | hepsi | Var (ayrı ekranlar) | 63 |
| Gerçek redaksiyon | Foxit, Acrobat | Sayfayı görüntüye çevirerek | 64 |
| AI | Acrobat, Foxit, PDFelement, Xodo | Belge geneli yeniden yazım | 65 |
| Fiyat | abonelik / filigran | **Ücretsiz, çevrimdışı** | — |

---

## 9. Cihaz ve kullanıcı gerektiren işler (özet)

- 💻📱 Faz 51 (kısa tur), 54, 57, 59–63 (dokunma turları), 66 (ölçüm), 67 (görsel onay), 68 (rakip turu).
- 👤 Faz 51: Word ile sentetik külliyat belgeleri (yalnız uydurma metin); Faz 53: maket onayı;
  Faz 68: rakip uygulamaları cihazda karşılaştırma + sürüm onayı.
- Test cihazı: MatePad (taban) + Xiaomi 13T / Mi Note 10 Lite (GMS, ikinci cihaz). Yerel oturum
  YUKSELTME §0 düzeninde (onaycı tüm koşu boyunca yaşar — HAFIZA tuzağı).

## 10. Riskler ve önlemler

| Risk | Önlem |
|---|---|
| `GenerateContent` etiketli/işaretli içeriği bozar | Faz 52 kapısında ölçülür; kirli akış dışındakilere dokunulmadığı piksel/bayt testiyle; olmazsa PK1-B |
| PDFium işçisinde kilitlenme/yarış | Tüm çağrılar pdfrx işçisinde tek kuyrukta; fuzz + uzun oturum testi (Faz 66) |
| Onarılan font Flutter'da yanlış metrik verir | WYSIWYG testi: Flutter satır genişliği vs PDFium glif genişliği farkı ≤ %0,5; aşarsa PDFium canlı çizim yolu |
| Font paketlerinin boyutu | İsteğe bağlı indirme + alt kümeleyici; APK'ya girmez |
| pdfrx yukarı akış güncellemeleri | `third_party` yamaları `YAMA.md`'de tek tek; aylık bağımlılık raporu |
| Kapsam büyüklüğü | Her faz bağımsız birleşir ve kullanıcıya değer verir; sıra bağımlılığa göre, atlama yok |

---

## Kaynaklar
- [A1] Adobe — Acrobat Android Edit PDF: https://www.adobe.com/devnet-docs/acrobat/android/en/editpdf.html
- [A2] Adobe Yardım — Acrobat mobil "Add text": https://helpx.adobe.com/acrobat/mobile/edit-text-images/add-text.html
- [A3] Acrobat Android sürüm notları (APKMirror): https://www.apkmirror.com/?p=7645859
- [F1] Foxit PDF Editor (App Store): https://apps.apple.com/us/app/foxit-mobilepdf-pdf-reader/id507040546
- [P1] 9to5Mac — PDFelement satır/paragraf kipi: https://9to5mac.com/?p=514438
- [P2] PDFelement (App Store): https://apps.apple.com/lt/app/id1150215996?l=en-gb
- [P3] 7labs — PDFelement incelemesi: https://7labs.io/mobile/iphone/edit-annotate-manage-pdf-ios.html
- [X1] Capterra — Xodo yorumları: https://www.capterra.com/reviews/210439/Xodo
- [X2] G2 — Xodo yorumları: https://www.g2.com/products/Xodo/reviews
- [X3] SoftPicker — Android'de ücretsiz PDF düzenleme 2026: https://softpicker.com/how-to-edit-pdf-on-android-free/
- [N1] Nutrient — Android'de PDF metni düzenleme: https://www.nutrient.io/guides/android/editor/edit-text/
- [D1] pdfium_dart — `PDFium` sınıfı (0.4.1): https://pub.dev/documentation/pdfium_dart/latest/pdfium_dart/PDFium-class.html
- [D2] PDFium `fpdf_edit.h` (GenerateContent notu): https://rust-digger.code-maven.com/src/pdfium-render-0.8.26/include/pdfium_6406/fpdf_edit.h
