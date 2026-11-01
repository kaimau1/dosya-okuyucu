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
| **A** | ☁️ bulut | A1 hijyen · A2 ölü kod · A3 bağımlılık tazeleme · A4 kod sağlığı · A5 iş sonucu sayfası · A6 Play/gizlilik metinleri + Pro iskeleti · A7 eksik özellikler · A8 ölçüm altyapısı · A9 isteğe bağlı | 5–7 oturum |
| **B** | 📱💻👤 | B1 yerel küçük işler · B2 cihaz turu · B3 cihaza bağlı takip · B4 Office uyumluluk · B5 hesap/karar · B6 sürüm adayı | 1–2 cihaz oturumu + hesap işleri |

---

## Faz A — Bulutta yapılabilenler ☁️

**Ortak "bitti":** `flutter analyze` 0 · `flutter test` yeşil (Flutter **3.44.6**) ·
cihazla doğrulanacak yeni şey `docs/CIHAZ_TESTI.md`'de · HAFIZA'ya tarihli kayıt ·
bu dosyadan madde silindi · main'e birleşti, CI yeşil. `ci/*.kt` değiştiyse
`tool/check_kotlin.sh`. **`dart format` KOŞTURMA** (HAFIZA tuzakları).

**Sıra:** A1 → A2 → A3 → A4 → A5 → A6 → A7 → A8 → (A9 isteğe bağlı). A1+A2 bir oturum;
A3 tek başına bir oturum (riskli); A4, A5+A6, A7 (2 oturum), A8 ayrı ayrı.

### A1 — Depo ve belge hijyeni (kısa, ilk iş)

- [ ] **A1.2 Uzak dalları temizle (kullanıcı izniyle).** main dışında 64 uzak dal var:
      16'sı main'e tam girmiş; 46'sının main'le ortak atası yok (main'in geçmişi bir ara
      yeniden yazılmış — içerikleri main'de); `ccr-4fb1643b-cvg3t7` #52 ile squash girmiş;
      `ccr-0ba9d97d-1mtuwm` 2026-11-01'de birleştirildi.
      CLAUDE.md kuralı "iş main'e girince uzak dal silinir"; Faz 0'da silme izinle
      engellenmişti. Önce yeniden say (`git for-each-ref refs/remotes/origin` +
      `git rev-list --count origin/main..<dal>` + `git merge-base`), o an süren oturum
      dalları HARİÇ sil. **Bitti:** `git ls-remote --heads origin` yalnız `main` +
      süren oturum dalları.
- [ ] **A1.3 Bayat ifadeler (kod tarafı):** `pubspec.yaml`'daki "CI 3.29.3 / Dart 3.7"
      gerekçeleri (A3 ile birlikte düzelir); `flutter_launcher_icons` `min_sdk_android: 23`
      (gerçek minSdk 24); kod yorumlarında "KALANLAR maddesi" atıfları (KALANLAR artık
      yalnız açık işi tutuyor — atıf HAFIZA'ya ya da kaldırılır). Belge tarafı 2026-11-01'de
      düzeltildi.

### A2 — Ölü kod ve eski yollar

`lib/main.dart`'tan erişilemeyen 3 dosya var (2026-11-01 erişilebilirlik taraması):

- [ ] **A2.1 `lib/screens/qr_share_screen.dart`** (173 satır; yalnız
      `test/qr_share_test.dart` kullanıyor). 2026-10-29'da paylaş seçimi 2 seçeneğe
      inince "metni QR'ın içine koy" yolu koptu. **Öneri:** Paylaş levhasına küçük metin
      dosyası / seçili metin için "QR olarak göster" diye yeniden bağla (kullanıcı
      2026-10-22'de istemişti); istenmezse ekran + test silinir.
- [ ] **A2.2 `lib/services/pdf/pdf_font_class.dart`** (yalnız kendi testi) ve
      **`pdf_text_stamp.dart`** (yalnız `tool/write_fixtures_test.dart` +
      `pdf_fixture_smoke_test`). Kullanılacaksa bağla; yalnız örnek üretimi içinse
      `test/support/`'a taşı; değilse testiyle sil.
- [ ] **A2.3 Erişilebilirlik bekçisi:** `test/reachability_test.dart` — `lib/` altında
      `main.dart`'tan erişilemeyen dosya 0 (yöntem: import/export/part grafiğinde
      `main.dart`'tan gezinti; 2026-11-01'de elle koşturuldu, kaydedilmedi). Bundan sonra
      kopan ekran testte yakalanır.

> Eski WebView Word düzenleme yolu ve `lib/labs/word_editor/` prototipi **cihaz onayına
> bağlı** → B3.2.

### A3 — Bağımlılık tazeleme (Flutter 3.29 dönemi sabitleri) — tek başına bir oturum

CI 2026-10-21'den beri Flutter 3.44.6, ama pubspec'te "3.29.3 / Dart 3.7 uyumlu son
sürüm" diye sabitlenmiş paketler ve onlara karşı yazılmış geçici çözümler duruyor.
Her yükseltme **ayrı commit**, her birinden sonra analyze + test; APK boyutu bütçesi
(CI) geçmeli; cihazda bakılacaklar `CIHAZ_TESTI.md`'ye.

- [ ] **A3.1 `archive ^3` → `^4`** (ön koşul): `image 4.3.0` → güncel, `koni_archive`,
      `excel` uyumu; arşiv testleri (`fm_archive_*`) yeşil.
- [ ] **A3.2 `pdfrx ^1.3.0` → 2.x** (en büyük kazanç, ayrı dalda dene): 1.3.5 hatalarına
      karşı yazılan çözümler — basamaklı `getPageRenderingScale` (yakınlaştırma
      titremesi), görünüm boyu değişince sayfa başına atlama (okuma kipi katmanı),
      `useAlternativeFitScaleAsMinScale` kenetlemesi, kendi seçim katmanı
      `widgets/pdf_select_layer.dart` — 2.x'te gereksiz mi, ölç. Gereksizse sadeleştir;
      değilse kalsın ve gerekçe HAFIZA'ya. Bütün `pdf_*` testleri + B2 PDF bölümü.
- [ ] **A3.3 ML Kit:** `google_mlkit_text_recognition 0.15.0`, `google_mlkit_translation
      0.13.0` → güncel (OCR Play Hizmetleri, çeviri K3 = kalsın); R8 `-dontwarn`
      kuralları hâlâ gerekli mi.
- [ ] **A3.4 Ötekiler:** `video_player 2.10.1` + `video_player_android 2.8.15`,
      `wakelock_plus 1.4.0`, `permission_handler 11.3.1`, `fc_native_video_thumbnail
      2.2.0`, `flutter_local_notifications 17.2.4`, `syncfusion_flutter_pdf/_core 31.1.19`
      (K1 lisansı aynı), `shared_preferences_android 2.4.28` (JNI çökmesi — HAFIZA;
      yalnız düzeldiği doğrulanırsa), `flutter_lints ^4`.
- [ ] **A3.5 `pubspec.lock` depoya alınsın** (uygulama deposu için Dart önerisi): CI her
      koşuda yeniden çözümlüyor; alt paket kayması bu yüzden elle pinleniyordu.
      `.gitignore`dan çıkar, CI `pub get --enforce-lockfile`.

### A4 — Kod sağlığı (Faz 3/5/12'nin kalıntıları)

- [ ] **A4.1 800+ satırlı ekranlar** (Faz 3 ölçütü "800+ satırlı ekran yok" geriledi):
      `screens/fm/remote/nearby_screen.dart` 1621 · `screens/image_edit_screen.dart`
      1613 · `screens/fm/job_report_screen.dart` 911 · `screens/fm/category_screen.dart`
      884 · `screens/fm/search_screen.dart` 881 → Faz 3 yöntemiyle böl (davranış aynı,
      testler aynen geçer). İsteğe bağlı 1000+ satırlı widget/denetleyiciler:
      `pdf_editor/layer.dart` 1152, `widgets/fm/media_resize_sheet.dart` 1150,
      `widgets/pdf_select_layer.dart` 1062, `docx_edit_controller.dart` 1045,
      `docx_editor_view.dart` 1030, `editors/spreadsheet/entry.dart` 1003.
- [ ] **A4.2 `AppState` (989 satır):** Faz 3'te ayrılmayan Browse / Clipboard / Remotes /
      AI bildiricileri ayrı `ChangeNotifier`'lara; yalnız ilgili ekran izlesin
      (`root_rebuild_test` yöntemiyle yeniden çizim sayısı testi).
- [ ] **A4.3 166 boş `catch (_) {}`** (161'i `lib/services`) — Faz 5'in sınıflandırılmayan
      kalanı: (a) beklenen → tek satır gerekçe yorumu, (b) `CrashLog`'a yazılmalı,
      (c) kullanıcıya `UserError`. Bekçi: gerekçesiz yeni boş `catch` testi kırar.
- [ ] **A4.4 Ekran/widget kodunda 51 senkron G/Ç** (`existsSync/statSync/listSync/
      readAsBytesSync…`; Faz 12a'da 39'du) → `async`/`compute`; bekçi testi tavanla
      (cırcır, yalnız azalabilir).
- [ ] **A4.5 4 `// ignore:`** — `core/route_guard.dart` (deprecated_member_use),
      `widgets/mini_player_bar.dart` (invalid_use_of_protected_member),
      `services/fm/remote/ftp_fs.dart` (invalid_null_aware_operator), `main.dart`
      (avoid_print): gerekçe doğrula ya da kaldır.

### A5 — İş sonucu sayfası her işte (`recordChanges`)

- [ ] Bugün yalnız **AI etiketleme** ve **taşı/kopyala** dosya dosya değişiklik yazıyor
      (`TrackedTask.recordChanges`, `jobChangesOf`; HAFIZA 2026-10-30/31 açık iş).
      Bağlanacak: toplu yeniden adlandır (geri al = eski ad), görsel/video boyutlandırma
      ve küçültme (çıktı + "özgünü çöpe at"), çöpe taşı / kalıcı sil, arşive ekle / çıkar,
      AI ile kategorilere ayır uygulaması, AI düzenleme, SD birleşik "Şimdi taşı", sohbet
      temizliği. **Bitti:** her işin kartından `JobReportScreen` açılıyor; geri
      alınabilenlerde "Geri al" çalışıyor; her iş için test.

### A6 — Play, gizlilik ve mağaza metinleri + Pro iskeleti

- [ ] **A6.1 `docs/play/izin_beyanlari.md` eksik izinler:** `QUERY_ALL_PACKAGES`
      (`installed_apps` eklentisinden birleşiyor; Play'de yüksek riskli), `ACCESS_FINE/
      COARSE_LOCATION` (hangi API düzeyinde ve neden), `BLUETOOTH_SCAN/ADVERTISE/
      CONNECT` (Yakındakiler BLE bulma/davet), `NEARBY_WIFI_DEVICES` + `CHANGE_WIFI_STATE`
      (LocalOnlyHotspot), `RECEIVE_BOOT_COMPLETED` (SD birleşik iş), `INSTALL_SHORTCUT`.
      **Bitti:** `ci/AndroidManifest.xml` + birleşen eklenti izinlerinin her biri belgede
      (bekçi testi: manifest izin listesi ⊆ belge başlıkları).
- [ ] **A6.2 `docs/play/veri_guvenligi.md` + `assets/privacy/{tr,en,ar}.md`:** kaldırılan
      **Anılar** hâlâ yazıyor; eklenecek: Yakındakiler (BLE reklamı, yerel ağda 8080 web
      sunucusu + jeton, hotspot), AI anlamla arama (yalnız sorgu gider), AI etiketleme
      (dosya ADI + klasör adı + boyut + ay Gemini'ye gider), asistan köprüsü (yalnız
      kişisel derleme, imza izinli). Üç dil aynı bölümler.
- [ ] **A6.3 Mağaza metinleri** (`docs/play/magaza_metinleri.md`, 2026-10-22): düzenleme
      turu (Word/Excel/Slayt/PDF), Yakındakiler, Kırık beyaz tema, iş sonucu ekranı;
      **L6 marka notu** ("Microsoft Word, Excel ve PowerPoint Microsoft Corporation'ın
      ticari markalarıdır; bu uygulama Microsoft ile bağlantılı değildir") TR/EN/AR;
      ekran görüntüleri son görünümle `tool/design_shots_*` yöntemiyle yeniden.
- [ ] **A6.4 Play derlemesi izin varyantı** (eski "mağaza yolu (c)"): `DOSYA_PLAY=1`
      hazırlık bayrağı (kişisel derleme bayrağı gibi) Play AAB'sinden
      `QUERY_ALL_PACKAGES` (`tools:node="remove"`; uygulamalar ekranı `<queries>` +
      kullanım istatistiğiyle) ve gerekirse `REQUEST_INSTALL_PACKAGES` /
      `PACKAGE_USAGE_STATS`'ı çıkarır; GitHub derlemesi değişmez. Hangisi çıkacak 👤 B5;
      kod + "üretilen manifestte yok" denetimi ☁️.
- [ ] **A6.5 Pro / Billing iskeleti** (Faz 11a'da "kapalı bayrakla yazılabilir" denmişti,
      yazılmadı): tek kapı `ProGate` + Play Billing (tek seferlik Pro, K6) — ürün kimliği
      yokken bayrak kapalı, GitHub derlemesinde her şey açık; satın alma geri yükleme
      akışı. Pro'ya girecek özellikler 👤 B5'te; iskelet + test burada.
- [ ] **A6.6 Play İçi Değerlendirme + Uygulama İçi Güncelleme** (N5): yalnız Play
      derlemesinde (bayrak); Kotlin + `check_kotlin.sh`.

### A7 — Eksik özellikler (kod + test bulutta; his cihazda)

- [ ] **A7.1 Çift bölme (dual pane):** tablette/yatayda iki klasör yan yana, sürükle-bırak
      taşı/kopyala, etkin bölme vurgusu. Bugün ≥ 840 dp'de yalnız sol kısayol paneli var
      (`browser_screen.dart` `_sidePane`).
- [ ] **A7.2 SD karta SAF ile yazma:** yol üzerinden yazılamayan kartta ağaç izni akışı
      (`ACTION_OPEN_DOCUMENT_TREE`, kalıcı izin), `FileOps`'ta SAF yazma yolu; SD birleşik
      depolamanın `sd_readonly` uyarısı buna bağlanır. Aynı turda SD birleşik **(b)**
      "ana bellek %X'i aşınca" eşiği ve **(c)** serbest klasör seçimi (bugün yalnız
      Android'in standart ortak klasörleri).
- [ ] **A7.3 Arşiv çıkarmada iptal:** ZIP/RAR/7z çıkarma izolatı durdurulamıyor
      (`archive_ops.dart` — `ReceivePort`, iptal belirteci yok; büyük solid RAR'da
      dakikalar sürebiliyor). "Durdur" → izolat öldürülür, yarım hedef klasör silinir.
- [ ] **A7.4 Görüntüye çevirerek PDF sıkıştırma (agresif kip):** eski engel "cihazda JPEG
      kodlayıcı yok" kalktı (Faz 14b: Android `Bitmap.compress`, `image` paketi). Ayrı ve
      açıkça uyaran seçenek (metin katmanı kaybolur; isteğe bağlı OCR katmanı), DPI/kalite
      seçimi; `pdf_tools.dart:304` yorumu güncellenir.
- [ ] **A7.5 Excel koşullu biçim yazma:** renk ölçeği / veri çubuğu / simge kümesi bugün
      yalnız okunup çiziliyor; "Koşullu biçimlendirme" levhasına eklenir (`<cfRule>` +
      `<colorScale>/<dataBar>/<iconSet>`), LibreOffice ile gidiş-dönüş testi.
- [ ] **A7.6 Koyu temada Word sayfa görünümü:** WebView kanvası (sayfanın çevresi) açık
      kalıyor → `assets/word/viewer.html`'e tema zemini; isteğe bağlı gece kipi (PDF'teki
      gibi ters renk).
- [ ] **A7.7 Kâğıt teması belge sayfası çerçevesi** (`#FBF8F1` zemin + 1 px `#D2C8B4` +
      yarıçap 4): bugün yalnız kanvas düzeyinde; PDF sayfa kutusu (pdfrx sayfa süslemesi)
      ve Word WebView sayfasına da.
- [ ] **A7.8 Asistan köprüsü — özet geri dönüşü** (isteğe bağlı): özet bugün Dosya
      Okuyucu'nun özet sayfasında açılıyor, asistana dönmüyor (HAFIZA 2026-10-31
      "gerekirse sonra"). Asistan deposunun `PROTOKOL.md`'siyle birlikte; yalnız kişisel
      derleme.

### A8 — Ölçüm altyapısı (bulut kısmı; koşusu B2'de)

- [ ] **A8.1 `integration_test` senaryoları** (FAZ_PLANI Faz 4 P13 — hiç yazılmadı):
      soğuk açılış, 5.000 öğeli klasörde kaydırma + sürükleyerek seçim, 2.000 fotoğraflı
      galeri, 100 sayfalık PDF, 10 bin satırlık Excel, Word 1000 paragraf yazma;
      `traceAction` özeti → `docs/perf/`. Veri `tool/make_test_tree.py`. Koşu:
      `flutter drive --profile` (B2).
- [ ] **A8.2 Açılışın ilk 0,5 sn'si:** ilk kare raster 218–309 ms (Impeller ve Skia), pano
      build 45–49 ms. Pano ilk kurulumunda `StartupQueue`'ya ertelenebilecek işleri kodda
      bul ve ertele (her biri ölçüm kancasıyla); doğrulama B2 (`_logSlowStartupFrames`).

### A9 — İsteğe bağlı (görsel fark riski)

- [ ] **A9.1 Levha/pencere birliği:** ~55 `showModalBottomSheet` ve ~58 `showDialog`
      çağrısı (2026-11-01 sayımı, ortak bileşenlerin kendi içi dahil) →
      `showAppSheet` / `showAppActionSheet` / `showAppConfirm` / `showAppPrompt`. Her levha
      için önce/sonra PNG (`tool/design_shots_*`), kullanıcı onayıyla parti parti; son
      bakış B2.

---

## Faz B — Diğerleri 📱💻👤

### B1 — Yerel Windows oturumu küçük işleri 💻

- [ ] **B1.1 `graphify update .`** → `graphify-out/` (rapor 2026-10-21'den beri eski;
      sonrasında `services/docx/`, `widgets/docx_editor/`, `screens/pdf_editor/`,
      `core/edit/`, Yakındakiler … eklendi); CLAUDE.md §2 düğüm/kenar/topluluk sayıları.
- [ ] **B1.2 Windows'ta kalan 2 test** (2026-11-01 tam koşu: 3293 geçti, `analyze` 0; ikisi temiz
      ağaçta da kırık, Linux CI'da sorun değil): `pdf_pending_objects_test` "Üstüne yaz" (çıkarılan
      metinde yeni yazı yok) · `peer_share_test` "alıcı yokken…" (Windows'ta port 1 bağlantısı
      `onWaiting` çağırmadan bitiyor). **Bitti:** Windows'ta ikisi de yeşil ya da platforma göre atlanıyor.
- [ ] **B1.3 Ölçüm hazırlığı:** yan yana kurulabilen `.r8test` profil APK'sı (HAFIZA
      tuzağı: CI anahtarı ≠ yerel anahtar) + `tool/make_test_tree.py` verisi.

### B2 — Cihaz turu 📱 (FAZ_PLANI 12b + DUZENLEME 33 cihaz kısmı + Faz 4 ölçümleri)

- [ ] **`docs/CIHAZ_TESTI.md`'yi baştan sona geç** (2026-11-01'de alana göre yeniden
      düzenlendi; §1 ölçüm tablosu sayılarla doldurulur). En az iki telefon (biri düşük
      donanımlı, FAZ_PLANI Ek D), Yakındakiler için ikinci telefon, Bluetooth klavye,
      varsa tablet/DeX. Kırmızılar aynı oturumda düzeltilir; sonuç HAFIZA'ya.
      Ölçüm verisi telefona `.nomedia`'lı klasörde konur, iş bitince silinir.

### B3 — Cihaz sonucuna bağlı takip işleri (B2 içinde ya da hemen sonra; kod bulutta da yazılabilir)

- [ ] **B3.1 K23:** Excel 10 bin satırda profil `FrameTiming` %99 > 16 ms ise (b) tek
      boyacı ızgara (debug prototipi ~4× hızlı; HAFIZA).
- [ ] **B3.2 Word Mobil görünüm editörü telefonda onaylanınca** (K18 kontrol noktası,
      CIHAZ_TESTI §Word): eski WebView `contenteditable` düzenleme yolu (`labWordEditor`
      bayrağı, `screens/editors/word/shell.dart`, `viewer.html` düzenleme köprüsü) ve
      `lib/labs/word_editor/` prototipi silinir — K19 (b) "Faz 23 sonunda kalkar"
      demişti. Onaylanmazsa kök neden yazılır, editör düzeltilir.
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
- [ ] **B5.3 A6.4 kararı:** Play derlemesinden hangi izinler çıkacak.
- [ ] **B5.4 K7 — depo private + `LICENSE`** ("Tüm hakları saklıdır") + README lisans notu.
      Önce iki sonucu karara bağla: Actions dakikası 2.000/ay sınırı (HAFIZA kota tuzağı)
      ve gizlilik politikasının "raw GitHub" adresi çalışmaz → herkese açık politika
      adresi (ayrı public depo / GitHub Pages / site).
- [ ] **B5.5 K5 — Google Drive tam kapsam:** yayından önce yıllık ücretli CASA denetimi ya
      da kapsamı yeniden düşün (`drive.file` / sistem seçicisi). Ayrıca Google Cloud OAuth
      istemcisi (paket + SHA-1, `docs/GOOGLE-DRIVE-KURULUM.md`) kayıtlı değilse Drive
      gezgini hiç çalışmaz.
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
