import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_state.dart';
import '../../services/fm/folder_size_cache.dart';
import '../../core/l10n/app_strings.dart';
import '../../models/fm_layout.dart';
import '../../models/fs_entry.dart';
import '../../models/media_open_with.dart';
import '../../models/photo_group.dart';
import '../../widgets/fm/fm_layout_sheet.dart';
import '../fm/folder_picker_screen.dart';
import 'settings_widgets.dart';

/// Klasör listelerinin yerleşimi (liste / 2-3-4 sütun ızgara).
class ListLayoutTile extends StatelessWidget {
  const ListLayoutTile({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    return SettingTile(
      icon: Icons.view_list_outlined,
      title: context.t('fmset.list_layout'),
      subtitle: context.t(appState.fmLayout.descriptionKey),
      value: context.t(appState.fmLayout.labelKey),
      onTap: () async {
        final picked =
            await showFmLayoutSheet(context, current: appState.fmLayout);
        if (picked != null) await appState.setFmLayout(picked);
      },
    );
  }
}

/// Fotoğraf/video zaman ekseninin ızgara yoğunluğu.
class PhotoGridTile extends StatelessWidget {
  const PhotoGridTile({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    return SettingTile(
      icon: Icons.grid_view_outlined,
      title: context.t('fmset.photo_grid'),
      subtitle: context.t('fmset.grid_density'),
      value: context.t(appState.fmPhotoLayout.labelKey),
      onTap: () async {
        final picked = await showFmLayoutSheet(
          context,
          current: appState.fmPhotoLayout,
          title: context.t('fmset.grid_density'),
          // Fotoğraf zaman ekseninde liste düzeni anlamsız.
          allowLists: false,
        );
        if (picked != null) await appState.setFmPhotoLayout(picked);
      },
    );
  }
}

/// Galerinin zaman ölçeği (gün / ay / yıl) — galerideki şeritle AYNI alanı
/// yazar, ikisi hep tutarlıdır.
class PhotoGroupTile extends StatelessWidget {
  const PhotoGroupTile({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    return SettingChoice<PhotoGroup>(
      icon: Icons.calendar_month_outlined,
      title: context.t('fmset.group_photos'),
      subtitle: context
          .t('fmset.group_photos_sub', {'unit': context.t('fmset.grouping')}),
      options: [
        for (final g in PhotoGroup.values) (g, context.t(g.labelKey)),
      ],
      selected: appState.fmPhotoGroup,
      onChanged: appState.setFmPhotoGroup,
    );
  }
}

/// Varsayılan sıralama ve yönü.
class DefaultSortTile extends StatelessWidget {
  const DefaultSortTile({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    return SettingTile(
      icon: Icons.sort,
      title: context.t('fmset.default_sort'),
      value: '${context.t(appState.fmSort.labelKey)} '
          '${appState.fmSortDesc ? '↓' : '↑'}',
      trailing: PopupMenuButton<String>(
        icon: const Icon(Icons.arrow_drop_down),
        onSelected: (v) {
          if (v == 'dir') {
            appState.setFmSort(appState.fmSort,
                descending: !appState.fmSortDesc);
          } else {
            appState.setFmSort(FmSort.values.firstWhere((s) => s.name == v));
          }
        },
        itemBuilder: (ctx) => [
          for (final s in FmSort.values)
            PopupMenuItem(value: s.name, child: Text(ctx.t(s.labelKey))),
          const PopupMenuDivider(),
          PopupMenuItem(value: 'dir', child: Text(ctx.t('fmset.reverse_dir'))),
        ],
      ),
    );
  }
}

/// Nokta ile başlayan dosya/klasörler görünsün mü?
class ShowHiddenTile extends StatelessWidget {
  const ShowHiddenTile({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    return SettingSwitch(
      icon: Icons.visibility_outlined,
      title: context.t('fmset.show_hidden'),
      subtitle: context.t('fmset.show_hidden_sub'),
      value: appState.fmShowHidden,
      onChanged: appState.setFmShowHidden,
    );
  }
}

/// Küçük resimler (görsel/video önizlemesi).
class ThumbnailsTile extends StatelessWidget {
  const ThumbnailsTile({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    return SettingSwitch(
      icon: Icons.image_outlined,
      title: context.t('fmset.thumbnails'),
      subtitle: context.t('fmset.thumbnails_sub'),
      value: appState.fmThumbnails,
      onChanged: appState.setFmThumbnails,
    );
  }
}

/// **Listede klasör boyutu** (2026-09-04).
///
/// Varsayılan KAPALI: bir klasörün boyutu ancak altındaki her şey gezilerek
/// bulunur. Açıkken yalnız ekranda görünen klasörler ölçülüyor
/// (`FolderSizeCache`), kapatılınca ölçüler bellekten düşüyor.
class FolderSizesTile extends StatelessWidget {
  const FolderSizesTile({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    return SettingSwitch(
      icon: Icons.folder_open_outlined,
      title: context.t('fmset.folder_sizes'),
      subtitle: context.t('fmset.folder_sizes_sub'),
      value: appState.fmFolderSizes,
      onChanged: (value) async {
        await appState.setFmFolderSizes(value);
        if (!value) FolderSizeCache.clear();
      },
    );
  }
}

/// **Kaldığın yerden devam** — video/ses konumu ve belge sayfası.
class ResumePositionTile extends StatelessWidget {
  const ResumePositionTile({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    return SettingSwitch(
      icon: Icons.play_circle_outline,
      title: context.t('fmset.resume'),
      subtitle: context.t('fmset.resume_sub'),
      value: appState.resumePosition,
      onChanged: appState.setResumePosition,
    );
  }
}

/// Medyanın uygulama içinde mi, sistem oynatıcısında mı açılacağı.
class MediaOpenWithTile extends StatelessWidget {
  const MediaOpenWithTile({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    return SettingTile(
      icon: Icons.play_circle_outline,
      title: context.t('fmset.media_open_with'),
      subtitle: context.t(appState.fmMediaOpenWith.descriptionKey),
      value: context.t(appState.fmMediaOpenWith.labelKey),
      trailing: PopupMenuButton<MediaOpenWith>(
        icon: const Icon(Icons.arrow_drop_down),
        onSelected: appState.setFmMediaOpenWith,
        itemBuilder: (ctx) => [
          for (final v in MediaOpenWith.values)
            PopupMenuItem(value: v, child: Text(ctx.t(v.labelKey))),
        ],
      ),
    );
  }
}

/// Açılış klasörü: boşken pano ilk ekran kalır.
///
/// Dosyalarını hep aynı klasörde tutan kullanıcı her açılışta panodan oraya
/// tıklaya tıklaya gidiyordu (KALANLAR maddesi).
class StartFolderTile extends StatelessWidget {
  const StartFolderTile({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final set = appState.fmStartFolder.isNotEmpty;
    return SettingTile(
      icon: Icons.home_outlined,
      title: context.t('fmset.start_folder'),
      subtitle: set
          ? appState.fmStartFolder
          : context.t('fmset.start_folder_none'),
      wrapSubtitle: true,
      trailing: !set
          ? const Icon(Icons.chevron_right)
          : IconButton(
              tooltip: context.t('fmset.start_folder_clear'),
              icon: const Icon(Icons.close),
              onPressed: () => appState.setFmStartFolder(''),
            ),
      onTap: () async {
        final picked = await Navigator.of(context).push<String>(
          MaterialPageRoute(
            builder: (_) => FolderPickerScreen(
              sources: const [],
              actionLabel: context.t('fmset.start_folder_pick'),
            ),
          ),
        );
        if (picked != null) await appState.setFmStartFolder(picked);
      },
    );
  }
}
