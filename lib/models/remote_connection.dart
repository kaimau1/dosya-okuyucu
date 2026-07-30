import 'dart:convert';

/// Desteklenen uzak/paylaşımlı depolama protokolleri.
enum RemoteProtocol { ftp, ftps, ftpes, sftp, smb, webdav }

extension RemoteProtocolInfo on RemoteProtocol {
  /// Kullanıcıya gösterilen ad (protokol adları çevrilmez — evrensel).
  String get label => switch (this) {
        RemoteProtocol.ftp => 'FTP',
        RemoteProtocol.ftps => 'FTPS (örtük)',
        RemoteProtocol.ftpes => 'FTPES (açık)',
        RemoteProtocol.sftp => 'SFTP',
        RemoteProtocol.smb => 'SMB',
        RemoteProtocol.webdav => 'WebDAV',
      };

  int get defaultPort => switch (this) {
        RemoteProtocol.ftp || RemoteProtocol.ftpes => 21,
        RemoteProtocol.ftps => 990,
        RemoteProtocol.sftp => 22,
        RemoteProtocol.smb => 445,
        RemoteProtocol.webdav => 80,
      };

  /// SMB'de kullanıcı adının yanında **etki alanı/çalışma grubu** da sorulur.
  bool get usesDomain => this == RemoteProtocol.smb;

  /// WebDAV'da adres bir URL (şema + yol) olduğu için ayrı alan gerekiyor.
  bool get usesUrl => this == RemoteProtocol.webdav;

  static RemoteProtocol byName(String? name) => RemoteProtocol.values
      .firstWhere((p) => p.name == name, orElse: () => RemoteProtocol.ftp);
}

/// Kayıtlı bir uzak depolama bağlantısı.
///
/// **Parola saklama — bilinçli sınır:** parola cihazda `shared_preferences`
/// içinde DÜZ METİN durur. Android'de uygulama verisi başka uygulamalara
/// kapalıdır (sandbox), ama root'lu ya da yedeği alınmış bir cihazda okunabilir.
/// Bu yüzden [savePassword] var: kapatılırsa parola diske hiç yazılmaz ve her
/// bağlanışta sorulur. Şifreli anahtar deposu (`flutter_secure_storage`) yeni
/// bir platform bağımlılığı demekti; kullanıcıya seçenek sunmak, ona
/// söylemeden düz metin yazmaktan dürüst.
class RemoteConnection {
  /// Kalıcı kimlik (yol/ad değişse de kayıt izlenebilsin).
  final String id;

  /// Listede görünen ad ("Ev NAS").
  final String name;

  final RemoteProtocol protocol;

  /// SMB/FTP/SFTP için makine adı ya da IP. WebDAV'da tam URL.
  final String host;

  final int port;
  final String user;
  final String password;

  /// SMB etki alanı / çalışma grubu (boş = WORKGROUP).
  final String domain;

  /// Bağlanınca açılacak klasör (boşsa protokolün kökü).
  final String initialPath;

  /// Parola diske yazılsın mı (bkz. sınıf açıklaması).
  final bool savePassword;

  const RemoteConnection({
    required this.id,
    required this.name,
    required this.protocol,
    required this.host,
    required this.port,
    this.user = '',
    this.password = '',
    this.domain = '',
    this.initialPath = '',
    this.savePassword = true,
  });

  /// Kökün yolu — SMB'de paylaşım listesi `/`, WebDAV'da URL'in kendi yolu.
  String get rootPath => initialPath.trim().isEmpty ? '/' : initialPath.trim();

  RemoteConnection copyWith({
    String? name,
    RemoteProtocol? protocol,
    String? host,
    int? port,
    String? user,
    String? password,
    String? domain,
    String? initialPath,
    bool? savePassword,
  }) =>
      RemoteConnection(
        id: id,
        name: name ?? this.name,
        protocol: protocol ?? this.protocol,
        host: host ?? this.host,
        port: port ?? this.port,
        user: user ?? this.user,
        password: password ?? this.password,
        domain: domain ?? this.domain,
        initialPath: initialPath ?? this.initialPath,
        savePassword: savePassword ?? this.savePassword,
      );

  /// Diske yazılan biçim. [savePassword] kapalıysa parola **yazılmaz** —
  /// `copyWith(password: '')` demek yerine burada kesiliyor ki bellekteki
  /// nesne oturum boyunca parolayı taşımaya devam etsin.
  Map<String, Object?> toMap() => {
        'id': id,
        'name': name,
        'protocol': protocol.name,
        'host': host,
        'port': port,
        'user': user,
        if (savePassword) 'password': password,
        'domain': domain,
        'initialPath': initialPath,
        'savePassword': savePassword,
      };

  String encode() => jsonEncode(toMap());

  static RemoteConnection? tryDecode(String raw) {
    try {
      final map = jsonDecode(raw);
      if (map is! Map) return null;
      final id = '${map['id'] ?? ''}';
      final host = '${map['host'] ?? ''}';
      if (id.isEmpty || host.isEmpty) return null;
      final protocol = RemoteProtocolInfo.byName('${map['protocol']}');
      return RemoteConnection(
        id: id,
        name: '${map['name'] ?? host}',
        protocol: protocol,
        host: host,
        port: (map['port'] as num?)?.toInt() ?? protocol.defaultPort,
        user: '${map['user'] ?? ''}',
        password: '${map['password'] ?? ''}',
        domain: '${map['domain'] ?? ''}',
        initialPath: '${map['initialPath'] ?? ''}',
        savePassword: map['savePassword'] != false,
      );
    } catch (_) {
      return null;
    }
  }

  /// Listede ikinci satır: `sftp · kullanıcı@sunucu:22`.
  String get summary {
    final auth = user.trim().isEmpty ? '' : '$user@';
    return '${protocol.label} · $auth$host:$port';
  }
}
