# PLAN — tek kalan-iş listesi (2026-11-15 birleştirmesi)

**Açık işin TEK kaynağı burası.** 2026-11-15'te KALANLAR, KONTROL_LISTEM, OTOMASYON Kuyruğu ve
8 faz planı (FAZ, DUZENLEME, GELISTIRME, YUKSELTME, PDF_PRO, GUVENLIK, FERRARI, SURUM) buraya
toplandı. Eski dosyalar **`docs/arsiv/planlar/`** altında (yalnız ayrıntı/karar kaynağı, yürütülmez).
Telefonda adım adım bakılacaklar: `docs/CIHAZ_TESTI.md`. Yürütme düzeni (zincir): `OTOMASYON.md`.

**Kurallar:** biten satır **SİLİNİR** (tik bırakılmaz) · karar / kök neden / tuzak → HAFIZA ·
cihazda bakılacak yeni şey → `docs/CIHAZ_TESTI.md` · kullanıcının yapacağı → §3 (ne · nasıl ·
doğruysa · yanlışsa) · yeni iş → §1 tablosuna yeni `P` satırı (≤ ~300 karakter).

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

## 1) Kuyruk — yapılacak işler

Durum: `bekliyor` · `sürüyor` · `cihaz bekliyor` · `kullanıcı kararı` · `takıldı: <neden>`.
Model: `fable` · `opus` · `sonnet`. Cihaz: `—` · `evet` · `A/B` (ölçüm kapısı) · `tablet`.
APK: `evet` (birleştirmede `[apk]`) · `hayır`. Kaynak yolları kısaltıldı: `arsiv/` = `docs/arsiv/planlar/`.

**SIRA (2026-11-15):** kod: P12b → P29 → P06 → P16 → P17 → P18 → P19 → P20 → P21 → P22 → P23 → P24 →
P25 → P30 → P31 (kalanlar) → P26 → P27 · telefon (boşaldıkça, tek seferde bir): P08 → P28 → P07 → P13 → P12 → P14 →
P04 → P11. Ferrari (P06, P27) bitmeden yeni özellik birleşmez — P16–P23 dalda hazırlanabilir.

### 1a) Telefon/A-B bekleyen dallar (kod bitti)

| No | İş | Model | Kaynak | Cihaz | APK | Durum |
|---|---|---|---|---|---|---|
| P08 | PDF Pro oturum belleği bütçe dışı (+56/+65 MB, bütçe +40) — `commitLive` gereksiz `needsReplay` kaldırıldı | opus | HAFIZA 2026-11-13; arsiv/PDF_PRO_PLANI 54 | A/B | evet | cihaz bekliyor — dal `faz-oto-P08-bellek` (CI yeşil), senaryo DEVIR.md |
| P28 | PDF kabuğu kırmızıları: H3.7 rozet ↔ AI düğmesi çakışması, H3.6 durum çubuğu seçeneği, H3.5 sayfa sayfa tam kaplama | opus | CIHAZ_TESTI 2026-11-14 P09 | A/B | evet | cihaz bekliyor — dal `faz-oto-P28-pdf-kabuk` (CI yeşil), A/B yarım (1+1), gözle bakılmadı |
| P07 | H1.4 son sayfa görüntüsü + H8.5 döndür / kareyi fotoğraf kaydet | opus | arsiv/FERRARI_PLANI H1.4, H8.5 | A/B | evet | cihaz bekliyor — dal `faz-oto-P07-artik`; CIHAZ_TESTI "Ferrari H1.4 + H8.5" |
| P13 | Liste/ızgara: 5.000 öğe kaydırma, Fotoğraflar ızgarası donması (B3.3c), soğuk açılış ≤ 1,2 sn | opus | arsiv/KALANLAR B3.3 | A/B | evet | birleşti (kullanıcı kararı) ama A/B KALDI: klasor_5000 p99 23,5→38,9; B3.3c + soğuk açılış cihazda yapılmadı → P12b |
| P12 | Excel: 10 bin × 20 açılış ≤ 1,5 sn (CI 1008 → 498 ms), K23 FrameTiming %99 | opus | arsiv/KALANLAR B3.1, B3.3a | A/B | evet | A/B KALDI (`xlsx_100k_acilis` p99 sıçraması) → P12b |
| P14 | Word kapanış/menü takılması (B3.3d) kök neden + Faz 37/38 Word/Slayt perf A/B | opus | arsiv/KALANLAR B3.3d | A/B | evet | cihaz bekliyor — senaryolar `word_300_menu`/`_kapanis` hazır; onay §3 K21–K22 |
| P04 | H10/H11 boş/hata durumları + görüntüleyici kabuğu | opus | arsiv/FERRARI_PLANI H10–H11 | A/B | evet | `[apk]`'sız birleşti; A/B 2 tur KALDI (gürültü şüphesi) → yeniden ölç; galeri/editör çubuğu kararı §3 K6–K7 |
| P11 | Genel cihaz turu: `CIHAZ_TESTI.md` baştan sona (Faz 34–42, Güvenlik G2.6/G3/G4/G6/G8.1, A8.2 soğuk açılış, galeri/tema elle kalanlar, 360×800 + 2× yazıda araç satırı); kırmızılar → yeni P satırı | sonnet | CIHAZ_TESTI | evet | hayır | bekliyor — telefon boşken |

### 1b) Kod işleri

| No | İş | Model | Kaynak | Cihaz | APK | Durum |
|---|---|---|---|---|---|---|
| P12b | P12/P13 A/B artıkları: `xlsx_100k_acilis` p99 128 ms (gerçekse kök neden), `xlsx_10k_x20_*` ve `*_sk` neden tabloda yok, düzelt + 3 tur ölç; soğuk açılış A tabanı | opus | docs/perf/2026-11-14-ab-1684533-*.md | A/B | evet | bekliyor |
| P29 | H4 dosya listesi büyük başlığı kaydırınca katlanmıyor; ana ekranda kalıcı "beklenmedik hata (1 kayıt)" şeridi — kök neden | opus | CIHAZ_TESTI 2026-11-14 P09 | A/B | evet | bekliyor |
| P06 | Ferrari H2 PDF kaydırma: önbellek tavanı ölç, bulanık yer tutucu, komşu sayfa ön çizimi, hızlı tutamaç önizlemesi, yakınlaştırma netleşmesi, USB okuma hızı — ölç→değiştir→ölç | opus (plan evresi fable) | arsiv/FERRARI_PLANI H2.1–H2.6 | A/B | evet | bekliyor |
| P16 | PDF Pro metin: taşma/çakışma uyarısı (punto küçült · it · genişlet), font seçici (belge → aile → paket), metne bağlantı | opus (plan evresi fable) | arsiv/PDF_PRO_PLANI 56–58 | A/B | evet | bekliyor |
| P17 | PDF Pro nesne/işaret: hizalama kılavuzu + tutunma, çoklu seçim/grup, katmanlar (OCG), kamera; serbest metin/bulut/damga, basınçlı kalem + avuç reddi, XFDF | opus | arsiv/PDF_PRO_PLANI 59–60 | A/B | evet | bekliyor |
| P18 | PDF Pro form + imza tek yüzey, form oluşturma, düz PDF'te alan algılama; form otomatik doldurma + akıllı karartma önerisi | opus (plan evresi fable) | arsiv/PDF_PRO_PLANI 61, 65/3 | evet | evet | bekliyor |
| P19 | PDF Pro OCR Pro: görünmez katman, renkli arka planda satır düzenleme | opus (plan evresi fable) | arsiv/PDF_PRO_PLANI 62 | evet | evet | bekliyor |
| P20 | PDF Pro sayfa stüdyosu (küçük resim ızgarası, geri alınabilir sayfa komutları) | opus | arsiv/PDF_PRO_PLANI 63 | A/B | evet | bekliyor |
| P21 | PDF Pro parola/izin, meta veri, optimize, PDF/A, bu kipte yazdır; AES-256 (R6) kilit açma; `PdfEditorScreen` emekliliği (filigran + taranmış satır düzeltme yeni kipe) | opus | arsiv/PDF_PRO_PLANI 64 | evet | evet | bekliyor |
| P22 | PDF Pro kalite: başarı %94 → %98 (Type3 aralık, `/Rotate`, açılı metin), 50 sayfa artımlı kayıt süresi, büyük belge/pil, görsel cila + tablet | opus | arsiv/PDF_PRO_PLANI 54, 66–68 | A/B | evet | bekliyor — P08 sonrası |
| P23 | UDF (UYAP) okuyucu — salt okuma görüntüleyici + `.udf` dosya ilişkilendirme + testler. **Biçim çözüldü (2026-11-15, kullanıcı örneği):** ZIP → `content.xml` + `documentproperties.xml`. Kök `<template format_id="1.8">`: `<content>` CDATA = tüm düz metin; `<properties><pageFormat>` (kenar boşlukları, kâğıt, yön); `<elements>` → `<paragraph Alignment FirstLineIndent>` → `<content startOffset length family size bold italic foreground>` (metni dilimler) + `<image imageData=base64>`; `<styles><style>`. Örnek KVKK gereği depoya GİRMEZ → test için sentetik `.udf` üret | opus | bu satır; HAFIZA 2026-11-15 | evet | evet | bekliyor |
| P24 | Bağımlılık bakımı: override'lar (`xml`, `pointycastle`, `dartssh2`) yeni sürüm çıktıysa kaldır; `shared_preferences_android` 2.4.28 sabit kalır; Dependabot PR'ları (#82–84, onay §3 K14) | opus | arsiv/KALANLAR Faz D | — | hayır | bekliyor |
| P25 | Levha/pencere birliği: ham `showModalBottomSheet`/`showDialog` (51+54) → `showAppSheet`/`showAppConfirm`/`showAppPrompt`, parti parti önce/sonra PNG; birleştirme onaydan sonra (§3 K17) | opus | arsiv/KALANLAR A9.1 | A/B | evet | bekliyor |
| P30 | Sürümler Lite / Pro / Kişisel: S4 manifest varyantları, S5 paket kimlikleri, S6 CI matrisi, S7 Lite → Pro geçiş, S8 mağaza metinleri, S9 Kişisel varsayılan | opus | arsiv/SURUM_PLANI S4–S9 | — | evet | kullanıcı kararı — önce §3 K15 (fiyat, adlar, tarama hangi sürümde) |
| P31 | **Ana ekran tasarım aileleri** (Fable, `docs/design/ana_ekran/`): A Sakin · B Bento · C Koyu başlık tema ailesi olarak eklendi (renk + `HomeStyle` düzeni: bellek kartı, kutu ızgarası, bölüm başlığı cümle düzeni, hızlı klasör 3 sütun, C'de iki sütunlu liste + renkli başlık) + kutularda basılı tut → sürükle-sırala / alttaki çöpe at ("not"tan). **Kalan:** D simge takımı (24 ızgara, 1,8 çizgi, %18 iç dolgu — kendi glif çizimi, şimdilik dolu `_rounded` glif renkli kutuda), F metinleri (arama "Dosya ya da özellik ara", son açılanlarda dosya adı yerine "Ekran görüntüsü · Bugün 09:31", "Tümü →" okunu kaldır, "Son tarama bugün 00:29 · 5.691 dosya", kutu adlarında cümle düzeni — K19), alt panelde ortadaki Aktar kapsülü vurgu renginde, cihazda ÖLÇÜM KAPISI (ana ekran) | opus | 2026-11-15 kullanıcı; docs/design/ana_ekran/README.md | A/B | evet | birleşti (ölçülmedi) — kalanlar bekliyor |
| P32 | **Menü ortak düzeni** (2026-11-15 kullanıcı: "çok iç içe menü, Sil'i bulamadım; her tür ortak dile kavuşsun"): ⋮ her türde (PDF, metin, Word, Excel, slayt, galeri, video, ses) AYNI dosya levhası — üstte taşı/kopyala/yeniden adlandır/önemli/SİL, altında türe özel gruplar AYRI RENKTE (`MenuTone.special`, vurgudan 120° öte); alt çubuk en çok 5, kaydırma yok; yüzen AI düğmesi alt çubuğa; Araçlar (=Düzenle›Sayfalar) ve PDF'te "PDF'e dönüştür" kalktı; grup ve ekran başlıkları büyük/kalın; net adlar. **Kalan:** üst çubukta Kaydet/↶/↷ yalnız gerektiğinde, Word'e "Aa", Kitaplık ⋮'ında "Sırala" başlığı | opus | bu satır; HAFIZA 2026-11-15 | A/B | evet | birleşti (ölçülmedi) — kalanlar bekliyor |
| P33 | **Decisions API (`gemini-decision-1`) kalan kullanımları** (2026-11-18 kullanıcı: "her türlü kullanalım"; yapılanlar: tek dosya + toplu hızlı kontrol, paylaşım kalkanı, Arapça OCR kararı — HAFIZA 2026-11-18). Kalan: (a) tarayıcı sonrası sayfa kalitesi (bulanık/kesik/parlama → "yeniden çek"); (b) Akıllı temizlik: yerel bulanık/karanlık/selamlaşma sezgisini AI ile doğrula (yanlış silme önerisi azalır); (c) "Yeni dosyalar"a düşen belgeye tür + önem puanı → "Önemli'ye ekle?" önerisi (AI kapsamı + ayar); (d) AI sohbet yönlendirici: soru belge gerektiriyor mu / basit mi → ucuz modele; (e) PDF/form: "imza alanı boş mu, form doldurulmuş mu" toplu denetim; (f) ses kaydı: konuşma dili + toplantı/not ayrımı; (g) galeri akıllı süzgeç (belge fotoğrafı / ekran görüntüsü / kişisel) dizinde önbellekli | opus | bu satır | evet | evet | bekliyor |
| P26 | Mağaza ekran görüntüleri (son görünüm, TR/EN/AR) → `docs/play/` | sonnet | arsiv/KALANLAR B2 | evet | hayır | bekliyor — en sonda |
| P27 | Ferrari son kapı: "10 işlem" son ölçüm + Samsung kıyası (> %20 yavaş değil), erişilebilirlik (≥ 48 dp, karşıtlık, büyük yazı), tasarım görüntüleri, özellik dondurma kalkar | sonnet | arsiv/FERRARI_PLANI H12 | A/B | evet | bekliyor — hepsi bitince, kullanıcıyla |

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
