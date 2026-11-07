// İzin sadeliği bekçisi (2026-11-07, aşama 1).
//
// Play yorumlarındaki başlıca şikâyet "izin yağmuru": açılışta izin
// penceresi ve bir ret sonrası art arda yeni pencereler. Bu dosya kaynakları
// tarar; kural bozulursa CI kırılır.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _src(String path) => File(path).readAsStringSync();

/// `//` yorum satırlarını atar (belgelerde eski davranış anlatılabilir).
String _code(String path) => _src(path)
    .split('\n')
    .where((l) => !l.trimLeft().startsWith('//'))
    .join('\n');

void main() {
  test('açılışta bildirim izni istenmez (NotificationHub.init)', () {
    expect(_code('lib/services/fm/notification_hub.dart'),
        isNot(contains('requestNotificationsPermission')));
  });

  test('tüm dosyalar reddedilince medya izinleri zincirle sorulmaz', () {
    final code = _code('lib/services/fm/storage_permission.dart');
    for (final p in ['Permission.photos', 'Permission.videos', 'Permission.audio']) {
      expect(code, isNot(contains(p)), reason: p);
    }
    // Her yolda en çok bir `.request()`: Android ≤10 klasik, 11+ tüm dosyalar.
    expect(RegExp(r'\.request\(\)').allMatches(code).length, 2);
  });

  test('main() açılışta izin penceresi açmaz', () {
    final code = _code('lib/main.dart');
    expect(code, isNot(contains('.request(')));
    expect(code, isNot(contains('requestNotificationsPermission')));
  });

  test('ham izin isteği yalnız onaylı, bağlamsal yerlerde', () {
    // Yeni bir `Permission.x.request()` eklenirse önce bağlamda (özelliğe
    // dokununca) istendiğinden emin ol, sonra buraya ekle.
    const allowed = {
      'lib/services/fm/storage_permission.dart', // pano/gezgin "İzin ver"
      'lib/widgets/permission_gate.dart', // ortak kapı + "İzin ver" düğmeleri
      'lib/services/fm/remote/qr_transfer.dart', // QR okut'a basınca kamera
      'lib/services/fm/remote/ble_nearby.dart', // Hızlı aktar açılınca
      'lib/screens/editors/slides/pro.dart', // anlatım kaydına basınca
    };
    final raw = RegExp(r'Permission\.\w+\.request\(\)|\]\.request\(\)|perms?\.request\(\)');
    final offenders = <String>[];
    for (final f in Directory('lib').listSync(recursive: true)) {
      if (f is! File || !f.path.endsWith('.dart')) continue;
      final path = f.path.replaceAll('\\', '/');
      if (allowed.contains(path)) continue;
      if (raw.hasMatch(_code(path))) offenders.add(path);
    }
    expect(offenders, isEmpty);
  });
}
