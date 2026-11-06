import 'package:dosya_okuyucu/core/app_state.dart';
import 'package:dosya_okuyucu/screens/fm/transfer_screen.dart';
import 'package:dosya_okuyucu/services/fm/tool_usage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

/// Faz 2 birleşmeleri (2026-10-21): panodaki ayrı kapılar tek merkezlere
/// indi. Kapılar sessizce kaybolmasın, eski kullanım sayaçları yeni kapıya
/// taşınsın diye burada kilitli.
void main() {
  test('birleşen araçların sayacı yeni kapıya toplanır', () {
    final counts = {'ftp_server': 7, 'download': 2, 'vault': 4};
    ToolUsage.foldMergedForTest(counts);
    expect(counts, {'transfer': 9, 'vault': 4});
  });

  // 2026-10-29: Aktar = birleşik Yakındakiler ekranı. Gönder/Al sekmesi
  // yok. 2026-11-06: üç sekme — Hızlı aktar (cihazlar + QR) · Diğer yollar
  // · Geçmiş.
  testWidgets('Aktar sekmeli: Gönder/Al yok, diğer yollar ve geçmiş sekmede',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 4000);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ChangeNotifierProvider(
      create: (_) => AppState(),
      child: const MaterialApp(home: TransferScreen(services: false)),
    ));
    await tester.pump();
    expect(find.text('Aktar'), findsOneWidget);
    expect(find.text('Gönder'), findsNothing);
    expect(find.text('Al'), findsNothing);
    // 1. sekme: hızlı aktar + QR aynı sayfada.
    for (final label in ['Hızlı aktar', 'Dosya ekle', 'Klasör ekle', 'QR ile paylaş']) {
      expect(find.text(label), findsOneWidget, reason: label);
    }
    await tester.tap(find.byKey(const ValueKey('near-tab-other')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    for (final label in ['Bilgisayarla', 'Ağ depolama', 'İndirmeler']) {
      expect(find.text(label), findsOneWidget, reason: label);
    }
    await tester.tap(find.byKey(const ValueKey('near-tab-history')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('Son alınanlar'), findsOneWidget);
  });
}
