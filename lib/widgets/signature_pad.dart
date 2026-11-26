import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart' show FileType;
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:shared_preferences/shared_preferences.dart';

import '../core/app_colors.dart';
import '../core/app_icons.dart';
import '../core/l10n/app_strings.dart';
import '../core/theme.dart';
import '../screens/fm/pick_file_screen.dart' show AppFilePicker;

/// İmza üretim türü (Faz 61 m.4): çizim, yazılı imza, görsel.
enum SignatureKind { draw, type, image }

/// İmza ya da baş harf (paraf):
/// * **Çizim:** 0..1 normalize vektör darbeler — her boyutta keskin.
/// * **Yazı:** el yazısı/italik yazı tipiyle belgeye basılan metin.
/// * **Görsel:** kırpılmış/küçültülmüş (≤ 480 px) PNG baytları.
class Signature {
  const Signature(
    this.strokes,
    this.aspect, {
    this.text,
    this.imageBytes,
  });

  /// Yazılı imza / baş harf ya da tarih damgası.
  factory Signature.typed(String text) {
    final clean = text.trim();
    final aspect = (clean.length * 0.52).clamp(1.4, 5.5);
    return Signature(const [], aspect, text: clean);
  }

  /// Görselden imza.
  const Signature.image(Uint8List bytes, this.aspect)
      : strokes = const [],
        text = null,
        imageBytes = bytes;

  /// Her biri bir kalem darbesi; noktalar 0..1.
  final List<List<Offset>> strokes;

  /// Genişlik / yükseklik — yerleştirirken imzanın oranı korunsun diye.
  final double aspect;

  /// Yazılı imza metni (çizim/görselde `null`).
  final String? text;

  /// Görsel imza PNG baytları (çizim/yazıda `null`).
  final Uint8List? imageBytes;

  SignatureKind get kind {
    if (imageBytes != null && imageBytes!.isNotEmpty) {
      return SignatureKind.image;
    }
    if (text != null && text!.trim().isNotEmpty) {
      return SignatureKind.type;
    }
    return SignatureKind.draw;
  }

  static const _prefsKey = 'signature_strokes_v1';

  /// Baş harf (paraf) ayrı saklanır (Faz 31 — imza + baş harf).
  static const _initialsKey = 'signature_initials_v1';

  static const _libraryKey = 'signature_library_v1';
  static const _initialsLibraryKey = 'signature_initials_library_v1';
  static const _maxLibrary = 5;

  static String _key(bool initials) => initials ? _initialsKey : _prefsKey;
  static String _libKey(bool initials) =>
      initials ? _initialsLibraryKey : _libraryKey;

  /// Ekranda çizilmiş ham noktaları sınır kutusuna göre normalize eder.
  /// Tek nokta/çizgi gibi dejenere hâllerde bölme sıfıra düşmesin diye taban var.
  factory Signature.fromRaw(List<List<Offset>> raw) {
    final points = [for (final s in raw) ...s];
    if (points.isEmpty) return const Signature([], 1);
    var minX = points.first.dx, maxX = points.first.dx;
    var minY = points.first.dy, maxY = points.first.dy;
    for (final p in points) {
      if (p.dx < minX) minX = p.dx;
      if (p.dx > maxX) maxX = p.dx;
      if (p.dy < minY) minY = p.dy;
      if (p.dy > maxY) maxY = p.dy;
    }
    final w = (maxX - minX).abs() < 1 ? 1.0 : maxX - minX;
    final h = (maxY - minY).abs() < 1 ? 1.0 : maxY - minY;
    return Signature(
      [
        for (final s in raw)
          if (s.length >= 2)
            [for (final p in s) Offset((p.dx - minX) / w, (p.dy - minY) / h)],
      ],
      w / h,
    );
  }

  bool get isEmpty => switch (kind) {
        SignatureKind.draw => strokes.isEmpty,
        SignatureKind.type => text == null || text!.trim().isEmpty,
        SignatureKind.image => imageBytes == null || imageBytes!.isEmpty,
      };

  String toJson() => switch (kind) {
        SignatureKind.draw => jsonEncode({
            'aspect': aspect,
            'strokes': [
              for (final s in strokes) [for (final p in s) [p.dx, p.dy]],
            ],
          }),
        SignatureKind.type => jsonEncode({
            'kind': 'type',
            'aspect': aspect,
            'text': text,
          }),
        SignatureKind.image => jsonEncode({
            'kind': 'image',
            'aspect': aspect,
            'image': base64Encode(imageBytes!),
          }),
      };

  static Signature? fromJson(String source) {
    try {
      final map = jsonDecode(source) as Map<String, dynamic>;
      final kind = map['kind'] as String?;
      if (kind == 'type') {
        final t = (map['text'] as String?)?.trim() ?? '';
        if (t.isEmpty) return null;
        final a = (map['aspect'] as num?)?.toDouble() ??
            (t.length * 0.52).clamp(1.4, 5.5);
        return Signature(const [], a, text: t);
      }
      if (kind == 'image') {
        final b64 = map['image'] as String?;
        if (b64 == null || b64.isEmpty) return null;
        final bytes = base64Decode(b64);
        if (bytes.isEmpty) return null;
        final a = (map['aspect'] as num?)?.toDouble() ?? 2.5;
        return Signature.image(bytes, a > 0.1 ? a : 2.5);
      }
      final strokes = [
        for (final s in map['strokes'] as List)
          [
            for (final p in s as List)
              Offset((p as List)[0] * 1.0, p[1] * 1.0),
          ],
      ];
      if (strokes.isEmpty) return null;
      return Signature(strokes, (map['aspect'] as num).toDouble());
    } catch (_) {
      return null; // bozuk kayıt: imza yokmuş gibi davran, çökme
    }
  }

  /// Kayıtlı son imzayı okur (yoksa null). Kullanıcı her seferinde yeniden çizmesin.
  static Future<Signature?> load({bool initials = false}) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key(initials));
    return raw == null ? null : fromJson(raw);
  }

  /// İmzayı hem varsayılan yuvaya hem kayıtlı imza kitaplığına kaydeder.
  Future<void> save({bool initials = false}) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = toJson();
    await prefs.setString(_key(initials), encoded);
    final list = List<String>.of(prefs.getStringList(_libKey(initials)) ?? []);
    list.remove(encoded);
    list.insert(0, encoded);
    if (list.length > _maxLibrary) list.removeRange(_maxLibrary, list.length);
    await prefs.setStringList(_libKey(initials), list);
  }

  /// Kayıtlı tüm imzaları (en yeni başta) döndürür.
  static Future<List<Signature>> loadSaved({bool initials = false}) async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_libKey(initials)) ?? const [];
    final out = <Signature>[];
    for (final raw in list) {
      final s = fromJson(raw);
      if (s != null) out.add(s);
    }
    if (out.isEmpty) {
      final single = await load(initials: initials);
      if (single != null) out.add(single);
    }
    return out;
  }

  /// Kayıtlı kitaplıktan belirtilen sıradaki imzayı siler.
  static Future<void> removeSaved(int index, {bool initials = false}) async {
    final prefs = await SharedPreferences.getInstance();
    final list = List<String>.of(prefs.getStringList(_libKey(initials)) ?? []);
    if (index >= 0 && index < list.length) {
      list.removeAt(index);
      await prefs.setStringList(_libKey(initials), list);
      if (list.isEmpty) {
        await prefs.remove(_key(initials));
      } else {
        await prefs.setString(_key(initials), list.first);
      }
    } else if (list.isEmpty && index == 0) {
      await prefs.remove(_key(initials));
    }
  }

  static Future<void> clear({bool initials = false}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key(initials));
    await prefs.remove(_libKey(initials));
  }

  /// Seçilen görseli imza boyutuna (en çok 480 px) küçültüp PNG yapar (izolatta).
  static Future<Signature?> fromImageBytes(Uint8List rawBytes) =>
      Isolate.run(() {
        final decoded = img.decodeImage(rawBytes);
        if (decoded == null || decoded.width <= 0 || decoded.height <= 0) {
          return null;
        }
        final resized = decoded.width > 480
            ? img.copyResize(decoded, width: 480)
            : decoded;
        final png = Uint8List.fromList(img.encodePng(resized));
        return Signature.image(png, resized.width / resized.height);
      });
}

/// İmza oluşturma / seçme penceresi (Çiz · Yaz · Görsel + kayıtlılar).
class SignaturePad extends StatefulWidget {
  const SignaturePad({super.key, this.initials = false});

  /// Baş harf mi oluşturuluyor (ayrı anahtara kaydedilir, başlık farklı).
  final bool initials;

  static Future<Signature?> show(BuildContext context,
          {bool initials = false}) =>
      showDialog<Signature>(
        context: context,
        builder: (_) => SignaturePad(initials: initials),
      );

  @override
  State<SignaturePad> createState() => _SignaturePadState();
}

class _SignaturePadState extends State<SignaturePad> {
  SignatureKind _mode = SignatureKind.draw;
  final _strokes = <List<Offset>>[];
  final _typeCtl = TextEditingController();
  Signature? _pickedImage;
  bool _picking = false;
  List<Signature> _saved = const [];

  @override
  void initState() {
    super.initState();
    _loadSaved();
  }

  @override
  void dispose() {
    _typeCtl.dispose();
    super.dispose();
  }

  Future<void> _loadSaved() async {
    final list = await Signature.loadSaved(initials: widget.initials);
    if (mounted) setState(() => _saved = list);
  }

  Future<void> _pickImage() async {
    if (_picking) return;
    setState(() => _picking = true);
    try {
      final res = await AppFilePicker.pickFiles(type: FileType.image);
      final path = res?.files.single.path;
      if (path == null || !mounted) return;
      final bytes = await File(path).readAsBytes();
      final sig = await Signature.fromImageBytes(bytes);
      if (sig != null && mounted) setState(() => _pickedImage = sig);
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  bool get _canConfirm => switch (_mode) {
        SignatureKind.draw => _strokes.any((s) => s.length >= 2),
        SignatureKind.type => _typeCtl.text.trim().isNotEmpty,
        SignatureKind.image => _pickedImage != null,
      };

  void _clear() {
    setState(() {
      switch (_mode) {
        case SignatureKind.draw:
          _strokes.clear();
        case SignatureKind.type:
          _typeCtl.clear();
        case SignatureKind.image:
          _pickedImage = null;
      }
    });
  }

  void _confirm() {
    final Signature? sig = switch (_mode) {
      SignatureKind.draw => Signature.fromRaw(_strokes),
      SignatureKind.type => Signature.typed(_typeCtl.text),
      SignatureKind.image => _pickedImage,
    };
    if (sig == null || sig.isEmpty) {
      Navigator.pop(context);
      return;
    }
    sig.save(initials: widget.initials);
    Navigator.pop(context, sig);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AlertDialog(
      title: Text(context.t(widget.initials ? 'pe.draw_initials' : 'sp.draw')),
      content: SizedBox(
        width: 400,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SegmentedButton<SignatureKind>(
                showSelectedIcon: false,
                segments: [
                  ButtonSegment(
                    value: SignatureKind.draw,
                    icon: const Icon(AppIcons.draw, size: 18),
                    label: Text(context.t('sp.tab_draw')),
                  ),
                  ButtonSegment(
                    value: SignatureKind.type,
                    icon: const Icon(AppIcons.textFields, size: 18),
                    label: Text(context.t('sp.tab_type')),
                  ),
                  ButtonSegment(
                    value: SignatureKind.image,
                    icon: const Icon(AppIcons.image, size: 18),
                    label: Text(context.t('sp.tab_image')),
                  ),
                ],
                selected: {_mode},
                onSelectionChanged: (s) => setState(() => _mode = s.first),
              ),
              const SizedBox(height: Gap.sm),
              if (_saved.isNotEmpty) ...[
                Text(
                  context.t('sp.saved_list'),
                  style: context.type.small
                      .copyWith(color: scheme.onSurfaceVariant),
                ),
                const SizedBox(height: Gap.xs),
                SizedBox(
                  height: 56,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _saved.length,
                    separatorBuilder: (_, _) => const SizedBox(width: Gap.xs),
                    itemBuilder: (_, i) {
                      final item = _saved[i];
                      return InkWell(
                        key: ValueKey('sig-saved-$i'),
                        borderRadius: BorderRadius.circular(Radii.sm),
                        onTap: () => Navigator.pop(context, item),
                        child: Container(
                          width: 112,
                          padding: const EdgeInsets.all(Gap.xs),
                          decoration: BoxDecoration(
                            color: AppColors.page,
                            border: Border.all(color: scheme.outlineVariant),
                            borderRadius: BorderRadius.circular(Radii.sm),
                          ),
                          child: Stack(
                            children: [
                              Positioned.fill(
                                child: SignaturePreview(signature: item),
                              ),
                              PositionedDirectional(
                                top: 0,
                                end: 0,
                                child: GestureDetector(
                                  onTap: () async {
                                    await Signature.removeSaved(i,
                                        initials: widget.initials);
                                    await _loadSaved();
                                  },
                                  child: Icon(AppIcons.close,
                                      size: 16,
                                      color: scheme.onSurfaceVariant),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: Gap.sm),
              ],
              _modeBody(context, scheme),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _canConfirm ? _clear : null,
          child: Text(context.t('common.clear')),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(context.t('common.cancel')),
        ),
        FilledButton(
          key: const ValueKey('sig-pad-ok'),
          onPressed: _canConfirm ? _confirm : null,
          child: Text(context.t('common.ok')),
        ),
      ],
    );
  }

  Widget _modeBody(BuildContext context, ColorScheme scheme) => switch (_mode) {
        SignatureKind.draw => SizedBox(
            height: 190,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: AppColors.page,
                border: Border.all(color: scheme.outlineVariant),
                borderRadius: BorderRadius.circular(Radii.sm),
              ),
              child: GestureDetector(
                onPanStart: (d) =>
                    setState(() => _strokes.add([d.localPosition])),
                onPanUpdate: (d) => setState(() {
                  if (_strokes.isEmpty) _strokes.add([]);
                  _strokes.last.add(d.localPosition);
                }),
                child: RepaintBoundary(
                  child: CustomPaint(
                    painter: _StrokePainter(_strokes),
                    size: Size.infinite,
                  ),
                ),
              ),
            ),
          ),
        SignatureKind.type => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                key: const ValueKey('sig-type-input'),
                controller: _typeCtl,
                decoration: InputDecoration(
                  labelText: context.t('sp.type_hint'),
                  border: const OutlineInputBorder(),
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: Gap.sm),
              Container(
                height: 92,
                padding: const EdgeInsets.all(Gap.sm),
                decoration: BoxDecoration(
                  color: AppColors.page,
                  border: Border.all(color: scheme.outlineVariant),
                  borderRadius: BorderRadius.circular(Radii.sm),
                ),
                child: _typeCtl.text.trim().isEmpty
                    ? Center(
                        child: Text(
                          context.t('sp.type_hint'),
                          style: context.type.small
                              .copyWith(color: scheme.onSurfaceVariant),
                        ),
                      )
                    : SignaturePreview(
                        signature: Signature.typed(_typeCtl.text)),
              ),
            ],
          ),
        SignatureKind.image => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                height: 136,
                padding: const EdgeInsets.all(Gap.sm),
                decoration: BoxDecoration(
                  color: AppColors.page,
                  border: Border.all(color: scheme.outlineVariant),
                  borderRadius: BorderRadius.circular(Radii.sm),
                ),
                child: _pickedImage == null
                    ? Center(
                        child: Text(
                          context.t('sp.image_hint'),
                          textAlign: TextAlign.center,
                          style: context.type.small
                              .copyWith(color: scheme.onSurfaceVariant),
                        ),
                      )
                    : SignaturePreview(signature: _pickedImage!),
              ),
              const SizedBox(height: Gap.sm),
              OutlinedButton.icon(
                key: const ValueKey('sig-pick-image'),
                onPressed: _picking ? null : _pickImage,
                icon: const Icon(AppIcons.addPhoto),
                label: Text(context.t('sp.pick_image')),
              ),
            ],
          ),
      };
}

/// Çizim / yazı / görsel imzayı ortak önizleyen bileşen.
class SignaturePreview extends StatelessWidget {
  const SignaturePreview({
    super.key,
    required this.signature,
    this.color = AppColors.pageInk,
  });

  final Signature signature;
  final Color color;

  @override
  Widget build(BuildContext context) => switch (signature.kind) {
        SignatureKind.draw => CustomPaint(
            painter: SignaturePainter(signature, color: color),
            size: Size.infinite,
          ),
        SignatureKind.type => Center(
            child: FittedBox(
              fit: BoxFit.contain,
              child: Text(
                signature.text ?? '',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontFamily: 'Tinos',
                      fontStyle: FontStyle.italic,
                      color: color,
                    ),
              ),
            ),
          ),
        SignatureKind.image => Image.memory(
            signature.imageBytes!,
            cacheWidth: 600,
            fit: BoxFit.contain,
          ),
      };
}

/// Ham (ekran koordinatlı) darbeleri çizer — imza panosu için.
class _StrokePainter extends CustomPainter {
  const _StrokePainter(this.strokes);

  final List<List<Offset>> strokes;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.pageInk
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;
    for (final stroke in strokes) {
      if (stroke.length < 2) continue;
      canvas.drawPath(
        Path()
          ..moveTo(stroke.first.dx, stroke.first.dy)
          ..addPolygon(stroke, false),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_StrokePainter old) => true;
}

/// Normalize edilmiş (0..1) imzayı verilen kutuya çizer — yerleştirme
/// önizlemesi ile PDF'e basılan şey aynı noktalardan gelir.
class SignaturePainter extends CustomPainter {
  const SignaturePainter(this.signature, {this.color = AppColors.pageInk});

  final Signature signature;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;
    for (final stroke in signature.strokes) {
      if (stroke.length < 2) continue;
      final points = [
        for (final p in stroke) Offset(p.dx * size.width, p.dy * size.height),
      ];
      canvas.drawPath(
        Path()
          ..moveTo(points.first.dx, points.first.dy)
          ..addPolygon(points, false),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(SignaturePainter old) => old.signature != signature;
}
