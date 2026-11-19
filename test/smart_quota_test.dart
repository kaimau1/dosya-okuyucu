import 'dart:io';

import 'package:dosya_okuyucu/services/ai_pool.dart';
import 'package:dosya_okuyucu/services/fm/ai_scope.dart';
import 'package:dosya_okuyucu/services/fm/fm_env.dart';
import 'package:dosya_okuyucu/services/fm/smart_quota.dart';
import 'package:dosya_okuyucu/services/fm/smart_sort.dart';
import 'package:dosya_okuyucu/services/gemini_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Akıllı düzen 2.0 m.5 (2026-11-19): günlük istek sınırı, kota (429)
/// sayımı, "yalnız Wi-Fi'de". Dosyalar sentetik, anahtar uydurma.
void main() {
  var day = DateTime(2026, 11, 19, 10);
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    SmartQuota.debugReset();
    day = DateTime(2026, 11, 19, 10);
    SmartQuota.now = () => day;
  });
  tearDown(SmartQuota.debugReset);

  test('varsayılan: günde 200, yalnız Wi-Fi açık', () async {
    await SmartQuota.read();
    expect(SmartQuota.dailyCap, 200);
    expect(SmartQuota.capChoices, contains(SmartQuota.defaultCap));
    expect(SmartQuota.wifiOnly, isTrue);
  });

  test('Wi-Fi: ölçülü ya da okunamayan bağlantıda tur başlamaz', () async {
    for (final (m, want) in [
      (true, SmartHold.wifi),
      (null, SmartHold.wifi),
      (false, null),
    ]) {
      SmartQuota.metered = () async => m;
      expect(await SmartQuota.check(), want, reason: 'ölçülü: $m');
    }
    SmartQuota.metered = () async => throw StateError('kanal yok');
    expect(await SmartQuota.check(), SmartHold.wifi);
    await SmartQuota.setSettings(wifiOnly: false);
    SmartQuota.metered = () async => true;
    expect(await SmartQuota.check(), isNull);
  });

  test('sınır: hak biter, check cap der; geçersiz sınır yok sayılır',
      () async {
    SmartQuota.metered = () async => false;
    await SmartQuota.setSettings(cap: 50);
    await SmartQuota.setSettings(cap: 7);
    expect(SmartQuota.dailyCap, 50);
    for (var i = 0; i < 50; i++) {
      expect(SmartQuota.take(), isTrue);
    }
    expect(SmartQuota.take(), isFalse);
    expect(SmartQuota.usedToday, 50);
    expect(SmartQuota.remaining, 0);
    expect(await SmartQuota.check(), SmartHold.cap);
  });

  test('gün dönünce sayım sıfırlanır, geçmiş en çok 7 gün', () async {
    await SmartQuota.read();
    for (var d = 0; d < 9; d++) {
      day = DateTime(2026, 11, 1 + d, 12);
      SmartQuota.take();
      if (d.isEven) SmartQuota.noteLimited();
    }
    final days = SmartQuota.days;
    expect(days, hasLength(SmartQuota.historyDays));
    expect(days.first.day, '2026-11-09');
    expect(days.first.requests, 1);
    expect(days.first.limited, 1);
    expect(days[1].day, '2026-11-08');
    expect(days[1].limited, 0);
    day = DateTime(2026, 11, 10);
    expect(SmartQuota.usedToday, 0);
    expect(SmartQuota.limitedToday, 0);
  });

  test('kalıcı: sayım ve ayar yeniden okunur; bozuk satır düşer', () async {
    await SmartQuota.setSettings(cap: 500, wifiOnly: false);
    SmartQuota.take();
    SmartQuota.take();
    SmartQuota.noteLimited();
    await pumpEventQueue();
    final prefs = await SharedPreferences.getInstance();
    final log = prefs.getStringList(SmartQuota.prefLog)!;
    expect(log.first, '2026-11-19,2,1');
    await prefs.setStringList(SmartQuota.prefLog, [...log, 'bozuk', 'x,-1,2']);
    SmartQuota.debugReset();
    SmartQuota.now = () => day;
    await SmartQuota.read();
    expect(SmartQuota.dailyCap, 500);
    expect(SmartQuota.wifiOnly, isFalse);
    expect(SmartQuota.usedToday, 2);
    expect(SmartQuota.limitedToday, 1);
    expect(SmartQuota.days, hasLength(1));
  });

  group('tur', () {
    late Directory tmp;
    var posts = 0;
    var status = 200;
    const creds = AiCredentials(keys: ['k1']);
    const scope = AiScope(settings: AiScopeSettings());

    final root0 = FmEnv.primaryRoot;
    setUp(() {
      tmp = Directory.systemTemp.createTempSync('squota_');
      FmEnv.primaryRoot = tmp.path;
      FmEnv.appSupportDir = tmp.path;
      final dl = Directory('${tmp.path}/Download')..createSync();
      for (var i = 0; i < 3; i++) {
        File('${dl.path}/not$i.txt').writeAsStringSync('fatura $i tutar 120');
      }
      SmartSort.debugReset();
      SmartSort.retryDelay = Duration.zero;
      posts = 0;
      status = 200;
      GeminiService.debugClient = MockClient((req) async {
        posts++;
        return status == 200
            ? http.Response('{"answers":{}}', 200)
            : http.Response('{"error":{"message":"quota"}}', status);
      });
    });
    tearDown(() {
      GeminiService.debugClient = null;
      SmartSort.debugReset();
      FmEnv.primaryRoot = root0;
      FmEnv.appSupportDir = '';
      tmp.deleteSync(recursive: true);
    });

    test('anahtar yoksa neden söylenir (U4: eskiden "yeni dosya yok")',
        () async {
      SmartQuota.metered = () async => false;
      final r = await SmartSort.run(
          credentials: const AiCredentials(), scope: scope);
      expect(r.hold, SmartHold.noKey);
      expect(posts, 0);
    });

    test('kota durması kullanıcı dilinde (ham API iletisi değil)', () async {
      SmartQuota.metered = () async => false;
      status = 403;
      final r = await SmartSort.run(credentials: creds, scope: scope);
      expect(r.stoppedBy, isNot(contains('quota')));
      expect(r.stoppedBy, SmartSort.stopText(GeminiException('x', statusCode: 403)));
    });

    test('mobil veride (yalnız Wi-Fi) istek yok', () async {
      SmartQuota.metered = () async => true;
      final r = await SmartSort.run(credentials: creds, scope: scope);
      expect(r.hold, SmartHold.wifi);
      expect(posts, 0);
    });

    test('sınır dolunca durur; her dosya bir hak', () async {
      SmartQuota.metered = () async => false;
      await SmartQuota.setSettings(cap: 50);
      for (var i = 0; i < 48; i++) {
        SmartQuota.take();
      }
      final r = await SmartSort.run(credentials: creds, scope: scope);
      expect(posts, 2);
      expect(r.hold, SmartHold.cap);
      expect(SmartQuota.usedToday, 50);
      final again = await SmartSort.run(credentials: creds, scope: scope);
      expect(again.hold, SmartHold.cap);
      expect(posts, 2);
    });

    test('429: bir kez yeniden denenir, ikisi de sayılır, tur durur',
        () async {
      SmartQuota.metered = () async => false;
      status = 429;
      final r = await SmartSort.run(credentials: creds, scope: scope);
      expect(r.stoppedBy, isNotNull);
      expect(r.hold, isNull);
      expect(SmartQuota.limitedToday, greaterThanOrEqualTo(2));
      expect(SmartQuota.usedToday, posts);
    });
  });
}
