import 'package:flutter/material.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/theme.dart';
import '../../core/app_colors.dart';
import '../../core/app_icons.dart';
import '../app_dialog.dart';

/// Ses ve video oynatıcılarının **ortak oynatma hızı** levhası (U3 m.2,
/// 2026-11-20, kullanıcı: "6 sabit seçenek yerine tutamaçlı çubuk, 0,05
/// adım"). Eski hızlı seçenekler çubuğun altında düğme olarak kaldı.
///
/// Aralık 0,5–2,0: iki motorun da (ses + video) bozulmadan çaldığı aralık;
/// ponytail: genişletmek gerekirse [min]/[max] — cihazda ses perdesi denenmeli.
abstract final class PlaybackSpeed {
  static const min = 0.5;
  static const max = 2.0;
  static const step = 0.05;
  static const quick = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0];

  /// 0,05'e yuvarlar ve aralıkta tutar (kayan nokta kırıntısı yok).
  static double snap(double v) =>
      ((v.clamp(min, max) / step).round() * step * 100).round() / 100;

  /// "1,25×" — gereksiz sıfırsız.
  static String label(double v) {
    var s = snap(v).toStringAsFixed(2);
    s = s.replaceFirst(RegExp(r'0$'), '').replaceFirst(RegExp(r'\.0$'), '');
    return '$s×';
  }
}

/// **Canlı hız paneli** (2026-11-20, kullanıcı: "ekranı karartmadan altta
/// daha ufak panel; hem çekerken hem izleyebileyim, premium"). Arka plan
/// KARARMAZ (saydam bariyer), panel alçak ve yarı saydam; çubuk sürüklenirken
/// hız ANINDA uygulanır (0,05 adımda değişince — her karede değil). Hız 1×
/// değilken başlıkta "1× yap" düğmesi.
Future<void> showSpeedSheet(
  BuildContext context, {
  required double current,
  required ValueChanged<double> onChanged,
}) {
  return showAppSheet<void>(
    context,
    barrierColor: Colors.transparent,
    builder: (_) => _SpeedBody(current: current, onChanged: onChanged),
  );
}

/// Üst çubuktaki hız düğmesi: 1×'te yalnız simge; değilse "1,7×" hapı ve
/// yanında tek dokunuşla 1×'e döndüren ✕ (kullanıcı 2026-11-20: "hız farklı
/// olduğunda hiçbir yerde anlaşılmıyor; görülmeli ve sıfırlama tuşlu olmalı").
class SpeedButton extends StatelessWidget {
  final double speed;
  final VoidCallback onOpen;
  final VoidCallback onReset;
  final String tooltip;
  final Color? color;

  const SpeedButton({
    super.key,
    required this.speed,
    required this.onOpen,
    required this.onReset,
    required this.tooltip,
    this.color,
  });

  static bool isNormal(double v) => (v - 1).abs() < 0.001;

  @override
  Widget build(BuildContext context) {
    if (isNormal(speed)) {
      return IconButton(
        key: const ValueKey('mp-speed'),
        tooltip: tooltip,
        icon: const Icon(AppIcons.speed),
        onPressed: onOpen,
      );
    }
    final fg = color ?? IconTheme.of(context).color;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Material(
        key: const ValueKey('mp-speed'),
        color: (fg ?? AppColors.onMedia).withValues(alpha: 0.16),
        shape: const StadiumBorder(),
        clipBehavior: Clip.antiAlias,
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          InkWell(
            onTap: onOpen,
            child: Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(12, 8, 4, 8),
              child: Text(PlaybackSpeed.label(speed),
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: fg, fontWeight: FontWeight.w700)),
            ),
          ),
          InkWell(
            key: const ValueKey('mp-speed-reset'),
            onTap: onReset,
            child: Tooltip(
              message: context.t('mp.speed_reset'),
              child: Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(2, 8, 8, 8),
                child: Icon(AppIcons.close, size: 16, color: fg),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

class _SpeedBody extends StatefulWidget {
  final double current;
  final ValueChanged<double> onChanged;
  const _SpeedBody({required this.current, required this.onChanged});

  @override
  State<_SpeedBody> createState() => _SpeedBodyState();
}

class _SpeedBodyState extends State<_SpeedBody> {
  late double _v = PlaybackSpeed.snap(widget.current);

  void _apply(double v) {
    final next = PlaybackSpeed.snap(v);
    if ((next - _v).abs() < 0.001) return;
    setState(() => _v = next);
    widget.onChanged(_v);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(Gap.md, Gap.sm, Gap.md, Gap.sm),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            Text(context.t('mp.play_speed'),
                style: theme.textTheme.titleSmall),
            const SizedBox(width: Gap.sm),
            Text(PlaybackSpeed.label(_v),
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700)),
            const Spacer(),
            if (!SpeedButton.isNormal(_v))
              TextButton.icon(
                key: const ValueKey('speed-reset'),
                onPressed: () => _apply(1.0),
                icon: const Icon(AppIcons.undo, size: 18),
                label: Text(context.t('mp.speed_reset')),
              ),
          ]),
          Slider(
            key: const ValueKey('speed-slider'),
            value: _v,
            min: PlaybackSpeed.min,
            max: PlaybackSpeed.max,
            divisions: ((PlaybackSpeed.max - PlaybackSpeed.min) /
                    PlaybackSpeed.step)
                .round(),
            label: PlaybackSpeed.label(_v),
            // Canlı: yalnız 0,05 kademesi değişince motora gider.
            onChanged: _apply,
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final s in PlaybackSpeed.quick)
                  Padding(
                    padding: const EdgeInsetsDirectional.only(end: Gap.xs),
                    child: ChoiceChip(
                      visualDensity: VisualDensity.compact,
                      label: Text(PlaybackSpeed.label(s)),
                      selected: (s - _v).abs() < 0.001,
                      onSelected: (_) => _apply(s),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
