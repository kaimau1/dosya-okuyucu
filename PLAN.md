# PLAN — tek kalan-iş listesi (2026-11-15 birleştirmesi · 2026-11-18 büyük paketler)

**Açık işin TEK kaynağı burası.** 2026-11-15'te KALANLAR, KONTROL_LISTEM, OTOMASYON Kuyruğu ve
8 faz planı (FAZ, DUZENLEME, GELISTIRME, YUKSELTME, PDF_PRO, GUVENLIK, FERRARI, SURUM) buraya
toplandı. Eski dosyalar **`docs/arsiv/planlar/`** altında (yalnız ayrıntı/karar kaynağı, yürütülmez).
Telefonda adım adım bakılacaklar: `docs/CIHAZ_TESTI.md`. Yürütme düzeni (zincir): `OTOMASYON.md`.

**Kurallar:** biten satır **SİLİNİR** (tik bırakılmaz) · karar / kök neden / tuzak → HAFIZA ·
cihazda bakılacak yeni şey → `docs/CIHAZ_TESTI.md` · kullanıcının yapacağı → §3 (ne · nasıl ·
doğruysa · yanlışsa) · yeni iş → **ilgili B/C paketine madde** (yeni paket yalnız hiçbirine uymuyorsa).

---

## 0) Hız anayasası (bağlayıcı — 2026-11-04, kullanıcı: "performans düzeltmelerini bozma")

Kazanımlar (docs/perf/2026-10-21.md): soğuk açılış ~430–630 ms, boşta 0 kare, 5.000 öğe kaydırma
p99 8 ms, görsel önbelleği 56/100/160 MB (`PerfBudget`), GPU tavanı 64 MB/300, `StartupQueue`
(2 sn sonra tek sıra), gizli sekme `TickerMode`, PDF metni açılışta çıkarılmaz, hafif profilde
120 Hz/otomatik tarama/nabız kapalı.

1. Yeni ağır iş ana iş parçacığında koşmaz (`compute`/izolat ya da Kotlin `Dispatchers.Default`; `perf_offload_test`).
2. Tembel yükle: açılışta (`main`, pano `initState`) hiçbir şey çalışmaz; gerekirse `StartupQueue`, ilk 2 sn'de asla.
3. Sayılar `PerfBudget`ten (`low/mid/high`); hafif profilde yeni animasyon/nabız/otomatik önizleme KAPALI başlar.
4. Görsel: `cacheWidth = boyut×dpr` (kova); tam çözünürlük yalnız yakınlaştırmada; önizleme ≤ ekran×dpr×2 (≤ 2480).
5. Büyük liste/ızgara: `const` + `RepaintBoundary` + sabit boy; dar `ValueListenableBuilder`, kökte `watch` YOK;
   hücrede `saveLayer`/`Opacity`/`BackdropFilter`/geniş `ShaderMask` YASAK.
6. Boşta 0 kare: görünmezken `AnimationController`/`Timer.periodic` durur; izleyici olaya bağlı, yoklama yok.
7. APK/bellek: yeni bağımlılık CI boyut + 16 KB denetiminden geçer; +1,5 MB üstü gerekçe (HAFIZA); modeller isteğe bağlı iner.
8. Perf kapısı: ilgili `test/perf/*` + tasarım/hareket bekçileri yeşil; `docs/perf/` önce/sonra A/B tablosu;
   **gerileme > %10 ya da kare p99 > 24 ms → birleşmez** (bayrakla kapalı gelir). Mandallar yalnız düşer.
9. Büyük yeni yetenek bayrak kapalı / `perf_mode=hafif`te eski yolu aynen çalıştırır; geri alma tek satır.

Ayrıntılı bekçiler ve "10 işlem" ölçüm seti: `docs/arsiv/planlar/FERRARI_PLANI.md` §0, §2.
**Ölçmeden "akıcı/hızlı" denmez.**

---

## 1) Kuyruk — BÜYÜK PAKETLER (2026-11-18 birleştirmesi)

**Neden büyük paket (kullanıcı 2026-11-18):** küçük satırlar her oturumda bağlamı baştan kurdurup
belirteç harcatıyordu. Artık **bir oturum = bir paket** (gerekirse 2–3 oturum, aynı dalda sürer).
Eski `P` numaraları paketlerin İÇİNDE durur (§3 kararları ve HAFIZA onlara atıf yapar); biten
madde paketten silinir, paket boşalınca satır silinir. **Kod paketleri (B)** bulutta ya da yerelde;
**cihaz paketleri (C)** telefon bağlıyken yerelde (`ab-olcum` skill'i, ÖLÇÜM KAPISI).

Durum: `bekliyor` · `sürüyor` · `cihaz bekliyor` · `kullanıcı kararı` · `takıldı: <neden>` ·
`bulutta: sürüyor …` (bulut zinciri sahiplendi — yerel tur atlar; `OTOMASYON.md` "Bulut zinciri").
Model: `fable` · `opus` · `sonnet`. Cihaz: `—` · `evet` · `A/B` · `tablet`. APK: `evet` · `hayır`.
Kaynak kısaltması: `arsiv/` = `docs/arsiv/planlar/`.

**SIRA:** B1 → (telefon boşaldıkça C1, C2) → B2 → B3 → B4 → B5 → B6 → B7 → C3 → B8.
Ferrari kuralı (§0): B3'teki hız işleri (P06, P12b, P29) bitmeden büyük yeni özellik **varsayılan
açık** birleşmez — B1/B2 bayrakla (Akıllı düzen kullanıcı açınca çalışır) birleşebilir.

| No | Paket | Model | Kaynak | Cihaz | APK | Durum |
|---|---|---|---|---|---|---|
| B1 | **AI Akıllı düzen 2.0 — çekirdek:** ayrıntılı sınıflandırma (§1.1), kullanıcı kategorileri (doğruluk kapısıyla), HER dosya türü (Office/metin/ses/video/arşiv), doğruluk ölçüm tezgâhı, Files API (büyük dosya) | opus (şema evresi fable) | §1.1; HAFIZA 2026-11-18 | A/B | evet | bekliyor — 1. sürüm main'de |
| B2 | **AI Akıllı düzen 2.0 — kullanım:** Ayıkla 2 (en iyi kare, benzer kare grupları), kontrol listeleri, düzeltmeden öğrenme, isteğe bağlı taşıma kuralları, hassas kategori kilidi, Decisions'ın kalan kullanımları (eski P33/P34) | opus | §1.2 | A/B | evet | bekliyor — B1'den sonra |
| B3 | **Hız (Ferrari) kod + ölçüm:** P12b Excel/liste A/B artıkları, P29 büyük başlık + kalıcı hata şeridi, P06 PDF kaydırma H2.1–H2.6 | opus (P06 plan evresi fable) | §1.3; arsiv/FERRARI_PLANI H2 | A/B | evet | bekliyor |
| B4 | **PDF Pro tamamlama:** P16 metin, P17 nesne/işaret, P18 form+imza, P19 OCR Pro, P20 sayfa stüdyosu, P21 parola/meta/optimize/PDF-A, P22 kalite %98 | opus (plan evresi fable) | §1.4; arsiv/PDF_PRO_PLANI 54–68 | A/B | evet | bekliyor — 2–3 oturum, tek dal |
| B5 | **Biçim + bakım + levha birliği:** P23 UDF (UYAP) okuyucu, P24 bağımlılık bakımı, P25 levha/pencere birliği (onay §3 K17) | opus | §1.5 | A/B | evet | bekliyor |
| B6 | **Tasarım tamamlama:** P31 ana ekran aileleri kalanları (D simge takımı, F metinleri, K19), P32 menü ortak düzeni kalanları | opus | §1.6; docs/design/ana_ekran/ | A/B | evet | bekliyor — K19 kararıyla |
| B7 | **Sürümler + yayın:** P30 Lite/Pro/Kişisel (S4–S9, K15/K16), P26 mağaza ekran görüntüleri | opus / sonnet | §1.7; arsiv/SURUM_PLANI | — | evet | kullanıcı kararı — K15 |
| B8 | **Son kapı:** P27 "10 işlem" son ölçüm + Samsung kıyası, erişilebilirlik, özellik dondurma kalkar | sonnet | arsiv/FERRARI_PLANI H12 | A/B | evet | bekliyor — en sonda, kullanıcıyla |
| C1 | **Cihaz: hazır dalların ölçümü:** P08 PDF Pro bellek (`faz-oto-P08-bellek`), P28 PDF kabuğu (`faz-oto-P28-pdf-kabuk`), P07 son sayfa + döndür (`faz-oto-P07-artik`) → A/B → yeşilse birleştir | opus | §1.8; DEVIR.md | A/B | evet | cihaz bekliyor |
| C2 | **Cihaz: perf A/B artıkları:** P13 liste/ızgara (klasor_5000 p99 23,5→38,9, B3.3c, soğuk açılış), P12 Excel 10k×20, P14 Word kapanış/menü (K21–K22), P04 boş/hata durumları (K6–K7) + 2026-11-18 AI/ana ekran işlerinin ölçümü | opus | §1.8; docs/perf/ | A/B | evet | cihaz bekliyor |
| C3 | **Cihaz: genel tur:** P11 `CIHAZ_TESTI.md` baştan sona (Faz 34–42, Güvenlik, 360×800 + 2× yazı, 2026-11-18 AI maddeleri) + §3 "Telefonda sen bak" (K20–K28); kırmızı → ilgili pakete madde | sonnet | CIHAZ_TESTI | evet | hayır | bekliyor — telefon boşken |

### 1.1) B1 ayrıntısı — Akıllı düzen 2.0 çekirdek

**Hedef:** telefondaki HER dosya (kapsam klasörlerinde) anlamlı bir ikinci ad + AI kategorisi alır;
kullanıcı kendi kategorisini ekler ve **eklemeden önce doğru çalıştığını görür**; doğruluk ölçülür.

1. **Ayrıntılı şema (fable ile tasarla, opus uygula)** — `smart_sort_taxonomy.dart`:
   - Her belge kategorisine alt tür: fiş (market · restoran · akaryakıt · e-ticaret · eczane),
     vergi/SGK (bordro · vergi levhası · hizmet dökümü · emeklilik), sözleşme (kira · iş · satış ·
     abonelik · vekâlet), resmî (e-Devlet · mahkeme/icra · noter · tapu · nüfus/ikamet · askerlik),
     sigorta/araç (trafik · kasko · sağlık sigortası · ruhsat · muayene · ceza), iş (CV · rapor ·
     sunum · tablo · teklif/sipariş · toplantı), kılavuz (kullanım · garanti · kurulum), ekran
     görüntüsü (harita · alışveriş · sosyal medya · ayarlar · oyun · bilet/QR), fotoğraf (yemek ·
     manzara · ürün · evcil hayvan · araç).
   - Kurum listeleri: GSM (Turkcell · Vodafone · Türk Telekom), elektrik/doğalgaz/su dağıtım şirketleri
     (en yaygın ~15), banka listesi genişler; hepsinde `other` kaçışı. Kurum yalnız ilgili kategoride.
   - **Tarih bilgisi + bugün:** "son ödeme / geçerlilik tarihi bugünden (istekte verilen tarih) önce mi?"
     → "Ödemesi geçmiş fatura", "Süresi dolmuş belge" rozetleri. Tutar aralığı (choice: <100 · 100–500 ·
     500–2000 · >2000 · yok) süzgeci.
   - Tek istek kuralı korunur; soru sayısı ölçülür (girdi belirteci raporu `usage`'tan).
2. **Her dosya türü:**
   - Word/ODT/RTF/TXT/MD/HTML/EPUB → metin özütü **izolatta** (ilk ~20 bin karakter) → `text` bloğu.
   - Excel/CSV/ODS → ilk sayfanın ilk ~200 satırı CSV; PowerPoint/ODP → slayt metinleri (+ ilk slayt görüntüsü).
   - Ses (mp3/m4a/ogg/wav) → `audio` bloğu: tür (sesli not · toplantı · ders · telefon kaydı · müzik ·
     WhatsApp sesli mesajı), konuşma dili, gürültü/kalite; 14 MB üstü **Files API** (`uri`).
   - Video → `video` bloğu, düşük çözünürlük, ilk 60 sn (`start_offset/end_offset`): aile/kişisel ·
     ekran kaydı · ders · ileti/mem · belge/tahta; yanlışlıkla/çok kısa/karanlık → Ayıkla.
   - APK/arşiv → yalnız meta (ad, boyut, kaynak klasör) yazı olarak → kurulum dosyası / yedek / indirme.
   - Kapsam (§ Kamera kapalı varsayılanı) aynen; AI kapsamı dışı hiç gönderilmez.
3. **Kullanıcı kategorileri ("doğru çalışır mı?" tasarımı):**
   - Ad + "neyi kapsar" tek cümlesi (her dilde) + simge/renk. Model talimatı: "Does this file match the
     user's category: <cümle>?" — **ayrı `noul` sorusu** (yerleşik kategorinin kalibrasyonunu bozmaz;
     bir dosya birden çok kullanıcı kategorisine girebilir), eşik 0,7.
   - **Kaydetmeden önce "Dene"**: son 20 dosyada tek soru → eşleşenler önizlenir, kullanıcı cümleyi
     düzeltir; ≥ 1 eşleşme ve kullanıcı "doğru" demeden kaydedilmez.
   - Geriye dönük uygula: düzenlenmiş dosyalara YALNIZ o soru (ucuz), ilerlemeli; en çok 30 kategori.
   - Süzgeç, akıllı klasör, arama ve ikinci ad (kullanıcı kategorisi baskınsa) yerleşiklerle aynı yoldan.
4. **Doğruluk ölçüm tezgâhı (ÖLÇÜM):** ayarlarda gizli "Doğruluk ölçümü" — kullanıcı kendi 100
   dosyasını etiketler (yerelde kalır, depoya GİRMEZ — KVKK), model sonuçlarıyla karşılaştırılır:
   kategori/alt tür/tarih doğruluğu, güven eşiği önerisi. **Kapı: kategori ≥ %90, alt tür ≥ %80**;
   altındaysa şema/talimat düzeltilir. Sonuç `docs/perf/` benzeri `docs/ai/` raporu (dosya adı yok).
5. **Hız/kota:** tur izolatta hazırlık, ana iş parçacığında yalnız sonuç; ücretsiz kota (429) ölçülür,
   günlük üst sınır + "Wi-Fi'de" seçeneği; liste satırında ikinci ad maliyeti A/B (ÖLÇÜM KAPISI).

**Bitti:** dört tür ailesi (görsel/PDF, Office/metin, ses, video) düzenleniyor · kullanıcı kategorisi
"Dene"li · tezgâh raporu kapıyı geçti · CI + A/B yeşil.

### 1.2) B2 ayrıntısı — Akıllı düzen 2.0 kullanım

- **Ayıkla 2:** benzer kare grupları (yerel algısal özet + AI `score` net/gözler açık/kadraj) → en iyi ⭐,
  kalanlar tek dokunuşla gizle/sil; WhatsApp "iletildi" görsellerinin kopyaları; ekran görüntüsü yaşı.
- **Kontrol listeleri:** kaydedilebilir listeler (vize dosyası, kira sözleşmesi, reçete, epikriz, iş
  başvurusu); belge ya da klasörde çalışır → ✓/✗ + güven, eksik evrak; PDF rapor olarak paylaş.
- **Düzeltmeden öğrenme:** kullanıcının "Düzelt"i aynı kaynaktan (klasör/gönderen adı deseni) gelen
  sonraki dosyada öncelik; hatalı kategoriler tezgâha örnek olur.
- **Taşıma kuralları (isteğe bağlı):** "Fatura → Faturalar/2026", "Kimlik → Kasa" — ilk seferde onay,
  her taşıma geri alınabilir, varsayılan KAPALI (karar 1: dosyalar yerinde).
- **Hassas kategoriler** (kimlik, sağlık, banka, vergi) uygulama kilidi açıkken görünür.
- **Decisions'ın kalan kullanımları** (eski P33): tarayıcı sonrası sayfa kalitesi (yeniden çek), akıllı
  temizliğin yerel bulanık/selamlaşma sezgisini doğrulama, sohbet yönlendirici (basit soru → ucuz
  model), PDF form "imza alanı boş mu / doldurulmuş mu" toplu denetim, galeri akıllı süzgeci (yalnız
  kategori — içerik araması YOK, KVKK).

### 1.3) B3 ayrıntısı — Hız (Ferrari)

- **P12b:** `xlsx_100k_acilis` p99 128 ms (gerçekse kök neden), `xlsx_10k_x20_*` ve `*_sk` neden
  tabloda yok, düzelt + 3 tur ölç; soğuk açılış A tabanı (docs/perf/2026-11-14-ab-1684533-*.md).
- **P29:** H4 dosya listesi büyük başlığı kaydırınca katlanmıyor; ana ekranda kalıcı "beklenmedik hata
  (1 kayıt)" şeridi — kök neden (CIHAZ_TESTI 2026-11-14 P09).
- **P06:** PDF kaydırma H2.1–H2.6: önbellek tavanı ölç, bulanık yer tutucu, komşu sayfa ön çizimi, hızlı
  tutamaç önizlemesi, yakınlaştırma netleşmesi, USB okuma hızı — ölç → değiştir → ölç.

### 1.4) B4 ayrıntısı — PDF Pro (arsiv/PDF_PRO_PLANI)

- **P16** metin: taşma/çakışma uyarısı (punto küçült · it · genişlet), font seçici (belge → aile → paket), metne bağlantı (56–58).
- **P17** nesne/işaret: hizalama kılavuzu + tutunma, çoklu seçim/grup, katmanlar (OCG), kamera; serbest metin/bulut/damga, basınçlı kalem + avuç reddi, XFDF (59–60).
- **P18** form + imza tek yüzey, form oluşturma, düz PDF'te alan algılama; form otomatik doldurma + akıllı karartma önerisi (61, 65/3).
- **P19** OCR Pro: görünmez katman, renkli arka planda satır düzenleme (62) — Arapça için `CloudOcr` yolu hazır.
- **P20** sayfa stüdyosu (küçük resim ızgarası, geri alınabilir sayfa komutları) (63).
- **P21** parola/izin, meta veri, optimize, PDF/A, bu kipte yazdır; AES-256 (R6) kilit açma; `PdfEditorScreen` emekliliği (64).
- **P22** kalite: başarı %94 → %98 (Type3 aralık, `/Rotate`, açılı metin), 50 sayfa artımlı kayıt, büyük belge/pil, görsel cila + tablet (54, 66–68) — C1'deki P08 birleşince.

### 1.5) B5 ayrıntısı — Biçim + bakım + levha birliği

- **P23 UDF (UYAP) okuyucu:** salt okuma + `.udf` ilişkilendirme + testler. Biçim çözüldü (2026-11-15):
  ZIP → `content.xml` + `documentproperties.xml`; kök `<template format_id="1.8">`; `<content>` CDATA = düz
  metin; `<properties><pageFormat>`; `<elements>` → `<paragraph Alignment FirstLineIndent>` → `<content
  startOffset length family size bold italic foreground>` + `<image imageData=base64>`; `<styles>`.
  Örnek KVKK gereği depoya GİRMEZ → sentetik `.udf` üret. Akıllı düzene "resmî/mahkeme" olarak bağlanır.
- **P24 bağımlılık bakımı:** override'lar (`xml`, `pointycastle`, `dartssh2`) yeni sürüm çıktıysa kaldır;
  `shared_preferences_android` 2.4.28 sabit; Dependabot PR'ları #82–84 (onay §3 K14).
- **P25 levha/pencere birliği:** ham `showModalBottomSheet`/`showDialog` → `showAppSheet`/`showAppConfirm`/
  `showAppPrompt`, parti parti önce/sonra PNG; birleştirme onaydan sonra (§3 K17).

### 1.6) B6 ayrıntısı — Tasarım tamamlama

- **P31 kalanları:** D simge takımı (24 ızgara, 1,8 çizgi, %18 iç dolgu — kendi glif çizimi), F metinleri
  (arama "Dosya ya da özellik ara", son açılanlarda "Ekran görüntüsü · Bugün 09:31", "Tümü →" okunu kaldır,
  "Son tarama bugün 00:29 · 5.691 dosya", kutu adlarında cümle düzeni — K19), alt paneldeki Aktar kapsülü
  vurgu renginde, ÖLÇÜM KAPISI (ana ekran).
- **P32 kalanları:** üst çubukta Kaydet/↶/↷ yalnız gerektiğinde, Word'e "Aa", Kitaplık ⋮'ında "Sırala" (K28 bakışı).

### 1.7) B7 ayrıntısı — Sürümler + yayın

- **P30:** S4 manifest varyantları, S5 paket kimlikleri, S6 CI matrisi, S7 Lite → Pro geçiş, S8 mağaza
  metinleri, S9 Kişisel varsayılan — önce §3 K15/K16. AI özellikleri (Akıllı düzen, Decisions) hangi sürümde?
- **P26:** mağaza ekran görüntüleri (son görünüm, TR/EN/AR) → `docs/play/`; `docs/play/yayin_rehberi.md`'ye uy.

### 1.8) Cihaz paketleri (C1–C3) — telefon bağlıyken yerelde

- Taban = önceki `[apk]` profil derlemesi, ölçüm kimliği `.r8test`; eşikler §0/8 (gerileme > %10 ya da
  p99 > 24 ms → birleşmez). Senaryolar: `tool/perf_senaryo.sh`, `tool/pdf_profil.sh`; ayrıntı `ab-olcum`.
- **C1:** P08 (DEVIR.md senaryosu), P28 (A/B yarım: 1+1 tur kaldı, gözle bakılmadı), P07 (CIHAZ_TESTI "Ferrari H1.4 + H8.5").
- **C2:** P13 (klasor_5000 p99 23,5→38,9; B3.3c Fotoğraflar donması; soğuk açılış ≤ 1,2 sn), P12 (10k×20
  ≤ 1,5 sn, K23 FrameTiming %99), P14 (`word_300_menu`/`_kapanis`, K21–K22), P04 (2 tur, gürültü şüphesi;
  K6–K7) + **2026-11-18 işleri:** ana ekran "Son açılanlar/Yeni gelenler" sekmesi ve `smart` kutusu, liste
  satırında akıllı ikinci ad, galeride QR düğmesi (kaydırırken kasma yok mu).
- **C3:** P11 genel tur + K20–K28; Arapça OCR, AI hızlı/toplu kontrol, paylaşım kalkanı, Akıllı düzen ve
  Ayıkla maddeleri (CIHAZ_TESTI 2026-11-18).

---

## 2) Bilinçli kapsam dışı (yapılmayacak)

- "Verilerimi sil"e kayıtlı bağlantı/anahtar seçeneği (bilinçli dışarıda).
- Eski sürüme dönülürse Keystore sarılı sırlar okunamaz, kullanıcı yeniden girer (bilinçli ödün).
- AI'da tek belgelik maske kapatma (G10.2) — korumayı gevşettiği için yapılmadı (istenirse §3 K12).
- Başka uygulamaya sürükle-bırak (eklenti gerekir). Eski liste: `docs/arsiv/planlar/KALANLAR.md` "Bilinçli kapsam dışı".

---

## 3) Senin işlerin 👤 (ben yapamam — karar, hesap, telefon ayarı)

Cevap kısa olabilir: "K6 tamam", "K14 birleştir" gibi. Bitenleri silerim.

### Kararlar (tek kelime yeter)
- **K1 Menü kısaltma (H7.2):** PDF ⋮ "Daha fazla" 13–15 madde. Öneri: ilk 5 = Sayfaya git · Sesli oku · Metni tanı · Okuma ayarları · Dosya işlemleri; gerisi "Diğer". → "menü tamam" / "menüler kalsın".
- **K2 Çöpe atmada onay (H7.4):** artık sorulmuyor, "Geri al" çıkıyor (Ayarlar › Depolama › "Silmeden önce sor" ile açılır). → sorun yoksa bir şey deme / "onay geri gelsin".
- **K3 Tarama rehberi:** ilk 3 taramada çıkıyor; "bir kez" olsun mu?
- **K4 "Kopyalandı" bildirimi:** Android 13+ kendi de gösteriyor; çift görünüyorsa söyle, kaldırırım.
- **K5 Çift bölmede sürükle-bırak = kopya:** taşımak için "Taşı". → "sürükle taşısın" dersen değiştiririm.
- **K6 Galeri alt çubuğu (H11):** 8 düğme → altta Paylaş · Düzenle · İyileştir · Bilgi · Sil; Boyut · Araçlar · Seç ⋮'ya. → "galeri tamam" / "galeri kalsın".
- **K7 Editör üst çubuğu (H11.1):** Kaydet yalnız değişiklik varken görünsün mü? → "editör tamam" / "editör kalsın".
- **K8 Liste hız sınırı (P13):** 24 ms sınırı TalkBack kapalı ölçüme (`_sk`) bağlansın, açık olan yalnız kötüleşmeye bakılsın mı? Silinen satırın kapanma animasyonu yok, yeni satır bir an vurgulanıyor; yeterli mi?
- **K9 Google Drive kapsamı (G8.5):** "dar" (`drive.file`, Play incelemesi kolay, Drive'da gezme biter) / "tam".
- **K10 Dış güvenlik taraması (G12.6):** MobSF / drozer, ücretsiz. → "tarama yap" / "gerek yok".
- **K11 Android 7 kasa parolası (G3):** 600 bin tur ≈ 10 sn+ olabilir. Android 7 telefon varsa süreyi söyle; uzunsa tur düşürülsün mü?
- **K12 AI tek belgelik maske kapatma:** istersen "ekle" de (şu an yok, en güvenli).
- **K13 OneDrive / Dropbox eklensin mi?** Uygulamasız alıcıya "tarayıcıda çöz" bağlantısı yapılsın mı?
- **K14 Dependabot PR'ları** #82 setup-gradle 6, #83 upload-artifact 7, #84 cache 6 → "birleştir"?
- **K15 Sürümler:** Pro fiyatı, uygulama adları (Lite/Pro), taramanın hangi sürümde olacağı, "Tüm dosyalar" izni reddedilince ne olacağı → P30 açılır.
- **K16 Play izin varyantı (B5.3):** Play derlemesinden hangi izinler çıksın (QUERY_ALL_PACKAGES, READ_MEDIA_*, APK kurma)?
- **K17 Levha birliği (P25):** her parti için önce/sonra görüntüye "tamam" demen gerekecek — başlayayım mı?
- **K19 Ana ekran tasarımı (P31):** Ayarlar › Görünüm'de üç yeni tema var (Sakin, Bento, Koyu başlık). Hangisi varsayılan olsun? Kutu adlarında cümle düzeni ("Önemli dosyalar") tüm ekranlara uygulansın mı? Simgeler renkli mi tek renk mi?
- **K18 Açık soru:** "tikli öğesi çok notlar kasıyor" (2026-10-29) hâlâ geçerli mi?

### Telefonda sen bak
- **K20 PDF düzenleme (Düzenle → Metin):** iki parmak yakınlaştırma (seçim yerinde kalmalı) · `ğüşıöçİ` yaz (aynı yazı tipi/boy) ·
  Gboard önerisi + sesle yazma · hızlı yazınca gecikme yok · dekont satırı değiştir → Kaydet "kopya / üstüne yaz" sorar ·
  WhatsApp'tan açılan PDF → "kopya Belgeler'e kaydedildi" · Chrome/Acrobat'ta aynı görünüm, karartılan yazı seçilemez ·
  ⋮ → Yeniden yaz/Çevir · 5 dk boşta ısınma yok. Bozuk olanın görüntüsünü at.
- **K21 Word mobil editör (B3.2):** Word aç → Düzenle → `ğüşıöçİ`, sil, Enter, uzun basıp seç, öneriye dokun → "mobil editör tamam" dersen eski yolu silerim.
- **K22 Word kapanışı (B3.3d):** ⋮ aç-kapat, geri ile çık → "akıcı" / "takılıyor".
- **K23 Tablet turu (H9):** tablet bağla ya da `CIHAZ_TESTI.md` "Ferrari H9"a kendin bak → "H9 tamam".
- **K24 Samsung ölçümü (H0.1):** `docs/perf/2026-11-H0.md` 10 işlem (özellikle 1, 3, 4, 5, 8, 9) Samsung'da ekran kaydı + kronometre. USB diski telefona takarsan 231 MB PDF ölçümünü (H0.4) ben alırım.
- **K25 Erişilebilirlik ölçümü (P6):** TalkBack'i aç, "açtım" de, ölçüp söylerim, kapatırsın.
- **K26 İkinci cihaz:** Xiaomi 13T / GMS'li telefon bağlarsan aynı ölçümler + Drive girişi + ML Kit model indirme orada.
- **K28 Menü ortak düzeni (P32):** PDF, Word, Excel, slayt, galeri, video ⋮ → Sil en üst sırada mı · türe özel grup ayrı renkte mi · alt çubuk yana kaymıyor mu · Ayarlar başlığı büyük/kalın mı → bozuk olanın görüntüsünü at.
- **K27 Telefonda temizlik:** `/sdcard/Download/PdfPro/` test kopyaları ve `….r8test` ölçüm uygulaması ölçümler bitince silinebilir.

### Hesap / anahtar / ayar
- **K30 Drive girişi, OCR/çeviri modeli, SFTP/FTP/NAS** — kendi hesabın/sunucunla dene; liste gelir, aktarım biter mi?
- **K31 Kalıcı sürüm:** `v1.2.N` etiketi (GitHub → Releases) — ya da "at" de, ben atayım.
- **K32 Güvenlik e-postası:** `SECURITY.md` için adres.
- **K33 `SIGN_CERT_SHA256`** repo değişkeni (APK imza doğrulaması).
- **K34 Depo ayarları (G9.5):** Secret scanning + Push protection; `main` koruması (zorla itme/silme yok); fork PR onayı; 2 adımlı doğrulama; eski erişim belirteçlerini sil.
- **K35 İmza anahtarı yedeği (G9.7):** 2 çevrimdışı yedek (şifreli USB + parola kâğıtta, ayrı yerde); Play'de "Play App Signing".
- **K36 OpenSubtitles:** `OPENSUBTITLES_API_KEY` secret'ı (yoksa altyazı araması gizli).
- **K37 Play Console + yayın:** geliştirici hesabı, `v*` AAB'si iç teste, 48 saat iç test (ANR < %0,47, çökme < %1,09).
- **K38 Lisans:** depo private + `LICENSE` ("Tüm hakları saklıdır"); Syncfusion Community License belgesi saklandı mı?
- **K39 Office uyumluluk turu:** düzenlenmiş Word/Excel/PDF çıktılarını Microsoft Office / Acrobat'ta aç, bozulma var mı?
- **K40 Sesli not → Notlar uygulaması** tarafı (ayrı depo).
- **K41 PDF maket onayı (Faz 53):** https://claude.ai/artifact/PNjvf5wSp5ae2rY56RpNQW — itiraz varsa söyle.
- **K42 PDF külliyatına eksik üreticiler:** LibreOffice, Google Docs, LaTeX, macOS Quartz örnek PDF'leri.
