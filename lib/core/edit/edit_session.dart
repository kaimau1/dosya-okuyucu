/// Bir düzenleme oturumu: kirli durum, kaydetme durumu, taslak günlüğü,
/// otomatik kaydetme ve **tek tip çıkış sorusu** (Faz 20 / ED2, K21).
///
/// Eskiden her editör kendi `_dirty` bayrağını tutuyordu; Word, Excel ve
/// slaytta ekrandan çıkarken hiç soru sorulmuyordu (yazılan sessizce
/// kayboluyordu), PDF / görsel / metin üç ayrı diyalog kullanıyordu.
/// Şimdi editör yalnız üç şey verir: belgenin o anki baytları ([snapshot],
/// taslak için), dosyaya yazma işi ([save]) ve değişiklik bildirimi
/// ([changed]). Gerisi burada.
library;

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../app_icons.dart';
import '../l10n/app_strings.dart';
import '../snack.dart';
import 'draft_journal.dart';
import 'editor_perf.dart';
import 'save_coordinator.dart';

/// Belgeler ayarları (Ayarlar > Belgeler). [AppState] açılışta doldurur.
class EditPrefs {
  EditPrefs._();

  /// K21: dosyaya otomatik kaydetme (varsayılan AÇIK). Taslak günlüğü bundan
  /// bağımsız, her zaman çalışır.
  static bool autoSave = true;

  /// Word canlı düzenlemede yazım denetimi + otomatik düzeltme + cümle başı
  /// büyük harf (Faz 21 / W8, varsayılan AÇIK).
  static bool wordSpellcheck = true;

  /// Excel: Türkçe arayüzde de formülleri İngilizce ad + `,` ile göster
  /// (Faz 25 / K22, varsayılan KAPALI).
  static bool formulaEnglish = false;
}

/// Çıkış sorusunun cevabı.
enum UnsavedChoice { save, discard, cancel }

/// Altı editörün ortak "kaydedilmemiş değişiklikler" sorusu:
/// **Kaydet · Kaydetme · İptal**.
Future<UnsavedChoice> showUnsavedChanges(BuildContext context) async {
  final choice = await showDialog<UnsavedChoice>(
    context: context,
    builder: (ctx) => AlertDialog(
      key: const ValueKey('unsaved-dialog'),
      title: Text(ctx.t('edit.unsaved_title')),
      content: Text(ctx.t('edit.unsaved_body')),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx, UnsavedChoice.cancel),
            child: Text(ctx.t('common.cancel'))),
        TextButton(
            key: const ValueKey('unsaved-discard'),
            onPressed: () => Navigator.pop(ctx, UnsavedChoice.discard),
            child: Text(ctx.t('edit.dont_save'))),
        FilledButton(
            key: const ValueKey('unsaved-save'),
            onPressed: () => Navigator.pop(ctx, UnsavedChoice.save),
            child: Text(ctx.t('common.save'))),
      ],
    ),
  );
  return choice ?? UnsavedChoice.cancel;
}

class EditSession extends ChangeNotifier with WidgetsBindingObserver {
  /// Taslak anahtarı ve dış değişiklik denetimi için kaynak dosya.
  final String sourcePath;

  /// Editör türü ('word', 'excel', 'slides', 'text', 'pdf', 'image').
  final String editor;

  /// Belgenin o anki baytları (taslak için). null dönerse taslak yazılmaz.
  final Future<Uint8List?> Function()? snapshot;

  /// Dosyaya yazma işi; hata fırlatırsa kayıt başarısız sayılır.
  final Future<void> Function() save;

  /// Taslak sıklığı: son değişiklikten bu kadar sonra ya da [draftEvery]
  /// değişiklikte bir.
  final Duration draftDelay;
  final int draftEvery;

  /// Otomatik kaydetme: son değişiklikten bu kadar boşluk sonra.
  final Duration autoSaveDelay;

  final SaveCoordinator coordinator = SaveCoordinator();

  bool _dirty = false;
  int _generation = 0;
  int _changesSinceDraft = 0;
  Timer? _draftTimer;
  Timer? _autoTimer;
  bool _autoSaveForDoc = true;
  bool _writable = true;
  (int, int)? _stamp;
  bool _disposed = false;

  EditSession({
    required this.sourcePath,
    required this.editor,
    required this.save,
    this.snapshot,
    this.draftDelay = const Duration(seconds: 3),
    this.draftEvery = 20,
    this.autoSaveDelay = const Duration(seconds: 5),
    bool observeLifecycle = true,
  }) {
    coordinator.status.addListener(notifyListeners);
    if (observeLifecycle) WidgetsBinding.instance.addObserver(this);
    _observing = observeLifecycle;
  }

  late final bool _observing;

  bool get isDirty => _dirty;
  SaveStatus get status => coordinator.status.value;
  DateTime? get lastSavedAt => coordinator.lastSavedAt;

  /// Otomatik kaydetme bu belgede etkin mi (genel ayar + belge başına ⋮
  /// anahtarı + kaynak yazılabilir).
  bool get autoSave => EditPrefs.autoSave && _autoSaveForDoc && _writable;
  bool get autoSaveForDoc => _autoSaveForDoc;

  set autoSaveForDoc(bool v) {
    _autoSaveForDoc = v;
    if (!v) _autoTimer?.cancel();
    notifyListeners();
  }

  /// Kaynak dosyanın açılıştaki boy + değiştirilme zamanı; yazılabilirlik.
  Future<void> captureSource() async {
    _stamp = await _statOf(sourcePath);
    _writable = await _canWrite(sourcePath);
  }

  /// Dosya biz açtıktan sonra BAŞKA bir yerde değişti mi (kaydetme onun
  /// üstüne yazmasın — "dosya başka yerde değişti" uyarısı).
  Future<bool> sourceChangedExternally() async {
    final was = _stamp;
    if (was == null) return false;
    final now = await _statOf(sourcePath);
    return now != null && now != was;
  }

  /// Editör her değişiklikte çağırır.
  void changed() {
    EditorPerf.mark(editor);
    _generation++;
    if (!_dirty) {
      _dirty = true;
      notifyListeners();
    }
    _changesSinceDraft++;
    _draftTimer?.cancel();
    if (_changesSinceDraft >= draftEvery) {
      unawaited(writeDraft());
    } else {
      _draftTimer = Timer(draftDelay, () => unawaited(writeDraft()));
    }
    _autoTimer?.cancel();
    if (autoSave) {
      _autoTimer = Timer(autoSaveDelay, () => unawaited(saveNow(auto: true)));
    }
  }

  /// Taslağı şimdi yazar (arka plana geçerken de çağrılır).
  Future<void> writeDraft() async {
    _draftTimer?.cancel();
    _changesSinceDraft = 0;
    if (!_dirty || snapshot == null) return;
    try {
      final bytes = await snapshot!();
      if (bytes == null || !_dirty) return;
      final journal = await DraftJournal.shared();
      await journal.write(sourcePath, bytes, editor: editor);
    } catch (_) {
      // Taslak en iyi çaba: yazılamazsa belge yine düzenlenir.
    }
  }

  /// Dosyaya kaydeder. [auto] = otomatik kaydetme (dış değişiklikte sessizce
  /// vazgeçer, kullanıcıya bir kez söylenir).
  Future<bool> saveNow({bool auto = false}) async {
    _autoTimer?.cancel();
    if (auto && await sourceChangedExternally()) {
      _externalConflict = true;
      notifyListeners();
      return false;
    }
    final gen = _generation;
    final ok = await coordinator.save(save);
    if (_disposed) return ok;
    if (ok) {
      // Kendi yazdığımız dosya "dışarıda değişti" sayılmasın: damga tazelenir
      // (beklenmez — kaydetmenin bitişini disk sorgusu geciktirmesin).
      _stamp = null;
      unawaited(_statOf(sourcePath).then((v) => _stamp = v));
      _externalConflict = false;
      if (_generation == gen) {
        _dirty = false;
        unawaited(_dropDraft());
      }
      notifyListeners();
    }
    return ok;
  }

  bool _externalConflict = false;

  /// Otomatik kaydetme dosyanın dışarıda değiştiğini gördü ve yazmadı.
  bool get externalConflict => _externalConflict;

  /// Değişikliklerden vazgeçildi: taslak silinir, belge temiz sayılır.
  Future<void> discard() async {
    _draftTimer?.cancel();
    _autoTimer?.cancel();
    _dirty = false;
    notifyListeners();
    unawaited(_dropDraft());
  }

  /// Taslağı arkada siler (en iyi çaba; çıkışı bekletmez).
  Future<void> _dropDraft() async {
    try {
      await (await DraftJournal.shared()).discard(sourcePath);
    } catch (_) {}
  }

  /// Editör kendi yolundan kaydettiyse (Farklı kaydet …) temiz işaretler.
  void markSaved() {
    _dirty = false;
    coordinator.lastSavedAt = DateTime.now();
    coordinator.status.value = SaveStatus.saved;
    notifyListeners();
  }

  /// Ekrandan çıkmadan önce: kirliyse otomatik kaydet ya da sor. Çıkılabilirse
  /// true.
  Future<bool> confirmLeave(BuildContext context) async {
    if (!_dirty) return true;
    if (autoSave && !_externalConflict) {
      if (await saveNow()) return true;
      if (!context.mounted) return false;
    }
    final choice = await showUnsavedChanges(context);
    switch (choice) {
      case UnsavedChoice.save:
        return saveNow();
      case UnsavedChoice.discard:
        await discard();
        return true;
      case UnsavedChoice.cancel:
        return false;
    }
  }

  /// Üst çubuğun durum satırı ("Kaydediliyor… / Kaydedildi 14:32 /
  /// Kaydedilmedi"); söylenecek bir şey yoksa null.
  String? statusText(AppStrings s) {
    if (status == SaveStatus.saving) return s.t('edit.saving');
    if (_externalConflict) return s.t('edit.changed_elsewhere');
    if (_dirty) {
      return status == SaveStatus.failed
          ? s.t('edit.save_failed_short')
          : s.t('shell.unsaved');
    }
    final at = lastSavedAt;
    if (at == null) return null;
    final hh = at.hour.toString().padLeft(2, '0');
    final mm = at.minute.toString().padLeft(2, '0');
    return s.t('edit.saved_at', {'time': '$hh:$mm'});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      unawaited(writeDraft());
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _draftTimer?.cancel();
    _autoTimer?.cancel();
    if (_observing) WidgetsBinding.instance.removeObserver(this);
    coordinator.status.removeListener(notifyListeners);
    coordinator.dispose();
    super.dispose();
  }

  static Future<(int, int)?> _statOf(String path) async {
    try {
      final st = await File(path).stat();
      if (st.type == FileSystemEntityType.notFound) return null;
      return (st.size, st.modified.millisecondsSinceEpoch);
    } catch (_) {
      return null;
    }
  }

  static Future<bool> _canWrite(String path) async {
    try {
      final f = File(path);
      if (!await f.exists()) return false;
      final raf = await f.open(mode: FileMode.append);
      await raf.close();
      return true;
    } catch (_) {
      return false;
    }
  }
}

/// Geri tuşu sırası (§5 madde 2): önce açık katman (panel, klavye, arama,
/// seçim, düzenleme kipi) — [closeLayer] true dönerse tüketildi; sonra kirli
/// belge için [EditSession.confirmLeave]; en son ekran kapanır.
class EditExitGuard extends StatelessWidget {
  final EditSession? session;

  /// Açık bir katman var mı (varsa geri tuşu önce onu kapatır).
  final bool hasOpenLayer;
  final VoidCallback? closeLayer;
  final Widget child;

  const EditExitGuard({
    super.key,
    required this.session,
    required this.child,
    this.hasOpenLayer = false,
    this.closeLayer,
  });

  @override
  Widget build(BuildContext context) {
    final s = session;
    if (s == null) {
      return PopScope(
        canPop: !hasOpenLayer,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop && hasOpenLayer) closeLayer?.call();
        },
        child: child,
      );
    }
    return ListenableBuilder(
      listenable: s,
      builder: (context, child) => PopScope(
        canPop: !hasOpenLayer && !s.isDirty,
        onPopInvokedWithResult: (didPop, _) async {
          if (didPop) return;
          if (hasOpenLayer) {
            closeLayer?.call();
            return;
          }
          final nav = Navigator.of(context);
          if (await s.confirmLeave(context)) {
            if (nav.mounted) nav.pop();
          }
        },
        child: child!,
      ),
      child: child,
    );
  }
}

/// Belgenin üstündeki "Kaydedilmemiş değişiklikler bulundu" şeridi.
class DraftRecoveryBanner extends StatelessWidget {
  final DraftInfo draft;
  final VoidCallback onRestore;
  final VoidCallback onDiscard;

  const DraftRecoveryBanner({
    super.key,
    required this.draft,
    required this.onRestore,
    required this.onDiscard,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final at = draft.savedAt;
    final time =
        '${at.hour.toString().padLeft(2, '0')}:${at.minute.toString().padLeft(2, '0')}';
    return Material(
      key: const ValueKey('draft-banner'),
      color: scheme.secondaryContainer,
      child: SafeArea(
        top: false,
        bottom: false,
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 8, 8),
          child: Row(
            children: [
              Icon(AppIcons.draftRestore,
                  color: scheme.onSecondaryContainer),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  context.t('edit.draft_found', {'time': time}),
                  style: TextStyle(color: scheme.onSecondaryContainer),
                ),
              ),
              TextButton(
                  key: const ValueKey('draft-discard'),
                  onPressed: onDiscard,
                  child: Text(context.t('edit.draft_discard'))),
              FilledButton.tonal(
                  key: const ValueKey('draft-restore'),
                  onPressed: onRestore,
                  child: Text(context.t('edit.draft_restore'))),
            ],
          ),
        ),
      ),
    );
  }
}

/// Editör ekranlarının ortak taslak kurtarma akışı: açılışta [lookForDraft],
/// gövdede [withDraftBanner]. "Geri yükle" baytları editörün [restore]'una
/// verir; "Sil" taslağı atar.
mixin DraftRecoveryMixin<T extends StatefulWidget> on State<T> {
  DraftInfo? pendingDraft;

  /// Kaynak için geçerli bir taslak var mı bakar (yoksa sessiz).
  Future<void> lookForDraft(String sourcePath) async {
    try {
      final journal = await DraftJournal.shared();
      unawaited(journal.prune());
      final found = await journal.find(sourcePath);
      if (found != null && mounted) setState(() => pendingDraft = found);
    } catch (_) {
      // path_provider yok (test) ya da klasör okunamadı: kurtarma yok.
    }
  }

  Widget withDraftBanner(Widget body,
      {required Future<void> Function(Uint8List bytes) restore}) {
    final draft = pendingDraft;
    if (draft == null) return body;
    return Column(
      children: [
        DraftRecoveryBanner(
          draft: draft,
          onRestore: () async {
            final bytes = await draft.read();
            await restore(bytes);
            if (!mounted) return;
            setState(() => pendingDraft = null);
            showSnack(context, context.t('edit.draft_restored'));
          },
          onDiscard: () async {
            setState(() => pendingDraft = null);
            try {
              await (await DraftJournal.shared()).discard(draft.sourcePath);
            } catch (_) {}
          },
        ),
        Expanded(child: body),
      ],
    );
  }
}
