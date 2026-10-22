import 'package:dosya_okuyucu/core/app_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dosya_okuyucu/widgets/scan_flow.dart';

/// **Tarama rehberi** (2026-10-18): ML Kit ekranının "sayfa ekle" düğmesi
/// yazısız, "Sonraki" taramayı bitiriyor — rehber ilk taramalarda çıkar,
/// "bir daha gösterme" ile kapanır.
void main() {
  Future<bool?> open(WidgetTester tester) async {
    bool? result;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () async =>
                result = await ScanFlow.showTipsIfNeeded(context),
            child: const Text('aç'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('aç'));
    await tester.pumpAndSettle();
    return result;
  }

  testWidgets('ilk taramada rehber çıkar; "başla" taramaya geçirir',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    await open(tester);
    expect(find.byIcon(Icons.note_add_rounded), findsOneWidget);
    final start = find.byIcon(AppIcons.ocr).last;
    await tester.ensureVisible(start);
    await tester.pumpAndSettle();
    await tester.tap(start);
    await tester.pumpAndSettle();
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getInt('scan_tips_shown'), 1);
  });

  testWidgets('"bir daha gösterme" sonrası rehber çıkmaz', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await open(tester);
    await tester.ensureVisible(find.byType(TextButton).last);
    await tester.pumpAndSettle();
    await tester.tap(find.byType(TextButton).last);
    await tester.pumpAndSettle();
    final result = await open(tester);
    expect(find.byIcon(Icons.note_add_rounded), findsNothing);
    expect(result, isTrue, reason: 'rehber atlanınca tarama sürer');
  });

  testWidgets('sınır dolunca kendiliğinden çıkmaz', (tester) async {
    SharedPreferences.setMockInitialValues(
        {'scan_tips_shown': ScanFlow.tipsAutoShowLimit});
    final result = await open(tester);
    expect(find.byIcon(Icons.note_add_rounded), findsNothing);
    expect(result, isTrue);
  });
}
