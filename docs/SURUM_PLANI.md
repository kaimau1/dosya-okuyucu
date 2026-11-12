# SÜRÜM PLANI — Lite / Pro / Kişisel (2026-11-10)

Kullanıcı kararı: **üç sürüm, tek kod tabanı.**
- **Lite** — Play, ücretsiz, reklamsız. İnsanların günlük işini gören çekirdek. Pro'ya rahatsız etmeyen yönlendirme.
- **Pro** — Play, ücretli (tek seferlik, ayrı uygulama). Lite'taki her şey + ileri özellikler.
- **Kişisel** — yalnız GitHub (`tags/kisisel`), mağazada yok. Her şey + deneysel + Play'in izin vermeyeceği özellikler.

Gelir: Pro satışından. Reklam yok, abonelik yok. (K6 "reklamsız + tek seferlik Pro" kararıyla uyumlu;
fark: uygulama içi satın alma yerine **ayrı ücretli uygulama** → Billing kodu gerekmez, `KALANLAR` A6.5 iskeleti düşer.)

---

## 1. Özellik dağılımı

### 1.1 Lite (ücretsiz) — "aç, oku, bul, paylaş"

Taban: bugünkü **izinsiz okuyucu derlemesi** (`build-okuyucu.yml`, `DOSYA_OKUYUCU`) — manifestte hassas izin yok,
dosyalar "Birlikte aç", "Dosya aç" ve "Klasör ekle" (sistem seçicisi) ile gelir.

| Alan | Lite'ta olan |
|---|---|
| Açma | PDF, Word (docx/doc), Excel (xlsx/xls/csv), PowerPoint (pptx), metin/Markdown, görsel, e-kitap; zip içine bakma ve tek dosya açma |
| PDF okuma | kaydırma/yakınlaştırma, metin arama, metin seçip kopyalama, sayfaya git, içindekiler, kaldığı yerden devam, gece kipi, parolalı PDF açma |
| PDF temel iş | vurgulama + not, **form doldurma**, **elle imza atma** (çizerek), kaydet/kopyasını kaydet |
| Office okuma | Word sayfa görünümü, Excel sayfa/sekme gezme + hücre arama, slayt gösterisi |
| Ortak | yazdırma, paylaşma, son açılanlar, Kitaplık (rafta PDF/e-kitap), dosya özellikleri |
| Sesli okuma | telefonun kendi sesiyle (sistem TTS) oku |
| Görünüm | açık/koyu tema, Türkçe/İngilizce/Arapça |
| Gizlilik | 0 hassas izin, reklam/takip yok, internetsiz çalışır |

Lite'ta **olmayan ama görünen** (PRO rozetli, dokununca §3 levhası): düzenleme, PDF araçları, tarama, dönüştürme, dosya yöneticisi.

Boyut hedefi: Lite'a video motoru (libmpv), görsel büyütme (LiteRT) ve yapay zekâ ses motoru **girmez** →
hedef ≤ 45 MB (bugün tam sürüm bütçesi 100 MB). Ölçülmeden söz verilmez; ilk Lite derlemesinde boyut raporuna bakılır.

### 1.2 Pro (ücretli) — Lite + aşağıdakiler

| Alan | Pro'ya özel |
|---|---|
| Office düzenleme | Word (mobil yazım + sayfa), Excel (formül, Türkçe işlevler, grafik), PowerPoint (yerinde metin, nesneler), yeni boş belge |
| PDF ileri | metin/paragraf düzenleme, sayfa sırala/sil/döndür/ekle, birleştir/böl, sıkıştır, parola koy/kaldır, karartma (redaksiyon), karşılaştır, OCR ile aranabilir PDF, dijital imza, PDF çevirisi |
| Tarama | kamera ile belge tara → PDF (düzleştirme, netleştirme, OCR) |
| Dönüştürme | Word/Excel/slayt/görsel ↔ PDF, Markdown, metinden slayt |
| Dosya yöneticisi | gezgin, kategori/tür süzgeci, arama (ad + içerik), çöp kutusu + geri al, taşı/kopyala/toplu yeniden adlandır, iş sonucu ekranı, USB bellek + SD kart, arşiv oluştur/çıkar (zip/RAR/7z) |
| Yer açma | depolama analizi, kopya ve benzer dosyalar, akıllı temizlik, WhatsApp temizliği |
| Güvenlik | şifreli kasa, klasör kilidi, uygulama kilidi |
| Aktarım | Yakındakiler (telefon ↔ telefon / Windows), QR ile paylaşım, tarayıcıdan paylaşım |
| Uzak | SMB / FTP / SFTP / WebDAV bağlantıları |
| Ses | sesli kitap üretme + kitaplığı, cihaz içi doğal Türkçe sesler |
| Yapay zekâ | özet, sohbet, etiketleme, çeviri (kullanıcının kendi Gemini anahtarı); cihaz içi çeviri |
| Medya/görsel | video/müzik oynatıcı, fotoğraf galerisi, görsel düzenleme + boyutlandırma |
| Diğer | Önemli Dosyalar + galeri, ana ekran widget'ları, ayar yedeği |

Pro izinleri: "Tüm dosyalara erişim" (yalnız dosya yöneticisi ilk açıldığında), kamera, bildirim, yakın cihazlar/Bluetooth.
**Risk:** "Tüm dosyalar" için Play beyan formu + video ister; dosya yöneticisi izinli kategoridir ama ret olasılığı vardır.
Ret gelirse Pro, Lite gibi "Klasör ekle" (SAF) yoluna düşer — kod zaten var.

### 1.3 Play'e (Lite ve Pro) HİÇ girmeyen — yalnız Kişisel

| Özellik | Neden çıkıyor |
|---|---|
| APK / .apks kurma ve APK dışa aktarma | `REQUEST_INSTALL_PACKAGES` — Play'de çekirdek işlev olmadan ret sebebi |
| Yüklü uygulamalar ekranı + "son kullanım" | `QUERY_ALL_PACKAGES`, `PACKAGE_USAGE_STATS` — beyanı zor, okuyucuyla ilgisiz |
| Kendi kendini güncelleme (GitHub'dan) | Play politikası: mağaza dışı güncelleme yasak |
| İndirme yöneticisi + tarayıcı bağlantılarını yakalama (`http/https host=*`) | "indirici" kategorisi telif/politika riski; gereksiz geniş Intent süzgeci (güvenlik B15) |
| İnternette altyazı arama | üçüncü taraf anahtar + telif riski |
| Google Drive (tam kapsam) | yıllık ücretli CASA denetimi; `drive.file`'a inince Pro'ya döner |
| Telefonu FTP sunucusu yapma | güvenlik planı G4 bitene dek; sonra Pro'ya döner |
| Arka planda sürekli "Yakındakiler" servisi, açılışta başlayan işler (`RECEIVE_BOOT_COMPLETED`) | pil/izin şikâyeti; ön plan servisi beyanı |
| Konum izni (Wi-Fi Direct eski yol) | okuyucu için açıklanamaz; yeni yol konumsuz |
| Sesli not / dikte, sessiz otomatik AI turu, Android asistan işlevleri (AppFunctions) | deneysel |
| USB tanılama, SD birleştirme, `lib/labs/**`, bitmemiş PDF Pro motoru (`PDF_PRO_ENGINE`) | deneysel — olgunlaşan Pro'ya terfi eder |

Kural: **yeni/deneysel her özellik önce Kişisel'e girer**; kararlı + politikaya uygun olunca Pro'ya, çok temel ise Lite'a terfi eder.

---

## 2. Neden bu dağılım (kâr / zarar)

- **Lite cimri olursa indirilmez, cömert olursa Pro satmaz.** Çizgi: *okuma ve doldurup imzalama ücretsiz; üretme, düzenleme, yönetme ücretli.* Form + imza Lite'ta çünkü en sık "acil iş" bu ve iyi puanı o getirir.
- **Lite'ın satış cümlesi "0 izin, reklamsız, küçük".** Dosya yöneticisi Lite'a girerse bu cümle ölür ve Play incelemesi zorlaşır.
- **Ayrı ücretli uygulama (seçilen yol)** — Kazanç: Billing kodu yok, hızlı çıkış, Play'in 2 saatlik iade süresi fiilen deneme olur. Bedel: ücretli uygulamaya geçiş oranı uygulama içi satın almaya göre genelde daha düşüktür; iki mağaza kaydı = yorumlar bölünür; Lite'taki son dosyalar/ayarlar Pro'ya kendiliğinden geçmez (§4.6).
- **Fiyat:** "çok ucuz" başlamak mantıklı ama sonradan zam eski yorumları bozmaz, indirim ise her zaman yapılabilir → listede orta bir fiyat + **lansman indirimi** öner. Rakam kullanıcı kararı (👤).

---

## 3. Lite'ta Pro yönlendirmesi (rahatsız etmeyen)

Olacak:
1. **PRO rozeti:** Pro özelliğinin düğmesi Lite'ta görünür, köşesinde küçük "PRO". Dokununca alt levha: özellik adı + 3 madde + fiyat + **"Play'de gör"** düğmesi + "Şimdi değil".
2. **Ana ekranda tek kart:** "Pro'da neler var?" — kapatılabilir; kapatınca 30 gün görünmez.
3. **Ayarlar → "Pro sürüm"** satırı (karşılaştırma tablosu + bağlantı).
4. **Hakkında / mağaza açıklaması**nda tek satır.

Olmayacak: açılışta tam ekran pencere, geri sayım, iş bitince araya giren teklif, bildirimle teklif, okuma sırasında şerit.

Fiyat metni tek yerde (`lib/core/edition.dart` `proPriceLabel`); boşsa levhada fiyat satırı gizlenir (yanlış fiyat göstermektense hiç gösterme). Bağlantı: `market://details?id=<pro paket kimliği>`, açılamazsa `https://play.google.com/store/apps/details?id=…`.

---

## 4. Teknik uygulama (yürüten model için)

Kurallar: `CLAUDE.md` §4 (doğrulama = CI). Faz dalı `faz-S1`… + PR. Her madde ayrı commit.

- [x] **S1 — Sürüm kapısı.** (2026-11-12: `lib/core/edition.dart` + `test/edition_test.dart`; `readerBuild` = Lite, yüklü uygulamalar/oto güncelleme `Feature`'a bağlı.) `lib/core/edition.dart`:
      `enum Edition { lite, pro, kisisel }` — `String.fromEnvironment('DOSYA_SURUM', defaultValue: 'kisisel')`'den;
      `enum Feature { … }` (§1'deki her satır bir değer); `Edition.current.has(Feature f)` tablosu **tek dosyada**.
      Eski bayraklar buna bağlanır: `StoragePermission.readerBuild` → `Edition.current == lite`;
      `DOSYA_KISISEL == '1'` → `kisisel`. Eski `--dart-define`'lar bir süre birlikte kabul edilir (CI kırılmasın).
      Test: `test/edition_test.dart` — her sürüm için tablo; "Lite ⊂ Pro ⊂ Kişisel" (alt küme) kuralı.
- [~] **S2 — Arayüz kapıları.** (2026-11-12: `lib/widgets/pro_gate.dart` — `ProGate.guard/visible/locked`, `ProBadged`; `FmTileData.feature` ile pano araçları + kategori kutuları + Tüm araçlar; dock düğmeleri; dosya işlem levhası (`_featureOf`); `ScanFlow.run`, `PdfToolsScreen.open`, `showNewDocumentSheet` kendi içinde; Drive yalnız Kişisel. **Kalan:** Office düzenleyiciler (Word/Excel/slayt) aynı zamanda görüntüleyici — Lite'ta salt-okunur kip gerekir (`EntryOpener.screenFor`); görüntüleyici menülerindeki tek tek PDF/AI eylemleri.) Giriş noktaları: `lib/screens/fm/dashboard/{sections,tools,tiles}.dart` (kutular),
      `tools_screen.dart`, görüntüleyici menüleri (`lib/screens/viewer/**`), `entry_actions/**`, `pdf_tools/**`, ayar katalogu
      (`settings_catalog.dart`). Yardımcı: `ProGate.guard(context, Feature f, VoidCallback run)` — sürümde varsa çalıştırır,
      Lite'ta §3 levhasını açar, Play dışı özellik Lite/Pro'da **hiç çizilmez**. Arama: `grep -rn "Navigator.*push" lib/screens | wc -l`
      çok; ekran ekran değil **giriş noktası** kapat (kutu, menü satırı, düğme).
      Test: Lite'ta pano widget testi — Pro kutuları rozetli, Kişisel kutuları yok.
- [x] **S3 — Pro levhası + kart + ayar satırı** (2026-11-12: levha `showProSheet`; Lite'ta Ayarlar → "Pro sürüm"; ana ekran bildirim alanında "Pro'da neler var?" (`ProPromo`, "Şimdi değil" → 30 gün); fiyat `--dart-define=DOSYA_PRO_FIYAT`.) (§3). Metinler `lib/core/l10n/strings/` üç dilde. `SecureScreen` gerekmez.
- [ ] **S4 — Manifest varyantları.** `ci/play_variant.py`'ye sürüm kipi: `DOSYA_SURUM=lite` → bugünkü `OKUYUCU_REMOVE` listesi;
      `pro` → çıkar: `REQUEST_INSTALL_PACKAGES`, `QUERY_ALL_PACKAGES`, `PACKAGE_USAGE_STATS`, `RECEIVE_BOOT_COMPLETED`,
      `ACCESS_FINE_LOCATION`/`COARSE` (Nearby konumsuz çalışıyor mu **ÖNCE DOĞRULA**), `http/https host="*"` Intent süzgeçleri,
      APK MIME süzgeçleri, `AjanServisi`. `verify` kipi birleşmiş manifestte bunları denetler.
      İzin tabanı dosyaları: `ci/izin_lite.txt`, `ci/izin_pro.txt` (yeni izin = bilinçli güncelleme).
- [ ] **S5 — Paket kimlikleri ve adlar.** Lite: `…dosya_okuyucu.okuyucu` (mevcut), ad "Dosya Okuyucu Lite".
      Pro: `…dosya_okuyucu.pro`, ad "Dosya Okuyucu Pro". Kişisel: bugünkü kimlik (kurulu cihazlar güncellenmeye devam etsin).
      Üçü yan yana kurulabilir. Simge: Pro'da küçük rozet (`tool/gen_icon.py`).
- [ ] **S6 — CI.** `build-okuyucu.yml` → `build-play.yml` (elle + `v*` etiketi): matris `surum: [lite, pro]`,
      AAB + arm64 APK artifact, boyut bütçesi sürüme göre (lite 45, pro 100 — ilk ölçümden sonra kesinleşir).
      Lite'ta ağır yerel kitaplıklar: `pubspec` tek olduğu için eklenti düşmez → `prepare_android.sh`'de Lite için
      `packagingOptions { jniLibs.excludes }` ile `libmpv*`, LiteRT `.so` dışla (Dart tarafı o özellikleri zaten çağırmaz;
      çağrı kalırsa çökme → S1 testi + duman turu). **ÖNCE DOĞRULA:** dışlama sonrası açılışta eklenti kaydı çöküyor mu.
- [ ] **S7 — Lite → Pro geçiş.** Lite'ta "Ayarları dışa aktar" (mevcut `settings_backup.dart`) + son açılanlar listesi tek dosya;
      Pro ilk açılışta "Lite'tan aktar" (dosyayı seçtir). Otomatik paylaşım yok (ayrı paketler birbirinin verisini okuyamaz).
- [ ] **S8 — Mağaza.** `fastlane/metadata/android-lite/` ve `android-pro/` (tr/en/ar): başlık, kısa açıklama, tam açıklama
      (§1 tablolarından; Lite açıklaması 6 madde), ekran görüntüsü listesi (`tool/magaza_varliklari.py`).
      `docs/play/veri_guvenligi.md` ve `izin_beyanlari.md` iki sürüm için ayrı bölüm.
- [ ] **S9 — Kişisel.** `DOSYA_SURUM=kisisel` varsayılan; oto güncelleme, `ci/kisisel/manifest_ek.xml` aynen. Yeni özellik
      şablonu: `Feature`'a ekle → yalnız `kisisel` → kararlı olunca tabloda terfi.

Bitti: iki AAB CI'dan çıkıyor · `play_variant verify` iki sürümde yeşil · Lite'ta hiçbir Pro/Kişisel ekranına ulaşılamıyor
(widget testi + cihaz turu) · `docs/CIHAZ_TESTI.md` "Sürümler" bölümü · HAFIZA kaydı.

**Sıra önerisi:** güvenlik planının asgari kümesi (G0, G1, G2, G6, G9.1–9.3) → S1–S6 → Lite kapalı test → S7–S8 → Pro.
Lite önce çıkar (izin riski yok, inceleme kolay); Pro'nun "Tüm dosyalar" beyanı ayrı ve daha uzun sürer.

---

## 5. Kullanıcı kararları (👤)

1. Pro fiyatı + lansman indirimi (ve `proPriceLabel` metni).
2. Tarama Lite'a "ayda birkaç sayfa" sınırıyla girsin mi? (Öneri: hayır — sayaç/sınır kodu ve "kandırıldım" yorumu riski; Pro'da kalsın.)
3. Pro'da "Tüm dosyalar" beyanı reddedilirse SAF'la devam mı, itiraz mı?
4. Uygulama adları: "Dosya Okuyucu Lite / Pro" mu, yeni bir marka adı mı?
