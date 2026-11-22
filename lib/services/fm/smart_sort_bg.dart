import 'dart:async';
import 'dart:ui' show DartPluginRegistrant;

import 'package:flutter/widgets.dart';

import '../../core/app_state.dart';
import 'fm_env.dart';
import 'native_extras.dart';
import 'smart_quota.dart';
import 'smart_sort.dart';

/// **Akıllı düzen arka plan turu** (2026-11-19, kullanıcı: *"oto AI düzeni
/// Wi-Fi'ye ve şarja bağlıyken yapılsın diye ayrı bir seçeneği olsun, arka
/// planda da çalışabilsin"*).
///
/// Yerel `SmartBgJob` (JobScheduler: şarjda + ölçülü olmayan ağda, ~3 saatte
/// bir) ayrı bir Flutter motorunda bunu koşturur. Ekran yok: yalnız
/// [SmartSort.run], sonuç diske yazılır; uygulama dönüşte depoyu yeniden okur
/// ([SmartSort.reloadIfChanged]).
///
/// Koşul tekrar denetlenir (iş başladıktan sonra şarj çıkarılmış olabilir);
/// seçenek kapatıldıysa, AI rızası kalıcı değilse ya da anahtar yoksa hiçbir
/// istek atılmaz.
abstract final class SmartSortBg {
  /// Tek turda en çok bu kadar dosya (JobScheduler ~10 dk tanır; 8 dk
  /// dolunca tur kesilir, yapılanlar kalır). 2026-11-22: 60 → 300 — gece
  /// şarjda tüm arşiv birkaç turda biter.
  static const limit = 300;

  static Future<void> run() async {
    await FmEnv.ensureInit();
    await SmartSort.readSettings();
    if (!SmartSort.wantsBackgroundJob) {
      // Seçenek kapatılmış ama iş kalmış: iptal et.
      await NativeExtras.scheduleSmartBg(false);
      return;
    }
    if (!await SmartSort.chargingOnWifi()) return;
    final ai = await AppState.loadAiForBackground();
    if (ai == null) return;
    await SmartQuota.read();
    await SmartSort.ensureLoaded();
    await SmartSort.run(
      credentials: ai.credentials,
      scope: ai.scope,
      scan: SmartSort.scanAll,
      limit: limit,
    ).timeout(const Duration(minutes: 8), onTimeout: () {
      SmartSort.cancelRun();
      return const SmartRunResult(0, 0);
    });
    await SmartSort.flush();
  }
}

@pragma('vm:entry-point')
Future<void> akilliDuzenArkaPlan() async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();
  try {
    await SmartSortBg.run();
  } catch (_) {
    // Bilinçli: arka plan turu bir kolaylık; hata bir sonraki koşulda denenir.
  } finally {
    await NativeExtras.smartBgDone();
  }
}
