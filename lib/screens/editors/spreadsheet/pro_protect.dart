part of '../spreadsheet_editor_screen.dart';

/// **Faz 36 madde 12** — sayfa koruması (Excel uyumlu 16 bit parola özeti;
/// dosyadaki SHA-512 özeti de doğrulanır), korumalı sayfada düzenlenebilir
/// aralıklar (`protectedRanges`) ve yazdırma alanı (`_xlnm.Print_Area`).
extension _SpreadsheetProProtectPart on _SpreadsheetEditorScreenState {
  /// Hücre korumalı sayfada kilitliyse uyarır ve `false` döner.
  bool _guardEditable(Iterable<CellRef> cells) {
    final sheet = _sheet;
    if (sheet == null || !sheet.isProtected) return true;
    if (cells.every((c) => sheet.layout.canEdit(c.row, c.col))) return true;
    _snack(context.t('xp.protected_cell'));
    return false;
  }

  Future<void> _toggleSheetProtection() async {
    _endEdit();
    final sheet = _sheet;
    if (sheet == null) return;
    if (sheet.isProtected) {
      var ok = sheet.protectionNeedsPassword ? false : sheet.unprotect();
      String? error;
      while (!ok && sheet.protectionNeedsPassword) {
        final pw = await _askFilePassword(context.t('xp.unprotect'), error);
        if (pw == null || !mounted) return;
        ok = sheet.unprotect(pw);
        error = context.t('xp.password_wrong');
      }
      _session.changed();
      _partSetState(() {});
      _snack(context.t('xp.unprotected'));
      return;
    }
    DocMoreSheet.show(context, [
      DocMoreGroup(context.t('xp.protect_sheet'), [
        DocMoreItem(AppIcons.lock, context.t('xp.protect_no_pw'),
            () => _protectNow(null)),
        DocMoreItem(AppIcons.lock, context.t('xp.protect_with_pw'), () async {
          final pw = await _askFilePassword(context.t('xp.protect_sheet'), null,
              confirm: true);
          if (pw != null && mounted) _protectNow(pw);
        }),
      ]),
    ]);
  }

  void _protectNow(String? password) {
    final sheet = _sheet;
    if (sheet == null) return;
    sheet.protect(password: password);
    _session.changed();
    _partSetState(() {});
    _snack(context.t('xp.protected'));
  }

  /// Seçili aralık korumalı sayfada düzenlenebilir olsun / olmasın.
  void _toggleAllowEdit() {
    _endEdit();
    final sheet = _sheet;
    if (sheet == null) return;
    final r = _selXlsxRange();
    final on = sheet.layout.allowEditRanges.any((x) =>
        x.r1 == r.r1 && x.c1 == r.c1 && x.r2 == r.r2 && x.c2 == r.c2);
    sheet.setAllowEdit(r, !on);
    _session.changed();
    _partSetState(() {});
    _snack(context.t(on ? 'xp.allow_edit_off' : 'xp.allow_edit_on'));
  }

  void _setPrintArea({required bool clear}) {
    _endEdit();
    final sheet = _sheet;
    if (sheet == null) return;
    sheet.setPrintArea(clear ? null : _selXlsxRange());
    _session.changed();
    _partSetState(() {});
    _snack(context.t(clear ? 'xp.print_area_cleared' : 'xp.print_area_set'));
  }
}
