import 'package:flutter/material.dart';

import '../../core/app_icons.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/motion.dart';
import '../../models/fs_entry.dart';
import '../../widgets/fm/fm_entry_icon.dart' show FmColors;
import 'category_screen.dart';
import 'swipe_pager.dart';

/// **APK ve Arşivler** (2026-11-10, kullanıcı: *"arşivler çok kullanılan bir
/// sekme değil … APK ve arşivler olsun, iki sekme halinde çalışsın,
/// varsayılan ilk sekme APK, yana kaydırarak arşivlere geçilsin"*).
///
/// Panodaki iki seyrek kutu tek kutuda birleşti. Sekmeler [SwipePager]
/// üstünde: seçim sürerken yana kaydırma kilidi ([SwipeHold]) aynen çalışır.
class ApkArchiveScreen extends StatefulWidget {
  final List<FsEntry> apkFiles;
  final List<FsEntry> archiveFiles;
  final Future<List<FsEntry>> Function()? loadApks;
  final Future<List<FsEntry>> Function()? loadArchives;

  const ApkArchiveScreen({
    super.key,
    required this.apkFiles,
    required this.archiveFiles,
    this.loadApks,
    this.loadArchives,
  });

  @override
  State<ApkArchiveScreen> createState() => _ApkArchiveScreenState();
}

class _ApkArchiveScreenState extends State<ApkArchiveScreen>
    with SingleTickerProviderStateMixin {
  final _pages = PageController();
  late final TabController _tabs = TabController(length: 2, vsync: this);

  @override
  void dispose() {
    _pages.dispose();
    _tabs.dispose();
    super.dispose();
  }

  Widget _tabBar(BuildContext context) => TabBar(
        controller: _tabs,
        onTap: (i) => _pages.animateToPage(i,
            duration: Motion.of(context, Motion.medium),
            curve: Curves.easeOutCubic),
        tabs: [
          Tab(
            icon: const Icon(AppIcons.installMobile, size: 18),
            iconMargin: EdgeInsets.zero,
            height: 52,
            text: context.t('fm.apk_tab'),
          ),
          Tab(
            icon: Icon(FmColors.iconFor(FmCategory.archive), size: 18),
            iconMargin: EdgeInsets.zero,
            height: 52,
            text: context.t('enum.cat_archive'),
          ),
        ],
      );

  @override
  Widget build(BuildContext context) {
    final title = context.t('fm.apk_archives');
    return SwipePager(
      controller: _pages,
      showHint: false,
      onPageChanged: _tabs.animateTo,
      pages: [
        SwipePage(
          label: context.t('fm.apk_tab'),
          icon: AppIcons.installMobile,
          color: FmColors.forCategory(FmCategory.apk),
          builder: (context) => CategoryScreen(
            title: title,
            files: widget.apkFiles,
            loadAll: widget.loadApks,
            header: _tabBar(context),
          ),
        ),
        SwipePage(
          label: context.t('enum.cat_archive'),
          icon: FmColors.iconFor(FmCategory.archive),
          color: FmColors.forCategory(FmCategory.archive),
          builder: (context) => CategoryScreen(
            title: title,
            files: widget.archiveFiles,
            loadAll: widget.loadArchives,
            header: _tabBar(context),
          ),
        ),
      ],
    );
  }
}
