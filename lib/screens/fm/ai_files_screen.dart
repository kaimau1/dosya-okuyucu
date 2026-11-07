/// **Kova ekranı** — rapordaki bir sayıya dokununca açılan liste.
///
/// Kullanıcı (2026-08-11): *"rapor menüsünde etkileşim yok, silinebilir
/// adayları göremiyorum."* Rapor artık her satırı buraya bağlıyor: kovanın
/// dosyaları, toplam boyutu ve o kovaya uygun toplu işlem burada.
library;

import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../services/fm/ai_buckets.dart';
import '../../services/fm/ai_index.dart';
import '../../services/fm/fs_scan.dart';
import '../../widgets/fm/ai_file_list.dart';

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
  // Liste HER indeks değişiminde yeniden kurulur (2026-11-07): eskiden bir
  // kez kuruluyordu; başka yerde silinen/taşınan dosya burada kalıyordu.
  List<AiRecord> _load() =>
      AiBuckets.of(widget.bucket, docType: widget.docType);

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: AiIndex.revision,
      builder: (context, _, __) {
        final records = _load();
        final bytes = AiBuckets.totalBytes(records);
        final suggestions = widget.bucket == AiBucket.suggestions;
        return Scaffold(
          appBar: AppBar(
            title: Text(widget.title,
                maxLines: 1, overflow: TextOverflow.ellipsis),
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(22),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(Gap.md, 0, Gap.md, Gap.xs),
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Text(
                    '${records.length} · ${FsPaths.humanSize(bytes)}',
                    style: context.type.small
                        .copyWith(color: Paper.faint(context)),
                  ),
                ),
              ),
            ),
          ),
          body: AiFileList(
            records: records,
            showSuggestion: suggestions,
            onChanged: () => setState(() {}),
            onApply: suggestions
                ? (selected) async {
                    await confirmApplyAiSuggestions(context, selected);
                  }
                : null,
          ),
        );
      },
    );
  }
}
