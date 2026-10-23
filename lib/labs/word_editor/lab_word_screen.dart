import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/app_icons.dart';
import '../../core/edit/editor_chrome.dart';
import '../../core/l10n/app_strings.dart';
import '../../widgets/office_ribbon.dart';
import 'thin_editor.dart';

/// "Yeni Word editörü (deneme)" ekranı (Faz 21b / K18). Belgenin
/// paragraflarını ince çekirdekte açar; KAYDETMEZ — yalnız yazma hissini
/// (📱 kontrol noktası, `docs/CIHAZ_TESTI.md`) ölçmek için.
class LabWordEditorScreen extends StatefulWidget {
  final String title;
  final List<String> paragraphs;
  const LabWordEditorScreen(
      {super.key, required this.title, required this.paragraphs});

  @override
  State<LabWordEditorScreen> createState() => _LabWordEditorScreenState();
}

class _LabWordEditorScreenState extends State<LabWordEditorScreen> {
  late final ThinEditorController _c = ThinEditorController(widget.paragraphs);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Future<void> _paste() async {
    final d = await Clipboard.getData(Clipboard.kTextPlain);
    final t = d?.text;
    if (t != null && t.isNotEmpty) _c.insertText(t);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title, maxLines: 1, overflow: TextOverflow.ellipsis),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(28),
          child: Container(
            width: double.infinity,
            color: scheme.tertiaryContainer,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Text(context.t('lab.word_banner'),
                style: TextStyle(color: scheme.onTertiaryContainer)),
          ),
        ),
      ),
      body: EditorChrome(
        body: ThinEditor(controller: _c),
        accessory: ListenableBuilder(
          listenable: _c,
          builder: (context, _) {
            bool on(int bit) {
              if (_c.collapsed) return _c.typingStyle & bit != 0;
              final p = _c.paras[_c.start.para];
              final k = _c.start.offset.clamp(0, p.styles.length - 1);
              return p.styles.isNotEmpty && p.styles[k] & bit != 0;
            }

            return KeyboardAccessoryBar(
              onHideKeyboard: () =>
                  SystemChannels.textInput.invokeMethod<void>('TextInput.hide'),
              items: [
                AccessoryItem(
                    icon: OfficeIcons.bold,
                    tooltip: context.t('common.bold'),
                    selected: on(ThinStyle.bold),
                    onPressed: () => _c.toggle(ThinStyle.bold)),
                AccessoryItem(
                    icon: OfficeIcons.italic,
                    tooltip: context.t('common.italic'),
                    selected: on(ThinStyle.italic),
                    onPressed: () => _c.toggle(ThinStyle.italic)),
                AccessoryItem(
                    icon: OfficeIcons.underline,
                    tooltip: context.t('common.underline'),
                    selected: on(ThinStyle.underline),
                    onPressed: () => _c.toggle(ThinStyle.underline)),
                AccessoryItem(
                    icon: AppIcons.copy,
                    tooltip: context.t('common.copy'),
                    onPressed: () => Clipboard.setData(
                        ClipboardData(text: _c.selectedText()))),
                AccessoryItem(
                    icon: AppIcons.paste,
                    tooltip: context.t('common.paste'),
                    onPressed: _paste),
              ],
            );
          },
        ),
      ),
    );
  }
}
