import 'dart:io';

import 'package:path/path.dart' as p;

import '../../../models/remote_connection.dart';
import '../app_storage_service.dart';
import 'remote_fs.dart';

/// **SAF (Storage Access Framework) dosya sistemi** — kullanıcının klasör
/// izni verdiği bir ağacı gezmek.
///
/// **Niye var (kullanıcı 2026-09-02):** USB bellek takılıyken Android onu
/// dosya YOLU olarak vermiyor; `/storage` altında hiçbir şey görünmüyor ve
/// uygulama "takılı değil" diyordu. Android 11+ üzerinde takılabilir belleğe
/// erişmenin herkese açık yolu SAF: kullanıcı bir kez klasörü seçer,
/// uygulama kalıcı izin alır.
///
/// **Niye `RemoteFs`:** uzak protokoller (FTP/SFTP/SMB/WebDAV) için zaten
/// protokolden bağımsız bir arayüz ve onu süren bir gezgin ekranı var
/// (`RemoteBrowserScreen`, `fs` parametresiyle enjekte edilebiliyor). SAF de
/// tam olarak aynı şekle uyuyor: listele, indir, yükle, sil, klasör aç,
/// yeniden adlandır. Böylece **yeni bir gezgin ekranı yazılmadı** ve
/// "indir-aç-geri yükle" akışı sayesinde bütün biçim desteği (PDF, Office,
/// görsel, video) ilk günden çalışıyor.
///
/// **Yol yerine URI.** SAF'ta girdilerin yolu yoktur, URI'si vardır ve bir
/// çocuğun URI'si ebeveyninden HESAPLANAMAZ — sorgulanır. Bu yüzden
/// [RemoteEntry.path] alanında URI taşınıyor ve gezinti sırasında görülen
/// klasörlerin ebeveynleri gezinti sırasında öğrenilip saklanıyor: "yukarı"
/// dendiğinde ebeveynin URI'si buradan bulunur (bkz. [parentPath]).
///
/// **Sınır — dürüstçe:** SAF ancak Android birimi BAĞLADIYSA çalışır. Android
/// hiç bağlamadıysa klasör seçicide de görünmez; o durumda tek çare aygıtı ham
/// USB olarak sürmek (kendi yığın depolama sürücümüzü yazmak) olurdu — ayrı
/// ve çok daha büyük bir iş.
class SafFs extends RemoteFs {
  /// İzin verilmiş ağacın kök URI'si.
  final String rootUri;

  /// Kökün görünen adı ("USB sürücü", "SDCARD"…).
  final String rootName;

  /// Gezinti sırasında görülen klasörlerin ebeveyni: çocuk URI → ebeveyn URI.
  /// "Yukarı" düğmesi bunu kullanır (SAF'ta ebeveyn hesaplanamaz).
  final Map<String, String> _parents = {};

  SafFs({
    required this.rootUri,
    required this.rootName,
    RemoteConnection? connection,
  }) : super(connection ?? connectionFor(rootUri, rootName));

  /// Gezgin ekranının beklediği sahte bağlantı kaydı.
  ///
  /// SAF bir "sunucu" değil; ekran yalnız ad ve kök yolu için bakıyor.
  /// Uydurma bir protokol enum'u eklemek yerine var olanlardan biri
  /// kullanılıyor ve ekranda hiçbir yerde gösterilmiyor.
  static RemoteConnection connectionFor(String uri, String name) =>
      RemoteConnection(
        id: 'saf:$uri',
        name: name,
        protocol: RemoteProtocol.webdav,
        host: '',
        port: 0,
        initialPath: uri,
        savePassword: false,
      );

  @override
  Future<void> connect() async {
    // İzin zaten verilmiş; bağlanacak bir şey yok. Kökün okunabildiğini
    // doğrulamak için tek listeleme yapılıyor — izin geri alınmışsa kullanıcı
    // "boş klasör" yerine gerçek hatayı görsün.
    final probe = await AppStorageService.safList(rootUri);
    if (probe.isEmpty && !await _rootReadable()) {
      throw const RemoteException(
        RemoteError.denied,
        detail: 'Klasör izni yok ya da geri alınmış.',
      );
    }
  }

  /// Kök gerçekten okunabiliyor mu? (Boş klasör ile izinsizliği ayırmak için.)
  Future<bool> _rootReadable() async {
    final roots = await AppStorageService.safRoots();
    return roots.any((r) => r.uri == rootUri);
  }

  @override
  Future<void> close() async {}

  @override
  Future<List<RemoteEntry>> list(String path) async {
    final uri = path.isEmpty ? rootUri : path;
    final items = await AppStorageService.safList(uri);
    for (final item in items) {
      if (item.isDir) _parents[item.uri] = uri;
    }
    return RemoteFs.sorted([
      for (final item in items)
        RemoteEntry(
          name: item.name,
          path: item.uri,
          isDir: item.isDir,
          sizeBytes: item.sizeBytes,
          modifiedMs: item.modifiedMs,
        ),
    ]);
  }

  /// Bir klasörün ebeveyni — gezinti sırasında öğrenilmişse.
  /// Bilinmiyorsa kök döner (kullanıcı hiçbir zaman ağacın dışına çıkamaz).
  ///
  /// Taban sınıfın yol kesen gerçeklemesi burada YANLIŞ olurdu: URI'nin son
  /// parçası belge kimliğidir, ebeveyni değil.
  @override
  String parentPath(String path) => _parents[path] ?? rootUri;

  /// SAF'ta ebeveyn ve ad AYRI gerekiyor; ekran tek dize veriyor. Ayraç
  /// olarak `/` güvenli: dosya/klasör adı hiçbir dosya sisteminde `/`
  /// içeremez, dolayısıyla son `/` her zaman doğru yerde böler
  /// (bkz. [makeDirectory]).
  @override
  String childPath(String dir, String name) => '$dir/$name';

  @override
  Future<File> download(RemoteEntry entry, String localPath) async {
    final ok = await AppStorageService.safCopyToFile(entry.path, localPath);
    if (!ok) {
      throw const RemoteException(RemoteError.unknown,
          detail: 'Dosya okunamadı.');
    }
    return File(localPath);
  }

  @override
  Future<void> upload(File local, String remoteDir, {String? name}) async {
    final target = name ?? p.basename(local.path);
    final uri = await AppStorageService.safCopyFromFile(
      remoteDir.isEmpty ? rootUri : remoteDir,
      local.path,
      target,
    );
    if (uri == null) {
      throw const RemoteException(RemoteError.denied,
          detail: 'Dosya yazılamadı (klasör salt okunur olabilir).');
    }
  }

  @override
  Future<void> delete(RemoteEntry entry) async {
    if (!await AppStorageService.safDelete(entry.path)) {
      throw const RemoteException(RemoteError.denied, detail: 'Silinemedi.');
    }
  }

  @override
  Future<void> makeDirectory(String path) async {
    // `path` burada "ebeveyn URI/yeni ad" değil; ekran bize tam yolu veriyor.
    // SAF'ta ad ile ebeveyn ayrı gerekiyor, o yüzden son parçayı ayırıyoruz.
    final cut = path.lastIndexOf('/');
    final parent = cut <= 0 ? rootUri : path.substring(0, cut);
    final name = cut < 0 ? path : path.substring(cut + 1);
    if (await AppStorageService.safMkdir(parent, name) == null) {
      throw const RemoteException(RemoteError.denied,
          detail: 'Klasör oluşturulamadı.');
    }
  }

  @override
  Future<void> rename(RemoteEntry entry, String newName) async {
    if (await AppStorageService.safRename(entry.path, newName) == null) {
      throw const RemoteException(RemoteError.denied,
          detail: 'Yeniden adlandırılamadı.');
    }
  }
}
