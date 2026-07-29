/// İndirme görevlerinin **saf** modeli: durum makinesi, dosya adı çözümleme,
/// hız/kalan süre biçimleme.
///
/// Bilinçli olarak Flutter ve `dart:io` içermez → indirmenin en kaygan
/// kısımları (sunucunun verdiği ada güvenmek, sürdürme koşulları) birim
/// testiyle sabitlenir.
library;

import 'dart:convert';

enum DownloadState { queued, running, paused, completed, failed, canceled }

extension DownloadStateInfo on DownloadState {
  String get label => switch (this) {
        DownloadState.queued => 'Sırada',
        DownloadState.running => 'İndiriliyor',
        DownloadState.paused => 'Duraklatıldı',
        DownloadState.completed => 'Tamamlandı',
        DownloadState.failed => 'Başarısız',
        DownloadState.canceled => 'İptal edildi',
      };

  bool get isActive =>
      this == DownloadState.queued || this == DownloadState.running;

  /// Sürdürülebilir mi (devam düğmesi gösterilsin mi)?
  bool get isResumable =>
      this == DownloadState.paused || this == DownloadState.failed;
}

/// Tek bir indirme.
class DownloadTask {
  /// Kalıcı kimlik (kuyruk dosyasında ve arayüzde anahtar).
  final String id;
  final String url;

  /// Hedef dosyanın tam yolu.
  final String destPath;

  final String fileName;
  final DownloadState state;

  /// İnen bayt.
  final int received;

  /// Toplam bayt; sunucu bildirmediyse -1 (yüzde gösterilemez).
  final int total;

  /// Son hata (varsa) — kullanıcıya olduğu gibi gösterilir.
  final String? error;

  /// Anlık hız (bayt/sn); durakladıysa 0.
  final int bytesPerSecond;

  final int startedMs;
  final int updatedMs;

  const DownloadTask({
    required this.id,
    required this.url,
    required this.destPath,
    required this.fileName,
    this.state = DownloadState.queued,
    this.received = 0,
    this.total = -1,
    this.error,
    this.bytesPerSecond = 0,
    this.startedMs = 0,
    this.updatedMs = 0,
  });

  bool get hasTotal => total > 0;

  /// 0..1 arası ilerleme; toplam bilinmiyorsa null (belirsiz çubuk).
  double? get fraction =>
      hasTotal ? (received / total).clamp(0, 1).toDouble() : null;

  DownloadTask copyWith({
    DownloadState? state,
    int? received,
    int? total,
    String? error,
    bool clearError = false,
    int? bytesPerSecond,
    int? startedMs,
    int? updatedMs,
    String? destPath,
    String? fileName,
  }) =>
      DownloadTask(
        id: id,
        url: url,
        destPath: destPath ?? this.destPath,
        fileName: fileName ?? this.fileName,
        state: state ?? this.state,
        received: received ?? this.received,
        total: total ?? this.total,
        error: clearError ? null : (error ?? this.error),
        bytesPerSecond: bytesPerSecond ?? this.bytesPerSecond,
        startedMs: startedMs ?? this.startedMs,
        updatedMs: updatedMs ?? this.updatedMs,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'url': url,
        'dest': destPath,
        'name': fileName,
        'state': state.name,
        'received': received,
        'total': total,
        'error': error,
        'started': startedMs,
        'updated': updatedMs,
      };

  static DownloadTask? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final id = raw['id'], url = raw['url'], dest = raw['dest'];
    if (id is! String || url is! String || dest is! String) return null;
    var state = DownloadState.queued;
    for (final s in DownloadState.values) {
      if (s.name == raw['state']) state = s;
    }
    // Koşan indirme "sırada" olarak okunur: uygulama kapalıyken indirme
    // native tarafta SÜRMÜŞ olabilir (arka plan motoru). Gerçek durum açılışta
    // motora sorulup düzeltilir (`DownloadService.ensureLoaded`); burada
    // "duraklatıldı" yazmak, hâlâ inen bir dosyayı durmuş göstermek olurdu.
    if (state == DownloadState.running) state = DownloadState.queued;
    return DownloadTask(
      id: id,
      url: url,
      destPath: dest,
      fileName: (raw['name'] as String?) ?? id,
      state: state,
      received: (raw['received'] as num?)?.toInt() ?? 0,
      total: (raw['total'] as num?)?.toInt() ?? -1,
      error: raw['error'] as String?,
      startedMs: (raw['started'] as num?)?.toInt() ?? 0,
      updatedMs: (raw['updated'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Metin bir indirilebilir bağlantı mı? (Paylaşılan metinde link aramak için.)
String? extractUrl(String text) {
  final match =
      RegExp(r'https?://[^\s<>"]+', caseSensitive: false).firstMatch(text);
  return match?.group(0);
}

/// **Dosya adı çözümleme** — sırayla: `Content-Disposition` → URL yolu →
/// içerik türünden üretilen yedek ad.
///
/// Sunucunun verdiği ada körü körüne güvenilmez: yol ayracı ve kontrol
/// karakterleri temizlenir (aksi hâlde `../../` ile başka klasöre yazılabilir).
String resolveFileName({
  required String url,
  String? contentDisposition,
  String? contentType,
}) {
  String? name;

  final disposition = contentDisposition;
  if (disposition != null && disposition.isNotEmpty) {
    // RFC 5987: filename*=UTF-8''ad%20soyad.pdf (öncelikli, Türkçe adlar için)
    final star =
        RegExp(r"filename\*\s*=\s*[^']*'[^']*'([^;]+)", caseSensitive: false)
            .firstMatch(disposition);
    if (star != null) {
      name = _tryDecode(star.group(1)!.trim());
    } else {
      final plain =
          RegExp(r'filename\s*=\s*"?([^";]+)"?', caseSensitive: false)
              .firstMatch(disposition);
      if (plain != null) name = plain.group(1)!.trim();
    }
  }

  if (name == null || name.isEmpty) {
    // URL yolunun son parçası; sorgu dizesi ve çapa atılır.
    final uri = Uri.tryParse(url);
    final segments = uri?.pathSegments ?? const [];
    for (final segment in segments.reversed) {
      if (segment.trim().isEmpty) continue;
      name = _tryDecode(segment);
      break;
    }
  }

  name = _sanitizeFileName(name ?? '');
  if (name.isEmpty) name = 'indirilen';

  // Uzantı yoksa içerik türünden tamamla ("indirilen" → "indirilen.pdf").
  if (!name.contains('.')) {
    final ext = extensionForContentType(contentType);
    if (ext != null) name = '$name.$ext';
  }
  return name;
}

String _tryDecode(String value) {
  try {
    return Uri.decodeComponent(value);
  } catch (_) {
    return value;
  }
}

String _sanitizeFileName(String name) => name
    .replaceAll(RegExp(r'[/\\]'), '_')
    .replaceAll(RegExp(r'[\x00-\x1f]'), '')
    .replaceAll(RegExp(r'^\.+'), '') // ".." ve gizli ad tuzağı
    .trim();

/// Yaygın MIME → uzantı. Liste kasıtlı olarak kısa: yalnız uzantısız
/// bağlantılarda yedek olarak kullanılıyor.
String? extensionForContentType(String? contentType) {
  if (contentType == null) return null;
  final mime = contentType.split(';').first.trim().toLowerCase();
  return const {
    'application/pdf': 'pdf',
    'application/zip': 'zip',
    'application/x-zip-compressed': 'zip',
    'application/vnd.android.package-archive': 'apk',
    'application/x-7z-compressed': '7z',
    'application/x-rar-compressed': 'rar',
    'application/vnd.rar': 'rar',
    'application/json': 'json',
    'application/msword': 'doc',
    'application/vnd.openxmlformats-officedocument.wordprocessingml.document':
        'docx',
    'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet': 'xlsx',
    'application/vnd.openxmlformats-officedocument.presentationml.presentation':
        'pptx',
    'text/plain': 'txt',
    'text/html': 'html',
    'text/csv': 'csv',
    'image/jpeg': 'jpg',
    'image/png': 'png',
    'image/gif': 'gif',
    'image/webp': 'webp',
    'video/mp4': 'mp4',
    'video/x-matroska': 'mkv',
    'audio/mpeg': 'mp3',
    'audio/mp4': 'm4a',
  }[mime];
}

/// Hız biçimi: "1,2 MB/s".
String formatSpeed(int bytesPerSecond) {
  if (bytesPerSecond <= 0) return '—';
  return '${_humanSize(bytesPerSecond)}/s';
}

/// Kalan süre; hız yoksa ya da toplam bilinmiyorsa null.
Duration? etaFor({
  required int received,
  required int total,
  required int bytesPerSecond,
}) {
  if (total <= 0 || bytesPerSecond <= 0 || received >= total) return null;
  return Duration(seconds: ((total - received) / bytesPerSecond).ceil());
}

/// "3 dk 12 sn" / "45 sn" biçimi.
String formatDuration(Duration d) {
  if (d.inHours > 0) return '${d.inHours} sa ${d.inMinutes.remainder(60)} dk';
  if (d.inMinutes > 0) {
    return '${d.inMinutes} dk ${d.inSeconds.remainder(60)} sn';
  }
  return '${d.inSeconds} sn';
}

String _humanSize(int bytes) {
  if (bytes <= 0) return '0 B';
  const units = ['B', 'KB', 'MB', 'GB', 'TB'];
  var size = bytes.toDouble();
  var unit = 0;
  while (size >= 1024 && unit < units.length - 1) {
    size /= 1024;
    unit++;
  }
  final text =
      unit == 0 ? size.toStringAsFixed(0) : size.toStringAsFixed(size < 10 ? 1 : 0);
  return '${text.replaceAll('.', ',')} ${units[unit]}';
}

/// Kuyruğun diske yazılan biçimi (saf → testli).
String encodeQueue(List<DownloadTask> tasks) =>
    jsonEncode(tasks.map((t) => t.toJson()).toList());

List<DownloadTask> decodeQueue(String raw) {
  try {
    final data = jsonDecode(raw);
    if (data is! List) return const [];
    return [
      for (final item in data)
        if (DownloadTask.fromJson(item) case final task?) task,
    ];
  } catch (_) {
    return const [];
  }
}
