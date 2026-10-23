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

- **2026-10-22 (Faz 15–16; ayrıntı `docs/hafiza/2026-10.md` (6)):** yeni alt çubuk
  (`bottomNavigationBar`, seçim/dock çubuğu) `ToastAvoider` ile sarılır, yoksa iş kartı
  düğmeleri örter · degradenin `begin:/end:`i `AlignmentDirectional` OLMAZ (boyayıcıda
  `createShader` çöker) · `ScrollController.animateTo` sıfır süre kabul etmez →
  `Motion.scrollTo/toPage` · yeni ekran kodu tokenları kullanır (`design_tokens_test`
  cırcırı), fiziksel sol/sağ yazmaz (`rtl_guard_test`).
- **2026-10-22 (7):** Office Symbol/Wingdings madde imleri (U+F0B7, "§"+Wingdings) Android'de ▯ —
  Word `viewer.html` `fixSymbolFonts`, slayt `core/symbol_fonts.dart`; `viewer.html`'de charset
  YOK → betikte `\uXXXX`.
- **2026-10-22 (8):** Flutter 3.27+ derin bağlantı varsayılan açık → "Birlikte aç" `content://`
  adresini sayfa adı diye itip çökertiyordu: manifest `flutter_deeplinking_enabled=false` +
  `core/route_guard.dart`. Flutter yükseltmesinde platform varsayılanlarını da gözden geçir.

## Yol Haritası (öncelik kullanıcıyla netleşecek)

1. ~~Office ileri düzenleme: Excel formül + satır/sütun; Word biçim araç çubuğu; slayt
   çoğalt/sil/taşı~~ → **YAPILDI 2026-07-21** (bkz. Sabit Kararlar). Kalan uçlar: Word'de
   liste (madde/numara) düğmesi, slayta görsel ekleme, Excel formül sonucunu önizleme.
2. Firebase config ile gerçek senkron + Google Sign-In SHA ekleme.
3. Format dönüştürme zenginleştirme (PDF ↔ Word ↔ Slayt).
4. AI: PDF'den otomatik slayt üretimi (genişletilmiş), kaynakları bağlama alma.
5. Masaüstü (Windows/macOS/Linux) build hedefleri + iOS.



- **2026-10-22 (9) — Faz 14b/15b/17/18/19/11a(bulut)/12a + yeni istekler:**
  ÇÖKME kök nedeni: `shared_preferences_android` 2.5.x JNI kaydı SÜREÇ başına
  tek ve her motorun detach'i siliyor → `PickerActivity` kapanınca ana uygulama
  "No instance with no name has been registered" → 2.4.28'e sabit (2.4.29
  yayımlanmamış). TUZAK: temanın `focusedBorder/enabledBorder/filled`'ı
  `border: InputBorder.none` alanlara sızar (Excel hücresi mavi çerçeve) — dört
  anahtar birlikte; bekçi `bare_input_guard_test`. Yapay zekâ sesleri (Antalia,
  EMA): APK'ya 0 MB — HF Space'lerin ONNX Runtime Web dosyaları ilk kullanımda
  iner, WebView + yerel 127.0.0.1 sunucu (COOP/COEP), çıktı POST ile; ağ güvenliği
  yalnız loopback cleartext. Chromium'da doğrulandı (`tool/voice_engine_check.mjs`);
  Android WebView'da cihaz turu bekliyor. QR paylaşım ağsız (metin QR'ın içinde,
  üçüncü taraf yükleme reddedildi: gizlilik). Hata kaydı artık kayıt başına sürüm
  yazar (eski kayıtlar güncel sürüme aitmiş gibi okunuyordu).

- **2026-10-22 (10) — QR ile dosya paylaş, İndirilenlerde göster, R8 geri açıldı, cihaz ölçümleri:**
  QR paylaşım artık DOSYA (metin QR'ı alt yol): gönderen ekran açıkken `QrShareServer`
  (dart:io, jetonlu `/q/<jeton>/`), karşı tarafın kamerası tarayıcıda İndir sayfası açar;
  Dosya Okuyucu'lu alıcı Al → "QR kodu tara" (Google kod tarayıcısı — kamera izni yok,
  `ci/QrTransfer.kt`). Ortak Wi-Fi yoksa `LocalOnlyHotspot` + `WIFI:` QR; alıcı uygulama
  `WifiNetworkSpecifier` + `bindProcessToNetwork` (internetsiz ağda bağlamadan 192.168.x'e
  gidilemez — tarayıcı yolunda bu risk açık, CIHAZ_TESTI). Üçüncü taraf yükleme YOK (gizlilik).
  **R8 hipotezi YANLIŞ çıktı:** AGP 9 kütüphane koruma kurallarını UYGULUYOR
  (`build/app/outputs/mapping/release/configuration.txt` kaynak listesi); tam kip
  `ComponentRegistrar` boş yapıcılarını siliyordu → kural eklendi, 6c (R8 kapalı) silindi.
  **TUZAK — yerel APK telefona kurulamaz** (CI anahtarı ≠ debug anahtarı, veri silinir):
  temiz kopyada `applicationIdSuffix = ".r8test"` + sabit `documents` authority'sini
  `${applicationId}`e çevirip YAN YANA kur. **TUZAK — Git Bash'te adb:** `MSYS_NO_PATHCONV=1`
  `uiautomator dump /sdcard/...` için şart (yoksa "/Files/Git/sdcard"a yazar, bayat döküm
  okunur) ama aynı oturumda Windows yolları `C:/` biçiminde verilmeli; SF `--latency`
  katman adı `#id` ekiyle. İndirilenlerde göster: `BrowserScreen(focusPath:)` — oranla atla,
  satır kurulunca `getOffsetToReveal`; `ensureVisible` satırı alt çubuğun arkasında bıraktı.
- **2026-10-23 (11) — foto klasörü ölçüm turu:** **TUZAK — SF `--latency` aralığı takılma
  değildir:** `adb input swipe` arasındaki boşluklar >33 ms "takılma" gibi görünüyor; önceki
  turun "kaydırmada 180–250 ms / yukarı p99 50 ms" sonucu bu yüzden YANLIŞTI. Doğrusu
  `FrameTiming` (`main.dart` yavaş kare kancası, logcat `KARE`). Gerçek donma büyük klasör
  AÇILIŞINDA: `FsScan.sort` her karşılaştırmada `nameKey` (242 ms → 45 ms, anahtar sıralama
  başına bir kez). GPU belleği görsel önbelleği tavanının ~2-3 katı, ön planda geri verilmiyor
  (Impeller+Skia) → orta/güçlü tavan 160 MB/1000 → 64 MB/300 (GL 496 → 237 MB). Ölçüm
  betikleri: yan yana `.r8test` APK + tek senaryo betiği (A/B aynı adımlar).

- **2026-10-23 (12) — arka plan işleri, yapay ses seçimi, AI özet kaydı:** Pano yüzen
  çubuğundan yeni klasör düğmesi kalktı (kullanıcı isteği; diyalog + akış silindi).
  **Kök neden — "AI özeti hazırlanıyor ama açamıyorum, tekrar basınca yenisi başlıyor":**
  özet yalnız başlatan ekranın `context`i yaşıyorsa gösteriliyordu, hiçbir yerde
  tutulmuyordu, iş hedefsizdi. Artık `services/ai_summary_store.dart` (diske JSON, dosya
  boy+mtime değişince bayat) + süren iş anahtarla tekil + `FmJobTargetKind.aiSummary`
  (bildirim/şerit özeti açar). `showTaskDialog` (tracked_busy) her "çalışıyor" penceresine
  **"Arka plana al"** koydu; sessiz bitiş artık `userWatching && pencere açık`.
  **Kök neden — yapay sesler yalnız sesli kitapta:** motor (WebView) sesli kitap EKRANININ
  içindeydi. Artık `NeuralVoiceEngine.acquire/release` + kökte `NeuralVoiceHostLayer`
  (main.dart builder; 3 dk boşta kapanır), sentez kuyruklu (EMA tek iş bilir). Sesli okuma
  tercihi `TtsPrefs.voiceName = 'neural:<ad>'` (biçim değişmedi); `TtsService` parçaları
  WAV'a çevirip video_player ile çalar, sonrakini önceden üretir, hata olursa cihaz sesine
  düşer. Sesli kitap üretimi `AudiobookJob` (ekrandan bağımsız, `TrackedTask` eşiksiz →
  ön plan servisi + bildirim "Durdur", hedef `FmJobTargetKind.audiobook`).
  CIHAZ_TESTI: WebView'ın uygulama alttayken JS/Worker'ı kısıp kısmadığı doğrulanmadı.

- **2026-10-23 (13) — bulut işlerinin sonu: Faz 14b, 15b, 16 kalanı, slayta görsel:**
  Kullanıcı: *"bulutta yapılabilecek hepsini tek oturumda yap, main'e merge et, APK derlensin"*.
  **14b:** video da dört yerleşimi yapıyor — Media3 `Presentation` `LAYOUT_SCALE_TO_FIT` (siyah
  boşluk) / `_WITH_CROP` (ortadan kırp); Dart `VideoLayout` adı kanalla gider. Videoda dosya
  boyutu hedefi = hedef×8/süre − ses (taban 150 kbit/s; düşükse ölçü de iner, piksel başına
  en az "en küçük" kalitenin bpp'si). `CropAnchor` (fotoğraf; video motoru yalnız orta).
  **Ölçüldü:** `image` paketi `decodeJpg` yön etiketini piksele uygulayıp SİLİYOR, tarih/kamera
  EXIF'ini çıktıya yazıyor → "EXIF kopyası" zaten vardı; yalnız `stripLocation` eklendi
  (`exif.imageIfd.sub.directories.remove('gps')`). WebP (Android kodlayıcı) meta veri taşımaz.
  Düzenleyici: `ImageEdits.scale` (kırpılmış bölgeye uygulanır, isIdentity'ye dahil).
  **15b:** `AppType` (`context.type.small` …) — **TUZAK:** `textTheme.bodySmall` RENK de
  taşır; düğme/çip/perde içindeki beyaz yazıyı koyuya çevirir → `AppType` yalnız BOY verir.
  Renk tokenları değerleri birebir korur (görünüm değişmez). Simge/`Colors.*` bekçisi artık
  tavan değil kural (0). **TUZAK — `dart format` KOŞTURMA:** depo dart format'lı değil; tek
  dosyada bile yüzlerce satırlık gürültü üretir (bu turda 172 dosyayı biçimlendirip geri
  almak zorunda kalındı — betikler HEAD'den yeniden uygulandı). Elle kurulan ad sorma
  pencerelerinde `controller.dispose()` `await`ten hemen sonra → kapanış animasyonunda
  "used after disposed" yarışı; `showAppPrompt` denetleyiciyi pencerenin durumunda tutar.
  **16:** asimetrik `Positioned` → `PositionedDirectional` (bilinçli fiziksel: PDF sayfası
  üstü imza/kurdele, önce/sonra bölme çizgisi — bekçide izinli). `LiveProgress`: canlı
  bölge yalnız %10 basamağında değişir (her saniye konuşmasın).
  **Office:** "Word liste düğmesi" ve "Excel formül önizlemesi" zaten vardı (yol haritası
  bayattı); slayta görsel ekleme yazıldı (`PptxEditor.addImage`, `PptxRender.forget`).
  Cihaz maddeleri `docs/CIHAZ_TESTI.md` en alt. Sıradaki: cihaz turu (FAZ_PLANI §0.1 sıra 12).

- **2026-10-23 (14) — üst alan yeniden tasarımı, akıllı bildirim alanı, çöp donması, PDF "zorla
  kaydırma", AI etiket/anlamla arama:** Kullanıcı (4 ekran görüntüsü): kategori üst alanı baştan,
  "Analiz ve düzenle" menüsü, panoda %25 alçak bellek kartı + bildirim alanı, çöp donması, PDF,
  tek tip bildirim, sohbet temizliği sayıları, araç sırası, menüler, anlamla ara.
  **Kök neden — PDF "zorla kaydırılıyor":** okuma kipi (Faz 18/G20) çubukları kaydırırken çekince
  gövde her animasyon karesinde büyüyor; pdfrx 1.3.5 `_updateLayout` görünüm boyu her değiştiğinde
  `_goToPage(güncel sayfa)` çağırıp SAYFA BAŞINA atlıyor. PDF'te okuma kipi kapatıldı
  (`readingBars: null`). **TUZAK:** pdfrx görüntüleyicisinin boyunu jest sırasında asla değiştirme.
  **Kök neden — dolu çöpte donma/çökme:** `TrashService.list()` her kayıt için ana izlekte
  `existsSync`×2; `empty()` öğe başına `deleteForever` → 5 bin kez tüm `index.json` yazımı +
  5 bin `FsEvents.changed()` (açık ekranlar disk taramalı tazelemeye giriyordu). Artık var olma
  denetimi `compute`ta (≥200), dizin JSON'u damgalı (boy+mtime) bellek önbelleğinde, toplu silme
  200'lük gruplarla tek yazma + TEK sinyal (`_deleteMany`, purge de). Çöp ekranı süzme/sayım
  önbellekli, tek silme/geri yükleme yerelden düşer.
  **Kök neden — sohbet temizliği "temizledim ama hâlâ sayıyor":** rapor taramanın anlık fotoğrafıydı.
  `ChatJunkLive` (süreç başına tek FsEvents dinleyicisi) silineni kovalardan/toplamdan düşürür,
  `job.detail`i yeniler, `JobQueue.refreshFinished` şeridi/kutuyu tazeler.
  **Yeni:** `SmartInbox` (pano en üstü; süren işler → olaylar [bellek ≥%90, çöp ≥300, ağdan erişim
  — kapatılamaz] → 24 sa içindeki kapatılmamış sonuçlar; en çok 3 satır; boşken çizilmez). Panoda
  alt `JobProgressBar(hidden:)` gizli (aynı iş iki yerde olmasın); ağ şeridi inbox'a katıldı.
  Bellek kartı kompakt (halka 52, titleLarge). `showAppActionSheet` (gruplu, simgeli levha —
  `showAppSheet` üstünde; tasarım bekçisi `showModalBottomSheet`i yeni dosyada YASAKLIYOR) →
  seçim "Daha fazla" ve galeri ⋮; açılır menü teması gölgeli/ferah. Kategori ekranı: başlık altında
  "N öğe · X MB", `FmListControls` (Sırala·Süzgeç·Analiz hapları + çip satırında GÖRÜNMEYEN etkin
  ölçütlerin kaldırılabilir çipleri), etiket çipleri. `category_tools.dart`: Özet / Genel analiz
  (`CollectionInsights`, cihazda) / AI analizi (sayılar + ≤150 ad) / AI ile kategorilere ayır
  (`AiTagger`: önce AI dizini, kalanlar için ad+klasör ADI+boyut+ay; öneri levhada onaylanır) /
  toplu etiket / etiket yönetimi (ilk kez arayüz; `renameTag/deleteTag` artık @visibleForTesting
  değil). Anlamla ara (`AiMeaningSearch`): YALNIZ sorgu AI'ya, sözcük planı arama dizini + AI
  dizininde cihazda puanlanır; panodaki arama kutusunda "✦ Anlamla" + arama ekranında düğme.
  Araçlar varsayılan sırası güç sırası (Yer aç, Sohbet temizliği [yeni kutu], Aktar, Kasa…);
  harici bellek yine hep başta. graphify bu ortamda yok — `graphify update .` yerelde.

- **2026-10-23 (15) — düzenleme turu planı (`docs/DUZENLEME_PLANI.md`, Faz 20–33; kod değişmedi):**
  Kullanıcı: *"Word, Excel, PDF, slayt, metin, görsel düzenleme — özellikle Word'de yazı, Excel'de
  giriş — telefonda rahat, canlı, kasmadan, alışık olunan Office'e benzer olsun; detaylı fazlar, kod
  değiştirme, main'e merge et."* Altı editör denetlendi + M365/Google/Numbers mobil dili + Android IME
  araştırması. **Doğrulanmış bulgular (kodda yeniden okundu, henüz düzeltilmedi → Faz 20/21):**
  **W1** docx-preview `splitBySection`, `breakPages:true` + `ignoreLastRenderedPageBreak:false` iken
  `w:lastRenderedPageBreak` içeren paragrafı iki `<p>`'ye bölüyor → indeks eşlemesinin sayım sigortası
  canlı düzenlemeyi kapatıyor; Word bu işareti her kayıtta yazdığı için çok sayfalı gerçek belgelerde
  "Düzenle" büyük olasılıkla çalışmıyor (köprü testi tek sayfalık örnekle koştuğu için yakalanmadı).
  Çözüm planı: WebView'a giden kopyada her `w:p`'ye `w:bookmarkStart _fkp<i>` (docx-preview
  `<span id>` çiziyor), işaretsiz `<p>` = önceki paragrafın devamı. **X1** Türkçe işlev adı/`;` formül
  dosyaya ham yazılıyor (`xlsx_package.dart:564`) → masaüstü Excel `#AD?`. **X2** satır/sütun silmede
  `_shiftLayoutRows/_shiftKeys/_shiftSet` `k == at`'i düşürmüyor → silinen satırın stil/yükseklik/gizli
  bilgisi ÜST satıra yazılıyor. **SL1** slaytta `\n` `a:t` içine ham; `a:t`'siz paragrafa yazı
  kaydedilmiyor. **TX1** metin editörü satır numarası `'\$i'` → her satırda "$i". Ayrıca: Word'de
  Enter yeni paragraf açmıyor (`w:br`), `setRuns` köprü/alan/dipnot başvurusunu siliyor, yazı ~0,5
  ölçekte düzenleniyor; Excel'de %100'de hücre içi düzenleme hiç açılmıyor (30×72 dp eşiği), her
  setState'te 3 yeni `FormulaEngine`, ekle/silde formül başvurusu kaymıyor; slaytta ~0,37 ölçek.
  **Mimari öneri (K18, karar Faz 21 ölçümü + 📱 kontrol noktasıyla):** Word'ün kalıcı yazma yüzeyi
  WebView `contenteditable` DEĞİL, Flutter-yerel **Mobil görünüm** editörü + kendi DOCX modeli (M365
  telefonda da Mobil görünümde düzenletiyor); motor super_editor ya da kendi ince `DeltaTextInputClient`
  çekirdeğimiz. *Niye:* Android IME + contenteditable sorunları bitmiyor (ProseMirror 2025'te hâlâ
  Android klavye düzeltmesi yayımlıyor), Flutter yolu bulutta `flutter test`le simüle edilebiliyor.
  **REDDEDİLEN:** gömülü LibreOffice/Collabora (APK +70–75 MB), WebView'da ProseMirror (yine
  contenteditable), paragraf başına ayrı TextField (paragraflar arası seçim yok, boş paragrafta geri
  silme klavyeye göre olay üretmiyor). Sayfa görünümü okuma/önizleme için WebView'da kalır (K19).
  Diğer öneriler: Excel'e uygulama içi sayı/formül tuş takımı (K20), taslak günlüğü + varsayılan açık
  otomatik kaydetme (K21), Türkçe arayüzde Türkçe formül dili ama dosyaya İngilizce (K22), Excel ızgara
  çiziminde ölçümlü deneme (K23). Yürütme: Faz 20 → 21 → 25 → 26 → 22 → 23 → 28 → 30 → 24 → 27 → 29 →
  32 → 31 → 33; cihaz turu (FAZ_PLANI sıra 12) Faz 33 ile birleştirilebilir.
- **2026-10-23 (16) — düzenleme turu D1–D4: Faz 20 ✅, 21 ✅ (K18 bekliyor), 25 ✅, 26 🟡 kısmen:**
  Kullanıcı: *"Faz 20'ye başla, 4 faz bitir, main'e merge et, APK derlensin"*; bağlam dolunca
  *"daha fazla faza geçme, bitir, rapor sun"* → Faz 26'nın bir kısmı sonraki oturuma.
  **Faz 20:** X1 (`FormulaEngine.toFileFormula`: İngilizce ad + `,` + `.` + `_xlfn.`), X2
  (`_inDeleted`), W11 (zengin metin korunur), SL1 (`a:br`; el değmeyen paragraf artık yazılmıyor —
  eskiden HER kayıtta ilk `a:t`'ye toplanıyordu), TX1, IM4. `lib/core/edit/`: EditHistory,
  EditSession (otomatik kaydetme K21 varsayılan açık), DraftJournal, SaveIsolate, EditorChrome
  (klavye üstü çubuk + Aa paneli), EditorShortcuts, EditorPerf. **Faz 21a:** W1 kökü
  `w:lastRenderedPageBreak` bölmesi → WebView kopyasında `_fkp<i>` yer imleri; kanıt: Word'de
  kaydedilmiş örnek Dart 31 / DOM 32 → şimdi 31. Enter/geri silme paragraf böl/birleştir, ada
  (köprü/alan/dipnot/resim) korunur, JS tarafı geri al. **Faz 21b ölçüm (flutter test, debug):**
  super_editor 1000 paragraf ilk pump 2223 ms, 8 harf IME 1177 ms; ince çekirdek 52 ms / 9 harf
  112 ms. super_editor 43 paket ekliyor ve package_config 3.0.0→2.2.0 düşürüyor → ana pubspec'e
  EKLENMEDİ; ince çekirdek (`lib/labs/word_editor/`) geliştirici bayrağıyla. **K18 kararı
  kullanıcının 📱 kontrol noktasına bağlı** (CIHAZ_TESTI "Faz 21"). **Faz 25:** yüzer hücre
  editörü (%100'de de), ✓↵⇥ oklar, K20 tuş takımı, işaret kipi + renkli başvurular, tutamaklar,
  bağlam menüsü (özel yapıştır), akıllı giriş (`sheet_input.dart`), K22 Türkçe formül dili
  (Ayarlar'da "Formülleri İngilizce göster"), ekle/silde başvuru kaydırma (`sheet_structure.dart`).
  **Faz 26 (yapılan):** `CalcState` (kalıcı değer önbelleği + hesapta kaydedilen bağımlılık
  grafiği; hücre değişince yalnız bağımlılar; uçucu işlevler her değişiklikte; ≥5 bin formülde ilk
  hesap isolate'te), `CalcLog` (model günlüğü: setCell hücre, yapısal/sayfa işlemi toplu),
  kaydette `<v>` önbellek değeri, `maxCols`/`mergeAt`/`condRuleAt` dizinleri, durum çubuğu ve
  koşullu biçim min/max önbelleği, `functionNames` bir kez sıralı. AST önbelleği YOK (ayrıştırıcı
  yorumlayıcı; değer önbelleği sayesinde formül değişiklik başına bir kez ayrıştırılıyor).
  **Faz 26 kalan:** K23 ızgara denemesi, okuma sınırı (1024 sütun/200 bin satır) şeridi — DİKKAT
  bugün kesilen hücreler kaydedince SİLİNİR —, `test/perf` kıyasları, paylaş/indir'in `save()`'i
  hâlâ ana izlekte (`file_ops.dart`).
  **Bug kökleri:** (a) çapraz sayfa formülü: `=Sayfa2!B1` hesaplanırken B1'in `=C1*2`'si etkin
  sayfanın C1'ini okuyordu (ayrıştırıcının sayfa bağlamı yoktu) → `_Parser.sheet`. (b) Excel AI
  düğmesi düzenlerken klavye üstü çubuğun üstüne biniyordu → yazarken gizli.
  **Tuzaklar:** testWidgets içinde gerçek dosya G/Ç sahte saatte bitmez (captureSource/lookForDraft
  unawaited, DraftJournal.find senkron); Scaffold gövdesinin MediaQuery'si viewInsets'i siler →
  EditorChrome `View.of`; flutter_test gölgeleri düz siyah çizer (`debugDisableShadows`), tasarım
  görüntüsünde gövde içinde kapatıp aç; Carlito'da ⇥↵⌫ yok → ikon; LibreOffice dipnot başvurusu
  olup `footnotes.xml` yoksa dosyayı açmıyor; soffice UTF-8 metin filtresi `txt:Text (encoded):UTF8`.
