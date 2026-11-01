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
- `pubspec.lock` gitignore'da; CI her koşuda yeniden çözümler → alt paketler elle pinli
  (KALANLAR A3.5).
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
  (compileSdk 30, derlemeyi kırıyor).

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
