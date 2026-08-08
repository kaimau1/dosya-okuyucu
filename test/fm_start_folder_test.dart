import 'dart:io';

import 'package:dosya_okuyucu/core/app_state.dart';
import 'package:dosya_okuyucu/core/l10n/app_strings.dart';
import 'package:dosya_okuyucu/screens/fm/browser_screen.dart';
import 'package:dosya_okuyucu/screens/home_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'support/temp_dir.dart';

/// **Açılış klasörü** (KALANLAR maddesi): dosyalarını hep aynı klasörde tutan
/// kullanıcı her açılışta panodan oraya tıklaya tıklaya gidiyordu.
const _delegates = <LocalizationsDelegate<Object?>>[
  AppStrings.delegate,
  GlobalMaterialLocalizations.delegate,
  GlobalWidgetsLocalizations.delegate,
  GlobalCupertinoLocalizations.delegate,
];

Future<AppState> _state(WidgetTester tester, {String? startFolder}) async {
  SharedPreferences.setMockInitialValues({});
  final state = AppState();
  // `init()` gerçek asenkron iş: sahte saat zonunda tamamlanmaz.
  await tester.runAsync(state.init);
  if (startFolder != null) {
    await tester.runAsync(() => state.setFmStartFolder(startFolder));
  }
  return state;
}

Future<void> _pumpHome(WidgetTester tester, AppState state) async {
  await tester.pumpWidget(
    ChangeNotifierProvider<AppState>.value(
      value: state,
      child: const MaterialApp(
        locale: Locale('tr'),
        supportedLocales: [Locale('tr'), Locale('en'), Locale('ar')],
        localizationsDelegates: _delegates,
        home: HomeScreen(),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
}

void main() {
  late Directory dir;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('start_folder');
    HomeScreen.debugResetStartFolder();
  });

  tearDown(() {
    HomeScreen.debugResetStartFolder();
    try {
      removeTempDir(dir);
    } catch (_) {}
  });

  test('tercih varsayılan BOŞ ve diske yazılıyor', () async {
    SharedPreferences.setMockInitialValues({});
    final state = AppState();
    await state.init();
    expect(state.fmStartFolder, isEmpty,
        reason: 'varsayılan davranış değişmemeli: pano ilk ekran');

    await state.setFmStartFolder('/depo/Belgeler');
    final reloaded = AppState();
    await reloaded.init();
    expect(reloaded.fmStartFolder, '/depo/Belgeler');
  });

  testWidgets('tercih boşken pano açılır, gezgin İTİLMEZ', (tester) async {
    final state = await _state(tester);
    await _pumpHome(tester, state);
    expect(find.byType(BrowserScreen), findsNothing);
  });

  testWidgets('tercih doluysa o klasör açılır', (tester) async {
    final state = await _state(tester, startFolder: dir.path);
    await _pumpHome(tester, state);
    await tester.pump();
    expect(find.byType(BrowserScreen), findsOneWidget);
  });

  testWidgets('klasör SİLİNMİŞSE sessizce pano gösterilir', (tester) async {
    // SD kart çıkarılmış ya da klasör silinmiş olabilir. Açılışta
    // çözülemeyecek bir hata penceresiyle karşılamak kötü bir karşılama.
    final missing = '${dir.path}/olmayan';
    final state = await _state(tester, startFolder: missing);
    await _pumpHome(tester, state);
    await tester.pump();
    expect(find.byType(BrowserScreen), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
