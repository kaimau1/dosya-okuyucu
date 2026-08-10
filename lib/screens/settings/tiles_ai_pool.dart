/// **Kesintisiz AI ayarları** — yedek anahtarlar ve model sırası.
///
/// KÖK NEDEN (2026-08-10 kullanıcı isteği): *"her modelin kotası ayrı olduğu
/// için 6 model seçebilelim, kotası bittikçe diğerine geçsin; 5 tane de API
/// anahtarı alanı olsun, 1.sindeki tüm kotalar bitince diğerine geçsin."*
///
/// Buradaki iki liste `AiPool`un deneme sırasıdır: **anahtar dıştan, model
/// içten**. Yani 1. anahtarın altı modeli de tükenmeden 2. anahtara geçilmez.
/// Bu, "asıl hesabım bitsin, sonra yedeğe geç" beklentisinin karşılığı.
///
/// Birincil anahtar ve modeli yukarıdaki `AiAccessTile` yönetir (doğrulama ve
/// model listesi çekme orada); burası **2. sıradan itibaren** yedekleri ekler.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_state.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/theme.dart';
import '../../services/ai_pool.dart';
import '../../services/gemini_service.dart';
import 'settings_widgets.dart';

/// Yedek API anahtarları (2. sıradan 5. sıraya).
class AiBackupKeysTile extends StatefulWidget {
  const AiBackupKeysTile({super.key});

  @override
  State<AiBackupKeysTile> createState() => _AiBackupKeysTileState();
}

class _AiBackupKeysTileState extends State<AiBackupKeysTile> {
  /// Yalnız YEDEK anahtarların denetleyicileri (birincil yukarıda düzenlenir).
  final _controllers = <TextEditingController>[];
  bool _obscure = true;

  @override
  void initState() {
    super.initState();
    final keys = context.read<AppState>().apiKeys;
    for (var i = 1; i < keys.length; i++) {
      _controllers.add(TextEditingController(text: keys[i]));
    }
  }

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  /// Alanlardaki değerleri birincil anahtarla birleştirip kaydeder.
  ///
  /// Birincil anahtar her zaman listenin başında kalır: kullanıcı yedek alanı
  /// boşaltsa bile ana anahtarı kaybetmemeli.
  Future<void> _save() async {
    final state = context.read<AppState>();
    final primary = state.apiKeys.isEmpty ? '' : state.apiKeys.first;
    await state.setApiKeys([
      primary,
      for (final controller in _controllers) controller.text,
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final canAdd = _controllers.length + 1 < AiCredentials.maxKeys;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SettingTile(
          icon: Icons.vpn_key_outlined,
          title: context.t('aipool.backup_keys'),
          subtitle: context.t('aipool.backup_keys_sub'),
          wrapSubtitle: true,
          value: '${state.apiKeys.length}/${AiCredentials.maxKeys}',
        ),
        for (var i = 0; i < _controllers.length; i++)
          Padding(
            padding: const EdgeInsets.fromLTRB(Gap.md, 0, Gap.md, Gap.sm),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controllers[i],
                    obscureText: _obscure,
                    decoration: InputDecoration(
                      isDense: true,
                      labelText:
                          context.t('aipool.key_n', {'n': i + 2}),
                      hintText: 'AIza...',
                    ),
                    onChanged: (_) => _save(),
                  ),
                ),
                IconButton(
                  tooltip: context.t('aipool.show_keys'),
                  icon: Icon(
                      _obscure ? Icons.visibility : Icons.visibility_off),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
                IconButton(
                  tooltip: context.t('common.delete'),
                  icon: const Icon(Icons.close),
                  onPressed: () async {
                    setState(() => _controllers.removeAt(i).dispose());
                    await _save();
                  },
                ),
              ],
            ),
          ),
        if (canAdd)
          Padding(
            padding: const EdgeInsets.only(left: Gap.md, bottom: Gap.sm),
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.add),
                label: Text(context.t('aipool.add_key')),
                onPressed: () =>
                    setState(() => _controllers.add(TextEditingController())),
              ),
            ),
          ),
      ],
    );
  }
}

/// Model sırası — kota dolunca sıradakine geçilir.
class AiModelChainTile extends StatefulWidget {
  const AiModelChainTile({super.key});

  @override
  State<AiModelChainTile> createState() => _AiModelChainTileState();
}

class _AiModelChainTileState extends State<AiModelChainTile> {
  /// Anahtardan çekilemezse kullanılan liste. Ücretsiz katmanda gerçekten
  /// ayrı kotası olan modeller bilinçli olarak önde.
  static const _fallback = [
    'gemini-2.0-flash',
    'gemini-2.0-flash-lite',
    'gemini-2.5-flash',
    'gemini-2.5-flash-lite',
    'gemini-1.5-flash',
    'gemini-1.5-flash-8b',
    'gemini-1.5-pro',
  ];

  List<String>? _available;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  /// Birincil anahtarla kullanılabilir modelleri çeker (başarısızsa yedek liste).
  Future<void> _fetch() async {
    final key = context.read<AppState>().apiKey.trim();
    if (key.isEmpty) return;
    setState(() => _loading = true);
    try {
      final models = await GeminiService.listModels(key);
      if (!mounted) return;
      setState(() {
        _available = models.isEmpty ? null : models;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final chain = state.aiModels;
    final available = _available ?? _fallback;
    final addable = [
      for (final model in available)
        if (!chain.contains(model)) model
    ];
    final canAdd = chain.length < AiCredentials.maxModels && addable.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SettingTile(
          icon: Icons.layers_outlined,
          title: context.t('aipool.model_chain'),
          subtitle: context.t('aipool.model_chain_sub'),
          wrapSubtitle: true,
          value: '${chain.length}/${AiCredentials.maxModels}',
          trailing: _loading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : null,
        ),
        for (var i = 0; i < chain.length; i++)
          // **"Model kaldırılmış olabilir"** (kullanıcı notu 2026-08-10):
          // ölü bir model listede sessizce durursa her işte bir başarısız
          // istek üretir. İki kaynak birleştiriliyor: anahtarın canlı model
          // listesi (varsa) ve havuzun 404 gördüğü modeller.
          Builder(builder: (context) {
            final dead = AiPool.deadModels.contains(chain[i]) ||
                (_available != null && !_available!.contains(chain[i]));
            return ListTile(
            dense: true,
            contentPadding: const EdgeInsets.only(left: 56, right: Gap.sm),
            leading: null,
            title: Text('${i + 1}. ${chain[i]}',
                maxLines: 1, overflow: TextOverflow.ellipsis),
            subtitle: !dead
                ? null
                : Text(
                    context.t('aipool.model_gone'),
                    style: TextStyle(
                      fontSize: 11,
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: context.t('aipool.move_up'),
                  icon: const Icon(Icons.arrow_upward, size: 20),
                  onPressed: i == 0
                      ? null
                      : () {
                          final next = [...chain];
                          final moved = next.removeAt(i);
                          next.insert(i - 1, moved);
                          context.read<AppState>().setAiModels(next);
                        },
                ),
                IconButton(
                  tooltip: context.t('common.delete'),
                  icon: const Icon(Icons.close, size: 20),
                  // Son model silinemez: modelsiz bir havuz hiçbir iş yapamaz.
                  onPressed: chain.length == 1
                      ? null
                      : () {
                          final next = [...chain]..removeAt(i);
                          context.read<AppState>().setAiModels(next);
                        },
                ),
              ],
            ),
          );
          }),
        Padding(
          padding: const EdgeInsets.only(left: 56, bottom: Gap.sm),
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: PopupMenuButton<String>(
              enabled: canAdd,
              onSelected: (model) =>
                  context.read<AppState>().setAiModels([...chain, model]),
              itemBuilder: (context) => [
                for (final model in addable)
                  PopupMenuItem(value: model, child: Text(model)),
              ],
              child: OutlinedButton.icon(
                icon: const Icon(Icons.add),
                label: Text(context.t('aipool.add_model')),
                // Menüyü sarmalayan PopupMenuButton açar; düğmenin kendi
                // onPressed'i olursa dokunuş orada tükenir ve menü açılmaz.
                onPressed: null,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Havuz durumu: kaç ikili soğumada, sıfırlama düğmesi.
class AiPoolStatusTile extends StatefulWidget {
  const AiPoolStatusTile({super.key});

  @override
  State<AiPoolStatusTile> createState() => _AiPoolStatusTileState();
}

class _AiPoolStatusTileState extends State<AiPoolStatusTile> {
  @override
  void initState() {
    super.initState();
    AiPool.ensureLoaded().then((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final slots = state.aiCredentials.slotCount;
    final cooling = AiPool.coolingCount;
    return SettingTile(
      icon: Icons.battery_charging_full_outlined,
      title: context.t('aipool.status'),
      subtitle: context.t('aipool.status_sub', {
        'total': slots,
        'cooling': cooling,
      }),
      wrapSubtitle: true,
      trailing: TextButton(
        onPressed: cooling == 0
            ? null
            : () async {
                await AiPool.clearCooldowns();
                if (mounted) setState(() {});
              },
        child: Text(context.t('aipool.reset')),
      ),
    );
  }
}
