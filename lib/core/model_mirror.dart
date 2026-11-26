/// **Model indirme aynası** (B7b/4, 2026-11-26) — üçüncü parti model
/// kaynaklarının (Hugging Face, jsDelivr, TF Hub) TEK yapılandırma yeri.
///
/// Derlemede `--dart-define=DOSYA_MODEL_AYNA=https://ayna.ornek` verilirse
/// her indirme önce `<ayna>/<özgün host><özgün yol>[?sorgu]` adresini dener,
/// olmazsa özgün kaynağa döner. Boşsa (varsayılan) yalnız özgün kaynak.
/// Her dosyanın SHA-256'sı ayrıca denetlendiği için ayna içeriği
/// değiştiremez — yalnız erişilebilirliği artırır.
abstract final class ModelMirror {
  static const base = String.fromEnvironment('DOSYA_MODEL_AYNA');

  /// [url] için denenecek adresler, sırayla.
  static List<String> candidates(String url, {String mirror = base}) {
    if (mirror.isEmpty) return [url];
    final u = Uri.parse(url);
    final root = mirror.endsWith('/')
        ? mirror.substring(0, mirror.length - 1)
        : mirror;
    final q = u.hasQuery ? '?${u.query}' : '';
    return ['$root/${u.host}${u.path}$q', url];
  }
}
