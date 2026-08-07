import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:dosya_okuyucu/services/xlsx_compat.dart';
import 'package:dosya_okuyucu/services/xlsx_editor.dart';
import 'package:dosya_okuyucu/services/xlsx_writer.dart';
import 'package:excel/excel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xml/xml.dart';

/// `excel` paketinin reddettiği GERÇEK dosyalar (kullanıcı ekran görüntüsü
/// 2026-08-07: *"custom numFmtId starts at 164 but found a value of 26"*).
void main() {
  group('XlsxCompat — styles.xml onarımı', () {
    test('yerleşik kimliğin yeniden tanımı 164+ kimliğe taşınır', () {
      const xml = '<?xml version="1.0"?>'
          '<styleSheet xmlns="http://schemas.openxmlformats.org/'
          'spreadsheetml/2006/main">'
          '<numFmts count="2">'
          '<numFmt numFmtId="26" formatCode="d/m/yyyy"/>'
          '<numFmt numFmtId="164" formatCode="0.000"/>'
          '</numFmts>'
          '<cellStyleXfs count="1"><xf numFmtId="26"/></cellStyleXfs>'
          '<cellXfs count="3">'
          '<xf numFmtId="0"/><xf numFmtId="26" applyNumberFormat="1"/>'
          '<xf numFmtId="164"/>'
          '</cellXfs>'
          '</styleSheet>';

      final fixed = XlsxCompat.repairStylesXml(xml);
      expect(fixed, isNotNull);
      final doc = XmlDocument.parse(fixed!);

      final defs = doc.findAllElements('numFmt').toList();
      expect(defs.length, 2);
      // 26 boşa çıkan ilk özel kimliğe (165) taşındı, 164 yerinde kaldı.
      final moved = defs.firstWhere((e) => e.getAttribute('formatCode') == 'd/m/yyyy');
      expect(moved.getAttribute('numFmtId'), '165');
      expect(
        defs.firstWhere((e) => e.getAttribute('formatCode') == '0.000')
            .getAttribute('numFmtId'),
        '164',
      );

      // Ona işaret eden HER kayıt güncellendi (yoksa biçim kaybolurdu).
      final refs = [
        for (final xf in doc.findAllElements('xf')) xf.getAttribute('numFmtId'),
      ];
      expect(refs, containsAll(<String>['165', '164', '0']));
      expect(refs, isNot(contains('26')));
    });

    test('aynı kimliğin ikinci tanımı ve formatCode\'suz kayıt düşer', () {
      const xml = '<?xml version="1.0"?><styleSheet>'
          '<numFmts count="3">'
          '<numFmt numFmtId="164" formatCode="0.00"/>'
          '<numFmt numFmtId="164" formatCode="0.000"/>'
          '<numFmt numFmtId="165"/>'
          '</numFmts></styleSheet>';

      final fixed = XlsxCompat.repairStylesXml(xml);
      expect(fixed, isNotNull);
      final defs = XmlDocument.parse(fixed!).findAllElements('numFmt').toList();
      expect(defs.length, 1);
      expect(defs.single.getAttribute('formatCode'), '0.00'); // ilki kalır
      expect(
        XmlDocument.parse(fixed).findAllElements('numFmts').single
            .getAttribute('count'),
        '1',
      );
    });

    test('sorunsuz dosyaya DOKUNULMAZ (null döner)', () {
      const xml = '<?xml version="1.0"?><styleSheet>'
          '<numFmts count="1"><numFmt numFmtId="164" formatCode="0.00"/>'
          '</numFmts></styleSheet>';
      expect(XlsxCompat.repairStylesXml(xml), isNull);
    });

    test('<dxf> içindeki numFmt tanımına dokunulmaz', () {
      const xml = '<?xml version="1.0"?><styleSheet>'
          '<numFmts count="1"><numFmt numFmtId="20" formatCode="h:mm"/></numFmts>'
          '<dxfs count="1"><dxf><numFmt numFmtId="0" formatCode="General"/>'
          '</dxf></dxfs></styleSheet>';
      final fixed = XlsxCompat.repairStylesXml(xml);
      expect(fixed, isNotNull);
      final dxf = XmlDocument.parse(fixed!).findAllElements('dxf').single;
      expect(dxf.findAllElements('numFmt').single.getAttribute('numFmtId'), '0');
    });
  });

  group('XlsxEditor — reddedilen dosya yine de açılır', () {
    /// Geçerli bir paket üretip `styles.xml`ine yerleşik kimlik tanımı enjekte
    /// eder (gerçek üreticilerin — LibreOffice, Google E-Tablolar — yaptığı şey).
    Uint8List packageWithBuiltinNumFmt() {
      final bytes = XlsxWriter.build([
        XlsxWriteSheet(
          name: 'Form',
          cells: {
            0: {0: const XlsxWriteCell(text: 'Tarih'), 1: const XlsxWriteCell(number: 45000)},
          },
        ),
      ]);
      final archive = ZipDecoder().decodeBytes(bytes);
      final rebuilt = Archive();
      for (final f in archive.files) {
        if (f.name != 'xl/styles.xml') {
          rebuilt.addFile(f);
          continue;
        }
        var text = utf8.decode(f.content as List<int>, allowMalformed: true);
        text = text.replaceFirst(
          '<cellXfs',
          '<numFmts count="1"><numFmt numFmtId="26" formatCode="d/m/yyyy"/>'
              '</numFmts><cellXfs',
        );
        final data = utf8.encode(text);
        rebuilt.addFile(ArchiveFile(f.name, data.length, data));
      }
      return Uint8List.fromList(ZipEncoder().encode(rebuilt)!);
    }

    test('excel paketi tek başına DÜŞÜYOR (regresyonun kanıtı)', () {
      expect(() => Excel.decodeBytes(packageWithBuiltinNumFmt()), throwsException);
    });

    test('XlsxEditor.parse onarıp açıyor, veri yerinde', () {
      final editor = XlsxEditor.parse(packageWithBuiltinNumFmt());
      expect(editor.sheets, isNotEmpty);
      expect(editor.sheets.first.rawAt(0, 0), 'Tarih');
    });
  });
}
