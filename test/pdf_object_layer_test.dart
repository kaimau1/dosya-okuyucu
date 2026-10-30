import 'package:dosya_okuyucu/services/pdf/pdf_form.dart';
import 'package:dosya_okuyucu/services/pdf/pdf_pending_objects.dart';
import 'package:dosya_okuyucu/widgets/pdf_object_layer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Faz 31: yerinde paragraf alanı, dört köşe tutamağı, bekleyen nesneler ve
/// sayfa üstünde form.
void main() {
  Widget host(Widget child) => MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 600,
            height: 800,
            child: Stack(children: [child]),
          ),
        ),
      );

  testWidgets('yerinde düzenleme alanı paragrafın kutusunda açılır',
      (tester) async {
    const rect = Rect.fromLTWH(40, 120, 300, 36);
    final ctrl = TextEditingController(text: 'Eski paragraf');
    await tester.pumpWidget(host(PdfInlineParagraphEditor(
        rect: rect, controller: ctrl, pointSize: 12)));
    final box = tester.getRect(find.byKey(const ValueKey('inline-paragraph-box')));
    // Kutu paragrafı 2 px payla tam örter.
    expect(box.left, closeTo(rect.left - 2, 0.01));
    expect(box.top, closeTo(rect.top - 2, 0.01));
    expect(box.width, closeTo(rect.width + 4, 0.01));
    expect(box.height, greaterThanOrEqualTo(rect.height + 4 - 0.01));
    final field =
        tester.getRect(find.byKey(const ValueKey('inline-paragraph-field')));
    expect(rect.inflate(2).contains(field.topLeft), isTrue);
    await tester.enterText(find.byType(TextField), 'Yeni paragraf');
    expect(ctrl.text, 'Yeni paragraf');
  });

  test('köşeden boyutlandırma: karşı köşe sabit, oran kilidi', () {
    const r = Rect.fromLTWH(100, 100, 200, 100);
    // Sol-üst köşe (0) içeri çekildi: sağ-alt köşe yerinde kalır.
    final a = PdfTransformBox.resizeFromCorner(r, 0, const Offset(20, 10));
    expect(a.bottomRight, r.bottomRight);
    expect(a.width, 180);
    expect(a.height, 90);
    // Oran kilidi: sağ-alt (2) yalnız yatay çekildi, yükseklik oranla gelir.
    final b = PdfTransformBox.resizeFromCorner(r, 2, const Offset(100, 0),
        keepAspect: true);
    expect(b.topLeft, r.topLeft);
    expect(b.width / b.height, closeTo(2, 1e-9));
    expect(b.width, 300);
    // En küçük kutunun altına inmez.
    final c = PdfTransformBox.resizeFromCorner(r, 1, const Offset(-1000, 1000),
        keepAspect: true);
    expect(c.width, greaterThanOrEqualTo(PdfTransformBox.minSize - 1e-9));
    expect(c.height, greaterThanOrEqualTo(PdfTransformBox.minSize - 1e-9));
    expect(c.bottomLeft, r.bottomLeft);
  });

  testWidgets('eklenen yazı kaydetmeden önce taşınır ve düzenlenir',
      (tester) async {
    var obj = const PdfPendingObject(
      id: 7,
      kind: PdfPendingKind.text,
      pageIndex: 0,
      box: Rect.fromLTWH(50, 50, 100, 20),
      text: 'Not',
    );
    int? selected;
    int? editing;
    final ctrl = TextEditingController();
    late StateSetter set;
    await tester.pumpWidget(host(StatefulBuilder(builder: (context, s) {
      set = s;
      return PdfPendingObjectLayer(
        objects: [obj],
        scale: 2,
        selectedId: selected,
        editingId: editing,
        editingController: ctrl,
        onSelect: (id) => s(() => selected = id),
        onChanged: (o) => s(() => obj = o),
        onEdit: (id) => s(() {
          editing = id;
          ctrl.text = obj.text;
        }),
      );
    })));
    // Dokun → seçilir.
    await tester.tap(find.text('Not'));
    await tester.pump();
    expect(selected, 7);
    // Gövdeden sürükle → taşınır (katman pikseli 2 = 1 PDF noktası).
    await tester.drag(find.byKey(const ValueKey('transform-body')),
        const Offset(40, 20));
    await tester.pump();
    // (Sürüklemenin ilk birkaç pikseli jest eşiğine gider.)
    expect(obj.box.left, greaterThan(55));
    expect(obj.box.top, greaterThan(52));
    // Köşeden büyüt → punto oranla büyür.
    await tester.drag(find.byKey(const ValueKey('transform-corner-2')),
        const Offset(200, 0));
    await tester.pump();
    expect(obj.box.width, greaterThan(100));
    expect(obj.fontSize, greaterThan(12));
    // Seçiliyken yeniden dokun → yerinde düzenleme alanı.
    await tester.tap(find.byKey(const ValueKey('transform-body')));
    await tester.pump();
    expect(editing, 7);
    expect(find.byKey(const ValueKey('pending-text-field')), findsOneWidget);
    set(() {});
  });

  testWidgets('form alanları sayfada çizilir, dokununca bildirilir',
      (tester) async {
    PdfFormFieldInfo? tapped;
    const fields = [
      PdfFormFieldInfo(
          name: 'Ad',
          kind: PdfFormFieldKind.text,
          value: '',
          page: 1,
          bounds: Rect.fromLTWH(100, 100, 150, 20)),
      PdfFormFieldInfo(
          name: 'Onay',
          kind: PdfFormFieldKind.checkbox,
          value: 'false',
          page: 1,
          bounds: Rect.fromLTWH(100, 140, 14, 14)),
    ];
    await tester.pumpWidget(host(PdfFormOverlay(
      fields: fields,
      scale: 1.5,
      values: const {'Ad': 'Ayşe', 'Onay': 'true'},
      onTapField: (f) => tapped = f,
    )));
    final r = tester.getRect(find.byKey(const ValueKey('form-field-Ad')));
    expect(r, const Rect.fromLTWH(150, 150, 225, 30));
    expect(find.text('Ayşe'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('form-field-Onay')));
    expect(tapped?.name, 'Onay');
  });
}
