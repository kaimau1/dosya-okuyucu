# Play Console — hassas izin beyanları (Faz 11a, 2026-10-22; 2026-11-02 tam liste)

Play Console > Uygulama içeriği'ndeki formlara yapıştırılacak metinler. Her
izin için: **neden**, **reddedilirse ne olur**, **kısa video senaryosu**
(Play, `MANAGE_EXTERNAL_STORAGE` ve ön plan servisleri için video istiyor).

**Kapsam (2026-11-02):** `ci/AndroidManifest.xml`'deki ve eklentilerden
birleşen (`installed_apps`, `flutter_local_notifications`, `open_filex`,
`cunning_document_scanner`, `google_sign_in_android`) **her** `uses-permission`
aşağıda bir başlıkta geçer. Bekçi: `test/play_permissions_doc_test.dart`
(yeni izin eklenip burada anlatılmazsa test kırılır). Play derlemesinden
çıkarılacak izinler (KALANLAR A6.4 / B5.3) bu belgede "Play derlemesi"
notuyla işaretlenir.

## MANAGE_EXTERNAL_STORAGE (Tüm dosyalara erişim)

- **Kategori:** Dosya yöneticisi (izin verilen kullanım: "File managers").
- **Neden:** Uygulamanın asıl işlevi telefondaki tüm dosyaları gezmek,
  açmak, taşımak, kopyalamak, silmek ve yer açmaktır (indirilenler,
  WhatsApp medyası, SD kart, USB bellek). Medya izinleri belge/arşiv/APK
  dosyalarını kapsamaz; Storage Access Framework klasör bazında izin verdiği
  için tüm depolamayı yöneten bir dosya yöneticisi için yetersizdir.
- **Reddedilirse:** Uygulama açılır; belge görüntüleyici/düzenleyici
  "Birlikte aç", paylaşım ve sistem dosya seçicisiyle (SAF) gelen dosyalarla
  çalışır. Gezgin, pano analizi ve temizlik "izin gerekli" kartı gösterir;
  ardından başka izin sorulmaz, "Dosya aç" önerilir.
- **Ne zaman istenir:** Açılışta değil; kullanıcı panodaki/gezgindeki
  "İzin ver"e bastığında (ya da rehberdeki satırdan).
- **Video senaryosu (30 sn):** ilk açılış → İzinler sayfası → "Tüm
  dosyalara erişim"e dokun → sistem ayarı → geri dön → pano dolu bellek
  halkası → İndirilenler'de bir PDF'i aç → çöp kutusuna taşı → geri al.

## FOREGROUND_SERVICE_DATA_SYNC

- **Neden:** Kullanıcının başlattığı uzun dosya işleri (kopyalama/taşıma,
  ZIP, video küçültme, ağ paylaşımı) ekran kapansa da sürsün; bildirimde
  ilerleme ve "Durdur" düğmesi.
- **Video:** büyük klasörü SD karta kopyala → ana ekrana çık → bildirimdeki
  ilerleme çubuğu → "Durdur".

## FOREGROUND_SERVICE_MEDIA_PLAYBACK

- **Neden:** Ses/video oynatıcı ve sesli kitaplar arka planda çalar;
  kilit ekranı ve bildirim denetimleri.

## PACKAGE_USAGE_STATS (isteğe bağlı)

- **Neden:** "Uygulamalar" ekranında son kullanım tarihini göstermek
  (uzun süredir kullanılmayan uygulamaları kaldırma önerisi). Kullanıcı
  kendisi verir; vermezse yalnız kurulum tarihi görünür.

## REQUEST_INSTALL_PACKAGES

- **Neden:** Dosya yöneticisinde kullanıcının dokunduğu APK dosyasını
  sistemin kurulum ekranına vermek. Uygulama kendiliğinden hiçbir şey kurmaz.

## CAMERA

- **Neden:** Belge tarama (kenar algılama, PDF). Yalnız tarama açıkken.

## RECORD_AUDIO (isteğe bağlı)

- **Neden:** Slayt sunumunda anlatım kaydı (Faz 38). İzin yalnız kullanıcı
  "Anlatım kaydet"e bastığında istenir; ses slayt dosyasına gömülür, hiçbir
  yere gönderilmez. Reddedilirse yalnız anlatım kaydı kapanır.

## POST_NOTIFICATIONS

- **Neden:** Uzun işlerin ilerlemesi/sonucu, fatura hatırlatması. Reddedilirse
  işler yine çalışır, yalnız bildirim görünmez.

## INTERNET

- Kullanıcının başlattığı işler: Gemini AI (kendi anahtarı), Google Drive,
  ağ depolama, indirme yöneticisi, ML Kit dil modeli ve yapay zekâ sesi
  indirmeleri. Analitik/reklam YOK.

## QUERY_ALL_PACKAGES · REQUEST_DELETE_PACKAGES (eklentiden: `installed_apps`)

- **Play'de yüksek riskli izin** — yalnız "cihazdaki uygulamaları listelemek
  asıl işlev" sayılan kategoriler (dosya yöneticisi / cihaz temizleyici)
  beyan edebilir; beyan zayıf kalırsa inceleme reddeder.
- **Neden:** Dosya yöneticisinin "Uygulamalar" bölümü: yüklü uygulamaları
  boyutlarıyla listeler, uzun süredir kullanılmayanları gösterir, kullanıcı
  isterse **sistemin kaldırma penceresini** açar (`REQUEST_DELETE_PACKAGES`;
  uygulama kendiliğinden hiçbir şeyi kaldırmaz). Liste cihazdan çıkmaz.
- **Reddedilirse / Play derlemesi:** A6.4 varyantında `QUERY_ALL_PACKAGES`
  manifestten çıkarılır (`tools:node="remove"`); Uygulamalar ekranı yalnız
  başlatıcıda görünen uygulamaları (`<queries>` + `LAUNCHER` niyeti) gösterir.
- **Video (20 sn):** pano → Uygulamalar → boyuta göre sırala → bir uygulamaya
  dokun → "Kaldır" → sistemin onay penceresi.

## ACCESS_FINE_LOCATION · ACCESS_COARSE_LOCATION (yalnız Android 12L ve öncesi)

- **Konum KULLANILMAZ.** Manifestte `maxSdkVersion="32"`: Android 13+'ta hiç
  istenmez (yerine `NEARBY_WIFI_DEVICES` / `BLUETOOTH_*`, "konum için değil"
  bayrağıyla).
- **Neden (≤ 12L):** Android, eski sürümlerde (a) Wi-Fi ağlarını taramayı /
  internetsiz geçici ağ (LocalOnlyHotspot) kurmayı ve (b) Bluetooth LE
  taramayı konum iznine bağlıyor. Yakındakiler'de ortak Wi-Fi yoksa geçici
  ağ kurmak ve yakındaki telefonu BLE ile bulmak için. İzin yalnız kullanıcı
  "Yakındakiler"de hotspot ya da bulma düğmesine bastığında sorulur.
- **Reddedilirse:** Yakındakiler aynı Wi-Fi'de UDP keşfiyle ve QR/web
  bağlantısıyla çalışmaya devam eder; yalnız geçici ağ ve BLE bulma yok.
- **Veri güvenliği formu:** konum verisi toplanmaz, saklanmaz, gönderilmez.

## BLUETOOTH_SCAN · BLUETOOTH_ADVERTISE · BLUETOOTH_CONNECT · BLUETOOTH · BLUETOOTH_ADMIN

- **Neden:** Yakındakiler (2026-10-29): ekran açıkken Bluetooth LE ile
  **yalnız bulma ve davet** — telefon kısa bir reklam yayınlar (cihaz adı +
  rastgele oturum kimliği), karşı taraf onu görüp "dosya gönderiyorum"
  davetini alır. **Dosya Bluetooth'tan geçmez**, veri Wi-Fi'den akar.
  `BLUETOOTH_SCAN` "konum için değil" (`neverForLocation`) bayraklı.
  `BLUETOOTH` / `BLUETOOTH_ADMIN` yalnız Android 11 ve öncesi
  (`maxSdkVersion="30"`).
- **Reddedilirse:** BLE bulma kapanır; aynı Wi-Fi'deki cihazlar UDP ile, öteki
  her şey QR ile yine bulunur.
- **Video (20 sn):** iki telefonda Yakındakiler → biri "Gönder", öteki
  listede görünür → davet → kabul → aktarım Wi-Fi'den.

## NEARBY_WIFI_DEVICES · CHANGE_WIFI_STATE · ACCESS_WIFI_STATE · CHANGE_NETWORK_STATE · ACCESS_NETWORK_STATE

- **Neden:** Ortak Wi-Fi yoksa gönderen internetsiz **geçici ağ**
  (LocalOnlyHotspot) kurar, alıcı uygulama o ağa `WifiNetworkSpecifier` ile
  bağlanır (`ci/QrTransfer.kt`); ağ durumu, aktarımın mobil veriye kaçmaması
  ve "aynı ağda mısınız" uyarısı için okunur. `NEARBY_WIFI_DEVICES` Android
  13+ ve `neverForLocation` bayraklı.
- **Reddedilirse:** geçici ağ kurulamaz; aynı Wi-Fi ve QR/web yolu çalışır.

## RECEIVE_BOOT_COMPLETED

- **Neden:** SD kartla birleşik depolama: kullanıcı açtıysa, şarjdayken koşan
  dönemsel taşıma işi (`JobScheduler`, `ci/SdUnion.kt`) telefon yeniden
  başladıktan sonra da kurulu kalsın (`setPersisted` bu izni şart koşuyor).
  Açılışta uygulama kendiliğinden başka bir şey yapmaz.
- **Reddedilirse:** (normal izin, kurulumda verilir) — yok.

## INSTALL_SHORTCUT (`com.android.launcher.permission`)

- **Neden:** "Ana ekrana ekle" (klasör/dosya/kitaplık kısayolu) — yalnız
  Android 7 ve öncesinin eski başlatıcı yayını için. 8+'da
  `ShortcutManager.requestPinShortcut` izinsiz çalışır ve sistem onay sorar.

## FOREGROUND_SERVICE · WAKE_LOCK

- **Neden:** Yukarıdaki iki ön plan servisi türünün (veri eşitleme, medya
  oynatma) ortak izni; uzun kopyalama/aktarım ve çalma sürerken işlemcinin
  uyumaması (`PARTIAL_WAKE_LOCK`, iş bitince bırakılır; 2 sa tavan).

## READ_EXTERNAL_STORAGE · WRITE_EXTERNAL_STORAGE

- **Neden:** `READ_EXTERNAL_STORAGE` ≤ Android 12L, `WRITE_EXTERNAL_STORAGE`
  ≤ Android 10 (`maxSdkVersion`): Android 10 ve altında tüm depolamaya erişimi
  klasik izin verir. Android 13+ medya izinleri (READ_MEDIA_*) **bildirilmez**
  (Faz 46): başka uygulamada açma kendi `ACTION_VIEW` köprümüzle, yalnız o
  dosyaya verilen okuma yetkisiyle yapılır.

## VIBRATE (eklentiden: `flutter_local_notifications`)

- **Neden:** Bildirim titreşimi (iş bitti / hatırlatma) ve dokunsal geri
  bildirim. Normal izin.

