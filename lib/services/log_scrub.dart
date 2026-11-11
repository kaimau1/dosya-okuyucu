/// **Günlük/çökme metni temizleyici** — tanı raporu (`DiagReport.scrub`) ve
/// çökme kaydı (`CrashLog.record`) AYNI işlevi kullanır (Güvenlik Faz G2.5,
/// 2026-11-11).
///
/// Önce **sırlar** maskelenir (API anahtarı, `Authorization:` satırı, URL'deki
/// `kullanıcı:parola@`, `key=`/`token=`/`kod=` sorgu değerleri), sonra kişisel
/// veri (yol, dosya adı, e-posta, URI, uzun sayı — KVKK). Yığın satırları
/// (`package:…dart:12:5`) korunur: hatanın yeri okunur kalmalı.
abstract final class LogScrub {
  static final _rules = <(RegExp, String Function(Match))>[
    // ── sırlar (G2.5) ──
    // Google API anahtarı biçimi.
    (RegExp(r'AIza[0-9A-Za-z_\-]{35}'), (_) => '<anahtar>'),
    // Başlık satırları: değer satır sonuna kadar gizlenir.
    (
      RegExp(r'(authorization|x-goog-api-key|proxy-authorization)\s*[:=]\s*[^\n]+',
          caseSensitive: false),
      (Match m) => '${m.group(1)}: <gizli>'
    ),
    // URL'deki kimlik: şema://kullanıcı:parola@ → şema://<kimlik>@
    (RegExp(r'://[^/\s:@]+:[^/\s@]+@'), (_) => '://<kimlik>@'),
    // Sorgu değerleri: ?key=…, &token=…, kod=…
    (
      RegExp(
          r'\b(key|api_key|apikey|token|access_token|refresh_token|kod|password|pass|sig)=[^&\s#"' "'" r']+',
          caseSensitive: false),
      (Match m) => '${m.group(1)}=<gizli>'
    ),
    // ── kişisel veri (KVKK, 2026-10 tanı raporu kuralları) ──
    // Tırnak içindeki yol (FileSystemException biçimi; boşluklu adlar dahil).
    (RegExp(r"'[^'\n]*[/\\][^'\n]*'"), (_) => "'<yol>'"),
    (RegExp(r'"[^"\n]*[/\\][^"\n]*"'), (_) => '"<yol>"'),
    (RegExp(r'[\w.+-]+@[\w-]+\.[\w.]+'), (_) => '<eposta>'),
    (RegExp(r'(content|file|https?|ftp|smb|sftp|webdav)://\S+'), (_) => '<uri>'),
    (
      RegExp(r'(?<![\w.])(/[^\s/:,;()\[\]"' "'" r']+){2,}/?'),
      (_) => '<yol>'
    ),
    (
      RegExp(
          r'[^\s/\\:"' "'" r'()\[\]]+\.(pdf|docx?|xlsx?|xlsm|csv|pptx?|odt|ods|odp|rtf|txt|md|epub|jpe?g|png|webp|heic|gif|mp[34]|mkv|zip|rar|7z|apk)\b',
          caseSensitive: false),
      (_) => '<dosya>'
    ),
    (RegExp(r'\d{6,}'), (_) => '<n>'),
  ];

  /// Sır ve kişisel olabilecek parçaları maskeler.
  static String scrub(String s) {
    var out = s;
    for (final (re, rep) in _rules) {
      out = out.replaceAllMapped(re, rep);
    }
    return out;
  }
}
