# Dosya Okuyucu — Proje Hafızası

> Kararlar, *niye*'leri, denenip reddedilen yollar ve açık durum burada.
> **Append-only:** eski maddeler silinmez, geçersizse "→ güncellendi/iptal" notu düşülür.
> Kod yapısı buraya yazılmaz (bkz. CLAUDE.md §Hafıza haritası).
> KVKK: hasta verisi / TC / ölçüm / token bu dosyaya YAZILMAZ.
>
> **Dizin + arşiv (2026-10-21, Faz 0 H1):** bu dosya yalnız dizin (kararlar, tuzaklar,
> açık durum). Tarihli tur kayıtları kelimesi kelimesine `docs/hafiza/YYYY-MM.md`
> arşivlerinde — gerektiğinde ara (`grep -rn "<konu>" docs/hafiza`). Yeni tarihli kayıt
> bu dosyanın SONUNA yazılır; ~600 satırı geçince `python tool/hafiza_arsivle.py`.

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


## 2026-10-21 (5) — Faz 0 hijyen · P10 · Faz 7b (Flutter 3.44.6) · Faz 10 (medya)

Yerel Windows oturumu (Flutter 3.44.6), telefon USB'de (Xiaomi 13T, Android 14+).

### Faz 0
- HAFIZA → 330 satırlık dizin + `docs/hafiza/YYYY-MM.md` (satır kümesi
  karşılaştırmasıyla birebir); `tool/hafiza_arsivle.py` tekrar kullanılabilir.
  37 cihaz maddesi KALANLAR → `docs/CIHAZ_TESTI.md`. README yalnız Android.
- **Uzak dal silme ve graphify'ı GitHub'dan yükseltme izin sınıflandırıcısınca
  ENGELLENDİ** (git destructive / untrusted code). 42 dal main'e squash'la
  girmiş (cherry + konu eşleşmesiyle denetlendi) — kullanıcı elle silebilir.

### Faz 7b — Flutter 3.29.3 → 3.44.6 (CI varsayılanı da 3.44.6)
- **TUZAK — push kancası Windows'ta HİÇ geçemiyordu:** `hooks/pre-push` tam
  `flutter test` koşuyor; yerel 3.44'te iki DERLEME hatası (`RepeatMode` adı
  Flutter'ın `repeating_animation_builder`ıyla çakışıyor; `CupertinoPageTransitionsBuilder`
  artık material'dan dışa verilmiyor) + 8 test `/` ile yol bekliyordu. Bulut
  oturumları 3.29/Linux'ta yazdığı için görünmüyordu. Düzeltildi: `AudioRepeatMode`,
  iOS geçişleri silindi (K10), testler `p.join/normalize`, M3U `path.posix`.
- Kullanımdan kaldırmalar: Radio→`RadioGroup` (5 dosya), Dropdown `initialValue`
  (model sonradan değişen yerde `ValueKey`), Matrix4 `*ByDouble`, `fontWeight.value`,
  tarama `onReorderItem`. Pano/sekme sıralaması `onReorder`da kaldı (dizin anlamı
  değişiyor — ignore + KALANLAR).
- **TUZAK — 3.44 assert:** boyalı `DecoratedBox` içindeki `ListTile` hata.
  `SettingsGroup` kartı `Material` oldu (tek yerden, 11 test).
- **TUZAK — kilitsiz çözüm:** `pubspec.lock` gitignore'da; 3.44'ün Dart'ı
  `receive_sharing_intent` 1.9.0'ı çözüyor, o da compileSdk 37 istiyor (AGP 9.0.1
  en çok 36). **1.8.1'e sabitlendi.**
- AGP 9 yamaları (`ci/prepare_android.sh` 6b): bütün eklentiler compileSdk 36
  (`cunning_document_scanner` 33 ile geliyordu; blok `evaluationDependsOn`dan ÖNCE),
  `kotlin.jvm.target.validation.mode=warning` (1.8.1'in Java 11/Kotlin 21 hedefi).
- Yerel APK reçetesi: temiz kopya + `bash ci/prepare_android.sh` + `flutter build apk`.
  **Git Bash'te `python3` yok** (Windows mağaza takma adı exit 49) → `python`a
  yönlendiren betik PATH'e; PATH'e `C:/` DEĞİL `/c/` biçimi yazılmalı.
  **Sürüm numarası:** yerel derlemede CI'ın sıradakinden KÜÇÜK ama telefondakinden
  büyük `--build-number` (yoksa sonraki CI APK'sı "sürüm düşürme" ile kurulmaz).

### P10 (Faz 4)
- Arama ekranı açıkken dizin uzun ömürlü isolate'te (`SearchIndex.openSession`),
  ad katlamaları önceden; dosya değişince (mtime+boyut) kendiliğinden yeniden okur.

### Faz 10
- **Görsel düzenleyici** (`image_edit_screen.dart` + `services/image_edit.dart`):
  kırp (oranlı), döndür/çevir, parlaklık/kontrast/doygunluk, kalem/ok/yazı. Önizleme
  ve kayıt AYNI `paintEdits`ten (Türkçe yazı Flutter tuvalinde; `image` paketinin
  bitmap fontunda ş/ğ yok). Varsayılan kopya; HEIC/WebP → JPEG kopya. Galeride
  "Döndür" yerine "Düzenle".
  **TUZAK:** çizimde çevirme döndürmeden sonra (F·R) → çevrilmişken saat yönü
  adım TERSİNE (`rotated()`); piksel testi sabitliyor.
- **PiP:** `FloatingPlayer.kt` (671 satır) + `floating_video.dart` + yüzen servis
  + `SYSTEM_ALERT_WINDOW` silindi. Etkinlik `supportsPictureInPicture`; oynatıcı
  ekranı açıkken video oynuyorsa çıkışta kendiliğinden PiP (12+ `setAutoEnterEnabled`,
  eskisinde `onUserLeaveHint`); PiP'te yalnız video çizilir, yaşam döngüsü duraklatmaz.
- **Tek oynatma motoru:** `audioplayers` kalktı; ses de `video_player`/ExoPlayer
  (`allowBackgroundPlayback`), `AudioPlayback` içinde ince `_AudioEngine`.
- **Media3 Transformer (K2 b):** `ci/MediaTranscode.kt` (probe + start/progress/cancel),
  Gradle'a media3-transformer/effect/common **1.5.1** (video_player_android'in
  ExoPlayer'ıyla AYNI sürüm şart). FFmpeg (LGPL) + `video_compress` + lisans
  ekranındaki LGPL metni kalktı; çıktı süre doğrulaması korundu.

### 2026-10-22 — telefonda doğrulama (1.0.389, yerel derleme)
- **TUZAK — AGP 9 R8 yansımalı sınıfları kırıyor:** önce açılışta ÇÖKME (WorkManager
  Room `_Impl`), koruma kuralı eklenince SİYAH EKRAN (flutter_local_notifications Gson
  `TypeToken` "Missing type parameter" → Dart açılışı takıldı; logcat'te Dart hatası
  YOK), sonra ML Kit kayıt sınıfı. Skia ile de siyah olduğu görülünce çizim değil
  Dart/eklenti sorunu ayrıldı. **Çözüm: R8 küçültme kapalı** (`prepare_android.sh` 6c);
  kurallar `proguard-rules.pro`da duruyor. APK 57 → 63-66 MB (bütçe 80).
- Ölçümler `docs/perf/2026-10-21.md` sonunda: açılış 628 ms, boşta 0 kare, aşağı
  kaydırma p99 8,5 ms; **yukarı kaydırma p99 50 ms** (KALANLAR).
- Görsel düzenleyici telefonda: 4:3 + döndür + kalem → kopya `ad (1).jpg` 810×1080 (3:4 ✔).
- Telefon ölçüm araçları: SurfaceFlinger katman adının başında kimlik öneki var
  (`662e22f SurfaceView[...]`); `uiautomator dump` Flutter'da bayat kalabiliyor →
  dökümden önce ~2,5 sn bekle. Xiaomi'de `input` için "USB hata ayıklama (Güvenlik
  ayarları)" açık olmalı. Git Bash'te adb'ye `/sdcard` yolu için `MSYS_NO_PATHCONV=1`.
- **Sürüm numarası tuzağı:** kullanıcı arada CI nightly'yi (388) kurmuştu; yerel 380
  "sürüm düşürme" olurdu → 389 verildi. Kurmadan önce telefondaki sürüme bak.
- **TUZAK — ölçüm verisini kullanıcının ortak depolamasına koymak:** `make_test_tree.py`
  çıktısı (2.000 tek renk PNG + 5.000 txt) `/sdcard/DosyaOkuyucuOlcum`a itildi; telefonun
  galerisi ve uygulamanın Belgeler'i bunlarla doldu, kullanıcı "görüntüler bozulmuş, yüzlerce
  ölçüm dosyası" diye fark etti. Silindi + `content call --uri content://media --method
  scan_volume` + uygulamada "Yeniden tara". Bir dahaki sefere: içine `.nomedia` koy (galeri
  görmesin), ölçüm biter bitmez sil ve kullanıcıya ÖNCEDEN söyle.

## 2026-10-22 (2) — Görsel/kullanım araştırması → Faz 13–19 + bulut-önce yürütme sırası

Bulut oturumu, **kod değişikliği yok** (kullanıcı: *"bu tur kod değiştirme"*). Kullanıcı
isteği: *"faz 11, 12 ve kalanlar dışında tamamen görsele ve kullanım deneyimine yönelik
yeni fazlar; uzak ortamda yapabileceklerin en başta. Son dosyalarda PDF vs ayrı
filtreleyemiyorum; kolay biçimde ve istediğim oranda görüntü boyutlarını değiştiremiyorum."*

- **Plan:** `docs/FAZ_PLANI.md` §3.14 (bulgular G1–G21), K13–K17, Faz 13–19, **§0.1
  yürütme sırası** (☁️ bulut → 📱 tek cihaz turu = 12b → 👤 Play/Billing/RC). Faz 10'un
  kalanı **10b** (örnek medya seti, ☁️), Faz 11 → 11a ☁️ / 11b 👤, Faz 12 → 12a ☁️ /
  12b 📱 / 12c 👤. Faz 11a bilinçli olarak UX fazlarından SONRA: mağaza görselleri ve
  ilk açılış son görünümü göstersin.
- **Kök neden — "PDF'i ayrı süzemiyorum":** tür süzgeci üç ayrı yerde üç ayrı biçimde
  yazılmış (gezgin `FmTypeChips` = `FmCategory` düzeyi; kategori ekranında DocKind
  çipleri yalnız `showDocKinds` = Belgeler kutusu; arama `FmCategory` çipleri). *Yeni
  gelenler* aynı `CategoryScreen`i bayraksız açıyor; *Son açılanlar*, *İndirilenler*,
  *Önemli*, *Üretilenler*, *Çöp*, *Kasa*'da tür süzgeci hiç yok. Çözüm yönü (Faz 13):
  tek tür modeli (uzantı → üst tür + belge alt türü tek tablodan) + tek bileşen + 10 ekran.
- **Kök neden — "istediğim oranda boyutlandıramıyorum":** yüzde %10–95; serbest en×boy'da
  oran kilidi yok (ikisi yazılınca esniyor, `targetSize` custom dalı); büyütme sessizce
  kaynağa kırpılıyor; oran değiştirme/kenar boşluğu/hedef KB yok; fotoğrafa da video
  çift-sayı yuvarlaması; ayar hatırlanmıyor; WebP yazılamıyor, HEIC `image` paketiyle
  çözülemiyor; videoda Media3 `LAYOUT_STRETCH_TO_FIT` her zaman esnetiyor. **Şüphe
  (B11, doğrulanmadı):** `image` paketi EXIF yönünü uygulamadan ölçüyor → dikey
  fotoğrafta genişlik ham kenara gidebilir; Faz 10b örnek setiyle test edilecek.
- **Ölçüm (tutarlılık):** ham `Icons.*` 1.344 / `AppIcons` 93; `_outlined` 373 ·
  `_rounded` 189 · eksiz 744; sabit renk 150 + `Colors.*` 188; sabit punto 114; sabit
  süre 95; `disableAnimations` 2 yer; `meetsGuideline` testi 0; RTL'de aynalanmayan
  ~150 kullanım. Komutlar FAZ_PLANI Ek E — faz başında yeniden ölçülür.
- **Dış gerçek (web, Ek E):** Android 16'da hedef API 36 → `onBackPressed` çağrılmıyor,
  `enableOnBackInvokedCallback="false"` yalnız GEÇİCİ kaçış; sw ≥ 600 dp ekranda yön/
  boyut kısıtları yok sayılıyor (API 37'de çıkış yok, Play Ağu 2027) → geniş ekran
  düzeni artık "güzel olur" değil zorunluluk (Faz 18). Material 3 Expressive Flutter
  çekirdeğinde yok (yalnız üçüncü taraf paket) → eklenmedi.
- **KALANLAR temizliği:** "Liste simgesi 68 dp — ListTile tavanı" maddesi silindi
  (Faz 6'da `FmEntryRow` kendi `Row`umuzla kapandı, `fm_entry_tiles.dart:17-27`);
  "Flutter 3.44.9 deneme derlemesi" silindi (Faz 7b 3.44.6'ya taşıdı, uyarılar
  temizlendi). Kalan maddelere §0.1 sıra numarası yazıldı.
- **Ders:** kategori ekranı gibi ORTAK bir ekran bir bayrakla (`showDocKinds`) ek
  özellik açıyorsa, onu yeniden kullanan ekranlar (Yeni gelenler) özelliği sessizce
  kaybeder — özellik bayrağı değil, veriden türeyen davranış olmalı (Faz 13: alt tür
  çipleri listede birden çok alt tür varsa kendiliğinden çıkar).
