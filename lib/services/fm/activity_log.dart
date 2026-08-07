import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import 'fm_env.dart';

/// Kullanıcının uygulamayla **yaptığı iş** türü.
///
/// Dosya işlemleri (taşı/kopyala/sil) burada YOK: onların kendi geçmişi var
/// (`OpHistory`) ve geri alma kayıtlarını taşıyor. Buradaki kayıtlar
/// "ürettiğim şeyler": küçültülen video, düzenlenen PDF, dönüştürülen belge,
/// taranan sayfa.
enum ActivityKind {
  videoResize,
  imageResize,
  pdfEdit,
  documentEdit,
  convert,
  scan,
  other,
}

extension ActivityKindInfo on ActivityKind {
  /// Çeviri anahtarı (bkz. `FmCategoryLabel.labelKey`).
  String get labelKey => switch (this) {
        ActivityKind.videoResize => 'act.kind_video',
        ActivityKind.imageResize => 'act.kind_image',
        ActivityKind.pdfEdit => 'act.kind_pdf',
        ActivityKind.documentEdit => 'act.kind_doc',
        ActivityKind.convert => 'act.kind_convert',
        ActivityKind.scan => 'act.kind_scan',
        ActivityKind.other => 'act.kind_other',
      };
}

/// Tek bir "yaptım" kaydı.
class ActivityRecord {
  final ActivityKind kind;
  final int whenMs;

  /// Üretilen/dokunulan dosyanın yolu. Kayda dokunmak bunu açar.
  final String path;

  /// Kısa açıklama ("48,3 MB → 12,1 MB", "3 sayfa imzalandı"). Boş olabilir.
  final String detail;

  const ActivityRecord({
    required this.kind,
    required this.whenMs,
    required this.path,
    this.detail = '',
  });

  String get name => p.basename(path);

  Map<String, Object?> toJson() => {
        'kind': kind.name,
        'when': whenMs,
        'path': path,
        if (detail.isNotEmpty) 'detail': detail,
      };

  static ActivityRecord? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final path = raw['path'];
    if (path is! String || path.isEmpty) return null;
    var kind = ActivityKind.other;
    for (final k in ActivityKind.values) {
      if (k.name == raw['kind']) kind = k;
    }
    return ActivityRecord(
      kind: kind,
      whenMs: (raw['when'] as num?)?.toInt() ?? 0,
      path: path,
      detail: raw['detail'] as String? ?? '',
    );
  }
}

/// "Yaptıklarım" defteri — üretilen dosyaların kalıcı kaydı.
///
/// KÖK NEDEN (kullanıcı 2026-08-07: *"benim yaptıklarım kartı lazım; mesela
/// video boyutu düşürdük, düşen video orada; PDF düzenledik, orada — ama her
/// şey kategorize olmalı"*): sonuçlar üç ayrı yere dağılmıştı ve hiçbiri
/// kalıcı değildi. İş kuyruğu yalnız son işleri tutuyor (liste kırpılıyor),
/// düzenlenen belgeler hiçbir yere yazılmıyordu; kullanıcı ürettiği dosyayı
/// klasör klasör aramak zorundaydı.
///
/// Kayıt **yol anahtarlı ve türlü** tutulur: ekran türe göre gruplayabilsin.
abstract final class ActivityLog {
  static const _fileName = 'activity_log.json';
  static const maxRecords = 300;

  static String get _path => p.join(FmEnv.appSupportDir, _fileName);

  /// Bellekteki kopya — ekran her açılışta diski okumasın; yazma da
  /// bunun üstünden yapılır.
  static List<ActivityRecord>? _cache;

  static Future<List<ActivityRecord>> load() async {
    final cached = _cache;
    if (cached != null) return cached;
    if (FmEnv.appSupportDir.isEmpty) return const [];
    try {
      final file = File(_path);
      if (!file.existsSync()) return _cache = const [];
      final raw = jsonDecode(await file.readAsString());
      if (raw is! List) return _cache = const [];
      return _cache = [
        for (final item in raw)
          if (ActivityRecord.fromJson(item) case final r?) r,
      ]..sort((a, b) => b.whenMs.compareTo(a.whenMs));
    } catch (_) {
      return _cache = const [];
    }
  }

  /// Kayıt ekler (en yeni başta). **Hata yutulur:** defter tutulamadı diye
  /// kullanıcının asıl işi (kaydetme, küçültme) başarısız sayılamaz.
  static Future<void> add(
    ActivityKind kind,
    String path, {
    String detail = '',
    int? whenMs,
  }) async {
    if (path.isEmpty) return;
    final record = ActivityRecord(
      kind: kind,
      whenMs: whenMs ?? DateTime.now().millisecondsSinceEpoch,
      path: path,
      detail: detail,
    );
    // Aynı dosyanın arka arkaya kaydedilmesi tek satır kalsın: Word'de üç kez
    // "Kaydet" demek üç ayrı "yaptım" değil.
    final all = [
      record,
      ...(await load()).where((r) => !(r.path == path && r.kind == kind)),
    ];
    _cache = all.length > maxRecords ? all.sublist(0, maxRecords) : all;
    if (FmEnv.appSupportDir.isEmpty) return;
    try {
      final tmp = File('$_path.tmp');
      await tmp.writeAsString(
          jsonEncode([for (final r in _cache!) r.toJson()]),
          flush: true);
      await tmp.rename(_path);
    } catch (_) {
      // Defter yazılamazsa iş yine yapıldı; sessiz geçilir.
    }
  }

  /// Diskte artık olmayan kayıtları eler (kullanıcı dosyayı silmiş olabilir).
  /// Ekran listeyi böyle gösterir: dokununca açılmayan satır "bozuk" sanılır.
  static List<ActivityRecord> existing(List<ActivityRecord> records) => [
        for (final r in records)
          if (File(r.path).existsSync()) r,
      ];

  /// Türlere göre gruplar (ekran "kategorize" istiyordu). Sıra
  /// [ActivityKind.values] sırasıdır; boş gruplar dönmez.
  static Map<ActivityKind, List<ActivityRecord>> group(
      List<ActivityRecord> records) {
    final out = <ActivityKind, List<ActivityRecord>>{};
    for (final kind in ActivityKind.values) {
      final of = [for (final r in records) if (r.kind == kind) r];
      if (of.isNotEmpty) out[kind] = of;
    }
    return out;
  }

  static Future<void> clear() async {
    _cache = const [];
    try {
      final file = File(_path);
      if (file.existsSync()) await file.delete();
    } catch (_) {}
  }

  /// Yalnız testlerde: bellekteki kopyayı düşürür.
  static void resetCache() => _cache = null;
}
