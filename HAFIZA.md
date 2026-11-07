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
