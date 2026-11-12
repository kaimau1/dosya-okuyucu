import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:dosya_okuyucu/services/office_reader.dart';
import 'package:dosya_okuyucu/services/office_zip_guard.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xml/xml.dart';

/// **G7.3 Office paketleri** (2026-11-12): DOCX/XLSX/PPTX zip'i, hiçbir
/// giriş açılmadan başlıktaki sayı/boyutla sınırlanır; XML dış/iç varlıklar
/// genişletilmez ("milyar kahkaha" belleği patlatmaz).
void main() {
  Uint8List zipOf(Map<String, String> parts) {
    final a = Archive();
    parts.forEach((name, body) {
      final b = utf8.encode(body);
      a.addFile(ArchiveFile(name, b.length, b));
    });
    return Uint8List.fromList(ZipEncoder().encode(a));
  }

  test('olağan paket geçer', () {
    final z = zipOf({'word/document.xml': '<w:document/>'});
    expect(OfficeZipGuard.decode(z).files, hasLength(1));
  });

  test('giriş sayısı sınırı', () {
    final z = zipOf({
      for (var i = 0; i <= OfficeZipGuard.maxEntries; i++) 'x/$i.xml': '',
    });
    expect(() => OfficeZipGuard.decode(z), throwsA(isA<OfficeTooLarge>()));
  });

  test('tek giriş ve toplam boyut sınırı (başlıktaki boyut)', () {
    final big = Archive()
      ..addFile(ArchiveFile(
          'word/document.xml', OfficeZipGuard.maxEntryBytes + 1, Uint8List(0)));
    expect(() => OfficeZipGuard.check(big), throwsA(isA<OfficeTooLarge>()));

    final many = Archive();
    for (var i = 0; i < 6; i++) {
      many.addFile(ArchiveFile(
          'p$i.xml', OfficeZipGuard.maxEntryBytes, Uint8List(0)));
    }
    expect(() => OfficeZipGuard.check(many), throwsA(isA<OfficeTooLarge>()));
  });

  test('OfficeTooLarge bir FormatException (bozuk dosya yolu işler)', () {
    expect(const OfficeTooLarge('x'), isA<FormatException>());
  });

  test('okuyucu sınırı uygular', () {
    final z = zipOf({
      for (var i = 0; i <= OfficeZipGuard.maxEntries; i++) 'x/$i.xml': '',
    });
    expect(() => OfficeReader.extractDocxText(z), throwsA(isA<OfficeTooLarge>()));
  });

  test('milyar kahkaha: iç varlıklar genişletilmez', () {
    final sb = StringBuffer('<?xml version="1.0"?>\n<!DOCTYPE lolz [\n'
        ' <!ENTITY lol "lol">\n');
    for (var i = 1; i <= 9; i++) {
      final prev = i == 1 ? 'lol' : 'lol${i - 1}';
      sb.writeln(' <!ENTITY lol$i "${'&$prev;' * 10}">');
    }
    sb.write(']>\n<lolz>&lol9;</lolz>');
    final sw = Stopwatch()..start();
    // Ayrıştırıcı ya reddeder ya da varlığı düz metin bırakır; ikisinde de
    // 10^9 "lol" belleğe açılmaz.
    try {
      final doc = XmlDocument.parse(sb.toString());
      expect(doc.rootElement.innerText.length, lessThan(100));
    } on XmlException {
      // Bilinçli: reddetmek de güvenli sonuç.
    }
    expect(sw.elapsed, lessThan(const Duration(seconds: 5)));
  });
  test('yalan başlık: açılmış boyutu küçük yazılmış giriş başlıktaki boyutu aşamaz', () {
    // 4 MB sıfır → merkezi dizinde açılmış boyut 1000 diye yazılır.
    final a = Archive()
      ..addFile(ArchiveFile.bytes('word/document.xml', Uint8List(4 * 1024 * 1024)));
    final bytes = Uint8List.fromList(ZipEncoder().encode(a));
    final view = ByteData.sublistView(bytes);
    var patched = 0;
    for (var i = 0; i + 30 < bytes.length; i++) {
      final sig = view.getUint32(i, Endian.little);
      if (sig == 0x04034b50) {
        view.setUint32(i + 22, 1000, Endian.little); // yerel başlık
        patched++;
      } else if (sig == 0x02014b50) {
        view.setUint32(i + 24, 1000, Endian.little); // merkezi dizin
        patched++;
      }
    }
    expect(patched, greaterThanOrEqualTo(2), reason: 'test girdisi anlamlı');
    // Başlık sınırları geçer (1000 bayt) …
    final archive = OfficeZipGuard.decode(bytes);
    // … ama `archive` paketi açmayı başlıktaki boyutla keser (4.6: maxOutputSize
    // = uncompressedSize) → 4 MB belleğe hiç açılmaz, hata FormatException.
    expect(() => archive.files.first.content, throwsA(isA<FormatException>()));
  });
}
