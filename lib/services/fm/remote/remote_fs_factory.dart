import '../../../models/remote_connection.dart';
import 'ftp_fs.dart';
import 'remote_fs.dart';
import 'sftp_fs.dart';
import 'smb_fs.dart';
import 'webdav_fs.dart';

/// Bağlantı ayarından doğru [RemoteFs] gerçeklemesini üretir.
///
/// Tek yerde durması önemli: arayüz hiçbir yerde protokole bakmıyor, yalnız
/// `RemoteFs` görüyor. Yeni protokol eklemek bu switch'e bir satır.
RemoteFs createRemoteFs(RemoteConnection connection) => switch (connection.protocol) {
      RemoteProtocol.sftp => SftpFs(connection),
      RemoteProtocol.smb => SmbFs(connection),
      RemoteProtocol.webdav => WebDavFs(connection),
      RemoteProtocol.ftp ||
      RemoteProtocol.ftps ||
      RemoteProtocol.ftpes =>
        FtpFs(connection),
    };
