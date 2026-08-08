import 'dart:io';

import 'package:dosya_okuyucu/core/l10n/app_strings.dart';
import 'package:dosya_okuyucu/models/remote_connection.dart';
import 'package:dosya_okuyucu/screens/fm/remote/remote_browser_screen.dart';
import 'package:dosya_okuyucu/services/fm/entry_opener.dart';
import 'package:dosya_okuyucu/services/fm/fm_env.dart';
import 'package:dosya_okuyucu/services/fm/remote/remote_fs.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support/temp_dir.dart';

const _delegates = <LocalizationsDelegate<Object?>>[
  AppStrings.delegate,
  GlobalMaterialLocalizations.delegate,
  GlobalWidgetsLocalizations.delegate,
  GlobalCupertinoLocalizations.delegate,
];

const _connection = RemoteConnection(
  id: 'r1',
  name: 'Ev NAS',
  protocol: RemoteProtocol.sftp,
  host: '192.168.1.10',
  port: 22,
);

/// Ağa çıkmayan sahte uzak dosya sistemi.
class FakeFs extends RemoteFs {
  FakeFs(super.connection, {this.failOnConnect, this.failOnList});

  final RemoteError? failOnConnect;
  final RemoteError? failOnList;

  final Map<String, List<RemoteEntry>> tree = {
    '/': const [
      RemoteEntry(name: 'belgeler', path: '/belgeler', isDir: true),
      RemoteEntry(
          name: 'rapor.pdf',
          path: '/rapor.pdf',
          isDir: false,
          sizeBytes: 2048,
          modifiedMs: 1753900000000),
    ],
    '/belgeler': const [
      RemoteEntry(name: 'ic.txt', path: '/belgeler/ic.txt', isDir: false),
    ],
  };

  final deleted = <String>[];
  final renamed = <String>[];
  final created = <String>[];
  final uploaded = <String>[];
  bool closed = false;

  /// İndirilen dosyaya yazılacak içerik; testler bunu değiştirerek
  /// "kullanıcı düzenledi" durumunu taklit ediyor.
  String downloadContent = 'ilk';

  /// `EntryOpener` yerine geçen kanca: dosya açıldıktan sonra ne olsun?
  Future<void> Function(File local)? onOpened;

  @override
  Future<void> connect() async {
    if (failOnConnect != null) throw RemoteException(failOnConnect!);
  }

  @override
  Future<void> close() async => closed = true;

  @override
  Future<List<RemoteEntry>> list(String path) async {
    if (failOnList != null) throw RemoteException(failOnList!);
    return RemoteFs.sorted(tree[path] ?? const []);
  }

  @override
  Future<File> download(RemoteEntry entry, String localPath) async {
    // Senkron G/Ç: `flutter_test`in sahte saat zonunda asenkron dosya işleri
    // ilerlemiyor (bkz. HAFIZA 2026-07-25 §F).
    final file = File(localPath);
    file.parent.createSync(recursive: true);
    file.writeAsStringSync(downloadContent);
    return file;
  }

  @override
  Future<void> upload(File local, String remoteDir, {String? name}) async =>
      uploaded.add('$remoteDir/${name ?? ''}:${local.readAsStringSync()}');

  @override
  Future<void> delete(RemoteEntry entry) async => deleted.add(entry.path);

  @override
  Future<void> makeDirectory(String path) async => created.add(path);

  @override
  Future<void> rename(RemoteEntry entry, String newName) async =>
      renamed.add('${entry.path}→$newName');
}

Future<void> _pump(WidgetTester tester, FakeFs fs,
    {Locale locale = const Locale('tr')}) async {
  await tester.pumpWidget(MaterialApp(
    locale: locale,
    supportedLocales: const [Locale('tr'), Locale('en'), Locale('ar')],
    localizationsDelegates: _delegates,
    home: RemoteBrowserScreen(connection: _connection, fs: fs),
  ));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('kök listelenir, klasör ve dosya görünür', (tester) async {
    await _pump(tester, FakeFs(_connection));
    expect(find.text('belgeler'), findsOneWidget);
    expect(find.text('rapor.pdf'), findsOneWidget);
    // Kökteyken ".." satırı OLMAMALI (kullanıcı köke sıkışmasın).
    expect(find.text('..'), findsNothing);
  });

  testWidgets('klasöre girilir ve ".." ile geri çıkılır', (tester) async {
    await _pump(tester, FakeFs(_connection));
    await tester.tap(find.text('belgeler'));
    await tester.pumpAndSettle();
    expect(find.text('ic.txt'), findsOneWidget);
    expect(find.text('..'), findsOneWidget);

    await tester.tap(find.text('..'));
    await tester.pumpAndSettle();
    expect(find.text('rapor.pdf'), findsOneWidget);
  });

  testWidgets('bağlantı hatası ANLAŞILIR metinle gösterilir', (tester) async {
    // Ham "SocketException: …" kullanıcıya hiçbir şey anlatmıyor; ekran ne
    // yapması gerektiğini söylemeli.
    await _pump(tester,
        FakeFs(_connection, failOnConnect: RemoteError.unreachable));
    expect(find.textContaining('ulaşılamadı'), findsOneWidget);
  });

  testWidgets('parola hatası ayrı metinle gösterilir', (tester) async {
    await _pump(tester, FakeFs(_connection, failOnConnect: RemoteError.auth));
    expect(find.textContaining('parola'), findsOneWidget);
  });

  testWidgets('boş klasör "boş" der, hata DEĞİL', (tester) async {
    final fs = FakeFs(_connection);
    fs.tree['/'] = const [];
    await _pump(tester, fs);
    expect(find.textContaining('boş'), findsOneWidget);
  });

  testWidgets('uzun basış menüsünden silme onaylanınca çağrılır',
      (tester) async {
    final fs = FakeFs(_connection);
    await _pump(tester, fs);
    await tester.longPress(find.text('rapor.pdf'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sil'));
    await tester.pumpAndSettle();
    // Onay penceresi: onaylanmadan silinmemeli.
    expect(fs.deleted, isEmpty);
    await tester.tap(find.text('Tamam'));
    await tester.pumpAndSettle();
    expect(fs.deleted, ['/rapor.pdf']);
  });

  testWidgets('yeni klasör tam yolla oluşturulur', (tester) async {
    final fs = FakeFs(_connection);
    await _pump(tester, fs);
    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Yeni klasör'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'yedek');
    await tester.tap(find.text('Tamam'));
    await tester.pumpAndSettle();
    expect(fs.created, ['/yedek']);
  });

  testWidgets('ekran kapanınca bağlantı KAPATILIR', (tester) async {
    // Kapatılmazsa uzak oturum açık kalır: sunucuda oturum sınırı dolar ve
    // bir sonraki bağlanma reddedilir.
    final fs = FakeFs(_connection);
    await _pump(tester, fs);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    expect(fs.closed, isTrue);
  });

  testWidgets('İngilizce arayüzde ekran İngilizce', (tester) async {
    await _pump(tester, FakeFs(_connection, failOnConnect: RemoteError.auth),
        locale: const Locale('en'));
    expect(find.textContaining('password'), findsOneWidget);
  });

  group('düzenlemeyi sunucuya geri yazma', () {
    late Directory support;

    setUp(() {
      support = Directory.systemTemp.createTempSync('remote_wb');
      FmEnv.appSupportDir = support.path;
    });

    tearDown(() {
      FmEnv.appSupportDir = '';
      openLocalFile = (context, path) => EntryOpener.open(context, path);
      removeTempDir(support);
    });

    testWidgets('dosya DEĞİŞMEDİYSE hiç sorulmaz', (tester) async {
      // Kullanıcı dosyayı yalnız İNCELEDİYSE soru sormak gürültüdür.
      final fs = FakeFs(_connection);
      openLocalFile = (context, path) async {};
      await _pump(tester, fs);
      await tester.tap(find.text('rapor.pdf'));
      await tester.pumpAndSettle();
      expect(find.textContaining('sunucuya yüklensin'), findsNothing);
      expect(fs.uploaded, isEmpty);
    });

    testWidgets('düzenlenmişse SORULUR; "şimdilik yükleme" yüklemez',
        (tester) async {
      final fs = FakeFs(_connection);
      openLocalFile = (context, path) async =>
          File(path).writeAsStringSync('düzenlenmiş içerik');
      await _pump(tester, fs);
      await tester.tap(find.text('rapor.pdf'));
      await tester.pumpAndSettle();

      expect(find.textContaining('sunucuya yüklensin'), findsOneWidget);
      await tester.tap(find.text('Şimdilik yükleme'));
      await tester.pumpAndSettle();
      // Sessizce üzerine yazmak geri alınamaz bir karar olurdu.
      expect(fs.uploaded, isEmpty);
    });

    testWidgets('"Yükle" doğru yola, ÖZGÜN adla ve YENİ içerikle yükler',
        (tester) async {
      final fs = FakeFs(_connection);
      openLocalFile = (context, path) async =>
          File(path).writeAsStringSync('düzenlenmiş içerik');
      await _pump(tester, fs);
      await tester.tap(find.text('rapor.pdf'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Yükle'));
      await tester.pumpAndSettle();

      // Hedef: dosyanın KENDİ klasörü (kök) ve KENDİ adı — yeni bir dosya
      // oluşturmak değil, var olanın üzerine yazmak.
      expect(fs.uploaded, ['//rapor.pdf:düzenlenmiş içerik']);
    });
  });
}
