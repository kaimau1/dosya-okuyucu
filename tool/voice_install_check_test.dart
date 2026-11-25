// Yapay zekâ seslerinin indiricisini GERÇEK ağla dener (CI'da koşmaz —
// `tool/` altında). Kullanım:
//   VOICE_ROOT=/tmp/voices flutter test tool/voice_install_check_test.dart
// Ardından tool/voice_engine_check.mjs motoru gerçek Chromium'da sınar.
import 'dart:io';

import 'package:dosya_okuyucu/services/voice/neural_voices.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('sesler indirilir ve kurulu sayılır', () async {
    final root = Platform.environment['VOICE_ROOT'];
    if (root == null) return;
    // ignore: invalid_use_of_visible_for_testing_member
    NeuralVoiceStore.rootOverride = root;
    for (final v in NeuralVoice.values) {
      await NeuralVoiceStore.instance.install(v);
      expect(NeuralVoiceStore.instance.isInstalled(v), isTrue, reason: v.name);
    }
    final worker = File('$root/ema/worker.js').readAsStringSync();
    expect(worker, isNot(contains('cdn.jsdelivr.net')));
    File('$root/engine.html').writeAsStringSync(VoiceServer.engineHtml);
  }, timeout: const Timeout(Duration(minutes: 20)));
}
