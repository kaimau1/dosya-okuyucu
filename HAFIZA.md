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

## 2026-11-19 — B9 Word 2.0 m.1 içerik denetimleri + m.6 sadakat bekçisi (bulut, dal faz-oto-B9-word2)
- **Kök (m.1):** `_readBody`/`_readTable` `default:` dalı blok `w:sdt`yi `_opaque` ile tek paragrafa düzleştiriyordu. Düzeltme: `_readSdt` — `sdtContent` içindeki `p`/`tbl`/iç içe `sdt` aynı yoldan, `container = sdtContent` (kap korunur; birleştirme/seçim silme zaten aynı kap şartlı). Kilitli (`w:lock` content/sdtContentLocked) ya da `w:dataBinding`li denetim `_frozen` (biçimli ama `opaque`) — **karar (sabah bakılacak):** veri bağlı alanı Word açılışta bağlı XML'den yeniden yazar, düzenleme sessizce kaybolurdu → salt okunur.
- **Tuzak:** paragraf/tablo yerleştirme gövde düzeyinde kap varsayıyordu. `_place` artık önceki/sonraki paragraf iç içe kaptaysa (`_childOf`) kabın ardına/önüne koyar; `insertTable` `_lastOfBlock` (denetimin son paragrafından sonra), `_syncNewTables` önceki öğenin gövde düzeyindeki atasını kullanır. Kayıtta boş kalan `sdtContent`e boş `w:p` (Word boşu bozuk sayar).
- **Satır içi form:** `DocxAtomKind.control` (düz/zengin metin, `w14:checkbox`, `dropDownList`, `comboBox`, `date`); galeri (`docPartObj`), resim, alıntı, denklem, grup, kilitli/bağlı → eski `inline` atom. Doldurma kabın KOPYASINI değiştirir (geri al özgün düğümü tutar); tek run + tek `w:t` ise yalnız yazı değişir (test: XML farkı = `w14:val` + simge). Yer tutucu stili (`PlaceholderText`) ve `showingPlcHdr` düşer; liste `w:lastValue`, tarih `w:fullDate` + `w:dateFormat` (d/dd/M/MM/MMM/MMMM/ddd/dddd/yy/yyyy, tr/en adlar).
- **Kalan:** satır/hücre düzeyi `w:sdt` (`w:tr`/`w:tc`yi saran — `_readTable` yalnız doğrudan `tr`/`tc` okur; içerik görünmez ama kayıtta korunur).
- **m.6 bekçi:** `test/word_roundtrip_test.dart` + `test/support/docx_synth.dart` (sentetik paket kurucu; ad alanları w14/w15/mc/wps/dgm/c/v/o). Bütün parçalar bayt eşit; tek düzenleme = tek `w:p` farkı; egzotik öğe XML'i (drawing, pict, object, AlternateContent, alan, yer imi, başvurular) aynen.

## 2026-11-19 — B9 Word 2.0 m.2 İçindekiler + m.5 dipnot/sonnot (bulut, dal faz-oto-B9-word2; yazıldı, cihazda doğrulanmadı)
- **m.2:** `DocxInsertPro.toc` — Başlık 1–3 → `w:sdt` (galeri "Table of Contents") içinde `TOC \o "1-3" \h \z \u` + `_Toc` yer imi köprüsü + `PAGEREF` (sayfa = `_layoutPages` tahmini). Var olan İçindekiler (galeri sdt ya da denetimsiz TOC alanı) YERİNDE güncellenir; başlık stili `TOCHeading` anahat dışı (`outlineLvl 9`) → kendini listelemez. Paragraf eşleşmesi `wordTocText` ile metin doğrulamalı.
- **Kök (m.1 ek):** `DocxPackage.modelParagraphs` blok `w:sdt`yi tek öğe sayıyordu; editör m.1'den beri içini ayrı okuyor → Araçlar işlemleri sdt sonrası paragrafta kayıyordu. Düzeltme `_sdtParas` (`_readSdt` ile aynı sıra; kilitli/bağlı denetimdeki tablo tek öğe).
- **m.5:** not numarası belge sırasıyla (`noteLabels`, `w:id`den bağımsız; `footnotePr/endnotePr` numFmt/numStart; sonnot varsayılan i, ii). Not anahtarı: dipnot `w:id`, sonnot `e:<id>`. Silme yalnız modelden başvuruyu kaldırır; parça kaydette KOPYA üzerinde budanır (`_prunedFootnotes`) → geri al notu getirir, dokunulmayan belgede not parçaları bayt eşit.
- **Kalan / bilinçli:** PDF'te notlar belge sonunda liste — `pdf` MultiPage sayfa içeriği bilinmeden sayfa altı kurulamıyor (ayrı iş).

## 2026-11-19 — B10 Excel 2.0 m.2 formül kapsamı + m.6 sadakat bekçisi (bulut, dal faz-oto-B10-excel2)
- **m.2:** `lib/services/formula/arrays.dart` — TEXTSPLIT, VSTACK/HSTACK, TAKE/DROP, CHOOSECOLS/CHOOSEROWS, XMATCH (önce-bak: yoktu, `_xlfn` listesinde vardı), LAMBDA/MAP/REDUCE/SCAN/BYROW/BYCOL/MAKEARRAY, NETWORKDAYS.INTL/WORKDAY.INTL. IFS/SWITCH/MAXIFS/MINIFS/TEXTJOIN/CONCAT zaten vardı; SWITCH/MAXIFS/MINIFS/CONCAT/LET'in takma adı yoktu → tamamlamada görünmüyordu, LET dosyaya `_xlfn.`siz yazılıyordu (düzeldi).
- **LAMBDA kararı:** motor ayrıştırırken hesaplar (AST yok) → LAMBDA gövdesi METİN saklanır, her çağrıda alt `_Parser` ile (parametreler `_locals`) yeniden ayrıştırılır; Türkçe ondalık kipi tanımlandığı formülden taşınır (`decimalComma`). Dosyadaki `_xlpm.` öneki `_stripPrefix`te okunur; YAZMADA eklenmiyor (PLAN §1.10 m.2 kalanı).
- **Dizi sabiti** `{1,2;3,4}` artık gerçek dizi (eskiden yalnız ilk öğe): `,`/`\` sütun, `;` satır; tek değer yerinde `_single` ilk öğeyi alır (eski sonuç), TOPLA({..}) tümünü toplar. Türkçe kipte `{1,5}` ondalık okunur (hipotez: Türkçe Excel dizi ayırıcısı doğrulanmadı).
- **Türkçe adlar (sabah bakılacak):** METİNBÖL, DÜŞEYYIĞ, YATAYYIĞ, AL, BIRAK, SÜTUNSEÇ, SATIRSEÇ, ÇAPRAZEŞLEŞTİR, TAMİŞGÜNÜ.ULUSL, İŞGÜNÜ.ULUSL, İLKEŞLEŞEN, ÇOKEĞERMAK, ÇOKEĞERMİN, ARALIKBİRLEŞTİR; LAMBDA ailesi İngilizce kimlik takma adıyla.
- **Bekçiler:** `test/formula_array_text_test.dart` (MS belge örnekleri + kapsam listesi: tanınır / tamamlamada / yardım imzası); `test/excel_roundtrip_test.dart` + `test/support/xlsx_synth.dart` (sentetik .xlsm: pivot+önbellek, dilimleyici, x14 koşullu biçim, tanımlı adlar, dış bağlantı, vbaProject.bin). Koddan: `XlsxPackageWriter.write` bilinmeyen parçaları bayt bayt taşır, workbook.xml DOM'la, sayfa XML'i dizge yamasıyla yeniden yazılır (extLst korunur). Yerelde koşturulmadı → CI.
- **CI kırmızı kökü (2026-11-19, 5 test):** (1) `_hasTopSemicolon` dizi sabitindeki `;`'yi Türkçe yazım sayıyordu → `{1,2;3,4}`te `1,2` ondalık (1.2) okundu (TAKE/DROP/CHOOSECOLS/dizi sabiti testleri). Düzeltme: `{…}` içi `;` sayılmaz; Türkçe işareti = dışarıda `;` ya da dizide `\`. Aynı kök `toFile`'da `{1,2;3,4}`ü kayıtta `{1.2,3.4}` yapıyordu → dizide `;` kalır, `\`→`,`; `toTurkish` dizide `,`→`\`. (2) NETWORKDAYS.INTL `"0010001"` önce sayıya (10001) çevrilip #SAYI! veriyordu → 7 haneli 0/1 kalıbı sayıdan önce bakılır.

## 2026-11-19 — B9 Word 2.0 m.3 Değişiklikleri izle (bulut, dal faz-oto-B9-word2; yazıldı, cihazda doğrulanmadı)
- **Tasarım:** ekleme = harf biçimine `DocxRev` işareti (`DocxCharStyle.rev`; `merge/withLook/detached/withRev` taşır, `_sameWrite` karşılaştırır) → `_rebuild` ardışık aynı işaretli run'ları tek `w:ins`e sarar. Silme = modelden çıkar, XML'de sıfır genişlikli çapa `w:del` (`w:t`→`w:delText`, `instrText`→`delInstrText`) — IME metni ile model boyu hep eşit kalır (silinen metni modelde tutmak klavye ofsetlerini bozardı). Tüm yazma/silme `doc.editText` (`docx_track.dart`) üstünden; izle kapalıyken yazılan harfe komşu eklemenin işareti GEÇMEZ (`withRev(null)`).
- **Okuma:** yalnız düz metin run'lı `w:ins` artık düzenlenebilir metin (eskiden tek atom); özgün öznitelik/kimlik ilk yazımda korunur, bölünürse sonrakiler yeni kimlik (`_revEmitted` kalıcı). Kimlik sayacı belgedeki izleme öğelerinin en büyüğünden artar.
- **Sıra tuzağı:** art arda geri silmede yeni `w:del`, [a]'daki eski çapalardan SONRA ve [b]'den kayanlardan ÖNCE konur; bitişik kendi silmemizle KOPYA üzerinden birleşir (geri al eski düğümü tutar). Başkasının eklemesini silmek `w:ins > w:del`; kendi eklemesini silmek iz bırakmaz.
- **Kök (eski hata):** `resolveTrackedChanges` `commit()` etmeden XML'i çözüp modeli yeniden okuyordu → kaydedilmemiş düzenlemeler kayboluyordu. Düzeltme: önce `commit()`; ret `delInstrText`i de geri çevirir.
- **Bilinçli sınır:** paragraf işareti (Enter/birleştirme) ve biçim değişikliği izlenmez; izle açıkken çok paragraflı seçim silmesi paragrafları birleştirmez. Yazar = yorum yazarı tercihi (`word.comment_author`), boşsa "Yazar". m.4 önce-bak: yorum yaz/yanıtla/çözüldü (`commentsExtended` `w15:done`) zaten vardı; kalan kenar balonu.

## 2026-11-19 — B10 Excel 2.0 dilim 2: m.3 veri doğrulama + m.2 `_xlpm.` yazımı (bulut, dal faz-oto-B10-excel2; yazıldı, cihazda doğrulanmadı)
- **Önce-bak (koddan):** satır içi liste, sayı/tarih/uzunluk, açılır ok, levha ve "Durdur" Faz 27'den beri vardı. Eksikler: aralık/ad/başka sayfa listesi (`options` null → ok yoktu), özel formül ve başvurulu sınır (`accepts` hep true), `errorStyle`/`errorTitle`/`prompt`/`showDropDown`/`showInputMessage` kayıtta düşüyordu (`XlsxValidationWrite.from`), `x14:dataValidations` (Excel'in başka sayfa listesi) hiç okunmuyordu.
- **Kök (bug):** `structure_edit` satır/sütun eklemede kuralı yeniden kurarken işleç, ikinci sınır, uyarı metni ve allowBlank'i atıyordu (≤ 10 kuralı "arasında"ya dönüyordu). Düzeltme `XlsxDataValidation.copyWith`.
- **Karar:** `showErrorMessage` dosyada yoksa Excel uyarmaz → uygulama da engellemez (Excel'e sadık; uygulamanın kurduğu kuralda hep 1). Uyarı = sorulur, Bilgi = yazılır + bildirilir; formda yalnız Durdur engeller.
- **Yapı:** formüle bağlı denetim `lib/services/xlsx/validation_check.dart` (motor ister): göreli başvurular kural aralığının sol-üstüne göre `shiftFormula`la kayar; özel formül ızgaranın SIĞ kopyasında (yalnız değişen satır) hücreye giriş yazılmış gibi hesaplanır. Tanımlı ad okumada `listRef`e çözülür (kayıtta ad kalır). Liste ≤ 1000 seçenek; çizimde yalnız ucuz `_hasValidationList` (çözüm ok açılınca).
- **x14:** ana `dataValidations`a yeni kural yazılır (başka sayfa başvurusu ana öğede de geçerli); temizlenen aralığa değen x14 kuralı uzantıdan silinir, boşalan `ext`/`extLst` kalkar.
- **`_xlpm.`:** `toFile` LET (çift sıralı, sonuncu hariç) ve LAMBDA (sonuncu hariç) parametrelerini iç içe toplar, bildirim + kullanımda önek; aynı adlı bilinen işlev çağrısı, metin, `Sayfa!`, aralık (`:`) dokunulmaz; kapsam yaklaşık (ad formülün her yerinde). Gösterimde önek kalkar.

## 2026-11-19 — B9 Word 2.0 m.8 Büyük belge açılışı (bulut, dal faz-oto-B9-word2; yazıldı, cihazda doğrulanmadı)
- **Önce-bak:** tam ayrıştırma zaten izolattaydı (`compute(_parse)`); eksik olan "ilk sayfa": önizleme yalnız ilk 50 paragrafın DÜZ METNİ (regex) — başlık/kalın/hiza/tablo/resim yok, tam modelden farklı görünüp geçişte zıplıyordu.
- **Çözüm:** `DocxDocument.parseHead` — `docxHeadXml` dizge taramasıyla `document.xml`i ilk 60 üst düzey bloktan (ya da toplam 120 paragraf; tablo/`w:sdt` asla ortadan bölünmez) sonra keser, gövde `w:sectPr`'si korunur (paragraf içindeki bölüm sonu alınmaz), aynı `_readBody` yolu. Ekran baş ve tam ayrıştırmayı aynı anda iki izolatta başlatır; baş `DocxEditorView(readOnly: true)` ile çizilir (kaydırma var, dokunuş/klavye yok); baş çözümlenemezse eski düz metin önizlemesi.
- **Güvenlik:** baş modeli `headOnly` — `buildArchive` StateError atar (kaydedilseydi belgenin geri kalanı silinirdi). Kısa belgede kesme yok (`headOnly` yanlış, tam model).
- **Bekçi:** `word_perf_test` "5000 paragrafta ilk kare ≤ 60 paragraf, ≤ 400 ms" (mandal, yalnız düşer); `test/docx_head_test.dart` kesme kuralları.

## 2026-11-19 — B13 Deneyim hissi dilim 1 (yerel, dal faz-oto-B13-his; yazıldı, cihazda doğrulanmadı)
- **Önce-bak:** m.2 (öngörülü geri, H6.6), m.6 (taslak + kurtarma + "Kaydedildi", Faz 20 ED2), m.9 (a11y_guidelines_test, Faz 16) zaten vardı — yeniden yazılmadı.
- **m.3 dokunuş haritası:** seçim = `selection`, uzun bas/sürükleme başı = `longPress` (orta), bırakma = `drop` (hafif), yıkıcı onay = `destructive`, hata = `warning` (yalnız kopyalanabilir hata bildirimi — `showSnack(copyable:)` hata işareti sayıldı). Bekçi: yeniden sıralama başı/sonu doğru anlamda.
- **m.5 kök (bug):** Önemli ekranında kategori silme çöp ayarından bağımsız `FileOps.deleteAll` ile KALICI siliyordu. Artık çöp açıksa `trashWithUndo` (deleteEntries ile ortak uç). Bekçi `undo_paths_guard_test`: ham silme/çöpe atma tavanı + `FileOps.rename` eden ekran `showUndoToast` içerir.
- **m.8 kök (bug):** özel Word editörü (`DocxEditorView`) imleci yalnız denetleyici değişince görünür kılıyordu; klavye açılınca görünüm daralıp kaydırma aynı kaldığından alttaki imleç klavye altında kalıyordu. `didChangeMetrics` → kare başına bir kez animasyonsuz `_revealCaret`.
- **Kalan:** m.1 Office/PDF açılış geçişi (cihaz ölçümüne bağlı), m.4 Excel/Slayt aşamalı açılış, m.7 hareket eşitliği.

## 2026-11-19 — B13 Deneyim hissi dilim 2 (yerel, dal faz-oto-B13-his; yazıldı, cihazda doğrulanmadı)
- **m.4 aşamalı açılış (Excel/Slayt, Word B9 m.8 yolu):** tam ayrıştırma ile AYNI ANDA ayrı izolatta baş okunur; tam model önce biterse baş atılır (`_editor != null` bekçisi). Slayt `PptxEditor.headViews` (ilk 3 slayt çizimi; deste ≤ 3 → null). Excel yalnız ≥ 1 MB xlsx/xlsm: Faz 42 akış okuyucusu `maxCells: 800` → `SheetHeadPreview` (ham değer, ilk dolu sayfa — tam model `activeTab`'da açılabilir). Ortak `OfficeLoadingPreview` (state_views): yazı yalnız `Motion.progressLabelDelay` (1 sn) sonra, saydamlık RENKTE.
- **m.7 kök:** Excel/Slayt `PinchZoomArea` paylaşıyordu, Word'ün özel editöründe çimdik HİÇ yoktu (yalnız şerit düğmesi). Word aynı bileşene alındı; kurucu aynı widget örneğini döner (çimdik karelerinde belge yeniden kurulmaz).
- **KARAR (sabah bakılacak):** çift dokunuşla sığdır eklenmedi — üç editörde çift dokunuş zaten iş görüyor (Word sözcük seçimi, Excel doldurma tutamağı, Slayt şekil düzenleme). Kaydırma fiziği (yaylanma) ölçümsüz değiştirilmedi.
- **Kalan:** m.1 Office/PDF açılış geçişi (H1.4 cihaz ölçümü).
## 2026-11-19 — B2 Akıllı düzen kullanım dilim 1 (yerel, dal faz-oto-B2-duzen-kullanim; yazıldı, cihazda doğrulanmadı)
- **Kök (Ayıkla 2):** `SimilarFinder` grupta "en iyi"yi EN BÜYÜK dosya sayıyordu → bulanık büyük kare ⭐ alıp net kare silmeye öneriliyordu. Artık gruptaki görüntülere Laplace varyansı (128x128 gri, `MediaFingerprint.sharpness`, oturum önbelleği) → `sharpnessTier` (≈%15 kademe, geçişli karşılaştırma) → eşitse eski kural (büyük, yeni). Ölçüm yalnız gruplananlara. Ayıkla AppBar "Benzer kareler" = `SimilarScreen` scope `smart_photos` (photo_people + photo_other).
- **Hassas kilit KARARI (sabah bakılacak):** "uygulama kilidi açıkken görünür" şöyle yorumlandı — PIN kurulu + uygulama kilidi KAPALI ise kimlik/sağlık/banka/vergi içeren Akıllı düzen listesine girişte oturumda bir kez PIN; uygulama kilidi açıksa (girişte soruldu) ya da PIN yoksa sorulmaz. Rozet/tutar listelerinde de kayıt kategorisine bakılır.
- **Düzeltme → tezgâh:** "Kategori yanlış mı?" düzeltmesi tezgâha yalnız kategori etiketiyle girer; tezgâhta zaten olan (elle etiketli) öğe ezilmez.

## 2026-11-19 — B2 Akıllı düzen kullanım dilim 2 (yerel, dal faz-oto-B2-duzen-kullanim; yazıldı, cihazda doğrulanmadı)
- **Kök (bug):** `SmartSort` `PathSideIndex` kancasına bağlı değildi — uygulama içinden taşınan/adı değişen dosya Akıllı düzen kaydını kaybediyor, kategorisinden düşüp bir sonraki düzenlemede yeniden AI'ya (kota) gidiyordu. `SmartSort.movePath` (klasör taşımada alt yollar `movedPathFor`) `main` kancasına eklendi. **Çöpe giden kayıt bilerek eski yolda kalır** (`.dosya-okuyucu-cop` hedefi atlanır): yoksa çöpteki dosya kategoride görünürdü; geri yüklenince kaydı yerinde.
- **Taşıma kuralları:** kategori → klasör `SmartFolderPrefs` (`sm_move_rules`), varsayılan YOK. Klasör menüsü "Taşıma kuralı…" → klasör seç → onay (şimdi n dosya + sonra yeni gelenler) → taşı + tek "Geri al" (`FileOps.undoMove`). Sonraki uygulama yalnız Akıllı düzen ekranında "Şimdi düzenle" sonrası (arka plan otomatik düzenleme TAŞIMAZ — kullanıcının görmediği taşıma yok).
- **Ayıkla:** 30 günden eski ekran görüntüsü `old_shot` nedeniyle önerilir (silinmez).

## 2026-11-19 — U2 Ana ekran tek akıllı şerit (yerel, dal faz-oto-U2-tek-serit; yazıldı, cihazda doğrulanmadı)
- **Karar (kullanıcı: "ikisi akıllı bir şekilde birleşsin … iki satıra çıkmasın"):** 2026-11-18'deki sekmeli "Geçmiş | Yeniler" şeridi (`RecentStrip(onAllNew:)`, `home_recent_tab`; docs/hafiza/2026-11.md "Ana ekran Son açılanlar | Yeni gelenler sekmesi") **yerine geçti** → tek şerit "Son dosyalar"; başlıkta "Yeniler" / "Geçmiş" düğmeleri tam listelere gider. Bölüm kimliği `recent` aynı (görünürlük ayarı zaten tekti).
- **Sıra (`mergeStripItems`, `recent_strip.dart`):** son 24 saatte değişmiş ve o sürümü açılmamış (açılma zamanı < değişme zamanı) yeniler öne, en çok limit−3; gerisi son açılan (açılma zamanı) + eski yeniler (değişme zamanı) zamana göre; yol tekil; en az 3 son açılan hep görünür. "Yeni" etiketi üst köşe, son açılan alt köşede ince saat.
- **Hız kapısı değişti:** eski düzende Geçmiş sekmesinde disk yürüyüşü yoktu; artık yeniler hep gerekli → ilk karede yalnız bellekteki `FreshCache.last`; `warm` (stat) + `scan` (izolat, şeritlerle ortak) ilk kareden sonra; dönüş/dosya işleminde tazelenir. Cihazda A/B ölçülmedi → C2.
- **Göç:** `home_recent_tab` artık okunmuyor, silinmedi (geri alınabilir). Aktar/seçicideki sekmeli `FreshFilesStrip` değişmedi — istek ana ekran içindi.
## 2026-11-19 — U1 Geçmiş'te görsel açılışı donuyordu (yerel, dal faz-oto-U1-gecmis-gorsel; cihazda doğrulanmadı)
- **Kök:** galeri rotası saydam (`imageGalleryRoute` `opaque: false`) → altındaki ekran sahnede kalır. `EntryOpener` geçmiş kaydını açılış geçişi BİTİNCE yapıyordu (`acil-galeri` 2026-11-18); `OpenHistory.changes` → `OpenHistoryScreen._load` (statPaths + tüm listeyi yeniden süz/sırala/kur) galerinin ALTINDA, tam boy çözümün başladığı karelerde koşuyordu. Fotoğraflar ızgarası `changes` dinlemediği için orada yoktu; ana ekran şeridi (`RecentStrip`) de dinliyor → aynı sorun.
- **Düzeltme (tek yer):** galeri dalında kayıt `gallery.completed` (geri dönüş geçişi bitince). Opak oynatıcı/belge rotaları `_afterTransition`'da kalır (alt ekran çizilmiyor). Bekçi: `test/gallery_history_record_test.dart`.
- **Tuzak:** saydam rota altındaki ekranı tetikleyen bildirimler (geçmiş, FsEvents) görüntüleyici açıkken kasma yapar — yeni saydam rota eklerken dinleyicilere bak.
## 2026-11-19 — B11 Slayt 2.0 dilim 1 (yerel, dal faz-oto-B11-slayt2; yazıldı, cihazda doğrulanmadı)
- **m.1 kök neden:** çizici (`pptx_render` `_table`) yalnız hücrenin açık `a:tcPr` dolgusunu okuyordu; PowerPoint'te stil verilmiş tablolar (görünüm `a:tableStyleId` + `ppt/tableStyles.xml`) renksiz çıkıyordu. Artık stil bölgeleri (wholeTbl → bant → kenar sütun → son/ilk satır) dolgu + yazı rengi + kalınlık verir; açık hücre biçimi üstün; varsayılan GUID `{5C22544A…}` tanımsızsa yerleşik Orta Stil 2 yaklaşığı. Stil kenarlıkları (`a:tcBdr`) ve `fillRef` okunmuyor.
- **m.1 altın görüntü:** piksel altın PNG yerel test yasağıyla üretilemiyor (CI'da `--update-goldens` yok) → sadakat yapısal (model) testleriyle korunuyor; piksel altın gerekirse kullanıcı izniyle yerelde üretilecek.
- **m.4:** düzenleme açılınca imleç dokunulan yerde (`SlideCanvas.onEditShape(shape, at)` → `SlideBoxEditor.tapAt`); eskiden hep sondaydı. Klavye açılınca kayma için ek kod YOK — `showOnScreen` iç içe kaydırıcılarda çalışmalı (hipotez, cihazda bak).
- **m.7:** `test/slides_roundtrip_test.dart` — opak parçalar bayt bayt korunuyordu (kanıt arandı, kayıp yok); bekçi olarak kaldı.
- **m.2 bağımlılık:** slayt grafik türleri B10 m.1 ortak çizicisini bekler (aynı kod; çakışma olmasın diye önce B10).
## 2026-11-19 — B11 Slayt 2.0 dilim 2 (yerel, dal faz-oto-B11-slayt2; yazıldı, cihazda doğrulanmadı)
- **m.6:** not yazma (`slides/outline.dart`) ve sunucu görünümünde büyük not (`slideshow/presenter.dart`) zaten vardı; eksik olan anlatımsız prova → `SlideshowScreen(rehearse:)` (advTm ilerletmez, slayt başı süre toplanır, geri tuşuyla süreler döner) + `PptxMediaOps.setTimings` (advTm, 500 ms taban; anlatımla aynı `_writeAdvance`). < 500 ms geçilen slayt zamanlanmaz.
- **m.8 kök neden:** `SlideCanvas` tüm şekiller tek Stack'te; sürüklenen `SlideFrameEditor`'ün Positioned'ı her karede değişince Stack yeniden boyanıyor, seçili olmayan şekiller de yeniden çiziliyordu. Seçim varken seçilenin altı/üstü iki `RepaintBoundary` katmanı (z sırası korunur). Bekçi: `slides_perf_test` `debugOnProfilePaint` ile boyanan metin sayımı + rebuild tavanı 130 (CI 107); `slideshow_test` geçiş karesinde `SlideCanvas` kurulmaz (geçiş zaten `AnimatedBuilder child` önbellekli). Bedel: seçim aç/kapa ağaç şeklini değiştirir (şekiller bir kez yeniden bağlanır).
- **m.5 (AI tasarımcı) yapılmadı** — dilim 3'e.
## 2026-11-19 — B2 dilim 3 (yerel, dal faz-oto-B2-duzen-kullanim; yazıldı, cihazda doğrulanmadı)
- **Kontrol listeleri:** `Checklists` (`services/fm/checklists.dart`): hazır 5 liste (vize, kira, reçete, epikriz, iş başvurusu; maddeler çeviri tablosunda `|` ile) + kullanıcı listeleri `ckl_lists`. Dosya başına TEK Decisions isteği (bütün maddeler ayrı `noul` sorusu, tavan 20), madde sonucu = dosyalar arası en yüksek P(evet) ≥ 0,5. Klasörde yalnız doğrudan içindeki dosyalar (özyineleme yok, en çok 60). PDF rapor `ConversionService.textToPdf` (Carlito — Helvetica Türkçe harfi bozar), raporda yol değil yalnız ad (KVKK).
- **WhatsApp iletilen kopyaları:** WhatsApp klasöründe aynı BAYT boyutlu görseller = kopya sezgisi, en eskisi kalır (`SmartSort.waCopiesOf`, `reasonOf` → `wa_copy`). Kayıt alanı değil, `revision`'a bağlı önbellek. Yanlış eşleşme görülürse grupta içerik özeti karşılaştır.
- **AI en iyi kare:** Benzer karelerde grup başına ⭐ → önizlemelere Decisions `score` (netlik/gözler açık/kadraj), `SimilarFinder.orderByAi` (puanlı başa, eşitte yerel netlik sırası). Sonuç iş kuyruğundaki grubu yeniden sıralar (silme yok).
- **Decisions boş imza alanı:** belge hazır sorularına `sign_empty` — toplu kontrol "Yalnız Evet" ile imzasızlar.
## 2026-11-19 — B2 dilim 4 (yerel, dal faz-oto-B2-duzen-kullanim; yazıldı, cihazda doğrulanmadı; haftalık limit %91 → yarıda)
- **Tarama AI kalite:** `ScanAiQuality` (3 noul: okunaklı/parlama/kesik, eşik 0.6, öncelik parlama>kesik>okunaksız) — yerel ölçüm parlama/kesik kenarı göremiyordu. Yalnız kullanıcı ⋮'dan başlatır (gizlilik+kota).
- **Akıllı temizlik AI doğrulaması:** yalnız greeting/blurry kovası; en çok 20 görsel, AI P<0.3 → kovadan düşer (silme yok).
- **Galeri kategori süzgeci ZATEN VARDI:** Fotoğraflar `FmQuickFilters` AI kategori hapı (2026-11-18). Eksik: hassas kategori (kimlik/sağlık/banka/vergi) seçiminde PIN — yapılmadı.
- **Sohbet yönlendirici (yapılmadı):** sohbet zinciri zaten flash-lite önce (`ai_tasks.dart`); kazanç = basit soruda Gemma'yı (günde 14.400) öne almak; Decisions çağrısı yalnız katalogda Gemma varsa + zaman aşımı ~1,5 sn.
## 2026-11-19 — B2 dilim 5 (son; dal faz-oto-B2-duzen-kullanim; yazıldı, cihazda doğrulanmadı)
- **Hassas kategori PIN'i tek yerde:** `unlockSensitiveCats` (`widgets/fm/pin_dialog.dart`, oturum bayrağı) — Akıllı düzen listeleri + Fotoğraflar AI kategori levhası (`showSmartCatSheet`, yalnız SEÇERKEN) paylaşır; PIN yoksa / uygulama kilidi açıksa sorulmaz.
- **Sohbet yönlendirici ertelendi → PLAN B14:** her mesaja ek Decisions isteği + ≤1,5 sn gecikme; yanıt kalitesi A/B'siz değiştirilmez. B2 satırı silindi, A/B C2'de.
## 2026-11-19 — İkinci ad/kategori menüsü + toplu AI ikinci ad + arka plan Akıllı düzen (kullanıcı isteği; yazıldı, cihazda doğrulanmadı)
- **Menü:** ⋮ ve çoklu seçim "Daha fazla"da EN ÜSTTE "İkinci ad ve kategori" bölümü (AI ile ikinci ad · İkinci ad ver · Kategori ekle · Kategori yanlış mı?). Seçimdeki ve ⋮'daki eski "AI ile etiketle" (`showAiTagFlow`) KALDIRILDI — yeni model (Decisions, `SmartSort.classifyOne`) adı + kategoriyi (etiket olarak da) veriyor. Kategori araçları ekranındaki AI etiketleme duruyor.
- **Toplu AI ikinci ad:** `giveAiAliasBatch` (`ai_actions.dart`) — TrackedTask (eşik 0 → bildirim/şerit, Durdur), 2 paralel, en çok 300, kapsam dışı/klasör atlanır, 401/403/429'da durur. SmartQuota'yı (günlük sınır) TÜKETMEZ (kullanıcı başlattı, tekli de tüketmiyordu).
- **Kategori ekle** (`category_add_sheet.dart`): tek kaynak Akıllı düzen — yerleşik kategori → `SmartSort.correct` (elle düzeltilmiş); kullanıcı kategorisi → `SmartSort.addToUserCat` (`uc` değeri `manualMark`=101, olasılık aralığı dışı; `withUserAnswers` ve `_keepManual` AI turunda korur). "Yeni kategori" yalnız ad ister (about=ad, deneme yok). Kaydı olmayan dosyaya `modifiedMs: -1` "diğer" kaydı → `needs` true, AI yine sorar. Kategori adı FileTags etiketi de olur (AI ikinci ad gibi); tek dosyada seçili kullanıcı kategorisine dokunmak çıkarır.
- **Arka plan düzen:** ayar `smart_sort_bg` ("Yalnız şarjda ve Wi-Fi'de (arka planda da)", varsayılan KAPALI). Açıkken uygulama içi otomatik tur da şarj + ölçülü olmayan ağ bekler (`chargingOnWifi`). Yerel `SmartBgJob` (`ci/Extras.kt`, JobScheduler 0x5E02, 3 sa periyot, şarj + UNMETERED, persisted) ayrı FlutterEngine'de `smart_sort_bg.dart › akilliDuzenArkaPlan` koşar (Aktar kalıbı); motorun `dosya/extras` kanalında yalnız isMetered/isCharging/unwrapKey/smartBgDone var. Anahtar+kapsam `AppState.loadAiForBackground` (kalıcı AI rızası yoksa / çevrimdışıysa null → tur yok). Uygulama ekrandaysa iş koşmaz.
- **Tuzak — iki izolat aynı depo:** arka plan `smart_sort.json` yazar; uygulama dönüşte `SmartSort.reloadIfChanged` (dosya mtime ≠ son okuma/yazma) ile yeniden okur, yoksa bellek kopyası arka plan sonucunu ezerdi. SmartQuota sayacı prefs önbelleği yüzünden izolatlar arası kayabilir (günlük sınır biraz aşılabilir) — kabul edildi.
## 2026-11-19 — B4 PDF Pro dilim 1 (dal faz-oto-B4-pdfpro; yazıldı, cihazda doğrulanmadı)
- **Önce bak sonucu:** P21'in parola koy/kaldır (`PdfTools.setPassword/removePassword`), izinler (AES-256), PDF/A (a2b), sert sıkıştırma; P20 sıralama/boş sayfa/kırp; P18 form oluşturma + otomatik doldurma profili ZATEN VARDI. Eksik çıkan: meta veri ve XFDF.
- **Meta veri:** `PdfDocPro.readMeta/writeMeta` (Syncfusion `documentInformation`; parolalı belge parolasıyla açılıp aynı güvenlikle kaydedilir). XMP akışı güncellenmiyor (yalnız Info sözlüğü) — PDF/A belgede uyuşmazlık olabilir, gerekirse XMP'yi de yaz.
- **XFDF:** Syncfusion `exportAnnotation/importAnnotation(xfdf)`; içe aktarma ekler, var olanı silmez. Pro araçlar levhası: `meta`, `xfdf_out`, `xfdf_in`.
## 2026-11-19 — Kullanıcı kararı: Akıllı bütünlük + AI budama (B15)
- **Karar:** ürünün öne çıkan yüzü yeni model (Akıllı kategori/ikinci ad/Akıllı düzen). Adlandırma her yerde "Akıllı …" ("AI …"/"Gemini …" değil); menü, ekran, işlev ve his bütünlüğü zorunlu.
- **Budanan (kullanıcı seçti):** AI ile özetle, AI Sohbet, Slayt AI ile hazırla, "AI ile çalış" menüsü, Benzerlerde Gemini/en iyi kare, eski AI etiketle. **Öneriyle budanan (sabah bakılacak):** AI hızlı/toplu kontrol, kontrol listesi. **Kalan:** PDF AI düzenle, Word AI yaz, görsel kısa özet, tarama kalite, Arapça OCR.
- **Sonuç:** B14 (sohbet yönlendirici) iptal — sohbet kalkıyor; dal faz-oto-B14-yonlendirici silindi.

## 2026-11-19 — B4 dilim 2: AES-256 R6 kilit açma (dal faz-oto-B4-pdfpro)
- **Bug kökü:** Syncfusion R6 (qpdf/Word) belgede `removePassword` sayfasız çıktı veriyordu (tezgâh 2026-11-08). Çözüm: `PdfTools.removePasswordInBackground` Syncfusion çıktısının sayfa sayısını girdiyle karşılaştırır; eksik/hata → `removePasswordPdfium` (pdfrx `encodePdf(removeSecurity: true)`, ana izlekte; pdfrx kendi işçisinde). PDFium `Isolate.run` içinde ÇAĞRILMAZ (başlatma belirsiz).
- **Karar:** parola/izin koruması `aesx256BitRevision6` (R6, PDF 2.0); R5 (`aesx256Bit`) Adobe'ce kullanımdan kalktı. Test `test/pdf_pro/pdf_unlock_r6_test.dart`.

## 2026-11-19 — B4 dilim 3: P20 sayfa stüdyosu (dal faz-oto-B4-pdfpro)
- **Karar:** `PdfReorderScreen` (liste) silindi → `lib/screens/pdf_tools/page_studio.dart` ızgara (Pro araçlar "reorder" kimliği aynı). Plan = (özgün indeks, çeyrek tur) listesi → `PdfTools.applyPageStudio`.
- **Tuzak/karar:** sıra kesin artansa (yalnız sil/döndür) belge YERİNDE değişir → açıklamalar korunur; sıralama/çoğaltma `selectPages` kopyası → açıklama kaybı uyarısı yalnız o zaman (`studioKeepsAnnotations`).
- Sürükle-bırak `LongPressDraggable`+`DragTarget` (Flutter'da yeniden sıralanır ızgara yok, paket eklenmedi); kenarda kendiliğinden kaydırma yok. Cihazda ölçülmedi (C2).
## 2026-11-19 — B15 dilim 1: AI budama + "Akıllı" adlandırma (dal faz-oto-B15-akilli)
- **Budanan kod:** AI Sohbet (`chat_screen.dart`, AI merkezi Sohbet sekmesi, `AiAsk.ask`), AI ile özetle (`ai_summary_flow.dart`, `showAiSummary`; eski özet iş kaydına dokununca dosya açılır), Slayt AI kipi (`ai_slides.dart`; `slides_flow.dart` yalnız sezgi yolu), alt çubuk "AI ile çalış" (görüntüleyici + 3 editör), Benzerlerde Gemini/en iyi kare (`compareImages`, `orderByAi`), `AiTagger`/`ai_tag_flow` (kategori araçlarında yerine toplu Akıllı ikinci ad), hızlı/toplu kontrol + kontrol listesi. `quickCheckInput` `ai_actions.dart`'a taşındı (ikinci ad kullanıyor). Kullanıcı verisi (ai_index, `AiSummaryStore` özetleri, hafıza notları) silinmedi; 193 ölü çeviri anahtarı silindi.
- **Adlandırma kuralı:** görünen "AI …" → "Akıllı …" (en "Smart …", ar "ذكي"); "Akıllı düzen" tek yazım (en "Smart organize"); AI girişlerinin simgesi `AppIcons.ai` (organize/ocr değil); akıllı hata kalıbı `common.smart_failed` ("Akıllı işlem yapılamadı: {error}"). Ayarlar/gizlilik/onay metinlerinde "Yapay zekâ"/"Gemini API anahtarı" kalır.
- **Tuzak:** silinen anahtarlar HEAD ile karşılaştırılarak seçildi (yalnız bu işle yetim kalanlar + aynı öneklerin eski yetimleri); dinamik anahtar (`'qc.t_${…}'`) kalıbı tarayıcıda önek sayıldı.
- **Sabah bakılacak:** Ayarlar'daki "AI Kalıcı Hafıza" yalnız sohbette kullanılıyordu — artık etkisiz (notlar duruyor); seçili metinde "Akıllı sor" (QuickAiSheet) envanterde yoktu, kaldı.

## 2026-11-20 — U4 Akıllı klasörler + Analiz + Yapay zekâ ayarları (yerel, dal faz-oto-U4-akilli-klasor; yazıldı, cihazda doğrulanmadı)
- **Beyin fırtınası (17 aday → 7 seçildi; ölçüt: önce bug, sonra kullanıcıya doğrudan görünen düşük maliyet/risk):** seçilmeyenler PLAN U4 satırında (a)–(j). Yeni yerleşik kategori (d) BİLEREK yok: Decisions `cat` seçeneğine ekleme kalibrasyonu ve tezgâh karşılaştırmasını bozar — önce C2 doğruluk ölçümü.
- **Kök (bug):** `SmartSort.run` 401/403'te de "günlük kota doldu" diyordu (ekran her `stoppedBy`'ı kota sayıyordu); anahtar yok/çevrimdışı kip/kapsam boşken sessiz `(0,0)` → "yeni dosya yok". `SmartHold` + `offline/noKey/noScope`; durma metni `SmartSort.stopText` (= `UserError`: ne oldu + ne yapmalı) — tur, Kategorilerim denemesi ve geriye dönük uygulama ORTAK. `stoppedBy` artık kullanıcı metni (ham API iletisi değil).
- **Kök (bug, hayalet kayıt):** başka uygulamada silinen / çöpü boşaltılan dosyanın kaydı kalıyordu → klasör sayıları şişik. `SmartSort.pruneMissing` (Akıllı düzen ekranı açılınca): çöpteki asıl yol ve takılı olmayan birimdeki kayıt KALIR, çöp okunamazsa hiçbir şey silinmez (B2 dilim 2 "çöpe giden eski yolda" kararı korunur).
- **Kök (bug):** kayıtlı aramalar (`SmartFolders`) yalnız eski `AiIndex`'e bakıyordu → Akıllı düzen kullananda boş. Artık `SmartSort.matches` de girer; gizlenen (Ayıkla) elemesi `matches`'in İÇİNDE (tek kapı). Hassas kategorili arama açılışta `unlockSensitiveCats`, satır küçük resminde gösterilmez.
- **KARAR (sabah bakılacak, yalnız metin, geri alınabilir):** "Akıllı klasörler" iki ayrı şeyin adıydı (Akıllı düzenin kategori ızgarası + kayıtlı aramalar) → kayıtlı aramalar **"Akıllı aramalar"**; Akıllı düzen ekranında ızgaranın altında kartı var. "Akıllı klasörler" = kategori ızgarası.
- **Kategorizasyon (B15 m.4):** `other` kayıtları ızgarada yoktu → "Diğer" klasörü (varsayılan en sonda); kullanıcı bulup "Kategori yanlış mı?" ile öğretir. Şema/talimat DEĞİŞMEDİ (tezgâh uyumlu).
- **Yapay zekâ ayar sayfası (kullanıcı):** sıra Akıllı klasörler (durum satırı → Akıllı düzen; `SmartSortSettings` = ekrandaki AYNI denetim, kendi dinler, const kurulur; hassas klasör PIN durumu; Kategorilerim) → Erişim → Buluta ne gidiyor (`ai_send_ask`, `ai_pii_mask` Gizlilik'ten TAŞINDI — kimlikler aynı) → Analiz kapsamı → Gelişmiş. `MemoryTile` + `settings.memory*` silindi, AppState not verisi duruyor (test: 'memory' bilinçli kalktı).
- **Kök (bug, Analiz):** 200 satır sınırı yalnız çizimdeydi; "Tümünü seç"/sayaç `_visible`ın tamamını (aramada 1000'e dek) görüyordu → görünmeyen dosya seçilip silinebiliyordu. Sınır `_visible`da. "Yinelenen dosyaları bul" → "Kopyalar" (ana ekran aracıyla aynı ad + `AppIcons.filterNone`; U3 ana ekrandan kaldıracak). Akıllı düzen açık + gereksiz varsa araçlarda "Ayıkla · n" (Analiz `SmartSort` yüklemesi TETİKLEMEZ — main yükler; sayı bir kez).
- **Tuzak:** `SmartSortSettings` gibi durağan depodan okuyan bir parçayı `const` kurup dinleyiciyi DIŞARIDA bırakırsan const örnek hiç yeniden kurulmaz (değerler donar) — dinleyici parçanın içinde olmalı.
## 2026-11-20 — G1 Kök: eski fotoğrafı açınca ~700 ms donma (dal faz-oto-G1-galeri-kasma; tablette ölçüldü)
- **Kök:** galeri alt şeridi (`_FilmStrip`, `image_gallery/widgets.dart`) `ListView.separated` idi; açılışta seçili fotoğrafa `jumpTo` yaparken boyu bilinmeyen liste 0'dan o indekse kadar BÜTÜN öğe + ayraçları kurup ölçüyordu (5.321 görselde en eski fotoğraf: ~16 bin BUILD, tek kare 679–712 ms). Yeni fotoğrafta indeks küçük → sorun yok ("eski fotoğraflarda" bulgusu buydu). Önceki galeri düzeltmeleri (geçmiş kaydı, önizleme bildirimi, tam boy erteleme) bunu göremezdi.
- **Düzeltme:** `ListView.builder(itemExtent: _item + _gap)`, boşluk öğe içinde (görünüm aynı). A/B (MatePad DBY-W09, `.r8test`): açılış karesi 679–712 → ≤ 33 ms. Bekçi `test/gallery_film_strip_extent_test.dart`.
- **Tuzak:** uzak indekse atlanan (`jumpTo`/`initialScrollOffset`) uzun listede `itemExtent`/`prototypeItem`/`SliverVariedExtentList` şart; `ListView.separated` ve boyu serbest `ListView.builder` atlamada O(n) kurar.
- **Ölçüm yöntemi (kare içi kanıt):** profil derlemesinde VM servisi açık (`The Dart VM service is listening` logcat) → `adb forward` + websocket `getVMTimeline`; tek karedeki `BUILD` sayısı tembel liste patlamasını gösterir. `getCpuSamples` profil derlemesinde kapalı ("Feature is disabled"). Zaman çizelgesi halkası ~2–6 sn: `clearVMTimeline`'ı olaydan hemen önce çağır.
- **Kalan:** ilk savurmada tek 110–135 ms kare (A ve B aynı) → PLAN G1b.

## 2026-11-20 — U3 Ana ekran + bildirim bütünlüğü (yerel, dal faz-oto-U3-ana-ekran; yazıldı, cihazda doğrulanmadı)
- **Kök (m.8, Başarım seçimi görünmüyordu):** `SettingTile` `trailing` (açılır menü düğmesi) verilince `value`yu HİÇ çizmiyordu → Başarım, Çöp otomatik temizle, varsayılan sıralama, medya açılışı. Düzeltme tek yerde (değer menünün solunda, ana renkte) + menülerde `CheckedPopupMenuItem` + `initialValue`.
- **m.6:** araçlardan Kopyalar (Bellek Analizi'nde, U4) ve Bağlantıdan indir kalktı (ekran duruyor: paylaşılan bağlantı + Yakındaki cihazlar açar). Araçlar 5 + Harici bellek.
- **m.5:** pano altındaki iki düğme → tek "Düzenle" (`dash-edit`, menü: Ana ekranı düzenle · Alt paneli düzenle).
- **m.2:** ortak hız levhası `lib/widgets/fm/speed_sheet.dart` (`PlaybackSpeed`: 0,5–2,0, 0,05 adım, bırakınca uygulanır; hızlı düğmeler altta). Aralık "en güvenli" (iki motor); genişletmek cihazda ses denemesi ister.
- **m.4/m.11 (karar):** Akıllı düzen sonucu ayrı `SmartBatchStrip` değil `SmartInbox` olayı (`InboxEvent.onDismiss`); bildirim/tost tek dil = `SmartInbox` satırı + `snack.dart` kartı. Doğrudan `ScaffoldMessenger.showSnackBar` (3 yer) ortak kartı atlıyordu → `showSnackBarReplacing`. **Kök (sessiz başarı):** çöp kapalıyken kalıcı silme başarıda hiçbir şey demiyordu, hata sabit Türkçeydi → `fm.deleted_n`/`fm.deleted_partial`.
- **m.3 (yeni kullanıcı isteği U2'yi günceller):** U2'nin "24 saatin yenileri öne" sırası kalktı → yeniler (değişme) + Geçmiş (açılma) tek zaman çizgisi, her türden en az 3 ayrılır (`mergeStripItems`). Başlıkta sekmeler geri geldi: "Son dosyalar" (karışık) · Geçmiş · Yeniler (U2'nin "iki satıra çıkmasın"ı korunur: tek satır şerit, sekme yalnız başlıkta); › sekmenin tam listesi. Varsayılan sekme `StripPrefs` (`home_strip_mode`, Ana ekranı düzenle › Bölümler). Yan menü `_RecentMini` silindi → aynı `RecentStrip(dense, scan: false)`.
- **Yükleme yolu (ölçülmedi, C2):** Geçmiş sonucu oturum içi bellekte (`_memOpened`, ilk karede hazır, ardından `stat` doğrular); Geçmiş sekmesinde yeniler taraması hiç başlamaz; yan menü tam tarama başlatmaz (FreshCache "sürerken bir tur daha" kuralı yan menü açılışında ikinci tarama yaptırırdı).

## 2026-11-20 — B4 PDF Pro dilim 4 (dal faz-oto-B4-pdfpro)
- **P20 stüdyo planı = sanal indeks:** önce bu belgenin sayfaları, sonra `extra` belgeleri sırayla; `PdfTools.studioBlank` (-1) = boş sayfa. `applyPageStudio(extra:)` ek belgeyi `_compose` ile alır (selectPages tek kaynaklı); `studioKeepsAnnotations(order, pageCount:)` ek belge sayfası görünce yerinde yolu kapatır — `pageCount` verilmezse ek sayfa "artan" sayılıp yanlışlıkla yerinde yola girerdi.
- **Önce bak bulgusu:** PDF_PRO Faz 63 m.2 (kırpma `crop`, boyut `fit_a4`), m.3 (sayfa no + Bates `numbering`, filigran `stamp`), m.4 (yer imi ekle/yeniden adlandır/sürükle/iç içe — `_OutlineEditor`) Pro araçlarda ZATEN var; P20'de kalan yalnız stüdyo içi böl/çıkar ve görselden/taramadan ekle.

## 2026-11-20 — B4 PDF Pro dilim 5 (dal faz-oto-B4-pdfpro)
- **P20 çıkar/böl = `PdfStudioResult.newFiles`:** boş değilse her parça `applyPageStudio` ile ayrı dosya (`_saveSibling`, `-sayfalar` / `-bolumN`), belge DEĞİŞMEZ; böl kuralı `PdfTools.studioSplit` (seçili konumdan önce kes, yalnız boş sayfalı parça atılır).
- **Görselden/taramadan ekle:** görüntüler önce `ConversionService.imagesToPdf(A4)` ile PDF'e, sonra dosyadan ekleme yoluyla `extra` (tek ekleme yolu `_insertPdf`). Tarama "tara ve ekle" kuralıyla (kendiliğinden kırpma yok).
- **Kenar kaydırma:** `LongPressDraggable.onDragUpdate` → ızgaranın üst/alt 56 px bandında `Timer.periodic` (kare başı 14 px `jumpTo`), `onDragEnd`'de durur. Süre `Duration(microseconds:)` — zamanlayıcı, tasarım tokenı değil (bekçi `milliseconds` sayar).

