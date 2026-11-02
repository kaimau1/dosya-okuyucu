// Play derlemesi izin varyantı (2026-11-02): `ci/play_variant.py`.
// Play AAB'sinden QUERY_ALL_PACKAGES (ve kararla başkaları) çıkarılır;
// GitHub APK'sı değişmez. Betik python3 ister — yoksa test atlanır.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  final hasPython = () {
    try {
      return Process.runSync('python3', ['--version']).exitCode == 0;
    } on ProcessException {
      return false;
    }
  }();

  late Directory tmp;
  setUp(() => tmp = Directory.systemTemp.createTempSync('play_variant'));
  tearDown(() => tmp.deleteSync(recursive: true));

  ProcessResult run(List<String> args, {Map<String, String>? env}) =>
      Process.runSync('python3', ['ci/play_variant.py', ...args],
          environment: env);

  test('apply: remove düğümü + LAUNCHER sorgusu; ikinci kez değişmez', () {
    final m = File(p.join(tmp.path, 'AndroidManifest.xml'))
      ..writeAsStringSync(File('ci/AndroidManifest.xml').readAsStringSync());
    final before = m.readAsStringSync();
    expect(run(['apply', m.path]).exitCode, 0);
    final after = m.readAsStringSync();
    expect(after, contains('android:name="android.permission.QUERY_ALL_PACKAGES" '
        'tools:node="remove"'));
    expect(after, contains('android.intent.category.LAUNCHER'));
    // Özgün izinler yerinde.
    expect(after, contains('android.permission.MANAGE_EXTERNAL_STORAGE'));
    expect(after.length, greaterThan(before.length));
    expect(run(['apply', m.path]).exitCode, 0);
    expect(m.readAsStringSync(), after, reason: 'idempotent');
  }, skip: hasPython ? false : 'python3 yok');

  test('DOSYA_PLAY_REMOVE: doğrudan bildirilen izin silinir, remove yazılır', () {
    final m = File(p.join(tmp.path, 'AndroidManifest.xml'))
      ..writeAsStringSync(File('ci/AndroidManifest.xml').readAsStringSync());
    final r = run(['apply', m.path], env: {
      'DOSYA_PLAY_REMOVE': 'QUERY_ALL_PACKAGES,REQUEST_INSTALL_PACKAGES',
    });
    expect(r.exitCode, 0, reason: '${r.stderr}');
    final t = m.readAsStringSync();
    expect(
        RegExp(r'android\.permission\.REQUEST_INSTALL_PACKAGES').allMatches(t),
        hasLength(1));
    expect(t, contains('REQUEST_INSTALL_PACKAGES" tools:node="remove"'));
  }, skip: hasPython ? false : 'python3 yok');

  test('verify: izin kalırsa düşer, yoksa geçer; geçersiz ad reddedilir', () {
    final bad = File(p.join(tmp.path, 'bad.xml'))
      ..writeAsStringSync('<uses-permission '
          'android:name="android.permission.QUERY_ALL_PACKAGES"/>');
    final good = File(p.join(tmp.path, 'good.xml'))
      ..writeAsStringSync('<uses-permission '
          'android:name="android.permission.INTERNET"/>');
    expect(run(['verify', bad.path]).exitCode, isNot(0));
    expect(run(['verify', good.path]).exitCode, 0);
    expect(run(['verify']).exitCode, isNot(0), reason: 'dosya yoksa düşmeli');
    expect(
        run(['verify', good.path], env: {'DOSYA_PLAY_REMOVE': 'x; rm'})
            .exitCode,
        isNot(0));
  }, skip: hasPython ? false : 'python3 yok');
}
