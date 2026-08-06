import 'dart:typed_data';

import 'package:dosya_okuyucu/services/xls_legacy.dart';
import 'package:dosya_okuyucu/services/xlsx_reader.dart';
import 'package:flutter_test/flutter_test.dart';

/// Eski `.xls` artık **gerçek Excel ızgarasında** açılıyor: BIFF'ten okunan
/// değer + görünüm `.xlsx`e çevriliyor (2026-08-07). Buradaki testler BIFF
/// kayıtlarını elle üretip zincirin iki ucunu birden doğruluyor.
void main() {
  group('XlsLegacy — BIFF görünüm kayıtları', () {
    test('SST devam kaydında (CONTINUE) metinler kaymaz, kodlama değişebilir',
        () {
      final wb = _Book();
      // İki metin: ikincisi kayıt sınırında bölünüyor ve devam kaydı FARKLI
      // kodlamayla (2 baytlık) geliyor. Eski sürüm blokları düz birleştirdiği
      // için buradan sonrası bozuluyordu.
      final sstData = <int>[
        ..._u32(2), ..._u32(2),
        // "abc" (sıkıştırılmış)
        ..._u16(3), 0x00, 0x61, 0x62, 0x63,
        // "de" + devamı CONTINUE'da: cch 5 ama yalnız 2 karakter burada
        ..._u16(5), 0x00, 0x64, 0x65,
      ];
      wb.globals(0x00FC, sstData);
      wb.globals(0x003C, <int>[
        0x01, // yeni kodlama bayrağı: kalan karakterler 2 bayt
        ..._u16le('ĞŞİ'),
      ]);

      wb.sheetName('Sayfa1');
      wb.cellLabelSst(0, 0, 0);
      wb.cellLabelSst(0, 1, 1);

      final doc = XlsLegacy.parseWorkbookStream(wb.build());
      expect(doc.sheets.single.rows.first, ['abc', 'deĞŞİ']);
    });

    test('XF + FONT + FORMAT: kalın/punto/renk/hizalama ve sayı biçimi', () {
      final wb = _Book();
      // 5 FONT kaydı: BIFF8'de 4 numaralı indeks YOKTUR, ifnt=5 beşinci fonta
      // (listede 4.) denk gelmeli.
      for (var i = 0; i < 4; i++) {
        wb.font(sizePt: 11, bold: false, name: 'Calibri');
      }
      wb.font(sizePt: 16, bold: true, name: 'Arial', colorIndex: 10);
      // Özel sayı biçimi.
      wb.format(164, '0.000');
      // XF 0: varsayılan. XF 1: kalın 16pt + özel biçim + ortalı + dolgu.
      wb.xf();
      wb.xf(
        fontIndex: 5,
        formatIndex: 164,
        hAlign: 2,
        wrap: true,
        fillPattern: 1,
        fillFore: 12,
      );

      wb.sheetName('Veri');
      wb.cellNumber(0, 0, 3.14159, xf: 1);
      // Yerleşik tarih biçimi (14) sayıyı tarih olarak göstermeli.
      wb.xf(formatIndex: 14);
      wb.cellNumber(1, 0, 45000, xf: 2);

      final doc = XlsLegacy.parseWorkbookStream(wb.build());
      final style = doc.styles[1];
      expect(style.bold, isTrue);
      expect(style.fontSize, 16);
      expect(style.fontName, 'Arial');
      expect(style.fontArgb, 0xFFFF0000); // BIFF8 paletinde icv 10 = kırmızı
      expect(style.numFmtCode, '0.000');
      expect(style.hAlign, 'center');
      expect(style.wrap, isTrue);
      expect(style.fillArgb, isNotNull);
      expect(doc.styles[2].numFmtCode, 'dd.mm.yyyy');

      // Uçtan uca: çevrilen .xlsx'te de aynı biçim durmalı.
      final out = XlsxReader.read(doc.toXlsxBytes());
      final layout = out.sheets.first;
      final fmt = out.styles.formatAt(layout.cellAt(0, 0)!.styleIndex);
      expect(fmt.font.bold, isTrue);
      expect(fmt.font.size, 16);
      expect(fmt.numFmtCode, '0.000');
      expect(fmt.align.horizontal, XlsxHAlign.center);
      expect(fmt.align.wrapText, isTrue);
      expect(
          out.styles.formatAt(layout.cellAt(1, 0)!.styleIndex).numFmtCode,
          'dd.mm.yyyy');
    });

    test('satır yüksekliği, sütun genişliği, birleşme ve donmuş bölme taşınır',
        () {
      final wb = _Book();
      wb.xf();
      wb.sheetName('S');
      wb.row(0, heightTwips: 500, custom: true);
      wb.row(2, hidden: true);
      wb.colInfo(0, 0, widthChars256: 20 * 256);
      wb.colInfo(3, 3, widthChars256: 8 * 256, hidden: true);
      wb.cellNumber(0, 0, 1);
      wb.cellNumber(2, 0, 3);
      wb.merged([
        [0, 0, 1, 2],
      ]);
      wb.window2(frozen: true);
      wb.pane(cols: 1, rows: 2);

      final doc = XlsLegacy.parseWorkbookStream(wb.build());
      final s = doc.sheets.single;
      expect(s.rowHeights[0], closeTo(25, 0.01)); // 500/20 punto
      expect(s.hiddenRows, contains(2));
      expect(s.colWidths[0], closeTo(20, 0.01));
      expect(s.hiddenCols, contains(3));
      expect(s.merges.length, 1);
      expect(s.frozenRows, 2);
      expect(s.frozenCols, 1);

      final layout = XlsxReader.read(doc.toXlsxBytes()).sheets.first;
      expect(layout.colWidthChars(0), closeTo(20, 0.01));
      expect(layout.rowHeightPt(0), closeTo(25, 0.01));
      expect(layout.merges.length, 1);
      expect(layout.frozenRows, 2);
      expect(layout.frozenCols, 1);
      expect(layout.hiddenRows, contains(2));
      expect(layout.hiddenCols, contains(3));
    });

    test('mantıksal ve hata hücreleri (BOOLERR) okunur', () {
      final wb = _Book();
      wb.xf();
      wb.sheetName('S');
      wb.boolErr(0, 0, value: 1, isError: false);
      wb.boolErr(0, 1, value: 0x07, isError: true); // #DIV/0!
      final doc = XlsLegacy.parseWorkbookStream(wb.build());
      expect(doc.sheets.single.rows.first, ['DOĞRU', '#DIV/0!']);

      final layout = XlsxReader.read(doc.toXlsxBytes()).sheets.first;
      expect(layout.cellAt(0, 0)?.boolean, isTrue);
      expect(layout.cellAt(0, 1)?.error, '#DIV/0!');
    });

    test('boş ama biçimli hücreler (BLANK) korunur', () {
      final wb = _Book();
      wb.xf();
      wb.xf(fillPattern: 1, fillFore: 13);
      wb.sheetName('S');
      wb.blank(1, 1, xf: 1);
      final doc = XlsLegacy.parseWorkbookStream(wb.build());
      // Değer yok ama biçim var: hücre ızgarada duruyor.
      expect(doc.sheets.single.cells[1]?[1]?.xf, 1);
      expect(doc.sheets.single.rows[1][1], '');
    });

    test('gizli sayfa gizli olarak çevrilir', () {
      final wb = _Book();
      wb.xf();
      wb.sheetName('Gizli', hidden: true);
      wb.cellNumber(0, 0, 1);
      final doc = XlsLegacy.parseWorkbookStream(wb.build());
      expect(doc.sheets.single.hidden, isTrue);
      expect(XlsxReader.read(doc.toXlsxBytes()).sheets.first.hidden, isTrue);
    });
  });
}

// ── BIFF8 kayıt üreteci (yalnız test) ───────────────────────────────────────

List<int> _u16(int v) => [v & 0xFF, (v >> 8) & 0xFF];
List<int> _u32(int v) =>
    [v & 0xFF, (v >> 8) & 0xFF, (v >> 16) & 0xFF, (v >> 24) & 0xFF];
List<int> _u16le(String s) => [
      for (final c in s.codeUnits) ...[c & 0xFF, (c >> 8) & 0xFF],
    ];

/// Sıkıştırılmış (1 bayt/karakter) kısa dize — ASCII dışı karakter yoksa.
List<int> _shortStr(String s) => [s.length, 0x00, ...s.codeUnits];

/// `cch` 2 baytlık dize.
List<int> _longStr(String s) {
  final ascii = s.codeUnits.every((c) => c < 0x100);
  return [
    ..._u16(s.length),
    ascii ? 0x00 : 0x01,
    if (ascii) ...s.codeUnits else ..._u16le(s),
  ];
}

/// Tek sayfalı bir BIFF8 çalışma kitabı kurar. BOUNDSHEET'in konum alanı
/// sayfa alt akışının gerçek offset'iyle yamanır.
class _Book {
  final _globals = <int>[];
  final _sheet = <int>[];
  String _name = 'Sayfa1';
  bool _hidden = false;

  void _rec(List<int> out, int type, List<int> data) {
    out
      ..addAll(_u16(type))
      ..addAll(_u16(data.length))
      ..addAll(data);
  }

  void globals(int type, List<int> data) => _rec(_globals, type, data);

  void font({
    required double sizePt,
    required bool bold,
    required String name,
    int colorIndex = 0x7FFF,
    bool italic = false,
  }) =>
      globals(0x0031, [
        ..._u16((sizePt * 20).round()),
        ..._u16(italic ? 0x0002 : 0),
        ..._u16(colorIndex),
        ..._u16(bold ? 700 : 400),
        ..._u16(0), // sss
        0, // uls
        0, 0, 0, // family, charset, reserved
        ..._shortStr(name),
      ]);

  void format(int id, String code) =>
      globals(0x041E, [..._u16(id), ..._longStr(code)]);

  void xf({
    int fontIndex = 0,
    int formatIndex = 0,
    int hAlign = 0,
    int vAlign = 2,
    bool wrap = false,
    int fillPattern = 0,
    int fillFore = 0,
  }) {
    final data = List<int>.filled(20, 0);
    data.setRange(0, 2, _u16(fontIndex));
    data.setRange(2, 4, _u16(formatIndex));
    data[6] = (hAlign & 0x07) | (wrap ? 0x08 : 0) | ((vAlign & 0x07) << 4);
    // fls (dolgu deseni) 14–17 baytlık alanın en üst 6 biti.
    data.setRange(14, 18, _u32((fillPattern & 0x3F) << 26));
    data.setRange(18, 20, _u16(fillFore & 0x7F));
    globals(0x00E0, data);
  }

  void sheetName(String name, {bool hidden = false}) {
    _name = name;
    _hidden = hidden;
  }

  void cellLabelSst(int r, int c, int isst, {int xf = 0}) =>
      _rec(_sheet, 0x00FD,
          [..._u16(r), ..._u16(c), ..._u16(xf), ..._u32(isst)]);

  void cellNumber(int r, int c, double value, {int xf = 0}) {
    final bd = ByteData(8)..setFloat64(0, value, Endian.little);
    _rec(_sheet, 0x0203, [
      ..._u16(r), ..._u16(c), ..._u16(xf),
      ...bd.buffer.asUint8List(),
    ]);
  }

  void blank(int r, int c, {int xf = 0}) =>
      _rec(_sheet, 0x0201, [..._u16(r), ..._u16(c), ..._u16(xf)]);

  void boolErr(int r, int c, {required int value, required bool isError}) =>
      _rec(_sheet, 0x0205,
          [..._u16(r), ..._u16(c), ..._u16(0), value, isError ? 1 : 0]);

  void row(int r,
      {int heightTwips = 255, bool custom = false, bool hidden = false}) {
    var grbit = 0;
    if (hidden) grbit |= 0x0020;
    if (custom) grbit |= 0x0040;
    _rec(_sheet, 0x0208, [
      ..._u16(r), ..._u16(0), ..._u16(1),
      ..._u16(heightTwips),
      ..._u16(0), ..._u16(0),
      ..._u16(grbit),
      ..._u16(0),
    ]);
  }

  void colInfo(int first, int last,
          {required int widthChars256, bool hidden = false}) =>
      _rec(_sheet, 0x007D, [
        ..._u16(first), ..._u16(last), ..._u16(widthChars256),
        ..._u16(0), ..._u16(hidden ? 0x0001 : 0), ..._u16(0),
      ]);

  /// Her giriş: [rowFirst, rowLast, colFirst, colLast].
  void merged(List<List<int>> ranges) => _rec(_sheet, 0x00E5, [
        ..._u16(ranges.length),
        for (final r in ranges) ...[
          ..._u16(r[0]), ..._u16(r[1]), ..._u16(r[2]), ..._u16(r[3]),
        ],
      ]);

  void window2({required bool frozen, bool gridLines = true}) {
    var grbit = 0;
    if (gridLines) grbit |= 0x0002;
    if (frozen) grbit |= 0x0008;
    _rec(_sheet, 0x023E, [..._u16(grbit), ..._u16(0), ..._u16(0)]);
  }

  void pane({required int cols, required int rows}) =>
      _rec(_sheet, 0x0041, [..._u16(cols), ..._u16(rows), ..._u16(0), ..._u16(0)]);

  Uint8List build() {
    final head = <int>[];
    _rec(head, 0x0809, [
      ..._u16(0x0600), ..._u16(0x0005),
      ..._u16(0), ..._u16(0), ..._u32(0), ..._u32(0),
    ]);
    final body = <int>[...head, ..._globals];

    // BOUNDSHEET konumunu bilmek için önce kendi uzunluğunu hesapla.
    final boundData = <int>[
      ..._u32(0), // yer tutucu
      _hidden ? 0x01 : 0x00, 0x00,
      ..._shortStr(_name),
    ];
    final boundRecLen = 4 + boundData.length;
    const eofLen = 4;
    final sheetStart = body.length + boundRecLen + eofLen;
    boundData.setRange(0, 4, _u32(sheetStart));
    _rec(body, 0x0085, boundData);
    _rec(body, 0x000A, const []); // globals EOF

    // Sayfa alt akışı.
    _rec(body, 0x0809, [
      ..._u16(0x0600), ..._u16(0x0010),
      ..._u16(0), ..._u16(0), ..._u32(0), ..._u32(0),
    ]);
    body.addAll(_sheet);
    _rec(body, 0x000A, const []);
    return Uint8List.fromList(body);
  }
}
