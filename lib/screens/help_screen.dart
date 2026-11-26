import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/app_icons.dart';
import '../core/edition.dart';
import '../core/l10n/app_strings.dart';
import '../core/safe_insets.dart';
import '../core/snack.dart';
import '../services/feature_help.dart';
import 'settings/feedback_screen.dart';

/// **Yardım** (2026-11-14): tüm özellikler grup grup, her biri "nerede /
/// nasıl" açılır kartı. Üstte arama; en altta "Özellik iste".
class HelpScreen extends StatefulWidget {
  final String initialQuery;
  final String? openId;

  const HelpScreen({super.key, this.initialQuery = '', this.openId});

  @override
  State<HelpScreen> createState() => _HelpScreenState();
}

class _HelpScreenState extends State<HelpScreen> {
  late final _controller = TextEditingController(text: widget.initialQuery);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final q = _controller.text.trim();
    final hits = q.length >= 2 ? FeatureHelpIndex.search(q) : null;
    final theme = Theme.of(context);
    final children = <Widget>[];
    if (hits != null) {
      if (hits.isEmpty) {
        children.add(Padding(
          padding: const EdgeInsets.all(16),
          child: Text(context.t('help.none', {'q': q}),
              style: theme.textTheme.bodyLarge),
        ));
      }
      children.addAll(hits.map((f) => FeatureHelpTile(f, initiallyExpanded: true)));
    } else {
      for (final g in FeatureHelpIndex.groups) {
        children.add(Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
          child: Text(g,
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w800)),
        ));
        for (final f in FeatureHelpIndex.all.where((f) => f.group == g)) {
          children.add(FeatureHelpTile(f,
              initiallyExpanded: f.id == widget.openId));
        }
      }
    }
    children.add(Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: FilledButton.tonalIcon(
        onPressed: () => Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => Edition.current.isPlay
                ? const FeedbackScreen(initialKind: FeedbackKind.idea)
                : FeatureRequestScreen(initial: q))),
        icon: const Icon(AppIcons.send),
        label: Text(context.t('help.request')),
      ),
    ));
    return Scaffold(
      appBar: AppBar(title: Text(context.t('help.ftitle'))),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: TextField(
              controller: _controller,
              decoration: InputDecoration(
                prefixIcon: const Icon(AppIcons.search),
                hintText: context.t('help.hint'),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
          Expanded(
            child: ListView(
              padding:
                  withNavInset(context, const EdgeInsets.only(bottom: 24)),
              children: children,
            ),
          ),
        ],
      ),
    );
  }
}

/// Tek özelliğin açılır kartı (arama ekranında da kullanılır).
class FeatureHelpTile extends StatelessWidget {
  final FeatureHelp help;
  final bool initiallyExpanded;

  const FeatureHelpTile(this.help, {super.key, this.initiallyExpanded = false});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return ExpansionTile(
      key: PageStorageKey('help-${help.id}'),
      initiallyExpanded: initiallyExpanded,
      leading: Icon(AppIcons.help, color: scheme.primary),
      title: Text(help.name,
          style: theme.textTheme.titleSmall
              ?.copyWith(fontWeight: FontWeight.w700)),
      subtitle: Text(help.where,
          maxLines: initiallyExpanded ? 3 : 1,
          overflow: TextOverflow.ellipsis),
      childrenPadding: const EdgeInsetsDirectional.fromSTEB(56, 0, 16, 12),
      expandedCrossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(context.t('help.where'),
            style: theme.textTheme.labelMedium
                ?.copyWith(color: scheme.primary, fontWeight: FontWeight.w700)),
        const SizedBox(height: 2),
        Text(help.where),
        const SizedBox(height: 8),
        Text(context.t('help.how'),
            style: theme.textTheme.labelMedium
                ?.copyWith(color: scheme.primary, fontWeight: FontWeight.w700)),
        const SizedBox(height: 2),
        for (var i = 0; i < help.how.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: Text('${i + 1}. ${help.how[i]}'),
          ),
      ],
    );
  }
}

/// Arama ekranında sorguya uyan özellikler (en çok [max]); eşleşme yoksa
/// hiçbir şey çizmez.
class FeatureHelpMatches extends StatelessWidget {
  final String query;
  final int max;

  const FeatureHelpMatches({super.key, required this.query, this.max = 2});

  @override
  Widget build(BuildContext context) {
    final q = query.trim();
    if (q.length < 2) return const SizedBox.shrink();
    final hits = FeatureHelpIndex.search(q, limit: 20);
    if (hits.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.secondaryContainer.withValues(alpha: .45),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final f in hits.take(max))
            ListTile(
              dense: true,
              leading: Icon(AppIcons.help, color: theme.colorScheme.primary),
              title: Text(f.name,
                  style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text(f.where,
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              onTap: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => HelpScreen(initialQuery: q, openId: f.id))),
            ),
          if (hits.length > max)
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: TextButton(
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => HelpScreen(initialQuery: q))),
                child: Text(context
                    .t('help.more', {'n': '${hits.length - max}'})),
              ),
            ),
          const Divider(height: 1),
        ],
      ),
    );
  }
}

/// **Özellik iste**: istek yazılır, cihazda saklanır ve geliştiriciye
/// GitHub "yeni konu" sayfası (hazır doldurulmuş) açılarak iletilir.
class FeatureRequestScreen extends StatefulWidget {
  final String initial;

  const FeatureRequestScreen({super.key, this.initial = ''});

  @override
  State<FeatureRequestScreen> createState() => _FeatureRequestScreenState();
}

class _FeatureRequestScreenState extends State<FeatureRequestScreen> {
  static const _key = 'feature_requests_v1';
  late final _controller = TextEditingController(text: widget.initial);
  List<({String text, int at})> _list = const [];

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getStringList(_key) ?? const [];
      final out = <({String text, int at})>[];
      for (final r in raw) {
        final m = jsonDecode(r);
        if (m is Map && m['t'] is String && m['a'] is int) {
          out.add((text: m['t'] as String, at: m['a'] as int));
        }
      }
      if (mounted) setState(() => _list = out);
    } catch (_) {
      // Bilinçli: geçmiş istek listesi yalnız gösterim; okunamazsa boş kalır.
    }
  }

  Future<void> _save(String text) async {
    final next = [(text: text, at: DateTime.now().millisecondsSinceEpoch), ..._list];
    setState(() => _list = next);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_key, [
        for (final r in next.take(100)) jsonEncode({'t': r.text, 'a': r.at}),
      ]);
    } catch (_) {
      // Bilinçli: kaydedilemezse istek yine tarayıcıda gönderilir.
    }
  }

  Future<void> _send() async {
    if (Edition.current.isPlay) {
      await Navigator.of(context).push(MaterialPageRoute<void>(
          builder: (_) => const FeedbackScreen(initialKind: FeedbackKind.idea)));
      return;
    }
    final text = _controller.text.trim();
    if (text.length < 3) return;
    await _save(text);
    final title = text.split('\n').first;
    final uri = Uri.https('github.com', '/kaimau1/dosya-okuyucu/issues/new', {
      'title': 'İstek: ${title.length > 80 ? '${title.substring(0, 80)}…' : title}',
      'body': text,
      'labels': 'istek',
    });
    var ok = false;
    try {
      ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      // Bilinçli: tarayıcı yoksa ok=false → kullanıcıya "cihaza kaydedildi".
    }
    if (!mounted) return;
    _controller.clear();
    showSnack(context, context.t(ok ? 'help.req_sent' : 'help.req_saved'));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(context.t('help.request'))),
      body: ListView(
        padding: withNavInset(context, const EdgeInsets.all(16)),
        children: [
          Text(context.t('help.req_hint'), style: theme.textTheme.bodyMedium),
          const SizedBox(height: 12),
          TextField(
            controller: _controller,
            minLines: 4,
            maxLines: 10,
            decoration: InputDecoration(
              hintText: context.t('help.req_field'),
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _send,
            icon: const Icon(AppIcons.send),
            label: Text(context.t('help.req_send')),
          ),
          if (_list.isNotEmpty) ...[
            const SizedBox(height: 24),
            Text(context.t('help.req_mine'),
                style: theme.textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.w800)),
            for (final r in _list)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(AppIcons.send),
                title: Text(r.text, maxLines: 3, overflow: TextOverflow.ellipsis),
                subtitle: Text(MaterialLocalizations.of(context).formatShortDate(
                    DateTime.fromMillisecondsSinceEpoch(r.at))),
              ),
          ],
        ],
      ),
    );
  }
}
