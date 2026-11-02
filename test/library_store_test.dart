import 'dart:io';

import 'package:archive/archive.dart';
import 'package:dosya_okuyucu/core/l10n/app_strings.dart';
import 'package:dosya_okuyucu/screens/fm/library_screen.dart';
import 'package:dosya_okuyucu/services/fm/fm_env.dart';
import 'package:dosya_okuyucu/services/fm/reading_positions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:dosya_okuyucu/services/fm/library_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'support/temp_dir.dart';

void main() {
  late Directory dir;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('library_');
    FmEnv.appSupportDir = dir.path;
    LibraryStore.debugReset();
  });

  tearDown(() {
    FmEnv.appSupportDir = '';
    removeTempDir(dir);
  });

  test('yalnız kitaplar eklenir, tekrar eklenmez, kalıcıdır', () async {
    final n = await LibraryStore.add(
        ['/k/a.pdf', '/k/b.EPUB', '/k/not.docx', '/k/a.pdf']);
    expect(n, 2);
    expect(LibraryStore.paths, ['/k/b.EPUB', '/k/a.pdf']); // en yeni önce

    LibraryStore.debugReset();
    await LibraryStore.ensureLoaded();
    expect(LibraryStore.count, 2);

    await LibraryStore.remove(['/k/a.pdf']);
    LibraryStore.debugReset();
    await LibraryStore.ensureLoaded();
    expect(LibraryStore.paths, ['/k/b.EPUB']);
  });

  test('EPUB kapağı OPF cover-image öğesinden okunur', () {
    final img = [0xFF, 0xD8, 0xFF, 1, 2, 3];
    final arc = Archive()
      ..addFile(ArchiveFile.string('META-INF/container.xml',
          '<rootfile full-path="OEBPS/content.opf"/>'))
      ..addFile(ArchiveFile.string('OEBPS/content.opf',
          '<manifest><item id="c" href="img/kapak.jpg" properties="cover-image"/></manifest>'))
      ..addFile(ArchiveFile('OEBPS/img/kapak.jpg', img.length, img));
    final file = File(p.join(dir.path, 'k.epub'))
      ..writeAsBytesSync(ZipEncoder().encode(arc));
    expect(LibraryStore.epubCoverBytes(file.path), img);
  });

  testWidgets('kitaplık: boşken çağrı, kitap eklenince rafta görünür',
      (tester) async {
    ReadingPositions.debugReset();
    Widget app() => const MaterialApp(
          locale: Locale('tr'),
          supportedLocales: [Locale('tr'), Locale('en'), Locale('ar')],
          localizationsDelegates: [
            AppStrings.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: LibraryScreen(),
        );
    await tester.pumpWidget(app());
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pump();
    expect(find.text('Kitaplığın boş'), findsOneWidget);

    await tester.runAsync(() => LibraryStore.add(['/yok/Suç ve Ceza.fb2']));
    await tester.pump();
    expect(find.text('1 kitap'), findsOneWidget);
    expect(find.text('Suç ve Ceza'), findsWidgets); // çizilmiş kapak + başlık
  });
}
