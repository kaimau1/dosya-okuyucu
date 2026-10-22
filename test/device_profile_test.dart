import 'dart:io';

import 'package:dosya_okuyucu/core/app_state.dart';
import 'package:dosya_okuyucu/core/device_profile.dart';
import 'package:dosya_okuyucu/core/startup_queue.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Faz 4 — düşük donanım profili ve açılış bütçesi.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() => DeviceProfile.debugOverride(DeviceTier.mid));

  group('classifyDevice', () {
    test('bilgi yoksa orta (eski davranış)', () {
      expect(classifyDevice(const DeviceInfo()), DeviceTier.mid);
    });
    test('sistem düşük RAM diyorsa hafif', () {
      expect(
          classifyDevice(const DeviceInfo(
              totalRamMb: 8000, cores: 8, lowRam: true)),
          DeviceTier.low);
    });
    test('2-3 GB ya da 4 çekirdek hafif', () {
      expect(classifyDevice(const DeviceInfo(totalRamMb: 2900, cores: 8)),
          DeviceTier.low);
      expect(classifyDevice(const DeviceInfo(totalRamMb: 4000, cores: 4)),
          DeviceTier.low);
    });
    test('4 GB / 8 çekirdek orta', () {
      expect(classifyDevice(const DeviceInfo(totalRamMb: 3800, cores: 8)),
          DeviceTier.mid);
    });
    test('8 GB / 8 çekirdek ya da medya sınıfı 12+ güçlü', () {
      expect(classifyDevice(const DeviceInfo(totalRamMb: 7600, cores: 8)),
          DeviceTier.high);
      expect(
          classifyDevice(
              const DeviceInfo(totalRamMb: 4000, cores: 8, perfClass: 31)),
          DeviceTier.high);
    });
    test('fromMap yerel kanal biçimini okur', () {
      final info = DeviceInfo.fromMap(
          {'totalRamMb': 3000, 'lowRam': false, 'cores': 8, 'perfClass': 0});
      expect(info.totalRamMb, 3000);
      expect(classifyDevice(info), DeviceTier.low);
    });
  });

  test('kullanıcı kipi algılananı ezer', () {
    expect(effectiveTier(PerfMode.auto, DeviceTier.high), DeviceTier.high);
    expect(effectiveTier(PerfMode.light, DeviceTier.high), DeviceTier.low);
    expect(effectiveTier(PerfMode.full, DeviceTier.low), DeviceTier.high);
  });

  test('bütçeler: hafif < orta <= güçlü', () {
    const low = PerfBudget(DeviceTier.low);
    const mid = PerfBudget(DeviceTier.mid);
    const high = PerfBudget(DeviceTier.high);
    expect(low.imageCacheBytes < mid.imageCacheBytes, isTrue);
    expect(mid.imageCacheBytes <= high.imageCacheBytes, isTrue);
    expect(high.imageCacheBytes, 64 << 20); // 2026-10-23 telefonda A/B
    expect(low.thumbConcurrency, 1);
    expect(high.thumbConcurrency, 2);
    expect(low.highRefreshDefault, isFalse);
    expect(mid.highRefreshDefault, isTrue);
    expect(low.volumePoll.inSeconds, greaterThanOrEqualTo(15));
  });

  test('kanal yoksa yükleme sessizce orta profile düşer', () async {
    await DeviceProfile.load(PerfMode.auto);
    expect(DeviceProfile.detected, DeviceTier.mid);
    expect(DeviceProfile.tier.value, DeviceTier.mid);
  });

  test('120 Hz / otomatik tarama varsayılanı profile bağlı, seçim kalıcı',
      () async {
    SharedPreferences.setMockInitialValues({});
    final s = AppState();
    await s.init();
    DeviceProfile.debugOverride(DeviceTier.low);
    expect(s.highRefreshRate, isFalse);
    expect(s.autoRescan, isFalse);
    DeviceProfile.debugOverride(DeviceTier.high);
    expect(s.highRefreshRate, isTrue);
    await s.setHighRefreshRate(false);
    expect(s.highRefreshRate, isFalse);
    await s.setPerfMode(PerfMode.light);
    expect(DeviceProfile.tier.value, DeviceTier.low);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('perf_mode'), 'light');
    // Eski kurulumdaki açık tercih korunur.
    SharedPreferences.setMockInitialValues({'perf_high_refresh': true});
    final old = AppState();
    await old.init();
    DeviceProfile.debugOverride(DeviceTier.low);
    expect(old.highRefreshRate, isTrue);
  });

  group('StartupQueue', () {
    setUp(() => StartupQueue.instance.debugReset());

    test('işler beklemeden sonra SIRAYLA koşar, hata zinciri kırmaz',
        () async {
      final q = StartupQueue.instance;
      final order = <String>[];
      var concurrent = 0, peak = 0;
      Future<void> job(String n) async {
        concurrent++;
        peak = concurrent > peak ? concurrent : peak;
        await Future<void>.delayed(const Duration(milliseconds: 5));
        order.add(n);
        concurrent--;
      }

      q.add('a', () => job('a'));
      q.add('boom', () async => throw StateError('x'));
      q.add('b', () => job('b'));
      expect(order, isEmpty);
      q.start(delay: const Duration(milliseconds: 10));
      await Future<void>.delayed(const Duration(milliseconds: 5));
      expect(order, isEmpty, reason: 'bekleme süresinden önce koşmamalı');
      await Future<void>.delayed(const Duration(milliseconds: 20));
      await q.whenIdle;
      expect(order, ['a', 'b']);
      expect(peak, 1);
      expect(q.debugLog, ['a', 'boom', 'b']);
      // Süre dolduktan sonra eklenen iş hemen koşar.
      q.add('late', () => job('late'));
      await q.whenIdle;
      expect(order.last, 'late');
    });
  });

  test('yerel köprü: deviceClass kanalda tanımlı', () {
    final kt = File('ci/MainActivity.kt').readAsStringSync();
    expect(kt.contains('"deviceClass" -> result.success(Extras.deviceClass(ctx))'),
        isTrue);
    final extras = File('ci/Extras.kt').readAsStringSync();
    expect(extras.contains('fun deviceClass(ctx: Context)'), isTrue);
    expect(extras.contains('isLowRamDevice'), isTrue);
  });

  testWidgets('gizli sekmelerde animasyon saati durur (TickerMode)',
      (tester) async {
    final src = File('lib/screens/home_screen.dart').readAsStringSync();
    expect(src.contains('TickerMode('), isTrue);
    await tester.pumpWidget(const SizedBox());
  });
}
