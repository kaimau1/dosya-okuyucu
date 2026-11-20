import 'package:dosya_okuyucu/core/theme.dart';
import 'package:dosya_okuyucu/widgets/fm/fm_category_tile.dart';
import 'package:dosya_okuyucu/widgets/fm/fm_tool_pills.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// 2026-11-20: Araçlar hap düğmeleri — büyük yazı ölçeğinde ve uzun
/// etiketlerde taşmadan çizilir, dokunma aracın kendisine gider.
void main() {
  List<FmTileData> tools(void Function(int) tap) => [
        for (var i = 0; i < 9; i++)
          FmTileData(
            icon: Icons.folder,
            color: Colors.blue,
            label: i == 0
                ? 'Çok uzun bir araç adı ki tek satıra hiç sığmasın diye yazıldı'
                : 'Araç $i',
            subtitle: i == 1 ? '3 biten' : '',
            id: 'tool$i',
            onTap: () => tap(i),
          ),
      ];

  for (final scale in const [1.0, 1.6, 2.0]) {
    testWidgets('$scale ölçekte taşma yok', (tester) async {
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.light(),
        home: MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(scale)),
          child: Scaffold(
            body: SingleChildScrollView(
              child: FmToolPills(tools: tools((_) {})),
            ),
          ),
        ),
      ));
      expect(tester.takeException(), isNull);
      expect(find.byKey(const ValueKey('tool-pill-tool3')), findsOneWidget);
    });
  }

  testWidgets('hapa dokununca araç açılır', (tester) async {
    var tapped = -1;
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(body: FmToolPills(tools: tools((i) => tapped = i))),
    ));
    await tester.tap(find.text('Araç 4'));
    await tester.pumpAndSettle();
    expect(tapped, 4);
  });
}
