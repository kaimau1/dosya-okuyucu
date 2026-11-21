// B9b — Word yorum balonu: tablette kenar sütununda (metin daralır),
// telefonda paragraf altında; yorumsuz belgede sütun yok.
import 'package:dosya_okuyucu/services/blank_docs.dart';
import 'package:dosya_okuyucu/services/docx/docx_document.dart';
import 'package:dosya_okuyucu/widgets/docx_editor/docx_edit_controller.dart';
import 'package:dosya_okuyucu/widgets/docx_editor/docx_editor_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

DocxEditController _doc({required bool comment}) {
  final c = DocxEditController(DocxDocument.parse(BlankDocs.blankDocx()));
  c.select(const DocPos(0, 0), const DocPos(0, 0));
  c.insertText('Kenar sütunu deneme paragrafı');
  if (comment) {
    c.select(const DocPos(0, 0), const DocPos(0, 5));
    expect(c.addComment('Buna bak', 'A'), isTrue);
  }
  return c;
}

Future<void> _pump(WidgetTester t, DocxEditController c, Size size) async {
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  await t.pumpWidget(MaterialApp(
      home: Scaffold(body: DocxEditorView(controller: c, spellcheck: false))));
  await t.pump();
}

Finder _keyed(String prefix) => find.byWidgetPredicate((w) {
      final k = w.key;
      return k is ValueKey<String> && k.value.startsWith(prefix);
    });

final _rail = _keyed('docx-rail-');
Finder _balloon() => _keyed('docx-balloon-');

void main() {
  testWidgets('tablet: balon kenar sütununda, metnin yanında', (t) async {
    await _pump(t, _doc(comment: true), const Size(1200, 800));
    expect(_rail, findsWidgets);
    expect(_balloon(), findsOneWidget);
    expect(find.descendant(of: _rail, matching: _balloon()), findsOneWidget);
    // Yan yana: balon metnin bittiği yerden sonra başlar.
    final text = t.getRect(find.byType(RichText).first);
    expect(t.getRect(_balloon()).left, greaterThan(text.right - 1));
  });

  testWidgets('telefon: sütun yok, balon paragraf altında', (t) async {
    await _pump(t, _doc(comment: true), const Size(400, 800));
    expect(_rail, findsNothing);
    expect(_balloon(), findsOneWidget);
    final text = t.getRect(find.byType(RichText).first);
    expect(t.getRect(_balloon()).top, greaterThan(text.bottom - 1));
  });

  testWidgets('tablet + yorumsuz belge: sütun yok', (t) async {
    await _pump(t, _doc(comment: false), const Size(1200, 800));
    expect(_rail, findsNothing);
    expect(_balloon(), findsNothing);
  });
}
