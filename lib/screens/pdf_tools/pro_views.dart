part of '../pdf_tools_screen.dart';

/// Pro araç levhasındaki bir satır.
class _ProTool {
  final String id;
  final IconData icon;
  final String title;
  final String? subtitle;
  const _ProTool(this.id, this.icon, this.title, [this.subtitle]);
}

/// Faz 39 araçları — gruplu. Yeni araç buraya bir satır + [_openProTools]
/// içinde bir dal.
const _proTools = <List<_ProTool>>[
  [
    _ProTool('dsign', AppIcons.pdfSignCert, 'pp.dsign', 'pp.dsign_sub'),
    _ProTool('dsign_list', AppIcons.draw, 'pp.dsign_list'),
  ],
  [
    _ProTool('redact', AppIcons.pdfRedact, 'pp.redact', 'pp.redact_sub'),
  ],
];

class _ProToolsSheet extends StatelessWidget {
  const _ProToolsSheet();

  @override
  Widget build(BuildContext context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var g = 0; g < _proTools.length; g++) ...[
            if (g > 0) const Divider(height: 1),
            for (final t in _proTools[g])
              ListTile(
                leading: Icon(t.icon),
                title: Text(context.t(t.title)),
                subtitle:
                    t.subtitle == null ? null : Text(context.t(t.subtitle!)),
                onTap: () => Navigator.pop(context, t.id),
              ),
          ],
        ],
      );
}

// ── Dijital imza ──────────────────────────────────────────────────────────

class _DSignOptions {
  final bool pfx;
  final String name;
  final String reason;
  final String location;
  final bool visible;
  final bool lastPage;
  final bool exportCertificate;
  const _DSignOptions({
    required this.pfx,
    required this.name,
    required this.reason,
    required this.location,
    required this.visible,
    required this.lastPage,
    this.exportCertificate = false,
  });
}

class _DigitalSignSheet extends StatefulWidget {
  const _DigitalSignSheet({required this.initialName, required this.hasIdentity});

  final String initialName;
  final bool hasIdentity;

  @override
  State<_DigitalSignSheet> createState() => _DigitalSignSheetState();
}

class _DigitalSignSheetState extends State<_DigitalSignSheet> {
  late final _name = TextEditingController(text: widget.initialName);
  final _reason = TextEditingController();
  final _location = TextEditingController();
  bool _pfx = false;
  bool _visible = true;
  bool _lastPage = true;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _reason.dispose();
    _location.dispose();
    super.dispose();
  }

  _DSignOptions _options({bool export = false}) => _DSignOptions(
        pfx: _pfx,
        name: _name.text.trim(),
        reason: _reason.text.trim(),
        location: _location.text.trim(),
        visible: _visible,
        lastPage: _lastPage,
        exportCertificate: export,
      );

  void _submit() {
    if (_name.text.trim().isEmpty) {
      setState(() => _error = context.t('pp.dsign_name_needed'));
      return;
    }
    Navigator.pop(context, _options());
  }

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: Gap.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(context.t('pp.dsign_source'),
                style: context.type.caption),
            const SizedBox(height: Gap.xs),
            SegmentedButton<bool>(
              showSelectedIcon: false,
              segments: [
                ButtonSegment(
                    value: false, label: Text(context.t('pp.dsign_self'))),
                ButtonSegment(
                    value: true, label: Text(context.t('pp.dsign_pfx'))),
              ],
              selected: {_pfx},
              onSelectionChanged: (v) => setState(() => _pfx = v.first),
            ),
            const SizedBox(height: Gap.sm),
            TextField(
              controller: _name,
              decoration: InputDecoration(
                  labelText: context.t('pp.dsign_name'), errorText: _error),
            ),
            TextField(
              controller: _reason,
              decoration:
                  InputDecoration(labelText: context.t('pp.dsign_reason')),
            ),
            TextField(
              controller: _location,
              decoration:
                  InputDecoration(labelText: context.t('pp.dsign_location')),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _visible,
              onChanged: (v) => setState(() => _visible = v),
              title: Text(context.t('pp.dsign_visible')),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _lastPage,
              onChanged: (v) => setState(() => _lastPage = v),
              title: Text(context.t('pp.dsign_last_page')),
            ),
            if (widget.hasIdentity && !_pfx)
              TextButton.icon(
                onPressed: () =>
                    Navigator.pop(context, _options(export: true)),
                icon: const Icon(AppIcons.share),
                label: Text(context.t('pp.dsign_export_cert')),
              ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: Gap.sm),
              child: FilledButton.icon(
                onPressed: _submit,
                icon: const Icon(AppIcons.pdfSignCert),
                label: Text(context.t('pp.dsign_go')),
              ),
            ),
          ],
        ),
      );
}
