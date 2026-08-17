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

## 2026-07-29 (4. tur) — Zıplama, WhatsApp kopyaları, çoklu kaynak, kasma

### A. KÖK NEDEN — "seçince sayfa zıplıyor"
Alt eylem çubuğu `Scaffold.bottomNavigationBar` ile veriliyordu → seçim
başlayınca gövdenin YÜKSEKLİĞİ küçülüyor, ızgara yeniden yerleşiyor ve
kaydırma konumu kayıyordu. Çözüm: çubuk `Stack` içinde **bindirmeli**
(`Positioned(bottom: 0)`); görünüm alanı sabit kaldığı için zıplama yok.
Listelere/ızgaralara **sürekli** 88-96 px alt boşluk verildi (yalnız seçimdeyken
verilseydi boşluğun kendisi zıplatırdı).

### B. KÖK NEDEN — "WhatsApp görüntülerinde aynı resimden 3 tane"
WhatsApp aynı görseli birden çok klasöre yazar: `WhatsApp Images`, aynısının
`Sent` kopyası ve `Android/media/com.whatsapp/...` altındaki yeni yol. Galeri
tüm depolamayı taradığı için üçü de ayrı dosya olarak görünüyordu.
**Çözüm:** `FmFilter.hideDuplicates` — anahtar **ad + boyut** (Türkçe katlamalı).
Galeride (`PhotosScreen`) varsayılan AÇIK; kategori listelerinde kapalı.
- İçerik (bayt bayt) karşılaştırması BİLİNÇLİ olarak yapılmıyor: 20 bin dosyayı
  okumak ızgarayı dondurur. Gerçek içerik doğrulaması **Yinelenen dosyalar**
  ekranının işi (o zaten bayt bayt karşılaştırıyor).
- Boyut farklıysa kopya sayılmaz → aynı adlı farklı çekimler kaybolmaz.
- Gizleme **sessiz değil**: "N yinelenen kopya gizlendi · Göster" satırı ekranda
  duruyor (sessiz gizleme "dosyam kayboldu" hatasına yol açar).
- Ayıklama SIRALAMADAN SONRA yapılır: hangi kopyanın kalacağı sıraya bağlıdır.

### C. Çoklu kaynak seçimi
`FmFilter.bucket` (tek) → `buckets` (küme). Çipler `ChoiceChip` → `FilterChip`.
"Kamera + WhatsApp" birlikte seçilebiliyor; birden çok kaynak seçili olsa da
rozet 1 sayar (tek ölçüt).

### D. KÖK NEDEN — "uygulama kasmaya başladı"
Kategori listeleri artık 800 değil **on binlerce** dosya tutuyor (3. tur) ve
`build` her seçim dokunuşunda çalışıyor. Her karede yapılanlar:
süz + sırala (O(n log n)), gruplama, `bucketCounts`/`extensionCounts` (O(n)) ve
seçili girdiler için `_files.where(...)` (O(n)). 20 bin dosyada bu, kare
bütçesini fazlasıyla aşıyordu.
**Çözüm — önbellek:** `FmFilter.signature` + liste kimliği (`identityHashCode`)
ile anahtar üretilip sonuçlar saklanıyor (`_visibleCache`, `_sectionsCache`,
sayım önbellekleri) ve seçili girdiler **yol → girdi haritasından** O(1)
bulunuyor. Girdiler değişmedikçe hiçbiri yeniden hesaplanmıyor.

### E. İndirilenler ekranı ("ilginç, kullanışsız bir klasör")
Kullanıcı klasör sanmıştı; oysa bu, alt klasörler dahil TÜM dosyaların yaş
odaklı listesi. Yapılanlar: başlığa "N dosya · alt klasörler dahil" alt satırı,
klasör düğmesine anlaşılır ad ("Klasör görünümü"), **satır başına ⋮ menüsü**
(taşı/kopyala/paylaş/yeniden adlandır/sil — daha önce hiç yoktu, sadece açma ve
toplu silme vardı), alt klasördeki dosyalarda "📁 klasör adı" bilgisi ve
`index(perCategory: 5000)` yerine `collect` (kategori başına kırpma yok).

### F. Doğrulama
`analyze` temiz, `flutter test` **640 geçti, 0 kırmızı**. Yeni testler: çoklu
kaynak seçimi, kopya ayıklamanın ad+boyut kuralı (boyut farklıysa gizlemez),
önbellek imzasının küme sırasından etkilenmemesi, galeride "2 yinelenen kopya
gizlendi" satırı ve "Göster" ile geri gelmesi. Cihazda ölçüm YAPILMADI —
kasma düzeltmesi kod okumasıyla (kare başına yapılan iş) gerekçelendirildi.

## 2026-07-29 (5. tur) — On yeni yetenek: AI arama, sınıflandırma, düzenleme, kilit…

Kullanıcı önerilen listenin **tamamını** istedi. Her yetenek **saf bir çekirdek
+ ince bir ekran** olarak yazıldı; çekirdekler `fm_smart_features_test` ile
sabitlendi (30 durum). Ekranlar yalnız gösterir/uygular.

### A. Akıllı arama — `services/fm/smart_query.dart`
"geçen ay whatsapp videoları tatil" → kategori=video, tarih=son 30 gün,
kaynak=WhatsApp, kalan ad araması="tatil".
- **Önce YEREL çözümleyici, AI isteğe bağlı.** Sorguların çoğu birkaç kalıptan
  ibaret; bunun için ağ gecikmesi + API anahtarı zorunluluğu + maliyet ödemek
  yanlış olurdu. AI (Gemini) yalnız menüden istenince çalışır ve **başarısız
  olursa arama bozulmaz** (`smartQueryFromJson` null → yerel sonuç kalır).
- **TUZAK — aksan:** `turkishFold` yalnız harf büyüklüğünü katlar, aksanı
  KALDIRMAZ; "videoları" → "videolari" DEĞİL. Anahtar listeleri ASCII yazılıp
  hem sorgu hem anahtarlar `_plain()` (ı→i, ş→s, ğ→g…) ile indirgendi →
  "geçen ay" da "gecen ay" da çalışıyor. İlk testte 4 kırmızı bunu yakaladı.
- Anlaşılanlar **çip olarak gösterilir** ve "Yoksay" ile kaldırılabilir:
  sessiz süzme "neden bu sonuç?" sorusunu doğurur.
- `SearchIndex.query` `matchAll` aldı: cümle tamamen ölçüte dönüşünce
  ("bu hafta videolar") ad araması kalmıyor, yine de listeye ihtiyaç var.

### B. Görselde ne var? — `doc_classifier.dart` + `ai_actions.dart`
OCR metni anahtar sözcüklerle sınıflandırılır (fatura/kimlik/banka/sağlık/
sözleşme/bilet…) ve "Önemli Dosyalar/Faturalar"a taşıma önerilir.
**Sınıflandırma çevrimdışı ve ücretsiz** (tek fatura için ağ isteği saçma);
AI yalnız *özet* için. Sonuç **öneri**dir — taşımaya kullanıcı basar ve
kararın **kanıtı** (eşleşen sözcükler) gösterilir.

### C. Otomatik düzenle — `auto_organize.dart` + `organize_screen.dart`
Türe/tarihe/kaynağa göre alt klasörlere ayırma; **önizle → onayla → uygula**.
Zaten doğru klasördeki dosya taşınmaz, klasörlere dokunulmaz, varsayılan
yalnız üst düzey (mevcut alt klasör düzeni bozulmasın). Sonuç işlem geçmişine
yazılır → toplu geri alınabilir.

### D. Yer açma asistanı — `cleanup_advisor.dart` + `cleanup_screen.dart`
Çöp kutusu · kopyalar · 180+ gün açılmamış indirilenler · APK'lar · 100 MB+
videolar. **Güvenli öneriler açık, fotoğraf/video içerenler KAPALI gelir**
(yanlışlıkla silinen anı geri gelmez) ve her şey çöp kutusuna gider.

### E. Belge özeti (AI) — `ai_actions.dart`
Metin çıkarılır (gerekirse OCR), ilk 12 bin karakter Gemini'ye gider
(2 MB'lık PDF metnini göndermek pahalı ve gereksiz), özet + yerel sınıflandırma
birlikte gösterilir.

### F. Galeriden GERÇEK kopya temizliği
4. turda kopyalar yalnız *gizleniyordu* (ad+boyut tahmini). Artık "Temizle"
adayları `DuplicateFinder.scanPaths` ile **bayt bayt doğruluyor**, her gruptan
en eskiyi koruyor, kalanları çöpe atıyor. **Silme asla tahmine dayanamaz.**

### G. Klasör kilidi — `folder_lock.dart` + `pin_dialog.dart`
PIN tuzlanmış tekrarlı FNV ile saklanır (`crypto` paketi bu tek kullanım için
APK'ya girmesin). Kilitli klasör: gözatıcıda PIN sorar, **galeri/kategori
listelerinden de ayıklanır** (yoksa kilit işe yaramaz), kilidi KALDIRIRKEN de
PIN sorulur. **Dürüstlük kuralı:** arayüzde "şifrelemez, yalnız bu uygulamada
gizler" yazıyor — kullanıcıya sahte güvenlik satılmaz.

### H. Toplu yeniden adlandırma — `batch_rename.dart`
`{ad} {n} {n2} {tarih} {uzanti}` kalıpları, bul/değiştir, canlı önizleme.
**Uzantı otomatik korunur** (silinirse dosya açılamaz hâle gelir = sessiz veri
kaybı), yol ayracı temizlenir, çakışan adlar kırmızı ve atlanır.

### I. Son işlemler — `op_history.dart` + ekranı
Son 50 işlem; taşıma/düzenleme geri alınabilir. Bildirimdeki "Geri al" birkaç
saniyede kayboluyordu; beş dakika sonra fark eden kullanıcının elinde bir şey
kalmıyordu. Kopyalama/silme geri alınmaz (biri "sil" demek, diğeri çöp
kutusunun işi).

### J. Depolama takibi — `storage_trend.dart`
Günde bir fotoğraf (tarama zaten yapılıyor), analiz ekranında "Son 7 günde
+2,1 GB · en çok Videolar". Veri yoksa kart hiç gösterilmez (0 B değişim
bilgi değil gürültü).

### K. Doğrulama
`analyze` 0 hata, `flutter test` **670 geçti, 0 kırmızı** (30 yeni durum).
Cihazda deneme YAPILMADI; AI yolları (Gemini) gerçek anahtarla denenmedi —
hata yolları (anahtar yok / bozuk yanıt / ağ hatası) kodda ele alınıyor.

### L. CI TUZAĞI — build 152 kırmızı: NDK indirmesi bozuk geldi
Hata kodda değildi: `ndkVersion = "27.0.12077973"` runner'da kurulu değildi,
Gradle indirmeye çalıştı ve arşiv bozuk indi →
`java.util.zip.ZipException: Archive is not a ZIP archive` →
"Failed to install ndk;27.0.12077973" → `:pdfrx` yapılandırması çöktü.
**Çözüm:** sürüm sabit yazılmıyor; runner'da **kurulu** NDK'ların en yenisi
(`ls $ANDROID_SDK_ROOT/ndk | sort -V | tail -1`) kullanılıyor. Hem bu
kırılganlık kalktı hem her derlemede ~500 MB indirme atlandı. Kurulu NDK
yoksa eski sabit sürüme düşülüyor (uyarı basılarak).

## 2026-07-29 (6. tur) — Uygulama içi indirme (bağlantıdan / GitHub sürümünden)

Kullanıcı isteği: *"internetten bir linkten indireceğim (GitHub release,
DuckDuckGo, Chrome) — bizim programımızdan indirmek istiyorum, daha organize
hızlı etkili olalım"*.

### A. Neden kendi indiricimiz
Tarayıcının indirdiği dosya `Download` klasörüne düşer ve orada kaybolur;
kullanıcı sonra onu bulup taşımak zorunda. Bizim indiricimizde dosya
**baştan istenen klasöre** iniyor (örn. Önemli Dosyalar/Faturalar), yarım
kalırsa sürdürülüyor ve biter bitmez açılabiliyor.

### B. Parçalar
- `models/download_task.dart` (saf): durum makinesi, **dosya adı çözümleme**
  (Content-Disposition → `filename*` UTF-8 → URL yolu → içerik türünden
  uzantı), hız/kalan süre, kuyruk kodlama.
- `services/fm/download_service.dart`: akış hâlinde yazma (500 MB'lık APK
  belleğe alınmaz), `Range` ile sürdürme, iptal, en çok 2 eşzamanlı indirme,
  kuyruğun diskte saklanması.
- `services/fm/github_release.dart` (saf): `github.com/<sahip>/<depo>[/releases
  [/latest | /tag/<etiket>]]` → API adresi; sürüm yanıtından dosya listesi.
- `screens/fm/download_manager_screen.dart`: kuyruk/geçmiş, duraklat-devam-
  iptal, panodan yapıştır, elle bağlantı, hedef klasör seçimi.
- Panoda "İndir" kutusu; paylaşımdan gelen metin/bağlantı indirme akışını açar.
- `ci/AndroidManifest.xml`: **ayrı** `text/plain` SEND filtresi (dosya MIME
  listesine text/plain eklemek düz metin dosyası paylaşımıyla karışırdı) →
  Chrome/DuckDuckGo'da bağlantıya uzun bas → Paylaş → Dosya Okuyucu.

### C. Kritik kararlar (ve niye)
- **GitHub sürüm sayfası indirilmez.** `…/releases/latest` bir HTML sayfasıdır;
  olduğu gibi indirilse elde işe yaramaz bir `.html` kalırdı. Adres API'ye
  çevrilip **dosya listesi** gösteriliyor, kullanıcı hangisini indireceğini
  seçiyor (32-bit/64-bit APK ayrımı gibi). API'ye ulaşılamazsa adres olduğu
  gibi indiriliyor — kullanıcı hiç değilse bir şey elde etsin.
- **Sürdürme yalnız 206'da.** Sunucu `Range`'i yok sayıp 200 dönerse dosya
  BAŞTAN yazılıyor; yarım dosyanın sonuna baştan veri eklemek sessiz veri
  bozulmasıdır (testle sabitlendi).
- **Sunucunun verdiği ada güvenilmez:** yol ayracı, kontrol karakterleri ve
  baştaki noktalar temizleniyor (`../../etc/passwd` tuzağı testte).
- Dosya `.indiriliyor` uzantısıyla yazılıp bitince asıl adına taşınıyor →
  yarım dosya galeriye/kategori listelerine düşmüyor.
- **Arka planda devam ETMEZ** (ön plan servisi gerekir). Uygulama kapanınca
  koşan indirme kuyruğa "duraklatıldı" olarak yazılıyor; "indiriliyor"
  göstermek yalan olurdu. Kullanıcı tek dokunuşla devam ettiriyor.
- Bildirim/ön plan servisi ve paralel parçalı indirme (aria2 tarzı) YAPILMADI —
  ayrı iş; ikisi de yerel Android kodu ya da ek paket gerektiriyor.

### D. Doğrulama
`analyze` temiz, `flutter test` **689 geçti, 0 kırmızı** (19 yeni durum: ad
çözümleme, sürdürme koşulu, kuyruk turu, GitHub adres kalıpları ve bozuk
yanıtlar). Gerçek indirme cihazda denenMEDİ; ağ yolları CI'da koşturulamıyor.

### E. "İndirme kısmında seçenek olarak çıkmalıyız" (aynı gün, ek istek)
Paylaş menüsü yetmiyor: kullanıcı tarayıcıda **doğrudan bir dosya
bağlantısına dokununca** Android'in "hangi uygulamayla?" listesinde de
görünmeliyiz. Eklenen manifest filtreleri:
- `VIEW` + `http`/`https` + **pathPattern** (`.*\.apk`, `.*\.zip`, `.*\.pdf`,
  `.*\.mp4` …). **Desen ŞART:** yalnız şema yazılsaydı HER bağlantıda (haber
  sitesi, arama sonucu) tarayıcı yerine biz önerilirdik. Sorgu dizeli
  adresler için ayrıca `.*\.apk.*` deseni var.
- `VIEW` + http(s) + MIME (`application/vnd.android.package-archive`, `zip`,
  `octet-stream`): uzantı yerine tür bildiren sunucular için.

**TUZAK — paylaşım türüne güvenmemek:** gelen içerik eklentiye/Android
sürümüne göre `text`, `url` ya da `file` etiketlenebiliyor. Karar artık tek
ölçüte bağlı: içerik http(s) adresi mi ve diskte o adla dosya YOK mu →
indirme akışı. Ayrıca indirme ekranı açılışında **panodaki bağlantı** şerit
olarak öneriliyor: paylaşım yolu bir cihazda çalışmasa bile her zaman işleyen
bir yol kalsın.

**Cihazda doğrulanmadı:** intent filtrelerinin gerçekten listede çıkardığı ve
`receive_sharing_intent`in ACTION_VIEW http adreslerini ilettiği bu ortamda
test edilemez; ilk kurulumda denenmeli.

### F. "Arka planda mutlaka devam etmeli" — motor değiştirildi
İlk sürüm `http` paketiyle kendi akışını yazıyordu; uygulama arka plana atılınca
ya da kapanınca indirme duruyordu. Android'de bunun tek doğru yolu **ön plan
servisi** (foreground service) + kalıcı bildirim ve bu Dart'tan yazılamaz.
Üstelik CI her derlemede `android/` klasörünü `flutter create` ile yeniden
ürettiği için elle yazılmış bir Kotlin servisi her seferinde silinirdi.
**Karar:** iş `background_downloader 9.5.7` paketine devredildi — indirme
native tarafta koşuyor, uygulama öldürülse bile sürüyor, sistem bildiriminde
ilerleme görünüyor, duraklat/sürdür bildirimden de yapılabiliyor.
- Kendi `DownloadService`imiz artık **ince bir köprü**: paketin durum/ilerleme
  akışını dinleyip kendi modelimizi (`DownloadTask`) ve diskteki kuyruğu
  güncelliyor. Arayüz hiç değişmedi.
- Hedef yol `bg.Task.split(filePath:)` ile paketin beklediği (temel dizin,
  alt dizin, ad) üçlüsüne çevriliyor — elle `BaseDirectory.root` kurmak
  platforma göre farklı kök ön eklerinde kırılırdı.
- `pause`/`resume` yalnız `taskId` kullandığı için görev nesnesini yeniden
  kurmak yeterli; sürdürme verisi yoksa (uygulama verisi temizlenmiş)
  baştan başlatılıyor — "devam et"in hiçbir şey yapmaması en kötü sonuç.
- **Açılışta uzlaşma** (`_reconcileWithEngine`): kapalıyken indirme sürmüş,
  bitmiş ya da düşmüş olabilir. Motorda duran görevler "sırada", motorda
  olmayıp dosyası diskte olanlar "tamamlandı" sayılıyor. Bu yüzden kuyruk
  okunurken `running` artık `paused` değil `queued` oluyor.
- Manifest: `POST_NOTIFICATIONS`, `FOREGROUND_SERVICE`,
  `FOREGROUND_SERVICE_DATA_SYNC`, `WAKE_LOCK`. Bildirim izni verilmezse
  indirme yine çalışır, yalnız bildirim görünmez.
- `serverHonorsRange` silindi (aralık yönetimi artık pakette) — ölü kod
  bırakmak "burada bir şey yapılıyor" yanılsaması üretir.

### G. CI TUZAĞI — build 156 kırmızı: paket sürümü AGP'yi aştı
`background_downloader 9.5.7` Android tarafında `androidx.core:core-ktx 1.17`
ve `compileSdk 36` istiyor; ikisi de **AGP 8.9.1+** demek. Flutter 3.29.3'ün
ürettiği şablon AGP 8.7 kullanıyor →
"Dependency 'androidx.core:core-ktx:1.17.0' requires Android Gradle plugin
8.9.1 or higher" ile derleme çöktü.
**Çözüm:** paket `^8.9.0`a (8.9.5) sabitlendi — compileSdk 34, core-ktx 1.12,
work-runtime 2.9; kullandığımız API (configureNotification, holdingQueue,
start, resumeFromBackground, allTasks, Task.split, pause/resume) 8.9.5'te
birebir var, kodda tek satır değişmedi.
**Reddedilen yol:** AGP + Gradle wrapper'ı CI'da yükseltmek. Tek bir paket
için tüm derleme zincirini (Flutter 3.29.3'ün doğruladığı sürümler) oynatmak,
HAFIZA'daki sürüm cehennemi derslerinden sonra kabul edilebilir bir risk
değil. Flutter yükseltildiği turda 9.x'e geçilebilir.

**Ayrıca:** Android'de WorkManager işleri 9 dakikada kesiliyor. 10 MB'tan
büyük dosyalar ön plan servisinde koşacak şekilde ayarlandı
(`Config.runInForegroundIfFileLargerThan`), görevlerde `allowPause: true`
olduğu için kesilse bile kendiliğinden duraklayıp sürüyor.

### H. CİHAZDA DOĞRULANDI — listede ÇIKMIYORUZ. Kök neden: Android 12 kuralı
Kullanıcı ekran görüntüsü gönderdi: DuckDuckGo'da bir bağlantıya basınca açılan
"Bununla aç" listesinde yalnız DuckDuckGo ve Chrome var; biz yokuz.
§E'de "cihazda doğrulanmadı" diye bıraktığımız varsayım **yanlış çıktı**.

**Kök neden (Android 12 / API 31 — App Links doğrulaması):** `http`/`https`
şemalı bir `VIEW` + `BROWSABLE` intent filtresi artık sistem tarafından
**otomatik olarak gizleniyor**; yalnız o alan adı için *doğrulanmış*
uygulamalar listede çıkıyor. Doğrulama, alan adının sunucusuna
`/.well-known/assetlinks.json` koymayı gerektiriyor — `github.com` bizim
olmadığı için bunu **hiçbir zaman** yapamayız. Yani manifeste ne yazarsak
yazalım (pathPattern, MIME türü, öncelik) tarayıcının indirme seçiciye
giremeyiz. Bu bir hata değil, kasıtlı bir platform kısıtı.

**Reddedilen yollar:** (1) `autoVerify="true"` eklemek — doğrulama yine
sunucudan yapıldığı için hiçbir şey değiştirmez, sadece log'a hata yazar.
(2) Şemayı `http` yerine özel bir şemaya (`dosyaokuyucu://`) çevirmek —
tarayıcı böyle bir intent üretmiyor, kimse çağırmaz. (3) Erişilebilirlik
servisiyle tarayıcıya müdahale — kullanıcı verisine sınırsız erişim isteyen,
Play politikasının da yasakladığı bir yol; sade bir dosya yöneticisi için
kabul edilemez.

**Yapılan (dürüst çözüm):** kısıtı gizlemek yerine indirme ekranında
açıkça anlatan bir yardım kartı (`showDownloadHelp` +
`_HowToCard`, `download_manager_screen.dart`) ve **gerçekten çalışan üç yol**:
1. Tarayıcıda **Paylaş → Dosya Okuyucu** (SEND filtresi kısıta tabi değil,
   bu yol çalışıyor — asıl önerdiğimiz yol bu).
2. **Bağlantıyı kopyala** → uygulamayı aç; pano şeridi bağlantıyı kendiliğinden
   öneriyor.
3. Sistem ayarları → *Varsayılan olarak aç* → *Desteklenen bağlantıları aç*:
   kullanıcı isterse elle izin verebiliyor. Karttaki düğme doğrudan uygulama
   ayarlarını açıyor (`StoragePermission.openSettings`).

**Ders:** platform kısıtı bulunca arayüzü sessiz bırakmak en kötüsü —
kullanıcı "çalışmıyor" diye düşünür. Kısıt yazılıp yanına işleyen yol konur.

### I. "Ana ekranda çok fazla buton olmuş, karışıklık var"
Ana ekranda 16 kutucuk eşit ağırlıkta yan yanaydı (kategoriler + araçlar
karışık). Sorun sayıdan çok **hiyerarşisizlik**: "Görüntüler" ile "Çöp" aynı
boyda görününce göz nereye bakacağını bilmiyor.

**Karar — iki kademe:**
- **İçerik** (ne var): 8 büyük kart — Önemli Dosyalar, Görüntüler, Videolar,
  Belgeler, Ses, Arşivler, APK dosyaları, Yeni Dosyalar.
- **Araçlar** (ne yapılır): "Araçlar" başlığı altında 8 küçük, kartsız,
  en fazla 110 px'lik kutucuk (`FmToolGrid`, `fm_category_tile.dart`) —
  İndir, İndirilenler, Yer aç, Düzenle, Analiz, Uygulamalar, Son işlemler, Çöp.
Hiçbir özellik silinmedi; yalnız görsel ağırlık ayrıldı. Kartsız + küçük ikon
seçilmesinin nedeni: araçlar günde bir kez, kategoriler her açılışta lazım.

**Ek (aynı gün):** §H'deki 3. yolun (elle izin) gerçekten kullanılabilmesi için
manifeste `github.com`, `objects.githubusercontent.com`,
`raw.githubusercontent.com`, `codeload.github.com` alan adları TEK TEK yazıldı.
Eşleşme açısından gereksizler (`host="*"` zaten hepsini tutuyor); sebep şu:
"Varsayılan olarak aç" ekranı manifestteki alan adlarını **listeler** ve yalnız
`*` yazılıysa bazı cihazlarda liste boş geliyor → kullanıcının
işaretleyebileceği hiçbir şey olmuyor, yani izin verme yolu da kapanıyor.

## 2026-07-29 (III) — Video/fotoğraf işlemleri, arka plan kuyruğu, benzer görsel

Kullanıcının 6 maddelik listesi; her madde önce SORULDU, onay alındıktan sonra
yapıldı (seçimler aşağıda parantez içinde).

### A. "Basılı tutup seçince zıplama" — kök neden alt panel DEĞİLDİ
Alt eylem çubuğu 2026-07-29 (I)'de `Stack`e alınmıştı, yani zıplatmıyordu.
Asıl neden: seçim başlayınca ÜSTTEKİ satırlar (`gün/ay/yıl` çipleri, kaynak
çipleri, "N kopya gizlendi" şeridi) `!_selecting` ile **kayboluyor** ve ızgara
yukarı kayıyordu. `photos_screen` + `category_screen` düzeltildi: satırlar
seçim sırasında da durur (kopya şeridinin düğmeleri pasifleşir — kaybolsa
zıplar, etkin kalsa "seçtiklerimi mi siliyor?" sanılır).
**Ders:** "panel açılınca zıplıyor" raporunda panel masumsa, aynı karede
GİZLENEN şeye bak. Regresyon testi: `fm_photos_screen_test` içinde ilk karonun
`getTopLeft`i seçim öncesi/sonrası karşılaştırılıyor.

### B. Arka plan iş kuyruğu (seçim: "kuyruk + sistem bildirimi")
`services/fm/job_queue.dart` — tek tek koşan (eşzamanlılık 1), iptal
edilebilen, **sonucu saklayan** kuyruk. Sonucu saklaması kritik: ekrandan
çıkıp dönünce dakikalar süren tarama baştan başlamıyor (`job.result` +
kararlı `id`). Bağlananlar: **Yer aç** (çözümleme + temizleme),
**Yinelenen dosyalar**, **Benzer görseller**, **Boyut düşürme**.
- Şerit her sekmenin altında (`widgets/fm/job_progress_bar.dart`), gezinme
  çubuğunun üstünde; dokununca iş listesi açılır, sağdaki düğme iptal eder.
- Sistem bildirimi `flutter_local_notifications 17.2.4` ile ve **JobReporter**
  arayüzünün arkasında: kuyruk eklenti bağımsız kaldı (birim testi bildirim
  eklentisi olmadan koşuyor), bildirim kurulamazsa iş yine çalışıyor.
- **CI YAMASI GEREKTİ:** paket `java.time` kullanıyor, minSdk 24 < 26 olduğu
  için UYGULAMA modülünde de core library desugaring açılmalı. `flutter create`
  her koşuda `android/`ı yeniden ürettiği için workflow'a python yaması eklendi
  (`compileOptions` içine bayrak + `coreLibraryDesugaring` bağımlılığı).
  Yama gerçek 3.29.3 iskeletinde (build.gradle.kts) denenip doğrulandı.
- **Dürüst sınır (arayüzde de yazılı):** iş uygulama arka plandayken sürer,
  görev listesinden kapatılırsa durur. Gerçek ön plan servisi Dart'tan
  yazılamıyor ve CI android/ı ürettiği için Kotlin servisi silinirdi (§F).

### C. "AI ile aynı resimleri tespit" (seçim: cihaz-içi + Gemini, ikisi de)
İki katman, karıştırılmadı:
- `DuplicateFinder` = **birebir aynı dosya** (bayt bayt, yanlış pozitif yok).
- `SimilarFinder` + `image_hash.dart` = **aynı görünen** dosya (dHash).
  WhatsApp'ın yeniden sıkıştırdığı/boyutu değişmiş kopyayı bu yakalıyor.
- Parmak izi motoru **dart:ui** (`ImageDescriptor.instantiateCodec` hedef
  boyutla + `ImmutableBuffer.fromFilePath`): saf Dart `image` paketiyle 12 MP
  bir JPEG yarım saniye sürüyor (10 bin fotoğraf = bir saat), platformun
  çözücüsü milisaniye. Bedeli: ana izlekte koşmalı → iş kuyruğundan çağrılıyor.
  Videoda küçük resim karesi (var olan native `ThumbnailCache`) hash'leniyor.
- Parmak izleri diskte önbellekli (yol+mtime+boyut) → ikinci tarama anında.
- Gruplama: union-find ile **geçişli**; 6000'in altında tüm çiftler (kesin),
  üstünde 8x8-bit blok indeksi (güvercin yuvası: d≤7 için tam).
- Gemini yalnız kullanıcı bir grup için isteyince ve **küçültülmüş** JPEG'lerle
  çağrılıyor (`GeminiService.compareImages`); yanıt öneri, silme hep onaylı.

### D. Boyut düşürme — SERBEST ÇÖZÜNÜRLÜK VİDEODA VERİLEMEDİ (kullanıcı istedi)
Kullanıcı "videoda da serbest çözünürlük denenSin, kırılırsa kademeliye düş"
dedi. `light_compressor 2.2.0` **denenmeden önce** paket incelendi ve üç
bağımsız derleme kırıcısı bulundu → eklenmedi (CI turu yakılmadı):
1. Android modülünde `namespace` yok, manifestte hâlâ `package=` → AGP 8 için
   hata ("Namespace not specified").
2. Native bağımlılığı JitPack'te (`com.github.AbedElazizShe:LightCompressor`)
   ama paket bu deposu tüketen uygulamaya tanıtmıyor → çözümleme çöker.
3. Kendi `buildscript`inde AGP 4.2.2 classpath'i bildiriyor → kökteki 8.7 ile
   çakışır.
Üçünü yamayla zorlamak = "tek paket için tüm derleme zincirini oynatma"
(HAFIZA'da zaten reddedilmiş yol, bkz. §G).
**Yapılan:** fotoğrafta serbest ölçü TAM çalışıyor (saf Dart `image 4.3.0` —
`archive ^3` ile uyumlu SON sürüm, 4.4.0+ archive ^4 istiyor ve `excel` ile
çakışır). Videoda hangi seçim yapılırsa yapılsın (yüzde/serbest/kademe) hedef
ölçü hesaplanıp **en yakın ALT kademeye** eşleniyor (1080/720/540/480) ve
arayüz bunu açıkça yazıyor. Kare sayısı (60/30/24/15) ve "sesi çıkar"
`video_compress 3.1.4` ile tek geçişte.
**Açık kalan tek yol:** `ffmpeg_kit_flutter_new` (ikilileri yeniden
barındıran çatal, 2026-07-29'da yayınlandı) birebir çözünürlük + fps'i tek
geçişte verir ama APK'ya mimari başına ~25 MB ekler ve bir günlüktür —
kullanıcıya sorulmadan alınacak bir karar değil.
**Ayrıca:** çıktı özgün dosyanın yanına yazılır, "özgün dosyayı çöpe at"
varsayılan KAPALI; çıktı kaynaktan büyük çıkarsa çöpe atılıp "kazanç olmadı"
denir (kullanıcının elinde iki büyük dosya kalmasın).

### E. Belge Tara panoya taşındı (seçim: kamera taraması)
Ana ekranda (Dosyalar panosu) sabit yüzen buton; "yeni klasör" küçük düğme
olarak üstüne alındı. Son belgeler sekmesindeki düğme de kaldı.

### F. WhatsApp/Telegram "kişiye göre filtreleme" — DİSKTEN OKUNAMAZ
Gönderen/grup bilgisi dosya adında ve klasöründe **yok**; yalnız WhatsApp'ın
şifreli `msgstore` veritabanında ve root olmadan okunamıyor (Telegram aynı).
Kullanıcıya bu söylendi, seçim: "uygulama + tür + tarih süzgeçleri + elle
etiket".
- `models/chat_media.dart`: klasör düzeninden KESİN okunan kırılım
  (Görüntü/Video/Belge/Ses/Sesli not/Çıkartma/Animasyon) + `Sent` klasöründen
  gelen/gönderilen ayrımı. Sıra testle kilitli: "Video Notes" videodur,
  "Voice Notes" sesten önce sınanır, "Animated Gifs" görüntüden önce.
  Klasör tanınmazsa dosyanın kendi türüne düşülür.
- `services/fm/file_tags.dart`: kişi/grup etiketleri (JSON, uygulama dizini).
  Etiket dosyanın İÇİNE yazılmıyor (EXIF yazmak fotoğrafı yeniden kodlamak
  demekti) → **yola bağlı**, dışarıdan taşınırsa kopar; arayüzde yazılı.
- `FmFilter` üç yeni ölçüt aldı (chatKinds/direction/tags) ve `with*`
  üreteçleri tek `_copy`ye indirildi — yedi ayrı üretecin birinde alan
  düşürmek en kolay kaçan hata sınıfıydı, test bunu da kilitliyor.
  Etiket ölçütü **çözücü verilmezse hiçbir şeyi eşlemez**: sessizce "tümü"
  saymak, kullanıcı süzdüğü hâlde her şeyi görmesi demekti.

## 2026-07-29 (IV) — Videoda BİREBİR çözünürlük: ffmpeg çatalı eklendi

§D'de "açık kalan tek yol" diye bıraktığımız `ffmpeg_kit_flutter_new`
kullanıcı isteğiyle denendi ve **çalıştı** (derleme doğrulaması CI'da).

### Hangi varyant ve niye
`ffmpeg_kit_flutter_new_min_gpl 2.6.0`. Sekiz varyant var; H.264 **yazmak**
için x264 gerekiyor ve x264 yalnız `-gpl` varyantlarında. `min_gpl` en küçük
GPL varyantı; ölçekleme + kare sayısı + AAC için fazlası gerekmiyor
(full/https varyantları yalnız boyut ekler).

### Niye bu paket light_compressor gibi kırmadı
Bu sefer üç kırıcının hiçbiri yok: Android modülünde `namespace` **var**,
compileSdk 35, minSdk 24 (bizimkiyle aynı), native kütüphane **Maven
Central**'da (`com.antonkarpenko:ffmpeg-kit-min-gpl:2.2.2`) — JitPack yok.
R8 kuralları paketin `consumerProguardFiles`ıyla kendiliğinden geliyor, CI'da
proguard yaması gerekmedi.
**Tek gereken CI değişikliği:** Kotlin eklentisi 2.1.0 → **2.2.0**. Paket
kotlin-stdlib 2.2.0 çekiyor ve 2.1.0 derleyicisi 2.2 metadata'sını okuyamaz
(build 119'daki hata sınıfının aynısı, ters yön). Kotlin 2.2 Gradle eklentisi
Gradle 7.6.3+ / AGP 7.3+ istiyor; şablonda Gradle 8.10.2 + AGP 8.7.0 var.
Paket kendi buildscript'inde AGP 8.11.1 bildiriyor ama kökteki AGP kazanıyor
(light_compressor'daki AGP 4.2.2'nin aksine bu yön zararsız).

### Bedeli (bilinçli kabul edildi, kullanıcıya söylendi)
- **APK büyüdü:** arm64 66.7 MB → derleme sonrası ölçülecek (~+12 MB beklenti;
  AAR tüm ABI'ler için 48.6 MB, biz ABI'ye böldüğümüz için mimari başına pay
  düşüyor).
- **LİSANS:** x264/x265/xvid GPL v3. Uygulamanın dağıtımı artık GPL v3
  koşullarına giriyor. Depo halka açık olduğu için kaynak sunma fiilen
  karşılanıyor ama depoda LICENSE dosyası YOK — eklenmesi kullanıcının kararı,
  bizim değil (not edildi, sessizce lisans atanmadı).

### Kararlar
- **Yedek motor SİLİNMEDİ.** FFmpeg yolu bu ortamda cihazda doğrulanamıyor
  (Android SDK/telefon yok). FFmpeg herhangi bir nedenle başarısız olursa
  `video_compress` kademeli yoluna düşülüyor ve iş ayrıntısında hangi motorun
  kullanıldığı yazıyor. Yedek olmadan olası bir aksaklık özelliği tamamen
  kullanılamaz yapardı.
- **Kodlayıcı sırası:** önce `h264_mediacodec` (donanım, kat kat hızlı), olmazsa
  `libx264`. Donanım kodlayıcı her cihazda/derlemede olmayabiliyor; yokken
  ffmpeg saniyenin altında "Unknown encoder" ile döndüğü için yedek yol pahalı
  değil. Donanımda CRF anlamsız olduğu için bit hızı hesaplanıyor.
- **Ses `-c:a copy` DEĞİL, AAC'ye yeniden kodlanıyor:** kaynak sesi MP4'e
  girmeyen bir biçimde (WebM/Opus) olabilir ve copy o dosyada sessizce çöker.
- **DÖNDÜRME TUZAĞI:** telefon videoları yatay kodlanıp "90° döndür"
  verisiyle saklanıyor. ffprobe'un verdiği `width/height` **kodlanmış** ölçü;
  açı okunmazsa dikey bir videoyu 720p'ye indirmek istediğinde ölçüler ters
  hesaplanır ve video ezilir. `rotationOf` açıyı iki ayrı yerden okuyor
  (`side_data_list` ve eski dosyalarda `tags.rotate`), 90/270'te eksenler
  takas ediliyor. Saf fonksiyon + test.
- **Argüman kurucusu saf fonksiyon ve testli:** komut satırında tek yazım
  hatası ("-vf" yerine "-vs", filtreleri virgülle birleştirmemek) cihazda
  "video hiç dönüşmüyor" olarak görünür ve telefon olmadan başka türlü
  yakalanamaz. `-pix_fmt yuv420p` (eski oynatıcılar), `-map_metadata 0`
  (çekim tarihi korunsun, galeride "bugün" görünmesin), `-movflags +faststart`.

## 2026-07-29 (V) — LİSANS DÜZELTMESİ: GPL → LGPL (Google Play kaygısı)

Kullanıcı: *"lisans kısmını hallet Google Play'de sorun yaşamayalım."*
§IV'te `min_gpl` varyantı seçilmişti (x264 ile H.264 yazmak için) ve bedeli
"uygulamanın dağıtımı GPL v3'e girer" diye yazılmıştı. Bu bedel Play için
kabul edilemez: GPL v3 tüm uygulama kaynağını bu lisansla yayımlama
zorunluluğu getirir ve "ek kısıtlama koyulamaz" maddesinin mağaza dağıtım
şartlarıyla çakışması bilinen bir sorundur.

**Karar: `ffmpeg_kit_flutter_new_min` (LGPL v3).** GPL'li kodlayıcılar
(x264/x265/xvidcore/vid.stab) artık DAĞITILMIYOR.

### Birebir çözünürlük NEDEN kaybolmadı
`scale` ve `fps` süzgeçleri FFmpeg'in **çekirdeğinde** (libavfilter), GPL
kütüphanelerde değil. Kaybedilen tek şey x264 ile *yazılım* H.264 kodlaması.
Onun yerine cihazın **donanım kodlayıcısı** kullanılıyor
(`h264_mediacodec`) — paket FFmpeg **8.1.2** taşıyor, MediaCodec
kodlayıcıları 6.1'den beri var. Üç kazanç: lisans temiz, kodlama yazılım
x264'ten kat kat hızlı ve H.264 patent lisansı cihaz üreticisinde kalıyor.

### Kodlayıcı zinciri (hepsi LGPL kapsamında)
1. `h264_mediacodec` — cihazın donanımı, birincil yol.
2. `mpeg4` — FFmpeg'in kendi kodlayıcısı. Kalitesi H.264'ün gerisinde ama
   istenen **çözünürlük yine birebir** uygulanır. (CRF anlamadığı için
   `-q:v` 2..31 ile sürülüyor.)
3. Her ikisi de olmazsa `VideoTranscoder` kademeli MediaCodec motoruna
   (`video_compress`) düşer — §IV'te kurulan yedek zincir yerinde duruyor.

### LGPL v3 yükümlülükleri nasıl karşılandı
- `LICENSES.md` (depo kökü): bileşen, sürüm, lisans, **kaynak kodu
  bağlantıları**, değiştirilmediği notu ve yeniden bağlama (relinking)
  açıklaması.
- **Uygulama içinde** Ayarlar → *Açık kaynak bileşenler* ekranı
  (`showOpenSourceLicenses`). Depodaki dosya tek başına yetmez: mağazadan
  kuran kullanıcı depoyu görmez, lisans atfın KULLANICIYA ulaşmasını istiyor.
- FFmpeg dinamik bağlı `.so` olarak dağıtıldığı için relinking hakkı fiilen
  sağlanıyor (statik bağlasaydık LGPL ek yükümlülükler getirirdi).
- Kaynakta değişiklik yapılmadı → değişiklik bildirimi gerekmiyor.

### Test kilidi
`fm_ffmpeg_video_test` içinde **"GPL'li libx264 argümanları HİÇ üretilmiyor"**
testi var: bu lisans kararının kodda sessizce geri gelmesini engelliyor
(bir "hızlı düzeltme"de `libx264` eklemek çok kolay olurdu).

### Boyut yan etkisi
`min` AAR 38.9 MB, `min_gpl` 48.6 MB → APK ~10 MB daha küçük.

### Açık durum
- **build 164 ve 165 GPL'li ikili içeriyor** (§IV'ün derlemeleri). Yeni
  derleme bunları geçersiz kılıyor; o iki release'i silmek kullanıcının
  kararı (silme geri alınamaz, bu yüzden sormadan yapılmadı).
- `LICENSE` dosyası hâlâ YOK: artık uygulamanın kendi lisansı GPL'e
  zorlanmıyor, yani lisans seçimi tamamen proje sahibinin tercihi.

## 2026-07-29 (VI) — Üç yeni istek: üstünü/altını seç, son açılanlar, benzer video oynatma

### A. "Tümünü seç"e ek: üstündekileri/altındakileri de seç
Kullanıcı isteği: *"1 görüntü seçtim, onun altında kalanları seç, onun
üstünde kalanları seç butonu olsun"*. Google Fotoğraflar'daki "buraya kadar
seç" jesti. Yalnız **tek dosya** seçiliyken görünür (birden çok seçiliyken
hangi dosyanın "anchor" olacağı belirsizleşir) — `photos_screen`,
`category_screen`, `browser_screen` üçünde de aynı mekanik: seçili dosyanın
**görünen** (ekrandaki, mevcut sıralama/filtre sonrası) listede indeksi
bulunur, `_selectRange` ile [0, indeks] ("üstündekiler") veya
[indeks, son] ("altındakiler") aralığı seçime eklenir.
`browser_screen`'de `_selectionBar(context)` görünen listeyi almıyordu
(yalnız `_entries.length` biliyordu) — imza `_selectionBar(context, visible)`
oldu, çağrı yeri `build()`'teki `entries` (= `_sorted`) değişkenini geçiyor.
Widget testi (`fm_photos_screen_test`): 5 dosyalı bir grupta ortadakini seçip
"üstündekileri" tıklayınca 3/5, "altındakileri" tıklayınca 3/5 seçili
olduğu; 2. dosya seçilince (anchor belirsizleşince) düğmelerin kaybolduğu
kilitlendi.

### B. "Son açılanlar" — tüm dosya türleri için ayrı bir alan
Kullanıcı isteği: *"son açılma tarihi tüm dosyalar içinde yapılabilmeli ayrı
bir alanda"*. Var olan `AppState.recents` ("Son belgeler", AI sekmesi)
yalnız **belge** (Word/Excel/PDF/metin) açılışlarını ve en yeni 40'ı tutar —
görüntü/video/ses/arşiv YOK. `services/fm/open_history.dart`: yol→açılma
zamanı eşleyen, `file_tags.dart` ile aynı desende (uygulama dizininde JSON,
dosyanın içine yazılmaz, silinen dosyanın kaydı yüklemede düşer) AMA sınırsız
kayıt tutan ayrı bir servis. `EntryOpener.open` ve `openExternally` içindeki
**her başarılı açma dalına** (external/archive/player/audio/gallery+siblings/
belge) `OpenHistory.record(path)` eklendi — tek kapı olduğu için tüm ekranlar
otomatik kapsandı.
**KÖK NEDEN yakalanan hata (kod incelemesinde, cihaza gitmeden):** `record()`
ilk yazımda `ensureLoaded()`'ı hiç çağırmıyordu. `record()` genelde
uygulamanın OpenHistory'ye dokunduğu İLK yer olduğu için (kullanıcı dosya
açmaya "Son açılanlar" ekranını ziyaret etmekten çok daha sık başlar), bu
neredeyse HER oturumda diskteki geçmişi TEK dosyalık bir kayıtla ezip
önceki tüm geçmişi silecekti. Düzeltme: `record` önce `await ensureLoaded()`
çağırır. Ayrıca `ensureLoaded` bool bayrak DEĞİL, paylaşılan bir
`Future<void>?` ile memoize edilir — bayrak senkron olarak "yüklendi"
işaretlenip gerçek disk okuması sürüyorsa, eşzamanlı bir `record()` çağrısı
yüklemeyi BEKLEMEDEN devam edebilirdi. Bu ikisi `fm_open_history_test.dart`
içinde "yeni oturumda ilk açılan dosya eski geçmişi silmez" ve "eşzamanlı ilk
kayıtlar birbirini ezmez" testleriyle kilitli.
Ekran: `open_history_screen.dart` — liste + arama + "geçmişi temizle" (yalnız
kaydı siler, dosyaya dokunmaz). Panoya "Son açılanlar" aracı eklendi
("Son işlemler" ile karıştırılmasın: o taşı/kopyala/sil İŞLEMLERİNİ tutar,
bu hangi DOSYANIN ne zaman AÇILDIĞINI).

### C. Benzer videolar — SimilarScreen'de oynatma
Kullanıcı isteği: *"benzer videolar fotoğraflar ekranında oynatma
yapılabilmeli emin olabilmek için"*. `PhotosScreen`de video zaten normal
dokunuşla oynatılabiliyordu (istek bundan değil) — asıl sorun
`SimilarScreen`de: tek dokunuş SEÇİME ayrılmış, oynatma yalnız uzun basışta
gizliydi. Kullanıcı "aynı video mu?" diye emin olmadan silme kararı verme
riskiyle karşı karşıyaydı. Çözüm: video küçük resimlerinin üstüne görünür,
ayrı bir ▶ düğmesi (yarı saydam daire + `InkWell`) — kendi dokunuşunu
yakalar, alttaki `GestureDetector`ın seçim davranışını TETİKLEMEZ (aynı iç-içe
widget deseni `FmEntryListTile`'daki "⋮" düğmesinde de var, kanıtlanmış
çalışıyor). Fotoğraf küçük resimlerinde düğme yok (gerek yok, önizleme yeterli).

## 2026-07-29 (VII) — SADAKAT DENETİMİ: verilen sözler kodda tek tek doğrulandı

Kullanıcı gece "tüm alanlarda sadakatimizi %100 yap" dedi. Yöntem: bu oturumda
kullanıcıya ya da koda YAZDIĞIM her iddiayı bulup gerçekten öyle mi diye
kontrol etmek. Bulunan açıklar ve düzeltmeleri:

### AÇIK 1 (CİDDİ — veri kaybı): etiketler taşımada sessizce siliniyordu
`FileTags.movePath` ve `OpenHistory.movePath` yazılmıştı ama **hiçbir yerden
çağrılmıyordu**. Üstelik `file_tags.dart` başında *"Uygulama içinden taşımada
yol güncellenir ([movePath])"* yazılıydı ve etiket sayfasında kullanıcıya
*"dosyayı BAŞKA BİR uygulamayla taşırsan etiket onunla gitmez"* deniyordu —
yani uygulama içinde korunacağı sözü verilmişti. Gerçekte: kullanıcı "Ayşe"
diye etiketlediği fotoğrafı bizim gezginimizle başka klasöre taşıyınca kayıt
eski yolda kalıyor, bir sonraki açılışta "dosya yok" sayılıp **siliniyordu**.
**Düzeltme:** `path_side_index.dart` — yol anahtarlı yan kayıtları güncelleyen
kanca. `FileOps.rename`, `FileOps._transfer` (yalnız TAŞIMA; kopyalamada
etiket kaynakta kalır, kopyaya yapıştırmak kullanıcının vermediği bir karar
olurdu), `TrashService.moveToTrash` ve `TrashService.restore` bağlandı.
Kanca `main`de kaydediliyor: böylece `FileOps`/`TrashService` **saf `dart:io`**
kalıyor (belgelenmiş değişmez), `FileTags` ise `path_provider`a bağlı olduğu
hâlde katman kirlenmiyor. 7 test: `fm_path_side_index_test.dart`.

### AÇIK 2: "video ve fotoğraflarda AI ile tespit" — AI yalnız fotoğrafta
Cihaz-içi parmak izi videoda çalışıyordu (küçük resim karesini hash'liyor) ama
Gemini yolu *"video karesi henüz desteklenmiyor"* diyordu; yani isteğin yarısı.
**Düzeltme:** `SimilarScreen._previewFor` — video için aynı native kare
(`ThumbnailCache`) alınıp küçültülüyor. Gemini artık video gruplarını da
karşılaştırıyor.

### AÇIK 3: erişilemeyen özellikler
"Boyut düşür" ve "Etiketle" YALNIZ çoklu seçim çubuğundaydı; tek dosyaya uzun
basan kullanıcı bulamıyordu. İkisi de uzun basış menüsüne eklendi.

### AÇIK 4: yanıltıcı doküman (kuyruk kapsamı)
`FmJob` dokümanı arşiv çıkarmayı kuyrukta sayıyordu; gerçekte kopyala/taşı/sil/
sıkıştır/çıkar `showFmProgress` ile koşuyor. **Ama yetenek var:** o pencerenin
2026-07-26'da eklenmiş "Arka plana al" düğmesi + kalıcı şerit + "Durdur"u
mevcut. Yani "arka planda çalışabilmeli" isteği o işler için de karşılanıyor,
yalnız mekanizma farklı. Doğrulanmış kodu birleştirmek için kurcalamak yerine
**doküman gerçeğe uyduruldu** (iki mekanizmanın niye ayrı durduğu da yazıldı:
`showFmProgress` işin SONUCUNU döndürüyor — "çıkar, sonra çıkan klasörü aç" —
kuyruk ise ateşle-bırak).

### AÇIK 5: "son açılma tarihi TÜM DOSYALAR içinde" — özellikler penceresi
Ayrı ekran vardı ama tek bir dosyayı merak eden kullanıcı listeye değil
**Özellikler**e bakar. `Son açılma` satırı eklendi (yalnız kaydımız varsa
yazılıyor: "—" göstermek "hiç açılmadı" ile "bilmiyorum"u karıştırırdı).
NOT: dosya sisteminin `accessedMs` damgası bu iş için KULLANILAMAZ — Android'de
tarama/yedekleme de onu güncelliyor, "kullanıcı ne zaman açtı" demiyor.

### AÇIK 6 (var olan hata, denetimde çıktı): çöpten geri yükleme yanlış ad
`TrashService.restore` çapraz birimde (SD kart ↔ dahili) `rename` yapamayıp
`FileOps.moveAll`e düşüyor; moveAll dosyayı çöpteki **id'li adıyla**
("1753…-0-rapor.pdf") indiriyor ama metot çağırana `target`ı (eski adı)
döndürüyordu → kullanıcıya "eski yerine döndü" denip dosya bambaşka adla
duruyordu. Son adım (id'li addan gerçek ada rename) eklendi.

### AÇIK 7: boyut düşürmede küçük sadakat kusurları
- Uzantısız kaynakta çıktı adı `foto_720p.` oluyordu (hiçbir uygulama açmaz) →
  içerik JPEG yazıldığı için ad da `jpg`.
- Çıktı kaynaktan BÜYÜK çıkarsa çöpe atılıyordu; kullanıcının hiç görmediği,
  saniyeler önce bizim ürettiğimiz ve işe yaramadığını ölçtüğümüz dosyayla çöp
  kutusunu doldurmak yanlış → doğrudan silinir (özgün dosyaya dokunulmuyor).
- "Özgünü çöpe at" seçilince etiket/geçmiş çöpe giden dosyayla gidiyordu; oysa
  kullanıcının dosyası artık küçültülmüş çıktı → kayıtlar ÖNCE çıktıya taşınır,
  SONRA özgün çöpe gider (sıra önemli).

### FFmpeg iddiaları — İKİLİ DOSYADAN doğrulandı (tahmin değil)
AAR indirilip (`com.antonkarpenko:ffmpeg-kit-min:2.2.2`) içine bakıldı:
- **`--enable-gpl` YOK**, `libx264` kodlayıcı adı ikilide **yok** → LICENSES.md'
  deki "GPL bileşen dağıtılmıyor" iddiası **doğru**. (libavcodec'te geçen
  `x264 - core %d` / `x264_build` metinleri H.264 **ÇÖZÜCÜSÜNÜN** SEI sürüm
  algılaması; kodlayıcı değil — denetimde bu ayrım özellikle yapıldı.)
- `--enable-version3` → LGPL v3 doğru.
- **Sürüm:** libavutil içinde `FFmpeg version n8.1.2`, libavcodec `Lavc62.28.102`
  → gerçekten 8.1.2. (configure satırındaki `ffmpeg-kit-6.0.LTS` yazarın eski
  KLASÖR adı, sürüm değil — yanıltıcı, denetimde neredeyse yanlış sonuca
  götürüyordu.) 8.1.2 ≥ 6.1 olduğu için `h264_mediacodec` **kodlayıcısı** var;
  `AMediaCodec_createEncoderByType` sembolü de ikilide mevcut → donanım
  kodlama yolu gerçek.
- Her FFmpeg kütüphanesi **ayrı `.so`** (libavcodec/avfilter/avformat/avutil/
  swresample/swscale) → LGPL'in "dinamik bağlı, değiştirilebilir" koşulu fiilen
  sağlanıyor.
- **ÖLÇÜLEN boyut** (§V'teki "~12 MB beklenti" tahminini düzeltir): arm64
  `.so`ların toplamı **15 MB**; APK 66.7 MB (build 162, ffmpeg'siz) → 81.7 MB
  (build 166, LGPL ffmpeg) = **+15,0 MB**. Tahmin ve ölçüm birebir örtüştü.

## 2026-07-29 (VIII) — SADAKAT DENETİMİ, 2. TUR: hata avı (12 bulgu, hepsi kapatıldı)

§VII "verilen sözler kodda var mı?" sorusuna bakmıştı. Bu tur farklı bir soru
soruyor: **"var olan kod hangi durumda kullanıcının verisini bozar?"** Sistematik
hata avı (kod okuma, çalıştırma değil — cihaz yok) 12 bulgu verdi; hepsi
doğrulandı ve kapatıldı. Sıra ciddiyete göre.

### CRITICAL 1 — "Yer aç" yinelenenleri KALICI siliyordu (çöp sözü tutulmuyordu)
`CleanupScreen` seçilen önerileri `CleanupAdvisor`ın sıralamasıyla işliyordu:
`safeByDefault` önce, sonra bayta göre azalan. `trash` (çöp kutusunu boşalt) ile
`duplicates` (yinelenenler) İKİSİ de `safeByDefault` → boyuta göre sıralanınca
`duplicates` çoğu zaman ÖNCE geliyordu: yinelenenler çöpe taşınıyor, hemen
ardından `trash` önerisi çöpü `empty()` ile **kalıcı siliyordu**. Pencere ise
"çöp kutusuna taşınacak, geri alabilirsin" diyordu.
**Düzeltme:** `trash` önerisi her zaman EN BAŞA alınır (`ordered` listesi), yani
boşaltma kendisinden sonra çöpe gireni asla götürmez.
Ders: "iki öneri de güvenli" demek "sıraları önemsiz" demek DEĞİL — biri diğerinin
çıktısını yok eden bir işse sıra sözleşmenin parçasıdır.

### CRITICAL 2/3 — `bool _loaded` bayrağı etiketleri ve açılma geçmişini biçiyordu
`FileTags` ve `OpenHistory` diskten okumaya BAŞLAMADAN `_loaded = true`
işaretliyordu. O aralıkta gelen ikinci çağıran "yüklendi" sanıp BOŞ harita
üzerinde çalışıyor, ilk `add`/`record` tüm dosyanın üstüne yazıyordu.
`record()` uygulamanın bu kayda dokunduğu İLK yer olduğu için pratikte
**her oturum geçmişi/etiketleri sıfırlıyordu**.
**Düzeltme:** paylaşılan `Future` memoizasyonu (`_loadFuture ??= _load()`) +
`FmEnv.appSupportDir` boşken **kilitlenmeme** (paylaşımla soğuk açılışta
`ensureInit()` henüz koşmamış olabiliyor; bir kez boş kilitlenmek her şeyi
kaybettiriyordu).
Ayrıca `existsSync() == false` olan HER kaydı atmak yanlıştı: depolama izni
yokken / izin geri alınmışken / SD kart çıkarılmışken her yol "yok" görünür.
Artık kayıt yalnız **klasörü okunabildiği hâlde** dosya yoksa atılır
(`_shouldKeep`) ve ölü kayıt yüklemede **diske yazılmaz** (bir sonraki gerçek
değişiklikte kendiliğinden iner). Kilit: `test/fm_file_tags_test.dart` (13),
`test/fm_open_history_test.dart` (11).

### CRITICAL 4 — "Aynı kalsın" biçimi `.webp` adlı JPEG dosyaları üretiyordu
`ImageResizer` yalnız JPEG/PNG/BMP/TGA **yazabiliyor** (`image` paketi WebP
yazamıyor), ama "Aynı kalsın" seçilince kaynağın uzantısı körü körüne
korunuyordu. Sonuç: `.webp`/`.gif`/`.heic`/`.tiff` adlı, içi JPEG olan dosyalar —
galeride açılmaz, paylaşımda bozuk görünür. "Özgün dosyayı çöp kutusuna at"
açıkken kullanıcı sağlam aslını çöpe atıp bozuk kopyayla kalıyordu.
**Düzeltme:** `ImageResizer.keepExtension` + `encodableExtensions` kümesi
(`_resizeSync`teki switch ile birebir aynı olmak zorunda). Yazamadığımız her
uzantı `jpg`'ye düşer.

### HIGH 5 — benzer tarama kimliği TEK sabitti (kapsamlar birbirine karışıyordu)
`SimilarFinder.jobId = 'similar_media'`. Görüntüler'den, Videolar'dan ve panonun
"Benzer görsel" kutucuğundan açılan taramalar aynı kuyruk işini paylaşıyordu:
ikinci ekran açılışta "sonuç zaten var" deyip **başka kapsamın** gruplarını
gösteriyor, kullanıcı Videolar'da fotoğraf silebiliyordu.
**Düzeltme:** `SimilarFinder.jobIdFor(scope)` + `SimilarScreen.scopeId`
(`Görüntüler` / `Videolar` / `tum-medya`).
Aynı yerde: `cancelled` iş yeniden taranmıyordu → iptalden sonra ekran
"Benzer görüntü bulunamadı 🎉" diye **yanlış güvence** veriyordu. Artık
`failed` gibi `cancelled` de yeniden taranır.

### HIGH 6/8 — yinelenen taramada iptal ve geri dönüş
- `DuplicateFinder.scan` ortasında durdurulamıyor; `handle.result = groups`
  iptal yoklamasından SONRA yazılıyordu → tarama biterken "Durdur"a basmak
  dakikalarca süren işi çöpe atıyordu. Sıra ters çevrildi (sonuç saklanır, iş
  yine "İptal edildi" damgalanır).
- Ekrana geri dönüşte varsayılan seçim kurulmuyordu (`_seedSelection` yalnız
  kuyruk bildiriminde çalışıyor, bitmiş iş bir daha bildirim üretmiyor) →
  sonuçlar görünüyor ama "N kopyayı çöpe taşı" şeridi hiç çıkmıyordu.
- Yan bulgu: "Yeniden tara" içerik değişmediyse `_seedSignature` aynı kalıyor ve
  seçim bir daha hiç kurulmuyordu → `_scan()` imzayı sıfırlıyor.

### HIGH 7 — boyut düşürme kimliği çakışıyordu (ikinci iş SESSİZCE yutuluyordu)
Kimlik `resize_${adet}_${ilkYolunHashCode}` idi. Aynı 3 fotoğrafı önce 720p sonra
480p için başlatmak aynı kimliği üretiyor, kuyruk "bu iş zaten sürüyor" deyip
ikincisini yutuyordu — arayüz "arka planda başladı" diyor, hiçbir şey olmuyordu.
**Düzeltme:** kimlik = TÜM yolların hash'i + `MediaResizeOptions.signature`
(tüm ayar alanlarını yansıtan kararlı imza, birim testli).

### HIGH 9 — FFmpeg iptali yalnız istatistik geri çağrısında yoklanıyordu
İki kusur: (a) istatistik yalnız kare kodlandıkça gelir — ses çözülürken ya da
uzun dosyanın başında hiç gelmeyebilir, o aralıkta "Durdur" hiçbir şey
yapmıyordu; (b) ilk kodlayıcı (`h264_mediacodec`) hata verdiği anda kullanıcı
iptal etmişse İKİNCİ kodlayıcı (`mpeg4`) sıfırdan başlıyor ve dakikalarca
sürüyordu. **Düzeltme:** 400 ms'lik bağımsız yoklama zamanlayıcısı +
her kodlayıcı denemesinden önce iptal kontrolü.

### HIGH 12 — iptal edilen boyut düşürme diskte yarım iz bırakıyordu
`handle.throwIfCancelled()` döngünün başındaydı ve `FsEvents.changed()` ile
"özgünleri çöpe at" adımının ÜSTÜNDEN atlayıp dışarı fırlıyordu: 10 dosyanın
4'ü bittikten sonra durdurulunca o 4 yeni dosya hiçbir listede görünmüyor,
"Özgün dosyayı çöp kutusuna at" açıkken kullanıcının elinde hem özgün hem kopya
kalıyordu. **Düzeltme:** döngü `try`, kuyruk sonu `finally` — iptalde de
etiket taşınır, özgünler çöpe gider, listeler tazelenir, ayrıntı satırında
`durduruldu (4/10)` yazar.

### MEDIUM 10 — `ResizeResult.width/height` yedek motorda YALAN söylüyordu
Yedek motor (MediaCodec kademesi) istenen ölçüyü değil kendi kademesini uygular
ama alanlara KAYNAĞIN ölçüsü yazılıyordu ("çıktı 1920x1080" derken dosya
1280x720 olabiliyordu). Alanlar `int?` yapıldı; yedek yolda ölçü **çıktıdan**
okunur, okunamazsa `null` ("uydurmak yerine bilmiyorum").

### MEDIUM 11 — `PathSideIndex`: etiket/geçmiş yol değişince kayboluyordu
(§VII AÇIK 1'in devamı) Kanca `FileOps.rename`, `FileOps._transfer` (**yalnız
`move`** — kopyalamada etiket kaynakta kalmalı), `TrashService.moveToTrash`
(hem hızlı hem yedek yol), `TrashService.restore` ve boyut düşürmenin
"özgünü değiştir" yoluna bağlandı. `FileOps`/`TrashService` saf `dart:io`
kalsın diye kanca deseni seçildi (bkz. `path_side_index.dart`).

### Denetimin kendi dersi
Bulguların 4'ü **aynı desenden** çıktı: *"iki durumu birbirine karıştırmak"*.
- "dosya silinmiş" ↔ "şu an göremiyorum" (izin/SD kart) → CRITICAL 2/3
- "yüklemeye başladım" ↔ "yüklendi" (bayrak ↔ Future) → CRITICAL 2/3
- "iki öneri de güvenli" ↔ "sıraları önemsiz" → CRITICAL 1
- "uzantı" ↔ "gerçekten yazabildiğim biçim" → CRITICAL 4
Yeni kod yazarken bu dört ayrım özellikle sorulmalı.

### Doğrulama (bu turda)
`flutter analyze`: 0 hata (40 info/warning, hepsi eski koddan).
`flutter test`: **824 test geçti** (denetim öncesi 805; +19 yeni kilit).
Yeni/güncellenen test dosyaları: `fm_file_tags_test.dart` (yeni, 13),
`fm_media_resize_test.dart` (+9: `keepExtension`, ayar imzası, kapsam kimliği),
`fm_open_history_test.dart` (11), `fm_path_side_index_test.dart` (7).

## 2026-07-29 (IX) — SADAKAT DENETİMİ, 3. TUR: iki bağımsız hata avı (23 bulgu)

§VIII'deki 12 bulgu kapandıktan sonra **ikinci bir tur** koşuldu: bu kez iki
bağımsız denetim, "birinci turun KAÇIRDIĞINI bul" göreviyle — biri boyut düşürme
hattı (model/servis/ekran/pencere), biri dosya yöneticisi ekranları + yol
anahtarlı yan kayıtlar. Toplam 23 bulgu; ikisi de eklentilerin **kendi native
kaynağını** okuyarak (video_compress'in Android Kotlin'i, image 4.3.0) doğruladı,
tahmin etmedi. Bu tur en ciddi veri kayıplarını buldu.

### CRITICAL — "çıktı küçüldü" tek başına başarı ölçütü DEĞİLDİ
`ResizeResult` çıktı yoksa `afterBytes`ı bilerek 0 yazıyor; kabul koşulu ise
yalnız `afterBytes >= beforeBytes` idi → **0 >= 200 MB yanlış** olduğu için BOŞ
ya da BOZUK çıktı "en büyük başarı" sayılıyordu: özet "199 MB kazanıldı" yazıyor,
"Özgün dosyayı çöp kutusuna at" açıkken 10 dakikalık asıl videoyu çöpe atıyordu.
Gerçek senaryo: kaydı yarıda kesilmiş video (bozuk `moov` — telefonlarda çok
yaygın); ffmpeg ilk 3 saniyeyi çözüp **0 dönüş koduyla** çıkıyor.
**Düzeltmeler:** (a) `afterBytes <= 0` artık başarısızlık; (b) yeni
`VideoTranscoder._verifyOutput` — çıktı ffprobe ile okunur ve **süresi** kaynağın
%90'ından kısaysa iş başarısız sayılır, yarım çıktı silinir, özgüne DOKUNULMAZ;
(c) doğrulama `catch (_)` DIŞINDA: "yarım çıktı" kararı yedek motoru denemek için
sebep değil (kaynak bozuksa o da yarım üretir, kullanıcı dakikalarca bekler).
Ders: **"küçüldü" ile "geçerli" aynı şey değil.** Yer kazancı ölçmek, dosyanın
açılabildiğini ölçmek değildir.

### CRITICAL — yedek motor, "çözünürlüğü değiştirme" derken çözünürlüğü düşürüyordu
`video_compress` kademeleri eklentinin Android tarafında `DefaultVideoStrategy
.atMost(n)`e eşleniyor (`LowQuality` → 360, `MediumQuality` → 640; kısa kenarı
zorla düşürür). Bizim `_presetQuality` "Çözünürlük: Değiştirme" seçiminde
sıkıştırma sertliğini bu kademelere eşliyordu → kullanıcı *değiştirme* derken
1080p aslı çöpe gidip elinde 640 piksellik dosya kalıyordu. Üstelik bu yol yalnız
ffprobe başarısız olunca çalıştığı ve arayüzdeki "yedek motora düşülebilir"
uyarısı `changesResolution`e bağlı olduğu için **uyarı da görünmüyordu**: söz
verilmemiş, sorulmamış, geri alınamaz kayıp.
**Düzeltme:** `!changesResolution` → `HighestQuality` (eklentide ölçü kısıtı
KOYMAYAN tek kademe). Bedeli dürüstçe kabul edildi ve arayüze yazıldı: yedek
motorda sıkıştırma sertliği ve kare sayısı seçimi uygulanamaz.

### CRITICAL — "Temizle" çöp kutusu sözü verip KALICI siliyordu
`deleteEntries(confirm: false)` TÜM onay bloğunu atlıyordu — `!useTrash` dalı
dahil. Fotoğraflar ekranındaki "Temizle" kendi penceresinde *"çöp kutusuna
taşınacak"* yazıp bu yolu kullanıyor; Ayarlar > "Çöp kutusunu kullan" kapalıysa
31 fotoğraf kalıcı siliniyor, çöp kutusu boş kalıyordu.
**Düzeltme:** onay kararı saf bir fonksiyona çıkarıldı ve kilitlendi
(`needsDeleteConfirm`, `test/fm_delete_guard_test.dart`): **kalıcı silme onayı
hiçbir koşulda atlanamaz.** Ayrıca "Temizle" penceresinin metni ayarı okuyor ve
düğme etiketleri `deleteActionText` ile dürüstleşti (çöp kutusu kapalıyken
"çöpe taşı" yazmıyor).

### CRITICAL — benzer tarama kapsamı EKRAN BAŞLIĞIYLA anahtarlanıyordu
§VIII'de eklenen `jobIdFor(scope)` doğru fikirdi ama ona verilen anahtar
`category.label` ("Görüntüler") idi — bu ad **tek değil**: pano tüm depolamayı,
Önemli Dosyalar ekranı ise o klasördeki bir düzine dosyayı aynı başlıkla açıyor.
İkinci ekran "sonuç zaten var" deyip BİRİNCİNİN gruplarını gösteriyor,
"Fazlaları seç" + kırmızı şerit hiç taranmamış, hiç görülmemiş 40 fotoğrafı çöpe
atıyordu. **Düzeltme:** `PhotosScreen.scopeId` (pano `depolama-<kategori>`,
Önemli Dosyalar `onemli-<kategori>`). Ders: **kimlik, ekranın adı değil, işin
kapsamı olmalı.**

### HIGH — klasörü yeniden adlandırmak İÇİNDEKİ tüm etiketleri öldürüyordu
`PathSideIndex.moved` klasörler için de çağrılıyor ama `movePath` yalnız TAM
anahtara bakıyordu. `DCIM/Tatil` → `Tatil 2025`: 40 fotoğrafın "Ayşe" etiketi
ölü yollarda kalıyor, süzgeç çipi "Ayşe (40)" yazarken liste BOŞ dönüyor ve
kayıtlar hiç temizlenmiyor (`_shouldKeep` eski üst klasörü de göremediği için
"erişilemez" sanıp sonsuza dek saklıyor). **Düzeltme:** yeni saf fonksiyon
`movedPathFor` — alt yollar da yeniden yazılır, eşleşme **ayırıcı sınırında**
yapılır (`Tatil` taşınırken `Tatil 2025` etkilenmez), `/` ve `\` ikisi de sınır.
`FileTags.movePath` ve `OpenHistory.movePath` bunu kullanıyor; kilit:
`fm_path_side_index_test.dart` (klasör adlandırma + 6 saf yol testi).

### HIGH — animasyon/çok sayfa tek kareye iniyor, asıl çöpe gidiyordu
`image` paketinin `decodeImage`i animasyondan yalnız ilk kareyi çözüyor,
`encodeJpg` de tek kare yazıyor. 4 MB'lık hareketli bir GIF 200 KB'a "küçülüyor"
(çok küçük → kabul), asıl GIF çöpe gidiyor ve kullanıcının elinde tek duruk kare
kalıyordu. 12 sayfalık TIFF'te 11 sayfa, PSD'de katmanlar aynı şekilde.
**Düzeltme:** `ImageResizer.mayLoseFrames` (gif/apng/webp/tif/tiff/psd/xcf) —
dönüştürme yapılır (duruk bir `.webp` küçültmek isteyenin yolu kapanmasın) ama
**"özgünü çöpe at" bu dosyalarda uygulanmaz** ve özette yazar:
"N hareketli/çok sayfalı dosyanın aslı korundu".

### HIGH — kullanıcının kendi bastığı "Durdur" ona "biçim desteklenmiyor" diyordu
`video_compress` iptalde de hatada da `null` döndürüyor (Android'de
`onTranscodeCanceled` ve `onTranscodeFailed` ikisi de `result.success(null)`) →
`info.isCancel` ölü kod. İptal `VideoTranscodeException`a düşüyor,
`resize_actions` onu `failed++` sayıyordu. **Düzeltme:** `info == null` +
iptal isteği → `JobCancelled`.

### HIGH — iptal özeti hiçbir yüzeye ULAŞMIYORDU
`resize_actions` iptalde dürüst bir özet yazıyor ("12,4 MB kazanıldı · 4 özgün
çöp kutusunda · durduruldu (4/10)") ama ilerleme şeridi `İptal edildi.` sabitini
basıyor, bildirim ise iptalde tümden **siliniyordu**. Yani 4 videosunun çöpe
gittiğini öğrenmenin hiçbir yolu yoktu. **Düzeltme:** şerit `İptal edildi · …`
yazıyor; ayrıntısı olan iptal bildirimi silinmiyor. Özete "N özgün çöp kutusunda"
satırı eklendi.

### HIGH — "Yer aç" iptalden sonra "Depolaman düzenli görünüyor 🎉" diyordu
`cleanup_screen.initState` yalnız `failed` bakıyordu (§VIII'de diğer iki ekranda
düzeltilen hatanın aynısı, burası atlanmış). İptal edilen çözümlemenin sonucu
yok → ekran tam ters bir güvence veriyordu. Ayrıca geri dönüşte varsayılan seçim
kurulmuyordu ("Güvenli öneriler açık gelir" sözü ikinci girişte tutulmuyor,
düğme "Bir öneri seçin" diye kapalı kalıyordu). İkisi de düzeltildi.

### HIGH — serbest ölçü kaynaktan BÜYÜTÜYORDU (arayüz tersini yazarken)
"Kaynaktan büyütme yapılmaz" kuralı yalnız kademelerde uygulanıyordu; arayüz bu
cümleyi tam serbest ölçü alanlarının ALTINDA yazıyor. 1000 px fotoğrafa 2000
yazmak dosyayı büyütüyor, çıktı kaynaktan büyük çıkıyor ve iş "küçültülemedi"
diye bitiyordu — kullanıcı nedenini hiç öğrenmiyordu. **Düzeltme:** serbest
ölçüde de kaynağa çekilir (4 test). Ayrıca yardım metni ikinci gerçeği de
söylüyor: iki alanı da doldurmak oranı bozar.

### MEDIUM (hepsi kapatıldı)
- **Yinelenenler ekranı GÖRÜNMEYEN grupları siliyordu:** varsayılan seçim tüm
  gruplara kurulu, arama yalnız çizimi daraltıyordu → "1 / 47 grup" yazarken
  şerit 94 dosyayı çöpe atıyordu. Artık eylem ve sayılar `_visibleGroups`ten.
- **Seçim, çip süzgeciyle budanmıyordu:** "Tümünü seç" (8214) sonra "WhatsApp
  (12)" çipi → başlık "8214 / 12 seçildi", "Sil" 8214 dosyayı götürüyordu.
  `_selectedEntries` artık GÖRÜNEN listeden çözülür (seçim kümesi korunur, çipi
  kapatınca geri gelir); sayaçlar eylemle aynı kümeyi sayar.
- **`setState` after `dispose`:** `showFmProgress`ın "Arka plana al" düğmesi
  pencereyi kapatıp işi sürdürüyor; kullanıcı geri gidince dört yerde ölü
  State'e `setState` gidiyordu (photos/category/browser seçim çubuğu,
  duplicates silme sonrası). `mounted` koruması eklendi.
- **Kare sayısı büyütülüyordu:** 30 fps videoya "60" seçmek ffmpeg'e kareleri
  kopyalattırıyor, dosya şişiyor, iş "küçültülemedi" diye bitiyordu →
  `VideoTranscoder.cappedFps` (çözünürlükteki "büyütme yok" kuralının kare
  sayısındaki karşılığı, 4 test).
- **Yeniden kodlama uyarısı yanlış bayrağa bağlıydı:** video yolu çözünürlük
  değişmese de HER durumda yeniden kodluyor; uyarı `changesResolution`e bağlıydı
  → "Değiştirme" seçen kullanıcı dakikalar sürecek kodlamayı uyarısız
  başlatıyordu. Uyarı artık seçimde video varsa her zaman görünüyor.
- **Yedek motorda iptal yalnız ilerleme geri çağrısında yoklanıyordu** (FFmpeg
  yolundaki 400 ms'lik yoklama buraya da eklendi).
- **Yedek motorun geçici çıktısı sızıyordu:** eklenti iptal/hata yolunda dosyanın
  yolunu söylemiyor → art arda iptallerde uygulama deposunda gigabaytlar
  kalıyordu. İptal/hata yolunda `deleteAllCache()` çağrılıyor.
- **Yarım kalan görüntü yazımı** albümde 0 baytlık dosya bırakıyordu → hata
  anında silinir.
- **Bit hızı 30 fps varsayıyordu:** "15 fps" seçene gereğinin iki katı bit hızı
  ayrılıyor, yani kare sayısını yarıya indirmek dosyayı beklendiği kadar
  küçültmüyordu → `_bitrateFor` artık fps alıyor.
- **Fotoğraflar "Temizle" etiket süzgeci açıkken hiçbir şey yapmıyordu**
  (`tagsOf` verilmemiş): ekran "6 kopya gizlendi" derken düğme "kopya çıkmadı"
  diyordu. `analysis_screen`de de aynı çözücü savunma amaçlı eklendi.

### LOW (kapatıldı)
- Benzerlik kademesi geri dönüşte "Normal"e dönüyor ama ekranda SIKI sonuçları
  duruyordu → kademe kapsam başına hatırlanıyor.
- "İşlem arka planda başladı" metni durumu okumuyordu (aynı iş sürüyorsa yenisi
  hiç açılmıyor; kuyrukta bekleyen iş "başlamış" değil) → üç ayrı metin.
- `sourceSize` aynı dosyada ikinci bir ffprobe koşturuyordu → `_sizeViaPlugin`.
- `archive_screen._preview` `await`ten sonra `context` kullanıyordu (analyzer
  uyarısı; tek `mounted` koruması).

### Bu turun dersi
1. tur "kod ne yapıyor?" diye sordu; 2. tur **"eklenti gerçekte ne yapıyor?"**
diye sordu ve en ciddi iki kaybı orada buldu (`atMost(360)`, `success(null)`).
Bir paketin Dart API'si sözleşme değil; davranış native tarafta. Bir daha
eklentiye dayanan bir söz verirken (birebir çözünürlük, iptal, kare sayısı) o
sözün native karşılığı OKUNARAK doğrulanmalı.

### Doğrulama (3. tur)
`flutter analyze`: 0 hata, 0 yeni uyarı (kalan 39 info/warning eski koddan;
`withOpacity` deprecation'ları). `flutter test`: **853 test geçti** (2. tur
sonunda 829). Yeni: `fm_delete_guard_test.dart` (7),
`fm_media_resize_test.dart` (+13: serbest ölçü büyütmez, `cappedFps`,
`mayLoseFrames`), `fm_path_side_index_test.dart` (+7: `movedPathFor` + klasör
adlandırma), `fm_smart_features_test.dart` (+5: `cleanupApplyOrder`).

## 2026-07-29 (X) — SADAKAT DENETİMİ, 4. TUR: veri taşıma çekirdeği (17 bulgu)

§VIII ve §IX ekranları ve boyut düşürme hattını taradı. Bu tur **altındaki
katmanı** denetledi — kullanıcının gerçek dosyalarını taşıyan, silen, geri
yükleyen kod: `file_ops.dart`, `trash_service.dart`, `job_queue.dart`,
`op_history.dart`, ilerleme penceresi. Buradaki bir hata geri alınamaz.
17 bulgu; 15'i kapatıldı, 2'si **bilinçli olarak kapatılmadı** (aşağıda gerekçe).
Kilit: yeni `test/fm_transfer_safety_test.dart` (10 test).

### CRITICAL — çöp kaydı üzerine yazılıyordu; yarım yazma TÜM çöpü görünmez yapıyordu
`index.json` doğrudan `writeAsString` ile güncelleniyordu; bu çağrı dosyayı önce
**kısaltır**. Yazma kesilirse (kart dolu — kullanıcı zaten bu yüzden siliyor;
kart çıkarıldı; süreç öldü) dosyada yarım JSON kalıyor ve `_readIndex` bozuk
JSON'u **boş listeye** çeviriyor. Sonuç: çöp kutusu "boş" görünüyor, o turdaki
dosyalar VE tüm eski kayıtlar birden yok oluyor; baytlar `.dosya-okuyucu-cop`
içinde `1753…-12-rapor.pdf` gibi adlarla, `FsScan`ın atladığı gizli klasörde
kalıyor — kullanıcı ne görebiliyor, ne geri alabiliyor, ne "Yer aç" ile
bulabiliyor. **Düzeltme:** geçici dosya + `rename` (atomik). Aynı sınıf hata
`op_history.json`de de vardı (tüm geri alma geçmişi) → o da atomik.

### CRITICAL — dosya çöpe taşındı ama KAYDI yazılamadıysa dosya yok sayılıyordu
`moveToTrash` önce taşıyıp sonra kayıt yazıyor ve aradaki hata için koruma yoktu
(ters durum için — kaynak yerinde kalmışsa — koruma vardı). İki gerçek tetikleyici
bulundu: (a) çok uzun ad → id ekiyle 255 baytı aşıyor, yedek yoldaki İKİNCİ
`rename` korumasız olduğu için hata dışa fırlıyor; (b) kart dolu → kayıt yazımı
patlıyor. İkisinde de dosya kullanıcının klasöründen gitmiş, çöpte de kayıtsız
(görünmez) kalıyor. **Düzeltmeler:** ikinci `rename` korundu (ad çevrilemezse
dosya indiği adda bırakılır ve kayıt **o adı** gösterir) + kayıt yazılamazsa
dosya **eski yoluna geri alınır** ve hata bildirilir; geri alma da olmazsa yol
hata metnine yazılır. Kural: **çöpte dosya varsa kaydı da vardır.**

### CRITICAL — `FmConflict.skip` + klasör taşıma: atlanan çocuğun TEK kopyası siliniyordu
Klasör dalında çocuk sonuçları yok sayılıyor, sonra kaynak
`delete(recursive: true)` ile siliniyordu. Ad çakışması yüzünden **atlanan**
çocuk hata atmadığı için silme yine koşuyor: hedefte zaten farklı içerikli bir
dosya var, kaynaktaki tek kopya yok oluyor. **Düzeltme:** herhangi bir çocuk
atlandıysa kaynak klasör KORUNUR. (UI şu an `skip`/`overwrite` göndermiyor —
`FmConflict` genel API ve bir sonraki doğal özellik "çakışma penceresi"; hata
gelmeden kapatıldı.)

### CRITICAL — `FmConflict.overwrite` hedefi, yerine bir şey koymadan siliyordu
Önce `deleteSync(dest)`, sonra `copy`. Kopyalama patlarsa (kart doldu, kaynak
okunamadı) hedefteki veri gitmiş, yerine bir şey konmamış olur. `rename`/`copy`
POSIX'te var olan yolun üstüne zaten yazıyor. **Düzeltme:** ön silme kaldırıldı.

### HIGH — iptal edilen taşımada "Geri al" KAYBOLUYORDU
İptal dalı `transfers`ı boş döndürüyordu: 200 fotoğrafın 90'ı taşındıktan sonra
"İptal"e basan kullanıcı "90 öğe taşındı" okuyor ama geri alma düğmesini
(koşulu `transfers.isNotEmpty`) hiç görmüyordu. Otomatik düzenlemede daha kötüsü:
o taşımalar `OpHistory` kaydına hiç yazılmadığı için "Son işlemler"den de geri
alınamıyorlardı. Ayrıca `FsEvents.changed()` de atlanıyor, açık ekranlar taşınmış
dosyaları eski yolunda göstermeye devam ediyordu. **Düzeltme:** iptalde de
`transfers` + `FsEvents.changed()`.

### HIGH — "İptal" tek dosyada hiç iptal etmiyordu ve sonuç bunu SÖYLEMİYORDU
İptal yalnız döngü başında yoklanıyor; `File.copy`/`rename` bölünemez. 3 GB'lık
tek bir videoda "İptal" hiçbir şeyi durdurmuyor ve sonuçta `cancelled == false`
kaldığı için arayüz "1 öğe taşındı" diyordu. Kopyalamayı kesmek elimizde değil,
ama **olanı doğru söylemek** elimizde: sonuç artık iptal isteğini yansıtıyor ve
arayüz "Durduruldu · N öğe çoktan taşındı (süren aktarma yarıda kesilemiyor)"
yazıyor.

### HIGH — kaynak, kopya DOĞRULANMADAN siliniyordu (çapraz birim)
Sıra doğruydu (kopya önce, silme sonra) ama boyut karşılaştırması yoktu: kısa
yazmayı hata olarak bildirmeyen bir bağlama noktasında (sdcardfs/FUSE/MTP) tek
sağlam kopya silinebilirdi. **Düzeltme:** kopya boyutu kaynakla eşit değilse
yarım hedef silinir, hata atılır, **kaynak yerinde kalır**.

### HIGH — "Çöp kutusu boşaltıldı · N öğe · X yer açıldı" silinemeyenler için de yazılıyordu
`deleteForever` her hatayı yutup kaydı yine de düşürüyordu: kart salt-okunur
takılıysa ya da dosya başka uygulamada açıksa baytlar diskte kalıyor, kayıt
gidiyor → dosya çöp ekranında görünmüyor, `FsScan` çöpü atladığı için "Yer aç"
da bulamıyor; kullanıcının 4 GB'ı uygulama içinden **asla** geri kazanılamaz
hâle geliyor, üstelik ekran "4,2 GB yer açıldı" diyordu. **Düzeltme:** gerçek
hata YUKARI çıkar ve kayıt korunur (dosya zaten yoksa kayıt düşer — o hata
değil). Böylece var olan "N öğe silinemedi" dalları ilk kez gerçekten çalışıyor.
Ek: klasörler kayda `0` bayt yazılıyordu ("4 GB klasörü boşalttım, 0 B yer
açıldı") → çöpe atarken gerçek boyut ölçülüyor (`FsScan.folderSize`).

### HIGH — eşzamanlı çöp işlemleri kayıt düşürüyordu (oku-değiştir-yaz yarışı)
"Arka plana al" sayesinde kullanıcı uzun bir silmeyi arka plana atıp hemen başka
bir silme/geri yükleme başlatabiliyor. A okur (42 kayıt) → B okur (42) → B 43
yazar → A kendi 43'ünü B'nin kaydı olmadan yazar: B'nin dosyası çöpte, kaydı yok
→ görünmez ve geri alınamaz. **Düzeltme:** kayıt değişiklikleri süreç genelinde
bir `Future` zinciriyle sıraya alınıyor (`_withIndexLock`, static).

### HIGH — "Geri al" dosyanın ADINI sessizce değiştiriyordu
`undoMove`, `moveAll` üzerinden gittiği için hedef adı `basename(dest)`ten
üretiyordu; taşımada çakışma olduysa (`rapor.pdf` → `rapor (1).pdf`) geri alma
dosyayı `rapor (1).pdf` olarak geri getiriyor, arayüz ise sadece "Geri alındı."
diyordu. **Düzeltme:** eski ad boşsa dosya o ada döndürülür.

### MEDIUM (kapatıldı)
- İptal edilen KLASÖR aktarımı "başarılı" sayılıyordu: 5000 fotoğraflık albümün
  900'ü kopyalanmışken kullanıcıya "kopyalandı" deniyor, geri alma kaydına yarım
  bir ağaç yazılıyordu → iptalde `null` döner, `succeeded` artmaz.
- `succeeded` atlanan dosyaları da sayıyordu (hem `skipped` hem `succeeded`).
- Kısmi hata bildirimi: yalnız ilk hata metni yazılıyor, kaç dosyanın olduğu/
  olmadığı söylenmiyordu → "N öğe taşındı, M öğe aktarılamadı: …". Ayrıca
  `deleteEntries` hepsi başarısız olsa bile `true` dönüyordu (çağıranlar seçimi
  temizleyip listeyi tazeliyor, "oldu" sanılıyordu).
- **Kısmi geri alma kaydı siliyordu:** 60 dosyanın 40'ı dönmüşse kayıt
  düşürülüyor, kalan 20'nin nereye gittiğini söyleyen tek bilgi (kaynak→hedef
  eşlemesi) yok oluyor ve o dosyalar bir daha ASLA geri alınamıyordu → kayıt
  yalnız tamamı geri alındıysa düşer.
- Arka plan ilerleme şeridi `hideCurrentSnackBar()` ile kapanıyordu: SnackBar'lar
  sırayla gösterildiği için bu, araya giren bir sonuç mesajını ("5 öğe taşındı ·
  Geri al") süpürebiliyordu → şeridin kendi denetleyicisi (`controller.close()`).
- Yalnız büyük/küçük harf değiştiren yeniden adlandırma SD kartta (FAT32/exFAT)
  "bu adda bir öğe zaten var" diye reddediliyordu (dahili depolamada çalışıyor —
  tutarsız) → geçici ada uğrayıp hedefe inen iki adımlı `rename`.

### BİLİNÇLİ KAPATILMAYAN İKİ BULGU (gerekçeli)
1. **`JobQueue`ta zaman aşımı/gözcü yok.** Gövdesi hiç dönmeyen bir iş kuyruğu
   kalıcı olarak kilitler (sonraki işler "Sırada"da bekler, bildirim şeritte
   asılı kalır, çare uygulamayı zorla kapatmak). Zaman aşımı EKLENMEDİ: kuyruğun
   gerçek sakinleri dakikalarca süren meşru işler (video kodlama, bayt bayt
   tarama) ve "iptali 30 saniyede uygulamayan işi terk et" kuralı, dosya
   değiştiren iki işi (ör. "Yer aç: temizleniyor" + yeni bir iş) aynı anda
   koşturabilirdi — yani gözlemlenmemiş bir kilitlenmeyi önlemek için
   gözlemlenmiş bir sınıf hatayı (çöp kaydı yarışı) yeniden açmak olurdu.
   Kuyruk eşzamanlılığının 1 olması bilinçli bir güvenlik kararı; onu iptal
   yolundan delmek yanlış takas. Gerçek çözüm, işleri tek tek kesilebilir
   yapmak (her uzun döngüde `throwIfCancelled`) — şu an kuyruğa giren tüm
   gövdelerde bu var; kesilemeyen tek adım `DuplicateFinder.scan` ve o da
   sonlu.
2. **İlerleme sayacı hızlı yollarda atlıyor.** Klasörün tamamı tek `rename` ile
   taşındığında sayaç 1/5000 gösterip sona atlıyor. Düzeltmek ya ağacı ikinci
   kez yürümek ya da ilerleme protokolünü değiştirmek demek; sayı hiçbir zaman
   VERİ hakkında yanlış bir şey söylemiyor (yalnız çubuk kaba). Kozmetik olarak
   kabul edildi.

### Denetimin bulmadığı, doğrulanan yerler
Çöpten geri yükleme hedefi ezmiyor (her zaman `uniquePath`), çöp içinde ad
çakışması olamıyor (ms + süreç sayacı), "çöpü boşalt" çöp klasörü dışına
çıkamıyor (yol `sanitizeName`den geçmiş bir taban adla kuruluyor), taşımada
silme sırası her yerde doğru (kopya önce), `_pump` hata yutmuyor, ilerleme
kısması SON raporu düşürmüyor (`report` alanları kapıdan önce yazıyor,
`_pump` bitişte `notifyListeners` + `onFinished` çağırıyor).

### Doğrulama (4. tur)
`flutter analyze`: 0 hata, 0 yeni uyarı (39 info/warning eski koddan).
`flutter test`: **863 test geçti** (3. tur sonunda 853).
Yeni: `test/fm_transfer_safety_test.dart` (10).

---

## 2026-07-30 — Video küçültme: dikey→yatay bozulması, hız ve "İşlemler" ekranı

Kullanıcı geri bildirimi (ekran görüntüsüyle): *"video boyutu düşürürken o
işlemler için bir özel sayfa yok, nerede ne oluyor, başlatıldı mı başarısız mı
oldu göremiyorum… ana ekranda bir yer/kart/buton lazım"*, *"çok yavaş"*,
*"küçültülen video nereye gitti belli değil, nereden açacağım bilinmiyor"*,
*"dikey videonun boyutu küçültülünce yatay gibi genişletmiş"*.

### 1) KÖK NEDEN — dikey video yatay/ezik çıkıyordu (veri bozan hata)
`FfmpegVideo.buildArgs` hedefi **mutlak sayı** olarak yazıyordu
(`scale=1280:720`) ve o sayılar `probe`un okuduğu ölçüden geliyordu. Telefon
videoları neredeyse her zaman **yatay kodlanıp** "90° döndür" verisiyle
saklanır; ffprobe düşerse ölçü yedek eklentiden (`video_compress` →
`MediaMetadataRetriever`) geliyor ve **o döndürmeyi ölçüye katmıyor** → hedef
"1280x720" hesaplanıyor. ffmpeg ise süzgece giren kareyi kendi döndürme
verisiyle çeviriyor (autorotate) → dikey kare zorla yatay çerçeveye basılıyor:
video enine yayılıyordu.

**Çözüm:** mutlak ölçü yerine **kutuya sığdırma** —
`scale=w=L:h=L:force_original_aspect_ratio=decrease:force_divisible_by=2`
(L = hedefin uzun kenarı). Çıktı oranı artık **kaynağın kendi karesinden**
çıkıyor, döndürme bilgisine hiç ihtiyaç yok. Büyütme riski yok çünkü
`targetSize` hedefi kaynakla sınırlıyor (kutu ≤ kaynağın uzun kenarı).
- **REDDEDİLEN yol:** `scale=w='if(gt(iw\,ih)\,min(iw\,L)\,min(iw\,S))'…`
  ifadeleri. Doğru çalışırdı ama filtre ifadeleri **virgül** içerir, virgül de
  filtre zincirinin ayırıcısı: tek bir kaçırma/tırnak hatası "video hiç
  dönüşmüyor" demek ve bu ortamda cihazda doğrulanamaz. Seçenek tabanlı çözüm
  aynı sonucu virgülsüz veriyor (test: "süzgeç ifade İÇERMEZ").
- **Serbest en×boy korundu:** kullanıcı iki sayıyı da yazdıysa birebir
  uygulanır (`VideoScaleMode.exactBoth`); tek kenar yazıldıysa diğeri `-2` ile
  orandan hesaplanır — o da yönden bağımsız. Yani 2026-07-29'un "1234x568 de
  verilebilmeli" sözü bozulmadı.

### 2) Hız — yazılım kodlayıcı en sona alındı
Motor sırası artık: **donanım kodlayıcı (h264_mediacodec) → yedek motor
(video_compress/native MediaCodec, o da DONANIM) → yazılım kodlayıcı (mpeg4)**.
Eskiden mpeg4 ikinci sıradaydı; donanım kodlayıcısı bulunamayan cihazlarda
kullanıcı sürekli **yazılım kodlamayı** yiyordu (telefonda dakikalar).
Serbest ölçü istendiğinde sıra değişir (yedek motor birebir ölçü veremez;
yazılım kodlayıcı verir). Ek hız: **`fps` süzgeci `scale`den ÖNCE** (atılacak
kareler artık ölçeklenmiyor — 60→30 fps'te ölçekleyicinin işinin yarısı çöpe
gidiyordu) ve mpeg4'te `-threads 0` (dilim çoklu izleği; tek izlekte 1080p
kodlamak dakikalar).
- **Dürüstlük:** hangi motorun koştuğu + yüzde + **ölçülen** kalan süre işlem
  satırına yazılıyor ("720×1280 · %42 · ~2 dk kaldı · donanım kodlayıcı").
  Yavaşlığın nedeni neredeyse her zaman motor; kullanıcı bunu görmeden
  "takıldı mı?" diye bakıyordu. Tahmin ilk 3 saniyede YAZILMAZ (yanlış süre
  yazmak hiç yazmamaktan kötü).
- **REDDEDİLEN yol:** `-hwaccel mediacodec` ile donanım ÇÖZME. Yüzey/pix_fmt
  pazarlığı kırılgan, bu ortamda cihazda doğrulanamıyor ve başarısızlığı
  sessizce yazılım koduna düşürürdü. `libx264`/`openh264` de yok: lisans (GPL)
  ve `min` varyantında openh264 bulunmuyor.
- **TUZAK:** çıktı doğrulaması (süre/okunabilirlik) başarısızsa **başka motor
  DENENMEZ** — kaynak bozuksa (yarıda kesilmiş kayıt, hasarlı `moov`) her motor
  yarım üretir, kullanıcı dakikalarca bekleyip aynı yere varır. Bunun için
  `VideoTranscodeException.fatal` bayrağı eklendi; motor döngüsü yalnız
  `fatal: false` hatalarda sıradakine geçiyor.

### 3) "İşlemler" ekranı + sonuç şeridi + çıktı dosyaları
- Yeni ekran `lib/screens/fm/jobs_screen.dart`: süren/bekleyen/bitmiş işler,
  **ne kadar sürdüğü**, özet ve **işin ürettiği dosyalar** (ad + boyut + klasör,
  dokunarak açma, "Klasörü aç"). Eski alt sayfa (`_JobsSheet`) kaldırıldı —
  iki arayüz olsa biri geride kalırdı.
- Ana ekrandaki **İşlemler** kutusu (Araçlar'ın ilk sırası) canlı sayaç
  gösteriyor ("1 sürüyor" / "3 biten"); araç ızgarası `JobQueue`ya bağlandı.
- **Alt şerit iş bitince kaybolmuyor:** sonuç satırı (başarılı/başarısız simgesi
  + özet + "Göster") kullanıcı kapatana kadar durur (`FmJob.dismissed`).
  Eskiden şerit yalnız SÜREN işi gösteriyordu → iş bitince sonuç yok oluyordu
  ve iş listesine girecek kapı da kalmıyordu.
- `FmJob.outputs` + `JobHandle.addOutput`: boyut düşürme her başarılı çıktıyı
  kaydediyor; özet satırında "Kaydedildi: <klasör>" yazıyor (sistem bildirimine
  de aynı metin gidiyor). Geçmiş `historyLimit = 40` ile sınırlı (süren iş ASLA
  düşmez), süreler `startedAtMs/finishedAtMs` ile ölçülüyor.

### YENİ VE ÖNEMLİ — bulut oturumunda ffmpeg SÜZGECİ gerçekten koşturulabiliyor
`pip install imageio-ffmpeg` ile **ffmpeg 7.0.2 ikilisi** geliyor (apt gerekmiyor).
Yani video süzgeçleri artık varsayımla değil **ölçümle** doğrulanıyor. Bu turda
hatanın kendisi birebir üretildi:
```
# Dikey telefon videosunu taklit et (yatay kodlanmış + 90° döndürme verisi)
ffmpeg -f lavfi -i testsrc=size=1920x1080:rate=30:duration=2 -c:v libx264 yatay.mp4
ffmpeg -display_rotation 90 -i yatay.mp4 -c copy dikey.mp4
```
| süzgeç | dikey kaynak (ekranda 1080x1920) | yatay kaynak |
|---|---|---|
| ESKİ `scale=1280:720` | **1280x720 (hata: yatay/ezik)** | 1280x720 |
| YENİ kutuya sığdırma | **720x1280 ✓** | 1280x720 ✓ |

Ayrıca ölçülenler: çıktıda döndürme verisi KALMIYOR (oynatıcı ikinci kez
çevirmiyor), 480x640 kaynağa 640 kutusu verilince ölçü değişmiyor (büyütme yok),
tek kenar biçimi (`scale=w=600:h=-2`) dikey kaynakta 600x1066 veriyor (yön
korunuyor), tek sayıya düşen ölçüler çift sayıya yuvarlanıyor (H.264 kabul etti).
**TUZAK:** libx264 **tek sayılı kaynağı** kodlamıyor — test videosu üretirken
ölçüler çift olmalı, yoksa hata süzgeçte sanılıyor.

### Doğrulama
Bulut Linux oturumunda Flutter **3.29.3** (CI ile aynı) indirilip koşturuldu:
`flutter analyze` **0 hata, 0 yeni uyarı** (39 info/warning eski koddan),
`flutter test` **883 test geçti** (önceki tur 877 + yeni 6 dosya/testler).
Yeni test dosyası: `test/fm_jobs_screen_test.dart` (5 widget testi — sonucun ve
çıktı dosyalarının GERÇEKTEN göründüğünü kilitliyor). `fm_ffmpeg_video_test`
ölçek süzgeci + kalan süre grupları, `fm_job_queue_test` çıktı/şerit/süre/geçmiş
testleriyle büyüdü. Cihazda doğrulanamayan tek şey kodlamanın kendisi (Android
SDK/telefon yok) — o yüzden süzgeç ve motor sırası saf fonksiyonlara ayrılıp
testlendi.

---

## 2026-07-30 — İngilizce + Arapça dil desteği; Excel/Word sadakatinde RTL turu

Kullanıcı isteği: *"ingilizce ve Arapça dilleri ekleyelim"*, *"sadakat
geliştirmelerine devam Excel word özellikle"*. İki iş aynı turda çünkü Arapça
**yalnız çeviri değil YÖN** demek: Excel'in `rightToLeft` sayfası ve Word'ün
`w:bidi` paragrafı bizde okunuyordu ama **hiç kullanılmıyordu**.

### A) Dil altyapısı — `lib/core/l10n/`
- `AppLanguage { system, tr, en, ar }` + `AppStrings` (anahtar → **üç alanlı
  kayıt** `(tr, en, ar)`), `LocalizationsDelegate`, `context.t('anahtar')`.
- **Neden üç alanlı kayıt, neden dil başına ayrı `Map` değil:** kayıtta bir
  dili unutmak **derleme hatası**; üç `Map`te eksik anahtar ancak kullanıcının
  ekranında (anahtarın kendisi yazılı olarak) fark edilirdi.
- **Neden `.arb` + `gen_l10n` DEĞİL (reddedilen yol):** üretilen kod CI'da ek
  bir adım ister; çıktı depoya girmezse APK derlemesi kırılır. Tablo düz Dart,
  ek araç yok.
- `flutter_localizations` (SDK) eklendi — Material/Widgets katmanının kendi
  metinleri ve Arapça'da **sağdan sola akış** oradan geliyor. Çakışma yok:
  Flutter 3.29.3 `intl 0.20.2` pinliyor, `syncfusion_flutter_pdf` zaten aynı
  sürümü çekiyordu.
- **TUZAK — `load()` `async` olursa ekran bir kare BOŞ çizilir.** `Localizations`
  delege çözülene kadar hiçbir şey çizmiyor; tablo kodda olduğu için
  `SynchronousFuture` döndürülüyor. İlk yazımda bu yüzden widget testleri
  "0 widget bulundu" diye düşmüştü — ürün tarafındaki karşılığı dil
  değiştirmede görünür bir çakma olurdu.
- `AppState.language` kalıcı (`app_language`); Ayarlar'da seçim. Diller **kendi
  dillerinde** listeleniyor (Türkçe / English / العربية) — dilini arayan
  kullanıcı o an anlamadığı bir dilde yazılmış listeyi okuyamaz.
- Çevrilen ekranlar: **ana ekran, Ayarlar, Excel, Word** (bu turda hedeflenen
  kapsam). Kalan ekranlar Türkçe — bkz. KALANLAR.
- Kilit: `test/l10n_test.dart` (10) — üç dilin de dolu olması, **yer
  tutucuların üç dilde aynı** olması (`{error}`ı bir dilde unutmak o dilde
  hatayı GİZLER) ve **kodda `\.t('x')` ile çağrılan her anahtarın tabloda
  bulunması** (lib/ taranıyor; yazım hatası ekranda anahtarın kendisini
  gösterirdi).

### B) Excel: `excel` paketinin YAZAMADIKLARI geri kondu (`xlsx_save_patch.dart`)
2026-07-28 §B'de "Kapatılamayan" diye bırakılan gap kapandı. `excel 4.0.6`
zip'i ürettikten SONRA sayfa XML'i yamalanıyor:
- **Gizli satır/sütun** — paketin yazma API'sinde karşılığı yok
  (`_createNewRow` yalnız `r`/`ht`/`customHeight` yazıyor, `<cols>` her
  kayıtta baştan kuruluyor). Kullanıcı gizlediği sütunu kaydedip Excel'de
  açtığında sütun geri geliyordu.
- **Hücresiz satırın yüksekliği** — `<row>` yalnız hücresi olan satır için
  üretiliyor; ayırıcı boş satırların özel yüksekliği kayboluyordu.
- **Sayfa yönü** `rightToLeft`.
- **TUZAK — `Archive.files` DEĞİŞTİRİLEMEZ** (archive 3.6.1): yerinde yazmak
  `UnmodifiableListMixin` hatası veriyor ve yamadaki `try/catch` bunu sessizce
  yutup girdiyi aynen döndürüyordu (12 testin 5'i bu yüzden kırmızıydı, hata
  yama mantığında SANILDI). Çözüm: yeni `Archive` kurup dokunulmayan dosyaları
  taşımak.
- **TUZAK — aralıklı `<col min="1" max="10">`:** gerçek dosyalarda tek `<col>`
  onlarca sütunu kapsıyor; ona `hidden="1"` eklemek **10 sütunu birden**
  gizlerdi. Aralık üçe bölünüyor (`1-4` · `5-5 hidden` · `6-10`), genişlik üç
  parçada da korunuyor.
- **TUZAK — ECMA-376 `CT_Worksheet` çocuk SIRASI zorunlu:** `<cols>`
  `<sheetData>`dan önce gelmeli, yoksa Excel "onarılamayan içerik" diyor.
  `_insertOrdered` şema sırasına göre yerleştiriyor.
- Sayfa adı → `sheetN.xml` eşlemesi **`r:id` üzerinden** çözülüyor; `sheet1.xml`
  in birinci sayfa olduğu garanti DEĞİL (Excel sayfa silip ekledikçe numaralar
  karışır).
- **Bozuk girdide yama ATLANIR, baytlar aynen döner** — kaydetmeyi kırmaktansa
  yamayı atlamak doğru.
- Kilit: `test/xlsx_save_patch_test.dart` (12), `XlsxEditor.save` üzerinden
  gidiş-dönüş dahil.

### C) Excel: dosyadaki sayfa yönü artık ÇİZİLİYOR
`xlsx_reader` `rightToLeft`i okuyordu, `layout`ta duruyordu, **hiçbir yerde
kullanılmıyordu** — Arapça/İbranice bir tablo bizde ters (A sütunu solda)
açılıyordu.
- Izgara `Directionality` ile sarıldı. `Row`/`SingleChildScrollView` yönü
  kendiliğinden uyguluyor; **kaydırma konumu her iki yönde de BAŞLANGIÇTAN
  ölçüldüğü için** sanallaştırma (`cols.startAt`) ve `_ensureVisible`
  matematiği aynen geçerli kaldı. `_cellAtGlobal` zaten `hitTest` kullanıyor,
  koordinat çevirisi gerekmedi.
- **Yön ARAYÜZ DİLİNDEN BAĞIMSIZ:** yön belgenin özelliği. Bu yüzden yön her
  iki durumda da AÇIKÇA yazılıyor — sarmalayıcı olmasaydı Arapça arayüzde
  soldan sağa her tablo da ters çizilirdi. (Excel de böyle davranır.)
- `general` (açık hizalaması olmayan) hücreler aynalanıyor: sağdan sola
  sayfada **metin sağa / sayı sola**. AÇIK `left`/`right` aynalanmaz.
- Pinch odağı aynalandı (`focal.dx` daima soldan, kaydırma başlangıçtan).
- ⋮ menüsüne **Sayfa sağdan sola** anahtarı (Excel'in *Sayfa Düzeni → Sayfayı
  Sağdan Sola* düğmesi); kaydetmede B'deki yamayla dosyaya yazılıyor.
- Kilit: `test/spreadsheet_rtl_test.dart` (7).

### D) Word: `w:bidi` okunuyor ve uygulanıyor
- `DocxParagraph.rtl` (`w:pPr/w:bidi`) ve `DocxEditor.rightToLeft`
  (`w:sectPr/w:bidi`, yoksa metinli paragrafların **çoğunluğu**).
- **TUZAK — `findAllElements('w:bidi')` YANLIŞ:** bölüm sonu taşıyan bir `w:p`
  içinde `w:pPr/w:sectPr/w:bidi` bulunabilir; o BÖLÜMÜN yönüdür. Yalnız
  `w:pPr`nin doğrudan çocuğu sayılıyor, yoksa soldan sağa paragraf sırf bölüm
  sonunu taşıdığı için sağa yaslanırdı.
- Boş paragraflar çoğunluk hesabına GİRMİYOR (Word belgeleri metinsiz
  paragrafla dolu; sayılsalardı Arapça belge "çoğunluk LTR" görünürdü).
- Yedek metin editöründe paragraf `Directionality` ile sarılıyor, seçim şeridi
  ve iç boşluk `BorderDirectional`/`EdgeInsetsDirectional`. Dosyada hizalama
  **yazmıyorsa** `TextAlign.start` (eskiden koşulsuz `left` → Arapça belgede
  her paragraf sola yapışıyordu); AÇIK `left`/`right` mutlak kalıyor
  (`DocxParagraph.hasExplicitAlign`).
- `viewer.html`: gömülü docx-preview **bölüm düzeyi** `w:bidi`yi yok sayıyor
  (kendi ayrıştırıcısında `case "bidi": break`) → `setDocDir(rtl)` köprüsü
  eklendi, `DocxView` çizimden ÖNCE çağırıyor.
- `viewer.html` font: Carlito/Tinos/Arimo **yalnız Latin-Yunan-Kiril** taşıyor.
  `unicode-range` olmadan tarayıcı "Calibri" adını görüp bu dosyaları yükler ve
  Arapça harfleri onlarda arar. Arapça/İbranice aralıkları ayrı `@font-face` ile
  cihazın kendi fontuna (`local('Noto Naskh Arabic')`) yönlendirildi; metrik
  uyumu zaten Latin için anlamlı, Arapça'da kayıp yok.
- Kilit: `test/docx_rtl_test.dart` (9).

### Doğrulama
Bulut Linux oturumunda Flutter **3.29.3** (CI ile aynı): `flutter analyze`
**0 hata**, yeni dosyalarda 0 uyarı (39 info/warning eski koddan, baştaki
sayının aynısı). `flutter test` **921 test geçti** (tur başında 883; yeni 38).
Cihazda görsel doğrulama YAPILMADI (Android SDK/telefon yok) — Arapça arayüzün
ve sağdan sola Excel/Word sayfalarının telefonda görünümü KALANLAR'da.

---

## 2026-07-30 (II) — Google Drive bağlantısı (`drive.file`) ve NAS araştırması

Kullanıcı iki şey sordu: *"NAS (FTP, FTPS, SFTP, SMB, WebDAV, LAN) yapabilir
miyiz"* ve *"Google Drive bağlantısı yapabilir miyiz"*. Karar: **önce Drive**;
NAS sonraki tura, SMB'de "önce dene, tutmazsa listeden çıkar".

### A) Paket uyumluluğu TAHMİN DEĞİL, ÖLÇÜM
Hepsi bizim sürüm duvarımıza (Flutter 3.29.3 / Dart 3.7) karşı
`flutter pub add --dry-run` ile denendi — çözülen sürümler:

| iş | paket | çözülen sürüm |
|---|---|---|
| SFTP | `dartssh2` | 2.22.5 |
| FTP/FTPS | `ftpconnect` | 2.0.7 |
| WebDAV | `webdav_client` | 1.2.2 |
| LAN keşfi | `multicast_dns` | 0.3.3 |
| Drive | `googleapis` / `googleapis_auth` | 15.0.0 / 2.0.0 |
| SMB | `smb_connect` | **0.0.9** |

Hiçbiri çözümlemeyi kırmıyor. **SMB tek zayıf halka:** olgun saf-Dart istemci
yok, tek aday 0.0.9. Java `smbj`'yi platform kanalıyla sarmak **kendi
`android/` klasörümüzü depoya sokmak** demek — CI iskeleti her derlemede
`flutter create` ile üretiyor; "tek paket için tüm derleme zincirini oynatma"
daha önce reddedilmiş bir yol (bkz. `light_compressor`, `usage_stats`).
PC→telefon FTP **sunucusu** hiç paket istemiyor: `dart:io` `ServerSocket`.

### B) Drive — `googleapis` DEĞİL, düz REST
`googleapis` Google'ın bütün API'lerini tek pakette taşıyor; bize altı uç nokta
gerekiyordu. Depoda zaten elle yazılmış REST istemcisi var
(`gemini_service.dart`) ve testi `http.runWithClient` + `MockClient` ile
kuruluyor — aynı desen izlendi, **yeni bağımlılık girmedi**.
`lib/services/fm/drive_service.dart` + `lib/models/drive_file.dart`.

### C) KARAR — kapsam `drive.file`, `drive` DEĞİL
"Tüm Drive'ı gez" için gereken `drive`/`drive.readonly` Google'ın
**restricted scope**'u: yayınlanan uygulamada yıllık ve **ÜCRETLİ** üçüncü
taraf güvenlik denetimi (CASA) şart. Projenin "ücretsiz" ilkesiyle
bağdaşmıyor. `drive.file` kısıtlı değil ve yalnız **uygulamanın kendi
yüklediği/oluşturduğu** dosyaları görüyor.

**Bunun kullanıcıya SÖYLENMESİ ürünün parçası:** yazılmazsa Drive'ında yüzlerce
dosyası olan kullanıcı boş liste görüp uygulamayı bozuk sanar. Bilgi şeridi
`drive_screen`de **liste doluyken de** duruyor (yalnız boşken gösterilseydi
tek dosya yükleyen kullanıcı açıklamayı bir daha görmezdi) ve **Drive'daki
diğer dosyalara nasıl ulaşılacağını** yazıyor: *Dosya Aç → sistem seçicisi*.
Android'in Depolama Erişim Çerçevesi Drive'ı sağlayıcı olarak listeliyor ve o
yol hiçbir yetki istemiyor — yani "her Drive dosyasını aç" yeteneği zaten
vardı, sadece görünür değildi.

### D) Tuzaklar (kodda ve testte sabitlendi)
- **Google'ın kendi biçimleri (`vnd.google-apps.*`) `alt=media` ile
  İNDİRİLEMEZ** — Drive 403 döndürür. `export` uç noktası + hedef MIME şart
  (Dokümanlar→docx, E-Tablolar→xlsx, Slaytlar→pptx, Çizimler→pdf).
- **O biçimlerde `size` alanı HİÇ GELMEZ.** Arayüz "0 B" değil **"—"**
  gösteriyor: bayt karşılığı olmaması boş olmak demek değil.
- **Drive'daki adın uzantısı yoktur** ("Bütçe"). İndirirken dışa aktarım
  uzantısı eklenmezse telefonda hiçbir uygulama açamaz (`DriveFile.localName`).
- **`fields` açıkça istenmeli:** yazılmazsa Drive yalnız `id`+`name` döndürür,
  boyut/tarih sütunları sessizce boş kalırdı.
- **Drive sorgu dilinde tek tırnak sınırlayıcı** → arama metnindeki kesme
  işareti kaçırılmazsa sorgu bozulur ("Ali'nin raporu").
- **`multipart/related` gövdesi BAYT olarak kurulmalı;** metne çevirip
  birleştirmek UTF-8 olmayan içeriği bozardı (test bunu birebir ölçüyor).
- **TUZAK (kendi hatam) — test kancası "oturum açık" demek DEĞİL:**
  `authHeadersOverride` takılıyken `signIn*` koşulsuz `true` dönüyordu, bu
  yüzden "oturumsuz" durumu hiç test edilemiyordu. Artık kanca **başlık
  üretebiliyor mu** diye bakılıyor.
- Hata sessizce yutulmuyor: `DriveException` + `DriveError` (notSignedIn /
  forbidden / notFound / temporary / unknown) ve Drive'ın kendi
  `error.message`'ı kullanıcıya taşınıyor. Sessiz boş liste, gerçekten boş bir
  Drive'dan ayırt edilemezdi.

### E) Bağlantı noktaları
Pano → **Araçlar → Google Drive** kutucuğu; dosyaya uzun basış → **Drive'a
yükle**. Açma yolu **indir-önbelleğe-aç**: uzak dosya uygulamanın kendi
klasörüne iner, sonra mevcut `EntryOpener` zinciriyle açılır — Drive dosyaları
tüm biçim desteğimizden ilk günden yararlanıyor ve `FileOps`un **saf `dart:io`**
değişmezi bozulmuyor. (Alternatif "soyut dosya sistemi katmanı" doğru ama
gezgin/iş kuyruğu/etiket zincirinin tamamını etkiliyor → NAS turunda yeniden
değerlendirilecek.)

### Doğrulama
Flutter 3.29.3 (CI ile aynı): `flutter analyze` **0 hata**, 39 info/warning
(tur başındakiyle aynı, hepsi eski kod). `flutter test` **949 test geçti**
(önceki tur 921; yeni 28: `drive_service_test` 21, `drive_screen_test` 7).
Cihazda doğrulanamayan: gerçek Google oturumu ve OAuth istemci yapılandırması
(google-services.json) — Drive, Firebase ile aynı istemciyi kullanıyor,
yapılandırma yoksa giriş açılmaz. KALANLAR'a yazıldı.

---

## 2026-07-30 (III) — NAS: FTP/FTPS/FTPES · SFTP · SMB · WebDAV · LAN + PC'den FTP

Kullanıcı isteğinin tamamı: *"FTP, FTPS, SFTP, SMB, WebDAV ve LAN gibi uzak ya
da paylaşılan depolama… Ayrıca FTP kullanarak PC'den mobil cihazınıza erişim"*.

### A) Mimari — ortak `RemoteFs` arayüzü, `FileOps`a DOKUNULMADI
`lib/services/fm/remote/`: `remote_fs.dart` (arayüz + `RemoteEntry` +
`RemoteError`/`RemoteException` + saf yol yardımcıları), `sftp_fs` `ftp_fs`
`webdav_fs` `smb_fs` gerçeklemeleri, `remote_fs_factory` (protokol → sınıf).
- **Neden ortak arayüz:** gezgin/indirme/yükleme/silme dört protokolde AYNI
  davranmalı. Ekran protokolü bilseydi her yeni protokol arayüzü de
  değiştirirdi ve davranışlar zamanla ayrışırdı (bu bedel daha önce ödendi:
  iki ayrı iş listesi arayüzü).
- **Neden `FileOps` genelleştirilmedi:** saf `dart:io` olması belgelenmiş bir
  değişmez; etiket/çöp/iş kuyruğu/`PathSideIndex` zincirinin tamamı ona bağlı.
  Uzak dosyalar **indir-önbelleğe-aç** akışıyla yerel dünyaya giriyor →
  PDF/Word/Excel/slayt/video/arşiv desteği ilk günden çalışıyor.

### B) Protokole özgü tuzaklar (hepsi kodda yazılı)
- **FTP'de `TransferType.binary` ŞART.** Varsayılan ASCII kipi satır sonlarını
  çevirir ve resim/zip/pdf'i **bozar**. Testle kilitlendi.
- **FTP kullanıcı adı boşsa `anonymous`** — halka açık sunucular boş adı
  reddediyor.
- **SFTP'de `truncate` olmadan üzerine yazma:** yeni dosya kısaysa eskinin
  kuyruğu kalıyor. `create|truncate|write` birlikte veriliyor.
- **SFTP `modifyTime` SANİYE** — milisaniyeye çevrilmezse tarihler 1970'e yakın.
- **SMB kökü paylaşım listesi**, dosya listesi değil; `IPC$` gibi yönetimsel
  paylaşımlar gizleniyor. Yol biçimi dışarıya `/a/b`, pakete `\a\b`.
- **SMB etki alanı boşsa `WORKGROUP`** — boş değer bazı sunucularda reddediliyor.
- **WebDAV'da şema yazılmazsa `https` varsayılıyor.** http'ye sessizce düşmek
  parolayı şifresiz göndermek demekti.
- **WebDAV klasör silmede yol `/` ile bitmeli**, yoksa bazı sunucular 404 verir.
- **WebDAV'da `ping` (PROPFIND) bağlanışta çağrılıyor:** yanlış adres/parola
  ilk listelemede değil BURADA anlaşılsın (kullanıcı "klasör boş" sanmasın).

### C) LAN keşfi — iki yöntem birlikte, çünkü tek başına ikisi de yetmiyor
`lan_discovery.dart`: **mDNS** (`_smb._tcp`, `_sftp-ssh._tcp`, `_ftp._tcp`,
`_webdav._tcp`) duyuru yapan sunucuyu adıyla verir ama duyuru yapmayanı
bulamaz; bazı ROM'lar çoklu yayını kısıtlıyor. **Alt ağ port taraması**
(/24, 32'lik gruplar, 400 ms) duyuru yapmayanı da bulur. Sonuçlar **akış**
olarak veriliyor — 254 adresin bitmesi beklenseydi kullanıcı "hiçbir şey yok"
sanardı. `169.254.` (APIPA) elenir: o adres "DHCP yok" demek, taraması boşuna.

### D) PC'den telefona FTP **sunucusu** — paketsiz, `dart:io`
`ftp_server.dart`. Hazır Dart FTP *sunucusu* yok (olanlar istemci); `dart:io`
`ServerSocket` ile yazıldı.
- **Kök hapsi (`resolve`) en kritik parça.** Olmasaydı sunucu telefonun TÜM
  dosya sistemini ağa açardı. Karar: kökün üstüne çıkan yol **reddedilmiyor,
  köke sıkıştırılıyor** — FTP istemcileri kökte `CWD ..` göndermeyi normal
  sayıyor, hata döndürmek gezinmeyi kilitliyor. Güvenlik sözü "reddet" değil
  **"sonuç her zaman kökün içinde"**; test bunu ölçüyor.
- **Yalnız PASİF mod.** Aktif modda (PORT) sunucu istemciye geri bağlanır;
  NAT/ev yönlendiricisi arkasında neredeyse hep başarısız → "listeleniyor ama
  dosya inmiyor". Pasif dinleyici **port 0** ile açılıyor (sabit port ikinci
  eşzamanlı aktarımı kırardı).
- **Varsayılan port 2121:** Android'de 1024 altı root ister, 21'e bağlanmak
  sessiz başarısızlık olurdu.
- **Yazma varsayılan KAPALI** — PC'den bakmak isteyen kullanıcı yanlışlıkla
  silme riskini istemez. Kullanıcı adı/parola yanlışsa **aynı** yanıt veriliyor
  (fark, kaba kuvvete ipucu olurdu).
- **Sunucu ekranla birlikte yaşıyor:** ekrandan çıkınca duruyor. Arka planda
  sürseydi kullanıcı telefonunu ağa açtığını unuturdu.
- **BULUNAN GERÇEK HATA (test sayesinde):** ilk yazımda `MLSD` yoktu ve FEAT'te
  de duyurulmuyordu; `ftpconnect` (ve çoğu modern istemci) varsayılan olarak
  MLSD kullandığı için listeleme **502** alıp tamamen çalışmıyordu. MLSD/MLST
  (RFC 3659) eklendi ve FEAT'e yazıldı.

### E) YENİ VE ÖNEMLİ — FTP sunucusu bu ortamda GERÇEKTEN koşturulabiliyor
`test/ftp_server_test.dart` sunucuyu localhost'ta başlatıp `ftpconnect`
istemcisiyle sürüyor: giriş, MLSD listeleme, klasöre girme, indirme, yükleme,
silme ve **512 baytlık ikili içeriğin bozulmadan geçtiği** ölçülüyor. Ayrıca
ham komut testleri: girişsiz komut reddi, kullanıcı/parola ayrımının
sızdırılmaması, yazma kapalıyken STOR/DELE/MKD reddi, kök dışına CWD'de kökte
kalma, SIZE/MDTM/EPSV/FEAT/MLST yanıt biçimleri. Yani "kör push" değil.

### F) Parola saklama — bilinçli sınır, kullanıcıya SÖYLENİYOR
Parola `shared_preferences`ta **düz metin**. Android sandbox'ı başka
uygulamalara kapatıyor ama root'lu/yedeklenmiş cihazda okunabilir.
`RemoteConnection.savePassword` kapatılırsa parola **diske hiç yazılmıyor**
(`toMap` alanı atlıyor) ve her bağlanışta soruluyor; bellekteki nesne oturum
boyunca taşımaya devam ediyor. `flutter_secure_storage` yeni bir platform
bağımlılığı demekti — kullanıcıya seçenek sunmak, ona söylemeden düz metin
yazmaktan dürüst. Form altındaki açıklama bunu birebir yazıyor.

### Doğrulama
Flutter 3.29.3 (CI ile aynı): `flutter analyze` **0 hata**, 39 info/warning
(tur başındakiyle aynı, hepsi eski kod). `flutter test` **1002 test geçti**
(önceki tur 949; yeni 53 — `ftp_server_test` 20, `remote_fs_test` 24,
`remote_browser_screen_test` 9).
**Cihazda doğrulanamayan:** gerçek bir NAS'a (SMB/SFTP/FTP/WebDAV) bağlanma ve
telefonun Wi-Fi'sinde ağ taraması — bu ortamda yerel ağ yok. SMB'nin gerçek
sunucuda çalışıp çalışmadığı KALANLAR'daki karar maddesine bağlı.

---

## 2026-07-30 (IV) — NAS istemcileri GERÇEK sunuculara karşı sınandı: SMB hatası bizdeymiş

Önceki tur NAS'ı yazdı ama istemcilerin hiçbiri gerçek bir sunucuya
bağlanmamıştı (yalnız FTP **sunucumuz** localhost'ta sınanmıştı). Kullanıcı
"yarım iş kalmasın" deyince bu açık kapatıldı.

### A) YENİ VE ÖNEMLİ — dört protokolün de sunucusu bu ortamda kurulabiliyor
| Protokol | Sunucu | Kurulum |
|---|---|---|
| SFTP | OpenSSH | `apt-get install openssh-server`, ayrı `sshd_config`, port 2222 |
| FTP | pyftpdlib | `pip install pyftpdlib` |
| WebDAV | wsgidav | `pip install wsgidav cheroot` |
| SMB | **Samba** | `apt-get install samba` |

`test/remote_live_test.dart` (11 test) bunlara bağlanıyor: listeleme, indirme,
yükleme, **ikili içeriğin bozulmadığı**, klasör oluşturma, yeniden adlandırma,
silme, yanlış parola ve ulaşılamayan port. **Sunucu yoksa test kendini ATLIYOR**
(`markTestSkipped`) → CI kırmızıya dönmüyor. `dart_test.yaml`de `live` etiketi
tanımlı (tanımsız etiket `flutter test` çıktısında uyarı üretiyordu).

### B) BULUNAN GERÇEK HATA — SMB yolunu ters eğik çizgiye çevirmek
`SmbFs.toSmbPath` yolu `/paylasim/klasor` → `\paylasim\klasor` çeviriyordu
("SMB Windows protokolü, ayraç `\` olmalı" varsayımı). **Yanlış:**
`smb_connect` kendi örneğinde `connect.file("/home")` kullanıyor ve
`SmbConnect.getShare` paylaşım adını **ilk `/`e kadar** okuyor. Ters eğik
çizgiye çevrilince tüm dizgi paylaşım adı sanılıyor, tree connect düşüyor ve
sunucu `STATUS_NETWORK_NAME_DELETED` ("The specified network name is no longer
available") döndürüyor.

**Belirti aldatıcıydı:** bağlanma ve **paylaşım listeleme çalışıyordu**, yalnız
paylaşımın İÇİNE girmek düşüyordu. Cihazda "SMB bozuk, paket olgun değil" diye
teşhis edilip protokol listeden çıkarılacaktı — oysa kusur bizdeydi.
Düzeltme: yol **olduğu gibi** geçiyor (`/` ayracı, baştaki `/` garanti).

**Sonuç: SMB ÇALIŞIYOR.** Samba 4.19 (SMB2) üzerinde okuma ve yazma doğrulandı
→ KALANLAR'daki "SMB gerçek sunucu kararı" kapandı. Ekrandaki uyarı da
ölçüme dayandırıldı ("Samba/Windows paylaşımlarıyla sınandı ve çalışıyor;
yalnız SMB3 zorunlu kılan sunucular bağlanmayabilir").

### C) `smb_connect` PORT AYARINI YOK SAYIYOR
`smb_transport.dart` bağlanırken `SmbConstants.DEFAULT_PORT` (445) kullanıyor,
verilen portu kullanmıyor. Formdaki port alanı SMB'de **kapatıldı**: alanı açık
bırakmak kullanıcıya tutulmayacak bir söz verirdi ("yazdım ama bağlanmıyor").

### D) TUZAKLAR (test ortamı kurarken)
- **impacket'in `SimpleSMBServer`ı YETMİYOR.** Bağlanma ve paylaşım listeleme
  çalışıyor, paylaşımın içine girmek düşüyor — yani B'deki hatayı **maskeliyor
  ve yanlış yöne götürüyor**. Gerçek Samba şart.
- **Samba bu konteynerde IPv6 olmadığı için açılmıyor:**
  `smbd_open_one_socket: open_socket_in failed: Address family not supported by
  protocol`. Çözüm: `interfaces = lo 127.0.0.1` + `bind interfaces only = yes`.
  Ayrıca `/run/samba/ncalrpc` elle oluşturulmalı.
- **SFTP kökü kullanıcının EV dizinidir** (`/home/<kullanıcı>`), yapılandırmada
  gösterilen klasör değil.

### Doğrulama
`flutter analyze` **0 hata**, 39 info/warning (değişmedi). `flutter test`
**1014 test geçti** (önceki tur 1002; yeni 11 canlı test + SMB yol testi ikiye
ayrıldı). Canlı testler bu oturumda **gerçekten koştu ve geçti** — dört
protokolün dördü de.

### Ek (2026-07-30 IV) — uzak dosyada düzenleme artık sunucuya geri yazılıyor
Önceki turda açık bırakılmıştı: uzaktan açılan dosya düzenlenip kaydedilince
yalnız yerel önbellek kopyası değişiyor, sunucudaki eski kalıyordu — kullanıcı
"kaydettim" sanıyor, sessiz veri kaybı gibi görünüyordu.

`RemoteBrowserScreen._offerWriteBack`: dosya açılmadan önceki **boyut +
değiştirilme damgası** saklanıyor; görüntüleyiciden dönüşte değişmişse
kullanıcıya "sunucuya yüklensin mi?" diye soruluyor.
- **Neden sorulup otomatik yapılmıyor:** yükleme sunucudaki sürümün üzerine
  yazıyor; kullanıcı dosyayı yalnız incelemiş, editör dokunmuş olabilir.
  Sessizce üzerine yazmak geri alınamayan bir karar olurdu.
- **Neden boyut VE damga birlikte:** yalnız damga güvenilmez (aynı saniyede
  kaydeden editör), yalnız boyut da güvenilmez (aynı uzunlukta düzeltme).
- Yükleme dosyanın **kendi klasörüne, kendi adıyla** gidiyor (yeni dosya
  oluşturmuyor).
- **TUZAK (yine):** `File.stat()` (asenkron) `flutter_test`in sahte saat
  zonunda hiç tamamlanmıyor → ekran sonsuza dek "yükleniyor" kalıyordu ve
  `pumpAndSettle` zaman aşımına uğradı. `statSync` kullanıldı; damga okuma
  birkaç baytlık üstveri işi, dosya içeriği okunmuyor.
- Görüntüleyici çağrısı `openLocalFile` kancasına alındı (testte gerçek
  görüntüleyici açılamıyor). Kilit: 3 test — değişmemişse SORULMAZ,
  "şimdilik yükleme" YÜKLEMEZ, "Yükle" doğru yola/ada/içerikle yükler.

## 2026-07-30 — Arayüz çevirisi tamamlandı (tr/en/ar)

- **Kalan ~460 dizgi çevrildi**; uygulamada Türkçe sabit kullanıcı metni kalmadı.
- **Saf Dart modeller `AppStrings`'i tanıyamaz** (Flutter importu yok, birim testli
  kalsınlar diye). Çözüm: her enum uzantısına `labelKey` / `descriptionKey`;
  metin tek yerde `app_strings.dart` tablosunda, ekran `context.t(x.labelKey)` der.
- **`label` Türkçe bırakıldı — bilinçli.** İki yerde diske/kayda yazılıyor:
  `auto_organize` klasör adı üretiyor ve `op_history` eski özetleri saklıyor.
  Çevrilseydi dil değişince diskteki klasör adları değişir, geçmiş kayıtları
  tutarsızlaşırdı.
- **`AppStrings.current`** eklendi: bildirim, iş kuyruğu, `dart:io` katmanı gibi
  `BuildContext`siz yerler için. Delegate her `load`ta günceller. Arayüzde
  KULLANILMAZ — orada `context.t`, çünkü test/önizlemede ayrı dil kurulabilir.
- **AI istemleri de çevriliyor** (chat hızlı komutları, `pdf_ai_edit`,
  `ai_rewrite_sheet`, `ai_actions` özet istemi). Yoksa Arapça arayüzde Türkçe
  istem gidiyordu. Desen: `(etiketAnahtarı, istemAnahtarı)` çifti.
- **Çevrilmeyecekler (tuzak):**
  - `batchRenamePresets` kalıpları — `{ad} {n} {n2} {tarih} {uzanti}`
    `applyBatchRename`in sözleşmesi ve birim testli; çevrilirse eşleşme
    SESSİZCE bozulur. Yalnız etiket çevrildi.
  - `ImportantScreen.folderName` ve `downloadsPathIn` aday listesindeki
    `'İndirilenler'` — diskteki KLASÖR ADLARI.
  - `formula_engine` fonksiyon adları (TOPLA, EĞER…) — Excel formül dili.
  - Bildirim kanalı adı (`job_notifications._channelName`) — Android kanalı bir
    kez kaydediliyor, sonradan değişmesi kullanıcıya iki kanal gösterirdi.
- `cleanup_advisor` saf fonksiyon kaldı: `CleanupSuggestion` artık `title`/`detail`
  yerine `titleKey`/`detailKey` + `detailVars` taşıyor.
- **Sık tekrarlayan iki derleme hatası** (toplu değiştirmede): `const Text(context.t(…))`
  → `const` kaldır; `use_build_context_synchronously` → metinleri `await`ten ÖNCE
  `AppStrings.of(context)` ile yakala (ya da kuyruğa giren işte `AppStrings.current`).

Doğrulama: `flutter analyze` 0 hata (21 uyarı = değişmeyen taban), `flutter test`
**1017 test geçti**.

## 2026-07-30 — 7 KULLANICI HATASI: bildirim çubuğu, arka plan, Drive, tarama, galeri, oynatıcı, PIN
Kullanıcı ekran görüntüleriyle bildirdi. Hepsi tek turda düzeltildi; her biri
için **kök neden** aşağıda (belirti değil).

### A) Bildirim ilerleme çubuğu hep boş
*"video boyutu ayarlama gibi işlevler bildirim çubuğunda ilerlemesi görülmüyor,
o çubuk hep boş"*.
- **Kök neden:** `FmJob.done/total` **DOSYA** sayıyor. Tek videoyu küçültmek
  `done=0, total=1` demek → çubuk iş bitene kadar 0'da duruyor. Yüzde yalnız
  `detail` METNİNDE vardı, o da daraltılmış bildirimde görünmüyor.
- **Çözüm:** `FmJob.unit` (0..1, süren dosyanın kesri). `progress` artık
  `(done + unit) / total`. `JobHandle.report(unit:)` — `done` ilerleyince
  `unit` SIFIRLANIR (yoksa dosya değişiminde çubuk bir kare zıplardı).
  Bildirimde çubuk 0-1000 ölçeğinde çizilir (`scaledProgress`), ayrıntı
  `BigTextStyleInformation` ile genişletilince tam okunur.

### B) Arka plana alınca iş duraklıyor
- **Kök neden:** Android (özellikle MIUI/EMUI) ön planda olmayan süreci
  donduruyor; kodlama native iş parçacığında koşsa bile süreç askıya alınınca
  duruyor. İş kuyruğunun tek koruması bir bildirimdi — bildirim süreci ayakta
  TUTMAZ.
- **Çözüm:** **ön plan servisi**. `flutter_local_notifications`ın
  `startForegroundService`i kullanıldı → **yeni paket gerekmedi** ve servisin
  bildirimi zaten bizim ilerleme bildirimimiz (iki ayrı bildirim birikmiyor).
  `ci/AndroidManifest.xml`'e `com.dexterous...ForegroundService` tanımı eklendi
  (eklenti kendi manifestinde bildirmiyor; `foregroundServiceType="dataSync"`,
  izinler zaten indirmelerden vardı).
- `JobReporter.onIdle()` eklendi (gövdesi boş, sahte raportörler bilmek zorunda
  değil): kuyruk boşalınca servis durur. Her işin sonunda durdurup sıradakinde
  yeniden açmak, Android 12+ "arka plandan servis başlatma" kısıtına takılıp
  ikinci dosyada korumayı düşürürdü.
- **DÜRÜST SINIR (değişmedi):** servis `stopWithTask="true"`. İş Dart
  izolatında koşuyor; görev listesinden kapatınca izolat ölür, ayakta kalan
  servis yalnız donmuş bir bildirim gösterirdi.

### C) "drive olmadı"
- **Kök neden:** `DriveService.signIn()` içinde `catch (_) { return false; }`
  vardı → her hata tek bir "Google hesabına bağlı değilsiniz" oluyordu. Gerçek
  neden neredeyse kesin `ApiException: 10` (DEVELOPER_ERROR): APK'nın **paket
  adı + imza SHA-1** ikilisi Google Cloud'da "Android OAuth istemcisi" olarak
  kayıtlı değil. **Kodla çözülemez** — kurulum adımı.
- **Çözüm (üç parça):**
  1. Hata sınıflandırılıyor (`DriveSignInError`: notConfigured / noPlayServices
     / network / cancelled / failed), her biri için EYLEM içeren ayrı metin.
     Sınıflandırılamayanın ham platform mesajı seçilebilir metin olarak
     gösteriliyor (kullanıcının bildirebileceği tek ipucu).
  2. **Yapılandırma gerektirmeyen ÇALIŞAN yol düğme oldu:** "Sistem seçicisiyle
     Drive dosyası aç" — Android'in Depolama Erişim Çerçevesi Drive'ı sağlayıcı
     olarak listeler, hiçbir yetki istemez ve Drive'ın TAMAMINI gezdirir.
     Eskiden yalnız METİNDE tarif ediliyordu.
  3. `docs/GOOGLE-DRIVE-KURULUM.md` — SHA-1 nereden alınır, hangi kapsam
     (`drive.file`, CASA denetimi gerektirmeyen), neden `google-services.json`
     gerekmiyor. **Uyarı:** `ANDROID_KEYSTORE_B64` secret'ı yoksa CI her koşuda
     geçici anahtar üretir → SHA-1 değişir → kayıt bir sonraki derlemede ölür.
- Yan bulgu: `drive.scope_notice` metnindeki `**yıldızlar**` ekranda düz metin
  olarak çıkıyordu (şerit `Text`, Markdown değil) — kaldırıldı.

### D) Belge tarama kalitesi
*"kenarlar vs çok daha iyi algılanıp sayfa düzeltilmeli ve yazılar
netleştirilmeli"*. İki yeni saf-Dart servis (`image` paketi, izolatta koşar):

**`lib/services/doc_edges.dart` — otomatik kenar bulma (Hough).**
Köşe ayar ekranı artık görselin tamamıyla değil, bulunan kâğıtla açılıyor.
Yolda **ölçülerek** düzeltilen üç tuzak:
- *Sabit yüzdelik eşik ÇALIŞMIYOR:* temiz bir çekimde piksellerin %99'u sıfır
  eğimli, "en güçlü %8" eşiği SIFIR yapıyor ve hiçbir kenar bulunamıyordu →
  **Otsu** (parametresiz, dağılıma bakar).
- *θ adımı 2° YETMİYOR:* gerçek açı iki bin arasına düşünce oylar ρ kutularına
  bölünüp eşiği geçemiyordu → 1° adım + tepe puanı = üç komşu ρ kutusunun
  toplamı.
- *"En dıştaki doğruyu al" ÇUVALLIYOR:* kalın kenar bandını çapraz kesen 4°'lik
  zayıf bir "hayalet" doğru gerçek kenardan dışta çıkıp dörtgeni yamultuyordu
  (sol kenar üstte 46, altta 70 piksel). İki düzeltme birlikte: (a) Canny usulü
  **inceltme** (eğim yönünde maksimum olmayanı bastır) bandı 1 piksele indirir,
  (b) seçim artık "en dıştaki" değil **"en güçlü + ondan yeterince uzak en
  güçlü"** (`_pickPair`). Sentetik sayfada köşe hatası <6 piksel.
- Bulamazsa **null** döner ve görselin tamamına düşülür — yanlış dörtgen,
  dörtgen olmamasından kötü.

**`lib/services/scan_enhance.dart` — yazı netleştirme.**
Asıl sorun çözünürlük değil **ışık**: sayfanın bir yanı parlak, öbür yanı
gölgede; genel kontrast artırmak gölgeli yanı büsbütün karartıyor. Boru hattı:
yerel zemine **bölme** (gölge/vinyet giderme) → %2-98 kontrast gerdirme →
keskinleştirme maskesi → (S-B modunda) uyarlamalı eşikleme. Renkli modda
düzeltme **parlaklık** üstünden uygulanıp renge taşınıyor; üç kanalı ayrı
düzeltmek renkleri kaydırıyordu (mavi imza morarıyordu).
Önizleme ekranı açılırken TÜM sayfalara `auto` uygulanıyor (kullanıcı "daha iyi
taransın" diyor, her sayfada düğmeye basmasını istemiyor); çip şeridinden
Özgün/Gri/S-B'ye geçilebiliyor ve **özgün dosyalar korunuyor** (filtre yıkıcı
değil, köşe düzeltme hep özgün üstünde yapılıyor).

### E) Galeride dokununca resim zıplıyor
- **Kök neden:** çubuk gizlenirken `appBar: null` veriliyordu → Scaffold gövdesi
  ~80 piksel uzuyor, `BoxFit.contain` görseli yeniden ölçekliyor. Her dokunuşta
  iki kez zıplama.
- **Çözüm:** `extendBodyBehindAppBar` + sabit yükseklikli `PreferredSize`;
  görünürlük yalnız `AnimatedOpacity` ile, `IgnorePointer` gizliyken dokunuşu
  yutmasın diye.

### F) Video oynatıcı düğmeleri ortalı değil
- **Kök neden:** tam ekran düğmesi aynı `Row`un 6. öğesiydi; `center` ALTI
  öğeyi ortalıyordu → beşli oynatma grubu sola kayıyordu.
- **Çözüm:** `Stack` — beşli grup ortada, tam ekran `PositionedDirectional(end:)`
  ile kenarda (RTL'de kendiliğinden sola geçer).

### G) "eski pin girmedim ki" — TEMA HATASI, PIN hatası değil
- **Kök neden:** `inputDecorationTheme.fillColor` = `surfaceContainerHigh` ve
  `dialogTheme.backgroundColor` = **aynı renk**, üstelik odaklanmamış kutunun
  kenarlığı `BorderSide.none` idi → diyalogdaki ikinci metin kutusu TAMAMEN
  görünmezdi. Kullanıcı "PIN (tekrar)" kutusunu göremediği için boş bırakıyor
  ve "İki PIN aynı değil" hatası alıyordu. **Her diyalogdaki her metin kutusunu
  ilgilendiren genel bir hata**, PIN'e özel değil.
- **Çözüm:** odaklanmamış kutuya `outlineVariant` kenarlık + dolgu bir kademe
  koyu (`surfaceContainerHighest`). Ayrıca tekrar kutusu boşken artık "aynı
  PIN'i alttaki kutuya da yazın" deniyor (yanlış tanı veren mesaj düzeltildi).

**Doğrulama:** Linux bulut oturumunda Flutter 3.29.3 (CI ile aynı) —
`flutter analyze` 0 hata, `flutter test` **1038 test geçti** (25 yeni test:
`doc_edges_test`, `scan_enhance_test`, `job_progress_test`). APK derlemesi
yalnız CI'da doğrulanır.

**Dal notu:** bu tur, oturum yönergesi gereği `claude/video-size-document-scan-issues-q0vf9o`
dalına gitti (CLAUDE.md'deki "tek dal = main" kuralının istisnası; harici
yönerge dalı açıkça dayattı).

---

## 2026-07-31 — Tüm belge çevirisi · işlemden ilgili yere gezinme · tarama sonucu

Kullanıcının bu turdaki altı bulgusu (üçü sohbet, ikisi ekran görüntülü):

### A) "Tek butonla tüm sayfayı çevir" — `lib/services/doc_translate.dart`
Eski çeviri **hazır metin** istiyordu; taranmış PDF'te ekran "önce Metni tanı"
diyordu. Yani tek düğme değil, iki düğme ve arada kullanıcının bilmesi gereken
bir kavram (OCR) vardı.
- `DocTranslate.collectPdfPages`: **sayfa sayfa** önce metin katmanı, o sayfa
  boşsa OCR. Karma belgede (dijital sayfalar + arada taranmış imza sayfası) hem
  hızlı hem eksiksiz — "hepsini OCR'la" ya da "hiç OCR'lama" ikisi de yanlıştı.
- Sayfa ayrımı **veride** duruyor (`OcrPage` listesi), metnin içinde değil.
  Eskiden OCR çıktısına "— Sayfa 3 —" yazılıyordu ve o başlık da çeviriye
  giriyordu. Başlığı artık arayüz kendi dilinde yazıyor.
- Çok sayfalı belgede **tek** `OnDeviceTranslator` açılıyor
  (`TranslateService.translateWith`): sayfa başına yeni çevirici, 180 sayfada
  dil modelini 180 kez belleğe yüklemek demekti.
- Akış durdurulabilir; durdurulunca o ana kadar çevrilen sayfalar GÖSTERİLİR ve
  "M sayfanın N tanesi çevrildi" yazılır. Eskiden ilerleme penceresinin
  kapatılma yolu yoktu (`barrierDismissible: false`, düğme yok) — 200 sayfalık
  taranmış bir belge kullanıcıyı on dakika kilitliyordu.
- `OcrService.maxPdfPages` (25) yerini çeviride kullanıcının "Durdur" kararına
  bıraktı; sabit kesme uzun belgede sessizce eksik çeviri üretirdi.

### B) İşlem → "ilgili yer" (kart · şerit · **bildirim**)
Üçü de ya aynı yere (İşlemler ekranı) ya hiçbir yere gidiyordu.
- **`FmJobTarget` düz VERİ olarak kuyrukta durur.** Geri çağrı/`BuildContext`
  saklamak denenmedi bile: kuyruk ekranlardan uzun yaşıyor, ekran kapandıktan
  sonra elde ölü bir bağlam kalırdı.
- Tek gezinme noktası `screens/fm/job_navigation.dart`; sıra: hedef → işin
  ürettiği dosyalar → İşlemler ekranı. İşlemler ekranındaki kart `fallbackToJobs:
  false` ile çağırıyor (kendi ekranını yeniden açmasın).
- Ok simgesi yalnız `jobHasDestination(job)` iken çiziliyor: her karta ok koymak,
  dokununca hiçbir şey olmayan kartlarda yalan olurdu.
- **Bildirim:** `initialize`a hiç yanıt işleyicisi verilmemişti — bildirime
  dokunmak yalnız uygulamayı öne alıyordu. Artık yük = iş kimliği,
  `onDidReceiveNotificationResponse` + kök `navigatorKey`. Uygulama KAPALIYKEN
  açılan bildirim `getNotificationAppLaunchDetails` ile ilk kareden sonra
  tüketiliyor (`takePendingJobId`).
- `CleanupScreen.index` **isteğe bağlı** oldu: bildirimden açılınca elde indeks
  yok, tarama indeksi kendisi kuruyor. Boş indeksle koşmak APK/büyük video
  önerilerini sessizce yok sayardı.

### C) TUZAK — `pdf` paketi metin renginde ALFA kanalını yazmıyor
Kullanıcı ekran görüntüsü: "metinleri de tanı" ile taranan sayfada OCR metni
**koyu siyah, dev punto**, sayfanın sağına taşmış. İki kök neden birlikte:
1. Görünmezlik `PdfColor(0, 0, 0, 0)` ile, yani **saydam renkle** deneniyordu.
   `PdfGraphics.setFillColor` yalnız `r g b rg` yazıyor; alfa PDF'e hiç
   gitmiyor → metin tastamam siyah çıkıyor. **Doğrusu PDF'in kendi metin çizim
   kipi 3'ü:** `pw.TextStyle(renderingMode: PdfTextRenderingMode.invisible)`.
   Metin çizilmez ama belgede durur (aranabilir + kopyalanabilir).
2. Metin resmin ALTINA konup "resim üstünü örter" varsayılıyordu. Örtme yalnız
   resmin sınırları içinde çalışır; OCR kutusuna sığmayan uzun satır resmin
   sağından taşıyordu ve orada örtecek bir şey yok. Artık her satır **kendi
   kutusuna** `FittedBox` ile sıkıştırılıyor ve katman resmin dikdörtgeniyle
   `ClipRect`leniyor.
**Test tuzağı:** içerik akışı `FlateDecode`; doğrulama için açmak gerekiyor
(`zlib.decode`). Ama gömülü yazı tipi programı da bir akış ve ikili içeriğinde
tesadüfen "0 Tr" geçiyor → yalnız `BT ` içeren akışlara bakılmalı
(`test/scan_searchable_pdf_test.dart`).

### D) Tarama sonucu ekranı — `lib/screens/scan_result_screen.dart`
İstek: "bir sayfada belge, bir sayfada yazılar düzgün formatta, çeviri seçeneği,
PDF dönüştür ve kaydet, kaydedilecek konum seçilebilsin."
- Belge / Metin sekmeleri; metin sayfa sayfa kartlarda ve seçilebilir.
- **Kaydetme sırası bilinçli ters:** PDF ekran açılmadan Belgeler dizinine
  yazılıyor, ekran "Konumu değiştir" (klasör seçici → taşı) sunuyor.
  "Kaydetmeden göster, düğme bekle" kurgusunda geri tuşuna basan kullanıcı
  taramasını kaybederdi.
- OCR **bir kez** koşuyor (`DocumentScanner.recognizePages`); aynı sonuç hem
  PDF katmanına hem metin sekmesine gidiyor.

### E) "Butona bastım, başladı mı anlamıyorum" (tarama filtre çipleri)
Filtre `compute` ile ayrı izolatta koşuyor ve **bitene kadar ekranda hiçbir şey
değişmiyordu** — çip bile seçili görünmüyordu, çünkü seçim işareti sonuç
geldiğinde konuyordu. Genel kural olarak yazıldı: *izolata iş veren her dokunuş,
dokunulduğu KARE içinde görünür bir iz bırakmalı.* Çip iyimser seçilir, çipte
gösterge döner, üstte belirsiz çubuk çıkar; iş başarısız olursa seçim geri alınır.

### F) "10 bin WhatsApp fotoğrafının %90'ı gereksiz" — `services/fm/chat_junk.dart`
- **Karar: kova, tek tek eleme DEĞİL.** 10 bin dosyayı kaydır-sil ile elemek
  10 bin karar demek; kimse yapmaz. Dosyalar "gereksiz olma SEBEBİNE" göre
  kovalanıyor, kullanıcı kova başına tek karar veriyor.
- **Yalnız üst veri** (yol, ad, boyut, tarih) — dosya AÇILMIYOR. 10 bin görüntüyü
  çözmek dakikalar sürer. Görüntü çözmeyi gerektiren iş (benzer kareler) zaten
  ayrı bir özellik (`SimilarFinder`); ekranın altından oraya kapı var.
- Kovalar: birebir kopya · çıkartma · GIF · profil fotoğrafı · küçük görüntü
  (iletilmiş mem/"günaydın") · gönderdiklerim (`/Sent/`) · uzun süredir
  açılmamış. Öncelik sırası sabit ve **bir dosya en çok BİR kovada**: iki kovada
  saymak "şu kadar yer açılacak" toplamını yalan yapardı.
- Kopya kümesinin bir parçası sohbet klasörünün DIŞINDAysa buradakilerin hepsi
  silinmez (en az biri kalmalı) — `test/fm_chat_junk_test.dart`te kilitli.
- Kopya taraması **yalnız sohbet klasörlerinde** (`DuplicateFinder.scanPaths`):
  soru "WhatsApp yığını", tüm depolamayı bayt bayt karşılaştırmak dakikalar alır.
- "Küçük görüntü" eşiği (varsayılan 150 KB) ekrandan değiştirilebiliyor; sabit
  bir sayı dayatıp "gereksiz" demek fazla iddialı olurdu.
- Fotoğraf içeren hiçbir kova **varsayılan seçili gelmez**; yalnız birebir
  kopyalar güvenli (bir kopya kalıyor). Projedeki sabit kural.

**TEST TUZAĞI (bu turda iki test bu yüzden yanlış geçti/kaldı):** sahte "şimdi"
olarak küçük bir sayı (1e9) kullanmak `now - 400 gün`ü NEGATİF yapıyor ve yaş
kuralını sessizce devre dışı bırakıyor. Yaşa bakan testlerde gerçekçi epoch
kullan (`1785456000000`) ve varsayılan `modifiedMs`i "dün" yap.

**Doğrulama:** Linux bulut oturumunda Flutter 3.29.3 (CI ile aynı) —
`flutter analyze` 0 hata, `flutter test` **1070 test geçti** (32 yeni test:
`scan_searchable_pdf_test`, `fm_job_target_test`, `fm_chat_junk_test`).
APK derlemesi yalnız CI'da doğrulanır.

**Dal notu:** bu tur da oturum yönergesi gereği
`claude/translation-navigation-improvements-qsabzb` dalına gitti (CLAUDE.md'deki
"tek dal = main" kuralının istisnası; harici yönerge dalı açıkça dayattı).

---

## 2026-07-31 (2. tur) — İş listesi kalıcılığı · çöp kutusu görünürlüğü

### A) TUZAK / YANLIŞ ÇIKAN YOL — "bir işi durdurunca diğerleri kayboluyor"
Kullanıcı: *"İşlemler menüsünde birkaç işlem yapılıyor diyelim, uygulamayı 1-2
kez alta alıp yeniden üste aldığımda … 1'ini sonlandırdığımda diğer tüm işlemler
kayboluyor, boşa yapmış oluyorum."*

**İlk şüpheli iptal mantığıydı — DEĞİLMİŞ.** Sonda testiyle doğrulandı: süren
işi iptal etmek sıradakileri düşürmüyor, kuyruk sıradakini normal çalıştırıyor
(`[C=queued, B=running, A=cancelled]` → `[C=done, B=done, A=cancelled]`). Bu
invaryant artık `test/fm_job_queue_test.dart`te kilitli ki aynı şikâyet tekrar
gelirse bu yol hemen elensin.

**Gerçek kök neden: `JobQueue` yalnız BELLEKTEYDİ, hiç diske yazmıyordu.**
Zincir şöyle:
1. Son etkin iş bitiyor/durduruluyor → `_pump` boşalıyor → `reporter.onIdle()`
   → **ön plan servisi kapanıyor**.
2. Servis kapanınca süreç korumasını yitiriyor; kullanıcı uygulamayı alta
   almışken Android (MIUI/EMUI'de fazlasıyla agresif) süreci öldürüyor.
3. Geri gelince `main()` baştan koşuyor, `JobQueue.instance` yepyeni ve BOŞ.
   Süren işler de, kullanıcının henüz görmediği SONUÇLAR da izsiz yok oluyor.

Yani "1'ini sonlandırma" tetikleyiciydi (kuyruğu boşaltıp servisi indirdiği
için), sebep değil.

**Çözüm — `lib/services/fm/job_store.dart`:**
- `JobPersistence` kancası (`JobReporter` ile aynı kalıp): `JobQueue` `dart:io`
  ve eklenti bağımsız kalıyor, birim testi diske dokunmuyor.
- Kaydedilen: işin **hikâyesi** (durum, ayrıntı, süre damgaları, çıktı yolları,
  hedef). Kaydedilmeyen: `result` (rastgele Dart nesnesi) ve iş gövdesi
  (closure) — bu yüzden yarıda kalan iş kendiliğinden DEVAM ETMEZ.
- Yeni durum **`JobStatus.interrupted`**: geri yüklenirken süren/bekleyen işler
  bunu alıyor. "Sürüyor" demek yalan olurdu (çubuk sonsuza kadar dönerdi),
  sessizce silmek de kullanıcının şikâyetinin ta kendisiydi. Kart "yarıda kaldı
  · dokunup yeniden başlatın" diyor; dokunmak işin hedef ekranını açıyor, tarama
  oradan yeniden başlıyor (2026-07-31 1. turdaki `FmJobTarget` sayesinde
  bedavaya geldi).
- Yazma **kısılmış** (2 sn) + geçici dosya & `rename`: ilerleme saniyede ~7 kez
  bildiriliyor, her birinde JSON yazmak diski döverdi; `rename` de yazma
  ortasında ölen süreçte yarım JSON bırakmaz.
- Okuma **açılışı bloklamaz** (`unawaited(_restoreJobs())`): kayıt yolu
  `FmEnv.appSupportDir`e bağlı ve `FmEnv.ensureInit()` depolama birimlerini de
  tarıyor. Liste geç gelse de İşlemler ekranı/şerit kuyruğu dinliyor.
  `restore` bu oturumda eklenmiş kimliği EZMEZ.

### B) "Çöp kutusunu bulmak çok zor"
İstek: *"üstteki büyük simgelerden 1'i olsun, altta olmasın, doluysa animasyonu
olsun."* Çöp kutusu **Araçlar** ızgarasının SON kutucuğuydu — orası bilinçli
olarak "görsel ağırlığı düşük" (2026-07-29 kararı: küçük, kartsız simgeler).
Ama o hiyerarşide kaybolan şey **silinen dosyayı geri almanın tek kapısıydı**;
ağırlığı düşürülecek bir "araç" değil.
- Kutucuk büyük kategori ızgarasına taşındı, Araçlar'dan çıkarıldı.
- Doluyken: dolu simge (`Icons.delete`), turuncu renk, sayı alt satırda ve
  simge yavaşça **nefes alıyor** (`FmTileData.pulse`).
- **Erişilebilirlik:** cihazda animasyonlar kapalıysa (`disableAnimations`)
  hiç oynamıyor; kutu o durumda renk + dolu simge + sayı ile ayırt ediliyor.
  Sürekli titreyen bir kutuyu hareket duyarlılığı olan kullanıcıya dayatmak
  olmaz. Üçü de `test/fm_trash_tile_test.dart`te kilitli.
- **Test tuzağı:** `find.byType(ScaleTransition)` işe YARAMAZ — Material'in
  kendi içinde de `ScaleTransition` var. `FmCategoryTile.pulseKey` ile bulunuyor.
- Etiket "Çöp" → "Çöp kutusu": büyük kutuda tek heceli "Çöp" ne olduğunu
  anlatmıyordu.

**Doğrulama:** Flutter 3.29.3 (CI ile aynı) — `flutter analyze` 0 hata,
`flutter test` **1080 test geçti** (10 yeni test).

## 2026-07-31 — Windows test koşusu: 8 kırmızının kök nedenleri

- **Saf yol hesabında platform join'i (6 test):** `p.join`/`p.dirname`/`p.normalize`
  Windows'ta `\` basar; POSIX-stilli girdiyle çalışan saf hesaplar bozuldu.
  Düzeltilen yerler: `ArchiveOps.volumePath` (concat, önek korunur),
  `FileOps.rename` hedefi + `_transfer` dest'i (`joinKeepingSeparator`:
  girdinin SON ayırıcısı kullanılır), `FtpServer.resolve` dönüşü (güvenlik
  kontrolü normalize üzerinde kalır, dönüş `kök + '/' + sanal`),
  `TrashService.trashDirFor` (`startsWith('$r/')` → `p.equals`/`p.isWithin`;
  literal `/` yüzünden HER yol fallback'e düşüyordu — birim çöpü, `.nomedia`
  ve `index.json` üçünü birden bozan tek satırdı).
- **koni FFI parola-hatası handle sızdırıyor (Windows):** parolasız şifreli
  RAR extract'inde native yol arşiv tanıtıcısını süresiz kilitli bırakıyor
  (tearDown `errno=32`; retry çare değil). Çözüm semptomda değil:
  `_extractSync`/`_extractOneSync` şifreli girdi + parolasızken native'e HİÇ
  girmeden `ArchiveError(passwordRequired)` fırlatır — sızıntı hiç oluşmaz.
- **SMB canlı testleri Windows'ta yanlış-pozitif:** Windows 445'i kendi SMB
  servisiyle HER ZAMAN dinler; `_up(445)` "test sunucumuz ayakta" sanıp
  gerçek Windows SMB'ye bağlanıyordu. `_smbUp`: Windows'ta `LIVE_SMB=1`
  açık onayı ister, diğer platformlarda davranış aynı.
- Kit kuruldu: `hooks/pre-push` (flutter test; kırmızı → push engellenir),
  `core.hooksPath=hooks`; `.claude/skills/flutter-ui` eklendi (usta §3b).

**Doğrulama:** `flutter analyze` 0 hata; `flutter test` pre-push hook
üzerinden **1080 geçti / 9 atlandı (canlı sunucu) / 0 kırmızı**.

## 2026-08-01 — Slaytta gezinme/arama/AI özet · Word bulanıklığı ve font · Excel bölme sadakati

Kullanıcı listesi: *"slayt toplam slayt sayısı görülmeli, tüm belgelerde toplam
sayfa sayısı görülmeli · slayta git seçeneği ve arama · ai ile slayt özetleme
detaylı ve kısa · Excel sadakatini devam · word bulanıklık ve metin boyutu yazı
tipi seçimi sadakat geliştirmelerine devam · slaytta tıklayıp düzenleme
başladığında geri tuşu düzenlemeyi kapatmalı, geri gidiyor direk."*

### A) KÖK NEDEN — Word'de bulanıklık: yakınlaştırma ÜÇ ayrı katmandaydı
`viewer.html` sayfayı `wrap.style.zoom` ile sığdırıyordu, `DocxViewState._zoomBy`
**ayrıca** `document.body.style.zoom` yazıyordu ve `enableZoom(true)` +
`user-scalable=yes` ile üstüne **native WebView pinch**'i biniyordu. Bulanıklığın
kaynağı üçüncüsü: native pinch sayfayı yeniden dizmez, **çizilmiş kareyi
büyütür** — yani yakınlaştıkça yazı piksel piksel şişer.
- Native yakınlaştırma kapatıldı (`user-scalable=no`, `enableZoom(false)`).
- Pinch artık JS'te yakalanıp tek bir CSS `zoom`a çevriliyor
  (`fitScale() * USER`) → tarayıcı metni **yeniden diziyor**, her ölçekte keskin.
  Odak noktası korunuyor: `scrollTo((s + f) * oran - f)`.
- Aynı ilke PDF tarafında zaten yazılıydı (*"yeniden-yerleşimle NET tutulur,
  InteractiveViewer değil"*); Word'e uygulanmamıştı.
- Ölçek JS'ten `Sayfa` kanalıyla bildirildiği için **zoom % rozeti** de
  bedavaya geldi (KALANLAR'daki "Word'de zoom rozeti yok" maddesi kapandı).

### B) Word'de yazı tipi/punto — neden SEÇİME değil PARAGRAFA
Canlı düzenlemenin tamamı *"DOM'daki `<p>` sırası = `document.xml`'deki `w:p`
sırası"* varsayımına dayanıyor; sigorta sayı uyuşmazsa düzenlemeyi tamamen
kapatıyor. Seçimi `<span>`la sarmak (`surroundContents`/`extractContents`)
paragraf sınırını aşan seçimlerde `<p>` bölebilir → eşleme çöker. Bu yüzden
font/punto paragrafın **stiline** yazılıyor (DOM yapısı değişmiyor).
- **`data-fk-font` / `data-fk-size` işareti şart:** `segsOf` hesaplanmış stili
  koşulsuz gönderseydi, kullanıcı sadece harf yazdığında bile dosyadaki
  STİLDEN gelen font satır içi bir `w:rFonts`e dönüşür ve belge stili sessizce
  donardı. İşaret yoksa alan `null` gider, `setRuns` şablon `rPr`ye dokunmaz.
- `RunSeg` 4'lü kayıttan (record) sınıfa çevrildi: opsiyonel `font`/`sizePt`
  alanı record'da temsil edilemiyor.
- `w:sz` **yarım punto** (14 pt → 28) ve `w:szCs` de yazılıyor; `w:rFonts`ta
  `ascii`+`hAnsi`+`cs` birlikte — yalnız `ascii` yazılsa Arapça metin eski
  fontta kalırdı.
- Liste bilinçli dar (Calibri/Times/Arial/Cambria/Helvetica): yalnız
  APK'ya gömülü, metrik-uyumlu karşılığı olan aileler. Cihazda olmayan bir font
  seçtirmek belgeyi Word'de bambaşka gösterirdi.

### C) Slaytta konum: ölçüm değil ANALİTİK hesap
Slaytlar tek akışta olduğu için "kaçıncı slayttayım" ancak kaydırma konumundan
çıkar. Kart yükseklikleri `_slideExtent` ile **hesaplanıyor** (başlık şeridi
`40*zoom` + `cardW/en-boy` + `20*zoom`), ölçülmüyor: ölçüme dayansaydı henüz
çizilmemiş bir slayda atlanamazdı (`ListView.builder` tembel). Formül
`_buildSlides`/`_slideCard` yerleşimiyle birebir aynı — **ikisi ayrışırsa
"slayta git" yanlış yere atlar**, ikisine de bunu söyleyen yorum kondu.
Rozet PDF'teki sayfa rozetiyle aynı kurguda: konumu söyler + dokununca "git".

### D) Arama: eşleşme slaytın ÜSTÜNDE vurgulanamıyor
`SlideCanvas` biçimli metni kendi çiziyor; içine vurgu katmanı koymak render
motoruna dokunmayı gerektirirdi. Onun yerine arama çubuğunun altında **bağlam
satırı** var ("Slayt 3 / 12 · …bütçe kalemleri…"): sayaç tek başına hangi metni
bulduğunu söylemiyordu. Arama çekirdeği `core/text_search.dart#searchSections`
— saf Dart, testli, bölüm bazlı (slayt/sayfa fark etmez).
**Tuzak:** sınıra dayanıp dayanmadığını anlamak için `findAll`dan
**sınırdan bir fazla** istemek gerekiyor; yoksa "tam 200 buldum" ile "200'de
kestim" ayırt edilemez ve kırpma sessiz kalır.

### E) Geri tuşu (kullanıcının doğrudan şikâyeti)
Slayt ve Word ekranlarında `PopScope`: düzenleme (ya da slaytta arama) açıkken
geri **onu** kapatır, ekrandan çıkmaz. Slaytta geri = `_finishEdit()`, yani
yazılan metin de kaydedilir — düzenlemeyi kapatıp yazılanı atmak, şikâyetin
kendisini başka biçimde tekrar etmek olurdu.

### F) Excel sadakati: `<pane>` / `showGridLines` / `<autoFilter>` kaydetmede uçuyordu
`excel 4.0.6` sayfayı yazarken `sheetData`yı temizleyip yeniden kuruyor;
dondurulmuş bölme, kapalı ızgara ve otomatik süzgeç **okunuyor ve ekranda
uygulanıyordu ama geri yazılmıyordu**. Başlık satırı donmuş bir tabloda tek
hücre değiştirip kaydeden kullanıcı, dosyayı Excel'de açtığında bölmenin
çözülmüş olduğunu görüyordu. `XlsxSavePatch`e eklendi.
- **Kırmızı→yeşil kanıtlandı:** yamanın alanları geçici olarak kaldırılınca
  gidiş-dönüş testi düşüyor (`frozenRows` 1 yerine 0) — yani kazanç gerçek,
  paket bunları korumuyor.
- `<pane>` **`sheetView`'ın İLK çocuğu** olmalı, `<autoFilter>` ise
  `sheetData`dan SONRA: `_worksheetOrder` listesi `sheetData` sonrasındaki
  kardeşlerle genişletildi, yoksa `autoFilter` `pageMargins`in arkasına düşüp
  Excel'de "onarılamayan içerik" uyarısı verirdi.
- Izgara niteliği yalnız KAPALIYKEN yazılıyor (Excel varsayılanı açık) —
  gereksiz nitelik dosyayı boşuna değiştirirdi.

### G) TUZAK — `main` zaten DERLENMİYORDU (`ftpconnect` sabitleri)
İstenen işle ilgisiz ama turu bloke ediyordu: `ftp_fs.dart` (ve
`ftp_server_test.dart`) `SecurityType.ftps` / `FTPEntryType.dir` yazıyordu;
`ftpconnect 2.0.7`de sabitler **BÜYÜK HARF** (`FTPS`, `DIR`). 4 derleme hatası
= APK derlemesi kırık. Sürüm yükseltmek yol DEĞİL: 2.0.8+ `intl ^0.20.2`
istiyor, Flutter 3.29.3'ün `flutter_localizations`ı `intl 0.19.0`a pinli.
Paketin kendi adları kullanıldı.

### H) Doğrulama
Bulut oturumunda Flutter **3.29.3** (CI ile aynı) indirilip koşturuldu:
`flutter analyze` **0 hata**, `flutter test` tüm paket yeşil
(yeni testler: `slides_screen_test` 6, `searchSections` 5, `word_assets`
2 sözleşme testi, `xlsx_save_patch` 5, `docx_editor` font/punto 2).
Cihazda görsel doğrulama YAPILMADI → KALANLAR "2026-08-01 turu".

**Dal notu:** oturum yönergesi gereği `claude/slide-document-features-bd90oq`
dalına gitti (CLAUDE.md'deki "tek dal = main" kuralının istisnası; harici
yönerge dalı açıkça dayattı — 2026-07-31'deki gibi).

## 2026-08-01 (2. tur) — Cihaz bulguları: sayfa ekrana sığmıyordu · FAB çakışmaları

Kullanıcı ekran görüntüsüyle geldi: *"bulanıklık devam ediyor yaklaştırınca
düzeliyor"*, *"ai butonu ile bir çok şey çakışıyor"*.

### A) KÖK NEDEN — "bulanıklık" aslında SIĞDIRMA hatasıydı
1. turda native pinch kapatılıp CSS zoom'a geçilmişti ve bu DOĞRUYDU
(kullanıcı "yaklaştırınca düzeliyor" diyor — yani yeniden dizme çalışıyor).
Ama ekran görüntüsü ölçüldüğünde sayfa ekranın **yalnız %59'unu** kaplıyordu:
yani sığdırma ölçeği olması gerekenin ~0,6 katıydı, yazı da o oranda küçük
kalıyordu. Küçük yazı ekranda "bulanık" görünür — sorun keskinlik değil BOYUT
(2026-07-28'deki teşhisin aynısı, bu kez sebebi ölçüm hatası).

İki hata birden vardı, ikisi de `fitPage`te:
- **`Math.max(offsetWidth, scrollWidth)`** — `scrollWidth` sayfadan TAŞAN bir
  tablo/başlık yüzünden şişiyor ve sayfayı gereksiz yere küçültüyordu. Sayfa
  ekrana sığmalı; taşan içerik yatayda kaydırılsın. Artık `offsetWidth`.
- **`if (!pageW)` önbelleği** — genişlik bir kez ölçülüp sonsuza dek
  saklanıyordu. İlk ölçüm docx-preview yerleşimi/fontlar tamamlanmadan
  yapılırsa yanlış değer bir daha DÜZELMİYORDU. Artık her `fitPage`te yeniden
  ölçülüyor (ölçümden önce zoom temizleniyor).

**Kalıcı ders — ölçüme değil SONUCA bak:** hangi ölçümün yalan söylediğini
kestirmek yerine `fitPage` artık bir **doğrulama turu** yapıyor: ölçek
uygulandıktan sonra `sec.getBoundingClientRect().width` okunuyor, sayfa ekranı
doldurmuyorsa ölçek bir kez düzeltiliyor (`pageW /= hata`). Böylece ölçüm
katmanı ne yaparsa yapsın sonuç doğru çıkıyor. Döngü riski yok: düzeltme
özyinelemesiz ve yalnız `USER === 1`de (kullanıcı yakınlaştırmamışken).

**Kalan bilinçli sınır:** A4 sayfa telefon genişliğine sığdırıldığında gövde
yazısı yine de gerçek boyutunun ~yarısı olur. Gerçek boyutta okumak için
**Mobil (akış) görünümü** var; "belge SAYFA görünümüyle açılır" 2026-07-28
kullanıcı kararı olduğu için varsayılan değiştirilmedi.

### B) FAB çakışmaları — alt şeridin üç yeri var, üçü de doluydu
Sağ altta ekranın AI düğmesi (FAB) duruyor. 1. turda konum rozetleri de sağ
alta konmuştu → FAB rozeti yarıdan kesiyordu ("Slay…" görünüyordu). Word'de
ayrıca `DocxView`in zoom düğmeleri (bunlar eskiden beri sağ altta) FAB'ın
altında kalıyordu.

**Kural yazıldı: alt şerit ÜÇE bölünür — SOL = zoom düğmeleri / pinch %
rozeti, ORTA = konum rozeti (sayfa/slayt), SAĞ = FAB.** PDF görüntüleyici
zaten sayfa rozetini ortada tutuyordu; slayt ve Word de aynı hizaya geldi.

**Doğrulama:** `flutter analyze` 0 hata; `flutter test` tüm paket yeşil.
Sığdırma düzeltmesi ancak CİHAZDA görülebilir (WebView yerleşimi birim testi
ile taklit edilemiyor) — `word_assets_test` yalnız sözleşmeyi kilitliyor
(`scrollWidth` kullanılmıyor + doğrulama turu duruyor).

## 2026-08-02 — Slayt sadakati: ön tanımlı şekiller ARTIK KUTU DEĞİL

Kullanıcı isteği: *"sadakat geliştirmeleri için araştırma yap ve geliştir."*
Araştırma turunda üç açık sadakat kaybı bulundu, üçü de PPTX çiziminde.

### A) KÖK NEDEN — `BoxDecoration` üçgen çizemez
`slide_canvas` şekilleri yalnız `BoxDecoration` ile çiziyordu. `BoxDecoration`
sadece dikdörtgen (isteğe bağlı köşe yarıçapı) ve daire üretebilir; yani
`a:prstGeom@prst` ne olursa olsun ekrana **düz dikdörtgen** düşüyordu:
üçgen, elmas, ok, chevron, yıldız, altıgen, artı, silindir, küp, halka,
akış şeması kutuları… Süreç/akış diyagramı içeren bir sunumda bu, sadakat
kaybının en görünür biçimi — **okun yerinde kutu**.
- Yeni modül `services/pptx_geometry.dart`: `prst` → `dart:ui` `Path`.
  ECMA-376 `presetShapeDefinitions.xml` formülleri (`ss = min(w,h)`, ayarlar
  1/100000) izlendi; **50+ şekil** tanımlı, saf `dart:ui` (widget/dosya G/Ç
  yok) olduğu için yol geometrisi doğrudan birim testli.
- `ShapeVM.preset` + `ShapeVM.adjust` eklendi. **Tanımadığımız geometri
  sessizce `rect`e düşer** — yanlış çizmektense kutu çizmek daha az yanıltıcı
  (bilerek alınan karar; `funkyShapeXyz` testi bunu kilitliyor).
- `roundRect` yarıçapı artık `a:avLst`ten geliyor. Eskiden `min(w,h)*0.12`
  sabitti; ECMA varsayılanı **16667/100000** ve kullanıcı sarı tutamağı
  oynattıysa değer dosyada yazılı. Aynı yoldan `flowChartTerminator`
  (stadyum) ve `flowChartAlternateProcess` de kutu ailesine bağlandı.

### B) HATA — geniş elips DAİRE çiziliyordu
`isEllipse` bayrağı `BoxShape.circle`a gidiyordu; Flutter orada **kısa kenara
göre daire** çizer (`drawCircle(center, shortestSide/2)`). Yani 200x100'lük
bir elips ekranda 100x100 daire oluyordu — hem yanlış biçim hem ortada
kaybolmuş bir şekil. Elips artık yol olarak çiziliyor ve kutunun tamamını
kaplıyor (`elips kutunun TAMAMINI kaplar — daire değil` testi).

### C) `a:srcRect` (görsel kırpması) hiç okunmuyordu
PowerPoint kırpmayı kaynağın kenarlarından atılan ORAN olarak saklar; görünen
parça yine kutuyu doldurur. Biz kırpmayı yok sayıp görselin tamamını kutuya
gerdiğimiz için fotoğraf hem **yanlış kadrajdan** hem **bozuk en-boy oranıyla**
çıkıyordu. `_CroppedImage`: görsel `1/(1-l-r)` oranında büyütülüp `-l` kadar
kaydırılıyor, `ClipRect` fazlasını kesiyor.

### D) Görselin çerçevesi görselin ALTINDA kalıyordu
`Container(decoration:…, child: img)` süslemeyi çocuktan ÖNCE boyar → kenarlıklı
bir fotoğrafın çerçevesi görselin altında kayboluyordu. Çerçeve artık
`foregroundDecoration`a (yol şekillerinde `foregroundPainter`a) taşındı.
Bu yüzden `_GeometryPainter` `fill`/`stroke` bayrağı taşıyor: aynı yol iki
katmanda, arada görsel.

### TUZAKLAR
- **Dart'ta `switch` gövdeleri TEK kapsam paylaşır.** İki ayrı `case` içinde
  `final d` tanımlamak "already defined" derleme hatası; her gövde `{ }` ile
  sarıldı. (İlk yazımda 6 çakışma vardı.)
- **`Path.getBounds` YALAN SÖYLER** — Skia sınırı denetim noktalarından
  hesaplar, yay içeren şekillerde çizilen hattın çok dışını verir: 200x100'lük
  bir `chord` için `Rect(-41.4, 0, 170.7, 120.7)`. "Şekil kutuya sığıyor mu"
  testi bu yüzden `computeMetrics` ile yolu ÖRNEKLİYOR (`_outlineBounds`).
  Yol gerçekten taşmıyordu; ölçü aleti taşıyordu.
- **OOXML `pie` varsayılanı 0°→270°** ve açı saat 3 yönünden SAAT YÖNÜNDE
  ölçülür (kanvasla aynı yön). Boş kalan çeyrek **sağ üst**, sol üst değil —
  testi ters yazınca yakalandı.
- **Balon (`wedge*Callout`) kuyruğu şekil kutusunun DIŞINA taşar**; PowerPoint
  de öyle çizer, bu yüzden "kutuya sığmalı" kuralının bilinçli istisnası.

### Doğrulama
Bulut oturumunda Flutter **3.29.3** (CI ile aynı): `flutter analyze` **0 hata**
(kalan uyarılar önceden var olan `withOpacity` maddeleri), `flutter test`
**1124 test yeşil**. Yeni testler: `pptx_geometry_test` 19,
`pptx_render_test`e 4 (preset+avLst, yol çizimi, `srcRect`, çerçeve katmanı).
Cihazda GÖRSEL doğrulama yapılmadı → KALANLAR "2026-08-02 turu".

## 2026-08-02 (2. tur) — Excel: DÜZENLEME çekirdeği (geri al, pano, doldurma, Σ)

Kullanıcı: *"Excel tarafını geliştirmeye devam edelim, gerçek mobil excel gibi
olsun, aynısı oluncaya kadar çalış."*

### A) Araştırma bulgusu — eksik olan GÖRÜNÜM değil, DÜZENLEME
Ekran zaten Excel gibi ÇİZİYORDU (biçim, koşullu biçim, donmuş bölme, RTL,
formül motoru). Gerçek Excel'den ayıran şey düzenleme eylemleriydi ve en
temel dördü **hiç yoktu**: geri al/yinele, kopyala/kes/yapıştır, doldurma
tutamağı, otomatik toplam. Yani kullanıcı yanlış bir hücreye yazdığında geri
dönüşü yoktu — bu, bir tablo uygulamasında en sık kullanılan tuştur.

### B) Çekirdek ayrı ve SAF DART: `services/sheet_edit.dart`
Kural yoğun, kenar durumu bol her şey (formül kaydırma, seri üretimi, pano
tekrar kuralı, geri alma yığını) ekrandan ayrıldı → 39 birim testiyle
kilitlendi. Widget testinde sürükle-bırak taklidiyle uğraşmadan kural sınanıyor.

### C) TUZAKLAR (hepsi testte yakalandı)
- **`LOG10(A1)` → `LOG11(A2)` oluyordu.** `LOG` geçerli bir sütun adı, `10`
  geçerli bir satır — yani işlev adı tam bir hücre başvurusu gibi görünüyor.
  Excel ayrımı **ardından `(` gelip gelmediğine** bakarak yapar; biz de öyle.
- **Doldurma tutamağı kaydırılabilir ızgaranın İÇİNDE.** Sıradan
  `GestureDetector` sürüklemeyi kaydırma tanıyıcısıyla arenada paylaşır ve
  çoğu zaman KAYDIRMA kazanır: tutamak hiç çalışmaz, sayfa kayar. Çözüm
  `RawGestureDetector` + **`ImmediateMultiDragGestureRecognizer`** (Flutter'ın
  kendi sürükle-bırak listelerinde kullandığı yöntem) — pointer'ı hemen
  üstlenir. Widget testi gerçek sürükleme yapıyor, çünkü sınanması gereken
  şey kod yolu değil **arenayı kimin kazandığı**.
- **Formül çubuğu bayatlıyordu:** yapıştırma/doldurma/Σ imlecin ALTINDAKİ
  değeri değiştirdiğinde çubuk eski değeri gösteriyordu ve bir sonraki
  düzenlemede onu geri yazardı. `_editCells` artık `_syncField()` çağırıyor.
- **`deleteRow`un tersi `insertRow` DEĞİLDİR.** Silinen satırın değerleri,
  biçim indeksleri, uygulama içi biçim örtmeleri ve yüksekliği de geri
  konmalı; yoksa "geri al" veri kaybeder. `XlsxEditor.captureRow/restoreRow`
  (ve sütun karşılıkları) bunun için eklendi.
- **Testte `find.text` `EditableText`i de sayar:** "Tümünü değiştir" testinde
  değiştir ALANINDAKİ metin eşleşmeye karışıyordu; ızgara aramaları
  `find.descendant(of: SheetCell)` ile kapsandı.

### D) Kararlar
- **Geri alma yığını SAYFA BAŞINA.** Tek ortak yığın olsaydı geri al bazen
  görünmeyen bir sayfayı değiştirirdi.
- **Kesmede formül KAYDIRILMAZ** (taşımadır, kopyalama değil); kopyalamada
  göreli başvurular kayar, `$` kilitli olanlar durur — Excel kuralı.
- **Kesme kaynağı YAPIŞTIRINCA boşalır**, kesince değil: kullanıcı vazgeçerse
  veri yerinde kalır. Kaynak temizliği yapıştırmayla AYNI geri alma adımında.
- **Tek sayı doldurulunca KOPYALANIR** (5 → 5,5,5). Excel'de artırmak için
  Ctrl gerekir, dokunmatikte o kip yok.
- **Yapıştırma yalnız DEĞERİ taşır, biçimi değil** — bilinçli sınır, KALANLAR'da.
- Sistem panosuna TSV yazılıyor: başka uygulamaya (gerçek Excel dahil)
  yapıştırılabiliyor; sistem panosundan gelen TSV de okunuyor.

### E) Doğrulama
Flutter **3.29.3** (CI ile aynı): `analyze` **0 hata**, `flutter test`
**1172 test yeşil** (önceki tur 1124 → +48). Yeni: `sheet_edit_test` 39,
`spreadsheet_screen_test` +5 (geri al/yinele, temizle, kopyala-yapıştır, Σ,
doldurma sürüklemesi, değiştir), `xlsx_editor_test` +3 (satır/sütun geri alma,
`overrideAt`). Cihazda doğrulama YAPILMADI → KALANLAR "2026-08-02 (2. tur)".

## 2026-08-02 (3. tur) — Excel sayı biçimi YAZMA: paket kaydetmeyi kırıyordu

### KÖK NEDEN — `excel 4.0.6` biçim kodunu hücre TİPİYLE eşleştiriyor
Sayı biçimini paketin `CellStyle.numberFormat` alanından yazmayı denedim.
Paket, `save()` sırasında `numberFormat.accepts(value)` denetimi yapıyor ve
uymazsa ya biçimi sessizce varsayılana çeviriyor ya da **istisna fırlatıyor**:

    Exception: CustomDateTimeNumFormat("dd.mm.yyyy") does not work for IntCellValue

Excel'de tarihler **sayı** (seri numarası) olarak saklandığı için "bu sütunu
tarih yap" en sık istenen biçimlendirme — ve bu yolla dosya **hiç
kaydedilemez** hâle geliyordu. Yani kullanıcı verisini kaybederdi.

**Karar:** sayı biçimleri de `XlsxSavePatch`e taşındı (gizli satır/bölme/
süzgeçle aynı yol). Yama `styles.xml`i doğrudan yazdığı için tip polisi yok.
Bu aynı zamanda KALANLAR'daki tüm "biçim yazma" ailesinin (dolgu rengi,
kenarlık, metin kaydırma…) altyapısı — hepsi aynı `_StyleTable`den geçecek.

### `_StyleTable` — Excel'de biçim hücrede DEĞİL, tabloda durur
Hücre yalnız `s="<cellXfs indeksi>"` yazar. Bir hücreye biçim vermek üç adım:
1. biçim kodu için `numFmtId` (yerleşikse hazır id, değilse `<numFmts>`e
   **164'ten** başlayan yeni kayıt),
2. hücrenin ŞU ANKİ `<xf>`ini **kopyalayıp** `numFmtId`ini değiştir — sıfırdan
   kurulsaydı biçim vermek yazı tipini/dolguyu/kenarlığı silerdi,
3. aynı `<xf>` varsa indeksini **yeniden kullan**; her hücreye yeni `<xf>`
   eklemek büyük tabloda stil tablosunu şişirir.
Üçü de testli (`sayı biçimi hücrenin ÖTEKİ biçimlerini korur`,
`aynı biçim iki hücrede TEK bir <xf> paylaşır`).

### TUZAK — `[Red]` içindeki `d` yüzünden ondalık düğmeleri çalışmıyordu
`bumpDecimals` tarih kodlarına dokunmuyor; tarih tespiti "kodda y/d/h/s var mı"
diye bakıyordu. `#,##0.00;[Red]-#,##0.00` gibi ÇOK YAYGIN bir kodda `[Red]`
parçası tarih sanılıyor ve ondalık artır/azalt sessizce hiçbir şey yapmıyordu.
Tespit artık köşeli parantezli belirteçleri, tırnak içi sabitleri ve `\`
kaçışlarını atlıyor.

### Doğrulama
Flutter 3.29.3: `analyze` **0 hata**, **1181 test yeşil** (+9).

## 2026-08-02 (4. tur) — Word: paragraf silmenin geri dönüşü yoktu

Kullanıcı: *"devam sonra word e çalış."*

### Ortak geri alma yığını `core/undo_stack.dart`e taşındı
Excel'de doğan `SheetUndoStack` Word'de de gerekince çekirdeğe alındı
(`UndoStep` / `UndoStack` / `CallbackUndoStep`). Excel tarafındaki adlar
**typedef** olarak korundu — çağıranların ve testlerin hiçbiri değişmedi.

### Word'ün gerçek boşluğu: YAPISAL işlemler
Word ekranında paragraf ekle/sil vardı ama **geri alma yoktu**: yanlış
paragrafı silen kullanıcının belgeyi kaydetmeden kapatmaktan başka yolu yoktu.
- `DocxEditor.slotOf` / `restoreParagraph`: paragrafın **XML ağacındaki yeri +
  model sırası** silmeden ÖNCE yakalanır. **Sona eklemek yeterli değil:**
  Word'de paragrafın yeri anlamının parçası — başlığın altındaki madde
  belgenin sonuna düşerse metin bozulur. Testli (ilk paragraf dahil).
- Üst çubuğa geri al/yinele.

### Bilinçli sınır — harf harf yazma yığına GİRMEZ
Canlı görünümde tarayıcının kendi geri alması, akış görünümünde `TextField`in
kendi geri alması zaten çalışıyor. Her tuş vuruşunu ayrıca kaydetmek **iki
katmanlı ve şaşırtıcı** bir geri alma yaratırdı (bir "geri al" bazen harfi,
bazen paragrafı geri alır). Yığın yalnız yapısal işlemleri taşıyor.

### Doğrulama
Flutter 3.29.3: `analyze` **0 hata**, **1184 test yeşil** (+3).
Cihazda doğrulama YAPILMADI → KALANLAR.

## 2026-08-02 (5. tur) — Arayüz: "sade ama kullanışlı" (araç çubuğu kuralı)

Kullanıcı: *"arayüzümüz konusunda çalışmalıyız, sana bıraktım, bizi sade ama
kullanışlı bir hale getir."*

### Denetim: ön kapı iyi, KALABALIK belge ekranlarında
Ana ekran zaten sade (3 sekme: Dosyalar / Son / AI) ve alt eylem çubukları
tutarlı (Düzenle · Kaydet · Paylaş + türe özel). Sorun biçim çubuklarındaydı.

**Excel biçim çubuğu 20 kontrole çıkmıştı** — üstelik çoğunu bu oturumda ben
ekledim. Hepsi ikon-only ve tek satırda yatay kaydırmalı: kullanıcı ne
olduğunu ancak deneyerek öğreniyor, üstelik kaydırmadan görmüyor bile.

**Bu ders daha önce öğrenilmişti:** `DocActionBar`ın doğuş gerekçesi
(2026-07-27) *"üst çubuktaki ikonların tooltip'i telefonda hiç görünmüyor"*.
Biçim çubuğu o dersin dışında kalmış.

### KURAL (bundan sonra her belge ekranı için)
**Çubukta en fazla ~5 sık kullanılan eylem ikonla; gerisi ETİKETLİ ve GRUPLU
"Daha fazla" sayfasında.** Yeni ortak bileşen: `widgets/doc_more_sheet.dart`
(`DocMoreSheet` / `DocMoreGroup` / `DocMoreItem`).

- **Excel: 20 → 6.** Kalan: Kalın · İtalik · Hizalama · Sayı biçimi · Σ ·
  Daha fazla. Sayfada gruplu: **Pano** (kes/kopyala/yapıştır/temizle),
  **Sayı** (ondalık ±), **Satır** (ekle/sil/yükseklik), **Sütun**
  (ekle/sil/genişlik).
- **Hizalama üç düğme yerine TEK menü:** seçenekler birbirini dışlıyor, üç
  slot harcamaya değmez ve etkin olan menüde işaretli görünüyor. Aynı desen
  sayı biçiminde de var.
- Sütun genişliği / satır yüksekliği ⋮ menüsünden kalktı: artık ait oldukları
  Satır/Sütun grubunda (aynı işi iki yerde tutmamak).
- **PDF görüntüleyici: 7 → 5 eylem.** İki döndürme ikonu (birbirinin aynası,
  hangisinin ne yaptığı anlaşılmıyordu) etiketli ⋮ menüsüne taşındı. Dar
  telefonda 7×48dp başlığa yer bırakmıyordu.

### Karşı argüman ve cevabı
Satır/sütun ekleme artık iki dokunuş uzakta. Kabul: seyrek kullanılan bir iş
için bulunabilirlik > hız, üstelik artık ETİKETLİ. Excel mobil de bu işleri
panele koyuyor. Sık olanlar (biçim, Σ) çubukta kaldı.

### Doğrulama
`analyze` 0 hata, **1184 test yeşil**. Ekran testleri yeni akıştan geçiyor
(`tapMore` yardımcısı: "Daha fazla" → etiketli eylem), yani sayfa gerçekten
açılıyor ve eylemler çalışıyor.

---

## 2026-08-05 — Kağıt teması (claude.ai/design "Sekiz ekran Flutter tasarımı" devir notları)

**Karar: uygulamanın varsayılan teması artık KAĞIT.** Tasarım claude.ai/design'da
üretildi; iki devir notu (`DEVIR-NOTU.md`, `DEVIR-NOTU-2.md`) doğrudan Claude Code
için yazılmıştı ve token tablosu + ekran bazlı iyileştirme listesi içeriyordu.
Notların kendisi `design/` altına indirilmedi (tasarım projesi kaynakta duruyor);
uygulanan değerler `lib/core/theme.dart` içindeki `Paper` sınıfında yaşıyor.

### Niye "tohum korunur ama yüzeyler elle geçersiz kılınır"
`ColorScheme.fromSeed` yüzeyleri tohumdan türetiyor ve mavi-gri çıkıyor; kağıt
hissini bozan tam olarak buydu. Tohum (`#3B6EF6`) ikincil/üçüncül rollerin
türetilmesi için kaldı, `surface*` / `outline*` / `on*` / `secondaryContainer` /
`inverseSurface` elle yazıldı. Kabul ölçütü buydu: hiçbir ekranda Material'ın
türetilmiş mavi-gri yüzeyi kalmayacak.

### Tipografi: yeni font İNDİRİLMEDİ
Devir notu Spectral + IBM Plex öneriyordu. `assets/fonts/` altında slayt sadakati
için zaten **Tinos** (serif) ve **Arimo** (sans) vardı; başlık = Tinos w600,
gövde = Arimo, yol/boyut/zaman = sistem `monospace` seçildi. **APK boyutu
artmadı.** (İlk denemede Cormorant Garamond + Lora indirilmişti — yanlış tasarım
projesine ("Classical") bakıldığı anlaşılınca silindi; bkz. TUZAK.)

### TUZAK — 2026-08-05: "claude design" iki ayrı proje demek olabiliyor
`DesignSync.list_projects` yalnız **tasarım sistemi** (design-system) türündeki
projeleri döndürüyor. Kullanıcının kastettiği ekran tasarımı ise `PROJECT_TYPE_PROJECT`
türündeydi ve listede HİÇ GÖRÜNMÜYORDU — ancak paylaşılan URL'deki `projectId` ile
`get_project`/`list_files` çağrılabildi. Ders: kullanıcı "claude design'da çalışıyor"
dediğinde list_projects boş/alakasız çıkıyorsa proje **URL'si** istenir, liste
üstünden tahmin yürütülmez.

### TUZAK — `ftpconnect` enum adları sürüme göre değişiyor; İKİ ORTAM İKİ SÜRÜM
5 test dosyası yerelde "loading" hatasıyla düşüyordu: `SecurityType.FTPS/FTPES/FTP`
ve `FTPEntryType.DIR` bulunamıyor. Sebep: **2.0.8+ enum adlarını küçük harfe
çevirdi** (`FTPS` → `ftps`, `DIR` → `dir`).

**Sürüm sabitlemek ÇÖZMÜYOR — iki denemede de kırıldı:**
- `2.0.9`'a sabitlendi → CI'da **"version solving failed"** (2.0.8+'ın `intl`
  kısıtı Flutter 3.29.3'ün `flutter_localizations`ıyla çakışıyor).
- `2.0.7`'ye sabitlendi → bu sefer **yerel** çözemiyor (daha yeni Flutter'ın
  `intl`i 2.0.7'yi dışlıyor).

Yani CI zorunlu olarak 2.0.7'de, güncel yerel ortam zorunlu olarak 2.0.10'da.
Aralık (`^2.0.7`) ikisinin de çözebildiği tek yazım; ilk teşhisimin ("aralık
CI'yı da kıracaktı") aksine **CI hep 2.0.7'ye düşüyordu ve yeşildi**.

**Çözüm:** sabitin ADINI yazmayı bırak. `ftp_fs.dart` (ve `ftp_server_test.dart`)
artık `SecurityType.values.firstWhere((v) => v.name.toLowerCase() == 'ftps')`
ve `item.type?.name.toLowerCase() == 'dir'` kullanıyor — aynı kaynak her iki
sürümde de derleniyor. `pubspec.yaml`daki aralık bilinçli olarak açık bırakıldı.

**Ders:** iki ortam farklı sürüm çözmek ZORUNDAysa (SDK'nın pinlediği `intl`
gibi geçişli bir kısıt yüzünden), sürümü sabitlemeye çalışmak birini kırar;
kodu sürümler arası tarafsız yazmak tek çıkış.

### Doğrulama
`flutter analyze lib` → hata yok. `flutter test` → **1184 test yeşil** (9 atlandı).

---

## 2026-08-04 — Sadakat turu: Excel biçim yazma, Word köprüsü, kağıt simgesi

Kullanıcı isteği: "uygulama simgesini de yeni kağıt temamıza uygun hale getir;
sadakat geliştirmelerine devam et, kalanlarda bir şey kalmasın". Tur boyunca
`flutter analyze lib` **0 hata / 0 uyarı** (yalnız `info` kaldı; 22 → 10) ve
tam takım yeşil tutuldu.

### A) Uygulama simgesi kağıda geçti
`tool/gen_icon.py` yeniden yazıldı (harici bağımlılık yok, sadece `zlib`):
sıcak kağıt gradyanı + gölgeli, kenarlıklı bir sayfa + mürekkep mavisi sırt
bandı + ink/inkSoft satırlar. Renkler `theme.dart#Paper` ile birebir.

- **TUZAK — kağıt üstüne kağıt görünmüyor:** ilk denemede zemin (`#F7F2E6`) ile
  sayfa (`#FBF8F1`) neredeyse aynıydı; simge 48dp'de bej bir lekeye dönüyordu.
  Zemin bilinçli olarak iki kademe koyulaştırıldı (`#ECE2CC → #D9CBAD`).
- Adaptive ön-plan **gölgesiz** üretiliyor: maske kırpınca gölge kenarda leke
  bırakıyor. `pubspec.yaml` adaptive zemini `#3B6EF6` → `#E3D7BD`.

### B) Excel: "okunuyor ama yazılamıyor" maddesi kapandı
`_StyleTable` artık `numFmtId` yanında `fontId`/`fillId`/`borderId` de tahsis
ediyor; desen sayı biçimiyle aynı (hücrenin ŞU ANKİ `<xf>`i klonlanır, yalnız
ilgili alan değişir). Dolgu rengi, yazı rengi, kalın/italik/altı çizili,
kenarlık (kenar başına, `null` = sil) ve metin kaydırma yazılıyor.

- **Neden `excel` paketinin renk API'si kullanılmadı:** tek bir `ExcelColor`
  sabit paleti var ve kullanıcının seçtiği rengi en yakın sabite yuvarlıyor.
- **TUZAK — nitelik SIRASI:** eski `_sameXf` nitelikleri sıraya duyarlı
  karşılaştırıyordu; aynı biçim iki kez kaydedilebiliyordu. Artık kanonik
  anahtar (ad + SIRALI nitelikler + çocukların aynısı) kullanılıyor.
- `<font>`/`<border>` çocukları ECMA sırasına diziliyor — yanlış sıra Word/Excel
  için "onarılamayan içerik" demek.
- **Biçim yapıştırma** stil tablosuna HİÇ dokunmuyor: `styleCopies` hedef→kaynak
  eşlemesiyle kaynağın `s` indeksi hedefe yazılıyor (ikisi de aynı dosyada,
  indeks zaten geçerli). Yapıştırma değeri ve biçimi TEK geri alma adımında
  taşıyor.
- **Geri alma kaydetmeye giden izi de geri alıyor.** Yalnız ekran örtmesini
  geri koymak, geri alınmış bir dolgunun dosyaya yine yazılmasına yol açardı.

### C) Excel: sayfa yönetimi, süzgeç arayüzü, formül tamamlama
- **Sayfa ekle / yeniden adlandır / sil** (sekmeye uzun basış + "+" düğmesi).
  `excel.rename` kopyala+sil olduğu için YENİ bir `Sheet` nesnesi üretiyor;
  model nesnesinin KENDİSİ korunup yeni tabloya bağlanıyor — yoksa o oturumda
  verilen biçimler kaybolurdu. `XlsxSheet.name` ve `_sheet` bu yüzden artık
  değiştirilebilir.
- **Sayfa TAŞIMA yapılmadı (bilinçli):** `excel 4.0.6` sayfa sırasını kendi
  haritasının ekleme sırasından yazıyor, sırayı değiştirecek API yok; zorlamak
  her sayfayı kopyala-sil ile yeniden kurmak demekti.
- **Otomatik süzgeç arayüzü:** başlıktaki ok artık tıklanabilir — A→Z / Z→A
  sıralama + değer onay listesi. Süzgecin gizlediği satırlar `filterHidden`da
  sütun başına ayrı tutuluyor: süzgeci kaldırmak kullanıcının ELLE gizlediği
  satırı geri getirmemeli. Sıralama satırları BÜTÜN olarak taşıyor
  (`captureRow`/`restoreRow`), yoksa satırın gerisi yerinde kalıp veri karışırdı.
- **Formül otomatik tamamlama:** öneriler motorun KENDİ takma ad tablosundan
  üretiliyor (`FormulaEngine.functionNames`), ayrı bir liste tutmak motor yeni
  işlev öğrendiğinde eskirdi. Ayrı "işlev sihirbazı" ekranı yerine satır içi
  çip şeridi seçildi — telefonda ekran değiştirmeden, yazma ritmini bozmadan.

### D) Word: seçim köprüsü her şeyin önündeki tıkaçtı
`sendSelectionText` / `replaceSelectionText` eklenince dört KALANLAR maddesi
birden çözüldü.

- **Bul/değiştir:** arama DOM'a HİÇ dokunmuyor — eşleşme `Range` ile seçiliyor,
  tarayıcı kendi vurgusunu çiziyor. Bu yüzden düzenleme KAPALIYKEN de çalışıyor
  ve paragraf eşlemesini bozamıyor. Katlama Türkçe duyarlı
  (`toLocaleLowerCase('tr')`). Değiştirme metin düğümü düzeyinde ve SAĞDAN
  SOLA: soldaki eşleşmelerin konumu bozulmasın.
- **Renk/vurgu seçime uygulanıyor** (yazı tipinin aksine): `execCommand`
  `<span>` ürettiği için `<p>` sayısı değişmiyor. Renk YALNIZ kullanıcı
  verdiyse taşınıyor (`data-fk-color`/`data-fk-hl`) — hesaplanmışı koşulsuz
  göndermek temadan gelen rengi her düzenlemede satır içi bir `w:color`a
  dondururdu (yazı tipiyle aynı gerekçe).
- **TUZAK — liste için `execCommand('insertUnorderedList')` KULLANILAMAZ:**
  `<p>`yi `<li>`ye çevirip paragraf sayısını değiştiriyor ve eşleme sigortası
  düzenlemeyi tamamen kapatıyor. Liste bir PARAGRAF ÖZELLİĞİ olarak yapıldı:
  işaret CSS'ten çiziliyor, Word tarafında `w:numPr` oluyor — Word'ün kendi
  modeli de tam olarak bu. Kaydetmede `numbering.xml` + `[Content_Types].xml` +
  `document.xml.rels` BİRLİKTE yazılıyor; üçünden biri eksikse Word dosyayı
  "onarılamaz" sayıyor. Liste verilmemişse hiçbir parça eklenmiyor.
- **TUZAK — seçim alt sayfa açılınca kayboluyor:** AI/çeviri sayfası açılırken
  DOM seçimi düşebiliyor; `Range` istek anında saklanıp sonuç yazılırken o
  kullanılıyor.

### E) Slayt: konuşmacı notu
`pptx_render.notes()` `notesSlide*.xml`i okuyor — yalnız `body` yer tutucusunu.
Not sayfasında `sldNum` (sayfa numarası) yer tutucusu da var; alınsaydı her
notun sonuna slayt numarası yapışırdı. Şeridin yüksekliği `_slideExtent`e de
eklendi — kart yüksekliği ANALİTİK hesaplandığı için ikisi ayrışsaydı "slayta
git" notlu destelerde kayardı.

### F) PDF: Türkçe-duyarlı arama
`PdfTextSearcher.startTextSearch` bir `Pattern` (RegExp) kabul ediyor. Paketin
`caseInsensitive` bayrağı yerel-duyarsızdı ("İSTANBUL" ararken "istanbul"u
kaçırıyordu). `turkishSearchPattern` her harfi Türkçe eş biçimlerini kapsayan
bir karakter sınıfına çeviriyor ve eşleştirme büyük/küçük harf DUYARLI
koşuyor — böylece KALANLAR'ın önerdiği "kendi paint callback'ini yaz" yoluna
hiç gerek kalmadı, paketin vurgulaması olduğu gibi kullanılıyor.

### G) Eskimiş KALANLAR maddeleri (kod okunarak kapatıldı)
- "PDF vurgu remount zoom kaybı" — `_pdfReloadKey` yolu 2026-07-26'da
  `PdfReload.reloadFile` ile değiştirilmişti; widget artık hiç remount olmuyor,
  zoom/kaydırma zaten korunuyor.
- "Döndürülmüş sayfa vurgu düzeltmesi" — aynı bölümün üstünde 2026-07-26'da
  ÖLÇÜLÜP yanlış alarm olduğu yazılmış (dört açıda da `/Rect` birebir aynı).
  Madde iki yerde duruyordu; ölçülmemiş bir konvansiyona göre kod yazmak
  "kör push" olurdu.
- "Excel sayfa sekmeleri çip görünümüne alınsın" — sekmeler zaten `ChoiceChip`.
- `withOpacity` temizliği: 10 çağrı `withValues(alpha:)` oldu; `ftp_fs`teki
  sürümler-arası `?.` uyarısı gerekçesiyle susturuldu, `sheet_cell`deki
  gereksiz import kalktı.

### H) Aynı turun ikinci yarısı — notlar, süzgeç, koşullu biçim
- **Hücre notu OKUNUYOR, yazılmıyor (bilinçli).** Not ayrı bir `comments*.xml`
  parçasında ve sayfaya `worksheets/_rels` üzerinden GÖRELİ hedefle bağlı;
  ikisi de çözülüyor. Yazmak için eski VML çizimini (`vmlDrawing1.vml` +
  `<legacyDrawing>`) da üretmek gerekiyor ve eksik/yanlış VML'de Excel dosyayı
  "onarılması gerekiyor" diye açıyor — cihazda doğrulanamayan bir yazma yolu
  eklenmedi. **Ölçüldü:** `excel` paketi tanımadığı zip parçalarını baytı
  baytına taşıyor (`utilities/archive.dart#_cloneArchive`), yani var olan
  notlar kaydetmede KAYBOLMUYOR.
- **TUZAK — `<dxf>` dolgusu `bgColor`a yazılır.** Hücre stilinde renk
  `patternFill/fgColor`a gider; koşullu biçimlendirmenin `<dxf>`inde ise
  `bgColor`a. Ters yazılırsa Excel dolguyu hiç göstermiyor.
- **TUZAK — `cfRule/@priority` POZİTİF olmak zorunda.** İlk yazımda yeni
  kurallara 0 ve negatif öncelik verilmişti (en üstte olsunlar diye); Excel
  bunu kabul etmiyor. Çözüm: var olan kuralların önceliği yeni kural sayısı
  kadar yukarı kaydırılıyor, yenilere 1..n veriliyor.
- **`dxfId` iki tarafta da aynı sırada.** Ekrandaki çizim
  `styles.dxfs[dxfId]`e, dosyadaki kural `styles.xml`deki aynı sıraya bakıyor;
  bu yüzden `<dxf>` tekilleştirmesi bilinçli olarak YOK — aynı rengi
  paylaştırmak indeksleri kaydırıp ekranla dosyayı ayrıştırırdı.
- **Süzgeç gizlemesi sütun başına ayrı.** `filterHidden[col]` kullanıcının
  ELLE gizlediği satırlardan ayrı tutuluyor; süzgeci kaldırmak yalnız o
  sütunun gizlediklerini geri getiriyor ve başka bir sütunun süzgeci hâlâ
  gizliyorsa satır gizli kalıyor.

---

## 2026-08-05 — Depolama sayıları, uygulama boyutu ve hızlı süzgeçler

Kullanıcı, File Manager+ (`com.alphainventor.filemanager`) ile karşılaştırmalı
ekran görüntüleri gönderdi. Üç gerçek eksik ve bir gerçek hata çıktı.

### A) HATA — doluluk satırı iki kez "boş" yazıyordu
Ekranda `281 GB / 464 GB kullanıldı · 182 GB boş(%61) · 182 GB boş`. Sebep:
`an.volume_usage` şablonu zaten `{free} boş` içeriyordu, çağıran üstüne elle
bir kez daha ekliyordu; ayrıca `{used}` yuvasına **toplam** besleniyordu. Tek
şablona indirildi (`{used} / {total} kullanıldı (%{percent}) · {free} boş`).

### B) "464 GB" — `df` yanlış soru soruyordu
`df` yalnız `/data` bölümünü ölçüyor; sistem/vendor/ayrılmış bloklar dışarıda
kalınca 512 GB'lık telefonda 464 GiB çıkıyor. **Android'in kendisi kullanıcıya
bu ham sayıyı göstermiyor:** `StorageStatsManager.getTotalBytes()` içeride
`FileUtils.roundStorageSize()` uyguluyor ve reklam kapasitesine yuvarlıyor
(1,2,4…512 × 1000ⁿ). O algoritma saf Dart'a taşındı (`StorageVolume.
advertisedSize`) — yalnız bu sayı için platform kanalı eklemeye gerek kalmadı.

- **Kapasite ONDALIK biçimleniyor** (`FsPaths.humanCapacity`), dosya boyutları
  1024 tabanında kaldı. İkisi karışınca 512 GB "477 GB" görünüyordu.
- **Boş alan YUVARLANMIYOR** (bilinçli): kullanıcıya dolduramayacağı yer
  varmış gibi göstermek, birkaç GB'lık kozmetik tutarlılıktan daha kötü.
  Fark "kullanılan" tarafında görünüyor — Ayarlar → Depolama da böyle yapıyor.
- Karşılaştırma uygulamasının sayılarıyla birebir örtüştü (196 GB boş, 512 GB).

### C) YENİ — platform kanalı gerçekten gerekiyordu (uygulama boyutları)
`installed_apps` boyut vermiyor, `df` uygulama başına kırılım bilmiyor,
`Android/data` Android 11'den beri başka uygulamalara kapalı. Tek yol
`StorageStatsManager.queryStatsForPackage`.

- **CI `android/` iskeletini her derlemede `flutter create` ile üretiyor**, bu
  yüzden "Kotlin eklenemez" sanılıyordu (HAFIZA 2026-07-25 §F). Doğru değil:
  iş akışı zaten `ci/AndroidManifest.xml` ve `ci/proguard-rules.pro`
  kopyalıyor. `ci/MainActivity.kt` aynı desenle eklendi.
- **Doğrulandı:** build 216 logunda adım çıktısı `package com.dosyaokuyucu.
  dosya_okuyucu` yazdırdı ve `find` tek bir `MainActivity.kt` buldu (java/
  altındaki olası ikizi siliniyor, yoksa "duplicate class").
- İzin `PACKAGE_USAGE_STATS` — son kullanım tarihiyle **aynı** izin, kullanıcı
  bir kez verince ikisi de açılıyor. Kanal yoksa (masaüstü/test/eski APK)
  her çağrı zarifçe boş dönüyor; arayüz sıfır yazmıyor, "bilinmiyor" diyor.
- Ölçüm 200+ binder çağrısı → Kotlin tarafında arka izlekte, Dart tarafında
  5 dakikalık önbellekle. **Boş sonuç önbelleğe alınmıyor:** izin verilip
  dönüldüğünde kullanıcı beş dakika beklemesin.
- `openAppStorageSettings`: `:settings:fragment_args_key` eklentisiyle doğrudan
  "Depolama ve önbellek" alt sayfasına iner; tanımayan ROM'da uygulama bilgisi
  sayfası açılır (tek dokunuş uzakta, yine doğru yer).

### D) Hızlı süzgeçler — kod VARDI, ekranda YOKTU
`CategoryScreen.showSources` bayrağının arkasındaki kaynak çipleri
(WhatsApp/Telegram/Kamera…) hiçbir çağıran tarafından açılmıyordu; yani özellik
yazılmış ama hiç görünmemişti. **Ders:** varsayılanı kapalı bir görünürlük
bayrağı eklerken onu açan en az bir çağıran da aynı commit'te olmalı, yoksa
ölü kod sessizce birikiyor.

Yerine `FmQuickFilters` geldi: çipler **veriden türetiliyor** (listede o kaynak
yoksa çip yok) ve sayı taşıyor. Yanına "Büyük dosyalar" ve **"6 aydır
açılmamış"** eklendi.

- **TUZAK — "son açılma" diye güvenilir bir veri yok.** `FsEntry.lastTouchedMs`
  atime'ı kullanıyor ama Android'de çoğu bağlama `relatime`/`noatime`; ölçüt en
  kötü durumda "şu tarihten eski"ye düşüyor. Kendi açılma veritabanımızı tutmak
  reddedildi: yalnız BİZİM açtığımız dosyaları bilirdi ve kullanıcıya yanlış
  bir tamlık hissi verirdi.

### E) Bellek Analizi büyük kutulara alındı
Araç satırındayken kaydırmadan görünmüyordu (kullanıcı isteği).

## 2026-08-05 (II) — "google drive girmiyorum": kayıt değerleri artık uygulamada

Kullanıcı Drive'a hâlâ giremiyor. Kod tarafında hata YOK; kök neden 2026-07-30'da
saptananla aynı: paket adı + imza SHA-1 ikilisi Google Cloud'da "Android OAuth
istemcisi" olarak kayıtlı değil (ApiException 10). Bu turda eksik olan parça
kapatıldı: **kayıt için gereken iki değer kullanıcının elinde yoktu.**

### CI'dan doğrulanan gerçekler (build 219 logu)
- `ANDROID_KEYSTORE_B64` secret'ı EKLİ → "İmza anahtarı repo secret'ından
  yüklendi (kalıcı)" satırı var; imza tüm derlemelerde AYNI.
- İmza **SHA-1: `F5:5D:0C:09:9F:97:71:3B:7A:1B:8D:B7:E8:6D:6A:0A:DA:EE:9D:B5`**
  (SHA-256: 9eef6704…3718). Paket: `com.dosyaokuyucu.dosya_okuyucu`.

### Yapılan
- `ci/MainActivity.kt` → `appSignatureSha1` metodu (aynı `app_storage` kanalı):
  KURULU APK'nın kendi imza sertifikasından SHA-1 okur. Neden koddan: belgedeki/
  CI logundaki değer eski bir anahtara ait olabilir; uygulamanın gösterdiği
  değer tanım gereği doğru. API 28+ `signingInfo`, öncesi `GET_SIGNATURES`.
- `lib/services/fm/app_signature.dart`: kanal + `colonize()` (saf, birim
  testli). Kanal yoksa CI anahtarının bilinen SHA-1 sabitine düşer.
- `drive_screen`: `notConfigured` hatasında **kurulum kartı** — paket adı ve
  SHA-1, kopyala düğmeleriyle; adım özeti. Yalnız DEĞER kopyalanıyor (Cloud
  formu etiketli yapıştırmayı kabul etmez).
- Giriş ekranı gövdesi `SingleChildScrollView` oldu: hata şeridi + kurulum
  kartı açıkken sabit Column dikeyde taşıyordu (testte yakalandı).
- `docs/GOOGLE-DRIVE-KURULUM.md` gerçek SHA-1 ile güncellendi.

### TUZAK — testte işleyicisiz platform kanalı SESSİZCE ASILI KALIR
`MethodChannel.invokeMethod` widget testinde mock işleyici yoksa hata da
fırlatmayabiliyor; Future hiç tamamlanmıyor ve `pumpAndSettle` sonrası ilgili
satır "yok" görünüyor. Çözüm: `setMockMethodCallHandler(..., (_) async => null)`
— null yanıt aynı zamanda sabite düşüş yolunu da sınıyor.

### KULLANICI ADIMI (kod bunu yapamaz)
console.cloud.google.com → Drive API etkin + OAuth izin ekranı (`drive.file`
kapsamı, Test modundaysa hesabı test kullanıcısına ekle) → OAuth istemci
kimliği (Android) = paket adı + yukarıdaki SHA-1. Uygulamadaki kurulum kartı
iki değeri de kopyalatıyor; yayılması birkaç dakika sürebilir.

## 2026-08-05 (III) — Slayt sadakati: custGeom (serbest çizim) + tema çizgi kalınlığı

Kullanıcı isteği "sadakat geliştirmeleri, araştır-uygula". Tarama sonucu iki
kapanmamış render açığı bulundu ve kapatıldı (ikisi de birim testli):

### A) `a:custGeom` — özel geometri artık ÇİZİLİYOR
Serbest çizim / "Noktaları Düzenle" çıktısı şekiller `prstGeom` olmadığı için
düz DİKDÖRTGEN çıkıyordu. Yeni: `PptxCustomGeom`/`PptxCustPath`
(pptx_geometry, saf dart:ui) + `_customGeom` ayrıştırıcısı (pptx_render) +
`_GeometryPainter.pathFor` özel yolu tercih ediyor.
- Komutlar: moveTo/lnTo/cubicBezTo/quadBezTo/arcTo/close. arcTo merkezi
  mevcut noktadan GERİ hesaplanır (ECMA); açılar 1/60000 derece.
- `a:path@w/@h` yoksa koordinatlar şeklin EMU uzayında → ext cx/cy uzay olur.
- `fill="none"` alt yol dolgudan DIŞLANIR ama kenarlıkta durur (fillOnly).
- **Bilinçli sınır:** `gdLst` formül kılavuzları çözülmüyor; koordinat sayı
  değilse TÜM geometri reddedilir → dikdörtgene düşülür (yanlış çizim yok).
- TUZAK (testte): üçgen köşesini x=0'a koyup "fillOnly sol kenara değmez"
  beklemek çelişki — fikstür köşeleri sınırlardan uzak seçilmeli.

### B) `p:style > a:lnRef@idx` kalınlığı artık temadan
Tema stilli şekillerde kalınlık sabit 0.75pt varsayılıyordu; şimdi
`a:fmtScheme > a:lnStyleLst`ten idx (1 tabanlı) ile okunuyor
(`_themeLineWidths`, master başına önbellekli). Tema yoksa 0.75 kalır.

Doğrulama: yerel Flutter 3.29.3 `analyze` temiz, `flutter test` 1230 yeşil.
Dal: claude/google-drive-connection-xpsmgn (PR #34, Drive işiyle birlikte).

## 2026-08-05 (IV) — Drive 403'ü: giriş ÇALIŞTI, liste düştü (kullanıcı ekran görüntüsü)

Kullanıcı OAuth kaydını yaptı; ekran görüntüsünde **giriş başarılı** (çıkış/yenile
düğmeleri ve arama çubuğu görünüyor) ama `files.list` **403** dönüyor ve ekranda
"Drive bu işleme izin vermedi. Bu dosya uygulamamızla yüklenmemiş olabilir."
yazıyor. Bu metin YANLIŞ yere baktırıyor: liste çağrısının dosya sahipliğiyle
ilgisi yok.

### Kök neden sınıfı — 403 TEK bir şey değil
- `accessNotConfigured` → **Cloud projesinde Drive API etkin değil.** Kurulumun
  en sık atlanan adımı: OAuth istemcisi kaydedilir, API kitaplıktan açılmaz →
  giriş çalışır, HER çağrı 403. En olası neden bu.
- `insufficientPermissions` → jeton `drive.file` kapsamını taşımıyor.
- Tanınmayan 403 → eski "dosya bizim değil" yorumu.

### Yapılan
- `DriveService.classify(status, body)`: 403 gövdesindeki `reason`/mesaja bakıp
  `apiNotEnabled` / `insufficientScope` / `forbidden` ayırıyor. `errorFor` (yalnız
  durum kodu) duruyor ve testte kalıyor.
- İki yeni metin: API'yi nereden açacağını (Console → Kitaplık → Google Drive
  API → Etkinleştir) ve kapsam eksikse ne yapacağını (çıkış → yeniden bağlan)
  ADIM ADIM söylüyor.
- **Google'ın kendi `error.message`i artık ekranda.** Eskiden yalnız
  sınıflandırılamayan GİRİŞ hatasında gösteriliyordu; `_refresh` içinde
  `e.detail` atılıyordu — bu yüzden ekran görüntüsünden 403'ün nedeni
  okunamadı. Alan `_signInDetail` → `_errorDetail` olarak adlandırıldı.
- **Çelişki giderildi:** hata şeridi varken "Henüz bu uygulamayla Drive'a dosya
  yüklemediniz." de yazıyordu (ekran görüntüsünde ikisi birden). Liste boş
  çünkü çağrı düştü; kullanıcı yüklemediği için değil. Hata varken boş-liste
  metni çizilmiyor.

### DERS
Sınıflandırdığımız hatalarda ham mesajı gizlemek, sınıflandırmanın YANLIŞ
olduğu durumda teşhisi imkânsızlaştırıyor. Ham metin her hata için görünür
kalmalı (kullanıcı ekran görüntüsü tek teşhis aracı).

### AÇIK KARAR — kapsam
Kullanıcı "diğer Drive dosyalarını göremez miyiz, klasör açamaz mıyız" diye
sordu. `drive.file` ile klasör oluşturma/yönetme MÜMKÜN (klasör de bir dosya,
uygulamanın oluşturduğu her şeye erişilir); TÜM Drive'ı gezmek `drive` kapsamı
ister — kısıtlı kapsam, Test modunda (≤100 test kullanıcısı) ücretsiz çalışır,
YAYINLAMAK için ücretli CASA denetimi şart. Karar kullanıcıya soruldu.

## 2026-08-05 (V) — KAPSAM KARARI DEĞİŞTİ: `drive.file` → `drive` (tam erişim)

Kullanıcı *"diğer drive dosyalarını göremez miyiz, klasör oluşturma vs
yapamaz mıyız"* diye sordu; seçenekler bedelleriyle sunuldu ve **tam erişimi**
seçti. 2026-07-30'daki "`drive.file` yeter, CASA denetimi istemiyoruz" kararı
bu tarihten itibaren GEÇERSİZ.

### Bedeli — yazılı ve bilinçli
`drive` Google'ın *restricted* kapsamı. OAuth izin ekranı **Test** modundayken
ücretsiz çalışıyor (≤100 test kullanıcısı, e-postalar elle eklenir). **Yayına
almak** (Play Store) yıllık ve ücretli üçüncü taraf güvenlik denetimi (CASA)
istiyor. KALANLAR'daki Play Store hedefi bu kapsamla birlikte yeniden
değerlendirilmeli — ikisi aynı anda ücretsiz olmuyor.

### Servis (`drive_service.dart`)
- `scope` = `.../auth/drive`, `rootId = 'root'`.
- `listUri(parentId:)` → `'<id>' in parents` ile **klasör gezinme**;
  `orderBy` artık `folder,name` (dosya yöneticisi sıralaması).
- **Arama klasör sınırı TANIMAZ:** query verilince parent süzgeci düşer,
  Drive'ın tamamında aranır (dosya yöneticilerinin beklenen davranışı; testle
  sabit).
- `createFolder` / `rename` / `move`; `upload(parentId:)` → `parents` üstverisi.
- **TUZAK — iki ayrı uç nokta:** yeniden adlandırma `www.googleapis.com/drive/v3`
  (üstveri), içerik yazma `upload.../drive/v3`. Adı upload adresine göndermek
  dosyanın İÇERİĞİNİ ezerdi. `metadataUri` bu yüzden `updateUri`den ayrı ve
  ikisinin ayrı kaldığı testle sabitlendi.
- **TUZAK — taşımada `removeParents` şart:** yalnız `addParents` yazmak dosyayı
  iki klasörde birden gösterir (Drive'da "üst klasör" çoklu bir alan).

### Ekran (`drive_screen.dart`)
- Kırıntı yolu (herhangi bir parçaya dokunmak oraya döner), klasöre girme,
  **geri tuşu bir üst klasöre** (`PopScope`; kökte ekranı kapatır), klasör
  oluştur, yeniden adlandır, bulunulan klasöre yükle, arama temizleme (×).
- **Kapsam uyarısı şeridi KALDIRILDI** — "yalnız bu uygulamayla yüklediğiniz
  dosyalar görünür" artık yanlış olurdu. `drive.scope_notice` anahtarı silindi.
- `drive.empty` metni "henüz yüklemediniz" → **"Bu klasör boş."**; aramada
  ayrı metin. Eski metin tam erişimde yanlış yönlendirirdi.
- Arama sürerken gezinme düğmeleri kapalı: sonuçlar klasör sınırı tanımadığı
  için "hangi klasördeyim" sorusunun cevabı o sırada yok.
- **Bilinen sınır:** arama sonucundan bir klasöre girilince kırıntı yolu
  kökten kurulur (gerçek üst zincir bilinmiyor); "yukarı" köke döner. Listeleme
  doğru, yalnız yol gösterimi kısa.

### KULLANICI ADIMI — kapsam büyüdü, yeniden izin ŞART
Elde `drive.file` jetonu varsa yeni sürümde 403 gelir. Uygulamada bir kez
**Bağlantıyı kes → Google ile bağlan** gerekiyor; ayrıca Cloud'da OAuth izin
ekranına `.../auth/drive` kapsamı eklenmeli. Belge (`docs/GOOGLE-DRIVE-KURULUM.md`)
sorun giderme tablosuyla güncellendi.

## 2026-08-05 — PDF'te "premium" metin seçimi: Chrome eşdeğeri, taranmış sayfa dahil
Kullanıcı isteği: *"PDF üzerindeki metinleri normal metin seçer gibi seçebilmek
istiyorum, taranmış veya yazılmış fark etmez; Chrome PDF görüntüleyicisi bunu
çok güzel yapmış, şu anki sistemimiz kullanışlı değil."* Eski davranış yalnız
uzun basış + tutamaçtı; sürükleyerek büyütme, fare desteği ve taranmış sayfa
desteği hiç yoktu.

### A) Sürükleyerek seçim, pan kilidini KIRMADAN (`pdf_select_layer.dart`)
Uzun basış kelimeyi seçer; parmak kalkmadan sürüklenirse seçim KELİME KELİME
büyür (Android/Chrome yerlisi). Bunu jest arenasına girmeden yapmanın yolu:
- Katman hâlâ yalnız `Listener` (arena tuzağı için bkz. 2026-07-26 kayıtları;
  `pdf_select_layer_gestures_test` kaynak düzeyinde korumaya devam ediyor).
- Seçim başladığı an katman `onSelectingChanged(true)` bildirir,
  `viewer_screen` `PdfViewerParams.panEnabled: false` yapar. **Bu güvenli**:
  pdfrx'in `InteractiveViewer`'ı bayrağı HER olayda okur (jest ortasında bile
  etkili) ve params değişimi belgeyi yeniden YÜKLETMEZ (yalnız documentRef
  değişiminde yükler; kaynaktan doğrulandı, pdfrx 1.3.5 `_widgetUpdated`).
- Kilit yalnız işaretçi yerdeyken sürer: up/cancel/ikinci parmak anında
  `false` bildirilir; katman sökülürse `dispose` post-frame ile açar. Eski
  "seçim modu açıkken pan hep kapalı" hatasına (2026-07-26) dönüş yapısal
  olarak engelli — widget testi `selectingLog == [true, false]`'u kilitliyor.
- Sürüklerken parmağın 66 px üstünde `RawMagnifier` büyüteç gezer (yerel his);
  tutamaç sürüklemede de var. Tutamaçlar karakter, sürükleme kelime hassaslığı.
- "En yakın karakter" araması artık düz dizide (ekran-koordinat önbelleği,
  `_ensureGeometry`); sürüklemede her olayda `PdfRect→Rect` çevirisi yapılmıyor.

### B) Fare (masaüstü): Chrome birebir
Metin üstünde imleç I-kirişi (`MouseRegion` `opaque: false` — hit-test'ten
hiçbir şey çalmaz), bas-sürükle karakter seçimi (basıldığı AN pan kilidi →
ilk pikseller pdfrx'e kaçmaz), çift tık kelime, boşluğa/metne tık seçimi
çözer. Metin DIŞINDA bas-sürükle sayfayı kaydırmaya devam eder. Ctrl/Cmd+C
kopyalar (`CallbackShortcuts`, `viewer_screen`).

### C) Taranmış sayfa = cihaz-içi OCR ile aynı seçim yolu
- `services/pdf/ocr_page_text.dart`: ML Kit sözcük kutuları → **sahte
  `PdfPageText`** (`buildOcrPageText`, saf fonksiyon + birim test). Kritik
  çeviri: görüntü pikseli y-AŞAĞI → PDF puntosu y-YUKARI (`top > bottom`);
  karakter kutuları sözcük kutusunun eşit dilimleri, sözcük arası boşluklara
  ARADAKİ aralık verilir (vurgu kesintisiz), satır sonuna sıfır genişlik '\n'.
  Satır sırası ML Kit'in blok sırası — y'ye göre YENİDEN SIRALAMA YOK (çok
  sütunlu sayfayı karıştırır).
- `services/pdf/pdf_ocr_text.dart`: sayfa→PNG (OcrService.renderPageToPng,
  artık ölçek de döndürür) → `recognizeImageWordLines` (ML Kit satır
  `elements`ları) → önbellek (24 sayfa LRU, anahtar `sourceName#sayfa`;
  "metin yok" da önbelleklenir — pil). `debugOcrOverride` test kancası tüm
  boru hattının yerine geçer (Linux'ta ne ML Kit ne pdfium render var).
- Katman OCR'ı ANCAK kullanıcı taranmış sayfada uzun basınca tetikler
  (görünür her sayfayı otomatik OCR'lamak pil yakardı; Chrome de tembel).
  Çip: "Metin tanınıyor…" → bitince basılan kelime seçili gelir, parmak hâlâ
  yerdeyse sürükleme kipi de açılır. Metin çıkmazsa "Sayfada seçilebilir
  metin bulunamadı" 2,4 sn görünür. pdfium metni <8 karakterse sayfa
  "taranmış" sayılır (yalnız sayfa numarası kırıntısı olan taramalar için).
- `onSelected` artık `fromOcr` bayrağı taşır: OCR seçiminde **Düzenle
  gizlenir** (gerçek metin akışı yok, yerinde düzenleme imkânsız); Vurgula/
  Kopyala/Çevir çalışır (vurgu zaten dikdörtgen tabanlı). KVKK: OCR tamamen
  cihazda, geçici PNG işi bitince siliniyor.

### Tuzak/karar notları
- `PdfPageTextFragment.fromParams(...)` pdfrx 1.3.5'te public — sahte fragment
  üretmek için Mock gerekmiyor; `PdfPageText` de soyut sınıf, `OcrPageText`
  düz alt sınıf. Widget testinde `PdfPage`/`PdfDocument` `implements` +
  `noSuchMethod(throw)` ile taklit edildi (yanlışlıkla pdfium'a inen yol testte
  hemen patlar).
- Reddedilen yol: OCR metnini görünür her sayfada otomatik başlatmak (pil) ve
  satırları y'ye göre sıralamak (çok sütun bozulur).
- Yapılmadı (bilinçli, istenirse sonraki tur): sayfalar ARASI kesintisiz seçim
  (katman sayfa başına; Chrome yapabiliyor), sürüklerken kenarda otomatik
  kaydırma. İkisi de görüntüleyici düzeyinde eşgüdüm ister.

**Doğrulama:** Linux bulut oturumunda Flutter 3.29.3 (CI ile aynı) —
`flutter analyze` 0 hata/0 uyarı, **1254 test yeşil** (+13: 5 birim
`ocr_page_text_test`, 8 widget `pdf_select_layer_widget_test` — uzun basış +
sürükleme, büyüteç, fare sürükleme/çift tık, OCR çipi/bayrağı/boş sonucu,
iki parmak kilidi). Cihaz doğrulaması: taranmış PDF'te uzun basış → çip →
seçim; yazılmış PDF'te sürükleyerek büyütme + zoom/kaydırmanın ÖLMEDİĞİ.

## 2026-08-05 (2. tur) — Seçim tamamen otomatik + üç premium dokunuş
Kullanıcı: *"kullanıcıya bir şey bırakmamalısın, otomatik olmalı — özellikle
mobilde; benzer premium geliştirmeleri sen bul ve uygula."* İlk turda OCR
uzun basışla tetikleniyordu; artık kullanıcıdan hiçbir şey beklenmiyor.

### A) OCR artık KENDİLİĞİNDEN (`_maybeAutoOcr`)
Taranmış sayfa görünür olup metin katmanı "ince" çıkınca katman **350 ms
sonra** OCR'ı sessizce başlatır: çip yok, jest yok — sayfa kullanıcı daha
dokunmadan seçilebilir olur (premium davranış görünmez olandır). 350 ms
gecikme + katman sökülünce zamanlayıcı iptali = hızla kaydırılıp geçilen
sayfalar HİÇ OCR'lanmaz (pil); testle kilitli. Çip yalnız kullanıcı OCR
bitmeden basarsa görünür (`_ocrInteractive`), bitince bastığı kelime seçilir.
OCR bitmiş ve sayfada gerçekten metin yoksa uzun basışta "bulunamadı" çipi.

### B) Çift dokunuş kelime seçer (mobil Chrome paritesi)
İki hızlı dokunuş (<300 ms, <30 px) kelimeyi seçer. pdfrx 1.3'te çift tık
jesti YOK (kaynaktan bakıldı), çakışma olmaz. Tek dokunuş seçimi temizlemeye
devam eder. Çift dokunuşta sürükleme kipi/pan kilidi AÇILMAZ (parmak yerde
değil — kilit açılsaydı asılı kalırdı; test `selectingLog == []`).

### C) Kenar oto-kaydırması (Chrome'un seçim akışı)
Sürükleme (uzun basış büyütmesi / tutamaç / fare) ekran kenarına yaklaşınca
görüntü o yöne akar, seçim büyümeye devam eder. Kurulum:
- Saf `edgeAutoScrollDelta` (`services/pdf/edge_auto_scroll.dart`, birim
  testli): 56 px kenar payı, doğrusal hızlanma, tavan 14 px/kare (~840 px/sn),
  küçük görüntüde pay extent/3'e daralır (ölü bölge hep kalır).
- Katman `onDragAt(global|null)` bildirir (null'lar DENGELİ: her bitişte ve
  dispose'ta — aksi hâlde zamanlayıcı sonsuza dek koşardı).
- Viewer 16 ms'lik `Timer.periodic` ile `_pdfController.value = value..
  leftTranslate(-d)` iter. **Güvenli**: `PdfViewerController.value` setter'ı
  `makeMatrixInSafeRange`ten geçer (pdfrx 1.3.5:1750) → belge sınırı dışına
  çıkılamaz; pan kilidi programatik matrisi etkilemez. Zamanlayıcı işaretçi
  olaylarından bağımsız → parmak kenarda hareketsiz dursa da akış sürer.
- Bilinen sınır: sayfa parmağın altından akarken seçim ucu ancak parmak
  kımıldayınca güncellenir (işaretçi olayı gerekir; parmak doğal titrer).

### D) Tek etkin seçim (`activeSelectionPage`)
Eskiden iki sayfada iki vurgu kalabiliyordu (her katman kendi durumunu
tutar). Viewer artık seçimi taşıyan sayfayı katmanlara verir; başka sayfa
devralınca katman vurgusunu `didUpdateWidget`te SESSİZCE bırakır (rapor yok —
rapor devralanın seçimini ezerdi; testle kilitli). Boş seçim raporunda
`_pdfSelPage = 0`.

**Doğrulama:** Flutter 3.29.3 — `analyze` 0 hata/0 uyarı, **1264 test yeşil**
(+10: 5 `edge_auto_scroll_test`, 5 widget: otomatik OCR sessizliği, sökülen
sayfanın OCR'lanmaması, çift dokunuş, sahiplik devri, onDragAt dengesi).
1. turun CI'si (run 226 / bcc2ab8) YEŞİL — APK release'e çıktı. Cihazda
bakılacaklar: taranmış sayfada hiç dokunmadan ~1 sn sonra uzun basışın anında
seçmesi, kenarda akışın hızı (56/14 sabitleri), çift dokunuşun yazı dışında
yanlış tetiklenmemesi.

## 2026-08-05 (3. tur) — "Mükemmel belge tarama": tamamen otomatik boru hattı
Kullanıcı: *"belge tarama işine de el at, mükemmel bir belge tarama sistemi
kur"* + önceki turun ilkesi (*"kullanıcıya bir şey bırakma, otomatik olmalı"*).
Tarama hattının iskeleti zaten iyiydi (ML Kit tarayıcı → inceleme/filtre →
A4 PDF + görünmez OCR katmanı → sonuç ekranı); bu tur kalan el işlerini
otomatikleştirdi.

### A) "Aranabilir olsun mu?" penceresi KALDIRILDI — OCR hep koşar
Cihaz içi OCR sayfa başına ~yarım saniye; doğru cevabı bildiğimiz soruyu
sormak kullanıcıya iş çıkarmaktı. Artık her tarama kendiliğinden aranabilir,
metin sekmesi hep dolu gelir VE belge adını içeriğinden alır. Kaldırılan
l10n anahtarları: sf.scanned_title/scanned_body/image_only/with_ocr.

### B) Akıllı adlandırma (`services/scan_title.dart`, saf + birim testli)
"Tarama 2026-08-05 171234.pdf" → "SAĞLIK RAPORU 2026-08-05.pdf" (Drive
tarayıcısı davranışı). Sezgisel: satırlar y'ye sıralanır, ilk 14 aday içinde
`kutu yüksekliği × (1 − 0,015·sıra)` en yüksek satır başlıktır (punto vekili
kutu yüksekliği); kısa üst başlık ("T.C.") altındaki benzer puntolu satırla
birleşir; dosya-yasağı karakterler ayıklanır, 48 karakterde kelime sınırından
kesilir. Başlık çıkmazsa eski damgalı ad. `DocumentScanner.savePdf` artık
`FileOps.uniquePath` kullanır — aynı belge iki kez taranınca ikincisi
"(1)" alır, SESSİZCE EZİLMEZ (akıllı ad çakışmayı olağanlaştırdı).

### C) PDF boyutu: uzun kenar 2480 px (A4 @ 300 dpi)
`ScanEnhance.applyToImage` borunun BAŞINDA küçültür (12MP kamera ~4000 px
üretiyor; fazlası OCR'a/baskıya katkısız, sayfa başına birkaç MB şişkinlik).
Filtreler de küçük görselde ~2-3 kat hızlandı. `ScanFilter.original` bilerek
tam çözünürlük kalır (dosyaya hiç dokunulmayan yol). Köşe düzeltme etkilenmez
(kaynak üzerinde çalışır, filtre sonrası görüntü yalnız gösterim+PDF girdisi).

### D) Sonuç ekranı: yeniden adlandır + sayfa ekle
- Kayıt satırı artık dosya ADINI da gösterir; kalem → ad değiştirme
  (`FileOps.rename`; FAT32 büyük/küçük harf tuzağı orada zaten çözülü).
- **"Sayfa ekle"**: tarayıcı → inceleme/netleştirme → yalnız YENİ sayfalar
  OCR'lanır → PDF aynı yolda yeniden kurulur (masaüstü tarayıcının "beslemeye
  devam et"i). Bunun için OCR SATIRLARI (kutulu) akıştan sonuç ekranına
  taşınıyor (`ScanResultScreen.ocrLines`) — düz metin yetmez, görünmez katman
  kutular ister. OCR'sız eski taramada hizalama `while (_lines.length <
  _pages.length) _lines.add(const [])` ile korunur.

**Doğrulama:** Flutter 3.29.3 — `analyze` 0 hata/0 uyarı, **1274 test yeşil**
(+10: 7 `scan_title_test`, 3 `scan_enhance_resize_test`; mevcut
`scan_enhance_test` 60x40 sentetik görselleri eşiğin altında, kırılmadı).
Cihazda bakılacaklar: gerçek belgede başlık isabeti (fatura/rapor/kimlik),
"Sayfa ekle" sonrası PDF sayfa sırası, 2480 px'in yakınlaştırmada yeterliliği.

## 2026-08-05 (4. tur) — Taranmış PDF'te ARAMA + OCR disk önbelleği
"Taranmış veya yazılmış fark etmez" sözünün son parçası: seçim/kopyalama OCR
ile çalışıyordu ama **belge içi arama** pdfrx'in pdfium arayıcısına bağlıydı,
taranmış sayfada kördü. Ayrıca OCR sonuçları yalnız bellekteydi — uygulama
kapanınca uçuyor, aynı belge her açılışta yeniden OCR'lanıyordu.

### A) OCR disk önbelleği (`pdf_ocr_text.dart` 2. katman)
- `encodeOcrPageText`/`decodeOcrPageText` (saf JSON, birim testli — kutular
  BİREBİR dönmeli, kayıp = yeniden açılışta kayan seçim) + `fnv1a` (kararlı
  64-bit özet; `hashCode` OLMAZ: Dart oturumlar arası kararlılık vaat etmez;
  işaret biti maskelenir yoksa `toRadixString` '-' üretip dosya adını bozar).
- Anahtar: yol + mtime + boyut → dosya değişince eski girdi kendiliğinden
  ıskalanır. "Metin yok" da `yok` işaretiyle saklanır (boş taranmış sayfa her
  açılışta OCR'lanmasın). Kap: 300 sayfa dosyası, taşınca en eski silinir.
- **TUZAK — platform kanalı kritik yolda beklenmez:**
  `getApplicationSupportDirectory` flutter_test'te İLERLEMEZ; ilk sürümde
  `_diskRead` bunu await ediyordu ve üç seçim widget testi "OCR hiç koşmadı"
  diye kırıldı (HAFIZA §F "gerçek asenkron iş ilerlemez" tuzağının kanal
  biçimi). Çözüm `_dirSync()`: dizin çözülmemişse arka planda ısındırılır,
  o çağrı diski atlar (OCR ~1 sn sürdüğünden yazma anına dek dizin hazır).
- KVKK notu: önbellek uygulamanın KENDİ destek dizininde, belgenin kendisiyle
  aynı mahremiyet düzeyinde; buluta çıkmaz.

### B) Taranmış sayfalarda arama (`pdf_ocr_search.dart` + viewer)
- `PdfOcrSearch` (ChangeNotifier): metin katmanı ince (<8 karakter, seçim
  katmanıyla aynı eşik) sayfaları `PdfOcrText` üzerinden OCR'layıp deseni
  OCR metninde arar; eşleşme kutuları `selectionPdfRects` ile (vurgu, seçim
  vurgusuyla aynı satır geometrisi — bu yüzden yardımcılar
  `services/pdf/selection_rects.dart`a taşındı, `pdf_select_layer` eski
  adresten `export` ediyor, hiçbir import/test kırılmadı).
- Arama kullanıcının BAKTIĞI sayfadan başlar (ilk sonuçlar gözün önünden);
  yeni arama generation sayacıyla eskisini iptal eder; sayfa başına
  `notifyListeners` → sayaç canlı büyür. OCR bütçesi: bir aramada en çok
  40 YENİ sayfa OCR'lanır (önbellekli sayfalar bütçe yemez), atlananlar
  `skippedPages`te sayılır — sessiz kesme yok.
- Viewer birleşik gezinme: pdfrx + OCR eşleşmeleri sayfa sırasına dizilir;
  imleç SAYI değil KAYIT (`_findEntry`) — OCR eşleşmeleri damla damla
  gelirken sayı kayardı. İleri/geri: pdfrx eşleşmesine `goToMatchOfIndex`,
  OCR eşleşmesine `goToRectInsidePage`. OCR vurguları `pagePaintCallbacks`te
  pdfrx'in varsayılan renkleriyle boyanır (sarı/turuncu, %50) — kullanıcı
  hangi motorun bulduğunu AYIRT EDEMEZ. Sayaç OCR sürerken "n/m…" (üç nokta).

**Doğrulama:** Flutter 3.29.3 — `analyze` 0 hata/0 uyarı, **1284 test yeşil**
(+10: 5 `ocr_disk_cache_test` — gidiş-dönüş, bozuk girdi, fnv, iki-oturum
diskten dönüş, "yok" işareti; 5 `pdf_ocr_search_test` — ince/dolu sayfa
ayrımı, baktığın-sayfadan-başlama, generation iptali, bütçe sayacı, reset).
Cihazda bakılacaklar: taranmış PDF'te arama vurgusunun konumu, 40-sayfa
bütçesinin uzun taramalarda hissiyatı, arama sayacının canlı büyümesi.

## 2026-08-05 (5. tur / gece) — Düzenlemede isabet, ana ekran hızlı erişim, Drive terfisi
Kullanıcı (yatarken, işler bize emanet): *"ana ekranı geliştir; Drive daha
kolay erişilebilmeli, şu an zor bulunuyor; PDF düzenlemede daha serbestlik ve
isabet istiyorum, yazıları değiştirirken şu an yeterli değil, büyük küçük
yazım; main'e merge et, APK derlensin."*

### A) PDF yerinde düzenleme: kademeli eşleşme + konumla hedefleme
(`pdf_text_replace.dart` — "bulunamadı"ların ve yanlış-yeri-değiştirmenin ilacı)
- **Üç geçişli arama:** 1) birebir (eski davranış — birebir varken katlama
  DEVREYE GİRMEZ, testle kilitli); 2) katlama: ligatürler açılır (ﬁ→fi …),
  tipografik tırnak/çizgi tekilleşir (’→', –→-, …→...); 3) katlama + Türkçe
  küçük harf. pdfium'un çıkardığı metin (seçilen) ile /ToUnicode çözümü tam
  bu karakterlerde ayrışıyor ve kullanıcı üstü-kapatma yedeğine düşüyordu.
- **TUZAK — `toLowerCase` Türkçede kullanılamaz:** Dart'ta 'İ'.toLowerCase()
  'i̇' (i + U+0307) üretir, eşleşme yine kaçar. I→ı, İ→i elle eşlendi.
- **Konumla hedefleme:** `replaceTextInContent(nearX:, nearY:)` — bir geçişte
  birden çok eşleşme varsa seçim kutusuna (dikey ağırlıklı: |Δy|·3+|Δx|)
  en yakın olan değişir. Bağlam öneki yine önce gelir (daha güçlü kanıt),
  konum bağlamın çözemediğinin hakemi. `PdfEditFlow` seçim kutularının
  birleşimini `nearRect` olarak geçirir; isolate sınırından düz liste geçer.
- Katlamada koordinat eşlemesi: `_flatten(transform:)` açılan her karakteri
  AYNI kaynak (op, karakter) çiftine bağlar — eşleşme sınırı ligatürün
  ortasına düşse bile değiştirme bütün kaynak karakteri kapsar. Yeni metin
  daima kullanıcının YAZDIĞI gibi girer (dönüşüm yalnız aramada).
- 7 yeni birim test (`pdf_replace_matching_test`); mevcut 70 düzenleme testi
  aynen yeşil (davranış geriye uyumlu: tek eşleşme + birebir = eski yol).

### B) Ana ekran: hızlı erişim şeridi (Son belgeler sekmesi)
Dört kapı: **Tara · Google Drive · PDF araçları · Yeni belge** — liste boşken
de görünür (boş durumda da Drive'a/taramaya tek dokunuş). Renkli daire +
etiketli kompakt kartlar, yatay kaydırılır.

### C) Google Drive: araç simgesinden BÜYÜK karta terfi (dashboard)
Çöp kutusuyla aynı hikâye (2026-07-31): 12 küçük simge arasında kaybolan tek
kapı. Artık kategori ızgarasında "Buluttaki dosyalar" alt yazılı büyük kart;
araçlar ızgarasından çıkarıldı (NAS orada kaldı — onu kuran bilir, Drive'ı
herkes arar). Yeni anahtar: `fm.drive_subtitle`.

**Doğrulama:** Flutter 3.29.3 — `analyze` 0 hata/0 uyarı, **1291 test yeşil**
(+7 eşleşme testi). Cihazda bakılacaklar: büyük/küçük harfli belgede yerinde
düzenlemenin artık "bulunamadı" dememesi; aynı kelimenin iki geçtiği sayfada
dokunulanın değişmesi; ana ekrandaki şeridin dar ekranda taşmaması.

## 2026-08-06 — PDF seçim/kopyalama düzeltmeleri + Drive indirme ilerlemesi
Kullanıcı (ekran görüntüleriyle): *"Drive'da büyük PDF açarken ne olduğu belli
değil, ilerleme lazım; kopyalanan metinde anlamsız karakter var; üst alanda
seçim yaparken tüm sayfa seçiliyor; 'Fizik Muayene' iki satır yapışıyor, tek
satır olmalı."*

### A) Pano temizliği — `core/copy_text.dart` (`cleanPdfCopyText`)
- **KÖK NEDEN:** pdfium `fullText` satır sonlarını `\r\n` verir ve eşlemesiz
  glifler için U+FFFE bırakır; panoya aynen gidince Not uygulamasında tofu
  (⍰) ve bölünmüş satırlar görünüyordu.
- Kural: tek satır sonu → boşluk (2+ = paragraf, tek `\n` kalır); C0/C1,
  soft hyphen, sıfır genişlikli, BOM, U+FFFD..U+FFFF atılır; satır sonunda
  tireyle bölünen kelime birleşir (devam küçük harfse). YALNIZ kopyalama
  yolunda (`_copyPdfSelection`) — seçim katmanının ham metni (yerinde
  düzenleme eşleştirmesi) DEĞİŞMEDİ.

### B) "Tüm sayfa seçiliyor" — iki kök neden, iki düzeltme
1. **`mergeSameLineRects` yatay sınır tanımıyordu:** akış şemasında sol/sağ
   kutular aynı hizada diye aradaki boşlukla birlikte TEK banda birleşiyordu
   → vurgu sayfa genişliğinde görünüyordu. Artık boşluk satır yüksekliğinin
   2 katını aşarsa birleşmez (kelime aralığı ≠ sütun aralığı).
2. **Sürükleme araması düz uzaklık kullanıyordu:** parmak kutular arası
   boşluğa taşınca "en yakın karakter" BAŞKA kutuda bulunuyor, seçim
   sıçrıyordu. `_charIndexAt`e `lineBias` (dikey ceza ×4) eklendi — seçim
   parmağın satırına kilitli kalır, alt kutuya ancak parmak gerçekten
   inince geçer (fare sürüklemesi ve tutamaçlar da aynı yolu kullanır).

### C) Drive indirme: ilerleme penceresi
- `DriveService.download` artık AKAN gövdeyle (`Client().send`) iner ve
  `onProgress(inen, toplam?)` bildirir; toplam Content-Length'ten, yoksa
  Drive üstverisinden (Google biçimi export'ta null → belirsiz çubuk).
  `http.Client()` `runWithClient` zonuna saygılı → MockClient testleri akan
  yolda da çalışıyor.
- `DriveScreen._open`: çıplak `_busy` spinner yerine adlı pencere — dosya
  adı + çubuk + "12,3 MB / 29,0 MB · %42". `EntryOpener._showBusy` de
  "Dosya açılıyor…" yazan karta dönüştü (`open.opening`).
- TUZAK: ilerleme `ValueNotifier`'ı bilerek dispose edilmiyor — pencerenin
  kapanış animasyonu sürerken `ValueListenableBuilder` hâlâ dinliyor
  olabilir; dispose sonrası removeListener debug'da fırlatır.

**Doğrulama:** Flutter 3.29.3 (CI ile aynı) — `analyze` 0 hata/0 uyarı (45
önceden var olan info), **1302 test yeşil** (+11: pano temizliği 7, sütun
birleşmeme 2, indirme ilerlemesi 2). Cihazda bakılacaklar: Drive'dan büyük
PDF'te yüzdeli pencere; akış şemalı PDF'te seçim vurgusunun kutulara
yapışması; kopyalanan metnin Not'ta tek satır ve tofu'suz yapışması.

## 2026-08-06 (2. tur) — Drive önbelleği + Word'de telefonda akış varsayılanı
Kullanıcı: *"her açma istediğimde tekrar tekrar indiriyor"* ve *"word
belgelerinde bulanık görünüm var, zoom yapınca düzeliyor ama hep düzgün
görünmeli"*. (İlerleme penceresi sahada doğrulandı — ekran görüntüsü:
"Drive'dan indiriliyor… 26 MB / 40 MB · %65".)

### A) Drive indirme önbelleği — `services/fm/drive_cache.dart`
- Eski `_open` her dokunuşta koşulsuz indiriyordu. Artık yol düzeni
  `drive/<dosya kimliği>/<yerel ad>` (kimlik klasörü: Drive'da aynı adlı iki
  dosya birbirini ezmesin) ve `DriveCache.freshFile` taze kopyayı bulursa
  indirme + pencere tamamen atlanır.
- Tazelik (saf `isFresh`, birim testli): boyut Drive üstverisiyle tutmalı
  (yarım inmiş kopyayı yakalar; Google biçimlerinde boyut gelmez → atlanır)
  VE yerel değişiklik zamanı buluttan eski olmamalı. Yerel > bulut bilerek
  taze sayılır — uygulama içi düzenleme sessizce ezilmesin.
- `prune`: kök 400 MB'ı aşarsa en eski dokunulan kimlik klasörleri silinir;
  eski düz düzenin (`drive/<ad>`) artık dosyaları da temizlenir.

### B) Word "bulanık" — telefonda VARSAYILAN artık MOBİL AKIŞ
- Kök neden 2026-07-28'dekiyle aynı (çözünürlük değil ÖLÇEK: A4 794 px →
  telefonda sığdırma ~%48 → 11 punto ~5 px). Akış görünümü o gün yapılmıştı
  ama varsayılan SAYFAydı; kullanıcı bugün "hep düzgün görünmeli" deyince
  karar değişti: dar ekranda (shortestSide < 600) belge AKIŞLA açılır,
  sayfa düzeni tek dokunuş ("Sayfa düzeni"). Geniş ekranda sayfa kalır
  (ölçek ~1, sorun yok). Karar ilk build'de bir kez verilir (initState'te
  MediaQuery yok); JS köprüsü çizimden önce çağrılamadığı için `setFlow`
  onStatus(ok) anında uygulanır — sayfa bir an %48'de görünüp akışa geçer.

**Doğrulama:** Flutter 3.29.3 — analyze 0 hata/0 uyarı (45 eski info),
**1314 test yeşil** (+12 DriveCache). Cihazda bakılacaklar: aynı Drive
dosyası ikinci açılışta pencere görmeden anında açılmalı; Drive'da güncellenen
dosya yeniden inmeli; Word telefonda net açılmalı, "Sayfa düzeni"ne geçiş
çalışmalı.

## 2026-08-06 (3. tur) — Tarama akışı iyileştirmeleri + taranmış PDF düzenleme/okuma
Kullanıcı (ekran görüntüleriyle, 5+2 madde): kırpma seçeneği, yarım sayfa,
eğik tarama, e-kitap okuma, kaybolan büyüteç; ayrıca "taranmış belge deyip
düzenleme yaptırmıyor, PDF'de yapılabilmeli; premium olmalı".

### A) Köşe ayarına BÜYÜTEÇ geri geldi (`scan_edit_screen`)
Tutamaç sürüklenirken RawMagnifier (1,8×) köşeyi izler (`_dragCorner` indeksi
— konum build'de köşeden hesaplanır, sürüklemede kaymaz). Kullanıcının
"eskiden vardı" dediği pencere ML Kit'in kendi arayüzündeydi; bizim köşe
ekranımıza hiç konmamıştı.

### B) Otomatik eğim düzeltme (`services/scan_deskew.dart`)
Önizleme (`ScanReviewScreen._prepareAll`) her sayfada önce `DocEdges` ile
kâğıt dörtgeni arar; `worthApplying` (saf, testli) onaylarsa `Perspective`
ile düz açar, sonra filtre. Kurallar: alan oranı %45–98 arası VE kimliğe
yakın değil (her köşe kendi görsel köşesinin %2,5'i içindeyse dokunma).
Yanlış kırpma kırpmamaktan kötü — emin değilse sayfa olduğu gibi kalır,
elle "Köşeleri ayarla" hep açık.

### C) Sonuç ekranına "Kenarları kırp" (`scan_result_screen._cropCurrent`)
Görünen sayfa köşe ekranında kırpılır → o sayfanın OCR'ı tazelenir → PDF
aynı yolda yeniden kurulur ("Sayfa ekle" ile aynı yol). Yeni anahtarlar:
`scr.crop_page`, `scr.cropped`.
**SINIR — yarım sayfa (madde 2):** çekim anındaki mavi dörtgen ML Kit
tarayıcısının KENDİ arayüzü (`cunning_document_scanner` → GMS); oraya kod
enjekte edilemiyor. Çözüm yolu kullanıcıya: Manuel çekim + sonradan kırpma.

### D) Okuma görünümü (`screens/reader_screen.dart`)
PDF menüsünde "Okuma görünümü": sayfa GÖRÜNTÜSÜ değil METNİ akar — yazılmış
sayfada pdfium, taranmışta `PdfOcrText` (aynı önbellek), `cleanPdfCopyText`
ile satır kırıkları birleşik. Punto ± , zemin üçlüsü (açık/sepya/koyu),
Tinos serif. Gemini KULLANILMADI: cihaz-içi OCR ücretsiz/çevrimdışı ve
yeterli; AI temizliği istenirse sonra eklenir.

### E) Taranmış PDF düzenleme (`services/pdf/pdf_scanned_retype.dart`)
- PDF düzenleyici Metin modunda paragrafsız sayfa "taranmış" sayılır
  (YAPIŞKAN küme `_scannedPages` — ilk düzenleme gerçek metin ekleyince
  sınıf değişmesin) ve OCR satır kutuları (`PdfScannedOverlay`, kesikli
  tertiary) dokunulabilir çizilir; kutular `PdfOcrText` fragmentlarından.
- Dokununca tanınan metin ön-dolu pencere; Uygula = satır BEYAZ kapakla
  örtülür + yeni metin AYNI yere gömülü Carlito ile yazılır (Türkçe glifler
  tam; punto = kutu yüksekliği × 0,74; yazım alanı sağa sayfa kenarına dek).
  Boş metin = satırı sil. Syncfusion `page.graphics` — annotation değil,
  düzleştirilmiş içerik.
- Düzenleme sonrası `PdfOcrText.invalidateMemory()` (yeni API) + `_docRev`
  artar → kutular tazelenir; paragraf kutusuyla >%50 örtüşen OCR satırı
  elenir (üstüne yazılmış satır artık paragraf yolundan düzenlenir).
- Görüntüleyicinin seçim çubuğunda OCR seçiminde "Düzenle" artık görünür →
  PDF düzenleyiciye götürür.
- SINIR (bilinçli v1): kapak düz beyaz — renkli zeminde yama görünür; zemin
  renk örnekleme açık iş.

**Doğrulama:** Flutter 3.29.3 — analyze 0 hata/0 uyarı (45 eski info),
**1320 test yeşil** (+6: deskew kararı 4, üstüne yazma 2 — Syncfusion üret/
yeniden aç/metin çıkar döngüsüyle). Cihazda bakılacaklar: eğik kitap sayfası
önizlemede kendiliğinden düzelmeli; köşe ayarında büyüteç; taranmış PDF'te
Metin modunda satır kutuları ve üstüne yazma; Okuma görünümünde taranmış
sayfanın metin olarak akması.

## 2026-08-06 (4. tur) — Okuma görünümüne SESLİ KİTAP
Kullanıcı: *"e-book sesli kitap gibi okuma olsun."* `ReaderScreen`e mevcut
`TtsService` bağlandı (görüntüleyicideki "Sesli oku" ile aynı motor — cihaz
içi, internetsiz): kulaklık düğmesi başlatır/duraklatır, sayfa bitince
KENDİLİĞİNDEN sonraki sayfaya geçer (boş sayfa atlanır), altta "Sayfa X ·
parça n/m" durumu. Duraklatma kaldığı parçadan sürer. TUZAK: kullanıcı
duraklatması ile "sayfa bitti" bildirimi ayrışsın diye niyet bayrağı
(`_speaking`) pause'dan ÖNCE kapatılır — yoksa pause bir sonraki sayfayı
tetikliyordu. Doğrulama: analyze 0 hata/uyarı, 1320 test yeşil.

## 2026-08-06 (5. tur) — Word: SAYFA görünümü varsayılana döndü + netlik düzeltmesi
Kullanıcı: *"mobil görünüme geçmeden, tam sayfada uzaktan bakarken de net
görünsün — asıl isteğim o."* Aynı gün alınan "telefonda akış varsayılan"
kararı GERİ ALINDI (akış görünümü duruyor, yalnız varsayılan sayfa).
- **Netlik düzeltmesi:** `DocxView` Android'de artık **hybrid composition**
  ile çiziliyor (`AndroidWebViewWidgetCreationParams(displayWithHybrid
  Composition: true)`, `webview_flutter_android` doğrudan bağımlılık oldu —
  sürüm zaten kilitliydi, çözünürlük değişmedi). Varsayılan Texture Layer
  yolu WebView çıktısını Flutter dokusuna alıp örnekleyerek basıyor; ~%50
  sığdırmadaki küçük harfler bu EK yeniden örneklemede yumuşuyordu
  (yakınlaşınca harf büyüyüp fark kaybolur — kullanıcının tarifi birebir).
  Hybrid composition ara dokuyu kaldırır, metin motorun çizdiği keskinlikte.
- Fizik notu: sığdırmada 11 punto ~7 dp'dir; hedef "o boyda OLABİLECEK en
  keskin çizim". Cihazda beklenen: sayfa görünümü pdfrx'in PDF sayfası kadar
  net. Yetmezse sıradaki aday: WebView içeriğini 2× yerleşimle çizip
  transform'la küçültme (supersampling) — raster ölçek seçimi Chromium'a
  takılabilir, denenmedi.
**Doğrulama:** analyze 0 hata/uyarı, 1320 test yeşil.

## 2026-08-06 (6. tur) — Taranmış belge turu: düzleştirme, Türkçe kodlama, sesli okuma
Kullanıcı (ekran görüntüleriyle): *"kendi taradığım kitapta da metinleri
tanımakta zorlanıyor düzenleyici"*, *"tarama yapılırken bombe kısımlar
düzenlenmiyor"*, *"editöre düzenle ve AI ile düzenle butonu koyalım"*,
*"sesli okuma çok kalitesiz, ses seçimi olmalı notlar uygulamadaki gibi,
ayrıca AI ile oku seçeneği de olsun, sayfa numaraları okunmamalı"*,
*"oluşturduğumuz taranmış belgelerin PDF'i son dosyalara düşmüyor"*,
*"düzenleme editörü de PDF de Türkçe karakter sorunu mevcut"*.

### A) Türkçe karakter (mojibake) — KÖK NEDEN bulundu
Paragraf düzenleyici `T.C. ANKARA ÜNÝVERSÝTESÝ REKTÖRLÜÐÜ` gösteriyordu.
Belge EKRANDA doğruydu; yanlış olan bizim okumamızdı: `/ToUnicode` taşımayan
fontta **Latin-1** varsayıyorduk (0xDD→`Ý`, 0xD0→`Ð`). İki katman eklendi:
1. **`/Encoding /Differences` ayrıştırması** (`pdf_glyph_names.dart` +
   `PdfFontEncoding.fromSimpleFont`): "221 /Idotaccent" gibi glif ADLARI
   okunuyor. Bu belgelerde harf eşlemesi YALNIZ orada duruyor. Çözüm
   simetrik — geri yazarken de fontun kendi kodları kullanılıyor.
2. **Yedek tablo Latin-1 DEĞİL CP1254** (`PdfFontEncoding.fallback`).
   İkisi yalnız altı konumda ayrışır (Ð Ý Þ ð ý þ ↔ Ğ İ Ş ğ ı ş); bu
   uygulamanın belgelerinde ilk küme neredeyse hiç geçmez. Yan fayda:
   0x80–0x9F artık dolu — tırnak/tire (`’ “ –`) görünmez denetim karakterine
   düşmüyor. `PdfSingleByteEncoding.candidates` sırası da CP1254 önce yapıldı
   (test `pdf_replace_matching` yalnız BİLDİRİLEN tablo adı için güncellendi;
   davranış aynı).
   **Gerçekten `Ð` demek isteyen üretici bunu `/Differences`ta adıyla söyler
   ve o yol bu tabloyu ezer** — kararın dayanağı bu.

### B) Bombe + eğim: kâğıda değil YAZIYA bakan düzleştirme (`scan_dewarp.dart`)
Var olan `ScanDeskew` kâğıdın KENARINI arıyor; kullanıcının kitap
fotoğraflarında kenar kadrajda yok → hiç devreye girmiyordu.
- **Eğim:** izdüşüm profili yöntemi — sayfa her aday açıyla eğilir, satır
  histogramının kareler toplamı ölçülür; en sivri açı eğimdir (±12°, 0,1°
  ince ayar). Hough'a göre ucuz ve harf kenarlarına kanmıyor.
- **Bombe:** sayfa 12 dikey şeride bölünür, komşu şeritlerin satır profilleri
  çapraz ilinti ile hizalanır → sütun başına dikey kaydırma alanı → yeniden
  örnekleme. Arama penceresi satır aralığının %45'iyle sınırlı (yoksa bir
  satır aşağıyı "mükemmel hizalanma" sanar).
- Kendi `rotateWhite`'ımız yazıldı: `img.copyRotate` boşluğu siyah bırakıyor,
  belge taramasında hem çirkin hem OCR'ı bozuyor.
- **TUZAK (test yakaladı):** düzeltme `+eğim` ile döndürülüyordu (eğimi İKİYE
  KATLIYOR) ama arkasından gelen kıvrım adımı kaymayı KESME ile örttüğü için
  uçtan uca test yeşil kalıyordu. Artık işaret sözleşmesi ayrı testte sabit:
  `rotateWhite(+eğim)` eğimi ikiye katlamalı.
- Emin değilse dokunmaz: mürekkep oranı %0,5–45 dışında, satır düzeni yoksa,
  eğim <0,25° ya da kıvrım <%0,6 ise sayfa OLDUĞU GİBİ kalır.

### C) Editörde "Düzelt" ve "AI ile düzelt"
Taranmış sayfada metin modunda iki düğme; ikisi de tüm satırları TEK geçişte
onarır (`PdfScannedRetype.applyMany` — 30 satır için belgeyi 30 kez açıp
kaydetmek yerine).
- **Düzelt** (`scan_text_fix.dart`, cihaz içi, ücretsiz): kelime başındaki
  `I`→`İ` **ünlü uyumuna bakarak** ("Iki"→"İki" ama "Işık" dokunulmaz; uyuma
  uymayan İstanbul/İzmir gibi adlar için küçük liste), iki harf ARASINDAKİ
  0/1/5/8 → harf, satır sonu tiresi birleştirme, noktalama boşlukları.
- **AI ile düzelt** (`scan_ai_fix.dart`, Gemini): satırlar NUMARALI gidip
  numaralı dönüyor; 1..N eksiksiz gelmezse düzeltme TÜMÜYLE reddediliyor —
  kutular sabit olduğu için eksik yanıt metni yanlış satıra taşırdı.
- **Yalnız DEĞİŞEN satır yeniden yazılır.** Hepsini basmak, hatasız satırların
  görüntüsünü de gömülü fontla değiştirir ve sayfa "tarama" olmaktan çıkardı.

### D) Sesli okuma: ses seçimi + AI ile oku + sayfa numarası
- `TtsPrefs` (ses adı/yerel, hız, perde) AppState'te kalıcı; `TtsVoiceSheet`
  cihazdaki sesleri listeler, dinletir. Kalitenin kaynağı motor değil SEÇİLEN
  SES; varsayılan çoğu zaman en robotik olanı.
- **TUZAK:** `flutter_tts`ta 1.0 her yerde "normal" değil — Android'de normal
  1.0, iOS'ta 0.5. Çarpan `TtsService.platformRate` ile çevriliyor.
- `cleanForSpeech`: tek başına duran sayfa numarası satırı okunmuyor
  (cümle içindeki sayıya dokunulmuyor), satır sonu tiresi birleşiyor.
  Roma rakamı tanıma İKİ KEZ daraltıldı: harf kümesine bakmak "civil"i,
  geçerli roma dizilişi aramak "mix"i (=1009) sayfa numarası sanıyordu →
  yalnız ön sayfa aralığı (i…lxxxix, C/D/M yok).
- **AI ile oku** (`read_aloud_ai.dart`): sayfa metni okunmadan önce Gemini'ye
  toparlatılır. Yanıt özgününün %60'ından kısaysa ATILIR (model özetlemiş
  demektir) ve özgün metin okunur; AI'ya ulaşılamazsa okuma DURMAZ.

### E) Taranan PDF "Son belgeler"e düşmüyordu
Kayıt yalnız `EntryOpener.open` içinde atılıyordu — tarama kendi sonuç
ekranına gittiği için üretilen PDF hiçbir listeye girmiyordu. Yeni
`EntryOpener.rememberFile` (açmadan kaydeder) tarama akışında PDF yazılır
yazılmaz çağrılıyor; sonuç ekranındaki yeniden adlandırma/taşıma da kaydı
`previousPath` ile güncelliyor.

**Doğrulama:** Flutter 3.29.3 (CI ile aynı) — `analyze` 0 hata/0 uyarı (45
eski info), **1363 test yeşil** (+43). Cihazda bakılacaklar: eğik/kavisli
kitap sayfası önizlemede düzleşmeli; resmî PDF'te paragraf metni `İ/Ğ/Ş` ile
görünmeli; taranmış sayfada "Düzelt"/"AI ile düzelt"; sesli okumada ses
seçimi ve sayfa numarasının atlanması; taranan PDF ana ekranda "Son
belgeler"de.

## 2026-08-06 (akşam) — Drive menüsü, pano düzeni, YEREL APK derleme reçetesi

### A) Drive "Sil" KALICI siliyordu → çöp kutusu
`files.delete` dosyayı geri dönüşsüz siliyordu; Drive uygulamasının "Sil"i ise
`trashed: true` yapar (30 gün geri alınabilir). Menü artık çöp kutusuna taşıyor,
onay metni de bunu söylüyor. `rename`/`setStarred`/`trash` tek `_patchMetadata`
üzerinden gidiyor. Eklenenler: **Telefona indir…** (klasör seçici; Drive'ın
Kopyala/Yapıştır'ı yalnız Drive İÇİNDE çalışır — sunucuda kopya çıkarır, dosya
telefona inmez), **Bilgi**, **Yıldız** (`starred` alanı `fields`e eklendi).

### B) Taranan PDF panoda anında görünmüyordu
`DocumentScanner.savePdf` dosyayı yazıp `FsEvents.changed()` DEMİYORDU; pano
taraması süreç boyunca önbellekli olduğu için yeni PDF ancak aşağı çekince
görünüyordu. Sinyal, her tarama kaydının geçtiği tek ortak noktaya (savePdf)
kondu. (2026-07-25'teki "Son belgeler" kaydı ayrı bir eksikti — bkz. E maddesi.)

### C) YEREL APK derleme reçetesi (CI kırmızıyken lazım oldu)
`android/` **gitignore'da** ve CI onu her koşuda `flutter create` ile yeniden
üretip yamalıyor. Yerelde derlemek için AYNI yamalar elle uygulanmalı, yoksa:
1. **Desugaring yoksa** → `flutter_local_notifications requires core library
   desugaring` ile derleme kırılır (`isCoreLibraryDesugaringEnabled = true` +
   `desugar_jdk_libs:2.1.4`, minSdk 24).
2. **`dart run flutter_launcher_icons` unutulursa** → APK ESKİ ikonla çıkar
   (yerel mipmap'ler 23.07'den kalmaydı; kullanıcı fark etti, kurmadı).
3. **`--split-per-abi` olmadan** → versionCode 1 üretilir, telefondaki 2001'in
   altında kalır → `INSTALL_FAILED_VERSION_DOWNGRADE`. Flutter arm64'e +2000
   ekliyor; CI'nın şeması bu, aynısı kullanılmalı (`--build-number` ile
   büyütmek CI güncellemelerini kırardı).
4. **R8 (Flutter 3.44 yerelde) WorkManager'ı kırıyor:** açılışta
   `Failed to create an instance of class androidx.work.impl.WorkDatabase` ile
   ÇÖKÜYOR (Room sınıfı yansımayla bulunamıyor). Yerel derlemede
   `isMinifyEnabled = false`. CI (Flutter 3.29.3) etkilenmiyor — CI APK'ları
   sağlam.
5. İmza: Gradle debug anahtarıyla imzalar; APK sonradan `apksigner` ile
   `Yazılımlar\dosya-okuyucu-imza\release.jks` (parola aynı klasörde) ile
   imzalanır → SHA-256 `9eef6704…`, CI ile AYNI, üstüne kurulur.
6. `ci/AndroidManifest.xml`, `ci/MainActivity.kt`, `ci/proguard-rules.pro`
   elle kopyalanır.

### D) Pano düzeni (kullanıcı ekran görüntüsüyle)
Liste alt boşluğu 32 → **136**: yüzen düğmeler son satırdaki "Google Drive"
kartının yazısını örtüyordu. Çöp kutusu ızgara kartından çıkıp klasör eklemenin
YANINA küçük yüzen düğme oldu (yolculuğu: araçlar → büyük kart → FAB).
"Ana bellek" renk açıklaması tek satıra indi: payı %1 üstü en büyük dört
kategori, "Boş" yazılmıyor.

**Doğrulama:** analyze temiz, 1363 test yeşil, APK imzalanıp telefona kuruldu
(çökme yok). Görsel doğrulama telefon kilitli olduğu için yapılamadı.

### E) "Düzelt" adı yanılttı → adlandırma + elle düzleştirme (2026-08-06 gece)
Kullanıcı **eğik taranmış sayfayı** düzeltmek için PDF düzenleyicideki
"Düzelt" / "AI ile düzelt" ikilisini aradı. O ikili **METNİ** onarıyor (OCR'ın
Türkçe hataları), geometriyi değil; geometri düzeltme tarama önizlemesinde ve
**otomatik**. Ders: bir düğmenin adı ne yaptığını söylemiyorsa kullanıcı onu
başka bir şey sanıp arar — ve bulamayınca "özellik yok" der.
- `pe.fix_page` → **"Metni düzelt"**, `pe.fix_page_ai` → **"Metni AI ile düzelt"**.
  (Yukarıdaki 2026-08-06 sabah notundaki "Düzelt/AI ile düzelt" adları ARTIK
  BÖYLE DEĞİL.)
- Tarama önizlemesine **"Düzleştir"** (`sr.straighten`) düğmesi eklendi:
  otomatik geçiş temkinli olduğu için (emin değilse dokunmuyor) eğik kalan
  sayfada kullanıcının elinde hiçbir şey yoktu. `_flatten` artık bool döndürüyor
  — otomatik geçişte sessizlik doğru, düğmeye basana geri bildirim şart.
- Düğmelerin nerede göründüğü: "Metni düzelt" ikilisi YALNIZ PDF düzenleyici →
  Metin modunda, sayfada gerçek metin katmanı YOKKEN (`paragraphs.isEmpty` →
  "taranmış aday") ve OCR satır bulmuşken çıkar. Aranabilir (OCR katmanlı) PDF
  üretilmişse sayfa metinli sayılır ve çubuk çıkmaz — açık kalan konu.

### F) Aranabilir taranmış PDF "metinli" sayılıyordu (2026-08-07)
"Metni düzelt / Metni AI ile düzelt" çubuğu, tarama **aranabilir** yapıldığında
HİÇ çıkmıyordu: sayfaya gömülen görünmez OCR metni (`3 Tr`) yüzünden
`paragraphs.isEmpty` yanlış çıkıyor, sayfa taranmış sayılmıyordu — kendi
özelliğimiz kendi özelliğimizi kapatıyordu. Artık `PdfPageOutline.scanned`
bayrağı var: **görünmez metin (`3 Tr`/`7 Tr`) VE sayfada görüntü**. İkisi
birlikte aranıyor, yoksa filigranlı sıradan belge de taranmış sayılırdı.
`hasInvisibleText` var olan `scanContent` tarayıcısını kullanıyor — dize
İÇİNDEKİ "3 Tr" operatör sanılmıyor (`test/pdf_invisible_text_test.dart`).

**Tuzak (test):** `fm_file_tags` eşzamanlılık testi, tam paket APK derlemesiyle
AYNI ANDA koşarken düşüyor (yükte zamanlama). Tek başına yeşil — kırmızı
görünce önce tek dosyayı koştur, koda dalmadan.

## 2026-08-07 — Excel turu: eski .xls, şerit, zoom, beyaz zemin, ortak simge dili

Kullanıcının sekiz maddelik listesi (xls uyumu · düzenleyicide daha çok müsade
ve isabet · xls'te zoom yok · PDF çok sütunda oto genişleme · Excel/txt'de
kağıt değil beyaz · yazı boyutu+font · üç uygulamanın simge dili · Excel gibi
şerit).

### A) Eski `.xls` artık SALT-OKUNUR DEĞİL — çevrilip gerçek ızgarada açılıyor
Kök neden: `.xls` dosyaları `viewer_screen`deki basit bir listede
gösteriliyordu (`_SpreadsheetView`). Zoom yok, şerit yok, formül yok, düzenleme
yok — kullanıcının "xls uyumu" ve "xls'te zoom yok" maddelerinin ikisi de
buydu; Excel ekranındaki zoom (pinch) hep vardı ama o dosyalar oraya HİÇ
gitmiyordu.
- **Karar: BIFF oku → .xlsx YAZ → normal Excel ekranını aç.** `.xls` (BIFF)
  ÜRETMİYORUZ: yazma tarafı okuma tarafından çok daha büyük bir iş ve kullanıcı
  düzenlediğini modern biçimde saklamalı. Kaydetme özgün dosyanın YANINA aynı
  adlı `.xlsx` bırakır (`LoadedDoc.savePath`), `.xls` dosyasına DOKUNULMAZ.
  Açılan yol geçici bir çalışma kopyasıdır (`LoadedDoc.path`).
- Yeni `services/xlsx_writer.dart`: sıfırdan geçerli bir OOXML paketi üretir
  (content types, rels, workbook, styles, sharedStrings, sheetN). *Niye elle,
  niye `excel` paketiyle değil:* paketin yazma yolu sütun genişliği, donmuş
  bölme, birleşik hücre ve sayı biçimini ya hiç yazmıyor ya kendi kafasına göre
  yazıyor (aynı eksikler için zaten `xlsx_save_patch` var). Çevrimde kayıp
  olmaması için XML'i baştan sona biz belirliyoruz.
- `xls_legacy.dart` genişletildi: FORMAT (sayı biçimi → tarihler artık tarih
  görünüyor), FONT (punto/kalın/italik/renk; **BIFF8'de 4 numaralı font indeksi
  YOKTUR**, ifnt≥4 bir kayar), XF (hizalama/kaydırma/girinti/dolgu), PALETTE,
  ROW (yükseklik+gizli), COLINFO (genişlik+gizli), MERGEDCELLS, WINDOW2+PANE
  (donmuş bölme, sağdan sola, ızgara çizgisi), BLANK/MULBLANK (biçimli boş
  hücre), BOOLERR, BOUNDSHEET gizli bayrağı.
- **KÖK NEDEN düzeltmesi — SST CONTINUE:** BIFF8'de bir metin kayıt sınırında
  bölünür ve devam kaydı **1 baytlık yeni bir kodlama bayrağıyla** başlar. Eski
  sürüm blokları düz birleştiriyordu → ilk sınırdan sonraki bütün metinler
  kayıyordu (dosya büyüdükçe tablo anlamsızlaşıyor). Artık okuma blok sınırını
  biliyor (`_SstCursor`): karakter verisi sınırı geçerken bayrak tüketilip
  kodlama güncelleniyor; zengin metin/fonetik atlamalarında bayrak YOKTUR.
- Test yolu: `XlsLegacy.parseWorkbookStream` (@visibleForTesting) — testler
  BIFF kayıtlarını elle üretiyor, OLE2 kabı üretmeye gerek yok.

### B) Excel şeridi: sekmeli ve simgeli (`widgets/office_ribbon.dart`)
"Sade tutulur, altı düğme + Daha fazla" kararı (2026-07-28) BURADA GEÇERSİZ:
sadeliğin bedeli, kullanıcının Excel'de refleksle aradığı her şeyin (yazı tipi,
punto, kenarlık, süzgeç, sıralama, zoom) menü içinde kaybolmasıydı — "şeritte
Excel gibi simgeler bile yok". Yeni şerit Excel'in kendi sekmeleriyle: **Giriş
/ Ekle / Veri / Görünüm**. Etiketli "Daha fazla" sayfası DURUYOR (seyrek işler).
- ⋮ menüsü kalktı: sayfaya git / bölme / yön artık Veri ve Görünüm sekmesinde.
  (Testler de oraya taşındı — `spreadsheet_screen_test`, `spreadsheet_rtl_test`.)
- **Simge dili tek yerden:** `OfficeIcons`. Word, Excel ve Slayt aynı işi aynı
  simgeyle gösteriyor; üç editör de aynı `OfficeRibbon` bileşenini kullanıyor
  (`onBrand: true` = Word'ün renkli üst çubuğu).
- **Tuzak:** `RibbonChip` kendi `InkWell`ini kurarsa `PopupMenuButton` çocuğu
  olduğunda dokunuşu YUTAR (Word'ün yazı tipi/punto menüleri açılmaz).
  `onTap` null ise hiç jest kurulmuyor; regresyon testi `office_ribbon_test`.

### C) Görünür zoom (`PinchZoomController`)
Pinch keşfedilmesi gereken bir jest. Şeritteki −/%/+ takımı **aynı** ölçeği
sürüyor (ikinci bir zoom durumu ızgara ölçüleriyle çelişirdi); düğmeyle zoomda
odak görünür alanın ortası, kaydırma düzeltmesi pinch'le aynı matematik.
Yüzde göstergesi `_fixScroll` içindeki `setState` ile tazeleniyor — rozet
yalnız pinch'te görünüyor, düğmeyle zoomun tek geri bildirimi şerit.

### D) Kağıt teması belgenin İÇİNE girmiyor (`Paper.docSurface`)
Kullanıcı: *"kağıt teması arka planları excelde kağıt yapmış olmaz, beyaz
olmalı, txt de öyle"*. Kağıt dokusu uygulamanın KABUĞUNA ait (listeler,
kartlar, ayarlar); belgenin içi kullanıcının verisidir ve Excel/Not
Defteri'nde beyazdır. Excel ızgarası, düz metin sayfası ve Word'ün yedek
sayfası artık `Paper.docSurface` (açık temada beyaz, koyu temada kanvastan bir
tık koyu nötr yüzey — koyuda beyaz gözü yakar).

### E) Yazı boyutu ve yazı tipi
- Excel: şeritte yazı tipi çipi + punto çipi + A▲/A▼. Kaydetmeye giriyor —
  `XlsxStyleEdit.fontSize/fontName` → `<sz>`/`<name>`. **`scheme` SİLİNİR:**
  kalırsa Excel tema fontunu kullanır ve seçilen ad görünmez.
- Metin görüntüleyici: punto zaten vardı, **yazı tipi ailesi** eklendi
  (gömülü/kesin var olan aileler: Arimo, Tinos, tek aralıklı).
- Slayt: iki düğmeyle 12'den 44'e çıkmak 16 dokunuştu → punto listesi.
- Word'de ikisi de vardı; yalnız ortak bileşene taşındı.

### F) PDF: çok sütunda oto sığdırma + düzenleyicide isabet/müsade
- **Sütun düzeni:** pdfrx sütun sayısı değişince yakınlaştırmayı OLDUĞU GİBİ
  bırakıyor; 4 sütun bir anda dört kat genişliyor ama ekranda hâlâ tek
  sütunluk kadarı görünüyor ("hiçbir şey değişmedi" / "sayfalar kayboldu").
  `_fitPdfWidth` düzen ölçüldükten sonra genişliğe sığdırıyor (dikey konum
  korunur).
- **İsabet:** `Stack` hit-test'i SONDAKİ çocuktan başlar; kutular dosya
  sırasındaydı, paragrafın içindeki küçük satır kutusu büyüğün altında kalıp
  dokunuşu kaptırıyordu. Artık alan büyüklüğüne göre azalan sıra (küçük üstte)
  + ince kutulara en az 30dp dokunma hedefi (görünen kutu yerinde kalır).
- **Müsade:** OCR satır kutuları artık yalnız "taranmış" sınıfı için değil,
  **sayfada görsel varsa** da yükleniyor — üstte gerçek başlık altta fotokopi
  tablo taşıyan karma sayfalarda kullanıcı "metin var ama düzenletmiyor"
  diyordu. Paragrafla örtüşen satırlar zaten eleniyor, çift kutu olmuyor.

**Doğrulama:** Flutter 3.29.3 (CI ile aynı) — `analyze` 0 hata/0 uyarı (44 eski
info), **1392 test yeşil** (+27; yeni: `xlsx_writer_test`,
`xls_legacy_rich_test`, `spreadsheet_ribbon_test`, `office_ribbon_test`,
`pdf_edit_overlay_test` + file_service/save_patch eklemeleri).
Cihazda bakılacaklar: `.xls` dosyası Excel ızgarasında açılmalı (şerit, zoom,
düzenleme) ve "Kaydet" yanına `.xlsx` bırakmalı; şeritte dört sekme; Görünüm
sekmesinde %; Excel/txt zemini beyaz; PDF'te 2/4 sütun seçilince tam genişlik.

## 2026-08-07 — CI kırmızıydı: iki AYRI arıza var, karıştırma

Kullanıcı "CI kırmızı sorunu bu repoda da var" dedi (kardeş repo `ezan-vakti`
üzerinden). İncelendi: **aynı arıza DEĞİL.** İki imza birbirinden 10 saniyede
ayrılıyor, ayırmadan hata aramak boşa zaman.

**İmza A — iş akışı dosyası geçersiz (bu repoda YOK).**
`ezan-vakti`'de bir adımın `if:`'inde `secrets` bağlamı kullanılmıştı. `secrets`
adım düzeyindeki `if:` içinde KULLANILAMAZ (orada izin verilenler: github, needs,
strategy, matrix, job, runner, env, vars, steps, inputs). Tanımsız bağlam ifadeyi
`false` yapmaz, TÜM dosyayı ayrıştırma anında düşürür. Belirti: koşu **0 job** ile
anında kırmızı, **hiç log yok** — orada 10 koşu boyunca herkes Gradle'da hata aradı.
Buradaki `build-apk.yml` denetlendi: `secrets` yalnızca `env:` ve `with:` içinde
geçiyor (`KS_B64`, `KS_PASS`, `GITHUB_TOKEN`), adım `if:`'lerinde yok.
**Bu arıza burada yok, tekrar arama.**

**İmza B — platform işi iptal ediyor (2026-08-06'da BU repoyu vuran arıza).**
`Android APK` işi **tam ~15 dakika** sonra `conclusion: cancelled` ile bitti; işin
kendi `timeout-minutes: 30` sınırına daha çok vardı, yani bizim zaman aşımımız
değil. Etkilenen koşular: 31118376313, 31118555699, 31118582733
(2026-08-06 16:02 → 17:16 UTC; sonuncusu 3. denemeydi, o da iptal edildi).

**Kendiliğinden düzeldi:** 23:01'deki koşu (31129558085) hiçbir değişiklik
yapılmadan 10 dakikada yeşil. Aynı gün aynı saatlerde kardeş repo `not` da
tamamen farklı bir iş akışıyla birebir aynı imzayı verdi (~15:02'de `cancelled`,
iş logu 404). İki ayrı repo + iki ayrı iş akışı + aynı sabit 15 dk = runner tarafı.

**Ne yapılmalı:** koda dokunmadan koşuyu yeniden çalıştır. Yeşile dönerse konu
kapanır; art arda üç denemede de aynı 15 dk'da iptal oluyorsa (2026-08-06'da öyle
oldu) beklemek dışında yapılacak bir şey yok — düzeltme denemesi için commit
atmak sadece CI dakikası yakar.

**Tuzak:** `conclusion: cancelled` olan işler `failed_only=true` ile listelenmez —
"başarısız iş yok" cevabı gelir ve arıza görünmez olur. Koşu kırmızı ama
`failed_jobs: 0` ise işlerin `conclusion`'ına tek tek bak (`list_workflow_jobs`);
`cancelled` ise İmza B, `total_jobs: 0` ise İmza A.

## 2026-08-07 — Drive listesinde eksik üstveri: tarih, tür ikonu, sayfalama
Kullanıcı ekran görüntüsü: Drive listesinde satır altında **yalnız boyut**
vardı ("24 MB"), her dosyanın ikonu aynı gri kağıttı ve `ezanvakti-ozel-1.0.130`
ile `1.0.135`ten hangisinin yeni olduğu okunamıyordu.

### A) Son değiştirilme tarihi (asıl istek)
- Alt yazı artık yerel gezginle AYNI düzende: `boyut · 6 Ağu 2026 23:41`
  (`FsPaths.humanDate`). Klasörde boyut yazılmaz (Drive klasörün baytını
  vermez), yalnız tarih. Google biçimlerinde araya "DOCX olarak iner" giriyor.
- Bilgi penceresindeki tarih `DateTime.toString()` ile ham damga
  ("2026-08-06 23:41:18.573Z") olarak yazılıyordu → `humanDate`.

### B) Ekranın diğer eksikleri (aynı turda tespit + eklendi)
- **Tür ikonu YOKTU:** hepsi `insert_drive_file_outlined`. Artık
  `FmColors.iconFor/forCategory` — APK yeşil android, PDF/Office belge,
  görüntü mor: yerel gezginle tek palet. `DriveFile.category` uzantıdan
  türetiliyor; Google biçimlerinde adın uzantısı olmadığı için **dışa aktarım
  uzantısına** düşüyor, yoksa hepsi "Diğer" olurdu.
- **Bilgi penceresi yoksuldu:** tür olarak ham MIME
  (`application/vnd.openxml…`) yazıyordu. Artık "PDF · Belgeler" + oluşturulma
  tarihi + sahip + paylaşım durumu + yıldız. Yeni Drive alanları:
  `createdTime,owners(displayName,emailAddress),shared` (istenmezse Drive
  göndermez → satırlar sessizce "—" kalırdı). `_fields2` (tek dosya dönen uç
  noktalar) liste alanlarıyla aynı kümede tutuldu: yeniden adlandırma sonrası
  dönen kayıt satırın yerine geçiyor, eksik alan gelse tarih/sahip silinirdi.
- **SIRALAMA yoktu:** çubuğa sıralama menüsü (ad / tarih / boyut). Sıralamayı
  **Drive yapıyor** (`orderBy`), yerelde değil — liste sunucuda sayfalanıyor,
  yerel sıralama yalnız eldeki sayfayı sıralardı. Tuzak: boyutun Drive
  anahtarı `size` DEĞİL `quotaBytesUsed`; `size` yazmak 400 döndürür. Her
  seçenek `folder,` ile başlıyor ki klasörler üstte kalsın.
- **BUG — sayfalama hiç yapılmıyordu:** `files.list` yanıtındaki
  `nextPageToken` okunmuyordu, yani 200'den kalabalık bir klasörün kuyruğu
  SESSİZCE kayboluyordu (kullanıcı "dosyam Drive'da yok" derdi). `list()`
  artık sayfaları izliyor, `maxPages` (10 × 200) üst sınırıyla — 20 binlik bir
  Drive'ı tek listede çekmek telefonu kilitlerdi.

### C) TUZAK — testte `http.Response` gövdesi LATIN-1 sayılır
Başlıksız `http.Response('{"…Ayşe…"}', 200)` kurulamıyor ("ş" latin-1'de yok)
→ MockClient patlıyor, ekran boş liste gösteriyor ve hata "widget bulunamadı"
gibi görünüyor. Türkçe içeren sahte yanıtlara
`headers: {'content-type': 'application/json; charset=utf-8'}` gerekiyor.
(`Bütçe` geçen eski test bu yüzden çalışıyordu: ü/ç latin-1'de var.)

**Doğrulama:** Linux bulut oturumunda Flutter 3.29.3 (CI ile aynı) —
`analyze` 0 hata/0 uyarı (44 eski info), **1401 test yeşil** (+9: Drive
sayfalama, sıralama `orderBy`, oluşturulma/sahip/paylaşım ayrıştırma,
kategori eşlemesi, listede tarih, bilgi penceresi).
Cihazda bakılacaklar: Drive satırlarında "boyut · tarih", türe göre renkli
ikon, çubukta sıralama menüsü, bilgi penceresinde sahip/paylaşım.

## 2026-08-07 (2) — "Sayfaya git" yarışları, Drive simgeleri, yazı tipi listesi, Ayarlar
Kullanıcı bulguları: *"sayfaya git bazen çalışmıyor; ilk girdiğimde çalışıyor,
biraz gezip işlem yapınca çalışmıyor"*, *"yazı tipi fontu boyutu seçimi yok"*,
*"Drive'da PDF PDF simgesinde, Excel kendi simgesinde olmalı; şu an hepsi aynı
belge işareti"*, *"ayarlar kısmı eskidi, görsel ve mantıksal olarak
düzenlenmeli"*.

### A) "Sayfaya git" — ÜÇ ayrı neden, üçü de sessizdi
1. **Klavye yarışı.** Pencere kapanınca yumuşak klavye de kapanıyor, Scaffold
   görünümü yeniden boyutlandırıyor; pdfrx `isViewSizeChanged` görünce
   `_goToPage(o anki sayfa)` atıyor ve tam bizim atlayışımızı geri çekiyor.
   Çözüm: `_waitViewerSettled` — ölçüt "klavye kapandı" DEĞİL, "viewInsets iki
   ölçümde aynı"; odak arama kutusuna dönerse klavye açık kalıyor ve kapanmasını
   beklemek boşuna 1 sn eklerdi.
2. **Kopmuş denetleyici.** Dosyada işlem yapılınca (`_reloadPdf` — vurgu, imza,
   düzenleme, PDF araçları) pdfrx `_onDocumentChanged` içinde `_controller
   ._attach(null)` yapıp belge null'ken ERKEN DÖNÜYOR. O aralıkta
   `controller.goToPage` `__state!` üstünden FIRLATIYOR; hata yakalanmadığı için
   ekranda hiçbir şey olmuyordu = "düğme ölü". Artık try/catch + hazır olana
   kadar bekleme, olmazsa "belge hâlâ yükleniyor".
3. **Yanlış ölçü.** Varış pdfrx'in TAHMİNİ sayfa numarasıyla ölçülüyordu; o
   numara "görünen alanla en çok kesişen sayfa"dır — yakınlaştırılmış ya da çok
   sütunlu görünümde doğru sayfadayken bile komşusunu söyleyebiliyor, biz de
   3 kez tekrar deneyip "gidilemedi" diyorduk. Artık geometri:
   `arrivedAtPage` (saf, testli) — merkez sayfanın üstünde VEYA kesişim ≥ %20.
   İki ölçüt de gerekli: merkez yakınlaştırmayı, oran uzaklaşmayı karşılıyor.
   Tuzak: `Rect.intersect` kesişme yokken NEGATİF kenar döndürür; eksi × eksi
   = artı olduğu için naif alan hesabı "varıldı" derdi.

### B) Drive: her belge kendi simgesiyle
Kategori ikonu (`FmColors`) bütün belgeleri tek tip gösteriyordu. Belgelerde
artık `FileTypeIcon` (PDF kırmızı, Excel yeşil, Word mavi) — yerel gezginle
aynı kural. Ayrıca `FileService.iconKindForExtension` eklendi: **yalnız simge
için** tür; `kindForExtension` eski biçimleri bilerek "bilinmeyen" sayıyor
(editörlerimiz .doc/.ppt açamaz) ama listede .xls'in Excel yeşili olması
gerekiyor. Yerel gezgin de bunu kullanıyor.

### C) Yazı tipi: tek liste, tanıdık adlar, slaytta ARTIK VAR
- `lib/core/doc_fonts.dart` — tek kaynak. Her seçenek çift yüzlü: `name`
  **dosyaya yazılan** ad (Word/Excel/PowerPoint'te gerçek Arial görünsün),
  `render` **ekranda çizilen** gömülü aile (Carlito/Arimo/Tinos/monospace).
  Android'de Arial/Georgia/Verdana KURULU DEĞİL — o adla çizmek sessizce
  Roboto'ya düşerdi ("seçtim ama değişmedi").
- **Slaytta yazı tipi ailesi HİÇ YOKTU** (yalnız punto vardı) → eklendi.
  `PptxEditor.formatParagraph(fontFamily:)` `a:latin` + **`a:cs`** + `a:ea`
  yazıyor: yalnız `a:latin` Arapça metinde hiçbir şeyi değiştirmezdi.
  Çubuktaki ad XML'den okunuyor (`fontOfParagraph`) — çizim modelindeki ad
  gömülü aileye eşlenmiş olur (Arial → Arimo) ve geri dönülemez.
- Word/Excel/metin görüntüleyici aynı listeye geçti; `viewer.html`e eksik
  adlar için @font-face takma adları eklendi (Georgia/Garamond/Book Antiqua →
  Tinos, Verdana/Tahoma/Segoe UI → Arimo).

### D) Ayarlar: kart + simge + açıklama, mantıklı sıra
Bölümler sayfa zemininde gevşek bileşen yığınlarıydı. Artık `SettingsGroup`:
simge + başlık + tek satır açıklama taşıyan kart. Sıra: Hesap → **Görünüm ve
dil (tema + dil TEK grupta)** → Yapay zekâ → Hafıza → Dosya yöneticisi →
Hakkında. Dil ayrı bölümken kullanıcı onu temanın altında arıyordu. Dosya
yöneticisi ayarları yalnız gezgin panosundan açılabiliyordu → köprü eklendi.

### E) TUZAK (test) — `http.Response` gövdesi başlıksızken LATIN-1
Türkçe içeren sahte yanıt ("Ayşe") kurulamıyor, MockClient patlıyor ve ekran
boş liste gösteriyor; hata "widget bulunamadı" gibi görünüyor.
`headers: {'content-type': 'application/json; charset=utf-8'}` şart.

**Doğrulama:** Linux bulut oturumunda Flutter 3.29.3 (CI ile aynı) —
`analyze` 0 hata, **1414 test yeşil** (+13: `pdf_page_arrival_test`,
`settings_screen_test`, pptx yazı tipi, Drive simge/tarih/sıralama/sayfalama).
Cihazda bakılacaklar: PDF'te sayfaya git (klavye kapanır kapanmaz, işlem
sonrası da), Drive'da PDF/Excel/Word simgeleri, slaytta yazı tipi çipi,
Ayarlar'ın yeni düzeni.

## 2026-08-07 (3) — Yazı tipi/boyutu HER TELEFONDA sabit, varsayılan Carlito
Kullanıcı: *"en uygun fontu varsayılan yap; yazı boyutu ve fontumuz tüm
telefonlarda sabit olmalı, sadece uygulama içerisinden değiştirilebilmeli."*

- **Varsayılan gövde yazı tipi Arimo → Carlito.** Arimo = Arial/Helvetica
  metriği (baskı çağı groteski, küçük puntoda harfler yaklaşıyor); Carlito =
  Calibri metriği, doğrudan EKRAN için tasarlanmış hümanist sans, açık harf
  boşluğu, tam Türkçe. Belge tarafıyla da tutarlı (Word/Excel varsayılanı
  Calibri, `viewer.html` zaten Calibri→Carlito eşliyordu). Başlıklar Tinos
  (serif) kalıyor — kağıt temasının karşıtlığı oradan geliyor.
- **Sistem yazı boyutu YOK SAYILIYOR.** `MaterialApp.builder` içinde
  `MediaQuery.copyWith(textScaler: linear(appState.uiTextScale))` — sistemden
  gelen ölçeğin yerine geçer (`withNoTextScaling` sarmaya gerek yok). Aynı
  ekran artık her telefonda birebir aynı. Ödün bilinçli: sistemden büyük yazı
  seçmiş kullanıcı bunu bizde görmez → uygulama içi ölçek **%85–%140**
  (`setUiTextScale` kısar) ve Ayarlar > Görünüm'ün en üstünde.
- **WebView ayrı bir kaçaktı:** Android WebView'ın metin yakınlaştırması
  sistem yazı boyutunu izler; Flutter'daki kilit ona işlemez. `.docx`
  görünümünde aynı belge farklı telefonlarda başka sarıyor, sayfa sayısı bile
  tutmuyordu → `AndroidWebViewController.setTextZoom(100)`.
- Yazı tipi seçenekleri yalnız GÖMÜLÜ aileler (Carlito/Arimo/Tinos/tek
  aralıklı): cihazda kurulu olmaya bağlı bir aile "her telefonda aynı" olmazdı.

**Doğrulama:** Flutter 3.29.3 (CI ile aynı) — `analyze` 0 hata, **1419 test
yeşil** (+5: `ui_font_scale_test` — sistem ölçeği etkisiz, uygulama ölçeği
etkili, varsayılan Carlito, seçim temaya işliyor, sınırlar).

### 2026-08-07 (3b) — DÜZELTME: yazı tipi ayarı yalnız gövdeyi değiştiriyordu
Kullanıcı ekran görüntüsü (gezgin, "Ana bellek"): *"buradaki yazı tipleri vs
değişmiyor hep aynı kalıyor."* Haklı ve nedeni yapısal:

- Gezgin satırında dosya adı **başlık** stiliyle (`ListTile.titleTextStyle` →
  `titleMedium` → serif Tinos), tarih satırı ise `MonoText` ile (koda gömülü
  `'monospace'`) çiziliyor. Yani o ekranda **gövde metni HİÇ YOK**; yalnız
  `ThemeData.fontFamily`yi değiştiren ayar orada hiçbir şeyi değiştirmiyordu.
- Çözüm iki parçalı:
  1. Bir aile seçilirse **başlık ve veri satırları da** onunla kuruluyor
     (`_base` içinde `heading`/`mono` seçilen aileye eşitleniyor).
  2. Koda gömülü aile adları yerine tema uzantısı: `AppFonts` (body/heading/
     mono). `MonoText` ve PDF sayfa rozeti artık `AppFonts.of(context)` okuyor.
     Yeni yerlerde `AppTheme.fontMono` yazmak yerine bu kullanılmalı.
- Ayar listesine **"Varsayılan"** işaret değeri eklendi
  (`AppTheme.uiFontDefault`): tasarımın kendi karışımı (serif başlık + Carlito
  gövde + tek aralıklı veri). Diğer seçenekler tek aileyi her yere uygular.
- **Bilerek DIŞARIDA bırakıldı:** elektronik tablo sayı hücreleri
  (`sheet_cell`) ve Drive kurulum kartındaki SHA-1/paket adı. İkisi de belge/
  teknik veri sadakati: rakam hizası ve kopyalanabilir değerler arayüz
  tercihine göre değişmemeli.

**Doğrulama:** `analyze` 0 hata, **1420 test yeşil** (+1: varsayılan karışım ve
seçimin başlık/veri satırlarına işlemesi).

## 2026-08-07 (4) — Varsayılan Carlito, 10 arayüz yazı tipi, hazır boyut kademeleri
Kullanıcı: *"varsayılan carlito olsun, daha fazla yazı tipi lazım, ayrıca
boyut ek olarak küçük orta büyük çok büyük şeklinde kolay seçimde olsun."*

- **Varsayılan artık düz Carlito** (`uiFontDefault = fontBody`). Önceki
  "tasarımın karışımı" (serif başlık + sans gövde + tek aralıklı veri) işaret
  değeri KALDIRILDI; seçilen aile başlık dahil her yere uygulanıyor. Kağıt
  temasının serif/sans karşıtlığı bilinçli olarak feda edildi — kullanıcı tek
  ve tutarlı yazı tipi istedi.
- **Yedi yeni gömülü aile:** Inter, Lato, Nunito (sans), Merriweather,
  EB Garamond, Roboto Slab (serif), JetBrains Mono (tek aralıklı). Listeden
  cihazın kendi `monospace`i ÇIKARILDI: telefondan telefona değiştiği için
  "her telefonda aynı" kuralını bozuyordu.
  - **Boyut:** ham set 8,2 MB → **2,2 MB**. İki adım: (1) değişken fontlarda
    `wght` dışındaki eksenler (opsz/wdth) varsayılana sabitlendi —
    Merriweather tek başına 4,5 MB'dı, (2) Latin + Latin Ext-A/B (Türkçe
    ğ/İ/ı/ş) + noktalama + para birimlerine altkümeleme. İtalik kesitler
    alınmadı (arayüzde kullanılmıyor, boyutu ikiye katlardı).
  - Üretici betik **`tool/fetch_ui_fonts.py`** (fonttools) — depodaki ikili
    dosyalar tek komutla yeniden üretilebilsin diye. Lisans notu
    `assets/fonts/FONTS-NOTICE.txt`e eklendi (altısı OFL, Roboto Slab
    Apache-2.0).
- **Yazı tipi seçimi artık alt sayfa:** on aile tek bir SegmentedButton'a
  sığmıyordu; her satır kendi yazı tipiyle + Türkçe örnek satırla yazılıyor
  ("Nunito" adı tek başına neye benzediğini söylemiyor).
- **Boyut kademeleri:** Küçük %90 / Orta %100 / Büyük %115 / Çok büyük %130
  (`AppTheme.uiTextScales`) — ince ayar için kaydırıcı altında duruyor.
  Kaydırıcıyla ara değere gelinirse çubukta EN YAKIN kademe seçili görünür;
  hiçbiri seçili olmayan bir çubuk "bozuk" sanılıyordu.

**Doğrulama:** `analyze` 0 hata, **1423 test yeşil** (+3: yeni varsayılan,
kademe listesi ve sınırları, ayarlar ekranında kademeler + yazı tipi sayfası).

## 2026-08-07 (5) — Yarıda kalan işe "Devam et", Yaptıklarım defteri, video özeti
Kullanıcı üç madde: *"boyut düşürme veya başka bir işlem yarım kaldığında
'dokunun devam etsin' çalışmıyor"*, *"benim yaptıklarım kartı lazım … her şey
kategorize olmalı"*, *"video boyut düşürmede şu anki durum görülmeli,
çözünürlük kare sayısı vs görülmeli ki ne yapacağımızı bilelim"*.

### A) "Devam et" gerçekten çalışıyor — `JobRecipe`
- **Neden çalışmıyordu:** kart "yeniden başlatmak için dokunun" yazıyordu ama
  dokunuş `openJobTarget`e gidiyordu (yalnız klasörü açar). Asıl engel şuydu:
  işin gövdesi bir **closure**, diske yazılamıyor; süreç ölünce elde
  çalıştırılabilir hiçbir şey kalmıyordu.
- **Çözüm:** `JobRecipe(kind, params)` — işin TARİFİ düz veri olarak kaydedilir
  (`FmJob.recipe`, `toJson`/`fromJson`). `JobRecipes.register(kind, runner)`
  ile tür → gövde üreticisi eşlenir; kayıt **`main.dart`ta açılışta** yapılır
  (`registerResizeJobRunner`) — kullanıcı dokunduğunda üretici hazır olmalı.
  `JobQueue.resume(id)` gövdeyi yeniden kurup kuyruğa koyar.
- **Kaldığı yerden:** biten dosya sayısı (`job.done`) tarife `skip` olarak
  geçer; on videonun dördü bittiyse beşinciden devam edilir.
- Kartta artık görünür bir **"Devam et"** düğmesi var (yalnız alt yazıya
  gömülü "dokunun" fark edilmiyordu) ve sonuç snack ile SÖYLENİR — sessiz
  kalmak şikâyetin ta kendisiydi.
- Şu an yalnız boyut düşürme tarifli. Tarama/temizlik işleri zaten kendi
  ekranlarından yeniden başlatılıyor; yeni bir uzun iş eklenirken tarif de
  eklenmeli (`JobRecipes.canResume` düğmeyi ona göre gösteriyor).

### B) Yaptıklarım defteri (`ActivityLog` + `ActivityScreen`)
- Sonuçlar üç yere dağılmıştı ve hiçbiri kalıcı değildi: iş kuyruğu listeyi
  kırpıyor, düzenlenen belgeler hiçbir yere yazılmıyordu.
- Yeni defter `activity_log.json` (en çok 300 kayıt, yol + tür + zaman +
  açıklama). Yazan yerler: **PDF kaydetme diyalogu** (araçlar/imza/AI düzenleme
  hepsi oradan geçiyor), Word/Excel/Slayt `_save`, boyut düşürme çıktıları
  (kazanç bilgisiyle: "48 MB → 12 MB"), tarama PDF'i.
- Ekran türe göre gruplu + çipli süzgeç; **diskte olmayan kayıt listelenmez**
  (dokununca açılmayan satır "bozuk" sanılır). "Geçmişi temizle" YALNIZ
  defteri siler, dosyaları değil — onay metni bunu açıkça yazıyor.
- Panoda İşlemler'in yanında yeni kutu: İşlemler "şu an ne oluyor", Yaptıklarım
  "ne ürettim".

### C) Boyut düşürme sayfasında "Şu an → Sonra"
- Sayfa yalnız hedef sunuyordu; kaynağın ne olduğu hiçbir yerde yazmıyordu.
  Artık üstte kart: **çözünürlük · kare sayısı · süre · boyut · Mbps** ve
  seçime göre canlı **"Sonra: 1280×720 · 30 fps"** satırı.
- Ölçüm `FfmpegVideo.probe` ile, **en çok 5 dosya** (200 fotoğrafta her dosyayı
  ölçmek sayfayı saniyelerce geciktirirdi); videolar önce sıralanır çünkü kart
  ilk öğeyi gösteriyor. Ölçüm başarısızsa kart çizilmez, iş engellenmez.
- **Uyarı:** seçilen ayarlar o dosyada hiçbir şeyi küçültmüyorsa (1080p videoya
  1080p) kırmızı satır çıkıyor — kullanıcı dakikalarca bekleyip "küçülmedi"
  yazısını görmesin.
- Saf mantık `MediaSourceInfo` içinde (bitrate/targetFor/targetFps/
  noVisualChangeWith) → birim testli.

**Doğrulama:** `analyze` 0 hata, **1439 test yeşil** (+16: tarif kaydı/devam
akışı, activity_log defteri, kaynak özeti).

## 2026-08-07 (6) — Açılmayan Excel dosyası, Excel taşma/oto yükseklik, tahmini boyut, PDF formu
Kullanıcı: ekran görüntüsüyle *"custom numFmtId starts at 164 but found a value
of 26"*, *"excelde farklar var bizle gerçek excelde"*, *"devam et 0 dan
başlıyor"*, *"boyut düşürmede tahmini boyut yazmalı"*, *"PDF düzenlemeyi
geliştir"*.

### A) KÖK NEDEN — `excel` paketi GEÇERLİ dosyayı reddediyordu (dosya hiç açılmıyor)
- OOXML'de 0–163 arası sayı biçimi kimlikleri yerleşiktir, 164+ dosyaya özeldir.
  LibreOffice / Google E-Tablolar / kimi Java kütüphaneleri yerleşik bir kimliği
  `<numFmt numFmtId="26" formatCode="…"/>` diye **yeniden tanımlar**; Excel kabul
  eder, `excel` 4.0.6 (`parse.dart`) istisna atar → `XlsxEditor.parse` düşer,
  ekran "Açılamadı" der. Aynı yolda iki tuzak daha var: **aynı kimliğin ikinci
  tanımı** (`numFmtId N already exists`) ve **`formatCode` niteliği olmayan**
  `<numFmt>` (paket `!` ile okuyor → null hatası).
- **Çözüm `services/xlsx_compat.dart`:** styles.xml'de o kimlik 164+ boş bir
  kimliğe **taşınır** (silinmez — biçim kaybolmaz) ve ona işaret eden bütün
  `cellXfs`/`cellStyleXfs` `<xf>` kayıtları güncellenir. `<dxf>` içindeki
  `<numFmt>`e DOKUNULMAZ (orası tanım değil, yerel etiket).
- Onarım yalnız **pakete verilen kopyaya** uygulanır; `XlsxReader` özgün
  baytları okumaya devam eder, kullanıcının dosyası değişmez. Yol try/catch
  ardına konuldu: sağlam dosyada hiç çalışmaz (zip'i ikinci kez açmak bedava
  değil). Aynı onarım `FileService._decodeSpreadsheet`te de var.

### B) "Gerçek Excel gibi" iki eksik davranış
- **Komşuya taşma (`core/sheet_overflow.dart`):** sığmayan metin, komşu hücreler
  BOŞSA üstlerine sarkar. Yerleşim değişmez — `SheetCell` içerikte `OverflowBox`
  kullanır, kutu kendi genişliğinde kalır (dokunma alanı da). Sarkmanın
  altındaki hücre kendi **ızgara çizgisini çizmez** (`Row` çocukları sırayla
  boyandığı için o çizgi harfin ortasından geçerdi; Excel de gizler).
  Kaydırılan / birleşik / **sayı** hücreleri taşmaz — Excel sığmayan sayıyı
  `###` yapar, taşırmaz. Sağdan sola sayfada liste ters çevrilip ekran sırasına
  göre çözülür.
- **Otomatik satır yüksekliği:** dosyada `ht` OLMAYAN satırlar, metin kaydırma
  açık ya da içinde satır sonu olan içeriğe göre yükselir (`XlsxSheet.
  autoRowHeights`, ekran doldurur, dosyaya yazılmaz). Üreticilerin çoğu `ht`
  yazmaz; yüksekliği açan Excel'in kendisidir — bizde dört satırlık hücre tek
  satıra kırpılıyordu.
- **Ölçüm tek kaynaktan:** `SheetCell.metricsStyle` + `SheetTextMeasure`
  (TextPainter, önbellekli). Ölçüm ile çizim aynı stili kullanmazsa hesap
  tutmaz. Karakter sayısından tahmin REDDEDİLDİ: "İĞÜŞÇÖ" ile "illlli" aynı
  karakter sayısında bambaşka genişlikte.
- Sınır: en çok 4000 hücre ölçülür (200 bin hücrelik dosyada açılış saniyelere
  çıkardı); kalan satırlar varsayılan yükseklikte kalır.

### C) "Devam et 0'dan başlıyor"
İş gövdesi (`resize_actions._run`) her koşuda 0'dan sayıyor ve `total`ı KALAN
dosya sayısına düşürüyordu → devam eden iş "0/6" görünüyordu. Dahası bir sonraki
"Devam et" `job.done`u okuduğu için YANLIŞ yerden (baştan) sürerdi. Artık
ilerleme **mutlak** (`offset + done` / `totalFiles`), `JobQueue.resume` eski
işin sayaçlarını ve **çıktı listesini** yeni işe kopyalıyor (`enqueue` aynı
kimlikli kaydı listeden düşürüyor, kopyalamazsak üretilmiş dosyaların kaydı
kayboluyordu).

### D) Tahmini boyut (`models/media_resize.dart`)
- Video: `piksel × kare × kalite bit/piksel` — katsayılar **kodlayıcının
  kendi** tablosundan (`FfmpegVideo._bitrateFor` ile aynı sayılar), kodlayıcıyla
  aynı bit hızı sınırları, ses eklenir.
- Fotoğraf: piksel oranı × JPEG kalite eğrisi (`jpegBytesPerPixel`); kayıpsız
  çıktı piksel sayısından. Kaynak ölçüsü artık **yalnız dosya başlığı**
  okunarak alınıyor (`ImageResizer.probeSize`, ilk 256 KB) — 12 MP JPEG'i
  tümüyle çözmek sayfayı bekletirdi.
- Ölçülmeyen dosyalar (sayfa hız için ilk 5'ini ölçüyor) aynı türün **ortalama
  oranıyla** toplama katılır. Tahmin kaynağın boyutunu aşmaz ve "≈" ile yazılır.

### E) PDF form doldurma (`services/pdf/pdf_form.dart` + `screens/pdf_form_screen.dart`)
- Form PDF'inde yazı içerik akışında DEĞİL, `/Widget` alanlarında yaşar; üstüne
  metin basmak formu doldurmuş saymaz. `PdfFormFiller` alanın kendi değerini
  değiştirir (metin/onay/radyo/açılır liste), isteğe bağlı **düzleştirir**.
- **TUZAK (gerçek hata) — Türkçe:** PDF'in yerleşik yazı tipleri (Helvetica
  ailesi) `İ Ğ Ş ğ ı ş` tanımıyor; Syncfusion alanın görünümünü çizerken
  `Invalid argument (The character is not supported by the font.)` atıyor —
  "Ayşe" yazan kullanıcı formu HİÇ kaydedemezdi. Değerinde ya da **açılır liste
  seçeneğinde** böyle harf geçen alanların yazı tipi gömülü Carlito'yla
  değiştiriliyor (`fontData` ekrandan geçer, izolata `rootBundle` girmiyor).
  Gömülü font yoksa sessiz kalınmaz, açık `PdfFormException` verilir.
- Arayüz **liste**, sayfa üstünde kutucuk değil: alanlar telefonda 8-10 punto,
  yakınlaştırıp minik kutulara yazmak Acrobat'ın mobilde en çok şikâyet edilen
  yanı. Alanlar sayfa sırasına göre gruplanır; salt-okunur alan kilit
  simgesiyle görünür (dokunup bir şey olmaması "bozuk" sanılıyor).
- Keşif: PDF açılırken dosyada `/AcroForm` **akış hâlinde** aranıyor (50 MB'lık
  belgeyi belleğe almadan) ve bulunursa "Bu belge doldurulabilir bir form ·
  Formu doldur" şeridi çıkıyor. Yanlış pozitifte ekran zaten "form alanı yok"
  diyor ve ne yapılabileceğini yazıyor.

**Doğrulama:** Flutter 3.29.3 (CI ile aynı) — `analyze` 0 hata/uyarı,
**1478 test yeşil** (+39: `xlsx_compat_test`, `sheet_overflow_test`,
`spreadsheet_fidelity_test`, `pdf_form_test`, `pdf_form_screen_test`, iş
kuyruğu devam sayacı, tahmini boyut).
Cihazda bakılacaklar: (a) hata veren form dosyası artık açılıyor mu,
(b) uzun başlık komşu boş hücreye sarkıyor mu ve çok satırlı hücrede satır
yükseliyor mu, (c) yarıda kalan boyut düşürmede "Devam et" 4/10'dan mı
sürüyor, (d) ayar sayfasındaki tahmin gerçek sonuca yakın mı,
(e) form PDF'inde ⋮ → Formu doldur (Türkçe harfli alanla) kaydediyor mu.

## 2026-08-07 (7) — PİL ve BAŞARIM denetimi (kullanıcı: "pil ve performans sorunlarını tespit edip düzelt")
Bu tur bir istek listesi değil, **denetim**: uygulama baştan sona pil kaçağı,
bellek şişmesi ve gereksiz yeniden çizim açısından tarandı. Bulunan altı
maddenin hepsi düzeltildi, biri de yeni ayar olarak kullanıcının eline verildi.

### A) EN BÜYÜĞÜ — görseller TAM ÇÖZÜNÜRLÜKTE açılıyordu (`core/image_budget.dart`)
- Galeri (`image_gallery_screen`) ve görüntüleyici (`viewer_screen`)
  `Image.file`ı **`cacheWidth` vermeden** kullanıyordu. Flutter o zaman dosyayı
  tam çözünürlükte bitmap'e açar: sıradan bir 12 MP telefon fotoğrafı
  (4000×3000) bellekte **48 MB** eder — dosyanın kendisi 3 MB olsa bile, çünkü
  JPEG çözülünce piksel başına 4 bayt kalır. `PageView` komşu sayfayı da canlı
  tuttuğu için aynı anda iki-üç görsel açılıyordu → 100 MB+ bitmap, sürekli çöp
  toplama, kaydırmada takılma, düşük bellekli telefonda sistemin uygulamayı
  öldürmesi. Sürekli çöz-at döngüsü CPU'yu meşgul ettiği için pil de buna
  gidiyordu.
- **Çözüm:** ekranda kaç piksel görünecekse o kadar çöz. 1080p telefonda tam
  sayfa görsel için 1536 piksel yeter (~9 MB yerine 48 MB).
- **Yakınlaştırma kaybedilmedi:** ölçek hesaba katılıyor, ama `maxWidth = 3072`
  tavanıyla — 6 kat yakınlaştırmada tam çözünürlüğe dönmek ilk sorunu geri
  getirirdi.
- **TUZAK — kademe (`step = 512`) şart:** `cacheWidth` her değiştiğinde Flutter
  görseli YENİDEN çözer ve önbellekte AYRI kayıt tutar. Ölçek parmak
  hareketiyle sürekli değiştiği için her karede yeni genişlik istenirse
  saniyede onlarca çözme olurdu; kademeye YUKARI yuvarlamak bunu elle
  sayılacak kadar seyrekleştirir (aşağı yuvarlamak istenenin altında kalıp bir
  kademe bulanık çizerdi).
- `cacheWidth` kaynaktan büyük olursa Flutter değeri kendiliğinden kaynağa
  kısar (`allowUpscaling: false`) → küçük görsel büyütülüp şişmez.
- `ImageBudget` saf ve testli; ekranlarda `TransformationController` dinlenip
  kademe atlayınca yeniden çözülüyor.

### B) Video arka planda oynamaya DEVAM ediyordu (en pahalı pil kaçağı)
- `media_player_screen`in sınıf notu "uygulama arkaya alınınca çalma durur"
  diyordu; **Android'de bu doğru değil.** `video_player` ExoPlayer'ı sürer,
  ekran kapalıyken bile kareleri çözmeye devam eder — görüntü kimseye
  gösterilmeden. Telefon cepteyken süren tam güçte video kod çözme.
- Artık `WidgetsBindingObserver`: `paused`/`hidden`/`detached`ta duraklar,
  `resumed`da **yalnız biz duraklattıysak** devam eder (kullanıcı duraklattıysa
  kendiliğinden başlamaz — şaşırtıcı olurdu).
- `inactive` bilerek YOK SAYILIYOR: bildirim gölgesini çekmek ya da izin
  penceresi de o durumu üretir, orada duraklatmak izlemeyi bölerdi.
- Ses oynatıcı (`AudioPlayerScreen`, audioplayers) bilerek dışarıda: müziğin
  arka planda sürmesi İSTENEN davranış.

### C) Video oynatıcı her yarım saniyede TÜM ekranı yeniden kuruyordu
`_onTick` içindeki `setState(() {})` denetleyicinin her konum yayınında (saniyede
iki kez) üst çubuğu, degradeleri, açılır menüleri ve video ağacını yeniden
kuruyordu. Konum çubuğu artık kendi `ValueListenableBuilder`ında
(`VideoPlayerController` zaten `ValueListenable`) → yeniden çizilen alan yalnız
alt kontroller. `_onTick`te setState yalnız oynat/duraklat DEĞİŞİMİNDE.

### D) Pano kutusunun "nefes alması" SÜRESİZDİ
Çöp kutusu dolu olduğunda simge sonsuza kadar büyüyüp küçülüyordu. Hareket eden
tek piksel bile olsa Flutter her kareyi yeniden çizer: pano açıkken uygulama hiç
boşa geçmiyor, 120 Hz ekranda kullanıcı ekrana bakıp dururken bile saniyede 120
kare üretiliyordu. Kutunun işi **dikkat çekmek**; 6 saniye sonra o iş bitti
sayılıp dinlenme boyutuna dönülüyor (`animateBack` — ortada kesilen animasyon
simgeyi büyük bırakıp "bozuk" gösterirdi). Kutu bundan sonra da koyu zemin +
renkle ayırt edilebiliyor.

### E) Pano taraması sırasında yapılan değişiklik YUTULUYORDU (gerçek hata)
`_scan()` bitişte `FsEvents.version`i okuyup `_stale = false` yapıyordu. Tarama
dakikalar sürebildiği için o sırada silinen/taşınan dosya "görülmüş" sayılıyor,
panoya hiç yansımıyordu — kullanıcı silinen dosyayı sayılarda görmeye devam
ederdi. Sürüm artık yürüyüşün BAŞINDA alınıyor; arada değiştiyse tarama **bir
kez** tekrarlanıyor (`allowRepeat`). Zincir en çok iki tur: sürekli yazan bir
işlem (büyük kopyalama) panoyu sonsuza dek yeniden taratmasın.

### F) Sohbet: yanıt gelmeden ekrandan çıkınca `setState() called after dispose()`
Gemini yanıtı saniyeler sürüyor; kullanıcı bu arada geri tuşuna basarsa
`chat_screen`in üç `setState`i elden çıkmış `State` üzerinde çalışıyordu.
`mounted` koruması eklendi.

### G) Küçük resim "başarısız" listesi SINIRSIZDI
`ThumbnailCache._failed` süreç boyunca büyüyordu (her kayıt tam dosya yolu); on
binlerce videosu olan telefonda kaydırdıkça şişiyor ve hiç boşalmıyordu. 512'de
sınırlandı, dolunca en eski yarısı düşüyor — en kötü ihtimalle o dosyalar için
zaten hızlıca başarısız olan çağrı bir kez daha yapılır.

### H) YENİ — Ayarlar > **Pil ve başarım**
Uygulamanın en pahalı iki alışkanlığı KOŞULSUZ açıktı; ikisi de çoğu kullanıcı
için doğru varsayılan ama kapatılabilmeliydi:
- **Yüksek tazeleme hızı** (varsayılan açık). Kapatınca `FlutterDisplayMode.
  setLowRefreshRate()` — GPU saniyede yarı kadar kare çizer; uzun belge
  okumada en gözle görülür pil kazancı. Ayar **anında** uygulanıyor:
  "yeniden başlat" isteyen bir ayar denenmeden kapatılıp unutulur.
  `main.dart`taki koşulsuz `setHighRefreshRate()` çağrısı kaldırıldı; tercih
  `AppState.init()` sonrasında okunup uygulanıyor
  (`core/display_mode.dart` → `applyRefreshRate`). Fonksiyon `main.dart`ta
  BIRAKILMADI: Ayarlar ekranının `main.dart`ı içe aktarması (uygulamanın giriş
  noktasına geri bağımlılık) test kurulumunu da gereksiz yere ağırlaştırırdı.
- **Otomatik yeniden tarama** (varsayılan açık). Pano dizin 12 saatten eskiyse
  tüm depolamayı yeniden geziyordu: on binlerce dosyada dakikalarca CPU + disk.
  Kapatılabilir. **AYRIM önemli:** `SearchIndex.isStale` (bizim yaptığımız bir
  silme/taşıma yüzünden bayat) tercihe BAKMADAN tazeleniyor — kullanıcının
  sildiği dosyanın sayılarda kalması kabul edilemez; kapatılabilen yalnız
  "uygulama dışında bir şey değişmiş olabilir" varsayımıyla yapılan tahmini
  tam tarama.

**Bilinçli YAPILMAYAN:** ekranı açık tutma (wakelock). `wakelock_plus 1.4.0`
Flutter 3.29.3 ile çözümleniyor (bu oturumda denendi, uyumlu) ama pil azaltmayı
isteyen bir turda pil ARTIRAN bir bağımlılık eklemek ve gece boyu doğrulanmamış
bir eklentiyle main'i riske atmak doğru olmazdı. KALANLAR'da duruyor.

**Doğrulama:** Linux bulut oturumunda Flutter 3.29.3 (CI ile aynı) —
`flutter analyze` 0 hata/uyarı (lib'de yeni tek bir `info` bile yok, stash'li
karşılaştırmayla ölçüldü), **1495 test yeşil** (+17: `image_budget_test`,
`image_decode_budget_screen_test`, oynatıcı yaşam döngüsü, kutu nefesinin
durması, Pil ve başarım ayarları).
Cihazda bakılacaklar: (a) galeride büyük fotoğraflar arasında kaydırma daha
akıcı mı ve yakınlaştırınca yazı hâlâ keskin mi, (b) video izlerken ana ekrana
çıkıp dönünce video durup kaldığı yerden devam ediyor mu, (c) çöp kutusu
kutusunun animasyonu birkaç saniye sonra duruyor mu, (d) Ayarlar > Pil ve
başarım'da tazeleme hızını kapatınca kaydırma hissi değişiyor mu.

## 2026-08-08 — KALANLAR turu: çevrilmemiş metin bitti, altı madde kapandı
Kullanıcı: *"kalanları bitir hepsini bu oturumda yap"*. Liste ~60 maddeydi;
**yarısı cihaz doğrulaması** (kullanıcının telefonunda bakılacak şeyler) ve bir
kısmı paket/ortam sınırı. Bu turda **kodla kapatılabilen** maddeler kapatıldı,
kapatılamayanların NEDENİ maddenin yanına yazıldı (aşağıda ve KALANLAR'da).

### A) "Kalan ekranlar hâlâ Türkçe" → BİTTİ, üstelik BEKÇİSİ var
- Madde 2026-07-30'da yazılmıştı ve **eskiydi:** tablo o gün 4 ekranlıkken
  bugün **1692 anahtar** ve 75 dosya `context.t` kullanıyordu. Kaynak
  tarandığında kullanıcıya görünen yerlerde yalnız **~50 sabit Türkçe dize**
  kalmıştı; hepsi taşındı (ortak sözcükler `common.*` altında toplandı —
  "Geri al / Yeniden dene / Yeniden tara / Temizle / Yeni / en eski / en iyi").
- **Asıl iş bekçi:** `test/l10n_literals_test.dart` kaynağı tarıyor ve
  `Text(...)`, `tooltip:`, `label:`, `title:`, `hintText:` gibi kullanıcıya
  görünen yerlere doğrudan Türkçe yazılırsa **testi kırıyor**.
  *Niye kaynak taraması:* çevrilmemiş metin çalışırken hata vermez, yalnız
  İngilizce/Arapça kullananın ekranında Türkçe görünür — kimse fark etmez ve
  liste tur sonunda yeniden şişer. `l10n_test` yalnız TABLODAKİ eksikleri
  yakalıyor; tabloya hiç girmemiş metni ancak kaynağa bakan bir test yakalar.
- İzin listesi dar ve gerekçeli: marka adı (Dosya Okuyucu, Google Drive, ZIP),
  JSON anahtarı, disk göstergesi, API anahtarı ipucu, JS çağrısı, desen
  sözdizimi.

### B) Ekranı açık tutma (wakelock) — `core/screen_awake.dart`
- `wakelock_plus 1.4.0` eklendi (Flutter 3.29.3 ile çözümlendiği bir önceki
  turda ölçülmüştü).
- **Doğrudan eklenti çağrılmıyor, sayaçlı bir kapı var.** Wakelock pil HARCAR;
  bir önceki tur pil kaçaklarını kapatmakla geçti, buraya kontrolsüz bir kaçak
  açmak o işi geri alırdı. `request()` bir bırakma işlevi döndürür; **son**
  sahip bırakınca kilit açılır. Sayaç şart: iç içe iki sahip varken biri
  bırakınca ekran ötekinin altından sönerdi.
- Kilit **yalnız video GERÇEKTEN OYNARKEN** tutuluyor: duraklatınca, video
  bitince, uygulama arkaya alınınca ve ekran kapanınca bırakılıyor. Ses
  oynatıcıda hiç alınmıyor (müzik dinlerken ekranın sönmesi istenen davranış).
- **TUZAK:** `unawaited(_apply(...))` ile başlatılan çağrıda `try` bloğu test
  yönlendirmesini de KAPSAMALI; yoksa oradan sızan hata "yakalanmayan asenkron
  hata" olur ve ilgisiz bir testi kırar.

### C) Yapıştırmada çakışma politikası soruluyor
- Eskiden sessizce `FmConflict.rename` uygulanıyordu (`rapor.pdf` →
  `rapor (1).pdf`). Veri kaybı yoktu ama kullanıcının niyeti çoğu zaman
  **güncelleme**: aynı dosyanın yeni sürümünü yapıştırıp klasörde iki kopya
  bulmak ve hangisinin yeni olduğunu bilememek gerçek bir karışıklıktı.
- `PasteConflict.collisions` (saf + testli) çakışan adları buluyor; **yalnız
  çakışma varsa** alt sayfa açılıyor: İkisini de tut / Atla / Üzerine yaz.
- **Pencereyi kapatmak = vazgeç.** Sessizce bir varsayılana düşmek,
  kullanıcının kapattığı pencerenin yine de dosya yazması olurdu.
- Klasör çakışması da sayılıyor (aynı adlı klasörün üzerine yazmak dosyadan
  daha yıkıcı; sorulmayan bir yol bırakılamazdı).

### D) Açılış klasörü ayarı (Material Files'ta vardı)
`AppState.fmStartFolder` + Dosya yöneticisi ayarları > **Açılış klasörü**.
Boşken hiçbir şey değişmiyor (pano yine ilk ekran). Klasör silinmişse
(SD kart çıkarılmış olabilir) **sessizce** pano gösteriliyor — açılışta
kullanıcının çözemeyeceği bir hata penceresiyle karşılamak kötü karşılamadır.
Açılış yalnız BİR KEZ: bayrak `static`, yoksa tema/dil değişimi ağacı yeniden
kurunca kullanıcı geri tuşuyla panoya her döndüğünde içeri fırlatılırdı.

### E) Ses etiketleri: kapak resmi + sanatçı/albüm — `services/fm/audio_tags.dart`
- **Saf Dart, bağımlılık yok.** Ekranda dört alan gösteriliyor; bunun için tam
  bir etiket kütüphanesi (ve APK'da birkaç yüz KB) eklemek "sade/hızlı"
  konumlandırmasıyla çelişirdi.
- **ID3v2.2/2.3/2.4** + **MP4/M4A `ilst`**. Okunamayan etiket sessizce boş
  döner ve ekran eskisi gibi dosya adını gösterir — en kötü durum, bu iş
  yapılmadan önceki durumdur.
- **TUZAKLAR (testle sabitlendi):**
  - v2.4'te ÇERÇEVE boyutu da senkron-güvenlidir (7 bit). Düz 32 bit okumak
    zinciri kaydırır ve etiketin kalanı çöpe döner.
  - `APIC` açıklaması kodlamaya göre 1 ya da 2 bayt NUL ile biter; UTF-16'da
    tek bayt aramak görüntünün ilk baytını yutar.
  - MP4 atom adı DÖRT BAYTTIR: `©nam`daki `©` UTF-8 (2 bayt) değil, tek
    baytlık 0xA9. `utf8.encode` kullanmak bütün atom zincirini kaydırır.
  - Metin alanları NUL ile sonlanır → ilk NUL'dan sonrası atılmalı.
- Dosyanın yalnız **ilk 2 MB'ı** okunuyor (etiket başta durur); 40 MB'lık bir
  albümü belleğe almanın anlamı yok. Kapak `cacheWidth: 480` ile çözülüyor.

### F) PDF kapak küçük resmi — `services/fm/pdf_thumbnail.dart`
Listelerde her PDF aynı kırmızı simgeydi; on faturanın hangisinin hangisi
olduğu yalnız addan anlaşılıyordu. İlk sayfa pdfium ile çizilip **diskte**
önbelleğe alınıyor — anahtar video küçük resimleriyle AYNI kural
(`ThumbnailCache.cacheName`: yol + değişiklik zamanı + boy), aynı klasör
mantığı. Parolalı/bozuk belge sessizce simgeye düşüyor ve **bir daha
denenmiyor** (her kaydırmada pdfium'u yeniden çalıştırmasın). En-boy oranı
korunuyor: kare çizmek A4'ü yamultup "yanlış belge" hissi verirdi.

### G) Windows'ta kırık testler → `test/support/temp_dir.dart`
Kök neden temizlikti: `tearDown`daki çıplak `deleteSync(recursive: true)`
Windows'ta `FileSystemException` atıyor (arşiv/WebView/video bir kolu geç
bırakıyor) ve **testin kendisi geçmişken** kırmızı yakıyordu. Sonuç: yerelde
`flutter test` sürekli kırmızı döndüğü için gerçek regresyon gürültüden
ayrılamıyordu. Artık tek yardımcı: kısa yeniden deneme, sonra **sessizce** pes.
Temizlik bir doğrulama değildir; silinemezse işletim sistemi zaten toplar.
`fm_archive_rar_test`teki `rethrow`lu döngü de buna çevrildi.

### H) Eskimiş maddeler kapatıldı (kod zaten yapıyordu)
Toplu yeniden adlandırma (`batch_rename_sheet.dart`), video küçük resmi
(`ThumbnailCache` + `_VideoThumb`), ağ/bulut (Drive + SFTP/FTP/SMB/WebDAV
ekranları). Üçü de listede "yok" diye duruyordu.

**Doğrulama:** Linux bulut oturumunda Flutter 3.29.3 (CI ile aynı) —
`flutter analyze` 0 hata/uyarı, tüm testler yeşil.

### 2026-08-08 (2) — Bekçi testi kendi sınırını gösterdi
`lib/` lint temizliği yaparken sohbet ekranının dışa aktarma menüsünde
`Text('Aktar')` ve `Text('Sunum (PDF)')` görüldü — yani bir gün önce yazılan
`l10n_literals_test` bunları KAÇIRMIŞTI. Sebep yapısal ve kayda değer:

**Bekçi Türkçe'yi harften ve kelime listesinden tanıyor.** "Aktar" ve "Sunum"
Türkçe'ye özgü harf taşımıyor ve listede yoktu → sızdılar. Kelime listesi
genişletildi (aktar, sunum, ekle, gönder, indir, paylaş, ara, bul, başlat,
durdur, devam, bitir) ve genişletme **anında altı tane daha gerçek sızıntı**
yakaladı: "Ara", "Uygulama ara…", "Durdur" (iki yerde), "Devam et", "Ekle".
Hepsi tabloya taşındı.

**Ders — bu test bir kanıt değil, ucuz bir süzgeç.** Yanlış pozitif üretmemesi
(İngilizce/marka dizelerini kızdırmaması) yakalama oranından daha değerli:
bağıran ama yanılan bir test kısa sürede susturulur. Sızıntı görüldükçe
kelime listesi büyütülmeli; testin dosya başındaki notu bunu yazıyor.

Ayrıca `flutter analyze lib` **ilk kez sıfır sorun**: `const ZLibEncoder/
Decoder`, kayıt deseninde `__` yerine joker `_`, galeri `_paths` alanı
`final` (yalnız mutasyon var, yeniden atama yok).

### 2026-08-08 (3) — Bekçinin iki YAPISAL deliği: eklemeli dil ve alt satır

Önceki oturum `ba88610`'ı APK derlensin diye main'e itip yarıda kaldı.
**Önce o kapatıldı:** koşu 265 yeşil, `v0.1.0-build-265` yayımlandı — yani
2026-08-06 kırmızısının runner tarafı olduğu (PR #43 teşhisi) artık ölçüyle
de doğrulandı, kodda yapılacak bir şey yok.

Asıl iş, o commit'in kendi açık bıraktığı uçtu. Bir gün önce kelime listesi
genişletilince ANINDA altı sızıntı çıkmıştı; bu, listenin dar olduğunu değil
**testin şeklinin yanlış** olduğunu gösteriyordu. İki ayrı delik bulundu:

**A) Türkçe EKLEMELİ bir dil — `\b(gövde)\b` yanlış şekil.** Liste `dosya`yı
tanıyordu ama `'Dosyalar'` sızdı: `-lar` eki sondaki `\b`yi kaydırıyor ve tam
kelime eşleşmesi tutmuyor. Aynı sebeple `'Uygulamalar'`, `'Yolu kopyala'`,
`'Boyutu hesapla'`, `'Konum'`, `'Parola'` görünmezdi. Çözüm: gövde + **en çok
iki Türkçe ek** (`uygula`+`ma`+`lar`), ek listesi AÇIK ve sonlu.
**Serbest son ek (`gövde\w*`) DENENMEDİ, çünkü İngilizce'yi yakardı:** `bu`
gövdesi `button`/`build`/`buffer`, `bas` gövdesi `base` ile eşleşirdi — ve bu
testin en değerli özelliği yanlış pozitif üretmemesi. Kapalı ek listesi
bunları eler (`tton` Türkçe eki değildir). Ölçüldü: 21 gerçek sızıntı, sıfır
yanlış pozitif.

**B) Yuva ile metin AYNI satırda olmayabilir.** `Text(` satır sonunda bitip
dize alt satıra düşünce (biçimlendiricinin sık yaptığı şey) yalnız o satıra
bakan tarama körleşiyordu — `markdown_text`teki `'kod'` böyle sızmıştı.
Artık önceki satır yuva açıp kapatmadan bittiyse alt satır da taranıyor.
Bütün ağaçta bu konumda yalnız 4 dize var (`'kod'` + `'page'`, `', '`, `' · '`
— üçü çevrilmez), yani delik kapandı ve gürültü gelmedi.

**TUZAK — `_suffixes` sıralaması.** Alternatifler soldan denenir: `lar`,
`ları`dan önce yazılırsa uzun biçim hiç denenmez ve sondaki `\b` tutmaz.
Uzun ek kısa olandan ÖNCE gelmeli.

**TUZAK — Python ile prova ETME.** Regex'i önce Python'da denerken 107 sahte
sızıntı çıktı (`'ps.title'`, `'ZIP'`, `'size'`…). Sebep: Python'un `re.I`si
tam kılıf katlaması yapar, `ı` (U+0131) ASCII `I` ile eşleşir — yani
`[çğıöşü]` sınıfı **içinde `i` geçen her dizeyi** yakar. Dart/ECMAScript bu
eşlemeyi bilerek dışarıda bırakır (büyük harfi ASCII'ye düşen ASCII-dışı
karakter kendisi olarak kalır), o yüzden Dart testinde bu sorun YOK. Ders:
bekçiyi kendi diliyle koştur, taklidiyle değil.

### Servis katmanındaki etiketler — `StorageVolume.labelKey`
`'Ana bellek'` / `'SD kart'` saf Dart serviste duruyordu (`context.t` yok).
Model artık metin değil **anahtar** taşıyor (`labelKey`, mevcut
`FmCategoryLabel.labelKey` düzeniyle aynı) ve ekran `displayLabel(context.t)`
ile çeviriyor. **Neden metin saklanmadı:** birim listesi açılışta bir kez
kuruluyor; hazır çevrilmiş metin saklansaydı kullanıcı dili değiştirdiğinde
eski dilde donardı. Takılabilir diskin KENDİ adı (`SAMSUNG`) çevrilmez — o
kullanıcının verisi; yalnız UUID adlı birim "SD kart" olur.

**TUZAK (testle sabitlendi):** `volumes()` doluluk bilgisini `copyWith` ile
dolduruyor. `copyWith` yeni alanı taşımayı unutursa **her birim adsız kalır**
— sızıntı derlemede değil yalnız ekranda görünürdü.

`vt.fallback_engine` zaten TABLODA VARDI (`yedek motor (kademeli ölçü)`) ve
kullanılmıyordu; yenisini eklemek `equal_keys_in_const_map` derleme hatası
verdi. Yeni anahtar açmadan önce tabloya bakmak gerekiyor.

**Doğrulama:** Linux bulut oturumu, Flutter 3.29.3 (CI ile aynı) —
`flutter analyze lib` sıfır sorun, **1523 test yeşil** (yeni `labelKey`
gerileme testi dahil).

## 2026-08-08 (4) — Slayt ↔ PDF: iki yön de yazıldı

Kullanıcı yarım kalan işin `claude/slayt-pdf-donusturme-ypvtqd` dalı olduğunu
söyledi. **O dal uzakta YOK** (GitHub'da 19 dal var, aralarında değil), ona ait
PR yok, yerelde stash/reflog izi yok, hiçbir dalda slayt↔PDF commit'i yok —
yani o oturumdan hiçbir şey push edilmemiş. Devam edilecek kod değil, sıfırdan
yazılacak iş çıktı. **Ders:** dal adı işin yapıldığını göstermez; "yarım kalan"
denince önce uzakta gerçekten commit var mı diye bakılmalı.

### Önceki durum (ölçüldü, varsayılmadı)
- **Slayt → PDF: hiç yoktu.** `.pptx` dosya yöneticisinden `SlidesEditorScreen`e
  gidiyor, oradaki "Paylaş" `.pptx`in KENDİSİNİ paylaşıyordu. `pptx_render`,
  `pptx_editor`, `slideshow_screen` — üçünde de "pdf" kelimesi geçmiyordu.
- **PDF → slayt: çalışmıyordu.** Menüde "Slayta dönüştür" vardı ama
  `_exportSlides` metni `_textController?.text ?? doc.plainText`ten alıyordu ve
  PDF'te İKİSİ DE BOŞ (PDF metin türü değil, metni `_pdfText`te durur). Yani
  asıl hedef olan PDF'te boş deste üretiyordu. Üstüne bölme yalnız `---` /
  `— Slayt N —` arıyordu; gerçek bir PDF'te bunlar yok, her şey tek slayta
  düşerdi.

### A) Slayt → PDF: görüntü + GÖRÜNMEZ metin (`slides_pdf.dart`, `slide_snapshot.dart`)
Ekranda çizilenin ta kendisi PDF'e basılıyor, üstüne `3 Tr` ile görünmez metin
yazılıyor — **taranmış PDF'ler için zaten var olan `imagesToPdf(ocrLinesPerPage:)`
yolu yeniden kullanıldı**, yeni bir PDF yazıcı yazılmadı.
- **Neden vektör yeniden çizim DEĞİL:** slayt sadakati (prstGeom, custGeom,
  lnRef, gradient, kırpılmış görsel) `slide_canvas`ta uzun uğraşla oturdu. Aynı
  çizimi `pdf` paketiyle ikinci kez yazmak o sadakati sıfırdan riske atardı ve
  iki çizici birbirinden bağımsız bozulurdu.
- **TUZAK — başsız (headless) çizim görselli slaytları BOŞ basar.** `SlideCanvas`
  görselleri `Image.memory` ile çiziyor, çözümleme asenkron. Tek karede boyayan
  bir `BuildOwner`/`PipelineOwner` kurgusu görseli olan slaytları sessizce boş
  bırakırdı (hata da atmaz). Bu yüzden slayt gerçek ağaca (Overlay) ekleniyor,
  görseller `precacheImage` ile önden alınıyor, İKİ kare bekleniyor.
- **TUZAK — `Offstage` işe yaramaz:** offstage alt ağaç hiç boyanmaz,
  `toImage` boş döner. Slayt ekran DIŞINA ötelenerek konuyor; `RepaintBoundary
  .toImage` kendi katmanını çizdiği için üstteki öteleme çıktıya yansımıyor.
- **TUZAK — `ui.Image.dispose()`:** yerel bellek tutar, GC beklemez; 40 slaytlık
  destede bırakılırsa bellek slayt sayısıyla büyür.
- Görüntü ve metin kutuları AYNI `_pdfPixelRatio` (2.0) ile ölçekleniyor —
  ayrışırsa seçim kutuları yazının yanına düşer. Kutu şekil başına değil
  **paragraf başına**: yoksa kopyalanan metin tek satıra iner.
- Sayfa boyu = slaydın kendi boyu; A4'e sığdırmak 16:9'u kâğıdın ortasında bant
  yapardı.

### B) PDF → Slayt: GERÇEK .pptx (`pptx_writer.dart`, `text_to_slides.dart`)
Çıktı artık PDF değil **düzenlenebilir .pptx** — "tersi" isteğinin karşılığı bu.
- **Neden elle XML:** pub'da bakımlı bir PPTX YAZICI yok. Paket ~11 küçük XML
  parçası; elle yazmak bağımlılık eklemiyor.
- **TUZAK — PowerPoint ilişkilerde katı.** Eksik `slideLayout`/`theme` ilişkisi
  "onarılması gerekiyor" uyarısı çıkarır. `fmtScheme` listeleri SABİT sayıda
  öğe ister (3 dolgu, 3 çizgi, 3 efekt, 3 arka plan). Kendi okuyucumuzun
  hoşgörülü olması yeterli DEĞİL — dosya dışarıda da açılmalı.
- **TUZAK — `p:sldId@id` en az 256** (ECMA-376); küçüğü dosyayı geçersiz yapar.
- **TUZAK — XML kaçışında `&` ÖNCE gelmeli**, yoksa `&lt;` → `&amp;lt;` olur.
  Ayrıca XML 1.0'da yasak denetim karakterleri PDF metninden geliyor ve
  dosyayı açılamaz yapardı — süzülüyor.
- Yerleşimden MİRAS alınmıyor, her şekle açık `a:xfrm` yazılıyor: miras zinciri
  okuyucuya göre farklı yorumlanıyor, açık koordinat her yerde aynı.
- **TUZAK — `RegExp` varsayılanı çok satırlı DEĞİL.** Ayraç sezgisi
  `_explicit.hasMatch(tümMetin)` ile yazılınca `^…$` yalnız metnin tamamı bir
  ayraçsa eşleşiyordu; açık `---` ayraçları hiç görülmedi (test yakaladı).
  Artık satır satır bakılıyor.
- Bölme kuralları: açık ayraç > boş satır blokları. Tek satırlık UZUN paragraf
  kendi slaytını açmaz, öncekine madde olur (yoksa her cümleye bir slayt).
  Altı maddeden sonrası aynı başlıkla taşar. Cümleyle başlayan blok başlıksız
  kalır — uydurma başlık yazmaktansa boş bırakmak dürüst.

**Bilinen borç:** iki ayrı bölücü var — `conversion_service._splitIntoSlides`
(AI metninden PDF deste, `stripInlineMarkdown` uygular) ve `TextToSlides`.
İkincisi daha iyi ama markdown temizlemiyor; birleştirmek ayrı bir tur.

**Doğrulama:** Flutter 3.29.3 (CI ile aynı) — `analyze lib` sıfır sorun,
**1540 test yeşil** (17 yeni). Gidiş-dönüş testi asıl kanıt: ürettiğimiz .pptx
`PptxEditor.parse` ile açılıyor ve çizilebilir `SlideVM` veriyor.

## 2026-08-08 (5) — AI ile gerçek sunum: yapılandırılmış JSON + konuşmacı notu

Kullanıcı "AI ile yapabilmeliyiz, gerçekten kullanışlı slayt ve PDF istiyorum"
dedi. Sezgi (`TextToSlides`) kaynağın BİÇİMİNE bakıyor: metin zaten slayt gibi
yazılmışsa iyi, ama tipik bir PDF (rapor, makale, form) düzyazıdır — orada
"başlık" ve "madde" diye bir şey yoktur ve sezgi ne yaparsa yapsın çıktı
paragrafların slayta kopyalanmış hâli olur. Teknik olarak slayt, sunum olarak
işe yaramaz. Özetleyerek madde çıkarmak anlama dayalı bir iş; modele ait.

### A) Serbest metin değil, ŞEMAYA BAĞLI JSON — `GeminiService.generateJson`
`chat()` + "bana JSON ver" istemi güvenilmez: model açıklama cümlesi ekler,
```json çiti koyar, bazen tek tırnak kullanır. Gemini'nin `responseMimeType:
application/json` + `responseSchema` ayarı çözümlemeyi MODELE bırakıyor.
Sıcaklık 0.3 — burada yaratıcılık değil kaynağa sadakat isteniyor.

**Yine de savunmacı ayrıştırma şart** (`AiSlides.parse`): şema garantisi mutlak
değil, yanıt uzunluk sınırında KESİLEBİLİR. Kurtarılabilen her şey kurtarılıyor
— tek bozuk slayt yüzünden kullanıcının bütün işi çöpe gitmesin. Çit ve
gövde-dışı cümle soyuluyor, nesne olmayan öğe atlanıyor, boş madde süzülüyor.
Hiç kullanılabilir slayt yoksa **hata veriyor**, sessizce boş dönmüyor.

### B) Konuşmacı notu — `notesSlide` + `notesMaster`
AI'nin ürettiği asıl değer maddelerden çok "bu slaytta ne anlatılacak" notu.
- **TUZAK — ECMA-376 eleman SIRASI bağlayıcı:** `sldMasterIdLst` →
  `notesMasterIdLst` → `sldIdLst` → `sldSz` → `notesSz`. Sıra bozulursa dosya
  geçersiz.
- **TUZAK — `notesMasterId r:id`, `presentation.xml.rels`teki Id ile BİREBİR
  aynı olmalı**; slayt sayısına göre kayan numaralandırmada kolay kaçar.
- Notu olmayan slayt için `notesSlide` parçası HİÇ yazılmıyor (paket şişmesin);
  hiç not yoksa `notesMaster` da eklenmiyor. Testle sabitlendi.

### C) Çift bölücü borcu KAPANDI
`conversion_service._splitIntoSlides` silindi; `textToSlidesPdf` artık
markdown'ı temizleyip `TextToSlides.split`e veriyor ve ortak
`slidesToPdf(title, List<SlideDraft>)` yolunu çağırıyor. Böylece AI planı da,
sezgi planı da AYNI PDF yolundan geçiyor. `conv.slide_fallback` anahtarı da
gereksizleşti (artık uydurma başlık yazılmıyor, başlıksız slayt kalıyor).

### D) Sezgi yolu SİLİNMEDİ
Akışta "AI ile hazırla" / "Hızlı (AI'sız)" seçimi var. AI anahtar ister ve para
harcar; ücretsiz ve çevrimdışı seçeneği kaldırmak uygulamanın "sade, hızlı,
ücretsiz" konumlandırmasına aykırı olurdu. Çıktı biçimi de ayrı soruluyor:
.pptx (düzenlenebilir) / PDF (düzeni bozulmaz).

Deste kullanıcının ARAYÜZ dilinde üretiliyor ve modele dilin KENDİ adı
gönderiliyor ('Türkçe'/'English'/'العربية') — 'tr' gibi bir koddan net.

**Doğrulama:** Flutter 3.29.3 — `analyze lib` sıfır sorun, **1551 test yeşil**.

### Excel bulgusu — İKİ TEZ DE ÇÜRÜDÜ (henüz teşhis YOK)
Kullanıcı düzenlediği .xlsx'te "yazılar farklı göründü, çubuk silindi" dedi.
İki tez ölçüldü ve **ikisi de yanlış çıktı** — kayda değer, çünkü ikisi de
makul görünüyordu:
1. *"`excel` paketi tanımadığı parçaları atıyor"* → HAYIR. Gidiş-dönüş denendi:
   `xl/charts/chart1.xml` ve `xl/drawings/drawing1.xml` kaydetmeden sağ çıktı
   (KAYBOLAN: []).
2. *"Sayfadaki `<drawing r:id>` bağlantısı düşüyor, grafik yetim kalıyor"* →
   HAYIR. Etiket de sağ çıktı.
Yani grafik kaybı bu mekanizmadan DEĞİL. Teşhis için kullanıcıdan netleştirme
gerekiyor. **KVKK:** bulgunun geldiği dosya hasta/asistan kişisel verisi
içeriyor — dosya İSTENMEYECEK, tekrar üretim için anonim örnek istenecek.

## 2026-08-09 — Bellek analizi, hızlı süzgeçler, altyazı, simge
Kullanıcı ekran görüntüsüyle yedi madde bildirdi. Hepsinin ortak teması:
**gösterilen sayı ile verilen sonuç birbirini tutmuyordu.**

### A) "En büyük dosyalarda sadece videolar var, diğerleri boş"
Kök neden: `StorageIndex.largest` **tek** bir liste ve yalnız 200 kayıt. Bir
film 2 GB, bir PDF 2 MB → o 200 kaydın tamamı video oluyor. Bellek analizinde
"Belgeler" çubuğuna dokunmak bu listeyi *süzüyordu*, yani boş ekran veriyordu.
- **Çözüm — `StorageIndex.largestByCategory`:** aynı tek geçişli yürüyüşte
  kategori başına ayrı bir `_TopN` (200) toplanıyor. Kategori süzgeci artık
  genel listeyi daraltmıyor, **kendi listesini açıyor** (`largestOf`).
- Ekrana açık **kapsam çipleri** eklendi ("Tümü" + türler). Kullanıcı "direkt
  videolar seçili geliyor" demişti; aslında süzgeç kapalıydı — genel en
  büyükler gerçekten hep videoydu. Görünmeyen durumu tartışmak yerine
  görünür kılmak doğru çözümdü: "Tümü" çipi ilk açılışta seçili duruyor.
- `_refreshAlive` artık **her** listeyi buduyor; yalnız görüneni budasaydı
  silinen dosya kapsam değişince geri gelirdi.
- Kapsam çipi `c.label` yerine `context.t(c.labelKey)` kullanıyor: apk
  kategorisinin sabit adı "Uygulamalar", çeviri anahtarı "Kurulum dosyaları"
  — aynı ekranda iki farklı ad görünüyordu.

### B) "Son 6 ayda açılanlar" süzgeçleri — İKİ ayrı kök neden
1. **atime arama dizininde KAYBOLUYORDU.** `encodeIndexRow` dört alan
   yazıyordu (yol, boyut, mtime, klasör mü); dizinden kurulan her girdinin
   `accessedMs`'i 0 oluyor, `lastTouchedMs` sessizce mtime'a düşüyordu. Yani
   kategori ekranlarındaki "6 aydır açılmamış" çipi aslında "6 aydır
   DEĞİŞTİRİLMEMİŞ" demekti. Beşinci alan eklendi; **dört alanlı eski
   satırlar okunmaya devam ediyor** (dizin yeniden taranınca tamamlanır).
2. **Uygulamanın kendi açılış kaydı hiç sayılmıyordu.** Android'de çoğu
   bağlama `relatime`/`noatime` → atime yok. Kullanıcının dün bu uygulamada
   açtığı film hâlâ "açılmamış" sayılıyordu. `FmFilter.lastSeenMs` artık
   atime ile `OpenHistory` kaydının **en yenisini** alıyor (`openedAtOf`
   çözücüsü, `tagsOf` deseniyle aynı). Kayıt yokluğu "açılmadı" demek
   olmadığı için atime'ın yerini almıyor, onu tamamlıyor.
- **Eksik olan üçüncü şey:** "açılmamışlar" vardı, **"açılanlar" hiç yoktu**.
  `openedWithinDays` eklendi; ikisi karşıt olduğu için biri kurulunca diğeri
  siliniyor (ikisi birlikte her zaman boş liste verirdi → "süzgeç bozuk").
- **TUZAK — süzme önbellekleri geçmişi görmüyordu.** `category_screen._sorted`
  ve `FmQuickFilters` anahtarları listeye+süzgece bakıyor; geçmiş ekran
  çizildikten SONRA diskten geliyor. `OpenHistory.revision` sayacı anahtara
  eklendi, yoksa çip yüklenmemiş (eksik) sayısında donup kalıyordu.

### C) Çip sayıları başka bir soruyu yanıtlıyordu
`FmQuickFilters` her çipin sayısını **ham** listeden hesaplıyordu: WhatsApp
çipi zaten seçiliyken "Büyük dosyalar · 312" yazan çipe dokununca 4 dosya
çıkıyordu. Artık her sayı "**dokunursam kaç dosya kalır**"ın karşılığı (çip
başına bir geçiş). Maliyeti karşılamak için widget `Stateful` oldu ve sayım
`(liste, süzgeç imzası, geçmiş sürümü)` anahtarıyla önbelleklendi — 20 bin
dosyada her karede yeniden saymak ekranı kastırırdı.

### D) Üst filtre alanı sayfayı daraltıyordu
Kategori ekranında ALT ALTA iki çip satırı vardı (hızlı süzgeçler 44 dp +
belge türleri 48 dp). Belge türü çipleri `FmQuickFilters.extraChips` ile aynı
yatay satıra alındı → listeye 48 dp geri verildi.

### E) Son açılanlar / yeni dosyalar
- **Hız:** "Son açılanlar" her yol için ana izlekte `existsSync` + `statSync`
  çağırıyordu. `FsScan.statPaths` (izolatta, sıra korunur) eklendi;
  `OpenHistory.pathsByRecency()` diske hiç dokunmuyor.
- **Eksiksizlik:** "Yeni dosyalar" pano önbelleğinin 300 kaydında kesiliyordu;
  `loadAll` (tüm kategoriler = `MediaLibrary.categoryFiles(null)`) eklendi.
- **Erişilebilirlik:** "Son açılanlar" araçlar satırındaki 12 küçük simgenin
  arasından büyük kutulara terfi etti (çöp kutusu/Drive ile aynı hikâye).
- Arama `toLowerCase()` yerine `turkishFold` kullanıyor ("sarki" → "Şarkı").

### F) Video küçük resmindeki oynat rozeti
Ortadaki %42'lik daire karenin tam anlamlı yerini kapatıyordu ("görüntüyü
bozuyor"). Rozet köşeye alındı ve %18'e indi (12–28 dp arası kelepçeli),
gölgeyle açık zeminde de görünür. `PositionedDirectional` → Arapça arayüzde
karşı köşeye geçiyor.

### G) Altyazı — `services/fm/subtitles.dart` (saf Dart, testli)
`.srt` / `.vtt` / `.ass` / `.ssa` okunuyor; film dosyasının yanındaki ve
`Subs/` altındaki dosyalar kendiliğinden bulunuyor, arayüz diline uyan varsa
o açılıyor.
- **KARAR — motorun `setClosedCaptionFile`'ı DEĞİL, kendi katmanımız.**
  Gecikme ayarı ve punto denetimi o API'de yok, oysa indirilen altyazının
  sesle tutmaması en sık karşılaşılan sorun. Zamanlamayı zaten biz yapıyorsak
  çizmek ek maliyet değil. Aktif satır **ikili aramayla** bulunuyor (2000
  satırlık bir filmde saniyede iki kez çalışıyor).
- **TUZAK — Türkçe altyazıların çoğu UTF-8 DEĞİL.** `utf8.decode(
  allowMalformed: true)` onları "Ã§ok gÃ¼zel"e çeviriyordu. Sıra: BOM → KATI
  UTF-8 → Windows-1254. Katı çözmenin patlaması burada **bilgidir**.
- **TUZAK — ASS metin alanı virgül içerebilir** (`Dialogue: …,Virgül, içeren
  metin`); alan sırası `Format:` satırından okunuyor, sabit 9 varsayılmıyor
  (SSA v4'te alan sayısı farklı).
- **TUZAK — SubRip bloklarının arasında boş satır olmayabiliyor**; sonraki
  bloğun numarası metnin son satırı gibi görünüyordu.
- `.sub` bilerek DESTEKLENMİYOR: MicroDVD (kare numaralı, fps bilinmeden
  zamana çevrilemez) ya da VobSub (ikili + ayrı `.idx`). Yarım destek
  vermektense listelememek dürüst.

### H) Uygulama simgesi
`tool/gen_icon.py`: adaptive ön-plan 0.62 → **0.93** (tam +%50). Üst sınır
adaptive **güvenli alan**: 1024'lük tuvalde maskenin her cihazda gösterdiği
bölge ortadaki %66 (676 px). 0.93'te sayfa 532 × 656 px — güvenli alanın 22 px
altında, yani hiçbir maske kesmiyor. Düz `icon.png` (API 23-25) 1.0 → 1.30;
oradaki sınır maske değil **gölgenin sığması** (kayma 16 + bulanıklık 22,
ölçekle birlikte büyüyor).

**Doğrulama:** Flutter 3.29.3 (CI ile aynı) — `analyze lib` sıfır sorun,
**1577 test yeşil** (26 yeni: altyazı ayrıştırıcısı, çip sayıları, kategori
başına en büyükler, dizin satırında atime, karşıt süzgeçler).

## 2026-08-09 (2) — Üç uygulama tek simge dili

Kullanıcı: *"3 uygulamanın simgelerini aynı dile getirelim; dosya okumanın
boyutu güzel, ezan vaktinin çerçeve rengi güzel."* Dosya Okuyucu · Notlar ·
Ezan Vakti aynı ana ekranda duruyor, üçü üç ayrı dil konuşuyordu (sıcak kağıt
gradyanı + gölge / düz krem / beyaz).

### Ortak dilin dört kuralı (üç depoda da aynı)
1. **Zemin düz beyaz** `#FFFFFF` — gradyan, gölge, doku yok. (Ezan Vakti'nden.)
2. **İşaret tek renk dolu silüet**, ayrıntılar zeminden OYUK — ikinci bir
   renk eklenmiyor.
3. **İşaretin uzun kenarı 66dp / 108dp tuval.** Kare/dairesel işaretler
   keyline kuralıyla ×0,95 (Ezan Vakti'nin hilali → 62,7dp): aynı ölçüde
   basılan kare bir işaret dar-uzun olandan gözle daha İRİ görünüyor.
4. İşaretin sınır kutusu tuvalin **merkezine** oturur.

Karşılıkları: burada `tool/gen_icon.py`, Notlar'da `assets/icon/src/*.svg`,
Ezan Vakti'nde `res/drawable/ic_launcher_*.xml`.

### KÖK NEDEN — 69dp yanlıştı, "güvenli alan" kare sanılmıştı
Bir önceki tur (§H) ön-planı 0,93'e çıkarırken güvenli alanı **kare** varsaydı:
"sayfa 656 px, 676 px'lik alanın altında, hiçbir maske kesmiyor". Maskelerin
hepsi kare DEĞİL. Ölçüldü (`maskecheck`, piksel piksel maske sınaması):
69dp'lik sayfa MIUI'nin **squircle**'ında yüzeyin %1,6'sından, Pixel'in
**dairesinde** %8,5'inden kırpılıyordu. Eski tasarımda zemin tuvali baştan
başa doldurduğu için bu görünmüyordu; işaret tek başına kalınca kırpılma
**düz bir kesik** gibi ortaya çıktı.
- Sayfa oranıyla (286:352) squircle'a sığan en büyük ölçü **67,1dp** (köşe
  yarıçapı 30 → **70** yapıldıktan sonra; yuvarlatma köşeleri içeri çekiyor ve
  2,4dp daha büyük sayfaya izin veriyor). **66** seçildi, 1,1dp pay kalsın.
- **Daire maskesi bilerek karşılanmadı:** sığması için 59,6dp'ye inmek, yani
  kullanıcının "boyutu güzel" dediği simgenin %14 küçüğüne dönmek gerekirdi.
  Hedef cihaz MIUI ve eski simge de aynı davranıştaydı.

### Sayfa beyazdan MAVİYE döndü — mecburiyet, tercih değil
Zemin beyaz olunca `Paper.page` (#FBF8F1) beyaz üstünde beyaz kalıyordu.
Silüet tersine çevrildi: kütle `Paper.accent` (#2E5AA8), sırt bandı onun
koyusu (#1E3B70), satırlar zeminle oyuk. Gölge ve kenarlık silindi (1. kural).
Yan fayda: Notlar'ın belgesiyle aynı boyda ama farklı renk + sırt bandı, Ezan
Vakti'nin hilalinden hem renk hem biçimle ayrılıyor — üçü 48dp'de ayırt
edilebiliyor (ölçüldü, ön izleme çekildi).

`FG_SCALE` ve `ICON_SCALE` artık elle yazılmıyor, `ISARET_DP`/`ESKI_ORAN`'dan
TÜRETİLİYOR — ortak dilin sayısı değişirse tek yerden değişsin.

**Doğrulama:** ikonlar üretildi, üç maskede de piksel piksel sınandı
(`kare`/`squircle` TAM, `daire` bilinen ödünç). Kod değişmedi; APK CI'da.

## 2026-08-09 — Galeri üst alanı kompakt · Ayarlar sıfırdan yeniden tasarlandı
Kullanıcı iki madde verdi (ekran görüntüsüyle): *"1- bu görüntüler ve
videolardaki işaretli üst alan çok yer kaplıyor kompaktlaşmalı. 2- ayarlar
kısmımız çok karıştı her yer her yerde tamamen 0 dan tasarlanmalı ve
yerleştirilmeli"*.

### A) Süzgeç alanı: dört satır → TEK 38 dp'lik şerit
**Kök neden:** Fotoğraflar/Videolar ekranında üst üste dört ayrı satır vardı —
gün/ay/yıl ölçeği (48), kaynak çipleri (48), hızlı süzgeçler (44), "N kopya
gizlendi" şeridi (48) — toplam ~180 dp. 7559 dosyalık galeride ekranın üçte
biri süzgeçti.
- Yeni `FmFilterBar` + `FmChip` + `FmPill` (`fm_quick_filters.dart`): sabit
  `kFmFilterBarHeight = 38`, yatay kaydırmalı TEK satır. `FmQuickFilters`
  artık `leading` / `trailing` alıyor, ekranlar kendi çiplerini AYNI şeride
  katıyor (kategori ekranındaki belge türü çipleri de öyle).
- Gün/Ay/Yıl üç ayrı çip değil, tek pil içinde üç bölme (üçü de görünür kalır
  — menüye saklanan ölçek bulunmuyor).
- Kopya uyarısı çipe indi ("25 kopya gizli"), Göster/Temizle bir menüde.
  **Şeridin EN BAŞINDA**: satır kaydırmalı, sona konsa ekran dışında kalır ve
  "dosyam kayboldu" hatasını önlemesi gereken bilgi görünmezdi.
- **TUZAK:** `PopupMenuButton`ın çocuğu `FilterChip` olamaz — çipin kendi jest
  tanıyıcısı dokunuşu yutuyor, menü hiç açılmıyor. Bunun için görünüşü çipe eş
  ama dokunmayı yutmayan `FmPill` yazıldı.
- **TUZAK:** yatay `ListView` tembel — ekran dışındaki çip HİÇ kurulmuyor, test
  `find.text('Kamera')` ile onu bulamıyor. Uzun uyarı metni sağdaki kaynak
  çiplerini dışarı itiyordu → kısa biçim (`ph.hidden_dupes_short`) eklendi.
- Regresyon bekçisi: `fm_photos_screen_test` → "üst süzgeç alanı TEK ve kompakt
  bir şerittir" (şerit sayısı, sabit yükseklik, ızgaranın şeride uzaklığı).

### B) Ayarlar: iki ekran → tek ekran, sekiz kategori, satır düzeyinde arama
**Kök neden:** ayarlar `SettingsScreen` (tema, dil, Gemini, hesap, pil) ve
`FmSettingsScreen` (yerleşim, küçük resim, çöp, izin, dizin) arasında
bölünmüştü; ikisi birbirine köprü veriyor, "Görünüm" başlığı iki ekranda iki
farklı şey anlatıyordu. **Her iki ekranda da arama YALNIZ bölüm başlığına
bakıyordu:** "küçük resim" yazan kullanıcı sıfır sonuç alıyordu, çünkü o metin
bir bölüm değil bir satırdı.
- `FmSettingsScreen` **silindi**. Tek giriş: `SettingsScreen`. Pano ve çöp
  ekranındaki düğmeler oraya bakıyor; çöp ekranı `openSettingsCategory(
  context, 'trash')` ile doğrudan ilgili sayfayı açıyor.
- Yeni bildirimsel katalog `lib/screens/settings/settings_catalog.dart`:
  `SettingsCategory` → `SettingsSection` → `SettingRow` (sabit `id`, çeviri
  anahtarı, eşanlam anahtarları, denetimi kuran `builder`). Bir ayarın nerede
  yaşadığı tek satırda görünüyor; yeni ayar "hangi ekrana" değil "hangi
  kategoriye" sorusunu sorduruyor.
- Sekiz kategori: Görünüm ve dil · Dosya listeleri · Yapay zekâ · Hesap ·
  Gizlilik ve izinler · Silme ve çöp kutusu · Pil, hız ve bakım · Hakkında.
  Ana ekran kart listesi; **kartta mevcut değer** yazıyor ("Sistem · Sistem",
  "Liste · Tarih ↓") — kategoriyi açmadan ne ayarlı olduğu görünüyor.
- Arama kutusu düğme arkasında DEĞİL, hep açık; eşleşen ayarın **kendisi**
  kendi denetimiyle listeleniyor → sonuçtaki anahtar oracıkta çalışıyor.
- Satır dili üçe indirildi: `SettingTile` (değeri olan satır) · `SettingSwitch`
  · `SettingChoice` (2-4 seçenek). Eskiden beş farklı satır tipi vardı.
- **TUZAK:** `const` bir `SettingRow` listesi kurmak için `builder`ların ÜST
  DÜZEY işlev olması gerekiyor (kapanış/lambda `const` olamaz) — katalog
  dosyasının sonundaki tek satırlık `_xTile` işlevleri bunun için.
- **TUZAK (test):** ayar satırları `AppState.init()` çağrılmadan pump edilirse
  bir anahtara dokunma `LateInitializationError` atıyor; `tester.runAsync(
  state.init)` şart (HAFIZA 2026-07-25 §F ile aynı ders).

**Doğrulama:** Flutter 3.29.3 (CI ile aynı) — `flutter analyze` lib'de 0 sorun,
**1580 test yeşil** (l10n tablo ve "sabit Türkçe metin yok" bekçileri dahil).
`graphify update .` bu bulut oturumunda çalıştırılamadı (araç kurulu değil) —
yerelde çalıştırılmalı.

## 2026-08-10 — AI ile tüm dosya analizi + "Şuradan aç" listesinde görünme
Kullanıcı iki şey istedi: **(1)** ekran görüntüsüyle *"pull burada ki listede
bizim adımız yok"* — Android dosya seçicisinin kaynak çekmecesi; **(2)** *"ai
ile tüm dosya analizi… bana sorular sor planlayalım"*. Planlama turunda yedi
soru soruldu; kararlar aşağıda ve kodun tepesindeki notlarda.

### A) Planlama turunun kararları (kullanıcının seçtikleri)
- **Kapsam:** arka planda tüm cihaz indeksi (yerel çıkarım + AI kayıt).
- **Gizlilik:** buluta yalnız **meta + ilk N KB metin** (varsayılan 6 KB).
- **Çıktı:** dördü birden — dosya sohbeti, etiket/önem, ad+klasör önerisi, rapor.
- **Maliyet:** kullanıcının kendi Gemini anahtarı; ücretsiz kotayı korumak bizim işimiz.
- **Yer:** panoda AI kartı → tek merkez (`AiHubScreen`).
- **Tetik:** **elle başlatılır** (otomatik/şarj tetiklemesi YOK).
- **Kullanıcının eklediği şart:** *"kapsama girmeyecek klasörleri ve filtreleri
  (mesela kamera klasörü) seçilebilmeli, kameram ile çektiğim fotoğraflara
  erişmesini istemiyorum."*

### B) Kapsam denetimi indeksin TEMELİ (sonradan takılan süzgeç değil)
`lib/services/fm/ai_scope.dart` üç katman: sabit dışlamalar (`Android/data`,
`Android/obb`, uygulamanın çöp kutusu, önbellek/küçük resim klasörleri) ·
PIN'li klasörler (`FolderLock`) · kullanıcı seçimi. **İlk kurulumda
`DCIM/Camera` kapalı gelir** ve bu bir kez tohumlanır (`ai_scope_seeded`) —
kullanıcı kamerayı kapsama alırsa karar geri alınmaz.
- **KARAR:** kapsam daraltılınca o klasörün ESKİ analiz kayıtları da silinir
  (`AiIndex.dropOutOfScope`). Aksi hâlde "artık bakma" denen klasör sohbet
  yanıtlarında ve raporda görünmeye devam ederdi; ayarın anlamı kalmazdı.
- **KARAR:** görsellerin kendisi varsayılan olarak buluta **gitmez**; görselden
  metin cihaz-içi OCR ile okunur, yalnız o metin (ve "metin gönder" açıksa)
  gider. `sendImages` ayrı ve varsayılan kapalı bir anahtardır.
- **Dürüst sınır (kullanıcıya da böyle söylendi):** bu ayarlar AI hattını
  kapatır — uygulamanın kendi dosya gezgini/araması (kullanıcının kendi
  cihazında, ağa çıkmadan) o klasörleri listelemeye devam eder.

### C) Kuyruk: ücretsiz kotanın içinde kalma mühendisliği
`ai_analyzer.dart` — dosya başına bir istek DEĞİL, **6'lı grup** (ücretsiz
kotada sınır dakikadaki istek sayısı; 2.000 dosya tek tek sorulursa ilk 15
dosyada duvara çarpılır). İstekler arası 4 sn nefes payı, 429/5xx'te üstel geri
çekilme (8→120 sn), günlük dosya bütçesi (varsayılan 400), duraklat/durdur.
Her grup sonunda sonuç diske yazılır → yarıda kesilme kayıp değil, artımlı
devam. Anahtar yoksa **yerel kip**: `classifyDocumentText` ile tür/önem, özet
üretilmez.
- **TUZAK/DÜZELTME:** `GeminiException`a `statusCode` eklendi. Hata metninden
  "(429)" aramak (ilk taslak) çeviri/biçim değişince sessizce bozulurdu;
  "geçici mi kalıcı mı" kararı artık koda dayanıyor.

### D) Soru-cevap: maliyeti SABİT tutan iki aşama
`ai_ask.dart` — soru sözcükleri indekste yerel elenir (ücretsiz), yalnız en iyi
30 kayıt modele gider. Telefonda 500 dosya da olsa 50.000 dosya da olsa soru
başına maliyet aynı. Cevapla birlikte **kaynak dosyalar** döner (dokununca
açılır): kaynaksız AI cevabı dosya yöneticisinde doğrulanamaz, yanlışsa fark
edilmez.
- **TUZAK (test yakaladı):** tam sözcük eşleşmesi Türkçede çalışmıyor —
  "faturalarım nerede" sorusu "elektrik-faturasi.pdf" ile eşleşmiyordu. Çözüm:
  eşleşme sözcüğün **ilk beş harfiyle** (`_stem`). Aday seçimi olduğu için
  yanlış pozitif zararsız, son kararı model veriyor.

### E) "Şuradan aç" çekmecesi = DocumentsProvider
Manifestteki VIEW/SEND filtreleri "Birlikte aç" ve "Paylaş" menülerine sokar;
seçicinin sol çekmecesi (Son / İndirilenler / Dosya Yöneticisi / Drive…)
**yalnız `DocumentsProvider` bildiren** uygulamaları listeler. `ci/
DosyaProvider.kt` eklendi (kökler: dahili + Android 11+ takılabilir birimler;
listeleme, açma, arama, oluştur/sil/adlandır, küçük resim), manifeste
`<provider … android:permission="MANAGE_DOCUMENTS">` ve iş akışına kopyalama
adımı. Belge kimliği = mutlak yol (AOSP `ExternalStorageProvider` deseni).
- **Not:** izin verilmemişse kök yine listelenir ama içi boş görünür — seçicide
  hiç görünmemek asıl şikâyetin ta kendisiydi.

### F) Başarım pürüzleri (yazarken düzeltildi)
- Liste satırında `FsEntry.ofPath` = satır başına `existsSync/statSync` → ana
  izlekte disk G/Ç. Girdi artık kayıttan kuruluyor, diske dokunulmuyor.
- Panodaki kart "bekleyen öneri" sayısını her çizimde tüm indeksi tarayarak
  buluyordu → `AiIndex.suggestionCount` önbelleğe alındı (yalnız indeks
  değişince sayılır).

**Doğrulama:** Linux bulut oturumunda Flutter 3.29.3 (CI ile aynı) —
`flutter analyze` 0 hata/uyarı, tüm test takımı yeşil; yeni 28 test
(`ai_scope_test`, `ai_index_test`) kamera dışlamasını, kapsam daraldığında
kaydın silinmesini, öneri güvenliğini (uzantı korunur, klasör ayıracı
temizlenir) ve soru elemesini kilitliyor. **APK yalnız CI'da doğrulanır.**
`graphify update .` bu bulut oturumunda çalıştırılamadı (araç kurulu değil).

## 2026-08-10 (2. tur) — Seçicideki "ok" ve kesintisiz AI (havuz)
Aynı gün iki kullanıcı bulgusu daha:

### G) "Biz çıkıyoruz ama arayüzümüze yönlendiren işaret çıkmıyor"
Belge seçicisinin çekmecesinde **iki ayrı satır türü** var ve bu ayrım
projede bilinmiyordu:
- **Kök satırı** — `DocumentsProvider`dan gelir, seçicinin KENDİ arayüzünde
  gezilir, oku yoktur. (Bu turun ilk parçasında kazanıldı: `DosyaProvider`.)
- **Uygulama satırı** — `ACTION_GET_CONTENT` karşılayan uygulamalar; yanında
  "uygulamada aç" oku vardır ve dokununca o uygulamanın KENDİ ekranı açılır
  (Drive, MIUI Dosya Yöneticisi). Kullanıcının aradığı işaret buydu.

Eklendi: `ci/PickerActivity.kt` + manifestte GET_CONTENT filtresi +
`lib/screens/fm/pick_file_screen.dart` (sade seçim ekranı) +
`lib/services/fm/picker_bridge.dart`.
- **TUZAK (kritik):** filtre `MainActivity`'ye KONULAMAZ — o `singleTask` ve
  Android'de singleTask bir aktivite **sonuç döndüremez**; çağıran anında
  `RESULT_CANCELED` alır. Listede görünüp hiçbir zaman dosya veremeyen bir
  satır çıkardı. Bu yüzden ayrı `PickerActivity` (+ `excludeFromRecents`).
- Teslim yolu: seçilen dosya kendi sağlayıcımızın `content://` adresine
  çevrilip `FLAG_GRANT_READ_URI_PERMISSION` ile döndürülüyor. Sağlayıcı
  `grantUriPermissions="true"` bildirdiği için bu, `MANAGE_DOCUMENTS`
  korumasına rağmen YALNIZ o adres için geçici okuma izni veriyor — dosya
  kopyalanmıyor, depolamamız çağırana açılmıyor.
- Flutter tarafı `PickerActivity`nin verdiği `/picker` başlangıç yoluyla
  ayrılıyor; seçici kipinde iş kuyruğu/bildirim köprüsü **başlatılmıyor**
  (çağıran uygulama beklerken saniyeler süren açılış + istenmeyen yan etki).
- İstenen türe uymayan dosya listelenmiyor; bilinmeyen uzantı **kategori
  ailesine** düşüyor (`image/*` isteyen bir uygulamada `.heic` görünsün diye).

### H) Kesintisiz AI: 5 anahtar × 6 model havuzu
Kullanıcı isteği: *"her modelin kotası ayrı olduğu için 6 model seçebilelim,
kotası bittikçe diğerine geçsin; 5 tane de API anahtarı alanı olsun,
1.sindeki tüm kotalar bitince diğerine geçsin — AI analiz başta olmak üzere
tüm işlerde."* → `lib/services/ai_pool.dart`.
- **Sıra: anahtar dıştan, model içten.** 1. anahtarın altı modeli tükenmeden
  2. anahtara geçilmez (kullanıcının cümlesi birebir bu).
- **Soğuma katlamalı** (1,5 dk → … → en çok 6 saat) ve **diske yazılır**:
  Gemini'nin dakikalık (RPM) ve günlük sınırını ayırt eden bir bilgi yanıtta
  gelmiyor; katlama ikisini de doğru yönetiyor. Diske yazılmazsa yeniden
  açılışta tükenmiş modele saniyeler içinde yeniden yüklenilirdi.
- **Soğuma kaydında API anahtarı AÇIK yazılmaz** — yalnız kısa özeti (KVKK/sır
  hijyeni; kayıt diske gidiyor).
- **KARAR — havuz `GeminiService`in ALT SINIFI (`PooledGemini`):** uygulamada
  12 yerde `GeminiService` kuruluyor ve bazıları onu başka nesnelere geçiriyor
  (`AiSlides.generate(gemini:)`, `ReadAloudAi.tidyOrOriginal(...)`). Ayrı bir
  tür yapılsaydı 12 çağrı + o nesnelerin imzaları değişecekti. Artık tek giriş
  noktası `AppState.gemini`; çağıran taraf havuzu bilmiyor.
- Kalıcı hatada (içerik engeli, şema) model DEĞİŞTİRİLMİYOR: aynı isteği altı
  modelde tekrarlamak altı kat gecikme ve token demek. 400/403'te ise o
  anahtarın kalan modelleri atlanıyor.
- Eski tekil `gemini_api_key`/`gemini_model` anahtarları korunuyor; listeler
  boşsa onlardan tohumlanıyor (güncelleme sonrası kullanıcı anahtarını
  yeniden girmek zorunda kalmasın).
- Ayarlar > Yapay zekâ: yedek anahtarlar, model sırası (yukarı taşı/sil) ve
  "kota durumu · sıfırla" satırı eklendi.

**Doğrulama:** Linux bulut oturumunda Flutter 3.29.3 (CI ile aynı) —
`flutter analyze` lib'de 0 sorun, **tüm test takımı yeşil**; yeni testler:
`ai_pool_test` (9 test — sıra, soğuma, geçersiz anahtar, kalıcı hata, anahtarın
gizliliği), `picker_request_test` (5 test — MIME süzgeci).

### H2) "Sadece kota değil, diğer hatalar da gözetilmeli" (aynı gün, düzeltme)
Havuzun ilk sürümü 429'u yönetiyor, gerisini ya hiç denemiyor ya da sonsuza
kadar deniyordu. Kullanıcı iki noktayı işaret etti: *"sadece kota değil diğer
hatalarda gözetilmeli"* ve *"model kaldırılmış olabilir, çalışmayabilir."*
Artık `AiPool.classify` altı sınıf üretiyor ve her birinin ayrı karşılığı var:

| Sınıf | Belirti | Davranış |
|---|---|---|
| `quota` | 429 | katlamalı soğuma → sıradaki ikili |
| `transient` | 500/502/503/504 | kısa soğuma → sıradaki ikili |
| `modelMissing` | 404 · 400 + "not found/not supported" | **12 saat** eleme, "ölü model" damgası → sıradaki MODEL |
| `auth` | 401/403 · 400 + anahtar metni | o ANAHTARIN tüm modelleri atlanır |
| `network` | kodsuz + "ağ hatası/socket/timeout" | soğutma YOK, en çok 2 deneme |
| `content` | kodsuz + engel/boş yanıt | en çok 2 model (güvenlik eşiği modele göre değişebiliyor) |

- **TUZAK — 400 iki şeyi birden anlatıyor:** Gemini hem bozuk anahtarı hem
  tanınmayan model adını 400 ile döndürüyor. Metne bakılmazsa "model
  kaldırılmış" durumunda kullanıcının SAĞLAM anahtarı yarım saat devre dışı
  kalıyordu. Sınıflandırma bu yüzden koda ek olarak mesaja da bakıyor.
- **Ağ hatasında soğutma YOK:** internet yokken 30 ikiliyi işaretlemek,
  bağlantı geri geldiğinde çalışan modelleri de dışlamak demekti.
- Havuz tükendiğinde hata metni **sebebe göre** yazılıyor: "kotalar doldu" ile
  "anahtar kabul edilmedi", "model kaldırılmış", "internet yok" ayrı cümleler.
  Kullanıcıyı yanlış yere baktırmamak için.
- Ayarlar > Model sırası: canlı model listesinde olmayan ya da 404 görmüş
  modeller kırmızı "artık kullanılamıyor" alt yazısı alıyor.

**Doğrulama:** `flutter analyze` 0 sorun, tüm takım yeşil; `ai_pool_test` 14
teste çıktı (sınıflandırma tablosu + 404/400 ayrımı + ağ sınırı dahil).

### I) CI build 277 KIRMIZI — gerçek yarış hatası (kırılgan test değil)
`fm_file_tags_test: "eşzamanlı ilk yazmalar birbirini EZMEZ"` CI'da düştü,
yerelde 5 koşuda da geçti. Sebep gerçek bir **veri kaybı** hatasıydı:
iki eşzamanlı `FileTags.add` **aynı** `file_tags.json.tmp` dosyasına yazıyor,
ikinci yazma birincinin dosyasını sıfırlıyor, sonra iki `rename` yarışıyordu.
Diskte yarım JSON kalınca bir sonraki açılışta `jsonDecode` patlıyor, `catch`
sessizce yutuyor ve **kullanıcının bütün etiketleri siliniyordu**. Testin
gördüğü "hepsi boş" tam olarak buydu.
- Çözüm: yazmalar **zincire** alındı (`_saving` future'ı). Her yazma o anki tam
  durumu serileştirdiği için sıradaki yazma en güncel hâli indiriyor.
- **Aynı desen `AiIndex`te de vardı** ve orada risk gerçekti: analiz sürerken
  kullanıcı öneri uygulayabilir (`movePath`) ya da klasörü kapsam dışına
  alabilir (`dropOutOfScope`). Aynı zincir oraya da kondu.
- Ders: "yerelde geçiyor, CI'da düşüyor" = kırılgan test DEĞİL demek zorunda
  değil; zamanlamaya bağlı gerçek hatalar tam da böyle görünüyor.

### J) AI analizi arka planda + bildirim panelinde
Kullanıcı isteği: *"ai analiz işlemi arka planda yürümeli ve bildirim panelinde
görmeliyim."* Analiz artık `JobQueue`ya iş olarak giriyor (`id: 'ai-analysis'`):
- Uzun işler kuyrukta **ön plan servisinde** koşuyor; aksi hâlde MIUI gibi pil
  yönetimleri uygulama arka plana alınır alınmaz süreci donduruyordu
  (HAFIZA 2026-07-30 ile aynı ders).
- İlerleme kalıcı bildirime yazılıyor ("AI dosya analizi · 120/500 · dosya adı");
  bildirime dokunmak **AI Merkezi**'ni açıyor (yeni `FmJobTargetKind.aiHub`).
- Bildirimden/İşlemler ekranından iptal analizi durduruyor (`handle.cancelled`
  her grupta yoklanıyor), o ana kadarki sonuçlar diskte kalıyor.
- `start()` artık **beklemiyor**: iş kuyrukta koşuyor, arayüz `progress`
  üzerinden izliyor; kullanıcı ekranı kapatıp gidebiliyor.

## 2026-08-10 (3. tur) — Kullanıcının cihaz denemesinden çıkan beş düzeltme
Build 280 telefonda denendi; beş bulgu geldi ve beşi de kapatıldı.

### K) "400'den sonra yarın devam diyor ama kotam var" → sınır kaldırıldı
Günlük dosya bütçesi (400) havuz YOKKEN konmuş bir korumaydı. Artık `AiPool`
kotayı gerçekten ölçüyor (dolan ikili soğumaya giriyor, sıradakine geçiliyor),
yani uygulamanın kendi tahmini sayacı yalnız gereksiz bir duvardı.
- Varsayılan **0 = sınırsız**. Eski kurulumdaki 400 bir kez temizleniyor
  (`ai_budget_freed`), yoksa güncelleyen kullanıcı yine duvara çarpardı.
- Ayarlarda seçenek duruyor (Sınırsız / 400 / 1000) — isteyen kendisi sınırlar.

### L) "Öneriler ekranında işlemleri yapmıyor, atlıyor" (0 düzenlendi, 312 atlandı)
**Kök neden:** toplu uygulama, hedef klasörü **oluşturmuyordu**.
`FileOps.moveAll` var olmayan klasöre taşıyamayıp `succeeded: 0` dönüyor, akış
da bunu sessizce "atlandı" diye sayıyordu. Tek dosyalık öneride bu doğruydu
(`ai_actions.fileIntoSuggestedFolder` klasörü `create(recursive: true)` ile
açıyor); toplu akışa taşınırken o satır unutulmuş.
- Düzeltme: hedef klasör açılıyor **ve** hata mesajı kullanıcıya gösteriliyor.
  "312 atlandı" tek başına kullanıcıyı kör bırakıyordu; artık sebep yazıyor.

### M) AI Merkezi'nde dosya işlemleri + satır başına öneri denetimi
Kullanıcı: *"ai analizinde belgeleri silme düzenleme vs gibi işlemler de
yapılabilmeli"*. Satırlara uzun basış ve ⋮ düğmesi **uygulamanın kendi işlem
sayfasını** açıyor (`showEntryActions`: aç, paylaş, adlandır, taşı, sil,
etiketle, özellikler). Ayrı bir menü YAZILMADI — davranış her ekranda aynı
kalsın ve tek yerde bakımı sürsün. İşlem sonrası `AiIndex.pruneMissing()` ile
indeks gerçekle eşitleniyor (silinen dosya listede hayalet kalmıyor).
Önerilerde satır menüsü: **yalnız bunu uygula · öneriyi yok say · dosya
işlemleri** (`AiIndex.clearSuggestion`).

### N) Seçicide ana sayfa (ok işareti artık cihaz köküne değil bize açılıyor)
Kullanıcı: *"orada direkt cihaz hafızası menüsü açılıyor, kullanışlı değil;
bizim ana sayfamız açılıp her türlü işleme oradan yönlendirebilmeliyiz."*
`PickFileScreen` yeniden yazıldı: **arama** (arama dizininden, tüm depolama) ·
**son açılanlar** · **kategoriler** (Belgeler/Görüntüler/Videolar/Ses — istenen
türe uymayan kategori hiç gösterilmez) · **hızlı klasörler + birimler** · ve
istenirse klasör gezinme. Geri tuşu: kategori/arama → ana sayfa, klasör → üst
klasör, kök → iptal.
- Ana sayfada ve arama sonucunda satırın alt yazısı dosyanın **klasörünü**
  gösteriyor: aynı adlı iki dosyayı ayırt etmenin tek yolu bu.

**Doğrulama:** Flutter 3.29.3 — `flutter analyze` 0 sorun, tüm takım yeşil.

## 2026-08-11 — AI Merkezi revizyonu: sayı değil, EYLEM
Kullanıcı (6193 dosyalık gerçek analizden sonra): *"AI analiz ediyor ama ne işe
yarıyor, kullanıcı ne yapacak belli değil; yaptıklarının yansıması nerede belli
değil… analiz sonrası öneriler arka planda yapılmaya devam etmiyor; rapor
menüsünde etkileşim yok, silinebilir adayları göremiyorum. Büyük bir revizyon
şart."* Ekran görüntüleri üç somut hatayı da gösterdi.

### O) KÖK NEDEN — "0 dosya düzenlendi, 304 atlandı"
Hata metni açıktı: `FileSystemException: bu adda bir öğe zaten var`. Model iki
farklı dosyaya **aynı adı** öneriyor (ekranda iki satır da
`Derya_Soyalp_Is_Sozlesmesi.doc` diyordu) ya da önerilen ad klasörde zaten var.
`FileOps.rename` haklı olarak hata atıyor, toplu akış da tek hatada bütün
listeyi düşürüyordu. Artık çakışan ad `FileOps.uniquePath` ile numaralanıyor
("ad (2).doc") — kopyala/taşı akışlarının zaten kullandığı kural.
- Bir önceki turda bulunan "hedef klasör açılmıyor" hatası da bu akışta duruyor;
  ikisi birlikte "hiçbir öneri uygulanmıyor" tablosunu üretiyordu.

### P) Öneri uygulama artık ARKA PLANDA (`ai_apply.dart`)
Uygulama ön planda koşuyordu; ekran kapanınca iş duruyordu. Artık `JobQueue`ya
giriyor (`ai-suggestions`): ön plan servisi, bildirimde ilerleme, bildirimden
iptal, sonunda "kaç dosya düzenlendi / kaç atlandı" özeti.

### R) Rapor tıklanabilir oldu (`ai_buckets.dart` + `ai_files_screen.dart`)
Rapor sayı listesiydi; hiçbir sayının arkasındaki dosyalara ulaşılamıyordu.
- **Kova** kavramı: önemli · harcanabilir · düşük önemli · öneri · tür · tümü.
  Her kova bir liste ekranı açıyor; listede çoklu seçim ve **toplu işlem**
  (paylaş, taşı, sil, öneriyi uygula) var. Aynı liste (`AiFileList`) Etiketler
  ve Öneriler sekmelerinde de kullanılıyor — tek etkileşim dili.
- Raporun başına **eylem kartları** kondu: "N dosya için öneri hazır → Önerileri
  aç", "N harcanabilir dosya · X GB → Listeyi aç". "Ne yapacağım" sorusunun
  cevabı artık ekranın en üstünde, düğmesiyle birlikte.

### S) İki DÜRÜSTLÜK düzeltmesi
1. **"Silinebilir aday 5262 · 8,3 GB" yanlıştı.** Kural "önem ≤ 20" olduğu için
   kullanıcının 3419 fotoğrafı bu kovaya düşüyordu. Fotoğrafa "sil" demek bir
   dosya yöneticisinin verebileceği en tehlikeli tavsiye. Artık silme önerisi
   yalnız gerçekten harcanabilir türlere (ekran görüntüsü, geçici dosya,
   önbellek, kurulum dosyası…) veriliyor; kalan yığın **"Düşük önemli (gözden
   geçir)"** adıyla ayrı kovada. Test bu kuralı kilitliyor (`ai_buckets_test`).
2. **"fotoğraf 3419" ve "fotograf 413" ayrı satırdı.** `canonicalDocType`
   Türkçe harfleri ASCII'ye indirip eşanlamları birleştiriyor; gösterimde
   `AiBuckets.label` okunur Türkçe ad veriyor. Analiz artık kanonik türü
   **yazıyor**, yani indeks de temiz kalıyor.

### T) `asciiFold` — neden `turkishFold`dan AYRI
`turkishFold` yalnız büyük/küçük harf katlıyor ve her karakteri tek karakterde
tutuyor; belge içi aramanın eşleşme konumları buna bağlı (aksan atsaydı indeks
hizası bozulurdu). Gruplama/eşleşme anahtarı için `core/text_search.dart`e
`asciiFold` eklendi (`fotoğraf` → `fotograf`). AI sohbetinin yerel eleme
puanlaması da buna geçti: artık "sözleşme" yazan kullanıcı `sozlesme.pdf`
dosyasını gerçekten buluyor.

**Doğrulama:** Flutter 3.29.3 — `flutter analyze` 0 sorun, tüm takım yeşil;
yeni `ai_buckets_test` (12 test) silme güvenliğini ve tür tekilleştirmeyi
kilitliyor.

---

## 2026-08-17 — Excel kullanılabilirliği + pano/simge turu

Kullanıcı cihaz denemesinden gelen liste (Excel'de yedi madde, uygulama
genelinde altı madde). Kararlar ve kök nedenler:

### A) KÖK NEDEN — "çerçeveler kayboluyor, yazı tipi tutmuyor" (`xlsx_editor.dart`)
`setCell` boş bir hücre için `styleIndex: 0` (varsayılan) kayıt kuruyordu.
Dosyadaki bir tablonun boş gözüne yazınca hücre kaydı DOĞUYOR ve o kayıt
`styleAt`in satır/sütun stiline düşme yolunu kapatıyor → kenarlık siliniyor,
yazı tipi sütunun geri kalanından farklı çıkıyordu. Hem ekranda hem
kaydedilen dosyada.
- **Çözüm:** `XlsxSheet.inheritTemplateAt` — yeni hücre biçimini komşusundan
  devralır. Sıra: aynı sütunda üstteki → alttaki → aynı satırda soldaki
  (en çok 64 hücre taranır, yazma yavaşlamasın). Bulunan örnek hücre
  `styleCopies`e de yazılır, böylece KAYDETMEDE `XlsxSavePatch` aynı `s`yi
  koyuyor.
- **Sıra önemli:** `_editCells` önce `setCell`, sonra `copyCellFormat`
  çağırıyor → kullanıcının açık biçim yapıştırması devralmanın üstüne biner.
- Test: `xlsx_editor_test` → "yeni yazılan hücre biçimi komşusundan devralır"
  (3 test; biri kaydet-yeniden aç turunu kapsıyor).
- **TUZAK (test):** `excel` paketinin `Border`/`BorderStyle` adları
  `flutter/material.dart` ile çakışıyor → `import ... as xl show Border,
  BorderStyle` gerekiyor.

### B) "tik işaretine basmadan kaydolmuyor"
`_endEdit`in ilk satırı `if (!_editing) return;` idi. `_editing` yalnız
HÜCRE İÇİ düzenlemede true; formül çubuğuna yazılan metin bu yüzden sessizce
atılıyor, başka hücreye dokunmak `_syncField()` ile üstüne yazıyordu. Artık
bayraktan bağımsız: alandaki metin hücrenin değerinden farklıysa yazılır.
✓/✗ düğmeleri de yalnız onaylanmamış giriş varken çıkıyor (Excel gibi).

### C) Üst alan kompaktlaştı
- `OfficeRibbon.compact`: 84 → 68 dp (sekme 34→28, sıra 48→40).
- Formül çubuğu 50 → 38 dp; `OutlineInputBorder` kalktı (odakta beliren mavi
  hat "gereksiz ve çok dar" şikâyetinin kaynağıydı), yazarken alan üç satıra
  kadar büyüyor. Ad Kutusu artık tıklanınca "Hücreye git" açıyor.
- Şerit formül çubuğundaki çift yönlü okla kapatılabiliyor → ızgaraya +68 dp.

### D) Ölçü ve veri girişi
- Sütun/satır başlığının kenarında **sürükleme tutamağı** (18 dp, dar
  başlıkta genişliğin %45'iyle sınırlı). Diyalog uzun basışta kalıyor.
  Yatay/dikey tanıyıcılar ayrı: sütun tutamağı dikey kaydırmayı yutmuyor.
- Enter girişi yazıp ALT hücreye geçiyor **ve yazmaya devam ediyor** (klavye
  kapanmıyor) — bir sütuna arka arkaya veri girmek eskiden her satırda iki
  fazladan dokunuş istiyordu.
- Hücre 30 dp'den kısa ya da 72 dp'den darsa düzenleme hücre içinde değil
  **formül çubuğunda** açılıyor (Excel Mobile'ın davranışı): 15 puntoluk bir
  satırda hücre içi alan parmakla imleç konulamayacak kadar inceydi.

### E) Yeni dosyalar artık kaçmıyor (`fs_scan.dart` + `dashboard_screen.dart`)
Tam tarama pahalı olduğu için 12 saatte bir koşuyordu; arada eklenen dosya
panoya hiç yansımıyordu. **Sıcak klasör taraması** eklendi:
`FsScan.freshFiles` yalnız DCIM/Download/Pictures/Movies/Music/Documents/
WhatsApp ağaçlarını gezer (saniyenin altında), sonucu
`StorageIndex.mergeFresh` ile indekse katılır — hem "Yeni Dosyalar" listesine
hem kategori listelerine hem sayaçlara. Pano açılışında VE
`AppLifecycleState.resumed`da koşuyor (insanlar uygulamayı kapatmıyor,
WhatsApp'tan belge indirip geri DÖNÜYOR).
- **Çift sayma tuzağı:** aynı dosya her açılışta yeniden bulunacağı için
  `mergeFresh` bilinen yolları eler; test bunu kilitliyor (`fm_scan_test`).

### F) Pano ve simge dili
- Kategori kutularının çerçevesi ve kartı kalktı: 44 dp kutu içinde 24 dp glif
  yerine **38 dp sade glif**. Izgara **sabit 4 sütun**
  (`SliverGridDelegateWithFixedCrossAxisCount`); eski `maxCrossAxisExtent: 150`
  cihaz genişliğine göre 2-3 sütun üretiyordu, kullanıcının gördüğü düzen
  telefonuna göre değişiyordu.
- **İndirilenler** araç satırından ızgaranın İLK sırasına terfi etti.
- `FmColors.forExtension` / `forFolderName`: apk·zip·epub·font·kod·iso·
  torrent·vcf·ics kendi glifi ve rengi; bilinen klasörler (İndirilenler, DCIM,
  WhatsApp, Ekran görüntüleri…) kendi glifi. Taklit değil — Material
  ailesinden bu paletin eşlemesi.
- Liste simgesi 44 → 52 dp (`FmLayout.iconSizeFor`); `ListTile`ın 56 dp
  asgarisinin içinde kaldığı için satır uzamıyor.

### G) Aramada çoklu seçim (`search_screen.dart`)
Arama sonucu çoğu zaman "şu 40 dosyayı sil/taşı/paylaş" demek; ekran tek tek
açmaktan başkasına izin vermiyordu. Kategori/galeri ile **aynı kalıp**:
`DragSelectArea` + `FmEntryListTile` + `FmSelectionBar`, üstte sayaç ve
"tümünü seç".

### H) Kağıt teması beyazlatıldı (`theme.dart`)
Krem doygunluğu yarıya indi, basamak sırası (bg → card → band → well → rule →
edge) korundu. *Niye:* okuyucuda sarımsı zemin gözü dinlendirir ama dosya
yöneticisinde fotoğraf küçük resimlerinin ve renkli tür simgelerinin yanında
zemin "sararmış" görünüyor. `dashboard_screen`deki iki kaçak hex
(`0xFFFDFBF6`, `0xFFE6DECC`) de tokenlara bağlandı — beyazlatma onları geride
bırakıp kutuyu sarı gösteriyordu.

**Doğrulama:** Flutter 3.29.3 (CI ile aynı) — `flutter analyze` 0 sorun,
`flutter test` 1644 test yeşil (yeni: 3 biçim devralma + 3 `mergeFresh`).

---

## 2026-08-17 (ikinci tur) — cihaz denemesinden gelen yedi madde

Aynı gün, build-287 APK'sı denendikten sonra gelen ikinci liste.

### A) KÖK NEDEN — `freshFiles`in sınırı YANLIŞ kesiyordu
Sabahki turda eklenen sıcak klasör taraması `stop: () => hits.length >= limit`
ile duruyordu. Yürüyüş **dizin sırasında** ilerler, tarih sırasında değil:
7000 fotoğraflı bir DCIM'de ilk 100'de durmak "rastgele 100 dosya"yı en
yeniler sanmak demekti — kullanıcının az önce çektiği kare listeye hiç
girmeyebilirdi. ("hâlâ çok geç güncelleniyor" şikâyetinin bir parçası buydu.)
**Çözüm:** ağaç sonuna kadar gezilir, bellekte yalnız en yeni N tutulur
(`_TopN`). Test bunu kilitliyor (`fm_scan_test` → "sınır varken bile EN
YENİLER döner").

### B) `NewFilesScreen` — yeni ekran
Eskiden kutu `CategoryScreen`i `MediaLibrary.categoryFiles(null)` ile
besliyordu: **tüm depolama** (kullanıcıda 12 010 dosya), hem yavaş hem bayat.
Artık yalnız sıcak klasörler taranıyor ve **en yeni 100** gösteriliyor.
- **TUZAK — `IndexedStack` çocuğu `initState`i bir kez koşar:** alt gezinme
  çubuğunda duran ekran, sekmeye her dönüşte açılıştaki bayat listeyi
  gösterirdi. `active` bayrağı + `didUpdateWidget` + `AppLifecycleState
  .resumed` üçlüsüyle tazeleniyor (panonun `_catchUp`'ıyla aynı kalıp).
- **TUZAK — `CategoryScreen` listesini `initState`te kopyalar:** sonraki
  `widget.files` değişimlerini görmez. Taze liste gerçekten değiştiyse
  `ValueKey(_revision)` ile yeniden kuruluyor; değişmediyse anahtar SABİT
  kalıyor (yoksa her tazeleme kaydırma konumunu ve seçimi sıfırlardı).
- `CategoryScreen.replaceOnLoad`: varsayılan "yalnız daha uzunsa değiştir"
  sabit sınırlı listede taze sonucu sessizce yutuyordu.

### C) Alt gezinme: "Son belgeler" → "Yeni Dosyalar"
Kullanıcı: *"son belgeleri kaldır, yerine yeni dosyaları koy"*. Açılmış
belgeler kaybolmadı — panodaki **Son açılanlar** kutusu aynı kaydı gösteriyor.
- **DİKKAT (sessiz kayıp önlendi):** `RecentDocsScreen` yalnız listeyi değil
  **boş belge oluşturmayı** da barındırıyordu (Word/Excel/metin). Sekmeyi
  silmek onu erişilemez bırakacaktı; kimse onu kaldırmayı istemedi. Akış
  `widgets/new_document_sheet.dart`e taşındı ve panonun araç satırına
  "Yeni belge" kutusu olarak kondu. `RecentDocsScreen` (≈620 satır) silindi.

### D) AI kartı → AI sekmesinin rozeti
Kullanıcı: *"ai asistan yazısı sağ alttaki ai düğmesi alanına entegre et, ana
ekran temizlensin"*. Panodaki tam genişlikli kart kalktı. Alt çubuktaki AI
simgesi durum taşıyor: analiz sürerken ilerleme halkası, bekleyen öneri varsa
sayı rozeti, ikisi de yoksa düz simge. AI Merkezi'nin kapısı artık AI
sekmesinin üst çubuğundaki yıldız düğmesi (`chat_screen`).

### E) APK'ların kendi simgeleri (`services/fm/apk_icon.dart`)
İndirilenlerde on kurulum dosyası aynı yeşil Android glifiyle görünüyordu.
- **Niye `installed_apps` paketi DEĞİL:** o paket **kurulu** uygulamaların
  simgesini paket adından verir; buradaki dosyaların çoğu kurulu değil ve
  paket adını öğrenmek için zaten APK'yı açmak gerekirdi.
- **Nasıl:** APK bir zip; `res/mipmap-*/ic_launcher.png` yol adına göre
  puanlanıp (ad × yoğunluk) en keskin aday seçiliyor. İkili `AndroidManifest
  .xml` ayrıştırıcısı YAZILMADI — `mipmap-anydpi-v26/ic_launcher.xml`
  (uyarlanabilir simge) atlanıyor, yanında neredeyse hep bir PNG bulunuyor.
- `InputFileStream` (archive_io): 95 MB'lık bir APK'yı `readAsBytes` ile
  açmak düşük bellekli cihazı öldürürdü; yalnız zip dizini ve seçilen girdi
  okunuyor. Ayrıştırma izolatta, sonuç diskte önbellekte (PDF/video küçük
  resimleriyle aynı `ThumbnailCache.cacheName` kuralı), simgesi bulunamayan
  dosya işaretlenip bir daha denenmiyor.

### F) Ölçüler ve varsayılanlar
- Liste simgesi 52 → **68** dp (kullanıcı: *"olabildiğince büyüt"*, *"yüzde 30
  büyüt"*). `ListTile`ın 56 dp asgarisi aşılıyor, satır uzuyor — bilinçli takas.
- Pano kutusu glifi 38 → 46, araç glifi 30 → 34.
- **İndirilenler varsayılan sıralaması "en eski" → "en yeni"**. Ekran "yer aç"
  gözüyle tasarlanmıştı (silinecek adaylar önce); oysa insanlar buraya çoğu
  zaman **az önce indirdikleri** dosyayı açmaya geliyor.
- "Yeni Dosyalar" simgesi `fiber_new` idi — Material onu "NEW" YAZISI olarak
  çiziyor, dört sütunlu ızgarada harf yığını gibi duruyordu. `move_to_inbox`.

**Doğrulama:** Flutter 3.29.3 (CI ile aynı) — `flutter analyze` 0 sorun,
`flutter test` 1658 test yeşil (yeni: 8 APK simgesi + 3 `freshFiles`).

### G) Sıcak klasör yakalaması KISITLANDI (aynı gün, ikinci tur sonrası)
`AppLifecycleState.resumed` sanılandan çok daha sık geliyor: izin penceresi,
paylaşım sayfası, ekranın kapanıp açılması, bildirim panelinin çekilmesi.
`freshFiles` artık ağacı **sonuna kadar** yürüdüğü için (bkz. A) her resume'da
DCIM + WhatsApp = on binlerce `stat` demekti — kullanıcının *"performans sorunu
yaşamadan yapmalısın"* şartını çiğnerdi. Hem panoda hem `NewFilesScreen`de
20 saniyelik kısıtlama var. **Aşağı çekerek yenileme etkilenmiyor**
(`CategoryScreen` doğrudan `_scan`ı çağırıyor) — o kullanıcının açık isteği.

### H) TUZAK — CI kırmızısı her zaman KOD değildir
build-288: APK derlendi ve imzalandı, **GitHub Release adımı** 503 aldı
("No server is currently available"), üç denemede de. Yani hata GitHub
tarafındaydı, üründe değil. Bu oturumda `rerun-failed-jobs` ve
`workflow_dispatch` için yetki YOK (403 "Resource not accessible by
integration") → yeniden derleme ancak main'e yeni bir push ile tetiklenebiliyor.
`paths-ignore: '**.md'` yüzünden yalnız HAFIZA'ya yazmak da tetiklemiyor.
