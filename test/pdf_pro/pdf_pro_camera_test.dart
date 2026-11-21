// PDF Pro Faz 59 m.2: kameradan görsel ekleme — tarayıcı sonucu okunur,
// vazgeçince hiçbir şey eklenmez (tarayıcı yerine sahte).
import 'dart:io';
import 'dart:typed_data';

import 'package:dosya_okuyucu/services/pdf/pro/pdf_pro_images.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  test('çekilen ilk kare okunur; vazgeçme / boş sonuç = null', () async {
    final tmp = Directory.systemTemp.createTempSync('pdf_pro_camera_test');
    addTearDown(() => tmp.deleteSync(recursive: true));
    final shot = File(p.join(tmp.path, 'kare.jpg'))
      ..writeAsBytesSync([0xFF, 0xD8, 1, 2, 3]);

    expect(
        await PdfProImages.fromCamera(scan: () async => [shot.path]),
        Uint8List.fromList([0xFF, 0xD8, 1, 2, 3]));
    expect(await PdfProImages.fromCamera(scan: () async => null), isNull);
    expect(await PdfProImages.fromCamera(scan: () async => const []), isNull);
  });
}
