// PDF Pro Faz 54: düzenleme kipinin levhaları ve blok isabet testi.
import 'dart:io';

import 'package:dosya_okuyucu/core/l10n/app_strings.dart';
import 'package:dosya_okuyucu/services/pdf/pro/pdf_version_history.dart';
import 'package:dosya_okuyucu/widgets/pdf_pro/pdf_block_layer.dart';
import 'package:dosya_okuyucu/widgets/pdf_pro/pdf_pro_sheets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

/// Düğmeye basınca [open]'ı çağırıp sonucu [result]'a yazan sayfa.
Future<void> _host<T>(WidgetTester tester,
    Future<T> Function(BuildContext) open, void Function(T) result,
    {Locale locale = const Locale('tr')}) async {
  await tester.pumpWidget(MaterialApp(
    locale: locale,
    supportedLocales: const [Locale('tr'), Locale('en'), Locale('ar')],
    localizationsDelegates: const [
      AppStrings.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    home: Builder(
      builder: (context) => Scaffold(
        body: TextButton(
          onPressed: () async => result(await open(context)),
          child: const Text('aç'),
        ),
      ),
    ),
  ));
  await tester.tap(find.text('aç'));
  await tester.pumpAndSettle();
}

void main() {
  group('blok isabeti', () {
    const rects = [
      Rect.fromLTWH(10, 10, 100, 20),
      Rect.fromLTWH(10, 34, 100, 20),
      Rect.fromLTWH(200, 10, 50, 50),
    ];

    test('kutunun içi o bloğu, boşluk hiçbirini vermez', () {
      expect(hitPdfBlock(rects, const Offset(50, 20)), 0);
      expect(hitPdfBlock(rects, const Offset(220, 40)), 2);
      expect(hitPdfBlock(rects, const Offset(150, 100)), isNull);
      expect(hitPdfBlock(const [], const Offset(1, 1)), isNull);
    });

    test('kenarın biraz dışı da tutar; komşular çakışınca yakın olan kazanır',
        () {
      expect(hitPdfBlock(rects, const Offset(7, 20)), 0);
      // İki satırın arası: ikisinin de payına düşer, merkezi yakın olan.
      expect(hitPdfBlock(rects, const Offset(50, 31)), 0);
      expect(hitPdfBlock(rects, const Offset(50, 33)), 1);
    });
  });

  group('paragraf levhası', () {
    testWidgets('değişen metin döner (boşluklar sadeleşir)', (tester) async {
      String? out = 'yok';
      await _host<String?>(tester,
          (c) => showPdfBlockEditSheet(c, initial: 'Eski metin'), (v) => out = v);
      expect(find.text('Paragrafı düzenle'), findsOneWidget);
      await tester.enterText(
          find.byKey(const ValueKey('pse-edit-field')), 'Yeni   metin\nburada ');
      await tester.tap(find.byKey(const ValueKey('pse-edit-apply')));
      await tester.pumpAndSettle();
      expect(out, 'Yeni metin burada');
    });

    testWidgets('değişmeyen ya da boş metin null döner', (tester) async {
      String? out = 'yok';
      await _host<String?>(tester,
          (c) => showPdfBlockEditSheet(c, initial: 'Eski metin'), (v) => out = v);
      await tester.tap(find.byKey(const ValueKey('pse-edit-apply')));
      await tester.pumpAndSettle();
      expect(out, isNull);

      out = 'yok';
      await tester.tap(find.text('aç'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const ValueKey('pse-edit-field')), '  ');
      await tester.tap(find.byKey(const ValueKey('pse-edit-apply')));
      await tester.pumpAndSettle();
      expect(out, isNull);
    });
  });

  group('kurtarma levhası', () {
    testWidgets('sayıyı söyler; Geri yükle / Sil seçilir', (tester) async {
      PdfRecoverChoice? out;
      await _host<PdfRecoverChoice?>(
          tester,
          (c) => showPdfRecoverSheet(c, count: 3, copyOnly: false),
          (v) => out = v);
      expect(find.text('Kaydedilmemiş düzenlemeler bulundu'), findsOneWidget);
      expect(find.textContaining('3 kaydedilmemiş değişiklik'), findsOneWidget);
      expect(
          find.text('Kaydedilmemiş düzenlemeleri geri yükle'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('pse-recover-restore')));
      await tester.pumpAndSettle();
      expect(out, PdfRecoverChoice.restore);

      await tester.tap(find.text('aç'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('pse-recover-discard')));
      await tester.pumpAndSettle();
      expect(out, PdfRecoverChoice.discard);
    });

    testWidgets('yalnız kopya kurtarılabiliyorsa bunu söyler', (tester) async {
      await _host<PdfRecoverChoice?>(tester,
          (c) => showPdfRecoverSheet(c, count: 0, copyOnly: true), (_) {});
      expect(find.text('Kurtarılan kopyayı kaydet'), findsOneWidget);
      expect(find.text('Kaydedilmemiş düzenlemeleri geri yükle'), findsNothing);
    });
  });

  group('sürüm geçmişi levhası', () {
    testWidgets('boşken 14 gün notu; doluyken sürüme dön seçilir',
        (tester) async {
      PdfVersion? out;
      await _host<PdfVersion?>(tester,
          (c) => showPdfVersionsSheet(c, versions: const []), (v) => out = v);
      expect(find.textContaining('14 gün'), findsOneWidget);
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();

      final versions = [
        PdfVersion(File('a.pdf'), DateTime(2026, 11, 10, 14, 5), 2048),
        PdfVersion(File('b.pdf'), DateTime(2026, 11, 9, 9, 30), 1024),
      ];
      await _host<PdfVersion?>(tester,
          (c) => showPdfVersionsSheet(c, versions: versions), (v) => out = v);
      expect(find.text('Bu sürüme dön'), findsNWidgets(2));
      expect(find.textContaining('14:05'), findsOneWidget);
      await tester.tap(find.text('Bu sürüme dön').last);
      await tester.pumpAndSettle();
      expect(out, same(versions[1]));
    });
  });

  group('korumalı belge levhası', () {
    testWidgets('uyarır; sahip parolasıyla aç → true, vazgeç → false',
        (tester) async {
      bool? out;
      await _host<bool>(tester, showPdfLockedSheet, (v) => out = v);
      expect(find.text('Bu belge düzenlemeye karşı korunuyor'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('pse-locked-open')));
      await tester.pumpAndSettle();
      expect(out, isTrue);

      await tester.tap(find.text('aç'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Vazgeç'));
      await tester.pumpAndSettle();
      expect(out, isFalse);
    });

    testWidgets('İngilizce ve Arapça metinler çizilir', (tester) async {
      await _host<bool>(tester, showPdfLockedSheet, (_) {},
          locale: const Locale('en'));
      expect(find.text('Unlock with owner password'), findsOneWidget);
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();
      await _host<bool>(tester, showPdfLockedSheet, (_) {},
          locale: const Locale('ar'));
      expect(find.text('فتح بكلمة مرور المالك'), findsOneWidget);
    });
  });
}
