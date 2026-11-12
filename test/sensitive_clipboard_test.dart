import 'package:dosya_okuyucu/core/sensitive_clipboard.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Güvenlik G2.6: hassas kopya 60 sn sonra yalnız pano hâlâ aynıysa silinir.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  String? board;

  setUp(() {
    board = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        board = (call.arguments as Map)['text'] as String?;
        return null;
      }
      if (call.method == 'Clipboard.getData') {
        return board == null ? null : {'text': board};
      }
      return null;
    });
  });

  test('pano aynıysa temizlenir', () async {
    board = 'Gizli-123';
    expect(await SensitiveClipboard.clearIfSame('Gizli-123'), isTrue);
    expect(board, '');
  });

  test('kullanıcı başka şey kopyaladıysa dokunulmaz', () async {
    board = 'başka metin';
    expect(await SensitiveClipboard.clearIfSame('Gizli-123'), isFalse);
    expect(board, 'başka metin');
  });

  test('kanal yoksa düz kopyalar', () async {
    await SensitiveClipboard.copy('Gizli-123');
    expect(board, 'Gizli-123');
  });
}
