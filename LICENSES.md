# Üçüncü taraf bileşenler ve lisansları

Bu dosya, uygulamanın içinde dağıtılan üçüncü taraf bileşenleri ve bunların
lisans yükümlülüklerini listeler. Uygulama içinden de görülebilir:
**Ayarlar → Açık kaynak bileşenler**.

## Video motoru — Android Media3 (Apache 2.0)

Video küçültme ve oynatma Android **Media3** (Transformer + ExoPlayer, Apache
2.0) ile yapılır; H.264 kodlaması cihazın donanım kodlayıcısında. 2026-10-21'e
kadar dağıtılan FFmpeg (LGPL v3, `ffmpeg_kit_flutter_new_min`) ve
`video_compress` kaldırıldı (Faz 10, karar K2) — LGPL yükümlülükleri artık yok.
Geçmiş doğrulama notları: `docs/hafiza/2026-07.md` (FFmpeg lisans denetimi).

## Diğer bileşenler

Uygulamanın kalan bağımlılıkları (Flutter, pdfrx/PDFium, Syncfusion Flutter PDF,
Google ML Kit, `excel`, `archive`, `koni_archive`, `image`,
`video_player`, `flutter_local_notifications`
ve diğerleri) izin verici (BSD/MIT/Apache 2.0) ya da ticari-kullanıma açık
lisanslarla dağıtılmaktadır; tam liste ve sürümler `pubspec.yaml` dosyasındadır.

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
