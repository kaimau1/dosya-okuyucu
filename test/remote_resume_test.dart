import 'dart:io';

import 'package:dosya_okuyucu/models/remote_connection.dart';
import 'package:dosya_okuyucu/services/fm/remote/remote_fs.dart';
import 'package:flutter_test/flutter_test.dart';

/// Ofsetli okuyabilen sahte sunucu (SFTP gibi) — ya da okuyamayan (FTP gibi).
class _FakeFs extends RemoteFs {
  final List<int> data;
  final bool resumable;
  final offsets = <int>[];
  int? failAfter;

  _FakeFs(this.data, {required this.resumable})
      : super(const RemoteConnection(
            id: 'x', name: 'x', protocol: RemoteProtocol.sftp, host: 'h', port: 22));

  @override
  bool get canResume => resumable;

  @override
  Future<void> downloadFrom(RemoteEntry entry, File part, int offset) async {
    if (!resumable) return super.downloadFrom(entry, part, offset);
    offsets.add(offset);
    final sink = part.openWrite(mode: offset > 0 ? FileMode.append : FileMode.write);
    var end = data.length;
    if (failAfter != null) end = failAfter!;
    sink.add(data.sublist(offset, end));
    await sink.close();
    if (failAfter != null) {
      failAfter = null;
      throw const SocketException('koptu');
    }
  }

  @override
  Future<File> download(RemoteEntry entry, String localPath) async {
    offsets.add(0);
    return File(localPath)..writeAsBytesSync(data);
  }

  @override
  Future<void> connect() async {}
  @override
  Future<void> close() async {}
  @override
  Future<List<RemoteEntry>> list(String path) async => const [];
  @override
  Future<void> upload(File local, String remoteDir, {String? name}) async {}
  @override
  Future<void> delete(RemoteEntry entry) async {}
  @override
  Future<void> makeDirectory(String path) async {}
  @override
  Future<void> rename(RemoteEntry entry, String newName) async {}
}

/// Faz 41 / 8: uzak indirme kaldığı yerden sürer.
void main() {
  final data = List.generate(5000, (i) => i % 251);
  const entry = RemoteEntry(name: 'a.bin', path: '/a.bin', isDir: false, sizeBytes: 5000);
  late Directory dir;
  setUp(() => dir = Directory.systemTemp.createTempSync('rres'));
  tearDown(() => dir.deleteSync(recursive: true));

  test('kopan indirme ikinci denemede kalan baytı çeker', () async {
    final fs = _FakeFs(data, resumable: true)..failAfter = 2000;
    final target = '${dir.path}/a.bin';
    await expectLater(fs.downloadResumable(entry, target), throwsA(isA<SocketException>()));
    expect(File('$target.part').lengthSync(), 2000);
    final f = await fs.downloadResumable(entry, target);
    expect(fs.offsets, [0, 2000]);
    expect(f.readAsBytesSync(), data);
    expect(File('$target.part').existsSync(), isFalse);
  });

  test('devam desteklemeyen protokol yarım parçayı atıp baştan indirir', () async {
    final fs = _FakeFs(data, resumable: false);
    final target = '${dir.path}/b.bin';
    File('$target.part').writeAsBytesSync(List.filled(100, 9));
    final f = await fs.downloadResumable(entry, target);
    expect(f.readAsBytesSync(), data);
  });

  test('ofset kararı', () {
    expect(RemoteFs.resumeOffset(have: 0, size: 10), 0);
    expect(RemoteFs.resumeOffset(have: 4, size: 10), 4);
    expect(RemoteFs.resumeOffset(have: 12, size: 10), 0);
    expect(RemoteFs.resumeOffset(have: 4, size: 0), 0);
  });
}
