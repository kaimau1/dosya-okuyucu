# KALANLAR — tek kalan-iş listesi (2026-11-01 toplaması)

> **Bütün açık işler burada, iki fazda:**
> **Faz A ☁️** — bulut oturumunda baştan sona yapılabilenler ·
> **Faz B 📱💻👤** — telefon (📱), yerel Windows bilgisayar (💻) ya da kullanıcının
> hesabı/kararı (👤) gerekenler.
>
> **Kaynak:** eski KALANLAR, `docs/FAZ_PLANI.md` (Faz 0–19, K1–K17),
> `docs/DUZENLEME_PLANI.md` (Faz 20–33, K18–K25), `docs/CIHAZ_TESTI.md`, HAFIZA ve
> 2026-11-01 kod taraması (`main` @ `9ae256a`, build 444, CI yeşil). Eski listelerdeki
> **biten maddeler silindi**; bayat olanlar güncellendi ya da kaldırıldı.
>
> **Kurallar:** biten madde **SİLİNİR** (tik koyup bırakılmaz) · karar / kök neden /
> tuzak HAFIZA'ya yazılır · cihazda bakılacak yeni şey `docs/CIHAZ_TESTI.md`'ye girer ·
> her madde **ne · nerede · bitti ölçütü** taşır. FAZ_PLANI ve DUZENLEME_PLANI artık
> karar/bulgu kaynağı; **yürütme sırası bu dosyadır.**

| Faz | Ortam | Bölümler | Tahmini |
|---|---|---|---|
| **A** | ☁️ bulut | kod işleri bitti (2026-11-12); kalan A1.2 dal temizliği + A9.1 levha birliği — kullanıcı onayıyla | — |
| **B** | 📱💻👤 | B1 yerel küçük işler · B2 cihaz turu · B3 cihaza bağlı takip · B4 Office uyumluluk · B5 hesap/karar · B6 sürüm adayı | 1–2 cihaz oturumu + hesap işleri |

---

## Faz A — Bulutta yapılabilenler ☁️

**Ortak "bitti":** `flutter analyze` 0 · `flutter test` yeşil · cihazla doğrulanacak yeni
şey `docs/CIHAZ_TESTI.md`'de · HAFIZA'ya tarihli kayıt · bu dosyadan madde silindi ·
main'e birleşti, CI yeşil. **`dart format` KOŞTURMA** (HAFIZA tuzakları).

**2026-11-12: Faz A'nın kod işleri bitti** (A3, A4.1b, A4.2–A4.4, A5, A6.5–A6.6, A7, A8.1,
A9.2, A10 bizim taraf — HAFIZA "Faz A kapanışı"). Kalan iki madde YALNIZ kullanıcı onayı/izniyle
yürüyebiliyor:

- [x] **A1.2 Uzak dalları temizle** (2026-11-13: 116 dal silindi, yalnız main + Dependabot). 114 dal; 94'ü main'e tam girmiş, 19'unda main'de
      olmayan 1–12 commit (faz-54, faz-G0/G1/G2, dependabot ×3, eski `claude/*` ×7 …). Bulut
      oturumunun git vekili oturum dalı dışındaki dalları silmeye 403 veriyor → GitHub arayüzünden
      ya da yerel `git push --delete`. **Bitti:** `git ls-remote --heads origin` yalnız `main` +
      süren oturum dalları.
- [ ] **A9.1 Levha/pencere birliği (👤 parti parti onay, görsel fark riski):** 51
      `showModalBottomSheet` + 54 `showDialog` (2026-11-12 sayımı) → `showAppSheet` /
      `showAppConfirm` / `showAppPrompt`. Her parti için önce/sonra PNG (`tool/design_shots_*`),
      kullanıcı onayı; son bakış B2.

---

## Faz C — Geliştirme fazları (2026-11-04, kullanıcı isteği) ☁️📱
Ayrıntı ve bitti ölçütleri: **`docs/GELISTIRME_PLANI.md`** (Faz 34–42: pano cilası ·
pro belge tarayıcı · Excel · Word · Slayt · PDF · ortak görünüm · dosya yöneticisi · kalite).
**Her faz `GELISTIRME_PLANI.md` baştaki PERFORMANS KORUMA ANAYASASI'na uyar** (izolat, tembel yükleme, PerfBudget, boşta 0 kare, perf kapısı + A/B tablo).
Faz 35'in ilk adımı **ML Kit geçişi** (onaylandı; kullanıcı başlatacak).
Önerilen sıra: 34 → 35 → 39 → 36 → 37 → 38 → 40 → 41 → 42. **Faz 34 BİTTİ** (kod; cihaz doğrulaması `CIHAZ_TESTI.md`). **Faz 35 BİTTİ** 2026-11-05 (ML Kit `GmsDocumentScanner` + pro tarayıcı; cihaz turu + perf A/B bekliyor). **Faz 39 BİTTİ** 2026-11-05 (PDF pro: dijital imza, karartma, Excel/Word/PDF-A, karşılaştırma, izin/yer imi/damga/numara, okuma, agresif sıkıştırma, sayfa/form/dönüştürme/paraf; cihaz turu + perf A/B bekliyor). **Faz 36 BİTTİ** 2026-11-05 (Excel pro: özet tablo, koşullu biçim yazma/yönetici, mini grafik, dinamik dizi/LET/yapısal başvuru, parolalı xlsx, yazdırma alanı/PDF, içe aktarma/ara toplam/anahat, biçim boyacısı/tema, formül denetimi/hedef ara, grafik kombinasyon/eğilim, sayfa koruması; cihaz turu + perf A/B bekliyor). **Faz 37 BİTTİ** 2026-11-05 (Word pro: stil güncelle/tema, sayfa düzeni + baskı önizleme, denklem LaTeX↔OMML, tablo birleştir/böl/kenarlık/sığdır/sırala, şablon galerisi, karşılaştır/belge ekle/gözden geçirme çubuğu/parola, sesle yazma + satır içi AI, PDF/yazı tipi gömülü docx/ODT/RTF/MD, gezinti ağacı/küçük resim/okuma süresi, metin kutusu/şekil/sarma/kapak/bölüm/alan/çapraz başvuru/kaynakça, AI yazım denetimi, okuma kipi; cihaz turu + perf A/B bekliyor). **Faz 38 BİTTİ** 2026-11-05 (Slayt pro: ana slayt/yerleşim + tema, 8 şablon + metinden slayt önerisi, grafik/tablodan grafik/SmartArt→şekil, ses/video + lazer/kalem/zamanlayıcı, sunucu görünümü + PNG/MP4, hizala/dağıt/katman/animasyon sırası, bölüm/özel gösteri, şekil kitaplığı/bağlayıcı/efekt/kırpma/arka plan/tablo biçimi/köprü/sayaç, ses tuşu + yerel ağ kumanda/anlatım/ikinci ekran; cihaz turu + perf A/B bekliyor). **Faz 40 BİTTİ** 2026-11-05 (ortak görünüm: tek üst çubuk + bağlam şeridi, Motion geçişleri + boş durum çizimleri, 2×/TalkBack/kontrast bekçileri, rehber + örnek belgeler, ayarlarda Önerilenler, kapanış güvencesi, tek Paylaş/Dışa aktar, tema ön ayarı + vurgu rengi, eksik çeviri taraması, iskelet + tek tip hata yüzü; cihaz turu + perf A/B bekliyor). **Faz 41 BİTTİ** 2026-11-05 (çift bölme, SD SAF yazma, ad kalıpları; Drive çevrimdışı + çakışma; içerik dizini (OCR dahil) + kayıtlı aramalar; kısa ömürlü bağlantı; akıllı temizlik önerileri; etiket/klasör rengi + favori sırası; bölünmüş arşiv; uzak indirmede devam + artımlı arama dizini; OneDrive/Dropbox B5.8'de hesap kararı bekliyor; cihaz turu + perf A/B bekliyor). **Faz 42 BİTTİ** 2026-11-06 (bağımlılık bütçesi + açılış bekçisi; 100 MB xlsx akış önizlemesi + PDF araç bellek bekçisi; Hata kayıtları → Sorunu bildir (anonim özet, kare dağılımı); sürüm adayı turu + fastlane mağaza varlıkları; CI perf kapısı + APK taban %2; integration_test senaryoları; R8 kuralları + `.r8test` A/B betiği; cihaz turu + perf A/B bekliyor). **Faz C'nin tüm fazları bitti.**

## Faz D — Yükseltme fazları (2026-11-07, kullanıcı isteği) 💻📱
Ayrıntı ve kapılar: **`docs/YUKSELTME_PLANI.md`** (Faz 43–50: ölçüm tabanı · Flutter 3.47.9 ·
saf Dart zinciri (xml 7/pdf/syncfusion 35) · Android eklentileri · google_sign_in 7/ML Kit 1.0/SSH ·
**pdfrx 2.12 (önce kök neden ölçümü)** · temizlik · sürüm adayı). Yerel Windows + USB telefon; cihaz
kapısı (> %10 ya da p99 > 24 ms → birleşmez). Sıra 43 → 50. A3.4b bu fazlara taşındı.
- [ ] Faz 43 artığı 📱 — **Mi Note 10 Lite tabanı alındı (2026-11-13, `docs/perf/2026-11-50-sonuc.md`)**; kalan: Xiaomi 13T, P6 (👤 erişilebilirlik hizmetini kullanıcı açsın), P12 ilk kare, duman turunun elle maddeleri (taban MatePad’da alındı → `docs/perf/2026-11-43-taban.md`): Xiaomi 13T + Mi Note 10 Lite tabanı (P1–P12), P6 (erişilebilirlik açık), P4/P5 ekran kaydı + yakınlaştırma, P12 video; duman turunun elle maddeleri.
- [x] İncele 📱 (2026-11-13, Mi Note 10 Lite): `VIEW video/*` hata DEĞİL — "Video neyle açılsın?" penceresi çıkıyor (seçince oynatıcı oynuyor; MatePad'de arkadaki pano görülmüş). `SEND` → Aktar = tasarım (2026-11-03). Kod değişmedi.
- [ ] **Faz 43–50 bitti** (son tablo `docs/perf/2026-11-50-sonuc.md`). Kalan 👤: `v1.2.N` etiketi (kullanıcı atar — kalıcı sürüm arm + arm64 + AAB).
- [ ] Faz 50 artığı 📱: ikinci cihaz (Xiaomi/Mi Note 10 Lite) tam §2; xlsx 100 bin için daha uzun kaydırma senaryosu (şimdiki 3–34 kare, p99 ≈ en kötü kare); `CIHAZ_TESTI.md` "Faz 49" elle maddeleri (çevrimdışı kip, AI onayı, Klasör ekle, Neler yeni).
- [ ] UDF (UYAP) okuyucu — Play yorum çalışmasında aday (P2, orta-büyük); biçim araştırılmadı.
- [ ] Faz 48 artığı 📱: **P6** (erişilebilirlik hizmeti gerçekten açık, PDF-B kaydırma) GMS'li/Xiaomi cihazda; yakınlaştırma keskinliği (basamaklı ölçek kalktı — iki parmak elle); `CIHAZ_TESTI.md` "Faz 48".
- [ ] Faz 45–47 artığı 📱: GMS'li cihazda Drive girişi (google_sign_in 7 yetkilendirme yolu) + ML Kit OCR/çeviri model indirme; gerçek SFTP/FTP sunucusunda (NAS) bağlan/aktar (yerel asyncssh/pyftpdlib ile yeşil); "Başka uygulamada aç" köprüsü (video/ses/apk, READ_MEDIA_* yok) elle; dosya seçici (file_picker 13) çoklu seçim + büyük dosya; paylaş (share_plus 13); bildirim (flutter_local_notifications 23) — `docs/CIHAZ_TESTI.md` "Faz 45–47".
- [ ] Override'lar (Faz 45/47): `xml` (webdav_client), `pointycastle` (smb_connect), `dartssh2` (ftpconnect) — paketler yeni sürüm çıkarınca sil; `shared_preferences_android` 2.4.28 sabit (2.5.4'te de süreç geneli kayıt silinmesi).
- [ ] Faz 44 artığı 📱: P9/P12 ve duman turunun elle maddeleri 3.47'de; Xiaomi'de P5 kuyruğu (+%14–18 MatePad'de) yeniden ölç.

## Faz E — PDF Pro: profesyonel PDF düzenleyici (2026-11-08, kullanıcı isteği) ☁️💻📱
Ayrıntı, kök nedenler, mimari kararlar (PK1–PK8) ve bitti ölçütleri: **`docs/PDF_PRO_PLANI.md`**
(her fazın altında 2026-11-13 **Durum** satırı). Ölçüm: `docs/perf/2026-11-pdfpro-55-65.md`.

**2026-11-13 durumu:** Faz 55 (düzen), 56 (yazı tipi sadakati — motor), 57 (yerinde yazma — kod),
58 (metin araçları), 59 (nesne — çekirdek), 60 (işaretleme — çekirdek), 64 / 1–2 (gerçek karartma +
KVKK), 65 / 1–2 (AI yerinde), 66 / 2–3 (bulanık + uzun oturum) yazıldı ve main'de. Yeni kip
varsayılan (`pdf_pro_engine`), eski düzenleyici ⋮ menüsünde. **Hiçbiri cihazda denenmedi.**

- [x] 📱 **Cihaz kapısı (2026-11-13, Mi Note 10 Lite):** Faz 54 1–12, Faz 55–65 1–20, bulgular 1–5
      koşuldu (`docs/CIHAZ_TESTI.md` koşu kayıtları); 7 hata düzeltildi (90999e27, 56a78ae9, afd39705,
      dc527cf4, 4ecc90f3, 3cc7467b, 9197a180). Kalanlar aşağıda.
- [x] 💻 **Dekont / tablo satırı düzenleme (2026-11-13, kullanıcı bulgusu):** 1 em boşluk, satır birleşmesi,
      Kaydet'te kopya/üstüne yaz sorusu — kök nedenler HAFIZA; 📱 doğrulama `docs/CIHAZ_TESTI.md`
      "PDF Pro — dekont/tablo satır düzenleme" (bekliyor).
- [ ] 👤 **Elle (kullanıcı):** iki parmak yakınlaştırma (düzenleme, seçim, yakınlaştırılmışken taşıma/yazı);
      Türkçe harf (ğüşıöçİ) ve Çince ret yazımı (adb ASCII dışı yazamıyor); Gboard önerisi/otomatik
      düzeltme/sesle yazma, tuş ve kalem gecikmesi hissi; başka uygulamadan "birlikte aç" + Kaydet
      (salt okunur konum); kaydedilen PDF'in Acrobat/Chrome'da görünümü; AI Yeniden yaz/Çevir
      (anahtar); 5 dk boşta pil/ısı.
- [ ] 📱 **Oturum belleği bütçe dışı:** 3 paragraf düzenlemesi +56 / +65 MB (bütçe +40). Geçici kayıt
      A/B'de suçsuz çıktı. Test ölçümü (2026-11-13, `pdf_pro_memory_test`): geri al yığını + canlı belgede
      KALAN düzenleme başına ~10 KB (sayfa kopyası küçük) → suçlu değil. Yük tuş başına geçici iş: her tuşta
      paragraf iki kez dizilir (geçici sayfa kopyasında prova + canlı), tuş başına ~2–3 MB yerel çöp, ayırıcı
      işletim sistemine geri vermez (30 tuşta tepe +70–90 MB). Karakter başına anahtar kurma düzeltildi;
      **cihazda yeniden ölçülecek**. Hâlâ aşıyorsa sıradaki: provayı tuşta atlamak / görüntüleyicinin tuş
      başı tam sayfa yeniden çizimi (HAFIZA 2026-11-13 "oturum belleği").
      **A/B (2026-11-13, Mi Note 10 Lite, 50 sayfa, TOTAL PSS):** normal 400 / 337 MB · kayıt kapalı 368 / 363 MB →
      fark yok (gürültü); geçici kayıt suçlu DEĞİL. Öneri: kurtarma davranışı DEĞİŞMESİN; bütçe aşımı için sıradaki aday
      adım başına sayfa anlık görüntüsü + yedek font (PSS mutlak; tek-oturum taban farkı hâlâ ölçülmedi).
- [x] 📱 **§6 gecikme bütçeleri (2026-11-13 cihazda ölçüldü, hepsi bütçe içinde — `docs/perf/2026-11-pdfpro-54-oturum.md`):** `PDFPRO_PERF` logu eklendi (638e5f75 — kipe_gecis, uygula, geri_al,
      yinele, kaydet, tus; biçim `docs/perf/2026-11-pdfpro-55-65.md`). Kalan: `.r8test` profil APK'sıyla
      cihazda topla, p50/p95'i tabloya yaz (dokun→imleç ayrı ölçülmüyor).
- [x] **Aynı PDF iki kez açık** (dc5b57d3): belgenin tek düzenleme sahibi; ikinci görüntüleyicide Düzenle
      → düzenleyen görüntüleyiciye dönülür + ileti. 📱 cihazda bir kez dene.
- [x] **Küçükler** (d1995342): Çoğalt kopyayı alttaki ilk boşluğa koyuyor; Silgi işaretleme şekillerini
      (yeni çizilen dikdörtgen/ok/elips/çizgi) siliyor. Kalan: büyüyen paragraf alttakinin üstüne biniyor
      (Faz 57 artığı); bu düzeltmeden önce çizilmiş şekiller yine Görsel aracıyla. 📱 cihazda bir kez dene.
- [ ] **Faz 57 artığı:** taşma/çakışma uyarısı + seçenekler (punto küçült · alttakileri it · genişlet);
      yazı tipi değiştirme + satır aralığı/girinti arayüzü; sistem seçim tutamaçları ve büyüteç;
      RTL (Arapça) yazma — harf birleştirme yazıcıda yok, blok kilitli.
- [ ] **Faz 56 artığı:** font seçici (belge fontları → eşleşen aile → paket), isteğe bağlı font paketi
      (Caladea, Cousine, Gelasio, Noto Naskh…), büyük harf yüksekliği ölçekleme, SSIM ölçümü.
- [ ] **Başarı %94 → %98:** Type3 (matplotlib) aralık sabitleme; tezgâhın `/Rotate` ve açılı metin
      ölçümü (düzenleme doğru, tezgâh satır sırasını bulamıyor).
- [ ] **Faz 58 / 7:** metne bağlantı ekle/düzenle/kaldır.
- [ ] **Faz 59 artığı:** hizalama kılavuzları + tutunma, çoklu seçim/grup, katmanlar (OCG), kamera/
      tarama/panodan görsel, saydamlık.
- [ ] **Faz 60 artığı:** serbest metin/bulut/damga, basınçlı kalem + avuç içi reddi, XFDF,
      `pdf_ink_screen` emekliliği, `mutool` ile ikinci çizici doğrulaması.
- [ ] **Faz 61 (yapılmadı):** form + imza tek yüzeye; form oluşturma; düz PDF'te alan algılama.
- [ ] **Faz 62 (yapılmadı):** OCR Pro — görünmez katman, arka plan renkli satır düzenleme,
      "sayfayı düzenlenebilir yap".
- [ ] **Faz 63 (yapılmadı):** sayfa stüdyosu (küçük resim ızgarası, geri alınabilir sayfa komutları,
      kırpma, üst/alt bilgi, yer imleri). Şimdilik yalnız "sayfayı döndür" geri alınabilir.
- [ ] **Faz 64 / 3–5 + artık:** parola/izin, meta veri, optimize, PDF/A, yazdır bu kipte yok (araçlar
      ekranında); karartmada meta veri/gömülü dosya temizliği ve adres kalıpları; görsel pikseli
      karartma yolunun testi.
- [ ] **Faz 65 / 3:** form otomatik doldurma, akıllı karartma önerisi.
- [ ] 💻📱 **Faz 66 / 1, 4, 5 · Faz 67 · Faz 68:** büyük belge/pil ölçümü, görsel cila + tablet +
      erişilebilirlik + ilk kullanım, rakip turu ve sürüm adayı.
- [ ] **`PdfEditorScreen` emekliliği:** filigran ve taranmış satır düzeltme yeni kipe taşınınca
      `lib/screens/pdf_editor*` + çalışma kopyası + eski `PdfEditJournal` silinir.
- [ ] **Faz 54 ölçüm açıkları:** 50 sayfalık belgede artımlı kayıt süresi, tek oturumun ek belleği
      (`session_bench_test` güncellemesi — yeni yazıcıyla yeniden denenmedi).
- [ ] 👤 **Faz 53 maket onayı — itiraz varsa düzelt:** https://claude.ai/artifact/PNjvf5wSp5ae2rY56RpNQW
      (yüzen blok çubuğu yerine bağlamsal çubuk kullanıldı — `etkilesim.md` §5 notu).
- [ ] 👤 **Külliyata eksik üreticiler:** LibreOffice, Google Docs, LaTeX, macOS Quartz (CORPUS.md'de 12 üretici).
- [ ] **AES-256 (R6) kilit açma** — eski Syncfusion yolu; `PdfEditorScreen` emekliliğiyle kapanır.
- [x] `graphify update .` (2026-11-13, yerel: 33 945 düğüm).

---

## Faz S — Sürümler: Lite / Pro / Kişisel (2026-11-10, kullanıcı kararı) ☁️📱👤

Plan: `docs/SURUM_PLANI.md`. A6.5 (Billing iskeleti) ve B5.2 bu kararla **düştü** (Pro ayrı ücretli uygulama).

- [x] S1 sürüm kapısı (2026-11-12) · [~] S2 arayüz kapıları (pano araçları) · [~] S3 Pro levhası + ayar satırı · S4 manifest varyantları · S5 paket kimlikleri · S6 CI · S7 Lite→Pro geçiş · S8 mağaza · S9 Kişisel
- [ ] 👤 fiyat, uygulama adları, taramanın yeri, "Tüm dosyalar" reddinde yol (§5)

---

## Faz F — Güvenlik fazları (2026-11-10, kullanıcı isteği) ☁️📱👤

Plan: `docs/GUVENLIK_PLANI.md` (G0–G12; sıra ve açılış istemi orada). Play için asgari küme: G0, G1, G2, G4, G6, G9.1–9.3, G10.1.

- [ ] 👤 G0 artığı: `SECURITY.md` içindeki `GUVENLIK_ADRESI_BELIRLENECEK` yer tutucusuna güvenlik e-posta adresi (G0 kodu bitti)
- [x] Faz G1 platform (kod bitti, 2026-11-11; cihaz maddeleri `docs/CIHAZ_TESTI.md` "Faz G1")
- [ ] G1 artığı: (a) ✔ 2026-11-12 kod tarafı: APK kurma / yüklü uygulamalar / oto güncelleme `Edition`'a bağlı, Play sürümlerinde gizli — kalan: manifestten çıkarma S4 + B5.3 kararı 👤; (c) eski (imzasız) sabitlenmiş ana ekran kısayolu uyumu `Extras.pathAccepted` — eski kısayollar kalmayınca imzasız kolu kaldır
- [x] Faz G2 sırlar (kod bitti, 2026-11-11; cihaz maddeleri `docs/CIHAZ_TESTI.md` "Faz G2")
- [x] 2026-11-12 (main): G4.5 boş disk (507/452), G6.5 ses sunucusu Host/Origin, G7.2 arşiv yol testleri, G7.5 CSV formül koruması, G7.10 uzantı aldatması, G9.2 CI en az yetki, G9.3 kalıcı imza zorunlu — cihaz maddeleri `docs/CIHAZ_TESTI.md` "Güvenlik G4.5 / G6.5 / G7.x"
- [x] 2026-11-12 (main, 2. tur): G2.6 hassas pano, G6.1–G6.4 WebView (CSP, gezinti kilidi, dosya erişimi, kanal sınırı), G7.6 PDF bağlantı şeması, G8.1 SFTP TOFU, G9.1 Action SHA, G9.4 Dependabot, G9.6 güncelleme SHA-256 + ana makine, G10.3 kasa AI'ya kapalı (+ kasa dosyası son açılanlara/kısayola yazılıyordu — düzeltildi), G12.1–G12.4 (`docs/guvenlik/SURUM_KONTROL.md`, `MASVS.md`, `OLAY.md`, `ci/min_guvenli_surum.txt`) — cihaz maddeleri `CIHAZ_TESTI.md` "Güvenlik G2.6 / G6 / G8.1 …"
- [x] 2026-11-12 (main, 3. tur): G7.9 bulanık test (10 ayrıştırıcı; bulgu: Office şifre çözmede spinCount/anahtar boyu denetimsizdi → sınırlandı), G9.4 osv-scanner + G9.10 MobSF (`guvenlik-taramasi.yml`, haftalık), G9.8 APK doğrulaması (debuggable/yedek/şifresiz trafik/izin tabanı/imza), G9.9 gömülü JS + yamalı paket özetleri, G10.4 tek ağ kapısı `NetGuard` (+ bekçi testi), G10.5 "Verilerimi sil" + politika, G7.4 Word düzenleyici bağlantı şeması, G7.6 kapandı (PDF eki açma yok), G12.5 — cihaz maddeleri `CIHAZ_TESTI.md` "Güvenlik — genel elle tur"
- [ ] G9.8 artığı: 👤 `SIGN_CERT_SHA256` repo değişkeni (imza parmak izi karşılaştırması). (İzin tabanı 2026-11-12'de dolduruldu, kip katı; `READ_PHONE_STATE` manifestte `tools:node="remove"` ile çıkarıldı.)
- [ ] Güvenlik artıkları (2026-11-12): ~~G6.6~~ (yapıldı); G7.4 kayıtta makro korunuyor mu (bilgi iletisi 2026-11-12'de eklendi); G9.9 ses motoru dosyalarının özeti (HF `resolve/main` değişken); G2.6 ✔ (Yakındakiler erişim adresi hassas kopya; başka parola kopyası yok); "Verilerimi sil"e kayıtlı bağlantılar/anahtarlar seçeneği (bilinçli dışarıda)
- [ ] G6.5 artığı: ses sunucusunda rastgele yol öneki (aynı cihazdaki başka uygulamaya karşı) — kurulumda yeniden yazılan çalışan betikleri mutlak yol (`/antalia/vendor/ort/…`) kullanıyor; önek için yeniden yazımın da öneki eklemesi gerekir.
- [ ] G2 artığı: Keystore sarılı sırlar (Gemini, uzak/FTP parola) eski bir sürüme geri dönülürse okunamaz — kullanıcı yeniden girer (bilinçli ödün, sürüm notunda); OpenSubtitles anahtarı APK ikilisinde (dart-define) — Pro'da vekil sunucu düşünülür
- [ ] G3 artığı 📱: `docs/CIHAZ_TESTI.md` "Faz G3" (yerel PBKDF2 süresi, parmak izi CryptoObject, yeni parmak izi ekleyince geçersizleşme, eski kayıt göçü). Android 7'de (yerel PBKDF2 yok) saf Dart 600 bin tur ≈ 10 sn+ — ölçülmedi; uzun sürerse Android 7 için tur düşürme kararı 👤
- [ ] G4 artığı 📱: `CIHAZ_TESTI.md` "Faz G4" (G4.2 ✔ / G4.4 ✔ 2026-11-13; G4.5 başlık ≤ 16 KB değmez kararı; G4.8 ✔)
- [x] 2026-11-13 (main, 4. tur): G10.1 açık rıza tamam (eğitim uyarısı + rızasız sessiz otomatik tur yok), G4.2 8 karakterlik karışık parola, G4.4 6 haneli kod, G7.8 kurulum öncesi imza parmak izi (Kişisel), G11 R8 denetimi — cihaz maddeleri `CIHAZ_TESTI.md` "Güvenlik — 4. tur". **Play asgari kümesi (G0, G1, G2, G4, G6, G9.1–9.3, G10.1) kodda tamam.**
- [ ] Kalan: G7.1 artığı (oran aşımında kullanıcıya sorma yok — ret; `.bz2/.xz` 2026-11-12'de sınırlandı), G7.3 artığı (yazıcı/yama yolları; yalan başlık 2026-11-12'de kapandı — `archive` açmayı başlıktaki boyutla kesiyor), G7.4 artığı (makro), G7.8 ✔ 2026-11-13 · G8.2 ✔, G8.4 ✔ (misafir uyarısı yok), G8.5 👤 (B5.5), G8.6 ✔ · G9.5 👤, G9.7 👤 · G10.2 artığı (tek belgelik kapatma) · G12.6 👤 (G5, G11 isteğe bağlı)

---

## Faz H — Görünüm ve his: "Ferrari planı" (2026-11-14, kullanıcı isteği) ☁️💻📱👤
Ayrıntı, kurallar, madde madde yapılış ve açılış istemi: `docs/FERRARI_PLANI.md`. Bitti ölçütü: §2'deki 10 işlemde
Samsung Dosyalarım ile yan yana videoda geride görünmemek (H12 kapısı). Plan sürerken yeni özellik açılmaz.
- [ ] H0 Ölçüm tabanı ve rakip videosu 📱💻
- [ ] H1 PDF açılış hissi — H1.1–H1.3 bitti (2026-11-14); kalan **H1.4 📱 cihaz bekliyor** (son sayfa görüntüsü + ölçüm), H1.5 → H6.3; cihaz turu `CIHAZ_TESTI.md` "Ferrari H1"
- [ ] H2 PDF kaydırma akıcılığı 📱💻
- [ ] H3 PDF okuma konforu — kod bitti (2026-11-14, H3.1–H3.7: çift dokunma + akıllı yakınlık, görsel kipi, kenar kırpma, sayfa sayfa, durum çubuğu, solan rozet); kalan **📱 cihaz turu** `CIHAZ_TESTI.md` "Ferrari H3"
- [x] H4 Dosya listesi: Samsung düzeyi ☁️ — bitti (2026-11-14); H4.3/H4.4 kullanıcı kararıyla uygulanmaz; cihazda bakış `CIHAZ_TESTI.md` "Ferrari H4"
- [x] H5 Ana ekran sadeleştirme ☁️ — bitti (2026-11-14): yeni varsayılan sıra son dosyalar · kategoriler · bellek; güncelleme şeridi tek satır; H5.3/H5.4 zaten vardı; cihazda bakış `CIHAZ_TESTI.md` "Ferrari H5"
- [x] H6 Hareket ve dokunuş ☁️ — bitti (2026-11-14): titreşim kapsamı, basma hâli, görsel → galeri büyüme geçişi, levha bekçisi, Android 14+ öngörülü geri önizlemesi; **H6.4 liste satırı kapanış animasyonu ölçüm turuna** (H2/H12, 2.000+ öğe cihazda); PDF/Office kapsayıcı geçişi H11.3 ile; cihazda bakış `CIHAZ_TESTI.md` "Ferrari H6"
- [ ] H7 Sadeleştirme: bildirim, menü, ipucu ☁️👤
- [ ] H8 Video kırpma / kesme — kod bitti (2026-11-14, H8.1–H8.4, H8.6); kalan H8.5 döndür + kareyi kaydet, **📱 cihaz turu** `CIHAZ_TESTI.md` "Ferrari H8" + "Video düzenle" (2026-11-14: ara kesimler, bölge sesi kapat/ekle)
- [ ] H9 Tablet ☁️📱
- [ ] H10 Boş, yükleniyor, hata durumları ☁️
- [ ] H11 Görüntüleyici kabuğu tutarlılığı ☁️
- [ ] H12 Son kapı 📱👤

## Faz B — Diğerleri 📱💻👤

### B1 — Yerel Windows oturumu küçük işleri 💻

(B1 bitti — 2026-11-02: `.r8test` profil APK'sı ve ölçüm verisi hazırlığı; tarif HAFIZA.)

### B2 — Cihaz turu 📱 (FAZ_PLANI 12b + DUZENLEME 33 cihaz kısmı + Faz 4 ölçümleri)

- [ ] **A8.2 doğrulaması:** soğuk açılışta `ACILIS ai-index` izolatta, ilk kare raster
      < 218 ms hedefi (`_logSlowStartupFrames`); pano `initState` artığı ucuz mu.
- [ ] **`docs/CIHAZ_TESTI.md`'yi baştan sona geç** (2026-11-01 ilk tur tek telefonla, ADB:
      §1'de CPU/RAM/açılış dolu; açılış duman testi, QR gönderim, odak, parola, FTP, seçici kipi geçti. Elle/donanımla
      yapılacak bölümler duruyor). En az iki telefon (biri düşük
      donanımlı, FAZ_PLANI Ek D), Yakındakiler için ikinci telefon, Bluetooth klavye,
      varsa tablet/DeX. Kırmızılar aynı oturumda düzeltilir; sonuç HAFIZA'ya.
      Ölçüm verisi telefona `.nomedia`'lı klasörde konur, iş bitince silinir.
- [ ] **Mağaza ekran görüntüleri** (A6.3'ten, 2026-11-02): metinler güncel
      (`docs/play/magaza_metinleri.md`), görüntüler son görünümle telefonda alınmalı —
      bulutta `tool/design_shots_test.dart` geçici klasör yolunu ve eksik rozetleri gösteriyor,
      mağazaya uygun değil. Düzenleme turu (Word/Excel/Slayt/PDF), Yakındakiler, kırık beyaz
      tema, iş sonucu ekranı; TR/EN/AR.
- [ ] **Galeri/tema geliştirmesi elle kalanlar** (2026-11-08, CIHAZ_TESTI "Galeri/tema geliştirme"): AI anahtarlı
      cihazda "AI ile ikinci ad ver" + ikinci adla arama (3); Xiaomi'de uzun ses listesi kaydırma (2) ve Gece'nin
      OLED'de görünümü (1). Önce görüntüsü alınmadı (ana uygulamanın teması değiştirilmedi) — yalnız "sonra" var.

### B3 — Cihaz sonucuna bağlı takip işleri (B2 içinde ya da hemen sonra; kod bulutta da yazılabilir)

- [ ] **B3.1 K23:** Excel 10 bin satırda profil `FrameTiming` %99 > 16 ms ise (b) tek
      boyacı ızgara (debug prototipi ~4× hızlı; HAFIZA).
- [ ] **B3.2 Word Mobil görünüm editörü telefonda onaylanınca** (K18 kontrol noktası,
      CIHAZ_TESTI §Word): eski WebView `contenteditable` düzenleme yolu (`labWordEditor`
      bayrağı, `screens/editors/word/shell.dart`, `viewer.html` düzenleme köprüsü) ve
      `lib/labs/word_editor/` prototipi silinir — K19 (b) "Faz 23 sonunda kalkar"
      demişti. Onaylanmazsa kök neden yazılır, editör düzeltilir.
- [ ] **B3.3a Excel açılışı:** 10 bin × 20 Mi Note 10 Lite'ta 7,7–8,9 sn (DOM'suz okuyucudan önce ~20 sn), hedef ≤ 1,5 sn.
      Sırada: `XlsxReader.read` sonrası nerede vakit gidiyor ölç (`_rowsFrom`, ilk çizim); gerekirse hücreleri tembel kur.
- [ ] **B3.3b Mi Note 10 Lite sınırdakiler (2026-11-02, profil APK):** 5.000 öğe kaydırma
      %99 19–27 ms (hedef 24; yavaş karelerde raster baskın, Impeller GLES — Skia daha kötü);
      galeri 2.000 küçük PNG sonrası RSS 355 MB (hedef 350). Kök neden için DevTools zaman
      çizelgesi (profil APK, `flutter attach`) gerekir; tahminle yama yok.
- [ ] **B3.3c Fotoğraflar ızgarası kalan donma (2026-11-03):** küçük resim düzeltmesinden sonra ekran kaydında
      4.–5. savurmada 13–17 karelik donma kaldı, Flutter karesi temiz. Önce SurfaceFlinger `--latency` (uygulama
      katmanı) ile gerçek mi kaydedici artığı mı ayır; gerçekse GPU/doku tarafı (Impeller GLES). Yöntem HAFIZA.
- [ ] **B3.3d Word kapanış/menü takılması (2026-11-03):** açılış işi izolata alındı; kalan şüpheli
      `DocxView`'ın **hybrid composition** WebView'ı (`displayWithHybridComposition: true`, netlik için
      2026-08-06 seçildi): HC'de Flutter karesi platform izleğinde çizilir, WebView'ın üstüne açılan her
      şerit/levha/menü ayrı katman ister ve sayfa geçişinde platform görünümü kaydırılır. Profil APK'da
      Word kapat/şerit aç zaman çizelgesi al; HC suçluysa seçenekler: geçiş/levha süresince WebView'ın
      anlık görüntüsünü göster ya da TLHC + `devicePixelRatio` ölçekli çizim (netliği yeniden ölç). Tahminle
      kip değiştirme — netlik kullanıcının açık isteği.
- [ ] **B3.3 Faz 4 bütçe aşımları** (soğuk açılış ≤ 1,2 sn, 5.000 öğe kaydırma %99 ≤ 24 ms,
      galeri 2.000 fotoğraf RSS ≤ 350 MB / hafif ≤ 250 MB, boşta 0 kare) ve DUZENLEME §7
      bütçeleri → aynı oturumda düzelt.
- [ ] **B3.4 Duruma bağlı düzeltmeler:** Excel'de kaydırma sürerken başlayan pinch
      tutmuyorsa (ilk parmak sahipliği); büyük PDF düzenlemede bellek (belge + 48 MB
      önbellek) düşük cihazda sorunluysa bütçe profile bağlanır; CropBox'lı PDF'te vurgu
      yerinde değilse; yapay ses motoru (WebView) uygulama alttayken kısılıyorsa sesli
      kitap ön plan servisine; Yakındakiler hotspot + tarayıcı yolunda alıcı mobil veriye
      gidiyorsa; SMB3-zorunlu NAS'ta bağlanmıyorsa ekrandaki yönlendirme yeterli mi.

### B4 — Office uyumluluk turu 💻👤 (DUZENLEME Faz 33 madde 5)

- [ ] `test/fixtures/{office,pdf}` düzenlenmiş çıktıları + cihazda üretilen dosyalar
      **masaüstü Word/Excel/PowerPoint**, **Google Dokümanlar/E-Tablolar/Slaytlar** ve
      **LibreOffice**'te onarım uyarısız açılıyor mu — tablo `CIHAZ_TESTI.md` §13.
      (Bulutta yalnız LibreOffice/Poppler denenebildi.)

### B5 — Hesap ve kararlar 👤 (Faz 11b)

- [ ] **OpenSubtitles:** depoya `OPENSUBTITLES_API_KEY` secret'ı (yoksa altyazıda "İnternette ara" gizli; A11'den).
- [ ] **Sesli not Notlar tarafı (A10, Notlar deposu):** Dosya Okuyucu notu ACTION_SEND ile konu
      "Dosyalar" olarak gönderiyor; Notlar'da bu konuyu "Dosyalar" klasörüne koyan alıcı ve
      istenirse doğrudan köprü (`kopru.xml` knownCerts'e Dosya Okuyucu release sertifikası).
- [ ] **B5.1 Play Console:** geliştirici hesabı; `v*` etiketinin AAB'si iç test kanalına —
      inceleme uyarısız yayımlanıyor mu. Formlar: veri güvenliği (A6.2 metni), izin
      beyanları + videolar (A6.1 senaryoları), içerik derecelendirme, hedef kitle, ön plan
      servisi türleri.
- [ ] **B5.2 Pro:** Pro'ya girecek özellik listesi + Billing ürün kimlikleri → A6.5
      iskeletine bağlanır; test hesabında satın alma ve geri yükleme.
- [ ] **B5.3 Play izin varyantı kararı:** Play derlemesinden hangi izinler çıkacak
      (kod hazır: `ci/play_variant.py`, elle tetiklemede `aab: true` + `play: true` +
      `play_remove`; varsayılan `QUERY_ALL_PACKAGES` + `READ_MEDIA_*` — 2026-11-08). Karardan sonra `v*` etiketinde
      varsayılan açılabilir.
- [ ] **B5.4 K7 — depo private + `LICENSE`** ("Tüm hakları saklıdır") + README lisans notu.
      Önce iki sonucu karara bağla: Actions dakikası 2.000/ay sınırı (HAFIZA kota tuzağı)
      ve gizlilik politikasının "raw GitHub" adresi çalışmaz → herkese açık politika
      adresi (ayrı public depo / GitHub Pages / site).
- [ ] **B5.5 K5 — Google Drive tam kapsam:** yayından önce yıllık ücretli CASA denetimi ya
      da kapsamı yeniden düşün (`drive.file` / sistem seçicisi). Ayrıca Google Cloud OAuth
      istemcisi (paket + SHA-1, `docs/GOOGLE-DRIVE-KURULUM.md`) kayıtlı değilse Drive
      gezgini hiç çalışmaz.
- [ ] **B5.8 B-bulut — OneDrive / Dropbox (Faz 41 / 2):** eklensin mi? Gerekenler:
      Microsoft Entra uygulama kaydı (istemci kimliği + Android yönlendirme URI'si,
      `Files.ReadWrite` izni) ve/veya Dropbox App Console uygulaması (App key, `files.content.*`).
      Karar + kimlikler gelince Drive'ın çevrimdışı/çakışma altyapısı (`drive_offline.dart`)
      aynen kullanılır. (2026-11-05)
- [ ] **B5.9 Uygulamasız alıcı — tarayıcıda çöz (Aktar "Bağlantıyla gönder", 2026-11-13, YAPILMADI):**
      iPhone/PC'de uygulama olmadan bağlantıyı açıp dosyayı tarayıcıda çözmek için
      (1) **barındırılan statik sayfa** (ör. ayrı public depoda GitHub Pages ya da kendi alan
      adı) — bağlantı `https://<sayfa>/#id=…&k=…` olur, sayfa Web Crypto ile AES-GCM çözer;
      (2) **Google Cloud API anahtarı** (Drive API açık, HTTP yönlendiren kısıtlı) — tarayıcı
      `drive.usercontent.google.com`'dan CORS'suz okuyamaz, `www.googleapis.com/drive/v3/files/<id>?alt=media&key=…`
      CORS verir. İkisi de hesap/konsol işi + dışa dönük yayın → kullanıcı kararı. Kod tarafı
      hazır parça: kap biçimi `lib/services/fm/remote/link_share.dart` (DOAKLNK1), başvuru
      `tool/aktar_sifre_vektor.py`. Karar gelince sayfa + bağlantı biçimi (uygulama iki biçimi de tanır) yazılır.
- [ ] **B5.6 K1 — Syncfusion Community License** başvurusu yapıldı ve belge saklandı mı
      (teyit).
- [ ] **B5.7 Açık soru:** kullanıcının "tikli öğesi çok notlar kasıyor" notu (2026-10-29)
      — bu uygulamada onay kutulu not yok; Notlar uygulamasıyla mı ilgili? Cevap
      bekleniyor.

### B6 — Sürüm adayı ve yayın 👤 (Faz 12c)

- [ ] 48 saat iç test; `CrashLog` + Android Vitals (ANR < %0,47, çökme < %1,09); sürüm
      notları; `v1.x.0` etiketi (arm + arm64 + AAB); Play kapalı test → üretim. Ön koşul:
      B2'de açık kırmızı 0, B5 tamam.

---

## Bilinçli kapsam dışı / paket sınırı (yapılmayacak — kayıt için)

- **SMB:** `smb_connect` en fazla SMB 2.1 konuşuyor ve portu 445'e sabitliyor (paket
  sınırı); SMB3 zorunlu NAS'ta ekran SFTP/FTP'ye yönlendiriyor. Gerekirse paket çatallanır.
- **RAR yazma** yok (özel biçim; `.zip` üretiliyor). Büyük solid RAR'da saf Dart hız sınırı.
- **Excel `###`** gösterilmiyor, sığmayan sayı kırpılıyor (ölçümümüz Excel'le birebir değil;
  yanlış yerde `###` göstermektense kırpmak seçildi).
- **Excel'de not yazma** deneysel etiketli (K24); masaüstü doğrulaması B4.
- **Eski WebView Word yolunda** harf harf geri alma yok — yol B3.2'de kalkacak.
- **ID3v1** etiketleri okunmuyor (ID3v2.2–2.4, MP4 `ilst`, FLAC Vorbis okunuyor).
- **Slayt çizimi:** bulut/gözyaşı yaklaşık; `bentArrow`/`circularArrow`/`ribbon` gibi
  tanımsız geometriler dikdörtgen (yanlış biçim yerine kutu); animasyon efekt türü
  okunmuyor (jenerik beliriş).
- **`docs/DUZENLEME_PLANI.md` §10:** makro/Power Query/pivot oluşturma/dinamik dizi işlevleri;
  SmartArt ve denklem düzenleme; gerçek zamanlı ortak düzenleme; slayt kutusunda paragraf
  başına hizanın düzenlerken görünmesi; izlenen değişikliklerde tek tek kabul + kaydetme
  kipi; slayt animasyonu yazma, ses/video ekleme; eski ikili biçimlere yazma; PDF serbest
  yeniden akış; şifreli Office düzenleme.
- **`re_editor`** denenmedi (K25 + bağımlılık diyeti; ölçülmüş darboğaz yok).
- **"6 aydır açılmamış"** süzgeci cihazın `atime` tutmasına bağlı.
- **PDF/Word "belgenin kendisini" çevirme:** gömülü yazı tipinin taşımadığı dilde
  (Türkçe → Arapça) paragraflar atlanır ve sayısı söylenir.

---

## Açılış istemleri (yeni oturuma aynen yapıştır)

> **Faz A (bulut), sıradaki bölüm:** `KALANLAR.md`'yi oku; Faz A'da ilk açık bölümü
> (A1'den başlayarak) bitir. Her madde için kabul ölçütünü sağla, testleri yaz, cihazda
> bakılacakları `docs/CIHAZ_TESTI.md`'ye ekle, HAFIZA'nın "Tarihli kayıtlar" bölümüne
> yaz, biten maddeleri KALANLAR'dan sil, main'e birleştir, CI'ı izle. A1.2'de dal
> silme öncesi bana sor; A3'te her paket ayrı commit.
>
> **Faz B2 (cihaz turu, yerel oturum + USB'li telefon):** `KALANLAR.md` B1 ve B2'yi
> yapalım: önce graphify ve Windows testleri, sonra `docs/CIHAZ_TESTI.md`'yi benimle
> telefonda bölüm bölüm geç; §1 ölçüm tablosunu doldur; ölçüm verisini telefona
> koymadan önce söyle (`.nomedia`, iş bitince sil). Kırmızıları ve B3'ü aynı oturumda
> düzelt, HAFIZA'ya yaz, main'e birleştir.
>
> **Faz B5/B6 (hesap):** `KALANLAR.md` B5'i benimle madde madde geç; depo görünürlüğü,
> Billing ürün kimlikleri ve etiketleme öncesi bana sor.
