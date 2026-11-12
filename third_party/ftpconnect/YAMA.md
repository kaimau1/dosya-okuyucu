# ftpconnect 3.0.0 yaması (Güvenlik G8.2, 2026-11-12)

**Tek değişiklik** — `lib/src/ftp/ftp_socket.dart` (+ `lib/ftpconnect.dart` dışa aktarımı):
üç `onBadCertificate: (certificate) => true` satırı `FtpTlsTrust.onBadCertificate`
kancasına bağlandı (denetim bağlantısı, FTPES yükseltmesi, veri kanalı). Kanca null ise
davranış yukarı akışla aynı (her sertifika kabul). Veri kanalı, denetim bağlantısında kabul
edilen sertifikanın aynısını sunarsa yeniden sorulmaz.

**Neden:** kendinden imzalı FTPS sertifikası sessizce kabul ediliyordu — aynı ağdaki biri
sunucunun yerine geçip parolayı alabilirdi. Uygulama tarafı `lib/services/fm/remote/ftps_trust.dart`
(ilk kullanımda güven, değişince kırmızı uyarı; SFTP G8.1 ile aynı pencere).

**Yükseltmede:** yeni sürümde sertifika doğrulama kancası varsa kopyayı sil, `FtpFs.connect`'te
o kancayı kullan. Kopyada yalnız `lib/`, `pubspec.yaml`, `LICENSE`, `README.md`, `CHANGELOG.md` var.
