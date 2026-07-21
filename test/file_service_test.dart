import 'dart:io';
import 'dart:typed_data';

import 'package:dosya_okuyucu/models/document.dart';
import 'package:dosya_okuyucu/services/file_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final svc = FileService();

  test('uzantıdan tür tespiti geniş türleri kapsar', () {
    expect(FileService.kindForExtension('pdf'), DocKind.pdf);
    expect(FileService.kindForExtension('XLSX'), DocKind.spreadsheet);
    expect(FileService.kindForExtension('docx'), DocKind.word);
    expect(FileService.kindForExtension('pptx'), DocKind.slides);
    expect(FileService.kindForExtension('heic'), DocKind.image); // iPhone görseli
    expect(FileService.kindForExtension('webp'), DocKind.image);
    expect(FileService.kindForExtension('py'), DocKind.text);
    expect(FileService.kindForExtension('yaml'), DocKind.text);
    expect(FileService.kindForExtension('bin'), DocKind.unknown);
  });

  test('uzantısız metin dosyası içerikten metin olarak açılır', () async {
    final dir = await Directory.systemTemp.createTemp('fs_test');
    try {
      final f = File('${dir.path}/README');
      await f.writeAsString('Merhaba dünya\nsatır iki\n');
      final doc = await svc.load(f.path);
      expect(doc.kind, DocKind.text);
      expect(doc.plainText, contains('Merhaba'));
    } finally {
      await dir.delete(recursive: true);
    }
  });

  test('ikili (NUL içeren) dosya bilinmeyen kalır', () async {
    final dir = await Directory.systemTemp.createTemp('fs_test');
    try {
      final f = File('${dir.path}/blob.xyz');
      await f.writeAsBytes(
          Uint8List.fromList([0, 1, 2, 0, 255, 0, 3, 7, 0, 9]));
      final doc = await svc.load(f.path);
      expect(doc.kind, DocKind.unknown);
    } finally {
      await dir.delete(recursive: true);
    }
  });
}
