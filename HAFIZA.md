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

## 2026-11-01 — Kalan işler iki fazda toplandı; HAFIZA, KALANLAR, CIHAZ_TESTI temizlendi
Kullanıcı: *"bütün kalan işleri tara, başka eksikleri de belirle, eski fazlardan her şeyi
toparla; 1. bulutta yapılabilecekler 2. diğerleri — iki faz; eksik ufak şey kalmasın; hafızayı
ve kalanlar dosyasını temizle; main'e merge et."* Kod değişmedi.
- **`KALANLAR.md` baştan:** Faz A ☁️ (A1 hijyen … A9) / Faz B 📱💻👤 (B1 yerel … B6 sürüm);
  biten [x] maddeler silindi, bilinçli sınırlar ayrı bölümde, açılış istemleri sonda. Eski metin
  `docs/arsiv/KALANLAR_2026-10-31.md`. **`docs/CIHAZ_TESTI.md`** alana göre yeniden (§1 ölçüm
  tablosu, §13 Office uyumluluk tablosu); kaldırılan akışlar çıktı; eski metin
  `docs/arsiv/CIHAZ_TESTI_2026-10-31.md`. FAZ_PLANI / DUZENLEME_PLANI durum ve karar
  tabloları güncellendi (K13, K15, K16, K19–K22, K24, K25 karar sütunları boştu).
- **Yeni bulgular (kod taraması):** (1) pubspec'te "CI 3.29.3 / Dart 3.7" diye sabitlenmiş ~12
  paket — CI 2026-10-21'den beri 3.44.6; pdfrx 2.x artık mümkün (A3). (2) main'den erişilemeyen 3
  dosya: `qr_share_screen.dart` (10-29'da paylaş seçimi daralınca koptu), `pdf_font_class.dart`,
  `pdf_text_stamp.dart` (A2). (3) Play izin beyanında Yakındakiler'in yeni izinleri ve
  `QUERY_ALL_PACKAGES` yok; gizlilik/veri güvenliği metni kaldırılan "Anılar"ı anlatıyor (A6).
  (4) 800+ satırlı 5 ekran (Faz 3 ölçütü geriledi), 166 boş `catch`, ekran kodunda 51 senkron
  G/Ç (A4). (5) `ProGate`/Billing iskeleti ve `integration_test` senaryoları hiç yazılmamış
  (A6.5, A8.1). (6) Arşiv çıkarmada iptal yok (A7.3). (7) "JPEG kodlayıcı yok" engeli kalktığı
  için agresif PDF sıkıştırma yolu açıldı (A7.4).
- **Uzak dallar:** main dışında 64 dal; 16'sı main'e girmiş, 46'sının main'le ortak atası yok
  (main geçmişi bir ara yeniden yazılmış), `ccr-4fb1643b` #52 ile squash girmiş; **bugün açılmış
  `ccr-0ba9d97d-1mtuwm` main'de olmayan 2 CI commit'i taşıyor** (kişisel ön-sürüm) — kullanıcıya
  soruldu, dokunulmadı → kullanıcı onayıyla aynı gün main'e alındı (aşağıdaki kayıt).
- **CI süresi** (Faz 1'in "önbellek dolunca yeniden ölç" notu): main koşuları #440–444 ≈ 9–12 dk.
- **Tuzak:** son tur kayıtları `- **2026-…**` madde biçiminde yazıldığı için
  `tool/hafiza_arsivle.py` (yalnız `## YYYY-MM-DD` başlıklarını taşır) onları göremedi, dizin
  892 satıra çıktı → tarihli kayıt başlıkla yazılır (yukarıdaki kural).

## 2026-11-01 — Kişisel derleme Release'e çıkar (dal `ccr-0ba9d97d-1mtuwm` main'e alındı)
Kullanıcı isteği: *"indirebileyim"*; aynı gün başka oturumda yazıldı, kullanıcı *"o dalı da al
main'e"* deyince birleştirildi. Elle tetikleme `kisisel: true` → ayrı **`kisisel`** ön-sürümü
(prerelease, `--latest=false`; etiket her koşuda o commit'e taşınır, APK üzerine yazılır).
`nightly` ve `releases/latest/download/dosya-okuyucu.apk` DEĞİŞMEZ; budama `kisisel`i de atlar.
Herhangi bir daldan; elle tetikleme yoksa commit mesajına `[kisisel]` yazıp push etmek de aynısını
yapar. İndirme: `releases/download/kisisel/dosya-okuyucu.apk`. (Özgün kayıt madde biçimindeydi,
birleştirmede yeni dizin biçimine taşındı.)

## 2026-11-01 — Uygulama içi seçici, düzenleme dönüşü, dock, kırık beyaz
- **Paylaş "dosya seç" = sistem DocumentsUI** (adb: bizim uygulama `OPEN_DOCUMENT` başlatıyordu, `file_picker`).
  Artık tüm `FilePicker.platform.pickFiles` çağrıları `AppFilePicker.pickFiles` (pick_file_screen.dart) —
  aynı imza/`FilePickerResult`, arayüz bizim `PickFileScreen` (uygulama içi kip: `request` dolu → `Navigator.pop`).
  İzin yoksa / "Diğer kaynaklar" → sistem seçicisi. `getDirectoryPath` hâlâ sistemde.
  Sınır: başka uygulama `OPEN_DOCUMENT` çağırırsa araya girilemez; yalnız `GET_CONTENT` (PickerActivity) bize gelir.
- **Slayt düzenle→bitir başa atlıyordu — kök:** düzenlerken gövde `_focusEditor()` ile DEĞİŞİYORDU, liste (`_vCtrl`)
  sökülüp dönüşte offset 0 ile yeniden kuruluyordu. Çözüm: liste `Offstage`+`TickerMode` ile ağaçta kalır,
  `Stack(fit: expand)` (gizli liste 0×0 ölçülür, expand şart — yoksa odak editörü 0×0, test yakaladı).
  Düzenlenen kutu `_flashRect` ile ~1,3 sn çerçevelenir.
- **Word:** çıkışta akış→sayfa geçişi kaydırmayı atıyordu; imleç paragrafı önce okunur, `focusPara(i)` (viewer.html)
  ortalar + çerçeveler. Mobil editör dönüşü yeniden çizer → `_resumePage` ile aynı sayfa.
- Dock: QR → Aktar (QR alma Yakındaki cihazlar içinde), Belge Tara yalnız simge. Kırık beyaz zemin F6F3EA→FAF8F2.
- **Kitaplık (2026-11-01):** `LibraryStore` (appSupport/`library.json`, yalnız yol listesi — dosya taşınmaz;
  kayıp dosya soluk + "bulunamadı", sessizce düşürülmez) + `LibraryScreen` (raf görünümü, "Okumaya devam et"
  `ReadingPositions.progressOf`'tan, kapak: PDF ilk sayfa / EPUB OPF cover-image / yoksa çizilmiş kapak).
  Girişler: pano kutusu `id: 'library'`, dosya menüsünde "Kitaplığa ekle/çıkar", ana ekran kısayolu `app:library`
  (`openAppLink`). TUZAK: l10n dizgesinde düz `'` (file's) derleme kırar — part dosyası olduğu için
  `flutter analyze <dosya>` yakalamadı, l10n testi yakaladı; tam analyze ya da `’` kullan.

## 2026-11-01 — Aktarım ekrandan bağımsız; düzenleme dönüşü odağı; seçici 2. tur
- **QR/web gönderimi ekrandan çıkınca kesiliyordu — kök:** `NearbyScreen.dispose` sunucuyu `close(force: true)` ile
  kapatıyor, hotspot'u da indiriyordu; seçim değişince `_restartWeb` de süren indirmeyi kesiyordu. Alıcı (`PeerReceiver`) aynı
  hatayı taşıyordu. Çözüm `services/fm/remote/transfer_keeper.dart`: aktarım sürerken ön plan servisi + `PARTIAL_WAKE_LOCK`
  + Wi-Fi kilidi (`dosya/qr` → `keepAwake`, 2 sa tavan); ekran kapanırken son 60 sn'de isteği olan sunucu devralınır, iş
  bitince 60 sn boşta kalırsa sunucu + hotspot kapanır. **Hiç istek almamış sunucu eskisi gibi anında kapanır** (gizlilik
  kararı korunuyor). Bildirimde "Durdur". Test `test/transfer_keeper_test.dart` (gerçek HTTP).
- **Düzenleme sonrası odak — kökler:** (1) Word'ün gerçek yolu Mobil editör; dönüş yalnız sayfa numarası taşıyordu ve
  `_resumePage > 1` şartı vardı, `focusPara` yalnız eski WebView yolundaydı → artık `topParaIndex` ile bakılan paragrafta açılır,
  `caretOut` ile imleç paragrafına dönüp çerçeveler. (2) Slayt: gizli liste düzenleme boyunca boyu değişen görünümde kaldığı için
  konum kenetlenip başa kayıyordu (test önce kırmızı: 30 → 0) → `_editOffset` ile geri konur. (3) PDF: düzenleyicide
  başka sayfaya geçince görüntüleyici eski sayfaya dönüyordu → `PdfEditorScreen.lastPage`.
- **Seçici 2. tur:** kategori/arama yalnız arama dizinine bakıyordu (yeni kurulumda boş) → diske düşer; yazdıkça arama;
  sıralama çipi her listede; Tümünü seç / Temizle + toplam boyut; "son klasör" çipi; teslimde silinmiş dosya çökmez.
- **TUZAK:** `pick_file_screen.dart` kaynağında ham NUL baytı vardı (`'\0system'`), git dosyayı ikili sayıp diff göstermiyordu → `'\u0000system'`.
- **TUZAK:** MIUI'de adb kurulum ve dokunma için Geliştirici seçeneklerinde "USB üzerinden yükle" + "USB hata ayıklama
  (Güvenlik ayarları)" kullanıcı tarafından açılmalı; yoksa `INSTALL_FAILED_USER_RESTRICTED` / `INJECT_EVENTS`.
- **TUZAK (Windows test, B1.2):** `const SystemEncoding()` Windows'ta cp1254 çözer → testte `utf8.decoder`. Aynı cihazı başka oturum
  kullanıyorsa kilit: `/data/local/tmp/cihaz.lock`.

## 2026-11-01 — İlk cihaz turu (Mi Note 10 Lite, ADB): bulgular ve tuzaklar
Sayılar `docs/CIHAZ_TESTI.md` §1. Cihazda kanıtlananlar: QR gönderimi 300 MB + MD5 (geri çık, ana ekran, ekran kapalı; USB'de),
Word/Slayt/PDF düzenleme dönüş odağı, parolalı PDF, FTP uçtan uca, seçici kipi, 49 örnek dosya açılışı.
- **Excel açılış kökü:** `XlsxReader` sayfayı `XmlDocument.parse` ile DOM'a alıyordu (200 bin hücre telefonda ~20 sn + GC) ve `cellRef`
  her hücrede RegExp derliyordu → `sheetData` ve paylaşılan dizeler elle taranır (CDATA, yorum, ön ekli adda DOM'a düşer; `forceDom` ile iki yol
  eşdeğerlik testli). ~8 sn'ye indi, hedef 1,5 sn tutmuyor (KALANLAR B3.3a).
- **Parolalı PDF kökü:** görüntüleyicide `passwordProvider` hiç yoktu, dosya "bozuk" görünüyordu. Parola yalnız bellekte tutulur.
- **Şerit kökü:** `EditorChrome` şeridi alt güvenli alanı saymıyordu; 3 tuşlu gezinmede PDF araçları çubuğun arkasındaydı. Hareketli gezinmeli
  telefonda (13T) görünmüyordu: **tek telefonla test yetmez.**
- **TUZAK — pdfrx `initialPageNumber` tutmuyor** (görüntü 1. sayfada, sayaç 16): `goToPage` yeniden denemeyle.
- **TUZAK — Windows checkout örnek PDF'leri bozuyordu:** `autocrlf` + düz metin PDF → xref kayar, pdfium açar ama Syncfusion reddeder. "PDF kaydı
  bozuk" diye yanlış alarm verdi. `.gitattributes`: `test/fixtures/** binary`. Bozuk xref'li gerçek PDF'te mesaj hâlâ genel (B3.3b).
- **TUZAK — `hooks/pre-push` tam testi koşar (5–7 dk):** kısa zaman aşımıyla "push takıldı" sanma, arka planda koştur; yükte kararsız test çıkabilir,
  önce tek başına koştur. Push sonrası CI koşusunu `gh run list --commit <sha>` ile bul: `--limit 1` eski koşuyu izletir.
- **TUZAK — ölçüm:** sentetik `input tap` Flutter satırlarında bazen kaçıyor → `input swipe x y x y 110`. `uiautomator dump` metni okumak ekran görüntüsünden çok ucuz.
  Prizdeki telefonda `batterystats` mAh vermez; gerçek pil için USB'siz koşu gerekir. Aynı telefonu başka oturum kullanıyorsa kilit `/data/local/tmp/cihaz.lock`.

## 2026-11-02 — Faz A bulut turu 1: A1.3, A2, A4.5, A6.1–A6.3, A7.3
Kullanıcı: *"fazlardan devam et, bulutta yapılabilecekleri yap, main'e merge et, APK derlensin"*.
- **A2 ölü kod:** `qr_share_screen.dart` yeniden bağlandı — paylaş seçimi `screens/fm/remote/share_choice.dart`'a
  taşındı (nearby_screen 1621 → 1602 satır), tek ve ≤ 8 KB metin dosyasında üçüncü seçenek "Metni QR kodda göster".
  `pdf_font_class.dart` "Üstüne yaz"ın Carlito yedeğine bağlandı: paragrafın ana `/BaseFont`'u
  (`PdfPageEdit.paragraphBaseFont`) → `PdfOverwrite.fontAssetFor` (serif → Tinos, italik korunur, kalınlık
  kullanıcıdan). `pdf_text_stamp.dart` yalnız örnek üretimi kullanıyordu → `test/support/`. Bekçi
  `test/reachability_test.dart` (import/export/part + koşullu import gezintisi, `main.dart`'tan; kopuk dosya 0).
- **A4.5:** `ftpconnect` alt sınırı ^2.0.10 (her ortam 3.44.6) → `?.` + ignore kalktı; `route_guard`'da eskimiş
  `didPushRoute` ezmesi gereksizdi (varsayılan `didPushRouteInformation` onu çağırıyordu, o zaten eziliyor);
  `main.dart` `print` → `debugPrint` (yayında da logcat). `mini_player_bar` `setState` ignore'u gerekçeli, kaldı.
- **A1.3:** kod/test yorumlarındaki "KALANLAR maddesi" atıfları kaldırıldı (KALANLAR artık yalnız açık iş);
  `flutter_launcher_icons` `min_sdk_android: 24`. pubspec'teki "CI 3.29.3" gerekçeleri A3'te paket paket düzelecek.
- **A6.1:** `docs/play/izin_beyanlari.md` her izni anlatıyor (QUERY_ALL_PACKAGES/REQUEST_DELETE_PACKAGES,
  konum ≤ API 32, BLE, Wi-Fi/hotspot, BOOT, INSTALL_SHORTCUT, medya, VIBRATE). Bekçi
  `test/play_permissions_doc_test.dart`: `ci/AndroidManifest.xml` + eklenti manifestleri (`package_config.json`
  üzerinden) ⊆ `## ` başlıkları.
- **A6.2:** gizlilik TR/EN/AR'ye Yakındakiler (BLE yalnız bulma — görünen ad + KURULUMA özgü kimlik, oturum değil;
  8080 + 6 harf kod; hotspot; konum okunmaz), AI anlamla arama (yalnız sorgu), AI etiketleme/kategori analizi
  (ad + uzantı + klasör ADI + boyut + ay; analizde sayı/boyut özeti), asistan köprüsü (yalnız kişisel derleme);
  izin tablosu genişledi; veri güvenliği taslağından "Anılar" çıktı. `policy_doc_test`: üç dil aynı bölüm + tablo satırı.
- **A6.3:** mağaza metinleri + L6 Microsoft marka notu TR/EN/AR. **Ekran görüntüleri buluttan ALINAMAZ**:
  `design_shots_test` geçici klasör yolunu (`tmp > designXXXX`) ve boş tür rozetlerini çiziyor, `filtre` çekimi
  düşüyor → B2'ye taşındı.
- **A7.3 arşiv çıkarmada Durdur:** `ArchiveOps.extract(isCancelled:)` → `Isolate.spawn` + üst düzey giriş
  (`_extractEntry`, yalnız gönderilebilir liste — 2026-07-27 closure-context tuzağı) + 150 ms yoklama; iptalde
  `kill(immediate)`, yarım hedef klasör silinir (uniquePath ile yeni açıldığı için güvenli), `JobCancelled` atılır;
  `showFmProgress` `JobCancelled`'ı hata değil "durduruldu" sayar. `isCancelled` verilmeyen çağrılar (QR/peer alma)
  eski `Isolate.run` yolunda. Test `test/fm_archive_cancel_test.dart` (4000 dosyalı ZIP).
- **Bulut test notu:** tam takımda `excel_data_screen_test` "Yinelenenleri kaldır" ve `snack_queue_test` "ikinci
  bildirim" yükte düştü, tek başına yeşil (bilinen yük kararsızlığı; kod değişikliğiyle ilgisiz).
- **A1.2 (uzak dal silme)** kullanıcı izni gerektirdiği için yapılmadı.

## 2026-11-02 — Faz A bulut turu 2: A3.5, A6.4, A7.6, A7.7, A5'in iki işi
- **A3.5 `pubspec.lock` depoda** (Flutter 3.44.6 ile çözümlenmiş hâli); `.gitignore`'dan çıktı; CI
  `flutter pub get --enforce-lockfile`, `prepare_android.sh` kilidi `flutter create`e karşı yedekler ve
  kilit varsa ona uyar. Alt paket kayması artık kilitte görünür.
- **A6.4 Play izin varyantı:** `ci/play_variant.py apply|verify` — `DOSYA_PLAY_REMOVE` (varsayılan
  `QUERY_ALL_PACKAGES`) için ana manifeste `tools:node="remove"`, `<queries>`'e MAIN/LAUNCHER; doğrudan
  bildirilmiş izin satırı önce silinir (yoksa çakışır); iki kez uygulanmaz. Workflow elle tetiklemede
  `play: true` (+ `aab: true`): APK'lar ÖNCE derlenir, manifest yalnız AAB için yamanır, birleşmiş
  manifestte izin YOK denetlenir. Varsayılan KAPALI — hangi izinler çıkacağı kullanıcı kararı (B5.3).
  Test `test/play_variant_test.dart` (python3 yoksa atlanır).
- **A7.6/A7.7 belge kanvası:** `DocxCanvas` (docx_view.dart) + `viewer.html` `setCanvas(bg, page, frame)`
  (kendi `<style id=canvasStyle>`; renkler Dart'ta `#rrggbb`, JS'e kullanıcı metni girmez). Koyu (ve
  gece ailesi) → kanvas temanın zemini, sayfa beyaz; kâğıt açık → kanvas `well`, sayfa `#FBF8F1` +
  `#D2C8B4` çerçeve, yarıçap 4 (akış görünümünde çerçeve yok); öteki açık temalar eski `#F3F2F1`.
  WebView `setBackgroundColor` da aynı renk (açılış parlaması yok). PDF: `PdfPageFrame` kâğıt açıkta
  `pageDropShadow: null` + `pagePaintCallbacks`'te kalınlık 0 (her yakınlıkta 1 cihaz pikseli) çerçeve.
  **Sınır:** pdfrx 1.3.5 sayfa zeminini açmıyor → PDF sayfa içi beyaz kalır (A9.2).
- **A5 (kısmi):** toplu yeniden adlandırma `TrackedTask` + `renamedChange` (tür `rename`, değer boş = tek
  grup, `before` eski yol) → rapor ⋮ "Adları geri al" (eski ad doluysa o dosya atlanır). Çöpe taşıma:
  `FmOpResult.trashed` + `transfers` (özgün → çöpteki yol) → `jobChangesOf` tür `trash`; `summarize` çöpü
  hedef göstermez; rapor ⋮ "Geri yükle" çöp listesinde `storedPath` ile bulup `restore`. Kalan işler KALANLAR A5.
- **TUZAK (test):** `MaterialApp(theme:)` değişince ilk karede `Theme.of` hâlâ ESKİ parlaklığı verir
  (AnimatedTheme geçişi) → testte `pumpAndSettle`.
- **TUZAK (bekçi):** `design_tokens_test` servis kodundaki `Duration(milliseconds: N)`'yi de sayar; arşiv
  iptal yoklaması (zamanlayıcı = içerik, tasarım değil) tavana yazıldı. Belge renkleri `AppColors.paperPage /
  paperFrame / docCanvas` token'ı. Turu 1 bu yüzden CI'da kırmızıydı (yerel tam test aynı anda koşmadan
  push edildi) → turu 2'de düzeldi. Ders: push ÖNCESİ tam test bitmeli.


## 2026-11-02 — Cihaz turu (Mi Note 10 Lite): profil APK, çöp hızı kök nedeni

- **Test telefonu temizlendi:** 54 reklam/arka plan/gereksiz paket `pm uninstall --user 0`
  (MIUI msa/analytics/daemon/joyose, Facebook/Netflix ön yüklemesi, Xiaomi bulut/mağaza/uygulamalar,
  Google gereksizleri, kullanıcının eski uygulamaları). Kalan: WhatsApp, Telegram, Gmail, YouTube,
  Play, Chrome (Yakındakiler tarayıcı yolu), Foto/Drive, Mi Dosya. Geri: `cmd package install-existing <paket>`.
- **B1.3 tarifi (yerelde):** `git clone` → `C:\r8`; `ci/AndroidManifest.xml` + `ci/PickerActivity.kt`
  authority `…dosya_okuyucu.r8test.documents`; `bash ci/prepare_android.sh` (PATH'te `python3` →
  `python` kabuğu); `android/app/build.gradle.kts`'e `applicationIdSuffix = ".r8test"`;
  `flutter build apk --profile --target-platform android-arm64`. MIUI kurulumu: Geliştirici
  seçenekleri → "USB üzerinden yükle" (yoksa `INSTALL_FAILED_USER_RESTRICTED`). Profilde
  `_logSlowStartupFrames` sökülmez, 300 karede bir `KARE_OZET … p99=` yazar.
- **Bulgu:** Impeller Vulkan bu telefonda (Adreno 618) GLES'e düşüyor. `--ez enable-impeller false`
  ile Skia denendi → daha KÖTÜ (%99 30–45 ms) → **reddedildi**, Impeller kalır.
- **Kök neden — "5.000 dosyayı çöpe atmak dakikalar sürüyor":** (1) her dosyada büyüyen
  `index.json` baştan kodlanıp yazılıyordu (O(n²)) → kayıtlar 64'lük gruplarla; grup yazılamazsa o
  gruptaki dosyalar geri alınır. (2) asıl büyük pay **FUSE**: `/sdcard`'da `rename` hedef klasör
  büyüdükçe pahalı — kabukta bile 5.500 dosyalı düz klasöre ~150 ms/dosya, küçük klasöre ~22 ms
  (taban). Çöp artık `files/<zaman>-<k>/` 256'lık alt klasörlere yazıyor; kayıt `stored` alanı
  `files/`e göreli yol (eski kayıtlar yalnız ad — ikisi de okunur); boşalan alt klasör silinir.
  Sonuç temiz çöpte 1.000 dosya: taşı 31 sn, boşalt ~20 sn (önce 74–92 / ~67 ms/dosya).
  **TUZAK:** ölçümde `date +%s%N` aritmetiği telefonda taşıyor (negatif/yanlış süre) → `time sh -c`.
  **Bilinen sınır:** süreç grup ortasında ölürse ≤ 64 dosya kayıtsız kalır (ponytail notu kodda).
- Ölçümler `docs/CIHAZ_TESTI.md` §1; sınırdakiler KALANLAR B3.3b.
- **Arşiv durdurma:** `isolate.kill` asenkron → durdurmada `addOnExitListener` ile çıkış beklenip
  sonra yarım klasör silinir (Android'de silmeden sonra yazma yarışı). **TUZAK (Windows test):**
  öldürülen izolatın yarım dosya tanıtıcısı kapanmıyor, Windows klasörü silmiyor (errno 32, ≈1/6) →
  `fm_archive_cancel_test` "yarım klasör" testi Windows'ta `skip`. Yeniden deneme işe yaramadı (denendi).
  Push-öncesi kanca yerel kırmızı testte push'u engelliyor — atlama.
- **TUZAK (ortak SDK):** 2026-11-02 13:25'te başka bir oturum `C:\src\flutter`'ı 3.47.7'ye geçirdi →
  bu projede `flutter` komutu `pubspec.lock`'u sessizce yükseltti (intl/meta/matcher…), commit'e
  karıştı, testler derleyicide düştü. Bu proje için ayrı SDK: `C:\src\flutter-3446` (3.44.6) —
  `export PATH="/c/src/flutter-3446/bin:$PATH"`; kilit `flutter pub get --enforce-lockfile` ile doğrulanır.

## 2026-11-02 — A3.1 archive 3→4 (image 4.8.0)
- `archive ^4.0.9` + `image >=4.4.0 <4.9.0` (kilit 4.8.0). **Üst sınırlar:** `pdf` paketi archive'i <4.1'de
  tutuyor; image 4.9+ `xml ^7`, 4.11+ archive'in yeni API'sini (`ZLibDecoder.decodeLazy`) istiyor → ikisi de
  `xml ^6` ve pdf yüzünden yükseltilemez (pdf 3.13 → xml 7 gerektirir).
- **Kök neden / TUZAK:** archive 4'te çözülmüş `ArchiveFile`'ı başka arşive olduğu gibi `addFile` etmek
  BOZUK bayt üretiyor (ham sıkıştırılmış veri yeniden işleniyor); xlsx yaması hatayı `catch`te yutup girdiyi
  değiştirmeden döndürüyordu (tek belirti: yama sessizce uygulanmıyor). Çare: `services/zip_carry.dart`
  `carryEntry` — açık içerikten yeni girdi. Kalan API farkları: `decodeBuffer`→`decodeStream`,
  `compress`→`compression`, `encode()` artık null dönmüyor.
- Bu makinede doğrulama yalnız `C:\src\flutter-3446` ile; 3.47.7'de pdfrx 1.3.5/dartssh2 derlenmiyor.
- Tam pakette 3 zamanlama düşüşü (slides_edit, pdf_form_screen, xlsx_reader_fast) yük altında; izole geçiyor.

## 2026-11-02 — Asistan köprüsü kaldırıldı
- Merkezi asistan (`com.ses.asistan`) pil yüzünden bırakıldı. Silinenler: `ci/kisisel/` (AsistanKopru, manifest eki,
  sertifika, yetenekler), `AsistanKomutlari` (`oku:`/`ozet:`/`durdur:` bağlantıları), harness ve testi. `DOSYA_KISISEL`
  bayrağı ve `kisisel` ön-sürümü kişisel not özelliği için kaldı. `DosyaArama` yalnız Ajan'ın.

## 2026-11-02 — Windows "Dosya Aktar" exe (tool/pc_aktar)
- Kullanıcı isteği: Yakındakiler protokolüyle konuşan Windows exe. C# WinForms, **net48** (her Win10/11'de kurulu,
  exe ~55 KB, kurulumsuz). Derle: `cd tool/pc_aktar && dotnet build -c Release` → `bin/Release/net48/DosyaAktar.exe`.
  Protokol Dart'tan birebir (`peer_share.dart`): UDP 8769 bulma, HTTP 8770 `/kim /sor /durum /al`, tid'li devam,
  `paket=1` ZIP açma. **peer_share.dart'ta uç/alan değişirse `tool/pc_aktar/Core.cs` de değişmeli.**
- BLE bilinçli YOK (uygulamada da yalnız bulma; veri zaten Wi-Fi). Eşleştirme kodu desteklenmiyor (Yakındakiler kullanmıyor).
- Tuzaklar: HttpListener yerine TcpListener (HttpListener LAN önekinde yönetici/urlacl ister); UDP soketinde
  `SIO_UDP_CONNRESET` kapatılmalı yoksa ICMP sonrası Receive düşer; HttpWebRequest'te `Proxy=null` +
  `Expect100Continue=false`; gizli `.dosya-aktarim-*` taşınınca Hidden niteliği kalır → temizlenmeli;
  Android adlarındaki `: ? *` Windows'ta geçersiz → SafeName '_' yapar. Uçtan uca Dart PeerReceiver/PeerSender ile denendi (iki yön).

## 2026-11-02 — Arka planda görünürlük (kişisel derleme) + Dosya Aktar galerisi/BLE
- **Karar:** Yakındakiler kapalıyken görünmek YALNIZ kişisel derlemede (`ci/kisisel/NearbyBgService.kt`,
  DOSYA_KISISEL=1). Wi-Fi/UDP arka planda dinlenmez (pil + ekran kapalıyken yayın düşer); yalnız
  BLE LOW_POWER reklamı + GATT davet sunucusu, ön plan servisi `connectedDevice`, kanal IMPORTANCE_MIN.
  Kalıcı bildirim Android zorunluluğu (kullanıcı "olmasa iyi" dedi — sessiz/simgesiz yapıldı, kaldırılamaz).
- Davet → yüksek öncelikli bildirim; "Kabul et" = `davet:<json>` bağlantısı (Extras.linkIntent), dokunmak =
  `davetsor:` (yeniden sorar). Yeni davet türü **push** (`"p":1`, adressiz): Windows exe gönderir; telefon
  Yakındakiler'i açınca exe onu Wi-Fi'de bulup /sor ile gönderir, `_preApproved` (ad, 3 dk) ikinci soruyu atlar.
- Genel derleme servise yansımayla bağlanır (`nearbyBackground`, `NearbyBgService$Control` proguard keep);
  yayın + GATT sunucusu ortak `BleBeacon` (NearbyBle.kt). Ekran açıkken servis susar (aynı UUID çakışmasın).
- Windows exe: WinRT BLE (`Microsoft.Windows.SDK.Contracts`, net48'de tek exe kalıyor). Tuzak: Windows tarama
  yanıtını (üretici verisi) hizmet UUID'li reklamdan AYRI olay verir → adres önce UUID ile işaretlenir.
  Tuzak: kabuk küçük resmi alttan-üste DIB (negatif Stride) — satır satır kopyala.
- Doğrulanmadı: Kotlin (yerelde kotlinc yok → CI), gerçek telefonda arka plan + MIUI süreç öldürme + pil.

## 2026-11-02 — Yakındakiler yeniden tasarım + rebase kurtarma
- Önceki oturum `git rebase` ortasında kalmıştı (HAFIZA + asistan silinmesi çakışması). Çözüm: iki HAFIZA kaydı da
  kaldı; `ci/kisisel/` asistan parçaları origin'deki silinmeye uyuldu, **NearbyBgService korundu** (manifest_ek yalnız
  servis + FOREGROUND_SERVICE_CONNECTED_DEVICE; prepare_android kişisel bloğu yalnız servisi kopyalar/denetler).
  `git range-diff` ile 7 yerel commit doğrulandı — veri kaybı yok.
- Gönderim artık ekranı kapatan `showFmProgress` penceresi DEĞİL: ekranda "→ X cihazına gönderiliyor" kartı, dosya
  (kalem) başına satır + Durdur. Kaynak `PeerSender.send(onFile:)` (başta 0, bitince boyun tamamı). Süren gönderimde
  avatarlar soluk, dokununca `near.busy_sending`. Ekrandan çıkınca gönderim SÜRER (Future ekrana bağlı değil).
- ≥ 840 dp iki sütun (sol: durum/aktarımlar/seçim/cihazlar · sağ: QR/geçmiş/diğer yollar), en geniş 1480 (pano ile aynı).
- Bölme: `nearby_screen.dart` (durum+mantık) + `nearby/links.dart` (QR/hotspot/BLE davet/arka plan) +
  `nearby/sections.dart` + `nearby/widgets.dart` (`part` + extension). **TUZAK:** extension içinden `setState`
  `invalid_use_of_protected_member` verir → State'te `_update(fn)`; statik üyeler `_NearbyScreenState.` ile nitelenir.


## 2026-11-02 — Test süresi: demetler + push damgası
- Ölçüm (`--file-reporter json`): 357 dosya, tam paket 810 sn; tek dosyada test 2 sn, kalan ~40 sn DERLEME
  (her test dosyası ayrı derleniyor). Çare `tool/test_bundle.py`: dosyalar 8 demette (`group(dosya, t.main)`),
  önceki koşunun süresine göre dengeli → **tam paket ~2 dk**. Demetler gitignore'da, kapı bitince silinir.
- **TUZAK:** demette bir widget testi `TestWidgetsFlutterBinding` kurunca aynı izolattaki HER `HttpClient`
  sahte 400 döner → gerçek ağ açan dosyalar (regex NET) ayrı koşar. Duruma duyarlılar `ALONE` listesinde
  (job_tracking, job_shown_title, smart_redesign, fm_photos_screen, neural_voices) — yeni sızıntıda listeye ekle,
  kök nedeni ayrıca düzelt. Dosya düzeyi `@Timeout/@Tags` group'a geçmez → onlar da ayrı.
- `hooks/pre-push` artık `tool/test_gate.sh`: yeşil koşu HEAD ağacını `.git/test-green`'e damgalar; aynı ağaç
  (ya da fark yalnız `.github/ docs/ graphify-out/ hooks/ *.md`) yeniden test edilmez → push saniyeler.
  Düşen test asıl dosyasıyla bir kez tek başına denenir (yük altında süre aşımı). Akış: commit → `sh tool/test_gate.sh` → push.
- CI eşzamanlılık grubu kişisel/genel ayrı (elle kişisel derleme nightly'i iptal ediyordu).

## 2026-11-02 — A3.3 ML Kit tazelendi
- text_recognition 0.15.0 → ^0.17.1, translation 0.13.0 → ^0.15.1 (commons 0.13.0). Dart API değişmedi.
- R8 `-dontwarn com.google.mlkit.vision.text.{chinese,devanagari,japanese,korean}` HÂLÂ gerekli: eklenti 0.17.1
  o dil paketlerini `compileOnly` alıp köprüde içe aktarıyor. Cihazda OCR + çeviri bakılacak (CIHAZ_TESTI R8 satırı).

## 2026-11-02 — A3.4 bağımlılık tazeleme
- video_player 2.10.1 → ^2.14.1 (android alt paketi artık doğrudan sabit değil, 2.12.2), flutter_local_notifications
  17.2.4 → ^22.3.3 (**API: `initialize(settings:)`, `show/cancel/startForegroundService` adlı parametreler**; tek
  dosya `notification_hub.dart`), syncfusion pdf/core 31.1.19 → ^33.2, permission_handler 11.3.1 → ^12.0.1
  (cunning_document_scanner 1.4.0'a çıktı), fc_native_video_thumbnail 2.2.0 → ^4.0.0 (API aynı), flutter_lints ^6
  (yalnız 4 `unintended_html_in_doc_comment` → ters tırnak).
- Çakışma zinciri (kalan sabitler KALANLAR A3.4b): wakelock_plus ≥1.6.1 `win32 ^6` → share_plus 10 ile çakışır;
  wakelock 1.8 + bildirim 17 ise `dbus` sürümünde çakışıyordu (bildirim 22 bunu çözdü).
- Cihazda: bildirim (iş/oynatıcı/ön plan servisi), video küçük resmi, depolama izni akışı, PDF yazma (Syncfusion).

## 2026-11-02 — A3.2 pdfrx 1.3.5 → 2.4.8 (**2026-11-03 GERİ ALINDI**, aşağıya bak)
- 2.11 çözülmüyor (pdfrx_engine 0.9 bağımlılık zinciri); ^2.4.8. Yerel pdfium artık `pdfium_flutter` paketinden.
- API farkları: `loadText()` → ham `PdfPageRawText?` (fullText + charRects); parçalı metin `loadStructuredText()`
  (uzantı; ham metinden üretir → **test sahteleri `loadText` ile ham metin döndürmeli**). `PdfPageText` artık sabit
  değer sınıfı, parça sayfaya geri başvurur → OCR metni `assembleOcrPageText` (önce sayfa, sonra parçalar).
  `getBoundsForRange` → `charRects.boundingRect(start,end)`; `toRectInPageRect` → `toRectInDocument`;
  `render(backgroundColor:)` int (ARGB); `PdfImage.format` yok (her yerde BGRA); `minScale` /
  `useAlternativeFitScaleAsMinScale` → `sizeDelegateProvider: PdfViewerSizeDelegateProviderLegacy(...)`.
- **Geçici çözümler BİLEREK duruyor** (basamaklı `getPageRenderingScale`, sığdırma kenetlemesi, sabit pay,
  kendi seçim katmanı): 2.x'te gereksiz mi sorusu yalnız cihazda ölçülür → CIHAZ_TESTI PDF bölümü (B2).

## 2026-11-02 — A4.1 800+ satırlı ekranlar bölündü
- image_edit 1613 → 762 (+ `image_edit_screen/crop.dart`, `parts.dart`), pick_file 1071 → 687, job_report 978 → 417,
  category 884 → 699, search 881 → 449 (+ `<ad>/parts.dart`). Yöntem: `build` SONRASI yardımcı metotlar +
  State'ten sonraki sınıflar `part` + `extension` (davranış aynı). Kurallar: extension alan tanımlayamaz (alan
  State'te kalır), `setState` → State'teki `_update`, statik üyeler `_XState.` ile nitelenir.


## 2026-11-02 — VLC benzeri oynatıcı (mpv) + görsel iyileştirme/kurtarma
- **Motor:** ExoPlayer varsayılan; mpv (`video_player_media_kit` + `media_kit_libs_android_video`, libmpv 12 MB,
  içinde FFmpeg) `VideoPlayerPlatform.instance` değiştirilerek takılıyor (`services/fm/player_engine.dart`).
  **TUZAK:** örnek değişince `video_player` yeni örneğin `init()`ini çağırıyor ve onun TÜM oynatıcılarını
  kapatıyor; eski denetleyici değiştirmeden ÖNCE kapatılmalı (ses oynatıcısı da durduruluyor).
- **Otomatik geçiş:** ExoPlayer çözemediği sesi (AC3/DTS) HATA VERMEDEN sessiz çalıyor; tek ipucu
  `getAudioTracks()`ta hiçbir parçanın `isSelected` olmaması → mpv. Görüntü boyutu 0 ya da init hatası da mpv'ye
  düşer. AVI/WMV/FLV/RMVB/VOB… baştan mpv (`PlayerEngine.mpvFirst`). Menüde elle geçiş + ses parçası seçimi.
- **FFmpeg ses eklentisi (Media3 decoder_ffmpeg) EKLENMEDİ:** video_player_android ExoPlayer'ı
  `EXTENSION_RENDERER_MODE_OFF` ile kuruyor, eklenti için Java yaması gerekirdi; mpv aynı kodekleri kapsıyor.
- **Altyazı:** OpenSubtitles v1 (`opensubtitles.dart`, moviehash önce). Anahtar `--dart-define=OPENSUBTITLES_API_KEY`
  yalnız kişisel derlemede (secret `OPENSUBTITLES_API_KEY`); anahtar yoksa menüde seçenek yok. Altyazı punto
  çarpanı oturum boyu statik.
- **Görsel:** galeride "İyileştir" (otomatik/keskinleştir/gürültü — saf Dart; ESRGAN 4× — LiteRT `tflite_flutter`,
  model ilk kullanımda TF Hub'dan indirilip SHA-256 doğrulanıyor, APK'da yok). Bozuk görsel: başındaki çöp atılır,
  yarım JPEG'e EOI eklenir, `image` paketiyle yeniden çözülür (`image_repair.dart`); dosyaya dokunulmaz.
- APK bütçesi 80 → 100 MB; `-keep class com.alexmercerind.**` (libmpv JNI ile adla çağırıyor).
- meta 1.19 ile gelen `unawaited_return_in_try_block` / `invalid_return_type_for_then` uyarıları düzeltildi.

## 2026-11-03 — PDF'ler açılmıyordu (sürüm 475) + yerel SDK tuzağı
- **Kök neden:** pdfrx 2.x `PdfTextSearcher(controller)` yapıcısı hemen `controller.document.events`e abone
  oluyor; `ViewerScreen.initState`te (görüntüleyici bağlanmadan) kurulunca "Null check" → her PDF "Bu ekran
  çizilemedi". Arayıcı artık `onViewerReady`'de kuruluyor (her yeniden yüklemede yenisi). Kanıt:
  `test/pdf_viewer_open_test.dart` düzeltmesiz KIRMIZI, düzeltmeyle YEŞİL. Yöntem: CI artifact'ından
  `dart-symbols-<sürüm>` + `flutter symbolize` (tahminle yama yok).
- **TUZAK (yine düşüldü):** 3.47.7 SDK ile `pub add` kilidi bozdu (meta 1.19 …). Kayıt zaten vardı (yukarıda
  `C:\src\flutter-3446`); oturum başında HAFIZA tam okunmadı. Push kancası da PATH'te 3446 ister.

## 2026-11-03 — Fotoğraflar ızgarası kaydırma takılması (Mi Note 10 Lite, ölçümle)
- **Kök neden (ölçüldü):** her hücre 12 MP'lik özgün JPEG'i çözüyordu. Profil zaman çizelgesi (VM servis
  `getVMTimeline`, 5 savurma): `DecompressTexture` 4746 ms / en uzun 202 ms; doku yükleme 852 ms. UI izleği
  temiz (≤ 9,5 ms) → Dart kodu değil. **Düzeltme:** Android `ThumbnailUtils.createImageThumbnail` ile diskte
  küçük JPEG (`ThumbnailCache.forImage`, `image_thumbs/`, Kotlin `imageThumb`); hücre onu açar. Sonra: çözme
  470 ms / en uzun 21 ms (10×), yükleme 463 ms, raster en uzun 27 → 21 ms.
- **Ölçüm TUZAĞI:** Flutter `FrameTiming` (logcat KARE) bu takılmayı GÖSTERMİYOR (kareler zamanında) —
  görsel donma için ekran kaydı (`screenrecord` + ffmpeg 60 fps + satır kayması eşlemesi) gerekti.
- **Açık kalan:** videoda hâlâ 4.–5. savurmada 13–17 karelik donma görülüyor; Flutter tarafı temiz. Ekran
  kaydedici artığı mı gerçek mi ayrılmadı (SurfaceFlinger `--latency` ile bakılacak) — KALANLAR B3.3b.
- MIUI `svc power stayon usb`'yi yok sayıyor: her ölçümde `KEYCODE_WAKEUP` + kaydırarak kilit aç.

## 2026-11-03 — PDF/Word kasma turu (bulut, ölçümsüz — kod okumasıyla bulunan kök nedenler)
- **PDF açılışı — form taraması:** `PdfFormFiller.looksLikeForm` her açılışta dosyanın TAMAMINI ana izlekte
  tarıyordu (64 KB parçalar `[...tail, ...chunk]` ile kutulu listeye kopyalanıp bayt bayt). Büyük PDF'te
  saniyeler, tam da ilk sayfalar çizilirken. → `Isolate.run` + 1 MB blok + ilk bayt atlaması
  (`scanForAcroFormSync`, sınır testi `perf_offload_test`).
- **pdfrx 2.x'te kendi metin seçimi VARSAYILAN AÇIK** (1.3.5'te kapalıydı; A3.2'de fark edilmedi): sayfaların
  altına ikinci jest katmanı + her dokunuşta tüm sayfaların metnini tarayan isabet testi + bizim katmanla
  yarışan uzun basış. → `kPdfOwnSelectionOff` (`services/pdf/pdf_viewer_defaults.dart`, `const` olmalı:
  pdfrx parametreleri `!=` ile karşılaştırıyor). Görüntüleyici + PDF düzenleyici.
- **TUZAK — pdfrx 2.x boyama döngüsü her önbellekteki sayfanın metnini ZATEN yüklüyor**
  (`_getCachedTextOrDelayLoadText`, seçim kapalıyken bile) ve bütün pdfium çağrıları tek işçide sırada.
  `PdfSelectLayer` kurulur kurulmaz ikinci kez yüklüyordu → artık `textLoadDelay` (Motion.long) sonra ya da
  ilk dokunuşta; metin gelmeden uzun basış OCR'a DÜŞMEZ, yükleme bitince yeniden dener.
- **Taranmış PDF otomatik OCR:** sayfa görüntüsü GPU dokusuna yüklenip geri okunarak PNG yapılıyordu
  (`decodeImageFromPixels` + `toByteData`) → `OcrService.renderPageForOcr`: pikseller izolatta JPEG
  (`image` paketi). PNG dışa aktarım (`renderPageToPng`) değişmedi.
- **Word açılışı:** `FileService.load` docx/pptx metnini ana izlekte çıkarıyordu (yükleniyor göstergesi
  donar) → `compute`. `WordEditorScreen._load` `DocxEditor.parse` + `viewBytes` (DOM kopyası + bütün
  belgenin yeniden zip'lenmesi) işini sayfa geçişi sırasında ana izlekte yapıyordu → `DocxEditor.openForView`
  (`Isolate.run`, sonuç `Isolate.exit` ile kopyasız; gönderilemezse eski yola düşer — testte
  `debugOpenedInIsolate` ile izolat yolu doğrulanıyor).
- **Açık (cihaz):** Word kapanış/menü takılması için şüpheli hybrid composition WebView → KALANLAR B3.3d.
  Bu turun hiçbir düzeltmesi cihazda ÖLÇÜLMEDİ → CIHAZ_TESTI §6/§8 "Kasma turu".
- Tasarım tokenı testi dosya başına ham `Duration` sayısına tavan koyuyor: yeni gecikme için `Motion.*`.

## 2026-11-03 — pdfrx 2.4.8 → 1.3.5 GERİ (yoğun PDF'te ~5 FPS, açılış çok geç)
- **Kullanıcı bulgusu:** "40 Hadis İmam Nevevî" PDF'i (54 sayfa, 595×595 pt) kaydırırken sürekli donuyor,
  ilk yükleme aşırı geç; diğer PDF'lerde daha az. "Önceden düzgündü" = 1.3.5.
- **PDF'in ağırlığı (ölçüldü, poppler):** her sayfada 4961×2480'lik (12 MP) saydamlıklı (ExtGState) arka plan
  resmi; poppler bir sayfayı 200 dpi'da 4,8 sn'de çiziyor, metin çıkarma 25 ms. Yani maliyet ÇİZİMDE; sayfayı
  fazladan çizdiren / çizim kuyruğunu dolduran her şey kasmaya dönüşür.
- **2.x'in 1.3.5'te olmayan, parametreyle kapatılamayan işleri (kaynaktan):** (1) erişilebilirlik açıkken
  (telefonda HERHANGİ bir erişilebilirlik hizmeti) görünen her sayfanın HER satırı için `Focus`+`Semantics`
  bileşeni, kaydırmanın her karesinde yeniden (`_buildPageSemanticsWidgets`, yalnız
  `SemanticsBinding.semanticsEnabled`'a bakıyor); (2) boyama döngüsü önbellek payındaki her sayfanın metnini
  yüklüyor + ana izlekte `PdfTextFormatter` (`_getCachedTextOrDelayLoadText`); (3) kendi metin seçimi
  varsayılan açık. Tüm pdfium işleri tek işçide sırada.
- **Ölçülemedi:** bulutta pdfium çalıştırma (indirilen `libpdfium.so`) izin denetiminden geçmedi; telefon yok.
  Hangisinin baskın olduğu bilinmiyor → bilinen iyi motora dönüldü (geri alma küçük: A3.2 17 dosya).
- **Korunanlar (motordan bağımsız):** form taraması izolatta, seçim katmanı metni gecikmeli, OCR görüntüsü
  izolatta JPEG (1.3.5'te `PdfImage.format` RGBA/BGRA'ya göre kanal sırası), Word izolatı, PdfTextSearcher
  `onViewerReady`'de. `pdfrx: 1.3.5` tam sabit (`^1.3.0` değil).
- **Tekrar yükseltmeden önce:** bu PDF'le cihazda profil zaman çizelgesi (UI + raster + pdfium işçisi);
  2.x'te (1)'i kapatmak paket yaması ister (`dependency_overrides` + yerel kopya).

## 2026-11-03 — Görsel iyileştirme arka planda + önce/sonra; dosya seçici A11
- **"Üretiliyor ve kayboluyor" kökü:** iş galerinin modal penceresine bağlıydı, sonuç YALNIZ galerinin o anki
  bellek listesine ekleniyordu (kalıcı iz yok, galeriye bildirim yok, ekrandan çıkınca bulunamıyor).
  → `services/fm/enhance_jobs.dart`: `JobQueue.track` (şerit + İşlemler + bildirim, ön plan servisi),
  çıktı `TrackedJob.addOutput(out, source:)` ile özgünle çift, `FsEvents.changed` (MediaScan), `results`
  akışı açık galeriye yeni kopyayı ekler. Hedef `FmJobTargetKind.enhance` → `openJobTarget` çiftten
  `ResizeCompareScreen(enhance: true)` açar (Önce/Sonra etiketi, tasarruf satırı yok, "İkisini de tut"
  birincil; yeni "yan yana" görünümü her iki kipte).
- **İzolat:** `ImageEnhance.enhanceFile` artık `Isolate.spawn` (öldürülebilir): ilerleme ESRGAN parçası
  başına (`tileUpscale(onTile:)`), Durdur → `cancelSignal` (kuyruk dinleyicisi, yoklama YOK — tasarım
  tokenı testi ham `Duration(milliseconds:)` sayıyor) → `kill` + `EnhanceCancelled`; bozuk dosya `FormatException`
  (`image` çözücüsü çöpte RangeError atıyor — yakalanıyor).
- **TUZAK (test):** `track()` aynı kimlikle SÜREN iş varken yinelenen kayıt açar → `EnhanceJobs.start`
  önce `find(id)` bakar, sürüyorsa null döner.
- **Seçici A11:** ana sayfa sırası kutular → hızlı klasörler → ince depolama satırı → son açılanlar (EN ALTTA;
  eski büyük `DashboardVolumeCard` ve ayrı "Tüm dosyalar" satırı kalktı — depolama satırı köke gider).
  Listelerde `FmQuickFilters` + `FmTypeChips` + `FmMoreChip`; tür hapı `request.isSpecific`te gizli (açık
  soru öneriyle kapandı); klasörler süzgeçten etkilenmez (`pickVisibleEntries`, testli); görünüm değişince
  süzgeç sıfırlanır.
