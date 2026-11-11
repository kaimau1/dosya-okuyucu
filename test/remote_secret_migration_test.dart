import 'dart:convert';
import 'dart:typed_data';

import 'package:dosya_okuyucu/core/app_state.dart';
import 'package:dosya_okuyucu/models/remote_connection.dart';
import 'package:dosya_okuyucu/services/key_vault.dart';
import 'package:dosya_okuyucu/services/remote_secrets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Güvenlik Faz G2.1 (B1): uzak sunucu parolaları Keystore'la sarılı ayrı
/// kayıtta; eski düz kayıt açılışta göç eder, parola KAYBOLMAZ.
/// (Test parolaları uydurma — gerçek sır yok.)
void main() {
  void fakeKeystore() {
    KeyVault.wrap = (p) async => Uint8List.fromList([0x4B, ...p.reversed]);
    KeyVault.unwrap = (b) async => b.isEmpty || b.first != 0x4B
        ? null
        : Uint8List.fromList(b.sublist(1).reversed.toList());
  }

  tearDown(() {
    KeyVault.reset();
    RemoteSecrets.lastPersistProtected = true;
  });

  String oldRecord({String id = 'r1', String password = 'sahte-parola-1'}) =>
      jsonEncode({
        'id': id,
        'name': 'Ev NAS',
        'protocol': 'smb',
        'host': '192.168.1.20',
        'port': 445,
        'user': 'kullanici',
        'password': password,
        'domain': '',
        'initialPath': '',
        'savePassword': true,
      });

  test('eski düz kayıt → sarılı kayıt; parola korunur, prefs\'te düz kalmaz',
      () async {
    fakeKeystore();
    SharedPreferences.setMockInitialValues({
      'fm_remote_connections': [oldRecord()],
    });
    final state = AppState();
    await state.init();
    expect(state.remotes.single.password, 'sahte-parola-1');
    expect(state.remotePasswordsUnprotected, isFalse);

    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList('fm_remote_connections')!;
    expect(list.single, isNot(contains('sahte-parola-1')));
    expect(jsonDecode(list.single), isNot(contains('password')));
    final sealed = prefs.getString('fm_remote_secrets');
    expect(sealed, isNotNull);
    expect(sealed, isNot(contains('sahte-parola-1')));

    // Yeniden açılış sarılı kayıttan okur.
    final again = AppState();
    await again.init();
    expect(again.remotes.single.password, 'sahte-parola-1');
  });

  test('yeni kayıt parolasız liste + sarılı sır olarak yazılır', () async {
    fakeKeystore();
    SharedPreferences.setMockInitialValues({});
    final state = AppState();
    await state.init();
    await state.saveRemote(const RemoteConnection(
      id: 'r2',
      name: 'Yedek',
      protocol: RemoteProtocol.sftp,
      host: 'nas.local',
      port: 22,
      user: 'u',
      password: 'sahte-parola-2',
    ));
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getStringList('fm_remote_connections')!.single,
        isNot(contains('sahte-parola-2')));
    final again = AppState();
    await again.init();
    expect(again.remotes.single.password, 'sahte-parola-2');

    // Silinince sır da kalkar.
    await again.removeRemote('r2');
    expect(prefs.getString('fm_remote_secrets'), isNull);
  });

  test('parolası kaydedilmeyen bağlantı hiçbir yere parola yazmaz', () async {
    fakeKeystore();
    SharedPreferences.setMockInitialValues({});
    final state = AppState();
    await state.init();
    await state.saveRemote(const RemoteConnection(
      id: 'r3',
      name: 'Geçici',
      protocol: RemoteProtocol.ftp,
      host: '10.0.0.5',
      port: 21,
      password: 'sahte-parola-3',
      savePassword: false,
    ));
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('fm_remote_secrets'), isNull);
    expect(prefs.getStringList('fm_remote_connections')!.single,
        isNot(contains('sahte-parola-3')));
  });

  test('Keystore yoksa düz yol sürer, parola kaybolmaz, uyarı açılır',
      () async {
    KeyVault.wrap = (_) async => null;
    SharedPreferences.setMockInitialValues({
      'fm_remote_connections': [oldRecord()],
    });
    final state = AppState();
    await state.init();
    expect(state.remotes.single.password, 'sahte-parola-1');
    expect(state.remotePasswordsUnprotected, isTrue);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('fm_remote_secrets'), isNull);
    final again = AppState();
    await again.init();
    expect(again.remotes.single.password, 'sahte-parola-1');
  });
}
