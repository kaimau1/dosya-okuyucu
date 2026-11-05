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
- **PDF:** görüntüleme pdfrx 1.3.x (pdfium) + kendi seçim katmanı; yazma Syncfusion 31.1.19
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
- **Bulut oturumu:** Flutter 3.44.6 Linux tarball'ı indirilebilir
  (`storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_3.44.6-stable.tar.xz`),
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
- **pdfrx 1.3.5:** görüntüleyicinin boyunu jest sırasında değiştirme (sayfa başına atlar);
  `layoutPages` aynı girdide eşit düzen döndürmeli; yakınlaştırmada basamaklı çizim ölçeği;
  çok sütunda `useAlternativeFitScaleAsMinScale` kapalı. (2.x'e geçiş KALANLAR A3.2.)
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
  (compileSdk 30, derlemeyi kırıyor) · **pdfrx 2.x** (2.4.8 denendi, 2026-11-03'te geri alındı:
  yoğun PDF'te açılış çok geç, kaydırma ~5 FPS — ayrıntı 2026-11-03 kaydı; tekrar denenecekse önce
  cihazda o PDF'le profil ölçümü).

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
