part of '../slides_editor_screen.dart';

/// Faz 40 / 7: Slayt'ın tek "Paylaş / Dışa aktar" sayfası.
extension _SlidesShareExportPart on _SlidesEditorScreenState {
  Future<void> _shareExport() => showShareExportSheet(context, entries: [
        ShareExportEntry(
            id: 'pdf',
            icon: AppIcons.pdf,
            label: context.t('sl.to_pdf'),
            run: _exportPdf),
        ShareExportEntry(
            id: 'png_one',
            icon: AppIcons.image,
            label: context.t('sp.png_one'),
            run: () => _exportImages(only: _curIndex)),
        ShareExportEntry(
            id: 'png_all',
            icon: AppIcons.image,
            label: context.t('sp.png_all'),
            run: _exportImages),
        ShareExportEntry(
            id: 'video',
            icon: AppIcons.play,
            label: context.t('sp.video_export'),
            hint: context.t('sp.video_hint'),
            run: _exportVideo),
        ShareExportEntry(
            id: 'share',
            icon: AppIcons.share,
            label: context.t('common.share'),
            hint: widget.name,
            group: ShareExportGroup.send,
            run: _export),
        ShareExportEntry(
            id: 'download',
            icon: AppIcons.download,
            label: context.t('common.download'),
            group: ShareExportGroup.send,
            run: _download),
        ShareExportEntry.nearby(context, path: widget.path,
            beforeSend: () async {
          if (_session.isDirty) await _session.saveNow();
        }),
      ]);
}
