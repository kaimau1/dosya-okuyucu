import 'dart:async';
import 'dart:io';

import 'package:dosya_okuyucu/core/app_state.dart';
import 'package:dosya_okuyucu/core/l10n/app_language.dart';
import 'package:dosya_okuyucu/core/l10n/app_strings.dart';
import 'package:dosya_okuyucu/core/user_error.dart';
import 'package:dosya_okuyucu/services/gemini_service.dart';
import 'package:dosya_okuyucu/widgets/ai_key_gate.dart';
import 'package:dosya_okuyucu/widgets/permission_gate.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Faz 5 — son kullanıcı iletişimi: hata dili, izin kapısı, anahtarsız AI,
/// bekçiler.
void main() {
  FileSystemException fs(int code, [String msg = '']) =>
      FileSystemException('Cannot open file', '/x/y', OSError(msg, code));

  group('UserError.classify', () {
    test('dosya izni yok / yer yok / dosya yok / salt okunur / var', () {
      expect(UserError.classify(fs(13)), UserErrorKind.permission);
      expect(UserError.classify(fs(1)), UserErrorKind.permission);
      expect(UserError.classify(fs(28)), UserErrorKind.noSpace);
      expect(UserError.classify(fs(2)), UserErrorKind.notFound);
      expect(UserError.classify(fs(30)), UserErrorKind.readOnly);
      expect(UserError.classify(fs(17)), UserErrorKind.exists);
    });
    test('kodsuz işletim sistemi metninden de sınıflanır', () {
      expect(UserError.classify(fs(0, 'Permission denied')),
          UserErrorKind.permission);
      expect(UserError.classify(fs(0, 'No space left on device')),
          UserErrorKind.noSpace);
    });
    test('ağ ve AI', () {
      expect(UserError.classify(const SocketException('x')),
          UserErrorKind.offline);
      expect(UserError.classify(TimeoutException('t')), UserErrorKind.offline);
      expect(UserError.classify(GeminiException('q', statusCode: 429)),
          UserErrorKind.aiQuota);
      expect(UserError.classify(GeminiException('k', statusCode: 403)),
          UserErrorKind.aiKey);
      expect(UserError.classify(GeminiException('n')), UserErrorKind.offline);
    });
    test('bilinmeyen', () {
      expect(UserError.classify(StateError('boom')), UserErrorKind.unknown);
    });
  });

  test('mesaj arayüz dilinde, ham metin yalnız ayrıntıda', () {
    final e = UserError.from(fs(13, 'Permission denied'),
        strings: const AppStrings(AppLanguage.en));
    expect(e.message, const AppStrings(AppLanguage.en).t('uerr.permission'));
    expect(e.message.contains('errno'), isFalse);
    expect(e.message.contains('/x/y'), isFalse);
    expect(e.detail.contains('/x/y'), isTrue);
    final ar = UserError.from(fs(28), strings: const AppStrings(AppLanguage.ar));
    expect(ar.message, const AppStrings(AppLanguage.ar).t('uerr.no_space'));
  });

  test('her tür için üç dilde metin var', () {
    for (final kind in UserErrorKind.values) {
      final e = UserError(kind, '', '');
      expect(e.kind, kind);
    }
    for (final lang in AppLanguage.values) {
      final s = AppStrings(lang);
      for (final k in [
        'uerr.permission',
        'uerr.no_space',
        'uerr.not_found',
        'uerr.offline',
        'uerr.unknown',
        'uerr.details',
        'uerr.retry',
      ]) {
        expect(s.t(k), isNot(k), reason: '$lang $k');
      }
    }
  });

  group('bekçiler (ekran kodu)', () {
    final uiFiles = [
      for (final d in ['lib/screens', 'lib/widgets'])
        ...Directory(d)
            .listSync(recursive: true)
            .whereType<File>()
            .where((f) => f.path.endsWith('.dart'))
    ];

    test("ham hata deseni yok: '\$e', {'error': e}, '⚠️ \$e'", () {
      final raw = RegExp(r"""\{'error': e\}|(?<!contains\()'\$e'(?!\.contains)|'\S*\s?\$e'|: \$e'""");
      final offenders = <String>[];
      for (final f in uiFiles) {
        final lines = f.readAsLinesSync();
        for (var i = 0; i < lines.length; i++) {
          final l = lines[i];
          if (l.trimLeft().startsWith('//')) continue;
          if (raw.hasMatch(l)) offenders.add('${f.path}:${i + 1}: ${l.trim()}');
        }
      }
      expect(offenders, isEmpty,
          reason: 'Ham hata metni kullanıcıya gider; userErrorText(e) / '
              'showUserError kullanın (core/user_error.dart).');
    });

    test('gerekçesiz boş catch yok', () {
      final empty = RegExp(r'catch \([^)]*\) \{\s*\}');
      final offenders = <String>[];
      for (final f in uiFiles) {
        final src = f.readAsStringSync();
        for (final m in empty.allMatches(src)) {
          final line = '\n'.allMatches(src.substring(0, m.start)).length + 1;
          offenders.add('${f.path}:$line');
        }
      }
      expect(offenders, isEmpty,
          reason: 'Ekran kodunda boş catch ya kullanıcıya söylemeli ya da '
              'neden "en iyi çaba" olduğunu bir yorumla yazmalı.');
    });
  });

  group('PermissionGate', () {
    late _FakeProbe probe;
    setUp(() {
      probe = _FakeProbe();
      PermissionGate.probe = probe;
    });
    tearDown(() => PermissionGate.probe = const PluginPermissionProbe());

    Widget wrap(Widget child) => MaterialApp(
          locale: const Locale('tr'),
          supportedLocales: const [Locale('tr'), Locale('en'), Locale('ar')],
          localizationsDelegates: const [
            AppStrings.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: Scaffold(body: child),
        );

    const tr = AppStrings(AppLanguage.tr);

    for (final p in AppPermission.values) {
      testWidgets('${p.name}: reddedildi → neden + izin ver; verilince içerik',
          (tester) async {
        probe.state = GateStatus.denied;
        await tester.pumpWidget(wrap(PermissionGate(
            permission: p, child: const Text('İÇERİK'))));
        await tester.pumpAndSettle();
        final k = PermissionCard.keyOf(p);
        expect(find.text(tr.t('perm.${k}_why')), findsOneWidget);
        expect(find.text(tr.t('perm.${k}_without')), findsOneWidget);
        expect(find.text('İÇERİK'), findsNothing);
        probe.next = GateStatus.granted;
        await tester.tap(find.text(tr.t('perm.allow')));
        await tester.pumpAndSettle();
        expect(find.text('İÇERİK'), findsOneWidget);
      });
    }

    testWidgets('kalıcı ret → Ayarlara git; dönünce kendini tazeler',
        (tester) async {
      probe.state = GateStatus.permanentlyDenied;
      await tester.pumpWidget(wrap(const PermissionGate(
          permission: AppPermission.camera, child: Text('İÇERİK'))));
      await tester.pumpAndSettle();
      await tester.tap(find.text(tr.t('perm.open_settings')));
      await tester.pumpAndSettle();
      expect(probe.settingsOpened, 1);
      probe.state = GateStatus.granted;
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(find.text('İÇERİK'), findsOneWidget);
    });
  });

  testWidgets('anahtarsız AI: tek "etkinleştir" penceresi, vazgeçince false',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final state = AppState();
    await tester.runAsync(state.init);
    bool? result;
    await tester.pumpWidget(ChangeNotifierProvider<AppState>.value(
      value: state,
      child: MaterialApp(
        locale: const Locale('en'),
        supportedLocales: const [Locale('tr'), Locale('en'), Locale('ar')],
        localizationsDelegates: const [
          AppStrings.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async => result = await ensureAiKey(context),
            child: const Text('AI'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('AI'));
    await tester.pumpAndSettle();
    const en = AppStrings(AppLanguage.en);
    expect(find.text(en.t('aikey.title')), findsOneWidget);
    expect(find.text(en.t('aikey.add')), findsOneWidget);
    await tester.tap(find.text(en.t('common.cancel')));
    await tester.pumpAndSettle();
    expect(result, isFalse);
  });
}

class _FakeProbe extends PermissionProbe {
  GateStatus state = GateStatus.denied;
  GateStatus? next;
  int settingsOpened = 0;

  @override
  Future<GateStatus> status(AppPermission p) async => state;

  @override
  Future<GateStatus> request(AppPermission p) async {
    state = next ?? state;
    return state;
  }

  @override
  Future<void> openSettings() async => settingsOpened++;
}
