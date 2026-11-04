import 'package:flutter/material.dart';

import '../../core/app_icons.dart';
import '../../core/l10n/app_strings.dart';
import '../../services/fm/fm_env.dart';
import '../../services/fm/fs_scan.dart';
import 'chat_cleanup_screen.dart';
import 'cleanup_screen.dart';
import 'downloads_screen.dart';
import 'jobs_screen.dart';
import 'organize_screen.dart';

/// İşlemler merkezinin sekmeleri (sıra = ekrandaki sıra).
enum OpsTab { jobs, cleanup, chat, organize }

/// **İşlemler** — sekmeli merkez (2026-11-04, kullanıcı: *"sohbet medyası
/// temizliği, düzenle, yer aç işlemler içerisine girecek ve işlemler menüsü
/// üstte olacak şekilde sekmeler haline gelecek"*).
///
/// Sekmeler: **İşlemler** (süren + biten işler, biten işler 2 sütunlu kart) ·
/// **Yer aç** · **Sohbet medyası** · **Düzenle**. Son açılanlar ve Yeni
/// gelenler burada YOK — onlar panodaki **Geçmiş** kutusunda.
///
/// Sekme ilk seçildiğinde kurulur ve sonra ayakta kalır ([IndexedStack]):
/// Yer aç'ın çözümlemesi ya da sohbet taraması yalnız kullanıcı o sekmeye
/// geçince başlar, sekmeler arasında gidip gelince baştan başlamaz. Kaydırarak
/// sekme değiştirme bilinçli olarak YOK: Yer aç kartları ve sohbet kovaları
/// kendi içinde yatay hareket taşıyor.
class OperationsScreen extends StatefulWidget {
  final OpsTab initial;

  /// Panonun elindeki hazır indeks (Yer aç ikinci bir tam tarama yapmasın).
  final StorageIndex? index;

  const OperationsScreen({super.key, this.initial = OpsTab.jobs, this.index});

  static Future<void> open(BuildContext context,
          {OpsTab tab = OpsTab.jobs, StorageIndex? index}) =>
      Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => OperationsScreen(initial: tab, index: index)));

  @override
  State<OperationsScreen> createState() => _OperationsScreenState();
}

class _OperationsScreenState extends State<OperationsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(
    length: OpsTab.values.length,
    vsync: this,
    initialIndex: widget.initial.index,
  )..addListener(_onTab);

  late final Set<OpsTab> _built = {widget.initial};

  void _onTab() {
    _built.add(OpsTab.values[_tabs.index]);
    setState(() {});
  }

  @override
  void dispose() {
    _tabs
      ..removeListener(_onTab)
      ..dispose();
    super.dispose();
  }

  Widget _page(OpsTab tab) => switch (tab) {
        OpsTab.jobs => const JobsScreen(embedded: true),
        OpsTab.cleanup =>
          CleanupScreen(index: widget.index, embedded: true),
        OpsTab.chat => const ChatCleanupScreen(embedded: true),
        OpsTab.organize => OrganizeScreen(
            path: downloadsPathIn(FmEnv.primaryRoot) ?? FmEnv.primaryRoot,
            embedded: true,
          ),
      };

  (IconData, String) _spec(BuildContext context, OpsTab tab) => switch (tab) {
        OpsTab.jobs => (AppIcons.playlistAddCheckCircle, context.t('jb.title')),
        OpsTab.cleanup => (AppIcons.cleanEmpty, context.t('clean.title')),
        OpsTab.chat => (AppIcons.forum, context.t('ops.tab_chat')),
        OpsTab.organize =>
          (AppIcons.autoAwesomeMotion, context.t('ops.tab_organize')),
      };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.t('jb.title')),
        bottom: TabBar(
          controller: _tabs,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: [
            for (final tab in OpsTab.values)
              () {
                final (icon, label) = _spec(context, tab);
                return Tab(
                  height: 44,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(icon, size: 18),
                      const SizedBox(width: 6),
                      Text(label),
                    ],
                  ),
                );
              }(),
          ],
        ),
      ),
      body: IndexedStack(
        index: _tabs.index,
        children: [
          for (final tab in OpsTab.values)
            TickerMode(
              enabled: tab.index == _tabs.index,
              child: _built.contains(tab) ? _page(tab) : const SizedBox.shrink(),
            ),
        ],
      ),
    );
  }
}
