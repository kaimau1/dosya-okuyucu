/// Belge düzenleyicileri için ortak **geri al / yinele** yığını.
///
/// Excel'de (`services/sheet_edit.dart`) doğup Word'de de gerekince buraya
/// taşındı. Faz 20'den (2026-10-23) beri asıl çekirdek
/// `core/edit/edit_history.dart`'taki [EditHistory]; bu dosya eski adları
/// (Excel ve Word yedek editörü, testleri) koruyan ince sarmalayıcıdır.
library;

import 'edit/edit_history.dart';

export 'edit/edit_history.dart';

/// Geri alınabilir tek bir düzenleme adımı (eski ad).
typedef UndoStep = EditCommand;

/// Uygulanmış bir işlemin tersini iki geri çağırımla taşıyan genel adım.
class CallbackUndoStep extends CallbackEdit {
  CallbackUndoStep(super.label, super.apply, super.revert);
}

/// Geri alma/yineleme yığını — [EditHistory]in eski varsayılanlı (100 adım) adı.
class UndoStack extends EditHistory {
  UndoStack({super.limit = 100, super.maxBytes});
}
