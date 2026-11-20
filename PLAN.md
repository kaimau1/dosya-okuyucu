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

**SIRA (2026-11-18, kullanıcı: "özellikleri geliştirmeye devam — Word, PDF, Excel, slayt; performans,
hızlandırma, akıcılık, kullanıcı deneyimi hissi"):**
- **Kod (bulut ya da yerel):** B1 → B9 → B13 → B10 → B4 → B11 → B2 → B5 → B6 → B7.
- **Telefonla (yerel, paralel; boşaldıkça):** C1 → C2 → B3 → C3. **En son:** B8.

Ferrari kuralı (§0): B3'teki hız işleri (P06, P12b, P29) bitmeden büyük yeni özellik **varsayılan
açık** birleşmez — B1/B2 bayrakla (Akıllı düzen kullanıcı açınca çalışır) birleşebilir.
**Gevşetme (kullanıcı 2026-11-18, "özellikleri geliştirmeye devam"):** B9–B11 editör özellikleri ve
B4 PDF Pro varsayılan açık birleşebilir — koşul: dosya listesi / ana ekran / PDF kabuğunun sıcak
yoluna dokunmaz, dokunulan editörün bütçe testi yeşil, A/B sonra C2'de. C2'de gerileme çıkarsa
(§0 eşikleri) o commit `git revert` ya da düzeltme SIRA'nın EN ÖNÜNE.

| No | Paket | Model | Kaynak | Cihaz | APK | Durum |
|---|---|---|---|---|---|---|
| R1 | **Gerileme: liste kaydırma + slayt açılış (C2 e4a784e9→abf8309b):** 4 ek A/B (tek senaryo + bağlamlı + zaman çizelgesi) — kod kaynaklı gerileme YOK; fark küçük örneklemli p99 + GC denk gelişi (docs/perf/2026-11-20-R1-gerileme.md). Sabah bakılacak: n<100 kareli senaryoda karar ölçütü (en az 3 tur?) | opus | C2 2026-11-20 | A/B | hayır | bitti — dal faz-oto-R1-gerileme |
| B15 | **Akıllı bütünlük + AI budama (kullanıcı 2026-11-19, "reklamımız kategorizasyon"):** (1) kullanıcıya görünen her yerde "AI …" → "Akıllı …" (ör. "AI kategorisi" → "Akıllı kategori", "AI ile ikinci ad" → "Akıllı ikinci ad"); "Gemini …" marka adı menülerden kalkar (ayarlardaki API anahtarı hariç); "Akıllı Düzen/düzen" yazımı tekleşir; hata metinleri tek kalıp. (2) menü/levha/ekran bütünlüğü: aynı iş her yerde aynı ad, aynı simge, aynı sıra, aynı his. (3) BUDA (kullanıcı kararı): AI ile özetle, AI Sohbet (+ AI merkezi sohbeti), Slayt "AI ile hazırla", görüntüleyici/editör "AI ile çalış" menüsü, Benzer dosyalarda "Gemini'ye sor"/en iyi kare, eski "AI ile etiketle"; ayrıca (öneri, sabah bakılacak, geri alınabilir) AI hızlı kontrol, toplu kontrol, kontrol listesi. KALIR: Akıllı düzen/kategori/ikinci ad/klasör/temizlik/anlamla arama, PDF AI düzenle, Word AI yaz, görsel kısa özet + tarama kalite, Arapça OCR, sesli okuma, ayarlar. Kullanıcı verisi (ai_index, kayıtlı özetler) silinmez; ölü kod + çeviri anahtarları + testler temizlenir. (4) sonra kategorizasyonu mükemmelleştirme (doğruluk tezgâhı C2) | opus | bu satır; envanter HAFIZA 2026-11-19 | A/B | evet | sürüyor — dilim 1 (1)+(2)+(3) dal faz-oto-B15-akilli (budama + "Akıllı …" adlandırma + aynı simge; A/B C2'de, ölçülmedi); kalan (4) kategorizasyon + sabah bakılacak: hızlı/toplu kontrol ve kontrol listesi öneriyle budandı (geri alınabilir: git revert), Ayarlar'daki "AI Kalıcı Hafıza" artık hiçbir işte kullanılmıyor (notlar silinmedi) |
| G1b | **Fotoğraflar ilk savurma karesi:** ekran açıldıktan sonraki İLK savurmada tek 110–135 ms kare (LAYOUT içinde tek BUILD; tablette ölçüldü, docs/perf/2026-11-20-G1-galeri-acilis.md) — kök bul, düzelt, A/B | opus | G1 kalanı | A/B | evet | bekliyor |
| U4 | **Akıllı klasörler + Analiz + Akıllı ayarlar (beyin fırtınası, nokta atışı):** §1.14 m.7, m.9, m.10 + B15 m.4 kategorizasyonu mükemmelleştirme. **Bitti (dilim 1, 7 madde; HAFIZA 2026-11-20 U4):** durma/başlamama iletileri gerçek neden · hayalet kayıt budama · kayıtlı aramalar Akıllı düzeni arar + "Akıllı aramalar" adı + PIN · "Diğer" klasörü · Yapay zekâ ayar sayfası baştan (Hafıza kalktı) · Analiz "Tümünü seç" 200 sınırı · Analiz Kopyalar/Ayıkla. **Bitti (dilim 2, 3 madde; HAFIZA 2026-11-20 U4 dilim 2):** ağ kopunca tur durur (ortak durma kuralı, tezgâh dahil) · bulanık belge fotoğrafı Ayıkla'ya önerilmez (e) · öğrenilen kategori alt türünü/kurumunu korur. **Kalan adaylar (seçilmedi):** (a) klasör kutusunda "+n yeni" rozeti; (b) kutuda ilk dosyanın küçük resmi (ızgara, ölçümle); (c) klasörü ızgaradan gizle; (d) yeni yerleşik kategoriler (ev/tapu/aidat, çocuk/okul, tarif — önce C2 tezgâh ölçümü); (f) Kategorilerim ızgarada klasör (görünüş, kullanıcı kararı); (h) Analiz'de Akıllı kategoriye göre yer ("Faturalar 1,2 GB"); (j) eski Akıllı dosya asistanı (AiIndex analizi) ile Akıllı düzen ikiliği (budama kullanıcı kararı) | opus (xhigh) | §1.14 | A/B | evet | dilim 1 main'de; dilim 2 kod bitti — dal faz-oto-U4-akilli-2 (main'e birleştirilmedi; cihaz turu CIHAZ_TESTI U4.2); dilim 3 (g) Analiz silme sonrası yenilenir kod bitti — dal faz-oto-U4-akilli-3 (main'e birleştirilmedi; cihaz turu CIHAZ_TESTI U4.3); sabah bakılacak: kayıtlı aramaların adı "Akıllı aramalar" (geri alınabilir, yalnız metin) |
| U3 | **Ana ekran + bildirim bütünlüğü:** §1.14 m.2 (hız çubuğu 0,05), m.3 (son dosyalar tek akıllı liste + varsayılan kip + hız), m.4/m.11 (bildirim/tost/hata tek dil, kullanıcıyı bilgilendir), m.5 (tek düzenle düğmesi), m.6 (Bağlantıdan indir kalk, Kopyalar → Analiz), m.8 (Başarım seçimi görünür) | opus | §1.14 | A/B | evet | kod bitti — dal faz-oto-U3-ana-ekran (main'e birleştirilmedi; 7 madde HAFIZA 2026-11-20 U3; cihaz turu CIHAZ_TESTI U3, ölçüm C2 — ölçülmedi); sabah bakılacak: hız aralığı 0,5–2,0 (güvenli seçim; 0,25–3,0 istenirse `PlaybackSpeed.min/max`) |
| B3 | **Hız (Ferrari) kod + ölçüm:** P12b Excel/liste A/B artıkları, P29 büyük başlık + kalıcı hata şeridi, P06 PDF kaydırma H2.1–H2.6 | opus (P06 plan evresi fable) | §1.3; arsiv/FERRARI_PLANI H2 | A/B | evet | sürüyor — dal faz-oto-B3-hiz: P29 kod bitti (main'e birleştirilmedi; büyük başlık H4.2 2026-11-14 kullanıcı kararıyla zaten kalkmıştı — iş yok; hata şeridi kök neden arka plan kapatması, şerit ortak bildirim kartına katıldı; HAFIZA 2026-11-20 B3; cihaz turu CIHAZ_TESTI B3, ölçüm C2 — ölçülmedi); P12b'nin cihazsız kod artığı yok; kalan P12b ölçümü, P06 (plan evresi + cihaz) |
| B4 | **PDF Pro tamamlama:** P16 metin, P17 nesne/işaret, P18 form+imza, P19 OCR Pro, P20 sayfa stüdyosu, P21 parola/meta/optimize/PDF-A, P22 kalite %98 | opus (plan evresi fable) | §1.4; arsiv/PDF_PRO_PLANI 54–68 | A/B | evet | sürüyor — dal faz-oto-B4-pdfpro: bitti P21 meta veri (Belge bilgileri) + P17 XFDF dışa/içe (main'de) + P21 R6 kilit açma/R6 koruma (dilim 2, main'de) + P20 sayfa stüdyosu m.1 çekirdeği (ızgara, seç/döndür/sil/çoğalt/sürükle, geri al; dilim 3, main'de) + stüdyoda boş sayfa / dosyadan sayfa ekle (dilim 4, main'de) + stüdyoda çıkar/böl, görselden/taramadan ekle, kenar kaydırma (dilim 5, main'de; kırpma/boyut/Bates/filigran/yer imi Pro araçlarda zaten var) + P18 düz PDF'te alan algılama (`____`/`.....`/`☐` → etiketli alan; form oluşturma + otomatik doldurma zaten vardı; dilim 6, main'de) + P18 çizilmiş çizgi/kutu/kare sezgisi (dilim 7) + P18 form ekranında imza alanı imzalama + P19 m.1 "Aranabilir yap (OCR)" görünmez katman (dilim 8, dalda); akıllı karartma önerisi iptal (B15: AI aracı eklenmez); kalan P16, P17 (kılavuz/çoklu seçim/OCG/kalem), P18 (serbest imza yerleştirme form ekranına, PdfSignScreen emekliliği), P19 (renkli zeminde satır düzenleme, döndürülmüş sayfa katmanı), P21 (bu kipte yazdır, PdfEditorScreen emekliliği), P22/P22b; DEVIR.md'den sür |
| B5 | **Biçim + bakım + levha birliği:** P23 UDF (UYAP) okuyucu, P24 bağımlılık bakımı, P25 levha/pencere birliği (onay §3 K17) | opus | §1.5 | A/B | evet | sürüyor — dal faz-oto-B5-udf: P23 kod bitti (main'e birleştirilmedi; cihaz turu CIHAZ_TESTI B5, ölçüm C2 — ölçülmedi); kalan P24, P25 (K17 onayı) |
| B6 | **Tasarım tamamlama:** P31 ana ekran aileleri kalanları (D simge takımı, F metinleri, K19), P32 menü ortak düzeni kalanları | opus | §1.6; docs/design/ana_ekran/ | A/B | evet | bekliyor — K19 kararıyla |
| B7 | **Sürümler + yayın:** P30 Lite/Pro/Kişisel (S4–S9, K15/K16), P26 mağaza ekran görüntüleri | opus / sonnet | §1.7; arsiv/SURUM_PLANI | — | evet | kullanıcı kararı — K15 |
| B9 | **Word 2.0:** içerik denetimleri (`w:sdt` bugün tek düz paragrafa iniyor), İçindekiler, değişiklikleri izle, yorum, dipnot, sadakat bekçisi, yazma hissi, büyük belge açılışı | opus | §1.9 | A/B | evet | bulutta: sürüyor (2026-11-19) — dal faz-oto-B9-word2: bitti m.1 (içerik denetimleri + form doldurma), m.2 (İçindekiler oluştur/güncelle), m.5 (dipnot/sonnot ekle/düzenle/sil, numara belge sırasıyla; PDF'te not listesi belge sonunda — sayfa altı yerleşim kalan), m.6 (sadakat bekçisi `word_roundtrip_test`), m.3 (değişiklikleri izle: yazılan `w:ins`, silinen `w:del`, `settings.xml` bayrağı), m.8 (büyük belge açılışı: ilk sayfa önce — baş izolatta ≤ 60 blok çözümlenir, gerçek biçimle salt okunur önizleme; `word_perf_test` bütçesi), dilim 4 main'e gidiyor; m.4 önce-bak: yorum yaz/yanıtla/çözüldü zaten var, kalan yalnız kenar balonu; kalan m.4 kenar balonu, m.7 yazma hissi (+ satır/hücre düzeyi `w:sdt`, izlenen paragraf işareti/biçim değişikliği) |
| B10 | **Excel 2.0:** grafik türleri (bugün 4), formül kapsamı (189 işlev → dizi/metin işlevleri), veri doğrulama, otomatik/hızlı doldurma, süzgeç 2, sadakat bekçisi, hücre düzenleme hissi, açılış | opus | §1.10 | A/B | evet | bulutta: sürüyor (2026-11-19) — dal faz-oto-B10-excel2: bitti m.2 (çekirdek + `_xlpm.` yazımı) + m.3 veri doğrulama + m.6 sadakat bekçisi; dilim 2 main'e gidiyor, kalan m.1, m.2 kalanı (Türkçe LAMBDA adları, TOCOL/TOROW/WRAPROWS), m.4–5, m.7–8 |
| B11 | **Slayt 2.0:** görsel sadakat (altın görüntü testleri), grafik türleri, geçiş + animasyon + Biçim değiştir, yerinde metin düzenleme, AI tasarımcı, notlar + prova, sadakat bekçisi, sürükleme bütçesi | opus (animasyon planı fable) | §1.11 | A/B | evet | sürüyor — dilim 1+2 main'de (m.1 tablo stilleri, m.4 imleç, m.6 prova, m.7 sadakat bekçisi, m.8 sürükleme/geçiş bütçesi); dilim 3 dal faz-oto-B11-slayt3 (m.3 geçiş türleri + efektli animasyon + Biçim değiştir + önizleme, m.1 dikey metin; A/B C2'de); m.5 AI tasarımcı İPTAL (B15 kararı 2026-11-19, AI budandı); kalan m.1 piksel altın (kullanıcı izniyle yerelde) + yansıma, m.2 (B10 m.1 ortak çiziciden sonra), m.4 klavye kayması cihazda |
| B13 | **Deneyim hissi:** açılış geçişi, öngörülü geri, dokunuş haritası, aşamalı açılış, her yerde geri al, otomatik kayıt + kurtarma, hareket eşitliği, klavye, erişilebilirlik | opus | §1.13; arsiv/FERRARI §1 | A/B | evet | cihaz bekliyor — dilim 1+2 main'de (2026-11-19): m.4 Excel/Slayt aşamalı açılış + m.7 Word çimdik yapıldı (A/B C2'de); kalan m.1 açılış geçişi (Office/PDF, H1.4 cihaz ölçümüne bağlı) |
| B8 | **Son kapı:** P27 "10 işlem" son ölçüm + Samsung kıyası, erişilebilirlik, özellik dondurma kalkar | sonnet | arsiv/FERRARI_PLANI H12 | A/B | evet | bekliyor — en sonda, kullanıcıyla |
| C1 | **Cihaz: hazır dalların ölçümü:** P08 PDF Pro bellek (`faz-oto-P08-bellek`), P28 PDF kabuğu (`faz-oto-P28-pdf-kabuk`), P07 son sayfa + döndür (`faz-oto-P07-artik`) → A/B → yeşilse birleştir | opus | §1.8; DEVIR.md | A/B | evet | cihaz bekliyor — P08 (599af0ca) + P28 (6ea65ce5) dallari main birlesik, CI yesil; A/B kosmadi: bagli cihaz Huawei tablet, bilinmeyen kaynaktan yukleme onayi kullanicida (§3); P07 zaten main'de |
| C2 | **Cihaz: perf A/B artıkları:** B2 Akıllı düzen 2.0 dilim 1–5 (CIHAZ_TESTI B2) — ölçüldü: geçti (2026-11-20), P13 liste/ızgara (klasor_5000 p99 23,5→38,9, B3.3c, soğuk açılış) — ölçüldü: kaldı (2026-11-20; klasor_5000 build p99 20,6→46,1 ve 17,8→26,2; soğuk açılış geçti), P12 Excel 10k×20, P14 Word kapanış/menü (K21–K22), P04 boş/hata durumları (K6–K7) + 2026-11-18 AI/ana ekran işlerinin ölçümü + galeri açılış geçişi — ölçüldü: geçti (2026-11-20) (A/B bekliyor, main d7e9765e) + U2 ana ekran tek akıllı şerit (yazıldı, cihazda doğrulanmadı; dal faz-oto-U2-tek-serit) + B11 dilim 1–2 slayt düzenleme A/B (tablo stili çizimi, imleç dokunulan yerde, şekil sürükleme katmanları, prova; dal faz-oto-B11-slayt2) + B11 dilim 3 geçiş/animasyon/Biçim değiştir — ölçüldü: kaldı (2026-11-20; slayt_300_acilis_pro0 build p99 30,9→45,5 ve 30,0→47,6) (ölçülmedi; sunumda Biçim değiştir ve efektli tıklama animasyonu kare p99, taban önceki [apk] `.r8test`; dal faz-oto-B11-slayt3) + B4 dilim 1–8 PDF Pro (meta veri/XFDF, R6 kilit açma, sayfa stüdyosu ızgarası ve sayfa ekle/çıkar/böl/kaydır, form alanı algılama metin ve çizgi/kutu, form ekranında imza alanı, OCR aranabilir katman; işlev turu, izolatta; 300 sayfada p99 ≤ 16 ms hedefi; ölçülmedi; sıcak yola dokunmuyor; dal faz-oto-B4-pdfpro) + R6 kilit açma + boş/dosyadan/görselden/taramadan sayfa ekle + çıkar/böl + B15 dilim 1 AI budama + Akıllı adlandırma (ölçülmedi; görüntüleyici/editör alt çubuğundan bir düğme kalktı, ana ekran sekme adı değişti; dal faz-oto-B15-akilli) + U3 ana ekran — ölçüldü: kısmen (2026-11-20; sol menü geçti, ana sekmeler yalnız adayda 24 ms altı, ana ekran kaydırma senaryosu yok) (ölçülmedi; Son dosyalar sekmeleri + karışık sıra + Geçmiş bellek önbelleği, Akıllı düzen şeridi bildirim kartına katıldı, tek Düzenle düğmesi, araçlar 8→5, yan menü şeridi; taban önceki [apk] `.r8test`, ana ekran açılış + şerit sekme geçişi + yan menü açılışı; dal faz-oto-U3-ana-ekran) + U4 Akıllı klasörler/Analiz/ayarlar (ölçülmedi; Akıllı düzen ızgarasına "Diğer" kutusu + altına "Akıllı aramalar" kartı, Analiz araçlarına bir satır; sıcak liste yoluna dokunmuyor; dal faz-oto-U4-akilli-klasor) + B5 P23 UDF açılışı (ölçülmedi; .udf → .docx çevrimi izolatta, Word okuyucusu aynı; 1–5 sayfalık örnekte açılış süresi; dal faz-oto-B5-udf) + B3 P29 çökme uyarısı bildirim kartında (ölçülmedi; ana ekran üstündeki ayrı kırmızı şerit kalktı, kart kaynağına bir sayaç eklendi; taban önceki [apk] `.r8test`, ana ekran açılışı; dal faz-oto-B3-hiz) + U4 dilim 2 Akıllı düzen durma kuralı, Ayıkla yorumu ve öğrenilen alt tür (ölçüm gerekmez: görünür alan yok, liste/ızgara yoluna dokunmuyor; yalnız işlev turu CIHAZ_TESTI U4.2; dal faz-oto-U4-akilli-2) + U4 dilim 3 Bellek Analizi silme sonrası yenilenir (ölçüm gerekmez: görünür alan yok, pano ve liste yoluna dokunmuyor, yenileme izolatta; yalnız işlev turu CIHAZ_TESTI U4.3; dal faz-oto-U4-akilli-3) | opus | §1.8; docs/perf/ | A/B | evet | cihaz bekliyor; A/B U3/U4/B15 denendi 2026-11-20: YETERSİZ, ölçülmedi (sürücü boş kareyle çöktü, senaryo eksik; docs/perf/2026-11-20-C2-U3.md) |
| C3 | **Cihaz: genel tur:** P11 `CIHAZ_TESTI.md` baştan sona (Faz 34–42, Güvenlik, 360×800 + 2× yazı, 2026-11-18 AI maddeleri) + §3 "Telefonda sen bak" (K20–K28); kırmızı → ilgili pakete madde | sonnet | CIHAZ_TESTI | evet | hayır | bekliyor — telefon boşken |

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

### 1.4) B4 ayrıntısı — PDF Pro (arsiv/PDF_PRO_PLANI)

- **P16** metin: taşma/çakışma uyarısı (punto küçült · it · genişlet), font seçici (belge → aile → paket), metne bağlantı (56–58).
- **P17** nesne/işaret: hizalama kılavuzu + tutunma, çoklu seçim/grup, katmanlar (OCG), kamera; serbest metin/bulut/damga, basınçlı kalem + avuç reddi, XFDF (59–60).
- **P18** form + imza tek yüzey, form oluşturma, düz PDF'te alan algılama; form otomatik doldurma + ~~akıllı karartma önerisi~~ iptal (B15: yeni AI aracı yok) (61, 65/3).
- **P19** OCR Pro: görünmez katman, renkli arka planda satır düzenleme (62) — Arapça için `CloudOcr` yolu hazır.
- **P20** sayfa stüdyosu (küçük resim ızgarası, geri alınabilir sayfa komutları) (63).
- **P21** parola/izin, meta veri, optimize, PDF/A, bu kipte yazdır; AES-256 (R6) kilit açma; `PdfEditorScreen` emekliliği (64).
- **P22b okuma deneyimi (kullanıcı 2026-11-18):** hızlı kaydırma tutamacında sayfa no + küçük önizleme
  balonu (FERRARI H2.4; `PdfViewerScrollThumb`, `viewer/body.dart`), bağlantı/içindekilerden atlayınca
  "← geri dön" hapı (sayfa geçmişi), belge başına yakınlaştırma/görünüm kipini hatırla, çift dokunuşla metin
  sütununa sığdır, seçim tutamaçlarında büyüteç. Önce bak: hangisi zaten var (grep); olanı geliştir.
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

### 1.9) B9 ayrıntısı — Word 2.0 (sadakat + yazma hissi)

Çekirdek: `lib/services/docx/docx_document.dart` (okuma/yazma), `services/docx/pro/*`; ekran
`screens/editors/word_mobile_editor_screen.dart` + `word_mobile/`. Örnek belge KVKK gereği depoya
GİRMEZ → testte sentetik docx üret. Her madde ayrı commit.

_Bitti (bulut 2026-11-19, dal faz-oto-B9-word2; HAFIZA 2026-11-19 B9): m.1 içerik denetimleri, m.2 İçindekiler, m.3 değişiklikleri izle (`docx_track.dart`, test `docx_track_changes_test`), m.5 dipnot/sonnot, m.6 sadakat bekçisi, m.8 büyük belge açılışı (`DocxDocument.parseHead`, test `docx_head_test` + `word_perf_test`); m.4 yorum yaz/yanıtla/çözüldü önceden vardı (`docx_media.dart`). Kalan: m.4 kenar balonu; satır/hücre düzeyi `w:sdt`; PDF'te dipnot sayfa altında (bugün belge sonu liste); izlenen paragraf bölme/birleştirme (`w:pPr/w:rPr/w:ins|del`) ve biçim değişikliği (`w:rPrChange`)._

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

1. **Grafik türleri — KANIT VAR:** yalnız 4 tür (`xlsx_chart.dart:14` `XlsxChartKind {column, bar, line,
   pie}`; slaytta aynı: `pptx_chart_ops.dart:9`, `pptx_render.dart:251`). Ekle: alan, dağılım (XY), halka,
   radar, yığılmış / %100 yığılmış sütun-çubuk; sonra şelale, histogram, kutu (`cx:` chartex — önce
   okuma). Dosyadaki bilinmeyen tür bugün nasıl çiziliyor (önce bak) → en yakın tür + "yaklaşık" rozeti.
   Excel + Slayt ORTAK çizici (B11.2 aynı kodu kullanır). Test: tür başına yaz → oku → çiz.
2. **Formül kapsamı — kalan (çekirdek + `_xlpm.` yazımı bulutta yapıldı 2026-11-19):** LAMBDA ailesinin
   Türkçe adları (MAP/REDUCE/SCAN/BYROW/BYCOL/MAKEARRAY bugün İngilizce — sabah bakılacak);
   TOCOL/TOROW/WRAPROWS.
3. ~~**Veri doğrulama**~~ — bulutta yapıldı 2026-11-19 (aralık/ad/x14 liste, özel formül, başvurulu
   sınır, Durdur/Uyarı/Bilgi, öznitelik korunumu; `test/excel_validation_test.dart`). Kalan: giriş
   iletisinin (`prompt`) hücre seçilince gösterimi; cihaz turu `docs/CIHAZ_TESTI.md` §9.
4. **Otomatik + hızlı doldurma:** tutamaçla seri (1,2,3 · Pzt,Sal · Ocak · tarih +1 · formülde göreli
   kayma); "Hızlı doldurma" (örnekten desen: ad soyad ayır/birleştir). Önce bak: `autoFill` 4 dosyada.
5. **Süzgeç/sıralama 2:** çok düzeyli sıralama, renge göre süzgeç, ilk 10, "içerir"; durum dosyaya
   yazılır (`autoFilter` + `sortState`).
7. **Hücre düzenleme hissi:** Enter aşağı / Tab sağa / satır sonunda Enter, Tab'la başlanan sütuna döner;
   sayı hücresinde sayısal klavye; tek dokunuş seç, çift dokunuş düzenle; yapıştırmada seçenek
   (yalnız değer / biçim / formül); `spreadsheet_editor_screen.dart:418` ana iş parçacığında
   `readAsBytesSync` (→ B12.1).
8. **Açılış hızı:** büyük xlsx'te görünür pencere önce (`xlsx/xlsx_stream.dart` var); paylaşılan dizgeler
   ve stiller izolatta; cihazsız kanıt `excel_perf_test` (100 bin satır) ilk pencere bütçesi; A/B → C2.

**Bitti:** 1–8 testli, `excel_roundtrip_test` yeşil, C2'ye "Excel A/B".

### 1.11) B11 ayrıntısı — Slayt 2.0

Çekirdek: `lib/services/pptx_render.dart`, `services/pptx/`; ekran `screens/editors/slides*`,
`slideshow*`. Her madde ayrı commit.

1. **Görsel sadakat:** sentetik pptx korpusu (gradyan dolgu, gölge, yansıma, döndürülmüş metin kutusu,
   `normAutofit` fontScale, çok düzeyli madde, tema yazı tipleri, tablo stilleri) → `pptx_render` altın
   görüntüleri + fark eşiği. Önce bak: `test/` altında slayt altın testi var mı.
2. **Grafik türleri:** B10.1'in ortak çizicisi (slayttaki 4 tür aynı genişler).
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
- **C3:** **B13 his turu** (dal faz-oto-B13-his, cihazda doğrulanmadı): titreşim haritası (uzun bas orta ·
  bırakma hafif · hata uyarı · seçim tık), Önemli kategori sil → çöp + Geri al, Word'de alt satıra dokunup
  klavye açılınca satır görünür + kapanınca yerinde, öngörülü geri levhalarda; büyük sunum/tabloda ilk slayt/satır önizlemesi, Word'de iki parmakla yakınlaştırma (CIHAZ_TESTI B13). P11 genel tur + K20–K28; Arapça OCR, AI hızlı/toplu kontrol, paylaşım kalkanı, Akıllı düzen ve
  Ayıkla maddeleri (CIHAZ_TESTI 2026-11-18); Akıllı düzen Word/Excel/sunum/metin/APK ikinci adları
  (bulut 2026-11-18, dal faz-oto-B1-duzen2); Akıllı düzen kullanıcı kategorileri ("Dene", uygula,
  süzgeç/arama/ikinci ad — CIHAZ_TESTI 2026-11-18); Akıllı düzen hız/kota + ilk slayt görüntüsü
  (yalnız Wi-Fi, günlük sınır, büyük video kesiti — CIHAZ_TESTI 2026-11-19); Word form alanları ve
  içerik denetimleri (doldur, kaydet, Word'de aç — CIHAZ_TESTI 2026-11-19 B9); Word İçindekiler + dipnot/sonnot
  (CIHAZ_TESTI 2026-11-19 B9 m.2/m.5); Word değişiklikleri izle (CIHAZ_TESTI 2026-11-19 B9 m.3); Word büyük belge açılışı (CIHAZ_TESTI 2026-11-19 B9 m.8).

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
- 👤 **Play Console öncesi (2026-11-20, güvenlik denetimi 38ff7343'ten):** (1) kalıcı imzalama anahtarının SHA-256 parmak izini GitHub → Settings → Variables'a `SIGN_CERT_SHA256` olarak ekle; (2) mağaza için `EDITION=play` ile AAB tam derlemesini al (Actions → APK Derle → elle tetik ya da `v*` etiketi).
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
