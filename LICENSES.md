# Üçüncü taraf bileşenler ve lisansları

Bu dosya, uygulamanın içinde dağıtılan üçüncü taraf bileşenleri ve bunların
lisans yükümlülüklerini listeler. Uygulama içinden de görülebilir:
**Ayarlar → Açık kaynak bileşenler**.

## Video motorları — Android Media3 (Apache 2.0) ve mpv / FFmpeg (LGPL v2.1+)

1. **Android Media3 (Transformer + ExoPlayer, Apache 2.0):** Varsayılan video/ses oynatma ve video küçültme (H.264 donanım kodlayıcısı) Media3 ile yapılır. (Eski `ffmpeg_kit_flutter_new_min` ve `video_compress` 2026-10-21'de kaldırıldı.)
2. **mpv + FFmpeg (`video_player_media_kit` / `media_kit_libs_android_video`):** ExoPlayer'ın çözemediği kodekler (AC3/DTS ses, AVI/WMV/FLV vb.) için yedek oynatıcı olarak kullanılır (2026-11-02). Paket MIT lisanslıdır; Android derlemesinde dinamik bağlanan (`.so`) `libmpv` ve `FFmpeg` kütüphaneleri **GNU LGPL v2.1+** lisanslıdır (GPL kodlayıcı içermez). Kaynak kodu ve derleme betikleri: https://github.com/media-kit/media-kit ve https://github.com/media-kit/libmpv-android-video-build

## İsteğe bağlı indirilen yapay zekâ ve ses modelleri

APK içine gömülmez; yalnız kullanıcı ilgili özelliği ilk kez kullandığında indirilir:
- **ESRGAN (`captain-pool/esrgan-tf2`):** Görselde 4× yapay zekâlı büyütme — Apache 2.0 (`tflite_flutter` / LiteRT Apache 2.0).
- **Antalia-2 Mini (`cloud0day3/antalia-mini`) & EMA Lightning (`canberk7/ema-lightning`):** Cihaz içi Türkçe sesli kitap modelleri — Apache 2.0 (ONNX Runtime Web — MIT).

## Diğer bileşenler

Uygulamanın kalan bağımlılıkları (Flutter, pdfrx/PDFium, Google ML Kit, `archive`, `koni_archive`, `image`, `video_player`, `flutter_local_notifications` ve diğerleri) izin verici (BSD/MIT/Apache 2.0) lisanslarla; **Syncfusion Flutter PDF** (`syncfusion_flutter_pdf`, `syncfusion_flutter_core`) ise **Syncfusion Community License** kapsamında dağıtılmaktadır. Tam liste ve sürümler `pubspec.yaml` dosyasındadır.

Ağ depolama (NAS) bileşenleri ve lisansları:

| Paket | İş | Lisans |
|---|---|---|
| `dartssh2` | SFTP | MIT |
| `ftpconnect` | FTP / FTPS / FTPES | MIT |
| `webdav_client` | WebDAV | BSD 3-Clause |
| `multicast_dns` | Yerel ağ keşfi (mDNS) | BSD (Flutter Authors) |
| `smb_connect` | SMB / CIFS | Apache 2.0 |

Hepsi izin verici lisanslı ve **saf Dart**; hiçbiri APK'ya yerel (native)
kütüphane eklemiyor. PC'den telefona erişim için kullanılan FTP **sunucusu** bize
ait koddur (`lib/services/fm/remote/ftp_server.dart`), üçüncü taraf bileşen
içermez.

> **Not:** Bu dosya bir hukuki görüş değildir. Uygulamayı bir mağazada
> yayımlamadan önce lisans yükümlülüklerini kendi durumunuz için doğrulayın.
