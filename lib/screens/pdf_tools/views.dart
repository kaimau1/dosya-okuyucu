part of '../pdf_tools_screen.dart';


/// [_PageNumberSheet]'in döndürdüğü seçenekler.
class _NumberOptions {
  final bool skipFirst;
  final bool withTotal;
  final bool right;
  const _NumberOptions(this.skipFirst, this.withTotal, this.right);
}

/// Sayfa numarası seçenekleri — üç anahtar, hepsi kapalı gelir.
///
/// Varsayılan (ortada, 1'den başlayan sade sayı) en sık istenen hâl olduğu
/// için kullanıcı hiçbir şeye dokunmadan "Ekle" diyebilir.
class _PageNumberSheet extends StatefulWidget {
  const _PageNumberSheet();

  @override
  State<_PageNumberSheet> createState() => _PageNumberSheetState();
}

class _PageNumberSheetState extends State<_PageNumberSheet> {
  bool _skipFirst = false;
  bool _withTotal = false;
  bool _right = false;

  @override
  Widget build(BuildContext context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(context.t('pt.page_numbers'),
                  style: Theme.of(context).textTheme.titleMedium),
            ),
            SwitchListTile(
              value: _skipFirst,
              onChanged: (v) => setState(() => _skipFirst = v),
              title: Text(context.t('pt.pn_skip_first')),
              subtitle: Text(context.t('pt.pn_skip_first_sub')),
            ),
            SwitchListTile(
              value: _withTotal,
              onChanged: (v) => setState(() => _withTotal = v),
              title: Text(context.t('pt.pn_with_total')),
            ),
            SwitchListTile(
              value: _right,
              onChanged: (v) => setState(() => _right = v),
              title: Text(context.t('pt.pn_right')),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(context.t('common.cancel')),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: () => Navigator.pop(
                        context, _NumberOptions(_skipFirst, _withTotal, _right)),
                    child: Text(context.t('common.add')),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
}

extension _PdfToolsScreenViewsPart on _PdfToolsScreenState {
  /// Süren iş perdesi: ne olduğunu yazar ve dokunuşları yutar (işlem sürerken
  /// ikinci bir işlem başlatmak belgeyi tutarsız bırakırdı).
  Widget _busyOverlay() {
    return Positioned.fill(
      child: ColoredBox(
        color: AppColors.shade.withValues(alpha: 0.35),
        child: Center(
          child: Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.5)),
                  const SizedBox(width: 16),
                  Text(_busyLabel),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Sayfa ızgarası. **Aynı revizyonda AYNI widget örneği** döner — bkz.
  /// [_selection] açıklaması (yeniden render + başa atma hatasının çözümü).
  Widget _pageGrid(Uint8List bytes) {
    if (_gridCache == null || _gridCacheRev != _rev) {
      _gridCacheRev = _rev;
      final password = _password;
      _gridCache = PdfDocumentViewBuilder(
        // sourceName revizyonu taşır: düzenleme sonrası önizleme tazelensin.
        documentRef: PdfDocumentRefData(
          bytes,
          sourceName: '${widget.path}#$_rev',
          passwordProvider: password == null ? null : () async => password,
        ),
        builder: (context, document) {
          if (document == null) {
            return const Center(child: CircularProgressIndicator());
          }
          final count = document.pages.length;
          return GridView.builder(
            padding: const EdgeInsets.all(12),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 160,
              childAspectRatio: 0.7,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemCount: count,
            itemBuilder: (context, i) => _pageTile(document, i),
          );
        },
      );
    }
    return _gridCache!;
  }

  Widget _pageTile(PdfDocument document, int index) {
    return ValueListenableBuilder<Set<int>>(
      valueListenable: _selection,
      builder: (context, selection, child) {
        final scheme = Theme.of(context).colorScheme;
        final selected = selection.contains(index);
        return InkWell(
          onTap: () {
            final next = Set<int>.from(_selection.value);
            if (!next.remove(index)) next.add(index);
            _selection.value = next;
          },
          child: Column(
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: selected ? scheme.primary : scheme.outlineVariant,
                      width: selected ? 3 : 1,
                    ),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      // child: seçim değişince YENİDEN KURULMAZ — küçük resmin
                      // pdfium render'ı seçim dokunuşunda tekrarlanmasın.
                      child!,
                      // **Dönük sayfa rozeti** (2026-09-04): küçük resim
                      // döndürülmüş hâlini gösteriyor ama sayfanın KENDİ
                      // açısının değiştiği (ve kaydedileceği) hiçbir yerde
                      // yazmıyordu — "döndürdüm mü, döndürmedim mi?" sorusu
                      // ancak kaydedip yeniden açarak cevaplanıyordu.
                      if (document.pages[index].rotation.index != 0)
                        Align(
                          alignment: AlignmentDirectional.topStart,
                          child: Padding(
                            padding: const EdgeInsets.all(4),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 5, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.shade.withValues(alpha: 0.55),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                '${document.pages[index].rotation.index * 90}°',
                                style: context.type.micro.copyWith(
                                    color: AppColors.page,
                                  ),
                              ),
                            ),
                          ),
                        ),
                      if (selected)
                        Align(
                          alignment: AlignmentDirectional.topEnd,
                          child: Padding(
                            padding: const EdgeInsets.all(4),
                            child: Icon(AppIcons.checkCircle,
                                color: scheme.primary, size: 22),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text('${index + 1}',
                  style: Theme.of(context).textTheme.labelMedium),
            ],
          ),
        );
      },
      child: PdfPageView(
        document: document,
        pageNumber: index + 1,
        // Küçük resim: 300 DPI gereksiz bellek yer.
        maximumDpi: 96,
        decoration: const BoxDecoration(color: AppColors.page),
      ),
    );
  }

  Widget _actionBar() {
    return ValueListenableBuilder<Set<int>>(
      valueListenable: _selection,
      builder: (context, selection, _) {
        final has = selection.isNotEmpty;
        final single = selection.length == 1;
        return BottomAppBar(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _barButton(
                  AppIcons.rotateRight,
                  context.t(has ? 'vw.rotate' : 'pt.rotate_all'),
                  _busy ? null : _rotate),
              _barButton(AppIcons.delete, context.t('common.delete'),
                  has && !_busy ? _deleteSelected : null),
              _barButton(AppIcons.split, context.t('pt.extract'),
                  has && !_busy ? _extractSelected : null),
              _barButton(AppIcons.arrowUp, context.t('pt.forward'),
                  single && !_busy ? () => _move(-1) : null),
              _barButton(AppIcons.arrowDown, context.t('pt.backward'),
                  single && !_busy ? () => _move(1) : null),
            ],
          ),
        );
      },
    );
  }

  Widget _barButton(IconData icon, String label, VoidCallback? onTap) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 22, color: onTap == null ? Theme.of(context)
                  .disabledColor : null),
              Text(label,
                  style: context.type.caption.copyWith(
                    color: onTap == null ? Theme.of(context).disabledColor : null,
                  )),
            ],
          ),
        ),
      ),
    );
  }
}
