import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/app_state.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/snack.dart';
import '../../core/theme.dart';
import '../../models/fs_entry.dart';
import '../../services/gemini_decisions.dart';
import '../../services/offline_mode.dart';
import '../../widgets/app_dialog.dart';

/// **Paylaşmadan önce kişisel veri kalkanı** (2026-11-18, Decisions API).
///
/// Açıksa (Ayarlar → AI, varsayılan KAPALI — dosyayı buluta göndermek
/// kullanıcının bilerek açtığı bir şey olmalı) "Paylaş"a basınca ilk
/// [_maxFiles] görsel/PDF'e iki evet/hayır sorusu sorulur: kişisel veri
/// (TC no, telefon, adres, IBAN, sağlık) ve kimlik/banka kartı. Biri
/// ≥ [_threshold] ise "yine de paylaş?" onayı. Kalkan YARDIMCIDIR, kapı değil:
/// anahtar yoksa, çevrimdışıysa, [_budget] içinde yanıt gelmezse ya da hata
/// olursa paylaşım hiç beklemeden sürer.
abstract final class ShareShield {
  static const prefKey = 'share_shield';
  static const _maxFiles = 5;
  static const _threshold = 0.7;
  static const _budget = Duration(seconds: 6);

  static bool? _cached;

  static Future<bool> enabled() async {
    final c = _cached;
    if (c != null) return c;
    try {
      return _cached =
          (await SharedPreferences.getInstance()).getBool(prefKey) ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<void> setEnabled(bool v) async {
    _cached = v;
    try {
      await (await SharedPreferences.getInstance()).setBool(prefKey, v);
    } catch (_) {
      // Bilinçli: yazılamazsa seçim yalnız bu oturumda geçerli.
    }
  }

  static const _questions = [
    DecisionQuestion.yesNo(
      'pii',
      'pii',
      'Does this content show personal data such as a national ID number, '
          'phone number, home address, bank account / IBAN or health '
          'information about a person?',
    ),
    DecisionQuestion.yesNo(
      'id_card',
      'id_card',
      'Is an identity card, passport, driving licence or bank card visible?',
    ),
  ];

  /// Kalkana uğrayacak dosyalar (görsel ve PDF, var olan, sınır içinde).
  static Future<List<String>> candidates(List<String> paths) async {
    final out = <String>[];
    for (final path in paths) {
      if (out.length >= _maxFiles) break;
      if (!const {'image', 'document'}
          .contains(GeminiDecisions.mediaFor(path)?.type)) {
        continue;
      }
      final file = File(path);
      if (!await file.exists()) continue;
      if (await file.length() > GeminiDecisions.maxInlineBytes) continue;
      out.add(path);
    }
    return out;
  }
}

/// `true` = paylaşıma devam. Bkz. [ShareShield].
Future<bool> shareShieldAllows(BuildContext context, List<String> paths) async {
  if (!await ShareShield.enabled() || !context.mounted) return true;
  final state = context.read<AppState>();
  final keys = state.aiCredentials.normalized.keys;
  if (keys.isEmpty || OfflineMode.enabled) return true;
  final scope = state.aiScopeRules;
  final s = AppStrings.of(context);
  final files = [
    for (final path in await ShareShield.candidates(paths))
      if (scope.allowsFile(FsEntry.fromEntity(File(path)))) path
  ];
  if (files.isEmpty || !context.mounted) return true;
  final toast = showStickyToast(
    context,
    Row(children: [
      const SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(strokeWidth: 2)),
      const SizedBox(width: Gap.md),
      Expanded(child: Text(s.t('shield.checking'))),
    ]),
  );
  final flagged = <String>[];
  Future<void> check(String path) async {
    try {
      final r = await GeminiDecisions.ask(
        keys: keys,
        input: [await GeminiDecisions.fileBlock(path)],
        questions: ShareShield._questions,
      );
      if (r.answers.any((a) => (a.yes ?? 0) >= ShareShield._threshold)) {
        flagged.add(path);
      }
    } catch (_) {
      // Bilinçli: kalkan yardımcı; soru düşerse dosya işaretlenmez.
    }
  }

  try {
    await Future.wait([for (final f in files) check(f)])
        .timeout(ShareShield._budget);
  } on TimeoutException {
    // Bilinçli: süre dolunca o ana kadarki sonuçla devam (paylaşım beklemez).
  } finally {
    toast.close();
  }
  if (flagged.isEmpty || !context.mounted) return true;
  return showAppConfirm(
    context,
    title: s.t('shield.title'),
    message: s.t('shield.body', {
      'files': flagged.map(p.basename).join('\n'),
    }),
    confirmLabel: s.t('shield.share_anyway'),
  );
}
