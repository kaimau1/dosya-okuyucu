part of '../image_edit_screen.dart';

/// Boyut ve kırpma (A4.1 bölmesi, davranış aynı).
extension _ImageEditCrop on _ImageEditScreenState {
  // ── boyut (Faz 14b) ─────────────────────────────────────────────────────────

  void _syncSizeFields() {
    final out = outputSize(_src!, _e);
    _widthCtl.text = '${out.width.round()}';
    _heightCtl.text = '${out.height.round()}';
  }

  void _setScale(double scale) {
    final cropped = croppedSize(_src!, _e);
    // En az 16 px kısa kenar; büyütme yok (netlik katmaz, boyutlandırma
    // levhasında %100 üstü uyarılı ayrı yol).
    final minScale = 16 / math.min(cropped.width, cropped.height);
    final clamped = scale.clamp(math.min(minScale, 1.0), 1.0).toDouble();
    if ((clamped - _e.scale).abs() < 1e-6) {
      _syncSizeFields();
      return;
    }
    _push(_e.copyWith(scale: clamped));
    _syncSizeFields();
  }

  void _readSizeField(bool width) {
    final v = int.tryParse((width ? _widthCtl : _heightCtl).text.trim());
    if (v == null || v <= 0) return;
    final cropped = croppedSize(_src!, _e);
    final scale = v / (width ? cropped.width : cropped.height);
    final clamped = scale.clamp(0.0, 1.0);
    _history.push(_e);
    _update(() => _e = _e.copyWith(scale: clamped));
    // Oran hep kilitli: öteki alan anında hesaplanır.
    final out = outputSize(_src!, _e);
    (width ? _heightCtl : _widthCtl).text =
        '${(width ? out.height : out.width).round()}';
  }

  /// Seçim (ölçek) değişince önizleme + dosya boyu, durulunca BİR kez
  /// (B21: "%75/%50/%25 seçince hiçbir fark yok, anlaşılmıyor").
  void _scheduleSizePreview() {
    if (identical(_sizeReq, _e)) return;
    final e = _sizeReq = _e;
    // Büyütecin kapladığı çıktı pikseli: yalnız orta parça tutulur (tam
    // çıktı 8192² olabilir — bellekte bekletilmez).
    final side = (_ImageEditScreenState._loupe *
            MediaQuery.devicePixelRatioOf(context) *
            e.scale)
        .ceil();
    _sizeTimer?.cancel();
    _sizeTimer = Timer(Motion.previewDefer, () async {
      final src = _src;
      if (src == null || !mounted) return;
      try {
        final out = await renderEdits(src, e);
        final (bytes, mid) = await _probeSize(out, side,
                png: editedExtension(widget.path) == '.png')
            .whenComplete(out.dispose);
        if (!mounted || !identical(_sizeReq, e)) return mid.dispose();
        _update(() {
          _sizeOut?.dispose();
          _sizeOut = mid;
          _sizeOutFor = e;
          _sizeBytes = bytes;
        });
      } catch (_) {
        // Önizleme isteğe bağlı: kaydetme yolu kendi hatasını gösterir.
      }
    });
  }

  Widget _sizePanel() {
    _scheduleSizePreview();
    final cropped = croppedSize(_src!, _e);
    final out = outputSize(_src!, _e);
    final longSide = math.max(cropped.width, cropped.height);
    final scheme = Theme.of(context).colorScheme;
    const soft = TextStyle(color: AppColors.onMediaSoft);
    // Koyu stüdyoda okunur alan (B21: genel temanın açık dolgusu açık yazıyı
    // yutuyordu; etiket alanın üstünde sabit).
    InputDecoration deco(String key) => InputDecoration(
          labelText: context.t(key),
          labelStyle: soft,
          floatingLabelBehavior: FloatingLabelBehavior.always,
          filled: true,
          fillColor: scheme.surfaceContainerHigh,
          isDense: true,
          border: const OutlineInputBorder(),
          enabledBorder: const OutlineInputBorder(
              borderSide: BorderSide(color: AppColors.onMediaFaint)),
        );
    Widget chip(String label, double scale, {Key? key}) => ChoiceChip(
          key: key,
          label: Text(label),
          selected: (_e.scale - scale).abs() < 0.002,
          onSelected: (_) => _setScale(scale),
        );
    final ready = _sizeOut != null && identical(_sizeOutFor, _e);
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final label = Theme.of(context).textTheme.labelSmall?.copyWith(
        color: AppColors.onMediaSoft);
    // 1:1 büyüteç: aynı yerin özgün ve küçültülmüş hâli yan yana — küçültme
    // telefon ekranında ancak yakından görünür.
    Widget loupe(String key, String labelKey, ui.Image? image,
            ImageEdits edits, double pixelsPerDp) =>
        Padding(
          padding: const EdgeInsetsDirectional.only(end: Gap.sm),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              key: ValueKey(key),
              width: _ImageEditScreenState._loupe,
              height: _ImageEditScreenState._loupe,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(Radii.sm),
                border: Border.all(color: AppColors.onMediaFaint),
              ),
              child: image == null
                  ? const SizedBox.shrink()
                  : CustomPaint(
                      painter: _LoupePainter(image, edits, pixelsPerDp)),
            ),
            Text(context.t(labelKey), style: label),
          ]),
        );
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Row(children: [
        loupe('ied-loupe-before', 'ied.size_before', _src, _e, dpr),
        loupe('ied-loupe-after', 'ied.size_after', _sizeOut,
            const ImageEdits(), dpr * (_sizeOutFor?.scale ?? 1)),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                context.t('ied.size_now', {
                  'from': '${cropped.width.round()} × ${cropped.height.round()}',
                  'to': '${out.width.round()} × ${out.height.round()}',
                }),
                style: soft,
              ),
              Text(
                key: const ValueKey('ied-size-bytes'),
                ready && _sizeBytes != null
                    ? context.t('ied.size_estimate',
                        {'size': FsPaths.humanSize(_sizeBytes!)})
                    : context.t('ied.size_estimating'),
                style: const TextStyle(color: AppColors.onMedia),
              ),
            ],
          ),
        ),
      ]),
      const SizedBox(height: Gap.xs),
      // Sarılır: dar ekranda "1600 px" kesilmez (B21).
      Wrap(spacing: Gap.xs + 2, runSpacing: Gap.xs, children: [
        chip(context.t('ied.size_original'), 1),
        for (final p in const [75, 50, 25]) chip('%$p', p / 100),
        for (final edge in longEdgeChoices.reversed)
          if (edge < longSide)
            chip('$edge px', edge / longSide, key: ValueKey('edge-$edge')),
      ]),
      const SizedBox(height: 8),
      Row(children: [
        Expanded(
          child: TextField(
            key: const ValueKey('ied-width'),
            controller: _widthCtl,
            keyboardType: TextInputType.number,
            style: const TextStyle(color: AppColors.onMedia),
            decoration: deco('rs.width'),
            onChanged: (_) => _readSizeField(true),
          ),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 8),
          child: Icon(AppIcons.link, color: AppColors.onMediaSoft),
        ),
        Expanded(
          child: TextField(
            key: const ValueKey('ied-height'),
            controller: _heightCtl,
            keyboardType: TextInputType.number,
            style: const TextStyle(color: AppColors.onMedia),
            decoration: deco('rs.height'),
            onChanged: (_) => _readSizeField(false),
          ),
        ),
      ]),
      const SizedBox(height: 4),
    ]);
  }

  // ── kırpma ────────────────────────────────────────────────────────────────

  void _cropStart(Offset local) {
    final r = _cropOnScreen();
    final corners = {
      _Drag.tl: r.topLeft,
      _Drag.tr: r.topRight,
      _Drag.br: r.bottomRight,
      _Drag.bl: r.bottomLeft,
    };
    _drag = _Drag.none;
    var best = 40.0; // dokunma yarıçapı (dp)
    corners.forEach((k, o) {
      final d = (o - local).distance;
      if (d < best) {
        best = d;
        _drag = k;
      }
    });
    if (_drag == _Drag.none && r.contains(local)) _drag = _Drag.move;
    if (_drag != _Drag.none) _history.push(_e);
  }

  void _cropUpdate(Offset local, Offset delta) {
    if (_drag == _Drag.none) return;
    final c = _e.crop;
    final d = Offset(delta.dx / _box.width, delta.dy / _box.height);
    Rect next;
    if (_drag == _Drag.move) {
      final dx = d.dx.clamp(-c.left, 1 - c.right);
      final dy = d.dy.clamp(-c.top, 1 - c.bottom);
      next = c.shift(Offset(dx, dy));
    } else {
      const minSide = 0.05;
      final n = _norm(local);
      var l = c.left, t = c.top, r = c.right, b = c.bottom;
      switch (_drag) {
        case _Drag.tl:
          l = math.min(n.dx, r - minSide);
          t = math.min(n.dy, b - minSide);
        case _Drag.tr:
          r = math.max(n.dx, l + minSide);
          t = math.min(n.dy, b - minSide);
        case _Drag.br:
          r = math.max(n.dx, l + minSide);
          b = math.max(n.dy, t + minSide);
        case _Drag.bl:
          l = math.min(n.dx, r - minSide);
          b = math.max(n.dy, t + minSide);
        default:
      }
      next = Rect.fromLTRB(l, t, r, b);
      if (_ratio != null) next = _fitRatio(next, _drag);
    }
    _update(() => _e = _e.copyWith(crop: next));
  }

  /// [r]'nin yüksekliğini orana göre düzeltir; sürüklenmeyen kenar sabit.
  Rect _fitRatio(Rect r, _Drag anchor) {
    final ratio = _ratio!;
    var w = r.width;
    var h = w * _full.width / (_full.height * ratio);
    final top = anchor == _Drag.tl || anchor == _Drag.tr;
    final maxH = top ? r.bottom : 1 - r.top;
    if (h > maxH) {
      h = maxH;
      w = h * _full.height * ratio / _full.width;
    }
    final left = anchor == _Drag.tl || anchor == _Drag.bl;
    return Rect.fromLTWH(
      left ? r.right - w : r.left,
      top ? r.bottom - h : r.top,
      w,
      h,
    );
  }

  /// Oran çipi seçildi. "Orijinal" görselin kendi oranı, "Özel" a:b sorar.
  Future<void> _setRatioKey(String key, double? ratio) async {
    if (key == 'ied.original') {
      ratio = _full.width / _full.height;
    } else if (key == 'ied.custom_ratio') {
      final text = await showAppPrompt(context,
          title: context.t('ied.custom_ratio'),
          label: context.t('ied.ratio_hint'),
          initial: '4:5');
      if (text == null || !mounted) return;
      final parts = text.replaceAll(',', '.').split(RegExp(r'[:x×/ ]+'));
      final a = parts.isNotEmpty ? double.tryParse(parts.first) : null;
      final b = parts.length > 1 ? double.tryParse(parts[1]) : null;
      if (a == null || b == null || a <= 0 || b <= 0) {
        showSnack(context, context.t('ied.ratio_invalid'));
        return;
      }
      ratio = a / b;
    }
    _update(() => _ratioKey = key);
    _setRatio(ratio);
  }

  void _setRatio(double? ratio) {
    _update(() => _ratio = ratio);
    if (ratio == null) return;
    // Görselin TAMAMINA sığan en büyük oranlı dikdörtgen (eski kırpmaya
    // göre değil — yoksa her oran dokunuşu bir öncekini küçültüyordu).
    // Mevcut kırpmanın ortasına yerleşir, taşarsa içeri kaydırılır.
    final c = _e.crop;
    final pw = _full.width, ph = _full.height;
    var w = pw, h = pw / ratio;
    if (h > ph) {
      h = ph;
      w = ph * ratio;
    }
    final nw = (w / pw).clamp(0.0, 1.0), nh = (h / ph).clamp(0.0, 1.0);
    final l = (c.center.dx - nw / 2).clamp(0.0, 1.0 - nw);
    final t = (c.center.dy - nh / 2).clamp(0.0, 1.0 - nh);
    _push(_e.copyWith(crop: Rect.fromLTWH(l, t, nw, nh)));
  }
}

/// Çıktının kodlanmış boyu (izolat) + büyüteç için [side] px'lik orta parçası.
Future<(int, ui.Image)> _probeSize(ui.Image out, int side,
    {required bool png}) async {
  final bytes = await encodedSize(out, png: png);
  final w = math.min(side, out.width), h = math.min(side, out.height);
  final rec = ui.PictureRecorder();
  Canvas(rec).drawImageRect(
    out,
    Rect.fromCenter(
        center: Offset(out.width / 2, out.height / 2),
        width: w.toDouble(),
        height: h.toDouble()),
    Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()),
    Paint(),
  );
  final pic = rec.endRecording();
  try {
    return (bytes, await pic.toImage(w, h));
  } finally {
    pic.dispose();
  }
}

/// Boyut büyüteci (B21): [src]'nin kırpma merkezini [pixelsPerDp] ölçekte
/// (görsel pikseli / mantıksal piksel) kutuya çizer — özgünde cihaz pikseli
/// başına 1 görsel pikseli; küçültülmüş çıktı aynı yeri kaplar.
class _LoupePainter extends CustomPainter {
  _LoupePainter(this.src, this.edits, this.pixelsPerDp);

  final ui.Image src;
  final ImageEdits edits;
  final double pixelsPerDp;

  @override
  void paint(Canvas canvas, Size size) {
    final full = orientedSize(src, edits) / pixelsPerDp;
    final c = edits.crop.center;
    canvas.clipRect(Offset.zero & size);
    paintEdits(
      canvas,
      src,
      edits,
      Rect.fromLTWH(size.width / 2 - c.dx * full.width,
          size.height / 2 - c.dy * full.height, full.width, full.height),
    );
  }

  @override
  bool shouldRepaint(_LoupePainter old) =>
      old.src != src || old.edits != edits || old.pixelsPerDp != pixelsPerDp;
}
