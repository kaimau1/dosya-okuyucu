import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_icons.dart';
import '../../core/app_state.dart';
import '../../core/edition.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/theme.dart';
import '../../services/fm/smart_scope_pick.dart';
import '../../services/fm/smart_sort.dart';
import '../../widgets/pro_gate.dart';
import '../../widgets/section_header.dart';

/// **"Neyi düzenleyelim?"** — Akıllı düzen kapsamı (Aşama 1, 2026-11-22).
///
/// Türler (Belgeler · Ekran görüntüleri · Fotoğraflar · Ses · Video ·
/// Uygulama/arşiv) ve yerler (Kamera · WhatsApp · Telegram · İndirilenler ·
/// Diğer) aç/kapa; her birinin yanında dosya sayısı. Üstte canlı özet:
/// seçili / düzenlenmiş / kalan. Sayım cihazda, hiçbir istek atılmaz.
/// Kredi satırı yalnız TAHMİN (satın alma Aşama 2, PLAN §3 K15a).
class SmartScopeScreen extends StatefulWidget {
  const SmartScopeScreen({super.key});

  @override
  State<SmartScopeScreen> createState() => _SmartScopeScreenState();
}

class _SmartScopeScreenState extends State<SmartScopeScreen> {
  SmartScopeCounts? _counts;

  @override
  void initState() {
    super.initState();
    if (!Edition.current.has(Feature.smartFolders)) return;
    SmartScopePick.revision.addListener(_changed);
    SmartSort.revision.addListener(_changed);
    unawaited(_load());
  }

  @override
  void dispose() {
    if (Edition.current.has(Feature.smartFolders)) {
      SmartScopePick.revision.removeListener(_changed);
      SmartSort.revision.removeListener(_changed);
    }
    super.dispose();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  Future<void> _load() async {
    final scope = context.read<AppState>().aiScopeRules;
    await SmartSort.readSettings();
    final c = await SmartScopePick.count(scope);
    if (mounted) setState(() => _counts = c);
  }

  static IconData _groupIcon(SmartGroup g) => switch (g) {
        SmartGroup.docs => AppIcons.newWord,
        SmartGroup.screenshots => AppIcons.screenshot,
        SmartGroup.images => AppIcons.photos,
        SmartGroup.audio => AppIcons.audiotrack,
        SmartGroup.videos => AppIcons.videoLibrary,
        SmartGroup.packages => AppIcons.pdfArchive,
      };

  static IconData _sourceIcon(SmartSource s) => switch (s) {
        SmartSource.camera => AppIcons.photoCamera,
        SmartSource.whatsapp => AppIcons.chat,
        SmartSource.telegram => AppIcons.send,
        SmartSource.download => AppIcons.download,
        SmartSource.other => AppIcons.folder,
      };

  static String _sourceLabel(BuildContext context, SmartSource s) =>
      switch (s) {
        SmartSource.camera => context.t('enum.bucket_camera'),
        SmartSource.whatsapp => context.t('enum.bucket_whatsapp'),
        SmartSource.telegram => context.t('enum.bucket_telegram'),
        SmartSource.download => context.t('enum.bucket_download'),
        SmartSource.other => context.t('scp.src_other'),
      };

  @override
  Widget build(BuildContext context) {
    if (!Edition.current.has(Feature.smartFolders)) {
      return ProLockedView(
        feature: Feature.smartFolders,
        title: context.t('scp.title'),
      );
    }
    final c = _counts;
    final theme = Theme.of(context);
    final sel = c?.sum(
        where: (g, s) =>
            SmartScopePick.groupOn(g) && SmartScopePick.sourceOn(s));
    String count(int n) => c == null ? '…' : '$n';
    return Scaffold(
      appBar: AppBar(title: Text(context.t('scp.title'))),
      body: ListView(
        padding: const EdgeInsets.only(bottom: Gap.lg),
        children: [
          Padding(
            padding: const EdgeInsets.all(Gap.md),
            child: Card(
              key: const ValueKey('scp-summary'),
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.all(Gap.md),
                child: sel == null
                    ? const LinearProgressIndicator()
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            context.t('scp.selected', {'n': sel.total}),
                            style: theme.textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: Gap.xs),
                          Text(context.t('scp.done_left', {
                            'd': sel.total - sel.remaining,
                            'r': sel.remaining,
                          })),
                          const SizedBox(height: Gap.sm),
                          Text(
                            _creditLine(context, sel.remaining),
                            key: const ValueKey('scp-credit'),
                            style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant),
                          ),
                        ],
                      ),
              ),
            ),
          ),
          SectionHeader(context.t('scp.types')),
          for (final g in SmartScopePick.priority)
            SwitchListTile(
              key: ValueKey('scp-g-${g.name}'),
              secondary: Icon(_groupIcon(g)),
              title: Text(context.t('scp.g_${g.name}')),
              subtitle: Text(context.t(
                  'scp.files', {'n': count(c?.groupTotal(g) ?? 0)})),
              value: SmartScopePick.groupOn(g),
              onChanged: (v) => unawaited(SmartScopePick.setGroup(g, v)),
            ),
          SectionHeader(context.t('scp.sources')),
          for (final s in SmartSource.values)
            SwitchListTile(
              key: ValueKey('scp-s-${s.name}'),
              secondary: Icon(_sourceIcon(s)),
              title: Text(_sourceLabel(context, s)),
              subtitle: Text(context.t(
                  'scp.files', {'n': count(c?.sourceTotal(s) ?? 0)})),
              value: SmartScopePick.sourceOn(s),
              onChanged: (v) => unawaited(SmartScopePick.setSource(s, v)),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(Gap.md, Gap.sm, Gap.md, 0),
            child: Text(context.t('scp.note'),
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          ),
        ],
      ),
    );
  }

  /// Kendi anahtarıyla sınırsız; kredi yalnız tahmin (yakında).
  String _creditLine(BuildContext context, int remaining) {
    final pack = SmartCreditDraft.packFor(remaining);
    final own = context.t('scp.own_key');
    final credit = pack == null
        ? context.t('scp.credit_free',
            {'free': SmartCreditDraft.freeFiles})
        : context.t('scp.credit_pack', {
            'free': SmartCreditDraft.freeFiles,
            'n': pack.$1,
            'tl': pack.$2,
          });
    return '$own\n$credit';
  }
}
