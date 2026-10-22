import 'dart:async';

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../core/app_icons.dart';
import '../core/app_navigator.dart';
import '../core/l10n/app_strings.dart';
import '../core/snack.dart';

/// Uygulamanın istediği izinler — her biri için tek tip açıklama.
enum AppPermission { allFiles, notifications, camera, location, overlay }

/// Bir iznin durumu (eklentiden bağımsız, test edilebilir).
enum GateStatus { granted, denied, permanentlyDenied }

/// İzin sorgulama/isteme köprüsü. Testler [PermissionGate.probe]u değiştirir.
abstract class PermissionProbe {
  const PermissionProbe();
  Future<GateStatus> status(AppPermission p);
  Future<GateStatus> request(AppPermission p);
  Future<void> openSettings();
}

/// `permission_handler` ile gerçek uygulama.
class PluginPermissionProbe extends PermissionProbe {
  const PluginPermissionProbe();

  static Permission _of(AppPermission p) => switch (p) {
        AppPermission.allFiles => Permission.manageExternalStorage,
        AppPermission.notifications => Permission.notification,
        AppPermission.camera => Permission.camera,
        AppPermission.location => Permission.locationWhenInUse,
        AppPermission.overlay => Permission.systemAlertWindow,
      };

  static GateStatus _map(PermissionStatus s) => s.isGranted || s.isLimited
      ? GateStatus.granted
      : s.isPermanentlyDenied || s.isRestricted
          ? GateStatus.permanentlyDenied
          : GateStatus.denied;

  @override
  Future<GateStatus> status(AppPermission p) async {
    try {
      return _map(await _of(p).status);
    } catch (_) {
      // Eklenti yok (test/masaüstü): engel çıkarma.
      return GateStatus.granted;
    }
  }

  @override
  Future<GateStatus> request(AppPermission p) async {
    try {
      return _map(await _of(p).request());
    } catch (_) {
      return GateStatus.denied;
    }
  }

  @override
  Future<void> openSettings() async {
    try {
      await openAppSettings();
    } catch (_) {
      // Ayar sayfası açılamadıysa kart yerinde kalır; kullanıcı elle açar.
    }
  }
}

/// **Ortak izin kapısı** (Faz 5, 2026-10-21 — FAZ_PLANI I6).
///
/// İzin verilmişse [child]ı gösterir; verilmemişse TEK TİP bir kart:
/// ne için gerekli · izin olmadan ne olur/ne olmaz · "İzin ver" (ya da kalıcı
/// reddedildiyse "Ayarlara git"). Kullanıcı ayarlardan döndüğünde kapı kendini
/// tazeler — "verdim ama hâlâ istiyor" sorusu kalmaz.
class PermissionGate extends StatefulWidget {
  final AppPermission permission;
  final Widget child;

  /// İzin olmadan da gösterilecek içerik (ör. kısıtlı liste). Verilirse kart
  /// onun ÜSTÜNDE bir şerit olarak durur.
  final Widget? fallback;

  /// Testler değiştirir; uygulamada eklenti.
  static PermissionProbe probe = const PluginPermissionProbe();

  const PermissionGate({
    super.key,
    required this.permission,
    required this.child,
    this.fallback,
  });

  @override
  State<PermissionGate> createState() => _PermissionGateState();
}

class _PermissionGateState extends State<PermissionGate>
    with WidgetsBindingObserver {
  GateStatus? _status;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_refresh());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(_refresh());
  }

  Future<void> _refresh() async {
    final s = await PermissionGate.probe.status(widget.permission);
    if (mounted && s != _status) setState(() => _status = s);
  }

  Future<void> _ask() async {
    final probe = PermissionGate.probe;
    if (_status == GateStatus.permanentlyDenied) {
      await probe.openSettings();
      return; // dönüşte `resumed` tazeler
    }
    final s = await probe.request(widget.permission);
    if (mounted) setState(() => _status = s);
  }

  @override
  Widget build(BuildContext context) {
    final status = _status;
    if (status == null) return widget.fallback ?? const SizedBox.shrink();
    if (status == GateStatus.granted) return widget.child;
    final card = PermissionCard(
      permission: widget.permission,
      permanentlyDenied: status == GateStatus.permanentlyDenied,
      onAsk: _ask,
    );
    final fallback = widget.fallback;
    if (fallback == null) return Center(child: card);
    return Column(children: [card, Expanded(child: fallback)]);
  }
}

/// İzin kartının kendisi — kapı dışında da (pano üstü, ayarlar) kullanılır.
class PermissionCard extends StatelessWidget {
  final AppPermission permission;
  final bool permanentlyDenied;
  final VoidCallback onAsk;

  const PermissionCard({
    super.key,
    required this.permission,
    required this.permanentlyDenied,
    required this.onAsk,
  });

  static String keyOf(AppPermission p) => switch (p) {
        AppPermission.allFiles => 'all_files',
        AppPermission.notifications => 'notifications',
        AppPermission.camera => 'camera',
        AppPermission.location => 'location',
        AppPermission.overlay => 'overlay',
      };

  static IconData iconOf(AppPermission p) => switch (p) {
        AppPermission.allFiles => AppIcons.emptyFolder,
        AppPermission.notifications => Icons.notifications_none_rounded,
        AppPermission.camera => Icons.photo_camera_rounded,
        AppPermission.location => Icons.place_rounded,
        AppPermission.overlay => Icons.picture_in_picture_alt_rounded,
      };

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final k = keyOf(permission);
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(iconOf(permission), color: scheme.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Text(context.t('perm.${k}_title'),
                    style: Theme.of(context).textTheme.titleMedium),
              ),
            ]),
            const SizedBox(height: 8),
            Text(context.t('perm.${k}_why')),
            const SizedBox(height: 6),
            Text(context.t('perm.${k}_without'),
                style: TextStyle(color: scheme.onSurfaceVariant)),
            const SizedBox(height: 12),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: FilledButton.icon(
                onPressed: onAsk,
                icon: Icon(permanentlyDenied
                    ? AppIcons.settings
                    : Icons.check_circle_outline_rounded),
                label: Text(context.t(permanentlyDenied
                    ? 'perm.open_settings'
                    : 'perm.allow')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Yardım ekranındaki "izinlerim ne durumda?" satırı: durum + tek düğme.
class PermissionStatusRow extends StatefulWidget {
  final AppPermission permission;

  const PermissionStatusRow({super.key, required this.permission});

  @override
  State<PermissionStatusRow> createState() => _PermissionStatusRowState();
}

class _PermissionStatusRowState extends State<PermissionStatusRow>
    with WidgetsBindingObserver {
  GateStatus? _status;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_refresh());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(_refresh());
  }

  Future<void> _refresh() async {
    final s = await PermissionGate.probe.status(widget.permission);
    if (mounted) setState(() => _status = s);
  }

  @override
  Widget build(BuildContext context) {
    final k = PermissionCard.keyOf(widget.permission);
    final granted = _status == GateStatus.granted;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(PermissionCard.iconOf(widget.permission)),
      title: Text(context.t('perm.${k}_title')),
      subtitle: Text(context.t(granted ? 'perm.granted' : 'perm.${k}_without')),
      trailing: _status == null || granted
          ? null
          : TextButton(
              onPressed: () async {
                final probe = PermissionGate.probe;
                if (_status == GateStatus.permanentlyDenied) {
                  await probe.openSettings();
                } else {
                  final s = await probe.request(widget.permission);
                  if (mounted) setState(() => _status = s);
                }
              },
              child: Text(context.t(_status == GateStatus.permanentlyDenied
                  ? 'perm.open_settings'
                  : 'perm.allow')),
            ),
    );
  }
}

/// İlk uzun iş başlarken bildirim izni kapalıysa BİR KEZ söyler (Faz 5, I6):
/// "işler sürüyor ama haber gelmiyor" sorusunun cevabı. `JobQueue.onFirstJob`
/// kancası olarak `main` bağlar.
Future<void> tellIfNotificationsOff() async {
  final status = await PermissionGate.probe.status(AppPermission.notifications);
  if (status == GateStatus.granted) return;
  final context = navigatorKey.currentContext;
  if (context == null || !context.mounted) return;
  showSnack(
    context,
    context.t('uerr.notif_off'),
    duration: const Duration(seconds: 6),
    action: SnackBarAction(
      label: context.t('perm.open_settings'),
      onPressed: () => unawaited(PermissionGate.probe.openSettings()),
    ),
  );
}
