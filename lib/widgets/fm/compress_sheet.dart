import 'package:flutter/material.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/theme.dart';
import '../../services/fm/archive_ops.dart';

/// Kullanıcının seçtiği sıkıştırma ayarları.
class CompressOptions {
  final CompressFormat format;
  final String? password;
  final bool hideNames;
  const CompressOptions({
    required this.format,
    this.password,
    this.hideNames = false,
  });
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
      padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
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
                  icon: Icon(Icons.folder_zip_outlined),
                ),
                ButtonSegment(
                  value: CompressFormat.sevenZip,
                  label: Text('7z'),
                  icon: Icon(Icons.compress),
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
            const SizedBox(height: Gap.md),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                onPressed: _protect && _password.text.isEmpty
                    ? null
                    : () => Navigator.pop(
                          context,
                          CompressOptions(
                            format: _format,
                            password: _protect ? _password.text : null,
                            hideNames: _hideNames,
                          ),
                        ),
                icon: const Icon(Icons.archive_outlined),
                label: Text(context.t('cmp.title')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
