# KALANLAR — canlı kalan-iş listesi (biten madde silinir)

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
> 3. **Gerçek kalan iş** — Word tablo/resim düzenleme, Word'de karakter
>    düzeyinde punto, Excel grafik ekleme ve köşegen doldurma, çift bölme,
>    dosya seçici intent'i, SAF ile SD karta yazma, listede klasör boyutu,
>    `/ToUnicode`suz PDF'lerde AGL tablosu, iki yana yaslı satırın yeniden
>    dağıtımı, ses için bildirim/kilit ekranı kontrolleri, APK boyutu
>    (split-per-abi/AAB). Her biri kendi başına bir tur.

- [ ] **Liste simgesi 68 dp'ye YÜKSELEMİYOR — `ListTile` tavanı** (2026-08-30).
      `FmEntryListTile` 68 dp istiyor; Material'in `ListTile`'ı `leading`
      yuvasını `maxHeight: 56` ile kesiyor (yoğun satırda 48). Şekil artık
      kutuya kendi oranıyla sığıyor (klasör genişliği 51 → 68 dp, yan boşluk
      sıfır) ama YÜKSEKLİK hâlâ 56'da duruyor. Aşmak için `leading` yuvası
      bırakılıp satır kendi `Row`'umuzla kurulmalı (seçili zemin, şekil, ink,
      başlık/alt satır stilleri ve trailing elle taşınacak) — gözatıcı,
      kategori, arama ve "son açılanlar" listelerinin hepsini etkiliyor,
      o yüzden ayrı tur.

- [ ] **Sayfanın SON paragrafında taşma denetimi yok** (2026-08-30 bulgusu,
      yerinde çeviri turunda çıktı). `findParagraphs`, paragrafın altında
      başka satır yoksa `roomBelow`u `double.infinity` veriyor: sayfanın son
      paragrafı uzayınca (çeviri özgününden %20 uzun olabiliyor) sayfa
      kenarının ALTINA taşıyor ve hiçbir uyarı çıkmıyor. `pageBox` zaten elde
      olduğu için düzeltmesi kolay (`roomBelow = son taban çizgisi − sayfa
      altı`), ama paragraf düzenlemenin GENEL davranışını değiştiriyor
      (mevcut `pdf_paragraph_test`/`pdf_reflow_test` beklentileri) → ayrı tur.

- [ ] **cihaz doğrulaması (kullanıcı) — 2026-08-30 turu.** Bu turda değişenler
      yalnız CI'da derlendi; telefonda bakılacaklar: (a) dosya listesinde
      simgelerin üstündeki uzantı yazısı ("XLSX", "DOCX") artık NET mi —
      bulanıklığın kök nedeni yazının birim karede dizilmesiydi; (b) Drive'da
      büyük bir dosya indirirken "Arka plana al" ve "Durdur" çalışıyor mu,
      durdurulan indirme klasörde yarım dosya BIRAKMIYOR mu; (c) PDF'te
      yerinde düzenlemede satırın biraz üstüne/altına dokunmak imleci o
      sütuna taşıyor mu, ◀ ▶ okları tek karakter ilerletiyor mu; (d) art arda
      çıkan uyarı şeritleri artık sıra beklemeden birbirinin yerine geçip
      kendiliğinden kayboluyor mu; (e) PDF düzenleyicide görsel seçip
      döndür/ayna — görsel merkezinde dönüyor mu, iki kez döndürülebiliyor
      mu; (f) **PDF çevir → "belgenin kendisi"** — çıkan belge özgününün
      düzeninde mi, kaç paragrafın atlandığı doğru mu yazıyor (Türkçe→Arapça
      gibi bir çiftte gömülü font harfleri taşımadığı için çoğu paragrafın
      atlanması BEKLENEN davranış).

- [ ] **MAĞAZA YOLU (2026-08-28 durum değerlendirmesi) — sırayla, her biri
      kendi turu.** Dört temel bu turda yapıldı (artan versionCode, imza
      sızıntısının kapatılması, hata kaydı, gizlilik politikası). Kalanlar:
      (a) **targetSdk 36** — Play 31 Ağu 2026'dan itibaren istiyor; bizim CI
      Flutter **3.29.3**'e çivili (targetSdk 35) ve pubspec'teki onlarca
      sürüm sabiti "3.35+ ister" diyor → **sürüm duvarını yıkma turu**,
      takvim aleyhimize, en acil madde;
      (b) **AAB** çıktısı + `android/` klasörünün depoya alınması (Play yeni
      uygulamada APK kabul etmiyor; her derlemede `flutter create` üretmek
      Play imza/sürüm yönetimi için kırılgan);
      (c) **izin diyeti / Play varyantı (flavor):** `QUERY_ALL_PACKAGES` +
      `PACKAGE_USAGE_STATS` (Uygulamalar ekranı) ve
      `REQUEST_INSTALL_PACKAGES` + `.apk` intent'leri Play'de yüksek red
      riski — bunlar yalnız GitHub sürümünde kalsın;
      (d) **Drive kapsamı `drive` → `drive.file`** (yayına almak yıllık
      ücretli CASA denetimi istiyor — bkz. HAFIZA 2026-08-05);
      (e) **boyut:** ~91 MB/ABI; ffmpeg (~39 MB) isteğe bağlı indirilen
      modüle, ML Kit unbundled, font altkümesi kırpılsın → hedef < 35 MB;
      (f) **Veri Güvenliği formu** `assets/privacy/tr.md`in 1-2. bölümünden
      doldurulacak;
      (g) ~~`flutter analyze` CI kapısı~~ **BİTTİ** (2026-08-28).

- [ ] **Flutter 3.44.9 DENEME DERLEMESİ (kullanıcı tetikleyecek)** —
      2026-08-28: Actions > **Run workflow** > "Denenecek Flutter sürümü" =
      `3.44.9`. Ölçüldü: bağımlılıklar değişmeden çözülüyor, 1730 test yeşil,
      yalnız 24 kullanımdan-kaldırma uyarısı var; belirsiz olan **Android
      derleme zinciri** (AGP 9.0.1 / Gradle 9.1 / Kotlin 2.3.20 / NDK 28).
      Yeşil çıkarsa `FLUTTER_VERSION` varsayılanı 3.44.9'a taşınır → targetSdk
      **36** (Play'in 31 Ağu 2026 şartı) kendiliğinden gelir ve yereldeki
      sürümle CI aynı olur. Ardından 24 uyarının temizlenmesi ayrı bir tur
      (`RadioGroup`, `DropdownButtonFormField.initialValue`,
      `Matrix4.translateByDouble/scaleByDouble`) — bunlar 3.29.3'te DERLENMEZ,
      yani ancak varsayılan taşındıktan sonra yapılabilir.

- [ ] **Slayt ↔ PDF cihaz doğrulaması (kullanıcı)** — 2026-08-08:
      (a) bir `.pptx` aç → alt çubukta **PDF** → üretilen PDF'te slaytlar
      **ekrandakiyle birebir** mi (şekiller, renkler, görseller yerinde mi),
      (b) o PDF'te **yazı seçilip kopyalanabiliyor** ve aranabiliyor mu
      (görünmez metin katmanı), (c) görsel içeren bir slayt PDF'te boş
      çıkıyor mu (çıkıyorsa önbellek/kare bekleme yetmemiş demektir),
      (d) çok slaytlı (20+) bir destede bellek/donma sorunu var mı,
      (e) bir **PDF** aç → ⋮ → **Slayta dönüştür** → çıkan `.pptx`
      düzenleyicimizde açılıyor mu, (f) aynı dosya **PowerPoint / Google
      Slaytlar**'da onarım uyarısı olmadan açılıyor mu (en kritik madde —
      paket geçerliliği yalnız orada kanıtlanır), (g) bölme mantıklı mı
      (başlıklar başlık, her cümle ayrı slayt değil).

- [ ] **KALANLAR turu cihaz doğrulaması (kullanıcı)** — 2026-08-08:
      (a) Ayarlar > **Dil** > English seç → **dosya yöneticisi, PDF, slayt ve
      sohbet** ekranlarında da artık Türkçe metin KALMAMALI, (b) bir video
      izlerken ekrana dokunmadan bekle → **ekran sönmemeli**; duraklatınca
      normal zaman aşımına dönmeli, (c) bir dosyayı kopyala → **aynı adlı
      dosyanın olduğu** klasöre yapıştır → İkisini de tut / Atla / Üzerine yaz
      soruluyor mu, üçü de doğru davranıyor mu, (d) Dosya yöneticisi ayarları >
      **Açılış klasörü** bir klasör seç → uygulamayı kapat-aç → doğrudan orada
      açılıyor mu, (e) bir mp3 aç → **kapak resmi, sanatçı ve albüm** geliyor
      mu, (f) Belgeler listesinde **PDF'ler kapak sayfalarıyla** mı görünüyor,
      çok PDF'li klasörde kaydırma akıcı mı.

- [ ] **Pil/başarım turu cihaz doğrulaması (kullanıcı)** — 2026-08-07 (7):
      (a) çok sayıda büyük fotoğrafı olan bir klasörde galeriyi aç, sağa-sola
      hızlı kaydır → takılma/kasma AZALDI mı, uygulama artık kendiliğinden
      kapanıyor mu (eskiden tam çözünürlük belleği şişiriyordu), (b) bir
      fotoğrafı 3-4 kat **yakınlaştırınca yazı hâlâ keskin** mi (çözünürlük
      kademeli artıyor), (c) bir video aç → ana ekrana çık → **ses/görüntü
      duruyor** mu, uygulamaya dönünce kaldığı yerden devam ediyor mu,
      (d) videoyu KENDİN duraklat → arkaya al → dön: kendiliğinden BAŞLAMAMALI,
      (e) çöp kutusu doluyken panodaki kutunun nefes alması birkaç saniye sonra
      duruyor mu (sonsuza kadar oynamamalı), (f) Ayarlar > **Pil ve başarım** →
      "Yüksek tazeleme hızı"nı kapat → kaydırma hissi 60 Hz'e düşüyor mu,
      uygulamayı kapatıp açınca tercih korunuyor mu.

- [ ] **2026-08-02 (5. tur) arayüz cihaz doğrulaması (kullanıcı).**
      (a) Excel biçim çubuğu artık kısa mı (Kalın · İtalik · Hizalama ·
      Sayı biçimi · Σ · **Daha fazla**) ve yatayda kaydırmaya gerek kalmıyor
      mu, (b) **Daha fazla** sayfası açılıp Pano/Sayı/Satır/Sütun grupları
      ETİKETLİ görünüyor mu, dokununca sayfa kapanıp iş yapılıyor mu,
      (c) hizalama menüsü etkin hizalamayı işaretli gösteriyor mu,
      (d) PDF'te üst çubuk daha ferah mı, döndürme ⋮ menüsünde bulunuyor mu,
      (e) belge başlığı artık kırpılmadan okunuyor mu.
      **Sonraki adım (istenirse):** aynı kural Word ve slayt biçim
      çubuklarına da uygulanabilir — ikisi şu an sınırda (9 ve 11 kontrol).

- [ ] **2026-08-02 (3-4. tur) cihaz doğrulaması (kullanıcı).**
      **Excel:** (a) bir sütun seç → biçim çubuğundaki **#** menüsünden
      *Para (₺)* / *Yüzde* / *Tarih* seç → hücreler o biçimde görünüyor mu,
      (b) **kaydet → masaüstü Excel'de aç**: biçimler DURUYOR mu (en kritik
      madde — eski yol dosyayı hiç kaydettirmiyordu), (c) **ondalık artır/
      azalt** düğmeleri çalışıyor mu, (d) biçim verilen hücrenin kalın/renk/
      kenarlığı BOZULMADI mı, (e) hepsi **geri al** ile geri dönüyor mu.
      **Word:** (f) akış (Mobil) görünümünde bir paragrafı **sil** → üstteki
      **geri al** paragrafı KENDİ yerine geri getiriyor mu (sona değil),
      (g) paragraf **ekle** → geri al onu kaldırıyor mu, (h) yazarken
      klavyenin kendi geri alması hâlâ çalışıyor mu.


## Word "gerçek mobil Word gibi olsun" — kalan yol haritası
2026-08-02'de yapısal geri al/yinele geldi. Kalanlar:
- [x] ~~**Belge içinde bul / değiştir yok**~~ → **YAPILDI 2026-08-04:** JS
      köprüsü (`findAll`/`findGo`/`replaceHit`/`replaceAll`). Arama DOM'a hiç
      dokunmuyor (eşleşme `Range` ile seçiliyor) → düzenleme kapalıyken de
      çalışıyor. Katlama Türkçe duyarlı.
- [ ] **Yazı tipi/punto PARAGRAF düzeyinde** — seçimin ortasındaki üç kelimeye
      ayrı punto verilemiyor (aşağıdaki "Bilinen eksik-risk" maddesi).
- [x] ~~**Metin rengi / vurgu / madde işareti / numaralandırma** düğmeleri yok~~
      → **YAPILDI 2026-08-04:** renk/vurgu seçime (`execCommand` + `data-fk-*`
      işaretleri), liste PARAGRAF ÖZELLİĞİ olarak (`w:numPr` + üretilen
      `numbering.xml`). `insertUnorderedList` bilinçli kullanılmadı: `<p>`yi
      `<li>`ye çevirip paragraf eşlemesini bozuyordu (HAFIZA 2026-08-04 §D).
- [ ] **Tablo düzenleme yok** (tablolar görüntüleniyor, düzenlenemiyor).
- [ ] **Resim ekleme/taşıma yok.**
- [x] ~~**Seçili metin çevirisi yok**~~ → **YAPILDI 2026-08-04:**
      `sendSelectionText` köprüsü; "Seçimi çevir" ve "Seçimi AI ile düzelt"
      alt çubukta.
- [ ] Harf harf yazma geri alma yığınına girmiyor (bilinçli — HAFIZA 4. tur).

## Excel "gerçek mobil Excel gibi olsun" — kalan yol haritası
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
- [ ] **Sayfa TAŞIMA yok (bilinçli).** `excel 4.0.6` sayfa sırasını kendi
      haritasının ekleme sırasından yazıyor ve sırayı değiştirecek API
      sunmuyor; zorlamak her sayfayı kopyala-sil ile yeniden kurmak demek.
- [ ] **Grafik EKLEME yok** (PPTX tarafında grafik çizimi var, Excel'de yok).
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
- [ ] **Köşegen doldurma** yok — tek eksende doldurma var.

- [ ] **2026-08-02 (2. tur) cihaz doğrulaması (kullanıcı) — Excel düzenleme.**
      Bir .xlsx aç: (a) bir hücreye yaz → üstteki **geri al** oku eski değeri
      geri getiriyor, **yinele** tekrar yazıyor mu, (b) aralık seç → **kopyala**
      → başka yere **yapıştır**; formül yapıştırınca başvurular kaydı mı
      (`=A1*2` bir sağa → `=B1*2`), (c) **kes** → yapıştır: kaynak yapıştırınca
      mı boşalıyor, (d) seçimin **sağ alt köşesindeki küçük kare** parmakla
      aşağı sürüklenebiliyor mu (sayfa kaymadan!), 1-2 yazıp sürükleyince
      3,4,5 geliyor mu, "Ocak" sürükleyince "Şubat" geliyor mu, (e) sayı
      sütununun altına **Σ** basınca doğru aralığı topluyor mu, (f) 🔍 →
      **Tümünü değiştir** çalışıp tek geri alma adımında geri alınıyor mu,
      (g) satır/sütun **sil** → geri al: veri VE biçim geri geliyor mu,
      (h) uygulamadan kopyalayıp **başka bir uygulamaya** (Not Defteri/Excel)
      yapıştırınca tablo düzgün mü (sekmeyle ayrılmış).

## Yarım kalan
- [ ] **2026-08-02 turu cihaz doğrulaması (kullanıcı) — slayt şekilleri.**
      İçinde süreç/akış diyagramı olan gerçek bir .pptx aç: (a) **oklar, üçgen,
      elmas, chevron, yıldız, altıgen, artı, silindir, akış şeması kutuları
      artık kendi biçiminde mi** (eskiden hepsi düz dikdörtgendi), (b) **geniş
      bir elips** (basık oval) artık daire değil oval mi, (c) kırpılmış bir
      **fotoğraf doğru kadrajda ve doğru en-boy oranında** mı, (d) kenarlıklı
      bir fotoğrafın **çerçevesi görünüyor** mu, (e) yuvarlatılmış dikdörtgenin
      köşe yuvarlaklığı PowerPoint'tekiyle aynı mı, (f) aynalanmış (flipH/flipV)
      bir ok/üçgen doğru yöne bakıyor mu, (g) konuşma balonunun kuyruğu var mı.
      **Bilinen sınır:** bulut (`cloud`) ve gözyaşı (`teardrop`) yaklaşık
      çiziliyor; `bentArrow`/`circularArrow`/`ribbon` gibi tanımsız geometriler
      hâlâ dikdörtgen düşüyor (bilinçli — yanlış biçim yerine kutu).
- [ ] **2026-08-01 turu cihaz doğrulaması (kullanıcı)** — (a) slaytta her kartın
      üstünde ve sağ alt rozette **"Slayt 3 / 12"** yazıyor mu, rozete
      dokununca "Slayta git" açılıp o slayda ATLIYOR mu (yakınlaştırılmış
      hâlde de doğru yere), (b) üstteki 🔍 ile aranan kelime bulunuyor,
      ‹ › eşleşmeler arasında geziyor, altındaki bağlam satırı hangi slaytta
      olduğunu söylüyor mu, (c) alt çubuktaki **AI özet** → "Kısa"/"Detaylı"
      seçenekleri geliyor ve özet slayt numaralarına atıf yapıyor mu,
      (d) slaytta bir metin kutusuna dokunup düzenlemeye geçince **geri tuşu**
      ekrandan çıkmak yerine düzenlemeyi kapatıyor mu (Word'de de aynı),
      (e) Word'de **yakınlaştırınca yazı keskin mi** (pinch artık JS/CSS zoom;
      bulanıklık gitmeli), ölçek rozeti (%) çıkıyor mu, (f) Word biçim
      çubuğundaki **yazı tipi/punto** seçimi paragrafa uygulanıp KAYDEDİLİYOR
      mu (kaydet → Word'de aç → font ve punto korunmuş olmalı), (g) Word'de
      sol alt **"Sayfa 3 / 12"** rozeti doğru sayıyor ve dokununca o sayfaya
      gidiyor mu, (h) Excel durum çubuğunun sağında **"Sayfa 1 / 3"** var mı,
      (i) **dondurulmuş bölmesi olan** bir Excel dosyasında tek hücre değiştirip
      kaydet → masaüstü Excel'de aç → bölme, ızgara ayarı ve süzgeç okları
      DURUYOR mu.
      **2. tur (aynı gün, kullanıcı ekran görüntüsü üzerine):** (j) Word'de
      belge açılır açılmaz sayfa **ekran genişliğini DOLDURUYOR** mu (önceden
      %59'unu kaplıyordu, yazı bu yüzden okunaksızdı), (k) slaytta konum rozeti
      ve Word'de sayfa rozeti artık **ortada** — AI düğmesi hiçbirini kesmiyor,
      Word'de zoom düğmeleri de solda ve FAB'ın altında kalmıyor.
- [ ] **Google Drive cihaz doğrulaması (kullanıcı)** — 2026-07-30: Pano →
      Araçlar → **Google Drive** → (a) "Google ile bağlan" hesap seçtiriyor ve
      Drive izni soruyor mu, (b) bir dosyaya uzun bas → **Drive'a yükle** →
      dosya gerçekten Drive'a çıkıyor mu, (c) Drive ekranında o dosya
      listeleniyor mu, dokununca inip AÇILIYOR mu, (d) kapsam şeridi
      ("yalnız bu uygulamayla yüklediğiniz…") okunuyor mu, (e) silme çalışıyor
      mu, (f) **google-services.json yoksa** giriş penceresi hiç açılmıyor
      olmalı — çökme DEĞİL. NOT: Drive, Firebase ile aynı OAuth istemcisini
      kullanıyor; Firebase kurulmamışsa Drive da çalışmaz (FIREBASE_SETUP.md).
- [ ] **NAS cihaz doğrulaması (kullanıcı)** — 2026-07-30: Pano → Araçlar →
      **Ağ depolama** → (a) **Ağda ara** telefonun Wi-Fi'sindeki NAS'ı buluyor
      mu (mDNS + port taraması), (b) elle eklenen SFTP/FTP/FTPS/WebDAV
      bağlantısı **Bağlantıyı sına** ile yeşil veriyor mu, (c) klasörler
      geziliyor, dosya dokununca inip AÇILIYOR mu, (d) **Buraya yükle** /
      yeni klasör / yeniden adlandır / sil çalışıyor mu, (e) parola kaydetme
      KAPALIYKEN her bağlanışta soruluyor mu, (f) yanlış adres/parola
      ANLAŞILIR hata veriyor mu (ham SocketException değil).
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
- [ ] **"Ağdan erişim" cihaz doğrulaması (kullanıcı)** — 2026-08-29'da
      yeniden yazıldı. Pano → araçlar → **Ağdan erişim** → **BAŞLAT** →
      (a) ekranda `ftp://<ip>:2121`, kullanıcı adı ve parola yazıyor mu,
      (b) PC'nin dosya gezginine bu adres yazılınca **kök telefondaki
      kutuları** gösteriyor mu (Telefon · Indirilenler · Kamera · Resimler ·
      Videolar · Ses · Belgeler · Arsivler · Uygulamalar), kutulara girince
      dosyalar listeleniyor, inip yükleniyor mu, (c) **uygulamadan çıkıp başka ekranda gezerken /
      ekran kapalıyken aktarım sürüyor mu** (asıl düzeltilen şey bu),
      (d) bildirim panelinde kalıcı bildirim duruyor ve dokununca ekrana
      götürüyor mu, (e) panonun üstündeki "Ağdan erişim açık" şeridi
      görünüyor ve **Kapat** çalışıyor mu, (f) *Yazma izni* kutusu kapalıyken
      PC'den silme reddediliyor mu, (g) *Gizli dosyaları göster* kapalıyken
      `.` ile başlayan klasörler PC'de görünmüyor mu, (h) uygulamayı son
      kullanılanlardan kapatınca paylaşım ve bildirim kayboluyor mu.
- [x] ~~**FTP sunucusu arka planda çalışmıyor (bilinçli).**~~ → 2026-08-29:
      kullanıcı bunu bir HATA olarak bildirdi, karar geri alındı. Sunucu artık
      `FtpService`te yaşıyor ve ön plan servisiyle arka planda sürüyor;
      "unutma" riskinin karşılığı kapatmak değil GÖRÜNÜRLÜK oldu (kalıcı
      bildirim + pano şeridi). Bkz. HAFIZA 2026-08-29 (II).
- [ ] **Dil desteği cihaz doğrulaması (kullanıcı)** — 2026-07-30: Ayarlar →
      **Dil** → English / العربية seç → (a) ana ekran, alt sekmeler, Ayarlar,
      Excel ve Word ekranları o dilde mi, (b) **Arapça'da arayüz sağdan sola**
      mı akıyor (geri oku, sekme sırası, kaydırıcılar), (c) Arapça'da yazı
      tipi okunur mu (cihazın Arapça fontu), (d) dil seçimi uygulamayı
      kapatıp açınca korunuyor mu, (e) "Sistem" seçiliyken telefon dili
      İngilizce/Arapça ise uygulama o dilde mi açılıyor.
- [x] ~~**Kalan ekranlar hâlâ Türkçe**~~ → **BİTTİ 2026-08-08.** Madde
      eskimişti (yazıldığında 4 ekran çevriliydi, bugün tablo 1700+ anahtar).
      Kaynakta kalan ~50 sabit dize taşındı; ortak sözcükler `common.*`
      altında toplandı. **Bekçisi var:** `test/l10n_literals_test.dart`
      kaynağı tarıyor — `Text(...)`/`tooltip:`/`label:` gibi yerlere doğrudan
      Türkçe yazan bir değişiklik testi KIRAR. İzin listesi dar ve gerekçeli
      (marka adı, JSON anahtarı, desen sözdizimi).
- [ ] **Sağdan sola Excel/Word cihaz doğrulaması (kullanıcı)** — 2026-07-30:
      (a) Arapça bir .xlsx aç → A sütunu SAĞDA mı, kaydırma sağ kenardan mı
      başlıyor, hücre metni sağa mı yaslı, sayılar sola mı, (b) ⋮ > **Sayfa
      sağdan sola** ile yön değişiyor mu, kaydedip Excel'de açınca korunuyor
      mu, (c) gizlediğin sütunu kaydedip Excel'de aç → gizli KALMALI,
      (d) Arapça bir .docx aç → sayfa görünümünde metin sağdan mı akıyor,
      Arapça harfler kutu (tofu) çıkmıyor mu, (e) ⋮ > Metin düzenleyicide
      paragraflar sağa yaslı mı.
- [ ] **2026-07-28 turu cihaz doğrulaması (kullanıcı)** — (a) resmi PDF'te
      *Düzenleyici → Metin* → paragrafa dokun → artık ne "metin dışı çizim var
      (ET)" ne de "(Q)" uyarısı ÇIKMAMALI; (b) **ortalı** bir başlığı (DAĞITIM
      gibi) kısalt/uzat → sayfada ORTALI kalmalı; (c) *Görsel* modunda armayı
      taşı → KESİLMEMELİ; (d) Word'de alt çubuktaki **Mobil** düğmesi → yazı
      okunur boyuta gelmeli, **Sayfa** ile geri dönmeli, düzenleme hâlâ
      çalışmalı; (e) Word/Excel/slayt/görüntüleyicide üstteki ⋮ ve simgelerde
      artık alttakilerin ikizi OLMAMALI, ama Word/Slaytta düzenlemeye geçince
      üstte **Kaydet** görünmeli.
- [ ] **PDF editörü cihaz doğrulaması (kullanıcı)** — 2026-07-27: PDF aç → alt
      çubuk **Düzenleyici** → (a) *Metin* modunda paragraf kutuları çıkıyor mu,
      dokununca pencere açılıp özgün metni üstte gösteriyor mu, "Uygula" sonrası
      sonuç sayfada HEMEN görünüyor mu, yazı tipi/punto/hizalama korunuyor mu,
      (b) kelimeyi uzatınca satır düzgün sarıyor mu, kısaltınca boşluk düzgün mü,
      (c) *Görsel* modunda logo/QR seçilip sürükleniyor/boyutlanıyor/siliniyor mu,
      (d) *Filigran* modunda "KOPYADIR" benzeri damga listeleniyor ve
      kaldırılıyor mu, gerçek içerik listede ÇIKMAMALI, (e) *Sayfa* modunda
      90° sağa/sola dönüyor mu, (f) **Geri al** işe yarıyor mu, (g) **Kaydet** →
      "Üzerine yaz / Kopyasını kaydet / Klasör seç" ve "AÇ" düğmesi çalışıyor mu,
      (h) kaydetmeden çıkınca özgün dosya DEĞİŞMEMİŞ olmalı.
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
- [ ] **Okuma deneyimi cihaz doğrulaması (kullanıcı)** — 2026-07-25 Faz 4: PDF aç →
      (a) ay simgesi gece modunu açıyor mu, sayfa ters renkte okunaklı mı,
      (b) içindekiler (☰ simgesi) olan bir PDF'te başlığa dokununca o sayfaya
      gidiyor mu, olmayan belgede "içindekiler yok" diyor mu, (c) içinde köprü
      olan PDF'te bağlantıya dokununca ONAY penceresi tam adresi gösteriyor mu,
      "Aç" tarayıcıyı açıyor mu, iç bağlantı sayfaya atlıyor mu, (d) ⋮ "Sesli oku"
      → Türkçe okuyor mu, duraklat/devam/durdur çalışıyor mu, ekrandan çıkınca
      susuyor mu (dispose), (e) taranmış PDF'te "önce OCR" uyarısı geliyor mu.
- [ ] **İmza cihaz doğrulaması (kullanıcı)** — 2026-07-25 Faz 2: PDF aç → ⋮
      "İmzala" → (a) imza penceresi çiziyor mu, "Tamam" sonrası imza HATIRLANIYOR
      mu (ikinci kez sormamalı), (b) imza kutusu parmakla sürüklenip kaydırıcıyla
      büyüyor mu, (c) "Bas" sonrası imza sayfada TAM gördüğünüz yerde mi,
      (d) yakınlaştırınca keskin mi (vektör), (e) **döndürülmüş sayfada** (araçlardan
      90° döndürüp imzalayın) imza yan yatık ya da başka köşede mi çıkıyor —
      koordinat çevirisi birim testli ama cihazda görsel teyit edilmedi.
- [ ] **Belge tarayıcı cihaz doğrulaması (kullanıcı)** — 2026-07-25 Faz 3: ana
      ekranda "Belge Tara" → (a) Google tarayıcı arayüzü açılıyor mu, kamera izni
      soruluyor mu, (b) kenar tespiti + kırpma + filtre "tarayıcıdan çıkmış gibi"
      mi, (c) çok sayfa çekip tek PDF oluyor mu, (d) "Yazıları da tanı" seçilince
      PDF içinde arama çalışıyor mu, (e) belge Son belgeler'de görünüyor mu,
      (f) PDF Araçları ⋮ "Sayfa tara ve ekle" mevcut belgeye ekliyor mu.
      **Play Services olmayan cihazda** paketin yedek tarayıcısına düşmeli.
- [ ] **PDF Araçları cihaz doğrulaması (kullanıcı)** — 2026-07-25 Faz 1: ana ekran
      PDF simgesi / görüntüleyici ⋮ "PDF araçları" → (a) sayfa küçük resimleri
      geliyor mu, (b) seç → döndür/sil/öne-arkaya taşı doğru sayfaya mı uyguluyor,
      (c) "Çıkar" seçili sayfaları ayrı PDF olarak paylaşıyor mu, (d) "Başka PDF
      ekle" birleştiriyor mu, (e) parola koy → uygulamayı kapat-aç → parola soruyor
      mu, parolayı kaldır çalışıyor mu, (f) sıkıştır boyutu düşürüyor mu (taranmış
      PDF'te kazanç KÜÇÜK olabilir, beklenen), (g) Kaydet sonrası görüntüleyici
      belgeyi tazeliyor mu.
- [ ] **Çeviri/resim-PDF/premium cihaz doğrulaması (kullanıcı)** — 2026-07-24,
      build 89'da: (a) PDF'te metin seç → "Çevir" → dil modeli iniyor mu, çeviri
      geliyor mu; (b) Word/Excel/Slayt menüsünde "Belgeyi çevir"; (c) bir resim
      açıp "PDF'e dönüştür" → "Yazıları da tanı" → çıkan PDF'te resim TAM ve
      içindeki yazı aranabilir mi; (d) .apk dosyasına "birlikte aç" deyince
      uygulamamız artık listede ÇIKMIYOR mu (asıl şikayet); (e) WhatsApp'tan
      gelen dosya hâlâ açılıyor mu (octet-stream riski — HAFIZA'da yazılı);
      (f) premium görünüm: kart/liste/boş durum, koyu tema kontrastı.
- [ ] **Seçili metin çevirisi Word/Excel/Slayt'ta yok** — şu an yalnız PDF'te
      (seçim altyapısı orada). Word WebView tabanlı, seçim Flutter'a gelmiyor;
      istenirse JS köprüsüyle seçili metin okunabilir.
- [x] ~~**`withOpacity` → `withValues` temizliği**~~ → **YAPILDI 2026-08-04:**
      10 çağrı dönüştürüldü. `flutter analyze lib` artık **0 uyarı** (yalnız
      `info` kaldı).
- [ ] **PDF Faz 2 vurgu cihaz doğrulaması (kullanıcı)** — yerel build telefona
      KURULDU (2026-07-23, adb install başarılı, debug-imzalı). "Metin seç" →
      renk seç (sarı/yeşil/pembe/mavi) → Vurgula → (a) vurgu SEÇİLEN metnin tam
      üstüne oturuyor mu (koordinat Y-flip), (b) kaydettikten sonra aynı sayfada
      yeniden yükleniyor mu (ValueKey), (c) kapatıp açınca vurgu kalıcı mı.
      **Not:** kaldır+kur ile kuruldu → Gemini API anahtarı ve son dosyalar listesi
      sıfırlandı, Ayarlar'dan anahtarı tekrar gir. Push yapılmadı, main/CI eski.
- [ ] **Cihaz doğrulaması (kullanıcı)** — 2026-07-23 14:30'da yerel derleme telefona
      kuruldu, içindekiler test edilmedi: Excel hücre içi yazma (seçili hücreye
      ikinci dokunuş), slaytta yerinde metin düzenleme, PDF seçim tutamaçları,
      Gemini model listesinin Ayarlar'da otomatik dolması. Ayrıca eski liste:
      WhatsApp "birlikte aç", odak-noktalı pinch, Word tam sayfa sığdırma,
      eski .doc/.xls/.ppt açma, arama, yeni belge, slayt çoğalt/sil/taşı.
- [ ] **PDF arama cihaz doğrulaması (kullanıcı)** — Faz 1 (belge içi arama + sayfaya
      atlama + sarı vurgu) main'de/build'de: gerçek PDF'te arama sonuçları doğru
      vurgulanıp sonraki/önceki ile o sayfaya kayıyor mu? (pdfrx PdfTextSearcher).
- [ ] **Slayt sadakati cihaz doğrulaması (kullanıcı)** — Faz 1-3 yerelde test
      yeşil (204) ama GÖRSEL cihazda bakılmadı (2026-07-23): gömülü fontlarla
      metin görünümü + **değişken-Arimo kalın** (Arial kalın doğru mu?),
      bağlayıcı okları/kesik çizgi, dış gölge, grafiklerin (sütun/çubuk/pasta/
      halka/çizgi) gerçek .pptx'te doğru veri+renk+oranla çizilmesi.

- [ ] **Word sadakati cihaz doğrulaması (kullanıcı)** — 2026-07-24 WebView'a MS font
      ikamesi (Calibri→Carlito, Times→Tinos, Arial→Arimo `@font-face`) + Word sayfa
      kırma konumları (`ignoreLastRenderedPageBreak:false`) + tam A4 yükseklik
      (`ignoreHeight:false`) eklendi. Gerçek Calibri/Times/Arial'lı .docx'te: (a)
      satır/sayfa kırılımı Word ile aynı yerde mi, (b) yazı yerel/doğru görünüyor mu,
      (c) `../fonts/` file:// erişimi cihazda fontları gerçekten yüklüyor mu (script'ler
      yükleniyor → beklenen evet). Yerelde flutter yok, CI test+APK yeşil olmalı.

- [ ] **PPTX sadakati cihaz doğrulaması (kullanıcı)** — 2026-07-24: p:style tema
      dolgu/çizgi referansı, görsel flipH/flipV, spcPts/spcAft satır aralığı, tablo
      kenar-başına kenarlık eklendi (birim testli, CI yeşil olmalı). Gerçek .pptx'te:
      (a) tema temelli renkli şekiller artık dolu mu (eskiden boştu), (b) aynalanmış
      görseller doğru yönde mi, (c) tablo yalnız tanımlı kenarları mı çiziyor.

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
- [ ] **Word'de yazı tipi/punto PARAGRAF düzeyinde** (2026-08-01): seçimin
      ortasındaki üç kelimeye ayrı punto verilemiyor. Bilinçli sınır — seçimi
      `<span>`la sarmak `<p>` sayısını değiştirip canlı düzenlemenin paragraf
      eşlemesini bozabiliyor (sigorta düzenlemeyi tamamen kapatır). Gerekirse
      yol: seçimi paragraf sınırında BÖLÜP her parçayı ayrı sarmak ve eşlemeyi
      `data-p-index` gibi bir kimlikle indeksten bağımsız hale getirmek.

## Dosya yöneticisi (2026-07-25) — cihaz doğrulaması gereken/ertelenen işler
- [ ] **İzin akışı (kullanıcı, cihaz):** ilk açılışta "Tüm dosyalara erişim" kartı →
      Android ayar sayfası → geri dönünce tarama otomatik başlıyor mu. Reddedilirse
      medya izinleriyle en azından Görüntüler/Video/Ses görünüyor mu.
- [ ] **Depolama doluluğu (`df`) gerçek cihazda:** halka/çubuk doğru dolu mu; bazı
      ROM'larda `df` kısıtlıysa çubuk gizlenmeli (kod öyle davranıyor, doğrulanmadı).
      **2026-08-05 güncellemesi:** toplam artık `df`in ham boyutu değil AOSP
      `roundStorageSize` ile yuvarlanmış REKLAM kapasitesi (512 GB) ve ondalık
      biçimleniyor; boş alan yuvarlanmıyor.
- [ ] **Uygulama boyutu cihaz doğrulaması (kullanıcı)** — 2026-08-05: Pano →
      **Uygulamalar** → (a) liste boyuta göre mi sıralı, boyutlar Ayarlar →
      Uygulamalar'daki sayılarla tutuyor mu, (b) "Kullanım erişimi" izni YOKKEN
      boyut yerine sıfır DEĞİL hiçbir şey gösteriliyor mu, izin verilince
      hemen geliyor mu, (c) satırdaki klasör düğmesi doğrudan "Depolama ve
      önbellek" sayfasına iniyor mu (MIUI), (d) Bellek Analizi'ndeki
      **Uygulamalar kartı** toplamı Ayarlar'daki toplamla yakın mı.
- [ ] **Hızlı süzgeç cihaz doğrulaması (kullanıcı)** — 2026-08-05: Belgeler /
      Videolar ekranında (a) üstte WhatsApp/Telegram/Kamera çipleri sayılarıyla
      çıkıyor mu, (b) **"6 aydır açılmamış"** çipi mantıklı bir sonuç veriyor
      mu — cihazın `atime` tutup tutmadığına bağlı, tutmuyorsa liste "eski
      dosyalar"a dönüşür (bilinçli sınır).
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
- [ ] **Ses: bildirim/kilit ekranı kontrolleri yok** — audioplayers ekran kapalıyken
      çalmayı sürdürür ama ön plan servisi olmadığı için sistem bellek baskısında
      süreci öldürebilir ve bildirimden kontrol edilemez. Çözüm `just_audio_background`
      (manifest'te activity sınıfı değişir → APK'da sınıf doğrulayan CI adımı şart).
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
- [ ] **Dosya seçici olarak davranma** (başka uygulama dosya isteyince
      GET_CONTENT/OPEN_DOCUMENT intent'i karşılamak).
- [ ] **SD karta yazma (SAF)** — Android bazı cihazlarda ikincil birime doğrudan
      yazmayı engeller; gerekirse `SAF` tree izni akışı eklenmeli.
- [ ] **Klasör boyutlarını liste içinde göstermek** (şu an yalnız Özellikler'de,
      istek üzerine hesaplanıyor — her satırda hesaplamak pahalı).

## PDF turu sonrası kalanlar (2026-07-26, 2. tur sonrası güncel)
- [ ] **Cihaz doğrulaması bekliyor:** vurgulama, uzun basışla metin seçimi,
      2/4 sütun düzeni, kaydırma çubuğu, taramada köşe ayarı + döndürme,
      yerinde metin düzenleme. Hiçbiri birim testle doğrulanamaz
      (pdfium render + dokunma + kamera).
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
- [ ] **`/ToUnicode` taşımayan belgeler** (eski üreticiler, bazı taranmış+OCR
      çıktıları) hâlâ tek baytlık tahmine kalıyor; tutmazsa yedek yola düşer.
      Çözüm: `/Encoding /Differences` + glif adı→Unicode tablosu (AGL).
- [x] ~~Yeni metin uzunsa satırın kalanı sağa kayar (PDF metni yeniden
      akıtmaz)~~ → **YAPILDI (5. tur):** belgenin kendi glif genişlikleriyle
      ölçülüp satırın kalanı kaydırılıyor (`pdf_font_metrics` + `scanContent`).
      Taşarsa kaydetmeden önce uyarı veriliyor.
- [ ] **İki yana yaslı satır yeniden YASLANMIYOR.** Satırın kalanı doğru kadar
      kayıyor ama sağ kenar artık düz değil (Word paragrafı yeniden dağıtır,
      biz tek satıra dokunuyoruz). Çözüm için paragraf sınırlarını ve `Tw`
      dağıtımını yeniden hesaplamak gerekir — ayrı ve büyük iş.
- [ ] **Yerinde düzenleme cihaz doğrulaması (kullanıcı)** — 5. tur: PDF aç →
      yazıya uzun bas → "Düzenle" → (a) kutu metnin TAM ÜSTÜNDE mi açılıyor,
      punto/konum oturuyor mu, (b) klavye kendiliğinden geliyor ve metin baştan
      seçili mi, (c) kelimeyi uzatıp uygula → satırın kalanı KAYIYOR mu,
      kısaltınca boşluk kalmıyor mu, (d) yakınlaştırılmış sayfada kutu doğru
      yerde mi, (e) "AI ile düzelt" kutuyu kaybetmeden metni değiştiriyor mu,
      (f) taşma uyarısı çıkan belgede sonuç gerçekten taşıyor mu.
- [x] ~~Arka plana alınan iş için kalıcı gösterge yok~~ → **YAPILDI:** kalıcı
      alt şerit (iş adı + sayaç + Durdur), sayfa değişse de kalıyor.
- [x] ~~Taramada döndürme yok~~ → **YAPILDI:** önizlemede 90° çevirme.
- [ ] **Agresif sıkıştırma (resme çevirerek) YAPILMADI — yol kapalı.**
      Cihazda JPEG kodlayıcı yok (`dart:ui` yalnız PNG üretir) ve PNG taranmış
      sayfada özgün JPEG'den büyük çıkar → "sıkıştır" dosyayı şişirirdi.
      Gerekirse `image` paketi (yeni bağımlılık, yavaş) veya platform kanalı.
      Yapılırsa metin katmanı kaybolacağı için AYRI ve açıkça uyaran bir
      seçenek olmalı, sessizce değil.
- [ ] **Kırpılmış (CropBox'ı MediaBox'tan kaydırılmış) PDF'te vurgu/yerinde
      düzenleme koordinatı doğrulanmadı.** Syncfusion kutu ölçüsünü alırken
      köşe konumunu (c0/c1) atıyor; böyle bir dosya elimizde yok, ölçülemedi.
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
- [ ] **Cihaz doğrulaması (kullanıcı):** kağıt temasında (a) büyük sistem yazı
      tipinde taşma var mı, (b) koyu temada kart kenarlıkları görünüyor mu,
      (c) Arapça (RTL) düzende cetvel çizgileri ve sağdaki özet değerler doğru
      yönde mi, (d) serif başlık + sans gövde okunaklı mı.
