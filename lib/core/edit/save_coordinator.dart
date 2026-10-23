/// Kaydetmeyi UI izleğinden alan ve sıraya koyan koordinatör (Faz 20 / ED3).
///
/// KÖK NEDEN: Word `editor.save()` (zip dahil) ve Excel `editor.save()` UI
/// izleğinde senkron koşuyordu — büyük dosyada kaydet düğmesinden sonra ekran
/// donuyordu. Şimdi:
/// * ağır iş (zip sıkıştırma / paket yazımı) [runInIsolate] ile ayrı izolatta;
/// * aynı anda **tek** kaydetme; kayıt sürerken gelen istek sıraya girer ve
///   birden çok istek tek kayda katlanır (otomatik kaydetme fırtınası yok);
/// * durum [status] ile dinlenir (`DocTitle`: "Kaydediliyor… / Kaydedildi").
library;

import 'dart:async';

import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';

/// Kaydetme durumu.
enum SaveStatus { idle, saving, saved, failed }

/// İzolat çalıştırıcı imzası (`compute` ile aynı).
typedef IsolateRunner = Future<R> Function<M, R>(
    FutureOr<R> Function(M message) callback, M message);

Future<R> _compute<M, R>(FutureOr<R> Function(M) cb, M message) =>
    compute<M, R>(cb, message);

/// Ağır kaydetme işlerinin izolat kapısı.
///
/// `flutter_test`te gerçek izolat askıda kalabildiği için (HAFIZA 2026-07-25
/// §F) testler [runner]'ı eşzamanlı bir sahteyle değiştirir; böylece "kaydetme
/// izolata gidiyor mu" da sayılarak doğrulanır.
class SaveIsolate {
  SaveIsolate._();

  static IsolateRunner runner = _compute;

  /// Kaç ağır iş izolata gönderildi (test ve tanı için).
  static int dispatched = 0;

  static Future<R> run<M, R>(FutureOr<R> Function(M message) cb, M message) {
    dispatched++;
    return runner<M, R>(cb, message);
  }

  /// Arşivi izolatta zip'e çevirir.
  static Future<Uint8List> encodeZip(Archive archive) =>
      run<Archive, Uint8List>(_encode, archive);

  static Uint8List _encode(Archive a) =>
      Uint8List.fromList(ZipEncoder().encode(a) ?? const <int>[]);
}

/// Tek belge için kaydetme sırası.
class SaveCoordinator {
  final ValueNotifier<SaveStatus> status = ValueNotifier(SaveStatus.idle);

  /// Son başarılı kaydın saati.
  DateTime? lastSavedAt;

  /// Son hata (failed durumunda).
  Object? lastError;

  Future<bool>? _running;
  Future<bool>? _queued;

  bool get isSaving => _running != null;

  /// [job]'u sıraya koyar. Kayıt sürüyorsa bir sonraki tura bağlanır; sırada
  /// zaten bekleyen varsa ONA katılır (iki otomatik kayıt tek yazım).
  Future<bool> save(Future<void> Function() job) {
    if (_running == null) return _start(job);
    return _queued ??= _running!.then((_) {
      _queued = null;
      return _start(job);
    });
  }

  Future<bool> _start(Future<void> Function() job) {
    final f = _run(job);
    _running = f;
    f.whenComplete(() {
      if (identical(_running, f)) _running = null;
    });
    return f;
  }

  Future<bool> _run(Future<void> Function() job) async {
    status.value = SaveStatus.saving;
    try {
      await job();
      lastSavedAt = DateTime.now();
      lastError = null;
      status.value = SaveStatus.saved;
      return true;
    } catch (e) {
      lastError = e;
      status.value = SaveStatus.failed;
      return false;
    }
  }

  void dispose() => status.dispose();
}
