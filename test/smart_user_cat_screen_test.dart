import 'package:dosya_okuyucu/core/l10n/app_strings.dart';
import 'package:dosya_okuyucu/screens/fm/smart_user_cat_screen.dart';
import 'package:dosya_okuyucu/services/fm/smart_sort.dart';
import 'package:dosya_okuyucu/services/fm/smart_user_cats.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget _app(Widget home) => MaterialApp(
      locale: const Locale('tr'),
      supportedLocales: const [Locale('tr'), Locale('en'), Locale('ar')],
      localizationsDelegates: const [
        AppStrings.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: home,
    );

/// Kullanıcı kategorisi ekranı (PLAN §1.1 m.3): denemeden kaydedilmez;
/// düzenlemede yalnız simge/renk değişirse deneme gerekmez.
void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    SmartUserCats.debugReset();
    SmartSort.debugReset();
  });

  // Bütün form tek ekranda kurulsun (ListView görünmeyeni kurmaz).
  void tall(WidgetTester t) {
    t.view.physicalSize = const Size(900, 3000);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
  }

  FilledButton save(WidgetTester t) =>
      t.widget<FilledButton>(find.byKey(const ValueKey('suc-save')));

  testWidgets('yeni kategori: ad + cümle yazılsa da denenmeden Kaydet kapalı',
      (t) async {
    tall(t);
    await t.pumpWidget(_app(const SmartUserCatScreen()));
    expect(save(t).onPressed, isNull);
    await t.enterText(find.byKey(const ValueKey('suc-name')), 'Kira');
    await t.enterText(
        find.byKey(const ValueKey('suc-about')), 'Kira dekontları');
    await t.pump();
    expect(save(t).onPressed, isNull, reason: 'Dene + onay şart');
    expect(find.textContaining('Kaydetmek için önce dene'), findsOneWidget);
    expect(find.byKey(const ValueKey('suc-try')), findsOneWidget);
  });

  testWidgets('düzenle: simge değişince doğrudan kaydedilir, cümle değişince '
      'deneme ister', (t) async {
    const cat = SmartUserCat(id: 'u:a', name: 'Kira', about: 'Kira dekontu');
    SmartUserCats.debugReset([cat]);
    tall(t);
    await t.pumpWidget(_app(const SmartUserCatScreen(initial: cat)));
    expect(find.byKey(const ValueKey('suc-try')), findsNothing);
    await t.tap(find.byKey(const ValueKey('suc-icon-home')));
    await t.pump();
    expect(save(t).onPressed, isNotNull);
    await t.enterText(find.byKey(const ValueKey('suc-about')), 'Başka cümle');
    await t.pump();
    expect(save(t).onPressed, isNull);
    expect(find.byKey(const ValueKey('suc-try')), findsOneWidget);
  });
}
