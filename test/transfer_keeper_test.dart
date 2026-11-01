import 'dart:io';

import 'package:dosya_okuyucu/services/fm/remote/qr_transfer.dart';
import 'package:dosya_okuyucu/services/fm/remote/transfer_keeper.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory tmp;
  late File big;
  const bytes = 32 * 1024 * 1024;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('keeper');
    big = File(p.join(tmp.path, 'buyuk.bin'));
    await big.writeAsBytes(List.filled(bytes, 7));
  });
  tearDown(() => tmp.delete(recursive: true));

  Future<QrShareServer> serve(TransferKeeper keeper) async {
    final server = QrShareServer([big.path], onActivity: keeper.onActivity);
    await server.start();
    addTearDown(server.stop);
    return server;
  }

  test('hiç istek almamış sunucu ekranla birlikte anında kapanır', () async {
    final keeper = TransferKeeper(idle: const Duration(milliseconds: 100));
    final server = await serve(keeper);
    var closed = false;
    await keeper.handOff(server, onClosed: () async => closed = true);
    expect(closed, isTrue);
    expect(keeper.adoptedCount, 0);
    expect(server.port, 0);
  });

  test('indirme sürerken ekran kapansa da dosya SONUNA kadar iner; '
      'sonra sunucu ve geçici ağ kapanır', () async {
    final keeper = TransferKeeper(idle: const Duration(milliseconds: 200));
    final server = await serve(keeper);
    final client = HttpClient();
    addTearDown(client.close);
    final res =
        await (await client.getUrl(server.urlFor('127.0.0.1').resolve('0')))
            .close();
    var got = 0;
    var closed = false;
    final done = res.forEach((chunk) async {
      // Alıcı yavaş: ekran kapanırken indirme yarıda olsun.
      if (got == 0) {
        expect(server.activeTransfers, 1);
        await keeper.handOff(server, onClosed: () async => closed = true);
      }
      got += chunk.length;
    });
    await done;
    expect(got, bytes);
    expect(keeper.adoptedCount, 1, reason: 'sıradaki dosya için kısa bekleme');
    expect(closed, isFalse);
    for (var i = 0; i < 40 && !closed; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
    expect(closed, isTrue);
    expect(keeper.adoptedCount, 0);
    expect(server.port, 0);
  });

  test('bildirimdeki Durdur devralınan sunucuyu hemen kapatır', () async {
    final keeper = TransferKeeper(idle: const Duration(minutes: 5));
    final server = await serve(keeper);
    server.lastActivity = DateTime.now();
    var closed = false;
    await keeper.handOff(server, onClosed: () async => closed = true);
    expect(keeper.adoptedCount, 1);
    await keeper.stopAdopted();
    expect(closed, isTrue);
    expect(server.port, 0);
  });

  test('yeni ekran geçici ağı devraldıysa eski oturum onu kapatmaz', () async {
    final keeper = TransferKeeper(idle: const Duration(minutes: 5));
    final server = await serve(keeper);
    server.lastActivity = DateTime.now();
    var closed = false;
    await keeper.handOff(server, onClosed: () async => closed = true);
    keeper.detachClosers();
    await keeper.stopAdopted();
    expect(closed, isFalse);
  });
}
