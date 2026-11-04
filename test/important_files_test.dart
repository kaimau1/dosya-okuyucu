import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:dosya_okuyucu/core/app_state.dart';
import 'package:dosya_okuyucu/models/fs_entry.dart';
import 'package:dosya_okuyucu/screens/fm/entry_actions.dart';
import 'package:dosya_okuyucu/screens/fm/media_player_screen.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:dosya_okuyucu/services/fm/file_ops.dart';
import 'package:dosya_okuyucu/services/fm/important_files.dart';
import 'package:dosya_okuyucu/services/fm/office_thumbnail.dart';
import 'package:dosya_okuyucu/widgets/fm/fm_file_image.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

/// 2026-11-04 kullanıcı turu: önemli dosya adı/tanıma/silme ayrımı, önizleme
/// kalitesi (cover çözme ölçüsü), video kapanınca durma kuralı, Office
/// önizleme resmi.
void main() {
  group('ImportantFiles adlandırma', () {
    test('uzantıdan önce _onemli eklenir', () {
      expect(ImportantFiles.markedName('rapor.pdf'), 'rapor_onemli.pdf');
      expect(ImportantFiles.markedName('foto.final.jpg'), 'foto.final_onemli.jpg');
      expect(ImportantFiles.markedName('BENIOKU'), 'BENIOKU_onemli');
      expect(ImportantFiles.markedName('Tez', isDir: true), 'Tez_onemli');
      expect(ImportantFiles.markedName('v1.2', isDir: true), 'v1.2_onemli');
    });

    test('iz iki kez eklenmez', () {
      expect(ImportantFiles.markedName('rapor_onemli.pdf'), 'rapor_onemli.pdf');
      expect(ImportantFiles.markedName('rapor_ONEMLI.pdf'), 'rapor_ONEMLI.pdf');
    });

    test('çakışma eki olan kopya da önemli sayılır', () {
      expect(ImportantFiles.hasMark('rapor_onemli (1).pdf'), isTrue);
      expect(ImportantFiles.hasMark('rapor.pdf'), isFalse);
      expect(ImportantFiles.hasMark('onemli.pdf'), isFalse);
      expect(ImportantFiles.hasMark('rapor_onemli_eski.pdf'), isFalse);
    });

    test('klasörün içi ve kendisi önemli; dışı değil', () {
      const root = '/depo';
      expect(ImportantFiles.isImportant('/depo/Önemli Dosyalar', root: root), isTrue);
      expect(ImportantFiles.isImportant('/depo/Önemli Dosyalar/a/b.txt', root: root),
          isTrue);
      expect(ImportantFiles.isImportant('/depo/DCIM/a.jpg', root: root), isFalse);
      expect(ImportantFiles.isImportant('/depo/DCIM/a_onemli.jpg', root: root), isTrue);
      expect(ImportantFiles.isImportant('', root: root), isFalse);
    });

    test('toplu silmede önemliler ayrılır, sıra korunur', () {
      final (imp, rest) = ImportantFiles.split(
        ['/d/a.jpg', '/d/b_onemli.jpg', '/d/c.pdf', '/d/Önemli Dosyalar/x'],
        (s) => s,
        root: '/d',
      );
      expect(imp, ['/d/b_onemli.jpg', '/d/Önemli Dosyalar/x']);
      expect(rest, ['/d/a.jpg', '/d/c.pdf']);
    });
  });

  group('FileOps.copyAll renameTo', () {
    late Directory tmp;
    setUp(() => tmp = Directory.systemTemp.createTempSync('onemli'));
    tearDown(() => tmp.deleteSync(recursive: true));

    test('kopya _onemli adıyla yazılır, özgün yerinde kalır', () async {
      final src = File(p.join(tmp.path, 'rapor.pdf'))..writeAsStringSync('x');
      final dir = Directory(p.join(tmp.path, 'Klasor'))..createSync();
      File(p.join(dir.path, 'ic.txt')).writeAsStringSync('y');
      final dest = Directory(p.join(tmp.path, ImportantFiles.folderName))
        ..createSync();
      final r = await FileOps.copyAll([src.path, dir.path], dest.path,
          renameTo: ImportantFiles.markedNameFor);
      expect(r.succeeded, 2);
      expect(File(p.join(dest.path, 'rapor_onemli.pdf')).existsSync(), isTrue);
      expect(File(p.join(dest.path, 'Klasor_onemli', 'ic.txt')).existsSync(), isTrue);
      expect(src.existsSync(), isTrue);
      // İkinci kopya ezmez: "(1)" alır ve yine önemli tanınır.
      final again = await FileOps.copyAll([src.path], dest.path,
          renameTo: ImportantFiles.markedNameFor);
      expect(again.succeeded, 1);
      final second = again.transfers.single.dest;
      expect(p.basename(second), isNot('rapor_onemli.pdf'));
      expect(ImportantFiles.hasMark(p.basename(second)), isTrue);
    });
  });

  group('önizleme çözme ölçüsü (cover)', () {
    test('kısa kenar hedefe iner, oran korunur', () {
      final s = fmCoverTargetSize(4000, 3000, 384);
      expect(s.height, 384);
      expect(s.width, 512);
      final portrait = fmCoverTargetSize(3000, 4000, 384);
      expect(portrait.width, 384);
      expect(portrait.height, 512);
    });

    test('küçük kaynak büyütülmez', () {
      final s = fmCoverTargetSize(300, 200, 384);
      expect(s.width, 300);
      expect(s.height, 200);
    });

    test('cover sağlayıcısı ayrı önbellek anahtarı', () {
      expect(const FmFileImage('/a.jpg', cacheWidth: 384, cover: true),
          isNot(const FmFileImage('/a.jpg', cacheWidth: 384)));
    });
  });

  test('video ekrandan çıkınca kapanır, ses sürer', () {
    expect(MediaPlayerScreen.closesOnExit('/v/film.mp4'), isTrue);
    expect(MediaPlayerScreen.closesOnExit('/v/FILM.MKV'), isTrue);
    expect(MediaPlayerScreen.closesOnExit('/m/sarki.mp3'), isFalse);
    expect(MediaPlayerScreen.closesOnExit('/m/kitap.M4A'), isFalse);
    expect(MediaPlayerScreen.closesOnExit(''), isFalse);
  });

  group('OfficeThumbnail', () {
    late Directory tmp;
    setUp(() => tmp = Directory.systemTemp.createTempSync('office_thumb'));
    tearDown(() => tmp.deleteSync(recursive: true));

    String zipWith(String name, Map<String, List<int>> entries) {
      final archive = Archive();
      entries.forEach((k, v) => archive.addFile(ArchiveFile(k, v.length, v)));
      final path = p.join(tmp.path, name);
      File(path).writeAsBytesSync(ZipEncoder().encode(archive));
      return path;
    }

    test('gömülü önizleme resmi okunur', () {
      final path = zipWith('sunum.pptx', {
        '[Content_Types].xml': [60, 63],
        'docProps/thumbnail.jpeg': [0xFF, 0xD8, 1, 2, 3],
      });
      expect(OfficeThumbnail.readEmbedded(path), [0xFF, 0xD8, 1, 2, 3]);
    });

    test('ODF önizlemesi de okunur', () {
      final path = zipWith('tablo.ods', {
        'Thumbnails/thumbnail.png': [0x89, 0x50],
      });
      expect(OfficeThumbnail.readEmbedded(path), [0x89, 0x50]);
    });

    test('önizlemesi olmayan / bozuk dosya null', () {
      final path = zipWith('tablo.xlsx', {'xl/workbook.xml': [60]});
      expect(OfficeThumbnail.readEmbedded(path), isNull);
      final bad = File(p.join(tmp.path, 'bozuk.docx'))..writeAsStringSync('zip değil');
      expect(OfficeThumbnail.readEmbedded(bad.path), isNull);
    });

    test('uzantı kapsamı', () {
      expect(OfficeThumbnail.supports('PPTX'), isTrue);
      expect(OfficeThumbnail.supports('xlsx'), isTrue);
      expect(OfficeThumbnail.supports('pdf'), isFalse);
      expect(OfficeThumbnail.supports('xls'), isFalse);
    });
  });

  group('önemli dosya silme onayı', () {
    FsEntry entry(String name) => FsEntry(
        path: '/depo/x/$name',
        name: name,
        isDir: false,
        sizeBytes: 1,
        modifiedMs: 0);

    Future<bool?> run(WidgetTester tester, List<FsEntry> entries) async {
      bool? result;
      await tester.pumpWidget(ChangeNotifierProvider<AppState>.value(
        value: AppState(),
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                // `confirm: false`: çağıran kendi onayını almış olsa bile.
                onPressed: () async => result =
                    await deleteEntries(context, entries, confirm: false),
                child: const Text('sil'),
              ),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('sil'));
      await tester.pumpAndSettle();
      return result;
    }

    testWidgets('tek önemli dosyada onay sorulur; vazgeçince silinmez',
        (tester) async {
      await run(tester, [entry('rapor_onemli.pdf')]);
      expect(find.text('Önemli dosya silinecek'), findsOneWidget);
      expect(find.text('Yine de sil'), findsOneWidget);
      await tester.tap(find.text('Vazgeç').last);
      await tester.pumpAndSettle();
      expect(find.text('Önemli dosya silinecek'), findsNothing);
    });

    testWidgets('toplu seçimde önemliler ayrı sorulur', (tester) async {
      await run(tester, [entry('a.jpg'), entry('b_onemli.jpg'), entry('c.jpg')]);
      expect(find.text('Önemli dosya silinecek'), findsOneWidget);
      expect(find.text('Önemlileri koru, diğer 2 öğeyi sil'), findsOneWidget);
      expect(find.text('Önemliler dahil 3 öğenin hepsini sil'), findsOneWidget);
    });
  });
}
