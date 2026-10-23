/// Bütün editörlerin ortak **geri al / yinele** çekirdeği (Faz 20, 2026-10-23).
///
/// `core/undo_stack.dart`'taki yığın Excel'de doğdu ve yalnız Excel'de tam
/// kullanılıyordu; Word yalnız yedek editörde, slayt/metin hiç, görsel/PDF
/// kendi listeleriyle. Bu sınıf onların üstüne kurulan ortak zemin:
/// * en çok [limit] adım + isteğe bağlı bellek tavanı ([maxBytes]);
/// * **yazma birleştirme** — aynı hedefe ardışık yazım tek adım (Word gibi;
///   bkz. [TextEditStep]);
/// * `canUndo/canRedo` dinlenebilir (düğmeler `ValueListenableBuilder` ile);
/// * **kirli durum**: [markSaved] anındaki adım ile şimdiki adım farklıysa
///   belge kaydedilmemiştir — geri alıp kayıtlı hâle dönmek "kirli değil"
///   sayılır (Word/Excel davranışı).
///
/// Yığın adımın ne yaptığını bilmez, yalnız `apply`/`revert` çağırır.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show TextEditingValue;

/// Geri alınabilir tek bir düzenleme adımı.
abstract class EditCommand {
  /// Adımı anlatan **i18n anahtarı**; metne çevirmek çağıranın işi.
  String get label;

  void apply();
  void revert();
}

/// Kendinden sonra gelen adımı içine katabilen adım (ardışık yazım).
abstract class MergeableEdit implements EditCommand {
  /// [next] bu adıma katıldıysa true (o zaman [next] yığına ayrıca girmez).
  bool tryMerge(EditCommand next);
}

/// Bellek tavanı için adımın yaklaşık boyutu (bayt).
abstract class SizedEdit implements EditCommand {
  int get bytes;
}

/// Uygulanmış bir işlemin tersini iki geri çağırımla taşıyan genel adım.
class CallbackEdit implements EditCommand {
  @override
  final String label;
  final void Function() _apply;
  final void Function() _revert;

  CallbackEdit(this.label, this._apply, this._revert);

  @override
  void apply() => _apply();

  @override
  void revert() => _revert();
}

/// Birden çok adımı TEK geri al adımı olarak taşır (ör. "yapıştır" birden çok
/// paragrafa dokunur).
class CompositeEdit implements EditCommand {
  @override
  final String label;
  final List<EditCommand> steps;

  CompositeEdit(this.label, this.steps);

  @override
  void apply() {
    for (final s in steps) {
      s.apply();
    }
  }

  @override
  void revert() {
    for (final s in steps.reversed) {
      s.revert();
    }
  }
}

/// Bir metin hedefine (paragraf, hücre, metin kutusu) yazma adımı.
///
/// Değer **seçim/imleçle birlikte** saklanır: geri alınca imleç de yazmadan
/// önceki yerine döner. Birleştirme kuralları (Word'e benzer):
/// * aynı [target] ve öncekinin bittiği değerden başlıyor (imleç atlamadı);
/// * araya [mergeWindow]'dan uzun duraklama girmedi;
/// * kelime sınırı: önceki adım boşlukla bittiyse ve yeni adım boşluk dışı
///   bir şey ekliyorsa kesilir — "geri al" son KELİMEYİ geri alır.
class TextEditStep implements MergeableEdit, SizedEdit {
  static const mergeWindow = Duration(seconds: 1);

  @override
  final String label;
  final Object target;
  final TextEditingValue before;
  TextEditingValue after;
  final void Function(TextEditingValue value) write;
  DateTime at;

  TextEditStep({
    required this.target,
    required this.before,
    required this.after,
    required this.write,
    this.label = 'edit.typing',
    DateTime? at,
  }) : at = at ?? DateTime.now();

  @override
  void apply() => write(after);

  @override
  void revert() => write(before);

  @override
  int get bytes => (before.text.length + after.text.length) * 2 + 64;

  @override
  bool tryMerge(EditCommand next) {
    if (next is! TextEditStep) return false;
    if (next.target != target) return false;
    if (next.before.text != after.text) return false;
    if (next.at.difference(at) > mergeWindow) return false;
    if (_startsNewWord(after.text, next.after.text)) return false;
    after = next.after;
    at = next.at;
    return true;
  }

  static bool _startsNewWord(String prev, String next) {
    if (next.length <= prev.length) return false; // silme kesmez
    if (prev.isEmpty) return false;
    final last = prev.codeUnitAt(prev.length - 1);
    final prevSpace = last == 0x20 || last == 0x0A || last == 0x09;
    if (!prevSpace) return false;
    // eklenen kısım boşluk değilse yeni kelime başlıyor
    final added = next.substring(prev.length);
    return added.trim().isNotEmpty;
  }
}

/// Ortak geri al / yinele geçmişi.
class EditHistory extends ChangeNotifier {
  final int limit;

  /// Toplam [SizedEdit.bytes] tavanı (null = yalnız adım sınırı).
  final int? maxBytes;

  final _done = <EditCommand>[];
  final _doneIds = <int>[];
  final _undone = <EditCommand>[];
  final _undoneIds = <int>[];
  int _nextId = 1;
  int _savedId = 0;
  bool _mergeBroken = false;

  final ValueNotifier<bool> _canUndo = ValueNotifier(false);
  final ValueNotifier<bool> _canRedo = ValueNotifier(false);
  final ValueNotifier<bool> _dirty = ValueNotifier(false);

  EditHistory({this.limit = 200, this.maxBytes});

  bool get canUndo => _done.isNotEmpty;
  bool get canRedo => _undone.isNotEmpty;
  int get depth => _done.length;

  ValueListenable<bool> get canUndoListenable => _canUndo;
  ValueListenable<bool> get canRedoListenable => _canRedo;

  /// [markSaved]'dan bu yana belge değişti mi.
  bool get isDirty => _topId != _savedId;
  ValueListenable<bool> get dirtyListenable => _dirty;

  /// Son adımın etiketi (geri al düğmesinin ipucu için).
  String? get undoLabel => _done.isEmpty ? null : _done.last.label;
  String? get redoLabel => _undone.isEmpty ? null : _undone.last.label;

  int get _topId => _doneIds.isEmpty ? 0 : _doneIds.last;

  /// Adımı UYGULAR ve geçmişe koyar.
  void push(EditCommand step) {
    step.apply();
    record(step);
  }

  /// Adım zaten uygulandıysa (çağıran kendi yolundan yazdıysa) yalnız kaydeder.
  void record(EditCommand step) {
    _undone.clear();
    _undoneIds.clear();
    final last = _done.isEmpty ? null : _done.last;
    if (!_mergeBroken && last is MergeableEdit && last.tryMerge(step)) {
      // Birleşen adım içeriği değiştirdi → yeni kimlik (kirli durum doğru kalsın).
      _doneIds[_doneIds.length - 1] = _nextId++;
    } else {
      _done.add(step);
      _doneIds.add(_nextId++);
    }
    _mergeBroken = false;
    _trim();
    _sync();
  }

  /// Bir sonraki adımın öncekiyle birleşmesini engeller (imleç atladı,
  /// biçim düğmesine basıldı, editör odak kaybetti).
  void breakMerge() => _mergeBroken = true;

  /// Son adımı geri alır; adım yoksa null.
  EditCommand? undo() {
    if (_done.isEmpty) return null;
    final step = _done.removeLast();
    final id = _doneIds.removeLast();
    step.revert();
    _undone.add(step);
    _undoneIds.add(id);
    _mergeBroken = true;
    _sync();
    return step;
  }

  /// Geri alınan son adımı yineler; adım yoksa null.
  EditCommand? redo() {
    if (_undone.isEmpty) return null;
    final step = _undone.removeLast();
    final id = _undoneIds.removeLast();
    step.apply();
    _done.add(step);
    _doneIds.add(id);
    _mergeBroken = true;
    _sync();
    return step;
  }

  /// Şimdiki durumu "kaydedildi" olarak işaretler.
  void markSaved() {
    _savedId = _topId;
    _mergeBroken = true;
    _sync();
  }

  void clear() {
    _done.clear();
    _doneIds.clear();
    _undone.clear();
    _undoneIds.clear();
    _savedId = 0;
    _sync();
  }

  void _trim() {
    while (_done.length > limit) {
      _dropOldest();
    }
    final cap = maxBytes;
    if (cap == null) return;
    var total = 0;
    for (final s in _done) {
      if (s is SizedEdit) total += s.bytes;
    }
    while (total > cap && _done.length > 1) {
      final s = _done.first;
      if (s is SizedEdit) total -= s.bytes;
      _dropOldest();
    }
  }

  void _dropOldest() {
    _done.removeAt(0);
    final id = _doneIds.removeAt(0);
    // Kayıtlı nokta düştüyse ona bir daha dönülemez.
    if (id == _savedId) _savedId = -1;
  }

  void _sync() {
    _canUndo.value = canUndo;
    _canRedo.value = canRedo;
    _dirty.value = isDirty;
    notifyListeners();
  }

  @override
  void dispose() {
    _canUndo.dispose();
    _canRedo.dispose();
    _dirty.dispose();
    super.dispose();
  }
}

/// Bütün durumu tek değer olarak taşıyan editörler için (görsel düzenleyici,
/// PDF kalem) anlık görüntü geçmişi: değişiklikten ÖNCEKİ değer itilir.
///
/// Faz 20 / IM4: görsel düzenleyicide kaydırıcı ve kırpma girişleri 30'luk
/// sınırı atlıyordu (yalnız bir yol sınırı uyguluyordu) ve yinele yoktu.
/// Bütün yollar [push]'tan geçer; sınır tek yerde.
class SnapshotHistory<T> {
  final int limit;
  final _undo = <T>[];
  final _redo = <T>[];

  SnapshotHistory({this.limit = 30});

  bool get canUndo => _undo.isNotEmpty;
  bool get canRedo => _redo.isNotEmpty;
  int get depth => _undo.length;

  /// Değişiklikten ÖNCEKİ değeri kaydeder; yineleme dalı silinir.
  void push(T before) {
    _undo.add(before);
    _redo.clear();
    while (_undo.length > limit) {
      _undo.removeAt(0);
    }
  }

  /// [current]'i yinelemeye koyar, önceki değeri döndürür (yoksa null).
  T? undo(T current) {
    if (_undo.isEmpty) return null;
    _redo.add(current);
    return _undo.removeLast();
  }

  /// [current]'i geri almaya koyar, yinelenen değeri döndürür (yoksa null).
  T? redo(T current) {
    if (_redo.isEmpty) return null;
    _undo.add(current);
    return _redo.removeLast();
  }

  void clear() {
    _undo.clear();
    _redo.clear();
  }
}
