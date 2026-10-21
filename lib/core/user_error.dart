import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/crash_log.dart';
import '../services/gemini_service.dart';
import 'l10n/app_strings.dart';
import 'snack.dart';

/// Hatanın kullanıcıya dönük sınıfı (Faz 5, 2026-10-21 — FAZ_PLANI §3.7).
enum UserErrorKind {
  permission,
  noSpace,
  notFound,
  readOnly,
  exists,
  offline,
  pdfDamaged,
  pdfLocked,
  aiKey,
  aiQuota,
  cancelled,
  unknown,
}

/// **Kullanıcı dili hata** — ham `'$e'` yerine.
///
/// Eskiden ekranlar `FileSystemException: Cannot open file, path = …, OS
/// Error: Permission denied, errno = 13` gibi metinleri doğrudan gösteriyordu
/// (103 yer, FAZ_PLANI I1). Artık [UserError.from] hatayı sınıflandırır:
/// kısa, çevrilmiş bir [message] + yalnız "Ayrıntı"da görünen ham [detail].
/// Sınıflandırılamayan hatalar `CrashLog`a otomatik yazılır.
@immutable
class UserError {
  final UserErrorKind kind;

  /// Arayüz dilinde kısa açıklama.
  final String message;

  /// Ham hata metni (yalnız "Ayrıntı" düğmesi arkasında).
  final String detail;

  const UserError(this.kind, this.message, this.detail);

  /// Bilinen hata türlerini kullanıcı diline çevirir.
  factory UserError.from(Object error, {AppStrings? strings}) {
    final s = strings ?? AppStrings.current;
    final kind = classify(error);
    if (kind == UserErrorKind.unknown) {
      unawaited(CrashLog.record(error, StackTrace.current,
          context: 'user_error', kind: 'handled'));
    }
    return UserError(kind, s.t(_keyOf(kind)), error.toString());
  }

  /// Saf sınıflandırma (birim testli).
  static UserErrorKind classify(Object error) {
    if (error is UserError) return error.kind;
    if (error is FileSystemException) {
      return _fromOs(error.osError?.errorCode, error.message, error.osError?.message);
    }
    if (error is SocketException ||
        error is TimeoutException ||
        error is HttpException ||
        error is HandshakeException) {
      return UserErrorKind.offline;
    }
    if (error is GeminiException) {
      final code = error.statusCode;
      if (code == 0) return UserErrorKind.offline;
      if (code == 429) return UserErrorKind.aiQuota;
      if (code == 400 || code == 401 || code == 403) return UserErrorKind.aiKey;
      return UserErrorKind.unknown;
    }
    if (error is PlatformException) {
      final m = '${error.code} ${error.message}'.toLowerCase();
      if (m.contains('permission') || m.contains('denied')) {
        return UserErrorKind.permission;
      }
      if (m.contains('cancel')) return UserErrorKind.cancelled;
    }
    // Paket istisnalarına (pdfrx `PdfException`/`PdfPasswordException`)
    // tür bağımlılığı eklemeden ADIYLA bakılır.
    final type = error.runtimeType.toString();
    final text = error.toString().toLowerCase();
    if (type.contains('PdfPassword') || text.contains('password')) {
      return UserErrorKind.pdfLocked;
    }
    if (type.startsWith('Pdf') && type.contains('Exception')) {
      return UserErrorKind.pdfDamaged;
    }
    if (error is OSError) return _fromOs(error.errorCode, error.message, null);
    return UserErrorKind.unknown;
  }

  static UserErrorKind _fromOs(int? code, String message, String? osMessage) {
    switch (code) {
      case 1: // EPERM
      case 13: // EACCES
        return UserErrorKind.permission;
      case 2: // ENOENT
        return UserErrorKind.notFound;
      case 17: // EEXIST
        return UserErrorKind.exists;
      case 28: // ENOSPC
      case 122: // EDQUOT
        return UserErrorKind.noSpace;
      case 30: // EROFS
        return UserErrorKind.readOnly;
    }
    final m = '$message ${osMessage ?? ''}'.toLowerCase();
    if (m.contains('permission denied') || m.contains('not permitted')) {
      return UserErrorKind.permission;
    }
    if (m.contains('no space')) return UserErrorKind.noSpace;
    if (m.contains('no such file') || m.contains('cannot find')) {
      return UserErrorKind.notFound;
    }
    if (m.contains('read-only')) return UserErrorKind.readOnly;
    if (m.contains('exists')) return UserErrorKind.exists;
    return UserErrorKind.unknown;
  }

  static String _keyOf(UserErrorKind kind) => switch (kind) {
        UserErrorKind.permission => 'uerr.permission',
        UserErrorKind.noSpace => 'uerr.no_space',
        UserErrorKind.notFound => 'uerr.not_found',
        UserErrorKind.readOnly => 'uerr.read_only',
        UserErrorKind.exists => 'uerr.exists',
        UserErrorKind.offline => 'uerr.offline',
        UserErrorKind.pdfDamaged => 'uerr.pdf_damaged',
        UserErrorKind.pdfLocked => 'uerr.pdf_locked',
        UserErrorKind.aiKey => 'uerr.ai_key',
        UserErrorKind.aiQuota => 'uerr.ai_quota',
        UserErrorKind.cancelled => 'uerr.cancelled',
        UserErrorKind.unknown => 'uerr.unknown',
      };

  @override
  String toString() => message;
}

/// Ekran kodunun `{'error': e}` / `'$e'` yerine kullandığı kısa metin.
String userErrorText(Object error) => UserError.from(error).message;

/// Hata bildirimi: kısa mesaj + **"Ayrıntı"** (ham metni gösterir, kopyalanır)
/// ve isteğe bağlı **"Yeniden dene"**. [prefix] verilirse mesajın önüne
/// eklenir ("Kaydedilemedi: …").
ToastHandle showUserError(
  BuildContext context,
  Object error, {
  String? prefix,
  VoidCallback? onRetry,
}) {
  final e = UserError.from(error, strings: AppStrings.of(context));
  final text = prefix == null ? e.message : '$prefix: ${e.message}';
  final action = onRetry != null
      ? SnackBarAction(label: context.t('uerr.retry'), onPressed: onRetry)
      : SnackBarAction(
          label: context.t('uerr.details'),
          onPressed: () => _showDetail(context, e),
        );
  return showSnack(context, text, action: action);
}

void _showDetail(BuildContext context, UserError e) {
  if (!context.mounted) return;
  unawaited(showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(ctx.t('uerr.details')),
      content: SingleChildScrollView(child: SelectableText(e.detail)),
      actions: [
        TextButton(
          onPressed: () {
            unawaited(Clipboard.setData(ClipboardData(text: e.detail)));
            Navigator.of(ctx).pop();
          },
          child: Text(ctx.t('common.copy')),
        ),
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: Text(ctx.t('common.ok')),
        ),
      ],
    ),
  ));
}
