import 'package:dosya_okuyucu/services/fm/smart_folder_prefs.dart';
import 'package:dosya_okuyucu/services/fm/smart_learn.dart';
import 'package:dosya_okuyucu/services/fm/smart_sort_taxonomy.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('SmartLearn.features', () {
    test('ekran görüntüsünün uygulaması, klasör ve uzantı', () {
      final f = SmartLearn.features(
          '/sdcard/DCIM/Screenshots/Screenshot_2026-11-18-19-24-47-101_com.whatsapp.jpg');
      expect(f, contains('a:com.whatsapp'));
      expect(f, contains('d:screenshots'));
      expect(f, contains('e:.jpg'));
      // Gürültü sözcükler ve sayılar özellik olmaz.
      expect(f.where((x) => x.startsWith('w:')), isEmpty);
    });

    test('addaki anlamlı sözcükler Türkçe katlamalı', () {
      final f = SmartLearn.features('/sdcard/Download/Fatura Detayı - Kasım 2026.pdf');
      expect(f, containsAll(['w:fatura', 'w:detayi', 'w:kasim', 'd:download']));
    });
  });

  group('SmartLearn.decide', () {
    final wa = SmartLearn.features(
        '/sdcard/DCIM/Screenshots/Screenshot_2026-11-01_com.whatsapp.jpg');
    final waNew = SmartLearn.features(
        '/sdcard/DCIM/Screenshots/Screenshot_2026-11-18_com.whatsapp.jpg');

    test('aynı uygulamanın ekran görüntüsünde aynı hata çevrilir', () {
      final items = [SmartCorrection('screenshot', 'screenshot_chat', wa, 1)];
      expect(SmartLearn.decide(waNew, 'screenshot', items, image: true),
          'screenshot_chat');
      // Model başka bir şey dediyse bu düzeltme oy vermez.
      expect(SmartLearn.decide(waNew, 'meme', items, image: true), isNull);
    });

    test('"doğruymuş" onayları yanlış genellemeyi frenler', () {
      final items = [
        SmartCorrection('screenshot', 'screenshot_chat', wa, 1),
        SmartCorrection('screenshot', 'screenshot', waNew, 2),
      ];
      expect(SmartLearn.decide(waNew, 'screenshot', items, image: true), isNull);
    });

    test('yalnız klasör + uzantı ortaksa tek düzeltme yetmez', () {
      final a = SmartLearn.features('/sdcard/Download/a1.pdf');
      final b = SmartLearn.features('/sdcard/Download/b2.pdf');
      final one = [SmartCorrection('receipt', 'bank', a, 1)];
      expect(SmartLearn.decide(b, 'receipt', one, image: false), isNull);
      final two = [
        SmartCorrection('receipt', 'bank', a, 1),
        SmartCorrection('receipt', 'bank', a, 2),
      ];
      expect(SmartLearn.decide(b, 'receipt', two, image: false), 'bank');
    });

    test('belgeye görsel kategorisi öğrenilmez', () {
      final pdf = SmartLearn.features('/sdcard/Download/gmail_bulten.pdf');
      final items = [
        SmartCorrection('email', 'screenshot', pdf, 1),
        SmartCorrection('email', 'screenshot', pdf, 2),
      ];
      expect(SmartLearn.decide(pdf, 'email', items, image: false), isNull);
    });
  });

  test('geri bildirim yalnız kimlik ve sayı taşır (dosya adı gitmez)', () {
    SmartLearn.debugReset([
      const SmartCorrection('screenshot', 'email', ['w:gizli_ad'], 1),
      const SmartCorrection('screenshot', 'email', ['w:gizli_ad'], 2),
    ]);
    final h = SmartLearn.hint(image: true);
    expect(h, contains('"screenshot" was wrong and should have been "email" (2x)'));
    expect(h, isNot(contains('gizli')));
    // Belge sorusuna görsel kategorili karışıklık girmez.
    expect(SmartLearn.hint(image: false), isEmpty);
    final q = SmartTaxonomy.questions(image: true, nowYear: 2026, learned: h);
    expect(q.first.instructions, endsWith(h));
    SmartLearn.debugReset();
  });

  test('akıllı klasör düzeni: kullanıcı sırası önce, sütun 2–4', () async {
    SharedPreferences.setMockInitialValues({});
    SmartFolderPrefs.debugReset();
    await SmartFolderPrefs.setOrder(['bank', 'invoice']);
    expect(SmartFolderPrefs.arrange(['invoice', 'health', 'bank']),
        ['bank', 'invoice', 'health']);
    await SmartFolderPrefs.setName('health', '  Hastane  ');
    expect(SmartFolderPrefs.nameOf('health'), 'Hastane');
    await SmartFolderPrefs.setName('health', '');
    expect(SmartFolderPrefs.nameOf('health'), isNull);
    await SmartFolderPrefs.setColumns(9);
    expect(SmartFolderPrefs.columns, SmartFolderPrefs.maxColumns);
    SmartFolderPrefs.debugReset();
  });

  test('panoda iki araç satırı: en çok sekiz araç', () {
    expect(DashboardTools.rows(List.generate(12, (i) => i)), hasLength(8));
    expect(DashboardTools.rows([1, 2, 3]), [1, 2, 3]);
  });
}
