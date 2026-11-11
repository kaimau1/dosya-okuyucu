import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:pdfrx/pdfrx.dart';

import '../../services/pdf/pro/pdf_edit_bridge.dart';
import '../../services/pdf/pro/pdf_edit_recovery.dart';
import '../../services/pdf/pro/pdf_edit_save.dart';
import '../../services/pdf/pro/pdf_edit_session.dart';

/// **Düzenleme kipinin durumu** (PDF Pro Faz 54 / 2, PK3 — tek yüzey).
///
/// Görüntüleyici ekranı düzenleme kipine girince bunu kurar: oturum (komut
/// yığını), kayıt, sayfa başına blok önbelleği, seçili blok, çökme günlüğü
/// ve 30 sn'lik geçici kayıt. Ekran değişmez; belge yeniden yüklenmez.
class PdfProEditController extends ChangeNotifier {
  PdfProEditController({
    required this.document,
    required this.path,
    PdfPasswordProvider? password,
    Duration? snapshotEvery,
  })  : session = PdfEditSession.forDocument(document),
        super() {
    saver = PdfEditSaver(session: session, path: path, password: password);
    session.addListener(_onSession);
    PdfEditRecovery.begin(path);
    _timer = Timer.periodic(
        snapshotEvery ?? PdfEditRecovery.snapshotEvery, (_) => _snapshot());
  }

  final PdfDocument document;
  final String path;
  final PdfEditSession session;
  late final PdfEditSaver saver;

  Timer? _timer;
  final Map<int, List<PdfTextBlock>> _blocks = {};
  final Set<int> _loading = {};
  bool _closed = false;
  bool _busy = false;
  int _changes = 0, _snapshotAt = 0;

  /// Seçili blok: sayfa (0 tabanlı) ve o sayfanın blok listesindeki sıra.
  int? selectedPage, selectedBlock;

  /// Bir düzenleme/kayıt sürüyor (düğmeler bekler).
  bool get busy => _busy;

  /// Bu oturumda özgün dosyanın üstüne kaydedildi mi? Öyleyse diskteki dosya
  /// artık belgenin AÇILDIĞI baytlar değildir; oturum kapanınca görüntüleyici
  /// belgeyi diskten yeniden okur.
  bool get savedOverOriginal => _savedOver;
  bool _savedOver = false;

  /// Sayfanın blokları; henüz okunmadıysa okumayı başlatır ve null döner
  /// (bitince dinleyiciler uyarılır).
  List<PdfTextBlock>? blocksOf(int pageIndex) {
    final hit = _blocks[pageIndex];
    if (hit != null) return hit;
    if (_closed || !_loading.add(pageIndex)) return null;
    unawaited(() async {
      try {
        final b = await PdfEditBridge.blocks(document, pageIndex);
        if (_closed) return;
        _blocks[pageIndex] = b;
      } catch (_) {
        if (_closed) return;
        // Okunamayan sayfa "blok yok" sayılır; yeniden denemek için önbellek
        // boş listeyle dolar (sonsuz yeniden deneme yok).
        _blocks[pageIndex] = const [];
      } finally {
        _loading.remove(pageIndex);
      }
      _notify();
    }());
    return null;
  }

  PdfTextBlock? get selected {
    final p = selectedPage, b = selectedBlock;
    if (p == null || b == null) return null;
    final list = _blocks[p];
    return list == null || b >= list.length ? null : list[b];
  }

  void select(int pageIndex, int? block) {
    if (selectedPage == pageIndex && selectedBlock == block) return;
    selectedPage = block == null ? null : pageIndex;
    selectedBlock = block;
    _notify();
  }

  void clearSelection() {
    if (selectedBlock == null) return;
    selectedPage = null;
    selectedBlock = null;
    _notify();
  }

  Future<T> _guard<T>(Future<T> Function() job) async {
    _busy = true;
    _notify();
    try {
      return await job();
    } finally {
      _busy = false;
      _notify();
    }
  }

  void _invalidate(int pageIndex) {
    _blocks.remove(pageIndex);
    if (selectedPage == pageIndex) {
      selectedPage = null;
      selectedBlock = null;
    }
  }

  /// [block]'un metnini değiştirir (geri alınabilir komut). Reddedilirse
  /// [PdfEditBridgeRefused]; belge değişmez.
  Future<void> replace(int pageIndex, PdfTextBlock block, String text,
          {required String label}) =>
      _guard(() async {
        await session.apply(PdfReplaceBlockOp.of(pageIndex, block, text),
            label: label, detail: _excerpt(text));
        _invalidate(pageIndex);
      });

  Future<bool> undo() => _guard(() async {
        final page = session.undoStep?.pageIndex;
        final ok = await session.undo();
        if (ok && page != null) _invalidate(page);
        return ok;
      });

  Future<bool> redo() => _guard(() async {
        final page = session.redoStep?.pageIndex;
        final ok = await session.redo();
        if (ok && page != null) _invalidate(page);
        return ok;
      });

  Future<PdfEditSaveResult> save() => _guard(() async {
        final r = await saver.save();
        if (r.overwritten) {
          _savedOver = true;
          await PdfEditRecovery.clear(path);
        }
        return r;
      });

  Future<PdfEditSaveResult> saveAs({bool documents = false}) =>
      _guard(() => saver.saveAs(documents: documents));

  /// Kaydedilmemiş değişiklikleri bırakır; false → çağıran belgeyi diskten
  /// yeniden okumalı (kayıtlı hâle yığından dönülemedi).
  Future<bool> revert() => _guard(() async {
        final ok = await session.revertToSaved();
        _blocks.clear();
        selectedPage = null;
        selectedBlock = null;
        return ok;
      });

  /// Çökmeden kalan günlüğü oynatır; uygulanan adım sayısı.
  Future<int> recover(PdfEditRecoveryEntry entry) => _guard(() async {
        final n = await PdfEditRecovery.replay(session, entry);
        _blocks.clear();
        return n;
      });

  void _onSession() {
    _changes++;
    unawaited(PdfEditRecovery.writeJournal(path, session.stepsSinceSaved));
    _notify();
  }

  Future<void> _snapshot() async {
    if (_closed || _busy || !session.dirty || _snapshotAt == _changes) return;
    final at = _changes;
    try {
      final bytes = await saver.encode();
      if (_closed) return;
      await PdfEditRecovery.writeSnapshot(path, bytes);
      _snapshotAt = at;
    } catch (_) {
      // Bilinçli: geçici kayıt bir emniyet ağı; sıradaki turda yeniden denenir.
    }
  }

  /// Geçici kaydı hemen yazar (test ve uygulama arka plana giderken).
  @visibleForTesting
  Future<void> snapshotNow() => _snapshot();

  static String _excerpt(String text) {
    final t = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    return t.length <= 24 ? t : '${t.substring(0, 24)}…';
  }

  void _notify() {
    if (!_closed) notifyListeners();
  }

  /// Oturumu kapatır. [keepRecovery] true → çökme kaydı silinmez (belge
  /// arkamızdan yeniden yüklendiyse kaydedilmemiş iş kurtarılabilsin).
  Future<void> close({bool keepRecovery = false}) async {
    if (_closed) return;
    _closed = true;
    _timer?.cancel();
    session.removeListener(_onSession);
    await session.close();
    await saver.dispose();
    if (keepRecovery) {
      PdfEditRecovery.abandon(path);
    } else {
      await PdfEditRecovery.end(path);
    }
  }

  @override
  void dispose() {
    unawaited(close(keepRecovery: session.dirty));
    super.dispose();
  }
}
