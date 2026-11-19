import 'package:dosya_okuyucu/core/l10n/app_strings.dart';
import 'package:dosya_okuyucu/widgets/fm/image_qr_chip.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

/// Görseldeki QR düğmesi (2026-11-18).
void main() {
  test('bağlantı tanıma', () {
    expect(ImageQrChip.linkOf('https://ornek.com/a')?.host, 'ornek.com');
    expect(ImageQrChip.linkOf('www.ornek.com')?.scheme, 'https');
    expect(ImageQrChip.linkOf('WIFI:S:ev;T:WPA;P:1234;;'), isNull);
    expect(ImageQrChip.linkOf('düz yazı'), isNull);
  });

  Widget app(Widget child) => MaterialApp(
        locale: const Locale('tr'),
        supportedLocales: const [Locale('tr'), Locale('en'), Locale('ar')],
        localizationsDelegates: const [
          AppStrings.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: Scaffold(body: Center(child: child)),
      );

  testWidgets('QR yoksa hiçbir şey çizilmez', (tester) async {
    ImageQrChip.debugSeed('/yok.jpg', const []);
    await tester.pumpWidget(app(const ImageQrChip(path: '/yok.jpg')));
    expect(find.byKey(const ValueKey('img-qr-chip')), findsNothing);
  });

  testWidgets('bağlantılı QR alan adını gösterir', (tester) async {
    ImageQrChip.debugSeed('/qr.jpg', const ['https://www.ornek.com/menu']);
    await tester.pumpWidget(app(const ImageQrChip(path: '/qr.jpg')));
    expect(find.byKey(const ValueKey('img-qr-chip')), findsOneWidget);
    expect(find.text('ornek.com'), findsOneWidget);
  });
}
