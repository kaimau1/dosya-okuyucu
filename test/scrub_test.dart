import 'dart:io';

import 'package:dosya_okuyucu/services/crash_log.dart';
import 'package:dosya_okuyucu/services/diag_report.dart';
import 'package:dosya_okuyucu/services/log_scrub.dart';
import 'package:flutter_test/flutter_test.dart';

/// Güvenlik Faz G2.5: çökme kaydı ve tanı raporu sırları maskeler.
/// (Tüm değerler uydurma; anahtar biçimi parçalardan kurulur ki depo
/// taraması — denetim kural 9 — gerçek anahtar sanmasın.)
void main() {
  final fakeGoogleKey = 'AI' 'za' + 'x' * 35;

  test('Google API anahtarı maskelenir', () {
    final s = LogScrub.scrub('istek başarısız: anahtar $fakeGoogleKey geçersiz');
    expect(s, isNot(contains(fakeGoogleKey)));
    expect(s, contains('<anahtar>'));
  });

  test('Authorization ve x-goog-api-key satırı maskelenir', () {
    final s = LogScrub.scrub(
        'Authorization: Basic c2FodGU6cGFyb2xh\nx-goog-api-key: sahte-deger');
    expect(s, isNot(contains('c2FodGU6cGFyb2xh')));
    expect(s, isNot(contains('sahte-deger')));
    expect(s, contains('Authorization: <gizli>'));
  });

  test('URL içindeki kullanıcı:parola maskelenir', () {
    final s = LogScrub.scrub('bağlanılamadı ftp://kullanici:sahteparola@10.0.0.2/');
    expect(s, isNot(contains('sahteparola')));
    expect(s, isNot(contains('kullanici')));
  });

  test('key= / token= / kod= sorgu değerleri maskelenir', () {
    for (final name in ['key', 'token', 'kod', 'access_token']) {
      final s = LogScrub.scrub('GET models?$name=sahte-sir-123&pageSize=200');
      expect(s, isNot(contains('sahte-sir-123')), reason: name);
      expect(s, contains('$name=<gizli>'), reason: name);
      expect(s, contains('pageSize=200'), reason: name);
    }
  });

  test('tanı raporu aynı işlevi kullanır; yığın satırı korunur', () {
    expect(DiagReport.scrub('k=$fakeGoogleKey'), isNot(contains(fakeGoogleKey)));
    const frame = '#3 Foo.bar (package:dosya_okuyucu/services/x.dart:12:5)';
    expect(LogScrub.scrub(frame), frame);
  });

  test('çökme kaydı diske yazmadan önce temizler', () async {
    final dir = Directory.systemTemp.createTempSync('scrub_test');
    CrashLog.dirOverride = dir.path;
    addTearDown(() {
      CrashLog.dirOverride = null;
      if (dir.existsSync()) dir.deleteSync(recursive: true);
    });
    await CrashLog.record(
        StateError('https://u:sahteparola@h/x?key=sahte-sir-9 $fakeGoogleKey'),
        StackTrace.fromString('#0 a (package:dosya_okuyucu/a.dart:1:1)'),
        context: 'Authorization: Bearer sahte-belirtec');
    final raw = dir
        .listSync()
        .whereType<File>()
        .map((f) => f.readAsStringSync())
        .join();
    for (final secret in [
      'sahteparola',
      'sahte-sir-9',
      fakeGoogleKey,
      'sahte-belirtec',
    ]) {
      expect(raw, isNot(contains(secret)), reason: secret);
    }
    final records = await CrashLog.load();
    expect(records.single.stack, contains('package:dosya_okuyucu/a.dart'));
  });
}
