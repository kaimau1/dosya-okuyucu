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
