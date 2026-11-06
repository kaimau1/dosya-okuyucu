import 'dart:io';

import 'package:dosya_okuyucu/screens/settings/crash_log_screen.dart';
import 'package:dosya_okuyucu/services/crash_log.dart';
import 'package:dosya_okuyucu/services/diag_report.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Faz 42 / 3·7 (A8): çökme günlüğü → "Bildir" akışı ve kullanıcı onaylı
/// anonim özet (çökme/ANR/bellek öldürmesi + kare dağılımı). KVKK: kişisel
/// parçalar maskelenir.
void main() {
  late Directory dir;
  setUp(() {
    dir = Directory.systemTemp.createTempSync('diag');
    CrashLog.dirOverride = dir.path;
    FrameStats.dirOverride = dir.path;
    SharedPreferences.setMockInitialValues({});
    FrameStats.instance.counts.fillRange(0, FrameStats.instance.counts.length, 0);
  });
  tearDown(() {
    CrashLog.dirOverride = null;
    FrameStats.dirOverride = null;
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });

  group('scrub (KVKK)', () {
    test('yol, dosya adı, e-posta, URI, uzun sayı maskelenir', () {
      final s = DiagReport.scrub(
          "PathNotFoundException: path = '/storage/emulated/0/Download/Ahmet Yılmaz CV.pdf' "
          'TC 12345678901 ali@ornek.com content://com.android.providers/x/1 '
          'rapor.docx /data/user/0/app/cache/x');
      expect(s, isNot(contains('Yılmaz')));
      expect(s, isNot(contains('12345678901')));
      expect(s, isNot(contains('ali@')));
      expect(s, isNot(contains('content://')));
      expect(s, isNot(contains('rapor')));
      expect(s, isNot(contains('/data/user')));
      expect(s, contains('<yol>'));
      expect(s, contains('<n>'));
    });

    test('yığın satırı (package:) korunur — hatanın yeri okunur kalır', () {
      const frame = '#3 Foo.bar (package:dosya_okuyucu/services/x.dart:12:5)';
      expect(DiagReport.scrub(frame), frame);
    });
  });

  group('FrameStats', () {
    test('kovalar, yüzdelik ve yavaş oran', () {
      final f = FrameStats.instance;
      for (var i = 0; i < 90; i++) {
        f.addSample(6);
      }
      for (var i = 0; i < 9; i++) {
        f.addSample(30);
      }
      f.addSample(140);
      expect(f.total, 100);
      expect(f.percentile(.5), 8);
      expect(f.percentile(.99), 33);
      expect(f.percentile(1), 101);
      expect(f.slowPercent(), closeTo(10, 0.01));
      expect(f.slowPercent(50), closeTo(1, 0.01));
    });
  });

  test('özet: ANR/bellek/çökme sayıları, yinelenen hata tek satır', () {
    final now = DateTime(2026, 11, 6);
    final records = [
      CrashRecord(time: now, kind: 'exit', error: 'Process exit: ANR input', stack: '', count: 2),
      CrashRecord(time: now, kind: 'exit', error: 'Process exit: LOW_MEMORY', stack: ''),
      CrashRecord(
          time: now,
          kind: 'flutter',
          error: "FileSystemException: '/storage/emulated/0/gizli.pdf'",
          stack: '#0 a (package:dosya_okuyucu/x.dart:1)\n#1 b',
          version: '1.1.3'),
      CrashRecord(
          time: now,
          kind: 'flutter',
          error: "FileSystemException: '/storage/emulated/0/gizli.pdf'",
          stack: ''),
    ];
    FrameStats.instance.addSample(60);
    final text = DiagReport.build(
        records: records,
        frames: FrameStats.instance,
        tier: 'mid',
        perfMode: 'auto');
    expect(text, contains('ANR: 2'));
    expect(text, contains('bellek öldürmesi: 1'));
    expect(text, contains('kare: n=1'));
    expect(text, isNot(contains('gizli')));
    expect(RegExp(r'FileSystemException').allMatches(text).length, 1);
  });

  testWidgets('Hata kayıtları → Bildir: önizleme + onay levhası', (tester) async {
    await tester.runAsync(() => CrashLog.record(StateError('bozuk'), null));
    await tester.pumpWidget(const MaterialApp(home: CrashLogScreen()));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('crash-report')));
    // Özet dosyadan okunur (gerçek G/Ç) → runAsync; levha açılış animasyonu
    // için sabit adımlar (ekranda yükleme göstergesi varken pumpAndSettle
    // hiç durulmaz).
    for (var i = 0; i < 6; i++) {
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 60)));
      await tester.pump(const Duration(milliseconds: 200));
    }
    expect(find.byKey(const ValueKey('dg-preview')), findsOneWidget);
    expect(find.byKey(const ValueKey('dg-send')), findsOneWidget);
    final preview =
        tester.widget<SelectableText>(find.byKey(const ValueKey('dg-preview')));
    expect(preview.data, contains('Bad state: bozuk'));
    // Kare ölçümü varsayılan KAPALI (anayasa: açık rıza).
    final sw = tester.widget<SwitchListTile>(find.byKey(const ValueKey('dg-frames')));
    expect(sw.value, isFalse);
  });
}
