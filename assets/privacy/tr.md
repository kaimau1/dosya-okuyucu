# Gizlilik Politikası — Dosya Okuyucu

**Son güncelleme:** 26 Kasım 2026 · **Sürüm:** 1.2.0

## Özet

Dosya Okuyucu **cihazınızda çalışan** bir dosya yöneticisi ve belge
okuyucu/düzenleyicidir. Dosyalarınızı toplayan, sizi izleyen ya da veri satan
bir sunucumuz **yoktur**. Uygulama içinde **reklam yoktur**, **kullanım
takibi (analitik) yoktur**.

Veriniz cihazdan yalnızca **sizin başlattığınız** bir işlemle çıkar; hangi
işlemin neyi nereye gönderdiği aşağıda tek tek yazılıdır.

## 1. Cihazda kalan veriler

Aşağıdakiler uygulamanın özel klasöründe tutulur, cihazdan çıkmaz:

- Ayarlarınız (tema, dil, yerleşim, açılış klasörü)
- Son açılan dosyalar, açılma geçmişi, etiketler, favoriler
- Arama dizini ve küçük resim önbelleği
- Çöp kutusundaki dosyalar
- Klasör kilidi PIN'i ve kilitli klasör listesi
- AI kalıcı hafıza notları (siz kaydettiyseniz)
- **Hata (çökme) kayıtları** — aşağıda ayrı başlık

Uygulamayı kaldırdığınızda bunların hepsi silinir. Kaldırmadan silmek için:
**Ayarlar → Gizlilik → Verilerimi sil** (geçmiş, yapay zekâ kayıtları, arama dizinleri,
hata kayıtları; dosyalarınıza dokunulmaz). Uygulama verisi Android yedeğine alınmaz.

## 2. Cihazdan çıkan veriler — yalnız sizin başlattığınız işlemlerde

| İşlem | Nereye gider | Ne gider |
|---|---|---|
| **Gemini AI** (sohbet, özet, analiz) | Google — `generativelanguage.googleapis.com` | Sorunuz ve AI'a açtığınız dosyanın metni. **Kendi API anahtarınızla** gider; anahtarı siz girersiniz, cihazda saklanır ve bizim sunucumuza uğramaz. |
| **Bulut OCR ve görsel AI** (isteğe bağlı) | Google — `generativelanguage.googleapis.com` | Yalnız Ayarlar'dan **Bulut OCR (Gemini)** seçeneğini açtıysanız veya bir görselde **"Görselde ne var?" / AI kalite-kare puanlama** başlattıysanız: seçilen sayfa/görselin küçültülmüş önizlemesi **kendi API anahtarınızla** gider. Varsayılan OCR cihazda çalışır. |
| **Google Drive** | Google | Yalnız siz bağlarsanız: yüklediğiniz/indirdiğiniz dosyalar ve dosya listesi |
| **Ağ depolama** (FTP/SFTP/SMB/WebDAV) | **Sizin** sunucunuz | Bağlantı bilgileri ve aktardığınız dosyalar. Bu bağlantılar bizden geçmez. |
| **İndirme yöneticisi** | Girdiğiniz adres | İndirme isteği |
| **Çeviri** (ML Kit) | Google | Yalnız **dil modeli ilk kez indirilirken**. Çevirinin kendisi cihazda, çevrimdışı yapılır. |
| **Paylaş / Yazdır** | Seçtiğiniz uygulama | Paylaştığınız dosya |
| **AI ile anlamla arama** | Google — `generativelanguage.googleapis.com` | **Yalnız yazdığınız arama sorgusu** (kendi anahtarınızla). Dosya adları ve içerikleri gitmez; eşleştirme cihazda yapılır. |
| **AI ile etiketleme / kategorilere ayırma** | Google — `generativelanguage.googleapis.com` | Seçtiğiniz dosyaların **adı, uzantısı, bulunduğu klasörün ADI** (tam yol değil), boyutu ve ayı (kategori analizinde ayrıca sayı/boyut özeti). Dosya içeriği gitmez; kamera klasörü ve kilitli klasörler hiç gönderilmez. Öneriler siz onaylamadan yazılmaz. |
| **Yapay zekâ sesleri** (Antalia-2 Mini, EMA Lightning) | Hugging Face — `huggingface.co`, `cdn.jsdelivr.net` | Yalnız sesi **siz indirirken**: model ve ses motoru dosyalarının indirme isteği. Metniniz gönderilmez — seslendirme cihazda, internetsiz yapılır. |
| **Görsel netleştirme (4× AI büyütme)** (isteğe bağlı) | TensorFlow Hub — `tfhub.dev` | Yalnız galeride **AI ile netleştir** dediğinizde, model dosyası cihazda yoksa ilk kurulum indirmesi yapılır. Fotoğrafınız sunucuya gönderilmez; büyütme cihazda çalışır. |
| **Altyazı arama** (Kişisel/GitHub) | OpenSubtitles — `api.opensubtitles.com` | Yalnız Kişisel derlemede video oynatıcıda **Altyazı ara** dediğinizde: yazdığınız arama sorgusu (film/video adı) ve seçtiğiniz altyazıyı indirme isteği. |

**Varsayılan metin tanıma (OCR), akıllı temizlik analizi, sesli kitap üretimi, belge
tarama ve çeviri motorları cihazda çalışır** — Bulut OCR veya görsel AI özetini
siz açmadıkça belgelerinizin ve görsellerinizin içeriği internete gönderilmez.

**Metni QR kodda gösterme** ağ kullanmaz: yazı, karşı tarafın kamerasıyla
okunan QR kodun içindedir ve hiçbir sunucuya yüklenmez.

**Yakındakiler** (yakındaki cihaza / tarayıcıya dosya gönderme) **üçüncü
taraf sunucu kullanmaz**; dosya iki cihaz arasında doğrudan, yerel ağdan
gider:

- **Bluetooth LE yalnız bulma ve davet için:** Yakındakiler ekranı açıkken
  telefonunuz görünen adını ve bu kuruluma özgü rastgele bir kimliği
  yayınlar. Dosya Bluetooth'tan geçmez.
- **Yerel ağ:** aynı Wi-Fi'deki cihazlar birbirini yerel yayınla bulur;
  ortak Wi-Fi yoksa telefon internetsiz geçici bir ağ (hotspot) kurar.
- **Tarayıcıdan alma:** gönderirken telefon, yalnız yerel ağda erişilebilen
  bir web sayfası açar (8080 bağlantı noktası); sayfa 6 harflik bir
  kodla korunur ve aktarım bitince kapanır.
- Konum izni (yalnız Android 12 ve öncesi) sistem bu ağ işlemleri için
  istediği için sorulur; **konumunuz okunmaz ve kaydedilmez.**

**Asistan köprüsü** yalnız geliştiricinin **kişisel derlemesinde** vardır
(mağaza ve GitHub sürümünde yoktur): aynı imzayla imzalanmış asistan
uygulaması bir dosyayı sesli okutabilir ya da özetini açabilir. Başka
uygulamalar bu köprüyü kullanamaz; veri cihazdan çıkmaz.

## 3. Hata (çökme) kayıtları

Uygulama beklenmedik bir hatayla karşılaştığında hatanın teknik özeti
(hata mesajı, yığın izi, saat, Android sürümü) **cihazınızda** bir dosyaya
yazılır. Bu kayıtlar:

- **Otomatik olarak hiçbir yere gönderilmez.**
- Ayarlar → Hakkında → **Hata kayıtları**'ndan tamamı okunabilir.
- Yalnız siz **Paylaş** düğmesine basarsanız, seçtiğiniz yere gider.
- İstediğiniz an **Temizle** ile silinir.
- En fazla son 20 kayıt tutulur.

Hata metni, hataya yol açan dosyanın adını/yolunu içerebilir. Bu yüzden
paylaşmadan önce metnin tamamı ekranda gösterilir — ne gönderdiğinizi görerek
karar verirsiniz.

**Sorunu bildir (anonim özet).** Hata kayıtları ekranındaki bu düğme, hata
sayılarını (çökme, yanıt vermeme/ANR, bellek yetersizliği), hataların ilk
satırlarını ve isterseniz kare süresi dağılımını içeren kısa bir özet
hazırlar. Dosya adları, yollar, e-posta adresleri ve 6 haneden uzun sayılar
(T.C. kimlik no, telefon vb.) maskelenir; belge içeriği hiç girmez. Özet
önce ekranda gösterilir, yalnız siz **Paylaş**'a basarsanız gider. "Kare
ölçümü" varsayılan olarak kapalıdır ve yalnız sayısal bir dağılım tutar.

## 4. İzinler ve nedenleri

| İzin | Niçin |
|---|---|
| Tüm dosyalara erişim (`MANAGE_EXTERNAL_STORAGE`) | Bir dosya yöneticisinin telefondaki klasörleri gezebilmesi için. Vermezseniz uygulama yine çalışır; seçtiğiniz dosyaları sistem seçicisiyle açıp düzenleyebilirsiniz. |
| Medya (görsel/video/ses) | Galeri, oynatıcı ve küçük resimler |
| Kamera | Yalnız belge tarayıcı. Kamerasız cihazda uygulama tam çalışır. |
| Mikrofon (`RECORD_AUDIO`) (Kişisel/GitHub) | Yalnız Kişisel derlemede slayt sunumunda anlatım kaydı ve sesle yazma (dikte) başlattığınızda. Play sürümlerinde bu izin kaldırılmıştır. |
| Bildirimler | Uzun işlerin (kopyalama, sıkıştırma, indirme) ilerlemesi |
| Kullanım erişimi (`PACKAGE_USAGE_STATS`) (Kişisel/GitHub) | Yalnız Kişisel derlemede "Uygulamalar" ekranındaki **son açılma tarihi**. Play sürümlerinde kaldırılmıştır. |
| Bilinmeyen kaynak kurulumu (Kişisel/GitHub) | Yalnız Kişisel derlemede `.apk` kurulumu için. Play sürümlerinde kaldırılmıştır. |
| Bluetooth, yakındaki cihazlar, Wi-Fi durumu | Yakındakiler: yakındaki telefonu bulma, davet ve geçici ağ (yukarıda). Vermezseniz QR ve aynı Wi-Fi yolu çalışır. |
| Konum (yalnız Android 12 ve öncesi) | Android eski sürümlerde Bluetooth taramayı ve geçici ağı konum iznine bağlıyor. Konum okunmaz. |
| Yüklü uygulamaları görme | "Uygulamalar" ekranı: liste, boyut, sistemin kaldırma penceresi. Liste cihazdan çıkmaz. |
| Açılışta çalışma | Siz açtıysanız SD kartla birleşik depolamanın dönemsel işi yeniden başlatmadan sonra da sürsün diye. |
| İnternet | Yukarıdaki 2. bölümdeki işlemler |

## 5. Çocuklar

Uygulama çocuklara yönelik değildir ve çocuklardan bilerek veri toplamaz
(zaten hiç kimseden veri toplamamaktadır).

## 6. Değişiklikler

Bu metin değiştiğinde tarihi güncellenir; güncel hâli her zaman uygulamanın
içinde (Ayarlar → Gizlilik → Gizlilik politikası) ve depoda bulunur.

## 7. İletişim

Soru, gizlilik talebi ve hata bildirimleri için uygulama içinde
**Ayarlar → Hakkında → Hata / istek bildir** bölümünü ya da Google Play
mağaza sayfasındaki geliştirici iletişim adresini kullanabilirsiniz.
