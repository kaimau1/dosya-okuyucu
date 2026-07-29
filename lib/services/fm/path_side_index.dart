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

/// [path], `from` → `to` taşımasından etkileniyorsa **yeni yolunu** döndürür;
/// etkilenmiyorsa null.
///
/// ## Niye ayrı ve saf bir fonksiyon
/// [PathSideIndex.moved] KLASÖRLER için de çağrılıyor (`FileOps.rename` bir
/// klasörü yeniden adlandırdığında da haber veriyor), ama yan kayıtlar
/// yalnızca **tam anahtar** eşleşmesine bakıyordu. Sonuç: `DCIM/Tatil`
/// klasörünün adını değiştiren kullanıcı, içindeki 40 fotoğrafın "Ayşe"
/// etiketini bir anda kaybediyordu — üstelik kayıtlar hiç temizlenmiyordu
/// (`_shouldKeep` eski üst klasörü de göremediği için kaydı "erişilemez" sanıp
/// sonsuza dek saklıyor) ve süzgeç çipi "Ayşe (40)" yazarken liste boş
/// dönüyordu (2026-07-29 sadakat denetimi, 2. tur).
///
/// Alt yol eşleşmesi **ayırıcı sınırında** yapılır: `Tatil` taşınırken
/// `Tatil 2025` etkilenmemeli. Her iki ayırıcı da (`/` ve `\`) kabul edilir.
String? movedPathFor({
  required String path,
  required String from,
  required String to,
}) {
  if (path == from) return to;
  if (!path.startsWith(from)) return null;
  final rest = path.substring(from.length);
  if (rest.isEmpty) return to;
  final first = rest[0];
  // `from` zaten ayırıcıyla bitiyorsa (ör. "/a/b/") sınır sağlanmış sayılır.
  final fromEndsWithSeparator = from.endsWith('/') || from.endsWith(r'\');
  if (!fromEndsWithSeparator && first != '/' && first != r'\') return null;
  return '$to$rest';
}
