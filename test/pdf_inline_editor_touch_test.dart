import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdfrx/pdfrx.dart';

import 'package:dosya_okuyucu/widgets/pdf_inline_editor.dart';

/// **"İmleç zor hareket ediyor, tıklayınca orayı odaklamıyor"** — kullanıcı
/// 2026-08-30, PDF'te yerinde metin düzenlerken.
///
/// KÖK NEDEN: düzenleme kutusu belgenin kendi ölçüsündeydi. Gövde metni
/// %100 yakınlaştırmada 10-14 dp yüksekliğinde çiziliyor; yani dokunulabilir
/// hedef bir parmağın (Material 48 dp) dörtte biri kadardı. Satırın birkaç
/// piksel üstüne/altına gelen dokunuş `TextField`e HİÇ ulaşmıyor, altındaki
/// pdfrx katmanına düşüyordu — ekrana basılıyor, imleç kıpırdamıyordu.
///
/// Çözüm yazıyı büyütmek DEĞİL ("sanki o yazıya aitmiş gibi" ilkesi):
/// kutunun çevresine saydam bir dokunma payı kondu ve o paya gelen dokunuş
/// imleci dokunulan sütuna taşıyor.
void main() {
  // Sayfa 200x100 punto, ekranda 1:1. Satır: PDF'te y 60→50 (10 punto
  // yüksek), x 10→90. Ekran karşılığı: (10, 40) - (90, 50).
  const pageSize = Size(200, 100);
  const line = PdfRect(10, 60, 90, 50);

  late TextEditingController controller;
  late FocusNode focusNode;

  setUp(() {
    controller = TextEditingController(text: 'Merhaba dunya');
    focusNode = FocusNode();
  });

  tearDown(() {
    controller.dispose();
    focusNode.dispose();
  });

  Future<void> pump(WidgetTester tester) => tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: pageSize.width,
            height: pageSize.height,
            child: Stack(
              children: [
                PdfInlineEditor(
                  page: _FakePage(),
                  pageSize: pageSize,
                  rects: const [line],
                  original: 'Merhaba dunya',
                  controller: controller,
                  focusNode: focusNode,
                  onSubmit: () {},
                ),
              ],
            ),
          ),
        ),
      ));

  testWidgets('dokunma hedefi yazıdan yüksek (parmakla isabet edilebilir)',
      (tester) async {
    await pump(tester);
    // Yazının kendisi 10 dp; dokunma alanı en az 40 dp olmalı.
    final target = tester.getSize(find.byKey(PdfInlineEditor.padKey));
    expect(target.height, greaterThanOrEqualTo(40),
        reason: 'satır 10 dp; pay olmadan parmak isabet ettiremez');
    expect(target.width, greaterThan(80));
  });

  testWidgets('yazının BEYAZ kapağı büyümüyor (komşu satır örtülmesin)',
      (tester) async {
    await pump(tester);
    // Metin kutusu hâlâ özgün satırın tam yerinde: 40'tan başlıyor.
    final field = tester.getRect(find.byType(TextField));
    expect(field.top, closeTo(40, 0.5));
    expect(field.left, closeTo(10, 0.5));
  });

  testWidgets('payın içindeki dokunuş imleci O SÜTUNA taşır', (tester) async {
    await pump(tester);
    controller.selection = const TextSelection.collapsed(offset: 0);

    // Satırın hemen ÜSTÜNE (yazının dışına ama payın içine) dokun: eskiden
    // bu dokunuş kutuya hiç ulaşmıyordu.
    final target = tester.getRect(find.byKey(PdfInlineEditor.padKey));
    await tester.tapAt(Offset(60, target.top + 4));
    await tester.pump();

    expect(controller.selection.isCollapsed, isTrue);
    expect(controller.selection.baseOffset, greaterThan(0),
        reason: 'imleç dokunulan sütuna gitmeli, başta kalmamalı');
  });

  testWidgets('boş kutuda dokunuş imleci oynatmaz (çökmez)', (tester) async {
    controller.text = '';
    await pump(tester);
    final target = tester.getRect(find.byKey(PdfInlineEditor.padKey));
    await tester.tapAt(Offset(60, target.top + 4));
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(controller.selection.baseOffset, lessThanOrEqualTo(0));
  });

  group('klavye (2026-09-24)', keyboardGroup);
}

/// **"Klavye ilk basınca açılıyor, sonra açılmıyor; değişiklik yapılamıyor"**
/// — kullanıcı 2026-09-24. Klavye geri tuşuyla kapanınca odak kutuda
/// kalıyordu; kutuya dokunmak klavyeyi yeniden açmıyordu çünkü pdfrx'in
/// köprü katmanı (sayfa katmanlarının ÜSTÜNDE translucent bir tap
/// tanıyıcısı) dokunuşu kazanıyordu. Aşağıda o katman birebir taklit ediliyor.
void keyboardGroup() {
  const pageSize = Size(200, 100);
  const line = PdfRect(10, 60, 90, 50);

  Future<(TextEditingController, FocusNode, GlobalKey)> pumpWithLinkLayer(
      WidgetTester tester) async {
    final controller = TextEditingController(text: 'Merhaba dunya');
    final focusNode = FocusNode();
    final fieldKey = GlobalKey();
    addTearDown(controller.dispose);
    addTearDown(focusNode.dispose);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: pageSize.width,
          height: pageSize.height,
          child: Stack(
            children: [
              PdfInlineEditor(
                page: _FakePage(),
                pageSize: pageSize,
                rects: const [line],
                original: 'Merhaba dunya',
                controller: controller,
                focusNode: focusNode,
                fieldKey: fieldKey,
                onSubmit: () {},
              ),
              // pdfrx `linkHandlingOverlay`: tüm görüntüyü kaplayan,
              // translucent, onTapUp'lı GestureDetector — sayfa
              // katmanlarının ÜSTÜNDE.
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onTapUp: (_) {},
                ),
              ),
            ],
          ),
        ),
      ),
    ));
    return (controller, focusNode, fieldKey);
  }

  testWidgets('klavye kapandıktan sonra kutuya dokununca YENİDEN açılır',
      (tester) async {
    final (_, focusNode, fieldKey) = await pumpWithLinkLayer(tester);
    PdfInlineEditor.showKeyboard(fieldKey.currentContext, focusNode);
    await tester.pump();
    expect(focusNode.hasFocus, isTrue);
    expect(tester.testTextInput.isVisible, isTrue);

    // Android geri tuşu: klavye kapanır, odak kutuda kalır.
    tester.testTextInput.hide();
    await tester.pump();
    expect(tester.testTextInput.isVisible, isFalse);
    expect(focusNode.hasFocus, isTrue);

    await tester.tapAt(tester.getCenter(find.byType(TextField)));
    await tester.pump(const Duration(milliseconds: 400));
    expect(tester.testTextInput.isVisible, isTrue,
        reason: 'dokunuş köprü katmanına kaybedilse de klavye açılmalı');
  });

  testWidgets(
      'odak kutudayken showKeyboard klavyeyi yeniden gösterir '
      '(◀ ▶ / tümünü seç düğmeleri)', (tester) async {
    final (_, focusNode, fieldKey) = await pumpWithLinkLayer(tester);
    PdfInlineEditor.showKeyboard(fieldKey.currentContext, focusNode);
    await tester.pump();
    tester.testTextInput.hide();
    await tester.pump();

    PdfInlineEditor.showKeyboard(fieldKey.currentContext, focusNode);
    await tester.pump();
    expect(tester.testTextInput.isVisible, isTrue);
  });

  testWidgets('kutuya dokunuş imleci dokunulan harfe koyar', (tester) async {
    final (controller, focusNode, fieldKey) = await pumpWithLinkLayer(tester);
    PdfInlineEditor.showKeyboard(fieldKey.currentContext, focusNode);
    await tester.pump();
    controller.selection =
        TextSelection(baseOffset: 0, extentOffset: controller.text.length);

    final field = tester.getRect(find.byType(TextField));
    await tester.tapAt(Offset(field.left + field.width * 0.6, field.center.dy));
    await tester.pump(const Duration(milliseconds: 400));
    expect(controller.selection.isCollapsed, isTrue);
    expect(controller.selection.baseOffset, greaterThan(0));
    expect(controller.selection.baseOffset, lessThan(controller.text.length));
  });

  testWidgets('temanın çerçevesi/dolgusu kutuya SIZMAZ', (tester) async {
    // Tema: dolgulu + odakta kalın yuvarlak çerçeve (uygulamanın teması gibi).
    final controller = TextEditingController(text: 'Merhaba dunya');
    final focusNode = FocusNode();
    addTearDown(controller.dispose);
    addTearDown(focusNode.dispose);
    await tester.pumpWidget(MaterialApp(
      theme: ThemeData(
        inputDecorationTheme: const InputDecorationTheme(
          filled: true,
          fillColor: Colors.grey,
          focusedBorder: OutlineInputBorder(),
          enabledBorder: OutlineInputBorder(),
        ),
      ),
      home: Scaffold(
        body: SizedBox(
          width: pageSize.width,
          height: pageSize.height,
          child: Stack(children: [
            PdfInlineEditor(
              page: _FakePage(),
              pageSize: pageSize,
              rects: const [line],
              original: 'Merhaba dunya',
              controller: controller,
              focusNode: focusNode,
              onSubmit: () {},
            ),
          ]),
        ),
      ),
    ));
    focusNode.requestFocus();
    await tester.pump();
    final decorator =
        tester.widget<InputDecorator>(find.byType(InputDecorator));
    final d = decorator.decoration;
    expect(d.filled, isFalse);
    expect(d.focusedBorder, InputBorder.none);
    expect(d.enabledBorder, InputBorder.none);
  });
}

/// Yalnız [PdfInlineEditor]'ün kullandığı üyeler gerçek; kalanı çağrılırsa
/// test bilerek patlar (yanlışlıkla pdfium'a inen yol hemen görünsün).
class _FakeDoc implements PdfDocument {
  @override
  final String sourceName = 'test.pdf';

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('$invocation');
}

class _FakePage implements PdfPage {
  @override
  final PdfDocument document = _FakeDoc();

  @override
  int get pageNumber => 1;

  @override
  double get width => 200;

  @override
  double get height => 100;

  @override
  Size get size => const Size(200, 100);

  @override
  PdfPageRotation get rotation => PdfPageRotation.none;

  @override
  bool get isLoaded => true;

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('$invocation');
}
