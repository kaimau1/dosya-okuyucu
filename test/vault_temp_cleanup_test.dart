import 'dart:io';

import 'package:dosya_okuyucu/services/fm/secure_vault.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'support/temp_dir.dart';

/// **G2.8 artığı** (2026-11-12): kasadan açılmış düz kopyalar
/// (`<cache>/vault_open/`) süreç öldürülüp kilit çalışmadıysa bir sonraki
/// açılışta silinmeli. Hem temizliğin kendisi hem açılışta kuyruğa
/// eklendiği doğrulanır.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tmp;
  const channel = MethodChannel('plugins.flutter.io/path_provider');

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('vault_temp');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async => tmp.path);
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    removeTempDir(tmp);
  });

  test('clearTemp kalmış düz kopyaları siler, başka önbelleğe dokunmaz', () async {
    final open = Directory(p.join(tmp.path, 'vault_open'))..createSync();
    File(p.join(open.path, 'gizli.pdf')).writeAsStringSync('düz kopya');
    final other = File(p.join(tmp.path, 'baska.txt'))..writeAsStringSync('x');

    await SecureVault.clearTemp();

    expect(open.existsSync(), isFalse);
    expect(other.existsSync(), isTrue);
  });

  test('klasör yokken sessizce geçer', () async {
    await SecureVault.clearTemp();
    expect(Directory(p.join(tmp.path, 'vault_open')).existsSync(), isFalse);
  });

  test('açılışta temizlik kuyruğa ekleniyor (bekçi)', () {
    final src = File('lib/main.dart').readAsStringSync();
    expect(src, contains("StartupQueue.instance.add('vault-temp', SecureVault.clearTemp)"));
  });
}
