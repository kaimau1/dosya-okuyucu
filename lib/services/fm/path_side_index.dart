/// **Yol anahtarlı yan kayıtlar** — dosya taşınınca/adı değişince onların da
/// taşınması gerekir.
///
/// ## Niye var (2026-07-29 sadakat denetimi)
/// Etiketler (`file_tags.dart`) ve açılma geçmişi (`open_history.dart`)
/// dosyayı **yolundan** tanır. Dosya uygulama içinden taşındığında ya da adı
/// değiştiğinde bu kayıtlar eski yolda kalıyor ve bir sonraki yüklemede
/// "dosya yok" sayılıp **sessizce siliniyordu**. Yani kullanıcı "Ayşe" diye
/// etiketlediği fotoğrafı bizim uygulamamızla başka klasöre taşıyınca etiketi
/// kaybediyordu — üstelik etiket sayfasında ona *"başka bir uygulamayla
/// taşırsan etiket onunla gitmez"* yazıyordu, yani uygulama içinde
/// korunacağını söylemiş oluyorduk. Bu dosya o sözü gerçek yapar.
///
/// ## Niye kanca (doğrudan çağrı değil)
/// [FileOps] ve [TrashService] bilinçli olarak **saf `dart:io`** — Flutter
/// bağımlılığı yok, geçici klasörle birim testi yazılabiliyor. `FileTags`
/// ise `FmEnv` üzerinden `path_provider`a (Flutter eklentisi) bağlı. Kancayı
/// `main` bağlayınca dosya işlemleri katmanı saf kalır, testler eklenti
/// olmadan koşmaya devam eder.
library;

/// Bir yolun taşındığını duyan kayıt.
typedef PathMovedHook = Future<void> Function(String from, String to);

abstract final class PathSideIndex {
  static final List<PathMovedHook> _hooks = [];

  /// Kancayı kaydeder (`main` içinde bir kez).
  static void register(PathMovedHook hook) => _hooks.add(hook);

  /// Bir dosya/klasör [from] → [to] taşındı. Kayıtlı tüm yan kayıtlara bildirir.
  ///
  /// Hatalar **yutulur**: yan kayıt güncellemesi dosya işlemini geri
  /// almamalı — dosya taşındı, etiket kaybı üzücü ama işlemi çökertmekten
  /// iyidir.
  static Future<void> moved(String from, String to) async {
    if (from == to) return;
    for (final hook in _hooks) {
      try {
        await hook(from, to);
      } catch (_) {}
    }
  }

  /// Yalnız testler için: kayıtlı kancaları temizler.
  static void resetForTest() => _hooks.clear();
}
