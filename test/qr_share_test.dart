import 'dart:convert';
import 'dart:io';

import 'package:barcode/barcode.dart';
import 'package:dosya_okuyucu/core/l10n/app_strings.dart';
import 'package:dosya_okuyucu/screens/fm/remote/share_choice.dart';
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

  // 2026-11-02: paylaş seçimi ikiye inince kopan "metni QR'da göster" yolu
  // küçük metin dosyasında geri bağlandı.
  group('paylaş seçimi — metni QR\'da göster', () {
    late Directory dir;
    late String small, big, pdf;
    setUp(() {
      dir = Directory.systemTemp.createTempSync('qr_choice');
      small = '${dir.path}/not.txt';
      File(small).writeAsStringSync('Alışveriş: süt, ekmek, çay');
      big = '${dir.path}/uzun.txt';
      File(big).writeAsStringSync('x' * (qrTextMaxBytes + 1));
      pdf = '${dir.path}/belge.pdf';
      File(pdf).writeAsStringSync('%PDF-1.4');
    });
    tearDown(() => dir.deleteSync(recursive: true));

    test('aday: küçük metin evet; büyük, metin olmayan, yok hayır', () async {
      expect(await isQrTextCandidate(small), isTrue);
      expect(await isQrTextCandidate(big), isFalse);
      expect(await isQrTextCandidate(pdf), isFalse);
      expect(await isQrTextCandidate('${dir.path}/yok.txt'), isFalse);
      expect(await readQrText(small), 'Alışveriş: süt, ekmek, çay');
    });

    Widget host(List<String> paths, void Function(bool) done) => MaterialApp(
          locale: const Locale('tr'),
          supportedLocales: const [Locale('tr'), Locale('en'), Locale('ar')],
          localizationsDelegates: const [
            AppStrings.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () async => done(await showShareChoice(context, paths)),
              child: const Text('paylaş'),
            ),
          ),
        );

    Future<void> openSheet(WidgetTester tester) async {
      await tester.tap(find.text('paylaş'));
      // stat gerçek G/Ç: sahte saatte bitmez.
      await tester.runAsync(() => Future<void>.delayed(
          const Duration(milliseconds: 50)));
      await tester.pumpAndSettle();
    }

    testWidgets('küçük metin dosyasında seçenek var, QR ekranını açar',
        (tester) async {
      await tester.pumpWidget(host([small], (_) {}));
      await openSheet(tester);
      expect(find.byKey(const ValueKey('share-nearby')), findsOneWidget);
      expect(find.byKey(const ValueKey('share-text-qr')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('share-text-qr')));
      // Okuma gerçek G/Ç: kare ilerlet + gerçek saatte bekle, birkaç tur.
      for (var i = 0; i < 5 && find.byType(QrShareScreen).evaluate().isEmpty;
          i++) {
        await tester.pump(const Duration(milliseconds: 100));
        await tester.runAsync(() => Future<void>.delayed(
            const Duration(milliseconds: 50)));
      }
      await tester.pumpAndSettle();
      expect(find.byType(QrShareScreen), findsOneWidget);
      expect(find.byKey(const ValueKey('qr-0')), findsOneWidget);
    });

    testWidgets('PDF ya da çoklu seçimde seçenek yok', (tester) async {
      await tester.pumpWidget(host([pdf], (_) {}));
      await openSheet(tester);
      expect(find.byKey(const ValueKey('share-text-qr')), findsNothing);
      await tester.tapAt(const Offset(10, 10)); // levhayı kapat
      await tester.pumpAndSettle();
      await tester.pumpWidget(host([small, small], (_) {}));
      await openSheet(tester);
      expect(find.byKey(const ValueKey('share-text-qr')), findsNothing);
    });
  });
}
