import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/app_icons.dart';
import '../../core/l10n/app_strings.dart';
import '../../services/fm/audio_playback.dart';

/// **Satır içi oynat/duraklat** (2026-11-08, kullanıcı: ses listesinde
/// dosyanın üstünden doğrudan çal). Ses satırının simgesinin üstüne biner;
/// dokunuş satırı açmaz, çalar/duraklatır. Ekran altı mini çubukla aynı
/// [AudioPlayback] tekilini kullanır → ikisi kendiliğinden senkron.
///
/// Kaydırma maliyeti (P3): her satır yalnız durum bildirimini dinler (çal/
/// duraklat/parça — saniyede ~5 gelen konum DEĞİL). Konumu yalnız ÇALAN
/// satırın halkası dinler; ötekiler kare başı iş yapmaz.
class FmInlinePlay extends StatelessWidget {
  final String path;

  /// Dokunulunca başlayan çalma listesi (aynı listedeki sesler); null = tek.
  final List<String> Function()? queue;
  final double size;

  const FmInlinePlay(
      {super.key, required this.path, required this.size, this.queue});

  @override
  Widget build(BuildContext context) {
    final audio = AudioPlayback.instance;
    final scheme = Theme.of(context).colorScheme;
    final d = (size * 0.62).clamp(28.0, 44.0);
    return ListenableBuilder(
      listenable: audio,
      builder: (context, _) {
        final mine = audio.current == path;
        final playing = mine && audio.playing;
        return Semantics(
          button: true,
          label: context.t(playing ? 'mp.pause' : 'mp.play'),
          excludeSemantics: true,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => unawaited(mine
                ? audio.toggle()
                : audio.open(path, list: queue?.call() ?? const [])),
            child: SizedBox.square(
              dimension: size,
              child: Center(
                child: SizedBox.square(
                  dimension: d,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      DecoratedBox(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: scheme.primary
                              .withValues(alpha: mine ? 0.95 : 0.85),
                        ),
                        child: Icon(
                          playing ? AppIcons.pause : AppIcons.play,
                          color: scheme.onPrimary,
                          size: d * 0.62,
                        ),
                      ),
                      if (mine) _Progress(audio: audio, color: scheme),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Çalan satırdaki ilerleme halkası — konumu yalnız bu dinler.
class _Progress extends StatelessWidget {
  final AudioPlayback audio;
  final ColorScheme color;

  const _Progress({required this.audio, required this.color});

  @override
  Widget build(BuildContext context) => RepaintBoundary(
        child: ValueListenableBuilder<Duration>(
          valueListenable: audio.positionListenable,
          builder: (context, pos, _) {
            final total = audio.duration.inMilliseconds;
            return CircularProgressIndicator(
              value: total <= 0
                  ? 0
                  : (pos.inMilliseconds / total).clamp(0.0, 1.0),
              strokeWidth: 3,
              color: color.onPrimary,
              backgroundColor: color.onPrimary.withValues(alpha: 0.25),
            );
          },
        ),
      );
}
