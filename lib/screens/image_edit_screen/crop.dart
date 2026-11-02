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

  Widget _sizePanel() {
    final cropped = croppedSize(_src!, _e);
    final out = outputSize(_src!, _e);
    final longSide = math.max(cropped.width, cropped.height);
    const soft = TextStyle(color: AppColors.onMediaSoft);
    InputDecoration deco(String key) => InputDecoration(
          labelText: context.t(key),
          labelStyle: soft,
          isDense: true,
          border: const OutlineInputBorder(),
          enabledBorder: const OutlineInputBorder(
              borderSide: BorderSide(color: AppColors.onMediaFaint)),
        );
    Widget chip(String label, double scale, {Key? key}) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 3),
          child: ChoiceChip(
            key: key,
            label: Text(label),
            selected: (_e.scale - scale).abs() < 0.002,
            onSelected: (_) => _setScale(scale),
          ),
        );
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Text(
        context.t('ied.size_now', {
          'from': '${cropped.width.round()} × ${cropped.height.round()}',
          'to': '${out.width.round()} × ${out.height.round()}',
        }),
        style: soft,
      ),
      const SizedBox(height: 6),
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: [
          chip(context.t('ied.size_original'), 1),
          for (final p in const [75, 50, 25]) chip('%$p', p / 100),
          for (final edge in longEdgeChoices.reversed)
            if (edge < longSide)
              chip('$edge px', edge / longSide, key: ValueKey('edge-$edge')),
        ]),
      ),
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
    // Var olan kırpmanın ortasına sığan en büyük oranlı dikdörtgen.
    final c = _e.crop;
    final pw = c.width * _full.width, ph = c.height * _full.height;
    var w = pw, h = pw / ratio;
    if (h > ph) {
      h = ph;
      w = ph * ratio;
    }
    _push(_e.copyWith(
      crop: Rect.fromCenter(
        center: c.center,
        width: w / _full.width,
        height: h / _full.height,
      ),
    ));
  }
}
