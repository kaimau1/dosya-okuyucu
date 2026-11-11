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


## 2026-11-04 — WhatsApp klonları + dosya menüsü 2. hızlı sıra
- **Kök neden (galeride aynı fotoğraftan 3 tane):** ad+boyut anahtarı (2026-07-29) iki durumu
  kaçırıyordu: (1) aynı foto iki sohbete gidince `IMG-…-WA0003/WA0004` bayt bayt aynı ama ad
  farklı; (2) `WhatsApp Images/Sent/` kopyası yeniden sıkıştırılmış → ad da boyut da farklı.
  Çözüm: `duplicateKey` WA sayacını yok sayar; galeri `isWhatsAppSentCopy` olanları da gizler
  ("Gönderdiklerim" seçiliyken hariç). "Temizle": bayt bayt gruplar + Sent kopyaları **algısal**
  (`SimilarFinder` sıkı eşik) eşleşirse silinir — aday asıllar yalnız bir Sent'ten ≤7 gün önceki
  görseller; ASIL asla silinmez. Cihazda doğrulanmadı.
- Dosya menüsü: ikinci hızlı sıra = Hızlı paylaş (doğrudan `NearbyScreen`) · Önemli işaretle
  (`fm.copy_to_important` adı değişti) · Sil (danger tonu). Alttaki tam genişlik Sil kaldırıldı.

## 2026-11-04 — Menüler tek kaynak, alt çubuk 2 satır, "masa ve kâğıt" teması
- **Menüler:** seçimde tek öğe varken "Daha fazla" artık ⋮ menüsünün AYNISI (`showEntryActions`,
  `FmSelectionBar.allowReveal/onReveal` ekranın ⋮ çağrısıyla aynı verilir). ⋮ menüsüne "AI ile
  etiketle" eklendi. Seçim çubuğuna Hızlı paylaş (`quickShareEntries`). Çoklu seçimde eski levha kalır.
- **Alt alan:** yüzen kapsül (çöp · aktar | tara) KALDIRILDI → `HomeQuickRow` (Çöp · Aktar · Drive ·
  Tara, 44 dp) gezinme çubuğunun üstünde, aynı yüzeyde (`surfaceContainer`), yalnız pano sekmesinde;
  gezinme çubuğu o sekmede 62 dp. Çöp rozeti `DashboardScreen.trashCount` (ValueNotifier).
  Drive kutusu varsayılan gizli + mevcut kurulumda bir kez gizlenir (`dash_drive_moved_v1`).
- **Üst satır:** "Dosyalar" başlığı kalktı; arama kutusu AppBar başlığında, AI · yenile · ayarlar yanında.
- **Tema (Notlar TEMA_PLANI K1–K2 aynısı):** `AppSkin` paper/ivory/light → **sage (varsayılan) /
  porcelain / clay**; eski adlar `byName` ile eşlenir (ivory→sage, light→porcelain, paper→clay,
  kayıt yeniden yazılmaz). Açık temada kart zeminden AÇIK. Word/PDF kâğıt sayfa çerçevesi artık Kil
  ailesinde. Açılış zemini `#EAF0EB`. `Paper` sabitleri (belge kanvası vb.) bilerek değişmedi.
  Cihazda doğrulanmadı.

## 2026-11-04 — Alt alan görsel düzeltmesi + hızlı sıra gecikmesi
- Gezinme çubuğu panoda 62 dp'de seçili etiketi kırpıyordu → 68 dp + yazı ölçeği ≤1.1 kıskacı.
  Hızlı sıranın üstüne ince `outlineVariant` çizgisi (içerik "kesik" görünmesin), çubukla aynı
  `surfaceContainer`. Çöp rozeti simgenin soluna (etiketin üstüne biniyordu).
- Gecikme: hızlı sıra öğelerindeki `Tooltip` (dokunmatikte uzun basma tanıyıcısı) kaldırıldı,
  yerine `Semantics`; dalga `InkSplash` (anında). Kök neden kesin değil — cihazda doğrulanmadı.
- **2. tasarım (aynı gün, kullanıcı: "ayrı duruyor, baştan tasarla, görsel birlik"):** `BottomDock`
  (home_quick_row.dart) = hızlı sıra + gezinme TEK yüzey, üst köşeler yuvarlak + yumuşak gölge,
  her sekmede. NavigationBar şeffaf/elevation 0, 64 dp, yazı ölçeği 1.0 kıskaç. Çöp·Aktar·Drive
  tek bölmeli grup (ince ayırıcılar), Tara sağda tek vurgu; çöp sayısı etiket yanında küçük hap.
  Tuzak: tek kenarlı `Border(top:)` + `borderRadius` Flutter'da assert → gölge kullanıldı.

## 2026-11-04 — Tasarım turu: İşlemler sekmeli, tek araç satırı, arama kapsülü, yeni simgeler, alt panel, Kitaplık
- **Araçlar TEK satır** (`DashboardTools.row`, 4): Aktar araçlardan kalktı (alt panelde); Yer aç ·
  Sohbet medyası · Düzenle → **`OperationsScreen`** (screens/fm/operations_screen.dart) sekmeleri:
  İşlemler | Yer aç | Sohbet medyası | Düzenle. Sekme ilk seçilince kurulur, `IndexedStack`'te
  kalır (kaydırarak geçiş YOK — kartlar yatay hareket taşıyor). Ekranlara `embedded` bayrağı:
  kendi AppBar'ı yerine `EmbeddedToolbar` (ince eylem satırı). `openJobsScreen` + İşlemler kutusu +
  akıllı bildirim "Tümü" + kart "Yer aç" düğmesi artık bu merkeze gider. Geçmiş ekranı (4 bölüm) aynen.
- **JobsScreen:** süren işler tam kart, **biten işler 2 sütun ızgara** (`_FinishedGrid`,
  `IntrinsicHeight` satırlar — sabit yükseklik yok, 2× yazıda taşmasın). Test metinleri korunuyor.
- **Arama kapsülü:** AppBar'da tek kapsül (gölgeli), AI · yenile · ayarlar içinde; "Anlamla" artık
  AÇ/KAPA anahtarı (`dash_meaning_search_v1`), ipucu duruma göre (`srch.hint_ai`). AI rozeti nokta.
- **Simgeler:** `FmSquircleIcon` (widgets/fm/fm_tile_art.dart) — squircle zemin + gölge; Fotoğraflar,
  Videolar, Arşivler, Ses, Belgeler, İndirilenler kendi 2.5D çizimi (`FmTileData.art`). Çizgi
  ailesinde eski glif. Görünmez `Icon` ağaçta kalır (`find.byIcon`).
- **Alt panel:** `[sol ek] Çöp · Drive (Aktar) Tara [sağ ek]`, 52 dp; ek düğmeler `DockExtras`
  (prefs `dock_extra_left_v1/right_v1`), panele basılı tut ya da panodaki "Alt paneli düzenle".
- **Kitaplık:** okuma durumu süzgeci (Okunuyor/Başlanmadı/Bitti), istatistik satırı, raf/liste
  görünümü, "Telefondaki kitapları bul" (pano taramasından, ayrı disk taraması yok), bulunamayanları
  kaldır, kitap menüsüne Klasöründe göster + Paylaş.
- Tuzak: tasarım tokenı bekçisi (`design_tokens_test`) yeni dosyada `Color(0x`, `fontSize:`,
  `Duration(milliseconds:`, `showModalBottomSheet` tavanı 0 → `AppHues`, `context.type`, `Motion`,
  `showAppSheet` kullan. Cihazda doğrulanmadı.

## 2026-11-04 — Pano cilası 2 + Geliştirme planı (Faz 34–42)
- **Alt gezinme çubuğu (NavigationBar) KALDIRILDI** (kullanıcı: "en alt satırı kaldır dediydim"):
  `home_screen.dart` yalnız pano'da `BottomDock([HomeQuickRow])` çizer; öteki sekmelere (Yeni
  Dosyalar, Geçmiş…) panodaki kutular/ek düğmelerle gidilir. `NavTabs` altyapısı duruyor (temizlik Faz 34).
- **Hızlı sıra simetrik:** Aktar ortada, iki yanda eşit yuva (eksik yana `Spacer`); sağ ek düğme
  varsayılanı `free_space` (pref yoksa); "yok" seçimi artık `''` saklanır (null = hiç seçilmedi).
  Dock'a `SafeArea(top:false)` (gezinme çubuğu kalkınca sistem çubuğu payı).
- **Simgeler sadeleşti:** parlama kalktı, gölge alpha 0.24→0.09, zemin daha açık/düz, nesne
  gradyanı yumuşak. Araç başlığı üst boşluğu Gap.lg→sm, çerçeve dikey boşluk azaldı, kutu oranı 0.94.
- **Plan:** `docs/GELISTIRME_PLANI.md` (Faz 34–42), `KALANLAR.md` Faz C. Tarayıcı önerisi: ML Kit
  `GmsDocumentScanner` doğrudan (PDF+JPEG, canlı kenar, otomatik çekim) — kullanıcı onayı bekler.
- Cihazda/CI'da doğrulanmadı (yerel test yok, CLAUDE.md §4).
- **Plan genişletildi (aynı gün, kullanıcı: "performans düzeltmelerini bozma"):** `GELISTIRME_PLANI.md`
  başına 10 maddelik PERFORMANS KORUMA ANAYASASI (izolat, tembel yükleme, PerfBudget, boşta 0 kare,
  APK bütçesi, faz sonu A/B tablosu, özellik bayrağı, büyük dosya tavanı) + her faza ek maddeler.
- **KARAR 2026-11-04:** belge tarayıcı ML Kit `GmsDocumentScanner`a doğrudan geçecek (Faz 35 adım 0, bayrak `scan_engine_v2`, yedek akış korunur); kullanıcı başlatacak.

## 2026-11-04 — Faz 34 bitti (faz-34 dalı)
- Ölü alt çubuk ayarı kaldırıldı: ayarlar `nav_tabs` satırı, `NavTabsTile`, "Ana ekranı düzenle" içindeki giriş. `NavTabs`/`nav_tabs_sheet` dosyaları duruyor (home_screen sekme durumu, nav_tabs_test).
- Perf A/B: bekliyor (ölçüm yok). Cihazda 360×800 dp + 2× yazı ölçeği doğrulaması bekliyor.

- **Tuzak (Faz 34):** build-apk.yml push tetikleyicisinde `faz-*` yoktu → faz PR'ları hiç CI almıyordu; `faz-*` eklendi (verify her dalda koşar, apk/release main+etiket kapılı).

## 2026-11-05 — Faz 35 adım 0 (faz-35 dalı)
- `cunning_document_scanner` pubspec/lock'tan çıktı; yerine `ci/DocScan.kt` (ML Kit `GmsDocumentScanner`, `play-services-mlkit-document-scanner:16.0.0`, kanal `dosya/docscan`, istek kodu 7351, sonuç `MainActivity.onActivityResult` → `DocScan.handleResult`). Dart: `DocumentScanner.scanPages` önce köprü; `unavailable`/MissingPlugin ya da `scan_engine_v2=false` → `importFromGallery` (FilePicker görsel). `permission_handler` ^13 engeli kalktı (yükseltme ayrı iş, A3.4b).
- Cihazda/CI'da doğrulanmadı; Perf A/B: bekliyor. Kalan: Faz 35 madde 1–9 (kipler, ızgara, akıllı çıktı…) sonraki oturumlarda.

## 2026-11-05 — Faz 35 bitti (faz-35 dalı; kod — cihaz turu + perf A/B bekliyor)
- **Kipler** `lib/services/scan_kind.dart` (Belge/Kimlik/Kitap/Fiş/Beyaz tahta/Kartvizit/Fotoğraf): stüdyoda hap seçici; kimlik ön+arka tek A4 (izolat), kitap cilt çizgisi = orta bandın en koyu sütunu, kartvizit OCR → .vcf (PDF yanında). Fiş/fotoğraf/kartvizit PDF'i A4 değil görsel oranında (`renderPdf(uniformA4:)`, stüdyo `_saver` seçili kipten).
- **Filtreler** `ScanFilter.vivid` (renk sapması ×1.45) ve `shadowless` (düzeltilmiş parlaklık ≥214 ve resim maskesi 0 → saf beyaz). `ScanFilter.values` ev temizliği kalıbına da giriyor (yeni ad = yeni geçici dosya soneki).
- **Izgara** stüdyoda (DragTarget+LongPressDraggable; `Opacity` yerine boş yuva — anayasa k.5). **Dışa aktar** `scan_export.dart`: tablo algılama (dikey örtüşme → satır, çok hücreli satırların sol kenarları → sütun çapası, tol = medyan yükseklik ×1.2), `parseNumber` (baştaki 0 → metin), kalite Küçük/Orta/Yüksek (1240/1754/2480 px, q60/75/88); sıkıştırılmış sayfada OCR kutuları oranla ölçeklenir (`scaleLines`) — unutulursa görünmez metin kayar.
- **Öneri şeridi:** kimlik → `addToVault`, fiş/fatura → `Giderler.csv` (`;` ayraçlı, UTF-8 BOM). **Kalite** `scan_quality.dart` (640 px gri kopya; Laplace varyansı <45 bulanık, parlaklık <85 karanlık, izdüşüm profili ±6° eğiklik ≥2°), yalnız görünen sayfa, dosyası yoksa atlanır (widget testleri sahte yol kullanır).
- **Taramalar** artık `Documents/Dosya Okuyucu/Taramalar`.
- **Tuzak:** Dart `RegExp` `\b` ASCII — "A.Ş." gibi Türkçe harf/nokta ile biten kalıpta sınır yok; boşluk bakışı kullan.
- **Açık:** `pdf` paketi 30 sayfayı kayda dek bellekte tutuyor (akışla üretim yok). Perf A/B: bekliyor (ölçüm yok). Kotlin köprüsü (`ci/DocScan.kt`) ilk kez `[release-apk]` ile faz dalında derlendi.

## 2026-11-05 — Faz zinciri onarıldı
- **Bug kökü:** faz görevlerinde `model` boş (→ Sonnet açılıyordu) ve istem 5. adımı kurulmamış bir "GitHub PR birleşti" tetikleyicisine güvenip `fire_trigger`ı yasaklıyordu → zincir her fazda koptu. Düzeltme: model `claude-opus-5-5`, 5. adım sıradaki id ile `fire_trigger`, TAMLIK KURALI (tüm maddeler [x] olmadan PR yok; daralırsa kendini yeniden tetikle). Yedek denetim `send_later` 2 saatte bir. Ayrıntı `docs/ZAMANLANMIS_GOREV_ISTEMI.md`.
- **Tuzak:** zamanlanmış görev isteminde "başka tetikleyici başlatır" deme — doğrulanmadıysa zincir kopar.
## 2026-11-05 — Faz 39 bitti (faz-39 dalı; kod — cihaz turu + perf A/B bekliyor)
- **Pro araçlar** tek girdi: PDF Araçları menüsü → "Pro araçlar…" levhası (`pdf_tools/pro_actions.dart` + `pro_views.dart`); bayrak `pdf_pro_v1` (varsayılan açık). Yeni bağımlılık yok.
- **Dijital imza:** Syncfusion `addExternalSigner` + kendi DER yazıcımız (`pdf/der.dart`) ile öz-imzalı X.509 (RSA-2048, pointycastle); anahtar uygulama destek klasöründe `signing/identity.json`. `.pfx` parolası saklanmaz. **Tuzak:** `RSAPrivateKey` 5. parametre (publicExponent) kullanımdan kalktı → analyze kırar.
- **Karartma:** Syncfusion'da redaction YOK → sayfa pdfium'la çizilir, kutu pikselleri siyah (`PdfRaster.encodeJpeg`), sayfa YENİ belgede görüntüden kurulur, kutu dışı sözcükler görünmez metin (`setTransparency(0)`); `leakedWords` çıktıyı yeniden açıp doğrular. Görünmez sözcük ölçüsü kutuya taşarsa YAZILMAZ (yazı tipi farkı sızıntı sanılırdı).
- **PDF/A-2b, agresif sıkıştırma, PDF→Word/Excel** hep `PdfRedact.apply` / `PdfExportPro` üzerinden; görüntüye çizen işler 40'lık parça (`_hardChunk`).
- **Tuzak:** `printing` paketi `PdfRaster` sınıfı dışa veriyor → `pdf_tools_screen` onu `show Printing` ile alır. Syncfusion `PdfNumberStyle` dışa veriyor → bizimki `PageNumberStyle`. `Printing.convertHtml` kullanımdan kalktı (gerekçeli `ignore`); printing yükseltilirse WebView + PrintManager köprüsü gerekir.
- **Tuzak:** `PdfGraphics`'te `scaleTransform` yok → sığdırmada şablon `drawPdfTemplate(size: page.size*scale)` ile çizilir, döndürme ötelemesi aynı ölçekle çarpılır.
- Okuma: `kPdfBookLayout = 3` (`_pdfColumns`), kaydırma kilidi = `panAxis: vertical` + `scaleEnabled: false`, sepya `ColorFilter.matrix`. Doldurma profili cihazda (`pdf_autofill_profile`), kimlik no BİLİNÇLİ yok (KVKK).
- Perf A/B: bekliyor (`docs/perf/2026-11-05-faz39.md`), cihaz listesi `CIHAZ_TESTI.md` Faz 39.
- **Tuzak (Faz 39 CI):** Syncfusion 33.2 `PdfBookmarkBase.add(destination:)` parametreyi YOK SAYIYOR → `..destination =` ayarlayıcısı. PDF/A belgesine `drawPdfTemplate` boş işaretçi atıyor → PDF/A yalnız görüntü + görünmez metin. Yeni `PdfDocument`te `drawString` kutusu 40 pt kenar boşluklu istemci alanına göre; çıkarılan metin kutusu SAYFA koordinatında.
- **Bug kökü (zincir, 2026-11-05):** Faz 39 zamanlanmış oturumunda `fire_trigger` aracı yoktu → Faz 36 tetiklenemedi. Kullanıcı kararı: elle başlatma YOK, zincir otomatik olmalı → araç yoksa oturum sıradaki fazı kendisi sürdürür (`docs/ZAMANLANMIS_GOREV_ISTEMI.md`).
## 2026-11-05 — Faz 36 bitti (faz-36 dalı; kod — cihaz turu + perf A/B bekliyor)
- **Excel pro** 12 madde: özet tablo (`xlsx/pivot.dart`), koşullu biçim yazma + yönetici (dosya kuralı `condRemovals` = sqref+priority ile sökülür), mini grafik (x14 extLst), dinamik dizi + LET + yapısal başvuru, parolalı xlsx (ECMA-376 Agile + kendi CFB yazıcımız), yazdırma PDF + yazdırma alanı (`_xlnm.Print_Area`), sade şerit/yoğunluk, içe aktarma/ara toplam/anahat/köprü, biçim boyacısı/tema renkleri, öncül-ardıl/hedef ara, grafik kombinasyon/ikincil eksen/eğilim, sayfa koruması. Bayrak `excel_pro_v1` (varsayılan açık).
- **Bug kökü (dinamik dizi):** `_Parser.resolve` sonucu `_single`'a indiriyordu → `FormulaArray` çapaya hiç ulaşmıyor, taşma/#YAYILMA! çalışmıyordu. `resolve` artık diziyi olduğu gibi döndürür.
- **Bug kökü (ekran testleri, 41 kırmızı):** açılışta parola denetimi `File.readAsBytes()` (zaman uyumsuz) çağırıyordu → widget testinin sahte saatinde dosya hiç yüklenmiyordu. Önce 8 baytlık OLE imzası `openSync/readSync` ile; yalnız OLE ise tam okuma.
- **Tuzak:** `pdf` paketinde `pw.Table(headerCount:)` YOK (yalnız `fromTextArray`); başlık yinelemek için `TableRow(repeat: true)`. Matcher `contains([..])` liste içinde listeyi eşitlikle bulmaz → `contains(equals([..]))`. Türkçe sayfa adı başvuruda tırnaklanır (`'Satış'!A1:E1`).
- **Tuzak:** sayfa koruması güçlü özeti SHA-512(H + LE32(n)) — sayaç SONDA (dosya şifrelemesinde başta). Biz 16 bit eski özet yazarız (`legacyHash('password') == '83AF'`).
- Perf A/B: bekliyor (`docs/perf/2026-11-05-faz36.md`), cihaz listesi `CIHAZ_TESTI.md` Faz 36.
## 2026-11-05 — Faz 37 bitti (faz-37 dalı; kod — cihaz turu + perf A/B bekliyor)
- **Mimari:** Word pro işlemleri paket düzeyinde: `doc.saveAsync()` → `DocxPackage` (zip + XML parçaları) → işlem → yeniden ayrıştır (`_proApply`, izolatta `DocxPro.run`); önceki bayt `_proUndo` (≤5) — üst çubuk ↶ editör yığını boşsa onu geri alır. İmleç→XML eşlemesi `DocxPackage.modelParagraphs()` = `DocxDocument._readBody` sırası (gövde p, üst düzey tablo hücre p'leri, boş hücre, metinli diğer öğe) — ikisi birlikte değişmeli.
- **İmlece öğe (alan, çapraz başvuru, kaynak):** editör `kDocxMarker` (U+E000 U+E001 U+E000) yazar, paket işlemi işaretli run'ı böler; başarısızsa `c.undo()`.
- **Araçlar sekmesi** `kWordProTools` (+ Tablo/Resim sekmesinde pro düğmeleri), bayrak `word_pro_v1`. Parolalı docx: sayfa görünümü (WebView) çözemez → Word ekranı Mobil editöre `pushReplacement`; kayıt `OfficeCrypto` Agile.
- **PDF** kendi çizicimiz (`docx_pdf.dart`, `pdf` paketi, Carlito/Tinos gömülü); `pdf` paketinde gazete sütunu yok → çok sütunlu bölüm PDF'te tek sütun akar. **DOCX yazı tipi gömme:** yalnız OFL metrik eşleri — Calibri→Carlito, Times/Georgia/Cambria→Tinos adıyla yazılır; odttf anahtarı GUID hex'in TERS bayt sırası, ilk 32 bayt XOR.
- **Sesle yazma** `ci/Dikte.kt` RecognizerIntent (kanal `dosya/dictate`), RECORD_AUDIO EKLENMEDİ (tanıyıcı uygulama ister); manifest `<queries>` RECOGNIZE_SPEECH.
- **Tuzak (analyze):** pro sınıf adları `docx_document.dart` kütüphanesindekilerle çakışıyordu (`DocxTableOps`, `DocxReview` zaten var) → `DocxTableTools`, `DocxReviewTools`. Yeni dosyada `xml` uzantı yöntemleri (`descendantElements`, `remove`) için `package:xml` importu şart. `XmlName('w:p')` önek ayırmaz → `XmlName.fromString`. SDK alt sınırı 3.3 → `?öğe` (null-aware eleman) ve `_` joker parametre YOK.
- **Tuzak (test):** `pdf` paketinin sıkıştırılmış çıktısında `/Type /Page` sayılamaz → `DocxPdf.render(compress: false)`.
- Perf A/B: bekliyor (`docs/perf/2026-11-05-faz37.md`), cihaz listesi `CIHAZ_TESTI.md` Faz 37.
## 2026-11-05 — Faz 38 bitti (faz-38 dalı; kod — cihaz turu + perf A/B bekliyor)
- **Mimari:** slayt pro işlemleri paket düzeyinde: `editor.saveAsync()` → `PptxPackage` (`services/pptx/pro/pptx_package.dart`: zip + XML parçaları, rels/içerik türü yardımcıları) → işlem (`PptxOp`, izolatta `PptxPro.run`) → `compute(PptxEditor.parse)`; önceki bayt `_proUndo` (≤5) — ↶ editör geçmişi boşsa onu geri alır, pro işlemden sonra `_history.clear()` (eski kayıtlar eski editör nesnesine bağlı). Bayrak `slides_pro_v1`.
- **İzolat tuzağı:** `PptxPro.query/run`'a giden kapanış durum nesnesini yakalamasın → okuyucular üst düzey işlev (`_readLayout(part)`, `_readChart(slide,id)` …) döndürür.
- **Sunum:** `SlideshowScreen(deck:, deckIndex:)` → `PptxShowInfo.read` (medya, köprü/eylem, sayaç, advTm) izolatta; parçalar `slideshow/{ink,media,presenter,actions,remote}.dart`. Sahne ölçüsü `_stageSize` (sunucu görünümünde ekrandan dar) — dokunma/çizim dönüşümleri bundan.
- **Bölümler:** `p14:sectionLst` üyeliği SIRAYA göre `PptxDeckOps.normalize` ile kurulur; `PptxEditor.buildArchive` her kayıtta çağırır (slayt ekle/sil/taşı bölümleri bozmasın).
- **Anlatım:** `setNarration` = ses şekli (`descr="dosya:anlatim"`) + `playFrom` `mediacall` düğümü + `p:audio` + `advTm`. **Tuzak:** çizici `mediacall` par'ını tıklama adımı sayıyordu (ses simgesi gizlenirdi) → `_timing` atlar. Gizli şekil (`cNvPr@hidden`) artık çizilmez.
- **Kotlin `ci/Slayt.kt`** (kanal `dosya/slides`): Media3 görüntü→MP4 (`setDurationUs`+`setFrameRate`, eski API bilinçli — 1.5.1), ML Kit konu bölütleme (`play-services-mlkit-subject-segmentation:16.0.0-beta1`), `MainActivity.dispatchKeyEvent` → ses tuşu kumandası, MediaRecorder anlatım, `android.app.Presentation` ikinci ekran. **RECORD_AUDIO eklendi** (Faz 37'de dikte için eklenmemişti; anlatım kaydı için gerekli, `izin_beyanlari.md`).
- **Tuzak (analyze):** `ReorderableListView.onReorder` kullanımdan kalktı → `onReorderItem` (indeks düzeltmesi yok). `flutter/services` zaten `Uint8List` verir → ayrı `dart:typed_data` importu "unnecessary_import". Build içindeki kapanışta `await` sonrası `context.mounted` (State.mounted değil).
- Yerel ağ kumandası: `HttpServer` rastgele bağlantı noktası + 8 harfli anahtar yolu; sayfa not METNİ göndermez (KVKK/ağ gizliliği).
- Perf A/B: bekliyor (`docs/perf/2026-11-05-faz38.md`), cihaz listesi `CIHAZ_TESTI.md` Faz 38.

- **Karar (2026-11-05, kullanıcı):** pano üst çubuğundaki AI Merkezi düğmesi (`dash-ai-hub`) KALDIRILDI; alt panelin sağ ek düğmesi varsayılan **AI** (eskiden "Yer aç"). "Yer aç" uzun bas → alt paneli düzenle'den seçilebilir; kayıtlı seçimi olan kullanıcının düzeni değişmez.
## 2026-11-05 — Faz 40 bitti (faz-40 dalı; kod — cihaz turu + perf A/B bekliyor)
- **Ortak üst çubuk** `widgets/editor_top_bar.dart` (`EditorTopBar.actions`): sıra SABİT kaydet · ↶ · ↷ · ekler · ⋮; dört editörde. Kaydet alt çubuklardan kalktı (tekrar yok). ⋮ → `showShareExportSheet` (`widgets/share_export_sheet.dart`, biçim + gönder; satırlar editörün mevcut işini çağırır, sayfa kapandıktan sonra).
- **Bağlam şeridi:** `DocActionBar(contextual:)` — Excel aralık seçiliyken Kopyala/Kes/Yapıştır başta.
- **Kapanış güvencesi:** `EditSession.onBackground()` (paused/hidden/detached) = taslak + otomatik kaydet açıksa dosyaya kayıt; bekçi `editor_uniform_test` (dört editör EditSession + withDraftBanner + EditExitGuard + EditorTopBar).
- **Tema:** `AppAccent` (skin.dart, 7 vurgu; açıkta koyu ton, koyuda açık ton; `accent_theme_test` her aile × zemin ≥ 4,5/3) + `SkinPalette.withAccent`; pref `app_accent`; ön ayar `ThemePresetTile` (Açık/Koyu/AMOLED/Kâğıt); yazı ölçeği kademesi 2,0 eklendi.
- **Tuzak (CI):** çeviri anahtar öneki `tp.` etiket seçicide (13_smart) kullanılıyor → `equal_keys_in_const_map`; yeni önek eklemeden önce `grep "'önek\."` yap. Faz 40 tema anahtarları `thp.*`.
- **Eksik çeviri bekçisi** `l10n_missing_scan_test`: EN'de ğışİĞŞ, AR'de Arap harfsiz Latin kelime yasak; istisna (marka/klasör adı) listesi gerekçeli.
- Durum yüzleri `widgets/state_views.dart`: `AppSkeleton` (nabız `Motion.pulse`, hafif/azaltılmışta yok), `AppErrorView` (editör hata satırlarının yerine). Boş durum çizimi `widgets/empty_art.dart` (FmEmptyState otomatik).
- Rehber: okuyucu · düzenleyici · tara + `SampleDocs` (yalnız düğmeyle, `Documents/Dosya Okuyucu/<Örnekler>`). Ayarlar: `suggestedSettingIds` → "Önerilenler" çipleri.
- Perf A/B: bekliyor (`docs/perf/2026-11-05-faz40.md`), cihaz listesi `CIHAZ_TESTI.md` Faz 40.
## 2026-11-05 — Faz 41 bitti (faz-41 dalı; kod — cihaz turu + perf A/B bekliyor)
- **Zincir:** `fire_trigger` bu oturumda da yoktu → yedek kural: Faz 41 aynı oturumda sürdü (Faz 40 PR #60 birleşti).
- **Çift bölme** `screens/fm/dual_pane_screen.dart` (`DualPaneModel` saf); gezgin ⋮'den. **SD SAF yazma** `services/fm/saf_write.dart`: `FileOps._transfer` başında `needsSaf` (çıkarılabilir birimde deneme dosyası yazılamazsa) → izinli ağaca (`SafRoot`) eşleme + `safCopyFromFile`; izin yoksa hata `SafWrite.noGrant` → `showSafGrantSnack`.
- **Drive** `drive_offline.dart`: sabitleme (`offline_pins.json`, `DriveCache.prune(keep:)`), taban kaydı `<id>/.base.json` → `DriveSyncState` (yerel/uzak/çakışma). OneDrive/Dropbox → KALANLAR B5.8 (uygulama kaydı 👤).
- **İçerik dizini** `content_index.dart` + `content_indexer.dart` (JSONL, artımlı; `textOf` null = sonraki tura, boş = metinsiz kaydı); `DeviceProfile.powerSave()` → Kotlin `Extras` kanalı `powerSave`. Kayıtlı aramalar `saved_searches.dart`.
- **Arama dizini artımlı:** `SearchIndex.applyChanges` + `FsEvents.changed(paths, indexed)` → `indexedVersion` eşitse dizin bayatlamaz.
- **Tuzak (CI, 3 kez):** çeviri anahtarı ÖNEKLERİ başka tablolarla çakışıyor (`tp.`, `saf.granted`, `ss.saved`) → `equal_keys_in_const_map`. Yeni anahtar eklemeden önce tüm `strings/*.dart`ta yinelenen anahtar taraması yap (python tek satır). `JobHandle`ta iptal = `cancelled` (JobRecord'da `cancelRequested`). `daysBetween` `int?` döner. `dart:ui` olmadan servis dosyasında `Color` yok.
- Perf A/B: bekliyor (`docs/perf/2026-11-05-faz41.md`), cihaz listesi `CIHAZ_TESTI.md` Faz 41.

## 2026-11-05 — CI: test seçimi, 3 parça, pre-push kaldırıldı (kullanıcı kararı)
- `hooks/pre-push` silindi: push öncesi yerel tam test (5–7 dk) yok; doğrulama yalnız CI.
  Windows'ta `core.hooksPath=hooks` kalsa da dosya olmadığından kanca koşmaz.
- `verify` 3 parça (`fail-fast: false`); kırmızı parça tek başına "Re-run failed jobs".
- Seçim `tool/ci_test_secimi.sh`: dal → `git diff merge-base(origin/main)..HEAD` →
  `tool/etkilenen_testler.py` (import grafiği + testteki `'lib'`, `'test/fixtures/..'`,
  `'assets/..'` yol dizeleri). Taban son push DEĞİL: iptal edilen koşunun değişikliği kaçmaz.
  main → ağaç yeşil PR başıyla aynıysa `atla` (iş yeşil biter, release bekler). Tam: `[tam]`.
- TUZAK: dal korumasında zorunlu kontrol adı "Doğrulama (analyze + test)" ise artık
  "Doğrulama (0/3)" … "(2/3)" seçilmeli.
- **[apk] işareti (2026-11-05, kullanıcı kararı):** main push'u APK/nightly yalnız başlıkta `[apk]`
  ya da `Merge pull request #N from …/faz-NN` başlığında derler (`changes` → `apk_isareti`).
  CI/belge birleştirmesi sürüm üretmez. APK derlemesi tek adım (~7 dk, Dart AOT + Gradle) —
  parçalara bölünemez; push'ta zaten yalnız arm64.
- **Sürüm adı ilerler (2026-11-05, kullanıcı kararı):** eskiden `1.0.<koşu no>` (ilk iki hane hiç
  değişmiyordu). Artık `ANA.ARA.N`: ANA.ARA `app_version.dart` (1.1'e çıkarıldı), N = o tabandan bu
  yana main'de yayın işaretli commit sayısı ([apk] / faz PR birleşmesi; `tool/surum_hesapla.sh`,
  `changes` işinde). Başlıkta `[minor]` → ARA +1, N sıfırlanır. versionCode yine koşu no (güncelleme
  denetimi ona bakar). Nightly'de sabit ad + `dosya-okuyucu-v<ad>.apk`; eski sürümlü ad silinir.

## 2026-11-06 — Faz 42 bitti (faz-42 dalı; SON geliştirme fazı — cihaz turu + perf A/B bekliyor)
- **Bütçeler:** `tool/bagimlilik_denetimi.py` + `ci/bagimliliklar.txt` (verify 0/3; yeni paket listede yoksa kırmızı — gerekçe HAFIZA'ya). `test/startup_budget_test.dart`: `main()` içindeki `await` adları onaylı listede; yeni iş → `unawaited`/`StartupQueue`.
- **Perf kapısı:** `perf` etiketli dosyalar (`@Tags(['perf'])`) seçili test adımından ÇIKARILIR, 0/3'te ayrı "Perf gerileme kapısı" adımında hep koşar (`--exclude-tags` kullanılmadı: yalnız perf dosyası kalan parçada "No tests ran" = 79). APK taban `ci/apk_boyut_tabani.txt` (+%2 kırmızı, başlıkta `[boyut]` uyarı).
- **Büyük xlsx:** `services/xlsx/xlsx_stream.dart` — `InputFileStream` + `writeContent(OutputFileStream)` ile girdiyi geçici dosyaya açıp `xml_events` akışıyla okur; tavan `PerfBudget.xlsxStreamMaxCells`, eşik `xlsxFullParseMaxBytes` (8/20/40 MB). Sonuç `XlsxEditor.fromStream` → tüm sayfalar `truncated` (kaydetme kapalı, şerit `lf.xlsx_stream`). PDF görüntüleyici zaten `PdfViewer.file`; araçlar `pdfInMemoryMaxBytes` üstünde açılmaz.
- **Bildir (A8):** `services/diag_report.dart` — `DiagReport.scrub` (tırnaklı yol, URI, e-posta, `(?<![\w.])` yol, belge adı, 6+ hane) + `FrameStats` (kova sayacı, `diag_frame_stats` varsayılan kapalı, `StartupQueue`'da). Hata kayıtları AppBar 🐞 → önizleme + onay + paylaş. Gizlilik metni (3 dil) güncellendi.
- **integration_test:** `pubspec.lock`'a elle girildi (Flutter yok): sdk `integration_test`/`flutter_driver`/`fuchsia_remote_debug_protocol` + hosted `process 5.0.6`, `sync_http 0.3.1`, `webdriver 3.2.0` (Flutter 3.44 sdk paketleri `any` — pub en yeniyi seçer; sha256 pub.dev API'den). CI `--enforce-lockfile` kırarsa çıktıdaki sürümü yaz.
- **R8:** `ci/proguard-rules.pro` Faz 42 bloğu; `DOSYA_R8TEST=1 bash ci/prepare_android.sh` `.r8test` kimliğini otomatik kurar (eski 3 elle düzenleme); `tool/r8_ab.sh` = yayın kipi logcat denetimi + profil senaryoları (integration_test yayın kipinde koşmaz).
- **Mağaza:** tek kaynak `docs/play/magaza_metinleri.md` → `tool/magaza_varliklari.py` → `fastlane/metadata/android/` (Pillow yerelde bozuk → venv). TR/EN başlıklar 33 karakterdi (Play sınırı 30) → kısaltıldı. Tur: `docs/SURUM_ADAYI.md`.
- Perf A/B: bekliyor (`docs/perf/2026-11-06-faz42.md`), cihaz listesi `CIHAZ_TESTI.md` Faz 42.

## 2026-11-06 — Kullanıcı listesi: Dosyalarım adı, Aktar sekmeleri, filtre şeridi, temalar, uygulamalar, otomatik AI
- **Ad:** başlatıcı etiketi `ci/AndroidManifest.xml` + `MaterialApp.title` + lisans sayfası + çeviri metinleri "Dosyalarım". Disk klasörü (`DocsHome.folderName`, USB/indirme alt klasörü "Dosya Okuyucu"), paket kimliği ve Kotlin kanal adları DEĞİŞMEDİ (mevcut kullanıcı dosyaları/güncelleme bozulmasın). Türkçe ek: "Dosyalarım'a", "“Dosyalarım”a".
- **Temalar:** Notlar'ın D–J aileleri eklendi (`AppSkin` lavender, olive, white, straw, cream, peach, mint) — belirteçler Notlar `app_palette.dart`tan (ground→bg, card, sheet→band, field→well, hair→rule, primary→accent, primaryContainer→accentWell); soluk mürekkepler kontrast için koyulaştırıldı (scratchpad betiği, WCAG). `withAccent` kuyusu artık kontrast ≥4,5 olana dek karışımı azaltır (Saman + kiremit vurguda 4,23 idi).
- **Filtre şeridi** (`fm_quick_filters.dart`): üç ayrı gri hap → tek kâğıt kart, bölmeler arası tüy çizgi, etkin bölme vurgu kuyusu; `FmChip`/şerit dışı `FmPill` kart renkli, ince kenarlı, `radiusControl` köşeli. Yükseklik sabit 48 (test).
- **Aktar** (`remote/nearby/tabs.dart`): 3 sekme — Hızlı aktar (ince durum şeridi + seçim + yatay cihaz şeridi + QR; 360×780'de kaydırmadan sığar, `nearby_layout_test`) · Diğer yollar · Geçmiş. Hizmetler State'te; sekme değişince durmaz.
- **Uygulamalar** — yavaş açılış kökü: `getInstalledApps(withIcon: true)` (her simge PNG) + son kullanım + boyut SIRAYLA bekleniyordu. Şimdi `listStaged`: önbellek → simgesiz liste (kullanım ∥ boyut) → simgeler. Canlı silme kökü: `uninstallApp` sistem penceresini açıp ANINDA dönüyor, ardından gelen yenileme kaldırmadan önce koşuyordu → öne gelişte `isAppInstalled` yoklaması (0/0,4/1,2/2,5 sn), satır düşer + `forget`.
- **Otomatik AI analizi** (`services/fm/ai_auto.dart`): Ayarlar → AI → "Yeni dosyaları otomatik analiz et", varsayılan KAPALI; yalnız açıldığı andan (`autoSinceMs`) sonra değişen dosyalar; açılışta (StartupQueue) + öne gelişte en sık 20 dk'da bir; aday yoksa iş/bildirim açılmaz.

## 2026-11-07 — QR küçüldü, Ayarlar yeniden, görselli tema galerisi
- **QR:** `QrCode.fitSize` (kısa kenar × 0,5, yüksekliğin ≤ 1/3, 132–220 dp) — Hızlı aktar (≤200), FTP (≤180); `qr_share_screen` sayfa alanına `LayoutBuilder` ile sığar (eski 420 dp). Painter matrisi/yolu bir kez kurar (her boyamada `Barcode.make` koşuyordu). Okuyucuda `enableAutoZoom()` (code-scanner 16.1.0).
- **Ayarlar ana ekranı:** üstte görünüm kartı (önizlemeli tema şeridi + Açık/Koyu/Otomatik), önerilenler (`skin` önerisi süzülür — galeri zaten üstte), kategoriler TEK kartta ince ayraçlarla.
- **Tema galerisi** (`settings/theme_gallery.dart`, Notlar `ThemeChoiceCard` örneği): her aile mini ekran (masa, üst çubuk, kâğıt kart + ailenin klasör simgesi, yazı satırları, vurgu düğmesi), şu anki parlaklıkta. `skin` satırı artık ızgara; yinelenen **hızlı tema çipleri (`theme_preset`, `ThemePresetTile`) KALDIRILDI** (aile + mod ikilisinin kopyasıydı); `accent` Tema bölümüne geçti.
- **Bağlantı denetimi:** katalogdaki her `builder` kullanılıyor, her ayar alıcısı uygulamada okunuyor (tazeleme hızı/başarım kipi/düzenleme tercihleri anında uygulanıyor). Bağsız ayar bulunmadı.

## 2026-11-07 — İzin sadeliği aşama 1 (Play yorum çalışması; Claude Docs "İzin Sadeliği ve Google Play Yorum Analizi")
- **Kural:** bir dokunuş = en çok BİR sistem izin penceresi; açılışta hiç pencere yok. Bekçi `test/permission_simplicity_test.dart` (yeni ham `Permission.x.request()` → onaylı liste).
- `StoragePermission.request()`: Android 11+ yalnız "tüm dosyalar", ≤10 (eklenti `manageExternalStorage` = `restricted`) yalnız klasik depolama. Eski zincir (klasik → tüm dosyalar → 3 medya izni) kaldırıldı. `hasFullAccess` ≤10'da klasik izne bakar (eskiden hep false'tu → Android 10'da pano kartı hiç kaybolmuyordu). `PluginPermissionProbe` allFiles'ı buraya yönlendirir.
- Ret → `showStorageDeniedHint` ("Sorun değil — tek tek aç" + Dosya aç → SAF seçici → `EntryOpener.open`); ayarlara itilmez.
- **Bildirim izni açılıştan kalktı:** `NotificationHub.init` artık `requestNotificationsPermission` ÇAĞIRMAZ. İstek: ilk uzun işte `tellIfNotificationsOff` snack'i ("İzin ver"), Faturalar ekranında `PermissionStatusRow(hideWhenGranted)`, rehber satırı, Hızlı aktar. Yeni bildirim kullanan özellik eklenirse izni ORADA iste.
- **Tuzak — READ_MEDIA_* manifestten çıkarılamaz (henüz):** `open_filex` 4.7.0 Android 13+'ta görsel/video/sesi dış uygulamada açarken bu izinleri denetler/İSTER; bildirilmezse açma "Permission denied" ile düşer. Çıkarmak için önce `EntryOpener.openExternally`'yi kendi `ACTION_VIEW` + FileProvider köprüsüne taşı (aşama 2 adayı).
- Mağaza kısa açıklaması "Reklamsız… İzin istemeden açılır, dosyan telefonda kalır." + uzun açıklamada İzinler bloku (Play "tüm dosyalar" kullanımının mağazada belirgin anlatılmasını istiyor).
- **2026-11-07 — main APK'sı iki koşudur çıkmıyordu:** #608 (QR/Ayarlar/tema galerisi) #609'la iptal, #609 (Galeri Seç) kırmızı: `image_gallery/widgets.dart` seçim simgesi `Positioned(right:)` (rtl_guard) + ham `Color(0xAA000000)` (design_tokens hex tavanı). → `PositionedDirectional(end:)` + `AppColors.mediaChrome`. Ders: `[apk]` push'tan sonra Actions sonucuna bir kez bak; kırmızıysa APK hiç yayımlanmaz.

## 2026-11-07 — Yükseltme planı (Faz 43–50) + pdfrx 2.12 ön incelemesi
- Plan: `docs/YUKSELTME_PLANI.md` (KALANLAR Faz D). Yerel Windows + USB telefon; bu fazlarda yerel test serbest (kullanıcı kararı).
- **Flutter son kararlı 3.47.9 (Dart 3.13.7)**; pdfrx 2.12 ve background_downloader 9.6 Flutter ≥3.47 istiyor → Flutter önce.
- **Zincir açıldı:** `pdf 3.13.1` artık `xml ^7` → syncfusion 35, image 4.12, xml 7 birlikte çözülebilir (A3.4b engeli).
- **pdfrx 2.12.0 kaynağı (pub arşivi) okundu:** N2 (boyamada her sayfanın metnini yükleme) DÜZELTİLMİŞ — `isTextSelectionEnabled` koşullu.
  N1 (erişilebilirlik açıkken satır başına Semantics) HÂLÂ VAR, kapatma parametresi yok (`forceEnableTextSemantics || semanticsEnabled`)
  → yukarı akış PR'ı ya da `third_party/pdfrx` yaması. `ExcludeSemantics` yetmez (bayrak `SemanticsBinding`'den).
  Hangi nedenin baskın olduğu hâlâ ÖLÇÜLMEDİ — Faz 48.1'de cihazda A/B.

## 2026-11-07 — AI Merkezi baştan (hayalet kayıt, "kendi kendine taşıma", anlaşılmazlık)
- **Hayalet kayıt kökü:** `AiIndex.pruneMissing` yalnız AI listesinin kendi silme düğmesinden sonra koşuyordu; Galeri/WhatsApp/başka ekrandan silinen dosya listede kalıyor, dokununca "Dosya bulunamadı". Artık: hub açılışı + `FsEvents.version` (geciktirmeli) + her analiz sonu + satıra dokununca dosya yoksa. Denetim asenkron, 200'lük parçalar. `AiFilesScreen` listesi `revision`'a bağlandı (eskiden bir kez kuruluyordu).
- **"Kendi kendine önemli dosyalara taşıma" kökü:** (1) öneriler `Önemli Dosyalar/<klasör>`e taşıyordu → yıldız/silme koruması yüzlerce dosyaya yayıldı; (2) yerel kural sınıflandırıcısı (`_localRecord`) her tanıdığı belgeye klasör yazıyordu → anahtarsız analizde her belge "taşınacak"; (3) başlıkta onaysız "Tümünü uygula (N)". **Karar:** klasör önerisi yalnız `source=='ai'` (`hasFolderSuggestion`), Önemli Dosyalar'daki dosyaya öneri yok, hedef `<bellek>/Documents/<klasör>` (`AiApply.folderRootIn`), uygulama yalnız `confirmApplyAiSuggestions` levhasından (ad / taşı ayrı anahtar, taşı varsayılan KAPALI). Satır menüsü: yalnız bunu uygula · yok say (`AiIndex.dismissSuggestion`).
- **Arayüz:** başlıktaki 4 yazısız simge → tek yazılı menü; "Etiketler" → **Türler** (yalnız görünüm, açıklama satırı); Analiz sekmesi = durum kartı (otomatik turda "Yeni dosyalar analiz ediliyor" + `AiProgress.auto`) + "Okur / Sınıflandırır / Kendi kendine hiçbir şey yapmaz" + otomatik analiz anahtarı (`AiAutoNewTile`) + kapsam + onaylı yeniden analiz. Diğer sekmelerde ince şerit yalnız analiz SÜRERKEN. Satırdaki kırmızı yıldız → yazılı "Önemli" etiketi (Önemli Dosyalar yıldızıyla karışıyordu).
- **2026-11-07 ek:** Öneriler → Bekleyen / **Yapılanlar** (`AiApplyLog`, son 300). Zaten önerilen klasördeki ("Sözleşme"≈"Sözleşmeler") ya da adı öneriyle aynı dosyaya öneri yok. Ad değişip taşıma düşünce kayıt eski yolda hayalet kalıyordu → ad değişir değişmez `movePath`.

## 2026-11-07 — Faz 43: ölçüm tabanı (MatePad DBY-W09, GMS'siz) → `docs/perf/2026-11-43-taban.md`
- **Taban:** P1 975 ms · P2 0 kare · P3 build p99 30,2 / raster p99 7,9 · P5 (PDF-B) FrameTiming p99 17,7, ≥25 ms kare 15, PSS 352 MB · P10 pano 219 MB. Xiaomi satırları bekliyor; P6 ölçülemedi (tablette erişilebilirlik gerçekte KAPALI, `accessibility_enabled=0`).
- **Kapı tuzağı:** bu tablette klasör kaydırma build p99 tabanda zaten > 24 ms → §0.4 mutlak sınırı burada değil, Xiaomi'de uygulanır; tablet için kapı = tabana göre %10.
- **Huawei/Windows yerel ölçüm tuzakları:** `adb install` iki onay ekranı (DEVAM ET → YÜKLE; uiautomator ile koordinat); `flutter drive` yeniden kurunca MANAGE_EXTERNAL_STORAGE düşer (koşu sırasında `appops set` döngüsü); `traceAction` için `flutter drive --no-dds` şart (yoksa "Failed to connect to VM Service"); Git Bash'te `MSYS_NO_PATHCONV=1`; Windows'ta `python3` sahte kısayol → betikler `python`a düşer; `prepare_android.sh` var olan `android/` üstünde yeniden koşunca desugaring adımında durur → önce `rm -rf android`; Huawei ROM'da `screenrecord` yok; `input` ile yakınlaştırma yok (çift dokunma PDF'te metin seçer).
- **Gözlem (kök neden aranmadı):** `am start VIEW video/mp4 file://` oynatıcı yerine panoyu açıyor; `SEND application/pdf` Aktar ekranını açıp konum + yakın cihaz izni istiyor.

## 2026-11-07 — Faz 44: Flutter 3.47.9 (Dart 3.13.7) → `docs/perf/2026-11-44.md`
- **Yerel SDK artık `C:\src\flutter-3479`** (CI 3.47.9). `C:\src\flutter-3446` yalnız eski taban A/B'si için.
- **Dart 3.13 kırığı:** await sonrası tip daraltması sıkılaştı → `pdfrx 1.3.5` ve `dartssh2 2.14.0` derlenmiyor. Yeni sürüme geçmek zincir başlatıyor (dartssh2 2.15+ → pointycastle 4 = Faz 45; pdfrx 2.x = Faz 48, perf gerekçeli sabit) → **`third_party/` yamalı kopya + `dependency_overrides`** (2+1 satır `!`). Kalkacağı faz `third_party/README.md`'de; yükseltme fazında klasör SİLİNİR.
- **Lint:** Dart 3.13 + 202 yeni bilgi uyarısı (`unnecessary_underscores`, `use_null_aware_elements`, `prefer_initializing_formals`) → `dart fix --apply --code=…`; `Semantics.header` Android'de etkisiz → `headingLevel`.
- **Kapı kararı (kullanıcı):** PDF-B p99 +%14–18 (kuyruk; ≥25 ms kare ve en uzun kare aynı) → "çok kötü değilse birleştir" → birleşti. Zaman çizelgesi: raster p50 aynı, fark izlenmeyen sunum/takas aşamasında (motor içi).
- **Ölçüm tuzakları:** tek koşu taban yanıltıcı (aynı yapı klasör build p99 30,2 ↔ 22,0) → kapı A/B ile, aynı oturumda, ≥3 (PDF ≥5) koşu medyanı. Bu tablette hem uygulama hem integration_test **Impeller GLES** ile çiziyor (logcat "Vulkan" dese de; çizelgede `ReactorGLES`). `flutter drive` sonunda uygulama kaldırılabiliyor ve `build/app/outputs/.../app-profile.apk` sürücü APK'sıyla ÜSTÜNE yazılıyor → ölçüm öncesi gerçek APK'yı yeniden derle. `perf_driver.dart` boş çizelgede tüm özetleri düşürüyordu → atlıyor. AppGallery kaldırıldı (kullanıcı) → kurulum onayı standart `PackageInstallerActivity` "YÜKLE".

## 2026-11-08 — Faz 45–47: paket yükseltmeleri (tek dal `faz-45`)
- **Temiz taban:** tabletten 25 reklam paketi `pm uninstall --user 0` (liste/geri yükleme CIHAZ_TESTI §0) → yeni taban `docs/perf/2026-11-45-temiz-taban.md`. P2 ölçümü `SurfaceView[...](BLAST)#0` katmanıyla — BLAST'sız katman kaydırırken de 0 döner (yanlış sıfır).
- **xml 7:** `XmlName(x)`/`XmlName.fromString` → `XmlName.qualified`, 2 argümanlı → `XmlName.parts(l, prefix:)`, `namespace:` → `namespaceUri:` (betikle 489 yer) + `dart fix` const. Davranış farkı test takımında görülmedi.
- **Override'lar (gerekçe pubspec yorumunda):** `xml` (webdav_client 1.2.2 ^6), `pointycastle ^4` (smb_connect 0.0.9 ^3; 4.0'ın tek kırılımı generateKeyPair jenerikleri), `dartssh2 ^4.1` (ftpconnect 3.0 ^3.3.1). pointycastle 4 ⇄ dartssh2 ≥2.15 birbirini zorladı → dartssh2 4 Faz 45'e öne alındı, `third_party/dartssh2` silindi.
- **Kök neden — SFTP 14 → 1 MB/sn (dartssh2 ≥3.1):** sürüm bölme (3.0.2 hızlı, 3.1.0 yavaş), mesaj sayısı aynı, mesaj başı 8× süre → 3.1'de varsayılan şifre sırası **aes256-gcm önde**; saf Dart (pointycastle) GCM yavaş. `SftpFs._algorithms` CTR'yi öne alır (ETM HMAC ile güvenli). Tuzak: dartssh2'yi yükseltirken şifre sırası değişirse hız yeniden ölçülmeli (`tool` yok — yerel asyncssh sunucusu + 32 MB aktarım testi).
- **dartssh2 4 tuzakları:** `SSHClient.close()` artık Future (transport `await socket.close()`); beklenmezse karşı taraf önce kapattığında "Write failed" yakalanmamış hata → `close()` beklenip yutuluyor. ssh-rsa/CBC/SHA-1 KEX varsayılan kapalı (çok eski NAS bağlanamaz; bilinçli, OpenSSH ile aynı).
- **google_sign_in 7:** `authenticate()` (Credential Manager) Android'de **serverClientId (web istemcisi)** ister — bizde yok. Drive'a yalnız belirteç lazım → sadece `GoogleSignIn.instance.authorizationClient` (Identity AuthorizationClient, mevcut Android OAuth istemcisi paket+SHA-1 ile). `disconnect` yalnız eklentinin o süreçte tanıdığı hesabı iptal edebilir → önce sessiz `authorizationForScopes`.
- **file_picker 13:** `FilePickerResult`/somut `PlatformFile` yok, `allowMultiple`/`withData` kalktı → `AppFilePicker` kendi `PickResult/PickedFile`'ını döner; Android yine önbelleğe kopyalayıp `file://` yol veriyor.
- **open_filex kalktı:** `MainActivity` "openExternal" = `DocumentsContract.buildDocumentUri("$packageName.documents", yol)` (DosyaProvider, belge kimliği = mutlak yol) + `FLAG_GRANT_READ_URI_PERMISSION` → READ_MEDIA_* manifestten çıktı (izin sadeliği aşama 2). Cihazda elle doğrulanacak (CIHAZ_TESTI Faz 45–47 /1).
- **permission_handler_android 14.1:** `status` artık `permanentlyDenied` dönmüyor; yalnız `request()` dönüşü → kapı ilk dokunuşta isteyip ikincide "Ayarları aç".
- **shared_preferences_android 2.4.28 sabit kalır:** 2.5.4 kaynağında `onDetachedFromEngine` → `SharedPreferencesApiRegistrar().register(null)` süreç geneli `SharedPreferencesApiInstances`tan siliyor (çökme kökü aynı). Cihaz denemesi gerekmedi.
- **Reddedilen:** `dart format` ile toplu biçimleme (30 dosyada 3.600 satır gürültü) — yalnız betikli düzenleme.
- **Tuzak (Windows yerel):** `PATH`'e `C:/...` yazma (iki nokta PATH'i böler) → `/c/...`; heredoc'ta `\`/`\r` kaçışları kanca tarafından bozuluyor → Python betiğini dosyaya yaz; CRLF dosyalarda betik `\r\n`'yi normalize etmeli.

## 2026-11-08 — Faz 48: pdfrx 1.3.5 → 2.12.0 (ölçerek) → `docs/perf/2026-11-48-pdfrx.md`
- **Kök neden ölçümle (MatePad A/B, PDF-B 54 s.):** 2.x'in kendisi 1.3.5'ten kötü değil (B ≈ A). İki ek yük vardı:
  **N1** erişilebilirlik açıkken satır başına Focus+Semantics (`forceEnableTextSemantics` ile taklit: UI kare p99 3,3 → 5,8–6,3 ms, PSS +%20)
  → `third_party/pdfrx` tek satır yama (`YAMA.md`); **N5** bizim 1.3.5 dönemi basamaklı `getPageRenderingScale`'imiz 2.x'te fazladan
  çizim → kaldırıldı (FrameTiming p99 19 → 13, ≥25 ms kare 15 → 9). Son yapı: p99 11,3 (A 15–20), açılış aynı, PSS +%21 medyan (aralık A'nınkinin içinde).
- **P6 (erişilebilirlik gerçekten açık) bu tablette ölçülemez** (hizmet yok, ayara dokunma) → GMS/Xiaomi cihazda; B2 taklidi yerine geçti.
- **Tuzak (Windows yerel):** pdfrx 2.x `pdfium_dart` native-assets hook'u C derleyicisi ister → ~~Windows'ta derlenmez~~ **2026-11-08 düzeltme:** MSVC kurulu ama `vswhere -latest` onu görmüyor; `C:\Users\sena\vsshim` PATH'in başına → yerel `flutter test` çalışır (bkz. PDF Pro Faz 51 notu). Windows'ta Git Bash `/c/...` yolu adb/python'a VERİLMEZ (`pwd -W` ile `C:/...`); PATH'e ise `/c/...`.
- **Huawei yükleme onayı otomatik:** uiautomator dökümünde "DEVAM ET/YÜKLE" (UTF-8 okunmalı: `sys.stdin.buffer…decode('utf-8')`).
- **Okuma yardımcıları (Aa levhası, yalnız PDF):** ekran açık · ses tuşuyla sayfa (Slayt.kt köprüsü, yeni Kotlin yok) · otomatik kaydırma (kare geri çağrısı yalnız açıkken, parmak değince bekler). Kapalıyken sıfır maliyet.
- **2026-11-08 · Office geliştirme (PR #67):** araştırmada önerilenlerin çoğu zaten vardı (Word okuma modu/başlık gezgini/bul-değiştir; Excel bölme/süzgeç/formül çubuğu; Slayt sunucu görünümü/notlar/şerit) → yeniden yazılmadı. Eklenen: Excel `workbookView/@activeTab` + `selection/@activeCell` ile kaydedildiği sayfa/hücrede açılır (gizli sayfa → ilk görünür) · Word/Slayt kaldığı yerden (PDF'in `ReadingPositions`'ı, aynı ayar, yeni servis yok) · gösteride siyah/beyaz ekran (B/W . ,) + "Tüm slaytlar" ızgarası (sayaç / G). Ölçüm `docs/perf/2026-11-08-office.md` (kapı geçti).
- **Tuzak (bekçiler):** ekran kodunda `showModalBottomSheet` yok → `showAppSheet` (koyu zemin için `backgroundColor` parametresi eklendi); `Colors.*` yok → `AppColors.mediaSurface/page`; gerekçesiz boş `catch` yok (yorum yaz). Dal main'den önce ayrıldıysa APK boyut tabanı eski kalır → `origin/main` birleştir.
- **Tuzak (ölçüm):** onay.py'yi her `flutter drive` öncesi 60 sn'lik başlatmak yetmez (derleme ~140 sn) → onaycıyı ölçüm boyunca döngüde koştur; `appops` döngüsü de kurulum gecikirse biter. `gelistirme-*` dalları workflow push tetiğinde yok → `gh workflow run build-apk.yml --ref <dal>`.

## 2026-11-08 — Galeri/tema geliştirme (dal `faz-galeri`)
- **Bug kökü — Gece'de "eski simgeler":** `SkinMetrics` night/system → `SkinIconStyle.outlined`; bu dal 2026-11-04 squircle/2.5D pano çizimini ve dolu dosya simgelerini atlayıp düz Material glif çiziyordu (tasarım kararı gibi duruyordu, kullanıcı hata olarak yaşadı). Artık gradient; bekçi `nav_tabs_test` (night/system = varsayılan dil).
- **`outlined` → `classic` dili:** boşta kalan dil silinmedi, "Klasik"/"Defter" ailelerinin düz çizimine dönüştü (manila klasör + beyaz sayfa + renkli tür şeridi). `FmColors.iconFor(outlined:)` kalktı (çizgi eşlemesi dolu eşlemeyle birebir aynıydı). Yeni palet eklerken WCAG yerelde Python ile hesaplanabilir (Windows'ta `contrast_test` derlenmiyor — pdfrx native assets).
- **AI ikinci ad = `AiRecord.title`** (yeni alan YOK): satırda alt yazının başında (tek satır → `prototypeItem` sabit yükseklik korunur), `SearchIndex.query` ad eşleşmelerine `AiIndex.aliasMatches` ekler (katlanmış başlık `Expando` önbelleği). Tek dosya: `giveAiAlias` → `AiAnalyzer.start(candidates:[e], reanalyze:true)`. Orijinal ad yalnız AI Merkezi onaylı akışında değişir.
- **Satır içi oynatma:** `FmInlinePlay` yalnız `FmFileListView` satırlarında (`audioQueue`); durum bildirimini dinler, konumu yalnız çalan satırın halkası (`positionListenable`).
- **Galeri:** mevcut olanlar tekrar yazılmadı (zaman ekseni, pinch yoğunluk, yıl çubuklu kaydırıcı, slayt, benzer/kopya). Eklenen: Albümler levhası + "Bu gün geçmişte" — yalnız `_visible`'ı daraltır, ızgara çizimi aynı.
- **Tuzak (yerel ölçüm/kurulum):** `android/` önceki R8 A/B'den `.r8test` kimliğinde kalmış olabilir → `flutter build apk --profile` AYRI paket kurar (`adb install` "Success" der ama ana uygulama değişmez; `aapt dump badging` ile bak). Git Bash'te `--dart-define=...=/sdcard/...` yolu `C:/Program Files/Git/sdcard` olur → `MSYS_NO_PATHCONV=1` (P13 tablo_100k "PathNotFound").

## 2026-11-08 — Play yorum çalışması aşama 2–3 + Faz 49 temizlik (dal `faz-49`)
- **Çevrimdışı kip tek noktada:** `main()` = `http.runWithClient(_main, OfflineAwareClient.new)` → `package:http`'in üst düzey işlevleri ve `http.Client()` hep `OfflineMode.check`'ten geçer; yerel ağ (10/172.16–31/192.168, .local, loopback, link-local, ULA) serbest. dio/dart:io HttpClient KAPSANMAZ (webdav_client, peer_share/qr_transfer — yerel ağ). Yeni internet çağrısı `package:http` ile yazılmalı. AI ayrıca `AiPool.run` başında `statusCode: -1` (kalıcı) — 0 dönseydi toplu kuyruk "ağ hatası" sanıp yeniden denerdi.
- **Tuzak:** `test/startup_budget_test.dart` `main` gövdesini METİNLE arar → artık `Future<void> _main() async {`.
- **AI onayı = `AiPool.consent` kancası** (tüm AI çağrıları `PooledGemini` → `AiPool.run`): oturumluk "Gönder" (500 dosyalık toplu analizde 500 pencere olmasın) + kalıcı "Bir daha sorma" (`ai_send_consent`). Ekran yoksa (arka plan) sorulmadan GÖNDERİLMEZ.
- **Klasör ekle:** SAF altyapısı (SafFs, safPickTree, panoda SAF kartı) zaten vardı; eksik olan pano kartındaki düğme + Gizlilik sayfasında "Eklenen klasörler / Geri al" (safForget). İzin kartı dili belgedeki örnek; "İptal" yok.
- **İzinsiz okuyucu derlemesi:** `.github/workflows/build-okuyucu.yml` (yalnız elle; workflow main'de olmadan `gh workflow run` çalışmaz) → `ci/prepare_android.sh` §11 `DOSYA_OKUYUCU=1`: `.okuyucu` kimliği (r8test ile ortak SUFFIX bloğu) + `play_variant.py` ile 21 hassas izin çıkar, birleşmiş manifest `verify`; Dart `StoragePermission.readerBuild` izin düğmelerini gizler. Bilinçli sınır: yakındakiler/uygulamalar gibi izinli özellikler arayüzde duruyor ama izin alamaz — gizlemek ayrı iş.
- **Play AAB varsayılan çıkarma:** QUERY_ALL_PACKAGES + READ_MEDIA_* (ana manifestte Faz 46'dan beri yok; eklenti sızıntısına karşı).
- **Neler yeni:** `WhatsNew` ANA.ARA anahtarlı; yeni kurulum görüldü sayılır; perf senaryosu önceden işaretler (açılış ölçümü bozulmasın). ARA hane artınca `WhatsNew.items` yenilenir.
- **Sürüm ara hanesi elle:** CI yalnız `appVersionPatch`'i sed'liyor; başlıkta `[minor]` yalnız hesaplanan adı +1 yapar, uygulama içi `appVersionMinor` değişmez → ARA'yı `app_version.dart`'ta artır, başlığa `[minor]` YAZMA (çift artar).
- **Faz 49:** override'ların dördü hâlâ gerekli (yukarı akışta yeni sürüm yok); `convertHtml` ignore'ları kalır (printing 5.15'te hâlâ deprecated). Aylık rapor `bagimlilik-raporu.yml` (otomatik yükseltme yok). Kotlin: kalkan API'lerin hepsi zaten sürüm korumalıydı, yalnız PackageManager int-bayrak çağrıları 33+ `*Flags.of`. CI APK logunda Kotlin uyarısı basılmıyor → kaynak taramasıyla bakıldı.
- **Tuzak (yerel ölçüm):** `ci/prepare_android.sh` var olan `android/` üstünde ikinci kez KOŞMAZ (desugaring "build.gradle bulunamadı" — zaten yamalı) → önce `rm -rf android .backup`. Git Bash'te `python3` Windows'un sahte kısayolu olabilir → PATH'e `exec python "$@"` sarmalayıcı.
- 2026-11-08 · Orkestra gecesi TUZAKLARI: (1) CI push tetiği yalnız `main`/`faz-*`/`claude/**`/`ccr-*` — `gelistirme-*` gibi dalda CI HİÇ koşmaz, PR sessizce bekler → dalı `faz-` önekiyle aç ya da `gh workflow run build-apk.yml --ref <dal>`. (2) Huawei kurulum onaycısı (uiautomator DEVAM ET/YÜKLE) `flutter drive` derlemesinden (~140 sn) KISA yaşarsa kurulum saatlerce bekler (Office A/B 3 sa 10 dk takıldı) → onaycı tüm koşu boyunca yaşamalı; uzun komuta `timeout` koy.
- 2026-11-08 · Okuyucu (izinsiz) derlemesi: `StoragePermission.readerBuild` → BLE `BleNearby.start` hiç izin istemez (unsupported; Wi-Fi/QR aktarım çalışır), Uygulamalar kutusu/dock girişi gizli, ekrana başka yoldan gelinirse `ia.reader_off` açıklaması. Yerel Faz 42 yedeği (`yedek/yerel-faz42`) uzaktaki Faz 42'nin 8 maddesince karşılandı (plan [x]) → silindi.

## 2026-11-08 — PDF Pro planı (Faz 51–68) → `docs/PDF_PRO_PLANI.md`
- **Kullanıcı isteği:** "piyasadaki en iyi PDF düzenleyici; basit/yarım iş yok, önce araştırma, istediğin sayıda faz". 6 sorun (PS1–PS6) ekran görüntüleriyle.
- **Kök nedenler (kodda):** PS1 `viewer/pdf_selection.dart:83` yalnız sayfa geçiriyor; PS2 `pdf_editor/actions.dart:186 _ocrEditable` logo gibi TEK görsel yüzünden doğal metne OCR "taranmış satır" açıyor → beyaz örtü + Carlito + punto `box.height/1.2` (ekrandaki minik "taşımak"), ayrıca alt küme fontta glif yoksa tüm paragraf Carlito/Tinos'a düşüyor ve düzenleme alanı hep Carlito çiziliyor (`pdf_object_layer.dart:487,559`); PS3 `pdf_save_dialog.dart:97` bildirim eylemi kapanmış editörün `context`'ini kullanıyor (küresel toast yaşıyor, `context.mounted` false → sessiz); PS4 `resizeToAvoidBottomInset: true` + her uygulamada tüm belgeyi baştan yükleme (`_syncDocument` → `PdfReload`); PS5 önizleme 34 karakterde kesik.
- **Karar (PK1, Faz 52 kapısına bağlı):** pdfium_dart 0.4.1 (pdfrx üzerinden zaten ağaçta, ek APK yok) tam düzenleme API'sini veriyor (`FPDFText_SetText`, `FPDFFont_GetFontData`, `FPDFPage_GenerateContent`, `FPDF_SaveAsCopy` + `FPDF_INCREMENTAL`, `FPDFAnnot_*`) → düzenleme görüntüleyicinin açık belgesinde, pdfrx işçisinde (PDFium iş parçacığı güvenli değil; ikinci izolatta paralel çağrı YASAK). Belge yeniden yüklenmez, yalnız sayfa önbelleği düşer. Karar kapısında geçemezse PK1-B: şimdiki Dart motorunun okuma tarafı PDFium karakter verisiyle güçlenir.
- **Korunan eski kararlar:** paragraf birimi (2026-07-27), özgün baytlara dokunmama (artımlı kayıt), PDF→Word→PDF reddi. Yeni: doğal metinde beyaz örtü YASAK; paragrafı sessizce başka fonta geçirmek YASAK (yalnız eksik glifler metrik uyumlu yedekle).

## 2026-11-08 — PDF Pro Faz 51: külliyat + tezgâh + kanamayı durdurma (dal `faz-51`)
- **Külliyat** `test/fixtures/pdf_corpus/` 68 PDF / 8 üretici (Word COM, Chrome headless, ReportLab, fpdf2, PyMuPDF, matplotlib, Dart `pdf`, Syncfusion); üretici `tool/pdf_corpus/make_corpus.py` + `dart_corpus_test.dart`. **TUZAK (KVKK):** Word PDF'in Yazar alanına Windows kullanıcı adını (PDF Info + XMP) yazıyor → üretici `BuiltInDocumentProperties` Author/Last Author/Company/Manager'ı ezer; yeni üretici eklerken `pymupdf .metadata` ile ad sızıntısına bak. LibreOffice/Google Docs/LaTeX/Quartz bu makinede yok → KALANLAR 👤.
- **Tezgâh** `tool/pdf_pro_bench.dart` (BenchEngine arayüzü — Faz 52'de 2. motor) + `test/pdf_pro/bench_test.dart` + taban bekçisi `test/pdf_pro/baseline.json`. Ölçüm PDFium'dan (motor bağımsız). CI: verify 0. parçada ayrı adım, apt `qpdf mupdf-tools`, `PDFIUM_PATH`. Taban: kapsama %63,6 · başarı %54,2 (aynı harf) / %34,2 (Türkçe harf) · Word 18 dosyada 0 paragraf → `docs/perf/2026-11-pdfpro-51-taban.md`.
- **Bug kökü (Word = 0 paragraf, PS2'nin asıl kaynağı):** Word her satırı `q … re W* n … BT…ET Q` kırpma bloğu + `BDC/EMC` ile sarıyor; Dart paragraf motoru kırpmalı blokları birleştirmiyor → 0 blok → editör sayfayı "taranmış" sınıfına alıp OCR'a düşüyordu.
- **Bug kökü (kilit açma):** `PdfTools.removePassword` izin bayraklarını temizlemezse Syncfusion şifreleme sözlüğünü yazmaya devam ediyor → sahip parolalı belge kilit açıldıktan sonra da şifreli (`permissions.clear()` eklendi). AES-256 (R6) Word kopyası kilit açılınca sayfasız çıkıyor → KALANLAR.
- **PS3:** kayıt bildirimi `openSavedPdf` = kök `navigatorKey` (kapanmış editörün context'i ölüydü); gövdeye dokunmak da açar; kayıt `rememberFile` + `FsEvents.changed`; `PdfEditorScreen.open` artık yazılan YOLU döndürür (bool değil) → kopyaysa görüntüleyici kopyayı açar.
- **PS4:** `EditorChrome(overlayKeyboard, freezeBody)` — gövde son ölçülen boyda dondurulur, çubuk klavyenin üstüne bindirilir; ağaç yapısı sabit (görüntüleyici yeniden kurulmasın). Office editörleri değişmedi (varsayılan kapalı). `_syncDocument` matrisi saklayıp geri koyar (yeniden yükleme PK2'de kalkar).
- **PS2/PK7:** doğal metin katmanı olan sayfada (pdfium metni ≥20 karakter, `outline.scanned` değil) OCR satırları yalnız görsel kutusunun içinde; motor okuyamadıysa nedeni söylenir + "OCR ile düzenle" (bilerek). Alan ailesi `PdfFontClass.previewFamily` (Calibri→Carlito, Arial→Arimo, serif→Tinos).
- **TUZAK (yerel test, Windows):** HAFIZA "Windows'ta PDFium testleri derlenmez" ESKİ: MSVC (VS 2026 Build Tools) kurulu ama kurulum "tamamlanmamış" (isComplete 0) → `vswhere -latest` boş döner, native_toolchain_c derleyici bulamaz. Çözüm: `C:\Users\sena\vsshim\vswhere.exe` (gerçek vswhere'i `-all` ile çağıran sarmalayıcı) PATH'in başına → `flutter test` PDFium'lu testler yerelde koşar (tezgâh 13 sn).
- **TUZAK (GitHub 504):** pdfium_dart kancası ikiliyi `releases/download`'dan çekiyor; uç 504 verince bütün testler "Building native assets failed". `tool/pdfium_onyukle.sh` (gh release download + actions/cache). Yerelde aynısı: `gh release download chromium/8125 -R bblanchon/pdfium-binaries -p pdfium-win-x64.tgz` → `.dart_tool/hooks_runner/shared/pdfium_dart/build/chromium_8125/win-x64/pdfium.dll`.
- **TUZAK (test):** bildirim (toast) testinde `pumpAndSettle` KULLANMA — 8 sn'lik ömür de kare sayılır, kart kapanır.
- **TUZAK (cihaz turu, PS4/PS5):** görüntüleyici okuma çubuklarının ARKASINA uzanıyor; `ReadingChrome.insetsOf(context)` görüntüleyici State bağlamında 0 dönüyor (sağlayıcı daha aşağıda) → örtü TAHMİN edilmez, `GlobalKey` ile çubuk + görüntüleyici kutusu ÖLÇÜLÜR. Klavye alan açıldıktan SONRA çıkar (Huawei IME) → kaydırma `didChangeMetrics`'te, ölçülen çubuk üst kenarına göre.
- **TUZAK (PS1):** Dart motorunun birleşik paragraf kutusu (ReportLab) yalnız ilk satırları kapsayabiliyor → seçim→paragraf eşlemesi kutu kesişimi + yedek metin eşleşmesi (`bestTextMatch`).
- **Cihazda sürücü:** `adb shell am start -a android.intent.action.VIEW -d file:///sdcard/... -t application/pdf -n com.dosyaokuyucu.dosya_okuyucu.r8test/com.dosyaokuyucu.dosya_okuyucu.MainActivity` belgeyi doğrudan açar; koordinatlar `uiautomator dump` (UTF-8) ile; Git Bash'te `MSYS_NO_PATHCONV=1` şart. Ekran görüntüsünde klavye önerisi kişisel e-posta gösterebilir → görüntüler depoya KONMAZ.

## 2026-11-08 — PDF Pro Faz 52: motor köprüsü + KARAR (dal `faz-52`)
- **KARAR (PK1, sayıyla):** PDFium nesne düzeyi düzenleme seçildi — kapsama %100 / %63,6, başarı %81,8 / %54,2 (aynı harf) ve %44,9 / %34,2 (Türkçe harf), gecikme p50 8 / 27 ms, bellek tepe +38 / +104 MB, işaretli içerik kaybı 0, qpdf/mutool 0 hata → `docs/perf/2026-11-pdfpro-52-motor.md`. **Koşullu:** prototip `pdf_pro_engine` bayrağında kalır; Faz 54'te (1) değişmeyen bölge piksel farkı 0 (ReportLab dahil) ve (2) büyüme p50 ≤ 4 KB sağlanmadan varsayılan olmaz. PK1-B (Dart motoru + PDFium okuma) REDDEDİLDİ: Word'de 0 paragraf kökü (kırpma blokları) okuma değil yazma tarafında; Dart yazıcı Word blokları için de yeniden yazılmak zorunda kalırdı.
- **Kök (PDFium sınırı):** `FPDFPage_GenerateContent` düzenlenen bloğu taşıyan içerik akışının TAMAMINI nesne modelinden yeniden üretir ve `Tw`/`Tc` metin durumunu YAZMAZ → aynı akıştaki dokunulmamış satırlar (ReportLab `-0.0917 Tw`) boşluk başına 0,09 pt kayar. Çözüm yolu Faz 54: hibrit (yeni nesne ayrı akışa, eski blok baytları Dart artımlı yazıcıyla akıştan çıkar).
- **Kök (büyüme):** artımlı kayıt sayfanın font sözlüğünü `/FXFn` takma adlarıyla ve gömülü FontFile2 akışlarını yeniden yazıyor (+36 KB p50/düzenleme).
- **Mimari:** `third_party/pdfrx_engine` yaması `computeOnIdleDocument(cb(pdfium, doc, msg), msg)` — PDFium işçisinde, pdfrx'in `_PdfiumIdleTask` çizim bekçisiyle (o belgenin etkin çizimi yokken). `useNativeDocumentHandle` ana izolatta, `compute` bekçisiz — ikisi de düzenleme için YASAK. PK2 için pdfrx'e yama GEREKMEDİ: `reloadPages([n])` → `PdfDocumentPageStatusChangedEvent` → görüntüleyici yalnız o sayfanın önbelleğini düşürür, matris aynı (widget testi).
- **Köprü kuralı:** yazdıktan sonra PDFium metin çıkarıcısıyla GERİ OKU (boşluklar dahil; PDFium'un ürettiği boşlukların nesnesi yok → aradakiler sayılır); tutmazsa eski nesneleri `FPDFPage_InsertObjectAtIndex` ile yerine koy + glif reddi. Eski nesneler doğrulamadan önce YOK EDİLMEZ (`RemoveObject` sahipliği verir).
- **TUZAK (widget testi + pdfrx):** sahte zamanda (a) `controller.setZoom` null patlar, `await goTo` bitmez → `controller.value =`; (b) köprü işi görüntüleyicinin çizim işleri bitmeden açılmaz → `runAsync(gecikme)` + `pump` döngüsü; (c) `doc.events` aboneliğinin `cancel()`'ı test sonunda beklenirse ASILIR → `unawaited(sub.cancel())`.
- **TUZAK (CI):** Linux `flutter_tester` pdfium_dart yerel varlığını yükleyemiyor ("Native assets file not found") → test adımında `PDFIUM_PATH` (önden indirilen libpdfium.so). GitHub releases 504 aynı gün media_kit jar indirmesini de kırdı (main APK) → yeniden koşu.

## 2026-11-08 — PDF Pro Faz 53: tasarım dili (dal `faz-53`)
- **Karar (maketler):** düzenleme = görüntüleyicinin kipi; üst çubuk (← · başlık + "Kaydedilmedi · N değişiklik" · geri al · yinele · dolgulu Kaydet · ⋮), alt 7'li araç çubuğu + bağlamsal ikinci çubuk, seçili bloğun üstünde koyu yüzen eylem çubuğu, klavye üstü biçim çubuğu ("belge" rozeti = gömülü font kullanılıyor), tablet/yatay: sol ray + (tablet) 320 dp sağ panel. Blok çerçevesi 3 kademe: dinlenme %14 vurgu 1 px · seçili 2 px + 4 tutamaç · düzenlenemez kesik turuncu (PK7). Artefakt https://claude.ai/artifact/PNjvf5wSp5ae2rY56RpNQW, kaynak `docs/design/pdf_pro/maket/`, sözleşme `etkilesim.md`.
- **Tokenlar:** `PdfEditTokens` (`app_colors.dart`): vurgu TEMADAN (`colorScheme.primary`), token yalnız roller/oranlar/ölçüler — kaplama (skin) değişince düzenleyici kendiliğinden uyar. Plan "AppHues içinde" diyordu; AppHues kimlik renkleri tablosu, ölçü taşımadığı için ayrı sınıf seçildi.
- **👤 onay kapısı bloklanmadı** (kullanıcı ekran başında değil, tasarım değişikliğine açık) → KALANLAR'da "maket onayı — itiraz varsa düzelt".

## 2026-11-08 — PDF Pro Faz 54 / 0: PK1 koşulları sağlandı (dal `faz-54`)
- **Sonuç (tezgâh):** değişmeyen bölge piksel farkı 54/400 → **0/0** (ReportLab dahil), büyüme p50 36,5 KB → **2,7 KB**, başarı %81,4 / %44,9 (5 dürüst ret). Taban `baseline_pdfium.json` + `growthP50Max` bekçisi.
- **Kök (kayma):** `FPDFPage_GenerateContent` metni `Tm Tf <..> Tj` yazar; `Tw`/`Tc`/`TJ` aralığı kaybolur → aynı akıştaki dokunulmamış satırlar kayar. PDFium'da ham akış yazma/okuma ve karakter KODU okuma API'si YOK (yalnız Unicode; `FPDFText_SetCharcodes` var ama okuyan yok) → hibrit "akıştan bayt çıkar" yolu bellek/kayıt tutarsızlığı doğurduğu için REDDEDİLDİ.
- **Çözüm (prova):** `FPDF_ImportPagesByIndex` ile sayfa geçici belgeye kopyalanır, düzenleme + `GenerateContent` orada; bağımsız `FPDF_LoadPage` ile yeniden ayrıştırılıp karakter kökenleri karşılaştırılır (`_drifted`): katı kayma → `FPDFPageObj_Transform`; içeride kayma → sözcük, olmazsa harf parçaları (her parça gerçek kökende, genişliği karakter kutusuyla doğrulanır, MCID kopyalanır). Düzeltilemiyorsa canlı belgeye HİÇ dokunulmaz → ret. Canlıda tek `GenerateContent`.
- **TUZAK:** üretilmiş akış PDFium'da geri alınamaz → eski "üret → doğrula → geri koy + yeniden üret" geri alması da kaydırıyordu. Glif doğrulaması artık akış ÜRETMEDEN (metin sayfası bellekteki nesnelerden kurulur) → ret kusursuz.
- **TUZAK:** `FPDFPageObj_GetClipPath` kırpmasız nesnede de nullptr DEĞİL döner; `FPDFClipPath_CountPaths` -1/0 → gerçek kırpma `> 0`.
- **Kök (büyüme):** PDFium artımlı kaydı yüklenmiş her nesneyi (font sözlüğü, FontFile2) yazar. `PdfIncrementalTrim` eki ayrıştırıp özgünle anlamca (anahtar sırası/sayı/dize yazımı/filtre bağımsız) aynı nesneleri atar, sıkıştırmasız akışları Flate'ler, `PdfFile.appendRawObjects` ile yazar. **TUZAK:** şifreli belgede kırpma bozuk çıktı verdi (PDFium eki kendi şifreleme sözlüğü/kimliğiyle) → şifreliye dokunulmaz (p95 büyümesi oradan).
- **RTL:** köprü Arapçayı soldan sağa, harf birleştirmesiz yazıyordu (geri okuma "doğru" diyordu) → açık ret (PK7) Faz 55/57'ye dek.
- **Bug kökü (2026-11-08, Faz 54/0 CI'da mutool 4 hata):** `PdfFile.parse` akış verisinin sonundaki 0x0A/0x0D'yi "endstream öncesi satır sonu" diye kırpıyordu; sıkıştırılmış verinin son baytı tesadüfen öyleyse veri kesik → zlib sağlama hatası. Artık doğrudan `/Length` (ardından yalnız boşluk + endstream) geçerliyse ona güveniliyor. Tezgâha `qpdfFail`/`mutoolFail` = 0 bekçisi eklendi. Yerel denetim: pymupdf `TOOLS.mupdf_warnings()` (mutool kurulu değil).

## 2026-11-09 — APK dışa aktarma + .apks kurulumu + sessiz oto AI
- **Bug kökü (.apks kurulmuyor):** `.apks/.xapk` FmCategory.apk → `openExternal` (ACTION_VIEW, MimeTypeMap bilmediği için `*/*`); sistem yükleyicisi ZIP kuramaz. Çözüm `ci/ApkKurulum.kt`: PackageInstaller oturumu, ZIP'teki her .apk yazılır; cihazın desteklemediği `split_config.<abi>` parçaları atlanır (en öncelikli tek ABİ), OBB kurulmaz. Bilinmeyen kaynak izni yoksa ayar açılır → `need_permission`. Sonuç onaydan SONRA döner (dinamik `RECEIVER_NOT_EXPORTED` alıcı + açık paketli FLAG_MUTABLE PendingIntent).
- **Karar (APK dışa aktarma):** menüde iki giriş — "paylaş / kaydet" sayfası (biçim, kayıt yeri seç, Kaydet ve paylaş / Yalnız paylaş / Yalnız kaydet) ve sorusuz "doğrudan kaydet" (parçalıysa .apks). Varsayılan kayıt yeri `İndirilenler/APK` (eskiden İndirilenler kökü).
- **Karar (oto AI sessiz):** `JobQueue.enqueue(silent:)` → sistem bildirimi/ön plan servisi/şerit/gelen kutusu yok, yalnız İşlemler geçmişi; AI simgesi halkası kalır. **Bedel:** ön plan servisi olmadığından arka planda Android otomatik turu dondurabilir (tur öne gelişte başladığı için kabul).

## 2026-11-09 — Aktarım sonucu/yüzde + Windows "Geliyor %" + oto güncelleme + reset hatası
- **Bug kökü ([async] SocketException errno 104, uzak port geçici → telefon SUNUCU):** istemci (Windows Gezgini/Dosya Aktar) bağlantıyı sıfırlayınca yanıtın/soketin `done` future'ı hata ile bitiyor, dinleyen olmadığı için kök zona düşüyordu. Çözüm: FTP kontrol + veri soketinde `socket.done.ignore()`, veri kapatma `_closeData` (try/catch + destroy); `PeerReceiver`, `HttpShareServer`, QR sunucusunda `request.response.done.ignore()`; gönderende `request.done.ignore()` (iptalde abort). **Kural:** yeni sunucu/soket yazarken `done`'u mutlaka dinle.
- **Gönderilenler geçmişi:** `TransferRecord` + `ok`/`percent`/`duration` (JSON `ok`,`y`,`d`; eski kayıt = başarılı, alanlar null). Artık başarısız/iptal denemeler de yazılır; satırın 2. satırı "✓ Başarılı · %100 · 1 dk 5 sn" (kırmızı ✗ başarısızda). Yüzde dosya kalemi adından (`out.files[basename]`), paketlenmiş küçük dosyalarda genel yüzde.
- **Windows exe:** alırken mavi "⬇ Geliyor %X" rozeti + çubuk + pencere başlığı + görev çubuğu ilerlemesi (ITaskbarList3, yoksa sessiz); gönderirken "⬆ X cihazına gidiyor %"; bitişte "Başarılı/Başarısız %· süre". **Linux'ta derlenir:** `apt-get install dotnet-sdk-8.0` + csproj'a `Microsoft.NETFramework.ReferenceAssemblies` eklendi → `dotnet build -c Release` (exe `tool/pc_aktar/exe/`'ye kopyalanır).
- **Oto güncelleme (`lib/services/app_update.dart`):** açılış kuyruğunda ≤6 saatte bir `releases/latest` (kişisel derleme `tags/kisisel`, `--dart-define=DOSYA_KISISEL`), `dosya-okuyucu-v<sürüm>.apk` yeniyse önbelleğe iner; kurulum bir SONRAKİ açılışta ya da "Şimdi güncelle" ile (iş ortasında süreç ölmesin). `ApkKurulum.install(selfUpdate)` tek .apk'yı oturuma yazar, Android 12+'da `USER_ACTION_NOT_REQUIRED` ister — sistem yalnız uygulama kurulumun sahibiyse onaysız kurar; ilk sefer (tarayıcıdan kurulmuşsa) onay penceresi ÇIKAR. Vazgeçilen sürüm açılışta yeniden sorulmaz. Atlanır: çevrimdışı, ayar kapalı, yama 0, `okuyucu` derlemesi. Ayar: Hakkında › Güncellemeler.

## 2026-11-09 — Önemli Dosyalar kategori + galeri, Aktar'da yapıştırma alanı
- **Karar (kategori):** kategori = Önemli Dosyalar'ın gerçek alt klasörü (ayrı veritabanı yok). Ekranda ⋮ ile yeniden adlandır/sil (silmede onay her zaman). `copyToImportant` → `pickImportantCategory`: alt klasör varsa "Genel / kategoriler / Yeni kategori" levhası, yoksa soru çıkmaz.
- **Galeri:** Önemli Dosyalar'da tüm dosyalar `FmEntryIcon` küçük resmiyle ızgarada (tür çipleri, ilk 24 + "Tümünü göster"), dokununca kardeşleriyle açılır.
- **Aktar (Yakındakiler):** seçim kartında kalıcı `TextField` (`_textCtrl`, `_text` aynası); `contentInsertionConfiguration` ile klavyeden görsel/GIF → geçici klasöre dosya → seçime eklenir. Sistem panosundaki yazı açılışta/öne gelişte yoklanır → "Panodan ekle" çipi; uygulama içi kopyalanan dosyalar → "Kopyalanan N dosyayı ekle" çipi. **Bedel:** Android 12+ her yoklamada "panodan yapıştırıldı" bildirimi gösterebilir. Flutter `Clipboard` sistem panosundaki GÖRSELİ okuyamaz; görsel yalnız klavye yoluyla gelir.
- **Windows exe:** Ctrl+V / "Panodan yapıştır" düğmesi: dosya listesi doğrudan, görsel PNG, yazı .txt olarak gönderilir; pencere öne gelince düğme panodakini yazar. Linux'ta `dotnet build` ile derlendi, exe güncellendi.

## 2026-11-10 — Tarama netliği/eğim/Kaydet, dinamik Hz, Önemli Galeri, sürüm notları
- **Bug kökü (eğik uyarısı ↔ "zaten düz"):** uyarı `ScanQualityCheck.estimateSkew` (kaba eşik, resim ayıklaması YOK — masa/fotoğraf dokusunu satır sanıyordu), Düzleştir düğmesi `ScanDewarp.straighten` (resim maskesi + mürekkep oranı kapıları) — iki ayrı kestirici. Artık uyarı `ScanDewarp.measureSkew` ile, düğmeyle AYNI kapılardan ölçülür; eski `estimateSkew` silindi. **Kural:** öneri gösteren her uyarı, eylemin kendi ölçümünü kullanmalı.
- **Netleştirme:** tek geçişli maske (r=1, 0,8) 2480 px'te görünmüyordu → `ScanEnhance.sharpenText`: ince (r1 ×0,9) + orta (r2 ×0,7) fark, gürültü eşiği (3/4), hale sınırı (3×3 min/max ±10). Ölçekten bağımsız bulanıklık ölçüsü denendi (yüksek/orta frekans oranı) — gürültüde tekdüze değil, REDDEDİLDİ; sabit güçlü + hale sınırı seçildi.
- **Karar (tarama sonrası):** alt sağ düğme "PDF'i aç" → **Kaydet**: son yazım beklenir, tarama ekranı `pushReplacement` ile klasöre (BrowserScreen.focusPath, mevcut çerçeveli vurgu) döner + "kaydedildi" bildirimi. "PDF'i aç" ⋮ menüde kaldı.
- **Dinamik tazeleme:** `DynamicRefresh` (display_mode.dart) — global işaretçi rotası; dokunma/kaydırmada `setHighRefreshRate`, 3 sn boşta `setLowRefreshRate` (cihazın en düşüğü: 60/48/30). Video ve otomatik kaydırma `ScreenAwake.request(motion: true)` ile yüksek hızı TUTAR. Ayar `perf_dynamic_refresh` (varsayılan açık), yalnız "Yüksek tazeleme" açıkken etkin. **Bedel:** bazı ROM'larda mod geçişinde tek karelik takılma olabilir — olursa idleDelay büyütülür.
- **Önemli Galeri:** ana ekran kutusu `important_gallery` (Önemli Dosyalar'ın yanında) → `ImportantGalleryScreen`; süzgeç modeli saf `important_gallery_filter.dart` (ince tür 12 + 3 grup, alt klasör, dosya ADI+klasör adından DocClass konusu — içerik okunmaz, etiket, zaman/boyut kovaları, 4 sıralama, ad araması). Boyut içinde VEYA, boyutlar arası VE; kutu sayısı "yalnız bunu seçersem". Önemli Dosyalar ekranında önizleme 12 + "Galeriyi aç".
- **Sürüm notları:** commit gövdesinde `Yeni:/İyileştirme:/Düzeltme:` satırları (CLAUDE.md §4) → `tool/surum_notu.sh <önceki sürüm sha>` (nightly/kisisel etiketi taşınmadan ÖNCE okunur; v* → önceki v*), satır yoksa arındırılmış başlıklar. Not `<!-- notlar -->` arasında; `AppUpdate.extractNotes` bunu indirilen sürüm için saklar, kurulumdan sonraki ilk açılışta "vX — Yenilikler" penceresi bir kez çıkar.
- **Bug kökü (oto güncelleme "en son sürüm kurulu" diyordu, 2026-11-10):** `apk` işinin artifact'i yalnız `dist/dosya-okuyucu.apk` yüklüyordu; `dosya-okuyucu-v<sürüm>.apk` Release'e HİÇ gitmedi, `pickAsset` onu aradığı için yeni sürümü göremiyordu. Artifact iki adı da yükler; `pickAsset` yedek olarak başlıktaki `v<sürüm>` + sabit adı kullanır. 1.2.9–1.2.12 kurulu cihazlar bu düzeltmeden sonraki ilk sürümü kendiliğinden bulur.

- **Karar (Aramadan açılanlar, 2026-11-10):** arama sonucundan açılan dosya `SearchHistory.recordOpened` ile `search_opened.json`'a (en çok 60, yol tekil, en yeni üstte, sorgu + zaman). Arama kutusu boşken "Son aramalar"ın altında liste + tür çipleri (FmChip); silinmiş dosya gösterilmez ama kayıttan düşmez.

## 2026-11-10 — Güvenlik planı (G0–G12)
- **Karar:** güvenlik işleri `docs/GUVENLIK_PLANI.md` fazlarıyla (`faz-GN` dalı + PR). Kod okunarak 18 bulgu (B1–B18): uzak sunucu + FTP parolaları prefs'te düz, `allowBackup` açık, `MainActivity` `dosya_link` eki doğrulanmıyor (şüphe), yerel sunucular `0.0.0.0` + 4 haneli güvensiz eşleştirme kodu, Word WebView'da CSP/gezinti kilidi yok, Gemini anahtarı URL'de, PBKDF2 120k, Action'lar SHA'ya sabit değil.
- **Reddedilen (şimdilik):** root/hata ayıklayıcı tespiti, sertifika sabitleme, ücretli pentest — korunacak sunucu sırrı/ücretli içerik yok; Pro gelince yeniden bakılır.
- **Sınır:** cihazda sızma testi yapılmadı; "ÖNCE DOĞRULA" işaretli maddeler varsayım.

## 2026-11-10 — Üç sürüm kararı (Lite / Pro / Kişisel)
- **Karar (kullanıcı):** Lite = ücretsiz reklamsız okuyucu (izinsiz okuyucu derlemesi tabanı; oku + ara + form doldur + imza + yazdır/paylaş), Pro = ayrı ÜCRETLİ uygulama (düzenleme, PDF araçları, tarama, dosya yöneticisi, aktarım, kasa, AI, sesli kitap), Kişisel = GitHub, deneysel + Play dışı (APK kurma, yüklü uygulamalar, oto güncelleme, indirme yöneticisi, Drive tam kapsam, FTP sunucu). Ayrıntı `docs/SURUM_PLANI.md`.
- **Sonuç:** uygulama içi satın alma (K6'nın Billing kısmı, A6.5) düştü; tek kapı `Edition`/`Feature` tablosu olacak. Yeni özellik önce Kişisel'e girer.
- **Bedel:** iki mağaza kaydı, Lite verisi Pro'ya kendiliğinden geçmez (dışa/içe aktarma ile).

- **Karar (ana sayfa güncelleme şeridi, 2026-11-10):** `UpdateBanner` (widgets/update_banner.dart) panonun en üstünde, kapatılamaz. `AppUpdate.available` = GitHub'da bulunan yeni sürüm (inmemiş olabilir); `AppUpdate.detect()` açılışta + öne gelişte en çok 30 dk'da bir sorar (eski 6 saat sınırı kalktı; oto güncelleme kapalıyken de duyurur, yalnız indirmez). Dokununca `downloadAndInstall` → indir (yüzde çubuğu) + sistem kurucusu. **Bedel:** her açılış/öne geliş ≤30 dk'da bir GitHub API çağrısı (kimliksiz kota 60/saat/IP).

- **Karar (Kasa görünümü, 2026-11-10):** `VaultScreen` açıkken Önemli Dosyalar düzeninde: özet kart (N dosya · boyut), "Türlere göre" `FmCategoryGrid` (dokununca galeri o türe süzülür), çipli galeri (`ImportantGalleryTile` + kilit rozeti; basılı tut = eski menü). Küçük resim için yalnız görsel/PDF ≤15 MB `openTemp` ile SIRAYLA geçici düz kopyaya açılır (kilitlenince silinir). **Bedel:** kasa açıkken bu dosyaların düz kopyası önbellekte durur (önceden yalnız açılan dosya); büyük kasada açılışta şifre çözme yükü.

## 2026-11-10 — Elle ikinci ad, AI ad canlı kartı, galeri seçimi, güncelleme yalnız dokununca
- **Karar (ikinci ad):** `AiRecord.alias` (json `al`) = elle verilen ad; `aliasOf` önce onu, yoksa AI `title`'ı verir. `AiIndex.putAll` gelen kayıtta alias boşsa eskisini KORUR (toplu yeniden analiz elle adı ezmez). Dosya menüsünde "İkinci ad ver" (`editAlias`). "AI ile ikinci ad" bilerek AI'dan istendiği için bitince elle adı siler; süreçte kalıcı kart, bitince "Şu adı koydum: X · Değiştir" (`AiAnalyzer.whenIdle`, 5 dk zaman aşımı).
- **Önemli Galeri:** basılı tut = seçim kipi (çerçeve + onay rozeti), üstte sayaç/tümünü seç, altta ortak `FmSelectionBar`; geri tuşu önce seçimi kaldırır.
- **Karar (güncelleme, kullanıcı):** açılışta İNDİRME/KURMA YOK — `runOnStartup` yalnız denetler (ayar "Yeni sürümleri haber ver" kapalıysa hiç sormaz); indirme+kurulum yalnız şeride/Ayarlar'daki "Güncelle"ye dokununca. Ayarlar'da "Denetle" artık yalnız sorar.
- **Kurulumdan sonra yeniden açılış:** `GuncellemeSonrasi` (ci/ApkKurulum.kt) `MY_PACKAGE_REPLACED` alır; işaret (`selfUpdate` kurulumu, ≤30 dk) varsa ana ekranı açar. **Bedel/sınır:** Android 10+ arka plandan ekran açmayı yalnız "diğer uygulamaların üstünde göster" izniyle bırakır; izin yoksa "Güncelleme kuruldu — açmak için dokunun" bildirimi düşer (cihazda doğrulanmadı).
- **Bug kökü (2026-11-10, kullanıcı: "Diğer uygulamaların üzerinde göster listesinde çıkmıyor"):** manifestte `SYSTEM_ALERT_WINDOW` HİÇ bildirilmemişti (yalnız OKUYUCU_REMOVE listesinde adı vardı) → sistem listesinde uygulama yoktu, yeniden açılma hep bildirime düşüyordu. İzin eklendi + Ayarlar › Güncellemeler'de "Güncellemeden sonra kendiliğinden aç" satırı (durum + izin sayfası, `canDrawOverlays`/`openOverlaySettings`).

## 2026-11-11 — PDF Pro Faz 54 / 1–6: düzenleme oturumu + tek yüzey + artımlı kayıt (dal `faz-54`)
- **Karar (geri al):** komut başına yalnız o sayfanın anlık görüntüsü = sayfanın geçici PDFium belgesine kopyası (`FPDF_ImportPagesByIndex`); geri al kopyayı aynı sıraya ekler, eski sayfayı siler (`FPDFPage_Delete`) → piksel piksel aynı (test). Ters işlemle geri alma (eski metni yeniden yazmak) REDDEDİLDİ: `GenerateContent` `Tw`/`TJ` aralığını yazmadığı için özgün dizgi geri gelmez. `PdfEditSession` (`lib/services/pdf/pro/`), duruma bakan sayfa bazlı kirli izleme.
- **TUZAK → karar (kayıt):** geri konan sayfa belgede YENİ nesnedir; eski sayfaya nesne numarasıyla bakan yer imi/bağlantı/etiket kayıtta boşa düşerdi. Bu yüzden bir geri al/yinele olmuş oturumda kayıt canlı belgeden DEĞİL: açılış baytları ayrı belge olarak açılır, kalan komutlar (`PdfEditOp`, günlüğe de yazılan aynı nesne) sırayla yeniden oynatılır (`PdfEditSaver.encode`). Bedel: o kayıt komut sayısıyla orantılı sürer.
- **Karar (kayıt tabanı):** PDFium belleğindeki belge AÇILDIĞI baytlara dayanır; her kayıt "açılış baytları + bugüne kadarki değişiklikler"dir. İlk üzerine yazmadan önce açılış baytları geçici dosyaya kopyalanır (kırpma tabanı). Oturum kapanınca, özgünün üstüne kaydedildiyse görüntüleyici belgeyi diskten yeniden okur — yoksa sıradaki oturumun tabanı diskle tutmaz. **TUZAK:** PDFium dosyayı tembel okur; `SafeWrite` yeniden adlandırmayla yazdığı için açık tanıtıcı eski dosyada kalır (güvenli). Geçici dosya açılamayan klasörde doğrudan yazma yoluna düşülürse okuma/yazma yarışı olasılığı var (cihazda görülmedi, ölçülmedi).
- **Sürüm geçmişi:** `PdfVersionHistory` — uygulama destek dizininde yolun SHA-1'iyle klasör, 14 gün + belge başına 20 sürüm; her Kaydet dosyanın tam kopyasını koyar (bedel: büyük PDF'te depolama = sürüm sayısı × boyut).
- **Çökme kurtarma:** `PdfEditRecovery` — günlük = son kayıttan sonraki işlemler + diskteki dosyanın boyu/değişme anı; açılışta tutuyorsa yeniden oynatılır (yine geri alınabilir), tutmuyorsa 30 sn'lik geçici artımlı kayıt Belgeler'e kopya olur. Eski `services/fm/pdf_edit_journal.dart` (özgünü geri yazan günlük) eski yolun; ikisi ayrı.
- **Şifreli:** karar izin bayrağından (Tablo 22 bit 4 = 8; pdfrx `PdfPermissions` adları bu bitle örtüşmüyor, ham değer kullanıldı). Sahip parolası, belge o parolayla AYRICA açılıp izne bakılarak doğrulanır; açık belge yeniden yüklenmez (PDFium düzenleme API'si izin bitini uygulamaz — kısıt bizim politikamız).
- **Tek yüzey:** bayrak `pdf_pro_engine` açıkken "Düzenle" `ViewerScreen` kipidir (`viewer/pdf_pro_edit.dart`, `widgets/pdf_pro/`); gövde boyu/çubuk payı değişmesin diye alt çubuk yerinde kalır, çubuklar sabitlenir. `PdfEditorScreen` bayrak kapalıyken hâlâ tek yol — silinmesi bayrak varsayılan olunca.
- **Bekçi tuzakları (CI'da yakalandı):** `try` içinde `return gelecek;` → `unawaited_return_in_try_block`; hiçbir ekrandan içe aktarılmayan `lib/` dosyası `reachability_test`'i kırar (servis commit'i tek başına yeşil olmaz); ham `HapticFeedback` yasak (`AppHaptics`).

## 2026-11-11 — Güvenlik Faz G0: denetim betiği + envanter
- **Karar:** `tool/guvenlik_denetimi.sh` (9 kural, Flutter'sız) CI `verify` 0. parçada her dalda koşar. `BEKLEYEN="3 4 6"` uyarı kipinde: 3 → G2.4 (Gemini `?key=`), 4 → G1 (`allowBackup=false`), 6 → G9.1 (Actions SHA). Faz bitince numara listeden ÇIKARILIR (yoksa kural hiç kırmızı olmaz).
- **Karar:** izin listeleri (Random, exported bileşen, bind, JS) betiğin başında; yeni giriş gerekçeli olmalı, `docs/guvenlik/ENVANTER.md` ile birlikte güncellenir. `peer_share.dart` Random() girişi GEÇİCİ (G4.2'de kalkar).
- **Tuzak:** manifestte `exported="true"` metni yorum satırlarında da geçiyor — grep yanıltır; betik XML'i `xml.etree` ile ayrıştırır (yorumlar düşer). Ayrıca `docx_fonts.dart` tohumlu `Random(seed)` kullanıyor (yalnız seed≠0; varsayılan `Random.secure()`), listeye alındı.
- `SECURITY.md` bildirim e-postası yer tutucu: 👤 depo sahibinden adres gerekli (KALANLAR).

## 2026-11-11 — Güvenlik Faz G1: Android platform sertleştirme
- **Karar:** `allowBackup=false` + `data_extraction_rules` (bulut+cihaz aktarımı) ; `dosya_link`/kısayol yolu eki HMAC-SHA256 imzalı (`Extras.EXTRA_SIG`, anahtar `filesDir/link_key`). İmzasız: yalnız `app:` bağlantısı (statik kısayol XML'i imzalanamaz) ve özel dizin dışı yol (eski sabitlenmiş kısayollar kırılmasın). Dart tarafı `isSafeLinkPath`/`isAllowedAppLink` beyaz listesi (`..`, `/data`, `Android/data`, kasa klasörleri red).
- **Karar:** `FLAG_SECURE` sayaçlı tek kapı `SecureScreenGate`/`SecureScreen` (kasa, PIN, uygulama kilidi, AI anahtarı, uzak parola); kasadan açılan görüntüleyici VaultScreen altta olduğu için kendiliğinden kapsanır.
- **Doğrulandı, DEĞİŞMEDİ:** `host="*"` süzgeci indirme bağlantısı özelliği (zaten uzantı kalıplı); `file://` süzgeçleri (eski dosya yöneticileri); `requestLegacyExternalStorage` (Android 10); `FLAG_MUTABLE` PendingIntent'ler (PackageInstaller/UsbManager şart, setPackage var); `RECEIVER_EXPORTED` USB/medya sistem yayınları.
- **Tuzak:** Play izin çıkarma listesi iş akışında zaten vardı; `REQUEST_INSTALL_PACKAGES`/`PACKAGE_USAGE_STATS` çıkarmak özellik gizleme ister → G1 artığı (KALANLAR). Denetim kural 4 hata kipine alındı.

## 2026-11-11 — Güvenlik Faz G2: sırlar (diskte, ağda, logda)
- **Karar:** uzak sunucu parolaları `RemoteSecrets` (services/remote_secrets.dart): `fm_remote_connections` PAROLASIZ, `{id: parola}` KeyVault ile sarılı `fm_remote_secrets`. FTP sunucu elle parolası `ftpd_password_sealed`; rastgele kipte parola diske YAZILMAZ. Eski düz kayıtlar açılışta göç eder (test: `remote_secret_migration_test`, `ftpd_password_migration_test`). Keystore yoksa düz yol + bağlantılar ekranında uyarı (`remotePasswordsUnprotected`).
- **Karar:** Gemini anahtarı `x-goog-api-key` başlığında (`GeminiService.debugClient` testte sahte istemci); denetim kural 3 hata kipinde (`BEKLEYEN="6"`).
- **Bug kökü (G2.3):** `SettingsBackup.secretPrefixes` `gemini_key`/`ai_api_key` önekleri asıl kayıtları (`gemini_api_key*`) kapsamıyordu → AI anahtarı ayar yedeğine giriyordu. Önek + G2 sırları eklendi; bağlantı JSON'undaki `password` dışa/içe aktarımda sökülür.
- **Karar:** `LogScrub.scrub` ortak (DiagReport.scrub delege); `CrashLog.record` diske yazmadan önce uygular. **Tuzak:** testte sahte Google anahtarı parçalardan kurulmalı (`'AI' 'za${'x' * 35}'`; `+` ile birleştirme lint'e takılır), yoksa denetim kural 9 depoyu kırmızı yapar.


## 2026-11-11 — A4.4 senkron G/Ç azaltma (87 → 50) + cırcır
- **Karar:** `test/sync_io_ratchet_test.dart` lib/screens + lib/widgets'taki `*Sync(` çağrılarını sayar, tavan 50 (yalnız iner). Kitaplık boyut/eksik bilgisi `_statBooks` ile arka planda (kitaplık değişince tazelenir); "eksikleri temizle" artık bu önbelleğe bakar.
- **Tuzak (yine §F):** asenkron `exists()/stat()` widget testinin sahte saatinde tamamlanmaz → testin doğrudan koşturduğu açılış yolları SENKRON bırakıldı, gerekçe yorumuyla: `HomeScreen._openStartFolder` (fm_start_folder_test), `ImportantScreen._load` (a11y testi). Dönüştürmeden önce `grep -rlw <Ekran> test` ile bak; testi `runAsync` döngüsüyle bekleyenler (job_report_test `settle`) güvenli.
- `if (!dir.existsSync()) await dir.create(recursive: true)` → yalnız `await dir.create(recursive: true)` (var olan klasöre dokunmaz).

## 2026-11-11 — Güvenlik Faz G3: kasa, PIN, uygulama kilidi
- **Karar (G3.1):** PBKDF2 600 bin tur. Saf Dart (pointycastle) çok yavaş (120 bin turda bile bir test 7 türetmede 30 sn'yi aştı) → türetme `PinKdf` ile Android `PBKDF2WithHmacSHA256` (yerel, arka izlek, Android 8+); yalnız ASCII PIN'de (char→bayt sağlayıcıya göre değişebilir). Yedek saf Dart: ≤ 20 bin tur yerinde (widget testinin sahte saatinde tamamlanır), üstü `Isolate.run`. RFC 7914 vektörü `vault_crypto_kat_test`te.
- **Karar:** testler `SecureVault.targetIterations` / `FolderLock.targetIterations` = 1000 kurar — **TUZAK:** yeni bir test kasa kurar ya da PIN ayarlarsa bunu yapmalı, yoksa 600 bin tur saf Dart'ta dakikalar sürer / sahte saatte asılır.
- **Karar (G3.2):** tek ortak, kalıcı yanlış PIN sayacı `pin_fail_count`/`pin_fail_at` (`PinBackoff`) — kasa, uygulama kilidi, PIN penceresi aynı PIN'i kullandığı için. 5 serbest → 30 sn → ×2 → en çok 1 sa; saat geri alınınca bekleme baştan. Widget testinde saat `PinBackoff.debugClock`.
- **Karar (G3.3):** `fm_lock_pin` biçimi `v2:<tur>:<tuz>:<özet>`; doğrulama `AppState.verifyLockPin` (async; v1/az turlu → doğru PIN'de v2'ye yazılır). `FolderLock.verify` yalnız v1 için kaldı.
- **Karar (G3.4):** kasa parmak izi ayrı Keystore anahtarı `dosya_vault_bio_v2` (`setUserAuthenticationRequired` + `setInvalidatedByBiometricEnrollment`, `BiometricPrompt.CryptoObject`), kayıt `vault_bio_key2`. Eski `vault_bio_key` (doğrulamasız `dosya_vault_key` ile sarılı → parmak izi yalnız arayüz kapısıydı) OKUNMAZ; PIN'le açılışta silinir ve parmak izi yeniden kurulur. `dosya_vault_key` (Gemini/uzak parolalar `KeyVault`) DEĞİŞMEDİ.
- **Dürüst sınır:** 4–6 haneli PIN'de 600 bin tur çevrim dışı kaba kuvveti yalnız yavaşlatır (10^4 olasılık); `vault.json` paylaşılan depolamada. Asıl koruma PIN uzunluğu — kullanıcıya söylendi.
- G3.5 `vault_autolock_secs` (0/30/60/300), dönüşte geçen süreye de bakılır. G3.6 metinler zaten dürüsttü (değişiklik yok).

