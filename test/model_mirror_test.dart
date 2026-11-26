import 'package:dosya_okuyucu/core/model_mirror.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const tf =
      'https://tfhub.dev/captain-pool/lite-model/esrgan-tf2/1?lite-format=tflite';

  test('ayna yoksa yalnız özgün kaynak', () {
    expect(ModelMirror.candidates(tf, mirror: ''), [tf]);
  });

  test('ayna önce, özgün kaynak yedek; host + yol + sorgu korunur', () {
    expect(ModelMirror.candidates(tf, mirror: 'https://ayna.test/m/'), [
      'https://ayna.test/m/tfhub.dev/captain-pool/lite-model/esrgan-tf2/1?lite-format=tflite',
      tf,
    ]);
  });
}
