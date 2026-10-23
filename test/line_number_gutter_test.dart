import 'package:dosya_okuyucu/screens/viewer_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Faz 20 / TX1 — satır numaraları "1, 2, 3" yazmalı, "$i" değil.
void main() {
  testWidgets('satır numarası şeridi gerçek numaraları yazar', (t) async {
    await t.pumpWidget(const MaterialApp(
        home: Scaffold(body: LineNumberGutter(count: 3, fontSize: 14))));
    expect(find.text('1'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
    expect(find.text(r'$i'), findsNothing);
  });
}
