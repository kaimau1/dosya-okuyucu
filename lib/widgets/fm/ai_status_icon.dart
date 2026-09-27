import 'package:flutter/material.dart';

import '../../services/fm/ai_analyzer.dart';
import '../../services/fm/ai_index.dart';

/// AI simgesi — **canlı durum taşır** (panonun üst çubuğunda).
///
/// Panodaki AI kartının yerini aldı (2026-08-17), 2026-09-27'de alt
/// çubuktan panonun üst çubuğuna taşındı. Üç hâl:
/// * analiz sürüyorsa simgenin çevresinde ince bir ilerleme halkası,
/// * bekleyen öneri varsa sayı rozeti,
/// * ikisi de yoksa düz simge (gürültü yok).
class AiStatusIcon extends StatelessWidget {
  final bool selected;
  const AiStatusIcon({super.key, this.selected = false});

  @override
  Widget build(BuildContext context) {
    final icon =
        Icon(selected ? Icons.auto_awesome : Icons.auto_awesome_outlined);
    return ValueListenableBuilder<AiProgress>(
      valueListenable: AiAnalyzer.progress,
      builder: (context, progress, _) => ValueListenableBuilder<int>(
        valueListenable: AiIndex.revision,
        builder: (context, _, __) {
          final pending = AiIndex.suggestionCount;
          if (progress.isBusy) {
            return Stack(
              alignment: Alignment.center,
              clipBehavior: Clip.none,
              children: [
                SizedBox(
                  width: 30,
                  height: 30,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    value: progress.total == 0 ? null : progress.fraction,
                  ),
                ),
                icon,
              ],
            );
          }
          if (pending <= 0) return icon;
          return Badge(
            label: Text('$pending'),
            child: icon,
          );
        },
      ),
    );
  }
}
