import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:dosya_okuyucu/core/app_state.dart';
import 'package:dosya_okuyucu/models/fs_entry.dart';
import 'package:dosya_okuyucu/widgets/fm/fm_entry_icon.dart';
import 'package:dosya_okuyucu/widgets/fm/fm_file_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;

import 'support/temp_dir.dart';

/// **Niye bu test var (2026-08-17 donma bulgusu):** galeri, Flutter'ın kendi
/// [FileImage]'ını kullanıyordu; o dosyayı `readAsBytes()` ile okuyor, yani
/// her fotoğrafın tam boyutlu JPEG'i önce Dart yığınına kopyalanıyordu.
/// 6476 fotoğraflı bir telefonda bu, tek kaydırmada yüzlerce MB geçici
/// ayırma demek — çöp toplayıcı ana izleği durduruyor (donma) ve bellek
/// baskısı altında bazı hücreler hiç çizilmiyordu.
///
/// [FmFileImage] baytları motorun belleğine okur ve **çözerken** hedef
/// genişliğe küçültür. Burada kilitlenen şey: küçültme gerçekten oluyor mu ve
/// küçük kaynak BÜYÜTÜLMÜYOR mu (büyütmek hem bulanık hem de daha pahalı).
void main() {
  late Directory tmp;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('fm-file-image');
  });

  tearDown(() => removeTempDir(tmp));

  String writePng(String name, int w, int h) {
    final image = img.Image(width: w, height: h);
    img.fill(image, color: img.ColorRgb8(200, 40, 40));
    final path = p.join(tmp.path, name);
    File(path).writeAsBytesSync(img.encodePng(image));
    return path;
  }

  Future<ui.Image> load(ImageProvider provider) {
    final completer = Completer<ui.Image>();
    provider.resolve(ImageConfiguration.empty).addListener(
          ImageStreamListener(
            (info, _) => completer.complete(info.image),
            onError: (e, _) => completer.completeError(e),
          ),
        );
    return completer.future;
  }

  testWidgets('cacheWidth: kaynak küçültülerek çözülür (oran korunur)',
      (tester) async {
    final path = writePng('buyuk.png', 400, 200);
    await tester.runAsync(() async {
      final image = await load(FmFileImage(path, cacheWidth: 100));
      expect(image.width, 100);
      expect(image.height, 50); // 400:200 oranı korundu
    });
  });

  testWidgets('küçük kaynak BÜYÜTÜLMEZ', (tester) async {
    final path = writePng('kucuk.png', 40, 20);
    await tester.runAsync(() async {
      final image = await load(FmFileImage(path, cacheWidth: 400));
      expect(image.width, 40);
      expect(image.height, 20);
    });
  });

  testWidgets('cacheWidth verilmezse tam çözünürlük', (tester) async {
    final path = writePng('tam.png', 64, 32);
    await tester.runAsync(() async {
      final image = await load(FmFileImage(path));
      expect(image.width, 64);
    });
  });

  testWidgets('olmayan dosya hata verir (çağıranın errorBuilder yolu)',
      (tester) async {
    await tester.runAsync(() async {
      await expectLater(
        load(FmFileImage(p.join(tmp.path, 'yok.png'))),
        throwsA(anything),
      );
    });
  });

  testWidgets('yer tutucu SINIRSIZ yükseklikli yuvada da çizilir',
      (tester) async {
    // `Image`ın width/height'ı yalnız ASIL kareye uygulanır, `frameBuilder`ın
    // döndürdüğü yer tutucuya değil. Kendi başına genişleyen bir yer tutucu
    // `ListTile.leading` gibi yüksekliği sınırsız bir yuvada çizim hatası
    // verirdi — ve bu yalnız resim henüz çözülmemişken, yani tam da ilk
    // kaydırmada görülürdü.
    final path = writePng('satir.png', 800, 600);
    await tester.pumpWidget(ChangeNotifierProvider<AppState>.value(
      value: AppState(),
      child: MaterialApp(
        home: Scaffold(
          body: ListView(
            children: [
              ListTile(
                leading: FmEntryIcon(
                  entry: FsEntry(
                    path: path,
                    name: p.basename(path),
                    isDir: false,
                    sizeBytes: 100,
                    modifiedMs: 0,
                  ),
                  size: 68,
                ),
                title: const Text('satır'),
              ),
            ],
          ),
        ),
      ),
    ));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  test('anahtar: aynı yol + aynı ölçü aynı önbellek girdisidir', () {
    // Eşitlik yanlış olsaydı `imageCache` her karede yeniden çözerdi.
    expect(const FmFileImage('/a/b.jpg', cacheWidth: 100),
        const FmFileImage('/a/b.jpg', cacheWidth: 100));
    expect(const FmFileImage('/a/b.jpg', cacheWidth: 100).hashCode,
        const FmFileImage('/a/b.jpg', cacheWidth: 100).hashCode);
    expect(const FmFileImage('/a/b.jpg', cacheWidth: 100),
        isNot(const FmFileImage('/a/b.jpg', cacheWidth: 200)));
    expect(const FmFileImage('/a/b.jpg'), isNot(const FmFileImage('/a/c.jpg')));
  });
}
