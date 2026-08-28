import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

import '../../core/l10n/app_language.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/policy_doc.dart';
import '../../core/theme.dart';

/// **Gizlilik politikası — uygulamanın içinde, çevrimdışı.**
///
/// Metin `assets/privacy/<dil>.md`ten okunur; depodaki kopya ile birebir aynı
/// dosyadır (bkz. `core/policy_doc.dart`). Bir tarayıcıya yönlendirmek
/// yerine burada gösterilmesinin nedeni basit: gizlilik politikasını okumak
/// için kullanıcının internete çıkmak zorunda kalması çelişki olurdu — ve
/// uygulama zaten çevrimdışı çalışacak biçimde tasarlandı.
class PrivacyPolicyScreen extends StatefulWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  State<PrivacyPolicyScreen> createState() => _PrivacyPolicyScreenState();
}

class _PrivacyPolicyScreenState extends State<PrivacyPolicyScreen> {
  List<PolicyBlock>? _blocks;
  AppLanguage? _loadedFor;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Dil ekran açıkken değişebilir (Ayarlar > Dil); o zaman metin de değişmeli.
    final language = context.language;
    if (_loadedFor == language) return;
    _loadedFor = language;
    _load(language);
  }

  Future<void> _load(AppLanguage language) async {
    // `system` çözümlenmiş dille gelir; yine de bilinmeyen bir kod gelirse
    // Türkçe'ye düşülür — boş ekran göstermektense ana dili göstermek doğru.
    final code = switch (language) {
      AppLanguage.en => 'en',
      AppLanguage.ar => 'ar',
      _ => 'tr',
    };
    try {
      final text = await rootBundle.loadString('assets/privacy/$code.md');
      if (mounted) setState(() => _blocks = PolicyDoc.parse(text));
    } catch (_) {
      if (mounted) setState(() => _blocks = const []);
    }
  }

  @override
  Widget build(BuildContext context) {
    final blocks = _blocks;
    return Scaffold(
      appBar: AppBar(title: Text(context.t('settings.privacy_policy'))),
      body: blocks == null
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(Gap.md, Gap.sm, Gap.md, Gap.xl),
              itemCount: blocks.length,
              itemBuilder: (context, i) => _PolicyBlockView(blocks[i]),
            ),
    );
  }
}

class _PolicyBlockView extends StatelessWidget {
  final PolicyBlock block;
  const _PolicyBlockView(this.block);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    switch (block.kind) {
      case PolicyBlockKind.heading:
        final style = block.level <= 1
            ? theme.textTheme.titleLarge
            : theme.textTheme.titleMedium;
        return Padding(
          padding: EdgeInsets.only(
              top: block.level <= 1 ? Gap.md : Gap.lg, bottom: Gap.sm),
          child: Text(block.text,
              style: style?.copyWith(fontWeight: FontWeight.w700)),
        );
      case PolicyBlockKind.paragraph:
        return Padding(
          padding: const EdgeInsets.only(bottom: Gap.sm),
          child: Text(block.text, style: theme.textTheme.bodyMedium),
        );
      case PolicyBlockKind.bullet:
        return Padding(
          padding: const EdgeInsets.only(bottom: Gap.xs),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('•  ', style: theme.textTheme.bodyMedium),
              Expanded(
                  child: Text(block.text, style: theme.textTheme.bodyMedium)),
            ],
          ),
        );
      case PolicyBlockKind.tableRow:
        // Tablo telefonda YAN YANA çizilmez: ikinci sütun ("niçin", "ne
        // gider") uzun cümleler ve dar ekranda okunmaz hâle gelirdi. Bunun
        // yerine her satır bir kart: başlık koyu, açıklama altında.
        final title = block.cells.isNotEmpty ? block.cells.first : '';
        final rest = block.cells.skip(1).where((c) => c.isNotEmpty).toList();
        return Padding(
          padding: const EdgeInsets.only(bottom: Gap.sm),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w700)),
              for (final cell in rest)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(cell, style: theme.textTheme.bodySmall),
                ),
            ],
          ),
        );
      case PolicyBlockKind.divider:
        return const Padding(
          padding: EdgeInsets.symmetric(vertical: Gap.sm),
          child: Divider(height: 1),
        );
    }
  }
}
