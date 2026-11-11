# Cihaz doğrulama listesi (KALANLAR Faz B2'nin eki)

> **2026-11-01'de baştan düzenlendi:** eski liste (770 satır, tarih tarih birikmiş, bir kısmı
> kaldırılmış ekranlara ait) **alana göre** toplandı; yinelenenler birleşti, artık var olmayan
> akışlar (QR paylaş ekranları, Firebase, eski PDF "Düzenleyici" alt çubuğu, Word sayfa
> üzerinde düzenleme, Excel eski biçim çubuğu…) çıkarıldı ya da bugünkü karşılığına çevrildi.
> Eski metin kelimesi kelimesine: `docs/arsiv/CIHAZ_TESTI_2026-10-31.md`.
>
> **Nasıl:** her madde *ne yapılır → ne görülmeli*. Geçen madde **silinir**; kırmızı olan
> aynı oturumda düzeltilir ya da KALANLAR'a madde olarak yazılır. Bulutta yeni yazılan ve
> telefonda bakılması gereken her şey buraya, ilgili bölüme eklenir.

## 0. Hazırlık

- Nightly APK (`releases/latest/download/dosya-okuyucu.apk`) ya da ölçüm için yan yana
  kurulan `.r8test` profil APK'sı (HAFIZA tuzağı: yerel anahtar ≠ CI anahtarı → üstüne kurma).
- Örnek dosyalar: `test/fixtures/pdf/` (parola `1234`), `test/fixtures/office/`,
  `test/fixtures/media/` (yeniden üretim: `flutter test tool/write_fixtures_test.dart`,
  `python3 tool/make_media_fixtures.py`, `python3 tool/make_word_fixtures.py`).
  Ölçüm verisi: `python3 tool/make_test_tree.py olcum` → telefonda **`.nomedia`'lı** klasör,
  iş bitince SİL (galeri/dizin bozulmasın).
- Cihazlar: güncel telefon + düşük donanımlı telefon (FAZ_PLANI Ek D, ≤ 3 GB) · Yakındakiler
  için ikinci telefon · Bluetooth klavye · varsa tablet/katlanabilir/DeX · masaüstünde Word/
  Excel/PowerPoint + Google Dokümanlar + LibreOffice (§13).
- Kare ölçümü `FrameTiming` / logcat `KARE` (`adb logcat -s flutter | grep KARE`).
  **SurfaceFlinger `--latency` aralığı takılma ölçüsü DEĞİLDİR** (HAFIZA). Git Bash'te adb:
  `MSYS_NO_PATHCONV=1`.
- **Cihaz notu — MatePad DBY-W09 (2026-11-07, kullanıcı isteği):** reklam/gereksiz paketler
  `adb shell pm uninstall --user 0 <paket>` ile kaldırıldı (geri: `adb shell cmd package
  install-existing <paket>`). Başarılı: com.huawei.intelligent, com.huawei.hwsearch,
  com.huawei.search, com.huawei.fastapp, com.huawei.gamebox, com.huawei.gameassistant,
  com.huawei.game.kitserver, com.huawei.tips, com.huawei.tipsove, com.huawei.browser,
  com.huawei.browser.fa, com.huawei.browserhomepage, com.huawei.himovie.overseas,
  com.huawei.music, com.huawei.health, com.huawei.ohos.health, com.huawei.email,
  com.huawei.calendar, trendyol.com, com.pozitron.hepsiburada,
  com.amazon.mShop.android.shopping, com.getir, com.sahibinden, com.akakce.akakce,
  com.dmall.mfandroid, **com.huawei.appmarket** (AppGallery; ana oturumda kaldırıldı —
  kurulumda "güvenlik taraması" reklamı açıyordu). **Başarısız (bırakıldı):**
  com.huawei.hitouch (`DELETE_FAILED_INTERNAL_ERROR`). Dokunulmadı: com.huawei.hwid,
  com.huawei.searchservice. Sonrasında yeni ölçüm tabanı: `docs/perf/2026-11-45-temiz-taban.md`.
  Kurulum onayı artık standart `PackageInstallerActivity` (DEVAM ET → YÜKLE).

## 1. Ölçümler (sayıyla doldur — FAZ_PLANI Faz 4 + DUZENLEME §7)

| Senaryo | Hedef (orta / düşük) | Güncel cihaz | Düşük cihaz |
|---|---|---|---|
| Soğuk açılış, ilk kare / etkileşim | ≤ 1,2 sn / ≤ 2 sn | 433–628 ms (2026-10-22, Xiaomi 13T) | |
| Açılışın ilk 0,5 sn'si: ilk kare raster, pano build | ölç (KALANLAR A8.2 sonrası) | 218–309 ms / 45–49 ms | |
| Boşta pano 60 sn: çizilen kare + zamanlayıcı | 0 | 0 ✔ | |
| 5.000 öğeli klasör kaydırma + sürükleyerek seçim, %99 kare | ≤ 24 ms | 8,5 ms ✔ | Mi Note 10 Lite 19–27 ms ≈ sınırda |
| Büyük klasör açılış karesi (3.000 foto) | — | 58 ms ✔ | |
| Galeri 2.000 fotoğraf kaydırma sonrası RSS | ≤ 350 MB (hafif ≤ 250) | | Mi Note 10 Lite 355 MB (profil, küçük PNG) ≈ sınırda |
| 100 sayfalık PDF: ilk sayfa, açılıştan sonraki 10 sn CPU | — | | |
| `uzun_320_sayfa.pdf` açılış | Faz 4'ten kötü değil | | |
| Excel 10 bin × 20: açılış / kaydırma %99 kare (**K23** — tutmazsa KALANLAR B3.1) | ≤ 1,5 sn / ≤ 16 ms | | |
| Excel hücre onayı → 1000 bağımlı hesaplı | ≤ 16 ms / ≤ 33 ms | | |
| Word 20 sayfa aç → düzenlemeye hazır · 300 sayfa ilk ekran | ≤ 1,2 sn · ≤ 1,5 sn | | |
| Word/Slayt/Excel/Metin tuş → ekranda harf | ≤ 1 kare / ≤ 2 kare | | |
| Word / Excel / slayt kaydırma %99 kare | ≤ 16 ms / ≤ 33 ms | | |
| Görsel düzenleyici 4000×3000: ayar kaydırıcısı kare | ≤ 8 ms / ≤ 16 ms | | |
| Ek bellek: Word 300 sayfa · Excel 100 bin hücre · büyük PDF düzenleme | ≤ +150 MB · ≤ +120 MB · ölç | | |
| 50 slaytlık deste açılış/kaydırma · 10 bin satırlık metin | akıcı | | |
| Dolu çöp (≥ 3 bin öğe) açılış | < 1 sn | | Mi Note 10 Lite 5.999 öğe ✔ |
| 100 bin+ dosyalı telefonda pano taraması (süre, bellek; `_TopN` yeterli mi) | ölç | | |
| Akıllı analiz: 1.500 WhatsApp görselinde OCR süresi | ölç | | |
| R8'li APK: açılış çökmesiz, APK boyutu | çökme yok | ✔ 60,6 MB (2026-10-22) | |

**Mi Note 10 Lite (Android 12, 5,7 GB RAM) — 2026-11-01, v1.0.452–454, ADB ile:**

| Ölçüm | Sonuç |
|---|---|
| Soğuk açılış (`am start -W`, ilk kurulum / sonrası) | 1,63 sn / 0,60–0,70 sn ✔ |
| Pano boşta 60 sn · arka planda 60 sn CPU (tek çekirdek) | %0,20 ✔ · %0,18 ✔ |
| Pano bellek (PSS / RSS) | 130 MB / 237 MB |
| PDF 320 sayfa: açılış, kaydırma tepesi PSS | 664 ms, ~227 MB, sonra düşüyor ✔ (RSS tek koşuda 555 MB) |
| Word çok sayfa · Slayt 50: açılış, kaydırma PSS | 601 ms, ~203 MB · 629 ms, ~150 MB ✔ |
| Excel 10 bin × 20: ilk hücre | ~20 sn → DOM'suz okuyucuyla **7,7–8,9 sn** ✖ hedef ≤ 1,5 sn (KALANLAR B3.3) |
| Pil: 4 dk PDF kaydırma + 2 dk arka plan | 48 sn CPU; **mAh ölçülemedi** (telefon prizde, hesaplanan tüketim 0) |
| Kare %99 | yayın derlemesinde ölçülmez → profil APK (aşağıda) |

**Aynı telefon — 2026-11-02, yan yana `.r8test` profil APK'sı (`KARE_OZET`, 300 karelik dilimler):**
Impeller Vulkan bu telefonda (Adreno 618) **OpenGLES'e düşüyor**. Skia denendi: daha kötü
(%99 30–45 ms, ilk dilim 145 ms) → Impeller kalıyor.

| Ölçüm | Sonuç |
|---|---|
| Soğuk açılış (profil, yayından yavaş) | 1,45–1,56 sn (ilk 2,5 sn) |
| 5.000 öğeli klasör açılış karesi | 145 ms (build 139) |
| 5.000 öğe kaydırma %99 — 300 ms'lik kaydırma / 120 ms'lik (insandan hızlı) | 19–27 ms ≈ sınırda / 25–31 ms (hedef ≤ 24) |
| 2.000 görsel, 3 sütun kaydırma %99 · sonra PSS / RSS | 20–29 ms · 260 / 355 MB (hedef RSS ≤ 350) |
| Çöpe taşı (eski kod) | ✖ 5.000 dosyada 4 dk'da ~1.800, giderek yavaş (74–92 ms/dosya) |
| Çöpe taşı / boşalt, temiz çöpte 1.000 dosya (toplu kayıt + 256'lık alt klasör) | 31 sn / ~20 sn ✔ (FUSE `rename` tabanı ~22 ms/dosya) |
| Dolu çöp (5.999 öğe) açılış | < 1 sn, en kötü kare 88 ms ✔ · eski düz çöpü boşaltma 5.999 öğe ~400 sn |

## 2. Dosya yöneticisi — pano, listeler, süzgeç, arama

- [ ] **İzin akışı:** ilk açılış rehberi (3 ekran) → "Tüm dosyalara erişim" → ayara git, dön →
      tarama kendiliğinden başlıyor; reddedilirse medya izinleriyle Görüntüler/Video/Ses yine
      görünüyor, öteki yerlerde "izin gerekli" kartı.
- [ ] **Pano:** bellek kartı (eskisinden ~%25 alçak, 2,0× yazıda taşma yok; toplam = reklam
      kapasitesi "512 GB", `df` kısıtlı ROM'da çubuk gizli); kaydırınca kapsül katlanıyor;
      çöp doluyken kutunun nefesi birkaç saniye sonra duruyor.
- [ ] **Akıllı bildirim alanı:** büyük kopyalama → panonun en üstünde halka + kalan süre; bitince
      "✓ … · şimdi", × kapatır; panodayken alt şerit YOK, başka sekmede VAR; bellek ≥ %90
      uyarısı; FTP açıkken kapatılamaz satır + "Kapat".
- [ ] **Araçlar sırası:** Harici bellek, Yer aç, Sohbet temizliği, Aktar (Yakındakiler), Kasa…
- [ ] **Ana ekranı düzenle:** "Görüntüler" (foto + video) ve "Son açılanlar" şeridi varsayılan
      gizli, buradan eklenince görünüyor (K16).
- [ ] **Tür hapı (her listede):** "Tüm türler · 142 ▾" → levhada simge/renk/sayılı kutular,
      çoklu seçim (PDF + Word), liste arkada hemen süzülüyor, "N dosyayı göster"; boş sonuçta
      "Filtreyi temizle". Belgeler, Görüntüler, İndirilenler, Son açılanlar, Gezgin, Arama,
      Çöp, Kasa, Üretilenler, Yeni gelenler, Önemli.
- [ ] **Süzgeç şeridi:** en fazla 3 kart (Tür · Kaynak ve zaman · Analiz ve diğer), kaydırma
      yok, yazılar sığıyor; "Kaynak ve zaman"da WhatsApp/Telegram/Kamera çipleri sayılı ve
      **Etiketler** bölümü; "6 aydır açılmamış" mantıklı (cihaz `atime` tutmuyorsa "eski
      dosyalar"a döner — bilinçli).
- [ ] **Son açılanlar:** "Tarihe göre" = açılma zamanı (Bugün / Bu hafta); "Ada göre" kapat-aç
      sonrası korunuyor, tür süzgeci ise yeniden açılışta TEMİZ (K17); 2 dosya seç → ⋮ →
      "Geçmişten kaldır" → dosyalar diskte duruyor, "Geri al" geri getiriyor.
- [ ] **Kategori üst alanı (Belgeler):** "161 öğe · 220 MB"; Sırala · Süzgeç · Analiz aynı satırda;
      görünmeyen ölçütler × çipleri, "Temizle".
- [ ] **Analiz ve düzenle:** Özet; Genel analiz (ay çubukları, "uzun süredir açılmamış" → liste);
      AI analizi (anahtar yoksa etkinleştir penceresi); AI ile kategorilere ayır → iş sonucu
      ekranı (aşağıda); Etiketleri yönet → yeniden adlandır / sil.
- [ ] **AI etiket iş sonucu ekranı:** İşlemler → etiket işi → düz cümleli özet; **Etikete göre**
      küçük resim ızgarası (fotoğraf, video karesi, PDF kapağı) — dokun = ✕ / ✓, basılı tut = aç;
      etiket çipleriyle süzme; **Dosyaya göre** çip = tak/çıkar; işi arka plana alınca öneriler
      kaybolmuyor. Taşı/kopyala işinde "Taşımayı geri al".
- [ ] **Arama:** son sorgular çip, × siler; tür çipleri SONUÇTAN çıkıyor; kipler **Adında /
      Anlamla (AI) / Dosyaların içinde / İçinde (AI)** süzgeç kapsamında; panoda "✦ Anlamla" →
      "geçen kışki elektrik faturası" → "Aranan:" çipleri + ilgili dosyalar; tekrar basınca ad
      aramasına dönüyor.
- [ ] **Seçim › Daha fazla:** gruplu levha (Düzenle / Kopyala ve gönder / Diğer), "AI ile etiketle"
      vurgulu; galeri ⋮ ve uzun basma menüsü aynı görünüm (menü dili).
- [ ] **Seçimde** galeri/kategori ekranında yana kaydırma sayfa DEĞİŞTİRMİYOR; başlıkta toplam
      boyut doğru.
- [ ] **Liste görünümü:** sıralama menüsünde "Yalnız bu klasör" açıkken sıralama klasöre özel
      (görünüm/sütun gezginde GLOBAL — tasarım, FAZ_PLANI Faz 17 G3); iki parmakla sütun sayısı;
      simge üstündeki uzantı yazısı ("XLSX") net; PDF'ler kapak sayfasıyla, kaydırma akıcı.
- [ ] **Hızlı kaydırıcı:** balon + tutamaç; Arapça'da SOL kenarda.
- [ ] **Uygulamalar ekranı:** boyuta göre sıralı, Ayarlar'daki sayılarla tutuyor; "Kullanım
      erişimi" yokken boyut yerine boşluk (sıfır değil), izin verince hemen geliyor; klasör
      düğmesi "Depolama ve önbellek"e iniyor (MIUI); Bellek Analizi Uygulamalar kartı toplamı.
- [ ] **Sohbet temizliği:** kovadan sil → geri dön → kova sayısı ve panodaki "N dosya · X MB"
      yenilemeden güncel.
- [ ] **Ana ekrana ekle:** Görüntüler → ⋮ → "Ana ekrana ekle" → kendi simgeli kısayol; uygulama
      kapalıyken de Görüntüler'i açıyor.
- [ ] **Dosya seçici 2. tur, kalanı (kategori, sıralama, Tümünü seç çipi, toplam boyut 2026-11-01'de geçti):** yazdıkça arama;
      Temizle; bir seçimden sonra ana sayfada son klasör çipi; depolama çipi "Ana bellek"; gizli klasör dosyaları listede yok.
- [ ] **Seçici kipi (başka uygulamadan "dosya seç"):** PDF isteyen uygulamada doğrudan o türün
      dosyaları (en yeni üstte, "Tümü · PDF 34" çipleri, "Klasörlerde gez"); seçici kapandıktan
      sonra ayarlar kaydediliyor (shared_preferences çökmesi yok); Notlar'dan gelişte "Diğer".

## 3. Gezgin, dosya işlemleri, çöp, Kasa

- [ ] **Yol hapları** geri gidiyor (yeni sayfa açmıyor); hap adı TalkBack'te bir kez okunuyor.
- [ ] **Açılış klasörü** (Dosya yöneticisi ayarları) → kapat-aç → doğrudan orada; klasör
      silinmişse panoya düşüyor.
- [ ] **Listede klasör boyutu** (Ayarlar > Gezinme) açık → boyut beliriyor, kaydırma akıcı.
- [ ] **İndirilenlerde göster:** indirme bildiriminden → satır alt çubuğun arkasında kalmadan görünür.
- [ ] **Yapıştırma çakışması:** aynı adlı dosyanın olduğu klasöre yapıştır → İkisini de tut / Atla /
      Üzerine yaz doğru; pencereyi kapatmak = vazgeç.
- [ ] **İş bildirimi alt çubuğu örtmüyor:** çok dosya seç → Sil → "Çöp kutusuna taşınıyor · n / N"
      kartı seçim çubuğunun ÜSTÜNDE; ana ekran alt gezinmesi ve belge dock'unda da; ilerleme
      penceresinde **"Arka plana al"**; biten iş şeritte/bildirimde "… tamamlandı".
- [ ] **Dolu çöp (≥ 3 bin öğe):** "Boşalt" sırasında pano/kategori takılmıyor, bitince sayı doğru;
      tek öğe sil/geri yükle anında düşüyor.
- [ ] **Kasa:** eski "Gizli dosyalar"ı olan telefonda taşıma kartı → "Kasaya taşı" → Kasa'da
      açılıyor, "Geri çıkar" özgün klasöre (alt klasörleriyle); PIN değiştir önce eski PIN'i
      soruyor.
- [ ] **Geçmiş ekranı** alt çubuğu ve geri tuşu; işlem geçmişi.
- [ ] **Arşiv:** büyük ve solid RAR/7z çıkarma süresi + ilerleme; parolalı ZIP üretme.
- [ ] **Arşiv çıkarmada Durdur (2026-11-02):** büyük RAR/7z/ZIP çıkarırken pencerede **İptal** ve
      şeritte/bildirimde **Durdur** var → birkaç sn içinde duruyor, yarım klasör SİLİNMİŞ, iş
      "durduruldu" (hata değil); aynı arşivi yeniden çıkarmak sorunsuz; arşiv dosyası silinebiliyor.
- [ ] **Belge tarama stüdyosu:** Google tarayıcı (Play Hizmetleri yoksa yedek tarayıcı), kenar +
      kırpma + filtre; resimli sayfa bozulmadan; Kırp (kenar ortası tutamaçları, büyüteç,
      "Kenarları bul"), Döndür, Filtre + "Tüm sayfalara", sıra sürükleme, Yeniden çek, Sil →
      "Geri al", "Kaydediliyor… → Kaydedildi"; "+" → "Fotoğraftan ekle"; "Yazıları da tanı" →
      PDF'te arama; PDF Araçları ⋮ "Sayfa tara ve ekle".
- [ ] **Uygulamanın kapladığı alan** listesinin son satırı ("Android uygulama ayarlarını aç")
      gezinme çubuğunun üstünde; öteki listeler de.

- [ ] **İş sonucu sayfası (2026-11-02):** toplu yeniden adlandır → İşlemler'de kart → "Yeniden
      adlandırıldı" grubu → ⋮ "Adları geri al" eski adları veriyor (eski ad doluysa o dosya kalıyor);
      çok dosyayı çöpe at → kart → "Çöp kutusuna taşındı" → ⋮ "Geri yükle" eski yerlerine; kart
      gizli çöp klasörünü "aç" diye göstermiyor.

## 4. Depolama birimleri (SD kart, USB)

- [ ] **SD kart:** `/storage/XXXX-XXXX` bulunuyor; birimler arası taşımada kopyala+sil yedek yolu;
      yazılamayan kartta hata anlamlı (`sd_readonly`; SAF akışı KALANLAR A7.2 sonrası).
- [ ] **SD birleşik depolama (deneysel):** "Şimdi taşı" ilerlemesi; şarja takınca UYGULAMA
      KAPALIYKEN çalışıyor, şarjdan çıkınca duruyor; bitiş bildirimi; taşınan fotoğraflar
      galeride; Android ≤ 10'da "yazılamıyor" uyarısı.
- [ ] **USB bellek (ham FAT/exFAT yazma, K8):** dosya yaz → "Güvenle çıkar" → çek → PC'de dosya
      sağlam; yazma sırasında çek → tekrar tak → "kirli" bayrağıyla onarım uyarısı, veri
      kaybı yok; çok bölümlü bellekte "Bölüm seç" şeridi.

## 5. Ağ ve aktarım

- [ ] **Yakındakiler (iki telefon):** ekran açılınca HEM alıyor HEM buluyor (Wi-Fi + **BLE**,
      karşı telefon birkaç sn'de listede); gönder → alıcıda önizlemeli **Kabul et / Reddet**
      (reddedilen diske YAZILMIYOR, gönderende "Karşı taraf kabul etmedi"); çok küçük dosya tek
      akışta (ZIP akışı); aktarım yarıda kesilip yeniden bağlanınca **kaldığı yerden**; klasör
      paylaşımı; ortak Wi-Fi yoksa **hotspot daveti** (BLE ile) → alıcı ağa bağlanıyor, iş
      bitince eski ağına dönüyor; ekrandan çıkınca geçici ağ kapanıyor (Wi-Fi listesinde
      DIRECT-/AndroidShare kalmıyor); geçmiş paneli.
- [ ] **Gönderim ekrandan bağımsız, kalanı (gönderen tarafı 2026-11-01'de 300 MB + MD5 ile geçti):** pil üzerinde (USB'siz)
      ekran kapalıyken; bildirimdeki Durdur; hotspot yolu; iki telefonla alıcı ekrandan çıkınca alım sürüyor.
- [ ] **Uygulamasız alıcı (web):** tarayıcıda `http://<ip>:8080` + 6 harfli jeton (elle de
      yazılabiliyor) → küçük resimli liste, "Tümünü indir" ZIP, tek dosyada otomatik indirme,
      sayfa tarayıcı diline göre TR/EN. Hotspot yolunda alıcının tarayıcısı mobil veriye
      gidiyorsa sonucu yaz (KALANLAR B3.4).
- [ ] **Metni QR kodda göster (2026-11-02):** küçük bir `.txt`/`.md` (≤ 8 KB) → Paylaş → üç seçenek
      (Yakındakiler · **Metni QR kodda göster** · Diğer uygulamalar); QR ekranı açılıyor, başka
      telefonun kamerası metni okuyor; uzun notta 1/n… sırayla + "Otomatik"; PDF'te ya da çoklu
      seçimde bu seçenek YOK.
- [ ] **QR ile al:** pano yüzen çubuğu → QR → Google kod tarayıcısı (kamera izni SORULMAZ) →
      onay levhası (dosyalar, toplam, klasör) → iptal edilebilir indirme → "N dosya alındı · Aç".
- [ ] **Ağdan erişim (FTP sunucusu):** BAŞLAT → `ftp://<ip>:2121` + kullanıcı/parola; PC
      gezgininde kök kutular (Telefon · İndirilenler · Kamera …); indir/yükle; uygulamadan çıkınca
      ve ekran kapalıyken aktarım sürüyor; kalıcı bildirim → ekrana götürüyor; panoda kapatılamaz
      satır + "Kapat"; *Yazma izni* kapalıyken PC'den silme reddediliyor; *Gizli dosyalar*
      kapalıyken `.` klasörleri görünmüyor; son kullanılanlardan kapatınca paylaşım bitiyor.
- [ ] **Ağ depolama (NAS):** "Ağda ara" NAS'ı buluyor (mDNS + port); SFTP/FTP/FTPS/WebDAV/SMB2
      "Bağlantıyı sına" yeşil; gez, aç, Buraya yükle, yeni klasör, yeniden adlandır, sil; parola
      kaydı kapalıyken her bağlanışta soruyor; yanlış adres/parola ANLAŞILIR hata; SMB3-zorunlu
      NAS varsa sonucu yaz.
- [ ] **Google Drive:** OAuth istemcisi kayıtlıysa (KALANLAR B5.5) "Google ile bağlan" → hesap +
      Drive izni; uzun bas → Drive'a yükle; listede görünüyor, dokununca inip açılıyor; sil; büyük
      indirmede "Arka plana al" ve "Durdur" (yarım dosya kalmıyor). Kayıt yoksa: "Google girişi bu
      APK için etkinleştirilmemiş" + "Sistem seçicisiyle Drive dosyası aç" çalışıyor, çökme yok.
- [ ] **Paylaş / Birlikte aç:** WhatsApp'tan gelen dosya açılıyor (octet-stream); `.apk`'ya
      "birlikte aç" listesinde uygulamamız YOK; `content://` bağlantısıyla açılış çökmesiz
      (derin bağlantı koruması).

## 6. PDF — görüntüleme ve araçlar

- [ ] **Kasma turu (2026-11-03, pdfrx 1.3.5'e dönüldü):** kullanıcının "40 Hadis İmam Nevevî" PDF'i (her
      sayfada 12 MP saydam arka plan resmi) → açılış ve kaydırma 2.x öncesi kadar akıcı; 50+ MB PDF'te ilk sayfa
      geçiş biter bitmez görünüyor (form taraması izolatta); uzun basış kelime seçiyor; taranmış PDF'te
      kaydırırken takılma yok, sayfa birkaç sn sonra seçilebilir (OCR JPEG/izolat — 1.3.5'te RGBA/BGRA
      ikisi de: tanınan metin doğru mu?); form PDF'inde "doldurulabilir form" önerisi çıkıyor.
- [ ] **Kaldığın yerden:** uzun PDF'i yarıda bırak, kapat-aç → o sayfa + "Baştan başla" şeridi.
- [ ] **Kaydırma:** hızlı fırlatma Word/listeler kadar gidiyor; sayfa başına geri ÇEKMİYOR; iki
      parmak yakınlaştırıp bırakınca zıplama yok; yakında yazı keskin (basamaklı çizim
      ölçeği, kenar bulanıklığı/atlama yok).
- [ ] **Okuma kipi:** kaydırınca çubuklar gövdenin üstünden kayıp gidiyor, gövde ZIPLAMIYOR;
      2,2 sn sonra geri geliyor; arama açıkken gizlenmiyor; Tam ekran.
- [ ] **Aa levhası:** okuma görünümü, 1/2/4 sütun (2/4 sütunda sayfalar genişliğe sığıyor), gece
      modu (ters renk okunaklı), "kaldığım yerden aç" — değişiklik arkada canlı.
- [ ] **İçindekiler** (☰): başlık → sayfa; olmayan belgede "içindekiler yok".
- [ ] **Bağlantılar:** onay penceresi tam adres; "Aç" tarayıcıyı açıyor; iç bağlantı sayfaya atlıyor.
- [ ] **Arama:** Türkçe duyarlı (İ/ı), sonuçlar vurgulu, ‹ › o sayfaya kaydırıyor.
- [ ] **Metin seçimi:** uzun bas → tutamaçlar, kopyala; seçim çubuğunda Çevir (ML Kit dil modeli
      iniyor) ve "Düzenle" (düzenleyici seçimin sayfasında açılıyor).
- [ ] **Vurgu:** sarı/yeşil/pembe/mavi seçilen metnin tam üstünde; kaydet-aç sonrası kalıcı;
      **`cropbox.pdf`** ve döndürülmüş sayfada da yerinde (başka okuyucuda bak).
- [ ] **Sesli oku:** Türkçe okuyor, duraklat/devam/durdur; ekrandan çıkınca susuyor; taranmış
      PDF'te "önce OCR" uyarısı; yapay zekâ sesi seçiliyse onunla (cihaz sesine düşme yedeği).
- [ ] **OCR (Metni tanı):** taranmış PDF / görsel → seçilebilir metin + AI bağlamı.
- [ ] **PDF Araçları:** küçük resimler; seç → döndür/sil/öne-arkaya doğru sayfaya; "Çıkar" ayrı
      PDF; "Başka PDF ekle" birleştiriyor; parola koy (kapat-aç → soruyor) / kaldır; sıkıştır
      boyutu düşürüyor (taranmışta kazanç küçük — beklenen); kaydet sonrası görüntüleyici tazeleniyor.
- [ ] **PDF çevir → "belgenin kendisi":** özgün düzende; atlanan paragraf sayısı doğru (Türkçe →
      Arapça'da çoğunun atlanması beklenen).
- [ ] **Slayt ↔ PDF:** `.pptx` → PDF: slaytlar ekrandakiyle birebir (görseller boş değil, 20+
      slaytta donma yok), yazı seçilebilir/aranabilir; PDF → ⋮ → Slayta dönüştür → düzenleyicide
      açılıyor; bölme mantıklı (PowerPoint'te açılış §13).
- [ ] **Resim → PDF** + "Yazıları da tanı" → resim TAM, yazı aranabilir.
- [ ] **Daha fazla sayfası:** OCR "Dönüştür" grubunda.

- [ ] **Kâğıt teması sayfa çerçevesi (2026-11-02):** kâğıt temasında (açık) PDF sayfalarında gölge
      yerine ince bej çerçeve, yakınlaşınca da 1 piksel; öteki temalarda eski gölge.

## 7. PDF — düzenleme (Faz 31 + 2026-10-31)

- [ ] **Kabuk:** Düzenle → şerit sekmeleri Metin · Görsel · İmzala · Form · Filigran · Sayfa (+ Çiz,
      AI); düzenlerken klavye üstü çubuk; ↶ ↷ üstte.
- [ ] **"Ne oluyor" hissi:** sayfa açılınca ipucu şeridinde "Sayfa N okunuyor…" çarkı; meşgulken
      paragrafa dokununca "Bir saniye — …"; Bitti'den sonra yeni metin yerinde kalıp sayfa
      yenileniyor (eski metin bir an görünmüyor); sayfa değişince eski kutular görünmüyor.
- [ ] **Yerinde paragraf:** dokun → kendi kutusunda alan, ~18 px'e yakınlaşma; **tek satırlık başlık
      tek satır kalıyor** (Word çıktısı, e-Devlet, tarama + OCR — en az üç farklı PDF); yazı
      tipi/punto/hizalama korunuyor; uzatınca düzgün sarıyor; **ortalı başlık kısalt/uzat → ortalı
      kalıyor**; taranmış/OCR satırı da yerinde (klavye açılınca satır görünür).
- [ ] **Ret → "Üstüne yaz":** paragrafın KENDİ gömülü yazı tipiyle; harf alt kümede yoksa **aynı
      aileden** gömülü karşılık (2026-11-02: serif/Times kitapta **Tinos**, italikse italik; sans'ta
      Carlito); eski metin aramada/kopyada da yok.
- [ ] **Kalın / renk:** Word'den çıkmış PDF'te paragraf → K → Bitti (gömülü kalın kesim); kesim yoksa
      ret + "Üstüne yaz" kalın; renk kırmızı → Acrobat/Chrome'da aynı.
- [ ] **Nesneler:** Yazı ekle (`taranmis.pdf`, `dondurulmus_90.pdf`, `cropbox.pdf`'te dokunulan yerde,
      DÜZ), imza (bir kez çiz → hatırlanıyor), baş harf, görsel ekle → kaydedilene kadar seç, taşı,
      dört köşeden oran kilitli boyutlandır, yeniden yaz, sil; yakında keskin (vektör);
      **döndürülmüş sayfada** imza doğru köşede ve dik.
- [ ] **Var olan görsel:** logo/QR/arma seç → taşı (kesilmiyor), dört köşe boyut, merkezinde döndür
      (iki kez), ayna, sil.
- [ ] **Form (`formlu.pdf`):** alanlar sayfada (metin yerinde, onay kutusu tek dokunuş, liste/radyo
      levhadan, ‹ › ✓); Türkçe değer (Ayşe, İstanbul) kaydediliyor; kaydedilen dosya Acrobat/
      tarayıcıda dolu; "Doldurduktan sonra kilitle" sayfaya işliyor; form olmayan PDF'te açıklama;
      döndürülmüş sayfada liste ekranı yedeği.
- [ ] **Filigran:** "KOPYADIR" benzeri damga listede, kaldırılıyor; gerçek içerik listede yok.
- [ ] **Sayfa:** 90° sağa/sola.
- [ ] **Çiz / AI sekmeleri:** Çiz → çiz → Uygula → düzenleyicide ↶ çizimi siliyor; AI düzenleme
      çalışma kopyasının metniyle.
- [ ] **Kaydet:** "Orijinali değiştir / Kopyasını kaydet / Klasör seç" + "AÇ"; kaydetmeden çıkınca
      özgün dosya DEĞİŞMEMİŞ; büyük PDF'te bellek (§1).

## 8. Word

- [ ] **Kasma turu (2026-11-03):** resimli/uzun .docx aç → "açılıyor" göstergesi donmuyor, sayfa geçişi
      akıcı (ayrıştırma + görünüm kopyası izolatta); düzenle/kaydet/geri al eskisi gibi. Kapanırken ve şerit /
      alt levha açılırken hâlâ takılma varsa → KALANLAR B3.3d (hybrid composition).
**Bütün editörlerde ortak (Faz 20 — Word, Excel, Slayt, Metin, PDF, Görsel):**
- [ ] Klavye açılıp kapanırken klavye üstü çubuk klavyeyle birlikte kayıyor (zıplama yok).
- [ ] Otomatik kaydetme: düzenle, 3 sn bekle → başlıkta "Kaydedildi"; uygulamayı zorla kapat →
      yeniden aç → taslak şeridi "Geri yükle"; geri yazılamayan dosyada (e-posta eki) ilk kayıtta
      "Kopya olarak kaydet" önerisi.
- [ ] Çıkışta kaydedilmemiş değişiklik sorusu (Kaydet / Atma / Vazgeç).

**Görüntüleme (sayfa görünümü, WebView):**
- [ ] Açılınca sayfa ekran genişliğini dolduruyor; yakınlaştırınca yazı keskin + ölçek rozeti;
      "Sayfa 3 / 12" rozeti ortada, dokununca o sayfaya; okuma kipinde gövde dolgusu doğru.
- [ ] **Sadakat:** Calibri/Times/Arial'lı gerçek belgede satır/sayfa kırılımı Word'le aynı yerde,
      fontlar (Carlito/Tinos/Arimo) yükleniyor; madde imleri ▯ değil • / ➢ / ✓ / ▪
      (`madde_imleri.docx`, ESNEKLİK-REZİLYANS belgesi).
- [ ] **Arapça (`arapca_rtl.docx`):** metin sağdan akıyor, harfler kutu değil.

**Mobil görünüm editörü (Düzenle) — K18 kontrol noktası; onaylanırsa KALANLAR B3.2:**
- [ ] **Gboard ve Samsung Klavye ayrı ayrı:** `ğüşıöçİ` kaybolmuyor/çiftlenmiyor; kaydırarak yazma;
      sesle yazma; öneri çubuğu kelimeyi değiştiriyor; cümle başı büyük harf.
- [ ] **Geri silme** harf siliyor (kök neden düzeltmesi 2026-10-23), imleç yanıp sönüyor.
- [ ] Enter yeni paragraf; başlık sonunda Enter → gövde; boş maddede Enter → listeden çıkar;
      paragraf başında geri silme birleştiriyor (boş paragrafta da).
- [ ] Uzun bas → kelime + mavi tutamaklar + **büyüteç**; çift dokunuş kelime, üç dokunuş paragraf;
      seçim paragraflar arası uzuyor; bağlam çubuğu Kes/Kopyala/Yapıştır/Tümünü seç/Çevir/AI ile düzelt.
- [ ] Yanlış kelimenin altında kırmızı dalga, dokununca öneriler.
- [ ] Büyük belgede açılışta ilk paragraflar önce görünüyor; Arapça belgede sağdan sola yazma.
- [ ] Akıcılık puanı 1–5: ___ (isteğe bağlı: geliştirici bayrağıyla eski sayfa üzerinde düzenleme
      kıyası ___).

**Biçim ve ekleme (Faz 23–24 + 2026-10-30/31):**
- [ ] Klavye kapalıyken Giriş · Görünüm · Gözden Geçir şeridi, açıkken klavye üstü çubuk (↶ K T A •
      1. ⇤ ⇥ hiza renk Aa ⌄) — geçiş takılmasız; **Aa** paneli klavye yüksekliğinde, imleç satırı
      yerinde, ⌨ ile klavye geri.
- [ ] Kelimeye kalın + kırmızı + 16 pt + vurgu; paragrafa Başlık 1; madde/numara/çok düzeyli liste;
      **liste kalıbı galerisi** (✓, A., i.); satır aralığı 1,5; ortala (masaüstü kontrolü §13).
- [ ] Biçim boyacısı: tek dokunuş bir kez, çift dokunuş kilit, ✕ ile biter.
- [ ] Görünüm > Gezinti başlığa kaydırıyor; Türkçe Word'de kaydedilmiş belgede (stil kimliği
      `Balk1`) Başlık 1 belgenin kendi stiliyle.
- [ ] **Kalın kelime kopyala/yapıştır** kalın kalıyor (kendi panomuz).
- [ ] **Bağlantı:** dokun → düzenle (metin/adres) · Aç · Kaldır.
- [ ] **Tablo:** hücreye dokun → Tablo sekmesi; satır/sütun ekle-sil, başlık/bant/gölge; hücreye yaz
      (`tablo.docx` "Ayşe"); kaydet-aç sonrası duruyor.
- [ ] **Resim:** Ekle → galeriden → paragrafın altında; tutamakla boyut, Resim sekmesi, alternatif
      metin, sil.
- [ ] Yorum ekle/yanıtla/çözüldü/sil; dipnot; yatay çizgi; tarih/saat; üst/alt bilgi; izlenen
      değişiklikleri tümünü kabul/ret.
- [ ] **Tablet (≥ 840 dp):** Aa paneli sağda, yazarken klavye kapanmıyor. **Donanım klavyesi:**
      kısayollar + Ctrl+/ yardım levhası. **TalkBack:** bir paragraf yazıp kalın yapılabiliyor;
      şeritte "Kalın, açık/kapalı".

- [ ] **Kanvas teması (2026-11-02):** koyu temada Word sayfasının çevresi KOYU (eskiden açık gri);
      kâğıt temasında (açık) sayfa kâğıt rengi `#FBF8F1` + ince bej çerçeve, gölge yok; akış
      görünümünde çerçeve yok; tema değiştirip geri dönünce kanvas hemen değişiyor.

## 9. Excel

- [ ] **Hücre girişi:** %100'de seçili hücreye ikinci dokunuş hücre üstünde editör; ✓ ↵ ⇥ oklar (⇥ ile
      satır girip ↵ satır başı sütununa); sayı hücresinde uygulama tuş takımı, "ABC" sistem
      klavyesi; `=` yazıp hücreye dokununca başvuru + renkli çerçeve; yazarken mavi çerçeve YOK.
- [ ] **Akıllı giriş:** `1.234,56`, `%15`, `₺100`, `23.10.2026`, `14:30` doğru tür ve biçim;
      `=TOPLA(A1;A2)` (masaüstü kontrolü §13).
- [ ] **Seçim:** tutamaklarla aralık genişliyor; hızlı fırlatma veri sonuna; uzun bas → bağlam menüsü
      (yalnız değerleri / biçimi yapıştır, devrik yapıştır); kaydırma sürerken pinch tutuyor mu
      (tutmuyorsa KALANLAR B3.4).
- [ ] **Düzenleme çekirdeği:** geri al / yinele; kopyala → yapıştır formül başvurusu kayıyor
      (`=A1*2` bir sağa → `=B1*2`); kes → yapıştırınca kaynak boşalıyor; doldurma tutamağı sayfa
      kaymadan (1,2 → 3,4,5; Ocak → Şubat), çift dokunuşla sütun boyunca, **köşegen** (1,2 / 10,20
      bloğu → C1=19…); Σ doğru aralık; 🔍 Tümünü değiştir tek geri al adımı; satır/sütun sil →
      geri al veri VE biçimi getiriyor; başka uygulamaya yapıştırınca sekmeyle ayrılmış tablo.
- [ ] **Biçim:** Hücreleri biçimlendir paneli (sayı: Para ₺/Yüzde/Tarih; ondalık artır/azalt; dolgu,
      yazı rengi, kenarlık, kaydır, birleştir), hücre stilleri, koşullu biçim; biçimli hücrenin
      kalın/renk/kenarlığı bozulmuyor; hepsi geri alınıyor.
- [ ] **Veri:** A→Z / Z→A (satırlar bütün), değer süzgeci, özel sıralama, veri doğrulama + Durdur,
      form görünümü, notlar (deneysel K24).
- [ ] **Görünüm:** sığmayan metin boş komşuya taşıyor, çok satırlı hücreler Excel kadar yüksek;
      kılavuz çizgileri; durum çubuğunda "Sayfa 1 / 3"; büyük dosyada kaydırma (§1).
- [ ] **Sayfa sekmeleri:** basılı tut + sürükle = sırala (yerinde bırakınca menü); Sola/Sağa taşı;
      renk, gizle, çoğalt, ekle/yeniden adlandır/sil.
- [ ] **Grafik:** `satis.xlsx` A1:C4 → Ekle → Grafik (Sütun/Çubuk/Çizgi/Pasta önizlemesi) → ızgarada
      taşı/boyutlandır/tür/sil; **dosyadaki grafikler** hücrelerin üstünde doğru yerde.
- [ ] **Tablo olarak biçimlendir** → kaydet (masaüstünde "Tablo Tasarımı" §13).
- [ ] **Çeviri:** birkaç hücre seç → Çevir → yalnız seçim.
- [ ] **Okuma sınırı:** 200 bin satırı ya da 1024 sütunu aşan dosyada kırmızı şerit, Kaydet "kaydetme
      kapalı", dosya değişmiyor; büyük kitapta Paylaş/İndir'de ekran donmuyor.
- [ ] **RTL:** Arapça `.xlsx` → A sütunu SAĞDA, kaydırma sağdan, metin sağa/sayı sola; ⋮ > Sayfa
      sağdan sola → kaydet → Excel'de korunuyor; hücre hizası belge içeriği olarak AYNALANMIYOR.
- [ ] **Donanım klavyesi:** oklar, ⇧+ok, Ctrl+ok, ⇥, ↵, F2, Delete, Home, PgUp/Dn, harfle yazmaya
      başlama; Ctrl+/ yardım. **TalkBack:** hücre "B2, Armut".

## 10. Slayt

- [ ] **Sadakat:** oklar, üçgen, elmas, chevron, yıldız, altıgen, artı, silindir, akış kutuları kendi
      biçiminde; basık elips oval; kırpılmış fotoğraf doğru kadraj/oran; çerçeve; yuvarlak köşe;
      flipH/flipV doğru yön; konuşma balonu kuyruğu; tema renkli şekiller dolu; tablo yalnız tanımlı
      kenarlar; gömülü font + Arimo kalın; bağlayıcı ok/kesik çizgi; gölge; grafikler (sütun/çubuk/
      pasta/halka/çizgi) doğru veri/renk; madde imleri "§"/"Ø" yerine ▪/➢.
- [ ] **Gezinme:** kartlarda "Slayt 3 / 12" rozeti → "Slayta git" (yakınlaştırılmışken de); 🔍 arama
      ‹ › + bağlam satırı; AI özet Kısa/Detaylı slayt numaralı; düzenlerken geri tuşu düzenlemeyi
      kapatıyor; sunum modu (tam ekran, yatay, zoom, animasyon adımları, geçiş oynuyor, gizli
      slayt atlanıyor).
- [ ] **Yerinde metin (Faz 28):** şekle dokun → çerçeve + tutamaklar + bağlam çubuğu; tekrar dokun →
      kutuya yakınlaşma takılmasız, yazı ≥ 16 dp, klavyenin üstünde; uzun kutuda imleç ekranda
      kalıyor; Gboard + Samsung'da Türkçe, otomatik düzeltme, öneri; kelimeye K/renk/punto yalnız
      ona; Enter madde işaretli yeni paragraf, geri silme birleştiriyor; boş "Başlık eklemek için
      dokunun" yer tutucusu; Anahat görünümü slayta yansıyor; ⋮ > Konuşmacı notu.
- [ ] **Nesneler (Faz 29):** sürükle = taşı (liste kaymıyor), köşe = boyut, üst ok = döndür; hizalama
      kılavuzları (pembe çizgi + titreşim, donanım klavyesinde ok 1 pt / ⇧ 10 pt); Ekle → metin
      kutusu / şekil / **tablo 3×4** (hücreler arası ⇥ / ⇧⇥, klavye üstü ‹ ›) / **görsel** (ortada,
      oran doğru) / düzenden yeni slayt; **Düzeni değiştir** (metin kaybolmuyor); **grup içindeki
      şekli** sürükle; tablo hücresine uzun bas → tabloyu bütün olarak taşı/boyutlandır; Çizgi
      (renk, kalınlık, kesik) + Saydamlık %50; "Şekli metne göre boyutlandır" kutusu Bitti'de
      büyüyor; şekil çubuğu Kes/Kopyala/Yapıştır/Çoğalt/Öne/Arkaya/Sil + ↶.
- [ ] **Slaytlar:** küçük resim şeridi (dikeyde altta, yatay tablette solda; dokun = git, güncel
      küçük resme dokun = menü, uzun bas + sürükle = sırala); sıralayıcı ızgarası; çoğalt/sil/taşı;
      ⋮ → Slaytı gizle ("Gizli" + soluk); Tasarım → arka plan, geçiş (Soldur/İt/Sil).
- [ ] **Çeviri:** metin kutusunda kelime seç → şeritte Çevir → yalnız seçim.
- [ ] **TalkBack:** slayt şekli yazısıyla okunuyor.

## 11. Metin, kod, Markdown, eski biçimler

- [ ] **Büyük metin:** 50 MB kayıt dosyası → "Büyük dosya — salt okunur" şeridi + satır sayısı +
      kodlama; kaydırma çubuğunu sürükleyerek hızlı kaydırma takılmıyor, bellek uyarısı/çökme yok.
- [ ] **Kodlamalar:** `metin_utf8.txt`, `metin_cp1254.txt`, `metin_utf16le.txt` aynı Türkçe metin;
      düzenle-kaydet sonrası kodlama korunuyor; `noktali_virgul.csv` üç sütun.
- [ ] **Kod:** 2 MB dosyada renklendirme yazma durunca geliyor, yazarken takılma yok; satır aralığı
      1,8 → numaralar hizalı; girinti 2/4/8; Ctrl+/ yardım.
- [ ] **Markdown:** önizleme; tablette (≥ 840 dp) editör | önizleme yan yana, yazdıkça güncel.
- [ ] **Eski `.doc/.xls/.ppt`:** "SALT OKUNUR" rozeti → "DOCX yap ve düzenle" → yanına `ad.docx`
      (varsa `ad (2).docx`), Word ekranı açılıyor; `.ppt` → `.pptx`, `.xls` → `.xlsx`.
- [ ] **Yeni belge** oluşturma (Word/Excel/Slayt/metin) ve "Belgeyi çevir" (Word/Excel/Slayt menüsü).

## 12. Görsel, galeri, video, ses

- [ ] **Galeri:** büyük fotoğraflı klasörde hızlı sağa-sola kaydırma takılmasız, kendiliğinden
      kapanma yok; 3-4 kat yakınlaştırınca yazı keskin; slayt gösterisi; "Farklı kullan";
      **EXIF yönü** `orient_6.jpg` / `orient_8.jpg` DİK (sol üst kırmızı), Boyutlandır "Şu an 300×400".
- [ ] **Görsel düzenleyici 2.0:** Kırp (4:3, 4:5, 3:2, 21:9, A4, Orijinal, Özel; "1080 × 1350"
      etiketi), serbest açı −45…45, Döndür, yatay/dikey çevir, Ayarla (11 ayar, tek dokunuşla
      sıfır), 10 filtre + şiddet, kalem/vurgulayıcı/silgi/ok/çizgi/dikdörtgen/elips, yazı nesnesi
      (sürükle, sağ alt tutamakla büyüt, üst tutamakla döndür, tekrar dokun = düzenle; Tırnaklı,
      Arka plan; "Şğİ"), bulanıklaştır/pikselleştir (kaydedince plaka okunamıyor), iki parmak
      yakınlaştır (çizerken ikinci parmak çizgiyi bırakmadan), çift dokunuş sığdır, **Boyut**
      sekmesi (%50 / 1080 px, en yazınca boy, kırp → boyut → Kaydet doğru ölçü), karşılaştırma
      simgesine BASILI TUT → özgün; "Kopya olarak kaydet" → `ad (1).jpg`, kayıt önizlemeyle aynı,
      özgün dokunulmamış; `orient_6.jpg` kırp 1:1 + döndür → kopya dik.
- [ ] **Boyutlandırma 2.0 (fotoğraf):** galeri → "Boyut" levhası "Boyutlandır (1 dosya)"; genişlik
      1600 → yükseklik anında (kilit); kilit kapalı 1080×1080 → Doldur ve kırp / Kenar boşluğu
      (Bulanık) / Esnet; %150 kırmızı uyarı ve çıktı silinmiyor; uzun kenar 1600 dikey (EXIF 6) →
      1200×1600 DİK; 4:5 + boşluk, 16:9 + kırp; **"≤ 200 KB"** → 3-5 MB fotoğraf ≤ 200 KB, süre
      makul, iş özetinde boyut; kırpma çapası Üst/Sol/Sağ (Arapça'da da görüntünün solu); canlı
      önizleme küçük resmi (50 fotoğraflık seçimde levha gecikmiyor); son ayar hatırlanıyor ama
      "Özgünü çöpe at" HEP kapalı; ön ayar kaydet → kapat-aç duruyor → basılı tut sil; konum
      kaldır → konum YOK, tarih/kamera VAR.
- [ ] **HEIC / WebP / GIF:** telefonda çekilmiş HEIC boyutlandırma + düzenleyicide açma; WebP çıktı;
      `anim.gif` → JPEG kopya, "özgünü çöpe at" uygulanmıyor (kare kaybı uyarısı).
- [ ] **Video oynatıcı:** `clip.mp4` / `clip.mkv`, büyük mkv/HEVC; `clip.srt` kendiliğinden altyazı
      (Türkçe bozulmadan); jestler (parlaklık kaydırması, uzun basış 2×, kilit, yatay sarma, tam ekran
      yatay geçiş); A-B tekrar; dokunmadan beklerken ekran SÖNMÜYOR, duraklatınca normal zaman
      aşımı; ana ekrana çıkınca duruyor, dönünce kaldığı yerden; kendin duraklattıysan dönüşte
      BAŞLAMIYOR; **PiP** ("Küçük pencerede oynat", oynarken ana ekrana → kendiliğinden PiP,
      büyüt → oynatıcı; "diğer uygulamaların üzerinde göster" izni YOK).
- [ ] **Video küçültme (Media3):** 1080p → 720p 30 fps "Dengeli" → yüzde akıyor, 1280×720 (dikeyde
      720×1280), süre aynı; "sesi çıkar" sessiz; serbest 1234×568 birebir; iptal → yarım dosya
      yok; `clip.mkv` → MP4 oynuyor; **oran kipleri** 1920×1080 → 1:1 + Kırp = 1080×1080 ortadan,
      esneme yok / 1:1 + Kenar boşluğu = siyah şerit; kilit kapalı 1080×1080 dört kip farklı ve
      doğru; **dosya boyutu hedefi** 1 dk 1080p → "≤ 10 MB" ≈ 10 MB (±%15), "≤ 2 MB" çözünürlüğü de
      indiriyor, ses duruyor.
- [ ] **Ses:** müzik klasörü → çal, ekranı kilitle → sürüyor; bildirim/kilit ekranı kontrolleri
      (sürüklenebilir ilerleme, önceki/sonraki), kulaklık düğmeleri; parça bitince sıradaki;
      tekrar/karışık (karışık kapat-aç sonrası korunuyor); hız 1,5×; telefon çalınca susuyor;
      `tagged.mp3/.m4a/.flac` → "Örnek Şarkı", sanatçı · albüm, turuncu kapak.
- [ ] **Sesli kitap + yapay zekâ sesleri:** Antalia / EMA indir → sesli kitap üret (Android
      WebView'da ONNX çalışıyor mu, süre); uygulama alttayken üretim sürüyor mu (KALANLAR B3.4);
      bildirimde "Durdur"; çıktı M4A, Müzik/Sesli Kitaplar'da görünüyor; sesli okumada yapay ses
      seçilebiliyor.
- [ ] **AI özet:** hazırlanırken ekrandan çık → bildirim/şeritten açılıyor; tekrar basınca yenisi
      başlamıyor, kayıtlı özet anında açılıyor.
- [ ] **Akıllı analiz:** WhatsApp "günaydın" görselleri OCR ile bulunuyor (süre §1).

## 13. Office uyumluluk tablosu (masaüstü — KALANLAR B4)

Her dosyayı **masaüstü Word/Excel/PowerPoint**, **Google Dokümanlar/E-Tablolar/Slaytlar** ve
**LibreOffice**'te aç: onarım uyarısı yok + içerik doğru. Sonucu tabloya yaz.

| Dosya / işlem | Beklenen | MS Office | Google | LibreOffice |
|---|---|---|---|---|
| `tablo_duzenlendi.docx` | resim, madde işareti, "Mart" 16 pt kalın, "Ayşe Kaya" | | | ✔ (bulut) |
| Mobil editörde biçimlenmiş .docx (kalın/renk/16 pt/vurgu, Başlık 1, 3 liste türü + liste galerisi, 1,5 aralık, ortala) — `numbering.xml`'siz belgede de | aynı görünüm | | | |
| .docx: tablo (satır/sütun, bant), resim + alternatif metin, yorum, dipnot, üst/alt bilgi, bağlantı, izlenen değişiklik kabul/ret | yerinde | | | |
| .docx: Türkçe font/punto seçimi | korunmuş | | | |
| `satis_duzenlendi.xlsx` | grafik E-M sütunlarında, sayfa sırası *Notlar, Özet* | | | ✔ (bulut) |
| .xlsx: sayı biçimleri (₺/%/tarih), dolgu/kenarlık/birleştirme, koşullu biçim | biçimler duruyor | | | |
| .xlsx: `=TOPLA(A1;A2)` gibi Türkçe formül | doğru işlev, `#AD?` yok | | | |
| .xlsx: Tablo olarak biçimlendir | "Tablo Tasarımı" sekmesi | | | ✔ (bulut) |
| .xlsx: dondurulmuş bölme + ızgara ayarı + süzgeç okları olan dosyada tek hücre değiştir | hepsi duruyor | | | |
| .xlsx: gizli sütun, sayfa sağdan sola, sayfa sırası (taşı), sekme rengi | korunmuş | | | |
| .xlsx: not ekle (deneysel K24) | onarımsız, not görünüyor | | | |
| .xlsx: kaydedilen dosyanın Drive/dosya yöneticisi önizlemesi | formül SONUÇLARI görünüyor | | | |
| `sunum_duzenlendi.pptx` | "Gelir %12 arttı" | | | ✔ (bulut) |
| .pptx: yerinde metin (K/renk/punto), yer tutucuya yazı → başlık, konuşmacı notu (notesMaster'sız destede de) | onarımsız | | | |
| .pptx: taşı/boyut/döndür, tablo 3×4 + renkler, görsel ekle, sıralama, gizli slayt, çizgi/saydamlık, spAutoFit boyu, Düzeni değiştir, grup içi taşıma | aynı konum/görünüm | | | |
| PDF → Slayta dönüştür çıktısı | onarımsız açılıyor | | | |
| Düzenlenen PDF'ler (yerinde metin, kalın/renk, form, imza) | Acrobat/Chrome'da aynı | — | — | — |

## 14. Görünüm, dil, erişilebilirlik, sistem

- [ ] **Temalar:** 4 tema + **Kırık beyaz** (mavisiz, adaçayı vurgu) + **Sistem rengi** (yalnız
      Android 12+ listede, duvar kâğıdı rengi); eski seçilmiş tema/yazı tipi (Okyanus,
      Merriweather) güncellemeden sonra Modern/Tinos'a dönmüş; kâğıt temasında büyük yazıda taşma
      yok, koyu temada kart kenarları görünüyor, Arapça'da cetvel/özet yönü doğru, serif başlık +
      sans gövde okunaklı.
- [ ] **Görsel dil (15b — görünüm DEĞİŞMEMELİ):** simge ailesi (çizgi/dolu karışımı yok; kategori
      simgeleri bilinçli çizgi), Office şeridi beyaz yazı/simge, PDF küçük resimleri beyaz kâğıt,
      galeri/video perde yazıları, kırpma kılavuzları, bulma vurgusu, yazı boyları önceki sürümle
      aynı; soluk metin (yol, sayaç, zaman) 4 tema × açık/koyu okunur; Modern açıkta yeşil
      "başarılı" rengi.
- [ ] **Onay pencereleri:** "Sil" kırmızı dolgulu, vazgeç solda; yeniden adlandır/yeni klasör
      penceresinde uzantı seçimin dışında; art arda uyarı şeritleri sıra beklemeden yer değiştirip
      kayboluyor.
- [ ] **Animasyonları kaldır** (Erişilebilirlik ya da geliştirici ölçekleri) → geçişler anında;
      galeri şeridi, slayt gösterisi, sohbet kaydırması atlayarak; çökme yok.
- [ ] **Büyük yazı:** uygulama içi %200 + sistem %200, 360 dp telefonda gezgin, Son açılanlar, Yeni
      gelenler, ayarlar, arama, çöp, editör şeritleri taşma şeridi yok.
- [ ] **TalkBack:** dosya satırı "PDF, Kira sözleşmesi, 117 KB · dün" TEK kez; yerel bağlam menüsünde
      **"Seç"** eylemi seçim kipini açıyor; etiketsiz "uzun bas" düğümü yok; büyük kopyalamada %10
      adımlarla duyuru (her saniye değil) — şerit, İşlemler ekranı, ilerleme penceresi; editörler §8–10.
- [ ] **Dil:** English → dosya yöneticisi, PDF, slayt, sohbet, Excel/Word dahil Türkçe metin
      KALMAMIŞ; العربية → arayüz aynalı (geri oku, sekme sırası, kaydırıcılar, rozetler, fotoğraf
      ızgarası grup etiketleri), "117 KB · 22 …" sırası doğru, cihazın Arapça fontu okunur; dil
      seçimi kapat-aç sonrası korunuyor; "Sistem"de telefon dili izleniyor; **Android 13+ uygulama
      başına dil** listesinde Türkçe/English/العربية ve oradan seçim yansıyor.
- [ ] **Sistem entegrasyonu:** açılış ekranı açık/koyu; başlatıcı kısayolları; ana ekran pencere
      öğesi (son dosyalar); **tahminli geri** (Android 14+ geri jesti önizlemesi, düzenlemeden
      çıkarken sorma, açık pencereyi önce kapatma); dokunsal geri bildirim.
- [ ] **İlk açılış ve yardım:** ilk açılış rehberi (seçici kipinde YOK); Yardım/SSS; "Sorun bildir"
      (hata kaydı sürümle).
- [ ] **Ayarlar:** Pil ve başarım → "Yüksek tazeleme hızı" kapalı → 60 Hz, tercih korunuyor;
      Başarım Otomatik/Hafif/Tam (düşük cihazda Hafif varsayılanları); Gemini anahtarı + model
      listesi API'den kendiliğinden doluyor; güncellemeden sonra anahtar kayıtlı (Keystore göçü).
- [ ] **Gemini işlevleri (AppFunctions, destekleyen cihaz/Gemini sürümünde):** Gemini'den "son açılan
      dosyalarım", "… dosyasını bul/aç" → Dosya Okuyucu'da açılıyor; kilitli ve AI kapsamı dışı
      klasörler dönmüyor.

## 15. Kurulum, kararlılık, kişisel derleme

- [ ] **Güncelleme:** nightly eskisinin üstüne kuruluyor (aynı imza), ayarlar/anahtar/son dosyalar
      duruyor.
- [ ] **R8'li sürüm:** açılış çökmesiz; ML Kit (OCR/çeviri), Drive girişi, Yakındakiler, Media3,
      PDF yazma (Syncfusion) çalışıyor.
- [ ] **48 saat iç test** (KALANLAR B6): çökme/ANR yok; `CrashLog` boş ya da anlamlı.

## 16. Dosya seçici ana sayfası ve devam notu (2026-11-02)
- [ ] **Seçici yenisi (A11, 2026-11-03):** "Diğer dosyalar" gibi tür belirtmeyen istekte ana sayfa: üstte kategori
      kutuları, altında hızlı klasörler, sonra ince depolama satırı (ad · "x GB boş" · ince çizgi; dokununca kök),
      EN ALTTA son açılanlar. Klasör/kategori/arama/eşleşme listelerinde süzgeç satırı (WhatsApp/Kamera gibi kaynak,
      büyük dosyalar, açılmayanlar, tür hapı, ⋯ tarih/boyut); klasörler süzgeçte kaybolmuyor; PDF isteyen
      uygulamada tür hapı YOK, uzantı çipleri var; görünüm değişince süzgeç sıfırlanıyor.
- [ ] **Dosya seçici (tür belirtmeyen istek, ör. "Diğer dosyalar"):** ana sayfa panonun aynısı — bellek
      kartı(ları), kullanıcının dizdiği kutu ızgarası (İndirilenler, Önemli, Fotoğraflar, Videolar,
      Belgeler, Müzik, Arşivler, APK; "diğer kaynaklar" açıksa Drive), hızlı klasörler. Kutuya
      dokununca seçicinin kendi kategori/klasör listesi açılıyor; çoklu seçim alt çubuğu çalışıyor.
      Belirli tür isteyen yerlerde (yalnız görsel vb.) ilk yüz yine eşleşme listesi.
- [ ] **Belge devam notu:** 5. sayfadan sonra kapatılmış PDF'i aç → üstte ince "N. sayfadan devam
      ediliyor · Baştan başla" hapı, birkaç sn sonra kendiliğinden çekiliyor; "Baştan başla" 1. sayfaya
      götürüyor; okuma kipinde (çubuklar çekik) sayfayı örtmüyor; koyu/kâğıt temasında okunur.
- [ ] **Yakındakiler — aynı anda iki dosya alma (2026-11-02):** iki ayrı telefondan (ya da bir telefondan
      iki büyük dosya, 8 MB üstü) aynı anda gönder → "Alınıyor · 2 dosya" kartı en üstte; her dosya kendi
      satırında (simge, tek satır ad, alınan/toplam · %, kendi çubuğu); adlar birbirinin üstüne binmiyor;
      biten dosyanın satırı kalkıyor, geçmişe düşüyor. 4+ küçük dosya tek paket olarak gelir (tek satır).
- [ ] **Yakındakiler — gönderim kartı (2026-11-02):** 3+ dosya gönderirken ekran açık kalıyor; her dosya kendi
      satırında ilerliyor, bitenler ✓; Durdur kalanları göndermiyor; tablette/yatayda iki sütun.
- [ ] **A3.4 tazeleme sonrası (2026-11-02):** iş bildirimi + Durdur düğmesi, müzik bildirimi (ön plan servisi), video
      küçük resimleri, ilk açılışta depolama izni, PDF açıklama/form kaydetme, belge tarayıcı (cunning 1.4.0), OCR + çeviri.


## 17. VLC benzeri oynatıcı + görsel iyileştirme (2026-11-02, kişisel APK)
- [ ] **İyileştirme arka planda (2026-11-03):** Galeri → İyileştir → yapay zekâ: pencere açılmıyor, "arka planda"
      notu; galeride "İyileştiriliyor · %n" hapı; başka fotoğrafa geç / galeriden çık → alt şerit + bildirimde
      ilerleme, Durdur çalışıyor (yarım kopya kalmıyor). Bitince yeni kopya özgünün hemen sağında; "Önce / sonra"
      eylemi ve hap → karşılaştırma (kaydırmalı + üstteki düğmeyle YAN YANA); bildirime dokununca da aynı ekran;
      kopya Fotoğraflar'da görünüyor (kaybolmuyor).
- [ ] AC3/DTS sesli MKV: ses geliyor mu (otomatik mpv'ye geçiş); menüde "Standart motora dön" görünüyor mu
- [ ] AVI/WMV/FLV açılıyor mu; mpv'de PiP, mini çubuk, bildirim, kaldığı yerden devam çalışıyor mu
- [ ] Çok dilli MKV'de ses parçası menüsü (ExoPlayer) dil değiştiriyor mu
- [ ] Altyazı → İnternette ara: sonuç geliyor, indirilen altyazı filmin yanına kaydedilip açılıyor (secret varsa)
- [ ] Altyazı büyüt/küçült
- [ ] Galeri → İyileştir: otomatik/keskinleştir/gürültü kopyası `_iyi.jpg`; yapay zekâ ilk seferde model indiriyor, süre?
- [ ] Başında çöp olan / yarım inmiş JPEG "kurtarılabilen kısmı" notuyla açılıyor
- [ ] Fotoğraflar ızgarası: hızlı savurmada takılma/donma Google Foto'ya yakın mı (küçük resimler ilk açılışta üretilir, ikinci açılışta anında)

## 18. Aktar turu (2026-11-03)
- [ ] Galeride bir fotoğrafı "Yapay zekâ ile büyüt" + "Otomatik iyileştir" ile dene. Kapanırsa uygulamayı yeniden aç →
      Ayarlar > Hata kayıtları'nda "Process exit: …" satırını paylaş (neden + PSS MB).
- [ ] Yarım kalan iyileştirme: İşlemler'de karta / "Devam et"e dokun → iş yeniden başlar, sonunda önce/sonra açılır.
- [ ] Başka uygulamada bir dosyayı Paylaş → Dosya Okuyucu: Aktar açılır, dosya "Ne gönderilecek?"te hazır.
      Bir yazıyı paylaş → yazı çipi hazır. "Birlikte aç" hâlâ okuyucuda açmalı.
- [ ] Yazı: Aktar > Yazı (panodaki metin hazır gelir) → cihaza dokun → karşıda kopyalanabilir pencere.
- [ ] Güvenilen cihaz: gelen teklifte "Bu cihaza güven" işaretle → ikinci gönderim sorulmadan gelir; avatarda rozet;
      Windows "Dosya Aktar" ile de; "Güvenilen cihazlar"dan kaldırınca yine sorulur.
- [ ] Yeni Aktar düzeni telefonda ve yatayda taşmasız, okunur.

## 19. Önizleme / video / önemli dosyalar turu (2026-11-04, kişisel APK)
- [ ] Fotoğraflar ızgarası ve dosya listeleri: önizlemeler NET mi (yatay + dikey fotoğraf, 3/4/5 sütun)? İlk açılışta
      küçük resimler yeniden üretilir (`q2_`); kaydırma eski kadar akıcı mı (Mi Note 10 Lite)?
- [ ] Video küçük resimleri net mi? HEIC fotoğrafta önizleme çıkıyor mu?
- [ ] Video oynatırken geri tuşu / çıkış → video DURUR, mini çubuk ve bildirim kalkar. Müzik/sesli kitapta çıkınca SÜRER.
      Küçük pencere (PiP) hâlâ çalışıyor mu?
- [ ] Oynatıcıda sağdaki "Sağa çevir / Sola çevir": görüntü 90° döner, ekranı doldur kipinde de; başka videoya geçince sıfır.
- [ ] Galeride üstteki döndür düğmeleri; ⋮ → "Döndürülmüş hâlini kaydet" yanına yeni dosya yazar ve hemen yanında açılır.
- [ ] Slayt düzenleyici: alttaki şerit büyüdü mü, ana görünümde kaydırınca güncel slayt şeridin ortasına geliyor mu?
      Dosya listesinde PowerPoint/Word dosyasında ilk sayfa/slayt önizlemesi görünüyor mu?
- [ ] Bir dosyayı "Önemli Dosyalar'a kopyala" → kopya `ad_onemli.uzantı`; galeri/kategori/aramada yıldızlı.
      O kopyayı tekli sil → "Önemli dosya silinecek" sorulur; toplu seçimde (önemli + normal) "Önemlileri koru" seçeneği.
      Ayarlarda "silmeden önce sor" kapalıyken de sorulmalı. Temizlik önerileri önemlileri silmemeli.

## Faz 34 — Pano cilası
- [ ] 360×800 dp ve 2× yazı ölçeğinde 4 sıra kutu + araç satırı alt panelin üstünde, kayma yok.
- [ ] Ayarlar > Görünüm'de "Alt çubuk kısayolları" satırı yok; Ana ekranı düzenle açılıyor.

## Faz 35 / adım 0 — Belge tarayıcı v2 (ML Kit GmsDocumentScanner)
- [ ] Tara → ML Kit arayüzü açılır (canlı kenar, otomatik çekim, leke silme); kaydet → PDF üretilir.
- [ ] Çok sayfa (≥5) + galeriden içe aktar çalışır; vazgeçince hata/çökme yok.
- [ ] Play Hizmetleri'siz / eski cihazda: galeriden içe aktar yedek akışı açılır (hata iletisi yok).
- [ ] Soğuk açılışta tarayıcı yüklenmez (ilk dokunuşta kurulur); APK boyutu bütçesi CI'da yeşil.

## Faz 35 — Pro belge tarayıcı (madde 1–9)
- [ ] 10 gerçek belge: kâğıt, fiş, kimlik (ön+arka), kitap çift sayfa, beyaz tahta, kartvizit, fotoğraf.
- [ ] Kimlik kipi: iki yüz tek A4'te, kartlar okunur boyda; "Kasaya taşı" şeridi → kasaya girer, aslı silinir.
- [ ] Kitap kipi: çift sayfa cilt çizgisinden doğru bölünür (sağ/sol sırası doğru).
- [ ] Fiş kipi: PDF sayfası fiş oranında (A4'e küçülmüyor); "Gider ekle" → Giderler.csv'de tarih/tutar doğru.
- [ ] Kartvizit: .vcf Kişiler'e içe aktarılır (ad, telefon, e-posta).
- [ ] Izgara: basılı tut-sürükle sırası, sayfa menüsü (döndür/filtre/kırp/sil), 30 sayfada akıcı (p99 ≤ 24 ms).
- [ ] Filtre levhası 6 önizleme (Canlı, Gölgesiz) 360 dp'de sığıyor.
- [ ] Dışa aktar: Word açılır/düzenlenir; Excel tablolu fişte sütunlar doğru; TXT Türkçe karakter; PDF Küçük/Orta/Yüksek boyut tahmini gerçeğe yakın.
- [ ] Kalite şeridi: bulanık çekimde "yeniden çek", loş ortamda "fener", eğik sayfada "düzleştir" çıkıyor; net sayfada çıkmıyor.
- [ ] Bitti ölçütü: 20 sayfa < 15 sn işlenir (orta cihaz); OCR'lı PDF aranabilir.

## Faz 39 — PDF pro araçları (madde 1–12)
- [ ] 💻 Dijital imza: öz-imzalı imzalı PDF Adobe Reader'da "belge değiştirilmedi" (kimlik bilinmiyor) ve Chrome'da imza paneli; .pfx (e-imza) ile imza geçerli, parola yanlışsa anlaşılır hata.
- [ ] Karartma: "Gizli" araması + elle kutu → kaydet → başka okuyucuda metin seçilemiyor/kopyalanamıyor, görselde siyah; kutu dışı metin aranabilir.
- [ ] Tablo → Excel: fatura/ekstre PDF'inde sütunlar doğru, sayılar sayı; Word'e aktarım satır/girinti/punto korunmuş açılıyor; PDF/A (veraPDF) iki kipte de geçer.
- [ ] Karşılaştırma: iki sözleşme sürümü — metin farkı (kırmızı/yeşil) ve görsel fark kırmızı; 50 sayfada takılma yok.
- [ ] İzinler: yazdırma kapalı PDF Adobe'da yazdırılamıyor; yer imleri Adobe/Chrome'da görünüyor; damga/filigran Türkçe harfli.
- [ ] Okuma: kitap görünümü (kapak sağda, çiftler yan yana), kaydırma kilidinde yatay kayma/yakınlaştırma yok, sepya tonu, vurgu kitapçığı .md paylaşılıyor; arama sonuç listesi + taranmış PDF OCR araması.
- [ ] Agresif sıkıştırma: 100 sayfa taranmış PDF küçülüyor, metin (açıksa) aranabilir; düşük RAM cihazda çökme yok.
- [ ] Sayfa: sürükleyerek sırala 200 sayfada akıcı; boş sayfa algılama taranmış arka yüzleri buluyor; kırp/A4'e sığdır.
- [ ] Formlar: profille doldur boş alanlara doğru değer; yeni metin/onay/imza alanı başka okuyucuda doldurulabiliyor.
- [ ] Dönüştürme: görsellerden PDF (A4/özgün), toplu PDF→JPEG klasörü, web sayfası → PDF, docx/xlsx/pptx → PDF.
- [ ] İmza yönetimi: imza/paraf çiz-sil, her sayfaya paraf + tarih 100 sayfada.
- [ ] Perf: `docs/perf/2026-11-05-faz39.md` tablosu doldurulur (gerileme > %10 ya da p99 > 24 ms → `pdf_pro_v1` kapatılır).

## Faz 36 — Excel pro (madde 1–12)
- [ ] Özet tablo: 10 bin satırlık satış dosyasında bölge × ürün toplamı, süzgeç; kaynak değişince "Özeti yenile" doğru; 100 bin satırda donma yok.
- [ ] Koşullu biçim: renk ölçeği / veri çubuğu / simge kümesi / formül kuralı kaydet → Excel ve Google E-Tablolar'da aynı görünüyor; "Kuralları yönet" dosyadaki kuralı siliyor.
- [ ] Mini grafik: çizgi/sütun/kazanç-kayıp Excel'de görünüyor; kaydırma akıcı.
- [ ] Dinamik dizi: `=FİLTRE(...)`, `=SIRALA(...)`, `=BENZERSİZ(...)`, `=SIRALI(5)` taşıyor; engel varsa #YAYILMA!; LET ve formül "?" açıklaması.
- [ ] Tablo: `Tablo1[Tutar]`, `[@Tutar]` formülleri; tablo stili Excel'de Tablo Tasarımı'nda.
- [ ] Parolalı xlsx: Excel'de parolayla korunan dosya açılıyor; uygulamada parola konan dosya Excel'de parola istiyor; yanlış parola uyarısı.
- [ ] Yazdırma → PDF: yatay/sığdır/başlık yinele; yazdırma alanı ayarlıysa yalnız o alan; Excel'de yazdırma alanı görünüyor.
- [ ] Görünüm: sade şerit, kaydırınca başlık gölgesi, yoğunluk (kompakt/rahat) yeniden açılışta kalıyor.
- [ ] Veri: CSV/TSV/ODS içe aktarma (Türkçe ANSI dosya), ara toplam, satır gruplama + aç/kapa, not yanıtı, köprü (web + sayfa bağı) Excel'de çalışıyor.
- [ ] Biçim boyacısı tek dokunuşta biçimi taşıyor; renk seçicide dosyanın tema renkleri.
- [ ] Formüller: öncül/ardıl okları doğru hücreye; döngüsel formül yazınca uyarı; Hedef ara (ör. kredi taksiti) doğru sonuç.
- [ ] Grafik: kombinasyon + ikincil eksen + eğilim çizgisi Excel'de aynı; stil değişiyor; PNG/PDF paylaşımı.
- [ ] Koruma: parolalı sayfa koruması Excel'de aynı parolayla kalkıyor; düzenlenebilir aralık dışı hücre uygulamada kilitli; Excel'de korunmuş dosyanın korumasını parolayla kaldırma.
- [ ] Perf: `docs/perf/2026-11-05-faz36.md` tablosu doldurulur (gerileme > %10 ya da p99 > 24 ms → `excel_pro_v1` kapatılır).

## Faz 37 — Word pro (madde 1–11)
- [ ] Stil: başlığı kalın/ortala yap → Giriş > "Stili güncelle" → aynı stildeki bütün başlıklar değişiyor; Word'de stil tanımı güncel. Belge teması (Klasik/Modern…) yazı tiplerini ve başlık rengini değiştiriyor.
- [ ] Sayfa düzeni levhası: cm kenar boşluğu, yatay, A5, 2 sütun, cilt payı, farklı ilk sayfa → Word'de aynı; "Baskı önizleme" sistem yazdırma ekranını açıyor, Türkçe harfler doğru, sayfa sonları yerinde.
- [ ] Denklem: `\frac{-b \pm \sqrt{b^2-4ac}}{2a}` ekle → Word'de düzgün denklem; Word'de yazılmış denklemi aç → düzenle kutusunda LaTeX geliyor.
- [ ] Tablo: sağa/aşağı birleştir, böl, kenarlık hazırları, sığdır (içerik/pencere/sabit), sırala (Türkçe ç/ğ/ı/ö/ş/ü ve 1.234,5 sayıları doğru).
- [ ] Yeni belge > Word: şablon galerisi (CV, mektup, rapor, fatura, tutanak) Word ve LibreOffice'te onarımsız açılıyor.
- [ ] Karşılaştır: eski sürümü seç → izlenen değişiklikler; gözden geçirme çubuğu ↑↓, tek tek kabul/ret; yorumda "Yorumlar" açılıyor. Belge ekle imleçten sonra.
- [ ] Belge parolası: parola koy → kaydet → Word parola istiyor; Word'de parolalanmış docx uygulamada parolayla açılıyor (sayfa görünümünden Mobil editöre yönleniyor).
- [ ] Sesle yaz: Google tanıyıcı açılıyor (Türkçe), metin imlece; tanıyıcı yoksa uyarı.
- [ ] AI ile yaz: 6 görev, önizleme, Değiştir / Altına ekle, Vazgeç isteği iptal ediyor. AI yazım denetimi: öneri başına Uygula/Atla, Tümünü uygula, Durdur.
- [ ] Dışa aktar: PDF, yazı tipi gömülü docx (başka telefonda Word'de aynı satır kırılımı), ODT/RTF/MD/TXT LibreOffice/Word'de açılıyor.
- [ ] Gezinti ağacı katlanıyor, imleçteki başlık vurgulu; küçük resimler geldikçe doluyor, dokununca o sayfaya; sayaç okuma süresi.
- [ ] Metin kutusu, şekil, resim sarma (kare/üst-alt/arkada/önde), kapak, bölüm sonu, alan (tarih/sayfa), çapraz başvuru, kaynakça Word'de doğru.
- [ ] Okuma kipi: gündüz/sepya/gece, yazı boyu kalıcı; 300 sayfada akıcı kaydırma.
- [ ] Perf: `word_pro_v1=false` → eski arayüz; boşta 0 kare; 300 sayfa docx açılış/kaydırma/kayıt A/B (`docs/perf/2026-11-05-faz37.md`).

## Faz 38 — Slayt pro (madde 1–9)
- [ ] Araçlar → Ana slayt ve tema: tema rengi/yazı tipi değişince bütün slaytlar uyuyor; yerleşimde yer tutucu sürükle/boyutlandır/ekle/sil, yerleşim kopyala/adlandır → PowerPoint'te onarımsız açılıyor, "Asıl Slayt Görünümü"nde aynı.
- [ ] Şablon galerisi (8 tema) uygulanıyor, geri al çalışıyor; PDF/metin → "Slayt üret" (pptx) önerili galeriyi açıyor, önerilen içerikle uyumlu.
- [ ] Grafik ekle (sütun/çubuk/çizgi/pasta), veri düzenle; tablodan grafik; PowerPoint'te "Verileri Düzenle" gömülü kitabı açıyor. SmartArt'lı pptx → "SmartArt'ı şekle çevir" → metinli şekil grubu.
- [ ] Ses/video ekle (mp4, mp3, m4a): sunumda dokununca oynuyor (video şeklin yerinde, ses alt çubukta), slayt değişince duruyor; PowerPoint'te oynuyor.
- [ ] Sunumda araç çubuğu: lazer, kalem (renkler, sil), zamanlayıcı (dokun dur/başla, uzun bas sıfırla); kalem kipinde kaydırma slayt değiştirmiyor; klavye/Bluetooth sunum kumandası (PageUp/PageDown, oklar) çalışıyor.
- [ ] Sunucu görünümü: süre, sonraki slayt, notlar, önceki/sonraki; 60 fps geçiş (`FrameTiming`).
- [ ] Dışa aktar: bu slayt PNG, tüm slaytlar PNG zip, MP4 video (slayt başı süre; anlatımlı destede kayıtlı süreler) — video galeride oynuyor.
- [ ] Katmanlar: sürükle → z sırası, göz → gizle (sunumda/PowerPoint'te gizli), uzun bas → ad; çoklu seçimle hizala (6) ve dağıt (≥3). Animasyon sırası: sürükle, sil, ekle (Belir/Soldur/Sil/Yakınlaştır) → sunumda tıklama sırası doğru, PowerPoint'te "Animasyon Bölmesi" aynı.
- [ ] Bölümler: ekle/adlandır/yukarı-aşağı taşı/sil; sıralayıcıda § etiketi; slayt silince/taşıyınca PowerPoint'te bölümler bozulmuyor. Özel gösteri: oluştur, oynat (gizli slayt da), PowerPoint'te "Özel Slayt Gösterisi"nde var.
- [ ] Şekil kitaplığı (6 kategori), eylem düğmesi (sunumda ileri/geri), bağlayıcı (düz/dirsekli; PowerPoint'te şekil taşınınca çizgi izliyor), gradyan/gölge/yansıma/parıltı, kırp + şekle kırp, tablo biçimi (6), köprü (web/slayt/ileri/bitir), canlı sayaç (sunumda geri sayıyor, dokun dur).
- [ ] Arka planı kaldır: ilk kullanımda "model iniyor", sonra kişi/nesne saydam PNG olarak yerinde.
- [ ] Kumanda: ses tuşları (aşağı ileri, yukarı geri; kapalıyken ses ayarı normal); yerel ağ: gösterilen adres aynı Wi-Fi'deki tarayıcıda açılıyor, ileri/geri çalışıyor, sunum kapanınca adres yanıt vermiyor.
- [ ] Anlatım kaydı: mikrofon izni ilk kayıtta; her slayt ayrı ses; kaydet → sunum kendi ilerliyor ve ses çalıyor; PowerPoint'te "Kayıtlı zamanlamaları kullan" aynı.
- [ ] İkinci ekran: HDMI/USB-C ya da Cast (ekran yansıtma "ikinci ekran" kipi) → slayt TV'de, telefonda sunucu görünümü; kablo çekilince sorunsuz.
- [ ] Perf: `slides_pro_v1=false` → eski arayüz aynen; boşta 0 kare; 300 slayt açılış/kaydırma/kayıt A/B (`docs/perf/2026-11-05-faz38.md`); APK boyutu (+ML Kit konu bölütleme istemcisi) CI bütçesinde.

## Faz 40 — Ortak görünüm ve deneyim (madde 1–10)
- [ ] Dört editörde (Word sayfa/mobil, Excel, Slayt) üst çubuk aynı sıra: 💾 · ↶ · ↷ · [ara/anahat/düzen] · ⋮; ⋮ → "Paylaş / Dışa aktar" aynı sayfayı açıyor.
- [ ] Excel'de aralık seç → alt şeridin başında Kopyala/Kes/Yapıştır grubu; tek hücreye dönünce kayboluyor.
- [ ] Sayfa geçişleri akıcı (220 ms giriş / 170 ms geri); Arapçada yeni sayfa soldan giriyor; "animasyonları kaldır" açıkken anında.
- [ ] Boş klasör / arama sonucu yok / çöp boş ekranlarında çizim; koyu, AMOLED ve kâğıt temada okunur.
- [ ] TalkBack: üst çubuk düğmeleri, ⋮, bağlam grubu ("Seçim"), Word'deki yorum simgesi okunuyor; 2× yazıda editör çubukları ve ayarlar taşmıyor.
- [ ] Temiz kurulum: rehber 3 sayfa (okuyucu · düzenleyici · tara); "Örnek belgeleri ekle" → Belgeler/Dosya Okuyucu/Örnekler'de 4 dosya, her biri kendi editöründe açılıyor.
- [ ] Ayarlar: arama, "Önerilenler" çipleri (AI anahtarı / otomatik kaydet / kilit / yazı boyutu) alt levhada ayarı açıyor.
- [ ] Editörde değişiklik yap → ana ekrana dön (arka plan) → uygulamayı görev yöneticisinden kapat → yeniden aç: değişiklik kayıtlı (otomatik kaydet açık) ya da taslak şeridi çıkıyor.
- [ ] Paylaş / Dışa aktar: Word mobil (PDF, DOCX, ODT, RTF, MD, TXT), Excel (PDF, CSV), Slayt (PDF, PNG, MP4); Gönder → paylaş, indir, yakındaki cihaza (kayıtlı hâl gidiyor).
- [ ] Tema ön ayarı (Açık/Koyu/AMOLED/Kâğıt) ve 7 vurgu rengi her ailede okunur; yazı ölçeği "2×" kademesi.
- [ ] Arapça arayüzde Faz 40 metinleri Arapça; bozuk dosya açınca tek tip hata yüzü (Ayrıntıyı kopyala); açılışta iskelet, hafif profilde nabızsız.
- [ ] Pano: üst çubukta AI düğmesi YOK; alt panelin sağında varsayılan "AI" (Yer aç yerine; uzun bas → değiştirilebilir).
- [ ] Perf: pano boşta 0 kare, büyük klasör kaydırma ve editör açılışı Faz 39 tablosuna göre gerilemiyor (`docs/perf/2026-11-05-faz40.md`).

## Faz 41 — Dosya yöneticisi ve bulut (madde 1–8)
- [ ] Gezgin ⋮ → Çift bölme: iki klasör, dokunulan bölme etkin; seç → "Öbür tarafa kopyala/taşı"; telefonda dikey, tablet/yatayda yan yana; Değiştir düğmesi.
- [ ] SD kart (Android 11+): SD'ye kopyala → "SD karta yazmak için izin gerekli · İzin ver" → kart kökünü seç → kopyalama SAF ile tamamlanıyor; SD birleşimi ekranında "salt okunur" uyarısının altındaki izin düğmesi.
- [ ] Toplu yeniden adlandır: {AD} (Türkçe İ/I), {ad_kucuk}, {klasor}; "Kalıbı kaydet" → çip olarak kalıyor, ✕ ile siliniyor.
- [ ] Drive: ⋮ → Çevrimdışı kullan (bulut-tamam simgesi), uçak kipinde açılıyor; önbellek dolunca silinmiyor. Kopyayı telefonda düzenle → yeniden aç: "Telefondaki kopya değişti" → Drive'a yükle; iki taraf değişince üç seçenek (telefondakini yükle / ikisini tut → "Ad (telefon).ext" / Drive'dakini al).
- [ ] Arama → "içinde ara": ilk aramada canlı tarama, sonra dizin; Word/Excel/PDF metni ve (ayar açıksa) görsel yazısı bulunuyor; pil tasarrufu açıkken dizinleme duruyor. Kayıtlı arama: 🔖 → ad → boş aramada çip.
- [ ] Yakındakiler QR/bağlantı: 15 dk / 1 saat / tek indirme; süre dolunca tarayıcıda 410, ekranda "süresi doldu · yenile".
- [ ] Yer aç: eski ekran görüntüleri, bir yıldır açılmamış büyük dosyalar, boş klasörler önerileri; boş klasörler varsayılan seçili, diğerleri değil.
- [ ] Etiket sayfasında etikete uzun bas → renk; klasör ⋮ → Klasör rengi (listede klasör gövdesi o renkte; taşıyınca renk kalıyor); ⋮ → Favorileri sırala (sürükle).
- [ ] Sıkıştır → Bölümlere ayır (25 MB) → `ad.zip.001…`; 7-Zip/WinRAR PC'de açıyor, uygulamada ilk cilde dokununca açılıyor.
- [ ] SFTP'den büyük dosya indirirken Wi-Fi'yi kes → yeniden indir: kaldığı yerden sürüyor (`.part`).
- [ ] Perf: 50 bin dosyalı telefonda ad araması < 1 sn; kopyala/taşı sonrası dizin "bayat" olmuyor (tam yeniden kurulum yok); pano boşta 0 kare, gezgin kaydırma Faz 40 tablosuna göre gerilemiyor (`docs/perf/2026-11-05-faz41.md`).

## Faz 42 — Kalite, performans, yayın (madde 1–8)
- [ ] Ölçüm verisi: `python3 tool/make_test_tree.py olcum --buyuk` → `adb push olcum/. /sdcard/Android/data/com.dosyaokuyucu.dosya_okuyucu/files/olcum/` (iş bitince SİL).
- [ ] `bash tool/perf_senaryo.sh 13T` ve düşük RAM cihazda → `docs/perf/<tarih>-senaryo.md`; tabloyu `docs/perf/2026-11-06-faz42.md`ye taşı (p99 > 24 ms ya da > %10 gerileme → kırmızı).
- [ ] `bash tool/r8_ab.sh`: `.r8test` yayın kipinde OCR, belge tara, QR, slayt arka plan kaldır, Gemini işlevi, görsel büyütme, Word görüntüleyici → logcat'te ClassNotFound/NoSuchMethod YOK.
- [ ] `buyuk_100mb.xlsx` aç: kırmızı şerit "Büyük dosya (… MB): akış önizlemesi"; kaydırma akıcı, uygulama kapanmıyor (Hata kayıtları'nda `exit · LOW_MEMORY` yok); kaydet → "kaydedilemez" uyarısı, özgün dosya değişmedi.
- [ ] `buyuk_100mb.pdf` görüntüleyicide açılıyor/kayıyor; Ayarlar › Depolama ve hız › Başarım = Hafif iken PDF araçları "çok büyük (sınır 64 MB)" açıklaması gösteriyor, Tam'da açılıyor.
- [ ] Ayarlar › Hakkında › Hata kayıtları › 🐞 Sorunu bildir: önizlemede dosya adı/yol/uzun sayı maskeli; "Kare ölçümünü topla" aç → bir gün kullan → özet `kare: n=… p90≤… p99≤…`; Paylaş yalnız dokununca.
- [ ] Mağaza: `fastlane/metadata/android/tr-TR/images/featureGraphic.png` Play önizlemesinde kırpılmadan görünüyor; ekran görüntüleri seçimi (`docs/SURUM_ADAYI.md` §3).
- [ ] Sürüm adayı turu: `docs/SURUM_ADAYI.md` adım adım (B6).

## Yükseltme duman turu (Faz 43–50, her faz sonunda ~10 dk — KALICI, maddeler silinmez)
> `docs/YUKSELTME_PLANI.md` §0.7: her faz birleşmeden önce bu tur koşulur, sonuç fazın
> `docs/perf/2026-11-<faz>.md` belgesine "duman turu" satırı olarak yazılır. Profil ya da
> nightly APK; çökme → `adb logcat -b crash` + `flutter symbolize` (tahminle düzeltme yok).
> GMS'siz cihazda (Huawei) Google hizmeti isteyen maddeler "GMS'li cihazda" diye geçilir.
1. Soğuk açılış: ilk kare geliyor, `adb logcat -s flutter | grep KARE` ilk 6 sn'de 100 ms üstü kare yok.
2. Pano: kartlar dolu, 10 sn boşta kare üretmiyor; süzgeç şeridi açılıyor.
3. Gezgin: `/sdcard` → derin klasör, kaydırma akıcı; kopyala/taşı/sil (çöpe) + geri al.
4. Paylaş ile gelen dosya (başka uygulamadan "Paylaş → Dosya Okuyucu") doğru görüntüleyicide açılıyor.
5. Dosya seçici (PickerActivity): başka uygulamanın "dosya ekle"sinden seçim, dosya geri dönüyor.
6. PDF: aç → kaydır → yakınlaştır → vurgula/işaretle → kaydet; yeniden açınca işaret duruyor.
7. Word / Excel / Slayt: her biri aç → küçük düzenleme → kaydet → yeniden aç.
8. Belge tara + OCR (ML Kit — **GMS'li cihazda**; model indirme Play Hizmetleri ister).
9. Çeviri (ML Kit çeviri modeli — **GMS'li cihazda**).
10. Bildirim + ön plan iş: büyük kopyalama/indirme sürerken bildirim ilerliyor, bitince kapanıyor.
11. Video: Exo + mpv ile birer video, ilk kare < 1 sn, ses senkron.
12. Drive giriş (**GMS'li cihazda**), SFTP/FTP bağlan + listele, Yakındakiler keşfi.

**Koşu kaydı**
- 2026-11-07 · Faz 43 · MatePad DBY-W09 (GMS'siz): 1–3, 6–7 açılış ✅ · 4 ⚠ Paylaş → Aktar ekranı + konum/yakın cihaz izni · 11 ❌ `VIEW video/*` panoya düşüyor · 8, 9, Drive GMS'li cihazda · kalanlar elle bekliyor → ayrıntı `docs/perf/2026-11-43-taban.md`.

## Faz 45–47 — Paket yükseltmeleri (2026-11-08)
Otomatik kısım (ölçüm + duman) `docs/perf/2026-11-45.md`'de. Elle bakılacaklar:
1. **Başka uygulamada aç** (open_filex yerine kendi `ACTION_VIEW` köprüsü, READ_MEDIA_* yok): video, ses, apk ve
   bilinmeyen biçimde bir dosya → sistem seçicisi/uygulaması açılıyor, dosya okunuyor; uygulama yoksa "uygulama yok" iletisi.
2. Dosya seçici (file_picker 13): sistem seçicisinden tek + çoklu seçim; büyük (>500 MB) dosyada bellek şişmiyor.
3. Paylaş (share_plus 13): bir PDF ve birkaç görseli paylaş; metin paylaş (AI özet).
4. Bildirim (flutter_local_notifications 23): uzun kopyalama/indirme ilerlemesi + iptal.
5. İzin kapısı (permission_handler 13): bildirim/kamera iznini reddet → düğme "Ayarları aç"a dönüyor (bir dokunuş).
6. **GMS'li cihazda:** Drive girişi (google_sign_in 7 — yalnız yetkilendirme yolu, kurulum değişmedi), sessiz giriş
   (uygulamayı kapat-aç), çıkış (izin iptali); ML Kit OCR + çeviri model indirme.
7. Gerçek SFTP/FTP sunucusu (NAS): bağlan, listele, büyük dosya aktar (yerelde asyncssh/pyftpdlib ile SFTP 14 MB/sn,
   FTP 24 MB/sn — main ile aynı). Çok eski NAS (yalnız ssh-rsa/CBC) bağlanamayabilir (dartssh2 4).
8. Uygulamalar ekranı (installed_apps 2.2.1, `detectPlatformType:false`): liste açılış süresi.

**Koşu kaydı**
- 2026-11-08 · Faz 45–47 · MatePad DBY-W09 (GMS'siz): ölçüm kapısı ✅ (`docs/perf/2026-11-45.md`), senaryolar 3/3 çökmesiz, SFTP/FTP yerel sunucuyla ✅ · 1–5, 7–8 elle bekliyor · 6 GMS'li cihazda.

## Faz 48 — pdfrx 2.12 + okuma yardımcıları (2026-11-08)
Otomatik kısım (A/B ölçüm) `docs/perf/2026-11-48-pdfrx.md`'de. Elle bakılacaklar:
1. **"40 Hadis" PDF'i** (kullanıcının asıl dosyası): açılış ve kaydırma akıcı (2.4.8'deki ~5 FPS yok).
2. **Erişilebilirlik hizmeti AÇIK** (GMS'li/Xiaomi; parola yöneticisi ya da TalkBack) → aynı PDF'te kaydırma akıcı (P6).
3. **İki parmakla yakınlaştır:** yazı keskinleşiyor, jest sırasında titreme/atlama yok (1.3.5 basamaklı ölçek kalktı, 2.12'nin kendi kısmi çizimi).
4. Uzun basış seçim, arama + sonuç listesi, işaretleme, form, imza, taranmış sayfa OCR metni, PDF düzenleyici açılışı.
5. **Aa → Ekran açık kalsın:** okurken ekran sönmüyor; kapatınca normal zaman aşımı.
6. **Aa → Ses tuşlarıyla sayfa çevir:** kısma sonraki, açma önceki sayfa; kapalıyken ses düğmesi sesi değiştiriyor.
7. **Aa → Otomatik kaydırma:** Yavaş/Orta/Hızlı; parmak ekrandayken duruyor, kalkınca sürüyor; belgenin sonunda kendiliğinden kapanıyor.

**Koşu kaydı**
- 2026-11-08 · Faz 48 · MatePad DBY-W09 (GMS'siz): ölçüm kapısı ✅ (`docs/perf/2026-11-48-pdfrx.md`), çökme 0 · 5–7 adb ile ✅ (`KEEP_SCREEN_ON`, ses tuşu 98→100→99, kaydırma 1→3. sayfa) · 1–4 elle bekliyor · 2 GMS'li/Xiaomi cihazda.

## Office geliştirme (2026-11-08, PR #67)
1. **Excel:** masaüstü Excel'de 2. sayfada C5 seçiliyken kaydedilen dosya bu sayfa ve hücrede açılıyor; gizli sayfa etkinse ilk görünür sayfa.
2. **Word:** çok sayfalı belgeyi 5. sayfada kapat → yeniden aç: 5. sayfadan açılıyor + "devam ediliyor · Baştan başla" notu; Baştan başla 1. sayfaya döner.
3. **Slayt:** aynı şekilde N. slayttan açılıyor + not; ayarlardaki okuma konumu kapalıyken hep baştan.
4. **Gösteri:** B / `.` siyah, W / `,` beyaz ekran; dokunma ya da herhangi bir tuş kapatır · araç çubuğu düğmeleri · sayaca dokun / G → "Tüm slaytlar" ızgarası, dokunulan slayta atlar; takılma yok.

**Koşu kaydı**
- 2026-11-08 · MatePad DBY-W09: ölçüm kapısı ✅ (`docs/perf/2026-11-08-office.md`), çökme 0 · 1–4 elle bekliyor.

## Galeri/tema geliştirme (2026-11-08, dal `faz-galeri`)
Ekran görüntüleri `docs/design/2026-11-galeri/` (örnek ağaç `/sdcard/Ornek`, kişisel ad yok). Elle bakılacaklar:
1. **Gece (OLED):** pano kutuları ve dosya listesi Adaçayı ile aynı yeni (squircle/dolu) simgelerle; eski düz glif yok. Sistem rengi ailesinde de aynı.
2. **Ses listesi:** Ses kategorisi / müzik klasöründe simgeye dokun → çalar, simge duraklat olur + ilerleme halkası; mini çubukla iki yönde senkron; satıra dokunmak yine tam oynatıcıyı açar. 50+ sesli listede kaydırma akıcı.
3. **AI ikinci ad (anahtar gerekli):** 3 nokta → "AI ile ikinci ad ver" → bir süre sonra satırın alt yazısında renkli ikinci ad; dosya adı DEĞİŞMEDİ; üst aramada ikinci addaki bir sözcükle dosya bulunuyor. Anahtarsızken "AI'yı etkinleştir" penceresi.
4. **Klasik / Defter temaları:** tema galerisinde önizleme manila klasör; gezginde sarı düz klasör + beyaz sayfa ve türün renkli şeridi (PDF kırmızı, XLSX yeşil…); açık ve koyu mod okunur.
5. **Galeri → Albümler** (çubuktaki klasör simgesi): "Bu gün geçmişte" (varsa) + kapaklı klasör ızgarası; albüm seçince başlık albüm adı, ✕ ve geri tuşu süzgeci kaldırır; pinch/hızlı kaydırma aynı.
6. **Ayarlar (tablet sol panel):** tema modu seçici "Sistem · Açık · Koyu", yazı bölünmüyor; pano hızlı klasör çiplerinde klasör simgesi temanın klasör renginde.

**Koşu kaydı**
- 2026-11-08 · MatePad DBY-W09: 1, 2, 4, 5, 6 adb + ekran görüntüsüyle ✅ (`.r8test` profil APK) · 3 anahtarsız cihazda yalnız menü girdisi görüldü (AI isteği elle bekliyor).

## Faz 49 — Play yorum çalışması aşama 2–3 + temizlik (2026-11-08, dal `faz-49`)
1. **İlk açılış (temiz kurulum):** okuyucu sayfasında iki büyük seçenek. "Bir dosya aç" → sistem seçicisi, izin penceresi YOK, seçilen dosya açılır ve rehber kapanır. "Telefonumdaki tüm dosyaları yönet" → tek sistem penceresi; reddedince "Sorun değil — tek tek aç" notu, başka izin sorulmaz.
2. **Pano izin kartı (izin yokken):** başlık "Tüm dosyalarını burada görelim mi?", üç düğme: Şimdilik tek dosya aç · Klasör ekle · İzin ver. **Klasör ekle** → Download seç → panoda kart olarak çıkar, dokununca gezgin açılır; uygulamayı kapat-aç → kart duruyor.
3. **Ayarlar › Gizlilik ve izinler:** "Ağ ve yapay zekâ" (Çevrimdışı kip, AI'ya göndermeden önce sor) + İzinler (tüm dosyalar, bildirim, kamera, konum, üstte gösterme, eklenen klasörler, kullanım): her satırda neden + durum; verilmişse **Geri al** sistem ayarını açar, dönünce satır tazelenir; eklenen klasörde Geri al kartı panodan kaldırır.
4. **Çevrimdışı kip AÇIK:** AI özeti/sohbet → "Çevrimdışı kip açık — internete bağlanılmadı…" (bekleme/yeniden deneme yok); Drive ve altyazı aynı mesaj; yerel ağ (NAS/SFTP, yakındaki cihaz) çalışıyor. Kapatınca AI yine çalışıyor.
5. **AI onayı (anahtar gerekli):** ilk AI işinde "Dosya Google'a gönderilsin mi?" — Vazgeç → "Yapay zekâya gönderilmedi"; Gönder → aynı oturumda bir daha sorulmaz; "Bir daha sorma" → kalıcı, ayardaki anahtar kapalı görünür, yeniden açınca yine sorar.
6. **Neler yeni:** 1.1'den 1.2'ye güncellemede bir kez levha (6 madde); ikinci açılışta yok; temiz kurulumda hiç yok.
7. **Okuyucu derlemesi** (Actions › "Okuyucu derlemesi (izinsiz)" artifact'i, `…okuyucu` kimliği, tam uygulamanın yanına kurulur): uygulama bilgisinde hassas izin yok; pano kartında "İzin ver" yok, Klasör ekle + Dosya aç çalışıyor; ilk açılışta tek seçenek.

**Koşu kaydı**

## PDF Pro Faz 51 — kanamayı durdurma (2026-11-08, dal `faz-51`)
Külliyat belgeleri: `test/fixtures/pdf_corpus/rl_paragraflar.pdf`, `wd_mektup_logo.pdf`, `ch_cok_sayfa.pdf` → `/sdcard/Download/PdfPro/`.
1. **PS5 — uzun seçim:** metne uzun bas, tutamaçla 3 paragraf uzat → çubuk seçimi örtmüyor (örtüyorsa belge kayar ya da çubuk üste geçer); önizlemedeki ⌄'ye dokun → seçimin tamamı + "N karakter · M sözcük", alan kendi içinde kayar.
2. **PS1 — Düzenle seçimi taşır:** seçim çubuğunda **Düzenle** → editör AYNI sayfada, seçilen paragraf doğrudan düzenleme kipinde, imleç seçimin başında (sayfa baştan çerçevelenip yeniden seçtirilmiyor).
3. **PS4 — klavye:** düzenleme alanı açıkken klavye çıkınca sayfa küçülmüyor/uzaklaşmıyor; imlecin satırı klavye + çubuğun üstünde görünür (yatay tablette de). OCR satırında da okunur boya yakınlaşma. Uygula'dan sonra yakınlık/konum aynı.
4. **PS3 — kaydet:** Yazı ekle → Kaydet → "Kopyasını kaydet" → görüntüleyici **kopyayı** açar; bildirimde **AÇ** (ve bildirimin gövdesi) editör kapanmış olsa da dosyayı açar; Geçmiş › Son açılanlar'ın başında kopya.
5. **PS2 — Word logolu mektup:** editörde doğal metne OCR kutusu YOK; ipucu "Bu sayfanın metni bu sürümde yerinde düzenlenemiyor…" + **OCR ile düzenle** (bilerek seçilince satırlar gelir). Düzenleme alanı belgenin ailesiyle (Calibri→Carlito, Arial→Arimo, Times→Tinos).

**Koşu kaydı**
- 2026-11-08 · MatePad DBY-W09 (yatay, `.r8test` profil APK, adb + uiautomator): 1 ✅ (tutamaçla uzatılan seçim çubuğun üstünde; tam metin + "528 karakter · 66 sözcük") · 2 ✅ (Düzenle → paragraf doğrudan düzenlemede, imleç seçimin başında) · 3 ✅ (görüntü küçülmüyor; klavye açılınca satır örtülmeyen şeritte) · 4 ✅ (kopya doğrudan açıldı, Son açılanlar'ın başında; "AÇ" dokunuşu zaman aşımına denk geldi → widget testiyle doğrulandı) · 5 ✅ (OCR kutusu yok, ipucu + OCR ile düzenle). Turda bulunan 4 sorun aynı dalda düzeltildi (klavye sonrası kaydırma, Düzenle meşgul yarışı + kutu/metin eşleşmesi, seçim çubuğu örtüsü ölçümü).

## Faz G1 — Android platform sertleştirme (2026-11-11, dal `faz-G1`)
1. **Widget dokunuşu:** ana ekran widget'larındaki Tara / Ara / Temizle düğmeleri ve "son dosyalar" satırı doğru ekranı/dosyayı açıyor (bağlantılar artık imzalı).
2. **Başlatıcı kısayolları:** uygulama simgesine uzun bas → Ara / Tara / İndirilenler / Son açılanlar çalışıyor.
3. **Sabitlenmiş dosya kısayolu:** (a) güncellemeden ÖNCE sabitlenmiş bir dosya kısayolu hâlâ açıyor; (b) yeni sabitlenen de açıyor.
4. **"Birlikte aç" / Paylaş:** başka uygulamadan PDF/resim "Dosyalarım ile aç" çalışıyor; tarayıcıda dosya bağlantısına dokununca seçenekte çıkıyor.
5. **Ekran görüntüsü engeli:** Kasa, PIN/parola pencereleri, uygulama kilidi, AI anahtarı alanı, uzak bağlantı ekranı açıkken ekran görüntüsü alınamıyor ("güvenlik nedeniyle alınamıyor"), son uygulamalar önizlemesi boş; ana gezginde alınabiliyor. Kasadan açılan dosya görüntüleyicide de engelli; kasa kapanınca bayrak kalkıyor.
6. **Yedek:** `adb shell bmgr`/ayarlardan yedek alıp geri yüklemede uygulama verisi gelmiyor (ayarlar için uygulamanın kendi "Ayar yedeği" kullanılır).

## Faz G2 — Sırlar: diskte, ağda, logda (2026-11-11, dal `faz-G2`)
1. **Uzak bağlantı göçü:** güncellemeden ÖNCE parolası kayıtlı bir SMB/FTP/SFTP/WebDAV bağlantısı güncellemeden sonra parola sormadan bağlanıyor; uygulamayı kapatıp açınca da.
2. **Yeni bağlantı:** parola kaydedilerek eklenen bağlantı yeniden açılışta bağlanıyor; "Parolayı kaydet" kapalıysa her bağlanışta soruyor. Bağlantılar ekranında "korumasız saklanıyor" uyarısı ÇIKMIYOR (çıkıyorsa Keystore sorunu — not et).
3. **Ağdan erişim (FTP sunucu):** elle parola kipinde önceden girilen parola güncellemeden sonra duruyor; rastgele kipte her açılışta yeni parola üretiliyor.
4. **AI:** sohbet, belge özeti ve Ayarlar'da "modelleri listele" çalışıyor (anahtar artık başlıkta gidiyor).
5. **Ayar yedeği:** dışa aktarılan JSON'da AI anahtarı ve parola yok; geri yüklemede kayıtlı bağlantılar (parolasız) geliyor.
6. **Hata kaydı:** Ayarlar › Hakkında › hata kaydında dosya yolu/anahtar görünmüyor, `package:` satırları okunuyor.

