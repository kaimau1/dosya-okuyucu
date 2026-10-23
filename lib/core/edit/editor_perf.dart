/// Düzenleme gecikmesi ölçümü (Faz 20 / madde 9, §7 bütçeleri).
///
/// Tuş olayı geldiğinde [mark] çağrılır; ardından çizilen İLK karenin
/// bitişine kadar geçen süre ölçülür (`SchedulerBinding.addPostFrameCallback`
/// + `FrameTiming`). Sonuç `KARE` günlüğüne editör etiketiyle yazılır ve
/// geliştirici ayarı açıksa köşedeki sayaçta görünür.
library;

import 'dart:developer' as dev;

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/material.dart';

import '../app_colors.dart';

class EditorPerf {
  EditorPerf._();

  /// Geliştirici menüsündeki "Düzenleme gecikme sayacı".
  static final ValueNotifier<bool> overlayEnabled = ValueNotifier(false);

  /// Son ölçüm (ms) — sayaç bunu gösterir.
  static final ValueNotifier<double?> lastMs = ValueNotifier(null);

  static final List<double> _samples = [];

  /// Son ölçümler (en çok 120) — test/tanı için.
  static List<double> get samples => List.unmodifiable(_samples);

  static Stopwatch? _pending;
  static String _tag = '';

  /// Bir tuş/düzenleme olayı oldu; bir sonraki kare ölçülür.
  static void mark(String editor) {
    if (_pending != null) return; // aynı kareye düşen ikinci tuş
    _tag = editor;
    final sw = Stopwatch()..start();
    _pending = sw;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      sw.stop();
      _pending = null;
      final ms = sw.elapsedMicroseconds / 1000.0;
      _samples.add(ms);
      if (_samples.length > 120) _samples.removeAt(0);
      lastMs.value = ms;
      if (kProfileMode || kDebugMode) {
        dev.log('KARE $_tag tuş→kare ${ms.toStringAsFixed(1)} ms',
            name: 'EditorPerf');
      }
    });
    SchedulerBinding.instance.ensureVisualUpdate();
  }

  @visibleForTesting
  static void reset() {
    _samples.clear();
    _pending = null;
    lastMs.value = null;
  }
}

/// Köşedeki gecikme sayacı (yalnız geliştirici ayarı açıkken).
class EditorPerfOverlay extends StatelessWidget {
  final Widget child;
  const EditorPerfOverlay({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: EditorPerf.overlayEnabled,
      builder: (context, on, _) {
        if (!on) return child;
        return Stack(
          children: [
            child,
            PositionedDirectional(
              top: 4,
              end: 4,
              child: IgnorePointer(
                child: ValueListenableBuilder<double?>(
                  valueListenable: EditorPerf.lastMs,
                  builder: (context, ms, _) => DecoratedBox(
                    decoration: BoxDecoration(
                      color: AppColors.mediaScrim,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      child: Text(
                        ms == null ? '— ms' : '${ms.toStringAsFixed(1)} ms',
                        style: Theme.of(context)
                            .textTheme
                            .labelSmall
                            ?.copyWith(color: AppColors.onMedia),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
