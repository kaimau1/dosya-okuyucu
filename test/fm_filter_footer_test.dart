import 'package:dosya_okuyucu/core/l10n/app_strings.dart';
import 'package:dosya_okuyucu/models/fm_type.dart';
import 'package:dosya_okuyucu/widgets/fm/fm_type_chips.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

/// Faz 42 süzgeç cilası: levha alt satırı — Temizle yalnız seçim varken
/// etkin, levhayı kapatmadan seçimi bırakır; sıfır sonuç açıkça söylenir.
void main() {
  Widget app(Widget child) => MaterialApp(
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

  testWidgets('tür levhası: Temizle seçimi bırakır, levha açık kalır',
      (tester) async {
    Set<FmType>? last;
    await tester.pumpWidget(app(Builder(
      builder: (context) => TextButton(
        onPressed: () => showFmTypeSheet(
          context,
          counts: const {FmType.pdf: 3, FmType.image: 5, FmType.audio: 0},
          present: const [FmType.pdf, FmType.image, FmType.audio],
          selected: const {},
          onChanged: (s) => last = s,
        ),
        child: const Text('aç'),
      ),
    )));
    await tester.tap(find.text('aç'));
    await tester.pumpAndSettle();

    TextButton clear() => tester.widget<TextButton>(find.ancestor(
        of: find.text('Temizle'), matching: find.byWidgetPredicate((w) => w is TextButton)));
    expect(clear().onPressed, isNull, reason: 'seçim yokken Temizle pasif');
    expect(find.text('8 dosyayı göster'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('type-pdf')));
    await tester.pumpAndSettle();
    expect(last, {FmType.pdf});
    expect(find.text('3 dosyayı göster'), findsOneWidget);
    expect(clear().onPressed, isNotNull);

    await tester.tap(find.text('Temizle'));
    await tester.pumpAndSettle();
    expect(last, isEmpty);
    expect(find.byKey(const ValueKey('type-done')), findsOneWidget,
        reason: 'levha açık kalır');

    // Sıfır sonuçlu tür seçilirse birincil düğme bunu söyler.
    await tester.tap(find.byKey(const ValueKey('type-audio')));
    await tester.pumpAndSettle();
    expect(find.text('Hiç dosya kalmadı'), findsOneWidget);
  });
}
