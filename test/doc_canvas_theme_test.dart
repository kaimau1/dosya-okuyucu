import 'dart:io';

import 'package:dosya_okuyucu/core/skin.dart';
import 'package:dosya_okuyucu/core/theme.dart';
import 'package:dosya_okuyucu/widgets/docx_view.dart';
import 'package:dosya_okuyucu/widgets/pdf_page_frame.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Belge kanvası temaya uyar (2026-11-02, KALANLAR A7.6 + A7.7): koyu temada
/// Word sayfasının çevresi açık griydi; kâğıt temasında sayfa kâğıt rengi +
/// ince çerçeve (Word) ve gölgesiz çerçeve (PDF).
void main() {
  SkinPalette pal(AppSkin s, Brightness b) => SkinPalette.of(s, b);

  test('koyu: kanvas temanın zemini, sayfa/çerçeve yok', () {
    final c = DocxCanvas.forSkin(
        AppSkin.clay, Brightness.dark, pal(AppSkin.clay, Brightness.dark));
    expect(c.background, pal(AppSkin.clay, Brightness.dark).bg);
    expect(c.page, isNull);
    expect(c.frame, isNull);
    expect(c.background, isNot(DocxCanvas.fallback.background));
  });

  test('gece ailesi açık parlaklıkta da koyu sayılır', () {
    final c = DocxCanvas.forSkin(AppSkin.night, Brightness.light,
        pal(AppSkin.night, Brightness.light));
    expect(c.page, isNull);
    expect(c.background, pal(AppSkin.night, Brightness.light).bg);
  });

  test('kâğıt açık: #FBF8F1 sayfa + #D2C8B4 çerçeve', () {
    final c = DocxCanvas.forSkin(AppSkin.clay, Brightness.light,
        pal(AppSkin.clay, Brightness.light));
    expect(c.page, const Color(0xFFFBF8F1));
    expect(c.frame, const Color(0xFFD2C8B4));
    expect(c.js, "setCanvas('${DocxCanvas.hex(c.background)}', "
        "'#fbf8f1', '#d2c8b4')");
  });

  test('öteki açık temalar eski Fluent görünümü', () {
    final c = DocxCanvas.forSkin(AppSkin.modern, Brightness.light,
        pal(AppSkin.modern, Brightness.light));
    expect(c, DocxCanvas.fallback);
    expect(c.js, "setCanvas('#f3f2f1', null, null)");
  });

  testWidgets('PDF: kâğıt açıkta gölgesiz çerçeve, koyuda varsayılan gölge',
      (tester) async {
    late PdfPageFrame light, dark;
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light(skin: AppSkin.clay),
      home: Builder(builder: (c) {
        light = PdfPageFrame.of(c);
        return const SizedBox();
      }),
    ));
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.dark(skin: AppSkin.clay),
      home: Builder(builder: (c) {
        dark = PdfPageFrame.of(c);
        return const SizedBox();
      }),
    ));
    await tester.pumpAndSettle(); // tema geçiş animasyonu bitsin
    // Kâğıt sayfa çerçevesi sıcak ailede (eski Kağıt → Kil, 2026-11-04).
    expect(light.enabled, isTrue);
    expect(light.shadowOrDefault, isNull);
    expect(dark.enabled, isFalse);
    expect(dark.shadowOrDefault, isNotNull);
  });

  test('viewer.html setCanvas tanımlı', () {
    // Dart'ın çağırdığı işlev WebView sayfasında var mı (adı kaymasın).
    final html = File('assets/word/viewer.html').readAsStringSync();
    expect(html, contains('window.setCanvas = function (bg, page, frame)'));
  });

  test('gece kipi (A9.2): js setNight ekler, setCanvas sıfırlar', () {
    const day = DocxCanvas(background: Color(0xFF101010));
    final night = day.withNight(true);
    expect(day.js, isNot(contains('setNight')));
    expect(night.js, endsWith('; setNight(true)'));
    expect(night, isNot(day));
    expect(night.withNight(false), day);
    final html = File('assets/word/viewer.html').readAsStringSync();
    expect(html, contains('window.setNight = function (on)'));
    expect(html, contains('window.setNight(false);'));
    // PDF kâğıt zemini: çarpma kipi (beyaz → kâğıt, siyah aynı).
    expect(PdfPageFrame.paperTint.blendMode, BlendMode.multiply);
  });
}
