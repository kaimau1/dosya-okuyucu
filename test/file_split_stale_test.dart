import 'dart:io';

import 'package:dosya_okuyucu/services/fm/file_split.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

/// 2026-11-20: aynı dosya önce küçük, sonra büyük parçalarla bölününce eski
/// set'in fazladan parçaları kalıyor ve birleştirme bozuk dosya üretiyordu.
void main() {
  late Directory temp;

  setUp(() => temp = Directory.systemTemp.createTempSync('split-stale'));
  tearDown(() {
    try {
      temp.deleteSync(recursive: true);
    } catch (_) {}
  });

  test('yeniden bölünce eski fazla parçalar silinir, birleşim doğru',
      () async {
    final bytes = List<int>.generate(10 * 1024, (i) => i % 251);
    final src = File(p.join(temp.path, 'v.bin'))..writeAsBytesSync(bytes);
    final small = await FileSplit.split(src.path, partBytes: 1024);
    expect(small, hasLength(10));
    final big = await FileSplit.split(src.path, partBytes: 4096);
    expect(big, hasLength(3));
    expect(File(p.join(temp.path, 'v.bin.004')).existsSync(), isFalse);
    expect(File(p.join(temp.path, 'v.bin.010')).existsSync(), isFalse);

    final out = await FileSplit.join(big.first);
    expect(File(out).readAsBytesSync(), bytes);
  });
}
