# Cihaz ve masaüstü doğrulama listesi

> Kodla ya da birim testle kapatılamayan, **telefonda bakılması gereken** maddeler.
> Faz 8/9 bölümleri + KALANLAR'dan taşınan 37 eski madde (en altta, kaynak bölüm
> başlığıyla). Her madde: ne yapılır → ne görülmeli.
> Örnek dosyalar `test/fixtures/pdf/` ve `test/fixtures/office/` altında
> (`flutter test tool/write_fixtures_test.dart` yeniden üretir).

## Faz 8 — PDF tek çatı (2026-10-21)

- [ ] **Düzenle kapısı:** herhangi bir PDF → alt çubukta artık *Düzenle · Araçlar · Çevir ·
      Paylaş · Yazdır* var (Kalem/Düzenleyici ayrı düğme değil). "Düzenle" → altı kip
      (Metin, Kalem, İmza, Form, Sayfalar, AI ile) çıkıyor mu, her biri kendi ekranını
      açıyor mu, kaydederken hep aynı "Orijinali değiştir / Kopyasını kaydet" penceresi mi.
- [ ] **Seçimden düzenleme:** yazıya uzun bas → seçim çubuğunda "Düzenle" → PDF
      düzenleyicisi SEÇİMİN SAYFASINDA açılıyor mu (eski satır içi kutu artık yok).
- [ ] **Yazı ekle (K12 yedeği):** `taranmis.pdf` → Düzenle → Metin → sağ altta
      "Yazı ekle" → sayfaya dokun → metin + punto → yazı dokunulan yerde mi;
      `dondurulmus_90.pdf` ve `cropbox.pdf`te de dokunulan yerde ve DÜZ okunuyor mu.
- [ ] **"Daha fazla" sayfası:** "Düzenle ve imzala" grubu kalktı; Metni tanı (OCR)
      "Dönüştür" grubunda.
- [ ] **Aa levhası (PDF):** üst çubukta "Aa" → okuma görünümü düğmesi, 1/2/4 sütun,
      gece modu ve "kaldığım yerden aç" anahtarı tek yerde; değişiklik arkada canlı.
- [ ] **Örnek set:** `test/fixtures/pdf/*` uygulamada açılıyor mu (parola: `1234`);
      `uzun_320_sayfa.pdf` açılış süresi Faz 4 ölçümünden kötü değil mi
      (`docs/perf/2026-10-21.md`).

**Bulutta ölçülen (2026-10-21):** örnek PDF'lerin hepsi Poppler'da açılıyor;
düzenlenmiş hâllerinde yeni metin var, eskisi yok (`pdftotext`). Paragraf motoru
`/Rotate 90/180/270`, CropBox'lı, parolası kaldırılmış, Type0/Identity-H ve
`/Differences`+AGL (ToUnicode'suz) belgelerde düzenliyor (`pdf_fixture_smoke_test`).

## Faz 9 — Office ve metin (2026-10-21)

### Word
- [ ] **Canlı yazma gidiyor mu (KÖK NEDEN düzeltmesi):** `tablo.docx` → Düzenle → bir
      paragrafa yaz → Kaydet → dosyayı kapat-aç: yazılan duruyor mu. (Chromium'da
      ölçüldü: `input` olayının hedefi `<article>` olduğu için yazılanlar eskiden
      Flutter'a hiç gitmiyordu — bkz. HAFIZA 2026-10-21 (4).)
- [ ] **Tablo hücresi:** aynı belgede "Ayşe" hücresine yaz → kaydet → yeniden aç.
- [ ] **Seçime punto/yazı tipi:** bir kelimeyi seç → punto 20 → yalnız o kelime
      büyüyor mu; kaydet-aç sonrası da öyle mi.
- [ ] **Resim ekle/sil:** imleç bir paragrafta → şeritte "Resim ekle" → galeriden
      resim → paragrafın altına geldi mi, düzenleme kaldığı yerden sürüyor mu;
      resmin yanına dokun → "Resmi sil".
- [ ] **Masaüstü Word:** `tablo_duzenlendi.docx` Word'de onarım istemeden açılıyor mu
      (resim, madde işareti, "Mart" 16 pt kalın, "Ayşe Kaya").

### Excel
- [ ] **Grafik ekle:** `satis.xlsx` → A1:C4 seç → Daha fazla → Ekle → Grafik ekle →
      Sütun/Çubuk/Çizgi/Pasta önizlemesi değişiyor mu → Ekle → Kaydet.
- [ ] **Masaüstü Excel / Google E-Tablolar:** `satis_duzenlendi.xlsx` onarım istemeden
      açılıyor mu, grafik E-M sütunlarında görünüyor mu, sayfa sırası *Notlar, Özet*.
- [ ] **Köşegen doldurma:** 1, 2 / 10, 20 bloğunu seç → tutamağı sağ-aşağı çapraz çek →
      önizleme dikdörtgen mi, sonuç satır serisinin devamı mı (C1=19 …).
- [ ] **Sayfa taşı:** sekmeye uzun bas → Sola/Sağa taşı → kaydet → Excel'de sıra aynı mı.
- [ ] **Seçimi çevir:** birkaç hücre seç → Çevir → yalnız seçim çevriliyor mu.
- [ ] 10 bin satırlık dosyada kaydırma/açılış Faz 4 ölçümünden kötü değil mi
      (`tool/make_test_tree.py` ve Ek D protokolü).

### Slayt
- [ ] Metin kutusunu düzenle → bir kelime seç → şeritte "Çevir" → yalnız seçim.
- [ ] `sunum_duzenlendi.pptx` PowerPoint'te açılıyor mu ("Gelir %12 arttı").

### Metin ve eski biçimler
- [ ] **Büyük metin:** 50 MB'lık bir kayıt dosyası aç → "Büyük dosya — salt okunur"
      şeridi + satır sayısı + kodlama; hızlı kaydırma (kaydırma çubuğunu sürükle)
      takılmıyor mu, bellek uyarısı/çökme yok mu.
- [ ] **Kodlamalar:** `metin_utf8.txt`, `metin_cp1254.txt`, `metin_utf16le.txt` aynı
      Türkçe metni gösteriyor mu; `noktali_virgul.csv` üç sütun.
- [ ] **Eski .doc/.ppt:** gerçek bir `.doc` aç → "SALT OKUNUR" rozeti → "DOCX yap ve
      düzenle" → yanına `ad.docx` (varsa `ad (2).docx`) çıktı mı ve Word ekranı açıldı mı;
      `.ppt` için aynısı (`.pptx`).

**Bulutta ölçülen (2026-10-21):** `test/fixtures/office/*.{docx,xlsx,pptx}` (özgün +
düzenlenmiş, 7 dosya) LibreOffice 7'de PDF'e çevrildi; hepsi açıldı, düzenlenen metinler
yerinde. Grafik dört türde de LibreOffice'te çiziliyor (`spPr` rengi eklendikten sonra —
önce çubuklar görünmüyordu). openpyxl grafikleri `BarChart/LineChart/PieChart` olarak
okuyor. Word köprüsü: `node tool/check_word_bridge.js` (Playwright + Chromium).
**Gerçek Microsoft Office'te açılış bulutta denenemedi** — yukarıdaki masaüstü maddeleri
bunun için.

## Faz 10 — medya (2026-10-21)

- [ ] **Görsel düzenleyici:** galeride bir JPEG → "Düzenle" → Kırp (4:3 seç, köşeyi
      çek), Döndür, Çevir, Ayarla (parlaklık +), İşaretle (kalem, ok, yazı "Şğİ") →
      Kaydet → "Kopya olarak kaydet" → yanına `ad (1).jpg`; açınca önizlemedekiyle aynı,
      özgün dokunulmamış. EXIF'li (yan çekilmiş) fotoğrafta önizleme dik mi.
- [ ] **HEIC/WebP:** düzenle → kaydet seçeneğinde "JPEG kopya" notu, çıktı `.jpg`.
- [ ] **PiP:** video oynat → "Küçük pencerede oynat" → video küçük pencerede sürüyor;
      oynatırken ana ekrana kaydır → kendiliğinden PiP; pencereyi büyüt → oynatıcıya döner.
      Ayarlar > Uygulamalar'da "diğer uygulamaların üzerinde göster" izni ARTIK yok.
- [ ] **Ses (yeni motor):** müzik klasörü → çal, ekranı kilitle → çalmaya devam; bildirimden
      sonraki/önceki; parça bitince sıradaki; tekrar/karışık; hız 1.5x; telefon çalınca
      susuyor mu (ses odağı).
- [ ] **Video küçültme (Media3):** 1080p video → 720p, 30 fps, "Dengeli" → ilerleme yüzdesi
      akıyor, çıktı 1280x720 (dikey videoda 720x1280), süre aynı; "sesi çıkar" sessiz;
      serbest ölçü 1234x568 birebir; iptal → yarım dosya kalmıyor.

## Faz 10b — örnek medya seti (2026-10-22)

Set: `test/fixtures/media/` (`python3 tool/make_media_fixtures.py` yeniden üretir).
Telefona kopyalarken klasöre `.nomedia` KOY ve iş bitince SİL (HAFIZA 2026-10-22 ölçüm tuzağı).

- [ ] **EXIF yönü (B11):** `orient_6.jpg` ve `orient_8.jpg` galeride DİK görünüyor mu (sol üst
      kırmızı). Boyutlandır → "Şu an" satırı **300×400** yazıyor mu (eskiden 400×300).
- [ ] **Görsel düzenleyici:** `orient_6.jpg` → Düzenle → kırp 1:1 + döndür → kopya; kopya dik ve
      kırmızı kare doğru köşede mi.
- [ ] **HEIC:** telefonda çekilmiş bir HEIC → Boyutlandır: "Görüntü çözülemedi" mi, çalışıyor mu
      (Dart `image` paketi HEIC çözemiyor — beklenen: hata; Faz 14b yerel motorla kapanır).
      Görsel düzenleyici HEIC'i açıyor mu.
- [ ] **WebP / GIF:** `photo.webp`, `anim.gif` → Boyutlandır → JPEG kopya açılıyor mu; GIF'te
      "özgünü çöpe at" uygulanmıyor (kare kaybı uyarısı).
- [ ] **Video:** `clip.mp4` ve `clip.mkv` oynuyor; `clip.srt` altyazı olarak kendiliğinden
      bulunuyor ("Merhaba dünya", Türkçe karakterler bozulmadan). `clip.mkv` → küçült (Media3)
      → MP4 çıktı oynuyor mu.
- [ ] **Ses:** `tagged.mp3`, `tagged.m4a`, `tagged.flac` → başlık "Örnek Şarkı", sanatçı, albüm
      ve turuncu kapak görünüyor mu (FLAC etiketleri bu turda eklendi).
- [ ] **Galeri 2.000 fotoğraf RSS** (Ek D) — Faz 4 ölçümüyle birlikte.

## Faz 14a — görsel boyutlandırma 2.0 (2026-10-22)

- [ ] **Galeri → "Boyut"** (alt çubukta, Düzenle'nin yanında) levhayı açıyor mu; başlık
      "Boyutlandır (1 dosya)".
- [ ] **Piksel + kilit:** genişliğe 1600 yaz → yükseklik alanı anında doluyor mu; kilidi aç →
      1080 × 1080 → "Doldur ve kırp" / "Kenar boşluğu ekle (Bulanık)" / "Esnet" → çıktılar
      galeride beklenen gibi mi (kırpılmış kare, bulanık zeminli kare, esnemiş kare).
- [ ] **%150:** kırmızı "netlik artmaz" uyarısı; çıktı 1,5 kat ve iş "küçültülemedi" diye
      SİLMİYOR (büyük çıktı istenen sonuç).
- [ ] **Uzun kenar 1600:** dikey telefon fotoğrafında (EXIF 6) çıktı 1200×1600 DİK mi.
- [ ] **En-boy oranı 4:5 + kenar boşluğu, 16:9 + kırp** çıktıları doğru mu.
- [ ] **Dosya boyutu "Başvuru ≤ 200 KB":** 3-5 MB kamera fotoğrafı → çıktı ≤ 200 KB mi, süre
      makul mü (en çok 8 kodlama; düşük cihazda ölç). İş özetinde boyut yazıyor mu.
- [ ] **Son ayar hatırlanıyor mu:** bir ayarla başlat → başka fotoğrafta levha aynı ayarla
      açılıyor mu; "Özgünü çöpe at" ise HER ZAMAN kapalı açılmalı.
- [ ] **Video seçiminde** fotoğraf kipleri görünmüyor, 480p…1080p duruyor.
      → **2026-10-23 (14b) güncellendi:** videoda uzun kenar / en-boy oranı / dosya boyutu
      DA var (aşağıdaki 14b maddeleri).

## Faz 13 — ortak tür süzgeci + Son açılanlar (2026-10-22)

- [ ] **Son açılanlar:** Ayarlar/pano → Geçmiş → Açılanlar → üstte `Tümü · PDF · Word …`
      çipleri; "PDF"e dokun → yalnız PDF'ler, sayı çipteki sayıyla aynı mı. PDF + Word
      birlikte seçilebiliyor mu.
- [ ] **Son açılanlar sıralama/gruplar:** "Tarihe göre" = AÇILMA zamanı (Bugün / Bu hafta
      başlıkları); "Ada göre" seç → uygulamayı kapat-aç → ada göre açılıyor mu (kalıcı).
      PDF süzgeci ise uygulama yeniden açılınca TEMİZ olmalı (K17).
- [ ] **Geçmişten kaldır:** uzun bas → 2 dosya seç → ⋮ → "Geçmişten kaldır" → satırlar
      gidiyor, dosyalar diskte duruyor mu; snackbar "Geri al" → eski yerlerine dönüyor mu.
- [ ] **Yeni gelenler / İndirilenler / Belgeler / Önemli:** PDF çipi var ve tek dokunuşla
      süzüyor mu; çipler tek satır, kaydırılabilir; boş sonuçta "Filtreyi temizle".
- [ ] **Arama:** bir sorgu yaz → tür çipleri SONUÇTAN çıkıyor mu (PDF/Word ayrı).
- [ ] **Gezgin:** süzgeç düğmesi → PDF/Word/… + Tarih ▾ + Boyut ▾ aynı satırda.
- [ ] **Çöp kutusu, Kasa, Üretilenler:** karışık içerikte tür çipleri çıkıyor ve süzüyor mu.
- [ ] **Büyük yazı (Ayarlar → yazı boyutu en büyük + sistem yazı 200 %):** Son açılanlar
      ve Yeni gelenlerde taşma (sarı-siyah şerit) yok mu.

## Faz 15–16 — görsel dil birliği + erişilebilirlik/RTL (2026-10-22)

- [ ] **İş bildirimi alt çubuğu örtmüyor (kullanıcı bildirimi 2026-10-22):** çok
      dosya seçip Sil → "Çöp kutusuna taşınıyor · n / N" kartı seçim çubuğunun
      ÜSTÜNDE duruyor mu, düğmeler basılabiliyor mu. Aynısı ana ekran alt
      gezinmesi ve belge dock'u (Word/Excel alt çubuğu) için. Başka sayfa
      açılınca kart yine ekranın altına iniyor mu.
- [ ] **Simge ailesi:** gezgin, pano, ayarlar, oynatıcı, PDF/Word araç
      çubuklarında çizgi (outlined) + dolu glif karışımı kalmadı mı; "İş
      programı/Gece" ailesinde kategori simgeleri hâlâ çizgi mi (bilinçli).
- [ ] **Soluk metin okunurluğu:** yol, sayaç, zaman damgası (inkFaint koyulaştı,
      4 tema × açık/koyu) gözü yormadan okunuyor mu; Modern açık temada yeşil
      "başarılı" rengi.
- [ ] **Animasyonları kaldır:** Geliştirici seçenekleri → animasyon ölçekleri
      kapalı ya da Erişilebilirlik → "Animasyonları kaldır" → sayfa geçişi anında
      mı; galeri küçük resim şeridi, slayt gösterisi, sohbet kaydırması
      atlayarak mı gidiyor (çökme/takılma yok).
- [ ] **TalkBack:** dosya satırı "PDF, Kira sözleşmesi, 117 KB · dün" gibi TEK
      kez okunuyor mu; TalkBack menüsünde (üç parmak/yerel bağlam menüsü)
      **"Seç"** eylemi var ve seçim kipini açıyor mu; yol çubuğu hapı adı bir
      kez okuyor mu; listede etiketsiz "uzun bas" düğümü kalmadı mı.
- [ ] **Uygulama başına dil (Android 13+):** Ayarlar → Uygulamalar → Dosya
      Okuyucu → Dil listesinde Türkçe/English/العربية var mı; uygulama içi dil
      "Sistem"deyken buradan seçilen dil uygulamaya yansıyor mu.
- [ ] **Arapça:** gezgin/kategori/Son açılanlar/ayarlar aynalanmış mı; alt satır
      "117 KB · 22 …" sırası doğru mu (sayı/birim karışmıyor); Excel hücre
      hizası ve PDF çıktısı AYNALANMAMIŞ mı (belge içeriği bilinçli fiziksel).
- [ ] **Büyük yazı 2,0×:** Ayarlar → Görünüm → yazı boyutu kaydırıcısı %200'e
      çıkıyor mu; 360 dp'lik telefonda gezgin, Son açılanlar, ayarlar, arama,
      çöp kutusu taşma şeridi göstermeden kullanılabiliyor mu.

- [ ] **Word/slayt madde imleri (kullanıcı bildirimi 2026-10-22):** ekran görüntüsündeki
      ESNEKLİK-REZİLYANS belgesinde "Yastıkların üzerinden atlama…" maddelerinin başında
      ▯ yerine • görünüyor mu; ok (➢), onay (✓), kare (▪) imli listeler; PowerPoint'te
      "§"/"Ø" yerine ▪/➢. Düzenleyip kaydedince Word'de madde imleri bozulmuyor mu.

## KALANLAR'dan taşınanlar (Faz 0, 2026-10-21 — kelimesi kelimesine)

### (başlıksız)

- [ ] **cihaz doğrulaması (kullanıcı) — 2026-10-21 Faz 8/9:** `docs/CIHAZ_TESTI.md` §Faz 8
      (PDF "Düzenle" kip sayfası, "Yazı ekle", Aa levhası) ve §Faz 9 (Word canlı yazma +
      tablo hücresi + seçime punto + resim ekle/sil, Excel grafik/köşegen/sayfa taşı,
      büyük metin, eski .doc dönüştür). Örnek dosyalar `test/fixtures/{pdf,office}/`.
- [ ] **cihaz doğrulaması (kullanıcı) — 2026-10-21 Faz 2:** (a) eski "Gizli dosyalar"ı olan
      telefonda Kasa açılınca taşıma kartı çıkıyor mu, "Kasaya taşı" sonrası dosyalar Kasa'da
      açılıyor ve "Geri çıkar" özgün klasöre (alt klasörleriyle) döndürüyor mu; (b) Ayarlar >
      PIN değiştir önce eski PIN'i soruyor mu, sonra Kasa yeni PIN'le açılıyor mu; (c) Geçmiş
      ekranının alt çubuğu ve geri tuşu; (d) Aktar ekranı; (e) seçilmiş eski tema/yazı tipi
      (ör. Okyanus, Merriweather) güncellemeden sonra Modern/Tinos'a dönmüş mü.
- [ ] **cihaz doğrulaması (kullanıcı) — 2026-10-18 turu (tarama baştan).** (a) Resimli
      sayfa taranıp ML Kit'te onaylanınca fotoğraf bozulmadan / dilimlenmeden mi
      kaydediliyor; (b) stüdyo: Kırp (kenar ortası tutamaçları, büyüteç, "Kenarları bul"),
      Döndür, Filtre önizlemeleri ve "Tüm sayfalara", sıra sürükleme, Yeniden çek, Sil →
      "Geri al", başlıkta "Kaydediliyor… → Kaydedildi"; (c) "+" → "Fotoğraftan ekle" ile
      kırpma; (d) "Uygulamanın kapladığı alan"ın en altındaki "Android uygulama
      ayarlarını aç" ve öteki listelerin son satırı gezinme çubuğunun üstünde mi; (e) dosya
      işlem menüsünün hızlı sırası; (f) pano kapsülü (kaydırınca katlanma); (g) biten işin
      şeritte/bildirimde "… tamamlandı" yazması.
- [ ] **cihaz doğrulaması (kullanıcı) — 2026-10-17 (3) turu.** (a) Galeri/kategori
      ekranında seçim yaparken yana kaydırma sayfa DEĞİŞTİRMİYOR, seçim bitince
      değiştiriyor mu; (b) tarama → 2026-10-18 turunda akış baştan yazıldı, aşağıdaki
      maddeye bakın; (c) **SD kartla birleşik depolama**: "Şimdi taşı"
      ilerlemesi, şarja takınca UYGULAMA KAPALIYKEN çalışıyor mu, şarjdan çıkınca
      duruyor mu, bitiş bildirimi, taşınan fotoğraflar galeride görünüyor mu,
      Android 10 ve öncesinde "yazılamıyor" uyarısı çıkıyor mu.
- [ ] **cihaz doğrulaması (kullanıcı) — 2026-09-04 turu.** Telefonda
      bakılacaklar: (a) uzun bir PDF'i yarıda bırak, kapat, yeniden aç →
      kaldığın SAYFADAN açılıyor ve "Baştan başla" şeridi çıkıyor mu;
      (b) Ayarlar > Gezinme > "Listede klasör boyutu"nu aç → klasör
      satırlarında boyut beliriyor, kaydırma akıcı kalıyor mu; (c) dosya
      seçince başlıkta toplam boyut doğru mu; (d) aramada son sorgular çip
      olarak geliyor, çarpıyla siliniyor mu; (e) videoda A-B tekrar:
      düğmeye iki kez basıp aralığın döndüğünü gör; (f) müzikte karışık
      kipini aç, uygulamayı kapat-aç → kip KORUNUYOR mu; (g) çok bölümlü bir
      USB bellekte "Bölüm seç" şeridi çıkıyor ve öteki bölüm açılıyor mu.
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

### Excel "gerçek mobil Excel gibi olsun" — kalan yol haritası

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

### Yarım kalan

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
- [ ] **Dil desteği cihaz doğrulaması (kullanıcı)** — 2026-07-30: Ayarlar →
      **Dil** → English / العربية seç → (a) ana ekran, alt sekmeler, Ayarlar,
      Excel ve Word ekranları o dilde mi, (b) **Arapça'da arayüz sağdan sola**
      mı akıyor (geri oku, sekme sırası, kaydırıcılar), (c) Arapça'da yazı
      tipi okunur mu (cihazın Arapça fontu), (d) dil seçimi uygulamayı
      kapatıp açınca korunuyor mu, (e) "Sistem" seçiliyken telefon dili
      İngilizce/Arapça ise uygulama o dilde mi açılıyor.
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

### Dosya yöneticisi (2026-07-25) — cihaz doğrulaması gereken/ertelenen işler

- [ ] **İzin akışı (kullanıcı, cihaz):** ilk açılışta "Tüm dosyalara erişim" kartı →
      Android ayar sayfası → geri dönünce tarama otomatik başlıyor mu. Reddedilirse
      medya izinleriyle en azından Görüntüler/Video/Ses görünüyor mu.
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

### PDF turu sonrası kalanlar (2026-07-26, 2. tur sonrası güncel)

- [ ] **Cihaz doğrulaması bekliyor:** vurgulama, uzun basışla metin seçimi,
      2/4 sütun düzeni, kaydırma çubuğu, taramada köşe ayarı + döndürme,
      yerinde metin düzenleme. Hiçbiri birim testle doğrulanamaz
      (pdfium render + dokunma + kamera).

### Kağıt teması — 2. tur devir notundan kalanlar (2026-08-05)

- [ ] **Cihaz doğrulaması (kullanıcı):** kağıt temasında (a) büyük sistem yazı
      tipinde taşma var mı, (b) koyu temada kart kenarlıkları görünüyor mu,
      (c) Arapça (RTL) düzende cetvel çizgileri ve sağdaki özet değerler doğru
      yönde mi, (d) serif başlık + sans gövde okunaklı mı.

## 2026-10-22 — Faz 17–19, 11a, sesli kitap, QR, akıllı analiz (cihazda bakılacak)
- [ ] Seçici (başka uygulamadan "dosya seç") açılıp kapandıktan sonra ayarlar kaydediliyor mu (shared_preferences çökmesi)
- [ ] Excel hücresinde yazarken mavi çerçeve YOK; Word/slayt kutusunda da
- [ ] Yapay zekâ sesleri: Antalia/EMA indir → sesli kitap üret (Android WebView'da ONNX çalışıyor mu, süre)
- [ ] Sesli kitap M4A'ya dönüşüyor mu (Media3 yalnız-ses), Müzik/Sesli Kitaplar'da görünüyor mu
- [ ] Akıllı analiz: WhatsApp "günaydın" görselleri OCR ile bulunuyor mu, süre (1.500 görsel)
- [ ] QR paylaşım (metin alt yolu): Paylaş → QR ile paylaş → "Metni QR'ın içine koy" → başka telefonun kamerası Türkçe metni doğru gösteriyor mu

### QR ile dosya paylaş (2026-10-22 — İKİ telefon gerekir)
- [ ] **Aynı Wi-Fi, uygulamasız alıcı:** bir PDF → Paylaş → 3. seçenek "QR ile paylaş" → karşı
      telefonun KAMERASI kodu okuyor, tarayıcıda dosya adı + "İndir" sayfası açılıyor, iniyor;
      gönderende "İndirildi: 1".
- [ ] **Aynı Wi-Fi, Dosya Okuyucu'lu alıcı:** Aktar → Telefonla → Al → "QR kodu tara" (kamera
      izni SORULMAMALI, Google tarayıcısı açılır) → dosya "Kaydet" klasörüne iniyor, listede görünüyor.
- [ ] **Ortak Wi-Fi yok (hotspot):** gönderenin Wi-Fi'si kapalıyken ekran kendiliğinden geçici
      ağ kuruyor (Android 13+ "Yakındaki cihazlar" izni sorulur) → 1. kod kamerayla okutulunca
      karşı telefon ağa bağlanıyor → 2. kod tarayıcıda açılıyor ve iniyor.
      **Risk (tahmin):** internetsiz ağda alıcının tarayıcısı mobil veriden gitmeye çalışabilir —
      açılmazsa alıcının mobil verisini kapatıp dene ve sonucu yaz.
- [ ] **Hotspot + uygulamalı alıcı:** "QR kodu tara" → 2. kod → sistem "ağa bağlan" onayı → dosya
      iniyor; iş bitince alıcı telefon eski Wi-Fi'sine/mobil veriye dönüyor.
- [ ] Ekrandan çıkınca geçici ağ kapanıyor (Wi-Fi listesinde DIRECT-/AndroidShare ağı kalmıyor).
- [ ] Klasör paylaşımı ZIP olarak iniyor.
- [ ] Tahminli geri (Android 14+): geri jesti önizlemesi, düzenlemeden çıkarken sorma
- [ ] Açılış ekranı açık/koyu, başlatıcı kısayolları, Sistem rengi teması (Android 12+)
- [ ] Video: parlaklık kaydırması, uzun basış 2×, kilit, yatay sarma; galeri slayt gösterisi, Farklı kullan
- [ ] Okuma kipi: PDF/Word'de çubuklar kaydırınca gizleniyor mu; Tam ekran
- [ ] HEIC fotoğraf boyutlandırma, WebP çıktı
- [ ] Gemini anahtarı güncellemeden sonra kayıtlı kalıyor mu (Keystore göçü)

## Faz 14b + 15b + 16 devamı + slayt görseli (2026-10-23 — bulut turu, cihazda bakılacak)
- [ ] **Video oran kipi (Media3 düzen):** yatay 1920×1080 video → En-boy oranı 1:1 + Kırp →
      çıktı 1080×1080, görüntü ORTADAN kırpılmış, esneme YOK; aynı video 1:1 + Kenar boşluğu →
      1920×1920, üst/alt SİYAH şerit. (Eskiden kilit kapalı ölçü videoyu sessizce esnetiyordu.)
- [ ] **Video piksel kilit kapalı 1080×1080:** Sığdır / Doldur ve kırp / Kenar boşluğu / Esnet
      dört farklı ve doğru çıktı.
- [ ] **Video dosya boyutu hedefi:** 1 dk 1080p video → "≤ 10 MB" → çıktı ~10 MB (±%15);
      "≤ 2 MB" seçince çözünürlük de iniyor mu (iş özetinde ölçü), ses duruyor mu.
- [ ] **Kırpma çapası (fotoğraf):** dikey portre → 1:1 + Kırp + "Üst" → yüz korunuyor mu;
      "Sol/Sağ" yatay fotoğrafta doğru kenarı tutuyor mu (Arapça arayüzde de "Sol" görüntünün solu).
- [ ] **Canlı önizleme:** levhanın üstündeki küçük resim oran/kırp/boşluk seçtikçe anında
      değişiyor mu; bulanık zemin görünüyor mu; 50 fotoğraflık seçimde levha açılışı gecikmiyor mu.
- [ ] **Ön ayar kaydet/sil:** "Ayarı kaydet" → ad ver → çip görünüyor; uygulamayı kapat-aç →
      çip duruyor; basılı tut → sil onayı → gidiyor. "Özgünü çöpe at" ön ayarla gelmiyor.
- [ ] **Konum bilgisini kaldır:** konumlu kamera fotoğrafı → anahtar açık → çıktıyı galeri
      bilgisinde aç: konum YOK, tarih/kamera VAR; anahtar kapalı → konum duruyor.
- [ ] **Görsel düzenleyici "Boyut" sekmesi:** 4. sekme; %50 / 1080 px çipleri, en yazınca boy
      anında; kırp → boyut → Kaydet → dosya beklenen ölçüde mi. Kırpma kutusunda "1080 × 1350"
      etiketi; yeni oranlar (4:5, 3:2, 21:9, A4, Orijinal, Özel "4:5"); üstteki karşılaştırma
      simgesine BASILI TUT → özgün görünüyor, bırakınca düzenlenmiş.
- [ ] **Slayta görsel ekle:** slayt ⋮ → "Görsel ekle" → galeriden resim → slaytın ortasında,
      oranı doğru; Kaydet → dosyayı PowerPoint/Google Slaytlar'da aç → görsel orada, taşınabiliyor.
- [ ] **Görsel dil taşıması (15b — görünüm DEĞİŞMEMELİ):** simgeler, Office şeridi (marka zemini
      üstü beyaz yazı/simge), PDF sayfa küçük resimleri (beyaz kâğıt), galeri/video perde yazıları,
      kırpma kılavuzları, bulma vurgusu (sarı/turuncu) önceki sürümle aynı mı. Yazı boyutları:
      ayarlar, AI merkezi, çöp kutusu alt satırları aynı boyda mı (13 pt'lik satırlar 13 kaldı).
- [ ] **Onay pencereleri (15b):** silme/boşaltma pencerelerinde "Sil" artık kırmızı dolgulu düğme,
      vazgeç solda; yeniden adlandır / yeni klasör adı penceresinde uzantı seçimin dışında.
- [ ] **TalkBack — iş ilerlemesi (16):** büyük kopyalamada şerit %10 adımlarla duyuruluyor mu
      (her saniye konuşmamalı); İşlemler ekranında ve ilerleme penceresinde de.
- [ ] **Arapça (RTL) — 16:** hızlı kaydırıcı balonu ve tutamacı SOL kenarda; benzer fotoğraflar
      ve fotoğraf ızgarası grup etiketleri hücrelerin üstünde hizalı; rozetler aynalanmış.


### 2026-10-23 (14) — üst alan yeniden tasarımı / bildirim alanı / çöp / PDF
- [ ] **PDF kaydırma:** uzun PDF'te hızlı aşağı-yukarı kaydır + savur → belge parmağı izliyor,
      sayfa başına geri ÇEKİLMİYOR; üst/alt çubuk sabit kalıyor.
- [ ] **Dolu çöp (≥ 3 bin öğe):** açılış < 1 sn, kaydırma akıcı; "Boşalt" sırasında pano/kategori
      ekranı takılmıyor; bitince sayı doğru; tek öğe sil/geri yükle anında listeden düşüyor.
- [ ] **Sohbet temizliği:** kovadan sil → geri dön → kova sayısı ve "N dosya · X MB" (panodaki
      kartta da) yenile'ye basmadan güncel.
- [ ] **Akıllı bildirim alanı:** büyük kopyalama başlat → panonun en üstünde halka + kalan süre;
      bitince "✓ … · şimdi" satırı, × ile kapanıyor; panodayken alt şerit YOK, Dosyalar dışındaki
      sekmede şerit VAR; bellek ≥ %90'da uyarı satırı; FTP açıkken kapatılamaz satır + "Kapat".
- [ ] **Bellek kartı:** eskisinden ~%25 alçak; 2,0× yazıda taşma yok.
- [ ] **Kategori üst alanı (Belgeler):** başlık altında "161 öğe · 220 MB"; Sırala/Süzgeç/Analiz
      hapları; süzgeçte tarih/etiket seçince hapların altında × çipleri, "Temizle" hepsini kaldırıyor.
- [ ] **Analiz ve düzenle:** Özet, Genel analiz (ay çubukları, "uzun süredir açılmamış" → liste),
      AI analizi (anahtar yoksa etkinleştir penceresi), AI ile kategorilere ayır → öneri levhası →
      uygula → çip satırında "#Fatura · 12"; Etiketleri yönet → yeniden adlandır/sil.
- [ ] **Seçim › Daha fazla:** alttan gruplu levha (Düzenle / Kopyala ve gönder / Diğer), "AI ile
      etiketle" mavi; galeri ⋮ da aynı levha.
- [ ] **Anlamla ara:** panodaki "✦ Anlamla" → "geçen kışki elektrik faturası" → Ara → "Aranan:"
      çipleri + ilgili dosyalar; düğmeye tekrar basınca normal ad aramasına dönüyor.
- [ ] **Araçlar:** ilk sıra Harici bellek, sonra Yer aç, Sohbet temizliği, Aktar, Kasa…

## Düzenleme turu Faz 20–26 (2026-10-23 — bulut turu, cihazda bakılacak)

### Faz 21 — K18 kontrol noktası (Word yazma motoru; KARAR BU TESTE BAĞLI)
Ayarlar → Geliştirici → "Deneysel Word editörü" açılır; Word'de ⋮ → Deneysel editör.
Hem eski "Düzenle" (WebView) hem deneysel editörde, **Gboard ve Samsung klavyede** ayrı ayrı:
- [ ] ğ ü ş ı ö ç İ yazılıyor, harf kaybolmuyor/çiftlenmiyor
- [ ] kaydırarak yazma (swipe) kelimeyi doğru koyuyor
- [ ] sesle yazma metni ekliyor
- [ ] öneri çubuğuna dokunmak kelimeyi değiştiriyor
- [ ] Enter yeni paragraf açıyor, boş paragrafta geri silme önceki paragrafla birleştiriyor
- [ ] uzun basınca seçim, kopyala/yapıştır çalışıyor
- [ ] akıcılık puanı 1–5 (eski / deneysel): ___ / ___ — hangisi daha iyi?
- [ ] çok sayfalı, Word'de kaydedilmiş gerçek bir .docx'te "Düzenle" açılıyor (W1 onarımı)

### Faz 20 — ortak düzenleme çekirdeği
- [ ] klavye açılıp kapanırken klavye üstü çubuk klavyeyle birlikte kayıyor (takılma/zıplama yok)
- [ ] otomatik kaydetme: düzenleyip 3 sn bekle → başlıkta "Kaydedildi"; uygulamayı zorla kapat →
      yeniden aç → taslak şeridi "Geri yükle" çıkıyor
- [ ] çıkışta kaydedilmemiş değişiklik sorusu (Kaydet / Atma / Vazgeç)

### Faz 25 — Excel veri girişi
- [ ] %100 yakınlaştırmada seçili hücreye ikinci dokunuş hücre üstünde editör açıyor
- [ ] ✓ ↵ ⇥ oklar; ⇥ ile satır girip ↵ satır başı sütununa dönüyor
- [ ] sayı hücresinde uygulama tuş takımı açılıyor, "ABC" sistem klavyesine geçiyor
- [ ] `=` yazıp hücreye dokununca başvuru ekleniyor, renkli çerçeve görünüyor
- [ ] seçim tutamaklarını sürükleyerek aralık genişliyor; hızlı fırlatma veri sonuna gidiyor
- [ ] uzun bas → bağlam menüsü (yalnız değerleri / biçimi yapıştır, devrik yapıştır)
- [ ] `1.234,56`, `%15`, `₺100`, `23.10.2026`, `14:30` doğru tür ve biçimle giriliyor
- [ ] Türkçe formül (`=TOPLA(A1;A2)`) kaydedilen dosyada masaüstü Excel'de doğru açılıyor

### Faz 26 (kısmen) — hesap motoru
- [ ] büyük (10 bin satır, formüllü) sayfada yazarken/kaydırırken takılma (önce/sonra izlenim)
- [ ] kaydedilen .xlsx'i dosya yöneticisi/Drive önizlemesinde açınca formül SONUÇLARI görünüyor


### Faz 26b — okuma sınırı, kaydetme izolatı, K23 ızgara ölçümü (2026-10-23)
- [ ] 10 bin satırlık sayfada hızlı kaydırma: profil kipinde `FrameTiming` %99 kare ≤ 16 ms mı?
  (K23 kararı buna bağlı: tutmazsa tek boyacıya geçilir — bulut ölçümü HAFIZA 2026-10-23 (17))
- [ ] hücreye dokunma (seç / ikinci dokunuş = düzenle / aralığa dokunuş = bağlam menüsü) eskisi gibi
- [ ] 200 bin satırdan büyük ya da 1024 sütunu aşan bir .xlsx açılınca kırmızı şerit; Kaydet
  "kaydetme kapalı" diyor, dosya değişmiyor
- [ ] büyük kitapta Paylaş / İndir sırasında ekran donmuyor

### Faz 28 — slaytta yerinde metin düzenleme (2026-10-23)
- [ ] şekle dokun → çerçeve + tutamaklar + alt bağlam çubuğu; tekrar dokun → kutuya yakınlaşma
  animasyonu takılmasız, yazı rahat okunur boyda, klavyenin üstünde
- [ ] uzun bir gövde kutusunda yazarken imleç ekranda kalıyor (yatay/dikey kendiliğinden kayıyor)
- [ ] Gboard + Samsung klavyesiyle Türkçe (ğüşıöçİ) yazma, otomatik düzeltme, kelime önerisi sorunsuz
- [ ] bir kelimeyi seç → K / renk / punto: yalnız o kelime değişiyor; kaydet → PowerPoint'te aynı
- [ ] Enter yeni paragraf (madde işaretiyle), paragraf başında geri silme birleştiriyor
- [ ] boş "Başlık eklemek için dokunun" yer tutucusuna yazılan metin PowerPoint'te başlık olarak görünüyor
- [ ] Anahat görünümünde düzeltilen yazı slayta yansıyor
- [ ] ⋮ > Konuşmacı notu: not yazılıyor; PowerPoint "Notlar" bölmesinde görünüyor (notesMaster
  olmayan bir destede de — onarım uyarısı çıkmamalı)
- [ ] Şekil çubuğu: Kes / Kopyala / Yapıştır / Çoğalt / Öne getir / Arkaya gönder / Sil; ↶ geri alıyor
- [ ] 50 slaytlık destede açılış ve kaydırma akıcı

### Faz 22 — Word Mobil görünüm editörü (2026-10-23; K18 kontrol noktasının yerini alır)
Word'de bir belge aç → alttaki **Düzenle** (artık Mobil görünüm açılır):
- [ ] Gboard ve (varsa) Samsung Klavye ile Türkçe `ğüşıöçİ`, kaydırarak yazma, sesle yazma
- [ ] otomatik düzeltme önerisine dokunma doğru kelimeyi değiştiriyor; büyük harf cümle başında
- [ ] Enter yeni paragraf; başlığın sonunda Enter → normal gövde; boş madde işaretinde Enter → listeden çıkar
- [ ] paragraf başında geri silme iki paragrafı birleştiriyor (boş paragrafta da)
- [ ] uzun bas → kelime seçimi + mavi tutamaklar + Kes/Kopyala/Yapıştır/Tümünü seç/Çevir/AI ile düzelt
- [ ] çift dokunuş kelime, üç dokunuş paragraf seçiyor; tutamakla seçim paragraflar arası uzuyor
- [ ] yanlış yazılan kelimenin altında kırmızı dalgalı çizgi; dokununca öneriler menüde
- [ ] klavye üstü çubuk: ↶ ↷ K T A yapıştır ⌄; klavye kapalıyken şerit + "Sayfa düzeni"
- [ ] kaydet → Word masaüstünde / Google Dokümanlar'da onarımsız açılıyor; köprü, dipnot, resim, tablo yerinde
- [ ] "akıcı mı" (1–5) ve eski sayfa üzerinde düzenleme (⋮ menü) ile kıyas
- [ ] Arapça belgede sağdan sola yazma
