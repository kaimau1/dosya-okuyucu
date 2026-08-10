import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:provider/provider.dart';

import '../core/app_state.dart';
import '../core/copy_text.dart';
import '../core/l10n/app_strings.dart';
import '../services/pdf/pdf_ocr_text.dart';
import '../services/read_aloud_ai.dart';
import '../services/tts_service.dart';
import '../widgets/tts_voice_sheet.dart';

/// **Okuma görünümü** — PDF'i (taranmış olsa bile) bir e-kitap gibi sunar
/// (2026-08-06 kullanıcı isteği: *"tarandıktan sonra PDF'i okutmak
/// istediğimizde iyi bir e-kitap gibi okuyacak sistem kurmalıyız"*).
///
/// Sayfa görüntüsü yerine sayfanın **metni** akar: yazılmış PDF'te pdfium
/// metni, taranmış PDF'te cihaz-içi OCR ([PdfOcrText] — önbellekli, ücretsiz,
/// çevrimdışı). Metin [cleanPdfCopyText] ile toparlanır (satır kırıkları
/// birleşir, görünmez karakterler atılır) — kitap sayfası gibi okunur.
///
/// Punto büyütülüp küçültülebilir; zemin üçlüsü (açık/sepya/koyu) e-kitap
/// okuyucuların bilinen düzeni. Metin seçilebilir (kopyala/paylaş serbest).
class ReaderScreen extends StatefulWidget {
  final PdfDocument document;
  final String title;

  const ReaderScreen({super.key, required this.document, required this.title});

  static Future<void> open(
    BuildContext context, {
    required PdfDocument document,
    required String title,
  }) =>
      Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => ReaderScreen(document: document, title: title),
      ));

  @override
  State<ReaderScreen> createState() => _ReaderScreenState();
}

enum _ReaderTheme { light, sepia, dark }

class _ReaderScreenState extends State<ReaderScreen> {
  static const _minFont = 13.0, _maxFont = 30.0;

  /// Oturum içi hatırlanan tercihler (ekran kapanıp açılınca korunur;
  /// uygulama yeniden başlayınca varsayılana döner — kalıcılaştırmak istenirse
  /// AppState'e taşınır).
  static double _fontSize = 17;
  static _ReaderTheme _theme = _ReaderTheme.sepia;

  /// Sayfa metinleri (null = yüklenemedi/boş). Ekran ömrünce tutulur;
  /// OCR zaten `PdfOcrText` önbelleğinde, burası ikinci kez sormamak için.
  final _texts = <int, String?>{};
  final _loading = <int, Future<String?>>{};

  // ── Sesli kitap (2026-08-06 isteği: "e-kitap sesli kitap gibi okusun") ────
  /// Cihazın konuşma motoru — internet gerektirmez, görüntüleyicidekiyle
  /// aynı servis. Sayfa bitince kendiliğinden SONRAKİ sayfaya geçer.
  TtsService? _tts;

  /// Kullanıcı niyeti: sesli okuma açık mı? (Motorun anlık "konuşuyor"
  /// durumundan ayrı — sayfa arası metin yüklenirken de açık sayılır.)
  bool _speaking = false;

  /// Şu an okunan sayfa (1-tabanlı) — duraklatınca kaldığı yerden sürer.
  int _speakPage = 1;

  @override
  void dispose() {
    _tts?.dispose(); // ekran kapanınca konuşma sürmesin
    super.dispose();
  }

  /// "AI ile oku" ile toparlanmış sayfa metinleri — sayfa başına bir kez
  /// istenir (her duraklat/devam ettede yeniden istemek hem yavaş hem masraflı).
  final _narration = <int, String>{};

  Future<void> _toggleSpeech() async {
    final tts = _tts ??= TtsService()..onProgress = _onTtsProgress;
    // Ses/hız/perde tercihi her başlatışta tazelenir: kullanıcı okuma
    // sürerken ayarı değiştirebiliyor.
    tts.prefs = context.read<AppState>().ttsPrefs;
    if (_speaking) {
      // ÖNCE niyet kapatılır: pause bildirimi "sayfa bitti" sanılmasın.
      _speaking = false;
      await tts.pause();
      if (mounted) setState(() {});
      return;
    }
    setState(() => _speaking = true);
    // Duraklatılmış sayfa varsa kaldığı parçadan sür; yoksa sayfayı yükle.
    if (tts.total > 0) {
      await tts.resume();
      return;
    }
    await _speakCurrentPage();
  }

  Future<void> _speakCurrentPage() async {
    final page = _speakPage;
    var text = await _textFor(page);
    if (!mounted || !_speaking) return;
    if (text == null) {
      await _advanceSpeech(); // boş sayfa atlanır (kitaplarda kapak/ayraç)
      return;
    }
    // "AI ile oku": sayfa metni okunmadan önce toparlanır. Başarısız olursa
    // özgün metin okunur — okuma asla durmaz (bkz. ReadAloudAi).
    final state = context.read<AppState>();
    if (state.ttsAiRead && state.hasApiKey) {
      text = _narration[page] ??= await ReadAloudAi.tidyOrOriginal(
        state.gemini,
        text,
      );
      if (!mounted || !_speaking || page != _speakPage) return;
    }
    await _tts!.start(text);
  }

  void _onTtsProgress(int index, int total, bool playing) {
    if (!mounted) return;
    setState(() {});
    // Motor durdu ve sıra sıfırlandıysa sayfanın TAMAMI okundu (TtsService
    // bitişte stop → index 0). Kullanıcı duraklatması buraya düşmez:
    // [_toggleSpeech] niyeti önce kapatır.
    if (!playing && index == 0 && _speaking) _advanceSpeech();
  }

  Future<void> _advanceSpeech() async {
    if (!_speaking || !mounted) return;
    if (_speakPage >= widget.document.pages.length) {
      setState(() => _speaking = false); // kitap bitti
      return;
    }
    _speakPage++;
    await _speakCurrentPage();
  }

  Future<String?> _textFor(int pageNumber) {
    if (_texts.containsKey(pageNumber)) {
      return Future.value(_texts[pageNumber]);
    }
    return _loading[pageNumber] ??= _load(pageNumber);
  }

  Future<String?> _load(int pageNumber) async {
    String text = '';
    try {
      final page = widget.document.pages[pageNumber - 1];
      text = (await page.loadText()).fullText;
      // "İnce" metin (yalnız sayfa numarası gibi kırıntılar) = taranmış
      // sayfa → OCR (seçim katmanıyla aynı eşik ve aynı önbellek).
      if (text.trim().length < 8 && PdfOcrText.isSupported) {
        final ocr = await PdfOcrText.forPage(page);
        if (ocr != null) text = ocr.fullText;
      }
    } catch (_) {}
    final clean = cleanPdfCopyText(text);
    final result = clean.isEmpty ? null : clean;
    _texts[pageNumber] = result;
    _loading.remove(pageNumber);
    return result;
  }

  (Color bg, Color fg) get _colors => switch (_theme) {
        _ReaderTheme.light => (Colors.white, const Color(0xFF1F1F1F)),
        _ReaderTheme.sepia =>
          (const Color(0xFFF6EFDF), const Color(0xFF453A28)),
        _ReaderTheme.dark =>
          (const Color(0xFF121212), const Color(0xFFD5D5D5)),
      };

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = _colors;
    final pageCount = widget.document.pages.length;
    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        foregroundColor: fg,
        title: Text(widget.title,
            maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          // Sesli kitap: cihazın konuşma motoru sayfaları sırayla okur,
          // sayfa bitince kendiliğinden sonrakine geçer.
          IconButton(
            tooltip: context.t('vw.speak'),
            icon: Icon(_speaking
                ? Icons.pause_circle_outline
                : Icons.headphones_outlined),
            onPressed: _toggleSpeech,
          ),
          IconButton(
            tooltip: context.t('vw.text_smaller'),
            icon: const Icon(Icons.text_decrease),
            onPressed: _fontSize <= _minFont
                ? null
                : () => setState(() => _fontSize =
                    (_fontSize - 2).clamp(_minFont, _maxFont)),
          ),
          IconButton(
            tooltip: context.t('vw.text_bigger'),
            icon: const Icon(Icons.text_increase),
            onPressed: _fontSize >= _maxFont
                ? null
                : () => setState(() => _fontSize =
                    (_fontSize + 2).clamp(_minFont, _maxFont)),
          ),
          PopupMenuButton<_ReaderTheme>(
            tooltip: context.t('reader.theme'),
            icon: const Icon(Icons.palette_outlined),
            onSelected: (t) => setState(() => _theme = t),
            itemBuilder: (_) => [
              _themeItem(_ReaderTheme.light, context.t('reader.theme_light')),
              _themeItem(_ReaderTheme.sepia, context.t('reader.theme_sepia')),
              _themeItem(_ReaderTheme.dark, context.t('reader.theme_dark')),
            ],
          ),
          // Sesli okuma ayarları: ses seçimi (kalitenin asıl kaynağı) ve
          // "AI ile oku" anahtarı.
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: _onMenu,
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'voice',
                child: Row(children: [
                  const Icon(Icons.record_voice_over_outlined, size: 18),
                  const SizedBox(width: 8),
                  Text(context.t('tts.voice_settings')),
                ]),
              ),
              CheckedPopupMenuItem(
                value: 'ai',
                checked: context.watch<AppState>().ttsAiRead,
                child: Text(context.t('tts.ai_read')),
              ),
            ],
          ),
        ],
      ),
      body: ListView.builder(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 48),
        itemCount: pageCount,
        itemBuilder: (context, i) => _pageItem(context, i + 1, fg),
      ),
      // Sesli okuma sürerken küçük durum çubuğu: hangi sayfa, parça ilerlemesi.
      bottomNavigationBar: !_speaking
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.graphic_eq, size: 16, color: fg),
                    const SizedBox(width: 8),
                    Text(
                      '${context.t('tf.page_header', {'n': _speakPage})}'
                      '${(_tts?.total ?? 0) > 0 ? '  ·  ${(_tts!.index) + 1} / ${_tts!.total}' : ''}',
                      style: TextStyle(color: fg, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Future<void> _onMenu(String action) async {
    final state = context.read<AppState>();
    final messenger = ScaffoldMessenger.of(context);
    if (action == 'voice') {
      await TtsVoiceSheet.show(context);
      if (mounted) _tts?.prefs = context.read<AppState>().ttsPrefs;
      return;
    }
    if (action != 'ai') return;
    final next = !state.ttsAiRead;
    if (next && !state.hasApiKey) {
      messenger.showSnackBar(
          SnackBar(content: Text(AppStrings.current.t('tts.ai_needs_key'))));
      return;
    }
    await state.setTtsAiRead(next);
    // Anahtar değişince önceki toparlamalar geçersiz (biri ham, biri işlenmiş
    // metin okurdu).
    _narration.clear();
    messenger.showSnackBar(SnackBar(
      content: Text(AppStrings.current
          .t(next ? 'tts.ai_read_on' : 'tts.ai_read_off')),
    ));
  }

  PopupMenuItem<_ReaderTheme> _themeItem(_ReaderTheme value, String label) =>
      PopupMenuItem(
        value: value,
        child: Row(
          children: [
            Icon(_theme == value ? Icons.check : null, size: 18),
            const SizedBox(width: 8),
            Text(label),
          ],
        ),
      );

  Widget _pageItem(BuildContext context, int pageNumber, Color fg) {
    final divider = Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        children: [
          Expanded(child: Divider(color: fg.withValues(alpha: 0.25))),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Text(
              context.t('tf.page_header', {'n': pageNumber}),
              style: TextStyle(
                  color: fg.withValues(alpha: 0.55), fontSize: 12),
            ),
          ),
          Expanded(child: Divider(color: fg.withValues(alpha: 0.25))),
        ],
      ),
    );
    return FutureBuilder<String?>(
      future: _textFor(pageNumber),
      builder: (context, snap) {
        final Widget body;
        if (snap.connectionState != ConnectionState.done) {
          body = Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: fg.withValues(alpha: 0.5)),
              ),
            ),
          );
        } else if (snap.data == null) {
          body = Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
              context.t('reader.page_empty'),
              style: TextStyle(
                  color: fg.withValues(alpha: 0.5),
                  fontSize: _fontSize - 2,
                  fontStyle: FontStyle.italic),
            ),
          );
        } else {
          body = SelectableText(
            snap.data!,
            style: TextStyle(
              color: fg,
              fontSize: _fontSize,
              height: 1.55,
              fontFamily: 'Tinos', // kitap hissi: gömülü serif (OFL)
            ),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [if (pageNumber > 1) divider, body],
        );
      },
    );
  }
}
