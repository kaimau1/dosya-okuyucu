import 'dart:io';

import 'package:dosya_okuyucu/core/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// **Niye bu test var (kullanıcı 2026-08-29, işaretli ekran görüntüsü: *"video
/// ve görsellerde dosya adı zor görülüyor"*):**
///
/// Video oynatıcının üst çubuğu `AppBar(foregroundColor: Colors.white)`
/// veriyordu ve simgeler beyaz çiziliyordu — ama **başlık değil.** Flutter'da
/// `foregroundColor` yalnız `titleTextStyle` RENKSİZ olduğunda devreye girer;
/// `AppTheme` ise `appBarTheme.titleTextStyle: titleLarge` veriyor ve o stil
/// Material tipografisinden gelen KOYU rengi taşıyor. Sonuç: siyah zemin
/// üzerine neredeyse siyah dosya adı (kullanıcının ekran görüntüsünde ölçülen
/// piksel: `#1D1B20`).
///
/// Bu tuzak sessiz: kod "beyaz" diyor, ekran koyu çiziyor ve hiçbir test
/// kırılmıyordu. Buradaki üç kontrol onu kapalı tutuyor.
void main() {
  test('TUZAK: temanın çubuk başlığı stili KOYU bir renk taşır', () {
    final style = AppTheme.light().appBarTheme.titleTextStyle;
    expect(style, isNotNull,
        reason: 'stil null olsaydı foregroundColor zaten yeterdi');
    expect(style!.color, isNotNull,
        reason: 'renk taşıyan stil `foregroundColor: Colors.white`i EZER — '
            'OverlayBar tam bu yüzden var');
    expect(style.color, isNot(Colors.white));
  });

  testWidgets('OverlayBar.title koyu zeminde BEYAZ çizer', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light(),
      home: Builder(
        builder: (context) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            foregroundColor: Colors.white,
            title: Text('AHBS_Egitim_Videosu_1080.mp4',
                style: OverlayBar.title(context)),
          ),
        ),
      ),
    ));

    final painted = tester.firstWidget<RichText>(find.descendant(
      of: find.text('AHBS_Egitim_Videosu_1080.mp4'),
      matching: find.byType(RichText),
    ));
    expect(painted.text.style?.color, Colors.white);
    // Parlak bir video karesinin üstünde de okunsun diye gölge şart.
    expect(painted.text.style?.shadows, isNotEmpty);
  });

  testWidgets('foregroundColor TEK BAŞINA başlığı beyaz YAPMAZ (regresyon)',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
          title: const Text('okunmayan ad'),
        ),
      ),
    ));
    final painted = tester.firstWidget<RichText>(find.descendant(
      of: find.text('okunmayan ad'),
      matching: find.byType(RichText),
    ));
    expect(painted.text.style?.color, isNot(Colors.white),
        reason: 'bu satır kırmızıya dönerse Flutter davranışı değişmiş '
            'demektir; OverlayBar hâlâ zararsız ama gerekçesi gözden '
            'geçirilmeli');
  });

  test('koyu zeminli çubukların HEPSİ başlık stilini OverlayBar\'dan alır', () {
    // Kaynak taraması: yeni bir koyu çubuk eklenirse aynı tuzağa sessizce
    // düşülmesin. `foregroundColor: Colors.white` yazan her dosya, aynı
    // dosyada `OverlayBar` da kullanmalı.
    final offenders = <String>[];
    for (final file in Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))) {
      // Yorum satırları elenir: `OverlayBar`ın kendi tanımı (theme.dart) bu
      // deseni AÇIKLAMA olarak yazıyor, kod olarak değil.
      final source = file
          .readAsLinesSync()
          .where((l) => !l.trimLeft().startsWith('//'))
          .join('\n');
      if (!source.contains('foregroundColor: Colors.white')) continue;
      if (source.contains('OverlayBar.')) continue;
      offenders.add(file.path);
    }
    expect(offenders, isEmpty,
        reason: 'Bu dosyalarda beyaz zorlanan bir çubuk var ama başlık '
            'stili temadan (KOYU) geliyor:\n${offenders.join('\n')}');
  });
}
