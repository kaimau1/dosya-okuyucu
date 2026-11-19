import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/app_state.dart';
import '../../core/theme.dart';
import '../../models/fs_entry.dart';
import '../../services/file_service.dart';
import '../../services/fm/ai_analyzer.dart';
import '../../services/fm/ai_index.dart';
import '../../services/fm/file_tags.dart';
import '../../services/fm/smart_sort.dart';
import '../../services/fm/smart_sort_input.dart';
import '../../widgets/app_dialog.dart';
import '../../services/fm/doc_classifier.dart';
import '../../services/fm/file_ops.dart';
import '../../services/fm/fm_env.dart';
import '../../services/fm/tracked_task.dart';
import '../../services/gemini_decisions.dart';
import '../../services/gemini_service.dart';
import 'image_insight.dart';
import 'important_screen.dart';
import '../../core/snack.dart';
import '../../core/user_error.dart';
import '../../widgets/ai_key_gate.dart';

/// Dosya üzerinde **Akıllı** işlemler: ikinci ad + kategori, elle ikinci ad,
/// görsel kısa özeti. 2026-11-19 (B15, kullanıcı kararı): "AI ile özetle"
/// budandı — kayıtlı özetler diskte kalır (`AiSummaryStore`), arayüz yok.
///
/// **Akıllı ikinci ad + etiket** (2026-11-18, kullanıcı: *"AI ile 2. ad ver
/// bu olsun artık; yeni model hem ad versin hem etiketini"*).
///
/// Önce **yeni model** (Gemini Decisions, [SmartSort.classifyOne]): görsel/PDF
/// olduğu gibi, Word/metin okunan yazıyla tek istekte sorulur → "Elektrik
/// faturası · Ekim 2026" gibi ikinci ad + AI kategorisi; kategori aynı anda
/// dosyanın **etiketi** olur ([FileTags], Etiketler süzgecinde görünür).
/// Ses/video da yeni modelle (2026-11-18). Yeni model ad çıkaramazsa
/// (kişisel fotoğraf, aile videosu, düşük güven) eski
/// yol: üretken AI analizi yalnız bu dosya için ([AiAnalyzer]).
///
/// AI'dan istendiği için önceki ELLE ad bırakılır (yeni ad görünsün); iş
/// sürerken kalıcı kart, bitince "Şu adı koydum: … · Etiket: …" + Değiştir.
Future<void> giveAiAlias(BuildContext context, FsEntry entry) async {
  if (!await ensureAiKey(context) || !context.mounted) return;
  final state = context.read<AppState>();
  if (!state.aiScopeRules.allowsFile(entry)) {
    showSnack(context, context.t('qc.scope_off'));
    return;
  }
  final nav = Navigator.of(context, rootNavigator: true);
  final str = AppStrings.of(context);
  final live = showStickyToast(
    context,
    Row(children: [
      const SizedBox(
        width: 16,
        height: 16,
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
      const SizedBox(width: Gap.md),
      Expanded(child: Text(str.t('alias.started'))),
    ]),
  );
  await AiIndex.ensureLoaded();
  // Elle ad bırakılır: AI'dan yeni ad istendi.
  final before = AiIndex.of(entry.path);
  if (before != null && before.alias.isNotEmpty) {
    await AiIndex.put(before.copyWith(alias: ''));
  }
  var tag = '';
  var alias = '';
  try {
    final rec = await SmartSort.classifyOne(
      entry: entry,
      credentials: state.aiCredentials,
      // Ses/video bloğunu (ilk 60 sn, büyükse Files API) SmartSort kurar.
      input: switch (SmartSortInput.kindOf(entry.path)) {
        SmartInputKind.audio || SmartInputKind.video => const [],
        _ => await quickCheckInput(entry.path, str),
      },
    );
    if (rec != null) {
      alias = SmartSort.render(rec, str);
      if (alias.isNotEmpty && rec.cat != 'other') {
        tag = str.t('sm.c_${rec.cat}');
        await FileTags.add([entry.path], tag);
      }
    }
  } catch (_) {
    // Bilinçli: yeni model düşerse aşağıdaki eski yol dener.
  }
  if (alias.isEmpty && !AiAnalyzer.isRunning) {
    await AiAnalyzer.start(
      scope: state.aiScopeRules,
      credentials: state.aiCredentials,
      reanalyze: true,
      candidates: [entry],
    );
    await AiAnalyzer.whenIdle
        .timeout(const Duration(minutes: 5), onTimeout: () {});
    final rec = AiIndex.of(entry.path);
    if (rec != null && rec.alias.isNotEmpty && rec.title.isNotEmpty) {
      await AiIndex.put(rec.copyWith(alias: ''));
    }
    alias = AiIndex.aliasOf(entry.path);
  }
  live.close();
  if (!nav.mounted) return;
  if (alias.isEmpty) {
    showSnack(nav.context, str.t('alias.failed'));
    return;
  }
  showSnack(
    nav.context,
    tag.isEmpty
        ? str.t('alias.done', {'name': alias})
        : str.t('alias.done_tag', {'name': alias, 'tag': tag}),
    duration: const Duration(seconds: 8),
    action: SnackBarAction(
      label: str.t('alias.change'),
      onPressed: () {
        if (nav.mounted) editAlias(nav.context, entry);
      },
    ),
  );
}

/// **Toplu AI ile ikinci ad** (2026-11-19, kullanıcı: *"belgeleri, fotoları
/// seçip toplu biçimde yeni AI modeli ile ikinci ad verme olmalı; burada
/// eski etiket mantığı kalmış"*). Tek dosyadaki [giveAiAlias] ile aynı yeni
/// model ([SmartSort.classifyOne]) her dosyaya; kategori etiket de olur.
/// İş iş kuyruğunda (bildirim + şerit, "Durdur"), ekrandan çıkılsa da sürer.
/// Klasörler ve AI kapsamı dışındakiler atlanır; en çok [maxAliasBatch].
const maxAliasBatch = 300;

Future<void> giveAiAliasBatch(BuildContext context, List<FsEntry> entries) async {
  if (!await ensureAiKey(context) || !context.mounted) return;
  final state = context.read<AppState>();
  final str = AppStrings.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final scope = state.aiScopeRules;
  final todo = [
    for (final e in entries)
      if (!e.isDir && scope.allowsFile(e)) e
  ].take(maxAliasBatch).toList();
  if (todo.isEmpty) {
    showSnackOn(messenger, str.t('qc.scope_off'));
    return;
  }
  final credentials = state.aiCredentials;
  final task = TrackedTask(
    title: str.t('alias.batch_title'),
    name: str.t('alias.batch_name', {'n': todo.length}),
    threshold: Duration.zero,
  );
  task.report(done: 0, total: todo.length);
  showSnackOn(messenger, str.t('alias.batch_started', {'n': todo.length}));
  await AiIndex.ensureLoaded();
  var named = 0, failed = 0, done = 0;
  String? stoppedBy;
  final queue = [...todo];
  Future<void> worker() async {
    while (queue.isNotEmpty && stoppedBy == null && !task.cancelRequested) {
      final e = queue.removeAt(0);
      try {
        final rec = await SmartSort.classifyOne(
          entry: e,
          credentials: credentials,
          input: switch (SmartSortInput.kindOf(e.path)) {
            SmartInputKind.audio || SmartInputKind.video => const [],
            _ => await quickCheckInput(e.path, str),
          },
        );
        final alias = rec == null ? '' : SmartSort.render(rec, str);
        if (rec != null && alias.isNotEmpty) {
          // AI'dan istendi: elle verilmiş eski ad yenisini gölgelemesin.
          final before = AiIndex.of(e.path);
          if (before != null && before.alias.isNotEmpty) {
            await AiIndex.put(before.copyWith(alias: ''));
          }
          if (rec.cat != 'other') {
            await FileTags.add([e.path], str.t('sm.c_${rec.cat}'));
          }
          named++;
        } else {
          failed++;
        }
      } on GeminiException catch (err) {
        failed++;
        if (const {401, 403, 429}.contains(err.statusCode)) {
          stoppedBy = err.message;
        }
      } catch (_) {
        failed++;
      }
      done++;
      task.report(done: done, detail: e.name);
    }
  }

  await Future.wait([worker(), worker()]);
  final detail = [
    str.t('alias.batch_done', {'n': named}),
    if (failed > 0) str.t('alias.batch_failed', {'n': failed}),
    ?stoppedBy,
  ].join(' · ');
  if (task.cancelRequested || stoppedBy != null) {
    await task.stopped(detail: detail);
  } else {
    await task.complete(detail: detail);
  }
  if (TrackedTask.userWatching) showSnackOn(messenger, detail);
}

/// İkinci adı **elle** yazdırır (2026-11-10). Orijinal dosya adı değişmez;
/// ad satırda ve aramada görünür, AI yeniden analizi bunu ezmez.
Future<void> editAlias(BuildContext context, FsEntry entry) async {
  await AiIndex.ensureLoaded();
  if (!context.mounted) return;
  final current = AiIndex.aliasOf(entry.path);
  final text = await showAppPrompt(
    context,
    title: context.t('alias.manual'),
    label: context.t('alias.label'),
    initial: current,
    confirmLabel: context.t('common.save'),
    maxLength: 80,
  );
  if (text == null || text == current) return;
  await AiIndex.setAlias(entry, text);
  if (context.mounted) {
    showSnack(context, context.t('alias.saved', {'name': text}));
  }
}

/// "Görselde ne var?" — AI kısa özeti + tür + katlanır metin (2026-11-18,
/// bkz. [showImageInsightSheet]). Eskiden ham OCR satırlarını döküyordu.
Future<void> showImageInsight(BuildContext context, FsEntry entry) =>
    showImageInsightSheet(context, entry);

/// Tahmine göre `Önemli Dosyalar/<klasör>` altına taşır.
Future<bool> fileIntoSuggestedFolder(
  BuildContext context,
  FsEntry entry,
  DocClass type,
) async {
  final dest =
      p.join(ImportantScreen.pathIn(FmEnv.primaryRoot), type.folder);
  // Metinler await'ten ÖNCE (asenkron boşluktan sonra `context` yok).
  final str = AppStrings.of(context);
  try {
    final dir = Directory(dest);
    await dir.create(recursive: true); // varsa dokunmaz
    final result = await FileOps.moveAll([entry.path], dest);
    if (!context.mounted) return result.succeeded > 0;
    _snack(
      context,
      result.hasError
          ? str.t('aia.move_failed', {'error': result.errors.first})
          : str.t('aia.moved',
              {'name': entry.name, 'folder': type.folder}),
    );
    return result.succeeded > 0;
  } catch (e) {
    if (context.mounted) _snack(context, str.t('aia.move_failed', {'error': userErrorText(e)}));
    return false;
  }
}

void _snack(BuildContext context, String message) {
  showSnack(context, message);
}

/// Dosya → Decisions girdi bloğu: PDF/görsel/ses/video olduğu gibi; ötekiler
/// (Word, metin, tablo…) okunan düz yazıyla (en çok 60 000 karakter).
/// Akıllı ikinci ad ([giveAiAlias], [giveAiAliasBatch]) kullanır.
Future<List<Map<String, Object?>>> quickCheckInput(
    String path, AppStrings s) async {
  if (GeminiDecisions.mediaFor(path) != null) {
    return [
      await GeminiDecisions.fileBlock(path,
          tooLarge: s.t('qc.too_large'), unsupported: s.t('qc.unsupported'))
    ];
  }
  final text = (await FileService().load(path)).plainText.trim();
  if (text.isEmpty) {
    throw GeminiException(s.t('qc.unsupported'), statusCode: -1);
  }
  return [
    GeminiDecisions.textBlock(
        text.length > 60000 ? text.substring(0, 60000) : text)
  ];
}
