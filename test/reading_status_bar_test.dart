import 'package:dosya_okuyucu/models/document.dart';
import 'package:dosya_okuyucu/widgets/office_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Ferrari H3.6 — sürükleyici okuma: çubuklar çekilince durum çubuğu da
/// gizlenir, tek dokunuşla geri gelir; içerik payı HİÇ değişmez (PDF düzeni
/// yeniden kurulup sayfa başına atlamasın).
void main() {
  testWidgets('durum çubuğu çubuklarla gizlenir, içerik payı sabit',
      (tester) async {
    final calls = <MethodCall>[];
    final messenger = tester.binding.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(SystemChannels.platform, (c) async {
      calls.add(c);
      return null;
    });
    addTearDown(
        () => messenger.setMockMethodCallHandler(SystemChannels.platform, null));
    final dpr = tester.view.devicePixelRatio;
    tester.view.padding = FakeViewPadding(top: 24 * dpr);
    addTearDown(tester.view.reset);

    final bars = ReadingBars(idle: Duration.zero);
    addTearDown(bars.dispose);
    EdgeInsets? insets;
    await tester.pumpWidget(MaterialApp(
      home: OfficeShell(
        kind: DocKind.pdf,
        title: 'belge',
        readingBars: bars,
        hideStatusBar: true,
        body: Builder(builder: (context) {
          insets = ReadingChrome.insetsOf(context);
          return const SizedBox.expand();
        }),
      ),
    ));
    await tester.pump();
    final top = insets!.top;
    expect(top, greaterThan(24));

    bool chrome(MethodCall c) => c.method.startsWith('SystemChrome.setEnabled');

    bars.hide();
    await tester.pump();
    expect(calls.where(chrome), isNotEmpty, reason: 'durum çubuğu gizlenir');

    // Sistem durum çubuğunu kaldırdı: pay 0'a inse de içerik yerinde.
    tester.view.padding = FakeViewPadding.zero;
    await tester.pumpAndSettle();
    expect(insets!.top, top);

    calls.clear();
    bars.show();
    await tester.pumpAndSettle();
    expect(calls.where(chrome).map((c) => c.arguments),
        contains('SystemUiMode.edgeToEdge'));
    tester.view.padding = FakeViewPadding(top: 24 * dpr);
    await tester.pumpAndSettle();
    expect(insets!.top, top);
  });

  testWidgets('tercih kapalıyken sistem kipine dokunulmaz', (tester) async {
    final calls = <MethodCall>[];
    final messenger = tester.binding.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(SystemChannels.platform, (c) async {
      calls.add(c);
      return null;
    });
    addTearDown(
        () => messenger.setMockMethodCallHandler(SystemChannels.platform, null));
    final bars = ReadingBars(idle: Duration.zero);
    addTearDown(bars.dispose);
    await tester.pumpWidget(MaterialApp(
      home: OfficeShell(
        kind: DocKind.pdf,
        title: 'belge',
        readingBars: bars,
        body: const SizedBox.expand(),
      ),
    ));
    bars.hide();
    await tester.pumpAndSettle();
    expect(calls.where((c) => c.method.startsWith('SystemChrome.setEnabled')),
        isEmpty);
  });
}
