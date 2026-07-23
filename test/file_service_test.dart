import 'dart:convert';
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

  test('eski ofis biçimleri (.doc/.xls/.ppt) legacy → unknown', () {
    expect(FileService.isLegacyOffice('doc'), isTrue);
    expect(FileService.isLegacyOffice('xls'), isTrue);
    expect(FileService.isLegacyOffice('ppt'), isTrue);
    expect(FileService.isLegacyOffice('odt'), isTrue);
    expect(FileService.isLegacyOffice('docx'), isFalse);
    // Modern OOXML kendi editörüne, eski biçim unknown'a gider.
    expect(FileService.kindForExtension('doc'), DocKind.unknown);
    expect(FileService.kindForExtension('docx'), DocKind.word);
  });

  test('.doc yüklenince yönlendirme notlu unknown döner', () async {
    final dir = await Directory.systemTemp.createTemp('fs_test');
    try {
      final f = File('${dir.path}/eski.doc');
      // OLE2 sihirli baytları — gerçek .doc başlığı (yine de açılamaz).
      await f.writeAsBytes(
          Uint8List.fromList([0xD0, 0xCF, 0x11, 0xE0, 1, 2, 3, 4]));
      final doc = await svc.load(f.path);
      expect(doc.kind, DocKind.unknown);
      expect(doc.plainText, contains('.doc'));
    } finally {
      await dir.delete(recursive: true);
    }
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

  test('uzantısız PDF imza baytından tanınır (WhatsApp paylaşımı)', () async {
    // Paylaşım (receive_sharing_intent) dosyayı çoğu zaman uzantısız bir önbellek
    // yoluna kopyalar; tür yalnızca içerik imzasından anlaşılabilir.
    final dir = await Directory.systemTemp.createTemp('fs_test');
    try {
      final f = File('${dir.path}/shared_doc'); // uzantı yok
      // Minimal PDF: "%PDF-1.4\n" + ikili gövde (NUL/ikili baytlar içerir).
      await f.writeAsBytes(Uint8List.fromList([
        0x25, 0x50, 0x44, 0x46, 0x2D, 0x31, 0x2E, 0x34, 0x0A, // %PDF-1.4\n
        0x25, 0xE2, 0xE3, 0xCF, 0xD3, 0x0A, 0x00, 0x01,
      ]));
      final doc = await svc.load(f.path);
      expect(doc.kind, DocKind.pdf);
    } finally {
      await dir.delete(recursive: true);
    }
  });

  test('uzantısız PNG imza baytından görsel olarak tanınır', () async {
    final dir = await Directory.systemTemp.createTemp('fs_test');
    try {
      final f = File('${dir.path}/gorsel'); // uzantı yok
      await f.writeAsBytes(Uint8List.fromList([
        0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, // PNG imzası
        0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52,
      ]));
      final doc = await svc.load(f.path);
      expect(doc.kind, DocKind.image);
    } finally {
      await dir.delete(recursive: true);
    }
  });

  test('.csv salt-okunur elektronik tablo olarak yüklenir (; ayracı)', () async {
    final dir = await Directory.systemTemp.createTemp('fs_csv');
    try {
      final f = File('${dir.path}/veri.csv');
      await f.writeAsString('ad;yas\nAli;30\nAy;25');
      final doc = await svc.load(f.path);
      expect(doc.kind, DocKind.spreadsheet);
      expect(doc.readOnly, isTrue);
      expect(doc.table, isNotNull);
      expect(doc.table!.length, 3);
      expect(doc.table![0], ['ad', 'yas']);
      expect(doc.table![2], ['Ay', '25']);
    } finally {
      await dir.delete(recursive: true);
    }
  });

  test('.tsv sekme ayracıyla tabloya çözülür', () async {
    final dir = await Directory.systemTemp.createTemp('fs_tsv');
    try {
      final f = File('${dir.path}/veri.tsv');
      await f.writeAsString('a\tb\tc\n1\t2\t3');
      final doc = await svc.load(f.path);
      expect(doc.kind, DocKind.spreadsheet);
      expect(doc.table![1], ['1', '2', '3']);
    } finally {
      await dir.delete(recursive: true);
    }
  });

  test('BOM-lu .csv ilk hücreye BOM yapıştırmaz (round-trip)', () async {
    final dir = await Directory.systemTemp.createTemp('fs_bom');
    try {
      final f = File('${dir.path}/bom.csv');
      // Uygulamanın kendi dışa aktardığı gibi UTF-8 BOM + `;` ayracı.
      await f.writeAsBytes([0xEF, 0xBB, 0xBF, ...utf8.encode('ad;yaş\nAli;30')]);
      final doc = await svc.load(f.path);
      expect(doc.kind, DocKind.spreadsheet);
      expect(doc.table![0][0], 'ad'); // '﻿ad' değil
      expect(doc.table![0][1], 'yaş');
    } finally {
      await dir.delete(recursive: true);
    }
  });
}
