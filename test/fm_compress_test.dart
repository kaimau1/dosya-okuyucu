import 'dart:io';

import 'package:dosya_okuyucu/services/fm/archive_ops.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

/// Şifreli arşiv ÜRETME → geri OKUMA turu. Kullanıcının verisini parolayla
/// kilitleyen bir özellik: "yazdığımızı geri açabiliyor muyuz" testle
/// sabitlenmeli (parola unutulursa kurtarma yolu yok).
void main() {
  late Directory tmp;
  late Directory source;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('fm_compress_test');
    source = Directory(p.join(tmp.path, 'kaynak'))..createSync();
    File(p.join(source.path, 'not.txt')).writeAsStringSync('gizli içerik');
    Directory(p.join(source.path, 'alt')).createSync();
    File(p.join(source.path, 'alt', 'derin.txt')).writeAsStringSync('derin');
  });

  tearDown(() => tmp.deleteSync(recursive: true));

  test('parolasız ZIP: hızlı yol (ZipFileEncoder) çalışmayı sürdürür', () async {
    final path = await ArchiveOps.compress([source.path], tmp.path,
        archiveName: 'duz');
    expect(p.extension(path), '.zip');

    final listing = await ArchiveOps.list(path);
    expect(listing.files.any((f) => f.path.endsWith('not.txt')), isTrue);
  });

  test('parolalı ZIP (AES-256): parolasız okunamaz, parolayla açılır',
      () async {
    final path = await ArchiveOps.compress(
      [source.path],
      tmp.path,
      archiveName: 'kilitli',
      password: 'gizli123',
    );

    // Adlar görünür (ZIP'te dizin şifrelenmez) ama içerik şifreli.
    final listing = await ArchiveOps.list(path);
    expect(listing.hasEncryptedEntries, isTrue);

    await expectLater(
      ArchiveOps.extract(path, destDir: p.join(tmp.path, 'x1')),
      throwsA(isA<ArchiveError>()),
    );

    final target = await ArchiveOps.extract(path,
        destDir: p.join(tmp.path, 'x2'), password: 'gizli123');
    expect(
      File(p.join(target, 'kaynak', 'not.txt')).readAsStringSync(),
      'gizli içerik',
    );
  });

  test('parolalı 7z + adları gizle: başlık şifreli, doğru parolayla açılır',
      () async {
    final path = await ArchiveOps.compress(
      [source.path],
      tmp.path,
      archiveName: 'kasa',
      format: CompressFormat.sevenZip,
      password: 'p4rola',
      hideNames: true,
    );
    expect(p.extension(path), '.7z');

    // Başlık şifreli → parolasız LİSTELEME bile başarısız.
    await expectLater(
      ArchiveOps.list(path),
      throwsA(isA<ArchiveError>()),
    );

    final listing = await ArchiveOps.list(path, password: 'p4rola');
    expect(listing.files.map((f) => f.path).any((x) => x.endsWith('not.txt')),
        isTrue);

    final target = await ArchiveOps.extract(path,
        destDir: p.join(tmp.path, 'y'), password: 'p4rola');
    expect(
      File(p.join(target, 'kaynak', 'alt', 'derin.txt')).readAsStringSync(),
      'derin',
    );
  });

  test('yanlış parola içerik yazmaz, hata verir', () async {
    final path = await ArchiveOps.compress(
      [source.path],
      tmp.path,
      archiveName: 'kilitli2',
      format: CompressFormat.sevenZip,
      password: 'dogru',
    );
    await expectLater(
      ArchiveOps.extract(path,
          destDir: p.join(tmp.path, 'z'), password: 'yanlis'),
      throwsA(isA<ArchiveError>()),
    );
  });
}
