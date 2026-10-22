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
}
