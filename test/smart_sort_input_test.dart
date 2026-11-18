import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:dosya_okuyucu/models/fs_entry.dart';
import 'package:dosya_okuyucu/services/fm/smart_sort.dart';
import 'package:dosya_okuyucu/services/fm/smart_sort_input.dart';
import 'package:dosya_okuyucu/services/xlsx_writer.dart';
import 'package:flutter_test/flutter_test.dart';

/// Akıllı düzen 2.0 — her dosya türü, metin kısmı (PLAN §1.1 madde 2):
/// sınır kesme, CSV satır sınırı, meta yazısı ve biçim okuyucuları. Bütün
/// dosyalar sentetik ve küçük (kişisel veri yok).
void main() {
  late Directory tmp;
  setUp(() => tmp = Directory.systemTemp.createTempSync('ssi_'));
  tearDown(() => tmp.deleteSync(recursive: true));

  Uint8List zip(Map<String, String> files) {
    final a = Archive();
    files.forEach((k, v) => a.add(ArchiveFile.string(k, v)));
    return Uint8List.fromList(ZipEncoder().encode(a));
  }

  FsEntry entry(String path, int size) => FsEntry(
      path: path, name: path.split('/').last, isDir: false,
      sizeBytes: size, modifiedMs: 1);

  group('tür ve kapsam', () {
    test('kindOf: görsel/PDF medya, Office yazı, APK/arşiv meta, ses yok', () {
      expect(SmartSortInput.kindOf('/a/f.jpg'), SmartInputKind.media);
      expect(SmartSortInput.kindOf('/a/f.PDF'), SmartInputKind.media);
      for (final x in ['docx', 'doc', 'odt', 'rtf', 'txt', 'md', 'html', 'epub']) {
        expect(SmartSortInput.kindOf('/a/f.$x'), SmartInputKind.text, reason: x);
      }
      for (final x in ['xlsx', 'xls', 'csv', 'ods']) {
        expect(SmartSortInput.kindOf('/a/f.$x'), SmartInputKind.sheet, reason: x);
      }
      for (final x in ['pptx', 'ppt', 'odp']) {
        expect(SmartSortInput.kindOf('/a/f.$x'), SmartInputKind.slides, reason: x);
      }
      for (final x in ['apk', 'zip', 'rar', '7z']) {
        expect(SmartSortInput.kindOf('/a/f.$x'), SmartInputKind.meta, reason: x);
      }
      for (final x in ['mp3', 'mp4', 'dart', 'exe', '']) {
        expect(SmartSortInput.kindOf('/a/f.$x'), isNull, reason: x);
      }
    });

    test('SmartSort.supports: Office sınırda, büyük APK meta olarak, gizli değil',
        () {
      expect(SmartSort.supports(entry('/s/Download/r.docx', 1000)), isTrue);
      expect(
          SmartSort.supports(
              entry('/s/Download/r.docx', SmartSortInput.maxExtractBytes + 1)),
          isFalse);
      expect(SmartSort.supports(entry('/s/Download/a.apk', 900 << 20)), isTrue);
      expect(SmartSort.supports(entry('/s/Download/s.mp3', 1000)), isFalse);
      expect(SmartSort.supports(entry('/s/.gizli/r.docx', 1000)), isFalse);
      expect(SmartSort.supports(entry('/s/Download/bos.txt', 0)), isFalse);
    });
  });

  group('saf yardımcılar', () {
    test('clip: en çok 20 bin karakter, boşluk sadeleşir, vekil bölünmez', () {
      final long = 'a' * 30000;
      expect(SmartSortInput.clip(long).length, SmartSortInput.maxTextChars);
      expect(SmartSortInput.clip('  x \r\n\r\n\r\n\r\ny   z  '), 'x\n\ny z');
      final emoji = '${'b' * 9}😀';
      final cut = SmartSortInput.clip(emoji, 10);
      expect(cut, 'b' * 9, reason: 'yarım vekil çifti bırakılmaz');
    });

    test('rowsToCsv: 200 dolu satır, boş satır atlanır, sondaki boşlar kırpılır',
        () {
      final rows = [
        for (var i = 0; i < 300; i++) ...[
          ['s$i', 'x,y', '', ''],
          ['', ''],
        ],
      ];
      final csv = SmartSortInput.rowsToCsv(rows);
      final lines = csv.split('\n');
      expect(lines.length, SmartSortInput.maxSheetRows);
      expect(lines.first, 's0,"x,y"');
      expect(lines.last, 's199,"x,y"');
      expect(SmartSortInput.rowsToCsv([
        ['a'],
        ['b']
      ], maxRows: 1), 'a');
    });

    test('metaText: ad, tür, boyut, klasör; içerik okunmadığı söylenir', () {
      final t = SmartSortInput.metaText(
          name: 'oyun.apk',
          sizeBytes: 1572864,
          folder: 'Download',
          apk: true);
      expect(t, contains('File name: oyun.apk'));
      expect(t, contains('APK'));
      expect(t, contains('Size: 1.5 MB'));
      expect(t, contains('Folder: Download'));
      expect(t, contains('content was not read'));
      final z = SmartSortInput.metaText(
          name: 'yedek.zip', sizeBytes: 10, folder: '', apk: false);
      expect(z, contains('compressed archive (zip)'));
      expect(z, contains('Folder: (root)'));
      expect(SmartSortInput.sizeText(512), '512 B');
      expect(SmartSortInput.sizeText(20 << 20), '20 MB');
    });

    test('htmlText: betik/stil atılır, varlıklar çözülür, bloklar satır olur', () {
      final t = SmartSortInput.htmlText('<html><head><style>p{}</style></head>'
          '<body><script>var a=1;</script><h1>Fatura</h1><p>Tutar &amp; KDV'
          '&nbsp;&#252;cret</p><!-- yorum --></body></html>');
      expect(t, 'Fatura\nTutar & KDV ücret');
    });

    test('rtfText: tablo grupları atlanır, cp1254 ve \\u çözülür', () {
      const rtf = r"{\rtf1\ansi{\fonttbl{\f0 Arial;}}{\*\generator X;}"
          r"\f0 Merhaba \'fc\'e7\par d\u252?nya}";
      expect(SmartSortInput.rtfText(rtf), 'Merhaba üç\ndünya');
    });
  });

  group('biçim okuyucuları', () {
    test('docx: paragraflar', () {
      final b = zip({
        'word/document.xml': '<w:document xmlns:w="w"><w:body>'
            '<w:p><w:r><w:t>Kira</w:t></w:r><w:r><w:t> sözleşmesi</w:t></w:r></w:p>'
            '<w:p><w:r><w:t>Madde 1</w:t></w:r></w:p></w:body></w:document>',
      });
      expect(SmartSortInput.fromBytes(b, 'docx'), 'Kira sözleşmesi\nMadde 1');
    });

    test('odt: paragraf, başlık, text:s boşluğu; odp slayt başlıkları', () {
      const ns = 'xmlns:office="o" xmlns:text="t" xmlns:draw="d"';
      final odt = zip({
        'content.xml': '<office:document-content $ns><office:body><office:text>'
            '<text:h>Başlık</text:h><text:p>bir<text:s text:c="2"/>iki'
            '<text:tab/>üç</text:p><text:p/><text:p>son</text:p>'
            '</office:text></office:body></office:document-content>',
      });
      expect(SmartSortInput.fromBytes(odt, 'odt'), 'Başlık\nbir iki\tüç\n\nson');
      final odp = zip({
        'content.xml': '<office:document-content $ns><office:body>'
            '<office:presentation><draw:page><draw:frame><draw:text-box>'
            '<text:p>Giriş</text:p></draw:text-box></draw:frame></draw:page>'
            '<draw:page><text:p>Sonuç</text:p></draw:page>'
            '</office:presentation></office:body></office:document-content>',
      });
      expect(SmartSortInput.fromBytes(odp, 'odp'),
          '— Slayt 1 —\nGiriş\n\n— Slayt 2 —\nSonuç');
    });

    test('ods: ilk sayfa, tekrarlanan hücre/satır tavanlı, ikinci sayfa yok', () {
      const ns = 'xmlns:office="o" xmlns:text="t" xmlns:table="tb"';
      final ods = zip({
        'content.xml': '<office:document-content $ns><office:body>'
            '<office:spreadsheet><table:table table:name="A">'
            '<table:table-row><table:table-cell><text:p>Ürün</text:p>'
            '</table:table-cell><table:table-cell><text:p>Fiyat</text:p>'
            '</table:table-cell><table:table-cell table:number-columns-repeated="1000"/>'
            '</table:table-row>'
            '<table:table-row table:number-rows-repeated="3">'
            '<table:table-cell table:number-columns-repeated="2">'
            '<text:p>x</text:p></table:table-cell></table:table-row>'
            '<table:table-row table:number-rows-repeated="100000">'
            '<table:table-cell table:number-columns-repeated="1000"/>'
            '</table:table-row></table:table>'
            '<table:table table:name="B"><table:table-row><table:table-cell>'
            '<text:p>gizli</text:p></table:table-cell></table:table-row>'
            '</table:table></office:spreadsheet></office:body>'
            '</office:document-content>',
      });
      expect(SmartSortInput.fromBytes(ods, 'ods'), 'Ürün,Fiyat\nx,x\nx,x\nx,x');
      final many = zip({
        'content.xml': '<office:document-content $ns><office:body>'
            '<office:spreadsheet><table:table>'
            '<table:table-row table:number-rows-repeated="5000">'
            '<table:table-cell><text:p>r</text:p></table:table-cell>'
            '</table:table-row></table:table></office:spreadsheet>'
            '</office:body></office:document-content>',
      });
      expect(SmartSortInput.fromBytes(many, 'ods').split('\n').length,
          SmartSortInput.maxSheetRows);
    });

    test('epub: spine sırası, HTML ayıklanır', () {
      final b = zip({
        'META-INF/container.xml':
            '<container><rootfiles><rootfile full-path="OEBPS/c.opf"/></rootfiles></container>',
        'OEBPS/c.opf': '<package><manifest>'
            '<item id="a" href="bolum%201.xhtml"/><item id="b" href="0.xhtml"/>'
            '</manifest><spine><itemref idref="a"/><itemref idref="b"/></spine></package>',
        'OEBPS/bolum 1.xhtml': '<html><body><p>Birinci</p></body></html>',
        'OEBPS/0.xhtml': '<html><body><p>İkinci</p></body></html>',
      });
      expect(SmartSortInput.fromBytes(b, 'epub'), 'Birinci\n\nİkinci');
    });

    test('bozuk dosya boş döner (tur durmaz)', () {
      expect(SmartSortInput.fromBytes(Uint8List.fromList([1, 2, 3]), 'docx'), '');
      expect(SmartSortInput.fromBytes(Uint8List.fromList([1, 2, 3]), 'ods'), '');
    });
  });

  group('dosyadan çıkarma (extract)', () {
    test('txt: baştan 512 KB, UTF-8 karakter ortadan bölünmez, 20 bin sınır',
        () async {
      // 'a' + 'ş' (2 bayt) × N → kesme noktası bir karakterin ortasına düşer;
      // yarım bayt kalsaydı katı UTF-8 düşer ve cp1254'e (Åž) dönerdi.
      final f = File('${tmp.path}/n.txt')..writeAsStringSync('a${'ş' * 300000}');
      final t = await SmartSortInput.extract(f.path, tempDir: tmp.path);
      expect(t.length, SmartSortInput.maxTextChars);
      expect(t.startsWith('aşş'), isTrue);
      expect(t.contains('Å'), isFalse);
    });

    test('csv: ilk 200 dolu satır', () async {
      final f = File('${tmp.path}/t.csv')
        ..writeAsStringSync([for (var i = 0; i < 500; i++) '$i;ad $i'].join('\n'));
      final t = await SmartSortInput.extract(f.path, tempDir: tmp.path);
      final lines = t.split('\n');
      expect(lines.length, SmartSortInput.maxSheetRows);
      expect(lines.first, '0,ad 0');
    });

    test('xlsx: ilk sayfanın ilk 200 satırı (akışla)', () async {
      final cells = <int, Map<int, XlsxWriteCell>>{
        for (var r = 0; r < 400; r++)
          r: {0: XlsxWriteCell(text: 'Satır $r'), 1: XlsxWriteCell(number: r * 2.0)},
      };
      final f = File('${tmp.path}/t.xlsx')
        ..writeAsBytesSync(XlsxWriter.build([
          XlsxWriteSheet(name: 'Veri', cells: cells),
          XlsxWriteSheet(name: 'Öteki', cells: {
            0: {0: const XlsxWriteCell(text: 'ikinci sayfa')}
          }),
        ]));
      final t = await SmartSortInput.extract(f.path, tempDir: tmp.path);
      final lines = t.split('\n');
      expect(lines.length, SmartSortInput.maxSheetRows);
      expect(lines.first, startsWith('Satır 0,'));
      expect(t.contains('ikinci sayfa'), isFalse);
    });

    test('olmayan dosya boş döner', () async {
      expect(await SmartSortInput.extract('${tmp.path}/yok.docx', tempDir: tmp.path),
          '');
    });
  });
}
