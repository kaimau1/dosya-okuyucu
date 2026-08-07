import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path/path.dart' as p;

import '../core/l10n/app_strings.dart';
import '../core/theme.dart';
import '../services/pdf/pdf_form.dart';
import '../widgets/pdf_save_dialog.dart';

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
        for (final f in fields) {
          if (f.kind == PdfFormFieldKind.text) {
            _controllers[f.name] = TextEditingController(text: f.value);
          }
        }
      });
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    }
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
      final out = await PdfFormFiller.fill(
        bytes,
        _values,
        flatten: _flatten,
        fontData: font,
      );
      if (!mounted) return;
      setState(() => _busy = false);
      final outcome = await savePdfWithChoice(
        context,
        originalPath: widget.path,
        bytes: out,
        note: context.t(_flatten ? 'pf.note_flat' : 'pf.note'),
      );
      if (outcome == null || !mounted) return;
      Navigator.of(context).pop(outcome.overwritten);
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.t('pf.failed', {'error': e}))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final fields = _fields;
    final fillable =
        fields?.where((f) => !f.readOnly).length ?? 0;
    return Scaffold(
      appBar: AppBar(
        title: Text(context.t('pf.title', {'name': p.basename(widget.path)}),
            maxLines: 1, overflow: TextOverflow.ellipsis),
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
                          : const Icon(Icons.save_outlined),
                      label: Text(context.t('pf.save')),
                    ),
                  ],
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
              Icon(Icons.article_outlined,
                  size: 48, color: Paper.faint(context)),
              const SizedBox(height: Gap.md),
              Text(context.t('pf.no_fields'), textAlign: TextAlign.center),
              const SizedBox(height: Gap.sm),
              // Yol GÖSTERİLİR: "form alanı yok" tek başına çıkmaz sokak.
              Text(context.t('pf.no_fields_hint'),
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: Paper.faint(context))),
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
      padding: const EdgeInsets.symmetric(horizontal: Gap.md),
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
    if (field.readOnly) {
      return ListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(field.label),
        subtitle: Text(field.value.isEmpty
            ? context.t('pf.read_only')
            : '${field.value} · ${context.t('pf.read_only')}'),
        leading: const Icon(Icons.lock_outline),
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
        final value = _values[field.name] ?? field.value;
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: Gap.xs),
          child: DropdownButtonFormField<String>(
            value: field.options.contains(value) ? value : null,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: field.label,
              border: const OutlineInputBorder(),
            ),
            items: [
              for (final option in field.options)
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
