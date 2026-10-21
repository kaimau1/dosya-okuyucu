import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../../core/app_icons.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/theme.dart';
import '../../services/fm/fm_env.dart';
import '../../services/fm/fs_scan.dart';

/// Yol çubuğunun bir parçası: görünen ad + mutlak yol.
typedef FmPathSegment = ({String label, String path});

/// [path] için yol hapları. Kök, içinde bulunulan **birimin** köküdür
/// ("Ana bellek", "SD kart") — kullanıcıya `/storage/emulated/0` gösterilmez.
///
/// [volumes] (yol, ad) çiftleri; hiçbiri tutmazsa kök `/` olur ve adı
/// [rootLabel]'dır.
List<FmPathSegment> fmPathSegments(
  String path, {
  required List<({String path, String label})> volumes,
  required String rootLabel,
}) {
  final remainder = p.normalize(path);
  String? rootPath;
  var label = rootLabel;
  for (final v in volumes) {
    if (FsPaths.isInside(v.path, remainder)) {
      rootPath = p.normalize(v.path);
      label = v.label;
      break;
    }
  }
  rootPath ??= '/';
  final segments = <FmPathSegment>[(label: label, path: rootPath)];
  if (remainder.length > rootPath.length) {
    var acc = rootPath;
    for (final s in remainder
        .substring(rootPath.length)
        .split('/')
        .where((s) => s.isNotEmpty)) {
      acc = p.join(acc, s);
      segments.add((label: s, path: acc));
    }
  }
  return segments;
}

/// Gezginin **yol hapları** (Faz 6 / U1-B2).
///
/// Dokunulan hap [onTap]'e verilir; gezgin orada yeni sayfa AÇMAZ, yığında
/// o klasöre kadar GERİ gider (`BrowserScreen.jumpTo`). Eskiden `push`
/// ediliyordu: yığın her dokunuşta büyüyor, geri tuşu kullanıcıyı az önce
/// çıktığı derin klasöre götürüyordu.
class FmPathBar extends StatelessWidget {
  final String path;
  final void Function(String) onTap;

  const FmPathBar({super.key, required this.path, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // `label` birincil bellekte BOŞ (ad çeviriden gelir): kökte yol çubuğu
    // boş bir şerit olarak görünüyordu (kullanıcı ekran görüntüsü
    // 2026-09-23). Panodaki kartla aynı ad kaynağı.
    final segments = fmPathSegments(
      path,
      volumes: [
        for (final v in FmEnv.volumes)
          (path: v.path, label: v.displayLabel(context.t)),
      ],
      rootLabel: context.t('fm.root'),
    );

    // Birimin KÖKÜNDE yol çubuğu gösterilmez: tek parçası başlıkla aynı
    // ("Ana bellek") — 45 dp'lik bir şerit yalnız tekrar ediyordu.
    if (segments.length < 2) return const SizedBox.shrink();

    return Container(
      height: 48,
      alignment: Alignment.centerLeft,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        reverse: true, // uzun yolda son klasör görünür kalsın
        shrinkWrap: true,
        padding: const EdgeInsets.symmetric(horizontal: Gap.sm, vertical: 7),
        itemCount: segments.length,
        itemBuilder: (context, i) {
          final seg = segments[segments.length - 1 - i];
          final isLast = i == 0;
          final isRoot = i == segments.length - 1;
          final fg = isLast ? scheme.onPrimaryContainer : scheme.onSurface;
          return Row(
            children: [
              if (!isRoot)
                Icon(AppIcons.chevron,
                    size: 18, color: scheme.onSurfaceVariant),
              Semantics(
                button: !isLast,
                label: seg.label,
                child: Material(
                  color: isLast
                      ? scheme.primaryContainer
                      : scheme.surfaceContainerHigh,
                  shape: const StadiumBorder(),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: isLast ? null : () => onTap(seg.path),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (isRoot) ...[
                            Icon(AppIcons.device,
                                size: 15,
                                color: isLast
                                    ? scheme.onPrimaryContainer
                                    : scheme.onSurfaceVariant),
                            const SizedBox(width: 4),
                          ],
                          Text(
                            seg.label,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight:
                                  isLast ? FontWeight.w700 : FontWeight.w500,
                              color: fg,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
