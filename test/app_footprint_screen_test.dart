import 'package:dosya_okuyucu/core/l10n/app_strings.dart';
import 'package:dosya_okuyucu/screens/settings/app_footprint_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

/// "Uygulamanın kapladığı alan" ekranı — duman testi: klasör yolları
/// bilinmezken (masaüstü/test, `path_provider` yok) çökmeden açılır ve
/// temizleme düğmesi pasif durur.
void main() {
  testWidgets('yollar bilinmezken ekran açılır, temizle pasif', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      locale: Locale('tr'),
      supportedLocales: [Locale('tr'), Locale('en'), Locale('ar')],
      localizationsDelegates: [
        AppStrings.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: AppFootprintScreen(),
    ));
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(find.text('Uygulamanın kapladığı alan'), findsOneWidget);
    expect(find.text('Ölçülecek bir şey yok.'), findsOneWidget);
    final clean = tester.widget<ButtonStyleButton>(find.ancestor(
        of: find.textContaining('Önbelleği temizle'),
        matching: find.byWidgetPredicate((w) => w is ButtonStyleButton)));
    expect(clean.onPressed, isNull);
    expect(tester.takeException(), isNull);
  });
}
