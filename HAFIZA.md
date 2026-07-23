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
