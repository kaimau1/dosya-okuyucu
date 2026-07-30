import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import 'file_ops.dart';
import 'fm_env.dart';

/// Yapılan işlem türü.
enum OpKind { move, copy, delete, rename, organize }

extension OpKindInfo on OpKind {
  /// Çeviri anahtarı (bkz. `FmCategoryLabel.labelKey`). [label] Türkçe kalır:
  /// geçmiş kayıtlarına **özet metni olarak yazılmış** eski kayıtlar var.
  String get labelKey => switch (this) {
        OpKind.move => 'enum.op_move',
        OpKind.copy => 'enum.op_copy',
        OpKind.delete => 'enum.op_delete',
        OpKind.rename => 'enum.op_rename',
        OpKind.organize => 'enum.op_organize',
      };

  String get label => switch (this) {
        OpKind.move => 'Taşıma',
        OpKind.copy => 'Kopyalama',
        OpKind.delete => 'Silme',
        OpKind.rename => 'Yeniden adlandırma',
        OpKind.organize => 'Otomatik düzenleme',
      };

  /// Geri alınabilir mi? Yalnız dosyanın YERİ değişen işlemler.
  ///
  /// Kopyalamayı geri almak "sil" demektir (yanlış dokunuşta veri kaybı),
  /// silmeyi geri almak çöp kutusunun işidir (orada zaten geri yükleme var).
  bool get undoable => this == OpKind.move || this == OpKind.organize;
}

/// Geçmişteki tek bir işlem.
class OpRecord {
  final OpKind kind;
  final int whenMs;

  /// İnsan okur özet ("12 öğe → Önemli Dosyalar").
  final String summary;

  /// Geri almak için gereken kaynak → varış eşlemeleri.
  final List<FmTransfer> transfers;

  const OpRecord({
    required this.kind,
    required this.whenMs,
    required this.summary,
    this.transfers = const [],
  });

  bool get canUndo => kind.undoable && transfers.isNotEmpty;

  Map<String, dynamic> toJson() => {
        'kind': kind.name,
        'when': whenMs,
        'summary': summary,
        'moves': [
          for (final t in transfers) {'s': t.source, 'd': t.dest},
        ],
      };

  static OpRecord? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final kindName = raw['kind'];
    final when = (raw['when'] as num?)?.toInt();
    if (when == null) return null;
    OpKind? kind;
    for (final k in OpKind.values) {
      if (k.name == kindName) kind = k;
    }
    if (kind == null) return null;
    final moves = <FmTransfer>[];
    final list = raw['moves'];
    if (list is List) {
      for (final item in list) {
        if (item is! Map) continue;
        final s = item['s'], d = item['d'];
        if (s is String && d is String) moves.add(FmTransfer(s, d));
      }
    }
    return OpRecord(
      kind: kind,
      whenMs: when,
      summary: (raw['summary'] as String?) ?? kind.label,
      transfers: moves,
    );
  }
}

/// **Son işlemler geçmişi** — "neyi nereye taşımıştım?" sorusunun cevabı ve
/// toplu geri alma yeri.
///
/// Bildirimdeki "Geri al" düğmesi birkaç saniye sonra kaybolur; kullanıcı
/// yanlış taşımayı beş dakika sonra fark ederse elinde hiçbir şey kalmıyordu.
/// Kayıtlar düz JSON dosyasında tutulur (son [maxRecords] işlem).
abstract final class OpHistory {
  static const _fileName = 'op_history.json';
  static const maxRecords = 50;

  static String get _path => p.join(FmEnv.appSupportDir, _fileName);

  static Future<List<OpRecord>> load() async {
    if (FmEnv.appSupportDir.isEmpty) return const [];
    try {
      final file = File(_path);
      if (!file.existsSync()) return const [];
      final raw = jsonDecode(await file.readAsString());
      if (raw is! List) return const [];
      return [
        for (final item in raw)
          if (OpRecord.fromJson(item) case final record?) record,
      ]..sort((a, b) => b.whenMs.compareTo(a.whenMs));
    } catch (_) {
      return const [];
    }
  }

  /// Kaydı ekler (en yeni başta) ve listeyi sınırlar.
  static Future<void> add(OpRecord record) async {
    if (FmEnv.appSupportDir.isEmpty) return;
    final all = trim([record, ...await load()]);
    try {
      await _writeAtomic(all);
    } catch (_) {
      // geçmiş yazılamazsa işlem yine de yapıldı; sessiz geçilir
    }
  }

  /// Kaydı geçmişten düşürür (geri alındıktan sonra).
  static Future<void> remove(OpRecord record) async {
    if (FmEnv.appSupportDir.isEmpty) return;
    final all = await load()
      ..removeWhere(
          (r) => r.whenMs == record.whenMs && r.summary == record.summary);
    try {
      await _writeAtomic(all);
    } catch (_) {}
  }

  /// **Atomik** yazma: geçici dosya + `rename`.
  ///
  /// `writeAsString` dosyayı önce kısaltıyor; yazma yarıda kalırsa `load()`
  /// bozuk JSON'u boş listeye çeviriyor ve TÜM geri alma geçmişi sessizce yok
  /// oluyordu (2026-07-29 sadakat denetimi, 4. tur — çöp kutusu kaydındaki
  /// aynı sınıf hata, orada dosya baytları söz konusuydu, burada geçmiş).
  static Future<void> _writeAtomic(List<OpRecord> records) async {
    final tmp = File('$_path.tmp');
    await tmp.writeAsString(
        jsonEncode(records.map((e) => e.toJson()).toList()),
        flush: true);
    await tmp.rename(_path);
  }

  static Future<void> clear() async {
    if (FmEnv.appSupportDir.isEmpty) return;
    try {
      final file = File(_path);
      if (file.existsSync()) await file.delete();
    } catch (_) {}
  }

  /// En yeniden eskiye sıralar ve [maxRecords] ile sınırlar (saf → testli).
  static List<OpRecord> trim(List<OpRecord> records) {
    final sorted = [...records]..sort((a, b) => b.whenMs.compareTo(a.whenMs));
    return sorted.length <= maxRecords
        ? sorted
        : sorted.sublist(0, maxRecords);
  }
}
