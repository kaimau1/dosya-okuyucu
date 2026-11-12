import 'package:flutter/material.dart';

import '../core/l10n/app_strings.dart';
import '../models/document.dart';
import '../services/blank_docs.dart';
import '../services/docx/pro/docx_templates.dart';
import '../core/app_icons.dart';
import '../core/edition.dart';
import 'pro_gate.dart';
import '../core/l10n/app_language.dart';
import 'app_dialog.dart';
import '../services/fm/entry_opener.dart';
import 'file_type_icon.dart';
import '../core/snack.dart';
import '../core/user_error.dart';

/// **Yeni belge oluştur** — boş Word / Excel / metin dosyası kurup açar.
///
/// *Niye ayrı bir dosya:* bu akış 2026-08-17'ye kadar "Son belgeler"
/// sekmesinin (`RecentDocsScreen`) içindeydi. O sekme kullanıcı isteğiyle alt
/// gezinme çubuğundan kaldırıldı (*"son belgeleri kaldır, yerine yeni
/// dosyaları koy"*) — ama belge OLUŞTURMA istenmeyen bir kayıp olurdu, kimse
/// onu kaldırmayı istemedi. Akış buraya taşındı ve panonun araç satırından
/// çağrılıyor.
Future<void> showNewDocumentSheet(BuildContext context) {
  if (!Edition.current.has(Feature.officeEdit)) {
    return showProSheet(context, Feature.officeEdit); // S2: Lite
  }
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
              alignment: AlignmentDirectional.centerStart,
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
      if (type == 'docx') {
        // Faz 37 madde 4: Word → şablon galerisi (boş belge ilk sırada).
        final nav = Navigator.of(ctx);
        nav.pop();
        showWordTemplateSheet(nav.context);
        return;
      }
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
    showSnackOn(messenger, s.t('home.create_error', {'error': userErrorText(e)}));
  }
}

/// Word şablon galerisi (Faz 37 madde 4): Boş belge + CV, mektup, rapor,
/// fatura, tutanak. Şablon içeriği arayüz diliyle (Türkçe değilse İngilizce).
Future<void> showWordTemplateSheet(BuildContext context) async {
  final id = await showAppSheet<String>(
    context,
    title: context.t('wt.title'),
    builder: (ctx) => Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final (id, icon) in const [
          ('blank', AppIcons.newWord),
          ('cv', AppIcons.badge),
          ('letter', AppIcons.editNote),
          ('report', AppIcons.assignment),
          ('invoice', AppIcons.receiptLong),
          ('minutes', AppIcons.eventNote),
        ])
          ListTile(
            key: ValueKey('word-template-$id'),
            leading: Icon(icon),
            title: Text(ctx.t('wt.$id')),
            subtitle: Text(ctx.t('wt.${id}_hint')),
            onTap: () => Navigator.pop(ctx, id),
          ),
      ],
    ),
  );
  if (id == null || !context.mounted) return;
  if (id == 'blank') {
    await _createAndOpen(context, 'docx');
    return;
  }
  final s = AppStrings.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final navigator = Navigator.of(context);
  try {
    final bytes = DocxTemplates.build(id,
        turkish: s.language != AppLanguage.en && s.language != AppLanguage.ar);
    final path = await BlankDocs.createFrom(s.t('wt.$id'), 'docx', bytes);
    if (!navigator.mounted) return;
    await EntryOpener.open(navigator.context, path);
  } catch (e) {
    showSnackOn(messenger, s.t('home.create_error', {'error': userErrorText(e)}));
  }
}
