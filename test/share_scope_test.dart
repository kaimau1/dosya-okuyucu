import 'dart:io';

import 'package:dosya_okuyucu/models/fs_entry.dart';
import 'package:dosya_okuyucu/services/fm/remote/ftp_server.dart';
import 'package:dosya_okuyucu/services/fm/remote/ftp_tree.dart';
import 'package:dosya_okuyucu/services/fm/remote/share_scope.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support/temp_dir.dart';

/// **Paylaşım kapsamı** (kullanıcı isteği 2026-08-31): *"ağ paylaşımında hangi
/// klasörlerin paylaşılacağını seçelim, bir de ayrı olarak paylaşılan klasörü
/// olsun … sadece o klasör paylaşılır."*
///
/// Burada ölçülen şey **iki katmanlı**: seçilmemiş kutu (a) listelenmemeli,
/// (b) adı elle yazılarak da AÇILMAMALI. İkincisi olmadan özellik yalnız
/// gizleme olurdu, güvenlik değil — `/Belgeler/fatura.pdf` yazan biri
/// dosyayı yine indirirdi.
void main() {
  late Directory root;

  FsEntry file(String path) => FsEntry(
        path: path,
        name: path.split('/').last,
        isDir: false,
        sizeBytes: 10,
        modifiedMs: 1,
      );

  FtpTree tree({
    ShareScope scope = ShareScope.all,
    List<FsEntry> images = const [],
  }) =>
      FtpTree(
        realRoot: root.path,
        scope: scope,
        collect: (category) async =>
            category == FmCategory.image ? images : const [],
      );

  setUp(() {
    root = Directory.systemTemp.createTempSync('share_scope');
    Directory('${root.path}/DCIM').createSync();
    Directory('${root.path}/Download').createSync();
    File('${root.path}/Download/a.pdf').writeAsStringSync('x');
  });

  tearDown(() => removeTempDir(root));

  group('ShareScope', () {
    test('varsayılan (boxes: null) HER kutuya izin verir', () {
      for (final box in FtpTree.allBoxes) {
        expect(ShareScope.all.allows(box), isTrue, reason: box);
      }
      expect(ShareScope.all.isEmpty, isFalse);
    });

    test('boş küme ile null AYNI ŞEY DEĞİL', () {
      // "Hiç seçmedim" (null → hepsi) ile "hepsini kaldırdım" (boş → hiçbiri)
      // karıştırılırsa kullanıcının bilerek kapattığı paylaşım geri açılır.
      const empty = ShareScope(boxes: {});
      expect(empty.allows(FtpTree.storageFolder), isFalse);
      expect(empty.isEmpty, isTrue);
      expect(ShareScope.all.isEmpty, isFalse);
    });

    test('yalnız-Paylaşılan kipinde SEÇİLİ kutular bile geçmez', () {
      // Kip kutu seçimini EZER: kullanıcı "yalnız Paylaşılan" dediyse eski
      // işaretler geri sızmamalı.
      const scope = ShareScope(
          mode: ShareMode.sharedOnly, boxes: {'Belgeler', 'Telefon'});
      expect(scope.allows('Belgeler'), isFalse);
      expect(scope.allows(FtpTree.storageFolder), isFalse);
      expect(scope.allows(ShareScope.sharedBox), isTrue);
    });

    test('kutu adı ASCII — eski FTP istemcileri Türkçe harfi bozuyor', () {
      expect(ShareScope.sharedBox.codeUnits.every((c) => c < 128), isTrue);
      for (final box in FtpTree.allBoxes) {
        expect(box.codeUnits.every((c) => c < 128), isTrue, reason: box);
      }
    });
  });

  group('kök listesi kapsamı süzüyor', () {
    test('seçilmemiş kutu LİSTELENMEZ', () {
      final names = tree(scope: const ShareScope(boxes: {'Indirilenler'}))
          .rootItems()
          .map((i) => i.name)
          .toList();
      expect(names, ['Indirilenler']);
    });

    test('yalnız-Paylaşılan kipinde kökte TEK kutu var', () {
      final items = tree(scope: ShareScope.sharedOnly).rootItems();
      expect(items.map((i) => i.name), [ShareScope.sharedBox]);
      // Klasör henüz kurulmamış olsa da listeleniyor: boş bir kök
      // kullanıcıya "paylaşım bozuk" dedirtirdi (kurulumu FtpService yapıyor).
      expect(items.single.realPath, FtpTree.sharedFolderPath(root.path));
    });

    test('Paylaşılan kutusu, klasör VARSA seçili kipte de görünür', () async {
      expect(tree().rootItems().map((i) => i.name),
          isNot(contains(ShareScope.sharedBox)));
      expect(await FtpTree.ensureSharedFolder(root.path), isTrue);
      expect(
          tree().rootItems().map((i) => i.name).first, ShareScope.sharedBox);
    });

    test('ensureSharedFolder klasörü kurar ve ikinci kez bozmaz', () async {
      final path = FtpTree.sharedFolderPath(root.path);
      File('${root.path}/x').writeAsStringSync('y');
      expect(await FtpTree.ensureSharedFolder(root.path), isTrue);
      File('$path/gonder.pdf').writeAsStringSync('z');
      expect(await FtpTree.ensureSharedFolder(root.path), isTrue);
      expect(File('$path/gonder.pdf').existsSync(), isTrue);
    });
  });

  group('kapsam dışı yol ÇÖZÜLMEZ (gizlemek yetmez)', () {
    test('kapsam dışı kategori kutusu ve içindeki dosya', () async {
      final t = tree(
        scope: const ShareScope(boxes: {'Indirilenler'}),
        images: [file('${root.path}/DCIM/tatil.jpg')],
      );
      expect((await t.resolve('/Resimler')).kind, isNot(FtpNodeKind.category));
      final node = await t.resolve('/Resimler/tatil.jpg');
      expect(node.realPath, isNull);
      expect(node.relative, isNull);
    });

    test('kapsam dışı gerçek klasör kutusu', () async {
      final t = tree(scope: const ShareScope(boxes: {'Indirilenler'}));
      // "Telefon" kapalıyken telefonun tamamına giden kapı da kapalı.
      expect((await t.resolve('/${FtpTree.storageFolder}/DCIM')).relative,
          isNull);
      expect((await t.resolve('/Kamera')).relative, isNull);
      // Seçili kutu çalışmaya devam ediyor.
      expect((await t.resolve('/Indirilenler/a.pdf')).relative,
          'Download/a.pdf');
    });

    test('yalnız-Paylaşılan kipinde yalnız o klasör çözülüyor', () async {
      await FtpTree.ensureSharedFolder(root.path);
      final t = tree(scope: ShareScope.sharedOnly);
      expect((await t.resolve('/${ShareScope.sharedBox}')).relative,
          ShareScope.sharedFolderName);
      for (final path in ['/Telefon', '/Belgeler', '/Kamera/x.jpg']) {
        expect((await t.resolve(path)).relative, isNull, reason: path);
      }
    });
  });

  group('sunucu kapsamı canlı devrediyor', () {
    test('scope değişince ağaç da önbelleği de tazeleniyor', () async {
      final server = FtpServer(
        rootDirectory: root.path,
        scope: const ShareScope(boxes: {'Indirilenler'}),
        collectCategory: (_) async => [file('${root.path}/DCIM/a.jpg')],
        freshFiles: () async => const [],
      );
      expect(server.tree.rootItems().map((i) => i.name), ['Indirilenler']);
      // Önbelleği doldur: kapsam değişince bayat kalmamalı.
      await server.tree.categoryEntries('Resimler');

      server.scope = const ShareScope(boxes: {'Resimler'});
      expect(server.tree.rootItems().map((i) => i.name), ['Resimler']);
      expect(server.scope.allows('Indirilenler'), isFalse);
      final files = await server.tree.categoryEntries('Resimler');
      expect(files.keys, ['a.jpg']);
      // Kök hapsi aynı yerde kalıyor: kutunun içindeki dosya yine kökün içi.
      final node = await server.tree.resolve('/Resimler/a.jpg');
      expect(server.realPathOf(node), '${root.path}/DCIM/a.jpg');
    });
  });
}
