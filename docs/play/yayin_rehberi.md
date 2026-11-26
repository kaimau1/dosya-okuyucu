# Google Play Yayın, Lisans ve Telif Rehberi (A'dan Z'ye)

Bu belge, **Dosya Okuyucu** projesinin lisans/telif denetimini, ücretli satışta dikkat edilmesi gereken politika kurallarını ve Google Play Store'a çıkış aşamalarını adım adım listeler.

İlgili diğer belgeler:
- Hassas izin beyanları ve video senaryoları: [`docs/play/izin_beyanlari.md`](izin_beyanlari.md)
- Mağaza metinleri (TR/EN/AR): [`docs/play/magaza_metinleri.md`](magaza_metinleri.md)
- Veri güvenliği formu: [`docs/play/veri_guvenligi.md`](veri_guvenligi.md)
- Sürüm mimarisi (Lite / Pro / Kişisel): [`docs/arsiv/planlar/SURUM_PLANI.md`](../arsiv/planlar/SURUM_PLANI.md)
- Sürüm öncesi güvenlik kontrolü: [`docs/guvenlik/SURUM_KONTROL.md`](../guvenlik/SURUM_KONTROL.md)

---

## BÖLÜM 1: Lisans, Telif ve Ücretli Satış Analizi

### 1.1 Lisans Alınması Gerekli mi?
- **Syncfusion (`syncfusion_flutter_pdf`, `syncfusion_flutter_core`):**
  - **Durum:** Açık kaynak **değildir**. PDF yazma, sayfa düzenleme, form, parola ve dijital imza işlemlerinde kullanılır.
  - **Ticari/Ücretli Satış:** Bireysel geliştiriciyseniz veya şirketinizin yıllık brüt geliri **< 1 Milyon USD**, çalışan sayısı **≤ 10** (geliştirici **≤ 5**) ve dış yatırımı **< 3 Milyon USD** ise **Syncfusion Community License** tamamen **ücretsizdir** ve **ücretli uygulama satışına izin verir**.
  - **Yapılması Gereken:** Syncfusion sitesinden kendi/şirket adınıza Community License başvurusu yapıp lisans belgesini (PDF/e-posta) resmi olarak saklayın (`PLAN.md` K38). Şartları aşarsanız ticari lisans satın alınmalı veya kalan Syncfusion çağrıları yerel PDF motoruna taşınmalıdır.

### 1.2 Açık Kaynak ve Gömülü Bileşen Lisansları
- **`video_player_media_kit` ve `media_kit_libs_android_video` (`libmpv` + `FFmpeg`):**
  - Paket MIT lisanslıdır; ancak Android derlemesine gömdüğü `libmpv` ve `FFmpeg` (`.so` yerel kütüphaneleri) **LGPL v2.1+** lisanslıdır (GPL kodlayıcı içermez).
  - **Ücretli satışa engel mi?** Hayır. Android APK/AAB içinde `.so` olarak dinamik bağlandığı için uygulama kaynak kodunuzu açmanız gerekmez. Uygulama içi lisans ekranında (`Ayarlar → Açık kaynak bileşenler`) ve `LICENSES.md` dosyasında LGPL v2.1+ bildirimi ve kaynak bağlantısı yer alır.
- **Gömülü Yazı Tipleri (Carlito, Tinos, Arimo, JetBrains Mono):**
  - Microsoft'un tescilli *Calibri, Arial, Times New Roman* fontları yerine metrik uyumlu **SIL Open Font License (OFL 1.1)** fontları gömülüdür (`assets/fonts/OFL.txt`, `FONTS-NOTICE.txt`).
  - Hiçbirinde "Reserved Font Name" (RFN) kısıtlaması yoktur (`test/font_license_test.dart`). Ücretli uygulamada gömülü dağıtılması tamamen yasaldır.
- **Gömülü JS ve İsteğe Bağlı İndirilen Modeller:**
  - Word görüntüleyici (`jszip.min.js` → MIT, `docx-preview.min.js` → Apache 2.0): telif başlıkları ve `assets/word/LICENSES.txt` korunmuştur; ticari satışa uygundur.
  - Türkçe sesli kitap modelleri (`Antalia-2 Mini`, `EMA Lightning`, `ONNX Runtime Web`) ve 4× görsel büyütme (`ESRGAN`): **Apache 2.0 / MIT** lisanslıdır, APK'da gömülü olmayıp ilk kullanımda indirilir; ticari kullanıma uygundur.
- **Diğer Tüm Paketler (`pdfrx`/PDFium, `archive`, `koni_archive`, `pointycastle`, `dartssh2`, `ftpconnect`, `smb_connect`, `mlkit`):**
  - Tamamı izin verici (**MIT / BSD-3 / Apache 2.0**) lisanslıdır; ücretli satışta hiçbir kısıtlama yoktur.
- **Microsoft Marka Hakları:**
  - Mağaza açıklamalarında *"Microsoft Word, Excel ve PowerPoint, Microsoft Corporation'ın ticari markalarıdır; bu uygulama Microsoft ile bağlantılı değildir"* ibaresi yer alır (`docs/play/magaza_metinleri.md`). Uygulama simgesinde ve başlığında Microsoft logoları kullanılmamalıdır.

### 1.3 Ücretli Satışta Politika ve Gelir Riskleri
1. **Google Drive Tam Kapsamı (`drive` scope):** Tam Drive erişimi Google tarafından "Restricted Scope" sayılır ve yayına çıkabilmek için **yıllık ücretli CASA güvenlik denetimi** şart koşar. Ücretli CASA yaptırılmayacaksa Play sürümlerinde Drive kapalı tutulmalı (`Edition.kisisel`) veya kapsam ücretsiz onaylanan `drive.file` seviyesine çekilmelidir (`PLAN.md` K9).
2. **Mağaza Dışı Güncelleme (`selfUpdate`) ve APK Kurma (`REQUEST_INSTALL_PACKAGES`):** Play Store'da dağıtılan bir uygulamanın GitHub'dan APK indirip kendini güncellemesi **kesin politika ihlalidir**. Play derlemelerinde (`Edition.lite` ve `Edition.pro`) bu özellikler ve izinler devre dışıdır.
3. **Gemini API Anahtarı (BYOK) Beklentisi:** Ücretli Pro sürümü satın alan kullanıcının sürpriz yaşamaması için mağaza açıklamasında *"Yapay zekâ özellikleri kullanıcının kendi Gemini API anahtarıyla çalışır"* bilgisi açıkça belirtilmelidir.
4. **Kaynak Kodu Koruması:** Ticari yayından önce GitHub deposu **Private** yapılmalı ve kök dizine `"Tüm hakları saklıdır"` içeren `LICENSE` dosyası eklenmelidir (`PLAN.md` K38).

---

## BÖLÜM 2: Google Play'e Çıkış İçin A'dan Z'ye Adım Adım Yol Haritası

### Aşama 1: Hukuki, Lisans ve Depo Hazırlığı
1. **Syncfusion Community License:** Başvuruyu tamamlayın ve lisans belgesini saklayın.
2. **Güvenlik E-postası:** `SECURITY.md` içindeki yer tutucuyu gerçek iletişim adresinizle güncelleyin (`PLAN.md` K32).
3. **Gizlilik Politikası URL'si:** Depo private olacağından `assets/privacy/tr.md` ve `en.md` metinlerini herkese açık bir adreste (GitHub Pages veya özel alan adı) yayınlayın.
4. **Depo Gizliliği:** Kök dizine `LICENSE` ("Tüm hakları saklıdır") ekleyin ve depoyu Private'a alın.

### Aşama 2: Sürüm Mimarisi ve Kod Kapıları (`SURUM_PLANI.md` S2–S8)
1. **Kararlar (`PLAN.md` K15, K16):** Pro satış fiyatını (`DOSYA_PRO_FIYAT`), uygulama adlarını (`Dosya Okuyucu Lite` / `Dosya Okuyucu Pro`) ve Drive kapsamını (`K9`) kesinleştirin.
2. **Arayüz Kapıları (S2):** Lite sürümde Office düzenleyicilerin salt-okunur açılmasını ve Pro özelliklerinin `ProGate.guard` ile tanıtım levhasına yönlendirilmesini tamamlayın.
3. **Manifest Varyantları (S4):** `ci/play_variant.py` ile Lite sürümde 0 hassas izin, Pro sürümde ise Play dışı izinlerin (`REQUEST_INSTALL_PACKAGES`, `QUERY_ALL_PACKAGES`, `PACKAGE_USAGE_STATS`, `RECEIVE_BOOT_COMPLETED`, konum ve genel indirme süzgeçleri) çıkarıldığını doğrulayın.
4. **Paket Kimlikleri ve CI (S5–S6):**
   - Lite: `com.dosyaokuyucu.dosya_okuyucu.lite` (hedef ≤ 45 MB; `libmpv` ve LiteRT `.so` dışlanmış — `ci/prepare_android.sh` §11b).
   - Pro: `com.dosyaokuyucu.dosya_okuyucu.pro`.
   - İmzalı AAB: Actions → *APK Derle & Release* → elle tetik, `aab` işaretli (Lite/Pro/Kişisel matrisi; `play_variant verify`, 16 KB ELF arm64 + x86_64). Ayrı `build-play.yml` yok.
5. **Lite → Pro Geçişi (S7):** Lite'tan ayarları ve son açılanlar listesini dışa aktarıp Pro'da içe aktarma akışını doğrulayın.

### Aşama 3: İmza Anahtarı ve Güvenlik Denetimi
1. **Keystore Yedeği (`SIGNING.md`, `K35`):** `release.jks` ve parolasını en az iki ayrı çevrimdışı ortamda (şifreli USB + kâğıt) yedekleyin; repo değişkenlerine `SIGN_CERT_SHA256` ekleyin (`K33`).
2. **Güvenlik Kontrolü (`docs/guvenlik/SURUM_KONTROL.md`):**
   - `bash tool/guvenlik_denetimi.sh` yeşil.
   - `tool/apk_dogrula.py` ile `debuggable=false`, `allowBackup=false`, `targetSdk=36` ve **16 KB ELF sayfa hizalaması** doğrulandı.

### Aşama 4: Google Play Console Hesap Kurulumu
1. **Geliştirici Hesabı:** Google Play Console hesabını açın (25 USD) ve kimlik/adres (kurumsal ise D-U-N-S) doğrulamasını tamamlayın.
2. **Satıcı (Merchant) ve Ödeme Profili:** Ücretli Pro sürümü satabilmek için *Play Console → Ayarlar → Ödeme profili* altından banka (IBAN) ve vergi bilgilerinizi tanımlayın.
3. **Testçi Hazırlığı:** Kasım 2023 sonrası açılan bireysel hesaplarda üretim onayı için **en az 12–20 testçinin 14 gün boyunca aralıksız** kapalı testte kalması şarttır (kurumsal hesaplarda bu şart yoktur).

### Aşama 5: Mağaza Görselleri ve Play Console Beyan Formları
1. **Mağaza Varlıkları (`P26`):**
   - `python3 tool/magaza_varliklari.py` ile 512×512 simge ve 1024×500 tanıtım görselini üretin.
   - Gerçek cihazdan TR, EN ve AR dillerinde telefon ve tablet ekran görüntülerini alın.
2. **Uygulama İçeriği (App Content) Formları:**
   - **Gizlilik Politikası:** Herkese açık politika URL'sini girin.
   - **Reklamlar:** *"Hayır, uygulamam reklam içermiyor"*.
   - **Uygulama Erişimi:** *"Tüm işlevler özel erişim olmadan kullanılabilir"*.
   - **İçerik Derecelendirmesi (IARC):** Verimlilik / Yardımcı Program → PEGI 3 / Tüm Yaşlar.
   - **Hedef Kitle:** **13+ (veya 18+)** seçin (9 yaş altı çocukları **işaretlemeyin**).
   - **Veri Güvenliği (Data Safety):** [`docs/play/veri_guvenligi.md`](veri_guvenligi.md) tablosuna göre doldurun (*"Veri toplanmaz ve paylaşılmaz"*, uygulama içi *"Verilerimi sil"* mevcut).
3. **Hassas İzin Beyanları ve Videoları (Yalnız Pro Sürüm):**
   - **Lite** sürümde hassas izin yoktur, form çıkmaz.
   - **Pro** sürümde [`docs/play/izin_beyanlari.md`](izin_beyanlari.md) metinlerini kullanın ve aşağıdaki iki kısa ekran kaydını YouTube'a *Liste Dışı (Unlisted)* yükleyip forma ekleyin:
     1. **`MANAGE_EXTERNAL_STORAGE` (~30 sn):** İzin istemeden açılış → Gezgin/Pano'da "İzin ver" kartı → Sistem ayarı → İndirilenler'de dosya açma, taşıma ve çöp kutusu.
     2. **`FOREGROUND_SERVICE_DATA_SYNC` & `MEDIA_PLAYBACK` (~20 sn):** Uzun dosya kopyalama/sıkıştırma başlatma → Ana ekrana çıkma → Bildirimde ilerleme ve "Durdur" düğmesi; arka planda ses oynatma bildirimi.

### Aşama 6: Çıkış (Release) Aşamaları
1. **Adım 6.1 — İç Test (Internal Testing — 48 Saat):**
   - İmzalı `.aab` dosyasını ve `dart-symbols-<sürüm>` sembollerini **Play App Signing** açık olarak İç Test kanalına yükleyin.
   - Firebase Test Lab **Ön Lansman Raporunu (Pre-launch Report)** inceleyin (çökme, ekran kayması, erişilebilirlik).
   - Gerçek cihazlarda 48 saat test edin (`PLAN.md` K37).
2. **Adım 6.2 — Kapalı Test (Closed Testing):**
   - İç test temizse sürümü Kapalı Test kanalına yükseltin (bireysel hesapta 20 testçi × 14 gün).
   - **Android Vitals** eşiklerini doğrulayın: çökme oranı **< %1,09**, ANR oranı **< %0,47**.
3. **Adım 6.3 — Üretim (Production) ve Kademeli Dağıtım:**
   - Önce **Lite** sürümü (0 izin, hızlı onay), ardından **Pro** sürümü Üretim'e gönderin.
   - İlk yayını **%10–%20 kademeli dağıtım (staged rollout)** ile başlatın; 2–3 gün Vitals metriklerini izledikten sonra **%100**'e çıkarın.
   - Pro sürüm mağazada yayına girdiğinde Lite sürümde `DOSYA_PRO_FIYAT` bayrağıyla Pro yönlendirme fiyat etiketini etkinleştirin.
