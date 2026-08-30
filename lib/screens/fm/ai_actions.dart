import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/app_state.dart';
import '../../core/theme.dart';
import '../../models/document.dart';
import '../../models/fs_entry.dart';
import '../../services/file_service.dart';
import '../../services/fm/doc_classifier.dart';
import '../../services/fm/file_ops.dart';
import '../../services/fm/fm_env.dart';
import '../../services/gemini_service.dart';
import '../../services/ocr_service.dart';
import 'important_screen.dart';
import '../../core/snack.dart';

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
Future<void> showAiSummary(BuildContext context, FsEntry entry) async {
  final appState = context.read<AppState>();
  // Metinler await'ten ÖNCE (asenkron boşluktan sonra `context` yok).
  final str = AppStrings.of(context);
  if (!appState.hasApiKey) {
    _snack(context, str.t('aia.need_key'));
    return;
  }

  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => _Busy(str.t('aia.reading_doc')),
  );

  String text;
  try {
    final doc = await FileService().load(entry.path);
    text = doc.plainText;
    if (text.trim().isEmpty && doc.kind == DocKind.image) {
      text = await OcrService.recognizeImageFile(entry.path);
    }
  } catch (e) {
    if (context.mounted) Navigator.pop(context);
    if (context.mounted) _snack(context, str.t('aia.read_failed', {'error': e}));
    return;
  }

  if (text.trim().length < 20) {
    if (context.mounted) Navigator.pop(context);
    if (context.mounted) {
      _snack(context, str.t('aia.no_text'));
    }
    return;
  }

  final trimmed =
      text.length > _maxAiChars ? text.substring(0, _maxAiChars) : text;
  String summary;
  try {
    final gemini =
        appState.gemini;
    summary = await gemini.chat(
      history: [
        ChatTurn(
          fromUser: true,
          text: str.t('aia.summary_prompt'),
        ),
      ],
      fileContext: trimmed,
    );
  } catch (e) {
    if (context.mounted) Navigator.pop(context);
    if (context.mounted) {
      _snack(context, str.t('aia.summary_failed', {'error': e}));
    }
    return;
  }

  if (!context.mounted) return;
  Navigator.pop(context); // yükleniyor penceresi
  if (!context.mounted) return;

  // Yerel sınıflandırma da ücretsiz geldiği için birlikte gösterilir.
  final guess = classifyDocumentText(text, fileName: entry.name);
  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (ctx) => _ResultSheet(
      entry: entry,
      title: str.t('aia.summary_title'),
      body: summary,
      guess: guess.isConfident ? guess : null,
    ),
  );
}

/// Görselden metni tanır (OCR), türünü tahmin eder ve klasörleme önerir.
Future<void> showImageInsight(BuildContext context, FsEntry entry) async {
  // Metinler await'ten ÖNCE (asenkron boşluktan sonra `context` yok).
  final str = AppStrings.of(context);
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => _Busy(str.t('aia.reading_image')),
  );

  String text;
  try {
    text = await OcrService.recognizeImageFile(entry.path);
  } catch (e) {
    if (context.mounted) Navigator.pop(context);
    if (context.mounted) _snack(context, str.t('aia.ocr_failed', {'error': e}));
    return;
  }
  if (!context.mounted) return;
  Navigator.pop(context);
  if (!context.mounted) return;

  final guess = classifyDocumentText(text, fileName: entry.name);
  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (ctx) => _ResultSheet(
      entry: entry,
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
    if (context.mounted) _snack(context, str.t('aia.move_failed', {'error': e}));
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
  final FsEntry entry;
  final String title;
  final String body;
  final DocGuess? guess;

  const _ResultSheet({
    required this.entry,
    required this.title,
    required this.body,
    this.guess,
  });

  @override
  Widget build(BuildContext context) {
    final g = guess;
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.85),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(title),
              subtitle:
                  Text(entry.name, maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
            const Divider(height: 1),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(Gap.md),
                child: SelectableText(body),
              ),
            ),
            if (g != null) ...[
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
                                  context, entry, g.type);
                              if (ok && context.mounted) {
                                Navigator.pop(context);
                              }
                            },
                            icon: const Icon(Icons.drive_file_move_outline),
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
