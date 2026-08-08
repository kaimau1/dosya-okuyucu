import 'dart:io';

import 'package:dosya_okuyucu/core/app_state.dart';
import 'package:dosya_okuyucu/models/fs_entry.dart';
import 'package:dosya_okuyucu/services/fm/file_ops.dart';
import 'package:dosya_okuyucu/widgets/fm/fm_selection_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';
import 'support/temp_dir.dart';

/// **Tek adımlı taşı/kopyala** akışının kanıtları (kullanıcı isteği
/// 2026-07-29: "taşıma kopyalama şu an çok zor").
///
/// Buradaki asıl kritik parça `transfers` + `undoMove`: "Geri al" düğmesi
/// dosyanın GERÇEK varış yolunu bilmezse (ad çakışınca `rapor (1).pdf` olur)
/// yanlış dosyayı geri taşır ya da hiçbir şey bulamaz.
void main() {
  group('taşıma sonucu ve geri alma', () {
    late Directory tmp;

    setUp(() {
      tmp = Directory.systemTemp.createTempSync('fm_move_test');
    });

    tearDown(() {
      if (tmp.existsSync()) removeTempDir(tmp);
    });

    File touch(String relative, [String content = 'veri']) {
      final f = File(p.join(tmp.path, relative));
      f.parent.createSync(recursive: true);
      f.writeAsStringSync(content);
      return f;
    }

    test('taşıma gerçek varış yollarını bildirir', () async {
      final a = touch('kaynak/a.pdf');
      final b = touch('kaynak/b.pdf');
      final dest = Directory(p.join(tmp.path, 'hedef'))..createSync();

      final result = await FileOps.moveAll([a.path, b.path], dest.path);

      expect(result.succeeded, 2);
      expect(result.transfers.length, 2);
      for (final t in result.transfers) {
        expect(File(t.dest).existsSync(), isTrue);
        expect(p.dirname(t.dest), dest.path);
      }
      expect(a.existsSync(), isFalse);
    });

    test('ad çakışınca bildirilen yol YENİ addır (geri alma buna dayanır)',
        () async {
      final src = touch('kaynak/rapor.pdf', 'yeni');
      touch('hedef/rapor.pdf', 'eski');

      final result =
          await FileOps.moveAll([src.path], p.join(tmp.path, 'hedef'));

      expect(result.transfers.length, 1);
      expect(p.basename(result.transfers.first.dest), 'rapor (1).pdf');
      // Hedefteki eski dosya EZİLMEDİ.
      expect(
          File(p.join(tmp.path, 'hedef', 'rapor.pdf')).readAsStringSync(),
          'eski');
    });

    test('geri alma dosyayı eski klasörüne döndürür', () async {
      final src = touch('kaynak/foto.jpg');
      final dest = Directory(p.join(tmp.path, 'hedef'))..createSync();

      final moved = await FileOps.moveAll([src.path], dest.path);
      expect(src.existsSync(), isFalse);

      final undo = await FileOps.undoMove(moved.transfers);

      expect(undo.hasError, isFalse);
      expect(src.existsSync(), isTrue);
      expect(File(moved.transfers.first.dest).existsSync(), isFalse);
    });

    test('klasör taşıma da geri alınabilir (içeriğiyle birlikte)', () async {
      touch('kaynak/albüm/1.jpg');
      touch('kaynak/albüm/2.jpg');
      final album = p.join(tmp.path, 'kaynak', 'albüm');
      final dest = Directory(p.join(tmp.path, 'hedef'))..createSync();

      final moved = await FileOps.moveAll([album], dest.path);
      expect(Directory(album).existsSync(), isFalse);
      expect(
          File(p.join(dest.path, 'albüm', '1.jpg')).existsSync(), isTrue);

      final undo = await FileOps.undoMove(moved.transfers);
      expect(undo.hasError, isFalse);
      expect(File(p.join(album, '1.jpg')).existsSync(), isTrue);
      expect(File(p.join(album, '2.jpg')).existsSync(), isTrue);
    });

    test('kopyalama kaynağı yerinde bırakır ve yollarını bildirir', () async {
      final src = touch('kaynak/not.txt');
      final dest = Directory(p.join(tmp.path, 'hedef'))..createSync();

      final result = await FileOps.copyAll([src.path], dest.path);

      expect(src.existsSync(), isTrue);
      expect(result.transfers.length, 1);
      expect(File(result.transfers.first.dest).existsSync(), isTrue);
    });
  });

  group('seçim eylem çubuğu', () {
    FsEntry entry(String name, {bool dir = false}) => FsEntry(
          path: '/depo/$name',
          name: name,
          isDir: dir,
          sizeBytes: 10,
          modifiedMs: 0,
        );

    Widget harness(List<FsEntry> selected) =>
        ChangeNotifierProvider<AppState>.value(
          value: AppState(),
          child: MaterialApp(
            home: Scaffold(
              bottomNavigationBar: FmSelectionBar(
                selected: selected,
                onChanged: () async {},
              ),
            ),
          ),
        );

    testWidgets('taşı ve kopyala en görünür yerde (uzun basış → alt çubuk)',
        (tester) async {
      await tester.pumpWidget(harness([entry('a.jpg'), entry('b.jpg')]));
      await tester.pump();

      expect(find.text('Taşı'), findsOneWidget);
      expect(find.text('Kopyala'), findsOneWidget);
      expect(find.text('Paylaş'), findsOneWidget);
      expect(find.text('Sil'), findsOneWidget);
      expect(find.text('Daha fazla'), findsOneWidget);
    });

    testWidgets('klasör seçiliyken Paylaş gösterilmez (Android paylaşamaz)',
        (tester) async {
      await tester.pumpWidget(harness([entry('Belgeler', dir: true)]));
      await tester.pump();

      expect(find.text('Taşı'), findsOneWidget);
      expect(find.text('Paylaş'), findsNothing);
    });

    testWidgets('seçim boşken çubuk çizilmez', (tester) async {
      await tester.pumpWidget(harness(const []));
      await tester.pump();
      expect(find.text('Taşı'), findsNothing);
    });
  });
}
