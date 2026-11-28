# PLAN — tek kalan-iş listesi (2026-11-27 temiz sayfa)

**Açık işin TEK kaynağı burası.** 2026-11-27'de baştan temizlendi (kullanıcı: "geçmişte açık kalmasın,
plan teke insin"): biten satırlar silindi, eski planların (`docs/arsiv/planlar/` — KALANLAR, KONTROL_LISTEM,
FAZ, DUZENLEME, GELISTIRME, YUKSELTME, PDF_PRO, GUVENLIK, FERRARI, SURUM, SURUM_ADAYI) hâlâ geçerli açıkları
buraya satır olarak taşındı; arşiv yalnız ayrıntı/karar kaynağıdır, yürütülmez. Telefonda adım adım
bakılacaklar: `docs/CIHAZ_TESTI.md`. Yürütme düzeni (zincir): `OTOMASYON.md`.

**Kurallar:** biten satır **SİLİNİR** (tik bırakılmaz) · karar / kök neden / tuzak → HAFIZA ·
cihazda bakılacak yeni şey → `docs/CIHAZ_TESTI.md` + §1.8 · kullanıcının yapacağı → §3 (ne · nasıl ·
doğruysa · yanlışsa) · yeni iş → **ilgili paketine madde** (yeni paket yalnız hiçbirine uymuyorsa).
Kaynak kısaltması: `arsiv/` = `docs/arsiv/planlar/`.

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

## 1) Kuyruk — paketler

**Bir oturum = bir paket** (gerekirse 2–3 oturum, aynı dalda sürer; kullanıcı 2026-11-18). Paketin içindeki
`P`/`m.` numaraları HAFIZA ve §3 atıfları için korunur; biten madde paketten silinir, paket boşalınca satır
silinir. **Kod paketleri (B)** bulutta ya da yerelde; **cihaz işleri (R, C)** telefon bağlıyken yerelde
(`ab-olcum` skill'i, ÖLÇÜM KAPISI).

Durum: `bekliyor` · `sürüyor` · `cihaz bekliyor` · `kullanıcı kararı` · `takıldı: <neden>` ·
`bulutta: sürüyor …` (bulut zinciri sahiplendi — yerel tur atlar; `OTOMASYON.md` "Bulut zinciri").
Model: `fable` · `opus` · `sonnet`. Cihaz: `—` · `evet` · `A/B` · `tablet`. APK: `evet` · `hayır`.

**CİHAZ KURULUM KURALI (kullanıcı 2026-11-21):** test cihazına (Huawei tablet DBY-W09 / Mi Note 10 Lite)
kendi APK'mızı kurarken "Bilinmeyen kaynaklardan yükleme" → **DEVAM ET** → **YÜKLE** → **BİTTİ** pencerelerine
Claude KENDİSİ basar (nightly, `.r8test` taban/aday, elle derleme). Düzen: `KEYCODE_WAKEUP` → `wm dismiss-keyguard`
→ `uiautomator dump` ile düğmeyi bul → `input tap`; `adb install` 2 dk'da dönmezse ekrana bak. Başka izin/ayar/
hesap ekranı, PIN kapsam dışı. Ayrıntı `ab-olcum` skill'i "Huawei tablet".
**APK kuralı (kullanıcı 2026-11-21):** bir birleştirme dizisinin sonunda APK HER ZAMAN bir kez derletilir
(`gh workflow run build-apk.yml --ref main` ya da son birleştirmeye `[apk]`), sonra tablete kurulur.

**Sabit karar (U6 a, 2026-11-25):** Kokoro/eSpeak (GPL-3.0) Play derlemelerinde YOK, yalnız Kişisel derlemede
(`Feature.extraVoices`); Play'de Apache-2.0 yapay sesler (Antalia/EMA) + cihazın Android TTS motoru.

**Ferrari kuralı (§0):** B3 hız işleri (P06, P12b) bitmeden büyük yeni özellik **varsayılan açık** birleşmez.
**Gevşetme (kullanıcı 2026-11-18):** editör özellikleri ve B4 PDF Pro varsayılan açık birleşebilir — koşul:
dosya listesi / ana ekran / PDF kabuğunun sıcak yoluna dokunmaz, dokunulan editörün bütçe testi yeşil,
A/B sonra C2'de; gerileme çıkarsa (§0 eşikleri) o commit `git revert` ya da düzeltme SIRA'nın EN ÖNÜNE.

**SIRA (2026-11-27):**
- **Telefonla (yerel):** R3 → C2 → C3 → B3 (P12b ölçümü, P06) → **en son B8**.
- **Kod (bulut ya da yerel):** B4 (P21 kalan → P22 → m.13 düzenleyici artıkları → H1.5) → B16 kalan →
  kullanıcı kararı gelince B5 / B6 / U4 → B11 m.1 (izinle).

| No | Paket | Model | Kaynak | Cihaz | APK | Durum |
|---|---|---|---|---|---|---|
| R3 | **Gerileme kökü — PDF ilk sayfa (hız anayasası, SIRA'nın EN ÖNÜ):** 2026-11-28 ABBA (4b2bec2↔main 11fb9de6): `acilis_ilk_sayfa#1` (belge_100) 331–419 → 815–1038 ms (+%163, tam ayrık; 27-11'deki tüm koşularda zaten 700–830 → gerileme `4b2bec2..02c2ee5e` arasında, taban hep sonrası olduğundan görünmedi). Yapılacak: tek senaryolu bisect (`AB_SENARYO=acilis_gecis`, `acilis_ilk_sayfa` damgası; şüpheli `lib/screens/viewer/body.dart` commit'leri c51456c1, ac47b338, 2bef416a, e92152c2, f5ae323f, 2da8b296, fb47a12a — doğrulanmadı) → kök düzelt → A/B. (Eski R3 (1) Word mobil kaydırma ve (2) pptx geçiş build p99 GERÇEK DEĞİL — iki kipli/tek kare kuyruğu, kapandı: docs/perf/2026-11-28-R3-word-mobil.md) | sonnet (bisect) + opus (düzeltme) | docs/perf/2026-11-28-R3-word-mobil.md, 2026-11-28-ab-4b2bec2-11fb9de.md | A/B | evet | bekliyor — EN ÖNCE |
| C2 | **Cihaz: perf A/B listesi** — tam liste §1.8 C2 | opus | §1.8 | A/B | evet | bekliyor — R3'ten sonra |
| C3 | **Cihaz: elle tur** — tam liste §1.8 C3 + `docs/CIHAZ_TESTI.md` | sonnet | §1.8; CIHAZ_TESTI | evet | hayır | bekliyor — telefon boşken |
| B3 | **Hız (Ferrari) kalanı:** P12b Excel/liste A/B artıkları + P06 PDF kaydırma H2.1–H2.6 (ayrıntı §1.3) | opus (P06 plan evresi fable) | §1.3; arsiv/FERRARI_PLANI H2 | A/B | evet | cihaz bekliyor |
| B4 | **PDF Pro tamamlama — kalan:** P21 kalanı (yinelenen font/görsel birleştirme, `PdfEditorScreen` emekliliği), P22 kalite %98 + büyük belge, m.13 düzenleyici artıkları, H1.5 açılış geçişi (ayrıntı §1.4) | opus (plan evresi fable) | §1.4; arsiv/PDF_PRO_PLANI 54–68; arsiv/KALANLAR "PDF Pro" | A/B | evet | sürüyor — P16–P20, P19b/P19c, P20ust, P21 güvenlik/çıktı, P22b main'de; sıradaki P21 kalanı |
| B16 | **İnternetsiz Arapça OCR — kalan:** dilim 1 main'de (5afd34d8; PP-OCRv5 det + Arapça rec ONNX, ilk kullanımda iner; tablette model indirme + sentetik sayfa GEÇTİ). Kalan: m.4 kalite kapısı (Gemini'ye karşı karakter doğruluğu; cihaz → §1.8), yerel sonuç zayıfsa Gemini'ye sorarak geçiş, eğik fotoğraf için döndürülmüş kutu, m.5 PP-Structure (isteğe bağlı) (ayrıntı §1.15) | opus | §1.15 | evet | evet | bekliyor. Sabah bakılacak: ORT wasm indirilen çalışma zamanı (seslerle aynı yol; Play politikası) |
| U4 | **Akıllı klasörler + Analiz — kalan adaylar:** dilim 1–3 main'de (58e0e57d, 09f5dc10, bb0aa582). Seçilmemiş adaylar: (a) klasör kutusunda "+n yeni" rozeti; (b) kutuda ilk dosyanın küçük resmi (ızgara, ölçümle); (c) klasörü ızgaradan gizle; (d) yeni yerleşik kategoriler (ev/tapu/aidat, çocuk/okul, tarif — önce C2 doğruluk tezgâhı); (f) Kategorilerim ızgarada klasör; (h) Analiz'de Akıllı kategoriye göre yer ("Faturalar 1,2 GB"); (j) eski Akıllı dosya asistanı (AiIndex) ile Akıllı düzen ikiliği; + B15 m.4 kategorizasyonu iyileştirme (C2 tezgâhından sonra) | opus (xhigh) | kullanıcı istekleri 2026-11-19 m.7/m.10 (eski PLAN §1.14); HAFIZA 2026-11-20 U4 | A/B | evet | kullanıcı kararı — §3 m.11 |
| B5 | **Levha birliği + bağımlılık bakımı:** P25 ham `showModalBottomSheet`/`showDialog` → `showAppSheet`/`showAppConfirm`/`showAppPrompt`, parti parti önce/sonra PNG (onay K17); Dependabot dalları actions/cache · upload-artifact · setup-gradle (onay K14); P24 `xml` (webdav_client 1.2.2) ve `pointycastle` (smb_connect 0.0.9) override'ları üst paket yeni sürüm çıkarınca kaldır; `shared_preferences_android` 2.4.28 sabit | opus | arsiv/KALANLAR A9.1; HAFIZA P24 | A/B | evet | kullanıcı kararı — §3 m.10 (K17, K14) |
| B6 | **Tasarım tamamlama:** P31 ana ekran — D simge takımı (24 ızgara, 1,8 çizgi, %18 iç dolgu, kendi glif çizimi), F metinleri (arama "Dosya ya da özellik ara", son açılanlarda "Ekran görüntüsü · Bugün 09:31", "Tümü →" okunu kaldır, "Son tarama bugün 00:29 · 5.691 dosya", kutu adlarında cümle düzeni), alt paneldeki Aktar kapsülü vurgu renginde, ÖLÇÜM KAPISI (ana ekran); P32 menü — üst çubukta Kaydet/↶/↷ yalnız gerektiğinde, Word'e "Aa", Kitaplık ⋮'ında "Sırala" | opus | docs/design/ana_ekran/; arsiv/FERRARI_PLANI H5/H7 | A/B | evet | kullanıcı kararı — §3 m.10 (K19, K7) |
| B11 | **Slayt 2.0 — kalan:** m.1 piksel altın görüntü testi (sentetik pptx korpusu → `pptx_render` altın PNG + fark eşiği; yerel test yasağı yüzünden yalnız kullanıcı izniyle yerelde üretilir). Öteki maddeler main'de (tablo stilleri, geçiş/animasyon/Biçim değiştir, yerinde metin, prova, roundtrip bekçisi, sürükleme bütçesi, grafik türleri, dikey metin, yansıma); m.5 AI tasarımcı İPTAL (B15). Cihaz kısmı (m.4 klavye kayması) §1.8 C3 | opus | HAFIZA 2026-11-19/20 B11 | — | hayır | kullanıcı kararı — §3 m.14 |
| B8 | **Son kapı:** P27 "10 işlem" son ölçüm + Samsung kıyası (FERRARI H0.1/H12.1–H12.2), H0.4 231 MB USB PDF, erişilebilirlik (H12.3), tasarım görüntüleri güncel (H12.4), PDF rakip turu (PDF_PRO Faz 68: Acrobat/PDFelement/Xodo, 10 belge × 15 görev), özellik dondurma kalkar (H12.5) | sonnet | arsiv/FERRARI_PLANI H0, H12; arsiv/PDF_PRO_PLANI Faz 68 | A/B | evet | bekliyor — en sonda, kullanıcıyla |

### 1.3) B3 ayrıntısı — Hız (Ferrari)

- **P12b:** `xlsx_100k_acilis` p99 128 ms (gerçekse kök neden), `xlsx_10k_x20_*` ve `*_sk` neden
  tabloda yok, düzelt + 3 tur ölç; soğuk açılış A tabanı (docs/perf/2026-11-14-ab-1684533-*.md).
- **P06:** PDF kaydırma H2.1–H2.6 (plan evresi fable): önbellek tavanı ölç (`pdfImageCacheBytes` 64 MB),
  bulanık yer tutucu (≤ 48 dpi), komşu sayfa ön çizimi (+2), yakınlaştırma netleşmesi, USB okuma hızı →
  ölç → değiştir → ölç (cihaz). H2.4 hızlı tutamaç önizlemesi P22b ile main'de.

### 1.4) B4 ayrıntısı — PDF'in kalanları

**Main'de (tekrar yapma):** P16 metin · P17 nesne + işaretleme stüdyosu + XFDF · P18 form + imza + dijital imza
tek yüzey (alan algılama, form oluşturma, otomatik doldurma) · P19 OCR Pro (görünmez katman, renkli satır,
döndürülmüş sayfa, "düzenlenebilir yap", düşük güven işareti) + P19c Play'siz cihazda anlaşılır ileti (paketli
Latin modeli KONMAZ — kullanıcı kararı) · P20 sayfa stüdyosu + üst/alt bilgi ekle/düzenle/kaldır · P21 parola/
izinler, meta düzenle/temizle, PDF/A-2b, agresif sıkıştırma (büyüyen sonuç uygulanmaz), nesne akışları,
ilerleme + Durdur, Yazdır · P22b tutamaç önizlemesi + "N. sayfaya dön" hapı (K41; kapatma `P22B_KAPALI`) ·
P08, P28, P07 · eski düzenleyici yeni motorda · akıllı karartma önerisi. **Kural:** her madde için önce `grep`;
var olanı geliştir. Her dilim CI + `pdf_pro_*` testleri; PDF kabuğu sıcak yoluna (`viewer/body.dart`, kaydırma)
dokunan madde **bayrak + A/B** (§0 k.9). Dal `faz-oto-B4-<ad>`.

6. **P21 kalan:** yinelenen font/görsel birleştirme (düşük seviye nesne yeniden yazımı — `PdfFile` + tam
   yeniden yazım; önce Syncfusion bağlantısız nesneyi atıyor mu ölç); **`PdfEditorScreen` emekliliği** (⋮ "Eski
   düzenleyici" — `pdf_pro_edit.dart`, `pdf_selection.dart`, `pdf_action_bars.dart` kullanımını grep'le; filigran
   ve AES-256 kilit açma yeni yola taşınınca `lib/screens/pdf_editor*` + eski `PdfEditJournal` silinir —
   arsiv/KALANLAR "PdfEditorScreen emekliliği", "AES-256 (R6)"). Ayrı e-posta kısayolu YAPILMAZ (Paylaş içerir).
10. **H1.5 Office/PDF açılış geçişi** (B13 m.1): 2026-11-20 A/B KALDI (satırdan büyüyen kırpma, Slayt 314→354 ms,
    Excel 293→342 ms; docs/perf/2026-11-20-ab-c136fd2-56f885b.md). ÖNCE Slayt/Excel ilk karelerinde neyin
    uzadığını zaman çizelgesinden bul (`ext.flutter.profileWidgetBuilds`), sonra farklı yöntemle (ör. ilk kare
    hazır olunca) bayrak arkasında yeniden dene; A/B geçmezse iptal.
11. **P22 kalite + büyük belge** (PDF_PRO Faz 54, 66–67): başarı %94 → %98 (Type3/matplotlib aralık, `/Rotate`,
    açılı metin tezgâh ölçümü), 50 sayfa artımlı kayıt süresi + oturum ek belleği (`session_bench_test`; 3 paragraf
    düzenlemesi +56/+65 MB, bütçe +40 — arsiv/KALANLAR "Oturum belleği"), 500+ sayfa / 200 MB tembel çözümleme,
    pil/ısı (10 dk düzenleme CPU; boşta 0 kare), tablet yatay düzen (sağ panel), TalkBack/200% yazı/RTL, ilk
    kullanım ipuçları, ayarlar (kaydetme kipi, sürüm geçmişi süresi, font paketleri).
13. **Düzenleyici artıkları (2026-11-27 arşivden taşındı; kaynak arsiv/KALANLAR "PDF Pro" + arsiv/PDF_PRO_PLANI
    Faz 56–60; kodda `grep` ile yok doğrulandı):** (a) metne bağlantı ekle/düzenle/kaldır (URI + sayfa içi hedef;
    Faz 58/7); (b) taşma/çakışma uyarısı + seçenekler (punto küçült · alttakileri it · genişlet), büyüyen paragraf
    alttakinin üstüne binmesin (Faz 57); (c) font seçici: belgenin fontları → eşleşen aile → isteğe bağlı font
    paketi (Caladea, Cousine, Gelasio, Noto Naskh…) (Faz 56); (d) nesnelerde hizalama kılavuzları + tutunma,
    çoklu seçim/grup, hizala/dağıt (Faz 59); (e) basınçlı kalem + avuç içi reddi (Faz 60). Her biri ayrı dilim;
    önce `grep` (yerel dal `faz-oto-B20-kalem` açıldıysa (e) orada).

### 1.15) B16 ayrıntısı — İnternetsiz Arapça OCR (kullanıcı 2026-11-26)

**Neden:** ML Kit'te Arapça yazı modeli yok; Arapça tanıma yerel motordan önce yalnız Gemini ile (internet,
anahtar, ücret). Dini kitap ve B17 (Malezya/Endonezya: Arapça + Cavi) için cihazda, ücretsiz tanıma.
İndirilen şey kod değil model dosyası (Play kuralına takılmaz). **Kaçın:** DocLayout-YOLO/ultralytics (AGPL).
- **m.4 kalite kapısı:** matbu Arapça, harekeli Kur'an metni, Osmanlıca, Cavi örnek sayfalarla Gemini'ye karşı
  karakter doğruluğu; yerel < kabul eşiği ise varsayılan Gemini kalır, yerel "çevrimdışı" seçenek olur. Hız/bellek
  cihazda (§1.8 C2, CIHAZ_TESTI B16).
- **Geçiş:** yerel sonuç zayıfsa (onaylı) Gemini'ye sorarak geçiş; onaysız buluta gönderim kuralı (HAFIZA 2026-11-25) korunur.
- **Döndürülmüş kutu:** eğik fotoğrafta satır kutuları döndürülmüş; `orderOcrRows` sağdan sola sıra denetimi.
- **m.5 (isteğe bağlı):** PP-Structure düzen modeli (Apache 2.0) → taranmış kitapta başlık/paragraf/tablo ayrımı.

### 1.8) Cihaz doğrulama (C2 ölçüm · C3 elle tur) — telefon bağlıyken yerelde

Taban = önceki `[apk]` profil derlemesi, ölçüm kimliği `.r8test`; eşikler §0/8. Senaryolar `tool/perf_senaryo.sh`,
`tool/pdf_profil.sh`; ayrıntı `ab-olcum`. Adım adım maddeler `docs/CIHAZ_TESTI.md` (başlıklar aşağıda adıyla).
Bulut zinciri ölçümsüz `[apk]` yaparsa buraya "ölçülmedi" satırı ekler; gerileme çıkarsa revert/düzeltme SIRA'nın önüne.

**C2 — A/B ölçüm (2026-11-26 tablet turu 4b2bec2→ad4ee9a KALDI; kalan kök R3'te):**
- **Kaldı, kök bekliyor:** B9b Word yorum sütunu (word_300_kaydirma raster p99 15,9→22,4); B10 büyük xlsx
  (xlsx_100k_kaydirma build p90 8,5→24,8, xlsx_10k_x20_acilis p99 144,6→180,9; hipotez önizleme→tam model yer
  değişimi); P13 liste/ızgara (klasor_5000 build p99 20,6→46,1); B11 dilim 3 sunum (slayt_300_acilis_pro0 build p99
  30,9→45,5).
- **Yeniden ölç:** P22b PDF geçiş kare kurulum p99 (2026-11-27 A/B 2'de 4/8 ölçümde > 24 ms, gürültü şüphesi;
  K41 ile alındı — docs/perf/2026-11-27-P22b-ab2.md); Fotoğraflar'da eski görsellere hızlı inip açınca donma
  (kullanıcı isteği 2026-11-19 m.1, arsiv/KALANLAR B3.3c) + soğuk açılış ≤ 1,2 sn.
- **Hiç ölçülmedi:** P08 PDF Pro bellek (PSS), P28 PDF kabuğu, P07 son sayfa + döndür (C1 dalları main'de);
  P12/P12b Excel 10k×20 (≤ 1,5 sn, K23 FrameTiming %99); P14 Word kapanış/menü (K21–K22); P04 boş/hata (K6–K7);
  U1 Geçmiş görsel açılışı; U2 tek şerit; U3 ana ekran kaydırma + şerit sekme + yan menü açılışı; U4 Akıllı düzen
  ızgarası; U5 galeri çimdik + pano araçlar; U7 tablet tek menü + pano; B1 Akıllı düzen doğruluk tezgâhı
  (Geliştirici → "Doğruluk ölçümü", ~100 dosya, kapı kategori ≥ %90 / alt tür ≥ %80, rapor `docs/ai/`) + hız/kota
  (14 MB görselli tur ana izlek, liste satırında ikinci ad, haftalık istek/429 → varsayılan 200 doğru mu, 2 dk+
  video kesiti); B9 Word 2.0 m.1–m.8 (form alanlı/dipnotlu/izlenen belgede yazma, 300+ sayfa ilk kare, İçindekiler
  süresi) + Word 3 yorumlu belge (`word_300` + 50 yorum, p99 ≤ 24 ms); B10 süzgeç levhası + chartex çizimi + büyük
  xlsx ilk pencere; B11 dilim 1–2 + m.2 + m.1 yansıma; B12 hız (eski .xls/.doc açılışı, taslaktan geri yükleme,
  sesli kitap hazırlığı, resimli Word kaydırma, CSV 2.000 satır; ölçümle taşınacak senkron G/Ç adayları
  `sync_io_guard_test` tavanında; PDF sayfa değişiminde `body.dart` onPageChanged setState → dar dinleyici adayı);
  B13 m.4/m.7 (50+ slayt / ≥ 1 MB xlsx ilk kare, Word çimdik p99 ≤ 24 ms); B4 dilim 1–8 + P16/P17 (kalemle çizerken
  300 sayfada p99 ≤ 16 ms); B15 budama; B5 UDF açılışı; B3 P29 ana ekran açılışı; Yer aç/Bento levha; B16 Arapça
  OCR hız/bellek; B17 ucuz (2–3 GB RAM) cihazda PDF/Office açılışı.
- **Geçti (silinmez, taban):** B2 dilim 1–5, galeri açılış geçişi (2026-11-20), sol menü (2026-11-21),
  2026-11-27 [apk] öncesi PDF açılış/kaydırma (docs/perf/2026-11-27-ab-83f94a5-e9ecadb.md).

**C3 — elle tur (`docs/CIHAZ_TESTI.md`; geçen madde orada silinir, kırmızı → ilgili pakete madde):**
- **Önce (en yeniler):** K15 Pro satın alım Play iç test kanalında (ödeme penceresi, ülke fiyatı, anında kilit
  açma, geri yükle — §3 m.6 sonrası; Lite rozet/levha GEÇTİ) · P19c Play'siz cihazda OCR anlaşılır ileti (yeni
  nightly; CIHAZ_TESTI "B4-P19b") · "C3-düzelt" (agresif sıkıştırma koruması, OCR stüdyosu hata ekranı) ·
  "B4-P19" / "B4-P19b" gerçek taramayla · "B4-P22b" · "B16 dilim 1" gerçek Arapça belge · "B18" Yer aç · "B19"
  İçindekiler arka planda · "B17" (Cavi ek harfleri) · "B4-P18", "B4-P17i", "B11 m.1".
- **Sonra:** P11 genel tur baştan sona (Faz 34–42, Güvenlik G1–G4, U1–U8, B1/B2 Akıllı düzen, B9 Word 2.0/3,
  B13 his turu: titreşim haritası, Önemli kategori sil → çöp + Geri al, Word klavye satırı, öngörülü geri, büyük
  sunum/tablo önizlemesi, Word çimdik); 360×800 dp + 2× yazı ölçeğinde araç satırı alt panel üstünde
  (arsiv/GELISTIRME_PLANI); B11 m.4 slayt klavye kayması; §3 m.16 "Telefonda sen bak" (K20–K28).

---

## 2) Bilinçli kapsam dışı (yapılmayacak)

- "Verilerimi sil"e kayıtlı bağlantı/anahtar seçeneği (bilinçli dışarıda).
- Eski sürüme dönülürse Keystore sarılı sırlar okunamaz, kullanıcı yeniden girer (bilinçli ödün).
- AI'da tek belgelik maske kapatma (G10.2) — korumayı gevşettiği için yapılmadı.
- Başka uygulamaya sürükle-bırak (eklenti gerekir).
- Ayrı ücretli Pro uygulaması, Lite→Pro geçiş, ayrı paket kimlikleri (arsiv/SURUM_PLANI S4–S8) — K15 tek uygulama
  kararıyla geçersiz.
- Play'siz cihazlar için paketli Latin OCR modeli (P19c kararı 2026-11-27; APK +~12 MB).
- Word ⋮ menü süslerini sadeleştirme (K40 kararı 2026-11-27).
- Slayt AI tasarımcı (B11 m.5, B15 budaması) · Office'te çift dokunuşla sığdır (mevcut hareketle çakışır) ·
  kenar yaylanmasını PDF'le eşitleme (ölçümsüz fizik değişmez) — B13 kararları.
- Eski liste: `docs/arsiv/planlar/KALANLAR.md` "Bilinçli kapsam dışı".

**Kapanan kararlar (2026-11-27, ayrıntı HAFIZA):** K15 iş modeli → tek uygulama + tek seferlik `pro_unlock`
(TR 29,99 TL, diğer ülkeler yerel fiyat; ana ekran ve tüm dosyalara erişim her iki katmanda — K15c/K16) ·
K40 Word menü süsleri kalır · K41 P22b alındı · P19c paketli Latin OCR modeli konmaz.

---

## 3) Senin işlerin 👤 (sırayla; biteni söylemen yeterli, silerim)

Kaynak: `docs/play/yayin_rehberi.md`, `izin_beyanlari.md`, `veri_guvenligi.md` + arşivdeki SURUM_PLANI,
SURUM_ADAYI, GUVENLIK_PLANI 👤 maddeleri ve eski K-maddeleri.

### A. Hukuk, hesap, güvenlik (yayın öncesi zorunlu)
1. **Syncfusion Community License:** gelir < 1 M USD ve çalışan ≤ 10 ise ücretsiz; başvur, belgeyi sakla (eski K38).
2. **Google Play Console hesabı + ödeme profili:** bireysel geliştirici (25 USD) + kimlik doğrulama + Pro satışı
   için banka/IBAN/vergi profili (eski K37).
3. **Destek ve güvenlik e-postası:** uygulama içi hata bildirimi, gizlilik politikası ve Play iletişimi için
   (`kSupportEmail` + `SECURITY.md` yer tutucusu; eski K32).
4. **Gizlilik politikası herkese açık + depo güvenliği:** TR/EN/AR metni GitHub Pages ya da kendi alan adına;
   GitHub'da 2 adımlı doğrulama, `main` dal koruması, secret scanning + push protection (eski K34, G9.5).
5. **İmza anahtarı:** `release.jks` + parolasını iki ayrı çevrimdışı yere yedekle; SHA-256'yı GitHub değişkeni
   `SIGN_CERT_SHA256`'ya ekle; Play App Signing aç (eski K33, K35, G9.7).

### B. Ürün kararları ve Play ürünleri
6. **`pro_unlock` ürününü aç (K15):** Play Console → Para kazanma → Uygulama içi ürünler → yönetilen ürün
   **`pro_unlock`**, Türkiye 29,99 TL, diğer ülkeler yerel kademe (ör. `$0.79`, IDR, MYR), etkinleştir. Doğruysa:
   iç test kanalında "Satın al" Play penceresini ve ülke fiyatını gösterir, satın alınca rozetler anında kalkar;
   lisans test hesabıyla iptal/bekleyen/geri yükle denenir. Yanlışsa (başka kimlik): kimliği yaz, `ProPurchase.productId` değişir.
7. **Akıllı Klasör ekstra kota ürünü (K15a):** 500 dosya başlangıç hakkı üstü abonelik/kredi fiyat kademeleri +
   Play ürün kimliği; gelince ürün + sunucu eklenir.
8. **Model indirme aynası (isteğe bağlı):** sesler (Hugging Face/jsDelivr) ve görsel büyütme modeli (tfhub.dev)
   için kendi aynan (Cloudflare R2 / GitHub Releases), düzen `<ayna>/<özgün host>/<özgün yol>`, GitHub değişkeni
   `DOSYA_MODEL_AYNA`. Erişilemezse uygulama özgün kaynağa döner.
9. **Drive / OpenSubtitles / Notlar (K9, K36, G8.5):** Play'de Drive kapalı mı kalsın, `drive.file` kısıtlı kapsam
   mı eklensin? OpenSubtitles için `OPENSUBTITLES_API_KEY` secret'ı (yoksa altyazı "İnternette ara" gizli). Notlar
   Play'e çıkınca haber ver (mağaza kartı + sesli not köprüsü).
10. **Arayüz tercihleri (tek kelime yeter):** PDF "Daha fazla" ilk 5 + Diğer (K1) · çöp silme onayı kapalı kalsın
    mı (K2) · Android 13+ çift "Kopyalandı" kapatılsın mı (K4) · çift bölmede sürükle-bırak kopyala mı taşı mı (K5) ·
    galeri alt çubuğu 5 düğme (K6) · Kaydet yalnız değişiklik varken (K7) · ana ekran varsayılan görünümü (Sakin /
    Bento / Koyu başlık) + kutu adları cümle düzeni (K19 → B6) · levha birleştirme görsel onayı (K17 → B5) ·
    Dependabot güncellemeleri (K14 → B5).
11. **U4 aday seçimi:** Kuyruk U4 satırındaki (a)–(j) adaylardan hangileri yapılsın? Ayrıca bak: "Akıllı aramalar"
    adı uygun mu; Ayarlar'daki "AI Kalıcı Hafıza" artık kullanılmıyor — kaldırılsın mı?
12. **Yalnız Wi-Fi'de model indirme seçeneği (B17 m.4):** 2026-09-26'da mobil veride indirme bilerek açıldı;
    Endonezya/Malezya'da veri pahalı — "yalnız Wi-Fi" seçeneği eklensin mi?
13. **Uygulamasız alıcı (isteğe bağlı, arsiv/KALANLAR B5.9):** Aktar "Bağlantıyla gönder"de uygulaması olmayan
    alıcının tarayıcıda çözmesi için ya barındırılan statik sayfa (GitHub Pages / alan adı, Web Crypto) ya da Drive
    API anahtarı gerekir — istiyor musun?
14. **Slayt piksel altın testi (B11 m.1):** altın PNG'ler yalnız yerelde (`flutter test --update-goldens`)
    üretilebilir; yerel test yasağına bu iş için izin veriyor musun?

### C. Mağaza, video, telefon kontrolü, lansman
15. **Ekran görüntüleri + 2 izin videosu:** telefon & tablette TR/EN/AR/ID/MS görüntüler; Tüm dosyalara erişim için
    YouTube "Liste dışı" 2 kayıt: (1) izin isteme akışı (~30 sn), (2) arka planda taşıma/müzik bildirimi (~20 sn).
16. **Play Console formları:** içerik derecelendirmesi (reklam yok), Veri Güvenliği (`veri_guvenligi.md`), izin
    beyanları (`izin_beyanlari.md`).
17. **Gerçek telefonda hızlı kontrol (K20–K28, K30, K39, K11, K25):** PDF Türkçe yazı/kaydetme/WhatsApp kopya açma,
    Word klavye/çimdik/kapanış, USB takılıyken büyük PDF, menülerde Sil/Kaydet düzeni, Drive/SFTP hesabınla test,
    düzenlenmiş Word/Excel/PDF çıktılarını Microsoft Office / Acrobat / Google Dokümanlar'da açma; Android 7 varsa
    kasa açılma süresi; TalkBack denemesi.
18. **İç test → kapalı test → kademeli yayın:** imzalı AAB'yi (`build-apk.yml` elle tetik `aab=true`) iç teste at,
    Ön Lansman Raporu temiz mi bak; 12–20 testçiyle 14 gün aralıksız kapalı test (çökme < %1,09, ANR < %0,47);
    %10–20 kademeli → %100; ilk yorumlara aynı gün yanıt.

### D. Endonezya + Malezya (B17 — kod bitti, kalan yalnız senin işlerin)
19. **Mağaza, fiyat, hukuk, çeviri:** ID/MS mağaza metinleri hazır (`docs/play/magaza_metinleri.md`) — anahtar
    sözcük gözden geçirme ("pembaca PDF", "baca dokumen"); IDR/MYR yerel fiyat kademesi (m.6 ile aynı ürün);
    gizlilik politikası Endonezce + Malayca, UU PDP (2022) ve PDPA gözden geçirmesi (gelince
    `privacy_policy_screen` eşlemesi açılır); ana ekran, PDF, Kitaplık, ödeme ve hata metinlerini anadili konuşan
    biriyle gözden geçir.

### Eski referans (yalnız bilgi; kararı istenirse açılır)
K8 liste hız eşiği · K10 dış güvenlik taraması (MobSF/drozer; G12.6 bağımsız göz) · K12 AI tek belgelik maske
kapatma (kapalı kalması önerilir) · K13 OneDrive/Dropbox · K18 "tikli öğesi çok notlar kasıyor" (Notlar) ·
**PDF örnek korpusu** (eski "K41–K42" numarası; bugünkü K41 = P22b kararıyla karışmasın diye numarasız anılır —
eksik üreticiler LibreOffice, Google Docs, LaTeX, macOS Quartz).
