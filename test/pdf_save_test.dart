import 'dart:io';
import 'dart:typed_data';

import 'package:dosya_okuyucu/services/pdf_save.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'support/temp_dir.dart';

/// "Üzerine yaz / kopyasını kaydet" hedef seçimi.
///
/// Kritik davranış: KOPYA özgün dosyaya DOKUNMAMALI. Bu yanlış olsaydı
/// kullanıcı "kopyasını kaydet" deyip belgesini kaybederdi.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory dir;
  late File original;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('pdf_save_test');
    original = File(p.join(dir.path, 'rapor.pdf'));
    await original.writeAsBytes(Uint8List.fromList([1, 2, 3]));
  });

  tearDown(() {
    if (dir.existsSync()) removeTempDir(dir);
  });

  test('overwrite: özgün dosyaya yazar, yolu aynıdır', () async {
    final written = await PdfSave.write(
        original.path, Uint8List.fromList([9, 9]), PdfSaveMode.overwrite);

    expect(written, original.path);
    expect(await original.readAsBytes(), [9, 9]);
  });

  test('copy: yeni dosya açar, özgün dosya DEĞİŞMEZ', () async {
    final written = await PdfSave.write(
        original.path, Uint8List.fromList([9, 9]), PdfSaveMode.copy);

    expect(written, isNot(original.path));
    expect(p.basename(written), 'rapor (kopya).pdf');
    expect(await File(written).readAsBytes(), [9, 9]);
    expect(await original.readAsBytes(), [1, 2, 3]);
  });

  test('copy: ad çakışırsa numaralandırır (var olanı ezmez)', () async {
    final first = await PdfSave.write(
        original.path, Uint8List.fromList([1]), PdfSaveMode.copy);
    final second = await PdfSave.write(
        original.path, Uint8List.fromList([2]), PdfSaveMode.copy);

    expect(p.basename(first), 'rapor (kopya).pdf');
    expect(p.basename(second), 'rapor (kopya 2).pdf');
    expect(await File(first).readAsBytes(), [1]);
    expect(await File(second).readAsBytes(), [2]);
  });

  test('copy hedefi hesaplanırken deneme dosyası geride bırakılmaz', () async {
    await PdfSave.copyTargetFor(original.path);

    final leftovers = dir
        .listSync()
        .map((e) => p.basename(e.path))
        .where((n) => n != 'rapor.pdf')
        .toList();
    expect(leftovers, isEmpty);
  });
}
