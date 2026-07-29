# Üçüncü taraf bileşenler ve lisansları

Bu dosya, uygulamanın içinde dağıtılan üçüncü taraf bileşenleri ve bunların
lisans yükümlülüklerini listeler. Uygulama içinden de görülebilir:
**Ayarlar → Açık kaynak bileşenler**.

## FFmpeg (LGPL v3)

Uygulama, video boyut düşürme/çözünürlük değiştirme işlemleri için **FFmpeg**
kütüphanelerini içerir. Dağıtılan sürüm `ffmpeg-kit` "min" yapılandırmasıdır:

- **Bileşen:** FFmpeg 8.1.2 (libavcodec, libavformat, libavfilter, libavutil,
  libswscale, libswresample)
- **Paket:** [`ffmpeg_kit_flutter_new_min`](https://pub.dev/packages/ffmpeg_kit_flutter_new_min)
  → `com.antonkarpenko:ffmpeg-kit-min`
- **Lisans:** GNU Lesser General Public License v3.0
  (https://www.gnu.org/licenses/lgpl-3.0.html)
- **Kaynak kodu:** https://ffmpeg.org/download.html ve
  https://github.com/arthenica/ffmpeg-kit (ffmpeg-kit yapılandırma betikleri)

### GPL bileşenleri BİLİNÇLİ olarak dağıtılmıyor

`ffmpeg-kit`in `-gpl` yapılandırmaları **x264, x265, xvidcore, vid.stab**
içerir ve bunlar **GPL v3** lisanslıdır. Bunları dağıtmak uygulamanın tamamını
GPL v3 kapsamına sokar ve dağıtım şartlarıyla çakışma riski doğurur. Bu yüzden
GPL'siz (`min`) yapılandırma seçilmiştir.

Sonuç olarak H.264 videolar **cihazın kendi donanım kodlayıcısıyla**
(`h264_mediacodec`) üretilir; donanım kodlayıcı bulunmayan cihazlarda FFmpeg'in
kendi `mpeg4` kodlayıcısına düşülür. Her iki durumda da istenen çözünürlük
birebir uygulanır.

### LGPL v3 yükümlülüklerinin nasıl karşılandığı

1. **Atıf:** bu dosya ve uygulama içindeki "Açık kaynak bileşenler" ekranı.
2. **Kaynak kodun sunulması:** yukarıdaki bağlantılar; kütüphane değiştirilmeden
   olduğu gibi kullanılmaktadır.
3. **Yeniden bağlama (relinking):** FFmpeg **dinamik olarak bağlı** paylaşımlı
   kütüphaneler (`.so`) hâlinde dağıtılır; APK içindeki `lib/<abi>/` dizininden
   çıkarılıp kullanıcının kendi derlediği uyumlu bir sürümle değiştirilebilir.
4. **Değişiklik bildirimi:** FFmpeg kaynağında bir değişiklik yapılmamıştır.

## Diğer bileşenler

Uygulamanın kalan bağımlılıkları (Flutter, pdfrx/PDFium, Syncfusion Flutter PDF,
Google ML Kit, Firebase, `excel`, `archive`, `koni_archive`, `image`,
`video_player`, `audioplayers`, `video_compress`, `flutter_local_notifications`
ve diğerleri) izin verici (BSD/MIT/Apache 2.0) ya da ticari-kullanıma açık
lisanslarla dağıtılmaktadır; tam liste ve sürümler `pubspec.yaml` dosyasındadır.

> **Not:** Bu dosya bir hukuki görüş değildir. Uygulamayı bir mağazada
> yayımlamadan önce lisans yükümlülüklerini kendi durumunuz için doğrulayın.
