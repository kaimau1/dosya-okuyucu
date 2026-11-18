@Tags(['perf'])
library;

import 'dart:io';
import 'dart:isolate';

import 'package:dosya_okuyucu/core/edit/edit_session.dart';
import 'package:dosya_okuyucu/screens/editors/spreadsheet_editor_screen.dart';
import 'package:dosya_okuyucu/services/file_service.dart';
import 'package:dosya_okuyucu/services/formula_engine.dart';
import 'package:dosya_okuyucu/services/xlsx/pivot.dart';
import 'package:dosya_okuyucu/services/xlsx_editor.dart';
import 'package:dosya_okuyucu/services/xlsx_writer.dart';
import 'package:dosya_okuyucu/widgets/sheet_cell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/rebuild_probe.dart';

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

  // P12 (B3.3a): dosya yöneticisinden açılış = FileService.load + ekranın
  // izolatta ayrıştırması. Eskiden ilk adım kitabı (metin + tablo) bir kez
  // daha ayrıştırıyordu; aynı koşuda eski / yeni yol yan yana yazılır.
  test('10 bin × 20: açılış yolu kitabı bir kez ayrıştırır', () async {
    final dir = await Directory.systemTemp.createTemp('excel_open');
    addTearDown(() => dir.delete(recursive: true));
    final path = '${dir.path}/10k_x20.xlsx';
    final bytes = XlsxWriter.build([sheetOf(10000, 20)]);
    await File(path).writeAsBytes(bytes);

    var sw = Stopwatch()..start();
    XlsxReader.read(bytes);
    final reader = sw.elapsedMilliseconds;
    sw = Stopwatch()..start();
    await Isolate.run(() => XlsxEditor.parse(File(path).readAsBytesSync()));
    final screen = sw.elapsedMilliseconds;
    sw = Stopwatch()..start();
    final old = await FileService().load(path);
    final oldMs = sw.elapsedMilliseconds;
    sw = Stopwatch()..start();
    final doc = await FileService().load(path, spreadsheetText: false);
    final newMs = sw.elapsedMilliseconds;
    // ignore: avoid_print
    print('PERF excel_reader_10k_x20_ms=$reader '
        'screen_isolate_parse_ms=$screen '
        'preload_old_ms=$oldMs preload_new_ms=$newMs '
        'open_old_ms=${oldMs + screen} open_new_ms=${newMs + screen}');
    expect(old.table, isNotNull); // AI / arama yolu metni hâlâ alır
    expect(doc.table, isNull);
    expect(doc.plainText, isEmpty);
    expect(doc.kind, old.kind);
  }, timeout: const Timeout(Duration(minutes: 2)));

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

  // ── Faz 36 perf: 100 bin satır eşikleri (gerileme bekçisi, debug/JIT) ──

  test('100 bin satır: aç (ayrıştır) ≤ 25 sn', () {
    final bytes = XlsxWriter.build([sheetOf(100000, 3)]);
    final sw = Stopwatch()..start();
    final editor = XlsxEditor.parse(bytes);
    sw.stop();
    // ignore: avoid_print
    print('PERF excel_open_100k_rows_ms=${sw.elapsedMilliseconds}');
    expect(editor.sheets.first.layout.maxRow, 99999);
    expect(sw.elapsedMilliseconds, lessThan(25000));
  }, timeout: const Timeout(Duration(minutes: 3)));

  test('100 bin satır: tek hücre değişince yalnız kirli bağımlılar (≤ 500 ms)', () {
    const n = 100000;
    final g = <List<String>>[
      for (var i = 0; i < n; i++)
        ['${i + 1}', '=A${i + 1}*2', if (i == 0) '=SUM(B1:B$n)'],
    ];
    final st = CalcState();
    FormulaEngine eng() =>
        FormulaEngine(g, sheetName: 'S', sheets: {'S': g}, state: st);
    final e0 = eng();
    expect(e0.displayValue(0, 2), '${n * (n + 1)}');
    final before = st.evaluations;
    final sw = Stopwatch()..start();
    g[49999][0] = '0';
    st.invalidate('S', 49999, 0);
    final e = eng();
    final total = e.displayValue(0, 2);
    sw.stop();
    // ignore: avoid_print
    print('PERF excel_100k_dirty_ms=${sw.elapsedMilliseconds} '
        'evals=${st.evaluations - before}');
    expect(total, '${n * (n + 1) - 100000}');
    // Tam yeniden hesap YOK: B50000 + toplam (+ pay) — 100 bin değil.
    expect(st.evaluations - before, lessThan(10));
    expect(sw.elapsedMilliseconds, lessThan(500));
  }, timeout: const Timeout(Duration(minutes: 3)));

  test('100 bin satır özet tablo ≤ 5 sn (UI izleğinde değil: izolatta koşar)', () {
    final data = <List<String>>[
      ['Bölge', 'Ürün', 'Tutar'],
      for (var i = 0; i < 100000; i++) ['B${i % 12}', 'U${i % 40}', '${i % 97}'],
    ];
    final sw = Stopwatch()..start();
    final r = Pivot.build(
        data, const PivotSpec(rowField: 0, colField: 1, valueField: 2));
    sw.stop();
    // ignore: avoid_print
    print('PERF excel_pivot_100k_ms=${sw.elapsedMilliseconds}');
    expect(r.rowKeys, 12);
    expect(r.colKeys, 40);
    expect(sw.elapsedMilliseconds, lessThan(5000));
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

  // B12 m.3 — yeniden kurulum bütçesi (mandal, YALNIZ DÜŞER). KÖK (koddan):
  // yüzer editörde her harf `onChanged` → ekranın tamamı setState
  // (spreadsheet/entry.dart) → görünür her SheetCell yeniden kurulur. Metne
  // bağlı parçalar (formül çubuğu ✓, işlev önerileri, başvuru renkleri,
  // otomatik tamamlama) ekran durumundan okunduğu için daraltma ölçümsüz
  // yapılmadı → PLAN §1.12 m.3 kalan. Tavanlar ilk CI ölçümüyle sıkılaşır.
  group('B12 m.3: hücre girişi yeniden kurulum bütçesi', () {
    late Directory dir;
    late String path;

    setUp(() async {
      SpreadsheetEditorScreen.parseInIsolate = false;
      EditPrefs.autoSave = false;
      dir = await Directory.systemTemp.createTemp('excel_rebuild');
      path = '${dir.path}/giris.xlsx';
      await File(path).writeAsBytes(XlsxWriter.build([
        XlsxWriteSheet(name: 'Sayfa1', cells: {
          for (var r = 0; r < 200; r++)
            r: {
              for (var c = 0; c < 8; c++) c: XlsxWriteCell(text: 'h${r}_$c'),
            },
        }),
      ]));
    });

    tearDown(() {
      SpreadsheetEditorScreen.parseInIsolate = true;
      EditPrefs.autoSave = true;
      try {
        dir.deleteSync(recursive: true);
      } catch (_) {}
    });

    testWidgets('yüzer editörde bir harf: kurulum sayısı tavanı', (t) async {
      t.view.physicalSize = const Size(1080, 2200);
      t.view.devicePixelRatio = 2.75;
      t.view.viewInsets = const FakeViewPadding(bottom: 800);
      addTearDown(t.view.reset);
      await t.pumpWidget(MaterialApp(
        home: SpreadsheetEditorScreen(
            path: path, name: 'giris.xlsx', plainText: ''),
      ));
      await t.pump();
      await t.pump(const Duration(milliseconds: 100));
      // İlk dokunuş seçer, ikincisi hücrede yüzer editörü açar.
      for (var i = 0; i < 2; i++) {
        await t.tap(find
            .ancestor(of: find.text('h2_1'), matching: find.byType(SheetCell))
            .first);
        await t.pump();
        await t.pump(const Duration(milliseconds: 400));
      }
      final editor = find.byKey(const ValueKey('floating-cell-editor'));
      expect(editor, findsOneWidget);
      final field = find.descendant(of: editor, matching: find.byType(TextField));
      await t.enterText(field, 'K'); // ısınma
      await t.pump();
      // Ağaçtaki TÜM hücreler (önbellek bölgesindeki ekran dışı satırlar
      // dahil): sayaç da tüm öğeleri sayar; `find` varsayılanı ekran dışını
      // atlar. Tavan = hücre başına en çok bir kurulum, yeni hücre doğmaz.
      final cells =
          t.widgetList(find.byType(SheetCell, skipOffstage: false)).length;
      final onscreen = t.widgetList(find.byType(SheetCell)).length;
      final r = await countRebuilds(t, () async {
        await t.enterText(field, 'Ki');
        await t.pump();
      });
      // ignore: avoid_print
      print('PERF excel_key_rebuilds=${r.total} sheet_cells=${r.of(SheetCell)} '
          'tree_cells=$cells visible_cells=$onscreen top=${r.top()}');
      expect(onscreen, greaterThan(10), reason: 'ızgara görünmeli');
      expect(r.of(SheetCell), lessThanOrEqualTo(cells));
      expect(r.total, lessThan(12000));
      await t.pumpWidget(const SizedBox());
      await t.pump(const Duration(seconds: 3));
    });
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
            itemBuilder: (_, _) => const SizedBox.shrink(),
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
