# Dosya Okuyucu — Proje Hafızası (dizin)

> **Ne:** kalıcı kararlar ve *niye*'leri, hâlâ geçerli tuzaklar, reddedilen yollar, güncel
> durum. Kod yapısı burada değil (`graphify-out/`), kalan iş burada değil (`KALANLAR.md`).
> **KVKK:** hasta verisi / TC / ölçüm / token / parola bu dosyaya YAZILMAZ.
>
> **2026-11-01 temizliği:** önceki dizin (892 satır; 2026-07 kararları, build geçmişi,
> 2026-10-22…31 tur kayıtları) **kelimesi kelimesine** `docs/hafiza/dizin_2026-11-01_oncesi.md`
> dosyasına taşındı; bu dosya güncel özettir. Daha eski tur kayıtları `docs/hafiza/2026-07.md`
> … `2026-10.md`. Ayrıntı/kanıt için: `grep -rn "<konu>" docs/hafiza`.
>
> **Yazma kuralı (usta rule 12):** iş bitmeden kalıcı karar, bug kök nedeni ya da yanlış çıkan
> yol oluştuysa **en alttaki "Tarihli kayıtlar"a** `## YYYY-MM-DD — başlık` biçiminde ekle
> (madde imli `- **2026-…**` biçimi `tool/hafiza_arsivle.py`'nin göremediği biçimdir — 2026-10'da
> 400 satır bu yüzden dizinde birikti). Bir karar değişirse buradaki satırı güncelle ve
> tarihli kayda "→ güncellendi" yaz. Dosya ~600 satırı geçince `python tool/hafiza_arsivle.py`.

## 1. Güncel durum (2026-11-01)

- **Sürüm:** `main` @ `9ae256a`, build **444** (CI yeşil, nightly). Flutter **3.44.6** (CI = yerel
  = bulut). ~623 Dart dosyası / ~210 bin satır, 349 test dosyası (son tam sayım 2026-10-29:
  3216 test yeşil), `flutter analyze` 0.
- **Fazlar:** FAZ_PLANI Faz 0–19 ve DUZENLEME_PLANI Faz 20–32 bulut kısmıyla bitti; Faz 4, 10,
  11b, 12b/12c ve 33'ün cihaz/hesap kısmı açık. **Bütün kalan iş tek listede:
  `KALANLAR.md` — Faz A ☁️ (bulut) / Faz B 📱💻👤 (telefon, yerel, hesap).** Telefonda
  bakılacaklar: `docs/CIHAZ_TESTI.md` (alana göre, 2026-11-01).
- **Açık kararlar (kullanıcı):** Pro özellik listesi + Billing ürünleri (K6), depo private
  zamanı (K7), Drive CASA ya da kapsam (K5), Play derlemesi izin varyantı (KALANLAR B5).

## 2. Sabit kararlar (güncel)

Kararların tam tablosu ve gerekçeleri: `docs/FAZ_PLANI.md` §4 (K1–K17),
`docs/DUZENLEME_PLANI.md` §6 (K18–K25).

**Platform ve dağıtım**
- **Yalnız Android** (K10, 2026-10-21); minSdk **24** (K9), targetSdk/compileSdk 36 (AppFunctions
  için compileSdk 37 yaması). Paket `com.dosyaokuyucu.dosya_okuyucu`.
- **`android/` depoda yok:** `ci/prepare_android.sh` `flutter create` iskeletini üretip bütün
  yamaları (manifest `ci/AndroidManifest.xml`, Kotlin `ci/*.kt`, Gradle, R8 kuralları
  `ci/proguard-rules.pro`) uygular; yerelde de aynı betik. Kotlin değiştiyse
  `tool/check_kotlin.sh` (gerçek android-all jar'ına karşı derler + harness'ler).
- **CI** (`.github/workflows/build-apk.yml`): `verify` (pub get → analyze → test) ∥ `apk`
  (obfuscate, apksigner, içerik/16 KB/boyut bütçesi) → `release`. main → tek **`nightly`**
  (üzerine yazılır); **`v*` etiketi** → kalıcı sürüm (arm + arm64 + AAB); eski sürümler budanır.
  `**.md`, `docs/**`, `graphify-out/**` CI koşturmaz. Dağıtım K11: Play (AAB) + GitHub nightly.
- **Kişisel derleme** (`DOSYA_KISISEL=1`, elle `kisisel: true`): asistan köprüsü
  (`ci/kisisel/AsistanKopru.kt`, izin `signature|knownSigner`) yalnız orada; genel derlemede
  betik köprünün manifestte OLMADIĞINI denetler. Ayrı **`kisisel`** ön-sürümüne yayınlanır
  (`releases/download/kisisel/dosya-okuyucu.apk`; nightly/"en son" değişmez); tetik: elle
  `kisisel: true` ya da head commit mesajında `[kisisel]` (2026-11-01).
- **İmza:** bütün APK'lar sabit anahtarla — secret `ANDROID_KEYSTORE_B64` +
  `ANDROID_KEYSTORE_PASSWORD`, alias `dosyaokuyucu`, SHA-256 `9E:EF:67:04:…:4C:57:37:18`.
  Anahtar dosyası repo DIŞINDA (`C:\Users\sena\Desktop\dosya-okuyucu-imza\release.jks`) —
  **kaybetmek = bir daha güncelleme yayınlayamamak**, yedekle. İmza değişirse telefona kurulmaz
  (`INSTALL_FAILED_UPDATE_INCOMPATIBLE`, veri silinir).
- **Tek dal `main`.** Bulut oturum dalı (`ccr-*`, `claude/*`) iş main'e girince silinir; dal
  silmeden önce main'de olduğunu doğrula (2026-07-22 ikon kaybı dersi).

**Yapay zekâ ve gizlilik**
- **Gemini düz REST** (paket yok); kullanıcı kendi anahtarı (K4) + anahtarsız temiz deneyim;
  anahtar Keystore sarmalı (Faz 11a); model listesi ListModels'ten, olmazsa statik yedek.
- AI'ya yalnız gereken gider: anlamla arama = yalnız sorgu (puanlama cihazda); AI etiketleme =
  ad + klasör ADI + boyut + ay; Yakındakiler/QR'da üçüncü taraf yükleme YOK.
- **Firebase 2026-09-26'da kaldırıldı.** Google Drive `google_sign_in` + tam `drive` kapsamı
  (K5 a) → yayından önce CASA; OAuth istemcisi paket + SHA-1 ile kayıt ister
  (`docs/GOOGLE-DRIVE-KURULUM.md`).
- Yapay zekâ sesleri APK'ya 0 MB: HF Space'lerin ONNX Runtime Web dosyaları ilk kullanımda iner,
  WebView + yerel 127.0.0.1 sunucu (COOP/COEP); kökte `NeuralVoiceHostLayer`, 3 dk boşta kapanır.

**Belge motorları**
- **Office ilkesi:** cihaz-içi / çevrimdışı / ücretsiz; özgün XML korunur, yalnız dokunulan düğüm
  yeniden yazılır → el değmemiş belge baytı baytına aynı (Word/Excel/Slayt testli).
- **Word:** okuma/sayfa görünümü = gömülü docx-preview + WebView (K19), MS font ikamesi
  (Carlito/Tinos/Arimo). **Düzenleme = Mobil görünüm editörü** — kendi DOCX modeli
  (`services/docx/`, paragraf değişmez nesne, atom `U+FFFC` = köprü/alan/dipnot/resim…) + ince
  `DeltaTextInputClient` çekirdeği (`widgets/docx_editor/`) — **K18 (b-ii)**. WebView
  `contenteditable` düzenleme yalnız geliştirici bayrağında; cihaz onayından sonra silinecek
  (KALANLAR B3.2).
- **Excel:** kendi Flutter ızgarası (K23 a; tek boyacı yedek plan), okuma `xlsx_reader`, yazma
  `excel 4.0.6` + `XlsxSavePatch` (stil/gizli/yükseklik/koşullu biçim/tablo parçaları);
  kendi formül motoru + `CalcState` bağımlılık grafiği; Türkçe arayüzde Türkçe formül, dosyaya
  İngilizce `,` `.` `_xlfn.` (K22); uygulama içi sayı/formül tuş takımı (K20); okuma sınırı
  200 bin satır / 1024 sütun, aşılırsa kaydetme KAPALI (kesilen hücre silinmesin).
- **Slayt:** kendi renderer (`pptx_render` + `slide_canvas`); yerinde zengin metin
  (`pptx_rich_text`), kutuya yakınlaşan odak görünümü; dikey akış + ham pointer pinch
  (`PinchZoomArea`, Excel ile ortak).
- **PDF:** görüntüleme pdfrx 2.12 (pdfium; `third_party/pdfrx` tek satır yama) + kendi seçim katmanı; yazma Syncfusion 35
  (K1 a Community License); paragraf motoru yerinde düzenler, reddederse "Üstüne yaz"
  (eski span akıştan çıkarılır + gömülü yazı tipi/Carlito); düzenleme işlem listesi bellekte.
- **Ortak düzenleme çekirdeği** `lib/core/edit/` (EditHistory, EditSession, DraftJournal,
  SaveIsolate, EditorChrome, EditorShortcuts): taslak günlüğü her zaman + otomatik kaydetme
  varsayılan AÇIK (K21).
- **Metin/kod:** geliştirilmiş `TextField` (K25), 1–4 MB isolate renklendirme, kodlama korunur.

**Medya ve sistem**
- Video küçültme **Media3 Transformer** (K2 b; FFmpeg kalktı); tek oynatma motoru `video_player`;
  bildirim/kilit ekranı çerçevenin kendi `MediaSession`'ı (`ci/MediaSession.kt`) + ön plan
  servisi. Görsel çıktı Android yerel (HEIC okuma, WebP yazma; K15 b), Dart `image` yedek.
- Yakındakiler: UDP + **BLE yalnız bulma/davet** (`ci/NearbyBle.kt`), veri Wi-Fi'den (gerekirse
  LocalOnlyHotspot); protokol v2 kaldığı yerden devam + store ZIP akışı; web 8080 + 6 harf jeton.
- Ham USB FAT/exFAT yazma kalsın + sağlamlaştırıldı (K8): güvenli sıra, geri-okuma, kirli bayrak.
- Cihaz profili `low/mid/high` (Faz 4): görsel önbelleği orta/güçlü 64 MB / 300, açılış işleri
  `StartupQueue`'da (ilk kareden 2 sn sonra, tek sırada).

**Arayüz ve dil**
- Tasarım tokenları `AppIcons` / `AppColors` / `AppType` / `Motion`; ham `Icons.*` ve `Colors.*`
  **0** (bekçi `design_tokens_test`, cırcır). Yeni dosyada `showModalBottomSheet` yasak →
  `showAppSheet` / `showAppActionSheet`; onay/ad sorma `showAppConfirm` / `showAppPrompt`.
- Diller TR/EN/AR, `t()` tablosu `core/l10n/strings/`; ekranda doğrudan Türkçe yazmak
  `l10n_literals_test`'i kırar. Fiziksel sol/sağ yazma (`rtl_guard_test`); belge içeriği
  (PDF sayfası, Excel hizası, slayt) bilinçli fiziksel.
- Ortak bekçiler: `a11y_guidelines`, `editor_a11y`, `bare_input_guard`, `navigator_guard`,
  `route_guard`, `fm_delete_guard`, `motion_tokens`, `l10n_keys_used`.
- Menü dili tek: `widgets/menu_kit.dart` (DocMoreSheet, uzun basma, AppActionSheet, klasör ⋮).

## 3. Tuzaklar (hâlâ geçerli)

**Ortam, CI, süreç**
- **Bulut oturumu:** Flutter 3.47.9 Linux (Faz 44; önce 3.44.6) tarball'ı indirilebilir
  (`storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_3.47.9-stable.tar.xz`),
  `git config --global --add safe.directory '*'` şart. Telefon/ölçüm/`graphify` YOK.
- **`dart format` KOŞTURMA** — depo biçimlendirilmiş değil; tek dosyada yüzlerce satır gürültü
  (2026-10-23'te 172 dosya geri alındı).
- **Actions dakika kotası** bitince işler 2-3 sn'de logsuz düşer — "altyapı arızası" sanıp boş
  commit'le yeniden tetikleme; önce kullanıcıya/Billing'e bak. Depo private olunca 2.000 dk/ay.
- PowerShell borusu secret'a CR ekler → `gh secret set X < dosya`; workflow `tr -d '\r\n \t'`.
- **main'e giden head commit mesajında `[kisisel]` YAZMA** (birleştirme mesajı dahil): o koşu
  nightly yerine kişisel derleme + `kisisel` ön-sürümü üretir.
- Oturum başında `.claude/settings.json` hook'u `git pull --rebase --autostash` yapar —
  beklenmeyen üst commit bundandır.
- Kotlin yalnız CI'da derleniyordu, tek tür hatası 13 dk yakıyordu → `tool/check_kotlin.sh`.
- **`pubspec.lock` depoda (2026-11-02):** CI `pub get --enforce-lockfile` → pubspec'i değiştiren
  `flutter pub get` koşturup kilidi de commit'lemeli; yoksa verify/apk "Bağımlılıklar" adımı kırılır.
  `prepare_android.sh` kilidi `flutter create`e karşı yedekler.
- **Yerel APK telefona kurulmaz** (anahtar farklı, veri silinir): temiz kopyada
  `applicationIdSuffix = ".r8test"` + `documents` authority `${applicationId}` → yan yana kur.
  Git Bash'te adb: `MSYS_NO_PATHCONV=1`, Windows yolları `C:/` biçiminde.
- **SurfaceFlinger `--latency` aralığı takılma DEĞİLDİR** (`input swipe` boşlukları); kare için
  `FrameTiming` / logcat `KARE`. Ölçüm medyası telefona `.nomedia`'lı klasörde, sonra sil.
- Perf eşikleri paralel test yükünde 3–5× şişer → bekçi eşikleri gevşek (`perf` etiketi);
  debug ölçümü cihaz bütçesini kanıtlamaz.
- Flutter yükseltmesinde platform varsayılanlarını gözden geçir: 3.27+ derin bağlantı açık →
  `content://` sayfa adı sanılıp çöküyordu (`flutter_deeplinking_enabled=false` + `route_guard`).
- `shared_preferences_android` 2.5.x JNI kaydı süreç başına tek → `PickerActivity` kapanınca
  ana uygulama çöküyordu → **2.4.28 sabit**.
- R8: ML Kit dört dil sınıfı için `-dontwarn`; tam kip `ComponentRegistrar` boş yapıcılarını
  siliyordu → keep kuralı. AGP 9 kütüphane kurallarını uygular.

**Flutter / Dart**
- `testWidgets` içinde gerçek dosya G/Ç ve `compute` sahte saatte bitmez (`await
  File.writeAsBytes`, `createTemp` sonsuza asılır) → `setUp`'ta ya da `*Sync`; ekran kodunda
  okuma izolata.
- Özel `TextInputClient` yazan editör Backspace/Delete **tuş olayını** kendisi işlemeli (Android
  klavyesi silmeyi `KEYCODE_DEL` olarak gönderir); testte `sendKeyEvent` ile sına.
- Çift dokunuş tanıyıcısı her tek dokunuşu 300 ms geciktirir (`kDoubleTapTimeout`) → editörlerde
  yok; testte süreyi ilerlet.
- `Transform.scale`'de `alignment` origin'e EKLENİR → `Alignment.topLeft` (pinch kayması).
- Örtük animasyon yapı değişirse oynamaz — iki durumda aynı ağaç.
- Tema `focusedBorder/enabledBorder/filled` `InputBorder.none` alanlara sızar → dört anahtar
  birlikte (`bare_input_guard_test`).
- Degrade `begin/end` `AlignmentDirectional` OLAMAZ; `animateTo` sıfır süre kabul etmez →
  `Motion.scrollTo`; `textTheme.bodySmall` RENK de taşır → `AppType` yalnız boy.
- Diyalog/levha `TextEditingController`'ı kapanış animasyonunda atılırsa "used after disposed" →
  denetleyici pencerenin State'inde (`showAppPrompt`); `AnimationController` `initState`'te kur.
- collection-if: `if (a) for (...) if (b) x else y` — `else` içteki if'e bağlanır.
- `ValueKey(Object)` ≠ `ValueKey<String>`; yatay `ListView` tembel kurar (testte bulunamaz);
  ekran dışındaki şerit öğesi için `scrollUntilVisible` + `ensureVisible`.
- Klavye üstü çubuk yalnız `viewInsets.bottom > 0` iken; testte `tester.view.viewInsets`.
- Yeni alt çubuk `ToastAvoider` ile sarılır (iş kartı düğmeleri örtmesin).
- Bağlamsız `?? const []` for-loop'ta `Object`e düşer → `?? const <XmlElement>[]`.

**Belge biçimleri**
- **`XmlName('w:numPr')` öneki ayırmaz** (`local == 'w:numPr'`) → `XmlName.fromString`; xml
  `removeWhere` "already has a parent" atabilir → toplayıp tek tek `remove`.
- `paraLook` pPr düğümü başına önbellekli → değişecek pPr'yi önce kopyala.
- Word stilleri ADLA aranır (Türkçe Word kimliği `Balk1`, adı `heading 1`).
- docx-preview `w:lastRenderedPageBreak`'te paragrafı ikiye böler → WebView kopyasında `_fkp<i>`
  yer imleri (W1). Office Symbol/Wingdings madde imleri Android'de ▯ → `fixSymbolFonts` /
  `core/symbol_fonts.dart`; `viewer.html`'de charset yok → `\uXXXX`.
- WebView: meta viewport'u JS ile değiştirmek yeniden sığdırmaz → CSS `zoom`.
- **pdfrx (2.12, Faz 48):** görüntüleyicinin boyunu jest sırasında değiştirme (sayfa başına atlar);
  `layoutPages` aynı girdide eşit düzen döndürmeli; basamaklı çizim ölçeği 2.x'te KALDIRILDI (N5,
  fazladan çizim); çok sütunda `useAlternativeFitScaleAsMinScale` kapalı.
- PDF adları `[A-Za-z0-9]` dışını da içerir (`/ABCDEF+Arial-BoldMT`); yalnız kapak bırakmak eski
  metni aramada bırakır → span akıştan çıkarılmalı; PDF düzenleme op kapanışına yerel
  `pageIndex` kopyası.
- Slayt: kopyalanan slayda not ilişkisi gitmemeli; `a:latin/cs/ea` sıralı eklenmeli; yeniden
  çizimden sonra şekil `_resolveShape` ile (aynı XML düğümü) bulunur.
- `excel 4.0.6`: hizalama okunmuyor, `insertRow/insertColumn` NO-OP, `defaultColWidth` yoksa
  `getColumnWidth` null atar — kendi kodumuz/try-catch. Sentetik dosya bu hataları göstermedi:
  gerçek dosyayla duman testi yapmadan "çalışıyor" deme.
- LibreOffice: dipnot başvurusu olup `footnotes.xml` yoksa açmıyor; soffice UTF-8 metin filtresi
  `txt:Text (encoded):UTF8`.
- `image` paketi `decodeJpg` yön etiketini piksele uygulayıp siler; WebP kodlayıcı meta veri taşımaz.

## 4. Reddedilen yollar (tekrar önerme)

- Sunucu tabanlı OnlyOffice / gömülü LibreOffice-Collabora (çevrimdışı + APK +70 MB) ·
  WebView + PPTXjs (slayt) · x-spreadsheet (Excel WebView) · Word için super_editor (43× yavaş
  açılış + 43 paket), WebView'da ProseMirror, paragraf başına `TextField` · `audio_service` /
  `just_audio_background` (yaşam döngüsü dayatıyor) · Wi-Fi Direct (hotspot yeterli) · aktarımda
  deflate (telefonda Wi-Fi'den yavaş) · QR/aktarımda üçüncü taraf yükleme (gizlilik) · Firebase
  senkronu (kaldırıldı) · FFmpeg (Media3'e geçildi) · `insertUnorderedList` (Word paragraf
  eşlemesini bozuyordu) · çift dokunuşla yakınlaştırma editörlerde · `usage_stats` paketi
  (compileSdk 30, derlemeyi kırıyor) · **pdfrx 2.x'te erişilebilirlik satır Semantics'i ve bizim
  basamaklı `getPageRenderingScale`'imiz** (2.4.8 2026-11-03'te geri alındı; 2.12'ye 2026-11-08'de
  ölçerek geçildi: N1 `third_party/pdfrx` tek satır yama, N5 kaldırıldı — `docs/perf/2026-11-48-pdfrx.md`;
  pdfrx yükseltilirken önce A/B, yama YAMA.md'ye göre yeniden).

## 5. Tarihli kayıtlar (yeni kayıt en alta; `## YYYY-MM-DD — başlık`)


## 2026-11-18 — Geçmiş / Yeniler adları · araçlar 2 satır · Bento 4 uzun kart · Görselde ne var · akıllı klasör düzeni + öğrenme
- **Adlar (kullanıcı: "her yerde"):** "Son açılanlar" → **Geçmiş** (`oh.title`, `dash.sec_recent`, `fm.recent_opened`, `hist.opened`, `side.show_recents`), "Yeni gelenler"/"Yeni Dosyalar" → **Yeniler** (`fresh.new`, `fm.new_files`, `hist.incoming`), Yaptıklarım (`act.title`) → Üretilenler. Kimlikler (`recent`, `new`) DEĞİŞMEDİ.
- **Geçmiş kutusu kalktı** (pano kutusu `recent`, `DashboardLayout.tiles`'tan çıktı; kayıtlı sıradaki kimlik `_merge`'de düşer). Bölüm kimliği `recent` (şerit) duruyor. `HistoryScreen` yalnız alt çubuk "Geçmiş" düğmesinden (dock) açılıyor.
- **Araçlar 2 satır** (`DashboardTools.rows` = 8): Harici bellek · İşlemler · **Üretilenler** (ActivityScreen) · Kasa · Yeni belge · Kopyalar · Ağdan erişim · Bağlantıdan indir. **Sesli kitaplarım** araçlardan çıktı → Kitaplık (AppBar simgesi + raf başında kart + boş ekranda düğme).
- **Bento:** ilk 2 büyük, sonraki **4** uzun (`_bentoMid`), gerisi küçük; Bento varsayılanı kullanıcının SS'i: Akıllı Düzen · Önemli | Fotoğraflar · Videolar | İndirilenler · Belgeler | Ses · APK · Uygulamalar · Kitaplık.
- **Kök (Yeniler geç yükleniyordu):** şerit, Yeniler ekranı ve Aktar şeridi sıcak klasörlerin TAMAMINI ayrı ayrı geziyordu (DCIM + WhatsApp medyası binlerce dosya), ilk sonuca kadar boş/iskelet. **Çözüm** `lib/services/fm/fresh_cache.dart`: tek ortak tarama (sürerken gelen istek bitince bir tur daha — yeni dosya kaçmaz), bellekte son sonuç, diskte (`fresh_cache_v1`) en yeni 60 yol → açılışta yalnız `stat` ile ANINDA ilk görüntü, ardından tam tarama yerine geçer. Doğruluk tam taramada. Gizlilik silmede temizlenir.
- **Görselde ne var** (`lib/screens/fm/image_insight.dart`): ham OCR dökümü yerine AI kısa özeti (tür + 1–2 cümle + ≤4 ayrıntı, 1280 px JPEG önizleme, istemde kişisel veri yasak; anahtar + AI kapsamı + çevrimiçiyse kendiliğinden, yoksa düğme), Akıllı düzen/cihaz türü çipleri, yazı katlanır bölümde. Oturum önbelleği yol+mtime+dil.
- **Akıllı klasör düzeni** (`smart_folder_prefs.dart`): ad (yalnız görünen; kimlik ve ikinci ad aynı, ad aramaya girer), sıra (basılı tut → menü; "Sırala ve adlandır" levhası `onReorderItem`), 2/3/4 sütun (menü + iki parmak sıkıştırma — `Listener`, hareket yarışına girmez).
- **Öğrenme** (`smart_learn.dart`, `smart_learn.json`): dosya ⋮ → "Kategori yanlış mı?" → "Ne olmalıydı?" (`smart_fix_sheet.dart`). (1) yerel en-yakın-komşu: düzeltme dosyanın özellikleriyle (klasör, uzantı, ekran görüntüsü uygulaması, ad sözcükleri — YOL SAKLANMAZ) tutulur; model aynı yanlışı verince ağırlıklı Jaccard oyu çevirir (≥0,85, "doğruymuş" onayları frenler, yalnız klasör+uzantı ortaksa ≥2 düzeltme gerekir, belgeye görsel kategorisi yok); (2) modele geri bildirim: kategori sorusuna "X yanlıştı Y olmalıydı (n×)" — YALNIZ kimlik + sayı, dosya adı buluta gitmez. Düzeltmede aynı yanlışla düzenlenmiş benzerler "onlar da?" diye sorulur.
- **Tuzak:** `showModalBottomSheet` tasarım mandalında dosya başına tavanlı (yeni dosyada 0) → `showAppSheet`. `showAppPrompt` boş yanıtı null (vazgeç) döndürür → varsayılan ada dönüş ayrı menü maddesi.
- ÖLÇÜM KAPISI (ana ekran: araçlar 8 hücre, Bento) — bulutta yapıldı, cihazda A/B ölçülmedi → `docs/CIHAZ_TESTI.md`.

## 2026-11-18 — Kök: Akıllı düzen başarısız dosyalar (main 63bf5a6f)
- **Kök ("300 başlattım, 27 çıktı"):** `SmartSort.run` yanıtsız/hatalı dosyayı sessizce `failed++` sayıp kayıt yazmıyordu → `needs` her turda AYNI başarısız dosyaları yeniden seçiyor, ileti yalnız başarılı sayıyı gösteriyordu. Tur kaldığı yerden devam eder (kaydı olan atlanır). **Çözüm:** oturum içi `_failures` (boyut+değişme+deneme; 2 denemeden sonra o oturumda atlanır), 429'da 30 sn bekleyip bir kez yeniden dene, iletide "N dosya yapılamadı: <neden>". Gerçek hata nedeni cihazdan bekleniyor.

## 2026-11-18 — Bulut gece zinciri (`oto-bulut`, zamanlanmış görev `okuyucu-bulut`)
- **Karar (kullanıcı: "notlardaki zincirin bulutta çalışacak versiyonu, kendi kendine bitirsin"):** claude.ai zamanlanmış görev (saatlik :37, her çalıştırma yeni bulut oturumu) → `oto-bulut` skill'i; yerel `oto-tur` (masaüstü + telefon) aynen kalır, ikisi `PLAN.md` §1'i paylaşır (bulut yalnız B, `bulutta:` önekiyle sahiplenir; C ve A/B yerelde). Kurulum + istem `OTOMASYON_BASLAT.md` (g).
- **Neden ayrı skill:** bulutta `.git/oto.lock` kaplar arası görünmez → uzak kilit `oto-kilit` dalı (`kilit.sh`: her yazım öncekinin çocuğu, düz ileri sarma push'u = karşılaştır-değiştir; bırakmak "SERBEST" commit'i; yaş = commit zamanı, eşik 60 dk; işçi her push'ta, yürütücü her uyanışta tazeler, döngü yok); `get_usage` yok → fren yok, kilit bayatlayınca sonraki çalıştırma sürer; `gh` yok → CI GitHub MCP; ön plan `sleep` engelli → arka plan `sleep`.
- **Tuzak (kota):** main'de test atlansın diye birleştirme ağacı yeşil dal ucuyla AYNI olmalı (`tool/ci_test_secimi.sh` HEAD^2 ağaç kıyası) → DEVIR.md CI'a giden uçta silinir ve `origin/main` ucun atası olmalı. Yalnız `.md`/`docs/`/`.claude/` değişen push CI açmaz (paths-ignore) → CI'ı başlatan son commit kod içermeli, `[skip ci]`'siz; elle tetik tam takım + APK derler (kullanılmaz).
- **İki yönlü devir (kullanıcı: "diğer görev yarım dallardan devam edebilecek mi"):** önce iki zincir birbirinin satırını hiç almıyordu, biri durursa yarım iş sahipsiz kalıyordu; yerel sahiplenme de main'e yazılmıyordu (bulut göremezdi). Şimdi ikisi de sahiplenmeyi main'e yazar (yalnız `.md`, CI açmaz); dal ≥ 3 saat sessizse (bulutunkiyse kilit de bayat) öteki zincir devralır, DEVIR.md'den sürer.
- **[apk]:** istem `ÖLÇÜMSÜZ APK = hayır` (ÖLÇÜM KAPISI): kapı yüzeyine varsayılan açık dokunan iş `[apk]`'sız, ölçüm C2'ye; günlük dilim sınırı 2026-11-18'de kaldırıldı (aşağı bak).
- **Tuzak (bulut git vekili):** dal SİLME push'u 403 (2026-11-18, `git push origin --delete ccr-…` reddedildi; yeni dal açma ve main'e ileri sarma geçti) → bulut zinciri dal silmez, zorla push kullanmaz; birleşmiş `faz-oto-*` dalları yok sayılır, yerel `oto-tur` siler.
- Denendi: `kilit.sh` silme + ileri sarmayan push'u kapalı çıplak depoda al / meşgul / tazele / bayat devralma / çalışma kopyasından tazele / bırak — geçti. Bulutta ilk çalıştırma kullanıcıda (sabah bakılacak: `oto-kilit` push'u bulut vekilinden geçiyor mu).

## 2026-11-18 — Kullanıcı kararları: her sabah APK + plan büyüdü (B9–B13)
- **"ÖLÇÜMSÜZ APK evet olsun, her sabah APK istiyorum":** bulut zinciri ölçümsüz `[apk]` yapar (en çok 4 saatte bir; TR 04:00–09:00 ilk birleştirme her zaman; 06:30'da hâlâ yoksa main'de günde en çok 1 elle tetik — `workflow_dispatch` main'de APP=true → apk + nightly, ama tam takım da koşar ≈ 50 dk). CLAUDE.md §4c'ye bulut istisnası yazıldı; ölçüm sonra C2'de, gerileme → revert/düzeltme SIRA'nın önüne.
- **"Planı büyütelim — Word, PDF, Excel, slayt + performans, hızlandırma, akıcılık, deneyim hissi":** `PLAN.md` §1'e B9 Word 2.0, B10 Excel 2.0, B11 Slayt 2.0, B12 Hız 2.0 (cihazsız kanıtlı), B13 Deneyim hissi; PDF'e B4 P22b okuma deneyimi. Yeni SIRA (kod): B1 → B12 → B9 → B13 → B10 → B4 → B11 → B2 → B5 → B6 → B7; telefonla C1 → C2 → B3 → C3; en son B8. Ferrari kuralı gevşedi: B9–B11 ve B4 varsayılan açık birleşebilir (sıcak yola dokunmadan, bütçe testi yeşil).
- **Kanıtlı boşluklar (plan yazılırken koddan):** `docx_document.dart` `_readBody` blok `w:sdt`'yi (İçindekiler, kapak, form alanı) tek opak paragrafa düzleştiriyor (`grep sdt lib` = 0); değişiklik izleme yazarken yok (`trackRevisions` = 0); grafik yalnız 4 tür (`XlsxChartKind`, `SlideChartKind`, `pptx_render` `ChartType`); formül 189 işlev, TEXTSPLIT/LAMBDA/VSTACK yok; `lib/screens`+`lib/widgets` 14 dosyada eşzamanlı dosya G/Ç.

## 2026-11-18 — Akıllı düzen 2.0: Office/metin/APK türleri (bulut, dal faz-oto-B1-duzen2)
- **Karar:** görsel/PDF dışındaki türler `SmartSortInput` (`lib/services/fm/smart_sort_input.dart`) ile tura girer: Word/ODT/RTF/TXT/MD/HTML/EPUB yazısı ≤ 20 bin karakter, Excel/CSV/ODS ilk sayfa ≤ 200 dolu satır CSV (xlsx `XlsxStream` akışla, hücre tavanlı), PowerPoint/ODP slayt yazıları; çıkarma `Isolate.run`'da. APK/arşivin içine bakılmaz — yalnız ad · boyut · köke göre göreli klasör yazısı. Ses/video hâlâ yok. Kaynak sınırı 40 MB (meta sınırsız); boş/okunamayan → `GeminiException(-1)` → "yapılamadı" sayılır, tur durmaz.
- **Tuzak:** metin dosyasının başını bayt olarak kesince UTF-8 karakteri ortadan bölünürse `TextDecode.decode` katı UTF-8'de düşüp cp1254'e döner (Türkçe "ş" → "Åž"); `_cutText` yarım karakteri atar (test var). ODF/EPUB için yeni bağımlılık yok: zip + `xml` olay akışı, `content.xml` ilk 8 MB.

## 2026-11-18 — Kök: galeride fotoğraf takılarak açılıyor (özellikle eski fotoğraflar)
- **Kök (kullanıcı: "takıla takıla geliyor, eski fotoğraflarda daha fazla"):** (1) `EntryOpener.open` galeri yolunda `_remember` (bütün açılış geçmişinin JSON'u + başlatıcı kısayolu) geçişten ÖNCE çalışıyordu — oynatıcıda `_afterTransition` ile ertelenmişti, galeride unutulmuş. (2) `_PhotoThumb` yalnız TAM boy küçük resmi `fmRememberThumb` ile bildiriyordu; eski fotoğrafta ızgara çoğu kez önizlemeyi (başka boy) gösterir → galeri ilk kareyi/en-boy oranını bulamıyor, kahraman kutusu ekranı kaplayıp tam çözüm gelince geçiş ORTASINDA yeniden yerleşiyordu. (3) Tam boy çözüm + iki komşunun ön-çözümü büyüme animasyonuyla yarışıyordu.
- **Çözüm:** galeride geçmiş kaydı geçiş bitince; önizleme de bildirilir; küçük resim + oran biliniyorsa geçiş boyunca yalnız küçük resim (`_ZoomableImage._full`), tam boy ve komşular geçiş bitince.
- Videoda zaten `_openAfterTransition` var; değişiklik yok. Ölçüm kapısı (geçiş): cihazda A/B ölçülmedi → C2.

## 2026-11-18 — Akıllı düzen şema 2.0 (bulut, dal faz-oto-B1-duzen2; PLAN §1.1 m.1)
- **Karar:** tek istek korunur (görsel 25, belge 21 soru; `maxQuestions` 40). Alt türler her belge kategorisinde + ekran görüntüsü/fotoğraf (yalnız görselde sorulur); alt tür kimlikleri bütün kategorilerde TEKİL (`sm.s_<kimlik>`, test denetler). Fatura kurumu ayrı `provider` sorusu (GSM, internet/TV, ~13 elektrik/doğalgaz/su şirketi); `providerFits` kurumu yalnız faturada ve alt türüyle uyumluysa alır (elektrik faturasına Turkcell yazılmaz).
- **Tarih:** model serbest tarih vermez → istekte "Today is YYYY-AA-GG" + bugüne göre aralık (`due`: geçmiş·hafta·ay·sonra, `valid`: geçmiş·ay·yıl·sonra); kayıtta aralık + sorulduğu gün (`ad`). `SmartDates` "hafta içinde" olanı 7 gün sonra kendiliğinden "ödemesi geçmiş" sayar — yeniden sormadan. Sorulduğu gün bilinmeyen (0) yalnız "geçmiş" yanıtıyla rozet alır. Rozet/tutar süzgeci yalnız Akıllı düzen ekranında (liste sıcak yoluna dokunulmadı).
- **APK/arşiv:** `package` kategorisi, tek soru (kurulum · yedek · indirme); öğrenme çevirmez (çevirse `needs` her turda yeniden sorardı). Eski şemada belge kategorisi almış APK bir kez ucuz soruyla yeniden sorulur.
- **Geriye uyum:** yeni alanlar (`pv/du/va/am/ad`) yoksa ya da türü bozuksa boş/0 — eski kayıt düşmez; eski kayıtlar yeniden SORULMAZ (kota). `usage` alan adı API'de doğrulanmadı (`usage`/`usage_metadata`/`usageMetadata` denenir) → rapor gelmezse ekranda satır yok.

## 2026-11-18 — Akıllı düzen 2.0: ses ve video (bulut, dal faz-oto-B1-duzen2; PLAN §1.1 m.2)
- **Karar:** ses (mp3/m4a/aac/ogg/opus/wav/flac) ve video (mp4/3gp/webm/mov/mkv) **sabit kategori** (`audio`/`video`, uzantıdan; `SmartTaxonomy.fixedCategories` — öğrenme çevirmez) + tek istekte alt tür; seste konuşma dili (`lg`) + kalite (`ql`), videoda "yanlışlıkla/çok kısa/karanlık" → `accidental` → Ayıkla (hücre `FmEntryIcon` ile ilk kare). Aile videosuna ikinci ad yok (kişisel fotoğraf kuralı). Video bloğu `media_resolution: low` + `video_metadata` 0s–60s.
- **Files API:** ≤ 14 MB satır içi (base64 izolatta), üstü `GeminiService.uploadFile` (sürdürülebilir yükleme, gövde diskten akışla `_FileUpload`; görünen ad sabit — kişisel dosya adı sunucuya gitmez; PROCESSING → ACTIVE beklenir; iş bitince `deleteFile`). Yüklenen dosya yalnız yükleyen anahtarın projesinde görünür → `SmartPrepared.keys` o tek anahtar; yüklemede 401/403/429 → sıradaki anahtar. Sınır: ses 100 MB, video 50 MB (bütün dosya yüklenir; kırpma m.5).
- **Doğrulanmadı (tahmin):** Decisions bloğunda `file_data: {file_uri, mime_type}`, `media_resolution`, `video_metadata` alan adları API'de denenmedi (generateContent'teki adlar) → cihazda "yapılamadı" çıkarsa önce bunlara bak.
- **Kapsam:** WhatsApp Voice Notes/Audio/Video + `Recordings` köklere eklendi; Kamera kapalı varsayılanı aynen (DCIM/Camera videoları gitmez). Sabah bakılacak: Müzik klasörü bilinçli dışarıda (kota).
- 2026-11-18 · Bulut zinciri: günlük dilim sınırı (`GÜNLÜK DİLİM = 6`) KALDIRILDI — kullanıcı: "iş bitene kadar devam". Skill + OTOMASYON_BASLAT + zamanlanmış görev istemi güncellendi; durdurucu yalnız 9. adım (kota/fatura hatası dahil).

## 2026-11-18 — Akıllı düzen 2.0: kullanıcı kategorileri (bulut, dal faz-oto-B1-duzen2; PLAN §1.1 m.3)
- **Karar:** her kullanıcı kategorisi AYRI `noul` sorusu (`uc_<kimlik>`, eşik 0,7) — yerleşik `cat` seçeneğine eklenmez (kalibrasyon bozulmaz), dosya birden çok kategoride olabilir. Kimlik `u:` önekli; kayıtta `uc` (eşleşen → yüzde) + `uq` (sorulanlar). Normal turda soru bütçesinin (40) kalanı kadar aynı istekte sorulur; sığmayan ve eski dosyalar "Eski dosyalara uygula" (yalnız o soru, 2 paralel, durdurulabilir; kayıt dosyayla aynıysa). En çok 30.
- **"Dene" kapısı:** son 20 dosyada tek soru; `SmartUserCats.canSave` = deneme bu ad+cümleyle + ≥1 eşleşme + kullanıcı onayı. Ad/cümle değişince eski yanıtlar silinir (soru değişti); yalnız simge/renk değişirse deneme gerekmez. Deneme yanıtları kaydedilince kayda yazılır (dosya değişmediyse).
- **Aynı yol:** süzgeç `FmFilter.smartUserCatsOf` kancası (aynı `smartCats` kümesi; kategori yoksa tek karşılaştırma), akıllı klasör `SmartSort.pathsOf('u:…')`, arama `keywordsOf` adları, ikinci ad baskınsa (yüzde > yerleşik güven ya da yerleşik ad boş — kişisel fotoğrafta da) kategorinin adı. Liste satırı kurulumu değişmedi; süzgeç sayımı C2'de ölçülecek.
## 2026-11-18 — B12 Hız 2.0 m.2 + m.4 (bulut, dal faz-oto-B12-hiz2)
- **Kök (m.2, koddan):** ilk açılışlar zaten izolattaydı; ana izlekte kalanlar `FileService._loadLegacy` (XlsLegacy.tryParse + toXlsxBytes, LegacyText), dört editörün `_restoreDraft`i ve `DocChapters.load` (docx/pptx). Hepsi `compute`/`openForView`/`_parseDeck` ile izolata; Slayt `_load` da tek kapı `_parseDeck`.
- **Bekçi:** `test/open_parse_isolate_test.dart` — sentetik büyük docx/xlsx/pptx ana izlekte > 16 ms (Stopwatch, kanıt) + ekranlarda çıplak `X.parse(` dosya başına tavan (koparma `compute(X.parse, b)` eşleşmez). Word `_rerender` tavanda (m.3).
- **m.4:** `test/image_cache_guard_test.dart` — `Image.memory`/`MemoryImage` çözme boysuz olamaz. Tuzak: `cover` kutuda yalnız `cacheWidth` yatay görseli bulanıklaştırır → ham küçük resimde `ResizeImage(policy: fit)` iki kenar tavanı (büyütmez). Word editöründe `cacheWidth` sürüklenen genişlikten değil `maxW`den (kademeli; her karede yeniden çözme olmasın).
- ODF/EPUB uygulamada açılmıyor (ODT/ODS/ODP harici aç) → m.2 kapsamı dışı. Cihaz A/B → C2.

## 2026-11-18 — B12 Hız 2.0 m.1 + m.5 (bulut, dal faz-oto-B12-hiz2)
- **Bekçi (m.1):** `test/sync_io_guard_test.dart` — `lib/screens`+`lib/widgets` senkron G/Ç (`sync_io_ratchet_test` ile aynı aile) DOSYA BAŞINA tavan, düşünce tablo da düşmeli (slack denetimi). Toplam cırcır 26 → 22.
- **Karar:** `build` içindeki stat'ler eşzamansız + önbellek: arşiv oranı (`_measureArchive`), SD birleştirme aday klasörleri (`_scanFolders`, `_load` setState'inden SONRA beklenmeden — sd_union_test sahte saatte ek tur istemesin), klasör seçici kısayolları (`_liveDir`: yol başına bir kez, sonuç gelene dek gizli). Ana ekran/pano/dosya seçici/galeri/PDF kabuğundakiler ÖLÇÜM KAPISI → tavanda, C2.
- **m.5:** `AppHaptics.load` beklenmiyor; aynı `SharedPreferences.getInstance` geleceğinin ilk dinleyicisi olduğundan değer `appState.init`ten önce yerinde. Kenardan kenara `await` bilinçli (ilk kare zıplamasın). `startup_budget_test` runApp öncesi tavan 6 (mandal).

## 2026-11-18 — B12 Hız 2.0 m.3 editör yeniden kurulum bütçeleri (bulut, dal faz-oto-B12-hiz2)
- **Sayaç:** `test/support/rebuild_probe.dart` — eylemden önce her öğenin widget örneği, sonra örneği değişen/doğan öğe sayısı (`debugOnRebuildDirtyWidget` RenderObject güncellemesini saymaz; bu sayar). Aynı örnekle atlanan alt ağaç sayılmaz.
- **Kök (Word):** `_changed` → setState her tuşta görünür TÜM paragrafların TextSpan'ini kurup RenderParagraph'ta derin karşılaştırıyordu. Düzeltme: dizin → (paragraf nesnesi, ölçek, hiza, yön) RichText önbelleği; satır içi öğeli paragraf (seçime/eyleme bağlı) önbelleğe girmez; çizici her kurulumda yenilenir (imleç/seçim çizimi aynı). Tuzak: tüm paragraf widget'ını önbelleklemek çiziciyi de dondurur (shouldRepaint yolu kalkar) → yalnız RichText.
- **Excel:** yüzer editörde her harf tüm ekran setState (`entry.dart` onChanged); metin bağımlı parça çok (formül çubuğu ✓, işlev önerisi, başvuru renkleri, tamamlama) → ölçümsüz daraltma yok. **Slayt:** sürükleme zaten yerel. **PDF:** pdfrx testte kurulamıyor (pdfium yok) → kaynak bekçisi; sayfa değişimi daraltması C2.

## 2026-11-18 — Akıllı düzen 2.0: doğruluk tezgâhı (bulut, dal faz-oto-B1-duzen2; PLAN §1.1 m.4)
- **Karar:** Ayarlar → Geliştirici (gizli) → "Doğruluk ölçümü"; etiketler `smart_bench.json` (appSupport, en çok 100) yalnız cihazda. Model yanıtı = ölçüm sorusu (`SmartSort.probe`: yerleşik sorular + öğrenme, kullanıcı kategorisi sorulmaz, **kayda yazmaz** — elle düzeltme bozulmasın) ya da elle düzeltilmemiş ve dosyası değişmemiş güncel kayıt. Elle düzeltilmiş kayıt model yanıtı sayılmaz (asıl yanıt bilinmiyor).
- **Ölçüt:** kategori oranına uzantıdan kesin kategoriler (ses/video/kurulum) girmez; alt tür yalnız etiketlenmişse ("Puanlama" ≠ "Hiçbiri"), kategori yanlışsa alt tür de yanlış; tarih = ay + yıl birlikte (0 = yok/eski, model `older`/`none` ikisinde de 0). Eşik önerisi: 0,30–0,95 (0,05) içinde eşik üstü doğruluğu ≥ %90 olan en düşük eşik, ≥ 5 dosya.
- **KVKK:** dışa aktarılan rapor yalnız sayı + kategori kimliği (test: yol/ad yok); panoya kopyalanır, `docs/ai/`ye elle. Gerçek ölçüm C2.

## 2026-11-18 — B12 Hız 2.0 m.6 + m.7 (bulut, dal faz-oto-B12-hiz2; B12 BİTTİ, A/B → C2)
- **m.6 kanıt (koddan):** tablo görünümü her hücre `Container(height: cellH)` → `itemExtent: cellH` (yazı ölçeğinden bağımsız); çalma listesi tek satır ad + tek satır boyut + 20 dp simge → `prototypeItem` (gerçek satır, 2× yazıda da doğru). Bekçi `test/list_extent_ratchet_test.dart` (≥ 11, dosya başına adıyla).
- **Reddedilen adaylar (değişken boy):** ayarlar (karışık `ListView(children:)`), işlem geçmişi (başlık 2 satır), arşiv (kilit simgesi ↔ 48 dp düğme, küçük simge ölçeğinde boy farkı), yüklü uygulamalar (koşullu boyut çubuğu), klasör seçici (izinsiz satırda alt yazı), kasa (klasör/dosya ayrı kutucuk). Arama sonuçları zaten `FmFileListView` (prototip). Dosya seçici/çöp kutusu `FmEntryRow` ama başlık/ayraç karışık → ölçümle (C2).
- **m.7:** 53 doğrudan bağımlılığın hepsi `lib/`de içe aktarılıyor; içe aktarılmayan 3'ü bilerek: `syncfusion_flutter_core` (sürüm eşi), `shared_preferences_android` (2.4.28 sabit), `media_kit_libs_android_video` (yerel mpv). Varlıkların hepsine başvuru var (`assets/` satırı yalnız boş yer tutucu dosyayı paketler, 0 bayt — pubspec'e dokunulmadı). Bekçi `test/unused_dependency_guard_test.dart`.

## 2026-11-19 — Akıllı düzen 2.0 hız/kota + ilk slayt (bulut, dal faz-oto-B1-duzen2; PLAN §1.1 m.5 + m.2 kalanı; B1 kodu BİTTİ, ölçüm C2)
- **Kök (koddan):** tur hazırlığında ana izlekte kalan üç ağır iş: `GeminiDecisions.fileBlock` base64'ü, `ask`taki `jsonEncode` ve `GeminiService._post` kişisel veri maskesi (varsayılan AÇIK → bütün gövde `jsonDecode`+`jsonEncode`; 14 MB görselde ~19 MB yazı, BÜTÜN AI görsel çağrılarında). 256 KB üstü gövde/veri izolatta (`Isolate.run`, sonuç kopyasız); bekçi `test/smart_offload_test.dart`.
- **Karar (sabah bakılacak):** `SmartQuota` — "yalnız Wi-Fi'de" varsayılan AÇIK (en güvenli: büyük video/ses mobil veriyi yemesin); bağlantı türü okunamazsa ölçülü sayılır. Ölçülü ağ: `dosya/extras` → `isMetered` (`ConnectivityManager.isActiveNetworkMetered`, ACCESS_NETWORK_STATE zaten vardı). Günlük sınır 50/100/200/500/1000, varsayılan 200 (tahmin; 7 günlük istek/429 sayımı ekranda — C2'de gerçek değerle düzelt). Sayılan: yalnız tur istekleri (her `ask` + 429 yeniden denemesi bir hak; her 429 tek yerde sayılır); "AI ile ikinci ad" (tek dosya), "Dene"/geriye dönük uygulama sayılmaz/durdurulmaz.
- **Büyük video:** 14 MB üstü ve 65 sn'den uzun videoda Media3 hızlı kesimle (`VideoTranscoder.clipTo`, geçici klasöre; kullanıcı klasörüne dokunmaz) ilk 60 sn; kesit ≤ 14 MB satır içi, ≤ 50 MB Files API, üstü "yapılamadı". Kesitler sırayla (kanal tek iş); kanal meşgulse/kesit olmazsa eski yol (≤ 50 MB bütün dosya). Kaynak sınırı 1 GB. Kesit yeniden kodlamasız → yüksek bit hızlı videoda 60 sn > 50 MB olabilir (o zaman gönderilmez; ölçekleme istenirse Kotlin `start`a kırpma eklenmeli).
- **İlk slayt görüntüsü:** yeni çizim yok — PowerPoint/LibreOffice'in dosyaya gömdüğü önizleme (`OfficeThumbnail.readEmbedded`, ≤ 1 MB PNG/JPEG) yazı bloğuna ek `image` bloğu (`SmartPrepared.extra`/`input`). Çok bloklu Decisions girdisi API'de denenmedi.
- **Tuzak (CI kırmızı, 2026-11-19):** bir sınırı (video 50 MB → kaynak 1 GB) değiştirince yalnız ana test dosyasını değil, aynı API'yi (`SmartSort.supports`) sınayan TÜM testleri `grep` et — `smart_sort_input_test` eski 60 MB=false beklentisinde kalmıştı.
