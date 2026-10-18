import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/safe_insets.dart';
import '../../core/theme.dart';
import '../../models/fs_entry.dart';
import '../../services/fm/entry_opener.dart';
import '../../services/fm/photo_insights.dart';
import '../../widgets/fm/fm_entry_icon.dart';

/// **Anılar**: Bu gün · Yerler · İnsanlar (bkz. [PhotoInsights]).
class MemoriesScreen extends StatefulWidget {
  const MemoriesScreen({super.key});

  @override
  State<MemoriesScreen> createState() => _MemoriesScreenState();
}

class _MemoriesScreenState extends State<MemoriesScreen> {
  bool _cancel = false;

  /// İnsanlar sekmesindeki süzgeç: 0 = kişili, 1 = tek kişi, 2 = grup.
  int _people = 0;

  @override
  void initState() {
    super.initState();
    // Tarih/konum okuması hızlı: ekran açılınca kendiliğinden.
    unawaited(PhotoInsights.instance.refresh(isCancelled: () => _cancel));
  }

  @override
  void dispose() {
    _cancel = true;
    super.dispose();
  }

  void _open(List<FsEntry> list, int i) =>
      EntryOpener.open(context, list[i].path);

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: Text(context.t('mem.title')),
          bottom: TabBar(tabs: [
            Tab(text: context.t('mem.tab_day')),
            Tab(text: context.t('mem.tab_places')),
            Tab(text: context.t('mem.tab_people')),
          ]),
        ),
        body: ListenableBuilder(
          listenable: PhotoInsights.instance,
          builder: (context, _) {
            final ins = PhotoInsights.instance;
            final progress = ins.progress;
            return Column(
              children: [
                if (progress != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                        Gap.md, Gap.sm, Gap.md, Gap.xs),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.t(
                              progress.step == 'faces'
                                  ? 'mem.scanning_faces'
                                  : 'mem.scanning',
                              {'n': progress.done, 'total': progress.total}),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const SizedBox(height: Gap.xs),
                        LinearProgressIndicator(
                          value: progress.total == 0
                              ? null
                              : progress.done / progress.total,
                        ),
                      ],
                    ),
                  ),
                Expanded(
                  child: TabBarView(
                    children: [
                      _dayTab(context, ins),
                      _placesTab(context, ins),
                      _peopleTab(context, ins),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _empty(BuildContext context, IconData icon, String text) => Center(
        child: Padding(
          padding: const EdgeInsets.all(Gap.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon,
                  size: 52,
                  color: Theme.of(context).colorScheme.onSurfaceVariant),
              const SizedBox(height: Gap.sm),
              Text(text, textAlign: TextAlign.center),
            ],
          ),
        ),
      );

  Widget _grid(List<FsEntry> list) => SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: Gap.md),
        sliver: SliverGrid.builder(
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 120,
            mainAxisSpacing: 4,
            crossAxisSpacing: 4,
          ),
          itemCount: list.length,
          itemBuilder: (context, i) => LayoutBuilder(
            builder: (context, box) => InkWell(
              onTap: () => _open(list, i),
              child: FmEntryIcon(
                  entry: list[i], size: box.maxWidth, radius: 6),
            ),
          ),
        ),
      );

  Widget _dayTab(BuildContext context, PhotoInsights ins) {
    final byYear = ins.onThisDay();
    if (byYear.isEmpty) {
      return _empty(context, Icons.cake_outlined,
          ins.busy ? context.t('mem.loading') : context.t('mem.day_empty'));
    }
    final now = DateTime.now();
    return CustomScrollView(
      slivers: [
        for (final e in byYear.entries) ...[
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(Gap.md, Gap.md, Gap.md, Gap.sm),
            sliver: SliverToBoxAdapter(
              child: Text(
                context.t('mem.years_ago',
                    {'n': now.year - e.key, 'year': e.key, 'count': e.value.length}),
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
          ),
          _grid(e.value),
        ],
        SliverPadding(padding: withNavInset(context, const EdgeInsets.only(bottom: Gap.lg))),
      ],
    );
  }

  Widget _placesTab(BuildContext context, PhotoInsights ins) {
    final places = ins.places();
    if (places.isEmpty) {
      return _empty(context, Icons.place_outlined,
          ins.busy ? context.t('mem.loading') : context.t('mem.places_empty'));
    }
    return ListView.separated(
      padding: withNavInset(context, const EdgeInsets.all(Gap.md)),
      itemCount: places.length,
      separatorBuilder: (_, __) => const SizedBox(height: Gap.sm),
      itemBuilder: (context, i) {
        final place = places[i];
        final name = place.name.isEmpty
            ? context.t('mem.place_unknown', {'n': i + 1})
            : place.name;
        return Card(
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => _PhotoGridScreen(title: name, photos: place.photos),
            )),
            child: Padding(
              padding: const EdgeInsets.all(Gap.sm),
              child: Row(
                children: [
                  for (final e in place.photos.take(3))
                    Padding(
                      padding: const EdgeInsetsDirectional.only(end: 4),
                      child: FmEntryIcon(entry: e, size: 56, radius: 8),
                    ),
                  const SizedBox(width: Gap.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleSmall),
                        Text(context.t('mem.n_photos', {'n': place.photos.length}),
                            style: Theme.of(context).textTheme.bodySmall),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _peopleTab(BuildContext context, PhotoInsights ins) {
    final pending = ins.facesPending;
    final list = switch (_people) {
      1 => ins.withFaces(1, 1),
      2 => ins.withFaces(3),
      _ => ins.withFaces(1),
    };
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.all(Gap.md),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(context.t('mem.people_note'),
                    style: Theme.of(context).textTheme.bodySmall),
                if (pending > 0 && !ins.busy) ...[
                  const SizedBox(height: Gap.sm),
                  FilledButton.tonalIcon(
                    onPressed: () => ins.scanFaces(isCancelled: () => _cancel),
                    icon: const Icon(Icons.face_retouching_natural),
                    label: Text(context.t('mem.scan_faces', {'n': pending})),
                  ),
                ],
                const SizedBox(height: Gap.sm),
                SegmentedButton<int>(
                  segments: [
                    ButtonSegment(value: 0, label: Text(context.t('mem.people_any'))),
                    ButtonSegment(value: 1, label: Text(context.t('mem.people_one'))),
                    ButtonSegment(value: 2, label: Text(context.t('mem.people_group'))),
                  ],
                  selected: {_people},
                  onSelectionChanged: (v) => setState(() => _people = v.first),
                ),
              ],
            ),
          ),
        ),
        if (list.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: _empty(context, Icons.people_outline,
                context.t(pending > 0 ? 'mem.people_scan_first' : 'mem.people_empty')),
          )
        else
          _grid(list),
        SliverPadding(padding: withNavInset(context, const EdgeInsets.only(bottom: Gap.lg))),
      ],
    );
  }
}

class _PhotoGridScreen extends StatelessWidget {
  final String title;
  final List<FsEntry> photos;
  const _PhotoGridScreen({required this.title, required this.photos});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(title)),
        body: GridView.builder(
          padding: withNavInset(context, const EdgeInsets.all(Gap.sm)),
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 120,
            mainAxisSpacing: 4,
            crossAxisSpacing: 4,
          ),
          itemCount: photos.length,
          itemBuilder: (context, i) => LayoutBuilder(
            builder: (context, box) => InkWell(
              onTap: () => EntryOpener.open(context, photos[i].path),
              child: FmEntryIcon(entry: photos[i], size: box.maxWidth, radius: 6),
            ),
          ),
        ),
      );
}
