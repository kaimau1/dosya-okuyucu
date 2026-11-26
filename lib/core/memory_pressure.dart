/// Bellek baskısı ve arka plana geçiş anlarında büyük oturum içi
/// önbellekleri bırakan merkezi kayıt defteri.
abstract final class MemoryPressure {
  static final List<void Function(bool critical)> _listeners = [];

  static void register(void Function(bool critical) listener) {
    if (!_listeners.contains(listener)) {
      _listeners.add(listener);
    }
  }

  static void unregister(void Function(bool critical) listener) {
    _listeners.remove(listener);
  }

  static void dispatch({required bool critical}) {
    for (final fn in List<void Function(bool critical)>.of(_listeners)) {
      try {
        fn(critical);
      } catch (_) {
        // Bir temizleyici hata verse de diğerleri koşsun.
      }
    }
  }
}
