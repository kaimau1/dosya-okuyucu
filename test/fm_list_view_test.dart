import 'dart:io';

import 'package:dosya_okuyucu/core/app_state.dart';
import 'package:dosya_okuyucu/core/l10n/app_strings.dart';
import 'package:dosya_okuyucu/models/fm_list_groups.dart';
import 'package:dosya_okuyucu/models/fs_entry.dart';
import 'package:dosya_okuyucu/screens/fm/browser_screen.dart';
import 'package:dosya_okuyucu/widgets/fm/fm_entry_tiles.dart';
import 'package:dosya_okuyucu/widgets/fm/fm_file_list_view.dart';
import 'package:dosya_okuyucu/widgets/fm/fm_path_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/temp_dir.dart';

/// Faz 6 — ortak liste bileşeni, yol hapları, gruplama, araç şeridi.
const _delegates = <LocalizationsDelegate<Object?>>[
  AppStrings.delegate,
  GlobalMaterialLocalizations.delegate,
  GlobalWidgetsLocalizations.delegate,
  GlobalCupertinoLocalizations.delegate,
];

FsEntry _e(String name, {bool dir = false, int ms = 0, int size = 10}) =>
    FsEntry(
      path: '/x/$name',
      name: name,
      isDir: dir,
      sizeBytes: size,
      modifiedMs: ms,
    );

class _Counter extends NavigatorObserver {
  int pushes = 0;
  int pops = 0;
  final stack = <Route<dynamic>>[];
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    pushes++;
    stack.add(route);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    pops++;
    stack.remove(route);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    stack.remove(oldRoute);
    if (newRoute != null) stack.add(newRoute);
  }
}

void main() {
  group('tarih grupları', () {
    final now = DateTime(2026, 10, 21, 15);
    int at(DateTime t) => t.millisecondsSinceEpoch;

    test('gün sınırı yerel gün başlangıcı', () {
      expect(dateGroupOf(at(DateTime(2026, 10, 21, 0, 1)), now),
          FmDateGroup.today);
      expect(dateGroupOf(at(DateTime(2026, 10, 20, 23, 59)), now),
          FmDateGroup.week);
      expect(dateGroupOf(at(DateTime(2026, 10, 15)), now), FmDateGroup.week);
      expect(dateGroupOf(at(DateTime(2026, 10, 14, 23)), now),
          FmDateGroup.month);
      expect(dateGroupOf(at(DateTime(2026, 9, 22)), now), FmDateGroup.month);
      expect(dateGroupOf(at(DateTime(2026, 9, 21, 23)), now),
          FmDateGroup.older);
    });

    test('tarihe göre sıralı listede başlıklar, indeksler sıralı yerde', () {
      final list = [
        _e('a', ms: at(DateTime(2026, 10, 21, 9))),
        _e('b', ms: at(DateTime(2026, 10, 18))),
        _e('c', ms: at(DateTime(2025, 1, 1))),
      ];
      final items = groupEntries(list, FmSort.date, now: now);
      expect(items.whereType<FmHeaderItem>().map((h) => h.labelKey),
          ['grp.today', 'grp.week', 'grp.older']);
      expect(items.whereType<FmEntryItem>().map((e) => e.index), [0, 1, 2]);
    });

    test('tek grup çıkıyorsa başlık yok; ada göre hiç yok', () {
      final list = [_e('a', ms: 1), _e('b', ms: 2)];
      expect(groupEntries(list, FmSort.date, now: now)
          .whereType<FmHeaderItem>(), isEmpty);
      expect(groupEntries(list, FmSort.name, now: now)
          .whereType<FmHeaderItem>(), isEmpty);
    });

    test('türe göre başlıklar', () {
      final list = [_e('k', dir: true), _e('a.jpg'), _e('b.pdf')];
      final heads = groupEntries(list, FmSort.type, now: now)
          .whereType<FmHeaderItem>()
          .map((h) => h.labelKey)
          .toList();
      expect(heads, ['enum.cat_folder', 'enum.cat_image', 'enum.cat_document']);
    });

    test('tür sayımı ve süzgeç', () {
      final list = [_e('k', dir: true), _e('a.jpg'), _e('b.jpg')];
      expect(categoryCounts(list)[FmCategory.image], 2);
      expect(list.where((e) => matchesCategory(e, FmCategory.folder)).length, 1);
      expect(list.where((e) => matchesCategory(e, null)).length, 3);
    });
  });

  test('yol parçaları birim kökünden başlar', () {
    final segs = fmPathSegments('/storage/emulated/0/Download/PDF',
        volumes: [(path: '/storage/emulated/0', label: 'Ana bellek')],
        rootLabel: 'Kök');
    expect(segs.map((s) => s.label), ['Ana bellek', 'Download', 'PDF']);
    expect(p.normalize(segs.last.path),
        p.normalize('/storage/emulated/0/Download/PDF'));
    final bare = fmPathSegments('/a/b', volumes: const [], rootLabel: 'Kök');
    expect(bare.map((s) => s.label), ['Kök', 'a', 'b']);
  });

  group('gezgin', () {
    late Directory dir;
    setUp(() {
      dir = Directory.systemTemp.createTempSync('fm_list_view');
      Directory('${dir.path}/Alfa/Beta').createSync(recursive: true);
      for (var i = 0; i < 12; i++) {
        File('${dir.path}/Alfa/dosya_$i.txt').writeAsStringSync('x' * i);
      }
    });
    tearDown(() => removeTempDir(dir));

    Future<(AppState, _Counter, GlobalKey<NavigatorState>)> pump(
        WidgetTester tester,
        {Size size = const Size(360, 720),
        double textScale = 1}) async {
      SharedPreferences.setMockInitialValues({});
      final state = AppState();
      await tester.runAsync(state.init);
      final counter = _Counter();
      final nav = GlobalKey<NavigatorState>();
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(ChangeNotifierProvider<AppState>.value(
        value: state,
        child: MaterialApp(
          navigatorKey: nav,
          navigatorObservers: [counter],
          locale: const Locale('tr'),
          supportedLocales: const [Locale('tr'), Locale('en'), Locale('ar')],
          localizationsDelegates: _delegates,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          ),
          home: const Scaffold(body: Text('ana')),
        ),
      ));
      return (state, counter, nav);
    }

    Future<void> settle(WidgetTester tester) async {
      for (var i = 0; i < 6; i++) {
        await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 30)));
        await tester.pump(const Duration(milliseconds: 50));
      }
      await tester.pump(const Duration(milliseconds: 400));
    }

    testWidgets('yol hapı yığını BÜYÜTMEZ: üst klasöre geri gider',
        (tester) async {
      final (_, counter, nav) = await pump(tester);
      for (final sub in ['', 'Alfa', p.join('Alfa', 'Beta')]) {
        nav.currentState!.push(browserRoute(BrowserScreen(path: p.join(dir.path, sub))));
        await settle(tester);
      }
      final before = counter.stack.length;
      expect(before, 4);
      // Beta'dayken "Alfa" hapına dokun.
      await tester.tap(find.descendant(
          of: find.byType(FmPathBar), matching: find.text('Alfa')).last);
      await settle(tester);
      expect(counter.stack.length, before - 1,
          reason: 'Alfa yığında vardı → oraya GERİ dönülmeli, yeni sayfa yok');
      expect(
          (counter.stack.last.settings.arguments as String).endsWith('${p.separator}Alfa'),
          isTrue);
    });

    testWidgets('derin klasör doğrudan açıldıysa hap YERİNE açar',
        (tester) async {
      final (_, counter, nav) = await pump(tester);
      nav.currentState!
          .push(browserRoute(BrowserScreen(path: p.join(dir.path, 'Alfa', 'Beta'))));
      await settle(tester);
      expect(counter.stack.length, 2);
      await tester.tap(find.descendant(
          of: find.byType(FmPathBar), matching: find.text('Alfa')).last);
      await settle(tester);
      expect(counter.stack.length, 2, reason: 'yığın büyümemeli');
      expect(
          (counter.stack.last.settings.arguments as String).endsWith('${p.separator}Alfa'),
          isTrue);
    });

    testWidgets('focusPath: uzak dosyaya kaydırır, vurgular, vurgu söner',
        (tester) async {
      final many = Directory(p.join(dir.path, 'Cok'))..createSync();
      for (var i = 0; i < 80; i++) {
        File(p.join(many.path, 'f_${i.toString().padLeft(2, '0')}.pdf'))
            .writeAsStringSync('x');
      }
      final (_, _, nav) = await pump(tester);
      nav.currentState!.push(browserRoute(BrowserScreen(
          path: many.path, focusPath: p.join(many.path, 'f_75.pdf'))));
      await settle(tester);
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));
      final y = tester.getRect(find.text('f_75.pdf')).center.dy;
      expect(y, inInclusiveRange(150, 450),
          reason: '80 dosyalık listede 75. dosya ekranın üst-ortasına gelmeli');
      final ring = find.ancestor(
          of: find.text('f_75.pdf'),
          matching: find.byWidgetPredicate(
              (w) => w is Container && w.foregroundDecoration != null));
      expect(ring, findsOneWidget);
      await tester.pump(const Duration(seconds: 5));
      expect(ring, findsNothing, reason: 'vurgu birkaç saniyede söner');
    });

    testWidgets('sıralama ve öğe sayısı ekranda; tür çipi süzer',
        (tester) async {
      final (_, _, nav) = await pump(tester);
      nav.currentState!.push(browserRoute(BrowserScreen(path: p.join(dir.path, 'Alfa'))));
      await settle(tester);
      expect(find.byType(FmListToolbar), findsOneWidget);
      expect(find.text('13 öğe · 66 B'), findsOneWidget);
      expect(find.text('Ada göre'), findsOneWidget);
      // Filtre düğmesi → çip satırı → "Klasörler" yalnız Beta'yı bırakır.
      await tester.tap(find.byTooltip('Filtre'));
      await settle(tester);
      // Türler tek açılır hapta (2026-10-28) → levhada "Klasörler".
      await tester.tap(find.byKey(const ValueKey('type-pill')));
      await settle(tester);
      await tester.tap(find.byKey(const ValueKey('type-folder')));
      await tester.tap(find.byKey(const ValueKey('type-done')));
      await settle(tester);
      expect(find.byType(FmEntryRow), findsOneWidget);
      expect(find.text('Beta'), findsWidgets);
    });

    testWidgets('360 dp ve 1,4× yazıda taşma yok (liste + seçim)',
        (tester) async {
      final (_, _, nav) = await pump(tester, textScale: 1.4);
      nav.currentState!.push(browserRoute(BrowserScreen(path: p.join(dir.path, 'Alfa'))));
      await settle(tester);
      expect(tester.takeException(), isNull);
      await tester.longPress(find.byType(FmEntryRow).first);
      await settle(tester);
      expect(find.text('Tümünü seç'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('tablet (≥ 840 dp) iki bölme', (tester) async {
      final (_, _, nav) =
          await pump(tester, size: const Size(1200, 800));
      nav.currentState!.push(browserRoute(BrowserScreen(path: p.join(dir.path, 'Alfa'))));
      await settle(tester);
      expect(find.text('Konumlar'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('boş klasörde FmEmptyState', (tester) async {
      final (_, _, nav) = await pump(tester);
      nav.currentState!
          .push(browserRoute(BrowserScreen(path: p.join(dir.path, 'Alfa', 'Beta'))));
      await settle(tester);
      expect(find.text('Bu klasör boş'), findsOneWidget);
    });
  });
}
