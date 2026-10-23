import 'package:flutter/material.dart';

import '../../core/l10n/app_strings.dart';
import 'activity_screen.dart';
import 'jobs_screen.dart';
import 'new_files_screen.dart';
import 'open_history_screen.dart';
import '../../core/app_icons.dart';

/// Geçmiş ekranının bölümleri (sıra = alt çubuktaki sıra).
enum HistorySection { opened, produced, jobs, incoming }

/// **Geçmiş** — tek kapı, dört bölüm (2026-10-21, Faz 2 / FAZ_PLANI §3.5).
///
/// Eskiden panoda beş ayrı kapı vardı: Son açılanlar, Yaptıklarım, İşlemler,
/// Son işlemler (geri al) ve Yeni dosyalar. Kullanıcı "dün ne yaptım"ı
/// sorarken hangisine bakacağını bilmek zorundaydı. Artık:
/// - **Açılanlar** — [OpenHistoryScreen]
/// - **Üretilenler** — [ActivityScreen] (küçültülen video, düzenlenen PDF…)
/// - **İşlemler** — [JobsScreen] (canlı + biten işler; geri alınabilir
///   taşımalar başlıktaki "Geri al" düğmesinde)
/// - **Yeni gelenler** — [NewFilesScreen]
///
/// Bölümler kendi başlık çubuklarını ve eylemlerini korur; bu ekran yalnız
/// aralarında geçişi sağlar. Bir bölüm ilk kez seçilince kurulur (beşi birden
/// açılışta disk taramasın), sonra ayakta kalır.
class HistoryScreen extends StatefulWidget {
  final HistorySection initial;

  const HistoryScreen({super.key, this.initial = HistorySection.opened});

  static Future<void> open(BuildContext context,
          [HistorySection section = HistorySection.opened]) =>
      Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => HistoryScreen(initial: section)));

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  late HistorySection _section = widget.initial;
  late final Set<HistorySection> _built = {widget.initial};

  Widget _page(HistorySection s) => switch (s) {
        HistorySection.opened => const OpenHistoryScreen(),
        HistorySection.produced => const ActivityScreen(),
        HistorySection.jobs => const JobsScreen(),
        HistorySection.incoming =>
          NewFilesScreen(active: _section == HistorySection.incoming),
      };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _section.index,
        children: [
          for (final s in HistorySection.values)
            _built.contains(s) ? _page(s) : const SizedBox.shrink(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _section.index,
        onDestinationSelected: (i) => setState(() {
          _section = HistorySection.values[i];
          _built.add(_section);
        }),
        destinations: [
          NavigationDestination(
            icon: const Icon(AppIcons.history),
            label: context.t('hist.opened'),
          ),
          NavigationDestination(
            icon: const Icon(AppIcons.historyEdu),
            label: context.t('hist.produced'),
          ),
          NavigationDestination(
            icon: const Icon(AppIcons.playlistAddCheckCircle),
            label: context.t('hist.jobs'),
          ),
          NavigationDestination(
            icon: const Icon(AppIcons.moveToInbox),
            label: context.t('hist.incoming'),
          ),
        ],
      ),
    );
  }
}
