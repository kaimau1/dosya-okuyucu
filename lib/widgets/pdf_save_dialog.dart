import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../core/l10n/app_strings.dart';
import '../services/fm/entry_opener.dart';
import '../services/fm/activity_log.dart';
import '../services/pdf_save.dart';

/// Kaydetme sonucunun çağırana söylediği şey.
class PdfSaveOutcome {
  /// Yazılan dosyanın yolu.
  final String path;

  /// Özgün dosyanın üzerine mi yazıldı?
  final bool overwritten;

  const PdfSaveOutcome({required this.path, required this.overwritten});
}

/// Düzenlenmiş PDF'i **sorarak** kaydeder: üzerine yaz / kopyasını kaydet /
/// klasör seçerek kaydet. Kaydettikten sonra nereye yazıldığını söyler ve
/// **"AÇ"** düğmesiyle dosyayı hemen açar.
///
/// *Niye tek yerde:* PDF araçları, imza, AI düzenleme ve yerinde metin
/// düzenleme aynı soruyu soruyor; ayrı ayrı yazılınca biri "aç" düğmesini
/// unutuyordu. 2026-07-26 kullanıcı bulgusu: "kopyasını kaydettiğinde nereye
/// gittiğini bulmak çok zor, hemen açabilmeliyim ve nereye kaydedileceğini
/// seçebilmeliyim."
///
/// Vazgeçilirse `null` döner.
Future<PdfSaveOutcome?> savePdfWithChoice(
  BuildContext context, {
  required String originalPath,
  required List<int> bytes,
  String? note,
}) async {
  final choice = await _askSaveChoice(context, originalPath, note);
  if (choice == null || !context.mounted) return null;

  String written;
  try {
    if (choice == _SaveChoice.chooseFolder) {
      final dir = await FilePicker.platform.getDirectoryPath();
      if (dir == null || !context.mounted) return null;
      written = await _writeInto(dir, originalPath, bytes);
    } else {
      written = await PdfSave.write(
        originalPath,
        bytes,
        choice == _SaveChoice.overwrite
            ? PdfSaveMode.overwrite
            : PdfSaveMode.copy,
      );
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Kaydedilemedi: $e')));
    }
    return null;
  }

  // "Yaptıklarım" defterine yazılır: kullanıcı düzenlediği PDF'i sonradan
  // klasör klasör aramasın (istek 2026-08-07).
  unawaited(ActivityLog.add(ActivityKind.pdfEdit, written,
      detail: note ?? ''));
  if (context.mounted) {
    _announce(context, written, choice == _SaveChoice.overwrite);
  }
  return PdfSaveOutcome(
    path: written,
    overwritten: choice == _SaveChoice.overwrite,
  );
}

/// Seçilen klasöre benzersiz adla yazar.
Future<String> _writeInto(
    String dir, String originalPath, List<int> bytes) async {
  final stem = p.basenameWithoutExtension(originalPath);
  var target = p.join(dir, '$stem.pdf');
  var n = 2;
  while (File(target).existsSync()) {
    target = p.join(dir, '$stem ($n).pdf');
    n++;
  }
  await File(target).writeAsBytes(bytes, flush: true);
  return target;
}

/// Nereye kaydedildiğini söyler; kopyaysa klasörü de yazar ve "AÇ" sunar.
void _announce(BuildContext context, String written, bool overwritten) {
  final messenger = ScaffoldMessenger.of(context);
  messenger.showSnackBar(SnackBar(
    duration: const Duration(seconds: 8),
    content: Text(
      overwritten
          ? context.t('ps.saved_as', {'name': p.basename(written)})
          : '${p.basename(written)}\n${p.dirname(written)}',
    ),
    action: SnackBarAction(
      label: context.t('ps.open'),
      onPressed: () {
        if (context.mounted) EntryOpener.open(context, written);
      },
    ),
  ));
}

enum _SaveChoice { overwrite, copy, chooseFolder }

Future<_SaveChoice?> _askSaveChoice(
    BuildContext context, String path, String? note) {
  final name = p.basename(path);
  return showDialog<_SaveChoice>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(ctx.t('ps.title')),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (note != null) ...[
            Text(note),
            const SizedBox(height: 12),
          ],
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.save_outlined),
            title: Text(ctx.t('ps.overwrite')),
            subtitle: Text(ctx.t('ps.overwrite_sub', {'name': name})),
            onTap: () => Navigator.pop(ctx, _SaveChoice.overwrite),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.copy_all_outlined),
            title: Text(ctx.t('ps.copy')),
            subtitle: Text(ctx.t('ps.copy_sub')),
            onTap: () => Navigator.pop(ctx, _SaveChoice.copy),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.folder_open_outlined),
            title: Text(ctx.t('ps.pick_folder')),
            subtitle: Text(ctx.t('ps.pick_folder_sub')),
            onTap: () => Navigator.pop(ctx, _SaveChoice.chooseFolder),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: Text(ctx.t('common.cancel')),
        ),
      ],
    ),
  );
}

