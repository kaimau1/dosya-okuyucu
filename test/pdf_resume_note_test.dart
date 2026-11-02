import 'package:dosya_okuyucu/widgets/pdf_resume_note.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// "N. sayfadan devam ediliyor" notu (2026-11-02): SnackBar yerine sayfanın
/// üstünde ince hap; "Baştan başla" geri dönüş verir, kendiliğinden çekilir.
void main() {
  Widget host({
    required VoidCallback onRestart,
    required VoidCallback onDismiss,
  }) =>
      MaterialApp(
        home: Scaffold(
          body: Stack(children: [
            PdfResumeNote(page: 42, onRestart: onRestart, onDismiss: onDismiss),
          ]),
        ),
      );

  testWidgets('sayfa numarasını gösterir, Baştan başla geri döndürür',
      (tester) async {
    var restarted = 0, dismissed = 0;
    await tester.pumpWidget(
        host(onRestart: () => restarted++, onDismiss: () => dismissed++));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.textContaining('42'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('pdf-resume-restart')));
    await tester.pump();
    expect(restarted, 1);
    expect(dismissed, 1);
  });

  testWidgets('dokunulmazsa kendiliğinden çekilir', (tester) async {
    var dismissed = 0;
    await tester.pumpWidget(host(onRestart: () {}, onDismiss: () => dismissed++));
    await tester.pump(const Duration(seconds: 6));
    await tester.pump(const Duration(milliseconds: 300));
    expect(dismissed, 1);
  });
}
