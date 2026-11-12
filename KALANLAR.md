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
| **A** | ☁️ bulut | A1 hijyen · A3 bağımlılık tazeleme · A4 kod sağlığı · A5 iş sonucu sayfası · A6 Play/gizlilik metinleri + Pro iskeleti · A7 eksik özellikler · A8 ölçüm altyapısı · A9 isteğe bağlı | 5–7 oturum |
| **B** | 📱💻👤 | B1 yerel küçük işler · B2 cihaz turu · B3 cihaza bağlı takip · B4 Office uyumluluk · B5 hesap/karar · B6 sürüm adayı | 1–2 cihaz oturumu + hesap işleri |

---

## Faz A — Bulutta yapılabilenler ☁️

**Ortak "bitti":** `flutter analyze` 0 · `flutter test` yeşil (Flutter **3.44.6**) ·
cihazla doğrulanacak yeni şey `docs/CIHAZ_TESTI.md`'de · HAFIZA'ya tarihli kayıt ·
bu dosyadan madde silindi · main'e birleşti, CI yeşil. `ci/*.kt` değiştiyse
`tool/check_kotlin.sh`. **`dart format` KOŞTURMA** (HAFIZA tuzakları).

**Sıra:** A1 → A3 → A4 → A5 → A6 → A7 → A8 → (A9 isteğe bağlı). A3 tek başına bir
oturum (riskli); A4, A5+A6, A7, A8 ayrı ayrı. (A2 ve A1.3, A3.5, A4.5, A6.1–A6.4, A7.3,
A7.6, A7.7 2026-11-02'de bitti — HAFIZA.)

### A1 — Depo ve belge hijyeni (kısa, ilk iş)

- [ ] **A1.2 Uzak dalları temizle (kullanıcı izniyle).** **2026-11-12 yeniden sayım (tam geçmişle):** 114 dal; 94'ü main'e TAM girmiş (91'i 24 saatten eski — silinmeye hazır, otomatik silme izinle engellendi), 19'unda main'de olmayan 1–12 commit (faz-54, faz-G0/G1/G2, dependabot ×3, eski `claude/*` ×7 …) — tek tek bakılmalı. Eski not: main dışında 64 uzak dal var:
      16'sı main'e tam girmiş; 46'sının main'le ortak atası yok (main'in geçmişi bir ara
      yeniden yazılmış — içerikleri main'de); `ccr-4fb1643b-cvg3t7` #52 ile squash girmiş;
      `ccr-0ba9d97d-1mtuwm` 2026-11-01'de birleştirildi.
      CLAUDE.md kuralı "iş main'e girince uzak dal silinir"; Faz 0'da silme izinle
      engellenmişti. Önce yeniden say (`git for-each-ref refs/remotes/origin` +
      `git rev-list --count origin/main..<dal>` + `git merge-base`), o an süren oturum
      dalları HARİÇ sil. **Bitti:** `git ls-remote --heads origin` yalnız `main` +
      süren oturum dalları.

### A3 — Bağımlılık tazeleme (Flutter 3.29 dönemi sabitleri) — tek başına bir oturum

CI 2026-10-21'den beri Flutter 3.44.6, ama pubspec'te "3.29.3 / Dart 3.7 uyumlu son
sürüm" diye sabitlenmiş paketler ve onlara karşı yazılmış geçici çözümler duruyor.
Her yükseltme **ayrı commit**, her birinden sonra analyze + test; APK boyutu bütçesi
(CI) geçmeli; cihazda bakılacaklar `CIHAZ_TESTI.md`'ye.

### A4 — Kod sağlığı (Faz 3/5/12'nin kalıntıları)

- [ ] **A4.1b (isteğe bağlı) 1000+ satırlı widget/denetleyiciler:** `pdf_editor/layer.dart` 1156,
      `widgets/fm/media_resize_sheet.dart` 1150, `widgets/pdf_select_layer.dart` 1062, `docx_edit_controller.dart`
      1045, `docx_editor_view.dart` 1030, `editors/spreadsheet/entry.dart` 1003. (Ekranlar 2026-11-02'de < 800.)
- [x] **A4.2 `AppState` (989 satır):** Faz 3'te ayrılmayan Browse / Clipboard / Remotes /
      AI bildiricileri ayrı `ChangeNotifier`'lara; yalnız ilgili ekran izlesin
      (`root_rebuild_test` yöntemiyle yeniden çizim sayısı testi).
      **2026-11-12:** Pano (`ClipboardState`), uzak bağlantılar (`RemotesState`), AI hafızası
      (`AiMemoryState`) ayrıldı (`core/state/focused_states.dart`; testi `root_rebuild_test`).
      Aynı gün: göz atma tercihleri (`BrowseState`) ve AI ayarları (`AiState`) da ayrıldı;
      okuyan ekranlar `context.watchBrowse()` / `watchAi()` (select kullananlar `dependOn…`).
- [x] **A4.3 Boş `catch`** (2026-11-11: 191 → 12; 2026-11-12: 12 → 0). Hepsi gerekçeli
      `// Bilinçli: …` yorumu aldı; bekçi `test/empty_catch_ratchet_test.dart` tavan **0**.
- [~] **A4.4 Ekran/widget kodunda senkron G/Ç** (2026-11-11: 87 → 44; 2026-11-12: → 30 → 26; bekçi
      `test/sync_io_ratchet_test.dart` tavan 26, yalnız iner). Kalan 26: `build` içi tek
      `stat`ler (önbellek gerekir: galeri bilgi satırı, işler boyutu, klasör seçici kısayolları,
      SD birleşik çipleri, arşiv başlığı), editör açılışı (sahte saat tuzağı, bilinçli),
      izolattaki okuma, PDF dosyaları (Faz 54'le çakışmasın diye dokunulmadı).

### A5 — İş sonucu sayfası her işte (`recordChanges`)

- [ ] Bugün **AI etiketleme**, **taşı/kopyala**, **toplu yeniden adlandır** (Adları geri al)
      ve **çöpe taşı** (Geri yükle) dosya dosya değişiklik yazıyor (`TrackedTask.recordChanges`,
      `jobChangesOf`, `renamedChange`; 2026-11-02).
      Bağlanacak: görsel/video boyutlandırma
      ve küçültme (çıktı + "özgünü çöpe at"), kalıcı sil, arşive ekle / çıkar,
      AI ile kategorilere ayır uygulaması, AI düzenleme, SD birleşik "Şimdi taşı", sohbet
      temizliği. **2026-11-11:** kalıcı sil (`delete`, `FmOpResult.deleted`) ve `showFmProgress<String>`
      ile ÜRETİLEN her şey (arşive ekle, arşivden çıkar, APK dışa aktar, indirme … → `create`,
      `createdChangeOf`; sayfada "Çöp kutusuna at" → `trash` olur, "Geri yükle" çalışır) bağlandı.
      **2026-11-12:** akıllı temizlik (kuyruk işi → `JobHandle.addChanges`, çöpe atılanlar `trash`)
      bağlandı. Zaten bağlıymış: AI kategorilere ayır (= `showAiTagFlow`, etiket kaydı), sohbet
      temizliği (`ChatJunkBucketScreen` → `deleteEntries` → `showFmProgress<FmOpResult>`).
      Bilinçli kalan: boyutlandırma/küçültme kartı karşılaştırma sayfasını açar (özgün ↔ yeni + sil/tut —
      rapor sayfasından zengin). Kalan: SD "Şimdi taşı" (yerel WorkManager işi yol listesi
      döndürmüyor → Kotlin), "AI düzenleme" (kodda karşılığı bulunamadı — ne kastedildiği belirsiz). **Bitti:** her işin kartından `JobReportScreen` açılıyor; geri
      alınabilenlerde "Geri al" çalışıyor; her iş için test.

### A6 — Play, gizlilik ve mağaza metinleri + Pro iskeleti

- [x] **A6.5 Pro / Billing iskeleti** — DÜŞTÜ (SÜRÜM PLANI 2026-11-10: Pro ayrı ücretli uygulama,
      Billing kodu yok). Yerine sürüm kapısı S1–S3 (2026-11-12, `core/edition.dart`, `widgets/pro_gate.dart`).
- [ ] **A6.6 Play İçi Değerlendirme + Uygulama İçi Güncelleme** (N5): yalnız Play
      derlemesinde (bayrak); Kotlin + `check_kotlin.sh`.

### A7 — Eksik özellikler (kod + test bulutta; his cihazda)

- [x] **A7.1 Çift bölme (dual pane):** (Faz 41 madde 1, `dual_pane_screen.dart`) tablette/yatayda iki klasör yan yana, sürükle-bırak
      taşı/kopyala, etkin bölme vurgusu. Bugün ≥ 840 dp'de yalnız sol kısayol paneli var
      (`browser_screen.dart` `_sidePane`).
- [x] **A7.2 SD karta SAF ile yazma:** (Faz 41 madde 1, `saf_write.dart`; (b)/(c) eşikleri ayrıca bakılmadı) yol üzerinden yazılamayan kartta ağaç izni akışı
      (`ACTION_OPEN_DOCUMENT_TREE`, kalıcı izin), `FileOps`'ta SAF yazma yolu; SD birleşik
      depolamanın `sd_readonly` uyarısı buna bağlanır. Aynı turda SD birleşik **(b)**
      "ana bellek %X'i aşınca" eşiği ve **(c)** serbest klasör seçimi (bugün yalnız
      Android'in standart ortak klasörleri).
- [x] **A7.4 Görüntüye çevirerek PDF sıkıştırma (agresif kip):** (Faz 39 madde 7, 2026-11-05) eski engel "cihazda JPEG
      kodlayıcı yok" kalktı (Faz 14b: Android `Bitmap.compress`, `image` paketi). Ayrı ve
      açıkça uyaran seçenek (metin katmanı kaybolur; isteğe bağlı OCR katmanı), DPI/kalite
      seçimi; `pdf_tools.dart:304` yorumu güncellenir.
- [x] **A7.5 Excel koşullu biçim yazma:** renk ölçeği / veri çubuğu / simge kümesi bugün (Faz 36 madde 2, 2026-11-05)
      yalnız okunup çiziliyor; "Koşullu biçimlendirme" levhasına eklenir (`<cfRule>` +
      `<colorScale>/<dataBar>/<iconSet>`), LibreOffice ile gidiş-dönüş testi.

### A8 — Ölçüm altyapısı (bulut kısmı; koşusu B2'de)

- [x] **A8.1 `integration_test` senaryoları** (Faz 42 / 6, 2026-11-06: `integration_test/perf_senaryolari_test.dart` + `tool/perf_senaryo.sh`; koşu B2) (FAZ_PLANI Faz 4 P13 — hiç yazılmadı):
      soğuk açılış, 5.000 öğeli klasörde kaydırma + sürükleyerek seçim, 2.000 fotoğraflı
      galeri, 100 sayfalık PDF, 10 bin satırlık Excel, Word 1000 paragraf yazma;
      `traceAction` özeti → `docs/perf/`. Veri `tool/make_test_tree.py`. Koşu:
      `flutter drive --profile` (B2).
- [~] **A8.2 Açılışın ilk 0,5 sn'si:** (2026-11-12: büyük AI indeksi ayrı izolatta, kanca `ACILIS ai-index`; pano `initState`'teki geri kalanlar SharedPreferences/meta okuması — ucuz; doğrulama B2.) ilk kare raster 218–309 ms (Impeller ve Skia), pano
      build 45–49 ms. Pano ilk kurulumunda `StartupQueue`'ya ertelenebilecek işleri kodda
      bul ve ertele (her biri ölçüm kancasıyla); doğrulama B2 (`_logSlowStartupFrames`).

### A9 — İsteğe bağlı (görsel fark riski)

- [ ] **A9.1 Levha/pencere birliği:** ~55 `showModalBottomSheet` ve ~58 `showDialog`
      çağrısı (2026-11-01 sayımı, ortak bileşenlerin kendi içi dahil) →
      `showAppSheet` / `showAppActionSheet` / `showAppConfirm` / `showAppPrompt`. Her levha
      için önce/sonra PNG (`tool/design_shots_*`), kullanıcı onayıyla parti parti; son
      bakış B2.

- [ ] **A9.2 Belge gece kipi ve PDF kâğıt zemini** (A7.6/A7.7 kalanı, 2026-11-02): koyu temada
      Word kanvası artık koyu ama sayfa beyaz; isteğe bağlı "gece kipi" (PDF'teki gibi ters
      renk, `viewer.html` CSS `filter`). PDF'te kâğıt temasında yalnız çerçeve var — sayfanın
      içi pdfium beyazı (pdfrx 2.12'de `render(backgroundColor:)` var — Faz 48 sonrası yapılabilir).

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
- [ ] Faz 43 artığı 📱 (taban MatePad’da alındı → `docs/perf/2026-11-43-taban.md`): Xiaomi 13T + Mi Note 10 Lite tabanı (P1–P12), P6 (erişilebilirlik açık), P4/P5 ekran kaydı + yakınlaştırma, P12 video; duman turunun elle maddeleri.
- [ ] İncele 📱: `VIEW video/*` (file://) oynatıcı yerine panoyu açıyor; Paylaş (`SEND`) Aktar ekranına gidip konum + yakın cihaz izni istiyor (MatePad, Faz 43).
- [ ] **Faz 43–50 bitti** (son tablo `docs/perf/2026-11-50-sonuc.md`). Kalan 👤: `v1.2.N` etiketi (kullanıcı atar — kalıcı sürüm arm + arm64 + AAB).
- [ ] Faz 50 artığı 📱: ikinci cihaz (Xiaomi/Mi Note 10 Lite) tam §2; xlsx 100 bin için daha uzun kaydırma senaryosu (şimdiki 3–34 kare, p99 ≈ en kötü kare); `CIHAZ_TESTI.md` "Faz 49" elle maddeleri (çevrimdışı kip, AI onayı, Klasör ekle, Neler yeni).
- [ ] UDF (UYAP) okuyucu — Play yorum çalışmasında aday (P2, orta-büyük); biçim araştırılmadı.
- [ ] Faz 48 artığı 📱: **P6** (erişilebilirlik hizmeti gerçekten açık, PDF-B kaydırma) GMS'li/Xiaomi cihazda; yakınlaştırma keskinliği (basamaklı ölçek kalktı — iki parmak elle); `CIHAZ_TESTI.md` "Faz 48".
- [ ] Faz 45–47 artığı 📱: GMS'li cihazda Drive girişi (google_sign_in 7 yetkilendirme yolu) + ML Kit OCR/çeviri model indirme; gerçek SFTP/FTP sunucusunda (NAS) bağlan/aktar (yerel asyncssh/pyftpdlib ile yeşil); "Başka uygulamada aç" köprüsü (video/ses/apk, READ_MEDIA_* yok) elle; dosya seçici (file_picker 13) çoklu seçim + büyük dosya; paylaş (share_plus 13); bildirim (flutter_local_notifications 23) — `docs/CIHAZ_TESTI.md` "Faz 45–47".
- [ ] Override'lar (Faz 45/47): `xml` (webdav_client), `pointycastle` (smb_connect), `dartssh2` (ftpconnect) — paketler yeni sürüm çıkarınca sil; `shared_preferences_android` 2.4.28 sabit (2.5.4'te de süreç geneli kayıt silinmesi).
- [ ] Faz 44 artığı 📱: P9/P12 ve duman turunun elle maddeleri 3.47'de; Xiaomi'de P5 kuyruğu (+%14–18 MatePad'de) yeniden ölç.

## Faz E — PDF Pro: profesyonel PDF düzenleyici (2026-11-08, kullanıcı isteği) ☁️💻📱
Ayrıntı, kök nedenler, mimari kararlar (PK1–PK8) ve bitti ölçütleri: **`docs/PDF_PRO_PLANI.md`**
(Faz 51–68: külliyat + ölçüm + kanama durdurma · PDFium düzenleme köprüsü + karar kapısı · tasarım
dili (👤 onay) · oturum çekirdeği + tek yüzey + kaydetme · metin anlama · yazı tipi sadakati ·
WYSIWYG yerinde düzenleme · metin araçları · nesneler · işaretleme · form/imza · OCR Pro · sayfa
stüdyosu · güvenlik/çıktı · AI · performans · görsel cila · sürüm adayı + rakip turu).
Sıra 51 → 68 (atlama yok). Bildirilen 6 sorun (PS1–PS6) Faz 51'de ara, 54/57'de kalıcı çözülür.
- [x] **Faz 54** — bitti (2026-11-11, dal `faz-54`): `PdfEditSession`, tek yüzey (bayrak `pdf_pro_engine`), artımlı kayıt + sürüm geçmişi, çökme kurtarma, şifreli belge, CI ölçümü (`docs/perf/2026-11-pdfpro-54-oturum.md`).
- [ ] 📱 **Faz 54 cihaz kapısı:** `docs/CIHAZ_TESTI.md` "PDF Pro Faz 54" 1–12 (tek yüzeyde yakınlaştırma/kaydırma, kayıt/kopya/sürüm geçmişi, çökme kurtarma, şifreli belge) + §6 bütçe sayıları perf raporunun "Cihaz" sütununa. Bitti: koşu kaydı dolu, bütçe aşımı yok.
- [ ] **Faz 54 ölçüm açıkları:** 50 sayfalık belgede artımlı kayıt süresi ölçülemedi (tezgâhın birleştirilmiş 51 sayfalık belgesinde köprü her düzenlemeyi reddetti — nedeni incelenmedi); tek oturumun ek belleği ayrıştırılmadı. Külliyata tek üreticiden 50 sayfalık belge + `session_bench_test` güncellemesi. Bitti: perf raporunda iki satır sayıyla dolu.
- [ ] **`PdfEditorScreen` emekliliği (Faz 54 / 2 kalanı):** bayrak kapalıyken hâlâ tek düzenleme yolu. Görsel/filigran/form/OCR işlevleri Faz 57–62'de düzenleme kipine taşındıkça ve `pdf_pro_engine` varsayılan olunca `lib/screens/pdf_editor*` + çalışma kopyası + eski `PdfEditJournal` silinir, testleri taşınır.
- [ ] **Faz 55** — sıradaki: metin anlama (düzen çözümleme).
- [ ] 👤 **Faz 53 maket onayı — itiraz varsa düzelt:** https://claude.ai/artifact/PNjvf5wSp5ae2rY56RpNQW (7 kare; kaynak `docs/design/pdf_pro/maket/`, sözleşme `docs/design/pdf_pro/etkilesim.md`). Kullanıcı ekran başında değildi, kapı bloklanmadı; sonraki UX fazları bu maketlerle sürüyor. Yorum/itiraz gelirse maket + belirtim + `PdfEditTokens` düzeltilir.
- [ ] 👤 **Külliyata eksik üreticiler** (Faz 51'de bu makinede yoktu): LibreOffice "PDF olarak dışa aktar", Google Docs "İndir → PDF", LaTeX (pdfTeX/XeTeX), macOS Quartz (Önizleme/Sayfalar). Uydurma metinle (kişisel veri yok) birer–ikişer PDF üretip `test/fixtures/pdf_corpus/` + `corpus.json`'a eklenir (≤ 300 KB, Yazar alanı boş). Bitti: CORPUS.md'de üretici sayısı 12.
- [ ] **AES-256 (R6) sahip parolalı belgede kilit açma sayfasız çıktı veriyor** (`wd_sifreli.pdf`, Faz 51 tezgâhı: Syncfusion `removePassword` sonrası "Sayfa bulunamadı"). Faz 52: PDFium yolu R6'yı kendisi açıyor (pdfium-nesne `pageErrors` 0) → PK1 varsayılan olunca bu madde kendiliğinden kapanır; Syncfusion `removePassword` yolu Faz 54'te emekliye ayrılırken silinir.

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
- [ ] G1 artığı: (a) `REQUEST_INSTALL_PACKAGES` / `PACKAGE_USAGE_STATS` Play'den çıkarılırken özelliklerin Play derlemesinde gizlenmesi (dart-define bayrağı) + B5.3 kararı; (c) eski (imzasız) sabitlenmiş ana ekran kısayolu uyumu `Extras.pathAccepted` — eski kısayollar kalmayınca imzasız kolu kaldır
- [x] Faz G2 sırlar (kod bitti, 2026-11-11; cihaz maddeleri `docs/CIHAZ_TESTI.md` "Faz G2")
- [x] 2026-11-12 (main): G4.5 boş disk (507/452), G6.5 ses sunucusu Host/Origin, G7.2 arşiv yol testleri, G7.5 CSV formül koruması, G7.10 uzantı aldatması, G9.2 CI en az yetki, G9.3 kalıcı imza zorunlu — cihaz maddeleri `docs/CIHAZ_TESTI.md` "Güvenlik G4.5 / G6.5 / G7.x"
- [x] 2026-11-12 (main, 2. tur): G2.6 hassas pano, G6.1–G6.4 WebView (CSP, gezinti kilidi, dosya erişimi, kanal sınırı), G7.6 PDF bağlantı şeması, G8.1 SFTP TOFU, G9.1 Action SHA, G9.4 Dependabot, G9.6 güncelleme SHA-256 + ana makine, G10.3 kasa AI'ya kapalı (+ kasa dosyası son açılanlara/kısayola yazılıyordu — düzeltildi), G12.1–G12.4 (`docs/guvenlik/SURUM_KONTROL.md`, `MASVS.md`, `OLAY.md`, `ci/min_guvenli_surum.txt`) — cihaz maddeleri `CIHAZ_TESTI.md` "Güvenlik G2.6 / G6 / G8.1 …"
- [x] 2026-11-12 (main, 3. tur): G7.9 bulanık test (10 ayrıştırıcı; bulgu: Office şifre çözmede spinCount/anahtar boyu denetimsizdi → sınırlandı), G9.4 osv-scanner + G9.10 MobSF (`guvenlik-taramasi.yml`, haftalık), G9.8 APK doğrulaması (debuggable/yedek/şifresiz trafik/izin tabanı/imza), G9.9 gömülü JS + yamalı paket özetleri, G10.4 tek ağ kapısı `NetGuard` (+ bekçi testi), G10.5 "Verilerimi sil" + politika, G7.4 Word düzenleyici bağlantı şeması, G7.6 kapandı (PDF eki açma yok), G12.5 — cihaz maddeleri `CIHAZ_TESTI.md` "Güvenlik — genel elle tur"
- [ ] G9.8 artığı: 👤 `SIGN_CERT_SHA256` repo değişkeni (imza parmak izi karşılaştırması). (İzin tabanı 2026-11-12'de dolduruldu, kip katı; `READ_PHONE_STATE` manifestte `tools:node="remove"` ile çıkarıldı.)
- [ ] Güvenlik artıkları (2026-11-12): G6.6 kötü niyetli DOCX fixture'ı; G7.4 kayıtta makro korunuyor mu (bilgi iletisi 2026-11-12'de eklendi); G9.9 ses motoru dosyalarının özeti (HF `resolve/main` değişken); G2.6 başka parola/kod kopyaları (yakın cihaz kodu) gözden geçirilmedi; "Verilerimi sil"e kayıtlı bağlantılar/anahtarlar seçeneği (bilinçli dışarıda)
- [ ] G6.5 artığı: ses sunucusunda rastgele yol öneki (aynı cihazdaki başka uygulamaya karşı) — kurulumda yeniden yazılan çalışan betikleri mutlak yol (`/antalia/vendor/ort/…`) kullanıyor; önek için yeniden yazımın da öneki eklemesi gerekir.
- [ ] G2 artığı: Keystore sarılı sırlar (Gemini, uzak/FTP parola) eski bir sürüme geri dönülürse okunamaz — kullanıcı yeniden girer (bilinçli ödün, sürüm notunda); OpenSubtitles anahtarı APK ikilisinde (dart-define) — Pro'da vekil sunucu düşünülür
- [ ] G3 artığı 📱: `docs/CIHAZ_TESTI.md` "Faz G3" (yerel PBKDF2 süresi, parmak izi CryptoObject, yeni parmak izi ekleyince geçersizleşme, eski kayıt göçü). Android 7'de (yerel PBKDF2 yok) saf Dart 600 bin tur ≈ 10 sn+ — ölçülmedi; uzun sürerse Android 7 için tur düşürme kararı 👤
- [ ] G4 artığı: G4.2 (parola zaten varsayılan rastgele 6 hane + yeni deneme sınırı; 8+ karışık karakter ve parolasız kipte süre sınırı yapılmadı), G4.4 kod yenileme + 6 hane (Windows exe ve eski sürüm uyumu gerekiyor; şimdilik Random.secure + adres başına 5 deneme/60 sn), G4.5 başlık ≤ 16 KB ve boş disk 507 (eşzamanlı ≤ 16 + boşta 60 sn 2026-11-12'de yapıldı), G4.8 30 dk boşta kapanma doğrulaması; 📱 `CIHAZ_TESTI.md` "Faz G4"
- [ ] Kalan: G7.1 artığı (oran aşımında kullanıcıya sorma yok — ret; `.bz2/.xz` 2026-11-12'de sınırlandı), G7.3 artığı (yazıcı/yama yolları; yalan başlık 2026-11-12'de kapandı — `archive` açmayı başlıktaki boyutla kesiyor), G7.4 artığı (makro), G7.8 · G8.2 artığı (FTPS sertifika TOFU), G8.4, G8.5, G8.6 artığı (uygulama içi diğer `http.get`'lerin zaman aşımı taraması) · G9.5 👤, G9.7 👤 · G10.2 artığı (tek belgelik kapatma) · G12.6 👤 (G5, G11 isteğe bağlı)

---

## Faz B — Diğerleri 📱💻👤

### B1 — Yerel Windows oturumu küçük işleri 💻

(B1 bitti — 2026-11-02: `.r8test` profil APK'sı ve ölçüm verisi hazırlığı; tarif HAFIZA.)

### B2 — Cihaz turu 📱 (FAZ_PLANI 12b + DUZENLEME 33 cihaz kısmı + Faz 4 ölçümleri)

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

### A11 — Dosya seçici: süzgeç + sade ana sayfa

(2026-11-03'te yapıldı — HAFIZA; telefonda bakış CIHAZ_TESTI §16.)

- [ ] OpenSubtitles: depoya `OPENSUBTITLES_API_KEY` secret'ı eklenecek (👤; yoksa "İnternette ara" gizli).

### A10 — Kişisel sürümde sesli not (Asistan yerine; Harita KALANLAR "Asistan'sız ses planı" Faz D)

- [ ] **Görüntüleyicide 🎤 not düğmesi, yalnız kişisel sürüm (`DOSYA_KISISEL=1`).** Basınca dikte hemen başlar
      (Harita/Kanallarım `Dictation` kuralları: ~3,5 sn sessizlik ya da "tamam" bitirir, "iptal" vazgeçer), not Notlar'ın
      "Dosyalar" klasörüne gider: dosya adı, sayfa no, görünen pasajdan alıntı, dosyayı yeniden açan `file:` bağlantısı.
      Kotlin köprü `ci/kisisel/`'de (prepare_android.sh 3b kopyalar), Dart düğmesi method channel ile, `RECORD_AUDIO`
      yalnız kişisel manifestte. **Bitti ölçütü:** CI genel APK'da mikrofon izni ve köprü olmadığını denetler;
      Notlar `kopru.xml` knownCerts'e Dosya Okuyucu release sertifikası eklendi; telefonda not "Dosyalar"a düşüyor.

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
