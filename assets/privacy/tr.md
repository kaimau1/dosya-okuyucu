# Gizlilik Politikası — Dosya Okuyucu

**Son güncelleme:** 28 Ağustos 2026 · **Sürüm:** 0.1.0

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

Uygulamayı kaldırdığınızda bunların hepsi silinir.

## 2. Cihazdan çıkan veriler — yalnız sizin başlattığınız işlemlerde

| İşlem | Nereye gider | Ne gider |
|---|---|---|
| **Gemini AI** (sohbet, özet, analiz) | Google — `generativelanguage.googleapis.com` | Sorunuz ve AI'a açtığınız dosyanın metni. **Kendi API anahtarınızla** gider; anahtarı siz girersiniz, cihazda saklanır ve bizim sunucumuza uğramaz. |
| **Google Drive** | Google | Yalnız siz bağlarsanız: yüklediğiniz/indirdiğiniz dosyalar ve dosya listesi |
| **Firebase giriş & senkron** | Google | Yalnız yapılandırılmış ve giriş yapılmışsa: e-posta adresiniz ve senkronladığınız ayarlar. Yapılandırılmamışsa uygulama **yerel modda** çalışır. |
| **Ağ depolama** (FTP/SFTP/SMB/WebDAV) | **Sizin** sunucunuz | Bağlantı bilgileri ve aktardığınız dosyalar. Bu bağlantılar bizden geçmez. |
| **İndirme yöneticisi** | Girdiğiniz adres | İndirme isteği |
| **Çeviri** (ML Kit) | Google | Yalnız **dil modeli ilk kez indirilirken**. Çevirinin kendisi cihazda, çevrimdışı yapılır. |
| **Paylaş / Yazdır** | Seçtiğiniz uygulama | Paylaştığınız dosya |

**Metin tanıma (OCR), belge tarama ve çeviri motorları cihazda çalışır** —
belgelerinizin içeriği bu işlemler için internete gönderilmez.

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

## 4. İzinler ve nedenleri

| İzin | Niçin |
|---|---|
| Tüm dosyalara erişim (`MANAGE_EXTERNAL_STORAGE`) | Bir dosya yöneticisinin telefondaki klasörleri gezebilmesi için. Vermezseniz uygulama çalışır; yalnız medya klasörleri görünür. |
| Medya (görsel/video/ses) | Galeri, oynatıcı ve küçük resimler |
| Kamera | Yalnız belge tarayıcı. Kamerasız cihazda uygulama tam çalışır. |
| Bildirimler | Uzun işlerin (kopyalama, sıkıştırma, indirme) ilerlemesi |
| Kullanım erişimi (`PACKAGE_USAGE_STATS`) | "Uygulamalar" ekranındaki **son açılma tarihi**. Vermezseniz liste yine gelir. |
| Bilinmeyen kaynak kurulumu | Bir `.apk` dosyasına dokunduğunuzda sistemin kurulum ekranını açmak |
| İnternet | Yukarıdaki 2. bölümdeki işlemler |

## 5. Çocuklar

Uygulama çocuklara yönelik değildir ve çocuklardan bilerek veri toplamaz
(zaten hiç kimseden veri toplamamaktadır).

## 6. Değişiklikler

Bu metin değiştiğinde tarihi güncellenir; güncel hâli her zaman uygulamanın
içinde (Ayarlar → Gizlilik → Gizlilik politikası) ve depoda bulunur.

## 7. İletişim

Soru ve bildirimler için:
<https://github.com/kaimau1/dosya-okuyucu/issues>
