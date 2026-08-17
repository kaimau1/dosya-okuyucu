import '../core/l10n/app_strings.dart';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

import '../services/docx_editor.dart' show RunSeg;
import 'office_shell.dart' show ZoomBadge, ZoomBadgeController;

/// .docx belgesini **Word'deki sayfa görünümüyle** çizer: sayfa kenarları,
/// stiller, tablolar, gömülü görseller, sütunlar. Canlı düzenleme modunda
/// sayfanın kendisi contenteditable olur; değişen paragraflar `Kalem`
/// kanalından `{i, segs:[[metin,b,i,u],…]}` olarak Flutter'a akar.
///
/// Çizimi `assets/word/` içine gömülü docx-preview motoru yapar; WebView yalnızca
/// yerel dosyaları yükler, internet erişimi yoktur.
// ponytail: Flutter'da docx sayfa akışını (satır kırma, sayfa sonu, stil mirası)
// elle yazmak yerine olgun bir motor gömüldü — sadakat farkı büyük, kod farkı ~40 satır.
class DocxView extends StatefulWidget {
  final Uint8List bytes;

  /// Belge **sağdan sola** bir bölüm mü (`w:sectPr/w:bidi`)? Gömülü
  /// docx-preview motoru bölüm düzeyindeki yönü yok saydığı için değer
  /// dışarıdan (`DocxEditor.rightToLeft`) verilir ve çizimden hemen sonra
  /// sayfaya uygulanır.
  final bool rightToLeft;

  /// Canlı düzenlemede bir paragraf değiştiğinde (indeks + biçimli parçalar).
  final void Function(int index, List<RunSeg> segs)? onEdited;

  /// Seçimin kalın/italik/altçizgi + yazı tipi/punto durumu değiştiğinde
  /// (araç çubuğu için). [font] boş, [sizePt] 0 ise okunamamış demektir.
  final void Function(
          bool bold, bool italic, bool underline, String font, double sizePt)?
      onSelection;

  /// Belgenin toplam sayfa sayısı çizildikten sonra bildirilir.
  final void Function(int pages)? onPageCount;

  /// Kaydırmayla görünen sayfa değiştiğinde (1 tabanlı).
  final void Function(int page)? onPage;

  /// Canlı görünümde bir paragrafın hizalaması değiştiğinde
  /// (indeks + 'left'|'center'|'right'|'both') — kaydetmede `w:jc` olur.
  final void Function(int index, String align)? onAlign;

  /// Sayfa görünümü başarıyla açıldı mı (false → çağıran yedek editöre geçer).
  final void Function(bool ok)? onStatus;

  /// WebView'daki paragraf sayısı beklenen sayıyla uyuşmazsa (eşleme sigortası).
  final void Function(int webCount)? onParagraphCount;

  /// Belge içi aramada bulunan eşleşme sayısı ([findAll] sonrası).
  final void Function(int hits)? onFindCount;

  /// "Tümünü değiştir" kaç yeri değiştirdi.
  final void Function(int count)? onReplacedCount;

  /// [requestSelectionText] sonrası seçili metin (seçim yoksa boş).
  final void Function(String text)? onSelectionText;

  /// Paragrafın madde/numara biçimi değiştiğinde
  /// (indeks + 'bullet'|'number'|'none') — kaydetmede `w:numPr` olur.
  final void Function(int index, String kind)? onListStyle;

  const DocxView({
    super.key,
    required this.bytes,
    this.rightToLeft = false,
    this.onEdited,
    this.onSelection,
    this.onAlign,
    this.onStatus,
    this.onParagraphCount,
    this.onPageCount,
    this.onPage,
    this.onFindCount,
    this.onReplacedCount,
    this.onSelectionText,
    this.onListStyle,
  });

  @override
  State<DocxView> createState() => DocxViewState();
}

class DocxViewState extends State<DocxView> {
  late final WebViewController _controller;
  bool _loading = true;
  String? _error;

  /// Sayfanın o anki toplam ölçeği (sığdırma × kullanıcı çarpanı) — rozet için.
  /// Değeri JS bildirir; Flutter tarafı kendi başına hesaplayamaz. (Bu köprü
  /// olmadığı için Word'de zoom yüzdesi rozeti yoktu — KALANLAR maddesi.)
  double _zoom = 1.0;
  late final _badge = ZoomBadgeController(setState);

  /// Yakınlaştırma **tek yoldan** yapılır: JS'teki `zoomBy` CSS `zoom`
  /// değiştirir ve tarayıcı metni yeniden dizer (keskin kalır). Native
  /// WebView pinch'i bilinçli KAPALI — o çizilmiş kareyi büyütüp
  /// bulanıklaştırıyordu (2026-08-01 kullanıcı bulgusu).
  void _zoomBy(double f) => _controller.runJavaScript('zoomBy($f)');

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFFF3F2F1)) // Fluent kanvas
      ..enableZoom(false)
      ..addJavaScriptChannel('Sayfa', onMessageReceived: _onSayfa)
      ..addJavaScriptChannel('Durum', onMessageReceived: (m) {
        if (!mounted) return;
        final err = m.message.startsWith('hata') ? m.message : null;
        setState(() {
          _loading = false;
          _error = err;
        });
        widget.onStatus?.call(err == null);
      })
      ..addJavaScriptChannel('Kalem', onMessageReceived: _onKalem)
      ..setNavigationDelegate(NavigationDelegate(
        onPageFinished: (_) => _render(),
        // (aşağıda `_lockWebViewTextSize` ile sistem yazı boyutu etkisizleşir)
        onWebResourceError: (e) {
          if (!mounted) return;
          setState(() {
            _loading = false;
            _error = e.description;
          });
          widget.onStatus?.call(false);
        },
      ))
      ..loadFlutterAsset('assets/word/viewer.html');
    _lockWebViewTextSize();
  }

  /// **Belge her telefonda aynı boyutta** (kullanıcı isteği 2026-08-07).
  ///
  /// Android WebView'ın kendi metin yakınlaştırması cihazın "Yazı tipi boyutu"
  /// sistem ayarını izler: aynı .docx, sistem yazısını büyütmüş bir telefonda
  /// bambaşka sarıyor ve sayfa sayısı bile tutmuyordu. Flutter tarafındaki
  /// ölçek kilidi (bkz. `DosyaOkuyucuApp.builder`) WebView'a işlemez — ayarı
  /// burada %100'e sabitliyoruz. Android dışında sessizce geçilir.
  void _lockWebViewTextSize() {
    final platform = _controller.platform;
    if (platform is AndroidWebViewController) {
      platform.setTextZoom(100);
    }
  }

  void _onKalem(JavaScriptMessage m) {
    if (!mounted) return;
    final dynamic data;
    try {
      data = jsonDecode(m.message);
    } catch (_) {
      return;
    }
    if (data is! Map) return;
    if (data['n'] is int) {
      widget.onParagraphCount?.call(data['n'] as int);
      return;
    }
    if (data['sel'] is Map) {
      final s = data['sel'] as Map;
      widget.onSelection?.call(
        s['b'] == true,
        s['i'] == true,
        s['u'] == true,
        '${s['font'] ?? ''}',
        (s['size'] as num?)?.toDouble() ?? 0,
      );
      return;
    }
    if (data['find'] is Map) {
      final n = (data['find'] as Map)['n'];
      if (n is int) widget.onFindCount?.call(n);
      return;
    }
    if (data['replaced'] is int) {
      widget.onReplacedCount?.call(data['replaced'] as int);
      return;
    }
    if (data['seltext'] is String) {
      widget.onSelectionText?.call(data['seltext'] as String);
      return;
    }
    if (data['list'] is Map) {
      final l = data['list'] as Map;
      if (l['i'] is int && l['v'] is String) {
        widget.onListStyle?.call(l['i'] as int, l['v'] as String);
      }
      return;
    }
    if (data['a'] is Map) {
      final a = data['a'] as Map;
      if (a['i'] is int && a['v'] is String) {
        widget.onAlign?.call(a['i'] as int, a['v'] as String);
      }
      return;
    }
    if (data['i'] is int && data['segs'] is List) {
      final segs = <RunSeg>[
        for (final seg in data['segs'] as List)
          if (seg is List && seg.isNotEmpty)
            RunSeg(
              '${seg[0]}',
              seg.length > 1 && seg[1] == true,
              seg.length > 2 && seg[2] == true,
              seg.length > 3 && seg[3] == true,
              // 5.–8. alanlar yalnız kullanıcı yazı tipi/punto/renk/vurgu
              // SEÇTİYSE dolu gelir; null ise dosyadaki biçim korunur
              // (bkz. viewer.html).
              font: _str(seg, 4),
              sizePt: seg.length > 5 && seg[5] is num && (seg[5] as num) > 0
                  ? (seg[5] as num).toDouble()
                  : null,
              color: _str(seg, 6),
              highlight: _str(seg, 7),
            ),
      ];
      widget.onEdited?.call(data['i'] as int, segs);
    }
  }

  /// JS'ten gelen parçanın [at]. alanı — dolu bir metin değilse null.
  static String? _str(List seg, int at) {
    if (seg.length <= at) return null;
    final v = seg[at];
    return v is String && v.isNotEmpty ? v : null;
  }

  /// Sayfa sayacı ve yakınlaştırma oranı kanalı.
  void _onSayfa(JavaScriptMessage m) {
    if (!mounted) return;
    final dynamic data;
    try {
      data = jsonDecode(m.message);
    } catch (_) {
      return;
    }
    if (data is! Map) return;
    if (data['pages'] is int) widget.onPageCount?.call(data['pages'] as int);
    if (data['page'] is int) widget.onPage?.call(data['page'] as int);
    if (data['zoom'] is num) {
      final z = (data['zoom'] as num).toDouble();
      if ((z - _zoom).abs() > 0.001) {
        setState(() => _zoom = z);
        _badge.bump(z);
      }
    }
  }

  /// Canlı düzenlemeyi açar/kapatır (sayfa contenteditable olur).
  void setEditing(bool on) =>
      _controller.runJavaScript('setEditable($on)');

  /// Seçime biçim uygular: 'bold' | 'italic' | 'underline'.
  void format(String cmd) => _controller.runJavaScript("fmt('$cmd')");

  /// Seçili paragraf(lar)ın yazı tipini değiştirir. Tek tırnak kaçırılır:
  /// font adları ("Book Antiqua" gibi) boşluk içerebilir, tırnak da içerebilir.
  void setFontFamily(String name) => _controller
      .runJavaScript("setFontFamily('${name.replaceAll("'", r"\'")}')");

  /// Seçili paragraf(lar)ın puntosunu değiştirir.
  void setFontSize(double pt) =>
      _controller.runJavaScript('setFontSize($pt)');

  /// Seçili metnin **yazı rengi**. [hex] `RRGGBB`; null = rengi kaldır.
  void setTextColor(String? hex) => _controller
      .runJavaScript(hex == null ? 'setTextColor(null)' : "setTextColor('$hex')");

  /// Seçili metnin **vurgu (fosforlu kalem) rengi**. null = vurguyu kaldır.
  void setHighlight(String? hex) => _controller
      .runJavaScript(hex == null ? 'setHighlight(null)' : "setHighlight('$hex')");

  /// Seçili paragraflara madde işareti / numaralandırma verir (aynı biçim
  /// yeniden verilirse kaldırır). 'bullet' | 'number' | 'none'.
  void setListStyle(String kind) =>
      _controller.runJavaScript("setListStyle('$kind')");

  /// [requestSelectionText] ile alınan seçimin yerine [text] yazar
  /// (AI ile yeniden yazma / çeviri sonucu).
  void replaceSelectionText(String text) =>
      _controller.runJavaScript("replaceSelectionText('${_js(text)}')");

  /// Seçili metni [DocxView.onSelectionText] üzerinden ister.
  void requestSelectionText() =>
      _controller.runJavaScript('sendSelectionText()');

  /// Belgede arar; sonuç [DocxView.onFindCount] ile döner.
  /// Tek tırnak kaçırılır (kullanıcı metni serbest).
  void findAll(String query) =>
      _controller.runJavaScript("findAll('${_js(query)}')");

  /// [k]. eşleşmeye kaydırır ve seçer (0 tabanlı).
  void findGo(int k) => _controller.runJavaScript('findGo($k)');

  /// [k]. eşleşmeyi [text] ile değiştirir.
  void replaceHit(int k, String text) =>
      _controller.runJavaScript("replaceHit($k, '${_js(text)}')");

  /// Tümünü değiştirir; sonuç [DocxView.onReplacedCount] ile döner.
  void replaceAll(String query, String text) => _controller
      .runJavaScript("replaceAll('${_js(query)}', '${_js(text)}')");

  /// JS tek tırnaklı dizgeye gömülecek metin: ters bölü, tırnak ve satır sonu.
  static String _js(String s) => s
      .replaceAll(r'\', r'\\')
      .replaceAll("'", r"\'")
      .replaceAll('\n', r'\n')
      .replaceAll('\r', '');

  /// Belirtilen (1 tabanlı) Word sayfasına kaydırır.
  void goToPage(int page) => _controller.runJavaScript('goToPage($page)');

  /// Belge yönünü günceller (sayfa çizildikten sonra da çağrılabilir).
  void setDocDir(bool rtl) =>
      _controller.runJavaScript('setDocDir($rtl)');

  /// Mobil akış görünümü: sayfanın sabit A4 genişliği kalkar, paragraflar
  /// ekrana sarılır → yazı gerçek boyutunda okunur (bkz. `viewer.html`).
  void setFlow(bool on) {
    _zoom = 1.0;
    _controller.runJavaScript('setFlow($on)');
  }

  /// Belge WebView'a base64 metin olarak aktarılır; çok büyük dosyalarda bu
  /// aktarım cihazı zorlar, o yüzden sınır var.
  static const _maxBytes = 12 * 1024 * 1024;

  Future<void> _render() async {
    if (widget.bytes.length > _maxBytes) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = AppStrings.current.t('dv.too_big',
            {'mb': (widget.bytes.length / 1048576).round()});
      });
      widget.onStatus?.call(false);
      return;
    }
    // Yön çizimden ÖNCE kurulur: docx-preview sayfayı yerleştirirken gövde
    // zaten rtl olur, sonradan çevirip yeniden ölçmek gerekmez (fitPage
    // genişliği bir kez ölçüyor).
    await _controller.runJavaScript('setDocDir(${widget.rightToLeft})');
    final b64 = base64Encode(widget.bytes);
    await _controller.runJavaScript("renderDocx('$b64')");
  }

  /// Android'de WebView **hybrid composition** ile çizilir (2026-08-06
  /// kullanıcı bulgusu: *"tam sayfada uzaktan bakarken de net görünsün"*).
  ///
  /// Varsayılan yol (Texture Layer) WebView'ın çıktısını bir Flutter dokusuna
  /// alıp sahneye örnekleyerek basar; ~%50 sığdırma ölçeğindeki küçük harfler
  /// bu ek yeniden örneklemede yumuşuyordu (yakınlaşınca harfler büyüdüğü
  /// için fark kayboluyordu — kullanıcının tarifiyle birebir). Hybrid
  /// composition WebView'ı GERÇEK bir platform görünümü olarak, kendi
  /// çözünürlüğünde ekrana koyar — ara doku yok, metin motorun çizdiği
  /// keskinlikte kalır. Bedeli (biraz daha yüksek bellek/kompozisyon
  /// maliyeti) belge ekranı için kabul edilebilir.
  Widget _webView() {
    final platform = _controller.platform;
    if (platform is AndroidWebViewController) {
      return WebViewWidget.fromPlatformCreationParams(
        params: AndroidWebViewWidgetCreationParams(
          controller: platform,
          displayWithHybridComposition: true,
        ),
      );
    }
    return WebViewWidget(controller: _controller);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        _webView(),
        if (_loading)
          const Center(child: CircularProgressIndicator())
        else if (_error != null)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                context.t('dv.fallback', {'error': _error}),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        // Yakınlaştır/uzaklaştır (pinch'e ek, garanti kontrol).
        //
        // SOLDA duruyor: sağ altta ekranın AI düğmesi (FAB) var ve düğmeler
        // onun altında kalıyordu (2026-08-01 kullanıcı ekran görüntüsü).
        //
        // **Sistem çubuğu payı (2026-08-17 kullanıcı ekran görüntüsü:
        // "büyüteç işaretleri telefonun kendi araç çubuğunun altında
        // kalıyor").** `OfficeShell` alt sistem çubuğunun payını yalnız
        // `bottomBar` VARKEN bırakıyor; düzenleme sırasında o çubuk gizleniyor
        // (klavye + biçim şeridi zaten yer kaplıyor) ve gövde ekranın en altına
        // kadar uzuyor — alttaki uzaklaştır düğmesi geri/ana menü çubuğunun
        // altında kalıyordu. `paddingOf` klavye açıkken kendiliğinden 0 olur
        // (insets payı yutar), yani klavyeliyken düğmeler fazladan yükselmez.
        if (_error == null)
          Positioned(
            left: 12,
            bottom: 12 + MediaQuery.paddingOf(context).bottom,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _ZoomBtn(icon: Icons.zoom_in, onTap: () => _zoomBy(1.25)),
                const SizedBox(height: 8),
                _ZoomBtn(icon: Icons.zoom_out, onTap: () => _zoomBy(1 / 1.25)),
              ],
            ),
          ),
        // Ölçek yüzdesi rozeti (Excel/slaytlardaki ile aynı).
        if (_error == null)
          Positioned(
            top: 12,
            left: 0,
            right: 0,
            child: Center(
              child: ZoomBadge(zoom: _badge.zoom, visible: _badge.visible),
            ),
          ),
      ],
    );
  }

  @override
  void dispose() {
    _badge.dispose();
    super.dispose();
  }
}

/// Yarı saydam yuvarlak zoom düğmesi (WebView üstünde yüzer).
class _ZoomBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _ZoomBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surface.withValues(alpha: 0.92),
      shape: const CircleBorder(),
      elevation: 2,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Icon(icon, size: 22, color: scheme.onSurface),
        ),
      ),
    );
  }
}
