import 'package:flutter/material.dart';

import '../../core/app_icons.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/theme.dart';
import '../../services/fm/archive_ops.dart';

/// Kullanıcının seçtiği sıkıştırma ayarları.
class CompressOptions {
  final CompressFormat format;
  final String? password;
  final bool hideNames;

  /// Bölünmüş arşiv (Faz 41 / 7): cilt boyutu (bayt); null = tek dosya.
  final int? volumeBytes;
  const CompressOptions({
    required this.format,
    this.password,
    this.hideNames = false,
    this.volumeBytes,
  });

  /// Hazır cilt boyutları: e-posta eki, bulut yüklemesi, CD, FAT32 sınırı.
  static const volumeSizes = <(String, int)>[
    ('cmp.vol_25', 25 << 20),
    ('cmp.vol_100', 100 << 20),
    ('cmp.vol_700', 700 << 20),
    ('cmp.vol_4g', (4 << 30) - (1 << 20)),
  ];
}

/// "Sıkıştır" seçenekleri: biçim (ZIP/7z), isteğe bağlı **parola** (AES-256)
/// ve 7z'de dosya adlarını da gizleme.
///
/// *Niye 7z de var:* parolalı ZIP'te (WinZip AES) dosya ADLARI arşivin
/// dizininde açık kalır — gizlilik gerekiyorsa 7z + "adları gizle" gerekir.
/// RAR üretimi yok: biçimin sıkıştırıcısı özel mülk (okuma destekleniyor).
Future<CompressOptions?> showCompressSheet(BuildContext context) {
  return showModalBottomSheet<CompressOptions>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
      child: const _CompressSheet(),
    ),
  );
}

class _CompressSheet extends StatefulWidget {
  const _CompressSheet();

  @override
  State<_CompressSheet> createState() => _CompressSheetState();
}

class _CompressSheetState extends State<_CompressSheet> {
  CompressFormat _format = CompressFormat.zip;
  bool _protect = false;
  bool _hideNames = false;
  int? _volume;
  final _password = TextEditingController();

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(Gap.lg, 0, Gap.lg, Gap.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(context.t('cmp.title'),
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: Gap.md),
            SegmentedButton<CompressFormat>(
              segments: const [
                ButtonSegment(
                  value: CompressFormat.zip,
                  label: Text('ZIP'),
                  icon: Icon(AppIcons.archiveView),
                ),
                ButtonSegment(
                  value: CompressFormat.sevenZip,
                  label: Text('7z'),
                  icon: Icon(AppIcons.shrink),
                ),
              ],
              selected: {_format},
              onSelectionChanged: (s) => setState(() {
                _format = s.first;
                if (_format == CompressFormat.zip) _hideNames = false;
              }),
            ),
            const SizedBox(height: Gap.sm),
            Text(
              _format == CompressFormat.zip
                  ? context.t('cmp.zip_note')
                  : context.t('cmp.7z_note'),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(context.t('cmp.set_password')),
              value: _protect,
              onChanged: (v) => setState(() => _protect = v),
            ),
            if (_protect) ...[
              TextField(
                controller: _password,
                obscureText: true,
                autofocus: true,
                decoration:
                    InputDecoration(labelText: context.t('common.password')),
                onChanged: (_) => setState(() {}),
              ),
              if (_format == CompressFormat.sevenZip)
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(context.t('cmp.hide_names')),
                  subtitle: Text(context.t('cmp.hide_names_sub')),
                  value: _hideNames,
                  onChanged: (v) => setState(() => _hideNames = v),
                ),
              Text(
                context.t('cmp.password_warning'),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.error,
                    ),
              ),
            ],
            // Faz 41 / 7: bölünmüş arşiv (7-Zip ciltleri: `.zip.001`/`.7z.001`).
            const SizedBox(height: Gap.sm),
            Text(context.t('cmp.split'),
                style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: Gap.xs),
            Wrap(
              spacing: Gap.sm,
              runSpacing: Gap.xs,
              children: [
                ChoiceChip(
                  key: const ValueKey('cmp-vol-none'),
                  label: Text(context.t('cmp.vol_none')),
                  selected: _volume == null,
                  onSelected: (_) => setState(() => _volume = null),
                ),
                for (final (key, bytes) in CompressOptions.volumeSizes)
                  ChoiceChip(
                    key: ValueKey('cmp-vol-$bytes'),
                    label: Text(context.t(key)),
                    selected: _volume == bytes,
                    onSelected: (_) => setState(() => _volume = bytes),
                  ),
              ],
            ),
            const SizedBox(height: Gap.md),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: FilledButton.icon(
                onPressed: _protect && _password.text.isEmpty
                    ? null
                    : () => Navigator.pop(
                          context,
                          CompressOptions(
                            format: _format,
                            password: _protect ? _password.text : null,
                            hideNames: _hideNames,
                            volumeBytes: _volume,
                          ),
                        ),
                icon: const Icon(AppIcons.compress),
                label: Text(context.t('cmp.title')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
