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

## 1. Ölçümler (sayıyla doldur — FAZ_PLANI Faz 4 + DUZENLEME §7)

| Senaryo | Hedef (orta / düşük) | Güncel cihaz | Düşük cihaz |
|---|---|---|---|
| Soğuk açılış, ilk kare / etkileşim | ≤ 1,2 sn / ≤ 2 sn | 433–628 ms (2026-10-22, Xiaomi 13T) | |
| Açılışın ilk 0,5 sn'si: ilk kare raster, pano build | ölç (KALANLAR A8.2 sonrası) | 218–309 ms / 45–49 ms | |
| Boşta pano 60 sn: çizilen kare + zamanlayıcı | 0 | 0 ✔ | |
| 5.000 öğeli klasör kaydırma + sürükleyerek seçim, %99 kare | ≤ 24 ms | 8,5 ms ✔ | |
| Büyük klasör açılış karesi (3.000 foto) | — | 58 ms ✔ | |
| Galeri 2.000 fotoğraf kaydırma sonrası RSS | ≤ 350 MB (hafif ≤ 250) | | |
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
| Dolu çöp (≥ 3 bin öğe) açılış | < 1 sn | | |
| 100 bin+ dosyalı telefonda pano taraması (süre, bellek; `_TopN` yeterli mi) | ölç | | |
| Akıllı analiz: 1.500 WhatsApp görselinde OCR süresi | ölç | | |
| R8'li APK: açılış çökmesiz, APK boyutu | çökme yok | ✔ 60,6 MB (2026-10-22) | |

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
- [ ] **Liste görünümü:** klasör başına hatırlanan görünüm/sıralama; iki parmakla sütun sayısı;
      simge üstündeki uzantı yazısı ("XLSX") net; PDF'ler kapak sayfasıyla, kaydırma akıcı.
- [ ] **Hızlı kaydırıcı:** balon + tutamaç; Arapça'da SOL kenarda.
- [ ] **Uygulamalar ekranı:** boyuta göre sıralı, Ayarlar'daki sayılarla tutuyor; "Kullanım
      erişimi" yokken boyut yerine boşluk (sıfır değil), izin verince hemen geliyor; klasör
      düğmesi "Depolama ve önbellek"e iniyor (MIUI); Bellek Analizi Uygulamalar kartı toplamı.
- [ ] **Sohbet temizliği:** kovadan sil → geri dön → kova sayısı ve panodaki "N dosya · X MB"
      yenilemeden güncel.
- [ ] **Ana ekrana ekle:** Görüntüler → ⋮ → "Ana ekrana ekle" → kendi simgeli kısayol; uygulama
      kapalıyken de Görüntüler'i açıyor.
- [ ] **Dosya seçici 2. tur:** yeni kurulumda kategori/arama dolu; yazdıkça arama; sıralama çipi; çoklu seçimde Tümünü seç /
      Temizle + toplam boyut; bir seçimden sonra ana sayfada son klasör çipi.
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
- [ ] **Arşiv:** büyük ve solid RAR/7z çıkarma süresi + ilerleme (iptal KALANLAR A7.3 sonrası);
      parolalı ZIP üretme.
- [ ] **Belge tarama stüdyosu:** Google tarayıcı (Play Hizmetleri yoksa yedek tarayıcı), kenar +
      kırpma + filtre; resimli sayfa bozulmadan; Kırp (kenar ortası tutamaçları, büyüteç,
      "Kenarları bul"), Döndür, Filtre + "Tüm sayfalara", sıra sürükleme, Yeniden çek, Sil →
      "Geri al", "Kaydediliyor… → Kaydedildi"; "+" → "Fotoğraftan ekle"; "Yazıları da tanı" →
      PDF'te arama; PDF Araçları ⋮ "Sayfa tara ve ekle".
- [ ] **Uygulamanın kapladığı alan** listesinin son satırı ("Android uygulama ayarlarını aç")
      gezinme çubuğunun üstünde; öteki listeler de.

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
- [ ] **Gönderim ekrandan bağımsız:** QR ile büyük dosya indirilirken gönderen geri çıksın / ana ekrana dönsün / ekranı
      kilitlesin → indirme sonuna kadar sürüyor, "Dosya aktarılıyor" bildirimi + Durdur; bitince ~1 dk içinde sunucu ve
      hotspot kapanıyor; hiç indirme başlamadan çıkınca sunucu anında kapanıyor. Alıcı tarafta da ekrandan çıkınca alım sürüyor.
- [ ] **Uygulamasız alıcı (web):** tarayıcıda `http://<ip>:8080` + 6 harfli jeton (elle de
      yazılabiliyor) → küçük resimli liste, "Tümünü indir" ZIP, tek dosyada otomatik indirme,
      sayfa tarayıcı diline göre TR/EN. Hotspot yolunda alıcının tarayıcısı mobil veriye
      gidiyorsa sonucu yaz (KALANLAR B3.4).
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

- [ ] **Örnek set** (`test/fixtures/pdf/*`) açılıyor; parolalı (`1234`) soruyor.
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
- [ ] **Ret → "Üstüne yaz":** paragrafın KENDİ gömülü yazı tipiyle (harf alt kümede yoksa Carlito);
      eski metin aramada/kopyada da yok.
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

**Bütün editörlerde ortak (Faz 20 — Word, Excel, Slayt, Metin, PDF, Görsel):**
- [ ] **Düzenleme sonrası odak:** Word 5. sayfada Düzenle → aynı yerde açılıyor; paragraf değiştir, çık → o paragraf ortada +
      çerçeve. Slayt 7'de kutu düzenle, Bitti → aynı slayt + çerçeve. PDF düzenleyicide 3. sayfada kaydet → görüntüleyici 3. sayfada.
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
- [ ] **Kişisel derleme (yalnız `kisisel` APK — `releases/download/kisisel/dosya-okuyucu.apk`;
      nightly/"en son" değişmemiş olmalı; asistan `com.ses.asistan` kurulu):** asistandan
      "… dosyasını aç" (sorgu boşsa son açılan), "oku" (görüntüleyicinin kendi sesli okuması),
      "durdur" (duraklatır, kaldığı yer kalır), "özetle" (özet sayfası) çalışıyor; genel APK'da
      köprü yok.
- [ ] **48 saat iç test** (KALANLAR B6): çökme/ANR yok; `CrashLog` boş ya da anlamlı.
