/// **Uzantı aldatması** (Güvenlik G7.10, 2026-11-12).
///
/// İki bilinen hile: (1) `rapor.pdf.apk` — listede ad sığmayınca sonu kesilir
/// ya da kullanıcı yalnız ilk uzantıyı görür; (2) Unicode yön denetimi
/// karakterleri (U+202E SAĞDAN SOLA GEÇERSİZ KIL vb.) — `faturagpj.apk`
/// adındaki `‮` ekranda `faturakpa.jpg` gibi görünür. Burada yön karakterleri
/// görünür bir işarete çevrilir ve tehlikeli son uzantı ayrıca bildirilir;
/// dosya ADI değişmez (yalnız gösterim).
class NameSpoof {
  NameSpoof._();

  /// Görünmez yön denetimi karakterleri: LRE/RLE/PDF/LRO/RLO (202A–202E),
  /// LRI/RLI/FSI/PDI (2066–2069), LRM/RLM (200E/200F), ALM (061C).
  static final _bidiControls =
      RegExp('[‪-‮⁦-⁩‎‏؜]');

  /// Yön karakterinin yerine konan görünür işaret.
  static const marker = '⸮'; // ⸮ (ters soru işareti)

  /// Çalıştırılabilir / betik çalıştıran son uzantılar.
  static const riskyExtensions = {
    'apk', 'apks', 'xapk', 'apkm', 'exe', 'msi', 'bat', 'cmd', 'com', 'scr',
    'pif', 'vbs', 'js', 'jse', 'wsf', 'ps1', 'sh', 'jar', 'html', 'htm',
    'hta', 'svg', 'lnk',
  };

  /// Aldatmaya alet edilen "masum" ara uzantılar.
  static const _decoyExtensions = {
    'pdf', 'doc', 'docx', 'xls', 'xlsx', 'ppt', 'pptx', 'txt', 'jpg', 'jpeg',
    'png', 'gif', 'mp3', 'mp4', 'zip', 'rar', 'csv', 'odt', 'rtf', 'heic',
    'webp',
  };

  static bool hasBidiControls(String name) => _bidiControls.hasMatch(name);

  /// Ad gösterim için: yön karakterleri [marker] olur, gerisi aynen.
  static String visible(String name) =>
      hasBidiControls(name) ? name.replaceAll(_bidiControls, marker) : name;

  /// `rapor.pdf.apk` gibi: masum bir uzantının ardından tehlikeli son uzantı.
  /// Ya da adında yön karakteri olan tehlikeli uzantılı dosya. Dönüş: vurgulanacak
  /// gerçek uzantı (`apk`) veya `null`.
  static String? deceptiveExtension(String name) {
    final clean = name.replaceAll(_bidiControls, '').toLowerCase().trim();
    final parts = clean.split('.');
    if (parts.length < 2) return null;
    final last = parts.last.trim();
    if (!riskyExtensions.contains(last)) return null;
    if (hasBidiControls(name)) return last;
    if (parts.length >= 3 && _decoyExtensions.contains(parts[parts.length - 2].trim())) {
      return last;
    }
    return null;
  }

  /// Aldatıcı bir ad mı (yön karakteri ya da çift uzantı)?
  static bool isSuspicious(String name) =>
      hasBidiControls(name) || deceptiveExtension(name) != null;
}
