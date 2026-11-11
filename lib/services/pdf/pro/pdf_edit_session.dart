/// **PDF düzenleme oturumu** (PDF Pro Faz 54 / 1, PK2 + PK3).
///
/// Görüntüleyicinin AÇIK belgesine bağlıdır; çalışma kopyası dosyası yoktur.
/// Her düzenleme bir **komut**tur: uygulanmadan önce yalnız o sayfanın anlık
/// görüntüsü alınır (içerik akışı + kaynak sözlüğü — tüm belge kopyası YOK),
/// geri al o görüntüyü yerine koyar, yinele komutun sonrasını. Yığın
/// sınırsızdır; adımlar ad taşır ("Paragraf düzenlendi: 'Ancak…'").
///
/// Kirli izleme sayfa bazlıdır ve **duruma** bakar: kayıtlı hâle geri alınan
/// sayfa kirli sayılmaz (Word/Excel davranışı).
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:pdfrx/pdfrx.dart';

import 'pdf_edit_bridge.dart';

/// Sayfa anlık görüntüsü arka ucu. Gerçeği PDFium'da ([PdfiumPageSnapshots]),
/// testte sahtesi.
abstract class PdfPageSnapshots {
  /// [pageIndex] sayfasının şimdiki hâli → tutamaç (0 = alınamadı).
  Future<int> take(int pageIndex);

  /// Tutamaçtaki hâli sayfaya geri koyar; olmazsa false (sayfa değişmedi).
  Future<bool> restore(int pageIndex, int handle);

  Future<void> release(int handle);
}

class PdfiumPageSnapshots implements PdfPageSnapshots {
  final PdfDocument doc;
  PdfiumPageSnapshots(this.doc);

  @override
  Future<int> take(int pageIndex) => PdfEditBridge.snapshotPage(doc, pageIndex);

  @override
  Future<bool> restore(int pageIndex, int handle) =>
      PdfEditBridge.restorePage(doc, pageIndex, handle);

  @override
  Future<void> release(int handle) async {
    try {
      await PdfEditBridge.releaseSnapshot(doc, handle);
    } catch (_) {
      // Bilinçli: belge bizden önce kapandıysa geçici kopya süreçle birlikte
      // ölür; kapanışta kullanıcıya gösterilecek bir hata değil.
    }
  }
}

/// Yeniden oynatılabilir, günlüğe yazılabilir düzenleme işlemi. Canlı belgede
/// de, kayıt/kurtarma için yeniden açılan belgede de AYNI yoldan uygulanır.
abstract class PdfEditOp {
  const PdfEditOp();

  int get pageIndex;

  /// Belgeye uygular; uygulanamıyorsa [PdfEditBridgeRefused] (belge değişmez).
  Future<void> applyTo(PdfDocument doc);

  Map<String, Object?> toJson();

  static PdfEditOp? fromJson(Map<String, Object?> j) => switch (j['op']) {
        'replaceBlock' => PdfReplaceBlockOp.fromJson(j),
        _ => null,
      };
}

/// Bir bloğun (paragrafın) metnini değiştirir. Blok nesne sıralarıyla bulunur
/// ve eski metni tutmuyorsa (sayfa değişmiş) reddedilir — yanlış bloğa yazma
/// yok.
class PdfReplaceBlockOp extends PdfEditOp {
  @override
  final int pageIndex;
  final List<int> objectIndexes;
  final String oldText, newText;

  const PdfReplaceBlockOp({
    required this.pageIndex,
    required this.objectIndexes,
    required this.oldText,
    required this.newText,
  });

  factory PdfReplaceBlockOp.of(int pageIndex, PdfTextBlock block, String text) =>
      PdfReplaceBlockOp(
        pageIndex: pageIndex,
        objectIndexes: block.objectIndexes,
        oldText: block.text,
        newText: text,
      );

  static PdfReplaceBlockOp? fromJson(Map<String, Object?> j) {
    final page = j['page'], objs = j['objs'], o = j['old'], n = j['new'];
    if (page is! int || objs is! List || o is! String || n is! String) {
      return null;
    }
    if (objs.any((e) => e is! int)) return null;
    return PdfReplaceBlockOp(
      pageIndex: page,
      objectIndexes: objs.cast<int>(),
      oldText: o,
      newText: n,
    );
  }

  @override
  Map<String, Object?> toJson() => {
        'op': 'replaceBlock',
        'page': pageIndex,
        'objs': objectIndexes,
        'old': oldText,
        'new': newText,
      };

  /// [blocks] içinde bu işlemin bloğu (aynı nesneler, aynı metin) — yoksa null.
  PdfTextBlock? find(List<PdfTextBlock> blocks) {
    for (final b in blocks) {
      if (listEquals(b.objectIndexes, objectIndexes) && b.text == oldText) {
        return b;
      }
    }
    return null;
  }

  @override
  Future<void> applyTo(PdfDocument doc) async {
    final block = find(await PdfEditBridge.blocks(doc, pageIndex));
    if (block == null) {
      throw const PdfEditBridgeRefused(
          'Blok bulunamadı (sayfa değişmiş olabilir).');
    }
    await PdfEditBridge.replaceBlock(doc, pageIndex, block, newText);
  }
}

/// Komut yığınındaki bir adım.
class PdfEditStep {
  final int id;
  final int pageIndex;

  /// Adım adı — çeviri anahtarı ([detail] ile birlikte gösterilir).
  final String label;

  /// Adın yanındaki kısa alıntı ("Ancak…"); boş olabilir.
  final String detail;

  /// Yeniden oynatma/günlük için işlem; null = oynatılamaz adım.
  final PdfEditOp? op;

  final int _before;
  int _after = 0;

  PdfEditStep._(this.id, this.pageIndex, this.label, this.detail, this.op,
      this._before);
}

class PdfEditSession extends ChangeNotifier {
  PdfEditSession(this._snapshots, {this.document});

  /// Görüntüleyicinin belgesine bağlı oturum.
  factory PdfEditSession.forDocument(PdfDocument doc) =>
      PdfEditSession(PdfiumPageSnapshots(doc), document: doc);

  final PdfPageSnapshots _snapshots;

  /// Bağlı belge (sahte arka uçlu testte null).
  final PdfDocument? document;

  final List<PdfEditStep> _done = [];
  final List<PdfEditStep> _undone = [];
  List<int> _savedIds = const [];
  int _nextId = 1;
  bool _restored = false;
  bool _disposed = false;
  Future<void> _tail = Future.value();

  /// Uygulanmış adımlar (eskiden yeniye).
  List<PdfEditStep> get steps => List.unmodifiable(_done);

  bool get canUndo => _done.isNotEmpty;
  bool get canRedo => _undone.isNotEmpty;
  PdfEditStep? get undoStep => _done.isEmpty ? null : _done.last;
  PdfEditStep? get redoStep => _undone.isEmpty ? null : _undone.last;

  /// Bir sayfa anlık görüntüden geri kondu mu? Öyleyse kayıt canlı belgeden
  /// değil, özgünün üstünde [ops] yeniden oynatılarak üretilir
  /// (bkz. [PdfEditBridge.restorePage]).
  bool get needsReplay => _restored;

  /// Kayıt için yeniden oynatılacak işlemler; oynatılamaz adım varsa null.
  List<PdfEditOp>? get ops {
    final out = <PdfEditOp>[];
    for (final s in _done) {
      final op = s.op;
      if (op == null) return null;
      out.add(op);
    }
    return out;
  }

  /// Son kayıttan SONRAKİ işlemler (çökme günlüğü için): diskteki dosyanın
  /// üstüne oynatılınca şimdiki hâli verir. Kaydın altına inildiyse ya da
  /// oynatılamaz adım varsa null (günlük yalnız geçici kayda güvenir).
  List<PdfEditStep>? get stepsSinceSaved {
    final k = _prefix;
    if (k != _savedIds.length) return null;
    final out = _done.sublist(k);
    return out.any((s) => s.op == null) ? null : out;
  }

  int get _prefix {
    var i = 0;
    while (i < _done.length &&
        i < _savedIds.length &&
        _done[i].id == _savedIds[i]) {
      i++;
    }
    return i;
  }

  /// Kayıtlı hâlden farklı adım sayısı ("N değişiklik").
  int get pendingCount {
    final k = _prefix;
    return (_done.length - k) + (_savedIds.length - k);
  }

  bool get dirty => pendingCount != 0;

  /// Kayıtlı hâlinden farklı sayfalar (0 tabanlı, sıralı).
  List<int> get dirtyPages {
    if (!dirty) return const [];
    final saved = _savedPageState;
    final now = _pageState(_done.map((s) => (s.pageIndex, s.id)));
    final out = <int>{};
    for (final p in {...saved.keys, ...now.keys}) {
      if (saved[p] != now[p]) out.add(p);
    }
    return out.toList()..sort();
  }

  Map<int, int> _savedPageState = const {};

  static Map<int, int> _pageState(Iterable<(int, int)> steps) =>
      {for (final (page, id) in steps) page: id};

  /// İşleri sıraya dizer: PDFium çağrıları ve yığın değişimi iç içe girmez.
  Future<T> _serial<T>(Future<T> Function() job) {
    final c = Completer<T>();
    _tail = _tail.then((_) async {
      try {
        c.complete(await job());
      } catch (e, st) {
        c.completeError(e, st);
      }
    });
    return c.future;
  }

  /// Bir komut uygular. [apply] başarısız olursa (ret) adım yığına girmez;
  /// köprü retlerde belgeye dokunmadığı için sayfa olduğu gibi kalır.
  Future<void> run({
    required int pageIndex,
    required String label,
    String detail = '',
    PdfEditOp? op,
    required Future<void> Function() apply,
  }) =>
      _serial(() async {
        _ensureAlive();
        final before = await _snapshots.take(pageIndex);
        if (before == 0) {
          throw const PdfEditBridgeRefused('Sayfanın yedeği alınamadı.');
        }
        try {
          await apply();
        } catch (_) {
          await _snapshots.release(before);
          rethrow;
        }
        for (final s in _undone) {
          await _release(s);
        }
        _undone.clear();
        _done.add(
            PdfEditStep._(_nextId++, pageIndex, label, detail, op, before));
        _notify();
      });

  /// [op]'u bağlı belgeye komut olarak uygular.
  Future<void> apply(PdfEditOp op,
      {required String label, String detail = ''}) {
    final doc = document;
    if (doc == null) throw StateError('Oturum bir belgeye bağlı değil.');
    return run(
      pageIndex: op.pageIndex,
      label: label,
      detail: detail,
      op: op,
      apply: () => op.applyTo(doc),
    );
  }

  /// Son adımı geri alır; alınamazsa false (yığın değişmez).
  Future<bool> undo() => _serial(() async {
        _ensureAlive();
        if (_done.isEmpty) return false;
        final step = _done.last;
        if (step._after == 0) {
          step._after = await _snapshots.take(step.pageIndex);
          if (step._after == 0) return false;
        }
        if (!await _snapshots.restore(step.pageIndex, step._before)) {
          return false;
        }
        _restored = true;
        _done.removeLast();
        _undone.add(step);
        _notify();
        return true;
      });

  Future<bool> redo() => _serial(() async {
        _ensureAlive();
        if (_undone.isEmpty) return false;
        final step = _undone.last;
        if (!await _snapshots.restore(step.pageIndex, step._after)) {
          return false;
        }
        _restored = true;
        _undone.removeLast();
        _done.add(step);
        _notify();
        return true;
      });

  /// Belge şimdiki hâliyle kaydedildi.
  void markSaved() {
    _savedIds = [for (final s in _done) s.id];
    _savedPageState = _pageState(_done.map((s) => (s.pageIndex, s.id)));
    _notify();
  }

  /// Kaydedilmemiş değişiklikleri bırakır: belge son kayıtlı hâline döner.
  /// Kayıtlı hâl yığından erişilemiyorsa (kayıttan sonra geri alıp başka yöne
  /// gidilmiş) false — çağıran belgeyi diskten yeniden okur.
  Future<bool> revertToSaved() async {
    while (dirty) {
      final k = _prefix;
      final bool moved;
      if (_done.length > k) {
        moved = await undo();
      } else if (_undone.isNotEmpty && _undone.last.id == _savedIds[k]) {
        moved = await redo();
      } else {
        return false;
      }
      if (!moved) return false;
    }
    return true;
  }

  Future<void> _release(PdfEditStep s) async {
    await _snapshots.release(s._before);
    if (s._after != 0) await _snapshots.release(s._after);
  }

  bool _gone = false;

  void _notify() {
    if (!_gone) notifyListeners();
  }

  void _ensureAlive() {
    if (_disposed) throw StateError('Oturum kapandı.');
  }

  /// Anlık görüntüleri bırakır. Belge kapanmadan ÖNCE çağrılmalı.
  Future<void> close() async {
    if (_disposed) return;
    await _serial(() async {
      _disposed = true;
      for (final s in [..._done, ..._undone]) {
        await _release(s);
      }
      _done.clear();
      _undone.clear();
    });
  }

  @override
  void dispose() {
    _gone = true;
    unawaited(close());
    super.dispose();
  }
}
