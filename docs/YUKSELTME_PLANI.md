# YÜKSELTME PLANI — Faz 43–50 (2026-11-07)

Kullanıcı isteği: *"Flutter ve tüm eklentiler güncel olsun; PDF'i (pdfrx 2.x) tekrar deneyeceğiz ama
önce neden geri döndüğümüzü bul; performans sorunu KESİNLİKLE yaşanmasın; test cihazı bilgisayara
bağlı, fazlarda telefonda canlı test yapılsın."* Fazlar **yerel bilgisayarda** (Windows + USB'li telefon)
yürütülür. Kural seti: `GELISTIRME_PLANI.md` → **Performans Koruma Anayasası** burada da geçerlidir (1–10).

---

## 0. Bu fazlara özel çalışma kuralları (2026-11-07, kullanıcı kararı)

1. **Dal + PR:** her faz `faz-NN` dalında yapılır, PR açılır, CI yeşil **ve cihaz kapısı geçtiyse**
   main'e birleştirilir (CLAUDE.md §4 faz istisnası). Her paket/küme **ayrı commit** → geri alma tek `git revert`.
2. **Yerel test SERBEST (kullanıcı açıkça istedi):** bu fazlarda `flutter analyze`, ilgili `flutter test`,
   `flutter run --profile` ve cihazda ölçüm yerelde yapılır. CI yine son söz (verify ×3 + perf kapısı + APK bütçesi).
3. **Yerel SDK tuzağı (HAFIZA):** Faz 44 bitene dek `C:\src\flutter-3446\bin\flutter.bat` (3.44.6).
   `C:\src\flutter` (3.47.7) **kilidi bozar** — kullanma. Faz 44'te `C:\src\flutter-3479` kurulur, CI ile aynı.
4. **Cihaz kapısı (her faz):** §2'deki ölçüm seti taban tablosuyla karşılaştırılır. Herhangi bir ölçüm
   **> %10 kötüleşir** ya da **kaydırma p99 > 24 ms** olursa faz birleşmez → neden bulunur ya da o paket
   geri alınır / eski sürümde sabitlenir (gerekçe pubspec yorumu + HAFIZA).
5. **Tahminle düzeltme yok:** çökme → `dart-symbols` + `flutter symbolize`; kasma → profil zaman çizelgesi
   (UI + raster + işçi izolat). `FrameTiming` donmayı göstermeyebilir → ekran kaydı (HAFIZA 2026-11-03).
6. **Sabit tutulan bir paket** ancak sabitleme gerekçesi cihazda **çürütülürse** açılır (shared_preferences_android,
   pdfrx). Çürütülemezse sabit kalır; plan "her şey en son" yerine **"her şey ya en son ya gerekçeli sabit"** ile biter.
7. **Bitti tanımı:** CI yeşil + cihaz kapısı tablosu `docs/perf/2026-11-<faz>.md` + `CIHAZ_TESTI.md` maddeleri işaretli
   + HAFIZA kaydı (karar / kök neden / tuzak) + `KALANLAR.md` güncel.

---

## 1. Mevcut durum (2026-11-07, pub.dev + Flutter sürüm listesi)

**Flutter:** CI 3.44.6 (Dart 3.12). **Son kararlı 3.47.9** (Dart 3.13.7, 2026-10-29).
3.47 bazı güncel paketlerin **ön koşulu**: `pdfrx 2.12` (flutter ≥3.47, sdk ^3.13), `background_downloader 9.6`.

| Paket | Şimdi | En son | Engel / risk | Faz |
|---|---|---|---|---|
| **pdfrx** | 1.3.5 (sabit) | 2.12.0 | 2.4.8 geri alındı (yoğun PDF ~5 FPS) — §Faz 48 | 48 |
| xml | 6.6.1 | 7.1.0 | API kırılımı; 39 dosya | 45 |
| pdf / printing | 3.12 / 5.14 | 3.13.1 / 5.15.1 | pdf 3.13 artık `xml ^7` → zinciri açıyor | 45 |
| syncfusion pdf/core | 33.2 | 35.1.43 | `xml ^7` istiyordu (pdf tutuyordu) — artık çözülür | 45 |
| image | 4.8 (<4.9 aralık) | 4.12.0 | 4.9+ xml ^7, 4.11+ archive yeni API | 45 |
| archive | 4.0.9 | 4.6.0 | `pdf` <4.1 tutuyordu — 3.13'te doğrula | 45 |
| pointycastle | 3.9.1 | 4.0.0 | ana sürüm; 4 dosya (imza/şifre) | 45 |
| share_plus | 10.1 | 13.3.1 | `win32 ^6`; API `SharePlus.instance.share(ShareParams)`; 18 dosya | 46 |
| wakelock_plus | 1.4.0 | 1.8.2 | share_plus 13 ile birlikte (win32 ^6) | 46 |
| permission_handler | 12.0 | 13.0.2 | engel kalktı (cunning çıktı) | 46 |
| file_picker | 8.3 | 13.3.2 | 5 ana sürüm; 18 dosya | 46 |
| open_filex | 4.7 | 5.0.0 | Android 13+ READ_MEDIA istemi (HAFIZA izin sadeliği) | 46 |
| receive_sharing_intent | 1.8.1 (sabit) | 1.9.0 | compileSdk 37 istiyordu — artık 37'deyiz | 46 |
| flutter_local_notifications | 22.3 | 23.0 | API değişikliği olası; tek dosya | 46 |
| flutter_displaymode | 0.6 | 0.7 | 120 Hz (P12) — perf ölç | 46 |
| installed_apps / app_usage | 2.1.1 / 4.0.1 | 2.2.1 / 4.1.0 | compileSdk denetle | 46 |
| shared_preferences_android | 2.4.28 (sabit) | 2.5.4 | JNI kaydı süreç başına → PickerActivity çökmesi | 46 |
| background_downloader | 8.9 | 9.6.6 | Flutter ≥3.47 | 47 |
| google_sign_in | 6.3 | 7.2.0 | **tamamen yeni API** (authenticate + authorizationClient) — Drive | 47 |
| google_mlkit_text_recognition / translation | 0.17 / 0.15 | 1.0.1 / 1.0.1 | 1.0 ana sürüm; 7 dosya | 47 |
| dartssh2 | 2.14 | 4.1.0 | 2 ana sürüm; SFTP | 47 |
| ftpconnect | 2.0 | 3.0.0 | ana sürüm; 3 dosya | 47 |
| Diğerleri (crypto, http, path, provider, url_launcher, webview, video_player, tflite, media_kit …) | güncel | — | — | — |

Araç zinciri (Faz 44'te birlikte): AGP 9 / Gradle / Kotlin (ci/prepare_android.sh şablon yamaları), Java 17,
compileSdk 37, targetSdk 36, NDK, R8 kuralları, 16 KB sayfa denetimi.

---

## 2. Performans ölçüm seti (her fazın kapısı — Faz 43'te taban alınır)

Cihazlar: **Xiaomi 13T** (ana) + **Mi Note 10 Lite** (düşük RAM, kasma kökleri burada çıktı). Profil kipi
(`--profile`), şarj ≥ %50, aynı dosya ağacı (`tool/make_test_tree.py`), MIUI için her ölçümde
`KEYCODE_WAKEUP` + kilit kaydırma (`svc power stayon` yok sayılıyor).

| # | Ölçüm | Araç | Taban hedefi |
|---|---|---|---|
| P1 | Soğuk açılış (ilk kare) | `tool/perf_senaryo.sh` / `am start -W` ×5 medyan | ~430–630 ms |
| P2 | Pano boşta kare / 10 sn | logcat `KARE` + `FrameStats` | 0 |
| P3 | 5.000 öğe kaydırma p90/p99 | `integration_test/perf_senaryolari_test.dart` | p99 ≤ 8–12 ms |
| P4 | Fotoğraf ızgarası 5 savurma | VM zaman çizelgesi `DecompressTexture` + ekran kaydı | en uzun ≤ 21 ms |
| P5 | **PDF "40 Hadis İmam Nevevî"** (54 s., 12 MP saydam arka plan) — ilk sayfa süresi, 54 sayfa kaydırma p90/p99, yakınlaştırma, bellek | zaman çizelgesi (UI + raster + pdfium işçisi) + `screenrecord` 60 fps | 1.3.5 değeri |
| P6 | P5'in **erişilebilirlik hizmeti AÇIK** hâli | `settings get secure enabled_accessibility_services` | 1.3.5 değeri |
| P7 | 100 sayfa metin PDF + taranmış PDF (OCR) | perf senaryosu | — |
| P8 | 100 bin satır xlsx açılış/kaydırma | perf senaryosu | — |
| P9 | Büyük docx açılış, pptx slayt geçişi | perf senaryosu | — |
| P10 | Bellek: pano boşta PSS, PDF açıkken PSS, GPU | `dumpsys meminfo <paket>` | `PerfBudget` |
| P11 | APK boyutu (arm64) + 16 KB | CI | `ci/apk_boyut_tabani.txt` +%2 |
| P12 | Video oynatma (Exo + mpv) ilk kare, 120 Hz durumu | elle + logcat | — |

Kayıt: `docs/perf/2026-11-<faz>.md` → "taban | sonra | fark %" sütunları. Ham çizelgeler `.nomedia`'lı
klasörde, iş sonu silinir (KVKK: belge adı/yolu yazılmaz, "PDF-A (54 s.)" gibi takma ad).

**A/B yan yana kurulum:** eski ve yeni APK aynı telefonda → `DOSYA_R8TEST=1 bash ci/prepare_android.sh`
(`.r8test` kimliği) deseni; yeni sürüm `.r8test` olarak kurulur, iki uygulama aynı dosyayla sırayla ölçülür.

---

## Faz 43 — Ölçüm tabanı ve araçlar (kod değişikliği yok ya da yalnız araç)

1. Telefon bağlantısı: `adb devices`, USB hata ayıklama + "USB ile yükleme" (MIUI), `flutter devices`.
2. Mevcut main (3.44.6 + pdfrx 1.3.5) profil APK'sı → §2'nin P1–P12'si **iki cihazda** → `docs/perf/2026-11-43-taban.md`.
3. `tool/pdf_profil.sh` (yeni): PDF'i `am start -d` ile açar, `--profile` VM servisinden `getVMTimeline`
   (UI/raster/izolat), sabit `input swipe` dizisi, `screenrecord`, sonuçları özetler (P5/P6 tekrarlanabilir olsun).
4. Erişilebilirlik ölçümü için hizmeti açıp kapatma adımları (TalkBack değil — telefondaki mevcut hizmetler
   listesine bak; MIUI/Google hizmetleri çoğu zaman açıktır → P6 gerçek kullanıcı durumudur).
5. `CIHAZ_TESTI.md`'ye **"Yükseltme duman turu"** bölümü (10 dk): açılış, pano, gezgin, paylaş ile gelen
   dosya, dosya seçici (PickerActivity), PDF aç/işaretle/kaydet, Word/Excel/Slayt aç-kaydet, tara, OCR,
   çeviri, bildirim + ön plan iş, video, Drive giriş, SFTP/FTP, Yakındakiler. Her faz sonunda koşulur.
**Bitti:** taban tablosu iki cihazda dolu; araç betikleri depoda.

## Faz 44 — Flutter 3.44.6 → 3.47.9 (Dart 3.13) + Android araç zinciri

1. Önce oku: Flutter 3.45/3.46/3.47 "breaking changes" ve sürüm notları; HAFIZA kuralı: **platform
   varsayılanlarını gözden geçir** (3.27 derin bağlantı dersi) — Impeller (Vulkan/GLES geri düşüş),
   kenardan kenara, geri hareketi (predictive back), metin girişi, `SelectionArea`, semantik değişiklikleri.
2. Deneme: CI elle tetik `flutter_version=3.47.9` (iş `continue-on-error` → ana hattı bozmadan görür).
3. Yerelde `C:\src\flutter-3479` kur; `flutter pub get` → `pubspec.lock` yenile (`--enforce-lockfile` CI'da);
   `environment.sdk` alt sınırı `>=3.13.0`. `integration_test` sdk paketlerinin kilit sürümleri yeniden yazılır.
4. `ci/prepare_android.sh`: yeni şablonun AGP/Gradle/Kotlin sürümleri, `minSdk 24` / `targetSdk 36` /
   `compileSdk 37` / NDK sed'leri yeni şablonda tutuyor mu (satır bulunamazsa betik zaten durur), eklenti
   compileSdk yaması (6b), R8 kuralları. Java 17 yeterli mi (AGP isterse 21).
5. `flutter analyze`: yeni kullanımdan kalkan API'ler → düzelt (göz ardı etme yok, gerekçesiz `ignore` yok).
6. `build-apk.yml` + `CLAUDE.md` + `HAFIZA` "3.44.6" geçen yerler → 3.47.9 (yalnız etkin yerler; tarihî kayıtlar kalır).
7. Cihaz: tam §2 + duman turu. Özellikle P1 (motor açılışı), P3/P4 (raster), P12 (120 Hz, `flutter_displaymode`).
**Geri dönüş:** `FLUTTER_VERSION` tek satır + kilit dosyası revert. **Bitti:** CI 3.47.9'da yeşil, cihaz kapısı geçti.

## Faz 45 — Saf Dart zinciri: xml 7 · pdf 3.13 · printing 5.15 · image 4.12 · archive 4.6 · syncfusion 35 · pointycastle 4

Sıra (her biri ayrı commit, arada analyze + ilgili test):
1. `xml ^7` + `pdf ^3.13` + `printing ^5.15` birlikte (birbirini zorlar). xml 7 kırılımlarını 39 dosyada tara
   (Word/Excel/Slayt ayrıştırıcıları, `xml_events` akışı — `xlsx_stream.dart`). Test: docx/xlsx/pptx fixture
   gidiş-dönüş (bayt farkı ve yapı), `test/perf/*_perf_test.dart`.
2. `image` aralığı → `^4.12` (pubspec yorumundaki engel kalkar), `archive ^4.6` (ZIP yazma hızı: Office kaydetme
   süresini ölç P9). `ZLibDecoder.decodeLazy` gibi yeni API'ler yalnız gerekirse.
3. `syncfusion_flutter_pdf/core ^35`: PDF yazma (imza, karartma, form, sayfa işlemleri, sıkıştırma). Kayıt sonrası
   çıktıyı başka okuyucuda aç (Faz 39 imza doğrulaması).
4. `pointycastle ^4`: PKCS#7 imza + şifreleme yolları; mevcut imzalı PDF testleri.
5. Cihaz: P5/P7 (PDF yazma), P8/P9 (Office), APK boyutu.
**Risk:** xml 7 akış ayrıştırmada bellek/hız değişebilir → büyük xlsx (P8) zorunlu.

## Faz 46 — Android eklenti zinciri (platform kodu olanlar)

Her biri ayrı commit; her commit'ten sonra ilgili duman maddesi cihazda:
1. **share_plus 13 + wakelock_plus 1.8 + permission_handler 13** (win32 ^6 üçlüsü). `Share.shareXFiles` →
   `SharePlus.instance.share(ShareParams(...))` 18 dosya; tek sarmalayıcıya topla (varsa onu kullan).
   İzin bekçisi `permission_simplicity_test` yeşil kalmalı; `StoragePermission` Android 10/11+ dalları cihazda.
2. **file_picker 13:** 18 dosya; SAF seçici, çoklu seçim, `withData` bellek davranışı (büyük dosyada
   `withData:false` kalmalı — bellek P10).
3. **receive_sharing_intent 1.9:** WhatsApp/Gmail'den "Birlikte aç" + paylaş; `content://` adlandırma (HAFIZA 2026-07).
4. **open_filex 5** — ya da izin sadeliği aşama 2: kendi `ACTION_VIEW` + FileProvider köprüsü (`ci/*.kt`) ve
   READ_MEDIA_* izinlerini manifestten çıkar. Öneri: köprü (paket bağımlılığı da biter). Karar fazda.
5. **flutter_local_notifications 23:** `notification_hub.dart`; ön plan servisi, ilerleme bildirimi, iptal.
6. **flutter_displaymode 0.7:** 120 Hz seçimi + hafif profilde kapalı kalması (P12, P2).
7. **installed_apps 2.2.1, app_usage 4.1:** Uygulamalar ekranı `listStaged` süresi.
8. **shared_preferences_android 2.5.4 — sabitleme sınavı:** önce yeni sürümün değişiklik günlüğünde "per-engine /
   detach" düzeltmesi ara. Sonra cihazda: dosya seçici (PickerActivity, ikinci motor) aç → seç → kapat → ana
   uygulamada ayar oku/yaz ×10, R8'li yayın APK'sında (`getAll`). **Çökme yoksa** sabit kalkar; varsa 2.4.28
   kalır + HAFIZA'ya "2.5.4'te de var" yazılır.
**Bitti:** duman turu tam, P1/P2/P10/P11 tabanda.

## Faz 47 — API'si kırılan büyükler: google_sign_in 7 · ML Kit 1.0 · dartssh2 4 · ftpconnect 3 · background_downloader 9

1. **google_sign_in 7** (Drive): `GoogleSignIn.instance.initialize()` + `authenticate()` + `authorizationClient`
   ile Drive kapsamı; sessiz giriş, belirteç yenileme, çıkış. `drive_offline.dart` eşitleme. Cihazda gerçek hesapla
   (kullanıcı) — belirteç/hesap bilgisi HAFIZA'ya yazılmaz.
2. **ML Kit 1.0** (metin tanıma + çeviri): model indirme (isteğe bağlı, APK'ya gömülmez — Anayasa 7), OCR sonucu
   eşitliği (aynı taranmış sayfada karakter farkı), R8 `-dontwarn` kuralları. P7.
3. **dartssh2 4 / ftpconnect 3:** SFTP/FTP bağlan, listele, büyük dosya aktarım hızı (MB/sn önce/sonra).
4. **background_downloader 9.6:** indirme işleri, bildirim, iptal/devam.
**Bitti:** her uzak bağlantı türü cihazda gerçek sunucuyla bir kez çalıştı (kullanıcı sunucusu/ev ağı).

## Faz 48 — PDF: pdfrx 1.3.5 → 2.12 (önce kök neden, sonra geçiş)

### 48.0 Neden geri döndük (HAFIZA 2026-11-03, kaynak okumasıyla doğrulandı)
2.4.8'de "40 Hadis" PDF'inde açılış çok geç, kaydırma ~5 FPS. PDF'in maliyeti **çizimde** (sayfa başı 12 MP saydam
arka plan; poppler 200 dpi'da 4,8 sn/sayfa). Pdfium işleri **tek işçide sırada** → çizim kuyruğunu dolduran her
ek iş kasmaya dönüşür. 2.x'in 1.3.5'te olmayan üç işi:

| # | Neden | 2.4.8 | **2.12.0 (kaynakta bakıldı 2026-11-07)** | Bizim çözüm |
|---|---|---|---|---|
| N1 | Erişilebilirlik açıkken görünen her sayfanın her satırına `Focus`+`Semantics`, her karede | var, kapatılamaz | **HÂLÂ VAR** — `_shouldBuildTextSemantics = forceEnableTextSemantics \|\| SemanticsBinding.instance.semanticsEnabled`, kapatma parametresi yok | yama gerekir (48.3) |
| N2 | Boyama döngüsü önbellekteki her sayfanın metnini yüklüyor | var | **DÜZELTİLDİ** — boyamada metin yükleme `isTextSelectionEnabled` koşuluna bağlı (2.11: "Reduced repeated layout, text extraction, partial rendering") | `kPdfOwnSelectionOff` ile kapalı tutarsak hiç yüklenmez |
| N3 | Kendi metin seçimi varsayılan açık | var | var (parametreyle kapanır) | `kPdfOwnSelectionOff` (zaten yazılı) |
| N4 | **Ölçülmedi:** çizim zamanlaması / kısmi çizim / ilerlemeli yükleme farkı | ? | 2.7 "görünen sayfa önizlemesi öncelikli", 2.10 **render önceliği**, 2.11 gizli görüntüleyiciyi askıya alma + ortak görüntü bütçesi | ölç → parametrele |

Ayrıca 2.4.8'de **bilerek bırakılan geçici çözümler** (basamaklı `getPageRenderingScale`, sığdırma kenetlemesi,
sabit pay, kendi seçim katmanı) 2.x'in kendi zamanlayıcısıyla **çakışmış olabilir** (fazladan yeniden çizim) —
hiçbiri ölçülmedi. Bu da bir şüpheli (N5).

### 48.1 Önce ölç (kod değişmeden)
1. A/B: 1.3.5 (main) ve 2.12 deneme APK'sı (`.r8test`) yan yana; P5 + P6 + P7, iki cihaz.
2. Erişilebilirlik **kapalı** ve **açık** ayrı ayrı → N1'in payı ayrışır.
3. Zaman çizelgesinde: UI izleğinde `Semantics`/`Focus` kurulumu (N1), pdfium işçisindeki iş sırası
   (metin mi çizim mi — N2/N4), raster süresi, aynı sayfanın kaç kez çizildiği (N5: `getPageRenderingScale` her
   değişimde yeni çizim mi tetikliyor).
4. Sonuç tablosu `docs/perf/2026-11-48-pdfrx.md`; baskın neden(ler) HAFIZA'ya **ölçümle** yazılır.

### 48.2 Geçiş (A3.2'nin 17 dosyası; API eşlemesi HAFIZA 2026-11-02'de hazır)
`loadText` → `PdfPageRawText` / `loadStructuredText`, `charRects.boundingRect`, `toRectInDocument`,
`render(backgroundColor:)` int, `PdfImage` her yerde BGRA, `sizeDelegateProvider: PdfViewerSizeDelegateProviderLegacy`,
`PdfTextSearcher` `onViewerReady`'de (2.x Null-check çökmesi — `test/pdf_viewer_open_test.dart` bekçi),
`kPdfOwnSelectionOff` hem görüntüleyici hem düzenleyicide. Ayrıca 2.12 yenilikleri:
- `imageCacheBudget` (ortak) + `maxImageBytesCachedOnMemory` → **`PerfBudget`'tan** (low/mid/high), elle sayı yok (Anayasa 3).
- Gizli görüntüleyiciyi askıya alma (sekme/arka plan) + `releaseCachedImages(keepVisible)` bellek baskısında (P6 yoklaması ile).
- Render önceliği: görünen sayfa yüksek, ön-çizim düşük.
- `PdfPage.renderForDisplay` küçük resim/önizleme yollarında değerlendirilir.

### 48.3 N1 çözümü (ölçüm N1'i baskın gösterirse — büyük olasılıkla P6'da)
Sıralı seçenekler:
1. **Yukarı akışa PR** (espresso3389/pdfrx): `enableTextSemantics` (varsayılan true) ya da yalnız odaktaki sayfa
   için semantik kur. Kabul edilene dek:
2. **Yerel yama:** `third_party/pdfrx/` (2.12.0 kopyası) + `dependency_overrides: pdfrx: path:` — yalnız
   `_shouldBuildTextSemantics`'e parametre; yama `third_party/pdfrx/YAMA.md`'de tek diff olarak belgelenir, her
   pdfrx yükseltmesinde yeniden uygulanır. Erişilebilirlik kaybı yok: sayfa metnini bizim seçim katmanımız/okuma
   modu (TTS) zaten sunuyor; tek sayfalık özet semantik etiket korunur.
3. Paket kopyası istenmezse: erişilebilirlik açıkken PDF'i 1.3.5 davranışına yakın kip (görüntüleyicinin üstünde
   `ExcludeSemantics` **yetmez** — bayrak `SemanticsBinding`'den okunuyor; bu yüzden seçenek 2 önerilir).

### 48.4 Geçici çözümleri ölçerek temizle
Her biri ayrı commit + P5: basamaklı ölçek, sığdırma kenetlemesi, sabit pay. 2.12 kendi yapıyorsa kaldır,
yapmıyorsa yorumla bırak. Kendi seçim katmanı (`pdf_select_layer.dart`) **kalır** (davranış bizim).

### 48.5 Kabul ölçütü (hepsi, iki cihaz, erişilebilirlik açık VE kapalı)
- "40 Hadis" ilk sayfa ≤ 1.3.5 + %10; 54 sayfa kaydırma p99 ≤ 24 ms ve 1.3.5'ten kötü değil; donma (ekran kaydı) yok.
- Bellek (PSS) ≤ 1.3.5 + %10; 100 sayfa metin PDF ve taranmış PDF aynı ölçüt.
- Metin seçimi, arama, işaretleme, form, imza, OCR sayfa metni, düzenleyici — duman turu PDF maddeleri.
- **Ölçüt tutmazsa:** 1.3.5'e dönülür (tek revert), yukarı akış PR'ı + bulgu HAFIZA'ya; plan bir sonraki
  pdfrx sürümünde 48.1'den tekrar.

## Faz 49 — Temizlik ve sürdürülebilirlik

1. Yükseltmelerin artık gereksiz kıldığı geçici çözümler, `dependency_overrides`, gerekçesi kalmamış `ignore`'lar
   (ör. `Printing.convertHtml` — printing 5.15'te durum), pubspec'teki "3.29 dönemi" yorumları.
2. `tool/bagimlilik_denetimi.py` → aylık **rapor** (CI elle/zamanlı iş: `pub outdated --json` özeti Actions
   özetine; otomatik yükseltme YOK). Sabit paketlerin gerekçesi pubspec yorumunda ve tabloda.
3. `ci/*.kt` köprülerinde kullanımdan kalkan Android API'leri (compileSdk 37 uyarıları), Kotlin denetimi.
4. `graphify update .`; HAFIZA §4 "reddedilen yollar"da pdfrx satırını sonuca göre güncelle.

## Faz 50 — Sürüm adayı

1. Tam test takımı (`[tam]`), iki cihazda tam §2 + `CIHAZ_TESTI.md` duman turu + Office uyumluluk (B4) örnekleri.
2. `docs/perf/2026-11-50-sonuc.md`: Faz 43 tabanına göre son tablo (her satır ≤ %10, çoğu iyileşme beklenir).
3. `app_version.dart` ara hane `[minor]`, `v*` etiketi → kalıcı sürüm (arm + arm64 + AAB). `SURUM_ADAYI.md` turu.

---

## Sıra ve gerekçe
**43 → 44 → 45 → 46 → 47 → 48 → 49 → 50.**
Flutter önce, çünkü pdfrx 2.12 ve background_downloader 9 ona bağlı ve yerel 3.47 kilit sorunu da böylece
biter. Saf Dart zinciri (45) platform kodsuz → en az cihaz riski. PDF (48) en riskli olan ve en çok ölçüm
istediği için, geri kalan her şey oturmuş ve taban netleşmişken yapılır (ölçüm farkı yalnız pdfrx'ten gelsin).

## Açılış istemi (her faz için yerel oturuma yapıştır)
> `docs/YUKSELTME_PLANI.md` Faz NN'i yürüt. Telefon bağlı (`adb devices`). §0 kurallarına uy: `faz-NN` dalı,
> her paket ayrı commit, yerelde analyze + ilgili test, cihazda §2 ölçümleri taban tablosuyla karşılaştır;
> kapı geçmezse birleştirme. Bitince PR → CI yeşil → main'e birleştir, HAFIZA + KALANLAR + CIHAZ_TESTI güncelle.
