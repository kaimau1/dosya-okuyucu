part of '../spreadsheet_editor_screen.dart';

/// Faz 40 / 7: Excel'in tek "Paylaş / Dışa aktar" sayfası.
extension _SpreadsheetShareExportPart on _SpreadsheetEditorScreenState {
  Future<void> _shareExport() => showShareExportSheet(context, entries: [
        ShareExportEntry(
            id: 'pdf',
            icon: AppIcons.pdf,
            label: context.t('xp.print_pdf'),
            run: _printToPdf),
        ShareExportEntry(
            id: 'csv', icon: AppIcons.tableView, label: 'CSV', run: _exportCsv),
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
        ShareExportEntry.nearby(context,
            path: widget.savePath ?? widget.path, beforeSend: () async {
          if (_session.isDirty) await _session.saveNow();
        }),
      ]);
}
