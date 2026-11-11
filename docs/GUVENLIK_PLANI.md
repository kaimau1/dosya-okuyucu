# GÜVENLİK PLANI — Faz G0–G12 (2026-11-10)

Kullanıcı isteği: *"Güvenlik için tam detaylı, tek seferde tüm güvenliği sağlayacak altyapı/üstyapı
planı; ne yapılacak nasıl yapılacak yazılsın ki alt modeller eksiksiz yapabilsin."*

**Dürüst sınır:** "tek seferde tüm güvenlik" diye bir şey yoktur. Bu plan (a) bugün kodda görülen
açıkları kapatır, (b) aynı açıkların geri gelmesini CI'da engeller, (c) sürüm öncesi denetimi
kurala bağlar. Yeni özellik = yeni yüzey; G0 denetim betiği ve G12 kontrol listesi bu yüzden kalıcıdır.

Bu belge **kod okunarak** yazıldı (2026-11-10, main `01c730f`). Cihazda sızma testi yapılmadı.
"**KANIT**" = dosyada görüldü. "**ÖNCE DOĞRULA**" = şüphe var, ilk adım okumak.

---

## 0. Yürüten modele kurallar (her fazda geçerli)

1. **Sıra:** G0 → G1 → G2 → G3 → G4 → G6 → G7 → G8 → G9 → G10 → G12. G5 ve G11 isteğe bağlı (aşağıda gerekçe).
   Bir oturum = bir faz. Faz bitmeden sıradakine geçme.
2. **Dal:** her faz `faz-GN` dalında (ör. `faz-G1`), iş sonunda PR → CI yeşil → main'e birleştir
   (CLAUDE.md §4 faz istisnası). Her madde **ayrı commit** (geri alma tek `git revert`).
3. **Doğrulama = CI.** Yerelde `flutter test/analyze` koşturma (CLAUDE.md §4). Her maddeye **test yaz**;
   test adı maddede verildi. Test yazılamayan (manifest gibi) maddede kabul ölçütü `tool/guvenlik_denetimi.sh` satırıdır.
4. **Önce oku, sonra değiştir.** Her maddede "Dosya" satırındaki dosyanın ilgili bölümünü oku.
   Madde "KANIT" dese bile satır numaraları kaymış olabilir; `grep` ile bul.
5. **Davranış kırma yasağı:** eski veriyi okuyan göç (migration) yazmadan depolama biçimi değiştirme.
   Her göç maddesinde "eski kayıt → yeni kayıt" testi zorunlu.
6. **Uydurma yok:** bir API'nin var olduğundan emin değilsen paketin kaynağını `~/.pub-cache` ya da
   `pubspec.lock` sürümünden oku. Emin olamadığın maddeyi **yapma**, `KALANLAR.md`'ye "G-N artığı" yaz.
7. **Sürüm notu:** kullanıcıya görünen her değişiklikte commit gövdesine `İyileştirme:`/`Düzeltme:` satırı.
8. **Bitti tanımı (faz):** maddelerin kutuları işaretli + CI yeşil + `HAFIZA.md` kaydı (karar/tuzak) +
   `KALANLAR.md` güncel + cihaz maddeleri `docs/CIHAZ_TESTI.md`'ye "Faz GN" başlığıyla eklendi.
9. **Kripto icat etme.** Yalnız bu belgede adı geçen yapı taşları: AES-256-GCM, HMAC-SHA256,
   PBKDF2-HMAC-SHA256, X25519, HKDF-SHA256, `Random.secure()`, Android Keystore. Hepsi `pointycastle`/`crypto`'da var.
10. **KVKK:** test verisine gerçek TC/hasta/ölçüm/anahtar yazma.

---

## 1. Tehdit modeli (kimden korunuyoruz)

| # | Saldırgan | Örnek | İlgili faz |
|---|---|---|---|
| T1 | Kötü niyetli **dosya** (WhatsApp'tan gelen PDF/DOCX/ZIP/APK) | zip-slip, arşiv bombası, DOCX içi betik/dış bağlantı, PDF "launch" eylemi | G6, G7 |
| T2 | Aynı **Wi-Fi'daki** kişi (kafe, otel, iş yeri) | paylaşım sunucusuna bağlanma, trafiği dinleme, eşleştirme kodu deneme | G4, G5, G8 |
| T3 | Telefondaki **başka uygulama** | dışa açık bileşene sahte Intent, yedekten veri okuma, ekran görüntüsü | G1, G2 |
| T4 | Telefonu **eline alan** kişi (kilit açık) | kasayı PIN deneyerek açma, kayıtlı sunucu parolalarını okuma | G2, G3 |
| T5 | **Tedarik zinciri** | ele geçmiş GitHub Action/pub paketi, sahte güncelleme APK'sı, sızan imza anahtarı | G9 |
| T6 | **Bulut tarafı** (AI) | belge içeriğinin rızasız Google'a gitmesi, anahtarın URL/log'da kalması | G2, G10 |

Kapsam dışı (bilinçli): root'lu/ele geçmiş cihaz, fiziksel adli inceleme, devlet düzeyi saldırgan.

---

## 2. Mevcut durum — bulgular (2026-11-10)

### İyi olanlar (dokunma, yalnız testle kilitle)
- Kasa: AES-256-CTR + HMAC-SHA256 (şifrele-sonra-doğrula), GCM küçük veride, `Random.secure()` — `lib/services/fm/vault_crypto.dart`.
- Gemini anahtarı Android Keystore ile sarılı — `lib/services/key_vault.dart`.
- Arşiv çıkarmada yol denetimi var — `archive_ops.dart` `_safeJoin` + `FsPaths.isInside`.
- Dışarı şifresiz HTTP yasak; yalnız 127.0.0.1 izinli — `ci/res/xml/network_security_config.xml`.
- `DosyaProvider` `MANAGE_DOCUMENTS`, `AjanServisi` `BIND_APP_FUNCTION_SERVICE` ile korunuyor.
- `lib/` içinde sertifika doğrulamasını kapatan kod yok (`badCertificateCallback` araması boş).
- Ayar yedeği sırları dışlıyor — `settings_backup.dart` `secretPrefixes`.
- Tanı raporu kişisel veriyi maskeliyor — `diag_report.dart` `scrub`.
- İmza anahtarı depoda yok, log'a basılmıyor; `--obfuscate` açık.

### Açıklar / zayıflıklar
| No | Önem | Bulgu | Kanıt | Faz |
|---|---|---|---|---|
| B1 | Yüksek | Kayıtlı uzak sunucu parolaları (SMB/FTP/SFTP/WebDAV) SharedPreferences'ta **düz metin** | `models/remote_connection.dart` (`'password': password`), `app_state.dart` `_kRemotes` | G2 |
| B2 | Yüksek | Telefonun FTP sunucu parolası düz metin (`ftpd_password`) | `fm/remote/ftp_service.dart` | G2 |
| B3 | Yüksek | `android:allowBackup` ayarlanmamış (varsayılan açık) → tercihler/kasa dizini bulut/ADB yedeğine girer | `ci/AndroidManifest.xml` `<application>` | G1 |
| B4 | Yüksek | Dışa açık `MainActivity` herhangi bir uygulamadan `dosya_link` / kısayol yolu ekini kabul ediyor; doğrulama **ÖNCE DOĞRULA** | `ci/MainActivity.kt` (`EXTRA_LINK`, `EXTRA_SHORTCUT_PATH`), `lib/screens/app_links.dart` | G1 |
| B5 | Yüksek | Yerel paylaşım sunucuları `0.0.0.0`'a bağlı, düz HTTP + Basic Auth; mobil veri arayüzünden de erişilebilir | `http_share_server.dart`, `ftp_server.dart`, `qr_transfer.dart`, `peer_share.dart`, `slideshow/remote.dart` | G4 |
| B6 | Yüksek | Eşler arası eşleştirme kodu 4 hane, `Random()` (güvenli değil), **isteğe bağlı**, deneme sınırı yok | `peer_share.dart` `newCode`, `codeOk` | G4 |
| B7 | Orta | Word WebView: JS sınırsız, **CSP yok**, gezinti kısıtı (`onNavigationRequest`) yok → belgedeki bağlantı/dış kaynak WebView içinde açılabilir | `widgets/docx_view.dart`, `assets/word/viewer.html` | G6 |
| B8 | Orta | Gemini anahtarı **URL sorgusunda** (`?key=`) — vekil/log'larda görünür | `gemini_service.dart` | G2 |
| B9 | Orta | Kasa PIN'i PBKDF2 120.000 tur (güncel öneri ≥ 600.000); PIN deneme sınırı/gecikmesi **ÖNCE DOĞRULA** | `vault_crypto.dart` `pinIterations`, `secure_vault.dart` | G3 |
| B10 | Orta | Kasa/PIN ekranlarında `FLAG_SECURE` yok → ekran görüntüsü, son uygulamalar önizlemesi | arama boş | G1 |
| B11 | Orta | GitHub Actions sürüm etiketiyle (`@v4`, `@v2`) çağrılıyor, SHA'ya sabit değil; iş akışı düzeyi `contents: write` | `.github/workflows/build-apk.yml` | G9 |
| B12 | Orta | Kalıcı anahtar yokken derleme geçici anahtarla **uyarı verip sürüyor** (v* etiketinde de) | `build-apk.yml` "İmza anahtarını hazırla" | G9 |
| B13 | Orta | Kendi kendini güncelleme APK'sında özet (SHA-256) denetimi ve sürüm düşürme engeli yok (imza denetimini Android yapıyor) | `services/app_update.dart`, `ci/ApkKurulum.kt` | G9 |
| B14 | Orta | Dependabot, `SECURITY.md`, bağımlılık açık taraması yok | `.github/` | G9 |
| B15 | Orta | Intent süzgeci `http/https` + `host="*"` ve `file://` VIEW kabul ediyor — gereklilik **ÖNCE DOĞRULA** | `ci/AndroidManifest.xml` ~275–324 | G1 |
| B16 | Düşük | SFTP sunucu anahtarı doğrulaması (ilk bağlantıda güven) **ÖNCE DOĞRULA** | `fm/remote/sftp*.dart` | G8 |
| B17 | Düşük | `checkBasicAuth` düz `==` karşılaştırma (zamanlama farkı), deneme sınırı yok | `http_share_server.dart` | G4 |
| B18 | Düşük | 30 izin; Play derlemesinde gereksizler duruyor | `ci/AndroidManifest.xml`, `ci/play_variant.py` | G1 |

---

## Faz G0 — Altyapı: denetim betiği + envanter (ilk iş, kısa)

Amaç: açıkların geri gelmesini CI yakalasın.

- [x] **G0.1 `tool/guvenlik_denetimi.sh`** yaz (bash, `set -euo pipefail`, Flutter gerektirmez). Her kural
      ihlalde `::error::` basıp `exit 1`. Kurallar (her biri ayrı işlev, başına açıklama):
  1. `lib/` içinde `badCertificateCallback`/`onBadCertificate` → yasak.
  2. `lib/` içinde `Random()` (güvenli olmayan) yalnız izin listesindeki dosyalarda; liste betiğin başında
     (`docx_media.dart` gibi sır üretmeyenler). Yeni kullanım → hata, mesaj: "sır/kod üretiyorsan `Random.secure()`".
  3. `lib/` içinde `?key=`, `&key=`, `password=` içeren `Uri.parse(` → yasak (G2.4'ten sonra açılır).
  4. `ci/AndroidManifest.xml`: `android:allowBackup="false"` var; her `android:exported="true"` bileşen
     betikteki **izin listesinde** (ad + gerekçe). Listede olmayan yeni dışa açık bileşen → hata.
  5. `ci/res/xml/network_security_config.xml`: `cleartextTrafficPermitted="true"` yalnız `127.0.0.1`/`localhost`.
  6. `.github/workflows/*.yml`: her `uses:` 40 haneli SHA ile bitiyor (G9.1'den sonra açılır).
  7. `lib/` içinde `HttpServer.bind(`/`ServerSocket.bind(`/`RawDatagramSocket.bind(` çağrıları izin listesinde
     (dosya adı + gerekçe). Yeni sunucu → hata.
  8. `lib/` içinde `JavaScriptMode.unrestricted` kullanan dosyalar izin listesinde.
  9. Depoda `*.jks`, `*.keystore`, `google-services.json`, `AIza[0-9A-Za-z_-]{35}` deseni yok.
  - Henüz kapanmamış kurallar `BEKLEYEN="3 4 6"` gibi bir değişkenle **uyarı** kipinde başlar; ilgili faz bitince listeden çıkarılır.
- [x] **G0.2 CI'ya bağla:** `build-apk.yml` `verify` 0. parçasına (analyze'ın yanına) adım: `bash tool/guvenlik_denetimi.sh`.
      `changes` süzgecine `tool/guvenlik_denetimi.sh` ve `ci/AndroidManifest.xml` ekli mi bak.
- [x] **G0.3 `docs/guvenlik/ENVANTER.md`:** üç tablo — (a) dışa açık bileşenler + koruması, (b) açılan ağ
      portları + kimlik doğrulaması, (c) diske yazılan sırlar + nerede/nasıl. Bu belgenin §2'sinden başla, kodu okuyarak tamamla.
- [x] **G0.4 `SECURITY.md`** (kök): açık bildirme adresi (kullanıcıdan iste — 👤), desteklenen sürüm = son sürüm, 90 gün açıklama süresi.

Bitti: betik CI'da koşuyor, bekleyen kurallar listeli, envanter dolu.

---

## Faz G1 — Android platform sertleştirme

- [x] **G1.1 Yedeklemeyi kapat (B3).** `ci/AndroidManifest.xml` `<application>`'a `android:allowBackup="false"`
      ve `android:dataExtractionRules="@xml/data_extraction_rules"` ekle. `ci/res/xml/data_extraction_rules.xml` oluştur:
      `<data-extraction-rules><cloud-backup><exclude domain="root"/><exclude domain="sharedpref"/><exclude domain="database"/><exclude domain="file"/></cloud-backup><device-transfer>` (aynı dışlamalar) `</device-transfer></data-extraction-rules>`.
      `ci/prepare_android.sh` `res/xml` kopyalıyor mu doğrula (diğer xml'lerin nasıl taşındığına bak, aynısını yap).
      **Bedel:** telefon değiştirirken ayarlar taşınmaz → uygulamanın kendi "Ayar yedeği" zaten var; sürüm notuna yaz.
- [x] **G1.2 Dışa açık `MainActivity` girdilerini doğrula (B4).**
  - `ci/MainActivity.kt`: `EXTRA_LINK` ve `EXTRA_SHORTCUT_PATH` okunan her yeri bul. Bu ekler yalnız **bizim** widget/bildirim/kısayolumuzdan gelmeli.
    Çözüm: bu Intent'leri üreten her yerde (`Extras.kt`, widget'lar, kısayol) ek olarak `EXTRA_SIG = HMAC-SHA256(süreçte bir kez üretilip `filesDir/link_key` içine yazılan 32 rastgele bayt, link metni)` koy; `MainActivity` imza tutmuyorsa eki **yok say**.
  - Dart: `lib/screens/app_links.dart` `openAppLink` — kabul edilen bağlantı biçimlerini **beyaz liste** yap (bilinen ekran adları + var olan dosya yolu). Yol: `p.normalize` sonrası uygulamanın özel dizinini (`/data/`), kasa dizinini gösteriyorsa reddet.
  - Test: `test/app_links_guvenlik_test.dart` — `../`, `/data/data/...`, kasa yolu, bilinmeyen şema → açılmaz.
  - Kotlin testi: `tool/kotlin_tests` altına imza doğrulama birimi.
- [x] **G1.3 Intent süzgeçlerini daralt (B15).** Manifest ~270–325: `http/https host="*"` süzgeci hangi özellik için (indirme yöneticisi?) — HAFIZA'da `grep -n 'host="\*"\|indirme yöneticisi' HAFIZA.md docs/hafiza/*.md`. Gerekçe yoksa kaldır; varsa yalnız MIME/uzantılı biçimi bırak. `file://` şeması: Android 7+ başka uygulamalar `file://` gönderemez; kaldırılabilir mi doğrula (eski dosya yöneticileri hâlâ gönderiyor olabilir → kalacaksa Dart tarafında yol G1.2 denetiminden geçsin).
      **Sonuç (doğrulandı, kod DEĞİŞMEDİ):** `host="*"` süzgeci "İndirme bağlantısına dokununca seçenek olarak çık" özelliği
      (kullanıcı isteği 2026-07-29, manifest yorumu) ve zaten yalnız indirilebilir uzantı `pathPattern`'leriyle sınırlı; ikinci
      süzgeç yalnız apk/zip/octet-stream MIME'li. Gerekçeli → kalır. `file://` süzgeçleri: Android 7+ hedefli gönderen uygulamalar
      `file://` yollayamaz ama eski dosya yöneticileri yollayabilir (dış açık kullanım) → kaldırmak davranış kırar, kalır;
      uygulama içi bağlantı/kısayol yolları G1.2 beyaz listesinden geçiyor. **G1 artığı:** dışarıdan gelen VIEW `file://`
      yolunun özel dizin denetimi (KALANLAR).

- [x] **G1.4 `FLAG_SECURE` (B10).** `ci/Extras.kt`'ye yöntem kanalı `setSecure(bool)` (`window.setFlags/clearFlags(WindowManager.LayoutParams.FLAG_SECURE)`). Dart: `lib/core/secure_screen.dart` — `SecureScreen` widget'ı (`initState` → true, `dispose` → false, sayaçlı: iç içe ekranlarda erken kapanmasın). Sar: `vault_screen.dart`, PIN giriş pencereleri, uygulama kilidi ekranı, AI anahtar girişi, uzak bağlantı parola formu. Kasadan açılan görüntüleyici de (kasa bayrağı ile).
- [x] **G1.5 İzin diyeti (B18).** `ci/play_variant.py` varsayılan çıkarma listesine ekle: `REQUEST_INSTALL_PACKAGES`, `PACKAGE_USAGE_STATS`, `QUERY_ALL_PACKAGES`, `READ_MEDIA_*`, `ACCESS_FINE_LOCATION` (Nearby için API 33+ `NEARBY_WIFI_DEVICES` + `neverForLocation` yeter mi **ÖNCE DOĞRULA**; konuma `android:maxSdkVersion="32"` koy). Çıkarılan iznin özelliği Play derlemesinde gizlenmeli (`dart-define` bayrağı var mı bak). GitHub derlemesi değişmez.
      **Sonuç:** `ACCESS_FINE_LOCATION` zaten `maxSdkVersion=32`, `NEARBY_WIFI_DEVICES` zaten `neverForLocation`; iş akışı Play listesi zaten `QUERY_ALL_PACKAGES`+`READ_MEDIA_*` çıkarıyor, `play_variant.py` varsayılanı ona hizalandı. `REQUEST_INSTALL_PACKAGES` / `PACKAGE_USAGE_STATS` çıkarılmadı: APK kurma / "son açılma" özelliklerinin Play derlemesinde gizlenmesi (dart-define) gerekir → KALANLAR "G1 artığı" (B5.3 kararıyla birlikte).
- [x] **G1.6 `requestLegacyExternalStorage`:** targetSdk 36'da etkisiz; kaldır (minSdk 24–28 cihazda `WRITE_EXTERNAL_STORAGE` yolu bozulmuyor mu **ÖNCE DOĞRULA**; Android 10 tek sürüm bu bayrağa muhtaç → o zaman bırak ve gerekçeyi yoruma yaz).
      **Sonuç:** kaldırılmadı: Android 10 (API 29) cihazda ortak depolama bu bayrağa bağlı (HAFIZA Faz 2/D9); manifest yorumuna gerekçe yazıldı.
- [x] **G1.7 Bekleyen Intent'ler:** `ci/*.kt` içinde her `PendingIntent.get*` → `FLAG_IMMUTABLE` var mı (`grep -n PendingIntent ci/*.kt`); değiştirilebilir olan varsa gerekçesiz ise düzelt, `setPackage` ekle.
      **Sonuç:** tüm `PendingIntent`ler `FLAG_IMMUTABLE`; yalnız `ApkKurulum.kt` (PackageInstaller) ve `UsbMass.kt` (UsbManager) `FLAG_MUTABLE` — sistem yanıt ekini doldurduğu için ŞART, ikisi de açık `setPackage(paketimiz)` kullanıyor. Değişiklik yok.
- [x] **G1.8 Yayın alıcıları:** Kotlin'de `registerReceiver(` çağrıları API 33+ `RECEIVER_NOT_EXPORTED` ile mi (`grep -n registerReceiver ci/*.kt`).
      **Sonuç:** `ApkKurulum`/`UsbMass` alıcıları `RECEIVER_NOT_EXPORTED`; `MainActivity` USB/medya sistem yayınları `RECEIVER_EXPORTED` (bilinçli, yorumda gerekçe: bazı ROM'larda NOT_EXPORTED sistem yayınını ulaştırmıyor); `NearbyBgService` Bluetooth durumu (sistem yayını, kişisel derleme) ve `SdUnion` batarya (alıcısız anlık okuma) bayraksız — sistem yayını, dışarıdan tetiklenemez. Değişiklik yok.

Bitti: `guvenlik_denetimi.sh` kural 4 "bekleyen"den çıktı; CIHAZ_TESTI'ye: widget dokunuşu, kısayol, "Birlikte aç", kasa ekran görüntüsü engeli.

---

## Faz G2 — Sırlar: diskte, ağda, logda

- [x] **G2.1 Uzak sunucu parolaları Keystore'a (B1).** `RemoteConnection.encode()` parolayı JSON'a düz yazıyor. Yeni akış: `AppState` kaydederken parolaları JSON'dan **ayır**, `{id: parola}` haritasını `KeyVault.seal` ile sarıp `fm_remote_secrets` anahtarına yaz; yüklerken `KeyVault.open` ile geri koy. **Göç:** yüklemede JSON'da `password` alanı varsa → sırlara taşı, JSON'u parolasız yeniden yaz. `KeyVault` sarma başarısızsa (Keystore yok) mevcut davranışa (düz) düş ama ekranda uyarı satırı göster ("bu cihazda parola korumasız saklanıyor"). Test: `test/remote_secret_migration_test.dart` (eski kayıt → yeni kayıt, parola korunur, prefs'te düz parola kalmaz).
- [ ] **G2.2 FTP sunucu parolası (B2).** `ftp_service.dart` `_kPassword` → aynı `KeyVault` yolu + göç. Rastgele parola kipinde parola **hiç diske yazılmasın** (oturumluk).
- [ ] **G2.3 Diğer sırlar envanteri.** `grep -rnE "setString\(|setStringList\(" lib | grep -iE "token|secret|pass|parola|pin|key|sifre"` → çıkan her anahtarı G0.3 envanterine yaz; düz metin sır ise G2.1 kalıbıyla taşı. Özellikle: Drive erişim/yenileme belirteci, OpenSubtitles anahtarı, `app_lock_pin`/`fm_lock_pin` (PIN **asla** düz ya da tek tur özetle saklanmaz → G3.3).
- [ ] **G2.4 Gemini anahtarı başlığa (B8).** `gemini_service.dart`: `?key=$apiKey` kaldır, tüm isteklere `x-goog-api-key: <anahtar>` başlığı. `models` listesi çağrısı dahil. Test: sahte `http.Client` ile URL'de `key=` yok, başlıkta var.
- [ ] **G2.5 Log/çökme kaydı temizliği.** `crash_log.dart` yazmadan önce `diag_report.dart` `scrub`'ı uygula (aynı işlevi paylaş). `scrub` desenlerine ekle: `AIza…` anahtarı, `Authorization:` satırı, `://kullanıcı:parola@` URL, `key=`/`token=`/`kod=` sorgu değerleri. Test: `test/scrub_test.dart` her desen için.
- [ ] **G2.6 Pano.** Parola/anahtar/kasa içeriği panoya kopyalanırken Android 13+ `ClipDescription.EXTRA_IS_SENSITIVE` işaretle (Kotlin `Extras.kt` yöntem kanalı `copySensitive`); 60 sn sonra pano hâlâ aynıysa temizle.
- [ ] **G2.7 Bellek:** PIN/parola `String`'leri uzun ömürlü alanlarda tutulmasın — kasa ana anahtarı `Uint8List`, kilitlenince `fillRange(0, len, 0)`. `secure_vault.dart` `lock()` bunu yapıyor mu bak.
- [ ] **G2.8 Geçici dosyalar.** Kasadan açılan dosyanın düz kopyası nereye yazılıyor (`grep -n "getTemporaryDirectory\|cache" lib/services/fm/secure_vault.dart lib/screens/fm/vault_screen.dart`)? Uygulamanın **özel** önbelleğinde olmalı, görüntüleyici kapanınca ve açılışta (çökme sonrası) silinmeli. Test ekle.

Bitti: `guvenlik_denetimi.sh` kural 3 açıldı; envanterde "düz metin" satırı kalmadı (kalanın gerekçesi yazılı).

---

## Faz G3 — Kasa, PIN, uygulama kilidi

- [ ] **G3.1 PBKDF2 turu (B9).** `pinIterations` 120.000 → **600.000**. Kasa başlığında tur sayısı saklanıyor mu bak; saklanmıyorsa başlığa sürüm/tur alanı ekle (eski başlık = 120.000 varsay). **Göç:** doğru PIN ile ilk açılışta ana anahtarı yeni turla yeniden sar. Türetme `Isolate.run` içinde (600k tur orta telefonda ~1 sn; UI donmasın). Test: eski başlık açılır → yeniden sarılır → yeni turla açılır.
- [ ] **G3.2 Deneme sınırı.** Kalıcı sayaç (`vault_fail_count`, `vault_fail_at`): 5 yanlıştan sonra 30 sn, sonra her yanlışta iki katı (en çok 1 saat). Sayaç doğru PIN'de sıfırlanır; saat geri alınırsa (şimdi < `fail_at`) bekleme baştan başlar. Arayüzde kalan süre. Aynı kural uygulama kilidi ve klasör kilidi PIN'ine. Test: `test/pin_backoff_test.dart` (saat enjekte edilir).
- [ ] **G3.3 PIN saklama.** `app_lock_pin`/`fm_lock_pin` nasıl saklanıyor oku. Hedef: `salt(16) + PBKDF2(600k)` özeti, karşılaştırma sabit zamanlı. Düz ya da tek SHA ise göç: eski değerle doğrula → yeni biçime yaz → eskiyi sil.
- [ ] **G3.4 Biyometri.** `secure_vault.dart` biyometrik açılışta ana anahtar `NativeExtras.wrapKey` ile sarılı. `ci/Extras.kt`: Keystore anahtarı `setUserAuthenticationRequired(true)` ve `setInvalidatedByBiometricEnrollment(true)` ile mi üretiliyor? Değilse biyometri yalnız "arayüz kapısı"dır (atlanabilir) → kasa için **ayrı** bir Keystore anahtarı üret (kimlik doğrulama zorunlu, `BiometricPrompt.CryptoObject` ile aç). Gemini anahtarının sarma anahtarı değişmez.
- [ ] **G3.5 Otomatik kilit.** Uygulama arka plana geçince kasa N sn sonra (varsayılan 0 = hemen) kilitlensin; ayar `vault_autolock_secs`. `WidgetsBindingObserver.paused`.
- [ ] **G3.6 Dürüst etiket.** `folder_lock.dart` şifrelemiyor (yalnız kapı) — arayüz metninde "şifreler" denmiyor mu doğrula; kasada "PIN unutulursa dosyalar kurtarılamaz" uyarısı ilk kurulumda var mı.
- [ ] **G3.7 Sabit vektör testi.** `test/vault_crypto_kat_test.dart`: sabit anahtar/IV ile bilinen çıktı (biçim `DVK1` kazara değişmesin); bozuk MAC → açılmaz; kesik dosya → açılmaz; 1 bayt değişik → açılmaz.

---

## Faz G4 — Yerel sunucular (aynı ağdaki saldırgan)

Sunucular: `http_share_server.dart`, `ftp_server.dart`, `qr_transfer.dart`, `peer_share.dart` (HTTP + UDP keşif), `slideshow/remote.dart`, `voice/neural_voices.dart` (yalnız 127.0.0.1 — iyi).

- [ ] **G4.1 Bağlama arayüzü (B5).** `anyIPv4` yerine: `NetworkInterface.list()` → özel adresli (10/8, 172.16/12, 192.168/16, 169.254/16) Wi-Fi/hotspot/USB arayüzleri; yalnız onlara bağlan. Ortak yardımcı `lib/services/fm/remote/lan_bind.dart` (`Future<List<InternetAddress>> lanAddresses()`, `bool isPrivate(InternetAddress)`). Bağlanamazsa `anyIPv4`'e düş **ama** her istekte `request.connectionInfo.remoteAddress` özel aralıkta değilse 403. Test: `isPrivate` tablosu (genel IP, CGNAT 100.64/10 → reddet, IPv6 fe80 → kabul).
- [ ] **G4.2 Kimlik doğrulama varsayılanı.** HTTP paylaşım ve FTP: parola **varsayılan zorunlu ve rastgele** (`Random.secure`, 8+ karakter, karışık). "Parolasız" seçeneği kalacaksa açık uyarı + oturum bitince kapanır. QR'daki adres parolayı içeriyorsa `http://u:p@host` yerine tek kullanımlık **belirteç yolu** (`/t/<128 bit base64url>/…`) kullan — tarayıcı geçmişinde Basic kimlik kalmasın.
- [ ] **G4.3 Sabit zamanlı karşılaştırma + deneme sınırı (B17).** `checkBasicAuth` → bayt bayt XOR karşılaştırma. IP başına 10 hatalı denemeden sonra 60 sn 429. FTP `PASS` için de. Test var olan `http_share`/`ftp_server` testlerine eklenir.
- [ ] **G4.4 Eşleştirme kodu (B6).** `peer_share.dart` `newCode`: `Random.secure()`, **6 hane**. Kod doğrulaması sabit zamanlı; 5 yanlış denemeden sonra kod **yenilenir** ve o IP 60 sn reddedilir. "Kodsuz + onay penceresi" kipi kalabilir (kullanıcı kararı, HAFIZA 2026-10-28) ama güvenilen cihaz (`trusted_peers.dart`) kimliği **neye dayanıyor oku**: yalnız ad/IP ise taklit edilebilir → G5'e kadar güvenilen cihazdan gelen dosyada da ilk seferde onay iste. Protokol uyumu: eski sürüm 4 hane gönderir → sürüm alanına bak, 4 haneyi yalnız eski eşle kabul et; Windows exe (`tool/pc_aktar`) aynı değişikliği alır.
- [ ] **G4.5 Yükleme sınırları.** Her sunucuda: istek başlığı ≤ 16 KB, JSON gövde ≤ 1 MB (`takeBytes` öncesi say), eşzamanlı bağlantı ≤ 16, boşta zaman aşımı 60 sn, yüklemede boş disk denetimi (kalan < 200 MB → 507). Dosya adı: `uploadFileName` zaten `.`/`..` reddediyor — ekle: denetim karakterleri, `/` `\`, 255 bayt üstü, Windows ayrılmış adları (`CON`, `NUL`…).
- [ ] **G4.6 Yanıt başlıkları.** HTML üreten sunucularda: `X-Content-Type-Options: nosniff`, `Content-Security-Policy: default-src 'none'; style-src 'unsafe-inline'; img-src 'self' data:; form-action 'self'`, `X-Frame-Options: DENY`, `Referrer-Policy: no-referrer`, `Cache-Control: no-store`. İndirilen dosyalarda `Content-Disposition: attachment` (HTML/SVG dosyası tarayıcıda **çalışmasın**).
- [ ] **G4.7 CSRF.** Tarayıcıdan yükleme/silme uçları: `Origin`/`Host` başlığı sunucunun kendi adresiyle eşleşmiyorsa 403 (DNS yeniden bağlama + başka siteden form gönderme).
- [ ] **G4.8 Yaşam süresi.** Her sunucu yalnız ilgili ekran/servis açıkken yaşıyor mu (HAFIZA 2026-09 "yalnız Al ekranı açıkken") — hepsi için doğrula; 30 dk etkinlik yoksa kendini kapat, bildirimi kaldır.
- [ ] **G4.9 Slayt kumandası** (`slideshow/remote.dart`): kimlik doğrulama var mı oku; yoksa G4.2 belirteç yolu.
- [ ] **G4.10 Yol kaçışı testleri.** `test/server_traversal_test.dart`: `/../`, `%2e%2e/`, `..%5c`, çift kodlama, boş bayt, mutlak yol, sembolik bağ hedefi kök dışı → 403/404. FTP `CWD`/`RETR`/`STOR`/`RNFR`/`RNTO` için aynı liste.

Bitti: `guvenlik_denetimi.sh` kural 7 izin listesi güncel; CIHAZ_TESTI: iki telefon + Windows exe ile gönder/al, mobil veri açıkken dışarıdan port kapalı.

---

## Faz G5 — Eşler arası aktarımı şifrele (isteğe bağlı, büyük)

Gerekli mi: **Orta.** Bugün aynı Wi-Fi'da trafiği dinleyen dosyayı görür. Ev ağında risk düşük, ortak ağda gerçek. Bedel: protokol sürümü + Windows exe + eski sürüm uyumu; ~1 faz. G4 bitmeden başlama.

- [ ] Tasarım: her oturumda X25519 geçici anahtar çifti; ortak sır → HKDF-SHA256(`salt = eşleştirme kodu`, `info = "dosya-aktar v2"`) → 2 anahtar (yön başına). Parça biçimi: `nonce(12, sayaç) + AES-256-GCM(1 MB parça) + etiket`. Kod uyuşmazsa ilk parça açılmaz → bağlantı kes. Kodsuz kipte iki ekranda 6 haneli **doğrulama sayısı** (ortak sırrın özeti) gösterilir.
- [ ] Güvenilen cihaz = karşı tarafın **kalıcı** X25519 açık anahtarının özeti (ad/IP değil).
- [ ] Eski sürüm eşle düz protokol sürer ama ekranda "şifresiz" rozeti.
- [ ] Test: bilinen vektör, sıra dışı/yinelenen parça reddi, yanlış kod.

---

## Faz G6 — WebView

- [ ] **G6.1 CSP (B7).** `assets/word/viewer.html` `<head>` başına:
      `<meta http-equiv="Content-Security-Policy" content="default-src 'none'; script-src 'self' 'unsafe-inline'; style-src 'self' 'unsafe-inline'; img-src data: blob:; font-src data: blob:; connect-src 'none'; frame-src 'none'; object-src 'none'; base-uri 'none'; form-action 'none'">`.
      `docx-preview` görselleri `blob:`/`data:` ile mi basıyor doğrula (`tool/check_word_bridge.js` var — onunla dene). `'unsafe-eval'` gerekirse **ekleme**, nedenini bul.
- [ ] **G6.2 Gezinti kilidi.** `docx_view.dart` `NavigationDelegate`'e `onNavigationRequest`: URL `viewer.html`'in kendisi değilse `NavigationDecision.prevent`; `http/https` ise kullanıcıya "Bağlantıyı tarayıcıda aç?" sor (tam adresi göster). `neural_engine.dart` için: yalnız `server.origin` izinli.
- [ ] **G6.3 Dosya erişimi.** `AndroidWebViewController`: `setAllowFileAccess(false)`, `setAllowContentAccess(false)` (varlık `loadFlutterAsset` bundan etkilenir mi **ÖNCE DOĞRULA** — etkileniyorsa yalnız içerik erişimini kapat), `setGeolocationEnabled(false)`, karışık içerik `never`. Paket sürümünde bu yöntemlerin adını kaynaktan doğrula.
- [ ] **G6.4 Kanal mesajları.** `Sayfa`/`Durum`/`Kalem` JS kanallarından gelen her mesaj: boyut sınırı (≤ 256 KB), `jsonDecode` try/catch, alan türü denetimi; mesajdaki değer **asla** dosya yolu/komut olarak kullanılmasın. Belge içeriği HTML'e `textContent` ile mi `innerHTML` ile mi giriyor — `viewer.html` betiğini oku; Dart'tan `runJavaScript`'e gömülen her metin `jsonEncode` ile kaçırılıyor mu.
- [ ] **G6.5 Yerel ses sunucusu.** `neural_voices.dart` 127.0.0.1 sunucusu: başka uygulama da bağlanabilir → rastgele yol öneki (`/<128 bit>/engine.html`), yalnız `assets/voice` altı, dizin kaçışı testi, `Host` başlığı `127.0.0.1:<port>` değilse 403.
- [ ] **G6.6 Test:** `test/fixtures/office/kotu_niyetli.docx` — içinde dış görsel (`http://…`), `javascript:` bağlantısı, `<script>` içeren altChunk/HTML. Beklenen: ağ isteği yok, betik çalışmaz. (`tool/make_word_fixtures.py`'ye üretici ekle.)

---

## Faz G7 — Güvenilmeyen dosya girdisi

- [ ] **G7.1 Arşiv bombası.** `archive_ops.dart` çıkarma: toplam açılmış boyut sınırı (varsayılan min(boş disk − 500 MB, 20 GB)), giriş sayısı ≤ 200.000, tek girişte sıkıştırma oranı > 1000× ise kullanıcıya sor, iç içe arşiv otomatik açılmaz. Sınır aşımında kısmi çıktıyı sil. Test: 1 KB → 1 GB sıfır dolu zip (testte üret).
- [ ] **G7.2 Yol testleri.** `_safeJoin` için: `../x`, `/etc/x`, `C:\x`, `a/../../x`, sonu boşluk/nokta, NUL içeren ad, 4096+ karakter. Sembolik bağ girişi (tar/zip unix modu `0xA000`) → **oluşturma**, atla ve raporla. Aynı testleri `koni_archive` (RAR/7z) yolu için.
- [ ] **G7.3 Office paketleri.** DOCX/XLSX/PPTX birer zip: açmadan önce (a) giriş sayısı ≤ 10.000, (b) tek XML ≤ 200 MB açılmış, (c) toplam ≤ 1 GB; aşarsa "dosya çok büyük/bozuk" hatası. `xml` paketi dış varlık (XXE) çözmez — `<!DOCTYPE` + `<!ENTITY` içeren XML'de "milyar kahkaha" denemesi testi yaz, sonuç: bellek patlamaz.
- [ ] **G7.4 Office dış bağlantılar.** Belgedeki `TargetMode="External"` ilişkiler (dış görsel, OLE, şablon) **otomatik getirilmez**; köprüye dokununca tam adres gösterilip sorulur; `file:`, `content:`, `intent:`, `javascript:` şemaları reddedilir. Makrolu dosya (`.docm/.xlsm`, `vbaProject.bin`) açılır ama makro çalışmaz (zaten motor yok) — kullanıcıya tek satır bilgi + kaydederken makroyu **koruyor muyuz/atıyor muyuz** dürüstçe yaz.
- [ ] **G7.5 Excel formül enjeksiyonu.** CSV dışa aktarmada `=`, `+`, `-`, `@`, sekme ile başlayan hücre → başına `'` (ayar: açık varsayılan). `HYPERLINK`/`WEBSERVICE`/DDE (`=cmd|…`) işlevleri ağ/komut çalıştırmaz — `formula_engine.dart`'ta doğrula, test ekle.
- [ ] **G7.6 PDF.** pdfrx/PDFium: JavaScript, `Launch`, `GoToR`, `SubmitForm`, `ImportData` eylemleri çalışmamalı — pdfrx bağlantı geri çağrısında yalnız `http/https/mailto` + sorarak aç. Gömülü dosya (ek) açılırken uzantıya göre uyar (`.apk`, `.html`, `.js`). Şifreli PDF parolası diske/log'a yazılmasın. `pdfrx`/`pdfium_dart` güvenlik güncellemeleri G9.4 ile izlenir (PDFium bellek hataları yerel kod çalıştırmaya gider — **güncel tutmak tek savunma**).
- [ ] **G7.7 Görsel/medya.** Görsel çözmeden önce boyut başlığını oku: genişlik×yükseklik > 100 MP → küçültülmüş çöz ya da reddet (bellek bombası). SVG gösteriliyorsa betik/dış kaynak işlenmez.
- [ ] **G7.8 APK/.apks kurulumu.** `ApkKurulum.kt`: kurmadan önce ekranda paket adı, sürüm, **imza SHA-256 parmak izi**, "yüklü sürümle aynı imza mı" göster. ZIP içi `.apk` adlarında yol ayırıcı reddi, oturuma yazılan toplam boyut sınırı. Kendi paketimizin adıyla gelen yabancı imzalı APK → kırmızı uyarı.
- [ ] **G7.9 Bulanık test (fuzz).** `test/fuzz/` — her ayrıştırıcıya (`xlsx_reader`, `office_reader`, `ole_cfb`, `xls_legacy`, `csv_codec`, `office_crypto`, `PdfFile.parse`, `archive_ops` listeleme, `text_decode`) sabit tohumlu 500 bozulmuş girdi (fixture'dan bayt çevirme/kesme/tekrar). Beklenen: istisna **yakalanır**, sonsuz döngü yok (test başına 10 sn zaman aşımı), bellek < 512 MB. `[tam]` koşusunda çalışır (her push'ta değil — `dart_test.yaml` etiketi `fuzz`).
- [ ] **G7.10 İndirilenlerde uzantı aldatması.** `rapor.pdf.apk`, RTL geçersiz kılma karakteri (U+202E) içeren adlar: listede gerçek uzantı vurgulanır, U+202A–202E/2066–2069 görünür işaretle gösterilir. Test.

---

## Faz G8 — Uzak bağlantılar (istemci tarafı)

- [ ] **G8.1 SFTP sunucu anahtarı (B16).** `dartssh2` `SSHClient(onVerifyHostKey:)` kullanılıyor mu oku. Hedef: ilk bağlantıda parmak izini göster + onayla (TOFU), `RemoteConnection`'a kaydet; sonraki bağlantıda değişmişse **kırmızı uyarı**, varsayılan reddet. Test: geri çağırma birimi.
- [ ] **G8.2 FTP/FTPS.** Düz FTP seçilince bağlantı formunda "parola şifresiz gider" uyarısı. FTPS'te sertifika doğrulaması açık mı (`ftpconnect` seçenekleri); kendinden imzalı sertifika → parmak izi TOFU (G8.1 kalıbı), sessiz kabul **yok**.
- [ ] **G8.3 WebDAV.** `http://` adres → uyarı (LAN'da izinli, internette değil: özel IP değilse engelle + "yine de" onayı). Basic kimlik yalnız TLS ya da özel IP'de. Yönlendirme başka ana makineye gidiyorsa kimlik başlığı taşınmaz.
- [ ] **G8.4 SMB.** `smb_connect` SMB1'e düşüyor mu oku; SMB1 yalnız açık onayla. Misafir oturum uyarısı.
- [ ] **G8.5 Google Drive.** Belirteç saklama (G2.3), kapsam `drive.file`'a indirilebilir mi (KALANLAR B5.5 — kullanıcı kararı 👤), çıkışta belirteç iptali + yerel önbellek (`drive_offline.dart`) silinir.
- [ ] **G8.6 İndirme yöneticisi / altyazı / güncelleme.** Tüm `http.get`/`HttpClient`: zaman aşımı var, en fazla 5 yönlendirme, `https` → `http` düşüşü reddedilir, indirilen dosya adı sunucudan geliyorsa G4.5 ad temizliğinden geçer, hedef yol `isInside(indirmeKlasörü)`.

---

## Faz G9 — Tedarik zinciri, derleme, güncelleme

- [ ] **G9.1 Action'ları SHA'ya sabitle (B11).** Her `uses: x/y@vN` → `uses: x/y@<40 hane sha> # vN`. SHA'yı etiketin gösterdiği commit'ten al (`git ls-remote https://github.com/x/y refs/tags/vN`). `subosito/flutter-action`, `gradle/actions/setup-gradle`, `actions/*` hepsi.
- [ ] **G9.2 En az yetki.** `build-apk.yml` üst düzey `permissions: contents: read`; yalnız `release` işinde `contents: write`. `pull_request_target` yok (kalsın). Fork PR'ında sırlar zaten gelmez — `apk` işi sır yokken imzasız/gecici çalışıyor, sorun değil.
- [ ] **G9.3 Kalıcı anahtar zorunlu (B12).** `refs/tags/v*` ya da main `release` yolunda `ANDROID_KEYSTORE_B64` boşsa **kırmızı** (`exit 1`), uyarı değil. Geçici anahtar yalnız dal/PR derlemesinde. Sabit yazılı `'DosyaOkuyucuGecici'` yalnız geçici anahtar içindir — yoruma yaz.
- [ ] **G9.4 Bağımlılık taraması.** `.github/dependabot.yml`: `pub` (haftalık, yalnız güvenlik + küçük sürüm, PR sınırı 3) ve `github-actions` (aylık). Yeni iş akışı `guvenlik-taramasi.yml` (haftalık + elle): `google/osv-scanner-action` `pubspec.lock` üzerinde; bulgu → Issue. `ci/bagimliliklar.txt` + `tool/bagimlilik_denetimi.py` var — onunla çakışmasın, genişlet.
- [ ] **G9.5 Depo ayarları (👤 kullanıcı, GitHub arayüzü):** Secret scanning + push protection aç; `main` için dal koruması (zorla itme yok, silme yok); Actions → "Fork PR'ları onay ister"; 2 adımlı doğrulama; kişisel erişim belirteçlerini gözden geçir. Plan belgesi adımları tek tek yazar: Settings → Code security → …
- [ ] **G9.6 Güncelleme bütünlüğü (B13).** `release` işi her APK için `sha256sum` üretip Release gövdesine `<!-- sha256:dosya-okuyucu-vX.apk=… -->` yazar. `app_update.dart`: indirilen dosyanın SHA-256'sı gövdedekiyle eşleşmiyorsa **sil, kurma**. Sürüm düşürme: indirilen `versionCode` ≤ kurulu ise kurma. Yalnız `https://github.com/kaimau1/…` ve GitHub'ın yönlendirdiği `objects.githubusercontent.com` kabul. Test: `test/app_update_test.dart`'e yanlış özet/eski sürüm/yabancı ana makine.
      **Not:** Play derlemesinde kendi kendini güncelleme tümüyle kapalı (Play politikası) — bayrak doğrula.
- [ ] **G9.7 İmza anahtarı yönetimi (👤).** `SIGNING.md`'ye ekle: anahtarın 2 çevrimdışı yedeği (şifreli USB + kâğıt parola ayrı yerde), Play'e çıkarken **Play App Signing** (yükleme anahtarı ≠ uygulama anahtarı), anahtar sızarsa yapılacaklar (G12.3).
- [ ] **G9.8 Derleme doğrulaması.** `apk` işindeki "APK denetimi" adımına ekle: `aapt2 dump badging` → `application-debuggable` **yok**; `apksigner verify --print-certs` parmak izi beklenen değerle (repo değişkeni `SIGN_CERT_SHA256`) eşleşiyor; manifestte `allowBackup=false`; `usesCleartextTraffic` yok; izin listesi `ci/izin_tabani.txt` ile birebir (yeni izin = bilinçli güncelleme).
- [ ] **G9.9 Gömülü üçüncü taraf.** `assets/word/*.min.js` (docx-preview, jszip), `third_party/`, ses motoru: sürüm + kaynak URL + SHA-256 `LICENSES.md`/`ci/bagimliliklar.txt`'de; denetim betiği dosya özetini doğrular (sessiz değişiklik yakalanır).
- [ ] **G9.10 MobSF (ücretsiz statik tarama).** `guvenlik-taramasi.yml`'e: son `nightly` APK'yı indir, `opensecurity/mobile-security-framework-mobsf` kabıyla tara, raporu artifact yap. Kırmızıya bağlama (çok yanlış alarm) — yalnız rapor; yüksek bulgular elle G12 listesine.

---

## Faz G10 — AI ve gizlilik (KVKK)

- [ ] **G10.1 Açık rıza.** İlk AI kullanımında (anahtar girilirken değil, **ilk gönderimde**) pencere: "Bu belgenin metni/görseli Google Gemini'ye gönderilir. Ücretsiz anahtarda Google veriyi model eğitiminde kullanabilir." Onay `ai_consent_v1`. `tiles_ai_scope.dart` kapsamı ile birleştir. Sessiz otomatik AI (`JobQueue.enqueue(silent:)`) rıza **yokken çalışmaz** — doğrula, test.
- [ ] **G10.2 Hassas veri maskesi.** Gönderimden önce isteğe bağlı (ayar, varsayılan **açık**) maske: TC kimlik (11 hane + sağlama), IBAN, kart no (Luhn), telefon, e-posta → `[TC]`, `[IBAN]`… `diag_report.scrub` ile aynı desen kütüphanesi (`lib/core/pii.dart`'a taşı). Kullanıcı tek belgelik kapatabilir. Test tablosu.
- [ ] **G10.3 Kasa ve kilitli klasör AI'ya kapalı.** Kasadaki dosya için AI eylemleri gizli; otomatik tur bu yolları atlar. Test.
- [ ] **G10.4 Çevrimdışı kip.** `offline_mode.dart` açıkken **hiçbir** ağ çağrısı çıkmıyor mu: tüm `http`/`HttpClient`/`Socket.connect` kullanım yerlerini listele (`grep`), her biri kipi denetliyor mu. Tek kapı `NetGuard.allow(amaç)` yardımcı işlevi öner; test: kip açıkken sahte istemci hiç çağrılmaz.
- [ ] **G10.5 Belgeler.** `docs/GIZLILIK.md`, `assets/privacy`, `docs/play/veri_guvenligi.md` bu plandaki değişikliklerle (yedekleme kapalı, anahtar başlıkta, maske) güncellenir. Uygulamada "Verilerimi sil" (AI özet deposu, arama geçmişi, önbellek, kayıtlı bağlantılar) tek düğme var mı — yoksa ekle.

---

## Faz G11 — Tersine mühendislik / kurcalama koruması (isteğe bağlı)

**Gereksiz** (şimdilik): root tespiti, hata ayıklayıcı tespiti, sertifika sabitleme, bütünlük denetimi. Gerekçe: uygulamada sunucu tarafı sır ya da ücretli içerik yok; bu önlemler yalnız yanlış alarm ve bakım yükü getirir. **Pro/Billing gelince** (KALANLAR A6.5) yeniden değerlendir: o zaman Play Integrity API + satın alma doğrulaması gerekir (sunucusuz doğrulama kırılabilir — dürüst sınır olarak yazılır).

Şimdi yapılacak tek şey:
- [ ] `--obfuscate --split-debug-info` açık (var). R8 `isMinifyEnabled`/`shrinkResources` açık mı `prepare_android.sh`'de doğrula; `proguard-rules.pro`'daki geniş `-keep class X.** { *; }` kuralları gerekçeli mi.

---

## Faz G12 — Süreç: sürüm kapısı ve olay müdahalesi

- [ ] **G12.1 `docs/guvenlik/SURUM_KONTROL.md`** — her `v*` etiketinden önce işaretlenen liste: denetim betiği yeşil · osv taraması temiz · MobSF raporunda yeni yüksek bulgu yok · izin tabanı değişmedi (ya da gerekçeli) · envanter güncel · CIHAZ_TESTI "Güvenlik" bölümü geçti · gizlilik metni güncel.
- [ ] **G12.2 `docs/guvenlik/MASVS.md`** — OWASP MASVS v2 denetimleri (STORAGE, CRYPTO, AUTH, NETWORK, PLATFORM, CODE, RESILIENCE, PRIVACY) tablosu: her satır → "karşılanıyor (kanıt: dosya/test)" / "kapsam dışı (gerekçe)" / "açık (G-N)".
- [ ] **G12.3 `docs/guvenlik/OLAY.md`** — senaryo başına adım adım: (a) imza anahtarı sızdı, (b) depoya sır commit edildi (iptal et → geçmişten sil → secret scanning), (c) yayındaki sürümde açık (düzelt → `[apk]` → sürüm notunda "güvenlik düzeltmesi" → uygulama içi güncelleme zorunlu bayrağı), (d) bağımlılıkta açık.
- [ ] **G12.4 Zorunlu güncelleme bayrağı.** Release gövdesinde `<!-- min-guvenli: 1.2.N -->`; kurulu sürüm altındaysa `app_update.dart` "güvenlik güncellemesi gerekli" penceresi (kapatılabilir ama her açılışta). Test.
- [ ] **G12.5 `docs/CIHAZ_TESTI.md` "Güvenlik" bölümü** — elle maddeler: başka uygulamadan `adb shell am start -n …/.MainActivity --es dosya_link "<kötü>"` → açılmaz · `adb backup` boş · kasa ekranında ekran görüntüsü engelli · 5 yanlış PIN → bekleme · paylaşım açıkken aynı ağdaki ikinci cihazdan parolasız erişim → 401 · mobil veriden port taraması → kapalı · kötü niyetli DOCX/ZIP fixture'ları açılır, zarar yok.
- [ ] **G12.6 Dış göz (👤, isteğe bağlı).** Play'e çıkmadan önce bağımsız biri/araç: MobSF dinamik, `drozer` ile dışa açık bileşen taraması. Ücretli pentest bu ölçekte **gereksiz**; Drive tam kapsam kalırsa CASA zaten zorunlu.

---

## 3. Gerekli / gereksiz özeti (kâr–zarar)

| Faz | Gerekli mi | Kazanç | Bedel |
|---|---|---|---|
| G0 denetim betiği | **Şart** | Açık geri gelmez | ~yarım oturum |
| G1 platform | **Şart** | Yedek sızıntısı, sahte Intent, ekran görüntüsü kapanır | Ayarlar telefon değişiminde taşınmaz |
| G2 sırlar | **Şart** | Sunucu parolaları/anahtar korunur | Göç kodu, 1 oturum |
| G3 kasa/PIN | **Şart** (kasa "şifreli" diye satılıyor) | Kaba kuvvet zorlaşır | Kasa açılışı ~1 sn yavaşlar |
| G4 yerel sunucular | **Şart** | Ortak Wi-Fi'da dosya çalınmaz | Windows exe + eski sürüm uyumu |
| G5 uçtan uca şifre | İsteğe bağlı | Trafik dinlenemez | Büyük; protokol v2 |
| G6 WebView | **Şart** | Kötü DOCX zararsız | docx-preview uyum riski |
| G7 dosya girdisi | **Şart** (çekirdek iş dosya açmak) | Bomba/kaçış/çökme kapanır | En uzun faz, 2 oturum |
| G8 uzak istemci | Gerekli | Ortadaki adam riski düşer | Fazladan onay pencereleri |
| G9 tedarik zinciri | **Şart** (depo herkese açık) | Ele geçmiş Action/sahte APK engeli | Dependabot PR gürültüsü |
| G10 AI/KVKK | **Şart** (Play veri güvenliği + KVKK) | Hukuki risk düşer | AI ilk kullanımda bir pencere daha |
| G11 kurcalama | **Gereksiz** (Pro'ya dek) | — | Yanlış alarm |
| G12 süreç | Gerekli | Sürüm kapısı | Belge bakımı |

Tahmini toplam: 12–15 oturum. Play'e çıkış için **asgari küme:** G0, G1, G2, G4, G6, G9.1–9.3, G10.1.

---

## 4. Açılış istemi (yeni oturuma aynen yapıştır)

```
docs/GUVENLIK_PLANI.md'yi oku (§0 kurallar + sıradaki açık faz). Sıradaki ilk açık fazı
faz-GN dalında yap: her maddede önce "Dosya"yı oku, "ÖNCE DOĞRULA" yazanı doğrula, test yaz,
ayrı commit at. Emin olmadığın maddeyi yapma, KALANLAR.md'ye "GN artığı" yaz. Bitince kutuları
işaretle, HAFIZA.md + KALANLAR.md güncelle, PR aç, CI yeşilse main'e birleştir.
```
