import '../../core/secure_screen.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_icons.dart';
import '../../core/app_state.dart';
import '../../core/state/focused_states.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/theme.dart';
import '../../services/ai_tasks.dart';
import '../../services/gemini_service.dart';
import '../../core/user_error.dart';

/// Gemini erişimi: **anahtar + doğrulama + model** tek blokta.
///
/// Niye tek satır değil: üçü birbirine bağlı. Anahtar girilmeden model listesi
/// çekilemez, çekilemeyince de açılır menü yedek listeyi gösterir. Eski
/// ekranda anahtarın çalışıp çalışmadığı model listesinin ALTINDA, üç satır
/// aşağıda yazıyordu; "anahtarım geçerli mi" sorusu anahtarın hemen altında
/// cevaplanmalı.
class AiAccessTile extends StatefulWidget {
  const AiAccessTile({super.key});

  @override
  State<AiAccessTile> createState() => _AiAccessTileState();
}

class _AiAccessTileState extends State<AiAccessTile> {
  late final TextEditingController _apiKey;
  bool _obscure = true;

  /// Anahtar geçersiz/ağ hatası/henüz çekilmediyse gösterilen yedek liste.
  static const _fallbackModels = [
    'gemini-2.5-flash',
    'gemini-2.5-flash-lite',
    'gemini-2.5-pro',
  ];

  /// API'den çekilen modeller (anahtara özgü — plan/bölgeye göre değişir).
  List<String>? _fetchedModels;
  bool _loadingModels = false;
  String? _modelsError;

  /// Anahtar geçerli ama hiç model dönmedi (hata metninden ayrı tutulur —
  /// çevirisi `build`de yapılıyor, yoksa dil değişince eski dilde asılı kalır).
  bool _noModels = false;
  Timer? _debounce;

  /// Son çekilen anahtar — aynı anahtar için gereksiz tekrar çekmeyi önler.
  String? _fetchedForKey;

  @override
  void initState() {
    super.initState();
    final key = context.read<AppState>().apiKey;
    _apiKey = TextEditingController(text: key);
    if (key.trim().isNotEmpty) _fetchModels(key);
  }

  @override
  void dispose() {
    _apiKey.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onApiKeyChanged(String value) {
    context.read<AppState>().setApiKey(value);
    // Kullanıcı yazarken her tuşta ağ isteği atmamak için 600 ms bekleme.
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 600), () {
      if (value.trim().isNotEmpty) _fetchModels(value);
    });
  }

  /// Bu anahtarla kullanılabilir modelleri çeker. Anahtar geçersizse ya da ağ
  /// hatası olursa yedek listeye sessizce düşülür (kullanıcı yine de bir model
  /// seçip devam edebilsin).
  Future<void> _fetchModels(String apiKey) async {
    final key = apiKey.trim();
    if (key.isEmpty || key == _fetchedForKey) return;
    setState(() {
      _loadingModels = true;
      _modelsError = null;
      _noModels = false;
    });
    try {
      final models = await GeminiService.listModels(key);
      if (!mounted) return;
      unawaited(context.read<AppState>().setAiCatalog(models));
      setState(() {
        _fetchedModels = models.isEmpty ? null : models;
        _fetchedForKey = key;
        _loadingModels = false;
        _noModels = models.isEmpty;
      });
      // Kaydedilmiş model bu anahtarda yoksa (ilk kurulum ya da eski seçim
      // artık desteklenmiyor) listenin en iyisine geç.
      if (models.isNotEmpty &&
          !models.contains(context.read<AppState>().model)) {
        await context.read<AppState>().setModel(models.first);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingModels = false;
        _modelsError = userErrorText(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) =>
      SecureScreen(child: _secureBody(context));

  Widget _secureBody(BuildContext context) {
    final appState = context.watchAi();
    final modelsError =
        _noModels ? context.t('settings.model_none') : _modelsError;
    final models = _fetchedModels ?? _fallbackModels;
    final model =
        models.contains(appState.model) ? appState.model : models.first;

    return Padding(
      padding: const EdgeInsets.fromLTRB(Gap.md, Gap.sm, Gap.md, Gap.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _apiKey,
            obscureText: _obscure,
            decoration: InputDecoration(
              labelText: context.t('settings.api_key'),
              hintText: 'AIza...',
              suffixIcon: IconButton(
                tooltip: context.t('settings.api_key'),
                icon: Icon(_obscure ? AppIcons.hidden : AppIcons.hiddenOff),
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
            ),
            onChanged: _onApiKeyChanged,
          ),
          const SizedBox(height: Gap.xs),
          Text(context.t('settings.api_key_note'),
              style: context.type.small.copyWith(color: Paper.faint(context))),
          // **Doğrulama satırı** — anahtarın hemen altında.
          if (appState.hasApiKey) ...[
            const SizedBox(height: Gap.xs),
            Row(
              children: [
                Icon(
                  _fetchedModels != null
                      ? AppIcons.checkCircleOutline
                      : (modelsError != null
                          ? AppIcons.error
                          : AppIcons.hourglassEmpty),
                  size: 16,
                  color: _fetchedModels != null
                      ? Paper.success(context)
                      : (modelsError != null
                          ? Theme.of(context).colorScheme.error
                          : Paper.faint(context)),
                ),
                const SizedBox(width: Gap.xs),
                Flexible(
                  child: Text(
                    _fetchedModels != null
                        ? context
                            .t('set.key_valid', {'n': _fetchedModels!.length})
                        : (modelsError != null
                            ? context.t('set.key_invalid')
                            : context.t('settings.model_refresh')),
                    style:
                        context.type.small.copyWith(color: Paper.faint(context)),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: Gap.md),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  // initialValue yalnız ilk kurulumda okunur: model dışarıdan
                  // değişince (liste çekildi) alan yeniden kurulsun.
                  key: ValueKey(model),
                  initialValue: model,
                  decoration: InputDecoration(
                    labelText: context.t(_fetchedModels != null
                        ? 'settings.model_fetched'
                        : 'settings.model_default'),
                  ),
                  items: models
                      .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                      .toList(),
                  onChanged: (v) => v == null ? null : appState.setModel(v),
                ),
              ),
              const SizedBox(width: Gap.xs),
              if (_loadingModels)
                const Padding(
                  padding: EdgeInsets.all(Gap.sm),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              else
                IconButton(
                  tooltip: context.t('settings.model_refresh'),
                  icon: const Icon(AppIcons.refresh),
                  onPressed: appState.hasApiKey
                      ? () {
                          _fetchedForKey = null; // zorla yeniden çek
                          _fetchModels(appState.apiKey);
                        }
                      : null,
                ),
            ],
          ),
          if (modelsError != null) ...[
            const SizedBox(height: Gap.xs),
            Text(
              context.t('settings.model_error', {'error': modelsError}),
              style: context.type.small.copyWith(
                  color: Theme.of(context).colorScheme.error,
                ),
            ),
          ],
        ],
      ),
    );
  }
}

/// **Görev başına model** (2026-11-15): her iş için Otomatik (görevine göre
/// seçilmiş sıra) ya da elle bir model. Otomatik satırı o an ilk denenecek
/// modeli ve kota notunu gösterir.
class AiTaskModelsTile extends StatelessWidget {
  const AiTaskModelsTile({super.key});

  static const _titles = {
    AiTask.chat: 'aitask.chat',
    AiTask.structured: 'aitask.structured',
    AiTask.vision: 'aitask.vision',
  };
  static const _subs = {
    AiTask.chat: 'aitask.chat_sub',
    AiTask.structured: 'aitask.structured_sub',
    AiTask.vision: 'aitask.vision_sub',
  };

  @override
  Widget build(BuildContext context) {
    final state = context.watchAi();
    final catalog = [
      for (final m in state.aiCatalog)
        if (isTextModel(m)) m
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(Gap.md, Gap.sm, Gap.md, Gap.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (catalog.isEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: Gap.sm),
              child: Text(context.t('aitask.no_catalog'),
                  style:
                      context.type.small.copyWith(color: Paper.faint(context))),
            ),
          for (final task in AiTask.values) ...[
            _row(context, state, task, catalog),
            const SizedBox(height: Gap.md),
          ],
        ],
      ),
    );
  }

  Widget _row(BuildContext context, AppState state, AiTask task,
      List<String> catalog) {
    final auto = AiTaskModels.autoChain(task);
    final autoLabel = auto.isEmpty
        ? context.t('aitask.auto')
        : '${context.t('aitask.auto')} · ${auto.first.id}';
    final chosen = state.aiTaskModel(task);
    final value = chosen.isEmpty || !catalog.contains(chosen) ? '' : chosen;
    final note = value.isEmpty
        ? (auto.isEmpty ? context.t(_subs[task]!) : auto.first.note)
        : context.t(_subs[task]!);
    return DropdownButtonFormField<String>(
      key: ValueKey('aitask-${task.name}-$value-${catalog.length}'),
      initialValue: value,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: context.t(_titles[task]!),
        helperText: note,
      ),
      items: [
        DropdownMenuItem(
            value: '',
            child: Text(autoLabel, overflow: TextOverflow.ellipsis)),
        for (final m in catalog)
          DropdownMenuItem(
              value: m, child: Text(m, overflow: TextOverflow.ellipsis)),
      ],
      onChanged: (v) => state.setAiTaskModel(task, v ?? ''),
    );
  }
}

/// Yapay zekânın kalıcı hafızası: kullanıcının "bunu unutma" dediği notlar.
class MemoryTile extends StatelessWidget {
  const MemoryTile({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    // Not ekleme/silme `AiMemoryState` ile bildirilir (A4.2).
    return ListenableBuilder(
        listenable: appState.memoryState,
        builder: (context, _) => _list(context, appState));
  }

  Widget _list(BuildContext context, AppState appState) {
    if (appState.memory.isEmpty) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(Gap.md, Gap.sm, Gap.md, Gap.sm),
        child: Text(context.t('settings.memory_empty'),
            style: context.type.small.copyWith(color: Paper.faint(context))),
      );
    }
    return Column(
      children: [
        for (final e in appState.memory.asMap().entries)
          ListTile(
            dense: true,
            leading: const Icon(AppIcons.notes),
            title: Text(e.value, maxLines: 3, overflow: TextOverflow.ellipsis),
            trailing: IconButton(
              tooltip: context.t('common.delete'),
              icon: const Icon(AppIcons.delete),
              onPressed: () => appState.removeMemory(e.key),
            ),
          ),
      ],
    );
  }
}
