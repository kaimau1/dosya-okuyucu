import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

// Sıkıştırma (.zip üretimi) ve koni'nin kapsamadığı tek-dosya biçimleri
// (.bz2/.xz) için mevcut `archive` paketi; okuma/çıkarma için koni.
import 'package:archive/archive_io.dart' as legacy;
import 'package:koni_archive/io.dart' as koni;
import 'package:path/path.dart' as p;

import 'file_ops.dart';
import 'fs_events.dart';
import 'fs_scan.dart';

/// Arşiv içindeki tek bir öğe (uygulama tarafı modeli).
///
/// koni'nin `ArchiveEntry`'si doğrudan ekranlara verilmez: arayüz tek bir
/// kütüphaneye bağlanmasın ve model isolate sınırından sorunsuz geçsin diye
/// sade bir kopya kullanılır.
class ArchiveItem {
  final String path;
  final bool isDir;
  final int size;
  final int compressedSize;
  final bool isEncrypted;
  final int modifiedMs;
  final String compression;

  const ArchiveItem({
    required this.path,
    required this.isDir,
    required this.size,
    this.compressedSize = 0,
    this.isEncrypted = false,
    this.modifiedMs = 0,
    this.compression = '',
  });

  String get name => p.basename(path);
  String get parent => p.dirname(path) == '.' ? '' : p.dirname(path);
}

/// Bir arşivin içerik listesi.
class ArchiveListing {
  final String archivePath;
  final String formatName;
  final List<ArchiveItem> items;

  /// Arşiv parolayla mı açıldı (şifreli başlık: RAR `-hp`, 7z `-mhe`).
  final bool openedWithPassword;

  /// Çok parçalı bir setin parçası mı (ör. `x.part1.rar`).
  final bool multiVolume;

  const ArchiveListing({
    required this.archivePath,
    required this.formatName,
    required this.items,
    this.openedWithPassword = false,
    this.multiVolume = false,
  });

  List<ArchiveItem> get files => items.where((i) => !i.isDir).toList();
  int get totalBytes => files.fold(0, (sum, i) => sum + i.size);
  bool get hasEncryptedEntries => items.any((i) => i.isEncrypted);
}

/// Arşiv hatalarının uygulama tarafı karşılıkları. Arayüz koni'nin
/// istisna sınıflarını tanımak zorunda kalmasın; parola akışı tek tip olsun.
enum ArchiveFailure {
  /// Şifreli arşiv, parola verilmedi → kullanıcıdan parola iste.
  passwordRequired,

  /// Parola yanlış → tekrar sor.
  wrongPassword,

  /// Biçim/özellik desteklenmiyor (ör. eksik cilt) → "başka uygulamayla aç".
  unsupported,

  /// Bozuk arşiv / CRC uyuşmazlığı.
  corrupt,

  /// Diğer (G/Ç hatası vb.).
  other,
}

class ArchiveError implements Exception {
  final ArchiveFailure failure;
  final String message;
  const ArchiveError(this.failure, this.message);

  @override
  String toString() => message;

  /// Kullanıcıya gösterilecek Türkçe açıklama.
  String get userMessage => switch (failure) {
        ArchiveFailure.passwordRequired => 'Bu arşiv parola korumalı.',
        ArchiveFailure.wrongPassword => 'Parola yanlış.',
        ArchiveFailure.unsupported =>
          'Bu arşiv cihazda açılamıyor: $message',
        ArchiveFailure.corrupt =>
          'Arşiv bozuk görünüyor (sağlama tutmadı): $message',
        ArchiveFailure.other => 'Arşiv açılamadı: $message',
      };
}

/// Arşiv işlemleri: **listele, çıkar, tek dosya çıkar, sıkıştır**.
///
/// **Okuma motoru `koni_archive` (saf Dart, MIT).** ZIP/TAR/GZIP'in yanında
/// **RAR4 + RAR5** (katı/solid arşivler, PPMd, delta/x86 filtreleri, şifreli
/// dosya ve şifreli başlık, çok parçalı setler) ve **7z** okur.
/// *Niye bu paket:* RAR biçiminin sıkıştırıcısı özel mülk; Android'de junrar
/// saran eklentiler yalnız RAR4 çözüyor ve platform kodu ekliyor — CI'da
/// `flutter create` ile üretilen `android/` iskeletini kırılganlaştırırdı.
/// Saf Dart çözücü hem RAR5'i kapsıyor hem de derleme hattına hiç dokunmuyor.
///
/// **Çıkarma her zaman ayrı bir isolate'te koşar** (`Isolate.run`): LZMA/PPMd
/// çözme saf Dart'ta CPU-yoğundur, ana izlekte yapılsa büyük arşivde uygulama
/// donardı (XLSX dersi, HAFIZA 2026-07-22).
abstract final class ArchiveOps {
  /// koni'nin okuduğu biçimler.
  static const _koniExts = {
    'zip', 'cbz', 'jar', 'apks', 'xapk', 'epub',
    'rar', 'cbr',
    '7z', 'cb7',
    'tar', 'cbt', 'gz', 'tgz',
  };

  /// Yalnızca eski `archive` paketiyle açılanlar (koni kapsamı dışında).
  static const _legacyExts = {'bz2', 'xz'};

  static Set<String> get supportedExtract => {..._koniExts, ..._legacyExts};

  static bool canExtract(String path) =>
      supportedExtract.contains(_ext(path)) || _isVolumePart(path);

  static String _ext(String path) =>
      p.extension(path).replaceFirst('.', '').toLowerCase();

  /// `x.r00`, `x.z01`, `x.7z.001` gibi devam ciltleri de arşiv sayılır
  /// (kullanıcı yanlışlıkla ikinci parçaya dokunursa anlamlı hata verilir).
  static bool _isVolumePart(String path) {
    final name = p.basename(path).toLowerCase();
    return RegExp(r'\.(r\d{2}|z\d{2}|\d{3})$').hasMatch(name);
  }

  // ── listeleme ─────────────────────────────────────────────────────────────

  /// Arşivin içindekileri okur (çıkarmadan). Parola gerekiyorsa
  /// [ArchiveError] `passwordRequired` ile döner.
  static Future<ArchiveListing> list(String path, {String? password}) async {
    if (_legacyExts.contains(_ext(path))) {
      // .bz2/.xz tek dosyadır; içerik listesi yoktur.
      return ArchiveListing(
        archivePath: path,
        formatName: _ext(path),
        items: [
          ArchiveItem(
            path: p.basenameWithoutExtension(path),
            isDir: false,
            size: 0,
          ),
        ],
      );
    }
    // Sonuç/hata isolate sınırından SADE bir listeyle geçer — bkz. _guard.
    return _unwrap(await Isolate.run(() => _guard(() => _listSync(path, password))))
        as ArchiveListing;
  }

  // ── çıkarma ───────────────────────────────────────────────────────────────

  /// Arşivin tamamını, adıyla aynı isimli yeni bir klasöre çıkarır ve
  /// klasörü döndürür. Hedef doluysa `" (1)"` eklenir (üzerine yazılmaz).
  static Future<String> extract(
    String archivePath, {
    String? destDir,
    String? password,
    void Function(FmProgress)? onProgress,
  }) async {
    final parent = destDir ?? p.dirname(archivePath);
    final target = FileOps.uniquePath(p.join(parent, _archiveBaseName(archivePath)));

    if (_legacyExts.contains(_ext(archivePath))) {
      await Directory(target).create(recursive: true);
      await legacy.extractFileToDisk(archivePath, target);
      FsEvents.changed();
      return target;
    }

    await Directory(target).create(recursive: true);
    final port = ReceivePort();
    final sub = port.listen((msg) {
      if (msg is List && msg.length == 3) {
        onProgress?.call(FmProgress(msg[0] as int, msg[1] as int, '${msg[2]}'));
      }
    });
    final sendPort = port.sendPort;
    try {
      _unwrap(await Isolate.run(() =>
          _guard(() => _extractSync(archivePath, target, password, sendPort))));
    } finally {
      await sub.cancel();
      port.close();
    }
    FsEvents.changed();
    return target;
  }

  /// Arşivden TEK dosyayı çıkarır (önizleme/açma için) ve yolunu döndürür.
  static Future<String> extractOne(
    String archivePath,
    String entryPath,
    String destDir, {
    String? password,
  }) async {
    await Directory(destDir).create(recursive: true);
    return _unwrap(await Isolate.run(() => _guard(
        () => _extractOneSync(archivePath, entryPath, destDir, password)))) as String;
  }

  // ── sıkıştırma (.zip) ─────────────────────────────────────────────────────

  /// [paths]'i tek bir .zip'e sıkıştırır ve zip'in yolunu döndürür.
  ///
  /// Akış tabanlı `ZipFileEncoder` (tüm arşivi belleğe almaz). **RAR üretmek
  /// mümkün değildir** — RAR sıkıştırıcısı özel mülk ve açık kaynak karşılığı
  /// yok; kullanıcıya .zip (ve istenirse 7z) sunulur.
  static Future<String> zip(
    List<String> paths,
    String destDir, {
    String? archiveName,
    void Function(FmProgress)? onProgress,
  }) async {
    if (paths.isEmpty) throw const FileSystemException('sıkıştırılacak öğe yok');
    final base = archiveName != null && archiveName.trim().isNotEmpty
        ? FileOps.sanitizeName(archiveName)
        : (paths.length == 1
            ? p.basenameWithoutExtension(paths.first)
            : 'arsiv');
    final target = FileOps.uniquePath(p.join(destDir, '$base.zip'));

    final encoder = legacy.ZipFileEncoder();
    encoder.create(target);
    try {
      var done = 0;
      for (final path in paths) {
        onProgress?.call(FmProgress(done, paths.length, p.basename(path)));
        final dir = Directory(path);
        if (dir.existsSync()) {
          await encoder.addDirectory(dir);
        } else {
          await encoder.addFile(File(path));
        }
        done++;
      }
      onProgress?.call(FmProgress(done, paths.length, ''));
    } finally {
      await encoder.close();
    }
    FsEvents.changed();
    return target;
  }

  /// Şifreli/7z sıkıştırma için hedef biçim.
  static Future<String> compress(
    List<String> paths,
    String destDir, {
    String? archiveName,
    CompressFormat format = CompressFormat.zip,
    String? password,
    bool hideNames = false,
    void Function(FmProgress)? onProgress,
  }) async {
    if (paths.isEmpty) throw const FileSystemException('sıkıştırılacak öğe yok');
    // Parolasız düz .zip: kanıtlanmış hızlı yol (ZipFileEncoder) korunur.
    if (format == CompressFormat.zip &&
        (password == null || password.isEmpty)) {
      return zip(paths, destDir,
          archiveName: archiveName, onProgress: onProgress);
    }

    final base = archiveName != null && archiveName.trim().isNotEmpty
        ? FileOps.sanitizeName(archiveName)
        : (paths.length == 1
            ? p.basenameWithoutExtension(paths.first)
            : 'arsiv');
    final ext = format == CompressFormat.sevenZip ? '7z' : 'zip';
    final target = FileOps.uniquePath(p.join(destDir, '$base.$ext'));

    final port = ReceivePort();
    final sub = port.listen((msg) {
      if (msg is List && msg.length == 3) {
        onProgress?.call(FmProgress(msg[0] as int, msg[1] as int, '${msg[2]}'));
      }
    });
    final sendPort = port.sendPort;
    final formatIndex = format.index;
    try {
      _unwrap(await Isolate.run(() => _guard(() => _compressSync(
            paths,
            target,
            formatIndex,
            password,
            hideNames,
            sendPort,
          ))));
    } finally {
      await sub.cancel();
      port.close();
    }
    FsEvents.changed();
    return target;
  }

  // ── çok parçalı arşivler ──────────────────────────────────────────────────

  /// Çok parçalı bir setin [volume]. cildinin dosya yolu (1 = [first]).
  ///
  /// Saf fonksiyon, birim testli. Desteklenen adlandırmalar:
  /// - `ad.part1.rar` → `ad.part2.rar` (basamak genişliği korunur)
  /// - `ad.rar` → `ad.r00`, `ad.r01`, … (RAR'ın eski şeması: cilt 2 = `.r00`)
  /// - `ad.7z.001` → `ad.7z.002`
  /// - `ad.zip` → `ad.z01`, `ad.z02`, …
  static String? volumePath(String first, int volume) {
    if (volume <= 1) return first;
    final dir = p.dirname(first);
    final name = p.basename(first);

    final part = RegExp(r'^(.*\.part)(\d+)(\.rar)$', caseSensitive: false)
        .firstMatch(name);
    if (part != null) {
      final width = part.group(2)!.length;
      return p.join(dir,
          '${part.group(1)}${volume.toString().padLeft(width, '0')}${part.group(3)}');
    }

    final numbered = RegExp(r'^(.*)\.(\d{3})$').firstMatch(name);
    if (numbered != null) {
      return p.join(dir, '${numbered.group(1)}.'
          '${volume.toString().padLeft(3, '0')}');
    }

    final ext = _ext(name);
    final base = p.basenameWithoutExtension(name);
    if (ext == 'rar') {
      // cilt 2 → .r00, cilt 3 → .r01 …
      return p.join(dir, '$base.r${(volume - 2).toString().padLeft(2, '0')}');
    }
    if (ext == 'zip') {
      return p.join(dir, '$base.z${(volume - 1).toString().padLeft(2, '0')}');
    }
    return null;
  }

  /// Çıkarılan klasörün adı: `yedek.tar.gz` → `yedek`, `film.part1.rar` → `film`.
  static String _archiveBaseName(String archivePath) {
    var name = p.basenameWithoutExtension(archivePath);
    if (p.extension(name).toLowerCase() == '.tar') {
      name = p.basenameWithoutExtension(name);
    }
    final part = RegExp(r'^(.*)\.part\d+$', caseSensitive: false)
        .firstMatch(name);
    return part?.group(1) ?? name;
  }
}

// ── isolate'te koşan gerçek iş ───────────────────────────────────────────────

/// Arşivi açar; çok parçalı setlerde sonraki ciltleri de bağlar.
/// Açılan yardımcı cilt kaynaklarını [volumes] listesine ekler — çağıran
/// kapatmakla yükümlüdür (koni ciltleri kapatmaz, belgelenmiş davranış).
Future<koni.Archive> _open(
  String path,
  String? password,
  List<koni.FileByteSource> volumes,
) async {
  try {
    return await koni.openArchiveFile(
      path,
      options: koni.ArchiveReadOptions(
        password: password,
        nextVolume: (volume) async {
          final next = ArchiveOps.volumePath(path, volume);
          if (next == null || !File(next).existsSync()) return null;
          final source = await koni.FileByteSource.open(next);
          volumes.add(source);
          return source;
        },
      ),
    );
  } catch (e) {
    throw _mapError(e);
  }
}

/// Sıkıştırma biçimi. RAR YOK: biçimin sıkıştırıcısı özel mülk, açık kaynak
/// yazıcısı yok (okuma tarafı destekleniyor).
enum CompressFormat {
  /// Yaygın uyumluluk; parola verilirse WinZip AES-256.
  zip,

  /// Daha yüksek sıkıştırma; parola verilirse AES-256-CBC + istenirse
  /// dosya adlarını da gizleyen şifreli başlık.
  sevenZip,
}

/// Arşiv yazma (şifreli ya da 7z). Saf Dart LZMA/AES CPU-yoğun olduğu için
/// isolate içinde koşar; ilerleme dosya bazında bildirilir.
Future<String> _compressSync(
  List<String> paths,
  String target,
  int formatIndex,
  String? password,
  bool hideNames,
  SendPort? progress,
) async {
  // (göreli yol, gerçek yol, klasör mü) üçlüleri
  final entries = <(String, String, bool)>[];
  for (final path in paths) {
    final dir = Directory(path);
    if (dir.existsSync()) {
      final base = p.basename(path);
      entries.add((base, path, true));
      for (final child in dir.listSync(recursive: true, followLinks: false)) {
        final rel = p.join(base, p.relative(child.path, from: path));
        entries.add((rel, child.path, child is Directory));
      }
    } else {
      entries.add((p.basename(path), path, false));
    }
  }

  final writer = await koni.createArchiveFile(
    target,
    format: formatIndex == CompressFormat.sevenZip.index
        ? const koni.SevenZWriteFormat()
        : const koni.ZipWriteFormat(),
    options: koni.ArchiveWriteOptions(
      password: (password == null || password.isEmpty) ? null : password,
      encryptHeader: hideNames,
    ),
  );
  try {
    final files = entries.where((e) => !e.$3).length;
    var done = 0;
    for (final (rel, real, isDir) in entries) {
      if (isDir) {
        await writer.addEntry(koni.ArchiveEntrySpec(
          path: rel,
          type: koni.ArchiveEntryType.directory,
        ));
        continue;
      }
      progress?.send([done, files, p.basename(real)]);
      final file = File(real);
      final size = file.lengthSync();
      await writer.addStream(
        koni.ArchiveEntrySpec(
          path: rel,
          modified: file.lastModifiedSync().toUtc(),
        ),
        file.openRead().cast<Uint8List>(),
        size: size,
      );
      done++;
    }
    progress?.send([done, files, '']);
  } catch (e) {
    throw _mapError(e);
  } finally {
    await writer.close();
  }
  return target;
}

/// İsolate sınırından hata geçirme.
///
/// **TUZAK (CI run #93'te yakalandı):** `Isolate.run` içinde atılan özel
/// istisna nesnesi karşı tarafa AYNI TİPTE ulaşmayabiliyor (sendable olmayan
/// bir alan/stack taşınırsa `RemoteError`'a dönüşüyor) → tiplenmiş
/// `ArchiveFailure` kayboluyor, parola akışı "bilinmeyen hata"ya düşüyordu.
/// Çözüm: isolate ASLA istisna fırlatmaz; sonucu ya da hatayı **sade**
/// (String/int) bir listeyle döndürür, çağıran yeniden kurar.
Future<List<Object?>> _guard<T>(Future<T> Function() body) {
  final completer = Completer<List<Object?>>();
  List<Object?> asError(Object e) {
    final mapped = _mapError(e);
    return ['err', mapped.failure.index, mapped.message];
  }

  // runZonedGuarded: isolate içinde SAHİPSİZ kalan async hata (akış hatası
  // gibi) `Isolate.run`'a ulaşıp `RemoteError`'a dönüşmesin — tipini
  // kaybetmeden sonuca çevrilsin.
  runZonedGuarded(() async {
    try {
      final value = await body();
      if (!completer.isCompleted) completer.complete(['ok', value]);
    } catch (e) {
      if (!completer.isCompleted) completer.complete(asError(e));
    }
  }, (e, _) {
    if (!completer.isCompleted) completer.complete(asError(e));
  });
  return completer.future;
}

Object? _unwrap(List<Object?> result) {
  if (result.isNotEmpty && result.first == 'ok') return result[1];
  final index = result.length > 1 ? result[1] as int : ArchiveFailure.other.index;
  final message = result.length > 2 ? '${result[2]}' : 'bilinmeyen hata';
  throw ArchiveError(ArchiveFailure.values[index], message);
}

ArchiveError _mapError(Object e) {
  if (e is ArchiveError) return e;
  if (e is koni.InvalidPasswordException) {
    return ArchiveError(ArchiveFailure.wrongPassword, e.toString());
  }
  if (e is koni.EncryptedArchiveException) {
    return ArchiveError(ArchiveFailure.passwordRequired, e.toString());
  }
  if (e is koni.UnsupportedFormatException ||
      e is koni.UnsupportedFeatureException ||
      e is koni.UnsupportedCompressionException) {
    return ArchiveError(ArchiveFailure.unsupported, e.toString());
  }
  if (e is koni.ChecksumMismatchException ||
      e is koni.CorruptArchiveException ||
      e is koni.InvalidHeaderException ||
      e is koni.UnexpectedEofException) {
    return ArchiveError(ArchiveFailure.corrupt, e.toString());
  }
  return ArchiveError(ArchiveFailure.other, e.toString());
}

ArchiveItem _toItem(koni.ArchiveEntry e) => ArchiveItem(
      path: e.path,
      isDir: e.type == koni.ArchiveEntryType.directory,
      size: e.uncompressedSize,
      compressedSize: e.compressedSize ?? 0,
      isEncrypted: e.isEncrypted,
      modifiedMs: e.modified?.millisecondsSinceEpoch ?? 0,
      compression: e.compression.name,
    );

Future<ArchiveListing> _listSync(String path, String? password) async {
  final volumes = <koni.FileByteSource>[];
  final archive = await _open(path, password, volumes);
  try {
    final items = archive.entries.map(_toItem).toList();
    return ArchiveListing(
      archivePath: path,
      formatName: archive.format.name,
      items: items,
      openedWithPassword: password != null && password.isNotEmpty,
      multiVolume: volumes.isNotEmpty,
    );
  } catch (e) {
    throw _mapError(e);
  } finally {
    await archive.close();
    for (final v in volumes) {
      await v.close();
    }
  }
}

Future<String> _extractSync(
  String archivePath,
  String target,
  String? password,
  SendPort? progress,
) async {
  final volumes = <koni.FileByteSource>[];
  final archive = await _open(archivePath, password, volumes);
  try {
    // Klasör girdilerini önce oluştur (boş klasörler de korunsun).
    for (final entry in archive.entries) {
      if (entry.type != koni.ArchiveEntryType.directory) continue;
      final dir = _safeJoin(target, entry.path);
      if (dir != null) await Directory(dir).create(recursive: true);
    }

    final files = archive.entries
        .where((e) => e.type == koni.ArchiveEntryType.file)
        .toList();
    var done = 0;
    for (final entry in files) {
      progress?.send([done, files.length, p.basename(entry.path)]);
      final outPath = _safeJoin(target, entry.path);
      // Zip-slip: koni yolları normalleştirip bayrakla işaretler, biz de
      // hedef klasörün dışına düşen her şeyi atlarız (iki kat güvence).
      if (outPath == null || entry.pathEscapedRoot) {
        done++;
        continue;
      }
      final out = File(outPath);
      await out.parent.create(recursive: true);
      // `sink.addStream` KULLANILMIYOR: akış hata verince hata hem dönen
      // future'a hem sink'in done future'ına düşüyor, biri SAHİPSİZ kalıp
      // isolate'i düşürüyordu (CI #94: RemoteError). Elle tüketimde hata tek
      // yerden gelir ve aşağıdaki catch onu tiplenmiş hataya çevirir.
      final sink = out.openWrite();
      try {
        await for (final chunk in archive.openRead(entry)) {
          sink.add(chunk);
        }
        await sink.flush();
      } finally {
        await sink.close();
      }
      if (entry.modified != null) {
        try {
          await out.setLastModified(entry.modified!);
        } catch (_) {
          // bazı dosya sistemleri izin vermez; içerik yine doğru
        }
      }
      done++;
    }
    progress?.send([done, files.length, '']);
    return target;
  } catch (e) {
    throw _mapError(e);
  } finally {
    await archive.close();
    for (final v in volumes) {
      await v.close();
    }
  }
}

Future<String> _extractOneSync(
  String archivePath,
  String entryPath,
  String destDir,
  String? password,
) async {
  final volumes = <koni.FileByteSource>[];
  final archive = await _open(archivePath, password, volumes);
  try {
    final entry = archive.entry(entryPath);
    if (entry == null) {
      throw const ArchiveError(
          ArchiveFailure.other, 'arşivde böyle bir dosya yok');
    }
    final out = File(FileOps.uniquePath(
        p.join(destDir, p.basename(entry.path))));
    final sink = out.openWrite();
    try {
      await for (final chunk in archive.openRead(entry)) {
        sink.add(chunk);
      }
      await sink.flush();
    } finally {
      await sink.close();
    }
    return out.path;
  } catch (e) {
    throw _mapError(e);
  } finally {
    await archive.close();
    for (final v in volumes) {
      await v.close();
    }
  }
}

/// [target] altında güvenli birleştirme; dışarı taşan yol için null.
String? _safeJoin(String target, String entryPath) {
  final joined = p.normalize(p.join(target, entryPath));
  if (!FsPaths.isInside(target, joined)) return null;
  return joined;
}
