import 'package:dosya_okuyucu/core/app_state.dart';
import 'package:dosya_okuyucu/models/fs_entry.dart';
import 'package:dosya_okuyucu/widgets/fm/recent_strip.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  Future<Widget> app(WidgetTester tester, Widget child) async {
    SharedPreferences.setMockInitialValues({});
    final state = AppState();
    await tester.runAsync(state.init);
    return ChangeNotifierProvider<AppState>.value(
        value: state, child: MaterialApp(home: Scaffold(body: child)));
  }

  FsEntry f(String n) => FsEntry(
      path: '/x/$n', name: n, isDir: false, sizeBytes: 1, modifiedMs: 0);

  testWidgets('şerit en çok 10 öğe gösterir; dokunuş açar, "Tümü" listeye gider',
      (tester) async {
    FsEntry? opened;
    var all = 0;
    await tester.pumpWidget(await app(
        tester,
        RecentStrip(
          entriesForTest: [for (var i = 0; i < 14; i++) f('belge$i.pdf')],
          onOpen: (e) => opened = e,
          onAll: () => all++,
        )));
    await tester.pump();
    expect(find.text('belge0.pdf'), findsOneWidget);
    await tester.tap(find.text('belge0.pdf'));
    expect(opened?.name, 'belge0.pdf');
    await tester.tap(find.byKey(const ValueKey('recent-strip-all')));
    expect(all, 1);
    // Yatay liste 10'da kesilir.
    await tester.drag(find.byType(ListView), const Offset(-4000, 0));
    await tester.pumpAndSettle();
    expect(find.text('belge9.pdf'), findsOneWidget);
    expect(find.text('belge10.pdf'), findsNothing);
  });

  testWidgets('kayıt yoksa şerit hiç çizilmez', (tester) async {
    await tester.pumpWidget(await app(tester,
        RecentStrip(entriesForTest: const [], onOpen: (_) {}, onAll: () {})));
    await tester.pump();
    expect(find.byType(ListView), findsNothing);
  });

  group('mergeStripItems (U2 tek şerit)', () {
    const day = Duration.millisecondsPerDay;
    const now = 100 * day;
    FsEntry g(String n, int mtime) => FsEntry(
        path: '/x/$n', name: n, isDir: false, sizeBytes: 1, modifiedMs: mtime);
    List<String> names(List<StripItem> l) => [
          for (final i in l)
            '${i.entry.name}:${i.mark == StripMark.fresh ? 'Y' : 'G'}'
        ];

    test('24 saatte gelen açılmamış yeni öne; gerisi zamana göre karışık', () {
      final opened = {'/x/a': now - 1000, '/x/b': now - 3 * day};
      final out = mergeStripItems(
        opened: [g('a', 0), g('b', 0)],
        fresh: [g('y1', now - 5000), g('eski', now - 2 * day)],
        openedAt: (p) => opened[p],
        nowMs: now,
      );
      expect(names(out), ['y1:Y', 'a:G', 'eski:Y', 'b:G']);
    });

    test('aynı dosya bir kez; açıldıktan sonra değişmemiş yeni = son açılan',
        () {
      final opened = {'/x/a': now - 100};
      final out = mergeStripItems(
        opened: [g('a', now - 500)],
        fresh: [g('a', now - 500), g('y', now - 50)],
        openedAt: (p) => opened[p],
        nowMs: now,
      );
      expect(names(out), ['y:Y', 'a:G']);
    });

    test('açıldıktan sonra yeniden değişen dosya yine "Yeni"', () {
      final out = mergeStripItems(
        opened: [g('a', now - 10)],
        fresh: [g('a', now - 10)],
        openedAt: (_) => now - 1000,
        nowMs: now,
      );
      expect(names(out), ['a:Y']);
    });

    test('yeniler şeridi doldursa da son açılanlar aynı anda görünür', () {
      final out = mergeStripItems(
        opened: [for (var i = 0; i < 5; i++) g('g$i', 0)],
        fresh: [for (var i = 0; i < 20; i++) g('y$i', now - i)],
        openedAt: (p) => p.contains('/g') ? now - 1 : null,
        nowMs: now,
      );
      expect(out.length, 10);
      expect(out.where((i) => i.mark == StripMark.opened).length, 3);
      expect(out.first.entry.name, 'y0');
    });
  });
}
