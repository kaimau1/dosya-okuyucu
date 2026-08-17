import 'package:flutter/material.dart';

import '../core/l10n/app_strings.dart';
import '../models/document.dart';
import '../services/blank_docs.dart';
import '../services/fm/entry_opener.dart';
import 'file_type_icon.dart';

/// **Yeni belge oluştur** — boş Word / Excel / metin dosyası kurup açar.
///
/// *Niye ayrı bir dosya:* bu akış 2026-08-17'ye kadar "Son belgeler"
/// sekmesinin (`RecentDocsScreen`) içindeydi. O sekme kullanıcı isteğiyle alt
/// gezinme çubuğundan kaldırıldı (*"son belgeleri kaldır, yerine yeni
/// dosyaları koy"*) — ama belge OLUŞTURMA istenmeyen bir kayıp olurdu, kimse
/// onu kaldırmayı istemedi. Akış buraya taşındı ve panonun araç satırından
/// çağrılıyor.
Future<void> showNewDocumentSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(ctx.t('home.new_document_title'),
                  style: Theme.of(ctx).textTheme.titleMedium),
            ),
          ),
          _tile(ctx, DocKind.word, ctx.t('home.new_word'), '.docx', 'docx'),
          _tile(ctx, DocKind.spreadsheet, ctx.t('home.new_excel'), '.xlsx',
              'xlsx'),
          _tile(ctx, DocKind.text, ctx.t('home.new_text'), '.txt', 'txt'),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
}

Widget _tile(BuildContext ctx, DocKind kind, String title, String sub,
    String type) {
  return ListTile(
    leading: FileTypeIcon(kind: kind),
    title: Text(title),
    subtitle: Text(sub),
    onTap: () {
      Navigator.pop(ctx);
      _createAndOpen(ctx, type);
    },
  );
}

Future<void> _createAndOpen(BuildContext context, String type) async {
  // Çeviri tablosu await'ten ÖNCE alınır: `context` asenkron boşluktan sonra
  // kullanılamaz (sayfa bu arada kapanmış olabilir).
  final s = AppStrings.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final navigator = Navigator.of(context);
  try {
    final path = await BlankDocs.create(type);
    if (!navigator.mounted) return;
    await EntryOpener.open(navigator.context, path);
  } catch (e) {
    messenger.showSnackBar(
      SnackBar(content: Text(s.t('home.create_error', {'error': e}))),
    );
  }
}
