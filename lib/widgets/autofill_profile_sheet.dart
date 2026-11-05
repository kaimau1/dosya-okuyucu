import 'package:flutter/material.dart';

import '../core/l10n/app_strings.dart';
import '../core/theme.dart';
import '../services/pdf_form_pro.dart';
import 'app_dialog.dart';

/// **Otomatik doldurma profili** düzenleme levhası (Faz 39 madde 9). Profil
/// yalnız bu cihazda saklanır; kaydedilen profil döner (vazgeçilirse `null`).
Future<Map<ProfileKey, String>?> showAutofillProfileSheet(
    BuildContext context) async {
  final current = await PdfFormPro.loadProfile();
  if (!context.mounted) return null;
  final result = await showAppSheet<Map<ProfileKey, String>>(
    context,
    title: context.t('pp.profile'),
    builder: (_) => _ProfileForm(initial: current),
  );
  if (result != null) await PdfFormPro.saveProfile(result);
  return result;
}

class _ProfileForm extends StatefulWidget {
  const _ProfileForm({required this.initial});

  final Map<ProfileKey, String> initial;

  @override
  State<_ProfileForm> createState() => _ProfileFormState();
}

class _ProfileFormState extends State<_ProfileForm> {
  late final Map<ProfileKey, TextEditingController> _ctl = {
    for (final k in ProfileKey.values)
      if (k != ProfileKey.date)
        k: TextEditingController(text: widget.initial[k] ?? ''),
  };

  @override
  void dispose() {
    for (final c in _ctl.values) {
      c.dispose();
    }
    super.dispose();
  }

  TextInputType _type(ProfileKey k) => switch (k) {
        ProfileKey.email => TextInputType.emailAddress,
        ProfileKey.phone => TextInputType.phone,
        ProfileKey.postalCode => TextInputType.number,
        ProfileKey.address => TextInputType.streetAddress,
        _ => TextInputType.name,
      };

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: Gap.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(context.t('pp.profile_privacy'), style: context.type.small),
            for (final e in _ctl.entries)
              TextField(
                controller: e.value,
                keyboardType: _type(e.key),
                maxLines: e.key == ProfileKey.address ? 2 : 1,
                decoration: InputDecoration(
                    labelText: context.t('pp.profile_${e.key.name}')),
              ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: Gap.sm),
              child: FilledButton(
                onPressed: () => Navigator.pop(context, {
                  for (final e in _ctl.entries) e.key: e.value.text.trim(),
                }),
                child: Text(context.t('common.save')),
              ),
            ),
          ],
        ),
      );
}
