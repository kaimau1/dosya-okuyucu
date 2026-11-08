import 'package:dosya_okuyucu/core/app_state.dart';
import 'package:dosya_okuyucu/models/fm_layout.dart';
import 'package:dosya_okuyucu/models/fs_entry.dart';
import 'package:dosya_okuyucu/widgets/fm/fm_entry_tiles.dart';
import 'package:dosya_okuyucu/widgets/fm/fm_inline_play.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

/// Satır içi oynatma (2026-11-08): yalnız ses satırında, seçim kapalıyken.
void main() {
  FsEntry file(String name) => FsEntry(
      path: '/depo/$name',
      name: name,
      isDir: false,
      sizeBytes: 1000,
      modifiedMs: 0);

  Widget harness(FsEntry entry, {bool selecting = false}) =>
      ChangeNotifierProvider<AppState>.value(
        value: AppState(),
        child: MaterialApp(
          home: Scaffold(
            body: ListView(children: [
              FmEntryRow(
                entry: entry,
                selected: false,
                selecting: selecting,
                subtitle: '1 KB',
                layout: FmLayout.list,
                onTap: () {},
                onCheck: () {},
                audioQueue: () => [entry.path],
              ),
            ]),
          ),
        ),
      );

  testWidgets('ses satırında oynat düğmesi var', (tester) async {
    await tester.pumpWidget(harness(file('kayit.opus')));
    expect(find.byType(FmInlinePlay), findsOneWidget);
  });

  testWidgets('ses dışı dosyada yok', (tester) async {
    await tester.pumpWidget(harness(file('rapor.pdf')));
    expect(find.byType(FmInlinePlay), findsNothing);
  });

  testWidgets('seçim kipinde yok (onay rozeti öncelikli)', (tester) async {
    await tester.pumpWidget(harness(file('kayit.mp3'), selecting: true));
    expect(find.byType(FmInlinePlay), findsNothing);
  });
}
