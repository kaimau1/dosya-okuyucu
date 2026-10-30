import 'dart:typed_data';

/// Belge baytları üzerinde çalışan, **yeniden oynatılabilir** bir PDF işlemi
/// (paragrafı yeniden yaz, görseli taşı, sayfayı döndür …).
///
/// Aynı girdiye her seferinde aynı çıktıyı vermeli: geri alma bellekteki ara
/// sonucu bıraktıysa adım, önceki hâlden yeniden oynatılarak kurulur.
typedef PdfByteOp = Future<List<int>> Function(List<int> bytes);

/// PDF düzenleyicinin **işlem listesi** (Faz 31 / PD4, 2026-10-30).
///
/// Eskiden her düzenleme tüm dosyanın disk kopyasını (`undo_N.pdf`) bırakıyor,
/// yinele yoktu, sayfa değişiminde PDF diskten yeniden okunuyordu. Burada:
/// * her adım bir **komut** — ya belge baytlarını değiştiren bir [PdfByteOp],
///   ya da yalnız kaydedilene kadar ekranda yaşayan katmanın (eklenen yazı/
///   imza, form değerleri) yeni hâli ([S], değişmez nesne);
/// * belgenin güncel hâli **bellekte** ([bytes]) — disk G/Ç yok;
/// * ara sonuçlar bir bellek bütçesi içinde önbellekte tutulur; bütçe aşılınca
///   en eskiler bırakılır ve gerekirse en yakın tutulan hâlden **yeniden
///   oynatılır** (dosya anlık görüntüsü yerine işlem listesi);
/// * **yinele** var; [dirty] kayıt anındaki adıma göre hesaplanır (geri alıp
///   kayıtlı hâle dönmek "kirli değil" sayılır — Word/Excel davranışı).
class PdfEditHistory<S> {
  PdfEditHistory(List<int> base, S initialLayer,
      {this.cacheBudgetBytes = 48 * 1024 * 1024})
      : _base = _asBytes(base),
        _initialLayer = initialLayer;

  /// Önbellekteki ara sonuçların toplam üst sınırı (bayt). Taban ve güncel
  /// hâl bu sınırın dışında, hep tutulur.
  final int cacheBudgetBytes;

  final Uint8List _base;
  final S _initialLayer;
  final List<_Step<S>> _steps = [];
  final List<_Step<S>> _redo = [];

  /// Adım sırası → o adımdan SONRAKİ belge baytları (yalnız bayt adımları).
  final Map<int, Uint8List> _cache = {};
  Uint8List? _current;
  int _savedAt = 0;

  /// Adım uzunluğu: kaçıncı adımda kaydedildiğini [markSaved] tutar.
  int get length => _steps.length;

  bool get canUndo => _steps.isNotEmpty;
  bool get canRedo => _redo.isNotEmpty;

  /// Kayıttan beri değişiklik var mı?
  bool get dirty => _savedAt != _steps.length;

  /// Sıradaki geri al / yinele adımının etiketi (i18n anahtarı).
  String? get undoLabel => _steps.isEmpty ? null : _steps.last.label;
  String? get redoLabel => _redo.isEmpty ? null : _redo.last.label;

  /// Belgenin güncel hâli (bellekte).
  Uint8List get bytes => _current ?? _base;

  /// Kaydedilene kadar ekranda yaşayan katmanın güncel hâli.
  S get layer {
    for (var i = _steps.length - 1; i >= 0; i--) {
      final l = _steps[i].layer;
      if (l != null) return l;
    }
    return _initialLayer;
  }

  /// Önbellekteki ara sonuçların toplamı (test + teşhis).
  int get cachedBytes =>
      _cache.values.fold(0, (sum, b) => sum + b.lengthInBytes);

  /// [op]'u güncel belgeye uygular ve adım olarak ekler. Hata fırlatırsa
  /// hiçbir şey değişmez (reddedilen düzenleme geri alma listesine girmez).
  Future<void> applyOp(String label, PdfByteOp op) async {
    final out = _asBytes(await op(bytes));
    _steps.add(_Step(label, op: op));
    _redo.clear();
    _setCurrent(out);
  }

  /// Katmanın yeni hâlini adım olarak ekler (belge baytları değişmez).
  void setLayer(String label, S next) {
    _steps.add(_Step(label, layer: next));
    _redo.clear();
  }

  /// Son adımı geri alır; belge baytları değiştiyse true.
  Future<bool> undo() async {
    if (_steps.isEmpty) return false;
    final step = _steps.removeLast();
    _redo.add(step);
    if (step.op == null) return false;
    _cache.remove(_steps.length);
    _current = await _bytesAfter(_steps.length - 1);
    return true;
  }

  /// Geri alınan son adımı yeniden yapar; belge baytları değiştiyse true.
  Future<bool> redo() async {
    if (_redo.isEmpty) return false;
    final step = _redo.last;
    final op = step.op;
    if (op != null) {
      final out = _asBytes(await op(bytes));
      _redo.removeLast();
      _steps.add(step);
      _setCurrent(out);
      return true;
    }
    _redo.removeLast();
    _steps.add(step);
    return false;
  }

  /// Şu anki hâl kaydedildi.
  void markSaved() => _savedAt = _steps.length;

  void _setCurrent(Uint8List out) {
    _current = out;
    _cache[_steps.length - 1] = out;
    _trim();
  }

  /// [index] adımından SONRAKİ belge (−1 → taban). Önbellekte yoksa en yakın
  /// tutulan hâlden ileri doğru yeniden oynatılır.
  Future<Uint8List> _bytesAfter(int index) async {
    // Katman adımları belgeyi değiştirmez; önbellekte tutulan en yakın bayt
    // adımına (yoksa tabana) kadar geri in.
    var start = index;
    while (start >= 0 &&
        !(_steps[start].op != null && _cache.containsKey(start))) {
      start--;
    }
    var data = start < 0 ? _base : _cache[start]!;
    for (var i = start + 1; i <= index; i++) {
      final op = _steps[i].op;
      if (op == null) continue;
      data = _asBytes(await op(data));
      _cache[i] = data;
    }
    _trim();
    return data;
  }

  /// Bütçeyi aşan en eski ara sonuçları bırakır (güncel hâl hariç).
  void _trim() {
    var total = cachedBytes;
    if (total <= cacheBudgetBytes) return;
    final keys = _cache.keys.toList()..sort();
    for (final k in keys) {
      if (total <= cacheBudgetBytes) break;
      final b = _cache[k]!;
      if (identical(b, _current)) continue;
      _cache.remove(k);
      total -= b.lengthInBytes;
    }
  }

  static Uint8List _asBytes(List<int> b) =>
      b is Uint8List ? b : Uint8List.fromList(b);
}

class _Step<S> {
  final String label;
  final PdfByteOp? op;
  final S? layer;
  _Step(this.label, {this.op, this.layer});
}
