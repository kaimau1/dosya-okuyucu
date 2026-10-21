import 'package:dosya_okuyucu/screens/fm/transfer_screen.dart';
import 'package:dosya_okuyucu/services/fm/tool_usage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Faz 2 birleşmeleri (2026-10-21): panodaki ayrı kapılar tek merkezlere
/// indi. Kapılar sessizce kaybolmasın, eski kullanım sayaçları yeni kapıya
/// taşınsın diye burada kilitli.
void main() {
  test('birleşen araçların sayacı yeni kapıya toplanır', () {
    final counts = {'ftp_server': 7, 'download': 2, 'vault': 4};
    ToolUsage.foldMergedForTest(counts);
    expect(counts, {'transfer': 9, 'vault': 4});
  });

  testWidgets('Aktar dört yolu tek ekranda gösterir', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: TransferScreen()));
    await tester.pump();
    for (final label in [
      'Bilgisayarla',
      'Telefonla',
      'Ağ depolama',
      'İndirmeler',
    ]) {
      expect(find.text(label), findsOneWidget, reason: label);
    }
  });
}
