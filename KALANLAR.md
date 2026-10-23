# KALANLAR — canlı kalan-iş listesi (biten madde silinir)

> **2026-10-21:** Kalan işler fazlara bağlandı → `docs/FAZ_PLANI.md`. Faz 0'da ayrıldı:
> telefonda bakılacak maddeler (37) → `docs/CIHAZ_TESTI.md`; burada yalnız gerçek iş kalır.
>
> **2026-10-22:** Yürütme sırası artık `docs/FAZ_PLANI.md` **§0.1** (bulutta yapılabilenler
> önce, telefon gerektirenler tek cihaz turunda). Yeni görsel/kullanım fazları 13–19
> (tür süzgeci, görsel boyutlandırma, görsel dil, erişilebilirlik/RTL, liste/gezinme,
> görüntüleyici, sistem entegrasyonu) orada; aşağıdaki maddelerin sıra numarası
> köşeli parantezde.


- [ ] **[Sıra 8 ☁️ + 12 📱] Ham USB yazmayı sağlamlaştır (K8 kararı, 2026-10-21).** Kullanıcı:
      *"kişi rahatlıkla USB'ye yazabilmeli ve güvenli olmalı"*. Android'in bağlamadığı
      bellekte FAT/exFAT'a kendi sürücümüz yazıyor (`lib/services/fm/usb/`); günlük yok.
      Yapılacak: güvenli yazma sırası (veri → FAT → dizin girdisi), yazma sonrası geri-okuma
      doğrulaması, "kirli" bayrağıyla bir sonraki takışta onarım, çekmeden önce "Güvenle
      çıkar" uyarısı + yarıda kesilme testleri.

- [ ] **[Sıra 8 ☁️] onReorder → onReorderItem (Flutter 3.44 kullanımdan kaldırma, 2026-10-21):**
      `dashboard_layout_sheet.dart` (alt küme → tam liste eşlemesi) ve `nav_tabs_sheet.dart`
      (`nav.move`) `// ignore` ile bırakıldı; yeni API `newIndex`i önceden düzeltiyor —
      eşleme ve `move` mantığı buna göre değiştirilip testle sabitlenmeli.
- [ ] **[Sıra 2 ☁️ = Faz 10b] Faz 10 kalan:** örnek medya seti + duman testleri (EXIF yönlü JPEG, HEIC, WebP,
      MP4/MKV/altyazı, MP3/FLAC/M4A). (Galeri RSS 2026-10-22 ölçüldü: PSS 948 MB → aşağıdaki GPU maddesi.)

- [ ] **[📱] Açılışın ilk 0,5 sn'si:** ilk kare raster 218–309 ms (Impeller ve Skia), sonra pano
      build 45–49 ms. `_logSlowStartupFrames` logcat'e yazıyor; pano ilk kurulumunda ertelenebilecek
      iş var mı bakılacak.
> **Bu liste nasıl okunur (2026-08-08 sınıflandırması).** Açık maddelerin
> çoğunluğu benim kapatabileceğim işler DEĞİL; hangisinin kimde olduğu
> karışmasın diye üç kümeye ayrılıyor:
>
> 1. **“cihaz doğrulaması (kullanıcı)”** başlıklı ~27 madde — telefonda
>    bakılacak şeyler (kamera, Play Services, gerçek Word/Excel'de açma,
>    dokunma hissi, gerçek NAS). Birim testle doğrulanamazlar; kodla
>    “kapatmak” yalnız kâğıt üzerinde kapatmak olurdu.
> 2. **“bilinçli” / paket sınırı** işaretli maddeler — kararı verilmiş ve
>    gerekçesi maddenin içinde yazılı olanlar (`excel 4.0.6` sayfa taşıma
>    API'si yok, `smb_connect` portu yok sayıyor, cihazda JPEG kodlayıcı yok,
>    graphify bu ortamda kurulu değil, Firebase config kullanıcının).
> 3. **Gerçek kalan iş** — çift bölme, dosya seçici intent'i, SAF ile SD
>    karta yazma, listede klasör boyutu, ses için bildirim/kilit ekranı
>    kontrolleri, APK boyutu (split-per-abi/AAB). Her biri kendi başına bir
>    tur. (Word tablo/resim/karakter punto, Excel grafik/köşegen/sayfa taşıma,
>    PDF AGL/iki yana/CropBox Faz 8-9'da kapandı — HAFIZA 2026-10-21 (4).)

- [ ] **SD birleşik depolama — sonraki adımlar (bilinçli ertelendi).** (a) SAF klasör
      izniyle yazma (yol üzerinden yazılamayan kartlar için); (b) "yalnız ana bellek
      %X'i aşınca" eşiği; (c) klasör seçiminde serbest klasör (şu an Android'in
      standart ortak klasörleri). Kullanıcı "birlik olarak kullan"dan başka bir şey
      kastettiyse ekran/kip buna göre genişletilecek.

- [ ] **[Faz 11a ☁️ / 11b 👤 — sıra 9 ve 13] MAĞAZA YOLU (2026-08-28 durum değerlendirmesi) — sırayla, her biri
      kendi turu.** Dört temel bu turda yapıldı (artan versionCode, imza
      sızıntısının kapatılması, hata kaydı, gizlilik politikası). Kalanlar:
      (a) ~~**targetSdk 36**~~ → **YAPILDI 2026-09-26** CI yamasıyla
      (Flutter 3.29.3 üzerinde compileSdk/targetSdk 36; tahminli geri
      manifestte kapalı). Flutter yükseltmesi (sürüm duvarı) ve tahminli
      geriye geçiş hâlâ ayrı tur;
      (b) **AAB** çıktısı + `android/` klasörünün depoya alınması (Play yeni
      uygulamada APK kabul etmiyor; her derlemede `flutter create` üretmek
      Play imza/sürüm yönetimi için kırılgan);
      (c) **izin diyeti / Play varyantı (flavor):** `QUERY_ALL_PACKAGES` +
      `PACKAGE_USAGE_STATS` (Uygulamalar ekranı) ve
      `REQUEST_INSTALL_PACKAGES` + `.apk` intent'leri Play'de yüksek red
      riski — bunlar yalnız GitHub sürümünde kalsın;
      (d) **Drive kapsamı `drive` → `drive.file`** (yayına almak yıllık
      ücretli CASA denetimi istiyor — bkz. HAFIZA 2026-08-05);
      (e) **boyut:** ~91 MB/ABI. 2026-09-26: OCR Play Hizmetleri'ne
      (unbundled, ~12 MB), pdfium.wasm çıkarıldı (2 MB), Firebase kaldırıldı.
      ffmpeg (15,5 MB/ABI) KULLANICI KARARIYLA KALIYOR (video küçültmenin ana
      motoru). Kalan aday: font altkümesi; → *2026-10-21 K2 (b): FFmpeg kalktı,
      Media3 Transformer geldi (Faz 10); R8 kapalıyken APK 63-66 MB*;
      (f) **Veri Güvenliği formu** `assets/privacy/tr.md`in 1-2. bölümünden
      doldurulacak;
      (g) ~~`flutter analyze` CI kapısı~~ **BİTTİ** (2026-08-28).

## Word "gerçek mobil Word gibi olsun" — kalan yol haritası
> **2026-10-23:** bu bölümün devamı ve yeni bulgular (W1 sayfa kırmada paragraf bölünmesi,
> Enter = `w:br`, `setRuns` köprü/alan kaybı …) → `docs/DUZENLEME_PLANI.md` Faz 20–24.
2026-08-02'de yapısal geri al/yinele geldi. Kalanlar:
- [x] ~~**Belge içinde bul / değiştir yok**~~ → **YAPILDI 2026-08-04:** JS
      köprüsü (`findAll`/`findGo`/`replaceHit`/`replaceAll`). Arama DOM'a hiç
      dokunmuyor (eşleşme `Range` ile seçiliyor) → düzenleme kapalıyken de
      çalışıyor. Katlama Türkçe duyarlı.
- [x] ~~**Metin rengi / vurgu / madde işareti / numaralandırma** düğmeleri yok~~
      → **YAPILDI 2026-08-04:** renk/vurgu seçime (`execCommand` + `data-fk-*`
      işaretleri), liste PARAGRAF ÖZELLİĞİ olarak (`w:numPr` + üretilen
      `numbering.xml`). `insertUnorderedList` bilinçli kullanılmadı: `<p>`yi
      `<li>`ye çevirip paragraf eşlemesini bozuyordu (HAFIZA 2026-08-04 §D).
- [x] ~~**Seçili metin çevirisi yok**~~ → **YAPILDI 2026-08-04:**
      `sendSelectionText` köprüsü; "Seçimi çevir" ve "Seçimi AI ile düzelt"
      alt çubukta.
- [ ] Harf harf yazma geri alma yığınına girmiyor (bilinçli — HAFIZA 4. tur).

## Excel "gerçek mobil Excel gibi olsun" — kalan yol haritası
> **2026-10-23:** devamı ve yeni bulgular (X1 Türkçe formül dosyaya ham yazılıyor, X2 satır
> silmede üst satırın biçimi eziliyor, X3 başvuru kaydırma …) → `docs/DUZENLEME_PLANI.md` Faz 20, 25–27.
2026-08-02'de düzenleme çekirdeği geldi (geri al/yinele, kes/kopyala/yapıştır,
doldurma tutamağı, Σ, bul-değiştir). Excel mobilden hâlâ ayıranlar, **etkiye
göre sıralı**:
- [x] ~~**Yapıştırmada BİÇİM taşınmıyor**~~ → **YAPILDI 2026-08-04:** önerilen
      yoldan DAHA UCUZU bulundu — `styleCopies` hedef→kaynak eşlemesiyle
      kaynağın `s` indeksi hedefe yazılıyor, stil tablosuna hiç dokunulmuyor
      (ikisi de aynı dosyada, indeks zaten geçerli). Değer ve biçim TEK geri
      alma adımında.
- [x] ~~**Sayı biçimi düğmeleri yok**~~ → **YAPILDI 2026-08-02:** biçim çubuğunda
      **#** menüsü (Genel/Sayı/Binlik/Para ₺/Yüzde/Tarih/Saat/Metin) + ondalık
      artır/azalt. `XlsxSavePatch._StyleTable` `numFmtId` tahsis edip hücrenin
      var olan `<xf>`ini kopyalıyor. **Paket yolu kullanılamazdı:** tarih
      biçimi sayısal hücrede `save()`i istisnayla kırıyordu (HAFIZA 3. tur).
- [x] ~~**Dolgu rengi / yazı rengi / kenarlık / metin kaydırma / hücre
      birleştirme** yazılamıyor~~ → **YAPILDI 2026-08-04:** `_StyleTable`
      `fontId`/`fillId`/`borderId` de tahsis ediyor; birleştirmeyi `excel`
      paketi yazabiliyordu. Arayüz: "Daha fazla" → **Biçim** grubu.
- [x] ~~**Sırala ve süz (autofilter) arayüzü yok**~~ → **YAPILDI 2026-08-04:**
      başlıktaki ok tıklanabilir — A→Z / Z→A + değer onay listesi. Süzgecin
      gizlediği satırlar sütun başına ayrı tutuluyor (elle gizlenen satır
      etkilenmiyor); sıralama satırları BÜTÜN olarak taşıyor.
- [x] ~~**Sayfa ekle / yeniden adlandır / sil**~~ → **YAPILDI 2026-08-04:**
      sekmeye uzun basış + "+" düğmesi.
- [x] ~~**Metin komşu hücreye taşmıyor, satır içeriğe göre yükselmiyor**~~ →
      **YAPILDI 2026-08-07** (kullanıcı: "excelde farklar var bizle gerçek
      excelde"): `core/sheet_overflow.dart` + `SheetTextMeasure`. Sığmayan
      metin boş komşunun üstüne sarkıyor, `ht` taşımayan satırlar kaydırılan/
      çok satırlı içeriğe göre yükseliyor. **Cihaz doğrulaması bekliyor:**
      başlık satırı kırpılmadan okunuyor mu, çok satırlı hücreler Excel'deki
      kadar yüksek mi, büyük dosyada kaydırma akıcı mı.
- [ ] **Sayı sığmayınca `###` gösterilmiyor** (bilinçli): Excel sığmayan sayıyı
      `###` yapar, biz kırpıyoruz. Ölçümümüz Excel'inkiyle birebir aynı
      olmadığı için yanlış yerde `###` göstermektense kırpmak seçildi.
- [x] ~~**Hücre notu/açıklaması** okunmuyor~~ → **OKUNUYOR 2026-08-04:**
      `comments*.xml` (klasik biçim) sayfanın `_rels`i üzerinden çözülüp
      okunuyor; hücrenin sağ üst köşesinde Excel'inki gibi kırmızı üçgen,
      dokununca yazar + metin. **Yazma bilinçli yapılmadı:** not eklemek eski
      VML çizimini (`vmlDrawing1.vml` + `<legacyDrawing>`) de üretmeyi
      gerektiriyor, eksik/yanlış VML'de Excel dosyayı "onarılması gerekiyor"
      diye açıyor — cihazda doğrulanamayan bir yazma yolu eklenmedi. Var olan
      notlar kaybolmuyor (`excel` paketi tanımadığı parçaları baytı baytına
      taşıyor).
- [x] ~~**formül otomatik tamamlama yok**~~ → **YAPILDI 2026-08-04:** formül
      çubuğunun altında işlev adı önerileri (motorun KENDİ takma ad
      tablosundan). Ayrı bir "işlev sihirbazı" ekranı bilinçli yapılmadı:
      satır içi öneri telefonda ekran değiştirmeden çalışıyor.
- [x] ~~**Koşullu biçimlendirme yalnız OKUNUYOR**~~ → **YAPILDI 2026-08-04:**
      "Daha fazla" → Biçim → **Koşullu biçimlendirme** (şundan büyükse /
      küçükse / eşitse / metin içeriyorsa) + renk. Kural sayfada (`<cfRule>`),
      görünümü stil tablosunda (`<dxf>`) yazılıyor; `dxfId` indeksi ekrandaki
      modelle dosyada BİREBİR aynı sırada tutuluyor (tekilleştirme bilinçli
      olarak yok — indeks kayması ekranla dosyayı ayrıştırırdı). Kalan: renk
      ölçeği / veri çubuğu kuralları hâlâ yalnız okunuyor.
- [x] ~~**Doldurma tutamağına çift dokunup sütunu otomatik doldurma**~~ →
      **YAPILDI 2026-08-04:** sınırı komşu sütun belirliyor (önce SOLDAKİ —
      Excel'in kuralı, o boşsa sağdaki). İkisi de boşsa uyarı veriliyor:
      nereye kadar dolduracağı bilinemez, tahmin binlerce boş satır yazmak
      olurdu.


## Yarım kalan
- [ ] **SMB: yalnız SMB3 zorunlu kılan sunucular sınanmadı.** SMB'nin kendisi
      2026-07-30'da **gerçek Samba 4.19 (SMB2) üzerinde doğrulandı** — okuma ve
      yazma çalışıyor (HAFIZA 2026-07-30 IV; `test/remote_live_test.dart`), o
      yüzden "protokolü listeden çıkar" kararı KAPANDI. Kalan tek belirsizlik:
      `smb_connect` en fazla SMB210 konuşuyor; SMB3'ü zorunlu kılan (eski
      sürümleri kapatmış) bir NAS'ta bağlanmayabilir. Ekrandaki uyarı bunu
      yazıyor ve kullanıcıyı SFTP/FTP'ye yönlendiriyor.
- [ ] **SMB'de port değiştirilemez (paket sınırı).** `smb_connect` bağlanırken
      445'i sabit kullanıyor, verilen portu yok sayıyor; form alanı bu yüzden
      SMB'de kapalı. Farklı portta SMB gerekirse paket çatallanmalı.
- [x] ~~**FTP sunucusu arka planda çalışmıyor (bilinçli).**~~ → 2026-08-29:
      kullanıcı bunu bir HATA olarak bildirdi, karar geri alındı. Sunucu artık
      `FtpService`te yaşıyor ve ön plan servisiyle arka planda sürüyor;
      "unutma" riskinin karşılığı kapatmak değil GÖRÜNÜRLÜK oldu (kalıcı
      bildirim + pano şeridi). Bkz. HAFIZA 2026-08-29 (II).
- [x] ~~**Kalan ekranlar hâlâ Türkçe**~~ → **BİTTİ 2026-08-08.** Madde
      eskimişti (yazıldığında 4 ekran çevriliydi, bugün tablo 1700+ anahtar).
      Kaynakta kalan ~50 sabit dize taşındı; ortak sözcükler `common.*`
      altında toplandı. **Bekçisi var:** `test/l10n_literals_test.dart`
      kaynağı tarıyor — `Text(...)`/`tooltip:`/`label:` gibi yerlere doğrudan
      Türkçe yazan bir değişiklik testi KIRAR. İzin listesi dar ve gerekçeli
      (marka adı, JSON anahtarı, desen sözdizimi).
- [ ] **Eski (kelime bazlı) yerinde düzenleme yolunu SİL** — 2026-07-27: paragraf
      editörü cihazda doğrulanınca `viewer_screen`'deki seçim-tabanlı düzenleme
      zinciri (`_startInlineEdit`/`_applyInlineEdit`/`_InlineEdit`/`_editBar`),
      `services/pdf_edit_flow.dart`, `services/pdf_content_editor.dart`,
      `services/pdf/pdf_text_replace.dart`, `widgets/pdf_inline_editor.dart` ve
      testleri (`pdf_content_editor*`, `pdf_inplace_edit`, `pdf_reflow`,
      `pdf_replace_text`, `pdf_encrypted_edit`) kaldırılacak. **Şimdi
      silinmemesinin nedeni:** paragraf motoru bazı belgeleri REDDEDİYOR
      (genişlik tablosu olmayan font, aralıkta gerçek çizim `q`/`cm`/`Do`,
      sığmama — *satır başına ayrı `BT`/`ET` reddi 2026-07-28'de kalktı*);
      eski yol o belgelerde hâlâ çalışan tek yedek. Doğrulanmadan silmek
      yetenek kaybı olurdu. (usta 4b'nin istisnası, gerekçesi burada.)
- [ ] **Seçili metin çevirisi Word/Excel/Slayt'ta yok** — şu an yalnız PDF'te
      (seçim altyapısı orada). Word WebView tabanlı, seçim Flutter'a gelmiyor;
      istenirse JS köprüsüyle seçili metin okunabilir.
- [x] ~~**`withOpacity` → `withValues` temizliği**~~ → **YAPILDI 2026-08-04:**
      10 çağrı dönüştürüldü. `flutter analyze lib` artık **0 uyarı** (yalnız
      `info` kaldı).



## PDF sadakat/deneyim — araştırıldı, cihaz doğrulaması gerekli (kör push yok)
- [x] ~~**Türkçe-duyarlı PDF arama**~~ → **YAPILDI 2026-08-04:** `startTextSearch`
      bir `Pattern` alıyor; `turkishSearchPattern` her harfi Türkçe eş
      biçimlerini kapsayan sınıfa çevirip eşleştirmeyi DUYARLI koşuyor.
      Önerilen "kendi paint callback'ini yaz" yoluna gerek kalmadı.
- [x] ~~**Döndürülmüş sayfa (/Rotate≠0) vurgu düzeltmesi**~~ → **GEREKSİZ:**
      aynı bölümün altında 2026-07-26'da ölçülüp yanlış alarm olduğu yazılmış
      (dört açıda da `/Rect` birebir aynı; iki taraf da ham sayfa uzayında
      konuşuyor). Madde iki yerde duruyordu.
- [x] ~~**PDF vurgu remount zoom kaybı**~~ → **GEREKSİZ:** `_pdfReloadKey` yolu
      2026-07-26'da `PdfReload.reloadFile` ile değiştirildi; widget artık hiç
      remount olmuyor, zoom/kaydırma zaten korunuyor.

## Play Store atağı — PDF (2026-07-25 kararı, 4 faz)
- [x] ~~Faz 1: PDF Araçları (birleştir/çıkar/sil/sırala/döndür/parola/sıkıştır)~~ → YAPILDI 2026-07-25
- [x] ~~Faz 2: İmza (parmakla çiz → sayfaya vektör olarak bas)~~ → YAPILDI 2026-07-25
- [x] ~~Faz 3: Belge tarayıcı (ML Kit) → tek PDF + OCR~~ → YAPILDI 2026-07-25
      ("çoklu resim → tek PDF" maddesini de kapattı)
- [x] ~~Faz 4: gece modu + link tıklama + içindekiler + sesli okuma~~ → YAPILDI 2026-07-25
      **4 fazın tamamı bitti.**

## Sonra yapılacak
- [x] ~~**PDF form doldurma (en son)**~~ → **YAPILDI 2026-08-07:**
      `PdfFormFiller` + `PdfFormScreen` (⋮ → Formu doldur). Overlay yerine
      **liste** seçildi: alanlar telefonda 8-10 punto, sayfayı yakınlaştırıp
      minik kutulara yazmak Acrobat'ın mobilde en çok şikâyet edilen yanı.
      Düzleştirme (kilitleme) seçenekli ve varsayılan kapalı.
      **Cihaz doğrulaması bekliyor (kullanıcı):** gerçek bir form PDF'i aç →
      (a) alanlar sayfa sırasına göre listeleniyor mu, (b) Türkçe harfli değer
      (Ayşe, İstanbul) kaydediliyor mu, (c) kaydedilen dosya Acrobat/tarayıcıda
      dolu görünüyor mu, (d) "Doldurduktan sonra kilitle" değeri sayfaya
      işliyor mu, (e) form olmayan PDF'te açıklama metni çıkıyor mu.
- [ ] Yol haritası #2: Firebase config + gerçek senkron (kullanıcı `flutterfire configure`)

## Bilinen eksik-risk
- [ ] Word canlı düzenleme: paragraf eşlemesi indeks tabanlı (DOM `article p` ↔ `w:p`);
      sayı uyuşmazsa sigorta düzenlemeyi kapatıp metin düzenleyiciye yönlendirir.
      Metin kutusu/köprü içeren belgelerde cihazda doğrulanmalı (2026-07-22)
- [ ] Excel pinch: kaydırma sürerken başlayan pinch ilk denemede tutmayabilir
      (ilk parmağın sahipliği scrollable'da kalır); cihazda rahatsız ederse iyileştirilecek
- [ ] Koyu temada Word WebView kanvası açık kalıyor (sayfa zaten beyaz; bilinçli erteleme)

## Dosya yöneticisi (2026-07-25) — cihaz doğrulaması gereken/ertelenen işler
- [ ] **Depolama doluluğu (`df`) gerçek cihazda:** halka/çubuk doğru dolu mu; bazı
      ROM'larda `df` kısıtlıysa çubuk gizlenmeli (kod öyle davranıyor, doğrulanmadı).
      **2026-08-05 güncellemesi:** toplam artık `df`in ham boyutu değil AOSP
      `roundStorageSize` ile yuvarlanmış REKLAM kapasitesi (512 GB) ve ondalık
      biçimleniyor; boş alan yuvarlanmıyor.
- [ ] **Büyük depolama taraması:** 100 bin+ dosyalı telefonda pano taraması ne kadar
      sürüyor, bellek sorun çıkarıyor mu (`_TopN` sınırı yeterli mi).
- [ ] **SD kart / OTG:** `/storage/XXXX-XXXX` bulunuyor mu; birimler arası taşımada
      kopyala+sil yedek yolu çalışıyor mu; SD karta yazma (SAF gerekebilir!) —
      Android bazı cihazlarda SD karta doğrudan yazmayı engeller, o durumda hata
      mesajı anlamlı mı.
- [x] ~~Video/ses oynatıcı ertelendi~~ → **YAPILDI 2026-07-25:** video_player 2.10.1 +
      video_player_android 2.8.15 (Flutter 3.29 uyumlu son sürüm) ile uygulama içi
      oynatıcı: çalma listesi, kaydırma, hız, tam ekran. Cihazda doğrulanacak:
      büyük mkv/HEVC oynatma, tam ekran yatay geçişi, ses dosyasında arka planda
      çalma (arka plan servisi YOK — ekran kapanınca durur, istenirse audio_service).
- [x] ~~**Ses: bildirim/kilit ekranı kontrolleri yok**~~ → **YAPILDI
      2026-09-03:** `ci/MediaSession.kt` — çerçevenin kendi
      `android.media.session.MediaSession`i (API 21+, **yeni paket yok**).
      Bildirimde sürüklenebilir ilerleme çubuğu, kilit ekranı kontrolleri,
      kulaklık düğmeleri; ön plan servisi (`MediaService`,
      `foregroundServiceType="mediaPlayback"`) süreci çalarken ayakta tutuyor.
      Aynı oturumu video oynatıcı da kullanıyor. Paket yolları
      (`just_audio_background`/`audio_service`) REDDEDİLDİ: ikisi de kendi
      Activity/Service yaşam döngüsünü dayatıyor, bizde `MainActivity` elle
      bakımlı ve çalma motoru Dart tarafında kalmalı. Ayrıntı: HAFIZA
      2026-09-03 §A.
- [x] ~~**Ses: ID3 kapak resmi / albüm-sanatçı bilgisi okunmuyor**~~ →
      **YAPILDI 2026-08-08:** `services/fm/audio_tags.dart` (saf Dart,
      bağımlılık yok) — ID3v2.2/2.3/2.4 + MP4/M4A `ilst`. Çalarda kapak
      resmi, parça adı ve "Sanatçı · Albüm" satırı. Etiket okunamazsa dosya
      adına düşülür. FLAC (Vorbis) ve ID3v1 bilinçli dışarıda.
- [x] ~~**Ekranı açık tutma (wakelock) yok**~~ → **YAPILDI 2026-08-08:**
      `wakelock_plus 1.4.0` + `core/screen_awake.dart` (sayaçlı tek kapı).
      Kilit **yalnız video gerçekten oynarken** tutuluyor; duraklatınca, video
      bitince, uygulama arkaya alınınca ve ekran kapanınca bırakılıyor. Ses
      oynatıcıda hiç alınmıyor. Sayaç birim testli — wakelock pil harcar,
      bırakılmayan bir kilit bir önceki turun pil işini geri alırdı.
- [x] ~~**Video küçük resmi (thumbnail) yok**~~ → madde ESKİMİŞTİ; kod
      2026-07-25'ten beri üretiyor (`ThumbnailCache` + `_VideoThumb`, disk
      önbellekli, film karesi + oynat rozeti).
- [x] ~~**Küçük resim yalnız görsellerde — video/PDF küçük resmi yok**~~ →
      **BİTTİ 2026-08-08:** PDF de kapak sayfasıyla görünüyor
      (`services/fm/pdf_thumbnail.dart`, pdfium ile ilk sayfa, disk önbelleği
      video ile AYNI anahtar kuralında). Parolalı/bozuk belge sessizce simgeye
      düşer ve bir daha denenmez. **Cihaz doğrulaması bekliyor:** belgeler
      listesinde PDF'ler kapaklarıyla mı görünüyor, kaydırma akıcı mı.
- [x] ~~RAR/7z çıkarma yok~~ → **YAPILDI 2026-07-25:** koni_archive (saf Dart, MIT)
      ile RAR4/RAR5 + 7z listeleme/çıkarma/önizleme/parola/çok parçalı. Kalan:
      cihazda büyük ve solid RAR'da hız (saf Dart LZMA/PPMd yavaştır — 100 MB+
      arşivde çıkarma dakikalar sürebilir, ilerleme çubuğu var ama İPTAL YOK),
      ve RAR YAZMA kalıcı olarak yok (biçim özel mülk; .zip üretiliyor).
- [x] ~~**Yapıştırmada çakışma politikası soruluyor değil**~~ →
      **YAPILDI 2026-08-08:** çakışma VARSA alt sayfa açılıyor (İkisini de tut
      / Atla / Üzerine yaz); yoksa hiçbir şey sorulmuyor. Pencereyi kapatmak
      = vazgeç (sessizce bir varsayılana düşmek, kapatılan pencerenin yine de
      dosya yazması olurdu). Klasör çakışması da sayılıyor. `PasteConflict`
      saf ve testli.
- [ ] **Kırpılmış (CropBox'ı kaydırılmış) PDF'te VURGU koordinatı doğrulanmadı.**
      Faz 8'de "yazı ekle" ölçüldü (Syncfusion'ın çizim kökeni CropBox'ın sol-üstü,
      `pdf_fixture_smoke_test`); vurgu ise pdfium'un karakter kutularından geliyor ve
      testte pdfium yok. Örnek: `test/fixtures/pdf/cropbox.pdf` — telefonda vurgula,
      başka okuyucuda yerinde mi bak.
- [ ] **graphify güncellemesi:** yeni `lib/services/fm/*` ve `lib/screens/fm/*`
      düğümleri graf raporunda yok. 2026-08-04 turunun getirdikleri de eksik:
      `XlsxStyleEdit`, `XlsxCondRuleWrite`, `_ColumnFilterSheet`,
      `_NoteMarkPainter`, `XlsxComment`, `turkishSearchPattern`,
      `PptxRender.notes`, `DocxEditor.setListStyle`. Araç bulut oturumunda
      kurulu değil (npm'de de yok) — `graphify update .` yerelde çalıştırılmalı.

## Dosya yöneticisi — araştırma karşılaştırmasından KALAN maddeler (2026-07-25)
Referanslar: Fossify File Manager, Material Files, AnExplorer, ekran görüntüsündeki
File Manager+. Bizde artık olanlar: pano/kategoriler, gezgin+çoklu seçim, çöp
kutusu, bellek analizi, **yinelenen dosya bulucu**, arşiv (RAR5/RAR4/7z okuma +
parolalı üretme), medya oynatıcı, galeri, favoriler, arama. Kalanlar:
- [x] ~~**Ağ/bulut (FTP, SMB, WebDAV, Drive)**~~ → madde ESKİMİŞTİ:
      2026-07-30'da yapıldı — `screens/fm/remote/` (SFTP/FTP/FTPS/SMB/WebDAV,
      ağda arama, bağlantı sınama) ve `drive_screen.dart` (Google Drive).
      Kalan belirsizlikler ayrı maddelerde (SMB3, SMB portu, cihaz doğrulaması).
- [ ] **Çift bölme (dual pane)** — tablet/yatay ekranda iki klasör yan yana,
      sürükle-bırak taşıma. Gezgin push-tabanlı olduğu için orta ölçekli iş.
- [x] ~~**Toplu yeniden adlandırma**~~ → madde ESKİMİŞTİ:
      `widgets/fm/batch_rename_sheet.dart` + `services/fm/batch_rename.dart`
      zaten var (desen + önizleme, uzantı korunuyor).
- [x] ~~**Varsayılan başlangıç klasörü** ayarı~~ → **YAPILDI 2026-08-08:**
      Dosya yöneticisi ayarları > **Açılış klasörü**. Boşken pano ilk ekran
      (davranış değişmedi); klasör silinmişse sessizce panoya düşer.
- [x] ~~**Dosya seçici olarak davranma**~~ → madde ESKİMİŞTİ (2026-09-26
      denetimi): 2026-08-10'da yapılmış — `ci/PickerActivity.kt`
      (GET_CONTENT, "Şuradan aç" çekmecesindeki ok) + `ci/DosyaProvider.kt`
      (OPEN_DOCUMENT çekmecesinde kök satırı).
- [ ] **SD karta yazma (SAF)** — Android bazı cihazlarda ikincil birime doğrudan
      yazmayı engeller; gerekirse `SAF` tree izni akışı eklenmeli. (2026-10-17: SD
      birleşik depolama da yol üzerinden yazıyor; yazılamayan kartta `sd_readonly`
      uyarısı veriyor — SAF desteği gelince oraya da bağlanmalı.)

## PDF turu sonrası kalanlar (2026-07-26, 2. tur sonrası güncel)
- [x] ~~Vurgu koordinatı /Rotate=0 varsayıyor~~ → **YANLIŞ ALARM, ölçüldü
      2026-07-26:** dört açıda da yazılan `/Rect` birebir aynı. İki taraf da ham
      sayfa uzayında konuşuyor. Uyarı silindi, davranış testle sabitlendi.
- [x] ~~AI düzenleme sayfa düzenini korumuyor~~ → **YAPILDI (3. tur):**
      `PdfContentEditor` ile GERÇEK yerinde düzenleme — belgenin kendi metni
      değişiyor, yazı tipi/punto/konum korunuyor, eski metin siliniyor,
      değişiklik dosyanın sonuna ekleniyor (özgün baytlara dokunulmuyor).
      Üstünü kapatan eski yol yalnız yedek (reddedilirse, onay alarak).
- [x] ~~Yerinde düzenleme özel kodlamalı fontlarda çalışmaz~~ → **ÇÖZÜLDÜ
      (4. tur):** fontun `/ToUnicode` tablosu okunup ters çevriliyor; alt küme
      gömülü ve Type0/Identity-H fontlar artık çalışıyor, yeni metin belgenin
      ÖZGÜN yazı tipiyle yazılıyor. Kalan sınır: alt küme fontta HİÇ geçmemiş
      bir harf yazılamaz (glif yok) — reddediliyor.
- [x] ~~Yeni metin uzunsa satırın kalanı sağa kayar (PDF metni yeniden
      akıtmaz)~~ → **YAPILDI (5. tur):** belgenin kendi glif genişlikleriyle
      ölçülüp satırın kalanı kaydırılıyor (`pdf_font_metrics` + `scanContent`).
      Taşarsa kaydetmeden önce uyarı veriliyor.
- [x] ~~Arka plana alınan iş için kalıcı gösterge yok~~ → **YAPILDI:** kalıcı
      alt şerit (iş adı + sayaç + Durdur), sayfa değişse de kalıyor.
- [x] ~~Taramada döndürme yok~~ → **YAPILDI:** önizlemede 90° çevirme.
- [ ] **Agresif sıkıştırma (resme çevirerek) YAPILMADI — yol kapalı.**
      Cihazda JPEG kodlayıcı yok (`dart:ui` yalnız PNG üretir) ve PNG taranmış
      sayfada özgün JPEG'den büyük çıkar → "sıkıştır" dosyayı şişirirdi.
      Gerekirse `image` paketi (yeni bağımlılık, yavaş) veya platform kanalı.
      Yapılırsa metin katmanı kaybolacağı için AYRI ve açıkça uyaran bir
      seçenek olmalı, sessizce değil.
- [ ] **graphify güncellemesi:** araç bu ortamda kurulu değil; yeni düğümler
      (`pdf_reload`, `pdf_save`, `perspective`, `scan_edit/review`,
      `pdf_ai_edit`, `pdf_dict`, `pdf_font_metrics`, `pdf_edit_flow`,
      `pdf_inline_editor`, `ai_rewrite_sheet`) grafta eksik; silinen
      `pdf_text_replace_screen` hâlâ duruyor.
- [ ] **APK ~199 MB (build 123).** Bu iş ÖNCESİNDE de böyleydi (build 120:
      196 MB → build 123: 199 MB, artış yalnız yeni kod), yani bu turun
      getirdiği bir şişme değil. Ama "sade/hızlı" konumlandırma ve Play Store
      için fazla büyük. Muhtemel kaynaklar: tek APK'da tüm ABI'ler (pdfium +
      ML Kit + video/ses yerel kütüphaneleri), gömülü fontlar, WebView Word
      motoru. Yol: `--split-per-abi` ya da App Bundle (AAB) — indirilen boyut
      3-4 kat düşer. Release akışının değişmesi gerekir, ayrı iş.

- [x] ~~**Windows'ta kırık 4 test (yerel doğrulamayı köreltiyor)**~~ →
      **YAPILDI 2026-08-08:** kök neden TEMİZLİKTİ. `tearDown`daki çıplak
      `deleteSync(recursive: true)` Windows'ta dosya kilidi yüzünden istisna
      atıyor ve **test geçmişken** kırmızı yakıyordu. Tek yardımcı:
      `test/support/temp_dir.dart` — kısa yeniden deneme, sonra SESSİZCE pes
      (temizlik bir doğrulama değildir; silinemezse işletim sistemi toplar).
      Tüm test dosyaları buna geçirildi; `fm_archive_rar_test`teki `rethrow`lu
      döngü de kaldırıldı. `volumePath` POSIX sorunu zaten çözülmüştü.
      **Doğrulanmadı:** Windows makine bu oturumda yok — Linux'ta yeşil,
      yerelde kullanıcı bakmalı.

- [x] ~~**Gizli satır/sütun kaydetmede kayboluyor (Excel sadakati).**~~ →
      **YAPILDI** (2026-08-02'de doğrulandı; madde eskimişti). Önerilen yol
      uygulanmış: `services/xlsx_save_patch.dart` `save()` sonrası zip'i açıp
      `<col hidden="1">` / `<row hidden="1">` yazıyor, `XlsxEditor.save`
      `layout.hiddenRows/hiddenCols`u geçiriyor. Testli:
      `xlsx_save_patch_test` (aralık bölme dahil).
- [x] ~~**Tamamen BOŞ satırın yüksekliği kaydedilmiyor.**~~ → **YAPILDI**
      (2026-08-02'de doğrulandı; madde eskimişti). `XlsxEditor.save`
      `rowHeightsPt`e yalnız `_isEmptyRow` satırlarını koyuyor, yama `<row>`u
      `ht`+`customHeight` ile üretiyor.

## Kağıt teması — 2. tur devir notundan kalanlar (2026-08-05)
Tasarımın `2a` bölümü (belge ekranları). Tema, palet, kanvas, rozet ve Excel
sayı hücreleri UYGULANDI; aşağıdakiler bilinçli olarak bu tura alınmadı çünkü
her biri ilgili editörün seçim/veri modeline dokunuyor ve cihazda görülmeden
doğrulanamıyor:
- [x] ~~**Word:** "Seçili paragrafı AI ile yeniden yaz" şeridi~~ → **YAPILDI
      2026-08-04:** `sendSelectionText`/`replaceSelectionText` köprüsü engeli
      kaldırdı; sonuç seçimin YERİNE yazılıyor.
- [x] ~~**Slayt:** kanvasın altında konuşmacı notu şeridi~~ → **YAPILDI
      2026-08-04:** `pptx_render.notes()` `notesSlide*.xml`i okuyor (yalnız
      `body` yer tutucusu).
- [x] ~~**Excel:** sayfa sekmelerinin çip görünümü~~ → zaten `ChoiceChip`di
      (madde eskimişti).
- [ ] **Belge sayfası** çerçevesi (`#FBF8F1` zemin + 1px `#D2C8B4` + yarıçap 4)
      yalnız kanvas düzeyinde uygulandı; PDF/Word sayfa kutusunun kendisi
      pdfrx/WebView içinde çiziliyor, oraya dokunmak ayrı bir tur.
