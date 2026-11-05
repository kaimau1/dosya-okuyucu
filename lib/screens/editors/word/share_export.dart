part of '../word_editor_screen.dart';

/// Faz 40 / 7: Word sayfa görünümünün tek "Paylaş / Dışa aktar" sayfası.
/// Biçim dönüştürmeleri (PDF, ODT, RTF …) Mobil editörde; burada belgenin
/// kendisi gönderilir.
extension _WordShareExportPart on _WordEditorScreenState {
  Future<void> _shareExport() => showShareExportSheet(context, entries: [
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
