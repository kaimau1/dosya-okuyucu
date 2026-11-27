# PLAN — tek kalan-iş listesi (2026-11-15 birleştirmesi · 2026-11-18 büyük paketler)

**Açık işin TEK kaynağı burası.** 2026-11-15'te KALANLAR, KONTROL_LISTEM, OTOMASYON Kuyruğu ve
8 faz planı (FAZ, DUZENLEME, GELISTIRME, YUKSELTME, PDF_PRO, GUVENLIK, FERRARI, SURUM) buraya
toplandı. Eski dosyalar **`docs/arsiv/planlar/`** altında (yalnız ayrıntı/karar kaynağı, yürütülmez).
Telefonda adım adım bakılacaklar: `docs/CIHAZ_TESTI.md`. Yürütme düzeni (zincir): `OTOMASYON.md`.

**Kurallar:** biten satır **SİLİNİR** (tik bırakılmaz) · karar / kök neden / tuzak → HAFIZA ·
cihazda bakılacak yeni şey → `docs/CIHAZ_TESTI.md` · kullanıcının yapacağı → §3 (ne · nasıl ·
doğruysa · yanlışsa) · yeni iş → **ilgili B/C paketine madde** (yeni paket yalnız hiçbirine uymuyorsa).

---

## ⚡ Son Denetim & Düzeltmeler (2026-11-27 — Bulut / Claude için)

> **Bu bölüm doğrudan `main` üzerine işlenmiştir; bulut oturumu devam ettiğinde bu işleri TEKRAR YAPMASIN:**
> 1. **K15 bölgesel Play fiyatı tamamlandı (`ProPurchase.storePrice` + `resolveProPrice`):** fiyat etiketi Google Play Billing ürün sorgusundan (`pro_unlock`) canlı çekilip önbellekleniyor; Türkiye dışı dillerde mağaza fiyatı henüz gelmeden sabit `"29,99 TL"` yazmıyor. Kullanıcı kararı (2026-11-27): TR lansmanı **29,99 TL**, diğer ülkelerde yerel alım gücüne göre bağımsız fiyat (ör. `$0.79` · IDR · MYR).
> 2. **Kilitli Pro ekranlar satın alım anında otomatik açılıyor (`ProUnlockWatcher`):** 9 doğrudan Pro ekranı (`BillsScreen`, `SmartClutterScreen`, `SmartFoldersScreen`, `SmartScopeScreen`, `SmartSortScreen`, `AudiobookLibraryScreen`, `AudiobookScreen`, `PdfToolsScreen`, `PdfEditorScreen`) `ProUnlock.owned` değişir değişmez `ProLockedView` yerine içeriği yükleyip açıyor.
> 3. **B17 `id`/`ms` eksik anahtarlar sıfırlandı:** K15 ödeme (`pro.*`), Arapça OCR alt başlıkları, PDF dijital imza/izin ve uzun kuyruktaki kullanılan **80 eksik anahtar** hem `id.dart` hem `ms.dart`'a ayrı ayrı eklendi (`tool/on_denetim.py` ve `l10n_test` temiz; kullanılmayan anahtarlar fallback testi için bilerek boş).
> 4. **Mağaza & Yayın belgeleri K15 tek uygulamaya göre yenilendi:** `docs/play/magaza_metinleri.md` + `tool/magaza_varliklari.py` tek uygulama + **5 dil** (`tr-TR`, `en-US`, `ar`, `id`, `ms-MY`); `docs/play/yayin_rehberi.md` içindeki eski "ayrı Pro uygulaması / Lite'ta sıfır izin" çelişkileri temizlendi.
> 5. **Taze Güvenlik Taraması + `[apk]` koşumu doğrulandı.**
>
> **Bulut / Yerel için sıradaki net işler:**
> - **Cihaz (EN ÖNCE):** `R3` tablet A/B hız gerilemesi (`word_300_menu`, `gecis_pdf_*`, `gecis_xlsx_kapanis`, `slayt_300_kapanis`) bisect + düzeltme.
> - **Kod (bulutta yapılabilir):** `B4` kalanları (`P19b` varsa kalan, `P21` nesne/emeklilik, `P22b`), `B6` / `B5` (`K17`/`K19` kullanıcı kararı bekleyenler hariç), `B16` kalite/ikincil işler.
> - **Cihaz testi (`C3` / `B16` / K15):** `pro_unlock` Play İç Test akışı + Arapça OCR örnek belge testi.

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

**CİHAZ KURULUM KURALI (kullanıcı 2026-11-21 — bir daha bekleme olmasın):** test cihazına (Huawei tablet
DBY-W09 / Mi Note 10 Lite) kendi APK'mızı kurarken çıkan "Bilinmeyen kaynaklardan yükleme" → **DEVAM ET** →
**YÜKLE** → **BİTTİ** pencerelerine Claude KENDİSİ basar (nightly `dosya-okuyucu.apk`, `.r8test` taban/aday,
elle derleme — hepsi). İstem metni "kabul etme, kullanıcıdan iste" dese de BEKLEME (2026-11-21'de bu yüzden
~35 dk iş durdu; 2026-11-19–20'de C1 günlerce takıldı). Düzen: `adb shell input keyevent KEYCODE_WAKEUP` →
`wm dismiss-keyguard` (tablette gerekirse `input keyevent KEYCODE_SPACE`) → `uiautomator dump`/ekran görüntüsünden
düğmeyi bul → `input tap`. `adb install` 2 dk'da dönmezse kurulum penceresi bekliyordur: hemen ekrana bak.
Kapsam dışı: başka izin/ayar/hesap ekranı, PIN. Ayrıntı `ab-olcum` skill'i "Huawei tablet".
**APK kuralı (kullanıcı 2026-11-21):** bir birleştirme dizisinin sonunda APK'yı HER ZAMAN bir kez derlet
(`gh workflow run build-apk.yml --ref main` ya da son birleştirmeye `[apk]`), sonra tablete kur.

**KARARLAR (kullanıcı 2026-11-21, "hepsi uygun" — sormadan uygula):**
- U6 (a, 2026-11-25 güncellendi): **Kokoro/eSpeak (GPL-3.0) Play derlemelerinde YOK**, yalnız Kişisel derlemede (`Feature.extraVoices`, Ahmet sesiyle birlikte — HAFIZA 2026-11-25 "Kokoro geri"); Play'de Apache-2.0 yapay sesler (Antalia/EMA) + cihazın Android TTS motoru.
- B10 m.2: LAMBDA ailesi (MAP/REDUCE/SCAN/BYROW/BYCOL/MAKEARRAY) **Türkçe adlarla** da tanınır/yazılır
  (Excel'in resmî Türkçe adları; İngilizce ad da çalışmaya devam eder).
- B9b: Word yorum balonu **tablette sağ kenar sütununda** (telefonda paragraf altında kalır).
- B4: eski PDF düzenleyici de **yeni PDF Pro motorunu** kullanır (`pdf_pro_engine ?? true` — 2026-11-21 main'de).

**SIRA (2026-11-18, kullanıcı: "özellikleri geliştirmeye devam — Word, PDF, Excel, slayt; performans,
hızlandırma, akıcılık, kullanıcı deneyimi hissi"):**
- **ÖNCE R3 (gerileme kökü, telefon).** **Kod (bulut ya da yerel; 2026-11-26 eşitlendi):** R2 + K1 dallarını birleştir (yürütücü) → B4 (P18 main'de; sıradaki P19+) → B7b → B5/B6/U4 (kullanıcı kararıyla: K14, K17, K19, U4 adayları) → **en son (kullanıcı 2026-11-26): B16 → B17**.
- **Telefonla (yerel, paralel; boşaldıkça):** C2 (önce Word/Excel ikinci tur) → C1 → B3 → C3 (B11 m.4 dahil). **En son:** B8.

Ferrari kuralı (§0): B3'teki hız işleri (P06, P12b, P29) bitmeden büyük yeni özellik **varsayılan
açık** birleşmez — B1/B2 bayrakla (Akıllı düzen kullanıcı açınca çalışır) birleşebilir.
**Gevşetme (kullanıcı 2026-11-18, "özellikleri geliştirmeye devam"):** B9–B11 editör özellikleri ve
B4 PDF Pro varsayılan açık birleşebilir — koşul: dosya listesi / ana ekran / PDF kabuğunun sıcak
yoluna dokunmaz, dokunulan editörün bütçe testi yeşil, A/B sonra C2'de. C2'de gerileme çıkarsa
(§0 eşikleri) o commit `git revert` ya da düzeltme SIRA'nın EN ÖNÜNE.

| No | Paket | Model | Kaynak | Cihaz | APK | Durum |
|---|---|---|---|---|---|---|
| R2 | **C2 gerileme kökü — Word ölçüm senaryosu:** `perf_senaryolari_test` word_300_menu yalnız `PopupMenuItem` arıyordu; Word ⋮ ortak dosya levhası (BottomSheet) olunca levha açık kalıp sonraki Word ölçümleri yanlış yüzeyi ölçtü (Bento varsayılanı levhayı değiştirince "Word gerilemesi" göründü) | opus | C2 2026-11-21 | A/B | hayır | kod bitti — dal faz-oto-R2-gerileme (60d8fed6, main'de değil; HAFIZA kaydı dalda): birleştirme yürütücüde, sonra C2 Word/Excel ikinci tur |
| U4 | **Akıllı klasörler + Analiz + Akıllı ayarlar (beyin fırtınası, nokta atışı):** §1.14 m.7, m.9, m.10 + B15 m.4 kategorizasyonu mükemmelleştirme. **Bitti (dilim 1, 7 madde; HAFIZA 2026-11-20 U4):** durma/başlamama iletileri gerçek neden · hayalet kayıt budama · kayıtlı aramalar Akıllı düzeni arar + "Akıllı aramalar" adı + PIN · "Diğer" klasörü · Yapay zekâ ayar sayfası baştan (Hafıza kalktı) · Analiz "Tümünü seç" 200 sınırı · Analiz Kopyalar/Ayıkla. **Bitti (dilim 2, 3 madde; HAFIZA 2026-11-20 U4 dilim 2):** ağ kopunca tur durur (ortak durma kuralı, tezgâh dahil) · bulanık belge fotoğrafı Ayıkla'ya önerilmez (e) · öğrenilen kategori alt türünü/kurumunu korur. **Kalan adaylar (seçilmedi):** (a) klasör kutusunda "+n yeni" rozeti; (b) kutuda ilk dosyanın küçük resmi (ızgara, ölçümle); (c) klasörü ızgaradan gizle; (d) yeni yerleşik kategoriler (ev/tapu/aidat, çocuk/okul, tarif — önce C2 tezgâh ölçümü); (f) Kategorilerim ızgarada klasör (görünüş, kullanıcı kararı); (h) Analiz'de Akıllı kategoriye göre yer ("Faturalar 1,2 GB"); (j) eski Akıllı dosya asistanı (AiIndex analizi) ile Akıllı düzen ikiliği (budama kullanıcı kararı) | opus (xhigh) | §1.14 | A/B | evet | kullanıcı kararı — dilim 1–3 main'de (58e0e57d, 09f5dc10, bb0aa582; cihaz turu CIHAZ_TESTI U4.2/U4.3, ölçüm C2); kalan adaylar (a)–(j) seçilmedi + B15 m.4 kategorizasyon (C2 doğruluk tezgâhından sonra; B15 dilim 1 main'de 39a080a8). Sabah bakılacak: "Akıllı aramalar" adı; B15 budamasında hızlı/toplu kontrol + kontrol listesi kalktı (geri alınabilir), Ayarlar'daki "AI Kalıcı Hafıza" artık hiçbir işte kullanılmıyor |
| B3 | **Hız (Ferrari) kod + ölçüm:** P12b Excel/liste A/B artıkları, P29 büyük başlık + kalıcı hata şeridi, P06 PDF kaydırma H2.1–H2.6 | opus (P06 plan evresi fable) | §1.3; arsiv/FERRARI_PLANI H2 | A/B | evet | cihaz bekliyor — P29 main'de (1df7facb; büyük başlık H4.2 kararıyla zaten yoktu; ölçüm C2); kalan P12b ölçümü + P06 (plan evresi fable + cihaz) |
| B4 | **PDF Pro tamamlama:** P16 metin, P17 nesne/işaret, P18 form+imza, P19 OCR Pro, P20 sayfa stüdyosu, P21 parola/meta/optimize/PDF-A, P22 kalite %98 | opus (plan evresi fable) | §1.4; arsiv/PDF_PRO_PLANI 54–68 | A/B | evet | sürüyor — dilim 1–8 + P16 metin + P17 nesne/işaretleme + P18 form+imza tek yüzey + P19 m.2/m.3/m.4 + P20 sayfa stüdyosu + üst/alt bilgi ekle/düzenle/kaldır (`85363ed`) main'de; P21 güvenlik + çıktı dalı `faz-oto-B4-p21`; sıradaki P21 kalanı, P22b, P22 |
| B5 | **Biçim + bakım + levha birliği:** P23 UDF (UYAP) okuyucu, P24 bağımlılık bakımı, P25 levha/pencere birliği (onay §3 K17) | opus | §1.5 | A/B | evet | kullanıcı kararı — P23 UDF + P24 bakım main'de (xml/pointycastle override üst paket yüzünden kalır); kalan P25 (K17 onayı, §3 m.9), Dependabot dalları actions/cache · upload-artifact · setup-gradle (K14) |
| B6 | **Tasarım tamamlama:** P31 ana ekran aileleri kalanları (D simge takımı, F metinleri, K19), P32 menü ortak düzeni kalanları | opus | §1.6; docs/design/ana_ekran/ | A/B | evet | bekliyor — K19 kararıyla |
| B7b | **Play çıkış & rakip paketi — KALAN** (kod 2026-11-26 `faz-oto-B7b-play` + 2026-11-27 `faz-oto-K15-iap` + bölgesel fiyat/anında kilit açma main'de): (2) **Lite diyeti GERİ ALINDI (K15):** Lite = tek uygulama, tüm kod içinde (≈ 87 MB; CI Lite bütçesi 91 MB); (1) **Pro tek seferlik satın alım + bölgesel Play fiyatı + kilitli ekranların anında açılması KODDA BİTTİ** (`ProPurchase.storePrice`, `resolveProPrice`, `ProUnlockWatcher`), cihazda/Play'de denenecek → 👤 §3 m.7 + C3; Akıllı Klasör ekstra kota aboneliği (K15a) ayrı, kodu yok; (7) Play AAB = `build-apk.yml` elle tetik `aab=true`; (3) görseller + 5 dil metinleri hazır, ekran görüntüleri 👤 §3 m.10 · (4) ayna sunucusu 👤 §3 m.7b · (5) → C3 | opus / sonnet | Play + Rakip Denetimleri + Kullanıcı Kararları 2026-11-26/27 | A/B | evet | **bekliyor — 👤 §3 m.7 (`pro_unlock`) + m.10 görseller; satın alma akışı C3 (iç test kanalı)** |
| B11 | **Slayt 2.0:** görsel sadakat (altın görüntü testleri), grafik türleri, geçiş + animasyon + Biçim değiştir, yerinde metin düzenleme, AI tasarımcı, notlar + prova, sadakat bekçisi, sürükleme bütçesi | opus (animasyon planı fable) | §1.11 | A/B | evet | cihaz bekliyor — dilim 1–3 + m.2 grafik türleri + m.1 dikey metin main'de; m.1 yansıma çizimi dal faz-oto-K1-kuyruk (birleşmeyi bekliyor); kalan m.1 piksel altın testi (kullanıcı izniyle yerelde), m.4 klavye kayması cihazda (C3); m.5 AI tasarımcı İPTAL (B15) |
| B8 | **Son kapı:** P27 "10 işlem" son ölçüm + Samsung kıyası, erişilebilirlik, özellik dondurma kalkar | sonnet | arsiv/FERRARI_PLANI H12 | A/B | evet | bekliyor — en sonda, kullanıcıyla |
| R3 | **Gerileme kökü (hız anayasası — SIRA'nın EN ÖNÜ):** 2026-11-26 tablet A/B 4b2bec2→ad4ee9a iki turda kaldı: word_300_menu build/raster p99 +%63–92, gecis_pdf_acilis raster p90 +%85–125, gecis_xlsx_kapanis raster p99 +%39–79, pdf_100_acilis +%23–39, slayt_300_kapanis +%12–29. Tek senaryolu bisect (`AB_SENARYO=gecis,word_300`) ile suçlu commit(ler)i bul → revert ya da düzeltme → A/B yeşil | sonnet (bisect) + opus (düzeltme) | docs/perf/2026-11-26-C1-C2.md | A/B | evet | bekliyor — EN ÖNCE · **2026-11-27 bisect: PDF/geçiş suçlusu bd691226 (alttaki sayfa ölçeği); (a) düzeltme dalı faz-oto-R3-gecis: geçiş raster p99 −%17–24 (yeşil); PDF `acilis_belge` kırmızısı ölçüm kaynaklı (iki kipli damga, bisect’te aynı değişiklik ters yönde — docs/perf/2026-11-27-R3-ab.md sonu), kod değişmedi → (a) v2 — A/B bekliyor (4A+4B ABBA, PDF kararı ortanca/acilis_ilk_sayfa ile)** (taban e05e099b ya da main; Word menü kökü 170a9be5..47f45aae ayrı) · **(b) Word ⋮ menü:** v1 RepaintBoundary A/B KIRMIZI; **v2 dal `faz-oto-R3-wordmenu2` — A/B bekliyor:** "levha her karede kuruluyor" hipotezi CI kare iziyle çürük (bekçi testi eklendi, uygulama kodu değişmedi) → önce aynı oturumda 4b2bec2↔main `AB_SENARYO=word_300` 3A+3B (gerileme gerçek mi), tutarsa timeline özetiyle ağır karenin evresi (HAFIZA 2026-11-27 R3 b v2) |
| C1 | **Cihaz: hazır dalların ölçümü:** P08 PDF Pro bellek (`faz-oto-P08-bellek`), P28 PDF kabuğu (`faz-oto-P28-pdf-kabuk`), P07 son sayfa + döndür (`faz-oto-P07-artik`) → A/B → yeşilse birleştir | opus | §1.8; DEVIR.md | A/B | evet | **2026-11-26 tablette A/B KALDI (2 tur, 4b2bec2→ad4ee9a, 121 commit):** sonuç docs/perf/2026-11-26-C1-C2.md; kök neden R3'te; P08 bellek (PSS) ve senaryosuz kalemler ölçülmedi |
| B19 | **İçindekiler çıkarma arka planda + doğruluk (kullanıcı 2026-11-27, ekran görüntüsü):** yer imi olmayan 750 sayfalık metinli PDF'te (Türkçe+Arapça) "İçindekiler" → "Metin tanınıyor, başlıklar aranıyor… 4/750" levhası ekranı kilitliyor, çok yavaş ve kullanıcıya göre doğru çalışmıyor. İstenen: (1) iş kuyruğa/arka plana alınsın (levha kapatılınca durmasın, bitince bildirim + önizleme onayı), (2) kök: metin katmanı olan PDF'te neden OCR yolu ("Metin tanınıyor") — `PdfAutoOutline.looksScanned` / sayfa başı metin çıkarma; metinli PDF'te OCR'sız, hızlı yol; başlık sezgisinin doğruluğu bu kitapta denensin. Kaynak `lib/widgets/pdf_outline_sheet.dart` `createPdfOutline`, `PdfAutoOutline`. | bekliyor | opus | A/B yok | evet |
| C2 | **Cihaz: perf A/B artıkları (hepsi main'de; taban önceki [apk] `.r8test`):** **İkinci tur (2026-11-21 tablette kaldı):** B9b Word yorum sütunu (word_300_kaydirma raster p99 15,9→22,4, word_300_menu build p99 16,6→28,6 — kök muhtemelen ölçüm senaryosu, R2) ve B10 Excel büyük xlsx (xlsx_100k_kaydirma build p90 8,5→24,8, xlsx_10k_x20_acilis p99 144,6→180,9; kod kökü bulunamadı, hipotez: önizleme→tam model yer değişimi). **Kaldı, kök neden bekliyor:** P13 liste/ızgara (klasor_5000 build p99 20,6→46,1), B11 dilim 3 sunum (slayt_300_acilis_pro0 build p99 30,9→45,5). **Ölçülmedi:** B10 süzgeç levhası + chartex çizimi; P12 Excel 10k×20; P14 Word kapanış/menü (K21–K22); P04 boş/hata (K6–K7); U2 tek şerit; U3 ana ekran kaydırma (senaryo yok); U4 Akıllı düzen ızgarası; U5 galeri çimdik + pano araçlar; U7 tablet tek menü + pano (CIHAZ_TESTI U7); B11 dilim 1–2 + m.2 + m.1 yansıma; B4 dilim 1–8 + P16/P17 (kalemle çizerken kare p99; 300 sayfada p99 ≤ 16 ms); B15 budama; B5 UDF açılışı; B3 P29 ana ekran açılışı; Yer aç/Bento levha (senaryo yok); §1.8 C2 listesi (2026-11-18/19 işleri). **Geçti:** B2 dilim 1–5, galeri açılış geçişi (2026-11-20), sol menü (2026-11-21). Ayrıntı §1.8, docs/perf/ | opus | §1.8; docs/perf/ | A/B | evet | **2026-11-26 tablette A/B KALDI (2 tur, 4b2bec2→ad4ee9a, 121 commit):** sonuç docs/perf/2026-11-26-C1-C2.md; kök neden R3'te; P08 bellek (PSS) ve senaryosuz kalemler ölçülmedi · 2026-11-27: word_mobil_kaydirma_pro0/1 raster p90 +%65–71 (7,7→13,2 ms; p99 +%8) 4b2bec2↔main — kökü aranmadı |
| C3 | **Cihaz: genel tur:** P11 `CIHAZ_TESTI.md` baştan sona (Faz 34–42, Güvenlik, 360×800 + 2× yazı, 2026-11-18 AI maddeleri) + §3 "Telefonda sen bak" (K20–K28); kırmızı → ilgili pakete madde | sonnet | CIHAZ_TESTI | evet | hayır | bekliyor — telefon boşken | — **2026-11-27 tablet turu 2 (faz-oto-C3-tur2):** K15 Lite: PRO rozeti + Pro levhası + Satın al/Geri yükle 'Google Play'e ulaşılamadı' iletisi GEÇTİ (Play ödemesi denenmedi); B16 Arapça OCR (model indirme + sentetik sayfa) GEÇTİ; P19/P19b Play Hizmetleri'siz cihazda ML Kit Latin OCR KALDI: sessiz başarısızlık, ileti yok (kök: vision.dynamite modülü yok; `ae3e76cb` düzeltmesi yeni nightly'de doğrulanmalı; Latin için paketli/ONNX yedek düşünülmeli). Ayrıntı `CIHAZ_TESTI.md`. **2026-11-27 daraltılmış tablet turu (faz-oto-C3-tur):** P20 / P20ust / P21 / B17 geçti (bulgular `CIHAZ_TESTI.md`); P19 / P19b / B16 gerçek tarama ve model indirme gerektirdiği için, K15 Lite derlemesi gerektirdiği için DENENMEDİ; R3 geçişi çökmesiz açılıp kapandı, akıcılık ölçülmedi. Bulgu: Agresif sıkıştırma metin belgeyi büyütüyor → **düzeltildi** (dal faz-oto-C3-duzelt: kazanç < %5 ise sonuç uygulanmaz + metin belgede önceden uyarı); OCR stüdyosu "Metni Tanı" görünür sonuç yok → hata artık sonuç ekranında kalıcı (kök: hata yolu kısa şerit + kurulum ekranına dönüyordu; Huawei'de Play Hizmetleri yok → ML Kit düşer; cihazda doğrulanacak, `CIHAZ_TESTI.md` C3-düzelt). PDF/A 150 sayfa sınırı bilgilendirici, dokunulmadı (sınırı yükseltmek gerekirse ayrı iş).
| B16 | **İnternetsiz Arapça OCR (kullanıcı 2026-11-26):** Arapça/Farsça/Urduca/Osmanlıca/Cavi (Jawi) metin tanıma cihazda, ücretsiz; bugün yalnız Gemini (internet + anahtar + ücret). PaddleOCR Arapça modelleri (Apache 2.0) ilk kullanımda iner, APK +0 MB | opus | §1.15 | evet | evet | sürüyor — dal faz-oto-B16-ocr: **dilim 1 yazıldı, cihazda doğrulanmadı** (m.1 model indirme: PP-OCRv5 mobil det + Arapça rec ONNX, ≈13 MB, sesli kitabın WebView ONNX Runtime'ı ORTAK; m.2 `OcrService` sırası: Arapça ayarı → yerel → Gemini, otomatikte zayıf Latin → yerel; m.3 `OcrLine` kutuları aynen; ayar satırında indir/sil). **Kalan:** m.4 kalite kapısı + hız/bellek (cihaz → C2/C3, CIHAZ_TESTI B16), yerel sonuç zayıfsa Gemini'ye sorarak geçiş, eğik fotoğraf için döndürülmüş kutu, m.5 PP-Structure (isteğe bağlı). Sabah bakılacak: ORT wasm indirilen çalışma zamanı (seslerle aynı yol; Play politikası) |
| B17 | **Endonezya + Malezya pazarı (kullanıcı 2026-11-26, satış hedefi):** Endonezce + Malayca arayüz, mağaza sayfası, yerel fiyat, düşük donanımlı telefon bütçesi, Cavi yazısı, gizlilik metinleri | opus (dil yapısı planı fable) | §1.16 | evet | evet | sürüyor — m.1–m.6 + K15/OCR/PDF sonradan eklenen 80 kullanılan anahtar + 5 dilli mağaza metinleri main'de (kullanılan eksik anahtar = 0); kalan: yalnız 👤 anadili gözden geçirme + bölgesel Play fiyatı, ucuz cihaz ölçümü (C2), cihaz turu (`docs/CIHAZ_TESTI.md` B17); 👤 maddeler §3 m.14 |
| B18 | **Yer aç birleştirme + yeni görünüm (kullanıcı 2026-11-27):** benzer kareler ve sohbet medyası Yer aç taramasına arka planda katılır (İncele satırı, seçim toplamı + ayrıntı ekranı seçimi geri yansır, Normal kademe); Yer aç ekranı sade yeni görünüm | opus | — | hayır | evet | sürüyor — dal faz-oto-B18-yer-ac: bitti kod + çeviri + test güncellemesi (derlenmedi, CI yok); kalan ön denetim, saf birleştirme testi, CI, HAFIZA/CIHAZ_TESTI; DEVIR.md'den sür |

### 1.1) B1 ayrıntısı — Akıllı düzen 2.0 çekirdek

**Hedef:** telefondaki HER dosya (kapsam klasörlerinde) anlamlı bir ikinci ad + AI kategorisi alır;
kullanıcı kendi kategorisini ekler ve **eklemeden önce doğru çalıştığını görür**; doğruluk ölçülür.

1. **Ayrıntılı şema** — _(yazıldı — bulut 2026-11-18, dal faz-oto-B1-duzen2: alt türler, banka + fatura kurumu
   (`providerFits`), son ödeme/geçerlilik aralığı bugüne göre + `SmartDates` rozetleri, tutar süzgeci, APK/arşiv
   `package` tek soru, `usage` belirteç raporu; rozet/süzgeç yalnız Akıllı düzen ekranında. Doğruluğu tezgâhta
   (m.4) ölçülecek; cihazda bakılacaklar `docs/CIHAZ_TESTI.md`)_
2. **Her dosya türü:** _(metin kısmı yazıldı — bulut 2026-11-18, dal faz-oto-B1-duzen2,
   `lib/services/fm/smart_sort_input.dart`: Word/ODT/RTF/TXT/MD/HTML/EPUB yazısı ≤ 20 bin karakter,
   Excel/CSV/ODS ilk sayfa ≤ 200 satır CSV, PowerPoint/ODP slayt yazıları, APK/arşiv yalnız ad·boyut·klasör;
   izolatta, mevcut tura girer)_ _(ses + video yazıldı — bulut 2026-11-18, dal faz-oto-B1-duzen2: sabit
   `audio`/`video` kategorisi + alt tür, seste dil/kalite, video ilk 60 sn düşük çözünürlük, yanlışlıkla → Ayıkla;
   14 MB üstü Files API; blok alan adları API'de doğrulanmadı — `docs/CIHAZ_TESTI.md`)_ _(ilk slayt
   görüntüsü yazıldı — bulut 2026-11-19: PowerPoint/ODP içindeki hazır önizleme resmi (≤ 1 MB, PNG/JPEG)
   yazıya ek görsel blok, izolatta; resmi olmayan sunum yalnız yazıyla)_ Kapsam (§ Kamera kapalı
   varsayılanı) aynen; AI kapsamı dışı hiç gönderilmez.
3. **Kullanıcı kategorileri ("doğru çalışır mı?" tasarımı):** _(yazıldı — bulut 2026-11-18, dal
   faz-oto-B1-duzen2: `lib/services/fm/smart_user_cats.dart` + `smart_user_cat_screen.dart`; normal turda
   soru bütçesi (40) yettiği kadar aynı istekte, sığmayanı "Eski dosyalara uygula" sorar; "Dene" sonuçları
   kaydedilince yeniden sorulmaz; ad/cümle değişirse eski yanıtlar silinir. Eşik 0,7'nin doğruluğu tezgâhta
   (m.4); cihazda bakılacaklar `docs/CIHAZ_TESTI.md`)_
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
   _(yazıldı — bulut 2026-11-18, dal faz-oto-B1-duzen2: `lib/services/fm/smart_bench.dart` (saf metrik +
   birim test) + `smart_bench_screen.dart`, Ayarlar → Geliştirici → "Doğruluk ölçümü". Model yanıtı: ölçüm
   sorusu (`SmartSort.probe`, düzen kaydına yazmaz) ya da elle düzeltilmemiş güncel kayıt; uzantıdan kesin
   kategoriler kategori oranına girmez; eşik önerisi = kapıyı geçen en düşük eşik (≥ 5 dosya). Gerçek
   ölçüm cihazda → C2; rapor "Raporu kopyala" → `docs/ai/`)_
5. **Hız/kota:** _(yazıldı — bulut 2026-11-19: görsel base64, istek gövdesi JSON'u ve kişisel veri maskesi
   büyük gövdede izolatta (`smart_offload_test`); `SmartQuota` günlük istek + 429 sayımı (7 gün), günlük
   sınır 50–1000 (varsayılan 200), "yalnız Wi-Fi'de" varsayılan AÇIK (sabah bakılacak); büyük video yalnız
   ilk 60 sn geçici kesitiyle (Media3 hızlı kesim; ≤ 14 MB satır içi, ≤ 50 MB yükleme; kaynak ≤ 1 GB).
   Liste satırında ikinci ad maliyeti A/B ve kota sayılarının gerçek değeri → C2)_

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

### 1.4) B4 ayrıntısı — PDF'in TÜM kalanları (envanter 2026-11-21; kaynak arsiv/PDF_PRO_PLANI Faz 56–68, arsiv/FERRARI_PLANI H0–H3)

**Main'de olanlar (tekrar yapma):** P21 meta veri + R6 kilit aç/koru · P17 XFDF dışa/içe + işaretleme stüdyosu · P20 sayfa stüdyosu
(ızgara, seç/döndür/sil/çoğalt/sürükle, geri al, boş/dosyadan/görselden/taramadan sayfa ekle, çıkar/böl, kenar
kaydırma) · kırpma/boyut/Bates/filigran/yer imi Pro araçlarda · P18 düz PDF'te alan algılama (`____`/`....`/`☐`,
çizgi/kutu sezgisi) + form oluşturma + otomatik doldurma + form/imza/dijital imza tek yüzey (`PdfSignScreen` emekli, tüm AcroForm türleri, çiz/yaz/görsel + kayıtlı imza/baş harf + tarih damgası, PAdES doğrulama) · P19 m.1
"Aranabilir yap (OCR)" görünmez katman · P08 yerinde yazma bitişi belleği · P28 kabuk (durum çubuğu anahtarı,
rozet, komşu sayfa) · eski düzenleyici yeni motorda (2026-11-21). **Kural:** her madde için önce `grep` — arşiv
planlarındaki `[ ]` kutularının bir kısmı eskidir; var olanı geliştir, yoksa yaz. Her dilim CI + `pdf_pro_*`
testleri; PDF kabuğu sıcak yoluna (`viewer/body.dart`, kaydırma) dokunan madde **bayrak + A/B** (§0 k.9).

Dilim sırası (her biri ayrı oturum/dal `faz-oto-B4-<ad>`; biten madde buradan SİLİNİR):
5. **P19 OCR Pro kalan** — m.3 + m.4 `faz-oto-B4-p19b`'de (birleşince bu madde SİLİNİR). Yapılmayan (bilerek):
   doku/desenli zeminde inpainting, kontur kalınlığından yazı tipi sınıfı tahmini, satır içi düzenleme alanında
   sözcük işareti (işaret yalnız satır kutusu katmanında); Arapça/bulut OCR güven puanı vermez → işaretsiz.
   **P19c Play'siz OCR (2026-11-27, `faz-oto-P19c-playsiz-ocr`):** tablet turu 2'de Play Hizmetleri olmayan cihazda "Metni Tanı" sessizce asılı kalıyordu → ortak `OcrService._process`'e 20 sn sınır + modül yokluğu tanıma + anlaşılır ileti; Pro levhasında Play hatası levha içinde. Kod bitti — cihazda yeniden bakılacak (C3, `docs/CIHAZ_TESTI.md` B4-P19b). Paketli Latin modeli kararı §3 B 9a.
6. **P21 kalan** — main'de VARDI: Pro araçlar → İzinler (sahip/kullanıcı parolası + yazdır/düzenle/kopyala…),
   Belge bilgileri, PDF/A-2b (görüntü + görünmez metin), agresif sıkıştırma (DPI/kalite/gri = görsel yeniden
   örnekleme), Araçlar ⋮ Sıkıştır/Parola/Paylaş. `faz-oto-B4-p21`'de: meta temizle (XMP + eski sürümler dahil),
   sıkıştırmada nesne akışları, agresif sıkıştırma/PDF-A'da ilerleme + Durdur, Araçlar ⋮ Yazdır. **Kalan:**
   yinelenen font/görsel birleştirme (düşük seviye nesne yeniden yazımı — `PdfFile` + tam yeniden yazım; önce
   Syncfusion bağlantısız nesneyi atıyor mu ölç), **PdfEditorScreen emekliliği** (⋮ "Eski düzenleyici" —
   `pdf_pro_edit.dart`, `pdf_selection.dart`, `pdf_action_bars.dart` kullanımı grep). Ayrı e-posta kısayolu
   YAPILMADI: Paylaş levhası e-postayı zaten içerir (share_plus hedef seçemez).
7. **P20 kalan — üst/alt bilgi + numara ekle/düzenle/kaldır** — `faz-oto-B4-p20ust`te yazıldı (birleşince bu madde
   SİLİNİR): Pro "Gelişmiş numaralandırma" sayfasında üst/alt bilgi + numara anahtarı + Kaldır; çizim akışı
   `/Artifact … /DosyaOkuyucuHF` işaretli blokla sarılır, kaldır = kendi `PdfFile` ile yalnız o blok çıkarılır
   (`pdf/pdf_header_footer.dart`; 4 sayfalı farklı içerikli belgede ekle→düzenle→kaldır sonrası sayfa metni +
   içerik akışları birebir — `pdf_doc_pro_test`). Eski işaretsiz numara ve parolalı belge kaldırılamaz (bilerek).
   Cihazda bakılacak: `docs/CIHAZ_TESTI.md` B4-P20ust.
8. **P22b okuma deneyimi** (FERRARI H2.4 + kullanıcı 2026-11-18): hızlı kaydırma tutamacında sayfa no + küçük
   önizleme balonu (`PdfViewerScrollThumb`, `viewer/body.dart`), bağlantı/içindekilerden atlayınca "← geri dön"
   hapı, belge başına yakınlaştırma/görünüm kipini hatırla, çift dokunuşla sütuna sığdır, seçim tutamaçlarında
   büyüteç — sıcak yol: bayrak + A/B.
9. **P06 PDF kaydırma hızı** (FERRARI H2.1–H2.6; B3 satırında, plan evresi fable): önbellek tavanı ölç
   (`pdfImageCacheBytes` 64 MB), bulanık yer tutucu (≤ 48 dpi), komşu sayfa ön çizimi (+2), yakınlaştırma
   netleşmesi, USB okuma hızı → ölç → değiştir → ölç (cihaz).
10. **H1.5 Office/PDF açılış geçişi** (B13 m.1, B13'ün tek kalan maddesi): 2026-11-20 A/B KALDI (satırdan
    büyüyen kırpma, kod 659158e1) — ÖNCE Slayt/Excel ilk karelerinde neyin uzadığını zaman çizelgesinden bul
    (`ext.flutter.profileWidgetBuilds`; koddan kök neden çıkmadı: sayfa zaten `RepaintBoundary`'li, kırpma
    yerleşimi değiştirmez — 2026-11-26), sonra farklı yöntemle (ör. ilk kare hazır olunca) bayrak arkasında
    yeniden dene; A/B geçmezse iptal.
11. **P22 kalite + büyük belge** (Faz 66–67 + PDF_PRO 54, 66–68): başarı %94 → %98 (Type3 aralık, `/Rotate`,
    açılı metin), 50 sayfa artımlı kayıt, 500+ sayfa / 200 MB tembel çözümleme, pil/ısı (10 dk düzenleme CPU;
    boşta 0 kare), tablet yatay düzen (sağ panel), TalkBack/200% yazı/RTL, ilk kullanım ipuçları, ayarlar
    (kaydetme kipi, sürüm geçmişi süresi, font paketleri).
12. **Ölçüm/kapı (cihaz):** C1 P08 + P28 A/B; H0.1 10 işlem tablosu, H0.4 231 MB USB PDF (B8'de); Faz 68
    rakip karşılaştırma (Acrobat/PDFelement/Xodo, 10 belge × 15 görev — B8 ile).

### 1.5) B5 ayrıntısı — Biçim + bakım + levha birliği

- **P23 UDF (UYAP) okuyucu:** salt okuma + `.udf` ilişkilendirme + testler. Biçim çözüldü (2026-11-15):
  ZIP → `content.xml` + `documentproperties.xml`; kök `<template format_id="1.8">`; `<content>` CDATA = düz
  metin; `<properties><pageFormat>`; `<elements>` → `<paragraph Alignment FirstLineIndent>` → `<content
  startOffset length family size bold italic foreground>` + `<image imageData=base64>`; `<styles>`.
  Örnek KVKK gereği depoya GİRMEZ → sentetik `.udf` üret. Akıllı düzene "resmî/mahkeme" olarak bağlanır.
- **P24 bağımlılık bakımı:** `dartssh2` override'ı kalktı (2026-11-21, ftpconnect kopyası ^4.1.0); `xml` (webdav_client 1.2.2) ve `pointycastle` (smb_connect 0.0.9) üst paket yeni sürüm çıkarınca kaldır;
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

### 1.9) B9 ayrıntısı — Word 2.0 (sadakat + yazma hissi)

Çekirdek: `lib/services/docx/docx_document.dart` (okuma/yazma), `services/docx/pro/*`; ekran
`screens/editors/word_mobile_editor_screen.dart` + `word_mobile/`. Örnek belge KVKK gereği depoya
GİRMEZ → testte sentetik docx üret. Her madde ayrı commit.

_Bitti (bulut 2026-11-19, dal faz-oto-B9-word2; HAFIZA 2026-11-19 B9): m.1 içerik denetimleri, m.2 İçindekiler, m.3 değişiklikleri izle (`docx_track.dart`, test `docx_track_changes_test`), m.5 dipnot/sonnot, m.6 sadakat bekçisi, m.8 büyük belge açılışı (`DocxDocument.parseHead`, test `docx_head_test` + `word_perf_test`), m.7 yazma hissi (`docx_auto_format.dart`, test `docx_auto_format_test` + `word_perf_test` kural bütçesi); m.4 yorum yaz/yanıtla/çözüldü önceden vardı (`docx_media.dart`). Kalan: m.4 kenar balonu; satır/hücre düzeyi `w:sdt`; PDF'te dipnot sayfa altında (bugün belge sonu liste); izlenen paragraf bölme/birleştirme (`w:pPr/w:rPr/w:ins|del`) ve biçim değişikliği (`w:rPrChange`)._ **Kalanlar bitti (yerel 2026-11-21, dal faz-oto-B9-word3; HAFIZA 2026-11-21 B9):** satır/hücre `w:sdt`, PDF dipnot sayfa altında, izlenen paragraf işareti, `w:rPrChange`, m.4 yorum balonu (paragraf altı; tablette sağ kenar sütunu — sabah bakılacak).

3. **Değişiklikleri izle (yazarken):** açıkken yazılan/silinen metin `w:ins`/`w:del` (yazar = Ayarlar'daki
   ad, tarih); `settings.xml` `w:trackRevisions` bayrağına uyulur. Bugün yalnız karşılaştırma üretiyor
   (`docx_compare.dart`; `grep trackRevisions` = 0); kabul/ret `DocxReview`'da var. Test: izle açık →
   yaz/sil → kaydet → XML'de ins/del.
4. **Yorumlar:** seçime yorum ekle, yanıtla, çözüldü (`comments.xml` + `commentsExtended.xml` `w15:done`),
   kenar balonu. Önce bak: okuma 3 dosyada var; yazma?
7. **Yazma hissi:** klavye üstü bağlamsal biçim çubuğu (seçim varken B/I/U/renk, yokken liste/hizalama),
   otomatik düzeltme (cümle başı büyük harf, "--" → "—", çift boşluk; Ayarlar'dan kapanır), "- " / "1. "
   ile başlayınca otomatik liste, imleç büyüteci + seçim tutamakları sistemle aynı (önce bak).
8. **Büyük belge açılışı:** çözümleme izolatta, ilk sayfa önce (artımlı `DocxPaginator` var). Cihazsız
   kanıt: 5000 paragraflık sentetik belgede ilk kare için çözümlenen paragraf sayısı bütçesi
   (`word_perf_test` genişler). Cihaz A/B → C2.

**Bitti:** 1–8 testli, `word_roundtrip_test` yeşil, `kasma-kontrol`, C2'ye "Word yazma/açılış A/B".

### 1.10) B10 ayrıntısı — Excel 2.0

Çekirdek: `lib/services/xlsx_*.dart`, `services/xlsx/`, `services/formula/`; ekran
`screens/editors/spreadsheet/`. Her madde ayrı commit.

1. **Grafik türleri — çekirdek yapıldı 2026-11-21** (alan, dağılım XY, halka, radar, yığılmış / %100
   yığılmış sütun-çubuk: Excel'e yazma + ORTAK okuma/çizim `pptx_render` `_parseChart` + `ChartPainter`;
   bilinmeyen tür → en yakın tür + "≈ yaklaşık" rozeti; `test/xlsx_chart_kinds_test.dart`). Kalan:
   ~~şelale, histogram, kutu~~ — yapıldı 2026-11-21 (dal faz-oto-B10-excel4, `ChartExReader`: okuma +
   çizim; Pareto da; huni/ağaç/güneş/harita yaklaşık; YAZMA yok); slaytta YENİ türle grafik
   EKLEME — B11.2 yapıldı 2026-11-21 (dal faz-oto-B11-slayt4).
2. ~~**Formül kapsamı**~~ — LAMBDA ailesi Türkçe adları yapıldı 2026-11-21 (KARAR; Microsoft tr-TR
   alfabetik liste: MAP = HARİTA, MAKEARRAY = DİZİOLUŞTUR, öbürleri Türkçe Excel'de de İngilizce;
   ÖNCEKİMETİN/SONRAKİMETİN eklendi — HAFIZA 2026-11-21 "B10 excel4").
   TOCOL/TOROW/WRAPROWS/WRAPCOLS bulutta yapıldı 2026-11-19 (Türkçe SÜTUNA/SATIRA/SATIRSAR/SÜTUNSAR
   hipotez — Türkçe Excel'de doğrulanmadı).
3. ~~**Veri doğrulama**~~ — bulutta yapıldı 2026-11-19 (aralık/ad/x14 liste, özel formül, başvurulu
   sınır, Durdur/Uyarı/Bilgi, öznitelik korunumu; `test/excel_validation_test.dart`). Giriş
   iletisinin (`prompt`) hücre seçilince gösterimi de yapıldı 2026-11-22 (`formula_bar.dart`
   `_validationPromptBanner`, 15db5fe3); cihaz turu `docs/CIHAZ_TESTI.md` §9.
4. ~~**Otomatik + hızlı doldurma**~~ — bulutta yapıldı 2026-11-19 (tutamak serisi zaten vardı; eklenen:
   tarih/saat BİÇİMLİ hücrede gün/saat adımı, aynı günlü tarihte ay adımı, biçimin taşınması; Veri →
   "Hızlı doldurma" + Ctrl+E; `test/sheet_fill_series_test.dart`, `test/flash_fill_test.dart`). Cihaz turu
   `docs/CIHAZ_TESTI.md` §9.
5. ~~**Süzgeç/sıralama 2**~~ — yapıldı 2026-11-21 (dal faz-oto-B10-excel4): içerir / ilk-son 10 /
   renge göre; ölçüt + sıralama `autoFilter` içine (`filterColumn` + `sortState`). Artık da yapıldı
   2026-11-21 (dal faz-oto-B10-acilis): dosyadaki süzgeç ölçütü okunur, renk süzgeci `dxf` ile yazılır.
7. ~~**Hücre düzenleme hissi**~~ — 2026-11-21 önce-bak: Enter/Tab/Tab-dönüşü, sayısal tuş takımı,
   dokun-seç/ikinci dokunuş-düzenle, yalnız değer/biçim/devrik zaten vardı; `readAsBytesSync`
   izolatta (`_readAndParse`, B12). Eklenen: "Yalnız formülleri yapıştır".
8. **Açılış hızı:** görünür pencere önce (B13 m.4) ve ayrıştırma izolatta (B12 m.2) VAR. Ölçüm:
   `large_file_test` "ilk pencere" (perf kapısı, PERF `xlsx_head_100k_ms`). **Kök (koddan):**
   `XlsxStream.read` hücre tavanı 800 iken de sayfa XML'ini + sharedStrings'i önce TAMAMEN geçici
   dosyaya açıyor (`_unpack`) → baş okuması dosya boyuyla büyür (CI 2026-11-21: 100 bin satır baş 445 ms,
   tam 1669 ms). **Yapıldı 2026-11-21** (dal faz-oto-B10-acilis): tavan < 100 bin hücrede blok blok
   açma (dart:io zlib, tavan dolunca durur) + tembel dizeler → baş 38 ms; tam okuma eski yolda
   (887 ms, 300 bin 926 ms — CI 44917945129). Cihaz A/B → C2 ("büyük xlsx ilk pencere").

**Bitti:** 1–8 testli, `excel_roundtrip_test` yeşil, C2'ye "Excel A/B".

### 1.11) B11 ayrıntısı — Slayt 2.0

Çekirdek: `lib/services/pptx_render.dart`, `services/pptx/`; ekran `screens/editors/slides*`,
`slideshow*`. Her madde ayrı commit.

1. **Görsel sadakat:** sentetik pptx korpusu (gradyan dolgu, gölge, yansıma, döndürülmüş metin kutusu,
   `normAutofit` fontScale, çok düzeyli madde, tema yazı tipleri, tablo stilleri) → `pptx_render` altın
   görüntüleri + fark eşiği. Önce bak: `test/` altında slayt altın testi var mı. **Durum 2026-11-26:**
   dikey metin (1c068e3f) + yansıma çizimi (`a:reflection`, aşağı doğru, bulanıksız; dal faz-oto-K1-kuyruk)
   yapıldı; piksel altın testi YOK — kullanıcı izniyle yerelde.
2. ~~**Grafik türleri**~~ — yapıldı 2026-11-21 (dal faz-oto-B11-slayt4): `SlideChartKind` = `XlsxChartKind`, XML `XlsxChartWriter.chartXml` ortak, tür seçici `ChartKindChips` ortak; `test/slides_chart_kinds_test.dart`.
3. **Geçiş + animasyon (plan evresi fable):** dosyadaki `p:transition` türleri sunumda oynasın (hangileri
   oynuyor önce bak), giriş/çıkış/vurgu animasyonu temel seti (`p:timing`: görün, kay, yaklaş, sil, dön),
   önizleme düğmesi; "Biçim değiştir" (Morph) temel: aynı adlı şekiller arasında konum/boyut/renk ara
   geçişi. 60 fps hedefi `RepaintBoundary` + önceden rasterize (var).
4. **Yerinde metin düzenleme:** şekle çift dokun → imleç doğrudan metinde; klavye açılınca slayt kayar
   (yazılan satır görünür); `normAutofit` canlı (yazdıkça punto küçülür).
5. **~~Tasarımcı (AI)~~ — İPTAL (B15 kararı 2026-11-19: AI özellikleri budandı).** Eski metin: seçili slayt için 3 düzen önerisi (`PptxTemplates.suggest` + Gemini),
   önizlemeyle uygula; AI kapalıyken yerel kurallar (başlık + maddeler → iki sütun vb.).
6. **Notlar + prova:** konuşmacı notu yazma, prova kipi (slayt başı süre → `advTm`), sunumda büyük not.
7. **Sadakat bekçisi:** dokunmadan kaydet = parçalar birebir (SmartArt veri parçaları, gömülü yazı
   tipleri, medya, özel XML) — `slides_roundtrip_test`.
8. **Sürükleme bütçesi:** şekil sürüklerken yalnız seçili şekil yeniden çizilsin — kurulum/çizim sayısı
   (`slides_perf_test` genişler); sunumda geçiş karesi bütçesi.

**Bitti:** 1–8 testli, altın + roundtrip yeşil, C2'ye "Slayt düzenleme/sunum A/B".

### 1.12) B12 ayrıntısı — Hız 2.0 (cihazsız kanıtlı) — **BİTTİ (bulut 2026-11-18, dal faz-oto-B12-hiz2)**

Kalan yalnız cihaz A/B → §1.8 C2 "B12 hız A/B". Ayrıntı HAFIZA 2026-11-18 "B12". Bekçiler: m.1
`sync_io_guard_test` (senkron G/Ç dosya başına tavan), m.2 `open_parse_isolate_test` (açılış/taslak
izolatta), m.3 `rebuild_probe` + editör `*_perf_test` (yeniden kurulum), m.4 `image_cache_guard_test`
(boysuz çözme yok), m.5 `startup_budget_test` (`runApp` öncesi await 6), m.6 `list_extent_ratchet_test`
(sabit satırlı liste ≥ 11: tablo görünümü `itemExtent`, çalma listesi `prototypeItem`), m.7
`unused_dependency_guard_test` (her pubspec paketi `lib/`de içe aktarılır; 3 gerekçeli istisna —
taramada kaldırılacak paket/varlık çıkmadı).

### 1.13) B13 ayrıntısı — Deneyim hissi (akıcılık · dokunuş · geri bildirim)

İlkeler `docs/arsiv/planlar/FERRARI_PLANI.md` §1; tokenlar `Motion.of`, `AppHaptics`, `Gap/Radii/AppType`;
görünür her değişiklikte `kasma-kontrol`; görünüş değişmeden önce eski kullanıcı kararları `grep`.

1. **Açılış geçişi (FERRARI H1.5/H6.3):** dosya satırından görüntüleyiciye `Motion.medium` büyüyen geçiş
   (paket eklemeden kap dönüşümü) — PDF, Word, Excel, Slayt, görsel; azaltılmış harekette düz solma.
2. **Öngörülü geri:** manifest `enableOnBackInvokedCallback="true"` var; temada öngörülü geri sayfa
   geçişi (Flutter 3.47'de hazır kurucu var mı önce bak) + levhalar geri hareketiyle kapanır.
3. **Dokunuş haritası:** aynı eylem = aynı titreşim (seçim değişimi hafif tık, uzun bas orta, silme/hata
   uyarı, sürükle-bırak oturma hafif); bekçi: ham `HapticFeedback.` yalnız `AppHaptics` içinde.
4. **Aşamalı açılış:** Office belgesinde boş ekran/çark yerine iskelet → ilk sayfa → tam (B12.2 ile);
   ilerleme yazısı yalnız > 1 sn.
5. **Her yerde geri al:** silme, taşıma, yeniden adlandırma, toplu işlem, editörde büyük değişiklik →
   5 sn "Geri al" şeridi; eksik yerlerin envanteri + bekçi (silme yolları).
6. **Otomatik kayıt + kurtarma:** Word/Excel/Slayt/PDF düzenlemede boşta taslak (`viewer/pending_save.dart`
   var — kapsamı bak), çökme sonrası "Kaydedilmemiş değişiklikler kurtarıldı"; üst çubukta sessiz
   "Kaydedildi ✓".
7. **Hareket eşitliği:** Word/Excel/Slayt'ta iki parmakla yakınlaştır + çift dokunuşla sığdır/geri, PDF
   ile aynı his (sınırda yaylanma, ivmeli kaydırma).
8. **Klavye:** editörlerde klavye açılırken içerik zıplamaz (imleç satırı görünür), araç çubuğu klavyenin
   üstüne yapışır, kapanınca konum korunur — widget testi (`viewInsets` değişimi) + kurulum bütçesi.
9. **Erişilebilirlik (H12.3'ün cihazsız kısmı):** `androidTapTargetGuideline` (≥ 48 dp) ve
   `textContrastGuideline` widget testleri ana ekranlarda; çok büyük yazıda taşma testleri.

**Bitti:** testli, `kasma-kontrol`, C3'e "his turu: geçiş, geri, titreşim, klavye" maddeleri.

**Durum (yerel 2026-11-19, dal faz-oto-B13-his, dilim 1):** m.2 H6.6'da yapılmıştı (levhalar rota → geri
hareketi kapatır). m.3 yapıldı (`AppHaptics.longPress/drop/warning` + bekçi). m.5 yapıldı (envanter: çöpe
atma/taşıma/adlandırma zaten Geri al'lı; Önemli kategori silme ayardan bağımsız KALICIYDI → çöp + Geri al,
kategori adlandırma Geri al; bekçi `undo_paths_guard_test`). m.6 Faz 20 ED2'de yapılmıştı (taslak günlüğü,
"Kaydedilmemiş değişiklikler geri yüklendi", kabukta "Kaydedildi 14:32"; PDF `pdf_edit_recovery`). m.8:
Excel/Slayt/Word klavye üstü çubuk testleri vardı; Word'de klavye açılınca imleç gizleniyordu → düzeltildi +
test. m.9 Faz 16 `a11y_guidelines_test` 10 ana ekranda vardı (pano Ahem taşması yüzünden dışarıda).
**Kalan:** m.1 Office/PDF açılış geçişi (H6.3 kararı: H1.4 cihaz ölçümüne bağlı, PDF kabuğu ölçümü sürüyor),
m.4 Excel/Slayt iskelet → ilk sayfa (Word B9 m.8'de yapıldı), m.7 Word/Excel/Slayt çimdik + çift dokunuş.
**Durum (yerel 2026-11-19, dilim 2):** m.4 yapıldı — Slayt: tam ayrıştırmayla aynı anda ilk 3 slaytın çizimi
(`PptxEditor.headViews`, deste ≤ 3 ise yok) salt okunur; Excel (≥ 1 MB): akış okuyucusu ilk 800 hücre, düz ızgara
(ham değer, ilk sayfa); ortak `OfficeLoadingPreview` (Word de): açıklama yazısı yalnız > 1 sn. m.7: Excel ve Slayt'ta
çimdik zaten vardı (`PinchZoomArea`); Word'de YOKTU → aynı bileşene alındı (1,0–2,2, düğmeler aynı ölçeği sürer).
**KARAR (sabah bakılacak):** çift dokunuşla sığdır/geri EKLENMEDİ — Word'de çift dokunuş sözcük seçer, Excel'de
hücre/doldurma tutamağı, Slayt'ta şekli düzenler; üçünde de mevcut hareketle çakışır (en güvenli: dokunma).
Kenarda yaylanma/ivme PDF'le eşitlenmedi (kaydırma fiziği ölçümsüz değiştirilmez). **Kalan:** m.1.
**m.1 (yerel 2026-11-20, dal faz-oto-B13-acilis, Huawei tablet A/B 3+3):** dokunulan satır şeridinden (64 dp)
tam ekrana büyüyen kırpma (opaklık yok, bitince kırpma kalkar) denendi → KALDI: Slayt açılışı 314→354 ms,
Excel 293→342 ms, Slayt açılış build p99 20→34 ms (PDF/Word değişmedi ya da iyileşti). Kod uygulanmadı;
ölçüm senaryosu `acilis_gecis` kaldı (tablo `docs/perf/2026-11-20-ab-c136fd2-56f885b.md`). Yeniden denemek
için önce Slayt/Excel'in ilk karelerinde neyin uzadığı zaman çizelgesinden bulunmalı (sabah bakılacak).
**Durum (yerel 2026-11-26, dal faz-oto-B13-his):** main'de yeniden doğrulandı — m.2–m.9 kodda (AppHaptics, Geri al
bekçisi, taslak kurtarma, `OfficeLoadingPreview`, Word `PinchZoomArea`, `a11y_guidelines_test` + 2,0× taşma).
Telefonsuz madde kalmadı; B13 satırı Kuyruk'tan silindi. m.1 → C2 madde 10 (önce zaman çizelgesi); m.4/m.7
A/B → C2; his turu → C3. Açık kararlar (sabah bakılacak): çift dokunuşla sığdır eklenmedi (mevcut hareketle
çakışır), kenar yaylanması PDF'le eşitlenmedi (ölçümsüz fizik değişmez), pano a11y testinde yok (Ahem taşması).

### 1.8) Cihaz paketleri (C1–C3) — telefon bağlıyken yerelde

- Taban = önceki `[apk]` profil derlemesi, ölçüm kimliği `.r8test`; eşikler §0/8 (gerileme > %10 ya da
  p99 > 24 ms → birleşmez). Senaryolar: `tool/perf_senaryo.sh`, `tool/pdf_profil.sh`; ayrıntı `ab-olcum`.
- **C1:** P08 (DEVIR.md senaryosu), P28 (A/B yarım: 1+1 tur kaldı, gözle bakılmadı), P07 (CIHAZ_TESTI "Ferrari H1.4 + H8.5").
- **C2** (bulutun ölçümsüz `[apk]`'ları dahil: her B9–B13 birleşmesi buraya "ölçülmedi" satırı yazar):
  P13 (klasor_5000 p99 23,5→38,9; B3.3c Fotoğraflar donması; soğuk açılış ≤ 1,2 sn), P12 (10k×20
  ≤ 1,5 sn, K23 FrameTiming %99), P14 (`word_300_menu`/`_kapanis`, K21–K22), P04 (2 tur, gürültü şüphesi;
  K6–K7) + **2026-11-18 işleri:** ana ekran "Son açılanlar/Yeni gelenler" sekmesi ve `smart` kutusu, liste
  satırında akıllı ikinci ad, galeride QR düğmesi (kaydırırken kasma yok mu); Akıllı düzen
  kullanıcı kategorisi süzgeci (dosya listesi süzgeç sayımına kullanıcı kategorisi eklendi — kategori
  yoksa tek karşılaştırma; bulut 2026-11-18, dal faz-oto-B1-duzen2, ölçülmedi).
  **Akıllı düzen doğruluk tezgâhı** (bulut 2026-11-18, dal faz-oto-B1-duzen2; ölçülmedi): Geliştirici →
  "Doğruluk ölçümü"nde ~100 kendi dosyanı etiketle → "Eksiklere sor" → kapı kategori ≥ %90, alt tür ≥ %80;
  "Raporu kopyala" çıktısı (dosya adsız) `docs/ai/<tarih>-dogruluk.md`; kapı geçmezse şema/talimat düzeltmesi
  B1'e satır.
  **Akıllı düzen 2.0 hız/kota** (bulut 2026-11-19, dal faz-oto-B1-duzen2; ölçülmedi): 14 MB görselli turda
  ana izlek kare süresi (base64/JSON/maske izolatta), liste satırında ikinci ad maliyeti (ÖLÇÜM KAPISI);
  bir haftalık günlük istek/429 sayısı (Akıllı düzen → "Günde en çok" satırı) → varsayılan 200 doğru mu;
  2 dk+ videoda ilk dakika kesiti süresi/boyutu. Tezgâh ya da A/B kırmızıysa B1'e yeni satır.
  **B12 hız A/B** (bulut 2026-11-18, dal faz-oto-B12-hiz2; ölçülmedi): eski .xls/.doc açılışı, Word/Excel/Slayt
  taslaktan geri yükleme, sesli kitap hazırlığı (ana izlek kare süresi); Word editöründe resimli belge kaydırma
  + bellek, galeride bozuk/kurtarılan görsel, aktarım teklifi küçük resimleri. **B12 m.1/m.5** (ölçülmedi):
  soğuk açılış; **ölçümle taşınacak senkron G/Ç** (`sync_io_guard_test` tavanı): ana ekran başlangıç klasörü
  `existsSync`, pano + dosya seçici Önemli kutusu ve `downloadsPathIn` (`build` içinde stat), galeri bilgi
  satırı `statSync` + iyileştirme kopyası `existsSync`, PDF kabuğu okuma konumu `lengthSync`. **B12 m.3**
  (bulut 2026-11-18, ölçülmedi): uzun Word belgesinde yazma kare süresi (paragraf metni önbelleği), Word
  resim ekle/sil donması; **PDF sayfa değişimi** tüm görüntüleyiciyi yeniden kuruyor (`body.dart`
  onPageChanged setState) → sayfa bildirimcisi + dar dinleyici adayı, önce kaydırma kare A/B.
  **B12 m.6** (bulut 2026-11-18, ölçülmedi): CSV/tablo görünümünde 2.000 satır yukarı kaydırma kare p99;
  dosya listesi dışı ölçüm kapılı adaylar: **dosya seçici** ve **çöp kutusu** (`FmEntryRow` + başlık/ayraç
  karışık), klasör seçici (izinsiz satırda alt yazı) — sabit boy ancak ölçümle.
  **U1 Geçmiş görsel açılışı** (yerel 2026-11-19, dal faz-oto-U1-gecmis-gorsel; ölçülmedi — tablet kurulum onayı):
  Geçmiş > Açılanlar listesinden fotoğrafa dokun, açılış geçişi + ilk 1 sn kare p99 (taban ↔ aday); kapanınca liste sırası.
  **B9 Word 2.0 m.1** (bulut 2026-11-19, dal faz-oto-B9-word2; ölçülmedi): içerik denetimli / form alanlı Word
  belgesinde açılış ve yazma kare süresi (blok denetim artık satır satır paragraf; form alanı dokunulabilir öğe).
  **B9 Word 2.0 m.2/m.5** (bulut 2026-11-19, dal faz-oto-B9-word2; ölçülmedi): çok dipnotlu belgede kaydırma/yazma
  kare süresi (not numaraları belge sırasıyla, değişiklikte yeniden sayılır); İçindekiler oluştur/güncelle süresi büyük belgede.
  **B9 Word 2.0 m.3** (bulut 2026-11-19, dal faz-oto-B9-word2; ölçülmedi): değişiklikleri izle açıkken yazma kare süresi
  (her harf izleme işaretli; silme XML düğümü üretir) ve izlenen eklemeli büyük belgede açılış.
  **B9 Word 2.0 m.8** (bulut 2026-11-19, dal faz-oto-B9-word2; ölçülmedi): 300+ sayfalık belgede dokunuştan ilk okunur
  kareye süre (baş önizlemesi gerçek biçimle; tam ayrıştırma ile aynı anda iki izolat) ve önizleme→editör geçiş karesi.
  **B13 m.4/m.7** (yerel 2026-11-19, dal faz-oto-B13-his; ölçülmedi): 50+ slaytlık deste ve ≥ 1 MB xlsx'te dokunuştan
  ilk okunur kareye süre (iki izolat aynı anda — tam açılış gecikmesin, ≤ %10) ve önizleme→editör geçiş karesi;
  Word'de çimdik sırasında kare p99 ≤ 24 ms (`word_300` belgesi).
  **B9 Word yazma hissi A/B m.7** (bulut 2026-11-19, dal faz-oto-B9-word2; ölçülmedi): bağlamsal klavye çubuğu (seçim
  değişince öğe takımı değişir) + her tuşta otomatik biçim kuralı; yazma kare süresi ve seçim aç/kapa karesi.
  **B9 Word 3 m.4** (yerel 2026-11-21, dal faz-oto-B9-word3; ölçülmedi): yorumlu belgede (`word_300` + 50 yorum) kaydırma ve
  yazma kare p99 ≤ 24 ms (yorum balonu paragraf altında).
- **C3:** **B13 his turu** (dal faz-oto-B13-his, cihazda doğrulanmadı): titreşim haritası (uzun bas orta ·
  bırakma hafif · hata uyarı · seçim tık), Önemli kategori sil → çöp + Geri al, Word'de alt satıra dokunup
  klavye açılınca satır görünür + kapanınca yerinde, öngörülü geri levhalarda; büyük sunum/tabloda ilk slayt/satır önizlemesi, Word'de iki parmakla yakınlaştırma (CIHAZ_TESTI B13). P11 genel tur + K20–K28; Arapça OCR, AI hızlı/toplu kontrol, paylaşım kalkanı, Akıllı düzen ve
  Ayıkla maddeleri (CIHAZ_TESTI 2026-11-18); Akıllı düzen Word/Excel/sunum/metin/APK ikinci adları
  (bulut 2026-11-18, dal faz-oto-B1-duzen2); Akıllı düzen kullanıcı kategorileri ("Dene", uygula,
  süzgeç/arama/ikinci ad — CIHAZ_TESTI 2026-11-18); Akıllı düzen hız/kota + ilk slayt görüntüsü
  (yalnız Wi-Fi, günlük sınır, büyük video kesiti — CIHAZ_TESTI 2026-11-19); Word form alanları ve
  içerik denetimleri (doldur, kaydet, Word'de aç — CIHAZ_TESTI 2026-11-19 B9); Word İçindekiler + dipnot/sonnot
  (CIHAZ_TESTI 2026-11-19 B9 m.2/m.5); Word değişiklikleri izle (CIHAZ_TESTI 2026-11-19 B9 m.3); Word büyük belge açılışı (CIHAZ_TESTI 2026-11-19 B9 m.8). Word 3 (yorum balonu, izlenen Enter/birleştirme/biçim, tablo satır denetimi, PDF dipnot — CIHAZ_TESTI 2026-11-21 B9).

---

## 2) Bilinçli kapsam dışı (yapılmayacak)

- "Verilerimi sil"e kayıtlı bağlantı/anahtar seçeneği (bilinçli dışarıda).
- Eski sürüme dönülürse Keystore sarılı sırlar okunamaz, kullanıcı yeniden girer (bilinçli ödün).
- AI'da tek belgelik maske kapatma (G10.2) — korumayı gevşettiği için yapılmadı (istenirse §3 K12).
- Başka uygulamaya sürükle-bırak (eklenti gerekir). Eski liste: `docs/arsiv/planlar/KALANLAR.md` "Bilinçli kapsam dışı".

---

## 3) Senin işlerin 👤 — Play'e Çıkış İçin Tek Paket (Sırayla Yapılacaklar)

Aşağıdaki liste `yayin_rehberi.md`, `SURUM_ADAYI.md`, `SURUM_PLANI.md`, `izin_beyanlari.md` ve eski K-maddelerinin tek yerde birleştirilmiş hâlidir. Biteni bana söylemen yeterli, listeden silerim.

### A. Hukuk, Hesap ve Güvenlik (Yayın Öncesi Zorunlu)
1. **Syncfusion Community License al:** Yıllık brüt gelirin < 1 Milyon USD ve çalışan ≤ 10 ise ücretsizdir; Syncfusion sitesinden başvurup lisans belgesini indir ve sakla (eski K38).
2. **Google Play Console hesabı + Ödeme/Satıcı profili aç:** Bireysel geliştirici hesabı (25 USD) + kimlik doğrulaması + ücretli Pro satışları için banka/IBAN/vergi profilini tanımla (eski K37).
3. **Destek ve güvenlik e-postası belirle:** Uygulama içi hata bildiriminde, Gizlilik Politikası'nda ve Play Console iletişiminde kullanılacak aktif bir e-posta ver (`kSupportEmail` + `SECURITY.md`, eski K32).
4. **Gizlilik politikasını herkese açık internete koy + depoyu Gizli (Private) yap:** Güncel Türkçe/İngilizce/Arapça gizlilik metinlerini GitHub Pages veya kendi alan adına koy (çünkü kod deposunu ticari çıkış öncesi Private'a alacaksın); GitHub güvenliği için 2 adımlı doğrulama ve `main` dal koruması aç (eski K34).
5. **İmza anahtarını yedekle ve GitHub'a tanıt:** Yayın imza anahtarını (`release.jks`) + parolasını iki ayrı çevrimdışı yere (şifreli USB + kâğıt) yedekle; SHA-256 parmak izini GitHub Ayarları'na (`SIGN_CERT_SHA256`) ekle; Play Console'da *Play App Signing* aç (eski K33, K35).

### B. Sabitlenen Ürün Kararları (2026-11-26) ve Kalan Arayüz Tercihlerin
6. **İş modeli (K15 — KESİNLEŞTİ 2026-11-27; eski K15b "ayrı Pro uygulaması"nın yerine):**
   - **Tek uygulama:** Lite ile Pro AYNI uygulama. Lite ücretsiz (reklamsız, tüm dosyalara erişim ve temel okuma/yönetim açık); Pro özellikler `PRO` rozetli/kilitli görünür, dokununca Pro sayfası açılır ve **tek seferlik uygulama içi satın alımla** (Play Billing yönetilen ürün `pro_unlock`; Türkiye **29,99 TL**, diğer ülkelerde yerel fiyata göre ör. `$0.79` · IDR · MYR) açılır. "Satın almayı geri yükle" düğmesi var; kilit Play kaydına bağlı.
   - **Ayrı ücretli Pro uygulaması mağazaya ÇIKMAZ** (CI'daki `edition=pro` derlemesi yalnız iç deneme). Abonelik **yalnızca** 500 dosyalık başlangıç hakkı üstündeki ekstra Akıllı Klasör bulut kotası içindir (K15a, ayrı).
   - **Ana ekran & izinler (K15c/K16 — KESİNLEŞTİ):** Mevcut tam pano düzeni korunur (ayrı sade mod yok) ve hem Lite hem Pro dosya görüntüleme/inceleme için tüm dosyalara erişim desteğini korur.
7. **Pro satın alım ürünü (K15):** Play Console → *Para kazanma → Ürünler → Uygulama içi ürünler* → yönetilen ürün kimliği **`pro_unlock`** aç, Türkiye için **29,99 TL** ve diğer ülkeler için kendi yerel fiyatlarını tanımla (ör. ABD/global USD için `$0.79`, Endonezya IDR ve Malezya MYR için yerel kademe — uygulama ekranda doğrudan Google Play'den gelen ülke fiyatını gösterir), etkinleştir. Doğruysa: iç test kanalında Pro sayfasındaki "Satın al" Play ödeme penceresini ve o ülkenin fiyatını gösterir, satın alınca açık kilitli sayfa dahil tüm rozetler anında kalkar; lisans test hesabıyla iptal/bekleyen ödeme/"geri yükle" denenir. Yanlışsa (başka kimlik açtıysan): kimliği bana yaz, `ProPurchase.productId` sabiti değişir.
7a. **Akıllı klasörler ekstra kota paketi / abonelik fiyatları:** Pro içindeki 500 dosya başlangıç hakkı sonrasında Play Store'da satılacak ekstra Akıllı Klasör paketinin veya aboneliğinin aylık/paket fiyat kademelerini belirle. Play Console'da bu ürünün kimliğini (abonelik ya da tüketilebilir kredi) aç ve bana yaz — Billing altyapısı Pro satın alımıyla geldi (K15); bu abonelik ürünü + sunucu (K15a) kararı gelince eklenir.
7b. **Model indirme aynası (B7b/4, isteğe bağlı):** sesli kitap sesleri (Hugging Face/jsDelivr) ve görsel büyütme modeli (tfhub.dev) bugün üçüncü parti sunuculardan iniyor. Kararlı olsun istersen kendi aynanı kur (ör. Cloudflare R2 / GitHub Releases), dosyaları `<ayna>/<özgün host>/<özgün yol>` düzeninde koy, GitHub → Settings → Variables → `DOSYA_MODEL_AYNA` = ayna kökü. Doğruysa: sonraki derlemede indirme önce aynadan gelir (SHA-256 aynı kalır). Yanlışsa/erişilemezse: uygulama kendiliğinden özgün kaynağa döner.
8. **Google Drive & OpenSubtitles & Notlar (K9, K36):** Play sürümlerinde Drive tamamen kapalı mı kalsın, yoksa ücretsiz onaylı kısıtlı kapsam (`drive.file`) eklensin mi? `Notlar` uygulaması Play'de yayına girdiğinde haber ver, mağaza kartını açalım.
9. **Arayüz/Tasarım Tercihlerin (tek kelime yeterli — K1–K7, K17, K19, K14):**
    - PDF *Daha fazla* menüsünü ilk 5 madde + *Diğer* olarak sadeleştirelim mi (`K1`)? Galeri alt çubuğunu 5 ana düğmeye indirelim mi (`K6`)?
    - Ana ekranda varsayılan görünüm hangisi olsun (Sakin / Bento / Koyu başlık) ve kutu adları cümle düzenine geçsin mi (`K19`)?
    - Çift bölmede sürükle-bırak kopyalasın mı taşısın mı (`K5`)? Çöp kutusu silme onayı kapalı kalsın mı (`K2`)? Kopyalandı bildirimi Android 13+'da çift görünüyorsa kapatalım mı (`K4`)? Editörde Kaydet düğmesi sadece değişiklik varken görünsün mü (`K7`)?
    - Levha/pencere birleştirmelerinde görsel onay (`K17`) ve GitHub bağımlılık güncellemeleri (`K14`) onaylı mı?


### C. Mağaza Sayfası, Video, Gerçek Telefon Kontrolü ve Lansman
    - **P22b PDF okuma eklentileri (K41, 2026-11-27):** tutamaçta sayfa önizlemesi + "N. sayfaya dön" düğmesi dal `faz-oto-B4-p22b`'de hazır. 2 tur A/B: PDF açılışı artık yeşil, ama PDF geçişlerinde kare kurulum p99 8 ölçümün 4'ünde 24 ms'yi aştı (tabanda hiç); aynı koşularda P22b'nin dokunmadığı slayt geçişinde de 121 ms takılma var (gürültü şüphesi) — docs/perf/2026-11-27-P22b-ab2.md. Seçenek: (a) bir tur daha yalnız geçiş ölçümü, (b) varsayılan KAPALI bayrakla birleştir, (c) bırak.
10. **Ekran görüntüleri ve 2 kısa Play izin videosu çek:**
    - Telefon & tablette TR/EN/AR ekran görüntüleri al.
    - Hem Lite hem Pro sürüm `Tüm dosyalara erişim` istediği için Play incelemesinde istenen YouTube *Liste Dışı* 2 kısa ekran kaydı yükle: (1) açılışta izin istemeyip dosya yöneticisinde nasıl izin istendiği (~30 sn), (2) arka planda dosya taşıma/müzik bildirimi (~20 sn).
11. **Play Console formlarını doldur:** İçerik derecelendirmesi (PEGI 3 / 13+ veya 18+ hedef kitle, reklam yok), `veri_guvenligi.md` tablosuna göre Veri Güvenliği formu ve `izin_beyanlari.md` metinleriyle izin formu.
12. **Gerçek telefonda hızlı kontrol turu (K20–K28, K30, K39):** PDF Türkçe yazı/kaydetme/WhatsApp kopya açma, Word klavye/çimdik ve kapanış, USB takılıyken büyük PDF, menülerdeki Sil/Kaydet düzeni, Drive/SFTP hesabınla test, ve düzenlenmiş Word/Excel/PDF çıktılarını Microsoft Office/Acrobat'ta açıp bakma; ayrıca Android 7 telefon varsa kasa açılma süresi (`K11`) ve TalkBack açıp ekran okuyucu denemesi (`K25`).
13. **48 Saat İç Test → 14 Gün Kapalı Test → Kademeli Yayın:**
    - Üretilen imzalı mağaza paketini önce İç Test'e atıp Play *Ön Lansman Raporu*'nda (Pre-launch) hata olmadığına bak.
    - Bireysel hesapta 12–20 testçinin **14 gün aralıksız** kapalı testini tamamla (çökme `< %1.09`, yanıt vermeme `< %0.47` altında kalmalı).
    - Önce **%10–%20** kademeli dağıtımla çık, metrikler temizse **%100**'e aç; ilk 100 mağaza yorumuna aynı gün yanıt ver.

### D. Endonezya + Malezya (B17, kullanıcı 2026-11-26 — kod işlerinin sonunda)
14. **Mağaza, fiyat, hukuk:**
    - Play mağaza sayfası Endonezce + Malayca (başlık, kısa/uzun açıklama, ekran görüntüleri metni); anahtar sözcük
    araştırması ("pembaca PDF", "baca dokumen", "pembaca fail PDF").
    - Yerel fiyat: Play'de Türkiye'deki 29,99 TL karşılığına bağlı kalmadan ülkeye göre bağımsız düşük fiyat kademesi belirle (ör. USD ülkelerinde `$0.79`, Endonezya IDR ve Malezya MYR için alım gücüne uygun düşük yerel fiyat; uygulama Play Store fiyatını otomatik gösterir); Play bu ülkelerde GoPay, OVO, DANA,
    Touch 'n Go gibi cüzdanları ve operatör faturasını kendisi sunar.
    - Gizlilik politikası Endonezce + Malayca; Endonezya UU PDP (2022) ve Malezya PDPA'ya uygunluk gözden geçirmesi.
    - Lansman: B7 kademeli çıkış ve Android Vitals eşikleri bu ülkelerde de geçerli; ilk yorumlara Endonezce/Malayca yanıt.
    - Çeviri: ana ekran, PDF, Kitaplık, ödeme ve hata metinlerini anadili konuşan biriyle gözden geçir (§1.16 m.2).

### Eski Referans Detayları (Geliştirici Notları)
- K8 (liste hız eşiği), K10 (MobSF/drozer dış güvenlik taraması), K12 (AI tek belgelik maske kapatma — kapalı kalması önerilir), K13 (OneDrive/Dropbox), K15a (sunuculu Akıllı Düzen kredi satışı taslağı), K18 ("tikli öğesi çok notlar kasıyor"), K41–K42 (örnek PDF korpusu) — detayları önceki karar kayıtlarında korunur.

### 1.14) Kullanıcı istekleri 2026-11-19 akşam (limit yenilenince ayrıştırılıp paketlenecek; ekran görüntüleri sohbette)
1. **ÖNCE:** Fotoğraflarda eski görsellere hızlı inip açınca kasma/donma — cihazda ölç, kök nedeni bul (bulutta çözülemedi).
2. Oynatma hızı: ses + video hepsinde tutamaçlı çubuk, 0,05 adım (bugün 6 sabit seçenek).
3. Ana ekran "Son dosyalar": yeni + geçmiş akıllı biçimde TEK karışık liste (bugün önce yeniler sonra geçmiş); "Yeni" etiketi kalsın; sol menüde de aynı; sekmeler kalsın, "Ana ekranı düzenle"den varsayılan kip: Otomatik / Geçmiş / Yeni. Yeniler ve Geçmiş geç yükleniyor → hız.
4. Bildirim bütünlüğü: üstteki iş bildirimi ile altındaki Akıllı düzen şeridi görsel olarak farklı; tüm bildirim/şerit/tost tek görsel dil.
5. Ana ekran altındaki "Ana ekranı düzenle" + "Alt paneli düzenle" → tek düğme (düzenle simgesi), görsel bütünlük.
6. Araçlar: "Bağlantıdan indir" kaldır; "Kopyalar" Analiz'e taşı (ana ekranda gereksiz).
7. Akıllı klasörler: Opus (extra high) beyin fırtınası ajanı — nokta atışı geliştirme, yeni/düzenlenmiş kategoriler, hatalar + düzeltmeler.
8. Ayarlar > Başarım (Otomatik/Hafif/Tam): seçili olan görünmüyor — seçimi göster, anlaşılır yap.
9. Yapay zekâ ayar sayfası yeni duruma göre baştan yazılsın (ana özellik Akıllı klasörler/kategori).
10. Analiz (Bellek Analizi): beyin fırtınası + nokta atışı öneriler, hata düzeltme, geliştirme.
11. Her hata/sonuç/bildirimde son kullanıcıya kısa ve doğru bilgi: ne oldu, ne yapmalı (ör. silince sessizce bir şey olmasın); hepsi tek görsel dil.

### 1.15) B16 ayrıntısı — İnternetsiz Arapça OCR (kullanıcı 2026-11-26)

**Neden:** ML Kit'te Arapça yazı modeli yok (`lib/services/cloud_ocr.dart` başı); Arapça tanıma bugün yalnız
Gemini ile (internet, kullanıcının anahtarı, ücret). Dini kitap/İhya gibi Arapça içerikli belgeler ve B17
(Malezya/Endonezya: Arapça + Cavi) için cihazda, ücretsiz tanıma gerek. Tesseract APK bütçesi yüzünden
reddedilmişti (yerel `.so` + dil verisi APK'ya girer; Play dışarıdan yerel kod indirmeyi yasaklar) — bu yol
ona takılmaz: **indirilen şey kod değil model dosyası**.
1. **Model:** PaddleOCR PP-OCR Arapça tanıma (`arabic_PP-OCRv*_rec`) + metin bulma (det) modelleri, Apache 2.0.
   Mevcut `tflite_flutter` (ESRGAN deseni: ilk kullanımda indir, sağlama toplamı denetle) ya da ONNX Runtime
   (sesli kitap modelleriyle aynı WebView yolu) — plan evresinde ölç: hız, bellek, APK etkisi (hedef +0 MB).
2. **Bağlantı:** `OcrService` sırası → ML Kit (Latin) · **yeni yerel Arapça motor** · Gemini (yalnız kullanıcı
   isterse / yerel sonuç zayıfsa). `OcrScript.arabic` ayarı ve `hasNonLatinScript` otomatik yükseltmesi önce yerel
   motora gider; onaysız buluta gönderim kuralı (HAFIZA 2026-11-25) korunur.
3. **Çıktı:** satır + kutu (`OcrLine`) → aranabilir PDF, taranmış sayfada seçim, otomatik içindekiler
   (`PdfAutoOutline` OCR yolu) değişmeden çalışır. Sağdan sola satır sırası (`orderOcrRows`) denetlenir.
4. **Kalite kapısı:** Arapça örnek sayfalarla (matbu Arapça, harekeli Kur'an metni, Osmanlıca, Cavi) Gemini'ye karşı
   karakter doğruluğu ölçülür; yerel < kabul eşiği ise varsayılan Gemini kalır, yerel "çevrimdışı" seçenek olur.
5. **Sonra (isteğe bağlı):** PP-Structure düzen modeli (Apache 2.0) → taranmış kitapta başlık/paragraf/tablo ayrımı;
   otomatik içindekiler isabeti artar. **Kaçın:** DocLayout-YOLO/ultralytics (AGPL).

### 1.16) B17 ayrıntısı — Endonezya + Malezya pazarı (kullanıcı 2026-11-26)

**Devir notu (2026-11-27, ilk dilim main'de):**
#### Dil yapısı planı (karar 2026-11-27)
- Bugün `_table` = `Map<String,(tr,en,ar)>` (54 dosya, ~6.300 anahtar). Demeti 5'liye genişletmek her satıra
  dokunur (paralel B4 dallarıyla çakışma; 12.600 metin bir anda yazılamaz). Seçilen: **dil başı ek tablo**
  `lib/core/l10n/locales/{id,ms}.dart` (`Map<String,String>`, `part of app_strings.dart`); `AppStrings.t` id/ms
  için önce ek tabloya bakar, yoksa İngilizceye düşer. `strings/` dosyalarına dokunulmaz. Bellek: yalnız eklenen metin.
- Bekçi: `l10n_test` (ek tablo anahtarı ana tabloda, yer tutucu Türkçeyle aynı, düşme, id≠ms) + `on_denetim`.
- Sistem dili id/ms → otomatik (supportedLocales + delegate + Android `locales_config.xml`); eski "in" kodunu
  Dart `Locale` "id"ye çevirir. Cavi: Malezya arayüzü Rumi → ms soldan sağa, arayüzde RTL/yazı tipi gerekmez;
  Cavi içerik B16 OCR + sistem Naskh, ek harfler (ڠ چ ڤ ڽ ݢ ۏ) cihazda (CIHAZ_TESTI B17).
#### Yapılanlar
- m.1 (11c49908): altyapı, seçici, otomatik seçim, dikte id-ID/ms-MY, ML Kit çeviri dilleri, gizlilik ekranı
  id/ms → İngilizce (hukuk metni 👤), akıllı aramada id/ms. 06774691: `ci/res/xml/locales_config.xml`
  (1. CI'da `locale_config_test` kırmızıydı).
- m.2 (11c49908 + a006d2bb): 590 anahtar × 2 dil — ortak, ana ekran, ayarlar, hata, tanıtım, yan menü, dosya
  yöneticisi, dosya işlemleri, USB/SD, PDF/belge görüntüleyici kabuğu.
#### Kalan
- m.3 yapıldı (`faz-oto-B17-ceviri2`): `lib`, `clean`, `pro`, `pt`, `pp`, `pse` (kullanılan anahtarlar).
- m.4 yapıldı (`faz-oto-B17-ceviri3`): `excel`, `word`, `sl`, `xp`, `sp`, `near`, `sm`, `pe` (1.219 anahtar).
- m.5 yapıldı (`faz-oto-B17-ceviri4`): 1.500 anahtar — `enum`, `wp`, `pse`, `mp`, `nas`, `fmset`, `drive`, `set`, `sdu`, `ied`, `rs`, `ss`, `fm`, `ftpd`, `vault`, `dl`, `ab`, `ph`, `skin`, `pf`, `jr`, `pp`, `cj`, `sb`, `clean`, `apk`, `suc`, `apps` (başı). Kalan çeviri: YOK.
- m.6 yapıldı (`faz-oto-B17-ceviri5`): 1.812 anahtar (ct, ocr_studio, smp, apps, foot, ved, vw, upd, link, srch, chart, card, smo, tf, gal, ks ve uzun kuyruk; B4 P20 dahil). Kodda kullanılıp id/ms'de olmayan anahtar = 0. Sonradan eklenen anahtarlar (K15 iç satın alım vb.) ayrıca eklenir.
- Wi-Fi'de model indirme seçeneği (§1.16 m.4) — yapılmadı (2026-09-26 kararı mobil veride indirmeyi açtı).
- Ucuz cihaz ölçümü → C2; cihaz turu `docs/CIHAZ_TESTI.md` B17.
#### Doğrulama
`PYTHONUTF8=1 python tool/on_denetim.py` · CI `verify` (l10n_test, locale_config_test).


**Neden:** satış hedefi kalabalık pazarlar (Endonezya ~280 M, Malezya ~35 M); çoğunluk Müslüman, Android payı
çok yüksek, giriş/orta seviye telefon yaygın, mobil veri pahalı. **Kod:**
1. **Dil yapısı (önce, fable planı):** bugün her metin 3'lü demet `(tr, en, ar)` — 53 dosya, ~6.200 anahtar
   (`lib/core/l10n/strings/`), `enum AppLanguage { system, tr, en, ar }`. 5 dile (+`id` Endonezce, `ms` Malayca)
   genişletmenin yolu seçilecek: demet → dil başı harita ya da dil başı ayrı dosya (APK/RAM bütçesi, `on_denetim`
   çeviri anahtarı denetimi, eksik çeviride İngilizceye düşme). Sistem dili `id`/`ms` ise otomatik seçilir.
2. **Çeviri:** ~6.200 anahtar makine destekli çeviri + yer tutucu (`{n}`) bekçisi; Endonezce ile Malayca yakın ama
   AYRI (ör. "kereta" ≠ "mobil"; Malezya "fail", Endonezya "berkas") — biri ötekine kopyalanmaz. Ana ekran, PDF,
   Kitaplık, ödeme ve hata metinleri anadili konuşan biriyle gözden geçirilir (👤).
3. **Mevcut altyapının uyumu (denetle, büyük ölçüde hazır):** ML Kit Latin OCR Endonezce/Malayca okur; ML Kit
   çeviride `id`/`ms` var; cihaz sesli okumada `id-ID`/`ms-MY` sesleri (`TtsService` dil eşlemesi); tarih/sayı
   biçimi (`intl`, `id_ID`/`ms_MY`); Arapça/Cavi içerik için B16.
4. **Düşük donanım + veri:** 2–3 GB RAM / Android Go telefonlarda PDF/Office açılışı, APK boyutu (bütçe yalnız
   düşer), indirilen modellerin (ses, OCR) yalnız Wi-Fi'de inmesi seçeneği; C-paketinde ucuz bir cihaz ölçümü.
5. **Yerel alışkanlıklar:** WhatsApp/Telegram belge akışı (Sohbet medyası zaten var — kısayol öne), dini PDF/Kur'an
   okuma (Kitaplık + içindekiler + Arapça OCR), devlet/okul formları (PDF form doldurma).

**👤 Senin işlerin:** §3 madde 14'e taşındı (2026-11-26).
