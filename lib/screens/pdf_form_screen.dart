import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path/path.dart' as p;

import '../core/app_icons.dart';
import '../core/l10n/app_strings.dart';
import '../core/theme.dart';
import '../services/pdf/pdf_form.dart';
import '../services/pdf_form_pro.dart';
import '../services/pdf_tools.dart';
import '../widgets/app_dialog.dart';
import '../widgets/autofill_profile_sheet.dart';
import '../widgets/pdf_save_dialog.dart';
import '../widgets/signature_pad.dart';
import '../core/snack.dart';
import '../core/safe_insets.dart';
import '../core/user_error.dart';

/// **PDF formu doldurma** — belgenin kendi alanları düzenlenebilir bir liste
/// olarak açılır, doldurulur ve dosyaya yazılır.
///
/// Niye liste, niye sayfanın üstünde kutular değil: form alanları telefon
/// ekranında çoğu zaman 8-10 punto ve iç içedir; sayfayı yakınlaştırıp minik
/// kutulara yazmak (Acrobat'ın mobilde en çok şikâyet edilen yanı) yerine
/// alanlar sayfa sırasına göre listelenir. Her satır kendi türüyle çizilir:
/// metin kutusu, onay kutusu, açılır liste, radyo düğmesi.
///
/// Yazma yolu `PdfFormFiller`: alanın kendi değeri değişir, üstüne metin
/// BASILMAZ — yoksa form doldurulmuş sayılmaz ve karşı taraf boş alan görür.
class PdfFormScreen extends StatefulWidget {
  const PdfFormScreen({super.key, required this.path});

  final String path;

  /// Doldurulup kaydedilirse `true` (üzerine yazıldıysa) döner.
  static Future<bool?> open(BuildContext context, String path) =>
      Navigator.of(context).push<bool>(
        MaterialPageRoute(builder: (_) => PdfFormScreen(path: path)),
      );

  @override
  State<PdfFormScreen> createState() => _PdfFormScreenState();
}

class _PdfFormScreenState extends State<PdfFormScreen> {
  List<PdfFormFieldInfo>? _fields;
  String? _error;
  bool _busy = false;

  /// Alan adı → kullanıcının verdiği değer (yalnız DEĞİŞENLER; dokunulmayan
  /// alan dosyada olduğu gibi kalsın).
  final Map<String, String> _values = {};
  final Map<String, TextEditingController> _controllers = {};

  /// İmza alanı → çizilen imza (P18: form + imza tek ekranda). Kayıtta form
  /// doldurulduktan SONRA alanın kutusuna vektör olarak basılır.
  final Map<PdfFormFieldInfo, Signature> _signs = {};

  /// Doldurulmuş form düzleştirilsin mi (alanlar kilitlensin mi)?
  bool _flatten = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final bytes = await File(widget.path).readAsBytes();
      final fields = await PdfFormFiller.read(bytes);
      if (!mounted) return;
      setState(() {
        _fields = fields;
        for (final c in _controllers.values) {
          c.dispose();
        }
        _controllers.clear();
        for (final f in fields) {
          if (f.kind == PdfFormFieldKind.text) {
            _controllers.remove(f.name)?.dispose();
            _controllers[f.name] = TextEditingController(text: f.value);
          }
        }
      });
    } catch (e) {
      if (mounted) setState(() => _error = userErrorText(e));
    }
  }

  /// Profille doldur: yalnız BOŞ metin alanları; profil yoksa önce
  /// düzenleme levhası açılır.
  Future<void> _autofill() async {
    final fields = _fields;
    if (fields == null) return;
    var profile = await PdfFormPro.loadProfile();
    if (!mounted) return;
    if (profile.isEmpty) {
      profile = await showAutofillProfileSheet(context) ?? const {};
      if (!mounted || profile.isEmpty) return;
    }
    final suggestion = PdfFormPro.suggest([
      for (final f in fields)
        if (f.kind == PdfFormFieldKind.text && !f.readOnly)
          (
            name: f.name,
            label: f.label,
            value: _values[f.name] ?? _controllers[f.name]?.text ?? f.value,
          ),
    ], profile);
    if (suggestion.isEmpty) {
      showSnack(context, context.t('pp.autofill_none'));
      return;
    }
    setState(() {
      suggestion.forEach((name, value) {
        _values[name] = value;
        _controllers[name]?.text = value;
      });
    });
    showSnack(context, context.t('pp.autofill_done', {'n': suggestion.length}));
  }

  /// İmza alanı sayfaya yerleştirilebilir mi (kutusu ve sayfası çözülmüş)?
  static bool _signable(PdfFormFieldInfo f) =>
      f.kind == PdfFormFieldKind.signature && f.bounds != null && f.page > 0;

  /// Kayıtlı imza varsa onu kullanır (ikinci dokunuş yeniden çizdirir);
  /// yoksa imza panosu açılır.
  Future<void> _signField(PdfFormFieldInfo field) async {
    final sig = _signs.containsKey(field)
        ? await SignaturePad.show(context)
        : await Signature.load() ?? await _pad();
    if (sig != null && mounted) setState(() => _signs[field] = sig);
  }

  Future<Signature?> _pad() =>
      mounted ? SignaturePad.show(context) : Future.value();

  /// İmzayı alan kutusuna en-boy oranını koruyarak ortalar.
  static Rect _fit(Rect box, double aspect) {
    final w = box.width / box.height > aspect ? box.height * aspect : box.width;
    final h = w / aspect;
    return Rect.fromCenter(center: box.center, width: w, height: h);
  }

  Future<void> _save() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final bytes = await File(widget.path).readAsBytes();
      // Gömülü yazı tipi ŞART: PDF'in yerleşik yazı tipleri `İ Ğ Ş ğ ı ş`
      // harflerini tanımıyor ve alanın görünümü çizilirken hata veriyor —
      // yani "Ayşe" yazan kullanıcı formu hiç kaydedemezdi.
      final font =
          (await rootBundle.load('assets/fonts/Carlito-Regular.ttf'))
              .buffer
              .asUint8List();
      List<int> out = await PdfFormFiller.fill(
        bytes,
        _values,
        flatten: _flatten,
        fontData: font,
      );
      // ponytail: imza başına bir yeniden ayrıştırma; formda 1–3 imza alanı olur.
      for (final MapEntry(key: f, value: sig) in _signs.entries) {
        out = await PdfTools.stampStrokes(
          out,
          pageIndex: f.page - 1,
          strokes: sig.strokes,
          rect: _fit(f.bounds!, sig.aspect),
          rawSpace: true,
        );
      }
      if (!mounted) return;
      setState(() => _busy = false);
      final outcome = await savePdfWithChoice(
        context,
        originalPath: widget.path,
        bytes: out,
        note: context.t(_flatten ? 'pf.note_flat' : 'pf.note'),
        activityDetail: context.t('ps.act_form'),
      );
      if (outcome == null || !mounted) return;
      Navigator.of(context).pop(outcome.overwritten);
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      showSnack(context, context.t('pf.failed', {'error': userErrorText(e)}));
    }
  }

  bool get _dirty => _values.isNotEmpty || _signs.isNotEmpty;

  Future<void> _handlePop(bool didPop) async {
    if (didPop) return;
    if (!_dirty) {
      Navigator.of(context).pop(false);
      return;
    }
    final leave = await showAppConfirm(
      context,
      title: context.t('pdf.discard_title'),
      message: context.t('pdf.discard_body'),
      confirmLabel: context.t('pdf.discard_confirm'),
      destructive: true,
    );
    if (leave && mounted) {
      Navigator.of(context).pop(false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final fields = _fields;
    final fillable =
        fields?.where((f) => !f.readOnly || _signable(f)).length ?? 0;
    return PopScope<bool>(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) => _handlePop(didPop),
      child: Scaffold(
      appBar: AppBar(
        title: Text(context.t('pf.title', {'name': p.basename(widget.path)}),
            maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          // Otomatik doldurma profili (Faz 39 madde 9): boş alanlara ad,
          // e-posta, telefon, adres… Uzun basış profili düzenletir.
          if (fillable > 0)
            IconButton(
              tooltip: context.t('pp.autofill'),
              icon: const Icon(AppIcons.pdfAutofill),
              onPressed: _autofill,
            ),
          if (fillable > 0)
            IconButton(
              tooltip: context.t('pp.profile'),
              icon: const Icon(AppIcons.tune),
              onPressed: () => showAutofillProfileSheet(context),
            ),
        ],
      ),
      body: _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(Gap.lg),
                child: Text(context.t('pf.failed', {'error': _error})),
              ),
            )
          : fields == null
              ? const Center(child: CircularProgressIndicator())
              : fields.isEmpty
                  ? _empty(context)
                  : _list(context, fields),
      bottomNavigationBar: fields == null || fields.isEmpty || fillable == 0
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(Gap.md),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Düzleştirme geri alınamaz: açıkça sorulur, varsayılan
                    // KAPALI. Kullanıcı formu sonra düzeltmek isteyebilir.
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      value: _flatten,
                      onChanged: (v) => setState(() => _flatten = v),
                      title: Text(context.t('pf.flatten')),
                      subtitle: Text(context.t('pf.flatten_sub')),
                    ),
                    FilledButton.icon(
                      onPressed: _busy ? null : _save,
                      icon: _busy
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(AppIcons.save),
                      label: Text(context.t('pf.save')),
                    ),
                  ],
                ),
              ),
            ),
    ),
    );
  }

  Widget _empty(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(Gap.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(AppIcons.newText,
                  size: 48, color: Paper.faint(context)),
              const SizedBox(height: Gap.md),
              Text(context.t('pf.no_fields'), textAlign: TextAlign.center),
              const SizedBox(height: Gap.sm),
              // Yol GÖSTERİLİR: "form alanı yok" tek başına çıkmaz sokak.
              Text(context.t('pf.no_fields_hint'),
                  textAlign: TextAlign.center,
                  style: context.type.small.copyWith(color: Paper.faint(context))),
            ],
          ),
        ),
      );

  Widget _list(BuildContext context, List<PdfFormFieldInfo> fields) {
    // Sayfa sırasına göre gruplanır: kullanıcı belgede nerede olduğunu bilsin.
    final pages = <int, List<PdfFormFieldInfo>>{};
    for (final f in fields) {
      pages.putIfAbsent(f.page, () => []).add(f);
    }
    final ordered = pages.keys.toList()..sort();
    return ListView(
      padding: withNavInset(
          context, const EdgeInsets.symmetric(horizontal: Gap.md)),
      children: [
        for (final page in ordered) ...[
          Padding(
            padding: const EdgeInsets.only(top: Gap.md, bottom: Gap.xs),
            child: Text(
              page > 0
                  ? context.t('pf.page', {'n': page})
                  : context.t('pf.other_fields'),
              style: Theme.of(context)
                  .textTheme
                  .labelLarge
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          for (final field in pages[page]!) _fieldTile(context, field),
        ],
        const SizedBox(height: Gap.lg),
      ],
    );
  }

  Widget _fieldTile(BuildContext context, PdfFormFieldInfo field) {
    if (field.readOnly && !_signable(field)) {
      return ListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(field.label),
        subtitle: Text(field.value.isEmpty
            ? context.t('pf.read_only')
            : '${field.value} · ${context.t('pf.read_only')}'),
        leading: const Icon(AppIcons.lock),
      );
    }
    if (_signable(field)) {
      final signed = _signs.containsKey(field);
      return ListTile(
        contentPadding: EdgeInsets.zero,
        leading: const Icon(AppIcons.gesture),
        title: Text(field.label),
        subtitle: Text(context.t(signed ? 'pf.signed' : 'pf.sign_tap')),
        trailing: signed ? const Icon(AppIcons.check) : null,
        onTap: _busy ? null : () => _signField(field),
      );
    }
    switch (field.kind) {
      case PdfFormFieldKind.checkbox:
        return CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          value: _values[field.name] == null
              ? field.isChecked
              : _values[field.name] == 'true',
          onChanged: (v) =>
              setState(() => _values[field.name] = v == true ? 'true' : 'false'),
          title: Text(field.label),
        );
      case PdfFormFieldKind.radio:
      case PdfFormFieldKind.combo:
      case PdfFormFieldKind.list:
        final options = field.options.toSet().toList();
        final value = _values[field.name] ?? field.value;
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: Gap.xs),
          child: DropdownButtonFormField<String>(
            initialValue: options.contains(value) ? value : null,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: field.label,
              border: const OutlineInputBorder(),
            ),
            items: [
              for (final option in options)
                DropdownMenuItem(value: option, child: Text(option)),
            ],
            onChanged: (v) {
              if (v == null) return;
              setState(() => _values[field.name] = v);
            },
          ),
        );
      case PdfFormFieldKind.text:
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: Gap.xs),
          child: TextField(
            controller: _controllers[field.name],
            decoration: InputDecoration(
              labelText: field.label,
              border: const OutlineInputBorder(),
            ),
            // Uzun açıklama alanları için: tek satıra sıkıştırmak yerine
            // gerektiğinde büyüsün.
            minLines: 1,
            maxLines: 4,
            onChanged: (v) => _values[field.name] = v,
          ),
        );
      case PdfFormFieldKind.signature:
      case PdfFormFieldKind.unknown:
        return const SizedBox.shrink();
    }
  }
}
