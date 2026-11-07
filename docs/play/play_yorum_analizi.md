# İzin Sadeliği ve Google Play Yorum Analizi (Claude Docs kopyası, 2026-11-07)
Kaynak: https://claude.ai/artifact/HejiLU4WU2HK4Sam3HUnoW

{"verdict":"allow","rev":10,"data":{"rev":10,"xml":"
Dosya Okuyucu — İzin Sadeliği ve Google Play Yorum Analizi
 · 
Özet
İzin şikayetinin çözümü izinleri silmek değil: uygulama izin istemeden açılsın, her izin yalnız onu gerektiren özellikte ve gerekçesiyle istensin. Rakiplerin yorumlarında en sık şikayet reklam, sonra gizli ücret, sonra izin/gizlilik. Bu üçünde de zaten iyi durumdayız ama bunu ne ilk açılışta ne mağazada söylüyoruz.
En önemli 7 öneri
Açılışta 0 izin penceresi. Okuyucu modu (Birlikte aç, Paylaş, SAF seçici) hiç izin istemeden çalışsın.
\"Tüm dosyalar\" reddedilince zinciri kes. Bugün ardından üç medya izni daha soruluyor; yerine \"tek tek aç / klasör ekle\" kartı gelsin.
Play derlemesinden READ_MEDIA_ ve QUERY_ALL_PACKAGES'ı çıkar.* Photo Picker + SAF yeter; Play politika riski de düşer.
Mağazanın ilk satırı: Reklamsız. İzin istemeden açılır. Dosyan telefonda kalır.
Ayarlar → Gizlilik ve izinler tek sayfası ve Çevrimdışı kip anahtarı.
Pro tek seferlik ve önceden net etiketli olsun; okuma ve temel PDF işleri (birleştir, böl, imzala) ücretsiz kalsın.
Orta vadede ayrı \"izinsiz okuyucu\" derlemesi mağazada \"0 hassas izin\" diye konumlansın.
İzin sorunu: kullanıcı neden kızıyor, Android ve Play ne diyor
Kullanıcı izne değil, gerekçesiz ve toplu izne kızıyor. Dosya yöneticisi kategorisi, 2025'te Play'den kaldırılan casus yazılım vakaları yüzünden (dosya yöneticisi kılığındaki KoSpy; Veri Güvenliği beyanında yalan söyleyen 1,5 milyon indirmelik \"File Manager\") şüpheyle bakılan bir kategori. \"PDF okuyucu konum/mikrofon/kişileri neden istiyor?\" sorusu doğrudan güvensizliğe ve 1 yıldıza dönüşüyor.
Kullanıcıyı rahatsız eden 5 şey
Açılışta izin duvarı — uygulama daha hiçbir şey göstermeden \"Tüm dosyalara erişim\" istiyor.
Konu dışı izin — bir okuyucunun konum, mikrofon, rehber, uygulama kullanımı istemesi.
Art arda pencere — biri reddedilince ardından başkasının gelmesi.
İzin vermeden hiçbir şey çalışmaması — WhatsApp'tan gelen tek bir PDF'i açmak için bile tüm depolama izni.
İnternet + tüm dosyalar birlikte — \"dosyalarım bir yere gidiyor mu?\" endişesi; reklam SDK'ları bu şüpheyi büyütüyor.
Android'in izin modeli (bizim kullandıklarımız)
 | 
Yol | 
Ne verir | 
İzin penceresi | 
Ne zaman kullanılır
 | 
\"Birlikte aç\" / Paylaş (ACTION_VIEW, ACTION_SEND) | 
Kullanıcının verdiği tek dosya | 
Yok | 
Okuyucu modunun tamamı
 | 
SAF dosya seçici (ACTION_OPEN_DOCUMENT) | 
Seçilen dosyalar, kalıcı erişim alınabilir | 
Yok (sistem seçicisi) | 
\"Dosya aç\", \"Farklı kaydet\"
 | 
SAF klasör izni (ACTION_OPEN_DOCUMENT_TREE) | 
Seçilen klasör ağacı | 
Yok (sistem seçicisi) | 
\"Belgeler klasörümü izle\", SD kart
 | 
Photo Picker | 
Seçilen fotoğraf/videolar | 
Yok | 
Görselden PDF, OCR, slayta görsel
 | 
MediaStore + READ_MEDIA_* | 
Tüm fotoğraf/video/ses | 
Var | 
Yalnız galeri benzeri çekirdek iş
 | 
MANAGE_EXTERNAL_STORAGE | 
Paylaşılan depolamanın tamamı (Android/data hariç) | 
Ayarlar sayfası | 
Yalnız dosya yöneticisi modu
Google Play politikası — bizi doğrudan bağlayanlar
Tüm dosyalara erişim: Dosya yöneticisi izinli kategori; ama Play Console'da beyan formu gerekir ve kullanım mağaza sayfasında belirgin şekilde anlatılmalı. \"Tek tek dosya seçtirme\" ve \"medya erişimi\" geçerli gerekçe sayılmıyor. Beyansız/yanıltıcı kullanım hesap kapatmaya kadar gidebilir (Play politikası, Android belgesi).
Fotoğraf/video izinleri: API 33+ hedefleyen uygulama READ_MEDIA_IMAGES/VIDEO'yu yalnız sistem seçicisi yetmiyorsa isteyebilir; 28 Mayıs 2025'ten beri tam uyum zorunlu, uymayan Play'den kaldırılıyor (Play: kısıtlı izinler). Bizde bu izinler yalnız \"tüm dosyalar reddedilirse yedek\" — bu gerekçe Play'de zayıf.
Sıradaki dalga: Aynı sayfaya göre yerel ağ erişimi (ACCESS_LOCAL_NETWORK) için uyum Ağustos 2027'de zorunlu olacak — FTP/Hızlı aktar özelliklerimizi etkiler.
İyi uygulama kuralları (Android: izin isteme): izni özellik kullanılırken iste; öncesinde ne kazanılacağını anlat; reddedilince özelliği kapat ama uygulamayı kilitleme; kullanıcıyı ikna etmek için ayarlara itme; iki ret = sistem artık sormaz.
Uygulamamızın mevcut izin durumu
ci/AndroidManifest.xml bugün 31 izin bildiriyor (eklentilerden gelenler hariç); Play mağaza sayfasındaki \"İzinler\" listesi kullanıcıya bunun tamamını gösterir. Teknik temel sağlam (çoğu izin maxSdkVersion ile eski sürümlere sınırlı, Bluetooth/Wi-Fi neverForLocation), ama görünen liste kalabalık ve ilk açılıştaki istek sırası agresif.
 | 
Grup | 
İzinler | 
Ne için | 
Kullanıcı gözünde risk
 | 
Depolama | 
MANAGE_EXTERNAL_STORAGE, READ/WRITE_EXTERNAL_STORAGE (≤32/≤29), READ_MEDIA_IMAGES/VIDEO/AUDIO | 
Gezgin, temizlik, pano | 
Yüksek — \"tüm dosyalarım\"
 | 
Konum | 
ACCESS_FINE/COARSE_LOCATION (yalnız Android ≤12) | 
Eski sürümlerde Wi-Fi/BLE tarama | 
Yüksek — \"dosya okuyucu neden konum istiyor?\"
 | 
Yakındaki cihaz | 
BLUETOOTH_SCAN/ADVERTISE/CONNECT, NEARBY_WIFI_DEVICES, eski BLUETOOTH* | 
Hızlı aktar | 
Orta
 | 
Mikrofon / Kamera | 
RECORD_AUDIO, CAMERA | 
Slayt anlatımı, dikte, belge tarama | 
Orta-yüksek
 | 
Uygulamalar | 
PACKAGE_USAGE_STATS, REQUEST_INSTALL_PACKAGES (+ eklentiden QUERY_ALL_PACKAGES) | 
Uygulama yöneticisi, APK kurma | 
Orta — \"uygulamalarımı izliyor\"
 | 
Arka plan | 
FOREGROUND_SERVICE_* (DATA_SYNC, MEDIA_PLAYBACK, CONNECTED_DEVICE), WAKE_LOCK, RECEIVE_BOOT_COMPLETED, POST_NOTIFICATIONS | 
Uzun kopyalama, oynatıcı, zamanlanmış işler | 
Düşük-orta
 | 
Ağ | 
INTERNET, *_NETWORK_STATE, *_WIFI_STATE | 
AI, bulut, FTP/aktarma | 
Düşük (ama \"çevrimdışı okuyucu internet ister mi?\")
Akıştaki sorun: StoragePermission.request() (lib/services/fm/storage_permission.dart) sırayla klasik depolama → tüm dosyalara erişim → üç medya iznini art arda soruyor. \"Tüm dosyalar\"ı reddeden kullanıcıya hemen üç pencere daha çıkıyor; yorumlarda en çok kızılan \"izin yağmuru\" tam olarak bu.
Hazır olan altyapı: PermissionGate/PermissionCard (bağlam içinde izin kartı), docs/play/izin_beyanlari.md (her izne gerekçe + bekçi testi), ci/play_variant.py (Play derlemesinden izin çıkarma; karar KALANLAR B5.3'te bekliyor). Yani öneriler büyük ölçüde yeni altyapı değil, sıra ve varsayılan kararı.
İzin stratejisi önerisi: \"Sıfır izinle başla, ihtiyaçta iste\"
Hedef: uygulama kurulup açıldığında hiçbir izin penceresi çıkmasın; her izin yalnız onu gerektiren özelliğe ilk dokunuşta, tek cümlelik gerekçeyle istensin. Mağazada bunu bir vaat olarak söyleyebiliriz: \"İzin istemeden açılır. Dosya yöneticisini kullanmak istersen sorar.\"
1. İzin merdiveni (4 basamak)
 | 
Basamak | 
Kullanıcı ne yapabilir | 
Gereken izin | 
Nasıl istenir
 | 
0 — Okuyucu | 
Birlikte aç/Paylaş ile gelen dosyayı gör, düzenle, dönüştür, kaydet; son dosyalar; Dosyalarım klasörü | 
Hiçbiri | 
—
 | 
1 — Seçerek erişim | 
\"Dosya aç\" (SAF), görsel seç (Photo Picker), \"Bu klasörü ekle\" (ağaç izni) | 
Hiçbiri (sistem seçicisi) | 
Kullanıcı düğmeye basınca
 | 
2 — Dosya yöneticisi | 
Tüm depolamayı gez, temizlik, büyük dosyalar, kopya bulucu, pano halkası | 
Tüm dosyalara erişim | 
Gezgin/Temizlik sekmesine ilk girişte açıklama kartı → ayarlar
 | 
3 — Ekstra özellik | 
Tarama, dikte, Hızlı aktar, uygulama yöneticisi, bildirim | 
Kamera, mikrofon, yakındaki cihazlar, kullanım erişimi, bildirim | 
Yalnız o özelliğe dokununca, tek tek
2. Somut değişiklikler
İlk açılış izin istemesin. Onboarding \"izin ver\" sayfası yerine iki büyük seçenek göstersin: \"Bir dosya aç\" (SAF) ve \"Telefonumdaki tüm dosyaları yönet\" (izin kartı). Okumak için gelen kullanıcı hiç izin görmez.
StoragePermission.request() zincirini kır. \"Tüm dosyalar\" reddedilince artık üç medya iznini sormasın; bunun yerine \"Sorun değil — dosyaları tek tek seçerek açabilirsin\" kartı ve SAF/klasör ekleme düğmesi çıksın.
READ_MEDIA_ izinlerini Play derlemesinden çıkar.* Tüm dosyalar zaten medyayı kapsıyor; yedek yol Photo Picker + SAF olsun. Hem pencere sayısı hem Play politika riski azalır (ci/play_variant.py → DOSYA_PLAY_REMOVE).
\"Klasör ekle\" modunu birinci sınıf yap. İzin vermeyen kullanıcı Download, Documents, WhatsApp Documents gibi klasörleri SAF ağaç izniyle ekleyip gezgini sınırlı ama çalışır hâlde kullanır (SD SAF yazma altyapısı saf_write.dart zaten var).
Mikrofon/kamera/konum bağlam dışı asla sorulmasın. Bugünün PermissionGate deseni doğru; tüm giriş noktalarının ondan geçtiğini bir test ile bekçile (ör. Permission.*.request() yalnız izinli dosyalarda geçebilir).
İki ayrı derleme düşün (opsiyonel, büyük kazanç): \"Dosyalarım Okuyucu\" (izinsiz, yalnız okuyucu + SAF) ve tam sürüm. Okuyucu sürümü mağazada \"0 hassas izin\" diye öne çıkar; Play onayı da kolaylaşır.
3. İzin kartının dili (örnek)
Başlık: Tüm dosyalarını burada görelim mi?
Gövde: Telefonundaki klasörleri gezmek, yer açmak ve dosya taşımak için Android \"tüm dosyalara erişim\" istiyor. Dosyaların telefondan çıkmaz; uygulamada reklam ve izleme yok.
Düğmeler: İzin ver · Şimdilik tek dosya aç (asla \"İptal\" değil — alternatif yolu göster).
4. Güveni görünür kıl
Ayarlar → Gizlilik ve izinler ekranı: her izin, neden kullanıldığı, durumu ve \"geri al\" düğmesi (PermissionStatusRow zaten var — tek sayfada topla).
\"Çevrimdışı kip\" anahtarı: açıkken AI, bulut ve tanılama ağ açmaz; mağazada ve uygulamada açıkça söylenir.
AI'ya gönderim onayı: Gemini'ye dosya gitmeden önce \"bu dosyanın metni Google'a gönderilecek\" bilgisi (otomatik AI analizi zaten varsayılan kapalı — iyi).
Veri Güvenliği formunu birebir doğru doldur (docs/play/veri_guvenligi.md); kategorideki casus yazılım vakaları tam olarak bu formda yalan söyleyen uygulamalardı.
Google Play yorum analizi: insanlar ne diyor
En çok tekrarlanan şikayet izin değil reklam; ikinci sırada \"bedava denip her şeyin ücretli çıkması\", üçüncü sırada izin/gizlilik güvensizliği. Üçü de aynı duyguya bağlanıyor: \"bu uygulama benim için değil, benden para/veri koparmak için var.\"
Yöntem notu: Play yorum sayfaları doğrudan okunamıyor (JavaScript, bot engeli). Bulgular yorumları özetleyen toplayıcı sitelerden, haberlerden ve uygulama listelerinden; bazı özetler sitelerin kendi otomatik çıkarımı. Oranlar değil, tekrar eden temalar olarak okunmalı. Kesin sayı için Play Console'a girince rakiplerin 1–2 yıldızlı yorumları elle sıralanmalı.
İncelenen uygulamalar
 | 
Uygulama | 
Puan / kitle | 
Öne çıkan şikayet | 
Öne çıkan övgü
 | 
Adobe Acrobat Reader | 
4,5 · ~7,3 M yorum | 
\"Bedava diye reklamı yapılıyor\", güncellemeden sonra sade okuyucu olmaktan çıktı, düzenleme abonelikte; 16 izin (kişiler, ses kaydı, kurulu uygulamalar) | 
Güvenilir PDF görüntüleme
 | 
MobiPDF | 
4,3 · ~161 B yorum | 
\"Her küçük özellik ödeme duvarı arkasında\", yoğun reklam, deneme sürümünde bile yazı yazılamıyor, kafa karıştırıcı arayüz | 
Özellik zenginliği
 | 
Files by Google | 
4,5 · ~8,8 M yorum (apppricinglab) | 
FTP/SMB/WebDAV yok, gelişmiş işler sınırlı (anexplorer karşılaştırması) | 
Temizlik önerileri, reklamsız
 | 
\"All Document Reader\" türü (android-stats) | 
— | 
Açılışta geçilemeyen tam ekran reklam, dosyayı açamama | 
—
 | 
Reklam yazılımlı PDF okuyucu (Malwarebytes, 2022) | 
1 M+ indirme | 
Uygulama kapalıyken bile tam ekran reklam; PDF açamıyor | 
—
 | 
Basit dosya yöneticileri (genel liste, chrome-stats) | 
— | 
Onay pencerelerinde bile reklam; rehber/arama izni; IP/çerez takibi | 
—
 | 
Fossify File Manager / Material Files / Amaze | 
Açık kaynak | 
Az özellik, sade görünüm | 
\"Reklam ve izleme yok\", gereksiz izin yok
 | 
Solid Explorer / X-plore / Total Commander | 
Güç kullanıcı | 
Ücretli sürüm, kalabalık arayüz | 
Çift bölme, SMB/FTP, bulut, çöp kutusu
Tema tema şikayetler
Reklam (en sık): açılışta tam ekran, her dosya açılışında reklam, onay pencerelerinde reklam, geçilemeyen video. Bazıları Play'den reklam yazılımı olarak kaldırıldı.
Gizli ücret: \"Ücretsiz\" etiketi + açıldıktan sonra abonelik duvarı; temel işlem (birleştir, imzala, yaz) için haftalık abonelik; bir kez ödenmiş ürünün yeniden satılması (unitQ / kimola özetleri).
İzin ve gizlilik: okuyucunun kişiler, mikrofon, kurulu uygulamalar istemesi; \"tüm dosyalar\"ın açılışta zorunlu tutulması; casus yazılım haberleri sonrası kategoriye genel güvensizlik (KoSpy, Çin sunucularına veri gönderen dosya yöneticisi).
Açamama / bozuk görüntü: \"belge okuyucu\" adına rağmen DOCX/XLSX'i bozuk göstermek, büyük PDF'te donma, parolalı dosya açamama.
Güncellemeyle bozulma: sade okuyucunun güncellemeyle AI/abonelik ekranlarına dönüşmesi; alışılan düğmelerin yer değiştirmesi.
Karmaşık arayüz: özellik yığını arasında \"dosyayı aç\" düğmesinin kaybolması.
Tema tema talepler
\"Sadece açsın\": hızlı, reklamsız, tek dokunuşla açan okuyucu; WhatsApp/Gmail'den gelen dosyayı anında göstermek.
Tek seferlik ödeme ya da tamamen ücretsiz; abonelik yerine \"bir kez al, sonsuza dek\".
Çevrimdışı çalışma ve \"dosyam buluta yüklenmesin\" güvencesi.
Temel PDF işleri ücretsiz: birleştir, böl, imzala, form doldur, görselden PDF.
Güç kullanıcı: çift bölme, SMB/FTP/NAS, bulut hesapları, çöp kutusu, sekmeler, arşiv (ZIP/RAR/7z).
Okuma konforu: gece modu, metin yeniden akışı (reflow), sesli okuma, kaldığı yerden devam, yer imleri.
Temizlik: büyük/kopya dosya, WhatsApp medyası temizliği (Files by Google'ın en sevilen yanı).
Kullanıcı talepleri → bizde ne var, ne yapılmalı
Taleplerin çoğunu kod olarak zaten karşılıyoruz; eksik olan görünürlük ve söz (mağazada ve ilk açılışta söylenmiyor) ile izin akışı. Yeni özellik yerine önce mevcut güçleri öne çıkarmak en ucuz kazanç.
 | 
Talep / şikayet | 
Bizde durum | 
Öneri | 
Öncelik | 
Efor
 | 
Açılışta izin duvarı olmasın | 
İlk açılışta onboarding izin istiyor | 
İzin merdiveni (basamak 0–1 izinsiz) | 
P0 | 
Orta
 | 
Reddedince art arda pencere | 
StoragePermission.request() 3 medya iznini daha soruyor | 
Zinciri kes, SAF/klasör ekle kartı | 
P0 | 
Küçük
 | 
Gereksiz izin listesi | 
31 izin; READ_MEDIA_*, QUERY_ALL_PACKAGES Play'de riskli | 
Play varyantından çıkar (B5.3 kararı) | 
P0 | 
Küçük
 | 
Reklamsız | 
Reklam yok | 
Mağazada ilk satır + ekran görüntüsü; söz olarak sabitle | 
P0 | 
Küçük
 | 
Gizli ücret olmasın | 
Pro iskeleti var (A6.5), içerik kararsız (B5.2) | 
Okuma + temel PDF işleri sonsuza dek ücretsiz; Pro tek seferlik ve açılmadan önce net etiketli | 
P0 | 
Karar
 | 
Dosyam dışarı gitmesin | 
AI, Drive, hata raporu ağ açıyor; otomatik AI varsayılan kapalı | 
\"Çevrimdışı kip\" anahtarı + AI'ya gönderim öncesi onay | 
P1 | 
Küçük
 | 
İzinleri gör/geri al | 
PermissionStatusRow dağınık | 
Ayarlar → Gizlilik ve izinler tek sayfa | 
P1 | 
Küçük
 | 
Office dosyasını bozmadan aç | 
Word/Excel/PPTX okuma-düzenleme var | 
Uyumluluk turu (KALANLAR B4) ve mağazada örnek görsel | 
P1 | 
Orta
 | 
Büyük dosyada donmasın | 
100 MB xlsx akışı, PDF bellek bekçisi (Faz 42) | 
Cihaz perf A/B turunu bitir | 
P1 | 
Cihaz
 | 
Çift bölme, SMB/FTP/SFTP/WebDAV, arşiv | 
Var (Faz 41) | 
Güç kullanıcıya yönelik ayrı ekran görüntüsü | 
P2 | 
Küçük
 | 
Çöp kutusu, geri al | 
Var | 
— | 
— | 
—
 | 
Temizlik (WhatsApp, kopya) | 
Var, akıllı temizlik | 
Files by Google'a karşı ana koz — mağazada 2. sıraya | 
P1 | 
Küçük
 | 
Sesli okuma | 
Sesli kitap, cihazda Türkçe ses | 
\"İnternetsiz\" vurgusu zaten var — koru | 
— | 
—
 | 
OneDrive / Dropbox | 
Yok (B5.8 hesap kararı) | 
Karar sonrası; izin gerektirmez, OAuth yeter | 
P2 | 
Orta
 | 
Türkiye'ye özgü: UYAP .udf | 
Kodda bulunamadı | 
Pazar araştırması: Türk kullanıcı için güçlü ayırıcı olabilir | 
P2 | 
Orta-büyük
 | 
Güncelleme alışkanlığı bozmasın | 
Faz 40 arayüz birliği | 
Büyük değişiklikte \"Neler yeni\" + eski düzene dönüş ayarı | 
P2 | 
Küçük
Mağaza sayfası ve konumlandırma
Rakiplerin zayıf olduğu üç şeyi mağaza metninin ilk satırına taşı: reklamsız, izin istemeden açılır, dosyalar telefondan çıkmaz. Bugünkü metin (docs/play/magaza_metinleri.md) \"reklamsız\"ı söylüyor ama izin ve gizlilik vaadi yok.
 | 
Alan | 
Bugün | 
Öneri
 | 
Başlık (≤30) | 
Dosya Okuyucu: PDF ve Office | 
Aynı kalsın; başlatıcı adı \"Dosyalarım\" ile tutarlılık için B5'te karar ver
 | 
Kısa açıklama (≤80) | 
PDF, Word, Excel, slayt aç-düzenle; dosya yöneticisi, temizlik, sesli kitap. | 
Reklamsız PDF ve Office okuyucu. İzin istemeden açılır, dosyan telefonda kalır. (79 karakter)
 | 
Uzun açıklama ilk paragraf | 
\"tek, hızlı ve reklamsız\" | 
+ \"İzinler\" bloku: hangi izin, hangi özellik, vermezsen ne olur (Play \"tüm dosyalar\" kullanımının mağazada belirgin anlatılmasını zaten istiyor)
 | 
Ekran görüntüsü 1 | 
Özellik | 
\"0 reklam · 0 izin ile açılır\" başlıklı karşılaştırma görseli
 | 
Ekran görüntüsü 2 | 
— | 
İzin kartının kendisi (\"Şimdilik tek dosya aç\" seçeneğiyle)
 | 
Veri Güvenliği | 
veri_guvenligi.md | 
\"Veri toplanmıyor / paylaşılmıyor\" iddiası AI ve hata raporu için istisnalarıyla doğru yazılmalı
Yorumlara yanıt çizgisi: İzin şikayetine her zaman aynı kalıpla, Play Console'dan yanıt ver: neden gerektiği + vermeden nasıl kullanılacağı + gizlilik sayfası bağlantısı. Yanıtlanan düşük puanların bir kısmı güncellenir; rakiplerin çoğu hiç yanıt vermiyor.
Anahtar kelimeler: \"reklamsız pdf okuyucu\", \"izinsiz dosya okuyucu\", \"çevrimdışı pdf\", \"türkçe office okuyucu\", \"udf okuyucu\" (UYAP belgesi açılıyorsa Türkiye'ye özgü güçlü niş — kontrol edilmeli).
Yol haritası
Aşama 1 tamamen bu repoda bugün yapılabilir: izin zinciri, onboarding ve Play varyantı küçük değişiklikler; mağaza metni docs/play/magaza_metinleri.md → tool/magaza_varliklari.py. Aşama 2'nin Pro kararı KALANLAR B5.2'ye, aşama 3'ün ayrı derlemesi ci/play_variant.py desenine bağlanır. İstersen aşama 1'i hemen koda dökebilirim.
Kaynaklar
Politika ve teknik belge
Google Play — Tüm dosyalara erişim (MANAGE_EXTERNAL_STORAGE) politikası
Google Play — Kısıtlı izinler ve asgari kapsamlı alternatifler (fotoğraf/video, yerel ağ)
Android — Manage all files on a storage device
Android — Request runtime permissions
Yorum özetleri ve uygulama listeleri
Adobe Acrobat Reader yorum özeti (grand-screen)
MobiPDF yorum özeti (grand-screen)
PDF editör kullanıcı geri bildirimi raporu (kimola)
Files by Google istatistikleri (apppricinglab)
All Document Reader and Viewer (android-stats)
My Files — File Manager (chrome-stats)
En iyi Android dosya yöneticisi karşılaştırması (anexplorer)
Fossify File Manager incelemesi (It's FOSS)
Güvenlik vakaları
KoSpy casus yazılımı Google Play'de (Gigazine, Mart 2025)
Çin sunucularına veri gönderen iki uygulama (SecurityWeek)
Tam ekran reklam gösteren PDF okuyucu (Malwarebytes, 2022)
Depo içi: ci/AndroidManifest.xml, lib/services/fm/storage_permission.dart, lib/widgets/permission_gate.dart, docs/play/izin_beyanlari.md, docs/play/magaza_metinleri.md, ci/play_variant.py, KALANLAR.md (B5.2, B5.3, B5.8).","complete":true},"frame":{"slug":"86d70f88-78ee-4c05-8076-8cb9642464d5","url":"https://claude.ai/artifact/HejiLU4WU2HK4Sam3HUnoW","artifactUrl":"https://claude.ai/artifact/HejiLU4WU2HK4Sam3HUnoW"}}
This doc takes suggestions. Rewording what is already here ("tighten", "improve", "review", "clean up", "this is clunky") → lay the changes in the doc as suggestions: guide( items = ["topic.index", "topic.suggestions"] ) first. Small fixes met on the way (a typo) go in as suggestions with them. The same when asked to suggest, propose or mark up, when the person wants to look before it goes in, and for a question that invites changes ("Any suggestions?", "What would you change?"): suggestions in the doc on this reply, not a list in chat and not comments. An ask for only an exact fix (a typo, a stated fact), new content, a delete or a move → save the edit as usual; the same in a doc you made in this chat, for a rewrite of the whole doc, when told to edit directly, and on an unattended run. While the person is in Suggesting mode, lay it as a suggestion. The person tells you in chat to go ahead with suggestions you laid on an earlier reply ("go ahead", "do the second one") → accept the ones they mean, one call each (topic.suggestions), rather than write the change again. Any other question about the doc → answer in chat.