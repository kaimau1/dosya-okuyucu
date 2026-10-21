import 'dart:async';

import 'package:flutter/foundation.dart';

/// **Açılış bütçesi** (Faz 4, 2026-10-21 — FAZ_PLANI P11).
///
/// Eskiden ilk saniyelerde ~12 bağımsız asenkron iş (geçici dosya süpürme,
/// kasa temizliği, SD işi, widget güncelleme, oynatma konumları, AI dizini…)
/// AYNI ANDA başlıyordu; düşük cihazda ilk etkileşim gecikiyordu. Kritik
/// olmayan işler buraya eklenir: ilk kareden [delay] sonra, **sırayla** ve
/// her biri bittikten sonra bir sonraki koşar. Bir işin hatası ötekileri
/// durdurmaz (her iş "en iyi çaba").
class StartupQueue {
  StartupQueue._();

  static final StartupQueue instance = StartupQueue._();

  final _jobs = <(String, Future<void> Function())>[];
  bool _scheduled = false;
  bool _ready = false;
  bool _running = false;
  Completer<void>? _idle;

  /// Koşmuş işlerin adları, sırayla (test ve teşhis için).
  @visibleForTesting
  final List<String> debugLog = [];

  /// İşi kuyruğa ekler. Bekleme süresi dolduysa hemen sıraya girer (yine
  /// sırayla); dolmadıysa süre dolunca koşar.
  void add(String name, Future<void> Function() job) {
    _jobs.add((name, job));
    if (_ready && !_running) unawaited(_drain());
  }

  /// İlk kareden sonra [delay] bekleyip kuyruğu boşaltır. Bir kez çağrılır.
  void start({Duration delay = const Duration(seconds: 2)}) {
    if (_scheduled) return;
    _scheduled = true;
    Timer(delay, () {
      _ready = true;
      unawaited(_drain());
    });
  }

  /// Kuyruk boşalınca tamamlanır (test için).
  @visibleForTesting
  Future<void> get whenIdle =>
      (_running || _jobs.isNotEmpty) ? (_idle ??= Completer()).future : Future.value();

  Future<void> _drain() async {
    if (_running) return;
    _running = true;
    try {
      while (_jobs.isNotEmpty) {
        final (name, job) = _jobs.removeAt(0);
        try {
          await job();
        } catch (_) {
          // Açılış işleri güvence ağı: biri düşerse uygulama yine çalışır.
        }
        debugLog.add(name);
      }
    } finally {
      _running = false;
      _idle?.complete();
      _idle = null;
    }
  }

  @visibleForTesting
  void debugReset() {
    _jobs.clear();
    _scheduled = false;
    _ready = false;
    _running = false;
    _idle = null;
    debugLog.clear();
  }
}
