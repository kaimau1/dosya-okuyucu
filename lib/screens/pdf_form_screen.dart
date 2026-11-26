import 'dart:io';
import 'dart:math' as math;

import 'package:file_picker/file_picker.dart' show FileType;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path/path.dart' as p;
import 'package:pdfrx/pdfrx.dart';
import 'package:share_plus/share_plus.dart';

import '../core/app_colors.dart';
import '../core/app_icons.dart';
import '../core/edition.dart';
import '../core/l10n/app_strings.dart';
import '../core/safe_insets.dart';
import '../core/snack.dart';
import '../core/theme.dart';
import '../core/user_error.dart';
import '../services/pdf/pdf_form.dart';
import '../services/pdf_digital_sign.dart';
import '../services/pdf_form_pro.dart';
import '../services/pdf_tools.dart';
import '../widgets/app_dialog.dart';
import '../widgets/autofill_profile_sheet.dart';
import '../widgets/pdf_save_dialog.dart';
import '../widgets/pro_gate.dart';
import '../widgets/signature_pad.dart';
import 'fm/pick_file_screen.dart' show AppFilePicker;

part 'pdf_form_sign_tab.dart';

/// Tek Form + İmza yüzeyinin sekmeleri (Faz 61 m.6: `PdfSignScreen` emekli).
enum PdfFormTab { form, sign, digital }

/// Sayfa üzerine serbest yerleştirilen imza / baş harf / tarih damgası.
class _PlacedStamp {
  _PlacedStamp({
    required this.id,
    required this.page,
    required this.signature,
    required this.pos,
    required this.widthFraction,
    this.isDateStamp = false,
  });

  final int id;
  final int page;
  final Signature signature;
  final bool isDateStamp;
  Offset pos;
  double widthFraction;
}

/// **PDF Form ve İmza tek yüzeyi** (P18 — Faz 61):
/// * **Form:** tüm AcroForm türleri (metin, çok satır, tarih seçici, onay,
///   radyo, liste, açılır, imza alanı) + profille otomatik doldurma + kilitle.
/// * **İmza:** serbest imza / baş harf / tarih damgası (çiz/yaz/görsel +
///   kayıtlı kitaplık), sayfa üzerinde sürükle ve boyutlandır.
/// * **Dijital imza (PAdES):** mevcut imzaları kriptografik olarak doğrula,
///   öz-imzalı kimlik ya da `.pfx/.p12` sertifikayla görünür/görünmez imzala.
class PdfFormScreen extends StatefulWidget {
  const PdfFormScreen({
    super.key,
    required this.path,
    this.initialTab = PdfFormTab.form,
  });

  final String path;
  final PdfFormTab initialTab;

  /// Kaydedilip özgün belgenin üzerine yazıldıysa `true` döner.
  static Future<bool?> open(
    BuildContext context,
    String path, {
    PdfFormTab initialTab = PdfFormTab.form,
  }) =>
      Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) => PdfFormScreen(path: path, initialTab: initialTab),
        ),
      );

  @override
  State<PdfFormScreen> createState() => _PdfFormScreenState();
}

class _PdfFormScreenState extends State<PdfFormScreen> {
  late PdfFormTab _tab = widget.initialTab;
  List<PdfFormFieldInfo>? _fields;
  List<PdfSignatureVerification> _verifications = const [];
  String? _error;
  bool _busy = false;
  int _pageCount = 1;

  /// Alan adı → kullanıcının verdiği değer (yalnız DEĞİŞENLER).
  final Map<String, String> _values = {};
  final Map<String, TextEditingController> _controllers = {};

  /// AcroForm imza alanı → seçilen/çizilen imza.
  final Map<PdfFormFieldInfo, Signature> _signs = {};

  /// Doldurulmuş form düzleştirilsin mi (alanlar kilitlensin mi)?
  bool _flatten = false;

  // ── Serbest imza sekmesi durumu ──
  int _signPage = 0;
  int _nextStampId = 1;
  final List<_PlacedStamp> _placed = [];
  int? _activeStampId;
  final Map<int, Size> _pageSizes = {};

  // ── Dijital imza sekmesi durumu ──
  SigningIdentity? _savedIdentity;
  bool _dsigUsePfx = false;
  bool _dsigVisible = true;
  bool _dsigLastPage = true;
  final _dsigNameCtl = TextEditingController();
  final _dsigReasonCtl = TextEditingController();
  final _dsigLocationCtl = TextEditingController();

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
    _dsigNameCtl.dispose();
    _dsigReasonCtl.dispose();
    _dsigLocationCtl.dispose();
    super.dispose();
  }

  void _partSetState(VoidCallback fn) {
    if (mounted) setState(fn);
  }

  Future<void> _load() async {
    try {
      final bytes = await File(widget.path).readAsBytes();
      final fields = await PdfFormFiller.read(bytes);
      final verifications = await PdfDigitalSign.verifyInBackground(bytes);
      int pages = 1;
      try {
        pages = await PdfTools.pageCount(bytes);
      } catch (_) {
        // Sayfa sayısı pdfrx'ten de gelir; yüklemeyi durdurma.
      }
      SigningIdentity? identity;
      try {
        identity = await PdfDigitalSign.loadIdentity();
      } catch (_) {
        // Test ortamında path_provider eklentisi olmayabilir.
      }
      Signature? defaultSig;
      if (widget.initialTab == PdfFormTab.sign) {
        try {
          defaultSig = await Signature.load();
        } catch (_) {
          // Kayıtlı imza yoksa kullanıcı araç çubuğundan ekler.
        }
      }
      if (!mounted) return;
      setState(() {
        _fields = fields;
        _verifications = verifications;
        _pageCount = math.max(1, pages);
        _savedIdentity = identity;
        if (identity != null && _dsigNameCtl.text.isEmpty) {
          _dsigNameCtl.text = identity.name;
        }
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
        if (defaultSig != null && _placed.isEmpty) {
          final st = _PlacedStamp(
            id: _nextStampId++,
            page: 0,
            signature: defaultSig,
            pos: const Offset(0.55, 0.75),
            widthFraction: 0.35,
          );
          _placed.add(st);
          _activeStampId = st.id;
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

  Future<void> _pickDate(PdfFormFieldInfo field) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: DateTime(1900),
      lastDate: DateTime(2100),
    );
    if (picked == null || !mounted) return;
    final formatted = _formatDate(picked);
    setState(() {
      _values[field.name] = formatted;
      _controllers[field.name]?.text = formatted;
    });
  }

  static String _formatDate(DateTime d) {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(d.day)}.${two(d.month)}.${d.year}';
  }

  /// İmza alanı sayfaya yerleştirilebilir mi (kutusu ve sayfası çözülmüş)?
  static bool _signable(PdfFormFieldInfo f) =>
      f.kind == PdfFormFieldKind.signature && f.bounds != null && f.page > 0;

  /// İmza alanı dokunuşu: çiz / yaz / görsel + kayıtlı imza penceresini açar.
  Future<void> _signField(PdfFormFieldInfo field) async {
    final sig = _signs.containsKey(field)
        ? await SignaturePad.show(context)
        : await Signature.load() ?? await _pad();
    if (sig != null && mounted) setState(() => _signs[field] = sig);
  }

  Future<Signature?> _pad({bool initials = false}) =>
      mounted ? SignaturePad.show(context, initials: initials) : Future.value();

  /// İmzayı alan kutusuna en-boy oranını koruyarak ortalar.
  static Rect _fit(Rect box, double aspect) {
    final w = box.width / box.height > aspect ? box.height * aspect : box.width;
    final h = w / aspect;
    return Rect.fromCenter(center: box.center, width: w, height: h);
  }

  Future<List<int>?> _loadFontAsset(String asset) async {
    try {
      return (await rootBundle.load(asset)).buffer.asUint8List();
    } catch (_) {
      return null;
    }
  }

  Future<List<int>> _stampSignature(
    List<int> pdfBytes, {
    required int pageIndex,
    required Signature signature,
    required Rect rect,
    required bool rawSpace,
    bool isDateStamp = false,
    List<int>? regularFont,
    List<int>? italicFont,
  }) =>
      switch (signature.kind) {
        SignatureKind.draw => PdfTools.stampStrokes(
            pdfBytes,
            pageIndex: pageIndex,
            strokes: signature.strokes,
            rect: rect,
            rawSpace: rawSpace,
          ),
        SignatureKind.type => PdfTools.stampText(
            pdfBytes,
            pageIndex: pageIndex,
            text: signature.text ?? '',
            rect: rect,
            fontBytes: isDateStamp ? regularFont : (italicFont ?? regularFont),
            rawSpace: rawSpace,
          ),
        SignatureKind.image => PdfTools.stampImage(
            pdfBytes,
            pageIndex: pageIndex,
            imageBytes: signature.imageBytes!,
            rect: rect,
            rawSpace: rawSpace,
          ),
      };

  Future<void> _save() async {
    if (_busy) return;
    final hasFormWork =
        (_fields != null && _fields!.isNotEmpty) &&
            (_values.isNotEmpty || _flatten);
    if (!hasFormWork && _signs.isEmpty && _placed.isEmpty) return;
    setState(() => _busy = true);
    try {
      final bytes = await File(widget.path).readAsBytes();
      final regularFont = await _loadFontAsset('assets/fonts/Carlito-Regular.ttf');
      final italicFont = await _loadFontAsset('assets/fonts/Tinos-Italic.ttf');
      List<int> out = bytes;
      if (hasFormWork) {
        out = await PdfFormFiller.fill(
          out,
          _values,
          flatten: _flatten,
          fontData: regularFont,
        );
      }
      for (final MapEntry(key: f, value: sig) in _signs.entries) {
        out = await _stampSignature(
          out,
          pageIndex: f.page - 1,
          signature: sig,
          rect: _fit(f.bounds!, sig.aspect),
          rawSpace: true,
          regularFont: regularFont,
          italicFont: italicFont,
        );
      }
      for (final st in _placed) {
        final sz = _pageSizes[st.page] ?? const Size(595, 842);
        final w = st.widthFraction * sz.width;
        final rect = Rect.fromLTWH(
          st.pos.dx * sz.width,
          st.pos.dy * sz.height,
          w,
          w / st.signature.aspect,
        );
        out = await _stampSignature(
          out,
          pageIndex: st.page,
          signature: st.signature,
          rect: rect,
          rawSpace: false,
          isDateStamp: st.isDateStamp,
          regularFont: regularFont,
          italicFont: italicFont,
        );
      }
      if (!mounted) return;
      setState(() => _busy = false);
      final signOnly = !hasFormWork && _signs.isEmpty && _placed.isNotEmpty;
      final note = signOnly
          ? context.t('sg.note')
          : context.t(_flatten ? 'pf.note_flat' : 'pf.note');
      final activityDetail = context.t(signOnly ? 'ps.act_signed' : 'ps.act_form');
      final outcome = await savePdfWithChoice(
        context,
        originalPath: widget.path,
        bytes: out,
        note: note,
        activityDetail: activityDetail,
      );
      if (outcome == null || !mounted) return;
      Navigator.of(context).pop(outcome.overwritten);
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      showSnack(context, context.t('pf.failed', {'error': userErrorText(e)}));
    }
  }

  Future<void> _applyDigitalSign() async {
    if (_busy) return;
    if (!await ProGate.check(context, Feature.pdfAdvanced)) return;
    if (!mounted) return;
    final name = _dsigNameCtl.text.trim();
    if (!_dsigUsePfx && name.isEmpty) {
      showSnack(context, context.t('pp.dsign_name_needed'));
      return;
    }
    List<int>? pfxBytes;
    String? pfxPass;
    if (_dsigUsePfx) {
      final res = await AppFilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pfx', 'p12'],
      );
      final pickedPath = res?.files.single.path;
      if (pickedPath == null || !mounted) return;
      pfxBytes = await File(pickedPath).readAsBytes();
      if (!mounted) return;
      pfxPass = await showAppPrompt(
        context,
        title: context.t('pp.dsign_pfx'),
        label: context.t('pp.dsign_pfx_password'),
        obscure: true,
      );
      if (pfxPass == null || !mounted) return;
    }
    setState(() => _busy = true);
    try {
      final bytes = await File(widget.path).readAsBytes();
      final fontBytes = await _loadFontAsset('assets/fonts/Carlito-Bold.ttf');
      final request = DigitalSignRequest(
        pageIndex: _dsigLastPage ? math.max(0, _pageCount - 1) : 0,
        bounds: null,
        visible: _dsigVisible,
        signerName: name.isEmpty ? 'e-İmza' : name,
        reason: _dsigReasonCtl.text.trim(),
        location: _dsigLocationCtl.text.trim(),
        signedAt: DateTime.now(),
        fontBytes: fontBytes,
      );
      List<int> out;
      if (_dsigUsePfx && pfxBytes != null && pfxPass != null) {
        out = await PdfDigitalSign.signWithPfxInBackground(
          bytes,
          pfx: pfxBytes,
          pfxPassword: pfxPass,
          request: request,
        );
      } else {
        var identity = _savedIdentity;
        if (identity == null || identity.name != name) {
          identity = await PdfDigitalSign.createIdentityInBackground(name);
          await PdfDigitalSign.saveIdentity(identity);
          if (mounted) _savedIdentity = identity;
        }
        out = await PdfDigitalSign.signWithIdentityInBackground(
          bytes,
          identity: identity,
          request: request,
        );
      }
      if (!mounted) return;
      setState(() => _busy = false);
      final outcome = await savePdfWithChoice(
        context,
        originalPath: widget.path,
        bytes: out,
        note: context.t('pp.dsign_done'),
        activityDetail: context.t('ps.act_signed'),
      );
      if (outcome == null || !mounted) return;
      Navigator.of(context).pop(outcome.overwritten);
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      showSnack(context, context.t('sg.failed', {'error': userErrorText(e)}));
    }
  }

  Future<void> _exportCert() async {
    final id = _savedIdentity;
    if (id == null) return;
    final certPath = await PdfDigitalSign.exportCertificate(id);
    await SharePlus.instance.share(ShareParams(files: [XFile(certPath)]));
  }

  bool get _dirty =>
      _values.isNotEmpty || _signs.isNotEmpty || _placed.isNotEmpty;

  bool get _hasDigitalSignature => _verifications.any((v) => v.signed);

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
          title: Text(
            context.t('pf.title_unified', {'name': p.basename(widget.path)}),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          actions: [
            if (_tab == PdfFormTab.form && fillable > 0)
              IconButton(
                tooltip: context.t('pp.autofill'),
                icon: const Icon(AppIcons.pdfAutofill),
                onPressed: _autofill,
              ),
            if (_tab == PdfFormTab.form && fillable > 0)
              IconButton(
                tooltip: context.t('pp.profile'),
                icon: const Icon(AppIcons.tune),
                onPressed: () => showAutofillProfileSheet(context),
              ),
          ],
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(
                  Gap.md, Gap.xs, Gap.md, Gap.xs),
              child: SegmentedButton<PdfFormTab>(
                key: const ValueKey('pf-tab-bar'),
                showSelectedIcon: false,
                segments: [
                  ButtonSegment(
                    value: PdfFormTab.form,
                    icon: const Icon(AppIcons.assignment, size: 18),
                    label: Text(context.t('pf.tab_form'),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                  ),
                  ButtonSegment(
                    value: PdfFormTab.sign,
                    icon: const Icon(AppIcons.draw, size: 18),
                    label: Text(context.t('pf.tab_sign'),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                  ),
                  ButtonSegment(
                    value: PdfFormTab.digital,
                    icon: const Icon(AppIcons.pdfSignCert, size: 18),
                    label: Text(context.t('pf.tab_digital'),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                  ),
                ],
                selected: {_tab},
                onSelectionChanged: (s) => setState(() => _tab = s.first),
              ),
            ),
            if (_busy) const LinearProgressIndicator(minHeight: 3),
            if (_hasDigitalSignature && _tab != PdfFormTab.digital)
              _signedWarningBanner(context),
            Expanded(
              child: switch (_tab) {
                PdfFormTab.form => _buildFormBody(context, fields),
                PdfFormTab.sign => _buildSignTab(context),
                PdfFormTab.digital => _buildDigitalTab(context),
              },
            ),
          ],
        ),
        bottomNavigationBar: _tab == PdfFormTab.form
            ? _formBottomBar(context, fields, fillable)
            : null,
      ),
    );
  }

  Widget _signedWarningBanner(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      key: const ValueKey('pf-signed-warn'),
      width: double.infinity,
      color: scheme.tertiaryContainer,
      padding:
          const EdgeInsetsDirectional.symmetric(horizontal: Gap.md, vertical: Gap.xs),
      child: Row(
        children: [
          Icon(AppIcons.warning, size: 18, color: scheme.onTertiaryContainer),
          const SizedBox(width: Gap.xs),
          Expanded(
            child: Text(
              context.t('pf.signed_warn'),
              style:
                  context.type.small.copyWith(color: scheme.onTertiaryContainer),
            ),
          ),
        ],
      ),
    );
  }

  Widget? _formBottomBar(
      BuildContext context, List<PdfFormFieldInfo>? fields, int fillable) {
    if (fields == null || (fields.isEmpty && _placed.isEmpty) ||
        (fillable == 0 && _placed.isEmpty)) {
      return null;
    }
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(Gap.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (fillable > 0)
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
    );
  }

  Widget _buildFormBody(BuildContext context, List<PdfFormFieldInfo>? fields) {
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(Gap.lg),
          child: Text(context.t('pf.failed', {'error': _error})),
        ),
      );
    }
    if (fields == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (fields.isEmpty) return _empty(context);
    return _list(context, fields);
  }

  Widget _empty(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(Gap.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(AppIcons.newText, size: 48, color: Paper.faint(context)),
              const SizedBox(height: Gap.md),
              Text(context.t('pf.no_fields'), textAlign: TextAlign.center),
              const SizedBox(height: Gap.sm),
              Text(context.t('pf.no_fields_hint'),
                  textAlign: TextAlign.center,
                  style: context.type.small
                      .copyWith(color: Paper.faint(context))),
              const SizedBox(height: Gap.md),
              OutlinedButton.icon(
                key: const ValueKey('pf-go-sign'),
                onPressed: () => setState(() => _tab = PdfFormTab.sign),
                icon: const Icon(AppIcons.draw),
                label: Text(context.t('pf.go_sign')),
              ),
            ],
          ),
        ),
      );

  Widget _list(BuildContext context, List<PdfFormFieldInfo> fields) {
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
      final sig = _signs[field];
      return ListTile(
        contentPadding: EdgeInsets.zero,
        leading: const Icon(AppIcons.gesture),
        title: Text(field.label),
        subtitle: Text(context.t(sig != null ? 'pf.signed' : 'pf.sign_tap')),
        trailing: sig == null
            ? null
            : SizedBox(
                width: 72,
                height: 36,
                child: SignaturePreview(signature: sig),
              ),
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
          onChanged: (v) => setState(
              () => _values[field.name] = v == true ? 'true' : 'false'),
          title: Text(field.label),
        );
      case PdfFormFieldKind.radio:
        final options = field.options.toSet().toList();
        final value = _values[field.name] ?? field.value;
        if (options.length <= 5) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: Gap.xs),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(field.label, style: context.type.label),
                const SizedBox(height: Gap.xs),
                Wrap(
                  spacing: Gap.xs,
                  runSpacing: Gap.xs,
                  children: [
                    for (final option in options)
                      ChoiceChip(
                        label: Text(option),
                        selected: value == option,
                        onSelected: (selected) {
                          if (selected) {
                            setState(() => _values[field.name] = option);
                          }
                        },
                      ),
                  ],
                ),
              ],
            ),
          );
        }
        return _dropdownField(field, options, value);
      case PdfFormFieldKind.combo:
      case PdfFormFieldKind.list:
        final options = field.options.toSet().toList();
        final value = _values[field.name] ?? field.value;
        return _dropdownField(field, options, value);
      case PdfFormFieldKind.text:
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: Gap.xs),
          child: TextField(
            controller: _controllers[field.name],
            decoration: InputDecoration(
              labelText: field.label,
              border: const OutlineInputBorder(),
              suffixIcon: field.isDateField
                  ? IconButton(
                      key: ValueKey('pf-date-${field.name}'),
                      tooltip: context.t('pf.pick_date'),
                      icon: const Icon(AppIcons.calendarMonth),
                      onPressed: () => _pickDate(field),
                    )
                  : null,
            ),
            textInputAction:
                field.multiline ? TextInputAction.newline : TextInputAction.next,
            keyboardType:
                field.multiline ? TextInputType.multiline : TextInputType.text,
            minLines: field.multiline ? 3 : 1,
            maxLines: field.multiline ? 6 : 1,
            onChanged: (v) => _values[field.name] = v,
          ),
        );
      case PdfFormFieldKind.signature:
      case PdfFormFieldKind.unknown:
        return const SizedBox.shrink();
    }
  }

  Widget _dropdownField(
      PdfFormFieldInfo field, List<String> options, String value) {
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
  }

  // ── Dijital imza (PAdES) sekmesi ─────────────────────────────────────────

  Widget _buildDigitalTab(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final locked = ProGate.locked(Feature.pdfAdvanced);
    return ListView(
      padding: withNavInset(
          context, const EdgeInsets.symmetric(horizontal: Gap.md, vertical: Gap.sm)),
      children: [
        Text(
          context.t('pf.dsig_verify_title'),
          style: Theme.of(context)
              .textTheme
              .titleSmall
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: Gap.xs),
        if (_verifications.isEmpty)
          Card(
            child: ListTile(
              leading: Icon(AppIcons.shield, color: scheme.onSurfaceVariant),
              title: Text(context.t('pp.dsign_none')),
            ),
          )
        else
          for (final v in _verifications) _verificationCard(context, v),
        const SizedBox(height: Gap.lg),
        Text(
          context.t('pf.dsig_sign_title'),
          style: Theme.of(context)
              .textTheme
              .titleSmall
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: Gap.sm),
        SegmentedButton<bool>(
          key: const ValueKey('pf-dsig-source'),
          showSelectedIcon: false,
          segments: [
            ButtonSegment(
              value: false,
              icon: const Icon(AppIcons.pdfSignCert, size: 18),
              label: Text(context.t('pf.dsig_self_opt')),
            ),
            ButtonSegment(
              value: true,
              icon: const Icon(AppIcons.key, size: 18),
              label: Text(context.t('pf.dsig_pfx_opt')),
            ),
          ],
          selected: {_dsigUsePfx},
          onSelectionChanged: (s) => setState(() => _dsigUsePfx = s.first),
        ),
        const SizedBox(height: Gap.sm),
        TextField(
          key: const ValueKey('pf-dsig-name'),
          controller: _dsigNameCtl,
          decoration: InputDecoration(
            labelText: context.t('pf.dsig_signer_name'),
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: Gap.sm),
        TextField(
          controller: _dsigReasonCtl,
          decoration: InputDecoration(
            labelText: context.t('pf.dsig_reason'),
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: Gap.sm),
        TextField(
          controller: _dsigLocationCtl,
          decoration: InputDecoration(
            labelText: context.t('pf.dsig_location'),
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: Gap.xs),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: _dsigVisible,
          onChanged: (v) => setState(() => _dsigVisible = v),
          title: Text(context.t('pf.dsig_visible')),
        ),
        if (_pageCount > 1 && _dsigVisible)
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _dsigLastPage,
            onChanged: (v) => setState(() => _dsigLastPage = v),
            title: Text(context.t('pf.dsig_last_page')),
          ),
        if (_savedIdentity != null && !_dsigUsePfx) ...[
          const SizedBox(height: Gap.xs),
          OutlinedButton.icon(
            onPressed: _busy ? null : _exportCert,
            icon: const Icon(AppIcons.share),
            label: Text(context.t('pp.dsign_export_cert')),
          ),
        ],
        const SizedBox(height: Gap.md),
        FilledButton.icon(
          key: const ValueKey('pf-dsig-submit'),
          onPressed: _busy ? null : _applyDigitalSign,
          icon: Icon(locked ? AppIcons.lock : AppIcons.pdfSignCert),
          label: Text(context.t(
              _dsigUsePfx ? 'pf.dsig_pick_pfx' : 'pp.dsign_go')),
        ),
        const SizedBox(height: Gap.lg),
      ],
    );
  }

  Widget _verificationCard(BuildContext context, PdfSignatureVerification v) {
    final scheme = Theme.of(context).colorScheme;
    final IconData icon;
    final Color color;
    final String statusText;
    if (!v.signed) {
      icon = AppIcons.draw;
      color = scheme.onSurfaceVariant;
      statusText = context.t('pp.dsign_empty_field');
    } else if (v.integrityValid && v.coversWholeDocument) {
      icon = AppIcons.verified;
      color = scheme.primary;
      statusText = context.t('pf.dsig_valid');
    } else if (v.integrityValid) {
      icon = AppIcons.warning;
      color = scheme.tertiary;
      statusText = context.t('pf.dsig_valid_partial');
    } else {
      icon = AppIcons.error;
      color = scheme.error;
      statusText = context.t('pf.dsig_invalid');
    }
    final details = <String>[
      statusText,
      if (v.signedAt != null) _formatDate(v.signedAt!),
      if (v.reason.isNotEmpty) v.reason,
      if (v.signed)
        v.selfSigned
            ? context.t('pf.dsig_self_signed')
            : (v.issuerName.isNotEmpty
                ? context.t('pf.dsig_issuer', {'name': v.issuerName})
                : ''),
    ].where((s) => s.isNotEmpty).join(' · ');

    return Card(
      key: ValueKey('pf-dsig-card-${v.fieldName}'),
      child: ListTile(
        leading: Icon(icon, color: color),
        title: Text(v.signerName.isNotEmpty ? v.signerName : v.fieldName),
        subtitle: Text(details),
      ),
    );
  }
}
