import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/app_icons.dart';
import '../../core/busy_dialog.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/app_state.dart';
import '../../core/theme.dart';
import '../../models/document.dart';
import '../../models/fs_entry.dart';
import '../../services/ai_summary_store.dart';
import '../../services/file_service.dart';
import '../../services/fm/doc_classifier.dart';
import '../../services/fm/file_ops.dart';
import '../../services/fm/fm_env.dart';
import '../../services/fm/job_queue.dart';
import '../../services/fm/tracked_task.dart';
import '../../services/gemini_service.dart';
import '../../services/ocr_service.dart';
import '../../widgets/markdown_text.dart';
import '../../widgets/tracked_busy.dart';
import 'important_screen.dart';
import '../../core/snack.dart';
import '../../core/user_error.dart';
import '../../widgets/ai_key_gate.dart';

/// Dosya üzerinde **AI ve tanıma** işlemleri: belge özeti, görselden metin
/// tanıma + otomatik sınıflandırma.
///
/// Tasarım kararları:
/// - **Sınıflandırma çevrimdışı ve ücretsiz** (`classifyDocumentText`): tek bir
///   fatura fotoğrafı için ağ isteği atmak yavaş ve gereksiz. AI yalnız
///   *özet* için, kullanıcı isteyince kullanılır.
/// - Sonuç bir **öneri**dir, otomatik taşıma YOK: "Faturalar klasörüne taşı"
///   düğmesine kullanıcı basar. Yanlış tahminle dosya kaybolmamalı.
/// - Uzun metin kırpılır (AI'ya 2 MB'lık PDF metni göndermek hem pahalı hem
///   gereksiz; özet için ilk ~12 bin karakter fazlasıyla yeter).
const _maxAiChars = 12000;

/// Belgeyi AI ile özetler ve sonucu bir sayfada gösterir.
///
/// 2026-10-23 (kullanıcı: *"ai özet hazırlanıyor ama açamıyorum, aynı dosyada
/// tekrar basınca yenisini yapmaya başlıyor"* + *"arka planda çalışabilmeli"*):
/// * dosyanın değişmemiş kayıtlı özeti varsa ANINDA açılır (yeni istek yok),
/// * özet sürüyorsa ikinci dokunuş yeni iş açmaz, sürene bağlanır,
/// * pencerede "Arka plana al" var: iş sürer, bitince bildirim gelir ve
///   bildirime/şeride dokununca özet açılır ([openSavedAiSummary]).
Future<void> showAiSummary(BuildContext context, FsEntry entry,
    {bool regenerate = false}) async {
  if (!regenerate && AiSummaryStore.running(entry.path) == null) {
    final saved = await AiSummaryStore.forFile(entry.path);
    if (!context.mounted) return;
    if (saved != null) {
      await _showSummarySheet(context, entry, saved);
      return;
    }
  }
  final appState = context.read<AppState>();
  // Metinler await'ten ÖNCE (asenkron boşluktan sonra `context` yok).
  final str = AppStrings.of(context);
  var run = AiSummaryStore.running(entry.path);
  if (run == null) {
    // Anahtar yoksa tek "AI'yı etkinleştir" penceresi (Faz 5, N3).
    if (!await ensureAiKey(context) || !context.mounted) return;
    if (regenerate) await AiSummaryStore.remove(entry.path);
    final gemini = appState.gemini;
    run = AiSummaryStore.start(
        entry.path, (run) => _summarizeFile(run, entry, gemini, str));
  }
  if (!context.mounted) return;
  await _watchSummary(context, entry, run);
}

/// Kaydedilmiş özeti açar (iş bildirimi/şeridi buraya gelir). Özet yoksa
/// ama iş sürüyorsa bekleme penceresi açılır.
Future<bool> openSavedAiSummary(BuildContext context, String path) async {
  final entry = FsEntry.ofPath(path);
  final run = AiSummaryStore.running(path);
  if (entry != null && run != null) {
    await _watchSummary(context, entry, run);
    return true;
  }
  final saved = await AiSummaryStore.read(path);
  if (saved == null || !context.mounted) return false;
  await _showSummarySheet(context, entry, saved);
  return true;
}

/// Süren işi pencerede izler; bitince (pencere hâlâ açıksa) özeti gösterir.
Future<void> _watchSummary(
    BuildContext context, FsEntry entry, RunningSummary run) async {
  final str = AppStrings.of(context);
  run.watched = true;
  final dialog = showTaskDialog(
    context,
    task: run.task!,
    message: run.status,
    onBackground: () => run.watched = false,
  );
  AiSummaryRecord? record;
  Object? error;
  try {
    record = await run.result;
  } catch (e) {
    error = e;
  }
  final stillWatching = dialog.isOpen;
  dialog.close();
  run.watched = false;
  if (!context.mounted || !stillWatching) return;
  if (error != null || record == null) {
    _snack(context, '$error'.isEmpty ? str.t('aia.no_text') : '$error');
    return;
  }
  await _showSummarySheet(context, entry, record);
}

/// İşin gövdesi — EKRANDAN BAĞIMSIZ: `context` kullanmaz, böylece kullanıcı
/// ekrandan çıksa da sürer ve sonucu diske yazılır.
Future<AiSummaryRecord> _summarizeFile(
  RunningSummary run,
  FsEntry entry,
  GeminiService gemini,
  AppStrings str,
) async {
  final task = run.task = TrackedTask(
    title: str.t('ai.sum_working'),
    name: str.t('aia.summary_title'),
    target: FmJobTarget(FmJobTargetKind.aiSummary,
        paths: [entry.path], title: entry.name),
  );
  run.status.value = str.t('aia.reading_doc');
  task.report(detail: entry.name);
  bool quiet() => run.watched && TrackedTask.userWatching;
  final stamp = AiSummaryStore.stampOf(entry.path);
  String text;
  try {
    final doc = await FileService().load(entry.path);
    text = doc.plainText;
    if (text.trim().isEmpty && doc.kind == DocKind.image) {
      text = await OcrService.recognizeImageFile(entry.path);
    }
  } catch (e) {
    final msg = str.t('aia.read_failed', {'error': userErrorText(e)});
    await task.fail(msg, quiet: quiet());
    throw msg;
  }
  if (text.trim().length < 20) {
    final msg = str.t('aia.no_text');
    await task.fail(msg, quiet: quiet());
    throw msg;
  }
  run.status.value = str.t('ai.sum_working');
  final trimmed =
      text.length > _maxAiChars ? text.substring(0, _maxAiChars) : text;
  try {
    final summary = await gemini.chat(
      history: [
        ChatTurn(fromUser: true, text: str.t('aia.summary_prompt')),
      ],
      fileContext: trimmed,
    );
    final record = AiSummaryRecord(
      key: entry.path,
      title: entry.name,
      summary: summary,
      createdAtMs: DateTime.now().millisecondsSinceEpoch,
      sourceSize: stamp.size,
      sourceModifiedMs: stamp.modifiedMs,
      truncated: text.length > _maxAiChars,
    );
    // Kayıt işten ÖNCE yazılır: bildirime dokunan kullanıcı özeti bulsun.
    await AiSummaryStore.write(record);
    await task.complete(detail: entry.name, quiet: quiet());
    return record;
  } catch (e) {
    final msg = str.t('aia.summary_failed', {'error': userErrorText(e)});
    await task.fail(msg, quiet: quiet());
    throw msg;
  }
}

Future<void> _showSummarySheet(
    BuildContext context, FsEntry? entry, AiSummaryRecord record) async {
  final str = AppStrings.of(context);
  // Yerel sınıflandırma da ücretsiz geldiği için birlikte gösterilir.
  final guess = entry == null
      ? null
      : classifyDocumentText(record.summary, fileName: entry.name);
  final again = await showModalBottomSheet<bool>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (ctx) => _ResultSheet(
      entry: entry,
      name: record.title,
      title: str.t('aia.summary_title'),
      body: record.summary,
      guess: guess != null && guess.isConfident ? guess : null,
      note: record.truncated
          ? str.t('ai.sum_truncated', {'n': _maxAiChars})
          : null,
      canRegenerate: entry != null,
      markdown: true,
    ),
  );
  if (again == true && entry != null && context.mounted) {
    await showAiSummary(context, entry, regenerate: true);
  }
}

/// Görselden metni tanır (OCR), türünü tahmin eder ve klasörleme önerir.
Future<void> showImageInsight(BuildContext context, FsEntry entry) async {
  // Metinler await'ten ÖNCE (asenkron boşluktan sonra `context` yok).
  final str = AppStrings.of(context);
  final busy = showBusyDialog(context,
      builder: (_) => _Busy(str.t('aia.reading_image')));

  String text;
  try {
    text = await OcrService.recognizeImageFile(entry.path);
  } catch (e) {
    busy.close();
    if (context.mounted) _snack(context, str.t('aia.ocr_failed', {'error': userErrorText(e)}));
    return;
  }
  busy.close();
  if (!context.mounted) return;

  final guess = classifyDocumentText(text, fileName: entry.name);
  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (ctx) => _ResultSheet(
      entry: entry,
      name: entry.name,
      title: guess.isConfident
          ? str.t('aia.looks_like',
              {'type': str.t(guess.type.labelKey).toLowerCase()})
          : str.t('aia.image_text'),
      body: text.trim().isEmpty ? str.t('aia.image_no_text') : text.trim(),
      guess: guess.isConfident ? guess : null,
    ),
  );
}

/// Tahmine göre "Önemli Dosyalar/<klasör>" altına taşır.
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
    if (!dir.existsSync()) await dir.create(recursive: true);
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

class _Busy extends StatelessWidget {
  final String message;
  const _Busy(this.message);

  @override
  Widget build(BuildContext context) => AlertDialog(
        content: Row(
          children: [
            const SizedBox(
                width: 20, height: 20,
                child: CircularProgressIndicator(strokeWidth: 2)),
            const SizedBox(width: Gap.md),
            Expanded(child: Text(message)),
          ],
        ),
      );
}

/// Sonuç sayfası: metin + (varsa) sınıflandırma önerisi ve "klasöre taşı".
class _ResultSheet extends StatelessWidget {
  final FsEntry? entry;
  final String name;
  final String title;
  final String body;
  final DocGuess? guess;

  /// Kırpılma gibi açıklama satırı (varsa).
  final String? note;

  /// "Yeniden oluştur" düğmesi gösterilsin mi (sayfa `true` ile kapanır).
  final bool canRegenerate;

  /// Gövde Markdown mu (AI özeti) yoksa düz metin mi (OCR).
  final bool markdown;

  const _ResultSheet({
    required this.entry,
    required this.name,
    required this.title,
    required this.body,
    this.guess,
    this.note,
    this.canRegenerate = false,
    this.markdown = false,
  });

  @override
  Widget build(BuildContext context) {
    final g = guess;
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.85),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(title),
              subtitle:
                  Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: context.t('common.copy'),
                    icon: const Icon(AppIcons.clipCopy, size: 20),
                    onPressed: () async {
                      await Clipboard.setData(ClipboardData(text: body));
                      if (context.mounted) {
                        showSnack(context, context.t('tf.copied'));
                      }
                    },
                  ),
                  IconButton(
                    tooltip: context.t('common.share'),
                    icon: const Icon(AppIcons.share, size: 20),
                    onPressed: () => Share.share(body, subject: name),
                  ),
                  if (canRegenerate)
                    IconButton(
                      key: const ValueKey('ai-summary-again'),
                      tooltip: context.t('aia.regenerate'),
                      icon: const Icon(AppIcons.refresh, size: 20),
                      onPressed: () => Navigator.pop(context, true),
                    ),
                ],
              ),
            ),
            if (note != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: Gap.md),
                child: Text(note!,
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: Theme.of(context).colorScheme.error)),
              ),
            const Divider(height: 1),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(Gap.md),
                // AI özeti Markdown gelir (başlık, madde): ham "**" yerine
                // biçimli gösterilir; OCR metni düz kalır.
                child: markdown
                    ? SelectionArea(child: MarkdownText(body))
                    : SelectableText(body),
              ),
            ),
            if (g != null && entry != null) ...[
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.all(Gap.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Kanıt gösterilir: "neden fatura dedi?" sorusu
                    // cevapsız kalmasın.
                    Text(
                      context.t('aia.hints',
                          {'list': g.matched.take(5).join(', ')}),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: Gap.sm),
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: () async {
                              final ok = await fileIntoSuggestedFolder(
                                  context, entry!, g.type);
                              if (ok && context.mounted) {
                                Navigator.pop(context);
                              }
                            },
                            icon: const Icon(AppIcons.move),
                            label: Text(context.t('aia.target_folder',
                                {'folder': g.type.folder})),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
