import 'package:dosya_okuyucu/widgets/fm/speed_sheet.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('oynatma hızı 0,05 adıma oturur ve aralıkta kalır', () {
    expect(PlaybackSpeed.snap(1.07), 1.05);
    expect(PlaybackSpeed.snap(1.08), 1.1);
    expect(PlaybackSpeed.snap(0.1), PlaybackSpeed.min);
    expect(PlaybackSpeed.snap(9), PlaybackSpeed.max);
    expect(PlaybackSpeed.label(1.0), '1×');
    expect(PlaybackSpeed.label(1.5), '1.5×');
    expect(PlaybackSpeed.label(1.25), '1.25×');
  });
}
