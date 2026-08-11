/// **Kova ekranı** — rapordaki bir sayıya dokununca açılan liste.
///
/// Kullanıcı (2026-08-11): *"rapor menüsünde etkileşim yok, silinebilir
/// adayları göremiyorum."* Rapor artık her satırı buraya bağlıyor: kovanın
/// dosyaları, toplam boyutu ve o kovaya uygun toplu işlem burada.
library;

import 'package:flutter/material.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/theme.dart';
import '../../services/fm/ai_apply.dart';
import '../../services/fm/ai_buckets.dart';
import '../../services/fm/ai_index.dart';
import '../../services/fm/fm_env.dart';
import '../../services/fm/fs_scan.dart';
import '../../widgets/fm/ai_file_list.dart';
import 'important_screen.dart';

class AiFilesScreen extends StatefulWidget {
  final AiBucket bucket;

  /// [AiBucket.docType] için tür adı.
  final String? docType;

  /// Ekran başlığı (kovanın adı).
  final String title;

  const AiFilesScreen({
    super.key,
    required this.bucket,
    required this.title,
    this.docType,
  });

  @override
  State<AiFilesScreen> createState() => _AiFilesScreenState();
}

class _AiFilesScreenState extends State<AiFilesScreen> {
  late List<AiRecord> _records = _load();

  List<AiRecord> _load() =>
      AiBuckets.of(widget.bucket, docType: widget.docType);

  void _refresh() => setState(() => _records = _load());

  @override
  Widget build(BuildContext context) {
    final bytes = AiBuckets.totalBytes(_records);
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title, maxLines: 1, overflow: TextOverflow.ellipsis),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(22),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(Gap.md, 0, Gap.md, Gap.xs),
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: Text(
                '${_records.length} · ${FsPaths.humanSize(bytes)}',
                style:
                    TextStyle(fontSize: 12, color: Paper.faint(context)),
              ),
            ),
          ),
        ),
      ),
      body: ValueListenableBuilder<int>(
        valueListenable: AiIndex.revision,
        builder: (context, _, __) => AiFileList(
          records: _records,
          showSuggestion: widget.bucket == AiBucket.suggestions,
          onChanged: _refresh,
          onApply: widget.bucket == AiBucket.suggestions
              ? (selected) async {
                  AiApply.start(
                    selected,
                    importantRoot:
                        ImportantScreen.pathIn(FmEnv.primaryRoot),
                  );
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(context
                        .t('aiap.started', {'n': selected.length})),
                  ));
                }
              : null,
        ),
      ),
    );
  }
}
