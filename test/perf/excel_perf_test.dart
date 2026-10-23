@Tags(['perf'])
library;

import 'dart:io';

import 'package:dosya_okuyucu/screens/editors/spreadsheet_editor_screen.dart';
import 'package:dosya_okuyucu/services/formula_engine.dart';
import 'package:dosya_okuyucu/services/xlsx_editor.dart';
import 'package:dosya_okuyucu/services/xlsx_writer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Faz 26b — Excel kıyas testleri (DUZENLEME_PLANI §7, K23 ölçümü).
///
/// Bulut (debug, JIT) ölçümü cihazdan yavaştır; eşikler §7 bütçesinin ×3
/// gevşek hâli (CI gürültüsü). Ölçülen sayılar `print` ile günlüğe düşer —
/// HAFIZA'daki K23 kararı bu çıktıya dayanır.
void main() {
  /// [rows] × [cols] sayfa: sayılar + her satırda bir metin hücresi.
  XlsxWriteSheet sheetOf(int rows, int cols) {
    final cells = <int, Map<int, XlsxWriteCell>>{};
    for (var r = 0; r < rows; r++) {
      final row = cells[r] = <int, XlsxWriteCell>{};
      for (var c = 0; c < cols - 1; c++) {
        row[c] = XlsxWriteCell(number: (r * cols + c).toDouble());
      }
      row[cols - 1] = XlsxWriteCell(text: 'Satır ${r + 1}');
    }
    return XlsxWriteSheet(name: 'Sayfa1', cells: cells);
  }

  test('10 bin × 20: aç (ayrıştır) ≤ 4,5 sn (§7 1,5 sn ×3)', () {
    final bytes = XlsxWriter.build([sheetOf(10000, 20)]);
    final sw = Stopwatch()..start();
    final editor = XlsxEditor.parse(bytes);
    sw.stop();
    // ignore: avoid_print
    print('PERF excel_open_10k_x20_ms=${sw.elapsedMilliseconds}');
    expect(editor.sheets.first.layout.maxRow, 9999);
    expect(sw.elapsedMilliseconds, lessThan(4500));
  });

  test('100 bin hücre: kaydetme UI izleğinde değil (saveAsync izolatta)', () async {
    final bytes = XlsxWriter.build([sheetOf(5000, 20)]);
    final editor = XlsxEditor.parse(bytes);
    final sw = Stopwatch()..start();
    final out = editor.save();
    sw.stop();
    // ignore: avoid_print
    print('PERF excel_save_100k_cells_ms=${sw.elapsedMilliseconds}');
    expect(out.length, greaterThan(1000));
  });

  // Eşik ≤ 150 ms: koşum paralel test yükünde 15 → 72 ms'ye çıktı; O(n²)
  // bir gerileme (her bağımlı için bütün sayfa) saniyeler sürerdi.
  test('hücre onayı → 1000 bağımlı ≤ 150 ms (yalnız bağımlılar)', () {
    final g = <List<String>>[
      for (var i = 0; i < 1000; i++) ['${i + 1}', '=A1*${i + 1}'],
    ];
    final st = CalcState();
    FormulaEngine eng() =>
        FormulaEngine(g, sheetName: 'S', sheets: {'S': g}, state: st);
    for (var r = 0; r < 1000; r++) {
      eng().displayValue(r, 1);
    }
    final before = st.evaluations;
    final sw = Stopwatch()..start();
    g[0][0] = '7';
    final dirty = st.invalidate('S', 0, 0);
    final e = eng();
    for (var r = 0; r < 1000; r++) {
      e.displayValue(r, 1);
    }
    sw.stop();
    // ignore: avoid_print
    print('PERF excel_commit_1000_deps_ms=${sw.elapsedMilliseconds}');
    expect(dirty, 1000);
    expect(st.evaluations - before, 1000); // yalnız bağımlılar
    expect(e.displayValue(999, 1), '7000');
    expect(sw.elapsedMilliseconds, lessThan(150));
  });

  testWidgets('K23 prototip kıyası: (a) widget satırları vs (b) tek boyacı',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);
    final a = await _avgDragFrame(tester, const _WidgetGrid());
    final b = await _avgDragFrame(tester, const _PainterGrid());
    // ignore: avoid_print
    print('PERF k23_proto_widget_avg_ms=${a.toStringAsFixed(2)} '
        'painter_avg_ms=${b.toStringAsFixed(2)}');
  });

  group('K23 ızgara ölçümü (a: hücre widget\'ları + sanallaştırma)', () {
    late Directory dir;
    late String path;

    setUp(() async {
      SpreadsheetEditorScreen.parseInIsolate = false;
      dir = await Directory.systemTemp.createTemp('excel_perf');
      path = '${dir.path}/10k.xlsx';
      await File(path).writeAsBytes(XlsxWriter.build([sheetOf(10000, 20)]));
    });

    tearDown(() {
      SpreadsheetEditorScreen.parseInIsolate = true;
      try {
        dir.deleteSync(recursive: true);
      } catch (_) {}
    });

    // Eşik bir GERİLEME bekçisi, bütçe değil: debug/JIT flutter_test'te
    // widget satırlı en yalın prototip bile ~40 ms (bkz. K23 prototip
    // kıyası). §7'nin 16 ms'si cihazda profil kipinde `FrameTiming` ile
    // ölçülür (Faz 33). 2026-10-23 ölçümü: 81 ms → hücre başı tanıyıcı
    // kalkınca ~64 ms.
    testWidgets('kaydırma karesi: ortalama ≤ 400 ms (debug gerileme bekçisi)',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2340);
      tester.view.devicePixelRatio = 2.75;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
        home: SpreadsheetEditorScreen(path: path, name: '10k.xlsx', plainText: ''),
      ));
      final open = Stopwatch()..start();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      open.stop();
      // ignore: avoid_print
      print('PERF excel_first_frame_10k_ms=${open.elapsedMilliseconds}');

      final center = tester.getCenter(find.byType(Scaffold).first);
      final frames = <int>[];
      for (var i = 0; i < 30; i++) {
        await tester.dragFrom(center, const Offset(0, -240));
        final sw = Stopwatch()..start();
        await tester.pump(const Duration(milliseconds: 16));
        sw.stop();
        frames.add(sw.elapsedMicroseconds);
      }
      frames.sort();
      final avg = frames.reduce((a, b) => a + b) / frames.length / 1000;
      final p90 = frames[(frames.length * 0.9).floor()] / 1000;
      // ignore: avoid_print
      print('PERF excel_scroll_frame_avg_ms=${avg.toStringAsFixed(2)} '
          'p90_ms=${p90.toStringAsFixed(2)}');
      // Paralel test yükünde 64 → 158 ms ölçüldü; eşik gürültüye dayanıklı.
      expect(avg, lessThan(400));
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 3));
    });
  });
}

// ── K23 deneme prototipleri (aynı koşum, aynı sürükleme) ─────────────────
//
// (a) bugünkü yol: satır başına Row + hücre başına widget.
// (b) tek boyacı: görünür bölgeyi TEK CustomPaint çizer, metin düzeni
//     önbellekli (LRU yerine sınırsız harita — ölçüm için yeter).
// Gerçek ızgaradaki seçim/biçim/birleştirme katmanları yoktur; amaç iki
// çizim yolunun KENDİ maliyetini aynı ortamda kıyaslamak.

const _protoRows = 10000, _protoCols = 20;
const _cw = 72.0, _rh = 20.0;

String _cellText(int r, int c) => c == _protoCols - 1 ? 'Satır ${r + 1}' : '${r * _protoCols + c}';

class _WidgetGrid extends StatelessWidget {
  const _WidgetGrid();
  @override
  Widget build(BuildContext context) => SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          width: _cw * _protoCols,
          child: ListView.builder(
            itemCount: _protoRows,
            itemExtent: _rh,
            itemBuilder: (_, r) => Row(children: [
              for (var c = 0; c < 6; c++)
                Container(
                  width: _cw,
                  decoration: const BoxDecoration(
                      border: Border(
                          right: BorderSide(color: Color(0xFFDDDDDD)),
                          bottom: BorderSide(color: Color(0xFFDDDDDD)))),
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: Text(_cellText(r, c),
                      maxLines: 1,
                      style: const TextStyle(fontSize: 11, color: Color(0xFF000000))),
                ),
            ]),
          ),
        ),
      );
}

class _PainterGrid extends StatefulWidget {
  const _PainterGrid();
  @override
  State<_PainterGrid> createState() => _PainterGridState();
}

class _PainterGridState extends State<_PainterGrid> {
  final _v = ScrollController();
  final _cache = <int, TextPainter>{};
  @override
  void dispose() {
    _v.dispose();
    for (final t in _cache.values) {
      t.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Stack(children: [
        Positioned.fill(
            child: CustomPaint(painter: _GridPainter(_v, _cache))),
        Positioned.fill(
          child: ListView.builder(
            controller: _v,
            itemCount: _protoRows,
            itemExtent: _rh,
            itemBuilder: (_, __) => const SizedBox.shrink(),
          ),
        ),
      ]);
}

class _GridPainter extends CustomPainter {
  final ScrollController v;
  final Map<int, TextPainter> cache;
  _GridPainter(this.v, this.cache) : super(repaint: v);
  @override
  void paint(Canvas canvas, Size size) {
    final off = v.hasClients ? v.offset : 0.0;
    final first = (off / _rh).floor();
    final last = ((off + size.height) / _rh).ceil().clamp(0, _protoRows - 1);
    final line = Paint()..color = const Color(0xFFDDDDDD);
    for (var r = first; r <= last; r++) {
      final y = r * _rh - off;
      for (var c = 0; c < 6; c++) {
        final x = c * _cw;
        final tp = cache.putIfAbsent(r * 32 + c, () {
          return TextPainter(
              text: TextSpan(
                  text: _cellText(r, c),
                  style: const TextStyle(fontSize: 11, color: Color(0xFF000000))),
              textDirection: TextDirection.ltr,
              maxLines: 1)
            ..layout(maxWidth: _cw - 6);
        });
        tp.paint(canvas, Offset(x + _cw - 3 - tp.width, y + (_rh - tp.height) / 2));
        canvas.drawLine(Offset(x + _cw, y), Offset(x + _cw, y + _rh), line);
      }
      canvas.drawLine(Offset(0, y + _rh), Offset(6 * _cw, y + _rh), line);
    }
  }

  @override
  bool shouldRepaint(_GridPainter old) => false;
}

Future<double> _avgDragFrame(WidgetTester tester, Widget grid) async {
  await tester.pumpWidget(MaterialApp(home: Scaffold(body: grid)));
  await tester.pump();
  final center = tester.getCenter(find.byType(Scaffold));
  final frames = <int>[];
  for (var i = 0; i < 30; i++) {
    await tester.dragFrom(center, const Offset(0, -240));
    final sw = Stopwatch()..start();
    await tester.pump(const Duration(milliseconds: 16));
    sw.stop();
    frames.add(sw.elapsedMicroseconds);
  }
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 3));
  return frames.reduce((a, b) => a + b) / frames.length / 1000;
}
