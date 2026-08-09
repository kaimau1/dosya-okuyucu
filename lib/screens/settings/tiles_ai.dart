import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_state.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/theme.dart';
import '../../services/gemini_service.dart';

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
    'gemini-2.0-flash',
    'gemini-2.0-flash-lite',
    'gemini-1.5-flash',
    'gemini-1.5-pro',
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
        _modelsError = '$e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
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
                icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
            ),
            onChanged: _onApiKeyChanged,
          ),
          const SizedBox(height: Gap.xs),
          Text(context.t('settings.api_key_note'),
              style: TextStyle(fontSize: 12, color: Paper.faint(context))),
          // **Doğrulama satırı** — anahtarın hemen altında.
          if (appState.hasApiKey) ...[
            const SizedBox(height: Gap.xs),
            Row(
              children: [
                Icon(
                  _fetchedModels != null
                      ? Icons.check_circle_outline
                      : (modelsError != null
                          ? Icons.error_outline
                          : Icons.hourglass_empty),
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
                        TextStyle(fontSize: 12, color: Paper.faint(context)),
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
                  value: model,
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
                  icon: const Icon(Icons.refresh),
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
              style: TextStyle(
                  color: Theme.of(context).colorScheme.error, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }
}

/// Yapay zekânın kalıcı hafızası: kullanıcının "bunu unutma" dediği notlar.
class MemoryTile extends StatelessWidget {
  const MemoryTile({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    if (appState.memory.isEmpty) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(Gap.md, Gap.sm, Gap.md, Gap.sm),
        child: Text(context.t('settings.memory_empty'),
            style: TextStyle(fontSize: 12, color: Paper.faint(context))),
      );
    }
    return Column(
      children: [
        for (final e in appState.memory.asMap().entries)
          ListTile(
            dense: true,
            leading: const Icon(Icons.sticky_note_2_outlined),
            title: Text(e.value, maxLines: 3, overflow: TextOverflow.ellipsis),
            trailing: IconButton(
              tooltip: context.t('common.delete'),
              icon: const Icon(Icons.delete_outline),
              onPressed: () => appState.removeMemory(e.key),
            ),
          ),
      ],
    );
  }
}
