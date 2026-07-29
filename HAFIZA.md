# Dosya Okuyucu — Proje Hafızası

> Kararlar, *niye*'leri, denenip reddedilen yollar ve açık durum burada.
> **Append-only:** eski maddeler silinmez, geçersizse "→ güncellendi/iptal" notu düşülür.
> Kod yapısı buraya yazılmaz (bkz. CLAUDE.md §Hafıza haritası).
> KVKK: hasta verisi / TC / ölçüm / token bu dosyaya YAZILMAZ.

## Sabit Kararlar (tarihli, append-only)

- **2026-07-20 — Teknoloji: Flutter (Dart), CI Flutter sürümü 3.29.3.**
  *Niye:* tek kod tabanıyla mobil + masaüstü. 3.29.3 zorunlu: pdfx engine API'si ve
  compileSdk 35 gerektiriyor, daha eski sürümlerde derlenmiyor (build-1 bu yüzden kırmızı).

- **2026-07-20 — AI: Google Gemini, düz REST çağrısı (paket bağımlılığı yok).**
  *Niye:* ücretsiz kota + bağımlılık şişkinliği istenmedi. Anahtar Ayarlar'dan girilir,
  cihazda SharedPreferences'ta saklanır. Varsayılan model `gemini-2.0-flash`.

- **2026-07-20 — Firebase kodu guard'lı; config repoda YOK.**
  *Niye:* config gizli ve kullanıcıya özel. `Firebase.initializeApp()` guard'lı olduğu için
  config yokken uygulama "yerel mod"da çalışır — kurulum kullanıcıyı bloklamaz.
  Aktifleştirme: `flutterfire configure` veya `google-services.json` (FIREBASE_SETUP.md).

- **2026-07-20 — Office düzenleme: cihaz-içi / offline / ücretsiz, ORTA sadakat.**
  Word/PPT'de orijinal XML korunur, sadece metin düğümleri (`w:t` / `a:t`) güncellenir →
  biçim bozulmadan metin düzenleme + geri kaydetme.
  **REDDEDİLEN yol:** sunucu tabanlı OnlyOffice — kullanıcı açıkça ücretsiz/offline istedi.

- **2026-07-20 — İmzalama: tüm APK'lar sabit anahtarla imzalanır.**
  *Niye:* güncelleme uyumu (anahtar değişirse kullanıcı uygulamayı güncelleyemez).
  Anahtar repoda TUTULMAZ; `ANDROID_KEYSTORE_B64` GitHub secret'ından yüklenir. Secret yoksa
  CI geçici anahtar üretip base64'ünü loglar (SIGNING.md). Alias `dosyaokuyucu`.
  → *güncellendi 2026-07-23:* parola workflow'da düz metindi; repo public yapılmadan
  önce DEĞİŞTİRİLDİ ve `ANDROID_KEYSTORE_PASSWORD` secret'ına taşındı (aşağıya bak).

- **2026-07-20 — Bildirim: başarılı derlemede release linki Gmail *taslağı* olarak hazırlanır**
  (hekimasistanitr@gmail.com). *Niye:* doğrudan gönderme aracı yok, sadece taslak mümkün.

- **2026-07-21 — Hafıza 3 katmana ayrıldı** (bu dosya + CLAUDE.md haritası + graphify).
  *Niye:* CLAUDE.md her oturumda otomatik yükleniyor; append-only karar listesi orada
  büyüyünce her oturumun token maliyeti artıyordu. Kararlar buraya, kurallar orada kaldı.
  graphify kuruldu (390 düğüm / 522 kenar / 22 topluluk) → CLAUDE.md'deki elle yazılmış
  dosya haritası silindi, yerine `graphify-out/GRAPH_REPORT.md` geçti (tek kaynak).
  `graphify-out/cache/` ve tarihli yedek klasörleri .gitignore'a eklendi; rapor+graf commitlenir.

- **2026-07-21 — Slayt görüntüleme: kendi Flutter renderer'ımız** (`services/pptx_render.dart`
  + `widgets/slide_canvas.dart`). Slayt XML'i punto koordinatlara çözülür, Flutter widget'ı
  olarak çizilir: arka plan, düzen/master grafikleri, şekil dolgu+çerçeve, görsel, grup
  dönüşümü, tablo hücreleri, biçimli metin (boyut/kalın/italik/renk/hizalama/madde).
  *Niye:* kullanıcı "PowerPoint'te nasıl görünüyorsa aynısı" istedi; metin listesi yetmiyordu.
  **REDDEDİLEN yol:** WebView + PPTXjs — jQuery bağımlılığı, APK şişmesi, orta sadakat.
  Metin düzenleme kutuya dokununca açılır, `<a:t>` güncellenir → tasarım bozulmaz.
  *Kapsam dışı (bilinçli):* SmartArt, grafik (chart), animasyon, gradient dolgu, gömülü fontlar.

- **2026-07-21 — DÜZELTME: yerelde Flutter VAR** (`C:\src\flutter`, sürüm 3.44.6).
  Artık doğrulama = `flutter test` + `flutter analyze` (yerel), sonra CI derlemesi.
  **Dikkat:** yerel 3.44 ≠ CI 3.29.3 → yerelde `withOpacity` "deprecated" uyarısı verir ama
  CI'da GEREKLİ, `withValues`'a çevirme (3.29'da yok). Uyarı normaldir, hata değildir.

- **2026-07-21 — Word: gömülü docx-preview + WebView; Excel: excel paketinin kendi stili.**
  *Niye:* Word'ün sayfa akışı (satır/sayfa kırma, stil mirası) elle yazılırsa %70 sadakatte
  kalıyor; olgun motor `assets/word/`e gömüldü (jszip MIT + docx-preview Apache-2.0, LICENSES.txt).
  İnternet gerekmez, WebView yalnızca yerel dosya açar. Excel'de tam tersi: `excel` paketi
  genişlik/yükseklik/stil/birleşik hücre bilgisini zaten veriyor → kendi styles.xml ayrıştırıcım
  YAZILMADI. **REDDEDİLEN yol:** Excel için WebView (x-spreadsheet) — gereksiz, ızgara Flutter'da daha iyi.

- **2026-07-21 — Sunum modu + animasyon yaklaşımı.** `p:timing/mainSeq` içindeki her `p:par`
  bir tıklama adımı sayılır; hedefler `p:spTgt@spid` (+ `p:pRg` paragraf aralığı). Efekt türü/süresi
  OKUNMAZ — beliriş jenerik (fade + hafif kayma). *Niye:* PowerPoint'te 100+ efekt var, akış
  önemli, efektin kendisi değil. Sunum modu tam ekran + yatay + zoom (InteractiveViewer).

- **2026-07-22 — Faz 0 "Office hissi" temeli (kullanıcı onaylı plan; sıra: Faz 0 → Word → Excel → PPTX).**
  Görsel referans **M365 mobil** (kullanıcı seçimi); Word Faz 1 kapsamı **metin + B/I/U birlikte** (kullanıcı seçimi).
  M365 kimliği: `OfficeColors` token'ları (Word #185ABD / Excel #107C41 / PPT #C43E1C / PDF #C50F1F),
  Fluent kanvas #F3F2F1 / #201F1E, ortak kabuk `widgets/office_shell.dart` — alt bar SafeArea'sı
  tek yerden (alt sistem çubuğu çakışma sınıfı burada çözülür, ekran ekran değil).
  120Hz: `flutter_displaymode.setHighRefreshRate` (Android, try/catch) + `SystemUiMode.edgeToEdge`.
  Zoom kararları ve *niye*leri:
  - Excel = **ham pointer pinch** (GestureDetector değil) — jest arenası çekişmesine girmez,
    2 parmakta scroll `NeverScrollableScrollPhysics` ile kilitlenir, bırakınca ölçek hücre
    metriklerine işlenir → yazı yeniden net çizilir (canlı faz GPU Transform.scale).
  - Slayt = PageView (PowerPoint mobil düzeni) + InteractiveViewer; zoom>1'ken sayfa kaydırma kilidi.
  - Word = native WebView zoom + viewer.html `viewport width=820` → açılışta tam sayfa sığar.
  **Bilinçli yok:** editör görünümlerinde çift-dokunuş zoom — kDoubleTapTimeout tuzağı gereği
  hücre/kutu dokunuşlarını 300 ms geciktirirdi; düzenleme hissi zoom kısayolundan önemli.

- **2026-07-22 — İkon kurtarma dersi + Faz 1 Word canlı düzenleme mimarisi.**
  *İkon:* launcher ikonu commit'i (69213bf) hiçbir dalda değildi (dangling) — bulut oturum
  dalı silinince kaybolmuş; `git checkout <sha> -- <paths>` ile nesne veritabanından kurtarıldı.
  *Ders:* dal silmeden önce main'e merge edildiğini doğrula.
  *Faz 1 kararları:* Sayfa görünümü contenteditable yapılır (docx-preview DOM'u);
  paragraf eşleme **indeks tabanlı** — DOM `section.docx article p` sırası = `document.xml`
  `w:p` sırası (başlık/altbilgi article dışında). Sigorta: düzenleme açılırken JS paragraf
  sayısı gönderir, uyuşmazsa canlı düzenleme kapanır (yanlış paragrafa yazma engellenir).
  B/I/U: `document.execCommand` + DOM'dan segman çıkarımı (computed style ile b/i/u) →
  `DocxEditor.setRuns` ilk run'ın rPr'ini şablon kopyalayıp `w:b/w:i/w:u` ayarlar.
  `DocxParagraph.rich` bayrağı: setRuns yazan paragrafa save() bir daha dokunmaz (ezme tuzağı).
  Kaydetme canlı görünümü YENİDEN ÇİZMEZ (imleç kaybolmasın). Eski "Düzenle" sekmesi silindi;
  düz metin editörü yalnız yedek yol (⋮ menüsü / sayfa görünümü açılamazsa).

- **2026-07-22 — Slayt görünümü kararı (kullanıcı, build 49 denemesi sonrası):**
  PageView (sayfa sayfa yatay) REDDEDİLDİ → tüm slaytlar alt alta dikey akış.
  InteractiveViewer + sonsuz boundaryMargin da reddedildi ("slayt kayboluyor",
  zoom zor) → Excel'deki ham-pointer pinch modeli ortaklaştırıldı:
  `widgets/pinch_zoom_area.dart` (Excel + slayt listesi aynı widget'ı kullanır).
  *Yazı taşması kök nedeni #2:* autofit çoğu dosyada şeklin bodyPr'inde değil
  ŞABLONDA durur → yer tutucu (`ph` olan) şekillere de sığdırma uygulanır
  (`ShapeVM.isPlaceholder`). #1 lnSpcReduction/ölçüm 48'de gelmişti.

- **2026-07-22 — DAL BİRLEŞTİRME:** `claude/office-programs-development-vbnq1x` dalındaki
  34 commit (aşağıdaki 2026-07-21 kararları) main'e merge edildi — dal main varsayılan
  olduktan SONRA da aktif kalmış, bugünkü Faz 0/1 işi main'de ayrı ilerlemişti.
  Çakışma politikası: kabuk/zoom/canlı-düzenleme UX'i main'den (kullanıcı onaylı),
  tüm dal özellikleri korunarak port edildi. Kural: tek aktif geliştirme hattı = main.

- **2026-07-21 — Office ileri düzenleme (yol haritası #1) eklendi.** Cihaz-içi/offline/
  ücretsiz ilkesi korunarak:
  - **Excel:** satır/sütun ekle-sil (`Excel.insertRow/removeRow/insertColumn/removeColumn`,
    ardından modeli `_refresh` ile yeniden kur), formül girişi (`=` ile başlayan hücre
    `FormulaCellValue` olur → dosyayı Excel açınca hesaplar, biz hesaplamayız), akıllı tip
    (sayı→IntCell/DoubleCell, baştaki sıfırlı "007"→metin). Formül çubuğu altına satır/sütun
    araç çubuğu.
  - **Word:** paragraf kalın/italik/altı çizili + hizalama (rPr `<w:b>/<w:i>/<w:u>`,
    pPr `<w:jc>`), paragraf ekle/sil (`<w:sectPr>` daima en sonda tutulur). Biçim araç çubuğu
    seçili paragraf üzerinde çalışır.
  - **PowerPoint:** slayt çoğalt/sil/taşı. `[Content_Types].xml` + `presentation.xml`
    (`sldIdLst`) + `presentation.xml.rels` üçlüsü güncellenir; yoksa `canEditStructure=false`
    (sentetik/eksik dosyada yapısal düzenleme kapalı, metin düzenleme açık kalır). Slayt
    sırası artık mümkünse `sldIdLst`'e göre (yoksa dosya numarası yedeği).
  *Niye/karar:* orijinal XML korunur, sadece hedef düğümler güncellenir (mevcut orta-sadakat
  ilkesiyle uyumlu). **REDDEDİLEN:** formülü cihazda hesaplama (offline motor şişkinliği);
  karakter-bazlı Word biçimi (mobilde paragraf-bazı daha kullanışlı + risk düşük).

- **2026-07-21 TUZAK — `excel` 4.0.6 Excel-seviye `insertRow/insertColumn` NO-OP:**
  `_excel.insertRow(sheetName, i)` / `insertColumn` çağrısı derleniyor ama satır/sütun
  sayısını DEĞİŞTİRMİYOR (CI run #17: beklenen 3, gelen 2; sütunda 1). Çözüm: yapısal
  işlemleri Sheet hücre API'siyle (`cell/value/cellStyle` — bunlar güvenilir) elle kaydır
  ve model listesini doğrudan güncelle (`xlsx_editor.dart` insert/deleteRow/Column). Not:
  Sheet-seviye `table.insertRow(i)` denenmedi; elle kaydırma paketten bağımsız çalışıyor.

- **2026-07-21 TUZAK — Dart: bağlamsız `?? const []` for-loop'ta 'Object'e düşer:**
  `for (final x in nullable?.iter() ?? const [])` CFE hatası verir ("must implement
  Iterable"). Çözüm: açık tip — `?? const <XmlElement>[]`. (Fonksiyon argümanı gibi bağlam
  tipi olan yerlerde sorun yok; yalnızca for-loop gibi bağlamsız yerlerde.)

- **2026-07-21 TUZAK — xml paketinde `XmlNodeList.removeWhere` üst-düğüm çakışması riski:**
  jenerik `ListMixin.removeWhere` compaction sırasında `[]=` ile düğümü yeniden atayınca
  "node already has a parent" atabilir. Çözüm: eşleşenleri `.toList()` ile toplayıp tek tek
  `children.remove(node)` ile sil (`_removeElems` yardımcısı, docx+pptx editörlerinde).

- **2026-07-21 — CI feature dallarında da çalışır.** `build-apk.yml` push tetikleyicisine
  `claude/**` eklendi → dal main'e girmeden test+build ile doğrulanır. **Release adımı
  yalnızca main**'de (if guard). *Niye:* yerelde Flutter yok; tek doğrulama CI'ın `flutter
  test` + `flutter build apk` adımları, o yüzden feature dalı da derlenmeli.
  → *güncelleme 2026-07-22:* yerelde Flutter var; doğrulama önce yerel test+analyze.

- **2026-07-22 — Pinch zoom odak noktası + CI tekrar tuzağı + WhatsApp intent kök nedeni.**
  *Zoom:* `PinchZoomArea` başta `Transform.scale`'i sol-üstten (topLeft) uyguluyordu →
  "sayfa kayıyor/kayboluyor" şikayeti. Çözüm: origin = iki parmağın ortası (focal),
  commit'te kaydırma ofseti `(ofset+odak)*f-odak` ile odaktaki içeriği sabit tutar.
  *CI TUZAK:* ayrı `test` işi + apk işinde `needs: test` → main'de APK ~4 dk boşuna
  bekliyordu (apk işi zaten `flutter test` koşuyor). Çözüm: `test` işi yalnız feature
  dallarında (`if: github.ref != 'refs/heads/main'`), apk'dan `needs` kaldırıldı.
  *WhatsApp "birlikte aç":* kod eksik değildi — ACTION_VIEW/SEND intent-filtreleri
  `ci/AndroidManifest.xml`'de zaten vardı ama kayıp dalda kalmıştı; build 51'de yok,
  build 52 (merge) sonrası geldi. Ders: "görünmüyor" = sürüm eski olabilir, önce build no.

- **2026-07-22 — Kullanıcı geri bildirim turu (zoom kayması, yazı taşması, PDF seçimi, eski Office).**
  - **TUZAK / zoom kök nedeni:** `Transform.scale`'e `origin` verilse bile `alignment`
    varsayılanı (center) origin'e EKLENİR (`RenderTransform` ikisini toplar) → etkin zoom
    merkezi odak+viewport/2 olur, yaklaştırırken içerik sağa/aşağı kayar. Çözüm:
    `alignment: Alignment.topLeft` (PinchZoomArea — Excel + slayt ikisi de düzeldi).
  - **Yazı taşması kök nedeni #3:** sığdırma artık TÜM metin kutularına uygulanıyor
    (autofit/yer tutucu ayrımı yetmedi; düz şekillerde Calibri≠Roboto farkı komşu
    kutuya bindiriyordu — Slayt 22 örneği). Ölçüm iki geçişli (sarma değişimini doğrular).
    PowerPoint'in "taşır" davranışından bilinçli sapma: okunurluk > birebir sadakat.
  - **PDF: pdfx → pdfrx 1.3.x (pdfium).** Sayfa üzerinde METİN SEÇME/kopyalama
    (`enableTextSelection`) + sayfa metni artık AI sohbet bağlamına gidiyor (loadText).
    **Sürüm sabitleme nedeni:** pdfrx 2.x Dart ≥3.9 ister; CI 3.29.3 = Dart 3.7 →
    `^1.3.0`. pdfium .so'ları CMake sırasında GitHub'dan iner (CI'da ağ var, sorun değil).
  - **Eski .doc/.ppt yapısal ayrıştırma:** .doc'ta FIB+piece table (CLX/PlcPcd, alan
    kodu gizleme, CP1252/UTF-16 parçalar), .ppt'te kayıt ağacı (TextChars/TextBytesAtom,
    SlidePersistAtom → "[Slayt N]"). Bayt tarama YEDEK yol olarak duruyor (bozuk dosya).
    Test için sentetik CFB üretici: `test/helpers/cfb_writer.dart` (mini-FAT'sız, 4096 pad).
  - **Excel hücre biçimi:** kalın/italik/hizalama düğmeleri (`setCellStyle`,
    copyWith `boldVal/italicVal/horizontalAlignVal` adları!). Hizalama dosyaya yazılır ama
    excel paketi okuma hatası yüzünden yeniden açınca GÖRÜNMEZ (bilinen paket hatası).
    Önbellek `patchStyle` ile tek hücre güncellenir (rebuildCaches O(hücre) çağrılmaz).
  - **Word canlı hizalama:** viewer.html `fmt('justify*')` → seçimdeki paragrafların
    hizası `{a:{i,v}}` köprüsüyle Flutter'a gelir, kayıtta `w:jc`. `_formatChanged`
    ikiye bölündü (`_biuChanged`/`_alignChanged`) — yalnız hizalama değişince karma
    run biçimi (tek kelimesi kalın paragraf) artık EZİLMİYOR; rich paragrafta da jc yazılır.
  - **Slayt kutu biçimi:** metin düzenleme sayfasında B/I/U + punto
    (`PptxEditor.formatParagraph`; yalnız DOKUNULAN özellik yazılır, rPr ilk çocuk).

- **2026-07-22 — PDF seçim düzeltmesi (kendi katmanımız) + OCR.**
  - **TUZAK / pdfrx 2.x bu projede KULLANILAMAZ:** pdfrx 2.x'in kendi sürüm kısıtı
    ">=3.7" dese de motoru `pdfrx_engine` TÜM sürümlerde Dart **>=3.8.1** ve
    `archive ^4` istiyor; CI (3.29.3 = Dart 3.7) + `excel`in `archive ^3` kısıtı
    ile pub çözümlemesi imkânsız. Yani "metin seçimi 2.0'da yeniden yazıldı"
    düzeltmesi paket yükseltmeyle alınamıyor.
  - **Karar:** seçim arayüzü bizim: `widgets/pdf_select_layer.dart` —
    pdfium karakter kutuları (`loadText().fragments[].charRects`) ekran
    koordinatına çevrilir; sürükleme/uzun basış karakter aralığına eşlenir,
    vurgu CustomPainter, kopyalama alt çubuktan. "Metin seç" modu açıkken
    `panEnabled=false` (jest çekişmesi kökten yok). 1.3.5'in SelectionArea
    yolu Android'de "tepki var, seçim yok" veriyordu → tamamen kaldırıldı.
  - **OCR:** `google_mlkit_text_recognition` **0.15.0 SABİT** (0.15.1+ Dart
    >=3.8). Cihaz-içi, Latin (Türkçe dahil), internet yok. Görsel → doğrudan;
    PDF → sayfa pdfium'la ~1600px PNG'ye çizilip tanınır (en çok 25 sayfa).
    Sonuç seçilebilir sayfada + panoya; taranmış PDF'te/görselde AI sohbet
    bağlamına da girer. ⋮ menüsünde "Metni tanı (OCR)".

- **2026-07-22 TUZAK — ML Kit + R8: "Missing class …text.chinese/japanese/korean/devanagari".**
  google_mlkit_text_recognition yalnız Latin AAR'ını getirir ama Java köprüsü
  dört dilin sınıflarına da referans verir → release küçültmede (R8) derleme
  KESİLİR (build #61). Çözüm: `ci/proguard-rules.pro` (4 satır `-dontwarn`) →
  CI'da `android/app/proguard-rules.pro`'ya kopyalanır; Flutter'ın Gradle
  eklentisi bu dosyayı otomatik dahil eder, build.gradle patch'i GEREKMEZ.

- **2026-07-22 — Gemini model listesi API'den otomatik çekilir.**
  Ayarlar'da API anahtarı girilince (600ms debounce) `GeminiService.listModels`
  (ListModels REST uç noktası) çağrılır; yalnızca `generateContent` destekleyen
  modeller döner, sürüm+yetenek sıralamasıyla (2.5 pro gibi en yeniler önde)
  dropdown'a dolar. Kayıtlı model bu hesapta yoksa listenin ilkine geçilir.
  Anahtar boş/geçersiz/ağ hatasında sessizce statik yedek listeye (`_fallbackModels`)
  düşülür — kullanıcı hiçbir zaman boş dropdown'la kalmaz. Elle "yenile" düğmesi var.
  *Test:* `http.runWithClient` + `MockClient` (paket zon-tabanlı override sağlıyor,
  GeminiService'e Client enjekte etmeye gerek kalmadı — düz REST sarmalayıcı ilkesi korundu).

- **2026-07-22 DÜZELTME — "runner atanamadan 3 sn'de düşme" GERÇEK KÖK NEDENİ: Actions
  DAKİKA KOTASI bitmiş.** build #63/#64 için "GitHub Actions altyapı arızası" diye
  yorumlanmıştı (job hiç loglanmadan saniyeler içinde failure oldu) — YANLIŞ teşhis.
  Kullanıcı doğruladı: hesabın aylık Actions dakikası tükenmişti; GitHub kotasız job'ı
  hiç kuyruğa almadan/runner atamadan anında reddediyor, bu da "altyapı arızası"yla
  AYIRT EDİLEMEZ şekilde görünüyor (ikisi de: 2-3 sn, log yok, `output.text` boş).
  **Ders:** bu belirtiyi görünce ARKA ARKAYA boş commit'le yeniden tetiklemek (yaptığımız
  hata) kotayı daha da tüketir/işe yaramaz — önce kullanıcıya sor ya da GitHub'ın
  Settings > Billing > Actions sayfasından kota durumunu kontrol et. Kota bitmişse tek
  çözüm: sonraki fatura döngüsünü beklemek ya da kullanıcının harcama limitini artırması
  (ajan bunu yapamaz). Bu proje ücretsiz/limitli kullanım hedeflediği için (bkz. CLAUDE.md
  §1) APK'yı yalnızca gerçekten istendiğinde derlemeye devam et (zaten mevcut politika).

## Build Geçmişi

| # | Sonuç | Not |
|---|---|---|
| build-1 | ❌ | pdfx engine API + compileSdk 34 (Flutter 3.24.5 uyumsuz) |
| build-2 | ✅ | Flutter 3.29.3'e yükseltildi |
| build-3 | ✅ | Firebase (guard'lı) eklendi, minSdk 23 |
| build-4 | ✅ | Office biçimli editörler (Excel / Word / Slayt) |
| build-5 | ✅ | Sabit imza (apksigner + secret bootstrap) — imzalı release üretildi |
| build-8 | ✅ | PPTX gerçek tasarım renderer'ı + CI'ya `flutter test` adımı (4/4 yeşil) |
| build-9 | ❌ | Secret'a yapışan CR → `base64: invalid input` (aşağıdaki tuzak) |
| build-10 | ✅ | **Kalıcı imzalı ilk sürüm** (SHA-256 `9eef6704…`), telefona kuruldu ve açıldı |
| build-11 | ✅ | Tam ekran sunum modu + zoom; kaldırmadan güncelleme ilk kez çalıştı |
| build-12..16 | ✅ | Animasyon adımları, Word sayfa görünümü (WebView), Excel ızgarası. APK 57 MB |

## Açık Durum / Bekleyenler

- ~~Kalıcı imza — kullanıcı aksiyonu bekliyor~~ → **ÇÖZÜLDÜ 2026-07-21:** kalıcı keystore
  üretildi ve `ANDROID_KEYSTORE_B64` secret'ı olarak eklendi. Artık her CI derlemesi AYNI
  anahtarla imzalanır → yeni APK eskisinin üstüne kurulur.
  - Anahtar dosyası: `C:\Users\sena\Desktop\dosya-okuyucu-imza\release.jks` (repo DIŞINDA).
    Parmak izi SHA-256 `9E:EF:67:04:C8:6F:74:76:...:4C:57:37:18`, alias `dosyaokuyucu`.
  - **Bu dosyayı kaybetmek = bir daha güncelleme yayınlayamamak.** Yedekle (repoya değil).
  - Parola workflow'da açık yazıyor ama repo PRIVATE; anahtar dosyası olmadan parola işe yaramaz.
- ~~main dalı yok~~ → **ÇÖZÜLDÜ 2026-07-21:** `main` oluşturuldu ve reponun varsayılan dalı
  yapıldı; yerel çalışma da `main`e alındı. Eski `claude/multi-format-file-reader-c9gh78` dalı
  aynı commit'te duruyor (silinmedi). Artık PR açılabilir.
- **Firebase config:** gerçek senkron için kullanıcı `flutterfire configure` yapmalı.

## Bilinen Riskler / Tuzaklar

- ~~Yerelde Flutter YOK~~ → **güncellendi 2026-07-21:** `C:\src\flutter\bin\flutter.bat` ile
  yerelde `test`/`analyze` çalışıyor; APK derlemesi yine CI'da doğrulanır.
- **Slaytta metin kutudan taşarsa** Column "RenderFlex overflowed" (sarı-siyah şerit) verir.
  Çözüm: `OverflowBox` (metin PowerPoint'teki gibi taşar, kırpılmaz). Widget testi yakaladı —
  `test/pptx_render_test.dart` bu yüzden var, silme.
- **Flutter API uyumu:** `withOpacity` / `value:` kullanıldı (3.29 uyumu).
  `CardThemeData` KULLANMA — sürüm hassas, derlemeyi kırar.
- **Platform klasörleri (`android/`, `ios/`) repoda yok**, CI'da `flutter create` ile üretilir.
  Yerelde de aynı adım gerekir (README).
- **Gizli anahtar / keystore repoya COMMIT EDİLMEZ** — güvenlik sınıflandırıcısı da engeller.
- **2026-07-21 TUZAK — `excel` paketinde iki hata (4.0.6):**
  1) Hizalama HİÇBİR dosyada okunmuyor: `parse.dart:445` `<alignment>` çocuğu yerine üst `<xf>`
     düğümünün özniteliklerine bakıyor. Çözüm: sayı/tarih hücrelerini varsayılan olarak sağa
     yasladık; açık hizalama beklemeyin (paket düzelirse kod kendiliğinden çalışır).
  2) `getColumnWidth/getRowHeight`, dosyada `defaultColWidth` yoksa **null hatası fırlatıp
     uygulamayı çökertiyor** (ICD10Listesi.xlsx'te yakalandı) → `xlsx_editor` içinde try/catch.
  *Ders:* gerçek dosyalarla duman testi yapmadan "çalışıyor" deme; sentetik dosya bu iki hatayı
  da göstermedi.
- **2026-07-21 TUZAK — Flutter'da çift dokunuş tek dokunuşu 300 ms geciktirir**
  (`kDoubleTapTimeout`). Sunum modunda dokunarak geçişte his gecikmeli; test de bu süreyi
  ilerletmeli (`pumpAndSettle` tek başına yetmez, zamanlayıcı kare planlamaz).
- **2026-07-21 TUZAK — örtük animasyon (AnimatedOpacity/AnimatedSlide) yapı değişirse oynamaz:**
  görünür durumda widget'ı sarmalayıp gizli durumda sarmalamazsan geçiş anında olur. İki durumda
  da aynı ağaç kalmalı (`_Reveal`).
- **2026-07-21 TUZAK — PowerShell borusu secret'a CR ekler:** `... | gh secret set X` ile
  yazılan base64'ün sonuna CRLF yapışıyor, CI'da `base64 -d` "invalid input" veriyor (build-9).
  Secret yazarken bash yönlendirmesi kullan: `gh secret set X < dosya` (dosyada CR/LF olmasın).
  Workflow artık `printf '%s' | tr -d '\r\n \t' | base64 -d` ile kendini koruyor.
- **2026-07-22 TUZAK — meta viewport'u JS ile değiştirmek Android WebView'da yeniden
  sığdırma YAPMAZ** (build 49'da Word sayfası "çok yakın" açıldı). Sığdırma CSS `zoom`
  ile yapılır (fitPage), viewport `device-width`te sabit kalır; pinch üzerine çarpan biner.
- **2026-07-22 TUZAK — contenteditable'da her tuşta tüm belgeyi taramak (querySelectorAll)
  yazmayı kastırır**; paragraf listesi düzenleme boyunca önbelleklenir, spellcheck kapatılır.
  Enter yeni `<p>` üretip indeks eşlemesini bozar → keydown'da satır sonuna (`w:br`) çevrilir,
  yapıştırma düz metne indirgenir.
- **İmza değişirse telefona kurulmaz:** `INSTALL_FAILED_UPDATE_INCOMPATIBLE`. Android, imzası
  farklı APK'yı mevcut verinin üstüne kurdurmaz → tek yol eskisini kaldırmak (uygulama verisi,
  yani kayıtlı Gemini anahtarı ve son dosyalar silinir). 2026-07-21'deki sabit anahtardan sonra
  bu bir daha yaşanmamalı. Kurulum: `adb install -r <apk>`; adb `%LOCALAPPDATA%\Android\Sdk\platform-tools`.
- `**.md` değişiklikleri CI'ı tetiklemez (workflow `paths-ignore`).
- **2026-07-21 TUZAK — graphify sandbox'ta çalışmaz:** ajan sandbox'ı DNS'i kesiyor,
  hata "Connection error" diye görünüyor → kota sanılıp boşuna key/model değiştiriliyor.
  Kök neden: `generativelanguage.googleapis.com` çözülemiyor. graphify'ı ağ erişimiyle çalıştır.
- **2026-07-21 TUZAK — repoda oturum başı otomatik `git pull` hook'u var**
  (`.claude/settings.json`, commit `d58fa94`). Oturum ortasında sessizce yeni commit
  getirebilir; beklenmedik bir üst commit görürsen sebebi budur, panik yapma.

## Yol Haritası (öncelik kullanıcıyla netleşecek)

1. ~~Office ileri düzenleme: Excel formül + satır/sütun; Word biçim araç çubuğu; slayt
   çoğalt/sil/taşı~~ → **YAPILDI 2026-07-21** (bkz. Sabit Kararlar). Kalan uçlar: Word'de
   liste (madde/numara) düğmesi, slayta görsel ekleme, Excel formül sonucunu önizleme.
2. Firebase config ile gerçek senkron + Google Sign-In SHA ekleme.
3. Format dönüştürme zenginleştirme (PDF ↔ Word ↔ Slayt).
4. AI: PDF'den otomatik slayt üretimi (genişletilmiş), kaynakları bağlama alma.
5. Masaüstü (Windows/macOS/Linux) build hedefleri + iOS.

## 2026-07-21 — Excel sayı biçimleri (görüntüleme sadakati)
- **Karar:** Excel hücrelerinde yüzde/para/binlik/ondalık biçimler artık Office'teki
  gibi görünüyor (ör. `0.15`→`%15`, `1234.5`→`₺1.234,50`, `1234567`→`1.234.567`).
  Türkçe gösterim: binlik `.`, ondalık `,`.
- **Kök neden / tuzak:** `excel` paketi (4.0.6) hücre sayı biçim kodunu (numFmt)
  vermiyor — sadece tarih/saat'i çözüyor. Çözüm: ham `.xlsx`'ten (ZipDecoder+xml)
  `xl/styles.xml` (numFmts + cellXfs) ve her `sheetN.xml`'deki `<c r s>` okunarak
  hücre→biçim kodu tablosu çıkarıldı (`XlsxEditor._readNumberFormats`).
- **Önemli tasarım kararı:** `XlsxSheet.rows` HEM ekran HEM `FormulaEngine` girdisi.
  Bu yüzden biçimlenmiş metin `rows`'a YAZILMAZ (yoksa `=A1*2` gibi formüller
  "%15"i sayı sanıp bozulur). Biçim yalnızca GÖSTERİM katmanında
  (`XlsxSheet.displayText`) uygulanır: önce FormulaEngine ham sonucu, sonra numFmt.
- Tarih biçimleri (numFmtId 14-22, 45-47) bilinçli dışarıda — excel paketi zaten
  DateCellValue'ya çeviriyor, üstüne biçim uygulanmaz.
- Test: `test/xlsx_number_format_test.dart` + fixture `test/fixtures/number_formats.xlsx`
  (elle üretilmiş minimal xlsx; LibreOffice bu sandbox'ta profil açamadığı için
  fixture Python zipfile ile yazıldı).

## 2026-07-21 — CI politikası: APK yalnızca istendiğinde (limit tasarrufu)
- **Sorun (kullanıcı):** her push'ta APK derleyip Release yapmak GitHub Actions
  dakikasını + depolamayı dolduruyor.
- **Karar:** `build-apk.yml` iki job'a bölündü:
  - `test` → HER push'ta (yalnızca `flutter test`; hızlı, APK/Release yok).
  - `apk`  → SADECE: commit mesajı `[apk]` içeriyor **veya** workflow_dispatch
    **veya** `main` dalı. İmzalı APK + Release burada.
- **APK istendiğinde nasıl üretilir:** commit mesajına `[apk]` ekle ve push et
  (ör. "release hazır [apk]"), ya da Actions'tan "Run workflow" (dispatch).
- Not: `test` job'ı `flutter create` yapmadan çalışır (saf Dart testleri platform
  klasörü istemez) → daha da ucuz.

## 2026-07-21 — TUZAK: commit mesajı işaretiyle CI tetikleme kırılgan
- Kök neden: apk job'ı `contains(head_commit.message, '[apk]')` ile tetikleniyordu.
  Politikayı ANLATAN commit'in gövdesinde geçen düz metin "[apk]" kelimesi bile
  eşleşip ~20 dk'lık ağır bir APK derlemesini yanlışlıkla başlattı (sonra runner
  shutdown sinyaliyle exit 143 iptal oldu — kod hatası DEĞİL).
- Çözüm: mesaj-işareti tamamen kaldırıldı. APK derleme yalnızca `workflow_dispatch`
  (elle/`actions_run_trigger`) veya `main`'de. Kullanıcı "APK ver" deyince dispatch et.
- Ders: CI koşullarını commit metnine bağlama; niyet/dispatch kullan.

## 2026-07-21 — APK derleme tetikleyicisi (dispatch API yasak!)
- `actions_run_trigger` (workflow_dispatch) API'si 403 "not accessible by
  integration" veriyor → ajan dispatch EDEMİYOR. main'e push da yok.
- Bu yüzden APK derlemenin TEK yolu: commit mesajına özel işaret koymak:
  `[release-apk]` (köşeli parantezli). Bu işareti YALNIZCA gerçekten APK
  istendiğinde commit mesajına yaz; açıklama/normal metinde asla kullanma.
- Kullanıcı "APK ver" deyince: `git commit --allow-empty -m "build: APK [release-apk]"`
  (veya bir özellik commit'inin mesajına ekle) → push → test sonra apk+release.

## 2026-07-21 — Eski Office (.doc/.xls/.ppt) SALT-OKUNUR görüntüleme
- **Karar:** eski ikili formatlar artık "harici aç" yerine cihazda gösteriliyor.
  - OLE2 CFB okuyucu (`ole_cfb.dart`) — kabın stream'lerini çıkarır (test #42 ✓).
  - `.xls` BIFF8 (`xls_legacy.dart`) — SST+BOUNDSHEET+LABELSST/RK/MULRK/NUMBER/
    FORMULA → hücreler → Excel ızgarası (salt-okunur) (test #43 ✓).
  - `.doc/.ppt` (`legacy_text.dart`) — stream'den en iyi çaba metin (UTF-16/CP1252
    tarama; biçim yok). Yetersizse "harici aç"a düşer (regresyon yok).
- **readOnly bayrağı** (LoadedDoc): legacy içerik OOXML editörlerine GİTMEZ,
  ViewerScreen'de gösterilir (home_screen yönlendirmesi).
- **Test edilemeyenler:** LibreOffice bu sandbox'ta profil açamıyor + olefile yok
  → gerçek .doc/.xls/.ppt fixture ÜRETİLEMEDİ. CFB ve BIFF sentetik (Python zipfile/
  struct ile elle) fixture'larla test edildi. .doc/.ppt metin çıkarımı gerçek dosyada
  kusurlu olabilir (sıra/boşluk) — dürüst "basit metin görünümü" etiketiyle sunulur.
- odt/ods/odp/rtf/pages/numbers/key hâlâ "harici aç" (kapsam dışı).

## 2026-07-22 — TUZAK+ÇÖZÜM: APK derlemesi geçici Gradle stall'ında 55 dk takılıp çöktü
- **Belirti (kullanıcı):** "derleme başarısız oldu ve çok uzun sürdü." Build #53
  (`f2fdd81`) `flutter build apk --release` adımında 12:36→13:31 = ~55 dk asılı
  kalıp job'ı çökertti. Aynı uygulama kodu bir sonraki koşuda (#54, `59bde00`)
  12 dk'da SORUNSUZ derlendi.
- **Kök neden:** kod hatası DEĞİL. #53 ile #54 arası fark yalnızca CI (`621ca97`)
  ve HAFIZA.md (`59bde00`) — `lib/` aynı. Yani geçici bir Gradle/ağ bağımlılık
  indirme stall'ı. Job'da `timeout-minutes` olmadığı için takılma uzun sürüp
  ~1 saat CI dakikası yaktı.
- **Çözüm (build-apk.yml, apk job):**
  1. `timeout-minutes: 30` — takılma bir daha ~1 saat yakamaz, hızlı başarısız olur.
  2. `actions/cache@v4` ile `~/.gradle/{caches,wrapper}` + `~/.pub-cache` önbelleği
     (anahtar: `pubspec.yaml` hash) — indirme diskten gelir, ağ stall'ına maruziyet düşer.
  3. `gradle.properties`'e `http.connectionTimeout/socketTimeout=120000` — asılan
     indirme 120 sn'de zaman aşımına uğrar, Gradle yeniden dener (sonsuz asılma yok).
- **Ders:** ağır CI job'larına HER ZAMAN `timeout-minutes` koy; Gradle ağ zaman
  aşımlarını sabitle. Geçmişte de benzer takılmalar oldu (#45 iptal, commit 409add6).

## 2026-07-22 — 3 KULLANICI HATASI: XLSX çökme, WhatsApp PDF tanınmama, slayt zoom zıplama
Kullanıcı gerçek dosyalarla bildirdi (SAHU bilgi formu .xlsx 996×26, Olgu_sunumu .pptx).

### 1) Büyük XLSX açılıp kaydırınca donup çöküyor (ANR)
- **Kök neden:** `SpreadsheetEditorScreen._cell` her görünür hücrede
  `sheet.styleAt` (→ excel paketi `_sheet.rows[r]`), `colWidth`, `rowHeight`
  çağırıyordu. excel 4.0.6'nın `rows`/`getColumnWidth`/`getRowHeight` getter'ları
  her çağrıda iç haritalardan yeniden üretilir (O(hücre)). Kare başına yüzlerce
  hücre × 25.896 hücre ⇒ O(hücre²) ⇒ ana izlek kilitlenir ⇒ ANR/çökme. Ayrıca
  her hücrede yeni `FormulaEngine` kuruluyordu.
- **Çözüm:** `XlsxSheet.rebuildCaches()` — stil/sütun-genişliği/satır-yüksekliği
  YÜKLEMEDE bir kez (excel `rows`'a tek erişimle) önbelleğe alınır; `styleAt/
  colWidth/rowHeight` artık O(1) düz-liste bakışı, excel paketine render'da hiç
  dokunulmaz. Yapısal işlemlerden (satır/sütun ekle-sil) sonra `rebuildCaches`
  tekrar çağrılır. `FormulaEngine` ekranda kare başına bir kez kurulur.
- **Ders:** excel paketinin getter'larını sıcak yolda (render) çağırma; yükleme
  anında düz veri yapısına çıkar.

### 2) WhatsApp'tan PDF açınca "dosya türü tanınmadı"
- **Kök neden:** `FileService.kindForExtension` yalnızca UZANTIYA bakıyor. Paylaşım
  (`receive_sharing_intent`) gelen dosyayı uzantısız/rastgele adlı bir önbellek
  yoluna kopyalıyor → `ext` boş → `unknown`. PDF'te NUL bayt olduğu için metin
  sniff'i de null döndürüp "unknown" bırakıyordu.
- **Çözüm:** `_sniffKind` — uzantı bilinmiyorsa İMZA BAYTLARINA bakar: `%PDF`→pdf,
  PNG/JPEG/GIF/BMP/WEBP/HEIC→image, `PK\x03\x04`→zip içine bakıp docx/xlsx/pptx.
  `load()` içinde metin sniff'inden ÖNCE çağrılır. word/slides artık uzantıdan
  bağımsız daima OOXML olarak çıkarılır (eski .doc/.ppt zaten yukarıda ayrılıyor).
- **Ders:** paylaşımla gelen dosyada uzantıya güvenme; içerik imzasıyla doğrula.

### 3) Slaytlarda pinch-zoom "zıplıyor" (önizleme)
- **Kök neden:** `SlidesEditorScreen._buildSlides` kart genişliğini
  `maxWidth*zoom - 32` ile ölçeklerken PinchZoomArea canlı önizlemeyi tek-tip
  (odaktan) GPU dönüşümüyle büyütüyordu. Sabit `-32` ve ölçeklenmeyen slayt-arası
  boşluk yüzünden yerleşim doğrusal değildi ⇒ parmak kalkınca commit edilen düzen
  canlı önizlemeyle örtüşmüyor ⇒ zıplama (aşağı slaytlarda daha belirgin).
- **Çözüm:** kart genişliği `(maxWidth-32)*zoom` ve slayt-arası boşluk `20*zoom`
  — yerleşim zoom'da DOĞRUSAL, böylece `layout(zoom)=zoom·layout(1)` ve GPU
  dönüşümüyle birebir örtüşür. PinchZoomArea'ya `ClipRect` (zoom'da taşma
  rozetin/çubukların üstüne binmesin). NOT: editör önizlemesi kasıtlı olarak
  yeniden-yerleşimle NET tutulur (InteractiveViewer değil — o bulanıklaştırırdı).

## 2026-07-22 — 2. TUR (build-56 sonrası kullanıcı testi): XLSX hâlâ çöküyor, slayt zoom hâlâ sorunlu
- PDF imza tespiti kullanıcıda DOĞRULANDI ✓ (WhatsApp PDF artık açılıyor).
- **XLSX çökmesinin ASIL kök nedeni açılış:** stil önbelleği (1. tur) kaydırma
  render'ını düzeltti ama `Excel.decodeBytes` 25.896 stilli hücrede onlarca
  saniye sürüyor ve ANA İZLEKTE, üstelik İKİ KEZ koşuyordu (FileService.load
  plainText için + editörün kendi parse'ı) → açılışta donma → ANR → sistem
  öldürüyor. Çözüm: her iki çözümleme de `compute` ile arka plan isolate'ine
  taşındı (başarısız olursa ana izleğe düşer — işlev aynı, testler etkilenmez).
- Kullanıcının dosyasında **dondurulmuş bölme** var (`pane xSplit=5 ySplit=2
  state=frozen` — Excel'de sol 5 sütun + üst 2 satır sabit; kullanıcının
  "sağ/sol ayrı oynuyor" dediği bu). Bölme çökme nedeni DEĞİL; biz yok sayarız
  (tek parça kaydırma). Bölme desteği istenirse ayrı özellik.
- **Slayt zoom (kalan):** kart genişliği doğrusaldı (1. tur) ama BAŞLIK şeridi
  ("Slayt N" + düğmeler) sabit yükseklikteydi → yerleşim yine doğrusal değil →
  commit'te kayma sürdü. Çözüm: başlık `SizedBox(40*zoom)+FittedBox` ile
  ölçeklenir; liste kenar boşlukları da (`16/8/32*zoom`) doğrusallaştırıldı.
  Artık layout(zoom) = zoom·layout(1) her bileşende geçerli.
- KVKK notu: kullanıcının SAHU dosyası hasta bilgi formu — fixture olarak
  repoya ASLA konmaz; sentetik üretim gerekirse Python zipfile ile.

## 2026-07-23 — PDF seçim tutamaçları + slaytta CANLI (yerinde) metin düzenleme
- **Slayt düzenleme popup'tan yerinde'ye (kullanıcı kararı):** metin kutusuna
  dokununca artık `showModalBottomSheet` DEĞİL; kutunun paragrafları slaytın
  üstünde, aynı konum/ölçekte `TextField` olur. Ölçek/konum matematiği YOK —
  düzenlenebilir alanlar `SlideCanvas` içindeki `FittedBox`'ın (pt) koordinat
  uzayına konur, ölçek bedavaya gelir. Biçim çubuğu (B/İ/altçizili+punto+Bitti)
  klavyenin üstünde yüzer. Eşleme: `editControllers` şeklin ParaVM sırasıyla
  hizalı (düzenlenemeyen paragraf = null); düzenlenen şekil `identical()` ile
  eşlenir (düzenlerken yeniden çizilmediği için nesne kararlı, id çakışması yok).
  Sadakat eskisiyle AYNI (biçim tüm kutuya). Tam zengin (run-bazlı) inline
  düzenleme kapsam dışı bırakıldı.
- **PDF seçimi (premium):** kendi seçim katmanımıza (pdf_select_layer) uçlarda
  sürüklenebilir tutamaç + üstte "Kopyala" balonu eklendi. `_selectWordAt` artık
  `_report()` çağırıp seçimi anında panoya/üst katmana yansıtıyor.
- **YEREL APK DERLEME TUZAĞI:** yerel Flutter 3.44 + AGP 9.0.1, eski plugin
  AAR'larıyla (`file_picker` android-34, `receive_sharing_intent` compileSdk 37)
  zincirleme "compileSdk çok düşük" hatası verir → yerelde APK ÜRETİLEMİYOR.
  CI'nin 3.29.3'ünde sorun yok. Sonuç: APK yalnızca CI'da derlenir; yerel
  `flutter build apk` doğrulama için kullanılmaz (analyze+test yeter).
  → **GÜNCELLENDİ (aynı gün, 2026-07-23):** engel aşıldı, yerelde `android/`
  iskeleti üretildi ve `flutter build apk --release` ÇALIŞIYOR (13:29'da APK
  üretildi, telefona 13:34'te kuruldu). Actions kotası kapalıyken tek APK yolu
  budur. **DİKKAT — İMZA:** yerel `android/app/build.gradle.kts` release'i
  `signingConfigs.getByName("debug")` ile imzalar → CI Release'lerinden FARKLI
  imza. Telefonda şu an yerel (debug imzalı) sürüm var; CI APK'sına dönmek
  istenirse önce uygulamayı kaldırmak gerekir (veri gider) ya da yerel derlemeyi
  `apksigner` ile `dosya-okuyucu-imza\release.jks` anahtarıyla yeniden imzala.

## 2026-07-23 — Faz 2: Excel hücre içi yazma (canlı hücre)
- **Karar:** düzenleme artık yalnız formül çubuğundan değil, hücrenin İÇİNDE.
  Tetikleyici **seçili hücreye ikinci dokunuş** — çift dokunuş DEĞİL
  (`kDoubleTapTimeout` tek dokunuşu 300 ms geciktirir; aynı gerekçe zoom'da da
  vardı, bkz. 2026-07-22 Faz 0).
- **Formül çubuğu ile hücre AYNI `TextEditingController`'ı paylaşır** → yazdıkça
  ikisi de güncel; ayrı controller + senkron kodu YAZILMADI. Aynı anda tek alan
  düzenlenebilir durumda mount edildiği için seçim/odak çakışması yok.
- Kirlilik sigortası: `_endEdit` içerik gerçekten değiştiyse yazar → hücreye
  girip çıkmak dosyayı "kaydedilmemiş" göstermez. Enter = yaz + bir alt hücre.
- Açık düzenleme şu üç noktada kapatılır (yanlış hücreye yazma riski):
  yapısal işlem (`_afterStructural`, satır/sütun kayar), sayfa sekmesi değişimi,
  kaydetme (`_save` — yazılmakta olan içerik kaydın dışında kalmasın).
- **TUZAK (test, yerelde yakalandı) — `.then(onError:)` void döndüremez:**
  `future.then((_) => fail(...), onError: (e) { expect(...); })` çalışma anında
  "Invalid argument(s) (onError): The error handler of Future.then must return
  a value of the returned future's type" atar (gemini_service_test kırmızıydı).
  Doğrusu: `expectLater(future, throwsA(isA<X>().having(...)))`.

## 2026-07-23 — Repo PUBLIC yapıldı (Actions kotası) + keystore parolası döndürüldü
- **Niye:** Actions dakika kotası bitince APK/Release işleri log üretmeden düşüyordu;
  public repolarda Actions dakikası sınırsız. Kullanıcı kararı: public.
- **Public'ten ÖNCE yapılan güvenlik işi (sıra önemli):** keystore parolası
  workflow'da düz metindi ve git GEÇMİŞİNDE kalıyordu → dosyadan silmek kozmetik
  olurdu. Bu yüzden parola `keytool -storepasswd` ile değiştirildi:
  - Sertifika/parmak izi AYNI (`SHA-256 9E:EF:67:04:…:4C:57:37:18`) → telefondaki
    uygulama güncellenmeye devam eder, kimse uygulamayı kaldırmak zorunda kalmaz.
  - Yeni parola `ANDROID_KEYSTORE_PASSWORD` secret'ı; yeni `.jks`ın base64'ü
    `ANDROID_KEYSTORE_B64` secret'ına yeniden yüklendi (ikisi de `gh secret set < dosya`
    ile — PowerShell borusu CR ekler, bkz. build-9 tuzağı).
  - Keystore yedeği: `dosya-okuyucu-imza\release.jks.yedek-20260723` (ESKİ parolalı).
  - Workflow artık `secrets.ANDROID_KEYSTORE_PASSWORD || 'DosyaOkuyucuGecici'` kullanır:
    fork'ta secret yoksa derleme kırılmaz, geçici anahtarla imzalanır.
- **Public olduğu için bilinçli kabul edilenler:** kaynak kodun tamamı + git geçmişi,
  HAFIZA/KALANLAR karar notları, commit yazar e-postası. Taramada `.jks`, gerçek API
  anahtarı, `google-services.json` veya hasta verisi YOK (SAHU/Olgu dosyaları hiç
  commitlenmemiş — KVKK ilkesi tuttu).

## 2026-07-23 — İkinci GitHub hesabı: GCM kimlik çakışması tuzağı
- **Karar:** repo `kaimau1/dosya-okuyucu`'da KALIYOR (private). İkinci hesap
  `hekimasistanitr` yalnızca `gh`'ye eklendi; repo transferi/fork yapılmadı.

## 2026-07-23 — Slayt sadakati %95 hedefi: font + bağlayıcı/gölge + grafik (3 faz)
Kullanıcı "slayt sadakati %95" istedi; renderer tahminî ~%80-85'teydi. Kod
HAFIZA'daki eski "gradient/tablo kapsam dışı" notunu çoktan geçmişti (gradient
+ tablo zaten vardı). Kalan gerçek açıklar 3 fazda kapatıldı (hepsi main'de).

- **Faz 1 — Fontlar (en yüksek getiri, her slaytı etkiler):** metin artık Roboto
  değil, PowerPoint fontlarının **metrik-uyumlu açık kaynak** karşılıklarıyla
  çiziliyor. `assets/fonts/`: **Carlito**(Calibri) · **Arimo**(Arial) ·
  **Tinos**(Times) — hepsi OFL, ~6.6MB. `pptx_render._resolveFont`: typeface
  rPr→defRPr→tema (major/minor, `+mj-lt`/`+mn-lt` çözülür), `_mapFamily` ile
  aileye eşlenir (serif→Tinos, arial/helvetica→Arimo, kalanı→Carlito). Tema
  fontları `_themeFonts` (`a:fontScheme`). **TUZAK:** Arimo google/fonts'ta
  yalnız **değişken (variable) font** olarak var (statik yok) → pubspec'te
  değişken kayıt, kalın `wght` ekseninden gelir; cihazda kalın-Arial görünümü
  DOĞRULANMADI. Küçültme hilesinin gerekçesi değişti: artık "Calibri≠Roboto"
  değil, metrik doğru → `_fitScale` çoğu kutuda 1 döner, yalnız gerçek taşmada
  güvenlik ağı. **Ayrıca not:** `assets:` altına `assets/fonts/` EKLENMEDİ —
  fontlar `fonts:` bloğundan gömülüyor, .txt lisanslar repoda kalıyor.
- **Faz 2 — Bağlayıcı + çizgi/ok + gölge:** `p:cxnSp` ve line/connector
  geometrileri `_walk`'ta `p:sp` gibi işlenip `ShapeVM.isLine` ile
  `_LinePainter`e (köşe-köşe, flipH/flipV, `head/tailEnd`→ok, `prstDash`→kesik)
  çiziliyor. Eğik/kavisli bağlayıcı **düz çizgiyle yaklaşıklanır**. Yatay/dikey
  çizginin 0 boyutu strokeWidth tabanıyla çizilebilir kılınır (yoksa Positioned
  0 yükseklikte kırpardı). `a:effectLst/outerShdw`→Flutter `BoxShadow` (kutu
  şekillere). nv id araması `p:nvCxnSpPr`yi de kapsar.
- **Faz 3 — Grafik (chart):** graphicFrame içindeki `c:chart` artık boş delik
  değil. `_graphicFrame` tablo/grafik ayırır; grafik AYRI parçadır (`r:id` →
  slide rels → `ppt/charts/chartN.xml`), `_parseChart` → `ChartVM`
  (sütun/çubuk/pasta+halka/çizgi; alan→çizgi). Seri renkleri `c:spPr` yoksa
  **tema aksan paletinden** (accent1-6), pasta dilimleri kategori başına.
  Çizim `widgets/chart_painter.dart` (`ChartPainter`): eksen+3 ızgara+lejant+
  çubuk/dilim/çizgi. **Kapsam dışı:** dağılım/radar/borsa grafiği + SmartArt.
  Stil sade (3B/gradient/eksen süsü yok) ama veri+oran+renk PowerPoint'le aynı.
- **TUZAK (Dart):** `(_alan1, _alan2) = kayıt;` pattern assignment **instance
  alanına yapılamaz** ("Only local variables can be assigned") → önce yerel
  değişkene al, sonra alanlara ata.
- **Doğrulama:** bu Windows makinesinde yerel `flutter test` (204 yeşil) +
  `analyze` (yeni kod temiz; kalan uyarılar önceden var olan kasıtlı
  `withOpacity` CI-3.29 uyumu). Grafik/font GÖRSEL kalitesi + değişken-Arimo
  kalını cihazda test EDİLMEDİ (ekran aracı yasak; APK CI'da). → KALANLAR.
- **Tetiklenen ana kod:** `services/pptx_render.dart` (RunVM.fontFamily,
  ShapeVM.isLine/flip/arrow/dashed/shadow/chart, ChartVM/ChartSeries/ChartType,
  `_resolveFont`/`_mapFamily`/`_themeFonts`/`_outerShadow`/`_parseChart`),
  `widgets/slide_canvas.dart` (`_LinePainter` + fontFamily + chart/line branch),
  `widgets/chart_painter.dart` (yeni). Grafik ayrıntısı → graphify.

## 2026-07-23 — PDF geliştirme: Syncfusion eklendi (ağır-dep ilkesi geri alındı)
- **Karar (kullanıcı, itirazım kayıtta):** PDF'e annotation/sayfa-düzenleme/form
  için `syncfusion_flutter_pdf` eklendi. "Hafif/ücretsiz/ağır-dep-yok" ilkesinden
  BİLİNÇLİ sapma — kullanıcı 4 özelliği (arama, annotation, sayfa düzenleme, form)
  istedi; bunların 2-4'ü ancak ağır PDF-yazma kütüphanesiyle olur. pdfrx salt-render,
  `pdf` paketi mevcut sayfa alamıyor → tek yol Syncfusion.
- **SÜRÜM SABİT: `syncfusion_flutter_pdf: 31.1.19` + `syncfusion_flutter_core: 31.1.19`.**
  *Niye pin:* 32+ (ve core 31.2.x) **Flutter >=3.35.1** ister → CI 3.29.3'ü kırar.
  31.1.x `flutter>=3.29.0` + Dart 3.7 + `xml >=6.5.0 <7.0.0` (bizim `^6.5.0` ile
  birebir, cascade YOK) + `archive`'a bağlı DEĞİL (excel'in `archive ^3`'üyle
  çakışmaz). **TUZAK:** pdf'in dep'i `^31.1.19` core'u 31.2.18'e çekiyordu (Flutter
  3.35) — yerel 3.44 gizledi; core'u da elle 31.1.19'a pinledim. Doğrulama:
  pub.dev API'sinden sürüm kısıtları tarandı (yerel resolüsyona güvenme, HAFIZA tuzağı).
- **Mimari:** görüntüleme **pdfrx/pdfium'da KALIR** (yüksek sadakat); Syncfusion
  yalnız düzenlenmiş PDF ÜRETİR (annotate/düzenle/form → yeni bayt → dosyaya yaz →
  pdfrx'te yeniden aç). İki PDF yığını yan yana, bilinçli.
- **Lisans:** Syncfusion Community License (birey/küçük ekip ücretsiz). PDF
  *kütüphanesi* çalışma-anı banner göstermez (o SfPdfViewer gibi UI widget'larında).
  Repo public → bağımlılık görünür. Kullanıcı uygunluğu varsayıldı.
- **YAPILDI:** Faz 0 (dep + duman testi `syncfusion_pdf_smoke_test`, CI 3.29.3'te
  test-green → Syncfusion derleniyor doğrulandı). Faz 1 (belge içi arama + sayfaya
  atlama + vurgu; pdfrx'in hazır `PdfTextSearcher`'ı, Syncfusion'sız — `viewer_screen`
  `_pdfController`/`_pdfSearcher`, find bar PDF için dallandı). İkisi de main'de push'lı.
- **KALDI (cihaz doğrulaması şart, koordinat/UI kodu):** Faz 2 annotation, Faz 3
  sayfa düzenleme, Faz 4 form → ayrıntı KALANLAR.md. Faz 1'in aksine bunlar benim
  koordinat eşlemem; kör push riskli, cihazda test edilmeli.
  Actions dakika kotası derdi varsa gerçek çözümler: repo'yu public yapmak
  (sınırsız dakika) veya ücretsiz organization açmak — ikinci ücretsiz kişisel
  hesap GitHub ToS'a aykırı, kota için kullanılmamalı.
- **KÖK NEDEN / TUZAK:** `gh auth login` ile ikinci hesap eklemek, Windows
  Credential Manager'daki TEK github kaydını (`git:https://github.com`) yeni
  hesapla EZDİ → bu repoda `git fetch/push` → `remote: Repository not found`
  (private repo yetkisiz kullanıcıya 403 değil 404 döner, yanıltıcı).
- **`gh auth switch` bu makinede git'i ETKİLEMEZ:** credential helper `gh`
  değil, Git Credential Manager (`credential.helper=manager`). gh ve git ayrı
  kimlik deposu kullanıyor; switch sadece `gh` komutlarını değiştirir.
- **ÇÖZÜM (kalıcı, repo başına):** remote URL'e kullanıcı adı gömüldü →
  `https://kaimau1@github.com/kaimau1/dosya-okuyucu.git`. GCM kimliği
  `kullanıcı+host` anahtarıyla saklar, her repo kendi hesabını kullanır,
  hesap değiştirme dansı bitti. Doğrulandı: `git ls-remote origin` → exit 0.
- Yeni bir makinede/yeni klonda aynı hata görülürse: `git remote set-url` ile
  kullanıcı adını URL'e ekle, sonra bir kez `git fetch` (GCM penceresi açılır).

## 2026-07-23 — AI yanıtlarında Markdown temizliği + "Word'e aktar"
- **Sorun (kullanıcı):** AI yanıtları ekranda ham `**kalın**`, `# başlık`,
  `- madde`, `| tablo |` işaretleriyle çirkin görünüyordu (chat balonu düz
  `SelectableText(turn.text)` idi).
- **Karar / çözüm:** işaretleri SİLMEK yerine GERÇEK BİÇİME çevirmek — hem
  temizlik hem "Office hissi". Bağımlılıksız saf-Dart ayrıştırıcı
  `lib/core/markdown.dart`:
  - `parseMarkdown` → blok listesi (başlık/madde/numaralı/alıntı/kod/çizgi/
    tablo + satır-içi kalın/italik/kod/üstü-çizili/bağlantı).
  - `stripMarkdown` → tüm belgeyi düz metne indirir (hafızaya kaydet için).
  - `stripInlineMarkdown` → tek satırın işaretlerini + baştaki liste/başlık
    işaretini kaldırır (slayt/PDF dışa aktarımı için).
  - **REDDEDİLEN yol:** `markdown` paketi — APK şişkinliği + CI 3.29.3/Dart 3.7
    sürüm hassasiyeti (bkz. genel "düz REST/bağımlılık istenmedi" ilkesi).
  - `widgets/markdown_text.dart` blokları `SelectableText.rich` ile çizer
    (seçilebilirlik korunur). **TUZAK:** Flutter `Table` her satırda EŞİT hücre
    sayısı ister → düzensiz AI tablosu çökebilir; sütun sayısı normalize edilip
    eksik hücreler boş span'le dolduruluyor (hem widget hem docx üreticisinde).
- **Yeni özellik — "Word'e aktar" (`services/markdown_export.dart`):** AI
  yanıtını düzenlenebilir gerçek `.docx`e çevirir. `blankDocx`in ham-OOXML
  desenini izler (Content_Types + rels + document.xml, `_zip` ZipEncoder).
  Biçim DOĞRUDAN verilir (rPr/pPr) — `styles.xml` yok, paket hep geçerli.
  Başlık büyük punto+bold, listeler girintili, Markdown tablosu → Word `w:tbl`
  (tablo sonrası boş `<w:p/>` şart, yoksa Word onarım uyarısı). XML özel
  karakterleri kaçırılır (`_esc`), aksi halde bozuk paket.
- **Doğrulama:** yerelde Flutter YOK (bkz. 2026-07-23 yerel APK tuzağı — bu
  Linux bulut oturumu, Windows makine değil). Doğrulama tamamen CI `flutter
  test`. Testler saf-Dart mantığa yazıldı: `test/markdown_test.dart` (parser +
  strip) ve `test/markdown_export_test.dart` (üretilen .docx geri açılıp
  `word/document.xml` içerik/biçim doğrulanır). CI run #68/#69 test job yeşil.
- **APK:** kullanıcı "main'e pushla, APK oluşsun" dedi → iş main'e alındı
  (apk job yalnız main'de/dispatch'te çalışır). build #70 ✅ (imzalı Release
  v0.1.0-build-70, APK 118 MB).

## 2026-07-23 — AI çıktısını Office'e aktar ekosistemi (Word + Excel + Sunum)
- **Karar:** AI sohbet yanıtı artık üç Office biçimine dışa aktarılabiliyor;
  balondaki dağınık düğmeler tek "Aktar" `PopupMenuButton`'ında toplandı:
  Word (.docx) · Excel (.xlsx) · Sunum (PDF). Ayrıca "Kopyala" (düz metin
  panoya, `stripMarkdown`) ve mevcut "Hafızaya kaydet".
- **Excel üretimi (`MarkdownExport.toXlsx`):** `excel` paketiyle gerçek .xlsx.
  Markdown tablosu → gerçek satır/sütun; tablo dışı içerik tek sütun (kayıp yok);
  sayısal hücre gerçek sayı (`_xlsxCell`), "007" gibi baştaki sıfırlı diziler
  metin kalır.
  - **TUZAK / önlem:** yerelde Flutter/pub-cache YOK → excel API'sini derleyip
    doğrulayamıyorum. Bu yüzden `appendRow` / `getDefaultSheet` / `maxRows` gibi
    SÜRÜM-BELİRSİZ çağrılardan kaçınıldı; yalnız kod tabanında KANITLI API
    kullanıldı: `excel['Sheet1']`, `sheet.cell(CellIndex.indexByColumnRow(...))
    .value = ...`, `excel.encode()` (bkz. xlsx_editor). Test de kanıtlı
    `Excel.decodeBytes` + `sheet.rows` + CellValue tipiyle doğruluyor
    (`TextCellValue.value.toString()` deseni; ham `.toString()` kırılgan).
- **Sunum PDF:** yeni kod yok — mevcut `ConversionService.textToSlidesPdf`
  yeniden kullanıldı (girdi `stripMarkdown` ile temizlenir).
- **Doğrulama:** CI test job yeşil (run #71). Sonra main'e ff-merge (#72 APK).
- **Dal notu:** PR #5 merge edildikten sonra bu tur main ucundan devam etti;
  yeni commit'ler yeni değişiklik olarak main'e ff-merge edildi (merged PR'a
  commit yığılmadı — kural gereği).

## 2026-07-23 — CSV/TSV birinci sınıf: ızgarada aç + dışa aktar
- **Karar:** CSV artık düz metin değil. `.csv/.tsv` gerçek satır/sütun
  tablosuna çözülüp SALT-OKUNUR elektronik tablo ızgarasında açılıyor —
  eski `.xls`'in kullandığı `LoadedDoc.table` + `readOnly` yolu yeniden
  kullanıldı (home_screen readOnly → ViewerScreen → `_SpreadsheetView`).
  Düşük risk: yükleme/render makinesi zaten vardı.
- **`services/csv_codec.dart`:** bağımlılıksız RFC 4180 parse/encode +
  ayraç otomatik saptama (`,` `;` sekme — Türkçe Excel `;` kullanır).
  Tırnaklı alan, `""` kaçışı, alan içi ayraç/yeni satır. `file_service`
  csv/tsv'yi `_textExts`'ten çıkardı, `_loadCsv` ile erken dallandı.
- **Dışa aktarım:** elektronik tablo editörüne "CSV olarak dışa aktar"
  (`;` + UTF-8 BOM `﻿` → Excel Türkçe karakterleri düzgün açar);
  AI "Aktar" menüsüne CSV (.csv) — `MarkdownExport.toCsv` + ortak `_rows`
  (toXlsx/toCsv paylaşımlı satır üretimi).
- **Not (çökme önlem):** `_SpreadsheetView` düzensiz (farklı uzunlukta)
  CSV satırlarına karşı zaten korumalı (`c < row.length ? row[c] : ''`),
  ayrıca sütun 64 / satır 2000 ile sınırlı (mevcut .xls davranışı).
- **Doğrulama:** CI test job yeşil (run #73): csv_codec_test (RFC uçları +
  round-trip), file_service_test (.csv `;` + .tsv sekme gerçek dosya yükleme),
  markdown_export_test (toCsv). Sonra main → APK (#74).

## 2026-07-23 — Açık kaynak araştırması → Markdown + kodlama iyileştirmeleri
- **Yöntem:** iki arka plan araştırma ajanı (İngilizce/uluslararası kaynaklar):
  (1) LLM-markdown renderer'ları — gpt_markdown, flutter_markdown (Google
  2025-05 terk etti → flutter_markdown_plus), markdown_widget, CommonMark/GFM;
  (2) Dart office/kodlama pratikleri. Düşük riskli + saf-Dart + test edilebilir
  olanlar seçildi; ağır bağımlılık EKLENMEDİ.
- **Markdown (core/markdown.dart + widgets/markdown_text.dart):**
  - **Vurgu flanking (CommonMark)** — en değerli düzeltme: `2 * 3 = 6` artık
    italik olmuyor. `_canToggle`: açılışta işaretten SONRA, kapanışta ÖNCE
    boşluk olmamalı. `_` için kelime-sınırı kuralı korundu (snake_case).
  - Ters bölü kaçışı `\*`, görsel `![alt](url)`→alt, autolink `<url>`,
    başlıkta kapanış `##`, GFM görev listesi `- [ ]/[x]`→☐/☑.
  - Kod bloğu: dil etiketi + Kopyala + yatay kaydırma (uzun satır sarmaz).
  - Tablo hizası `:--:` → widget `TextAlign` + docx `w:jc`; sert satır sonu.
- **Kodlama (services/text_decode.dart):**
  - **P1 (bug):** kendi yazdığımız BOM'lu CSV geri açılınca ilk hücreye
    görünmez `U+FEFF` yapışıyordu (BOM export'un yan etkisi) → içe alımda BOM
    baytları + kalan U+FEFF temizlenir. Round-trip düzeltmesi.
  - **P2:** strict UTF-8 başarısızsa **Windows-1254** (Türkçe) — eski `latin1`
    düşüşü `ğ/ş/İ/ı`'yı bozuyordu (mojibake). cp1254 tek-bayt tablo.
  - **P4:** AI→CSV'de formül enjeksiyonu önlemi (`=`/`@`/sayı-olmayan `±`
    başına `'`); kullanıcının kendi formülleri için varsayılan KAPALI.
  - **P5:** ayraç tespiti `|` eklendi + ilk ~5 satırda tutarlılık puanı.
- **REDDEDİLEN (araştırma kararı, HIGH-RISK):** sıfırdan `.pptx` üretimi —
  master/layout/theme zorunlu + döngüsel rel'ler, gerçek PowerPoint'te
  doğrulanamaz (yerelde Flutter yok) → PDF slaytta kalındı. Gerçek
  `numbering.xml` liste de gereksiz risk → literal önek (`•`/`1.`) korunur.
  Syncfusion = ücretli/ağır → kullanılmaz.
- **TUZAK (kendi test hatam):** backslash testinde beklenen metinde "fiyat "
  önekini atlayınca run #75 kırmızı; kod doğruydu, beklenti düzeltildi (#76).
- **Doğrulama:** CI test job yeşil (run #76). Sonra main → APK (#77).

## 2026-07-23 — Sözcük sayacı + Türkçe-duyarlı belge içi arama
- **Bulgu:** find-in-document zaten vardı (durum/sonraki/önceki) ama arama
  `toLowerCase` ile yapılıyordu → Dart yerel-duyarsız: `İSTANBUL` aranınca
  `istanbul` bulunmuyor, `I`→`i` (Türkçe'de `ı` olmalı).
- **core/text_search.dart (saf Dart):**
  - `turkishFold`: `İ→i`, `I→ı`, kalanı `toLowerCase`; her karakter TEK
    karaktere iner → kaynak metinle indeks hizalı (eşleşme konumu doğru).
    (`İ`.toLowerCase() 2 kod birimi verip indeksi kaydırıyordu.)
  - `findAll`: Türkçe-katlamalı, çakışmasız, `limit`li tüm eşleşme indeksleri.
  - `TextStats`: sözcük/karakter/karakter-boşluksuz/satır/paragraf.
- **viewer:** `_runFind` artık `findAll` kullanıyor (İSTANBUL↔istanbul eşleşir,
  dotsuz `I` ile noktalı `i` karışmaz). ⋮ menüsüne "Sözcük sayısı / bilgi"
  diyaloğu (`_showStats`) — metin taşıyan belgelerde görünür.
- **Doğrulama:** CI test job yeşil (run #78). Sonra main → APK (#79).

## 2026-07-23 — Üç özellik: Excel formül önizleme + CSV kodlama + Word liste
- **Excel formül önizleme:** formül çubuğuna `=` yazılırken altında canlı
  sonuç (`= 42`). `FormulaEngine.preview(formula, r, c)` — grid'e göre hesaplar,
  (r,c) ziyaret kümesine konarak kendine-referans döngüsü yakalanır.
  *Tuzak (test):* boş ızgarada `=A1` DÖNGÜ vermez (boş hücre kısa devre) —
  döngü testi grid'i kendine-referanslı (`[['=A1']]`) olmalı. Önizleme
  formül çubuğu düzenlemesi içindir; in-cell düzenlemede canlı güncellenmez
  (aynı controller ama onChanged o alanda tetiklenmez — bilinçli, basit).
- **CSV kodlama seçeneği:** elektronik tablo CSV dışa aktarımı artık kodlama
  soruyor — UTF-8 (BOM, modern) / Windows-1254 (eski Türkçe Excel).
  `TextDecode.encodeCp1254` (decode'un tersi; ters harita _c1+_high'tan;
  cp1254 dışı karakter → `?`). Round-trip decode↔encode testi.
- **Word madde/numara listesi:** yedek editör (plain) biçim çubuğuna madde (•)
  + numaralı liste düğmeleri. **Gerçek `numbering.xml` KULLANILMADI** (araştırma:
  yerelde Word'de doğrulanamaz, bozulma riski) → `core/list_prefix.dart` düz
  metin öneki (`• ` / `N. `). Numara üstteki ardışık numaralı paragraflara göre
  sıralanır. Yalnız non-rich paragrafta save() `.text`'i yazar (rich=WebView
  canlı düzenleme, orada liste kapsam dışı).
- **Doğrulama:** CI test job yeşil (run #80). Sonra main → APK.

## 2026-07-23 — PDF Faz 2: seçili metni kalıcı vurgulama (Syncfusion annotation)
- **Yapıldı/karar:** "Metin seç" modunda seçilen metin artık sarı/yeşil/pembe/mavi
  (kullanıcı seçimi: *birkaç renk*) **kalıcı highlight annotation** olarak PDF'e
  yazılıyor — kapatıp açınca ve başka PDF okuyucularda da görünür. Mimari
  değişmedi: görüntüleme pdfrx/pdfium'da, YAZMA Syncfusion'da.
- **Yeni/değişen dosyalar:** `services/pdf_annotator.dart` (`PdfAnnotator.addHighlight`:
  `PdfDocument(inputBytes)` → `page.annotations.add(PdfTextMarkupAnnotation(bounds,'',
  PdfColor, boundsCollection: satır dikdörtgenleri))` → `save()`); `widgets/pdf_select_layer.dart`
  (`onSelected` artık `(text, List<PdfRect>, pageNo)` raporluyor; ekran boyası +
  annotation AYNI geometriyi kullansın diye ortak `selectionPdfRects` helper'ı);
  `viewer_screen` (seçim çubuğunda renk sırası + "Vurgula", `_highlightPdf`);
  `file_service.writeBytes`.
- **KOORDİNAT TUZAĞI (çözüldü + testli):** pdfrx `PdfRect` origin sol-alt / Y-yukarı
  (`top > bottom`, `height = top - bottom`); Syncfusion/Flutter `Rect` sol-üst / Y-aşağı
  → `Rect.fromLTWH(left, pageHeight - pdfTop, w, h)`, `pageHeight = Syncfusion page.size.height`.
  `test/pdf_annotator_test.dart` bu çevrimi cihazsız doğrular (Syncfusion PDF I/O'su
  gerçek dosya/cihaz ister; risk sadece bu matematikte). ponytail: `/Rotate=0` varsayar.
- **YENİDEN YÜKLEME TUZAĞI:** pdfrx `PdfDocumentRefFile` eşitliği yalnız dosya yoluna
  bakar (`file == other.file`) → aynı yola tekrar yazınca `PdfViewer` OTOMATİK
  YENİLEMEZ (vurgu görünmez). Çözüm: `PdfViewer.file`'a `key: ValueKey(_pdfReloadKey)`,
  vurgudan sonra `key++` → remount → yeni bayt; `initialPageNumber: _pdfPage` ile
  aynı sayfada açılır.
- **Syncfusion API (31.1.19 pub cache'ten okundu, kör push yok):** `PdfDocument({inputBytes})`,
  `pages[i]`, `page.size` (Size, pt), `page.annotations.add()`→int, `save()` **async**
  (`Future<List<int>>`; `saveSync()` de var), `PdfColor(r,g,b,[a=255])`,
  `PdfTextMarkupAnnotationType.highlight` (varsayılan). Renk alfası yok sayılır
  (highlight çarpımsal harman, altındaki metni boyamaz).
- **ponytail:** annotate+save ana izlekte; büyük PDF'te takılırsa xlsx gibi `compute`'a
  taşınır (bkz. 2026-07-22 XLSX isolate).
- **Doğrulama:** yerel `flutter analyze` (yeni kodda 0 sorun; kalan uyarılar önceden
  var olan `withOpacity` CI-3.29 uyumu) + `flutter test` **208 yeşil**. GÖRSEL/cihaz
  doğrulaması KALANLAR'da (koordinat gerçekten oturuyor mu, reload, renkler). Push
  YAPILMADI (kullanıcı "pushla" demedi).
- **Telefona kuruldu (aynı gün):** yerel `flutter build apk --release` (112.5MB) +
  `adb install`. → **DÜZELTME (2026-07-23 önceki notu geçersiz kıldı):** telefonda
  o an CI RELEASE imzalı sürüm kuruluydu (sertifika SHA-256 `9eef6704…` — kalıcı
  keystore ile eşleşti), "yerel debug-imzalı sürüm var" notu bayatmış (muhtemelen
  aradan bir main→APK Release indirilip kurulmuş). Yerel derleme debug-imzalı
  (`build.gradle.kts` release→`signingConfigs.getByName("debug")`) → `INSTALL_
  FAILED_UPDATE_INCOMPATIBLE`. Kullanıcı kararı: release keystore'la yeniden
  imzalama (parola gerektirir) yerine **kaldır+kur** seçildi → `adb uninstall`
  (Gemini API anahtarı + son dosyalar listesi telefonda SİLİNDİ) → `adb install`
  başarılı. **Şu an telefonda debug-imzalı sürüm var.** Bir sonraki CI Release
  kurulmak istenirse yine bu imza çakışması yaşanır (kaldır+kur ya da
  `dosya-okuyucu-imza\release.jks` ile yeniden imzalama).
- **Ders (apksigner):** `%LOCALAPPDATA%\Android\Sdk\build-tools\37.0.0\apksigner.bat`
  JAVA_HOME ister; bu makinede JDK yok ama Android Studio'nun JBR'ı var:
  `C:\Program Files\Android\Android Studio\jbr`. İki APK'nın sertifikasını
  karşılaştırmak için: `apksigner verify --print-certs <apk>`.

## 2026-07-24 — Word sadakati %95 hedefi: WebView font ikamesi + Word sayfalama
Kullanıcı "Word içinde min %95 sadakat" istedi. Word görüntüleme docx-preview
0.3.7 (gömülü, `assets/word/`) ile yapılıyor; render'ın kendisi olgun ama iki
büyük sadakat kaybı vardı — düzeltildi (`assets/word/viewer.html`):

- **Kök neden (en büyük): WebView'da MS fontu yok.** Word belgeleri çoğunlukla
  Calibri/Times New Roman/Arial kullanır; Android WebView bunlara sahip değil →
  rastgele cihaz fontuna düşüyor, harf genişlikleri değişiyor → **satır ve sayfa
  kırılımı Word'den sapıyor** (sadakat kaybının asıl kaynağı, sadece "yazı farklı
  görünüyor" değil). Slaytta zaten gömülü olan metrik-uyumlu açık kaynak
  karşılıkları (Carlito≈Calibri, Tinos≈Times, Arimo≈Arial — harf genişlikleri
  birebir) **MS adlarıyla `@font-face`** olarak tanımlandı. Böylece docx-preview
  "Calibri" yazınca Carlito yükleniyor, metrikler Word'le aynı.
  - Font dosyaları `assets/fonts/`'ta (pubspec `fonts:`), viewer `assets/word/`'ten
    yüklendiği için `url('../fonts/X.ttf')`. **Neden çalışır:** `<script src="jszip
    .min.js">` zaten aynı yerel `file://` alt-kaynak mekanizmasıyla yükleniyor;
    CSS `url()` de alt-kaynak → `allowFileAccess` (varsayılan açık) kapsamında,
    `allowFileAccessFromFileURLs` (JS/XHR için, kapalı) ile İLGİSİZ. `../` Chromium'da
    normalize edilip flutter_assets içinde çözülür, dizin-dışına taşma yok.
  - `font-display:block`: doğru metrikle ölçülsün (yanlış fontla kısa çakma olmasın).
  - Arimo yalnız **değişken font** → `font-weight:100 900` aralığı; kalın wght ekseninden.
  - Ek: Calibri Light→Carlito (modern başlık), Cambria→Tinos (metrik-uyumsuz ama
    tam Türkçe kapsamlı tutarlı serif > rastgele cihaz serifi), `#container` son-çare
    fallback Carlito (fontsuz theme metni cihaz fontuna düşmesin).
- **Sayfalama Word'le hizalandı (`renderAsync` opsiyonları):**
  - `ignoreLastRenderedPageBreak: false` (eski varsayılan true) → Word'ün kaydederken
    yazdığı `w:lastRenderedPageBreak` konumları KULLANILIR, sayfa Word'le aynı yerde
    kırılır. (Word'ün hiç açmadığı üretilmiş belgede işaret yok → eski davranış, risksiz.)
  - `ignoreHeight: false` (eski true) → sayfa tam A4 yüksekliğinde (docx-preview
    `min-height` uygular, sabit height DEĞİL → içerik kırpılmaz; kısa belgede altta
    Word'deki gibi boşluk). fitPage genişlik ölçer, yükseklikten etkilenmez.
  - Başlık/altbilgi/dipnot/son-not render açık (zaten varsayılan, açıkça yazıldı).
- **Doğrulama:** `test/word_assets_test.dart`'a font testi eklendi — viewer.html'in
  `../fonts/`'la gösterdiği her `.ttf` gerçekten pakette mi (pubspec'ten biri düşerse
  derlemeden yakala). Flutter bu ortamda yok → CI test job + APK'da doğrulanacak.
- **KALAN (kullanıcı, cihaz):** gerçek Calibri/Times/Arial'lı .docx'te satır/sayfa
  kırılımı Word'le aynı mı; `../fonts/` file:// erişimi cihazda fontları yüklüyor mu
  (script'ler yükleniyor → beklenen evet ama görsel doğrulanmadı). → KALANLAR.md.

## 2026-07-24 — PPTX + PDF sadakat araştırması ve PPTX iyileştirmeleri
Kullanıcı Word'den sonra PPTX ve PDF sadakatini de otonom artırmayı istedi. İki
paralel araştırma ajanı render hatlarını taradı; bulgular ve yapılanlar:

### PPTX — 4 iyileştirme (parser deterministik, birim-testli, düşük risk)
`pptx_render.dart` + `slide_canvas.dart`:
- **`p:style` tema stil referansı (en büyük tekil kazanç):** Modern PPTX'te tema
  temelli şekiller dolgu/çizgiyi `spPr`'de DEĞİL, `p:style`'daki `a:fillRef`/`a:lnRef`
  (içinde schemeClr/srgbClr) taşır. Okunmadığı için bu şekiller **boş/şeffaf**
  çiziliyordu. `_shape`: spPr'de dolgu yoksa `fillRef`→dolgu, çizgi yoksa `lnRef`→
  stroke (idx="0"=tema bg, atla). lnRef kalınlığı tema lnStyleLst'te; çözmeden
  minör çizgi ~0.75pt varsayıldı.
- **Görsel `flipH`/`flipV`:** Eskiden flip yalnız `_LinePainter`'da uygulanıyordu;
  kutu/görseller aynalanmıyordu. `slide_canvas` görsel dalına merkez etrafında
  `Matrix4.diagonal3Values(±1,±1,1)` eklendi. **Metne UYGULANMAZ** (mirror yazı
  okunmaz olurdu) — yalnız görsel; ok/simge preset'leri zaten rect çiziliyor.
- **Mutlak satır aralığı `a:lnSpc>a:spcPts` + paragraf sonrası `a:spcAft`:** Eskiden
  yalnız `spcPct` okunuyordu, mutlak punto aralık varsayılan 1.2'ye düşüyordu.
  spcPts→çarpan (pt / font boyutu); spcAft→`ParaVM.spaceAfterPt`, Padding.bottom +
  `_fitScale` ölçümüne eklendi.
- **Tablo kenar-başına kenarlık:** Eskiden yalnız `lnB`/`lnT` okunup tüm kenara
  (`Border.all`) uygulanıyordu → tanımsız kenarlara da çizgi. `_table` artık
  L/R/T/B ayrı okuyup `ShapeVM.cellBorder` (Flutter `Border`) üretiyor; canvas
  `cellBorder ?? Border.all(stroke)`.
- **Test:** `pptx_render_test.dart`'a 3 test (p:style dolgu+çizgi, spcPts→2.0 çarpan
  + spcAft 6pt, tablo yalnız-tanımlı-kenar). A-E maddelerinin regresyon ağı yoktu.
- **ERTELENEN (araştırmada tespit, sonra):** `a:srcRect` görsel kırpma (canvas
  drawImageRect gerekir, orta risk), preset/custGeom (rect dışı hep kutu),
  glow/innerShdw/reflection efektleri, çok-seviyeli liste stilleri (lvl2-9),
  strike/superscript run özellikleri. → KALANLAR.

### PDF — araştırma bulguları (UI/koordinat kodu, cihaz doğrulaması gerekli → KALANLAR)
pdfium zaten yüksek raster sadakatli; kazançlar arama-tutarlılığı/deneyim/annotation:
- **Türkçe-duyarlı PDF arama (yüksek):** Metin editörü `turkishFold` (İ→i, I→ı)
  kullanıyor ama PDF yolu (`viewer_screen` `_pdfSearcher.startTextSearch caseInsensitive`)
  locale-duyarsız → "İstanbul/ışık" PDF'te güvenilmez eşleşir. Altyapı hazır
  (`findAll` + `selectionPdfRects`); kendi ince arayıcıya bağlanmalı.
- **Döndürülmüş sayfa (/Rotate≠0) vurgu geometrisi (yüksek):** `pdf_annotator`
  ham pdfium rect'ini yalnız Y-flip'liyor; ekran seçimi (`bounds.toRect` rotasyonu
  hesaba katıyor) doğru ama kaydedilen vurgu 90/180/270'te yanlış yere düşer.
  Rotasyon konvansiyonu Syncfusion'da belirsiz → **kör push YAPILMADI** (yanlış
  konvansiyonla eşleşen test = yanlış-güven; cihaz doğrulaması şart).
- **Gece modu invert (düşük risk, yüksek konfor):** `ColorFiltered` invert sarmalayıcı
  + AppBar toggle. Salt görsel.
- **Link/köprü tıklama:** `linkWidgetBuilder` (+ `url_launcher` bağımlılığı).
- **Belge ana hattı (outline/bookmarks):** `document.loadOutline()` + yan çekmece.
- **Vurgu remount zoom/kaydırma kaybı:** `_pdfReloadKey++` remount'ta zoom sıfırlanır.
- **Karar:** PDF kazançları çoğunlukla UI/koordinat → reponun "kör push yok" ilkesi
  gereği cihaz doğrulaması ister; net plan KALANLAR'a yazıldı, blind push yok.

## 2026-07-24 — "Birlikte aç" kirliliği, çeviri, resim→PDF veri kaybı
Kullanıcı 5 madde sıraladı (apk'da çıkma, çeviri, AI butonu, resim→PDF, premium).

### TUZAK/BUG KÖKÜ: resim→PDF'te görsel tamamen kayboluyordu
`viewer_screen._exportPdf` dosya türüne bakmadan `textToPdf(doc.plainText)`
çağırıyordu. Görselin `plainText`'i BOŞ → üretilen PDF'te yalnızca **"(Boş belge)"**
yazıyor, resim hiç gömülmüyordu. Kullanıcının "veri kaçıyor" şikayeti buydu.
- **Düzeltme:** `ConversionService.imageToPdf` — sayfa oranı = resim oranı (kırpma
  ve kenar boşluğu yok), piksel verisi kayıpsız (JPEG DCTDecode ile aynen, PNG
  kayıpsız yeniden kodlanır), yeniden ölçekleme YOK. `_exportPdf` başında
  `DocKind.image` dalı.
- **Aranabilir PDF:** `OcrService.recognizeImageLines` (yeni) satır + piksel kutusu
  döndürür; her satır kendi yerine hem şeffaf renkle hem resmin ALTINDA çizilir
  (iki kat güvence — alpha'ya tek başına güvenilmedi).
- **Tuzak:** `pw.MemoryImage.width/height` **nullable** — HEIC/HEIF çözülemez ve
  null döner. Sessiz bozuk PDF yerine `FormatException` atılıyor.
- **Tuzak:** görünmez katman Türkçe içerebilir → varsayılan Helvetica ğ/ş/ı çizemez
  ve pdf paketi hata atar. Gömülü `assets/fonts/Carlito-Regular.ttf` yükleniyor.

### "Birlikte aç"ta her dosyada çıkma (madde 1)
Kök neden `ci/AndroidManifest.xml`: VIEW ve SEND filtreleri `mimeType="*/*"` idi →
Android'e "her dosyayı açarım" deniyordu (.apk/.zip/video dahil). Desteklenen
gerçek MIME listesiyle değiştirildi (pdf, OOXML, legacy office, text/\*, image/\*).
- **Bilinçli RİSK:** `application/octet-stream` listeye ALINMADI. Bazı dosya
  yöneticileri/WhatsApp dosyayı bu tiple gönderebilir → o durumda listede
  çıkmayız. Kullanıcı şikayet ederse ekle, ama .apk sorunu geri gelir (Android'de
  negatif MIME filtresi yok — ya hep ya hiç).
- Yeni biçim desteği eklenirse (`FileService.kindForExtension`) manifest'e de eklenmeli.

### Çeviri = cihaz-içi ML Kit (Gemini DEĞİL — kullanıcı seçimi)
- **Sürüm kilidi:** `google_mlkit_translation: 0.13.1` SABİT. Gerekçe: text_recognition
  0.15.0 ile aynı `google_mlkit_commons 0.11.1`'i kullanır; 0.14.0+ commons 0.12 +
  Dart >=3.8 ister → CI Flutter 3.29.3 (Dart 3.7) kırılır. (Aynı tuzak text_recognition'da.)
- `TranslateService`: satır yapısı korunarak çevirir (boş satır = paragraf); uzun
  satır cümle sonundan bölünür — tek ML Kit çağrısı uzun metinde sessizce kırpabiliyor.
- Dil modeli ilk kullanımda indirilir (internet), sonrası çevrimdışı.
- Seçili metin çevirisi yalnız PDF'te (seçim altyapısı orada). Word/Excel/Slayt'ta
  "Belgeyi çevir" var — WebView tabanlı Word'de Flutter'a seçim gelmiyor.

### AI FAB (madde 3)
5 ekranda `FloatingActionButton.extended` (geniş etiket) belgenin sağ alt köşesini
kapatıyordu → dairesel FAB + tooltip. Ortak `AiFab` widget'ı YAPILMADI (ponytail:
5 küçük edit, tek satırlık soyutlama kazancı yok).

### Premium görsel yenileme (madde 5)
Kullanıcı "tüm uygulama" kapsamını seçti. En yüksek kaldıraç `core/theme.dart`:
tek dosya değişikliği tüm ekranlara yansıyor (kart, liste, giriş alanı, dialog,
bottom sheet, snackbar, ayraç, buton, FAB temaları + tipografi ölçeği).
- **Token'lar eklendi:** `Gap` (4/8dp ritmi) ve `Radii` (control 12 / card 16 /
  sheet 28). Ekranlara serbest sayı yazmak yerine buradan alınır.
- **Görsel dil:** gölge yığını yerine yüzey tonu (`surfaceContainerLow`) + saç
  teli `outlineVariant` kenarlık — koyu temada kenar kaybolmuyor.
- **TUTARSIZLIK BULGUSU (düzeltildi):** `widgets/file_type_icon.dart` marka
  renklerini KENDİ hex setiyle tanımlıyordu (PDF #E53935, Word #1E88E5, Excel
  #43A047, Slides #FB8C00) — `OfficeColors`'taki üst şerit renklerinden (#C50F1F,
  #185ABD, #107C41, #C43E1C) farklıydı. Aynı dosya listede ve şeritte iki ayrı
  tonla görünüyordu. Artık ikon Office dördü için `OfficeColors`'tan besleniyor;
  text/image/unknown listede ayrışsın diye kendi tonlarını korudu (şeritte hepsi
  tek `neutral`).
- **REDDEDİLEN (ui-ux-pro-max skill çıktısı):** önerilen teal/turuncu palet
  (#0D9488) mevcut Office kimliğini bozardı; Playfair Display serif bir ofis
  uygulamasına yanlış ve Google Fonts internet ister (uygulama çevrimdışı, APK'da
  zaten Carlito/Tinos/Arimo BELGE fontu olarak var — UI fontu değil); GSAP web
  kütüphanesi, Flutter'da karşılığı yok. Skill'den yalnız katmanlı yüzey, press
  geri bildirimi, kontrast/dokunma hedefi kuralları alındı.
- **Sayfa geçişi:** `CupertinoPageTransitionsBuilder` const map'te çözülmedi
  (`invalid_constant`); zaten Android'de yabancı duracaktı → Flutter'ın M3
  varsayılanı (ZoomPageTransitions) bırakıldı.

## 2026-07-25 — Uygulama artık aynı zamanda TAM DOSYA YÖNETİCİSİ
Kullanıcı isteği: "uygulamayı basit ama her işi gören, modern, pratik bir dosya
yöneticisi haline getir" (referans ekran görüntüsü: alphainventor File Manager+
panosu — depolama, kategoriler, geri dönüşüm kutusu). Git/web araştırması:
Fossify File Manager (Files/Recent/Storage sekmeleri, medya oynatıcı, çöp),
Material Files (MD3, yer imleri, arşiv). Bizim panomuz bu kalıbı izliyor.

### Mimari (yeni dosyalar)
- `models/fs_entry.dart` — saf Dart girdi modeli + `FmCategory` (klasör/görsel/
  video/ses/belge/arşiv/apk/diğer) + uzantı tabloları + `FmSort`.
- `services/fm/fs_scan.dart` — listeleme, **Türkçe-duyarlı sıralama**, özyinelemeli
  arama, klasör boyutu ve **tek geçişli `StorageIndex`** (kategori sayı/boyut,
  kategori başına en yeni N, en büyük N, son değişen N). Ağır işler `compute`
  isolate'inde; isolate yoksa ana izleğe düşer (XLSX dersi, HAFIZA 2026-07-22).
- `services/fm/file_ops.dart` — kopyala/taşı/sil/yeniden adlandır/oluştur,
  çakışma politikası (varsayılan **rename**, veri ezilmez), ilerleme + iptal.
- `services/fm/trash_service.dart` — geri dönüşüm kutusu.
- `services/fm/archive_ops.dart` — zip/çıkar (mevcut `archive` paketi; YENİ
  bağımlılık yok). RAR/7z bilinçli kapsam dışı → "başka uygulamayla aç".
- `services/fm/storage_stats.dart` — birimler + doluluk.
- `services/fm/storage_permission.dart`, `services/fm/fm_env.dart` (ortam/çöp
  tekil kurulumu), `services/fm/entry_opener.dart` (tek açma kapısı).
- Ekranlar: `screens/fm/` → dashboard, browser, category, search, trash, analysis
  + `entry_actions.dart` (ortak işlem sayfası). Widget: `widgets/fm/`.
- `home_screen.dart` artık **kabuk**: alt gezinme (Dosyalar / Son belgeler / AI).
  Paylaşım (birlikte aç) yakalama kabuğa taşındı → hangi sekme açıksa çalışır.

### Kararlar ve *niye*leri
- **Çöp kutusu uygulama verisinde DEĞİL, dosyanın kendi biriminde**
  (`<birim>/.dosya-okuyucu-cop/`, `.nomedia` ile galeriden gizli). `/data` ile
  `/storage` ayrı bağlama noktası → aradaki `rename` başarısız olur ve 2 GB'lık
  video çöpe atılırken KOPYALANIRDI. Aynı birimde silme/geri yükleme anında.
  Kayıtlar `index.json`; diskten elle silinmiş kayıt listeden düşer.
- **Depolama doluluğu `df` ile okunuyor, yeni eklenti EKLENMEDİ.** Dart'ta
  `statfs` yok; `disk_space*` paketleri bakımsız ve platform kanalı eklemek
  CI'da `flutter create` ile üretilen android/ iskeletini kırılganlaştırırdı.
  `StorageStats.parseDf` saf fonksiyon → birim testli; okunamazsa doluluk
  çubuğu gizlenir (zarif düşüş), dosya yöneticisi çalışmaya devam eder.
- **Tek geçişli tarama:** pano, kategori ekranları, "en büyük dosyalar" ve
  "yeni dosyalar" AYNI `StorageIndex`ten beslenir; her kutu kendi taramasını
  yapsa 100 bin dosya defalarca gezilirdi. Sonuç süreç boyunca önbellekli
  (aşağı çekince yenilenir). Bellek `_TopN` ile sınırlı (liste 2N'e ulaşınca
  sıralanıp N'e düşer) — 200 bin dosyalı telefonda isolate şişmesin.
- **Türkçe sıralama tuzağı:** Dart `compareTo` kod birimine bakar, `ı` (U+0131)
  `z`'den büyüktür → "Işık" listenin en sonuna düşüyordu. `FsScan.nameKey`
  Türkçe harfleri temel karşılığına indirger (ı→i, ş→s, ğ→g, ü→u, ö→o, ç→c).
- **İzin: MANAGE_EXTERNAL_STORAGE.** Android 11+'da bir dosya yöneticisinin
  başka yolu yok (READ yalnız medya; SAF her klasörü tek tek seçtirir). Play
  Store gerekçe ister ama dağıtım GitHub Releases → engel yok. İzin verilmezse
  uygulama kilitlenmez: pano bir "İzin ver" kartı gösterir, medya izinleri
  yedek yol olarak istenir.
- **Yeni bağımlılıklar (yalnız 2):** `permission_handler: 11.3.1` (SABİT — 11.4/12.x
  alt paketi compileSdk'yı yukarı çeker) ve `open_filex: ^4.7.0` (video/ses/apk/
  arşiv sisteme devredilir; kendi FileProvider'ını getirir). Manifest'e Android 11
  **paket görünürlüğü** sorgusu (`<queries>` ACTION_VIEW `*/*`) eklendi — yoksa
  open_filex "uygulama yok" der.
- **Video/ses oynatıcı EKLENMEDİ (bilinçli):** `video_player` 2.10.x'in alt paketi
  `video_player_android` 2.9+ Flutter >=3.35 istiyor; pub geriye düşse bile CI
  3.29.3'te kırılgan bir çözümleme olurdu (HAFIZA'daki sürüm cehennemi dersi).
  Medya sistemin oynatıcısında açılır. → KALANLAR.
- **Gözatıcı push tabanlı gezinir** (her alt klasör yeni sayfa) → Android geri
  tuşu doğal olarak üst klasöre çıkar, kaydırma konumu korunur.
- `viewer_screen`'deki "Başka uygulamayla aç" gerçekten sistemin uygulamasını
  açıyor (eskiden paylaş sayfasını açıyordu); paylaş ayrı düğme oldu.

### Doğrulama
Bu Linux bulut oturumunda Flutter YOK → doğrulama CI `flutter test`. Yeni testler:
`fm_file_ops_test` (çakışma/özyineleme/kendi içine taşıma), `fm_scan_test`
(kategori, Türkçe sıralama, arama, indeks, klasör boyutu), `fm_trash_test`
(sil→geri yükle→kalıcı sil, ad çakışması), `fm_storage_archive_test`
(`df` çözümleme uçları + zip→extract turu). Cihaz doğrulaması (izin akışı,
gerçek /storage taraması, harici açma) → KALANLAR.

### Doğrulama sonucu (aynı gün)
CI run #90 test ✅, #91 **APK ✅** (`v0.1.0-build-91`, imzalı, 190,5 MB — bir
önceki main sürümü #89 zaten 188,9 MB'dı, dosya yöneticisinin maliyeti ~1,6 MB),
#92 test ✅. **Ders/önlem:** CI'ın ucuz `test` işi yalnız testlerden ERİŞİLEN
dosyaları derler; ekranlar hiçbir testten import edilmediği için bir ekran
derleme hatası ancak ~20 dk'lık APK işinde görünürdü → `test/fm_screens_smoke_test.dart`
ekranları import edip kurucularını çağırıyor (pump ETMEZ; eklentiler test
ortamında yok), böylece hata hızlı koşuda yakalanıyor.

## 2026-07-25 — RAR/7z TAM desteği (kullanıcı: "rar kısmı da detaylı olsun")
İlk turda RAR/7z bilinçli kapsam dışıydı ("saf Dart çözücü yok" varsayımı).
Araştırma bu varsayımı ÇÜRÜTTÜ: `koni_archive` 0.9.0 (2026-07-18, MIT) **saf
Dart** clean-room RAR4/RAR5 + 7z okuyucusu.

- **Karar — okuma motoru `koni_archive`, sıkıştırma yine `archive`.**
  *Niye bu paket:* (a) saf Dart → platform kodu yok, CI'da `flutter create` ile
  üretilen `android/` iskeletine dokunmuyor (junrar saran eklentiler Kotlin
  kodu + Gradle bağımlılığı isterdi ve yalnız RAR4 çözerdi); (b) RAR5'i de
  kapsıyor (solid, PPMd, delta/x86 filtreleri, şifreli dosya + şifreli başlık,
  çok parçalı); (c) `sdk ^3.7.0` → CI Flutter 3.29.3 = Dart 3.7.2 ile tam
  uyumlu; ek bağımlılığı yok (glob/path/web). *Risk:* paket bir haftalık,
  0 beğeni → hatalarında uygulama çökmesin diye tüm çağrılar tiplenmiş
  `ArchiveError`'a çevriliyor ve arayüz "başka uygulamayla aç"a düşebiliyor.
  Gerçek RAR/7z fixture'larıyla CI'da test ediliyor.
- **Çıkarma `Isolate.run` içinde.** LZMA/PPMd saf Dart'ta CPU-yoğun; ana
  izlekte 100 MB'lık bir arşiv uygulamayı dondururdu (XLSX dersinin aynısı).
  İlerleme isolate'ten `SendPort` ile bildiriliyor. **İptal YOK** (Isolate.run
  öldürülemez) → ilerleme penceresi bu işte `cancellable: false`.
- **Fixture tuzağı:** RAR sıkıştırıcısı özel mülk; bu sandbox'ta ve CI'da
  `.rar` ÜRETİLEMEZ (`rar` ikilisi yok, açık kaynak yazıcı yok). Bu yüzden
  koni_archive'ın MIT fixture'larından 4 tanesi (RAR5 normal, RAR4 solid,
  şifreli RAR5, 7z LZMA2) `test/fixtures/archive/`'a kopyalandı; kaynak ve
  gerekçe `KAYNAK.md`'de. **RAR YAZMA kalıcı olarak kapsam dışı** — biçimin
  sıkıştırıcısı açık değil; kullanıcıya .zip üretiliyor.
- **Yeni ekran `screens/fm/archive_screen.dart`:** arşivi ÇIKARMADAN listeler
  (biçim, dosya sayısı, toplam boyut, sıkıştırma oranı, şifreli/çok parçalı
  rozeti), içinde arama, tek dosyayı önizleme (geçici klasöre çıkarıp
  görüntüleyicide açar), tek dosya çıkarma, "Tümünü çıkar".
- **Parola akışı** ortak `widgets/fm/archive_password_dialog.dart`: şifreli
  arşivde sorar, yanlışsa tekrar sorar (koni `InvalidPasswordException` →
  `ArchiveFailure.wrongPassword`). RAR5 dosya-şifreli arşivlerde LİSTELEME
  parolasız çalışır (başlık açık), hata ancak okumada gelir — akış buna göre.
- **Çok parçalı setler:** `ArchiveOps.volumePath` saf fonksiyonu cilt adını
  üretir (`ad.part2.rar` / `ad.r00` / `ad.7z.002` / `ad.z01`), koni'nin
  `nextVolume` geri çağrısına bağlanır. Açılan cilt kaynaklarını koni
  KAPATMAZ (belgelenmiş) → biz listede tutup `finally`de kapatıyoruz.
- Zip-slip'e karşı iki kat koruma: koni yolları normalleştirip `pathEscapedRoot`
  bayrağı koyuyor, biz ayrıca `FsPaths.isInside` ile hedef dışına düşeni atlıyoruz.

## 2026-07-25 — Uygulama içi video/ses oynatıcı + kaydırmalı görsel galerisi
Kullanıcı üç madde istedi: (1) video oynatıcı, (2) görsellerde sağa/sola
kaydırarak ileri-geri, (3) araştırmaları tam analiz edip geliştirmeye devam.

- **ERTELEME GERİ ALINDI — `video_player` EKLENDİ.** Aynı gün önce "CI Flutter
  3.29.3'te çözümleme kırılgan" diye ertelemiştim; pub.dev sürüm zincirini
  gerçekten tarayınca çıkan sonuç: **`video_player_android` 2.8.15**, `sdk ^3.7.0
  + flutter >=3.29.0` ile Flutter 3.29 uyumlu SON sürüm (2.8.16'dan itibaren
  flutter >=3.35). `video_player: 2.10.1` de flutter >=3.29 istiyor. İkisi de
  pubspec'te SABİT — `pubspec.lock` gitignore'da olduğu için CI her koşuda
  yeniden çözümlüyor, alt paket pinlenmezse pub yeni (uyumsuz) sürümü seçer.
  *Ders:* "sürüm cehennemi" korkusuyla özellik ertelemeden önce zinciri
  pub.dev API'sinden TARA — tek bir uyumlu sürüm çoğu zaman vardır.
- **`screens/fm/media_player_screen.dart`** video VE sesi tek ekranda oynatır
  (ses dosyasında görüntü katmanı yok → kapak alanı). Çalma listesi = aynı
  klasördeki medya dosyaları; sağa/sola kaydırma ve ileri/geri düğmeleriyle
  geçiş, dosya bitince sıradakine otomatik geçer. 10 sn ileri/geri, hız
  (0.5–2x), tam ekran (yatay kilit + immersive), 3 sn sonra kontrollerin
  gizlenmesi. Codec cihazdan gelir; açamazsa "Başka uygulamayla aç"a düşer.
- **`screens/fm/image_gallery_screen.dart`**: PageView ile kaydırmalı galeri,
  sayfa başına yakınlaştırma; **yakınlaştırılmışken sayfa geçişi kilitlenir**
  (`NeverScrollableScrollPhysics`) — slayt listesindeki zoom/kaydırma çekişmesi
  dersinin aynısı. OCR/çeviri/PDF gibi ağır işlevler tek-görsel
  `ViewerScreen`'de KALDI; galeri ⋮ menüsünden oraya geçilir (ViewerScreen'i
  çok-sayfalıya çevirmek 40 yerde `widget.doc` refactor'ü demekti — risk/
  kazanç oranı kötü).
- **Yönlendirme tek yerde: `EntryOpener.routeFor`** (saf fonksiyon, testli) →
  gallery / player / document / external. `siblingsFor` aynı türdeki kardeş
  dosyaları toplar; gözatıcı, kategori ekranı ve arama sonuçları listelerini
  geçirir. Manifest'e `video/*` + `audio/*` VIEW/SEND filtreleri eklendi
  (artık gerçekten oynatabiliyoruz; `*/*` hâlâ yok — apk/zip kirliliği).
- **TUZAK (CI run #93) — `Isolate.run` özel istisna tipini KAYBEDEBİLİYOR:**
  arşiv çıkarmada isolate içinde atılan `ArchiveError` karşı tarafa
  `ArchiveFailure.other` olarak ulaştı (şifreli RAR testi kırmızı). Çözüm:
  isolate artık istisna fırlatmıyor; sonucu/hatayı **sade** `['ok', değer]` /
  `['err', failureIndex, mesaj]` listesiyle döndürüyor, çağıran yeniden kuruyor
  (`_guard`/`_unwrap`). Kural: isolate sınırından yalnız ilkel tipler geçir.
- **Ekran duman testi kendini ödedi:** `archive_screen.dart`'ta eksik
  `file_ops.dart` importunu (FmProgress) hızlı test koşusu yakaladı — eskiden
  bu hata ancak ~20 dk'lık APK derlemesinde görünürdü.

### Yinelenen dosya bulucu (araştırma listesinden kalan madde)
Fossify/Material Files karşılaştırmasında bizde olmayan ve en çok işe yarayan
madde "yer açma" idi → `services/fm/duplicate_finder.dart`: üç aşamalı
(boyut grubu → baş/son 64 KB FNV-1a parmak izi → **bayt bayt** doğrulama).
*Niye üç aşama:* yalnız hash'e güvenip kullanıcının dosyasını sildirmek kabul
edilemez; boyut grubu sayesinde çoğu dosya hiç okunmaz. `Isolate.run` içinde.
Ekran: Bellek Analizi → "Yinelenen dosyaları bul"; her grupta **en eski dosya
korunur**, kalanlar seçili gelir, tek dokunuşla çöpe. `crypto` bağımlılığı
EKLENMEDİ (FNV-1a saf Dart, 20 satır).

### TUZAK (CI #94) — `Isolate.run` + akış hatası = RemoteError
İlk düzeltme (sonucu sade listeyle döndürmek) yetmedi: `IOSink.addStream`
kullanılınca akış hatası hem dönen future'a hem sink'in `done` future'ına
düşüyor, biri SAHİPSİZ kalıp isolate'i düşürüyor → `Isolate.run` hatayı
`RemoteError`'a çeviriyor, tip bilgisi yine kayboluyordu. Kesin çözüm iki
katmanlı: (1) `addStream` yerine `await for` + `sink.add` (hata tek yerden),
(2) `_guard` gövdesi `runZonedGuarded` içinde — sahipsiz async hata da
sonuca çevriliyor. **Kural:** isolate içinde akış tüketirken `addStream`
kullanma; ve isolate gövdesini daima zone ile koru.

### Şifreli arşiv ÜRETME (araştırma listesindeki "dosya şifreleme" karşılığı)
`koni_archive` yalnız okumuyor, **yazıyor** da: ZIP → WinZip AES-256, 7z →
AES-256-CBC + isteğe bağlı **şifreli başlık** (dosya adları da gizlenir).
Fossify'ın "file encryption" özelliğinin bizdeki karşılığı bu oldu ve okuma
tarafı zaten hazırdı → tur kapandı (üret → geri aç, testli).
- `ArchiveOps.compress(paths, destDir, {format, password, hideNames})`.
  **Parolasız düz .zip eski hızlı yolda (ZipFileEncoder) KALDI** — kanıtlanmış
  ve hızlı; koni yolu yalnız parola ya da 7z istenince devreye girer.
- Sıkıştırma da isolate'te (saf Dart LZMA/AES CPU-yoğun).
- UI: `widgets/fm/compress_sheet.dart` — biçim seçimi + "Parola koy" + 7z'de
  "Dosya adlarını da gizle" + "parolayı unutursan açılamaz" uyarısı.
  *Niye 7z seçeneği:* parolalı ZIP'te dosya ADLARI dizinde açık kalır; gerçek
  gizlilik için 7z + şifreli başlık gerekir (kullanıcıya açıkça yazıldı).
- **RAR üretimi yok ve olmayacak** (biçim özel mülk) — okuma tam.

### TUZAK — boş commit CI'ı TETİKLEMEZ
`[release-apk]` işaretli **boş** commit (`--allow-empty`) hiçbir koşu başlatmadı:
workflow'un `paths-ignore: '**.md'` filtresi, değişen dosyası olmayan push'u da
eliyor. APK istendiğinde ya gerçek bir kod değişikliğiyle ya da `ci/build-trigger.txt`
güncellenerek push edilmeli (dosya zaten bu amaçla duruyor).

## 2026-07-25 — Müzik çalar (ayrı ses motoru)
Kullanıcı "ses oynatma özelliği de lazım" dedi. Ses zaten `video_player` ile
çalıyordu ama **ekrandan çıkınca duruyordu** ve çalar işlevleri yoktu.
- **Karar: ses için AYRI motor — `audioplayers 6.6.0` (+ `audioplayers_android
  5.2.1` pinli, Flutter 3.29 uyumlu son sürümler).** `video_player` görüntü
  yüzeyine bağlı; audioplayers native çalıcıyı doğrudan sürer → ekran kapansa
  da çalar ve manifest'e servis/etkinlik eklemek GEREKMEZ.
- **REDDEDİLEN yol: `just_audio` + `just_audio_background`.** Bildirim/kilit
  ekranı kontrolleri verirdi ama manifest'te `<activity>`nin sınıfını
  `com.ryanheise.audioservice.AudioServiceActivity` yapmayı şart koşuyor;
  sınıf bulunmazsa uygulama AÇILMAZ (kullanıcının telefonunda en kötü hata
  sınıfı). Yerelde Flutter olmadığı için doğrulanamazdı → risk alınmadı.
  Bildirim kontrolleri istenirse ayrı bir turda, APK'da sınıf doğrulaması
  yapan bir CI adımıyla eklenmeli (KALANLAR).
- `screens/fm/audio_player_screen.dart`: çalma listesi (klasördeki sesler),
  tekrar (kapalı/bu parça/tümü), karışık, hız, 10 sn ileri-geri, kaydırarak
  parça değiştirme, sıradakiler listesi.
- `EntryOpener.routeFor` artık **ses ve videoyu ayırıyor** (`OpenRoute.audio`
  vs `player`) → çalma listeleri de ayrı (video listesi müziğe karışmaz).

## 2026-07-25 — Video küçük resmi, medya kaynağı filtresi, yüklü uygulamalar
Kullanıcı 4 madde istedi (ekran görüntüsü: "Videolar" ızgarasında hep aynı
film ikonu görünüyordu).

- **Video küçük resmi** — `fc_native_video_thumbnail 2.2.0` (native
  MediaMetadataRetriever). **TUZAK:** yaygın olan `video_thumbnail` paketi
  `sdk >=2.16.0 <3.0.0`da kalmış → Dart 3 ile KULLANILAMIYOR; bu paket
  `sdk >=2.18.6 <4.0.0 + flutter >=3.7` (3.0.0 sürümü flutter >=3.44 ister,
  o yüzden 2.2.0'a pinli).
  `services/fm/thumbnail_cache.dart`: küçük resim **diske** önbelleklenir,
  anahtar = yol + değişiklik zamanı + boy (dosya değişirse kendiliğinden
  tazelenir), paralel istekler tek işe indirgenir, üretilemeyen dosyalar
  kara listeye alınır (kaydırmada tekrar tekrar denenmesin), önbellek 600
  dosyada budanır. Widget üretilene kadar ikon gösterir (boş kutu YOK).
- **Medya kaynağı sınıflandırma** (`models/media_bucket.dart`, saf Dart):
  yola bakarak Kamera / Ekran görüntüsü / WhatsApp / Telegram / Instagram /
  İndirilenler / Bluetooth / Diğer. **Sıra önemli:** ekran görüntüsü DCIM
  altında da olabilir → kameradan ÖNCE bakılır. Android 11+ düzeni
  (`Android/media/com.whatsapp/...`) paket adıyla da eşleşir. Görsel ve video
  kategori ekranlarında sayı rozetli filtre çipleri.
- **Yüklü uygulamalar ekranı** — `installed_apps 2.1.1` (ad/ikon/sürüm/kurulum
  tarihi) + `usage_stats 1.3.1` (son açılma). Son kullanım Android'in ÖZEL
  "Kullanım erişimi" iznini ister (ayar sayfası açılır, normal izin penceresi
  değil) → izin yoksa liste yine gelir, yalnız tarih bilinmez ve renklendirme
  kapanır. Renk eşikleri `idleLevelFor` (saf, testli): <7g yeşil, <30g sarı,
  <90g turuncu, ≥90g / hiç açılmamış kırmızı. Uzun basış: aç / uygulama
  bilgisi / kaldır. Manifest'e `PACKAGE_USAGE_STATS` (+ `xmlns:tools` ile
  `tools:ignore="ProtectedPermissions"`); QUERY_ALL_PACKAGES ve
  REQUEST_DELETE_PACKAGES eklentinin kendi manifest'inden birleşiyor.
- **APK dosyaları ayrı kutu:** pano "Uygulamalar" kutusu artık YÜKLÜ
  uygulamaları açıyor; kurulum dosyaları "APK dosyaları" kutusunda.

## 2026-07-25 — KULLANICI HATASI: silinen dosya listelerde/sayılarda duruyordu
Belirti: bir dosya silindikten sonra panoya dönünce klasör/kategori sayısı
düşmüyor, içine girince dosya hâlâ görünüyor, üstelik çöp kutusunda da var.

- **KÖK NEDEN:** çöp klasörü (`<birim>/.dosya-okuyucu-cop/`) **tarama dışı
  bırakılmamıştı**. Dosya oraya taşınıyor ama `FsScan` tüm ağacı gezerken
  çöpteki kopyayı da sayıyordu → kategori sayıları aynı kalıyor, "Videolar/
  Görüntüler" listelerinde dosya duruyor, arama onu buluyor, yinelenen bulucu
  onu asıl dosyanın KOPYASI sanıyordu. Yani dosya gerçekten silinmişti; yanlış
  olan taramaydı. Çözüm: `FsScan.skipDirNames`'e `.dosya-okuyucu-cop`.
  Regresyon testi: `fm_trash_test` → "çöpe atılan dosya TARAMADA görünmez".
- **İKİNCİ KUSUR:** pano taraması süreç boyunca önbellekliydi ve hiçbir dosya
  işlemi onu geçersiz kılmıyordu → kopyalama/taşıma/silme sonrası sayılar
  bayat kalıyordu. Çözüm: `services/fm/fs_events.dart` (ValueNotifier sayacı);
  FileOps / TrashService / ArchiveOps her başarılı işlemde `FsEvents.changed()`
  çağırır. Pano yalnız **görünürken** yeniden tarar (`DashboardScreen.active`,
  kabuktan `_tab == 0` geçilir) — arka planda gereksiz tarama yok. Kategori
  ekranı da sinyalde diskte olmayanları listeden düşürür.
- **ÜÇÜNCÜ (önlem):** `TrashService.moveToTrash` artık taşımadan sonra kaynağın
  gerçekten gittiğini DOĞRULAR; kaynak yerinde kaldıysa çöpteki kopyayı siler
  ve hata döner — "hem klasörde hem çöpte" durumu artık imkânsız.

### TUZAK — video küçük resmi eklentisi minSdk'yı yükseltti
`fc_native_video_thumbnail` minSdk **24** ister; uygulama 23'teydi (Firebase
gerekçesiyle) → APK derlemesi `processReleaseMainManifest`te "minSdkVersion 23
cannot be smaller than version 24" ile kırıldı (CI #102). Dart testleri geçtiği
için hata ancak APK adımında göründü. CI patch'i minSdk 24'e alındı (Android 7+;
Android 6 payı ihmal edilebilir, Firebase'in 23'ü de kapsanıyor).

## 2026-07-25 — Dosya yöneticisine özel ayarlar + yaş odaklı İndirilenler
Kullanıcı: "ayarlar simgesi dosya yöneticisi kısmında da olmalı ve ona özel
ayarlar içermeli" + "indirilenlerde son kullanım tarihi olsun, gereksizleri
rahat silmek için".

- **`screens/fm/fm_settings_screen.dart`** — pano AppBar'ına ayar simgesi.
  Bölümler: Görünüm (ızgara, gizli dosyalar, küçük resimler aç/kapa,
  varsayılan sıralama), Silme (çöp kutusunu kullan / silmeden önce sor /
  çöp kutusunu otomatik temizle 7-30-90 gün / şimdi boşalt), İzinler (tüm
  dosyalara erişim + kullanım erişimi durum ve tek dokunuşla verme), Bakım
  (küçük resim önbelleğini temizle, birimleri yenile), Uygulama (genel
  ayarlara kısayol: Gemini/tema/hesap). Tercihler `AppState`te kalıcı:
  `fmThumbnails`, `fmUseTrash`, `fmConfirmDelete`, `fmTrashAutoDays`.
  `deleteEntries` artık bu tercihlere uyuyor (çöp kapalıysa KALICI silme —
  bu durumda onay her zaman sorulur, tercih kapalı olsa bile).
- **`screens/fm/downloads_screen.dart`** — "İndirilenler" kutusu artık klasör
  gezgini yerine **yaş odaklı** listeyi açıyor: her satırda indirilme tarihi,
  (varsa) son açılma ve renkli yaş rozeti; üstte "N dosya 6 aydır
  dokunulmamış · X GB" özeti + **"Eskileri seç"** ile tek dokunuşta toplu
  seçim → sil. Sıralama: en eski / en yeni / en büyük / ad.
- **TUZAK — atime güvenilmez:** Android'de çoğu bağlama `relatime`/`noatime`
  kullanır; erişim zamanı yazma zamanından büyük DEĞİLSE "son açılma"
  gösterilmez (`FsEntry.hasAccessInfo`) — uydurma bilgi vermektense
  göstermemeyi seçtik. Yaş rozeti bu yüzden `lastTouchedMs`
  (atime anlamlıysa o, değilse mtime) üzerinden hesaplanır.
- `models/file_age.dart` (saf, testli): `ageLevelFor`, `daysBetween`,
  `relativeDays`. `TrashService.purgeOlderThan` otomatik temizleme için.

### TUZAK — eklenti compileSdk'sı APK'yı kırar: `usage_stats` → `app_usage`
`usage_stats 1.3.1` **compileSdkVersion 30** ile yayınlanmış; modern AndroidX
kaynakları API 31 özniteliği (`android:attr/lStar`) istediği için
`:usage_stats:verifyReleaseResources` adımında "Android resource linking failed"
ile APK derlemesi kırıldı (CI #103). Dart testleri geçtiği için hata yalnız APK
işinde görünür.
**Karar:** paket değiştirildi → `app_usage 4.0.1` (compileSdk **35**, namespace
tanımlı). Yan fayda: izin sayfasını (Settings.ACTION_USAGE_ACCESS_SETTINGS)
kendisi açıyor. Yan maliyet: "izin var mı" sorgusu YOK — izinsiz sorgu ayar
sayfasını açtığı için izin durumu SharedPreferences bayrağıyla tutuluyor
(`fm_usage_access_granted`); ekran açılışında sorgu yalnız bayrak açıkken
yapılır, yoksa kullanıcı "İzin ver"e basana kadar ayar sayfası fırlamaz.
**Ders:** bir Android eklentisi eklerken pub sürüm kısıtlarına bakmak YETMEZ;
`android/build.gradle`ındaki `compileSdk`/`namespace` da bakılmalı (eski
değerler AGP 8'de derlemeyi keser).

## 2026-07-25 — Dosya seçiminde toplu/sürükleyerek seçim + Excel sadakati %100 turu

### A) Basılı tutup kaydırarak çoklu seçim (`widgets/fm/drag_select.dart`)
- **Karar:** hazır paket (drag_select_grid_view) KULLANILMADI — yalnız GridView'ı
  sarıyor ve seçim durumunu kendi tutuyor; bizde seçim ekranların `Set<String>`inde
  ve hem liste hem ızgara var. `DragSelectArea` durum TUTMAZ, yalnız
  "şu aralığa seç/kaldır uygula" geri çağrısı verir.
- **Parmağın altındaki öğe `MetaData` + hit-test ile bulunur** (`DragSelectItem`
  her öğeyi indeksiyle işaretler; `RenderMetaData` hit-test yoluna eklendiği için
  GlobalKey/ölçüm gerekmez, O(1)).
- **TUZAK (jest arenası):** öğelerin kendi `onLongPress`i KALIRSA çocuk arenayı
  kazanır ve sürükleme hiç başlamaz. Bu yüzden tile'lardan `onLongPress`
  kaldırıldı, uzun basış tek yerde (alanda) yakalanıyor. Onay kutusu `onCheck`
  ile ayrı geri çağrıya bağlandı. Regresyon testi: `fm_drag_select_test`
  (gerçek jest: startGesture → kLongPressTimeout → moveTo).
- Aralık matematiği saf fonksiyonda (`dragSelectDelta`): parmak GERİ çekilince
  fazladan seçilenler geri alınır (yoksa "geri çektim ama seçili kaldı" hatası).
- Kenara gelince otomatik kaydırma (72 px bölge, 16 ms timer) + kaydıktan sonra
  parmağın altındaki öğe yeniden hesaplanır.
- **Toplu seçme:** seçim çubuğuna `Tümünü seç / Seçimi kaldır` ikonu (durum
  duyarlı), ⋮ menüsüne "Seçimi tersine çevir"; başlık artık `N / M seçildi`.
- Uygulandığı ekranlar: gözatıcı (liste+ızgara), kategori (liste+ızgara),
  İndirilenler. Izgarada seçim rozeti (✓ daire) eklendi.

### B) Excel sadakati: görünüm tarafı `excel` paketinden AYRILDI
- **Kök karar:** `excel` 4.0.6 hizalamayı okumuyor (bilinen hata), sayı biçim
  kodunu vermiyor, tarihi kendi kafasına göre metne çeviriyor, dondurulmuş
  bölme/koşullu biçim/kenarlık/tema rengi/gizli satır-sütun bilgisini hiç
  taşımıyor. Sadakati %100'e çıkarmanın tek yolu sayfayı **kendimizin okuması**:
  yeni `services/xlsx_reader.dart` (styles.xml + theme1.xml + sheetN.xml +
  sharedStrings.xml). **Yazma/kaydetme yine `excel` paketinde** — dosya bozma
  riski alınmadı. İki taraf ayrı: okuma sadakati paket hatalarına takılmıyor.
- Okunanlar: hücre değeri (paylaşılan/satır içi dize, sayı, mantık, hata,
  formül + **Excel'in önbelleklediği sonuç**), numFmt (yerleşik + özel), yazı
  tipi/boyut/kalın/italik/altçizili/üstüçizili/renk, dolgu (desen yoğunluğu
  alfayla yaklaşıklanır), kenar başına kenarlık (stil+renk+kalınlık), yatay/
  dikey hizalama, metin kaydırma, girinti, döndürme, birleşik hücreler,
  sütun genişliği/satır yüksekliği, gizli satır/sütun, **dondurulmuş bölme**,
  ızgara çizgisi anahtarı, sekme rengi, gizli sayfa, koşullu biçimlendirme
  (cellIs/colorScale/dataBar/containsText…), veri doğrulama listesi, tema
  renkleri (+tint) ve indeksli palet.
- **TUZAK — `applyFont/applyFill/applyBorder` bayrakları yok sayılır:** birçok
  üretici (bizim yazma tarafımız dahil) bayrağı yazmadan stil kimliği veriyor;
  bayrağa uyulursa kalın/renkli hücreler DÜZ görünüyor. openpyxl/LibreOffice de
  kimliği doğrudan kullanır.
- **TUZAK — dxf (koşullu biçim) dolgusunda `patternType` YOKTUR**, yalnız
  `bgColor` verilir → desensiz ama renkli dolgu demektir (yoksa vurgu görünmez).
- **Tema indeksi ≠ clrScheme sırası:** dosyada dk1,lt1,dk2,lt2… sırasıyla yazılır
  ama `theme="0"` = lt1'dir → ilk iki çift yer değiştirilir.

### C) Sayı biçimi motoru (`core/excel_format.dart`, saf Dart)
Bölümler (`pozitif;negatif;sıfır;metin`), koşullu bölüm (`[>=1000]…`), renk
etiketi (`[Red]`/`[Kırmızı]`→ARGB), `0 # ?` yer tutucuları, binlik gruplama,
sondaki virgülle 1000'e bölme, yüzde, tırnaklı/kaçışlı metin, `_x`/`*x`,
para etiketi `[$₺-41F]`, tarih/saat (Türkçe ay/gün adları), geçen süre `[h]`,
kesir, bilimsel gösterim, `@`. Gösterim Türkçe (binlik `.`, ondalık `,`, `%15`).
- **TUZAK — `dd.mm.yyyy`de nokta ondalık ayıracı DEĞİLDİR:** aynı jeton hem
  tarih ayıracı hem ondalık nokta olabiliyor; ondalık virgülüne çevrilirse tarih
  "01,01,2024" çıkıyordu. Kesirli saniye (`mm:ss.0`) varsa virgül, yoksa nokta.
- **TUZAK — `m` hem AY hem DAKİKA:** saatten sonra/saniyeden önce gelirse dakika.
  `[h]:mm` (geçen süre) de saat sayılmalı, yoksa ay yazılıyordu.
- **TUZAK — sayı biçiminde tarih harfi:** `#,##0" adet"` içindeki `d` tarih
  sanılıyordu. Ayraç: tarih biçimlerinde tam sayı yer tutucusu (0/#/?) BULUNMAZ.
- **TUZAK — yalnız düz metin taşıyan bölüm "General" değildir:** `0;-0;"—"`
  kodunda sıfır bölümü `—` yazmalı; General sayılırsa `0` yazıyordu.

### D) Formül motoru büyütüldü (`services/formula_engine.dart`)
- Gerçek Excel **hata değerleri** (`#SAYI/0! #DEĞER! #AD? #YOK #BAŞV! #SAYI!`)
  artık istisna değil DEĞER → `EĞERHATA/IFERROR`, `EHATALIYSA` çalışıyor.
  (Argüman değerlendirmesi `_safeParse` ile hatayı değere çeviriyor; ayrıştırma
  hatası hâlâ istisna.)
- `&` metin birleştirme, `;` argüman ayıracı (Türkçe Excel), **Türkçe fonksiyon
  adları** (TOPLA, EĞER, DÜŞEYARA, ETOPLA, METNEÇEVİR… ~100 takma ad),
  **çapraz sayfa referansı** (`Sayfa2!A1`, `'Ad Soyad'!A1:B2`), hücre önbelleği.
- Yeni fonksiyonlar: SUMIF(S)/COUNTIF(S)/AVERAGEIF(S)/MAXIFS/MINIFS (joker `*?`
  ve `">15"` ölçütleriyle), VLOOKUP/HLOOKUP/INDEX/MATCH, MEDIAN/MODE/STDEV/VAR/
  LARGE/SMALL/RANK/SUMPRODUCT/SUBTOTAL, IFS/SWITCH/CHOOSE/XOR, IS* ailesi,
  ROUNDUP/DOWN/CEILING/FLOOR/TRUNC/MOD(Excel işareti)/GCD/LCM/FACT, metin
  ailesi (FIND/SEARCH/SUBSTITUTE/REPLACE/REPT/PROPER/TEXTJOIN/EXACT/VALUE),
  **TEXT()** (sayı biçim motorunu kullanır) ve tarih ailesi (TODAY/NOW/DATE/
  YEAR/MONTH/DAY/WEEKDAY/EDATE/EOMONTH/DATEDIF) — Excel seri numarasıyla.
- **Sonuç HAM kalır** (ondalık `.`); hücrenin sayı biçimi gösterim katmanında
  uygulanır. Bu ayrım korunmazsa `=A1*2` biçimli metni sayı sanar (eski karar).

### E) Izgara yeniden yazıldı (`screens/editors/spreadsheet_editor_screen.dart`
    + yeni `widgets/sheet_cell.dart`)
- **Satır/sütun başlıkları artık SABİT** (eskiden yatay kaydırınca satır
  numaraları kaçıyordu) ve **dosyadaki dondurulmuş bölme uygulanıyor** —
  kullanıcının "sağ/sol ayrı oynuyor" dediği SAHU dosyası bu yüzden bölünüyordu.
  Dört bölge (köşe / donmuş satırlar / donmuş sütunlar / gövde) bağlı
  kaydırmayla: gövde sürüklenir, başlıklar `jumpTo` ile takip eder. İki liste de
  `itemExtentBuilder` kullandığı için piksel piksel örtüşür.
- **Sütunlar yatayda da sanallaştırıldı** (görünen pencere + iki yandan boşluk)
  → 512 sütunluk dosyada kare başına ~15 sütun çizilir.
- Hücre çizimi `SheetCell`: dolgu, **kenar başına** kenarlık (CustomPainter —
  Flutter `BorderSide`ında `double`/kesikli Excel stilleri yok), yazı tipi
  (Calibri→Carlito, Arial→Arimo, Times→Tinos metrik-uyumlu eşleme), dikey+yatay
  hizalama, metin kaydırma, girinti, sayı biçimi rengi, koşullu biçim
  (renk ölçeği/veri çubuğu/hücre kuralı), seçim çerçevesi.
- **Aralık seçimi**: basılı tut + kaydır (dosya yöneticisiyle aynı MetaData
  tekniği); başlığa dokunuş tüm satırı/sütunu, köşeye dokunuş tüm sayfayı seçer.
- **Excel'in durum çubuğu**: seçili aralığın Ortalama · Sayı · Toplam değeri.
- Veri doğrulama listesi olan hücrede formül çubuğunda **açılır ok**.
- Gizli satır/sütun çizilmez, ızgara çizgisi anahtarı ve sekme rengi uygulanır,
  gizli sayfa sekmede görünmez, CSV dışa aktarımı artık **görünen metni** yazar
  (tarih seri numarası değil).
- **TUZAK — birleşik hücre bölme sınırında taşıyor:** A1:C1 birleşmesi donmuş
  sütun bölmesinde tüm genişliğiyle çizilince `RenderFlex overflowed by 153px`.
  Çözüm: birleşik genişlik YALNIZ o bölgede çizilen sütunları toplar.
- **TUZAK — dikey birleşme:** satırlar sabit uzantılı tembel listede çizildiği
  için çapa kendi satır yüksekliğinde kalır (içerik üst satırda görünür).

### F) YENİ VE ÖNEMLİ — bulut oturumunda Flutter SDK'sı İNDİRİLEBİLİYOR
- Bu Linux oturumunda `dart-sdk` ve **Flutter 3.29.3** (CI ile birebir aynı
  sürüm) indirilip `flutter pub get / analyze / test` koşturuldu. Yani
  "yerelde Flutter yok, kör push" varsayımı ARTIK GEÇERSİZ: bulut oturumunda da
  gerçek doğrulama yapılabilir.
  - `storage.googleapis.com/flutter_infra_release/releases/stable/linux/
    flutter_linux_3.29.3-stable.tar.xz` (~733 MB) → `git config --global
    --add safe.directory <yol>` gerekiyor (dubious ownership).
  - Bu turda **6 gerçek derleme/mantık hatası** bu sayede yakalandı
    (aşağıdaki tuzaklar dahil); kör push edilseydi APK derlemesinde ya da
    kullanıcının telefonunda çıkacaktı.
- **TUZAK — `flutter_test`te GERÇEK asenkron iş ilerlemez:** `File.readAsBytes()`
  sahte saat (fakeAsync) zonunda BAŞLATILIRSA hiç tamamlanmaz, `runAsync` de
  kurtarmaz → ekran sonsuza dek "yükleniyor" kalır. Çözüm hem testi hem ürünü
  düzeltti: dosya okuma da izolata taşındı (`_readAndParse`), ana izlekte artık
  disk G/Ç yok. Ayrıca `compute` izolatı flutter_test'te asılı kaldığı için
  `SpreadsheetEditorScreen.parseInIsolate` test kancası eklendi (üretimde daima
  true).
- **TUZAK — `testWidgets` gövdesinde `Directory.systemTemp.createTemp()`**
  aynı nedenle testi sonsuza kadar askıya alır; geçici dosyalar `setUp` içinde
  oluşturulmalı. (Bu yüzden "ekran hiç çizilmiyor" sanılıp yarım saat yanlış
  yerde arandı.)
- Yeni testler: `xlsx_reader_test` (elle üretilmiş zengin fixture
  `test/fixtures/rich_sheet.xlsx` + üreteci `make_rich_sheet.py`),
  `spreadsheet_screen_test` (widget duman testi — yerleşim taşmasını yakalar),
  `fm_drag_select_test`, genişletilmiş `formula_engine_test` ve
  `xlsx_number_format_test`. **335 test yeşil**, `flutter analyze` 0 hata.

## 2026-07-25 — Dosya yöneticisi arayüz turu: yerleşimler, Fotoğraflar, arama dizini
Kullanıcı bulguları (ekran görüntüleriyle): simgeler küçük ve çerçeveli, çöp
boşaltma sessiz, yerleşim seçenekleri yetersiz, görsellerde Google Fotoğraflar
düzeni yok, belgelerde tür süzgeci yok, arama her seferinde baştan tarıyor,
medya hep uygulama içinde açılıyor.

### A) Çerçevesiz ve büyük simgeler
`FmEntryIcon._badge` ve `FileTypeIcon` artık **kutu/kenarlık çizmiyor**; glif
kutunun %92'sini kaplıyor (eskiden dolgu + kenarlık içinde %52-54). Aynı
`size` değeriyle simge yaklaşık **1,7 kat** büyük görünüyor. `FileTypeIcon`ta
`framed: true` seçeneği rozet gerekirse duruyor (varsayılan çerçevesiz —
son belgeler listesi de aynı dili kullanıyor).

### B) `FmLayout` — iki durumlu `fmGrid` yerine altı yerleşim
`models/fm_layout.dart` (saf Dart, testli): liste · büyük liste · 2/3/4/5
sütun. Tercih `AppState.fmLayout` (dosyalar) ve `fmPhotoLayout` (fotoğraflar)
olarak AYRI tutuluyor — kullanıcı dosyalarda listeyi, fotoğraflarda ızgarayı
istiyor. Eski `fm_grid` bool'u okunmaya devam ediyor (açıksa 3 sütuna göç).
- **KARAR — `SliverGridDelegateWithFixedCrossAxisCount`:** eski
  `maxCrossAxisExtent: 120` telefonda 3, tablette 5 sütun üretiyordu;
  kullanıcı "3 sütun" dediğinde 3 sütun görmeli.
- **TUZAK — sabit en-boy oranı + sabit ikon boyu = taşma:** hücre yüksekliği
  orandan, ikon boyu formülden gelirse yazı tipi ölçeği büyütülmüş cihazda
  `RenderFlex overflowed` çıkıyor. Çözüm: ikon boyu **gerçek kısıtlardan**
  ölçülüyor (`LayoutBuilder`, hücre yüksekliği eksi 34 dp ad şeridi).
  Regresyon testi `fm_grid_tile_test` her yerleşimi 1.0 ve 1.6 yazı ölçeğinde
  çizip taşma olmadığını doğruluyor.
- Ortak tile'lar `widgets/fm/fm_entry_tiles.dart`e taşındı (gözatıcı ve
  kategori ekranı aynı öğeyi kullanıyor — eskiden iki ayrı kopyaydı).

### C) Fotoğraflar ekranı (`screens/fm/photos_screen.dart`)
Google Fotoğraflar tarzı zaman ekseni: **gün / ay / yıl** gruplaması, yapışkan
(pinned) başlıklar, tam kare önizlemeler (ad yok, 2 px aralık), grup başlığından
"gruptaki hepsini seç", kaynak çipleri, yerinde arama. Pano artık Görüntüler ve
Videolar kutularını buraya bağlıyor.
- Başlık metni `models/photo_group.dart`te saf fonksiyon: bugün/dün, son bir
  haftada gün adı, farklı yılda yıl. Testli (`fm_layout_test`).
- **KARAR — düz (flat) seçim indeksi:** sürükleyerek seçim aralığı gruplar
  boyunca kesintisiz yürümeli; her grup kendi indeksinden başlasaydı grup
  sınırında aralık koparadı. Her bölüm `startIndex` taşıyor.
- Sliver ağacı `SliverMainAxisGroup` + pinned `SliverPersistentHeader`.
  Yanlış kurulmuş sliver yalnız çizimde patladığı için `fm_photos_screen_test`
  ekranı gerçekten pump ediyor.

### D) Arama dizini (`services/fm/search_index.dart`) — "her seferinde baştan taramasın"
Eski arama her sorguda tüm depolamayı geziyordu. Artık düz bir dizin dosyası
(`search_index.tsv`, satır başına `yol \t boyut \t değişiklikMs \t klasörMü`)
var; sorgular bu dosyada koşuyor.
- **KARAR — dizin panonun taramasıyla AYNI yürüyüşte yazılıyor**
  (`FsScan.index(..., searchIndexPath:)`): pano zaten tüm ağacı geziyordu,
  aramanın ikinci kez gezmesi saf israftı. `StorageIndex.searchIndexRows` ile
  sayı dönüyor, `SearchIndex.adoptBuilt` yalnız metayı güncelliyor.
- **KARAR — dizin bellekte TUTULMUYOR:** 100 bin yol RAM'de ~15 MB. Sorgu
  `compute` isolate'inde dosyayı **64 KB'lık parçalar hâlinde** okuyor
  (UTF-8'de 0x0A çok baytlı dizinin içinde geçmez → baytları satırsonundan
  bölmek güvenli).
- Bayatlık: `FsEvents` sinyalinde dizin "bayat" işaretleniyor; arama yine
  ANINDA dönüyor, arka planda tazeleniyor, sonuçlar dönerken `exists` ile
  süzülüyor (silinmiş dosya sonuçta görünmez). Dizin yoksa canlı taramaya
  düşüyor — kullanıcı ilk taramayı beklemiyor.
- **TUZAK (testte yakalandı):** dizin dosyası taranan ağacın İÇİNDE olursa
  `.tmp` kendisi de sayılıyor. Üründe uygulama verisinde durduğu için sorun
  yok; test kökü ayrı klasöre alındı.

### E) Her alanda ayrı arama
Kategori, Fotoğraflar, Çöp Kutusu ve İndirilenler ekranlarına AppBar içi arama
eklendi. Bu listeler zaten bellekte → süzme anlık, disk okunmuyor
(`widgets/fm/fm_search_field.dart`, `fmMatches` Türkçe-duyarlı). Depolamanın
tamamında arama `SearchScreen` + dizin üzerinden; debounce 400 → 250 ms.

### F) Belge türü süzgeci
Belgeler kategorisinde PDF / Word / Excel / Slayt / Metin / Diğer çipleri
(`CategoryScreen.showDocKinds`). Sıra SABİT (sayıya göre sıralanırsa çipler her
açılışta yer değiştirir), boş tür gösterilmiyor.

### G) Çöp boşaltma artık sessiz değil
`TrashService.empty` ilerleme bildiriyor ve `FmOpResult` dönüyor. Onay
penceresinde kaç öğe/kaç MB silineceği yazıyor, silme sırasında ilerleme
penceresi (iptal edilebilir), sonunda "N öğe · X yer açıldı" özeti. Aynı
davranış hem Çöp ekranında hem ayarlardaki "şimdi boşalt"ta.

### H) "Kendi oynatıcımla aç" tercihi
`models/media_open_with.dart` (sor / uygulama içi / başka uygulama).
`EntryOpener` video-ses-görsel açarken tercihi soruyor; "Bunu hatırla"
işaretliyse kalıcı (ayarlardan da değiştirilebilir). Pencere kapatılırsa dosya
AÇILMIYOR — yanlışlıkla bir uygulamaya atmaktansa hiçbir şey yapmak yeğ.

**Doğrulama:** Flutter 3.29.3 (CI ile aynı) ile `flutter analyze` **0 hata**,
`flutter test` **362 test yeşil**.

## 2026-07-25 — Excel: sabit bölme ekranı yiyordu ("sağ tarafı göremiyorum") + hesap sadakati

Kullanıcı bulgusu: *"sağ sol kısımları ayrı oynayan excellerde kaydırdığımda
sağ kısmı göremiyorum"* + *"hesaplamalar tam görülmeli, Excel fonksiyonları
bizde de hesaplanmalı"*.

### A) KÖK NEDEN — dondurulmuş bölme pencereden genişse gövde 0 piksel kalıyordu
Dört bölgeli yerleşimde sol bölme `SizedBox(width: satırBaşlığı + donmuş
sütunlar)`, kaydırılan bölge ise `Expanded`. Dosyada 5 sabit sütun × 30 karakter
(≈1075 px) varsa `Row` telefon genişliğini aşıyor, **`Expanded` sıfır genişlik
alıyor** → sağ taraf hiç çizilmiyor (ayrıca `RenderFlex overflowed by 367px`).
Excel masaüstünde bölme pencereden geniş olabilir; telefonda bu, içeriğin
ERİŞİLEMEZ olması demek.
- **Karar:** `core/sheet_metrics.dart` → `fitFrozen(count, sizeOf, budget)`
  sabit bölgeye yalnız **bütçe kadar** satır/sütun alır (bütçe = eksen ölçüsü −
  başlık − en az %45/280 px gövde); sığmayan dondurulmuş sütunlar kaydırılan
  bölgeye bırakılır. Gizli (0 ölçülü) sütun bütçe yemez ama bölmeye dahildir.
- Bölme kısaltıldığında kullanıcıya bir kez bilgi (snackbar) + ⋮ menüsünde
  **"Bölmeleri çöz / dondur"** anahtarı (`_freeze`) — telefonda sabit bölme
  istemeyen kullanıcı tamamen kapatabiliyor.
- **Regresyon testi:** `test/fixtures/wide_freeze.xlsx` (üreteci
  `make_wide_freeze.py`) — 5×30 karakter sabit bölme + 40 sütun. Eski davranış
  geri getirildiğinde test `RenderFlex overflowed by 367 pixels` ile kırmızı
  oluyor (bilfiil doğrulandı).

### B) Sanallaştırma ölçüleri önbelleğe alındı, 512 sütun sınırı kalktı
`SheetAxisMetrics` (birikimli başlangıçlar + ikili arama): toplam genişlik,
kaydırma penceresi ve "hücreyi görünür yap" artık her karede baştan
toplanmıyor. Bu sayede **`_maxCols` 512 → 16384** (Excel sınırı) yapılabildi:
512. sütundan sonraki veriler eskiden HİÇ görünmüyordu. Boş sayfa da ızgara
görünsün diye en az 26 sütun / 60 satır çizilir (maliyeti yok); "tümünü seç"
ise KULLANILAN alanla sınırlı (yoksa durum çubuğu 16384 sütunu tarayacaktı —
200 bin hücre üstünde yalnız hücre sayısı gösteriliyor).
Yan düzeltmeler: satır başlığı listesi ile gövde listesinin **alt boşluğu
eşitlendi** (en altta satır numaraları kayıyordu), iki eksene kaydırma çubuğu,
seçim/`Hücreye git` artık hücreyi görünür yapıyor (`_ensureVisible`).

### C) Hesap sadakati
- **Motorumuz hesaplayamazsa Excel'in önbelleklediği sonuç gösteriliyor**
  (eskiden yalnız `#HATA`/`#DÖNGÜ`/boş için): desteklemediğimiz bir fonksiyon
  (`TREND` gibi) artık `#AD?` yerine Excel'deki değeriyle görünür.
  Hata kodları Türkçeleştirildi (`#DIV/0!` → `#SAYI/0!`, `isExcelErrorText` /
  `localizedExcelError`).
- **TUZAK — paylaşılan formül (`<f t="shared" si="…">`):** Excel aşağı
  çekilen formülün metnini YALNIZ ana hücreye yazar. Açmadığımız için o
  hücreler "formülsüz" sayılıyor, formül çubuğu boş kalıyor ve düzenleme
  sonrası yeniden hesaplanmıyordu. `XlsxReader.shiftFormulaRefs` göreli
  başvuruları kaydırıyor (`$` sabit kalır; dize sabiti, tırnaklı sayfa adı,
  fonksiyon adı `LOG10(` ve sayı `2e5` kaydırılmaz; sayfa dışına kayan →
  `#REF!`).
- **TUZAK — sayı arayan DÜŞEYARA/ÇAPRAZARA hiç eşleşmiyordu:** hücre değerleri
  modelde HAM METİN (`'20'`), ölçüt ise sayı (20) olduğu için `_compare` bunları
  "metin < sayı" sırasına koyuyordu. Artık iki taraf da sayıya çevrilebiliyorsa
  SAYISAL karşılaştırılıyor.
- **Yeni fonksiyonlar (~45):** KAYDIR/OFFSET, DOLAYLI/INDIRECT, ADRES,
  ARA/LOOKUP, ÇAPRAZARA/XLOOKUP, FORMÜLMETNİ, EFORMÜLSE, EREFSE, ÇİFTMİ/TEKMİ,
  HATA.TİPİ, KYUVARLA(MROUND), TAVANAYUVARLA/TABANAYUVARLA.MATEMATİK,
  KOMBİNASYON/PERMÜTASYON, SİNH/COSH/TANH, ORTALAMAA/MAKA/MİNA, GEOORT/HARORT,
  ORTSAP/SAPKARETOPL, YÜZDEBİRLİK/DÖRTTEBİRLİK/YÜZDERANK, METİNÖNCE/METİNSONRA,
  SAYIDEĞERİ (baştaki `%15` de kabul), SAYIDÜZENLE, UNICHAR/UNICODE, HAFTASAY/
  ISOHAFTASAY, TAMİŞGÜNÜ/İŞGÜNÜ, TARİHSAYISI/ZAMANSAYISI, YILORAN ve finans
  ailesi (DEVRESEL_ÖDEME/BD/GD/TAKSİT_SAYISI/FAİZ_ORANI/FAİZTUTARI/
  ANA_PARA_ÖDEMESİ/NBD/İÇ_VERİM_ORANI/DA) — kredi-taksit tabloları için.
  `SATIR()`/`SÜTUN()` argümansız kendi hücresini veriyor (bunun için tek hücre
  başvuruları artık REFERANS olarak taşınıyor, değere `_single` ile indiriliyor).
- **Noktalı Excel 2010+ adları** eklendi (`STDEV.S`, `VAR.P`, `MODE.SNGL`,
  `PERCENTILE.INC`…) — dosyalarda bu adlar yazılı olduğu için `#AD?` çıkıyordu.
- **TUZAK — Türkçe ad eşlemesi yanlıştı:** `KYUVARLA` CEILING'e bağlıydı;
  doğrusu `TAVANAYUVARLA` = CEILING, `KYUVARLA` = MROUND.

**Doğrulama:** Flutter 3.29.3 (CI ile aynı) — `flutter analyze` **0 hata**,
`flutter test` **390 test yeşil** (32 yeni test: `sheet_metrics_test`,
genişletilmiş `formula_engine_test`, `spreadsheet_screen_test`,
`xlsx_reader_test`). `graphify update .` bu bulut oturumunda ÇALIŞTIRILAMADI
(CLI kurulu değil) — kod haritası bir sonraki yerel turda yenilenmeli.

## 2026-07-25 — Video oynatıcı: dokununca görüntü kayıyordu

**Şikâyet (kullanıcı, ekran görüntüsü):** oynatıcıda videoya dokununca görüntü
küçülüp aşağı kayıyor, kontroller kaybolunca geri sıçrıyor.

### KÖK NEDEN — üst bar `Scaffold.appBar` slotundaydı
`appBar: _controlsVisible ? AppBar(...) : null` yazılmıştı. `appBar` bir
Scaffold **yerleşim slotu**: dolu olduğunda `body`'nin yüksekliğinden
`kToolbarHeight + durum çubuğu` kadarını yer. Video `Center` + `AspectRatio`
ile ortalandığı için body kısalınca görüntü hem küçülüyor hem yukarı/aşağı
oynuyordu — yani kayma her dokunuşta **iki kez** (aç/kapa) yaşanıyordu.

**Çözüm:** üst bar da alt kontroller gibi `Stack`'te overlay
(`Positioned(top:0)` + `SafeArea` + koyu gradyan). Scaffold'un `appBar` slotu
artık BOŞ → body her zaman tam ekran, görüntü hiç oynamıyor.

- **Kural:** tam ekran medya ekranlarında görünürlüğü değişen hiçbir çubuk
  Scaffold slotuna (`appBar`/`bottomNavigationBar`) verilmez; overlay yapılır.
- **Yan düzeltme:** `GestureDetector`'a `behavior: HitTestBehavior.opaque`.
  Varsayılan `deferToChild` ile videonun yanındaki siyah boşluklarda dokunma
  hiç yakalanmıyordu (kontroller yalnız görüntünün üstünde açılıyordu).
- **Yeni test — `media_player_layout_test.dart`:** sahte `VideoPlayerPlatform`
  (gerçek ExoPlayer yerine) takılıp kontroller açık/kapalı hâlde
  `find.byType(VideoPlayer)` dikdörtgeni ölçülüyor; birebir aynı olmalı. Bar
  tekrar Scaffold slotuna taşınırsa test kırmızı yanar.
  - Sahte motor için `video_player_platform_interface` **dev_dependency**
    olarak eklendi (zaten kilitli alt paket; `pubspec.lock` değişmedi).
  - `VideoPlayerPlatform`'u `extends` etmek yeterli — `MockPlatformInterfaceMixin`
    (plugin_platform_interface) gerekmiyor, token doğrulaması geçiyor.
  - Testin sonunda `pumpWidget(SizedBox())` şart: controller'ın periyodik
    konum zamanlayıcısı iptal olmazsa "A Timer is still pending" hatası.

**Doğrulama:** Flutter 3.29.3 (CI ile aynı) — `flutter analyze` 0 hata,
`flutter test` **391 test yeşil**.

## 2026-07-25 — Pano her açılışta tüm depolamayı baştan tarıyordu

**Şikâyet (kullanıcı):** "dosya yöneticisi açılırken de her seferinde tüm
dosyaları baştan tarıyor."

### KÖK NEDEN — pano indeksi yalnız SÜREÇ İÇİ önbellekteydi
`_DashboardScreenState._cachedIndex` `static`ti: sekmeler arası geçişte
korunuyor ama uygulama kapanınca yok oluyordu. Her açılışta `FsScan.index`
tüm ağacı yeniden yürüyordu (100 bin dosyada dakikalar + pil).

### ÇÖZÜM — pano, arama dizininin kendisinden kuruluyor (disk yürüyüşü YOK)
Arama dizini (`search_index.tsv`) zaten her dosya/klasör için
`yol \t boyut \t değişiklikMs \t klasörMü` tutuyor — panonun ihtiyacı olan her
şey orada. Yeni `FsScan.indexFromRows(indexPath)` bu düz dosyayı okuyup
`StorageIndex`'i **birebir aynı** kuruyor (saniyenin altı).

- Açılış akışı: dizin varsa anında kur ve göster → çöp/klasör boyutları →
  yalnız GEREKİRSE arka planda tam tarama (`unawaited(_scan())`).
  "Gerekiyor" = dizin bayat VEYA 12 saatten eski (`_maxIndexAge`).
- Sayım/sıralama mantığı `_IndexAccumulator`'a çıkarıldı; canlı yürüyüş ile
  dizinden kurma **aynı kodu** kullanıyor (iki yerde sapma olamaz).
- `encodeIndexRow`/`decodeIndexRow` `search_index.dart`'tan `fs_scan.dart`'a
  taşındı (yazıcı zaten oradaydı, satır biçimi kopyalanmıştı); eski konumdan
  `export` ile yeniden yayımlanıyor.
- **TUZAK — bayatlık diske yazılmalı:** `SearchIndex._stale` yalnız bellekteydi.
  Uygulama kapanınca unutuluyor, bir sonraki açılışta bayat dizin taze
  sanılıyordu (silinen dosya panoda sayılmaya devam ederdi — 2026-07-25'te bir
  kez düzeltilen hatanın kalıcı önbellekle geri gelme yolu). Artık meta
  json'a `stale` alanı yazılıyor; meta yazımı tek yerden (`_writeMeta`).
- **TUZAK — TSV'yi `String.fromCharCodes` ile okumak Türkçe adları bozar.**
  Bayt bazlı okuyup `0x0A`'dan bölmek ve `utf8.decode` şart (arama
  sorgusunun kullandığı yöntemin aynısı).

**Yeni testler** (`fm_search_index_test`): dizinden kurulan indeks tam
taramayla aynı sayılar/listeler; dizin yok/boşsa `null` (çağıran tam taramaya
düşer); bozuk satırlar atlanır.

---

## 2026-07-25 — Play Store atağı: PDF Faz 1 (PDF Araçları)

**Neden:** "PDF için bizi Play'de öne çıkaracak ne eklenir" sorusu. Verdikleri
karar: okuma özellikleri (arama/vurgu/çeviri/AI) tutundurur ama İNDİRTMEZ;
indirten aramalar *PDF birleştir / sıkıştır / imzala / şifrele / tara*.
4 fazlı yol haritası kabul edildi (KALANLAR "Play Store atağı" bölümü):
1 = PDF araçları, 2 = imza, 3 = belge tarayıcı, 4 = okuma deneyimi.
Teslim ritmi: **faz faz push + APK**, her fazı kullanıcı telefonda doğrular.

**Reddedilen yol — PDF→Word/Excel dönüştürme:** en çok aranan özellik ama
offline'da düzgün olmuyor; bulut gerektirir = maliyet + "dosyan telefondan
çıkmıyor" konumlandırmasını bozar. Konumlandırma (tam çevrimdışı, reklamsız)
özelliğin kendisinden daha değerli görüldü.

**Yapılan (Faz 1):** `lib/services/pdf_tools.dart` (saf Syncfusion, YENİ
BAĞIMLILIK YOK) + `lib/screens/pdf_tools_screen.dart` (sayfa küçük resim
ızgarası). Giriş: ana ekran AppBar PDF simgesi **ve** görüntüleyici ⋮ menüsü.

**Syncfusion Flutter ≠ Syncfusion .NET — TUZAK:** .NET'teki
`importPageRange` / `PdfDocument.merge` Flutter sürümünde **yok**. Sayfa
kopyalama tek yoldan olur: `srcPage.createTemplate()` → hedefte
`graphics.drawPdfTemplate(...)`. Birleştir/çıkar/sil/sırala bu yüzden tek
özel fonksiyona (`PdfTools._compose`) indirildi — dört iş de aynı kod.

**TUZAK — `createTemplate()` `/Rotate`'i taşımaz:** `PdfPage.size` ham kutu
ölçüsüdür, döndürmeyi yansıtmaz. 90/270° döndürülmüş sayfa kopyalanırken
hedef sayfanın en/boyu takas edilip grafik `translate+rotate` ile
çevrilmezse sayfa yan yatar ve taşar. Dönüşüm saf fonksiyona alındı
(`composedPageTransform`) ve testi yazıldı; ayrıca gerçek PDF üretilip
çıktı sayfa boyutu ölçülüyor.

**TUZAK — `PdfPage.rotation` setter'ı yalnız YÜKLENMİŞ (loaded) sayfada
çalışır** (`isLoadedPage` kontrolü kaynak kodunda). Yeni oluşturulan sayfaya
rotasyon yazılamaz — bu yüzden döndürme, belgeyi yeniden kurmadan doğrudan
yüklü belge üzerinde yapılıp kaydediliyor (kayıpsız, `/Rotate` girdisi).

**TUZAK — parola/sıkıştırma `incrementalUpdate = false` ister.** Syncfusion
varsayılanı artımlı güncelleme: şifreleme eski gövdeye EK olarak yazılır,
şifresiz ilk sürüm dosyada kalır (güvenlik açığı) ve sıkıştırma hiç kazanç
vermez. `doc.fileStructure.incrementalUpdate = false` şart.

**Sıkıştırmanın sınırı (bilinçli):** yalnız akış (stream) sıkıştırması —
gömülü görseller yeniden örneklenmiyor, o yüzden TARANMIŞ PDF'te kazanç
küçük. Agresif mod istenirse yol: sayfaları pdfrx ile bitmap'e render edip
JPEG kalitesi düşürülmüş yeni PDF kurmak (metin katmanı kaybolur → ayrı
seçenek olarak sunulmalı, sessizce yapılmamalı).

**pdfrx TUZAĞI — `PdfDocumentRefData` eşitliği yalnız `sourceName`'e bakar.**
Baytlar değişip ad aynı kalırsa önizleme tazelenmez; `sourceName`'e revizyon
sayacı eklendi (`'$path#$rev'`). Aynı sorunun dosya yolu sürümü zaten
biliniyordu (`_pdfReloadKey` remount, Faz 2 vurgu).

**Test:** `test/pdf_tools_test.dart` — 19 test, gerçek PDF üretip yeniden
açarak doğruluyor (Syncfusion PDF I/O cihazsız koşuyor). Sayfa SIRASI, her
sayfaya farklı GENİŞLİK verilip çıktının genişlik listesi okunarak
doğrulanıyor — metin çıkarmaya güvenmeye gerek kalmıyor.

**Not — Windows'ta yerel test paketinde 14 kırmızı var** (`fm_archive_rar`,
`fm_compress`, `fm_trash`, `fm_scan`, `fm_storage_archive`, `formula_engine`):
hepsi yol ayracı (`/` vs `\`) ve temp dizin kaynaklı, bu iş ÖNCESİNDE de
kırmızıydı (stash ile doğrulandı), Linux CI'yı ilgilendirmiyor.

---

## 2026-07-25 — Faz 3: Belge tarayıcı (kamera → "tarayıcıdan çıkmış gibi" PDF)

**İstek:** "tarayıcı makinesinde taranması gereken belgeleri kolayca kameradan
tarayıp sanki tarayıcıdan çıkmış gibi yapsın, paylaşıma hazır olsun."

**Karar — motoru kendimiz yazmadık.** Kenar tespiti + perspektif düzeltme +
kontrast/gri filtre işi **Google ML Kit Belge Tarayıcı**'ya verildi
(`cunning_document_scanner` 1.2.3 → `play-services-mlkit-document-scanner`,
`SCANNER_MODE_FULL`, sonuç JPEG). Kendi kamera+kırpma ekranımızı yazmak ~10 kat
iş ve kenar tespiti modeli bizde bakım yükü olurdu. Paket, Play Services yoksa
kendi yedek tarayıcı ekranına düşüyor (`fallback/DocumentScannerActivity`).
Sürüm 1.2.3 seçildi çünkü 2.8.0 Dart >=3.8 istiyor, biz 3.7'deyiz (CI 3.29.3).

**Bizim payımız:** çok sayfa → **tek PDF** + isteğe bağlı OCR görünmez metin
katmanı (aranabilir PDF) + Belgeler dizinine kaydet + görüntüleyicide aç.

**Refactor (yerine-geçen siler):** `ConversionService.imageToPdf` artık tek
başına bir yol değil; genel `imagesToPdf(List<String>)` yazıldı ve tek görsellik
hâl ona delege ediliyor. Tarayıcının çok sayfası ile tek resim aynı koddan
geçiyor — sayfa/ölçek/OCR mantığı iki yerde ayrışamaz.

**PLAY STORE TUZAĞI — `uses-feature android.hardware.camera required="true"`:**
tarayıcı eklentisi kendi manifest'inde kamerayı ZORUNLU bildiriyor. Birleşmiş
manifest'te öyle kalırsa **Play Store uygulamayı kamerasız cihazlarda gizler**
(bazı tabletler, Chromebook) — dosya okuyucu için ciddi erişim kaybı.
`ci/AndroidManifest.xml`'e `required="false"` + `tools:replace` eklendi.
Yeni bir donanım-bağımlı eklenti girerse aynı kontrol yapılmalı.

**Akış tek yerde:** `lib/widgets/scan_flow.dart` (`TranslateFlow` kalıbı) —
tara → "yazılar da tanınsın mı?" → ilerleme → kaydet → aç. Hem ana ekran
"Belge Tara" düğmesi hem PDF Araçları ⋮ "Sayfa tara ve ekle" aynı servisi
çağırıyor; ikincisi taranan sayfaları açık belgeye `PdfTools.merge` ile ekliyor.

**Test:** `image_to_pdf_test`e çok sayfa testi — 3 görselden üretilen PDF'te
sayfa nesnesi sayısı 3 (tek sayfaya üst üste binme regresyonunu yakalar).
OCR/kamera cihaz gerektirir, birim testle doğrulanamaz → KALANLAR'da cihaz
doğrulama maddesi var.

---

## 2026-07-25 — Faz 2: İmza + Faz 1'de bulunan VERİ KAYBI hatası

### Bulunan hata: sayfa kopyalama vurguları siliyordu (Faz 1)
Faz 2'nin koordinat matematiğini doğrularken ölçüldü: `createTemplate()` sayfa
İÇERİĞİNİ kopyalar, **annotation'ları (vurgu/not) kopyalamaz**. Yani Faz 1'de
sayfa silmek, taşımak veya birleştirmek kullanıcının tüm vurgularını sessizce
siliyordu (deney: 1 vurgu → compose sonrası 0).

**Kök neden düzeltmesi:** silme artık `PdfTools.deletePages` ile **yerinde**
(`doc.pages.removeAt`) yapılıyor — annotation'lar korunuyor (ölçüldü: 1 → 1).
Kopyalamak zorunda olan işlemler (taşı/birleştir/tara-ekle) için, belgede vurgu
VARSA kullanıcıya "$n vurgu silinecek" onayı soruluyor. Sessiz kayıp yok.
`selectPages` doc'una kalıcı uyarı yazıldı; `pdf_tools_test` bu sınırı
**test olarak sabitliyor** (Syncfusion bir gün taşımaya başlarsa test kırmızıya
döner ve uyarıyı kaldırırız).

### Döndürme matematiği artık ÖLÇÜLDÜ (varsayım değil)
`PdfTextExtractor.extractTextLines()` ile: sol-üstte "Sayfa 300" yazan 300x400
sayfa 90° döndürülüp kopyalanınca metin 400x300 sayfanın SAĞ ÜST bölgesine
düşüyor (x≈373, y≈67) — `composedPageTransform` doğru. 180° ve 270° de kontrol
edildi. **Not:** döndürülmüş metnin `bounds`'u kendi dönmüş çerçevesinde gelir
(180°de left>right çıkar) — kutu ŞEKLİNE değil, KENAR konumuna bakılmalı.

### İmza — resim değil VEKTÖR
Karar: imza PNG olarak değil, `PdfPath` + `drawPath` ile **vektör** basılıyor.
Nedenleri: (a) her yakınlaştırmada keskin, (b) dosya birkaç yüz bayt,
(c) PNG saydamlığının (RGBA→SMask) Syncfusion'da doğru gömülüp gömülmediğine
bağımlı kalmıyoruz. İmza noktaları 0..1 normalize + en/boy oranı olarak
`SharedPreferences`'ta saklanıyor → resim dosyası yönetimi yok, tekrar tekrar
çizdirmiyoruz.

**TUZAK — `PdfPath.addPolygon` şekli KAPATIR** (son noktadan ilkine çizgi
çeker): imzada saçma bir kapanış çizgisi oluşur. `startFigure()` + segment
segment `addLine` kullanıldı. (`addLines` public API'de YOK, sadece helper'da.)

**Koordinat sözleşmesi:** kullanıcı sayfayı `/Rotate` uygulanmış hâliyle görür
(pdfrx `PdfPage.width/height` zaten döndürülmüş ölçü verir) ve imzayı ona göre
koyar; sayfanın grafik uzayı ise ham. Köprü `stampTransform` —
`composedPageTransform`'un TERSİ. Test bunu gidiş-dönüş kimlik olarak
doğruluyor (4 açı × 4 nokta); yanlış olsa imza başka köşeye yan yatık basılırdı.

**İmza ekranı yalnız görüntüleyici ⋮ menüsünden açılıyor**, PDF Araçları'ndan
DEĞİL: araçlar ekranı bellekteki kaydedilmemiş baytlarla çalışıyor, imza ise
dosyaya yazıyor — ikisi aynı anda açık olsa biri diğerinin işini ezerdi.

---

## 2026-07-25 — Faz 4: okuma deneyimi (gece modu, köprü, içindekiler, sesli okuma)

Play Store atağının son fazı. Dördü de görüntüleyicide (`viewer_screen`),
hiçbiri dosyaya yazmıyor.

**Gece modu:** `ColorFiltered` + renk TERSLEME matrisi (R'=255-R …).
`Colors.white` gibi tek renk yerine matris, çünkü sayfadaki resim/grafikler de
terslenmeli. Salt boya — seçim/arama koordinatlarına dokunmuyor.

**Köprü (link):** `PdfViewerParams.linkHandlerParams`. İç hedef →
`controller.goToDest`, dış adres → **önce onay penceresi (tam URL gösterilir)**,
sonra `url_launcher`. Onay isteğe bağlı bir nezaket değil: belgedeki bağlantı
METNİ gerçek hedefi gizleyebilir (kimlik avı), kullanıcı nereye gittiğini
görmeden açmamalı.

**İçindekiler:** `document.loadOutline()` → girintili DÜZ liste (ağaç/açılır
düğüm yok — aynı işi görüyor, çok daha az kod). Belgede outline yoksa
kullanıcıya söyleniyor.

**Sesli okuma:** `flutter_tts`, cihazın kendi motoru, internet yok.
`lib/services/tts_service.dart`. Metin TEK parça verilmiyor: motor uzun metinde
kesiyor, durdurma gecikiyor ve nerede kalındığı bilinemiyor. `splitForSpeech`
cümlelerden bölüyor, uzun kalanları kelime sınırından kesiyor; arayüz
"3 / 128" ilerlemesi gösteriyor. `setCompletionHandler` ile sıradaki parçaya
geçiliyor, `setErrorHandler` → `stop()` (motor hata verince sıra kilitlenip
uygulama sessizleşmesin). Ekran kapanınca `dispose` konuşmayı kesiyor.
Metin kaynağı mevcut `_documentText` — taranmış PDF'te boş çıkar, kullanıcı
"önce OCR" uyarısı alır.

**Yeni bağımlılıklar:** `flutter_tts ^4.2.5`, `url_launcher ^6.3.2`
(url_launcher zaten printing üzerinden DOLAYLI geliyordu; doğrudan bağımlılık
yapıldı — dolaylıya güvenmek, ara paket sürüm değiştirince kırılır).

**Test:** `tts_split_test` — bölme metnin tamamını korur, sınırı aşmaz, kelime
ortadan bölünmez, boşluksuz dev kelimede sonsuz döngüye girmez. Konuşma motoru
ve PDF köprüleri cihaz gerektirir → KALANLAR'da doğrulama maddesi.

### Derleme tuzağı — Kotlin eklenti sürümü (build 119 kırmızı)
`flutter_tts 4.2.5` Kotlin **2.x** ile derlenmiş `kotlin-stdlib` (2.2.20)
çekiyor; Flutter 3.29.3 şablonunun Kotlin eklentisi **1.8.22** bu metadata'yı
okuyamıyor → `Class 'kotlin.Unit' was compiled with an incompatible version of
Kotlin` + `Unresolved reference: let/it`, `:flutter_tts:compileReleaseKotlin`
patlıyor.

**Çözüm:** CI'da `android/settings.gradle` içindeki
`org.jetbrains.kotlin.android` sürümü sed ile **2.1.0**'a yükseltiliyor (minSdk/
NDK yamalarıyla aynı kalıp, `build-apk.yml`). Yeni derleyici ESKİ metadata'yı
okuyabildiği için yükseltmek güvenli yön. Eklentiyi eski sürüme düşürmek
denenmedi: hangi sürümün hangi Kotlin'le derlendiğini deneme yanılmayla aramak
demekti. **Yeni bir eklenti Kotlin 2.x isterse artık sorun çıkmaz;** tersi
(1.8'e bağlı eski eklenti) gelirse bu satır hatırlansın.

---

## 2026-07-26 — PDF turu: vurgu KÖK NEDENİ, donma, seçim UX, tarama düzeltme

Kullanıcı 11 maddelik bir liste verdi (PDF düzenleme, AI, kaydetme, uzun belge
gezinme, sıkıştırma donması, vurgulama, metin seçimi, arka plan işlemleri,
tarama). Hepsi bu turda kapatıldı. Aşağıdakiler **kök neden** kayıtlarıdır.

### 1) TUZAK — pdfrx belgeleri STATİK haritada dosya YOLUNA göre önbelleğe alır
**Belirti:** "PDF'te vurgulama çalışmıyor." Vurgu Syncfusion'la dosyaya
gerçekten yazılıyordu (dosya baytları değişiyor) ama ekranda hiç görünmüyordu.
İmza ve PDF Araçları'ndan kaydetme de aynı derde giriyordu.

**Kök neden:** `PdfDocumentRef._listenables` **statik** bir `Map` ve
`PdfDocumentRefFile`'ın `==`'i YALNIZ `file` yoluna bakıyor. Bizim çözümümüz
widget'ı `ValueKey(_pdfReloadKey)` artırıp yeniden bağlamaktı — bu İŞE YARAMIYOR:
Flutter anahtarı değişince önce YENİ elemanı kurar (`initState` →
`resolveListenable()`), eskinin `dispose`'u (dolayısıyla `removeListener` ve
önbellekten düşme) karenin SONUNDA çalışır. Yani yeni widget haritadaki eski
kaydı bulur, `load()` "zaten yüklendi" deyip erken döner ve ekranda dosyanın
ESKİ hâli kalır — kalıcı olarak.

**Çözüm:** `lib/services/pdf_reload.dart` — aynı listenable bulunup
`load(forceReload: true)` çağrılıyor; bu, açık görüntüleyiciye haber verir.
Yeniden bağlama tamamen kaldırıldı, bonus olarak kullanıcı **aynı sayfada**
kalıyor. Yükleme sırasında kaydın serbest bırakılmaması için geçici bir
dinleyici eklenip iş bitince kaldırılıyor (görüntüleyici kapalıysa belge
bellekte asılı kalmasın).

**Ders:** pdfrx'te "dosyayı değiştirdim, tazele" = `forceReload`. Widget
anahtarı DEĞİL. Aynı sınıf hata `PdfDocumentRefData`'da `sourceName` ile
çözülmüştü (2026-07-25 notu) — dosya sürümü atlanmıştı.

**Yan etki yönetimi:** `forceReload` eski `PdfDocument`'ı dispose ediyor →
elimizdeki `_pdfDoc` bir kare boyunca ölü kalır. Bu yüzden `_reloadPdf` onu
null'lıyor (OCR/içindekiler ölü belgeye dokunmasın); yenisi `onViewerReady`
ile geri geliyor.

### 2) TUZAK — PDF Araçları'nda her dokunuş belgeyi DISPOSE edip yeniden yüklüyordu
**Belirti:** "PDF düzenlemede her sayfa seçtiğinde baştan render oluyor ve
başa atıyor."

**Kök neden:** ekran `setState` edince `PdfDocumentViewBuilder` yeni bir widget
ÖRNEĞİ oluyor. pdfrx'in `didUpdateWidget`'i `widget == oldWidget` (kimlik)
değilse eski listenable'dan dinleyiciyi kaldırıyor → başka dinleyici kalmadığı
için `_releaseIfNoRefs` belgeyi **dispose ediyor** → hemen ardından yeni kayıt
kuruluyor ve belge SIFIRDAN yükleniyor. Arada `document == null` döndüğü için
ızgara ağaçtan düşüyor: kaydırma başa gidiyor, tüm küçük resimler yeniden
çiziliyor. Yani suçlu "gereksiz rebuild" değil, pdfrx'in kimlik-tabanlı
karşılaştırması.

**Çözüm iki parçalı:** (a) seçim artık `setState` etmiyor —
`ValueNotifier<Set<int>>`, yalnız karolar dinliyor; (b) ızgara widget'ı
`_gridCache` ile önbelleğe alınıp AYNI ÖRNEK döndürülüyor (Flutter aynı örneği
görünce alt ağacı hiç güncellemiyor). Önbellek yalnız `_rev` (belge baytı)
değişince tazeleniyor. `PdfPageView` de `ValueListenableBuilder`'ın `child`'ı
olarak veriliyor → seçim dokunuşunda pdfium render'ı tekrarlanmıyor.

### 3) Donma: ağır iş ana izlekteydi
- **PDF sıkıştırma:** Syncfusion belgeyi ana izlekte baştan yazıyor →
  saniyelerce kare yok → "donma"/ANR. `PdfTools.*InBackground` sarmalayıcıları
  eklendi (`Isolate.run`). **Neden ayrı statik metotlar:** ekran içinden yazılan
  kapanış `this`i (State + BuildContext) yakalar ve isolate'e GÖNDERİLEMEZ;
  statik metodun kapanışı yalnız yerel değişkenleri görür. Hata isolate
  sınırından okunabilir geçsin diye `PdfToolsException`'a çevriliyor.
  Ayrıca sıkıştırma artık **önce ne yapacağını anlatan bir onay** alıyor
  (taranmış belgede kazanç küçüktür — beklemeden önce bilinmeli).
- **Parolasız .zip (dosya yöneticisi):** şifreli/7z yolu zaten isolate'teydi ama
  EN SIK kullanılan düz `.zip` yolu (`ZipFileEncoder`) ana izlekteydi →
  `_zipSync` yazılıp `Isolate.run`'a alındı, ilerleme `SendPort` ile.
- **Test notu:** isolate kapanışlarının gönderilebilirliği DERLEMEDE
  yakalanmaz, yalnız çalışma anında patlar → `pdf_tools_test`e her arka plan
  sarmalayıcısını gerçekten koşturan testler eklendi.

### 4) Uzun süren işler artık arka plana alınabiliyor
"Çöp kutusu boşaltılırken başka işlem yapamıyorum" — sorun işin kendisi değil,
**modal ilerleme penceresiydi**. `showFmProgress`'e "Arka plana al" düğmesi
eklendi (pencere kapanır, iş sürer). Pencere kapanışı artık `showDialog`'un
`.then`'ine değil senkron bir `closed` bayrağına bağlı: geç gelen bir `pop`
yanlış sayfayı kapatabilirdi. Çöp ekranı sonucu bildirmek için Messenger'ı
işten ÖNCE yakalıyor (kullanıcı ekrandan çıkmış olabilir; MaterialApp
seviyesindeki Messenger ekrandan bağımsız yaşar).

### 5) Metin seçimi: mod zorunluluğu kaldırıldı
Kullanıcı "çok kullanışsız, normal metin seçer gibi olmalı" dedi. Eskiden
seçim için üst çubuktan "Metin seç" modunu açmak ZORUNLUYDU. Artık seçim
katmanı DAİMA sayfanın üzerinde: **uzun basış her zaman kelimeyi seçer**,
tutamaçlar aralığı büyütür, dokunuş temizler. Seçim yokken katman parmağı
yutmuyor (`HitTestBehavior.translucent` + sürükleme tanıyıcısı KURULMUYOR) →
sayfa normal kaydırılıyor ve köprüler çalışıyor. `onTapDown` yalnız seçim
varken bağlanıyor (yoksa köprü dokunuşlarını yerdi). "Sürükleyerek seç" modu
duruyor ama isteğe bağlı. Sayfa üstündeki ikinci "Kopyala" balonu kaldırıldı —
tek alt çubuk kaldı, tutamaçlar 48 px dokunma hedefine büyütüldü.

### 6) Uzun belgede gezinme
- **Sayfaya git:** sayfa rozetine dokun → numara + kaydırıcı.
- **2/4 sütun:** `PdfViewerParams.layoutPages` devralındı. Sütun genişliği
  belgenin EN GENİŞ sayfasına sabit, dar sayfalar ortalanır (kayan sütun
  okumayı zorlaştırır). **NOT:** paket belgesi "değişiklik için
  `PdfViewerController.relayout()` çağır" diyor ama o API 2.x'te; 1.3.5'te
  `_updateLayout` her build'de düzeni yeniden hesaplayıp karşılaştırıyor →
  `setState` yeterli.
- **Kaydırma çubuğu:** paketin `PdfViewerScrollThumb`'ı `viewerOverlayBuilder`
  ile eklendi, topuzun üstünde sayfa numarası yazıyor.

### 7) Kaydetme: üzerine yaz / kopyasını kaydet
`lib/services/pdf_save.dart` + `widgets/pdf_save_dialog.dart` — PDF Araçları,
imza ve AI düzenleme aynı soruyu soruyor. Kopya hedefi önce özgün klasör
("… (kopya).pdf", çakışırsa numaralı), oraya yazılamıyorsa Belgeler dizini.
Yazılabilirlik VARSAYILMIYOR, deneme dosyasıyla ÖLÇÜLÜYOR: paylaşımla gelen
dosya çoğu zaman başka uygulamanın önbelleğinde durur.

### 8) AI ile düzenleme — dürüst sınırla
`PdfAiEditScreen`: metin katmanı Gemini'ye gider, yönergeye göre yeniden
yazılır, sonuç ELLE düzenlenebilir, sonra PDF'e basılır.
**Bilinçli sınır:** üretilen PDF metin tabanlıdır, özgün sayfa düzeni (sütun,
tablo, logo, imza) KORUNMAZ — PDF içindeki metni yerinde değiştirmek gömülü
font alt kümelerini ve satır kırımlarını yeniden kurmayı gerektirir, cihaz-içi
/ücretsiz ilkesiyle makul sadakatte yapılamıyor. Bu ekranda da, kaydetme
penceresinde de açıkça yazıyor ve kopya yolu öne çıkarılıyor.

### 9) TUZAK (sessiz bozulma) — metin→PDF'te Türkçe karakterler
`pdf` paketinin varsayılan fontu Helvetica (base-14, WinAnsi); `ğ ş ı İ` bu
kodlamada YOK. Paket **hata atmıyor** — PDF üretiliyor ama o karakterler
yanlış çiziliyor. Görünmez OCR katmanında font zaten gömülüyordu, görünen
metin yolu atlanmıştı. `textToPdf`/`textToSlidesPdf` artık gömülü Carlito
temasıyla çalışıyor. Test "çökmedi mi"ye değil `/FontFile2` var mı + Helvetica
yok mu diye bakıyor (çökmediği için "çalışıyor" sanılabilirdi).

### 10) Tarama: tek boy kâğıt + köşe düzeltme
- **"Sayfalar tam oturmalı, düm düz olmalı":** her sayfa görselinin oranını
  alıyordu → arka arkaya çekilen sayfalar birkaç piksel farklı olduğu için
  PDF'te sayfa boyu zıplıyordu. `imagesToPdf(uniformPage: A4)` eklendi: sabit
  kâğıt, oran korunarak sığdırma (kırpma/esnetme yok), ortalama; yatay görselde
  kâğıt da yatay çevriliyor. OCR katmanının konumu da aynı ölçek/kayma ile
  taşınıyor.
- **"Köşelerinden tutup ayarlama":** `ScanReviewScreen` (tarama sonrası
  önizleme, sayfa silme) + `ScanEditScreen` (mavi dörtgen, 4 sürüklenebilir
  köşe) + `services/perspective.dart`.
  **Karar — görüntü işleme paketi EKLENMEDİ:** perspektif düzeltme
  `Canvas.drawVertices` + `ImageShader` ile GPU'da yapılıyor; hedef dikdörtgen
  24×24'lük bir üçgen ağına bölünüp her köşeye kaynak görseldeki karşılığı
  doku koordinatı olarak veriliyor (her üçgen içinde afin yaklaşıklık; ağ
  sıklığında hata gözle görülmez). Homografi çözümü (8×9 Gauss, kısmi
  pivotlama) SAF ve test edilmiş — çizim GPU gerektirdiği için testler
  matematiği hedefliyor, hata gerçekten oradadır (yanlışsa sayfa yamuk çıkar).

**Doğrulama:** Linux bulut oturumunda Flutter 3.29.3 (CI ile aynı) indirilip
`analyze` (0 error) + `flutter test` (459 test, hepsi yeşil) koşturuldu.

---

## 2026-07-26 (2. tur) — kalan maddeler: yerinde metin düzenleme, döndürme, kalıcı şerit

Birinci turun KALANLAR listesi kapatıldı. İki madde **bilinçli olarak açık
bırakıldı** (gerekçeleri aşağıda) — gerisi bitti.

### 1) "Vurgu /Rotate=0 varsayıyor" — YANLIŞ ALARM, ölçüldü
Kodda "döndürülmüş sayfada vurgu kayabilir" diye bir uyarı taşınıyordu. Dört
açının dördünde de yazılan `/Rect` **birebir aynı** çıkıyor. Sebep: iki taraf da
HAM (döndürülmemiş) sayfa uzayında konuşuyor — pdfium'un `charRects`'i ham
koordinat verir (`PdfRect.toRect` döndürmeyi kendisi uygular), Syncfusion'ın
yüklü sayfadaki `PdfPage.size`'ı ise ham CropBox/MediaBox ölçüsüdür (kaynak
okundu: `pdf_page.dart` yalnız kutu genişlik/yüksekliğini hesaplıyor).
Uyarı silindi, davranış `pdf_annotator_test` ile SABİTLENDİ (Syncfusion bir gün
`/Rotate`'i `size`'a yansıtırsa test kırmızıya döner ve bize haber verir).
**Ders:** "olabilir" diye taşınan şüpheyi ya ölç ya sil; kodda duran yanlış
uyarı, gerçek bir hatayı ararken yanlış yere baktırıyor.

### 2) Yerinde metin düzenleme — AI düzenlemenin düzeni koruyan hâli
`PdfTools.replaceText` + `PdfTextReplaceScreen`: seçili satırların üstü düz
renkle kapatılıp yerine yeni metin yazılıyor. Sayfanın geri kalanı (tablo, logo,
sütun, diğer paragraflar) **hiç dokunulmadan** kalıyor. Metin elle ya da
Gemini'yle düzenlenebiliyor. Giriş: PDF seçim çubuğundaki "Düzenle".
`PdfAiEditScreen` (tüm belgeyi yeniden yazan, düzeni kaybeden yol) duruyor —
ikisi farklı işler, ekranlarda hangisinin ne yaptığı yazılı.

**TUZAK (ölçüldü, sessiz veri kaybı) — `drawString`'e DAR bir `bounds`
verilirse Syncfusion HİÇBİR ŞEY çizmez, hata da atmaz.** Kutu yüksekliği
satır yüksekliğine tam eşit/az geldiğinde çıktıda ne yazı ne font kalıyor
(ölçüm: `out=1087 bayt, /FontFile2 yok, Tm operatörü 0`). Kullanıcı için bu
"düzenledim, yazım kayboldu" demek. Çözüm: `bounds` yüksekliği **0** (sınırsız)
veriliyor — sarma genişliğe göre yapılıyor, sığmayan metin kaybolmak yerine
biraz taşıyor. Ayrıca `fitFontSize` toleransı (eski `+0.5pt`) kaldırıldı;
tam sınırdaki metin bu bollukla kabul edilip sonra çizim aşamasında yok
oluyordu.

**TUZAK (test yöntemi) — `PdfTextExtractor` yüklü sayfaya SONRADAN eklenen
içerik akışını okumuyor.** İlk testler bu yüzden "yazı eklenmemiş" diyordu;
oysa PDF'in içinde duruyordu (sıkıştırılmamış çıktıda `(YENI)'` operatörü
görüldü). Testler artık içerik akışlarını `ZLibDecoder` ile açıp operatörlere
bakıyor. **Ders:** bir doğrulama aracının sessizce eksik davranması, kodu
"bozuk" göstermeye yeter — aracı da doğrula.

**Bilinçli sınırlar (ekranda da yazılı):** yazı tipi belgenin kendi fontu değil
gömülü Carlito (PDF fontları genelde yalnız kullanılan harfleri içeren alt küme
olarak gömülür, yeni harf için glif yok); arka plan düz renk varsayılıyor.

### 3) Taramada döndürme + ortak yardımcılar
`Perspective.rotateToPng` (kanvasla 90° adımlar) ve tarama önizlemesinde çevirme
düğmesi. Görsel açma/geçici PNG yazma iki ekranda kopyalanmıştı → `decodeImageFile`
ve `writeTempPng` olarak `perspective.dart`'a alındı.
Çizim yolu artık **piksel düzeyinde** test ediliyor (`perspective_render_test`):
sol yarısı kırmızı/sağ yarısı mavi bir görsel warp/rotate edilip çıktının doğru
pikselleri okunuyor. Matematik testleri "boş görüntü" hatasını yakalayamazdı.

### 4) Arka plana alınan iş için kalıcı şerit
"Arka plana al" dendiğinde ekranın altında **kalıcı** bir ilerleme şeridi kalıyor
(süresi 1 gün, iş bitince elle kaldırılıyor) — üzerinde iş adı, "3/128" sayacı ve
"Durdur". Messenger MaterialApp seviyesinde olduğu için kullanıcı başka sayfaya
geçse de şerit görünür kalıyor.

### AÇIK BIRAKILANLAR (gerekçeli)
- **Agresif sıkıştırma (sayfaları resme çevirip küçültme) YAPILMADI.** Yol açık
  değil: cihazda JPEG **kodlayıcı** yok — `dart:ui` yalnız PNG üretir, PNG ise
  taranmış sayfada özgün JPEG'den BÜYÜK çıkar, yani "sıkıştır" dosyayı
  şişirirdi. Yapılabilmesi için `image` paketi (yeni bağımlılık, saf Dart ve
  yavaş) ya da platform kanalı gerekir. Bilerek yapılmadı; yapılırsa metin
  katmanı kaybolacağı için ayrı ve açıkça uyaran bir seçenek olmalı.
- **graphify güncellemesi yapılamadı:** araç bu ortamda kurulu değil
  (`command -v graphify` boş). Yeni düğümler grafta eksik kalıyor.

---

## 2026-07-26 (3. tur) — PDF metnini GERÇEKTEN yerinde düzenleme

**İstek:** "PDF içindeki yazıları Word'de çalışır gibi silip yeniden
yazabilmeliyim, PDF'in yapısı hiçbir şekilde bozulmamalı."

2. turdaki `PdfTools.replaceText` bunu KARŞILAMIYORDU: eski yazının üstünü
boyayıp yenisini üste çiziyordu. Üç kusuru vardı ve üçü de kullanıcının
farkedeceği türdendi — (a) eski metin belgede kalıyor, kopyalayınca/arayınca
çıkıyor, (b) desenli zeminde kapatma kutusu görünüyor, (c) yazı tipi değişiyor.
Bu tur asıl çözüm yazıldı; eski yol yalnız YEDEK olarak duruyor.

### Yaklaşım
Sayfanın **içerik akışındaki** metin operatörünün (`Tj/TJ/'/"`) dizesi
değiştiriliyor. Yazı tipi, punto, konum, renk, grafik durumu — hiçbirine
dokunulmuyor, dolayısıyla korunuyorlar. Eski metin gerçekten siliniyor.

Üç katman (hepsi cihazsız test edilebilir):
- `services/pdf/pdf_syntax.dart` — içerik akışı tarayıcısı + kodlama tabloları.
- `services/pdf/pdf_text_replace.dart` — akış içinde bul/değiştir (saf).
- `services/pdf/pdf_objects.dart` — nesne tarama, ObjStm, sayfa ağacı, yazma.
- `services/pdf_content_editor.dart` — orkestrasyon + doğrulama.

### KARAR — özgün baytlara asla dokunulmuyor (incremental update)
Değişiklik dosyanın SONUNA ekleniyor; eski sürüm bayt bayt yerinde kalıyor ve
yeni bir xref bölümü üstüne yeni nesneyi bindiriyor. Bu PDF'in kendi güncelleme
mekanizması. *Niye:* belgeyi baştan yazmak çok daha kolaydı ama her yeniden
yazma, ANLAMADIĞIMIZ her yapıyı (imza, form, gömülü dosya, işaretli içerik)
kaybetme riski demek. Test bunu bayt karşılaştırmasıyla sabitliyor.

### TUZAK — taban dosya xref AKIŞI kullanıyorsa güncelleme de akış olmalı
PDF 1.5+ (Word/LibreOffice çıktısı) çapraz başvuruyu akış olarak yazar. Oraya
klasik `xref` tablosu eklemek "hibrit" bir dosya üretir ve birçok okuyucu
reddeder. `_appendXref` tabanın biçimine bakıp ikisinden birini yazıyor.
Elle kurulan modern-yapı PDF'iyle test ediliyor (Syncfusion bu biçimi
ÜRETMEDİĞİ için başka türlü hiç denenmezdi — oysa kullanıcının düzenleyeceği
belgelerin çoğu tam olarak bu biçimde).

### TUZAK — sayfa sözlükleri `/ObjStm` içinde olabilir
Modern üreticiler sayfa sözlüklerini sıkıştırılmış nesne akışına koyar; açmadan
sayfa ağacı yürünemez ve her yeni belgede pes edilirdi. `_expandObjectStreams`
bunları açıyor. **Akışlar ObjStm'e KONULAMAZ** (PDF kuralı) → içerik akışı hep
üst seviyededir, onu doğrudan buluyoruz.

### Arama neden "boşluksuz" ve neden bağlamlı
- PDF'te bir cümle kerning yüzünden onlarca parçaya bölünür ve kelime araları
  çoğu zaman boşluk KARAKTERİ değil, kerning SAYISIDIR. Boşluğa takılan bir
  arama gerçek belgelerde neredeyse hiç eşleşmez → boşluklar yok sayılıyor.
- Aynı kelime sayfada birkaç kez geçebilir. Seçimden önceki 40 karakter
  bağlam olarak taşınıyor (`PdfSelectLayer` → ekran → servis); önce
  `bağlam+kelime` aranıyor, bulunmazsa sade aramaya düşülüyor. Bu olmasa
  kullanıcı ikinci geçişi seçse bile birincisi değişirdi.

### Güvenlik kapıları — hepsi "yazmadan önce reddet"
Şifreli belge (dizeler şifreli, düz yazmak bozar) · sayfa ağacı yürünemiyor ·
metin bulunamıyor (alt küme font / taranmış sayfa) · yeni harf fontun
kodlamasında yok · **içerik akışı birden çok sayfada ORTAK** (antet
sayfalarında olur; düzenlemek dokunulmayan sayfayı da değiştirirdi).
Yazdıktan SONRA belge yeniden açılıp doğrulanıyor: sayfa sayısı, hedef
sayfanın gerçekten değiştiği, diğer sayfaların değişmediği. Doğrulama düşerse
sonuç ATILIR.

### Kodlama
Font sözlüğünü ayrıştırmıyoruz. Aday tek baytlık kodlamalar (WinAnsi/CP1252,
CP1254, Latin-1) sırayla denenip **kullanıcının seçtiği metni bulabilen**
kodlama geçerli sayılıyor — eşleşmenin kendisi doğrulama. Yeni metin aynı
kodlamayla yazılıyor; tek karakter bile karşılanamıyorsa işlem reddediliyor
(yarım yazmak belgeyi bozar). Özel `/Differences` ya da CID (Identity-H)
fontlarda eşleşme olmaz → yedek yola düşülür.

### Bilinen sınır (bilinçli)
Yeni metin uzunsa satırın kalanı sağa kayar — PDF metni yeniden akıtmaz.
Bu Word'de de olan davranış (yazınca gerisi itilir), o yüzden hata değil;
ama sütun/tablo hizasını bozabileceği ekranda yazıyor.

**Doğrulama:** analyze 0 hata, 508 test yeşil. Yerinde düzenleme için 37 test:
uçtan uca (metin değişir, eski metin KALMAZ, özgün baytlar korunur, üst üste
düzenleme), modern yapı (ObjStm + xref akışı), sözdizimi (kaçışlar, onaltılık
dize, satır içi görselin ikili verisi, yorum), parçalı metin, kodlama ve tüm
güvenlik kapıları.

---

## 2026-07-26 (4. tur) — KÖK NEDEN: gerçek belgelerde yerinde düzenleme neden çalışmıyordu

**Bulgu (kullanıcı, ekran görüntüsüyle):** resmî bir belgede (EBYS çıktısı,
iki yana yaslı, Times benzeri gömülü font) düzenleme sonrası "yazı tipi ve
form düzeni bozuluyor". Ekran görüntüsündeki alt yazı: **"Metin üste yazıldı"**.

**Teşhis buradan çıktı.** Yerinde düzenleme (3. tur) o belgede REDDEDİLMİŞ ve
yedek yola (üstünü kapatma) düşülmüştü. Bozulmanın sebebi yedek yolun kendisi:
farklı font + satırın ortasını kapatıp sola yaslı yeniden yazma → iki yana
yaslı satırda ortada boşluk. Yani hata "düzenleme bozuyor" değil, **"asıl
düzenleme hiç çalışmıyor"**du.

### Neden reddediliyordu
3. turda kodlama, aday **tek baytlık** tablolarla (WinAnsi/CP1252, CP1254,
Latin-1) tahmin ediliyordu. Gerçek belgelerin yazı tipleri **alt küme gömülü**
ve çoğu zaman **Type0/Identity-H**: harf başına 2 baytlık, fonta özgü keyfi
glif numarası. Böyle bir belgede tek baytlık tablo HİÇBİR ZAMAN tutmaz →
"metni bulamadım" → yedek yol. Yani özellik, en çok düzenlenecek belgelerde
tam olarak çalışmıyordu.

### Çözüm — fontun kendi `/ToUnicode` tablosu
`services/pdf/pdf_font_map.dart`: PDF'in içinde taşınan "bu kod şu harftir"
tablosu okunup **ters çevriliyor**. Metni kopyalanabilen her belgede bulunur
(pdfium da bunu kullanır). Böylece:
- alt küme gömülü ve Identity-H fontlar çözülüyor,
- yeni metin belgenin **ÖZGÜN yazı tipiyle** yazılıyor.
Sayfanın font kaynakları `PdfFile.fontEncodings` ile bulunuyor; `/Resources`
sayfada yoksa `/Parent` zinciri yukarı yürünüyor — **miras atlanırsa gerçek
belgelerin çoğunda font hiç bulunamaz** (üreticiler kaynakları `/Pages`
düğümüne bir kez yazar).

Tek baytlık tablolar YEDEK olarak duruyor (basit fontlu eski belgeler).

**Sınır (dürüst):** alt küme font yalnız belgede GEÇEN harfleri taşır. Hiç
geçmemiş bir harf yazılmak istenirse reddediliyor — o glif yok, basılsaydı
boş/yanlış çıkardı.

**Test:** Syncfusion Type0/Identity-H font üretmediği için böyle bir belge
elle, bayt bayt kuruldu (`pdf_font_map_test`): 2 baytlık glif kodları,
`/ToUnicode` CMap'i, kaynakların üst düğümden miras alınması. Ayrıca CMap
ayrıştırıcısının `bfchar`, `bfrange` (ardışık ve dizi biçimi) ve tek/çift
baytlık codespace halleri.
**Test tuzağı:** ilk kurulumda sahte fontun alt kümesi yalnız o cümlenin
harfleriydi; kod doğru davranıp "harf fontta yok" dedi ve test kırmızı oldu.
Hata kodda değil kurgudaydı — gerçek belgede alfabenin tamamı bulunur.

### Kaydetme akışı tek yerde toplandı (kullanıcı isteği)
"Kopyasını kaydettiğinde nereye gittiğini bulmak çok zor, hemen açabilmeliyim
ve nereye kaydedileceğini seçebilmeliyim."
`widgets/pdf_save_dialog.dart` → `savePdfWithChoice`: **üzerine yaz / kopyasını
kaydet / klasör seçerek kaydet**, ardından dosya adı + KLASÖR yolu gösteren ve
**"AÇ"** düğmesi taşıyan bir bildirim. PDF araçları, imza, AI düzenleme ve
yerinde metin düzenleme artık aynı yolu kullanıyor — ayrı ayrı yazıldığında
biri "aç"ı unutuyordu.
Ayrıca **kaydetme sorusu en sona alındı**: değişiklik üretilmeden "nasıl
kaydedelim?" diye sorup sonra başarısız olmak kötüydü.

### Düzenleme ekranında uzunluk uyarısı
PDF metni Word gibi yeniden akıtmaz. Yeni metin uzunsa satırın kalanı kayar.
Ekran artık yazarken canlı uyarıyor (2 karakterden büyük farkta), yedek yol
penceresi de "iki yana yaslı metinde satır hizası bozulur" diyor.

**Doğrulama:** analyze 0 hata, 519 test yeşil.

## 2026-07-26 — PDF düzenleme 5. tur: satır yeniden hizalama + sayfa üzerinde yazma
Kullanıcı: *"PDF düzenleme olayını üst seviyelere taşımalıyız, formatı hiç
bozmadan sanki o PDF'ye aitmiş gibi düzenleme yapabilmeliyiz; yazılar yeni
duruma göre yeniden hizalanmalı, Word belgesi düzenler gibi; sayfa üzerinde
yeni bir alan açılmadan klavyeden değişiklik yapabilmeliyim, sanki orijinali
oymuş gibi olmalı."*

Üç ayrı eksik vardı ve üçü de bu turda kapandı.

### A) Satır artık yeniden hizalanıyor (asıl istek)
**Sorun:** yerinde düzenleme metni değiştiriyordu ama PDF'te bir satır çoğu
zaman ayrı ayrı KONUMLANDIRILMIŞ parçalardan oluşur (`Tm`/`Td` ile). Kelime
uzayınca sonraki parça yerinde kalıp üstüne biniyor, kısalınca arada boşluk
kalıyordu. KALANLAR'da "PDF metni yeniden akıtmaz" diye bilinen sınır buydu.

**Çözüm iki parçalı:**
1. **Ölçü** — `services/pdf/pdf_font_metrics.dart`: belgenin KENDİ glif
   genişlik tabloları (basit fontta `/FirstChar` + `/Widths`, Type0/CID fontta
   alt fontun `/W` + `/DW`). Tahmin yok; tablosu olmayan font ölçülmez ve o
   zaman hiç kaydırma yapılmaz.
2. **Kaydırma** — `pdf_syntax.dart` artık içerik akışını yalnız metin
   operatörleri için değil, **tam metin durumu ve matrisiyle** tarıyor
   (`scanContent`: `Tm/Td/TD/T*/Tf/Tc/Tw/Tz/TL`, her sayının bayt aralığıyla).
   `pdf_text_replace.dart` genişlik farkını hesaplayıp satırın kalanındaki
   konumlandırma sayılarını yerinde düzeltiyor.

**Kaydırma kuralı (bu kural yanlış olsaydı kayma iki katına çıkardı):**
mutlak `Tm` her seferinde kaydırılır (kendi başına konum belirler); göreli
`Td/TD` yalnız BİR kez — sonrakiler zaten kaymış satır matrisine göre çalışır.

**Kaydırmanın YAPILMADIĞI durumlar (hepsi bilinçli):** döndürülmüş/eğik metin
matrisi, eşleşmenin ortasında konumlandırma operatörü olması, ölçülemeyen font,
farklı satır (`|Δy| > 0.34 × satır yüksekliği`), düzenlemenin SOLUNDA kalan
metin (üreticiler metni sırasız yazabiliyor).

**Taşma uyarısı:** hizalamadan sonra satır sağa taşıyorsa kullanıcı KAYDETMEDEN
önce uyarılıyor. Sağ sınır ölçülerek tahmin ediliyor (en soldaki metin = kenar
boşluğu, sayfa simetrik varsayılıyor) — tahmin olduğu için işlemi iptal
etmiyor, yalnız söylüyor.

### B) Özgün baytlara sadakat arttı — `TJ` kerning'i artık korunuyor
**Bulunan sessiz hata:** eskiden eşleşen operatörün TÜM operandı yeniden
yazılıyordu, yani `[(Sağ) -15 (lık Bakanlığı)] TJ` tek bir `[(…)]`'e
indirgeniyordu. Metin doğruydu ama **harf aralıkları siliniyordu** — "sayfaya
hiç dokunulmadı" sözü tam doğru değildi. Artık yalnız eşleşmenin dokunduğu
DİZE yeniden yazılıyor; dizi yapısı, kerning sayıları ve öteki dizeler baytı
baytına kalıyor. Onaltılık dize onaltılık kalıyor (`writeStringLike`) —
Identity-H metni belgelerde hep onaltılıktır.
Yan fayda: `'` ve `"` operatörlerinin sayıları için özel kod gerekmedi, tek
dizeleri olduğu için kendiliğinden korunuyorlar.

### C) Düzenleme artık sayfa ÜZERİNDE (ayrı ekran kaldırıldı)
`widgets/pdf_inline_editor.dart`: seçili metnin TAM ÜSTÜNDE, aynı satır
yüksekliğinde bir kutu açılıyor; metin baştan seçili geliyor, klavye hemen
çıkıyor, üstündeki küçük çubukta vazgeç / AI ile düzelt / uygula var.
`screens/pdf_text_replace_screen.dart` **silindi**; uygulama mantığı
`services/pdf_edit_flow.dart`'a, AI yeniden yazımı
`widgets/ai_rewrite_sheet.dart`'a taşındı (düzenleme kutusu kaybolmadan açılan
alt sayfa).
- Kutu **opak beyaz**: altında sayfanın çizilmiş hâli duruyor, saydam bıraksak
  eski yazı yenisinin altından okunurdu. Gece modunda sayfayla birlikte
  terslendiği için uyum bozulmuyor.
- Yerinde düzenleme açıkken `PdfSelectLayer` HİÇ kurulmuyor — kutunun içindeki
  dokunuşları yutar, imleç konumlandırılamazdı.
- Tek satırlık metinde klavyenin "bitti" tuşu doğrudan uyguluyor.

### Yapı: `pdf_dict.dart` ayrıldı
`pdfName/pdfInt/pdfNum/pdfRef/pdfRefArray/pdfArray` `pdf_objects.dart`'tan
çıkıp kendi dosyasına taşındı (oradan `export` ediliyor, çağrı yerleri aynı).
Sebep: `pdf_font_metrics.dart` bunlara ihtiyaç duyuyordu ve `pdf_objects` ↔
`pdf_font_metrics` çevrimsel import'u istemedik.
**TUZAK (düzeltildi):** eski `pdfRefArray` `[^\]]*` ile dizi okuyordu; `/W`
gibi İÇ İÇE dizilerde yarıda kesiyordu. Yeni `pdfArray` köşeli parantez
derinliği sayıyor.

### Neden ekstra bir "doğrulama" eklenmedi
Yazdıktan sonraki doğrulama (sayfa sayısı + metin karşılaştırması) duruyor.
Geometrik bir doğrulama (satır kutularını Syncfusion'la karşılaştırmak) düşünüldü
ama EKLENMEDİ: hizalama yalnız yatay sayı değiştiriyor, dikey konum hiç
değişmiyor; buna karşılık metin değişince Syncfusion'ın satır bölmesi farklı
çıkabilir ve **yanlış yere reddetme** üretirdi. Yatay risk zaten taşma
uyarısıyla ölçülüyor.

**Doğrulama:** `flutter analyze` 0 hata, **559 test yeşil** (+40).
Yeni testler: `pdf_font_metrics_test` (her genişlik biçimi + varsayılanlar +
ölçülemeyen font), `pdf_reflow_test` (kesin sayılarla kaydırma, kaydırılmayan
durumlar, kerning/onaltılık/`'`/`"` korunması, taşma), `pdf_inplace_edit_test`
(uçtan uca: elle kurulmuş belge → düzenle → çıkan akıştaki `Tm` sayısını oku).

## 2026-07-26 — PDF düzenleme 6. tur: kaydırma/zoom bugı, dokunulamayan düğmeler, bekleyen kayıt

Kullanıcı bulguları (iki ekran görüntüsüyle): *"sayfayı kaydıramıyorum zoom
yapamıyorum"*, *"x, onay, ai işaretlerine tıklanmıyor"*, *"sayfaya git 8
yazıyorum 2'ye gidiyor"*, *"her seferinde kaydet diye sormasın"*, *"kelime
aralarında çıkan koyuluklar göz yoruyor"*, *"metin düzeltme hâlâ istediğimiz
seviyede değil — punto sanki o yazıya aitmiş gibi olmalı"*.

### A) KÖK NEDEN — "sayfayı kaydıramıyorum, zoom yapamıyorum"
Suçlu, üst çubuktaki **"sürükleyerek seç" modu**ydu. Açıkken
`panEnabled: false` veriliyor ve `PdfSelectLayer` `HitTestBehavior.opaque`
oluyordu → parmak katmanda kalıyor, sayfa ne kayıyor ne yakınlaşıyordu.
Kullanıcı modu açıp kapatmayı unutunca uygulama "bozuk" görünüyordu (ekran
görüntüsündeki el simgesi modun açık olduğunu gösteriyor).
**Karar: mod TÜMÜYLE kaldırıldı.** Zaten kullanıcı bir tur önce "mod açmak
kullanışsız" demişti; uzun basış + basılı sürükleme seçim için yetiyor.
Katman artık DAİMA translucent, `panEnabled` hep true.

**İkinci (gizli) kaynak — pinch'i yiyen uzun basış:** katman sayfanın üstünde
durduğu için her dokunuşta gesture arenasına giriyor. İki parmak inip yarım
saniye kıpırdamazsa `LongPressGestureRecognizer` arenayı kazanıyor ve pdfrx'in
ölçek tanıyıcısı eleniyordu → yakınlaştırma hiç başlamıyor. Çözüm:
`_PageLongPress` (RawGestureDetector ile kurulan alt sınıf) **ikinci parmak
inince `resolve(rejected)`** diyor. İki parmak = "yakınlaştırıyorum" demek.

### B) KÖK NEDEN — düzenleme kutusundaki x / AI / onay düğmelerine basılamıyor
pdfrx'in köprü katmanı (`linkHandlerParams` verilince kurulan
`_CanvasLinkPainter.linkHandlingOverlay`) **tüm görüntüyü kaplayan** translucent
bir `GestureDetector`'dır ve Stack'te sayfa katmanlarının ÜSTÜNDEdir. Hit-test
yolunda bizden ÖNCE geldiği için `TapGestureRecognizer`'ı arenaya önce giriyor;
kimse erken kazanmayınca `GestureArenaManager.sweep()` **ilk üyeyi** seçiyor →
her tap köprü katmanına gidiyor, `pageOverlaysBuilder` içindeki hiçbir düğme
ateşlenmiyordu. (Metin kutusunun kendisi çalışıyordu: metin alanı tanıyıcısı
erken kazanıyor. Bu yüzden hata "yazabiliyorum ama kaydedemiyorum" gibi
görünüyordu.)
Çözüm: **yerinde düzenleme açıkken `linkHandlerParams: null`** — o sırada
köprüye zaten gerek yok. Aynı sebeple `PdfSelectLayer`'ın "dokununca seçimi
temizle" davranışı `onTapDown`'dan **`Listener.onPointerDown`**'a taşındı
(tap arenayı kaybediyordu, pointer olayı kaybetmez).

### C) KÖK NEDEN — "8 yazıyorum 2'ye gidiyor"
"Sayfaya git" kutusu güncel sayfayla dolu açılıyordu ama metin **seçili
gelmiyordu**. 2. sayfadayken 8'e basınca yazı `28` oluyor; aralık dışı olduğu
için `onChanged` hedefi güncellemiyor, "Git" ise kutuyu değil eski hedef
değişkenini okuyordu → 2. sayfa. Düzeltme: metin seçili açılıyor **ve** "Git"
doğrudan kutudaki sayıyı okuyup 1..sayfa sayısı arasına kısıyor.

### D) Yerleşim: gece modu üç noktaya, "sayfaya git" aramanın içine
Kullanıcı isteği. Üst çubuk artık: sayfa düzeni · içindekiler · (bekleyen
değişiklik varsa kaydet) · ara · üç nokta. "Sayfaya git" arama çubuğunun
başındaki düğme (alt kenardaki sayfa rozetine dokunmak da hâlâ açıyor).

### E) Kaydetme artık her düzenlemede DEĞİL, en sonda
Kullanıcı: *"canlı metin düzenlerken her seferinde kaydet diye sormasın; en
sonda kaydetmek istenirse nasıl kaydedileceği sorulsun ve kopyası
kaydedilsin, çıkarken de kaydetmek ister misiniz diye sorulsun."*
- `PdfEditFlow.apply` artık **kaydetmiyor**: yeni baytları (`PdfEditApplied`)
  döndürüyor.
- Baytlar geçici bir **çalışma kopyasına** yazılıyor (`_pdfWorkPath`,
  `Directory.systemTemp` altında, dosya adı özgün adla aynı) ve görüntüleyici
  o dosyayı gösteriyor. **Özgün belgeye kullanıcı "üzerine yaz" diyene kadar
  HİÇ dokunulmuyor** — uygulama çökse bile bozulmaz. Vurgulama da aynı yola
  bağlandı (eskiden sessizce özgün dosyanın üstüne yazıyordu).
- Çıkışta `PopScope` "Kaydet / Kaydetme / Vazgeç" soruyor; `savePdfWithChoice`
  (üzerine yaz / kopya / klasör seç) yalnız burada bir kez çalışıyor.
- İmza, PDF araçları ve AI düzenleme ÖZGÜN dosyada çalıştığı için önce aynı
  soruyu soruyor (yoksa bekleyen düzenlemeler sessizce kaybolurdu).
- *Niye ilk düzenlemede sayfa zıplıyor:* pdfrx belgeleri **yola** göre
  önbellekliyor; yol değişimi gerçek bir yeniden yükleme. `initialPageNumber`
  güncel sayfayı verdiği için kullanıcı aynı sayfada açılıyor, sonraki
  düzenlemeler `PdfReload` ile hiç zıplamadan tazeleniyor.

### F) Seçim vurgusundaki koyu şeritler
PDF üreticileri satırı kelime kelime (bazen harf harf) ayrı parçalara böler.
Her parça ayrı yarı saydam dikdörtgen olarak boyanıyor, `inflate(1.5)`
yüzünden komşu parçalar örtüşüyor ve **örtüşen yerler iki kat koyu** çıkıyordu
— kullanıcının "kelime aralarındaki koyuluklar" dediği şey bu.
İki katmanlı çözüm: (1) `selectionPdfRects` artık aynı satırdaki parçaları tek
dikdörtgende **birleştiriyor** (`mergeSameLineRects`, satır yüksekliğinin
yarısından çok örtüşme = aynı satır); (2) boyama tek `Path` ile yapılıyor, yani
kalan örtüşmeler bile rengi ikiye katlayamıyor. Alfa 0.35 → 0.28.
Yan fayda: kalıcı vurgu annotation'ı da satır başına tek dikdörtgen alıyor.

### G) Düzenleme kutusunun puntosu artık ÖLÇÜLÜYOR
Eskiden punto = karakter kutusu yüksekliği × sabit katsayı (0.82). Katsayı
belgeden belgeye tutmuyordu (dar/geniş fontlarda gözle görülür kayıyordu) —
kullanıcının "sanki o yazıya aitmiş gibi olmalı" bulgusu buydu. Artık:
özgün metin `TextPainter` ile ölçülüp **seçimin ekrandaki genişliğini verecek**
puntoya oturtuluyor (oran 0.7–1.4 arasına kısılı: tek harflik/çok boşluklu
seçimde ölçüm yanıltabilir). Ayrıca kutunun çerçevesi kalktı (yalnız ince alt
çizgi), `contentPadding` sıfırlandı ve `strutStyle` ile satır yüksekliği
puntoya eşitlendi → yazı özgün satırın tam üstüne oturuyor.
**Not (açık madde):** yerinde düzenleme reddedilip "üste yaz" yedeğine
düşülürse yazı tipi hâlâ gömülü Carlito oluyor. Belgenin kendi gömülü fontunu
çıkarıp yeniden gömmek ayrı bir tur işi.

**Doğrulama:** Flutter 3.29.3 (CI ile aynı) — `flutter analyze` 0 hata / yeni
uyarı yok, **563 test yeşil** (+4). Yeni test: `pdf_selection_rects_test`
(satır birleştirme: aynı satır tek kutu, ayrı satırlar ayrı, bozuk kutu elenir).
Zoom/kaydırma ve dokunma sırası düzeltmeleri **gerçek cihazda** doğrulanmalı —
gesture arenası widget testinde birebir taklit edilemiyor.

## 2026-07-26 (7. tur) — "Belge parolalı/şifreli" uyarısı: izin kilitli PDF'ler

Kullanıcı bulgusu (sigorta poliçesi PDF'i, ekran görüntüsü): metni düzenlemeye
kalkınca **"Yerinde düzenleme yapılamadı — Belge parolalı/şifreli"** çıkıyor ve
tek seçenek "üste yaz" oluyor (yazı tipi Carlito'ya düşüyor).

**KÖK NEDEN — "şifreli" ile "parolalı" aynı şey değil.** Poliçe, fatura,
e-devlet çıktısı gibi belgelerin çoğunda `/Encrypt` VARDIR ama **kullanıcı
parolası boştur**: üretici yalnız yazdırma/kopyalama iznini kısıtlamıştır
(sahip parolası). Belge parola sorulmadan açılır — pdfium da öyle açıyor, o
yüzden kullanıcı belgesini "şifreli" saymıyor. `PdfFile.isEncrypted` yalnız
`/Encrypt` var mı diye baktığı için bu belgeleri de reddediyorduk ve kullanıcı
en kötü yola (üste yazma) mahkûm oluyordu.

**Çözüm — kurtarma yolu, ödev değil.** Eski mesaj "önce PDF araçlarından
parolayı kaldırın" diyordu; bu kullanıcıya ekran değiştirtip geri getiriyordu.
Artık:
- `PdfEditRefused` bir **`encrypted`** bayrağı taşıyor (isolate sınırından da
  geçiyor) — akış reddin sebebini ayırt edebiliyor.
- Sebep şifreyse `PdfEditFlow` tek soruyla korumayı kaldırmayı öneriyor
  (`PdfTools.removePasswordInBackground(currentPassword: '')`) ve **yerinde
  düzenlemeyi yeniden deniyor**. Böylece yazı tipi/punto belgenin kendisi
  kalıyor.
- Boş parola tutmazsa (gerçek kullanıcı parolası varsa) açıklamalı bir redde
  düşülüyor, oradan da "üste yaz" yedeği öneriliyor.
- Özgün dosya değişmiyor: koruma yalnız 6. turda gelen **çalışma kopyasında**
  kalkıyor, kaydetme biçimini kullanıcı çıkarken seçiyor. İki değişiklik
  birbirini tamamladı.

**TUZAK:** koruma kaldırma Syncfusion'ın tam yeniden yazımıdır
(`incrementalUpdate = false`) — artımlı güncelleme sözü o belge için bozulur.
Kullanıcıya söyleniyor (onay penceresinde madde madde).

**Doğrulama:** `pdf_encrypted_edit_test` — sahip parolalı (kullanıcı parolası
BOŞ) belge kuruluyor; (a) red gerçekten `encrypted: true` ile geliyor,
(b) boş parolayla koruma kalkıyor ve yerinde düzenleme metni gerçekten
değiştiriyor, (c) şifresiz belgedeki başka bir red `encrypted: false` kalıyor
(kurtarma yanlış yerde tetiklenmesin). `flutter analyze` 0 hata,
**566 test yeşil** (+3).

## 2026-07-26 (8. tur) — GERİ ALMA: "sayfa kaynıyor, zoom gidiyor" — kendi eklediğimiz koruma bozmuş

Kullanıcı bulgusu: *"PDF üzerinde değişiklik yapmaya çalıştıktan sonra uygulama
kararsızlaşıyor, zoom yapamamaya başlıyor, sayfa kaynamaya başlıyor."*

### A) KÖK NEDEN — 6. turda eklenen "iki parmak koruması" ters tepti
6. turda uzun basışın pinch'i yemesini önlemek için `RawGestureDetector` +
`_PageLongPress` (parmak sayan uzun basış tanıyıcısı) eklenmişti. İki kusuru
vardı ve ikisi de üretimde ortaya çıktı:

1. **Sayaç sayfa başına tutuluyordu.** `PdfSelectLayer` her sayfa için ayrı
   kuruluyor; iki parmak farklı sayfaların katmanlarına (ya da biri kenar
   boşluğuna) düşünce hiçbir katman "iki parmak" görmüyor, koruma çalışmıyordu.
2. **Sayaç TAKILI kalabiliyordu.** Parmak yerdeyken belge yeniden yüklenirse
   (düzenlemeden sonra tam da bu oluyor) katman yok edilir, `onPointerUp` hiç
   gelmez, sayaç ≥1 kalır. Sonrasında HER dokunuşta `resolve(rejected)`
   çağrılıyor; arenada tek üye kalınca **pdfrx'in kaydırma tanıyıcısı daha
   pointer-down anında kazanıyor**, yani kayma toleransı (slop) devre dışı
   kalıyor: en ufak parmak titremesinde sayfa kayıyor. Kullanıcının "sayfa
   kaynıyor" dediği şey bu.

**Karar: geri alındı.** Seçim katmanı 5. turdaki sade `GestureDetector`
biçimine döndü (translucent + uzun basış + seçim varken dokununca temizle).
Uzun basışın pinch'i yeme riski TEORİK olarak duruyor (kullanıcı iki parmağını
yarım saniye hiç kıpırdatmazsa) ama ölçülen zarar sıfır; koruma girişiminin
zararı ise gerçekti. *Ders: gesture arenasına müdahale eden koruma, ancak
tüm görüntüyü gören TEK bir yerden yapılabilir — sayfa başına kurulan
katmandan yapılamaz.*

### B) Düzenleme çubuğu artık ekranın altında (köprü katmanı hiç kapanmıyor)
7. turda "x/onay/AI'ye basılamıyor" sorunu, düzenleme açıkken
`linkHandlerParams`'ı null yaparak çözülmüştü. Çalışıyordu ama düzenleme her
açılıp kapandığında `PdfViewerParams` değişiyordu. Çubuk artık pdfrx'in
TAMAMEN dışında, `_buildBody`'nin kendi Stack'inde (seçim çubuğuyla aynı yer):
dokunuşu doğal olarak ilk o alıyor, köprü hiç kapatılmıyor, çubuk sayfa
kenarında kırpılmıyor ve klavyenin üstünde duruyor.
Metin kutusu sayfa katmanında kaldı — o zaten çalışıyor (metin alanı
tanıyıcısı arenayı erken kazanıyor). `TextEditingController` `ViewerScreen`'e
taşındı ki kutu ile alttaki çubuk aynı metni görsün.

### C) Yakınlaştırma yeniden yüklemede sıfırlanıyordu
Çalışma kopyasına geçiş pdfrx için GERÇEK bir yeniden yükleme; pdfrx yeniden
yüklemede ölçeği "sayfayı kapla"ya çekiyor. Kullanıcı yakınlaştırıp bir kelime
düzeltince sayfa birden uzaklaşıyordu — "kararsızlaştı" hissinin bir parçası.
Geçişten hemen önce `PdfViewerController.currentZoom` saklanıp
`calculateInitialZoom` ile geri veriliyor.

**Doğrulama:** `flutter analyze` 0 hata, **566 test yeşil**. Gesture
davranışı gerçek cihazda doğrulanmalı (arena widget testinde taklit edilemiyor).

## 2026-07-26 (9. tur) — "hiç sayfa geçemiyorum, zoom yapamıyorum": çalışma kopyası yolu geri alındı

Kullanıcı bulgusu (build 131/132): *"şu an hiç sayfa geçemiyorum, zoom
yapamıyorum, tamamen bozuldu."*

### Tanı yöntemi: koda değil, DİFFE bakmak
8. turdaki geri almadan sonra `PdfSelectLayer`'ın jest kurulumu, kullanıcının
sorunsuz kullandığı sürümle (6b475de) **birebir aynıydı** — dolayısıyla suçlu
seçim katmanı olamazdı. Bilinen iyi sürümle diff alınınca görüntüleyici
tarafında geriye tek bir gerçek fark kaldı: **6. turda eklenen çalışma kopyası,
`PdfViewer.file`'a verilen YOLU değiştiriyordu.**

### KÖK NEDEN — yol değişimi pdfrx için "belgeyi baştan yükle" demek
pdfrx belgeleri statik bir haritada YOLA göre tutar. Yol değişince
`_widgetUpdated` eski listenable'ın dinleyicisini kaldırıp yenisini
`load()` ediyor ve `_onDocumentChanged()` hemen çağrılıyor; o an belge henüz
null olduğu için `_controller` DETACH ediliyor, `_initialized` false yapılıyor
ve düzen sıfırlanıyor. Ayrıca eski `PdfDocument` dinleyicisi kalmayınca
dispose edilebiliyor — oysa `_pdfDoc`, açık sayfa görüntüleri ve
`PdfSelectLayer.loadText()` hâlâ onu kullanıyor. Bu geçiş sırasında bir şey
ters giderse görüntüleyici bağsız kalıyor: ne kaydırma, ne yakınlaştırma, ne
sayfa geçişi.

### Çözüm — yol HİÇ değişmesin
Düzenlemeler artık dosyanın KENDİSİNE yazılıyor ve görüntü 5. turdan beri
sorunsuz çalışan [PdfReload] ile (aynı yol, `forceReload`) tazeleniyor.
Özgün baytlar ilk düzenlemeden önce geçici bir **yedeğe** kopyalanıyor;
kullanıcı "üzerine yaz" demedikçe ekrandan çıkarken yedek geri yazılıyor.
Kullanıcıya verilen söz aynı kalıyor (her düzeltmede kaydet sorulmuyor,
çıkarken bir kez soruluyor, kopya olarak kaydedilebiliyor) ama görüntüleyici
kanıtlanmış yolda kalıyor.
- Bedeli açıkça kabul edildi: ekran açıkken belge diskte düzenlenmiş hâlde
  duruyor. Uygulama o sırada öldürülürse yedek geri yazılamaz. Buna karşılık
  6. turdan ÖNCE vurgulama zaten sorulmadan özgün dosyanın üstüne yazıyordu;
  yani bu tasarım eski davranıştan daha güvenli, yeni tasarımdan daha sağlam.
- "Kaydetme" seçeneği artık gerçekten geri alıyor (yedek geri yazılıp görüntü
  tazeleniyor); pencerede de böyle yazıyor.
- `calculateInitialZoom` kaldırıldı — yol değişmediği için gerekmiyor.

**DERS (3. kez aynı ders):** bu turda da, geçen turda da bozan şey ürün
mantığı değil, **pdfrx'in görüntüleyici durumuna dokunan yeni bir hareketli
parçaydı**. Görüntüleyici tarafında değişiklik yapmadan önce "bilinen iyi
sürümle diff" alınmalı; jest ve belge kimliği (yol) o diffte görünmemeli.

**Doğrulama:** `flutter analyze` 0 hata, **566 test yeşil**. Bilinen iyi
sürümle (6b475de) `PdfViewerParams` diffi artık yalnız `panEnabled` satırının
KALKMASI (varsayılan true) — başka fark yok.

## 2026-07-26 (10. tur) — ASIL KÖK NEDEN: seçim katmanı jest arenasına giriyordu

Kullanıcı düzeltmesi: donma **belge açılır açılmaz** oluyor, düzenlemeden
sonra değil. Bu tek cümle bütün tanıyı değiştirdi.

### Neden 6/8/9. turlar hedefi ıskaladı
Açılış anında kurulan ağaç, kullanıcının "bozuk" dediği sürümle 6b475de
(bu turların başlangıcı) arasında neredeyse aynı — yani suçlu bu turlarda
eklenen hiçbir şey olamazdı. Demek ki kullanıcının **bu turların EN BAŞINDA**
bildirdiği *"sayfayı kaydıramıyorum, zoom yapamıyorum"* hatası hiç
çözülmemişti; 6. turda üst çubuktaki "sürükleyerek seç" modunu suçlamıştım
(ekran görüntüsünde el simgesi açıktı) — mod gerçekten kötü bir tuzaktı ama
KULLANICININ HATASI O DEĞİLDİ.

### KÖK NEDEN
`PdfSelectLayer` sayfanın üstünde duruyor ve `GestureDetector` ile bir
`LongPressGestureRecognizer` kuruyordu. Bu tanıyıcı HER dokunuşta jest
arenasına giriyor ve süresi (500 ms) dolduğunda **kazanıp ötekileri eliyor**:
* Parmağını yarım saniye dinlendirip sonra kaydıran kullanıcıda uzun basış
  kazanıyor → sayfa kaymıyor.
* İki parmağını koyup açmadan önce bir an duraklayan kullanıcıda yine uzun
  basış kazanıyor, pdfrx'in ölçek tanıyıcısı eleniyor → zoom ölü.

İkisi de telefonda son derece olağan hareket; bu yüzden hata "ara sıra" değil
"sürekli" hissediliyordu. Emülatörde/fare ile fark edilmemesinin sebebi de bu:
fareyle insan parmağını dinlendirmez.

### Çözüm — katman artık HİÇBİR tanıyıcı kurmuyor
Sayfayı kaplayan alanda `GestureDetector` yerine **`Listener`** var.
`Listener` işaretçi olaylarını dinler ama **jest arenasına girmez**, dolayısıyla
pdfrx'in kaydırma/yakınlaştırmasıyla yarışması yapısal olarak olanaksız.
Uzun basış elle ölçülüyor: 500 ms zamanlayıcı + 18 px kayma toleransı +
ikinci parmak inince iptal.

Bilinçli bedel: uzun basıştan sonra parmağı sürükleyerek seçimi büyütmek yok
(o sürükleme sayfayı kaydırır). Seçim uçlardaki **tutamaçlardan** büyütülüyor —
Android'in yerel davranışı da bu. Kazanç: katmanın en kötü arıza biçimi artık
"seçim çalışmıyor"; **gezinmeyi kilitlemesi mümkün değil.**

### Yapısal koruma eklendi
`test/pdf_select_layer_gestures_test.dart`: kaynakta (yorumlar hariç)
`onLongPress` geçmemeli. Davranış testi yazılamıyor — `PdfSelectLayer` gerçek
bir pdfium `PdfPage`'i istiyor. Kural üç turda üç kez bozulduğu için kaynak
düzeyinde de olsa bir bekçi hak etti; hata mesajı nedeni anlatıyor.

**DERS:** "sayfanın üstüne konan her tanıyıcı, gezinmeyi elinden alabilir."
Bu katmana bir daha `GestureDetector` konmayacak. Ayrıca: kullanıcıya
**"ne zaman oluyor"** diye sormak (açılışta mı, işlemden sonra mı) üç turluk
yanlış tanıyı tek cümlede bitirdi — önce bunu sormalıydım.

**Doğrulama:** `flutter analyze` 0 hata, **567 test yeşil** (+1).

## 2026-07-26 (11. tur) — ASIL KÖK NEDEN BULUNDU: `CustomPaint` bütün dokunuşları yutuyordu

Kullanıcının tanıyı bitiren cümlesi: *"sadece kenardaki çubuktan kayıyor,
dokunarak olmuyor, zoom hiç yok."*

Bu, "jest arenasında yarışma" değil, **"işaretçi hiç ulaşmıyor"** demek:
kaydırma çubuğu ayrı bir katman olduğu için çalışıyor, sayfaya dokunmak ise
hiçbir şey yapmıyor. Yani pdfrx'in `InteractiveViewer`'ı (Stack'in EN ALTINDA)
işaretçiyi görmüyor — üstündeki bir şey yutuyor.

### KÖK NEDEN — Flutter'ın arka plan boyayıcısı tuzağı
```dart
// rendering/custom_paint.dart
bool hitTestSelf(Offset position) =>
    _painter != null && (_painter!.hitTest(position) ?? true);   // ?? TRUE
```
`CustomPainter.hitTest` varsayılan olarak **null** döner; `?? true` yüzünden
sonuç **true** olur. Yani **`painter:` verilmiş her `CustomPaint`, kapladığı
alandaki bütün dokunuşları sessizce yutar.** (`foregroundPainter` tarafında
`?? false` yazıyor — tuzak yalnız arka plan boyayıcısında.)

`PdfSelectLayer`'ın `CustomPaint`'i sayfanın TAMAMINI kaplıyor. Sarmalayıcıya
`HitTestBehavior.translucent` vermek hiçbir şeyi değiştirmiyordu: translucent
yalnız "çocuk vurmazsa yine de kaydol" demek, çocuk (CustomPaint) vuruyordu.
Sonuç: kaydırma ve yakınlaştırma **tümüyle** ölüydü — 5. turda katman
eklendiğinden beri.

**Düzeltme:** `_SelectionPainter.hitTest => false` (tek satır).

### Niye 6 tur boyunca bulunamadı
- Hata "bazen" değil "hep" olmasına rağmen, ilk ekran görüntüsünde
  "sürükleyerek seç" modu AÇIK görünüyordu ve bu çok inandırıcı bir suçluydu
  (`panEnabled: false` + opaque katman). Mod kaldırıldı, hata sürdü.
- Sonraki turlarda hep **jest arenası** (uzun basış vs. ölçek tanıyıcısı)
  incelendi. Arena analizi doğruydu ama YANLIŞ KATMANDAYDI: işaretçi zaten
  arenaya girmeden yutuluyordu.
- Yalnız `hitTest` sonucuna bakan bir soru sorulmamıştı. Kullanıcının
  *"kenardaki çubuktan kayıyor ama dokunarak olmuyor"* ayrımı, sorunun
  "yarışma" değil "ulaşamama" olduğunu tek cümlede söyledi.

**DERS 1:** `CustomPaint(painter: ...)` bir Stack'te BAŞKA bir katmanın
üstündeyse `hitTest`'i geçersiz kılmadan koyma. Sarmalayıcının
`HitTestBehavior`'ı bunu kurtarmaz.
**DERS 2:** Yutma yalnız **kardeş** katmanları kırar; ata (`Scrollable`,
`Listener` sarmalayıcıları) zaten olayı alır. Bu yüzden `sheet_cell` gibi
yerlerdeki aynı desen zararsız — orada kaydırıcı ATA konumunda.
**DERS 3:** "Ne çalışıyor?" sorusu "ne çalışmıyor?" kadar bilgi taşıyor.
Kaydırma çubuğunun çalışıyor olması, sorunun yerini doğrudan gösterdi.

**Koruma:** `test/pdf_select_layer_gestures_test.dart` artık iki kuralı da
bekliyor: (a) boyayıcıda `hitTest => false` geçersiz kılması duruyor,
(b) katmanda uzun basış tanıyıcısı yok. Hata mesajları nedenleri anlatıyor.

**Doğrulama:** `flutter analyze` 0 hata, **568 test yeşil** (+1).

## 2026-07-26 (12. tur) — "sayfaya git 1 sayfa ilerliyor": pdfrx AŞAMALI YÜKLEME yapıyor

Kullanıcı: kaydırma/zoom düzeldi (11. tur onaylandı). Yeni bulgu:
*"sayfaya git doğru çalışmıyor, ne yazarsam yazayım sadece 1 sayfa ilerliyor,
ve nerede olduğu anlaşılmıyor."*

### KÖK NEDEN — `document.pages` açılışta TAM DEĞİL
pdfrx 1.3.5'te `PdfViewer.file/asset/uri` hepsi `useProgressiveLoading = true`
varsayılanıyla geliyor. `_PdfDocumentPdfium.fromPdfDocument`:
```dart
final pages = await pdfDoc._loadPagesInLimitedTime(
  maxPageCountToLoadAdditionally: useProgressiveLoading ? 1 : null);
pdfDoc._pages = List.unmodifiable(pages.pages);   // → YALNIZCA 1 sayfa
```
Gerisi `loadPagesProgressively` ile arka planda ekleniyor ve `_pages` listesi
her turda YENİDEN kuruluyor; belge `PdfDocumentPageStatusChangedEvent`
yayımlıyor.

Biz sayfa sayısını `onViewerReady` anında **bir kez** okuyup saklıyorduk.
Değer, yükleme yarışına göre 1-2 gibi rastgele küçük bir sayıda donuyordu:
* alt rozet "5 / 1" gibi anlamsız bir şey gösteriyordu → *"nerede olduğu
  anlaşılmıyor"*,
* "Sayfaya git" hedefi `clamp(1, sayaç)` ile eziliyordu → kaç yazarsanız yazın
  belge birkaç sayfa ötesine gitmiyordu,
* AI/çeviri bağlamı için metin YALNIZ 1. sayfadan çıkarılıyordu (sessiz hata,
  kullanıcı henüz fark etmemişti).

Bu, oturumun BAŞINDAKİ *"8 yazıyorum 2'ye gidiyor"* bulgusunun da gerçek
sebebi. 6. turda "kutu seçili açılmıyor, metin 28 oluyor" diye açıklamıştım;
o da gerçek bir kusurdu ve düzeltildi ama ASIL sebep bu değildi.

### Çözüm
`_watchPageCount`: `document.events` akışına abone olunuyor, sayfa sayısı
canlı güncelleniyor. `_pageCount` getter'ı ayrıca belgeden doğrudan okuyor
(bir olay ıskalansa bile doğru sınır). Metin çıkarma son olaydan 800 ms sonraya
bırakılıyor; `_pdfTextPages` ile "önce başlayan az sayfalı tarama, sonra biten
tam taramanın üstüne yazmasın" yarışı da kapatıldı. Abonelik `dispose` ve
`_reloadPdf`'te iptal ediliyor.

### Bulunabilirlik
Kullanıcı *"kişiler bulamaz"* dedi: "Sayfaya git" yalnız arama çubuğundaki
etiketsiz simgedeydi. Artık üç yerde: üç nokta menüsünde (etiketli), arama
çubuğunda ve alttaki sayfa rozetine dokununca. Rozet de düz metinken
dokunulabilir görünmüyordu — simge ve "sayfaya git" yazısı eklendi.

**DERS:** pdfrx'te `document.pages` bir ANLIK GÖRÜNTÜ değil, büyüyen bir liste.
Sayfa sayısına dayanan her şey (sınır kısma, rozet, metin çıkarma, OCR, sütun
düzeni) canlı okunmalı.

**Doğrulama:** `flutter analyze` 0 hata, **568 test yeşil**.

## 2026-07-26 (13. tur) — 12. TURUN TANISI YANLIŞTI (düzeltme) + "sayfaya git" doğrulamalı

### DÜZELTME: 12. turdaki "aşamalı yükleme sayfa sayısını bozuyor" iddiası YANLIŞ
Build 139 (o düzeltmeyi içeriyordu) kullanıcıda **hiçbir şeyi değiştirmedi**.
Kaynağı yeniden okuyunca iddianın yanlış olduğu görüldü:
`_loadPagesInLimitedTime`, yüklenen sayfalardan sonra listeyi
`results.totalPageCount`'a kadar **`isLoaded: false` taslak sayfalarla
dolduruyor** (satır ~497). Yani `document.pages.length` daha ilk açılışta TAM
sayfa sayısıdır; `loadPagesProgressively` yalnız sayfa BOYUTLARINI yüklüyor.
`_pdfCount` hiçbir zaman yanlış değildi.
→ 12. turun `_watchPageCount` aboneliği, geciktirici ve `_pdfTextPages` yarış
koruması **geri alındı** (yanlış öncüle dayanıyorlardı; 9. turun dersi:
görüntüleyicinin etrafına gereksiz hareketli parça koyma). `_pageCount`
getter'ı ve bulunabilirlik iyileştirmeleri kaldı — onlar bağımsız olarak
doğruydu.

### Gerçek kalan sorun ve alınan yol
"Sayfaya git" hedefe gitmiyor, birkaç sayfa ötesinde kalıyor. En akla yatkın
mekanizma: pdfrx hedefe 200 ms'lik **animasyonla** gidiyor; bu sırada gelen
her yeniden yerleşim `_updateLayout`'ta
`if (isLayoutChanged || isViewSizeChanged) → _goToPage(o anki sayfa)`
tetikliyor ve atlayışı yarıda kesip geri çekiyor. Sayfa boyutları belge
açıldıktan sonra yüklendiği için düzen tam da "aç, hemen sayfaya git" anında
değişiyor.

Ama bu da **kanıtlanmış değil** — bu turda üst üste üç yanlış tanı yapıldı.
Bu yüzden mekanizmayı tahmin etmek yerine SONUÇ ölçülüyor: `_goToPdfPage`
hedefe gidiyor, 240 ms sonra `PdfViewerController.pageNumber` ile varışı
**doğruluyor**, tutmazsa en çok 3 kez yeniden deniyor ve sonucu kullanıcıya
söylüyor ("8. sayfa (toplam 9)" / "8. sayfaya gidilemedi; 3. sayfada
kalındı"). Böylece hem sorun büyük olasılıkla kapanıyor hem de kapanmazsa
kullanıcının gördüğü mesaj kök nedeni tek başına ayırt ettiriyor.

**DERS:** Üç kez üst üste yanlış kök neden ilan edildi (jest arenası → belge
yolu → aşamalı yükleme). Ortak kusur: **doğrulanamayan bir mekanizma
hikâyesine dayanıp düzeltme göndermek.** Cihazda ölçemediğimiz bir davranış
için doğru yol, tahmini değil SONUCU ölçen (ve ölçümü kullanıcıya gösteren)
kod yazmak.

**Doğrulama:** `flutter analyze` 0 hata, **568 test yeşil**.

---

## 2026-07-27 — PDF paragraf editörü, nesne/filigran düzenleme, hayalet dosyalar

### A. Karar: PDF düzenlemenin birimi KELİME değil PARAGRAF (kullanıcı kararı)

Kullanıcı önce "PDF'i Word'e çevir, düzenle, geri çevir" istedi. Reddedildi ve
gerekçesi söylendi: Dart'ta tam sadakatli PDF→DOCX yok, PDF (mutlak koordinatlı
sabit sayfa) ile DOCX (akışkan metin) farklı model, round-trip'te kayıp iki kez
birikiyor, bulut motoru KVKK riski. Kullanıcı asıl istediğini netleştirdi:
*"pdf üzerindeki yazıları sanki orjinal haliyle düzenleniyor gibi düzenlemek …
font boyut değişmeyecek ama kelime kısaldığında/uzadığında yine düzgün bir
paragraf gibi durması"* → yani **yerinde düzenleme + paragraf akışı.**

Sonra ikinci kararı: değiştirme birimi paragraf olsun. **Bu teknik olarak da
daha iyi çıktı**, sadece kullanışlılık değil: kelime bazlı yol metni içerik
akışında ARAMAK zorundaydı (üreticiler cümleyi kerning yüzünden onlarca parçaya
böler, kodlama tahmin edilir) ve gerçek belgelerde sık "bulunamadı" diyordu.
Paragraf birimi aramayı tamamen kaldırdı: dokunulan noktadan operatörler
koordinatla bulunuyor, o bayt aralığı komple yeniden yazılıyor.

### B. Yeni katman (saf Dart, cihazsız test edilebilir)

- `pdf/pdf_paragraph.dart` — paragraf bulma: satır gruplama (taban çizgisi),
  paragraf gruplama (satır aralığı tutarlılığı + yatay örtüşme + sol kenar
  hizası + aynı punto + aynı `cm`), biçim koşuları (font/punto/renk), `TJ`
  kerning boşluğunu kelime arası okuma, sayfa uzayında sınırlar.
- `pdf/pdf_paragraph_layout.dart` — yeniden dizme: ön ek/son ek diff ile biçim
  koruma, glif genişlikleriyle açgözlü satır sarma, iki yana yaslama, kelime
  başına mutlak `Tm` ile konumlandırma.
- `pdf/pdf_xobject.dart` — görseller: `cm` biriktirerek konum/boyut, silme
  (yalnız `/Im1 Do` baytları), taşıma/boyutlandırma (`Do` öncesine düzeltme
  `cm` EKLEME — mevcut operatör silinmez, q/Q dengesi bozulmaz).
- `pdf/pdf_background.dart` — filigran adayları (sayfaların ≥ yarısında
  yineleniyor VEYA çapraz çiziliyor) ve kaldırma.
- `pdf/pdf_page_context.dart` + `pdf_page_edit.dart` — dosya seviyesi, artımlı
  yazma + Syncfusion ile yeniden açıp doğrulama.

### C. TUZAK — `enc?.encode(t) ?? latin1.encode(t)` YAZILAMAZ

Testin yakaladığı gerçek hata: `?.` ile `??` birlikte "font tablosu YOK" ile
"tablo var ama bu harf içinde yok" durumlarını karıştırır. İkincisinde sessizce
Latin-1'e düşüp belgeye YANLIŞ GLİF yazıyordu (fontta olmayan `Ç` kabul edildi).
Doğrusu: tablo varsa cevabı yalnız o verir (`if (enc != null) return enc.encode(t);`).
Aynı kalıp `decode`/`measure` için de risklidir.

### D. Bilinçli sınırlar (kullanıcıya söylendi)

- Düzenlenen paragrafın satır içi kerning'i yeniden hesaplanır; paragraf DIŞI
  her şey bayt bayt korunur.
- Satır sayısı artıyorsa yalnız paragrafın ALTINDAKİ boşluk kadar taşılır;
  sığmazsa işlem REDDEDİLİR (sayfa kaydırma zinciri yok — kaç satır fazla
  geldiği mesajda söylenir).
- Aralıkta metin dışı operatör (`q`/`Q`/`cm`/`Do`/yol) varsa reddedilir:
  aralığı yeniden yazmak grafik durumu yığınını dengesiz bırakırdı.
- Form XObject'ler nesne listesine girmez (çizim alanı birim kare değil `/BBox`).

### E. Hayalet dosyalar (mor boş simge) — kök neden

Listeler yalnız UYGULAMA İÇİNDEN silme olunca tazeleniyordu (`FsEvents.version`).
Dosyayı Galeri/WhatsApp silince kimse haber vermiyor, kayıt listede kalıp
`Image.file` hata verince mor rozete düşüyordu. Çözüm: `FsEvents.reportUnreadable`
— küçük resim açılamayınca bildirilir, dosya GERÇEKTEN yoksa (bozuk ama duran
dosya listede kalmalı) tek sinyalde listeden düşürülür; bildirimler kare sonuna
kadar biriktirilip tek `changed()`'e indirgenir (800 fotoğraflı ızgarada her
hücrenin ayrı tetiklemesi uygulamayı kilitlerdi).

### F. Doğrulama

`flutter analyze lib` → 0 hata. `flutter test` → **577 geçti**; kırık 14 test
`fm_archive_rar_test.dart` ve DEĞİŞİKLİK ÖNCESİ temiz ağaçta da kırık
(stash ile doğrulandı) — bu turla ilgisi yok.

## 2026-07-28 — Arşiv (zip/rar/7z): sıkıştırma/çıkarma HİÇ çalışmıyordu — kök neden

Kullanıcı bildirimi (27 Tem gecesi, telefon): "sıkıştır" penceresi sonsuza kadar
"Hazırlanıyor…" gösteriyor, "Arka plana al" işe yaramıyor, ekrana anlamsız yazı
dökülüyor, "zip/rar kısmı kararsız".

### A. Kök neden — isolate closure'ı UI'ı da yanına alıyordu

`Isolate.run` closure'ı, ilerleme dinleyicisiyle **AYNI fonksiyon gövdesinde**
oluşturuluyordu (`ArchiveOps.extract` / `zip` / `compress`). **Dart aynı
gövdedeki closure'ları TEK bir context nesnesiyle besler:** dinleyici
`onProgress`'i yakalıyor (→ ilerleme penceresinin `ValueNotifier`'ı →
`WidgetsFlutterBinding`), isolate closure'ı da aynı context'i taşımaya çalışıp

    Illegal argument in isolate message: object is unsendable
    Class: _AsyncCompleter  <- Context num_variables: 5  <- Closure (archive_ops)

ile patlıyordu. Hata `Isolate.run`'ın future'ına DÜŞMEDİĞİ için `await` hiç
tamamlanmıyordu: iş ne başlıyor ne bitiyordu. Kullanıcının dört şikâyeti de
(donma, "çok uzun sürüyor", ham hata dökümü, kalıcı ilerleme şeridi) tek bu
nedenden geliyordu.

**Çözüm:** her `Isolate.run` çağrısı kendi top-level gövdesine alındı
(`_runExtract` / `_runZip` / `_runCompress`) — o gövdelerde başka closure yok,
context yalnız sendable parametreleri taşır. **Bu ayrımı bozma.**

*Niye testler yakalamamıştı:* `fm_compress_test` çağrıları `onProgress`
vermiyordu (null = gönderilebilir). Artık testler bilerek gönderilemez bir
nesne (`Completer`) yakalayan geri çağrı veriyor.

### B. İkinci kök neden — `FsPaths.isInside` Windows'ta hep false

`b.startsWith('$a/')` ayracı `/` varsayıyordu; `p.normalize` Windows'ta `\`
üretince her karşılaştırma false → `_safeJoin` null → **arşiv çıkarma sessizce
hiçbir dosya yazmıyordu** (hata da vermiyordu, "yanlış parola" testi bu yüzden
"başarılı" dönüyordu). Android'de `/` olduğu için orada görünmüyordu; masaüstü
hedefini ve tüm yerel testleri kırıyordu. Çözüm: `p.equals || p.isWithin`
(platform-doğru). Elle yol ayracı karşılaştırması YAPMA.

### C. İlerleme penceresi kilitli kalıyordu

`closeDialog` bayrağı pop'tan ÖNCE yakıyordu: iş pencere ilk karesini çizmeden
biterse (`dialogContext` null) bayrak yanmış oluyor, pencere sonradan açılıp bir
daha ASLA kapanmıyordu. Sıkıştırma düzeldikten sonra küçük dosyalarda iş anında
bittiği için bu tuzak gerçekten tetiklenir hale geldi. Bayrak artık istek/eylem
olarak ayrık; pencere kapatma isteğinden sonra çizilirse ilk karede kapanır.

### D. Arşivler artık uygulama içinde açılıyor

`EntryOpener.routeFor` arşivi `external`'a (sistemin uygulaması) yolluyordu;
kendi `ArchiveScreen`'imize yalnız dosya gezgininden ve uzun-bas menüsünden
erişilebiliyordu — ana ekran/arama/paylaşımla gelen zip dışarı çıkıyordu. Yeni
`OpenRoute.archive`: `ArchiveOps.canExtract` true ise kendi ekranımız, değilse
(ör. `.iso`) yine sistem.

### E. Doğrulama

`flutter analyze` → dokunulan dosyalarda 0 uyarı (47 issue'nun hepsi önceden
var olan `withOpacity`/`prefer_const`). `flutter test` → **590 geçti**.
Kırık 4 test **Windows'a özgü** ve değişiklik öncesi de kırıktı (stash ile
karşılaştırıldı; bu tur 9 → 4'e indirdi, **regresyon yok**): `volumePath`
POSIX yol bekliyor ama `p.join` Windows'ta `\` üretiyor · şifreli RAR
tearDown'ında temp klasörü silinemiyor (Windows dosya kilidi) · iki `fm_trash`
testi Android birim mantığına dayanıyor. APK ve Linux doğrulaması CI'da.

---

## 2026-07-28 — PDF editörü: 3 kullanıcı bulgusu (paragraf reddi, kesilen arma, alt çubuk)

### A. KÖK NEDEN — "hiçbir PDF'te yazı değiştiremedim"
Ekranda hep `Bu paragrafın içinde metin dışı çizim var (ET)` çıkıyordu.
Sebep bizim varsayımımızdı: `pdf_paragraph_layout._checkSpan` paragrafın bayt
aralığındaki her operatörü bir izin listesinden geçiriyor, `BT`/`ET` listede
yoktu. Ama resmi yazı üreticileri (EBYS, Ankara İSM yazıları) paragrafın **her
SATIRINI ayrı `BT … ET` bloğuna** yazıyor → çok satırlı HER paragrafın ortasında
zorunlu olarak `ET BT` çifti var → istisnasız reddediliyordu. Yani hata belgede
değil, motorun kendindeydi.
**Çözüm:** dengeli `ET`/`BT` çiftlerine izin. Güvenli, çünkü aralık bir metin
nesnesinin İÇİNDE başlayıp İÇİNDE bitiyor → silinen `ET` ve `BT` sayısı eşit,
dıştaki `BT` açık kalır, dıştaki `ET` kapatır, yığın dengede. Dengesiz dizi
(aralık `BT` ile başlıyor / eksik kapanıyor) hâlâ reddediliyor; `q`/`cm`/`Do`
gibi gerçek çizimler de öyle. Kanıt: `pdf_paragraph_test`e çok-`BT` testi,
düzeltme öncesi KIRMIZI (aynı hata mesajı), sonrası YEŞİL.

### B. KÖK NEDEN — "armanın yerini değiştirince kesiliyor"
`placeObject` taşımayı `Do`'dan önce düzeltme `cm` ekleyerek yapıyordu: görsel
yeni yere gidiyor ama o sırada geçerli **kırpma yolu (`W n`) eski yerinde
kalıyor** → taşan kısım kesiliyor. Antet logoları neredeyse hep
`q … re W n … cm /Im1 Do Q` içinde çizilir.
**Çözüm:** `PdfPageObject.clipped` (kırpma da `q`/`Q` yığınında taşınıyor).
Kırpma varsa yerinde `cm` yerine → çizim akıştan çıkarılıp akışın **sonuna**
temiz `q <cm> /Im Do Q` olarak yazılıyor; orada kırpma yok. Akış sonundaki
dönüşüm kimlik olmayabilir diye `_endTransform` ile tersi alınıyor.
**Bedeli (bilinçli):** kırpmalı görsel taşındığında en üstte çizilir. Kırpma
yoksa eski yol (yerinde `cm`) aynen duruyor, çizim sırası korunuyor.

### C. Alt eylem çubuğu her belge türünde
2026-07-27'de yalnız PDF'e eklenmişti; kullanıcı aynısını Word/txt/Excel/slayt
için istedi. Çubuk `widgets/doc_action_bar.dart`e taşındı (dört ekran ayrışmasın)
ve dolduruldu: PDF = Düzenleyici·Araçlar·Paylaş·Yazdır · txt/salt-okunur =
Düzenle·Kaydet·Paylaş·Yazdır · görsel = Metni tanı·PDF'e dönüştür·Paylaş ·
Word = Düzenle·Kaydet·Paylaş·Çevir · Slayt = Oynat·Kaydet·Paylaş·Çevir ·
Excel = sayfa sekmeleri + Kaydet·Paylaş·CSV·Çevir.
İki karar: **görselde "Yazdır" YOK** (`_print` metni PDF'e çevirip basıyor,
görselin metni olmadığı için boş sayfa çıkardı) · **Word/Slaytta düzenleme
sırasında çubuk gizleniyor** (klavye + biçim çubuğu zaten ekranın yarısını alıyor).
Word ve Slaytta "Yazdır" yok çünkü o ekranlarda basma yolu hiç yok — eklemek
docx/pptx→PDF render'ı gerektirir, ayrı iş.

### D. Doğrulama
`flutter analyze` → dokunulan dosyalarda 0 hata (kalan uyarılar önceden var olan
`withOpacity`/deprecated). `flutter test` → **592 geçti, 4 kırmızı**; dördü de
KALANLAR'da yazılı Windows'a özgü olanlar, bu turdan önce de kırmızıydı.
APK CI'da.

## 2026-07-28 (2. tur) — PDF `Q` reddi, ortalı yazı, Word okunabilirliği, tekrar eden düğmeler

### A. KÖK NEDEN — "hâlâ yeterince serbest değiliz": `Q` reddi
İlk turda `BT`/`ET` çözülmüştü ama aynı belgeler satırı ayrıca `q … Q` grafik
durumu bloğuna da sarıyor → aralıkta `ET Q q BT` → `Q` izin listesinde yok.
Aynı denge argümanıyla açıldı (silinen kapanış/açılış sayısı eşit), **tek ek
koşulla**: `Q` dönüşümü VE kırpmayı da geri alır. Farklı `cm` sorun değil,
çünkü `_continuesParagraph` zaten farklı dönüşümlü satırları ayrı paragraf
sayıyor (tekrar kontrol koymadık, tek doğruluk kaynağı orada). Geriye kırpma
kaldı → `PdfParagraph.uniformGraphics` = "hiçbir satır kırpma altında değil";
false ise `q`/`Q` yine reddediliyor (kırpmalı bloğu komşusuyla birleştirmek
yazının bir kısmını kestirirdi).

### B. KÖK NEDEN — ortalı başlık kısalınca kayıyor
`_wrap` yalnız iki düzen biliyordu: sola yaslı ve iki yana yaslı. Ortalı bir
başlık kısalınca sol kenarı sabit kaldığı için sağa büzülüyordu (kullanıcı
ekran görüntüsünde kutu 360-437, sayfa ortası ~450 — sol kenar eskisi).
Çözüm: `PdfParagraph.centered` — sayfa uzayında kutunun ortası sayfa ortasıyla
±%2 çakışıyor VE paragraf sayfa genişliğinin ≤%70'i ise ortalı. Genişlik
koşulu ŞART: sayfayı dolduran sıradan gövde paragrafının ortası da tanım gereği
sayfa ortasına denk gelir, onu ortalı sayarsak sol kenarını bozardık.
Ortalıysa her satır `centerX`'ten yerleştirilir ve sarma genişliği kendi dar
kutusu değil sayfanın metin sütunu (`columnWidth`) olur.
Bunun için `findParagraphs` artık `pageBox` alıyor (`PdfPageContext.mediaBox`);
verilmezse hiçbir paragraf ortalı sayılmaz (eski davranış).

### C. Word "yazı kalitesi çok düşük" — çözünürlük değil BOYUT
Ölçüldü (kullanıcı: yakınlaştırınca netleşiyor, sadece Word'de, sadece harfler):
`viewer.html/fitPage` A4 sayfayı (794 px) telefon genişliğine (~411 px)
sığdırmak için CSS `zoom` ~0.5 uyguluyor → 11 punto yazı 5-6 piksel.
Piksel kaybı yok, sadece çok küçük çiziliyor. "Daha yüksek çözünürlükte çiz"
diye bir çözüm YOK — A4'ün tamamı ekrana sığdığı sürece boyut budur.
Çözüm: **mobil akış görünümü** (`body.flow` sınıfı + `window.setFlow`) —
sayfanın sabit genişliği kalkar, paragraflar ekrana sarılır, ölçek 1'de kalır.
`!important` şart: docx-preview genişliği satır içi stille yazıyor.
**Kullanıcı kararı:** varsayılan SAYFA görünümü kalsın, mobil isteğe bağlı ve
hatırlanmasın. Canlı düzenleme etkilenmiyor (aynı `<p>` düğümleri).

### D. Tekrar eden düğmeler kalktı
Alt eylem çubuğu her ekranda olduğu için üstteki ikizleri kaldırıldı:
görüntüleyici ⋮'den Paylaş/Yazdır/PDF araçları + görselde OCR ve PDF'e
dönüştür, "Kaydet" simgesi · Word'den Düzenle+Kaydet simgeleri, ⋮ Paylaş/Çevir ·
Slayt'tan Oynat+Kaydet ve ⋮ menüsünün tamamı · Excel'den Kaydet, ⋮ Paylaş/CSV/
Çevir. **Kural:** üstte yalnız altta KARŞILIĞI OLMAYAN kalır. Tek istisna —
Word/Slaytta düzenleme sırasında alt çubuk gizlendiği için Kaydet o anda üste
çıkar (yoksa yazarken kaydetme yolu kalmaz).

### E. Doğrulama
`flutter analyze` → dokunulan dosyalarda 0 hata. `flutter test` → **596 geçti,
4 kırmızı** (KALANLAR'daki Windows'a özgü olanlar, bu turdan önce de kırmızı).
Ekran testleri kaldırılan düğmelerden hiçbirine takılmadı.

## 2026-07-28 (3. tur) — Excel: ölçü ayarı, Bul, kaydetme sadakati

### A. Sütun genişliği / satır yüksekliği ayarlanamıyordu
`XlsxSheet.colWidth/rowHeight` yalnız OKUYORDU; yazma yolu hiç yoktu.
Eklendi: `setColWidthChars(c, karakter)` / `setRowHeightPt(r, punto)` —
görünüm modelini (`layout.colWidths/rowHeights`) ve `excel` paketinin
haritasını BİRLİKTE günceller. 0 = gizle; gizli/görünür kümesi de senkron
tutulur, yoksa gizli sütuna genişlik verilince `colWidth` 0 döndüğü için
hiçbir şey olmuyormuş gibi görünürdü.
Arayüz: sütun/satır **başlığına uzun basma** (fare ile sürüklenecek kenar
telefonda parmakla vurulamayacak kadar ince) + ⋮ menüsünde aynı giriş.
Başlıkla seçili aralık örtüşüyorsa tüm aralığa uygulanır (Excel gibi).

### B. KÖK NEDEN — kaydetmede sütun genişlikleri bozuluyordu
`excel 4.0.6` `parse.dart` bir `<col min="1" max="10" width="20"/>`
aralığının **yalnız `min`ini** okuyor; `save_file.dart` `_setColumns` ise her
kayıtta `<cols>`u kendi haritasından **baştan** yazıyor. Sonuç: tek hücre
düzenlenip kaydedilince B–J sütunları varsayılana (ölçüldü: 14.43) düşüyordu.
Bizim `xlsx_reader` aralığı doğru açıyor → `XlsxEditor.parse` içinde
`_seedSizes` ile paketin haritası kendi okuduğumuz ölçülerden dolduruluyor.
Aynı düzeltme hem sadakati kurtarıyor hem A'daki yazmayı kalıcı yapıyor.
Kırmızı→yeşil kanıtlandı (`aralıklı <col> genişliği kaydetmeyi SAĞ ÇIKAR`).

**Kapatılamayan:** gizli satır/sütun (`hidden`) ve satır özel biçimi
kaydetmede hâlâ kayboluyor — paketin yazma API'sinde karşılığı yok
(`_createNewRow` yalnız `r`/`ht`/`customHeight` yazıyor, `sheetData`
tamamen temizlenip yeniden kuruluyor). Zip sonrası XML yaması gerekir →
KALANLAR. Ayrıca TAMAMEN BOŞ satırın yüksekliği yazılmaz (`<row>` yalnız
hücresi olan satır için üretiliyor) — kodda `ponytail:` notu var.

### C. Bul (metin arama) yoktu
Yalnız "Hücreye git" vardı. Eklendi: üst çubukta 🔍 → aktif sayfada
büyük/küçük harf duyarsız arama, ‹ › ile gezinme, `3/12` sayacı, eşleşme
seçilip görünür yapılıyor. **HAM değerde** arar (Excel'in "Bul"u da varsayılan
olarak formüllerde arar), formül hücresinde ek olarak sonuca da bakar.
Sınır: 500 eşleşme (`"a"` aramasında 100 bin hücre listelemek ekranı dondurur).
`_select` aynı hücreye ikinci gelişte düzenlemeye geçtiği için Bul/Hücreye git
artık `_jumpTo` kullanıyor.

### D. Görüntü denetimi — koyu temada okunmaz hücre
Excel'de sayfa DAİMA beyazdır, dosyalar da bunu varsayıp yazıyı siyah bırakır;
koyu temada o siyah yazı koyu zeminde **kayboluyordu** (tersi de: dosyadan
gelen beyaz dolgu üstünde açık tema yazı rengi). `sheet_cell.dart/readableOn`
kontrast oranı 2.5'in altındaysa rengi zemine göre çeviriyor. Eşik bilinçli
düşük: beyaz üstünde gri (~3.9) gibi KASITLI seçimler bozulmasın diye.
Ayrıca `_CellBorderPainter.shouldRepaint` `barColor`u karşılaştırmıyordu
(veri çubuğu rengi değişince yeniden çizmiyordu).

### E. Doğrulama
`flutter analyze` → dokunulan dosyalarda 0 sorun. `flutter test` → 602 geçti,
**4 kırmızı** — temiz kopyada (`git stash`) da aynı 4'ü verdi, KALANLAR'daki
Windows'a özgü olanlar. `excel`/`spreadsheet` testlerinin tamamı yeşil.
Cihazda görsel karşılaştırma YAPILMADI (gerçek Excel bu ortamda yok);
denetim çizim yolunun kod okumasıyla yapıldı.

## 2026-07-29 — Medyada eksik dosyalar, her yerde arama/filtre, Önemli Dosyalar

### A. KÖK NEDEN — "videolarda tüm videolar görünmüyor, dosyaların içinde var"
İki ayrı neden vardı, ikisi de sessizce dosya yutuyordu:

1. **800'lük kırpma.** `FsScan.index(perCategory: 800)` kategori başına yalnız
   **en yeni 800** dosyayı tutuyor; pano kutularının sayıları tüm taramadan
   (`stats`) geliyordu ama kategoriye GİRİNCE gösterilen liste (`byCategory`)
   o kırpılmış listeydi. Yani kutuda "1.240 video" yazıp içeride 800 video
   listeleniyordu. Gezgin gerçeği gösterdiği için kullanıcı haklı olarak
   "dosyaların içinde bulabiliyorum" dedi.
   **Çözüm:** kırpma kalmadı ama liste de sürekli bellekte tutulmuyor —
   `MediaLibrary.categoryFiles()` ile **istendiğinde** kuruluyor:
   önce arama dizininden (`FsScan.collectFromIndex`, disk gezilmez, isolate'te
   satır satır okur), dizin yoksa/boşsa diskten (`FsScan.collect`).
   Ekran anında açılsın diye önce kırpılmış liste çizilir, tam liste gelince
   yerine geçer (`PhotosScreen.loadAll` / `CategoryScreen.loadAll`).
   **Kural:** gelen liste elimizdekinden KISAysa yok sayılır — bozuk bir dizin
   yüzünden kullanıcıya gösterilen dosya sayısı asla azalmamalı.
2. **Eksik uzantı tabloları.** `FmExtensions` dar tutulmuştu: `m2ts, mpe, vob,
   3g2, divx, asf, rm, insv, lrv, mjpeg…` video sayılmıyordu; görselde `jp2,
   jxl, apng, cr3, nef, arw, orf, rw2…` (telefonların "pro"/RAW kipi) yoktu.
   Kategori dışı kalan dosya `other`'a düşüp galeriye HİÇ girmiyordu.
   Tablolar cömertleştirildi (ses/arşiv/belge dahil). **Karar:** yanlış
   kategoriye düşen nadir bir dosya, hiç görünmeyen dosyadan iyidir.
   Bilinen bedel: `.ts` hem TypeScript hem video akışı — telefonda video
   sayılıyor (sıra: görsel → video → ses → apk → arşiv → belge).

### B. Süzgeç ve sıralama tek yerde
`models/fm_filter.dart` (saf Dart) + `widgets/fm/fm_filter_sheet.dart`:
tarih aralığı (bugün / son 7 / son 30 / son 1 yıl / özel), boyut aralığı,
kaynak (Kamera/WhatsApp…), uzantı çoklu seçimi ve sıralama (ad/tarih/boyut/tür,
artan-azalan). Fotoğraflar, kategori listeleri, arama ve bellek analizi AYNI
sayfayı kullanıyor. Tuzaklar testle sabitlendi (`fm_filter_test`):
- "Son 7 gün" = **bugün dahil** 7 gün → gün başından 6 gün geriye.
- Özel aralıkta **bitiş günü tamamen** kapsanır (23:59:59.999); yoksa
  kullanıcı bitiş gününü seçtiği hâlde o günün dosyaları düşerdi.
- Boyut ölçütü seçiliyse klasörler elenir (klasör boyutu 0'dır → "100 MB
  üzeri"nde klasör listelenirdi).
Süzgeç düğmesi **rozetli** (`FmFilterButton`): görünmez süzgeç = "dosyam
kayboldu" hatası.

### C. Arama her ekranda
- **Bellek Analizi'nde arama YOKTU** → eklendi ve tüm depolamada
  (`SearchIndex.query`) arar; ekran yalnız en büyük 200 dosyayı tuttuğu için
  listeyi süzmek "aradığım dosya yok" demeye yol açardı. "Türlere göre"
  çubuğuna dokunmak listeyi o türe daraltıyor.
- **Arama ekranına** sıralama + süzgeç geldi; ham sonuç sınırı 500 → 1000
  (süzgeçten sonra haksız yere boşalmasın) ve "kaç sonuç · nasıl sıralı ·
  ilk 1000" özeti yazılıyor (sessiz kırpma "dosyam yok" sanılıyor).
- **Yinelenen dosyalar** ekranında hiç arama yoktu → eklendi.
- Fotoğraflar/kategori ekranlarında arama açıkken de süzgeç düğmesi duruyor.
- Fotoğraflarda ada/boyuta göre sıralama seçilirse zaman ekseni kapanır
  (ada göre sıralı listeyi güne bölmek başlıkları rastgele tekrar ettirirdi).

### D. Ana sayfada klasör oluşturma + Önemli Dosyalar
- Panoda FAB: ad + **konum** (ana bellek, standart klasörler, SD, Önemli
  Dosyalar) → oluşturup klasörü açıyor.
- `ImportantScreen`: `<ana bellek>/Önemli Dosyalar`. **Gerçek klasör**, gizli
  veritabanı değil — telefon bilgisayara takılınca da görünür, uygulama
  silinse de kalır. Ana sayfadaki kutu formatı ortak widget'a alındı
  (`widgets/fm/fm_category_tile.dart`); kategori kutuları alt klasörlerin
  içini de sayar, gezgin görünümü yalnız üst düzeyi. Alt klasör açma, arama,
  yapıştırma ve girdi menüsünde "Önemli dosyalara kopyala" var.
  **Kopya, taşıma değil:** "önemli" işareti asıl dosyayı DCIM/Belgeler'den
  koparmamalı.

### E. Performans tuzağı — `exists` süzmesi
`_dropMissing` her dosya sistemi olayında listedeki HER girdi için
`statSync` çağırıyordu; 800'lük listede sorun değildi, 20 binlik tam listede
ana izleği kilitlerdi. `FsScan.pruneMissing` isolate'e taşındı.

### F. Doğrulama
Flutter 3.29.3 (CI ile aynı) — `flutter analyze` dokunulan dosyalarda 0 sorun
(kalan uyarılar önceden var olan `withOpacity`/deprecated), `flutter test`
**627 geçti, 0 kırmızı** (bu turdan önce 1 kırmızı yeni testin kendi kurulum
hatasıydı, düzeltildi). Yeni testler: `fm_filter_test` (16 durum),
`fm_scan_test`'e 1000 satırlık dizinden **1000 videonun hepsinin** döndüğünü
kanıtlayan test (800 sınırı kırmızı→yeşil), `fm_photos_screen_test`'e tam
liste yer değiştirme + kısa listenin EZMEDİĞİ + süzgeç sayfası testleri.
Cihazda deneme YAPILMADI; APK CI'da derleniyor.

## 2026-07-29 (2. tur) — APK 200 MB → ABI'ye göre bölme

**Neden 200 MB'tı:** CI `flutter build apk --release` çalıştırıyordu = **fat APK**;
armeabi-v7a + arm64-v8a + x86_64 yerel kütüphaneleri (ML Kit metin tanıma/çeviri,
PDFium, syncfusion, video/ses, Firebase) TEK dosyada. Varlıklar toplam 6 MB
(fontlar 5,8) — yani boyutun neredeyse tamamı ×3 yazılan yerel kod.

**Yapılan (risksiz kısım):** `--split-per-abi --target-platform
android-arm,android-arm64`.
- **Süre uzamıyor:** bölme AOT derlemesini ÇOĞALTMAZ — şişko APK zaten her
  mimari için ayrı snapshot üretiyordu; yalnız paketleme ayrışıyor. x86_64
  düştüğü için (yalnız emülatörde işe yarar) bir AOT derlemesi eksildi →
  süre biraz KISALDI.
- **Dart kodu değişmedi** → süren geliştirmelerle çakışmaz, davranış aynı.
- İmzalama artık **döngü**: bölünmüş APK'ların hepsi aynı anahtarla
  imzalanmalı, yoksa kullanıcı mimari değiştirdiğinde "imza uyuşmuyor" ile
  güncelleyemez.
- **arm64 sade adı alır** (`dosya-okuyucu.apk`): 2016 sonrası pratikte her
  telefon arm64-v8a; kullanıcı her zamanki dosyayı indirmeye devam etsin diye.
  32-bit için ayrı dosya (`dosya-okuyucu-32bit-armeabi-v7a.apk`).
- CI'ya **boyut raporu** eklendi (job özetinde APK içi en büyük 25 dosya) —
  bundan sonraki küçültme kararları tahminle değil ölçümle verilsin.

**Ertelenen (riskli, cihazda test ister):** ML Kit gömülü modelleri
"unbundled"/Play Services sürümüne çevirmek (davranış değişir: model indirme
+ Play Services bağımlılığı), R8/minify + kaynak kırpma (HAFIZA'da zaten ML Kit
R8 "missing class" tuzağı var; reflection kullanan eklentiler SESSİZCE kırılır,
testler yakalamaz), kullanılmayan bağımlılık ayıklama (sürüm cehennemi).

## 2026-07-29 (3. tur) — Taşı/Kopyala tek adıma indi, seçim eylem çubuğu

### A. KÖK NEDEN — "taşıma kopyalama şu an çok zor"
Tek yol PANOYDU: kopyala → Dosyalar sekmesine geç → hedef klasörü ağaçta bul →
yapıştır. Dört adım, üstelik "pano" kavramını ve sekme değiştirmeyi hatırlamak
gerekiyor. Fotoğraf/video ızgarasında ise durum daha kötüydü: seçim çubuğunda
yalnız Paylaş/Kopyala(pano)/Sil vardı, **taşıma hiç yoktu**.
**Çözüm — tek adım:** uzun bas → **Taşı/Kopyala** → hedefe dokun → bitti.
- `FolderPickerScreen`: üstte kısayol çipleri (Önemli Dosyalar · İndirilenler ·
  Belgeler · Kamera … + favoriler + **son kullanılan hedefler**), altında
  gezinme (yalnız klasörler listelenir), "yeni klasör" ve "Buraya taşı/kopyala".
  Kısayola dokunmak **doğrudan** hedefi seçer (gir+onayla iki dokunuş değil).
  Önemli Dosyalar kısayolu klasör yoksa onu **oluşturur** — akış kesilmesin.
- Kaynağın kendisi/altı hedef olarak seçilemez (klasörü kendi içine taşıma).
- Birim kökünün üstüne çıkılamaz: `/storage`, `/` yazılamaz, oraya çıkmak
  yalnız "izin yok" ekranı gösterirdi.

### B. Seçim eylem çubuğu (alt) — `widgets/fm/fm_selection_bar.dart`
Uzun basış zaten seçim kipini açıyordu ama eylemler üst çubuktaki küçük
simgelere sıkışmıştı (başparmakla zor, etiketsiz). Artık **altta**:
Taşı · Kopyala · Paylaş · Sil · Daha fazla(pano, sıkıştır, önemli dosyalar,
yeniden adlandır, özellikler). Gözatıcı, kategori, Fotoğraflar ve İndirilenler
ekranlarının hepsi AYNI çubuğu kullanıyor.
**Kural (HAFIZA 2026-07-28 D) uygulandı:** altta karşılığı olan üst düğümler
kaldırıldı; üstte yalnız sayaç, "tümünü seç" ve (gözatıcıda) "seçimi tersine
çevir" kaldı. **Klasör seçiliyken Paylaş gizli** — Android klasör paylaşamaz,
gösterilse dokunulup hiçbir şey olmuyor sanılırdı.

### C. "Her türlü dosyada olmalı"
Girdi menüsü (`showEntryActions`) artık **Taşı…/Kopyala…** ile başlıyor; pano
girişleri "Panoya kopyala/kes" diye açıkça adlandırıldı. Menü zaten ortak
olduğu için gözatıcı, kategori, arama, yinelenenler, analiz ve galeri onu
kendiliğinden aldı. Ek olarak **video oynatıcı, ses çalar ve belge
görüntüleyiciye** "Dosya işlemleri" girişi eklendi — dosyayı taşımak için
ekranı kapatıp listede aramak gerekmiyor.

### D. GERİ AL (yeni) — `FileOps.undoMove`
Taşıma sonrası bildirimde "Geri al" var. Bunun için `FmOpResult.transfers`
eklendi: **gerçek** varış yolu (ad çakışınca `rapor (1).pdf` olur, tahmin
edilemez). `_transferOne` artık varış yolunu döndürüyor.
**Kopyalama geri alınMAZ:** orada geri almak "sil" demektir, yanlış dokunuşta
veri kaybı riski taşır. Geri alma ad çakışırsa yeni ad verir (veri ezilmez),
yani dosya eski adıyla dönmeyebilir — ama asla kaybolmaz.

### E. Küçük eklemeler
`AppState.fmRecentDestinations` (son 8 hedef, kalıcı): insanlar dosyayı hep
aynı birkaç klasöre koyar. Önemli Dosyalar ekranındaki yönlendirme metni yeni
akışa göre güncellendi.

### F. Doğrulama
Flutter 3.29.3 — `analyze` 0 sorun (kalan uyarılar önceden var olan
`withOpacity`/deprecated), `flutter test` **635 geçti, 0 kırmızı**.
Yeni `fm_move_copy_test`: gerçek varış yolu bildirimi, ad çakışmasında YENİ
adın bildirilmesi (geri alma buna dayanır), dosya ve klasör taşımasının geri
alınması, kopyalamada kaynağın yerinde kalması, seçim çubuğunun etiketleri ve
klasörde Paylaş'ın gizlenmesi. Cihazda deneme YAPILMADI.
