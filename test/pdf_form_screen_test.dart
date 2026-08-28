import 'dart:io';

import 'package:dosya_okuyucu/screens/pdf_form_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'support/temp_dir.dart';

/// Form doldurma ekranının duman testi: alanlar türlerine göre çiziliyor mu,
/// salt-okunur alan kilitli görünüyor mu, formu olmayan belgede ekran çıkmaz
/// sokak mı bırakıyor.
void main() {
  late Directory dir;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('pdf_form_screen');
  });

  tearDown(() => removeTempDir(dir));

  String writeForm({bool withFields = true}) {
    final doc = PdfDocument();
    final page = doc.pages.add();
    if (withFields) {
      doc.form.fields.add(
          PdfTextBoxField(page, 'AdSoyad', const Rect.fromLTWH(0, 0, 200, 20)));
      doc.form.fields.add(
          PdfCheckBoxField(page, 'Onay', const Rect.fromLTWH(0, 30, 20, 20)));
      final locked = PdfTextBoxField(
          page, 'Kilitli', const Rect.fromLTWH(0, 60, 200, 20))
        ..text = 'sabit'
        ..readOnly = true;
      doc.form.fields.add(locked);
    }
    final path = '${dir.path}/form${withFields ? '' : '_bos'}.pdf';
    File(path).writeAsBytesSync(doc.saveSync());
    doc.dispose();
    return path;
  }

  /// `runAsync`: ekran dosyayı GERÇEKTEN okuyor (ve alanları izolatta
  /// çözüyor). Sahte saat zonunda `File.readAsBytes` hiç tamamlanmaz — bu
  /// tuzak daha önce yarım saat kaybettirmişti (bkz. HAFIZA 2026-07-25 §F).
  Future<void> pump(WidgetTester tester, String path) async {
    await tester.runAsync(() async {
      await tester.pumpWidget(MaterialApp(home: PdfFormScreen(path: path)));
      await Future<void>.delayed(const Duration(milliseconds: 300));
      await tester.pump();
    });
    await tester.pump();
  }

  testWidgets('alanlar türlerine göre çizilir, kilitli alan kilitli görünür',
      (tester) async {
    await pump(tester, writeForm());

    expect(find.text('AdSoyad'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
    expect(find.byType(CheckboxListTile), findsOneWidget);
    // Salt-okunur alan düzenlenebilir olarak DEĞİL, kilit simgesiyle çizilir.
    expect(find.byIcon(Icons.lock_outline), findsOneWidget);
    // Kaydet çubuğu var (doldurulabilir alan olduğu için).
    expect(find.text('Doldur ve kaydet'), findsOneWidget);
    // Kilitleme varsayılan KAPALI (geri alınamaz bir iş).
    final flatten = tester.widget<SwitchListTile>(find.byType(SwitchListTile));
    expect(flatten.value, isFalse);
  });

  testWidgets('form alanı olmayan belgede yol gösterilir', (tester) async {
    await pump(tester, writeForm(withFields: false));

    expect(find.textContaining('doldurulabilir form alanı taşımıyor'),
        findsOneWidget);
    // Kaydet çubuğu ÇIKMAZ: basılacak bir şey yok.
    expect(find.text('Doldur ve kaydet'), findsNothing);
  });
}
