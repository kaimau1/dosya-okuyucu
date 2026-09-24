import 'package:flutter/gestures.dart' show kDoubleTapTimeout, kTouchSlop;
import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';

/// **Sayfa üzerinde yerinde metin düzenleme kutusu.**
///
/// Kullanıcı isteği (2026-07-26): *"sayfa üzerinde yeni bir alan açılmadan
/// klavyeden değişiklik yapabilmeliyim, sanki orijinali oymuş gibi olmalı."*
/// Eskiden "Düzenle" ayrı bir EKRAN açıyordu: belge gözden kayboluyor, metin
/// bağlamından kopuyor ve düzeltmenin sayfada nasıl duracağı görülmüyordu.
///
/// Artık kutu, seçili metnin TAM ÜSTÜNDE açılıyor: aynı yerde, aynı satır
/// yüksekliğinde, klavye hemen geliyor. Kaydedilince belgenin kendi metni
/// değiştiği için sonuç "sanki hep öyleymiş gibi" duruyor
/// (bkz. `PdfContentEditor`).
///
/// **Punto nasıl bulunuyor.** Önce karakter kutusunun yüksekliği sabit bir
/// katsayıyla çarpılıyordu; kullanıcı *"yazı fontu boyutu vs hepsi korunmalı,
/// sanki o yazıya aitmiş gibi olmalı"* dedi çünkü katsayı belgeden belgeye
/// tutmuyordu. Şimdi punto **ölçülerek** bulunuyor: özgün metin, seçimin
/// ekrandaki genişliğini verecek puntoda çiziliyor.
///
/// **Düğmeler burada DEĞİL** (2026-07-26, 8. tur): vazgeç / AI / uygula
/// çubuğu ekranın altında, `ViewerScreen` içinde duruyor. Sebebi
/// `ViewerScreen._editBar`'da yazılı — kısaca pdfrx'in köprü katmanı sayfa
/// katmanlarının üstünde bir tap tanıyıcısı kuruyor ve buradaki düğmelere
/// basılamıyordu. Metin kutusunun kendisi çalışıyor (metin alanı tanıyıcısı
/// arenayı erken kazanır), o yüzden yalnız o kaldı.
class PdfInlineEditor extends StatelessWidget {
  const PdfInlineEditor({
    super.key,
    required this.page,
    required this.pageSize,
    required this.rects,
    required this.original,
    required this.controller,
    required this.focusNode,
    required this.onSubmit,
    this.busy = false,
    this.fieldKey,
  });

  /// `TextField`in anahtarı — `ViewerScreen` imleç düğmelerinden sonra
  /// klavyeyi yeniden açabilmek için alanın içindeki `EditableText`e
  /// ulaşıyor (bkz. [showKeyboard]).
  final GlobalKey? fieldKey;

  /// Yazı tipi: **Arimo** (Arial/Helvetica metriği), arayüzün yazı tipi DEĞİL.
  ///
  /// Kutu temadan yazı tipi devralıyordu: kullanıcı arayüzde tek aralıklı
  /// bir yazı tipi seçmişse PDF'in üstünde daktilo yazısı çıkıyordu
  /// (2026-09-24 ekran görüntüsü). PDF'lerin ezici çoğunluğu Arial/Helvetica
  /// ailesinde; punto zaten genişliğe göre ölçülerek bulunuyor.
  static const String fontFamily = 'Arimo';

  /// Kutunun çevresindeki saydam dokunma payı (testler bununla buluyor).
  static const Key padKey = ValueKey('pdf-inline-edit-pad');

  /// **Klavyeyi AÇ — odak zaten kutudaysa bile.**
  ///
  /// KÖK NEDEN (kullanıcı 2026-09-24: *"klavye ilk basınca açılıyor ancak
  /// sonra açılmıyor, değişiklik yapılamıyor"*): klavye Android'in geri
  /// tuşuyla ya da kaydırırken kapanınca odak kutuda KALIYOR. Eski kod
  /// `if (!hasFocus) requestFocus()` diyordu → odak zaten var, hiçbir şey
  /// olmuyordu. Kutuya dokunmak da kurtarmıyordu: pdfrx'in köprü katmanı
  /// (sayfa katmanlarının ÜSTÜNDE, translucent bir tap tanıyıcısı) dokunma
  /// arenasına önce giriyor ve `TextField`in kendi "dokununca klavyeyi aç"
  /// işleyicisi çoğu kez ateşlenmiyordu.
  ///
  /// `EditableTextState.requestKeyboard` iki durumu da kapsıyor: odak yoksa
  /// ister, varsa giriş bağlantısını açar/klavyeyi yeniden gösterir.
  static void showKeyboard(BuildContext? fieldContext, FocusNode focusNode) {
    final editable = fieldContext == null ? null : _findEditable(fieldContext);
    if (editable != null && editable.mounted) {
      editable.requestKeyboard();
    } else if (!focusNode.hasFocus) {
      focusNode.requestFocus();
    }
  }

  static EditableTextState? _findEditable(BuildContext context) {
    EditableTextState? found;
    void visit(Element e) {
      if (found != null) return;
      if (e is StatefulElement && e.state is EditableTextState) {
        found = e.state as EditableTextState;
        return;
      }
      e.visitChildElements(visit);
    }

    if (context is StatefulElement && context.state is EditableTextState) {
      return context.state as EditableTextState;
    }
    (context as Element).visitChildElements(visit);
    return found;
  }

  final PdfPage page;

  /// Sayfanın ekrandaki (ölçekli) boyutu.
  final Size pageSize;

  /// Düzenlenen metnin PDF-koordinat dikdörtgenleri (satır başına bir).
  final List<PdfRect> rects;

  final String original;

  /// Metin denetleyicisi **dışarıda** (ViewerScreen) tutuluyor: alttaki
  /// düğme çubuğu da aynı metni okuyor.
  final TextEditingController controller;

  /// Odak düğümü de **dışarıda** — ve sebebi denetleyiciden farklı:
  /// bu katman pdfrx tarafından kaydırma/yakınlaştırmada yeniden kuruluyor.
  /// `autofocus` yalnız ilk kurulumda çalıştığı için klavye açılmıyordu
  /// (kullanıcı hatası 2026-08-29). Düğüm ağacın dışında yaşayınca yeniden
  /// kurulan `TextField` aynı odağa bağlanıyor ve klavye ayakta kalıyor.
  final FocusNode focusNode;

  /// Klavyenin "bitti" tuşu — tek satırlık metinde doğrudan uygular.
  final VoidCallback onSubmit;

  /// Kaydetme sürerken kutu kilitlenir.
  final bool busy;

  /// Bir parmağın rahatça isabet ettirebileceği en küçük yükseklik (Material
  /// dokunma hedefi 48 dp; burada kutu zaten yazının üstünde durduğu için
  /// 44 yetiyor ve komşu satırları daha az örtüyor).
  static const double _minTouch = 44;

  /// Dokunulan noktaya imleci taşır.
  ///
  /// İki yerden çağrılıyor: kutunun DIŞINDAKİ dokunma payından (yalnız
  /// sütun anlamlı) ve kutunun İÇİNDEN ([_TapToType]) — içeride
  /// `TextField`in kendi imleç yerleştirmesi arenayı pdfrx'e kaptırınca hiç
  /// çalışmıyordu. [offset] kutunun sol-üst köşesinden, yani metnin kendi
  /// başlangıcından ölçülüdür.
  void _placeCaret(Offset offset, double fontSize, double maxWidth) {
    final text = controller.text;
    if (text.isEmpty) return;
    // Aynı biçimle ölçülür — kutunun içindeki yazının birebir aynısı, yoksa
    // imleç dokunulan harfin yanına değil birkaç harf ötesine düşerdi.
    final painter = TextPainter(
      text: TextSpan(text: text, style: _style(fontSize)),
      strutStyle: _strut(fontSize),
      textDirection: TextDirection.ltr,
      maxLines: original.contains('\n') ? null : 1,
    )..layout(maxWidth: original.contains('\n') ? maxWidth : double.infinity);
    final position = painter.getPositionForOffset(offset);
    painter.dispose();
    controller.selection = TextSelection.collapsed(
      offset: position.offset.clamp(0, text.length),
      affinity: position.affinity,
    );
  }

  static TextStyle _style(double fontSize) => TextStyle(
        fontFamily: fontFamily,
        fontSize: fontSize,
        // height 1.0: satır kutusu puntoyla aynı kalsın, yazı özgün satırın
        // üstünde/altında kaymasın.
        height: 1.0,
        color: Colors.black,
      );

  static StrutStyle _strut(double fontSize) => StrutStyle(
        fontFamily: fontFamily,
        fontSize: fontSize,
        height: 1.0,
        forceStrutHeight: true,
      );

  /// Seçili satırların ekran dikdörtgeni (hepsini kapsayan).
  Rect? get _box {
    Rect? out;
    for (final r in rects) {
      final rect = r.toRect(page: page, scaledPageSize: pageSize);
      out = out == null ? rect : out.expandToInclude(rect);
    }
    return out;
  }

  /// Tek satırın yüksekliği — punto tahmininin başlangıcı buradan gelir.
  double get _lineHeight {
    if (rects.isEmpty) return 14;
    final first = rects.first.toRect(page: page, scaledPageSize: pageSize);
    return first.height <= 0 ? 14 : first.height;
  }

  /// Özgün metni seçimin ekrandaki GENİŞLİĞİNE oturtan punto.
  ///
  /// pdfium'un karakter kutusu yaklaşık yazı bloğu yüksekliğidir; ondan
  /// hesaplanan punto başlangıç tahminidir. Sonra özgün metin o puntoda
  /// ölçülür ve genişlik oranıyla düzeltilir — belgenin fontu dar da olsa
  /// geniş de olsa yazı aynı yeri kaplar, yani "o yazıya aitmiş gibi" durur.
  ///
  /// Oran [0.7, 1.4] arasında kısılıyor: seçim tek harf ya da çok boşluklu
  /// olduğunda ölçüm yanıltıcı olabilir, saçma bir puntoya savrulmayalım.
  double _fontSizeFor(Rect box) {
    final base = (_lineHeight * 0.86).clamp(6.0, 120.0);
    if (original.trim().isEmpty || box.width <= 1 || original.contains('\n')) {
      return base;
    }
    final painter = TextPainter(
      text: TextSpan(
        text: original,
        style: _style(base),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();
    final measured = painter.width;
    painter.dispose();
    if (measured <= 1) return base;
    final ratio = (box.width / measured).clamp(0.7, 1.4);
    return (base * ratio).clamp(6.0, 120.0);
  }

  @override
  Widget build(BuildContext context) {
    final box = _box;
    if (box == null) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    final fontSize = _fontSizeFor(box);
    final multiline = original.contains('\n');
    // Birkaç harf sağa yer bırakılır (yeni metin biraz uzun olabilir) ama
    // fazlası komşu yazıyı beyaza boyardı; gerisi kutunun içinde kayar.
    final width = (box.width + 14).clamp(48.0, pageSize.width - box.left);

    // **Dokunma alanı yazıdan BÜYÜK** (kullanıcı 2026-08-30: *"imleç zor
    // hareket ediyor, tıklayınca orayı odaklamıyor"*).
    //
    // KÖK NEDEN: kutu yazının TAM ölçüsündeydi. Gövde metni %100
    // yakınlaştırmada 10-14 dp yüksekliğinde çiziliyor; yani dokunulabilir
    // hedef bir parmağın (Material'in kendi ölçüsüyle 48 dp) dörtte biri
    // kadardı. Satırın bir iki piksel üstüne ya da altına gelen dokunuş
    // `TextField`e HİÇ ulaşmıyor, altındaki pdfrx katmanına düşüyordu:
    // kullanıcı ekrana basıyor, imleç kıpırdamıyor.
    //
    // Çözüm yazıyı büyütmek DEĞİL (o zaman "sanki o yazıya aitmiş gibi"
    // ilkesi bozulurdu): kutunun çevresine saydam bir dokunma payı konuyor.
    // Yazının kendisi ve beyaz kapak eskisi gibi tam yerinde duruyor —
    // değişen yalnız dokunuşun nereye kadar sayıldığı.
    final pad =
        multiline ? 0.0 : ((_minTouch - box.height) / 2).clamp(0.0, 18.0);
    const hpad = 10.0;

    // Positioned.fill: katman sayfanın tamamını kaplar, içindeki konumlar
    // doğrudan sayfa koordinatı olur (PdfSelectLayer ile aynı düzen).
    return Positioned.fill(
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Pay yalnız KÜÇÜK (tek satırlık) kutuda gerekiyor: çok satırlı
          // bir paragraf kutusu zaten parmakla rahat isabet edilecek
          // yükseklikte ve orada yan dokunuşu tek satırlık ölçümle
          // eşlemek imleci yanlış satıra koyardı.
          if (pad > 0)
            Positioned(
              left: box.left - hpad,
              top: box.top - pad,
              width: width + hpad * 2,
              height: box.height + pad * 2,
              // Yığında metin kutusunun ALTINDA: dokunuş önce kutunun
              // kendisine gider (isabetli dokunuşta Flutter'ın kendi imleç
              // yerleştirmesi çalışır), yalnız kutunun DIŞINA düşen — ama
              // paya giren — dokunuşlar buraya gelir.
              //
              // Ham işaretçi olayı (Listener), `GestureDetector` değil: tap
              // tanıyıcısı pdfrx'in köprü tanıyıcısına arenayı kaptırınca
              // hızlı dokunuşta hiç ateşlenmiyordu.
              child: _TapToType(
                key: padKey,
                enabled: !busy,
                behavior: HitTestBehavior.opaque,
                onTap: (local) => _placeCaret(
                    Offset(local.dx - hpad, fontSize / 2), fontSize, width),
                onShowKeyboard: (ctx) =>
                    showKeyboard(fieldKey?.currentContext, focusNode),
                child: const SizedBox.expand(),
              ),
            ),
          Positioned(
            left: box.left,
            top: box.top,
            width: width,
            child: Container(
              // Kağıt beyazı ve TAM eski yazının üstünde: altındaki eski yazı
              // okunmasın, ama çevresinde kutu/çerçeve görünmesin. Gece modunda
              // sayfayla birlikte terslendiği için uyum bozulmaz.
              constraints: BoxConstraints(minHeight: box.height),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(
                  // Tek görsel işaret: ince alt çizgi. Çerçeve yerine bu,
                  // çünkü çerçeve "ayrı bir kutu" hissi veriyordu.
                  bottom: BorderSide(color: scheme.primary, width: 1.2),
                ),
              ),
              child: _TapToType(
                enabled: !busy,
                onTap: (local) {
                  _placeCaret(local, fontSize, width);
                },
                onShowKeyboard: (ctx) =>
                    showKeyboard(fieldKey?.currentContext ?? ctx, focusNode),
                child: TextField(
                  key: fieldKey,
                  controller: controller,
                  focusNode: focusNode,
                  enabled: !busy,
                  maxLines: multiline ? null : 1,
                  keyboardType:
                      multiline ? TextInputType.multiline : TextInputType.text,
                  textInputAction: multiline
                      ? TextInputAction.newline
                      : TextInputAction.done,
                  onSubmitted: multiline ? null : (_) => onSubmit(),
                  cursorColor: scheme.primary,
                  cursorWidth: 1.4,
                  style: _style(fontSize),
                  strutStyle: _strut(fontSize),
                  // **Temanın kutu süsü BURADA İSTENMİYOR.** Yalnız
                  // `border: none` vermek yetmiyordu: `focusedBorder`,
                  // `enabledBorder` ve `filled` temadan geliyor, yani
                  // odaklanınca yazının etrafında kalın mavi, yuvarlak bir
                  // çerçeve ve gri dolgu çıkıyordu; metin silinince de
                  // sayfayı boydan boya kesen mavi bir çizgiye dönüşüyordu
                  // (kullanıcı ekran görüntüleri 2026-09-24).
                  decoration: const InputDecoration(
                    isCollapsed: true,
                    filled: false,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    disabledBorder: InputBorder.none,
                    errorBorder: InputBorder.none,
                    focusedErrorBorder: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Kutunun içindeki dokunuşu **ham işaretçi olayından** yakalar.
///
/// `Listener` dokunma arenasına girmez: pdfrx'in köprü tanıyıcısı arenayı
/// kazansa da bu olay yine gelir. Tek, kısa bir dokunuşta imleci o noktaya
/// koyar ve klavyeyi açar. `TextField` arenayı kazanırsa kendi yerleştirmesi
/// bizimkinden SONRA çalışır ve aynı yere koyar — çakışmaz.
///
/// Çift dokunuş (kelime seçimi) ve uzun basış (seçim tutamaçları) bozulmasın
/// diye yalnız tek ve kısa dokunuşlarda imleç taşınır; klavye her durumda
/// açılır.
class _TapToType extends StatefulWidget {
  const _TapToType({
    super.key,
    this.behavior = HitTestBehavior.translucent,
    required this.child,
    required this.enabled,
    required this.onTap,
    required this.onShowKeyboard,
  });

  final HitTestBehavior behavior;
  final Widget child;
  final bool enabled;
  final void Function(Offset local) onTap;
  final void Function(BuildContext context) onShowKeyboard;

  @override
  State<_TapToType> createState() => _TapToTypeState();
}

class _TapToTypeState extends State<_TapToType> {
  Offset? _downAt;
  DateTime? _downTime;
  DateTime? _lastTap;
  bool _moved = false;

  static const _longPress = Duration(milliseconds: 350);

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: widget.behavior,
      onPointerDown: (e) {
        _downAt = e.position;
        _downTime = DateTime.now();
        _moved = false;
      },
      onPointerMove: (e) {
        final at = _downAt;
        if (at != null && (e.position - at).distance > kTouchSlop) {
          _moved = true;
        }
      },
      onPointerUp: (e) {
        final down = _downTime;
        _downAt = null;
        _downTime = null;
        if (!widget.enabled || down == null || _moved) return;
        final now = DateTime.now();
        final quick = now.difference(down) < _longPress;
        final last = _lastTap;
        final secondTap =
            last != null && down.difference(last) < kDoubleTapTimeout;
        _lastTap = now;
        if (quick && !secondTap) widget.onTap(e.localPosition);
        widget.onShowKeyboard(context);
      },
      onPointerCancel: (_) {
        _downAt = null;
        _downTime = null;
      },
      child: widget.child,
    );
  }
}
