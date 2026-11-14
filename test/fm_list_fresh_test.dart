import 'package:dosya_okuyucu/core/app_state.dart';
import 'package:dosya_okuyucu/models/fm_layout.dart';
import 'package:dosya_okuyucu/models/fs_entry.dart';
import 'package:dosya_okuyucu/widgets/fm/fm_file_list_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

/// Ferrari H6.4: listeye yeni giren satır bir an vurgulanır; ilk yüklemede,
/// büyük listede ve toplu değişimde vurgu yok (her `setState` O(1) kalsın).
void main() {
  FsEntry e(String name) => FsEntry(
    path: '/d/$name',
    name: name,
    isDir: false,
    sizeBytes: 1,
    modifiedMs: 1,
  );
  List<FsEntry> many(int n) => [for (var i = 0; i < n; i++) e('f$i.txt')];

  group('fmFreshPaths', () {
    test('eklenen yol yeni sayılır', () {
      final a = many(3);
      expect(fmFreshPaths(a, [...a, e('yeni.txt')]), {'/d/yeni.txt'});
    });
    test('ilk yükleme, aynı ya da azalan liste → boş', () {
      final a = many(3);
      expect(fmFreshPaths(const [], a), isEmpty);
      expect(fmFreshPaths(a, [...a]), isEmpty);
      expect(fmFreshPaths(a, a.sublist(1)), isEmpty);
    });
    test('2.000 öğeden büyük listede kapalı', () {
      final a = many(fmFreshLimit);
      expect(fmFreshPaths(a, [...a, e('yeni.txt')]), isEmpty);
    });
    test('toplu değişim (20+ yeni) vurgulanmaz', () {
      final a = many(3);
      final b = [for (var i = 0; i < 30; i++) e('b$i.txt')];
      expect(fmFreshPaths(a, [...a, ...b]), isEmpty);
    });
  });

  Widget harness(List<FsEntry> entries) =>
      ChangeNotifierProvider<AppState>.value(
        value: AppState(),
        child: MaterialApp(
          home: Scaffold(
            body: FmFileListView(
              entries: entries,
              layout: FmLayout.list,
              selected: const {},
              onOpen: (_) {},
              onToggle: (_) {},
              subtitle: (_) => '',
            ),
          ),
        ),
      );

  testWidgets('yeni satır vurgulanır, eskiler vurgulanmaz', (tester) async {
    final a = many(3);
    await tester.pumpWidget(harness(a));
    expect(find.byKey(const ValueKey('fm-fresh:/d/f0.txt')), findsNothing);
    await tester.pumpWidget(harness([...a, e('yeni.txt')]));
    expect(find.byKey(const ValueKey('fm-fresh:/d/yeni.txt')), findsOneWidget);
    expect(find.byKey(const ValueKey('fm-fresh:/d/f0.txt')), findsNothing);
    // Vurgu söner, kare istemeye devam etmez (boşta 0 kare).
    await tester.pumpAndSettle();
    expect(tester.binding.hasScheduledFrame, isFalse);
  });
}
