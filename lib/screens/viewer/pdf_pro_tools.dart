part of '../viewer_screen.dart';

/// **PDF Pro düzenleme kipi — araçlar** (Faz 55–65): yerinde yazma, biçim
/// çubuğu, bağlamsal yongalar, nesne ve işaretleme araçları, bul-değiştir,
/// yorum paneli. Kipin kendisi (giriş/çıkış/kayıt) `pdf_pro_edit.dart`'ta.
extension _ViewerScreenPdfProToolsPart on _ViewerScreenState {
  PdfProLayerEvents get _proEvents => PdfProLayerEvents(
        onEdit: _proBegin,
        onLocked: _proLocked,
        onBlockMenu: _proBlockMenu,
        onCommit: _proDone,
        onRefused: _proRefused,
        onNote: _proAddNote,
        onAnnotTap: _proAnnotTap,
        onTextBox: _proTextBox,
        onSwitch: _proSwitch,
      );

  void _proRefused(Object e) {
    if (!mounted) return;
    _snack(e is PdfEditBridgeRefused && e.glyph
        ? context.t('pse.refused_glyph')
        : context.t('pse.refused'));
  }

  /// Bloğu yerinde yazmaya açar (imleç dokunulan harfte).
  Future<void> _proBegin(int pageIndex, PdfTextBlock block,
      {int? offset, (int, int)? selection}) async {
    final pro = _pro;
    if (pro == null || pro.busy || pro.live != null) return;
    final refused = context.t('pse.refused');
    final ok = await pro.beginEdit(pageIndex, block,
        offset: offset, selection: selection);
    if (!mounted || _pro != pro) return;
    if (!ok) {
      _snack(refused);
      return;
    }
    _proFocus.requestFocus();
    WidgetsBinding.instance.addPostFrameCallback((_) => _proRevealCaret());
  }

  /// Yazarken başka bir bloğa dokunuldu: yazımı uygula, klavyeyi KAPATMADAN
  /// dokunulan bloğa geç (imleç dokunulan harfte). Bloklar uygulamadan sonra
  /// yeniden okunur — eski blok nesnesi bayat olabilir.
  Future<void> _proSwitch(int pageIndex, double x, double y) async {
    final pro = _pro;
    if (pro == null || pro.live == null || pro.busy) return;
    final ok = await _proDone(keepFocus: true);
    if (!ok || !mounted || _pro != pro || pro.live != null) return;
    final block = await pro.editableBlockAt(pageIndex, x, y);
    if (!mounted || _pro != pro) return;
    if (block == null || pro.live != null) {
      _proFocus.unfocus();
      return;
    }
    await _proBegin(pageIndex, block, offset: block.map.offsetAt(x, y));
    if (mounted && _pro == pro && pro.live == null) _proFocus.unfocus();
  }

  /// Yazmayı uygular (✓, dışarı dokunuş). Yazılamayan hâl varsa yazma sürer.
  /// [keepFocus]: başka bloğa geçilecek, klavye kapanmasın.
  Future<bool> _proDone({bool keepFocus = false}) async {
    final pro = _pro;
    final live = pro?.live;
    if (pro == null || live == null) return false;
    if (pro.busy) {
      _proBusyHint();
      return false;
    }
    final refusedGlyph = context.t('pse.refused_glyph');
    final refused = context.t('pse.refused');
    final label = live.block == null
        ? 'pse.step_textbox'
        : live.text.trim().isEmpty
            ? 'pse.step_delete'
            : 'pse.step_paragraph';
    final ok = await pro.commitEdit(label: label);
    if (!mounted) return false;
    if (!ok) {
      _snack(pro.live?.glyphError ?? false ? refusedGlyph : refused);
      return false;
    }
    if (!keepFocus) _proFocus.unfocus();
    _pdfText = '';
    return true;
  }

  /// Uzun süren işlem (büyük taranmış sayfa vb.) sırasında geri/uygula
  /// sessizce yutulmasın: kullanıcı donma sanmasın diye bilgi verilir.
  void _proBusyHint() {
    if (!mounted) return;
    _snack(context.t('pse.busy_wait'));
  }

  /// Klavye açılıp kapanınca (gövde boyu değişmez, PS4) imleç satırı yeniden
  /// klavyenin üstüne getirilir — klavye canlandırması bitince bir kez.
  void _proWatchInset(double inset) {
    if (inset == _proInsetSeen) return;
    _proInsetSeen = inset;
    _proInsetTimer?.cancel();
    if (_pro?.live == null) {
      // Klavye kapandı, yazma bitti: belge sonu payında kalan görünüm
      // (sayfanın altındaki boşluk) sayfa sınırına geri çekilir.
      if (inset == 0) {
        _proInsetTimer = Timer(Motion.medium, () {
          if (!mounted || !_pdfController.isReady) return;
          try {
            final c = _pdfController;
            unawaited(c.goTo(
                c.calcMatrixForClampedToNearestBoundary(c.value,
                    viewSize: c.viewSize),
                duration: Motion.short));
          } catch (_) {
            // Görüntüleyici kapanıyorsa sessizce atla.
          }
        });
      }
      return;
    }
    _proInsetTimer = Timer(Motion.medium, () {
      if (mounted) _proRevealCaret();
    });
  }

  /// Yazarken klavye açıkken belgenin SONUNA eklenen kaydırma payı (belge
  /// birimi): son sayfanın alt satırları da klavyenin üstüne kaydırılabilsin.
  /// KÖK (2026-11-24, kullanıcı ekran görüntüsü): tek sayfalık belgede alt
  /// paragraf klavyenin arkasında kalıyordu — görüntüleyici belge sonundan
  /// öteye kaydırmıyordu.
  EdgeInsets? _proKeyboardRoom(BuildContext context) {
    if (_pro?.live == null) return null;
    final inset = MediaQuery.viewInsetsOf(context).bottom;
    if (inset <= 0) return null;
    final zoom = _pdfController.isReady && _pdfController.currentZoom > 0
        ? _pdfController.currentZoom
        : 1.0;
    return EdgeInsets.only(
        bottom: (inset + PdfEditTokens.formatBar + 96) / zoom);
  }

  /// Yazmayı bırakır (✕, Esc, geri tuşu).
  Future<void> _proCancel() async {
    final pro = _pro;
    if (pro == null || pro.live == null) return;
    await pro.cancelEdit();
    if (mounted) _proFocus.unfocus();
  }

  /// İmleç satırı klavyenin + biçim çubuğunun üstünde kalsın (yakınlaştırma
  /// değişmez; yalnız kaydırılır — etkileşim §4).
  void _proRevealCaret() {
    final live = _pro?.live;
    if (live == null || !mounted) return;
    try {
      final off = live.selEnd;
      final (x0, y0, x1, y1) = live.map.caret(off);
      final rect = _pdfController.calcRectForRectInsidePage(
        pageNumber: live.pageIndex + 1,
        rect: PdfRect(math.min(x0, x1) - 1, math.max(y0, y1),
            math.max(x0, x1) + 1, math.min(y0, y1)),
      );
      final zoom =
          _pdfController.currentZoom <= 0 ? 1.0 : _pdfController.currentZoom;
      final visible = _pdfController.visibleRect;
      final media = MediaQuery.of(context);
      final below =
          (media.viewInsets.bottom + PdfEditTokens.formatBar + 96) / zoom;
      final above = (media.padding.top + PdfEditTokens.topBar + 16) / zoom;
      var shift = 0.0;
      if (rect.bottom > visible.bottom - below) {
        shift = rect.bottom - (visible.bottom - below);
      } else if (rect.top < visible.top + above) {
        shift = rect.top - (visible.top + above);
      }
      if (shift.abs() < 2 / zoom) return;
      _pdfController.goTo(
          _pdfController.value.clone()
            ..leftTranslateByDouble(0, -shift * zoom, 0, 1),
          duration: Motion.short);
    } catch (_) {
      // Görüntüleyici henüz hazır değilse sessizce atla.
    }
  }

  /// Kilitli blok (PK7): neden + seçenekler.
  Future<void> _proLocked(int pageIndex, PdfTextBlock block) async {
    final pro = _pro;
    if (pro == null) return;
    final pick = await showPdfLockedBlockSheet(context,
        lock: block.lock,
        ai: block.lock == PdfBlockLock.invisible && CloudOcr.available);
    if (pick == null || !mounted || _pro != pro) return;
    if (pick == 'line') {
      pro.mode = PdfBlockMode.line;
    } else if (pick == 'replace' || pick == 'ai') {
      await _proReplaceScanned(pageIndex, block, ai: pick == 'ai');
    } else {
      await _proTextBox(pageIndex, block.left, block.top + block.size * 0.4);
    }
  }

  /// Taranmış yazıyı değiştir: eski yazı kâğıt rengiyle örtülür, görünmez
  /// tanıma metni silinir (tek geri alınabilir adım), tanınan (ya da [ai]
  /// ile yapay zekânın okuduğu) metin aynı yerde düzenlenebilir kutuya gelir.
  Future<void> _proReplaceScanned(int pageIndex, PdfTextBlock block,
      {bool ai = false}) async {
    final pro = _pro;
    final doc = _pdfDoc;
    if (pro == null || doc == null || pro.busy || pro.live != null) return;
    if (pageIndex < 0 || pageIndex >= doc.pages.length) return;
    final page = doc.pages[pageIndex];
    final refused = context.t('pse.refused');
    final aiFailed = context.t('pse.ocr_ai_failed');
    String text = block.text.trim();
    if (ai) {
      _snack(context.t('pse.ocr_ai_reading'));
      final read = await PdfScanBlock.aiRead(page, block);
      if (!mounted || _pro != pro) return;
      if (read == null) {
        _snack(aiFailed);
      } else {
        text = read;
      }
    }
    final paper = await PdfScanBlock.paperColor(page, block) ?? 0xFFFFFFFF;
    if (!mounted || _pro != pro || pro.live != null) return;
    final size = block.size.clamp(6.0, 48.0);
    final pad = math.max(1.0, size * 0.2);
    final base =
        block.map.bases.isNotEmpty ? block.map.bases.first : block.top - size;
    try {
      await pro.mutate(pageIndex, [
        PdfMutAction.delete(block.objectIndexes),
        PdfMutAction.shape(PdfShapeKind.rect, block.left - pad,
            block.bottom - pad, block.right + pad, block.top + pad,
            stroke: paper, fill: paper, strokeWidth: 0.5),
      ], label: 'pse.step_ocr_replace');
    } catch (e) {
      _proRefused(e);
      return;
    }
    if (!mounted || _pro != pro) return;
    final ok = await pro.beginTextBox(pageIndex, block.left, base,
        width: math.max(40.0, block.right - block.left), size: size);
    if (!mounted || _pro != pro) return;
    if (!ok) {
      _snack(refused);
      return;
    }
    if (text.isNotEmpty) pro.liveInput(text, text.length, text.length);
    _proFocus.requestFocus();
    WidgetsBinding.instance.addPostFrameCallback((_) => _proRevealCaret());
  }

  Future<void> _proTextBox(int pageIndex, double x, double y) async {
    final pro = _pro;
    if (pro == null || pro.busy || pro.live != null) return;
    pro.armTextBox = false;
    final refused = context.t('pse.refused');
    final ok = await pro.beginTextBox(pageIndex, x, y);
    if (!mounted || _pro != pro) return;
    if (!ok) {
      _snack(refused);
      return;
    }
    _proFocus.requestFocus();
  }

  /// Uzun basış: blok bağlam menüsü.
  Future<void> _proBlockMenu(int pageIndex, PdfTextBlock block) async {
    final pro = _pro;
    if (pro == null || pro.busy) return;
    AppHaptics.selection();
    final pick = await showAppActionSheet<String>(
      context,
      groups: [
        AppActionGroup(actions: [
          if (block.editable)
            AppAction(
                value: 'edit',
                icon: AppIcons.edit,
                label: context.t('common.edit')),
          AppAction(
              value: 'copy', icon: AppIcons.copy, label: context.t('pse.copy')),
          if (block.editable) ...[
            AppAction(
                value: 'dup',
                icon: AppIcons.copyAll,
                label: context.t('pse.duplicate')),
            AppAction(
                value: 'del',
                icon: AppIcons.delete,
                label: context.t('common.delete')),
            AppAction(
                value: 'delup',
                icon: AppIcons.arrowUp,
                label: context.t('pse.delete_pull')),
          ],
          AppAction(
              value: 'mode',
              icon: AppIcons.lines,
              label: context.t(pro.mode == PdfBlockMode.paragraph
                  ? 'pse.mode_line'
                  : 'pse.mode_paragraph')),
        ]),
      ],
    );
    if (pick == null || !mounted || _pro != pro) return;
    await _proBlockAction(pick, pageIndex, block);
  }

  Future<void> _proBlockAction(
      String action, int pageIndex, PdfTextBlock block) async {
    final pro = _pro;
    if (pro == null || pro.busy) return;
    final copied = context.t('pse.copied');
    try {
      switch (action) {
        case 'edit':
          await _proBegin(pageIndex, block);
        case 'copy':
          await pro.copyBlock(pageIndex, block);
          // Dışarıya düz metin (Faz 58 / 5).
          await Clipboard.setData(ClipboardData(text: block.text));
          _snack(copied);
        case 'dup':
          await pro.duplicateBlock(pageIndex, block, label: 'pse.step_duplicate');
        case 'del':
          await pro.deleteBlock(pageIndex, block, label: 'pse.step_delete');
        case 'delup':
          await pro.deleteBlock(pageIndex, block,
              pullUp: true, label: 'pse.step_delete');
        case 'mode':
          pro.mode = pro.mode == PdfBlockMode.paragraph
              ? PdfBlockMode.line
              : PdfBlockMode.paragraph;
        case 'bullets':
          await pro.toggleList(pageIndex, block,
              numbered: false, label: 'pse.step_list');
        case 'numbers':
          await pro.toggleList(pageIndex, block,
              numbered: true, label: 'pse.step_list');
        case 'left' || 'center' || 'right' || 'justify':
          await pro.reshape(pageIndex, block,
              align: PdfBlockAlign.values.byName(action),
              label: 'pse.step_format');
        case 'bigger' || 'smaller':
          await pro.reshape(pageIndex, block,
              size: (block.size + (action == 'bigger' ? 1 : -1))
                  .roundToDouble()
                  .clamp(4, 144)
                  .toDouble(),
              label: 'pse.step_format');
        case 'split':
          if (block.lines.length > 1) {
            pro.splitSelected(block.lines.length ~/ 2);
          }
        case 'merge':
          pro.mergeSelectedWithNext();
        case 'stylecopy':
          pro.styleClip = (
            size: block.size,
            color: block.lines.first.objects.first.fill,
            align: block.align
          );
          _snack(copied);
        case 'stylepaste':
          final s = pro.styleClip;
          if (s != null) {
            await pro.reshape(pageIndex, block,
                size: s.size,
                color: s.color,
                align: s.align,
                label: 'pse.step_format');
          }
        case 'color':
          final c = await showPdfColorSheet(context,
              title: context.t('pse.fmt_color'), colors: PdfProSwatches.text);
          if (c != null && _pro == pro) {
            await pro.reshape(pageIndex, block,
                color: c, label: 'pse.step_format');
          }
        case 'link':
          await _proLink(pro, pageIndex, block);
      }
      _pdfText = '';
    } catch (e) {
      _proRefused(e);
    }
  }

  /// Metne bağlantı ekle/düzenle/kaldır (Faz 58 / 7): web adresi ya da bu
  /// belgedeki bir sayfa.
  Future<void> _proLink(
      PdfProEditController pro, int pageIndex, PdfTextBlock block) async {
    final old = PdfProEditController.linkOver(
        block, await pro.linksOf(pageIndex));
    if (!mounted || _pro != pro) return;
    final bad = context.t('pse.link_bad');
    final pick = await showAppActionSheet<String>(
      context,
      title: context.t('pse.link'),
      subtitle: old == null
          ? null
          : old.destPage >= 0
              ? context.t('pse.link_to_page', {'n': '${old.destPage + 1}'})
              : old.uri,
      groups: [
        AppActionGroup(actions: [
          AppAction(
              value: 'web',
              icon: AppIcons.link,
              label: context.t('pse.link_web')),
          AppAction(
              value: 'page',
              icon: AppIcons.thumbnails,
              label: context.t('pse.link_page')),
          if (old != null)
            AppAction(
                value: 'remove',
                icon: AppIcons.linkOff,
                label: context.t('pse.link_remove'),
                destructive: true),
        ]),
      ],
    );
    if (pick == null || !mounted || _pro != pro) return;
    String? uri;
    if (pick == 'web') {
      final text = await showAppPrompt(context,
          title: context.t('pse.link_web'),
          label: context.t('pse.link_web_hint'),
          initial: old != null && old.destPage < 0 ? old.uri : 'https://');
      if (text == null || !mounted || _pro != pro) return;
      uri = PdfLinkTarget.web(text);
    } else if (pick == 'page') {
      final count = _pdfCount;
      final text = await showAppPrompt(context,
          title: context.t('pse.link_page'),
          label: context.t('pse.link_page_hint', {'n': '$count'}),
          initial: old != null && old.destPage >= 0
              ? '${old.destPage + 1}'
              : '');
      if (text == null || !mounted || _pro != pro) return;
      final n = int.tryParse(text);
      uri = n != null && n >= 1 && n <= count
          ? PdfLinkTarget.page(n - 1)
          : null;
    }
    if (pick != 'remove' && uri == null) {
      _snack(bad);
      return;
    }
    await pro.setBlockLink(pageIndex, block, uri, label: 'pse.step_link');
  }

  /// Kopyalanan bloğu görünen sayfaya yapıştırır (sayfalar arası taşıma).
  Future<void> _proPaste() async {
    final pro = _pro;
    if (pro == null || pro.busy || pro.clip == null) return;
    final page = (_livePdfPage() ?? _pdfPage) - 1;
    final doc = _pdfDoc;
    if (doc == null || page < 0 || page >= doc.pages.length) return;
    try {
      // Görünen alanın üst-ortası (ham sayfa uzayına dönüştürülür).
      final p = doc.pages[page];
      final rawW = p.rotation.index.isOdd ? p.height : p.width;
      final rawH = p.rotation.index.isOdd ? p.width : p.height;
      final pt = Offset(56, p.height * 0.5)
          .toPdfPoint(page: p, scaledPageSize: Size(p.width, p.height));
      final x = pt.x.clamp(24.0, math.max(56.0, rawW - 96)).toDouble();
      final y = pt.y.clamp(24.0, math.max(24.0, rawH - 24)).toDouble();
      await pro.pasteBlock(page, x, y, label: 'pse.step_paste');
    } catch (e) {
      _proRefused(e);
    }
  }

  // ── görsel / nesne ───────────────────────────────────────────────────────
  Future<void> _proInsertImage({PdfPageItem? replace}) async {
    final pro = _pro;
    if (pro == null || pro.busy) return;
    final unreadable = context.t('pe.image_unreadable');
    // Kaynak: dosya/galeri ya da kamera (Faz 59 m.2).
    final source = await showAppSheet<String>(
      context,
      title: context.t('pse.img_add'),
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            key: const ValueKey('pse-img-files'),
            leading: const Icon(AppIcons.image),
            title: Text(ctx.t('pse.img_from_files')),
            onTap: () => Navigator.pop(ctx, 'files'),
          ),
          ListTile(
            key: const ValueKey('pse-img-camera'),
            leading: const Icon(AppIcons.photoCamera),
            title: Text(ctx.t('pse.img_from_camera')),
            onTap: () => Navigator.pop(ctx, 'camera'),
          ),
        ],
      ),
    );
    if (source == null || !mounted || _pro != pro) return;
    final data = source == 'camera'
        ? await PdfProImages.fromCamera().catchError((Object e) {
            _proRefused(e);
            return null;
          })
        : (await AppFilePicker.pickFiles(type: FileType.image, withData: true))
            ?.files
            .single
            .bytes;
    if (data == null || !mounted || _pro != pro) return;
    final im = await PdfProImages.prepare(data);
    if (!mounted || _pro != pro) return;
    if (im == null) {
      _snack(unreadable);
      return;
    }
    final page = replace == null
        ? (_livePdfPage() ?? _pdfPage) - 1
        : (pro.selectedPage ?? 0);
    final doc = _pdfDoc;
    if (doc == null || page < 0 || page >= doc.pages.length) return;
    final p = doc.pages[page];
    final List<double> m;
    if (replace != null) {
      m = replace.matrix;
    } else {
      // Sayfanın ortasına, genişliğin en çok yarısı (ham sayfa boyutlarına göre).
      final rawW = p.rotation.index.isOdd ? p.height : p.width;
      final rawH = p.rotation.index.isOdd ? p.width : p.height;
      final w = math.min(rawW * 0.5, im.width.toDouble());
      final h = w * im.height / im.width;
      m = [w, 0, 0, h, (rawW - w) / 2, (rawH - h) / 2];
    }
    try {
      await pro.mutate(page, [
        if (replace != null) PdfMutAction.delete([replace.index]),
        PdfMutAction.image(im.path, m),
      ], label: replace == null ? 'pse.step_image' : 'pse.step_image_replace');
    } catch (e) {
      _proRefused(e);
    }
  }

  Future<void> _proItemAction(String action) async {
    final pro = _pro;
    final item = pro?.selectedItem;
    final page = pro?.selectedPage;
    if (pro == null || item == null || page == null || pro.busy) return;
    final saved = context.t('pse.image_exported');
    final failed = context.t('pse.refused');
    try {
      switch (action) {
        case 'delete':
          await pro.mutate(page, [PdfMutAction.delete([item.index])],
              label: 'pse.step_delete');
        case 'front':
          await pro.mutate(page, [PdfMutAction.order(item.index, -1)],
              label: 'pse.step_order');
        case 'back':
          await pro.mutate(page, [PdfMutAction.order(item.index, 0)],
              label: 'pse.step_order');
        case 'rotate':
          // Merkez etrafında 90° (saat yönünün tersine).
          final cx = (item.left + item.right) / 2;
          final cy = (item.bottom + item.top) / 2;
          await pro.mutate(page, [
            PdfMutAction.transform([item.index], [0, 1, -1, 0, cx + cy, cy - cx]),
          ], label: 'pse.step_rotate');
        case 'replace':
          await _proInsertImage(replace: item);
        case 'color':
          final c = await showPdfColorSheet(context,
              title: context.t('pse.fmt_color'), colors: PdfProSwatches.text);
          if (c != null && _pro == pro) {
            await pro.mutate(page, [
              PdfMutAction.style([item.index],
                  stroke: item.stroke ? c : 0, fill: item.filled ? c : 0),
            ], label: 'pse.step_format');
          }
        case 'export':
          final px = await PdfEditBridge.imagePixels(pro.document, page, item.index);
          if (px == null) {
            _snack(failed);
            return;
          }
          final png = await PdfProImages.png(px);
          final docs = await DocsHome.resolve();
          final target = p.join(docs.path,
              '${p.basenameWithoutExtension(widget.doc.path)}_gorsel_${DateTime.now().millisecondsSinceEpoch}.png');
          await File(target).writeAsBytes(png, flush: true);
          _snack(saved.replaceAll('{name}', p.basename(target)));
        case 'crop':
          await _proCropImage(page, item);
        case 'resize':
          await _proResizeImage(page, item);
      }
    } catch (e) {
      _proRefused(e);
    }
  }

  /// Seçili görseli veya şekli merkezden hassas ölçek kaydırıcısı / ön ayarlarla boyutlandırır.
  Future<void> _proResizeImage(int page, PdfPageItem item) async {
    final pro = _pro;
    final doc = _pdfDoc;
    if (pro == null || doc == null || page < 0 || page >= doc.pages.length) {
      return;
    }
    final p = doc.pages[page];
    final rawW = p.rotation.index.isOdd ? p.height : p.width;
    final rawH = p.rotation.index.isOdd ? p.width : p.height;
    final scale = await showPdfImageSizeSheet(
      context,
      item: item,
      pageWidth: rawW,
      pageHeight: rawH,
    );
    if (scale == null || (scale - 1).abs() < 0.01 || !mounted || _pro != pro) {
      return;
    }
    final cx = (item.left + item.right) / 2;
    final cy = (item.bottom + item.top) / 2;
    final m = [scale, 0.0, 0.0, scale, cx - scale * cx, cy - scale * cy];
    try {
      await pro.mutate(page, [PdfMutAction.transform([item.index], m)],
          label: 'pse.step_resize');
    } catch (e) {
      _proRefused(e);
    }
  }

  /// Görseli kırpar: kenarlardan yüzde olarak (tutamaçlı levha), pikseller
  /// yeniden yazılır — sayfadaki yeri kırpılan orana göre küçülür.
  Future<void> _proCropImage(int page, PdfPageItem item) async {
    final pro = _pro;
    if (pro == null) return;
    final failed = context.t('pse.refused');
    final px = await PdfEditBridge.imagePixels(pro.document, page, item.index);
    if (!mounted || _pro != pro) return;
    if (px == null) {
      _snack(failed);
      return;
    }
    final crop = await showPdfCropSheet(context);
    if (crop == null || !mounted || _pro != pro) return;
    final (l, t, r, b) = crop;
    final x = (px.width * l).round(), y = (px.height * t).round();
    final w = (px.width * (1 - l - r)).round();
    final h = (px.height * (1 - t - b)).round();
    if (w < 2 || h < 2) return;
    final png = await PdfProImages.png(px, left: x, top: y, width: w, height: h);
    final im = await PdfProImages.prepare(png);
    if (im == null || !mounted || _pro != pro) return;
    // Yerleşim: özgün matrisin birim karesinde kırpılan dikdörtgen.
    final m = item.matrix;
    final sx = 1 - l - r, sy = 1 - t - b;
    final nm = [
      m[0] * sx, m[1] * sx, m[2] * sy, m[3] * sy, //
      m[4] + m[0] * l + m[2] * b, m[5] + m[1] * l + m[3] * b,
    ];
    try {
      await pro.mutate(page, [
        PdfMutAction.delete([item.index]),
        PdfMutAction.image(im.path, nm),
      ], label: 'pse.step_crop');
    } catch (e) {
      _proRefused(e);
    }
  }

  // ── işaretleme ───────────────────────────────────────────────────────────
  Future<void> _proAddNote(int pageIndex, double x, double y) async {
    final pro = _pro;
    if (pro == null || pro.busy) return;
    final text = await showAppPrompt(context,
        title: context.t('pse.mk_note'), multiline: true);
    if (text == null || text.trim().isEmpty || !mounted || _pro != pro) return;
    try {
      await pro.annotate(
          PdfAnnotChange.add(pageIndex, PdfAnnotType.text,
              rect: [x - 10, y - 10, x + 10, y + 10],
              color: pro.markupColor | 0xFF000000,
              contents: text.trim()),
          label: 'pse.step_note',
          detail: text.trim());
    } catch (e) {
      _proRefused(e);
    }
  }

  Future<void> _proAnnotTap(int pageIndex, PdfAnnotInfo annot) async {
    final pro = _pro;
    if (pro == null || pro.busy) return;
    final pick = await showAppActionSheet<String>(
      context,
      title: pdfAnnotTypeLabel(context, annot.subtype),
      subtitle: annot.contents.isEmpty ? null : annot.contents,
      groups: [
        AppActionGroup(actions: [
          AppAction(
              value: 'note',
              icon: AppIcons.editNote,
              label: context.t('pse.comment_edit')),
          AppAction(
              value: 'color',
              icon: AppIcons.palette,
              label: context.t('pse.fmt_color')),
          AppAction(
              value: 'delete',
              icon: AppIcons.delete,
              label: context.t('common.delete')),
        ]),
      ],
    );
    if (pick == null || !mounted || _pro != pro) return;
    try {
      switch (pick) {
        case 'note':
          final text = await showAppPrompt(context,
              title: context.t('pse.comment_edit'),
              initial: annot.contents,
              multiline: true);
          if (text != null && _pro == pro) {
            await pro.annotate(
                PdfAnnotChange.update(pageIndex, annot.index, contents: text),
                label: 'pse.step_note');
          }
        case 'color':
          final c = await showPdfColorSheet(context,
              title: context.t('pse.fmt_color'), colors: PdfProSwatches.marker);
          if (c != null && _pro == pro) {
            await pro.annotate(
                PdfAnnotChange.update(pageIndex, annot.index,
                    color: c | 0xFF000000),
                label: 'pse.step_markup');
          }
        case 'delete':
          await pro.annotate(PdfAnnotChange.remove(pageIndex, annot.index),
              label: 'pse.step_markup_remove');
      }
    } catch (e) {
      _proRefused(e);
    }
  }

  Future<void> _proMarkupColor() async {
    final pro = _pro;
    if (pro == null) return;
    final ink = pro.markup == PdfMarkupKind.ink ||
        pro.markup.index >= PdfMarkupKind.rect.index;
    await showPdfStrokeSheet(
      context,
      color: pro.markupColor,
      width: pro.markupWidth,
      colors: ink ? PdfProSwatches.text : PdfProSwatches.marker,
      onColor: (c) {
        if (_pro == pro) pro.setMarkupColor(c);
      },
      onWidth: (w) {
        if (_pro == pro) pro.setMarkupWidth(w);
      },
    );
  }

  Future<void> _proComments() async {
    final pro = _pro;
    if (pro == null) return;
    await showPdfCommentsSheet(context, controller: pro, onGoTo: (a) {
      if (_pdfCount > 0) _goToPdfPage(a.pageIndex + 1, _pdfCount);
      pro
        ..tool = PdfProTool.markup
        ..selectAnnot(a.pageIndex, a);
    });
  }

  Future<void> _proFlatten() async {
    final pro = _pro;
    if (pro == null || pro.busy) return;
    final page = (_livePdfPage() ?? _pdfPage) - 1;
    final ok = await showAppConfirm(context,
        title: context.t('pse.flatten'),
        message: context.t('pse.flatten_q'),
        confirmLabel: context.t('pse.flatten'));
    if (!ok || !mounted || _pro != pro) return;
    try {
      await pro.mutate(page, const [PdfMutAction.flatten()],
          label: 'pse.step_flatten');
    } catch (e) {
      _proRefused(e);
    }
  }

  /// Kişisel verileri bul → önizle → onayla → karart (Faz 64 / 2).
  Future<void> _proSensitive() async {
    final pro = _pro;
    if (pro == null || pro.busy) return;
    final done = context.t('pse.kvkk_done');
    final hits = await showPdfSensitiveSheet(context, controller: pro);
    if (hits == null || hits.isEmpty || !mounted || _pro != pro) return;
    final ok = await showAppConfirm(context,
        title: context.t('pse.mk_redact'),
        message: context.t('pse.redact_q'),
        confirmLabel: context.t('pse.mk_redact'));
    if (!ok || !mounted || _pro != pro) return;
    try {
      final n = await pro.redact(hits, label: 'pse.step_redact');
      _pdfText = '';
      _snack(done.replaceAll('{n}', '$n'));
    } catch (e) {
      _proRefused(e);
    }
  }

  Future<void> _proFindReplace() async {
    final pro = _pro;
    if (pro == null) return;
    await showPdfFindReplaceSheet(context, controller: pro, onGoTo: (h) {
      if (_pdfCount > 0) _goToPdfPage(h.pageIndex + 1, _pdfCount);
      pro
        ..tool = PdfProTool.text
        ..select(h.pageIndex, h.block);
    });
    _pdfText = '';
  }

  Future<void> _proPickTextColor({required bool highlight}) async {
    final pro = _pro;
    if (pro == null || pro.live == null) return;
    final c = await showPdfColorSheet(context,
        title: context.t(highlight ? 'pse.fmt_highlight' : 'pse.fmt_color'),
        colors: highlight ? PdfProSwatches.marker : PdfProSwatches.text);
    if (c == null || _pro != pro || pro.live == null) return;
    pro.liveStyleBlock((a, b) => highlight
        ? PdfStyleSpan(a, b, highlight: c)
        : PdfStyleSpan(a, b, color: c | 0xFF000000));
    _proFocus.requestFocus();
  }

  /// Yazı tipi seçici (Faz 56 / 7): belge fontları → eşleşen aile → paket.
  Future<void> _proPickFont() async {
    final pro = _pro;
    final live = pro?.live;
    if (pro == null || live == null) return;
    final id = await showPdfFontSheet(context,
        choices: pro.fontChoices(),
        selected: live.fontAt(math.min(live.selStart, live.selEnd)));
    if (id == null || _pro != pro || pro.live == null) return;
    pro.liveFont(id);
    _proFocus.requestFocus();
  }

  // ── AI (Faz 65) ──────────────────────────────────────────────────────────
  /// Seçili paragrafı AI ile yerinde yeniden yazar: sonuç önce öneri olarak
  /// gösterilir (eski ↔ yeni), kabul = tek geri alınabilir adım. Blok seçili
  /// değilse belge geneli AI düzenlemeye yönlendirir.
  Future<void> _proAi() async {
    final pro = _pro;
    if (pro == null || pro.busy) return;
    final block = pro.selected;
    final page = pro.selectedPage;
    if (block == null || page == null || !block.editable) {
      final whole = await showAppConfirm(context,
          title: context.t('pse.tool_ai'),
          message: context.t('pse.ai_pick_block'),
          confirmLabel: context.t('pse.ai_whole'));
      if (whole && mounted) await _aiEditPdf();
      return;
    }
    final pick = await showAppActionSheet<PdfAiMode>(
      context,
      title: context.t('pse.tool_ai'),
      groups: [
        AppActionGroup(actions: [
          AppAction(
              value: PdfAiMode.rewrite,
              icon: AppIcons.autoFixNormal,
              label: context.t('pse.ai_rewrite')),
          AppAction(
              value: PdfAiMode.shorten,
              icon: AppIcons.shortText,
              label: context.t('pse.ai_shorten')),
          AppAction(
              value: PdfAiMode.formal,
              icon: AppIcons.badge,
              label: context.t('pse.ai_formal')),
          AppAction(
              value: PdfAiMode.grammar,
              icon: AppIcons.spellcheck,
              label: context.t('pse.ai_grammar')),
          AppAction(
              value: PdfAiMode.translate,
              icon: AppIcons.translate,
              label: context.t('pse.ai_translate')),
        ]),
      ],
    );
    if (pick == null || !mounted || _pro != pro) return;
    String? language;
    if (pick == PdfAiMode.translate) {
      language = await showAppActionSheet<String>(
        context,
        title: context.t('pse.ai_translate'),
        groups: [
          AppActionGroup(actions: [
            for (final l in const ['Türkçe', 'English', 'العربية', 'Deutsch', 'Français'])
              AppAction(value: l, icon: AppIcons.translate, label: l),
          ]),
        ],
      );
      if (language == null || !mounted || _pro != pro) return;
    }
    if (!await ensureAiKey(context) || !mounted || _pro != pro) return;
    final failed = context.t('pse.ai_failed');
    final same = context.t('pse.ai_same');
    final gemini = context.read<AppState>().gemini;
    final original = block.text;
    String? suggestion;
    try {
      _snack(context.t('pse.ai_working'));
      suggestion =
          await PdfAiRewrite.run(gemini, original, pick, language: language);
    } catch (e) {
      _snack(failed.replaceAll('{error}', userErrorText(e)));
      return;
    }
    if (!mounted || _pro != pro) return;
    if (suggestion == null || suggestion.trim() == original.trim()) {
      _snack(same);
      return;
    }
    final accept = await showPdfSuggestionSheet(context,
        before: original, after: suggestion);
    if (accept != true || !mounted || _pro != pro) return;
    try {
      await pro.replace(page, block, suggestion, label: 'pse.step_ai');
      _pdfText = '';
    } catch (e) {
      _proRefused(e);
    }
  }

  // ── çubuklar ─────────────────────────────────────────────────────────────
  /// Alt araç çubuğu (etkileşim §5): Metin · Görsel · İşaretle · İmza · Form ·
  /// Sayfalar · Daha fazla. Okuma kipindeki çubukla aynı yükseklikte — gövde
  /// payı değişmez.
  Widget _proToolBar(PdfProEditController pro) {
    Future<void> commitThen(FutureOr<void> Function() fn) async {
      if (pro.live != null) {
        await _proDone();
        if (pro.live != null || !mounted || _pro != pro) return;
      }
      await fn();
    }

    DocAction tool(PdfProTool t, IconData icon, String key) => DocAction(
        icon,
        context.t(key),
        pro.busy ? null : () => unawaited(commitThen(() => pro.tool = t)),
        active: pro.tool == t);
    return DocActionBar([
      tool(PdfProTool.text, AppIcons.textFields, 'pse.tool_text'),
      tool(PdfProTool.image, AppIcons.image, 'pse.tool_image'),
      tool(PdfProTool.markup, AppIcons.highlighter, 'pse.tool_markup'),
      DocAction(AppIcons.draw, context.t('pse.tool_sign'),
          pro.busy ? null : () => unawaited(commitThen(_signPdf))),
      DocAction(AppIcons.formView, context.t('pse.tool_form'),
          pro.busy ? null : () => unawaited(commitThen(_fillPdfForm))),
      DocAction(AppIcons.thumbnails, context.t('pse.tool_pages'),
          pro.busy ? null : () => unawaited(commitThen(_proPages))),
    ]);
  }

  /// Sayfalar: görünen sayfayı döndür (geri alınabilir) ya da sayfa
  /// stüdyosuna (sırala/ekle/sil/böl/birleştir) geç.
  Future<void> _proPages() async {
    final pro = _pro;
    if (pro == null || pro.busy) return;
    final pick = await showAppActionSheet<String>(
      context,
      groups: [
        AppActionGroup(actions: [
          AppAction(
              value: 'rotate',
              icon: AppIcons.rotateRight,
              label: context.t('pse.page_rotate')),
          AppAction(
              value: 'studio',
              icon: AppIcons.thumbnails,
              label: context.t('pse.page_studio'),
              hint: context.t('pse.page_studio_hint')),
        ]),
      ],
    );
    if (pick == null || !mounted || _pro != pro) return;
    if (pick == 'studio') {
      await _openPdfTools();
      return;
    }
    final page = (_livePdfPage() ?? _pdfPage) - 1;
    try {
      await pro.rotatePage(page, label: 'pse.step_rotate');
    } catch (e) {
      _proRefused(e);
    }
  }

  List<PdfProChip> _proChips(PdfProEditController pro) {
    String t(String k) => context.t(k);
    final block = pro.selected;
    final page = pro.selectedPage;
    switch (pro.tool) {
      case PdfProTool.text:
        if (block != null && page != null) {
          PdfProChip act(IconData i, String label, String a,
                  {bool danger = false, Key? key}) =>
              PdfProChip(i, label, () => _proBlockAction(a, page, block),
                  danger: danger, tapKey: key);
          if (!block.editable) {
            return [
              act(AppIcons.copy, t('pse.copy'), 'copy'),
              PdfProChip(AppIcons.info, t('pse.locked_why'),
                  () => _proLocked(page, block)),
            ];
          }
          return [
            PdfProChip(AppIcons.edit, t('pse.edit_text'),
                () => _proBlockAction('edit', page, block),
                primary: true, tapKey: const ValueKey('pse-chip-edit')),
            PdfProChip(
              AppIcons.tune,
              t('pse.style'),
              () => unawaited(showPdfBlockStyleSheet(
                context,
                block: block,
                hasStyleClip: pro.styleClip != null,
                onAction: (a) => _proBlockAction(a, page, block),
              )),
              tapKey: const ValueKey('pse-chip-style'),
            ),
            act(AppIcons.formatColorText, t('pse.fmt_color'), 'color',
                key: const ValueKey('pse-chip-color')),
            act(AppIcons.copy, t('pse.copy'), 'copy',
                key: const ValueKey('pse-chip-copy')),
            act(AppIcons.copyAll, t('pse.duplicate'), 'dup',
                key: const ValueKey('pse-chip-dup')),
            act(AppIcons.delete, t('common.delete'), 'del',
                danger: true, key: const ValueKey('pse-chip-delete')),
            PdfProChip(AppIcons.moreHoriz, t('pse.block_more'),
                () => _proBlockMenu(page, block),
                tapKey: const ValueKey('pse-chip-more')),
          ];
        }
        // Metin yok (taranmış sayfa): OCR ve metin kutusu önerilir (§9).
        final shown = (_livePdfPage() ?? _pdfPage) - 1;
        final scanned = pro.blocksOf(shown)?.isEmpty ?? false;
        return [
          if (scanned)
            PdfProChip(AppIcons.ocr, t('pse.ocr_run'),
                () => _runOcr(onlyPage: shown + 1),
                tapKey: const ValueKey('pse-chip-ocr')),
          PdfProChip(AppIcons.textFields, t('pse.add_text'),
              () => pro.armTextBox = !pro.armTextBox,
              active: pro.armTextBox,
              tapKey: const ValueKey('pse-chip-textbox')),
          PdfProChip(
              AppIcons.lines,
              t(pro.mode == PdfBlockMode.paragraph
                  ? 'pse.mode_label_para'
                  : 'pse.mode_label_line'),
              () => pro.mode = pro.mode == PdfBlockMode.paragraph
                  ? PdfBlockMode.line
                  : PdfBlockMode.paragraph,
              active: pro.mode == PdfBlockMode.line,
              tapKey: const ValueKey('pse-chip-mode')),
          PdfProChip(AppIcons.findReplace, t('pse.find_title'), _proFindReplace,
              tapKey: const ValueKey('pse-chip-find')),
          if (pro.clip != null)
            PdfProChip(AppIcons.paste, t('pse.paste'), _proPaste),
        ];
      case PdfProTool.image:
        final item = pro.selectedItem;
        final group = pro.selectedItems;
        if (group.length >= 2) {
          return [
            PdfProChip(
              AppIcons.alignHorizontalLeft,
              t('pse.align_group'),
              () => unawaited(_proPickGroupAlign(pro, group.length)),
              tapKey: const ValueKey('pse-chip-align-group'),
            ),
            PdfProChip(AppIcons.delete, t('common.delete'), () {
              final page = pro.selectedPage;
              if (page == null || pro.busy) return;
              pro
                  .mutate(page,
                      [PdfMutAction.delete([for (final i in group) i.index])],
                      label: 'pse.step_delete')
                  .catchError(_proRefused);
            }, danger: true),
          ];
        }
        if (item != null) {
          return [
            if (item.isImage) ...[
              PdfProChip(AppIcons.image, t('pse.img_replace'),
                  () => _proItemAction('replace'),
                  primary: true, tapKey: const ValueKey('pse-chip-replace')),
              PdfProChip(AppIcons.sizeScale, t('pse.resize'),
                  () => _proItemAction('resize'),
                  tapKey: const ValueKey('pse-chip-resize')),
              PdfProChip(
                  AppIcons.crop, t('pse.img_crop'), () => _proItemAction('crop')),
              PdfProChip(AppIcons.rotateRight, t('pse.img_rotate'),
                  () => _proItemAction('rotate')),
              PdfProChip(
                AppIcons.flipToFront,
                t('pse.order'),
                () => unawaited(_proPickItemOrder()),
                tapKey: const ValueKey('pse-chip-order'),
              ),
              PdfProChip(AppIcons.download, t('pse.img_export'),
                  () => _proItemAction('export')),
            ] else ...[
              PdfProChip(AppIcons.palette, t('pse.fmt_color'),
                  () => _proItemAction('color'),
                  primary: true),
              PdfProChip(AppIcons.sizeScale, t('pse.resize'),
                  () => _proItemAction('resize'),
                  tapKey: const ValueKey('pse-chip-resize')),
              PdfProChip(AppIcons.rotateRight, t('pse.img_rotate'),
                  () => _proItemAction('rotate')),
              PdfProChip(
                AppIcons.flipToFront,
                t('pse.order'),
                () => unawaited(_proPickItemOrder()),
                tapKey: const ValueKey('pse-chip-order'),
              ),
            ],
            PdfProChip(AppIcons.delete, t('common.delete'),
                () => _proItemAction('delete'),
                danger: true),
          ];
        }
        return [
          PdfProChip(AppIcons.addPhoto, t('pse.img_add'), _proInsertImage,
              primary: true, tapKey: const ValueKey('pse-chip-image')),
          PdfProChip(AppIcons.lasso, t('pse.obj_lasso'),
              () => pro.armLasso = !pro.armLasso,
              active: pro.armLasso, tapKey: const ValueKey('pse-chip-lasso')),
        ];
      case PdfProTool.markup:
        PdfProChip kind(PdfMarkupKind k, IconData i, String key) =>
            PdfProChip(i, t(key), () => pro.markup = k,
                active: pro.markup == k, tapKey: ValueKey('pse-mk-${k.name}'));
        const shapes = <(PdfMarkupKind, IconData, String)>[
          (PdfMarkupKind.rect, AppIcons.rectTool, 'pse.mk_rect'),
          (PdfMarkupKind.ellipse, AppIcons.ellipseTool, 'pse.mk_ellipse'),
          (PdfMarkupKind.line, AppIcons.lineTool, 'pse.mk_line'),
          (PdfMarkupKind.arrow, AppIcons.arrowTool, 'pse.mk_arrow'),
        ];
        const textLines = <(PdfMarkupKind, IconData, String)>[
          (PdfMarkupKind.underline, AppIcons.formatUnderlined, 'pse.mk_underline'),
          (PdfMarkupKind.strikeout, AppIcons.strikethroughS, 'pse.mk_strikeout'),
          (PdfMarkupKind.squiggly, AppIcons.gesture, 'pse.mk_squiggly'),
        ];
        final activeShape = shapes.where((e) => e.$1 == pro.markup).firstOrNull;
        final activeLine =
            textLines.where((e) => e.$1 == pro.markup).firstOrNull;
        return [
          PdfProChip(
            AppIcons.lineWeight,
            t('pse.stroke_title'),
            _proMarkupColor,
            swatch: Color(pro.markupColor | 0xFF000000),
            tapKey: const ValueKey('pse-chip-stroke'),
          ),
          kind(PdfMarkupKind.highlight, AppIcons.highlighter, 'pse.mk_highlight'),
          kind(PdfMarkupKind.ink, AppIcons.draw, 'pse.mk_ink'),
          kind(PdfMarkupKind.eraser, AppIcons.eraser, 'pse.mk_eraser'),
          PdfProChip(
            activeShape?.$2 ?? AppIcons.rectTool,
            t(activeShape?.$3 ?? 'pse.shapes'),
            () => unawaited(_proPickMarkupKind(pro, 'pse.shapes', shapes)),
            active: activeShape != null,
            tapKey: const ValueKey('pse-chip-shapes'),
          ),
          PdfProChip(
            activeLine?.$2 ?? AppIcons.formatUnderlined,
            t(activeLine?.$3 ?? 'pse.text_lines'),
            () => unawaited(
                _proPickMarkupKind(pro, 'pse.text_lines', textLines)),
            active: activeLine != null,
            tapKey: const ValueKey('pse-chip-lines'),
          ),
          kind(PdfMarkupKind.note, AppIcons.addComment, 'pse.mk_note'),
          kind(PdfMarkupKind.redact, AppIcons.pdfRedact, 'pse.mk_redact'),
          PdfProChip(AppIcons.shield, t('pse.kvkk_title'), _proSensitive,
              tapKey: const ValueKey('pse-chip-kvkk')),
          PdfProChip(AppIcons.comment, t('pse.comments'), _proComments,
              tapKey: const ValueKey('pse-chip-comments')),
          PdfProChip(AppIcons.pdfFlatten, t('pse.flatten'), _proFlatten,
              tapKey: const ValueKey('pse-chip-flatten')),
        ];
      default:
        return const [];
    }
  }

  PdfProFormatLabels get _proFormatLabels => PdfProFormatLabels(
        done: context.t('pse.done'),
        cancel: context.t('common.cancel'),
        bold: context.t('pse.fmt_bold'),
        italic: context.t('pse.fmt_italic'),
        underline: context.t('pse.fmt_underline'),
        strike: context.t('pse.fmt_strike'),
        color: context.t('pse.fmt_color'),
        highlight: context.t('pse.fmt_highlight'),
        align: context.t('pse.fmt_align'),
        smaller: context.t('pse.fmt_smaller'),
        larger: context.t('pse.fmt_larger'),
        selectAll: context.t('pse.select_all'),
        copy: context.t('pse.copy'),
        cut: context.t('pse.cut'),
        paste: context.t('pse.paste'),
        docFont: context.t('pse.font_doc'),
        fallbackFont: context.t('pse.font_fallback'),
        glyphError: context.t('pse.refused_glyph'),
        error: context.t('pse.refused'),
        size: context.t('pse.fmt_size'),
        overflow: context.t('pse.overflow'),
        shrink: context.t('pse.overflow_shrink'),
        push: context.t('pse.overflow_push'),
        widen: context.t('pse.overflow_widen'),
      );

  /// Düzenleme kipinin gövde üstü katmanları: bağlamsal çubuk, yazarken
  /// klavye üstü biçim çubuğu ve gizli giriş alanı. Hepsi gövdenin ÜSTÜNDE
  /// yüzer; gövde boyu değişmez (PS4).
  List<Widget> _proOverlays(PdfProEditController pro) {
    final live = pro.live;
    final inset = MediaQuery.viewInsetsOf(context).bottom;
    _proWatchInset(inset);
    if (live != null) {
      final bar = PdfProFormatBar(
        controller: pro,
        labels: _proFormatLabels,
        input: _proInput,
        onDone: _proDone,
        onCancel: _proCancel,
        onPickColor: () => _proPickTextColor(highlight: false),
        onPickHighlight: () => _proPickTextColor(highlight: true),
        onPickFont: _proPickFont,
      );
      return [
        PositionedDirectional(
          start: 0,
          top: 0,
          child: PdfProTextInput(
            controller: pro,
            input: _proInput,
            focusNode: _proFocus,
            onEscape: _proCancel,
            onUndo: _proUndo,
            onRedo: _proRedo,
          ),
        ),
        if (inset > 0)
          PositionedDirectional(start: 0, end: 0, bottom: inset, child: bar)
        else
          ReadingFloat(gap: 0, child: ToastAvoider(child: bar)),
      ];
    }
    final chips = _proChips(pro);
    final guide = _proGuideBanner(pro);
    return [
      ?guide,
      if (chips.isNotEmpty)
        ReadingFloat(
          gap: 0,
          child: ToastAvoider(
            child: PdfProContextBar(
                chips: chips, label: context.t('pse.context_bar')),
          ),
        ),
    ];
  }

  /// Blok menüsünden veya çoklu seçimden açılan yardımcı levhalar + aktif mod
  /// rehber şeridi.
  Future<void> _proPickGroupAlign(
      PdfProEditController pro, int count) async {
    final choices = <(PdfAxisAlign, bool, IconData, String)>[
      (PdfAxisAlign.start, false, AppIcons.alignHorizontalLeft,
          'pse.obj_align_left'),
      (PdfAxisAlign.center, false, AppIcons.alignHorizontalCenter,
          'pse.obj_align_hcenter'),
      (PdfAxisAlign.end, false, AppIcons.alignHorizontalRight,
          'pse.obj_align_right'),
      (PdfAxisAlign.end, true, AppIcons.alignVerticalTop, 'pse.obj_align_top'),
      (PdfAxisAlign.center, true, AppIcons.alignVerticalCenter,
          'pse.obj_align_vcenter'),
      (PdfAxisAlign.start, true, AppIcons.alignVerticalBottom,
          'pse.obj_align_bottom'),
      if (count >= 3) ...[
        (PdfAxisAlign.distribute, false, AppIcons.horizontalDistribute,
            'pse.obj_distribute_h'),
        (PdfAxisAlign.distribute, true, AppIcons.verticalDistribute,
            'pse.obj_distribute_v'),
      ],
    ];
    final pick = await showAppActionSheet<int>(
      context,
      title: context.t('pse.align_group'),
      groups: [
        AppActionGroup(actions: [
          for (var i = 0; i < choices.length; i++)
            AppAction(
                value: i,
                icon: choices[i].$3,
                label: context.t(choices[i].$4)),
        ]),
      ],
    );
    if (pick == null || !mounted || _pro != pro || pro.busy) return;
    final (_, vertical, _, _) = choices[pick];
    final mode = choices[pick].$1;
    await pro
        .alignSelected(mode, vertical: vertical, label: 'pse.step_align')
        .catchError(_proRefused);
  }

  Future<void> _proPickItemOrder() async {
    final pick = await showAppActionSheet<String>(
      context,
      title: context.t('pse.order'),
      groups: [
        AppActionGroup(actions: [
          AppAction(
              value: 'front',
              icon: AppIcons.flipToFront,
              label: context.t('pse.img_front')),
          AppAction(
              value: 'back',
              icon: AppIcons.flipToBack,
              label: context.t('pse.img_back')),
        ]),
      ],
    );
    if (pick == null || !mounted) return;
    await _proItemAction(pick);
  }

  Future<void> _proPickMarkupKind(
    PdfProEditController pro,
    String titleKey,
    List<(PdfMarkupKind, IconData, String)> options,
  ) async {
    final pick = await showAppActionSheet<PdfMarkupKind>(
      context,
      title: context.t(titleKey),
      groups: [
        AppActionGroup(actions: [
          for (final (k, ic, labelKey) in options)
            AppAction(value: k, icon: ic, label: context.t(labelKey)),
        ]),
      ],
    );
    if (pick == null || !mounted || _pro != pro) return;
    pro.markup = pick;
  }

  /// Geçerli sayfadaki seçilebilir görsel/şekil sayısı (keşif çubuğu için).
  int? _proSelectableCount(PdfProEditController pro) {
    final page = (_livePdfPage() ?? _pdfPage) - 1;
    final content = pro.contentOf(page);
    final doc = _pdfDoc;
    if (content == null || doc == null || page < 0 || page >= doc.pages.length) {
      return null;
    }
    final p = doc.pages[page];
    final pageW = p.width, pageH = p.height;
    return content.items
        .where((it) =>
            !it.mark.startsWith('DO') &&
            !(it.isPath &&
                it.width > pageW * 0.95 &&
                it.height > pageH * 0.95))
        .length;
  }

  Widget? _proGuideBanner(PdfProEditController pro) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final dark = theme.brightness == Brightness.dark;
    String? text;
    String? badge;
    Color dotColor = scheme.primary;
    VoidCallback? close;
    if (pro.armTextBox) {
      text = context.t('pse.textbox_guide');
      close = () => pro.armTextBox = false;
    } else if (pro.armLasso) {
      text = context.t('pse.lasso_guide');
      close = () => pro.armLasso = false;
    } else if (pro.drawing) {
      final toolName = context.t(switch (pro.markup) {
        PdfMarkupKind.highlight => 'pse.mk_highlight',
        PdfMarkupKind.underline => 'pse.mk_underline',
        PdfMarkupKind.strikeout => 'pse.mk_strikeout',
        PdfMarkupKind.squiggly => 'pse.mk_squiggly',
        PdfMarkupKind.ink => 'pse.mk_ink',
        PdfMarkupKind.rect => 'pse.mk_rect',
        PdfMarkupKind.ellipse => 'pse.mk_ellipse',
        PdfMarkupKind.line => 'pse.mk_line',
        PdfMarkupKind.arrow => 'pse.mk_arrow',
        PdfMarkupKind.redact => 'pse.mk_redact',
        _ => 'pse.tool_markup',
      });
      text = context.t('pse.draw_guide', {'tool': toolName});
      close = pro.clearMarkup;
    } else if (pro.tool == PdfProTool.image &&
        pro.selectedItem == null &&
        pro.selectedItems.isEmpty) {
      final n = _proSelectableCount(pro);
      dotColor = PdfEditTokens.imageAccent(dark);
      if (n == 0) {
        text = context.t('pse.obj_none_hint');
      } else if (n != null && n > 0) {
        badge = context.t('pse.obj_count', {'n': n});
        text = context.t('pse.obj_guide');
      }
    } else if (pro.tool == PdfProTool.text && pro.selected != null) {
      text = context.t('pse.text_guide_rich');
    }
    if (text == null) return null;
    return PositionedDirectional(
      start: Gap.md,
      end: Gap.md,
      top: ReadingChrome.insetsOf(context).top + Gap.sm,
      child: Center(
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: AppColors.studioShadow(dark),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Material(
            color: scheme.surfaceContainerLowest.withValues(alpha: 0.96),
            shape: StadiumBorder(
              side: BorderSide(
                color: dotColor.withValues(alpha: 0.42),
              ),
            ),
            child: Padding(
              padding: EdgeInsetsDirectional.fromSTEB(
                12,
                close == null ? 7 : 4,
                close == null ? 14 : 4,
                close == null ? 7 : 4,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: dotColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (badge != null) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 2),
                      decoration: ShapeDecoration(
                        color: dotColor.withValues(alpha: dark ? 0.25 : 0.14),
                        shape: const StadiumBorder(),
                      ),
                      child: Text(
                        badge,
                        style: context.type.micro.copyWith(
                          color: dotColor,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(width: 7),
                  ],
                  Flexible(
                    child: Text(
                      text,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.type.small.copyWith(
                        color: scheme.onSurface,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (close != null) ...[
                    const SizedBox(width: 4),
                    IconButton(
                      key: const ValueKey('pse-guide-close'),
                      visualDensity: VisualDensity.compact,
                      iconSize: 18,
                      color: scheme.onSurfaceVariant,
                      tooltip: context.t('common.close'),
                      onPressed: close,
                      icon: const Icon(AppIcons.close),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
