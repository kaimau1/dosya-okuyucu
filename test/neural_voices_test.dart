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
    final req = await c.getUrl(Uri.parse('${server.base}a.mjs'));
    final res = await req.close();
    expect(res.statusCode, 200);
    expect(res.headers.value('cross-origin-embedder-policy'), 'require-corp');
    expect(res.headers.contentType?.mimeType, 'text/javascript');
    await res.drain<void>();

    final bad = await (await c
            .getUrl(Uri.parse('${server.base}%2e%2e/%2e%2e/etc/passwd')))
        .close();
    expect(bad.statusCode, anyOf(403, 404));
    await bad.drain<void>();

    final noPrefix =
        await (await c.getUrl(Uri.parse('${server.origin}/a.mjs'))).close();
    expect(noPrefix.statusCode, 404, reason: 'G6.5: öneksiz istek dosya vermez');
    await noPrefix.drain<void>();
    expect(server.prefix, matches(RegExp(r'^[0-9a-f]{32}$')));

    Directory('${root.path}/ema').createSync();
    File('${root.path}/ema/worker.js')
        .writeAsStringSync('import "/antalia/vendor/ort/ort.wasm.min.mjs";');
    final w =
        await (await c.getUrl(Uri.parse('${server.base}ema/worker.js'))).close();
    expect(await w.transform(utf8.decoder).join(),
        contains('/${server.prefix}/antalia/vendor/ort/ort.wasm.min.mjs'));

    final engine = await (await c.getUrl(Uri.parse('${server.base}engine.html'))).close();
    expect(await engine.transform(utf8.decoder).join(), contains('window.engine'));

    final waiting = server.expect('j1');
    final post = await c.postUrl(Uri.parse('${server.base}out/j1'));
    post.add([1, 2, 3]);
    await (await post.close()).drain<void>();
    expect(await waiting, [1, 2, 3]);
    c.close();
  });

  test('G6.5: yabancı Host / Origin reddedilir, beklenmeyen iş 404', () async {
    final server = await VoiceServer.start(root.path);
    addTearDown(server.close);
    final port = server.port;
    expect(VoiceServer.hostAllowed('127.0.0.1:$port', port), isTrue);
    expect(VoiceServer.hostAllowed('localhost:$port', port), isTrue);
    expect(VoiceServer.hostAllowed('evil.com:$port', port), isFalse);
    expect(VoiceServer.hostAllowed(null, port), isFalse);
    expect(VoiceServer.originAllowed(null, port), isTrue);
    expect(VoiceServer.originAllowed('http://127.0.0.1:$port', port), isTrue);
    expect(VoiceServer.originAllowed('http://evil.com', port), isFalse);

    final c = HttpClient();
    addTearDown(() => c.close(force: true));
    final rebind = await c.getUrl(Uri.parse('${server.base}engine.html'));
    rebind.headers.set(HttpHeaders.hostHeader, 'evil.com:$port');
    final r1 = await rebind.close();
    expect(r1.statusCode, 403);
    await r1.drain<void>();

    server.expect('j2').ignore();
    final foreign = await c.postUrl(Uri.parse('${server.base}out/j2'));
    foreign.headers.set('origin', 'http://evil.com');
    foreign.add([1]);
    final r2 = await foreign.close();
    expect(r2.statusCode, 403);
    await r2.drain<void>();

    final unknown = await c.postUrl(Uri.parse('${server.base}out/yok'));
    unknown.add([1]);
    final r3 = await unknown.close();
    expect(r3.statusCode, 404);
    await r3.drain<void>();
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
