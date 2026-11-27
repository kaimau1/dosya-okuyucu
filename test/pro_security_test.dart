import 'dart:io';

import 'package:dosya_okuyucu/core/app_state.dart';
import 'package:dosya_okuyucu/core/edition.dart';
import 'package:dosya_okuyucu/core/l10n/app_strings.dart';
import 'package:dosya_okuyucu/core/theme.dart';
import 'package:dosya_okuyucu/screens/audiobook/audiobook_library_screen.dart';
import 'package:dosya_okuyucu/screens/fm/bills_screen.dart';
import 'package:dosya_okuyucu/screens/fm/smart_clutter_screen.dart';
import 'package:dosya_okuyucu/screens/fm/smart_folders_screen.dart';
import 'package:dosya_okuyucu/screens/fm/smart_scope_screen.dart';
import 'package:dosya_okuyucu/screens/fm/smart_sort_screen.dart';
import 'package:dosya_okuyucu/screens/pdf_tools_screen.dart';
import 'package:dosya_okuyucu/services/audiobook/audiobook_job.dart';
import 'package:dosya_okuyucu/services/audiobook/audiobook_maker.dart';
import 'package:dosya_okuyucu/services/fm/ai_scope.dart';
import 'package:dosya_okuyucu/services/fm/bills.dart';
import 'package:dosya_okuyucu/services/fm/fm_env.dart';
import 'package:dosya_okuyucu/services/fm/smart_learn.dart';
import 'package:dosya_okuyucu/services/fm/smart_quota.dart';
import 'package:dosya_okuyucu/services/fm/smart_scope_pick.dart';
import 'package:dosya_okuyucu/services/fm/smart_sort.dart';
import 'package:dosya_okuyucu/services/fm/smart_sort_bg.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _delegates = <LocalizationsDelegate<Object?>>[
  AppStrings.delegate,
  GlobalMaterialLocalizations.delegate,
  GlobalWidgetsLocalizations.delegate,
  GlobalCupertinoLocalizations.delegate,
];

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    SmartScopePick.resetForTest();
    await SmartLearn.forgetAll();
  });

  test('Pro lansman fiyatı 29,99 TL ve Akıllı Klasör başlangıç hakkı 500', () {
    expect(ProListing.priceLabel, '29,99 TL');
    expect(SmartQuota.proStarterLimit, 500);
    expect(SmartQuota.starterCapFor(Edition.pro, hasOwnKey: false), 500);
    expect(SmartQuota.starterCapFor(Edition.pro, hasOwnKey: true), isNull);
    expect(SmartQuota.starterCapFor(Edition.kisisel, hasOwnKey: false), isNull);
  });

  test('SmartScopePick hızlı seçimleri ve en az bir seçim denetimi çalışır',
      () async {
    await SmartScopePick.selectOnlyDocs();
    expect(SmartScopePick.groupOn(SmartGroup.docs), isTrue);
    expect(SmartScopePick.groupOn(SmartGroup.videos), isFalse);
    expect(SmartScopePick.groupOn(SmartGroup.images), isFalse);
    expect(SmartScopePick.hasAnySelected, isTrue);

    await SmartScopePick.selectOnlyDownloads();
    expect(SmartScopePick.sourceOn(SmartSource.download), isTrue);
    expect(SmartScopePick.sourceOn(SmartSource.whatsapp), isFalse);
    expect(SmartScopePick.groupOn(SmartGroup.docs), isTrue);
    expect(SmartScopePick.hasAnySelected, isTrue);

    await SmartScopePick.setAll(on: false);
    expect(SmartScopePick.hasAnySelected, isFalse);

    await SmartScopePick.setAll(on: true);
    expect(SmartScopePick.hasAnySelected, isTrue);
    expect(SmartScopePick.groupOn(SmartGroup.videos), isTrue);
  });

  test('runLocalOnly maxTotal başlangıç sınırında durur', () async {
    final dir = Directory.systemTemp.createTempSync('smart_starter_cap');
    final downloadDir = Directory('${dir.path}/Download')
      ..createSync(recursive: true);
    final root0 = FmEnv.primaryRoot;
    FmEnv.primaryRoot = dir.path;
    SmartSort.debugReset();
    try {
      File('${downloadDir.path}/Fatura_IGDAS_1.pdf').writeAsStringSync('pdf');
      File('${downloadDir.path}/Ziraat_Dekont_2.pdf').writeAsStringSync('pdf');

      final first = await SmartSort.runLocalOnly(
        scope: const AiScope(settings: AiScopeSettings()),
        maxTotal: 1,
      );
      expect(first.processed, 1);
      expect(first.hold, SmartHold.cap);

      final second = await SmartSort.runLocalOnly(
        scope: const AiScope(settings: AiScopeSettings()),
        maxTotal: 1,
      );
      expect(second.processed, 0);
      expect(second.hold, SmartHold.cap);
    } finally {
      FmEnv.primaryRoot = root0;
      SmartSort.debugReset();
      dir.deleteSync(recursive: true);
    }
  }, skip: Edition.current == Edition.lite);

  group('Lite derlemede derin Pro güvenliği (bypass kapalı)', () {
    Widget wrap(Widget child) => ChangeNotifierProvider<AppState>(
          create: (_) => AppState(),
          child: MaterialApp(
            theme: AppTheme.light(),
            locale: const Locale('tr'),
            supportedLocales: const [Locale('tr'), Locale('en'), Locale('ar')],
            localizationsDelegates: _delegates,
            home: child,
          ),
        );

    final isLite = Edition.current == Edition.lite;

    testWidgets('doğrudan açılan bütün Pro ekranları Lite’ta kilitli kalır',
        (tester) async {
      final screens = <Widget>[
        const SmartSortScreen(),
        const SmartFoldersScreen(),
        const SmartClutterScreen(),
        const SmartScopeScreen(),
        const BillsScreen(),
        const AudiobookLibraryScreen(),
        const PdfToolsScreen(path: '/tmp/ornek.pdf'),
      ];
      for (final s in screens) {
        await tester.pumpWidget(wrap(s));
        await tester.pump();
        expect(
          find.byKey(const ValueKey('pro-locked-view')),
          findsOneWidget,
          reason: '${s.runtimeType} Lite sürümde kilit ekranı göstermeli',
        );
      }
    }, skip: !isLite);

    test('servis ve arka plan yolları Lite sürümde iş yürütmez', () async {
      final local = await SmartSort.runLocalOnly(
        scope: const AiScope(settings: AiScopeSettings()),
      );
      expect(local.processed, 0);
      expect(await Bills.instance.refresh(), 0);
      await SmartSortBg.run();
      expect(
        () => AudiobookJob.start(
          path: '/tmp/ornek.pdf',
          chapters: const [],
          numbers: const [],
          voice: AudiobookVoice.system,
        ),
        throwsStateError,
      );
    }, skip: !isLite);
  });
}
