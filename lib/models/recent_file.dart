import 'dart:convert';

/// Son açılan dosya kaydı.
class RecentFile {
  final String path;
  final String name;
  final int sizeBytes;
  final int openedAtMs;

  RecentFile({
    required this.path,
    required this.name,
    required this.sizeBytes,
    required this.openedAtMs,
  });

  String get extension {
    final dot = name.lastIndexOf('.');
    return dot == -1 ? '' : name.substring(dot + 1).toLowerCase();
  }

  Map<String, dynamic> toMap() => {
        'path': path,
        'name': name,
        'sizeBytes': sizeBytes,
        'openedAtMs': openedAtMs,
      };

  String encode() => jsonEncode(toMap());

  static RecentFile? tryDecode(String source) {
    try {
      final map = jsonDecode(source) as Map<String, dynamic>;
      return RecentFile(
        path: map['path'] as String,
        name: map['name'] as String,
        sizeBytes: (map['sizeBytes'] as num).toInt(),
        openedAtMs: (map['openedAtMs'] as num).toInt(),
      );
    } catch (_) {
      return null;
    }
  }
}
