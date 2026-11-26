import 'dart:io';

import 'package:dosya_okuyucu/core/app_icons.dart';
import 'package:dosya_okuyucu/screens/pdf_form_screen.dart';
import 'package:dosya_okuyucu/services/pdf_digital_sign.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'support/temp_dir.dart';

/// Form + İmza + Dijital İmza tek yüzeyinin widget testleri (P18 — Faz 61).
void main() {
  late Directory dir;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('pdf_form_screen');
  });

  tearDown(() => removeTempDir(dir));

  String writeForm({bool withFields = true, bool richTypes = false}) {
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
      doc.form.fields.add(PdfSignatureField(page, 'Imza',
          bounds: const Rect.fromLTWH(0, 100, 150, 40)));
      if (richTypes) {
        doc.form.fields.add(PdfTextBoxField(
            page, 'Notlar', const Rect.fromLTWH(0, 150, 200, 50),
            multiline: true));
        doc.form.fields.add(PdfTextBoxField(
            page, 'DogumTarihi', const Rect.fromLTWH(0, 210, 150, 20)));
        final radio = PdfRadioButtonListField(page, 'Plan');
        radio.items.add(PdfRadioButtonListItem(
            'Bireysel', const Rect.fromLTWH(0, 240, 16, 16)));
        radio.items.add(PdfRadioButtonListItem(
            'Kurumsal', const Rect.fromLTWH(60, 240, 16, 16)));
        doc.form.fields.add(radio);
        final list = PdfListBoxField(
            page, 'Dil', const Rect.fromLTWH(0, 270, 200, 40));
        list.items.add(PdfListFieldItem('Türkçe', 'Türkçe'));
        list.items.add(PdfListFieldItem('English', 'English'));
        doc.form.fields.add(list);
      }
    }
    final path =
        '${dir.path}/form${withFields ? (richTypes ? '_tum' : '') : '_bos'}.pdf';
    File(path).writeAsBytesSync(doc.saveSync());
    doc.dispose();
    return path;
  }

  /// `runAsync`: ekran dosyayı GERÇEKTEN okuyor (ve alanları izolatta
  /// çözüyor). Sahte saat zonunda `File.readAsBytes` hiç tamamlanmaz — bu
  /// tuzak daha önce yarım saat kaybettirmişti (bkz. HAFIZA 2026-07-25 §F).
  Future<void> pump(WidgetTester tester, String path,
      {PdfFormTab initialTab = PdfFormTab.form}) async {
    await tester.runAsync(() async {
      await tester.pumpWidget(
        MaterialApp(home: PdfFormScreen(path: path, initialTab: initialTab)),
      );
      await Future<void>.delayed(const Duration(milliseconds: 350));
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
    expect(find.byIcon(AppIcons.lock), findsOneWidget);
    // İmza alanı kilitli değil, aynı ekranda imzalanır (P18 tek ekran).
    expect(find.text('İmzalamak için dokunun'), findsOneWidget);
    // Kaydet çubuğu var (doldurulabilir alan olduğu için).
    expect(find.text('Doldur ve kaydet'), findsOneWidget);
    // Kilitleme varsayılan KAPALI (geri alınamaz bir iş).
    final flatten = tester.widget<SwitchListTile>(find.byType(SwitchListTile));
    expect(flatten.value, isFalse);
  });

  testWidgets('çok satır, tarih seçici, radyo yongaları ve liste çizilir',
      (tester) async {
    await pump(tester, writeForm(richTypes: true));

    expect(find.byKey(const ValueKey('pf-date-DogumTarihi')), findsOneWidget);
    expect(find.byType(ChoiceChip), findsNWidgets(2));
    expect(find.text('Bireysel'), findsOneWidget);
    expect(find.text('Kurumsal'), findsOneWidget);
    expect(find.text('Dil'), findsOneWidget);
  });

  testWidgets('form alanı olmayan belgede yol gösterilir ve İmza sekmesine geçilir',
      (tester) async {
    await pump(tester, writeForm(withFields: false));

    expect(find.textContaining('doldurulabilir form alanı taşımıyor'),
        findsOneWidget);
    // Kaydet çubuğu ÇIKMAZ: basılacak bir şey yok.
    expect(find.text('Doldur ve kaydet'), findsNothing);
    // Tek yüzey: İmza sekmesine tek dokunuşla geçiş düğmesi var.
    expect(find.byKey(const ValueKey('pf-go-sign')), findsOneWidget);
  });

  testWidgets('dijital imzalı belgede uyarı ve doğrulama kartı gösterilir',
      (tester) async {
    final path = '${dir.path}/imzali.pdf';
    await tester.runAsync(() async {
      final doc = PdfDocument();
      doc.documentInformation.title = 'Sozlesme';
      doc.pages.add();
      final raw = doc.saveSync();
      doc.dispose();
      final id = PdfDigitalSign.createIdentity('Ayşe Deneme', bits: 1024);
      final signed = await PdfDigitalSign.signWithIdentity(
        raw,
        identity: id,
        request: DigitalSignRequest(
          pageIndex: 0,
          bounds: PdfDigitalSign.defaultBounds(595, 842),
          signerName: id.name,
          signedAt: DateTime(2026, 11, 26, 10, 0),
          reason: 'Onay',
        ),
      );
      File(path).writeAsBytesSync(signed);
    });

    await pump(tester, path, initialTab: PdfFormTab.form);
    // İmzalı belge uyarısı Form sekmesinde görünür.
    expect(find.byKey(const ValueKey('pf-signed-warn')), findsOneWidget);

    // Dijital imza sekmesine geç → doğrulama kartında geçerli imza görünür.
    await tester.tap(find.text('Dijital imza'));
    await tester.pump();
    expect(find.text('Ayşe Deneme'), findsOneWidget);
    expect(find.byIcon(AppIcons.verified), findsOneWidget);
    expect(find.byKey(const ValueKey('pf-dsig-submit')), findsOneWidget);
  });
}
