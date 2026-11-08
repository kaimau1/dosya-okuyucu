import 'package:dosya_okuyucu/core/app_navigator.dart';
import 'package:dosya_okuyucu/core/l10n/app_strings.dart';
import 'package:dosya_okuyucu/core/snack.dart';
import 'package:dosya_okuyucu/widgets/pdf_save_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// PS3 (PDF Pro Faz 51): kayıttan hemen sonra editör kapanıyor; bildirimdeki
/// "Aç" eskiden kapanmış editörün `context`iyle açtığı için hiçbir şey
/// yapmıyordu. Artık kök gezginle açar; bildirimin gövdesine dokunmak da açar.
///
/// Dosya bilerek YOK: açma girişimi "bulunamadı" bildirimiyle görünür olur —
/// yani açıcı CANLI bir bağlamla çağrılmış demektir.
void main() {
  late BuildContext editorContext;

  Future<void> openEditorThenClose(WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(
      navigatorKey: navigatorKey,
      builder: (context, child) => ToastLayer(child: child!),
      home: const Scaffold(body: Text('görüntüleyici')),
    ));
    navigatorKey.currentState!.push(MaterialPageRoute<void>(
      builder: (ctx) {
        editorContext = ctx;
        return const Scaffold(body: Text('editör'));
      },
    ));
    await tester.pumpAndSettle();
    announcePdfSaved(editorContext, '/yok/belge (2).pdf', false);
    navigatorKey.currentState!.pop(); // editör kapandı
    // pumpAndSettle DEĞİL: bildirimin 8 sn'lik ömrü de "kare" sayılır.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(editorContext.mounted, isFalse);
  }

  String notFound() => AppStrings.current.t('open.not_found');

  testWidgets('"Aç" editör kapandıktan sonra da dosyayı açar', (tester) async {
    await openEditorThenClose(tester);
    await tester.tap(find.text(AppStrings.current.t('ps.open')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text(notFound()), findsOneWidget);
  });

  testWidgets('bildirimin gövdesine dokunmak da açar', (tester) async {
    await openEditorThenClose(tester);
    await tester.tap(find.textContaining('belge (2).pdf'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text(notFound()), findsOneWidget);
  });
}
