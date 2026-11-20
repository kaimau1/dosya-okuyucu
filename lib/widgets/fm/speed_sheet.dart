import 'package:flutter/material.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/theme.dart';
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

Future<void> showSpeedSheet(
  BuildContext context, {
  required double current,
  required ValueChanged<double> onChanged,
}) {
  return showAppSheet<void>(
    context,
    title: context.t('mp.play_speed'),
    builder: (_) => _SpeedBody(current: current, onChanged: onChanged),
  );
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
    setState(() => _v = PlaybackSpeed.snap(v));
    widget.onChanged(_v);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(Gap.md, 0, Gap.md, Gap.md),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(PlaybackSpeed.label(_v),
              textAlign: TextAlign.center, style: theme.textTheme.headlineSmall),
          Slider(
            key: const ValueKey('speed-slider'),
            value: _v,
            min: PlaybackSpeed.min,
            max: PlaybackSpeed.max,
            divisions: ((PlaybackSpeed.max - PlaybackSpeed.min) /
                    PlaybackSpeed.step)
                .round(),
            label: PlaybackSpeed.label(_v),
            // Sürüklerken yalnız etiket; motora bırakınca gider (her karede
            // hız değiştirmek sesi takırdatır).
            onChanged: (v) => setState(() => _v = PlaybackSpeed.snap(v)),
            onChangeEnd: _apply,
          ),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: Gap.sm,
            children: [
              for (final s in PlaybackSpeed.quick)
                ChoiceChip(
                  label: Text(PlaybackSpeed.label(s)),
                  selected: (s - _v).abs() < 0.001,
                  onSelected: (_) => _apply(s),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
