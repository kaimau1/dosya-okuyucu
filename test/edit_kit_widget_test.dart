import 'dart:io';

import 'package:dosya_okuyucu/core/edit/draft_journal.dart';
import 'package:dosya_okuyucu/core/edit/edit_session.dart';
import 'package:dosya_okuyucu/core/edit/editor_chrome.dart';
import 'package:dosya_okuyucu/screens/editors/spreadsheet_editor_screen.dart';
import 'package:dosya_okuyucu/services/xlsx_editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/temp_dir.dart';
import 'support/xlsx_fixture.dart';

/// Faz 20 — ortak düzenleme çekirdeğinin ekran davranışı: tek tip çıkış
/// sorusu, taslak kurtarma şeridi, klavye ↔ Aa paneli geçişinde belge sabit.
void main() {
  late Directory dir;
  late String path;

  setUp(() async {
    SpreadsheetEditorScreen.parseInIsolate = false;
    EditPrefs.autoSave = false;
    dir = await Directory.systemTemp.createTemp('edit_kit');
    path = '${dir.path}/tablo.xlsx';
    await File(path).writeAsBytes(xlsxFrom({'A1': 'özgün'}));
    DraftJournal.instance = DraftJournal(Directory('${dir.path}/drafts'));
  });

  tearDown(() {
    SpreadsheetEditorScreen.parseInIsolate = true;
    EditPrefs.autoSave = true;
    DraftJournal.instance = null;
    removeTempDir(dir);
  });

  testWidgets('kirli belgede geri tuşu ortak soruyu sorar; Kaydetme çıkar',
      (tester) async {
    final session = EditSession(
      sourcePath: path,
      editor: 'test',
      observeLifecycle: false,
      save: () async {},
    );
    addTearDown(session.dispose);
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => EditExitGuard(
                session: session,
                child: const Scaffold(body: Text('editör')),
              ),
            )),
            child: const Text('aç'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('aç'));
    await tester.pumpAndSettle();
    session.changed();
    await tester.pump();

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('unsaved-dialog')), findsOneWidget);
    expect(find.text('editör'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('unsaved-discard')));
    await tester.pumpAndSettle();
    expect(find.text('editör'), findsNothing, reason: 'Kaydetme → çıkılır');
    expect(session.isDirty, isFalse);
  });

  testWidgets('temiz belgede soru sorulmaz', (tester) async {
    final session = EditSession(
      sourcePath: path,
      editor: 'test',
      observeLifecycle: false,
      save: () async {},
    );
    addTearDown(session.dispose);
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => EditExitGuard(
                session: session,
                child: const Scaffold(body: Text('editör')),
              ),
            )),
            child: const Text('aç'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('aç'));
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('unsaved-dialog')), findsNothing);
    expect(find.text('editör'), findsNothing);
  });

  testWidgets(
      'taslak kurtarma: ekran yeniden açılınca şerit çıkar, Geri yükle içeriği getirir',
      (tester) async {
    // Önceki oturum: kullanıcı A1'i değiştirdi, uygulama öldü — geriye
    // yalnız taslak kaldı (oturum nesnesi atıldı).
    final edited = XlsxEditor.parse(File(path).readAsBytesSync());
    edited.setCell(edited.sheets.first.name, 0, 0, 'TASLAKTAKİ');
    final journal = DraftJournal(Directory('${dir.path}/drafts'));
    await tester.runAsync(
        () => journal.write(path, edited.save(), editor: 'excel'));
    DraftJournal.instance = journal;

    await tester.pumpWidget(MaterialApp(
      home: SpreadsheetEditorScreen(
          path: path, name: 'tablo.xlsx', plainText: ''),
    ));
    await tester.pump();
    // Taslak araması gerçek disk G/Ç'si: sahte saat dışında bitir.
    for (var i = 0; i < 5; i++) {
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pump();
    }
    expect(find.byKey(const ValueKey('draft-banner')), findsOneWidget);
    expect(find.text('özgün'), findsWidgets);

    await tester.tap(find.byKey(const ValueKey('draft-restore')));
    for (var i = 0; i < 5; i++) {
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pump();
    }
    expect(find.byKey(const ValueKey('draft-banner')), findsNothing);
    expect(find.text('TASLAKTAKİ'), findsWidgets);
    expect(find.text('Kaydedilmedi'), findsOneWidget,
        reason: 'geri yüklenen içerik henüz dosyada değil');
  });

  testWidgets('geniş ekranda Aa paneli sağ bölmede açılır, klavye kalır',
      (tester) async {
    final panel = FormatPanelController();
    final docKey = GlobalKey();
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: EditorChrome(
          keyboardInsetOverride: 300,
          panel: panel,
          body: Container(key: docKey, color: Colors.white),
          accessory: KeyboardAccessoryBar(
            items: const [AccessoryItem(icon: Icons.format_bold, tooltip: 'K')],
            onFormat: panel.open,
          ),
          panelTabs: [
            FormatPanelTab(label: 'Yazı', builder: (_) => const Text('panel')),
          ],
        ),
      ),
    ));
    await tester.tap(find.byKey(const ValueKey('accessory-format')));
    await tester.pump();
    expect(panel.side, isTrue);
    final panelRect = tester.getRect(find.byKey(const ValueKey('format-panel')));
    final docRect = tester.getRect(find.byKey(docKey));
    expect(panelRect.left, greaterThanOrEqualTo(docRect.right));
    expect(panelRect.width, 320);
    // Klavye açıkken klavye üstü çubuk da durur (yazarken panel açık).
    expect(find.byKey(const ValueKey('keyboard-accessory')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('format-panel-close')));
    await tester.pump();
    expect(find.byKey(const ValueKey('format-panel')), findsNothing);
  });

  testWidgets('Aa ↔ klavye geçişinde belge alanı yerinde kalır',
      (tester) async {
    final panel = FormatPanelController();
    final docKey = GlobalKey();
    Widget app(double keyboard) => MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(
              size: const Size(400, 800),
              viewInsets: EdgeInsets.only(bottom: keyboard),
            ),
            child: Scaffold(
              body: EditorChrome(
                keyboardInsetOverride: keyboard,
                panel: panel,
                body: Container(key: docKey, color: Colors.white),
                accessory: KeyboardAccessoryBar(
                  items: const [AccessoryItem(icon: Icons.format_bold, tooltip: 'K')],
                  onFormat: panel.open,
                ),
                panelTabs: [
                  FormatPanelTab(label: 'Yazı', builder: (_) => const Text('panel')),
                ],
              ),
            ),
          ),
        );

    await tester.pumpWidget(app(300)); // klavye açık
    final withKeyboard = tester.getRect(find.byKey(docKey));
    expect(find.byKey(const ValueKey('keyboard-accessory')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('accessory-format')));
    await tester.pumpWidget(app(0)); // klavye indi, panel açıldı
    await tester.pump();
    expect(find.byKey(const ValueKey('format-panel')), findsOneWidget);
    final withPanel = tester.getRect(find.byKey(docKey));
    expect(withPanel, withKeyboard, reason: 'belge zıplamamalı');

    await tester.tap(find.byKey(const ValueKey('format-panel-keyboard')));
    await tester.pumpWidget(app(300));
    await tester.pump();
    expect(find.byKey(const ValueKey('format-panel')), findsNothing);
    expect(tester.getRect(find.byKey(docKey)), withKeyboard);
  });
}
