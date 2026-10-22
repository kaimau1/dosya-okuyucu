import 'dart:convert';
import 'dart:io';

import 'package:dosya_okuyucu/services/voice/neural_voices.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  late Directory root;
  setUp(() {
    root = Directory.systemTemp.createTempSync('voices');
    NeuralVoiceStore.rootOverride = root.path;
  });
  tearDown(() {
    NeuralVoiceStore.rootOverride = null;
    root.deleteSync(recursive: true);
  });

  test('yerel sunucu: COOP/COEP başlıkları, kök dışı yok, sonuç POST', () async {
    File('${root.path}/a.mjs').writeAsStringSync('export const x = 1;');
    final server = await VoiceServer.start(root.path);
    addTearDown(server.close);
    final c = HttpClient();
    final req = await c.getUrl(Uri.parse('${server.origin}/a.mjs'));
    final res = await req.close();
    expect(res.statusCode, 200);
    expect(res.headers.value('cross-origin-embedder-policy'), 'require-corp');
    expect(res.headers.contentType?.mimeType, 'text/javascript');
    await res.drain<void>();

    final bad = await (await c
            .getUrl(Uri.parse('${server.origin}/%2e%2e/%2e%2e/etc/passwd')))
        .close();
    expect(bad.statusCode, anyOf(403, 404));
    await bad.drain<void>();

    final engine = await (await c.getUrl(Uri.parse('${server.origin}/engine.html'))).close();
    expect(await engine.transform(utf8.decoder).join(), contains('window.engine'));

    final waiting = server.expect('j1');
    final post = await c.postUrl(Uri.parse('${server.origin}/out/j1'));
    post.add([1, 2, 3]);
    await (await post.close()).drain<void>();
    expect(await waiting, [1, 2, 3]);
    c.close();
  });

  test('kurulum: eksik dosyalar iner, EMA çalışanı yerel ORT\'ye çevrilir',
      () async {
    final client = MockClient.streaming((req, _) async {
      final body = req.url.path.endsWith('worker.js')
          ? 'import * as ort from "https://cdn.jsdelivr.net/npm/onnxruntime-web@1.30.0/dist/ort.webgpu.min.mjs";\n'
              'ort.env.wasm.wasmPaths = "https://cdn.jsdelivr.net/npm/onnxruntime-web@1.30.0/dist/";\n'
              'if (self.navigator?.gpu && x) {}'
          : 'veri';
      return http.StreamedResponse(Stream.value(utf8.encode(body)), 200);
    });
    final store = NeuralVoiceStore.instance;
    expect(store.isInstalled(NeuralVoice.ema), isFalse);
    await store.install(NeuralVoice.ema, client: client);
    expect(store.isInstalled(NeuralVoice.ema), isTrue);
    expect(store.isInstalled(NeuralVoice.antalia), isFalse);
    final worker = File('${root.path}/ema/worker.js').readAsStringSync();
    expect(worker, contains('/antalia/vendor/ort/ort.wasm.min.mjs'));
    expect(worker, isNot(contains('jsdelivr')));
    expect(worker, contains('if (false && self.navigator?.gpu'));

    await store.remove(NeuralVoice.ema);
    expect(store.isInstalled(NeuralVoice.ema), isFalse);
    expect(File('${root.path}/antalia/vendor/ort/ort.wasm.min.mjs').existsSync(),
        isFalse, reason: 'başka ses yoksa çalışma zamanı da silinir');
  });
}
