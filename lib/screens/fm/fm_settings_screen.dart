import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_state.dart';
import '../../core/theme.dart';
import '../../models/fs_entry.dart';
import '../../services/fm/fm_env.dart';
import '../../services/fm/fs_scan.dart';
import '../../services/fm/installed_apps_service.dart';
import '../../services/fm/storage_permission.dart';
import '../settings_screen.dart';

/// **Dosya yöneticisine özel** ayarlar (uygulama geneli ayarlar ayrı ekranda:
/// Gemini anahtarı, tema, hesap).
///
/// Buradaki her ayar kalıcıdır (`AppState` → SharedPreferences) ve anında
/// uygulanır: görünüm, küçük resimler, silme davranışı, çöp kutusu bakımı,
/// izinler ve önbellek temizliği.
class FmSettingsScreen extends StatefulWidget {
  const FmSettingsScreen({super.key});

  @override
  State<FmSettingsScreen> createState() => _FmSettingsScreenState();
}

class _FmSettingsScreenState extends State<FmSettingsScreen> {
  int _trashCount = 0;
  int _trashBytes = 0;
  bool _fullAccess = true;
  bool _usageAccess = false;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    await FmEnv.ensureInit();
    final items = await FmEnv.trash.list();
    final access = await StoragePermission.hasFullAccess();
    final usage = await InstalledAppsService.hasUsagePermission();
    if (!mounted) return;
    setState(() {
      _trashCount = items.length;
      _trashBytes = items.fold<int>(0, (s, i) => s + i.sizeBytes);
      _fullAccess = access;
      _usageAccess = usage;
    });
  }

  Future<void> _emptyTrash() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Çöp kutusu boşaltılsın mı?'),
        content: const Text('Tüm öğeler kalıcı olarak silinir.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Vazgeç')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Boşalt')),
        ],
      ),
    );
    if (ok != true) return;
    await FmEnv.trash.empty();
    await _refresh();
  }

  Future<void> _clearThumbs() async {
    final dir = Directory('${FmEnv.appSupportDir}/../cache/video_thumbs');
    var removed = 0;
    try {
      if (dir.existsSync()) {
        for (final f in dir.listSync()) {
          try {
            f.deleteSync(recursive: true);
            removed++;
          } catch (_) {}
        }
      }
    } catch (_) {}
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(removed == 0
            ? 'Temizlenecek küçük resim bulunamadı.'
            : '$removed küçük resim silindi.')));
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();

    return Scaffold(
      appBar: AppBar(title: const Text('Dosya yöneticisi ayarları')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: Gap.xl),
        children: [
          _section('Görünüm'),
          SwitchListTile(
            secondary: const Icon(Icons.grid_view),
            title: const Text('Izgara görünümü'),
            subtitle: const Text('Klasörler ızgara olarak açılsın'),
            value: appState.fmGrid,
            onChanged: appState.setFmGrid,
          ),
          SwitchListTile(
            secondary: const Icon(Icons.visibility_outlined),
            title: const Text('Gizli dosyaları göster'),
            subtitle: const Text('Adı nokta ile başlayanlar (.thumbnails gibi)'),
            value: appState.fmShowHidden,
            onChanged: appState.setFmShowHidden,
          ),
          SwitchListTile(
            secondary: const Icon(Icons.image_outlined),
            title: const Text('Küçük resimler'),
            subtitle: const Text(
                'Görsel ve video önizlemeleri (yavaş cihazda kapatın)'),
            value: appState.fmThumbnails,
            onChanged: appState.setFmThumbnails,
          ),
          ListTile(
            leading: const Icon(Icons.sort),
            title: const Text('Varsayılan sıralama'),
            subtitle: Text('${appState.fmSort.label} · '
                '${appState.fmSortDesc ? "azalan" : "artan"}'),
            trailing: PopupMenuButton<String>(
              onSelected: (v) {
                if (v == 'dir') {
                  appState.setFmSort(appState.fmSort,
                      descending: !appState.fmSortDesc);
                } else {
                  appState.setFmSort(
                      FmSort.values.firstWhere((s) => s.name == v));
                }
              },
              itemBuilder: (_) => [
                for (final s in FmSort.values)
                  PopupMenuItem(value: s.name, child: Text(s.label)),
                const PopupMenuDivider(),
                const PopupMenuItem(
                    value: 'dir', child: Text('Yönü ters çevir')),
              ],
            ),
          ),

          _section('Silme'),
          SwitchListTile(
            secondary: const Icon(Icons.delete_outline),
            title: const Text('Çöp kutusunu kullan'),
            subtitle: const Text(
                'Kapalıysa dosyalar doğrudan kalıcı silinir (geri alınamaz)'),
            value: appState.fmUseTrash,
            onChanged: appState.setFmUseTrash,
          ),
          SwitchListTile(
            secondary: const Icon(Icons.help_outline),
            title: const Text('Silmeden önce sor'),
            value: appState.fmConfirmDelete,
            onChanged: appState.setFmConfirmDelete,
          ),
          ListTile(
            leading: const Icon(Icons.auto_delete_outlined),
            title: const Text('Çöp kutusunu otomatik temizle'),
            subtitle: Text(appState.fmTrashAutoDays == 0
                ? 'Kapalı — çöp elle boşaltılır'
                : '${appState.fmTrashAutoDays} günden eski öğeler silinir'),
            trailing: PopupMenuButton<int>(
              onSelected: appState.setFmTrashAutoDays,
              itemBuilder: (_) => const [
                PopupMenuItem(value: 0, child: Text('Kapalı')),
                PopupMenuItem(value: 7, child: Text('7 gün')),
                PopupMenuItem(value: 30, child: Text('30 gün')),
                PopupMenuItem(value: 90, child: Text('90 gün')),
              ],
            ),
          ),
          ListTile(
            leading: const Icon(Icons.delete_sweep_outlined),
            title: const Text('Çöp kutusunu şimdi boşalt'),
            subtitle: Text(_trashCount == 0
                ? 'Çöp kutusu boş'
                : '$_trashCount öğe · ${FsPaths.humanSize(_trashBytes)}'),
            onTap: _trashCount == 0 ? null : _emptyTrash,
          ),

          _section('İzinler'),
          ListTile(
            leading: Icon(_fullAccess ? Icons.lock_open : Icons.lock_outline),
            title: const Text('Tüm dosyalara erişim'),
            subtitle: Text(_fullAccess
                ? 'Verildi — tüm klasörler görünüyor'
                : 'Verilmedi — yalnız medya klasörleri görünür'),
            trailing: _fullAccess
                ? null
                : FilledButton.tonal(
                    onPressed: () async {
                      await StoragePermission.request();
                      await FmEnv.ensureInit(force: true);
                      await _refresh();
                    },
                    child: const Text('İzin ver'),
                  ),
          ),
          ListTile(
            leading: const Icon(Icons.query_stats),
            title: const Text('Kullanım erişimi'),
            subtitle: Text(_usageAccess
                ? 'Verildi — uygulamaların son açılma tarihi görünüyor'
                : 'Verilmedi — “Uygulamalar” ekranında tarih gösterilemez'),
            trailing: _usageAccess
                ? null
                : FilledButton.tonal(
                    onPressed: () async {
                      await InstalledAppsService.requestUsagePermission();
                      await _refresh();
                    },
                    child: const Text('İzin ver'),
                  ),
          ),

          _section('Bakım'),
          ListTile(
            leading: const Icon(Icons.cleaning_services_outlined),
            title: const Text('Küçük resim önbelleğini temizle'),
            subtitle: const Text('Video önizlemeleri yeniden üretilir'),
            onTap: _clearThumbs,
          ),
          ListTile(
            leading: const Icon(Icons.storage),
            title: const Text('Birimler'),
            subtitle: Text(FmEnv.volumes.isEmpty
                ? 'Bulunamadı'
                : FmEnv.volumes.map((v) => v.label).join(' · ')),
            onTap: () async {
              await FmEnv.ensureInit(force: true);
              await _refresh();
            },
          ),

          _section('Uygulama'),
          ListTile(
            leading: const Icon(Icons.settings_outlined),
            title: const Text('Genel ayarlar'),
            subtitle: const Text('Gemini anahtarı, tema, hesap'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
          ),
        ],
      ),
    );
  }

  Widget _section(String title) => Padding(
        padding: const EdgeInsets.fromLTRB(Gap.md, Gap.lg, Gap.md, Gap.xs),
        child: Text(
          title,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.w700,
              ),
        ),
      );
}
