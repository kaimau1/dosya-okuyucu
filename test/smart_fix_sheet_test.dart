import 'package:dosya_okuyucu/core/l10n/app_strings.dart';
import 'package:dosya_okuyucu/screens/fm/smart_fix_sheet.dart';
import 'package:dosya_okuyucu/widgets/app_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _app(Widget Function(BuildContext) body) => MaterialApp(
      locale: const Locale('tr'),
      supportedLocales: const [Locale('tr'), Locale('en'), Locale('ar')],
      localizationsDelegates: const [
        AppStrings.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: Scaffold(body: Builder(builder: body)),
    );

void main() {
  testWidgets('"Ne olmalıydı?": seçilen kategori döner, belgeye görsel yok',
      (tester) async {
    String? picked;
    Future<void> open(BuildContext ctx, {required bool image}) async {
      picked = await showAppSheet<String>(
        ctx,
        scrollable: false,
        builder: (_) => SmartFixSheet(
            current: 'screenshot', image: image, name: 'a.jpg'),
      );
    }

    late BuildContext ctx;
    await tester.pumpWidget(_app((c) {
      ctx = c;
      return const SizedBox.expand();
    }));

    // Görsel: belge + görsel kategorileri, şimdiki seçili.
    final first = open(ctx, image: true);
    await tester.pumpAndSettle();
    expect(find.text('Ne olmalıydı?'), findsOneWidget);
    expect(find.byKey(const ValueKey('smf-screenshot')), findsOneWidget);
    await tester.ensureVisible(find.byKey(const ValueKey('smf-email')));
    await tester.tap(find.byKey(const ValueKey('smf-email')));
    await tester.pumpAndSettle();
    await first;
    expect(picked, 'email');

    // Belge (PDF): görsel kategorisi sunulmaz; "Aslında doğruymuş" şimdikini döner.
    final second = open(ctx, image: false);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('smf-meme')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('smf-keep')));
    await tester.pumpAndSettle();
    await second;
    expect(picked, 'screenshot');
  });
}
