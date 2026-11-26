import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/app_icons.dart';
import '../../core/app_version.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/snack.dart';
import '../../core/support_contact.dart';
import '../../core/theme.dart';
import '../../services/crash_log.dart';
import '../../services/log_scrub.dart';
import '../../widgets/app_dialog.dart';

/// Bildirim türü (konu satırının öneki).
enum FeedbackKind { bug, idea, other }

/// **Hata / istek bildir** (2026-11-22, kullanıcı: "kişiler bug'ları veya
/// isteklerini buradan bildirebilsinler").
///
/// Sunucu yok: metin [kSupportEmail] doluysa e-posta uygulamasıyla, boşsa
/// paylaşma menüsüyle gider. Gönderilmeden önce TAM metin gösterilir.
/// Güvenlik/KVKK: dosya adı, dosya içeriği, API anahtarı gitmez — yazılan
/// metin ve hata kayıtları [LogScrub] ile anahtar/belirteç kalıplarından
/// arındırılır; cihaz bilgisi yalnız sürüm + Android sürümü.
class FeedbackScreen extends StatefulWidget {
  final FeedbackKind initialKind;
  const FeedbackScreen({super.key, this.initialKind = FeedbackKind.bug});

  /// Gönderilecek metin (saf, test edilir).
  static String compose({
    required AppStrings s,
    required FeedbackKind kind,
    required String message,
    required String deviceLine,
    String crashText = '',
  }) {
    final b = StringBuffer()
      ..writeln(s.t('fb.kind_${kind.name}'))
      ..writeln()
      ..writeln(LogScrub.scrub(message.trim()))
      ..writeln()
      ..writeln('— Dosya Okuyucu $appVersionFull · $deviceLine');
    if (crashText.trim().isNotEmpty) {
      b
        ..writeln()
        ..writeln(LogScrub.scrub(crashText.trim()));
    }
    return b.toString();
  }

  static String subject(AppStrings s, FeedbackKind kind) =>
      '[${s.t('fb.kind_${kind.name}')}] Dosya Okuyucu $appVersionFull';

  @override
  State<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends State<FeedbackScreen> {
  late FeedbackKind _kind = widget.initialKind;
  final _text = TextEditingController();
  bool _attachLogs = true;
  bool _sending = false;

  static const _minChars = 10;

  @override
  void initState() {
    super.initState();
    _text.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<String> _body(AppStrings s) async {
    var crash = '';
    if (_attachLogs && _kind == FeedbackKind.bug) {
      final records = await CrashLog.load();
      if (records.isNotEmpty) {
        crash = CrashLog.asShareText(records.take(3).toList());
      }
    }
    return FeedbackScreen.compose(
      s: s,
      kind: _kind,
      message: _text.text,
      deviceLine: CrashLog.deviceLine(),
      crashText: crash,
    );
  }

  Future<void> _send() async {
    final s = AppStrings.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);
    setState(() => _sending = true);
    try {
      final body = await _body(s);
      final subject = FeedbackScreen.subject(s, _kind);
      var ok = false;
      if (kSupportEmail.isNotEmpty) {
        final uri = Uri(
          scheme: 'mailto',
          path: kSupportEmail,
          query: 'subject=${Uri.encodeComponent(subject)}'
              '&body=${Uri.encodeComponent(body)}',
        );
        ok = await launchUrl(uri);
      }
      if (!ok) {
        await SharePlus.instance
            .share(ShareParams(text: body, subject: subject));
      }
      if (!mounted) return;
      showSnackOn(messenger, s.t('fb.thanks'));
      nav.pop();
    } catch (_) {
      if (mounted) showSnackOn(messenger, s.t('fb.failed'));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _preview() async {
    final s = AppStrings.of(context);
    final body = await _body(s);
    if (!mounted) return;
    await showAppSheet<void>(
      context,
      title: s.t('fb.preview'),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(Gap.md, 0, Gap.md, Gap.md),
        child: SelectableText(body),
      ),
    );
  }

  Future<void> _copy() async {
    final s = AppStrings.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final body = await _body(s);
    await Clipboard.setData(ClipboardData(text: body));
    if (mounted) showSnackOn(messenger, s.t('fb.copied'));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ready = _text.text.trim().length >= _minChars && !_sending;
    return Scaffold(
      appBar: AppBar(title: Text(context.t('fb.title'))),
      body: ListView(
        padding: const EdgeInsets.all(Gap.md),
        children: [
          SegmentedButton<FeedbackKind>(
            key: const ValueKey('fb-kind'),
            segments: [
              for (final k in FeedbackKind.values)
                ButtonSegment(
                  value: k,
                  label: Text(context.t('fb.kind_${k.name}')),
                  icon: Icon(switch (k) {
                    FeedbackKind.bug => AppIcons.bugReport,
                    FeedbackKind.idea => AppIcons.lightbulbOutline,
                    FeedbackKind.other => AppIcons.help,
                  }),
                ),
            ],
            selected: {_kind},
            showSelectedIcon: false,
            onSelectionChanged: (v) => setState(() => _kind = v.first),
          ),
          const SizedBox(height: Gap.md),
          TextField(
            key: const ValueKey('fb-text'),
            controller: _text,
            minLines: 5,
            maxLines: 12,
            maxLength: 4000,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              border: const OutlineInputBorder(),
              hintText: context.t(_kind == FeedbackKind.bug
                  ? 'help.report_body'
                  : 'fb.idea_hint'),
            ),
          ),
          if (_kind == FeedbackKind.bug)
            SwitchListTile(
              key: const ValueKey('fb-logs'),
              contentPadding: EdgeInsets.zero,
              value: _attachLogs,
              onChanged: (v) => setState(() => _attachLogs = v),
              title: Text(context.t('fb.attach_logs')),
              subtitle: Text(context.t('fb.attach_logs_sub')),
            ),
          const SizedBox(height: Gap.sm),
          Text(context.t('fb.privacy'),
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          const SizedBox(height: Gap.lg),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: Gap.xs,
            runSpacing: Gap.xs,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextButton.icon(
                    key: const ValueKey('fb-preview'),
                    onPressed: _preview,
                    icon: const Icon(AppIcons.hidden),
                    label: Text(context.t('fb.preview')),
                  ),
                  TextButton.icon(
                    key: const ValueKey('fb-copy'),
                    onPressed: ready ? _copy : null,
                    icon: const Icon(AppIcons.clipCopy),
                    label: Text(context.t('fb.copy')),
                  ),
                ],
              ),
              FilledButton.icon(
                key: const ValueKey('fb-send'),
                onPressed: ready ? _send : null,
                icon: const Icon(AppIcons.send),
                label: Text(context.t('fb.send')),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
