import 'dart:convert';

import 'package:barcode/barcode.dart';
import 'package:dosya_okuyucu/core/l10n/app_strings.dart';
import 'package:dosya_okuyucu/screens/qr_share_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('kısa not tek QR; uzun not numaralı parçalara bölünür, kayıpsız', () {
    expect(QrShareScreen.parts('Merhaba dünya'), ['Merhaba dünya']);
    final long = List.generate(400, (i) => 'Kelime$i çğüşıö').join(' ');
    final parts = QrShareScreen.parts(long);
    expect(parts.length, greaterThan(1));
    for (var i = 0; i < parts.length; i++) {
      expect(parts[i], startsWith('[${i + 1}/${parts.length}] '));
      expect(utf8.encode(parts[i]).length, lessThanOrEqualTo(QrShareScreen.maxBytes));
      // Her parça gerçekten QR'a sığar.
      Barcode.qrCode().make(parts[i], width: 200, height: 200);
    }
    final joined = [
      for (final p in parts) p.replaceFirst(RegExp(r'^\[\d+/\d+\] '), ''),
    ].join(' ');
    expect(joined.split(RegExp(r'\s+')), long.split(' '));
  });

  testWidgets('QR ekranı parçalar arasında gezinir', (tester) async {
    final long = List.generate(400, (i) => 'Satır $i').join('\n');
    await tester.pumpWidget(MaterialApp(
      locale: const Locale('tr'),
      supportedLocales: const [Locale('tr'), Locale('en'), Locale('ar')],
      localizationsDelegates: const [
        AppStrings.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: QrShareScreen(title: 'not.txt', text: long),
    ));
    final n = QrShareScreen.parts(long).length;
    expect(find.text('1 / $n'), findsOneWidget);
    await tester.tap(find.byTooltip('Sonraki kod'));
    await tester.pumpAndSettle();
    expect(find.text('2 / $n'), findsOneWidget);
  });
}
