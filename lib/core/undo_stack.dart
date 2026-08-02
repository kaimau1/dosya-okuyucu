/// Belge düzenleyicileri için ortak **geri al / yinele** yığını.
///
/// Excel'de (`services/sheet_edit.dart`) doğup Word'de de gerekince buraya
/// taşındı: kural aynı, taşıdığı veri farklı. Yığın adımın ne yaptığını
/// bilmez — yalnız `apply`/`revert` çağırır — bu yüzden yeni bir işlem
/// eklemek yığına dokunmadan mümkün.
library;

/// Geri alınabilir tek bir düzenleme adımı.
abstract class UndoStep {
  /// Adımı anlatan **i18n anahtarı** (`excel.undo_paste` gibi); metne çevirmek
  /// çağıranın işi — çekirdek dilden habersiz kalsın.
  String get label;

  void apply();
  void revert();
}

/// Uygulanmış bir işlemin tersini iki geri çağırımla taşıyan genel adım.
///
/// Yapısal işlemler (paragraf ekle/sil, satır sil) ve biçim değişiklikleri
/// buradan geçer: "önce/sonra" değer çifti çıkarmak yerine iki kapanış yazmak
/// hem kısa hem de yan etkileri (dosya nesnesine yazma) doğal biçimde taşır.
class CallbackUndoStep implements UndoStep {
  @override
  final String label;

  final void Function() _apply;
  final void Function() _revert;

  CallbackUndoStep(this.label, this._apply, this._revert);

  @override
  void apply() => _apply();

  @override
  void revert() => _revert();
}

/// Geri alma/yineleme yığını.
///
/// Yeni bir adım eklendiğinde yineleme dalı silinir (her editörde olduğu gibi).
/// [limit] bellek tavanı: en eski adımlar düşer.
class UndoStack {
  final int limit;
  final _done = <UndoStep>[];
  final _undone = <UndoStep>[];

  UndoStack({this.limit = 100});

  bool get canUndo => _done.isNotEmpty;
  bool get canRedo => _undone.isNotEmpty;
  int get depth => _done.length;

  /// Adımı UYGULAR ve yığına koyar.
  void push(UndoStep step) {
    step.apply();
    record(step);
  }

  /// Adım zaten uygulandıysa (çağıran kendi yolundan yazdıysa) yalnız kaydeder.
  void record(UndoStep step) {
    _done.add(step);
    _undone.clear();
    while (_done.length > limit) {
      _done.removeAt(0);
    }
  }

  /// Son adımı geri alır; adım yoksa null.
  UndoStep? undo() {
    if (_done.isEmpty) return null;
    final step = _done.removeLast();
    step.revert();
    _undone.add(step);
    return step;
  }

  /// Geri alınan son adımı yineler; adım yoksa null.
  UndoStep? redo() {
    if (_undone.isEmpty) return null;
    final step = _undone.removeLast();
    step.apply();
    _done.add(step);
    return step;
  }

  void clear() {
    _done.clear();
    _undone.clear();
  }
}
