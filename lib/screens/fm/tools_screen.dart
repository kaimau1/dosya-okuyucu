import 'package:flutter/material.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/theme.dart';
import '../../widgets/fm/fm_category_tile.dart';

/// **Tüm araçlar** — panoda yalnız en çok kullanılanlar durur, gerisi burada.
///
/// Kullanıcı 2026-09-26 (sadeleştirme önerisini onayladı): ana ekranda 13
/// araç simgesi vardı; seyrek kullanılanlar (benzer görüntüler, sohbet
/// temizliği, otomatik düzenle, son işlemler…) sık kullanılanlarla aynı
/// ağırlıkta duruyordu. Pano artık kullanım sırasına göre ilk
/// [DashboardTools.visible] aracı gösteriyor; hiçbir araç KALDIRILMADI.
///
/// Araçlar panonun kendi listesinden gelir ([tools]): alt yazılar canlı
/// kalsın diye [listenable] değişince yeniden kurulur (süren iş sayısı,
/// ağdan erişimin açık olup olmadığı).
class ToolsScreen extends StatelessWidget {
  final List<FmTileData> Function() tools;
  final Listenable listenable;

  const ToolsScreen({
    super.key,
    required this.tools,
    required this.listenable,
  });

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(context.t('fm.tools'))),
        body: AnimatedBuilder(
          animation: listenable,
          builder: (context, _) => ListView(
            padding: const EdgeInsets.all(Gap.md),
            children: [FmToolGrid(tools: tools())],
          ),
        ),
      );
}

/// Panodaki araç ızgarasının ölçüsü.
abstract final class DashboardTools {
  /// Panoda gösterilen araç sayısı: 4 sütunda iki satır. Harici bellek kutusu
  /// bunun içinde (hep başta).
  static const visible = 8;

  /// Panoda gösterilecek ilk araçlar; [all] zaten kullanım sırasında.
  static List<T> head<T>(List<T> all) =>
      all.length <= visible ? all : all.sublist(0, visible);
}
